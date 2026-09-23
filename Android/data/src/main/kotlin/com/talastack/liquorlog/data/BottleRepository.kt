package com.talastack.liquorlog.data

import com.talastack.liquorlog.engine.ClassType
import com.talastack.liquorlog.engine.PourMath
import com.talastack.liquorlog.engine.PourSize
import com.talastack.liquorlog.engine.PourStatus
import com.talastack.liquorlog.engine.ProductionType
import java.util.UUID

/**
 * The bottles on the shelf.
 *
 * Every write stamps `updated_at` and sets `dirty`, because those two
 * together are the whole push queue: `updated_at` decides who wins a
 * conflict and `dirty` decides what gets sent. A write that sets one without
 * the other either strands the change locally forever or loses it to an older
 * edit from another device.
 *
 * `user_id` is left NULL on insert. The app works with no account, and
 * [AccountLinker.adopt] stamps the whole collection the moment somebody signs
 * in -- which is also why nothing here ever writes a user id itself.
 */
class BottleRepository(private val database: LiquorDatabase) {

    private val q = database.bottlesQueries
    private val t = database.tastingsQueries
    private val f = database.fillReadingsQueries
    private val bl = database.blendsQueries

    /**
     * One bottle as a screen needs it: the row, the fill worked out, and the
     * three facts that live in other tables.
     *
     * Mirrors the iOS `BottleSummary`. The derived numbers -- fill, cost per
     * pour, days open -- are computed by the engine from the row and never
     * stored, so two platforms reading the same database agree.
     */
    data class Summary(
        val bottle: Bottles,
        val status: PourStatus,
        val latestRating: Int?,
        val tastingCount: Int,
        /** Epoch millis of the last pour. Null means never poured from. */
        val lastPouredAt: Long?,
    ) {
        val id: String get() = bottle.id
        val name: String get() = bottle.custom_name ?: "Untitled bottle"
        val volumeMl: Double get() = bottle.volume_ml
        val abv: Double? get() = bottle.abv
        val isOpen: Boolean get() = bottle.opened_at != null
        val isFinished: Boolean get() = bottle.finished_at != null
        val isSample: Boolean get() = bottle.is_sample != 0L
        val isInfinity: Boolean get() = bottle.is_infinity != 0L
        val isStorePick: Boolean get() = bottle.is_store_pick != 0L
        val purchasePriceCents: Long? get() = bottle.purchase_price_cents
        val storageLocation: String? get() = bottle.storage_location

        /**
         * "B523", "Barrel 42-3C" -- whichever of the two this bottle has.
         *
         * Derived rather than stored, as on iOS, because a bottle can carry a
         * batch code, a barrel number, both or neither, and a stored string
         * would be a fourth thing to keep in step.
         */
        val releaseLabel: String?
            get() {
                val parts = listOfNotNull(
                    bottle.batch_number?.takeIf { it.isNotBlank() },
                    bottle.barrel_number?.takeIf { it.isNotBlank() }?.let { "Barrel " + it },
                )
                return parts.takeIf { it.isNotEmpty() }?.joinToString(" · ")
            }

        /** What one pour cost, from what was paid. Null with no price. */
        val costPerPourCents: Int?
            get() {
                val paid = bottle.purchase_price_cents?.toInt() ?: return null
                return PourMath.costPerPourCents(
                    priceCents = paid,
                    capacityMilliliters = bottle.volume_ml,
                    pourSize = PourSize(bottle.pour_size_ml),
                )
            }

        /** Whole days since the last pour, or null if never poured from. */
        fun daysSinceLastPour(now: Long = System.currentTimeMillis()): Int? {
            val last = lastPouredAt ?: return null
            return maxOf(0, ((now - last) / 86_400_000L).toInt())
        }

        /** Whole days the bottle has been open, or null if it is sealed. */
        fun daysOpen(now: Long = System.currentTimeMillis()): Int? {
            val opened = bottle.opened_at ?: return null
            return maxOf(0, ((now - opened) / 86_400_000L).toInt())
        }
    }

    // Reading

