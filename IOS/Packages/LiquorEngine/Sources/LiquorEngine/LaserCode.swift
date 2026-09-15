import Foundation

/// The laser-etched bottling code on a Buffalo Trace bottle.
///
/// Every bottle out of Frankfort -- Blanton's, Weller, Stagg, Taylor, Eagle
/// Rare, Buffalo Trace itself -- carries an etched line near the base of
/// the glass. The distillery has never published the scheme; the community
/// worked it out from thousands of bottles, and two independent write-ups
/// agree on it (both read 15 September 2026):
///
/// - https://debonairgentlemen.com/2023/09/25/how-to-read-a-buffalo-trace-laser-code/
/// - https://whiskeyjar.blog/2020/06/14/happy-national-bourbon-day-sipping-on-col-e-h-taylor-single-barrel-and-a-bit-about-laser-codes-on-buffalo-trace-bottles-and-the-vintage-of-those-bourbons/
///
/// Since 2012:
///
///     L 18 096 01 1050 K
///     │ │  │   │  │    └ bottling line
///     │ │  │   │  └ time of day, 24-hour
///     │ │  │   └ plant number
///     │ │  └ day of the year, 1-366
///     │ └ year, two digits
///     └ lot designation, always L
///
/// so that bottle was filled on the 96th day of 2018, 6 April, at 10:50.
/// From 2007 to 2011 the order was different -- `K 259 10 15:47` is line K,
/// day 259, 2010, 15:47 -- and both are read. The plant number and the
/// time are kept when present and never invented when absent.
///
/// For a Weller or a Taylor this is the only date the bottle carries; for a
/// Blanton's it sits beside the dump date. A day that does not exist (400,
/// or 366 in a non-leap year) is refused rather than repaired.
public struct LaserCode: Hashable, Sendable, CustomStringConvertible {
    public let prefix: Character?
    public let year: Int
    public let dayOfYear: Int
    public let plant: Int?
    public let hour: Int?
    public let minute: Int?
    public let line: Character?

    public init(prefix: Character?, year: Int, dayOfYear: Int, plant: Int? = nil,
                hour: Int? = nil, minute: Int? = nil, line: Character? = nil) {
        self.prefix = prefix
        self.year = year
        self.dayOfYear = dayOfYear
        self.plant = plant
        self.hour = hour
        self.minute = minute
        self.line = line
    }

    /// Reads either format, with or without the spaces and the colon.
    public init?(_ raw: String) {
        let text = raw.uppercased()
            .replacingOccurrences(of: " ", with: "")
            .replacingOccurrences(of: ":", with: "")

        // 2012 on: [L] YY DDD [PP] [HHMM] [line]. The digit run after the
        // letter is 5, 7, 9 or 11 long; its length says which parts exist.
        if let regex = try? NSRegularExpression(pattern: #"^([A-Z])?(\d{5}|\d{7}|\d{9}|\d{11})([A-Z])?$"#),
           let match = regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)),
           let digitsRange = Range(match.range(at: 2), in: text) {
            let digits = String(text[digitsRange])
            let yy = Int(digits.prefix(2)) ?? 0
            let ddd = Int(digits.dropFirst(2).prefix(3)) ?? 0
            var rest = String(digits.dropFirst(5))
            var plant: Int?
            var hour: Int?
            var minute: Int?
            if rest.count == 2 || rest.count == 6 {
                plant = Int(rest.prefix(2))
                rest = String(rest.dropFirst(2))
            }
            if rest.count == 4, let h = Int(rest.prefix(2)), let m = Int(rest.suffix(2)),
               (0...23).contains(h), (0...59).contains(m) {
                hour = h
                minute = m
            }
            // A day that does not exist is not a modern code; it may still
            // be the older order below, where the day comes first.
            if let made = Self.checked(year: 2000 + yy, day: ddd) {
                self.init(
                    prefix: Range(match.range(at: 1), in: text).flatMap { text[$0].first },
                    year: made.year, dayOfYear: made.day, plant: plant, hour: hour, minute: minute,
                    line: Range(match.range(at: 3), in: text).flatMap { text[$0].first })
                return
            }
        }

        // 2007-2011: line DDD YY HHMM.
        if let regex = try? NSRegularExpression(pattern: #"^([A-Z])(\d{3})(\d{2})(\d{4})$"#),
           let match = regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)),
           let lineRange = Range(match.range(at: 1), in: text),
           let dddRange = Range(match.range(at: 2), in: text),
           let yyRange = Range(match.range(at: 3), in: text),
           let timeRange = Range(match.range(at: 4), in: text) {
            let ddd = Int(text[dddRange]) ?? 0
            let yy = Int(text[yyRange]) ?? 0
            let time = String(text[timeRange])
            guard (7...11).contains(yy), let made = Self.checked(year: 2000 + yy, day: ddd) else { return nil }
            let h = Int(time.prefix(2)) ?? -1
            let m = Int(time.suffix(2)) ?? -1
            let valid = (0...23).contains(h) && (0...59).contains(m)
            self.init(
                prefix: nil, year: made.year, dayOfYear: made.day, plant: nil,
                hour: valid ? h : nil, minute: valid ? m : nil,
                line: text[lineRange].first)
            return
        }

        return nil
    }

    private static func checked(year: Int, day: Int) -> (year: Int, day: Int)? {
        guard (1...366).contains(day) else { return nil }
        if day == 366, !isLeap(year) { return nil }
        return (year, day)
    }

    /// The bottling date.
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
        if let plant { out += String(format: " %02d", plant) }
        if let hour, let minute { out += String(format: " %02d:%02d", hour, minute) }
        if let line { out += " " + String(line) }
        return out
    }

    /// "Bottled 6 April 2018 at 10:50, line K."
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
