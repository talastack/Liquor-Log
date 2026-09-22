package com.talastack.liquorlog.engine

import java.time.Instant
import java.time.LocalDate
import java.time.LocalDateTime
import java.time.Year
import java.time.ZoneId
import java.util.Locale

/**
 * The bottling code on a Wild Turkey, read as a date.
 *
 * Wild Turkey does not publish its scheme. The formats here are the ones
 * Rare Bird 101 -- the reference collectors use for the brand -- has
 * documented from bottles in hand (rarebird101.com/bottle-codes), with
 * its own worked examples as the tests. Three formats are readable
 * without guessing:
 *
 * - **2013-2023:** `LL/YMDDHHMM` -- year letter (A is 2012, so D is
 *   2015), month letter (A is January), day, 24-hour time.
 *   `LL/DF021000` is 10:00 on 2 June 2015. Rare Bird lists 2022-2024
 *   bottles with the same shape and a printed date on a second line.
 * - **2024 on:** `LA YMDD?HHMM` -- the same letters, then one letter
 *   whose meaning is not documented, then the time. `LA MI26E0719` is
 *   07:19 on 26 September 2024.
 * - **2006-2014:** `L Y DDD ?? HHMM` -- a single year digit, the day of
 *   the year, letters that are not documented, the time. `L9132FH 1253`
 *   is 12:53 on 12 May 2009; `L6229NU7A` is 17 August 2006. A single
 *   digit is a decade guess by itself; Rare Bird dates this format 2006
 *   to 2014, which pins it.
 *
 * The 1990s formats (`L-15-220`) are read too. The unhyphenated 1992
 * form (`L12358`) is six characters that a Buffalo Trace laser code also
 * uses, so it is left to that decoder rather than misread here.
 */
