package com.talastack.liquorlog.engine

import java.time.Instant
import java.time.temporal.ChronoUnit
import kotlin.math.max

/**
 * Two tastings of one bottle, side by side.
 *
 * A bottle tasted in March and again in October is two opinions, and the
 * interesting part is never the ratings on their own -- it is what changed
 * underneath them. [TastingTrend] already says whether the score went up;
 * this says what was tasted the second time that was not there the first.
 *
 * Stages arrive as plain keys rather than a Stage type, because that lives
 * in the data module and this engine has no dependencies. Each platform
 * passes its own stage order and gets it back.
 */
object TastingComparison {

    /** One of the two tastings. */
    data class Side(
        val tastedAt: Instant,
        val rating: Int? = null,
        /** Stage key to the descriptor labels picked at that stage. */
        val descriptors: Map<String, List<String>> = emptyMap(),
    )

    /** What happened at one stage between the two. */
    data class StageDiff(
        val stage: String,
        /** Picked both times. */
        val shared: List<String>,
        /** Picked the first time and not the second. */
        val goneSince: List<String>,
        /** Picked the second time and not the first. */
        val newSince: List<String>,
    ) {
        val isUnchanged: Boolean get() = goneSince.isEmpty() && newSince.isEmpty()

        /**
         * Nothing was picked at this stage either time, so a screen can leave
         * the row out rather than print an empty comparison.
         */
        val isEmpty: Boolean get() = shared.isEmpty() && isUnchanged
    }

    data class Result(
        /** Always the older of the two, whichever order they arrived in. */
        val earlier: Side,
        val later: Side,
        /** In the caller's stage order, stages with nothing in them removed. */
        val stages: List<StageDiff>,
        val daysApart: Int,
        /**
         * Later minus earlier, when both were rated. Null when either was
         * not: a tasting with no score is not a zero.
         */
        val ratingChange: Int?,
        /**
         * One factual line. Never an interpretation -- "you liked it more" is
         * a claim about a person; "8, up from 6" is what happened.
         */
        val text: String,
    )

    fun compare(one: Side, other: Side, stageOrder: List<String>): Result {
        // Chronological whatever order the caller passed, so "what is new"
        // always means new in the later glass.
        val earlier = if (one.tastedAt <= other.tastedAt) one else other
        val later = if (one.tastedAt <= other.tastedAt) other else one

        val stages = stageOrder.mapNotNull { stage ->
            val before = earlier.descriptors[stage].orEmpty().toSet()
            val after = later.descriptors[stage].orEmpty().toSet()
            val diff = StageDiff(
                stage = stage,
                // Sorted so the same two tastings always read the same way.
                shared = before.intersect(after).sorted(),
                goneSince = before.subtract(after).sorted(),
                newSince = after.subtract(before).sorted(),
            )
            if (diff.isEmpty) null else diff
        }

        val days = max(0, ChronoUnit.DAYS.between(earlier.tastedAt, later.tastedAt).toInt())
        val change = if (earlier.rating != null && later.rating != null) {
            later.rating - earlier.rating
        } else {
            null
        }

        return Result(
            earlier = earlier,
            later = later,
            stages = stages,
            daysApart = days,
            ratingChange = change,
            text = line(days, earlier.rating, later.rating, stages),
        )
    }

    private fun line(
        daysApart: Int,
        earlierRating: Int?,
        laterRating: Int?,
        stages: List<StageDiff>,
    ): String {
        val parts = mutableListOf<String>()

        parts += when {
            daysApart == 0 -> "The same day"
            daysApart == 1 -> "A day apart"
            daysApart < 60 -> "$daysApart days apart"
            else -> {
                val months = daysApart / 30
                if (months == 1) "About a month apart" else "About $months months apart"
            }
        }

        if (earlierRating != null && laterRating != null) {
            parts += if (laterRating == earlierRating) {
                "still $laterRating out of 10"
            } else {
                val direction = if (laterRating > earlierRating) "up" else "down"
                "$laterRating out of 10, $direction from $earlierRating"
            }
        }

        val appeared = stages.sumOf { it.newSince.size }
        if (appeared > 0) {
            parts += if (appeared == 1) {
                "one note you had not made before"
            } else {
                "$appeared notes you had not made before"
            }
        }

        return parts.joinToString(". ") + "."
    }
}
