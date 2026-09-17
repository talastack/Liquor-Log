package com.talastack.liquorlog.engine

import java.time.Instant
import java.time.ZoneId
import java.time.temporal.ChronoUnit
import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertNotNull
import kotlin.test.assertNull
import kotlin.test.assertTrue

class MoneyTest {
    @Test
    fun `cents become dollars, whatever the phone's locale`() {
        assertEquals("$74.99", Money.short(7_499))
        assertEquals("$0.00", Money.short(0))
        assertEquals("$1,234.00".replace(",", ""), Money.short(123_400), "no grouping separator")
    }
}

class HuntTest {

    private val now: Instant = Instant.parse("2026-09-17T12:00:00Z")
    private fun daysAgo(n: Long): Instant = now.minus(n, ChronoUnit.DAYS)

    private fun seen(id: String, product: String?, store: String, days: Long,
                     cents: Int? = null, count: Int? = null, bought: String? = null) =
        Hunt.Sighting(id = id, productId = product, name = product ?: id, store = store,
                      kind = Hunt.Kind.SEEN, cents = cents, count = count,
                      at = daysAgo(days), boughtBottleId = bought)

    private fun entered(id: String, product: String, runner: String, days: Long,
                        outcome: Hunt.Outcome? = null) =
        Hunt.Sighting(id = id, productId = product, name = product, store = runner,
                      kind = Hunt.Kind.ENTERED, outcome = outcome, at = daysAgo(days))

    @Test
    fun `stores rank by what was found there, and spellings merge`() {
        val summary = Hunt.summarise(
            listOf(
                seen("a", "blantons", "Total Wine", 30),
                seen("b", "weller-sr", "total wine ", 2),
                seen("c", "blantons", "Total Wine", 10),
                seen("d", "ecbp", "Liquor Barn", 1),
            ),
            wishlist = setOf("blantons"),
        )
        assertEquals(4, summary.seen)
        assertEquals(listOf("total wine", "Liquor Barn"), summary.stores.map { it.name })
        assertEquals(3, summary.stores[0].sightings)
        assertEquals(2, summary.stores[0].products)
        assertEquals(2, summary.stores[0].wishlistHits)
        assertEquals("4 sightings at 2 stores", summary.headline)
    }

    @Test
    fun `lotteries count entered, won, lost and pending`() {
        val summary = Hunt.summarise(listOf(
            entered("a", "stagg", "Virginia ABC", 90, Hunt.Outcome.LOST),
            entered("b", "stagg", "Virginia ABC", 40, Hunt.Outcome.WON),
            entered("c", "weller-12", "Virginia ABC", 5),
            entered("d", "blantons-gold", "Ohio", 2),
        ))
        assertEquals(4, summary.lotteries.entered)
        assertEquals(2, summary.lotteries.pending)
        assertEquals("4 entered · 1 won · 1 lost · 2 pending", summary.lotteries.line)
        assertEquals("4 lotteries entered, 1 won", summary.headline)
        assertTrue(summary.stores.isEmpty(), "a lottery runner is not a store you found something at")
    }

    @Test
    fun `an empty log says nothing`() {
        val summary = Hunt.summarise(emptyList())
        assertNull(summary.headline)
        assertNull(summary.lotteries.line)
        assertEquals(Hunt.Summary.empty, summary)
    }

    @Test
    fun `the latest sighting of a product is the newest shelf one`() {
        val log = listOf(
            seen("a", "blantons", "Total Wine", 30, cents = 7_499),
            seen("b", "blantons", "Liquor Barn", 3, cents = 6_999, count = 2),
            entered("c", "blantons", "Virginia ABC", 1),
        )
        val latest = Hunt.latest("blantons", log)
        assertEquals("b", latest?.id)
        assertEquals("At Liquor Barn 3 days ago · $69.99 · 2 on the shelf", Hunt.line(latest!!, now))
        assertNull(Hunt.latest("stagg", log))
    }

    @Test
    fun `on your list is recent, unbought, newest per product`() {
        val log = listOf(
            seen("a", "blantons", "Total Wine", 30),
            seen("b", "blantons", "Liquor Barn", 3),
            seen("c", "weller-12", "Total Wine", 90),
            seen("d", "ecbp", "Total Wine", 1),
            seen("e", "stagg", "Total Wine", 2, bought = "bottle-1"),
        )
        val rows = Hunt.onYourList(log, wishlist = setOf("blantons", "weller-12", "stagg"), now = now)
        assertEquals(listOf("b"), rows.map { it.id })
    }

