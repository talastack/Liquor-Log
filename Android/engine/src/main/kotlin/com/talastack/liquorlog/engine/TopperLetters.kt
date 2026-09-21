package com.talastack.liquorlog.engine

/**
 * The letters on Blanton's cork toppers, and which of them a shelf has.
 *
 * From Blanton's own FAQ (https://www.blantonsbourbon.com/pages/faq, read
 * 15 September 2026): since 1999 the stoppers have come as a collector's
 * set of eight, a horse and jockey in the eight stages of a race, each
 * marked with a single letter that spells BLANTONS when the set is
 * complete. There are two different N's -- the second is followed by a
 * subtle colon, "N:" -- and no apostrophe stopper. All eight are made in
 * equal numbers and placed on bottles at random, so no letter is rarer
 * than another; a shelf's set is a fact about the shelf, not a score.
 *
 * It is also what bourbondumpdate.com records beside the dump date, which
 * is why the letter is stored per bottle.
 */
object TopperLetters {

    /**
     * The eight stoppers, in the order they spell the name. The second N
     * is its own stopper, written "N:" as Blanton's marks it.
     */
    val stoppers: List<String> = listOf("B", "L", "A", "N", "T", "O", "N:", "S")

    /** The word the set spells, for display. */
    const val word = "BLANTONS"

    /**
     * A stored letter, normalised: uppercased, "n2" or "n:" for the second
     * N, anything that is not one of the eight rejected. The apostrophe
     * people sometimes type is not a stopper and comes back null.
     */
    fun normalise(raw: String): String? {
        val trimmed = raw.trim().uppercase()
        return when (trimmed) {
            "B", "L", "A", "T", "O", "S" -> trimmed
            "N", "N1" -> "N"
            "N:", "N2", "N;", "N." -> "N:"
            else -> null
        }
    }

    data class Progress(
        /** Stoppers owned, with how many of each. */
        val owned: Map<String, Int>,
        val missing: List<String>
    ) {
        val isComplete: Boolean get() = missing.isEmpty()
        val ownedCount: Int get() = stoppers.size - missing.size

        /**
         * The word with the missing stoppers blanked, for a single line:
         * "B L A _ T O N: _".
         */
        val wordLine: String
            get() = stoppers.joinToString(" ") { if (owned[it] != null) it else "_" }
    }

    fun progress(letters: List<String>): Progress {
        val owned = mutableMapOf<String, Int>()
        for (raw in letters) {
            val stopper = normalise(raw) ?: continue
            owned[stopper] = (owned[stopper] ?: 0) + 1
        }
        val missing = stoppers.filter { owned[it] == null }
        return Progress(owned = owned, missing = missing)
    }
}
