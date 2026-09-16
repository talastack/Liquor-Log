import Foundation

/// The life of a bottle, told from what was recorded.
///
/// Every other screen shows the bottle as it is now. This one puts the
/// record in order: bottled (when the label or its code says), bought,
/// opened, each pour and who it went to, each tasting and what changed,
/// each level set by eye or by weight, finished -- with the gaps between
/// them said in days, which is where the story is: opened after two years
/// on the shelf, finished ninety days later, the rating up a point by the
/// end. Nothing here is inferred; an event with no date is not an event.
public enum BottleStory: Sendable {

    public enum Kind: String, Sendable, Hashable {
        case bottled, bought, opened, pour, gift, tasting, level, addition, finished
    }

    public struct Event: Hashable, Sendable, Identifiable {
        public let date: Date
        public let kind: Kind
        public let title: String
        public let detail: String?
        public var id: String { "\(kind.rawValue)-\(Int(date.timeIntervalSince1970 * 1000))-\(title)" }

        public init(date: Date, kind: Kind, title: String, detail: String? = nil) {
            self.date = date; self.kind = kind; self.title = title; self.detail = detail
        }
    }

    /// What the caller knows about the bottle. Every field optional: the
    /// story is whatever was recorded.
    public struct Facts: Sendable {
        public var name: String
        public var bottledAt: Date?
        public var bottledText: String?
        public var boughtAt: Date?
        public var boughtWhere: String?
        public var paidText: String?
        public var openedAt: Date?
        public var finishedAt: Date?
        public var pours: [(at: Date, milliliters: Double, givenTo: String?, into: String?)]
        public var tastings: [(at: Date, rating: Int?, blind: Bool, liked: String?)]
        public var readings: [(at: Date, milliliters: Double, note: String?)]
        public var additions: [(at: Date, milliliters: Double, from: String)]

        public init(
            name: String, bottledAt: Date? = nil, bottledText: String? = nil,
            boughtAt: Date? = nil, boughtWhere: String? = nil, paidText: String? = nil,
            openedAt: Date? = nil, finishedAt: Date? = nil,
            pours: [(at: Date, milliliters: Double, givenTo: String?, into: String?)] = [],
            tastings: [(at: Date, rating: Int?, blind: Bool, liked: String?)] = [],
            readings: [(at: Date, milliliters: Double, note: String?)] = [],
            additions: [(at: Date, milliliters: Double, from: String)] = []
        ) {
            self.name = name; self.bottledAt = bottledAt; self.bottledText = bottledText
            self.boughtAt = boughtAt; self.boughtWhere = boughtWhere; self.paidText = paidText
            self.openedAt = openedAt; self.finishedAt = finishedAt
            self.pours = pours; self.tastings = tastings; self.readings = readings; self.additions = additions
        }
    }

    public struct Story: Sendable {
        public let events: [Event]
        /// "Opened after 412 days on the shelf. Finished 97 days later:
        /// 17 pours, 3 tastings, the rating up from 7 to 9."
        public let summary: String?

        public init(events: [Event], summary: String?) {
            self.events = events
            self.summary = summary
        }

        public static let empty = Story(events: [], summary: nil)
    }

