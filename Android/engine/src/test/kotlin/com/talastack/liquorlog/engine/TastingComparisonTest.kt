package com.talastack.liquorlog.engine

import java.time.Instant
import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertNull
import kotlin.test.assertTrue

/** The Kotlin half of the comparison, held to the same assertions as Swift. */
class TastingComparisonTest {

    private fun day(n: Long): Instant = Instant.ofEpochSecond(n * 86_400)
    private val stages = listOf("nose", "entry", "mid", "finish")

    @Test
    fun `the older tasting is the earlier one whichever way it arrives`() {
        val march = TastingComparison.Side(day(10), rating = 6)
        val october = TastingComparison.Side(day(200), rating = 8)

        for (pair in listOf(march to october, october to march)) {
            val result = TastingComparison.compare(pair.first, pair.second, stages)
            assertEquals(day(10), result.earlier.tastedAt)
            assertEquals(day(200), result.later.tastedAt)
            assertEquals(2, result.ratingChange)
        }
    }

    @Test
    fun `descriptors split into shared, gone and new`() {
        val before = TastingComparison.Side(
            day(1), rating = 7,
            descriptors = mapOf("nose" to listOf("Caramel", "Green apple"), "finish" to listOf("Oak")),
        )
        val after = TastingComparison.Side(
            day(100), rating = 7,
            descriptors = mapOf("nose" to listOf("Caramel", "Dried fig"), "finish" to listOf("Oak")),
        )

        val result = TastingComparison.compare(before, after, stages)
        val nose = result.stages.first { it.stage == "nose" }
        assertEquals(listOf("Caramel"), nose.shared)
        assertEquals(listOf("Green apple"), nose.goneSince)
        assertEquals(listOf("Dried fig"), nose.newSince)

        // A stage that did not move says so rather than being dropped: it is
        // evidence the two tastings agreed.
        val finish = result.stages.first { it.stage == "finish" }
        assertEquals(listOf("Oak"), finish.shared)
        assertTrue(finish.isUnchanged)
    }

    @Test
    fun `a stage nobody used is left out entirely`() {
        val before = TastingComparison.Side(day(1), descriptors = mapOf("nose" to listOf("Caramel")))
        val after = TastingComparison.Side(day(2), descriptors = mapOf("nose" to listOf("Caramel")))

        val result = TastingComparison.compare(before, after, stages)
        assertEquals(listOf("nose"), result.stages.map { it.stage })
    }

    @Test
    fun `an unrated tasting is not a zero`() {
        // The difference between "I did not score it" and "I scored it 0" is
        // the difference between no opinion and a bad one.
        val rated = TastingComparison.Side(day(1), rating = 8)
        val unrated = TastingComparison.Side(day(50))

        assertNull(TastingComparison.compare(rated, unrated, stages).ratingChange)
    }

    @Test
    fun `the line states what happened without interpreting it`() {
        val before = TastingComparison.Side(day(1), rating = 6)
        val after = TastingComparison.Side(
            day(200), rating = 8, descriptors = mapOf("nose" to listOf("Dried fig")),
        )

        val text = TastingComparison.compare(before, after, stages).text
        assertTrue(text.contains("6"), text)
        assertTrue(text.contains("8 out of 10"), text)
        assertTrue(text.contains("up from"), text)
        // "You liked it more" is a claim about a person. This says what the
        // record says and stops.
        assertTrue(!text.lowercase().contains("better"), text)
        assertTrue(!text.lowercase().contains("liked"), text)
    }

    @Test
    fun `two tastings on one night read as the same day`() {
        val first = TastingComparison.Side(day(5), rating = 7)
        val second = TastingComparison.Side(day(5), rating = 7)

        val result = TastingComparison.compare(first, second, stages)
        assertEquals(0, result.daysApart)
        assertTrue(result.text.startsWith("The same day"), result.text)
        assertTrue(result.text.contains("still 7"), result.text)
    }
}
