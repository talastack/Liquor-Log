import Foundation
import GRDB
import LiquorEngine

/// A tasting together with the wheel picks that belong to it.
public struct TastingDetail: Sendable, Identifiable, Hashable {
    public let tasting: Tasting
    /// Descriptor keys per stage, in the order they were picked.
    public let notes: [TastingStage: [String]]

    public var id: String { tasting.id }

    public func descriptors(on stage: TastingStage) -> [String] { notes[stage] ?? [] }

    public var descriptorCount: Int { notes.values.reduce(0) { $0 + $1.count } }
}

/// Reads and writes tastings, and the flavour-wheel picks attached to them.
public struct TastingRepository: Sendable {
    private let db: AppDatabase

    public init(_ db: AppDatabase) { self.db = db }

    // MARK: - Reading

    /// Every tasting of a bottle, newest first — a changing opinion is the
    /// point of keeping them all.
    public func history(bottleId: String) throws -> [TastingDetail] {
        try db.queue.read { db in
            let tastings = try Tasting
                .live()
                .filter(Column("bottle_id") == bottleId)
                .order(Column("tasted_at").desc)
                .fetchAll(db)
            return try tastings.map { try Self.detail(for: $0, in: db) }
        }
    }

    /// Every tasting of a product, whether or not you ever owned a bottle of
    /// it. This is what makes "tasted, never owned" answerable.
    public func history(productId: String) throws -> [TastingDetail] {
        try db.queue.read { db in
            let tastings = try Tasting
                .live()
                .filter(Column("catalog_product_id") == productId)
                .order(Column("tasted_at").desc)
                .fetchAll(db)
            return try tastings.map { try Self.detail(for: $0, in: db) }
        }
    }

    /// Tastings in the shape `ShelfCheck` wants.
    ///
    /// Resolves outside the read: the resolver may query this database for a
    /// custom product, and GRDB does not allow a read inside a read.
    public func records(resolving product: (String) -> ProductIdentity?) throws -> [TastingRecord] {
        let tastings = try db.queue.read { db in try Tasting.live().fetchAll(db) }
        return tastings.compactMap { tasting -> TastingRecord? in
            guard let id = tasting.catalogProductId, let identity = product(id) else {
                return nil
            }
            return TastingRecord(
                tastingId: tasting.id,
                product: identity,
                tastedAt: Date(timeIntervalSince1970: Double(tasting.tastedAt) / 1000),
                rating: tasting.rating,
                wouldRebuy: tasting.wouldRebuy.map { $0 == .yes },
                liked: tasting.liked,
                disliked: tasting.disliked
            )
        }
    }

    // MARK: - Writing

    /// Saves a tasting and its wheel picks in ONE transaction.
    ///
    /// Not two calls: a tasting that saved while its descriptors failed would
    /// leave a rating with no notes and no way for the user to tell that
    /// anything was lost.
    @discardableResult
    public func save(
        _ tasting: Tasting,
        descriptors: [TastingStage: [String]] = [:]
    ) throws -> TastingDetail {
        try db.queue.write { db in
            var copy = tasting
            try copy.saveLocal(db)
            try Self.replaceNotes(tastingId: copy.id, descriptors: descriptors, in: db)
            return try Self.detail(for: copy, in: db)
        }
    }

    /// Replaces the picks on ONE stage, leaving the other three alone.
    ///
    /// This is what the flavour wheel calls when you finish with a stage. It is
    /// a replace rather than an append because the wheel is a toggle: whatever
    /// is lit when you leave is what the stage holds.
    public func setDescriptors(
        tastingId: String,
        stage: TastingStage,
        keys: [String]
    ) throws {
        try db.queue.write { db in
            try Self.applyDescriptors(
                tastingId: tastingId, stage: stage, keys: keys, in: db)
        }
    }

    public func remove(tastingId: String) throws {
        try db.queue.write { db in
            guard var tasting = try Tasting.filter(key: tastingId).fetchOne(db) else { return }
            tasting.softDelete()
            try tasting.save(db)
        }
    }

    // MARK: - Internals

    static func replaceNotes(
        tastingId: String,
        descriptors: [TastingStage: [String]],
        in db: Database
    ) throws {
        for stage in TastingStage.allCases {
            try applyDescriptors(
                tastingId: tastingId, stage: stage,
                keys: descriptors[stage] ?? [], in: db)
        }
    }

    /// Makes one stage hold exactly `keys`, and nothing else.
    ///
    /// **Fetches every row for the stage, tombstones included.** Filtering to
    /// live rows here was a real bug: a descriptor removed and then re-selected
    /// could not find its own tombstone, so it inserted a second row for the
    /// same descriptor on the same stage. The row count is what caught it.
    ///
    /// Reviving rather than inserting also keeps the sync honest -- the server
    /// already has that id, and a second row for it would arrive as a duplicate
    /// on every other device.
    static func applyDescriptors(
        tastingId: String,
        stage: TastingStage,
        keys: [String],
        in db: Database
    ) throws {
        let all = try TastingNote
            .filter(Column("tasting_id") == tastingId)
            .filter(Column("stage") == stage.rawValue)
            .fetchAll(db)

        let wanted = Set(keys)

        for var note in all {
            let shouldBePresent = wanted.contains(note.descriptorKey)
            if shouldBePresent, note.isDeleted {
                note.deletedAt = nil
                try note.saveLocal(db)
            } else if !shouldBePresent, !note.isDeleted {
                // Tombstone rather than delete, so the removal syncs.
                note.softDelete()
                try note.save(db)
            }
        }

        let known = Set(all.map(\.descriptorKey))
        for key in keys where !known.contains(key) {
            var note = TastingNote(tastingId: tastingId, stage: stage, descriptorKey: key)
            try note.saveLocal(db)
        }
    }

    static func detail(for tasting: Tasting, in db: Database) throws -> TastingDetail {
        let notes = try TastingNote
            .live()
            .filter(Column("tasting_id") == tasting.id)
            .order(Column("created_at"))
            .fetchAll(db)

        var grouped: [TastingStage: [String]] = [:]
        for note in notes {
            grouped[note.stage, default: []].append(note.descriptorKey)
        }
        return TastingDetail(tasting: tasting, notes: grouped)
    }
}
