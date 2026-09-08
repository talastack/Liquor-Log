import Foundation
import GRDB

/// The six columns every synced table carries.
///
/// Conformance is what makes the sync columns a **compile-time obligation**
/// rather than something to remember. A new table that forgets `updated_at`
/// cannot conform, and cannot be handed to the sync client — so it cannot be
/// added to the schema and quietly left out of sync, which is the failure this
/// protocol exists to prevent.
/// `Hashable` is here so records can sit in SwiftUI collections and in the
/// summary types the repositories return. Every conformer is a value type whose
/// members are themselves Hashable, so synthesis covers it.
public protocol SyncableRecord:
    Codable, Hashable, FetchableRecord, MutablePersistableRecord, Identifiable, Sendable
{
    /// uuid v4, generated on device. Text, not a native UUID column: the same
    /// string has to round-trip through SQLite, PostgREST and JSON unchanged.
    var id: String { get }

    /// NULL until the user creates an account. The app is fully usable with no
    /// account, and every local row is stamped in one transaction at upgrade.
    var userId: String? { get set }

    /// Unix milliseconds.
    var createdAt: Int64 { get set }

    /// Unix milliseconds, bumped on every write. The last-write-wins key.
    var updatedAt: Int64 { get set }

    /// Soft-delete tombstone. **Never hard delete.** A hard delete breaks sync
    /// and destroys the history the product is sold on.
    var deletedAt: Int64? { get set }

    /// Local-only push queue flag. Never sent to the server, never received,
    /// and absent from the Postgres schema entirely.
    var dirty: Bool { get set }
}

public extension SyncableRecord {
    var isDeleted: Bool { deletedAt != nil }

    static func nowMilliseconds() -> Int64 {
        Int64(Date().timeIntervalSince1970 * 1000)
    }
}

// MARK: - Write helpers

public extension SyncableRecord {

    /// Stamps `updated_at` and marks the row for push.
    ///
    /// Every mutation goes through this. Bumping `updated_at` without setting
    /// `dirty` strands the change locally; setting `dirty` without bumping
    /// `updated_at` makes the server discard it as stale on arrival. They are
    /// only ever correct together, so they are only ever set together.
    mutating func touch(now: Int64 = Self.nowMilliseconds()) {
        updatedAt = now
        dirty = true
    }

    /// Soft-deletes and marks for push.
    mutating func softDelete(now: Int64 = Self.nowMilliseconds()) {
        deletedAt = now
        touch(now: now)
    }

    /// Stamps and saves. **The only save path for user-originated writes.**
    ///
    /// Note this is not GRDB's `willSave` callback. That callback is
    /// non-mutating, so it cannot stamp `updated_at` onto the record being
    /// written — the stamp has to happen before the save, which is what this
    /// does. Repositories call this rather than `save(db)` directly.
    mutating func saveLocal(_ db: Database) throws {
        touch()
        try save(db)
    }

    /// Saves a row that arrived from the server, **without** marking it dirty.
    ///
    /// The distinction matters: a row written by `saveLocal` needs pushing, and
    /// a row that just arrived from a pull does not. Marking incoming rows
    /// dirty would make every pull schedule a redundant push, and two devices
    /// would ping-pong changes at each other indefinitely.
    ///
    /// `updated_at` is preserved exactly as the server sent it, because it is
    /// the last-write-wins key — restamping it locally would make this device
    /// win every future conflict by accident.
    mutating func saveFromServer(_ db: Database) throws {
        dirty = false
        try save(db)
    }
}

// MARK: - Queries every synced table needs

public extension SyncableRecord where Self: TableRecord {

    /// Rows the user can actually see. Tombstones stay in the database forever
    /// so they can sync, and are filtered out of every read.
    static func live() -> QueryInterfaceRequest<Self> {
        filter(Column("deleted_at") == nil)
    }

    /// The push queue.
    static func pending() -> QueryInterfaceRequest<Self> {
        filter(Column("dirty") == true)
    }
}
