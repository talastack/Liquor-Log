import Foundation
import GRDB
import LiquorEngine

/// A bottle with everything a list row or a detail screen needs, computed in
/// one query rather than one per row.
public struct BottleSummary: Sendable, Identifiable, Hashable {
    public let bottle: Bottle
    public let status: PourStatus
    public let latestRating: Int?
    public let tastingCount: Int

    public var id: String { bottle.id }

    public var fillLevel: FillLevel {
        FillLevel(
            remainingMilliliters: status.remainingMilliliters,
            capacityMilliliters: status.capacityMilliliters
        )
    }

    /// Cost of one pour, from what was paid and the pour count actually shown.
    public var costPerPourCents: Int? {
        guard let paid = bottle.purchasePriceCents else { return nil }
        return PourMath.costPerPourCents(
            priceCents: paid,
            capacityMilliliters: bottle.volumeMl,
            pourSize: bottle.pourSize
        )
    }

    public func daysOpen(now: Date = Date()) -> Int? {
        guard let opened = bottle.openedAt else { return nil }
        return AgeMath.daysOpen(
            openedAt: Date(timeIntervalSince1970: Double(opened) / 1000), now: now)
    }
}

/// Reads and writes bottles, and derives what is left in them.
///
/// A `Sendable` struct holding a `DatabaseQueue`, which is itself thread-safe.
/// Views observe repositories; they never touch the queue directly.
public struct BottleRepository: Sendable {
    private let db: AppDatabase

    public init(_ db: AppDatabase) { self.db = db }

    // MARK: - Reading

    /// Everything on the shelf, newest first.
    public func summaries(includeFinished: Bool = false) throws -> [BottleSummary] {
        try db.queue.read { db in
            var request = Bottle.live()
            if !includeFinished {
                request = request.filter(Column("finished_at") == nil)
            }
            let bottles = try request.order(Column("created_at").desc).fetchAll(db)
            return try bottles.map { try Self.summary(for: $0, in: db) }
        }
    }

    public func summary(id: String) throws -> BottleSummary? {
        try db.queue.read { db in
            guard let bottle = try Bottle.filter(key: id).fetchOne(db) else { return nil }
            return try Self.summary(for: bottle, in: db)
        }
    }

    /// Live updates for SwiftUI. The whole list is one observation rather than
    /// one per bottle: a shelf with twenty bottles would otherwise open twenty
    /// observations that all re-fire on every single pour.
    public func observeSummaries(includeFinished: Bool = false)
        -> ValueObservation<ValueReducers.Fetch<[BottleSummary]>>
    {
        ValueObservation.tracking { db in
            var request = Bottle.live()
            if !includeFinished {
                request = request.filter(Column("finished_at") == nil)
            }
            let bottles = try request.order(Column("created_at").desc).fetchAll(db)
            return try bottles.map { try Self.summary(for: $0, in: db) }
        }
    }

    /// Holdings in the shape `ShelfCheck` wants. The engine takes plain values
    /// and does no I/O, so this is the only place the two meet.
    public func holdings(resolving product: (String) -> ProductIdentity?) throws -> [Holding] {
        try db.queue.read { db in
            try Bottle.live().fetchAll(db).compactMap { bottle in
                guard let id = bottle.catalogProductId, let identity = product(id) else { return nil }
                return Holding(
                    bottleId: bottle.id,
                    product: identity,
                    releaseLabel: bottle.releaseLabel,
                    isOpen: bottle.isOpen,
                    isFinished: bottle.isFinished
                )
            }
        }
    }

    // MARK: - Writing

    @discardableResult
    public func add(_ bottle: Bottle) throws -> Bottle {
        var copy = bottle
        try db.queue.write { db in try copy.saveLocal(db) }
        return copy
    }

    /// Adds a bottle of a product that is not in the bundled catalog.
    ///
    /// ONE transaction. A custom product that saved while its bottle failed
    /// would leave an orphan nobody can see or delete, and a bottle whose
    /// product failed would show as "Untitled bottle" forever.
    ///
    /// The catalog is small and always will be relative to what exists -- there
    /// is a new store pick every week -- so typing one in has to be a first
    /// class path, not a fallback.
    @discardableResult
    public func addCustom(
        product: CustomCatalogEntry,
        bottle: Bottle
    ) throws -> (product: CustomCatalogEntry, bottle: Bottle) {
        var savedProduct = product
        var savedBottle = bottle
        savedBottle.catalogProductId = product.id

        try db.queue.write { db in
            try savedProduct.saveLocal(db)
            try savedBottle.saveLocal(db)
        }
        return (savedProduct, savedBottle)
    }

