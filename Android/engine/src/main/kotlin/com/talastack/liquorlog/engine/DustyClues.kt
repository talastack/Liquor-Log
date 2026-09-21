package com.talastack.liquorlog.engine

/**
 * Dating an old bottle from what is printed on it.
 *
 * A "dusty" -- a bottle that sat on a shelf for decades -- usually has no
 * date on it, but it has things that only existed for certain years: a
 * tax strip, the agency named on the strip, a "4/5 QUART" size, a metric
 * size, a UPC. Each is a window; the bottle's date is where the windows
 * overlap. This is the collectors' method (whiskeyid.com,
 * whiskeyprof.com), with the federal dates behind it:
 *
 * - Strip stamps were required on distilled spirits until the tax stamp
 *   requirement was repealed effective 1 July 1985 (Deficit Reduction Act
 *   of 1984). A bottle with any strip is from before that.
 * - The Bureau of Alcohol, Tobacco and Firearms took over from the IRS's
 *   Alcohol and Tobacco Tax Division on 1 July 1972; strips printed
 *   "ATF" are later than that and strips printed "IRS" or "Internal
 *   Revenue" earlier -- collectors put the changeover on strips at 1977,
 *   when the ATF wording reached bottles.
 * - Metric standards of fill (750 ml, 1 L, 1.75 L) became mandatory for
 *   distilled spirits on 1 January 1980, after a transition from 1976
 *   (27 CFR 5.47a). "4/5 QUART", "PINT" and "1/2 PINT" are before 1980;
 *   "750 ML" is 1976 or later.
 * - Green bottled-in-bond strips with the seasons of barrelling and
 *   bottling printed on them were discontinued 1 December 1982.
 * - "Series 111" or "112" near the eagle: 1945 to 1972. Volume marked on
 *   the ends of the strip: before 1973.
 *
 * Nothing here is a date; it is a window, and two clues that cannot both
 * be true are reported as a conflict rather than averaged.
 */
object DustyClues {

    data class Clue(
        val id: String,
        val text: String,
        /** The window this clue puts the bottle in. Null is open on that side. */
        val from: Int?,
        val to: Int?,
        val why: String
    ) {
        companion object {
            val allCases: List<Clue> = listOf(
                Clue(
                    "strip", "A paper strip over the cap", null, 1985,
                    "Strip stamps were required until 1 July 1985."
                ),
                Clue(
                    "irs", "The strip says IRS or Internal Revenue", null, 1976,
                    "The IRS wording was replaced by ATF's on strips from 1977."
                ),
                Clue(
                    "atf", "The strip says ATF", 1977, 1985,
                    "ATF wording on strips from 1977; strips ended 1 July 1985."
                ),
                Clue(
                    "series", "\"Series 111\" or \"112\" near the eagle", 1945, 1972,
                    "Printed on strips from 1945 to 1972."
                ),
                Clue(
                    "ends", "A volume marked on the ends of the strip", null, 1972,
                    "Volume markings came off the strip ends in 1973."
                ),
                Clue(
                    "bib-green", "A green bottled-in-bond strip with two seasons on it", null, 1982,
                    "Discontinued 1 December 1982."
                ),
                Clue(
                    "quart", "\"4/5 QUART\", \"PINT\" or \"1/2 PINT\" on the glass", null, 1979,
                    "Metric sizes became mandatory 1 January 1980 (27 CFR 5.47a)."
                ),
                Clue(
                    "metric", "\"750 ML\", \"1 LITER\" or \"1.75 L\" on the glass", 1976, null,
                    "Metric sizes were allowed from 1976 and required from 1980."
                ),
                Clue(
                    "no-strip", "No strip, and the cap has never been opened", 1985, null,
                    "Strips ended 1 July 1985."
                )
            )
        }
    }

    data class Window(
        val from: Int?,
        val to: Int?,
        /** Two chosen clues that cannot both be true. */
        val conflict: Pair<Clue, Clue>?
    ) {
        /** "Between 1977 and 1979", "1985 or later", "Before 1973". */
        val text: String
            get() {
                val clash = conflict
                if (clash != null) {
                    return "Those cannot both be true: \"${clash.first.text}\" " +
                        "and \"${clash.second.text}\"."
                }
                val start = from
                val end = to
                return when {
                    start == null && end == null -> "Pick what the bottle shows."
                    end == null -> "$start or later."
                    start == null -> "Before ${end + 1}."
                    start == end -> "$start."
                    else -> "Between $start and $end."
                }
            }
    }

    /**
     * Pairs one bottle cannot show at once, whatever the year: a strip
     * and no strip, IRS and ATF wording on the same strip, a quart size
     * and a metric one on the same glass.
     */
    internal val exclusive: List<Pair<String, String>> = listOf(
        "strip" to "no-strip", "irs" to "atf", "quart" to "metric"
    )

    /** The overlap of the chosen clues' windows. */
    fun window(chosen: List<Clue>): Window {
        for ((a, b) in exclusive) {
            val first = chosen.firstOrNull { it.id == a }
            val second = chosen.firstOrNull { it.id == b }
            if (first != null && second != null) return Window(null, null, first to second)
        }
        var from: Int? = null
        var to: Int? = null
        var fromClue: Clue? = null
        var toClue: Clue? = null
        for (clue in chosen) {
            val f = clue.from
            if (f != null && f > (from ?: Int.MIN_VALUE)) {
                from = f
                fromClue = clue
            }
            val t = clue.to
            if (t != null && t < (to ?: Int.MAX_VALUE)) {
                to = t
                toClue = clue
            }
            val low = from
            val high = to
            val a = fromClue
            val b = toClue
            if (low != null && high != null && low > high && a != null && b != null) {
                return Window(null, null, a to b)
            }
        }
        return Window(from, to, null)
    }
}
