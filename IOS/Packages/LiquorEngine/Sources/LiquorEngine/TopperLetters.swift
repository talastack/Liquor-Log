import Foundation

/// The letters on Blanton's cork toppers, and which of them a shelf has.
///
/// From Blanton's own FAQ (https://www.blantonsbourbon.com/pages/faq, read
/// 15 September 2026): since 1999 the stoppers have come as a collector's
/// set of eight, a horse and jockey in the eight stages of a race, each
/// marked with a single letter that spells BLANTONS when the set is
/// complete. There are two different N's -- the second is followed by a
/// subtle colon, "N:" -- and no apostrophe stopper. All eight are made in
/// equal numbers and placed on bottles at random, so no letter is rarer
/// than another; a shelf's set is a fact about the shelf, not a score.
///
/// It is also what bourbondumpdate.com records beside the dump date, which
/// is why the letter is stored per bottle.
public enum TopperLetters: Sendable {

    /// The eight stoppers, in the order they spell the name. The second N
    /// is its own stopper, written "N:" as Blanton's marks it.
    public static let stoppers: [String] = ["B", "L", "A", "N", "T", "O", "N:", "S"]

    /// The word the set spells, for display.
    public static let word = "BLANTONS"

    /// A stored letter, normalised: uppercased, "n2" or "n:" for the second
    /// N, anything that is not one of the eight rejected. The apostrophe
    /// people sometimes type is not a stopper and comes back nil.
    public static func normalise(_ raw: String) -> String? {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        switch trimmed {
        case "B", "L", "A", "T", "O", "S": return trimmed
        case "N", "N1": return "N"
        case "N:", "N2", "N;", "N.": return "N:"
        default: return nil
        }
    }

    public struct Progress: Hashable, Sendable {
        /// Stoppers owned, with how many of each.
        public let owned: [String: Int]
        public let missing: [String]
        public var isComplete: Bool { missing.isEmpty }
        public var ownedCount: Int { stoppers.count - missing.count }

        /// The word with the missing stoppers blanked, for a single line:
        /// "B L A _ T O N: _".
        public var wordLine: String {
            stoppers.map { owned[$0] != nil ? $0 : "_" }.joined(separator: " ")
        }
    }

    public static func progress(_ letters: [String]) -> Progress {
        var owned: [String: Int] = [:]
        for raw in letters {
            if let stopper = normalise(raw) { owned[stopper, default: 0] += 1 }
        }
        let missing = stoppers.filter { owned[$0] == nil }
        return Progress(owned: owned, missing: missing)
    }
}
