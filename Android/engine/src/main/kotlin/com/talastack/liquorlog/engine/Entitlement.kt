package com.talastack.liquorlog.engine

/**
 * The free/Pro split.
 *
 * **Rewritten against the market research.** The first version of this file
 * was written in Phase 0, before any of it, and it got the split backwards in
 * five places: it capped free accounts at 25 bottles, and it charged for CSV
 * export, the oxidation clock, the price check and perceived proof.
 *
 * Every one of those is now free, and the reasons are worth keeping:
 *
 * **Export is never charged for.** *"Never charge for export. It costs you
 * almost nothing and it is the single strongest trust signal in a category
 * where people have been burned."* Paywalling it is cited by name as a reason
 * people abandoned OnlyDrams.
 *
 * **Bottles are unlimited.** The stated threshold for needing this kind of app
 * at all is around fifty bottles, so a 25-bottle cap locked out exactly the
 * people it is for. *"Free unlimited bottles alone beats Whiskey Shelf (about
 * $80/yr for 499 bottles) and Barrelbook (10-bottle free cap)."*
 *
 * **The differentiators are free.** The oxidation clock is a capability
 * essentially no app has, and the barrel fields are the wedge this whole
 * product turns on. Hiding them behind a paywall means nobody ever discovers
 * the reason to switch.
 *
 * **You are never charged for your own data back.** The price check runs on
 * prices the user recorded themselves. Charging to see those is the same move
 * as charging for export, and it reads the same way.
 *
 * What remains chargeable is the list the research calls tolerable: *"multi-
 * device sync and cloud backup, the insurance/estate PDF report, valuation
 * history, and a shareable public menu. These are the things where paying
 * feels like paying for a service rather than for your own data back."*
 *
 * One more constraint from §8: **price does not scale with collection size.**
 * CellarTracker's most engaged users call that "opportunistic", and it
 * punishes exactly the people worth having.
 */
enum class Tier(val storageKey: String) {
    FREE("free"),
    PRO("pro")
}

enum class Feature(val storageKey: String) {
    // Free, permanently, and said so on the store page.

    /**
     * The home tab. Never gated -- it is the reason to open the app, and one
     * that will not say whether you own the bottle in your hand is not worth
     * installing to find out.
     */
    SHELF_CHECK("shelfCheck"),
    BOTTLE_COLLECTION("bottleCollection"),
    POUR_LOGGING("pourLogging"),
    FILL_LEVEL("fillLevel"),
    TASTING_NOTES("tastingNotes"),
    FLAVOR_WHEEL("flavorWheel"),
    WISHLIST("wishlist"),

    /**
     * The barrel fields. THE WEDGE -- gating it would hide the only reason to
     * choose this app over a free incumbent with 56,000 bottles.
     */
    BARREL_DETAIL("barrelDetail"),
    PICK_COMPARE("pickCompare"),

    /**
     * Essentially no app has this. A differentiator nobody can discover is
     * not a differentiator.
     */
    OXIDATION_TRACKING("oxidationTracking"),
    PERCEIVED_PROOF("perceivedProof"),

    /**
     * Runs on prices the user recorded. Charging for it is charging for their
     * own data back.
     */
    PRICE_CHECK("priceCheck"),

    /** Never, ever charged for. */
    CSV_EXPORT("csvExport"),
    LABEL_SCANNING("labelScanning"),
    SHELF_WALK("shelfWalk"),
    PICK_MY_POUR("pickMyPour"),
    COLLECTION_STATS("collectionStats"),

    /** Sharing the text of what is open. The HOSTED version is the paid one. */
    GUEST_MENU("guestMenu"),

    /**
     * Notes the user wrote. Searching your own writing is not a service, and
     * charging for it fails the same test that moved export to free.
     */
    KNOWLEDGE_BASE("knowledgeBase"),

    // Pro -- services, not your own data.

    CLOUD_SYNC("cloudSync"),
    INSURANCE_REPORT("insuranceReport"),

    /** A link somebody else can open, rather than text you paste. */
    HOSTED_MENU("hostedMenu")
}

object Entitlement {

    /**
     * Bottles a free account may hold.
     *
     * **Null. Unlimited, for everybody.** Free is not a differentiator here --
     * OnlyDrams is already free with 56,000 bottles catalogued -- so a cap
     * buys nothing and costs the users who most need the app. You cannot
     * out-free a free incumbent; you can only out-fit it.
     */
    fun bottleLimit(tier: Tier): Int? = when (tier) {
        Tier.FREE, Tier.PRO -> null
    }

