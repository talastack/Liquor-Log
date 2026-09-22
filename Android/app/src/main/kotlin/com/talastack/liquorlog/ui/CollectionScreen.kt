package com.talastack.liquorlog.ui

import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.horizontalScroll
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.defaultMinSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Cancel
import androidx.compose.material.icons.filled.ChevronRight
import androidx.compose.material.icons.filled.PlaylistAdd
import androidx.compose.material.icons.filled.Place
import androidx.compose.material.icons.filled.Search
import androidx.compose.material.icons.filled.SwapVert
import androidx.compose.material3.BasicAlertDialog
import androidx.compose.material3.DropdownMenu
import androidx.compose.material3.DropdownMenuItem
import androidx.compose.material3.Icon
import androidx.compose.material3.Text
import androidx.compose.material3.TextField
import androidx.compose.material3.TextFieldDefaults
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import com.talastack.liquorlog.data.BottleRepository
import com.talastack.liquorlog.engine.CollectionFilter
import com.talastack.liquorlog.engine.CollectionValue
import com.talastack.liquorlog.engine.Money
import com.talastack.liquorlog.engine.Multiples
import com.talastack.liquorlog.engine.ProductionType
import com.talastack.liquorlog.engine.ClassType
import com.talastack.liquorlog.ui.theme.Space
import com.talastack.liquorlog.ui.theme.TypeScale
import com.talastack.liquorlog.ui.theme.palette
import java.time.Instant

/**
 * What you own, with how much is left in each.
 *
 * Counts **bottles owned, never drinks had.** Apple rejects apps that
 * encourage excessive consumption, which rules out streaks, totals and
 * anything that makes drinking more feel like progress.
 *
 * The filtering, the sorting and the "1 of 3" on duplicate bottles are all
 * the engine's, not this screen's: `CollectionFilter` and `Multiples` are
 * pure functions with tests on two platforms, and this file chooses colours.
 */
@Composable
fun CollectionScreen(onOpenBottle: (String) -> Unit, onAddBottle: () -> Unit) {
    val state = LocalAppState.current
    val colors = palette
    var criteria by remember { mutableStateOf(CollectionFilter.Criteria.none) }

    // Everything, finished included. The filter decides what is shown, so
    // switching between "on the shelf" and "finished" is a pass over memory
    // and never a database round trip.
    val summaries = remember(state.changeCount) { state.bottles.all() }
    val entries = remember(state.changeCount) {
        state.bottles.customEntries().associateBy { it.id }
    }
    val rows = remember(summaries, entries) {
        summaries.map { filterRow(state, it, entries) }
    }
    val places = remember(summaries) {
        Multiples.places(
            summaries.map { summary ->
                Multiples.Bottle(
                    id = summary.id,
                    productKey = summary.bottle.catalog_product_id
                        ?: summary.bottle.custom_name ?: summary.id,
                    barrel = summary.bottle.barrel_number,
                    batch = summary.bottle.batch_number,
                    isFinished = summary.isFinished,
                )
            }
        )
    }
    val byId = remember(summaries) { summaries.associateBy { it.id } }
    val shown = remember(criteria, rows, byId) {
        CollectionFilter.apply(criteria, rows).mapNotNull { byId[it.id] }
    }

    LazyColumn(
        contentPadding = PaddingValues(
            start = Space.xl, end = Space.xl, top = Space.s, bottom = 96.dp,
        ),
        verticalArrangement = Arrangement.spacedBy(Space.m),
    ) {
        item {
            Header(
                title = if (criteria.status == CollectionFilter.Status.ON_SHELF) {
                    "On your shelf"
                } else {
                    criteria.status.label
                },
                summaries = summaries,
                shown = shown,
            )
        }

        if (summaries.isEmpty()) {
            item { EmptyShelf(onAddBottle) }
        } else {
            item {
                Finder(
                    criteria = criteria,
                    rows = rows,
                    shownCount = shown.size,
                    onChange = { criteria = it },
                )
            }

            if (shown.isEmpty()) {
                item {
                    Empty("Nothing matches", "Try fewer words, or clear the filters.")
                }
            } else {
                items(shown, key = { it.id }) { summary ->
                    BottleCard(
                        summary = summary,
                        place = places[summary.id],
                        onClick = { onOpenBottle(summary.id) },
                    )
                }
            }
        }
    }
}

