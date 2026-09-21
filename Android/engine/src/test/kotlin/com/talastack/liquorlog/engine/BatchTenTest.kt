package com.talastack.liquorlog.engine

import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertFalse
import kotlin.test.assertIs
import kotlin.test.assertNotNull
import kotlin.test.assertNull
import kotlin.test.assertTrue

/**
 * Rarity from measured allocation, never from opinion. These pin the
 * restraint: three honest states, and no fabricated tier below "allocated".
 */
class RarityTest {

    /** The example the research found: 640 bottles, 44,696 entries. */
    private val stagg = Rarity.Allocation(
        bottles = 640, entries = 44_696, source = "Virginia ABC", year = 2026
    )

    @Test
    fun `measured demand becomes a ratio`() {
        assertEquals(69.8, stagg.demandRatio ?: 0.0, 0.05)
        val verdict = assertIs<Rarity.Verdict.Contested>(
            Rarity.assess(stagg).verdict, "a lottery with both numbers is contested"
        )
        assertEquals(69.8, verdict.ratio, 0.05)
    }

    @Test
    fun `seventy to one is extremely contested`() {
        assertEquals("Extremely contested", Rarity.assess(stagg).verdict.headline)
    }

    @Test
    fun `ten to one is contested`() {
        val allocation = Rarity.Allocation(bottles = 100, entries = 1_200, source = "Virginia ABC")
        assertEquals("Contested", Rarity.assess(allocation).verdict.headline)
    }

    @Test
    fun `a quiet lottery is just allocated by lottery`() {
        val allocation = Rarity.Allocation(bottles = 500, entries = 800, source = "Virginia ABC")
        assertEquals("Allocated, by lottery", Rarity.assess(allocation).verdict.headline)
    }

    /**
     * Pennsylvania publishes counts with no lottery. Supply without demand
     * gets a different verdict rather than a guessed ratio.
     */
    @Test
    fun `a count without entries is allocated, not contested`() {
        val allocation = Rarity.Allocation(bottles = 2_016, source = "Pennsylvania PLCB")
        val result = Rarity.assess(allocation)
        assertEquals(Rarity.Verdict.Allocated(2_016), result.verdict)
        assertNull(allocation.demandRatio)
    }

    /**
     * The most important test in the file. No record is NOT "common": every
     * free source skews to the scarce end, so there is no basis for a tier
     * below allocated, and inventing one is exactly the incumbent's mistake.
     */
    @Test
    fun `no record is not allocated and never common`() {
        val result = Rarity.assess(null)
        assertEquals(Rarity.Verdict.NotAllocated, result.verdict)
        assertFalse(result.verdict.headline.lowercase().contains("common"))
        assertTrue(result.summary.contains("not the same as common"))
    }

    @Test
    fun `the summary carries both numbers`() {
        val summary = Rarity.assess(stagg).summary
        assertTrue(summary.contains("44,696"), summary)
        assertTrue(summary.contains("640"), summary)
        assertTrue(summary.contains("70 people"), summary)
    }

    /** Two states' allocations do not add up to a national picture. */
    @Test
    fun `the caveat names the state and disclaims the nation`() {
        val caveat = Rarity.assess(stagg).caveat
        assertTrue(caveat.contains("Virginia ABC"))
        assertTrue(caveat.contains("2026"))
        assertTrue(caveat.contains("not a national figure"))
    }

    @Test
    fun `a zero-bottle allocation does not divide`() {
        val allocation = Rarity.Allocation(bottles = 0, entries = 100, source = "x")
        assertNull(allocation.demandRatio)
        assertEquals(Rarity.Verdict.Allocated(0), Rarity.assess(allocation).verdict)
    }
}

/** Windows, never dates; overlap, never an average. */
class DustyCluesTest {

    private fun clue(id: String): DustyClues.Clue =
        assertNotNull(DustyClues.Clue.allCases.firstOrNull { it.id == id }, id)

    @Test
    fun `nothing chosen asks for something`() {
        assertEquals("Pick what the bottle shows.", DustyClues.window(emptyList()).text)
    }

    @Test
    fun `one clue is a one-sided window`() {
        assertEquals("Before 1986.", DustyClues.window(listOf(clue("strip"))).text)
        assertEquals("1976 or later.", DustyClues.window(listOf(clue("metric"))).text)
        assertEquals("Before 1977.", DustyClues.window(listOf(clue("irs"))).text)
    }

    /**
     * One strip cannot say both IRS and ATF; a bottle cannot both have
     * and lack a strip, even in 1985 when either was possible.
     */
    @Test
    fun `mutually exclusive clues conflict whatever the year`() {
        assertNotNull(DustyClues.window(listOf(clue("irs"), clue("atf"))).conflict)
        assertNotNull(DustyClues.window(listOf(clue("strip"), clue("no-strip"))).conflict)
        assertNotNull(DustyClues.window(listOf(clue("quart"), clue("metric"))).conflict)
    }

    /** ATF strip and a 4/5 quart: 1977 to 1979, the three years both held. */
    @Test
    fun `clues overlap`() {
        val window = DustyClues.window(listOf(clue("atf"), clue("quart")))
        assertEquals(1977, window.from)
        assertEquals(1979, window.to)
        assertEquals("Between 1977 and 1979.", window.text)
    }

    @Test
    fun `a metric strip bottle is late seventies to mid eighties`() {
        val window = DustyClues.window(listOf(clue("strip"), clue("metric")))
        assertEquals("Between 1976 and 1985.", window.text)
    }

    /**
     * An IRS strip and a metric size cannot both be right about the same
     * bottle -- well, they can for 1976, so make it ATF and Series 111.
     */
    @Test
    fun `a contradiction is said, not averaged`() {
        val window = DustyClues.window(listOf(clue("atf"), clue("series")))
        assertNotNull(window.conflict)
        assertTrue(window.text.startsWith("Those cannot both be true"))
    }

    @Test
    fun `every clue has a reason`() {
        for (clue in DustyClues.Clue.allCases) {
            assertFalse(clue.why.isEmpty(), clue.id)
            assertTrue(clue.from != null || clue.to != null, clue.id)
        }
    }
}
