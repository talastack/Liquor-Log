import Foundation

/// The laser-etched bottling code on a Buffalo Trace bottle.
///
/// Every bottle out of Frankfort -- Blanton's, Weller, Stagg, Taylor, Eagle
/// Rare, Buffalo Trace itself -- carries a small etched line near the base
/// of the glass, and the community worked out years ago what it says:
///
///     L19274 15:02 K
///     │ │ │   │     └ bottling line
///     │ │ │   └ time of day, 24-hour
///     │ │ └ day of the year, 1-366
///     │ └ year, two digits
///     └ a fixed leading letter
///
/// So `L19274` is the 274th day of 2019: 1 October. That is the bottling
/// date, which for Weller and Taylor is the only date the bottle has, and
/// for a Blanton's sits beside the dump date on the label. The 10 September
/// brief found no interactive decoder for this anywhere; the knowledge lives
/// in blog posts that stopped updating.
///
/// Only the parts that are certain are decoded. The leading letter and the
/// line letter are shown as they are; what plant or line they name is not
/// something this app will assert without a source.
public struct LaserCode: Hashable, Sendable, CustomStringConvertible {
    public let prefix: Character?
    public let year: Int
    public let dayOfYear: Int
    public let hour: Int?
    public let minute: Int?
    public let line: Character?

    public init(prefix: Character?, year: Int, dayOfYear: Int, hour: Int? = nil, minute: Int? = nil, line: Character? = nil) {
        self.prefix = prefix
        self.year = year
        self.dayOfYear = dayOfYear
        self.hour = hour
        self.minute = minute
        self.line = line
    }

    /// Reads the code as etched, with or without the spaces and the colon.
    /// Nil when the digits do not make a date -- day 400 is not a typo the
    /// decoder should silently repair.
    public init?(_ raw: String) {
        let text = raw.uppercased()
            .replacingOccurrences(of: " ", with: "")
            .replacingOccurrences(of: ":", with: "")
        // [letter] YY DDD [HHMM] [letter]
        guard let regex = try? NSRegularExpression(pattern: #"^([A-Z])?(\d{2})(\d{3})(\d{4})?([A-Z])?$"#),
              let match = regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text))
        else { return nil }

        func group(_ index: Int) -> String? {
            guard let range = Range(match.range(at: index), in: text) else { return nil }
            return String(text[range])
        }
        guard let yy = group(2).flatMap(Int.init), let ddd = group(3).flatMap(Int.init),
              (1...366).contains(ddd)
        else { return nil }

        // The scheme is a 2000s one; a two-digit year means 20YY.
        year = 2000 + yy
        dayOfYear = ddd
        prefix = group(1)?.first
        line = group(5)?.first
        if let hhmm = group(4), let h = Int(hhmm.prefix(2)), let m = Int(hhmm.suffix(2)),
           (0...23).contains(h), (0...59).contains(m) {
            hour = h
            minute = m
        } else {
            hour = nil
            minute = nil
        }
        // Day 366 only exists in a leap year.
        if ddd == 366, !Self.isLeap(year) { return nil }
    }

    /// The bottling date. Nil only if the calendar refuses, which for a
    /// checked day-of-year it does not.
    public func date(calendar: Calendar = .current) -> Date? {
        var parts = DateComponents()
        parts.year = year
        parts.month = 1
        parts.day = 1
        guard let first = calendar.date(from: parts) else { return nil }
        return calendar.date(byAdding: .day, value: dayOfYear - 1, to: first)
    }

    public var description: String {
        var out = (prefix.map { String($0) } ?? "") + String(format: "%02d%03d", year % 100, dayOfYear)
        if let hour, let minute { out += String(format: " %02d:%02d", hour, minute) }
        if let line { out += " " + String(line) }
        return out
    }

    /// "Bottled 1 October 2019 at 15:02, line K."
    public func summary(calendar: Calendar = .current) -> String {
        let when: String
        if let date = date(calendar: calendar) {
            let parts = calendar.dateComponents([.day, .month, .year], from: date)
            when = "\(parts.day ?? 0) \(BatchCode.monthName(parts.month ?? 0)) \(parts.year ?? year)"
        } else {
            when = "day \(dayOfYear) of \(year)"
        }
        var out = "Bottled \(when)"
        if let hour, let minute { out += String(format: " at %02d:%02d", hour, minute) }
        if let line { out += ", line \(line)" }
        return out + "."
    }

    static func isLeap(_ year: Int) -> Bool {
        (year % 4 == 0 && year % 100 != 0) || year % 400 == 0
    }
}
