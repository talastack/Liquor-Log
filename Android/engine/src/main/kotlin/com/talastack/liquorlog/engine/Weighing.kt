package com.talastack.liquorlog.engine

import kotlin.math.max

/**
 * The fill level of a bottle from its weight on a kitchen scale.
 *
 * A spirit's density is fixed by its proof, so the grams on a scale are
 * millilitres once the empty bottle's weight is known. The density comes
 * from the same TTB Table 6 the water card uses -- the volumes of alcohol
 * and water in 100 volumes of spirit -- and two constants the Gauging Manual
 * states: water weighs **8.32823** pounds per gallon in air at 60 °F
 * (27 CFR 30.66, its worked example), and 200-proof spirit **6.6096**
 * (Table 5, weight per wine gallon). Mass is conserved when water and
 * alcohol mix even though volume is not, so the density of a spirit at any
 * proof is its alcohol's mass plus its water's mass over the 100 volumes
 * they make:
 *
 *     grams per ml  =  (alcohol × 0.79364 + water × 1.0) / 100 × 0.99798
 *
 * where alcohol is proof over two and water is Table 6's figure. Checked
 * against the table's own specific-gravity-in-air column, this reproduces it
 * to within five thousandths of a percent from 101 to 150 proof -- the
 * arithmetic the table was built with. On a full 750 the difference is a few
 * hundredths of a gram; the scale is the limit.
 *
 * The tare (the empty bottle: glass, cork, label) is not looked up anywhere;
 * it is measured once, when the level is known -- a new bottle is full --
 * and kept. After that, every weighing is a level.
 */
object Weighing {

    /** Water in air at 60 °F, 8.32823 lb per US gallon, in grams per ml. */
    internal const val WATER_GRAMS_PER_MILLILITER = 8.32823 * 453.59237 / 3785.411784

    /** 200 proof against water, in air: 6.6096 / 8.32823. */
    internal const val ABSOLUTE_ALCOHOL_RELATIVE_DENSITY = 6.6096 / 8.32823

    /**
     * Grams per millilitre of a spirit at [proof], in air at 60 °F. Null
     * outside Table 6's range.
     */
    fun density(proof: Double): Double? {
        val water = Proofing.waterParts(proof) ?: return null
        val alcohol = proof / 2
        return (alcohol * ABSOLUTE_ALCOHOL_RELATIVE_DENSITY + water) / 100 *
            WATER_GRAMS_PER_MILLILITER
    }

    /** The empty bottle's weight, from one weighing at a known level. */
    fun tare(grossGrams: Double, knownMilliliters: Double, proof: Double): Double? {
        if (grossGrams <= 0 || knownMilliliters < 0) return null
        val density = density(proof) ?: return null
        val tare = grossGrams - knownMilliliters * density
        return if (tare > 0) tare else null
    }

    /** What is in the bottle, from its weight now. */
    fun remainingMilliliters(grossGrams: Double, tareGrams: Double, proof: Double): Double? {
        if (grossGrams <= 0 || tareGrams <= 0) return null
        val density = density(proof) ?: return null
        return max(0.0, (grossGrams - tareGrams) / density)
    }
}
