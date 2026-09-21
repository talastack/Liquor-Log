package com.talastack.liquorlog.engine

import java.util.Locale
import kotlin.math.roundToInt

/**
 * What your own tastings say about you.
 *
 * Not a personality, and not a recommendation engine: the words you reach
 * for most, and how you rate by class, by strength and by mashbill --
 * averages over your ratings, each shown with the count it rests on, and
 * nothing said until there are enough to say it. Three ratings a side is
 * the floor for a comparison; two is a coincidence.
 *
 * Everything here counts opinions, never drinks. A tasting is one opinion
 * however large the pour, and the profile does not move for tasting the same
 * bottle again except that the newer opinion counts too.
 */
object Palate {

    /** One tasting, reduced to what the profile needs. */
    data class Tasting(
        /**
         * The product, so a blind rating and a sighted one of the same
         * whiskey can be paired.
         */
        val productId: String? = null,
        /** Rated without knowing which bottle it was. */
        val isBlind: Boolean = false,
        val classType: ClassType? = null,
        val abv: Double? = null,
        /**
         * True for a wheated recipe, false for another bourbon recipe, null
         * when the product is not a bourbon or the recipe is unknown.
         */
        val isWheated: Boolean? = null,
        val rating: Int? = null,
        /** 1..5, how hot it drank. */
        val perceivedHeat: Int? = null,
        val finishSeconds: Int? = null,
        val wouldRebuy: Boolean? = null,
        /** Flavour-wheel keys picked on any stage. */
        val descriptors: List<String> = emptyList()
    )

    /** An average rating for a group, with the count it rests on. */
    data class Line(val label: String, val count: Int, val average: Double) {
        val id: String get() = label
        val averageText: String get() = String.format(Locale.ROOT, "%.1f", average)
    }

    data class Word(val key: String, val count: Int) {
        val id: String get() = key
    }

    data class Profile(
        val tastings: Int,
        val rated: Int,
        /** Most used first; ties alphabetical. */
        val words: List<Word>,
        /** Classes with at least [minimum] ratings, highest average first. */
        val byClass: List<Line>,
        /** Strength bands with at least [minimum] ratings, strongest first. */
        val byStrength: List<Line>,
        val wheated: Line?,
        val otherBourbon: Line?,
        val averageFinishSeconds: Int?,
        /** Average rating when it drank hot (4-5) and when it drank easy (1-2). */
        val whenHot: Line?,
        val whenEasy: Line?,
        /** Of the tastings that answered, the share that would buy again. */
        val rebuyShare: Double?,
        val rebuyAnswered: Int,
        /**
         * Label bias: over products you rated both blind and knowing the
         * bottle, the average of (sighted - blind). Positive means the label
         * adds points. Null under [minimum] pairs.
         */
        val labelBias: Double?,
        val labelBiasPairs: Int
    ) {
        val isEmpty: Boolean get() = tastings == 0
    }

    /** Ratings a side before a comparison is drawn. */
    const val minimum = 3

    private val bands = listOf(
        "80–89 proof", "90–99 proof", "100–114 proof", "115 proof and up"
    )

    fun profile(tastings: List<Tasting>): Profile {
        val rated = tastings.filter { it.rating != null }

        val wordCounts = mutableMapOf<String, Int>()
        for (tasting in tastings) {
            for (key in tasting.descriptors.toSet()) {
                wordCounts[key] = (wordCounts[key] ?: 0) + 1
            }
        }
        val words = wordCounts
            .map { (key, count) -> Word(key, count) }
            .sortedWith(compareByDescending<Word> { it.count }.thenBy { it.key })

        val byClass = lines(
            rated.mapNotNull { t -> t.classType?.let { it.label to t.rating!! } }
        ).sortedWith(compareByDescending<Line> { it.average }.thenBy { it.label })

        val byStrength = lines(
            rated.mapNotNull { t -> t.abv?.let { band(it) to t.rating!! } }
        ).sortedByDescending { bands.indexOf(it.label).coerceAtLeast(0) }

        val wheated = line(
            "Wheated bourbon", rated.filter { it.isWheated == true }.map { it.rating!! }
        )
        val other = line(
            "Other bourbon", rated.filter { it.isWheated == false }.map { it.rating!! }
        )

        val finishes = tastings.mapNotNull { it.finishSeconds }.filter { it > 0 }
        val finish = if (finishes.size >= minimum) {
            (finishes.sum().toDouble() / finishes.size).roundToInt()
        } else {
            null
        }

        val hot = line(
            "Drank hot", rated.filter { (it.perceivedHeat ?: 0) >= 4 }.map { it.rating!! }
        )
        val easy = line(
            "Drank easy", rated.filter { (it.perceivedHeat ?: 0) in 1..2 }.map { it.rating!! }
        )

        val answered = tastings.mapNotNull { it.wouldRebuy }
        val rebuy = if (answered.size >= minimum) {
            answered.count { it }.toDouble() / answered.size.toDouble()
        } else {
            null
        }

        // One pair per product: the average of its sighted ratings against
        // the average of its blind ones, so a bottle tasted often does not
        // outvote one tasted twice.
        val sighted = LinkedHashMap<String, MutableList<Int>>()
        val blind = LinkedHashMap<String, MutableList<Int>>()
        for (t in rated) {
            val id = t.productId ?: continue
            val rating = t.rating ?: continue
            if (t.isBlind) {
                blind.getOrPut(id) { mutableListOf() }.add(rating)
            } else {
                sighted.getOrPut(id) { mutableListOf() }.add(rating)
            }
        }
        val differences = sighted.mapNotNull { (id, seen) ->
            val hidden = blind[id] ?: return@mapNotNull null
            mean(seen) - mean(hidden)
        }
        val bias = if (differences.size >= minimum) differences.sum() / differences.size else null

        return Profile(
            tastings = tastings.size,
            rated = rated.size,
            words = words,
            byClass = byClass,
            byStrength = byStrength,
            wheated = wheated,
            otherBourbon = other,
            averageFinishSeconds = finish,
            whenHot = hot,
            whenEasy = easy,
            rebuyShare = rebuy,
            rebuyAnswered = answered.size,
            labelBias = bias,
            labelBiasPairs = differences.size
        )
    }

