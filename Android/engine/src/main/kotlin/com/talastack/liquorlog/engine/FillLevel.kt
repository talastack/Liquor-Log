package com.talastack.liquorlog.engine

import kotlin.math.max
import kotlin.math.min

/**
 * How full the bottle is, and how much air is in it.
 *
 * The second number is the one that matters. Oxidation is driven by the
 * ratio of air to liquid, not by elapsed time alone: a bottle a quarter
 * full has three times the headroom of one three-quarters full and fades at
 * a different rate. `OxidationBand` takes headroom, not days, as its primary
 * input for exactly this reason.
 */
data class FillLevel(
    val remainingMilliliters: Double,
    val capacityMilliliters: Double,
) {
    /** Proportion of the bottle still holding liquid, 0..1. */
    val fraction: Double
        get() {
            if (capacityMilliliters <= 0) return 0.0
            return min(1.0, max(0.0, remainingMilliliters / capacityMilliliters))
        }

    /** Proportion of the bottle holding air, 0..1. */
    val headroomFraction: Double get() = 1 - fraction

    /**
     * Coarse bands, because the underlying effect is not precise enough to
     * justify a percentage.
     */
    val headroom: Headroom
        get() = when {
            headroomFraction < 0.33 -> Headroom.MINIMAL // more than two-thirds full
            headroomFraction < 0.60 -> Headroom.MODERATE // down to roughly half
            headroomFraction < 0.80 -> Headroom.HIGH // down to roughly a fifth
            else -> Headroom.SEVERE // the heel of the bottle
        }

    enum class Headroom(val storageKey: String) {
        MINIMAL("minimal"),
        MODERATE("moderate"),
        HIGH("high"),
        SEVERE("severe"),
    }
}
