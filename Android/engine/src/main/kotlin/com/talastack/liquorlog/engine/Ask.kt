package com.talastack.liquorlog.engine

import kotlin.math.roundToInt

/**
 * Plain English in, one of the app's own actions or questions out.
 *
 * "log a pour of weller 12", "1 oz of the blanton's", "add a bottle of
 * eagle rare, paid 40 at total wine", "rate the stagg an 8", "what's open",
 * "how many wellers do I have". No model: a small grammar of the verbs the
 * app already has, plus the same bottle search the shelf check uses to find
 * what the sentence is about. It runs on every phone, offline, for nothing,
 * and it is testable anywhere.
 *
 * Where the phone has an on-device language model, the app can use it to
 * turn looser phrasing into these same commands and to write the answer as
 * prose. That layer is optional and additive; this one is the floor, and it
 * is also the safety: a command is always shown back before anything is
 * written, because "log a pour" against the wrong bottle is a mistake
 * somebody has to find and undo.
 *
 * Nothing here is called AI anywhere a person can see. The research is blunt
 * about marketed AI in this category; this is a text box that understands
 * you.
 */
object Ask {

    /** What the sentence is about, as the search found it. */
    data class Subject(
        /**
         * The words the person used for the bottle, after the verb and the
         * numbers were taken out.
         */
        val text: String,
        /** Catalogue or custom products those words matched, best first. */
        val matches: List<SearchHit>
    ) {
        val best: ProductIdentity? get() = matches.firstOrNull()?.product

        val isAmbiguous: Boolean
            get() {
                if (matches.size < 2) return false
                return matches[0].score - matches[1].score < 0.1
            }
    }

    sealed class Command {
        data class Pour(val subject: Subject, val milliliters: Double?) : Command()
        data class Open(val subject: Subject) : Command()
        data class Finish(val subject: Subject) : Command()
        data class SetLevel(val subject: Subject, val percent: Double) : Command()
        data class Rate(val subject: Subject, val rating: Int) : Command()
        data class AddBottle(
            val subject: Subject, val paidCents: Int?, val store: String?
        ) : Command()
        data class Wishlist(val subject: Subject, val ceilingCents: Int?) : Command()
        data class Note(val subject: Subject, val body: String) : Command()

        /**
         * "saw blanton's at total wine for $75, 3 on the shelf" -- a sighting
         * for the hunt log.
         */
        data class Saw(
            val subject: Subject, val cents: Int?, val store: String?, val count: Int?
        ) : Command()

        /** "entered the stagg lottery at virginia abc". */
        data class Entered(val subject: Subject, val runner: String?) : Command()

        /**
         * "visited buffalo trace" -- a stamp in the passport. The place is a
         * name, not a product, so it is carried as typed.
         */
        data class Visited(val place: String) : Command()
    }

    sealed class Question {
        data object WhatIsOpen : Question()
        data class HowMany(val subject: Subject?) : Question()
        data class DoIHave(val subject: Subject) : Question()
        data class LastPoured(val subject: Subject) : Question()
        data class WhatDidIThink(val subject: Subject) : Question()
        data class WhatDidIPay(val subject: Subject) : Question()
        data class WhereIs(val subject: Subject) : Question()
        data object WhatIsOnMyWishlist : Question()
        data object NearlyGone : Question()

        /** "where did i see blanton's" -- from the hunt log. */
        data class WhereDidISee(val subject: Subject) : Question()

        /** "what did mike send me" -- from the samples and pours. */
        data class WhatCameFrom(val person: String) : Question()

        /** "have i been to buffalo trace" -- from the passport. */
        data class HaveIBeenTo(val place: String) : Question()
    }

    sealed class Understanding {
        data class AsCommand(val command: Command) : Understanding()
        data class AsQuestion(val question: Question) : Understanding()

        /**
         * The sentence was not one the grammar knows. The text is returned so
         * a model, when there is one, can try.
         */
        data class Unknown(val text: String) : Understanding()
    }

    // MARK: - Parsing

    fun understand(raw: String, catalog: List<SearchCandidate>): Understanding {
        val text = raw.trim()
        if (text.isEmpty()) return Understanding.Unknown(text)
        val lower = text.lowercase()

        question(lower, catalog)?.let { return Understanding.AsQuestion(it) }
        command(lower, text, catalog)?.let { return Understanding.AsCommand(it) }
        return Understanding.Unknown(text)
    }

