import Foundation
import GRDB
import LiquorEngine

/// The hunt log: where you looked, what was on the shelf, the lotteries
/// you entered. Rows like any other -- synced, backed up, soft-deleted.
public struct SightingRepository: Sendable {
    private let db: AppDatabase

    public init(_ db: AppDatabase) { self.db = db }

    // MARK: - Reading

    /// Everything, newest first.
    public func all() throws -> [Sighting] {
        try db.queue.read { db in
            try Sighting.live().order(Column("seen_at").desc).fetchAll(db)
        }
    }

    public func sightings(catalogProductId: String) throws -> [Sighting] {
        try db.queue.read { db in
            try Sighting.live()
                .filter(Column("catalog_product_id") == catalogProductId)
                .order(Column("seen_at").desc)
                .fetchAll(db)
        }
    }

    /// The newest shelf sighting of a product, not yet bought. Nil when it
    /// was never seen.
    public func latest(catalogProductId: String) throws -> Sighting? {
        try db.queue.read { db in
            try Sighting.live()
                .filter(Column("catalog_product_id") == catalogProductId)
                .filter(Column("kind") == Hunt.Kind.seen.rawValue)
                .filter(Column("bottle_id") == nil)
                .order(Column("seen_at").desc)
                .fetchOne(db)
        }
    }

    /// Where you have logged a sighting before, most recent first, one
    /// spelling per store -- for the chips on the sheet.
    public func stores() throws -> [String] {
        let rows = try all()
        var seen = Set<String>()
        var out: [String] = []
        for row in rows {
            let key = Hunt.storeKey(row.store)
            guard !key.isEmpty, !seen.contains(key) else { continue }
            seen.insert(key)
            out.append(row.store.trimmingCharacters(in: .whitespaces))
        }
        return out
    }

    // MARK: - Writing

    /// Logs one. A sighting names a catalogue product or a typed name;
    /// neither is a row that says nothing.
    @discardableResult
    public func record(
        catalogProductId: String? = nil,
        customName: String? = nil,
        kind: Hunt.Kind = .seen,
        store: String,
        region: String? = nil,
        cents: Int? = nil,
        count: Int? = nil,
        note: String? = nil,
        seenAt: Int64 = Sighting.nowMilliseconds()
    ) throws -> Sighting {
        let store = store.trimmingCharacters(in: .whitespacesAndNewlines)
        let name = customName?.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !store.isEmpty else { throw DataError.sightingNeedsAStore }
        guard catalogProductId != nil || !(name ?? "").isEmpty else { throw DataError.sightingNeedsAName }
        var row = Sighting(
            catalogProductId: catalogProductId,
            customName: catalogProductId == nil ? name : nil,
            kind: kind,
            store: store,
            region: region,
            cents: cents.flatMap { $0 > 0 ? $0 : nil },
            count: kind == .seen ? count.map { max(0, $0) } : nil,
            note: note?.isEmpty == false ? note : nil,
            seenAt: seenAt)
        try db.queue.write { db in try row.saveLocal(db) }
        return row
    }

    /// How a lottery came out. Nil puts it back to pending.
    public func setOutcome(id: String, outcome: Hunt.Outcome?) throws {
        try db.queue.write { db in
            guard var row = try Sighting.live().filter(key: id).fetchOne(db) else {
                throw DataError.sightingNotFound(id)
            }
            row.outcome = outcome
            try row.saveLocal(db)
        }
    }

    /// The bottle was bought: the sighting points at it and stops counting
    /// as somewhere to go.
    public func markBought(id: String, bottleId: String) throws {
        try db.queue.write { db in
            guard var row = try Sighting.live().filter(key: id).fetchOne(db) else {
                throw DataError.sightingNotFound(id)
            }
            row.bottleId = bottleId
            try row.saveLocal(db)
        }
    }

    /// Soft delete, like everything else here.
    public func remove(id: String) throws {
        try db.queue.write { db in
            guard var row = try Sighting.filter(key: id).fetchOne(db) else { return }
            row.softDelete()
            try row.save(db)
        }
    }

    // MARK: - For the engine

    /// The log as the engine reads it. `name` is resolved by the caller,
    /// which owns the catalogue.
    public func facts(name: (Sighting) -> String) throws -> [Hunt.Sighting] {
        try all().map { row in
            Hunt.Sighting(
                id: row.id,
                productId: row.catalogProductId,
                name: name(row),
                store: row.store,
                kind: row.kind,
                outcome: row.outcome,
                cents: row.cents,
                count: row.count,
                at: Date(timeIntervalSince1970: Double(row.seenAt) / 1000),
                boughtBottleId: row.bottleId)
        }
    }
}
