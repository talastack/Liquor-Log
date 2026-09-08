import Foundation
import GRDB
import LiquorEngine

/// Exports the whole collection as CSV.
///
/// **Free, always, and prominent.** People in this category have been burned —
/// apps losing collections, accounts vanishing, years of entry gone — and the
/// advice they give each other is to be wary of anything that will not let you
/// export. It costs almost nothing to build and it is the strongest trust
/// signal available.
///
/// It also has to be genuinely complete. An export missing the barrel fields
/// would be worse than none: it would look like a backup and not be one.
public struct CollectionExport: Sendable {
    private let db: AppDatabase

    public init(_ db: AppDatabase) { self.db = db }

    /// Column order is deliberate: identity, then status, then the barrel
    /// detail, then money, then notes. It reads left to right the way somebody
    /// would describe a bottle out loud.
    public static let header = [
        "name", "distillery", "brand", "expression",
        "class", "production", "status",
        "size_ml", "abv", "proof",
        "batch", "barrel", "store_pick", "pick_group", "pick_store",
        "warehouse", "rick", "floor", "recipe_code",
        "age_months", "entry_proof", "char_level", "finish",
        "bottle_number", "bottles_in_batch",
        "distilled_year", "bottled_year", "vintage_year",
        "purchased", "opened", "killed",
        "price", "bought_at", "storage_location", "shelf_number",
        "pours_remaining", "pours_total", "ml_remaining", "cost_per_pour",
        "rating", "would_rebuy", "liked", "disliked",
    ]

    public func csv(
        resolveName: (Bottle) -> String,
        resolveIdentity: (String) -> ProductIdentity?
    ) throws -> String {
        let bottles = BottleRepository(db)
        let tastings = TastingRepository(db)

        // Killed bottles are INCLUDED. They are archived, not deleted, and a
        // backup that silently drops your history is not a backup.
        let summaries = try bottles.summaries(includeFinished: true)

        let rows: [[String]] = try summaries.map { summary in
            let bottle = summary.bottle
            let identity = bottle.catalogProductId.flatMap(resolveIdentity)
            let latest = try tastings.history(bottleId: bottle.id).first

            return [
                resolveName(bottle),
                CSVWriter.text(identity?.distillery),
                CSVWriter.text(identity?.brand),
                CSVWriter.text(identity?.expression),
                CSVWriter.text(identity?.classType.label),
                CSVWriter.text(identity?.productionType.label),
                bottle.status.rawValue,

                CSVWriter.decimal(bottle.volumeMl, places: 0),
                CSVWriter.decimal(bottle.abv),
                CSVWriter.decimal(bottle.abv.map { ABV(percent: $0).proof }),

                CSVWriter.text(bottle.batchNumber),
                CSVWriter.text(bottle.barrelNumber),
                CSVWriter.flag(bottle.isStorePick),
                CSVWriter.text(bottle.pickGroup),
                CSVWriter.text(bottle.pickStore),
                CSVWriter.text(bottle.warehouse),
                CSVWriter.text(bottle.rick),
                CSVWriter.text(bottle.floor),
                CSVWriter.text(bottle.recipeCode),
                CSVWriter.number(bottle.ageMonths),
                CSVWriter.decimal(bottle.entryProof),
                CSVWriter.number(bottle.charLevel),
                CSVWriter.text(bottle.finish),
                CSVWriter.number(bottle.bottleNumber),
                CSVWriter.number(bottle.bottlesInBatch),

                CSVWriter.number(bottle.distilledYear),
                CSVWriter.number(bottle.bottledYear),
                CSVWriter.number(bottle.vintageYear),

                CSVWriter.date(millis: bottle.purchaseDate),
                CSVWriter.date(millis: bottle.openedAt),
                CSVWriter.date(millis: bottle.finishedAt),

                CSVWriter.money(cents: bottle.purchasePriceCents),
                CSVWriter.text(bottle.purchaseStore),
                CSVWriter.text(bottle.storageLocation),
                CSVWriter.number(bottle.shelfNumber),

                CSVWriter.number(summary.status.remainingPours),
                CSVWriter.number(summary.status.totalPours),
                CSVWriter.decimal(summary.status.remainingMilliliters, places: 0),
                CSVWriter.money(cents: summary.costPerPourCents),

                CSVWriter.number(latest?.tasting.rating),
                CSVWriter.text(latest?.tasting.wouldRebuy?.rawValue),
                CSVWriter.text(latest?.tasting.liked),
                CSVWriter.text(latest?.tasting.disliked),
            ]
        }

        return CSVWriter.document(header: Self.header, rows: rows)
    }

    /// Writes the export to a file and returns its URL, for a share sheet.
    public func write(
        to directory: URL,
        resolveName: (Bottle) -> String,
        resolveIdentity: (String) -> ProductIdentity?
    ) throws -> URL {
        let contents = try csv(resolveName: resolveName, resolveIdentity: resolveIdentity)
        let stamp = ISO8601DateFormatter().string(from: Date()).prefix(10)
        let url = directory.appendingPathComponent("liquor-log-\(stamp).csv")
        try contents.write(to: url, atomically: true, encoding: .utf8)
        return url
    }

    /// What the user has, for a bottle chooser. Last-poured comes from the pour
    /// log rather than a stored column, like every other derived number here.
    public func pourCandidates() throws -> [PickMyPour.Candidate] {
        let bottles = try BottleRepository(db).summaries()
        return try db.queue.read { db in
            try bottles.map { summary in
                let last = try Pour
                    .live()
                    .filter(Column("bottle_id") == summary.id)
                    .order(Column("poured_at").desc)
                    .fetchOne(db)

                return PickMyPour.Candidate(
                    id: summary.id,
                    name: summary.bottle.customName ?? summary.id,
                    lastPouredAt: last.map {
                        Date(timeIntervalSince1970: Double($0.pouredAt) / 1000)
                    },
                    isOpen: summary.bottle.isOpen,
                    remainingMilliliters: summary.status.remainingMilliliters)
            }
        }
    }
}