@Composable
private fun Header(
    title: String,
    summaries: List<BottleRepository.Summary>,
    shown: List<BottleRepository.Summary>,
) {
    val state = LocalAppState.current
    val colors = palette
    Column(verticalArrangement = Arrangement.spacedBy(Space.s)) {
        Text(title, style = TypeScale.largeTitle, color = colors.text)

        // Bottles, not drinks. See the note on this screen.
        val onShelf = summaries.filter { !it.isFinished }
        val open = onShelf.count { it.isOpen }
        val bottles = if (onShelf.size == 1) "1 bottle" else "${onShelf.size} bottles"
        Text(
            if (open > 0) "$bottles · $open open" else bottles,
            style = TypeScale.secondary,
            color = colors.textSecondary,
        )

        // What is on the shelf COST, never what it is worth. There is no
        // market data in this app and none will be invented.
        if (state.showsValue && shown.isNotEmpty()) {
            val total = CollectionValue.onTheShelf(
                shown.map {
                    CollectionValue.Holding(
                        purchasePriceCents = it.purchasePriceCents?.toInt(),
                        isFinished = it.isFinished,
                    )
                }
            )
            Text(Money.short(total.cents), style = TypeScale.title, color = colors.accent)
            Text(total.caveat, style = TypeScale.caption, color = colors.textMuted)
        }
    }
}

/**
 * Type, narrow, order.
 *
 * The research puts the point where somebody needs this at about fifty
 * bottles, and a flat list stops working long before that.
 */
