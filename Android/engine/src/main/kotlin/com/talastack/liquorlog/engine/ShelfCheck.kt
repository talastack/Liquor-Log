package com.talastack.liquorlog.engine

import java.time.Instant

/**
 * Who made it and what it is, at the level the catalogue records.
 *
 * [brand] is the line -- "Elijah Craig" -- and [expression] is the release
 * within it -- "Small Batch", "Barrel Proof", "18 Year". Two products
 * sharing a distillery and brand are the same line; differing in expression
 * makes them different whiskey. That distinction is the entire point of this
 * file.
 */
data class ProductIdentity(
    val productId: String,
    val distillery: String,
    val brand: String,
    val expression: String,
    val classType: ClassType,
    val productionType: ProductionType = ProductionType.UNSPECIFIED,
) {
    /** Identity of the product line, ignoring which expression it is. */
    val lineKey: String
        get() = "${distillery.normalizedForMatching()}|${brand.normalizedForMatching()}"

    val displayName: String
        get() = if (expression.isEmpty()) brand else "$brand $expression"
}

/**
 * A bottle you have or had. [releaseLabel] is the batch, pick or barrel that
 * distinguishes it from another bottle of the same product.
 */
data class Holding(
    val bottleId: String,
    val product: ProductIdentity,
    val releaseLabel: String? = null,
    val isOpen: Boolean = false,
    val isFinished: Boolean = false,
    /**
     * A sample -- a couple of ounces from a friend, a swap or a sample set
     * -- rather than a bottle. Owning one does not mean owning the bottle,
     * which is the question the aisle asks.
     */
    val isSample: Boolean = false,
)

/**
 * A tasting. Note it carries a product rather than a bottle: you can taste
 * something at a bar and never own it, which is a state the shelf check has
 * to be able to report.
 */
data class TastingRecord(
    val tastingId: String,
    val product: ProductIdentity,
    val tastedAt: Instant,
    val rating: Int? = null,
    val wouldRebuy: Boolean? = null,
    val liked: String? = null,
    val disliked: String? = null,
    /**
     * Where it happened when it was not your own bottle -- "At a bar", "A
     * sample" -- ready to print. Null for a pour of your own. Named for the
     * question rather than `where`, which Kotlin reserves.
     */
    val whereTasted: String? = null,
)

/**
 * The answer to "do I have this", standing in a shop with the bottle in
 * hand.
 *
 * **Ownership and tasting are independent, not a sequence.** You can have
 * tasted something at a bar and never owned it, and own something unopened
 * you have never tried. [headline] therefore describes ownership only; the
 * tasting fields are populated regardless of what the headline says, and the
 * card shows both.
 */
data class ShelfCheckResult(
    val product: ProductIdentity,
    val headline: Headline,
    val onShelf: List<Holding>,
    val finished: List<Holding>,
    val tastings: List<TastingRecord>,
    /** Bottles and tastings from the same line but a *different* expression. */
    val sameLine: List<ProductIdentity>,
    val isOnWishlist: Boolean,
) {
    enum class Headline(val storageKey: String) {
        NEVER_HAD_IT("neverHadIt"),

        /**
         * You own or have tried this line, but not this release. The answer
         * a flat "do I own this brand" lookup gets wrong.
         */
        HAVE_THE_LINE_NOT_THIS_RELEASE("haveTheLineNotThisRelease"),

        ON_YOUR_SHELF("onYourShelf"),

        /**
         * A sample of it on hand and no bottle. Sits between owning and
         * having owned: you can pour it tonight, and you still might buy it.
         */
        HAVE_A_SAMPLE("haveASample"),

        HAD_IT_BEFORE("hadItBefore"),
        TASTED_NEVER_OWNED("tastedNeverOwned"),
    }

    /**
     * Most recent tasting, which is what the card leads with -- your current
     * opinion beats your first one.
     */
    val latestTasting: TastingRecord? get() = tastings.maxByOrNull { it.tastedAt }

    val bestRating: Int? get() = tastings.mapNotNull { it.rating }.maxOrNull()

    val openBottleCount: Int get() = onShelf.count { it.isOpen }
}

object ShelfCheck {

    /**
     * Pure function over what the repositories hand it. No I/O, so the whole
     * verdict is testable without a database or a network -- which matters
     * because this screen has to work in a shop with no signal.
     */
    fun evaluate(
        product: ProductIdentity,
        holdings: List<Holding>,
        tastings: List<TastingRecord>,
        wishlistProductIds: Set<String> = emptySet(),
    ): ShelfCheckResult {
        val exactHoldings = holdings.filter { it.product.productId == product.productId }
        val onShelf = exactHoldings.filter { !it.isFinished }
        val finished = exactHoldings.filter { it.isFinished }

        val forThisProduct = tastings.filter { it.product.productId == product.productId }

        // Same line, different expression. Deduplicated and ordered so the
        // card is stable between launches.
        val sameLine = (holdings.map { it.product } + tastings.map { it.product })
            .filter { it.lineKey == product.lineKey && it.productId != product.productId }
            .distinctBy { it.productId }
            .sortedBy { it.displayName }

        val headline = when {
            onShelf.any { !it.isSample } -> ShelfCheckResult.Headline.ON_YOUR_SHELF
            onShelf.isNotEmpty() -> ShelfCheckResult.Headline.HAVE_A_SAMPLE
            finished.isNotEmpty() -> ShelfCheckResult.Headline.HAD_IT_BEFORE
            forThisProduct.isNotEmpty() -> ShelfCheckResult.Headline.TASTED_NEVER_OWNED
            sameLine.isNotEmpty() -> ShelfCheckResult.Headline.HAVE_THE_LINE_NOT_THIS_RELEASE
            else -> ShelfCheckResult.Headline.NEVER_HAD_IT
        }

        return ShelfCheckResult(
            product = product,
            headline = headline,
            onShelf = onShelf,
            finished = finished,
            tastings = forThisProduct,
            sameLine = sameLine,
            isOnWishlist = wishlistProductIds.contains(product.productId),
        )
    }
}
