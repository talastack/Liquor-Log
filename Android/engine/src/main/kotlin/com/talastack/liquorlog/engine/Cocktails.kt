package com.talastack.liquorlog.engine

import java.util.Locale
import kotlin.math.roundToInt

/**
 * What can be made tonight from what is open.
 *
 * The specs are the International Bartenders Association's official recipes
 * (iba-world.com/cocktails), the one list that is a standard rather than an
 * opinion, transcribed as ingredient lists with the IBA's own measures. A
 * recipe is not copyrightable and these are the IBA's to publish; nothing
 * here is invented, and where the IBA names a choice ("bourbon or rye") the
 * choice is kept.
 *
 * Matching is by what a bottle IS, from its class, never by name alone: a
 * Manhattan wants a rye or bourbon and a sweet vermouth, and any open bottle
 * of those classes fills the slot. The bottle picked for a slot is the
 * highest-rated open one, then the fullest. Bitters, citrus, sugar and soda
 * are pantry and are listed as things to have, not matched. A recipe with
 * every spirit slot filled is "ready"; one slot short is "nearly", with what
 * would fill it named.
 */
object Cocktails {

    /**
     * What a slot in a recipe accepts. Each case is a test of a bottle's
     * class, and for a few of the liqueur slots its name, since the catalogue
     * does not split liqueurs finer than that.
     */
    enum class Slot(val storageKey: String) {
        BOURBON_OR_RYE("bourbonOrRye"),
        BOURBON("bourbon"),
        RYE("rye"),
        SCOTCH("scotch"),
        ISLAY_SCOTCH("islayScotch"),
        IRISH_WHISKEY("irishWhiskey"),
        ANY_WHISKEY("anyWhiskey"),
        GIN("gin"),
        VODKA("vodka"),
        WHITE_RUM("whiteRum"),
        DARK_RUM("darkRum"),
        AGRICOLE_OR_JAMAICAN_RUM("agricoleOrJamaicanRum"),
        TEQUILA("tequila"),
        MEZCAL("mezcal"),
        COGNAC("cognac"),
        BRANDY("brandy"),
        SWEET_VERMOUTH("sweetVermouth"),
        DRY_VERMOUTH("dryVermouth"),
        CAMPARI("campari"),
        APEROL("aperol"),
        ORANGE_LIQUEUR("orangeLiqueur"),
        COFFEE_LIQUEUR("coffeeLiqueur"),
        AMARETTO("amaretto"),
        DRAMBUIE("drambuie"),
        MARASCHINO("maraschino"),
        GREEN_CHARTREUSE("greenChartreuse"),
        BLACKBERRY_LIQUEUR("blackberryLiqueur"),
        ABSINTHE("absinthe");

        val label: String
            get() = when (this) {
                BOURBON_OR_RYE -> "bourbon or rye"
                BOURBON -> "bourbon"
                RYE -> "rye"
                SCOTCH -> "Scotch"
                ISLAY_SCOTCH -> "Islay Scotch"
                IRISH_WHISKEY -> "Irish whiskey"
                ANY_WHISKEY -> "whiskey"
                GIN -> "gin"
                VODKA -> "vodka"
                WHITE_RUM -> "white rum"
                DARK_RUM -> "dark rum"
                AGRICOLE_OR_JAMAICAN_RUM -> "rhum agricole or Jamaican rum"
                TEQUILA -> "tequila"
                MEZCAL -> "mezcal"
                COGNAC -> "cognac"
                BRANDY -> "brandy"
                SWEET_VERMOUTH -> "sweet vermouth"
                DRY_VERMOUTH -> "dry vermouth"
                CAMPARI -> "Campari"
                APEROL -> "Aperol"
                ORANGE_LIQUEUR -> "orange liqueur"
                COFFEE_LIQUEUR -> "coffee liqueur"
                AMARETTO -> "amaretto"
                DRAMBUIE -> "Drambuie"
                MARASCHINO -> "maraschino liqueur"
                GREEN_CHARTREUSE -> "green Chartreuse"
                BLACKBERRY_LIQUEUR -> "crème de mûre"
                ABSINTHE -> "absinthe"
            }