data class WildTurkeyCode(
    val year: Int,
    val month: Int,
    val day: Int,
    val hour: Int?,
    val minute: Int?,
    /** Which documented format it was read as, for the screen. */
    val format: Format
) {

    enum class Format(val raw: String) {
        LETTERED_2013("lettered2013"),       // LL/YMDD
        LETTERED_2024("lettered2024"),       // LA YMDD?
        DAY_OF_YEAR_2007("dayOfYear2007"),   // L Y DDD
        HYPHENATED_1990S("hyphenated1990s")  // L-1Y-DDD
    }

    /**
     * The bottling moment. Noon stands in for an undocumented time, as on
     * the Swift side: it is the hour least likely to slide into the day
     * before or after when a zone is applied.
     */
    fun date(zone: ZoneId = ZoneId.systemDefault()): Instant =
        LocalDateTime.of(year, month, day, hour ?: 12, minute ?: 0)
            .atZone(zone)
            .toInstant()

    /** "Bottled 2 June 2015 at 10:00." */
    val summary: String
        get() {
            val text = StringBuilder("Bottled $day ${monthNames[month - 1]} $year")
            if (hour != null && minute != null) {
                text.append(String.format(Locale.ROOT, " at %02d:%02d", hour, minute))
            }
            return text.append(".").toString()
        }

    companion object {

        val monthNames = listOf(
            "January", "February", "March", "April", "May", "June", "July",
            "August", "September", "October", "November", "December"
        )

        /** A is 2012. */
        private const val BASE = 2012

        // Patterns use [0-9], never \d: on the Swift side ICU's \d matches
        // every Unicode digit while Int() reads only ASCII, so a fullwidth
        // digit typed from a Japanese keyboard would match and then trap on
        // the unwrap. The JVM's \d is ASCII-only, but the two engines are
        // meant to be readable side by side, so the spelling stays.

        // LL/YMDDHHMM, 2013-2023; the slash is optional.
        private val PATTERN_2013 = Regex("^LL/?([B-L])([A-L])([0-9]{2})([0-9]{4})?$")

        // LA YMDD ? HHMM, 2024 on.
        private val PATTERN_2024 = Regex("^LA([M-Z])([A-L])([0-9]{2})[A-Z]?([0-9]{4})?$")

        // L Y DDD ?? HHMM, 2006-2014.
        private val PATTERN_DAY_OF_YEAR = Regex("^L([0-9])([0-9]{3})[A-Z]{1,3}([0-9]{4})?[A-Z0-9]{0,2}$")

        // L-1Y-DDD, 1992-1998: the 1 is fixed, Y the last digit of the year.
        private val PATTERN_HYPHENATED = Regex("^L-1([0-9])-([0-9]{3})$")

        fun parse(raw: String): WildTurkeyCode? {
            val text = raw.uppercase().replace(" ", "")

            PATTERN_2013.matchEntire(text)?.let { m ->
                val parts = assemble(
                    year = BASE + index(m.groupValues[1]),
                    month = index(m.groupValues[2]) + 1,
                    day = m.groupValues[3].toInt(),
                    time = m.groupValues[4]
                ) ?: return null
                return parts.code(Format.LETTERED_2013)
            }

            PATTERN_2024.matchEntire(text)?.let { m ->
                val parts = assemble(
                    year = BASE + index(m.groupValues[1]),
                    month = index(m.groupValues[2]) + 1,
                    day = m.groupValues[3].toInt(),
                    time = m.groupValues[4]
                ) ?: return null
                return parts.code(Format.LETTERED_2024)
            }

            // A 5 is refused: the format is documented for 2006 to 2014, so
            // no year of it ends in one.
            PATTERN_DAY_OF_YEAR.matchEntire(text)?.let { m ->
                val digit = m.groupValues[1].toInt()
                if (digit == 5) return null
                val year = if (digit >= 6) 2000 + digit else 2010 + digit
                val parts = dayOfYear(m.groupValues[2].toInt(), year, m.groupValues[3])
                    ?: return null
                return parts.code(Format.DAY_OF_YEAR_2007)
            }

            PATTERN_HYPHENATED.matchEntire(text)?.let { m ->
                val year = 1990 + m.groupValues[1].toInt()
                val parts = dayOfYear(m.groupValues[2].toInt(), year, null) ?: return null
                return parts.code(Format.HYPHENATED_1990S)
            }

            return null
        }

        // MARK: - Pieces

        private data class Parts(
            val year: Int, val month: Int, val day: Int,
            val hour: Int?, val minute: Int?
        ) {
            fun code(format: Format) = WildTurkeyCode(year, month, day, hour, minute, format)
        }

        private fun index(letter: String): Int = letter[0] - 'A'

        /**
         * Two different absences, flattened into one shape: `null` means the
         * time on the bottle is impossible and the whole code is a misread;
         * a pair of nulls means the format carried no time at all.
         */
        private fun clock(raw: String): Pair<Int?, Int?>? {
            if (raw.isEmpty()) return null to null
            val hour = raw.take(2).toIntOrNull() ?: return null
            val minute = raw.takeLast(2).toIntOrNull() ?: return null
            if (hour >= 24 || minute >= 60) return null
            return hour to minute
        }

        /** A real calendar date or nothing: 31 June is refused, not rounded. */
        private fun assemble(year: Int, month: Int, day: Int, time: String): Parts? {
            val (hour, minute) = clock(time) ?: return null
            val date = runCatching { LocalDate.of(year, month, day) }.getOrNull() ?: return null
            return Parts(date.year, date.monthValue, date.dayOfMonth, hour, minute)
        }

        private fun dayOfYear(ordinal: Int, year: Int, time: String?): Parts? {
            val (hour, minute) = clock(time ?: "") ?: return null
            val length = if (Year.isLeap(year.toLong())) 366 else 365
            if (ordinal !in 1..length) return null
            val date = LocalDate.ofYearDay(year, ordinal)
            return Parts(year, date.monthValue, date.dayOfMonth, hour, minute)
        }
    }
}
