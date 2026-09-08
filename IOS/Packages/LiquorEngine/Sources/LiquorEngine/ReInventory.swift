import Foundation

/// The annual shelf walk.
///
/// Every long-running collection system decays. People say so plainly: *"I used
/// Only Drams but I drink/buy/trade too often to keep it current"*, *"According
/// to only drams, I'm sitting on 307 bottles with 120 open."* The coping
/// mechanism people arrive at independently is a periodic bulk re-inventory,
/// one to three times a year. Almost no app has one.
///
/// The design constraint that makes or breaks it: **you are walking past
/// physical shelves, not scrolling a list.** So the queue is ordered by where a
/// bottle is first and how stale the record is second. A list that sends you
/// from the closet to the basement and back is a list nobody finishes.
public enum ReInventory: Sendable {

    /// One bottle to lay eyes on.
    public struct Item: Hashable, Sendable, Identifiable {
        public let id: String
        public let name: String
        /// Free text, as people actually write it: "hall closet", "bar top".
        public let storageLocation: String?
        /// Nil means it has never been confirmed since it was added.
        public let lastVerifiedAt: Date?
        public let isOpen: Bool

        public init(
            id: String,
            name: String,
            storageLocation: String? = nil,
            lastVerifiedAt: Date? = nil,
            isOpen: Bool = false
        ) {
            self.id = id
            self.name = name
            self.storageLocation = storageLocation
            self.lastVerifiedAt = lastVerifiedAt
            self.isOpen = isOpen
        }
    }

    /// What you found when you looked.
    ///
    /// `gone` is deliberately not called "deleted". A bottle you finished and
    /// forgot to log is killed and archived, never removed — the same rule the
    /// rest of the app follows.
    public enum Verdict: String, Hashable, Sendable, CaseIterable {
        case present
        case gone
        case skipped
    }

    /// Bottles that share a location, in one pass.
    public struct Leg: Hashable, Sendable, Identifiable {
        /// Nil for everything with no location recorded.
        public let location: String?
        public let items: [Item]

        public var id: String { location ?? "\u{0}unplaced" }

        /// What to call this leg on screen.
        public var title: String { location ?? "No location recorded" }

        public init(location: String?, items: [Item]) {
            self.location = location
            self.items = items
        }
    }

    /// The walk, grouped by location and ordered so the stalest shelf comes
    /// first.
    ///
    /// Within a leg the stalest bottle leads, so an interrupted walk still
    /// leaves the collection better than it found it. Bottles with no location
    /// always come last: they are the ones you have to hunt for, and putting
    /// them first is how a walk stalls on its first entry.
    public static func plan(_ items: [Item], now: Date = Date()) -> [Leg] {
        let grouped = Dictionary(grouping: items) { $0.storageLocation }

        let legs = grouped.map { location, members in
            Leg(
                location: location,
                items: members.sorted {
                    let left = staleness(of: $0, now: now)
                    let right = staleness(of: $1, now: now)
                    if left != right { return left > right }
                    return $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending
                })
        }

        return legs.sorted { left, right in
            // Unplaced bottles last, whatever their staleness.
            if (left.location == nil) != (right.location == nil) {
                return right.location == nil
            }
            let leftStale = left.items.map { staleness(of: $0, now: now) }.max() ?? 0
            let rightStale = right.items.map { staleness(of: $0, now: now) }.max() ?? 0
            if leftStale != rightStale { return leftStale > rightStale }
            return (left.location ?? "").localizedCaseInsensitiveCompare(right.location ?? "")
                == .orderedAscending
        }
    }

    /// Days since a bottle was last confirmed by eye.
    ///
    /// Never confirmed sorts above everything, because a bottle nobody has ever
    /// looked at is the least trustworthy row in the collection.
    public static func staleness(of item: Item, now: Date = Date()) -> Double {
        guard let last = item.lastVerifiedAt else { return .greatestFiniteMagnitude }
        return max(0, now.timeIntervalSince(last) / 86_400)
    }

    /// Whether a walk is worth suggesting at all.
    ///
    /// People do this one to three times a year, so nagging sooner trains them
    /// to ignore it. Six months is the low end of the stated range.
    public static let suggestAfterDays = 182.0

    /// True when the oldest confirmation is old enough to be worth a prompt.
    /// An empty collection never prompts.
    public static func isDue(_ items: [Item], now: Date = Date()) -> Bool {
        guard !items.isEmpty else { return false }
        return items.contains { staleness(of: $0, now: now) >= suggestAfterDays }
    }

    /// What a finished (or abandoned) walk did.
    public struct Outcome: Hashable, Sendable {
        public let confirmed: [String]
        public let gone: [String]
        public let skipped: [String]

        public init(confirmed: [String], gone: [String], skipped: [String]) {
            self.confirmed = confirmed
            self.gone = gone
            self.skipped = skipped
        }

        public var checkedCount: Int { confirmed.count + gone.count }
        public var isEmpty: Bool { confirmed.isEmpty && gone.isEmpty && skipped.isEmpty }

        /// Plain words, no celebration. Marking bottles finished is bookkeeping,
        /// not an achievement — nothing in this app treats drinking more as
        /// progress.
        public var summary: String {
            if isEmpty { return "Nothing checked." }
            var parts: [String] = []
            if !confirmed.isEmpty {
                parts.append("\(confirmed.count) still on the shelf")
            }
            if !gone.isEmpty {
                parts.append("\(gone.count) marked finished")
            }
            if !skipped.isEmpty {
                parts.append("\(skipped.count) skipped for now")
            }
            return parts.joined(separator: ", ") + "."
        }
    }

    /// Folds a set of decisions into an outcome, in the order they were made.
    public static func outcome(from decisions: [(id: String, verdict: Verdict)]) -> Outcome {
        var confirmed: [String] = []
        var gone: [String] = []
        var skipped: [String] = []
        // Last decision on a bottle wins: people change their mind mid-shelf.
        var latest: [String: Verdict] = [:]
        var order: [String] = []
        for decision in decisions {
            if latest[decision.id] == nil { order.append(decision.id) }
            latest[decision.id] = decision.verdict
        }
        for id in order {
            switch latest[id] {
            case .present: confirmed.append(id)
            case .gone: gone.append(id)
            case .skipped, nil: skipped.append(id)
            }
        }
        return Outcome(confirmed: confirmed, gone: gone, skipped: skipped)
    }
}