        /**
         * Whether a bottle fills this slot. [name] is the product's full
         * name, lowercased and folded, for the slots the class cannot settle
         * alone.
         */
        fun accepts(classType: ClassType, name: String): Boolean {
            fun named(words: List<String>): Boolean = words.any { name.contains(it) }

            return when (this) {
                BOURBON_OR_RYE ->
                    classType in BOURBONS || classType in RYES ||
                        classType == ClassType.TENNESSEE_WHISKEY
                BOURBON -> classType in BOURBONS || classType == ClassType.TENNESSEE_WHISKEY
                RYE -> classType in RYES
                SCOTCH -> classType in SCOTCHES
                ISLAY_SCOTCH -> classType in SCOTCHES && named(
                    listOf(
                        "ardbeg", "laphroaig", "lagavulin", "caol ila", "bowmore",
                        "bunnahabhain", "kilchoman", "bruichladdich", "port charlotte",
                        "octomore", "islay"
                    )
                )
                IRISH_WHISKEY -> classType in IRISH
                ANY_WHISKEY -> classType.family == ClassType.Family.WHISKEY
                GIN -> classType in GINS
                VODKA -> classType == ClassType.VODKA
                WHITE_RUM -> classType == ClassType.RUM && named(WHITE_RUM_WORDS)
                DARK_RUM -> classType == ClassType.RUM && !named(WHITE_RUM_WORDS)
                AGRICOLE_OR_JAMAICAN_RUM ->
                    classType == ClassType.RHUM_AGRICOLE ||
                        (
                            classType == ClassType.RUM && named(
                                listOf(
                                    "appleton", "jamaica", "smith & cross", "hampden",
                                    "worthy park", "myers"
                                )
                            )
                            )
                TEQUILA -> classType in TEQUILAS
                MEZCAL -> classType == ClassType.MEZCAL
                COGNAC -> classType == ClassType.COGNAC
                BRANDY -> classType in BRANDIES
                SWEET_VERMOUTH -> classType == ClassType.VERMOUTH &&
                    !named(listOf("dry", "blanc", "bianco", "extra dry"))
                DRY_VERMOUTH -> classType == ClassType.VERMOUTH &&
                    named(listOf("dry", "extra dry"))
                CAMPARI -> named(listOf("campari"))
                APEROL -> named(listOf("aperol"))
                ORANGE_LIQUEUR -> named(
                    listOf(
                        "cointreau", "triple sec", "curacao", "curaçao",
                        "grand marnier", "orange liqueur", "combier"
                    )
                )
                COFFEE_LIQUEUR -> named(
                    listOf("kahlua", "kahlúa", "coffee liqueur", "mr black", "tia maria")
                )
                AMARETTO -> named(listOf("amaretto", "disaronno"))
                DRAMBUIE -> named(listOf("drambuie"))
                MARASCHINO -> named(listOf("maraschino", "luxardo"))
                GREEN_CHARTREUSE -> named(listOf("chartreuse")) && !named(listOf("yellow"))
                BLACKBERRY_LIQUEUR -> named(
                    listOf("creme de mure", "crème de mûre", "blackberry")
                )
                ABSINTHE -> classType == ClassType.ABSINTHE
            }
        }

