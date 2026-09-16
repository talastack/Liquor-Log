import Foundation
import GRDB
import LiquorEngine

/// Spirit or beer. A storage discriminator, kept apart from `ClassType`, which
/// says what the liquid legally is.
public enum BeverageCategory: String, Codable, Sendable, CaseIterable, DatabaseValueConvertible {
    case spirit
    case beer
}

public enum Rebuy: String, Codable, Sendable, CaseIterable, DatabaseValueConvertible {
    case yes
    case maybe
    case no
}

/// Where a tasting happened when it was not your own bottle. Mirrors the
/// `source_is_known` check in the Postgres schema.
public enum TastingSource: String, Codable, Sendable, CaseIterable, DatabaseValueConvertible {
    case bar
    case friend
    case sample
    case store
    case event
    case other

    public var label: String {
        switch self {
        case .bar: return "At a bar"
        case .friend: return "A friend's bottle"
        case .sample: return "A sample"
        case .store: return "In-store tasting"
        case .event: return "An event"
        case .other: return "Somewhere else"
        }
    }
}

/// How a sample came to be on your shelf. Mirrors `sample_source_is_known`
/// in the Postgres schema.
public enum SampleSource: String, Codable, Sendable, CaseIterable, DatabaseValueConvertible {
    case gift
    case swap
    case bought
    case decant

    public var label: String {
        switch self {
        case .gift: return "From a friend"
        case .swap: return "A swap"
        case .bought: return "Bought"
        case .decant: return "Poured off my own bottle"
        }
    }
}

public enum TastingStage: String, Codable, Sendable, CaseIterable, DatabaseValueConvertible {
    case nose
    case entry
    case mid
    case finish
}

#if compiler(>=6.0)
extension WaxDrip.Color: @retroactive DatabaseValueConvertible {}
#else
extension WaxDrip.Color: DatabaseValueConvertible {}
#endif

// Engine vocabularies are stored by their raw values, so the database and the
// validation rules cannot describe different worlds.
//
// Retroactive because LiquorEngine must not depend on GRDB -- that is the whole
// point of it having no dependencies. The compiler guard is for Xcode 15, whose
// Swift 5.9 cannot parse the @retroactive attribute at all.
#if compiler(>=6.0)
extension ClassType: @retroactive DatabaseValueConvertible {}
extension ProductionType: @retroactive DatabaseValueConvertible {}
#else
extension ClassType: DatabaseValueConvertible {}
extension ProductionType: DatabaseValueConvertible {}
#endif

// MARK: - custom_catalog_entries

/// A product the user added themselves.
///
/// The BUNDLED catalog is not a record type at all: it loads read-only from
/// `shared/data/spirits.v1.json`. A bottle's `catalogProductId` resolves against
/// the bundled catalog first and these rows second.
public struct CustomCatalogEntry: SyncableRecord {
    public static let databaseTableName = "custom_catalog_entries"

    public var id: String
    public var userId: String?
    public var distillery: String
    public var brand: String
    public var expression: String
    public var classType: ClassType
    public var productionType: ProductionType
    public var isBarrelProof: Bool
    public var isBottledInBond: Bool
    public var abv: Double?
    public var statedAgeYears: Int?
    public var recipeCode: String?

    /// A published SHELF price and where it came from -- a control board's
    /// posted price, or a producer's stated SRP. Never a resale value, and the
    /// database refuses a figure with no source.
    public var msrpCents: Int?
    public var msrpSource: String?
    public var msrpAsOfYear: Int?

    public var createdAt: Int64
    public var updatedAt: Int64
    public var deletedAt: Int64?
    public var dirty: Bool

    enum CodingKeys: String, CodingKey {
        case id, userId = "user_id", distillery, brand, expression
        case classType = "class_type", productionType = "production_type"
        case isBarrelProof = "is_barrel_proof", isBottledInBond = "is_bottled_in_bond"
        case abv, statedAgeYears = "stated_age_years", recipeCode = "recipe_code"
        case msrpCents = "msrp_cents", msrpSource = "msrp_source"
        case msrpAsOfYear = "msrp_as_of_year"
        case createdAt = "created_at", updatedAt = "updated_at"
        case deletedAt = "deleted_at", dirty
    }

    public init(
        id: String = UUID().uuidString,
        userId: String? = nil,
        distillery: String,
        brand: String,
        expression: String = "",
        classType: ClassType,
        productionType: ProductionType = .unspecified,
        isBarrelProof: Bool = false,
        isBottledInBond: Bool = false,
        abv: Double? = nil,
        statedAgeYears: Int? = nil,
        recipeCode: String? = nil,
        msrpCents: Int? = nil,
        msrpSource: String? = nil,
        msrpAsOfYear: Int? = nil,
        createdAt: Int64 = Self.nowMilliseconds(),
        updatedAt: Int64 = Self.nowMilliseconds(),
        deletedAt: Int64? = nil,
        dirty: Bool = true
    ) {
        self.id = id; self.userId = userId
        self.distillery = distillery; self.brand = brand; self.expression = expression
        self.classType = classType; self.productionType = productionType
        self.isBarrelProof = isBarrelProof; self.isBottledInBond = isBottledInBond
        self.abv = abv; self.statedAgeYears = statedAgeYears; self.recipeCode = recipeCode
        self.msrpCents = msrpCents; self.msrpSource = msrpSource
        self.msrpAsOfYear = msrpAsOfYear
        self.createdAt = createdAt; self.updatedAt = updatedAt
        self.deletedAt = deletedAt; self.dirty = dirty
    }

