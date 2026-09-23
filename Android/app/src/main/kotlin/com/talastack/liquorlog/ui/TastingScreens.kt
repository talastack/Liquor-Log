package com.talastack.liquorlog.ui

import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.horizontalScroll
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.ExperimentalLayoutApi
import androidx.compose.foundation.layout.FlowRow
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.compose.ui.window.Dialog
import com.talastack.liquorlog.data.BottleRepository
import com.talastack.liquorlog.data.TastingRepository
import com.talastack.liquorlog.engine.FlavorFamily
import com.talastack.liquorlog.ui.theme.Space
import com.talastack.liquorlog.ui.theme.TypeScale
import com.talastack.liquorlog.ui.theme.palette

/**
 * Every tasting you have recorded, newest first.
 *
 * Every tasting, not only the ones reached through a bottle: a tasting at a
 * bar has no bottle behind it and used to vanish the moment it was saved.
 */
@Composable
fun TastingHistoryScreen(onOpenBottle: (String) -> Unit, onRecord: () -> Unit) {
    val state = LocalAppState.current
    val colors = palette
    val details = remember(state.changeCount) { state.tastings.allDetails() }
    val bottles = remember(state.changeCount) {
        state.bottles.all().associateBy { it.id }
    }

    LazyColumn(
        contentPadding = PaddingValues(
            start = Space.xl, end = Space.xl, top = Space.s, bottom = 96.dp,
        ),
        verticalArrangement = Arrangement.spacedBy(Space.m),
    ) {
        item { Text("Tastings", style = TypeScale.largeTitle, color = colors.text) }

        if (details.isEmpty()) {
            item {
                Column(
                    modifier = Modifier.fillMaxWidth().padding(top = 64.dp),
                    horizontalAlignment = Alignment.CenterHorizontally,
                    verticalArrangement = Arrangement.spacedBy(Space.m),
                ) {
                    Text("No tastings yet", style = TypeScale.title, color = colors.text)
                    Text(
                        "Tap the + to record one. A rating on its own is enough.",
                        style = TypeScale.secondary,
                        color = colors.textMuted,
                        textAlign = TextAlign.Center,
                    )
                    AccentButton("Record a tasting", onClick = onRecord)
                }
            }
        } else {
            items(details, key = { it.id }) { detail ->
                TastingRow(
                    detail = detail,
                    title = title(state, detail, bottles),
                    onClick = detail.bottleId?.let { id -> { onOpenBottle(id) } },
                )
            }
        }
    }
}

