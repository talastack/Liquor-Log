package com.talastack.liquorlog.engine

import java.util.Locale

/**
 * A product in the bundled catalog.
 *
 * Product-level facts only. Batch numbers, barrel numbers, pick stores and
 * measured proof belong on the bottle, because you only ever meet a release
 * through a bottle.
 */
data class CatalogProduct(
    val id: String,
    val distillery: String,
    val brand: String,
    val expression: String = "",
    val classType: ClassType,
    val productionType: ProductionType = ProductionType.UNSPECIFIED,
    val isBarrelProof: Boolean = false,
    val isBottledInBond: Boolean = false,

    /**
     * **Null for a barrel-proof release, and that is correct.** Their strength
     * changes every batch, so a catalog claiming one number would be wrong for
     * almost every bottle on almost every shelf. The user reads it off the
     * label in front of them.
     */
    val abv: Double? = null,

    val statedAgeYears: Int? = null,
    val recipeCode: String? = null,
    /**
     * Groups products that share a grain recipe -- "wheated" and the like --
     * so relatedness can find siblings a name never would.
     */
    val mashbillKey: String? = null,

    /**
     * A published SHELF price, and where it was published.
     *
     * Never a market value. The documented source is a state control board's
     * posted price list -- public records, and the only free and stable price
     * data that exists for spirits. Null is the honest value everywhere else,
     * and it is currently null for EVERY row: no figure has been transcribed
     * from a control board yet, and inventing one is the exact failure mode
     * that discredits apps in this category.
     *
     * The field is plumbed so a cited figure drops in without a schema change.
     */
    val msrpCents: Int? = null,
    val msrpSource: String? = null,
    val msrpAsOfYear: Int? = null,

    /**
     * What a state board published about allocating this release: bottles
     * received and, where it ran a lottery, entries. Null everywhere until
     * somebody imports it. See [Rarity] for why this and not a tier.
     */
    val allocationBottles: Int? = null,
    val allocationEntries: Int? = null,
    val allocationSource: String? = null,
    val allocationYear: Int? = null,

    /** Where the facts came from. A number nobody can check is not data. */
    val source: String = "",
    val sourceUrl: String? = null,
    /** False until the row has been checked against the TTB registry. */
    val verified: Boolean = false
) {

    val identity: ProductIdentity
        get() = ProductIdentity(
            productId = id, distillery = distillery, brand = brand,
            expression = expression, classType = classType, productionType = productionType
        )

    val code: RecipeCode? get() = recipeCode?.let { RecipeCode.parse(it) }

    /**
     * What a board published about allocating this release, when anything was
     * imported. A count with no named source is refused, for the same reason
     * a price with no source is.
     */
    val allocation: Rarity.Allocation?
        get() {
            val bottles = allocationBottles ?: return null
            val named = allocationSource ?: return null
            return Rarity.Allocation(
                bottles = bottles, entries = allocationEntries,
                source = named, year = allocationYear
            )
        }

    /**
     * The shelf-price reference, when there is a cited one.
     *
     * A price with no named source cannot be shown, so it is not returned
     * either -- the same rule the custom catalogue enforces in the database.
     */
    val priceReference: PriceReference?
        get() {
            val cents = msrpCents ?: return null
            val named = msrpSource ?: return null
            return PriceReference(cents = cents, source = named, asOfYear = msrpAsOfYear)
        }

    /**
     * What the strength line should say. Barrel proof has no fixed answer, and
     * saying so is better than showing a number that is wrong most of the time.
     */
    val strengthDescription: String
        get() {
            val percent = abv
                ?: return if (isBarrelProof) "Varies by batch" else "Strength not recorded"
            val proof = ABV(percent).proof
            return String.format(Locale.ROOT, "%.1f%% ABV · %.1f proof", percent, proof)
        }

    companion object {
        /**
         * The column names `shared/data/spirits.v1.json` uses, pinned here so
         * the two engines cannot drift on the file's shape. Swift reads them
         * through CodingKeys; the Android data layer reads them here, because
         * this module carries no JSON dependency.
         */
        val storageKeys: List<String> = listOf(
            "id", "distillery", "brand", "expression", "class_type", "production_type",
            "is_barrel_proof", "is_bottled_in_bond", "abv", "stated_age_years",
            "recipe_code", "mashbill_key", "msrp_cents", "msrp_source", "msrp_as_of_year",
            "allocation_bottles", "allocation_entries", "allocation_source",
            "allocation_year", "source", "source_url", "verified"
        )
    }
}