    /// The shelf-price reference, if this product has one. Nil is the honest
    /// answer for anything with no published figure.
    public var priceReference: PriceReference? {
        guard let cents = msrpCents, let source = msrpSource else { return nil }
        return PriceReference(cents: cents, source: source, asOfYear: msrpAsOfYear)
    }

    /// Validated against the same federal rules the engine enforces, so a bad
    /// row cannot be written by a screen that forgot to check.
    public var validationIssues: [Classification.Issue] {
        Classification.validate(
            classType: classType,
            abv: abv.map { ABV(percent: $0) },
            statedAgeYears: statedAgeYears,
            isBottledInBond: isBottledInBond,
            volumeMilliliters: nil
        )
    }
}

// MARK: - bottles

/// The physical bottle. Product facts live on the catalog entry; the RELEASE —
/// batch, pick, barrel, measured proof, vintage — lives here, because you only
/// ever meet a release through a bottle.
public struct Bottle: SyncableRecord {
    public static let databaseTableName = "bottles"

    public var id: String
    public var userId: String?
    public var catalogProductId: String?
    public var category: BeverageCategory
    public var customName: String?

    public var isStorePick: Bool
    public var pickStore: String?
    public var pickName: String?
    public var barrelNumber: String?
    public var batchNumber: String?

    /// What a store pick actually prints, and what most apps drop.
    ///
    /// `pickGroup` is who SELECTED the barrel, which is often not who sells it
    /// -- a club, a bar or a society picks it and a shop puts it on the shelf.
    public var pickGroup: String?
    public var warehouse: String?
    public var rick: String?
    public var floor: String?
    /// Bottle-level recipe code. A Four Roses pick prints its code on THIS
    /// label and it differs barrel to barrel, so it overrides the product's.
    public var recipeCode: String?
    /// Age at bottling in months: a single barrel is 9 years 4 months, and
    /// rounding that to 9 throws away the thing it was picked for.
    public var ageMonths: Int?
    public var entryProof: Double?
    public var charLevel: Int?
    public var finish: String?
    public var bottleNumber: Int?
    public var bottlesInBatch: Int?
    /// Dump date, often the only date on a single-barrel label.
    public var dumpedAt: Int64?

    /// MEASURED strength of this bottle, which for a barrel-proof release
    /// differs from the catalog's standard figure batch to batch.
    public var abv: Double?

    /// Nil means the label does not say, which is the usual case: producers who
    /// skip chill filtration advertise it, and everyone else stays quiet.
    public var chillFiltered: Bool?

    public var distilledYear: Int?
    public var bottledYear: Int?
    public var vintageYear: Int?

    public var volumeMl: Double
    public var pourSizeMl: Double

    public var purchaseDate: Int64?
    public var purchasePriceCents: Int?
    public var purchaseStore: String?

    /// The price ON THE SHELF, which is not always what you paid.
    ///
    /// This is the app's price reference, and it belongs to the user. Every
    /// third-party price source carries a licensing question; what somebody
    /// wrote down about a shelf they stood in front of carries none.
    public var shelfPriceCents: Int?

    /// The barcode on this bottle, once somebody has scanned it.
    ///
    /// A shortcut, never an identity: a UPC identifies a SKU and cannot
    /// identify a barrel. Scanning answers "you have this line" and never
    /// "you own this barrel".
    public var barcode: String?

    /// The letter on a Blanton's cork topper -- one of the eight that spell
    /// BLANTONS, the second N stored as "N:" as Blanton's marks it.
    /// Free text so another brand's set needs no migration; the engine's
    /// `TopperLetters` knows which letters make a set.
    public var topperLetter: String?

    /// The file name of this bottle's photo on the device that took it. The
    /// name syncs, the bytes stay on the device.
    public var photoFile: String?

    /// The wax on a Maker's Mark, measured from a photo -- see `WaxDrip`.
    /// The fraction is drip over bottle height; millimetres only when the
    /// person typed the bottle's real height.
    public var waxColor: WaxDrip.Color?
    public var dripFraction: Double?
    public var dripLengthMm: Double?

    /// A Maker's Private Select stave recipe, in `StaveRecipe`'s compact
    /// form. Text so a future programme with other staves needs no
    /// migration; `staves` reads it back validated.
    public var staveRecipe: String?

    /// The federal permit number on the back label, normalised
    /// ("DSP-KY-113"). `DistilleryPermit.lookup` says whose it is.
    public var dsp: String?

    /// Where the bottle physically is. Collections scatter across closets and
    /// boxes, and people report this mattering more than remembering what they
    /// own at all.
    public var storageLocation: String?

    /// The user's OWN number, keyed to a sticker on the glass. Distinct from
    /// `bottleNumber`, which is the "47 of 240" the pick was bottled with. This
    /// is what bridges a shelf to a database.
    public var shelfNumber: Int?

    /// A sample -- two ounces from a friend, a swap, a sample set -- rather
    /// than a bottle. Every serious collector's spreadsheet has a samples
    /// tab; no app models one. A sample pours, tastes and finishes like a
    /// bottle, and is kept out of the bottle counts and off the guest menu.
    public var isSample: Bool
    /// Who it came from, in their words: "Mike", "the Louisville swap".
    public var sampleFrom: String?
    public var sampleSource: SampleSource?

