import Foundation
import GRDB

/// Push what changed, pull what changed elsewhere.
///
/// See `shared/contracts/sync.md`. The rules that matter, restated here because
/// this is where they are enforced:
///
/// - **Push filters on `dirty`, pull filters on `server_updated_at`.** Pulling
///   on `updated_at` loses every row edited offline and pushed late, silently.
/// - **`dirty` is cleared only after a 2xx.** Clearing it optimistically
///   discards somebody's tasting note when the request fails.
/// - **The cursor advances only after the batch is written**, to the highest
///   `server_updated_at` actually received.
/// - **Incoming rows never become dirty**, or every pull schedules a push and
///   two devices ping-pong forever.
///
/// Sync is additive. Nothing in the app waits on it, and every screen works
/// with no account and no network.
public actor SyncEngine {
    private let db: AppDatabase
    private let transport: SyncTransport
    private let cursors: SyncCursorStore

    /// PostgREST pages; 500 keeps a response small enough to decode on a phone
    /// without holding a whole collection in memory twice.
    private let pageSize = 500

    public init(db: AppDatabase, transport: SyncTransport, cursors: SyncCursorStore) {
        self.db = db
        self.transport = transport
        self.cursors = cursors
    }

    // MARK: - The table order

    /// **Dependency order, and it is load-bearing.**
    ///
    /// A pour references a bottle. Pushing pours first fails the foreign key,
    /// and PostgREST reports it as a 409 that names neither the table nor the
    /// row. Pull uses the same order so a referencing row is never written
    /// before the row it references.
    private var tables: [AnySyncTable] {
        [
            AnySyncTable(CustomCatalogEntry.self),
            AnySyncTable(Bottle.self),
            AnySyncTable(Pour.self),
            AnySyncTable(FillReading.self),
            AnySyncTable(Tasting.self),
            AnySyncTable(TastingNote.self),
            AnySyncTable(WishlistItem.self),
            AnySyncTable(KnowledgeNote.self),
            // subscriptions is server-owned: pulled, never pushed. It has no
            // insert or update policy, so an attempt is refused by RLS rather
            // than by anything here.
            AnySyncTable(Subscription.self, isPushable: false),
        ]
    }

    // MARK: - Running

    public struct Outcome: Sendable, Equatable {
        public var pushed = 0
        public var pulled = 0
        /// Tables that failed, with why. A partial sync is normal and safe:
        /// the rows that did not go stay dirty and go next time.
        public var failures: [String: String] = [:]

        public var isCompletelyClean: Bool { failures.isEmpty }
    }

    /// Push first, then pull.
    ///
    /// This order means a device sees its own writes reflected back with the
    /// server's clock on them, so its cursor moves past its own rows instead of
    /// re-downloading them on the next run.
    @discardableResult
    public func sync() async -> Outcome {
        var outcome = Outcome()

        for table in tables where table.isPushable {
            do {
                outcome.pushed += try await push(table)
            } catch {
                outcome.failures[table.name] = String(describing: error)
            }
        }

        for table in tables {
            do {
                outcome.pulled += try await pull(table)
            } catch {
                outcome.failures[table.name] = String(describing: error)
            }
        }

        return outcome
    }

    // MARK: - Push

    private func push(_ table: AnySyncTable) async throws -> Int {
        let pending = try loadPending(table)
        guard !pending.isEmpty else { return 0 }

        var sent = 0
        for batch in pending.chunked(into: pageSize) {
            try await transport.upsert(table: table.name, rows: batch.map(\.body))

            // Only now. If upsert threw, these rows stay dirty and go again.
            try clearDirty(table, batch.map(\.id))
            sent += batch.count
        }
        return sent
    }

    // MARK: - Database access
    //
    // Every database call goes through a NON-ASYNC helper, and that is
    // deliberate rather than stylistic.
    //
    // GRDB ships both a synchronous `read`/`write` and an async one. Inside an
    // `async` function Swift resolves to the ASYNC overload, which then demands
    // `await` and, under strict concurrency, demands everything crossing the
    // closure be Sendable. Doing the work from a non-async context picks the
    // synchronous overload, which is what an actor wants anyway: the writes are
    // short, and hopping executors mid-transaction buys nothing.
    //
    // `nonisolated` because they touch only `db`, which is an immutable
    // Sendable reference.

    private nonisolated func loadPending(
        _ table: AnySyncTable
    ) throws -> [(id: String, body: Data)] {
        try db.queue.read { try table.pendingRows($0) }
    }

    private nonisolated func clearDirty(_ table: AnySyncTable, _ ids: [String]) throws {
        try db.queue.write { try table.clearDirty(ids, $0) }
    }

    private nonisolated func apply(_ table: AnySyncTable, _ rows: [Data]) throws {
        // One transaction for the batch: a half-written page would leave the
        // cursor and the data disagreeing.
        try db.queue.write { db in
            for row in rows { try table.applyFromServer(row, db) }
        }
    }

    /// Strips what the server must never receive.
    ///
    /// `dirty` does not exist in Postgres and would be rejected. Sending
    /// `server_updated_at` is harmless — the trigger overwrites it — but a
    /// client that believes it can set the server's clock is a client somebody
    /// will eventually make depend on it.
    static func encodeForServer(_ row: [String: Any]) throws -> Data {
        var copy = row
        copy.removeValue(forKey: "dirty")
        copy.removeValue(forKey: "server_updated_at")
        return try JSONSerialization.data(withJSONObject: copy)
    }

    // MARK: - Pull

    private func pull(_ table: AnySyncTable) async throws -> Int {
        var cursor = cursors.cursor(for: table.name)
        var applied = 0

        // Keep going while a full page comes back: a full page means there is
        // very likely another.
        while true {
            let data = try await transport.fetch(
                table: table.name, since: cursor, limit: pageSize)

            guard let rows = try JSONSerialization.jsonObject(with: data) as? [[String: Any]]
            else { throw SyncError.malformedResponse(table: table.name) }

            if rows.isEmpty { break }

            let highest = rows.compactMap {
                ($0["server_updated_at"] as? NSNumber)?.int64Value
            }.max()

            // Converted to Data here, before it reaches the database helper.
            // A [String: Any] is not Sendable and cannot cross an isolation
            // boundary under strict concurrency.
            let bodies = rows.compactMap { row -> Data? in
                try? JSONSerialization.data(withJSONObject: Self.decodeFromServer(row))
            }
            try apply(table, bodies)
            applied += bodies.count

            // Only after the write. Advancing first loses the batch if the
            // write throws.
            if let highest, highest > cursor {
                cursor = highest
                cursors.setCursor(cursor, for: table.name)
            } else {
                // No usable clock in the response. Stopping is right: looping
                // on an unchanged cursor would re-fetch the same page forever.
                break
            }

            if rows.count < pageSize { break }
        }

        return applied
    }

    /// Prepares a server row for decoding.
    ///
    /// `dirty` is not optional on the record and is absent from every server
    /// row, so decoding without it fails. It is injected as false rather than
    /// made optional because a row that just arrived genuinely is not pending.
    static func decodeFromServer(_ row: [String: Any]) -> [String: Any] {
        var copy = row
        copy["dirty"] = false
        copy.removeValue(forKey: "server_updated_at")
        return copy
    }
}

