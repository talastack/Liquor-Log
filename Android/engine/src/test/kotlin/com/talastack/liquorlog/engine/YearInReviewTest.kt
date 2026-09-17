package com.talastack.liquorlog.engine

import java.time.Instant
import java.time.ZoneId
import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertNotNull
import kotlin.test.assertNull

/**
 * A year in sentences, from the record: bottles, tastings, words, people and
 * stores. Nothing about pours or bottles emptied.
 */
class YearInReviewTest {

    private val utc: ZoneId = ZoneId.of("UTC")
    private fun day(y: Int, m: Int, d: Int): Instant =
        Instant.parse(String.format("%04d-%02d-%02dT12:00:00Z", y, m, d))

    private val facts = YearInReview.Facts(
        added = listOf(
            YearInReview.Added("Weller 12", "Kentucky Straight Bourbon", "Buffalo Trace", 3_999, day(2026, 1, 3)),
            YearInReview.Added("Stagg", "Kentucky Straight Bourbon", "Buffalo Trace", null, day(2026, 4, 9)),
            YearInReview.Added("Four Roses Small Batch", "Kentucky Straight Bourbon", "Four Roses", 3_499, day(2026, 6, 1)),
            YearInReview.Added("Rittenhouse", "Straight Rye", "Heaven Hill", 2_799, day(2026, 8, 20)),
            YearInReview.Added("Last year's bottle", null, "Old Forester", 5_000, day(2025, 12, 30)),
        ),
        opened = listOf(day(2026, 1, 5), day(2026, 7, 4), day(2025, 3, 3)),
        tastings = listOf(
            YearInReview.Tasted("Weller 12", 8, day(2026, 1, 6), listOf("caramel", "oak", "caramel")),
            YearInReview.Tasted("Stagg", 9, day(2026, 4, 10), listOf("caramel", "cherry")),
            YearInReview.Tasted("Rittenhouse", null, day(2026, 8, 21), listOf("rye-spice")),
        ),
        samples = listOf(
            YearInReview.Sample("mike", day(2026, 2, 2)),
            YearInReview.Sample("Mike", day(2026, 3, 3)),
            YearInReview.Sample("Sarah", day(2026, 5, 5)),
        ),
        sightings = listOf(
            YearInReview.Sighted("Total Wine", day(2026, 2, 1)),
            YearInReview.Sighted("Total Wine", day(2026, 3, 1)),
            YearInReview.Sighted("Liquor Barn", day(2026, 3, 2)),
        ),
        lotteries = listOf(
            YearInReview.Lottery(false, day(2026, 3, 1)),
            YearInReview.Lottery(true, day(2026, 9, 1)),
            YearInReview.Lottery(null, day(2026, 9, 2)),
        ),
    )

    @Test
    fun `the year in sentences`() {
        val review = YearInReview.review(
            facts, year = 2026,
            words = { if (it == "caramel") "Caramel" else it },
            zone = utc,
        )
        assertNotNull(review)
        assertEquals(
            listOf(
                "4 bottles added, from 3 distilleries. Buffalo Trace most, 2 times.",
                "Mostly kentucky straight bourbon: 3 of them.",
                "First of the year: Weller 12, 3 January.",
                "3 tastings written. Highest: Stagg, 9/10.",
                "The word you reached for most: Caramel, 2 times.",
                "3 samples from Sarah, Mike.",
                "3 sightings at 2 stores; Total Wine most.",
                "3 lotteries entered, 1 won.",
            ),
            review.lines,
        )
        assertEquals("$102.97 across the 3 with a price.", review.moneyLine)
        assertEquals(4, review.bottlesAdded, "last year's bottle is last year's")
        assertEquals(
            YearInReview.Count("Caramel", 2), review.wordOfTheYear,
            "once per tasting, not three times",
        )
        assertEquals(listOf("Sarah", "Mike"), review.sampleSenders, "newest first, one Mike")
    }

    @Test
    fun `bottles opened is counted but never said`() {
        // On a card that gets shared it reads as a tally of drinking, which
        // is the one thing this must never be.
        val review = YearInReview.review(facts, year = 2026, zone = utc)
        assertNotNull(review)
        assertEquals(2, review.opened)
        assertNull(review.lines.firstOrNull { it.contains("opened") })
    }

    @Test
    fun `a year with nothing is nothing`() {
        assertNull(YearInReview.review(facts, year = 2019, zone = utc))
        assertEquals(listOf(2026, 2025), YearInReview.years(facts, utc))
    }

    @Test
    fun `money covers every bottle when every bottle has a price`() {
        val f = YearInReview.Facts(added = listOf(
            YearInReview.Added("A", null, null, 1_000, day(2026, 1, 1)),
            YearInReview.Added("B", null, null, 2_000, day(2026, 1, 2)),
        ))
        val review = YearInReview.review(f, year = 2026, zone = utc)
        assertNotNull(review)
        assertEquals("$30.00 across them.", review.moneyLine)
        assertEquals(listOf("2 bottles added.", "First of the year: A, 1 January."), review.lines)
    }

    @Test
    fun `counts rank by frequency then by name, so the answer never shuffles`() {
        val counts = YearInReview.counts(listOf("b", "a", "b", "c", "a", "", "c"))
        assertEquals(
            listOf(
                YearInReview.Count("a", 2),
                YearInReview.Count("b", 2),
                YearInReview.Count("c", 2),
            ),
            counts,
            "a three-way tie resolves alphabetically, and the blank is dropped",
        )
    }

    @Test
    fun `distinct names keep the first spelling and drop the blanks`() {
        assertEquals(
            listOf("Mike", "Sarah"),
            YearInReview.orderedDistinct(listOf("Mike", "  ", "mike", "Sarah", "MIKE")),
        )
    }
}
