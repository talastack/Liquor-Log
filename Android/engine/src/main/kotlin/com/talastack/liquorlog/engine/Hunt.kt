package com.talastack.liquorlog.engine

import java.time.Instant

/**
 * The hunt: where you looked, what was on the shelf, and the lotteries you
 * put your name in.
 *
 * Half of collecting allocated whiskey happens before a bottle is bought:
 * the Tuesday you saw Blanton's at the Total Wine on Broadway at $74.99 with
 * three on the shelf, the state lottery you entered in March and heard
 * nothing back from. Nobody writes that down, so nobody knows which store
 * actually gets the good stuff or how their lottery luck runs. This keeps
 * the record and reads it back. Every figure is yours, from what you logged;
 * nothing here says where a bottle is now.
 */
object Hunt {

    enum class Kind(val storageKey: String, val label: String) {
        /** On a shelf, at a price, in some number. */
        SEEN("seen", "Seen on a shelf"),
        /** A lottery or raffle entered, with its outcome when known. */
        ENTERED("entered", "Entered a lottery"),
        ;

        companion object {
            fun fromStorageKey(key: String): Kind? = entries.firstOrNull { it.storageKey == key }
        }
    }

    enum class Outcome(val storageKey: String, val label: String) {
        WON("won", "Won"),
        LOST("lost", "Lost"),
        ;

        companion object {
            fun fromStorageKey(key: String): Outcome? = entries.firstOrNull { it.storageKey == key }
        }
    }

    /** One entry in the log, reduced to what the reading needs. */
    data class Sighting(
        val id: String,
        val productId: String?,
        val name: String,
        val store: String,
        val kind: Kind = Kind.SEEN,
        val outcome: Outcome? = null,
        val cents: Int? = null,
        val count: Int? = null,
        val at: Instant,
        /** Set once the bottle was bought and is on the shelf. */
        val boughtBottleId: String? = null,
    )

    /** One store, from what you logged there. */
    data class Store(
        /** Lowercased, trimmed: "Total Wine" and "total wine " are one store. */
        val key: String,
        /** The spelling you used most recently. */
        val name: String,
        /** Shelf sightings logged there. */
        val sightings: Int,
        /** Distinct products seen there. */
        val products: Int,
        /** Sightings of products on your wishlist. */
        val wishlistHits: Int,
        val lastAt: Instant,
    )

    data class Lotteries(val entered: Int, val won: Int, val lost: Int) {
        val pending: Int get() = entered - won - lost

        /** "4 entered · 1 won · 2 pending". Null with nothing entered. */
        val line: String?
            get() {
                if (entered <= 0) return null
                val parts = mutableListOf("$entered entered")
                if (won > 0) parts += "$won won"
                if (lost > 0) parts += "$lost lost"
                if (pending > 0) parts += "$pending pending"
                return parts.joinToString(" · ")
            }
    }

    data class Summary(
        val seen: Int,
        /** Ranked: most sightings first, then most recent. */
        val stores: List<Store>,
        val lotteries: Lotteries,
        /**
         * "31 sightings at 6 stores · 4 lotteries entered, 1 won". Null when
         * the log is empty.
         */
        val headline: String?,
    ) {
        companion object {
            val empty = Summary(
                seen = 0, stores = emptyList(),
                lotteries = Lotteries(entered = 0, won = 0, lost = 0), headline = null,
            )
        }
    }

    // MARK: - Reading the log

    fun summarise(sightings: List<Sighting>, wishlist: Set<String> = emptySet()): Summary {
        val seen = sightings.filter { it.kind == Kind.SEEN }
        val entered = sightings.filter { it.kind == Kind.ENTERED }
        val lotteries = Lotteries(
            entered = entered.size,
            won = entered.count { it.outcome == Outcome.WON },
            lost = entered.count { it.outcome == Outcome.LOST },
        )

        val stores = seen.groupBy { storeKey(it.store) }
            .map { (key, rows) ->
                val newest = rows.maxByOrNull { it.at }!!
                Store(
                    key = key,
                    name = newest.store.trim(),
                    sightings = rows.size,
                    products = rows.map { it.productId ?: it.name.lowercase() }.toSet().size,
                    wishlistHits = rows.count { it.productId != null && wishlist.contains(it.productId) },
                    lastAt = newest.at,
                )
            }
            .sortedWith(compareByDescending<Store> { it.sightings }.thenByDescending { it.lastAt })

        var headline: String? = null
        if (seen.isNotEmpty() || lotteries.entered > 0) {
            val parts = mutableListOf<String>()
            if (seen.isNotEmpty()) {
                parts += "${seen.size} ${if (seen.size == 1) "sighting" else "sightings"} at " +
                    "${stores.size} ${if (stores.size == 1) "store" else "stores"}"
            }
            if (lotteries.entered > 0) {
                var lot = "${lotteries.entered} " +
                    "${if (lotteries.entered == 1) "lottery" else "lotteries"} entered"
                if (lotteries.won > 0) lot += ", ${lotteries.won} won"
                parts += lot
            }
            headline = parts.joinToString(" · ")
        }
        return Summary(seen = seen.size, stores = stores, lotteries = lotteries, headline = headline)
    }

    /** The newest shelf sighting of a product. Null when it was never seen. */
    fun latest(productId: String, sightings: List<Sighting>): Sighting? =
        sightings.filter { it.kind == Kind.SEEN && it.productId == productId }
            .maxByOrNull { it.at }

    /**
     * Wishlist products seen on a shelf in the last [within] days, newest
     * sighting per product, newest first. What the list is for: knowing where
     * to go.
     */
    fun onYourList(
        sightings: List<Sighting>,
        wishlist: Set<String>,
        within: Int = 60,
        now: Instant = Instant.now(),
    ): List<Sighting> {
        val newest = mutableMapOf<String, Sighting>()
        for (s in sightings) {
            if (s.kind != Kind.SEEN || s.boughtBottleId != null) continue
            val id = s.productId ?: continue
            if (!wishlist.contains(id)) continue
            if (AgeMath.days(s.at, now) > within) continue
            val have = newest[id]
            if (have != null && have.at >= s.at) continue
            newest[id] = s
        }
        return newest.values.sortedByDescending { it.at }
    }

    // MARK: - Words

    /**
     * "At Total Wine 12 days ago · $74.99 · 3 on the shelf", or for a lottery
     * "Virginia ABC, 3 weeks ago · pending".
     */
    fun line(s: Sighting, now: Instant = Instant.now()): String {
        val when_ = ago(AgeMath.days(s.at, now))
        return when (s.kind) {
            Kind.SEEN -> {
                val parts = mutableListOf("At ${s.store.trim()} $when_")
                s.cents?.let { parts += Money.short(it) }
                s.count?.let { parts += if (it == 0) "sold out" else "$it on the shelf" }
                if (s.boughtBottleId != null) parts += "bought"
                parts.joinToString(" · ")
            }
            Kind.ENTERED -> {
                val status = s.outcome?.label?.lowercase() ?: "pending"
                "${s.store.trim()}, $when_ · $status"
            }
        }
    }

    /** "today", "yesterday", "12 days ago", "3 weeks ago", "4 months ago". */
    fun ago(days: Int): String = when {
        days < 1 -> "today"
        days == 1 -> "yesterday"
        days < 14 -> "$days days ago"
        days < 60 -> "${days / 7} weeks ago"
        days < 365 -> "${days / 30} months ago"
        days / 365 == 1 -> "a year ago"
        else -> "${days / 365} years ago"
    }

    fun storeKey(store: String): String = store.trim().lowercase()
}
