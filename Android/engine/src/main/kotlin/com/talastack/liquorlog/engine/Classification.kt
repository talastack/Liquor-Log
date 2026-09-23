package com.talastack.liquorlog.engine

/**
 * The legal classes a bottle can be. The enum name is a storage key, never
 * English -- [ClassType.label] is what a screen prints.
 *
 * `storageKey` is the lowerCamelCase string the Swift engine and the
 * Postgres schema both use. It is written out rather than derived from the
 * enum name so that renaming a case here cannot silently change what is in
 * the database or what the shared catalogue JSON is read against.
 */
enum class ClassType(val storageKey: String) {
    // American whiskey
    BOURBON("bourbon"),
    STRAIGHT_BOURBON("straightBourbon"),
    KENTUCKY_STRAIGHT_BOURBON("kentuckyStraightBourbon"),
    BLEND_OF_STRAIGHT_BOURBON("blendOfStraightBourbon"),
    RYE("rye"),
    STRAIGHT_RYE("straightRye"),
    WHEAT_WHISKEY("wheatWhiskey"),
    STRAIGHT_WHEAT_WHISKEY("straightWheatWhiskey"),
    CORN_WHISKEY("cornWhiskey"),
    STRAIGHT_CORN_WHISKEY("straightCornWhiskey"),
    TENNESSEE_WHISKEY("tennesseeWhiskey"),
    AMERICAN_SINGLE_MALT("americanSingleMalt"),
    LIGHT_WHISKEY("lightWhiskey"),
    BLENDED_WHISKEY("blendedWhiskey"),

    // Scotch
    SINGLE_MALT_SCOTCH("singleMaltScotch"),
    BLENDED_MALT_SCOTCH("blendedMaltScotch"),
    SINGLE_GRAIN_SCOTCH("singleGrainScotch"),
    BLENDED_SCOTCH("blendedScotch"),

    // The rest of the world's whiskey
    IRISH_WHISKEY("irishWhiskey"),
    SINGLE_POT_STILL_IRISH("singlePotStillIrish"),
    SINGLE_MALT_IRISH("singleMaltIrish"),
    CANADIAN_WHISKY("canadianWhisky"),
    JAPANESE_WHISKY("japaneseWhisky"),

    // Agave
    TEQUILA_BLANCO("tequilaBlanco"),
    TEQUILA_REPOSADO("tequilaReposado"),
    TEQUILA_ANEJO("tequilaAnejo"),
    TEQUILA_EXTRA_ANEJO("tequilaExtraAnejo"),
    MEZCAL("mezcal"),

    // Cane
    RUM("rum"),
    RHUM_AGRICOLE("rhumAgricole"),

    // Clear and botanical
    LONDON_DRY_GIN("londonDryGin"),
    DISTILLED_GIN("distilledGin"),
    GENEVER("genever"),
    VODKA("vodka"),
    AQUAVIT("aquavit"),

    // Fruit
    COGNAC("cognac"),
    ARMAGNAC("armagnac"),
    CALVADOS("calvados"),
    BRANDY("brandy"),
    PISCO("pisco"),

    // Sugar-bearing
    LIQUEUR("liqueur"),
    AMARO("amaro"),
    VERMOUTH("vermouth"),
    ABSINTHE("absinthe"),

    // Beer
    MALT_BEVERAGE("maltBeverage"),

    // Cider and seltzer
    //
    // HARD_CIDER IS a defined class: TTB taxes it as a wine made from apples
    // or pears, still or lightly carbonated, under 8.5% ABV. Pear cider --
    // perry -- belongs here too, because the tax class covers it.
    //
    // HARD_SELTZER is NOT. It is a market category with two different bases:
    // some are flavoured malt beverages (Truly, Bud Light Seltzer) and some
    // are fermented from cane sugar with no malt at all (White Claw), which
    // are not even regulated by the same agency. The app keeps them as one
    // class because that is how a person holding the can thinks of them, and
    // does not claim a regulated class for any of them.
    HARD_CIDER("hardCider"),
    HARD_SELTZER("hardSeltzer"),
    ;

