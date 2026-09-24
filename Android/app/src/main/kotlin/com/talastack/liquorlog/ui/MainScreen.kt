package com.talastack.liquorlog.ui

import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.List
import androidx.compose.material.icons.filled.Add
import androidx.compose.material.icons.filled.MoreHoriz
import androidx.compose.material.icons.filled.Search
import androidx.compose.material.icons.filled.WineBar
import androidx.compose.material3.Icon
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.ModalBottomSheet
import androidx.compose.material3.NavigationBar
import androidx.compose.material3.NavigationBarItem
import androidx.compose.material3.NavigationBarItemDefaults
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Text
import androidx.compose.material3.rememberModalBottomSheetState
import androidx.compose.runtime.Composable
import androidx.compose.runtime.CompositionLocalProvider
import androidx.compose.runtime.getValue
import androidx.compose.ui.platform.LocalDensity
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.draw.shadow
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.unit.dp
import androidx.navigation.NavHostController
import androidx.navigation.NavType
import androidx.navigation.compose.NavHost
import androidx.navigation.compose.composable
import androidx.navigation.compose.currentBackStackEntryAsState
import androidx.navigation.compose.rememberNavController
import androidx.navigation.navArgument
import com.talastack.liquorlog.ui.theme.Space
import com.talastack.liquorlog.ui.theme.TypeScale
import com.talastack.liquorlog.ui.theme.palette

/**
 * The four tabs, matching the iOS `Tab` enum case for case.
 *
 * An enum rather than a set of route strings, so every destination is
 * exhaustively switched and a typo is a compile error rather than a blank
 * screen.
 */
enum class Tab(val route: String, val title: String, val icon: ImageVector) {
    SHELF_CHECK("shelf", "Shelf Check", Icons.Filled.Search),
    COLLECTION("collection", "Collection", Icons.AutoMirrored.Filled.List),
    TASTING("tasting", "Tasting", Icons.Filled.WineBar),
    MORE("more", "More", Icons.Filled.MoreHoriz),
}

/**
 * Routes that are not tabs.
 *
 * Only what has a screen. A constant for a destination that does not exist
 * is a link somebody adds later that navigates nowhere.
 */
object Route {
    const val BOTTLE = "bottle"
    const val ADD_BOTTLE = "addBottle"
    const val EDIT_BOTTLE = "editBottle"
    const val TASTING_SHEET = "tastingSheet"
    const val TASTING_EDIT = "tastingEdit"
    const val CATALOG = "catalog"
    const val STATS = "stats"
    const val CODE_DECODER = "codeDecoder"
    const val PICK_MY_POUR = "pickMyPour"
    const val POUR_MENU = "pourMenu"
    const val INSURANCE = "insurance"
    const val COCKTAILS = "cocktails"
    const val YEAR = "year"
    const val PALATE = "palate"
    const val TRY_NEXT = "tryNext"
    const val WISHLIST = "wishlist"
    const val EXPORT = "export"
    const val IMPORT = "import"
    const val HUNT_LOG = "huntLog"
    const val BUY_SIGHTING = "buySighting"
    const val PASSPORT = "passport"
    const val PEOPLE = "people"

    fun bottle(id: String) = BOTTLE + "/" + id
    fun editBottle(id: String) = EDIT_BOTTLE + "/" + id

    /**
     * "-" rather than an optional argument: an absent path segment and an
     * empty one are two ways to say the same thing, and one of them silently
     * fails to match the route.
     */
    fun tastingSheet(bottleId: String?) = TASTING_SHEET + "/" + (bottleId ?: "-")

    fun tastingEdit(tastingId: String) = TASTING_EDIT + "/" + tastingId

    fun buySighting(sightingId: String) = BUY_SIGHTING + "/" + sightingId
}

