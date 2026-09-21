package com.talastack.liquorlog.data

import java.util.UUID

/**
 * Bottles you want, and what you would pay for them.
 *
 * A row names a catalogue product or a string somebody typed, and both are
 * real: the point is to write down the bottle you saw on a back shelf and
 * could not place, as well as the one you have been hunting for months.
 *
 * The target price is what the owner would pay, not what anything is worth.
 * This app has no market data and will not invent an appraisal, so the number
 * only ever means "at this price I would buy it".
 */
class WishlistRepository(private val database: LiquorDatabase) {

    private val q = database.wishlistQueries

    data class Item(
        val row: Wishlist_items,
    ) {
        val id: String get() = row.id
        val catalogProductId: String? get() = row.catalog_product_id
        val customName: String? get() = row.custom_name?.takeIf { it.isNotBlank() }
        val targetPriceCents: Int? get() = row.target_price_cents?.toInt()
        val note: String? get() = row.note?.takeIf { it.isNotBlank() }
        val addedAt: Long get() = row.created_at
    }

    fun all(): List<Item> = q.selectAllItems().executeAsList().map { Item(it) }

    fun byId(id: String): Item? = q.selectItemById(id).executeAsOneOrNull()?.let { Item(it) }

    /**
     * The catalogue products on the list.
     *
     * What the shelf check asks for: it needs to know whether the bottle in
     * somebody's hand is one they are already looking for, and nothing else
     * about the row.
     */
    fun wishedProductIds(): Set<String> =
        q.wishedProductIds().executeAsList().filterNotNull().toSet()

    fun isWished(catalogProductId: String?): Boolean =
        catalogProductId != null && catalogProductId in wishedProductIds()

    fun add(
        catalogProductId: String? = null,
        customName: String? = null,
        targetPriceCents: Int? = null,
        note: String? = null,
        now: Long = System.currentTimeMillis(),
    ): String {
        val id = UUID.randomUUID().toString()
        q.insertItem(
            id = id,
            catalog_product_id = catalogProductId,
            custom_name = customName?.takeIf { it.isNotBlank() },
            target_price_cents = targetPriceCents?.toLong(),
            note = note?.takeIf { it.isNotBlank() },
            created_at = now,
            updated_at = now,
        )
        return id
    }

    fun update(
        id: String,
        customName: String? = null,
        targetPriceCents: Int? = null,
        note: String? = null,
        now: Long = System.currentTimeMillis(),
    ) = q.updateItem(
        custom_name = customName?.takeIf { it.isNotBlank() },
        target_price_cents = targetPriceCents?.toLong(),
        note = note?.takeIf { it.isNotBlank() },
        updated_at = now,
        id = id,
    )

    /**
     * Taken off the list.
     *
     * Soft, like every other delete here: the row has to survive to tell the
     * other devices it went. Used both for "I do not want this any more" and
     * for "I bought it", which are the same row leaving for opposite reasons.
     */
    fun remove(id: String, now: Long = System.currentTimeMillis()) =
        q.softDeleteItem(deleted_at = now, updated_at = now, id = id)
}
