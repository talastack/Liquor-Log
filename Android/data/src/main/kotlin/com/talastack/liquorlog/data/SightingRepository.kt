package com.talastack.liquorlog.data

import com.talastack.liquorlog.engine.Hunt
import java.time.Instant
import java.util.UUID

/**
 * The hunt log: where you looked, what was on the shelf, what you entered.
 *
 * Two kinds of entry share one table because they answer the same question
 * from opposite ends. A **sighting** is a bottle on a shelf at a price, which
 * tells you where to go back to. A **lottery entry** is a shot you took,
 * which tells you which shops actually allocate to you. Kept apart they would
 * be two logs nobody reads; together they are the record of a hunt.
 *
 * Visits -- distilleries you have stood in -- live here too. They are the
 * same shape of fact, recorded for the same reason.
 */
class SightingRepository(private val database: LiquorDatabase) {

    private val q = database.sightingsQueries

    /** One entry, with the engine's own enums resolved. */
    data class Entry(val row: Sightings) {
        val id: String get() = row.id
        val catalogProductId: String? get() = row.catalog_product_id
        val customName: String? get() = row.custom_name?.takeIf { it.isNotBlank() }
        val store: String get() = row.store
        val region: String? get() = row.region?.takeIf { it.isNotBlank() }
        val cents: Int? get() = row.cents?.toInt()
        val count: Int? get() = row.count?.toInt()
        val note: String? get() = row.note?.takeIf { it.isNotBlank() }
        val boughtBottleId: String? get() = row.bottle_id
        val seenAt: Long get() = row.seen_at

        /** Defaults to a shelf sighting: an unreadable kind is not a lottery. */
        val kind: Hunt.Kind get() = Hunt.Kind.fromStorageKey(row.kind) ?: Hunt.Kind.SEEN

        val outcome: Hunt.Outcome?
            get() = row.outcome?.let { Hunt.Outcome.fromStorageKey(it) }
    }

    // Reading

    fun all(): List<Entry> = q.selectAllSightings().executeAsList().map { Entry(it) }

    fun byId(id: String): Entry? =
        q.selectSightingById(id).executeAsOneOrNull()?.let { Entry(it) }

    /**
     * The log as the engine reads it.
     *
     * [name] resolves a catalogue id to a display name; the engine groups by
     * product, so a sighting with no product falls back to what was typed.
     */
    fun huntSightings(name: (String) -> String? = { null }): List<Hunt.Sighting> =
        all().map { entry ->
            Hunt.Sighting(
                id = entry.id,
                productId = entry.catalogProductId,
                name = entry.catalogProductId?.let { name(it) }
                    ?: entry.customName
                    ?: "Something unnamed",
                store = entry.store,
                kind = entry.kind,
                outcome = entry.outcome,
                cents = entry.cents,
                count = entry.count,
                at = Instant.ofEpochMilli(entry.seenAt),
                boughtBottleId = entry.boughtBottleId,
            )
        }

    fun visits(): List<Visits> = q.selectAllVisits().executeAsList()

    // Writing

    fun record(
        catalogProductId: String? = null,
        customName: String? = null,
        store: String,
        kind: Hunt.Kind = Hunt.Kind.SEEN,
        outcome: Hunt.Outcome? = null,
        region: String? = null,
        cents: Int? = null,
        count: Int? = null,
        note: String? = null,
        seenAt: Long = System.currentTimeMillis(),
        now: Long = System.currentTimeMillis(),
    ): String {
        val id = UUID.randomUUID().toString()
        q.insertSighting(
            id = id,
            catalog_product_id = catalogProductId,
            custom_name = customName?.takeIf { it.isNotBlank() },
            kind = kind.storageKey,
            outcome = outcome?.storageKey,
            store = store.trim(),
            region = region?.takeIf { it.isNotBlank() },
            cents = cents?.toLong(),
            count = count?.toLong(),
            bottle_id = null,
            note = note?.takeIf { it.isNotBlank() },
            seen_at = seenAt,
            created_at = now,
            updated_at = now,
        )
        return id
    }

    /** A lottery whose result came in later. */
    fun setOutcome(id: String, outcome: Hunt.Outcome?, now: Long = System.currentTimeMillis()) =
        q.setOutcome(outcome = outcome?.storageKey, updated_at = now, id = id)

    /** The hunt ended in a bottle. Ties the two records together. */
    fun setBought(id: String, bottleId: String?, now: Long = System.currentTimeMillis()) =
        q.setBought(bottle_id = bottleId, updated_at = now, id = id)

    fun remove(id: String, now: Long = System.currentTimeMillis()) =
        q.softDeleteSighting(deleted_at = now, updated_at = now, id = id)

    fun recordVisit(
        distillery: String,
        note: String? = null,
        visitedAt: Long = System.currentTimeMillis(),
        now: Long = System.currentTimeMillis(),
    ): String {
        val id = UUID.randomUUID().toString()
        q.insertVisit(
            id = id,
            distillery = distillery.trim(),
            visited_at = visitedAt,
            note = note?.takeIf { it.isNotBlank() },
            created_at = now,
            updated_at = now,
        )
        return id
    }

    fun removeVisit(id: String, now: Long = System.currentTimeMillis()) =
        q.softDeleteVisit(deleted_at = now, updated_at = now, id = id)
}
