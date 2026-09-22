package com.talastack.liquorlog.engine

import kotlin.math.roundToInt

/**
 * Turns somebody's spreadsheet into bottles.
 *
 * Spreadsheets are the incumbent -- *"the actual market leader"* in the
 * research's own words -- and the people this app most wants are the ones
 * with two hundred rows already typed into one. *"So I have 200+ bottles,
 * and zero interest in manually adding each one."* Whiskey Shelf converts
 * paying users by migrating them off other apps; this does the same from the
 * tool people actually use, and does it for free, because charging at the
 * moment somebody hands you their whole collection is charging at the exact
 * point you most want them to succeed.
 *
 * Two shapes are handled. **Our own export**, which round-trips exactly. And
 * **anybody's spreadsheet**, by recognising column names -- "Bottle",
 * "Whiskey", "Name" are all the name; "Proof" and "ABV" are both the
 * strength; "Paid", "Price" and "Cost" are what it cost. Nothing has to be
 * renamed before import.
 *
 * **This plans; it does not write.** It returns what it would create and what
 * it would skip, so a screen can show the plan before a single row lands. An
 * import that silently produced 40 untitled bottles from a misaligned column
 * would be worse than no import, and nobody would find out until they
 * searched for something.
 */
object CollectionImport {

    /** One bottle, as the spreadsheet described it. */
    data class Row(
        val name: String,
        val proof: Double? = null,
        val volumeMilliliters: Double? = null,
        val paidCents: Int? = null,
        val store: String? = null,
        val batch: String? = null,
        val barrel: String? = null,
        val storageLocation: String? = null,
        val isOpen: Boolean = false,
        val isFinished: Boolean = false,
        /**
         * A "sample" column: "yes" marks a sample, any other text marks a
         * sample AND names who it came from.
         */
        val isSample: Boolean = false,
        val sampleFrom: String? = null,
        val note: String? = null,
        /** Where it came from in the file, for a "row 14 was skipped" message. */
        val line: Int
    )

    data class Plan(
        val rows: List<Row>,
        /** Line numbers with no usable name. Reported, never guessed. */
        val skippedLines: List<Int>,
        /**
         * Which spreadsheet column was read as which field, so the screen can
         * say "reading 'Whiskey' as the name" and somebody can catch a wrong
         * guess before it lands.
         */
        val mapping: Map<Field, String>
    ) {
        val isEmpty: Boolean get() = rows.isEmpty()
    }

    enum class Field(val storageKey: String) {
        NAME("name"),
        PROOF("proof"),
        ABV("abv"),
        VOLUME("volume"),
        PAID("paid"),
        STORE("store"),
        BATCH("batch"),
        BARREL("barrel"),
        LOCATION("location"),
        STATUS("status"),
        SAMPLE("sample"),
        NOTE("note")
    }

    /**
     * Header names that mean each field, lowercase. The first match wins, so
     * the most specific spellings come first.
     */
    internal val synonyms: Map<Field, List<String>> = mapOf(
        Field.NAME to listOf(
            "name", "bottle", "bottle name", "whiskey", "whisky", "bourbon",
            "product", "expression", "label", "spirit"
        ),
        Field.PROOF to listOf("proof"),
        Field.ABV to listOf("abv", "abv %", "alcohol", "strength", "%"),
        Field.VOLUME to listOf("size_ml", "size", "volume", "ml", "size (ml)", "bottle size"),
        Field.PAID to listOf("price", "paid", "cost", "purchase price", "purchase_price", "$"),
        Field.STORE to listOf(
            "bought_at", "store", "bought at", "shop", "retailer", "place of purchase",
            "purchased at", "where"
        ),
        Field.BATCH to listOf("batch", "batch number", "batch #", "batch_number"),
        Field.BARREL to listOf("barrel", "barrel number", "barrel #", "barrel_number", "cask"),
        Field.LOCATION to listOf("storage_location", "location", "storage", "shelf", "where kept"),
        Field.STATUS to listOf("status", "state", "opened", "open"),
        Field.SAMPLE to listOf("sample_from", "sample from", "is_sample", "sample"),
        Field.NOTE to listOf("notes", "note", "comments", "comment", "review", "liked")
    )

