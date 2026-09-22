package com.talastack.liquorlog.engine

import java.time.Instant
import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertFalse
import kotlin.test.assertNull
import kotlin.test.assertTrue

/**
 * The home tab's verdict. The case that matters most is the one a flat "do I
 * own this brand" lookup gets wrong: you have the line, but not this
 * release.
 */
class ShelfCheckTest {

    private fun product(id: String, brand: String, expression: String = "",
                        distillery: String = "Heaven Hill") =
        ProductIdentity(
            productId = id, distillery = distillery, brand = brand,
            expression = expression, classType = ClassType.KENTUCKY_STRAIGHT_BOURBON,
        )

    private val barrelProof = product("ecbp", "Elijah Craig", "Barrel Proof")
    private val smallBatch = product("ecsb", "Elijah Craig", "Small Batch")
    private val eighteen = product("ec18", "Elijah Craig", "18 Year")
    private val weller = product("weller-12", "W L Weller", "12 Year", distillery = "Buffalo Trace")

    private fun holding(id: String, of: ProductIdentity, open: Boolean = false,
                        finished: Boolean = false, sample: Boolean = false) =
        Holding(bottleId = id, product = of, isOpen = open,
                isFinished = finished, isSample = sample)

    private fun tasting(id: String, of: ProductIdentity, rating: Int? = null,
                        at: Instant = Instant.parse("2026-01-01T00:00:00Z")) =
        TastingRecord(tastingId = id, product = of, tastedAt = at, rating = rating)

    @Test
    fun `a bottle on the shelf says so`() {
        val result = ShelfCheck.evaluate(
            product = barrelProof,
            holdings = listOf(holding("b1", barrelProof, open = true)),
            tastings = emptyList(),
        )
        assertEquals(ShelfCheckResult.Headline.ON_YOUR_SHELF, result.headline)
        assertEquals(1, result.openBottleCount)
    }

    @Test
    fun `having the line but not this release is its own answer`() {
        // The whole reason this file exists: owning Small Batch does not mean
        // owning Barrel Proof, and a brand lookup would say it did.
        val result = ShelfCheck.evaluate(
            product = barrelProof,
            holdings = listOf(holding("b1", smallBatch)),
            tastings = emptyList(),
        )
        assertEquals(ShelfCheckResult.Headline.HAVE_THE_LINE_NOT_THIS_RELEASE, result.headline)
        assertEquals(listOf("ecsb"), result.sameLine.map { it.productId })
    }

    @Test
    fun `a different distillery is not the same line`() {
        val result = ShelfCheck.evaluate(
            product = barrelProof,
            holdings = listOf(holding("b1", weller)),
            tastings = emptyList(),
        )
        assertEquals(ShelfCheckResult.Headline.NEVER_HAD_IT, result.headline)
        assertTrue(result.sameLine.isEmpty())
    }

    @Test
    fun `a sample is not a bottle`() {
        // Owning a couple of ounces from a friend does not answer the aisle
        // question, which is whether to buy the bottle.
        val result = ShelfCheck.evaluate(
            product = barrelProof,
            holdings = listOf(holding("s1", barrelProof, sample = true)),
            tastings = emptyList(),
        )
        assertEquals(ShelfCheckResult.Headline.HAVE_A_SAMPLE, result.headline)
    }

    @Test
    fun `a bottle beside a sample is still a bottle`() {
        val result = ShelfCheck.evaluate(
            product = barrelProof,
            holdings = listOf(
                holding("s1", barrelProof, sample = true),
                holding("b1", barrelProof),
            ),
            tastings = emptyList(),
        )
        assertEquals(ShelfCheckResult.Headline.ON_YOUR_SHELF, result.headline)
    }

    @Test
    fun `a finished bottle is history, not stock`() {
        val result = ShelfCheck.evaluate(
            product = barrelProof,
            holdings = listOf(holding("b1", barrelProof, finished = true)),
            tastings = emptyList(),
        )
        assertEquals(ShelfCheckResult.Headline.HAD_IT_BEFORE, result.headline)
        assertTrue(result.onShelf.isEmpty())
        assertEquals(1, result.finished.size)
    }

    @Test
    fun `tasted at a bar and never owned is a real state`() {
        val result = ShelfCheck.evaluate(
            product = eighteen,
            holdings = emptyList(),
            tastings = listOf(tasting("t1", eighteen, rating = 9)),
        )
        assertEquals(ShelfCheckResult.Headline.TASTED_NEVER_OWNED, result.headline)
        assertEquals(9, result.bestRating)
    }

    @Test
    fun `ownership and tasting are independent, not a sequence`() {
        // The headline describes ownership only; the tasting travels with it
        // whatever the headline says.
        val result = ShelfCheck.evaluate(
            product = barrelProof,
            holdings = listOf(holding("b1", barrelProof)),
            tastings = listOf(tasting("t1", barrelProof, rating = 8)),
        )
        assertEquals(ShelfCheckResult.Headline.ON_YOUR_SHELF, result.headline)
        assertEquals(8, result.bestRating)
        assertEquals("t1", result.latestTasting?.tastingId)
    }

    @Test
    fun `the card leads with the most recent opinion, not the first`() {
        val result = ShelfCheck.evaluate(
            product = barrelProof,
            holdings = emptyList(),
            tastings = listOf(
                tasting("old", barrelProof, rating = 6, at = Instant.parse("2024-01-01T00:00:00Z")),
                tasting("new", barrelProof, rating = 9, at = Instant.parse("2026-06-01T00:00:00Z")),
            ),
        )
        assertEquals("new", result.latestTasting?.tastingId)
        assertEquals(9, result.bestRating, "best is the best, latest is the latest")
    }

    @Test
    fun `nothing at all is never had it`() {
        val result = ShelfCheck.evaluate(barrelProof, emptyList(), emptyList())
        assertEquals(ShelfCheckResult.Headline.NEVER_HAD_IT, result.headline)
        assertFalse(result.isOnWishlist)
        assertNull(result.latestTasting)
        assertNull(result.bestRating)
    }

    @Test
    fun `the wishlist is reported alongside the verdict`() {
        val result = ShelfCheck.evaluate(
            product = barrelProof, holdings = emptyList(), tastings = emptyList(),
            wishlistProductIds = setOf("ecbp"),
        )
        assertTrue(result.isOnWishlist)
    }

    @Test
    fun `the same line is deduplicated and ordered, so the card does not shuffle`() {
        val result = ShelfCheck.evaluate(
            product = barrelProof,
            holdings = listOf(holding("b1", smallBatch), holding("b2", smallBatch)),
            tastings = listOf(tasting("t1", eighteen)),
        )
        assertEquals(
            listOf("Elijah Craig 18 Year", "Elijah Craig Small Batch"),
            result.sameLine.map { it.displayName },
        )
    }

    @Test
    fun `a line key ignores the expression and a display name includes it`() {
        assertEquals(barrelProof.lineKey, smallBatch.lineKey)
        assertEquals("Elijah Craig Barrel Proof", barrelProof.displayName)
        assertEquals("Stagg", product("s", "Stagg").displayName, "no expression, just the brand")
    }
}
