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
            "tastings", "tasting_notes", "wishlist_items", "knowledge_notes",
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

    /// Signing out must not orphan anything.
    ///
    /// The rows keep their `user_id` and stay exactly where they are. Somebody
    /// signing out on a shared iPad is not asking to lose their collection, and
    /// wiping local data on sign-out is how people lose years of notes to a
    /// mistap.
    public func rowsOwned(by userId: String) throws -> Int {
        try db.queue.read { db in
            var total = 0
            for table in tables {
                total += try Int.fetchOne(
                    db,
                    sql: "select count(*) from \(quoted(table)) where user_id = ?",
                    arguments: [userId]) ?? 0
            }
            return total
        }
    }

    /// Table names are from the constant list above and never from input, but
    /// quoting them keeps the string interpolation from ever being the reason
    /// this file needs reviewing.
    private func quoted(_ table: String) -> String {
        "\"" + table.replacingOccurrences(of: "\"", with: "") + "\""
    }
}