    /// An infinity bottle: filled from other bottles, never from a shop.
    /// It has no catalogue product; what is in it is the `blend_additions`
    /// against it, and `abv` is kept equal to the blend's strength so every
    /// screen that reads a bottle's proof reads the right one.
    public var isInfinity: Bool

    /// The empty bottle's weight in grams -- glass, cork, label -- worked
    /// out from one weighing at a known level. With it and the proof, any
    /// later weighing is a fill level to a few millilitres. See `Weighing`.
    public var tareGrams: Double?

    public var openedAt: Int64?
    public var finishedAt: Int64?

    /// Last time somebody laid eyes on this bottle during a shelf walk. Every
    /// collection record decays; this is what orders the walk that fixes it.
    public var lastVerifiedAt: Int64?

    public var createdAt: Int64
    public var updatedAt: Int64
    public var deletedAt: Int64?
    public var dirty: Bool

    enum CodingKeys: String, CodingKey {
        case id, userId = "user_id", catalogProductId = "catalog_product_id"
        case category, customName = "custom_name"
        case isStorePick = "is_store_pick", pickStore = "pick_store", pickName = "pick_name"
        case barrelNumber = "barrel_number", batchNumber = "batch_number"
        case pickGroup = "pick_group", warehouse, rick, floor
        case recipeCode = "recipe_code"
        case ageMonths = "age_months", entryProof = "entry_proof"
        case charLevel = "char_level", finish
        case bottleNumber = "bottle_number", bottlesInBatch = "bottles_in_batch"
        case dumpedAt = "dumped_at"
        case abv, chillFiltered = "chill_filtered"
        case distilledYear = "distilled_year", bottledYear = "bottled_year"
        case vintageYear = "vintage_year"
        case volumeMl = "volume_ml", pourSizeMl = "pour_size_ml"
        case purchaseDate = "purchase_date", purchasePriceCents = "purchase_price_cents"
        case purchaseStore = "purchase_store"
        case shelfPriceCents = "shelf_price_cents"
        case barcode
        case topperLetter = "topper_letter", photoFile = "photo_file"
        case waxColor = "wax_color", dripFraction = "drip_fraction", dripLengthMm = "drip_length_mm"
        case staveRecipe = "stave_recipe", dsp
        case storageLocation = "storage_location", shelfNumber = "shelf_number"
        case isSample = "is_sample", sampleFrom = "sample_from", sampleSource = "sample_source"
        case isInfinity = "is_infinity", tareGrams = "tare_grams"
        case openedAt = "opened_at", finishedAt = "finished_at"
        case lastVerifiedAt = "last_verified_at"
        case createdAt = "created_at", updatedAt = "updated_at"
        case deletedAt = "deleted_at", dirty
    }

    public init(
        id: String = UUID().uuidString,
        userId: String? = nil,
        catalogProductId: String? = nil,
        category: BeverageCategory = .spirit,
        customName: String? = nil,
        isStorePick: Bool = false,
        pickStore: String? = nil,
        pickName: String? = nil,
        barrelNumber: String? = nil,
        batchNumber: String? = nil,
        pickGroup: String? = nil,
        warehouse: String? = nil,
        rick: String? = nil,
        floor: String? = nil,
        recipeCode: String? = nil,
        ageMonths: Int? = nil,
        entryProof: Double? = nil,
        charLevel: Int? = nil,
        finish: String? = nil,
        bottleNumber: Int? = nil,
        bottlesInBatch: Int? = nil,
        dumpedAt: Int64? = nil,
        abv: Double? = nil,
        chillFiltered: Bool? = nil,
        distilledYear: Int? = nil,
        bottledYear: Int? = nil,
        vintageYear: Int? = nil,
        volumeMl: Double = 750,
        pourSizeMl: Double = PourSize.standard.milliliters,
        purchaseDate: Int64? = nil,
        purchasePriceCents: Int? = nil,
        purchaseStore: String? = nil,
        shelfPriceCents: Int? = nil,
        barcode: String? = nil,
        topperLetter: String? = nil,
        photoFile: String? = nil,
        waxColor: WaxDrip.Color? = nil,
        dripFraction: Double? = nil,
        dripLengthMm: Double? = nil,
        staveRecipe: String? = nil,
        dsp: String? = nil,
        storageLocation: String? = nil,
        shelfNumber: Int? = nil,
        isSample: Bool = false,
        sampleFrom: String? = nil,
        sampleSource: SampleSource? = nil,
        isInfinity: Bool = false,
        tareGrams: Double? = nil,
        openedAt: Int64? = nil,
        finishedAt: Int64? = nil,
        lastVerifiedAt: Int64? = nil,
        createdAt: Int64 = Self.nowMilliseconds(),
        updatedAt: Int64 = Self.nowMilliseconds(),
        deletedAt: Int64? = nil,
        dirty: Bool = true
    ) {
        self.id = id; self.userId = userId
        self.catalogProductId = catalogProductId; self.category = category
        self.customName = customName
        self.isStorePick = isStorePick; self.pickStore = pickStore; self.pickName = pickName
        self.barrelNumber = barrelNumber; self.batchNumber = batchNumber
        self.pickGroup = pickGroup; self.warehouse = warehouse
        self.rick = rick; self.floor = floor
        self.recipeCode = recipeCode; self.ageMonths = ageMonths
        self.entryProof = entryProof; self.charLevel = charLevel
        self.finish = finish
        self.bottleNumber = bottleNumber; self.bottlesInBatch = bottlesInBatch
        self.dumpedAt = dumpedAt
        self.abv = abv; self.chillFiltered = chillFiltered
        self.distilledYear = distilledYear; self.bottledYear = bottledYear
        self.vintageYear = vintageYear
        self.volumeMl = volumeMl; self.pourSizeMl = pourSizeMl
        self.purchaseDate = purchaseDate; self.purchasePriceCents = purchasePriceCents
        self.purchaseStore = purchaseStore; self.shelfPriceCents = shelfPriceCents
        self.barcode = barcode
        self.topperLetter = topperLetter; self.photoFile = photoFile
        self.waxColor = waxColor; self.dripFraction = dripFraction; self.dripLengthMm = dripLengthMm
        self.staveRecipe = staveRecipe; self.dsp = dsp
        self.storageLocation = storageLocation; self.shelfNumber = shelfNumber
        self.isSample = isSample; self.sampleFrom = sampleFrom; self.sampleSource = sampleSource
        self.isInfinity = isInfinity; self.tareGrams = tareGrams
        self.openedAt = openedAt; self.finishedAt = finishedAt
        self.lastVerifiedAt = lastVerifiedAt
        self.createdAt = createdAt; self.updatedAt = updatedAt
        self.deletedAt = deletedAt; self.dirty = dirty
    }