    internal fun mean(values: List<Int>): Double =
        values.sum().toDouble() / values.size.toDouble()

    /**
     * What the profile says, in sentences, each only when the numbers behind
     * it clear the floor. Descriptor keys are given as labels by the caller,
     * since the wheel lives outside the engine.
     */
    fun sentences(p: Profile, label: (String) -> String): List<String> {
        val out = mutableListOf<String>()

        val words = p.words.filter { it.count >= 2 }.take(3)
        if (words.size == 3) {
            val names = words.map { label(it.key) }
            out.add("You reach for ${names[0]}, ${names[1]} and ${names[2]} most.")
        }

        val topClass = p.byClass.firstOrNull()
        val bottomClass = p.byClass.lastOrNull()
        if (p.byClass.size >= 2 && topClass != null && bottomClass != null &&
            topClass.average > bottomClass.average
        ) {
            out.add(
                "${topClass.label} rates highest with you: ${topClass.averageText} on average " +
                    "over ${topClass.count}, against ${bottomClass.averageText} for " +
                    "${bottomClass.label}."
            )
        }

        val strong = p.byStrength.firstOrNull()
        val mild = p.byStrength.lastOrNull()
        if (p.byStrength.size >= 2 && strong != null && mild != null) {
            if (strong.average > mild.average + 0.5) {
                out.add(
                    "The stronger the better: ${strong.label} averages ${strong.averageText} " +
                        "with you, ${mild.label} ${mild.averageText}."
                )
            } else if (mild.average > strong.average + 0.5) {
                out.add(
                    "Proof does not buy points with you: ${mild.label} averages " +
                        "${mild.averageText}, ${strong.label} ${strong.averageText}."
                )
            } else {
                out.add(
                    "Strength does not move your ratings: ${strong.label} and ${mild.label} " +
                        "both sit near ${strong.averageText}."
                )
            }
        }

        val w = p.wheated
        val o = p.otherBourbon
        if (w != null && o != null) {
            if (w.average > o.average + 0.5) {
                out.add(
                    "Wheated bourbons rate ${w.averageText} with you, other bourbons " +
                        "${o.averageText}."
                )
            } else if (o.average > w.average + 0.5) {
                out.add(
                    "Other bourbons rate ${o.averageText} with you, wheated ${w.averageText}."
                )
            }
        }

        val hot = p.whenHot
        val easy = p.whenEasy
        if (hot != null && easy != null) {
            if (easy.average > hot.average + 0.5) {
                out.add(
                    "Heat costs a bottle points with you: ${easy.averageText} when it drank " +
                        "easy, ${hot.averageText} when it drank hot."
                )
            } else if (hot.average > easy.average + 0.5) {
                out.add(
                    "Heat does not put you off: ${hot.averageText} when it drank hot, " +
                        "${easy.averageText} when it drank easy."
                )
            }
        }

        p.averageFinishSeconds?.let {
            out.add("A finish runs about $it seconds by your count.")
        }

        p.rebuyShare?.let {
            out.add("You would buy again ${(it * 10).roundToInt()} of every 10 you rated.")
        }

        p.labelBias?.let { bias ->
            val pairs = "${p.labelBiasPairs} bottles rated both ways"
            if (bias >= 0.5) {
                out.add(
                    String.format(
                        Locale.ROOT,
                        "Knowing the label adds %.1f points: bottles you rated blind and again " +
                            "knowing what they were came in higher the second time (%s).",
                        bias, pairs
                    )
                )
            } else if (bias <= -0.5) {
                out.add(
                    String.format(
                        Locale.ROOT,
                        "The label costs %.1f points with you: bottles rated blind came in " +
                            "higher than the same bottles rated knowing what they were (%s).",
                        -bias, pairs
                    )
                )
            } else {
                out.add(
                    "The label does not move you: blind and knowing, you rate the same " +
                        "bottles about the same ($pairs)."
                )
            }
        }

        return out
    }

    // MARK: - Pieces

    internal fun band(abv: Double): String = when {
        abv < 45 -> bands[0]
        abv < 50 -> bands[1]
        abv < 57.5 -> bands[2]
        else -> bands[3]
    }

    internal fun lines(pairs: List<Pair<String, Int>>): List<Line> {
        val groups = LinkedHashMap<String, MutableList<Int>>()
        for ((label, rating) in pairs) groups.getOrPut(label) { mutableListOf() }.add(rating)
        return groups.mapNotNull { (label, ratings) -> line(label, ratings) }
    }

    internal fun line(label: String, ratings: List<Int>): Line? {
        if (ratings.size < minimum) return null
        return Line(
            label = label,
            count = ratings.size,
            average = ratings.sum().toDouble() / ratings.size.toDouble()
        )
    }
}
