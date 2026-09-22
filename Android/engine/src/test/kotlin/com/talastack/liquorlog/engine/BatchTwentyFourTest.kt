package com.talastack.liquorlog.engine

import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertIs
import kotlin.test.assertNotNull
import kotlin.test.assertNull
import kotlin.test.assertTrue

/**
 * Plain English in, the app's own verbs out. These pin the grammar and, more
 * importantly, the things it must NOT do: eat the 12 in "Weller 12", or
 * guess when it does not understand.
 */
class AskTest {

    private fun product(
        id: String, brand: String, expression: String = "",
        distillery: String = "Buffalo Trace"
    ) = SearchCandidate(
        product = ProductIdentity(
            productId = id, distillery = distillery, brand = brand,
            expression = expression, classType = ClassType.KENTUCKY_STRAIGHT_BOURBON
        )
    )

    private val catalog = listOf(
        product("weller-12", "W L Weller", "12 Year"),
        product("weller-sr", "W L Weller", "Special Reserve"),
        product("blantons", "Blanton's", "Original Single Barrel"),
        product("eagle-rare-10", "Eagle Rare", "10 Year"),
        product("stagg", "Stagg"),
        product("fr-small-batch", "Four Roses", "Small Batch", distillery = "Four Roses")
    )

    private fun command(text: String): Ask.Command? =
        (Ask.understand(text, catalog) as? Ask.Understanding.AsCommand)?.command

    private fun question(text: String): Ask.Question? =
        (Ask.understand(text, catalog) as? Ask.Understanding.AsQuestion)?.question

    @Test
    fun `log a pour keeps the number in the name`() {
        val pour = assertIs<Ask.Command.Pour>(command("log a pour of weller 12"))
        assertEquals("weller-12", pour.subject.best?.productId)
        assertNull(pour.milliliters, "no size given: the bottle's own pour size applies")
    }

    @Test
    fun `a quantity can lead the sentence`() {
        val pour = assertIs<Ask.Command.Pour>(command("1 oz of the blanton's"))
        assertEquals("blantons", pour.subject.best?.productId)
        assertEquals(PourSize.fromOunces(1.0).milliliters, pour.milliliters ?: 0.0, 0.01)
    }

    @Test
    fun `millilitres are read as well`() {
        val pour = assertIs<Ask.Command.Pour>(command("pour 30 ml of stagg"))
        assertEquals(30.0, pour.milliliters ?: 0.0, 0.01)
    }

    @Test
    fun `politeness`() {
        val pour = assertIs<Ask.Command.Pour>(command("Please log a pour of the Eagle Rare 10"))
        assertEquals("eagle-rare-10", pour.subject.best?.productId)
    }

    @Test
    fun `open and finish`() {
        val opened = assertIs<Ask.Command.Open>(command("opened the stagg"))
        assertEquals("stagg", opened.subject.best?.productId)
        val killed = assertIs<Ask.Command.Finish>(command("finished the weller special reserve"))
        assertEquals("weller-sr", killed.subject.best?.productId)
    }

    @Test
    fun `set level`() {
        val level = assertIs<Ask.Command.SetLevel>(command("set the weller 12 level to 50%"))
        assertEquals("weller-12", level.subject.best?.productId)
        assertEquals(50.0, level.percent)
        val half = assertIs<Ask.Command.SetLevel>(command("set the stagg to half full"))
        assertEquals(50.0, half.percent)
    }

    @Test
    fun `rating`() {
        val rated = assertIs<Ask.Command.Rate>(command("rate the stagg an 8"))
        assertEquals("stagg", rated.subject.best?.productId)
        assertEquals(8, rated.rating)
        val ten = assertIs<Ask.Command.Rate>(command("rate the eagle rare 10 a 9"))
        assertEquals("eagle-rare-10", ten.subject.best?.productId, "the 10 in the name survives")
        assertEquals(9, ten.rating)
    }

    @Test
    fun `add a bottle with price and store`() {
        val added = assertIs<Ask.Command.AddBottle>(
            command("add a bottle of Eagle Rare, paid 40 at Total Wine")
        )
        assertEquals("eagle-rare-10", added.subject.best?.productId)
        assertEquals(4_000, added.paidCents)
        assertEquals("Total Wine", added.store)
    }

    @Test
    fun `a dollar sign`() {
        val added = assertIs<Ask.Command.AddBottle>(command("bought a blanton's for \$65"))
        assertEquals(6_500, added.paidCents)
    }

    @Test
    fun `a wishlist entry with a ceiling`() {
        val wish = assertIs<Ask.Command.Wishlist>(
            command("add four roses small batch to my wishlist under \$40")
        )
        assertEquals("fr-small-batch", wish.subject.best?.productId)
        assertEquals(4_000, wish.ceilingCents)
    }

