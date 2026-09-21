package com.talastack.liquorlog.ui

import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.ArrowBack
import androidx.compose.material.icons.filled.MoreVert
import androidx.compose.material3.DropdownMenu
import androidx.compose.material3.DropdownMenuItem
import androidx.compose.material3.Icon
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import com.talastack.liquorlog.data.BottleRepository
import com.talastack.liquorlog.data.TastingRepository
import com.talastack.liquorlog.engine.ABV
import com.talastack.liquorlog.engine.FillLevel
import com.talastack.liquorlog.engine.Money
import com.talastack.liquorlog.engine.OxidationBand
import com.talastack.liquorlog.engine.PourSize
import com.talastack.liquorlog.engine.Replenish
import com.talastack.liquorlog.engine.RecipeCode
import com.talastack.liquorlog.engine.TastingTrend
import com.talastack.liquorlog.ui.theme.Space
import com.talastack.liquorlog.ui.theme.TypeScale
import com.talastack.liquorlog.ui.theme.palette
import java.time.Instant
import java.util.Locale
import kotlin.math.roundToInt

/**
 * One bottle: what it is, how much is left, and what you thought of it.
 *
 * The sections are the iOS ones in the iOS order, and for the iOS reason --
 * the fill and the oxidation band sit together because the band is an
 * estimate and the tastings under it are the evidence, and the two are
 * allowed to disagree.
 *
 * **Every number on this screen is derived, never stored.** The fill comes
 * from the pour log, the oxidation band from headroom and days open, the
 * cost per pour from what was paid. A screen that stored them would show a
 * figure that a pour logged on another device had already made wrong.
 */