@Composable
private fun Finder(
    criteria: CollectionFilter.Criteria,
    rows: List<CollectionFilter.Row>,
    shownCount: Int,
    onChange: (CollectionFilter.Criteria) -> Unit,
) {
    val colors = palette
    Column(verticalArrangement = Arrangement.spacedBy(Space.s)) {
        Row(
            modifier = Modifier
                .fillMaxWidth()
                .clip(RoundedCornerShape(11.dp))
                .background(colors.surface),
            verticalAlignment = Alignment.CenterVertically,
        ) {
            Icon(
                Icons.Filled.Search,
                contentDescription = null,
                tint = colors.textMuted,
                modifier = Modifier.padding(start = Space.l).size(18.dp),
            )
            TextField(
                value = criteria.query,
                onValueChange = { onChange(criteria.copy(query = it)) },
                placeholder = {
                    Text(
                        "Name, distillery, barrel, store, shelf",
                        style = TypeScale.secondary,
                        color = colors.textMuted,
                        maxLines = 1,
                        overflow = TextOverflow.Ellipsis,
                    )
                },
                singleLine = true,
                textStyle = TypeScale.body,
                colors = TextFieldDefaults.colors(
                    focusedContainerColor = Color.Transparent,
                    unfocusedContainerColor = Color.Transparent,
                    focusedIndicatorColor = Color.Transparent,
                    unfocusedIndicatorColor = Color.Transparent,
                    focusedTextColor = colors.text,
                    unfocusedTextColor = colors.text,
                    cursorColor = colors.accent,
                ),
                modifier = Modifier.weight(1f),
            )
            if (criteria.query.isNotEmpty()) {
                Icon(
                    Icons.Filled.Cancel,
                    contentDescription = "Clear the search",
                    tint = colors.textMuted,
                    modifier = Modifier
                        .clickable { onChange(criteria.copy(query = "")) }
                        .padding(Space.s)
                        .size(18.dp),
                )
            }
            SortMenu(criteria.sort) { onChange(criteria.copy(sort = it)) }
            Spacer(Modifier.width(Space.s))
        }

        // Status first, because "what is open" is the question people ask
        // most. Kinds and places follow only when the shelf has them: a chip
        // that can never narrow anything is noise on a control that exists
        // to narrow.
        Row(
            modifier = Modifier.horizontalScroll(rememberScrollState()),
            horizontalArrangement = Arrangement.spacedBy(Space.s),
        ) {
            for (status in CollectionFilter.Status.entries) {
                Chip(status.label, isOn = criteria.status == status) {
                    onChange(criteria.copy(status = status))
                }
            }
        }

        val kinds = CollectionFilter.availableKinds(rows)
        val locations = CollectionFilter.locations(rows)
        if (kinds.isNotEmpty() || locations.isNotEmpty()) {
            Row(
                modifier = Modifier.horizontalScroll(rememberScrollState()),
                horizontalArrangement = Arrangement.spacedBy(Space.s),
            ) {
                for (kind in kinds) {
                    Chip(kind.label, isOn = kind in criteria.kinds) {
                        val next = criteria.kinds.toMutableSet()
                        if (!next.remove(kind)) next.add(kind)
                        onChange(criteria.copy(kinds = next))
                    }
                }
                for (place in locations) {
                    Chip(place, isOn = criteria.location == place, icon = Icons.Filled.Place) {
                        onChange(
                            criteria.copy(
                                location = if (criteria.location == place) null else place,
                            )
                        )
                    }
                }
            }
        }

        if (criteria.isNarrowing) {
            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.SpaceBetween,
                verticalAlignment = Alignment.CenterVertically,
            ) {
                Text(
                    if (shownCount == 1) "1 bottle" else "$shownCount bottles",
                    style = TypeScale.caption,
                    color = colors.textMuted,
                )
                Text(
                    "Clear",
                    style = TypeScale.caption,
                    color = colors.accent,
                    modifier = Modifier
                        .clickable {
                            // The sort survives a clear. It is how somebody
                            // likes to read the list, not part of the filter.
                            onChange(CollectionFilter.Criteria.none.copy(sort = criteria.sort))
                        }
                        .defaultMinSize(minHeight = Space.tapTarget)
                        .padding(Space.s),
                )
            }
        }
    }
}

@Composable
private fun SortMenu(sort: CollectionFilter.Sort, onPick: (CollectionFilter.Sort) -> Unit) {
    val colors = palette
    var open by remember { mutableStateOf(false) }
    Box {
        Row(
            modifier = Modifier
                .clickable { open = true }
                .defaultMinSize(minHeight = Space.tapTarget)
                .padding(horizontal = Space.s),
            horizontalArrangement = Arrangement.spacedBy(Space.xs),
            verticalAlignment = Alignment.CenterVertically,
        ) {
            Icon(
                Icons.Filled.SwapVert,
                contentDescription = "Sort by " + sort.label,
                tint = colors.accent,
                modifier = Modifier.size(16.dp),
            )
            Text(sort.label, style = TypeScale.caption, color = colors.accent)
        }
        DropdownMenu(
            expanded = open,
            onDismissRequest = { open = false },
            modifier = Modifier.background(colors.surface),
        ) {
            for (option in CollectionFilter.Sort.entries) {
                DropdownMenuItem(
                    text = {
                        Text(
                            option.label,
                            style = TypeScale.body,
                            color = if (option == sort) colors.accent else colors.text,
                        )
                    },
                    onClick = {
                        onPick(option)
                        open = false
                    },
                )
            }
        }
    }
}

/**
 * One bottle in the list.
 *
 * Fill count and millilitres always travel together -- the pour count rounds
 * to nearest, and the millilitres are what stop that rounding carrying weight
 * on its own.
 */
