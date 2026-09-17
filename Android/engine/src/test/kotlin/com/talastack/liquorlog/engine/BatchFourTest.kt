package com.talastack.liquorlog.engine

import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertNotNull
import kotlin.test.assertNull
import kotlin.test.assertTrue

/**
 * Table 6 is a transcription from a government scan, so the tests are the
 * transcription's proof: the regulation's own worked example, its printed
 * anchors, and the smoothness of the step between neighbours, which is what
 * exposed every misread digit.
 */
class ProofingTest {

    @Test
    fun `the regulation's own worked example`() {
        // 27 CFR 30.66: "1.12 x 53.73 = 60.17, minus 47.75 equals 12.42
        // gallons of water per 100 wine gallons." 12.4276 before the
        // regulation's truncation, which is what the arithmetic gives.
        val parts = Proofing.waterToAdd(from = 112.0, to = 100.0, spiritMilliliters = 100.0)
        assertNotNull(parts)
        assertEquals(12.4276, parts, 0.001)
    }

    @Test
    fun `barrel proof down to a hundred, for one pour`() {
        val ml = Proofing.waterToAdd(from = 124.0, to = 100.0, spiritMilliliters = 44.0)
        assertNotNull(ml)
        assertEquals(10.98, ml, 0.01)
    }

    @Test
    fun `the anchors the regulation prints`() {
        assertEquals(53.73, Proofing.waterParts(100.0)!!, 0.0001)
        assertEquals(47.75, Proofing.waterParts(112.0)!!, 0.0001)
        assertEquals(28.19, Proofing.waterParts(150.0)!!, 0.0001)
        assertEquals(76.79, Proofing.waterParts(51.0)!!, 0.0001)
    }

    @Test
    fun `the step between neighbours stays smooth, which is how misreads showed up`() {
        var previous = Proofing.water.getValue(51)
        for (proof in 52..150) {
            val current = Proofing.water.getValue(proof)
            val step = previous - current
            assertTrue(
                step in 0.44..0.54,
                "the step from ${proof - 1} to $proof is $step, which is not the table's shape",
            )
            previous = current
        }
    }

    @Test
    fun `between whole proofs it interpolates`() {
        assertEquals((53.73 + 53.24) / 2, Proofing.waterParts(100.5)!!, 0.0001)
    }

    @Test
    fun `outside the table the answer is nothing, never a guess`() {
        assertNull(Proofing.waterParts(50.9))
        assertNull(Proofing.waterParts(150.1))
        assertNull(Proofing.waterToAdd(from = 160.0, to = 100.0, spiritMilliliters = 44.0))
        assertNull(Proofing.waterToAdd(from = 100.0, to = 40.0, spiritMilliliters = 44.0))
        assertNull(Proofing.waterToAdd(from = 100.0, to = 110.0, spiritMilliliters = 44.0), "water does not raise proof")
        assertNull(Proofing.waterToAdd(from = 100.0, to = 90.0, spiritMilliliters = 0.0))
    }

    @Test
    fun `adding water and asking where it landed are the same arithmetic`() {
        val spirit = 44.36
        val needed = Proofing.waterToAdd(from = 124.0, to = 100.0, spiritMilliliters = spirit)!!
        val landed = Proofing.proofAfterAdding(
            waterMilliliters = needed, fromProof = 124.0, spiritMilliliters = spirit,
        )
        assertNotNull(landed)
        assertEquals(100.0, landed, 0.01)
    }

    @Test
    fun `no water changes nothing, and too much is refused`() {
        assertEquals(
            124.0,
            Proofing.proofAfterAdding(waterMilliliters = 0.0, fromProof = 124.0, spiritMilliliters = 44.0),
        )
        assertNull(
            Proofing.proofAfterAdding(waterMilliliters = 10_000.0, fromProof = 124.0, spiritMilliliters = 44.0),
            "past the bottom of the table there is no answer to give",
        )
    }

    @Test
    fun `a kitchen measure sits beside the number`() {
        assertEquals("0.5 ml — a few drops", Proofing.describe(0.5))
        assertEquals("1.2 ml — about ¼ teaspoon", Proofing.describe(1.2))
        assertEquals("4.9 ml — about 1 teaspoon", Proofing.describe(4.93))
        assertEquals("6.2 ml — about 1¼ teaspoons", Proofing.describe(6.2))
        assertEquals("12.4 ml — about 2½ teaspoons", Proofing.describe(12.42))
    }

    @Test
    fun `a volume no spoon measures does not trap`() {
        // A pour size typed as a wall of digits reaches here as a number the
        // teaspoon count cannot hold.
        assertTrue(Proofing.describe(1e12).startsWith("1000000000000.0 ml"))
        assertEquals("—", Proofing.describe(Double.NaN))
        assertEquals("—", Proofing.describe(-1.0))
    }
}

class WeighingTest {

