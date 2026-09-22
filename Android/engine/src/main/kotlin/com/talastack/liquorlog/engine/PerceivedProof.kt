package com.talastack.liquorlog.engine

import java.util.Locale

/**
 * Does it drink like its proof?
 *
 * The question behind "do I taste 62.6%": a barrel-proof bourbon that goes
 * down easy is a different bottle from one that scorches at the same
 * strength, and the number on the label does not tell you which you have.
 * Over a collection it is one of the more useful things to know -- it is why
 * people keep a cask-strength bottle they can drink neat.
 *
 * Heat is recorded on a 1-5 scale because that is the resolution a person
 * actually has. Anything finer would be invented precision.
 */
object PerceivedProof {

    /** How hot it actually drank. */
    enum class Heat(val value: Int, val label: String) {
        GENTLE(1, "Gentle"),
        WARM(2, "Warm"),
        FIRM(3, "Firm"),
        HOT(4, "Hot"),
        SCORCHING(5, "Scorching"),
        ;

        companion object {
            private val byValue: Map<Int, Heat> by lazy { entries.associateBy { it.value } }

            /** The 1-5 a tasting stored, or null for anything off the scale. */
            fun fromValue(value: Int): Heat? = byValue[value]
        }
    }

    enum class Verdict(val storageKey: String, val label: String) {
        /** Drinks softer than the label says. The compliment. */
        DRINKS_BELOW_ITS_PROOF("drinksBelowItsProof", "Drinks below its proof"),
        DRINKS_AT_ITS_PROOF("drinksAtItsProof", "Drinks about right"),
        /** Harsher than the strength alone would explain. */
        DRINKS_ABOVE_ITS_PROOF("drinksAboveItsProof", "Drinks above its proof"),
    }

    /**
     * What a given strength usually feels like, before the whiskey gets a
     * say.
     *
     * Bands rather than a formula: the step from 40% to 45% is barely
     * noticeable and the step from 60% to 65% is not, so a linear map would
     * be wrong at both ends.
     */
    fun expectedHeat(abv: ABV): Heat = when {
        abv.percent < 43 -> Heat.GENTLE
        abv.percent < 48 -> Heat.WARM
        abv.percent < 54 -> Heat.FIRM
        abv.percent < 60 -> Heat.HOT
        else -> Heat.SCORCHING
    }

    data class Result(
        val abv: ABV,
        val expected: Heat,
        val actual: Heat,
        val verdict: Verdict,
        /** Negative means softer than expected. */
        val difference: Int,
    ) {
        val headline: String get() = verdict.label

        val summary: String
            get() {
                // Locale.ROOT: a proof is a number, not a local convention.
                // Without it a comma-decimal locale prints "124,2 proof".
                val proof = String.format(Locale.ROOT, "%.1f", abv.proof)
                return when (verdict) {
                    Verdict.DRINKS_BELOW_ITS_PROOF ->
                        "You would not guess $proof proof from tasting it."
                    Verdict.DRINKS_AT_ITS_PROOF ->
                        "Tastes about like $proof proof should."
                    Verdict.DRINKS_ABOVE_ITS_PROOF ->
                        "Harsher than $proof proof alone would explain — worth a " +
                            "few drops of water."
                }
            }
    }

    fun compare(abv: ABV, felt: Heat): Result {
        val expected = expectedHeat(abv)
        val difference = felt.value - expected.value

        val verdict = when {
            difference <= -1 -> Verdict.DRINKS_BELOW_ITS_PROOF
            difference >= 1 -> Verdict.DRINKS_ABOVE_ITS_PROOF
            else -> Verdict.DRINKS_AT_ITS_PROOF
        }

        return Result(
            abv = abv, expected = expected, actual = felt,
            verdict = verdict, difference = difference,
        )
    }
}