@Composable
fun BottleCard(
    summary: BottleRepository.Summary,
    place: Multiples.Place? = null,
    onClick: () -> Unit,
) {
    val state = LocalAppState.current
    val colors = palette

    Card(onClick = onClick) {
        Row(horizontalArrangement = Arrangement.spacedBy(Space.m)) {
            BottleMark(height = 58.dp)

            Column(
                modifier = Modifier.weight(1f),
                verticalArrangement = Arrangement.spacedBy(Space.s),
            ) {
                state.distillery(summary)?.let { SectionLabel(it) }

                Row(
                    modifier = Modifier.fillMaxWidth(),
                    verticalAlignment = Alignment.Top,
                ) {
                    Text(
                        state.name(summary),
                        style = TypeScale.title,
                        color = colors.text,
                        modifier = Modifier.weight(1f),
                    )
                    place?.label?.let { OutlineTag(it, colors.textMuted, colors.line) }
                    if (summary.isOpen && !summary.isFinished) {
                        Spacer(Modifier.width(Space.xs))
                        OutlineTag("Open", colors.accent, colors.accent)
                    }
                    if (summary.isFinished) {
                        Spacer(Modifier.width(Space.xs))
                        OutlineTag("Finished", colors.textMuted, colors.line)
                    }
                }

                summary.releaseLabel?.let {
                    Text(it, style = TypeScale.code, color = colors.textMuted)
                }
                if (summary.isSample) {
                    Text(
                        sampleLine(summary, state.ounces),
                        style = TypeScale.code,
                        color = verdictTint(
                            com.talastack.liquorlog.engine.ShelfCheckResult.Headline.HAVE_A_SAMPLE
                        ),
                    )
                }
                if (summary.isInfinity) {
                    Text(
                        summary.abv?.let {
                            String.format(
                                java.util.Locale.ROOT,
                                "Infinity bottle · %.1f proof",
                                com.talastack.liquorlog.engine.ABV(it).proof,
                            )
                        } ?: "Infinity bottle",
                        style = TypeScale.code,
                        color = colors.textMuted,
                    )
                }

                FillBar(summary.status, ounces = state.ounces)

                Row(
                    horizontalArrangement = Arrangement.spacedBy(Space.m),
                    verticalAlignment = Alignment.CenterVertically,
                ) {
                    summary.latestRating?.let { RatingChip(it) }
                    summary.costPerPourCents?.let {
                        Text(
                            Money.short(it) + " a pour",
                            style = TypeScale.code,
                            color = colors.textMuted,
                        )
                    }
                }

                // People use this to dig out a bottle they liked and have not
                // poured from in months. It is a fact about the bottle, never
                // a nudge to drink: no streak, no "it has been too long".
                lastPourLine(summary)?.let {
                    Text(it, style = TypeScale.caption, color = colors.textMuted)
                }
                summary.storageLocation?.let {
                    Text(it, style = TypeScale.caption, color = colors.textMuted)
                }
            }
        }
    }
}

@Composable
private fun OutlineTag(text: String, textColor: Color, borderColor: Color) {
    val shape = RoundedCornerShape(5.dp)
    Text(
        text,
        style = TypeScale.caption,
        color = textColor,
        modifier = Modifier
            .clip(shape)
            .border(1.dp, borderColor, shape)
            .padding(horizontal = Space.s, vertical = 3.dp),
    )
}

/**
 * Nil for a bottle never poured from -- "never poured" on a sealed bottle
 * states the obvious, and on an open one it reads as a reproach.
 */
private fun lastPourLine(summary: BottleRepository.Summary): String? {
    val days = summary.daysSinceLastPour() ?: return null
    return when {
        days == 0 -> "Last poured today"
        days == 1 -> "Last poured yesterday"
        days < 30 -> "Last poured $days days ago"
        days < 60 -> "Last poured about a month ago"
        days < 365 -> "Last poured ${days / 30} months ago"
        else -> "Last poured over a year ago"
    }
}

/**
 * "Sample · 50 ml · from Mike". The size is the fact that separates a sample
 * from a bottle of the same name on the shelf.
 */
private fun sampleLine(summary: BottleRepository.Summary, ounces: Boolean): String {
    val parts = mutableListOf("Sample", VolumeDisplay.text(summary.volumeMl, ounces))
    summary.bottle.sample_from?.takeIf { it.isNotBlank() }?.let { parts.add("from " + it) }
    return parts.joinToString(" · ")
}