/**
 * The app's chrome: four tabs, one back stack, and the add button.
 *
 * The "+" floats above the bar rather than sitting in it, the same compromise
 * the iOS build made: a true centre tab button needs a custom bar with real
 * safe-area and accessibility pitfalls, and this gets the action on screen
 * from day one without faking the chrome.
 */
@Composable
fun MainScreen(state: AppState) {
    val navController = rememberNavController()
    val backStack by navController.currentBackStackEntryAsState()
    val route = backStack?.destination?.route
    val onTab = Tab.entries.any { it.route == route }
    var isChoosingWhatToAdd by remember { mutableStateOf(false) }
    var isStartingInfinity by remember { mutableStateOf(false) }
    val colors = palette

    CompositionLocalProvider(LocalAppState provides state) {
        Scaffold(
            containerColor = colors.background,
            bottomBar = { if (onTab) TabBar(navController, route) },
        ) { padding ->
            Box(modifier = Modifier.fillMaxSize().padding(padding)) {
                AppNavHost(navController, state)

                // Only over the tabs. On a bottle's own screen the actions
                // belong to that bottle, and a floating "+" over them adds
                // a second meaning to the same gesture.
                if (onTab) {
                    AddButton(
                        modifier = Modifier
                            .align(Alignment.BottomCenter)
                            .padding(bottom = Space.l),
                        onClick = { isChoosingWhatToAdd = true },
                    )
                }
            }
        }
    }

    if (isChoosingWhatToAdd) {
        AddSheet(
            onDismiss = { isChoosingWhatToAdd = false },
            onAddBottle = {
                isChoosingWhatToAdd = false
                navController.navigate(Route.ADD_BOTTLE)
            },
            onRecordTasting = {
                isChoosingWhatToAdd = false
                navController.navigate(Route.tastingSheet(null))
            },
            onStartInfinity = {
                isChoosingWhatToAdd = false
                isStartingInfinity = true
            },
        )
    }

    if (isStartingInfinity) {
        InfinityBottleDialog(
            onDismiss = { isStartingInfinity = false },
            onStart = { name, ml ->
                state.bottles.startInfinityBottle(name = name, volumeMl = ml)
                state.noteChange()
                isStartingInfinity = false
            },
        )
    }
}

@Composable
private fun TabBar(navController: NavHostController, route: String?) {
    val colors = palette
    NavigationBar(containerColor = colors.surface, tonalElevation = 0.dp) {
        for (tab in Tab.entries) {
            NavigationBarItem(
                selected = route == tab.route,
                onClick = {
                    if (route != tab.route) {
                        navController.navigate(tab.route) {
                            // One entry per tab on the stack, and the tab you
                            // left is where you left it when you come back.
                            popUpTo(Tab.SHELF_CHECK.route) { saveState = true }
                            launchSingleTop = true
                            restoreState = true
                        }
                    }
                },
                icon = { Icon(tab.icon, contentDescription = null) },
                label = { TabLabel(tab.title) },
                colors = NavigationBarItemDefaults.colors(
                    selectedIconColor = colors.onAccent,
                    selectedTextColor = colors.accent,
                    indicatorColor = colors.accent,
                    unselectedIconColor = colors.textSecondary,
                    unselectedTextColor = colors.textSecondary,
                ),
            )
        }
    }
}

@Composable
private fun AddButton(modifier: Modifier = Modifier, onClick: () -> Unit) {
    val colors = palette
    Box(
        modifier = modifier
            .size(Space.tapTarget)
            // The shadow is not decoration. This button floats over a
            // scrolling list, and without one it reads as part of whichever
            // row happens to be under it.
            .shadow(8.dp, CircleShape)
            .clip(CircleShape)
            .background(colors.accent)
            .clickable(onClick = onClick),
        contentAlignment = Alignment.Center,
    ) {
        Icon(
            Icons.Filled.Add,
            contentDescription = "Add a bottle or a tasting",
            tint = colors.onAccent,
            modifier = Modifier.size(24.dp),
        )
    }
}

