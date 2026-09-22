package com.talastack.liquorlog.ui

import android.content.Context
import android.content.Intent
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalContext
import androidx.core.content.FileProvider
import com.talastack.liquorlog.ui.theme.Space
import com.talastack.liquorlog.ui.theme.TypeScale
import com.talastack.liquorlog.ui.theme.palette
import java.io.File
import java.time.LocalDate

/**
 * Your data, out of the app, in a format anything can read.
 *
 * **Never charged for, on either platform.** Paywalling export is cited by
 * name in the research as a reason people abandoned the app they used
 * before; it costs almost nothing to provide and it is the strongest signal
 * there is that the collection belongs to the person who typed it. Nothing
 * in this app is charged for now, so the principle is just the shape of the
 * screen: three files, complete, no account.
 *
 * The columns are the iOS columns in the iOS order, so a file written on one
 * phone reads on the other.
 */
@Composable
fun ExportScreen(onBack: () -> Unit) {
    val state = LocalAppState.current
    val context = LocalContext.current
    val colors = palette
    var lastWritten by remember { mutableStateOf<String?>(null) }

    val export = state.export
    val bottleCount = remember(state.changeCount) { state.bottles.all().size }
    val tastingCount = remember(state.changeCount) { state.tastings.allDetails().size }

    Column(Modifier.fillMaxWidth()) {
        DetailBar("Export", onBack)
        LazyColumn(
            contentPadding = PaddingValues(Space.xl),
            verticalArrangement = Arrangement.spacedBy(Space.m),
        ) {
            item {
                Text(
                    "Everything you have recorded, as CSV. It opens in any " +
                        "spreadsheet, and it is yours whether or not you ever " +
                        "sign in.",
                    style = TypeScale.secondary,
                    color = colors.textSecondary,
                )
            }

            item {
                ExportRow(
                    title = "The collection",
                    detail = if (bottleCount == 1) "1 bottle, finished ones included"
                    else "$bottleCount bottles, finished ones included",
                    enabled = bottleCount > 0,
                ) {
                    lastWritten = share(
                        context,
                        "pour-memo-collection",
                        export.bottlesCsv(
                            name = { state.name(it) },
                            distillery = { state.distillery(it) },
                            kind = { summary ->
                                val product = state.product(summary.bottle.catalog_product_id)
                                product?.classType?.label to
                                    product?.productionType?.label
                            },
                        ),
                    )
                }
            }

            item {
                val names = remember(state.changeCount) {
                    state.bottles.all().associate { it.id to state.name(it) }
                }
                ExportRow(
                    title = "Tastings",
                    detail = if (tastingCount == 1) "1 tasting, with its flavour picks"
                    else "$tastingCount tastings, with their flavour picks",
                    enabled = tastingCount > 0,
                ) {
                    lastWritten = share(
                        context,
                        "pour-memo-tastings",
                        export.tastingsCsv(
                            name = { names[it] ?: it },
                            // The wheel's labels, not its keys: a spreadsheet
                            // column reading "charredOak" is not the export
                            // of a tasting note, it is the export of an id.
                            label = { key -> state.wheel?.descriptor(key)?.label ?: key },
                        ),
                    )
                }
            }

            item {
                val names = remember(state.changeCount) {
                    state.bottles.all().associate { it.id to state.name(it) }
                }
                ExportRow(
                    title = "Pours",
                    detail = "Every pour, which is where the fill levels come from",
                    enabled = bottleCount > 0,
                ) {
                    lastWritten = share(
                        context,
                        "pour-memo-pours",
                        export.poursCsv(name = { names[it] ?: it }),
                    )
                }
            }

            lastWritten?.let { name ->
                item {
                    Card {
                        Text("Wrote $name", style = TypeScale.headline, color = colors.text)
                        Text(
                            "Pick where it goes from the sheet. The file stays in " +
                                "the app's own folder until you do.",
                            style = TypeScale.caption,
                            color = colors.textMuted,
                        )
                    }
                }
            }

        }
    }
}

@Composable
private fun ExportRow(
    title: String,
    detail: String,
    enabled: Boolean,
    onClick: () -> Unit,
) {
    val colors = palette
    Card {
        Text(title, style = TypeScale.headline, color = colors.text)
        Text(detail, style = TypeScale.secondary, color = colors.textMuted)
        AccentButton(
            "Export",
            modifier = Modifier.fillMaxWidth(),
            enabled = enabled,
            onClick = onClick,
        )
    }
}

/**
 * Writes the file and hands it to the share sheet.
 *
 * Through a `FileProvider`, not a raw path: Android has refused `file://`
 * URIs across app boundaries since Nougat, and the alternative is asking for
 * storage permission the app does not otherwise need and should not have.
 *
 * Returns the file name, so the screen can say what it wrote.
 */
private fun share(context: Context, stem: String, csv: String): String {
    val name = stem + "-" + LocalDate.now() + ".csv"
    val dir = File(context.cacheDir, "export").apply { mkdirs() }
    val file = File(dir, name)
    file.writeText(csv)

    val uri = FileProvider.getUriForFile(context, context.packageName + ".files", file)
    val intent = Intent(Intent.ACTION_SEND).apply {
        type = "text/csv"
        putExtra(Intent.EXTRA_STREAM, uri)
        addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
    }
    context.startActivity(Intent.createChooser(intent, "Export").apply {
        addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
    })
    return name
}
