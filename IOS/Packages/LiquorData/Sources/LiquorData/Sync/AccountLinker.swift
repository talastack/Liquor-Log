import Foundation
import GRDB

/// Adopts a local-only collection into an account.
///
/// The app works with no account, so `user_id` is NULL on every row until
/// somebody signs in. At that moment every one of those rows has to be stamped
/// with the new id — and **in a single transaction**.
///
/// A partial stamp is the worst failure this codebase has. `user_id` is NOT
/// NULL server-side and RLS matches on `auth.uid() = user_id`, so a row that
/// missed the stamp can never be pushed and, if it somehow were, could never be
/// read back. It would sit in the local database looking perfectly normal,
/// invisible to its owner on every other device, with nothing in the app able
/// to find or repair it.
public struct AccountLinker: Sendable {
    private let db: AppDatabase

    public init(_ db: AppDatabase) { self.db = db }

    /// Every table the client writes. `subscriptions` is absent because it is
    /// server-owned: rows arrive by pull already carrying their owner.
    private var tables: [String] {
        [
            "custom_catalog_entries", "bottles", "pours", "fill_readings",
            "blend_additions", "price_reports", "drip_reports", "menus",
            "tastings", "tasting_notes", "wishlist_items", "knowledge_notes",
            "sightings", "visits",
        ]
    }

    /// Stamps every unowned row and queues it for push. Returns how many.
    ///
    /// `updated_at` is deliberately NOT bumped. It is the last-write-wins key
    /// and it should say when the human edited the bottle, not when they
    /// happened to create an account — restamping it would make a years-old
    /// note win a conflict against a genuinely newer edit from another device.
    ///
    /// `dirty` IS set, because these rows have never been pushed.
    @discardableResult
    public func adopt(userId: String) throws -> Int {
        // ONE write block, so GRDB wraps every table in a single transaction.
        // Eight separate writes would leave a crash between any two of them
        // with half a collection owned and half orphaned.
        try db.queue.write { db in
            var stamped = 0
            for table in tables {
                try db.execute(
                    sql: """
                        update \(quoted(table))
                           set user_id = ?, dirty = 1
                         where user_id is null
                        """,
                    arguments: [userId])
                stamped += db.changesCount
            }
            return stamped
        }
    }

    /// The reverse of `adopt`, after the account was deleted on the server.
    ///
    /// Rows that were the account's become nobody's again, and dirty, so a
    /// new account made later adopts and pushes them exactly like a first
    /// sign-in. Rows that were somebody else's -- a household partner's,
    /// pulled while the household stood -- are removed: there is no account
    /// left that may hold them. One transaction, for the same reason as
    /// `adopt`.
    @discardableResult
    public func disown(userId: String) throws -> Int {
        try db.queue.write { db in
            var changed = 0
            for table in tables {
                try db.execute(
                    sql: "delete from \(quoted(table)) where user_id is not null and user_id <> ?",
                    arguments: [userId])
                changed += db.changesCount
                try db.execute(
                    sql: "update \(quoted(table)) set user_id = null, dirty = 1 where user_id = ?",
                    arguments: [userId])
                changed += db.changesCount
            }
            return changed
        }
    }

    /// Rows that belong to nobody. Zero after a successful `adopt`, and a
    /// non-zero result afterwards means the stamp did not finish.
    public func unownedCount() throws -> Int {
        try db.queue.read { db in
            var total = 0
            for table in tables {
                total += try Int.fetchOne(
                    db, sql: "select count(*) from \(quoted(table)) where user_id is null") ?? 0
            }
            return total
        }
    }

    /// Rows owned by some OTHER account.
    ///
    /// Non-zero means this device is holding a collection that is not the
    /// signing-in user's: the account that was signed in before, or a
    /// household partner's rows pulled while that household stood.
    public func foreignCount(excluding userId: String) throws -> Int {
        try db.queue.read { db in
            var total = 0
            for table in tables {
                total += try Int.fetchOne(
                    db,
                    sql: """
                        select count(*) from \(quoted(table))
                         where user_id is not null and user_id <> ?
                        """,
                    arguments: [userId]) ?? 0
            }
            return total
        }
    }

    /// Removes every row owned by another account, for when a DIFFERENT
    /// person signs in on a device that already holds a collection.
    ///
    /// Without this the rows simply stay. Nothing reads by `user_id` -- the
    /// local database is "this device's collection" -- so the new account
    /// would see the previous one's bottles as their own, and any edit to one
    /// would be pushed carrying the wrong owner, rejected by RLS, and retried
    /// forever.
    ///
    /// **What this costs, stated plainly.** These rows are not lost: they are
    /// on the server under the account that owns them, and that account pulls
    /// them again at its next sign-in. What IS lost is a change made under the
    /// previous account that never reached the server -- an edit made offline,
    /// then signed out of, then a different account signed in. That is a real
    /// loss and there is no better terminal state for such a row: it can never
    /// be pushed as the new user, and it must not be shown to them.
    ///
    /// One transaction, for the same reason as `adopt`.
    @discardableResult
    public func evict(keeping userId: String) throws -> Int {
        try db.queue.write { db in
            var removed = 0
            for table in tables {
                try db.execute(
                    sql: """
                        delete from \(quoted(table))
                         where user_id is not null and user_id <> ?
                        """,
                    arguments: [userId])
                removed += db.changesCount
            }
            return removed
        }
    }

    /// Table names are from the constant list above and never from input, but
    /// quoting them keeps the string interpolation from ever being the reason
    /// this file needs reviewing.
    private func quoted(_ table: String) -> String {
        "\"" + table.replacingOccurrences(of: "\"", with: "") + "\""
    }
}
