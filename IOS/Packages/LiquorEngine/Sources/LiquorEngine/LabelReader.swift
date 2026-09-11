import Foundation

/// Turns the text on a bottle label into fields.
///
/// **This is where the work is.** Getting characters off a label is Apple's
/// Vision framework — on-device, free, offline, no API key, and about sixty
/// lines. Turning
///
///     ELIJAH CRAIG / KENTUCKY STRAIGHT BOURBON WHISKEY
///     BARREL PROOF / BATCH B523 / 124.2 PROOF / 750 ML
///
/// into a proof, a batch code and a catalogue match is the part that decides
/// whether the feature is worth using, and it needs no model at all.
///
/// **No AI, and that is a design decision rather than a limitation.** A cloud
/// model is a paid dependency and breaks the offline promise, both of which
/// were ruled out on day one. And the research is pointed about the value: one
/// developer built AI label recognition and *removed it before launch* because
/// *"the photo recognition flow felt slower and didn't really add much benefit
/// compared to just adding bottles manually."* Regular expressions over
/// recognised text are faster than a model, run everywhere, and cannot
/// hallucinate a proof that is not on the bottle.
///
/// **Everything here is a SUGGESTION.** Nothing is written without somebody
/// confirming it. A misread proof that silently becomes a bottle's strength
/// would poison the cost-per-pour, the perceived-proof verdict and the shelf
/// check at once — and unlike a typo, nobody would know they had made it.
public enum LabelReader: Sendable {

    /// What was found, with the lines it came from so a screen can show its
    /// working. Every field is optional because most labels carry few of them.
    public struct Reading: Hashable, Sendable {
        public var proof: Double?
        public var abv: Double?
        public var volumeMilliliters: Double?
        public var batchCode: String?
        public var barrelNumber: String?
        public var recipeCode: String?
        public var statedAgeYears: Int?
        public var isBottledInBond: Bool = false
        public var isSingleBarrel: Bool = false
        public var isSmallBatch: Bool = false
        /// Lines left over once the recognised facts are removed — the name,
        /// most of the time, and what gets matched against the catalogue.
        public var nameCandidate: String = ""

        /// Explicit because the synthesised memberwise initialiser is INTERNAL
        /// even when every field is public. The app needs an empty reading for
        /// the barcode-only case, where a photo carried a code but no legible
        /// text.
        public init() {}

        public var isEmpty: Bool {
            proof == nil && abv == nil && volumeMilliliters == nil
                && batchCode == nil && barrelNumber == nil && recipeCode == nil
                && statedAgeYears == nil && nameCandidate.isEmpty
        }
    }

    // MARK: - Patterns
    //
    // Anchored to the words that actually appear on American whiskey labels.
    // Each is deliberately narrow: a pattern that matches too much puts a wrong
    // number in a field somebody will not check.

    /// "124.2 PROOF" or "PROOF 124.2". Not a bare number: labels are covered in
    /// numbers and most of them are not the proof.
    static let proofPattern = #"(?:(\d{2,3}(?:\.\d)?)\s*(?:°|)\s*PROOF|PROOF\s*[:\-]?\s*(\d{2,3}(?:\.\d)?))"#

    /// "62.1% ALC/VOL", "ALC 62.1% BY VOL", "62.1% ABV".
    /// A percentage that names alcohol. This one is believed outright.
    static let abvPattern = #"(\d{1,2}(?:\.\d{1,2})?)\s*%\s*(?:ALC|ABV|ALCOHOL)"#
    /// Any percentage at all. Mashbill shares look exactly like this, so a
    /// bare one is only believed when nothing named alcohol was found and
    /// the number is in spirits range -- "1% MALTED BARLEY" is never 1% ABV.
    static let barePercentPattern = #"(\d{1,2}(?:\.\d{1,2})?)\s*%"#

    static let volumePattern = #"(\d{3,4})\s*(?:ML|MILLILIT)"#
    static let litrePattern = #"(\d(?:\.\d{1,2})?)\s*(?:L|LITER|LITRE)\b"#

    /// Elijah Craig and Larceny batch codes: a letter, then digits. "B523",
    /// "A125", "C923".
    static let batchPattern = #"\bBATCH\s*[:\-]?\s*([A-Z]\d{3})\b"#
    /// "BARREL NO. 42-3C", "BARREL 421".
    static let barrelPattern = #"\bBARREL\s*(?:NO\.?|#)?\s*([A-Z0-9][A-Z0-9\-]{0,9})\b"#
    /// "AGED 9 YEARS", "12 YEARS OLD".
    static let agePattern = #"(?:AGED\s+)?(\d{1,2})\s*YEARS?(?:\s+OLD)?"#

