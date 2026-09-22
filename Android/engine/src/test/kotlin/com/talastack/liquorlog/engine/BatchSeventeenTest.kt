package com.talastack.liquorlog.engine

import java.time.Instant
import java.time.temporal.ChronoUnit
import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertFalse
import kotlin.test.assertNotNull
import kotlin.test.assertNull
import kotlin.test.assertTrue

/**
 * The only price data the app can honestly own. These pin the restraint: it
 * stays quiet until it has enough to say, and it never claims to be a value.
 */
class CommunityPriceTest {

    private val now: Instant = Instant.EPOCH.plus(1_000, ChronoUnit.DAYS)

    private fun report(dollars: Double, daysAgo: Long = 1, region: String? = null) =
        CommunityPrice.Report(
            cents = (dollars * 100).toInt(),
            seenAt = now.minus(daysAgo, ChronoUnit.DAYS),
            region = region
        )

    /**
     * One sighting is an anecdote and two is a coincidence. Showing a
     * "community price" from a single report borrows authority the app has
     * not earned.
     */
    @Test
    fun `too few reports says nothing`() {
        assertNull(CommunityPrice.estimate(emptyList(), now = now))
        assertNull(CommunityPrice.estimate(listOf(report(50.0)), now = now))
        assertNull(CommunityPrice.estimate(listOf(report(50.0), report(52.0)), now = now))
    }

    @Test
    fun `three reports is enough`() {
        val estimate = CommunityPrice.estimate(
            listOf(report(50.0), report(52.0), report(54.0)), now = now
        )
        assertNotNull(estimate)
        assertEquals(3, estimate.reportCount)
    }

    /**
     * Shelf prices move. A three-year-old sighting shown as current is worse
     * than nothing, because somebody would plan around it.
     */
    @Test
    fun `stale reports are dropped`() {
        val old = listOf(
            report(50.0, daysAgo = 900),
            report(52.0, daysAgo = 900),
            report(54.0, daysAgo = 900)
        )
        assertNull(CommunityPrice.estimate(old, now = now))
    }

    @Test
    fun `stale reports do not prop up fresh ones`() {
        val mixed = listOf(report(50.0), report(52.0), report(999.0, daysAgo = 900))
        assertNull(
            CommunityPrice.estimate(mixed, now = now),
            "two fresh reports is still too few"
        )
    }

    /**
     * One duty-free bottle or one airport markup would drag a mean somewhere
     * nobody shops.
     */
    @Test
    fun `it uses the median, not the mean`() {
        val reports = listOf(
            report(45.0), report(48.0), report(50.0), report(52.0), report(400.0)
        )
        val estimate = CommunityPrice.estimate(reports, now = now)
        assertEquals(5_000, estimate?.cents, "median, not the 11900 mean")
    }

    @Test
    fun `it reports the full spread`() {
        val estimate = CommunityPrice.estimate(
            listOf(report(45.0), report(60.0), report(90.0)), now = now
        )
        assertEquals(4_500, estimate?.lowestCents)
        assertEquals(9_000, estimate?.highestCents)
    }

    /** It must never read as a manufacturer's figure or a valuation. */
    @Test
    fun `the source names itself as reports`() {
        val estimate = CommunityPrice.estimate(
            listOf(report(45.0), report(50.0), report(55.0)), now = now
        )
        assertEquals("3 shelf prices reported", estimate?.source)
        assertFalse(estimate?.source?.lowercase()?.contains("msrp") ?: true)
    }

    @Test
    fun `the caveat refuses the word valuation`() {
        val estimate = assertNotNull(
            CommunityPrice.estimate(
                listOf(report(45.0), report(50.0), report(55.0)), now = now
            )
        )
        assertTrue(estimate.caveat.contains("not a valuation"))
        assertTrue(estimate.caveat.contains("\$45.00"), estimate.caveat)
        assertTrue(estimate.caveat.contains("\$55.00"), estimate.caveat)
    }

