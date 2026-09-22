package com.talastack.liquorlog.engine

import kotlin.math.roundToInt

// MARK: - Volume

object Volume {
    /** Exact, by definition of the US fluid ounce. */
    const val US_FLUID_OUNCE_IN_MILLILITERS: Double = 29.5735295625

    /**
     * TTB standards of fill for distilled spirits, in millilitres.
     *
     * A size outside this list is a data-entry error rather than an exotic
     * bottle, and it corrupts every pour count derived from it. The list was
     * expanded in recent years to authorise sizes that previously were not
     * legal -- see `docs/05-data-sourcing.md`; this transcription must be
     * checked against the current regulation before the catalog ships.
     */
    val standardsOfFill: Set<Int> = setOf(
        50, 100, 200, 355, 375, 500, 700, 720, 750, 900, 1000, 1750, 1800,
    )

    fun isStandardFill(milliliters: Double): Boolean =
        standardsOfFill.contains(milliliters.roundToInt())
}

// MARK: - ABV

/**
 * Alcohol by volume, stored as a percentage.
 *
 * A distinct type rather than a bare `Double`: storage is always ABV and
 * proof is presentation, and making that a type turns "did this number
 * arrive as 62.6 or 125.2" from a discipline problem into a compile error.
 */
data class ABV(val percent: Double) : Comparable<ABV> {

    /** US proof is exactly twice ABV. */
    val proof: Double get() = percent * 2

    override fun compareTo(other: ABV): Int = percent.compareTo(other.percent)

    val isPlausible: Boolean get() = percent in PLAUSIBLE_RANGE

    companion object {
        fun fromProof(proof: Double): ABV = ABV(proof / 2)

        /**
         * A coarse sanity check spanning everything from a light beer to
         * overproof rum. It is deliberately wide, and therefore weak: it
         * accepts 6.26%, because that is a real beer strength. Catching a
         * bourbon typed as 6.26 when 62.6 was meant needs the class -- see
         * `Classification`, which holds American whiskey to a 40% floor.
         */
        val PLAUSIBLE_RANGE: ClosedFloatingPointRange<Double> = 0.5..95.0
    }
}

// MARK: - Pour size

/** How much goes in the glass. User-configurable; the default is not a constant. */
data class PourSize(val milliliters: Double) {

    val usFluidOunces: Double get() = milliliters / Volume.US_FLUID_OUNCE_IN_MILLILITERS

    companion object {
        fun fromOunces(usFluidOunces: Double): PourSize =
            PourSize(usFluidOunces * Volume.US_FLUID_OUNCE_IN_MILLILITERS)

        /**
         * 1.5 US fl oz = 44.36 ml.
         *
         * This constant is pinned by two observations that have to both
         * hold: a 750 ml bottle gives 17 pours and a 700 ml bottle gives 16.
         * Only a 1.5 oz pour rounded to nearest satisfies both (16.91 and
         * 15.78).
         */
        val standard: PourSize = fromOunces(1.5)
    }
}
