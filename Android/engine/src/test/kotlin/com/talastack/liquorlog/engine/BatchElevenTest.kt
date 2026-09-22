package com.talastack.liquorlog.engine

import java.time.Instant
import java.time.temporal.ChronoUnit
import kotlin.random.Random
import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertFalse
import kotlin.test.assertNotNull
import kotlin.test.assertNull
import kotlin.test.assertTrue

/**
 * Suggestions with their reasons on the screen, from what you rated
 * well, never from what you already have.
 */
class TryNextTest {

    private fun product(id: String, distillery: String, brand: String, expression: String) =
        ProductIdentity(
            productId = id, distillery = distillery, brand = brand, expression = expression,
            classType = ClassType.KENTUCKY_STRAIGHT_BOURBON,
            productionType = ProductionType.UNSPECIFIED
        )

    private val w12 = product("w12", "Buffalo Trace", "W. L. Weller", "12 Year")
    private val wsr = product("wsr", "Buffalo Trace", "W. L. Weller", "Special Reserve")
    private val antique = product("antique", "Buffalo Trace", "W. L. Weller", "Antique 107")
    private val eagle = product("eagle", "Buffalo Trace", "Eagle Rare", "10 Year")
    private val makers = product("makers", "Maker's Mark", "Maker's Mark", "")
    private val ecbp = product("ecbp", "Heaven Hill", "Elijah Craig", "Barrel Proof")

    private val catalogue = listOf(
        SearchCandidate(product = w12, mashbillKey = "wheated"),
        SearchCandidate(product = wsr, mashbillKey = "wheated"),
        SearchCandidate(product = antique, mashbillKey = "wheated"),
        SearchCandidate(product = eagle),
        SearchCandidate(product = makers, mashbillKey = "wheated"),
        SearchCandidate(product = ecbp)
    )

    @Test
    fun `the line comes first, then mashbill, then distillery, and each says why`() {
        val suggestions = TryNext.suggest(
            liked = listOf(TryNext.Liked(product = w12, rating = 9, mashbillKey = "wheated")),
            catalogue = catalogue, had = setOf("w12")
        )
        assertEquals(
            listOf("antique", "wsr", "makers", "eagle"),
            suggestions.map { it.product.productId }
        )
        assertEquals(
            "Same line as W. L. Weller 12 Year, which you rated 9.",
            suggestions.first().why
        )
        assertEquals(SearchHit.Reason.SAME_DISTILLERY, suggestions.last().reason)
        assertEquals(
            SearchHit.Reason.SAME_RECIPE, suggestions[2].reason,
            "a shared mashbill reads as the same recipe"
        )
    }

    @Test
    fun `what you have had is not a suggestion`() {
        val suggestions = TryNext.suggest(
            liked = listOf(TryNext.Liked(product = w12, rating = 9)),
            catalogue = catalogue, had = setOf("w12", "wsr", "antique")
        )
        assertEquals(listOf("eagle"), suggestions.map { it.product.productId })
    }

    @Test
    fun `only bottles rated well are sources`() {
        val suggestions = TryNext.suggest(
            liked = listOf(TryNext.Liked(product = w12, rating = 5)),
            catalogue = catalogue, had = emptySet()
        )
        assertTrue(suggestions.isEmpty())
    }

    /**
     * A product reachable from two of your bottles is listed once, under
     * the better-rated one.
     */
    @Test
    fun `a product is suggested once, under the higher rating`() {
        val suggestions = TryNext.suggest(
            liked = listOf(
                TryNext.Liked(product = eagle, rating = 7),
                TryNext.Liked(product = w12, rating = 9)
            ),
            catalogue = catalogue, had = setOf("eagle", "w12")
        )
        val fromWeller = suggestions.firstOrNull { it.product.productId == "wsr" }
        assertEquals("w12", fromWeller?.because?.productId)
        assertEquals(1, suggestions.count { it.product.productId == "wsr" })
    }

