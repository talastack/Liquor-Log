package com.talastack.liquorlog.engine

import java.time.Instant
import java.time.LocalDate
import java.time.ZoneId
import java.time.ZoneOffset
import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertFalse
import kotlin.test.assertNotNull
import kotlin.test.assertNull
import kotlin.test.assertTrue

/**
 * The shareable pick record. Fixed shape, so a registry can parse it back
 * without a person in the loop.
 */
class PickCardTest {

    private val utc: ZoneId = ZoneOffset.UTC

    @Test
    fun `it writes one key per line in a fixed order`() {
        val text = PickCard.text(
            PickCard.Pick(
                product = "Four Roses Single Barrel",
                pickedBy = "Bourbon Society",
                store = "Total Wine",
                barrel = "42-3C",
                recipeCode = "OESQ",
                warehouse = "QN",
                proof = 112.4,
                ageMonths = 112
            ),
            utc
        )
        val lines = text.split("\n")
        assertEquals("Pick: Four Roses Single Barrel", lines[0])
        assertEquals("Picked by: Bourbon Society", lines[1])
        assertEquals("Store: Total Wine", lines[2])
        assertEquals("Barrel: 42-3C", lines[3])
        assertTrue(lines[4].startsWith("Recipe: OESQ"), lines[4])
        assertEquals("Warehouse: QN", lines[5])
        assertEquals("Proof: 112.4", lines[6])
        assertEquals("Age: 9 years 4 months", lines[7])
    }

    /** A reader who does not know what OESQ means gets the answer inline. */
    @Test
    fun `a recipe code is decoded on its own line`() {
        val text = PickCard.text(PickCard.Pick(product = "x", recipeCode = "OESQ"), utc)
        assertTrue(text.contains("75% corn, 20% rye, 5% malted barley"), text)
        assertTrue(text.contains("floral essence yeast"), text)
    }

    @Test
    fun `blank fields are omitted, not printed as empty`() {
        val text = PickCard.text(PickCard.Pick(product = "x", barrel = "7"), utc)
        assertEquals("Pick: x\nBarrel: 7", text)
        assertFalse(text.contains("Warehouse"))
    }

    /** The months are the reason the pick was chosen. */
    @Test
    fun `age keeps the months`() {
        assertEquals("9 years 4 months", PickCard.ageText(112))
        assertEquals("10 years", PickCard.ageText(120))
        assertEquals("7 months", PickCard.ageText(7))
    }

    @Test
    fun `bottle number reads as of batch`() {
        val both = PickCard.text(
            PickCard.Pick(product = "x", bottleNumber = 47, bottlesInBatch = 240), utc
        )
        assertTrue(both.contains("Bottle: 47 of 240"), both)
        val countOnly = PickCard.text(PickCard.Pick(product = "x", bottlesInBatch = 240), utc)
        assertTrue(countOnly.contains("Bottles: 240"), countOnly)
    }

    @Test
    fun `the dump date is ISO`() {
        val date = LocalDate.of(2025, 5, 10).atStartOfDay(utc).toInstant()
        val text = PickCard.text(PickCard.Pick(product = "Blanton's", dumpedAt = date), utc)
        assertTrue(text.contains("Dumped: 2025-05-10"), text)
    }

    /**
     * A standard release is not a pick, and a card with only a name would be
     * noise in a registry.
     */
    @Test
    fun `a standard release has nothing to share`() {
        assertFalse(PickCard.Pick(product = "Buffalo Trace", proof = 90.0).hasBarrelDetail)
        assertTrue(PickCard.Pick(product = "Buffalo Trace", barrel = "12").hasBarrelDetail)
    }

    /** Plain text, no markup, so it survives every paste target. */
    @Test
    fun `it is plain text`() {
        val text = PickCard.text(
            PickCard.Pick(product = "x", pickedBy = "y", barrel = "1"), utc
        )
        assertFalse(text.contains("<"))
        assertFalse(text.contains("*"))
        assertFalse(text.contains("|"))
    }
}

/**
 * What you paid before, and nobody else's idea of what it is worth.
 *
 * The Swift side has no tests of its own here -- it is exercised through
 * the screens -- so these pin the two things that would drift silently:
 * that the typical price is a median rather than a mean, and where the
 * deliberately wide bands fall.
 */
class PriceHistoryTest {

    private fun bought(cents: Int, shelf: Int? = null, day: Int? = null) = PriceHistory.Purchase(
        cents = cents,
        shelfCents = shelf,
        purchasedAt = day?.let { Instant.EPOCH.plusSeconds(it * 86_400L) }
    )

    @Test
    fun `a bottle you have never bought has no summary`() {
        assertNull(PriceHistory.summarise(emptyList()))
        assertNull(PriceHistory.summarise(listOf(bought(0))), "a price of nothing is not a price")
    }

