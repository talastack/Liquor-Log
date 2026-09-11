import Foundation

/// The letters on Blanton's cork toppers, and which of them a shelf has.
///
/// Each stopper carries a horse and jockey and one letter of B-L-A-N-T-O-N-'-S,
/// eight letters and an apostrophe, and collecting the set is a thing people
/// do. It is also what bourbondumpdate.com -- the one registry the 10
/// September brief found the community had welcomed -- records alongside the
/// dump date and the state the bottle was found in.
///
/// The set is a fact about Blanton's, so it lives here rather than in a
/// column constraint: another brand's set would be another table entry, not
/// a migration.
public enum TopperLetters: Sendable {

    /// The set, in order, apostrophe included. Two N's on purpose: the word
    /// has two, and the stoppers do too.
    public static let letters: [Character] = ["B", "L", "A", "N", "T", "O", "N", "'", "S"]

    /// The distinct letters somebody can own: B L A N T O S and the
    /// apostrophe. N appears twice in the word and once here.
    public static let distinct: [Character] = ["B", "L", "A", "N", "T", "O", "'", "S"]

    /// A stored letter, normalised: uppercased, the typographic apostrophe
    /// folded to the plain one, anything not in the set rejected.
    public static func normalise(_ raw: String) -> Character? {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        guard trimmed.count == 1, let letter = trimmed.first else { return nil }
        let folded: Character = (letter == "\u{2019}" || letter == "`") ? "'" : letter
        return distinct.contains(folded) ? folded : nil
    }

    public struct Progress: Hashable, Sendable {
        /// Letters owned, in set order, with how many of each.
        public let owned: [Character: Int]
        public let missing: [Character]
        public var isComplete: Bool { missing.isEmpty }
        public var ownedCount: Int { distinct.count - missing.count }

        /// The word with the missing letters blanked, for a single line:
        /// "B L A _ T O _ ' S".
        public var wordLine: String {
            letters.map { owned[$0] != nil ? String($0) : "_" }.joined(separator: " ")
        }
    }

    public static func progress(_ letters: [String]) -> Progress {
        var owned: [Character: Int] = [:]
        for raw in letters {
            if let letter = normalise(raw) { owned[letter, default: 0] += 1 }
        }
        let missing = distinct.filter { owned[$0] == nil }
        return Progress(owned: owned, missing: missing)
    }
}