    @Test
    fun `the reference carries the source through`() {
        val estimate = assertNotNull(
            CommunityPrice.estimate(
                listOf(report(45.0), report(50.0), report(55.0)), now = now
            )
        )
        assertEquals(estimate.cents, estimate.reference.cents)
        assertEquals(estimate.source, estimate.reference.source)
    }

    /**
     * A Kentucky shelf price is not a Virginia one, so a national median is a
     * number nobody recognises.
     */
    @Test
    fun `a regional figure is preferred`() {
        val reports = listOf(
            report(40.0, region = "KY"), report(42.0, region = "KY"),
            report(44.0, region = "KY"),
            report(90.0, region = "CA"), report(95.0, region = "CA"),
            report(99.0, region = "CA")
        )
        val local = assertNotNull(CommunityPrice.best(reports, preferring = "KY", now = now))
        assertEquals(4_200, local.cents)
        assertEquals("KY", local.region)
        assertTrue(local.source.contains("in KY"), local.source)
    }

    /**
     * Two local reports beaten by twenty national ones is still better than
     * showing nothing, and the source line says which you are looking at.
     */
    @Test
    fun `it falls back to everywhere when local is thin`() {
        val reports = listOf(
            report(40.0, region = "KY"),
            report(90.0, region = "CA"), report(95.0, region = "CA"),
            report(99.0, region = "CA")
        )
        val any = assertNotNull(CommunityPrice.best(reports, preferring = "KY", now = now))
        assertEquals(4, any.reportCount)
        assertNull(any.region, "fell back, and says so by not naming a region")
    }

    @Test
    fun `an unknown region still gets the national figure`() {
        val reports = listOf(
            report(50.0, region = "TX"), report(52.0, region = "TX"),
            report(54.0, region = "TX")
        )
        assertNotNull(CommunityPrice.best(reports, preferring = null, now = now))
    }

    private fun row(region: String?, isAll: Boolean = false, reports: Int, median: Int) =
        CommunityPrice.Aggregate(
            catalogProductId = "w12", region = region, isAll = isAll, reports = reports,
            medianCents = median, lowestCents = median - 500, highestCents = median + 500,
            oldestSeenAt = 1_700_000_000_000, latestSeenAt = 1_750_000_000_000
        )

    @Test
    fun `the region wins when it has enough reports`() {
        val rows = listOf(
            row("KY", reports = 5, median = 2999),
            row(null, isAll = true, reports = 40, median = 3499)
        )
        val best = CommunityPrice.bestOfAggregates(rows, preferring = "KY")
        assertEquals(2999, best?.cents)
        assertEquals("KY", best?.region)
        assertEquals("5 shelf prices reported in KY", best?.source)
    }

    @Test
    fun `too few local reports fall back to everywhere`() {
        val rows = listOf(
            row("KY", reports = 2, median = 2999),
            row(null, isAll = true, reports = 40, median = 3499)
        )
        val best = CommunityPrice.bestOfAggregates(rows, preferring = "KY")
        assertEquals(3499, best?.cents)
        assertNull(best?.region)
    }

    @Test
    fun `too few everywhere is nothing`() {
        assertNull(
            CommunityPrice.bestOfAggregates(
                listOf(row(null, isAll = true, reports = 2, median = 3499)),
                preferring = null
            )
        )
    }

    /**
     * Swift decodes the view's rows here with JSONDecoder. This module has no
     * JSON dependency, so the column names are pinned instead -- the two
     * engines have to agree on what the view is called, and the data layer
     * does the parsing.
     */
    @Test
    fun `the view's column names are pinned`() {
        assertEquals(
            listOf(
                "catalog_product_id", "region", "is_all", "reports",
                "median_cents", "lowest_cents", "highest_cents",
                "oldest_seen_at", "latest_seen_at"
            ),
            CommunityPrice.Aggregate.storageKeys
        )
    }
}
