package com.talastack.liquorlog.ui

import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.platform.LocalClipboardManager
import androidx.compose.ui.text.AnnotatedString
import androidx.compose.ui.unit.dp
import com.talastack.liquorlog.data.BottleRepository
import com.talastack.liquorlog.data.TastingRepository
import com.talastack.liquorlog.engine.ABV
import com.talastack.liquorlog.engine.BatchCode
import com.talastack.liquorlog.engine.ClassType
import com.talastack.liquorlog.engine.Cocktails
import com.talastack.liquorlog.engine.CollectionStats
import com.talastack.liquorlog.engine.InsuranceReport
import com.talastack.liquorlog.engine.Money
import com.talastack.liquorlog.engine.PickMyPour
import com.talastack.liquorlog.engine.PourMenu
import com.talastack.liquorlog.engine.RecipeCode
import com.talastack.liquorlog.engine.YearInReview
import com.talastack.liquorlog.ui.theme.Space
import com.talastack.liquorlog.ui.theme.TypeScale
import com.talastack.liquorlog.ui.theme.palette
import java.time.Instant
import java.time.ZoneId
import java.util.Locale
import kotlin.random.Random

/**
 * The tools reached from More.
 *
 * All eight are the engine doing the work: every number, ranking, match and
 * decoded code comes from a pure function with tests behind it, and these
 * screens lay it out. Where a tool has no data yet it says what it needs,
 * rather than showing an empty frame.
 */

// Browse the catalogue

@Composable
fun CatalogBrowseScreen(onBack: () -> Unit) {
    val state = LocalAppState.current
    val colors = palette
    var query by remember { mutableStateOf("") }

    val owned = remember(state.changeCount) {
        state.bottles.all().mapNotNull { it.bottle.catalog_product_id }.toSet()
    }
    val byDistillery = remember(state.catalog, query) {
        state.catalog.products
            .filter {
                query.isBlank() ||
                    it.identity.displayName.contains(query, ignoreCase = true) ||
                    it.distillery.contains(query, ignoreCase = true)
            }
            .groupBy { it.distillery.ifBlank { "Unattributed" } }
            .toSortedMap(String.CASE_INSENSITIVE_ORDER)
    }

    Column(Modifier.fillMaxWidth()) {
        DetailBar("The catalogue", onBack)
        LazyColumn(
            contentPadding = PaddingValues(Space.xl),
            verticalArrangement = Arrangement.spacedBy(Space.m),
        ) {
            item {
                Field(query, { query = it }, label = "Search", placeholder = "Heaven Hill, Weller")
            }
            item {
                Text(
                    "${state.catalog.products.size} products, " +
                        "${byDistillery.size} distilleries. Every one carries the " +
                        "source it came from.",
                    style = TypeScale.caption,
                    color = colors.textMuted,
                )
            }
            for ((distillery, products) in byDistillery) {
                item(key = "head-" + distillery) { SectionLabel(distillery) }
                items(products, key = { it.id }) { product ->
                    Card {
                        Row(modifier = Modifier.fillMaxWidth()) {
                            Text(
                                product.identity.displayName,
                                style = TypeScale.headline,
                                color = colors.text,
                                modifier = Modifier.weight(1f),
                            )
                            if (product.id in owned) {
                                Text("On your shelf", style = TypeScale.caption, color = colors.accent)
                            }
                        }
                        Text(
                            product.classType.label,
                            style = TypeScale.secondary,
                            color = colors.textSecondary,
                        )
                        Text(
                            strengthLine(product.abv, product.isBarrelProof),
                            style = TypeScale.code,
                            color = colors.textMuted,
                        )
                        // The source is part of the fact, never a footnote.
                        // An unsourced claim is a rumour, and this app does
                        // not carry rumours.
                        Text(
                            "Source: " + product.source.ifBlank { "not recorded" },
                            style = TypeScale.caption,
                            color = colors.textMuted,
                        )
                    }
                }
            }
        }
    }
}

// Your collection, at a glance

