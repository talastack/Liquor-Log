package com.talastack.liquorlog.data

import android.content.Context
import android.util.Log
import com.talastack.liquorlog.engine.Catalog
import com.talastack.liquorlog.engine.CatalogProduct
import com.talastack.liquorlog.engine.ClassType
import com.talastack.liquorlog.engine.FlavorDescriptor
import com.talastack.liquorlog.engine.FlavorFamily
import com.talastack.liquorlog.engine.FlavorOrigin
import com.talastack.liquorlog.engine.FlavorWheel
import com.talastack.liquorlog.engine.ProductionType
import org.json.JSONArray
import org.json.JSONObject

/**
 * The catalogue and the flavour wheel, read off the device at launch.
 *
 * **Why the parsing lives in `:app` and not in `:engine` or `:data`.** The
 * engine is deliberately dependency-free so it can be tested on a bare JVM,
 * and `:data` is the same. `org.json` is part of the Android framework --
 * nothing is added to the app by using it -- but it does not exist off a
 * device. So the two modules that must run on a Linux runner stay clean, and
 * the module that only ever runs on a phone does the decoding. Swift decodes
 * the same two files with `Codable`; the field names both sides read are
 * pinned by [CatalogProduct.storageKeys].
 *
 * Nothing here reaches the network. The files come out of the APK, which is
 * the whole point: a liquor store is a concrete box.
 */
object BundledData {

    private const val TAG = "BundledData"

    const val CATALOG_FILE = "spirits.v1.json"
    const val WHEEL_FILE = "flavor-wheel.v1.json"

    /**
     * The catalogue, or an empty one if it could not be read.
     *
     * An empty catalogue is visible to the user -- the shelf check says so
     * rather than answering "never had it", which would be a wrong answer
     * dressed as a right one.
     */
    fun catalog(context: Context): Catalog {
        val root = readObject(context, CATALOG_FILE) ?: return Catalog(products = emptyList())
        val array = root.optJSONArray("products") ?: return Catalog(products = emptyList())
        val products = ArrayList<CatalogProduct>(array.length())
        for (i in 0 until array.length()) {
            val row = array.optJSONObject(i) ?: continue
            products.add(product(row) ?: continue)
        }
        return Catalog(version = root.optInt("version", 1), products = products)
    }

    /** The flavour wheel, or null if it could not be read. */
    fun flavorWheel(context: Context): FlavorWheel? {
        val root = readObject(context, WHEEL_FILE) ?: return null
        val families = root.optJSONArray("families") ?: return null
        val decoded = ArrayList<FlavorFamily>(families.length())
        for (i in 0 until families.length()) {
            val row = families.optJSONObject(i) ?: continue
            decoded.add(family(row) ?: continue)
        }
        if (decoded.isEmpty()) return null
        return FlavorWheel(
            version = root.optInt("version", 1),
            name = root.optString("name", "Flavour wheel"),
            families = decoded,
        )
    }

    // Decoding

    /**
     * One catalogue row.
     *
     * A row whose class type the engine does not know is dropped rather than
     * defaulted: a bottle filed as bourbon because its real class was
     * unreadable is worse than a bottle that is simply not in the catalogue.
     */
    private fun product(row: JSONObject): CatalogProduct? {
        val id = row.optStringOrNull("id") ?: return null
        val classType = ClassType.fromStorageKey(row.optString("class_type")) ?: return null
        return CatalogProduct(
            id = id,
            distillery = row.optString("distillery"),
            brand = row.optString("brand"),
            expression = row.optString("expression", ""),
            classType = classType,
            productionType = ProductionType.fromStorageKey(row.optString("production_type"))
                ?: ProductionType.UNSPECIFIED,
            isBarrelProof = row.optBoolean("is_barrel_proof", false),
            isBottledInBond = row.optBoolean("is_bottled_in_bond", false),
            abv = row.optDoubleOrNull("abv"),
            statedAgeYears = row.optIntOrNull("stated_age_years"),
            recipeCode = row.optStringOrNull("recipe_code"),
            mashbillKey = row.optStringOrNull("mashbill_key"),
            msrpCents = row.optIntOrNull("msrp_cents"),
            msrpSource = row.optStringOrNull("msrp_source"),
            msrpAsOfYear = row.optIntOrNull("msrp_as_of_year"),
            allocationBottles = row.optIntOrNull("allocation_bottles"),
            allocationEntries = row.optIntOrNull("allocation_entries"),
            allocationSource = row.optStringOrNull("allocation_source"),
            allocationYear = row.optIntOrNull("allocation_year"),
            source = row.optString("source", ""),
            sourceUrl = row.optStringOrNull("source_url"),
            verified = row.optBoolean("verified", false),
        )
    }

    private fun family(row: JSONObject): FlavorFamily? {
        val key = row.optStringOrNull("key") ?: return null
        val array = row.optJSONArray("descriptors") ?: return null
        val descriptors = ArrayList<FlavorDescriptor>(array.length())
        for (i in 0 until array.length()) {
            val entry = array.optJSONObject(i) ?: continue
            descriptors.add(descriptor(entry) ?: continue)
        }
        if (descriptors.isEmpty()) return null
        return FlavorFamily(
            key = key,
            label = row.optString("label", key),
            descriptors = descriptors,
        )
    }

    private fun descriptor(row: JSONObject): FlavorDescriptor? {
        val key = row.optStringOrNull("key") ?: return null
        val origin = FlavorOrigin.fromStorageKey(row.optString("origin")) ?: return null
        return FlavorDescriptor(
            key = key,
            label = row.optString("label", key),
            origin = origin,
            group = row.optStringOrNull("group"),
            compound = row.optStringOrNull("compound"),
            why = row.optStringOrNull("why"),
        )
    }

    // Reading

    private fun readObject(context: Context, name: String): JSONObject? = try {
        val text = context.assets.open(name).bufferedReader().use { it.readText() }
        JSONObject(text)
    } catch (error: Exception) {
        // Logged, never thrown. A missing data file must not stop the app
        // launching -- the shelf and the pours are the person's own records
        // and do not depend on it.
        Log.e(TAG, "could not read " + name, error)
        null
    }

    /** `optString` returns "" for a missing key; this distinguishes the two. */
    private fun JSONObject.optStringOrNull(key: String): String? =
        if (isNull(key)) null else optString(key).takeIf { it.isNotEmpty() }

    private fun JSONObject.optIntOrNull(key: String): Int? =
        if (has(key) && !isNull(key)) optInt(key) else null

    private fun JSONObject.optDoubleOrNull(key: String): Double? =
        if (has(key) && !isNull(key)) optDouble(key).takeIf { !it.isNaN() } else null

    @Suppress("unused")
    private fun JSONArray.strings(): List<String> =
        (0 until length()).mapNotNull { optString(it).takeIf { s -> s.isNotEmpty() } }
}
