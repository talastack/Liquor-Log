package com.talastack.liquorlog.engine

import java.time.Instant
import java.time.ZoneId
import java.time.format.DateTimeFormatter
import java.util.Locale

/**
 * The passport: the distilleries you have stood in.
 *
 * A visit is a date and a name. Read back, the visits become stamps -- one
 * per distillery, with how many times and when -- and two lists the shelf
 * can answer that no passport can: which of your bottles came from a place
 * you have been, and which distilleries on your shelf you have never
 * visited. Nothing here is a checklist of the catalogue; the distilleries
 * you have not been to are the ones whose bottles you own, which is a list
 * you might act on, not a list you cannot finish.
 */
object Passport {

    data class Visit(
        val distillery: String,
        val at: Instant,
        val note: String? = null,
    )

    /** A bottle, as the passport needs it: where it was made and where it was bought. */
    data class Bottle(
        val name: String,
        val distillery: String?,
        val boughtAt: String? = null,
    )

    data class Stamp(
        val key: String,
        /** The spelling you used most recently. */
        val name: String,
        val visits: Int,
        val firstAt: Instant,
        val lastAt: Instant,
        /** Bottles on the shelf made there. */
        val bottlesFromThere: List<String>,
        /** Bottles whose purchase store is the distillery itself. */
        val boughtThere: List<String>,
    )

    data class Unvisited(val name: String, val bottles: Int)

    data class Summary(
        /** Most recently visited first. */
        val stamps: List<Stamp>,
        val visits: Int,
        /**
         * Distilleries with bottles on the shelf and no visit, most bottles
         * first.
         */
        val notYetVisited: List<Unvisited>,
        /** "6 distilleries, 9 visits." Null with nothing recorded. */
        val headline: String?,
    )

    fun summarise(visits: List<Visit>, shelf: List<Bottle>): Summary {
        val byKey = visits
            .filter { normalise(it.distillery).isNotEmpty() }
            .groupBy { normalise(it.distillery) }

        val stamps = byKey.map { (key, rows) ->
            val newest = rows.maxByOrNull { it.at }!!
            Stamp(
                key = key,
                name = newest.distillery.trim(),
                visits = rows.size,
                firstAt = rows.minOf { it.at },
                lastAt = newest.at,
                bottlesFromThere = shelf
                    .filter { it.distillery?.let(::normalise) == key }
                    .map { it.name }.sorted(),
                boughtThere = shelf
                    .filter { it.boughtAt?.let(::normalise) == key }
                    .map { it.name }.sorted(),
            )
        }.sortedWith(compareByDescending<Stamp> { it.lastAt }.thenBy { it.name })

        // LinkedHashMap so a tie in bottle count resolves by name, not by
        // whatever order the shelf happened to arrive in.
        val unvisited = LinkedHashMap<String, Unvisited>()
        for (bottle in shelf) {
            val distillery = bottle.distillery ?: continue
            val key = normalise(distillery)
            if (key.isEmpty() || byKey.containsKey(key)) continue
            // The latest spelling wins, as it does for a stamp: the name
            // shown is the one most recently typed.
            unvisited[key] = Unvisited(
                name = distillery,
                bottles = (unvisited[key]?.bottles ?: 0) + 1,
            )
        }
        val notYet = unvisited.values
            .sortedWith(compareByDescending<Unvisited> { it.bottles }.thenBy { it.name })

        val headline = if (stamps.isEmpty()) {
            null
        } else {
            "${stamps.size} ${if (stamps.size == 1) "distillery" else "distilleries"}, " +
                "${visits.size} ${if (visits.size == 1) "visit" else "visits"}."
        }
        return Summary(stamps = stamps, visits = visits.size, notYetVisited = notYet, headline = headline)
    }

    /** "3 visits · first March 2024 · last 3 weeks ago" or "Once, 3 weeks ago". */
    fun line(s: Stamp, now: Instant = Instant.now(), zone: ZoneId = ZoneId.systemDefault()): String {
        val last = Hunt.ago(AgeMath.days(s.lastAt, now))
        if (s.visits == 1) return "Once, $last"
        return "${s.visits} visits · first ${monthAndYear(s.firstAt, zone)} · last $last"
    }

    /** "2 bottles from there on the shelf, 1 bought there." Null with neither. */
    fun shelfLine(s: Stamp): String? {
        val parts = mutableListOf<String>()
        if (s.bottlesFromThere.isNotEmpty()) {
            parts += "${s.bottlesFromThere.size} " +
                "${if (s.bottlesFromThere.size == 1) "bottle" else "bottles"} from there on the shelf"
        }
        if (s.boughtThere.isNotEmpty()) {
            parts += "${s.boughtThere.size} bought there"
        }
        return if (parts.isEmpty()) null else parts.joinToString(", ") + "."
    }

    /**
     * "Buffalo Trace Distillery" and "buffalo trace" are one place. The
     * suffixes are stripped after lowercasing, so the order of these
     * replacements is the order they appear on a label.
     */
    fun normalise(name: String): String =
        name.trim().lowercase()
            .replace(" distillery", "")
            .replace(" distilling co.", "")
            .replace(" distilling company", "")
            .replace(" distilling", "")

    private fun monthAndYear(date: Instant, zone: ZoneId): String =
        DateTimeFormatter.ofPattern("MMMM yyyy", Locale.US).withZone(zone).format(date)
}