    private val finishedWords = listOf("killed", "finished", "empty", "dead", "gone")
    private val openWords = listOf("open", "opened", "yes", "y", "true")
    private val notSampleWords = listOf("no", "n", "false", "0")
    private val plainSampleWords = listOf("yes", "y", "true", "1", "sample")

    /** Reads a whole file into a plan. */
    fun plan(csv: String): Plan {
        val (header, records) = CSVReader.records(csv)
        val mapping = map(header)

        val nameColumn = mapping[Field.NAME]
            // No name column at all: nothing can be imported and the plan says
            // so with every line skipped rather than inventing a name from the
            // first column.
            ?: return Plan(
                rows = emptyList(),
                skippedLines = records.indices.map { it + 2 },
                mapping = mapping
            )

        val rows = mutableListOf<Row>()
        val skipped = mutableListOf<Int>()

        for ((index, record) in records.withIndex()) {
            val line = index + 2 // 1-based, after the header
            val name = (record[nameColumn] ?: "").trimSpaces()
            if (name.isEmpty()) {
                skipped.add(line)
                continue
            }

            fun get(field: Field): String? {
                val column = mapping[field] ?: return null
                val value = record[column] ?: return null
                return if (value.isEmpty()) null else value
            }

            // Proof wins over ABV when both exist, for the same reason it does
            // on a label: it is the number people wrote down.
            var proof = number(get(Field.PROOF))
            if (proof == null) {
                val abv = number(get(Field.ABV))
                if (abv != null) proof = if (abv <= 95) ABV(abv).proof else null
            }

            val status = (get(Field.STATUS) ?: "").lowercase()
            val isFinished = finishedWords.any { status.contains(it) }
            val isOpen = !isFinished &&
                openWords.any { status == it || status.startsWith(it) }

            // "yes" alone is a sample from nobody in particular; a name is a
            // sample from that person. "no" and blank are bottles.
            val sampleText = (get(Field.SAMPLE) ?: "").trimSpaces()
            val sampleWord = sampleText.lowercase()
            val isSample = sampleText.isNotEmpty() && sampleWord !in notSampleWords
            val sampleFrom =
                if (isSample && sampleWord !in plainSampleWords) sampleText else null

            rows.add(
                Row(
                    name = name,
                    proof = proof,
                    volumeMilliliters = number(get(Field.VOLUME))
                        ?.let { if (it < 10) it * 1000 else it },
                    paidCents = number(get(Field.PAID))?.let { (it * 100).roundToInt() },
                    store = get(Field.STORE),
                    batch = get(Field.BATCH),
                    barrel = get(Field.BARREL),
                    storageLocation = get(Field.LOCATION),
                    isOpen = isOpen,
                    isFinished = isFinished,
                    isSample = isSample,
                    sampleFrom = sampleFrom,
                    note = get(Field.NOTE),
                    line = line
                )
            )
        }

        return Plan(rows = rows, skippedLines = skipped, mapping = mapping)
    }

    /**
     * Matches header names to fields.
     *
     * Exact match first, then a header that CONTAINS a synonym -- so
     * "Purchase Price ($)" still reads as paid. Each spreadsheet column is
     * claimed by at most one field.
     */
    internal fun map(header: List<String>): Map<Field, String> {
        val mapping = LinkedHashMap<Field, String>()
        val claimed = mutableSetOf<String>()

        for (field in Field.entries) {
            val candidates = synonyms[field] ?: emptyList()
            val exact = header.firstOrNull { it in candidates && it !in claimed }
            if (exact != null) {
                mapping[field] = exact
                claimed.add(exact)
                continue
            }
            val partial = header.firstOrNull { column ->
                column !in claimed && candidates.any { column.contains(it) }
            }
            if (partial != null) {
                mapping[field] = partial
                claimed.add(partial)
            }
        }
        return mapping
    }

    /**
     * "$79.99", "79.99", "80", "750ml" all become a number. Null for anything
     * that is not one.
     */
    internal fun number(text: String?): Double? {
        if (text == null) return null
        val cleaned = text.filter { it.isDigit() || it == '.' }
        if (cleaned.isEmpty()) return null
        val value = cleaned.toDoubleOrNull() ?: return null
        return if (value > 0) value else null
    }

    /** Spaces and tabs, as Swift's `.whitespaces` trims; not line breaks. */
    private fun String.trimSpaces(): String =
        trim { it.isWhitespace() && it != '\n' && it != '\r' }
}
