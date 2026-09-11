import Foundation

/// Plain English in, one of the app's own actions or questions out.
///
/// "log a pour of weller 12", "1 oz of the blanton's", "add a bottle of
/// eagle rare, paid 40 at total wine", "rate the stagg an 8", "what's
/// open", "how many wellers do I have". No model: a small grammar of the
/// verbs the app already has, plus the same bottle search the shelf check
/// uses to find what the sentence is about. It runs on every phone, offline,
/// for nothing, and it is testable on Linux.
///
/// Where the phone has an on-device language model, the app can use it to
/// turn looser phrasing into these same commands and to write the answer as
/// prose. That layer is optional and additive; this one is the floor, and
/// it is also the safety: a command is always shown back before anything
/// is written, because "log a pour" against the wrong bottle is a mistake
/// somebody has to find and undo.
///
/// Nothing here is called AI anywhere a person can see. The research is
/// blunt about marketed AI in this category; this is a text box that
/// understands you.
public enum Ask: Sendable {

    /// What the sentence is about, as the search found it.
    public struct Subject: Hashable, Sendable {
        /// The words the person used for the bottle, after the verb and the
        /// numbers were taken out.
        public let text: String
        /// Catalogue or custom products those words matched, best first.
        public let matches: [SearchHit]
        public var best: ProductIdentity? { matches.first?.product }
        public var isAmbiguous: Bool {
            guard matches.count >= 2 else { return false }
            return matches[0].score - matches[1].score < 0.1
        }
    }

    public enum Command: Hashable, Sendable {
        case pour(Subject, milliliters: Double?)
        case open(Subject)
        case finish(Subject)
        case setLevel(Subject, percent: Double)
        case rate(Subject, rating: Int)
        case addBottle(Subject, paidCents: Int?, store: String?)
        case wishlist(Subject, ceilingCents: Int?)
        case note(Subject, body: String)
    }

    public enum Question: Hashable, Sendable {
        case whatIsOpen
        case howMany(Subject?)
        case doIHave(Subject)
        case lastPoured(Subject)
        case whatDidIThink(Subject)
        case whatDidIPay(Subject)
        case whereIs(Subject)
        case whatIsOnMyWishlist
        case nearlyGone
    }

    public enum Understanding: Hashable, Sendable {
        case command(Command)
        case question(Question)
        /// The sentence was not one the grammar knows. The text is returned
        /// so a model, when there is one, can try.
        case unknown(String)
    }

    // MARK: - Parsing

    public static func understand(_ raw: String, catalog: [SearchCandidate]) -> Understanding {
        let text = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return .unknown(text) }
        let lower = text.lowercased()

