package com.talastack.liquorlog.engine

import java.time.Instant
import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertNotNull
import kotlin.test.assertNull
import kotlin.test.assertTrue

/** Ten staves of five kinds. A recipe that does not total ten is a typo. */
class StaveRecipeTest {

    @Test
    fun `the label's compact form`() {
        val recipe = assertNotNull(StaveRecipe.parse("P2×3 Cu×2 46×2 Mo×1 Sp×2"))
        assertEquals(3, recipe.count(StaveRecipe.Stave.BAKED_AMERICAN_PURE_2))
        assertEquals(1, recipe.count(StaveRecipe.Stave.ROASTED_FRENCH_MOCHA))
        assertEquals("P2×3 Cu×2 46×2 Mo×1 Sp×2", recipe.code)
    }

    @Test
    fun `loose spellings read`() {
        assertEquals(
            StaveRecipe.parse("P2×3 Cu×2 46×2 Mo×1 Sp×2"),
            StaveRecipe.parse("p2x3, cu x 2, 46x2, mo x1, sp x2")
        )
        val all46 = assertNotNull(StaveRecipe.parse("46x10"))
        assertEquals("46×10", all46.code)
    }

    @Test
    fun `it must total ten`() {
        assertNull(StaveRecipe.parse("P2×3 Cu×2"))
        assertNull(StaveRecipe.parse("P2×11"))
        assertNull(
            StaveRecipe.of(
                mapOf(
                    StaveRecipe.Stave.MAKERS_46 to 5,
                    StaveRecipe.Stave.ROASTED_FRENCH_MOCHA to 6
                )
            )
        )
        assertNull(StaveRecipe.parse(""))
    }

    @Test
    fun `zeros are dropped`() {
        val recipe = assertNotNull(
            StaveRecipe.of(
                mapOf(
                    StaveRecipe.Stave.MAKERS_46 to 10,
                    StaveRecipe.Stave.TOASTED_FRENCH_SPICE to 0
                )
            )
        )
        assertEquals(1, recipe.counts.size)
    }

    @Test
    fun `leaning`() {
        assertTrue(assertNotNull(StaveRecipe.parse("46x10")).leaning.startsWith("All Maker's 46"))
        val spread = assertNotNull(
            StaveRecipe.parse("P2×3 Cu×2 46×2 Mo×1 Sp×2")
        )
        assertTrue(spread.leaning.startsWith("Led by Baked American Pure 2 (3 of 10)"), spread.leaning)
        val tie = assertNotNull(StaveRecipe.parse("Mo×5 Sp×5"))
        assertTrue(
            tie.leaning.startsWith("Led equally by Roasted French Mocha and Toasted French Spice"),
            tie.leaning
        )
    }

    @Test
    fun `comparison`() {
        val mine = assertNotNull(StaveRecipe.parse("P2×3 Cu×2 46×2 Mo×3"))
        val theirs = assertNotNull(
            StaveRecipe.parse("P2×3 Cu×2 46×2 Mo×1 Sp×2")
        )
        val comparison = StaveRecipe.compare(mine, theirs)
        assertEquals(
            listOf(
                StaveRecipe.Stave.BAKED_AMERICAN_PURE_2,
                StaveRecipe.Stave.SEARED_FRENCH_CUVEE,
                StaveRecipe.Stave.MAKERS_46,
                StaveRecipe.Stave.ROASTED_FRENCH_MOCHA
            ),
            comparison.shared
        )
        assertEquals(StaveRecipe.Stave.ROASTED_FRENCH_MOCHA, comparison.moreInFirst.first().first)
        assertEquals(2, comparison.moreInFirst.first().second)
        assertEquals(StaveRecipe.Stave.TOASTED_FRENCH_SPICE, comparison.moreInSecond.first().first)
        assertEquals(
            "The first leans more to Roasted French Mocha (+2); " +
                "the second to Toasted French Spice (+2).",
            comparison.text
        )
        assertTrue(StaveRecipe.compare(mine, mine).isIdentical)
    }
}

/** A line, expression by expression, as a fact and never a score. */
class LineViewTest {

    private fun ec(id: String, expression: String) = ProductIdentity(
        productId = id, distillery = "Heaven Hill", brand = "Elijah Craig",
        expression = expression, classType = ClassType.KENTUCKY_STRAIGHT_BOURBON,
        productionType = ProductionType.SMALL_BATCH
    )

    private val smallBatch = ec("ec-sb", "Small Batch")
    private val barrelProof = ec("ec-bp", "Barrel Proof")
    private val eighteen = ec("ec-18", "18 Year")
    private val weller = ProductIdentity(
        productId = "weller-sr", distillery = "Buffalo Trace", brand = "W L Weller",
        expression = "Special Reserve", classType = ClassType.KENTUCKY_STRAIGHT_BOURBON,
        productionType = ProductionType.UNSPECIFIED
    )

    private val now: Instant = Instant.parse("2026-09-21T12:00:00Z")

    @Test
    fun `every expression of the line, with a standing`() {
        val line = LineView.line(
            product = barrelProof,
            catalogue = listOf(smallBatch, barrelProof, eighteen, weller),
            holdings = listOf(
                Holding(bottleId = "1", product = smallBatch, isOpen = true, isFinished = false),
                Holding(bottleId = "2", product = barrelProof, isOpen = false, isFinished = true)
            ),
            tastings = listOf(
                TastingRecord(tastingId = "t", product = eighteen, tastedAt = now)
            )
        )
        assertEquals("Elijah Craig", line.brand)
        assertEquals(listOf("ec-sb", "ec-bp", "ec-18"), line.rows.map { it.product.productId })
        assertEquals(
            listOf(
                LineView.Standing.ON_SHELF,
                LineView.Standing.HAD_IT_BEFORE,
                LineView.Standing.TASTED_ONLY
            ),
            line.rows.map { it.standing }
        )
    }

