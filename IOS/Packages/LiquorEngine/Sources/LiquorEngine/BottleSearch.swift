import Foundation

extension String {
    /// Lowercased, de-accented, punctuation stripped, whitespace collapsed.
    ///
    /// "Elijah Craig Barrel-Proof (B523)" and "elijah craig barrel proof b523"
    /// have to be the same string before anything can be compared, or the
    /// catalog acquires duplicates that differ only in a hyphen.
    func normalizedForMatching() -> String {
        lowercased()
            .folding(options: .diacriticInsensitive, locale: nil)
            .components(separatedBy: CharacterSet.alphanumerics.inverted)
            .filter { !$0.isEmpty }
            .joined(separator: " ")
    }

    var matchTokens: [String] {
        normalizedForMatching().split(separator: " ").map(String.init)
    }
}

/// A catalog row as the search sees it.
public struct SearchCandidate: Hashable, Sendable {
    public let product: ProductIdentity
    public let recipeCode: RecipeCode?
    /// Mashbill or grain-recipe key, for relating bottles that share one.
    public let mashbillKey: String?
    /// True when this product already appears in your bottles or tastings.
    public let isInYourHistory: Bool

    public init(
        product: ProductIdentity,
        recipeCode: RecipeCode? = nil,
        mashbillKey: String? = nil,
        isInYourHistory: Bool = false
    ) {
        self.product = product
        self.recipeCode = recipeCode
        self.mashbillKey = mashbillKey
        self.isInYourHistory = isInYourHistory
    }
}

public struct SearchHit: Hashable, Sendable {
    public let product: ProductIdentity
    public let score: Double
    public let reason: Reason

    /// Why this row surfaced. Shown in the UI, because "related" results that do
    /// not say how they are related read as a broken search.
    public enum Reason: String, Sendable, Hashable {
        case exact
        case prefix
        case fuzzy
        case sameLine
        case sameDistillery
        case sameRecipe
    }

    public init(product: ProductIdentity, score: Double, reason: Reason) {
        self.product = product
        self.score = score
        self.reason = reason
    }
}

/// Autofill for the shelf check and the add-bottle sheet.
///
/// Pure function, no I/O, so it is fully testable on any machine. It also has to
/// be fast enough to run on every keystroke with no network, because it runs in
/// a shop.
public enum BottleSearch: Sendable {

    /// Below this, a fuzzy match is noise rather than a suggestion.
    public static let minimumFuzzyScore = 0.45

    /// A product already in your collection outranks a catalog row scoring the
    /// same. The bottle you are typing is usually one you have had before, and
    /// when it is not, an exact match still wins on its own score.
    public static let historyBoost = 0.15

    public static func search(
        query rawQuery: String,
        in candidates: [SearchCandidate],
        limit: Int = 20
    ) -> [SearchHit] {
        let query = rawQuery.normalizedForMatching()
        guard !query.isEmpty else { return [] }

        var hits: [SearchHit] = []
        for candidate in candidates {
            guard let base = score(query: query, candidate: candidate) else { continue }
            let boosted = candidate.isInYourHistory
                ? SearchHit(
                    product: base.product,
                    score: base.score + historyBoost,
                    reason: base.reason
                )
                : base
            hits.append(boosted)
        }

        return rank(hits, limit: limit)
    }

    /// Products related to one you are looking at, for the "you might also mean"
    /// row.
    ///
    /// Relatedness here is structural rather than textual: a shared line,
    /// distillery or recipe code. That is what lets "Weller" surface its wheated
    /// siblings and an OESQ pick surface the other Four Roses recipes, neither of
    /// which string similarity would ever find.
    public static func related(
        to product: ProductIdentity,
        recipeCode: RecipeCode? = nil,
        in candidates: [SearchCandidate],
        limit: Int = 10
    ) -> [SearchHit] {
        let distillery = product.distillery.normalizedForMatching()

        let hits: [SearchHit] = candidates.compactMap { candidate in
            guard candidate.product.productId != product.productId else { return nil }

            if candidate.product.lineKey == product.lineKey {
                return SearchHit(product: candidate.product, score: 0.9, reason: .sameLine)
            }
            if let code = recipeCode, candidate.recipeCode == code {
                return SearchHit(product: candidate.product, score: 0.8, reason: .sameRecipe)
            }
            if candidate.product.distillery.normalizedForMatching() == distillery {
                return SearchHit(product: candidate.product, score: 0.6, reason: .sameDistillery)
            }
            return nil
        }

        return rank(hits, limit: limit)
    }

    // MARK: - Scoring

    private static func rank(_ hits: [SearchHit], limit: Int) -> [SearchHit] {
        hits
            .sorted {
                $0.score == $1.score
                    ? $0.product.displayName < $1.product.displayName
                    : $0.score > $1.score
            }
            .prefix(limit)
            .map { $0 }
    }

    private static func score(query: String, candidate: SearchCandidate) -> SearchHit? {
        let name = candidate.product.displayName.normalizedForMatching()
        let distillery = candidate.product.distillery.normalizedForMatching()
        let haystackTokens = "\(distillery) \(name)".split(separator: " ").map(String.init)

        if name == query {
            return SearchHit(product: candidate.product, score: 1.0, reason: .exact)
        }

        // Every query token prefixes some token in the candidate. This is what
        // makes "eli cra bar" find Elijah Craig Barrel Proof.
        let queryTokens = query.split(separator: " ").map(String.init)
        let allTokensPrefixed = queryTokens.allSatisfy { queryToken in
            haystackTokens.contains { $0.hasPrefix(queryToken) }
        }
        if allTokensPrefixed {
            // A longer query that still fully prefixes is stronger evidence.
            let coverage = Double(query.count) / Double(max(name.count, 1))
            return SearchHit(
                product: candidate.product,
                score: 0.75 + 0.2 * min(1, coverage),
                reason: .prefix
            )
        }

        let score = similarity(query, name)
        guard score >= minimumFuzzyScore else { return nil }
        return SearchHit(product: candidate.product, score: score * 0.7, reason: .fuzzy)
    }

    /// 1 minus normalised Levenshtein distance, in 0...1.
    static func similarity(_ a: String, _ b: String) -> Double {
        let longest = max(a.count, b.count)
        guard longest > 0 else { return 1 }
        return 1 - Double(levenshtein(a, b)) / Double(longest)
    }

    /// Two-row Levenshtein. Rows rather than a full matrix because this runs on
    /// every keystroke against the whole catalog.
    static func levenshtein(_ a: String, _ b: String) -> Int {
        let source = Array(a)
        let target = Array(b)
        if source.isEmpty { return target.count }
        if target.isEmpty { return source.count }

        var previous = Array(0...target.count)
        var current = [Int](repeating: 0, count: target.count + 1)

        for i in 1...source.count {
            current[0] = i
            for j in 1...target.count {
                let substitution = previous[j - 1] + (source[i - 1] == target[j - 1] ? 0 : 1)
                current[j] = min(previous[j] + 1, current[j - 1] + 1, substitution)
            }
            swap(&previous, &current)
        }
        return previous[target.count]
    }
}
