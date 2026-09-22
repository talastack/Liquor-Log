package com.talastack.liquorlog.engine

import java.time.Instant
import java.time.ZoneId
import java.time.ZoneOffset
import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertFalse
import kotlin.test.assertNull
import kotlin.test.assertTrue

/**
 * The rule these exist to hold: everything counts the COLLECTION, never the
 * drinking. Nothing here may go up because somebody drank more.
 */
class CollectionStatsTest {

    /** Fixed to UTC so a year boundary lands where the dates say it does. */
    private val utc: ZoneId = ZoneOffset.UTC

    private fun day(n: Long): Instant = Instant.EPOCH.plusSeconds(n * 86_400)

    private fun entry(
        classType: ClassType? = ClassType.KENTUCKY_STRAIGHT_BOURBON,
        distillery: String? = "Heaven Hill",
        abv: Double? = 47.0,
        open: Boolean = false,
        finished: Boolean = false,
        ageMonths: Int? = null
    ) = CollectionStats.Entry(
        classType = classType, distillery = distillery, abv = abv,
        isOpen = open, isFinished = finished, ageMonths = ageMonths,
        addedAt = day(0)
    )

    /** A collection is what you have, not what you have had. */
    @Test
    fun `finished bottles are counted apart and never folded in`() {
        val summary = CollectionStats.summarise(
            listOf(entry(), entry(), entry(finished = true)), day(100), utc
        )
        assertEquals(2, summary.onShelf)
        assertEquals(1, summary.finished)
    }

    @Test
    fun `open and sealed add up to the shelf`() {
        val summary = CollectionStats.summarise(
            listOf(entry(open = true), entry(open = true), entry()), day(100), utc
        )
        assertEquals(2, summary.open)
        assertEquals(1, summary.sealed)
        assertEquals(summary.onShelf, summary.open + summary.sealed)
    }

    /**
     * The whole point of the guardrail: drinking a bottle must not make any
     * number here go up.
     */
    @Test
    fun `finishing a bottle never increases anything`() {
        val before = CollectionStats.summarise(listOf(entry(open = true), entry()), day(100), utc)
        val after = CollectionStats.summarise(
            listOf(entry(finished = true), entry()), day(100), utc
        )
        assertTrue(after.onShelf < before.onShelf)
        assertTrue(after.open <= before.open)
        assertTrue(
            (after.byClass.firstOrNull()?.count ?: 0) <=
                (before.byClass.firstOrNull()?.count ?: 0)
        )
    }

    @Test
    fun `it breaks down by class`() {
        val summary = CollectionStats.summarise(
            listOf(
                entry(ClassType.KENTUCKY_STRAIGHT_BOURBON),
                entry(ClassType.KENTUCKY_STRAIGHT_BOURBON),
                entry(ClassType.STRAIGHT_RYE)
            ),
            day(100), utc
        )
        assertEquals(2, summary.byClass.first().count)
        assertEquals(2, summary.classCount)
    }

    @Test
    fun `it breaks down by distillery`() {
        val summary = CollectionStats.summarise(
            listOf(
                entry(distillery = "Buffalo Trace"),
                entry(distillery = "Buffalo Trace"),
                entry(distillery = "Wild Turkey")
            ),
            day(100), utc
        )
        assertEquals("Buffalo Trace", summary.byDistillery.first().label)
        assertEquals(2, summary.distilleryCount)
    }

    /**
     * The interesting fact is "I own a lot of barrel proof", which four labels
     * say better than a histogram of exact figures.
     */
    @Test
    fun `strength is banded`() {
        assertEquals("80–89 proof", CollectionStats.strengthBand(43.0))
        assertEquals("90–99 proof", CollectionStats.strengthBand(47.0))
        assertEquals("100–114 proof", CollectionStats.strengthBand(50.0))
        assertEquals("115 proof and up", CollectionStats.strengthBand(62.1))
    }

    /** A chart whose order changes between launches reads as a bug. */
    @Test
    fun `equal counts sort alphabetically rather than arbitrarily`() {
        val summary = CollectionStats.summarise(
            listOf(entry(distillery = "Wild Turkey"), entry(distillery = "Buffalo Trace")),
            day(100), utc
        )
        assertEquals(listOf("Buffalo Trace", "Wild Turkey"), summary.byDistillery.map { it.label })
    }

    @Test
    fun `shares are proportions`() {
        val summary = CollectionStats.summarise(
            listOf(
                entry(ClassType.KENTUCKY_STRAIGHT_BOURBON),
                entry(ClassType.KENTUCKY_STRAIGHT_BOURBON),
                entry(ClassType.STRAIGHT_RYE),
                entry(ClassType.STRAIGHT_RYE)
            ),
            day(100), utc
        )
        assertEquals(0.5, summary.byClass.first().share(summary.onShelf))
    }