    @Test
    fun `lines say when and what in plain words`() {
        assertEquals("At Total Wine today · $74.99",
            Hunt.line(seen("a", null, "Total Wine", 0, cents = 7_499), now))
        assertEquals("At Total Wine yesterday · sold out",
            Hunt.line(seen("a", null, "Total Wine", 1, count = 0), now))
        assertEquals("At Total Wine 3 weeks ago · bought",
            Hunt.line(seen("a", null, "Total Wine", 21, bought = "b"), now))
        assertEquals("Virginia ABC, 6 weeks ago · pending",
            Hunt.line(entered("a", "stagg", "Virginia ABC", 45), now))
        assertEquals("Virginia ABC, a year ago · won",
            Hunt.line(entered("a", "stagg", "Virginia ABC", 400, Hunt.Outcome.WON), now))
    }

    @Test
    fun `ago rounds the way people say it`() {
        assertEquals("today", Hunt.ago(0))
        assertEquals("13 days ago", Hunt.ago(13))
        assertEquals("2 weeks ago", Hunt.ago(14))
        assertEquals("8 weeks ago", Hunt.ago(59))
        assertEquals("2 months ago", Hunt.ago(60))
        assertEquals("12 months ago", Hunt.ago(364))
        assertEquals("2 years ago", Hunt.ago(800))
    }
}

class PassportTest {

    private val utc: ZoneId = ZoneId.of("UTC")
    private fun day(iso: String): Instant = Instant.parse("${iso}T12:00:00Z")

    private val shelf = listOf(
        Passport.Bottle("Weller 12", "Buffalo Trace", "Total Wine"),
        Passport.Bottle("Stagg", "Buffalo Trace", "Buffalo Trace Distillery"),
        Passport.Bottle("Four Roses OESQ", "Four Roses", "Four Roses"),
        Passport.Bottle("Rittenhouse", "Heaven Hill"),
        Passport.Bottle("ECBP", "Heaven Hill"),
        Passport.Bottle("Something typed in", null),
    )

    @Test
    fun `stamps merge spellings and carry the shelf`() {
        val summary = Passport.summarise(
            visits = listOf(
                Passport.Visit("Buffalo Trace Distillery", day("2024-03-10")),
                Passport.Visit("buffalo trace", day("2026-08-01")),
                Passport.Visit("Four Roses", day("2025-05-05"), note = "the Cox's Creek warehouses"),
            ),
            shelf = shelf,
        )
        assertEquals("2 distilleries, 3 visits.", summary.headline)
        assertEquals(listOf("buffalo trace", "Four Roses"), summary.stamps.map { it.name })

        val bt = summary.stamps[0]
        assertEquals(2, bt.visits)
        assertEquals(day("2024-03-10"), bt.firstAt)
        assertEquals(listOf("Stagg", "Weller 12"), bt.bottlesFromThere)
        assertEquals(listOf("Stagg"), bt.boughtThere, "the store name is the distillery, however spelled")
        assertEquals("2 bottles from there on the shelf, 1 bought there.", Passport.shelfLine(bt))
        assertEquals(
            "2 visits · first March 2024 · last 3 weeks ago",
            Passport.line(bt, now = day("2026-08-22"), zone = utc),
        )
        assertEquals("Once, today", Passport.line(summary.stamps[1], now = day("2025-05-05"), zone = utc))
    }

    @Test
    fun `not yet visited is the shelf minus the stamps, most bottles first`() {
        val summary = Passport.summarise(
            visits = listOf(Passport.Visit("Buffalo Trace", day("2026-01-01"))),
            shelf = shelf,
        )
        assertEquals(listOf("Heaven Hill", "Four Roses"), summary.notYetVisited.map { it.name })
        assertEquals(listOf(2, 1), summary.notYetVisited.map { it.bottles })
    }

    @Test
    fun `an empty passport still has a shelf worth visiting`() {
        val summary = Passport.summarise(visits = emptyList(), shelf = shelf)
        assertNull(summary.headline)
        assertTrue(summary.stamps.isEmpty())
        assertEquals(3, summary.notYetVisited.size)
    }

    @Test
    fun `a stamp with nothing from it on the shelf says nothing`() {
        val summary = Passport.summarise(
            visits = listOf(Passport.Visit("Willett", day("2026-01-01"))),
            shelf = shelf,
        )
        assertNotNull(summary.stamps.firstOrNull())
        assertNull(Passport.shelfLine(summary.stamps[0]))
    }

    @Test
    fun `the distilling suffixes are all one place`() {
        assertEquals("buffalo trace", Passport.normalise("Buffalo Trace Distillery"))
        assertEquals("buffalo trace", Passport.normalise("  buffalo trace  "))
        assertEquals("willett", Passport.normalise("Willett Distilling Company"))
        assertEquals("smooth ambler", Passport.normalise("Smooth Ambler Distilling"))
    }
}
