import Foundation

/// Dating an old bottle from what is printed on it.
///
/// A "dusty" -- a bottle that sat on a shelf for decades -- usually has no
/// date on it, but it has things that only existed for certain years: a
/// tax strip, the agency named on the strip, a "4/5 QUART" size, a metric
/// size, a UPC. Each is a window; the bottle's date is where the windows
/// overlap. This is the collectors' method (whiskeyid.com,
/// whiskeyprof.com), with the federal dates behind it:
///
/// - Strip stamps were required on distilled spirits until the tax stamp
///   requirement was repealed effective 1 July 1985 (Deficit Reduction Act
///   of 1984). A bottle with any strip is from before that.
/// - The Bureau of Alcohol, Tobacco and Firearms took over from the IRS's
///   Alcohol and Tobacco Tax Division on 1 July 1972; strips printed
///   "ATF" are later than that and strips printed "IRS" or "Internal
///   Revenue" earlier -- collectors put the changeover on strips at 1977,
///   when the ATF wording reached bottles.
/// - Metric standards of fill (750 ml, 1 L, 1.75 L) became mandatory for
///   distilled spirits on 1 January 1980, after a transition from 1976
///   (27 CFR 5.47a). "4/5 QUART", "PINT" and "1/2 PINT" are before 1980;
///   "750 ML" is 1976 or later.
/// - Green bottled-in-bond strips with the seasons of barrelling and
///   bottling printed on them were discontinued 1 December 1982.
/// - "Series 111" or "112" near the eagle: 1945 to 1972. Volume marked on
///   the ends of the strip: before 1973.
///
/// Nothing here is a date; it is a window, and two clues that cannot both
/// be true are reported as a conflict rather than averaged.
public enum DustyClues: Sendable {

    public struct Clue: Hashable, Sendable, Identifiable, CaseIterable {
        public let id: String
        public let text: String
        /// The window this clue puts the bottle in. Nil is open on that side.
        public let from: Int?
        public let to: Int?
        public let why: String

        public static let allCases: [Clue] = [
            Clue(id: "strip", text: "A paper strip over the cap", from: nil, to: 1985,
                 why: "Strip stamps were required until 1 July 1985."),
            Clue(id: "irs", text: "The strip says IRS or Internal Revenue", from: nil, to: 1976,
                 why: "The IRS wording was replaced by ATF's on strips from 1977."),
            Clue(id: "atf", text: "The strip says ATF", from: 1977, to: 1985,
                 why: "ATF wording on strips from 1977; strips ended 1 July 1985."),
            Clue(id: "series", text: "\"Series 111\" or \"112\" near the eagle", from: 1945, to: 1972,
                 why: "Printed on strips from 1945 to 1972."),
            Clue(id: "ends", text: "A volume marked on the ends of the strip", from: nil, to: 1972,
                 why: "Volume markings came off the strip ends in 1973."),
            Clue(id: "bib-green", text: "A green bottled-in-bond strip with two seasons on it", from: nil, to: 1982,
                 why: "Discontinued 1 December 1982."),
            Clue(id: "quart", text: "\"4/5 QUART\", \"PINT\" or \"1/2 PINT\" on the glass", from: nil, to: 1979,
                 why: "Metric sizes became mandatory 1 January 1980 (27 CFR 5.47a)."),
            Clue(id: "metric", text: "\"750 ML\", \"1 LITER\" or \"1.75 L\" on the glass", from: 1976, to: nil,
                 why: "Metric sizes were allowed from 1976 and required from 1980."),
            Clue(id: "no-strip", text: "No strip, and the cap has never been opened", from: 1985, to: nil,
                 why: "Strips ended 1 July 1985."),
        ]
    }

    public struct Window: Hashable, Sendable {
        public let from: Int?
        public let to: Int?
        /// Two chosen clues that cannot both be true.
        public let conflict: (Clue, Clue)?

        public static func == (a: Window, b: Window) -> Bool {
            a.from == b.from && a.to == b.to && a.conflict?.0 == b.conflict?.0 && a.conflict?.1 == b.conflict?.1
        }
        public func hash(into hasher: inout Hasher) {
            hasher.combine(from); hasher.combine(to)
        }

        /// "Between 1977 and 1979", "1985 or later", "Before 1973".
        public var text: String {
            if let conflict {
                return "Those cannot both be true: \"\(conflict.0.text)\" and \"\(conflict.1.text)\"."
            }
            switch (from, to) {
            case (nil, nil): return "Pick what the bottle shows."
            case (let f?, nil): return "\(f) or later."
            case (nil, let t?): return "Before \(t + 1)."
            case (let f?, let t?): return f == t ? "\(f)." : "Between \(f) and \(t)."
            }
        }
    }

    /// The overlap of the chosen clues' windows.
    public static func window(for chosen: [Clue]) -> Window {
        var from: Int?
        var to: Int?
        var fromClue: Clue?
        var toClue: Clue?
        for clue in chosen {
            if let f = clue.from, f > (from ?? Int.min) { from = f; fromClue = clue }
            if let t = clue.to, t < (to ?? Int.max) { to = t; toClue = clue }
            if let f = from, let t = to, f > t, let a = fromClue, let b = toClue {
                return Window(from: nil, to: nil, conflict: (a, b))
            }
        }
        return Window(from: from, to: to, conflict: nil)
    }
}