    // MARK: - Reading

    /// Parses recognised lines. Order is irrelevant — Vision returns them in
    /// whatever order it found them, which on a wrap-around label is not
    /// reading order.
    public static func read(_ lines: [String]) -> Reading {
        let upper = lines.map { $0.uppercased() }
        let joined = upper.joined(separator: " ")

        var reading = Reading()

        reading.proof = firstNumber(in: joined, pattern: proofPattern)
        // EVERY "%" on the label, not the first one. Labels print mashbill
        // shares too, and "99% CORN" above "45% ALC/VOL" would otherwise match
        // 99, get rejected as implausible, and lose the real strength.
        reading.abv = allNumbers(in: joined, pattern: abvPattern)
            .first { $0 > 0.5 && $0 <= 95 }
            ?? allNumbers(in: joined, pattern: barePercentPattern)
            .first { $0 >= 15 && $0 <= 95 }

        // Proof and ABV must agree, and the PROOF is believed when they do not.
        // It is printed larger, it is the number people read off a label, and
        // deriving one from the other is how a bottle ends up recorded at half
        // its strength.
        if let proof = reading.proof {
            reading.abv = ABV(proof: proof).percent
        } else if let abv = reading.abv {
            reading.proof = ABV(percent: abv).proof
        }

        reading.volumeMilliliters = firstNumber(in: joined, pattern: volumePattern)
            ?? firstNumber(in: joined, pattern: litrePattern).map { $0 * 1000 }

        reading.batchCode = firstString(in: joined, pattern: batchPattern)
        reading.barrelNumber = firstString(in: joined, pattern: barrelPattern)
        reading.statedAgeYears = firstNumber(in: joined, pattern: agePattern).map(Int.init)

        // A Four Roses code is four letters with a fixed shape, so it is
        // recognised by validating against the ten real codes rather than by a
        // pattern that would also match any other four-letter word.
        reading.recipeCode = upper
            .flatMap { $0.split(whereSeparator: { !$0.isLetter }).map(String.init) }
            .first { RecipeCode($0) != nil }

        reading.isBottledInBond = joined.contains("BOTTLED IN BOND")
            || joined.contains("BONDED")
        reading.isSingleBarrel = joined.contains("SINGLE BARREL")
        reading.isSmallBatch = joined.contains("SMALL BATCH")

        reading.nameCandidate = nameLines(upper).joined(separator: " ")
        return reading
    }

    /// Lines that plausibly carry the name.
    ///
    /// Everything a label says about government warnings, volume and strength
    /// is noise for matching, and leaving it in drags a search away from the
    /// brand. The remaining lines are usually the name and the distillery.
    static func nameLines(_ upper: [String]) -> [String] {
        let noise = [
            "GOVERNMENT WARNING", "SURGEON GENERAL", "PREGNANCY", "MACHINERY",
            "DRINK RESPONSIBLY", "ALC", "VOL", "PROOF", "ML", "DISTILLED BY",
            "BOTTLED BY", "PRODUCT OF", "CONTAINS", "SULFITES",
            // The attribution line, never the brand line. Eagle Rare,
            // Blanton's and Weller all print "Buffalo Trace Distillery", and
            // keeping it puts "buffalo trace" into the reading -- so Buffalo
            // Trace's own bourbon counts as brand-present on a bottle that is
            // not it. Buffalo Trace's OWN front label says "BUFFALO TRACE"
            // without the word, so dropping it costs nothing there.
            "DISTILLERY", "DISTILLERIES",
        ]
        return upper.filter { line in
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            guard trimmed.count >= 3 else { return false }
            // A line that is mostly digits is a code or a measure, not a name.
            let letters = trimmed.filter(\.isLetter).count
            guard letters * 2 > trimmed.count else { return false }
            return !noise.contains { trimmed.contains($0) }
        }
    }

    // MARK: - Matching

