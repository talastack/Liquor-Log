package com.talastack.liquorlog.engine

import java.time.Instant
import java.time.LocalDate
import java.time.ZoneId
import java.util.Locale

/**
 * Your Blanton's, written out in the shape of the dump-date registry.
 *
 * The one thing the bourbon community has demonstrably welcomed (research
 * §"The risk that is not code") is a non-commercial dump-date registry with
 * an explicit ask for contributions. The live one is bourbondumpdate.com,
 * whose record is the dump date, the state the bottle was found in, and the
 * letter on the cork topper. This writes the same three things, plus the
 * barrel identity the label prints, as a CSV a person can paste into a
 * form or send to the registry's author.
 *
 * It is a contribution the person makes, by hand, from their own data.
 * Nothing here contacts anybody; the app has no relationship with the
 * registry and claims none. State found is the purchase store's state
 * when the person recorded one, otherwise blank -- guessing a state from a
 * store name is the kind of thing that poisons a registry.
 */
object DumpDateRegistry {

    data class Entry(
        val dumpedAt: Instant? = null,
        val topperLetter: String? = null,
        val barrel: String? = null,
        val warehouse: String? = null,
        val rick: String? = null,
        val bottleNumber: Int? = null,
        val store: String? = null,
        val stateFound: String? = null
    ) {
        /**
         * A registry entry needs a dump date; the letter alone is a
         * collector's fact, not a registry one.
         */
        val isSubmittable: Boolean get() = dumpedAt != null
    }

    val header: List<String> = listOf(
        "dump_date", "topper_letter", "barrel", "warehouse", "rick",
        "bottle_number", "store", "state_found"
    )

    /**
     * Only entries with a dump date, oldest dump first. Dates as ISO
     * (yyyy-mm-dd), because that is the one format every form parses.
     */
    fun csv(entries: List<Entry>, zone: ZoneId = ZoneId.systemDefault()): String {
        val rows = entries
            .filter { it.isSubmittable }
            .sortedBy { it.dumpedAt ?: Instant.MIN }
            .map { entry ->
                listOf(
                    entry.dumpedAt?.let { isoDay(it, zone) } ?: "",
                    entry.topperLetter?.let { TopperLetters.normalise(it) } ?: "",
                    entry.barrel ?: "",
                    entry.warehouse ?: "",
                    entry.rick ?: "",
                    entry.bottleNumber?.toString() ?: "",
                    entry.store ?: "",
                    entry.stateFound ?: ""
                )
            }
        return CSVWriter.document(header = header, rows = rows)
    }

    internal fun isoDay(date: Instant, zone: ZoneId): String {
        val day = LocalDate.ofInstant(date, zone)
        return String.format(
            Locale.ROOT, "%04d-%02d-%02d", day.year, day.monthValue, day.dayOfMonth
        )
    }
}