        private companion object {
            val BOURBONS = setOf(
                ClassType.BOURBON, ClassType.STRAIGHT_BOURBON,
                ClassType.KENTUCKY_STRAIGHT_BOURBON, ClassType.BLEND_OF_STRAIGHT_BOURBON
            )
            val RYES = setOf(ClassType.RYE, ClassType.STRAIGHT_RYE)
            val SCOTCHES = setOf(
                ClassType.SINGLE_MALT_SCOTCH, ClassType.BLENDED_MALT_SCOTCH,
                ClassType.SINGLE_GRAIN_SCOTCH, ClassType.BLENDED_SCOTCH
            )
            val IRISH = setOf(
                ClassType.IRISH_WHISKEY, ClassType.SINGLE_POT_STILL_IRISH,
                ClassType.SINGLE_MALT_IRISH
            )
            val TEQUILAS = setOf(
                ClassType.TEQUILA_BLANCO, ClassType.TEQUILA_REPOSADO,
                ClassType.TEQUILA_ANEJO, ClassType.TEQUILA_EXTRA_ANEJO
            )
            val GINS = setOf(ClassType.LONDON_DRY_GIN, ClassType.DISTILLED_GIN, ClassType.GENEVER)
            val BRANDIES = setOf(
                ClassType.COGNAC, ClassType.ARMAGNAC, ClassType.CALVADOS,
                ClassType.BRANDY, ClassType.PISCO
            )
            val WHITE_RUM_WORDS = listOf(
                "white", "blanco", "silver", "light", "superior", "3 stars",
                "plata", "carta blanca"
            )
        }
    }

    /**
     * One line of a recipe: a slot to fill from the shelf, or something from
     * the kitchen.
     */
    sealed class Ingredient {
        data class Bottle(val slot: Slot, val milliliters: Double) : Ingredient()
        /**
         * Named `note` rather than `text`: the sealed class already has a
         * `text` for display, and a subclass property of the same name
         * would resolve to itself inside that getter. Swift's associated
         * value has no name at all, so nothing is lost.
         */
        data class Pantry(val note: String) : Ingredient()

        val text: String
            get() = when (this) {
                is Bottle -> "${measure(milliliters)} ${slot.label}"
                is Pantry -> note
            }

        companion object {
            internal fun measure(ml: Double): String =
                if (ml == ml.roundToInt().toDouble()) {
                    "${ml.roundToInt()} ml"
                } else {
                    String.format(Locale.ROOT, "%.1f ml", ml)
                }
        }
    }

    data class Recipe(
        val id: String,
        val name: String,
        val ingredients: List<Ingredient>,
        val method: String,
        val glass: String
    ) {
        val slots: List<Slot>
            get() = ingredients.mapNotNull { (it as? Ingredient.Bottle)?.slot }
    }

    /** A bottle as the matcher sees it. */
    data class Candidate(
        val id: String,
        val name: String,
        val classType: ClassType,
        val isOpen: Boolean,
        val rating: Int? = null,
        val fillFraction: Double = 1.0
    ) {
        internal val folded: String get() = name.normalizedForMatching()
    }

    /** A slot nothing open fits, with a sealed bottle that would, if any. */
    data class MissingSlot(val slot: Slot, val sealed: Candidate?)

    data class Match(
        val recipe: Recipe,
        /**
         * The open bottle chosen for each slot; absent where nothing open
         * fits.
         */
        val picks: Map<Slot, Candidate>,
        val missing: List<MissingSlot>
    ) {
        val id: String get() = recipe.id
        val isReady: Boolean get() = missing.isEmpty()
    }

