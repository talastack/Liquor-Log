package com.talastack.liquorlog.engine

import java.time.Instant
import java.time.temporal.ChronoUnit
import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertNull
import kotlin.test.assertTrue

/**
 * The swap ledger, read from samples and pours: one person per name however
 * it was spelled, what went each way, whose turn it is, and whether their
 * samples rate well with you.
 */
class PeopleTest {

    private val now: Instant = Instant.parse("2026-09-17T12:00:00Z")
    private fun daysAgo(n: Long): Instant = now.minus(n, ChronoUnit.DAYS)

    private fun received(from: String, bottle: String, ml: Double, days: Long,
                         how: String? = null, rating: Int? = null) =
        People.ReceivedEntry(from = from, bottle = bottle, milliliters = ml,
                             how = how, at = daysAgo(days), rating = rating)

    private fun given(to: String, bottle: String, ml: Double, days: Long) =
        People.GivenEntry(to = to, bottle = bottle, milliliters = ml, at = daysAgo(days))

    @Test
    fun `one person per name, newest spelling, newest exchange first`() {
        val people = People.ledger(
            received = listOf(
                received("mike", "Stagg Jr", 50.0, 40, how = "A swap", rating = 8),
                received("Mike ", "Weller 12", 30.0, 3, rating = 9),
                received("Sarah", "ECBP", 60.0, 90, how = "From a friend"),
            ),
            given = listOf(
                given("MIKE", "Blanton's", 44.0, 10),
                given("  ", "nobody", 44.0, 1),
            ),
        )

        assertEquals(listOf("Mike", "Sarah"), people.map { it.name },
            "most recent exchange first, blank names dropped")
        val mike = people[0]
        assertEquals(listOf("Weller 12", "Stagg Jr"), mike.received.map { it.bottle })
        assertEquals(listOf("Blanton's"), mike.given.map { it.bottle })
        assertEquals(80.0, mike.receivedMilliliters)
        assertEquals(44.0, mike.givenMilliliters)
        assertEquals(daysAgo(3), mike.lastAt)
        assertEquals("2 samples from them · 1 pour to them · last 3 days ago", People.line(mike, now))
    }

    @Test
    fun `balance says whose turn it is in plain words`() {
        val people = People.ledger(
            received = listOf(received("Mike", "a", 100.0, 1)),
            given = listOf(
                given("Mike", "b", 40.0, 2),
                given("Sarah", "c", 44.0, 2),
            ),
        )
        val mike = people.first { it.name == "Mike" }
        val sarah = people.first { it.name == "Sarah" }
        assertEquals("They have sent 60 ml more than you have", People.balance(mike))
        assertEquals("They have sent 2.0 oz more than you have", People.balance(mike, ounces = true))
        assertEquals("You have sent 44 ml more than they have", People.balance(sarah))
    }

    @Test
    fun `inside one pour it is about even`() {
        val even = People.ledger(
            received = listOf(received("Joe", "a", 50.0, 1)),
            given = listOf(given("Joe", "b", 44.0, 2)),
        )
        assertEquals("About even", People.balance(even[0]))
    }

    @Test
    fun `taste needs two rated samples`() {
        val one = People.ledger(
            received = listOf(received("Mike", "a", 50.0, 1, rating = 9)),
            given = emptyList(),
        )
        assertNull(People.taste(one[0]))

        val two = People.ledger(
            received = listOf(
                received("Mike", "a", 50.0, 1, rating = 9),
                received("Mike", "b", 50.0, 2, rating = 8),
                received("Mike", "c", 50.0, 3),
            ),
            given = emptyList(),
        )
        assertEquals("Their samples average 8.5 with you, over 2 rated.", People.taste(two[0]))
    }

    @Test
    fun `nobody is an empty ledger`() {
        assertTrue(People.ledger(emptyList(), emptyList()).isEmpty())
    }

    @Test
    fun `a person who only received something still has a balance`() {
        val people = People.ledger(
            received = emptyList(),
            given = listOf(given("Sarah", "Stagg", 60.0, 5)),
        )
        assertEquals("You have sent 60 ml more than they have", People.balance(people[0]))
        assertEquals("1 pour to them · last 5 days ago", People.line(people[0], now))
    }
}
