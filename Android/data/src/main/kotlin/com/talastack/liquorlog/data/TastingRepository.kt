package com.talastack.liquorlog.data

import com.talastack.liquorlog.engine.FlavorWheel
import java.util.UUID

/**
 * Tastings, and the descriptors picked for each one.
 *
 * A tasting is the only record in the app that can exist without a bottle.
 * Somebody tries something at a bar, likes it, and wants that fact kept --
 * they do not own it and may never own it. So [Detail.bottleId] and
 * [Detail.catalogProductId] are both nullable, and a tasting with neither is
 * still a tasting, titled by whatever the person typed.
 */
class TastingRepository(private val database: LiquorDatabase) {

    private val q = database.tastingsQueries

    /** The stages a descriptor can be picked on, in the order they happen. */
    enum class Stage(val storageKey: String, val label: String) {
        NOSE("nose", "Nose"),
        ENTRY("entry", "Entry"),
        MID("mid", "Mid-palate"),
        FINISH("finish", "Finish"),
        ;

        companion object {
            fun fromStorageKey(key: String): Stage? =
                entries.firstOrNull { it.storageKey == key }
        }
    }

    /**
     * Would you buy it again.
     *
     * The research rates this as more useful than a numeric score: most
     * people's ratings cluster in one narrow band, and this one does not.
     */
    enum class Rebuy(val storageKey: String, val label: String) {
        YES("yes", "Would buy again"),
        MAYBE("maybe", "Might buy again"),
        NO("no", "Would not buy again"),
        ;

        companion object {
            fun fromStorageKey(key: String?): Rebuy? =
                key?.let { k -> entries.firstOrNull { it.storageKey == k } }
        }
    }

    /** One tasting with its picks already gathered by stage. */
    data class Detail(
        val tasting: Tastings,
        val descriptors: Map<Stage, List<String>>,
    ) {
        val id: String get() = tasting.id
        val bottleId: String? get() = tasting.bottle_id
        val catalogProductId: String? get() = tasting.catalog_product_id
        val rating: Int? get() = tasting.rating?.toInt()
        val tastedAt: Long get() = tasting.tasted_at
        val liked: String? get() = tasting.liked
        val disliked: String? get() = tasting.disliked
        val isBlind: Boolean get() = tasting.blind != 0L
        val rebuy: Rebuy? get() = Rebuy.fromStorageKey(tasting.would_rebuy)

        /** "At a bar · Jack Rose", or null for your own pour. */
        val whereLabel: String?
            get() {
                val source = tasting.source?.takeIf { it.isNotBlank() } ?: return null
                val note = tasting.source_note?.takeIf { it.isNotBlank() }
                return if (note == null) source else source + " · " + note
            }

        fun descriptors(on: Stage): List<String> = descriptors[on].orEmpty()

        /**
         * "Nose: vanilla, oak · Finish: pepper", the way the history list
         * shows it. Keys are turned into labels by the wheel, falling back to
         * the key so a descriptor dropped from a later wheel still reads.
         */
        fun describe(wheel: FlavorWheel?): String =
            Stage.entries.mapNotNull { stage ->
                val keys = descriptors(stage)
                if (keys.isEmpty()) return@mapNotNull null
                val labels = keys.map { key -> wheel?.descriptor(key)?.label ?: key }
                stage.label + ": " + labels.joinToString(", ")
            }.joinToString("  ·  ")
    }

    // Reading

    /** Every tasting, newest first, descriptors included. */
    fun allDetails(): List<Detail> = detail(q.selectAllTastings().executeAsList())

    /** Every tasting of one bottle, newest first. */
    fun forBottle(bottleId: String): List<Detail> =
        detail(q.selectTastingsForBottle(bottleId).executeAsList())

    fun byId(id: String): Detail? =
        q.selectTastingById(id).executeAsOneOrNull()?.let { detail(listOf(it)).firstOrNull() }

