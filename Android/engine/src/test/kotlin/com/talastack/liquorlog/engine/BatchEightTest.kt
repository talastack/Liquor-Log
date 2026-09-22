package com.talastack.liquorlog.engine

import java.time.LocalDate
import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertNotNull
import kotlin.test.assertNull

/** The Buffalo Trace bottling code: year, day of the year, time, line. */
class LaserCodeTest {

    @Test
    fun `the canonical example`() {
        val code = assertNotNull(LaserCode.parse("L19274 15:02 K"))
        assertEquals(2019, code.year)
        assertEquals(274, code.dayOfYear)
        assertEquals(15, code.hour)
        assertEquals(2, code.minute)
        assertEquals('K', code.line)
        assertEquals('L', code.prefix)
        assertEquals(LocalDate.of(2019, 10, 1), code.localDate())
        assertEquals("Bottled 1 October 2019 at 15:02, line K.", code.summary())
        assertEquals("L19274 15:02 K", code.toString())
    }

    /** The modern code as the public write-ups give it, plant number and all. */
    @Test
    fun `the modern format with a plant number`() {
        val code = assertNotNull(LaserCode.parse("L 18 096 01 1050 K"))
        assertEquals(2018, code.year)
        assertEquals(96, code.dayOfYear)
        assertEquals(1, code.plant)
        assertEquals(10, code.hour)
        assertEquals(50, code.minute)
        assertEquals('K', code.line)
        assertEquals("Bottled 6 April 2018 at 10:50, line K.", code.summary())
        assertEquals("L18096 01 10:50 K", code.toString())

        val plantOnly = assertNotNull(LaserCode.parse("L1809601"))
        assertEquals(1, plantOnly.plant)
        assertNull(plantOnly.hour)
    }

    /** 2007-2011: line, day, year, time. */
    @Test
    fun `the older format`() {
        val code = assertNotNull(LaserCode.parse("K 259 10 15:47"))
        assertEquals(2010, code.year)
        assertEquals(259, code.dayOfYear)
        assertEquals(15, code.hour)
        assertEquals(47, code.minute)
        assertEquals('K', code.line)
        assertNull(code.prefix)
        assertEquals("Bottled 16 September 2010 at 15:47, line K.", code.summary())
    }

    @Test
    fun `spaces and the colon are optional`() {
        assertEquals(LaserCode.parse("L19274 15:02 K"), LaserCode.parse("l192741502k"))
        val bare = assertNotNull(LaserCode.parse("L19274"))
        assertNull(bare.hour)
        assertEquals("Bottled 1 October 2019.", bare.summary())
    }

    @Test
    fun `day one and the last day`() {
        val first = assertNotNull(LaserCode.parse("L21001"))
        assertEquals(1, assertNotNull(first.localDate()).dayOfMonth)
        val leap = assertNotNull(LaserCode.parse("L20366"))
        assertEquals(LocalDate.of(2020, 12, 31), leap.localDate())
        assertNull(LaserCode.parse("L21366"), "2021 has no day 366")
        assertNull(LaserCode.parse("L19400"))
        assertNull(LaserCode.parse("L19000"))
    }

    /** The other decoders' inputs must not be mistaken for a laser code. */
    @Test
    fun `it does not eat the other schemes`() {
        assertNull(LaserCode.parse("OESQ"))
        assertNull(LaserCode.parse("B523"), "a Heaven Hill batch code has three digits, not five")
        assertNull(LaserCode.parse("A1123"))
        assertNull(LaserCode.parse(""))
    }

    @Test
    fun `a bad time is ignored, not invented`() {
        val code = assertNotNull(LaserCode.parse("L19274 25:99 K"))
        assertNull(code.hour)
        assertEquals('K', code.line)
    }
}

/** Rare Bird 101's own worked examples, one per format. */
class WildTurkeyCodeTest {

    @Test
    fun `the lettered format of 2013 to 2021`() {
        val code = assertNotNull(WildTurkeyCode.parse("LL/DF021000"))
        assertEquals(listOf(2015, 6, 2), listOf(code.year, code.month, code.day))
        assertEquals(10, code.hour)
        assertEquals(0, code.minute)
        assertEquals(WildTurkeyCode.Format.LETTERED_2013, code.format)
        assertEquals("Bottled 2 June 2015 at 10:00.", code.summary)
        assertEquals(2015, WildTurkeyCode.parse("ll df02 1000")?.year, "spaces and the slash are optional")
    }

