import Foundation

/// What you have paid for this bottle before.
///
/// The question in the aisle is "is this a rip-off?", and for anything
/// allocated that is a secondary-market question with no free, legal, stable
/// source behind it. Apps that answer it anyway get checked against reality and
/// lose: *"the fair price on a ton of bottles is absolute horse shit making the
/// app useless as a guide... DO NOT USE THIS TO EVALUATE YOUR BOURBON."*
///
/// This answers a narrower question that needs no outside data at all, is
/// impossible to be wrong about, and is often the one actually being asked:
/// **what did I pay last time?**
///
/// It is worth more than it looks. Somebody who buys the same bourbon twice a
/// year has a better price sense for it than any published figure, and the
/// thing they cannot do is remember it accurately at the shelf.
public enum PriceHistory: Sendable {

    /// One previous purchase of the same product.
    public struct Purchase: Hashable, Sendable {
        public let cents: Int
        public let purchasedAt: Date?
        public let store: String?

        public init(cents: Int, purchasedAt: Date? = nil, store: String? = nil) {
            self.cents = cents
            self.purchasedAt = purchasedAt
            self.store = store
        }
    }

    /// What your own record says this bottle costs.
    public struct Summary: Hashable, Sendable {
        public let purchases: [Purchase]
        public let lowestCents: Int
        public let highestCents: Int
        /// The MEDIAN, not the mean. One duty-free bottle or one auction
        /// mistake would drag an average somewhere you never actually shop.
        public let typicalCents: Int
        public let mostRecent: Purchase?

        public var count: Int { purchases.count }

        /// True when every purchase was the same price, which makes a range
        /// misleading to print.
        public var isSinglePrice: Bool { lowestCents == highestCents }

        /// Plain words. Never a recommendation, only a record.
        public var summary: String {
            if count == 1 {
                return "You paid \(Money.short(typicalCents)) for this before."
            }
            if isSinglePrice {
                return "You have paid \(Money.short(typicalCents)) each of the "
                    + "\(count) times you bought this."
            }
            return "You have bought this \(count) times, from "
                + "\(Money.short(lowestCents)) to \(Money.short(highestCents))."
        }
    }

    /// Builds the summary. Nil when there is nothing to compare against, which
    /// is the honest answer for a bottle you have never bought before.
    public static func summarise(_ purchases: [Purchase]) -> Summary? {
        let priced = purchases.filter { $0.cents > 0 }
        guard !priced.isEmpty else { return nil }

        let sorted = priced.map(\.cents).sorted()
        let middle = sorted.count / 2
        let median = sorted.count % 2 == 1
            ? sorted[middle]
            : (sorted[middle - 1] + sorted[middle]) / 2

        let mostRecent = priced
            .filter { $0.purchasedAt != nil }
            .max { ($0.purchasedAt ?? .distantPast) < ($1.purchasedAt ?? .distantPast) }

        return Summary(
            purchases: priced,
            lowestCents: sorted.first ?? 0,
            highestCents: sorted.last ?? 0,
            typicalCents: median,
            mostRecent: mostRecent ?? priced.last)
    }

    /// How a price in front of you compares with what you have paid.
    ///
    /// Bands are deliberately wide and deliberately unalarming. Shelf prices
    /// move, a bottle bought two years ago is not a fair benchmark today, and
    /// an app that cried "overpriced" at a normal increase would be wrong far
    /// more often than useful.
    public enum Verdict: String, Sendable, Hashable, CaseIterable {
        case cheaperThanUsual
        case aboutWhatYouPay
        case moreThanUsual
        case muchMoreThanUsual
        case noHistory

        public var headline: String {
            switch self {
            case .cheaperThanUsual: return "Cheaper than you usually pay"
            case .aboutWhatYouPay: return "About what you usually pay"
            case .moreThanUsual: return "More than you usually pay"
            case .muchMoreThanUsual: return "Much more than you usually pay"
            case .noHistory: return "You have not bought this before"
            }
        }
    }

    /// Within this either way counts as the same price.
    public static let sameSpread = 0.10
    /// Beyond this it is worth saying out loud.
    public static let muchMoreSpread = 0.40

    public static func compare(askingCents: Int, with history: Summary?) -> Verdict {
        guard let history, history.typicalCents > 0 else { return .noHistory }
        let fraction =
            Double(askingCents - history.typicalCents) / Double(history.typicalCents)

        switch fraction {
        case ..<(-sameSpread): return .cheaperThanUsual
        case ...sameSpread: return .aboutWhatYouPay
        case ...muchMoreSpread: return .moreThanUsual
        default: return .muchMoreThanUsual
        }
    }
}

/// Cents to money, in the engine so a price cannot render two ways between
/// a summary sentence and the screen showing it.
public enum Money: Sendable {
    public static func short(_ cents: Int) -> String {
        String(format: "$%.2f", Double(cents) / 100)
    }
}
