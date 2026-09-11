import Foundation
import GRDB
import LiquorEngine

/// Bottles you want, and the price you would pay for them.
///
/// The target price is the point. A wishlist without one is a list of names you
/// already remember; with one it answers the question you actually have in the
/// aisle — *I want this, but not at that price.*
public struct WishlistRepository: Sendable {
    private let db: AppDatabase

    public init(_ db: AppDatabase) { self.db = db }

    // MARK: - Reading

    public func items() throws -> [WishlistItem] {
        try db.queue.read { db in
            try WishlistItem
                .live()
                .order(Column("created_at").desc)
                .fetchAll(db)
        }
    }

    /// Whether a product is already on the list, so a screen can offer "add"
    /// or "remove" rather than silently creating a second copy.
    public func item(catalogProductId: String) throws -> WishlistItem? {
        try db.queue.read { db in
            try WishlistItem
                .live()
                .filter(Column("catalog_product_id") == catalogProductId)
                .fetchOne(db)
        }
    }

    // MARK: - Writing

    /// Adds a product, or revives it if it was removed before.
    ///
    /// Reviving rather than inserting matters because removal is a tombstone,
    /// not a delete: a plain insert would leave two rows for one bottle and the
    /// list would show it twice.
    @discardableResult
    public func add(
        catalogProductId: String? = nil,
        customName: String? = nil,
        targetPriceCents: Int? = nil,
        note: String? = nil
    ) throws -> WishlistItem {
        try db.queue.write { db in
            if let catalogProductId {
                // ALL rows, tombstones included -- that is the point.
                let existing = try WishlistItem
                    .filter(Column("catalog_product_id") == catalogProductId)
                    .fetchOne(db)
                if var found = existing {
                    found.deletedAt = nil
                    found.targetPriceCents = targetPriceCents ?? found.targetPriceCents
                    found.note = note ?? found.note
                    try found.saveLocal(db)
                    return found
                }
            }

            var item = WishlistItem(
                catalogProductId: catalogProductId,
                customName: customName,
                targetPriceCents: targetPriceCents,
                note: note)
            try item.saveLocal(db)
            return item
        }
    }

    @discardableResult
    public func setTargetPrice(id: String, cents: Int?) throws -> WishlistItem? {
        try db.queue.write { db in
            guard var item = try WishlistItem.filter(key: id).fetchOne(db) else { return nil }
            item.targetPriceCents = cents
            try item.saveLocal(db)
            return item
        }
    }

    /// Soft delete, like everything else here.
    public func remove(id: String) throws {
        try db.queue.write { db in
            guard var item = try WishlistItem.filter(key: id).fetchOne(db) else { return }
            item.softDelete()
            try item.save(db)
        }
    }

    /// Buying a wishlisted bottle: adds it to the collection and takes it off
    /// the list, in ONE transaction.
    ///
    /// Two steps would be worse than one. Getting a bottle and still seeing it
    /// on your wishlist is the exact drift that stops people trusting a list,
    /// and it is the failure mode the shelf walk exists to repair.
    ///
    /// - Parameter product: for a wishlist entry that was only a typed name,
    ///   the private catalogue entry to create alongside the bottle, so the
    ///   shelf check can answer for it exactly like a bottle typed in by hand.
    ///   Saved in the same transaction: a product without its bottle or a
    ///   bottle without its product is the orphan `addCustom` exists to avoid.
    @discardableResult
    public func buy(
        _ item: WishlistItem,
        as bottle: Bottle,
        creating product: CustomCatalogEntry? = nil
    ) throws -> Bottle {
        var saved = bottle
        if saved.catalogProductId == nil { saved.catalogProductId = item.catalogProductId }
        if let product { saved.catalogProductId = product.id }
        if saved.catalogProductId == nil && saved.customName == nil {
            saved.customName = item.customName
        }

        var wish = item
        wish.softDelete()

        try db.queue.write { db in
            if var product {
                try product.saveLocal(db)
            }
            try saved.saveLocal(db)
            try wish.save(db)
        }
        return saved
    }
}

extension WishlistItem {
    /// Whether an asking price meets what you said you would pay.
    ///
    /// Nil when no target was set, which is honest: without one there is no
    /// question to answer, and inventing a verdict would be the app having an
    /// opinion nobody asked it for.
    public func meetsTarget(askingCents: Int) -> Bool? {
        guard let target = targetPriceCents else { return nil }
        return askingCents <= target
    }
}