@Composable
fun BottleDetailScreen(
    bottleId: String,
    onBack: () -> Unit,
    onEdit: (String) -> Unit,
    onRecordTasting: (String) -> Unit,
) {
    val state = LocalAppState.current
    val colors = palette
    val summary = remember(bottleId, state.changeCount) { state.bottles.byId(bottleId) }
    val pours = remember(bottleId, state.changeCount) { state.bottles.poursFor(bottleId) }
    val tastings = remember(bottleId, state.changeCount) { state.tastings.forBottle(bottleId) }
    var confirmingFinish by remember { mutableStateOf(false) }
    var confirmingRemove by remember { mutableStateOf(false) }
    var customPour by remember { mutableStateOf<String?>(null) }
    var showsAllPours by remember { mutableStateOf(false) }
    var replenish by remember { mutableStateOf<Replenish.Offer?>(null) }

    /**
     * Pours, and asks about the wishlist on the pour that crosses the line.
     *
     * The crossing pour only. A bottle already down to its last two is not
     * asked about again on every pour after that, which would turn a useful
     * question into nagging.
     */
    fun pour(milliliters: Double) {
        val before = summary?.status?.remainingPours ?: return
        state.bottles.logPour(bottleId, milliliters = milliliters)
        state.noteChange()
        val after = state.bottles.byId(bottleId)?.status?.remainingPours ?: return
        replenish = Replenish.offer(
            remainingBefore = before,
            remainingAfter = after,
            isOnWishlist = state.wishlist.isWished(summary.bottle.catalog_product_id),
            wouldRebuy = when (tastings.firstNotNullOfOrNull { it.rebuy }) {
                TastingRepository.Rebuy.YES -> true
                TastingRepository.Rebuy.NO -> false
                TastingRepository.Rebuy.MAYBE, null -> null
            },
        )
    }

    Column(Modifier.fillMaxWidth()) {
        DetailBar(
            title = summary?.let { state.name(it) } ?: "Bottle",
            onBack = onBack,
            actions = {
                if (summary != null) {
                    Text(
                        "Edit",
                        style = TypeScale.body,
                        color = colors.accent,
                        modifier = Modifier
                            .clickable { onEdit(bottleId) }
                            .padding(horizontal = Space.s, vertical = Space.m),
                    )
                    BottleMenu(
                        summary = summary,
                        onPour = { ml -> pour(ml) },
                        onCustomPour = { customPour = "" },
                        onOpen = {
                            state.bottles.open(bottleId)
                            state.noteChange()
                        },
                        onFinish = { confirmingFinish = true },
                        onUnfinish = {
                            state.bottles.unfinish(bottleId)
                            state.noteChange()
                        },
                        onRemove = { confirmingRemove = true },
                    )
                }
            },
        )

        if (summary == null) {
            // Reached from a stale link or a bottle removed on another device.
            Column(
                modifier = Modifier.fillMaxWidth().padding(top = 64.dp, start = Space.xl, end = Space.xl),
                horizontalAlignment = Alignment.CenterHorizontally,
                verticalArrangement = Arrangement.spacedBy(Space.m),
            ) {
                BottleMark(height = 84.dp)
                Text(
                    "This bottle is no longer on your shelf.",
                    style = TypeScale.title,
                    color = colors.text,
                    textAlign = TextAlign.Center,
                )
            }
            return@Column
        }

        LazyColumn(
            contentPadding = PaddingValues(
                start = Space.xl, end = Space.xl, top = Space.s, bottom = 96.dp,
            ),
            verticalArrangement = Arrangement.spacedBy(Space.xl),
        ) {
            item { Hero(summary) }
            item { FillSection(summary, pours, showsAllPours) { showsAllPours = !showsAllPours } }

            oxidation(summary)?.let { estimate ->
                item { OxidationCard(estimate) }
            }

            if (tastings.isNotEmpty()) {
                item { HowItHasDrunk(summary, tastings) }
            }
            item { PriceSection(summary) }
            item { FactsSection(summary) }

            if (summary.isStorePick || summary.bottle.barrel_number != null) {
                item { PickSection(summary) }
            }
            if (summary.storageLocation != null || summary.bottle.shelf_number != null) {
                item { WhereItIs(summary) }
            }
            item {
                Actions(
                    summary = summary,
                    onRecordTasting = { onRecordTasting(bottleId) },
                    onPour = { pour(PourSize.standard.milliliters) },
                )
            }
        }
    }

    if (confirmingFinish) {
        ConfirmDialog(
            title = "Mark this bottle as finished?",
            message = "It leaves the shelf and stays in your history, tastings and all.",
            confirmLabel = "Finished",
            onConfirm = {
                state.bottles.finish(bottleId)
                state.noteChange()
                confirmingFinish = false
            },
            onDismiss = { confirmingFinish = false },
        )
    }

    if (confirmingRemove) {
        ConfirmDialog(
            title = "Remove this bottle from your collection?",
            message = "For a bottle that was entered by mistake. A bottle you drank " +
                "should be marked finished instead, so its history stays.",
            confirmLabel = "Remove",
            destructive = true,
            onConfirm = {
                state.bottles.softDelete(bottleId)
                state.noteChange()
                confirmingRemove = false
                onBack()
            },
            onDismiss = { confirmingRemove = false },
        )
    }

    replenish?.let { offer ->
        ConfirmDialog(
            title = "Nearly gone",
            message = offer.text + " Want it on your wishlist?",
            confirmLabel = "Add to wishlist",
            onConfirm = {
                val product = summary?.bottle?.catalog_product_id
                state.wishlist.add(
                    catalogProductId = product,
                    // A typed-in bottle has no catalogue row, so the name is
                    // all the wishlist can carry for it.
                    customName = if (product == null) summary?.let { state.name(it) } else null,
                )
                state.noteChange()
                replenish = null
            },
            onDismiss = { replenish = null },
        )
    }

    customPour?.let { text ->
        TextEntryDialog(
            title = "Pour how much?",
            message = "In millilitres. 44 ml is a standard 1.5 oz pour.",
            initial = text,
            confirmLabel = "Log it",
            numeric = true,
            onConfirm = { typed ->
                LocalNumber.parse(typed)?.takeIf { it > 0 }?.let { pour(it) }
                customPour = null
            },
            onDismiss = { customPour = null },
        )
    }
}

// Sections