    /** A grouping for filters and chips, not a legal concept. */
    enum class Family(val storageKey: String, val label: String) {
        WHISKEY("whiskey", "Whiskey"),
        AGAVE("agave", "Agave"),
        RUM("rum", "Rum"),
        GIN("gin", "Gin"),
        VODKA("vodka", "Vodka"),
        BRANDY("brandy", "Brandy"),
        LIQUEUR("liqueur", "Liqueur"),
        BEER("beer", "Beer"),
        CIDER("cider", "Cider"),
        SELTZER("seltzer", "Seltzer"),
        OTHER("other", "Other"),
    }

    val family: Family
        get() = when (this) {
            BOURBON, STRAIGHT_BOURBON, KENTUCKY_STRAIGHT_BOURBON, BLEND_OF_STRAIGHT_BOURBON,
            RYE, STRAIGHT_RYE, WHEAT_WHISKEY, STRAIGHT_WHEAT_WHISKEY,
            CORN_WHISKEY, STRAIGHT_CORN_WHISKEY, TENNESSEE_WHISKEY, AMERICAN_SINGLE_MALT,
            LIGHT_WHISKEY, BLENDED_WHISKEY,
            SINGLE_MALT_SCOTCH, BLENDED_MALT_SCOTCH, SINGLE_GRAIN_SCOTCH, BLENDED_SCOTCH,
            IRISH_WHISKEY, SINGLE_POT_STILL_IRISH, SINGLE_MALT_IRISH,
            CANADIAN_WHISKY, JAPANESE_WHISKY,
            -> Family.WHISKEY

            TEQUILA_BLANCO, TEQUILA_REPOSADO, TEQUILA_ANEJO, TEQUILA_EXTRA_ANEJO, MEZCAL,
            -> Family.AGAVE

            RUM, RHUM_AGRICOLE -> Family.RUM
            LONDON_DRY_GIN, DISTILLED_GIN, GENEVER -> Family.GIN
            VODKA -> Family.VODKA
            COGNAC, ARMAGNAC, CALVADOS, BRANDY, PISCO -> Family.BRANDY
            LIQUEUR, AMARO, VERMOUTH -> Family.LIQUEUR
            MALT_BEVERAGE -> Family.BEER
            HARD_CIDER -> Family.CIDER
            HARD_SELTZER -> Family.SELTZER
            AQUAVIT, ABSINTHE -> Family.OTHER
        }

    /**
     * "Straight" is a regulated claim, not a marketing word: at least two
     * years in new charred oak, and an age statement if under four.
     */
    val isStraight: Boolean
        get() = when (this) {
            STRAIGHT_BOURBON, KENTUCKY_STRAIGHT_BOURBON, BLEND_OF_STRAIGHT_BOURBON,
            STRAIGHT_RYE, STRAIGHT_WHEAT_WHISKEY, STRAIGHT_CORN_WHISKEY,
            // Tennessee whiskey meets the straight bourbon requirements and
            // then adds the Lincoln County Process. Leaving it out said that a
            // bonded Tennessee whiskey cannot exist, which is contradicted by
            // two on the shelf: Jack Daniel's Bonded and George Dickel
            // Bottled in Bond.
            TENNESSEE_WHISKEY,
            -> true
            else -> false
        }

    /**
     * Minimum bottling strength, where the class has one.
     *
     * Most distilled spirits carry a 40% floor -- US whiskey by the
     * standards of identity, and Scotch, Irish, Canadian and Japanese whisky
     * by their own rules, so the floor is the same wherever the bottle came
     * from. Gin, vodka, rum, brandy and tequila are held to it too.
     *
     * The exceptions are the sugar-bearing classes. A liqueur, an amaro or a
     * vermouth may sit well below 40% by design, and rejecting a 16% amaro as
     * under-strength would be the app being wrong with confidence.
     */
    val minimumBottlingStrength: ABV?
        get() = when (family) {
            // A 5% cider is not under-strength; it is a cider. Asserting a
            // spirits floor here would make the app wrong with confidence.
            Family.LIQUEUR, Family.BEER, Family.CIDER, Family.SELTZER -> null
            Family.WHISKEY, Family.AGAVE, Family.RUM,
            Family.GIN, Family.VODKA, Family.BRANDY,
            -> ABV(percent = 40.0)
            // Aquavit and absinthe are bottled far above any floor in
            // practice, but their minimums vary by origin, so the app does
            // not assert one.
            Family.OTHER -> null
        }

