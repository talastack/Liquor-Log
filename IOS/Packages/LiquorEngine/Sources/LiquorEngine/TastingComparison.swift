import Foundation

/// Two tastings of one bottle, side by side.
///
/// A bottle tasted in March and again in October is two opinions, and the
/// interesting part is never the ratings on their own -- it is what changed
/// underneath them. `TastingTrend` already says whether the score went up;
/// this says what was tasted the second time that was not there the first.
///
/// Stages arrive as plain keys rather than a `TastingStage`, because that
/// type lives in the data layer and this engine has no dependencies. Each
/// platform passes its own stage order and gets it back.
public enum TastingComparison: Sendable {

    /// One of the two tastings.
    public struct Side: Hashable, Sendable {
        public let tastedAt: Date
        public let rating: Int?
        /// Stage key to the descriptor labels picked at that stage.
        public let descriptors: [String: [String]]

        public init(tastedAt: Date, rating: Int? = nil, descriptors: [String: [String]] = [:]) {
            self.tastedAt = tastedAt
            self.rating = rating
            self.descriptors = descriptors
        }
    }

    /// What happened at one stage between the two.
    public struct StageDiff: Hashable, Sendable {
        public let stage: String
        /// Picked both times.
        public let shared: [String]
        /// Picked the first time and not the second.
        public let goneSince: [String]
        /// Picked the second time and not the first.
        public let newSince: [String]

        public var isUnchanged: Bool { goneSince.isEmpty && newSince.isEmpty }
        /// Nothing was picked at this stage either time, so a screen can
        /// leave the row out rather than print an empty comparison.
        public var isEmpty: Bool { shared.isEmpty && isUnchanged }
    }

    public struct Result: Hashable, Sendable {
        /// Always the older of the two, whichever order they arrived in.
        public let earlier: Side
        public let later: Side
        /// In the stage order the caller gave, stages with nothing in them
        /// removed.
        public let stages: [StageDiff]
        public let daysApart: Int
        /// Later minus earlier, when both were rated. Nil when either was
        /// not: a tasting with no score is not a zero.
        public let ratingChange: Int?

        /// One factual line. Never an interpretation -- "you liked it more"
        /// is a claim about a person; "8, up from 6" is what happened.
        public let text: String
    }

    public static func compare(
        _ one: Side,
        _ other: Side,
        stageOrder: [String]
    ) -> Result {
        // Chronological whatever order the caller passed, so "what is new"
        // always means new in the later glass.
        let earlier = one.tastedAt <= other.tastedAt ? one : other
        let later = one.tastedAt <= other.tastedAt ? other : one

        let stages: [StageDiff] = stageOrder.compactMap { stage in
            let before = earlier.descriptors[stage] ?? []
            let after = later.descriptors[stage] ?? []
            let beforeSet = Set(before)
            let afterSet = Set(after)
            let diff = StageDiff(
                stage: stage,
                // Sorted so the same two tastings always read the same way.
                shared: beforeSet.intersection(afterSet).sorted(),
                goneSince: beforeSet.subtracting(afterSet).sorted(),
                newSince: afterSet.subtracting(beforeSet).sorted())
            return diff.isEmpty ? nil : diff
        }

        let days = Calendar(identifier: .gregorian)
            .dateComponents([.day], from: earlier.tastedAt, to: later.tastedAt).day ?? 0

        var change: Int?
        if let first = earlier.rating, let second = later.rating {
            change = second - first
        }

        return Result(
            earlier: earlier,
            later: later,
            stages: stages,
            daysApart: max(0, days),
            ratingChange: change,
            text: line(daysApart: max(0, days),
                       earlierRating: earlier.rating,
                       laterRating: later.rating,
                       stages: stages))
    }

    private static func line(
        daysApart: Int,
        earlierRating: Int?,
        laterRating: Int?,
        stages: [StageDiff]
    ) -> String {
        var parts: [String] = []

        switch daysApart {
        case 0: parts.append("The same day")
        case 1: parts.append("A day apart")
        case 2..<60: parts.append("\(daysApart) days apart")
        default:
            let months = daysApart / 30
            parts.append(months == 1 ? "About a month apart" : "About \(months) months apart")
        }

        if let first = earlierRating, let second = laterRating {
            if second == first {
                parts.append("still \(second) out of 10")
            } else {
                parts.append("\(second) out of 10, \(second > first ? "up" : "down") from \(first)")
            }
        }

        let appeared = stages.reduce(0) { $0 + $1.newSince.count }
        if appeared > 0 {
            parts.append(appeared == 1
                ? "one note you had not made before"
                : "\(appeared) notes you had not made before")
        }

        return parts.joined(separator: ". ") + "."
    }
}
