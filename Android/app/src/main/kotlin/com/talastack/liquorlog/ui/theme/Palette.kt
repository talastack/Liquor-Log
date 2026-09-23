package com.talastack.liquorlog.ui.theme

import androidx.compose.runtime.Immutable
import androidx.compose.ui.graphics.Color

/**
 * Every colour in the app, in both modes, in four looks.
 *
 * Generated from the SwiftUI palette rather than transcribed: 112 hex values
 * copied by hand is where a typo hides until somebody notices one screen is
 * the wrong colour in one mode of one look.
 *
 * The looks are each rooted in something a bourbon collector actually sees:
 *
 * - **Cellar** -- green-black and copper, the inside of a rickhouse at dusk.
 *   The default, chosen by the owner from the four.
 * - **Label** -- cream paper and oxblood ink, the look of an old label.
 *   Light-first.
 * - **Bond** -- navy and brass, the tax strip and the bonded seal.
 * - **Amber** -- the original, kept for anybody who liked it.
 *
 * The rule that matters is the same one the iOS side keeps: **no colour
 * literal appears anywhere else in the app.** Screens read `palette.accent`,
 * never a hex.
 */
@Immutable
data class Palette(
    val background: Color,
    val surface: Color,
    val surfaceRaised: Color,
    val line: Color,
    val text: Color,
    val textSecondary: Color,
    val textMuted: Color,
    val accent: Color,
    val accentSoft: Color,
    val onAccent: Color,
    val haveTheLine: Color,
    val good: Color,
    val bad: Color,
    val glass: Color,
)

enum class Look(val key: String, val display: String, val line: String) {
    CELLAR("cellar", "Cellar", "Green-black and copper. The rickhouse at dusk."),
    LABEL("label", "Label", "Cream paper and oxblood ink. Light by default."),
    BOND("bond", "Bond", "Navy and brass. The tax strip and the seal."),
    AMBER("amber", "Amber", "Warm black and gold. The first look."),
    ;

    companion object {
        /** The owner's choice of the four. */
        val standard: Look = CELLAR
        const val KEY: String = "theme.look"

        fun fromKey(key: String?): Look =
            entries.firstOrNull { it.key == key } ?: standard
    }
}

/**
 * Light, dark, or whatever the phone is set to.
 *
 * Separate from [Look] on purpose. A look is a colour family -- the green of
 * a rickhouse, the cream and oxblood of a label -- and every one of them has
 * a light set of tokens and a dark set. Until now the phone chose between
 * them and nothing in the app could, so somebody who keeps their phone light
 * could not have a dark shelf, and picking "Cellar: green-black and copper"
 * gave them a pale green screen.
 */
enum class Appearance(val key: String, val display: String, val line: String) {
    SYSTEM("system", "Follow the phone", "Light by day, dark at night, as the phone is set."),
    LIGHT("light", "Always light", "Paper, whatever the phone is doing."),
    DARK("dark", "Always dark", "The bar at night, whatever the phone is doing."),
    ;

    companion object {
        val standard: Appearance = SYSTEM
        const val KEY: String = "theme.appearance"

        fun fromKey(key: String?): Appearance =
            entries.firstOrNull { it.key == key } ?: standard
    }
}

/** The token set for one look in one mode. */
fun paletteFor(look: Look, dark: Boolean): Palette = when (look) {
    Look.CELLAR -> if (dark) cellarDark else cellarLight
    Look.LABEL -> if (dark) labelDark else labelLight
    Look.BOND -> if (dark) bondDark else bondLight
    Look.AMBER -> if (dark) amberDark else amberLight
}

private val cellarDark = Palette(
    background = Color(0xFF0E1613),
    surface = Color(0xFF152019),
    surfaceRaised = Color(0xFF1F2C24),
    line = Color(0xFF2F4034),
    text = Color(0xFFEAF0E9),
    textSecondary = Color(0xFFA9B8AC),
    textMuted = Color(0xFF7C8C80),
    accent = Color(0xFFC97B4A),
    accentSoft = Color(0xFFE09466),
    onAccent = Color(0xFF10140F),
    haveTheLine = Color(0xFFA5764F),
    good = Color(0xFF86B37A),
    bad = Color(0xFFC97C68),
    glass = Color(0xFF3E4F44),
)