    /// The barrel's own recipe code where it has one, decoded.
    public var code: RecipeCode? { recipeCode.flatMap(RecipeCode.init) }

    /// "9 years 4 months". Months matter on a single barrel: two picks a few
    /// months apart taste different, which is the whole reason people chase
    /// them.
    public var ageDescription: String? {
        guard let months = ageMonths, months > 0 else { return nil }
        let years = months / 12
        let rest = months % 12
        if years == 0 { return "\(rest) \(rest == 1 ? "month" : "months")" }
        if rest == 0 { return "\(years) \(years == 1 ? "year" : "years")" }
        return "\(years) \(years == 1 ? "year" : "years") \(rest) \(rest == 1 ? "month" : "months")"
    }

    /// "Bottle 47 of 240".
    public var bottleNumberDescription: String? {
        guard let number = bottleNumber else { return nil }
        guard let total = bottlesInBatch else { return "Bottle \(number)" }
        return "Bottle \(number) of \(total)"
    }

    /// True when this bottle carries release detail worth its own section.
    public var hasPickDetail: Bool {
        isStorePick || warehouse != nil || rick != nil || floor != nil
            || recipeCode != nil || ageMonths != nil
            || bottleNumber != nil || entryProof != nil || charLevel != nil
            || finish != nil || pickGroup != nil || dumpedAt != nil
            || topperLetter != nil || staveRecipe != nil
    }

    /// The stave recipe, validated. Nil when none is recorded or the text
    /// does not total ten.
    public var staves: StaveRecipe? { staveRecipe.flatMap { StaveRecipe($0) } }

    /// Sealed, Open or Killed -- the enum every collector's spreadsheet has.
    ///
    /// A killed bottle is ARCHIVED, never deleted: the row keeps its notes, its
    /// price and its dates, and the history is the point of the app.
    public enum Status: String, Sendable, Hashable, CaseIterable {
        case sealed, open, killed

        public var label: String {
            switch self {
            case .sealed: return "Sealed"
            case .open: return "Open"
            case .killed: return "Killed"
            }
        }
    }

    public var status: Status {
        if finishedAt != nil { return .killed }
        return openedAt != nil ? .open : .sealed
    }

    public var isOpen: Bool { status == .open }
    public var isFinished: Bool { status == .killed }
    public var pourSize: PourSize { PourSize(milliliters: pourSizeMl) }

    /// The release label that distinguishes this bottle from another of the
    /// same product: a batch, a pick, or a barrel.
    public var releaseLabel: String? {
        if let pickName, !pickName.isEmpty { return pickName }
        if let barrelNumber, !barrelNumber.isEmpty { return "Barrel \(barrelNumber)" }
        if let batchNumber, !batchNumber.isEmpty { return batchNumber }
        return nil
    }
}

// MARK: - pours

/// One pour. These rows are the source of truth for what is left in the bottle:
/// `remainingMilliliters` is derived from them and is deliberately not a stored
/// column, because a mutable counter beside an event log is a second source of
/// truth that will disagree with the first.
public struct Pour: SyncableRecord {
    public static let databaseTableName = "pours"

    public var id: String
    public var userId: String?
    public var bottleId: String
    public var pouredAt: Int64
    public var volumeMl: Double
    public var note: String?
    /// Who the pour was for, when it was not you: a sample decanted for a
    /// friend, a swap sent off. Nil is your own glass. It is how "samples
    /// given" is answered without a second ledger.
    public var givenTo: String?
    /// The infinity bottle this pour went INTO, when it did. The pour comes
    /// off this bottle like any other; the matching `BlendAddition` puts it
    /// in the other one.
    public var intoBottleId: String?
    public var createdAt: Int64
    public var updatedAt: Int64
    public var deletedAt: Int64?
    public var dirty: Bool

