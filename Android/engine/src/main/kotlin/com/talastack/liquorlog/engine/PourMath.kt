package com.talastack.liquorlog.engine

import kotlin.math.max
import kotlin.math.min
import kotlin.math.roundToInt
import kotlin.math.roundToLong

/**
 * What is left in the bottle, and what that is worth.
 *
 * The rounding rule is the whole of the difficulty here, so it is stated
 * once and applied everywhere:
 *
 * **Round to nearest, for both capacity and remaining.**
 *
 * Flooring would report a full 750 ml bottle as 16 pours and a full 700 ml
 * as 15, contradicting the two numbers this design is pinned to. Rounding
 * to nearest gives 17 and 16.
 *
 * Applying it to *remaining* means a bottle holding 16.6 pours reads "17".
 * That is accepted, and it is why [PourStatus] always carries
 * [PourStatus.remainingMilliliters] alongside the count -- the rounding
 * never has to carry weight on its own. Using different rules for the two
 * would produce a full bottle reading "16 of 17", which reads as a bug.
 */
object PourMath {

    /** Pours a volume yields, rounded to nearest. Zero for a non-positive volume. */
    fun pourCount(milliliters: Double, pourSize: PourSize): Int {
        if (milliliters <= 0 || pourSize.milliliters <= 0) return 0
        return (milliliters / pourSize.milliliters).roundToInt()
    }

    /**
     * Volume left after everything poured so far. Never negative:
     * over-pouring past empty is a logging mistake, not a bottle that owes
     * you whiskey.
     *
     * [startingFrom] is the level the count runs down from -- the most
     * recent reading somebody took by eye. Null means "assume it was full",
     * which is only true for a bottle opened after it was added to the app.
     *
     * The starting level is clamped to the bottle's capacity. A reading can
     * be stored slightly over (a bottle filled generously, a rounded guess)
     * but a fill bar showing 105% is the app being visibly wrong.
     */
    fun remainingMilliliters(
        capacity: Double,
        poured: Double,
        startingFrom: Double? = null,
    ): Double {
        val start = min(capacity, max(0.0, startingFrom ?: capacity))
        return max(0.0, start - poured)
    }

    /**
     * Millilitres for a percentage of a bottle, for a screen that lets
     * people think in fractions -- "about a third left" -- rather than
     * volumes.
     *
     * Millilitres are what gets stored. A percentage kept against a bottle
     * whose size is later corrected would silently change how much whiskey
     * the app believes is in it.
     */
    fun milliliters(percentFull: Double, capacity: Double): Double {
        if (capacity <= 0) return 0.0
        return capacity * min(1.0, max(0.0, percentFull / 100))
    }

    /** The inverse, for showing a stored volume back as a percentage. */
    fun percentFull(remaining: Double, capacity: Double): Double {
        if (capacity <= 0) return 0.0
        return min(100.0, max(0.0, remaining / capacity * 100))
    }

    /**
     * Cost of one pour, in cents, derived from the pour count the user is
     * actually shown.
     *
     * Dividing by the displayed count rather than by the exact fractional
     * one means the arithmetic checks out in the user's head: price divided
     * by the number on screen. Null when the bottle yields no pours or had
     * no price.
     */
    fun costPerPourCents(
        priceCents: Int,
        capacityMilliliters: Double,
        pourSize: PourSize,
    ): Int? {
        val count = pourCount(capacityMilliliters, pourSize)
        if (count <= 0 || priceCents <= 0) return null
        return (priceCents.toDouble() / count).roundToLong().toInt()
    }

    /**
     * Everything the bottle detail and the shelf check need in one value.
     *
     * @param pouredMilliliters everything poured SINCE the reading, when
     *   there is one.
     * @param startingMilliliters the reading itself. Null assumes a full bottle.
     */
    fun status(
        capacityMilliliters: Double,
        pouredMilliliters: Double,
        startingMilliliters: Double? = null,
        pourSize: PourSize = PourSize.standard,
    ): PourStatus {
        val remaining = remainingMilliliters(
            capacity = capacityMilliliters,
            poured = pouredMilliliters,
            startingFrom = startingMilliliters,
        )
        return PourStatus(
            capacityMilliliters = capacityMilliliters,
            remainingMilliliters = remaining,
            totalPours = pourCount(capacityMilliliters, pourSize),
            remainingPours = pourCount(remaining, pourSize),
            pourSize = pourSize,
        )
    }
}

/**
 * A bottle's fill, as displayed. Count and millilitres travel together on
 * purpose -- see the rounding note on [PourMath].
 */
data class PourStatus(
    val capacityMilliliters: Double,
    val remainingMilliliters: Double,
    val totalPours: Int,
    val remainingPours: Int,
    val pourSize: PourSize,
) {
    val isEmpty: Boolean get() = remainingMilliliters <= 0

    /**
     * There is liquid left but not enough to round to a pour. The UI says
     * "less than a pour" rather than "0", which would read as empty.
     */
    val hasPartialPourOnly: Boolean get() = remainingPours == 0 && remainingMilliliters > 0
}