@Composable
fun StatsScreen(onBack: () -> Unit) {
    val state = LocalAppState.current
    val colors = palette
    val summary = remember(state.changeCount) {
        CollectionStats.summarise(
            state.bottles.all().map { statsEntry(state, it) }
        )
    }

    Column(Modifier.fillMaxWidth()) {
        DetailBar("Your collection", onBack)
        LazyColumn(
            contentPadding = PaddingValues(Space.xl),
            verticalArrangement = Arrangement.spacedBy(Space.m),
        ) {
            item { SectionLabel("Bottles") }
            item {
                Card {
                    // Bottles owned, never drinks had. Finished is a plain
                    // number with no celebration attached.
                    FactRow("On the shelf", summary.onShelf.toString())
                    FactRow("Open", summary.open.toString())
                    FactRow("Sealed", summary.sealed.toString())
                    FactRow("Samples", summary.samples.toString())
                    FactRow("Store picks", summary.picks.toString())
                    FactRow("Finished", summary.finished.toString(), isLast = true)
                }
            }

            if (summary.byClass.isNotEmpty()) {
                item { SectionLabel("By class") }
                item { SliceList(summary.byClass, summary.onShelf) }
            }
            if (summary.byDistillery.isNotEmpty()) {
                item { SectionLabel("By distillery") }
                item { SliceList(summary.byDistillery.take(10), summary.onShelf) }
            }
            if (summary.byStrength.isNotEmpty()) {
                item { SectionLabel("By strength") }
                item { SliceList(summary.byStrength, summary.onShelf) }
            }
            if (summary.byPlace.isNotEmpty()) {
                item { SectionLabel("Where they are") }
                item { SliceList(summary.byPlace, summary.onShelf) }
            }
            if (summary.addedByYear.isNotEmpty()) {
                item { SectionLabel("Added by year") }
                item { SliceList(summary.addedByYear, summary.addedByYear.sumOf { it.count }) }
            }

            item { SectionLabel("Notable") }
            item {
                Card {
                    summary.highestProof?.let {
                        FactRow(
                            "Strongest",
                            String.format(Locale.ROOT, "%.1f proof", ABV(it).proof),
                        )
                    }
                    summary.oldestStatedAgeMonths?.let {
                        FactRow("Oldest stated age", "${it / 12} years")
                    }
                    summary.longestOpen?.let {
                        // A fact about oxidation, not a prompt to finish it.
                        FactRow("Open longest", "${it.name} · ${it.value} days")
                    }
                    FactRow("Distilleries", summary.distilleryCount.toString())
                    FactRow("Classes", summary.classCount.toString(), isLast = true)
                }
            }
        }
    }
}

@Composable
private fun SliceList(slices: List<CollectionStats.Slice>, of: Int) {
    val colors = palette
    Card {
        for (slice in slices) {
            Column(modifier = Modifier.fillMaxWidth().padding(vertical = Space.xs)) {
                Row(
                    modifier = Modifier.fillMaxWidth(),
                    horizontalArrangement = Arrangement.SpaceBetween,
                ) {
                    Text(slice.label, style = TypeScale.secondary, color = colors.text)
                    Text(
                        slice.count.toString(),
                        style = TypeScale.code,
                        color = colors.textSecondary,
                    )
                }
                Box(
                    modifier = Modifier
                        .fillMaxWidth()
                        .height(4.dp)
                        .clip(RoundedCornerShape(2.dp))
                        .background(colors.surfaceRaised),
                ) {
                    Box(
                        modifier = Modifier
                            .fillMaxWidth(slice.share(of).toFloat().coerceIn(0f, 1f))
                            .height(4.dp)
                            .clip(RoundedCornerShape(2.dp))
                            .background(colors.accent),
                    )
                }
            }
        }
    }
}

// Decode a code

