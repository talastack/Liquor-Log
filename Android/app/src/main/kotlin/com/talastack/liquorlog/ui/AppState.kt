package com.talastack.liquorlog.ui

import androidx.compose.runtime.Stable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.setValue
import androidx.compose.runtime.staticCompositionLocalOf
import com.talastack.liquorlog.data.BottlePhotoStore
import com.talastack.liquorlog.data.BottleRepository
import com.talastack.liquorlog.data.CollectionExport
import com.talastack.liquorlog.data.PeopleLedger
import com.talastack.liquorlog.data.SightingRepository
import com.talastack.liquorlog.data.TastingRepository
import com.talastack.liquorlog.data.WishlistRepository
import com.talastack.liquorlog.engine.Catalog
import com.talastack.liquorlog.engine.CatalogProduct
import com.talastack.liquorlog.engine.FlavorWheel
import com.talastack.liquorlog.engine.ProductIdentity
import com.talastack.liquorlog.ui.theme.Appearance
import com.talastack.liquorlog.ui.theme.Look

/**
 * Everything a screen needs, in one place.
 *
 * The Compose counterpart of the iOS `AppEnvironment`, down to
 * [changeCount]: screens read the database on composition and re-read when
 * that number moves. It is a counter rather than a set of observable queries
 * because a pour changes a bottle, its fill, its tastings and the collection
 * header at once, and four separate observers would redraw four times and
 * still not agree with each other mid-flight.
 */
@Stable
class AppState(
    val bottles: BottleRepository,
    val tastings: TastingRepository,
    val wishlist: WishlistRepository,
    val sightings: SightingRepository,
    val people: PeopleLedger,
    val export: CollectionExport,
    /**
     * Where bottle photos are kept. Null when the folder could not be made,
     * which is the same to every screen as a bottle with no photo.
     */
    val photos: BottlePhotoStore?,
    /** The bundled catalogue. Empty when the asset could not be read. */
    val catalog: Catalog,
    /** The bundled flavour wheel. Null when the asset could not be read. */
    val wheel: FlavorWheel?,
    look: Look,
    private val onLookPicked: (Look) -> Unit,
    appearance: Appearance,
    private val onAppearancePicked: (Appearance) -> Unit,
    ounces: Boolean,
    private val onUnitsPicked: (Boolean) -> Unit,
    showsValue: Boolean,
    private val onShowsValuePicked: (Boolean) -> Unit,
) {
    var changeCount by mutableIntStateOf(0)
        private set

    var look by mutableStateOf(look)
        private set

    /** Light, dark, or the phone's own setting. */
    var appearance by mutableStateOf(appearance)
        private set

    /** Shown in ounces rather than millilitres. A preference, never data. */
    var ounces by mutableStateOf(ounces)
        private set

    /**
     * Whether the collection shows what it cost.
     *
     * Off unless somebody turned it on. The figure is wanted by some people
     * and actively avoided by others, and a total nobody asked for is the
     * version that causes harm.
     */
    var showsValue by mutableStateOf(showsValue)
        private set

    /** Something was written. Every screen on screen re-reads. */
    fun noteChange() {
        changeCount += 1
    }

    fun pick(look: Look) {
        this.look = look
        onLookPicked(look)
    }

    fun pick(appearance: Appearance) {
        this.appearance = appearance
        onAppearancePicked(appearance)
    }

    fun pick(ounces: Boolean) {
        this.ounces = ounces
        onUnitsPicked(ounces)
    }

    fun showValue(shows: Boolean) {
        this.showsValue = shows
        onShowsValuePicked(shows)
    }

    // Naming a bottle

    /**
     * The catalogue product behind a bottle, when it has one.
     *
     * A bottle typed in by hand points at a custom entry instead, which is
     * not in the catalogue -- so this is null for it, and the callers below
     * fall back to what the person typed.
     */
    fun product(catalogProductId: String?): CatalogProduct? =
        catalogProductId?.let { catalog.product(it) }

    fun identity(catalogProductId: String?): ProductIdentity? =
        product(catalogProductId)?.identity

    /** What to call a bottle: the catalogue's name, or the typed one. */
    fun name(summary: BottleRepository.Summary): String =
        identity(summary.bottle.catalog_product_id)?.displayName ?: summary.name

    /** Who made it, when that is known. Never guessed from the name. */
    fun distillery(summary: BottleRepository.Summary): String? =
        product(summary.bottle.catalog_product_id)?.distillery?.takeIf { it.isNotBlank() }
}

val LocalAppState = staticCompositionLocalOf<AppState> {
    error("No AppState. Every screen is built inside MainScreen, which provides one.")
}
