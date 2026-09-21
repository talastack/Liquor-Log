package com.talastack.liquorlog.ui

import androidx.compose.foundation.BorderStroke
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.ExperimentalLayoutApi
import androidx.compose.foundation.layout.FlowRow
import androidx.compose.foundation.layout.defaultMinSize
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Star
import androidx.compose.material3.Icon
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.geometry.Size
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.Path
import androidx.compose.ui.graphics.drawscope.Stroke
import androidx.compose.ui.draw.drawBehind
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.talastack.liquorlog.engine.ABV
import com.talastack.liquorlog.engine.PourStatus
import com.talastack.liquorlog.engine.ShelfCheckResult
import com.talastack.liquorlog.engine.Volume
import com.talastack.liquorlog.ui.theme.LocalDark
import com.talastack.liquorlog.ui.theme.Space
import com.talastack.liquorlog.ui.theme.TypeScale
import com.talastack.liquorlog.ui.theme.palette
import java.util.Locale
import kotlin.math.max
import kotlin.math.min
import kotlin.math.roundToInt

/**
 * The design system, in Compose.
 *
 * A one-for-one port of `IOS/App/DesignSystem/Components.swift`. Every piece
 * here exists on both platforms with the same name and the same rules, so a
 * change to how a verdict reads or how a fill bar is worded is one edit per
 * platform rather than a hunt through the screens.
 */

// Verdict badge

/**
 * The shelf-check answer, as a label.
 *
 * Takes the engine's own headline rather than a string, so the `when` below
 * is exhaustive: adding a verdict to the engine is a compile error here until
 * somebody decides how it looks. A badge that falls through to a default is a
 * verdict the user never sees.
 *
 * **Colour never carries the meaning alone.** Every badge shows its text, for
 * a dim shop aisle and for anyone colour-blind.
 */
@Composable
fun VerdictBadge(headline: ShelfCheckResult.Headline) {
    val tint = verdictTint(headline)
    // Filled when you have some claim on the bottle, outlined when you do
    // not. The fill is what carries at arm's length.
    val filled = when (headline) {
        ShelfCheckResult.Headline.ON_YOUR_SHELF,
        ShelfCheckResult.Headline.HAVE_THE_LINE_NOT_THIS_RELEASE,
        ShelfCheckResult.Headline.HAVE_A_SAMPLE -> true

        ShelfCheckResult.Headline.HAD_IT_BEFORE,
        ShelfCheckResult.Headline.TASTED_NEVER_OWNED,
        ShelfCheckResult.Headline.NEVER_HAD_IT -> false
    }
    val colors = palette
    val shape = RoundedCornerShape(6.dp)

    Box(
        modifier = Modifier
            .clip(shape)
            .then(
                if (filled) Modifier.background(tint)
                else Modifier.border(1.dp, tint, shape)
            )
            .defaultMinSize(minHeight = 26.dp)
            .padding(horizontal = Space.m, vertical = 5.dp),
        contentAlignment = Alignment.Center,
    ) {
        Text(
            text = verdictTitle(headline).uppercase(Locale.getDefault()),
            style = TypeScale.caption,
            color = if (filled) colors.onAccent else tint,
        )
    }
}

/**
 * The words each verdict gets.
 *
 * Presentation, not engine: the same six cases are worded for a screen here,
 * and the engine stays free to be read by something that words them
 * differently.
 */
fun verdictTitle(headline: ShelfCheckResult.Headline): String = when (headline) {
    ShelfCheckResult.Headline.ON_YOUR_SHELF -> "On your shelf"
    ShelfCheckResult.Headline.HAVE_THE_LINE_NOT_THIS_RELEASE -> "Have the line"
    ShelfCheckResult.Headline.HAVE_A_SAMPLE -> "Have a sample"
    ShelfCheckResult.Headline.TASTED_NEVER_OWNED -> "Tasted, not owned"
    ShelfCheckResult.Headline.HAD_IT_BEFORE -> "Had it before"
    ShelfCheckResult.Headline.NEVER_HAD_IT -> "Never had it"
}

/**
 * The one place colour is categorical.
 *
 * Four of the six are fixed across the looks, exactly as on iOS, so they stay
 * distinguishable from each other and from whichever accent the look brings.
 */
@Composable
fun verdictTint(headline: ShelfCheckResult.Headline): Color {
    val colors = palette
    val dark = LocalDark.current
    fun pick(darkValue: Long, lightValue: Long) =
        Color(if (dark) darkValue else lightValue)

    return when (headline) {
        ShelfCheckResult.Headline.ON_YOUR_SHELF -> colors.accent
        ShelfCheckResult.Headline.HAVE_THE_LINE_NOT_THIS_RELEASE -> colors.haveTheLine
        ShelfCheckResult.Headline.HAVE_A_SAMPLE -> pick(0xFF6FA8A0, 0xFF2E6B64)
        ShelfCheckResult.Headline.TASTED_NEVER_OWNED -> pick(0xFF9D84B8, 0xFF4E4176)
        ShelfCheckResult.Headline.HAD_IT_BEFORE -> pick(0xFF7F96AB, 0xFF3A5670)
        ShelfCheckResult.Headline.NEVER_HAD_IT -> pick(0xFFB5705A, 0xFF94402A)
    }
}

