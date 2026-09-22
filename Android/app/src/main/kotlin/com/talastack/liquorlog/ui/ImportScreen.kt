package com.talastack.liquorlog.ui

import android.net.Uri
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalContext
import com.talastack.liquorlog.engine.ABV
import com.talastack.liquorlog.engine.CollectionImport
import com.talastack.liquorlog.engine.Money
import com.talastack.liquorlog.ui.theme.Space
import com.talastack.liquorlog.ui.theme.TypeScale
import com.talastack.liquorlog.ui.theme.palette

/**
 * Somebody else's spreadsheet, read into the collection.
 *
 * The research's first-ranked adoption barrier is getting an existing
 * collection in: a shelf of two hundred should not take two hundred forms.
 *
 * **Nothing is written until the mapping has been shown.** The engine reads
 * the header and guesses which column is which -- "Whiskey" as the name,
 * "Cost" as the price -- and a wrong guess silently importing two hundred
 * bottles under the wrong field is far worse than one that asks first. So
 * the plan is rendered, with the guesses named, and the import happens on a
 * second tap.
 */
@Composable
fun ImportScreen(onBack: () -> Unit) {
    val state = LocalAppState.current
    val context = LocalContext.current
    val colors = palette

    var plan by remember { mutableStateOf<CollectionImport.Plan?>(null) }
    var error by remember { mutableStateOf<String?>(null) }
    var imported by remember { mutableStateOf<Int?>(null) }

    val picker = rememberLauncherForActivityResult(
        ActivityResultContracts.OpenDocument()
    ) { uri: Uri? ->
        if (uri == null) return@rememberLauncherForActivityResult
        imported = null
        try {
            val text = context.contentResolver.openInputStream(uri)
                ?.bufferedReader()
                ?.use { it.readText() }
            if (text.isNullOrBlank()) {
                error = "That file is empty."
                plan = null
            } else {
                plan = CollectionImport.plan(text)
                error = null
            }
        } catch (e: Exception) {
            // A file the picker handed over but cannot be read: a cloud file
            // that never downloaded, a permission that expired.
            error = "That file could not be read. " + (e.message ?: "")
            plan = null
        }
    }

    Column(Modifier.fillMaxWidth()) {
        DetailBar("Import", onBack)
        LazyColumn(
            contentPadding = PaddingValues(Space.xl),
            verticalArrangement = Arrangement.spacedBy(Space.m),
        ) {
            item {
                Text(
                    "A CSV from wherever you kept the collection before. Columns " +
                        "are matched by name -- Bottle, Proof, Price and the like -- " +
                        "and what it matched is shown before anything is written.",
                    style = TypeScale.secondary,
                    color = colors.textSecondary,
                )
            }

            item {
                AccentButton("Choose a file", modifier = Modifier.fillMaxWidth()) {
                    // Not only text/csv: plenty of exporters hand out
                    // application/vnd.ms-excel or octet-stream for a .csv,
                    // and a picker that hides the file somebody is looking
                    // at is a dead end with no explanation.
                    picker.launch(arrayOf("text/csv", "text/comma-separated-values", "text/plain", "*/*"))
                }
            }

            error?.let {
                item {
                    Card(borderColor = colors.bad) {
                        Text("Could not read it", style = TypeScale.headline, color = colors.text)
                        Text(it, style = TypeScale.secondary, color = colors.textMuted)
                    }
                }
            }

            imported?.let { count ->
                item {
                    Card {
                        Text(
                            if (count == 1) "Added 1 bottle" else "Added $count bottles",
                            style = TypeScale.headline,
                            color = colors.text,
                        )
                        Text(
                            "They are on the Collection tab. Nothing was overwritten: " +
                                "an import only adds.",
                            style = TypeScale.caption,
                            color = colors.textMuted,
                        )
                    }
                }
            }

            plan?.let { p ->
                item { SectionLabel("What it matched") }
                item {
                    Card {
                        if (p.mapping.isEmpty()) {
                            Text(
                                "No column in that file looks like a bottle name, so " +
                                    "nothing can be read from it.",
                                style = TypeScale.secondary,
                                color = colors.textMuted,
                            )
                        } else {
                            // Named so a wrong guess can be caught before it
                            // lands, rather than found weeks later.
                            val entries = p.mapping.entries.toList()
                            entries.forEachIndexed { index, (field, column) ->
                                FactRow(
                                    column,
                                    "read as " + field.storageKey,
                                    isLast = index == entries.lastIndex,
                                )
                            }
                        }
                    }
                }

                item {
                    Card {
                        Text(
                            if (p.rows.size == 1) "1 bottle to add"
                            else "${p.rows.size} bottles to add",
                            style = TypeScale.headline,
                            color = colors.text,
                        )
                        if (p.skippedLines.isNotEmpty()) {
                            // Reported by line, never guessed at. A row with
                            // no name cannot be found again once it is in.
                            Text(
                                (if (p.skippedLines.size == 1) "1 row has no name: line "
                                else "${p.skippedLines.size} rows have no name: lines ") +
                                    p.skippedLines.take(12).joinToString(", ") +
                                    if (p.skippedLines.size > 12) "…" else "",
                                style = TypeScale.caption,
                                color = colors.textMuted,
                            )
                        }
                    }
                }

                if (p.rows.isNotEmpty()) {
                    item {
                        AccentButton(
                            if (p.rows.size == 1) "Add it" else "Add all ${p.rows.size}",
                            modifier = Modifier.fillMaxWidth(),
                        ) {
                            var count = 0
                            for (row in p.rows) {
                                state.bottles.add(
                                    name = row.name,
                                    // 750 when the file did not say. Every
                                    // pour count in the app derives from it,
                                    // so it cannot be left absent.
                                    volumeMl = row.volumeMilliliters ?: 750.0,
                                    abv = row.proof?.let { ABV.fromProof(it).percent },
                                    batchNumber = row.batch,
                                    barrelNumber = row.barrel,
                                    purchasePriceCents = row.paidCents?.toLong(),
                                    purchaseStore = row.store,
                                    storageLocation = row.storageLocation,
                                    isSample = row.isSample,
                                    sampleFrom = row.sampleFrom,
                                    openNow = row.isOpen,
                                )
                                count += 1
                            }
                            state.noteChange()
                            imported = count
                            plan = null
                        }
                    }

                    item { SectionLabel("The first few") }
                    items(p.rows.take(10), key = { it.line }) { row ->
                        Card {
                            Text(row.name, style = TypeScale.headline, color = colors.text)
                            Text(
                                listOfNotNull(
                                    row.volumeMilliliters?.let { "${it.toInt()} ml" },
                                    row.proof?.let {
                                        String.format(java.util.Locale.ROOT, "%.1f proof", it)
                                    },
                                    row.paidCents?.let { Money.short(it) },
                                    row.store,
                                    if (row.isSample) "sample" else null,
                                    if (row.isFinished) "finished" else if (row.isOpen) "open" else null,
                                ).joinToString(" · "),
                                style = TypeScale.caption,
                                color = colors.textMuted,
                            )
                        }
                    }
                }
            }
        }
    }
}
