package com.talastack.liquorlog.engine

/**
 * Turns the text on a bottle label into fields.
 *
 * **This is where the work is.** Getting characters off a label is Apple's
 * Vision framework on iOS and ML Kit's on-device recogniser here -- both free,
 * offline and without an API key. Turning
 *
 * ```
 * ELIJAH CRAIG / KENTUCKY STRAIGHT BOURBON WHISKEY
 * BARREL PROOF / BATCH B523 / 124.2 PROOF / 750 ML
 * ```
 *
 * into a proof, a batch code and a catalogue match is the part that decides
 * whether the feature is worth using, and it needs no model at all.
 *
 * **No AI, and that is a design decision rather than a limitation.** A cloud
 * model is a paid dependency and breaks the offline promise, both of which
 * were ruled out on day one. And the research is pointed about the value: one
 * developer built AI label recognition and *removed it before launch* because
 * *"the photo recognition flow felt slower and didn't really add much benefit
 * compared to just adding bottles manually."* Regular expressions over
 * recognised text are faster than a model, run everywhere, and cannot
 * hallucinate a proof that is not on the bottle.
 *
 * **Everything here is a SUGGESTION.** Nothing is written without somebody
 * confirming it. A misread proof that silently becomes a bottle's strength
 * would poison the cost-per-pour, the perceived-proof verdict and the shelf
 * check at once -- and unlike a typo, nobody would know they had made it.
 */
object LabelReader {

    /**
     * What was found, with the lines it came from so a screen can show its
     * working. Every field is optional because most labels carry few of them.
     */
    data class Reading(
        val proof: Double? = null,
        val abv: Double? = null,
        val volumeMilliliters: Double? = null,
        val batchCode: String? = null,
        val barrelNumber: String? = null,
        val recipeCode: String? = null,
        val statedAgeYears: Int? = null,
        /** A Buffalo Trace laser code, when the photo caught the etching. */
        val laserCode: LaserCode? = null,
        /** The DSP permit number, normalised, when the back label was read. */
        val dsp: String? = null,
        val isBottledInBond: Boolean = false,
        val isSingleBarrel: Boolean = false,
        val isSmallBatch: Boolean = false,
        /**
         * Lines left over once the recognised facts are removed -- the name,
         * most of the time, and what gets matched against the catalogue.
         */
        val nameCandidate: String = ""
    ) {
        val isEmpty: Boolean
            get() = proof == null && abv == null && volumeMilliliters == null &&
                batchCode == null && barrelNumber == null && recipeCode == null &&
                statedAgeYears == null && nameCandidate.isEmpty()
    }

    // MARK: - Patterns
    //
    // Anchored to the words that actually appear on American whiskey labels.
    // Each is deliberately narrow: a pattern that matches too much puts a wrong
    // number in a field somebody will not check.

    /**
     * "124.2 PROOF" or "PROOF 124.2". Not a bare number: labels are covered in
     * numbers and most of them are not the proof.
     */
    internal val proofPattern =
        Regex("""(?:(\d{2,3}(?:\.\d)?)\s*(?:°|)\s*PROOF|PROOF\s*[:\-]?\s*(\d{2,3}(?:\.\d)?))""")

    /**
     * "62.1% ALC/VOL", "ALC 62.1% BY VOL", "62.1% ABV". A percentage that
     * names alcohol. This one is believed outright.
     */
    internal val abvPattern = Regex("""(\d{1,2}(?:\.\d{1,2})?)\s*%\s*(?:ALC|ABV|ALCOHOL)""")

    /**
     * Any percentage at all. Mashbill shares look exactly like this, so a bare
     * one is only believed when nothing named alcohol was found and the number
     * is in spirits range -- "1% MALTED BARLEY" is never 1% ABV.
     */
    internal val barePercentPattern = Regex("""(\d{1,2}(?:\.\d{1,2})?)\s*%""")

    internal val volumePattern = Regex("""(\d{3,4})\s*(?:ML|MILLILIT)""")
    internal val litrePattern = Regex("""(\d(?:\.\d{1,2})?)\s*(?:L|LITER|LITRE)\b""")

    /**
     * Elijah Craig and Larceny batch codes: a letter, then digits. "B523",
     * "A125", "C923".
     */
    internal val batchPattern = Regex("""\bBATCH\s*[:\-]?\s*([A-Z]\d{3})\b""")

    /** "BARREL NO. 42-3C", "BARREL 421". */
    internal val barrelPattern = Regex("""\bBARREL\s*(?:NO\.?|#)?\s*([A-Z0-9][A-Z0-9\-]{0,9})\b""")