    internal fun question(s: String, catalog: List<SearchCandidate>): Question? {
        if (matches(
                s,
                listOf(
                    "what's open", "whats open", "what is open",
                    "which bottles are open", "open bottles"
                )
            )
        ) {
            return Question.WhatIsOpen
        }
        // A question about the list, not a request to put something on it:
        // "what's on my wishlist", "show my wishlist". ("list" alone would
        // match inside "wishlist" and turn every add into a question.)
        if (matches(s, listOf("wishlist", "wish list")) &&
            (s.startsWith("what") || s.startsWith("show") || s.startsWith("list "))
        ) {
            return Question.WhatIsOnMyWishlist
        }
        if (matches(
                s,
                listOf("nearly gone", "almost empty", "running low", "almost gone", "nearly empty")
            )
        ) {
            return Question.NearlyGone
        }
        after(s, listOf("what did i pay for", "how much did i pay for", "what did i spend on"))
            ?.let { return Question.WhatDidIPay(subject(strip(it, listOf("the", "my", "a")), catalog)) }

        after(s, listOf("how many", "how much"))?.let { rest ->
            val stripped = strip(
                rest,
                listOf(
                    "bottles", "bottle", "of", "do i have", "do i own", "have i got",
                    "are there", "have i"
                )
            )
            if (stripped.isEmpty()) return Question.HowMany(null)
            return Question.HowMany(subject(stripped, catalog))
        }

        after(s, listOf("do i have", "do i own", "have i got", "do i already have"))?.let {
            return Question.DoIHave(
                subject(strip(it, listOf("any", "a", "an", "bottle of", "some")), catalog)
            )
        }

        after(
            s,
            listOf(
                "when did i last pour", "when did i last have", "last poured",
                "when did i last drink"
            )
        )?.let {
            return Question.LastPoured(
                subject(strip(it, listOf("the", "from", "my", "a")), catalog)
            )
        }

        after(
            s,
            listOf(
                "what did i think of", "what did i say about", "how did i rate",
                "my rating for", "what did i rate"
            )
        )?.let {
            return Question.WhatDidIThink(subject(strip(it, listOf("the", "my")), catalog))
        }

        after(
            s,
            listOf(
                "have i been to", "have i visited", "when did i visit", "when was i at",
                "have i ever been to"
            )
        )?.let { rest ->
            val place = strip(rest, listOf("the", "distillery")).trim { it in "?.! " }
            if (place.isNotEmpty()) return Question.HaveIBeenTo(place)
        }

        after(
            s,
            listOf(
                "where did i see", "where have i seen", "where did i last see",
                "where can i find", "who has", "who had", "who sells"
            )
        )?.let {
            return Question.WhereDidISee(
                subject(
                    strip(it, listOf("the", "my", "a", "any", "in stock", "for sale")), catalog
                )
            )
        }

        after(s, listOf("where is", "where's", "where did i put", "where do i keep"))?.let {
            return Question.WhereIs(subject(strip(it, listOf("the", "my")), catalog))
        }

        // "what did mike send me", "what has sarah sent", "samples from mike".
        val person = capture(
            s, """^what (?:did|has|have) (.+?) (?:send|sent|give|given|pour)(?: me)?\??$"""
        ) ?: capture(s, """^(?:samples|what came|what did i get) from (.+?)\??$""")
        if (person != null) {
            val name = person.trim()
            // "what did i pour" is not about a person; leave it unknown so
            // nothing answers as if "I" were a friend.
            if (name !in listOf("i", "you", "we", "they")) {
                return Question.WhatCameFrom(name)
            }
        }
        return null
    }

