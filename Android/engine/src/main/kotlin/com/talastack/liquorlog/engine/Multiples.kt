package com.talastack.liquorlog.engine

/**
 * Bottles that are the same thing: three of one store pick, two backups of
 * a standard release.
 *
 * Picks are bought in multiples -- a group that selects a barrel takes a
 * case -- and every bottle is still its own record with its own fill and its
 * own open date, which is the whole model. What the screen needs is to know
 * that these three cards are one thing, so it can say "1 of 3" on each and
 * list the others on the bottle.
 *
 * Two bottles are the same thing when they are the same product AND the same
 * barrel AND the same batch. Two bottles of Elijah Craig Barrel Proof from
 * different batches are not multiples; they are different whiskeys with one
 * name, which is the point of tracking batches at all.
 */
object Multiples {

    data class Bottle(
        val id: String,
        /** The product, or for a typed-in bottle its custom entry id or name. */
        val productKey: String,
        val barrel: String? = null,
        val batch: String? = null,
        val isFinished: Boolean = false,
    ) {
        internal val groupKey: String
            get() = listOf(productKey, barrel ?: "", batch ?: "")
                .joinToString("|") { it.normalizedForMatching() }
    }

    /**
     * One bottle's place among its multiples. [count] is the bottles still
     * on the shelf, [position] this bottle's 1-based place among them in the
     * order given, and [siblings] the other on-shelf ids.
     */
    data class Place(
        val count: Int,
        val position: Int,
        val siblings: List<String>,
    ) {
        val isOneOfSeveral: Boolean get() = count > 1

        /** "1 of 3", or null when there is only the one. */
        val label: String? get() = if (isOneOfSeveral) "$position of $count" else null
    }

    /**
     * Places for every on-shelf bottle. Finished bottles neither count nor
     * get a place: a killed bottle is history, and "1 of 3" on a shelf with
     * one bottle and two empties is wrong in the way that matters.
     */
    fun places(bottles: List<Bottle>): Map<String, Place> {
        // LinkedHashMap, so the grouping keeps the order it was given and the
        // positions are stable between runs.
        val groups = LinkedHashMap<String, MutableList<Bottle>>()
        for (bottle in bottles.filter { !it.isFinished }) {
            groups.getOrPut(bottle.groupKey) { mutableListOf() }.add(bottle)
        }

        val places = mutableMapOf<String, Place>()
        for (members in groups.values) {
            members.forEachIndexed { index, bottle ->
                places[bottle.id] = Place(
                    count = members.size,
                    position = index + 1,
                    siblings = members.filter { it.id != bottle.id }.map { it.id },
                )
            }
        }
        return places
    }
}
