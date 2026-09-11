import Foundation

/// A store pick beside the standard release of the same product.
///
/// The research's architectural claim is that bourbon collecting happens at
/// barrel level and every incumbent stops at the SKU. This is the screen that
/// only exists because the model went one level deeper: a Four Roses OESQ
/// pick at 58.7% sits next to the shelf bottle at 50%, and the difference in
/// proof, age, recipe, price and your own rating is laid out as facts.
///
/// Every row is a pair of things the person recorded or the catalogue states.
/// Nothing is inferred: a pick with no stated age shows no age row, because
/// "unknown" next to "7 years" would read as a fact about the pick.
public enum PickCompare: Sendable {

    /// The pick, as the bottle in hand records it.
    public struct Pick: Hashable, Sendable {
        public let abv: Double?
        public let ageMonths: Int?
        public let recipeCode: String?
        public let paidCents: Int?
        public let rating: Int?

        public init(
            abv: Double? = nil,
            ageMonths: Int? = nil,
            recipeCode: String? = nil,
            paidCents: Int? = nil,
            rating: Int? = nil
        ) {
            self.abv = abv
            self.ageMonths = ageMonths
            self.recipeCode = recipeCode
            self.paidCents = paidCents
            self.rating = rating
        }
    }

    /// The standard release, from the catalogue plus what the person has
    /// recorded about their own non-pick bottles of it.
    public struct Standard: Hashable, Sendable {
        public let abv: Double?
        public let statedAgeYears: Int?
        public let recipeCode: String?
        /// A published shelf price, or the person's own typical price.
        public let priceCents: Int?
        public let priceLabel: String?
        /// The person's best rating of a NON-pick bottle of this product.
        public let rating: Int?

        public init(
            abv: Double? = nil,
            statedAgeYears: Int? = nil,
            recipeCode: String? = nil,
            priceCents: Int? = nil,
            priceLabel: String? = nil,
            rating: Int? = nil
        ) {
            self.abv = abv
            self.statedAgeYears = statedAgeYears
            self.recipeCode = recipeCode
            self.priceCents = priceCents
            self.priceLabel = priceLabel
            self.rating = rating
        }
    }

    public enum Field: String, Sendable, Hashable, CaseIterable {
        case proof, age, recipe, price, rating

        public var label: String {
            switch self {
            case .proof: return "Proof"
            case .age: return "Age"
            case .recipe: return "Recipe"
            case .price: return "Price"
            case .rating: return "Your rating"
            }
        }
    }

    /// One fact, both sides. `difference` is the short phrase between them --
    /// "+17.4 proof", "same recipe", "$20 more" -- or nil when the two are
    /// not comparable as numbers.
    public struct Row: Hashable, Sendable {
        public let field: Field
        public let pick: String
        public let standard: String
        public let difference: String?
        /// Positive when the pick has more of it. Proof, age and rating up
        /// is more; price up is more expensive. The screen colours nothing by
        /// this -- more proof is not better -- it only orders.
        public let delta: Double?
    }

    public struct Comparison: Hashable, Sendable {
        public let rows: [Row]
        public var isEmpty: Bool { rows.isEmpty }
    }

    /// Only rows where BOTH sides have something to say. A comparison with
    /// one side blank is a fact sheet, and the bottle screen already has one.
    public static func compare(pick: Pick, standard: Standard) -> Comparison {
        var rows: [Row] = []

        if let a = pick.abv, let b = standard.abv {
            let pickProof = ABV(percent: a).proof
            let standardProof = ABV(percent: b).proof
            let delta = pickProof - standardProof
            rows.append(Row(
                field: .proof,
                pick: format(proof: pickProof),
                standard: format(proof: standardProof),
                difference: abs(delta) < 0.05 ? "same proof" : signed(delta, unit: "proof"),
                delta: delta))
        }

        if let months = pick.ageMonths, let years = standard.statedAgeYears {
            let pickYears = Double(months) / 12
            let delta = pickYears - Double(years)
            rows.append(Row(
                field: .age,
                pick: AgeMath.describe(months: months),
                standard: "\(years) \(years == 1 ? "year" : "years")",
                difference: abs(delta) < 1.0 / 24 ? "same age" : signedAge(delta),
                delta: delta))
        }

        if let a = pick.recipeCode, let b = standard.recipeCode {
            let same = a.uppercased() == b.uppercased()
            rows.append(Row(
                field: .recipe,
                pick: a.uppercased(),
                standard: b.uppercased(),
                difference: same ? "same recipe" : recipeDifference(a, b),
                delta: nil))
        }

        if let paid = pick.paidCents, let price = standard.priceCents {
            let delta = paid - price
            let label = standard.priceLabel.map { " (\($0))" } ?? ""
            rows.append(Row(
                field: .price,
                pick: Money.short(paid),
                standard: Money.short(price) + label,
                difference: delta == 0 ? "same price"
                    : delta > 0 ? "\(Money.short(delta)) more" : "\(Money.short(-delta)) less",
                delta: Double(delta)))
        }

        if let a = pick.rating, let b = standard.rating {
            let delta = a - b
            rows.append(Row(
                field: .rating,
                pick: "\(a)/10",
                standard: "\(b)/10",
                difference: delta == 0 ? "rated the same"
                    : delta > 0 ? "+\(delta) for the pick" : "\(delta) for the pick",
                delta: Double(delta)))
        }

        return Comparison(rows: rows)
    }

    // MARK: - Formatting

    private static func format(proof: Double) -> String {
        String(format: "%.1f", proof)
    }

    private static func signed(_ value: Double, unit: String) -> String {
        String(format: "%@%.1f %@", value > 0 ? "+" : "−", abs(value), unit)
    }

    private static func signedAge(_ years: Double) -> String {
        let months = Int((abs(years) * 12).rounded())
        let sign = years > 0 ? "+" : "−"
        if months % 12 == 0 {
            let whole = months / 12
            return "\(sign)\(whole) \(whole == 1 ? "year" : "years")"
        }
        if months < 24 {
            return "\(sign)\(months) months"
        }
        return String(format: "%@%.1f years", sign, abs(years))
    }

    /// For Four Roses, say WHAT differs -- mashbill or yeast -- rather than
    /// just "different". Anything else is just different.
    private static func recipeDifference(_ a: String, _ b: String) -> String {
        guard let x = RecipeCode(a), let y = RecipeCode(b) else { return "different recipe" }
        var parts: [String] = []
        if x.mashbill != y.mashbill { parts.append("different mashbill") }
        if x.yeast != y.yeast { parts.append("different yeast") }
        return parts.isEmpty ? "different recipe" : parts.joined(separator: ", ")
    }
}
