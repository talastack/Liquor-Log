package com.talastack.liquorlog.ui

import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.ListAlt
import androidx.compose.material.icons.filled.BarChart
import androidx.compose.material.icons.automirrored.filled.TrendingFlat
import androidx.compose.material.icons.filled.CalendarMonth
import androidx.compose.material.icons.filled.Casino
import androidx.compose.material.icons.filled.FileDownload
import androidx.compose.material.icons.filled.FileUpload
import androidx.compose.material.icons.filled.ChevronRight
import androidx.compose.material.icons.filled.Insights
import androidx.compose.material.icons.filled.People
import androidx.compose.material.icons.filled.Place
import androidx.compose.material.icons.filled.Search
import androidx.compose.material.icons.filled.LibraryBooks
import androidx.compose.material.icons.filled.Security
import androidx.compose.material.icons.filled.StarBorder
import androidx.compose.material.icons.filled.TextFields
import androidx.compose.material.icons.filled.WineBar
import androidx.compose.material3.Icon
import androidx.compose.material3.Switch
import androidx.compose.material3.SwitchDefaults
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.remember
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.unit.dp
import com.talastack.liquorlog.ui.theme.Look
import com.talastack.liquorlog.ui.theme.Space
import com.talastack.liquorlog.ui.theme.TypeScale
import com.talastack.liquorlog.ui.theme.palette

/**
 * Everything that is not one of the three main tabs.
 *
 * The tools are listed in the iOS order. **What is not built on Android yet
 * is listed too, and says so**, rather than being hidden: a person comparing
 * the two phones should be able to see what is missing, and an app that
 * quietly has fewer features reads as a broken one.
 */
@Composable
fun MoreScreen(onOpen: (String) -> Unit) {
    val state = LocalAppState.current
    val colors = palette
    val onShelf = remember(state.changeCount) { state.bottles.countOnShelf() }

    LazyColumn(
        contentPadding = PaddingValues(
            start = Space.xl, end = Space.xl, top = Space.s, bottom = 96.dp,
        ),
        verticalArrangement = Arrangement.spacedBy(Space.m),
    ) {
        item { Text("More", style = TypeScale.largeTitle, color = colors.text) }

        item { SectionLabel("Tools") }
        item {
            ToolRow(
                "Decode a code",
                "Four Roses recipes, Elijah Craig batches",
                Icons.Filled.TextFields,
            ) { onOpen(Route.CODE_DECODER) }
        }
        item {
            ToolRow(
                "Browse the catalogue",
                "Every product it knows, distillery by distillery, against your shelf",
                Icons.Filled.LibraryBooks,
            ) { onOpen(Route.CATALOG) }
        }
        item {
            ToolRow(
                "Your collection",
                "What is on your shelf, at a glance",
                Icons.Filled.BarChart,
            ) { onOpen(Route.STATS) }
        }
        item {
            ToolRow(
                "What's open",
                "A menu for guests, without the prices",
                Icons.AutoMirrored.Filled.ListAlt,
            ) { onOpen(Route.POUR_MENU) }
        }
        item {
            ToolRow(
                "Tonight",
                "The IBA's cocktails you can make from what is open",
                Icons.Filled.WineBar,
            ) { onOpen(Route.COCKTAILS) }
        }
        item {
            ToolRow(
                "Pick my pour",
                "Something open you have not had in a while",
                Icons.Filled.Casino,
            ) { onOpen(Route.PICK_MY_POUR) }
        }
        item {
            ToolRow(
                "Your palate",
                "What your tastings say: the words you reach for, what rates highest",
                Icons.Filled.Insights,
            ) { onOpen(Route.PALATE) }
        }
        item {
            ToolRow(
                "Try next",
                "Related to what you rated well, and not yet had -- each with its reason",
                Icons.AutoMirrored.Filled.TrendingFlat,
            ) { onOpen(Route.TRY_NEXT) }
        }
        item {
            ToolRow(
                "Wishlist",
                "Bottles you want, and what you would pay",
                Icons.Filled.StarBorder,
            ) { onOpen(Route.WISHLIST) }
        }
        item {
            ToolRow(
                "Hunt log",
                "Where you looked, what was on the shelf, the lotteries you entered",
                Icons.Filled.Search,
            ) { onOpen(Route.HUNT_LOG) }
        }
        item {
            ToolRow(
                "Passport",
                "The distilleries you have stood in, against your shelf",
                Icons.Filled.Place,
            ) { onOpen(Route.PASSPORT) }
        }
        item {
            ToolRow(
                "People",
                "Who sent you samples, who you poured for, whose turn it is",
                Icons.Filled.People,
            ) { onOpen(Route.PEOPLE) }
        }
        item {
            ToolRow(
                "Your year",
                "What was collected and written this year, in a few sentences",
                Icons.Filled.CalendarMonth,
            ) { onOpen(Route.YEAR) }
        }
        item { SectionLabel("Your data") }
        item {
            ToolRow(
                "Export",
                "Every bottle, tasting and pour as CSV. Never charged for.",
                Icons.Filled.FileDownload,
            ) { onOpen(Route.EXPORT) }
        }
        item {
            ToolRow(
                "Import",
                "A CSV from wherever you kept the collection before",
                Icons.Filled.FileUpload,
            ) { onOpen(Route.IMPORT) }
        }
        item {
            ToolRow(
                "Insurance report",
                "What you own and what it cost, for a policy schedule",
                Icons.Filled.Security,
            ) { onOpen(Route.INSURANCE) }
        }

        item { SectionLabel("Money") }
        item {
            SwitchRow(
                "Show what the shelf cost",
                "Off by default. Some people want the figure and some actively " +
                    "do not, and a total nobody asked for is the version that causes harm.",
                state.showsValue,
            ) { state.showValue(it) }
        }

        item { SectionLabel("Units") }
        item {
            SwitchRow(
                "Show ounces",
                "Millilitres are what is stored and exported, on every device. " +
                    "This changes only what you read.",
                state.ounces,
            ) { state.pick(it) }
        }

        item { SectionLabel("Look") }
        for (option in Look.entries) {
            item { LookRow(option, selected = option == state.look) { state.pick(option) } }
        }

        item { SectionLabel("Your collection") }
        item {
            Card {
                Text("$onShelf on the shelf.", style = TypeScale.body, color = colors.text)
                Text(
                    "Counted in bottles, never in drinks. Nothing in this app goes " +
                        "up because somebody drank more.",
                    style = TypeScale.secondary,
                    color = colors.textMuted,
                )
            }
        }

        item { SectionLabel("Not built on Android yet") }
        item {
            Card {
                for (missing in NOT_YET) {
                    Text("• $missing", style = TypeScale.secondary, color = colors.textMuted)
                }
                Text(
                    "All of it exists in the engine and is tested on this platform; " +
                        "none of it has a screen here yet.",
                    style = TypeScale.caption,
                    color = colors.textMuted,
                    modifier = Modifier.padding(top = Space.s),
                )
            }
        }

        item { SectionLabel("Data on this phone") }
        item {
            Card {
                Text(
                    if (state.catalog.products.isEmpty()) {
                        "The catalogue could not be read."
                    } else {
                        "${state.catalog.products.size} products in the catalogue."
                    },
                    style = TypeScale.secondary,
                    color = colors.textSecondary,
                )
                Text(
                    state.wheel?.let { "${it.allDescriptors.size} flavour descriptors." }
                        ?: "The flavour wheel could not be read.",
                    style = TypeScale.secondary,
                    color = colors.textSecondary,
                )
                Text(
                    "Both ship inside the app. Nothing here makes a network call, " +
                        "with or without an account.",
                    style = TypeScale.caption,
                    color = colors.textMuted,
                )
            }
        }
    }
}