/**
 * The three ways in, from an empty shelf.
 *
 * The research's first-ranked finding is that getting an existing collection
 * in is the adoption barrier, so an empty screen offers the bulk paths too,
 * not just one bottle at a time. Two of the three are honest about not being
 * built on this platform yet rather than being hidden.
 */
@Composable
private fun EmptyShelf(onAddBottle: () -> Unit) {
    val colors = palette
    Column(
        modifier = Modifier.fillMaxWidth().padding(top = 48.dp),
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.spacedBy(Space.l),
    ) {
        BottleMark(height = 84.dp)
        Text("Nothing here yet", style = TypeScale.title, color = colors.text)
        Text(
            "A shelf of two hundred should not take two hundred forms.",
            style = TypeScale.secondary,
            color = colors.textMuted,
            textAlign = androidx.compose.ui.text.style.TextAlign.Center,
        )
        WayIn(
            "Add one bottle",
            "Search the catalogue or type it in",
            Icons.Filled.PlaylistAdd,
            highlighted = true,
            onClick = onAddBottle,
        )
    }
}

@Composable
private fun WayIn(
    title: String,
    detail: String,
    icon: androidx.compose.ui.graphics.vector.ImageVector,
    highlighted: Boolean = false,
    onClick: () -> Unit,
) {
    val colors = palette
    Card(onClick = onClick, borderColor = if (highlighted) colors.accent else null) {
        Row(
            horizontalArrangement = Arrangement.spacedBy(Space.m),
            verticalAlignment = Alignment.CenterVertically,
        ) {
            Icon(
                icon,
                contentDescription = null,
                tint = if (highlighted) colors.accent else colors.textSecondary,
                modifier = Modifier.size(24.dp),
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

/**
 * A bottle flattened for the engine's filter.
 *
 * Class and production come from the catalogue for a catalogue bottle and
 * from the custom entry for a typed one, so both filter the same way.
 */
internal fun filterRow(
    state: AppState,
    summary: BottleRepository.Summary,
    entries: Map<String, com.talastack.liquorlog.data.Custom_catalog_entries>,
): CollectionFilter.Row {
    val bottle = summary.bottle
    val product = state.product(bottle.catalog_product_id)
    val entry = bottle.catalog_product_id?.let { entries[it] }
    return CollectionFilter.Row(
        id = bottle.id,
        name = state.name(summary),
        distillery = state.distillery(summary) ?: entry?.distillery,
        extraSearchText = listOfNotNull(
            summary.releaseLabel, bottle.barrel_number, bottle.batch_number,
            bottle.pick_store, bottle.purchase_store, bottle.pick_group,
            bottle.custom_name, bottle.sample_from,
        ),
        classType = product?.classType
            ?: entry?.class_type?.let { ClassType.fromStorageKey(it) },
        productionType = product?.productionType
            ?: entry?.production_type?.let { ProductionType.fromStorageKey(it) }
            ?: ProductionType.UNSPECIFIED,
        isBarrelProof = product?.isBarrelProof ?: (entry?.is_barrel_proof == 1L),
        isBottledInBond = product?.isBottledInBond ?: (entry?.is_bottled_in_bond == 1L),
        isStorePick = summary.isStorePick,
        isOpen = summary.isOpen,
        isFinished = summary.isFinished,
        isSample = summary.isSample,
        isInfinity = summary.isInfinity,
        storageLocation = bottle.storage_location,
        addedAt = Instant.ofEpochMilli(bottle.created_at),
        lastPouredAt = summary.lastPouredAt?.let { Instant.ofEpochMilli(it) },
        rating = summary.latestRating,
        fillFraction = if (summary.status.capacityMilliliters > 0) {
            summary.status.remainingMilliliters / summary.status.capacityMilliliters
        } else {
            0.0
        },
    )
}