    /** What the UI prints. The storage key is a key, not English. */
    val label: String
        get() = when (this) {
            BOURBON -> "Bourbon Whiskey"
            STRAIGHT_BOURBON -> "Straight Bourbon Whiskey"
            KENTUCKY_STRAIGHT_BOURBON -> "Kentucky Straight Bourbon Whiskey"
            BLEND_OF_STRAIGHT_BOURBON -> "Blend of Straight Bourbon Whiskeys"
            RYE -> "Rye Whiskey"
            STRAIGHT_RYE -> "Straight Rye Whiskey"
            WHEAT_WHISKEY -> "Wheat Whiskey"
            STRAIGHT_WHEAT_WHISKEY -> "Straight Wheat Whiskey"
            CORN_WHISKEY -> "Corn Whiskey"
            STRAIGHT_CORN_WHISKEY -> "Straight Corn Whiskey"
            TENNESSEE_WHISKEY -> "Tennessee Whiskey"
            AMERICAN_SINGLE_MALT -> "American Single Malt Whiskey"
            LIGHT_WHISKEY -> "Light Whiskey"
            BLENDED_WHISKEY -> "Blended Whiskey"
            SINGLE_MALT_SCOTCH -> "Single Malt Scotch Whisky"
            BLENDED_MALT_SCOTCH -> "Blended Malt Scotch Whisky"
            SINGLE_GRAIN_SCOTCH -> "Single Grain Scotch Whisky"
            BLENDED_SCOTCH -> "Blended Scotch Whisky"
            IRISH_WHISKEY -> "Irish Whiskey"
            SINGLE_POT_STILL_IRISH -> "Single Pot Still Irish Whiskey"
            SINGLE_MALT_IRISH -> "Single Malt Irish Whiskey"
            CANADIAN_WHISKY -> "Canadian Whisky"
            JAPANESE_WHISKY -> "Japanese Whisky"
            TEQUILA_BLANCO -> "Tequila Blanco"
            TEQUILA_REPOSADO -> "Tequila Reposado"
            TEQUILA_ANEJO -> "Tequila Añejo"
            TEQUILA_EXTRA_ANEJO -> "Tequila Extra Añejo"
            MEZCAL -> "Mezcal"
            RUM -> "Rum"
            RHUM_AGRICOLE -> "Rhum Agricole"
            LONDON_DRY_GIN -> "London Dry Gin"
            DISTILLED_GIN -> "Distilled Gin"
            GENEVER -> "Genever"
            VODKA -> "Vodka"
            AQUAVIT -> "Aquavit"
            COGNAC -> "Cognac"
            ARMAGNAC -> "Armagnac"
            CALVADOS -> "Calvados"
            BRANDY -> "Brandy"
            PISCO -> "Pisco"
            LIQUEUR -> "Liqueur"
            AMARO -> "Amaro"
            VERMOUTH -> "Vermouth"
            ABSINTHE -> "Absinthe"
            MALT_BEVERAGE -> "Malt Beverage"
            HARD_CIDER -> "Hard Cider"
            HARD_SELTZER -> "Hard Seltzer"
        }

    companion object {
        private val byKey: Map<String, ClassType> by lazy { entries.associateBy { it.storageKey } }

        /** The class a stored key names, or null when nothing does. */
        fun fromStorageKey(key: String): ClassType? = byKey[key]
    }
}

/** How the bottle was selected and combined. Orthogonal to [ClassType]. */
enum class ProductionType(val storageKey: String, val label: String) {
    SINGLE_BARREL("singleBarrel", "Single barrel"),
    SMALL_BATCH("smallBatch", "Small batch"),
    BLEND("blend", "Blend"),
    SINGLE_CASK("singleCask", "Single cask"),
    UNSPECIFIED("unspecified", "Not stated on the label"),
    ;