    @Test
    fun `a share of nothing is zero rather than a crash`() {
        assertEquals(0.0, CollectionStats.Slice("x", 3).share(0))
    }

    /** Rarity and strength work as properties of a bottle. Scoreboards do not. */
    @Test
    fun `it reports the strongest bottle as proof`() {
        val summary = CollectionStats.summarise(
            listOf(entry(abv = 47.0), entry(abv = 62.1)), day(100), utc
        )
        assertEquals(124.2, summary.highestProof ?: 0.0, 0.01)
    }

    @Test
    fun `missing facts are simply absent`() {
        val summary = CollectionStats.summarise(
            listOf(entry(null, distillery = null, abv = null)), day(100), utc
        )
        assertNull(summary.highestProof)
        assertNull(summary.oldestStatedAgeMonths)
        assertTrue(summary.byClass.isEmpty())
        assertEquals(1, summary.onShelf, "a bottle with no facts is still a bottle")
    }

    @Test
    fun `an empty collection is empty`() {
        assertTrue(CollectionStats.summarise(emptyList(), day(100), utc).isEmpty)
    }

    /**
     * Fifty millilitres from a friend is not a bottle. Samples get their own
     * number and stay out of the shelf count and the breakdowns.
     */
    @Test
    fun `samples are counted apart from bottles`() {
        val sample = CollectionStats.Entry(
            classType = ClassType.STRAIGHT_RYE, distillery = "MGP",
            isOpen = true, isSample = true, addedAt = day(0)
        )
        val summary = CollectionStats.summarise(listOf(entry(), entry(), sample), day(100), utc)
        assertEquals(2, summary.onShelf)
        assertEquals(1, summary.samples)
        assertEquals(0, summary.open)
        assertEquals(listOf("Heaven Hill"), summary.byDistillery.map { it.label })
    }

    @Test
    fun `a finished sample is finished, not a sample`() {
        val gone = CollectionStats.Entry(isFinished = true, isSample = true, addedAt = day(0))
        val summary = CollectionStats.summarise(listOf(gone), day(100), utc)
        assertEquals(0, summary.samples)
        assertEquals(1, summary.finished)
    }

    @Test
    fun `only samples is not an empty collection`() {
        val summary = CollectionStats.summarise(
            listOf(CollectionStats.Entry(isSample = true, addedAt = day(0))), day(100), utc
        )
        assertFalse(summary.isEmpty)
    }

    @Test
    fun `brands and places are tallied`() {
        val summary = CollectionStats.summarise(
            listOf(
                CollectionStats.Entry(brand = "Weller", storageLocation = "Cabinet", addedAt = day(0)),
                CollectionStats.Entry(brand = "Weller", storageLocation = "Cabinet", addedAt = day(0)),
                CollectionStats.Entry(brand = "Stagg", storageLocation = " ", addedAt = day(0)),
                CollectionStats.Entry(
                    brand = "Weller", isFinished = true, storageLocation = "Cabinet",
                    addedAt = day(0)
                )
            ),
            day(100), utc
        )
        assertEquals(CollectionStats.Slice("Weller", 2), summary.byBrand.first())
        assertEquals(listOf(CollectionStats.Slice("Cabinet", 2)), summary.byPlace)
    }

    /**
     * Growth of the collection, oldest year first, finished bottles included
     * because they were added that year.
     */
    @Test
    fun `added by year runs oldest first`() {
        val summary = CollectionStats.summarise(
            listOf(
                CollectionStats.Entry(addedAt = day(1_100)),                  // 1973
                CollectionStats.Entry(addedAt = day(10)),                     // 1970
                CollectionStats.Entry(isFinished = true, addedAt = day(20))   // 1970
            ),
            day(2_000), utc
        )
        assertEquals(listOf("1970", "1973"), summary.addedByYear.map { it.label })
        assertEquals(listOf(2, 1), summary.addedByYear.map { it.count })
    }

    @Test
    fun `picks are counted`() {
        val summary = CollectionStats.summarise(
            listOf(
                CollectionStats.Entry(isPick = true, addedAt = day(0)),
                CollectionStats.Entry(isFinished = true, isPick = true, addedAt = day(0)),
                CollectionStats.Entry(addedAt = day(0))
            ),
            day(100), utc
        )
        assertEquals(1, summary.picks)
    }

    @Test
    fun `longest open is the open bottle open longest`() {
        val summary = CollectionStats.summarise(
            listOf(
                CollectionStats.Entry(name = "Weller", isOpen = true, addedAt = day(0), openedAt = day(0)),
                CollectionStats.Entry(name = "Stagg", isOpen = true, addedAt = day(0), openedAt = day(90)),
                CollectionStats.Entry(name = "Sealed", isOpen = false, addedAt = day(0), openedAt = null),
                CollectionStats.Entry(
                    name = "Killed", isOpen = true, isFinished = true,
                    addedAt = day(0), openedAt = day(-400)
                )
            ),
            day(100), utc
        )
        assertEquals(CollectionStats.Standout("Weller", 100), summary.longestOpen)
    }