/** The same choices the iOS confirmation dialog offers. */
@OptIn(ExperimentalMaterial3Api::class)
@Composable
private fun AddSheet(
    onDismiss: () -> Unit,
    onAddBottle: () -> Unit,
    onRecordTasting: () -> Unit,
    onStartInfinity: () -> Unit,
) {
    val colors = palette
    ModalBottomSheet(
        onDismissRequest = onDismiss,
        containerColor = colors.surface,
        sheetState = rememberModalBottomSheetState(),
    ) {
        Column(
            modifier = Modifier.fillMaxWidth().padding(Space.l),
            verticalArrangement = Arrangement.spacedBy(Space.s),
        ) {
            Text("Add", style = TypeScale.title, color = colors.text)
            SheetRow("Add a bottle", "Search the catalogue or type it in", onAddBottle)
            SheetRow("Record a tasting", "A rating on its own is enough", onRecordTasting)
            SheetRow(
                "Start an infinity bottle",
                "An empty vessel you fill from your others",
                onStartInfinity,
            )
            Box(Modifier.padding(bottom = Space.xl))
        }
    }
}

@Composable
private fun SheetRow(title: String, detail: String, onClick: () -> Unit) {
    val colors = palette
    Card(onClick = onClick) {
        Text(title, style = TypeScale.headline, color = colors.text)
        Text(detail, style = TypeScale.secondary, color = colors.textMuted)
    }
}