    enum CodingKeys: String, CodingKey {
        case id, userId = "user_id", bottleId = "bottle_id"
        case pouredAt = "poured_at", volumeMl = "volume_ml", note
        case givenTo = "given_to", intoBottleId = "into_bottle_id"
        case createdAt = "created_at", updatedAt = "updated_at"
        case deletedAt = "deleted_at", dirty
    }

    public init(
        id: String = UUID().uuidString,
        userId: String? = nil,
        bottleId: String,
        pouredAt: Int64 = Self.nowMilliseconds(),
        volumeMl: Double,
        note: String? = nil,
        givenTo: String? = nil,
        intoBottleId: String? = nil,
        createdAt: Int64 = Self.nowMilliseconds(),
        updatedAt: Int64 = Self.nowMilliseconds(),
        deletedAt: Int64? = nil,
        dirty: Bool = true
    ) {
        self.id = id; self.userId = userId; self.bottleId = bottleId
        self.pouredAt = pouredAt; self.volumeMl = volumeMl; self.note = note
        self.givenTo = givenTo; self.intoBottleId = intoBottleId
        self.createdAt = createdAt; self.updatedAt = updatedAt
        self.deletedAt = deletedAt; self.dirty = dirty
    }
}

// MARK: - fill_readings

/// "There is this much left in the bottle, and I am looking at it right now."
///
/// The pour log cannot answer that on its own. It assumes every bottle started
/// full and that every pour since was logged, and both are routinely false:
/// people add bottles they opened years ago, and pour for guests without
/// reaching for a phone.
///
/// So the fill is derived as **the latest reading minus the pours logged after
/// it**, with the bottle's capacity standing in when there has never been a
/// reading. Correcting a bottle therefore never rewrites history -- the pours
/// you logged stay logged -- and two readings a year apart are a real record of
/// how fast that bottle went down.
// MARK: - blend_additions

/// One thing that went into an infinity bottle.
///
/// From a bottle on the shelf, it is paired with a `Pour` on that bottle
/// (`pourId`), so the source's fill drops by the same amount and the two
/// undo together. From anywhere else -- a friend's bottle, a sample -- it
/// carries its own name and strength. `abv` is copied at the time of the
/// addition because that is the strength of what went in, whatever the
/// source bottle's record says later.
public struct BlendAddition: SyncableRecord {
    public static let databaseTableName = "blend_additions"

    public var id: String
    public var userId: String?
    /// The infinity bottle.
    public var blendBottleId: String
    /// The bottle it was poured from, when it was one of yours.
    public var sourceBottleId: String?
    /// What to call it when there is no source bottle to resolve.
    public var sourceName: String?
    public var abv: Double?
    public var volumeMl: Double
    public var pourId: String?
    public var addedAt: Int64
    public var note: String?

    public var createdAt: Int64
    public var updatedAt: Int64
    public var deletedAt: Int64?
    public var dirty: Bool

    enum CodingKeys: String, CodingKey {
        case id, userId = "user_id", blendBottleId = "blend_bottle_id"
        case sourceBottleId = "source_bottle_id", sourceName = "source_name"
        case abv, volumeMl = "volume_ml", pourId = "pour_id"
        case addedAt = "added_at", note
        case createdAt = "created_at", updatedAt = "updated_at"
        case deletedAt = "deleted_at", dirty
    }

    public init(
        id: String = UUID().uuidString,
        userId: String? = nil,
        blendBottleId: String,
        sourceBottleId: String? = nil,
        sourceName: String? = nil,
        abv: Double? = nil,
        volumeMl: Double,
        pourId: String? = nil,
        addedAt: Int64 = Self.nowMilliseconds(),
        note: String? = nil,
        createdAt: Int64 = Self.nowMilliseconds(),
        updatedAt: Int64 = Self.nowMilliseconds(),
        deletedAt: Int64? = nil,
        dirty: Bool = true
    ) {
        self.id = id; self.userId = userId; self.blendBottleId = blendBottleId
        self.sourceBottleId = sourceBottleId; self.sourceName = sourceName
        self.abv = abv; self.volumeMl = volumeMl; self.pourId = pourId
        self.addedAt = addedAt; self.note = note
        self.createdAt = createdAt; self.updatedAt = updatedAt
        self.deletedAt = deletedAt; self.dirty = dirty
    }
}

// MARK: - price_reports, drip_reports, menus

/// A shelf price somebody saw, contributed when they chose to. The only
/// price data the app can honestly own: an observation is the observer's
/// to give, it carries no licence, and it says how many it rests on.
public struct PriceReport: SyncableRecord {
    public static let databaseTableName = "price_reports"

    public var id: String
    public var userId: String?
    public var catalogProductId: String
    public var cents: Int
    /// A US state or a country code, coarsely. Nil when not set.
    public var region: String?
    public var seenAt: Int64
    public var createdAt: Int64
    public var updatedAt: Int64
    public var deletedAt: Int64?
    public var dirty: Bool

    enum CodingKeys: String, CodingKey {
        case id, userId = "user_id", catalogProductId = "catalog_product_id"
        case cents, region, seenAt = "seen_at"
        case createdAt = "created_at", updatedAt = "updated_at"
        case deletedAt = "deleted_at", dirty
    }