    @Test
    fun `density is the table's, to the fifth decimal`() {
        assertEquals(0.93220, Weighing.density(100.0)!!, 0.00005)
        assertEquals(0.94970, Weighing.density(80.0)!!, 0.00005)
        assertEquals(0.91140, Weighing.density(120.0)!!, 0.00005)
        assertNull(Weighing.density(160.0), "outside Table 6 there is no density to give")
    }

    @Test
    fun `a stronger spirit is lighter`() {
        // Alcohol is less dense than water, so this ordering is the physics
        // and not an accident of the transcription.
        assertTrue(Weighing.density(140.0)!! < Weighing.density(100.0)!!)
        assertTrue(Weighing.density(100.0)!! < Weighing.density(60.0)!!)
    }

    @Test
    fun `the tare is measured once, at a level already known`() {
        // A new 750 at 100 proof: 750 ml weighs 699.15 g, so a 1200 g gross
        // is a 500 g bottle.
        val whiskey = 750 * Weighing.density(100.0)!!
        val tare = Weighing.tare(grossGrams = 500 + whiskey, knownMilliliters = 750.0, proof = 100.0)
        assertNotNull(tare)
        assertEquals(500.0, tare, 0.01)
    }

    @Test
    fun `a weighing lighter than the whiskey alone is refused`() {
        assertNull(Weighing.tare(grossGrams = 100.0, knownMilliliters = 750.0, proof = 100.0))
        assertNull(Weighing.tare(grossGrams = 0.0, knownMilliliters = 750.0, proof = 100.0))
        assertNull(Weighing.tare(grossGrams = 1200.0, knownMilliliters = 750.0, proof = 160.0))
    }

    @Test
    fun `weighing and taring are inverses`() {
        val tare = 500.0
        val gross = tare + 375 * Weighing.density(124.0)!!
        val left = Weighing.remainingMilliliters(grossGrams = gross, tareGrams = tare, proof = 124.0)
        assertNotNull(left)
        assertEquals(375.0, left, 0.01)
    }

    @Test
    fun `an empty bottle reads zero rather than a negative volume`() {
        val left = Weighing.remainingMilliliters(grossGrams = 480.0, tareGrams = 500.0, proof = 100.0)
        assertEquals(0.0, left)
    }
}

class PriceCheckTest {

    private fun reference(cents: Int, year: Int? = 2026) =
        PriceReference(cents = cents, source = "Virginia ABC", asOfYear = year)

    @Test
    fun `under the shelf price is the good answer`() {
        val result = PriceCheck.compare(paidCents = 5_999, reference = reference(6_999))
        assertEquals(PriceCheck.Band.AT_OR_BELOW, result.band)
        assertEquals(-1_000, result.differenceCents)
        assertEquals("At or under shelf price", result.headline)
    }

    @Test
    fun `the bands are deliberately wide, because shelf prices vary by state`() {
        assertEquals(PriceCheck.Band.SLIGHTLY_OVER,
            PriceCheck.compare(10_500, reference(10_000)).band, "5% over")
        assertEquals(PriceCheck.Band.SLIGHTLY_OVER,
            PriceCheck.compare(11_000, reference(10_000)).band, "exactly 10%, still slight")
        assertEquals(PriceCheck.Band.WELL_OVER,
            PriceCheck.compare(13_000, reference(10_000)).band, "30% over")
        assertEquals(PriceCheck.Band.WELL_OVER,
            PriceCheck.compare(14_000, reference(10_000)).band, "exactly 40%")
        assertEquals(PriceCheck.Band.FAR_OVER,
            PriceCheck.compare(30_000, reference(10_000)).band, "three times shelf")
    }

    @Test
    fun `no reference says so rather than guessing`() {
        val result = PriceCheck.compare(paidCents = 9_999, reference = null)
        assertEquals(PriceCheck.Band.NO_REFERENCE, result.band)
        assertNull(result.differenceCents)
        assertNull(result.fractionOver)
        assertEquals("No published shelf price for this bottle.", result.caveat)

        // A reference with no money in it is no reference.
        assertEquals(PriceCheck.Band.NO_REFERENCE, PriceCheck.compare(9_999, reference(0)).band)
    }

    @Test
    fun `the caveat names the source and refuses to be a resale value`() {
        val result = PriceCheck.compare(paidCents = 9_999, reference = reference(6_999))
        assertEquals(
            "Compared with the Virginia ABC shelf price (2026). Not a resale value.",
            result.caveat,
        )
        assertEquals(
            "Compared with the Virginia ABC shelf price. Not a resale value.",
            PriceCheck.compare(9_999, reference(6_999, year = null)).caveat,
        )
    }

    @Test
    fun `cost per pour needs no published data at all`() {
        // The more useful number day to day: an intimidating bottle price
        // becomes the price of a drink.
        assertEquals(400, PriceCheck.costPerPourCents(6_800, 750.0))
        assertNull(PriceCheck.costPerPourCents(0, 750.0))
    }
}
