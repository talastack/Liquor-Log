package com.talastack.liquorlog.engine

import java.time.Instant
import java.time.LocalDate
import java.time.ZoneId
import java.util.Locale

/**
 * Writes a CSV anyone can open in a spreadsheet.
 *
 * **Export is free, always, and prominent.** In this category people have been
 * burned by apps losing their data or vanishing, and the advice they give each
 * other is blunt: *be wary of any app that will not let you export.* It costs
 * almost nothing to build and it is the strongest trust signal available, so
 * putting it behind a paywall would be trading the thing that earns adoption
 * for a rounding error in revenue.
 *
 * Spreadsheets are also the real incumbent. A collection that can leave is a
 * collection somebody is willing to put in.
 */
object CSVWriter {

    /**
     * RFC 4180: quote a field that contains a comma, a quote or a newline, and
     * double any quote inside it.
     *
     * Bourbon data hits every one of these. Pick names contain commas
     * ("Barrel 42, Floor 5"), tasting notes contain quotes and line breaks, and
     * a naive join would produce a file that opens misaligned and looks like
     * lost data.
     */
    fun escape(field: String): String {
        val needsQuoting = field.contains(",") ||
            field.contains("\"") ||
            field.contains("\n") ||
            field.contains("\r")
        if (!needsQuoting) return field
        return "\"" + field.replace("\"", "\"\"") + "\""
    }

    fun row(fields: List<String>): String = fields.joinToString(",") { escape(it) }

    /**
     * A whole document. CRLF line endings, because Excel is the destination
     * often enough to be worth not arguing with.
     */
    fun document(header: List<String>, rows: List<List<String>>): String =
        (listOf(row(header)) + rows.map { row(it) }).joinToString("\r\n") + "\r\n"

    // MARK: - Formatting helpers

    /**
     * Empty rather than "null" or "0". A blank cell reads as "not recorded",
     * which is the truth for most optional fields on most bottles.
     */
    fun text(value: String?): String = value ?: ""

    fun number(value: Int?): String = value?.toString() ?: ""

    fun decimal(value: Double?, places: Int = 1): String =
        if (value == null) "" else String.format(Locale.ROOT, "%.${places}f", value)

    /**
     * Money as a plain decimal, no currency symbol. A symbol makes the column
     * text in every spreadsheet that opens it.
     */
    fun money(cents: Int?): String =
        if (cents == null) "" else String.format(Locale.ROOT, "%.2f", cents / 100.0)

    /** ISO dates, because they sort correctly as text in every spreadsheet. */
    fun date(millis: Long?, zone: ZoneId = ZoneId.systemDefault()): String {
        if (millis == null) return ""
        val day = LocalDate.ofInstant(Instant.ofEpochMilli(millis), zone)
        return String.format(
            Locale.ROOT, "%04d-%02d-%02d", day.year, day.monthValue, day.dayOfMonth
        )
    }

    fun flag(value: Boolean): String = if (value) "yes" else ""
}