    /**
     * Everything on the shelf, newest first.
     *
     * The pour totals, ratings and last-pour dates are four grouped queries
     * for the whole shelf rather than four per bottle: a hundred-bottle
     * collection was four hundred round trips otherwise, and it showed.
     */
    fun onShelf(): List<Summary> = summarise(q.selectOnShelf().executeAsList())

    /** Everything, finished bottles included. */
    fun all(): List<Summary> = summarise(q.selectAll().executeAsList())

    fun countOnShelf(): Long = q.countLive().executeAsOne()

    fun byId(id: String): Summary? =
        q.selectById(id).executeAsOneOrNull()?.let { summarise(listOf(it)).firstOrNull() }

    fun poursFor(bottleId: String): List<Pours> = q.poursFor(bottleId).executeAsList()

    fun readingsFor(bottleId: String): List<Fill_readings> =
        f.readingsFor(bottleId).executeAsList()

    fun additionsFor(blendBottleId: String): List<Blend_additions> =
        bl.additionsFor(blendBottleId).executeAsList()

    fun customEntries(): List<Custom_catalog_entries> =
        q.selectCustomEntries().executeAsList()

    fun customEntry(id: String): Custom_catalog_entries? =
        q.selectCustomEntryById(id).executeAsOneOrNull()

    private fun summarise(rows: List<Bottles>): List<Summary> {
        if (rows.isEmpty()) return emptyList()
        // Only what was poured SINCE the latest reading. A pour from before
        // it was already accounted for by whoever looked at the bottle; the
        // whole point of a reading is that the log before it was wrong.
        val poured = f.pouredSince().executeAsList()
            .associate { it.bottle_id to (it.poured_ml ?: 0.0) }
        val readings = f.latestReadings().executeAsList()
            .mapNotNull { row -> row.read_at?.let { row.bottle_id to row.remaining_ml } }
            .toMap()
        val lastPour = q.lastPouredAts().executeAsList()
            .mapNotNull { row -> row.last_poured_at?.let { row.bottle_id to it } }
            .toMap()
        val ratings = t.latestRatings().executeAsList()
            .mapNotNull { row ->
                val bottleId = row.bottle_id ?: return@mapNotNull null
                val rating = row.rating ?: return@mapNotNull null
                bottleId to rating.toInt()
            }
            .toMap()
        val counts = t.tastingCounts().executeAsList()
            .mapNotNull { row -> row.bottle_id?.let { it to row.n.toInt() } }
            .toMap()

        return rows.map { bottle ->
            Summary(
                bottle = bottle,
                status = PourMath.status(
                    capacityMilliliters = bottle.volume_ml,
                    pouredMilliliters = poured[bottle.id] ?: 0.0,
                    startingMilliliters = startingFor(bottle, readings[bottle.id]),
                    // NOT NULL with a default in the schema, so there is no
                    // absent case to fall back from.
                    pourSize = PourSize(bottle.pour_size_ml),
                ),
                latestRating = ratings[bottle.id],
                tastingCount = counts[bottle.id] ?: 0,
                lastPouredAt = lastPour[bottle.id],
            )
        }
    }

    /**
     * Where a bottle's fill counts down from.
     *
     * Null means "assume it was full", which is only true of a bottle opened
     * after it was added to the app.
     *
     * **An infinity bottle is the other way round.** It does not start full
     * and go down; it starts EMPTY and goes up as things are poured in. So
     * its starting level is what has been added -- from the last reading if
     * there is one, because a reading of an infinity bottle says how much is
     * in it now and only what happened afterwards counts.
     */
    private fun startingFor(bottle: Bottles, reading: Double?): Double? {
        if (bottle.is_infinity == 0L) return reading
        // With no reading this is 0, so every addition ever counts -- which
        // is what an infinity bottle nobody has measured should read.
        val readAt = f.latestReadingFor(bottle.id).executeAsOneOrNull()?.read_at ?: 0L
        val added = bl.addedSince(blend_bottle_id = bottle.id, added_at = readAt)
            .executeAsOne().added_ml ?: 0.0
        return (reading ?: 0.0) + added
    }

    // Writing