    /// The catalogue rows a reading might be, best first.
    ///
    /// Returns SUGGESTIONS. Nothing is written without confirmation, because a
    /// wrong match here attaches somebody's tasting notes to the wrong whiskey.
    public static func candidates(
        for reading: Reading, in catalog: [SearchCandidate], limit: Int = 5
    ) -> [SearchHit] {
        let words = Set(tokens(reading.nameCandidate))
        guard !words.isEmpty else { return [] }

        // A label is a pile of words -- brand, class statement, age, town --
        // and the shop search's rule (every typed word must prefix a name
        // word) fails on it by design. So the direction is reversed: a
        // product is a candidate when ITS brand appears among the label's
        // words, and ranks by how much of its expression does too.
        var hits: [SearchHit] = []
        for candidate in catalog {
            let product = candidate.product
            guard brandIsPresent(product, in: words) else { continue }
            let expression = tokens(product.expression)
            let expressionShare: Double
            if expression.isEmpty {
                expressionShare = 0.5
            } else {
                let matched = expression.filter { token in
                    words.contains { $0.hasPrefix(token) || token.hasPrefix($0) }
                }.count
                expressionShare = Double(matched) / Double(expression.count)
            }
            let score = 0.6 + 0.4 * expressionShare + (candidate.isInYourHistory ? 0.05 : 0)
            hits.append(SearchHit(
                product: product,
                score: score,
                reason: expressionShare >= 0.999 ? .exact : .prefix))
        }

        if hits.isEmpty {
            // OCR mangled the brand. Fall back to the fuzzy search over the
            // words that survived, brand-first as before.
            let fuzzy = BottleSearch.search(
                query: reading.nameCandidate, in: catalog, limit: limit * 2)
            return rankBrandFirst(fuzzy, against: reading.nameCandidate)
                .prefix(limit)
                .map { $0 }
        }

        return hits
            .sorted {
                $0.score == $1.score
                    ? $0.product.displayName < $1.product.displayName
                    : $0.score > $1.score
            }
            .prefix(limit)
            .map { $0 }
    }

    /// Products whose BRAND is on the label outrank ones matched only on the
    /// distillery.
    ///
    /// Eagle Rare, Blanton's and Weller all print "Buffalo Trace Distillery"
    /// on the label, so a search over the raw text matches every Buffalo Trace
    /// product and ranks them by noise — and Buffalo Trace's own bourbon can
    /// beat the bottle actually being held. The brand is the thing printed
    /// largest, and if its words are in the reading that is the answer.
    ///
    /// A stable partition, not a re-score: within each group the search's own
    /// order is kept, so this cannot make a good match worse.
    static func rankBrandFirst(_ hits: [SearchHit], against text: String) -> [SearchHit] {
        let words = Set(tokens(text))
        let brandMatched = hits.filter { brandIsPresent($0.product, in: words) }
        let rest = hits.filter { !brandIsPresent($0.product, in: words) }
        return brandMatched + rest
    }

    static func brandIsPresent(_ product: ProductIdentity, in words: Set<String>) -> Bool {
        let brand = tokens(product.brand)
        guard !brand.isEmpty else { return false }
        return brand.allSatisfy { words.contains($0) }
    }

    /// Lowercase alphanumeric words, so "Blanton's" and "BLANTONS" agree.
    static func tokens(_ text: String) -> [String] {
        text.lowercased()
            .replacingOccurrences(of: "'", with: "")
            .split(whereSeparator: { !$0.isLetter && !$0.isNumber })
            .map(String.init)
            .filter { $0.count > 1 }
    }

    // MARK: - Regex plumbing

    static func firstMatch(in text: String, pattern: String) -> [String]? {
        guard let regex = try? NSRegularExpression(pattern: pattern, options: []),
              let match = regex.firstMatch(
                in: text, range: NSRange(text.startIndex..., in: text))
        else { return nil }

        var groups: [String] = []
        for index in 1..<match.numberOfRanges {
            guard let range = Range(match.range(at: index), in: text) else { continue }
            groups.append(String(text[range]))
        }
        return groups.isEmpty ? nil : groups
    }

    /// Every capture from every match, in order. Needed wherever a label can
    /// legitimately carry more than one number of the same shape.
    static func allNumbers(in text: String, pattern: String) -> [Double] {
        guard let regex = try? NSRegularExpression(pattern: pattern, options: []) else {
            return []
        }
        let range = NSRange(text.startIndex..., in: text)
        return regex.matches(in: text, range: range).flatMap { match -> [Double] in
            (1..<match.numberOfRanges).compactMap { index in
                guard let captured = Range(match.range(at: index), in: text) else { return nil }
                return Double(text[captured])
            }
        }
    }

    static func firstNumber(in text: String, pattern: String) -> Double? {
        firstMatch(in: text, pattern: pattern)?
            .compactMap(Double.init)
            .first
    }

    static func firstString(in text: String, pattern: String) -> String? {
        firstMatch(in: text, pattern: pattern)?
            .first { !$0.isEmpty }
    }
}