    internal fun command(
        s: String,
        original: String,
        catalog: List<SearchCandidate>
    ): Command? {
        // "1 oz of the blanton's", "30 ml of stagg": the quantity leads.
        capture(s, """^\d+(?:\.\d+)?\s*(?:oz|ounces?|ml)\s+(?:of\s+)?(.+)$""")?.let { leading ->
            val words = strip(leading, listOf("the", "my", "a"))
            return Command.Pour(subject(words, catalog), milliliters(s))
        }

        // "note on X: body" -- the body is kept as typed.
        after(s, listOf("note on", "note about", "add a note to", "remember that"))?.let { rest ->
            val parts = rest.split(":", limit = 2).map { it.trim() }
            if (parts.size == 2) {
                val colon = original.indexOf(':')
                val body = if (colon >= 0) original.substring(colon + 1).trim() else parts[1]
                return Command.Note(
                    subject(strip(parts[0], listOf("the", "my")), catalog), body
                )
            }
        }

        // "visited buffalo trace", "went to four roses today": the passport.
        // The place keeps the casing it was typed with.
        after(
            s,
            listOf(
                "visited the", "visited", "went to the", "went to", "toured the", "toured",
                "was at the", "was at"
            )
        )?.let { rest ->
            val lowerPlace = strip(
                rest, listOf("distillery", "today", "yesterday", "this weekend", "last week")
            ).trim { it in ".!, " }
            if (lowerPlace.isEmpty()) return null
            val at = original.indexOf(lowerPlace, ignoreCase = true)
            val place = if (at >= 0) original.substring(at, at + lowerPlace.length) else lowerPlace
            return Command.Visited(place)
        }

        // "saw blanton's at total wine for $75, 3 on the shelf": the hunt log.
        after(
            s,
            listOf(
                "saw a", "saw the", "saw", "spotted a", "spotted the", "spotted", "seen",
                "found a", "found the", "found"
            )
        )?.let { rest ->
            val count = capture(rest, COUNT_PATTERN)?.toIntOrNull()
            val withoutCount = Regex(COUNT_PATTERN).replace(rest, " ")
            val words = strip(
                removeStore(removeQuantities(withoutCount)),
                listOf(
                    "the", "my", "a", "bottle of", "bottle", "bottles", "some", "for", "at",
                    "from", "of", "them", "on", "shelf", "in stock", "it"
                )
            )
            if (words.isEmpty()) return null
            return Command.Saw(
                subject(words, catalog), money(rest), storeName(original), count
            )
        }

        after(
            s,
            listOf(
                "entered the", "entered a", "entered", "put in for the", "put in for",
                "put my name in for the", "put my name in for"
            )
        )?.let { rest ->
            val words = strip(
                removeStore(removeQuantities(rest)),
                listOf(
                    "the", "my", "a", "lottery", "raffle", "drawing", "draw", "for", "at",
                    "from", "of", "it"
                )
            )
            if (words.isEmpty()) return null
            return Command.Entered(subject(words, catalog), storeName(original))
        }

        after(
            s,
            listOf(
                "log a pour of", "log a pour from", "pour of", "poured", "pour", "log",
                "had a pour of", "had a glass of", "drank", "had some"
            )
        )?.let { rest ->
            val words = strip(
                removeQuantities(rest),
                listOf("the", "my", "a", "of", "from", "some", "glass", "dram", "pour")
            )
            if (words.isEmpty()) return null
            return Command.Pour(subject(words, catalog), milliliters(rest))
        }

        after(
            s,
            listOf(
                "open the", "opened the", "open my", "opened my", "open a", "opened a",
                "open", "opened", "crack open", "cracked open"
            )
        )?.let { rest ->
            val words = strip(rest, listOf("the", "my", "a", "bottle of"))
            if (words.isEmpty()) return null
            return Command.Open(subject(words, catalog))
        }

        after(
            s,
            listOf(
                "finished the", "finished my", "killed the", "killed my", "finish the",
                "finish", "finished", "killed", "kill"
            )
        )?.let { rest ->
            val words = strip(rest, listOf("the", "my", "a", "bottle of", "off"))
            if (words.isEmpty()) return null
            return Command.Finish(subject(words, catalog))
        }

        after(s, listOf("set the", "set my", "set"))?.let { rest ->
            val percent = percent(rest)
            if (percent != null && matches(
                    rest,
                    listOf(
                        "level", "fill", "left", "full", "%", "percent", "half", "quarter",
                        "third", "empty"
                    )
                )
            ) {
                val words = strip(
                    removeQuantities(rest),
                    listOf(
                        "the", "my", "level", "fill", "to", "at", "left", "full", "of", "is",
                        "about", "percent", "half", "a third", "one third", "third",
                        "quarter", "empty"
                    )
                )
                if (words.isEmpty()) return null
                return Command.SetLevel(subject(words, catalog), percent)
            }
        }

        after(s, listOf("rate the", "rate my", "rate", "give the", "give"))?.let { rest ->
            val rating = rating(rest)
            if (rating != null) {
                val withoutRating = removeLastSmallNumber(removeQuantities(rest))
                val words = strip(
                    withoutRating,
                    listOf(
                        "the", "my", "a", "an", "out of", "stars", "star", "points",
                        "rating", "of", "as"
                    )
                )
                if (words.isEmpty()) return null
                return Command.Rate(subject(words, catalog), rating)
            }
        }

        after(
            s,
            listOf(
                "add a bottle of", "add bottle of", "add a", "add", "bought a bottle of",
                "bought a", "bought", "got a", "picked up a", "picked up"
            )
        )?.let { rest ->
            if (matches(rest, listOf("wishlist", "wish list"))) {
                val words = strip(
                    removeQuantities(rest),
                    listOf(
                        "to my wishlist", "to the wishlist", "to wishlist", "on my wishlist",
                        "wishlist", "wish list", "to my", "the", "my", "a", "bottle of",
                        "under", "up to", "for", "at"
                    )
                )
                if (words.isEmpty()) return null
                return Command.Wishlist(subject(words, catalog), money(rest))
            }
            val words = strip(
                removeStore(removeQuantities(rest)),
                listOf(
                    "the", "my", "a", "bottle of", "bottle", "paid", "for", "at", "from",
                    "i", "it"
                )
            )
            if (words.isEmpty()) return null
            return Command.AddBottle(subject(words, catalog), money(rest), storeName(original))
        }

        after(
            s,
            listOf(
                "wishlist the", "wishlist", "want a", "want the", "want",
                "i'm looking for", "looking for", "put"
            )
        )?.let { rest ->
            val words = strip(
                removeQuantities(rest),
                listOf(
                    "on my wishlist", "on the wishlist", "on wishlist", "to my wishlist",
                    "wishlist", "the", "my", "a", "bottle of", "some", "for", "up to", "under"
                )
            )
            if (words.isEmpty()) return null
            return Command.Wishlist(subject(words, catalog), money(rest))
        }

        return null
    }

