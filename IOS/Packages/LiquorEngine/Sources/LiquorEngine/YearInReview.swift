import Foundation

/// A year of collecting, in a few sentences, from what was recorded.
///
/// What came onto the shelf, from where, what it cost; what was tasted and
/// how it rated; the word reached for most; who sent samples; where the
/// hunting happened. Every figure counts bottles, tastings, words, people
/// and stores -- what was collected and written -- and none counts pours
/// or bottles emptied. A year is a calendar year; nothing is compared with
/// the year before, and nothing is a streak.
public enum YearInReview: Sendable {

    public struct Facts: Sendable {
        public var added: [(name: String, classLabel: String?, distillery: String?, cents: Int?, at: Date)]
        public var opened: [Date]
        public var tastings: [(name: String, rating: Int?, at: Date, words: [String])]
        public var samples: [(from: String, at: Date)]
        public var sightings: [(store: String, at: Date)]
        public var lotteries: [(won: Bool?, at: Date)]

        public init(
            added: [(name: String, classLabel: String?, distillery: String?, cents: Int?, at: Date)] = [],
            opened: [Date] = [],
            tastings: [(name: String, rating: Int?, at: Date, words: [String])] = [],
            samples: [(from: String, at: Date)] = [],
            sightings: [(store: String, at: Date)] = [],
            lotteries: [(won: Bool?, at: Date)] = []
        ) {
            self.added = added; self.opened = opened; self.tastings = tastings
            self.samples = samples; self.sightings = sightings; self.lotteries = lotteries
        }
    }

    public struct Count: Hashable, Sendable {
        public let name: String
        public let count: Int
    }

    public struct Review: Hashable, Sendable {
        public let year: Int
        public let bottlesAdded: Int
        public let distilleries: Int
        public let topDistillery: Count?
        public let topClass: Count?
        /// What the added bottles with a price cost, together. Shown only
        /// behind the money switch; the sentence for it is separate.
        public let spentCents: Int?
        public let pricedBottles: Int
        public let firstBottle: (name: String, at: Date)?
        public let opened: Int
        public let tastings: Int
        public let best: (name: String, rating: Int)?
        public let wordOfTheYear: Count?
        public let samples: Int
        public let sampleSenders: [String]
        public let sightings: Int
        public let stores: Int
        public let topStore: Count?
        public let lotteriesEntered: Int
        public let lotteriesWon: Int

        /// The review as sentences, money left out.
        public let lines: [String]
        /// "$1,240.00 across the 11 with a price." Nil without one.
        public let moneyLine: String?

        public static func == (a: Review, b: Review) -> Bool { a.year == b.year && a.lines == b.lines && a.moneyLine == b.moneyLine }
        public func hash(into hasher: inout Hasher) { hasher.combine(year); hasher.combine(lines) }
    }

    /// The years with anything recorded, newest first.
    public static func years(_ f: Facts, calendar: Calendar = .current) -> [Int] {
        let dates = f.added.map(\.at) + f.opened + f.tastings.map(\.at) + f.samples.map(\.at)
            + f.sightings.map(\.at) + f.lotteries.map(\.at)
        return Set(dates.map { calendar.component(.year, from: $0) }).sorted(by: >)
    }

