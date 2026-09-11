import Foundation

/// How one bottle's ratings moved between the first pour and the latest.
///
/// The research's argument for keeping every tasting rather than one score is
/// that a bottle changes as it sits open and people want to see that: *"a
/// changing opinion is the point of keeping them all."* Rows on their own do
/// not show it -- eye-balling 6, 7, 8 down a list is work -- so this turns
/// the series into one sentence, and says nothing when there is nothing to
/// say.
///
/// It reports what the person recorded and never why. "Opened up" is their
/// ratings rising, not a claim about oxidation; the oxidation band makes its
/// own hedged estimate and the two are shown side by side so they can
/// disagree.
public enum TastingTrend: Sendable {

    /// One rated tasting. Unrated tastings do not count toward a trend.
    public struct Point: Hashable, Sendable {
        public let tastedAt: Date
        public let rating: Int
        /// Days the bottle had been open at that tasting, when known.
        public let daysOpen: Int?

        public init(tastedAt: Date, rating: Int, daysOpen: Int? = nil) {
            self.tastedAt = tastedAt
            self.rating = rating
            self.daysOpen = daysOpen
        }
    }

    public enum Direction: String, Sendable, Hashable {
        case openedUp
        case holding
        case fading
    }

    public struct Summary: Hashable, Sendable {
        public let direction: Direction
        public let firstRating: Int
        public let latestRating: Int
        public let tastingCount: Int
        /// Days between the first and latest rated tastings.
        public let spanDays: Int
        public let text: String
    }

    /// A rating has to move at least this far to be called a change. One
    /// point is the noise of a different evening.
    public static let minimumMove = 2

    /// Nil with fewer than two rated tastings: one number is not a trend.
    public static func summarise(_ points: [Point]) -> Summary? {
        let ordered = points.sorted { $0.tastedAt < $1.tastedAt }
        guard let first = ordered.first, let latest = ordered.last, ordered.count >= 2 else {
            return nil
        }

        let move = latest.rating - first.rating
        let direction: Direction
        if move >= minimumMove {
            direction = .openedUp
        } else if move <= -minimumMove {
            direction = .fading
        } else {
            direction = .holding
        }

        let span = max(0, Int(latest.tastedAt.timeIntervalSince(first.tastedAt) / 86_400))
        let text = sentence(
            direction: direction,
            first: first,
            latest: latest,
            count: ordered.count,
            spanDays: span)

        return Summary(
            direction: direction,
            firstRating: first.rating,
            latestRating: latest.rating,
            tastingCount: ordered.count,
            spanDays: span,
            text: text)
    }

    private static func sentence(
        direction: Direction,
        first: Point,
        latest: Point,
        count: Int,
        spanDays: Int
    ) -> String {
        let period: String
        if let opened = latest.daysOpen, opened > 0 {
            period = "over \(opened) \(opened == 1 ? "day" : "days") open"
        } else if spanDays > 0 {
            period = "over \(spanDays) \(spanDays == 1 ? "day" : "days")"
        } else {
            period = "on the same day"
        }

        switch direction {
        case .openedUp:
            return "Opened up: \(first.rating) to \(latest.rating) \(period)."
        case .fading:
            return "Fading: \(first.rating) to \(latest.rating) \(period)."
        case .holding:
            let around = first.rating == latest.rating
                ? "at \(latest.rating)"
                : "around \(latest.rating)"
            return "Holding \(around) across \(count) tastings \(period)."
        }
    }
}
