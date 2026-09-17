package com.talastack.liquorlog.engine

import kotlin.math.max

/**
 * Whether a pour that leaves a bottle nearly empty should offer to put it on
 * the wishlist.
 *
 * This closes the loop between the two lists. The research's complaint about
 * every inventory app is drift -- *"I forget to add a bottle sometimes and
 * forget to delete one sometimes when it's finished"* -- and the moment a
 * bottle is about to go is the one moment somebody knows whether they want
 * another. Asking then, once, beats a wishlist they have to remember to
 * maintain.
 *
 * **Once.** The offer fires only on the pour that crosses the line, never on
 * every pour after it, and never at all when the person already said they
 * would not buy it again. An app that nags on every pour of a dying bottle
 * is an app that gets its notifications turned off.
 */
object Replenish {

    /**
     * Pours left at which a bottle counts as nearly gone. Two, because one
     * is the last pour and the question needs asking before that.
     */
    const val LAST_POURS_THRESHOLD = 2

    data class Offer(
        val remainingPours: Int,
        /**
         * The sentence to ask with. Mentions what the person said last time
         * when they said anything.
         */
        val text: String,
    )

    /** Null means do not ask. */
    fun offer(
        remainingBefore: Int,
        remainingAfter: Int,
        isOnWishlist: Boolean,
        wouldRebuy: Boolean?,
    ): Offer? {
        // Only the crossing pour. Before was above the line, after is at or
        // below it. A bottle set to two pours by a fill reading and then
        // poured from is "after: 1, before: 2" -- still not a crossing, and
        // still not asked, because the reading was the moment it became
        // nearly gone and nobody was pouring then.
        if (remainingBefore <= LAST_POURS_THRESHOLD) return null
        if (remainingAfter > LAST_POURS_THRESHOLD) return null
        if (isOnWishlist) return null
        if (wouldRebuy == false) return null

        val left = when {
            remainingAfter < 1 -> "That was the last pour."
            remainingAfter == 1 -> "About one pour left."
            else -> "About $remainingAfter pours left."
        }
        val said = if (wouldRebuy == true) " You said you would buy it again." else ""
        return Offer(remainingPours = max(0, remainingAfter), text = left + said)
    }
}
