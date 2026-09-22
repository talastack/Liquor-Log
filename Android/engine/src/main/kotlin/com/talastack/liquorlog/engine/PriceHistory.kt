package com.talastack.liquorlog.engine

import java.time.Instant

/**
 * What you have paid for this bottle before.
 *
 * The question in the aisle is "is this a rip-off?", and for anything
 * allocated that is a secondary-market question with no free, legal, stable
 * source behind it. Apps that answer it anyway get checked against reality
 * and lose: *"the fair price on a ton of bottles is absolute horse shit
 * making the app useless as a guide... DO NOT USE THIS TO EVALUATE YOUR
 * BOURBON."*
 *
 * This answers a narrower question that needs no outside data at all, is
 * impossible to be wrong about, and is often the one actually being asked:
 * **what did I pay last time?**
 *
 * It is worth more than it looks. Somebody who buys the same bourbon twice a
 * year has a better price sense for it than any published figure, and the
 * thing they cannot do is remember it accurately at the shelf.
 */
object PriceHistory {

    /** One previous purchase of the same product. */
    data class Purchase(
        val cents: Int,
        /**
         * What the shelf said, which is not always what was paid: a sale, a
         * club discount and a bundle all make the two differ.
         */
        val shelfCents: Int? = null,
        val purchasedAt: Instant? = null,
        val store: String? = null
    )

    /** What your own record says this bottle costs. */
    data class Summary(
        val purchases: List<Purchase>,
        val lowestCents: Int,
        val highestCents: Int,
        /**
         * The MEDIAN, not the mean. One duty-free bottle or one auction
         * mistake would drag an average somewhere you never actually shop.
         */
        val typicalCents: Int,
        val mostRecent: Purchase?
    ) {
        val count: Int get() = purchases.size

        /**
         * True when every purchase was the same price, which makes a range
         * misleading to print.
         */
        val isSinglePrice: Boolean get() = lowestCents == highestCents

        /** Plain words. Never a recommendation, only a record. */
        val summary: String
            get() {
                if (count == 1) {
                    return "You paid ${Money.short(typicalCents)} for this before."
                }
                if (isSinglePrice) {
                    return "You have paid ${Money.short(typicalCents)} each of the " +
                        "$count times you bought this."
                }
                return "You have bought this $count times, from " +
                    "${Money.short(lowestCents)} to ${Money.short(highestCents)}."
            }
    }

    /**
     * A price reference built from what the USER has seen on shelves.
     *
     * This is the app's answer to "what should this cost", and it
     * deliberately uses nobody else's data. Every third-party price source
     * carries a licensing question -- state boards may assert rights in their
     * lists, retailers have terms, and resale figures have no free stable
     * source at all. What somebody wrote down about a shelf they stood in
     * front of has none of those problems.
     *
     * It also gets better with use rather than staler, which no published
     * figure does.
     *
     * Null until at least one shelf price has been recorded: a reference
     * built from nothing would be a number nobody could defend.
     */
    fun shelfReference(purchases: List<Purchase>, asOfYear: Int? = null): PriceReference? {
        val seen = purchases.mapNotNull { it.shelfCents }.filter { it > 0 }.sorted()
        if (seen.isEmpty()) return null

        return PriceReference(
            cents = median(seen),
            source = if (seen.size == 1) {
                "the shelf price you recorded"
            } else {
                "the ${seen.size} shelf prices you recorded"
            },
            asOfYear = asOfYear
        )
    }

    /**
     * Builds the summary. Null when there is nothing to compare against,
     * which is the honest answer for a bottle you have never bought before.
     */
    fun summarise(purchases: List<Purchase>): Summary? {
        val priced = purchases.filter { it.cents > 0 }
        if (priced.isEmpty()) return null

        val sorted = priced.map { it.cents }.sorted()

        // First of equal maxima, as Swift's max(by:) keeps.
        val mostRecent = priced
            .filter { it.purchasedAt != null }
            .maxByOrNull { it.purchasedAt!! }

        return Summary(
            purchases = priced,
            lowestCents = sorted.firstOrNull() ?: 0,
            highestCents = sorted.lastOrNull() ?: 0,
            typicalCents = median(sorted),
            mostRecent = mostRecent ?: priced.last()
        )
    }

    /** Integer median of a list already sorted ascending; even counts average the middle pair. */
    private fun median(sorted: List<Int>): Int {
        val middle = sorted.size / 2
        return if (sorted.size % 2 == 1) {
            sorted[middle]
        } else {
            (sorted[middle - 1] + sorted[middle]) / 2
        }
    }

    /**
     * How a price in front of you compares with what you have paid.
     *
     * Bands are deliberately wide and deliberately unalarming. Shelf prices
     * move, a bottle bought two years ago is not a fair benchmark today, and
     * an app that cried "overpriced" at a normal increase would be wrong far
     * more often than useful.
     */
    enum class Verdict(val storageKey: String) {
        CHEAPER_THAN_USUAL("cheaperThanUsual"),
        ABOUT_WHAT_YOU_PAY("aboutWhatYouPay"),
        MORE_THAN_USUAL("moreThanUsual"),
        MUCH_MORE_THAN_USUAL("muchMoreThanUsual"),
        NO_HISTORY("noHistory");

        val headline: String
            get() = when (this) {
                CHEAPER_THAN_USUAL -> "Cheaper than you usually pay"
                ABOUT_WHAT_YOU_PAY -> "About what you usually pay"
                MORE_THAN_USUAL -> "More than you usually pay"
                MUCH_MORE_THAN_USUAL -> "Much more than you usually pay"
                NO_HISTORY -> "You have not bought this before"
            }
    }

    /** Within this either way counts as the same price. */
    const val sameSpread = 0.10

    /** Beyond this it is worth saying out loud. */
    const val muchMoreSpread = 0.40

    fun compare(askingCents: Int, history: Summary?): Verdict {
        if (history == null || history.typicalCents <= 0) return Verdict.NO_HISTORY
        val fraction =
            (askingCents - history.typicalCents).toDouble() / history.typicalCents.toDouble()

        return when {
            fraction < -sameSpread -> Verdict.CHEAPER_THAN_USUAL
            fraction <= sameSpread -> Verdict.ABOUT_WHAT_YOU_PAY
            fraction <= muchMoreSpread -> Verdict.MORE_THAN_USUAL
            else -> Verdict.MUCH_MORE_THAN_USUAL
        }
    }
}
