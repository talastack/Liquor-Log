package com.talastack.liquorlog.engine

import java.time.Instant
import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertFalse
import kotlin.test.assertNotEquals
import kotlin.test.assertNotNull
import kotlin.test.assertNull
import kotlin.test.assertTrue

/**
 * The bundled catalogue. Swift's decoding tests have no counterpart here --
 * the JSON belongs to the data layer -- so these cover the lookups,
 * relatedness and the integrity rules, which are what could drift.
 */
class CatalogTest {

    private val catalog = Catalog(
        version = 1,
        products = listOf(
            CatalogProduct(
                id = "ec-small-batch", distillery = "Heaven Hill", brand = "Elijah Craig",
                expression = "Small Batch", classType = ClassType.KENTUCKY_STRAIGHT_BOURBON,
                productionType = ProductionType.SMALL_BATCH, abv = 47.0,
                source = "Producer label"
            ),
            CatalogProduct(
                id = "ec-barrel-proof", distillery = "Heaven Hill", brand = "Elijah Craig",
                expression = "Barrel Proof", classType = ClassType.KENTUCKY_STRAIGHT_BOURBON,
                productionType = ProductionType.SMALL_BATCH, isBarrelProof = true, abv = null,
                source = "Producer label"
            ),
            CatalogProduct(
                id = "four-roses-single-barrel", distillery = "Four Roses", brand = "Four Roses",
                expression = "Single Barrel", classType = ClassType.KENTUCKY_STRAIGHT_BOURBON,
                productionType = ProductionType.SINGLE_BARREL, abv = 50.0, recipeCode = "OBSV",
                source = "Producer label"
            ),
            CatalogProduct(
                id = "weller-antique-107", distillery = "Buffalo Trace", brand = "W L Weller",
                expression = "Antique 107", classType = ClassType.KENTUCKY_STRAIGHT_BOURBON,
                abv = 53.5, mashbillKey = "wheated", source = "Producer label"
            )
        )
    )

    @Test
    fun `omitted fields take their sensible defaults`() {
        assertEquals(4, catalog.products.size)
        val weller = assertNotNull(catalog.product("weller-antique-107"))
        assertEquals(
            ProductionType.UNSPECIFIED, weller.productionType, "omitted means unspecified"
        )
        assertFalse(weller.isBarrelProof)
        assertFalse(weller.verified, "nothing is verified until it is checked")
    }

    /**
     * The strength of a barrel-proof release changes every batch, so a catalog
     * claiming one number would be wrong for almost every bottle on a shelf.
     */
    @Test
    fun `barrel proof carries no strength`() {
        val bp = assertNotNull(catalog.product("ec-barrel-proof"))
        assertNull(bp.abv)
        assertEquals("Varies by batch", bp.strengthDescription)
    }

    @Test
    fun `strength shows both units`() {
        val sb = assertNotNull(catalog.product("ec-small-batch"))
        assertEquals("47.0% ABV · 94.0 proof", sb.strengthDescription)
    }

    @Test
    fun `the recipe code decodes through the engine`() {
        val fr = assertNotNull(catalog.product("four-roses-single-barrel"))
        assertEquals(RecipeCode.Mashbill.B, fr.code?.mashbill)
        assertEquals(RecipeCode.Yeast.V, fr.code?.yeast)
    }

    @Test
    fun `search candidates carry the history boost`() {
        val candidates = catalog.searchCandidates(history = setOf("ec-barrel-proof"))
        val boosted = candidates.filter { it.isInYourHistory }.map { it.product.productId }
        assertEquals(listOf("ec-barrel-proof"), boosted)
    }

    @Test
    fun `search finds a product by abbreviated typing`() {
        val hits = BottleSearch.search("eli cra bar", catalog.searchCandidates())
        assertEquals("ec-barrel-proof", hits.firstOrNull()?.product?.productId)
    }

    /** The line-versus-release distinction, straight out of the catalog. */
    @Test
    fun `two Elijah Craigs are different products on one line`() {
        val sb = assertNotNull(catalog.identity("ec-small-batch"))
        val bp = assertNotNull(catalog.identity("ec-barrel-proof"))
        assertEquals(sb.lineKey, bp.lineKey, "same line")
        assertNotEquals(sb.productId, bp.productId, "different whiskey")
    }

    @Test
    fun `related finds the line`() {
        val hits = catalog.related("ec-small-batch")
        assertEquals("ec-barrel-proof", hits.firstOrNull()?.product?.productId)
        assertEquals(SearchHit.Reason.SAME_LINE, hits.firstOrNull()?.reason)
    }

    @Test
    fun `related to an unknown product is empty rather than everything`() {
        assertTrue(catalog.related("no-such-bottle").isEmpty())
    }

    @Test
    fun `a clean catalog has no issues`() {
        assertTrue(catalog.validate().isEmpty(), catalog.validate().toString())
    }

    /**
     * The engine's abv.missing rule must NOT fire on a barrel-proof row: a
     * missing strength there is the correct value, not a fault.
     */
    @Test
    fun `barrel proof is not reported as missing its strength`() {
        assertFalse(catalog.validate().any { it.rule == "abv.missing" })
    }

    @Test
    fun `a fixed strength on a barrel-proof row is rejected`() {
        val bad = Catalog(
            products = listOf(
                CatalogProduct(
                    id = "x", distillery = "D", brand = "B", classType = ClassType.BOURBON,
                    isBarrelProof = true, abv = 62.1, source = "label"
                )
            )
        )
        assertTrue(bad.validate().any { it.rule == "product.barrelProofHasNoFixedABV" })
    }

