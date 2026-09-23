package com.talastack.liquorlog.ui

import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.unit.dp
import com.talastack.liquorlog.engine.Hunt
import com.talastack.liquorlog.engine.Money
import com.talastack.liquorlog.ui.theme.Space
import com.talastack.liquorlog.ui.theme.TypeScale
import com.talastack.liquorlog.ui.theme.palette
import java.time.Instant
import kotlin.math.roundToInt

/**
 * The hunt log, and the passport.
 *
 * Both are records of going somewhere. The log answers "where should I go
 * back to, and which shop actually allocates to me"; the passport answers
 * "which of these have I stood in". Neither counts anything drunk.
 */

// The hunt log

@Composable
fun HuntLogScreen(onBack: () -> Unit) {
    val state = LocalAppState.current
    val colors = palette
    var adding by remember { mutableStateOf(false) }
    var deciding by remember { mutableStateOf<String?>(null) }

    val wished = remember(state.changeCount) { state.wishlist.wishedProductIds() }
    val sightings = remember(state.changeCount) {
        state.sightings.huntSightings { id -> state.identity(id)?.displayName }
    }
    val summary = remember(sightings, wished) { Hunt.summarise(sightings, wished) }
    val entries = remember(state.changeCount) { state.sightings.all() }
    val now = remember(state.changeCount) { Instant.now() }

    Column(Modifier.fillMaxWidth()) {
        DetailBar(
            "Hunt log",
            onBack,
            actions = {
                Text(
                    "Log one",
                    style = TypeScale.headline,
                    color = colors.accent,
                    modifier = Modifier
                        .clickable { adding = true }
                        .padding(horizontal = Space.m, vertical = Space.m),
                )
            },
        )

        LazyColumn(
            contentPadding = PaddingValues(Space.xl),
            verticalArrangement = Arrangement.spacedBy(Space.m),
        ) {
            summary.headline?.let {
                item {
                    Card { Text(it, style = TypeScale.body, color = colors.text) }
                }
            }

            if (summary.stores.isNotEmpty()) {
                item { SectionLabel("Where you looked") }
                item {
                    Card {
                        summary.stores.forEachIndexed { index, store ->
                            FactRow(
                                store.name,
                                buildString {
                                    append(store.sightings)
                                    append(if (store.sightings == 1) " sighting" else " sightings")
                                    // The number that decides where to go back
                                    // to: a shop that stocks what you want.
                                    if (store.wishlistHits > 0) {
                                        append(" · ")
                                        append(store.wishlistHits)
                                        append(" on your list")
                                    }
                                },
                                isLast = index == summary.stores.lastIndex,
                            )
                        }
                    }
                }
            }

            if (entries.isEmpty()) {
                item {
                    Empty(
                        "Nothing logged yet",
                        "Write down what you saw and where. After a few months it " +
                            "tells you which shop is worth the drive.",
                    )
                }
            } else {
                item { SectionLabel("The log") }
                items(entries, key = { it.id }) { entry ->
                    val hunt = sightings.firstOrNull { it.id == entry.id }
                    Card(onClick = { deciding = entry.id }) {
                        Row(
                            modifier = Modifier.fillMaxWidth(),
                            verticalAlignment = Alignment.Top,
                        ) {
                            Text(
                                hunt?.name ?: entry.customName ?: "Something unnamed",
                                style = TypeScale.headline,
                                color = colors.text,
                                modifier = Modifier.weight(1f),
                            )
                            entry.outcome?.let {
                                Text(
                                    it.label,
                                    style = TypeScale.caption,
                                    color = if (it == Hunt.Outcome.WON) colors.good
                                    else colors.textMuted,
                                )
                            }
                        }
                        // The engine's own sentence, so the log reads the same
                        // on both platforms.
                        Text(
                            hunt?.let { Hunt.line(it, now) } ?: entry.store,
                            style = TypeScale.secondary,
                            color = colors.textSecondary,
                        )
                        if (entry.kind == Hunt.Kind.ENTERED && entry.outcome == null) {
                            Text(
                                "Result not in yet -- tap to set it",
                                style = TypeScale.caption,
                                color = colors.accent,
                            )
                        }
                        entry.note?.let {
                            Text(it, style = TypeScale.caption, color = colors.textMuted)
                        }
                    }
                }
            }
        }
    }

    if (adding) {
        LogSightingDialog(
            onDismiss = { adding = false },
            onAdd = { name, store, kind, cents, count, note ->
                state.sightings.record(
                    customName = name,
                    store = store,
                    kind = kind,
                    cents = cents,
                    count = count,
                    note = note,
                )
                state.noteChange()
                adding = false
            },
        )
    }

    deciding?.let { id ->
        val entry = entries.firstOrNull { it.id == id }
        EntryActionsDialog(
            isLottery = entry?.kind == Hunt.Kind.ENTERED,
            onOutcome = {
                state.sightings.setOutcome(id, it)
                state.noteChange()
                deciding = null
            },
            onRemove = {
                state.sightings.remove(id)
                state.noteChange()
                deciding = null
            },
            onDismiss = { deciding = null },
        )
    }
}