// What this screen says is missing has to keep matching what is missing.
// Infinity bottles were on this list after they had been built, which is a
// worse failure than the gap itself: the app was telling somebody a feature
// was absent while it sat two taps away on their own bottle.
private val NOT_YET = listOf(
    "Sync, sign-in and a shared shelf",
    "Label scanning and bulk shelf entry",
    "Price history and the community price check",
    "Backup and restore",
    "Flights and the shelf walk",
)

@Composable
private fun ToolRow(
    title: String,
    detail: String,
    icon: ImageVector,
    onClick: () -> Unit,
) {
    val colors = palette
    Card(onClick = onClick) {
        Row(
            horizontalArrangement = Arrangement.spacedBy(Space.m),
            verticalAlignment = Alignment.CenterVertically,
        ) {
            Icon(
                icon,
                contentDescription = null,
                tint = colors.textSecondary,
                modifier = Modifier.size(22.dp),
            )
            Column(modifier = Modifier.weight(1f)) {
                Text(title, style = TypeScale.body, color = colors.text)
                Text(detail, style = TypeScale.caption, color = colors.textMuted)
            }
            Icon(
                Icons.Filled.ChevronRight,
                contentDescription = null,
                tint = colors.textMuted,
                modifier = Modifier.size(18.dp),
            )
        }
    }
}

@Composable
private fun SwitchRow(
    title: String,
    detail: String,
    checked: Boolean,
    onChange: (Boolean) -> Unit,
) {
    val colors = palette
    Card {
        Row(
            modifier = Modifier.fillMaxWidth(),
            horizontalArrangement = Arrangement.spacedBy(Space.m),
            verticalAlignment = Alignment.CenterVertically,
        ) {
            Text(
                title,
                style = TypeScale.body,
                color = colors.text,
                modifier = Modifier.weight(1f),
            )
            Switch(
                checked = checked,
                onCheckedChange = onChange,
                colors = SwitchDefaults.colors(
                    checkedThumbColor = colors.onAccent,
                    checkedTrackColor = colors.accent,
                    uncheckedThumbColor = colors.textMuted,
                    uncheckedTrackColor = colors.surfaceRaised,
                    uncheckedBorderColor = colors.line,
                ),
            )
        }
        Text(detail, style = TypeScale.caption, color = colors.textMuted)
    }
}

@Composable
private fun LookRow(look: Look, selected: Boolean, onClick: () -> Unit) {
    val colors = palette
    Card(onClick = onClick, borderColor = if (selected) colors.accent else null) {
        Text(look.display, style = TypeScale.headline, color = colors.text)
        Text(look.line, style = TypeScale.secondary, color = colors.textSecondary)
    }
}
