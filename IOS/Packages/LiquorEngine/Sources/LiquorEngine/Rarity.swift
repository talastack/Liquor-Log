import Foundation

/// How hard a bottle is to get, from measured allocation rather than opinion.
///
/// The research is pointed about the incumbent's version: OnlyDrams' rarity
/// tiers are *"an editorial label of unknown and demonstrably inconsistent
/// provenance"* — no methodology published anywhere, and two records for the
/// same bottle showing different tiers. *"This is an attack surface, not a
/// moat."* The one thing the community demonstrably loves about that app is
/// built on nothing.
///
/// This is built on numbers a state publishes. Virginia ABC's lottery posts
/// bottles available AND entries received per product — 640 bottles of George
/// T. Stagg, 44,696 entries — which is measured demand against measured
/// supply, and 70:1 is a fact rather than a tier somebody typed in.
///
/// **What it deliberately cannot say.** Every free source skews to the scarce
/// end, so this can grade the allocated tier and has *no basis at all* for
/// distinguishing "common" from "uncommon". The research suspects that gap is
/// exactly why OnlyDrams' tiers are inconsistent. So there are three honest
/// states, and "not allocated" is one of them — it is a real, useful fact
/// about a bottle, and inventing a tier below it would be the mistake this
/// type exists to avoid.
public enum Rarity: Sendable {

    /// What a state published about one release.
    public struct Allocation: Hashable, Sendable, Codable {
        /// Bottles the state received for this release.
        public let bottles: Int
        /// Lottery entries, where the state runs one and publishes the count.
        public let entries: Int?
        /// Which board, verbatim, shown beside the figure: "Virginia ABC".
        public let source: String
        public let year: Int?

        public init(bottles: Int, entries: Int? = nil, source: String, year: Int? = nil) {
            self.bottles = bottles
            self.entries = entries
            self.source = source
            self.year = year
        }

        /// Entries per bottle. Nil without an entry count.
        public var demandRatio: Double? {
            guard let entries, bottles > 0 else { return nil }
            return Double(entries) / Double(bottles)
        }
    }

    public enum Verdict: Hashable, Sendable {
        /// The state ran a lottery and published both numbers.
        case contested(ratio: Double)
        /// The state published how many bottles arrived, and nothing else.
        case allocated(bottles: Int)
        /// No allocation record. NOT "common" — the only honest reading is
        /// that nobody had to draw for it.
        case notAllocated

        public var headline: String {
            switch self {
            case .contested(let ratio) where ratio >= 50:
                return "Extremely contested"
            case .contested(let ratio) where ratio >= 10:
                return "Contested"
            case .contested:
                return "Allocated, by lottery"
            case .allocated:
                return "Allocated"
            case .notAllocated:
                return "Not allocated"
            }
        }
    }

    public struct Result: Hashable, Sendable {
        public let verdict: Verdict
        public let allocation: Allocation?

        /// One line, and never a number without its source.
        public var summary: String {
            switch (verdict, allocation) {
            case (.contested(let ratio), let allocation?):
                let entries = allocation.entries ?? 0
                return "\(format(entries)) entries for \(format(allocation.bottles)) bottles "
                    + "— about \(Int(ratio.rounded())) people for every one."
            case (.allocated(let bottles), let allocation?):
                return "\(format(bottles)) bottles allocated to \(allocation.source)."
            case (.notAllocated, _):
                return "No lottery or allocation on record. That is not the same as common."
            default:
                return ""
            }
        }

        /// Always shown beside the figure. Two states' allocations do not add
        /// up to a national picture, and the research says so in as many
        /// words.
        public var caveat: String {
            guard let allocation else {
                return "Allocation records cover only the scarcest bottles."
            }
            let year = allocation.year.map { " (\($0))" } ?? ""
            return "From \(allocation.source)\(year). One state's allocation, "
                + "not a national figure."
        }

        private func format(_ number: Int) -> String {
            let formatter = NumberFormatter()
            formatter.numberStyle = .decimal
            return formatter.string(from: NSNumber(value: number)) ?? String(number)
        }
    }

    /// Bands on the demand ratio. Deliberately coarse and deliberately few:
    /// this is measured data with a small sample of releases behind it, and a
    /// five-tier ladder would be precision the source does not have.
    public static let contestedThreshold = 10.0
    public static let extremelyContestedThreshold = 50.0

    public static func assess(_ allocation: Allocation?) -> Result {
        guard let allocation else {
            return Result(verdict: .notAllocated, allocation: nil)
        }
        if let ratio = allocation.demandRatio {
            return Result(verdict: .contested(ratio: ratio), allocation: allocation)
        }
        return Result(verdict: .allocated(bottles: allocation.bottles), allocation: allocation)
    }
}
