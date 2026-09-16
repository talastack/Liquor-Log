import Foundation

/// The hunt: where you looked, what was on the shelf, and the lotteries
/// you put your name in.
///
/// Half of collecting allocated whiskey happens before a bottle is bought:
/// the Tuesday you saw Blanton's at the Total Wine on Broadway at $74.99
/// with three on the shelf, the state lottery you entered in March and
/// heard nothing back from. Nobody writes that down, so nobody knows which
/// store actually gets the good stuff or how their lottery luck runs. This
/// keeps the record and reads it back: stores ranked by what you have
/// found there, your wishlist against what has been seen lately, and
/// entered / won / pending as a count. Every figure is yours, from what
/// you logged; nothing here says where a bottle is now.
public enum Hunt: Sendable {

    public enum Kind: String, Sendable, Hashable, CaseIterable, Codable {
        /// On a shelf, at a price, in some number.
        case seen
        /// A lottery or raffle entered, with its outcome when known.
        case entered

        public var label: String {
            switch self {
            case .seen: return "Seen on a shelf"
            case .entered: return "Entered a lottery"
            }
        }
    }

    public enum Outcome: String, Sendable, Hashable, CaseIterable, Codable {
        case won, lost

        public var label: String {
            switch self {
            case .won: return "Won"
            case .lost: return "Lost"
            }
        }
    }

    /// One entry in the log, reduced to what the reading needs.
    public struct Sighting: Hashable, Sendable, Identifiable {
        public let id: String
        public let productId: String?
        public let name: String
        public let store: String
        public let kind: Kind
        public let outcome: Outcome?
        public let cents: Int?
        public let count: Int?
        public let at: Date
        /// Set once the bottle was bought and is on the shelf.
        public let boughtBottleId: String?

        public init(
            id: String, productId: String?, name: String, store: String,
            kind: Kind = .seen, outcome: Outcome? = nil,
            cents: Int? = nil, count: Int? = nil, at: Date, boughtBottleId: String? = nil
        ) {
            self.id = id; self.productId = productId; self.name = name; self.store = store
            self.kind = kind; self.outcome = outcome; self.cents = cents; self.count = count
            self.at = at; self.boughtBottleId = boughtBottleId
        }
    }

    /// One store, from what you logged there.
    public struct Store: Hashable, Sendable, Identifiable {
        public var id: String { key }
        /// Lowercased, trimmed: "Total Wine" and "total wine " are one store.
        public let key: String
        /// The spelling you used most recently.
        public let name: String
        /// Shelf sightings logged there.
        public let sightings: Int
        /// Distinct products seen there.
        public let products: Int
        /// Sightings of products on your wishlist.
        public let wishlistHits: Int
        public let lastAt: Date

        public init(key: String, name: String, sightings: Int, products: Int, wishlistHits: Int, lastAt: Date) {
            self.key = key; self.name = name; self.sightings = sightings
            self.products = products; self.wishlistHits = wishlistHits; self.lastAt = lastAt
        }
    }

    public struct Lotteries: Hashable, Sendable {
        public let entered: Int
        public let won: Int
        public let lost: Int
        public var pending: Int { entered - won - lost }

        public init(entered: Int, won: Int, lost: Int) {
            self.entered = entered; self.won = won; self.lost = lost
        }

        /// "4 entered · 1 won · 2 pending". Nil with nothing entered.
        public var line: String? {
            guard entered > 0 else { return nil }
            var parts = ["\(entered) entered"]
            if won > 0 { parts.append("\(won) won") }
            if lost > 0 { parts.append("\(lost) lost") }
            if pending > 0 { parts.append("\(pending) pending") }
            return parts.joined(separator: " · ")
        }
    }

    public struct Summary: Hashable, Sendable {
        public let seen: Int
        /// Ranked: most sightings first, then most recent.
        public let stores: [Store]
        public let lotteries: Lotteries
        /// "31 sightings at 6 stores · 4 lotteries entered, 1 won". Nil when
        /// the log is empty.
        public let headline: String?

        public static let empty = Summary(seen: 0, stores: [], lotteries: Lotteries(entered: 0, won: 0, lost: 0), headline: nil)
    }

    // MARK: - Reading the log

