package com.talastack.liquorlog.engine

/**
 * A Four Roses recipe code: OBSV, OESQ and the eight others.
 *
 * The letters are fixed by the distillery -- O for the Cox's Creek site, S
 * for straight whiskey -- so only the second and fourth carry information:
 * which of two mashbills, and which of five yeasts. Ten combinations, and
 * the distillery publishes what each yeast contributes, which is why the
 * app can decode one without inventing anything.
 */
data class RecipeCode(val mashbill: Mashbill, val yeast: Yeast) {

    enum class Mashbill(val letter: String) {
        B("B"),
        E("E"),
        ;

        /** Percentages of corn, rye and malted barley. */
        val grains: Grains
            get() = when (this) {
                B -> Grains(corn = 60, rye = 35, maltedBarley = 5)
                E -> Grains(corn = 75, rye = 20, maltedBarley = 5)
            }

        val ryePercent: Int get() = grains.rye

        val summary: String
            get() = grains.let {
                "${it.corn}% corn, ${it.rye}% rye, ${it.maltedBarley}% malted barley"
            }

        companion object {
            fun fromLetter(letter: String): Mashbill? = entries.firstOrNull { it.letter == letter }
        }
    }

    data class Grains(val corn: Int, val rye: Int, val maltedBarley: Int)

    enum class Yeast(val letter: String, val character: String) {
        /** The distillery's own descriptors, not ours. */
        V("V", "Delicate fruit"),
        K("K", "Slight spice"),
        O("O", "Rich fruit"),
        Q("Q", "Floral essence"),
        F("F", "Herbal"),
        ;

        companion object {
            fun fromLetter(letter: String): Yeast? = entries.firstOrNull { it.letter == letter }
        }
    }

    val code: String get() = "O${mashbill.letter}S${yeast.letter}"

    override fun toString(): String = code

    companion object {
        /**
         * Parses a four-letter code. Case- and whitespace-insensitive; null
         * for anything that is not one of the ten.
         */
        fun parse(raw: String): RecipeCode? {
            val code = raw.trim().uppercase()
            if (code.length != 4) return null
            if (code[0] != 'O' || code[2] != 'S') return null
            val mashbill = Mashbill.fromLetter(code[1].toString()) ?: return null
            val yeast = Yeast.fromLetter(code[3].toString()) ?: return null
            return RecipeCode(mashbill, yeast)
        }

        /** All ten, for the picker and for the catalogue validator. */
        val all: List<RecipeCode> by lazy {
            Mashbill.entries.flatMap { mashbill -> Yeast.entries.map { RecipeCode(mashbill, it) } }
        }
    }
}
