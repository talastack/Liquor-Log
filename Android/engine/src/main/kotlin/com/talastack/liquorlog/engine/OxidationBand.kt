package com.talastack.liquorlog.engine

import kotlin.math.max
import kotlin.math.min
import kotlin.math.roundToInt

/**
 * How far along an open bottle is.
 *
 * **This is a rule of thumb, not chemistry.** Nobody has published a curve
 * for how fast a part-empty bourbon fades, so this gives a BAND and never a
 * date. Every result carries [Estimate.caveat], and the UI must show it -- a
 * hedged estimate presented confidently is worse than no estimate at all.
 *
 * The input that matters is **headroom, not time**. A bottle you drank
 * three-quarters of in a fortnight has barely changed; one sitting at the
 * same level for two years has. So the model is air multiplied by time, not
 * either alone.
 */
object OxidationBand {

    enum class Band(val storageKey: String, val label: String, val step: Int) {
        /** Position in the four-step meter the design draws, 0-3. */
        FRESH("fresh", "Still fresh", 0),
        PEAK("peak", "Drinking well", 1),
        FADING("fading", "Fading", 2),
        FADED("faded", "Well past its best", 3),
    }

    /**
     * Air times time, normalised so a year of exposure is the full scale.
     *
     * Pinned by two cases the design shows: a bottle at 24% headroom open 44
     * days reads *fresh*, and one at 70% headroom open 213 days reads
     * *fading*.
     */
    internal const val REFERENCE_DAYS = 365.0

    const val PEAK_THRESHOLD = 0.08
    const val FADING_THRESHOLD = 0.25
    const val FADED_THRESHOLD = 0.50

    data class Estimate(
        val band: Band,
        val headroomFraction: Double,
        val daysOpen: Int,
        /**
         * Air times time. Exposed for tests and for tuning, not for display
         * -- showing it would imply a precision this does not have.
         */
        val exposure: Double,
    ) {
        val headroomPercent: Int get() = (headroomFraction * 100).roundToInt()

        /** What the card says. Plain language, no number. */
        val summary: String
            get() = when (band) {
                Band.FRESH ->
                    "Little air in the bottle and not long open. No hurry."
                Band.PEAK ->
                    "Open long enough to have settled, with plenty left. This is " +
                        "usually when a bottle is at its best."
                Band.FADING ->
                    "Mostly air now, and open a while. Whiskey at this fill tends " +
                        "to flatten — the sweetness goes first."
                Band.FADED ->
                    "A small amount left in a mostly empty bottle, open a long " +
                        "time. Expect it to taste tired next to a fresh pour."
            }

        /** **Always shown.** The estimate is not defensible without it. */
        val caveat: String
            get() = "A rule of thumb, not chemistry. Nobody has published a real curve for " +
                "this, so the app gives you a band and never a date."
    }

    fun estimate(headroomFraction: Double, daysOpen: Int): Estimate {
        val air = min(1.0, max(0.0, headroomFraction))
        val time = min(1.0, max(0.0, daysOpen / REFERENCE_DAYS))
        val exposure = air * time

        val band = when {
            exposure < PEAK_THRESHOLD -> Band.FRESH
            exposure < FADING_THRESHOLD -> Band.PEAK
            exposure < FADED_THRESHOLD -> Band.FADING
            else -> Band.FADED
        }

        return Estimate(
            band = band,
            headroomFraction = air,
            daysOpen = max(0, daysOpen),
            exposure = exposure,
        )
    }

    fun estimate(fillLevel: FillLevel, daysOpen: Int): Estimate =
        estimate(fillLevel.headroomFraction, daysOpen)
}