@Composable
private fun Hero(summary: BottleRepository.Summary) {
    val state = LocalAppState.current
    val colors = palette
    Column(
        modifier = Modifier.fillMaxWidth().padding(top = Space.s),
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.spacedBy(Space.m),
    ) {
        BottleMark(height = 104.dp)
        state.distillery(summary)?.let { SectionLabel(it) }
        Text(
            state.name(summary),
            style = TypeScale.largeTitle,
            color = colors.text,
            textAlign = TextAlign.Center,
        )
        summary.latestRating?.let { RatingChip(it) }
        Text(
            strengthLine(
                summary.abv ?: state.product(summary.bottle.catalog_product_id)?.abv,
                isBarrelProof = state.product(summary.bottle.catalog_product_id)
                    ?.isBarrelProof == true,
            ),
            style = TypeScale.code,
            color = colors.textMuted,
        )
    }
}

@Composable
private fun FillSection(
    summary: BottleRepository.Summary,
    pours: List<com.talastack.liquorlog.data.Pours>,
    showsAll: Boolean,
    onToggleAll: () -> Unit,
) {
    val state = LocalAppState.current
    val colors = palette
    Column(verticalArrangement = Arrangement.spacedBy(Space.m)) {
        SectionLabel("Fill level")
        FillBar(summary.status, ounces = state.ounces)

        Row(
            modifier = Modifier.fillMaxWidth(),
            horizontalArrangement = Arrangement.SpaceBetween,
        ) {
            val days = summary.daysOpen()
            Text(
                if (days == null) "Unopened"
                else "Open $days " + if (days == 1) "day" else "days",
                style = TypeScale.secondary,
                color = colors.textSecondary,
            )
            summary.costPerPourCents?.let {
                Text(
                    Money.short(it) + " a pour",
                    style = TypeScale.secondary,
                    color = colors.accent,
                )
            }
        }

        // Stated as a fact, never as a prompt. People use it to dig out a
        // bottle they liked and forgot about; nothing here suggests that
        // pouring more often would be better.
        summary.daysSinceLastPour()?.let { days ->
            Text(
                if (days == 0) "Last poured today"
                else "Last poured $days " + (if (days == 1) "day" else "days") + " ago",
                style = TypeScale.secondary,
                color = colors.textSecondary,
            )
        }

        if (pours.isNotEmpty()) {
            Text("POUR LOG", style = TypeScale.caption, color = colors.textMuted)
            val shown = if (showsAll) pours else pours.take(5)
            for (pour in shown) {
                Row(
                    modifier = Modifier.fillMaxWidth().height(26.dp),
                    horizontalArrangement = Arrangement.SpaceBetween,
                    verticalAlignment = Alignment.CenterVertically,
                ) {
                    Text(
                        shortDate(pour.poured_at) +
                            (pour.given_to?.takeIf { it.isNotBlank() }
                                ?.let { " · for " + it } ?: ""),
                        style = TypeScale.caption,
                        color = colors.textMuted,
                    )
                    Text(
                        VolumeDisplay.text(pour.volume_ml, state.ounces),
                        style = TypeScale.code,
                        color = colors.textMuted,
                    )
                }
            }
            if (pours.size > 5) {
                Text(
                    if (showsAll) "Show fewer" else "Show all ${pours.size}",
                    style = TypeScale.caption,
                    color = colors.accent,
                    modifier = Modifier.clickable(onClick = onToggleAll).padding(vertical = Space.s),
                )
            }
        }
    }
}

/**
 * The oxidation band, hedged and banded.
 *
 * Never a date and never a percentage: nobody has published a real curve for
 * this, and a precise-looking number would claim a precision the estimate
 * does not have. The caveat is part of the card, not a footnote.
 */
@Composable
private fun OxidationCard(estimate: OxidationBand.Estimate) {
    val colors = palette
    val tint = when (estimate.band) {
        OxidationBand.Band.FRESH -> colors.good
        OxidationBand.Band.PEAK -> colors.accent
        OxidationBand.Band.FADING -> colors.haveTheLine
        OxidationBand.Band.FADED -> colors.bad
    }
    Card {
        Row(
            modifier = Modifier.fillMaxWidth(),
            horizontalArrangement = Arrangement.SpaceBetween,
            verticalAlignment = Alignment.CenterVertically,
        ) {
            SectionLabel("How it is holding up")
            Text(estimate.band.label, style = TypeScale.headline, color = tint)
        }

        // Four steps, because the underlying effect is not precise enough to
        // justify a bar that moves smoothly.
        Row(horizontalArrangement = Arrangement.spacedBy(Space.xs)) {
            for (step in 0..3) {
                Box(
                    modifier = Modifier
                        .weight(1f)
                        .height(6.dp)
                        .clip(RoundedCornerShape(3.dp))
                        .background(if (step <= estimate.band.step) tint else colors.surfaceRaised),
                )
            }
        }

        Text(estimate.summary, style = TypeScale.secondary, color = colors.textSecondary)
        Text(estimate.caveat, style = TypeScale.caption, color = colors.textMuted)
    }
}

