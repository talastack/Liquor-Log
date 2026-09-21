package com.talastack.liquorlog.engine

import java.util.Locale
import kotlin.math.roundToInt

/**
 * What is in a bottle that was filled from other bottles: an infinity
 * bottle, a home vatting, a blend.
 *
 * Two numbers people want from it. The **strength**, because a blend of a
 * 124-proof and a 90-proof has no label to read; and the **make-up**, which
 * is what an infinity bottle is for -- "a third Weller, a quarter that
 * Four Roses pick, and everything else in small pieces".
 *
 * Strength is worked the way distillers' blending records are kept: the
 * alcohol in each part (its volume times its strength) is added up, and
 * the total is divided by the total volume. Alcohol is conserved when
 * spirits are mixed; the slight contraction of the mixture is ignored, as
 * it is in proof-gallon accounting. When any part's strength is unknown --
 * a barrel-proof bottle whose proof was never typed -- the blend's
 * strength is unknown too, and the profile says how much of it is unknown
 * rather than guessing.
 *
 * Make-up is by what went IN. Pouring out takes every part in proportion,
 * so the shares never change on a pour, only on an addition.
 */
object Blend {

    /**
     * One thing that went into the bottle. [key] groups additions of the
     * same source; [name] is what to print.
     */
    data class Part(
        val key: String,
        val name: String,
        val milliliters: Double,
        val abv: Double?
    )

    data class Share(
        val key: String,
        val name: String,
        val milliliters: Double,
        /** 0..1 of everything added. */
        val fraction: Double
    ) {
        val id: String get() = key

        /** "34%"; "under 1%" rather than "0%" for a splash. */
        val percentText: String
            get() {
                val percent = fraction * 100
                if (percent > 0 && percent < 1) return "under 1%"
                return "${percent.roundToInt()}%"
            }
    }

    data class Profile(
        /** Everything ever added, before any pours out. */
        val addedMilliliters: Double,
        /** Null when any part's strength is unknown. */
        val abv: Double?,
        /**
         * The volume added from parts whose strength is not known. Zero
         * when [abv] is known.
         */
        val unknownMilliliters: Double,
        /** Biggest first; equal shares alphabetical so the list is stable. */
        val shares: List<Share>
    ) {
        val partCount: Int get() = shares.size
        val isEmpty: Boolean get() = addedMilliliters <= 0

        val proof: Double? get() = abv?.let { ABV(it).proof }

        /** "112.4 proof" or why there is no number. */
        val strengthText: String
            get() {
                val proof = proof
                if (proof != null) return String.format(Locale.ROOT, "%.1f proof", proof)
                if (isEmpty) return "Nothing in it yet"
                val ml = unknownMilliliters.roundToInt()
                return "Unknown — $ml ml went in without a proof"
            }
    }

    fun profile(parts: List<Part>): Profile {
        val live = parts.filter { it.milliliters > 0 }
        val total = live.sumOf { it.milliliters }

        // Insertion-ordered so the name kept for a key is the first one
        // typed, as on the Swift side.
        val byKey = LinkedHashMap<String, Pair<String, Double>>()
        for (part in live) {
            val existing = byKey[part.key]
            byKey[part.key] = if (existing == null) {
                part.name to part.milliliters
            } else {
                existing.first to (existing.second + part.milliliters)
            }
        }

        val shares = byKey
            .map { (key, entry) ->
                Share(
                    key = key,
                    name = entry.first,
                    milliliters = entry.second,
                    fraction = if (total > 0) entry.second / total else 0.0
                )
            }
            .sortedWith(
                compareByDescending<Share> { it.milliliters }
                    .thenBy(String.CASE_INSENSITIVE_ORDER) { it.name }
            )

        val unknown = live.filter { it.abv == null }.sumOf { it.milliliters }
        var abv: Double? = null
        if (total > 0 && unknown == 0.0) {
            val alcohol = live.sumOf { it.milliliters * (it.abv ?: 0.0) }
            abv = alcohol / total
        }

        return Profile(
            addedMilliliters = total,
            abv = abv,
            unknownMilliliters = unknown,
            shares = shares
        )
    }
}
