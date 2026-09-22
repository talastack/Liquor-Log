package com.talastack.liquorlog.engine

import java.time.Instant
import java.time.LocalDate
import java.time.ZoneId
import java.time.ZoneOffset
import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertFalse
import kotlin.test.assertNotNull
import kotlin.test.assertNull
import kotlin.test.assertTrue

/**
 * Bourbon data hits every CSV escaping edge case: pick names contain commas,
 * tasting notes contain quotes and line breaks. A naive join produces a file
 * that opens misaligned and looks exactly like lost data -- in a category
 * where people have already been burned by apps losing their collections.
 */
class CSVWriterTest {

    private val utc: ZoneId = ZoneOffset.UTC

    @Test
    fun `plain fields are not quoted`() {
        assertEquals("Elijah Craig", CSVWriter.escape("Elijah Craig"))
    }

    @Test
    fun `commas force quoting`() {
        assertEquals("\"Barrel 42, Floor 5\"", CSVWriter.escape("Barrel 42, Floor 5"))
    }

    @Test
    fun `quotes are doubled`() {
        assertEquals("\"the \"\"good\"\" barrel\"", CSVWriter.escape("the \"good\" barrel"))
    }

    @Test
    fun `newlines in notes survive`() {
        assertEquals("\"Nose: toffee\nFinish: hot\"", CSVWriter.escape("Nose: toffee\nFinish: hot"))
    }

    @Test
    fun `a row joins and escapes each field`() {
        assertEquals(
            "Elijah Craig,\"B523, 2023\",8",
            CSVWriter.row(listOf("Elijah Craig", "B523, 2023", "8"))
        )
    }

    @Test
    fun `a document has a header and CRLF endings`() {
        val csv = CSVWriter.document(
            header = listOf("name", "proof"),
            rows = listOf(listOf("Weller 107", "107"), listOf("Booker's", ""))
        )
        assertEquals("name,proof\r\nWeller 107,107\r\nBooker's,\r\n", csv)
    }

    /**
     * A blank cell reads as "not recorded", which is the truth for most
     * optional fields on most bottles. "null" or "0" would be a claim.
     */
    @Test
    fun `missing values are blank, not zero`() {
        assertEquals("", CSVWriter.number(null))
        assertEquals("", CSVWriter.decimal(null))
        assertEquals("", CSVWriter.money(null))
        assertEquals("", CSVWriter.text(null))
        assertEquals("", CSVWriter.date(null))
        assertEquals("", CSVWriter.flag(false))
    }

    /** No currency symbol: it makes the column text in every spreadsheet. */
    @Test
    fun `money is a plain decimal`() {
        assertEquals("79.99", CSVWriter.money(7999))
        assertEquals("0.05", CSVWriter.money(5))
    }

    @Test
    fun `dates are ISO so they sort as text`() {
        val millis = LocalDate.of(2026, 5, 12).atStartOfDay(utc).toInstant().toEpochMilli()
        assertEquals("2026-05-12", CSVWriter.date(millis, utc))
    }
}

/**
 * Reading a spreadsheet. The first thing anybody's file contains is a bottle
 * with a comma in its name, so the parser has to be a real one.
 */
class CSVReaderTest {

    @Test
    fun `a comma inside quotes is not a separator`() {
        val rows = CSVReader.rows("name,proof\n\"Elijah Craig, Batch B523\",124.2\n")
        assertEquals(listOf("Elijah Craig, Batch B523", "124.2"), rows[1])
    }

    @Test
    fun `a doubled quote is a literal quote`() {
        val rows = CSVReader.rows("note\n\"the \"\"good\"\" barrel\"\n")
        assertEquals(listOf("the \"good\" barrel"), rows[1])
    }

    @Test
    fun `a newline inside quotes stays in the field`() {
        val rows = CSVReader.rows("note\n\"nose: toffee\nfinish: hot\"\n")
        assertEquals(2, rows.size)
        assertEquals(listOf("nose: toffee\nfinish: hot"), rows[1])
    }

    /** Excel writes CRLF; a Mac spreadsheet writes LF. Both are one record. */
    @Test
    fun `CRLF and LF both end a record`() {
        assertEquals(2, CSVReader.rows("a,b\r\n1,2\r\n").size)
        assertEquals(2, CSVReader.rows("a,b\n1,2\n").size)
    }