@Composable
fun CodeDecoderScreen(onBack: () -> Unit) {
    val colors = palette
    var raw by remember { mutableStateOf("") }
    val recipe = remember(raw) { RecipeCode.parse(raw) }
    val batch = remember(raw) { BatchCode.parse(raw) }

    Column(Modifier.fillMaxWidth()) {
        DetailBar("Decode a code", onBack)
        LazyColumn(
            contentPadding = PaddingValues(Space.xl),
            verticalArrangement = Arrangement.spacedBy(Space.m),
        ) {
            item {
                Field(
                    raw, { raw = it },
                    label = "The code on the bottle",
                    placeholder = "OESQ, B523",
                )
            }

            recipe?.let {
                item {
                    Card {
                        SectionLabel("Four Roses recipe")
                        Text(it.code, style = TypeScale.largeTitle, color = colors.accent)
                        FactRow("Mashbill", it.mashbill.summary)
                        // The distillery's own descriptor for the yeast, not
                        // ours. We do not invent tasting language for them.
                        FactRow("Yeast", it.yeast.letter + " · " + it.yeast.character, isLast = true)
                    }
                }
            }

            batch?.let {
                item {
                    Card {
                        SectionLabel("Elijah Craig batch")
                        Text(
                            it.release.letter.toString() +
                                it.month.toString() +
                                (it.year % 100).toString().padStart(2, '0'),
                            style = TypeScale.largeTitle,
                            color = colors.accent,
                        )
                        FactRow("Release", it.release.ordinalName + " of the year")
                        FactRow("Bottled", BatchCode.monthName(it.month) + " " + it.year, isLast = true)
                    }
                }
            }

            if (raw.isNotBlank() && recipe == null && batch == null) {
                item {
                    Card {
                        Text(
                            "Not a code this app knows.",
                            style = TypeScale.headline,
                            color = colors.text,
                        )
                        Text(
                            "It reads Four Roses recipe codes (OBSV through OESQ) and " +
                                "Elijah Craig barrel-proof batch codes (a letter, a " +
                                "month, a year). Anything else is left alone rather " +
                                "than guessed at.",
                            style = TypeScale.secondary,
                            color = colors.textMuted,
                        )
                    }
                }
            }

            if (raw.isBlank()) {
                item {
                    Card {
                        Text(
                            "Two codes, decoded from the producers' own published " +
                                "schemes.",
                            style = TypeScale.secondary,
                            color = colors.textSecondary,
                        )
                        Text(
                            "OESQ · Four Roses: E mashbill, Q yeast.\n" +
                                "B523 · Elijah Craig: B release, May 2023.",
                            style = TypeScale.code,
                            color = colors.textMuted,
                        )
                    }
                }
            }
        }
    }
}

// What's open

@Composable
fun PourMenuScreen(onBack: () -> Unit) {
    val state = LocalAppState.current
    val colors = palette
    val clipboard = LocalClipboardManager.current
    val open = remember(state.changeCount) {
        state.bottles.onShelf().filter { it.isOpen && !it.status.isEmpty }
    }
    val items = remember(open) {
        open.map {
            PourMenu.Item(
                name = state.name(it),
                detail = state.distillery(it),
                proof = it.abv?.let { abv -> ABV(abv).proof },
            )
        }
    }
    val text = remember(items) { PourMenu.text("What's open", items) }

    Column(Modifier.fillMaxWidth()) {
        DetailBar("What's open", onBack)
        LazyColumn(
            contentPadding = PaddingValues(Space.xl),
            verticalArrangement = Arrangement.spacedBy(Space.m),
        ) {
            item {
                Text(
                    // No prices. A menu with prices on it reads as bragging
                    // about what the evening cost, and the one thing a guest
                    // cannot do with that information is enjoy the whiskey.
                    "A menu for guests. No prices, and only what is open.",
                    style = TypeScale.secondary,
                    color = colors.textSecondary,
                )
            }
            if (items.isEmpty()) {
                item { Empty("Nothing open", "Open a bottle and it appears here.") }
            } else {
                item {
                    Card {
                        Text(text, style = TypeScale.body, color = colors.text)
                    }
                }
                item {
                    AccentButton("Copy the menu", modifier = Modifier.fillMaxWidth()) {
                        clipboard.setText(AnnotatedString(text))
                    }
                }
            }
        }
    }
}

// Tonight

