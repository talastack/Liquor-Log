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

    /// When this bottle was last poured from. Nil means never.
    ///
    /// Derived from the pour log rather than stored, like every other number
    /// here. People use it to dig out a bottle they liked and have not touched
    /// in months.
    public let lastPouredAt: Date?

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

    /// Days since the last pour. Nil when it has never been poured from.
    public func daysSinceLastPour(now: Date = Date()) -> Int? {
        guard let last = lastPouredAt else { return nil }
        return max(0, Int(now.timeIntervalSince(last) / 86_400))
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
    ///
    /// The resolver runs AFTER the read, never inside it. Resolving a product
    /// the bundled catalogue does not know means looking it up in this same
    /// database, and a read opened inside a read is a re-entrancy fatal error
    /// in GRDB -- the shelf check crashed the moment a typed-in bottle was on
    /// the shelf.
    public func holdings(resolving product: (String) -> ProductIdentity?) throws -> [Holding] {
        let bottles = try db.queue.read { db in try Bottle.live().fetchAll(db) }
        return bottles.compactMap { bottle in
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

    /// Saves an edited bottle.
    ///
    /// **The identity columns are not writable through here.** `id` addresses
    /// the row, and `createdAt`, `userId` and the sync columns are taken from
    /// the stored copy rather than from the caller — a screen that round-trips
    /// a record can otherwise send back a stale `createdAt` or, worse, a
    /// `user_id` it guessed, and RLS would then hide the row from its owner
    /// forever.
    ///
    /// `saveLocal` stamps `updated_at` and queues the push, so an edit made
    /// offline reaches other devices with the time of the EDIT on it rather
    /// than the time it happened to sync.
    @discardableResult
    /// Points the bottle at a photo file, or at none. The file itself is the
    /// photo store's business; this only records which one.
    public func setPhoto(bottleId: String, fileName: String?) throws {
        try db.queue.write { db in
            guard var bottle = try Bottle.filter(key: bottleId).fetchOne(db) else {
                throw DataError.bottleNotFound(bottleId)
            }
            bottle.photoFile = fileName
            try bottle.saveLocal(db)
        }
    }

    public func update(_ bottle: Bottle) throws -> Bottle {
        try db.queue.write { db in
            guard let stored = try Bottle.filter(key: bottle.id).fetchOne(db) else {
                throw DataError.bottleNotFound(bottle.id)
            }

            var edited = bottle
            edited.userId = stored.userId
            edited.createdAt = stored.createdAt
            // Editing a bottle is not un-deleting one. A tombstone stays a
            // tombstone until something explicitly revives it.
            edited.deletedAt = stored.deletedAt

            try edited.saveLocal(db)
            return edited
        }
    }

    /// Regulation problems with a bottle as it stands.
    ///
    /// The engine has held these rules since the first commit and NOTHING
    /// called them, so a "bottled in bond" at 43% saved silently. They are
    /// surfaced as warnings rather than enforced as errors: a label really can
    /// contradict the regulations, an old bottle can predate a rule, and
    /// refusing to save somebody's real bottle because it fails a check is how
    /// an app loses to a spreadsheet.
    public func validationIssues(for bottle: Bottle) -> [Classification.Issue] {
        guard let classType = try? classType(of: bottle) else { return [] }
        return Classification.validate(
            classType: classType,
            abv: bottle.abv.map { ABV(percent: $0) },
            statedAgeYears: bottle.ageMonths.map { $0 / 12 },
            isBottledInBond: false,
            volumeMilliliters: bottle.volumeMl)
    }

    /// The class of what is in a bottle, from the custom catalogue.
    ///
    /// The BUNDLED catalogue is a file the app layer holds, so a bottle
    /// matched to it resolves there instead — this covers the rows that live
    /// in the database.
    private func classType(of bottle: Bottle) throws -> ClassType? {
        guard let id = bottle.catalogProductId else { return nil }
        return try customProduct(id: id)?.classType
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
            let reading = try Self.latestReading(bottleId: bottleId, in: db)
            let poured = try Self.pouredMilliliters(
                bottleId: bottleId, since: reading?.readAt, in: db)
            let remaining = PourMath.remainingMilliliters(
                capacity: bottle.volumeMl,
                poured: poured,
                startingFrom: reading?.remainingMl)
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

    /// Records how much is actually left, as observed right now.
    ///
    /// This is how somebody adds a bottle they opened two years ago, and how
    /// they correct a bottle they poured from at a party without logging it.
    /// It does not touch the pour log: the pours you logged stay logged, and
    /// the fill is derived from this reading forward.
    ///
    /// Readings accumulate rather than replace. Two of them a year apart on one
    /// bottle are a real record of how fast it went down.
    @discardableResult
    public func setLevel(
        bottleId: String,
        remainingMl: Double,
        note: String? = nil,
        at when: Int64 = FillReading.nowMilliseconds()
    ) throws -> FillReading {
        try db.queue.write { db in
            guard let bottle = try Bottle.filter(key: bottleId).fetchOne(db) else {
                throw DataError.bottleNotFound(bottleId)
            }
            var reading = FillReading(
                bottleId: bottleId,
                readAt: when,
                // Clamped on the way in as well as on the way out. A negative
                // reading is a typo, not a bottle in debt.
                remainingMl: min(bottle.volumeMl, max(0, remainingMl)),
                note: note)
            try reading.saveLocal(db)

            // Saying there is something in a bottle you never marked open is
            // saying it is open. Not inferring that leaves every age and
            // oxidation figure on the screen lying.
            if bottle.openedAt == nil, reading.remainingMl < bottle.volumeMl {
                var opened = bottle
                opened.openedAt = when
                try opened.saveLocal(db)
            }
            return reading
        }
    }

    /// Sets the level as a percentage of the bottle, for a screen where people
    /// think in fractions. Stored as millilitres either way.
    @discardableResult
    public func setLevel(
        bottleId: String,
        percentFull: Double,
        note: String? = nil,
        at when: Int64 = FillReading.nowMilliseconds()
    ) throws -> FillReading {
        guard let bottle = try summary(id: bottleId)?.bottle else {
            throw DataError.bottleNotFound(bottleId)
        }
        return try setLevel(
            bottleId: bottleId,
            remainingMl: PourMath.milliliters(
                percentFull: percentFull, capacity: bottle.volumeMl),
            note: note,
            at: when)
    }

    /// What you have paid for a product before, for the price comparison.
    ///
    /// Includes finished bottles: a price you paid two years ago is still a
    /// price you paid, and dropping it would make the history thinner exactly
    /// for the bottles you buy most often.
    ///
    /// `excluding` leaves out the bottle being looked at, so its own price is
    /// not compared against itself.
    public func purchaseHistory(
        catalogProductId: String,
        excluding bottleId: String? = nil
    ) throws -> [PriceHistory.Purchase] {
        try db.queue.read { db in
            var request = Bottle
                .live()
                .filter(Column("catalog_product_id") == catalogProductId)
                // Either number is a price sighting. Requiring a PURCHASE
                // price would throw away every bottle somebody priced but got
                // as a gift, and every one they recorded before buying.
                .filter(
                    Column("purchase_price_cents") != nil
                    || Column("shelf_price_cents") != nil)
            if let bottleId {
                request = request.filter(Column("id") != bottleId)
            }
            return try request
                .order(Column("purchase_date").desc)
                .fetchAll(db)
                .compactMap { bottle in
                    guard let cents = bottle.purchasePriceCents
                        ?? bottle.shelfPriceCents else { return nil }
                    return PriceHistory.Purchase(
                        cents: cents,
                        shelfCents: bottle.shelfPriceCents,
                        purchasedAt: bottle.purchaseDate.map {
                            Date(timeIntervalSince1970: Double($0) / 1000)
                        },
                        store: bottle.purchaseStore)
                }
        }
    }

    /// Every level ever recorded for a bottle, newest first.
    public func fillHistory(bottleId: String) throws -> [FillReading] {
        try db.queue.read { db in
            try FillReading
                .live()
                .filter(Column("bottle_id") == bottleId)
                .order(Column("read_at").desc)
                .fetchAll(db)
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

    /// Sum of live pours, optionally only those AFTER a level reading.
    ///
    /// Tombstoned pours do not count against the bottle, so undoing a
    /// mis-logged pour restores the fill.
    ///
    /// When a reading exists, pours logged before it are already reflected in
    /// what somebody saw in the glass. Counting them again would subtract the
    /// same whiskey twice.
    static func pouredMilliliters(
        bottleId: String,
        since readAt: Int64? = nil,
        in db: Database
    ) throws -> Double {
        // Fetched as a Double rather than through the record request: the
        // request's element type is Pour, so `fetchOne` on it would try to
        // decode a whole row from a single aggregate column. SUM over no rows
        // is NULL, which arrives here as nil and means an untouched bottle.
        var request = Pour
            .live()
            .filter(Column("bottle_id") == bottleId)
        if let readAt {
            request = request.filter(Column("poured_at") > readAt)
        }
        return try Double.fetchOne(db, request.select(sum(Column("volume_ml")))) ?? 0
    }

    /// The most recent level somebody actually looked at, if there is one.
    static func latestReading(bottleId: String, in db: Database) throws -> FillReading? {
        try FillReading
            .live()
            .filter(Column("bottle_id") == bottleId)
            .order(Column("read_at").desc)
            .fetchOne(db)
    }

    static func summary(for bottle: Bottle, in db: Database) throws -> BottleSummary {
        // A reading is a human overruling the pour log. Everything poured
        // before it is already accounted for in what they saw.
        let reading = try latestReading(bottleId: bottle.id, in: db)
        let poured = try pouredMilliliters(
            bottleId: bottle.id, since: reading?.readAt, in: db)
        let tastings = try Tasting
            .live()
            .filter(Column("bottle_id") == bottle.id)
            .order(Column("tasted_at").desc)
            .fetchAll(db)

        let lastPour = try Pour
            .live()
            .filter(Column("bottle_id") == bottle.id)
            .order(Column("poured_at").desc)
            .fetchOne(db)

        return BottleSummary(
            bottle: bottle,
            status: PourMath.status(
                capacityMilliliters: bottle.volumeMl,
                pouredMilliliters: poured,
                startingMilliliters: reading?.remainingMl,
                pourSize: bottle.pourSize
            ),
            latestRating: tastings.first?.rating,
            tastingCount: tastings.count,
            lastPouredAt: lastPour.map {
                Date(timeIntervalSince1970: Double($0.pouredAt) / 1000)
            }
        )
    }
}

public enum DataError: Error, Sendable, Equatable {
    case bottleNotFound(String)
    case bottleIsEmpty(String)
}