    companion object {
        private val byKey: Map<String, ProductionType> by lazy { entries.associateBy { it.storageKey } }

        fun fromStorageKey(key: String): ProductionType? = byKey[key]
    }
}

/**
 * Rules that are regulation rather than opinion, so they are checkable
 * rather than arguable.
 *
 * They live here, in compiled code. A remotely-updatable data file is
 * exactly where a bad value could otherwise arrive without review, so the
 * authority stays in the binary.
 */
object Classification {

    data class Issue(val rule: String, val detail: String) {
        override fun toString(): String = "$rule: $detail"
    }

    /** Bottled-in-bond is exactly 100 proof, by definition. */
    val bottledInBondABV = ABV(percent = 50.0)

    /** The floor most distilled spirits share. */
    val americanMinimumABV = ABV(percent = 40.0)

    /** Minimum barrel time for a "straight" designation. */
    const val STRAIGHT_MINIMUM_YEARS = 2

    /** Bonded whiskey must be at least four years old. */
    const val BOTTLED_IN_BOND_MINIMUM_YEARS = 4

    /**
     * A rule that is NOT here: bourbon's 125-proof cap is an *entry* proof --
     * the strength going into the barrel. Whiskey gains strength in a hot
     * warehouse, so barrel-proof bottlings legitimately exceed it; several
     * well-known ones bottle above 70% ABV. Validating bottled ABV against
     * 62.5% would reject real whiskey, so it is deliberately absent.
     */
    fun validate(
        classType: ClassType,
        abv: ABV?,
        statedAgeYears: Int?,
        isBottledInBond: Boolean,
        volumeMilliliters: Double?,
    ): List<Issue> {
        val issues = mutableListOf<Issue>()

        if (abv == null) {
            issues += Issue("abv.missing", "no ABV recorded")
        } else {
            if (!abv.isPlausible) {
                issues += Issue(
                    "abv.plausible",
                    "${abv.percent}% is outside 0.5-95%; likely a decimal slip",
                )
            }
            val floor = classType.minimumBottlingStrength
            if (floor != null && abv < floor) {
                issues += Issue(
                    "abv.americanMinimum",
                    "${classType.storageKey} bottles at no less than ${floor.proof} proof; " +
                        "got ${abv.proof}",
                )
            }
            if (isBottledInBond && abv != bottledInBondABV) {
                issues += Issue(
                    "bond.proof",
                    "bottled in bond is exactly 100 proof; got ${abv.proof}",
                )
            }
        }

        if (statedAgeYears != null) {
            if (classType.isStraight && statedAgeYears < STRAIGHT_MINIMUM_YEARS) {
                issues += Issue(
                    "straight.minimumAge",
                    "straight requires $STRAIGHT_MINIMUM_YEARS years; got $statedAgeYears",
                )
            }
            if (isBottledInBond && statedAgeYears < BOTTLED_IN_BOND_MINIMUM_YEARS) {
                issues += Issue(
                    "bond.minimumAge",
                    "bottled in bond requires $BOTTLED_IN_BOND_MINIMUM_YEARS years; " +
                        "got $statedAgeYears",
                )
            }
        }

        // 27 CFR 5.88 lets any distilled spirit be bonded -- Laird's bottles a
        // bonded apple brandy -- but a bonded whiskey has spent four years in
        // wood, so it is a straight whiskey and is labelled as one.
        if (isBottledInBond && classType.family == ClassType.Family.WHISKEY && !classType.isStraight) {
            issues += Issue(
                "bond.requiresStraight",
                "a bottled in bond whiskey is a straight whiskey; got ${classType.storageKey}",
            )
        }

        if (volumeMilliliters != null && !Volume.isStandardFill(volumeMilliliters)) {
            issues += Issue(
                "volume.standardOfFill",
                "$volumeMilliliters ml is not an authorised standard of fill",
            )
        }

        return issues
    }
}