    /**
     * Adds a bottle. Returns its id.
     *
     * The id is generated here rather than by the database, because sync is an
     * upsert keyed on it: a device offline for a week still has to produce ids
     * that will not collide with another device's.
     *
     * [catalogProductId] is the bundled catalogue's own id, for a bottle
     * matched to it. When it is given, nothing else is written: the
     * catalogue already holds the distillery, class, production type and
     * strength, and a custom entry beside it would be a second answer to the
     * same question. **It is also what makes the shelf check right** -- a
     * matched bottle has to carry the catalogue's id or the aisle gets told
     * "never had it" about a bottle standing at home.
     *
     * Without it, a bottle typed in by hand gets a custom catalogue entry
     * when a class type is given, because that entry is where the collection
     * filter reads its kind from. Both rows go in one transaction: a bottle
     * pointing at an entry that was never written filters as nothing.
     */
    fun add(
        name: String,
        volumeMl: Double,
        catalogProductId: String? = null,
        abv: Double? = null,
        category: String = "spirit",
        classType: ClassType? = null,
        productionType: ProductionType = ProductionType.UNSPECIFIED,
        isBarrelProof: Boolean = false,
        isBottledInBond: Boolean = false,
        distillery: String? = null,
        ageMonths: Long? = null,
        isStorePick: Boolean = false,
        pickStore: String? = null,
        pickName: String? = null,
        barrelNumber: String? = null,
        batchNumber: String? = null,
        recipeCode: String? = null,
        purchaseDate: Long? = null,
        purchasePriceCents: Long? = null,
        purchaseStore: String? = null,
        storageLocation: String? = null,
        isSample: Boolean = false,
        sampleFrom: String? = null,
        isInfinity: Boolean = false,
        pourSizeMl: Double = PourSize.standard.milliliters,
        openNow: Boolean = false,
        now: Long = System.currentTimeMillis(),
    ): String = database.transactionWithResult {
        val id = UUID.randomUUID().toString()
        // A catalogue match needs no entry of its own.
        val entryId = when {
            catalogProductId != null -> catalogProductId
            classType != null -> UUID.randomUUID().toString()
            else -> null
        }
        if (catalogProductId == null && entryId != null && classType != null) {
            q.insertCustomEntry(
                id = entryId,
                distillery = distillery?.takeIf { it.isNotBlank() } ?: name,
                brand = name,
                expression = "",
                class_type = classType.storageKey,
                production_type = productionType.storageKey,
                is_barrel_proof = if (isBarrelProof) 1L else 0L,
                is_bottled_in_bond = if (isBottledInBond) 1L else 0L,
                abv = abv,
                stated_age_years = ageMonths?.let { it / 12 },
                recipe_code = recipeCode,
                created_at = now,
                updated_at = now,
            )
        }
        q.insert(
            id = id,
            catalog_product_id = entryId,
            custom_name = name,
            volume_ml = volumeMl,
            abv = abv,
            category = category,
            is_store_pick = if (isStorePick) 1L else 0L,
            pick_store = pickStore,
            pick_name = pickName,
            barrel_number = barrelNumber,
            batch_number = batchNumber,
            recipe_code = recipeCode,
            age_months = ageMonths,
            purchase_date = purchaseDate,
            purchase_price_cents = purchasePriceCents,
            purchase_store = purchaseStore,
            storage_location = storageLocation,
            is_sample = if (isSample) 1L else 0L,
            sample_from = sampleFrom,
            is_infinity = if (isInfinity) 1L else 0L,
            pour_size_ml = pourSizeMl,
            opened_at = if (openNow) now else null,
            created_at = now,
            updated_at = now,
        )
        id
    }

