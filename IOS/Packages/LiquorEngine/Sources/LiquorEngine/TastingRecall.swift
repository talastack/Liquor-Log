import Foundation

/// What you said last time, in one line, at the moment it is useful.
///
/// The most common sentence in reviews of every collection app is some form
/// of *"I can't remember what I liked."* The tasting is in the database; the
/// failure is that it is three taps away when the question is being asked
/// -- in the aisle, or choosing tonight's pour. This puts the latest
/// tasting where the decision is, as one sentence built only from what was
/// recorded. Nothing rated, nothing written: no line.
public enum TastingRecall: Sendable {

    /// "Last time, in March: 8/10, would buy again. Liked toffee. Not the
    /// heat." Any missing part is left out rather than filled in.
    public static func line(
        _ tasting: TastingRecord,
        now: Date = Date(),
        calendar: Calendar = .current
    ) -> String? {
        var facts: [String] = []
        if let rating = tasting.rating { facts.append("\(rating)/10") }
        switch tasting.wouldRebuy {
        case .some(true): facts.append("would buy again")
        case .some(false): facts.append("would not buy again")
        case .none: break
        }

        var sentences: [String] = []
        if let liked = tasting.liked?.trimmingCharacters(in: .whitespacesAndNewlines), !liked.isEmpty {
            sentences.append("Liked \(liked).")
        }
        if let disliked = tasting.disliked?.trimmingCharacters(in: .whitespacesAndNewlines), !disliked.isEmpty {
            sentences.append("Not \(disliked).")
        }

        guard !facts.isEmpty || !sentences.isEmpty else { return nil }

        var head = "Last time, \(when(tasting.tastedAt, now: now, calendar: calendar))"
        if let where_ = tasting.where_ { head += " (\(where_.lowercased()))" }
        head += facts.isEmpty ? "." : ": " + facts.joined(separator: ", ") + "."
        return ([head] + sentences).joined(separator: " ")
    }

    /// "today", "yesterday", "12 days ago", "in March", "in March 2025".
    static func when(_ date: Date, now: Date, calendar: Calendar) -> String {
        let days = calendar.dateComponents(
            [.day], from: calendar.startOfDay(for: date), to: calendar.startOfDay(for: now)).day ?? 0
        switch days {
        case ..<0: return "later"   // a clock set forward; say something rather than lie about a date
        case 0: return "today"
        case 1: return "yesterday"
        case ..<30: return "\(days) days ago"
        default:
            let formatter = DateFormatter()
            formatter.calendar = calendar
            formatter.locale = Locale(identifier: "en_US_POSIX")
            let sameYear = calendar.component(.year, from: date) == calendar.component(.year, from: now)
            formatter.dateFormat = sameYear ? "MMMM" : "MMMM yyyy"
            return "in " + formatter.string(from: date)
        }
    }
}
