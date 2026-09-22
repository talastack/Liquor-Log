package com.talastack.liquorlog.engine

/**
 * Who really makes a tequila: the NOM on the label, looked up in the
 * CRT's own registry.
 *
 * Every bottle of tequila carries a four-digit NOM naming the distillery
 * that produced it, and the Consejo Regulador del Tequila publishes the
 * registry of authorised producers with the brands registered to each.
 * That is the agave world's DSP, and it answers the two questions
 * collectors ask: *who makes this brand*, and *what else comes out of
 * that plant* -- the store's own-label tequila and a premium one sharing
 * a still is the kind of fact the registry makes plain.
 *
 * The data is the CRT's, rebuilt by `scripts/build_tequila_registry.py`
 * from crt.org.mx and shipped as `tequila-nom.v1.json`. Names are as the
 * CRT lists them, in capitals; nothing is edited or added.
 *
 * **One thing the Swift type has that this one does not: reading the
 * file.** Swift gets JSONDecoder from Foundation for nothing; the JVM
 * does not, and this module keeps LiquorEngine's zero-dependency rule, so
 * parsing `tequila-nom.v1.json` belongs to the Android data layer, which
 * hands the rows here through the constructor. The lookups, the folding
 * and the ranking -- everything that could drift between the two engines
 * -- are all here.
 */
class TequilaRegistry(val producers: List<Producer>) {

    data class Producer(
        val nom: String,
        val company: String,
        val brands: List<String>
    ) {
        val id: String get() = nom
    }

    /** A brand that matched, and the plant it is registered to. */
    data class Match(val producer: Producer, val brand: String)

    private val byNOM: Map<String, Producer> = buildMap {
        // First wins on a duplicate NOM, as Swift's uniquingKeysWith does.
        for (producer in producers) if (!containsKey(producer.nom)) put(producer.nom, producer)
    }

    private data class BrandEntry(val folded: String, val brand: String, val producer: Producer)

    /**
     * Every brand, folded the way the rest of the app matches text --
     * lowercase, accents stripped, punctuation dropped -- so "el tequileno"
     * finds EL TEQUILENO and "trader joes" finds the CRT's own spelling
     * with its acute accent for an apostrophe.
     */
    private val brands: List<BrandEntry> = producers.flatMap { producer ->
        producer.brands.map { BrandEntry(it.normalizedForMatching(), it, producer) }
    }

    val isEmpty: Boolean get() = producers.isEmpty()

    fun producer(nom: String): Producer? = normalise(nom)?.let { byNOM[it] }

    /**
     * Producers with a brand matching the words typed. A brand that IS the
     * query comes first, then brands that start with it, then brands that
     * contain it; at most [limit]. Four characters before anything is
     * searched: three is the start of a Four Roses code, not a brand.
     */
    fun find(brand: String, limit: Int = 8): List<Match> {
        val query = brand.normalizedForMatching()
        if (query.length < 4) return emptyList()
        val exact = mutableListOf<Match>()
        val prefix = mutableListOf<Match>()
        val contains = mutableListOf<Match>()
        for (entry in brands) {
            when {
                entry.folded == query -> exact.add(Match(entry.producer, entry.brand))
                entry.folded.startsWith(query) -> prefix.add(Match(entry.producer, entry.brand))
                entry.folded.contains(query) -> contains.add(Match(entry.producer, entry.brand))
            }
        }
        return (exact + prefix + contains).take(limit)
    }

    /**
     * Only brands that are exactly the words typed -- for the case where
     * four digits are both a NOM and a registered brand name.
     */
    fun exact(brand: String): List<Match> {
        val query = brand.normalizedForMatching()
        if (query.isEmpty()) return emptyList()
        return brands.filter { it.folded == query }.map { Match(it.producer, it.brand) }
    }

    companion object {
        val empty = TequilaRegistry(emptyList())

        /**
         * "NOM 1139", "nom-1139", "1139" -> "1139". Null for anything that
         * is not four digits.
         */
        fun normalise(raw: String): String? {
            val upper = raw.uppercase()
            val digits = upper.replace("NOM", "").filter { it.isDigit() }
            if (digits.length != 4) return null
            if (!upper.filter { it.isLetter() }.all { it in "NOM" }) return null
            return digits
        }
    }
}