    @Test
    fun `the limit holds`() {
        val suggestions = TryNext.suggest(
            liked = listOf(TryNext.Liked(product = w12, rating = 9, mashbillKey = "wheated")),
            catalogue = catalogue, had = setOf("w12"), limit = 2
        )
        assertEquals(2, suggestions.size)
    }
}

/** Weighted toward neglect, and it always says why. */
class PickMyPourTest {

    private val now: Instant = Instant.EPOCH.plus(365, ChronoUnit.DAYS)

    private fun candidate(
        id: String, daysAgo: Int?, open: Boolean = true, remaining: Double = 500.0
    ) = PickMyPour.Candidate(
        id = id,
        name = id,
        lastPouredAt = daysAgo?.let { Instant.EPOCH.plus((365 - it).toLong(), ChronoUnit.DAYS) },
        isOpen = open,
        remainingMilliliters = remaining
    )

    /**
     * Opening a sealed bottle starts an oxidation clock and is often the whole
     * point of the bottle. The app should not make that call for somebody.
     */
    @Test
    fun `sealed bottles are never suggested`() {
        val pool = listOf(
            candidate("sealed", daysAgo = null, open = false),
            candidate("open", daysAgo = 10)
        )
        assertEquals(listOf("open"), PickMyPour.eligible(pool).map { it.id })
    }

    @Test
    fun `empty bottles are never suggested`() {
        val pool = listOf(candidate("empty", daysAgo = 5, remaining = 0.0))
        assertTrue(PickMyPour.eligible(pool).isEmpty())
    }

    @Test
    fun `nothing eligible returns null`() {
        assertNull(PickMyPour.choose(emptyList(), now, Random(1)))
        val sealed = listOf(candidate("s", daysAgo = null, open = false))
        assertNull(PickMyPour.choose(sealed, now, Random(1)))
    }

    /** An open bottle you have never tasted is the one most worth a nudge. */
    @Test
    fun `never poured carries the strongest weight`() {
        val never = candidate("never", daysAgo = null)
        val yesterday = candidate("recent", daysAgo = 1)
        assertTrue(PickMyPour.weight(never, now) > PickMyPour.weight(yesterday, now))
    }

    @Test
    fun `neglect raises the weight`() {
        val old = candidate("old", daysAgo = 200)
        val recent = candidate("recent", daysAgo = 3)
        assertTrue(PickMyPour.weight(old, now) > PickMyPour.weight(recent, now))
    }

    /**
     * Without a cap one forgotten bottle wins every time and the feature stops
     * being a surprise.
     */
    @Test
    fun `neglect is capped so one bottle cannot always win`() {
        val ancient = candidate("ancient", daysAgo = 700)
        assertEquals(PickMyPour.neglectCapDays, PickMyPour.weight(ancient, now), 0.001)
    }

    /**
     * A bottle poured yesterday still has to be reachable, or the suggestion
     * becomes predictable and people stop tapping it.
     */
    @Test
    fun `even a recent pour keeps a floor`() {
        assertTrue(PickMyPour.weight(candidate("today", daysAgo = 0), now) >= 1.0)
    }

    @Test
    fun `a single eligible bottle is always the answer`() {
        val only = listOf(
            candidate("only", daysAgo = 30),
            candidate("sealed", daysAgo = null, open = false)
        )
        assertEquals("only", PickMyPour.choose(only, now, Random(7))?.candidate?.id)
    }

    /**
     * A random pick with no reason feels arbitrary. A reason makes it a
     * suggestion.
     */
    @Test
    fun `every choice explains itself`() {
        for (days in listOf(0, 10, 60, 200, 400)) {
            val pool = listOf(candidate("x", daysAgo = days))
            val choice = assertNotNull(PickMyPour.choose(pool, now, Random(days)))
            assertFalse(choice.reason.isEmpty())
        }
        val never = listOf(candidate("n", daysAgo = null))
        assertTrue(
            PickMyPour.choose(never, now, Random(3))!!.reason.contains("not poured from it yet")
        )
    }
}
