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
 * A pick beside its standard release. These pin the restraint: a row only
 * exists when both sides have something to say, and the difference is a
 * phrase about the numbers, never a judgement.
 */
class PickCompareTest {

    /**
     * A Four Roses OESQ store pick at barrel proof next to the 100-proof
     * shelf single barrel, which is OBSV.
     */
    private val fourRoses = PickCompare.compare(
        pick = PickCompare.Pick(
            abv = 58.7, ageMonths = 112, recipeCode = "OESQ", paidCents = 8_999, rating = 9
        ),
        standard = PickCompare.Standard(
            abv = 50.0, statedAgeYears = 7, recipeCode = "OBSV",
            priceCents = 4_999, priceLabel = "Virginia ABC", rating = 7
        )
    )

    private fun row(field: PickCompare.Field) =
        assertNotNull(fourRoses.rows.firstOrNull { it.field == field }, field.name)

    @Test
    fun `every row when both sides are known`() {
        assertEquals(
            listOf(
                PickCompare.Field.PROOF,
                PickCompare.Field.AGE,
                PickCompare.Field.RECIPE,
                PickCompare.Field.PRICE,
                PickCompare.Field.RATING
            ),
            fourRoses.rows.map { it.field }
        )
    }

    @Test
    fun `the proof row`() {
        val row = row(PickCompare.Field.PROOF)
        assertEquals("117.4", row.pick)
        assertEquals("100.0", row.standard)
        assertEquals("+17.4 proof", row.difference)
        assertEquals(17.4, row.delta ?: 0.0, 0.01)
    }

    @Test
    fun `the age row speaks in months for the pick`() {
        val row = row(PickCompare.Field.AGE)
        assertEquals("9 years 4 months", row.pick)
        assertEquals("7 years", row.standard)
        assertEquals("+2.3 years", row.difference)
    }

    @Test
    fun `the recipe row says what differs`() {
        val row = row(PickCompare.Field.RECIPE)
        // OESQ vs OBSV: E vs B mashbill, Q vs V yeast.
        assertEquals("different mashbill, different yeast", row.difference)
        assertNull(row.delta)
    }

    @Test
    fun `the price row`() {
        val row = row(PickCompare.Field.PRICE)
        assertEquals("\$89.99", row.pick)
        assertEquals("\$49.99 (Virginia ABC)", row.standard)
        assertEquals("\$40.00 more", row.difference)
    }

    @Test
    fun `the rating row`() {
        assertEquals("+2 for the pick", row(PickCompare.Field.RATING).difference)
    }

    /**
     * A pick with nothing recorded compares to nothing. "Unknown" beside a
     * number would read as a fact about the pick.
     */
    @Test
    fun `no row without both sides`() {
        val comparison = PickCompare.compare(
            pick = PickCompare.Pick(abv = 60.0),
            standard = PickCompare.Standard(statedAgeYears = 7, priceCents = 4_999)
        )
        assertTrue(comparison.isEmpty)
    }

    @Test
    fun `the same values say so`() {
        val comparison = PickCompare.compare(
            pick = PickCompare.Pick(
                abv = 50.0, ageMonths = 84, recipeCode = "obsv", paidCents = 4_999, rating = 7
            ),
            standard = PickCompare.Standard(
                abv = 50.0, statedAgeYears = 7, recipeCode = "OBSV",
                priceCents = 4_999, rating = 7
            )
        )
        assertEquals(
            listOf("same proof", "same age", "same recipe", "same price", "rated the same"),
            comparison.rows.map { it.difference }
        )
    }

    /**
     * Below the standard, the proof and age rows use the typographic minus
     * and the rating row carries the number's own hyphen. That asymmetry is
     * in the Swift source and is kept rather than tidied.
     */
    @Test
    fun `a pick below the standard`() {
        val comparison = PickCompare.compare(
            pick = PickCompare.Pick(abv = 45.0, ageMonths = 66, paidCents = 3_999, rating = 5),
            standard = PickCompare.Standard(
                abv = 50.0, statedAgeYears = 7, priceCents = 4_999, rating = 7
            )
        )
        assertEquals(
            listOf(
                "−10.0 proof",
                "−18 months",
                "\$10.00 less",
                "-2 for the pick"
            ),
            comparison.rows.map { it.difference }
        )
    }

    @Test
    fun `the same yeast with a different mashbill`() {
        val comparison = PickCompare.compare(
            pick = PickCompare.Pick(recipeCode = "OESV"),
            standard = PickCompare.Standard(recipeCode = "OBSV")
        )
        assertEquals("different mashbill", comparison.rows.first().difference)
    }

    @Test
    fun `non-Four-Roses recipes are just different`() {
        val comparison = PickCompare.compare(
            pick = PickCompare.Pick(recipeCode = "wheated"),
            standard = PickCompare.Standard(recipeCode = "rye")
        )
        assertEquals("different recipe", comparison.rows.first().difference)
    }

    @Test
    fun `the age description`() {
        assertEquals("11 months", AgeMath.describe(11))
        assertEquals("1 year", AgeMath.describe(12))
        assertEquals("1 year 1 month", AgeMath.describe(13))
        assertEquals("12 years 6 months", AgeMath.describe(150))
    }
}

/**
 * The walk has one job: be finishable. Every test here is about the order
 * the bottles come in, because that is the only thing standing between a
 * shelf walk and an abandoned list.
 */
class ReInventoryTest {

