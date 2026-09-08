import Foundation

/// Choose something to drink tonight.
///
/// A trivial feature that people mention unprompted as a reason they like an
/// app. It works because the problem is real: a shelf of forty open bottles is
/// a decision, and most nights you reach for the same three.
///
/// It leans toward bottles you have not poured from in a while — one of the
/// stated uses is *"to push myself to dig out a bottle that I really liked but
/// haven't poured from in a long time."* Neglect is the signal, not novelty.
public enum PickMyPour: Sendable {

    /// The minimum a bottle needs for this to consider it.
    public struct Candidate: Hashable, Sendable, Identifiable {
        public let id: String
        public let name: String
        /// Nil means never poured, which is the strongest pull of all.
        public let lastPouredAt: Date?
        public let isOpen: Bool
        public let remainingMilliliters: Double

        public init(
            id: String, name: String, lastPouredAt: Date?,
            isOpen: Bool, remainingMilliliters: Double
        ) {
            self.id = id
            self.name = name
            self.lastPouredAt = lastPouredAt
            self.isOpen = isOpen
            self.remainingMilliliters = remainingMilliliters
        }
    }

    public struct Choice: Hashable, Sendable {
        public let candidate: Candidate
        /// Why this one, in plain words. A random pick with no reason feels
        /// arbitrary; a reason makes it feel like a suggestion.
        public let reason: String
    }

    /// Bottles eligible to be poured from: open, and with something in them.
    ///
    /// A sealed bottle is deliberately excluded. Opening one is a decision the
    /// app should not make for somebody — it starts an oxidation clock and it is
    /// often the whole point of the bottle.
    public static func eligible(from candidates: [Candidate]) -> [Candidate] {
        candidates.filter { $0.isOpen && $0.remainingMilliliters > 0 }
    }

    /// Picks one, weighted toward neglect.
    ///
    /// `generator` is injected so a test can pin the outcome. Callers pass
    /// `SystemRandomNumberGenerator()`.
    public static func choose<G: RandomNumberGenerator>(
        from candidates: [Candidate],
        now: Date = Date(),
        using generator: inout G
    ) -> Choice? {
        let pool = eligible(from: candidates)
        guard !pool.isEmpty else { return nil }

        let weighted = pool.map { (candidate: $0, weight: weight(for: $0, now: now)) }
        let total = weighted.reduce(0) { $0 + $1.weight }
        guard total > 0 else {
            guard let any = pool.randomElement(using: &generator) else { return nil }
            return Choice(candidate: any, reason: reason(for: any, now: now))
        }

        var roll = Double.random(in: 0..<total, using: &generator)
        for entry in weighted {
            roll -= entry.weight
            if roll < 0 {
                return Choice(candidate: entry.candidate, reason: reason(for: entry.candidate, now: now))
            }
        }
        let last = weighted[weighted.count - 1].candidate
        return Choice(candidate: last, reason: reason(for: last, now: now))
    }

    /// Days since the last pour, capped. A bottle untouched for two years is not
    /// meaningfully more neglected than one untouched for one, and without a cap
    /// a single forgotten bottle would win every time and stop being a surprise.
    static let neglectCapDays = 365.0

    static func weight(for candidate: Candidate, now: Date) -> Double {
        guard let last = candidate.lastPouredAt else {
            // Never poured. Deliberately the strongest pull: an open bottle you
            // have not tasted is the one most worth being reminded of.
            return neglectCapDays
        }
        let days = now.timeIntervalSince(last) / 86_400
        // Everything keeps a floor of 1 so a bottle poured yesterday can still
        // come up. A suggestion that never surprises stops being used.
        return max(1, min(neglectCapDays, days))
    }

    static func reason(for candidate: Candidate, now: Date) -> String {
        guard let last = candidate.lastPouredAt else {
            return "Open, and you have not poured from it yet."
        }
        let days = Int(now.timeIntervalSince(last) / 86_400)
        switch days {
        case ..<7: return "You had this recently. Still good."
        case ..<30: return "Not for a couple of weeks."
        case ..<120: return "It has been a couple of months."
        case ..<365: return "You have not touched this in months."
        default: return "Over a year since your last pour."
        }
    }
}