    /**
     * Saves the fields the edit screen owns.
     *
     * The custom catalogue entry travels with it, in the same transaction:
     * changing a bottle's class type without changing its entry leaves the
     * detail screen and the filter chips disagreeing about what it is.
     */
    fun update(
        id: String,
        name: String,
        volumeMl: Double,
        abv: Double? = null,
        category: String = "spirit",
        classType: ClassType? = null,
        productionType: ProductionType = ProductionType.UNSPECIFIED,
        isBarrelProof: Boolean = false,
        isBottledInBond: Boolean = false,
        distillery: String? = null,
        ageMonths: Long? = null,
        isStorePick: Boolean = false,
        pickStore: String? = null,
        pickName: String? = null,
        barrelNumber: String? = null,
        batchNumber: String? = null,
        recipeCode: String? = null,
        purchaseDate: Long? = null,
        purchasePriceCents: Long? = null,
        purchaseStore: String? = null,
        storageLocation: String? = null,
        isSample: Boolean = false,
        sampleFrom: String? = null,
        pourSizeMl: Double = PourSize.standard.milliliters,
        now: Long = System.currentTimeMillis(),
    ): Unit = database.transaction {
        q.update(
            custom_name = name,
            volume_ml = volumeMl,
            abv = abv,
            category = category,
            is_store_pick = if (isStorePick) 1L else 0L,
            pick_store = pickStore,
            pick_name = pickName,
            barrel_number = barrelNumber,
            batch_number = batchNumber,
            recipe_code = recipeCode,
            age_months = ageMonths,
            purchase_date = purchaseDate,
            purchase_price_cents = purchasePriceCents,
            purchase_store = purchaseStore,
            storage_location = storageLocation,
            is_sample = if (isSample) 1L else 0L,
            sample_from = sampleFrom,
            pour_size_ml = pourSizeMl,
            updated_at = now,
            id = id,
        )
        // Only a custom entry is edited. A bottle matched to the bundled
        // catalogue points at a row this app does not own and must not
        // rewrite, so its facts stay the catalogue's.
        val entryId = q.selectById(id).executeAsOneOrNull()?.catalog_product_id
            ?.takeIf { q.selectCustomEntryById(it).executeAsOneOrNull() != null }
        if (entryId != null && classType != null) {
            q.updateCustomEntry(
                distillery = distillery?.takeIf { it.isNotBlank() } ?: name,
                brand = name,
                expression = "",
                class_type = classType.storageKey,
                production_type = productionType.storageKey,
                is_barrel_proof = if (isBarrelProof) 1L else 0L,
                is_bottled_in_bond = if (isBottledInBond) 1L else 0L,
                abv = abv,
                stated_age_years = ageMonths?.let { it / 12 },
                recipe_code = recipeCode,
                updated_at = now,
                id = entryId,
            )
        }
    }

    fun open(id: String, now: Long = System.currentTimeMillis()) =
        q.open(opened_at = now, updated_at = now, id = id)

    fun finish(id: String, now: Long = System.currentTimeMillis()) =
        q.finish(finished_at = now, updated_at = now, id = id)

    fun unfinish(id: String, now: Long = System.currentTimeMillis()) =
        q.unfinish(updated_at = now, id = id)

    /** Soft, always. A hard delete breaks sync and destroys the history. */
    fun softDelete(id: String, now: Long = System.currentTimeMillis()) =
        q.softDelete(deleted_at = now, updated_at = now, id = id)

    fun setPhoto(id: String, fileName: String?, now: Long = System.currentTimeMillis()) =
        q.setPhoto(photo_file = fileName, updated_at = now, id = id)

    /**
     * Logs a pour, and opens the bottle if it was not open.
     *
     * One transaction: a pour recorded against a bottle that is still sealed
     * is a fill level nothing can explain.
     *
     * Returns the pour's id, so a tasting recorded in the same breath can
     * point at it.
     */
    fun logPour(
        bottleId: String,
        milliliters: Double = PourSize.standard.milliliters,
        givenTo: String? = null,
        note: String? = null,
        now: Long = System.currentTimeMillis(),
    ): String = database.transactionWithResult {
        val id = UUID.randomUUID().toString()
        q.open(opened_at = now, updated_at = now, id = bottleId)
        q.insertPour(
            id = id,
            bottle_id = bottleId,
            volume_ml = milliliters,
            poured_at = now,
            note = note,
            given_to = givenTo,
            into_bottle_id = null,
            created_at = now,
            updated_at = now,
        )
        id
    }