    private val now: Instant = Instant.EPOCH.plus(400, ChronoUnit.DAYS)

    private fun item(id: String, at: String? = null, verifiedDaysAgo: Int? = null) =
        ReInventory.Item(
            id = id,
            name = id,
            storageLocation = at,
            lastVerifiedAt = verifiedDaysAgo?.let { now.minus(it.toLong(), ChronoUnit.DAYS) }
        )

    /**
     * You are walking past shelves. A queue that sends you from the closet to
     * the basement and back is a queue nobody finishes.
     */
    @Test
    fun `bottles are grouped by where they are`() {
        val plan = ReInventory.plan(
            listOf(
                item("a", at = "closet", verifiedDaysAgo = 10),
                item("b", at = "basement", verifiedDaysAgo = 10),
                item("c", at = "closet", verifiedDaysAgo = 10)
            ),
            now
        )
        assertEquals(2, plan.size)
        val closet = plan.firstOrNull { it.location == "closet" }
        assertEquals(listOf("a", "c"), closet?.items?.map { it.id }?.sorted())
    }

    /**
     * The shelf you have not looked at in longest is the one worth walking
     * first, in case the walk stops early.
     */
    @Test
    fun `the stalest location comes first`() {
        val plan = ReInventory.plan(
            listOf(
                item("fresh", at = "bar top", verifiedDaysAgo = 5),
                item("stale", at = "basement", verifiedDaysAgo = 300)
            ),
            now
        )
        assertEquals("basement", plan.first().location)
    }

    @Test
    fun `the stalest bottle leads its own leg`() {
        val plan = ReInventory.plan(
            listOf(
                item("recent", at = "closet", verifiedDaysAgo = 3),
                item("old", at = "closet", verifiedDaysAgo = 200)
            ),
            now
        )
        assertEquals(listOf("old", "recent"), plan.first().items.map { it.id })
    }

    /** A bottle nobody has ever confirmed is the least trustworthy row there is. */
    @Test
    fun `never verified sorts above everything`() {
        val plan = ReInventory.plan(
            listOf(
                item("ancient", at = "closet", verifiedDaysAgo = 900),
                item("never", at = "closet", verifiedDaysAgo = null)
            ),
            now
        )
        assertEquals("never", plan.first().items.first().id)
    }

    /**
     * Bottles with no location are the ones you have to hunt for. Leading
     * with them is how a walk stalls on its first entry -- even though they
     * are, by staleness alone, the most urgent.
     */
    @Test
    fun `unplaced bottles go last despite being stalest`() {
        val plan = ReInventory.plan(
            listOf(
                item("homeless", at = null, verifiedDaysAgo = null),
                item("shelved", at = "closet", verifiedDaysAgo = 1)
            ),
            now
        )
        assertEquals(listOf("closet", null), plan.map { it.location })
        assertEquals("No location recorded", plan.last().title)
    }

    @Test
    fun `an empty collection plans nothing`() {
        assertTrue(ReInventory.plan(emptyList(), now).isEmpty())
    }

    /**
     * People do this once or twice a year. Nagging sooner trains them to
     * ignore it.
     */
    @Test
    fun `a walk is not due until something is six months stale`() {
        val recent = listOf(item("a", at = "closet", verifiedDaysAgo = 30))
        assertFalse(ReInventory.isDue(recent, now))

        val stale = listOf(item("a", at = "closet", verifiedDaysAgo = 200))
        assertTrue(ReInventory.isDue(stale, now))
    }

    @Test
    fun `an empty collection is never due`() {
        assertFalse(ReInventory.isDue(emptyList(), now))
    }

    @Test
    fun `never verified counts as due`() {
        assertTrue(ReInventory.isDue(listOf(item("a", verifiedDaysAgo = null)), now))
    }

    @Test
    fun `the outcome splits decisions three ways`() {
        val outcome = ReInventory.outcome(
            listOf(
                ReInventory.Decision("a", ReInventory.Verdict.PRESENT),
                ReInventory.Decision("b", ReInventory.Verdict.GONE),
                ReInventory.Decision("c", ReInventory.Verdict.SKIPPED)
            )
        )
        assertEquals(listOf("a"), outcome.confirmed)
        assertEquals(listOf("b"), outcome.gone)
        assertEquals(listOf("c"), outcome.skipped)
        assertEquals(2, outcome.checkedCount)
    }

    /** People change their mind halfway down a shelf. */
    @Test
    fun `the last decision on a bottle wins`() {
        val outcome = ReInventory.outcome(
            listOf(
                ReInventory.Decision("a", ReInventory.Verdict.GONE),
                ReInventory.Decision("a", ReInventory.Verdict.PRESENT)
            )
        )
        assertEquals(listOf("a"), outcome.confirmed)
        assertTrue(outcome.gone.isEmpty())
    }

    /**
     * Marking bottles finished is bookkeeping, not an achievement. Nothing in
     * this app is allowed to read as a score.
     */
    @Test
    fun `the summary does not celebrate`() {
        val outcome = ReInventory.outcome(
            listOf(
                ReInventory.Decision("a", ReInventory.Verdict.PRESENT),
                ReInventory.Decision("b", ReInventory.Verdict.GONE)
            )
        )
        assertEquals("1 still on the shelf, 1 marked finished.", outcome.summary)
    }

    @Test
    fun `an untouched walk says so`() {
        assertEquals("Nothing checked.", ReInventory.outcome(emptyList()).summary)
    }
}
