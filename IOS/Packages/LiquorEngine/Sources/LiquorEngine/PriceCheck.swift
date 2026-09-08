import Foundation

/// A published price to compare against, and where it came from.
///
/// **This is a SHELF price, not a market value.** It is what a bottle costs
/// where prices are posted publicly — a state control board's price list, or a
/// producer's stated suggested retail. It is not what an allocated bottle
/// trades for between collectors, and the app must never imply that it is.
///
/// Every reference names its source, because a price with no provenance is a
/// number the user cannot check and we cannot defend.
public struct PriceReference: Hashable, Sendable, Codable {
    public let cents: Int
    /// Human-readable origin, shown in the UI verbatim: "Virginia ABC",
    /// "Oregon OLCC", "Producer stated SRP".
    public let source: String
    /// Year the figure was published. Shelf prices drift, and a five-year-old
    /// reference presented as current is worse than no reference.
    public let asOfYear: Int?

    public init(cents: Int, source: String, asOfYear: Int? = nil) {
        self.cents = cents
        self.source = source
        self.asOfYear = asOfYear
    }
}

/// Compares what you paid against a published shelf price.
///
/// The question a user actually asks in a shop is "is this a rip-off?" — and
/// for anything allocated, that is a secondary-market question this app cannot
/// answer. There is no free, legal, stable source for resale prices, and
/// scraping listings is a terms-of-service problem before it is a technical
/// one.
///
/// So this answers the narrower question honestly and says which one it
/// answered: **how does this compare to the shelf price where prices are
/// posted?** `Result.caveat` carries that sentence and the UI must show it.
public enum PriceCheck: Sendable {

    public enum Band: String, Sendable, Hashable, CaseIterable {
        /// At or under the published shelf price.
        case atOrBelow
        /// Within a normal spread between markets.
        case slightlyOver
        /// Meaningfully above shelf, the usual sign of secondary pricing.
        case wellOver
        /// Multiples of shelf price.
        case farOver
        /// No published figure for this product.
        case noReference
    }

    /// Boundaries as a fraction over the reference. Deliberately wide: shelf
    /// prices vary legitimately between states and retailers, and a band that
    /// called a normal regional difference "overpriced" would be wrong far more
    /// often than it was useful.
    public static let slightlyOverThreshold = 0.10
    public static let wellOverThreshold = 0.40

    public struct Result: Hashable, Sendable {
        public let paidCents: Int
        public let reference: PriceReference?
        public let band: Band
        /// Positive when you paid over the reference. Nil without a reference.
        public let differenceCents: Int?
        /// Fraction over the reference; 0.5 means half again. Nil without one.
        public let fractionOver: Double?

        /// One line naming what was compared. Always shown beside the verdict.
        public var caveat: String {
            guard let reference else {
                return "No published shelf price for this bottle."
            }
            let year = reference.asOfYear.map { " (\($0))" } ?? ""
            return "Compared with the \(reference.source) shelf price\(year). "
                + "Not a resale value."
        }

        public var headline: String {
            switch band {
            case .atOrBelow: return "At or under shelf price"
            case .slightlyOver: return "A little over shelf price"
            case .wellOver: return "Well over shelf price"
            case .farOver: return "Far over shelf price"
            case .noReference: return "No shelf price to compare"
            }
        }
    }

    public static func compare(paidCents: Int, reference: PriceReference?) -> Result {
        guard let reference, reference.cents > 0 else {
            return Result(
                paidCents: paidCents, reference: reference,
                band: .noReference, differenceCents: nil, fractionOver: nil)
        }

        let difference = paidCents - reference.cents
        let fraction = Double(difference) / Double(reference.cents)

        let band: Band
        if fraction <= 0 {
            band = .atOrBelow
        } else if fraction <= slightlyOverThreshold {
            band = .slightlyOver
        } else if fraction <= wellOverThreshold {
            band = .wellOver
        } else {
            band = .farOver
        }

        return Result(
            paidCents: paidCents, reference: reference,
            band: band, differenceCents: difference, fractionOver: fraction)
    }

    /// What a pour costs, from what was actually paid. This one needs no
    /// external data at all and is the more useful number day to day: it turns
    /// an intimidating bottle price into the price of a drink.
    public static func costPerPourCents(
        paidCents: Int,
        capacityMilliliters: Double,
        pourSize: PourSize = .standard
    ) -> Int? {
        PourMath.costPerPourCents(
            priceCents: paidCents,
            capacityMilliliters: capacityMilliliters,
            pourSize: pourSize)
    }
}
