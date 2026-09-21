package com.talastack.liquorlog.data

import com.talastack.liquorlog.engine.ABV
import com.talastack.liquorlog.engine.CSVWriter

/**
 * Everything you recorded, as CSV.
 *
 * **Export is never charged for, and never will be.** It costs almost
 * nothing and it is the single strongest trust signal in a category where
 * people have been burned by apps that held their data hostage. Now that
 * nothing in this app is charged for at all, the principle is simply the
 * shape of the feature: it is here, it is complete, and it runs with no
 * account.
 *
 * The columns are the iOS ones, in the iOS order, so a file exported on one
 * phone imports on the other. Deriving them separately per platform is how
 * two column sets that are meant to be identical drift apart.
 */
class CollectionExport(private val database: LiquorDatabase) {

    private val bottles = BottleRepository(database)
    private val tastings = TastingRepository(database)

    companion object {
        /** One row per bottle. Matches `CollectionExport.header` in Swift. */
        val bottleHeader: List<String> = listOf(
            "name", "distillery", "brand", "expression",
            "class", "production", "status",
            "sample", "sample_from", "infinity",
            "size_ml", "abv", "proof",
            "batch", "barrel", "store_pick", "pick_group", "pick_store",
            "warehouse", "rick", "floor", "recipe_code",
            "age_months", "bottle_number", "bottles_in_batch", "topper_letter", "dsp",
            "distilled_year", "bottled_year", "vintage_year",
            "purchased", "opened", "killed", "last_poured",
            "price", "bought_at", "storage_location", "shelf_number",
            "pours_remaining", "pours_total", "ml_remaining", "cost_per_pour",
            "rating",
        )

        val tastingHeader: List<String> = listOf(
            "date", "bottle", "rating", "blind",
            "would_rebuy", "worth_the_price", "heat", "finish_seconds",
            "source", "source_note", "liked", "disliked",
            "nose", "entry", "mid", "finish",
        )

        val pourHeader: List<String> = listOf("date", "bottle", "ml", "given_to", "note")
    }

    /**
     * Every bottle, finished ones included.
     *
     * An export that quietly dropped what you have already drunk would be an
     * export of part of the record, and the person would not find out until
     * they needed the part that was missing.
     */
    fun bottlesCsv(
        name: (BottleRepository.Summary) -> String = { it.name },
        distillery: (BottleRepository.Summary) -> String? = { null },
        kind: (BottleRepository.Summary) -> Pair<String?, String?> = { null to null },
    ): String {
        val rows = bottles.all().map { summary ->
            val b = summary.bottle
            val (classLabel, productionLabel) = kind(summary)
            listOf(
                name(summary),
                CSVWriter.text(distillery(summary)),
                CSVWriter.text(b.custom_name),
                "",
                CSVWriter.text(classLabel),
                CSVWriter.text(productionLabel),
                status(summary),
                CSVWriter.flag(summary.isSample),
                CSVWriter.text(b.sample_from),
                CSVWriter.flag(summary.isInfinity),
                CSVWriter.decimal(b.volume_ml, places = 0),
                CSVWriter.decimal(b.abv, places = 1),
                CSVWriter.decimal(b.abv?.let { ABV(it).proof }, places = 1),
                CSVWriter.text(b.batch_number),
                CSVWriter.text(b.barrel_number),
                CSVWriter.flag(summary.isStorePick),
                CSVWriter.text(b.pick_group),
                CSVWriter.text(b.pick_store),
                CSVWriter.text(b.warehouse),
                CSVWriter.text(b.rick),
                CSVWriter.text(b.floor),
                CSVWriter.text(b.recipe_code),
                CSVWriter.number(b.age_months?.toInt()),
                CSVWriter.number(b.bottle_number?.toInt()),
                CSVWriter.number(b.bottles_in_batch?.toInt()),
                CSVWriter.text(b.topper_letter),
                CSVWriter.text(b.dsp),
                CSVWriter.number(b.distilled_year?.toInt()),
                CSVWriter.number(b.bottled_year?.toInt()),
                CSVWriter.number(b.vintage_year?.toInt()),
                CSVWriter.date(b.purchase_date),
                CSVWriter.date(b.opened_at),
                CSVWriter.date(b.finished_at),
                CSVWriter.date(summary.lastPouredAt),
                CSVWriter.money(b.purchase_price_cents?.toInt()),
                CSVWriter.text(b.purchase_store),
                CSVWriter.text(b.storage_location),
                CSVWriter.number(b.shelf_number?.toInt()),
                CSVWriter.number(summary.status.remainingPours),
                CSVWriter.number(summary.status.totalPours),
                CSVWriter.decimal(summary.status.remainingMilliliters, places = 0),
                CSVWriter.money(summary.costPerPourCents),
                CSVWriter.number(summary.latestRating),
            )
        }
        return CSVWriter.document(bottleHeader, rows)
    }

    /** Every tasting, with its descriptors spelled out per stage. */
    fun tastingsCsv(
        name: (String) -> String = { it },
        label: (String) -> String = { it },
    ): String {
        val rows = tastings.allDetails().map { detail ->
            val t = detail.tasting
            fun stage(s: TastingRepository.Stage) =
                detail.descriptors(s).joinToString("; ") { label(it) }
            listOf(
                CSVWriter.date(detail.tastedAt),
                CSVWriter.text(detail.bottleId?.let { name(it) }),
                CSVWriter.number(detail.rating),
                CSVWriter.flag(detail.isBlind),
                CSVWriter.text(detail.rebuy?.storageKey),
                // Null and "no" are different answers. `flag` cannot say the
                // first, so a nullable column is written by hand.
                t.worth_the_price?.let { if (it != 0L) "yes" else "no" } ?: "",
                CSVWriter.number(t.perceived_heat?.toInt()),
                CSVWriter.number(t.finish_seconds?.toInt()),
                CSVWriter.text(t.source),
                CSVWriter.text(t.source_note),
                CSVWriter.text(t.liked),
                CSVWriter.text(t.disliked),
                stage(TastingRepository.Stage.NOSE),
                stage(TastingRepository.Stage.ENTRY),
                stage(TastingRepository.Stage.MID),
                stage(TastingRepository.Stage.FINISH),
            )
        }
        return CSVWriter.document(tastingHeader, rows)
    }

    /** Every pour, which is where the fill levels come from. */
    fun poursCsv(name: (String) -> String = { it }): String {
        val rows = bottles.all().flatMap { summary ->
            bottles.poursFor(summary.id).map { pour ->
                listOf(
                    CSVWriter.date(pour.poured_at),
                    name(summary.id),
                    CSVWriter.decimal(pour.volume_ml, places = 0),
                    CSVWriter.text(pour.given_to),
                    CSVWriter.text(pour.note),
                )
            }
        }
        return CSVWriter.document(pourHeader, rows)
    }

    /**
     * A bottle's state as one word.
     *
     * Three states, not two: sealed, open and finished are what the collection
     * filter uses, and an export that collapsed them would not round-trip.
     */
    private fun status(summary: BottleRepository.Summary): String = when {
        summary.isFinished -> "finished"
        summary.isOpen -> "open"
        else -> "sealed"
    }
}
