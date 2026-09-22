package com.talastack.liquorlog.engine

import java.util.Locale

/**
 * Heaven Hill barrel-proof batch codes: `B523`, `A125`, `C923`.
 *
 * Elijah Craig Barrel Proof and Larceny Barrel Proof share the scheme, and it
 * is stated on Heaven Hill's own material:
 *
 * ```
 * B 5 23
 * | |  +-- year, two digits           2023
 * | +----- month bottled, one digit   5 = May
 * +------- release of the year        A = first, B = second, C = third
 * ```
 *
 * Three releases a year -- January, May, September -- so the letter and the
 * month agree on a real code, and disagreement is the tell for a misread.
 *
 * The research found no interactive decoder for these anywhere, and the one
 * static guide (ModernThirst) stopped at A119 in 2019. The knowledge lives in
 * blog posts; this makes it a function.
 *
 * `null` for anything that does not fit, never a partial reading. A month of
 * 13 is a misread, not a thirteenth month.
 */
data class BatchCode(
    val release: Release,
    /** 1-12. */
    val month: Int,
    /** Four digits. */
    val year: Int
) {

    enum class Release(val letter: Char) {
        FIRST('A'),
        SECOND('B'),
        THIRD('C');

        /** Swift spells this `ordinal`; on the JVM that name is taken by the enum's own index. */
        val ordinalName: String
            get() = when (this) {
                FIRST -> "First"
                SECOND -> "Second"
                THIRD -> "Third"
            }

        /** The month each release has historically shipped in. */
        val usualMonth: Int
            get() = when (this) {
                FIRST -> 1
                SECOND -> 5
                THIRD -> 9
            }

        companion object {
            fun of(letter: Char): Release? = entries.firstOrNull { it.letter == letter }
        }
    }

    override fun toString(): String =
        "${release.letter}$month" + String.format(Locale.ROOT, "%02d", year % 100)

    val code: String get() = toString()

    /** "Second release of 2023, bottled in May". */
    val summary: String
        get() = "${release.ordinalName} release of $year, bottled in ${monthName(month)}"

    /**
     * True when the letter and the month agree with the usual schedule. A
     * code that says "first release, bottled in September" is far more likely
     * a misread than a real bottle, and a screen should say so gently.
     */
    val followsTheUsualSchedule: Boolean get() = month == release.usualMonth

    companion object {
        /**
         * Parses `B523`, `b523`, `B 5 23`, or the older two-digit-month form
         * `A1023`. Null for anything else.
         */
        fun parse(raw: String): BatchCode? {
            val code = raw.uppercase().filter { it.isLetter() || it.isDigit() }
            val first = code.firstOrNull() ?: return null
            val release = Release.of(first) ?: return null

            val digits = code.drop(1)
            // Three digits is month + year; four is a two-digit month + year.
            if (digits.length != 3 && digits.length != 4) return null
            if (!digits.all { it.isDigit() }) return null
            val year = digits.takeLast(2).toIntOrNull() ?: return null
            val month = digits.dropLast(2).toIntOrNull() ?: return null
            if (month !in 1..12) return null

            // The scheme began in the 2010s and a two-digit year cannot mean
            // anything earlier, so 2000 is the only sensible century.
            return BatchCode(release = release, month = month, year = 2000 + year)
        }

        fun monthName(month: Int): String {
            val names = listOf(
                "January", "February", "March", "April", "May", "June",
                "July", "August", "September", "October", "November", "December"
            )
            return if (month in 1..12) names[month - 1] else "?"
        }
    }
}
