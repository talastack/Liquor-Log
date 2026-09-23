package com.talastack.liquorlog.ui

import androidx.compose.foundation.clickable
import androidx.compose.foundation.horizontalScroll
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.rememberScrollState
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.unit.dp
import com.talastack.liquorlog.engine.BottleSearch
import com.talastack.liquorlog.engine.CatalogProduct
import com.talastack.liquorlog.engine.ClassType
import com.talastack.liquorlog.engine.PourSize
import com.talastack.liquorlog.engine.ProductionType
import com.talastack.liquorlog.ui.theme.Space
import com.talastack.liquorlog.ui.theme.TypeScale
import com.talastack.liquorlog.ui.theme.palette
import kotlin.math.roundToInt

/**
 * Adding a bottle, or editing one.
 *
 * One screen for both, as `EditBottleView` and `AddBottleView` are on iOS:
 * the fields are the same fields, and two screens would be two places for a
 * new field to be forgotten.
 *
 * The form starts from the catalogue. Typing a name searches the 534 bundled
 * products with the engine's own matcher, and picking one fills in the
 * distillery, class, production type and strength -- all of it sourced, none
 * of it guessed. Typing a name the catalogue does not have is equally valid
 * and makes a custom entry instead.
 */
@Composable
fun AddBottleScreen(bottleId: String?, onDone: () -> Unit) {
    val state = LocalAppState.current
    val colors = palette
    val existing = remember(bottleId) { bottleId?.let { state.bottles.byId(it) } }

    var name by remember { mutableStateOf(existing?.name ?: "") }
    var matched by remember {
        mutableStateOf(state.product(existing?.bottle?.catalog_product_id))
    }
    var distillery by remember { mutableStateOf(matched?.distillery ?: "") }
    var size by remember { mutableStateOf((existing?.volumeMl ?: 750.0).roundToInt().toString()) }
    var proof by remember {
        mutableStateOf(
            existing?.abv?.let {
                String.format(java.util.Locale.ROOT, "%.1f", it * 2)
            } ?: ""
        )
    }
    var showsAllClasses by remember { mutableStateOf(false) }
    var classType by remember {
        mutableStateOf(
            matched?.classType
                ?: existing?.bottle?.catalog_product_id
                    ?.let { state.bottles.customEntry(it)?.class_type }
                    ?.let { ClassType.fromStorageKey(it) }
        )
    }
    var production by remember {
        mutableStateOf(matched?.productionType ?: ProductionType.UNSPECIFIED)
    }
    var barrelProof by remember { mutableStateOf(matched?.isBarrelProof ?: false) }
    var bottledInBond by remember { mutableStateOf(matched?.isBottledInBond ?: false) }
    var price by remember {
        mutableStateOf(
            existing?.purchasePriceCents?.let {
                String.format(java.util.Locale.ROOT, "%.2f", it / 100.0)
            } ?: ""
        )
    }
    var store by remember { mutableStateOf(existing?.bottle?.purchase_store ?: "") }
    var location by remember { mutableStateOf(existing?.storageLocation ?: "") }
    var barrel by remember { mutableStateOf(existing?.bottle?.barrel_number ?: "") }
    var batch by remember { mutableStateOf(existing?.bottle?.batch_number ?: "") }
    var pickStore by remember { mutableStateOf(existing?.bottle?.pick_store ?: "") }
    var isSample by remember { mutableStateOf(existing?.isSample ?: false) }
    var sampleFrom by remember { mutableStateOf(existing?.bottle?.sample_from ?: "") }
    var openNow by remember { mutableStateOf(existing?.isOpen ?: false) }

    // The catalogue match, if any. Only while adding: re-searching on an edit
    // would let a rename silently repoint the bottle at a different product.
    val hits = remember(name, bottleId) {
        if (bottleId != null || name.trim().length < 2) {
            emptyList()
        } else {
            BottleSearch.search(name, state.catalog.searchCandidates(), limit = 5)
        }
    }

    val volume = LocalNumber.parse(size) ?: 0.0
    val canSave = name.isNotBlank() && volume > 0

    Column(Modifier.fillMaxWidth()) {
        DetailBar(
            title = if (bottleId == null) "Add a bottle" else "Edit",
            onBack = onDone,
            actions = {
                Text(
                    "Save",
                    style = TypeScale.headline,
                    color = colors.accent.copy(alpha = if (canSave) 1f else 0.4f),
                    modifier = Modifier
                        .clickable(enabled = canSave) {
                            val abv = LocalNumber.parse(proof)?.takeIf { it > 0 }?.div(2)
                            val cents = LocalNumber.parse(price)
                                ?.takeIf { it > 0 }
                                ?.let { (it * 100).roundToInt().toLong() }
                            if (bottleId == null) {
                                state.bottles.add(
                                    name = name.trim(),
                                    volumeMl = volume,
                                    // The catalogue's own id when one was
                                    // picked. Without it the shelf check
                                    // would not recognise this bottle as
                                    // the catalogue product it is.
                                    catalogProductId = matched?.id,
                                    abv = abv,
                                    classType = classType,
                                    productionType = production,
                                    isBarrelProof = barrelProof,
                                    isBottledInBond = bottledInBond,
                                    distillery = distillery.trim().ifBlank { null },
                                    isStorePick = pickStore.isNotBlank(),
                                    pickStore = pickStore.trim().ifBlank { null },
                                    barrelNumber = barrel.trim().ifBlank { null },
                                    batchNumber = batch.trim().ifBlank { null },
                                    purchasePriceCents = cents,
                                    purchaseStore = store.trim().ifBlank { null },
                                    storageLocation = location.trim().ifBlank { null },
                                    isSample = isSample,
                                    sampleFrom = sampleFrom.trim().ifBlank { null },
                                    openNow = openNow,
                                )
                            } else {
                                state.bottles.update(
                                    id = bottleId,
                                    name = name.trim(),
                                    volumeMl = volume,
                                    abv = abv,
                                    classType = classType,
                                    productionType = production,
                                    isBarrelProof = barrelProof,
                                    isBottledInBond = bottledInBond,
                                    distillery = distillery.trim().ifBlank { null },
                                    isStorePick = pickStore.isNotBlank(),
                                    pickStore = pickStore.trim().ifBlank { null },
                                    barrelNumber = barrel.trim().ifBlank { null },
                                    batchNumber = batch.trim().ifBlank { null },
                                    purchasePriceCents = cents,
                                    purchaseStore = store.trim().ifBlank { null },
                                    storageLocation = location.trim().ifBlank { null },
                                    isSample = isSample,
                                    sampleFrom = sampleFrom.trim().ifBlank { null },
                                )
                                if (openNow && existing?.isOpen == false) {
                                    state.bottles.open(bottleId)
                                }
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
            item {
                Field(
                    name, { name = it },
                    label = "What it is",
                    placeholder = "Elijah Craig Barrel Proof",
                )
            }

            if (hits.isNotEmpty() && matched == null) {
                item { SectionLabel("From the catalogue") }
                items(hits, key = { it.product.productId }) { hit ->
                    val product = state.catalog.product(hit.product.productId)
                    Card(
                        onClick = {
                            if (product != null) {
                                matched = product
                                name = product.identity.displayName
                                distillery = product.distillery
                                classType = product.classType
                                production = product.productionType
                                barrelProof = product.isBarrelProof
                                bottledInBond = product.isBottledInBond
                                product.abv?.let {
                                    proof = String.format(java.util.Locale.ROOT, "%.1f", it * 2)
                                }
                            }
                        },
                    ) {
                        Text(
                            hit.product.displayName,
                            style = TypeScale.headline,
                            color = colors.text,
                        )
                        Text(
                            listOfNotNull(
                                product?.distillery?.takeIf { it.isNotBlank() },
                                product?.classType?.label,
                            ).joinToString(" · "),
                            style = TypeScale.secondary,
                            color = colors.textSecondary,
                        )
                    }
                }
            }

            matched?.let { product ->
                item {
                    Card {
                        SectionLabel("Matched")
                        Text(
                            product.identity.displayName,
                            style = TypeScale.headline,
                            color = colors.text,
                        )
                        Text(
                            // The catalogue's own source line travels with the
                            // facts it supplied. A fact with no source is a
                            // rumour, and this app does not carry rumours.
                            "From " + product.source.ifBlank { "the bundled catalogue" },
                            style = TypeScale.caption,
                            color = colors.textMuted,
                        )
                        Text(
                            "Use what I typed instead",
                            style = TypeScale.secondary,
                            color = colors.accent,
                            modifier = Modifier
                                .clickable { matched = null }
                                .padding(vertical = Space.s),
                        )
                    }
                }
            }

            item { SectionLabel("The bottle") }
            item {
                Row(horizontalArrangement = Arrangement.spacedBy(Space.m)) {
                    Field(
                        size, { size = it }, label = "Size in ml",
                        numeric = true, modifier = Modifier.weight(1f),
                    )
                    Field(
                        proof, { proof = it }, label = "Proof",
                        numeric = true, decimal = true, modifier = Modifier.weight(1f),
                    )
                }
            }
            item {
                Field(distillery, { distillery = it }, label = "Distillery")
            }

            item { SectionLabel("Class type") }
            item {
                // The regulation classes, not a free-text field: "bourbon"
                // typed three ways is three categories that never group.
                //
                // The twelve below are whiskey because that is what most
                // people are entering. Everything else was UNREACHABLE: a
                // hand-typed cider, seltzer, port or tequila could not be
                // given a class at all, which is half the catalogue and all
                // of what was added to it this week. "Everything else" opens
                // the rest, grouped by family.
                Row(
                    modifier = Modifier.horizontalScroll(rememberScrollState()),
                    horizontalArrangement = Arrangement.spacedBy(Space.s),
                ) {
                    for (option in commonClasses) {
                        Chip(option.label, isOn = classType == option) {
                            classType = if (classType == option) null else option
                        }
                    }
                }
            }
            item {
                val chosenElsewhere = classType != null && classType !in commonClasses
                Text(
                    if (showsAllClasses) "Fewer"
                    else if (chosenElsewhere) "Everything else · " + classType!!.label
                    else "Everything else",
                    style = TypeScale.caption,
                    color = palette.accent,
                    modifier = Modifier
                        .clickable { showsAllClasses = !showsAllClasses }
                        .padding(vertical = Space.s),
                )
            }
            if (showsAllClasses) {
                for (family in ClassType.Family.entries) {
                    val members = ClassType.entries.filter {
                        it.family == family && it !in commonClasses
                    }
                    if (members.isEmpty()) continue
                    item {
                        Text(
                            family.label,
                            style = TypeScale.caption,
                            color = palette.textMuted,
                            modifier = Modifier.padding(top = Space.s),
                        )
                    }
                    item {
                        Row(
                            modifier = Modifier.horizontalScroll(rememberScrollState()),
                            horizontalArrangement = Arrangement.spacedBy(Space.s),
                        ) {
                            for (option in members) {
                                Chip(option.label, isOn = classType == option) {
                                    classType = if (classType == option) null else option
                                }
                            }
                        }
                    }
                }
            }

            item { SectionLabel("Production type") }
            item {
                Row(
                    modifier = Modifier.horizontalScroll(rememberScrollState()),
                    horizontalArrangement = Arrangement.spacedBy(Space.s),
                ) {
                    for (option in ProductionType.entries) {
                        Chip(option.label, isOn = production == option) { production = option }
                    }
                }
            }
            item {
                ChipRow {
                    Chip("Barrel proof", isOn = barrelProof) { barrelProof = !barrelProof }
                    Chip("Bottled in bond", isOn = bottledInBond) {
                        bottledInBond = !bottledInBond
                    }
                }
            }

            item { SectionLabel("Where it came from") }
            item {
                Row(horizontalArrangement = Arrangement.spacedBy(Space.m)) {
                    Field(
                        price, { price = it }, label = "Paid",
                        numeric = true, decimal = true, modifier = Modifier.weight(1f),
                    )
                    Field(store, { store = it }, label = "Store", modifier = Modifier.weight(1f))
                }
            }
            item { Field(location, { location = it }, label = "Where you keep it") }

            item { SectionLabel("Batch and barrel") }
            item {
                Row(horizontalArrangement = Arrangement.spacedBy(Space.m)) {
                    Field(batch, { batch = it }, label = "Batch", modifier = Modifier.weight(1f))
                    Field(barrel, { barrel = it }, label = "Barrel", modifier = Modifier.weight(1f))
                }
            }
            item { Field(pickStore, { pickStore = it }, label = "Store pick for") }

            item { SectionLabel("Anything else") }
            item {
                ChipRow {
                    Chip("It is a sample", isOn = isSample) { isSample = !isSample }
                    if (bottleId == null) {
                        Chip("Already open", isOn = openNow) { openNow = !openNow }
                    }
                }
            }
            if (isSample) {
                item { Field(sampleFrom, { sampleFrom = it }, label = "From whom") }
            }

            item {
                Text(
                    "Everything works with no account. Nothing leaves this phone " +
                        "unless you sign in.",
                    style = TypeScale.caption,
                    color = colors.textMuted,
                    modifier = Modifier.padding(top = Space.l, bottom = 64.dp),
                )
            }
        }
    }
}

/**
 * The classes most bottles on an American shelf belong to.
 *
 * Not all fifty the engine knows: a chip row of fifty is a list nobody
 * scrolls. The rest arrive by matching the catalogue, which carries the full
 * set.
 */
private val commonClasses = listOf(
    ClassType.KENTUCKY_STRAIGHT_BOURBON,
    ClassType.STRAIGHT_BOURBON,
    ClassType.BOURBON,
    ClassType.STRAIGHT_RYE,
    ClassType.RYE,
    ClassType.TENNESSEE_WHISKEY,
    ClassType.AMERICAN_SINGLE_MALT,
    ClassType.SINGLE_MALT_SCOTCH,
    ClassType.BLENDED_SCOTCH,
    ClassType.IRISH_WHISKEY,
    ClassType.JAPANESE_WHISKY,
    ClassType.CANADIAN_WHISKY,
)
