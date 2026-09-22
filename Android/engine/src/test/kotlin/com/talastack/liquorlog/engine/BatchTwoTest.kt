package com.talastack.liquorlog.engine

import java.time.Instant
import java.time.ZoneId
import java.time.temporal.ChronoUnit
import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertNotNull
import kotlin.test.assertNull
import kotlin.test.assertTrue

class AgeMathTest {

    private val utc = ZoneId.of("UTC")
    private fun at(iso: String): Instant = Instant.parse(iso)

    @Test
    fun `months are described the way a label prints them`() {
        assertEquals("11 months", AgeMath.describe(11))
        assertEquals("1 month", AgeMath.describe(1))
        assertEquals("12 years", AgeMath.describe(144))
        assertEquals("1 year", AgeMath.describe(12))
        assertEquals("7 years 4 months", AgeMath.describe(88))
        assertEquals("1 year 1 month", AgeMath.describe(13))
        assertEquals("0 months", AgeMath.describe(0))
    }

    @Test
    fun `maturation is barrel time, and an impossible pair is refused`() {
        assertEquals(12, AgeMath.maturationYears(distilledYear = 2010, bottledYear = 2022))
        assertEquals(0, AgeMath.maturationYears(distilledYear = 2022, bottledYear = 2022))
        assertNull(AgeMath.maturationYears(distilledYear = 2025, bottledYear = 2022), "bottled before distilled")
        assertNull(AgeMath.maturationYears(distilledYear = null, bottledYear = 2022))
    }

    @Test
    fun `time in glass is provenance and is never the whiskey's age`() {
        // A 1985 bottling of a 12-year is a 12-year-old whiskey in a
        // 40-year-old bottle. This number is the bottle's, not the whiskey's.
        val now = at("2026-09-17T12:00:00Z")
        assertEquals(41, AgeMath.yearsInGlass(bottledYear = 1985, now = now, zone = utc))
        assertEquals(0, AgeMath.yearsInGlass(bottledYear = 2026, now = now, zone = utc))
        assertNull(AgeMath.yearsInGlass(bottledYear = 2030, now = now, zone = utc), "the future is not provenance")
        assertNull(AgeMath.yearsInGlass(bottledYear = null, now = now, zone = utc))
    }

    @Test
    fun `days are whole days, and a clock that jumped back clamps to zero`() {
        val opened = at("2026-01-01T00:00:00Z")
        assertEquals(10, AgeMath.days(opened, opened.plus(10, ChronoUnit.DAYS)))
        assertEquals(10, AgeMath.days(opened, opened.plus(10, ChronoUnit.DAYS).plus(23, ChronoUnit.HOURS)))
        assertEquals(0, AgeMath.days(opened, opened.minus(5, ChronoUnit.DAYS)), "no bottle opens in the future")
    }

    @Test
    fun `owned and open both read as days, and are null when undated`() {
        val now = at("2026-09-17T12:00:00Z")
        assertEquals(30, AgeMath.daysOwned(now.minus(30, ChronoUnit.DAYS), now))
        assertEquals(44, AgeMath.daysOpen(now.minus(44, ChronoUnit.DAYS), now))
        assertNull(AgeMath.daysOwned(null, now))
        assertNull(AgeMath.daysOpen(null, now))
    }
}

class OxidationBandTest {

    @Test
    fun `the two cases the design is pinned to`() {
        // 24% headroom, open 44 days: fresh.
        assertEquals(
            OxidationBand.Band.FRESH,
            OxidationBand.estimate(headroomFraction = 0.24, daysOpen = 44).band,
        )
        // 70% headroom, open 213 days: fading.
        assertEquals(
            OxidationBand.Band.FADING,
            OxidationBand.estimate(headroomFraction = 0.70, daysOpen = 213).band,
        )
    }

