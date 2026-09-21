package com.talastack.liquorlog.ui

import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Cancel
import androidx.compose.material.icons.filled.Search
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
import androidx.compose.ui.unit.dp
import com.talastack.liquorlog.data.BottleRepository
import com.talastack.liquorlog.engine.BottleSearch
import com.talastack.liquorlog.engine.ClassType
import com.talastack.liquorlog.engine.Holding
import com.talastack.liquorlog.engine.ProductIdentity
import com.talastack.liquorlog.engine.SearchCandidate
import com.talastack.liquorlog.engine.ShelfCheck
import com.talastack.liquorlog.engine.ShelfCheckResult
import com.talastack.liquorlog.engine.TastingRecord
import com.talastack.liquorlog.ui.theme.Space
import com.talastack.liquorlog.ui.theme.TypeScale
import com.talastack.liquorlog.ui.theme.palette

/**
 * The home tab: do I already own this, asked with the bottle in hand.
 *
 * **The verdict is the engine's, not this screen's.** `BottleSearch` finds
 * candidates and `ShelfCheck.evaluate` decides the headline, both of which
 * are pure functions with tests on two platforms. This file chooses colours
 * and nothing else.
 *
 * It searches the bundled catalogue AND the person's own bottles, so a
 * typed-in bottle the catalogue has never heard of still answers "on your
 * shelf". Nothing here touches the network: a liquor store is a concrete box.
 */
@Composable
fun ShelfCheckScreen(onOpenBottle: (String) -> Unit) {
    val state = LocalAppState.current
    val colors = palette
    var query by remember { mutableStateOf("") }

    val shelf = remember(state.changeCount) { state.bottles.all() }
    val tastings = remember(state.changeCount) { state.tastings.allDetails() }

    // The person's own bottles as products the engine can reason about,
    // plus the whole catalogue. A bottle typed in by hand has no catalogue
    // row, so without the first half the answer would be "never had it" for
    // a bottle standing on the shelf -- the one wrong answer this screen
    // must never give.
    val candidates = remember(shelf, state.catalog) {
        val history = shelf.mapNotNull { it.bottle.catalog_product_id }.toSet()
        val own = shelf
            .filter { it.bottle.catalog_product_id == null }
            .map { SearchCandidate(product = it.asProduct(state), isInYourHistory = true) }
        own + state.catalog.searchCandidates(history)
    }

    val holdings = remember(shelf) {
        shelf.map {
            Holding(
                bottleId = it.id,
                product = it.asProduct(state),
                isOpen = it.isOpen,
                isFinished = it.isFinished,
                isSample = it.isSample,
            )
        }
    }

    val tasted = remember(tastings, shelf) {
        val byBottle = shelf.associateBy { it.id }
        tastings.mapNotNull { detail ->
            // A tasting points at a bottle, at a catalogue product, or at
            // neither. Only the first two can be matched to what is in the
            // person's hand; the third is a bar pour with a typed name and
            // is deliberately not guessed at.
            val identity = detail.bottleId?.let { byBottle[it]?.asProduct(state) }
                ?: state.identity(detail.catalogProductId)
                ?: return@mapNotNull null
            TastingRecord(
                tastingId = detail.id,
                product = identity,
                tastedAt = java.time.Instant.ofEpochMilli(detail.tastedAt),
                rating = detail.rating,
                whereTasted = detail.whereLabel,
            )
        }
    }

    val hits = remember(query, candidates) {
        if (query.isBlank()) emptyList() else BottleSearch.search(query, candidates, limit = 12)
    }
    val byProduct = remember(shelf) {
        shelf.associateBy { it.asProduct(state).productId }
    }

    Column(modifier = Modifier.fillMaxWidth().padding(horizontal = Space.xl)) {
        Text(
            "Shelf Check",
            style = TypeScale.largeTitle,
            color = colors.text,
            modifier = Modifier.padding(top = Space.s),
        )
        Text(
            "Standing in a shop. Type what is in your hand.",
            style = TypeScale.secondary,
            color = colors.textSecondary,
            modifier = Modifier.padding(bottom = Space.m),
        )

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
                value = query,
                onValueChange = { query = it },
                placeholder = {
                    Text(
                        "Elijah Craig, Weller 12, Blanton's",
                        style = TypeScale.secondary,
                        color = colors.textMuted,
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
            if (query.isNotEmpty()) {
                Icon(
                    Icons.Filled.Cancel,
                    contentDescription = "Clear",
                    tint = colors.textMuted,
                    modifier = Modifier
                        .clickable { query = "" }
                        .padding(Space.m)
                        .size(18.dp),
                )
            }
        }

        when {
            query.isBlank() -> Empty(
                if (state.catalog.products.isEmpty()) {
                    "The catalogue could not be read."
                } else {
                    "Nothing typed yet."
                },
                if (state.catalog.products.isEmpty()) {
                    "Your own bottles are still searched. Reinstalling the app " +
                        "restores the catalogue."
                } else {
                    "${state.catalog.products.size} products and your own shelf, " +
                        "on the phone. It works with no signal."
                },
            )

            hits.isEmpty() -> Empty(
                "Nothing matches",
                "Try fewer words, or the distillery on its own.",
            )

            else -> LazyColumn(
                contentPadding = PaddingValues(top = Space.l, bottom = 96.dp),
                verticalArrangement = Arrangement.spacedBy(Space.m),
            ) {
                items(hits, key = { it.product.productId }) { hit ->
                    val verdict = ShelfCheck.evaluate(
                        product = hit.product,
                        holdings = holdings,
                        tastings = tasted,
                    )
                    val owned = byProduct[hit.product.productId]
                    VerdictCard(
                        product = hit.product,
                        verdict = verdict,
                        owned = owned,
                        onClick = owned?.let { summary -> { onOpenBottle(summary.id) } },
                    )
                }
            }
        }
    }
}

@Composable
private fun VerdictCard(
    product: ProductIdentity,
    verdict: ShelfCheckResult,
    owned: BottleRepository.Summary?,
    onClick: (() -> Unit)?,
) {
    val state = LocalAppState.current
    val colors = palette
    Card(onClick = onClick) {
        Text(product.displayName, style = TypeScale.headline, color = colors.text)
        VerdictBadge(verdict.headline)

        if (verdict.onShelf.isNotEmpty()) {
            Text(
                "${verdict.onShelf.size} on the shelf, ${verdict.openBottleCount} open",
                style = TypeScale.secondary,
                color = colors.textSecondary,
            )
        }
        owned?.let { FillBar(it.status, ounces = state.ounces) }

        // The catalogue's facts, sourced. Shown under the verdict because the
        // verdict is what the person came for and the facts are why they
        // might change their mind.
        state.catalog.product(product.productId)?.let { catalogue ->
            Text(
                listOfNotNull(
                    catalogue.distillery.takeIf { it.isNotBlank() },
                    catalogue.classType.label,
                    catalogue.abv?.let { strengthLine(it, catalogue.isBarrelProof) },
                ).joinToString(" · "),
                style = TypeScale.caption,
                color = colors.textMuted,
            )
        }
    }
}

/**
 * A bottle the person typed in, as a product the engine can reason about.
 *
 * A catalogue bottle uses the catalogue's identity so the two match; a typed
 * one has only the name, and the engine copes -- `lineKey` folds the brand,
 * so two bottles of the same name are one line.
 */
internal fun BottleRepository.Summary.asProduct(state: AppState): ProductIdentity =
    state.identity(bottle.catalog_product_id) ?: ProductIdentity(
        productId = id,
        distillery = "",
        brand = name,
        expression = "",
        classType = ClassType.BOURBON,
    )