    @Test
    fun `the year letters run from A is 2012`() {
        assertEquals(2019, WildTurkeyCode.parse("LL/HA01")?.year)
        assertEquals(2020, WildTurkeyCode.parse("LL/IA01")?.year)
        assertEquals(2021, WildTurkeyCode.parse("LL/JL31")?.year)
        assertEquals(12, WildTurkeyCode.parse("LL/JL31")?.month)
        assertEquals(2022, WildTurkeyCode.parse("LL/KA150900")?.year)
        assertEquals(2023, WildTurkeyCode.parse("LL/LC011200")?.year)
        assertNull(WildTurkeyCode.parse("LL/MA01"), "2024 bottles start with LA")
    }

    /**
     * A fullwidth or Arabic-Indic digit is not a code; it must not be a
     * crash either.
     */
    @Test
    fun `non-ASCII digits are refused, not trapped`() {
        assertNull(WildTurkeyCode.parse("LL/DF\uFF10\uFF12"))
        assertNull(WildTurkeyCode.parse("L\u0669\u0661\u0663\u0662FH"))
    }

    @Test
    fun `the format from 2024`() {
        val code = assertNotNull(WildTurkeyCode.parse("LA MI26E0719"))
        assertEquals(listOf(2024, 9, 26), listOf(code.year, code.month, code.day))
        assertEquals(7, code.hour)
        assertEquals(19, code.minute)
        assertEquals(WildTurkeyCode.Format.LETTERED_2024, code.format)
    }

    @Test
    fun `the day-of-year format from 2006 to 2014`() {
        val nine = assertNotNull(WildTurkeyCode.parse("L9132FH 1253"))
        assertEquals(listOf(2009, 5, 12), listOf(nine.year, nine.month, nine.day))
        assertEquals(12, nine.hour)
        assertEquals(53, nine.minute)

        val six = assertNotNull(WildTurkeyCode.parse("L6229NU7A"))
        assertEquals(listOf(2006, 8, 17), listOf(six.year, six.month, six.day))
        assertNull(six.hour)

        assertEquals(2013, WildTurkeyCode.parse("L3040AB")?.year)
        assertNull(WildTurkeyCode.parse("L5040AB"), "no year of the format ends in 5")
    }

    @Test
    fun `the hyphenated nineties`() {
        val code = assertNotNull(WildTurkeyCode.parse("L-15-220"))
        assertEquals(listOf(1995, 8, 8), listOf(code.year, code.month, code.day))
        assertEquals(WildTurkeyCode.Format.HYPHENATED_1990S, code.format)
    }

    /** Impossible dates are refused, not rounded. */
    @Test
    fun `impossible dates are refused`() {
        assertNull(WildTurkeyCode.parse("LL/DF311000"), "31 June")
        assertNull(WildTurkeyCode.parse("LL/DF022500"), "25 o'clock")
        assertNull(WildTurkeyCode.parse("L9366FH"), "day 366 of a common year")
        assertNull(WildTurkeyCode.parse("LL/DM02"), "M is not a month")
    }

    /** Other brands' codes are not Wild Turkey's. */
    @Test
    fun `other codes are left alone`() {
        assertNull(WildTurkeyCode.parse("OESQ"))
        assertNull(WildTurkeyCode.parse("B523"))
        assertNull(WildTurkeyCode.parse("L19274"), "a Buffalo Trace laser code")
        assertNull(WildTurkeyCode.parse("DSP-KY-113"))
        assertNull(WildTurkeyCode.parse("L12358"), "the unhyphenated 1992 form is left to the laser decoder")
    }

    /** The raw values are what a stored format string has to keep saying. */
    @Test
    fun `the format names match the Swift raw values`() {
        assertEquals(
            listOf("lettered2013", "lettered2024", "dayOfYear2007", "hyphenated1990s"),
            WildTurkeyCode.Format.entries.map { it.raw }
        )
    }
}
