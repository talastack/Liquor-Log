package com.talastack.liquorlog.engine

import java.time.Instant
import java.time.temporal.ChronoUnit
import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertFalse
import kotlin.test.assertNotNull
import kotlin.test.assertNull
import kotlin.test.assertTrue

class CollectionValueTest {

    private fun holding(cents: Int?, finished: Boolean = false) =
        CollectionValue.Holding(purchasePriceCents = cents, isFinished = finished)

    @Test
    fun `the number is off until somebody asks for it`() {
        // Written down in exactly one place, because people are on record
        // saying they do not want to be shown it.
        assertFalse(CollectionValue.SHOWN_BY_DEFAULT)
    }

    @Test
    fun `it totals the shelf, not a lifetime of spending`() {
        val total = CollectionValue.onTheShelf(listOf(
            holding(6_999), holding(4_500),
            holding(12_000, finished = true),
        ))
        assertEquals(11_499, total.cents, "a killed bottle is not in the house")
        assertEquals(2, total.bottlesCounted)
    }

    @Test
    fun `an unpriced bottle makes the figure a floor, and it says so`() {
        val total = CollectionValue.onTheShelf(listOf(
            holding(6_999), holding(null), holding(null),
        ))
        assertEquals(6_999, total.cents)
        assertEquals(2, total.bottlesWithoutPrice)
        assertTrue(total.isPartial)
        assertEquals(
            "What you paid, not what it is worth. 2 bottles have no price recorded, " +
                "so the real figure is higher.",
            total.caveat,
        )
    }

    @Test
    fun `one unpriced bottle is said in the singular`() {
        val total = CollectionValue.onTheShelf(listOf(holding(6_999), holding(null)))
        assertTrue(total.caveat.contains("1 bottle has no price recorded"))
    }

    @Test
    fun `a fully priced shelf still refuses to be a valuation`() {
        val total = CollectionValue.onTheShelf(listOf(holding(6_999), holding(4_500)))
        assertFalse(total.isPartial)
        assertEquals("What you paid, not what it is worth.", total.caveat)
    }

    @Test
    fun `an empty shelf is zero, not an error`() {
        val total = CollectionValue.onTheShelf(emptyList())
        assertEquals(0, total.cents)
        assertFalse(total.isPartial)
    }
}

class TastingTrendTest {

    private val start = Instant.parse("2026-01-01T00:00:00Z")

    private fun point(dayOffset: Long, rating: Int, daysOpen: Int? = null) =
        TastingTrend.Point(
            tastedAt = start.plus(dayOffset, ChronoUnit.DAYS),
            rating = rating,
            daysOpen = daysOpen,
        )

    @Test
    fun `one tasting is not a trend`() {
        assertNull(TastingTrend.summarise(emptyList()))
        assertNull(TastingTrend.summarise(listOf(point(0, 8))))
    }

    @Test
    fun `a rating climbing two points has opened up`() {
        val summary = TastingTrend.summarise(listOf(point(0, 6), point(40, 8)))
        assertNotNull(summary)
        assertEquals(TastingTrend.Direction.OPENED_UP, summary.direction)
        assertEquals(6, summary.firstRating)
        assertEquals(8, summary.latestRating)
        assertEquals(40, summary.spanDays)
        assertEquals("Opened up: 6 to 8 over 40 days.", summary.text)
    }

    @Test
    fun `one point is the noise of a different evening`() {
        val summary = TastingTrend.summarise(listOf(point(0, 7), point(30, 8)))
        assertNotNull(summary)
        assertEquals(TastingTrend.Direction.HOLDING, summary.direction)
        assertEquals("Holding around 8 across 2 tastings over 30 days.", summary.text)
    }

    @Test
    fun `a rating falling two points is fading`() {
        val summary = TastingTrend.summarise(listOf(point(0, 9), point(200, 6)))
        assertNotNull(summary)
        assertEquals(TastingTrend.Direction.FADING, summary.direction)
        assertEquals("Fading: 9 to 6 over 200 days.", summary.text)
    }

    @Test
    fun `days open is preferred to the span between tastings`() {
        // How long the bottle has been open is the thing that explains a
        // change; how long since the last tasting is not.
        val summary = TastingTrend.summarise(listOf(
            point(0, 6, daysOpen = 3),
            point(40, 8, daysOpen = 90),
        ))
        assertNotNull(summary)
        assertEquals("Opened up: 6 to 8 over 90 days open.", summary.text)
    }

    @Test
    fun `an unchanged rating holds at its number`() {
        val summary = TastingTrend.summarise(listOf(point(0, 8), point(10, 8), point(20, 8)))
        assertNotNull(summary)
        assertEquals("Holding at 8 across 3 tastings over 20 days.", summary.text)
        assertEquals(3, summary.tastingCount)
    }

    @Test
    fun `two tastings on one evening say so rather than 'over 0 days'`() {
        val summary = TastingTrend.summarise(listOf(point(0, 7), point(0, 8)))
        assertNotNull(summary)
        assertEquals(0, summary.spanDays)
        assertTrue(summary.text.endsWith("on the same day."), summary.text)
    }

    @Test
    fun `order of the input does not matter, only the dates do`() {
        val forwards = TastingTrend.summarise(listOf(point(0, 6), point(40, 9)))
        val backwards = TastingTrend.summarise(listOf(point(40, 9), point(0, 6)))
        assertEquals(forwards, backwards)
    }

    @Test
    fun `a single day is said in the singular`() {
        val summary = TastingTrend.summarise(listOf(point(0, 6), point(1, 9)))
        assertNotNull(summary)
        assertEquals("Opened up: 6 to 9 over 1 day.", summary.text)
    }
}
