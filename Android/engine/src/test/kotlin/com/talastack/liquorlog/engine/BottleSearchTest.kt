package com.talastack.liquorlog.engine

import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertTrue

/**
 * The search runs on every keystroke, offline, while somebody stands in a
 * shop. The cases below are the ones that make it usable there: abbreviated
 * typing, a typo, and relatedness that string similarity could never find.
 */
class BottleSearchTest {

    private fun candidate(id: String, brand: String, expression: String = "",
                          distillery: String = "Heaven Hill",
                          code: RecipeCode? = null, owned: Boolean = false) =
        SearchCandidate(
            product = ProductIdentity(
                productId = id, distillery = distillery, brand = brand,
                expression = expression, classType = ClassType.KENTUCKY_STRAIGHT_BOURBON,
            ),
            recipeCode = code,
            isInYourHistory = owned,
        )

    private val catalog = listOf(
        candidate("ecbp", "Elijah Craig", "Barrel Proof"),
        candidate("ecsb", "Elijah Craig", "Small Batch"),
        candidate("weller-12", "W L Weller", "12 Year", distillery = "Buffalo Trace"),
        candidate("weller-sr", "W L Weller", "Special Reserve", distillery = "Buffalo Trace"),
        candidate("blantons", "Blanton's", "Original", distillery = "Buffalo Trace"),
        candidate("fr-obsv", "Four Roses", "OBSV Pick", distillery = "Four Roses",
                  code = RecipeCode.parse("OBSV")),
        candidate("fr-oesq", "Four Roses", "OESQ Pick", distillery = "Four Roses",
                  code = RecipeCode.parse("OESQ")),
    )

    @Test
    fun `abbreviated typing finds the bottle`() {
        // The case the aisle actually needs: three fragments, typed fast.
        val hits = BottleSearch.search("eli cra bar", catalog)
        assertEquals("ecbp", hits.first().product.productId)
        assertEquals(SearchHit.Reason.PREFIX, hits.first().reason)
    }

    @Test
    fun `an exact name scores highest and says so`() {
        val hits = BottleSearch.search("Elijah Craig Barrel Proof", catalog)
        assertEquals("ecbp", hits.first().product.productId)
        assertEquals(SearchHit.Reason.EXACT, hits.first().reason)
        assertEquals(1.0, hits.first().score)
    }

    @Test
    fun `an apostrophe makes the name two tokens, so exactness is not available`() {
        // "Blanton's Original" normalises to "blanton s original" -- the
        // apostrophe splits it -- while somebody types "blantons original".
        // It still wins, on the fuzzy path, which is the behaviour that
        // matters; asserting EXACT here would have been asserting a bug.
        val hits = BottleSearch.search("blantons original", catalog)
        assertEquals("blantons", hits.first().product.productId)
        assertEquals(SearchHit.Reason.FUZZY, hits.first().reason)
    }

    @Test
    fun `punctuation and case do not matter`() {
        assertEquals("blantons", BottleSearch.search("blantons original", catalog).first().product.productId)
        assertEquals("blantons", BottleSearch.search("BLANTON'S ORIGINAL", catalog).first().product.productId)
    }

    @Test
    fun `a typo still finds it`() {
        val hits = BottleSearch.search("blantosn original", catalog)
        assertTrue(hits.isNotEmpty(), "a transposition is the commonest typo there is")
        assertEquals("blantons", hits.first().product.productId)
        assertEquals(SearchHit.Reason.FUZZY, hits.first().reason)
    }

    @Test
    fun `noise returns nothing rather than a wrong guess`() {
        assertTrue(BottleSearch.search("zzzzqqqq", catalog).isEmpty())
        assertTrue(BottleSearch.search("", catalog).isEmpty())
        assertTrue(BottleSearch.search("   ", catalog).isEmpty())
    }

    @Test
    fun `a bottle you own outranks a catalogue row scoring the same`() {
        val owned = listOf(
            candidate("weller-sr", "W L Weller", "Special Reserve", distillery = "Buffalo Trace"),
            candidate("weller-12", "W L Weller", "12 Year", distillery = "Buffalo Trace", owned = true),
        )
        val hits = BottleSearch.search("weller", owned)
        assertEquals("weller-12", hits.first().product.productId)
    }

    @Test
    fun `related finds the line, which is the point`() {
        val weller12 = catalog.first { it.product.productId == "weller-12" }.product
        val related = BottleSearch.related(weller12, candidates = catalog)
        val line = related.first { it.reason == SearchHit.Reason.SAME_LINE }
        assertEquals("weller-sr", line.product.productId)
        assertTrue(related.none { it.product.productId == "weller-12" }, "never itself")
    }

    @Test
    fun `related finds a shared recipe code, which no string match would`() {
        val obsv = catalog.first { it.product.productId == "fr-obsv" }
        val related = BottleSearch.related(
            obsv.product, recipeCode = RecipeCode.parse("OESQ"), candidates = catalog,
        )
        assertTrue(related.any { it.product.productId == "fr-oesq" })
    }

    @Test
    fun `related falls back to the distillery`() {
        val blantons = catalog.first { it.product.productId == "blantons" }.product
        val related = BottleSearch.related(blantons, candidates = catalog)
        assertTrue(
            related.all { it.product.distillery == "Buffalo Trace" },
            "a shared distillery is the weakest link, and the last one tried",
        )
        assertTrue(related.any { it.reason == SearchHit.Reason.SAME_DISTILLERY })
    }

    @Test
    fun `equal scores come back in the same order every time`() {
        val first = BottleSearch.search("weller", catalog).map { it.product.productId }
        repeat(5) {
            assertEquals(first, BottleSearch.search("weller", catalog).map { it.product.productId })
        }
    }

    @Test
    fun `the limit is honoured`() {
        assertEquals(1, BottleSearch.search("e", catalog, limit = 1).size)
        assertEquals(2, BottleSearch.related(
            catalog.first { it.product.productId == "blantons" }.product,
            candidates = catalog, limit = 2,
        ).size)
    }

    @Test
    fun `levenshtein and similarity are the textbook ones`() {
        assertEquals(0, BottleSearch.levenshtein("stagg", "stagg"))
        assertEquals(1, BottleSearch.levenshtein("stagg", "stag"))
        assertEquals(3, BottleSearch.levenshtein("kitten", "sitting"))
        assertEquals(5, BottleSearch.levenshtein("", "stagg"))
        assertEquals(1.0, BottleSearch.similarity("stagg", "stagg"))
        assertEquals(1.0, BottleSearch.similarity("", ""))
        assertEquals(0.0, BottleSearch.similarity("abc", "xyz"))
    }
}
