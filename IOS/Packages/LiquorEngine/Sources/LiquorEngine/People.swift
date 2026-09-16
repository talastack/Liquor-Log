import Foundation

/// The people behind the bottles: who sent you samples, who you poured
/// for, and how that stands.
///
/// Sample swapping is half the hobby, and the bookkeeping is all in
/// people's heads: Mike sent three samples in the spring, you sent him
/// two pours off the Stagg, and whose turn is it? The app already holds
/// every side of that -- a sample bottle says who it came from, a pour
/// says who it went to, a tasting says what you thought of it -- so the
/// ledger is read, not kept. Per person: what came from them, what went
/// to them, the millilitres either way, and, once you have rated a few of
/// their samples, whether they have good taste. Nothing here is about
/// how much anybody drank; it is about what changed hands.
public enum People: Sendable {

    /// A sample that came from somebody.
    public struct Received: Hashable, Sendable {
        public let bottle: String
        public let milliliters: Double
        /// "A swap", "From a friend"…, as the sample was logged.
        public let how: String?
        public let at: Date
        /// Your rating of it, when you tasted it.
        public let rating: Int?

        public init(bottle: String, milliliters: Double, how: String? = nil, at: Date, rating: Int? = nil) {
            self.bottle = bottle; self.milliliters = milliliters; self.how = how; self.at = at; self.rating = rating
        }
    }

    /// A pour that went to somebody.
    public struct Given: Hashable, Sendable {
        public let bottle: String
        public let milliliters: Double
        public let at: Date

        public init(bottle: String, milliliters: Double, at: Date) {
            self.bottle = bottle; self.milliliters = milliliters; self.at = at
        }
    }

    public struct Person: Hashable, Sendable, Identifiable {
        public var id: String { key }
        /// Lowercased, trimmed: "Mike" and "mike " are one person.
        public let key: String
        /// The spelling you used most recently.
        public let name: String
        /// Newest first.
        public let received: [Received]
        /// Newest first.
        public let given: [Given]

        public var receivedMilliliters: Double { received.reduce(0) { $0 + $1.milliliters } }
        public var givenMilliliters: Double { given.reduce(0) { $0 + $1.milliliters } }
        public var lastAt: Date {
            max(received.first?.at ?? .distantPast, given.first?.at ?? .distantPast)
        }

        /// Their samples' average with you, over two or more rated.
        public var averageRating: Double? {
            let ratings = received.compactMap(\.rating)
            guard ratings.count >= 2 else { return nil }
            return Double(ratings.reduce(0, +)) / Double(ratings.count)
        }
    }

    // MARK: - Reading

    /// The ledger, most recent exchange first.
    public static func ledger(
        received: [(from: String, bottle: String, milliliters: Double, how: String?, at: Date, rating: Int?)],
        given: [(to: String, bottle: String, milliliters: Double, at: Date)]
    ) -> [Person] {
        var names: [String: (name: String, at: Date)] = [:]
        var got: [String: [Received]] = [:]
        var sent: [String: [Given]] = [:]

        func note(_ raw: String, at: Date) -> String? {
            let name = raw.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !name.isEmpty else { return nil }
            let key = name.lowercased()
            if let have = names[key], have.at >= at { return key }
            names[key] = (name, at)
            return key
        }

        for r in received {
            guard let key = note(r.from, at: r.at) else { continue }
            got[key, default: []].append(Received(bottle: r.bottle, milliliters: r.milliliters, how: r.how, at: r.at, rating: r.rating))
        }
        for g in given {
            guard let key = note(g.to, at: g.at) else { continue }
            sent[key, default: []].append(Given(bottle: g.bottle, milliliters: g.milliliters, at: g.at))
        }

        return names.map { key, spelling in
            Person(
                key: key, name: spelling.name,
                received: (got[key] ?? []).sorted { $0.at > $1.at },
                given: (sent[key] ?? []).sorted { $0.at > $1.at })
        }
        .sorted { $0.lastAt != $1.lastAt ? $0.lastAt > $1.lastAt : $0.name < $1.name }
    }

    // MARK: - Words

    /// "3 samples from them · 2 pours to them · last 3 weeks ago".
    public static func line(_ p: Person, now: Date = Date(), calendar: Calendar = .current) -> String {
        var parts: [String] = []
        if !p.received.isEmpty {
            parts.append("\(p.received.count) \(p.received.count == 1 ? "sample" : "samples") from them")
        }
        if !p.given.isEmpty {
            parts.append("\(p.given.count) \(p.given.count == 1 ? "pour" : "pours") to them")
        }
        parts.append("last \(Hunt.ago(AgeMath.days(from: p.lastAt, to: now, calendar: calendar)))")
        return parts.joined(separator: " · ")
    }

    /// Whose turn it is, in millilitres, when there is a real gap. Nil
    /// when nothing has gone either way; "About even" inside one pour.
    public static func balance(_ p: Person, ounces: Bool = false) -> String? {
        let gap = p.receivedMilliliters - p.givenMilliliters
        guard p.receivedMilliliters + p.givenMilliliters > 0 else { return nil }
        if abs(gap) < 30 { return "About even" }
        let amount = ounces
            ? String(format: "%.1f oz", abs(gap) / Volume.usFluidOunceInMilliliters)
            : "\(Int(abs(gap).rounded())) ml"
        return gap > 0
            ? "They have sent \(amount) more than you have"
            : "You have sent \(amount) more than they have"
    }

    /// "Their samples average 8.3 with you, over 3 rated." Nil under two.
    public static func taste(_ p: Person) -> String? {
        guard let average = p.averageRating else { return nil }
        let rated = p.received.compactMap(\.rating).count
        return String(format: "Their samples average %.1f with you, over %d rated.", average, rated)
    }
}
