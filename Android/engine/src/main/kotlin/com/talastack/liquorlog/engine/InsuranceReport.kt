package com.talastack.liquorlog.engine

import java.time.Instant

/**
 * The collection as a document for an insurer or an executor.
 *
 * The research names this as one of three things people will pay for,
 * because it is a service rather than their own data handed back: *"the
 * insurance/estate PDF report."* It is also the one place the money is
 * wanted without hesitation -- an inventory with what was paid, when, and
 * where, with a photo, is what a claim asks for.
 *
 * This is the content. The app draws it. Every number is what the owner
 * recorded; nothing here is a valuation, and the document says so on
 * every page, because a report that reads as an appraisal is a liability
 * the app must never carry.
 */
object InsuranceReport {

    data class Line(
        val id: String,
        val name: String,
        val distillery: String? = null,
        /** Barrel, batch, pick, bottle number -- the identity of THIS bottle. */
        val detail: String? = null,
        val sizeMilliliters: Double,
        val status: String,
        val purchasedAt: Instant? = null,
        val store: String? = null,
        val paidCents: Int? = null,
        val photoFile: String? = null,
        val storageLocation: String? = null
    )

    data class Document(
        val generatedAt: Instant,
        val lines: List<Line>,
        val bottleCount: Int,
        val pricedCount: Int,
        /** The sum of what was paid, over the bottles with a price. */
        val paidTotalCents: Int,
        val title: String,
        val caveat: String
    ) {
        val unpricedCount: Int get() = bottleCount - pricedCount
    }

    const val title = "Spirits collection inventory"

    /** On every page. Not negotiable, and not softened. */
    const val caveat =
        "Purchase prices as recorded by the owner. Not an appraisal and not a " +
            "statement of current value."

    /**
     * Only bottles on the shelf, sealed or open. A finished bottle has no
     * value to insure and an executor does not need the empties. Ordered by
     * distillery then name so an adjuster can find a line.
     */
    fun build(lines: List<Line>, generatedAt: Instant = Instant.now()): Document {
        val ordered = lines.sortedWith(
            compareBy(String.CASE_INSENSITIVE_ORDER) { "${it.distillery ?: ""} ${it.name}" }
        )
        val priced = ordered.mapNotNull { it.paidCents }
        return Document(
            generatedAt = generatedAt,
            lines = ordered,
            bottleCount = ordered.size,
            pricedCount = priced.size,
            paidTotalCents = priced.sum(),
            title = title,
            caveat = caveat
        )
    }

    /**
     * The identity line for a bottle: whatever barrel-level facts it has,
     * in a fixed order, or null for a plain standard release.
     */
    fun detail(
        barrel: String? = null,
        batch: String? = null,
        pickStore: String? = null,
        bottleNumber: Int? = null,
        bottlesInBatch: Int? = null,
        topperLetter: String? = null
    ): String? {
        val parts = mutableListOf<String>()
        if (barrel != null) parts.add("Barrel $barrel")
        if (batch != null) parts.add("Batch $batch")
        if (pickStore != null) parts.add("Pick · $pickStore")
        if (bottleNumber != null) {
            if (bottlesInBatch != null) {
                parts.add("Bottle $bottleNumber of $bottlesInBatch")
            } else {
                parts.add("Bottle $bottleNumber")
            }
        }
        if (topperLetter != null) parts.add("Topper $topperLetter")
        return if (parts.isEmpty()) null else parts.joinToString(" · ")
    }
}