@Composable
fun CocktailsScreen(onBack: () -> Unit) {
    val state = LocalAppState.current
    val colors = palette
    val matches = remember(state.changeCount) {
        val shelf = state.bottles.onShelf().mapNotNull { summary ->
            val classType = state.product(summary.bottle.catalog_product_id)?.classType
                ?: summary.bottle.catalog_product_id
                    ?.let { state.bottles.customEntry(it)?.class_type }
                    ?.let { ClassType.fromStorageKey(it) }
                ?: return@mapNotNull null
            Cocktails.Candidate(
                id = summary.id,
                name = state.name(summary),
                classType = classType,
                isOpen = summary.isOpen,
                rating = summary.latestRating,
                fillFraction = if (summary.status.capacityMilliliters > 0) {
                    summary.status.remainingMilliliters / summary.status.capacityMilliliters
                } else {
                    0.0
                },
            )
        }
        Cocktails.matches(shelf)
    }

    Column(Modifier.fillMaxWidth()) {
        DetailBar("Tonight", onBack)
        LazyColumn(
            contentPadding = PaddingValues(Space.xl),
            verticalArrangement = Arrangement.spacedBy(Space.m),
        ) {
            item {
                Text(
                    "The IBA's official recipes, against what is open on your shelf.",
                    style = TypeScale.secondary,
                    color = colors.textSecondary,
                )
            }
            if (matches.isEmpty()) {
                item {
                    Empty(
                        "Nothing to make tonight",
                        "A recipe appears once something open fits it, or once you " +
                            "are one bottle short of one.",
                    )
                }
            } else {
                items(matches, key = { it.id }) { match ->
                    Card {
                        Row(modifier = Modifier.fillMaxWidth()) {
                            Text(
                                match.recipe.name,
                                style = TypeScale.title,
                                color = colors.text,
                                modifier = Modifier.weight(1f),
                            )
                            Text(
                                if (match.isReady) "Ready" else "One short",
                                style = TypeScale.caption,
                                color = if (match.isReady) colors.good else colors.textMuted,
                            )
                        }
                        for (ingredient in match.recipe.ingredients) {
                            Text(
                                "• " + ingredient.text,
                                style = TypeScale.secondary,
                                color = colors.textSecondary,
                            )
                        }
                        for ((slot, pick) in match.picks) {
                            Text(
                                slot.label + " → " + pick.name,
                                style = TypeScale.caption,
                                color = colors.accent,
                            )
                        }
                        for (missing in match.missing) {
                            Text(
                                missing.sealed?.let {
                                    "Nothing open for " + missing.slot.label +
                                        " · " + it.name + " is sealed"
                                } ?: ("Nothing for " + missing.slot.label),
                                style = TypeScale.caption,
                                color = colors.textMuted,
                            )
                        }
                        Text(match.recipe.method, style = TypeScale.caption, color = colors.textMuted)
                        Text(match.recipe.glass, style = TypeScale.caption, color = colors.textMuted)
                    }
                }
            }
        }
    }
}

// Pick my pour

@Composable
fun PickMyPourScreen(onBack: () -> Unit, onOpenBottle: (String) -> Unit) {
    val state = LocalAppState.current
    val colors = palette
    var roll by remember { mutableIntStateOf(0) }
    val candidates = remember(state.changeCount) {
        state.bottles.onShelf().map {
            PickMyPour.Candidate(
                id = it.id,
                name = state.name(it),
                lastPouredAt = it.lastPouredAt?.let { at -> Instant.ofEpochMilli(at) },
                isOpen = it.isOpen,
                remainingMilliliters = it.status.remainingMilliliters,
            )
        }
    }
    val choice = remember(candidates, roll) {
        PickMyPour.choose(candidates, random = Random(roll.toLong() + candidates.size))
    }

    Column(Modifier.fillMaxWidth()) {
        DetailBar("Pick my pour", onBack)
        Column(
            modifier = Modifier.fillMaxWidth().padding(Space.xl),
            verticalArrangement = Arrangement.spacedBy(Space.m),
        ) {
            Text(
                // A sealed bottle is deliberately never picked: opening one
                // starts an oxidation clock and is a decision the app should
                // not make for somebody.
                "Something open you have not had in a while. Sealed bottles are " +
                    "never picked for you.",
                style = TypeScale.secondary,
                color = colors.textSecondary,
            )
            if (choice == null) {
                Empty("Nothing open", "Open a bottle with something left in it.")
            } else {
                Card(onClick = { onOpenBottle(choice.candidate.id) }) {
                    Text(choice.candidate.name, style = TypeScale.largeTitle, color = colors.text)
                    Text(choice.reason, style = TypeScale.body, color = colors.textSecondary)
                }
                QuietButton("Pick another", modifier = Modifier.fillMaxWidth()) { roll += 1 }
            }
        }
    }
}