    @Test
    fun `air times time, not either alone`() {
        // Three-quarters gone but only a fortnight open: barely changed.
        val fast = OxidationBand.estimate(headroomFraction = 0.75, daysOpen = 14)
        assertEquals(OxidationBand.Band.FRESH, fast.band)

        // The same level, sitting for two years: not the same bottle.
        val slow = OxidationBand.estimate(headroomFraction = 0.75, daysOpen = 730)
        assertEquals(OxidationBand.Band.FADED, slow.band)

        // A full bottle cannot oxidise however long it stands.
        val full = OxidationBand.estimate(headroomFraction = 0.0, daysOpen = 3650)
        assertEquals(OxidationBand.Band.FRESH, full.band)
        assertEquals(0.0, full.exposure)
    }

    @Test
    fun `inputs are clamped and time saturates at the reference year`() {
        val overFull = OxidationBand.estimate(headroomFraction = 1.4, daysOpen = -10)
        assertEquals(1.0, overFull.headroomFraction)
        assertEquals(0, overFull.daysOpen)

        val year = OxidationBand.estimate(headroomFraction = 1.0, daysOpen = 365)
        val decade = OxidationBand.estimate(headroomFraction = 1.0, daysOpen = 3650)
        assertEquals(year.exposure, decade.exposure, "time saturates; it does not keep climbing")
    }

    @Test
    fun `the steps run zero to three for the meter the design draws`() {
        assertEquals(listOf(0, 1, 2, 3), OxidationBand.Band.entries.map { it.step })
        assertEquals(listOf("fresh", "peak", "fading", "faded"), OxidationBand.Band.entries.map { it.storageKey })
    }

    @Test
    fun `every estimate carries the caveat, because it is not defensible without it`() {
        val estimate = OxidationBand.estimate(headroomFraction = 0.5, daysOpen = 100)
        assertTrue(estimate.caveat.contains("not chemistry"))
        assertTrue(estimate.summary.isNotEmpty())
        assertEquals(50, estimate.headroomPercent)
    }

    @Test
    fun `a fill level can be handed in directly`() {
        val level = FillLevel(remainingMilliliters = 187.5, capacityMilliliters = 750.0)
        assertEquals(
            OxidationBand.estimate(headroomFraction = 0.75, daysOpen = 200).band,
            OxidationBand.estimate(level, daysOpen = 200).band,
        )
    }
}

class MultiplesTest {

    private fun bottle(id: String, product: String, barrel: String? = null,
                       batch: String? = null, finished: Boolean = false) =
        Multiples.Bottle(id = id, productKey = product, barrel = barrel,
                         batch = batch, isFinished = finished)

    @Test
    fun `three of one pick are one of three, each`() {
        val places = Multiples.places(listOf(
            bottle("a", "fr-single-barrel", barrel = "42-3C"),
            bottle("b", "fr-single-barrel", barrel = "42-3C"),
            bottle("c", "fr-single-barrel", barrel = "42-3C"),
        ))
        assertEquals("1 of 3", places.getValue("a").label)
        assertEquals("2 of 3", places.getValue("b").label)
        assertEquals("3 of 3", places.getValue("c").label)
        assertEquals(listOf("b", "c"), places.getValue("a").siblings)
    }

    @Test
    fun `different batches of one name are not multiples`() {
        // Two Elijah Craig Barrel Proofs from different batches are different
        // whiskeys with one name, which is why batches are tracked at all.
        val places = Multiples.places(listOf(
            bottle("a", "ecbp", batch = "B523"),
            bottle("b", "ecbp", batch = "C924"),
        ))
        assertNull(places.getValue("a").label)
        assertNull(places.getValue("b").label)
        assertEquals(1, places.getValue("a").count)
    }

    @Test
    fun `a finished bottle neither counts nor gets a place`() {
        // "1 of 3" on a shelf holding one bottle and two empties is wrong in
        // the way that matters.
        val places = Multiples.places(listOf(
            bottle("a", "weller-12"),
            bottle("dead-1", "weller-12", finished = true),
            bottle("dead-2", "weller-12", finished = true),
        ))
        assertNull(places["dead-1"])
        assertEquals(1, places.getValue("a").count)
        assertNull(places.getValue("a").label)
    }

    @Test
    fun `barrel numbers match however they were typed`() {
        val places = Multiples.places(listOf(
            bottle("a", "fr-single-barrel", barrel = "42-3C"),
            bottle("b", "fr-single-barrel", barrel = "42 3c"),
        ))
        assertEquals(2, places.getValue("a").count, "the same barrel, punctuated differently")
    }
}

