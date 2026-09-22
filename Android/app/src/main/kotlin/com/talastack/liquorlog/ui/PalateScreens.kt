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
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.unit.dp
import com.talastack.liquorlog.data.BottleRepository
import com.talastack.liquorlog.data.TastingRepository
import com.talastack.liquorlog.engine.ClassType
import com.talastack.liquorlog.engine.Money
import com.talastack.liquorlog.engine.Palate
import com.talastack.liquorlog.engine.TryNext
import com.talastack.liquorlog.ui.theme.Space
import com.talastack.liquorlog.ui.theme.TypeScale
import com.talastack.liquorlog.ui.theme.palette
import java.util.Locale
import kotlin.math.roundToInt

/**
 * The three screens that make tastings worth recording.
 *
 * Until now a tasting went into the database and came back out only as a
 * number on a card. These close the loop: what your tastings say about you,
 * what to try next because of them, and what you decided you wanted.
 */

// Your palate

/**
 * What your own tastings say, and nothing else.
 *
 * Every line rests on at least [Palate.minimum] ratings, which the engine
 * enforces rather than this screen: an average over two evenings is not a
 * preference, and presenting it as one is the kind of claim this app does
 * not make.
 */
@Composable
fun PalateScreen(onBack: () -> Unit) {
    val state = LocalAppState.current
    val colors = palette

    val profile = remember(state.changeCount) {
        val bottles = state.bottles.all().associateBy { it.id }
        Palate.profile(
            state.tastings.allDetails().map { detail ->
                val bottle = detail.bottleId?.let { bottles[it] }
                val product = state.product(
                    detail.catalogProductId ?: bottle?.bottle?.catalog_product_id
                )
                val classType = product?.classType
                    ?: bottle?.bottle?.catalog_product_id
                        ?.let { state.bottles.customEntry(it)?.class_type }
                        ?.let { ClassType.fromStorageKey(it) }
                Palate.Tasting(
                    productId = product?.id ?: detail.bottleId,
                    isBlind = detail.isBlind,
                    classType = classType,
                    abv = bottle?.abv ?: product?.abv,
                    // Null rather than false when the recipe is unknown: a
                    // bottle whose mashbill nobody recorded is not evidence
                    // that wheaters rate lower.
                    isWheated = product?.mashbillKey?.let { it == "wheated" },
                    rating = detail.rating,
                    perceivedHeat = detail.tasting.perceived_heat?.toInt(),
                    finishSeconds = detail.tasting.finish_seconds?.toInt(),
                    wouldRebuy = when (detail.rebuy) {
                        TastingRepository.Rebuy.YES -> true
                        TastingRepository.Rebuy.NO -> false
                        TastingRepository.Rebuy.MAYBE, null -> null
                    },
                    descriptors = TastingRepository.Stage.entries
                        .flatMap { detail.descriptors(it) },
                )
            }
        )
    }
    val sentences = remember(profile) {
        Palate.sentences(profile) { key -> state.wheel?.descriptor(key)?.label ?: key }
    }

    Column(Modifier.fillMaxWidth()) {
        DetailBar("Your palate", onBack)
        LazyColumn(
            contentPadding = PaddingValues(Space.xl),
            verticalArrangement = Arrangement.spacedBy(Space.m),
        ) {
            if (profile.isEmpty) {
                item {
                    Empty(
                        "Nothing to read yet",
                        "Record a few tastings and this fills in. It needs " +
                            "${Palate.minimum} ratings on a side before it will " +
                            "compare anything.",
                    )
                }
                return@LazyColumn
            }

            item {
                Card {
                    Text(
                        "${profile.tastings} tastings, ${profile.rated} of them rated.",
                        style = TypeScale.body,
                        color = colors.text,
                    )
                }
            }

            if (sentences.isNotEmpty()) {
                item { SectionLabel("In a few words") }
                item {
                    Card {
                        Text(
                            sentences.joinToString("\n\n"),
                            style = TypeScale.body,
                            color = colors.text,
                        )
                    }
                }
            }

            if (profile.words.isNotEmpty()) {
                item { SectionLabel("The words you reach for") }
                item {
                    ChipRow {
                        for (word in profile.words.take(12)) {
                            Chip(
                                (state.wheel?.descriptor(word.key)?.label ?: word.key) +
                                    " · " + word.count,
                                isOn = false,
                            ) {}
                        }
                    }
                }
            }

            if (profile.byClass.isNotEmpty()) {
                item { SectionLabel("By class") }
                item { LineCard(profile.byClass) }
            }
            if (profile.byStrength.isNotEmpty()) {
                item { SectionLabel("By strength") }
                item { LineCard(profile.byStrength) }
            }

            val recipes = listOfNotNull(profile.wheated, profile.otherBourbon)
            if (recipes.size == 2) {
                item { SectionLabel("Wheated or not") }
                item { LineCard(recipes) }
            }

            val heat = listOfNotNull(profile.whenHot, profile.whenEasy)
            if (heat.isNotEmpty()) {
                item { SectionLabel("Heat") }
                item { LineCard(heat) }
            }

            item { SectionLabel("Would you buy again") }
            item {
                Card {
                    val share = profile.rebuyShare
                    val answered = profile.rebuyAnswered
                    // Three states, not two. The engine returns null both
                    // when nobody answered and when too few did, and telling
                    // somebody "nothing answered yet" after they answered is
                    // the app calling them a liar.
                    when {
                        answered == 0 -> Text(
                            "Nothing answered yet.",
                            style = TypeScale.secondary,
                            color = colors.textMuted,
                        )

                        share == null -> Text(
                            "$answered answered so far. It waits for " +
                                "${Palate.minimum} before drawing anything from them.",
                            style = TypeScale.secondary,
                            color = colors.textMuted,
                        )

                        else -> Text(
                            "${(share * 100).roundToInt()}% of the $answered you answered.",
                            style = TypeScale.body,
                            color = colors.text,
                        )
                    }
                    profile.averageFinishSeconds?.let {
                        Text(
                            "Finishes average $it seconds.",
                            style = TypeScale.secondary,
                            color = colors.textSecondary,
                        )
                    }
                }
            }

            profile.labelBias?.let { bias ->
                item { SectionLabel("The label") }
                item {
                    Card {
                        Text(
                            // The one number here that is about the person
                            // rather than the whiskey. Stated flatly: it is
                            // interesting, not a failing.
                            String.format(
                                Locale.ROOT,
                                "Knowing the bottle moves your rating by %+.1f, over " +
                                    "%d %s rated both ways.",
                                bias,
                                profile.labelBiasPairs,
                                if (profile.labelBiasPairs == 1) "bottle" else "bottles",
                            ),
                            style = TypeScale.body,
                            color = colors.text,
                        )
                    }
                }
            }
        }
    }
}