    private fun detail(rows: List<Tastings>): List<Detail> {
        if (rows.isEmpty()) return emptyList()
        // One read of every note rather than one per tasting: the history
        // screen renders the whole list at once.
        val byTasting = q.selectAllNotes().executeAsList().groupBy { it.tasting_id }
        return rows.map { tasting ->
            val picks = byTasting[tasting.id].orEmpty()
                .mapNotNull { note ->
                    Stage.fromStorageKey(note.stage)?.let { it to note.descriptor_key }
                }
                .groupBy({ it.first }, { it.second })
            Detail(tasting = tasting, descriptors = picks)
        }
    }

    // Writing

    /**
     * Records a tasting and its picks in one transaction.
     *
     * Half a tasting -- the row saved, the descriptors lost -- is worse than
     * none, because the person believes the notes are kept.
     */
    fun record(
        bottleId: String? = null,
        catalogProductId: String? = null,
        rating: Int? = null,
        rebuy: Rebuy? = null,
        worthThePrice: Boolean? = null,
        perceivedHeat: Int? = null,
        finishSeconds: Int? = null,
        source: String? = null,
        sourceNote: String? = null,
        isBlind: Boolean = false,
        liked: String? = null,
        disliked: String? = null,
        descriptors: Map<Stage, List<String>> = emptyMap(),
        tastedAt: Long = System.currentTimeMillis(),
        now: Long = System.currentTimeMillis(),
    ): String = database.transactionWithResult {
        val id = UUID.randomUUID().toString()
        q.insertTasting(
            id = id,
            bottle_id = bottleId,
            catalog_product_id = catalogProductId,
            tasted_at = tastedAt,
            rating = rating?.toLong(),
            would_rebuy = rebuy?.storageKey,
            worth_the_price = worthThePrice?.let { if (it) 1L else 0L },
            perceived_heat = perceivedHeat?.toLong(),
            finish_seconds = finishSeconds?.toLong(),
            source = source,
            source_note = sourceNote,
            blind = if (isBlind) 1L else 0L,
            liked = liked?.takeIf { it.isNotBlank() },
            disliked = disliked?.takeIf { it.isNotBlank() },
            created_at = now,
            updated_at = now,
        )
        writeNotes(id, descriptors, now)
        id
    }

    /** Saves an edited tasting, replacing its picks wholesale. */
    fun update(
        id: String,
        rating: Int? = null,
        rebuy: Rebuy? = null,
        worthThePrice: Boolean? = null,
        perceivedHeat: Int? = null,
        finishSeconds: Int? = null,
        source: String? = null,
        sourceNote: String? = null,
        isBlind: Boolean = false,
        liked: String? = null,
        disliked: String? = null,
        descriptors: Map<Stage, List<String>> = emptyMap(),
        tastedAt: Long = System.currentTimeMillis(),
        now: Long = System.currentTimeMillis(),
    ): Unit = database.transaction {
        q.updateTasting(
            rating = rating?.toLong(),
            would_rebuy = rebuy?.storageKey,
            worth_the_price = worthThePrice?.let { if (it) 1L else 0L },
            perceived_heat = perceivedHeat?.toLong(),
            finish_seconds = finishSeconds?.toLong(),
            source = source,
            source_note = sourceNote,
            blind = if (isBlind) 1L else 0L,
            liked = liked?.takeIf { it.isNotBlank() },
            disliked = disliked?.takeIf { it.isNotBlank() },
            tasted_at = tastedAt,
            updated_at = now,
            id = id,
        )
        // Tombstone the old picks rather than deleting them, so the other
        // devices learn that they went.
        q.clearNotes(deleted_at = now, updated_at = now, tasting_id = id)
        writeNotes(id, descriptors, now)
    }

    fun softDelete(id: String, now: Long = System.currentTimeMillis()) =
        q.softDeleteTasting(deleted_at = now, updated_at = now, id = id)

    private fun writeNotes(
        tastingId: String,
        descriptors: Map<Stage, List<String>>,
        now: Long,
    ) {
        for ((stage, keys) in descriptors) {
            for (key in keys.distinct()) {
                q.insertNote(
                    id = UUID.randomUUID().toString(),
                    tasting_id = tastingId,
                    stage = stage.storageKey,
                    descriptor_key = key,
                    intensity = null,
                    created_at = now,
                    updated_at = now,
                )
            }
        }
    }
}
