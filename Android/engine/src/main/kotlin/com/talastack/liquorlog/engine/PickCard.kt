package com.talastack.liquorlog.engine

import java.time.Instant
import java.time.LocalDate
import java.time.ZoneId
import java.util.Locale

/**
 * A store pick, written out as a record somebody else can use.
 *
 * The research brief found that a national, crowdsourced registry of store
 * picks and single barrels has no incumbent -- only fragments that are
 * brand-captive or stop at a state line -- and that what survives in this
 * space is *"crowdsourcing with moderation cheap enough to survive its
 * founder's attention span."* It also found the only community-welcomed
 * pattern: a non-commercial registry with *"an explicit ask for
 * contribution."*
 *
 * This is the contribution. Every pick in the app already carries the fields
 * the Nashville Barrel Co. database uses -- barrel number, mashbill, proof,
 * bottle count, who picked it -- as structured columns rather than a notes
 * field. Writing them out in a fixed shape means a pick shared to a forum, a
 * group chat or a future registry arrives as data rather than prose.
 *
 * **Plain text with a fixed key order.** It has to survive being pasted
 * anywhere, and a stable shape is what lets a registry parse it back without
 * a person in the loop.
 */
object PickCard {

    data class Pick(
        val product: String,
        val distillery: String? = null,
        val pickedBy: String? = null,
        val store: String? = null,
        val barrel: String? = null,
        val batch: String? = null,
        val recipeCode: String? = null,
        val warehouse: String? = null,
        val rick: String? = null,
        val floor: String? = null,
        val proof: Double? = null,
        val ageMonths: Int? = null,
        val entryProof: Double? = null,
        val charLevel: Int? = null,
        val finish: String? = null,
        val bottleNumber: Int? = null,
        val bottlesInBatch: Int? = null,
        val dumpedAt: Instant? = null,
        val bottledYear: Int? = null
    ) {
        /**
         * Whether there is anything barrel-specific to share. A standard
         * release is not a pick, and a card with only a product name on it
         * would be noise in a registry.
         */
        val hasBarrelDetail: Boolean
            get() = barrel != null || batch != null || recipeCode != null ||
                warehouse != null || rick != null || floor != null ||
                ageMonths != null || pickedBy != null || dumpedAt != null
    }

    /**
     * One `key: value` per line, in a fixed order, blank fields omitted.
     *
     * The order is the order somebody reads a label: what it is, who chose
     * it, where the barrel sat, what came out of it.
     */
    fun text(pick: Pick, zone: ZoneId = ZoneId.systemDefault()): String {
        val lines = mutableListOf<String>()

        fun add(key: String, value: String?) {
            if (value.isNullOrEmpty()) return
            lines.add("$key: $value")
        }

        add("Pick", pick.product)
        add("Distillery", pick.distillery)
        add("Picked by", pick.pickedBy)
        add("Store", pick.store)

        add("Barrel", pick.barrel)
        add("Batch", pick.batch)
        pick.recipeCode?.let { code ->
            // Decoded inline where the scheme is known, so a reader who does
            // not know what OESQ means gets the answer on the same line.
            val decoded = RecipeCode.parse(code)
                ?.let { " (${it.mashbill.summary}; ${it.yeast.character.lowercase()} yeast)" }
                ?: ""
            add("Recipe", code + decoded)
        }
        add("Warehouse", pick.warehouse)
        add("Rick", pick.rick)
        add("Floor", pick.floor)

        add("Proof", pick.proof?.let { String.format(Locale.ROOT, "%.1f", it) })
        add("Age", pick.ageMonths?.let { ageText(it) })
        add("Entry proof", pick.entryProof?.let { String.format(Locale.ROOT, "%.1f", it) })
        add("Char", pick.charLevel?.let { "#$it" })
        add("Finish", pick.finish)
        val number = pick.bottleNumber
        if (number != null) {
            add("Bottle", pick.bottlesInBatch?.let { "$number of $it" } ?: "$number")
        } else {
            pick.bottlesInBatch?.let { add("Bottles", "$it") }
        }
        add("Dumped", pick.dumpedAt?.let { isoDate(it, zone) })
        add("Bottled", pick.bottledYear?.toString())

        return lines.joinToString("\n")
    }

    /**
     * "9 years 4 months", because the months are the reason the pick was
     * chosen and rounding them off throws that away.
     */
    internal fun ageText(months: Int): String {
        val years = months / 12
        val rest = months % 12
        return when {
            years == 0 -> "$rest months"
            rest == 0 -> "$years years"
            else -> "$years years $rest months"
        }
    }

    internal fun isoDate(date: Instant, zone: ZoneId): String {
        val day = LocalDate.ofInstant(date, zone)
        return String.format(
            Locale.ROOT, "%04d-%02d-%02d", day.year, day.monthValue, day.dayOfMonth
        )
    }
}
