package com.talastack.liquorlog.engine

import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertNotNull
import kotlin.test.assertNull
import kotlin.test.assertTrue

/**
 * The shipped JSON is validated by `scripts/check_flavor_wheel.py`, which
 * runs on the free Linux job. These cover the lookups and the rules against
 * fixtures -- so a structural bug is caught here even if the data file is
 * fine. Swift's decoding tests have no counterpart: the JSON belongs to the
 * data layer on this side.
 */
class FlavorWheelTest {

    private fun descriptor(
        key: String, label: String, origin: FlavorOrigin,
        compound: String? = null, why: String? = null
    ) = FlavorDescriptor(key = key, label = label, origin = origin, compound = compound, why = why)

    private val sample = FlavorWheel(
        version = 1,
        name = "Test wheel",
        families = listOf(
            FlavorFamily(
                "sweet", "Sweet",
                listOf(
                    descriptor(
                        "vanilla", "Vanilla", FlavorOrigin.MATURATION,
                        compound = "vanillin", why = "Oak lignin under char."
                    ),
                    descriptor("honey", "Honey", FlavorOrigin.MATURATION)
                )
            ),
            FlavorFamily(
                "grain", "Grain",
                listOf(descriptor("rye-spice", "Rye spice", FlavorOrigin.GRAIN))
            ),
            FlavorFamily(
                "faults", "Off-notes",
                listOf(
                    descriptor("green-apple", "Green apple", FlavorOrigin.OXIDATION),
                    descriptor("sulphur", "Sulphur", FlavorOrigin.FAULT)
                )
            )
        )
    )

    @Test
    fun `families and descriptors`() {
        assertEquals(1, sample.version)
        assertEquals(3, sample.families.size)
        assertEquals(5, sample.allDescriptors.size)
    }

    @Test
    fun `optional fields are optional`() {
        assertEquals("vanillin", sample.descriptor("vanilla")?.compound)
        assertNull(sample.descriptor("honey")?.compound)
        assertNull(sample.descriptor("honey")?.why)
    }

    /**
     * Swift refuses to decode an unknown origin rather than defaulting one.
     * Here the same refusal is the data layer's to make, so the engine gives
     * it a null to refuse on.
     */
    @Test
    fun `an unknown origin resolves to nothing rather than a default`() {
        assertNull(FlavorOrigin.fromStorageKey("vibes"))
        assertEquals(FlavorOrigin.MATURATION, FlavorOrigin.fromStorageKey("maturation"))
    }

    @Test
    fun `descriptor lookup by stored key`() {
        assertEquals("Rye spice", sample.descriptor("rye-spice")?.label)
        assertEquals("grain", sample.familyContaining("rye-spice")?.key)
    }

    /**
     * A tasting note holds a key. A key from a newer wheel must return null so
     * the UI can show the raw key, rather than the note silently vanishing.
     */
    @Test
    fun `an unknown key returns null rather than crashing`() {
        assertNull(sample.descriptor("brand-new-descriptor"))
        assertNull(sample.familyContaining("brand-new-descriptor"))
    }

    /**
     * Origin is what lets the oxidation model reason about which notes arrive
     * as a bottle sits open and which ones flatten.
     */
    @Test
    fun `descriptors can be selected by origin`() {
        assertEquals(
            listOf("green-apple"),
            sample.descriptorsFrom(FlavorOrigin.OXIDATION).map { it.key }
        )
        assertEquals(2, sample.descriptorsFrom(FlavorOrigin.MATURATION).size)
    }

    @Test
    fun `only faults are marked undesirable`() {
        for (origin in FlavorOrigin.entries) {
            assertEquals(origin == FlavorOrigin.FAULT, origin.isUndesirable, "$origin")
        }
    }

    @Test
    fun `every origin has a label`() {
        for (origin in FlavorOrigin.entries) {
            assertTrue(origin.label.isNotEmpty(), "$origin has no label")
        }
    }

    @Test
    fun `a clean wheel has no issues`() {
        assertTrue(sample.validate().isEmpty(), sample.validate().toString())
    }

    /**
     * Keys are stored in tasting notes, so a duplicate makes a saved note
     * ambiguous forever.
     */
    @Test
    fun `duplicate descriptor keys across families are rejected`() {
        val dupe = FlavorWheel(
            1, "x",
            listOf(
                FlavorFamily("a", "A", listOf(descriptor("oak", "Oak", FlavorOrigin.MATURATION))),
                FlavorFamily("b", "B", listOf(descriptor("oak", "Oak", FlavorOrigin.MATURATION)))
            )
        )
        assertTrue(dupe.validate().any { it.rule == "descriptor.unique" })
    }

