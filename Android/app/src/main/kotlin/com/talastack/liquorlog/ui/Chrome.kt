package com.talastack.liquorlog.ui

import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.RowScope
import androidx.compose.foundation.layout.defaultMinSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.ArrowBack
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.Icon
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.OutlinedTextFieldDefaults
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.text.input.KeyboardType
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import com.talastack.liquorlog.ui.theme.Space
import com.talastack.liquorlog.ui.theme.TypeScale
import com.talastack.liquorlog.ui.theme.palette
import java.time.Instant
import java.time.ZoneId
import java.time.format.DateTimeFormatter
import java.util.Locale

/**
 * The bar on every screen that is not a tab: a way back, a title, actions.
 *
 * Deliberately not `TopAppBar`. Material's bar brings its own colour roles,
 * its own title type and its own height, and the whole point of the palette
 * is that nothing in this app picks a colour Material chose.
 */
@Composable
fun DetailBar(
    title: String,
    onBack: () -> Unit,
    actions: @Composable RowScope.() -> Unit = {},
) {
    val colors = palette
    Column {
        Row(
            modifier = Modifier
                .fillMaxWidth()
                .background(colors.background)
                .padding(horizontal = Space.s),
            verticalAlignment = Alignment.CenterVertically,
        ) {
            Icon(
                Icons.AutoMirrored.Filled.ArrowBack,
                contentDescription = "Back",
                tint = colors.accent,
                modifier = Modifier
                    .clickable(onClick = onBack)
                    .defaultMinSize(minWidth = Space.tapTarget, minHeight = Space.tapTarget)
                    .padding(Space.m)
                    .size(22.dp),
            )
            Text(
                title,
                style = TypeScale.headline,
                color = colors.text,
                maxLines = 1,
                overflow = TextOverflow.Ellipsis,
                modifier = Modifier.weight(1f).padding(horizontal = Space.s),
            )
            actions()
        }
        Box(Modifier.fillMaxWidth().height(1.dp).background(colors.line))
    }
}

/**
 * A yes-or-no question with its consequence spelled out.
 *
 * The message is not decoration: every caller here is about to do something
 * that is either irreversible or looks like it, and the difference between
 * "finished" and "removed" is the whole history of the bottle.
 */