// Numbers people type

/**
 * A number from a text field, whichever separator the keyboard gave.
 *
 * A decimal keypad inserts the region's separator, so in Germany or Brazil
 * "2,5" arrives and `toDoubleOrNull` is null. This reads both.
 */
object LocalNumber {
    fun parse(text: String): Double? {
        val trimmed = text.trim()
        return trimmed.toDoubleOrNull() ?: trimmed.replace(',', '.').toDoubleOrNull()
    }
}

/**
 * Millilitres or US fluid ounces, by a per-device preference.
 *
 * Bottles are labelled in millilitres and the database stores millilitres;
 * American pours are thought about in ounces. The preference changes only
 * what is SHOWN -- every stored number and every export stays metric, so two
 * devices with different settings hold the same data.
 */
object VolumeDisplay {
    const val KEY = "units.ounces"

    /** "573 ml" or "19.4 oz". */
    fun text(milliliters: Double, ounces: Boolean): String {
        if (ounces) {
            val oz = milliliters / Volume.US_FLUID_OUNCE_IN_MILLILITERS
            return String.format(Locale.ROOT, if (oz < 10) "%.1f oz" else "%.0f oz", oz)
        }
        return milliliters.roundToInt().toString() + " ml"
    }

    /**
     * Both, when ounces are on: "573 ml · 19.4 oz". Where the millilitres are
     * the thing being edited they stay visible, so the number typed and the
     * number shown never disagree.
     */
    fun both(milliliters: Double, ounces: Boolean): String =
        if (ounces) {
            milliliters.roundToInt().toString() + " ml · " + text(milliliters, true)
        } else {
            text(milliliters, false)
        }
}

// Fill bar

/**
 * How much is left, from the engine's own status.
 *
 * The count and the millilitres are rendered together and cannot be
 * separated, because the pour count rounds to nearest: a bottle holding 16.6
 * pours reads "17". The millilitres are what stop that rounding from carrying
 * weight on its own.
 */
@Composable
fun FillBar(status: PourStatus, ounces: Boolean = false) {
    val colors = palette
    Column(verticalArrangement = Arrangement.spacedBy(Space.s)) {
        Row(
            modifier = Modifier.fillMaxWidth(),
            horizontalArrangement = Arrangement.SpaceBetween,
            verticalAlignment = Alignment.Bottom,
        ) {
            Text(
                "${status.remainingPours} of ${status.totalPours} pours left",
                style = TypeScale.code.copy(fontSize = TypeScale.body.fontSize),
                color = colors.text,
            )
            Text(
                VolumeDisplay.text(status.remainingMilliliters, ounces) + " left",
                style = TypeScale.code.copy(fontSize = TypeScale.caption.fontSize),
                color = colors.textSecondary,
            )
        }

        val fraction = if (status.capacityMilliliters > 0) {
            min(1.0, max(0.0, status.remainingMilliliters / status.capacityMilliliters))
        } else {
            0.0
        }
        Box(
            modifier = Modifier
                .fillMaxWidth()
                .height(9.dp)
                .clip(RoundedCornerShape(50))
                .background(colors.surfaceRaised),
        ) {
            Box(
                modifier = Modifier
                    .fillMaxWidth(fraction.toFloat())
                    .height(9.dp)
                    .clip(RoundedCornerShape(50))
                    .background(
                        Brush.horizontalGradient(listOf(colors.accent, colors.accentSoft))
                    ),
            )
        }

        if (status.hasPartialPourOnly) {
            // Never render this state as "0 pours", which reads as empty.
            Text("Less than a pour left", style = TypeScale.caption, color = colors.textMuted)
        }
    }
}

// Rating

@Composable
fun RatingChip(rating: Int, outOf: Int = 10) {
    val colors = palette
    val shape = RoundedCornerShape(7.dp)
    Row(
        modifier = Modifier
            .clip(shape)
            .background(colors.surfaceRaised)
            .border(1.dp, colors.line, shape)
            .defaultMinSize(minHeight = 28.dp)
            .padding(horizontal = Space.m - 2.dp, vertical = 4.dp),
        horizontalArrangement = Arrangement.spacedBy(Space.xs + 1.dp),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        Icon(
            Icons.Filled.Star,
            contentDescription = null,
            tint = colors.accent,
            modifier = Modifier.size(12.dp),
        )
        Text(
            "$rating/$outOf",
            style = TypeScale.secondary.copy(fontWeight = FontWeight.SemiBold),
            color = colors.accent,
        )
    }
}

