package com.talastack.liquorlog.engine

import java.time.Instant
import java.time.LocalDate
import java.time.ZoneId
import java.time.format.DateTimeFormatter
import java.time.temporal.ChronoUnit
import java.util.Locale

/**
 * What you said last time, in one line, at the moment it is useful.
 *
 * The most common sentence in reviews of every collection app is some form
 * of *"I can't remember what I liked."* The tasting is in the database; the
 * failure is that it is three taps away when the question is being asked
 * -- in the aisle, or choosing tonight's pour. This puts the latest
 * tasting where the decision is, as one sentence built only from what was
 * recorded. Nothing rated, nothing written: no line.
 */
object TastingRecall {

    /**
     * "Last time, in March: 8/10, would buy again. Liked toffee. Not the
     * heat." Any missing part is left out rather than filled in.
     */
    fun line(
        tasting: TastingRecord,
        now: Instant = Instant.now(),
        zone: ZoneId = ZoneId.systemDefault()
    ): String? {
        val facts = mutableListOf<String>()
        tasting.rating?.let { facts.add("$it/10") }
        when (tasting.wouldRebuy) {
            true -> facts.add("would buy again")
            false -> facts.add("would not buy again")
            null -> Unit
        }

        val sentences = mutableListOf<String>()
        val liked = tasting.liked?.trim()
        if (!liked.isNullOrEmpty()) sentences.add("Liked $liked.")
        val disliked = tasting.disliked?.trim()
        if (!disliked.isNullOrEmpty()) sentences.add("Not $disliked.")

        if (facts.isEmpty() && sentences.isEmpty()) return null

        val head = StringBuilder("Last time, ").append(whenItWas(tasting.tastedAt, now, zone))
        tasting.whereTasted?.let { head.append(" (").append(it.lowercase()).append(")") }
        head.append(if (facts.isEmpty()) "." else ": " + facts.joinToString(", ") + ".")
        return (listOf(head.toString()) + sentences).joinToString(" ")
    }

    /**
     * "today", "yesterday", "12 days ago", "in March", "in March 2025".
     *
     * Swift spells this `when`, which Kotlin reserves.
     */
    internal fun whenItWas(date: Instant, now: Instant, zone: ZoneId): String {
        val then = LocalDate.ofInstant(date, zone)
        val today = LocalDate.ofInstant(now, zone)
        val days = ChronoUnit.DAYS.between(then, today)
        return when {
            // A clock set forward; say something rather than lie about a date.
            days < 0 -> "later"
            days == 0L -> "today"
            days == 1L -> "yesterday"
            days < 30 -> "$days days ago"
            else -> {
                val pattern = if (then.year == today.year) "MMMM" else "MMMM yyyy"
                "in " + then.format(DateTimeFormatter.ofPattern(pattern, Locale.US))
            }
        }
    }
}
