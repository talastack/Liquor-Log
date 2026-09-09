import Foundation

/// What the collection looks like, in one screen.
///
/// The research is blunt about why this exists: OnlyDrams' growth loop is a
/// **shareable stats screenshot**. Post titles tell the story — *"My OnlyDrams
/// Post (10 years of collecting)"*, *"Can some one do the OnlyDrams thing for
/// me?"* — and the pie chart is the marketing asset. *"Build something
/// screenshot-worthy."*
///
/// **Everything here counts the COLLECTION, never the drinking.** Bottles
/// owned, classes represented, distilleries, the oldest thing on the shelf.
/// Nothing counts pours, nothing is a streak, nothing goes up when you drink
/// more, and there is no total that rewards volume.
///
/// That is not only Apple guideline 1.4.3, which rejects apps encouraging
/// excessive consumption. It is also what the research found people actually
/// like: an app pitched on *"collection progress and competition"* posted three
/// times to r/bourbon and scored 1, 1, 1. What generates unprompted delight is
/// a bottle's own properties, not a scoreboard.
public enum CollectionStats: Sendable {

    /// One bottle, reduced to what a summary needs.
    public struct Entry: Hashable, Sendable {
        public let classType: ClassType?
        public let distillery: String?
        public let abv: Double?
        public let isOpen: Bool
        public let isFinished: Bool
        public let addedAt: Date
        public let ageMonths: Int?

        public init(
            classType: ClassType? = nil,
            distillery: String? = nil,
            abv: Double? = nil,
            isOpen: Bool = false,
            isFinished: Bool = false,
            addedAt: Date = Date(),
            ageMonths: Int? = nil
        ) {
            self.classType = classType
            self.distillery = distillery
            self.abv = abv
            self.isOpen = isOpen
            self.isFinished = isFinished
            self.addedAt = addedAt
            self.ageMonths = ageMonths
        }
    }

    /// A slice of the collection, for a chart or a list.
    public struct Slice: Hashable, Sendable, Identifiable {
        public let label: String
        public let count: Int
        public var id: String { label }

        public func share(of total: Int) -> Double {
            total > 0 ? Double(count) / Double(total) : 0
        }
    }

    public struct Summary: Sendable, Equatable {
        /// On the shelf. Finished bottles are counted separately and never
        /// folded in: a collection is what you have, not what you have had.
        public let onShelf: Int
        public let open: Int
        public let sealed: Int
        /// Archived, not deleted. Reported as a plain number with no
        /// celebration attached.
        public let finished: Int

        public let byClass: [Slice]
        public let byDistillery: [Slice]
        public let byStrength: [Slice]

        public let distilleryCount: Int
        public let classCount: Int
        /// The strongest thing on the shelf, as a property of a bottle rather
        /// than an achievement.
        public let highestProof: Double?
        public let oldestStatedAgeMonths: Int?

        public var isEmpty: Bool { onShelf == 0 && finished == 0 }
    }

    /// Strength bands, in the words people use rather than numbers.
    ///
    /// Bands not a histogram: the interesting fact is "I own a lot of
    /// barrel-proof bourbon", and a bar chart of exact ABVs says that less
    /// clearly than four labels do.
    static func strengthBand(_ abv: Double) -> String {
        switch abv {
        case ..<45: return "80–89 proof"
        case ..<50: return "90–99 proof"
        case ..<57.5: return "100–114 proof"
        default: return "115 proof and up"
        }
    }

    public static func summarise(_ entries: [Entry]) -> Summary {
        let live = entries.filter { !$0.isFinished }
        let finished = entries.count - live.count

        let byClass = tally(live.compactMap { $0.classType?.label })
        let byDistillery = tally(live.compactMap(\.distillery))
        let byStrength = tally(live.compactMap { $0.abv.map(strengthBand) })

        return Summary(
            onShelf: live.count,
            open: live.filter(\.isOpen).count,
            sealed: live.filter { !$0.isOpen }.count,
            finished: finished,
            byClass: byClass,
            byDistillery: byDistillery,
            byStrength: byStrength,
            distilleryCount: Set(live.compactMap(\.distillery)).count,
            classCount: Set(live.compactMap { $0.classType?.label }).count,
            highestProof: live.compactMap(\.abv).max().map { ABV(percent: $0).proof },
            oldestStatedAgeMonths: live.compactMap(\.ageMonths).max())
    }

    /// Biggest first, then alphabetically so equal counts do not reshuffle
    /// between launches — a chart whose order changes on its own reads as a
    /// bug.
    static func tally(_ values: [String]) -> [Slice] {
        var counts: [String: Int] = [:]
        for value in values { counts[value, default: 0] += 1 }
        return counts
            .map { Slice(label: $0.key, count: $0.value) }
            .sorted {
                $0.count != $1.count
                    ? $0.count > $1.count
                    : $0.label.localizedCaseInsensitiveCompare($1.label) == .orderedAscending
            }
    }
}

/// What is open right now, written out for somebody else to read.
///
/// From the research, unprompted: *"I really like the menu concept! Now if
/// there was a way to take the spreadsheet and populate the menu......"*
///
/// It is a list of what is OPEN, because that is the question a guest is
/// actually asking. A sealed bottle is not on offer, and printing the whole
/// collection turns a menu into a brag.
public enum PourMenu: Sendable {

    public struct Item: Hashable, Sendable {
        public let name: String
        public let detail: String?
        public let proof: Double?

        public init(name: String, detail: String? = nil, proof: Double? = nil) {
            self.name = name
            self.detail = detail
            self.proof = proof
        }
    }

    /// Plain text, because it has to survive being pasted into a message.
    ///
    /// No prices. A menu with prices on it reads as bragging about what the
    /// evening cost, and the one thing a guest cannot do with that information
    /// is enjoy the whiskey.
    public static func text(title: String, items: [Item]) -> String {
        guard !items.isEmpty else {
            return "\(title)\n\nNothing open at the moment."
        }
        let lines = items.map { item -> String in
            var line = "• \(item.name)"
            if let proof = item.proof {
                line += String(format: "  (%.1f proof)", proof)
            }
            if let detail = item.detail, !detail.isEmpty {
                line += "\n  \(detail)"
            }
            return line
        }
        return ([title, ""] + lines).joined(separator: "\n")
    }
}
