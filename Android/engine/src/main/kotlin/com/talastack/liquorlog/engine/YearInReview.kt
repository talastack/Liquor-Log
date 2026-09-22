package com.talastack.liquorlog.engine

import java.time.Instant
import java.time.LocalDate
import java.time.ZoneId
import java.time.format.DateTimeFormatter
import java.util.Locale
import kotlin.math.min

/**
 * A year of collecting, in a few sentences, from what was recorded.
 *
 * What came onto the shelf, from where, what it cost; what was tasted and
 * how it rated; the word reached for most; who sent samples; where the
 * hunting happened. Every figure counts bottles, tastings, words, people and
 * stores -- what was collected and written -- and none counts pours or
 * bottles emptied. A year is a calendar year; nothing is compared with the
 * year before, and nothing is a streak.
 */
object YearInReview {

    data class Added(
        val name: String,
        val classLabel: String? = null,
        val distillery: String? = null,
        val cents: Int? = null,
        val at: Instant,
    )

    data class Tasted(
        val name: String,
        val rating: Int? = null,
        val at: Instant,
        val words: List<String> = emptyList(),
    )

    data class Sample(val from: String, val at: Instant)
    data class Sighted(val store: String, val at: Instant)
    data class Lottery(val won: Boolean?, val at: Instant)

    data class Facts(
        val added: List<Added> = emptyList(),
        val opened: List<Instant> = emptyList(),
        val tastings: List<Tasted> = emptyList(),
        val samples: List<Sample> = emptyList(),
        val sightings: List<Sighted> = emptyList(),
        val lotteries: List<Lottery> = emptyList(),
    )

    data class Count(val name: String, val count: Int)

    data class Best(val name: String, val rating: Int)

    data class FirstBottle(val name: String, val at: Instant)

    data class Review(
        val year: Int,
        val bottlesAdded: Int,
        val distilleries: Int,
        val topDistillery: Count?,
        val topClass: Count?,
        /**
         * What the added bottles with a price cost, together. Shown only
         * behind the money switch; the sentence for it is separate.
         */
        val spentCents: Int?,
        val pricedBottles: Int,
        val firstBottle: FirstBottle?,
        val opened: Int,
        val tastings: Int,
        val best: Best?,
        val wordOfTheYear: Count?,
        val samples: Int,
        val sampleSenders: List<String>,
        val sightings: Int,
        val stores: Int,
        val topStore: Count?,
        val lotteriesEntered: Int,
        val lotteriesWon: Int,
        /** The review as sentences, money left out. */
        val lines: List<String>,
        /** "$1,240.00 across the 11 with a price." Null without one. */
        val moneyLine: String?,
    )

    /** The years with anything recorded, newest first. */
    fun years(f: Facts, zone: ZoneId = ZoneId.systemDefault()): List<Int> {
        val dates = f.added.map { it.at } + f.opened + f.tastings.map { it.at } +
            f.samples.map { it.at } + f.sightings.map { it.at } + f.lotteries.map { it.at }
        return dates.map { yearOf(it, zone) }.toSortedSet().reversed()
    }