@Composable
private fun LineCard(lines: List<Palate.Line>) {
    val colors = palette
    Card {
        lines.forEachIndexed { index, line ->
            FactRow(
                line.label,
                line.averageText + " over " + line.count +
                    (if (line.count == 1) " rating" else " ratings"),
                isLast = index == lines.lastIndex,
            )
        }
    }
}

// Try next

/**
 * Related to what you rated well, and not yet had -- each with its reason.
 *
 * A suggestion with no reason is a recommendation engine, which this is not:
 * the relation is structural (same line, same recipe, same distillery) and
 * the sentence under each row says which, so the person can disagree with it.
 */
@Composable
fun TryNextScreen(onBack: () -> Unit, onWish: (String) -> Unit) {
    val state = LocalAppState.current
    val colors = palette
    val wished = remember(state.changeCount) { state.wishlist.wishedProductIds() }

    val suggestions = remember(state.changeCount) {
        val bottles = state.bottles.all()
        val byBottle = bottles.associateBy { it.id }
        val had = bottles.mapNotNull { it.bottle.catalog_product_id }.toMutableSet()

        val liked = state.tastings.allDetails().mapNotNull { detail ->
            val rating = detail.rating ?: return@mapNotNull null
            val productId = detail.catalogProductId
                ?: detail.bottleId?.let { byBottle[it]?.bottle?.catalog_product_id }
                ?: return@mapNotNull null
            had.add(productId)
            val product = state.catalog.product(productId) ?: return@mapNotNull null
            TryNext.Liked(
                product = product.identity,
                rating = rating,
                recipeCode = product.code,
                mashbillKey = product.mashbillKey,
            )
        }

        TryNext.suggest(
            liked = liked,
            catalogue = state.catalog.searchCandidates(),
            had = had,
        )
    }

    Column(Modifier.fillMaxWidth()) {
        DetailBar("Try next", onBack)
        LazyColumn(
            contentPadding = PaddingValues(Space.xl),
            verticalArrangement = Arrangement.spacedBy(Space.m),
        ) {
            item {
                Text(
                    "From the bottles you rated ${TryNext.threshold} or better, and " +
                        "only things you have not had.",
                    style = TypeScale.secondary,
                    color = colors.textSecondary,
                )
            }

            if (suggestions.isEmpty()) {
                item {
                    Empty(
                        "Nothing to suggest yet",
                        "Rate a bottle from the catalogue ${TryNext.threshold} or " +
                            "better and its relatives appear here.",
                    )
                }
            } else {
                items(suggestions, key = { it.id }) { suggestion ->
                    val onList = suggestion.product.productId in wished
                    Card {
                        Text(
                            suggestion.product.displayName,
                            style = TypeScale.headline,
                            color = colors.text,
                        )
                        // The reason, always. It is what separates this from
                        // a recommendation nobody can argue with.
                        Text(
                            suggestion.why,
                            style = TypeScale.secondary,
                            color = colors.textSecondary,
                        )
                        state.catalog.product(suggestion.product.productId)?.let { product ->
                            Text(
                                listOfNotNull(
                                    product.distillery.takeIf { it.isNotBlank() },
                                    product.classType.label,
                                ).joinToString(" · "),
                                style = TypeScale.caption,
                                color = colors.textMuted,
                            )
                        }
                        if (onList) {
                            Text(
                                "On your wishlist",
                                style = TypeScale.caption,
                                color = colors.accent,
                                modifier = Modifier.padding(top = Space.xs),
                            )
                        } else {
                            QuietButton("Add to wishlist") {
                                onWish(suggestion.product.productId)
                            }
                        }
                    }
                }
            }
        }
    }
}

