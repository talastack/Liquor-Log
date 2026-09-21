package com.talastack.liquorlog.engine

import java.time.Instant

/**
 * Finding one bottle in a collection that has outgrown a scroll.
 *
 * The research puts the point where somebody needs this app at about fifty
 * bottles -- below that they use their eyes -- and the bulk-onboarding paths
 * exist to get a shelf of two hundred in. A flat list is unusable at that
 * size, so the collection screen gets the same three things the shop does:
 * type a few letters, narrow by what the bottle is, and choose an order.
 *
 * Pure and I/O-free. The screen turns its rows into [Row]s once and hands
 * them here on every keystroke, so this has to be cheap, and it is: one pass
 * over the rows, then a sort.
 */
object CollectionFilter {

    /**
     * A bottle as the filter sees it. Flattened on purpose: the screen knows
     * how to resolve names and products, the filter only compares.
     */
    data class Row(
        val id: String,
        val name: String,
        val distillery: String? = null,
        /**
         * Anything else worth typing to find the bottle: release label,
         * barrel and batch numbers, the store, where it is kept.
         */
        val extraSearchText: List<String> = emptyList(),
        val classType: ClassType? = null,
        val productionType: ProductionType = ProductionType.UNSPECIFIED,
        val isBarrelProof: Boolean = false,
        val isBottledInBond: Boolean = false,
        val isStorePick: Boolean = false,
        val isOpen: Boolean = false,
        val isFinished: Boolean = false,
        val isSample: Boolean = false,
        val isInfinity: Boolean = false,
        val storageLocation: String? = null,
        val addedAt: Instant,
        val lastPouredAt: Instant? = null,
        val rating: Int? = null,
        /** 0..1. What is left, so "fullest" and "nearly gone" can sort. */
        val fillFraction: Double = 1.0
    ) {
        /** Every token somebody might type to find this bottle. */
        internal val searchTokens: List<String>
            get() = (listOf(name, distillery ?: "", storageLocation ?: "") + extraSearchText)
                .flatMap { it.matchTokens }
    }

    /**
     * [ON_SHELF] is the default: what you own now. Finished bottles are
     * archived history and only appear when asked for.
     */
    enum class Status(val storageKey: String) {
        ON_SHELF("onShelf"),
        OPEN("open"),
        UNOPENED("unopened"),
        FINISHED("finished"),
        ANY("any");

        val label: String
            get() = when (this) {
                ON_SHELF -> "On the shelf"
                ANY -> "Everything"
                OPEN -> "Open"
                UNOPENED -> "Unopened"
                FINISHED -> "Finished"
            }
    }

    /**
     * What the bottle IS. Class and production are separate facts in the data
     * model and they stay separate here: "single barrel" and "Kentucky
     * Straight" are different questions, and somebody can ask both at once.
     */
    enum class Kind(val storageKey: String) {
        STORE_PICK("storePick"),
        SINGLE_BARREL("singleBarrel"),
        SMALL_BATCH("smallBatch"),
        BARREL_PROOF("barrelProof"),
        BOTTLED_IN_BOND("bottledInBond"),
        BOURBON("bourbon"),
        RYE("rye"),
        WHEAT_WHISKEY("wheatWhiskey"),
        SCOTCH("scotch"),
        NOT_WHISKEY("notWhiskey"),
        SAMPLE("sample"),
        INFINITY("infinity");

        val label: String
            get() = when (this) {
                STORE_PICK -> "Store pick"
                SINGLE_BARREL -> "Single barrel"
                SMALL_BATCH -> "Small batch"
                BARREL_PROOF -> "Barrel proof"
                BOTTLED_IN_BOND -> "Bottled in bond"
                BOURBON -> "Bourbon"
                RYE -> "Rye"
                WHEAT_WHISKEY -> "Wheat whiskey"
                SCOTCH -> "Scotch"
                NOT_WHISKEY -> "Not whiskey"
                SAMPLE -> "Samples"
                INFINITY -> "Infinity bottles"
            }

        internal fun matches(row: Row): Boolean = when (this) {
            STORE_PICK -> row.isStorePick
            SINGLE_BARREL ->
                row.productionType == ProductionType.SINGLE_BARREL ||
                    row.productionType == ProductionType.SINGLE_CASK
            SMALL_BATCH -> row.productionType == ProductionType.SMALL_BATCH
            BARREL_PROOF -> row.isBarrelProof
            BOTTLED_IN_BOND -> row.isBottledInBond
            BOURBON -> when (row.classType) {
                ClassType.BOURBON,
                ClassType.STRAIGHT_BOURBON,
                ClassType.KENTUCKY_STRAIGHT_BOURBON,
                ClassType.BLEND_OF_STRAIGHT_BOURBON -> true
                else -> false
            }
            RYE -> row.classType == ClassType.RYE || row.classType == ClassType.STRAIGHT_RYE
            WHEAT_WHISKEY ->
                row.classType == ClassType.WHEAT_WHISKEY ||
                    row.classType == ClassType.STRAIGHT_WHEAT_WHISKEY
            SCOTCH -> when (row.classType) {
                ClassType.SINGLE_MALT_SCOTCH,
                ClassType.BLENDED_MALT_SCOTCH,
                ClassType.SINGLE_GRAIN_SCOTCH,
                ClassType.BLENDED_SCOTCH -> true
                else -> false
            }
            NOT_WHISKEY -> {
                val type = row.classType
                if (type == null) false else type.family != ClassType.Family.WHISKEY
            }
            SAMPLE -> row.isSample
            INFINITY -> row.isInfinity
        }
    }

