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
 * The paywall, and mostly what must never be behind it.
 *
 * These are not structural tests. Each one pins a decision the research is
 * explicit about, so that a future "let's gate one more thing" has to argue
 * with a failing test rather than slip through a diff.
 */
class EntitlementTest {

    /**
     * `displayOrder` is a list, so the compiler cannot catch a feature missing
     * from it -- which is precisely how something ends up gated in code and
     * absent from the comparison table.
     */
    @Test
    fun `displayOrder covers every feature exactly once`() {
        assertEquals(
            Feature.entries.toSet(),
            Entitlement.displayOrder.toSet(),
            "a Feature is missing from displayOrder, or listed twice"
        )
        assertEquals(
            Feature.entries.size,
            Entitlement.displayOrder.size,
            "displayOrder contains a duplicate"
        )
    }

    @Test
    fun `every feature has a label`() {
        for (feature in Feature.entries) {
            assertFalse(
                Entitlement.title(feature).isEmpty(),
                "$feature would render as a blank row"
            )
        }
    }

    @Test
    fun `pro has everything`() {
        for (feature in Feature.entries) {
            assertTrue(Entitlement.isAvailable(feature, Tier.PRO), "$feature gated from pro")
        }
    }

    /**
     * *"Never charge for export. It costs you almost nothing and it is the
     * single strongest trust signal in a category where people have been
     * burned."* Paywalling it is named as a reason people left OnlyDrams.
     */
    @Test
    fun `export is free forever`() {
        assertTrue(Entitlement.isAvailable(Feature.CSV_EXPORT, Tier.FREE))
    }

    /**
     * You cannot out-free a free incumbent, and the threshold for needing this
     * app at all is about fifty bottles -- so a cap locks out the people it is
     * for. The first version of this file capped free at 25.
     */
    @Test
    fun `bottles are unlimited on every tier`() {
        for (tier in Tier.entries) {
            assertNull(
                Entitlement.bottleLimit(tier),
                "$tier has a bottle cap; free unlimited is the price of entry here"
            )
        }
    }

    /**
     * The home tab. An app that will not say whether you own the bottle in
     * your hand is not worth installing to find out.
     */
    @Test
    fun `the shelf check is free`() {
        assertTrue(Entitlement.isAvailable(Feature.SHELF_CHECK, Tier.FREE))
    }

    /**
     * The wedge. Gating it hides the only reason to choose this over a free
     * incumbent that already has 56,000 bottles catalogued.
     */
    @Test
    fun `the barrel fields are free`() {
        assertTrue(Entitlement.isAvailable(Feature.BARREL_DETAIL, Tier.FREE))
        assertTrue(Entitlement.isAvailable(Feature.PICK_COMPARE, Tier.FREE))
    }

    /**
     * A differentiator nobody can discover is not a differentiator. Section 6
     * calls the oxidation clock "wide open" -- essentially no app has it.
     */
    @Test
    fun `the differentiators are free`() {
        assertTrue(Entitlement.isAvailable(Feature.OXIDATION_TRACKING, Tier.FREE))
        assertTrue(Entitlement.isAvailable(Feature.PERCEIVED_PROOF, Tier.FREE))
        assertTrue(Entitlement.isAvailable(Feature.FILL_LEVEL, Tier.FREE))
    }

    /**
     * The price check runs on prices the user recorded, and the knowledge base
     * is their own writing. Charging for either is charging for their own data
     * back, which is the same move as paywalling export.
     */
    @Test
    fun `your own data is never behind the paywall`() {
        assertTrue(Entitlement.isAvailable(Feature.PRICE_CHECK, Tier.FREE))
        assertTrue(Entitlement.isAvailable(Feature.KNOWLEDGE_BASE, Tier.FREE))
        assertTrue(Entitlement.isAvailable(Feature.TASTING_NOTES, Tier.FREE))
        assertTrue(Entitlement.isAvailable(Feature.BOTTLE_COLLECTION, Tier.FREE))
    }

    /**
     * Scanning behind a paywall is cited by name for Distiller and Vivino:
     * *"Putting the scanning behind a pay wall is kind of lame."*
     */
    @Test
    fun `scanning is free`() {
        assertTrue(Entitlement.isAvailable(Feature.LABEL_SCANNING, Tier.FREE))
    }

    /**
     * The whole of Pro, and the test that keeps it honest: every paid feature
     * must be a SERVICE with an ongoing cost, never a piece of the user's own
     * data withheld.
     */
    @Test
    fun `every paid feature is a service and says why`() {
        val paid = Feature.entries.filter { !Entitlement.isAvailable(it, Tier.FREE) }

        assertEquals(
            setOf(Feature.CLOUD_SYNC, Feature.INSURANCE_REPORT, Feature.HOSTED_MENU),
            paid.toSet(),
            "the paid list changed -- is the new one a service, or somebody's own data?"
        )

        for (feature in paid) {
            assertNotNull(
                Entitlement.reason(feature),
                "$feature is charged for with no stated reason"
            )
        }
    }

    @Test
    fun `free features give no reason to pay`() {
        for (feature in Feature.entries) {
            if (!Entitlement.isAvailable(feature, Tier.FREE)) continue
            assertNull(
                Entitlement.reason(feature),
                "$feature is free but carries paywall copy"
            )
        }
    }

    /**
     * Most of the app is free, and by a wide margin. If this ever fails,
     * something has been quietly moved behind the paywall.
     */
    @Test
    fun `the overwhelming majority of the app is free`() {
        val free = Feature.entries.filter { Entitlement.isAvailable(it, Tier.FREE) }
        assertTrue(
            free.size.toDouble() / Feature.entries.size.toDouble() > 0.8,
            "less than four fifths of the app is free"
        )
    }

    /** The storage keys are what a stored tier or feature string has to keep saying. */
    @Test
    fun `the storage keys match the Swift raw values`() {
        assertEquals(listOf("free", "pro"), Tier.entries.map { it.storageKey })
        assertEquals("shelfCheck", Feature.SHELF_CHECK.storageKey)
        assertEquals("csvExport", Feature.CSV_EXPORT.storageKey)
        assertEquals("hostedMenu", Feature.HOSTED_MENU.storageKey)
        assertEquals(
            Feature.entries.size, Feature.entries.map { it.storageKey }.toSet().size,
            "two features share a storage key"
        )
    }
}

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
