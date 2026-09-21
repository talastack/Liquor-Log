package com.talastack.liquorlog.engine

import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertFalse
import kotlin.test.assertNull
import kotlin.test.assertTrue

/**
 * Reading a label is regular expressions over recognised text, not a model --
 * so unlike the camera half, all of it is testable on any machine.
 *
 * The bar these have to clear: a misread proof that silently becomes a
 * bottle's strength poisons cost-per-pour, the perceived-proof verdict and
 * the shelf check at once, and unlike a typo nobody would know they had made
 * it.
 */
class LabelReaderTest {

    @Test
    fun `it reads proof from a label`() {
        val reading = LabelReader.read(listOf("ELIJAH CRAIG", "BARREL PROOF", "124.2 PROOF"))
        assertEquals(124.2, reading.proof ?: 0.0, 0.01)
        assertEquals(62.1, reading.abv ?: 0.0, 0.01)
    }

    @Test
    fun `it reads proof written the other way round`() {
        assertEquals(107.0, LabelReader.read(listOf("PROOF: 107")).proof ?: 0.0, 0.01)
    }

    @Test
    fun `it reads ABV and derives proof`() {
        val reading = LabelReader.read(listOf("45% ALC/VOL"))
        assertEquals(45.0, reading.abv ?: 0.0, 0.01)
        assertEquals(90.0, reading.proof ?: 0.0, 0.01)
    }

    /**
     * Proof is printed larger and is the number people read off a label, so
     * when both are present the proof decides. Deriving the wrong way round is
     * how a bottle gets recorded at half its strength.
     */
    @Test
    fun `proof wins when both are printed`() {
        val reading = LabelReader.read(listOf("62.1% ALC/VOL", "124.2 PROOF"))
        assertEquals(62.1, reading.abv ?: 0.0, 0.01)
    }

    /** Labels print mashbill percentages too. A "%" over 95 is not a strength. */
    @Test
    fun `a mashbill percentage is not mistaken for strength`() {
        val reading = LabelReader.read(listOf("MASHBILL: 99% CORN"))
        assertNull(reading.abv, "99% is a grain share, not a strength")
    }

    /**
     * And the mashbill must not shadow the real one. Taking only the FIRST
     * percentage would find 99, reject it, and lose the 45 further down.
     */
    @Test
    fun `a mashbill does not hide the strength below it`() {
        val reading = LabelReader.read(
            listOf("MASHBILL: 99% CORN 1% MALTED BARLEY", "45% ALC/VOL")
        )
        assertEquals(45.0, reading.abv ?: 0.0, 0.01)
    }

    /** A bare number is not a proof. Labels are covered in numbers. */
    @Test
    fun `a bare number is not taken as proof`() {
        assertNull(LabelReader.read(listOf("ESTABLISHED 1789", "LOT 4211")).proof)
    }

    @Test
    fun `it reads an Elijah Craig batch code`() {
        assertEquals("B523", LabelReader.read(listOf("BATCH B523")).batchCode)
    }

    @Test
    fun `it reads a barrel number`() {
        assertEquals("42-3C", LabelReader.read(listOf("BARREL NO. 42-3C")).barrelNumber)
    }

    /**
     * Validated against the ten real codes rather than matched by shape, so
     * any other four-letter word on the label is not mistaken for one.
     */
    @Test
    fun `it recognises a Four Roses recipe code`() {
        val reading = LabelReader.read(listOf("FOUR ROSES", "SINGLE BARREL", "OESQ"))
        assertEquals("OESQ", reading.recipeCode)
    }

    @Test
    fun `a four-letter word is not a recipe code`() {
        val reading = LabelReader.read(listOf("FOUR ROSES", "MASH", "OAKY", "CASK"))
        assertNull(reading.recipeCode)
    }

    /**
     * The etching on the glass, as the recogniser returns it: its own line, or
     * run together with the label text.
     */
    @Test
    fun `it reads a Buffalo Trace laser code`() {
        val own = LabelReader.read(listOf("BLANTON'S", "L19274 15:02 K"))
        assertEquals(2019, own.laserCode?.year)
        assertEquals(274, own.laserCode?.dayOfYear)
        val inline = LabelReader.read(listOf("KENTUCKY STRAIGHT BOURBON L21045 750 ML"))
        assertEquals(45, inline.laserCode?.dayOfYear)
        assertNull(LabelReader.read(listOf("BATCH B523", "94 PROOF")).laserCode)
        assertNull(
            LabelReader.read(listOf("BOTTLE", "12345")).laserCode,
            "a bare bottle number is not a date"
        )
    }