    @Test
    fun `a trailing newline does not make an empty row`() {
        assertEquals(2, CSVReader.rows("a\n1\n").size)
        assertEquals(2, CSVReader.rows("a\n1").size)
    }

    /**
     * Excel prefixes UTF-8 files with a byte-order mark, which would otherwise
     * make the first header "\uFEFFname" and match nothing.
     */
    @Test
    fun `Excel byte-order mark is stripped`() {
        val (header, _) = CSVReader.records("\uFEFFName,Proof\nWeller,90\n")
        assertEquals(listOf("name", "proof"), header)
    }

    @Test
    fun `records key by the header and drop blank rows`() {
        val (_, rows) = CSVReader.records("Name, Proof \nWeller , 90\n,\nBooker's,125\n")
        assertEquals(2, rows.size, "the all-empty row is not a record")
        assertEquals("Weller", rows[0]["name"])
        assertEquals("90", rows[0]["proof"])
        assertEquals("Booker's", rows[1]["name"])
    }

    @Test
    fun `our own export round-trips`() {
        val text = CSVWriter.document(
            header = listOf("name", "proof"),
            rows = listOf(listOf("Weller 107, Special", "107"), listOf("Booker's", ""))
        )
        assertEquals(
            listOf(
                listOf("name", "proof"),
                listOf("Weller 107, Special", "107"),
                listOf("Booker's", "")
            ),
            CSVReader.rows(text)
        )
    }
}

/** Eight stoppers spelling BLANTONS, two of them N, per Blanton's own FAQ. */
class TopperLettersTest {

    @Test
    fun `the set is eight stoppers with two Ns`() {
        assertEquals(8, TopperLetters.stoppers.size)
        assertEquals("BLANTON:S", TopperLetters.stoppers.joinToString(""))
        assertEquals("BLANTONS", TopperLetters.word)
    }

    @Test
    fun `normalising knows both Ns`() {
        assertEquals("B", TopperLetters.normalise("b"))
        assertEquals("N", TopperLetters.normalise(" n "))
        assertEquals("N:", TopperLetters.normalise("n:"))
        assertEquals("N:", TopperLetters.normalise("N2"))
        assertNull(TopperLetters.normalise("'"), "there is no apostrophe stopper")
        assertNull(TopperLetters.normalise("X"))
        assertNull(TopperLetters.normalise("BL"))
        assertNull(TopperLetters.normalise(""))
    }

    @Test
    fun `progress counts and blanks the word`() {
        val progress = TopperLetters.progress(listOf("B", "l", "A", "T", "O", "N:", "S", "b"))
        assertEquals(2, progress.owned["B"])
        assertEquals(listOf("N"), progress.missing)
        assertFalse(progress.isComplete)
        assertEquals(7, progress.ownedCount)
        assertEquals("B L A _ T O N: S", progress.wordLine)
    }

    @Test
    fun `the two Ns are different stoppers`() {
        val oneN = TopperLetters.progress(listOf("B", "L", "A", "N", "T", "O", "S"))
        assertEquals(listOf("N:"), oneN.missing)
        val both = TopperLetters.progress(listOf("B", "L", "A", "N", "T", "O", "N:", "S"))
        assertTrue(both.isComplete)
        assertEquals("B L A N T O N: S", both.wordLine)
    }

    @Test
    fun `unknown letters are ignored`() {
        val progress = TopperLetters.progress(listOf("Z", "?", "", "'"))
        assertEquals(0, progress.ownedCount)
        assertEquals(8, progress.missing.size)
    }
}

/**
 * Heaven Hill batch codes, made a function. The one static guide stopped in
 * 2019 and no interactive decoder existed anywhere.
 */
class BatchCodeTest {

    @Test
    fun `it decodes the canonical example`() {
        val code = assertNotNull(BatchCode.parse("B523"))
        assertEquals(BatchCode.Release.SECOND, code.release)
        assertEquals(5, code.month)
        assertEquals(2023, code.year)
        assertEquals("Second release of 2023, bottled in May", code.summary)
    }