    /**
     * Every recipe against the shelf: ready ones first, then those one bottle
     * short, each group alphabetical. "One short" means the shelf is already
     * part of the way there -- another slot is filled from an open bottle, or
     * the missing one is on the shelf unopened. A recipe nothing on the shelf
     * touches, and two or more short, are left out: that is a shopping list,
     * not tonight.
     */
    fun matches(shelf: List<Candidate>, recipes: List<Recipe> = all): List<Match> {
        val open = shelf.filter { it.isOpen }
        val sealed = shelf.filter { !it.isOpen }
        val ready = mutableListOf<Match>()
        val nearly = mutableListOf<Match>()

        for (recipe in recipes) {
            val picks = LinkedHashMap<Slot, Candidate>()
            val missing = mutableListOf<MissingSlot>()
            for (slot in recipe.slots) {
                val pick = best(slot, open)
                if (pick != null) {
                    picks[slot] = pick
                } else {
                    missing.add(MissingSlot(slot, best(slot, sealed)))
                }
            }
            val match = Match(recipe = recipe, picks = picks, missing = missing)
            if (missing.isEmpty()) {
                ready.add(match)
            } else if (missing.size == 1 && (picks.isNotEmpty() || missing[0].sealed != null)) {
                nearly.add(match)
            }
        }

        val byName = compareBy<Match, String>(String.CASE_INSENSITIVE_ORDER) { it.recipe.name }
        return ready.sortedWith(byName) + nearly.sortedWith(byName)
    }

    /** Highest rated, then fullest, then by name so the choice is stable. */
    internal fun best(slot: Slot, bottles: List<Candidate>): Candidate? =
        bottles
            .filter { slot.accepts(it.classType, it.folded) }
            .sortedWith(
                compareByDescending<Candidate> { it.rating ?: 0 }
                    .thenByDescending { it.fillFraction }
                    .thenBy(String.CASE_INSENSITIVE_ORDER) { it.name }
            )
            .firstOrNull()

    // MARK: - The IBA list

    private fun ml(slot: Slot, milliliters: Double): Ingredient = Ingredient.Bottle(slot, milliliters)
    private fun pantry(text: String): Ingredient = Ingredient.Pantry(text)