    public init(
        id: String = UUID().uuidString, userId: String? = nil,
        catalogProductId: String, cents: Int, region: String? = nil,
        seenAt: Int64 = Self.nowMilliseconds(),
        createdAt: Int64 = Self.nowMilliseconds(), updatedAt: Int64 = Self.nowMilliseconds(),
        deletedAt: Int64? = nil, dirty: Bool = true
    ) {
        self.id = id; self.userId = userId; self.catalogProductId = catalogProductId
        self.cents = cents; self.region = region; self.seenAt = seenAt
        self.createdAt = createdAt; self.updatedAt = updatedAt
        self.deletedAt = deletedAt; self.dirty = dirty
    }
}

/// A wax drip measured from a photo, as a fraction of the bottle's height.
public struct DripReport: SyncableRecord {
    public static let databaseTableName = "drip_reports"

    public var id: String
    public var userId: String?
    public var catalogProductId: String
    public var fraction: Double
    public var createdAt: Int64
    public var updatedAt: Int64
    public var deletedAt: Int64?
    public var dirty: Bool

    enum CodingKeys: String, CodingKey {
        case id, userId = "user_id", catalogProductId = "catalog_product_id", fraction
        case createdAt = "created_at", updatedAt = "updated_at"
        case deletedAt = "deleted_at", dirty
    }

    public init(
        id: String = UUID().uuidString, userId: String? = nil,
        catalogProductId: String, fraction: Double,
        createdAt: Int64 = Self.nowMilliseconds(), updatedAt: Int64 = Self.nowMilliseconds(),
        deletedAt: Int64? = nil, dirty: Bool = true
    ) {
        self.id = id; self.userId = userId; self.catalogProductId = catalogProductId
        self.fraction = fraction
        self.createdAt = createdAt; self.updatedAt = updatedAt
        self.deletedAt = deletedAt; self.dirty = dirty
    }
}

/// A published "what's open": the menu as text, under a slug a page is
/// served at. One per person is the normal case; the slug is the link.
public struct HostedMenu: SyncableRecord {
    public static let databaseTableName = "menus"

    public var id: String
    public var userId: String?
    public var slug: String
    public var title: String
    public var body: String
    public var publishedAt: Int64
    public var createdAt: Int64
    public var updatedAt: Int64
    public var deletedAt: Int64?
    public var dirty: Bool

    enum CodingKeys: String, CodingKey {
        case id, userId = "user_id", slug, title, body
        case publishedAt = "published_at"
        case createdAt = "created_at", updatedAt = "updated_at"
        case deletedAt = "deleted_at", dirty
    }

    public init(
        id: String = UUID().uuidString, userId: String? = nil,
        slug: String, title: String, body: String,
        publishedAt: Int64 = Self.nowMilliseconds(),
        createdAt: Int64 = Self.nowMilliseconds(), updatedAt: Int64 = Self.nowMilliseconds(),
        deletedAt: Int64? = nil, dirty: Bool = true
    ) {
        self.id = id; self.userId = userId; self.slug = slug
        self.title = title; self.body = body; self.publishedAt = publishedAt
        self.createdAt = createdAt; self.updatedAt = updatedAt
        self.deletedAt = deletedAt; self.dirty = dirty
    }

    /// A slug nobody can guess: 12 characters from a URL-safe alphabet.
    public static func makeSlug() -> String {
        let alphabet = Array("abcdefghijkmnpqrstuvwxyz23456789")
        return String((0..<12).map { _ in alphabet[Int.random(in: 0..<alphabet.count)] })
    }
}

public struct FillReading: SyncableRecord {
    public static let databaseTableName = "fill_readings"

    public var id: String
    public var userId: String?
    public var bottleId: String

    /// When the level was OBSERVED, which is not necessarily when it was typed
    /// in. Ordering is on this, so a reading backdated to the day a bottle was
    /// opened behaves correctly against the pours logged since.
    public var readAt: Int64

    /// Millilitres, always. A percentage is what somebody may type, but a
    /// percentage stored against a bottle whose size is later corrected would
    /// silently change how much whiskey the app thinks is in it.
    public var remainingMl: Double

    /// How the figure was arrived at, for the user's own benefit: eyeballed
    /// against the label, weighed, measured.
    public var note: String?

    public var createdAt: Int64
    public var updatedAt: Int64
    public var deletedAt: Int64?
    public var dirty: Bool

    enum CodingKeys: String, CodingKey {
        case id, userId = "user_id", bottleId = "bottle_id"
        case readAt = "read_at", remainingMl = "remaining_ml", note
        case createdAt = "created_at", updatedAt = "updated_at"
        case deletedAt = "deleted_at", dirty
    }

    public init(
        id: String = UUID().uuidString,
        userId: String? = nil,
        bottleId: String,
        readAt: Int64 = Self.nowMilliseconds(),
        remainingMl: Double,
        note: String? = nil,
        createdAt: Int64 = Self.nowMilliseconds(),
        updatedAt: Int64 = Self.nowMilliseconds(),
        deletedAt: Int64? = nil,
        dirty: Bool = true
    ) {
        self.id = id; self.userId = userId; self.bottleId = bottleId
        self.readAt = readAt; self.remainingMl = remainingMl; self.note = note
        self.createdAt = createdAt; self.updatedAt = updatedAt
        self.deletedAt = deletedAt; self.dirty = dirty
    }
}

