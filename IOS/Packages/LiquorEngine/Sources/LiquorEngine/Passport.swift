import Foundation

/// The passport: the distilleries you have stood in.
///
/// A visit is a date and a name. Read back, the visits become stamps --
/// one per distillery, with how many times and when -- and two lists the
/// shelf can answer that no passport can: which of your bottles came from
/// a place you have been, and which distilleries on your shelf you have
/// never visited. Nothing here is a checklist of the catalogue; the
/// distilleries you have not been to are the ones whose bottles you own,
/// which is a list you might act on, not a list you cannot finish.
public enum Passport: Sendable {

    public struct Visit: Hashable, Sendable {
        public let distillery: String
        public let at: Date
        public let note: String?

        public init(distillery: String, at: Date, note: String? = nil) {
            self.distillery = distillery; self.at = at; self.note = note
        }
    }

    /// A bottle, as the passport needs it: where it was made and where it
    /// was bought.
    public struct Bottle: Hashable, Sendable {
        public let name: String
        public let distillery: String?
        public let boughtAt: String?

        public init(name: String, distillery: String?, boughtAt: String? = nil) {
            self.name = name; self.distillery = distillery; self.boughtAt = boughtAt
        }
    }

    public struct Stamp: Hashable, Sendable, Identifiable {
        public var id: String { key }
        public let key: String
        /// The spelling you used most recently.
        public let name: String
        public let visits: Int
        public let firstAt: Date
        public let lastAt: Date
        /// Bottles on the shelf made there.
        public let bottlesFromThere: [String]
        /// Bottles whose purchase store is the distillery itself.
        public let boughtThere: [String]
    }

    public struct Summary: Hashable, Sendable {
        /// Most recently visited first.
        public let stamps: [Stamp]
        public let visits: Int
        /// Distilleries with bottles on the shelf and no visit, most
        /// bottles first.
        public let notYetVisited: [(name: String, bottles: Int)]
        /// "6 distilleries, 9 visits." Nil with nothing recorded.
        public let headline: String?

        public static func == (a: Summary, b: Summary) -> Bool {
            a.stamps == b.stamps && a.visits == b.visits && a.headline == b.headline
                && a.notYetVisited.map(\.name) == b.notYetVisited.map(\.name)
        }
        public func hash(into hasher: inout Hasher) { hasher.combine(stamps); hasher.combine(visits) }
    }

    public static func summarise(visits: [Visit], shelf: [Bottle]) -> Summary {
        var byKey: [String: [Visit]] = [:]
        for v in visits {
            let key = normalise(v.distillery)
            guard !key.isEmpty else { continue }
            byKey[key, default: []].append(v)
        }
        let stamps = byKey.map { key, rows -> Stamp in
            let newest = rows.max { $0.at < $1.at }!
            let made = shelf.filter { $0.distillery.map(normalise) == key }.map(\.name).sorted()
            let bought = shelf.filter { $0.boughtAt.map(normalise) == key }.map(\.name).sorted()
            return Stamp(
                key: key, name: newest.distillery.trimmingCharacters(in: .whitespaces),
                visits: rows.count,
                firstAt: rows.map(\.at).min()!, lastAt: newest.at,
                bottlesFromThere: made, boughtThere: bought)
        }
        .sorted { $0.lastAt != $1.lastAt ? $0.lastAt > $1.lastAt : $0.name < $1.name }

        var unvisited: [String: (name: String, bottles: Int)] = [:]
        for bottle in shelf {
            guard let distillery = bottle.distillery else { continue }
            let key = normalise(distillery)
            guard !key.isEmpty, byKey[key] == nil else { continue }
            unvisited[key] = (name: distillery, bottles: (unvisited[key]?.bottles ?? 0) + 1)
        }
        let notYet = unvisited.values.sorted { $0.bottles != $1.bottles ? $0.bottles > $1.bottles : $0.name < $1.name }

        let headline: String? = stamps.isEmpty ? nil
            : "\(stamps.count) \(stamps.count == 1 ? "distillery" : "distilleries"), \(visits.count) \(visits.count == 1 ? "visit" : "visits")."
        return Summary(stamps: stamps, visits: visits.count, notYetVisited: notYet, headline: headline)
    }

    /// "3 visits · first March 2024 · last 3 weeks ago" or "Once, 3 weeks ago".
    public static func line(_ s: Stamp, now: Date = Date(), calendar: Calendar = .current) -> String {
        let last = Hunt.ago(AgeMath.days(from: s.lastAt, to: now, calendar: calendar))
        if s.visits == 1 { return "Once, \(last)" }
        return "\(s.visits) visits · first \(monthAndYear(s.firstAt, calendar: calendar)) · last \(last)"
    }

    /// "2 bottles from there on the shelf, 1 bought there." Nil with neither.
    public static func shelfLine(_ s: Stamp) -> String? {
        var parts: [String] = []
        if !s.bottlesFromThere.isEmpty {
            parts.append("\(s.bottlesFromThere.count) \(s.bottlesFromThere.count == 1 ? "bottle" : "bottles") from there on the shelf")
        }
        if !s.boughtThere.isEmpty {
            parts.append("\(s.boughtThere.count) bought there")
        }
        return parts.isEmpty ? nil : parts.joined(separator: ", ") + "."
    }

    public static func normalise(_ name: String) -> String {
        name.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            .replacingOccurrences(of: " distillery", with: "")
            .replacingOccurrences(of: " distilling co.", with: "")
            .replacingOccurrences(of: " distilling company", with: "")
            .replacingOccurrences(of: " distilling", with: "")
    }

    static func monthAndYear(_ date: Date, calendar: Calendar) -> String {
        let formatter = DateFormatter()
        formatter.calendar = calendar
        formatter.timeZone = calendar.timeZone
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "MMMM yyyy"
        return formatter.string(from: date)
    }
}