        if let question = question(lower, catalog: catalog) {
            return .question(question)
        }
        if let command = command(lower, original: text, catalog: catalog) {
            return .command(command)
        }
        return .unknown(text)
    }

    static func question(_ s: String, catalog: [SearchCandidate]) -> Question? {
        if matches(s, ["what's open", "whats open", "what is open", "which bottles are open", "open bottles"]) {
            return .whatIsOpen
        }
        // A question about the list, not a request to put something on it:
        // "what's on my wishlist", "show my wishlist". ("list" alone would
        // match inside "wishlist" and turn every add into a question.)
        if matches(s, ["wishlist", "wish list"]),
           s.hasPrefix("what") || s.hasPrefix("show") || s.hasPrefix("list ") {
            return .whatIsOnMyWishlist
        }
        if matches(s, ["nearly gone", "almost empty", "running low", "almost gone", "nearly empty"]) {
            return .nearlyGone
        }
        if let rest = after(s, ["what did i pay for", "how much did i pay for", "what did i spend on"]) {
            return .whatDidIPay(subject(strip(rest, ["the", "my", "a"]), catalog: catalog))
        }
        if let rest = after(s, ["how many", "how much"]) {
            let stripped = strip(rest, ["bottles", "bottle", "of", "do i have", "do i own", "have i got", "are there", "have i"])
            if stripped.isEmpty { return .howMany(nil) }
            return .howMany(subject(stripped, catalog: catalog))
        }
        if let rest = after(s, ["do i have", "do i own", "have i got", "do i already have"]) {
            return .doIHave(subject(strip(rest, ["any", "a", "an", "bottle of", "some"]), catalog: catalog))
        }
        if let rest = after(s, ["when did i last pour", "when did i last have", "last poured", "when did i last drink"]) {
            return .lastPoured(subject(strip(rest, ["the", "from", "my", "a"]), catalog: catalog))
        }
        if let rest = after(s, ["what did i think of", "what did i say about", "how did i rate", "my rating for", "what did i rate"]) {
            return .whatDidIThink(subject(strip(rest, ["the", "my"]), catalog: catalog))
        }
        if let rest = after(s, ["where is", "where's", "where did i put", "where do i keep"]) {
            return .whereIs(subject(strip(rest, ["the", "my"]), catalog: catalog))
        }
        return nil
    }

    static func command(_ s: String, original: String, catalog: [SearchCandidate]) -> Command? {
        // "1 oz of the blanton's", "30 ml of stagg": the quantity leads.
        if let leading = capture(in: s, pattern: #"^\d+(?:\.\d+)?\s*(?:oz|ounces?|ml)\s+(?:of\s+)?(.+)$"#) {
            let words = strip(leading, ["the", "my", "a"])
            return .pour(subject(words, catalog: catalog), milliliters: milliliters(in: s))
        }

        // "note on X: body" -- the body is kept as typed.
        if let rest = after(s, ["note on", "note about", "add a note to", "remember that"]) {
            let parts = rest.split(separator: ":", maxSplits: 1).map { $0.trimmingCharacters(in: .whitespaces) }
            if parts.count == 2 {
                let body: String
                if let colon = original.range(of: ":") {
                    body = String(original[colon.upperBound...]).trimmingCharacters(in: .whitespaces)
                } else {
                    body = parts[1]
                }
                return .note(subject(strip(parts[0], ["the", "my"]), catalog: catalog), body: body)
            }
        }

        if let rest = after(s, ["log a pour of", "log a pour from", "pour of", "poured", "pour", "log", "had a pour of", "had a glass of", "drank", "had some"]) {
            let words = strip(removeQuantities(rest), ["the", "my", "a", "of", "from", "some", "glass", "dram", "pour"])
            guard !words.isEmpty else { return nil }
            return .pour(subject(words, catalog: catalog), milliliters: milliliters(in: rest))
        }

        if let rest = after(s, ["open the", "opened the", "open my", "opened my", "open a", "opened a", "open", "opened", "crack open", "cracked open"]) {
            let words = strip(rest, ["the", "my", "a", "bottle of"])
            guard !words.isEmpty else { return nil }
            return .open(subject(words, catalog: catalog))
        }

        if let rest = after(s, ["finished the", "finished my", "killed the", "killed my", "finish the", "finish", "finished", "killed", "kill"]) {
            let words = strip(rest, ["the", "my", "a", "bottle of", "off"])
            guard !words.isEmpty else { return nil }
            return .finish(subject(words, catalog: catalog))
        }

        if let rest = after(s, ["set the", "set my", "set"]), let percent = percent(in: rest),
           matches(rest, ["level", "fill", "left", "full", "%", "percent", "half", "quarter", "third", "empty"]) {
            let words = strip(removeQuantities(rest), ["the", "my", "level", "fill", "to", "at", "left", "full", "of", "is", "about", "percent", "half", "a third", "one third", "third", "quarter", "empty"])
            guard !words.isEmpty else { return nil }
            return .setLevel(subject(words, catalog: catalog), percent: percent)
        }

        if let rest = after(s, ["rate the", "rate my", "rate", "give the", "give"]), let rating = rating(in: rest) {
            let withoutRating = removeLastSmallNumber(removeQuantities(rest))
            let words = strip(withoutRating, ["the", "my", "a", "an", "out of", "stars", "star", "points", "rating", "of", "as"])
            guard !words.isEmpty else { return nil }
            return .rate(subject(words, catalog: catalog), rating: rating)
        }

        if let rest = after(s, ["add a bottle of", "add bottle of", "add a", "add", "bought a bottle of", "bought a", "bought", "got a", "picked up a", "picked up"]) {
            if matches(rest, ["wishlist", "wish list"]) {
                let words = strip(removeQuantities(rest), ["to my wishlist", "to the wishlist", "to wishlist", "on my wishlist", "wishlist", "wish list", "to my", "the", "my", "a", "bottle of", "under", "up to", "for", "at"])
                guard !words.isEmpty else { return nil }
                return .wishlist(subject(words, catalog: catalog), ceilingCents: money(in: rest))
            }
            let words = strip(
                removeStore(removeQuantities(rest)),
                ["the", "my", "a", "bottle of", "bottle", "paid", "for", "at", "from", "i", "it"])
            guard !words.isEmpty else { return nil }
            return .addBottle(subject(words, catalog: catalog), paidCents: money(in: rest), store: storeName(in: original))
        }

        if let rest = after(s, ["wishlist the", "wishlist", "want a", "want the", "want", "i'm looking for", "looking for", "put"]) {
            let words = strip(removeQuantities(rest), ["on my wishlist", "on the wishlist", "on wishlist", "to my wishlist", "wishlist", "the", "my", "a", "bottle of", "some", "for", "up to", "under"])
            guard !words.isEmpty else { return nil }
            return .wishlist(subject(words, catalog: catalog), ceilingCents: money(in: rest))
        }

        return nil
    }

    // MARK: - Pieces

    static func subject(_ words: String, catalog: [SearchCandidate]) -> Subject {
        let cleaned = words.trimmingCharacters(in: .whitespacesAndNewlines)
            .trimmingCharacters(in: CharacterSet(charactersIn: ",.!?"))
        var hits = BottleSearch.search(query: cleaned, in: catalog, limit: 5)
        // "how many wellers": a plural the search does not know. Once, on
        // the words that end in s, before giving up.
        if hits.isEmpty {
            let singular = cleaned.split(separator: " ")
                .map { $0.count > 3 && $0.hasSuffix("s") ? String($0.dropLast()) : String($0) }
                .joined(separator: " ")
            if singular != cleaned {
                hits = BottleSearch.search(query: singular, in: catalog, limit: 5)
            }
        }
        return Subject(text: cleaned, matches: hits)
    }

    static func matches(_ s: String, _ phrases: [String]) -> Bool {
        phrases.contains { s.contains($0) }
    }

    /// The text after the first of `prefixes` that starts the sentence, once
    /// a leading "please" / "can you" / "hey" is dropped.
    static func after(_ s: String, _ prefixes: [String]) -> String? {
        var text = s
        for lead in ["please ", "can you ", "could you ", "hey ", "ok ", "okay ", "i "] where text.hasPrefix(lead) {
            text = String(text.dropFirst(lead.count))
        }
        // Longest prefix first, so "log a pour of" wins over "log".
        for prefix in prefixes.sorted(by: { $0.count > $1.count }) {
            if text.hasPrefix(prefix + " ") {
                return String(text.dropFirst(prefix.count)).trimmingCharacters(in: .whitespaces)
            }
            if text == prefix { return "" }
        }
        return nil
    }

    /// Removes whole-word filler. "the weller 12" -> "weller 12".
    static func strip(_ s: String, _ fillers: [String]) -> String {
        var words = s.split(separator: " ").map(String.init)
        for filler in fillers.sorted(by: { $0.count > $1.count }) {
            let parts = filler.split(separator: " ").map(String.init)
            var index = 0
            while index + parts.count <= words.count {
                if Array(words[index..<index + parts.count]) == parts {
                    words.removeSubrange(index..<index + parts.count)
                } else {
                    index += 1
                }
            }
        }
        return words.joined(separator: " ").trimmingCharacters(in: .whitespaces)
    }

    /// A number WITH a unit, or a dollar amount, or "paid N". A bare number is
    /// left alone: "weller 12" and "eagle rare 10" are names, and a parser
    /// that ate the 12 would log a pour of the wrong Weller.
    static let quantityPattern =
        #"(?:\$\s*\d+(?:\.\d+)?|\d+(?:\.\d+)?\s*(?:oz|ounces?|ml|%|percent|dollars?|bucks|/\s*10|out of 10)\b|paid\s+\$?\d+(?:\.\d+)?)"#

    static func removeQuantities(_ s: String) -> String {
        guard let regex = try? NSRegularExpression(pattern: quantityPattern) else { return s }
        let range = NSRange(s.startIndex..., in: s)
        let out = regex.stringByReplacingMatches(in: s, range: range, withTemplate: " ")
        return out.replacingOccurrences(of: "  ", with: " ").trimmingCharacters(in: .whitespaces)
    }

    static func capture(in s: String, pattern: String) -> String? {
        guard let regex = try? NSRegularExpression(pattern: pattern),
              let match = regex.firstMatch(in: s, range: NSRange(s.startIndex..., in: s)),
              let range = Range(match.range(at: 1), in: s)
        else { return nil }
        return String(s[range])
    }

    static func number(in s: String, unitPattern: String) -> Double? {
        capture(in: s, pattern: #"(\d+(?:\.\d+)?)\s*"# + unitPattern).flatMap(Double.init)
    }

    static func milliliters(in s: String) -> Double? {
        if let oz = number(in: s, unitPattern: #"(?:oz|ounces?)\b"#) {
            return PourSize(usFluidOunces: oz).milliliters
        }
        if let ml = number(in: s, unitPattern: #"ml\b"#) { return ml }
        return nil
    }

    static func percent(in s: String) -> Double? {
        if let value = number(in: s, unitPattern: #"(?:%|percent)"#) { return value }
        if s.contains("half") { return 50 }
        if s.contains("a third") || s.contains("one third") { return 33 }
        if s.contains("quarter") { return 25 }
        if s.contains("empty") { return 0 }
        if s.contains("full") { return 100 }
        return nil
    }

    /// "the stagg an 8" -> "the stagg an". Only the LAST bare 1-10, which is
    /// the rating; the 10 in "eagle rare 10 an 8" stays where it is.
    static func removeLastSmallNumber(_ s: String) -> String {
        guard let regex = try? NSRegularExpression(pattern: #"\b(10|[1-9])\b"#) else { return s }
        let range = NSRange(s.startIndex..., in: s)
        guard let last = regex.matches(in: s, range: range).last,
              let r = Range(last.range, in: s) else { return s }
        var out = s
        out.removeSubrange(r)
        return out.replacingOccurrences(of: "  ", with: " ").trimmingCharacters(in: .whitespaces)
    }

    static func rating(in s: String) -> Int? {
        if let out = number(in: s, unitPattern: #"(?:/\s*10|out of 10)"#) { return Int(out) }
        guard let regex = try? NSRegularExpression(pattern: #"\b(10|[1-9])\b"#) else { return nil }
        let range = NSRange(s.startIndex..., in: s)
        let values = regex.matches(in: s, range: range).compactMap { match -> Int? in
            guard let r = Range(match.range(at: 1), in: s) else { return nil }
            return Int(s[r])
        }
        return values.last
    }

    /// "$40", "40 dollars", "paid 40". Cents.
    static func money(in s: String) -> Int? {
        for pattern in [
            #"\$\s*(\d+(?:\.\d{1,2})?)"#,
            #"(\d+(?:\.\d{1,2})?)\s*(?:dollars?|bucks)\b"#,
            #"paid\s+(\d+(?:\.\d{1,2})?)"#,
        ] {
            if let value = capture(in: s, pattern: pattern).flatMap(Double.init) {
                return Int((value * 100).rounded())
            }
        }
        return nil
    }

    /// "at Total Wine", "from the ABC store" -- the words after at/from, in
    /// the original casing, up to a comma or a money word.
    static func storeName(in original: String) -> String? {
        let lower = original.lowercased()
        for marker in [" at ", " from "] {
            guard let range = lower.range(of: marker) else { continue }
            let tail = String(original[range.upperBound...])
            let store = tail
                .split(whereSeparator: { $0 == "," || $0 == "." })
                .first
                .map { String($0).trimmingCharacters(in: .whitespaces) } ?? ""
            let cleaned = store
                .replacingOccurrences(of: #"(?i)^the\s+"#, with: "", options: .regularExpression)
                .replacingOccurrences(of: #"(?i)\s+(for|paid)\b.*$"#, with: "", options: .regularExpression)
                .trimmingCharacters(in: .whitespaces)
            if !cleaned.isEmpty { return cleaned }
        }
        return nil
    }

    static func removeStore(_ s: String) -> String {
        s.replacingOccurrences(of: #"\s+(at|from)\s+.*$"#, with: "", options: .regularExpression)
    }
}