    /// Nil when nothing at all was recorded in the year.
    public static func review(_ f: Facts, year: Int, words: (String) -> String = { $0 }, calendar: Calendar = .current) -> Review? {
        func inYear(_ d: Date) -> Bool { calendar.component(.year, from: d) == year }
        let added = f.added.filter { inYear($0.at) }.sorted { $0.at < $1.at }
        let opened = f.opened.filter(inYear).count
        let tastings = f.tastings.filter { inYear($0.at) }
        let samples = f.samples.filter { inYear($0.at) }
        let sightings = f.sightings.filter { inYear($0.at) }
        let lotteries = f.lotteries.filter { inYear($0.at) }
        guard !added.isEmpty || opened > 0 || !tastings.isEmpty || !samples.isEmpty || !sightings.isEmpty || !lotteries.isEmpty else {
            return nil
        }

        let distilleries = counts(added.compactMap(\.distillery))
        let classes = counts(added.compactMap(\.classLabel))
        let priced = added.compactMap(\.cents)
        let best = tastings.compactMap { t in t.rating.map { (name: t.name, rating: $0) } }
            .max { $0.rating != $1.rating ? $0.rating < $1.rating : false }
        // Counted once per tasting, so a wheel picked heavily on one night
        // does not name the year.
        let wordCounts = counts(tastings.flatMap { Array(Set($0.words)) })
        let senders = orderedDistinct(samples.sorted { $0.at > $1.at }.map(\.from))
        let stores = counts(sightings.map { $0.store.trimmingCharacters(in: .whitespaces) })
        let won = lotteries.filter { $0.won == true }.count

        var lines: [String] = []
        if !added.isEmpty {
            var line = "\(added.count) \(added.count == 1 ? "bottle" : "bottles") added"
            if distilleries.count > 1 { line += ", from \(distilleries.count) distilleries" }
            if let top = distilleries.first, top.count > 1 { line += ". \(top.name) most, \(top.count) times" }
            lines.append(line + ".")
            if let top = classes.first, classes.count > 1, top.count > 1 {
                lines.append("Mostly \(top.name.lowercased()): \(top.count) of them.")
            }
            if let first = added.first {
                lines.append("First of the year: \(first.name), \(dayAndMonth(first.at, calendar: calendar)).")
            }
        }
        // Bottles opened is counted, for the screen's own use, but not said:
        // on a card that gets shared it reads as a tally of drinking, and
        // that is the one thing this must never be.
        if !tastings.isEmpty {
            var line = "\(tastings.count) \(tastings.count == 1 ? "tasting" : "tastings") written"
            if let best { line += ". Highest: \(best.name), \(best.rating)/10" }
            lines.append(line + ".")
            if let word = wordCounts.first, word.count >= 2 {
                lines.append("The word you reached for most: \(words(word.name)), \(word.count) times.")
            }
        }
        if !samples.isEmpty {
            let named = senders.prefix(3).joined(separator: ", ")
            let more = senders.count - min(senders.count, 3)
            lines.append("\(samples.count) \(samples.count == 1 ? "sample" : "samples") from \(named)\(more > 0 ? " and \(more) more" : "").")
        }
        if !sightings.isEmpty {
            var line = "\(sightings.count) \(sightings.count == 1 ? "sighting" : "sightings") at \(stores.count) \(stores.count == 1 ? "store" : "stores")"
            if let top = stores.first, stores.count > 1, top.count > 1 { line += "; \(top.name) most" }
            lines.append(line + ".")
        }
        if !lotteries.isEmpty {
            lines.append("\(lotteries.count) \(lotteries.count == 1 ? "lottery" : "lotteries") entered\(won > 0 ? ", \(won) won" : "").")
        }

        let spent = priced.isEmpty ? nil : priced.reduce(0, +)
        let moneyLine = spent.map { total in
            priced.count == added.count
                ? "\(Money.short(total)) across them."
                : "\(Money.short(total)) across the \(priced.count) with a price."
        }

        return Review(
            year: year, bottlesAdded: added.count, distilleries: distilleries.count,
            topDistillery: distilleries.first, topClass: classes.first,
            spentCents: spent, pricedBottles: priced.count,
            firstBottle: added.first.map { (name: $0.name, at: $0.at) },
            opened: opened, tastings: tastings.count, best: best,
            wordOfTheYear: wordCounts.first.map { Count(name: words($0.name), count: $0.count) },
            samples: samples.count, sampleSenders: senders,
            sightings: sightings.count, stores: stores.count, topStore: stores.first,
            lotteriesEntered: lotteries.count, lotteriesWon: won,
            lines: lines, moneyLine: moneyLine)
    }

    // MARK: - Pieces

    /// Most first; ties by name, so the answer is the same every time.
    static func counts(_ names: [String]) -> [Count] {
        var tally: [String: Int] = [:]
        for name in names where !name.isEmpty { tally[name, default: 0] += 1 }
        return tally.map { Count(name: $0.key, count: $0.value) }
            .sorted { $0.count != $1.count ? $0.count > $1.count : $0.name < $1.name }
    }

    static func orderedDistinct(_ names: [String]) -> [String] {
        var seen = Set<String>()
        return names.compactMap { name in
            let key = name.trimmingCharacters(in: .whitespaces).lowercased()
            guard !key.isEmpty, seen.insert(key).inserted else { return nil }
            return name.trimmingCharacters(in: .whitespaces)
        }
    }

    static func dayAndMonth(_ date: Date, calendar: Calendar) -> String {
        let formatter = DateFormatter()
        formatter.calendar = calendar
        formatter.timeZone = calendar.timeZone
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "d MMMM"
        return formatter.string(from: date)
    }
}
