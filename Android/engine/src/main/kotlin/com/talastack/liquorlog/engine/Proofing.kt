package com.talastack.liquorlog.engine

import java.util.Locale
import kotlin.math.floor
import kotlin.math.min
import kotlin.math.roundToLong

/**
 * How much water takes a pour from one proof to another.
 *
 * Not a straight ratio. Ethanol and water contract when they mix, so 100
 * parts of spirit at 100 proof hold 50 parts of alcohol and **53.73** parts
 * of water, not 50. The TTB's Gauging Manual Table 6 (27 CFR 30.66)
 * tabulates those two figures for every proof, and gives the method:
 * *divide the alcohol in the given strength by the alcohol in the required
 * strength, multiply by the water in the required strength, and subtract
 * the water in the given strength -- the remainder is the water to add to
 * 100 parts of spirit.* Its own example: 112 proof to 100 proof is
 * 1.12 × 53.73 − 47.75 = 12.42 parts.
 *
 * The water column here is 51 to 150 proof, transcribed from the TTB's scan
 * of the table (ttb.gov, foia Gauging Manual Tables, Table_6.pdf) and
 * checked two ways: the anchors the regulation text prints (100 → 53.73,
 * 112 → 47.75) and the step between neighbours, which runs smoothly from
 * 0.45 to 0.53 across the range and exposed every misread digit. Alcohol is
 * proof over two by definition. Whiskey is bottled between 80 and about 145
 * proof, so the range covers every pour this app will see; outside it the
 * answer is null, never a guess. Between whole proofs the water figure is
 * interpolated, which over a half-step of 0.25 parts is exact to the
 * hundredth.
 */
object Proofing {

    /** Parts of water in 100 parts of spirit at 60 °F, by proof. */
    internal val water: Map<Int, Double> = mapOf(
        51 to 76.79, 52 to 76.34, 53 to 75.89, 54 to 75.44, 55 to 74.98,
        56 to 74.53, 57 to 74.08, 58 to 73.62, 59 to 73.17, 60 to 72.72,
        61 to 72.26, 62 to 71.81, 63 to 71.36, 64 to 70.89, 65 to 70.43,
        66 to 69.97, 67 to 69.51, 68 to 69.06, 69 to 68.59, 70 to 68.12,
        71 to 67.66, 72 to 67.19, 73 to 66.72, 74 to 66.26, 75 to 65.78,
        76 to 65.31, 77 to 64.84, 78 to 64.37, 79 to 63.90, 80 to 63.42,
        81 to 62.95, 82 to 62.47, 83 to 61.99, 84 to 61.52, 85 to 61.04,
        86 to 60.56, 87 to 60.08, 88 to 59.59, 89 to 59.11, 90 to 58.63,
        91 to 58.14, 92 to 57.66, 93 to 57.17, 94 to 56.68, 95 to 56.19,
        96 to 55.70, 97 to 55.21, 98 to 54.72, 99 to 54.22, 100 to 53.73,
        101 to 53.24, 102 to 52.74, 103 to 52.25, 104 to 51.75, 105 to 51.25,
        106 to 50.75, 107 to 50.26, 108 to 49.76, 109 to 49.26, 110 to 48.76,
        111 to 48.25, 112 to 47.75, 113 to 47.25, 114 to 46.75, 115 to 46.24,
        116 to 45.74, 117 to 45.23, 118 to 44.72, 119 to 44.22, 120 to 43.71,
        121 to 43.20, 122 to 42.69, 123 to 42.18, 124 to 41.67, 125 to 41.16,
        126 to 40.65, 127 to 40.14, 128 to 39.62, 129 to 39.11, 130 to 38.60,
        131 to 38.08, 132 to 37.57, 133 to 37.05, 134 to 36.54, 135 to 36.02,
        136 to 35.50, 137 to 34.99, 138 to 34.47, 139 to 33.95, 140 to 33.43,
        141 to 32.91, 142 to 32.38, 143 to 31.86, 144 to 31.34, 145 to 30.82,
        146 to 30.29, 147 to 29.76, 148 to 29.24, 149 to 28.71, 150 to 28.19,
    )

