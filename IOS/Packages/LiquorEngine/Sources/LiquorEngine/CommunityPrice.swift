import Foundation

/// What a bottle actually costs, from what people have seen it cost.
///
/// **This is the only price data the app can honestly own.**
///
/// Copying a control board's list and restating it does not change where it
/// came from; re-typing somebody's compilation is the thing copyright is about.
/// But an observation a person makes about a shelf they are standing in front
/// of is theirs, and one they contribute is ours. It carries no licence, cannot
/// be revoked, and — unlike every published figure — it gets more accurate the
/// more the app is used rather than staler.
///
/// It is also the only price reference that can answer the question people
/// actually ask, because a control-state list only covers control states and a
/// suggested retail is not what anybody pays.
///
/// **What this must never become:** a secondary-market valuation. The research
/// is unambiguous about apps that publish one — *"the fair price on a ton of
/// bottles is absolute horse shit making the app useless as a guide... DO NOT
/// USE THIS TO EVALUATE YOUR BOURBON."* Every figure here is a shelf price
/// somebody reported paying or seeing, it says how many reports it rests on,
/// and it never predicts what a bottle is worth.
public enum CommunityPrice: Sendable {

    /// One person's sighting.
    public struct Report: Hashable, Sendable {
        public let cents: Int
        public let seenAt: Date
        /// Where, coarsely. Prices vary more between states than between shops,
        /// so a national median is a number nobody recognises.
        public let region: String?

        public init(cents: Int, seenAt: Date, region: String? = nil) {
            self.cents = cents
            self.seenAt = seenAt
            self.region = region
        }
    }

    /// Reports below this and there is nothing worth showing.
    ///
    /// One sighting is an anecdote and two is a coincidence. Showing a
    /// "community price" built on a single report would be the app borrowing
    /// authority it has not earned, and being wrong in public is how these apps
    /// lose the room.
    public static let minimumReports = 3

    /// Older than this and a report stops counting.
    ///
    /// Shelf prices move. A three-year-old sighting presented as current is
    /// worse than no figure, because somebody would plan around it.
    public static let maximumAgeDays = 540.0

    public struct Estimate: Hashable, Sendable {
        public let cents: Int
        public let reportCount: Int
        public let lowestCents: Int
        public let highestCents: Int
        public let newest: Date
        public let oldest: Date
        public let region: String?

        /// Named so it can never be mistaken for a manufacturer's figure.
        public var source: String {
            let where_ = region.map { " in \($0)" } ?? ""
            return "\(reportCount) shelf prices reported\(where_)"
        }

        /// Always shown. The spread is the honest part: a bottle seen between
        /// $45 and $90 does not have one price, and printing a median alone
        /// would hide that.
        public var caveat: String {
            "A range of what people saw on shelves, not a valuation. "
                + "\(Money.short(lowestCents)) to \(Money.short(highestCents))."
        }

        public var reference: PriceReference {
            PriceReference(cents: cents, source: source, asOfYear: nil)
        }
    }

    /// Aggregates reports into something showable, or nil.
    ///
    /// Nil is a real answer and the common one early on. An app with no users
    /// yet has no community price, and inventing one would poison the feature
    /// exactly when first impressions are formed.
    public static func estimate(
        from reports: [Report],
        region: String? = nil,
        now: Date = Date()
    ) -> Estimate? {
        let fresh = reports.filter { report in
            report.cents > 0
                && now.timeIntervalSince(report.seenAt) / 86_400 <= maximumAgeDays
                && (region == nil || report.region == region)
        }
        guard fresh.count >= minimumReports else { return nil }

        let sorted = fresh.map(\.cents).sorted()
        let middle = sorted.count / 2
        // The median. One duty-free bottle or one airport markup would drag a
        // mean somewhere nobody shops.
        let median = sorted.count % 2 == 1
            ? sorted[middle]
            : (sorted[middle - 1] + sorted[middle]) / 2

        let dates = fresh.map(\.seenAt).sorted()

        return Estimate(
            cents: median,
            reportCount: fresh.count,
            lowestCents: sorted.first ?? 0,
            highestCents: sorted.last ?? 0,
            newest: dates.last ?? now,
            oldest: dates.first ?? now,
            region: region)
    }

    /// Prefers a regional figure and falls back to everywhere.
    ///
    /// A Kentucky shelf price is not a Virginia one, so the local number is
    /// worth more — but two local reports beaten by twenty national ones is
    /// still better than showing nothing at all, and the source line says which
    /// you are looking at.
    public static func best(
        from reports: [Report],
        preferring region: String?,
        now: Date = Date()
    ) -> Estimate? {
        if let region, let local = estimate(from: reports, region: region, now: now) {
            return local
        }
        return estimate(from: reports, region: nil, now: now)
    }
}
