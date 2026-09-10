import Foundation
import GRDB
import LiquorEngine

/// Writes an import plan into the collection.
///
/// `CollectionImport` in the engine decides what the spreadsheet meant. This
/// decides how it lands, and its one rule is that **the whole file lands or
/// none of it does.** A crash on row 140 of 200 would otherwise leave a
/// collection that is 70% imported with no way to tell which 70%, and the only
/// remedy would be finding and deleting 140 bottles by hand.
public struct CollectionImporter: Sendable {
    private let db: AppDatabase

    public init(_ db: AppDatabase) { self.db = db }

    public struct Outcome: Sendable, Equatable {
        public let imported: Int
        /// Rows whose name matched a catalogue product, so they behave like
        /// catalogue bottles in the shelf check.
        public let matchedToCatalog: Int
        public let skippedLines: [Int]
    }

    /// Lands every row in ONE transaction.
    ///
    /// - Parameter resolve: maps a name to a catalogue product id, or nil. The
    ///   engine's search lives in the app layer with the bundled catalogue, so
    ///   the caller supplies it. Only a confident match should come back —
    ///   attaching a spreadsheet row to the wrong product is worse than
    ///   leaving it as a custom bottle, because the shelf check then answers
    ///   for a whiskey the person does not own.
    @discardableResult
    public func apply(
        _ plan: CollectionImport.Plan,
        resolve: (String) -> String?
    ) throws -> Outcome {
        var matched = 0
        let now = Bottle.nowMilliseconds()

        try db.queue.write { db in
            for row in plan.rows {
                let productId = resolve(row.name)
                if productId != nil { matched += 1 }

                var bottle = Bottle(
                    catalogProductId: productId,
                    customName: productId == nil ? row.name : nil,
                    isStorePick: row.barrel != nil,
                    barrelNumber: row.barrel,
                    batchNumber: row.batch,
                    abv: row.proof.map { $0 / 2 },
                    volumeMl: row.volumeMilliliters ?? 750,
                    purchasePriceCents: row.paidCents,
                    purchaseStore: row.store,
                    storageLocation: row.storageLocation,
                    // Open and finished are states the spreadsheet asserted.
                    // The DATES are unknown, so they are set to now rather
                    // than invented: "opened at some point" is true, and a
                    // fabricated date would corrupt the oxidation clock.
                    openedAt: (row.isOpen || row.isFinished) ? now : nil,
                    finishedAt: row.isFinished ? now : nil)

                if productId == nil {
                    // A private product, so the shelf check can still answer
                    // for it -- same path as typing a bottle in by hand.
                    var product = CustomCatalogEntry(
                        distillery: row.name, brand: row.name, classType: .bourbon)
                    try product.saveLocal(db)
                    bottle.catalogProductId = product.id
                }
                try bottle.saveLocal(db)
            }
        }

        return Outcome(
            imported: plan.rows.count,
            matchedToCatalog: matched,
            skippedLines: plan.skippedLines)
    }
}