@Composable
private fun LogSightingDialog(
    onDismiss: () -> Unit,
    onAdd: (String, String, Hunt.Kind, Int?, Int?, String?) -> Unit,
) {
    val colors = palette
    var name by remember { mutableStateOf("") }
    var store by remember { mutableStateOf("") }
    var kind by remember { mutableStateOf(Hunt.Kind.SEEN) }
    var price by remember { mutableStateOf("") }
    var count by remember { mutableStateOf("") }
    var note by remember { mutableStateOf("") }
    // The store is the required field, not the bottle: "three of something I
    // could not read, at this shop" is a useful entry and a nameless shop is
    // not.
    val canSave = store.isNotBlank()

    AlertDialog(
        onDismissRequest = onDismiss,
        containerColor = colors.surface,
        title = { Text("Log a sighting", style = TypeScale.title, color = colors.text) },
        text = {
            Column(verticalArrangement = Arrangement.spacedBy(Space.m)) {
                ChipRow {
                    for (option in Hunt.Kind.entries) {
                        Chip(option.label, isOn = kind == option) { kind = option }
                    }
                }
                Field(store, { store = it }, label = "Where", placeholder = "Total Wine")
                Field(name, { name = it }, label = "What", placeholder = "Weller 12")
                if (kind == Hunt.Kind.SEEN) {
                    Row(horizontalArrangement = Arrangement.spacedBy(Space.m)) {
                        Field(
                            price, { price = it }, label = "Shelf price",
                            numeric = true, decimal = true, modifier = Modifier.weight(1f),
                        )
                        Field(
                            count, { count = it }, label = "How many",
                            numeric = true, modifier = Modifier.weight(1f),
                        )
                    }
                }
                Field(note, { note = it }, label = "A note", singleLine = false)
            }
        },
        confirmButton = {
            TextButton(
                onClick = {
                    onAdd(
                        name.trim(),
                        store.trim(),
                        kind,
                        LocalNumber.parse(price)?.takeIf { it > 0 }
                            ?.let { (it * 100).roundToInt() },
                        count.toIntOrNull()?.takeIf { it > 0 },
                        note.trim().ifBlank { null },
                    )
                },
                enabled = canSave,
            ) {
                Text(
                    "Log it",
                    style = TypeScale.headline,
                    color = colors.accent.copy(alpha = if (canSave) 1f else 0.4f),
                )
            }
        },
        dismissButton = {
            TextButton(onClick = onDismiss) {
                Text("Cancel", style = TypeScale.body, color = colors.textMuted)
            }
        },
    )
}

@Composable
private fun EntryActionsDialog(
    isLottery: Boolean,
    onOutcome: (Hunt.Outcome?) -> Unit,
    onRemove: () -> Unit,
    onDismiss: () -> Unit,
) {
    val colors = palette
    AlertDialog(
        onDismissRequest = onDismiss,
        containerColor = colors.surface,
        title = { Text("This entry", style = TypeScale.title, color = colors.text) },
        text = {
            Column(verticalArrangement = Arrangement.spacedBy(Space.m)) {
                if (isLottery) {
                    Text(
                        "Set the result when it comes in.",
                        style = TypeScale.secondary,
                        color = colors.textSecondary,
                    )
                    ChipRow {
                        for (outcome in Hunt.Outcome.entries) {
                            Chip(outcome.label, isOn = false) { onOutcome(outcome) }
                        }
                        Chip("Still waiting", isOn = false) { onOutcome(null) }
                    }
                }
                QuietButton("Remove this entry", modifier = Modifier.fillMaxWidth()) {
                    onRemove()
                }
            }
        },
        confirmButton = {
            TextButton(onClick = onDismiss) {
                Text("Done", style = TypeScale.headline, color = colors.accent)
            }
        },
    )
}

// The passport

/**
 * Distilleries you have stood in, against what is on your shelf.
 *
 * A record of having been somewhere, which is why it is a list of dates and
 * not a score. Nothing here ranks anybody.
 */