    @Test
    fun `a note`() {
        val note = assertIs<Ask.Command.Note>(
            command("note on Weller 12: runs hot in 2019 batches")
        )
        assertEquals("weller-12", note.subject.best?.productId)
        assertEquals("runs hot in 2019 batches", note.body)
    }

    @Test
    fun `questions`() {
        assertEquals(Ask.Question.WhatIsOpen, question("what's open"))
        assertEquals(Ask.Question.WhatIsOnMyWishlist, question("what is on my wishlist"))
        assertEquals(Ask.Question.NearlyGone, question("what's nearly gone"))

        val none = assertIs<Ask.Question.HowMany>(question("how many bottles do I have"))
        assertNull(none.subject)

        val some = assertIs<Ask.Question.HowMany>(question("how many wellers do I have"))
        assertEquals("W L Weller", some.subject?.best?.brand)

        val have = assertIs<Ask.Question.DoIHave>(question("do I have any blanton's"))
        assertEquals("blantons", have.subject.best?.productId)

        val last = assertIs<Ask.Question.LastPoured>(question("when did I last pour the stagg"))
        assertEquals("stagg", last.subject.best?.productId)

        val think = assertIs<Ask.Question.WhatDidIThink>(
            question("what did I think of the eagle rare")
        )
        assertEquals("eagle-rare-10", think.subject.best?.productId)

        val whereIs = assertIs<Ask.Question.WhereIs>(question("where is my weller 12"))
        assertEquals("weller-12", whereIs.subject.best?.productId)
    }

    @Test
    fun `nonsense is unknown, not a guess`() {
        assertIs<Ask.Understanding.Unknown>(
            Ask.understand("the weather is nice", catalog),
            "a sentence the grammar does not know must come back unknown"
        )
    }

    @Test
    fun `an unknown bottle is still a command with no match`() {
        val pour = assertIs<Ask.Command.Pour>(command("log a pour of pappy 23"))
        assertEquals("pappy 23", pour.subject.text)
        assertNull(pour.subject.best)
    }

    @Test
    fun `ambiguity is visible`() {
        val pour = assertIs<Ask.Command.Pour>(command("log a pour of weller"))
        assertTrue(
            pour.subject.isAmbiguous,
            "two Wellers score alike; the screen must ask which"
        )
    }

    @Test
    fun `a sighting carries store, price and count`() {
        val saw = assertIs<Ask.Command.Saw>(
            command("saw Blanton's at Total Wine for \$74.99, 3 on the shelf")
        )
        assertEquals("blantons", saw.subject.best?.productId)
        assertEquals(7499, saw.cents)
        assertEquals("Total Wine", saw.store)
        assertEquals(3, saw.count)
    }

    @Test
    fun `a count can lead and a name keeps its number`() {
        val saw = assertIs<Ask.Command.Saw>(
            command("spotted 2 bottles of eagle rare 10 at Liquor Barn")
        )
        assertEquals("eagle-rare-10", saw.subject.best?.productId)
        assertNull(saw.cents)
        assertEquals("Liquor Barn", saw.store)
        assertEquals(2, saw.count)
    }

    @Test
    fun `a lottery entry names who runs it`() {
        val entered = assertIs<Ask.Command.Entered>(
            command("entered the stagg lottery at Virginia ABC")
        )
        assertEquals("stagg", entered.subject.best?.productId)
        assertEquals("Virginia ABC", entered.runner)

        val plain = assertIs<Ask.Command.Entered>(command("put in for the stagg drawing"))
        assertNull(plain.runner)
    }

    @Test
    fun `where did I see is a question about the log`() {
        val seen = assertIs<Ask.Question.WhereDidISee>(question("where did I see the blanton's?"))
        assertEquals("blantons", seen.subject.best?.productId)
        assertIs<Ask.Question.WhereDidISee>(question("who has stagg in stock"))
    }

    @Test
    fun `a visit keeps the place as typed`() {
        val visit = assertIs<Ask.Command.Visited>(command("visited Buffalo Trace today"))
        assertEquals("Buffalo Trace", visit.place)
        val other = assertIs<Ask.Command.Visited>(command("I went to the Four Roses distillery"))
        assertEquals("Four Roses", other.place)
    }

    @Test
    fun `have I been to is a question about the passport`() {
        val been = assertIs<Ask.Question.HaveIBeenTo>(question("have I been to Buffalo Trace?"))
        assertEquals("buffalo trace", been.place)
    }

    @Test
    fun `what I poured is not about a person called I`() {
        assertIs<Ask.Understanding.Unknown>(
            Ask.understand("what did I pour", catalog),
            "\"I\" is not a friend who sent samples"
        )
    }

    @Test
    fun `what somebody sent is a question about them`() {
        val mike = assertIs<Ask.Question.WhatCameFrom>(question("what did Mike send me?"))
        assertEquals("mike", mike.person)
        val sarah = assertIs<Ask.Question.WhatCameFrom>(question("samples from sarah"))
        assertEquals("sarah", sarah.person)
    }
}
