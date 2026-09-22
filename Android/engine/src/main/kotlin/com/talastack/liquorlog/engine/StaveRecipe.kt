package com.talastack.liquorlog.engine

/**
 * A Maker's Mark Private Select stave recipe.
 *
 * Private Select is Maker's Mark's store-pick programme, and its picks are
 * not barrels: every one starts as fully matured Maker's, then ten oak
 * staves are chosen from five kinds and finished into the barrel for nine
 * weeks in a cold cellar. The label prints the ten. Two picks with
 * different staves are different whiskeys with one name, which is the same
 * fact about barrel-level identity this whole app is built on.
 *
 * The five kinds are Maker's own, with the flavours Maker's says each
 * brings; the counts are what the label says. A recipe must total ten,
 * because that is the rule of the programme, and one that does not is a
 * typo rather than a bottle.
 */
class StaveRecipe private constructor(val counts: Map<Stave, Int>) {

    enum class Stave(val storageKey: String) {
        BAKED_AMERICAN_PURE_2("P2"),
        SEARED_FRENCH_CUVEE("Cu"),
        MAKERS_46("46"),
        ROASTED_FRENCH_MOCHA("Mo"),
        TOASTED_FRENCH_SPICE("Sp");

        val fullName: String
            get() = when (this) {
                BAKED_AMERICAN_PURE_2 -> "Baked American Pure 2"
                SEARED_FRENCH_CUVEE -> "Seared French Cuvée"
                MAKERS_46 -> "Maker's 46"
                ROASTED_FRENCH_MOCHA -> "Roasted French Mocha"
                TOASTED_FRENCH_SPICE -> "Toasted French Spice"
            }

        /**
         * What each stave is designed to bring, as the Private Selection
         * programme describes it. Maker's own site states only that there
         * are five staves and ten per barrel; the per-stave descriptions
         * below are the programme's stave cards as reported by two
         * independent write-ups (both read 15 September 2026), which agree:
         * https://www.bourbonguy.com/blog/2017/12/12/makers-mark-private-select-part-1
         * https://www.bourbonbanter.com/makers-mark-private-select-review-randalls-wine-spirits/
         */
        val character: String
            get() = when (this) {
                BAKED_AMERICAN_PURE_2 -> "oak, vanilla, caramel and sweetness"
                SEARED_FRENCH_CUVEE -> "butterscotch, caramel, toasted oak and nuttiness"
                MAKERS_46 -> "spicy vanilla -- the same stave as Maker's 46"
                ROASTED_FRENCH_MOCHA -> "dark chocolate, coffee and char"
                TOASTED_FRENCH_SPICE -> "fruit and baking spice"
            }
    }

    fun count(of: Stave): Int = counts[of] ?: 0

    /**
     * The compact form the community writes: "P2x3 Cu x2 46x2 Mo x1 Sp x2"
     * with the multiplication sign, in the label's own order.
     */
    val code: String
        get() = Stave.entries.mapNotNull { stave ->
            val n = count(stave)
            if (n > 0) "${stave.storageKey}×$n" else null
        }.joinToString(" ")

    /**
     * The staves that dominate, most first. A recipe of ten 46 staves
     * reads "all Maker's 46"; a spread reads as its top two.
     */
    val leaning: String
        get() {
            val ordered = Stave.entries
                .map { it to count(it) }
                .filter { it.second > 0 }
                .sortedWith(
                    compareByDescending<Pair<Stave, Int>> { it.second }
                        .thenBy { it.first.ordinal }
                )
            val top = ordered.firstOrNull() ?: return ""
            if (top.second == staveCount) {
                return "All ${top.first.fullName}: ${top.first.character}."
            }
            if (ordered.size == 1) return "${top.first.fullName}: ${top.first.character}."
            val second = ordered[1]
            if (top.second == second.second) {
                return "Led equally by ${top.first.fullName} and ${second.first.fullName}: " +
                    "${top.first.character}; ${second.first.character}."
            }
            return "Led by ${top.first.fullName} (${top.second} of 10): ${top.first.character}. " +
                "Then ${second.first.fullName}: ${second.first.character}."
        }

    override fun equals(other: Any?): Boolean = other is StaveRecipe && other.counts == counts

    override fun hashCode(): Int = counts.hashCode()

    override fun toString(): String = code

    /**
     * Two recipes side by side: the staves they share, and where each one
     * has more.
     */
    data class Comparison(
        val shared: List<Stave>,
        /** Staves where the first recipe has more, with the difference. */
        val moreInFirst: List<Pair<Stave, Int>>,
        val moreInSecond: List<Pair<Stave, Int>>
    ) {
        val isIdentical: Boolean get() = moreInFirst.isEmpty() && moreInSecond.isEmpty()

        /**
         * "Identical recipes." / "The first leans more to Roasted French
         * Mocha (+2); the second to Toasted French Spice (+2)."
         */
        val text: String
            get() {
                if (isIdentical) return "Identical recipes."
                val parts = mutableListOf<String>()
                moreInFirst.firstOrNull()?.let {
                    parts.add("The first leans more to ${it.first.fullName} (+${it.second})")
                }
                moreInSecond.firstOrNull()?.let {
                    parts.add("the second to ${it.first.fullName} (+${it.second})")
                }
                return parts.joinToString("; ") + "."
            }
    }

    companion object {
        /** The total the programme fixes. */
        const val staveCount = 10

        private val CODE = Regex(
            """(P2|CU|46|MO|SP)\s*[xX]\s*([0-9]{1,2})""",
            RegexOption.IGNORE_CASE
        )

        /** Null unless the counts are non-negative and total ten. */
        fun of(counts: Map<Stave, Int>): StaveRecipe? {
            if (counts.values.any { it < 0 }) return null
            if (counts.values.sum() != staveCount) return null
            return StaveRecipe(counts.filterValues { it > 0 })
        }

        /**
         * Reads the compact form back, tolerating "x" for the multiplication
         * sign, commas, and missing zeros. Null when it does not total ten.
         */
        fun parse(raw: String): StaveRecipe? {
            val counts = mutableMapOf<Stave, Int>()
            val cleaned = raw.replace("×", "x").replace(",", " ")
            for (match in CODE.findAll(cleaned)) {
                val n = match.groupValues[2].toIntOrNull() ?: continue
                val stave = when (match.groupValues[1].uppercase()) {
                    "P2" -> Stave.BAKED_AMERICAN_PURE_2
                    "CU" -> Stave.SEARED_FRENCH_CUVEE
                    "46" -> Stave.MAKERS_46
                    "MO" -> Stave.ROASTED_FRENCH_MOCHA
                    "SP" -> Stave.TOASTED_FRENCH_SPICE
                    else -> null
                } ?: continue
                counts[stave] = (counts[stave] ?: 0) + n
            }
            return of(counts)
        }

        fun compare(a: StaveRecipe, b: StaveRecipe): Comparison {
            val shared = mutableListOf<Stave>()
            val first = mutableListOf<Pair<Stave, Int>>()
            val second = mutableListOf<Pair<Stave, Int>>()
            for (stave in Stave.entries) {
                val x = a.count(stave)
                val y = b.count(stave)
                if (x > 0 && y > 0) shared.add(stave)
                if (x > y) first.add(stave to (x - y))
                if (y > x) second.add(stave to (y - x))
            }
            return Comparison(
                shared = shared,
                moreInFirst = first.sortedByDescending { it.second },
                moreInSecond = second.sortedByDescending { it.second }
            )
        }
    }
}