// MARK: - tastings

/// A tasting hangs off a bottle **or** a product.
///
/// Without the product option there is no way to record something you drank at
/// a bar and never owned — and the shelf check has a verdict for exactly that.
public struct Tasting: SyncableRecord {
    public static let databaseTableName = "tastings"

    public var id: String
    public var userId: String?
    public var bottleId: String?
    public var catalogProductId: String?

    /// The specific pour this is a tasting of, when there was one.
    ///
    /// This is what makes the oxidation clock checkable rather than merely
    /// asserted: three tastings of one bottle, each pinned to a pour on a known
    /// date, is a record of how that bottle actually changed after opening.
    /// Nil for a tasting at a bar, where there is no pour of your own behind it.
    public var pourId: String?

    public var tastedAt: Int64
    public var rating: Int?
    public var wouldRebuy: Rebuy?
    public var worthThePrice: Bool?

    /// How hot it actually drank, 1-5.
    ///
    /// Stored beside the bottle's MEASURED strength so the two can disagree,
    /// which is the whole point: a barrel-proof bourbon that goes down easy is
    /// a different bottle from one that scorches at the same proof.
    public var perceivedHeat: Int?

    /// How long the finish lasted, in seconds. Length is the part of a finish
    /// people compare between bottles, and the one dimension free text is
    /// worst at holding still.
    public var finishSeconds: Int?

    /// Where this happened when it was not a pour of your own bottle. Nil for
    /// your own pour. A tasting at a bar is a real opinion and a different
    /// kind of evidence from one at home: a 30 ml pour after two others is
    /// not the same as a quiet glass, and the record should say which.
    public var source: TastingSource?
    /// The bar, the friend, the swap partner. Free text.
    public var sourceNote: String?

    /// Rated without knowing which bottle it was -- a glass in a flight,
    /// before the reveal. Kept so the palate can compare what you say
    /// about a label with what you say about the whiskey.
    public var blind: Bool

    public var liked: String?
    public var disliked: String?
    public var createdAt: Int64
    public var updatedAt: Int64
    public var deletedAt: Int64?
    public var dirty: Bool

    enum CodingKeys: String, CodingKey {
        case id, userId = "user_id", bottleId = "bottle_id"
        case catalogProductId = "catalog_product_id"
        case pourId = "pour_id"
        case tastedAt = "tasted_at", rating, wouldRebuy = "would_rebuy"
        case worthThePrice = "worth_the_price"
        case perceivedHeat = "perceived_heat"
        case finishSeconds = "finish_seconds"
        case source, sourceNote = "source_note", blind
        case liked, disliked
        case createdAt = "created_at", updatedAt = "updated_at"
        case deletedAt = "deleted_at", dirty
    }

    public init(
        id: String = UUID().uuidString,
        userId: String? = nil,
        bottleId: String? = nil,
        catalogProductId: String? = nil,
        pourId: String? = nil,
        tastedAt: Int64 = Self.nowMilliseconds(),
        rating: Int? = nil,
        wouldRebuy: Rebuy? = nil,
        worthThePrice: Bool? = nil,
        perceivedHeat: Int? = nil,
        finishSeconds: Int? = nil,
        source: TastingSource? = nil,
        sourceNote: String? = nil,
        blind: Bool = false,
        liked: String? = nil,
        disliked: String? = nil,
        createdAt: Int64 = Self.nowMilliseconds(),
        updatedAt: Int64 = Self.nowMilliseconds(),
        deletedAt: Int64? = nil,
        dirty: Bool = true
    ) {
        self.id = id; self.userId = userId
        self.bottleId = bottleId; self.catalogProductId = catalogProductId
        self.pourId = pourId
        self.source = source; self.sourceNote = sourceNote; self.blind = blind
        self.tastedAt = tastedAt; self.rating = rating; self.wouldRebuy = wouldRebuy
        self.worthThePrice = worthThePrice
        self.perceivedHeat = perceivedHeat; self.finishSeconds = finishSeconds
        self.liked = liked; self.disliked = disliked
        self.createdAt = createdAt; self.updatedAt = updatedAt
        self.deletedAt = deletedAt; self.dirty = dirty
    }

    /// "At a bar · Jack Rose", "A sample", or nil for your own pour.
    public var whereLabel: String? {
        guard let source else { return nil }
        if let note = sourceNote?.trimmingCharacters(in: .whitespaces), !note.isEmpty {
            return source.label + " · " + note
        }
        return source.label
    }

    /// The recorded heat as the engine's own type. Nil when nobody said.
    public var heat: PerceivedProof.Heat? {
        perceivedHeat.flatMap(PerceivedProof.Heat.init(rawValue:))
    }
}

// MARK: - tasting_notes

/// One flavour-wheel pick, on one stage of one tasting.
public struct TastingNote: SyncableRecord {
    public static let databaseTableName = "tasting_notes"

    public var id: String
    public var userId: String?
    public var tastingId: String
    public var stage: TastingStage
    public var descriptorKey: String
    public var intensity: Int?
    public var createdAt: Int64
    public var updatedAt: Int64
    public var deletedAt: Int64?
    public var dirty: Bool

    enum CodingKeys: String, CodingKey {
        case id, userId = "user_id", tastingId = "tasting_id"
        case stage, descriptorKey = "descriptor_key", intensity
        case createdAt = "created_at", updatedAt = "updated_at"
        case deletedAt = "deleted_at", dirty
    }

