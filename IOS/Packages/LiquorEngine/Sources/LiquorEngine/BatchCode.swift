import Foundation

/// Heaven Hill barrel-proof batch codes: `B523`, `A125`, `C923`.
///
/// Elijah Craig Barrel Proof and Larceny Barrel Proof share the scheme, and it
/// is stated on Heaven Hill's own material:
///
/// ```
/// B 5 23
/// | |  +-- year, two digits           2023
/// | +----- month bottled, one digit   5 = May
/// +------- release of the year        A = first, B = second, C = third
/// ```
///
/// Three releases a year — January, May, September — so the letter and the
/// month agree on a real code, and disagreement is the tell for a misread.
///
/// The research found no interactive decoder for these anywhere, and the one
/// static guide (ModernThirst) stopped at A119 in 2019. The knowledge lives in
/// blog posts; this makes it a function.
///
/// `nil` for anything that does not fit, never a partial reading. A month of
/// 13 is a misread, not a thirteenth month.
public struct BatchCode: Hashable, Sendable, CustomStringConvertible {

    public enum Release: Character, Sendable, CaseIterable {
        case first = "A"
        case second = "B"
        case third = "C"

        public var ordinal: String {
            switch self {
            case .first: return "First"
            case .second: return "Second"
            case .third: return "Third"
            }
        }

        /// The month each release has historically shipped in.
        public var usualMonth: Int {
            switch self {
            case .first: return 1
            case .second: return 5
            case .third: return 9
            }
        }
    }

    public let release: Release
    /// 1–12.
    public let month: Int
    /// Four digits.
    public let year: Int

    public init(release: Release, month: Int, year: Int) {
        self.release = release
        self.month = month
        self.year = year
    }

    /// Parses `B523`, `b523`, `B 5 23`, or the older two-digit-month form
    /// `A1023`. Nil for anything else.
    public init?(_ raw: String) {
        let code = raw.uppercased().filter { $0.isLetter || $0.isNumber }
        guard let first = code.first, let release = Release(rawValue: first) else {
            return nil
        }
        let digits = code.dropFirst()
        // Three digits is month + year; four is a two-digit month + year.
        guard digits.count == 3 || digits.count == 4,
              digits.allSatisfy(\.isNumber),
              let year = Int(digits.suffix(2)),
              let month = Int(digits.dropLast(2)),
              (1...12).contains(month)
        else { return nil }

        self.release = release
        self.month = month
        // The scheme began in the 2010s and a two-digit year cannot mean
        // anything earlier, so 2000 is the only sensible century.
        self.year = 2000 + year
    }

    public var description: String {
        String(release.rawValue) + "\(month)" + String(format: "%02d", year % 100)
    }

    public var code: String { description }

    /// "Second release of 2023, bottled in May".
    public var summary: String {
        "\(release.ordinal) release of \(year), bottled in \(Self.monthName(month))"
    }

    /// True when the letter and the month agree with the usual schedule. A
    /// code that says "first release, bottled in September" is far more likely
    /// a misread than a real bottle, and a screen should say so gently.
    public var followsTheUsualSchedule: Bool {
        month == release.usualMonth
    }

    public static func monthName(_ month: Int) -> String {
        let names = [
            "January", "February", "March", "April", "May", "June",
            "July", "August", "September", "October", "November", "December",
        ]
        return (1...12).contains(month) ? names[month - 1] : "?"
    }
}
