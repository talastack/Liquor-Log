package com.talastack.liquorlog.engine

/**
 * Reads a CSV the way a spreadsheet wrote it.
 *
 * The inverse of [CSVWriter], and the reason it has to be a real parser
 * rather than a split on commas: the first thing anybody's spreadsheet
 * contains is a bottle called *"Elijah Craig Barrel Proof, Batch B523"*, and
 * a tasting note with a line break in it. Splitting on commas hands back a
 * collection where half the bottles are named `"B523"`.
 *
 * RFC 4180: a quoted field may contain commas, quotes (doubled) and newlines.
 * CRLF and LF both end a record. A trailing newline does not produce an empty
 * last row.
 */
object CSVReader {

    /** A header and the records under it, keyed by that header. */
    data class Records(val header: List<String>, val rows: List<Map<String, String>>)

    /**
     * Rows of fields. The first row is whatever the file said it was -- the
     * caller decides whether that is a header.
     */
    fun rows(text: String): List<List<String>> {
        val rows = mutableListOf<List<String>>()
        var row = mutableListOf<String>()
        val field = StringBuilder()
        var inQuotes = false
        var i = 0

        while (i < text.length) {
            val character = text[i]

            if (inQuotes) {
                if (character == '"') {
                    // A doubled quote inside a quoted field is a literal
                    // quote. Anything else after a quote ends the field.
                    if (i + 1 < text.length && text[i + 1] == '"') {
                        field.append('"')
                        i += 2
                    } else {
                        inQuotes = false
                        i += 1
                    }
                } else {
                    field.append(character)
                    i += 1
                }
                continue
            }

            when (character) {
                '"' -> {
                    inQuotes = true
                    i += 1
                }
                ',' -> {
                    row.add(field.toString())
                    field.setLength(0)
                    i += 1
                }
                // All three spellings end a record. Swift gets CRLF for free,
                // because it reads "\r\n" as one grapheme cluster; the JVM
                // reads two chars, so the pair is stepped over by hand. Miss
                // that and our own export -- which writes CRLF -- re-imports
                // with a blank row between every bottle.
                '\r', '\n' -> {
                    row.add(field.toString())
                    rows.add(row)
                    row = mutableListOf()
                    field.setLength(0)
                    i += if (character == '\r' && i + 1 < text.length && text[i + 1] == '\n') 2 else 1
                }
                else -> {
                    field.append(character)
                    i += 1
                }
            }
        }

        // The last record, unless the file ended cleanly on a newline.
        if (field.isNotEmpty() || row.isNotEmpty()) {
            row.add(field.toString())
            rows.add(row)
        }

        return rows
    }

    /**
     * Rows as maps keyed by the header, with the header normalised to
     * lowercase and trimmed so `"Bottle Name"` and `"bottle name "` agree.
     */
    fun records(text: String): Records {
        val all = rows(text)
        val first = all.firstOrNull() ?: return Records(emptyList(), emptyList())
        val header = first.map { normalise(it) }
        val body = all.drop(1).filter { row -> row.any { it.isNotEmpty() } }
        val records = body.map { row ->
            val record = mutableMapOf<String, String>()
            header.forEachIndexed { index, key ->
                if (index < row.size) record[key] = row[index].trimSpaces()
            }
            record
        }
        return Records(header, records)
    }

    internal fun normalise(header: String): String =
        header.trim()
            .lowercase()
            .replace("\uFEFF", "")   // Excel's BOM

    /**
     * Spaces and tabs, not line breaks: Swift trims a cell with
     * `.whitespaces`, and a line break inside a quoted tasting note is
     * content, not padding.
     */
    private fun String.trimSpaces(): String =
        trim { it.isWhitespace() && it != '\n' && it != '\r' }
}