@Composable
private fun AppNavHost(navController: NavHostController, state: AppState) {
    NavHost(navController, startDestination = Tab.SHELF_CHECK.route) {
        composable(Tab.SHELF_CHECK.route) {
            ShelfCheckScreen(
                onOpenBottle = { navController.navigate(Route.bottle(it)) },
            )
        }
        composable(Tab.COLLECTION.route) {
            CollectionScreen(
                onOpenBottle = { navController.navigate(Route.bottle(it)) },
                onAddBottle = { navController.navigate(Route.ADD_BOTTLE) },
            )
        }
        composable(Tab.TASTING.route) {
            TastingHistoryScreen(
                onOpenBottle = { navController.navigate(Route.bottle(it)) },
                onRecord = { navController.navigate(Route.tastingSheet(null)) },
            )
        }
        composable(Tab.MORE.route) {
            MoreScreen(onOpen = { navController.navigate(it) })
        }

        composable(
            Route.BOTTLE + "/{id}",
            arguments = listOf(navArgument("id") { type = NavType.StringType }),
        ) { entry ->
            BottleDetailScreen(
                bottleId = entry.arguments?.getString("id").orEmpty(),
                onBack = { navController.popBackStack() },
                onEdit = { navController.navigate(Route.editBottle(it)) },
                onRecordTasting = { navController.navigate(Route.tastingSheet(it)) },
                onEditTasting = { navController.navigate(Route.tastingEdit(it)) },
            )
        }
        composable(Route.ADD_BOTTLE) {
            AddBottleScreen(
                bottleId = null,
                onDone = { navController.popBackStack() },
            )
        }
        composable(
            Route.BUY_SIGHTING + "/{id}",
            arguments = listOf(navArgument("id") { type = NavType.StringType }),
        ) { entry ->
            AddBottleScreen(
                bottleId = null,
                onDone = { navController.popBackStack() },
                fromSightingId = entry.arguments?.getString("id"),
            )
        }
        composable(
            Route.EDIT_BOTTLE + "/{id}",
            arguments = listOf(navArgument("id") { type = NavType.StringType }),
        ) { entry ->
            AddBottleScreen(
                bottleId = entry.arguments?.getString("id"),
                onDone = { navController.popBackStack() },
            )
        }
        composable(
            Route.TASTING_SHEET + "/{bottleId}",
            arguments = listOf(navArgument("bottleId") { type = NavType.StringType }),
        ) { entry ->
            val raw = entry.arguments?.getString("bottleId")
            TastingSheetScreen(
                bottleId = raw?.takeIf { it != "-" },
                onDone = { navController.popBackStack() },
            )
        }
        composable(
            Route.TASTING_EDIT + "/{tastingId}",
            arguments = listOf(navArgument("tastingId") { type = NavType.StringType }),
        ) { entry ->
            val state = LocalAppState.current
            val id = entry.arguments?.getString("tastingId")
            val editing = remember(id) { id?.let { state.tastings.byId(it) } }
            if (editing == null) {
                // The tasting was removed while this screen was on the back
                // stack. Going back is better than an empty form that would
                // save a second tasting nobody asked for.
                LaunchedEffect(Unit) { navController.popBackStack() }
            } else {
                TastingSheetScreen(
                    bottleId = editing.bottleId,
                    editing = editing,
                    onDone = { navController.popBackStack() },
                )
            }
        }
        composable(Route.CATALOG) {
            CatalogBrowseScreen(onBack = { navController.popBackStack() })
        }
        composable(Route.STATS) {
            StatsScreen(onBack = { navController.popBackStack() })
        }
        composable(Route.CODE_DECODER) {
            CodeDecoderScreen(onBack = { navController.popBackStack() })
        }
        composable(Route.PICK_MY_POUR) {
            PickMyPourScreen(
                onBack = { navController.popBackStack() },
                onOpenBottle = { navController.navigate(Route.bottle(it)) },
            )
        }
        composable(Route.POUR_MENU) {
            PourMenuScreen(onBack = { navController.popBackStack() })
        }
        composable(Route.INSURANCE) {
            InsuranceReportScreen(onBack = { navController.popBackStack() })
        }
        composable(Route.COCKTAILS) {
            CocktailsScreen(onBack = { navController.popBackStack() })
        }
        composable(Route.YEAR) {
            YearScreen(onBack = { navController.popBackStack() })
        }
        composable(Route.PALATE) {
            PalateScreen(onBack = { navController.popBackStack() })
        }
        composable(Route.TRY_NEXT) {
            TryNextScreen(
                onBack = { navController.popBackStack() },
                onWish = { productId ->
                    state.wishlist.add(catalogProductId = productId)
                    state.noteChange()
                },
            )
        }
        composable(Route.WISHLIST) {
            WishlistScreen(onBack = { navController.popBackStack() })
        }
        composable(Route.EXPORT) {
            ExportScreen(onBack = { navController.popBackStack() })
        }
        composable(Route.IMPORT) {
            ImportScreen(onBack = { navController.popBackStack() })
        }
        composable(Route.HUNT_LOG) {
            HuntLogScreen(
                onBack = { navController.popBackStack() },
                onBuy = { navController.navigate(Route.buySighting(it)) },
            )
        }
        composable(Route.PASSPORT) {
            PassportScreen(onBack = { navController.popBackStack() })
        }
        composable(Route.PEOPLE) {
            PeopleScreen(onBack = { navController.popBackStack() })
        }
    }
}

/**
 * A tab's name, allowed to grow with the text-size setting up to 1.3x and
 * no further.
 *
 * Four labels share the width of the phone. At the largest setting
 * "Collection" broke in the middle of the word -- "Collecti / on" -- and
 * "Shelf Check" took two lines. iOS does not grow tab labels with Dynamic
 * Type at all, for the same reason; everything ABOVE the bar still scales
 * in full, which is where the reading happens.
 */
@Composable
private fun TabLabel(title: String) {
    val fontScale = LocalDensity.current.fontScale
    val base = TypeScale.caption
    val capped = if (fontScale > MAX_TAB_LABEL_SCALE) {
        base.copy(fontSize = base.fontSize * (MAX_TAB_LABEL_SCALE / fontScale))
    } else {
        base
    }
    Text(title, style = capped, maxLines = 1, softWrap = false)
}

private const val MAX_TAB_LABEL_SCALE = 1.3f
