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
        "sample", "sample_from", "sample_source", "infinity",
        "size_ml", "abv", "proof", "chill_filtered",
        "batch", "barrel", "store_pick", "pick_group", "pick_store",
        "warehouse", "rick", "floor", "recipe_code",
        "age_months", "entry_proof", "char_level", "finish",
        "bottle_number", "bottles_in_batch", "topper_letter", "wax_color", "drip_percent", "stave_recipe", "dsp",
        "distilled_year", "bottled_year", "vintage_year",
        "purchased", "opened", "killed", "last_poured", "last_verified",
        "price", "bought_at", "storage_location", "shelf_number",
        "pours_remaining", "pours_total", "ml_remaining", "cost_per_pour",
        "rating", "would_rebuy", "finish_seconds", "liked", "disliked",
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

                CSVWriter.flag(bottle.isSample),
                CSVWriter.text(bottle.sampleFrom),
                CSVWriter.text(bottle.sampleSource?.rawValue),
                CSVWriter.flag(bottle.isInfinity),

                CSVWriter.decimal(bottle.volumeMl, places: 0),
                CSVWriter.decimal(bottle.abv),
                CSVWriter.decimal(bottle.abv.map { ABV(percent: $0).proof }),
                bottle.chillFiltered.map { $0 ? "yes" : "no" } ?? "",

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
                CSVWriter.text(bottle.topperLetter),
                CSVWriter.text(bottle.waxColor?.rawValue),
                CSVWriter.number(bottle.dripFraction.map { Int(($0 * 100).rounded()) }),
                CSVWriter.text(bottle.staveRecipe),
                CSVWriter.text(bottle.dsp),

                CSVWriter.number(bottle.distilledYear),
                CSVWriter.number(bottle.bottledYear),
                CSVWriter.number(bottle.vintageYear),

                CSVWriter.date(millis: bottle.purchaseDate),
                CSVWriter.date(millis: bottle.openedAt),
                CSVWriter.date(millis: bottle.finishedAt),
                CSVWriter.date(millis: summary.lastPouredAt.map {
                    Int64($0.timeIntervalSince1970 * 1000)
                }),
                CSVWriter.date(millis: bottle.lastVerifiedAt),

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
                CSVWriter.number(latest?.tasting.finishSeconds),
                CSVWriter.text(latest?.tasting.liked),
                CSVWriter.text(latest?.tasting.disliked),
            ]
        }

        return CSVWriter.document(header: Self.header, rows: rows)
    }

    // MARK: - The rest of the record

    /// Every tasting, one row each, with the wheel picks per stage. The
    /// bottle export carries only the latest tasting; a person with three
    /// years of notes on one bottle needs all three.
    public static let tastingsHeader = [
        "date", "bottle", "product", "distillery", "rating", "blind",
        "would_rebuy", "worth_the_price", "heat", "finish_seconds",
        "source", "source_note", "liked", "disliked",
        "nose", "entry", "mid", "finish",
    ]

    public func tastingsCSV(
        resolveName: (Bottle) -> String,
        resolveIdentity: (String) -> ProductIdentity?,
        word: (String) -> String = { $0 }
    ) throws -> String {
        let bottles = BottleRepository(db)
        let names = Dictionary(
            try bottles.summaries(includeFinished: true).map { ($0.id, resolveName($0.bottle)) },
            uniquingKeysWith: { a, _ in a })
        let rows: [[String]] = try TastingRepository(db).allDetails().map { detail in
            let t = detail.tasting
            let identity = t.catalogProductId.flatMap(resolveIdentity)
            func stage(_ s: TastingStage) -> String {
                detail.descriptors(on: s).map(word).joined(separator: "; ")
            }
            return [
                CSVWriter.date(millis: t.tastedAt),
                CSVWriter.text(t.bottleId.flatMap { names[$0] }),
                CSVWriter.text(identity?.displayName),
                CSVWriter.text(identity?.distillery),
                CSVWriter.number(t.rating),
                CSVWriter.flag(t.blind),
                CSVWriter.text(t.wouldRebuy?.rawValue),
                t.worthThePrice.map { $0 ? "yes" : "no" } ?? "",
                CSVWriter.number(t.perceivedHeat),
                CSVWriter.number(t.finishSeconds),
                CSVWriter.text(t.source?.rawValue),
                CSVWriter.text(t.sourceNote),
                CSVWriter.text(t.liked),
                CSVWriter.text(t.disliked),
                stage(.nose), stage(.entry), stage(.mid), stage(.finish),
            ]
        }
        return CSVWriter.document(header: Self.tastingsHeader, rows: rows)
    }

    /// Every pour, one row each: the record the fill levels are derived
    /// from, and who a pour went to.
    public static let poursHeader = ["date", "bottle", "ml", "given_to", "into", "note"]

    public func poursCSV(resolveName: (Bottle) -> String) throws -> String {
        let bottles = BottleRepository(db)
        let names = Dictionary(
            try bottles.summaries(includeFinished: true).map { ($0.id, resolveName($0.bottle)) },
            uniquingKeysWith: { a, _ in a })
        let rows: [[String]] = try bottles.pours().map { pour in
            [
                CSVWriter.date(millis: pour.pouredAt),
                CSVWriter.text(names[pour.bottleId]),
                CSVWriter.decimal(pour.volumeMl, places: 1),
                CSVWriter.text(pour.givenTo),
                CSVWriter.text(pour.intoBottleId.flatMap { names[$0] }),
                CSVWriter.text(pour.note),
            ]
        }
        return CSVWriter.document(header: Self.poursHeader, rows: rows)
    }

    /// The hunt log, one row per sighting or lottery entry.
    public static let huntLogHeader = [
        "date", "kind", "product", "store", "region", "price", "count", "outcome", "bought", "note",
    ]

    public func huntLogCSV(
        resolveIdentity: (String) -> ProductIdentity?
    ) throws -> String {
        let rows: [[String]] = try SightingRepository(db).all().map { row in
            [
                CSVWriter.date(millis: row.seenAt),
                row.kind.rawValue,
                CSVWriter.text(row.catalogProductId.flatMap(resolveIdentity)?.displayName ?? row.customName),
                row.store,
                CSVWriter.text(row.region),
                CSVWriter.money(cents: row.cents),
                CSVWriter.number(row.count),
                CSVWriter.text(row.outcome?.rawValue),
                CSVWriter.flag(row.bottleId != nil),
                CSVWriter.text(row.note),
            ]
        }
        return CSVWriter.document(header: Self.huntLogHeader, rows: rows)
    }

    /// The passport, one row per visit.
    public static let visitsHeader = ["date", "distillery", "note"]

    public func visitsCSV() throws -> String {
        let rows: [[String]] = try VisitRepository(db).all().map { row in
            [CSVWriter.date(millis: row.visitedAt), row.distillery, CSVWriter.text(row.note)]
        }
        return CSVWriter.document(header: Self.visitsHeader, rows: rows)
    }

    /// Everything, as files: the bottles always, and the tastings, pours,
    /// hunt log and visits when there are any. Returns the URLs for a share sheet.
    public func writeAll(
        to directory: URL,
        resolveName: (Bottle) -> String,
        resolveIdentity: (String) -> ProductIdentity?,
        word: (String) -> String = { $0 }
    ) throws -> [URL] {
        let stamp = ISO8601DateFormatter().string(from: Date()).prefix(10)
        var urls = [try write(to: directory, resolveName: resolveName, resolveIdentity: resolveIdentity)]
        let extras: [(String, String)] = [
            ("tastings", try tastingsCSV(resolveName: resolveName, resolveIdentity: resolveIdentity, word: word)),
            ("pours", try poursCSV(resolveName: resolveName)),
            ("hunt-log", try huntLogCSV(resolveIdentity: resolveIdentity)),
            ("visits", try visitsCSV()),
        ]
        // A header alone is one line; anything recorded makes two. (CRLF is
        // one Character in Swift, so this is a string split, not a Character one.)
        for (name, contents) in extras where contents.components(separatedBy: "\r\n").filter({ !$0.isEmpty }).count > 1 {
            let url = directory.appendingPathComponent("pour-memo-\(name)-\(stamp).csv")
            try contents.write(to: url, atomically: true, encoding: .utf8)
            urls.append(url)
        }
        return urls
    }

    /// Writes the export to a file and returns its URL, for a share sheet.
    public func write(
        to directory: URL,
        resolveName: (Bottle) -> String,
        resolveIdentity: (String) -> ProductIdentity?
    ) throws -> URL {
        let contents = try csv(resolveName: resolveName, resolveIdentity: resolveIdentity)
        let stamp = ISO8601DateFormatter().string(from: Date()).prefix(10)
        let url = directory.appendingPathComponent("pour-memo-\(stamp).csv")
        try contents.write(to: url, atomically: true, encoding: .utf8)
        return url
    }

    /// What the user has, for a bottle chooser. Last-poured comes from the pour
    /// log rather than a stored column, like every other derived number here.
    public func pourCandidates(
        resolveName: (Bottle) -> String = { $0.customName ?? $0.id }
    ) throws -> [PickMyPour.Candidate] {
        try BottleRepository(db).summaries().map { summary in
            PickMyPour.Candidate(
                id: summary.id,
                name: resolveName(summary.bottle),
                lastPouredAt: summary.lastPouredAt,
                isOpen: summary.bottle.isOpen,
                remainingMilliliters: summary.status.remainingMilliliters)
        }
    }
}