// Bottle mark

/**
 * A drawn bottle silhouette, used wherever a thumbnail is wanted.
 *
 * Deliberately a placeholder: real label artwork belongs to the distillery
 * and is not ours to reproduce. When somebody photographs their own bottle,
 * that photo replaces this.
 *
 * The path is the same set of points as the SwiftUI `BottleShape`, expressed
 * in fractions of the box so the two platforms draw the same bottle.
 */
@Composable
fun BottleMark(height: Dp = 58.dp) {
    val colors = palette
    Box(
        modifier = Modifier
            .width(height * 0.62f)
            .height(height)
            .drawBehind {
                val path = bottlePath(size)
                drawPath(path, colors.glass.copy(alpha = 0.55f))
                drawPath(path, colors.glass, style = Stroke(width = 1.4.dp.toPx()))
                // The label panel, in the accent, so the mark reads as a
                // bottle rather than a vase at thumbnail size.
                val w = size.width
                val h = size.height
                drawRoundRect(
                    color = colors.accent.copy(alpha = 0.85f),
                    topLeft = Offset(w * 0.5f - h * 0.145f, h * 0.5f - h * 0.08f),
                    size = Size(h * 0.29f, h * 0.26f),
                    cornerRadius = androidx.compose.ui.geometry.CornerRadius(2.dp.toPx()),
                )
            },
    )
}

private fun bottlePath(size: Size): Path {
    val w = size.width
    val h = size.height
    return Path().apply {
        moveTo(w * 0.39f, h * 0.03f)
        lineTo(w * 0.61f, h * 0.03f)
        lineTo(w * 0.61f, h * 0.20f)
        quadraticBezierTo(w * 0.90f, h * 0.26f, w * 0.94f, h * 0.40f)
        lineTo(w * 0.94f, h * 0.90f)
        quadraticBezierTo(w * 0.94f, h * 0.97f, w * 0.80f, h * 0.97f)
        lineTo(w * 0.20f, h * 0.97f)
        quadraticBezierTo(w * 0.06f, h * 0.97f, w * 0.06f, h * 0.90f)
        lineTo(w * 0.06f, h * 0.40f)
        quadraticBezierTo(w * 0.10f, h * 0.26f, w * 0.39f, h * 0.20f)
        close()
    }
}

// Small parts

/** Uppercase section label. 12sp is the floor for anything in this app. */
@Composable
fun SectionLabel(text: String, modifier: Modifier = Modifier) {
    Text(
        text.uppercase(Locale.getDefault()),
        style = TypeScale.caption.copy(letterSpacing = 1.1.sp),
        color = palette.textSecondary,
        modifier = modifier,
    )
}

/**
 * A fact row: label on the left, value on the right, hairline underneath.
 *
 * Class type and production type are always two of these, never one. They are
 * independent axes -- Elijah Craig Barrel Proof is Kentucky Straight *and*
 * small batch *and* barrel proof -- and merging them is what makes an app
 * unable to answer "do I have this bourbon, or do I have *this type*?"
 */
@Composable
fun FactRow(label: String, value: String, isLast: Boolean = false) {
    val colors = palette
    Column(modifier = Modifier.fillMaxWidth()) {
        Row(
            modifier = Modifier.fillMaxWidth().padding(vertical = 13.dp),
            horizontalArrangement = Arrangement.spacedBy(Space.l),
            verticalAlignment = Alignment.Top,
        ) {
            Text(
                label,
                style = TypeScale.secondary,
                color = colors.textSecondary,
                modifier = Modifier.weight(1f),
            )
            Text(
                value,
                style = TypeScale.secondary,
                color = colors.text,
                textAlign = TextAlign.End,
                modifier = Modifier.weight(1.4f),
            )
        }
        if (!isLast) {
            Box(Modifier.fillMaxWidth().height(1.dp).background(colors.line))
        }
    }
}

/** The bordered surface every card in the app sits on. */
@Composable
fun Card(
    modifier: Modifier = Modifier,
    onClick: (() -> Unit)? = null,
    borderColor: Color? = null,
    content: @Composable androidx.compose.foundation.layout.ColumnScope.() -> Unit,
) {
    val colors = palette
    val shape = RoundedCornerShape(12.dp)
    Column(
        modifier = modifier
            .fillMaxWidth()
            .clip(shape)
            .background(colors.surface)
            .border(BorderStroke(1.dp, borderColor ?: colors.line), shape)
            .then(if (onClick != null) Modifier.clickable(onClick = onClick) else Modifier)
            .padding(Space.l),
        verticalArrangement = Arrangement.spacedBy(Space.s),
        content = content,
    )
}

