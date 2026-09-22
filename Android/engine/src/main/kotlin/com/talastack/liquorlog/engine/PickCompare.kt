package com.talastack.liquorlog.engine

import java.util.Locale
import kotlin.math.abs
import kotlin.math.roundToInt

/**
 * A store pick beside the standard release of the same product.
 *
 * The research's architectural claim is that bourbon collecting happens at
 * barrel level and every incumbent stops at the SKU. This is the screen that
 * only exists because the model went one level deeper: a Four Roses OESQ
 * pick at 58.7% sits next to the shelf bottle at 50%, and the difference in
 * proof, age, recipe, price and your own rating is laid out as facts.
 *
 * Every row is a pair of things the person recorded or the catalogue states.
 * Nothing is inferred: a pick with no stated age shows no age row, because
 * "unknown" next to "7 years" would read as a fact about the pick.
 */
object PickCompare {

    /** The pick, as the bottle in hand records it. */
    data class Pick(
        val abv: Double? = null,
        val ageMonths: Int? = null,
        val recipeCode: String? = null,
        val paidCents: Int? = null,
        val rating: Int? = null
    )

    /**
     * The standard release, from the catalogue plus what the person has
     * recorded about their own non-pick bottles of it.
     */
    data class Standard(
        val abv: Double? = null,
        val statedAgeYears: Int? = null,
        val recipeCode: String? = null,
        /** A published shelf price, or the person's own typical price. */
        val priceCents: Int? = null,
        val priceLabel: String? = null,
        /** The person's best rating of a NON-pick bottle of this product. */
        val rating: Int? = null
    )

    enum class Field(val storageKey: String) {
        PROOF("proof"),
        AGE("age"),
        RECIPE("recipe"),
        PRICE("price"),
        RATING("rating");

        val label: String
            get() = when (this) {
                PROOF -> "Proof"
                AGE -> "Age"
                RECIPE -> "Recipe"
                PRICE -> "Price"
                RATING -> "Your rating"
            }
    }

    /**
     * One fact, both sides. [difference] is the short phrase between them --
     * "+17.4 proof", "same recipe", "$20 more" -- or null when the two are
     * not comparable as numbers.
     */
    data class Row(
        val field: Field,
        val pick: String,
        val standard: String,
        val difference: String?,
        /**
         * Positive when the pick has more of it. Proof, age and rating up
         * is more; price up is more expensive. The screen colours nothing by
         * this -- more proof is not better -- it only orders.
         */
        val delta: Double?
    )

    data class Comparison(val rows: List<Row>) {
        val isEmpty: Boolean get() = rows.isEmpty()
    }

    /**
     * Only rows where BOTH sides have something to say. A comparison with
     * one side blank is a fact sheet, and the bottle screen already has one.
     */
    fun compare(pick: Pick, standard: Standard): Comparison {
        val rows = mutableListOf<Row>()

        val pickAbv = pick.abv
        val standardAbv = standard.abv
        if (pickAbv != null && standardAbv != null) {
            val pickProof = ABV(pickAbv).proof
            val standardProof = ABV(standardAbv).proof
            val delta = pickProof - standardProof
            rows.add(
                Row(
                    field = Field.PROOF,
                    pick = formatProof(pickProof),
                    standard = formatProof(standardProof),
                    difference = if (abs(delta) < 0.05) "same proof" else signed(delta, "proof"),
                    delta = delta
                )
            )
        }

        val months = pick.ageMonths
        val years = standard.statedAgeYears
        if (months != null && years != null) {
            val pickYears = months.toDouble() / 12
            val delta = pickYears - years.toDouble()
            rows.add(
                Row(
                    field = Field.AGE,
                    pick = AgeMath.describe(months),
                    standard = "$years ${if (years == 1) "year" else "years"}",
                    difference = if (abs(delta) < 1.0 / 24) "same age" else signedAge(delta),
                    delta = delta
                )
            )
        }

        val pickRecipe = pick.recipeCode
        val standardRecipe = standard.recipeCode
        if (pickRecipe != null && standardRecipe != null) {
            val same = pickRecipe.uppercase() == standardRecipe.uppercase()
            rows.add(
                Row(
                    field = Field.RECIPE,
                    pick = pickRecipe.uppercase(),
                    standard = standardRecipe.uppercase(),
                    difference = if (same) {
                        "same recipe"
                    } else {
                        recipeDifference(pickRecipe, standardRecipe)
                    },
                    delta = null
                )
            )
        }

        val paid = pick.paidCents
        val price = standard.priceCents
        if (paid != null && price != null) {
            val delta = paid - price
            val label = standard.priceLabel?.let { " ($it)" } ?: ""
            rows.add(
                Row(
                    field = Field.PRICE,
                    pick = Money.short(paid),
                    standard = Money.short(price) + label,
                    difference = when {
                        delta == 0 -> "same price"
                        delta > 0 -> "${Money.short(delta)} more"
                        else -> "${Money.short(-delta)} less"
                    },
                    delta = delta.toDouble()
                )
            )
        }

        val pickRating = pick.rating
        val standardRating = standard.rating
        if (pickRating != null && standardRating != null) {
            val delta = pickRating - standardRating
            rows.add(
                Row(
                    field = Field.RATING,
                    pick = "$pickRating/10",
                    standard = "$standardRating/10",
                    // The minus here is the plain hyphen the number carries,
                    // not the typographic one the proof and age rows use.
                    difference = when {
                        delta == 0 -> "rated the same"
                        delta > 0 -> "+$delta for the pick"
                        else -> "$delta for the pick"
                    },
                    delta = delta.toDouble()
                )
            )
        }

        return Comparison(rows)
    }

    // MARK: - Formatting

    private fun formatProof(proof: Double): String = String.format(Locale.ROOT, "%.1f", proof)

    private fun signed(value: Double, unit: String): String = String.format(
        Locale.ROOT, "%s%.1f %s", if (value > 0) "+" else "−", abs(value), unit
    )

    private fun signedAge(years: Double): String {
        val months = (abs(years) * 12).roundToInt()
        val sign = if (years > 0) "+" else "−"
        if (months % 12 == 0) {
            val whole = months / 12
            return "$sign$whole ${if (whole == 1) "year" else "years"}"
        }
        if (months < 24) return "$sign$months months"
        return String.format(Locale.ROOT, "%s%.1f years", sign, abs(years))
    }

    /**
     * For Four Roses, say WHAT differs -- mashbill or yeast -- rather than
     * just "different". Anything else is just different.
     */
    private fun recipeDifference(a: String, b: String): String {
        val x = RecipeCode.parse(a) ?: return "different recipe"
        val y = RecipeCode.parse(b) ?: return "different recipe"
        val parts = mutableListOf<String>()
        if (x.mashbill != y.mashbill) parts.add("different mashbill")
        if (x.yeast != y.yeast) parts.add("different yeast")
        return if (parts.isEmpty()) "different recipe" else parts.joinToString(", ")
    }
}
