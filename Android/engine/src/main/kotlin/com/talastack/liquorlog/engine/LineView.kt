package com.talastack.liquorlog.engine

/**
 * One brand's line, expression by expression, against what you have.
 *
 * "Which Wellers do I have" is the aisle question one level up from the
 * shelf check: not this bottle, but this family. The catalogue knows the
 * expressions; the holdings and tastings know which you have, had, or have
 * only tasted. Laid side by side it reads as a fact about the collection.
 *
 * It is deliberately not a progress bar: no percentage, no bar, nothing
 * that treats a tasting as a step. The one count it carries -- "3 of the
 * 7 releases the catalogue lists have been on your shelf" -- is a count of
 * BOTTLES, which is what a collection is measured in; a drink at a bar
 * never moves it. The research is clear that collection-as-score gets an
 * app rated 1, 1, 1, and that is the line this stays on.
 */
object LineView {

    enum class Standing(val storageKey: String) {
        ON_SHELF("onShelf"),

        /** A sample on hand and no bottle. */
        SAMPLE("sample"),
        HAD_IT_BEFORE("hadItBefore"),
        TASTED_ONLY("tastedOnly"),
        NEVER("never");

        val label: String
            get() = when (this) {
                ON_SHELF -> "On your shelf"
                SAMPLE -> "Have a sample"
                HAD_IT_BEFORE -> "Had it"
                TASTED_ONLY -> "Tasted"
                NEVER -> "Never had it"
            }
    }

    data class Row(val product: ProductIdentity, val standing: Standing) {
        val id: String get() = product.productId
    }

    data class Line(
        val distillery: String,
        val brand: String,
        val rows: List<Row>
    ) {
        val isEmpty: Boolean get() = rows.isEmpty()

        /**
         * Expressions a bottle of which has been on your shelf: owned,
         * a sample, or finished. Tastings do not count -- a collection is
         * counted in bottles, never in drinks had (docs/00-positioning.md).
         */
        val hadCount: Int
            get() = rows.count {
                it.standing == Standing.ON_SHELF ||
                    it.standing == Standing.SAMPLE ||
                    it.standing == Standing.HAD_IT_BEFORE
            }

        /**
         * "3 of the 7 releases the catalogue lists have been on your
         * shelf." A count of bottles against what the app happens to
         * list; not a goal, not a checklist anybody set. Null for a line
         * of one, where it says nothing.
         */
        val completionLine: String?
            get() {
                if (rows.size <= 1) return null
                val had = hadCount
                if (had == 0) {
                    return "None of the ${rows.size} releases the catalogue lists " +
                        "has been on your shelf yet."
                }
                if (had == rows.size) {
                    return "All ${rows.size} releases the catalogue lists have been on your shelf."
                }
                return "$had of the ${rows.size} releases the catalogue lists " +
                    "have been on your shelf."
            }

        /** What is left, in catalogue order. */
        val notYet: List<ProductIdentity>
            get() = rows.filter { it.standing == Standing.NEVER }.map { it.product }
    }

    /** One line's count for a summary screen: "Weller - 4 of 7". */
    data class Completion(
        val distillery: String,
        val brand: String,
        val had: Int,
        val total: Int
    ) {
        val id: String get() = "$distillery|$brand"
        val fraction: Double get() = if (total > 0) had.toDouble() / total.toDouble() else 0.0
    }

    /**
     * Every line you have had a bottle of, against what the catalogue
     * lists of it. Bottles only -- owned, sampled or finished; a tasting
     * at a bar is a drink, not a bottle, and the collection screen counts
     * bottles. Lines of one expression are left out ("1 of 1" is not a
     * fact about a collection) and so are lines you have nothing of.
     * Most complete first, then biggest, then by name, so the list holds
     * still between launches.
     */
    fun completions(
        catalogue: List<ProductIdentity>,
        holdings: List<Holding>
    ): List<Completion> {
        val had = holdings.map { it.product.productId }.toSet()
        return catalogue.groupBy { it.lineKey }.values
            .mapNotNull { members ->
                if (members.size <= 1) return@mapNotNull null
                val first = members.firstOrNull() ?: return@mapNotNull null
                val count = members.count { it.productId in had }
                if (count == 0) return@mapNotNull null
                Completion(
                    distillery = first.distillery, brand = first.brand,
                    had = count, total = members.size
                )
            }
            .sortedWith(
                compareByDescending<Completion> { it.fraction }
                    .thenByDescending { it.total }
                    .thenBy(String.CASE_INSENSITIVE_ORDER) { it.brand }
            )
    }

    /**
     * Every catalogue product sharing the line of [product], in catalogue
     * order, with the person's standing on each. The product itself is
     * included: the line view is where you are, not only what is missing.
     */
    fun line(
        product: ProductIdentity,
        catalogue: List<ProductIdentity>,
        holdings: List<Holding>,
        tastings: List<TastingRecord>
    ): Line {
        val key = product.lineKey
        val members = catalogue.filter { it.lineKey == key }

        val live = holdings.filter { !it.isFinished }
        val onShelf = live.filter { !it.isSample }.map { it.product.productId }.toSet()
        val sampled = live.filter { it.isSample }.map { it.product.productId }.toSet()
        val finished = holdings.filter { it.isFinished }.map { it.product.productId }.toSet()
        val tasted = tastings.map { it.product.productId }.toSet()

        val rows = members.map { member ->
            val id = member.productId
            val standing = when {
                id in onShelf -> Standing.ON_SHELF
                id in sampled -> Standing.SAMPLE
                id in finished -> Standing.HAD_IT_BEFORE
                id in tasted -> Standing.TASTED_ONLY
                else -> Standing.NEVER
            }
            Row(member, standing)
        }
        return Line(distillery = product.distillery, brand = product.brand, rows = rows)
    }
}