    // MARK: - Pieces

    internal fun subject(words: String, catalog: List<SearchCandidate>): Subject {
        val cleaned = words.trim().trim { it in ",.!?" }
        var hits = BottleSearch.search(cleaned, catalog, 5)
        // "how many wellers": a plural the search does not know. Once, on the
        // words that end in s, before giving up.
        if (hits.isEmpty()) {
            val singular = cleaned.split(" ")
                .joinToString(" ") {
                    if (it.length > 3 && it.endsWith("s")) it.dropLast(1) else it
                }
            if (singular != cleaned) {
                hits = BottleSearch.search(singular, catalog, 5)
            }
        }
        return Subject(text = cleaned, matches = hits)
    }

    internal fun matches(s: String, phrases: List<String>): Boolean = phrases.any { s.contains(it) }

    /**
     * The text after the first of [prefixes] that starts the sentence, once a
     * leading "please" / "can you" / "hey" is dropped.
     */
    internal fun after(s: String, prefixes: List<String>): String? {
        var text = s
        for (lead in listOf("please ", "can you ", "could you ", "hey ", "ok ", "okay ", "i ")) {
            if (text.startsWith(lead)) text = text.substring(lead.length)
        }
        // Longest prefix first, so "log a pour of" wins over "log".
        for (prefix in prefixes.sortedByDescending { it.length }) {
            if (text.startsWith("$prefix ")) {
                return text.substring(prefix.length).trim()
            }
            if (text == prefix) return ""
        }
        return null
    }

    /** Removes whole-word filler. "the weller 12" -> "weller 12". */
    internal fun strip(s: String, fillers: List<String>): String {
        val words = s.split(" ").filter { it.isNotEmpty() }.toMutableList()
        for (filler in fillers.sortedByDescending { it.length }) {
            val parts = filler.split(" ").filter { it.isNotEmpty() }
            if (parts.isEmpty()) continue
            var index = 0
            while (index + parts.size <= words.size) {
                if (words.subList(index, index + parts.size) == parts) {
                    repeat(parts.size) { words.removeAt(index) }
                } else {
                    index += 1
                }
            }
        }
        return words.joinToString(" ").trim()
    }

