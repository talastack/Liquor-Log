package com.talastack.liquorlog.engine

import java.time.Instant
import java.util.Locale
import kotlin.math.roundToInt

/**
 * The life of a bottle, told from what was recorded.
 *
 * Every other screen shows the bottle as it is now. This one puts the record
 * in order: bottled (when the label or its code says), bought, opened, each
 * pour and who it went to, each tasting and what changed, each level set by
 * eye or by weight, finished -- with the gaps between them said in days,
 * which is where the story is: opened after two years on the shelf, finished
 * ninety days later, the rating up a point by the end. Nothing here is
 * inferred; an event with no date is not an event.
 */
object BottleStory {

    enum class Kind(val storageKey: String) {
        BOTTLED("bottled"),
        BOUGHT("bought"),
        OPENED("opened"),
        POUR("pour"),
        GIFT("gift"),
        TASTING("tasting"),
        LEVEL("level"),
        ADDITION("addition"),
        FINISHED("finished")
    }

    data class Event(
        val date: Instant,
        val kind: Kind,
        val title: String,
        val detail: String? = null
    ) {
        val id: String get() = "${kind.storageKey}-${date.toEpochMilli()}-$title"
    }

    data class Pour(
        val at: Instant,
        val milliliters: Double,
        val givenTo: String? = null,
        val into: String? = null
    )

    data class TastingNote(
        val at: Instant,
        val rating: Int? = null,
        val blind: Boolean = false,
        val liked: String? = null
    )

    data class Reading(val at: Instant, val milliliters: Double, val note: String? = null)

    data class Addition(val at: Instant, val milliliters: Double, val from: String)

    /**
     * What the caller knows about the bottle. Every field optional: the story
     * is whatever was recorded.
     */
    data class Facts(
        val name: String,
        val bottledAt: Instant? = null,
        val bottledText: String? = null,
        val boughtAt: Instant? = null,
        val boughtWhere: String? = null,
        val paidText: String? = null,
        val openedAt: Instant? = null,
        val finishedAt: Instant? = null,
        val pours: List<Pour> = emptyList(),
        val tastings: List<TastingNote> = emptyList(),
        val readings: List<Reading> = emptyList(),
        val additions: List<Addition> = emptyList()
    )

    data class Story(
        val events: List<Event>,
        /**
         * "Opened after 412 days on the shelf. Finished 97 days later:
         * 17 pours, 3 tastings, the rating up from 7 to 9."
         */
        val summary: String?
    ) {
        companion object {
            val empty = Story(emptyList(), null)
        }
    }

    fun tell(f: Facts, ounces: Boolean = false): Story {
        val events = mutableListOf<Event>()

        f.bottledAt?.let { at ->
            events.add(Event(at, Kind.BOTTLED, "Bottled", f.bottledText))
        }
        f.boughtAt?.let { at ->
            val detail = mutableListOf<String>()
            f.paidText?.let { detail.add(it) }
            f.boughtWhere?.let { detail.add("at $it") }
            f.bottledAt?.let { bottled ->
                val days = AgeMath.days(bottled, at)
                if (days > 30) detail.add("${span(days)} after bottling")
            }
            events.add(
                Event(
                    at, Kind.BOUGHT, "Bought",
                    if (detail.isEmpty()) null else detail.joinToString(" · ")
                )
            )
        }
        f.openedAt?.let { at ->
            val detail = f.boughtAt?.let { bought ->
                val days = AgeMath.days(bought, at)
                if (days <= 0) "The day it was bought" else "After ${span(days)} on the shelf"
            }
            events.add(Event(at, Kind.OPENED, "Opened", detail))
        }
        for (pour in f.pours) {
            val amount = volume(pour.milliliters, ounces)
            val into = pour.into
            val who = pour.givenTo
            when {
                into != null -> events.add(Event(pour.at, Kind.GIFT, "$amount into $into"))
                who != null -> events.add(Event(pour.at, Kind.GIFT, "$amount to $who"))
                else -> events.add(Event(pour.at, Kind.POUR, "A pour", amount))
            }
        }
        for (tasting in f.tastings) {
            var title = "Tasted"
            tasting.rating?.let { title += " · $it/10" }
            if (tasting.blind) title += " · blind"
            events.add(
                Event(tasting.at, Kind.TASTING, title, tasting.liked?.let { "Liked $it" })
            )
        }
        for (reading in f.readings) {
            events.add(
                Event(
                    reading.at, Kind.LEVEL,
                    "Level set: ${volume(reading.milliliters, ounces)}",
                    reading.note
                )
            )
        }
        for (addition in f.additions) {
            events.add(
                Event(
                    addition.at, Kind.ADDITION,
                    "${volume(addition.milliliters, ounces)} in from ${addition.from}"
                )
            )
        }
        f.finishedAt?.let { at ->
            val detail = f.openedAt?.let { opened ->
                "${span(AgeMath.days(opened, at))} after opening"
            }
            events.add(Event(at, Kind.FINISHED, "Finished", detail))
        }

        val ordered = events.sortedWith(
            compareBy<Event> { it.date }.thenBy { it.kind.storageKey }
        )
        return Story(events = ordered, summary = summary(f))
    }

