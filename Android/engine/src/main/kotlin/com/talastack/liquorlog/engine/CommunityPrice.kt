package com.talastack.liquorlog.engine

import java.time.Instant

/**
 * What a bottle actually costs, from what people have seen it cost.
 *
 * **This is the only price data the app can honestly own.**
 *
 * Copying a control board's list and restating it does not change where it
 * came from; re-typing somebody's compilation is the thing copyright is
 * about. But an observation a person makes about a shelf they are standing in
 * front of is theirs, and one they contribute is ours. It carries no licence,
 * cannot be revoked, and -- unlike every published figure -- it gets more
 * accurate the more the app is used rather than staler.
 *
 * It is also the only price reference that can answer the question people
 * actually ask, because a control-state list only covers control states and a
 * suggested retail is not what anybody pays.
 *
 * **What this must never become:** a secondary-market valuation. The research
 * is unambiguous about apps that publish one -- *"the fair price on a ton of
 * bottles is absolute horse shit making the app useless as a guide... DO NOT
 * USE THIS TO EVALUATE YOUR BOURBON."* Every figure here is a shelf price
 * somebody reported paying or seeing, it says how many reports it rests on,
 * and it never predicts what a bottle is worth.
 */
object CommunityPrice {

    /** One person's sighting. */
    data class Report(
        val cents: Int,
        val seenAt: Instant,
        /**
         * Where, coarsely. Prices vary more between states than between shops,
         * so a national median is a number nobody recognises.
         */
        val region: String? = null
    )

    /**
     * Reports below this and there is nothing worth showing.
     *
     * One sighting is an anecdote and two is a coincidence. Showing a
     * "community price" built on a single report would be the app borrowing
     * authority it has not earned, and being wrong in public is how these apps
     * lose the room.
     */
    const val minimumReports = 3

    /**
     * Older than this and a report stops counting.
     *
     * Shelf prices move. A three-year-old sighting presented as current is
     * worse than no figure, because somebody would plan around it.
     */
    const val maximumAgeDays = 540.0

    data class Estimate(
        val cents: Int,
        val reportCount: Int,
        val lowestCents: Int,
        val highestCents: Int,
        val newest: Instant,
        val oldest: Instant,
        val region: String?
    ) {
        /** Named so it can never be mistaken for a manufacturer's figure. */
        val source: String
            get() {
                val whereSeen = region?.let { " in $it" } ?: ""
                return "$reportCount shelf prices reported$whereSeen"
            }

        /**
         * Always shown. The spread is the honest part: a bottle seen between
         * $45 and $90 does not have one price, and printing a median alone
         * would hide that.
         */
        val caveat: String
            get() = "A range of what people saw on shelves, not a valuation. " +
                "${Money.short(lowestCents)} to ${Money.short(highestCents)}."

        val reference: PriceReference
            get() = PriceReference(cents = cents, source = source, asOfYear = null)
    }

    /**
     * Aggregates reports into something showable, or null.
     *
     * Null is a real answer and the common one early on. An app with no users
     * yet has no community price, and inventing one would poison the feature
     * exactly when first impressions are formed.
     */
    fun estimate(
        reports: List<Report>,
        region: String? = null,
        now: Instant = Instant.now()
    ): Estimate? {
        val fresh = reports.filter { report ->
            report.cents > 0 &&
                (now.toEpochMilli() - report.seenAt.toEpochMilli()) / 86_400_000.0 <=
                maximumAgeDays &&
                (region == null || report.region == region)
        }
        if (fresh.size < minimumReports) return null

        val sorted = fresh.map { it.cents }.sorted()
        val middle = sorted.size / 2
        // The median. One duty-free bottle or one airport markup would drag a
        // mean somewhere nobody shops.
        val median = if (sorted.size % 2 == 1) {
            sorted[middle]
        } else {
            (sorted[middle - 1] + sorted[middle]) / 2
        }

        val dates = fresh.map { it.seenAt }.sorted()

        return Estimate(
            cents = median,
            reportCount = fresh.size,
            lowestCents = sorted.firstOrNull() ?: 0,
            highestCents = sorted.lastOrNull() ?: 0,
            newest = dates.lastOrNull() ?: now,
            oldest = dates.firstOrNull() ?: now,
            region = region
        )
    }

    /**
     * Prefers a regional figure and falls back to everywhere.
     *
     * A Kentucky shelf price is not a Virginia one, so the local number is
     * worth more -- but two local reports beaten by twenty national ones is
     * still better than showing nothing at all, and the source line says which
     * you are looking at.
     */
    fun best(
        reports: List<Report>,
        preferring: String?,
        now: Instant = Instant.now()
    ): Estimate? {
        if (preferring != null) {
            val local = estimate(reports = reports, region = preferring, now = now)
            if (local != null) return local
        }
        return estimate(reports = reports, region = null, now = now)
    }

    // MARK: - From the server's aggregates

    /**
     * One row of the `community_prices` view: everyone's fresh sightings of a
     * product, already reduced to a count, a median and a range, either for
     * one region or across all of them. Nobody's individual report ever
     * leaves the server.
     *
     * Swift decodes this straight from the view's JSON; here the data layer
     * does the parsing and hands the numbers in, because this module carries
     * no JSON dependency. The column names are kept in [storageKeys] so the
     * two sides cannot drift on what the view is called.
     */
    data class Aggregate(
        val catalogProductId: String,
        val region: String?,
        val isAll: Boolean,
        val reports: Int,
        val medianCents: Int,
        val lowestCents: Int,
        val highestCents: Int,
        val oldestSeenAt: Long,
        val latestSeenAt: Long
    ) {
        val estimate: Estimate
            get() = Estimate(
                cents = medianCents,
                reportCount = reports,
                lowestCents = lowestCents,
                highestCents = highestCents,
                newest = Instant.ofEpochMilli(latestSeenAt),
                oldest = Instant.ofEpochMilli(oldestSeenAt),
                region = if (isAll) null else region
            )

        companion object {
            /** The view's column names, in the order this type declares them. */
            val storageKeys: List<String> = listOf(
                "catalog_product_id", "region", "is_all", "reports",
                "median_cents", "lowest_cents", "highest_cents",
                "oldest_seen_at", "latest_seen_at"
            )
        }
    }

    /**
     * The same rule as [best] over reports, applied to the server's rows: the
     * region's figure when it rests on enough reports, otherwise the figure
     * across everywhere, otherwise nothing.
     *
     * Swift spells this as a second overload of `best`. Both would erase to
     * the same JVM signature, so this one carries the longer name.
     */
    fun bestOfAggregates(aggregates: List<Aggregate>, preferring: String?): Estimate? {
        if (preferring != null) {
            val local = aggregates.firstOrNull { !it.isAll && it.region == preferring }
            if (local != null && local.reports >= minimumReports) return local.estimate
        }
        val all = aggregates.firstOrNull { it.isAll }
        if (all != null && all.reports >= minimumReports) return all.estimate
        return null
    }
}
