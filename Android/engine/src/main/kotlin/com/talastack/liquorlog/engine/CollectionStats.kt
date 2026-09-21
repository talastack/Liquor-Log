package com.talastack.liquorlog.engine

import java.time.Instant
import java.time.LocalDate
import java.time.ZoneId
import java.util.Locale
import kotlin.math.roundToInt

/**
 * What the collection looks like, in one screen.
 *
 * The research is blunt about why this exists: OnlyDrams' growth loop is a
 * **shareable stats screenshot**. Post titles tell the story -- *"My OnlyDrams
 * Post (10 years of collecting)"*, *"Can some one do the OnlyDrams thing for
 * me?"* -- and the pie chart is the marketing asset. *"Build something
 * screenshot-worthy."*
 *
 * **Everything here counts the COLLECTION, never the drinking.** Bottles
 * owned, classes represented, distilleries, the oldest thing on the shelf.
 * Nothing counts pours, nothing is a streak, nothing goes up when you drink
 * more, and there is no total that rewards volume.
 *
 * That is not only Apple guideline 1.4.3, which rejects apps encouraging
 * excessive consumption. It is also what the research found people actually
 * like: an app pitched on *"collection progress and competition"* posted three
 * times to r/bourbon and scored 1, 1, 1. What generates unprompted delight is
 * a bottle's own properties, not a scoreboard.
 */
object CollectionStats {

    /** One bottle, reduced to what a summary needs. */
    data class Entry(
        val name: String? = null,
        val classType: ClassType? = null,
        val distillery: String? = null,
        val brand: String? = null,
        val abv: Double? = null,
        val isOpen: Boolean = false,
        val isFinished: Boolean = false,
        /**
         * A sample rather than a bottle. Counted on its own line and kept out
         * of the bottle counts and breakdowns: fifty millilitres from a friend
         * is not a bottle of Weller on the shelf.
         */
        val isSample: Boolean = false,
        /** A store pick, single barrel or anything else with barrel detail. */
        val isPick: Boolean = false,
        val addedAt: Instant = Instant.now(),
        val openedAt: Instant? = null,
        val ageMonths: Int? = null,
        val storageLocation: String? = null,
        val purchasePriceCents: Int? = null,
        val purchasedAt: Instant? = null,
        val costPerPourCents: Int? = null,
        /** The Blanton's stopper letter, when the bottle has one. */
        val topperLetter: String? = null
    )

    /**
     * Money for one label -- a year, usually. Kept apart from [Slice] because
     * cents are not a count and a chart must not treat them as one.
     */
    data class Amount(val label: String, val cents: Int) {
        val id: String get() = label
    }

    /** One named bottle and a number about it, for the notable rows. */
    data class Standout(val name: String, val value: Int)

    /** A slice of the collection, for a chart or a list. */
    data class Slice(val label: String, val count: Int) {
        val id: String get() = label

        fun share(of: Int): Double = if (of > 0) count.toDouble() / of.toDouble() else 0.0
    }

    data class Summary(
        /**
         * On the shelf. Finished bottles are counted separately and never
         * folded in: a collection is what you have, not what you have had.
         */
        val onShelf: Int,
        val open: Int,
        val sealed: Int,
        /**
         * Archived, not deleted. Reported as a plain number with no
         * celebration attached.
         */
        val finished: Int,
        /** Samples on hand, not finished. Never folded into [onShelf]. */
        val samples: Int,
        val byClass: List<Slice>,
        val byDistillery: List<Slice>,
        val byStrength: List<Slice>,
        /** Brands, so "how much Weller do I have" is one line. */
        val byBrand: List<Slice>,
        /** Where bottles are kept. Empty until somebody records a place. */
        val byPlace: List<Slice>,
        /**
         * Bottles added per calendar year, oldest year first. Growth of the
         * COLLECTION, never a count of anything drunk.
         */
        val addedByYear: List<Slice>,
        val distilleryCount: Int,
        val classCount: Int,
        /**
         * Store picks and single barrels on the shelf -- the bottles this app
         * exists for.
         */
        val picks: Int,
        /**
         * The strongest thing on the shelf, as a property of a bottle rather
         * than an achievement.
         */
        val highestProof: Double?,
        val oldestStatedAgeMonths: Int?,
        /**
         * The open bottle that has been open longest, in days. A fact about
         * oxidation, not a prompt to finish it.
         */
        val longestOpen: Standout?,
        /**
         * Which Blanton's stopper letters are on the shelf. Null until there
         * is at least one, so a shelf with no Blanton's never sees the word.
         */
        val topperLetters: TopperLetters.Progress?,
        /**
         * Spend per calendar year of purchase, oldest first. Bottles with a
         * price but no purchase date are left out rather than guessed.
         */
        val spentByYear: List<Amount>,
        /** Mean cost of a pour across the priced bottles on the shelf. */
        val averageCostPerPourCents: Int?,
        /** The most and least expensive pours on the shelf. */
        val dearestPour: Standout?,
        val cheapestPour: Standout?
    ) {
        val isEmpty: Boolean get() = onShelf == 0 && finished == 0 && samples == 0
    }

    /**
     * Strength bands, in the words people use rather than numbers.
     *
     * Bands not a histogram: the interesting fact is "I own a lot of
     * barrel-proof bourbon", and a bar chart of exact ABVs says that less
     * clearly than four labels do.
     */
    internal fun strengthBand(abv: Double): String = when {
        abv < 45 -> "80–89 proof"
        abv < 50 -> "90–99 proof"
        abv < 57.5 -> "100–114 proof"
        else -> "115 proof and up"
    }