    enum class Sort(val storageKey: String) {
        NEWEST("newest"),
        NAME("name"),
        DISTILLERY("distillery"),
        FULLEST("fullest"),
        NEARLY_GONE("nearlyGone"),
        LAST_POURED("lastPoured"),
        RATING("rating");

        val label: String
            get() = when (this) {
                NEWEST -> "Newest"
                NAME -> "Name"
                DISTILLERY -> "Distillery"
                FULLEST -> "Fullest"
                NEARLY_GONE -> "Nearly gone"
                LAST_POURED -> "Last poured"
                RATING -> "Rating"
            }
    }

    data class Criteria(
        val query: String = "",
        val status: Status = Status.ON_SHELF,
        /**
         * Every selected kind must match -- "store pick" AND "barrel proof"
         * narrows, it does not widen.
         */
        val kinds: Set<Kind> = emptySet(),
        val location: String? = null,
        val sort: Sort = Sort.NEWEST
    ) {
        /**
         * True when anything narrows the list. The screen uses it to show a
         * "clear" control only when there is something to clear.
         */
        val isNarrowing: Boolean
            get() = query.trim { it.isWhitespace() && it != '\n' && it != '\r' }.isNotEmpty() ||
                status != Status.ON_SHELF ||
                kinds.isNotEmpty() ||
                location != null

        companion object {
            val none = Criteria()
        }
    }

    // MARK: - Applying

    fun apply(criteria: Criteria, rows: List<Row>): List<Row> {
        val queryTokens = criteria.query.matchTokens
        val matching = rows.filter { row ->
            matchesStatus(criteria.status, row) &&
                criteria.kinds.all { it.matches(row) } &&
                matchesLocation(criteria.location, row) &&
                matchesQuery(queryTokens, row)
        }
        return sorted(matching, criteria.sort)
    }

    /**
     * The distinct places bottles are kept, most-used first, for the location
     * chips. Empty when nobody has recorded a location.
     */
    fun locations(rows: List<Row>): List<String> {
        val counts = LinkedHashMap<String, Int>()
        for (row in rows) {
            val location = row.storageLocation?.trim { it.isWhitespace() && it != '\n' && it != '\r' }
            if (location.isNullOrEmpty()) continue
            counts[location] = (counts[location] ?: 0) + 1
        }
        return counts.entries
            .sortedWith(compareByDescending<Map.Entry<String, Int>> { it.value }.thenBy { it.key })
            .map { it.key }
    }

    /**
     * Only the kinds at least one row would match. A chip that can never
     * narrow anything is noise on a screen that exists to narrow.
     */
    fun availableKinds(rows: List<Row>): List<Kind> =
        Kind.entries.filter { kind -> rows.any { kind.matches(it) } }

    private fun matchesStatus(status: Status, row: Row): Boolean = when (status) {
        Status.ON_SHELF -> !row.isFinished
        Status.ANY -> true
        Status.OPEN -> row.isOpen && !row.isFinished
        Status.UNOPENED -> !row.isOpen && !row.isFinished
        Status.FINISHED -> row.isFinished
    }

    private fun matchesLocation(location: String?, row: Row): Boolean {
        if (location == null) return true
        return row.storageLocation?.equals(location, ignoreCase = true) == true
    }

    /**
     * Every query token prefixes some token of the row, the same rule the
     * shop search uses, so "eli bar" finds Elijah Craig Barrel Proof here as
     * well as there.
     */
    private fun matchesQuery(queryTokens: List<String>, row: Row): Boolean {
        if (queryTokens.isEmpty()) return true
        val haystack = row.searchTokens
        return queryTokens.all { token -> haystack.any { it.startsWith(token) } }
    }

    private fun sorted(rows: List<Row>, sort: Sort): List<Row> = when (sort) {
        Sort.NEWEST -> rows.sortedByDescending { it.addedAt }

        Sort.NAME -> rows.sortedWith(compareBy(String.CASE_INSENSITIVE_ORDER) { it.name })

        Sort.DISTILLERY -> rows.sortedWith(
            compareBy(String.CASE_INSENSITIVE_ORDER) { it.distillery ?: it.name }
                .thenBy(String.CASE_INSENSITIVE_ORDER) { it.name }
        )

        Sort.FULLEST -> rows.sortedByDescending { it.fillFraction }

        // Finished bottles are not "nearly gone", they are gone; they go last
        // so the top of the list is bottles still worth pouring.
        Sort.NEARLY_GONE -> rows.sortedWith(
            compareBy<Row> { it.isFinished }.thenBy { it.fillFraction }
        )

        // Most recently poured first; never poured last.
        Sort.LAST_POURED -> rows.sortedWith(
            Comparator { a, b ->
                val x = a.lastPouredAt
                val y = b.lastPouredAt
                when {
                    x != null && y != null -> y.compareTo(x)
                    x != null -> -1
                    y != null -> 1
                    else -> b.addedAt.compareTo(a.addedAt)
                }
            }
        )

        // Highest first; unrated last.
        Sort.RATING -> rows.sortedWith(
            Comparator { a, b ->
                val x = a.rating
                val y = b.rating
                when {
                    x != null && y != null ->
                        if (x == y) b.addedAt.compareTo(a.addedAt) else y.compareTo(x)
                    x != null -> -1
                    y != null -> 1
                    else -> b.addedAt.compareTo(a.addedAt)
                }
            }
        )
    }
}