    @Test
    fun `it reads an age statement`() {
        assertEquals(12, LabelReader.read(listOf("AGED 12 YEARS")).statedAgeYears)
        assertEquals(10, LabelReader.read(listOf("10 YEARS OLD")).statedAgeYears)
    }

    @Test
    fun `it reads the size`() {
        assertEquals(750.0, LabelReader.read(listOf("750 ML")).volumeMilliliters)
        assertEquals(1750.0, LabelReader.read(listOf("1.75 L")).volumeMilliliters)
    }

    @Test
    fun `it notices the production claims`() {
        val reading = LabelReader.read(
            listOf("KENTUCKY STRAIGHT BOURBON", "BOTTLED IN BOND", "SINGLE BARREL")
        )
        assertTrue(reading.isBottledInBond)
        assertTrue(reading.isSingleBarrel)
        assertFalse(reading.isSmallBatch)
    }

    /**
     * The warning text is the largest block on many labels and would drag any
     * search straight away from the brand.
     */
    @Test
    fun `the government warning is not taken for a name`() {
        val lines = LabelReader.nameLines(
            listOf(
                "ELIJAH CRAIG",
                "GOVERNMENT WARNING: ACCORDING TO THE SURGEON GENERAL",
                "WOMEN SHOULD NOT DRINK ALCOHOLIC BEVERAGES DURING PREGNANCY"
            )
        )
        assertEquals(listOf("ELIJAH CRAIG"), lines)
    }

    @Test
    fun `measures are not taken for a name`() {
        assertEquals(
            listOf("WELLER"),
            LabelReader.nameLines(listOf("750 ML", "124.2 PROOF", "WELLER"))
        )
    }

    @Test
    fun `short fragments are dropped`() {
        assertEquals(
            listOf("BUFFALO TRACE"),
            LabelReader.nameLines(listOf("A", "OF", "BUFFALO TRACE"))
        )
    }

    @Test
    fun `it suggests catalogue matches`() {
        val catalog = listOf(
            SearchCandidate(
                product = ProductIdentity(
                    productId = "ec-barrel-proof", distillery = "Heaven Hill",
                    brand = "Elijah Craig", expression = "Barrel Proof",
                    classType = ClassType.KENTUCKY_STRAIGHT_BOURBON,
                    productionType = ProductionType.SMALL_BATCH
                )
            ),
            SearchCandidate(
                product = ProductIdentity(
                    productId = "buffalo-trace", distillery = "Buffalo Trace",
                    brand = "Buffalo Trace", expression = "",
                    classType = ClassType.KENTUCKY_STRAIGHT_BOURBON,
                    productionType = ProductionType.UNSPECIFIED
                )
            )
        )

        val reading = LabelReader.read(
            listOf("ELIJAH CRAIG", "BARREL PROOF", "124.2 PROOF", "750 ML")
        )
        val hits = LabelReader.candidates(reading, catalog)
        assertEquals("ec-barrel-proof", hits.firstOrNull()?.product?.productId)
    }

    /**
     * A photo of a wall returns nothing, and must produce nothing rather than
     * a confident wrong answer.
     */
    @Test
    fun `an unreadable label suggests nothing`() {
        val reading = LabelReader.read(emptyList())
        assertTrue(reading.isEmpty)
        assertTrue(LabelReader.candidates(reading, emptyList()).isEmpty())
    }

    /**
     * The recogniser returns lines in the order it found them, which on a
     * wrap-around label is not reading order.
     */
    @Test
    fun `line order does not matter`() {
        val forwards = LabelReader.read(listOf("ELIJAH CRAIG", "BATCH B523", "124.2 PROOF"))
        val backwards = LabelReader.read(listOf("124.2 PROOF", "BATCH B523", "ELIJAH CRAIG"))
        assertEquals(forwards.proof, backwards.proof)
        assertEquals(forwards.batchCode, backwards.batchCode)
    }