/**
 * Whether your opinion of this bottle moved as it went down.
 *
 * Two rated tastings at minimum, because one number is not a trend, and the
 * engine enforces that rather than this screen.
 */
@Composable
private fun HowItHasDrunk(
    summary: BottleRepository.Summary,
    tastings: List<TastingRepository.Detail>,
) {
    val state = LocalAppState.current
    val colors = palette
    val trend = remember(tastings) {
        TastingTrend.summarise(
            tastings.mapNotNull { detail ->
                val rating = detail.rating ?: return@mapNotNull null
                TastingTrend.Point(
                    tastedAt = Instant.ofEpochMilli(detail.tastedAt),
                    rating = rating,
                )
            }
        )
    }

    Column(verticalArrangement = Arrangement.spacedBy(Space.m)) {
        SectionLabel("How it has drunk")
        trend?.let {
            Card { Text(it.text, style = TypeScale.body, color = colors.text) }
        }
        for (detail in tastings) {
            Card {
                Row(
                    modifier = Modifier.fillMaxWidth(),
                    horizontalArrangement = Arrangement.SpaceBetween,
                    verticalAlignment = Alignment.CenterVertically,
                ) {
                    Text(
                        shortDate(detail.tastedAt),
                        style = TypeScale.code,
                        color = colors.textMuted,
                    )
                    detail.rating?.let { RatingChip(it) }
                }
                detail.rebuy?.let {
                    Text(
                        it.label,
                        style = TypeScale.secondary,
                        color = if (it == TastingRepository.Rebuy.NO) colors.bad else colors.accent,
                    )
                }
                detail.liked?.let {
                    Text(it, style = TypeScale.secondary, color = colors.textSecondary)
                }
                detail.disliked?.let {
                    Text(it, style = TypeScale.secondary, color = colors.textMuted)
                }
                val described = detail.describe(state.wheel)
                if (described.isNotEmpty()) {
                    Text(described, style = TypeScale.caption, color = colors.textMuted)
                }
            }
        }
    }
}

@Composable
private fun PriceSection(summary: BottleRepository.Summary) {
    val state = LocalAppState.current
    val colors = palette
    val paid = summary.purchasePriceCents?.toInt()
    val msrp = state.product(summary.bottle.catalog_product_id)?.priceReference

    if (paid == null && msrp == null) return

    Column(verticalArrangement = Arrangement.spacedBy(Space.s)) {
        SectionLabel("What it cost")
        Card {
            paid?.let {
                FactRow("Paid", Money.short(it), isLast = msrp == null)
            }
            msrp?.let { reference ->
                // The source is shown with the number, always. An unsourced
                // price is a rumour, and this app does not carry rumours.
                FactRow(
                    "Suggested retail",
                    Money.short(reference.cents),
                    isLast = false,
                )
                FactRow(
                    "Source",
                    listOfNotNull(
                        reference.source,
                        reference.asOfYear?.toString(),
                    ).joinToString(", "),
                    isLast = true,
                )
            }
        }
        summary.costPerPourCents?.let {
            Text(
                Money.short(it) + " a pour, at " +
                    VolumeDisplay.text(summary.bottle.pour_size_ml, state.ounces) + " a pour",
                style = TypeScale.caption,
                color = colors.textMuted,
            )
        }
    }
}

/**
 * What the label says.
 *
 * Class type and production type are two rows, never one. They are
 * independent axes -- a bottle is Kentucky Straight *and* small batch *and*
 * barrel proof -- and merging them is what makes an app unable to answer "do
 * I have this bourbon, or do I have this type?"
 */