private val cellarLight = Palette(
    background = Color(0xFFEEF2EA),
    surface = Color(0xFFF7F9F4),
    surfaceRaised = Color(0xFFDFE7DD),
    line = Color(0xFFC3D0C2),
    text = Color(0xFF14201A),
    textSecondary = Color(0xFF4A5A4F),
    textMuted = Color(0xFF6E7D72),
    accent = Color(0xFF9A5A33),
    accentSoft = Color(0xFFB56E42),
    onAccent = Color(0xFFFFFBF6),
    haveTheLine = Color(0xFF7E5A3C),
    good = Color(0xFF37693B),
    bad = Color(0xFF9B3E2A),
    glass = Color(0xFFB6C4B2),
)

private val labelDark = Palette(
    background = Color(0xFF17120E),
    surface = Color(0xFF211A15),
    surfaceRaised = Color(0xFF2C231C),
    line = Color(0xFF3E3228),
    text = Color(0xFFF0E7D8),
    textSecondary = Color(0xFFBBAD97),
    textMuted = Color(0xFF8E806B),
    accent = Color(0xFFD0533C),
    accentSoft = Color(0xFFE06A52),
    onAccent = Color(0xFFFFF6EA),
    haveTheLine = Color(0xFFB07A63),
    good = Color(0xFF7FAA72),
    bad = Color(0xFFC07862),
    glass = Color(0xFF5A4A38),
)

private val labelLight = Palette(
    background = Color(0xFFF4EBD8),
    surface = Color(0xFFFBF5E8),
    surfaceRaised = Color(0xFFEADFC6),
    line = Color(0xFFD5C7A8),
    text = Color(0xFF1E1A14),
    textSecondary = Color(0xFF5A4F3F),
    textMuted = Color(0xFF7E7160),
    accent = Color(0xFF8B2E1F),
    accentSoft = Color(0xFFA63D2C),
    onAccent = Color(0xFFFBF5E8),
    haveTheLine = Color(0xFF9A5A45),
    good = Color(0xFF3E6B3A),
    bad = Color(0xFF9A3A22),
    glass = Color(0xFFB8A57E),
)

private val bondDark = Palette(
    background = Color(0xFF0D1626),
    surface = Color(0xFF14203A),
    surfaceRaised = Color(0xFF1D2B49),
    line = Color(0xFF2E3E60),
    text = Color(0xFFEEF1F7),
    textSecondary = Color(0xFFB4BDD0),
    textMuted = Color(0xFF8290AB),
    accent = Color(0xFFC8A44A),
    accentSoft = Color(0xFFDDBB62),
    onAccent = Color(0xFF0D1626),
    haveTheLine = Color(0xFFA48A4E),
    good = Color(0xFF7FAA72),
    bad = Color(0xFFC07862),
    glass = Color(0xFF3A4A6A),
)

private val bondLight = Palette(
    background = Color(0xFFEFF2F7),
    surface = Color(0xFFFFFFFF),
    surfaceRaised = Color(0xFFDFE5EF),
    line = Color(0xFFC6CFDD),
    text = Color(0xFF101828),
    textSecondary = Color(0xFF475467),
    textMuted = Color(0xFF667085),
    accent = Color(0xFF7A5D14),
    accentSoft = Color(0xFF94722A),
    onAccent = Color(0xFFFFFFFF),
    haveTheLine = Color(0xFF6E5A22),
    good = Color(0xFF356038),
    bad = Color(0xFF94402A),
    glass = Color(0xFFB9C4D6),
)

private val amberDark = Palette(
    background = Color(0xFF15100A),
    surface = Color(0xFF1E1710),
    surfaceRaised = Color(0xFF2A2016),
    line = Color(0xFF3A2D1E),
    text = Color(0xFFF2E9DB),
    textSecondary = Color(0xFFC0B19A),
    textMuted = Color(0xFF968771),
    accent = Color(0xFFC9973A),
    accentSoft = Color(0xFFE2B661),
    onAccent = Color(0xFF1A1309),
    haveTheLine = Color(0xFFA5763C),
    good = Color(0xFF7FAA72),
    bad = Color(0xFFC07862),
    glass = Color(0xFF5A4326),
)

private val amberLight = Palette(
    background = Color(0xFFF6F1E7),
    surface = Color(0xFFFFFDF7),
    surfaceRaised = Color(0xFFECE4D4),
    line = Color(0xFFDCD0BA),
    text = Color(0xFF1B1510),
    textSecondary = Color(0xFF4A4036),
    textMuted = Color(0xFF6B5F50),
    accent = Color(0xFF8A5F18),
    accentSoft = Color(0xFFA87C2C),
    onAccent = Color(0xFFFFFDF7),
    haveTheLine = Color(0xFF8A5F18),
    good = Color(0xFF356038),
    bad = Color(0xFF94402A),
    glass = Color(0xFFC9B48C),
)