    @Test
    fun `duplicate family keys are rejected`() {
        val dupe = FlavorWheel(
            1, "x",
            listOf(
                FlavorFamily("a", "A", listOf(descriptor("one", "One", FlavorOrigin.GRAIN))),
                FlavorFamily("a", "A again", listOf(descriptor("two", "Two", FlavorOrigin.GRAIN)))
            )
        )
        assertTrue(dupe.validate().any { it.rule == "family.unique" })
    }

    @Test
    fun `an empty family is rejected`() {
        val empty = FlavorWheel(1, "x", listOf(FlavorFamily("a", "A", emptyList())))
        assertTrue(empty.validate().any { it.rule == "family.notEmpty" })
    }

    /**
     * Keys are permanent. An uppercase or spaced key today is a key somebody
     * "tidies" tomorrow, orphaning every note that used it.
     */
    @Test
    fun `unstable keys are rejected`() {
        val loose = FlavorWheel(
            1, "x",
            listOf(
                FlavorFamily(
                    "a", "A",
                    listOf(descriptor("Charred Oak", "Charred oak", FlavorOrigin.MATURATION))
                )
            )
        )
        assertTrue(loose.validate().any { it.rule == "descriptor.keyIsStable" })
    }

    @Test
    fun `a missing label is rejected`() {
        val blank = FlavorWheel(
            1, "x",
            listOf(FlavorFamily("a", "A", listOf(descriptor("oak", "  ", FlavorOrigin.MATURATION))))
        )
        assertTrue(blank.validate().any { it.rule == "descriptor.hasLabel" })
    }

    /**
     * Groups come out in the order the data declares them, not alphabetised
     * -- the common note leads its family, and sorting would bury Caramel
     * under Chocolate.
     */
    @Test
    fun `groups keep the order the data declares`() {
        val family = FlavorFamily(
            "sweet", "Sweet",
            listOf(
                descriptor("caramel", "Caramel", FlavorOrigin.MATURATION).copy(group = "Caramel"),
                descriptor("cocoa", "Cocoa", FlavorOrigin.MATURATION).copy(group = "Chocolate"),
                descriptor("toffee", "Toffee", FlavorOrigin.MATURATION).copy(group = "Caramel"),
                descriptor("honey", "Honey", FlavorOrigin.MATURATION)
            )
        )
        assertEquals(listOf("Caramel", "Chocolate", "Sweet"), family.groups.map { it.name })
        assertEquals(
            listOf("caramel", "toffee"),
            family.groups.first().descriptors.map { it.key }
        )
    }
}

/**
 * Averages over your own ratings, each with its count, and nothing said
 * below three a side.
 */
class PalateTest {

    private fun t(
        classType: ClassType? = ClassType.KENTUCKY_STRAIGHT_BOURBON,
        abv: Double? = 50.0,
        wheated: Boolean? = null,
        rating: Int? = null,
        heat: Int? = null,
        finish: Int? = null,
        rebuy: Boolean? = null,
        words: List<String> = emptyList()
    ) = Palate.Tasting(
        classType = classType, abv = abv, isWheated = wheated, rating = rating,
        perceivedHeat = heat, finishSeconds = finish, wouldRebuy = rebuy, descriptors = words
    )

    @Test
    fun `words are counted once per tasting, most used first`() {
        val profile = Palate.profile(
            listOf(
                t(words = listOf("caramel", "oak", "caramel")),
                t(words = listOf("caramel", "cherry")),
                t(words = listOf("oak"))
            )
        )
        assertEquals(listOf("caramel", "oak", "cherry"), profile.words.map { it.key })
        assertEquals(2, profile.words.first().count, "twice in one tasting is one use")
    }

    @Test
    fun `ratings by class need three a side`() {
        val profile = Palate.profile(
            listOf(
                t(ClassType.STRAIGHT_RYE, rating = 9),
                t(ClassType.STRAIGHT_RYE, rating = 8),
                t(ClassType.STRAIGHT_RYE, rating = 8),
                t(ClassType.KENTUCKY_STRAIGHT_BOURBON, rating = 6),
                t(ClassType.KENTUCKY_STRAIGHT_BOURBON, rating = 7),
                t(ClassType.KENTUCKY_STRAIGHT_BOURBON, rating = 8),
                t(ClassType.SINGLE_MALT_SCOTCH, rating = 10),
                t(ClassType.SINGLE_MALT_SCOTCH, rating = 10)
            )
        )
        assertEquals(
            listOf("Straight Rye Whiskey", "Kentucky Straight Bourbon Whiskey"),
            profile.byClass.map { it.label }
        )
        assertEquals("8.3", profile.byClass.first().averageText)
        assertEquals(3, profile.byClass.first().count)
        val sentences = Palate.sentences(profile) { it }
        assertTrue(
            sentences.contains(
                "Straight Rye Whiskey rates highest with you: 8.3 on average over 3, " +
                    "against 7.0 for Kentucky Straight Bourbon Whiskey."
            ),
            sentences.toString()
        )
    }

