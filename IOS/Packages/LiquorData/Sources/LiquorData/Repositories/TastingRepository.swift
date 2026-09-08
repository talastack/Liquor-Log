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
    public func records(resolving product: (String) -> ProductIdentity?) throws -> [TastingRecord] {
        try db.queue.read { db in
            try Tasting.live().fetchAll(db).compactMap { tasting -> TastingRecord? in
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
            let existing = try TastingNote
                .live()
                .filter(Column("tasting_id") == tastingId)
                .filter(Column("stage") == stage.rawValue)
                .fetchAll(db)

            // Tombstone rather than delete, so the removal syncs.
            for var note in existing where !keys.contains(note.descriptorKey) {
                note.softDelete()
                try note.save(db)
            }

            let kept = Set(existing.filter { !$0.isDeleted }.map(\.descriptorKey))
            for key in keys where !kept.contains(key) {
                // Revive a previously removed pick rather than inserting a
                // duplicate row for the same descriptor.
                if var tombstoned = existing.first(where: { $0.descriptorKey == key }) {
                    tombstoned.deletedAt = nil
                    try tombstoned.saveLocal(db)
                } else {
                    var note = TastingNote(
                        tastingId: tastingId, stage: stage, descriptorKey: key)
                    try note.saveLocal(db)
                }
            }
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
            let keys = descriptors[stage] ?? []
            let existing = try TastingNote
                .live()
                .filter(Column("tasting_id") == tastingId)
                .filter(Column("stage") == stage.rawValue)
                .fetchAll(db)

            for var note in existing where !keys.contains(note.descriptorKey) {
                note.softDelete()
                try note.save(db)
            }
            let kept = Set(existing.filter { !$0.isDeleted }.map(\.descriptorKey))
            for key in keys where !kept.contains(key) {
                var note = TastingNote(tastingId: tastingId, stage: stage, descriptorKey: key)
                try note.saveLocal(db)
            }
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