    fun summarise(
        entries: List<Entry>,
        now: Instant = Instant.now(),
        zone: ZoneId = ZoneId.systemDefault()
    ): Summary {
        val unfinished = entries.filter { !it.isFinished }
        val finished = entries.size - unfinished.size
        val samples = unfinished.count { it.isSample }
        val live = unfinished.filter { !it.isSample }

        val byClass = tally(live.mapNotNull { it.classType?.label })
        val byDistillery = tally(live.mapNotNull { it.distillery })
        val byStrength = tally(live.mapNotNull { it.abv?.let { abv -> strengthBand(abv) } })
        val byBrand = tally(live.mapNotNull { it.brand })
        val byPlace = tally(
            live.mapNotNull { it.storageLocation?.trimSpaces() }.filter { it.isNotEmpty() }
        )

        // Years run oldest first: a growth line reads left to right. Every
        // bottle counts here, finished included -- it was added that year.
        val addedByYear = tally(entries.map { year(it.addedAt, zone) })
            .sortedBy { it.label }

        val longestOpen = live
            .filter { it.isOpen }
            .mapNotNull { entry ->
                val name = entry.name ?: return@mapNotNull null
                val days = AgeMath.daysOpen(entry.openedAt, now) ?: return@mapNotNull null
                Standout(name, days)
            }
            .maxByOrNull { it.value }

        // Priced live bottles with a purchase date, grouped by that year.
        val spent = mutableMapOf<String, Int>()
        for (entry in live) {
            val cents = entry.purchasePriceCents ?: continue
            val at = entry.purchasedAt ?: continue
            val label = year(at, zone)
            spent[label] = (spent[label] ?: 0) + cents
        }
        val spentByYear = spent
            .map { (label, cents) -> Amount(label, cents) }
            .sortedBy { it.label }

        val letters = live.mapNotNull { it.topperLetter }
        val toppers = if (letters.isEmpty()) null else TopperLetters.progress(letters)

        val pours = live.mapNotNull { entry ->
            val name = entry.name ?: return@mapNotNull null
            val cents = entry.costPerPourCents ?: return@mapNotNull null
            Standout(name, cents)
        }
        val averagePour = if (pours.isEmpty()) {
            null
        } else {
            (pours.sumOf { it.value }.toDouble() / pours.size).roundToInt()
        }

        return Summary(
            onShelf = live.size,
            open = live.count { it.isOpen },
            sealed = live.count { !it.isOpen },
            finished = finished,
            samples = samples,
            byClass = byClass,
            byDistillery = byDistillery,
            byStrength = byStrength,
            byBrand = byBrand,
            byPlace = byPlace,
            addedByYear = addedByYear,
            distilleryCount = live.mapNotNull { it.distillery }.toSet().size,
            classCount = live.mapNotNull { it.classType?.label }.toSet().size,
            picks = live.count { it.isPick },
            highestProof = live.mapNotNull { it.abv }.maxOrNull()?.let { ABV(it).proof },
            oldestStatedAgeMonths = live.mapNotNull { it.ageMonths }.maxOrNull(),
            longestOpen = longestOpen,
            topperLetters = toppers,
            spentByYear = spentByYear,
            averageCostPerPourCents = averagePour,
            dearestPour = pours.maxByOrNull { it.value },
            cheapestPour = pours.minByOrNull { it.value }
        )
    }

    /**
     * Biggest first, then alphabetically so equal counts do not reshuffle
     * between launches -- a chart whose order changes on its own reads as a
     * bug.
     */
    internal fun tally(values: List<String>): List<Slice> {
        val counts = LinkedHashMap<String, Int>()
        for (value in values) counts[value] = (counts[value] ?: 0) + 1
        return counts
            .map { (label, count) -> Slice(label, count) }
            .sortedWith(
                compareByDescending<Slice> { it.count }
                    .thenBy(String.CASE_INSENSITIVE_ORDER) { it.label }
            )
    }

    private fun year(at: Instant, zone: ZoneId): String =
        LocalDate.ofInstant(at, zone).year.toString()

    /** Spaces and tabs, as Swift's `.whitespaces` trims; not line breaks. */
    private fun String.trimSpaces(): String =
        trim { it.isWhitespace() && it != '\n' && it != '\r' }
}

/**
 * What is open right now, written out for somebody else to read.
 *
 * From the research, unprompted: *"I really like the menu concept! Now if
 * there was a way to take the spreadsheet and populate the menu......"*
 *
 * It is a list of what is OPEN, because that is the question a guest is
 * actually asking. A sealed bottle is not on offer, and printing the whole
 * collection turns a menu into a brag.
 */
object PourMenu {

    data class Item(
        val name: String,
        val detail: String? = null,
        val proof: Double? = null
    )

    /**
     * Plain text, because it has to survive being pasted into a message.
     *
     * No prices. A menu with prices on it reads as bragging about what the
     * evening cost, and the one thing a guest cannot do with that information
     * is enjoy the whiskey.
     */
    fun text(title: String, items: List<Item>): String {
        if (items.isEmpty()) return "$title\n\nNothing open at the moment."
        val lines = items.map { item ->
            val line = StringBuilder("• ").append(item.name)
            item.proof?.let { line.append(String.format(Locale.ROOT, "  (%.1f proof)", it)) }
            val detail = item.detail
            if (!detail.isNullOrEmpty()) line.append("\n  ").append(detail)
            line.toString()
        }
        return (listOf(title, "") + lines).joinToString("\n")
    }
}
