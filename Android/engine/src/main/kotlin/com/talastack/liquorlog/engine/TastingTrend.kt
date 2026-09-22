package com.talastack.liquorlog.engine

import java.time.Duration
import java.time.Instant
import kotlin.math.max

/**
 * How one bottle's ratings moved between the first pour and the latest.
 *
 * The research's argument for keeping every tasting rather than one score is
 * that a bottle changes as it sits open and people want to see that: *"a
 * changing opinion is the point of keeping them all."* Rows on their own do
 * not show it -- eye-balling 6, 7, 8 down a list is work -- so this turns the
 * series into one sentence, and says nothing when there is nothing to say.
 *
 * It reports what the person recorded and never why. "Opened up" is their
 * ratings rising, not a claim about oxidation; the oxidation band makes its
 * own hedged estimate and the two are shown side by side so they can
 * disagree.
 */
object TastingTrend {

    /** One rated tasting. Unrated tastings do not count toward a trend. */
    data class Point(
        val tastedAt: Instant,
        val rating: Int,
        /** Days the bottle had been open at that tasting, when known. */
        val daysOpen: Int? = null,
    )

    enum class Direction(val storageKey: String) {
        OPENED_UP("openedUp"),
        HOLDING("holding"),
        FADING("fading"),
    }

    data class Summary(
        val direction: Direction,
        val firstRating: Int,
        val latestRating: Int,
        val tastingCount: Int,
        /** Days between the first and latest rated tastings. */
        val spanDays: Int,
        val text: String,
    )

    /**
     * A rating has to move at least this far to be called a change. One point
     * is the noise of a different evening.
     */
    const val MINIMUM_MOVE = 2

    /** Null with fewer than two rated tastings: one number is not a trend. */
    fun summarise(points: List<Point>): Summary? {
        val ordered = points.sortedBy { it.tastedAt }
        if (ordered.size < 2) return null
        val first = ordered.first()
        val latest = ordered.last()

        val move = latest.rating - first.rating
        val direction = when {
            move >= MINIMUM_MOVE -> Direction.OPENED_UP
            move <= -MINIMUM_MOVE -> Direction.FADING
            else -> Direction.HOLDING
        }

        val span = max(0L, Duration.between(first.tastedAt, latest.tastedAt).toDays()).toInt()
        val text = sentence(
            direction = direction,
            first = first,
            latest = latest,
            count = ordered.size,
            spanDays = span,
        )

        return Summary(
            direction = direction,
            firstRating = first.rating,
            latestRating = latest.rating,
            tastingCount = ordered.size,
            spanDays = span,
            text = text,
        )
    }

    private fun sentence(
        direction: Direction,
        first: Point,
        latest: Point,
        count: Int,
        spanDays: Int,
    ): String {
        val opened = latest.daysOpen
        val period = when {
            opened != null && opened > 0 -> "over $opened ${if (opened == 1) "day" else "days"} open"
            spanDays > 0 -> "over $spanDays ${if (spanDays == 1) "day" else "days"}"
            else -> "on the same day"
        }

        return when (direction) {
            Direction.OPENED_UP -> "Opened up: ${first.rating} to ${latest.rating} $period."
            Direction.FADING -> "Fading: ${first.rating} to ${latest.rating} $period."
            Direction.HOLDING -> {
                val around = if (first.rating == latest.rating) {
                    "at ${latest.rating}"
                } else {
                    "around ${latest.rating}"
                }
                "Holding $around across $count tastings $period."
            }
        }
    }
}
