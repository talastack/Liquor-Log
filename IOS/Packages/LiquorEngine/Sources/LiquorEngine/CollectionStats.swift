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
        public let name: String?
        public let classType: ClassType?
        public let distillery: String?
        public let brand: String?
        public let abv: Double?
        public let isOpen: Bool
        public let isFinished: Bool
        /// A store pick, single barrel or anything else with barrel detail.
        public let isPick: Bool
        public let addedAt: Date
        public let openedAt: Date?
        public let ageMonths: Int?
        public let storageLocation: String?
        public let purchasePriceCents: Int?
        public let purchasedAt: Date?
        public let costPerPourCents: Int?

        public init(
            name: String? = nil,
            classType: ClassType? = nil,
            distillery: String? = nil,
            brand: String? = nil,
            abv: Double? = nil,
            isOpen: Bool = false,
            isFinished: Bool = false,
            isPick: Bool = false,
            addedAt: Date = Date(),
            openedAt: Date? = nil,
            ageMonths: Int? = nil,
            storageLocation: String? = nil,
            purchasePriceCents: Int? = nil,
            purchasedAt: Date? = nil,
            costPerPourCents: Int? = nil
        ) {
            self.name = name
            self.classType = classType
            self.distillery = distillery
            self.brand = brand
            self.abv = abv
            self.isOpen = isOpen
            self.isFinished = isFinished
            self.isPick = isPick
            self.addedAt = addedAt
            self.openedAt = openedAt
            self.ageMonths = ageMonths
            self.storageLocation = storageLocation
            self.purchasePriceCents = purchasePriceCents
            self.purchasedAt = purchasedAt
            self.costPerPourCents = costPerPourCents
        }
    }

    /// Money for one label -- a year, usually. Kept apart from `Slice`
    /// because cents are not a count and a chart must not treat them as one.
    public struct Amount: Hashable, Sendable, Identifiable {
        public let label: String
        public let cents: Int
        public var id: String { label }
    }

    /// One named bottle and a number about it, for the notable rows.
    public struct Standout: Hashable, Sendable {
        public let name: String
        public let value: Int
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

        /// Brands, so "how much Weller do I have" is one line.
        public let byBrand: [Slice]
        /// Where bottles are kept. Empty until somebody records a place.
        public let byPlace: [Slice]
        /// Bottles added per calendar year, oldest year first. Growth of the
        /// COLLECTION, never a count of anything drunk.
        public let addedByYear: [Slice]

        public let distilleryCount: Int
        public let classCount: Int
        /// Store picks and single barrels on the shelf -- the bottles this
        /// app exists for.
        public let picks: Int
        /// The strongest thing on the shelf, as a property of a bottle rather
        /// than an achievement.
        public let highestProof: Double?
        public let oldestStatedAgeMonths: Int?
        /// The open bottle that has been open longest, in days. A fact about
        /// oxidation, not a prompt to finish it.
        public let longestOpen: Standout?

        // Money. The screen shows none of this unless the person turned the
        // shelf-value switch on; the research is clear that the number is
        // wanted by some and actively avoided by others.
        /// Spend per calendar year of purchase, oldest first. Bottles with a
        /// price but no purchase date are left out rather than guessed.
        public let spentByYear: [Amount]
        /// Mean cost of a pour across the priced bottles on the shelf.
        public let averageCostPerPourCents: Int?
        /// The most and least expensive pours on the shelf.
        public let dearestPour: Standout?
        public let cheapestPour: Standout?

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

    public static func summarise(
        _ entries: [Entry],
        now: Date = Date(),
        calendar: Calendar = .current
    ) -> Summary {
        let live = entries.filter { !$0.isFinished }
        let finished = entries.count - live.count

        let byClass = tally(live.compactMap { $0.classType?.label })
        let byDistillery = tally(live.compactMap(\.distillery))
        let byStrength = tally(live.compactMap { $0.abv.map(strengthBand) })
        let byBrand = tally(live.compactMap(\.brand))
        let byPlace = tally(live.compactMap {
            $0.storageLocation?.trimmingCharacters(in: .whitespaces)
        }.filter { !$0.isEmpty })

        // Years run oldest first: a growth line reads left to right. Every
        // bottle counts here, finished included -- it was added that year.
        let addedByYear = tally(entries.map { String(calendar.component(.year, from: $0.addedAt)) })
            .sorted { $0.label < $1.label }

        let longestOpen = live
            .filter(\.isOpen)
            .compactMap { entry -> Standout? in
                guard let name = entry.name,
                      let days = AgeMath.daysOpen(openedAt: entry.openedAt, now: now, calendar: calendar)
                else { return nil }
                return Standout(name: name, value: days)
            }
            .max { $0.value < $1.value }

        // Priced live bottles with a purchase date, grouped by that year.
        var spent: [String: Int] = [:]
        for entry in live {
            guard let cents = entry.purchasePriceCents, let at = entry.purchasedAt else { continue }
            spent[String(calendar.component(.year, from: at)), default: 0] += cents
        }
        let spentByYear = spent
            .map { Amount(label: $0.key, cents: $0.value) }
            .sorted { $0.label < $1.label }

        let pours = live.compactMap { entry -> Standout? in
            guard let name = entry.name, let cents = entry.costPerPourCents else { return nil }
            return Standout(name: name, value: cents)
        }
        let averagePour = pours.isEmpty
            ? nil
            : Int((Double(pours.reduce(0) { $0 + $1.value }) / Double(pours.count)).rounded())

        return Summary(
            onShelf: live.count,
            open: live.filter(\.isOpen).count,
            sealed: live.filter { !$0.isOpen }.count,
            finished: finished,
            byClass: byClass,
            byDistillery: byDistillery,
            byStrength: byStrength,
            byBrand: byBrand,
            byPlace: byPlace,
            addedByYear: addedByYear,
            distilleryCount: Set(live.compactMap(\.distillery)).count,
            classCount: Set(live.compactMap { $0.classType?.label }).count,
            picks: live.filter(\.isPick).count,
            highestProof: live.compactMap(\.abv).max().map { ABV(percent: $0).proof },
            oldestStatedAgeMonths: live.compactMap(\.ageMonths).max(),
            longestOpen: longestOpen,
            spentByYear: spentByYear,
            averageCostPerPourCents: averagePour,
            dearestPour: pours.max { $0.value < $1.value },
            cheapestPour: pours.min { $0.value < $1.value })
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