// Insurance report

@Composable
fun InsuranceReportScreen(onBack: () -> Unit) {
    val state = LocalAppState.current
    val colors = palette
    val clipboard = LocalClipboardManager.current
    val document = remember(state.changeCount) {
        InsuranceReport.build(
            state.bottles.onShelf().map { summary ->
                val bottle = summary.bottle
                InsuranceReport.Line(
                    id = summary.id,
                    name = state.name(summary),
                    distillery = state.distillery(summary),
                    detail = InsuranceReport.detail(
                        barrel = bottle.barrel_number?.takeIf { it.isNotBlank() },
                        batch = bottle.batch_number?.takeIf { it.isNotBlank() },
                        pickStore = bottle.pick_store?.takeIf { it.isNotBlank() },
                        bottleNumber = bottle.bottle_number?.toInt(),
                        bottlesInBatch = bottle.bottles_in_batch?.toInt(),
                        topperLetter = bottle.topper_letter?.takeIf { it.isNotBlank() },
                    ),
                    sizeMilliliters = summary.volumeMl,
                    status = if (summary.isOpen) "Open" else "Sealed",
                    purchasedAt = bottle.purchase_date?.let { Instant.ofEpochMilli(it) },
                    store = bottle.purchase_store,
                    paidCents = summary.purchasePriceCents?.toInt(),
                    storageLocation = summary.storageLocation,
                )
            }
        )
    }
    val text = remember(document) { reportText(document) }

    Column(Modifier.fillMaxWidth()) {
        DetailBar("Insurance report", onBack)
        LazyColumn(
            contentPadding = PaddingValues(Space.xl),
            verticalArrangement = Arrangement.spacedBy(Space.m),
        ) {
            item {
                Card {
                    Text(document.title, style = TypeScale.title, color = colors.text)
                    FactRow("Bottles", document.bottleCount.toString())
                    FactRow("With a price", document.pricedCount.toString())
                    FactRow("Without one", document.unpricedCount.toString())
                    FactRow("Total paid", Money.short(document.paidTotalCents), isLast = true)
                    // Not negotiable and not softened. This app has no market
                    // data and will not invent an appraisal.
                    Text(document.caveat, style = TypeScale.caption, color = colors.textMuted)
                }
            }
            item {
                AccentButton("Copy the report", modifier = Modifier.fillMaxWidth()) {
                    clipboard.setText(AnnotatedString(text))
                }
            }
            items(document.lines, key = { it.id }) { line ->
                Card {
                    Text(line.name, style = TypeScale.headline, color = colors.text)
                    line.distillery?.let {
                        Text(it, style = TypeScale.secondary, color = colors.textSecondary)
                    }
                    line.detail?.let {
                        Text(it, style = TypeScale.code, color = colors.textMuted)
                    }
                    Text(
                        listOfNotNull(
                            VolumeDisplay.text(line.sizeMilliliters, state.ounces),
                            line.status,
                            line.paidCents?.let { Money.short(it) },
                            line.store,
                        ).joinToString(" · "),
                        style = TypeScale.caption,
                        color = colors.textMuted,
                    )
                }
            }
        }
    }
}

private fun reportText(document: InsuranceReport.Document): String = buildString {
    appendLine(document.title)
    appendLine(shortDate(document.generatedAt.toEpochMilli()))
    appendLine()
    for (line in document.lines) {
        append("• ").append(line.name)
        line.detail?.let { append(" · ").append(it) }
        append(" · ").append(line.sizeMilliliters.toInt()).append(" ml")
        line.paidCents?.let { append(" · ").append(Money.short(it)) }
        appendLine()
    }
    appendLine()
    appendLine(
        "${document.bottleCount} bottles, ${document.pricedCount} with a recorded price, " +
            "totalling ${Money.short(document.paidTotalCents)}."
    )
    appendLine(document.caveat)
}

// Your year