/**
 * The bundled catalog, as `shared/data/spirits.v1.json` declares it.
 *
 * There is no network call in this path at all -- the whole point is that the
 * shelf check works in a shop with no signal. Swift decodes the file itself;
 * here the data layer parses it and hands the products in.
 */
data class Catalog(val version: Int = 1, val products: List<CatalogProduct>) {

    fun product(id: String): CatalogProduct? = products.firstOrNull { it.id == id }

    fun identity(id: String): ProductIdentity? = product(id)?.identity

    /**
     * Everything the search needs, with the user's own history boosted.
     *
     * [history] is the set of product ids the user has a bottle or a tasting
     * for. The bottle somebody is typing is usually one they have had before.
     */
    fun searchCandidates(history: Set<String> = emptySet()): List<SearchCandidate> =
        products.map { product ->
            SearchCandidate(
                product = product.identity,
                recipeCode = product.code,
                mashbillKey = product.mashbillKey,
                isInYourHistory = product.id in history
            )
        }

    /**
     * Products sharing this one's line, distillery, recipe code or grain
     * recipe. Structural rather than textual: string similarity would never
     * connect Weller to Eagle Rare.
     */
    fun related(id: String, limit: Int = 10): List<SearchHit> {
        val anchor = product(id) ?: return emptyList()
        return BottleSearch.related(
            product = anchor.identity,
            recipeCode = anchor.code,
            candidates = searchCandidates(),
            limit = limit
        )
    }

    data class Issue(val rule: String, val detail: String) {
        override fun toString(): String = "$rule: $detail"
    }

    /**
     * Structural checks the app can run on whatever catalog it was handed,
     * including one fetched later. `scripts/check_catalog.py` runs the same
     * rules in CI against the shipped file.
     */
    fun validate(): List<Issue> {
        val issues = mutableListOf<Issue>()
        val seen = mutableSetOf<String>()

        for (product in products) {
            if (!seen.add(product.id)) {
                issues.add(Issue(rule = "product.unique", detail = product.id))
            }
            if (product.source.isEmpty()) {
                issues.add(
                    Issue(
                        rule = "product.hasSource",
                        detail = "${product.id} cites nothing; a number nobody can check is not data"
                    )
                )
            }
            if (product.isBarrelProof && product.abv != null) {
                issues.add(
                    Issue(
                        rule = "product.barrelProofHasNoFixedABV",
                        detail = "${product.id} claims one strength for a release that changes " +
                            "every batch"
                    )
                )
            }
            val code = product.recipeCode
            if (code != null && RecipeCode.parse(code) == null) {
                issues.add(Issue(rule = "product.recipeCode", detail = "${product.id}: $code"))
            }
            // A barrel-proof row is SUPPOSED to carry no ABV, so the engine's
            // abv.missing rule is not a fault here -- it is the correct value.
            val classIssues = Classification.validate(
                classType = product.classType,
                abv = product.abv?.let { ABV(it) },
                statedAgeYears = product.statedAgeYears,
                isBottledInBond = product.isBottledInBond,
                volumeMilliliters = null
            ).filter { !(product.isBarrelProof && it.rule == "abv.missing") }

            issues.addAll(
                classIssues.map { Issue(rule = it.rule, detail = "${product.id}: ${it.detail}") }
            )
        }
        return issues
    }

    companion object {
        val empty = Catalog(products = emptyList())
    }
}