    internal fun summary(f: Facts): String? {
        val parts = mutableListOf<String>()

        val bought = f.boughtAt
        val opened = f.openedAt
        if (bought != null && opened != null) {
            val days = AgeMath.days(bought, opened)
            if (days > 0) parts.add("Opened after ${span(days)} on the shelf.")
        }

        val ownPours = f.pours.count { it.givenTo == null && it.into == null }
        val given = f.pours.size - ownPours
        val ratings = f.tastings.sortedBy { it.at }.mapNotNull { it.rating }
        val first = ratings.firstOrNull()
        val last = ratings.lastOrNull()

        val finished = f.finishedAt
        if (opened != null && finished != null) {
            val tail = mutableListOf<String>()
            if (ownPours > 0) tail.add("$ownPours ${if (ownPours == 1) "pour" else "pours"}")
            if (given > 0) tail.add("$given given away")
            if (f.tastings.isNotEmpty()) {
                tail.add(
                    "${f.tastings.size} ${if (f.tastings.size == 1) "tasting" else "tastings"}"
                )
            }
            if (first != null && last != null && ratings.size > 1 && first != last) {
                tail.add(
                    if (last > first) "the rating up from $first to $last"
                    else "the rating down from $first to $last"
                )
            }
            val days = AgeMath.days(opened, finished)
            parts.add(
                "Finished ${span(days)} later" +
                    (if (tail.isEmpty()) "." else ": " + tail.joinToString(", ") + ".")
            )
        } else if (opened != null && (f.tastings.isNotEmpty() || ownPours > 0)) {
            val tail = mutableListOf<String>()
            if (ownPours > 0) {
                tail.add("$ownPours ${if (ownPours == 1) "pour" else "pours"} so far")
            }
            if (first != null && last != null && ratings.size > 1 && first != last) {
                tail.add(
                    if (last > first) "the rating up from $first to $last"
                    else "the rating down from $first to $last"
                )
            }
            if (tail.isNotEmpty()) parts.add(tail.joinToString(", ").capitalizedFirst() + ".")
        }

        return if (parts.isEmpty()) null else parts.joinToString(" ")
    }

    /**
     * "3 days", "6 weeks", "14 months", "2 years". Round, because the story is
     * read, not audited; the events carry the exact dates.
     */
    internal fun span(days: Int): String = when {
        days < 14 -> "$days ${if (days == 1) "day" else "days"}"
        days < 60 -> "${days / 7} weeks"
        days < 730 -> "${days / 30} months"
        else -> "${days / 365} years"
    }

    internal fun volume(ml: Double, ounces: Boolean): String = if (ounces) {
        String.format(Locale.ROOT, "%.1f oz", ml / Volume.US_FLUID_OUNCE_IN_MILLILITERS)
    } else {
        "${ml.roundToInt()} ml"
    }

    private fun String.capitalizedFirst(): String {
        val head = firstOrNull() ?: return this
        return head.uppercase() + substring(1)
    }
}