@Composable
fun YearScreen(onBack: () -> Unit) {
    val state = LocalAppState.current
    val colors = palette
    val zone = ZoneId.systemDefault()

    val facts = remember(state.changeCount) {
        val bottles = state.bottles.all()
        val tastings = state.tastings.allDetails()
        val names = bottles.associate { it.id to state.name(it) }
        YearInReview.Facts(
            added = bottles.map {
                YearInReview.Added(
                    name = state.name(it),
                    classLabel = state.product(it.bottle.catalog_product_id)?.classType?.label,
                    distillery = state.distillery(it),
                    cents = it.purchasePriceCents?.toInt(),
                    at = Instant.ofEpochMilli(it.bottle.created_at),
                )
            },
            opened = bottles.mapNotNull { it.bottle.opened_at?.let(Instant::ofEpochMilli) },
            tastings = tastings.mapNotNull { detail ->
                val name = detail.bottleId?.let { names[it] }
                    ?: state.identity(detail.catalogProductId)?.displayName
                    ?: return@mapNotNull null
                YearInReview.Tasted(
                    name = name,
                    rating = detail.rating,
                    at = Instant.ofEpochMilli(detail.tastedAt),
                    // The wheel's labels, not its keys: the "word of the
                    // year" is a word somebody would recognise.
                    words = TastingRepository.Stage.entries.flatMap { stage ->
                        detail.descriptors(stage).map { key ->
                            state.wheel?.descriptor(key)?.label ?: key
                        }
                    },
                )
            },
        )
    }
    val years = remember(facts) { YearInReview.years(facts, zone) }
    var year by remember(years) { mutableIntStateOf(years.lastOrNull() ?: 0) }
    val review = remember(facts, year) {
        if (year == 0) null else YearInReview.review(facts, year, zone = zone)
    }

    Column(Modifier.fillMaxWidth()) {
        DetailBar("Your year", onBack)
        LazyColumn(
            contentPadding = PaddingValues(Space.xl),
            verticalArrangement = Arrangement.spacedBy(Space.m),
        ) {
            if (years.isEmpty() || review == null) {
                item {
                    Empty(
                        "Nothing to look back on yet",
                        "Add a bottle or record a tasting and a year appears here.",
                    )
                }
            } else {
                item {
                    ChipRow {
                        for (option in years) {
                            Chip(option.toString(), isOn = option == year) { year = option }
                        }
                    }
                }
                item {
                    Card {
                        Text(
                            review.lines.joinToString("\n\n"),
                            style = TypeScale.body,
                            color = colors.text,
                        )
                        // Only behind the money switch, like everywhere else
                        // a total appears in this app.
                        if (state.showsValue) {
                            review.moneyLine?.let {
                                Text(it, style = TypeScale.secondary, color = colors.accent)
                            }
                        }
                    }
                }
            }
        }
    }
}

// Shared

/** A bottle reduced to what the stats summary needs. */
private fun statsEntry(
    state: AppState,
    summary: BottleRepository.Summary,
): CollectionStats.Entry {
    val bottle = summary.bottle
    val product = state.product(bottle.catalog_product_id)
    return CollectionStats.Entry(
        name = state.name(summary),
        classType = product?.classType
            ?: bottle.catalog_product_id
                ?.let { state.bottles.customEntry(it)?.class_type }
                ?.let { ClassType.fromStorageKey(it) },
        distillery = state.distillery(summary),
        brand = product?.brand ?: summary.name,
        abv = summary.abv ?: product?.abv,
        isOpen = summary.isOpen,
        isFinished = summary.isFinished,
        isSample = summary.isSample,
        isPick = summary.isStorePick || bottle.barrel_number != null,
        addedAt = Instant.ofEpochMilli(bottle.created_at),
        openedAt = bottle.opened_at?.let { Instant.ofEpochMilli(it) },
        ageMonths = bottle.age_months?.toInt(),
        storageLocation = summary.storageLocation,
        purchasePriceCents = summary.purchasePriceCents?.toInt(),
        purchasedAt = bottle.purchase_date?.let { Instant.ofEpochMilli(it) },
        costPerPourCents = summary.costPerPourCents,
        topperLetter = bottle.topper_letter,
    )
}