    /// Products the user added themselves, newest first.
    public func customProducts() throws -> [CustomCatalogEntry] {
        try db.queue.read { db in
            try CustomCatalogEntry.live()
                .order(Column("created_at").desc)
                .fetchAll(db)
        }
    }

    public func customProduct(id: String) throws -> CustomCatalogEntry? {
        try db.queue.read { db in
            try CustomCatalogEntry.filter(key: id).fetchOne(db)
        }
    }

    /// Logs a pour. The pour log is the source of truth for what is left, so
    /// this is the ONLY way the fill level changes.
    ///
    /// Over-pouring past empty is clamped: a bottle cannot owe you whiskey, and
    /// a mis-tap should not produce a negative fill.
    @discardableResult
    public func logPour(bottleId: String, volumeMl: Double? = nil, note: String? = nil) throws -> Pour {
        try db.queue.write { db in
            guard let bottle = try Bottle.filter(key: bottleId).fetchOne(db) else {
                throw DataError.bottleNotFound(bottleId)
            }
            let poured = try Self.pouredMilliliters(bottleId: bottleId, in: db)
            let remaining = PourMath.remainingMilliliters(
                capacity: bottle.volumeMl, poured: poured)
            let requested = volumeMl ?? bottle.pourSizeMl
            guard remaining > 0 else { throw DataError.bottleIsEmpty(bottleId) }

            var pour = Pour(
                bottleId: bottleId,
                volumeMl: min(requested, remaining),
                note: note
            )
            try pour.saveLocal(db)

            // Opening is implied by the first pour: nobody taps "open" and then
            // "pour" as two separate acts, and a bottle with pours but no open
            // date makes every age calculation lie.
            if bottle.openedAt == nil {
                var opened = bottle
                opened.openedAt = pour.pouredAt
                try opened.saveLocal(db)
            }
            return pour
        }
    }

    public func open(bottleId: String, at when: Int64 = Bottle.nowMilliseconds()) throws {
        try db.queue.write { db in
            guard var bottle = try Bottle.filter(key: bottleId).fetchOne(db) else {
                throw DataError.bottleNotFound(bottleId)
            }
            guard bottle.openedAt == nil else { return }
            bottle.openedAt = when
            try bottle.saveLocal(db)
        }
    }

    public func finish(bottleId: String, at when: Int64 = Bottle.nowMilliseconds()) throws {
        try db.queue.write { db in
            guard var bottle = try Bottle.filter(key: bottleId).fetchOne(db) else {
                throw DataError.bottleNotFound(bottleId)
            }
            bottle.finishedAt = when
            try bottle.saveLocal(db)
        }
    }

    /// Soft delete. A hard delete would break sync and destroy the history the
    /// product is sold on.
    public func remove(bottleId: String) throws {
        try db.queue.write { db in
            guard var bottle = try Bottle.filter(key: bottleId).fetchOne(db) else { return }
            bottle.softDelete()
            try bottle.save(db)
        }
    }

    // MARK: - Derivation

    /// Sum of every live pour. Tombstoned pours do not count against the
    /// bottle, so undoing a mis-logged pour restores the fill.
    static func pouredMilliliters(bottleId: String, in db: Database) throws -> Double {
        // Fetched as a Double rather than through the record request: the
        // request's element type is Pour, so `fetchOne` on it would try to
        // decode a whole row from a single aggregate column. SUM over no rows
        // is NULL, which arrives here as nil and means an untouched bottle.
        let request = Pour
            .live()
            .filter(Column("bottle_id") == bottleId)
            .select(sum(Column("volume_ml")))
        return try Double.fetchOne(db, request) ?? 0
    }

    static func summary(for bottle: Bottle, in db: Database) throws -> BottleSummary {
        let poured = try pouredMilliliters(bottleId: bottle.id, in: db)
        let tastings = try Tasting
            .live()
            .filter(Column("bottle_id") == bottle.id)
            .order(Column("tasted_at").desc)
            .fetchAll(db)

        return BottleSummary(
            bottle: bottle,
            status: PourMath.status(
                capacityMilliliters: bottle.volumeMl,
                pouredMilliliters: poured,
                pourSize: bottle.pourSize
            ),
            latestRating: tastings.first?.rating,
            tastingCount: tastings.count
        )
    }
}

public enum DataError: Error, Sendable, Equatable {
    case bottleNotFound(String)
    case bottleIsEmpty(String)
}