    @Test
    fun `strength bands run strongest first and read as a sentence`() {
        val profile = Palate.profile(
            listOf(
                t(abv = 62.0, rating = 9), t(abv = 60.0, rating = 9), t(abv = 65.0, rating = 8),
                t(abv = 43.0, rating = 6), t(abv = 44.0, rating = 7), t(abv = 41.0, rating = 6)
            )
        )
        assertEquals(
            listOf("115 proof and up", "80–89 proof"),
            profile.byStrength.map { it.label }
        )
        val sentences = Palate.sentences(profile) { it }
        assertTrue(sentences.any { it.startsWith("The stronger the better") }, sentences.toString())
    }

    @Test
    fun `wheated against the rest`() {
        val profile = Palate.profile(
            listOf(
                t(wheated = true, rating = 9), t(wheated = true, rating = 8),
                t(wheated = true, rating = 9),
                t(wheated = false, rating = 6), t(wheated = false, rating = 7),
                t(wheated = false, rating = 7),
                t(ClassType.SINGLE_MALT_SCOTCH, rating = 8)
            )
        )
        assertEquals("8.7", profile.wheated?.averageText)
        assertEquals("6.7", profile.otherBourbon?.averageText)
        assertTrue(
            Palate.sentences(profile) { it }.any { it.startsWith("Wheated bourbons rate 8.7") }
        )
    }

    @Test
    fun `heat, finish and rebuy`() {
        val profile = Palate.profile(
            listOf(
                t(rating = 6, heat = 5, finish = 30, rebuy = true),
                t(rating = 6, heat = 4, finish = 60, rebuy = false),
                t(rating = 5, heat = 5, finish = 45, rebuy = true),
                t(rating = 8, heat = 1, rebuy = true),
                t(rating = 9, heat = 2),
                t(rating = 8, heat = 2)
            )
        )
        assertEquals(45, profile.averageFinishSeconds)
        assertEquals(0.75, profile.rebuyShare ?: 0.0, 0.0001)
        val sentences = Palate.sentences(profile) { it }
        assertTrue(sentences.any { it.startsWith("Heat costs a bottle points with you") })
        assertTrue(sentences.contains("A finish runs about 45 seconds by your count."))
        assertTrue(sentences.contains("You would buy again 8 of every 10 you rated."))
    }

    /**
     * The same bottle rated blind and knowing what it was, paired by product;
     * the average gap is the label's worth to you.
     */
    @Test
    fun `label bias pairs blind and sighted ratings of the same bottle`() {
        val profile = Palate.profile(
            listOf(
                t(rating = 9).copy(productId = "w12"),
                t(rating = 7).copy(productId = "w12", isBlind = true),
                t(rating = 8).copy(productId = "ec"),
                t(rating = 6).copy(productId = "ec", isBlind = true),
                t(rating = 8).copy(productId = "ec", isBlind = true),
                t(rating = 7).copy(productId = "fr"),
                t(rating = 7).copy(productId = "fr", isBlind = true),
                t(rating = 10).copy(productId = "lonely")
            )
        )
        // w12: 9 - 7 = 2; ec: 8 - 7 = 1; fr: 0 -> 1.0 over three pairs.
        assertEquals(3, profile.labelBiasPairs)
        assertEquals(1.0, profile.labelBias ?: 0.0, 0.0001)
        val sentences = Palate.sentences(profile) { it }
        assertTrue(
            sentences.any { it.startsWith("Knowing the label adds 1.0 points") },
            sentences.toString()
        )
    }

    @Test
    fun `two pairs are not a bias`() {
        val profile = Palate.profile(
            listOf(
                t(rating = 9).copy(productId = "a"),
                t(rating = 5).copy(productId = "a", isBlind = true),
                t(rating = 9).copy(productId = "b"),
                t(rating = 5).copy(productId = "b", isBlind = true)
            )
        )
        assertNull(profile.labelBias)
    }

    /** Two tastings say nothing yet. Silence is the honest profile. */
    @Test
    fun `too few says nothing`() {
        val profile = Palate.profile(
            listOf(t(rating = 9, words = listOf("oak")), t(rating = 3, words = listOf("oak")))
        )
        assertTrue(profile.byClass.isEmpty())
        assertNull(profile.rebuyShare)
        assertTrue(Palate.sentences(profile) { it }.isEmpty())
        assertTrue(Palate.profile(emptyList()).isEmpty)
    }

    @Test
    fun `the bands sit where the proof does`() {
        assertEquals("80–89 proof", Palate.band(43.0))
        assertEquals("90–99 proof", Palate.band(47.0))
        assertEquals("100–114 proof", Palate.band(50.0))
        assertEquals("115 proof and up", Palate.band(57.5))
    }
}