    @Test
    fun `nothing open means no longest open`() {
        assertNull(
            CollectionStats.summarise(
                listOf(CollectionStats.Entry(name = "x", addedAt = day(0))), day(100), utc
            ).longestOpen
        )
    }

    @Test
    fun `spend groups by purchase year and skips undated`() {
        val summary = CollectionStats.summarise(
            listOf(
                CollectionStats.Entry(
                    addedAt = day(0), purchasePriceCents = 5_000, purchasedAt = day(10)
                ),
                CollectionStats.Entry(
                    addedAt = day(0), purchasePriceCents = 2_500, purchasedAt = day(20)
                ),
                CollectionStats.Entry(
                    addedAt = day(0), purchasePriceCents = 9_000, purchasedAt = day(1_100)
                ),
                // No date: left out rather than guessed.
                CollectionStats.Entry(addedAt = day(0), purchasePriceCents = 9_999),
                CollectionStats.Entry(
                    isFinished = true, addedAt = day(0),
                    purchasePriceCents = 9_999, purchasedAt = day(10)
                )
            ),
            day(2_000), utc
        )
        assertEquals(
            listOf(
                CollectionStats.Amount("1970", 7_500),
                CollectionStats.Amount("1973", 9_000)
            ),
            summary.spentByYear
        )
    }

    @Test
    fun `pour costs`() {
        val summary = CollectionStats.summarise(
            listOf(
                CollectionStats.Entry(name = "Cheap", addedAt = day(0), costPerPourCents = 200),
                CollectionStats.Entry(name = "Dear", addedAt = day(0), costPerPourCents = 1_000),
                CollectionStats.Entry(name = "Unpriced", addedAt = day(0))
            ),
            day(100), utc
        )
        assertEquals(600, summary.averageCostPerPourCents)
        assertEquals("Dear", summary.dearestPour?.name)
        assertEquals("Cheap", summary.cheapestPour?.name)
    }

    @Test
    fun `topper letters only when there are any`() {
        assertNull(
            CollectionStats.summarise(
                listOf(CollectionStats.Entry(addedAt = day(0))), day(100), utc
            ).topperLetters
        )
        val summary = CollectionStats.summarise(
            listOf(
                CollectionStats.Entry(addedAt = day(0), topperLetter = "B"),
                CollectionStats.Entry(addedAt = day(0), topperLetter = "s"),
                // Gone, not on the shelf.
                CollectionStats.Entry(isFinished = true, addedAt = day(0), topperLetter = "L")
            ),
            day(100), utc
        )
        assertEquals(2, summary.topperLetters?.ownedCount)
        assertEquals("B _ _ _ _ _ _ S", summary.topperLetters?.wordLine)
    }

    @Test
    fun `no prices means no average`() {
        assertNull(
            CollectionStats.summarise(
                listOf(CollectionStats.Entry(addedAt = day(0))), day(100), utc
            ).averageCostPerPourCents
        )
    }
}

/**
 * The guest menu. Asked for unprompted in the research and never built until
 * now: *"I really like the menu concept! Now if there was a way to take the
 * spreadsheet and populate the menu......"*
 */
class PourMenuTest {

    @Test
    fun `it lists what is open`() {
        val text = PourMenu.text(
            title = "Open tonight",
            items = listOf(
                PourMenu.Item(name = "Elijah Craig Barrel Proof", proof = 124.2),
                PourMenu.Item(name = "Four Roses Single Barrel", detail = "OESQ", proof = 100.0)
            )
        )
        assertTrue(text.contains("Elijah Craig Barrel Proof"))
        assertTrue(text.contains("124.2 proof"))
        assertTrue(text.contains("OESQ"))
    }

    @Test
    fun `an empty menu says so rather than being blank`() {
        assertTrue(PourMenu.text("Open tonight", emptyList()).contains("Nothing open"))
    }

    /**
     * A menu with prices on it reads as bragging about what the evening cost,
     * and the one thing a guest cannot do with that is enjoy the whiskey.
     */
    @Test
    fun `a menu never carries prices`() {
        val text = PourMenu.text(
            "Open tonight",
            listOf(PourMenu.Item(name = "Weller 12", detail = "wheated", proof = 90.0))
        )
        assertFalse(text.contains("\$"))
    }

    /** It has to survive being pasted into a message, so no markup. */
    @Test
    fun `it is plain text`() {
        val text = PourMenu.text(
            "Open tonight",
            listOf(PourMenu.Item(name = "Weller 12", proof = 90.0))
        )
        assertFalse(text.contains("<"))
        assertFalse(text.contains("*"))
    }
}