    /**
     * IBA official cocktails (iba-world.com), the measures as the IBA gives
     * them. Methods paraphrased to one line.
     */
    val all: List<Recipe> = listOf(
        Recipe(
            "old-fashioned", "Old Fashioned",
            listOf(
                ml(Slot.BOURBON_OR_RYE, 45.0), pantry("1 sugar cube"),
                pantry("a few dashes Angostura bitters"), pantry("a few dashes plain water")
            ),
            "Muddle the sugar with the bitters and water, add the whiskey and ice, stir. " +
                "Orange twist.",
            "old fashioned"
        ),
        Recipe(
            "manhattan", "Manhattan",
            listOf(
                ml(Slot.RYE, 50.0), ml(Slot.SWEET_VERMOUTH, 20.0),
                pantry("1 dash Angostura bitters")
            ),
            "Stir with ice, strain into a chilled glass. Cherry.", "cocktail"
        ),
        Recipe(
            "whiskey-sour", "Whiskey Sour",
            listOf(
                ml(Slot.BOURBON, 45.0), pantry("25 ml lemon juice"),
                pantry("20 ml sugar syrup"), pantry("optional: egg white")
            ),
            "Shake with ice, strain. Cherry and orange slice.", "old fashioned"
        ),
        Recipe(
            "boulevardier", "Boulevardier",
            listOf(ml(Slot.BOURBON, 45.0), ml(Slot.CAMPARI, 30.0), ml(Slot.SWEET_VERMOUTH, 30.0)),
            "Stir with ice, strain over fresh ice. Orange twist.", "old fashioned"
        ),
        Recipe(
            "sazerac", "Sazerac",
            listOf(
                ml(Slot.RYE, 50.0), ml(Slot.ABSINTHE, 10.0), pantry("1 sugar cube"),
                pantry("2 dashes Peychaud's bitters")
            ),
            "Rinse a chilled glass with the absinthe. Stir the rest with ice, strain in. " +
                "Lemon twist. The IBA gives cognac as the base too.",
            "old fashioned"
        ),
        Recipe(
            "mint-julep", "Mint Julep",
            listOf(
                ml(Slot.BOURBON, 60.0), pantry("4 mint sprigs"),
                pantry("1 teaspoon powdered sugar"), pantry("2 teaspoons water")
            ),
            "Muddle mint, sugar and water, add the bourbon and crushed ice, stir until frosted.",
            "julep cup"
        ),
        Recipe(
            "rusty-nail", "Rusty Nail",
            listOf(ml(Slot.SCOTCH, 45.0), ml(Slot.DRAMBUIE, 25.0)),
            "Stir over ice. Lemon twist.", "old fashioned"
        ),
        Recipe(
            "godfather", "Godfather",
            listOf(ml(Slot.SCOTCH, 35.0), ml(Slot.AMARETTO, 35.0)),
            "Build over ice, stir.", "old fashioned"
        ),
        Recipe(
            "penicillin", "Penicillin",
            listOf(
                ml(Slot.SCOTCH, 60.0), ml(Slot.ISLAY_SCOTCH, 7.5),
                pantry("22.5 ml lemon juice"), pantry("22.5 ml honey-ginger syrup")
            ),
            "Shake the blended Scotch, lemon and syrup with ice, strain over ice, float the " +
                "Islay. Candied ginger.",
            "old fashioned"
        ),
        Recipe(
            "irish-coffee", "Irish Coffee",
            listOf(
                ml(Slot.IRISH_WHISKEY, 50.0), pantry("120 ml hot coffee"),
                pantry("50 ml cream"), pantry("1 teaspoon sugar")
            ),
            "Sugar and coffee in a warm glass, add the whiskey, float the cream.",
            "Irish coffee glass"
        ),
        Recipe(
            "negroni", "Negroni",
            listOf(ml(Slot.GIN, 30.0), ml(Slot.CAMPARI, 30.0), ml(Slot.SWEET_VERMOUTH, 30.0)),
            "Build over ice, stir. Orange slice.", "old fashioned"
        ),
        Recipe(
            "dry-martini", "Dry Martini",
            listOf(ml(Slot.GIN, 60.0), ml(Slot.DRY_VERMOUTH, 10.0)),
            "Stir with ice, strain into a chilled glass. Lemon twist or olive.", "cocktail"
        ),
        Recipe(
            "john-collins", "John Collins",
            listOf(
                ml(Slot.GIN, 45.0), pantry("30 ml lemon juice"), pantry("15 ml sugar syrup"),
                pantry("60 ml soda water")
            ),
            "Build over ice in a tall glass, top with soda. Lemon slice and cherry.", "collins"
        ),
        Recipe(
            "french-75", "French 75",
            listOf(
                ml(Slot.GIN, 30.0), pantry("15 ml lemon juice"), pantry("2 dashes sugar syrup"),
                pantry("60 ml Champagne")
            ),
            "Shake gin, lemon and syrup with ice, strain into a flute, top with Champagne.",
            "flute"
        ),
        Recipe(
            "bees-knees", "Bee's Knees",
            listOf(
                ml(Slot.GIN, 52.5), pantry("22.5 ml lemon juice"),
                pantry("22.5 ml honey syrup")
            ),
            "Shake with ice, strain into a chilled glass.", "cocktail"
        ),
        Recipe(
            "bramble", "Bramble",
            listOf(
                ml(Slot.GIN, 40.0), ml(Slot.BLACKBERRY_LIQUEUR, 15.0),
                pantry("15 ml lemon juice"), pantry("10 ml sugar syrup")
            ),
            "Shake gin, lemon and syrup, strain over crushed ice, drizzle the " +
                "crème de mûre.",
            "old fashioned"
        ),
        Recipe(
            "last-word", "Last Word",
            listOf(
                ml(Slot.GIN, 22.5), ml(Slot.GREEN_CHARTREUSE, 22.5), ml(Slot.MARASCHINO, 22.5),
                pantry("22.5 ml lime juice")
            ),
            "Shake with ice, strain into a chilled glass.", "cocktail"
        ),
        Recipe(
            "americano", "Americano",
            listOf(
                ml(Slot.CAMPARI, 30.0), ml(Slot.SWEET_VERMOUTH, 30.0),
                pantry("a splash of soda water")
            ),
            "Build over ice, top with soda. Orange slice and lemon twist.", "highball"
        ),
        Recipe(
            "aperol-spritz", "Aperol Spritz",
            listOf(
                ml(Slot.APEROL, 60.0), pantry("90 ml Prosecco"),
                pantry("a splash of soda water")
            ),
            "Build over ice in a wine glass. Orange slice.", "wine"
        ),
        Recipe(
            "daiquiri", "Daiquiri",
            listOf(
                ml(Slot.WHITE_RUM, 60.0), pantry("20 ml lime juice"),
                pantry("2 bar spoons sugar syrup")
            ),
            "Shake with ice, strain into a chilled glass.", "cocktail"
        ),
        Recipe(
            "mojito", "Mojito",
            listOf(
                ml(Slot.WHITE_RUM, 45.0), pantry("20 ml lime juice"), pantry("6 mint leaves"),
                pantry("2 teaspoons sugar"), pantry("soda water")
            ),
            "Muddle mint with sugar and lime, add rum and crushed ice, top with soda.",
            "highball"
        ),
        Recipe(
            "dark-n-stormy", "Dark 'n' Stormy",
            listOf(ml(Slot.DARK_RUM, 60.0), pantry("100 ml ginger beer")),
            "Build over ice in a tall glass. Lime wedge.", "highball"
        ),
        Recipe(
            "mai-tai", "Mai Tai",
            listOf(
                ml(Slot.AGRICOLE_OR_JAMAICAN_RUM, 30.0), ml(Slot.DARK_RUM, 30.0),
                ml(Slot.ORANGE_LIQUEUR, 15.0), pantry("15 ml orgeat"),
                pantry("30 ml lime juice"), pantry("7.5 ml sugar syrup")
            ),
            "Shake with ice, strain over crushed ice. Mint and lime. The IBA pairs a Jamaican " +
                "rum with a Martinique rhum.",
            "old fashioned"
        ),
        Recipe(
            "margarita", "Margarita",
            listOf(
                ml(Slot.TEQUILA, 50.0), ml(Slot.ORANGE_LIQUEUR, 20.0),
                pantry("15 ml lime juice")
            ),
            "Shake with ice, strain into a salt-rimmed glass.", "margarita"
        ),
        Recipe(
            "tommys-margarita", "Tommy's Margarita",
            listOf(
                ml(Slot.TEQUILA, 45.0), pantry("15 ml lime juice"),
                pantry("2 bar spoons agave nectar")
            ),
            "Shake with ice, strain over fresh ice.", "old fashioned"
        ),
        Recipe(
            "paloma", "Paloma",
            listOf(
                ml(Slot.TEQUILA, 50.0), pantry("5 ml lime juice"), pantry("a pinch of salt"),
                pantry("grapefruit soda to top")
            ),
            "Build over ice in a tall glass, top with grapefruit soda.", "highball"
        ),
        Recipe(
            "sidecar", "Sidecar",
            listOf(
                ml(Slot.COGNAC, 50.0), ml(Slot.ORANGE_LIQUEUR, 20.0),
                pantry("20 ml lemon juice")
            ),
            "Shake with ice, strain into a chilled glass.", "cocktail"
        ),
        Recipe(
            "espresso-martini", "Espresso Martini",
            listOf(
                ml(Slot.VODKA, 50.0), ml(Slot.COFFEE_LIQUEUR, 30.0), pantry("1 shot espresso"),
                pantry("10 ml sugar syrup")
            ),
            "Shake hard with ice, strain into a chilled glass. Three coffee beans.", "cocktail"
        ),
        Recipe(
            "moscow-mule", "Moscow Mule",
            listOf(
                ml(Slot.VODKA, 45.0), pantry("120 ml ginger beer"), pantry("10 ml lime juice")
            ),
            "Build over ice in a copper mug. Lime wedge.", "copper mug"
        )
    )
}