    @Test
    fun `on the shelf outranks had it`() {
        val line = LineView.line(
            product = smallBatch,
            catalogue = listOf(smallBatch),
            holdings = listOf(
                Holding(bottleId = "1", product = smallBatch, isOpen = false, isFinished = true),
                Holding(bottleId = "2", product = smallBatch, isOpen = false, isFinished = false)
            ),
            tastings = emptyList()
        )
        assertEquals(LineView.Standing.ON_SHELF, line.rows.first().standing)
    }

    @Test
    fun `the other line is left out`() {
        val line = LineView.line(
            product = weller, catalogue = listOf(smallBatch, weller),
            holdings = emptyList(), tastings = emptyList()
        )
        assertEquals(listOf("weller-sr"), line.rows.map { it.product.productId })
        assertEquals(LineView.Standing.NEVER, line.rows.first().standing)
    }

    /**
     * A sample of an expression is its own standing: not owned, not
     * history, on hand tonight.
     */
    @Test
    fun `a sample is its own standing`() {
        val product = ProductIdentity(
            productId = "w12", distillery = "Buffalo Trace", brand = "W. L. Weller",
            expression = "12 Year", classType = ClassType.KENTUCKY_STRAIGHT_BOURBON,
            productionType = ProductionType.UNSPECIFIED
        )
        val line = LineView.line(
            product = product, catalogue = listOf(product),
            holdings = listOf(Holding(bottleId = "s", product = product, isSample = true)),
            tastings = emptyList()
        )
        assertEquals(listOf(LineView.Standing.SAMPLE), line.rows.map { it.standing })
    }

    private fun expression(id: String, name: String, brand: String = "W. L. Weller") =
        ProductIdentity(
            productId = id, distillery = "Buffalo Trace", brand = brand, expression = name,
            classType = ClassType.KENTUCKY_STRAIGHT_BOURBON,
            productionType = ProductionType.UNSPECIFIED
        )

    /**
     * A count of bottles against what the catalogue lists, never a goal.
     * Owned, sampled and finished count; a tasting at a bar does not.
     */
    @Test
    fun `the line counts bottles against the catalogue`() {
        val sr = expression("sr", "Special Reserve")
        val antique = expression("antique", "Antique 107")
        val twelve = expression("12", "12 Year")
        val full = expression("full", "Full Proof")
        val line = LineView.line(
            product = sr, catalogue = listOf(sr, antique, twelve, full),
            holdings = listOf(
                Holding(bottleId = "b", product = sr),
                Holding(bottleId = "s", product = antique, isSample = true),
                Holding(bottleId = "f", product = twelve, isFinished = true)
            ),
            tastings = listOf(
                TastingRecord(tastingId = "t", product = full, tastedAt = now, rating = 8)
            )
        )
        assertEquals(3, line.hadCount, "the tasting of Full Proof is a drink, not a bottle")
        assertEquals(
            "3 of the 4 releases the catalogue lists have been on your shelf.",
            line.completionLine
        )
        assertEquals(emptyList(), line.notYet.map { it.productId })
    }

    @Test
    fun `all and none read as such`() {
        val a = expression("a", "A")
        val b = expression("b", "B")
        val all = LineView.line(
            product = a, catalogue = listOf(a, b),
            holdings = listOf(
                Holding(bottleId = "1", product = a),
                Holding(bottleId = "2", product = b)
            ),
            tastings = emptyList()
        )
        assertEquals(
            "All 2 releases the catalogue lists have been on your shelf.",
            all.completionLine
        )
        val none = LineView.line(
            product = a, catalogue = listOf(a, b),
            holdings = emptyList(), tastings = emptyList()
        )
        assertEquals(
            "None of the 2 releases the catalogue lists has been on your shelf yet.",
            none.completionLine
        )
    }

    @Test
    fun `a line of one says nothing about completion`() {
        val a = expression("a", "A")
        val line = LineView.line(
            product = a, catalogue = listOf(a),
            holdings = listOf(Holding(bottleId = "1", product = a)),
            tastings = emptyList()
        )
        assertNull(line.completionLine)
    }

    @Test
    fun `completions list every line you have something of, most complete first`() {
        val w1 = expression("w1", "Special Reserve")
        val w2 = expression("w2", "Antique")
        val w3 = expression("w3", "12")
        val s1 = expression("s1", "Jr", brand = "Stagg")
        val s2 = expression("s2", "Sr", brand = "Stagg")
        val lone = expression("l", "", brand = "Lonely")
        val e1 = expression("e1", "Small Batch", brand = "Elijah Craig")
        val e2 = expression("e2", "18", brand = "Elijah Craig")
        val completions = LineView.completions(
            catalogue = listOf(w1, w2, w3, s1, s2, lone, e1, e2),
            holdings = listOf(
                Holding(bottleId = "a", product = w1),
                Holding(bottleId = "b", product = w2),
                Holding(bottleId = "c", product = s1),
                Holding(bottleId = "d", product = s2),
                Holding(bottleId = "e", product = lone)
            )
        )
        assertEquals(listOf("Stagg", "W. L. Weller"), completions.map { it.brand })
        assertEquals(listOf(2, 2), completions.map { it.had })
        assertEquals(listOf(2, 3), completions.map { it.total })
    }
}