    /**
     * Records what is actually left, by eye.
     *
     * This is how somebody corrects a bottle the pour log could never have
     * been right about: one opened years before the app existed, or one
     * poured from four times at a party. From here the fill starts at this
     * number and only later pours count against it.
     *
     * Setting a level below full on a sealed bottle opens it, in the same
     * transaction. A bottle that is visibly part-empty and still marked
     * sealed is a state nothing can explain, and it would leave the
     * oxidation clock unstarted.
     */
    fun setLevel(
        bottleId: String,
        remainingMilliliters: Double,
        note: String? = null,
        now: Long = System.currentTimeMillis(),
    ): String = database.transactionWithResult {
        val bottle = q.selectById(bottleId).executeAsOneOrNull()
        val clamped = minOf(bottle?.volume_ml ?: remainingMilliliters, maxOf(0.0, remainingMilliliters))
        val id = UUID.randomUUID().toString()
        f.insertReading(
            id = id,
            bottle_id = bottleId,
            read_at = now,
            remaining_ml = clamped,
            note = note?.takeIf { it.isNotBlank() },
            created_at = now,
            updated_at = now,
        )
        if (bottle != null && bottle.opened_at == null && clamped < bottle.volume_ml) {
            q.open(opened_at = now, updated_at = now, id = bottleId)
        }
        id
    }

    /**
     * Pours something into an infinity bottle.
     *
     * One transaction, always. The whiskey comes OFF the source bottle as a
     * real pour and goes ON to the blend as an addition, and a half-written
     * version of that is a volume that left one bottle without arriving in
     * the other -- a number nothing in the app could explain afterwards.
     *
     * [sourceBottleId] is null for something poured in from outside the
     * collection: a sample, a friend's bottle, a bar pour brought home. It
     * still counts toward what is in the blend and toward its strength.
     */
    fun addToBlend(
        blendBottleId: String,
        milliliters: Double,
        sourceBottleId: String? = null,
        sourceName: String? = null,
        abv: Double? = null,
        note: String? = null,
        now: Long = System.currentTimeMillis(),
    ): String = database.transactionWithResult {
        val source = sourceBottleId?.let { q.selectById(it).executeAsOneOrNull() }
        val pourId = if (source != null) {
            val id = UUID.randomUUID().toString()
            q.open(opened_at = now, updated_at = now, id = source.id)
            q.insertPour(
                id = id,
                bottle_id = source.id,
                volume_ml = milliliters,
                poured_at = now,
                note = note,
                given_to = null,
                into_bottle_id = blendBottleId,
                created_at = now,
                updated_at = now,
            )
            id
        } else {
            null
        }

        val id = UUID.randomUUID().toString()
        bl.insertAddition(
            id = id,
            blend_bottle_id = blendBottleId,
            source_bottle_id = sourceBottleId,
            // The name is copied rather than looked up later: a source
            // bottle removed from the collection must not erase what went
            // into the blend.
            source_name = sourceName?.takeIf { it.isNotBlank() }
                ?: source?.custom_name,
            abv = abv ?: source?.abv,
            volume_ml = milliliters,
            pour_id = pourId,
            added_at = now,
            note = note?.takeIf { it.isNotBlank() },
            created_at = now,
            updated_at = now,
        )
        id
    }

    /**
     * Undoes a pour.
     *
     * A pour into an infinity bottle undoes there as well: the whiskey did
     * not go in if it never left. Without that the source bottle's fill
     * goes back up while the blend still counts the same liquid, and the
     * two disagree for good -- the blend has no capacity to check itself
     * against. iOS has always cascaded here; Android had no way to undo a
     * pour at all until today, which is why this was never wrong before.
     */
    fun deletePour(pourId: String, now: Long = System.currentTimeMillis()): Unit =
        database.transaction {
            q.deletePour(deleted_at = now, updated_at = now, id = pourId)
            bl.additionForPour(pour_id = pourId).executeAsOneOrNull()?.let { addition ->
                bl.softDeleteAddition(deleted_at = now, updated_at = now, id = addition.id)
            }
        }

    /**
     * An empty vessel you fill from your other bottles.
     *
     * It starts open and at zero rather than full: the whole point is that
     * what is in it arrived from somewhere else.
     */
    fun startInfinityBottle(
        name: String,
        volumeMl: Double,
        now: Long = System.currentTimeMillis(),
    ): String = add(
        name = name.ifBlank { "Infinity bottle" },
        volumeMl = volumeMl,
        isInfinity = true,
        openNow = true,
        now = now,
    )
}
