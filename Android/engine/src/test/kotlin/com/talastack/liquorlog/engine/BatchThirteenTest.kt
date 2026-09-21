package com.talastack.liquorlog.engine

import java.time.Instant
import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertNotNull
import kotlin.test.assertNull
import kotlin.test.assertTrue

/** The document says what was paid and never what it is worth. */
class InsuranceReportTest {

    private val generatedAt: Instant = Instant.parse("2026-09-21T00:00:00Z")

    private fun line(name: String, distillery: String? = null, paid: Int? = null) =
        InsuranceReport.Line(
            id = name, name = name, distillery = distillery,
            sizeMilliliters = 750.0, status = "Sealed", paidCents = paid
        )

    @Test
    fun `totals cover only priced bottles`() {
        val doc = InsuranceReport.build(
            listOf(
                line("Weller 12", paid = 4_999),
                line("Stagg", paid = 9_999),
                line("Gift")
            ),
            generatedAt
        )
        assertEquals(3, doc.bottleCount)
        assertEquals(2, doc.pricedCount)
        assertEquals(1, doc.unpricedCount)
        assertEquals(14_998, doc.paidTotalCents)
    }

    @Test
    fun `ordered by distillery then name`() {
        val doc = InsuranceReport.build(
            listOf(
                line("Zed", distillery = "Buffalo Trace"),
                line("Elijah Craig", distillery = "Heaven Hill"),
                line("Blanton's", distillery = "Buffalo Trace")
            ),
            generatedAt
        )
        assertEquals(listOf("Blanton's", "Zed", "Elijah Craig"), doc.lines.map { it.name })
    }

    @Test
    fun `the caveat is part of the document`() {
        val doc = InsuranceReport.build(emptyList(), generatedAt)
        assertTrue(doc.caveat.contains("Not an appraisal"))
        assertEquals("Spirits collection inventory", doc.title)
    }

    @Test
    fun `the detail line is in a fixed order`() {
        assertEquals(
            "Barrel 42-3C · Pick · Total Wine · Bottle 47 of 240 · Topper B",
            InsuranceReport.detail(
                barrel = "42-3C", batch = null, pickStore = "Total Wine",
                bottleNumber = 47, bottlesInBatch = 240, topperLetter = "B"
            )
        )
        assertNull(InsuranceReport.detail())
        assertEquals("Bottle 3", InsuranceReport.detail(bottleNumber = 3))
    }
}

/**
 * A drip as a fraction of the bottle, ranked among your own, never called
 * rare.
 */
class WaxDripTest {

    private fun p(x: Double, y: Double) = WaxDrip.Point(x, y)

    @Test
    fun `a fraction of the bottle`() {
        // A bottle 400 units tall, a drip 100 units long: a quarter.
        val m = assertNotNull(
            WaxDrip.measure(
                bottleBase = p(50.0, 500.0), bottleTop = p(50.0, 100.0),
                waxEdge = p(60.0, 120.0), dripTip = p(60.0, 220.0)
            )
        )
        assertEquals(0.25, m.fraction, 0.0001)
        assertEquals(25, m.percent)
        assertNull(m.millimeters, "no height typed, no millimetres")
    }

    @Test
    fun `millimetres only with a real height`() {
        val m = assertNotNull(
            WaxDrip.measure(
                bottleBase = p(0.0, 400.0), bottleTop = p(0.0, 0.0),
                waxEdge = p(0.0, 0.0), dripTip = p(0.0, 100.0),
                bottleHeightMillimeters = 240.0
            )
        )
        assertEquals(60.0, m.millimeters ?: 0.0, 0.001)
        assertNull(
            WaxDrip.measure(
                bottleBase = p(0.0, 400.0), bottleTop = p(0.0, 0.0),
                waxEdge = p(0.0, 0.0), dripTip = p(0.0, 100.0),
                bottleHeightMillimeters = 0.0
            )?.millimeters
        )
    }

    @Test
    fun `the units do not matter`() {
        val small = assertNotNull(
            WaxDrip.measure(p(0.0, 40.0), p(0.0, 0.0), p(0.0, 0.0), p(0.0, 10.0))
        )
        val large = assertNotNull(
            WaxDrip.measure(p(0.0, 4000.0), p(0.0, 0.0), p(0.0, 0.0), p(0.0, 1000.0))
        )
        assertEquals(small.fraction, large.fraction, 0.0001)
    }

    @Test
    fun `a diagonal drip is measured along its length`() {
        val m = assertNotNull(
            WaxDrip.measure(
                bottleBase = p(0.0, 100.0), bottleTop = p(0.0, 0.0),
                waxEdge = p(0.0, 0.0), dripTip = p(30.0, 40.0)
            )
        )
        assertEquals(0.5, m.fraction, 0.0001)
    }

    @Test
    fun `two taps in one place is not a bottle`() {
        assertNull(WaxDrip.measure(p(1.0, 1.0), p(1.0, 1.0), p(0.0, 0.0), p(0.0, 5.0)))
    }

    @Test
    fun `a drip cannot be longer than the bottle`() {
        val m = assertNotNull(
            WaxDrip.measure(p(0.0, 10.0), p(0.0, 0.0), p(0.0, 0.0), p(0.0, 50.0))
        )
        assertEquals(1.0, m.fraction)
    }

    @Test
    fun `standing among your own`() {
        assertEquals(
            "The only drip measured so far.",
            WaxDrip.standing(0.3, emptyList()).text
        )
        assertEquals("Longest of 3.", WaxDrip.standing(0.3, listOf(0.1, 0.2)).text)
        val mid = WaxDrip.standing(0.2, listOf(0.1, 0.3, 0.05, 0.4))
        assertEquals(3, mid.rank)
        assertEquals("Longer than 50% of 5.", mid.text)
    }

    @Test
    fun `community standing speaks in quarters`() {
        val standing = WaxDrip.CommunityStanding("makers", 40, 0.1, 0.15, 0.2)
        assertEquals(
            "Longer than three quarters of the 40 drips people have measured.",
            standing.text(0.25)
        )
        assertEquals(
            "Longer than half of the 40 drips people have measured.",
            standing.text(0.16)
        )
        assertEquals(
            "Longer than a quarter of the 40 drips people have measured.",
            standing.text(0.12)
        )
        assertEquals(
            "Among the shortest quarter of the 40 drips people have measured.",
            standing.text(0.05)
        )
    }

    @Test
    fun `too few measured drips say nothing`() {
        val standing = WaxDrip.CommunityStanding("makers", 3, 0.1, 0.15, 0.2)
        assertNull(standing.text(0.5))
    }
}
