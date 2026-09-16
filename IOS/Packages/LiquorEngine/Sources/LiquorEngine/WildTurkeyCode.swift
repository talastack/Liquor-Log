import Foundation

/// The bottling code on a Wild Turkey, read as a date.
///
/// Wild Turkey does not publish its scheme. The formats here are the ones
/// Rare Bird 101 -- the reference collectors use for the brand -- has
/// documented from bottles in hand (rarebird101.com/bottle-codes), with
/// its own worked examples as the tests. Three formats are readable
/// without guessing:
///
/// - **2013–2023:** `LL/YMDDHHMM` -- year letter (A is 2012, so D is
///   2015), month letter (A is January), day, 24-hour time.
///   `LL/DF021000` is 10:00 on 2 June 2015. Rare Bird lists 2022–2024
///   bottles with the same shape and a printed date on a second line.
/// - **2024 on:** `LA YMDD?HHMM` -- the same letters, then one letter
///   whose meaning is not documented, then the time. `LA MI26E0719` is
///   07:19 on 26 September 2024.
/// - **2006–2014:** `L Y DDD ?? HHMM` -- a single year digit, the day of
///   the year, letters that are not documented, the time. `L9132FH 1253`
///   is 12:53 on 12 May 2009; `L6229NU7A` is 17 August 2006. A single
///   digit is a decade guess by itself; Rare Bird dates this format 2006
///   to 2014, which pins it.
///
/// The 1990s formats (`L-15-220`) are read too. The unhyphenated 1992
/// form (`L12358`) is six characters that a Buffalo Trace laser code also
/// uses, so it is left to that decoder rather than misread here.
public struct WildTurkeyCode: Hashable, Sendable {
    public let year: Int
    public let month: Int
    public let day: Int
    public let hour: Int?
    public let minute: Int?
    /// Which documented format it was read as, for the screen.
    public let format: Format

    public enum Format: String, Sendable {
        case lettered2013      // LL/YMDD
        case lettered2024      // LA YMDD?
        case dayOfYear2007     // L Y DDD
        case hyphenated1990s   // L-1Y-DDD
    }

    private static let base = 2012   // A

    public init?(_ raw: String) {
        let text = raw.uppercased().replacingOccurrences(of: " ", with: "")
        let calendar = Self.utc

        // LL/YMDDHHMM, 2013-2023; the slash is optional.
        if let m = Self.match(#"^LL/?([B-L])([A-L])([0-9]{2})([0-9]{4})?$"#, text) {
            guard let date = Self.assemble(
                year: Self.base + Self.index(m[1]), month: Self.index(m[2]) + 1,
                day: Int(m[3])!, time: m[4], calendar: calendar) else { return nil }
            self.init(date, format: .lettered2013)
            return
        }
        // LA YMDD ? HHMM, 2024 on.
        if let m = Self.match(#"^LA([M-Z])([A-L])([0-9]{2})[A-Z]?([0-9]{4})?$"#, text) {
            guard let date = Self.assemble(
                year: Self.base + Self.index(m[1]), month: Self.index(m[2]) + 1,
                day: Int(m[3])!, time: m[4], calendar: calendar) else { return nil }
            self.init(date, format: .lettered2024)
            return
        }
        // L Y DDD ?? HHMM, 2006-2014: a single year digit, day of year,
        // one to three letters, an optional time, and on the 2006 bottles
        // a couple more characters after. A 5 is refused: the format is
        // documented for 2006 to 2014, so no year ends in one.
        if let m = Self.match(#"^L([0-9])([0-9]{3})[A-Z]{1,3}([0-9]{4})?[A-Z0-9]{0,2}$"#, text) {
            let digit = Int(m[1])!
            guard digit != 5 else { return nil }
            let year = digit >= 6 ? 2000 + digit : 2010 + digit
            guard let date = Self.dayOfYear(Int(m[2])!, year: year, time: m[3], calendar: calendar)
            else { return nil }
            self.init(date, format: .dayOfYear2007)
            return
        }
        // L-1Y-DDD, 1992-1998: the 1 is fixed, Y the last digit of the year.
        if let m = Self.match(#"^L-1([0-9])-([0-9]{3})$"#, text) {
            let year = 1990 + Int(m[1])!
            guard let date = Self.dayOfYear(Int(m[2])!, year: year, time: nil, calendar: calendar)
            else { return nil }
            self.init(date, format: .hyphenated1990s)
            return
        }
        return nil
    }

    private init(_ parts: (year: Int, month: Int, day: Int, hour: Int?, minute: Int?), format: Format) {
        self.year = parts.year
        self.month = parts.month
        self.day = parts.day
        self.hour = parts.hour
        self.minute = parts.minute
        self.format = format
    }

    public func date(calendar: Calendar = .current) -> Date? {
        calendar.date(from: DateComponents(year: year, month: month, day: day, hour: hour ?? 12, minute: minute ?? 0))
    }

    /// "Bottled 2 June 2015 at 10:00."
    public var summary: String {
        var text = "Bottled \(day) \(Self.monthNames[month - 1]) \(year)"
        if let hour, let minute { text += String(format: " at %02d:%02d", hour, minute) }
        return text + "."
    }

    static let monthNames = ["January", "February", "March", "April", "May", "June", "July",
                             "August", "September", "October", "November", "December"]

    // MARK: - Pieces

    private static var utc: Calendar {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(identifier: "UTC")!
        return c
    }

    private static func index(_ letter: String) -> Int {
        Int(letter.unicodeScalars.first!.value) - Int(("A" as Unicode.Scalar).value)
    }

    /// Patterns use `[0-9]`, never `\d`: ICU's `\d` matches every Unicode
    /// digit and `Int()` reads only ASCII, so a fullwidth digit typed from
    /// a Japanese keyboard would match and then trap on the unwrap.
    private static func match(_ pattern: String, _ text: String) -> [String]? {
        guard let regex = try? NSRegularExpression(pattern: pattern),
              let m = regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text))
        else { return nil }
        return (0..<m.numberOfRanges).map { i in
            guard let r = Range(m.range(at: i), in: text) else { return "" }
            return String(text[r])
        }
    }

    private static func time(_ raw: String) -> (Int, Int)?? {
        guard !raw.isEmpty else { return .some(nil) }
        let hour = Int(raw.prefix(2))!, minute = Int(raw.suffix(2))!
        guard hour < 24, minute < 60 else { return nil }
        return .some((hour, minute))
    }

    /// A real calendar date or nothing: 31 June is refused, not rounded.
    private static func assemble(
        year: Int, month: Int, day: Int, time: String, calendar: Calendar
    ) -> (year: Int, month: Int, day: Int, hour: Int?, minute: Int?)? {
        guard let clock = Self.time(time) else { return nil }
        let components = DateComponents(year: year, month: month, day: day)
        guard let date = calendar.date(from: components),
              calendar.component(.day, from: date) == day,
              calendar.component(.month, from: date) == month else { return nil }
        return (year, month, day, clock?.0, clock?.1)
    }

    private static func dayOfYear(
        _ ordinal: Int, year: Int, time: String?, calendar: Calendar
    ) -> (year: Int, month: Int, day: Int, hour: Int?, minute: Int?)? {
        guard let clock = Self.time(time ?? "") else { return nil }
        guard ordinal >= 1, let first = calendar.date(from: DateComponents(year: year, month: 1, day: 1)),
              let date = calendar.date(byAdding: .day, value: ordinal - 1, to: first),
              calendar.component(.year, from: date) == year else { return nil }
        return (year, calendar.component(.month, from: date), calendar.component(.day, from: date),
                clock?.0, clock?.1)
    }
}