@Composable
fun ConfirmDialog(
    title: String,
    message: String,
    confirmLabel: String,
    destructive: Boolean = false,
    onConfirm: () -> Unit,
    onDismiss: () -> Unit,
) {
    val colors = palette
    AlertDialog(
        onDismissRequest = onDismiss,
        containerColor = colors.surface,
        titleContentColor = colors.text,
        textContentColor = colors.textSecondary,
        title = { Text(title, style = TypeScale.title, color = colors.text) },
        text = { Text(message, style = TypeScale.secondary, color = colors.textSecondary) },
        confirmButton = {
            TextButton(onClick = onConfirm) {
                Text(
                    confirmLabel,
                    style = TypeScale.headline,
                    color = if (destructive) colors.bad else colors.accent,
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

/** One field and a confirm. Used wherever iOS puts a `TextField` in an alert. */
@Composable
fun TextEntryDialog(
    title: String,
    message: String,
    initial: String,
    confirmLabel: String,
    numeric: Boolean = false,
    onConfirm: (String) -> Unit,
    onDismiss: () -> Unit,
) {
    val colors = palette
    var text by remember { mutableStateOf(initial) }
    AlertDialog(
        onDismissRequest = onDismiss,
        containerColor = colors.surface,
        title = { Text(title, style = TypeScale.title, color = colors.text) },
        text = {
            Column(verticalArrangement = Arrangement.spacedBy(Space.m)) {
                Text(message, style = TypeScale.secondary, color = colors.textSecondary)
                Field(
                    value = text,
                    onValueChange = { text = it },
                    label = if (numeric) "ml" else "",
                    numeric = numeric,
                )
            }
        },
        confirmButton = {
            TextButton(
                onClick = { onConfirm(text) },
                enabled = text.isNotBlank(),
            ) {
                Text(
                    confirmLabel,
                    style = TypeScale.headline,
                    color = colors.accent.copy(alpha = if (text.isNotBlank()) 1f else 0.4f),
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

/**
 * The app's text field.
 *
 * One definition rather than the Material default per screen, because the
 * default paints its own container and indicator in Material's colours, and
 * a form built from ten of them is ten places the palette could be lost.
 */
@Composable
fun Field(
    value: String,
    onValueChange: (String) -> Unit,
    label: String,
    modifier: Modifier = Modifier,
    placeholder: String? = null,
    numeric: Boolean = false,
    decimal: Boolean = false,
    singleLine: Boolean = true,
) {
    val colors = palette
    OutlinedTextField(
        value = value,
        onValueChange = { typed ->
            // Digits only where a number is meant. A letter typed into a
            // price field is not an error to report later, it is a keystroke
            // to not accept now.
            onValueChange(
                when {
                    numeric && !decimal -> typed.filter { it.isDigit() }
                    numeric -> typed.filter { it.isDigit() || it == '.' || it == ',' }
                    else -> typed
                }
            )
        },
        label = if (label.isEmpty()) null else {
            { Text(label, style = TypeScale.secondary) }
        },
        placeholder = placeholder?.let {
            { Text(it, style = TypeScale.secondary, color = colors.textMuted) }
        },
        singleLine = singleLine,
        textStyle = TypeScale.body,
        keyboardOptions = KeyboardOptions(
            keyboardType = when {
                numeric && decimal -> KeyboardType.Decimal
                numeric -> KeyboardType.Number
                else -> KeyboardType.Text
            }
        ),
        colors = OutlinedTextFieldDefaults.colors(
            focusedTextColor = colors.text,
            unfocusedTextColor = colors.text,
            focusedBorderColor = colors.accent,
            unfocusedBorderColor = colors.line,
            focusedLabelColor = colors.accent,
            unfocusedLabelColor = colors.textSecondary,
            cursorColor = colors.accent,
            focusedContainerColor = colors.surface,
            unfocusedContainerColor = colors.surface,
        ),
        modifier = modifier.fillMaxWidth(),
    )
}

// Dates

private val shortDateFormat: DateTimeFormatter =
    DateTimeFormatter.ofPattern("d MMM yyyy", Locale.getDefault())

/**
 * "14 Sep 2026", in the device's own zone.
 *
 * Every timestamp in the database is epoch milliseconds UTC, which is what
 * makes two devices in two zones agree about ordering. Only the rendering is
 * local, and only here.
 */
fun shortDate(epochMillis: Long): String =
    Instant.ofEpochMilli(epochMillis).atZone(ZoneId.systemDefault()).format(shortDateFormat)

/**
 * Starting an infinity bottle.
 *
 * An empty vessel you fill from your other bottles. It is a bottle like any
 * other in the database -- it takes pours, it has a fill -- and it starts
 * open, because the whole point is that things go into it.
 */
@Composable
fun InfinityBottleDialog(onDismiss: () -> Unit, onStart: (String, Double) -> Unit) {
    val colors = palette
    var name by remember { mutableStateOf("") }
    var size by remember { mutableStateOf("750") }
    val volume = LocalNumber.parse(size) ?: 0.0

    AlertDialog(
        onDismissRequest = onDismiss,
        containerColor = colors.surface,
        title = { Text("Start an infinity bottle", style = TypeScale.title, color = colors.text) },
        text = {
            Column(verticalArrangement = Arrangement.spacedBy(Space.m)) {
                Text(
                    "An empty vessel you fill from your other bottles. It keeps " +
                        "track of what went in and how strong it is.",
                    style = TypeScale.secondary,
                    color = colors.textSecondary,
                )
                Field(name, { name = it }, label = "Name", placeholder = "The infinity bottle")
                Field(size, { size = it }, label = "Size in ml", numeric = true)
            }
        },
        confirmButton = {
            TextButton(onClick = { onStart(name.trim(), volume) }, enabled = volume > 0) {
                Text(
                    "Start it",
                    style = TypeScale.headline,
                    color = colors.accent.copy(alpha = if (volume > 0) 1f else 0.4f),
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
