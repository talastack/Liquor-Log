import Foundation

/// What to try next, worked out from what you rated highest.
///
/// Not a taste model. Each suggestion is a catalogue product structurally
/// related to something you rated well -- the same line, the same recipe
/// code, the same distillery, the same mashbill -- and every one says
/// which bottle of yours put it there and why, so the reasoning is on the
/// screen and never in a black box. Things you have already had are left
/// out; a bottle on your shelf is not a suggestion.
public enum TryNext: Sendable {

    /// A bottle you rated, as the source of suggestions.
    public struct Liked: Hashable, Sendable {
        public let product: ProductIdentity
        public let rating: Int
        public let recipeCode: RecipeCode?
        public let mashbillKey: String?

        public init(product: ProductIdentity, rating: Int, recipeCode: RecipeCode? = nil, mashbillKey: String? = nil) {
            self.product = product
            self.rating = rating
            self.recipeCode = recipeCode
            self.mashbillKey = mashbillKey
        }
    }

    public struct Suggestion: Hashable, Sendable, Identifiable {
        public let product: ProductIdentity
        /// The bottle of yours it comes from, and how it relates.
        public let because: ProductIdentity
        public let reason: SearchHit.Reason
        public let becauseRating: Int
        public var id: String { product.productId }

        /// "Same line as Weller 12, which you rated 9."
        public var why: String {
            let how: String
            switch reason {
            case .sameLine: how = "Same line as"
            case .sameRecipe: how = "Same recipe as"
            case .sameDistillery: how = "Same distillery as"
            case .exact, .prefix, .fuzzy: how = "Related to"
            }
            return "\(how) \(because.displayName), which you rated \(becauseRating)."
        }
    }

    /// Ratings at or above this make a bottle a source of suggestions.
    public static let threshold = 7

    /// Suggestions from your best-rated bottles, best first. A product
    /// reachable from two of your bottles is listed once, under the
    /// higher-rated one; the same distillery alone is the weakest link and
    /// is only used when line and recipe have nothing to offer.
    public static func suggest(
        liked: [Liked],
        catalogue: [SearchCandidate],
        had: Set<String>,
        limit: Int = 12
    ) -> [Suggestion] {
        let sources = liked
            .filter { $0.rating >= threshold }
            .sorted { $0.rating != $1.rating ? $0.rating > $1.rating : $0.product.displayName < $1.product.displayName }
        var seen = Set<String>()
        var out: [Suggestion] = []

        for source in sources {
            var hits = BottleSearch.related(
                to: source.product, recipeCode: source.recipeCode, in: catalogue, limit: 40)
            // A shared mashbill is a relation `related` does not know about;
            // it ranks between recipe and distillery.
            if let key = source.mashbillKey {
                for candidate in catalogue
                where candidate.mashbillKey == key
                    && candidate.product.productId != source.product.productId
                    && !hits.contains(where: { $0.product.productId == candidate.product.productId }) {
                    hits.append(SearchHit(product: candidate.product, score: 0.7, reason: .sameRecipe))
                }
            }
            let ordered = hits.sorted {
                $0.score != $1.score ? $0.score > $1.score : $0.product.displayName < $1.product.displayName
            }
            for hit in ordered
            where !had.contains(hit.product.productId) && !seen.contains(hit.product.productId) {
                seen.insert(hit.product.productId)
                out.append(Suggestion(
                    product: hit.product, because: source.product,
                    reason: hit.reason, becauseRating: source.rating))
            }
        }

        // Line and recipe first across every source; distillery-only
        // suggestions fill in after.
        let strong = out.filter { $0.reason != .sameDistillery }
        let weak = out.filter { $0.reason == .sameDistillery }
        return Array((strong + weak).prefix(limit))
    }
}