    @Test
    fun `one purchase reads as one purchase`() {
        val summary = assertNotNull(PriceHistory.summarise(listOf(bought(4_999))))
        assertEquals(1, summary.count)
        assertEquals(4_999, summary.typicalCents)
        assertEquals("You paid \$49.99 for this before.", summary.summary)
    }

    /**
     * The median, not the mean. One duty-free bottle would drag an average
     * somewhere nobody actually shops.
     */
    @Test
    fun `the typical price is a median`() {
        val summary = assertNotNull(
            PriceHistory.summarise(listOf(bought(4_000), bought(5_000), bought(60_000)))
        )
        assertEquals(5_000, summary.typicalCents, "the mean would be 23,000")
        assertEquals(4_000, summary.lowestCents)
        assertEquals(60_000, summary.highestCents)
    }

    @Test
    fun `an even number of purchases averages the middle pair`() {
        val summary = assertNotNull(
            PriceHistory.summarise(
                listOf(bought(4_000), bought(5_000), bought(6_000), bought(7_000))
            )
        )
        assertEquals(5_500, summary.typicalCents)
    }

    @Test
    fun `one price every time does not print as a range`() {
        val summary = assertNotNull(
            PriceHistory.summarise(listOf(bought(5_000), bought(5_000)))
        )
        assertTrue(summary.isSinglePrice)
        assertEquals("You have paid \$50.00 each of the 2 times you bought this.", summary.summary)
    }

    @Test
    fun `a spread prints as a range`() {
        val summary = assertNotNull(
            PriceHistory.summarise(listOf(bought(4_000), bought(5_000), bought(6_000)))
        )
        assertEquals("You have bought this 3 times, from \$40.00 to \$60.00.", summary.summary)
    }

    @Test
    fun `the most recent purchase is the latest dated one`() {
        val summary = assertNotNull(
            PriceHistory.summarise(
                listOf(bought(4_000, day = 10), bought(9_000, day = 400), bought(5_000, day = 200))
            )
        )
        assertEquals(9_000, summary.mostRecent?.cents)
    }

    /** Bands are wide and unalarming on purpose. */
    @Test
    fun `the bands sit where they are documented`() {
        val history = assertNotNull(
            PriceHistory.summarise(listOf(bought(5_000), bought(5_000), bought(5_000)))
        )
        assertEquals(PriceHistory.Verdict.CHEAPER_THAN_USUAL, PriceHistory.compare(4_400, history))
        assertEquals(PriceHistory.Verdict.ABOUT_WHAT_YOU_PAY, PriceHistory.compare(4_600, history))
        assertEquals(
            PriceHistory.Verdict.ABOUT_WHAT_YOU_PAY, PriceHistory.compare(5_500, history),
            "exactly ten per cent over is still the same price"
        )
        assertEquals(PriceHistory.Verdict.MORE_THAN_USUAL, PriceHistory.compare(5_600, history))
        assertEquals(
            PriceHistory.Verdict.MORE_THAN_USUAL, PriceHistory.compare(7_000, history),
            "exactly forty per cent over is the last of the quiet band"
        )
        assertEquals(
            PriceHistory.Verdict.MUCH_MORE_THAN_USUAL, PriceHistory.compare(7_100, history)
        )
    }

    @Test
    fun `no history is its own verdict, never a guess`() {
        assertEquals(PriceHistory.Verdict.NO_HISTORY, PriceHistory.compare(5_000, null))
        assertEquals(
            "You have not bought this before",
            PriceHistory.Verdict.NO_HISTORY.headline
        )
    }

    /**
     * The reference is built from shelves the person stood in front of, and
     * from nothing at all until there is one.
     */
    @Test
    fun `the shelf reference needs a shelf price`() {
        assertNull(PriceHistory.shelfReference(listOf(bought(5_000))))
        val one = assertNotNull(PriceHistory.shelfReference(listOf(bought(4_500, shelf = 5_999))))
        assertEquals(5_999, one.cents)
        assertEquals("the shelf price you recorded", one.source)
    }

    @Test
    fun `several shelf prices become a median and say how many`() {
        val reference = assertNotNull(
            PriceHistory.shelfReference(
                listOf(
                    bought(1, shelf = 4_000),
                    bought(1, shelf = 6_000),
                    bought(1, shelf = 5_000),
                    bought(1, shelf = 0)
                ),
                asOfYear = 2026
            )
        )
        assertEquals(5_000, reference.cents, "the zero is not a shelf price")
        assertEquals("the 3 shelf prices you recorded", reference.source)
        assertEquals(2026, reference.asOfYear)
    }
}