    /** Recognition is case-noisy in practice. */
    @Test
    fun `it tolerates lowercase`() {
        val reading = LabelReader.read(listOf("elijah craig", "batch b523", "124.2 proof"))
        assertEquals("B523", reading.batchCode)
        assertEquals(124.2, reading.proof ?: 0.0, 0.01)
    }
}

/**
 * The Buffalo Trace problem. Eagle Rare, Blanton's and Weller all print
 * "Buffalo Trace Distillery" on the label, and a search over the raw text
 * matches every Buffalo Trace product and ranks them by noise.
 */
class LabelReaderRankingTest {

    private fun product(
        id: String, brand: String, expression: String = "",
        distillery: String = "Buffalo Trace"
    ) = SearchCandidate(
        product = ProductIdentity(
            productId = id, distillery = distillery, brand = brand,
            expression = expression, classType = ClassType.KENTUCKY_STRAIGHT_BOURBON
        )
    )

    private val buffaloTraceFamily = listOf(
        product("buffalo-trace", "Buffalo Trace"),
        product("eagle-rare-10", "Eagle Rare", "10 Year"),
        product("blantons", "Blanton's", "Original Single Barrel"),
        product("weller-sr", "W L Weller", "Special Reserve"),
        product("stagg", "Stagg")
    )

    /** The bottle being held is Eagle Rare. The distillery line must not win. */
    @Test
    fun `the brand on the label outranks the distillery on the label`() {
        val reading = LabelReader.read(
            listOf(
                "EAGLE RARE", "KENTUCKY STRAIGHT BOURBON WHISKEY", "10 YEARS OLD",
                "BUFFALO TRACE DISTILLERY", "FRANKFORT, KENTUCKY"
            )
        )
        val hits = LabelReader.candidates(reading, buffaloTraceFamily)
        assertEquals("eagle-rare-10", hits.firstOrNull()?.product?.productId)
    }

    /** And when the bottle IS Buffalo Trace, it still wins. */
    @Test
    fun `Buffalo Trace itself still comes first`() {
        val reading = LabelReader.read(
            listOf("BUFFALO TRACE", "KENTUCKY STRAIGHT BOURBON WHISKEY")
        )
        val hits = LabelReader.candidates(reading, buffaloTraceFamily)
        assertEquals("buffalo-trace", hits.firstOrNull()?.product?.productId)
    }

    /** Possessive brands must match their apostrophe-free OCR form. */
    @Test
    fun `a possessive brand matches without its apostrophe`() {
        val reading = LabelReader.read(
            listOf("BLANTONS", "THE ORIGINAL SINGLE BARREL", "BUFFALO TRACE DISTILLERY")
        )
        val hits = LabelReader.candidates(reading, buffaloTraceFamily)
        assertEquals("blantons", hits.firstOrNull()?.product?.productId)
    }

    /**
     * A stable partition: within each group the search's own order survives,
     * so this cannot make a good match worse.
     */
    @Test
    fun `ranking is a partition, not a reshuffle`() {
        val hits = listOf(
            SearchHit(buffaloTraceFamily[0].product, 0.9, SearchHit.Reason.FUZZY),
            SearchHit(buffaloTraceFamily[1].product, 0.8, SearchHit.Reason.FUZZY),
            SearchHit(buffaloTraceFamily[4].product, 0.7, SearchHit.Reason.FUZZY)
        )
        val ranked = LabelReader.rankBrandFirst(hits, "stagg buffalo trace distillery")
        // Stagg and Buffalo Trace both have their brand present; their relative
        // order is preserved. Eagle Rare drops behind both.
        assertEquals(
            listOf("buffalo-trace", "stagg", "eagle-rare-10"),
            ranked.map { it.product.productId }
        )
    }

    /**
     * The attribution line is stripped BEFORE ranking, or "buffalo trace"
     * leaks into the reading and Buffalo Trace counts as brand-present on a
     * bottle that is not it.
     */
    @Test
    fun `the distillery attribution line is not part of the name`() {
        val lines = LabelReader.nameLines(
            listOf("EAGLE RARE", "BUFFALO TRACE DISTILLERY", "FRANKFORT KENTUCKY")
        )
        assertEquals(listOf("EAGLE RARE", "FRANKFORT KENTUCKY"), lines)
    }
}