    const val LOWEST_PROOF = 51.0
    const val HIGHEST_PROOF = 150.0

    /**
     * Water in 100 parts of spirit at any proof the table covers,
     * interpolated between whole proofs.
     */
    internal fun waterParts(atProof: Double): Double? {
        if (atProof < LOWEST_PROOF || atProof > HIGHEST_PROOF) return null
        val lower = floor(atProof).toInt()
        val upper = min(lower + 1, HIGHEST_PROOF.toInt())
        val low = water[lower] ?: return null
        val high = water[upper] ?: return null
        val t = atProof - lower
        return low + (high - low) * t
    }

    /**
     * Millilitres of water to add to [spiritMilliliters] at [from] proof to
     * bring it to [to] proof. Null when either proof is outside the table or
     * the target is not below the start.
     */
    fun waterToAdd(from: Double, to: Double, spiritMilliliters: Double): Double? {
        if (to >= from || spiritMilliliters <= 0) return null
        val waterFrom = waterParts(from) ?: return null
        val waterTo = waterParts(to) ?: return null
        val alcoholFrom = from / 2
        val alcoholTo = to / 2
        val partsPerHundred = alcoholFrom / alcoholTo * waterTo - waterFrom
        return partsPerHundred / 100 * spiritMilliliters
    }

    /**
     * The proof a pour lands at after [waterMilliliters] of water go into
     * [spiritMilliliters] at [from] proof. Found by walking the table
     * downward, so it is the same arithmetic as [waterToAdd] run the other
     * way. Null below the table's floor or outside it.
     */
    fun proofAfterAdding(
        waterMilliliters: Double,
        fromProof: Double,
        spiritMilliliters: Double,
    ): Double? {
        if (waterMilliliters < 0 || spiritMilliliters <= 0) return null
        if (waterParts(fromProof) == null) return null
        if (waterMilliliters == 0.0) return fromProof

        var low = LOWEST_PROOF
        var high = fromProof
        val atFloor = waterToAdd(fromProof, low, spiritMilliliters) ?: return null
        if (waterMilliliters > atFloor) return null

        repeat(40) {
            val mid = (low + high) / 2
            val needed = waterToAdd(fromProof, mid, spiritMilliliters) ?: 0.0
            if (needed > waterMilliliters) low = mid else high = mid
        }
        return (low + high) / 2
    }

    /**
     * "6.2 ml — about 1¼ teaspoons". A kitchen measure beside the number,
     * because nobody owns a 6 ml pipette. A US teaspoon is 4.93 ml.
     */
    fun describe(waterMilliliters: Double): String {
        // A pour size typed as a wall of digits reaches here as a volume no
        // spoon measures; the count is capped so the conversion to an
        // integer cannot trap, and the sentence stays true.
        if (!waterMilliliters.isFinite() || waterMilliliters < 0) return "—"
        val teaspoons = waterMilliliters / 4.92892
        val quarters = min((teaspoons * 4).roundToLong(), 4_000_000L)
        val spoons = when {
            quarters < 1 -> "a few drops"
            quarters == 1L -> "about ¼ teaspoon"
            quarters == 2L -> "about ½ teaspoon"
            quarters == 3L -> "about ¾ teaspoon"
            else -> {
                val whole = quarters / 4
                val rest = (quarters % 4).toInt()
                val fraction = listOf("", "¼", "½", "¾")[rest]
                val noun = if (whole == 1L && rest == 0) "teaspoon" else "teaspoons"
                "about $whole$fraction $noun"
            }
        }
        // Locale.ROOT: millilitres are a number, not a local convention.
        return String.format(Locale.ROOT, "%.1f ml — %s", waterMilliliters, spoons)
    }
}
