package com.talastack.liquorlog.engine

/**
 * A published price to compare against, and where it came from.
 *
 * **This is a SHELF price, not a market value.** It is what a bottle costs
 * where prices are posted publicly -- a state control board's price list, or
 * a producer's stated suggested retail. It is not what an allocated bottle
 * trades for between collectors, and the app must never imply that it is.
 *
 * Every reference names its source, because a price with no provenance is a
 * number the user cannot check and we cannot defend.
 */
data class PriceReference(
    val cents: Int,
    /**
     * Human-readable origin, shown in the UI verbatim: "Virginia ABC",
     * "Oregon OLCC", "Producer stated SRP".
     */
    val source: String,
    /**
     * Year the figure was published. Shelf prices drift, and a five-year-old
     * reference presented as current is worse than no reference.
     */
    val asOfYear: Int? = null,
)

/**
 * Compares what you paid against a published shelf price.
 *
 * The question a user actually asks in a shop is "is this a rip-off?" -- and
 * for anything allocated, that is a secondary-market question this app
 * cannot answer. There is no free, legal, stable source for resale prices,
 * and scraping listings is a terms-of-service problem before it is a
 * technical one.
 *
 * So this answers the narrower question honestly and says which one it
 * answered: **how does this compare to the shelf price where prices are
 * posted?** [Result.caveat] carries that sentence and the UI must show it.
 */
object PriceCheck {

    enum class Band(val storageKey: String) {
        /** At or under the published shelf price. */
        AT_OR_BELOW("atOrBelow"),
        /** Within a normal spread between markets. */
        SLIGHTLY_OVER("slightlyOver"),
        /** Meaningfully above shelf, the usual sign of secondary pricing. */
        WELL_OVER("wellOver"),
        /** Multiples of shelf price. */
        FAR_OVER("farOver"),
        /** No published figure for this product. */
        NO_REFERENCE("noReference"),
    }

    /**
     * Boundaries as a fraction over the reference. Deliberately wide: shelf
     * prices vary legitimately between states and retailers, and a band that
     * called a normal regional difference "overpriced" would be wrong far
     * more often than it was useful.
     */
    const val SLIGHTLY_OVER_THRESHOLD = 0.10
    const val WELL_OVER_THRESHOLD = 0.40

    data class Result(
        val paidCents: Int,
        val reference: PriceReference?,
        val band: Band,
        /** Positive when you paid over the reference. Null without a reference. */
        val differenceCents: Int?,
        /** Fraction over the reference; 0.5 means half again. Null without one. */
        val fractionOver: Double?,
    ) {
        /** One line naming what was compared. Always shown beside the verdict. */
        val caveat: String
            get() {
                val reference = reference ?: return "No published shelf price for this bottle."
                val year = reference.asOfYear?.let { " ($it)" } ?: ""
                return "Compared with the ${reference.source} shelf price$year. " +
                    "Not a resale value."
            }

        val headline: String
            get() = when (band) {
                Band.AT_OR_BELOW -> "At or under shelf price"
                Band.SLIGHTLY_OVER -> "A little over shelf price"
                Band.WELL_OVER -> "Well over shelf price"
                Band.FAR_OVER -> "Far over shelf price"
                Band.NO_REFERENCE -> "No shelf price to compare"
            }
    }

    fun compare(paidCents: Int, reference: PriceReference?): Result {
        if (reference == null || reference.cents <= 0) {
            return Result(
                paidCents = paidCents, reference = reference,
                band = Band.NO_REFERENCE, differenceCents = null, fractionOver = null,
            )
        }

        val difference = paidCents - reference.cents
        val fraction = difference.toDouble() / reference.cents

        val band = when {
            fraction <= 0 -> Band.AT_OR_BELOW
            fraction <= SLIGHTLY_OVER_THRESHOLD -> Band.SLIGHTLY_OVER
            fraction <= WELL_OVER_THRESHOLD -> Band.WELL_OVER
            else -> Band.FAR_OVER
        }

        return Result(
            paidCents = paidCents, reference = reference,
            band = band, differenceCents = difference, fractionOver = fraction,
        )
    }

    /**
     * What a pour costs, from what was actually paid. This one needs no
     * external data at all and is the more useful number day to day: it turns
     * an intimidating bottle price into the price of a drink.
     */
    fun costPerPourCents(
        paidCents: Int,
        capacityMilliliters: Double,
        pourSize: PourSize = PourSize.standard,
    ): Int? = PourMath.costPerPourCents(paidCents, capacityMilliliters, pourSize)
}