    public init(
        id: String = UUID().uuidString,
        userId: String? = nil,
        tastingId: String,
        stage: TastingStage,
        descriptorKey: String,
        intensity: Int? = nil,
        createdAt: Int64 = Self.nowMilliseconds(),
        updatedAt: Int64 = Self.nowMilliseconds(),
        deletedAt: Int64? = nil,
        dirty: Bool = true
    ) {
        self.id = id; self.userId = userId; self.tastingId = tastingId
        self.stage = stage; self.descriptorKey = descriptorKey; self.intensity = intensity
        self.createdAt = createdAt; self.updatedAt = updatedAt
        self.deletedAt = deletedAt; self.dirty = dirty
    }
}

// MARK: - wishlist_items

/// Its own table rather than a flag on `bottles`. A wanted bottle has no
/// purchase date, no open date, no pours and no fill level.
public struct WishlistItem: SyncableRecord {
    public static let databaseTableName = "wishlist_items"

    public var id: String
    public var userId: String?
    public var catalogProductId: String?
    public var customName: String?
    public var targetPriceCents: Int?
    public var note: String?
    public var createdAt: Int64
    public var updatedAt: Int64
    public var deletedAt: Int64?
    public var dirty: Bool

    enum CodingKeys: String, CodingKey {
        case id, userId = "user_id", catalogProductId = "catalog_product_id"
        case customName = "custom_name", targetPriceCents = "target_price_cents", note
        case createdAt = "created_at", updatedAt = "updated_at"
        case deletedAt = "deleted_at", dirty
    }

    public init(
        id: String = UUID().uuidString,
        userId: String? = nil,
        catalogProductId: String? = nil,
        customName: String? = nil,
        targetPriceCents: Int? = nil,
        note: String? = nil,
        createdAt: Int64 = Self.nowMilliseconds(),
        updatedAt: Int64 = Self.nowMilliseconds(),
        deletedAt: Int64? = nil,
        dirty: Bool = true
    ) {
        self.id = id; self.userId = userId
        self.catalogProductId = catalogProductId; self.customName = customName
        self.targetPriceCents = targetPriceCents; self.note = note
        self.createdAt = createdAt; self.updatedAt = updatedAt
        self.deletedAt = deletedAt; self.dirty = dirty
    }
}

// MARK: - knowledge_notes

/// The user-editable knowledge base. v2 retrieves over these; the table exists
/// now so that does not need a migration.
public struct KnowledgeNote: SyncableRecord {
    public static let databaseTableName = "knowledge_notes"

    public var id: String
    public var userId: String?
    public var title: String
    public var body: String
    public var subjectKind: String?
    public var subjectId: String?
    public var createdAt: Int64
    public var updatedAt: Int64
    public var deletedAt: Int64?
    public var dirty: Bool

    enum CodingKeys: String, CodingKey {
        case id, userId = "user_id", title, body
        case subjectKind = "subject_kind", subjectId = "subject_id"
        case createdAt = "created_at", updatedAt = "updated_at"
        case deletedAt = "deleted_at", dirty
    }

    public init(
        id: String = UUID().uuidString,
        userId: String? = nil,
        title: String,
        body: String = "",
        subjectKind: String? = nil,
        subjectId: String? = nil,
        createdAt: Int64 = Self.nowMilliseconds(),
        updatedAt: Int64 = Self.nowMilliseconds(),
        deletedAt: Int64? = nil,
        dirty: Bool = true
    ) {
        self.id = id; self.userId = userId; self.title = title; self.body = body
        self.subjectKind = subjectKind; self.subjectId = subjectId
        self.createdAt = createdAt; self.updatedAt = updatedAt
        self.deletedAt = deletedAt; self.dirty = dirty
    }
}

// MARK: - subscriptions

/// Server-owned. Pulled and never pushed: its RLS policy is SELECT-only, so a
/// client attempting a write is refused by the database rather than by us.
public struct Subscription: SyncableRecord {
    public static let databaseTableName = "subscriptions"

    public var id: String
    public var userId: String?
    public var tier: Tier
    public var expiresAt: Int64?
    public var createdAt: Int64
    public var updatedAt: Int64
    public var deletedAt: Int64?
    public var dirty: Bool

    enum CodingKeys: String, CodingKey {
        case id, userId = "user_id", tier, expiresAt = "expires_at"
        case createdAt = "created_at", updatedAt = "updated_at"
        case deletedAt = "deleted_at", dirty
    }

    public init(
        id: String = UUID().uuidString,
        userId: String? = nil,
        tier: Tier = .free,
        expiresAt: Int64? = nil,
        createdAt: Int64 = Self.nowMilliseconds(),
        updatedAt: Int64 = Self.nowMilliseconds(),
        deletedAt: Int64? = nil,
        dirty: Bool = false
    ) {
        self.id = id; self.userId = userId; self.tier = tier; self.expiresAt = expiresAt
        self.createdAt = createdAt; self.updatedAt = updatedAt
        self.deletedAt = deletedAt; self.dirty = dirty
    }
}

#if compiler(>=6.0)
extension Tier: @retroactive DatabaseValueConvertible {}
#else
extension Tier: DatabaseValueConvertible {}
#endif
