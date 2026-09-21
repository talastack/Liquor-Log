package com.talastack.liquorlog.engine

/**
 * What to try next, worked out from what you rated highest.
 *
 * Not a taste model. Each suggestion is a catalogue product structurally
 * related to something you rated well -- the same line, the same recipe
 * code, the same distillery, the same mashbill -- and every one says
 * which bottle of yours put it there and why, so the reasoning is on the
 * screen and never in a black box. Things you have already had are left
 * out; a bottle on your shelf is not a suggestion.
 */
object TryNext {

    /** A bottle you rated, as the source of suggestions. */
    data class Liked(
        val product: ProductIdentity,
        val rating: Int,
        val recipeCode: RecipeCode? = null,
        val mashbillKey: String? = null
    )

    data class Suggestion(
        val product: ProductIdentity,
        /** The bottle of yours it comes from, and how it relates. */
        val because: ProductIdentity,
        val reason: SearchHit.Reason,
        val becauseRating: Int
    ) {
        val id: String get() = product.productId

        /** "Same line as Weller 12, which you rated 9." */
        val why: String
            get() {
                val how = when (reason) {
                    SearchHit.Reason.SAME_LINE -> "Same line as"
                    SearchHit.Reason.SAME_RECIPE -> "Same recipe as"
                    SearchHit.Reason.SAME_DISTILLERY -> "Same distillery as"
                    SearchHit.Reason.EXACT,
                    SearchHit.Reason.PREFIX,
                    SearchHit.Reason.FUZZY -> "Related to"
                }
                return "$how ${because.displayName}, which you rated $becauseRating."
            }
    }

    /** Ratings at or above this make a bottle a source of suggestions. */
    const val threshold = 7

    /**
     * Suggestions from your best-rated bottles, best first. A product
     * reachable from two of your bottles is listed once, under the
     * higher-rated one; the same distillery alone is the weakest link and
     * is only used when line and recipe have nothing to offer.
     */
    fun suggest(
        liked: List<Liked>,
        catalogue: List<SearchCandidate>,
        had: Set<String>,
        limit: Int = 12
    ): List<Suggestion> {
        val sources = liked
            .filter { it.rating >= threshold }
            .sortedWith(
                compareByDescending<Liked> { it.rating }.thenBy { it.product.displayName }
            )
        val seen = mutableSetOf<String>()
        val out = mutableListOf<Suggestion>()

        for (source in sources) {
            val hits = BottleSearch.related(
                product = source.product,
                recipeCode = source.recipeCode,
                candidates = catalogue,
                limit = 40
            ).toMutableList()

            // A shared mashbill is a relation `related` does not know about;
            // it ranks between recipe and distillery.
            val key = source.mashbillKey
            if (key != null) {
                for (candidate in catalogue) {
                    if (candidate.mashbillKey != key) continue
                    if (candidate.product.productId == source.product.productId) continue
                    if (hits.any { it.product.productId == candidate.product.productId }) continue
                    hits.add(SearchHit(candidate.product, 0.7, SearchHit.Reason.SAME_RECIPE))
                }
            }

            val ordered = hits.sortedWith(
                compareByDescending<SearchHit> { it.score }.thenBy { it.product.displayName }
            )
            for (hit in ordered) {
                if (hit.product.productId in had) continue
                if (!seen.add(hit.product.productId)) continue
                out.add(
                    Suggestion(
                        product = hit.product,
                        because = source.product,
                        reason = hit.reason,
                        becauseRating = source.rating
                    )
                )
            }
        }

        // Line and recipe first across every source; distillery-only
        // suggestions fill in after.
        val strong = out.filter { it.reason != SearchHit.Reason.SAME_DISTILLERY }
        val weak = out.filter { it.reason == SearchHit.Reason.SAME_DISTILLERY }
        return (strong + weak).take(limit)
    }
}