// MARK: - Type erasure

/// One synced table, with its record type erased so they can sit in a list.
///
/// The alternative is a generic method per table, which is eight near-identical
/// call sites and eight chances to get the order wrong.
struct AnySyncTable: Sendable {
    let name: String
    let isPushable: Bool
    /// Bodies are `Data`, already stripped and ready to send. Returning a
    /// dictionary would be friendlier to read and is not Sendable, so it could
    /// not leave the database closure under strict concurrency.
    let pendingRows: @Sendable (Database) throws -> [(id: String, body: Data)]
    let clearDirty: @Sendable ([String], Database) throws -> Void
    let applyFromServer: @Sendable (Data, Database) throws -> Void

    init<R: SyncableRecord & TableRecord>(_ type: R.Type, isPushable: Bool = true) {
        self.name = R.databaseTableName
        self.isPushable = isPushable

        self.pendingRows = { db in
            let encoder = JSONEncoder()
            return try R.pending().fetchAll(db).map { record in
                let data = try encoder.encode(record)
                let json = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any]
                // Stripped here, inside the closure, so nothing that is not
                // Sendable ever leaves it.
                return (id: record.id, body: try SyncEngine.encodeForServer(json ?? [:]))
            }
        }

        self.clearDirty = { ids, db in
            for id in ids {
                guard var record = try R.filter(key: id).fetchOne(db) else { continue }
                record.dirty = false
                // save, NOT saveLocal: saveLocal would restamp updated_at and
                // mark it dirty again, which is an infinite push.
                try record.save(db)
            }
        }

        self.applyFromServer = { data, db in
            var record = try JSONDecoder().decode(R.self, from: data)
            try record.saveFromServer(db)
        }
    }
}

extension Array {
    func chunked(into size: Int) -> [[Element]] {
        guard size > 0 else { return [self] }
        return stride(from: 0, to: count, by: size).map {
            Array(self[$0..<Swift.min($0 + size, count)])
        }
    }
}
