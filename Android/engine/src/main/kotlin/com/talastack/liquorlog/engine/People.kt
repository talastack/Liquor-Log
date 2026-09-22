package com.talastack.liquorlog.engine

import java.time.Instant
import java.util.Locale
import kotlin.math.abs
import kotlin.math.roundToInt

/**
 * The people behind the bottles: who sent you samples, who you poured for,
 * and how that stands.
 *
 * Sample swapping is half the hobby, and the bookkeeping is all in people's
 * heads: Mike sent three samples in the spring, you sent him two pours off
 * the Stagg, and whose turn is it? The app already holds every side of that
 * -- a sample bottle says who it came from, a pour says who it went to, a
 * tasting says what you thought of it -- so the ledger is read, not kept.
 *
 * Nothing here is about how much anybody drank; it is about what changed
 * hands.
 */
object People {

    /** A sample that came from somebody. */
    data class Received(
        val bottle: String,
        val milliliters: Double,
        /** "A swap", "From a friend"…, as the sample was logged. */
        val how: String? = null,
        val at: Instant,
        /** Your rating of it, when you tasted it. */
        val rating: Int? = null,
    )

    /** A pour that went to somebody. */
    data class Given(
        val bottle: String,
        val milliliters: Double,
        val at: Instant,
    )

    data class Person(
        /** Lowercased, trimmed: "Mike" and "mike " are one person. */
        val key: String,
        /** The spelling you used most recently. */
        val name: String,
        /** Newest first. */
        val received: List<Received>,
        /** Newest first. */
        val given: List<Given>,
    ) {
        val receivedMilliliters: Double get() = received.sumOf { it.milliliters }
        val givenMilliliters: Double get() = given.sumOf { it.milliliters }

        val lastAt: Instant
            get() = maxOf(
                received.firstOrNull()?.at ?: Instant.MIN,
                given.firstOrNull()?.at ?: Instant.MIN,
            )

        /** Their samples' average with you, over two or more rated. */
        val averageRating: Double?
            get() {
                val ratings = received.mapNotNull { it.rating }
                if (ratings.size < 2) return null
                return ratings.sum().toDouble() / ratings.size
            }
    }

    /** What the caller hands in, before it is grouped by person. */
    data class ReceivedEntry(
        val from: String,
        val bottle: String,
        val milliliters: Double,
        val how: String? = null,
        val at: Instant,
        val rating: Int? = null,
    )

    data class GivenEntry(
        val to: String,
        val bottle: String,
        val milliliters: Double,
        val at: Instant,
    )

    // MARK: - Reading

    /** The ledger, most recent exchange first. */
    fun ledger(received: List<ReceivedEntry>, given: List<GivenEntry>): List<Person> {
        // The spelling shown is the one used most recently, so the list
        // matches however the person last typed the name.
        val names = mutableMapOf<String, Pair<String, Instant>>()
        val got = mutableMapOf<String, MutableList<Received>>()
        val sent = mutableMapOf<String, MutableList<Given>>()

        fun note(raw: String, at: Instant): String? {
            val name = raw.trim()
            if (name.isEmpty()) return null
            val key = name.lowercase()
            val have = names[key]
            if (have == null || have.second < at) names[key] = name to at
            return key
        }

        for (r in received) {
            val key = note(r.from, r.at) ?: continue
            got.getOrPut(key) { mutableListOf() }.add(
                Received(bottle = r.bottle, milliliters = r.milliliters,
                         how = r.how, at = r.at, rating = r.rating),
            )
        }
        for (g in given) {
            val key = note(g.to, g.at) ?: continue
            sent.getOrPut(key) { mutableListOf() }.add(
                Given(bottle = g.bottle, milliliters = g.milliliters, at = g.at),
            )
        }

        return names.map { (key, spelling) ->
            Person(
                key = key,
                name = spelling.first,
                received = (got[key] ?: emptyList()).sortedByDescending { it.at },
                given = (sent[key] ?: emptyList()).sortedByDescending { it.at },
            )
        }.sortedWith(compareByDescending<Person> { it.lastAt }.thenBy { it.name })
    }

    // MARK: - Words

    /** "3 samples from them · 2 pours to them · last 3 weeks ago". */
    fun line(p: Person, now: Instant = Instant.now()): String {
        val parts = mutableListOf<String>()
        if (p.received.isNotEmpty()) {
            parts += "${p.received.size} ${if (p.received.size == 1) "sample" else "samples"} from them"
        }
        if (p.given.isNotEmpty()) {
            parts += "${p.given.size} ${if (p.given.size == 1) "pour" else "pours"} to them"
        }
        parts += "last ${Hunt.ago(AgeMath.days(p.lastAt, now))}"
        return parts.joinToString(" · ")
    }

    /**
     * Whose turn it is, in millilitres, when there is a real gap. Null when
     * nothing has gone either way; "About even" inside one pour.
     */
    fun balance(p: Person, ounces: Boolean = false): String? {
        val gap = p.receivedMilliliters - p.givenMilliliters
        if (p.receivedMilliliters + p.givenMilliliters <= 0) return null
        if (abs(gap) < 30) return "About even"
        val amount = if (ounces) {
            String.format(Locale.ROOT, "%.1f oz", abs(gap) / Volume.US_FLUID_OUNCE_IN_MILLILITERS)
        } else {
            "${abs(gap).roundToInt()} ml"
        }
        return if (gap > 0) {
            "They have sent $amount more than you have"
        } else {
            "You have sent $amount more than they have"
        }
    }

    /** "Their samples average 8.3 with you, over 3 rated." Null under two. */
    fun taste(p: Person): String? {
        val average = p.averageRating ?: return null
        val rated = p.received.count { it.rating != null }
        return String.format(
            Locale.ROOT,
            "Their samples average %.1f with you, over %d rated.",
            average, rated,
        )
    }
}