class ReplenishTest {

    @Test
    fun `the crossing pour asks, once`() {
        val offer = Replenish.offer(
            remainingBefore = 3, remainingAfter = 2,
            isOnWishlist = false, wouldRebuy = null,
        )
        assertNotNull(offer)
        assertEquals("About 2 pours left.", offer.text)

        // The next pour is below the line but is not the crossing, so it is
        // not asked again. An app that nags on every pour gets muted.
        assertNull(Replenish.offer(
            remainingBefore = 2, remainingAfter = 1,
            isOnWishlist = false, wouldRebuy = null,
        ))
    }

    @Test
    fun `it never asks about something already wanted or already refused`() {
        assertNull(Replenish.offer(
            remainingBefore = 3, remainingAfter = 2,
            isOnWishlist = true, wouldRebuy = true,
        ))
        assertNull(Replenish.offer(
            remainingBefore = 3, remainingAfter = 2,
            isOnWishlist = false, wouldRebuy = false,
        ))
    }

    @Test
    fun `what was said last time is repeated back`() {
        val offer = Replenish.offer(
            remainingBefore = 3, remainingAfter = 1,
            isOnWishlist = false, wouldRebuy = true,
        )
        assertNotNull(offer)
        assertEquals("About one pour left. You said you would buy it again.", offer.text)
    }

    @Test
    fun `the last pour says so`() {
        val offer = Replenish.offer(
            remainingBefore = 3, remainingAfter = 0,
            isOnWishlist = false, wouldRebuy = null,
        )
        assertNotNull(offer)
        assertEquals("That was the last pour.", offer.text)
        assertEquals(0, offer.remainingPours)
    }
}

class PerceivedProofTest {

    @Test
    fun `expected heat is banded, because the ends are not linear`() {
        assertEquals(PerceivedProof.Heat.GENTLE, PerceivedProof.expectedHeat(ABV(percent = 40.0)))
        assertEquals(PerceivedProof.Heat.WARM, PerceivedProof.expectedHeat(ABV(percent = 45.0)))
        assertEquals(PerceivedProof.Heat.FIRM, PerceivedProof.expectedHeat(ABV(percent = 50.0)))
        assertEquals(PerceivedProof.Heat.HOT, PerceivedProof.expectedHeat(ABV(percent = 57.0)))
        assertEquals(PerceivedProof.Heat.SCORCHING, PerceivedProof.expectedHeat(ABV(percent = 62.1)))
    }

    @Test
    fun `a barrel proof that drinks easy is the compliment`() {
        val result = PerceivedProof.compare(ABV(percent = 62.1), felt = PerceivedProof.Heat.FIRM)
        assertEquals(PerceivedProof.Verdict.DRINKS_BELOW_ITS_PROOF, result.verdict)
        assertEquals(-2, result.difference)
        assertEquals("You would not guess 124.2 proof from tasting it.", result.summary)
    }

    @Test
    fun `harsher than the strength explains suggests water`() {
        val result = PerceivedProof.compare(ABV(percent = 45.0), felt = PerceivedProof.Heat.HOT)
        assertEquals(PerceivedProof.Verdict.DRINKS_ABOVE_ITS_PROOF, result.verdict)
        assertTrue(result.summary.contains("few drops of water"))
    }

    @Test
    fun `matching the expectation is about right`() {
        val result = PerceivedProof.compare(ABV(percent = 50.0), felt = PerceivedProof.Heat.FIRM)
        assertEquals(PerceivedProof.Verdict.DRINKS_AT_ITS_PROOF, result.verdict)
        assertEquals(0, result.difference)
        assertEquals("Tastes about like 100.0 proof should.", result.summary)
    }

    @Test
    fun `the heat scale round-trips through its stored value`() {
        for (heat in PerceivedProof.Heat.entries) {
            assertEquals(heat, PerceivedProof.Heat.fromValue(heat.value))
        }
        assertNull(PerceivedProof.Heat.fromValue(0))
        assertNull(PerceivedProof.Heat.fromValue(6))
    }
}
