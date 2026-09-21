package com.talastack.liquorlog.engine

import java.time.Instant
import kotlin.random.Random

/**
 * Choose something to drink tonight.
 *
 * A trivial feature that people mention unprompted as a reason they like an
 * app. It works because the problem is real: a shelf of forty open bottles is
 * a decision, and most nights you reach for the same three.
 *
 * It leans toward bottles you have not poured from in a while -- one of the
 * stated uses is *"to push myself to dig out a bottle that I really liked but
 * haven't poured from in a long time."* Neglect is the signal, not novelty.
 */
object PickMyPour {

    /** The minimum a bottle needs for this to consider it. */
    data class Candidate(
        val id: String,
        val name: String,
        /** Null means never poured, which is the strongest pull of all. */
        val lastPouredAt: Instant?,
        val isOpen: Boolean,
        val remainingMilliliters: Double
    )

    data class Choice(
        val candidate: Candidate,
        /**
         * Why this one, in plain words. A random pick with no reason feels
         * arbitrary; a reason makes it feel like a suggestion.
         */
        val reason: String
    )

    /**
     * Bottles eligible to be poured from: open, and with something in them.
     *
     * A sealed bottle is deliberately excluded. Opening one is a decision the
     * app should not make for somebody -- it starts an oxidation clock and it
     * is often the whole point of the bottle.
     */
    fun eligible(candidates: List<Candidate>): List<Candidate> =
        candidates.filter { it.isOpen && it.remainingMilliliters > 0 }

    /**
     * Picks one, weighted toward neglect.
     *
     * [random] is injected so a test can pin the outcome. Callers pass
     * `Random.Default`.
     */
    fun choose(
        candidates: List<Candidate>,
        now: Instant = Instant.now(),
        random: Random = Random.Default
    ): Choice? {
        val pool = eligible(candidates)
        if (pool.isEmpty()) return null

        val weighted = pool.map { it to weight(it, now) }
        val total = weighted.sumOf { it.second }
        if (total <= 0) {
            val any = pool.random(random)
            return Choice(any, reason(any, now))
        }

        var roll = random.nextDouble(total)
        for ((candidate, weight) in weighted) {
            roll -= weight
            if (roll < 0) return Choice(candidate, reason(candidate, now))
        }
        val last = weighted[weighted.size - 1].first
        return Choice(last, reason(last, now))
    }

    /**
     * Days since the last pour, capped. A bottle untouched for two years is
     * not meaningfully more neglected than one untouched for one, and without
     * a cap a single forgotten bottle would win every time and stop being a
     * surprise.
     */
    const val neglectCapDays = 365.0

    internal fun weight(candidate: Candidate, now: Instant): Double {
        // Never poured. Deliberately the strongest pull: an open bottle you
        // have not tasted is the one most worth being reminded of.
        val last = candidate.lastPouredAt ?: return neglectCapDays
        val days = daysBetween(last, now)
        // Everything keeps a floor of 1 so a bottle poured yesterday can still
        // come up. A suggestion that never surprises stops being used.
        return maxOf(1.0, minOf(neglectCapDays, days))
    }

    internal fun reason(candidate: Candidate, now: Instant): String {
        val last = candidate.lastPouredAt
            ?: return "Open, and you have not poured from it yet."
        val days = daysBetween(last, now).toInt()
        return when {
            days < 7 -> "You had this recently. Still good."
            days < 30 -> "Not for a couple of weeks."
            days < 120 -> "It has been a couple of months."
            days < 365 -> "You have not touched this in months."
            else -> "Over a year since your last pour."
        }
    }

    private fun daysBetween(from: Instant, to: Instant): Double =
        (to.toEpochMilli() - from.toEpochMilli()) / 86_400_000.0
}