    /** "AGED 9 YEARS", "12 YEARS OLD". */
    internal val agePattern = Regex("""(?:AGED\s+)?(\d{1,2})\s*YEARS?(?:\s+OLD)?""")

    private val wordBreak = Regex("""[^\p{IsAlphabetic}\p{IsDigit}]+""")
    private val nonLetters = Regex("""[^\p{IsAlphabetic}]+""")

    // MARK: - Reading

    /**
     * Parses recognised lines. Order is irrelevant -- the recogniser returns
     * them in whatever order it found them, which on a wrap-around label is
     * not reading order.
     */
    fun read(lines: List<String>): Reading {
        val upper = lines.map { it.uppercase() }
        val joined = upper.joinToString(" ")

        var proof = firstNumber(joined, proofPattern)
        // EVERY "%" on the label, not the first one. Labels print mashbill
        // shares too, and "99% CORN" above "45% ALC/VOL" would otherwise match
        // 99, get rejected as implausible, and lose the real strength.
        var abv = allNumbers(joined, abvPattern).firstOrNull { it > 0.5 && it <= 95 }
            ?: allNumbers(joined, barePercentPattern).firstOrNull { it >= 15 && it <= 95 }

        // Proof and ABV must agree, and the PROOF is believed when they do not.
        // It is printed larger, it is the number people read off a label, and
        // deriving one from the other is how a bottle ends up recorded at half
        // its strength.
        if (proof != null) {
            abv = ABV.fromProof(proof).percent
        } else if (abv != null) {
            proof = ABV(abv).proof
        }

        val volume = firstNumber(joined, volumePattern)
            ?: firstNumber(joined, litrePattern)?.let { it * 1000 }

        // A code has a letter on it -- the lot letter in front, or the line
        // letter behind. A bare run of digits on a label is a bottle number
        // and is never read as a date.
        val hasALetter = { code: LaserCode -> code.prefix != null || code.line != null }
        val laserCode = upper.mapNotNull { LaserCode.parse(it) }.firstOrNull(hasALetter)
            ?: upper.flatMap { it.split(" ") }
                .mapNotNull { LaserCode.parse(it) }
                .firstOrNull(hasALetter)

        // A Four Roses code is four letters with a fixed shape, so it is
        // recognised by validating against the ten real codes rather than by a
        // pattern that would also match any other four-letter word.
        val recipeCode = upper
            .flatMap { it.split(nonLetters) }
            .filter { it.isNotEmpty() }
            .firstOrNull { RecipeCode.parse(it) != null }

        return Reading(
            proof = proof,
            abv = abv,
            volumeMilliliters = volume,
            batchCode = firstString(joined, batchPattern),
            barrelNumber = firstString(joined, barrelPattern),
            recipeCode = recipeCode,
            statedAgeYears = firstNumber(joined, agePattern)?.toInt(),
            laserCode = laserCode,
            // The etching reads as its own line, "L19274 15:02 K", or as one
            // run of characters. Either way the decoder validates it as a
            // date, so a random five-digit number is not taken for one.
            dsp = DistilleryPermit.find(joined),
            isBottledInBond = joined.contains("BOTTLED IN BOND") || joined.contains("BONDED"),
            isSingleBarrel = joined.contains("SINGLE BARREL"),
            isSmallBatch = joined.contains("SMALL BATCH"),
            nameCandidate = nameLines(upper).joinToString(" ")
        )
    }

    /**
     * Lines that plausibly carry the name.
     *
     * Everything a label says about government warnings, volume and strength
     * is noise for matching, and leaving it in drags a search away from the
     * brand. The remaining lines are usually the name and the distillery.
     */
    internal fun nameLines(upper: List<String>): List<String> {
        val noise = listOf(
            "GOVERNMENT WARNING", "SURGEON GENERAL", "PREGNANCY", "MACHINERY",
            "DRINK RESPONSIBLY", "ALC", "VOL", "PROOF", "ML", "DISTILLED BY",
            "BOTTLED BY", "PRODUCT OF", "CONTAINS", "SULFITES",
            // The attribution line, never the brand line. Eagle Rare,
            // Blanton's and Weller all print "Buffalo Trace Distillery", and
            // keeping it puts "buffalo trace" into the reading -- so Buffalo
            // Trace's own bourbon counts as brand-present on a bottle that is
            // not it. Buffalo Trace's OWN front label says "BUFFALO TRACE"
            // without the word, so dropping it costs nothing there.
            "DISTILLERY", "DISTILLERIES"
        )
        return upper.filter { line ->
            val trimmed = line.trim { it.isWhitespace() && it != '\n' && it != '\r' }
            if (trimmed.length < 3) return@filter false
            // A line that is mostly digits is a code or a measure, not a name.
            val letters = trimmed.count { it.isLetter() }
            if (letters * 2 <= trimmed.length) return@filter false
            noise.none { trimmed.contains(it) }
        }
    }

