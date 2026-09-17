package com.talastack.liquorlog.engine

import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertFalse
import kotlin.test.assertNull
import kotlin.test.assertTrue

/**
 * The same assertions the Swift engine is held to. The two numbers this
 * whole design is pinned to: a 750 ml bottle gives 17 pours and a 700 ml
 * gives 16. Only a 1.5 oz pour rounded to nearest satisfies both, so these
 * are load-bearing -- if either changes, the constant or the rounding rule
 * changed with it, on one platform and not the other.
 */
class PourMathTest {

    @Test
    fun `a full seven fifty reads seventeen of seventeen`() {
        val status = PourMath.status(capacityMilliliters = 750.0, pouredMilliliters = 0.0)
        assertEquals(17, status.totalPours)
        assertEquals(17, status.remainingPours, "a full bottle must not read 16 of 17")
    }

    @Test
    fun `a full seven hundred reads sixteen of sixteen`() {
        val status = PourMath.status(capacityMilliliters = 700.0, pouredMilliliters = 0.0)
        assertEquals(16, status.totalPours)
        assertEquals(16, status.remainingPours)
    }

    @Test
    fun `four pours from a seven fifty reads thirteen of seventeen`() {
        val poured = 4 * PourSize.standard.milliliters
        val status = PourMath.status(capacityMilliliters = 750.0, pouredMilliliters = poured)
        assertEquals(13, status.remainingPours)
        assertEquals(17, status.totalPours, "the denominator is capacity, not what is left")
    }

    @Test
    fun `the standard pour is forty four point three six millilitres`() {
        assertEquals(44.36, PourSize.standard.milliliters, 0.01)
    }

    @Test
    fun `thirty millilitres remaining reads one pour`() {
        val status = PourMath.status(capacityMilliliters = 750.0, pouredMilliliters = 720.0)
        assertEquals(1, status.remainingPours)
        assertFalse(status.hasPartialPourOnly)
        assertEquals(30.0, status.remainingMilliliters, 0.001)
    }

    @Test
    fun `ten millilitres is a partial pour and not empty`() {
        val status = PourMath.status(capacityMilliliters = 750.0, pouredMilliliters = 740.0)
        assertEquals(0, status.remainingPours)
        assertTrue(status.hasPartialPourOnly, "the UI says 'less than a pour', never '0 of 17'")
        assertFalse(status.isEmpty)
    }

    @Test
    fun `over-pouring clamps at empty`() {
        val status = PourMath.status(capacityMilliliters = 750.0, pouredMilliliters = 900.0)
        assertEquals(0.0, status.remainingMilliliters)
        assertEquals(0, status.remainingPours)
        assertTrue(status.isEmpty)
        assertFalse(status.hasPartialPourOnly)
    }

    @Test
    fun `a reading over the bottle's capacity is clamped to it`() {
        val status = PourMath.status(
            capacityMilliliters = 750.0,
            pouredMilliliters = 0.0,
            startingMilliliters = 900.0,
        )
        assertEquals(750.0, status.remainingMilliliters, "a fill bar at 120% is visibly wrong")
    }

    @Test
    fun `cost per pour divides by the count on the screen`() {
        // $68.00 over the 17 pours the user is shown, not over 16.91.
        assertEquals(400, PourMath.costPerPourCents(6_800, 750.0, PourSize.standard))
        assertNull(PourMath.costPerPourCents(0, 750.0, PourSize.standard))
        assertNull(PourMath.costPerPourCents(6_800, 0.0, PourSize.standard))
    }

    @Test
    fun `percentages and millilitres are inverses, and both are clamped`() {
        assertEquals(375.0, PourMath.milliliters(percentFull = 50.0, capacity = 750.0))
        assertEquals(50.0, PourMath.percentFull(remaining = 375.0, capacity = 750.0))
        assertEquals(750.0, PourMath.milliliters(percentFull = 140.0, capacity = 750.0))
        assertEquals(0.0, PourMath.milliliters(percentFull = -10.0, capacity = 750.0))
        assertEquals(0.0, PourMath.percentFull(remaining = 100.0, capacity = 0.0))
    }
}