// Wishlist

/**
 * Bottles you want, and what you would pay.
 *
 * The price is what the owner would pay, never what anything is worth. There
 * is no market data in this app and none will be invented, so the number only
 * ever means "at this price I would buy it".
 */
@Composable
fun WishlistScreen(onBack: () -> Unit) {
    val state = LocalAppState.current
    val colors = palette
    val items = remember(state.changeCount) { state.wishlist.all() }
    var adding by remember { mutableStateOf(false) }
    var removing by remember { mutableStateOf<String?>(null) }

    Column(Modifier.fillMaxWidth()) {
        DetailBar(
            "Wishlist",
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
            if (items.isEmpty()) {
                item {
                    Empty(
                        "Nothing on the list",
                        "Add a bottle you are looking for. The shelf check says so " +
                            "when you find one.",
                    )
                }
            } else {
                items(items, key = { it.id }) { item ->
                    val identity = state.identity(item.catalogProductId)
                    Card {
                        Text(
                            identity?.displayName ?: item.customName ?: "Untitled",
                            style = TypeScale.title,
                            color = colors.text,
                        )
                        item.targetPriceCents?.let {
                            Text(
                                Money.short(it) + " is what you would pay",
                                style = TypeScale.secondary,
                                color = colors.accent,
                            )
                        }
                        item.note?.let {
                            Text(it, style = TypeScale.secondary, color = colors.textSecondary)
                        }
                        Text(
                            "Added " + shortDate(item.addedAt),
                            style = TypeScale.caption,
                            color = colors.textMuted,
                        )
                        Row(horizontalArrangement = Arrangement.spacedBy(Space.s)) {
                            QuietButton("Take it off") { removing = item.id }
                        }
                    }
                }
            }
        }
    }

    if (adding) {
        WishlistDialog(
            onDismiss = { adding = false },
            onAdd = { name, cents, note ->
                state.wishlist.add(
                    customName = name,
                    targetPriceCents = cents,
                    note = note,
                )
                state.noteChange()
                adding = false
            },
        )
    }

    removing?.let { id ->
        ConfirmDialog(
            title = "Take it off the list?",
            message = "Either you bought it or you changed your mind. Both are " +
                "reasons to take it off, and neither is recorded.",
            confirmLabel = "Take it off",
            onConfirm = {
                state.wishlist.remove(id)
                state.noteChange()
                removing = null
            },
            onDismiss = { removing = null },
        )
    }
}

@Composable
private fun WishlistDialog(
    onDismiss: () -> Unit,
    onAdd: (String, Int?, String?) -> Unit,
) {
    val colors = palette
    var name by remember { mutableStateOf("") }
    var price by remember { mutableStateOf("") }
    var note by remember { mutableStateOf("") }

    androidx.compose.material3.AlertDialog(
        onDismissRequest = onDismiss,
        containerColor = colors.surface,
        title = { Text("Add to the wishlist", style = TypeScale.title, color = colors.text) },
        text = {
            Column(verticalArrangement = Arrangement.spacedBy(Space.m)) {
                Field(name, { name = it }, label = "What it is", placeholder = "Weller 12")
                Field(
                    price, { price = it },
                    label = "What you would pay",
                    numeric = true, decimal = true,
                )
                Field(note, { note = it }, label = "A note", singleLine = false)
            }
        },
        confirmButton = {
            androidx.compose.material3.TextButton(
                onClick = {
                    onAdd(
                        name.trim(),
                        LocalNumber.parse(price)?.takeIf { it > 0 }
                            ?.let { (it * 100).roundToInt() },
                        note.trim().ifBlank { null },
                    )
                },
                enabled = name.isNotBlank(),
            ) {
                Text(
                    "Add it",
                    style = TypeScale.headline,
                    color = colors.accent.copy(alpha = if (name.isNotBlank()) 1f else 0.4f),
                )
            }
        },
        dismissButton = {
            androidx.compose.material3.TextButton(onClick = onDismiss) {
                Text("Cancel", style = TypeScale.body, color = colors.textMuted)
            }
        },
    )
}