    // MARK: - Matching

    /**
     * The catalogue rows a reading might be, best first.
     *
     * Returns SUGGESTIONS. Nothing is written without confirmation, because a
     * wrong match here attaches somebody's tasting notes to the wrong whiskey.
     */
    fun candidates(
        reading: Reading,
        catalog: List<SearchCandidate>,
        limit: Int = 5
    ): List<SearchHit> {
        val words = tokens(reading.nameCandidate).toSet()
        if (words.isEmpty()) return emptyList()

        // A label is a pile of words -- brand, class statement, age, town --
        // and the shop search's rule (every typed word must prefix a name
        // word) fails on it by design. So the direction is reversed: a product
        // is a candidate when ITS brand appears among the label's words, and
        // ranks by how much of its expression does too.
        val hits = mutableListOf<SearchHit>()
        for (candidate in catalog) {
            val product = candidate.product
            if (!brandIsPresent(product, words)) continue
            val expression = tokens(product.expression)
            val expressionShare = if (expression.isEmpty()) {
                0.5
            } else {
                val matched = expression.count { token ->
                    words.any { it.startsWith(token) || token.startsWith(it) }
                }
                matched.toDouble() / expression.size.toDouble()
            }
            val score = 0.6 + 0.4 * expressionShare + (if (candidate.isInYourHistory) 0.05 else 0.0)
            hits.add(
                SearchHit(
                    product = product,
                    score = score,
                    reason = if (expressionShare >= 0.999) {
                        SearchHit.Reason.EXACT
                    } else {
                        SearchHit.Reason.PREFIX
                    }
                )
            )
        }

        if (hits.isEmpty()) {
            // OCR mangled the brand. Fall back to the fuzzy search over the
            // words that survived, brand-first as before.
            val fuzzy = BottleSearch.search(reading.nameCandidate, catalog, limit * 2)
            return rankBrandFirst(fuzzy, reading.nameCandidate).take(limit)
        }

        return hits.sortedWith(
            compareByDescending<SearchHit> { it.score }.thenBy { it.product.displayName }
        ).take(limit)
    }

    /**
     * Products whose BRAND is on the label outrank ones matched only on the
     * distillery.
     *
     * Eagle Rare, Blanton's and Weller all print "Buffalo Trace Distillery" on
     * the label, so a search over the raw text matches every Buffalo Trace
     * product and ranks them by noise -- and Buffalo Trace's own bourbon can
     * beat the bottle actually being held. The brand is the thing printed
     * largest, and if its words are in the reading that is the answer.
     *
     * A stable partition, not a re-score: within each group the search's own
     * order is kept, so this cannot make a good match worse.
     */
    internal fun rankBrandFirst(hits: List<SearchHit>, text: String): List<SearchHit> {
        val words = tokens(text).toSet()
        val brandMatched = hits.filter { brandIsPresent(it.product, words) }
        val rest = hits.filter { !brandIsPresent(it.product, words) }
        return brandMatched + rest
    }

    internal fun brandIsPresent(product: ProductIdentity, words: Set<String>): Boolean {
        val brand = tokens(product.brand)
        if (brand.isEmpty()) return false
        return brand.all { it in words }
    }

    /** Lowercase alphanumeric words, so "Blanton's" and "BLANTONS" agree. */
    internal fun tokens(text: String): List<String> =
        text.lowercase()
            .replace("'", "")
            .split(wordBreak)
            .filter { it.length > 1 }

    // MARK: - Regex plumbing

    private fun firstMatch(text: String, pattern: Regex): List<String>? {
        val match = pattern.find(text) ?: return null
        val groups = match.groups.drop(1).filterNotNull().map { it.value }
        return if (groups.isEmpty()) null else groups
    }

    /**
     * Every capture from every match, in order. Needed wherever a label can
     * legitimately carry more than one number of the same shape.
     */
    internal fun allNumbers(text: String, pattern: Regex): List<Double> =
        pattern.findAll(text)
            .flatMap { match -> match.groups.drop(1).filterNotNull().asSequence() }
            .mapNotNull { it.value.toDoubleOrNull() }
            .toList()

    internal fun firstNumber(text: String, pattern: Regex): Double? =
        firstMatch(text, pattern)?.firstNotNullOfOrNull { it.toDoubleOrNull() }

    internal fun firstString(text: String, pattern: Regex): String? =
        firstMatch(text, pattern)?.firstOrNull { it.isNotEmpty() }
}
