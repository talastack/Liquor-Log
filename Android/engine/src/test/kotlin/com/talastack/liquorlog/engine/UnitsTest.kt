package com.talastack.liquorlog.engine

import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertFalse
import kotlin.test.assertTrue

class UnitsTest {

    @Test
    fun `proof is exactly twice abv, both ways`() {
        assertEquals(124.2, ABV(percent = 62.1).proof, 0.0001)
        assertEquals(62.1, ABV.fromProof(124.2).percent, 0.0001)
    }

    @Test
    fun `the plausible range is wide on purpose and therefore weak`() {
        assertTrue(ABV(percent = 62.1).isPlausible)
        // A real beer strength, which is why catching a mistyped bourbon
        // needs the class rather than this range.
        assertTrue(ABV(percent = 6.26).isPlausible)
        assertFalse(ABV(percent = 0.0).isPlausible)
        assertFalse(ABV(percent = 99.0).isPlausible)
    }

    @Test
    fun `abv compares by strength`() {
        assertTrue(ABV(percent = 45.0) < ABV(percent = 62.1))
        assertEquals(ABV(percent = 45.0), ABV.fromProof(90.0))
    }

    @Test
    fun `the standards of fill accept a real bottle and refuse a typo`() {
        assertTrue(Volume.isStandardFill(750.0))
        assertTrue(Volume.isStandardFill(700.0))
        assertTrue(Volume.isStandardFill(50.0), "a sample is a standard size")
        assertFalse(Volume.isStandardFill(751.0))
        assertFalse(Volume.isStandardFill(0.0))
    }

    @Test
    fun `a pour size converts both ways`() {
        assertEquals(44.36, PourSize.fromOunces(1.5).milliliters, 0.01)
        assertEquals(1.5, PourSize.standard.usFluidOunces, 0.0001)
    }
}
