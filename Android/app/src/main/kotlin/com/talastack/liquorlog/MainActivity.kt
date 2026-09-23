package com.talastack.liquorlog

import android.content.Context
import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.compose.runtime.remember
import androidx.core.view.WindowCompat
import app.cash.sqldelight.db.SqlDriver
import app.cash.sqldelight.driver.android.AndroidSqliteDriver
import com.talastack.liquorlog.data.BottleRepository
import com.talastack.liquorlog.data.BundledData
import com.talastack.liquorlog.data.CollectionExport
import com.talastack.liquorlog.data.Database
import com.talastack.liquorlog.data.LiquorDatabase
import com.talastack.liquorlog.data.PeopleLedger
import com.talastack.liquorlog.data.SightingRepository
import com.talastack.liquorlog.data.TastingRepository
import com.talastack.liquorlog.data.WishlistRepository
import com.talastack.liquorlog.ui.AppState
import com.talastack.liquorlog.ui.MainScreen
import com.talastack.liquorlog.ui.VolumeDisplay
import com.talastack.liquorlog.ui.theme.Appearance
import com.talastack.liquorlog.ui.theme.LiquorLogTheme
import com.talastack.liquorlog.ui.theme.Look

class MainActivity : ComponentActivity() {

    private lateinit var driver: SqlDriver
    private lateinit var database: LiquorDatabase

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        WindowCompat.setDecorFitsSystemWindows(window, true)

        driver = AndroidSqliteDriver(
            schema = LiquorDatabase.Schema,
            context = this,
            name = "liquorlog.db",
        )
        // The driver creates the schema itself, so do not ask for it twice --
        // but the foreign key pragma is still ours to set, and is still per
        // connection. Without it a deleted bottle orphans its pours.
        database = Database.open(driver, createSchema = false)

        val preferences = getSharedPreferences("liquorlog", Context.MODE_PRIVATE)

        // Read once, at launch, off the assets in the APK. The catalogue is
        // half a megabyte of JSON and the shelf check is the first tab: the
        // one thing it must not do is parse it again on every keystroke.
        val catalog = BundledData.catalog(this)
        val wheel = BundledData.flavorWheel(this)

        setContent {
            val state = remember {
                AppState(
                    bottles = BottleRepository(database),
                    tastings = TastingRepository(database),
                    wishlist = WishlistRepository(database),
                    sightings = SightingRepository(database),
                    people = PeopleLedger(database),
                    export = CollectionExport(database),
                    catalog = catalog,
                    wheel = wheel,
                    look = Look.fromKey(preferences.getString(Look.KEY, null)),
                    onLookPicked = {
                        preferences.edit().putString(Look.KEY, it.key).apply()
                    },
                    appearance = Appearance.fromKey(preferences.getString(Appearance.KEY, null)),
                    onAppearancePicked = {
                        preferences.edit().putString(Appearance.KEY, it.key).apply()
                    },
                    ounces = preferences.getBoolean(VolumeDisplay.KEY, false),
                    onUnitsPicked = {
                        preferences.edit().putBoolean(VolumeDisplay.KEY, it).apply()
                    },
                    // Off unless somebody turned it on, on every device.
                    showsValue = preferences.getBoolean(SHOWS_VALUE_KEY, false),
                    onShowsValuePicked = {
                        preferences.edit().putBoolean(SHOWS_VALUE_KEY, it).apply()
                    },
                )
            }
            LiquorLogTheme(look = state.look, appearance = state.appearance) {
                MainScreen(state)
            }
        }
    }

    override fun onDestroy() {
        super.onDestroy()
        driver.close()
    }

    private companion object {
        const val SHOWS_VALUE_KEY = "showsCollectionValue"
    }
}
