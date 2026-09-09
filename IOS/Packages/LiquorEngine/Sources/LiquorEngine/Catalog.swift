import Foundation

/// A product in the bundled catalog.
///
/// Product-level facts only. Batch numbers, barrel numbers, pick stores and
/// measured proof belong on the bottle, because you only ever meet a release
/// through a bottle.
public struct CatalogProduct: Codable, Sendable, Hashable, Identifiable {
    public let id: String
    public let distillery: String
    public let brand: String
    public let expression: String
    public let classType: ClassType
    public let productionType: ProductionType
    public let isBarrelProof: Bool
    public let isBottledInBond: Bool

    /// **Nil for a barrel-proof release, and that is correct.** Their strength
    /// changes every batch, so a catalog claiming one number would be wrong for
    /// almost every bottle on almost every shelf. The user reads it off the
    /// label in front of them.
    public let abv: Double?

    public let statedAgeYears: Int?
    public let recipeCode: String?
    /// Groups products that share a grain recipe — "wheated" and the like — so
    /// relatedness can find siblings a name never would.
    public let mashbillKey: String?

    /// A published SHELF price, and where it was published.
    ///
    /// Never a market value. The documented source is a state control board's
    /// posted price list -- public records, and the only free and stable price
    /// data that exists for spirits. Nil is the honest value everywhere else,
    /// and it is currently nil for EVERY row: no figure has been transcribed
    /// from a control board yet, and inventing one is the exact failure mode
    /// that discredits apps in this category.
    ///
    /// The field is plumbed so a cited figure drops in without a schema change.
    public let msrpCents: Int?
    public let msrpSource: String?
    public let msrpAsOfYear: Int?

    /// Where the facts came from. A number nobody can check is not data.
    public let source: String
    public let sourceUrl: String?
    /// False until the row has been checked against the TTB registry.
    public let verified: Bool

    private enum CodingKeys: String, CodingKey {
        case id, distillery, brand, expression
        case classType = "class_type"
        case productionType = "production_type"
        case isBarrelProof = "is_barrel_proof"
        case isBottledInBond = "is_bottled_in_bond"
        case abv
        case statedAgeYears = "stated_age_years"
        case recipeCode = "recipe_code"
        case mashbillKey = "mashbill_key"
        case msrpCents = "msrp_cents"
        case msrpSource = "msrp_source"
        case msrpAsOfYear = "msrp_as_of_year"
        case source
        case sourceUrl = "source_url"
        case verified
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(String.self, forKey: .id)
        distillery = try c.decode(String.self, forKey: .distillery)
        brand = try c.decode(String.self, forKey: .brand)
        expression = try c.decodeIfPresent(String.self, forKey: .expression) ?? ""
        classType = try c.decode(ClassType.self, forKey: .classType)
        productionType = try c.decodeIfPresent(ProductionType.self, forKey: .productionType)
            ?? .unspecified
        isBarrelProof = try c.decodeIfPresent(Bool.self, forKey: .isBarrelProof) ?? false
        isBottledInBond = try c.decodeIfPresent(Bool.self, forKey: .isBottledInBond) ?? false
        abv = try c.decodeIfPresent(Double.self, forKey: .abv)
        statedAgeYears = try c.decodeIfPresent(Int.self, forKey: .statedAgeYears)
        recipeCode = try c.decodeIfPresent(String.self, forKey: .recipeCode)
        mashbillKey = try c.decodeIfPresent(String.self, forKey: .mashbillKey)
        msrpCents = try c.decodeIfPresent(Int.self, forKey: .msrpCents)
        msrpSource = try c.decodeIfPresent(String.self, forKey: .msrpSource)
        msrpAsOfYear = try c.decodeIfPresent(Int.self, forKey: .msrpAsOfYear)
        source = try c.decodeIfPresent(String.self, forKey: .source) ?? ""
        sourceUrl = try c.decodeIfPresent(String.self, forKey: .sourceUrl)
        verified = try c.decodeIfPresent(Bool.self, forKey: .verified) ?? false
    }

    public init(
        id: String, distillery: String, brand: String, expression: String = "",
        classType: ClassType, productionType: ProductionType = .unspecified,
        isBarrelProof: Bool = false, isBottledInBond: Bool = false,
        abv: Double? = nil, statedAgeYears: Int? = nil,
        recipeCode: String? = nil, mashbillKey: String? = nil,
        msrpCents: Int? = nil, msrpSource: String? = nil, msrpAsOfYear: Int? = nil,
        source: String = "", sourceUrl: String? = nil, verified: Bool = false
    ) {
        self.id = id; self.distillery = distillery; self.brand = brand
        self.expression = expression; self.classType = classType
        self.productionType = productionType
        self.isBarrelProof = isBarrelProof; self.isBottledInBond = isBottledInBond
        self.abv = abv; self.statedAgeYears = statedAgeYears
        self.recipeCode = recipeCode; self.mashbillKey = mashbillKey
        self.msrpCents = msrpCents; self.msrpSource = msrpSource
        self.msrpAsOfYear = msrpAsOfYear
        self.source = source; self.sourceUrl = sourceUrl; self.verified = verified
    }