    /**
     * A number WITH a unit, or a dollar amount, or "paid N". A bare number is
     * left alone: "weller 12" and "eagle rare 10" are names, and a parser that
     * ate the 12 would log a pour of the wrong Weller.
     */
    internal const val QUANTITY_PATTERN =
        """(?:\$\s*\d+(?:\.\d+)?|\d+(?:\.\d+)?\s*(?:oz|ounces?|ml|%|percent|dollars?|bucks|/\s*10|out of 10)\b|paid\s+\$?\d+(?:\.\d+)?)"""

    private const val COUNT_PATTERN =
        """\b(\d+)\s+(?:on the shelf|on the shelves|left|bottles?|of them)\b"""

    private val quantityRegex = Regex(QUANTITY_PATTERN)
    private val smallNumberRegex = Regex("""\b(10|[1-9])\b""")
    private val storeTailRegex = Regex("""\s+(at|from)\s+.*$""")
    private val leadingTheRegex = Regex("""^the\s+""", RegexOption.IGNORE_CASE)
    private val trailingForRegex = Regex("""\s+(for|paid)\b.*$""", RegexOption.IGNORE_CASE)

    internal fun removeQuantities(s: String): String =
        quantityRegex.replace(s, " ").replace("  ", " ").trim()

    internal fun capture(s: String, pattern: String): String? =
        Regex(pattern).find(s)?.groups?.get(1)?.value

    private fun number(s: String, unitPattern: String): Double? =
        capture(s, """(\d+(?:\.\d+)?)\s*""" + unitPattern)?.toDoubleOrNull()

    internal fun milliliters(s: String): Double? {
        number(s, """(?:oz|ounces?)\b""")?.let { return PourSize.fromOunces(it).milliliters }
        number(s, """ml\b""")?.let { return it }
        return null
    }

    internal fun percent(s: String): Double? {
        number(s, """(?:%|percent)""")?.let { return it }
        if (s.contains("half")) return 50.0
        if (s.contains("a third") || s.contains("one third")) return 33.0
        if (s.contains("quarter")) return 25.0
        if (s.contains("empty")) return 0.0
        if (s.contains("full")) return 100.0
        return null
    }

    /**
     * "the stagg an 8" -> "the stagg an". Only the LAST bare 1-10, which is
     * the rating; the 10 in "eagle rare 10 an 8" stays where it is.
     */
    internal fun removeLastSmallNumber(s: String): String {
        val last = smallNumberRegex.findAll(s).lastOrNull() ?: return s
        val out = s.removeRange(last.range)
        return out.replace("  ", " ").trim()
    }

    internal fun rating(s: String): Int? {
        number(s, """(?:/\s*10|out of 10)""")?.let { return it.toInt() }
        val values = smallNumberRegex.findAll(s).mapNotNull { it.groupValues[1].toIntOrNull() }
        return values.lastOrNull()
    }

    /** "$40", "40 dollars", "paid 40". Cents. */
    internal fun money(s: String): Int? {
        for (pattern in listOf(
            """\$\s*(\d+(?:\.\d{1,2})?)""",
            """(\d+(?:\.\d{1,2})?)\s*(?:dollars?|bucks)\b""",
            """paid\s+(\d+(?:\.\d{1,2})?)"""
        )) {
            val value = capture(s, pattern)?.toDoubleOrNull()
            if (value != null) return (value * 100).roundToInt()
        }
        return null
    }

    /**
     * "at Total Wine", "from the ABC store" -- the words after at/from, in
     * the original casing, up to a comma or a money word.
     */
    internal fun storeName(original: String): String? {
        val lower = original.lowercase()
        for (marker in listOf(" at ", " from ")) {
            val index = lower.indexOf(marker)
            if (index < 0) continue
            val tail = original.substring(index + marker.length)
            val store = tail.split(',', '.').firstOrNull { it.isNotEmpty() }?.trim() ?: ""
            val cleaned = store
                .replace(leadingTheRegex, "")
                .replace(trailingForRegex, "")
                .trim()
            if (cleaned.isNotEmpty()) return cleaned
        }
        return null
    }

    internal fun removeStore(s: String): String = storeTailRegex.replace(s, "")
}