    public static func tell(_ f: Facts, ounces: Bool = false, calendar: Calendar = .current) -> Story {
        var events: [Event] = []

        if let at = f.bottledAt {
            events.append(Event(date: at, kind: .bottled, title: "Bottled", detail: f.bottledText))
        }
        if let at = f.boughtAt {
            var detail: [String] = []
            if let paid = f.paidText { detail.append(paid) }
            if let where_ = f.boughtWhere { detail.append("at \(where_)") }
            if let bottled = f.bottledAt {
                let days = AgeMath.days(from: bottled, to: at, calendar: calendar)
                if days > 30 { detail.append("\(Self.span(days)) after bottling") }
            }
            events.append(Event(date: at, kind: .bought, title: "Bought", detail: detail.isEmpty ? nil : detail.joined(separator: " · ")))
        }
        if let at = f.openedAt {
            var detail: String?
            if let bought = f.boughtAt {
                let days = AgeMath.days(from: bought, to: at, calendar: calendar)
                detail = days <= 0 ? "The day it was bought" : "After \(Self.span(days)) on the shelf"
            }
            events.append(Event(date: at, kind: .opened, title: "Opened", detail: detail))
        }
        for pour in f.pours {
            let amount = Self.volume(pour.milliliters, ounces: ounces)
            if let into = pour.into {
                events.append(Event(date: pour.at, kind: .gift, title: "\(amount) into \(into)"))
            } else if let who = pour.givenTo {
                events.append(Event(date: pour.at, kind: .gift, title: "\(amount) to \(who)"))
            } else {
                events.append(Event(date: pour.at, kind: .pour, title: "A pour", detail: amount))
            }
        }
        for tasting in f.tastings {
            var title = "Tasted"
            if let rating = tasting.rating { title += " · \(rating)/10" }
            if tasting.blind { title += " · blind" }
            events.append(Event(date: tasting.at, kind: .tasting, title: title, detail: tasting.liked.map { "Liked \($0)" }))
        }
        for reading in f.readings {
            events.append(Event(date: reading.at, kind: .level,
                                title: "Level set: \(Self.volume(reading.milliliters, ounces: ounces))",
                                detail: reading.note))
        }
        for addition in f.additions {
            events.append(Event(date: addition.at, kind: .addition,
                                title: "\(Self.volume(addition.milliliters, ounces: ounces)) in from \(addition.from)"))
        }
        if let at = f.finishedAt {
            var detail: String?
            if let opened = f.openedAt {
                detail = "\(Self.span(AgeMath.days(from: opened, to: at, calendar: calendar))) after opening"
            }
            events.append(Event(date: at, kind: .finished, title: "Finished", detail: detail))
        }

        events.sort { $0.date != $1.date ? $0.date < $1.date : $0.kind.rawValue < $1.kind.rawValue }
        return Story(events: events, summary: summary(f, calendar: calendar))
    }

    static func summary(_ f: Facts, calendar: Calendar) -> String? {
        var parts: [String] = []
        if let bought = f.boughtAt, let opened = f.openedAt {
            let days = AgeMath.days(from: bought, to: opened, calendar: calendar)
            if days > 0 { parts.append("Opened after \(span(days)) on the shelf.") }
        }
        let ownPours = f.pours.filter { $0.givenTo == nil && $0.into == nil }.count
        let given = f.pours.count - ownPours
        let ratings = f.tastings.sorted { $0.at < $1.at }.compactMap(\.rating)
        if let opened = f.openedAt, let finished = f.finishedAt {
            var tail: [String] = []
            if ownPours > 0 { tail.append("\(ownPours) \(ownPours == 1 ? "pour" : "pours")") }
            if given > 0 { tail.append("\(given) given away") }
            if !f.tastings.isEmpty { tail.append("\(f.tastings.count) \(f.tastings.count == 1 ? "tasting" : "tastings")") }
            if let first = ratings.first, let last = ratings.last, ratings.count > 1, first != last {
                tail.append(last > first ? "the rating up from \(first) to \(last)" : "the rating down from \(first) to \(last)")
            }
            let days = AgeMath.days(from: opened, to: finished, calendar: calendar)
            parts.append("Finished \(span(days)) later" + (tail.isEmpty ? "." : ": " + tail.joined(separator: ", ") + "."))
        } else if f.openedAt != nil, !f.tastings.isEmpty || ownPours > 0 {
            var tail: [String] = []
            if ownPours > 0 { tail.append("\(ownPours) \(ownPours == 1 ? "pour" : "pours") so far") }
            if let first = ratings.first, let last = ratings.last, ratings.count > 1, first != last {
                tail.append(last > first ? "the rating up from \(first) to \(last)" : "the rating down from \(first) to \(last)")
            }
            if !tail.isEmpty { parts.append(tail.joined(separator: ", ").capitalizedFirst + ".") }
        }
        return parts.isEmpty ? nil : parts.joined(separator: " ")
    }

    /// "3 days", "6 weeks", "14 months", "2 years". Round, because the
    /// story is read, not audited; the events carry the exact dates.
    static func span(_ days: Int) -> String {
        switch days {
        case ..<14: return "\(days) \(days == 1 ? "day" : "days")"
        case ..<60: return "\(days / 7) weeks"
        case ..<730: return "\(days / 30) months"
        default: return "\(days / 365) years"
        }
    }

    static func volume(_ ml: Double, ounces: Bool) -> String {
        ounces ? String(format: "%.1f oz", ml / Volume.usFluidOunceInMilliliters) : "\(Int(ml.rounded())) ml"
    }
}

private extension String {
    var capitalizedFirst: String {
        guard let first = first else { return self }
        return first.uppercased() + dropFirst()
    }
}