@Composable
private fun FactsSection(summary: BottleRepository.Summary) {
    val state = LocalAppState.current
    val bottle = summary.bottle
    val product = state.product(bottle.catalog_product_id)
    val entry = bottle.catalog_product_id?.let { state.bottles.customEntry(it) }

    val rows = buildList {
        val classLabel = product?.classType?.label
            ?: entry?.class_type
                ?.let { com.talastack.liquorlog.engine.ClassType.fromStorageKey(it) }?.label
        classLabel?.let { add("Class type" to it) }

        val production = product?.productionType
            ?: entry?.production_type
                ?.let { com.talastack.liquorlog.engine.ProductionType.fromStorageKey(it) }
        val flags = buildList {
            production?.takeIf {
                it != com.talastack.liquorlog.engine.ProductionType.UNSPECIFIED
            }?.let { add(it.label) }
            if (product?.isBarrelProof == true || entry?.is_barrel_proof == 1L) {
                add("barrel proof")
            }
            if (product?.isBottledInBond == true || entry?.is_bottled_in_bond == 1L) {
                add("bottled in bond")
            }
        }
        if (flags.isNotEmpty()) add("Production type" to flags.joinToString(" · "))

        add("Size" to VolumeDisplay.both(bottle.volume_ml, state.ounces))
        bottle.age_months?.let { months ->
            add("Age" to if (months % 12 == 0L) "${months / 12} years" else "$months months")
        }
        bottle.recipe_code?.let { code ->
            // Decoded by the engine, which knows the mashbill and the yeast
            // each letter stands for. An undecodable code is shown as typed.
            val decoded = RecipeCode.parse(code)
            add(
                "Recipe code" to (
                    decoded?.let {
                        code + " · " + it.mashbill.summary + " · " + it.yeast.character
                    } ?: code
                )
            )
        }
        bottle.purchase_store?.takeIf { it.isNotBlank() }?.let { add("Bought at" to it) }
        bottle.purchase_date?.let { add("Bought" to shortDate(it)) }
        bottle.dsp?.takeIf { it.isNotBlank() }?.let { add("DSP" to it) }
        add("Added" to shortDate(bottle.created_at))
    }

    Column(verticalArrangement = Arrangement.spacedBy(Space.s)) {
        SectionLabel("What it is")
        Card {
            rows.forEachIndexed { index, (label, value) ->
                FactRow(label, value, isLast = index == rows.lastIndex)
            }
        }
    }
}

@Composable
private fun PickSection(summary: BottleRepository.Summary) {
    val bottle = summary.bottle
    val rows = buildList {
        bottle.pick_store?.takeIf { it.isNotBlank() }?.let { add("Picked by" to it) }
        bottle.pick_name?.takeIf { it.isNotBlank() }?.let { add("Pick name" to it) }
        bottle.barrel_number?.takeIf { it.isNotBlank() }?.let { add("Barrel" to it) }
        bottle.batch_number?.takeIf { it.isNotBlank() }?.let { add("Batch" to it) }
        bottle.warehouse?.takeIf { it.isNotBlank() }?.let { add("Warehouse" to it) }
        bottle.rick?.takeIf { it.isNotBlank() }?.let { add("Rick" to it) }
        bottle.floor?.takeIf { it.isNotBlank() }?.let { add("Floor" to it) }
    }
    if (rows.isEmpty()) return

    Column(verticalArrangement = Arrangement.spacedBy(Space.s)) {
        SectionLabel("The pick")
        Card {
            rows.forEachIndexed { index, (label, value) ->
                FactRow(label, value, isLast = index == rows.lastIndex)
            }
        }
    }
}

@Composable
private fun WhereItIs(summary: BottleRepository.Summary) {
    val rows = buildList {
        summary.storageLocation?.takeIf { it.isNotBlank() }?.let { add("Location" to it) }
        summary.bottle.shelf_number?.let { add("Shelf" to it.toString()) }
    }
    if (rows.isEmpty()) return

    Column(verticalArrangement = Arrangement.spacedBy(Space.s)) {
        SectionLabel("Where it is")
        Card {
            rows.forEachIndexed { index, (label, value) ->
                FactRow(label, value, isLast = index == rows.lastIndex)
            }
        }
    }
}