    @Test
    fun `it decodes each release`() {
        assertEquals(
            "First release of 2025, bottled in January",
            assertNotNull(BatchCode.parse("A125")).summary
        )
        assertEquals(
            "Third release of 2023, bottled in September",
            assertNotNull(BatchCode.parse("C923")).summary
        )
    }

    /** The older form carried a two-digit month. */
    @Test
    fun `it decodes a two-digit month`() {
        val code = assertNotNull(BatchCode.parse("A1023"))
        assertEquals(10, code.month)
        assertEquals(2023, code.year)
    }

    @Test
    fun `it is forgiving about case and spacing`() {
        assertEquals("B523", assertNotNull(BatchCode.parse("b523")).code)
        assertEquals("B523", assertNotNull(BatchCode.parse("B 5 23")).code)
        assertEquals("B523", assertNotNull(BatchCode.parse(" b-523 ")).code)
    }

    /**
     * Null, never a partial reading. Three of four characters decoded and the
     * fourth invented is worse than nothing, because nobody can tell.
     */
    @Test
    fun `an unknown letter is refused`() {
        assertNull(BatchCode.parse("D523"))
        assertNull(BatchCode.parse("523"))
    }

    @Test
    fun `an impossible month is refused`() {
        assertNull(BatchCode.parse("B1323"), "there is no thirteenth month")
        assertNull(BatchCode.parse("B023"), "there is no zeroth month")
    }

    @Test
    fun `the wrong number of digits is refused`() {
        assertNull(BatchCode.parse("B5"))
        assertNull(BatchCode.parse("B52"))
        assertNull(BatchCode.parse("B52345"))
    }

    /** Distinct from a Four Roses code, which has no digits at all. */
    @Test
    fun `a Four Roses code is not a batch code`() {
        assertNull(BatchCode.parse("OESQ"))
    }

    /**
     * Releases ship in January, May and September. A code whose letter and
     * month disagree is far more likely a misread than a real bottle.
     */
    @Test
    fun `the usual schedule is recognised`() {
        assertTrue(assertNotNull(BatchCode.parse("A125")).followsTheUsualSchedule)
        assertTrue(assertNotNull(BatchCode.parse("B523")).followsTheUsualSchedule)
        assertTrue(assertNotNull(BatchCode.parse("C923")).followsTheUsualSchedule)
    }

    @Test
    fun `a departure from the schedule is flagged, not refused`() {
        val odd = assertNotNull(BatchCode.parse("A923"))
        assertFalse(odd.followsTheUsualSchedule, "first release in September is unusual")
        assertEquals(9, odd.month, "but it still decodes -- the screen can warn")
    }
}

/** A contribution in the registry's shape, from the person's own data. */
class DumpDateRegistryTest {

    private val utc: ZoneId = ZoneOffset.UTC

    private fun day(n: Long): Instant = Instant.ofEpochSecond(n * 86_400)

    /** CSVWriter ends lines with CRLF for Excel's sake. */
    private fun lines(csv: String): List<String> =
        csv.split("\r\n").filter { it.isNotEmpty() }

    @Test
    fun `only dated entries, oldest first`() {
        val csv = DumpDateRegistry.csv(
            listOf(
                DumpDateRegistry.Entry(
                    dumpedAt = day(400), topperLetter = "b",
                    barrel = "12", warehouse = "H", rick = "34"
                ),
                DumpDateRegistry.Entry(topperLetter = "S"),
                DumpDateRegistry.Entry(
                    dumpedAt = day(10), topperLetter = "n2",
                    store = "Total Wine", stateFound = "VA"
                )
            ),
            utc
        )
        val rows = lines(csv)
        assertEquals(3, rows.size)
        assertEquals(DumpDateRegistry.header.joinToString(","), rows[0])
        assertEquals("1970-01-11,N:,,,,,Total Wine,VA", rows[1])
        assertEquals("1971-02-05,B,12,H,34,,,", rows[2])
    }

    @Test
    fun `an unknown letter is left blank rather than invented`() {
        val csv = DumpDateRegistry.csv(
            listOf(DumpDateRegistry.Entry(dumpedAt = day(0), topperLetter = "Z")),
            utc
        )
        assertEquals("1970-01-01,,,,,,,", lines(csv).last())
    }
}