    /** Null when nothing at all was recorded in the year. */
    fun review(
        f: Facts,
        year: Int,
        words: (String) -> String = { it },
        zone: ZoneId = ZoneId.systemDefault(),
    ): Review? {
        fun inYear(d: Instant) = yearOf(d, zone) == year

        val added = f.added.filter { inYear(it.at) }.sortedBy { it.at }
        val opened = f.opened.count { inYear(it) }
        val tastings = f.tastings.filter { inYear(it.at) }
        val samples = f.samples.filter { inYear(it.at) }
        val sightings = f.sightings.filter { inYear(it.at) }
        val lotteries = f.lotteries.filter { inYear(it.at) }

        if (added.isEmpty() && opened == 0 && tastings.isEmpty() &&
            samples.isEmpty() && sightings.isEmpty() && lotteries.isEmpty()
        ) {
            return null
        }

        val distilleries = counts(added.mapNotNull { it.distillery })
        val classes = counts(added.mapNotNull { it.classLabel })
        val priced = added.mapNotNull { it.cents }
        val best = tastings.mapNotNull { t -> t.rating?.let { Best(t.name, it) } }
            .maxByOrNull { it.rating }
        // Counted once per tasting, so a wheel picked heavily on one night
        // does not name the year.
        val wordCounts = counts(tastings.flatMap { it.words.toSet() })
        val senders = orderedDistinct(samples.sortedByDescending { it.at }.map { it.from })
        val stores = counts(sightings.map { it.store.trim() })
        val won = lotteries.count { it.won == true }

        val lines = mutableListOf<String>()
        if (added.isNotEmpty()) {
            var line = "${added.size} ${if (added.size == 1) "bottle" else "bottles"} added"
            if (distilleries.size > 1) line += ", from ${distilleries.size} distilleries"
            distilleries.firstOrNull()?.let {
                if (it.count > 1) line += ". ${it.name} most, ${it.count} times"
            }
            lines += "$line."

            val topClass = classes.firstOrNull()
            if (topClass != null && classes.size > 1 && topClass.count > 1) {
                lines += "Mostly ${topClass.name.lowercase()}: ${topClass.count} of them."
            }
            added.firstOrNull()?.let {
                lines += "First of the year: ${it.name}, ${dayAndMonth(it.at, zone)}."
            }
        }
        // Bottles opened is counted, for the screen's own use, but not said:
        // on a card that gets shared it reads as a tally of drinking, and
        // that is the one thing this must never be.
        if (tastings.isNotEmpty()) {
            var line = "${tastings.size} ${if (tastings.size == 1) "tasting" else "tastings"} written"
            if (best != null) line += ". Highest: ${best.name}, ${best.rating}/10"
            lines += "$line."
            wordCounts.firstOrNull()?.let {
                if (it.count >= 2) {
                    lines += "The word you reached for most: ${words(it.name)}, ${it.count} times."
                }
            }
        }
        if (samples.isNotEmpty()) {
            val named = senders.take(3).joinToString(", ")
            val more = senders.size - min(senders.size, 3)
            val tail = if (more > 0) " and $more more" else ""
            lines += "${samples.size} ${if (samples.size == 1) "sample" else "samples"} from $named$tail."
        }
        if (sightings.isNotEmpty()) {
            var line = "${sightings.size} ${if (sightings.size == 1) "sighting" else "sightings"} at " +
                "${stores.size} ${if (stores.size == 1) "store" else "stores"}"
            stores.firstOrNull()?.let {
                if (stores.size > 1 && it.count > 1) line += "; ${it.name} most"
            }
            lines += "$line."
        }
        if (lotteries.isNotEmpty()) {
            val wonTail = if (won > 0) ", $won won" else ""
            lines += "${lotteries.size} " +
                "${if (lotteries.size == 1) "lottery" else "lotteries"} entered$wonTail."
        }

        val spent = if (priced.isEmpty()) null else priced.sum()
        val moneyLine = spent?.let { total ->
            if (priced.size == added.size) {
                "${Money.short(total)} across them."
            } else {
                "${Money.short(total)} across the ${priced.size} with a price."
            }
        }

        return Review(
            year = year,
            bottlesAdded = added.size,
            distilleries = distilleries.size,
            topDistillery = distilleries.firstOrNull(),
            topClass = classes.firstOrNull(),
            spentCents = spent,
            pricedBottles = priced.size,
            firstBottle = added.firstOrNull()?.let { FirstBottle(it.name, it.at) },
            opened = opened,
            tastings = tastings.size,
            best = best,
            wordOfTheYear = wordCounts.firstOrNull()?.let { Count(words(it.name), it.count) },
            samples = samples.size,
            sampleSenders = senders,
            sightings = sightings.size,
            stores = stores.size,
            topStore = stores.firstOrNull(),
            lotteriesEntered = lotteries.size,
            lotteriesWon = won,
            lines = lines,
            moneyLine = moneyLine,
        )
    }

    // MARK: - Pieces

    /** Most first; ties by name, so the answer is the same every time. */
    internal fun counts(names: List<String>): List<Count> =
        names.filter { it.isNotEmpty() }
            .groupingBy { it }.eachCount()
            .map { (name, count) -> Count(name, count) }
            .sortedWith(compareByDescending<Count> { it.count }.thenBy { it.name })

    internal fun orderedDistinct(names: List<String>): List<String> {
        val seen = mutableSetOf<String>()
        return names.mapNotNull { name ->
            val key = name.trim().lowercase()
            if (key.isEmpty() || !seen.add(key)) null else name.trim()
        }
    }

    private fun yearOf(instant: Instant, zone: ZoneId): Int =
        LocalDate.ofInstant(instant, zone).year

    private fun dayAndMonth(date: Instant, zone: ZoneId): String =
        DateTimeFormatter.ofPattern("d MMMM", Locale.US).withZone(zone).format(date)
}
