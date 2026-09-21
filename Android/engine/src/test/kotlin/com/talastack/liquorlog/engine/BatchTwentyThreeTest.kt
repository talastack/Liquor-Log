package com.talastack.liquorlog.engine

import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertFalse
import kotlin.test.assertNotNull
import kotlin.test.assertNull
import kotlin.test.assertTrue

/** The IBA list against a shelf: ready, nearly, or not tonight. */
class CocktailsTest {

    private fun bottle(
        id: String, name: String, classType: ClassType,
        open: Boolean = true, rating: Int? = null, fill: Double = 1.0
    ) = Cocktails.Candidate(
        id = id, name = name, classType = classType,
        isOpen = open, rating = rating, fillFraction = fill
    )

    @Test
    fun `an Old Fashioned needs only an open bourbon`() {
        val matches = Cocktails.matches(
            listOf(bottle("ec", "Elijah Craig Small Batch", ClassType.KENTUCKY_STRAIGHT_BOURBON))
        )
        val ready = matches.filter { it.isReady }.map { it.recipe.id }
        assertTrue(ready.contains("old-fashioned"), ready.toString())
        assertTrue(ready.contains("whiskey-sour"))
        assertTrue(ready.contains("mint-julep"))
        assertFalse(ready.contains("manhattan"), "no vermouth")
    }

    @Test
    fun `one bottle short is nearly, and names the sealed one`() {
        val shelf = listOf(
            bottle("rye", "Rittenhouse Rye", ClassType.STRAIGHT_RYE),
            bottle("v", "Carpano Antica Formula", ClassType.VERMOUTH, open = false)
        )
        val manhattan = assertNotNull(
            Cocktails.matches(shelf).firstOrNull { it.recipe.id == "manhattan" }
        )
        assertFalse(manhattan.isReady)
        assertEquals(listOf(Cocktails.Slot.SWEET_VERMOUTH), manhattan.missing.map { it.slot })
        assertEquals("v", manhattan.missing.first().sealed?.id, "the sealed bottle that would do")
    }

    @Test
    fun `two short is not tonight`() {
        val matches = Cocktails.matches(
            listOf(bottle("g", "Tanqueray", ClassType.LONDON_DRY_GIN))
        )
        assertNull(
            matches.firstOrNull { it.recipe.id == "negroni" }, "no Campari, no vermouth"
        )
        assertTrue(matches.any { it.recipe.id == "john-collins" && it.isReady })
    }

    /**
     * A recipe the shelf has nothing for is not "one short"; a sealed bottle
     * of the one thing it needs makes it so.
     */
    @Test
    fun `one short means the shelf is part of the way there`() {
        val gin = Cocktails.matches(listOf(bottle("g", "Tanqueray", ClassType.LONDON_DRY_GIN)))
        assertNull(
            gin.firstOrNull { it.recipe.id == "old-fashioned" }, "no whiskey of any kind"
        )
        val sealed = Cocktails.matches(
            listOf(
                bottle("s", "Stagg Jr", ClassType.KENTUCKY_STRAIGHT_BOURBON, open = false)
            )
        )
        val oldFashioned = assertNotNull(sealed.firstOrNull { it.recipe.id == "old-fashioned" })
        assertEquals("s", oldFashioned.missing.first().sealed?.id)
    }

    /** Sweet and dry vermouth are one class; the name settles it. */
    @Test
    fun `vermouth is sweet unless it says dry`() {
        val shelf = listOf(
            bottle("g", "Beefeater", ClassType.LONDON_DRY_GIN),
            bottle("d", "Noilly Prat Extra Dry", ClassType.VERMOUTH),
            bottle("s", "Cocchi Vermouth di Torino", ClassType.VERMOUTH)
        )
        val martini = assertNotNull(
            Cocktails.matches(shelf).firstOrNull { it.recipe.id == "dry-martini" }
        )
        assertEquals("d", martini.picks[Cocktails.Slot.DRY_VERMOUTH]?.id)
        val negroni = Cocktails.matches(shelf).firstOrNull { it.recipe.id == "negroni" }
        assertEquals(listOf(Cocktails.Slot.CAMPARI), negroni?.missing?.map { it.slot })
    }

    @Test
    fun `the best open bottle fills a slot`() {
        val shelf = listOf(
            bottle(
                "a", "Old Grand-Dad", ClassType.KENTUCKY_STRAIGHT_BOURBON,
                rating = 6, fill = 0.9
            ),
            bottle(
                "b", "Weller 12", ClassType.KENTUCKY_STRAIGHT_BOURBON, rating = 9, fill = 0.2
            ),
            bottle(
                "c", "Sealed Stagg", ClassType.KENTUCKY_STRAIGHT_BOURBON,
                open = false, rating = 10
            )
        )
        val julep = assertNotNull(
            Cocktails.matches(shelf).firstOrNull { it.recipe.id == "mint-julep" }
        )
        assertEquals(
            "b", julep.picks[Cocktails.Slot.BOURBON]?.id,
            "highest rated open bottle, not the sealed one"
        )
    }

    @Test
    fun `ready comes before nearly, and each is alphabetical`() {
        val shelf = listOf(
            bottle("t", "Fortaleza Blanco", ClassType.TEQUILA_BLANCO),
            bottle("c", "Cointreau", ClassType.LIQUEUR, open = false)
        )
        val matches = Cocktails.matches(shelf)
        val ids = matches.map { it.recipe.id }
        assertEquals(listOf("paloma", "tommys-margarita"), ids.take(2), ids.toString())
        assertEquals("margarita", ids.last())
        assertFalse(matches.last().isReady)
    }

    @Test
    fun `the list is the IBA's and every recipe has a bottle slot`() {
        assertTrue(Cocktails.all.size >= 25)
        assertEquals(Cocktails.all.size, Cocktails.all.map { it.id }.toSet().size)
        for (recipe in Cocktails.all) {
            assertTrue(recipe.slots.isNotEmpty(), recipe.name)
            assertTrue(recipe.method.isNotEmpty(), recipe.name)
        }
    }

    @Test
    fun `ingredients read`() {
        assertEquals(
            "50 ml rye",
            Cocktails.Ingredient.Bottle(Cocktails.Slot.RYE, 50.0).text
        )
        assertEquals(
            "7.5 ml Islay Scotch",
            Cocktails.Ingredient.Bottle(Cocktails.Slot.ISLAY_SCOTCH, 7.5).text
        )
        assertEquals(
            "1 sugar cube",
            Cocktails.Ingredient.Pantry("1 sugar cube").text
        )
    }
}