/** A filter or option chip. Filled when on, quiet when off. */
@Composable
fun Chip(
    label: String,
    isOn: Boolean,
    icon: androidx.compose.ui.graphics.vector.ImageVector? = null,
    onClick: () -> Unit,
) {
    val colors = palette
    Row(
        modifier = Modifier
            .clip(RoundedCornerShape(9.dp))
            .background(if (isOn) colors.accent else colors.surfaceRaised)
            .clickable(onClick = onClick)
            .defaultMinSize(minHeight = Space.tapTarget - 8.dp)
            .padding(horizontal = Space.l),
        horizontalArrangement = Arrangement.spacedBy(Space.xs),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        if (icon != null) {
            Icon(
                icon,
                contentDescription = null,
                tint = if (isOn) colors.onAccent else colors.textSecondary,
                modifier = Modifier.size(13.dp),
            )
        }
        Text(
            label,
            style = TypeScale.secondary,
            color = if (isOn) colors.onAccent else colors.textSecondary,
        )
    }
}

/**
 * A set of chips that wraps.
 *
 * Not a scrolling row: a scrolling row hides options off the edge, and for a
 * handful of them -- three ways to answer "would you buy it again" -- the
 * hidden one is the one somebody wanted. The long lists (a 1-to-10 rating, a
 * dozen class types) scroll instead, because wrapping those takes half the
 * screen.
 */
@OptIn(ExperimentalLayoutApi::class)
@Composable
fun ChipRow(modifier: Modifier = Modifier, content: @Composable () -> Unit) {
    // A plain lambda rather than FlowRowScope: no caller needs the scope, and
    // taking it would leak the experimental annotation to every screen.
    FlowRow(
        modifier = modifier,
        horizontalArrangement = Arrangement.spacedBy(Space.s),
        verticalArrangement = Arrangement.spacedBy(Space.s),
    ) {
        content()
    }
}

/** The primary action. Accent-filled, never smaller than a thumb. */
@Composable
fun AccentButton(
    label: String,
    modifier: Modifier = Modifier,
    enabled: Boolean = true,
    onClick: () -> Unit,
) {
    val colors = palette
    // Disabled is shown by the fill and the label together. A button that
    // looks live and does nothing is worse than one that looks off.
    val alpha = if (enabled) 1f else 0.4f
    Box(
        modifier = modifier
            .clip(RoundedCornerShape(10.dp))
            .background(colors.accent.copy(alpha = alpha))
            .clickable(enabled = enabled, onClick = onClick)
            .defaultMinSize(minHeight = Space.tapTarget)
            .padding(horizontal = Space.l, vertical = Space.m),
        contentAlignment = Alignment.Center,
    ) {
        Text(
            label,
            style = TypeScale.headline,
            color = colors.onAccent.copy(alpha = alpha),
        )
    }
}

/** A quiet action, for anything that is not the one thing on the screen. */
@Composable
fun QuietButton(
    label: String,
    modifier: Modifier = Modifier,
    enabled: Boolean = true,
    onClick: () -> Unit,
) {
    val colors = palette
    val shape = RoundedCornerShape(10.dp)
    val alpha = if (enabled) 1f else 0.4f
    Box(
        modifier = modifier
            .clip(shape)
            .border(1.dp, colors.line.copy(alpha = alpha), shape)
            .clickable(enabled = enabled, onClick = onClick)
            .defaultMinSize(minHeight = Space.tapTarget)
            .padding(horizontal = Space.l, vertical = Space.m),
        contentAlignment = Alignment.Center,
    ) {
        Text(label, style = TypeScale.headline, color = colors.text.copy(alpha = alpha))
    }
}

/** The centred nothing-here state every empty list uses. */
@Composable
fun Empty(title: String, line: String, modifier: Modifier = Modifier) {
    val colors = palette
    Column(
        modifier = modifier.fillMaxSize().padding(Space.xl),
        verticalArrangement = Arrangement.Center,
        horizontalAlignment = Alignment.CenterHorizontally,
    ) {
        Text(title, style = TypeScale.title, color = colors.text, textAlign = TextAlign.Center)
        Text(
            line,
            style = TypeScale.secondary,
            color = colors.textSecondary,
            textAlign = TextAlign.Center,
            modifier = Modifier.padding(top = Space.s),
        )
    }
}

/** "62.1% ABV · 124.2 proof", or an honest absence. */
fun strengthLine(abv: Double?, isBarrelProof: Boolean = false): String {
    val percent = abv
        ?: return if (isBarrelProof) "Varies by batch" else "Strength not recorded"
    return String.format(
        Locale.ROOT, "%.1f%% ABV · %.1f proof", percent, ABV(percent).proof,
    )
}