@Composable
private fun Actions(
    summary: BottleRepository.Summary,
    onRecordTasting: () -> Unit,
    onPour: () -> Unit,
) {
    Column(verticalArrangement = Arrangement.spacedBy(Space.s)) {
        if (!summary.isFinished) {
            AccentButton(
                if (summary.isOpen) "Pour" else "Open and pour",
                modifier = Modifier.fillMaxWidth(),
                onClick = onPour,
            )
        }
        QuietButton(
            "Record a tasting",
            modifier = Modifier.fillMaxWidth(),
            onClick = onRecordTasting,
        )
    }
}

// Chrome

/**
 * Everything that changes the bottle's state without a form: the pour sizes,
 * opening without pouring, finishing, removing.
 */
@Composable
private fun BottleMenu(
    summary: BottleRepository.Summary,
    onPour: (Double) -> Unit,
    onCustomPour: () -> Unit,
    onOpen: () -> Unit,
    onFinish: () -> Unit,
    onUnfinish: () -> Unit,
    onRemove: () -> Unit,
) {
    val colors = palette
    var open by remember { mutableStateOf(false) }
    Box {
        Icon(
            Icons.Filled.MoreVert,
            contentDescription = "More actions",
            tint = colors.accent,
            modifier = Modifier
                .clickable { open = true }
                .padding(Space.m)
                .size(22.dp),
        )
        DropdownMenu(
            expanded = open,
            onDismissRequest = { open = false },
            modifier = Modifier.background(colors.surface),
        ) {
            if (!summary.isFinished) {
                for (choice in pourChoices) {
                    DropdownMenuItem(
                        text = { Text(choice.label, style = TypeScale.body, color = colors.text) },
                        onClick = {
                            onPour(choice.milliliters)
                            open = false
                        },
                    )
                }
                DropdownMenuItem(
                    text = { Text("Another amount…", style = TypeScale.body, color = colors.text) },
                    onClick = {
                        onCustomPour()
                        open = false
                    },
                )
                if (!summary.isOpen) {
                    DropdownMenuItem(
                        text = {
                            Text(
                                "Mark as opened today",
                                style = TypeScale.body,
                                color = colors.text,
                            )
                        },
                        onClick = {
                            onOpen()
                            open = false
                        },
                    )
                }
                DropdownMenuItem(
                    text = { Text("Mark as finished", style = TypeScale.body, color = colors.text) },
                    onClick = {
                        onFinish()
                        open = false
                    },
                )
            } else {
                DropdownMenuItem(
                    text = {
                        Text("Put back on the shelf", style = TypeScale.body, color = colors.text)
                    },
                    onClick = {
                        onUnfinish()
                        open = false
                    },
                )
            }
            DropdownMenuItem(
                text = {
                    Text("Remove from collection", style = TypeScale.body, color = colors.bad)
                },
                onClick = {
                    onRemove()
                    open = false
                },
            )
        }
    }
}

/**
 * The sizes people actually pour, in the unit they think in. The millilitres
 * are what is stored.
 */
private data class PourChoice(val ounces: Double) {
    val milliliters: Double get() = PourSize.fromOunces(ounces).milliliters
    val label: String
        get() {
            val oz = if (ounces == ounces.roundToInt().toDouble()) {
                ounces.roundToInt().toString()
            } else {
                String.format(Locale.ROOT, "%.1f", ounces)
            }
            return "$oz oz · ${milliliters.roundToInt()} ml"
        }
}

private val pourChoices = listOf(
    PourChoice(0.5), PourChoice(1.0), PourChoice(1.5), PourChoice(2.0),
)

/** The oxidation estimate, or null for a bottle that is not open. */
private fun oxidation(summary: BottleRepository.Summary): OxidationBand.Estimate? {
    val days = summary.daysOpen() ?: return null
    return OxidationBand.estimate(
        fillLevel = FillLevel(
            remainingMilliliters = summary.status.remainingMilliliters,
            capacityMilliliters = summary.status.capacityMilliliters,
        ),
        daysOpen = days,
    )
}
