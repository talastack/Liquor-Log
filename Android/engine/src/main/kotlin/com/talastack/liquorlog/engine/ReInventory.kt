package com.talastack.liquorlog.engine

import java.time.Instant

/**
 * The annual shelf walk.
 *
 * Every long-running collection system decays. People say so plainly: *"I
 * used Only Drams but I drink/buy/trade too often to keep it current"*,
 * *"According to only drams, I'm sitting on 307 bottles with 120 open."* The
 * coping mechanism people arrive at independently is a periodic bulk
 * re-inventory, one to three times a year. Almost no app has one.
 *
 * The design constraint that makes or breaks it: **you are walking past
 * physical shelves, not scrolling a list.** So the queue is ordered by where
 * a bottle is first and how stale the record is second. A list that sends you
 * from the closet to the basement and back is a list nobody finishes.
 */
object ReInventory {

    /** One bottle to lay eyes on. */
    data class Item(
        val id: String,
        val name: String,
        /** Free text, as people actually write it: "hall closet", "bar top". */
        val storageLocation: String? = null,
        /** Null means it has never been confirmed since it was added. */
        val lastVerifiedAt: Instant? = null,
        val isOpen: Boolean = false
    )

    /**
     * What you found when you looked.
     *
     * [GONE] is deliberately not called "deleted". A bottle you finished and
     * forgot to log is killed and archived, never removed -- the same rule
     * the rest of the app follows.
     */
    enum class Verdict(val storageKey: String) {
        PRESENT("present"),
        GONE("gone"),
        SKIPPED("skipped")
    }

    /** Bottles that share a location, in one pass. */
    data class Leg(
        /** Null for everything with no location recorded. */
        val location: String?,
        val items: List<Item>
    ) {
        val id: String get() = location ?: "\u0000unplaced"

        /** What to call this leg on screen. */
        val title: String get() = location ?: "No location recorded"
    }

    /** One decision made during the walk. */
    data class Decision(val id: String, val verdict: Verdict)

    /**
     * The walk, grouped by location and ordered so the stalest shelf comes
     * first.
     *
     * Within a leg the stalest bottle leads, so an interrupted walk still
     * leaves the collection better than it found it. Bottles with no location
     * always come last: they are the ones you have to hunt for, and putting
     * them first is how a walk stalls on its first entry.
     */
    fun plan(items: List<Item>, now: Instant = Instant.now()): List<Leg> {
        val grouped = items.groupBy { it.storageLocation }

        val legs = grouped.map { (location, members) ->
            Leg(
                location = location,
                items = members.sortedWith(Comparator { a, b ->
                    val left = staleness(a, now)
                    val right = staleness(b, now)
                    if (left != right) {
                        if (left > right) -1 else 1
                    } else {
                        String.CASE_INSENSITIVE_ORDER.compare(a.name, b.name)
                    }
                })
            )
        }

        return legs.sortedWith(Comparator { left, right ->
            // Unplaced bottles last, whatever their staleness.
            val leftUnplaced = left.location == null
            val rightUnplaced = right.location == null
            if (leftUnplaced != rightUnplaced) {
                if (rightUnplaced) -1 else 1
            } else {
                val leftStale = left.items.maxOfOrNull { staleness(it, now) } ?: 0.0
                val rightStale = right.items.maxOfOrNull { staleness(it, now) } ?: 0.0
                if (leftStale != rightStale) {
                    if (leftStale > rightStale) -1 else 1
                } else {
                    String.CASE_INSENSITIVE_ORDER
                        .compare(left.location ?: "", right.location ?: "")
                }
            }
        })
    }

    /**
     * Days since a bottle was last confirmed by eye.
     *
     * Never confirmed sorts above everything, because a bottle nobody has
     * ever looked at is the least trustworthy row in the collection.
     */
    fun staleness(item: Item, now: Instant = Instant.now()): Double {
        val last = item.lastVerifiedAt ?: return Double.MAX_VALUE
        return maxOf(0.0, (now.toEpochMilli() - last.toEpochMilli()) / 86_400_000.0)
    }

    /**
     * Whether a walk is worth suggesting at all.
     *
     * People do this one to three times a year, so nagging sooner trains them
     * to ignore it. Six months is the low end of the stated range.
     */
    const val suggestAfterDays = 182.0

    /**
     * True when the oldest confirmation is old enough to be worth a prompt.
     * An empty collection never prompts.
     */
    fun isDue(items: List<Item>, now: Instant = Instant.now()): Boolean {
        if (items.isEmpty()) return false
        return items.any { staleness(it, now) >= suggestAfterDays }
    }

    /** What a finished (or abandoned) walk did. */
    data class Outcome(
        val confirmed: List<String>,
        val gone: List<String>,
        val skipped: List<String>
    ) {
        val checkedCount: Int get() = confirmed.size + gone.size
        val isEmpty: Boolean get() = confirmed.isEmpty() && gone.isEmpty() && skipped.isEmpty()

        /**
         * Plain words, no celebration. Marking bottles finished is
         * bookkeeping, not an achievement -- nothing in this app treats
         * drinking more as progress.
         */
        val summary: String
            get() {
                if (isEmpty) return "Nothing checked."
                val parts = mutableListOf<String>()
                if (confirmed.isNotEmpty()) parts.add("${confirmed.size} still on the shelf")
                if (gone.isNotEmpty()) parts.add("${gone.size} marked finished")
                if (skipped.isNotEmpty()) parts.add("${skipped.size} skipped for now")
                return parts.joinToString(", ") + "."
            }
    }

    /** Folds a set of decisions into an outcome, in the order they were made. */
    fun outcome(decisions: List<Decision>): Outcome {
        val confirmed = mutableListOf<String>()
        val gone = mutableListOf<String>()
        val skipped = mutableListOf<String>()
        // Last decision on a bottle wins: people change their mind mid-shelf.
        val latest = LinkedHashMap<String, Verdict>()
        for (decision in decisions) latest[decision.id] = decision.verdict
        for ((id, verdict) in latest) {
            when (verdict) {
                Verdict.PRESENT -> confirmed.add(id)
                Verdict.GONE -> gone.add(id)
                Verdict.SKIPPED -> skipped.add(id)
            }
        }
        return Outcome(confirmed = confirmed, gone = gone, skipped = skipped)
    }
}
