package com.talastack.liquorlog.engine

import java.time.Instant
import java.time.LocalDateTime
import java.time.ZoneId
import java.time.ZoneOffset
import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertFalse
import kotlin.test.assertNotNull
import kotlin.test.assertNull
import kotlin.test.assertTrue

/**
 * The permit number is how sourced whiskey is unmasked, so the table must
 * be right and the app must say nothing when it does not know.
 */
class DistilleryPermitTest {

    @Test
    fun `spellings normalise`() {
        assertEquals("DSP-KY-113", DistilleryPermit.normalise("dsp ky 113"))
        assertEquals("DSP-KY-113", DistilleryPermit.normalise("DSP-KY-00113"))
        assertEquals("DSP-IN-15016", DistilleryPermit.normalise("DSP IN-15016"))
        assertNull(DistilleryPermit.normalise("KY-113"))
        assertNull(DistilleryPermit.normalise("OESQ"))
    }

    @Test
    fun `the majors resolve`() {
        assertEquals("Buffalo Trace", DistilleryPermit.lookup("DSP-KY-113")?.distillery)
        assertEquals("Maker's Mark", DistilleryPermit.lookup("DSP-KY-44")?.distillery)
        assertEquals(
            "MGP Ingredients (Ross & Squibb)",
            DistilleryPermit.lookup("dsp-in-15016")?.distillery
        )
        assertEquals("Jack Daniel's", DistilleryPermit.lookup("DSP-TN-4")?.distillery)
    }

    @Test
    fun `unknown is unknown, not a guess`() {
        assertNull(DistilleryPermit.lookup("DSP-KY-99999"))
    }

    @Test
    fun `found inside label text`() {
        assertEquals(
            "DSP-KY-113",
            DistilleryPermit.find(
                "DISTILLED AND BOTTLED BY BUFFALO TRACE DISTILLERY DSP-KY-113 FRANKFORT KY"
            )
        )
    }

    /** The list must not carry the same number twice with different names. */
    @Test
    fun `no duplicate numbers`() {
        val numbers = DistilleryPermit.plants.map { it.number }
        assertEquals(numbers.size, numbers.toSet().size)
    }

    @Test
    fun `every number is in normal form`() {
        for (plant in DistilleryPermit.plants) {
            assertEquals(plant.number, DistilleryPermit.normalise(plant.number), plant.number)
        }
    }
}

/** A line from the producer about the building, or nothing. */
class WarehouseLoreTest {

    @Test
    fun `warehouse H is Blantons`() {
        val note = assertNotNull(WarehouseLore.note(distillery = "Buffalo Trace", warehouse = "H"))
        assertTrue(note.text.contains("metal-clad"))
        assertTrue(note.source.contains("buffalotracedistillery.com"))
    }

    @Test
    fun `another Buffalo Trace warehouse says nothing`() {
        assertNull(WarehouseLore.note(distillery = "Buffalo Trace", warehouse = "K"))
        assertNull(WarehouseLore.note(distillery = "Buffalo Trace", warehouse = null))
    }

    @Test
    fun `Four Roses is about the buildings in general`() {
        val note = assertNotNull(WarehouseLore.note(distillery = "Four Roses", warehouse = null))
        assertTrue(note.text.contains("single-story"))
    }

    @Test
    fun `Wild Turkey Camp Nelson is specific`() {
        val specific = assertNotNull(
            WarehouseLore.note(distillery = "Wild Turkey", warehouse = "Camp Nelson B")
        )
        assertTrue(specific.text.contains("Camp Nelson B"))
        val general = assertNotNull(
            WarehouseLore.note(distillery = "Wild Turkey", warehouse = "Tyrone F")
        )
        assertFalse(general.text.contains("Camp Nelson B"))
    }

    @Test
    fun `an unknown distillery has no lore`() {
        assertNull(WarehouseLore.note(distillery = "Heaven Hill", warehouse = "Y"))
    }
}

/** One sentence from the last tasting, built only from what was recorded. */
class TastingRecallTest {

    private val utc: ZoneId = ZoneOffset.UTC

    private val weller = ProductIdentity(
        productId = "w12", distillery = "Buffalo Trace", brand = "W. L. Weller",
        expression = "12 Year", classType = ClassType.KENTUCKY_STRAIGHT_BOURBON,
        productionType = ProductionType.UNSPECIFIED
    )

    private fun date(y: Int, m: Int, d: Int): Instant =
        LocalDateTime.of(y, m, d, 12, 0).atZone(utc).toInstant()

    private fun record(
        at: Instant, rating: Int? = null, rebuy: Boolean? = null,
        liked: String? = null, disliked: String? = null, whereTasted: String? = null
    ) = TastingRecord(
        tastingId = "t", product = weller, tastedAt = at, rating = rating,
        wouldRebuy = rebuy, liked = liked, disliked = disliked, whereTasted = whereTasted
    )

    @Test
    fun `everything recorded reads as one line`() {
        val now = date(2026, 9, 15)
        val line = TastingRecall.line(
            record(
                at = date(2026, 3, 2), rating = 8, rebuy = true,
                liked = "toffee", disliked = "the heat"
            ),
            now, utc
        )
        assertEquals("Last time, in March: 8/10, would buy again. Liked toffee. Not the heat.", line)
    }

    @Test
    fun `only what was recorded appears`() {
        val now = date(2026, 9, 15)
        assertEquals(
            "Last time, yesterday: 6/10.",
            TastingRecall.line(record(at = date(2026, 9, 14), rating = 6), now, utc)
        )
        assertEquals(
            "Last time, today. Liked the finish.",
            TastingRecall.line(record(at = date(2026, 9, 15), liked = "  the finish "), now, utc)
        )
        assertEquals(
            "Last time, 12 days ago: would not buy again.",
            TastingRecall.line(record(at = date(2026, 9, 3), rebuy = false), now, utc)
        )
    }

    /**
     * A tasting with nothing in it is not a memory. No line, rather than
     * "Last time: ." on the card.
     */
    @Test
    fun `nothing recorded means no line`() {
        assertNull(
            TastingRecall.line(
                record(at = date(2026, 9, 1), liked = "  "), date(2026, 9, 15), utc
            )
        )
    }

    @Test
    fun `where it happened is kept`() {
        val line = TastingRecall.line(
            record(at = date(2025, 11, 20), rating = 7, whereTasted = "At a bar"),
            date(2026, 9, 15), utc
        )
        assertEquals("Last time, in November 2025 (at a bar): 7/10.", line)
    }

    @Test
    fun `the month carries its year only when it is not this year`() {
        val now = date(2026, 9, 15)
        assertEquals("in January", TastingRecall.whenItWas(date(2026, 1, 3), now, utc))
        assertEquals("in July 2024", TastingRecall.whenItWas(date(2024, 7, 3), now, utc))
        assertEquals("26 days ago", TastingRecall.whenItWas(date(2026, 8, 20), now, utc))
    }
}
