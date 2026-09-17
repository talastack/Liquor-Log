package com.talastack.liquorlog.engine

import kotlin.math.max
import kotlin.math.min

/** A catalogue row as the search sees it. */
data class SearchCandidate(
    val product: ProductIdentity,
    val recipeCode: RecipeCode? = null,
    /** Mashbill or grain-recipe key, for relating bottles that share one. */
    val mashbillKey: String? = null,
    /** True when this product already appears in your bottles or tastings. */
    val isInYourHistory: Boolean = false,
)

data class SearchHit(
    val product: ProductIdentity,
    val score: Double,
    val reason: Reason,
) {
    /**
     * Why this row surfaced. Shown in the UI, because "related" results that
     * do not say how they are related read as a broken search.
     */
    enum class Reason(val storageKey: String) {
        EXACT("exact"),
        PREFIX("prefix"),
        FUZZY("fuzzy"),
        SAME_LINE("sameLine"),
        SAME_DISTILLERY("sameDistillery"),
        SAME_RECIPE("sameRecipe"),
    }
}

/**
 * Autofill for the shelf check and the add-bottle sheet.
 *
 * Pure function, no I/O, so it is fully testable on any machine. It also has
 * to be fast enough to run on every keystroke with no network, because it
 * runs in a shop.
 */
object BottleSearch {

    /** Below this, a fuzzy match is noise rather than a suggestion. */
    const val MINIMUM_FUZZY_SCORE = 0.45

    /**
     * A product already in your collection outranks a catalogue row scoring
     * the same. The bottle you are typing is usually one you have had
     * before, and when it is not, an exact match still wins on its own score.
     */
    const val HISTORY_BOOST = 0.15

    fun search(
        query: String,
        candidates: List<SearchCandidate>,
        limit: Int = 20,
    ): List<SearchHit> {
        val normalized = query.normalizedForMatching()
        if (normalized.isEmpty()) return emptyList()

        val hits = candidates.mapNotNull { candidate ->
            val base = score(normalized, candidate) ?: return@mapNotNull null
            if (candidate.isInYourHistory) base.copy(score = base.score + HISTORY_BOOST) else base
        }
        return rank(hits, limit)
    }

    /**
     * Products related to one you are looking at, for the "you might also
     * mean" row.
     *
     * Relatedness here is structural rather than textual: a shared line,
     * distillery or recipe code. That is what lets "Weller" surface its
     * wheated siblings and an OESQ pick surface the other Four Roses
     * recipes, neither of which string similarity would ever find.
     */
    fun related(
        product: ProductIdentity,
        recipeCode: RecipeCode? = null,
        candidates: List<SearchCandidate>,
        limit: Int = 10,
    ): List<SearchHit> {
        val distillery = product.distillery.normalizedForMatching()

        val hits = candidates.mapNotNull { candidate ->
            when {
                candidate.product.productId == product.productId -> null
                candidate.product.lineKey == product.lineKey ->
                    SearchHit(candidate.product, 0.9, SearchHit.Reason.SAME_LINE)
                recipeCode != null && candidate.recipeCode == recipeCode ->
                    SearchHit(candidate.product, 0.8, SearchHit.Reason.SAME_RECIPE)
                candidate.product.distillery.normalizedForMatching() == distillery ->
                    SearchHit(candidate.product, 0.6, SearchHit.Reason.SAME_DISTILLERY)
                else -> null
            }
        }
        return rank(hits, limit)
    }

    // MARK: - Scoring

    private fun rank(hits: List<SearchHit>, limit: Int): List<SearchHit> =
        hits.sortedWith(
            // Score descending, then name ascending, so equal scores come back
            // in the same order every launch.
            compareByDescending<SearchHit> { it.score }.thenBy { it.product.displayName },
        ).take(limit)

    private fun score(query: String, candidate: SearchCandidate): SearchHit? {
        val name = candidate.product.displayName.normalizedForMatching()
        val distillery = candidate.product.distillery.normalizedForMatching()
        val haystackTokens = "$distillery $name".split(" ").filter { it.isNotEmpty() }

        if (name == query) {
            return SearchHit(candidate.product, 1.0, SearchHit.Reason.EXACT)
        }

        // Every query token prefixes some token in the candidate. This is what
        // makes "eli cra bar" find Elijah Craig Barrel Proof.
        val queryTokens = query.split(" ").filter { it.isNotEmpty() }
        val allTokensPrefixed = queryTokens.all { queryToken ->
            haystackTokens.any { it.startsWith(queryToken) }
        }
        if (allTokensPrefixed) {
            // A longer query that still fully prefixes is stronger evidence.
            val coverage = query.length.toDouble() / max(name.length, 1)
            return SearchHit(
                candidate.product,
                0.75 + 0.2 * min(1.0, coverage),
                SearchHit.Reason.PREFIX,
            )
        }

        val score = similarity(query, name)
        if (score < MINIMUM_FUZZY_SCORE) return null
        return SearchHit(candidate.product, score * 0.7, SearchHit.Reason.FUZZY)
    }

    /** 1 minus normalised Levenshtein distance, in 0..1. */
    internal fun similarity(a: String, b: String): Double {
        val longest = max(a.length, b.length)
        if (longest == 0) return 1.0
        return 1 - levenshtein(a, b).toDouble() / longest
    }

    /**
     * Two-row Levenshtein. Rows rather than a full matrix because this runs
     * on every keystroke against the whole catalogue.
     */
    internal fun levenshtein(a: String, b: String): Int {
        if (a.isEmpty()) return b.length
        if (b.isEmpty()) return a.length

        var previous = IntArray(b.length + 1) { it }
        var current = IntArray(b.length + 1)

        for (i in 1..a.length) {
            current[0] = i
            for (j in 1..b.length) {
                val substitution = previous[j - 1] + if (a[i - 1] == b[j - 1]) 0 else 1
                current[j] = minOf(previous[j] + 1, current[j - 1] + 1, substitution)
            }
            val swap = previous
            previous = current
            current = swap
        }
        return previous[b.length]
    }
}