@Composable
private fun TastingRow(
    detail: TastingRepository.Detail,
    title: String,
    onClick: (() -> Unit)?,
) {
    val state = LocalAppState.current
    val colors = palette
    Card(onClick = onClick) {
        Row(
            modifier = Modifier.fillMaxWidth(),
            verticalAlignment = Alignment.Top,
        ) {
            Text(
                title,
                style = TypeScale.title,
                color = colors.text,
                modifier = Modifier.weight(1f),
            )
            detail.rating?.let { RatingChip(it) }
        }

        Row(horizontalArrangement = Arrangement.spacedBy(Space.s)) {
            Text(shortDate(detail.tastedAt), style = TypeScale.code, color = colors.textMuted)
            detail.whereLabel?.let {
                Text("· " + it, style = TypeScale.caption, color = colors.textMuted)
            }
        }

        // Was being recorded and never shown on iOS at first. The research
        // rates would-buy-again as MORE useful than a numeric score: most
        // people's ratings cluster in one narrow band, and this one does not.
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

private fun title(
    state: AppState,
    detail: TastingRepository.Detail,
    bottles: Map<String, BottleRepository.Summary>,
): String {
    detail.bottleId?.let { id -> bottles[id]?.let { return state.name(it) } }
    state.identity(detail.catalogProductId)?.let { return it.displayName }
    return detail.tasting.source_note?.takeIf { it.isNotBlank() } ?: "Untitled tasting"
}

/**
 * Recording a tasting.
 *
 * The one required field is nothing. A rating on its own is a complete
 * tasting, and so is a single word in "what you liked" -- the research is
 * clear that a form demanding four stages of descriptors is a form people
 * stop filling in after the third bottle.
 */
@Composable
fun TastingSheetScreen(
    bottleId: String?,
    /**
     * The tasting being corrected, when this was opened on one that already
     * exists. An opinion is the one thing in this app that is genuinely
     * revisable -- a rating typed a digit out, a descriptor you meant to
     * pick -- and recording one used to be a one-way door.
     */
    editing: TastingRepository.Detail? = null,
    onDone: () -> Unit,
) {
    val state = LocalAppState.current
    val colors = palette
    // An edit keeps the tasting's own subject: changing your mind about a
    // whiskey does not move it to a different bottle.
    val subjectId = editing?.tasting?.bottle_id ?: bottleId
    val bottle = remember(subjectId) { subjectId?.let { state.bottles.byId(it) } }

    var rating by remember { mutableStateOf(editing?.tasting?.rating?.toInt()) }
    var rebuy by remember { mutableStateOf(editing?.rebuy) }
    var liked by remember { mutableStateOf(editing?.tasting?.liked ?: "") }
    var disliked by remember { mutableStateOf(editing?.tasting?.disliked ?: "") }
    var where by remember { mutableStateOf(editing?.tasting?.source ?: "") }
    var untitled by remember { mutableStateOf(editing?.tasting?.source_note ?: "") }
    var blind by remember { mutableStateOf(editing?.tasting?.blind == 1L) }
    var picks by remember {
        mutableStateOf(editing?.descriptors ?: mapOf<TastingRepository.Stage, List<String>>())
    }
    var pickingStage by remember { mutableStateOf<TastingRepository.Stage?>(null) }

    Column(Modifier.fillMaxWidth()) {
        DetailBar(
            title = bottle?.let { state.name(it) }
                ?: if (editing != null) "Edit tasting" else "Record a tasting",
            onBack = onDone,
            actions = {
                Text(
                    "Save",
                    style = TypeScale.headline,
                    color = colors.accent,
                    modifier = Modifier
                        .clickable {
                            // An edit writes over the same row. Recording a
                            // second one would leave the original behind and
                            // show the same night twice.
                            if (editing != null) {
                                state.tastings.update(
                                    id = editing.tasting.id,
                                    rating = rating,
                                    rebuy = rebuy,
                                    liked = liked,
                                    disliked = disliked,
                                    source = where.trim().ifBlank { null },
                                    sourceNote = untitled.trim().ifBlank { null },
                                    isBlind = blind,
                                    descriptors = picks,
                                )
                            } else {
                                state.tastings.record(
                                    bottleId = subjectId,
                                    rating = rating,
                                    rebuy = rebuy,
                                    liked = liked,
                                    disliked = disliked,
                                    source = where.trim().ifBlank { null },
                                    sourceNote = untitled.trim().ifBlank { null },
                                    isBlind = blind,
                                    descriptors = picks,
                                )
                            }
                            state.noteChange()
                            onDone()
                        }
                        .padding(horizontal = Space.m, vertical = Space.m),
                )
            },
        )

        LazyColumn(
            contentPadding = PaddingValues(Space.xl),
            verticalArrangement = Arrangement.spacedBy(Space.m),
        ) {
            if (bottle == null) {
                item {
                    Field(
                        untitled, { untitled = it },
                        label = "What you tasted",
                        placeholder = "Elijah Craig Small Batch",
                    )
                }
            }

            item { SectionLabel("Rating") }
            item {
                Row(
                    modifier = Modifier.horizontalScroll(rememberScrollState()),
                    horizontalArrangement = Arrangement.spacedBy(Space.s),
                ) {
                    for (score in 1..10) {
                        Chip(score.toString(), isOn = rating == score) {
                            rating = if (rating == score) null else score
                        }
                    }
                }
            }

            item { SectionLabel("Would you buy it again") }
            item {
                ChipRow {
                    for (option in TastingRepository.Rebuy.entries) {
                        Chip(option.label, isOn = rebuy == option) {
                            rebuy = if (rebuy == option) null else option
                        }
                    }
                }
            }

            item { SectionLabel("Flavours") }
            for (stage in TastingRepository.Stage.entries) {
                item {
                    StageRow(
                        stage = stage,
                        picked = picks[stage].orEmpty(),
                        onOpen = { pickingStage = stage },
                    )
                }
            }

            item { SectionLabel("In your own words") }
            item {
                Field(
                    liked, { liked = it },
                    label = "What you liked",
                    singleLine = false,
                )
            }
            item {
                Field(
                    disliked, { disliked = it },
                    label = "What you did not",
                    singleLine = false,
                )
            }

            item { SectionLabel("Where") }
            item {
                Field(
                    where, { where = it },
                    label = "At a bar, at a tasting, a friend's pour",
                )
            }
            item {
                ChipRow {
                    Chip("Tasted blind", isOn = blind) { blind = !blind }
                }
            }
            item {
                Text(
                    "Nothing here is required. A rating on its own is a tasting.",
                    style = TypeScale.caption,
                    color = colors.textMuted,
                    modifier = Modifier.padding(top = Space.l, bottom = 64.dp),
                )
            }
        }
    }

    pickingStage?.let { stage ->
        FlavourWheelPicker(
            stage = stage,
            picked = picks[stage].orEmpty(),
            onDone = { keys ->
                picks = picks + (stage to keys)
                pickingStage = null
            },
            onDismiss = { pickingStage = null },
        )
    }
}

@Composable
private fun StageRow(
    stage: TastingRepository.Stage,
    picked: List<String>,
    onOpen: () -> Unit,
) {
    val state = LocalAppState.current
    val colors = palette
    Card(onClick = onOpen) {
        Row(
            modifier = Modifier.fillMaxWidth(),
            horizontalArrangement = Arrangement.SpaceBetween,
        ) {
            Text(stage.label, style = TypeScale.headline, color = colors.text)
            Text(
                if (picked.isEmpty()) "Pick" else "${picked.size} picked",
                style = TypeScale.secondary,
                color = colors.accent,
            )
        }
        if (picked.isNotEmpty()) {
            Text(
                picked.joinToString(", ") { key ->
                    state.wheel?.descriptor(key)?.label ?: key
                },
                style = TypeScale.secondary,
                color = colors.textSecondary,
            )
        }
    }
}

/**
 * The flavour wheel, as a list of families you open one at a time.
 *
 * iOS draws it as an actual wheel. This does not, yet -- and says so rather
 * than drawing a wheel whose segments are too small to hit. The descriptors,
 * their families and their origins are the same bundled file both platforms
 * read, so a pick made here reads identically on a phone running the other
 * one.
 */
@Composable
fun FlavourWheelPicker(
    stage: TastingRepository.Stage,
    picked: List<String>,
    onDone: (List<String>) -> Unit,
    onDismiss: () -> Unit,
) {
    val state = LocalAppState.current
    val colors = palette
    var chosen by remember { mutableStateOf(picked.toSet()) }
    var openFamily by remember { mutableStateOf<String?>(null) }
    val wheel = state.wheel

    Dialog(onDismissRequest = onDismiss) {
        Column(
            modifier = Modifier
                .fillMaxWidth()
                .background(colors.background, RoundedCornerShape(14.dp))
                .padding(Space.l),
            verticalArrangement = Arrangement.spacedBy(Space.m),
        ) {
            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.SpaceBetween,
                verticalAlignment = Alignment.CenterVertically,
            ) {
                Text(stage.label, style = TypeScale.title, color = colors.text)
                Text(
                    "Done",
                    style = TypeScale.headline,
                    color = colors.accent,
                    modifier = Modifier
                        .clickable { onDone(chosen.toList()) }
                        .padding(Space.s),
                )
            }

            if (wheel == null) {
                Text(
                    "The flavour wheel could not be read on this device.",
                    style = TypeScale.secondary,
                    color = colors.textMuted,
                )
            } else {
                LazyColumn(
                    verticalArrangement = Arrangement.spacedBy(Space.s),
                    // Padded at the foot, so the last family is a whole card
                    // rather than one clipped by the dialog's own edge.
                    contentPadding = PaddingValues(bottom = Space.s),
                    modifier = Modifier.heightIn(max = 440.dp),
                ) {
                    items(wheel.families, key = { it.key }) { family ->
                        FamilyBlock(
                            family = family,
                            isOpen = openFamily == family.key,
                            chosen = chosen,
                            onToggleOpen = {
                                openFamily = if (openFamily == family.key) null else family.key
                            },
                            onToggle = { key ->
                                chosen = if (key in chosen) chosen - key else chosen + key
                            },
                        )
                    }
                }
            }
        }
    }
}

@OptIn(ExperimentalLayoutApi::class)
@Composable
private fun FamilyBlock(
    family: FlavorFamily,
    isOpen: Boolean,
    chosen: Set<String>,
    onToggleOpen: () -> Unit,
    onToggle: (String) -> Unit,
) {
    val colors = palette
    val here = family.descriptors.count { it.key in chosen }
    Card(onClick = onToggleOpen) {
        Row(
            modifier = Modifier.fillMaxWidth(),
            horizontalArrangement = Arrangement.SpaceBetween,
        ) {
            Text(family.label, style = TypeScale.headline, color = colors.text)
            Text(
                if (here > 0) "$here picked" else "",
                style = TypeScale.caption,
                color = colors.accent,
            )
        }
        if (isOpen) {
            // A flow of chips rather than a grid: descriptor labels run from
            // "Oak" to "Baking spice", and a fixed grid either clips the long
            // ones or wastes half a row on the short ones.
            ChipRow {
                for (descriptor in family.descriptors) {
                    Chip(descriptor.label, isOn = descriptor.key in chosen) {
                        onToggle(descriptor.key)
                    }
                }
            }
        }
    }
}
