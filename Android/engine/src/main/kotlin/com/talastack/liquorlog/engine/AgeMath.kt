package com.talastack.liquorlog.engine

import java.time.Duration
import java.time.Instant
import java.time.LocalDate
import java.time.ZoneId
import kotlin.math.max

/**
 * Four different numbers that all get called "age", kept apart because
 * conflating them is how a bottle gets described as 27 years old when the
 * whiskey in it is 12.
 */
object AgeMath {

    /**
     * "7 years 4 months", "11 months", "12 years". Months are what a label
     * prints for a pick and what the bottle stores; years alone would round
     * a 7-year-11-month barrel to the same age as a 7-year-1-month one.
     */
    fun describe(months: Int): String {
        val years = months / 12
        val rest = months % 12
        if (years == 0) return "$rest ${if (rest == 1) "month" else "months"}"
        if (rest == 0) return "$years ${if (years == 1) "year" else "years"}"
        return "$years ${if (years == 1) "year" else "years"} " +
            "$rest ${if (rest == 1) "month" else "months"}"
    }

    /**
     * Maturation: time in the barrel. **The only ageing that changes the
     * whiskey.** Null when either year is missing or the pair is impossible.
     */
    fun maturationYears(distilledYear: Int?, bottledYear: Int?): Int? {
        if (distilledYear == null || bottledYear == null) return null
        val years = bottledYear - distilledYear
        return if (years >= 0) years else null
    }

    /**
     * Time since bottling.
     *
     * Whiskey does not mature in glass. This is provenance -- how dusty the
     * bottle is -- and the UI must never present it as age. A 1985 bottling
     * of a 12-year is a 12-year-old whiskey in a 40-year-old bottle.
     */
    fun yearsInGlass(
        bottledYear: Int?,
        now: Instant = Instant.now(),
        zone: ZoneId = ZoneId.systemDefault(),
    ): Int? {
        if (bottledYear == null) return null
        val currentYear = LocalDate.ofInstant(now, zone).year
        val years = currentYear - bottledYear
        return if (years >= 0) years else null
    }

    /** How long this bottle has been yours. */
    fun daysOwned(
        purchasedAt: Instant?,
        now: Instant = Instant.now(),
    ): Int? = purchasedAt?.let { days(it, now) }

    /**
     * How long it has been open -- one of the two inputs to oxidation, the
     * other being headroom.
     */
    fun daysOpen(
        openedAt: Instant?,
        now: Instant = Instant.now(),
    ): Int? = openedAt?.let { days(it, now) }

    /**
     * Whole days between two instants. Negative spans clamp to zero: a
     * device clock that has jumped backwards should not produce a bottle
     * opened in the future.
     */
    fun days(from: Instant, to: Instant): Int =
        max(0L, Duration.between(from, to).toDays()).toInt()
}