@Composable
fun PassportScreen(onBack: () -> Unit) {
    val state = LocalAppState.current
    val colors = palette
    var adding by remember { mutableStateOf(false) }
    /** The visit a tap has offered to remove, waiting on a confirm. */
    var removingVisit by remember { mutableStateOf<String?>(null) }

    val visits = remember(state.changeCount) { state.sightings.visits() }
    val onShelf = remember(state.changeCount) {
        state.bottles.onShelf()
            .mapNotNull { state.distillery(it) }
            .map { it.trim().lowercase() }
            .toSet()
    }

    Column(Modifier.fillMaxWidth()) {
        DetailBar(
            "Passport",
            onBack,
            actions = {
                Text(
                    "Add",
                    style = TypeScale.headline,
                    color = colors.accent,
                    modifier = Modifier
                        .clickable { adding = true }
                        .padding(horizontal = Space.m, vertical = Space.m),
                )
            },
        )
        LazyColumn(
            contentPadding = PaddingValues(Space.xl),
            verticalArrangement = Arrangement.spacedBy(Space.m),
        ) {
            if (visits.isEmpty()) {
                item {
                    Empty(
                        "No visits yet",
                        "Add a distillery you have stood in. It marks the ones you " +
                            "also have on the shelf.",
                    )
                }
            } else {
                item {
                    Card {
                        Text(
                            if (visits.size == 1) "1 distillery visited"
                            else "${visits.size} distilleries visited",
                            style = TypeScale.body,
                            color = colors.text,
                        )
                    }
                }
                items(visits, key = { it.id }) { visit ->
                    // Tapping offers to remove it. removeVisit has been in
                    // the repository since the port with nothing calling it,
                    // so a visit added by mistake was permanent on Android
                    // and removable on iOS.
                    Card(onClick = { removingVisit = visit.id }) {
                        Row(
                            modifier = Modifier.fillMaxWidth(),
                            verticalAlignment = Alignment.Top,
                        ) {
                            Text(
                                visit.distillery,
                                style = TypeScale.headline,
                                color = colors.text,
                                modifier = Modifier.weight(1f),
                            )
                            if (visit.distillery.trim().lowercase() in onShelf) {
                                Text(
                                    "On your shelf",
                                    style = TypeScale.caption,
                                    color = colors.accent,
                                )
                            }
                        }
                        Text(
                            shortDate(visit.visited_at),
                            style = TypeScale.code,
                            color = colors.textMuted,
                        )
                        visit.note?.takeIf { it.isNotBlank() }?.let {
                            Text(it, style = TypeScale.secondary, color = colors.textSecondary)
                        }
                    }
                }
            }
        }
    }

    if (adding) {
        VisitDialog(
            onDismiss = { adding = false },
            onAdd = { distillery, note ->
                state.sightings.recordVisit(distillery = distillery, note = note)
                state.noteChange()
                adding = false
            },
        )
    }

    removingVisit?.let { id ->
        ConfirmDialog(
            title = "Remove this visit?",
            message = "It goes off the passport. For a visit added by mistake -- " +
                "somewhere you have actually stood is worth keeping.",
            confirmLabel = "Remove",
            destructive = true,
            onConfirm = {
                state.sightings.removeVisit(id)
                state.noteChange()
                removingVisit = null
            },
            onDismiss = { removingVisit = null },
        )
    }
}

@Composable
private fun VisitDialog(onDismiss: () -> Unit, onAdd: (String, String?) -> Unit) {
    val colors = palette
    var distillery by remember { mutableStateOf("") }
    var note by remember { mutableStateOf("") }

    AlertDialog(
        onDismissRequest = onDismiss,
        containerColor = colors.surface,
        title = { Text("A distillery you visited", style = TypeScale.title, color = colors.text) },
        text = {
            Column(verticalArrangement = Arrangement.spacedBy(Space.m)) {
                Field(
                    distillery, { distillery = it },
                    label = "Distillery", placeholder = "Buffalo Trace",
                )
                Field(note, { note = it }, label = "A note", singleLine = false)
            }
        },
        confirmButton = {
            TextButton(
                onClick = { onAdd(distillery.trim(), note.trim().ifBlank { null }) },
                enabled = distillery.isNotBlank(),
            ) {
                Text(
                    "Add it",
                    style = TypeScale.headline,
                    color = colors.accent.copy(
                        alpha = if (distillery.isNotBlank()) 1f else 0.4f,
                    ),
                )
            }
        },
        dismissButton = {
            TextButton(onClick = onDismiss) {
                Text("Cancel", style = TypeScale.body, color = colors.textMuted)
            }
        },
    )
}
