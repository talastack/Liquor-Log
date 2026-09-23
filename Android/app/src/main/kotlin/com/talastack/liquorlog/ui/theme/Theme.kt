package com.talastack.liquorlog.ui.theme

import androidx.compose.foundation.isSystemInDarkTheme
import androidx.compose.material3.LocalTextStyle
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Typography
import androidx.compose.material3.darkColorScheme
import androidx.compose.material3.lightColorScheme
import androidx.compose.runtime.Composable
import androidx.compose.runtime.CompositionLocalProvider
import androidx.compose.runtime.ReadOnlyComposable
import androidx.compose.runtime.staticCompositionLocalOf
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.text.font.FontFamily
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp

/**
 * The type scale, matching the iOS one size for size.
 *
 * The iOS side names three typefaces -- Newsreader, Public Sans, Spline Sans
 * Mono -- but ships none of them, so it falls back to the system serif, sans
 * and monospace. This does the same deliberately rather than by accident: the
 * two platforms then look the same for the same reason, and bundling the real
 * faces later is one change in each file rather than a redesign.
 */
object TypeScale {
    val largeTitle = TextStyle(
        fontFamily = FontFamily.Serif, fontSize = 32.sp, fontWeight = FontWeight.SemiBold,
    )
    val title = TextStyle(
        fontFamily = FontFamily.Serif, fontSize = 23.sp, fontWeight = FontWeight.Medium,
    )
    val headline = TextStyle(
        fontFamily = FontFamily.SansSerif, fontSize = 17.sp, fontWeight = FontWeight.Bold,
    )
    val body = TextStyle(
        fontFamily = FontFamily.SansSerif, fontSize = 16.sp, fontWeight = FontWeight.Normal,
    )
    val secondary = TextStyle(
        fontFamily = FontFamily.SansSerif, fontSize = 15.sp, fontWeight = FontWeight.Normal,
    )
    val caption = TextStyle(
        fontFamily = FontFamily.SansSerif, fontSize = 12.sp, fontWeight = FontWeight.Bold,
    )
    val code = TextStyle(
        fontFamily = FontFamily.Monospace, fontSize = 14.sp, fontWeight = FontWeight.Normal,
    )
}

/**
 * The spacing rhythm, the same numbers as iOS.
 *
 * [tapTarget] is a MINIMUM applied with `defaultMinSize`, never a fixed
 * height: text that grows must be able to push a control taller rather than
 * be clipped by it.
 */
object Space {
    val xs = 4.dp
    val s = 8.dp
    val m = 12.dp
    val l = 16.dp
    val xl = 24.dp

    /** 48dp on Android where iOS uses 44pt; both are the platform minimum. */
    val tapTarget = 48.dp
}

val LocalPalette = staticCompositionLocalOf { paletteFor(Look.standard, dark = true) }

/**
 * Whether the palette in force is the dark one.
 *
 * Not the same question as `isSystemInDarkTheme()`: the Label look is
 * light-first, and the six verdict colours that do not vary by look still
 * have to pick a light or a dark value. A screen that asked the system would
 * get the wrong one for that look.
 */
val LocalDark = staticCompositionLocalOf { true }

/** The current look's tokens. Screens read this; nothing reads a hex. */
val palette: Palette
    @Composable @ReadOnlyComposable get() = LocalPalette.current

/**
 * The app's theme.
 *
 * Material3's own colour scheme is filled in from the palette as well, because
 * Material components -- the navigation bar, text fields, ripples -- read it
 * and would otherwise arrive in Material's default purple on top of a
 * rickhouse-green app.
 */
@Composable
fun LiquorLogTheme(
    look: Look = Look.standard,
    appearance: Appearance = Appearance.standard,
    content: @Composable () -> Unit,
) {
    // The phone answers only when nobody has said otherwise. `dark` used to
    // BE `isSystemInDarkTheme()` with no way past it, which made three of
    // the four looks unreachable on a phone kept in light mode.
    val dark = when (appearance) {
        Appearance.SYSTEM -> isSystemInDarkTheme()
        Appearance.LIGHT -> false
        Appearance.DARK -> true
    }
    val tokens = paletteFor(look, dark)

    val colors = if (dark) {
        darkColorScheme(
            primary = tokens.accent,
            onPrimary = tokens.onAccent,
            background = tokens.background,
            onBackground = tokens.text,
            surface = tokens.surface,
            onSurface = tokens.text,
            surfaceVariant = tokens.surfaceRaised,
            onSurfaceVariant = tokens.textSecondary,
            outline = tokens.line,
            error = tokens.bad,
        )
    } else {
        lightColorScheme(
            primary = tokens.accent,
            onPrimary = tokens.onAccent,
            background = tokens.background,
            onBackground = tokens.text,
            surface = tokens.surface,
            onSurface = tokens.text,
            surfaceVariant = tokens.surfaceRaised,
            onSurfaceVariant = tokens.textSecondary,
            outline = tokens.line,
            error = tokens.bad,
        )
    }

    CompositionLocalProvider(
        LocalPalette provides tokens,
        LocalDark provides dark,
        LocalTextStyle provides TypeScale.body.copy(color = tokens.text),
    ) {
        MaterialTheme(
            colorScheme = colors,
            typography = Typography(
                headlineLarge = TypeScale.largeTitle,
                headlineMedium = TypeScale.title,
                titleMedium = TypeScale.headline,
                bodyLarge = TypeScale.body,
                bodyMedium = TypeScale.secondary,
                labelSmall = TypeScale.caption,
            ),
            content = content,
        )
    }
}