    public var identity: ProductIdentity {
        ProductIdentity(
            productId: id, distillery: distillery, brand: brand,
            expression: expression, classType: classType, productionType: productionType)
    }

    public var code: RecipeCode? { recipeCode.flatMap(RecipeCode.init) }

    /// The shelf-price reference, when there is a cited one.
    ///
    /// A price with no named source cannot be shown, so it is not returned
    /// either -- the same rule `CustomCatalogEntry` enforces in the database.
    public var priceReference: PriceReference? {
        guard let cents = msrpCents, let source = msrpSource else { return nil }
        return PriceReference(cents: cents, source: source, asOfYear: msrpAsOfYear)
    }

    /// What the strength line should say. Barrel proof has no fixed answer, and
    /// saying so is better than showing a number that is wrong most of the time.
    public var strengthDescription: String {
        guard let abv else {
            return isBarrelProof ? "Varies by batch" : "Strength not recorded"
        }
        let proof = ABV(percent: abv).proof
        return String(format: "%.1f%% ABV · %.1f proof", abv, proof)
    }
}

/// The bundled catalog, loaded from `shared/data/spirits.v1.json`.
///
/// Decoded from `Data` so the engine keeps no dependency on resource loading
/// and stays testable anywhere. The app hands it the file contents, and there
/// is no network call in this path at all — the whole point is that the shelf
/// check works in a shop with no signal.
public struct Catalog: Sendable, Codable {
    public let version: Int
    public let products: [CatalogProduct]

    private enum CodingKeys: String, CodingKey { case version, products }

    public init(version: Int = 1, products: [CatalogProduct]) {
        self.version = version
        self.products = products
    }

    public static func decode(from data: Data) throws -> Catalog {
        try JSONDecoder().decode(Catalog.self, from: data)
    }

    public static let empty = Catalog(products: [])

    // MARK: - Lookup

    public func product(_ id: String) -> CatalogProduct? {
        products.first { $0.id == id }
    }

    public func identity(_ id: String) -> ProductIdentity? {
        product(id)?.identity
    }

    /// Everything the search needs, with the user's own history boosted.
    ///
    /// `history` is the set of product ids the user has a bottle or a tasting
    /// for. The bottle somebody is typing is usually one they have had before.
    public func searchCandidates(history: Set<String> = []) -> [SearchCandidate] {
        products.map { product in
            SearchCandidate(
                product: product.identity,
                recipeCode: product.code,
                mashbillKey: product.mashbillKey,
                isInYourHistory: history.contains(product.id))
        }
    }

    /// Products sharing this one's line, distillery, recipe code or grain
    /// recipe. Structural rather than textual: string similarity would never
    /// connect Weller to Eagle Rare.
    public func related(to id: String, limit: Int = 10) -> [SearchHit] {
        guard let anchor = product(id) else { return [] }
        return BottleSearch.related(
            to: anchor.identity,
            recipeCode: anchor.code,
            in: searchCandidates(),
            limit: limit)
    }

    // MARK: - Integrity

    public struct Issue: Hashable, Sendable, CustomStringConvertible {
        public let rule: String
        public let detail: String
        public var description: String { "\(rule): \(detail)" }
    }

    /// Structural checks the app can run on whatever catalog it was handed,
    /// including one fetched later. `scripts/check_catalog.py` runs the same
    /// rules in CI against the shipped file.
    public func validate() -> [Issue] {
        var issues: [Issue] = []
        var seen: Set<String> = []

        for product in products {
            if !seen.insert(product.id).inserted {
                issues.append(Issue(rule: "product.unique", detail: product.id))
            }
            if product.source.isEmpty {
                issues.append(Issue(
                    rule: "product.hasSource",
                    detail: "\(product.id) cites nothing; a number nobody can check is not data"))
            }
            if product.isBarrelProof, product.abv != nil {
                issues.append(Issue(
                    rule: "product.barrelProofHasNoFixedABV",
                    detail: "\(product.id) claims one strength for a release that changes "
                        + "every batch"))
            }
            if let code = product.recipeCode, RecipeCode(code) == nil {
                issues.append(Issue(rule: "product.recipeCode", detail: "\(product.id): \(code)"))
            }
            // A barrel-proof row is SUPPOSED to carry no ABV, so the engine's
            // abv.missing rule is not a fault here -- it is the correct value.
            let classIssues = Classification.validate(
                classType: product.classType,
                abv: product.abv.map { ABV(percent: $0) },
                statedAgeYears: product.statedAgeYears,
                isBottledInBond: product.isBottledInBond,
                volumeMilliliters: nil
            ).filter { !(product.isBarrelProof && $0.rule == "abv.missing") }

            issues.append(contentsOf: classIssues.map {
                Issue(rule: $0.rule, detail: "\(product.id): \($0.detail)")
            })
        }
        return issues
    }
}