    @Test
    fun `a sourceless row is rejected`() {
        val bad = Catalog(
            products = listOf(
                CatalogProduct(
                    id = "x", distillery = "D", brand = "B",
                    classType = ClassType.BOURBON, abv = 45.0
                )
            )
        )
        assertTrue(bad.validate().any { it.rule == "product.hasSource" })
    }

    @Test
    fun `federal rules apply to catalog rows`() {
        // Bonded is exactly 100 proof, and this row claims 94.
        val bad = Catalog(
            products = listOf(
                CatalogProduct(
                    id = "x", distillery = "D", brand = "B",
                    classType = ClassType.STRAIGHT_BOURBON, isBottledInBond = true,
                    abv = 47.0, statedAgeYears = 5, source = "label"
                )
            )
        )
        assertTrue(bad.validate().any { it.rule == "bond.proof" }, bad.validate().toString())
    }

    @Test
    fun `duplicate ids are rejected`() {
        val bad = Catalog(
            products = listOf(
                CatalogProduct(
                    id = "x", distillery = "D", brand = "B",
                    classType = ClassType.BOURBON, abv = 45.0, source = "l"
                ),
                CatalogProduct(
                    id = "x", distillery = "D", brand = "C",
                    classType = ClassType.BOURBON, abv = 45.0, source = "l"
                )
            )
        )
        assertTrue(bad.validate().any { it.rule == "product.unique" })
    }

    @Test
    fun `an empty catalog is valid and searchable`() {
        assertTrue(Catalog.empty.validate().isEmpty())
        assertTrue(BottleSearch.search("anything", Catalog.empty.searchCandidates()).isEmpty())
    }

    /** The file's column names have to keep saying the same thing on both sides. */
    @Test
    fun `the shipped file's column names are pinned`() {
        assertTrue(CatalogProduct.storageKeys.contains("class_type"))
        assertTrue(CatalogProduct.storageKeys.contains("is_barrel_proof"))
        assertTrue(CatalogProduct.storageKeys.contains("allocation_entries"))
        assertEquals(22, CatalogProduct.storageKeys.size)
    }
}

/** The record in order, with the gaps said in days, and nothing inferred. */
class BottleStoryTest {

    private fun day(n: Long): Instant = Instant.EPOCH.plusSeconds(n * 86_400)

    @Test
    fun `a whole life in order, with its gaps`() {
        val facts = BottleStory.Facts(
            name = "Weller 12",
            bottledAt = day(0), bottledText = "From the laser code",
            boughtAt = day(200), boughtWhere = "Total Wine", paidText = "\$79.99",
            openedAt = day(600), finishedAt = day(690),
            pours = listOf(
                BottleStory.Pour(day(601), 44.0),
                BottleStory.Pour(day(620), 60.0, givenTo = "Mike"),
                BottleStory.Pour(day(650), 44.0)
            ),
            tastings = listOf(
                BottleStory.TastingNote(day(601), rating = 7, liked = "toffee"),
                BottleStory.TastingNote(day(680), rating = 9)
            ),
            readings = listOf(
                BottleStory.Reading(day(640), 300.0, "By weight: 850 g on the scale")
            )
        )
        val story = BottleStory.tell(facts)

        assertEquals(
            listOf(
                BottleStory.Kind.BOTTLED, BottleStory.Kind.BOUGHT, BottleStory.Kind.OPENED,
                BottleStory.Kind.POUR, BottleStory.Kind.TASTING, BottleStory.Kind.GIFT,
                BottleStory.Kind.LEVEL, BottleStory.Kind.POUR, BottleStory.Kind.TASTING,
                BottleStory.Kind.FINISHED
            ),
            story.events.map { it.kind }
        )
        assertEquals(
            "\$79.99 · at Total Wine · 6 months after bottling",
            story.events[1].detail
        )
        assertEquals("After 13 months on the shelf", story.events[2].detail)
        assertEquals("60 ml to Mike", story.events[5].title)
        assertEquals("Tasted · 9/10", story.events[8].title)
        assertEquals("3 months after opening", story.events.last().detail)
        assertEquals(
            "Opened after 13 months on the shelf. Finished 3 months later: " +
                "2 pours, 1 given away, 2 tastings, the rating up from 7 to 9.",
            story.summary
        )
    }

    @Test
    fun `an open bottle has a running summary`() {
        val facts = BottleStory.Facts(
            name = "Stagg", boughtAt = day(0), openedAt = day(3),
            pours = listOf(BottleStory.Pour(day(4), 44.0), BottleStory.Pour(day(9), 44.0)),
            tastings = listOf(
                BottleStory.TastingNote(day(4), rating = 6, blind = true),
                BottleStory.TastingNote(day(9), rating = 8)
            )
        )
        val story = BottleStory.tell(facts)
        assertEquals(
            "Opened after 3 days on the shelf. 2 pours so far, the rating up from 6 to 8.",
            story.summary
        )
        assertEquals(
            "Tasted · 6/10 · blind",
            story.events.firstOrNull { it.kind == BottleStory.Kind.TASTING }?.title
        )
    }

    /** Nothing dated is nothing told. */
    @Test
    fun `no dates, no story`() {
        val story = BottleStory.tell(BottleStory.Facts(name = "Sealed"))
        assertTrue(story.events.isEmpty())
        assertNull(story.summary)
    }

    @Test
    fun `ounces when asked`() {
        val facts = BottleStory.Facts(
            name = "x", openedAt = day(0),
            pours = listOf(BottleStory.Pour(day(1), 44.36))
        )
        assertEquals("1.5 oz", BottleStory.tell(facts, ounces = true).events.last().detail)
    }

    @Test
    fun `spans round`() {
        assertEquals("1 day", BottleStory.span(1))
        assertEquals("2 weeks", BottleStory.span(20))
        assertEquals("3 months", BottleStory.span(100))
        assertEquals("2 years", BottleStory.span(800))
    }
}