    public static func summarise(_ sightings: [Sighting], wishlist: Set<String> = []) -> Summary {
        let seen = sightings.filter { $0.kind == .seen }
        let entered = sightings.filter { $0.kind == .entered }
        let lotteries = Lotteries(
            entered: entered.count,
            won: entered.filter { $0.outcome == .won }.count,
            lost: entered.filter { $0.outcome == .lost }.count)

        var byStore: [String: [Sighting]] = [:]
        for s in seen { byStore[storeKey(s.store), default: []].append(s) }
        let stores = byStore.map { key, rows -> Store in
            let newest = rows.max { $0.at < $1.at }!
            return Store(
                key: key,
                name: newest.store.trimmingCharacters(in: .whitespaces),
                sightings: rows.count,
                products: Set(rows.map { $0.productId ?? $0.name.lowercased() }).count,
                wishlistHits: rows.filter { $0.productId.map(wishlist.contains) ?? false }.count,
                lastAt: newest.at)
        }
        .sorted { a, b in a.sightings != b.sightings ? a.sightings > b.sightings : a.lastAt > b.lastAt }

        var headline: String?
        if !seen.isEmpty || lotteries.entered > 0 {
            var parts: [String] = []
            if !seen.isEmpty {
                parts.append("\(seen.count) \(seen.count == 1 ? "sighting" : "sightings") at \(stores.count) \(stores.count == 1 ? "store" : "stores")")
            }
            if lotteries.entered > 0 {
                var lot = "\(lotteries.entered) \(lotteries.entered == 1 ? "lottery" : "lotteries") entered"
                if lotteries.won > 0 { lot += ", \(lotteries.won) won" }
                parts.append(lot)
            }
            headline = parts.joined(separator: " · ")
        }
        return Summary(seen: seen.count, stores: stores, lotteries: lotteries, headline: headline)
    }

    /// The newest shelf sighting of a product. Nil when it was never seen.
    public static func latest(productId: String, in sightings: [Sighting]) -> Sighting? {
        sightings
            .filter { $0.kind == .seen && $0.productId == productId }
            .max { $0.at < $1.at }
    }

    /// Wishlist products seen on a shelf in the last `days`, newest sighting
    /// per product, newest first. What the list is for: knowing where to go.
    public static func onYourList(
        _ sightings: [Sighting], wishlist: Set<String>,
        within days: Int = 60, now: Date = Date(), calendar: Calendar = .current
    ) -> [Sighting] {
        var newest: [String: Sighting] = [:]
        for s in sightings where s.kind == .seen && s.boughtBottleId == nil {
            guard let id = s.productId, wishlist.contains(id) else { continue }
            guard AgeMath.days(from: s.at, to: now, calendar: calendar) <= days else { continue }
            if let have = newest[id], have.at >= s.at { continue }
            newest[id] = s
        }
        return newest.values.sorted { $0.at > $1.at }
    }

    // MARK: - Words

    /// "At Total Wine 12 days ago · $74.99 · 3 on the shelf", or for a
    /// lottery "Virginia ABC, 3 weeks ago · pending".
    public static func line(_ s: Sighting, now: Date = Date(), calendar: Calendar = .current) -> String {
        let when = ago(AgeMath.days(from: s.at, to: now, calendar: calendar))
        switch s.kind {
        case .seen:
            var parts = ["At \(s.store.trimmingCharacters(in: .whitespaces)) \(when)"]
            if let cents = s.cents { parts.append(Money.short(cents)) }
            if let count = s.count {
                parts.append(count == 0 ? "sold out" : "\(count) on the shelf")
            }
            if s.boughtBottleId != nil { parts.append("bought") }
            return parts.joined(separator: " · ")
        case .entered:
            let status = s.outcome?.label.lowercased() ?? "pending"
            return "\(s.store.trimmingCharacters(in: .whitespaces)), \(when) · \(status)"
        }
    }

    /// "today", "yesterday", "12 days ago", "3 weeks ago", "4 months ago".
    public static func ago(_ days: Int) -> String {
        switch days {
        case ..<1: return "today"
        case 1: return "yesterday"
        case ..<14: return "\(days) days ago"
        case ..<60: return "\(days / 7) weeks ago"
        case ..<365: return "\(days / 30) months ago"
        default: return days / 365 == 1 ? "a year ago" : "\(days / 365) years ago"
        }
    }

    public static func storeKey(_ store: String) -> String {
        store.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }
}
