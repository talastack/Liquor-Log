package com.talastack.liquorlog.engine

import kotlin.test.Test
import kotlin.test.assertEquals

class FillLevelTest {

    private fun level(remaining: Double, capacity: Double = 750.0) =
        FillLevel(remainingMilliliters = remaining, capacityMilliliters = capacity)

    @Test
    fun `fraction and headroom are complements`() {
        val half = level(375.0)
        assertEquals(0.5, half.fraction, 1e-9)
        assertEquals(0.5, half.headroomFraction, 1e-9)
    }

    @Test
    fun `fraction is clamped at both ends`() {
        assertEquals(1.0, level(900.0).fraction, "a bottle cannot be more than full")
        assertEquals(0.0, level(-10.0).fraction)
        assertEquals(0.0, level(100.0, capacity = 0.0).fraction, "no capacity, no fraction")
    }

    @Test
    fun `the bands are the ones oxidation is judged by`() {
        // Headroom, not elapsed days, is the primary input: a quarter-full
        // bottle has three times the air of a three-quarters-full one.
        assertEquals(FillLevel.Headroom.MINIMAL, level(750.0).headroom)
        assertEquals(FillLevel.Headroom.MINIMAL, level(600.0).headroom, "20% air")
        assertEquals(FillLevel.Headroom.MODERATE, level(500.0).headroom, "33% air")
        assertEquals(FillLevel.Headroom.MODERATE, level(375.0).headroom, "half")
        assertEquals(FillLevel.Headroom.HIGH, level(300.0).headroom, "60% air")
        assertEquals(FillLevel.Headroom.HIGH, level(200.0).headroom)
        assertEquals(FillLevel.Headroom.SEVERE, level(150.0).headroom, "80% air, the heel")
        assertEquals(FillLevel.Headroom.SEVERE, level(0.0).headroom)
    }

    @Test
    fun `each band is entered from clearly inside the one before it`() {
        // Deliberately not the exact boundaries. 502.5 ml is 33.000% air,
        // which lands on whichever side the last bit of a double falls --
        // pinning that would test floating-point luck, not the rule.
        assertEquals(FillLevel.Headroom.MINIMAL, level(510.0).headroom, "32% air")
        assertEquals(FillLevel.Headroom.MODERATE, level(495.0).headroom, "34% air")
        assertEquals(FillLevel.Headroom.MODERATE, level(310.0).headroom, "58.7% air")
        assertEquals(FillLevel.Headroom.HIGH, level(290.0).headroom, "61.3% air")
        assertEquals(FillLevel.Headroom.HIGH, level(160.0).headroom, "78.7% air")
        assertEquals(FillLevel.Headroom.SEVERE, level(140.0).headroom, "81.3% air")
    }

    @Test
    fun `headroom keys are stable, because they are stored`() {
        assertEquals(
            listOf("minimal", "moderate", "high", "severe"),
            FillLevel.Headroom.entries.map { it.storageKey },
        )
    }
}
