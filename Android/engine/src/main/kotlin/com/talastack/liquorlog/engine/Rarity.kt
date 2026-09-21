package com.talastack.liquorlog.engine

import java.util.Locale
import kotlin.math.roundToInt

/**
 * How hard a bottle is to get, from measured allocation rather than opinion.
 *
 * The research is pointed about the incumbent's version: OnlyDrams' rarity
 * tiers are *"an editorial label of unknown and demonstrably inconsistent
 * provenance"* -- no methodology published anywhere, and two records for the
 * same bottle showing different tiers. *"This is an attack surface, not a
 * moat."* The one thing the community demonstrably loves about that app is
 * built on nothing.
 *
 * This is built on numbers a state publishes. Virginia ABC's lottery posts
 * bottles available AND entries received per product -- 640 bottles of George
 * T. Stagg, 44,696 entries -- which is measured demand against measured
 * supply, and 70:1 is a fact rather than a tier somebody typed in.
 *
 * **What it deliberately cannot say.** Every free source skews to the scarce
 * end, so this can grade the allocated tier and has *no basis at all* for
 * distinguishing "common" from "uncommon". The research suspects that gap is
 * exactly why OnlyDrams' tiers are inconsistent. So there are three honest
 * states, and "not allocated" is one of them -- it is a real, useful fact
 * about a bottle, and inventing a tier below it would be the mistake this
 * type exists to avoid.
 */
object Rarity {

    /** What a state published about one release. */
    data class Allocation(
        /** Bottles the state received for this release. */
        val bottles: Int,
        /** Lottery entries, where the state runs one and publishes the count. */
        val entries: Int? = null,
        /** Which board, verbatim, shown beside the figure: "Virginia ABC". */
        val source: String,
        val year: Int? = null
    ) {
        /** Entries per bottle. Null without an entry count. */
        val demandRatio: Double?
            get() {
                val count = entries ?: return null
                if (bottles <= 0) return null
                return count.toDouble() / bottles.toDouble()
            }
    }

    sealed class Verdict {
        /** The state ran a lottery and published both numbers. */
        data class Contested(val ratio: Double) : Verdict()

        /** The state published how many bottles arrived, and nothing else. */
        data class Allocated(val bottles: Int) : Verdict()

        /**
         * No allocation record. NOT "common" -- the only honest reading is
         * that nobody had to draw for it.
         */
        data object NotAllocated : Verdict()

        val headline: String
            get() = when {
                this is Contested && ratio >= Rarity.extremelyContestedThreshold ->
                    "Extremely contested"
                this is Contested && ratio >= Rarity.contestedThreshold -> "Contested"
                this is Contested -> "Allocated, by lottery"
                this is Allocated -> "Allocated"
                else -> "Not allocated"
            }
    }

    data class Result(val verdict: Verdict, val allocation: Allocation?) {

        /** One line, and never a number without its source. */
        val summary: String
            get() {
                val found = allocation
                val answer = verdict
                return when {
                    answer is Verdict.Contested && found != null -> {
                        val entries = found.entries ?: 0
                        "${format(entries)} entries for ${format(found.bottles)} bottles " +
                            "— about ${answer.ratio.roundToInt()} people for every one."
                    }
                    answer is Verdict.Allocated && found != null ->
                        "${format(answer.bottles)} bottles allocated to ${found.source}."
                    answer is Verdict.NotAllocated ->
                        "No lottery or allocation on record. That is not the same as common."
                    else -> ""
                }
            }

        /**
         * Always shown beside the figure. Two states' allocations do not add
         * up to a national picture, and the research says so in as many
         * words.
         */
        val caveat: String
            get() {
                val found = allocation
                    ?: return "Allocation records cover only the scarcest bottles."
                val year = found.year?.let { " ($it)" } ?: ""
                return "From ${found.source}$year. One state's allocation, " +
                    "not a national figure."
            }

        /**
         * Grouped thousands. Locale.US rather than the phone's, because the
         * figure sits in an English sentence beside a named American state
         * board, and "44.696" would read as a decimal.
         */
        private fun format(number: Int): String = String.format(Locale.US, "%,d", number)
    }

    /**
     * Bands on the demand ratio. Deliberately coarse and deliberately few:
     * this is measured data with a small sample of releases behind it, and a
     * five-tier ladder would be precision the source does not have.
     */
    const val contestedThreshold = 10.0
    const val extremelyContestedThreshold = 50.0

    fun assess(allocation: Allocation?): Result {
        if (allocation == null) return Result(Verdict.NotAllocated, null)
        val ratio = allocation.demandRatio
        if (ratio != null) return Result(Verdict.Contested(ratio), allocation)
        return Result(Verdict.Allocated(allocation.bottles), allocation)
    }
}