    /**
     * Exhaustive, with no `else`. Adding a [Feature] is a compile error until
     * somebody decides which tier it belongs to, rather than silently landing
     * in free -- or worse, silently landing behind the paywall.
     */
    fun isAvailable(feature: Feature, tier: Tier): Boolean = when (tier) {
        Tier.PRO -> true
        Tier.FREE -> when (feature) {
            Feature.SHELF_CHECK,
            Feature.BOTTLE_COLLECTION,
            Feature.POUR_LOGGING,
            Feature.FILL_LEVEL,
            Feature.TASTING_NOTES,
            Feature.FLAVOR_WHEEL,
            Feature.WISHLIST,
            Feature.BARREL_DETAIL,
            Feature.PICK_COMPARE,
            Feature.OXIDATION_TRACKING,
            Feature.PERCEIVED_PROOF,
            Feature.PRICE_CHECK,
            Feature.CSV_EXPORT,
            Feature.LABEL_SCANNING,
            Feature.SHELF_WALK,
            Feature.PICK_MY_POUR,
            Feature.COLLECTION_STATS,
            Feature.GUEST_MENU,
            Feature.KNOWLEDGE_BASE -> true

            Feature.CLOUD_SYNC,
            Feature.INSURANCE_REPORT,
            Feature.HOSTED_MENU -> false
        }
    }

    /**
     * Order the comparison table renders in. A list, so the compiler cannot
     * catch a feature missing from it -- which is exactly how something ends
     * up gated in code and absent from the table. The tests assert it covers
     * every case.
     */
    val displayOrder: List<Feature> = listOf(
        Feature.SHELF_CHECK,
        Feature.BOTTLE_COLLECTION,
        Feature.BARREL_DETAIL,
        Feature.POUR_LOGGING,
        Feature.FILL_LEVEL,
        Feature.OXIDATION_TRACKING,
        Feature.TASTING_NOTES,
        Feature.FLAVOR_WHEEL,
        Feature.PERCEIVED_PROOF,
        Feature.PICK_COMPARE,
        Feature.PRICE_CHECK,
        Feature.WISHLIST,
        Feature.SHELF_WALK,
        Feature.PICK_MY_POUR,
        Feature.COLLECTION_STATS,
        Feature.LABEL_SCANNING,
        Feature.GUEST_MENU,
        Feature.KNOWLEDGE_BASE,
        Feature.CSV_EXPORT,
        Feature.CLOUD_SYNC,
        Feature.INSURANCE_REPORT,
        Feature.HOSTED_MENU
    )

    /**
     * User-facing label, kept beside the tier mapping so the paywall copy and
     * the gate cannot describe different things.
     */
    fun title(feature: Feature): String = when (feature) {
        Feature.SHELF_CHECK -> "Do I already own this?"
        Feature.BOTTLE_COLLECTION -> "Unlimited bottles"
        Feature.BARREL_DETAIL -> "Barrel, batch, rick and pick details"
        Feature.POUR_LOGGING -> "Pour tracking"
        Feature.FILL_LEVEL -> "How much is left"
        Feature.OXIDATION_TRACKING -> "How an open bottle is holding up"
        Feature.TASTING_NOTES -> "Tasting notes"
        Feature.FLAVOR_WHEEL -> "The full flavour wheel"
        Feature.PERCEIVED_PROOF -> "Does it drink its proof"
        Feature.PICK_COMPARE -> "Compare a pick to the standard release"
        Feature.PRICE_CHECK -> "What you have paid before"
        Feature.WISHLIST -> "Wishlist"
        Feature.SHELF_WALK -> "Shelf walk"
        Feature.PICK_MY_POUR -> "Pick my pour"
        Feature.COLLECTION_STATS -> "Your collection at a glance"
        Feature.LABEL_SCANNING -> "Scan a label"
        Feature.GUEST_MENU -> "Share what's open"
        Feature.CSV_EXPORT -> "Export everything, always free"
        Feature.CLOUD_SYNC -> "Sync across your devices"
        Feature.INSURANCE_REPORT -> "Insurance and estate report"
        Feature.HOSTED_MENU -> "A shareable menu link"
        Feature.KNOWLEDGE_BASE -> "Your own notes, searchable"
    }

    /**
     * Why a Pro feature costs money, in one line.
     *
     * Null for free features. Every one of these is a SERVICE with an ongoing
     * cost behind it, which is the test the research sets for what people
     * tolerate paying for.
     */
    fun reason(feature: Feature): String? = when (feature) {
        Feature.CLOUD_SYNC ->
            "Storage and a server, running whether you open the app or not."
        Feature.INSURANCE_REPORT ->
            "A document you can hand to an insurer or an executor."
        Feature.HOSTED_MENU ->
            "A page hosted for you, that guests open without the app."
        else -> null
    }
}
