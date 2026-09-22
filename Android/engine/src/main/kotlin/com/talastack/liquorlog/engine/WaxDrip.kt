package com.talastack.liquorlog.engine

import kotlin.math.roundToInt
import kotlin.math.sqrt

/**
 * The wax on a Maker's Mark, measured.
 *
 * Every Maker's is hand-dipped, and collectors hunt the ones where the wax
 * ran: a long single drip, a cascade, a "slow pour". Some pay for it. The
 * lore is real and nobody measures it -- it is eyeballed in a store aisle
 * and argued about afterwards.
 *
 * This measures it from a photo, honestly. Two lines on the picture: the
 * bottle, base to cap, and the drip, wax edge to tip. The result is a
 * FRACTION of the bottle's height, which is what makes it comparable
 * between photos taken at different distances with different phones. If
 * the person types the bottle's real height it becomes millimetres too;
 * the app never guesses a bottle's height for them.
 *
 * What it will not do is call a drip rare. Nobody has published a
 * distribution, and the research is explicit about invented rarity tiers.
 * A drip is ranked among the person's own bottles, and [standing] exists
 * so that a community sample, when sync brings one, can place it without
 * a redesign.
 */
object WaxDrip {

    /**
     * A point on the photo, in whatever coordinate space the screen used.
     * Only ratios matter, so the units never do.
     */
    data class Point(val x: Double, val y: Double) {
        internal fun distanceTo(other: Point): Double =
            sqrt((x - other.x) * (x - other.x) + (y - other.y) * (y - other.y))
    }

    /**
     * The colours Maker's has dipped in. Red is the bottle; the others are
     * releases and picks, and a collector knows which is which on sight.
     */
    enum class Color(val storageKey: String) {
        RED("red"),
        BLACK("black"),
        GOLD("gold"),
        GREEN("green"),
        PURPLE("purple"),
        BLUE("blue"),
        WHITE("white"),
        OTHER("other");

        val label: String
            get() = when (this) {
                RED -> "Red"
                BLACK -> "Black"
                GOLD -> "Gold"
                GREEN -> "Green"
                PURPLE -> "Purple"
                BLUE -> "Blue"
                WHITE -> "White"
                OTHER -> "Another colour"
            }
    }

    data class Measurement(
        /**
         * Drip length over bottle height. 0.3 means the drip runs almost a
         * third of the way down the bottle.
         */
        val fraction: Double,
        /** Only when the bottle's real height was given. */
        val millimeters: Double?
    ) {
        val percent: Int get() = (fraction * 100).roundToInt()
    }

    /**
     * Null when either line has no length: two taps in the same place is
     * a slip, not a bottle of zero height.
     */
    fun measure(
        bottleBase: Point,
        bottleTop: Point,
        waxEdge: Point,
        dripTip: Point,
        bottleHeightMillimeters: Double? = null
    ): Measurement? {
        val bottle = bottleBase.distanceTo(bottleTop)
        val drip = waxEdge.distanceTo(dripTip)
        if (bottle <= 0 || drip < 0) return null
        val fraction = minOf(1.0, drip / bottle)
        val mm = bottleHeightMillimeters?.let { if (it > 0) fraction * it else null }
        return Measurement(fraction = fraction, millimeters = mm)
    }

    /**
     * Where one drip sits among others -- this person's own Maker's, or a
     * community sample later. 1-based rank by length, longest first.
     */
    data class Standing(
        val rank: Int,
        val count: Int,
        /**
         * Share of the others this one is longer than, 0..1. Null with
         * nothing to compare against.
         */
        val longerThan: Double?
    ) {
        val text: String
            get() {
                val share = longerThan
                if (count <= 1 || share == null) return "The only drip measured so far."
                if (rank == 1) return "Longest of $count."
                return "Longer than ${(share * 100).roundToInt()}% of $count."
            }
    }

    /**
     * Everyone's measured drips of a product, reduced on the server to a
     * count and quartiles. Where yours falls among them is a fact about
     * the sample, said in quarters, never a word for the drip itself.
     *
     * Swift decodes this straight from the community view's JSON; here the
     * data layer does the parsing and hands the numbers in, because this
     * module carries no JSON dependency.
     */
    data class CommunityStanding(
        val catalogProductId: String,
        val reports: Int,
        val p25: Double,
        val p50: Double,
        val p75: Double
    ) {
        /**
         * "Longer than three quarters of the 40 drips people have measured."
         * Null until there are enough.
         */
        fun text(fraction: Double): String? {
            if (reports < minimumReports) return null
            val tail = " of the $reports drips people have measured."
            if (fraction > p75) return "Longer than three quarters$tail"
            if (fraction > p50) return "Longer than half$tail"
            if (fraction > p25) return "Longer than a quarter$tail"
            return "Among the shortest quarter$tail"
        }

        companion object {
            /** Fewer than this and the quartiles are one person's bottles. */
            const val minimumReports = 4
        }
    }

    fun standing(fraction: Double, among: List<Double>): Standing {
        if (among.isEmpty()) return Standing(rank = 1, count = 1, longerThan = null)
        val all = among + fraction
        val longer = all.count { it > fraction }
        val shorter = among.count { it < fraction }
        return Standing(
            rank = longer + 1,
            count = all.size,
            longerThan = shorter.toDouble() / among.size.toDouble()
        )
    }

    // Deliberately absent: words for a length. An earlier version called a
    // drip "short", "proper", "long" or "a cascade" at bands the app made
    // up. No data exists for where those lines fall -- Maker's says only
    // that every bottle is hand-dipped -- so the app shows the number and
    // the standing among the person's own bottles, and says nothing it
    // cannot back.
}
