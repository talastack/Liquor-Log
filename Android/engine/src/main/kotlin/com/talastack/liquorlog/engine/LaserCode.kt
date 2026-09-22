package com.talastack.liquorlog.engine

import java.time.Instant
import java.time.LocalDate
import java.time.ZoneId
import java.util.Locale

/**
 * The laser-etched bottling code on a Buffalo Trace bottle.
 *
 * Every bottle out of Frankfort -- Blanton's, Weller, Stagg, Taylor, Eagle
 * Rare, Buffalo Trace itself -- carries an etched line near the base of
 * the glass. The distillery has never published the scheme; the community
 * worked it out from thousands of bottles, and two independent write-ups
 * agree on it (both read 15 September 2026):
 *
 * - https://debonairgentlemen.com/2023/09/25/how-to-read-a-buffalo-trace-laser-code/
 * - https://whiskeyjar.blog/2020/06/14/happy-national-bourbon-day-sipping-on-col-e-h-taylor-single-barrel-and-a-bit-about-laser-codes-on-buffalo-trace-bottles-and-the-vintage-of-those-bourbons/
 *
 * Since 2012:
 *
 * ```
 * L 18 096 01 1050 K
 * | |  |   |  |    +- bottling line
 * | |  |   |  +- time of day, 24-hour
 * | |  |   +- plant number
 * | |  +- day of the year, 1-366
 * | +- year, two digits
 * +- lot designation, always L
 * ```
 *
 * so that bottle was filled on the 96th day of 2018, 6 April, at 10:50.
 * From 2007 to 2011 the order was different -- `K 259 10 15:47` is line K,
 * day 259, 2010, 15:47 -- and both are read. The plant number and the
 * time are kept when present and never invented when absent.
 *
 * For a Weller or a Taylor this is the only date the bottle carries; for a
 * Blanton's it sits beside the dump date. A day that does not exist (400,
 * or 366 in a non-leap year) is refused rather than repaired.
 */
data class LaserCode(
    val prefix: Char?,
    val year: Int,
    val dayOfYear: Int,
    val plant: Int? = null,
    val hour: Int? = null,
    val minute: Int? = null,
    val line: Char? = null
) {

    /** The bottling date, as the plain day it is. */
    fun localDate(): LocalDate? {
        val length = if (isLeap(year)) 366 else 365
        if (dayOfYear !in 1..length) return null
        return LocalDate.ofYearDay(year, dayOfYear)
    }

    /** The bottling date as an instant, at the start of that day. */
    fun date(zone: ZoneId = ZoneId.systemDefault()): Instant? =
        localDate()?.atStartOfDay(zone)?.toInstant()

    override fun toString(): String {
        val out = StringBuilder()
        if (prefix != null) out.append(prefix)
        out.append(String.format(Locale.ROOT, "%02d%03d", year % 100, dayOfYear))
        if (plant != null) out.append(String.format(Locale.ROOT, " %02d", plant))
        if (hour != null && minute != null) {
            out.append(String.format(Locale.ROOT, " %02d:%02d", hour, minute))
        }
        if (line != null) out.append(" ").append(line)
        return out.toString()
    }

    /**
     * "Bottled 6 April 2018 at 10:50, line K."
     *
     * Swift threads a `Calendar` through here; it cancels out, because the
     * date is built and read back in the same one. The day of the year is
     * the fact, and it does not move with a time zone.
     */
    fun summary(): String {
        val date = localDate()
        val bottledOn = if (date != null) {
            "${date.dayOfMonth} ${BatchCode.monthName(date.monthValue)} ${date.year}"
        } else {
            "day $dayOfYear of $year"
        }
        val out = StringBuilder("Bottled ").append(bottledOn)
        if (hour != null && minute != null) {
            out.append(String.format(Locale.ROOT, " at %02d:%02d", hour, minute))
        }
        if (line != null) out.append(", line ").append(line)
        return out.append(".").toString()
    }

    companion object {

        // 2012 on: [L] YY DDD [PP] [HHMM] [line]. The digit run after the
        // letter is 5, 7, 9 or 11 long; its length says which parts exist.
        private val MODERN =
            Regex("^([A-Z])?([0-9]{5}|[0-9]{7}|[0-9]{9}|[0-9]{11})([A-Z])?$")

        // 2007-2011: line DDD YY HHMM.
        private val OLDER = Regex("^([A-Z])([0-9]{3})([0-9]{2})([0-9]{4})$")

        /** Reads either format, with or without the spaces and the colon. */
        fun parse(raw: String): LaserCode? {
            val text = raw.uppercase().replace(" ", "").replace(":", "")

            val modern = MODERN.matchEntire(text)
            if (modern != null) {
                val digits = modern.groupValues[2]
                val yy = digits.take(2).toIntOrNull() ?: 0
                val ddd = digits.drop(2).take(3).toIntOrNull() ?: 0
                var rest = digits.drop(5)
                var plant: Int? = null
                var hour: Int? = null
                var minute: Int? = null
                if (rest.length == 2 || rest.length == 6) {
                    plant = rest.take(2).toIntOrNull()
                    rest = rest.drop(2)
                }
                if (rest.length == 4) {
                    val h = rest.take(2).toIntOrNull()
                    val m = rest.takeLast(2).toIntOrNull()
                    if (h != null && m != null && h in 0..23 && m in 0..59) {
                        hour = h
                        minute = m
                    }
                }
                // A day that does not exist is not a modern code; it may
                // still be the older order below, where the day comes first.
                val made = checked(2000 + yy, ddd)
                if (made != null) {
                    return LaserCode(
                        prefix = modern.groups[1]?.value?.firstOrNull(),
                        year = made.first,
                        dayOfYear = made.second,
                        plant = plant,
                        hour = hour,
                        minute = minute,
                        line = modern.groups[3]?.value?.firstOrNull()
                    )
                }
            }

            val older = OLDER.matchEntire(text) ?: return null
            val ddd = older.groupValues[2].toIntOrNull() ?: 0
            val yy = older.groupValues[3].toIntOrNull() ?: 0
            if (yy !in 7..11) return null
            val made = checked(2000 + yy, ddd) ?: return null
            val time = older.groupValues[4]
            val h = time.take(2).toIntOrNull() ?: -1
            val m = time.takeLast(2).toIntOrNull() ?: -1
            val valid = h in 0..23 && m in 0..59
            return LaserCode(
                prefix = null,
                year = made.first,
                dayOfYear = made.second,
                plant = null,
                hour = if (valid) h else null,
                minute = if (valid) m else null,
                line = older.groupValues[1].firstOrNull()
            )
        }

        private fun checked(year: Int, day: Int): Pair<Int, Int>? {
            if (day !in 1..366) return null
            if (day == 366 && !isLeap(year)) return null
            return year to day
        }

        internal fun isLeap(year: Int): Boolean =
            (year % 4 == 0 && year % 100 != 0) || year % 400 == 0
    }
}
