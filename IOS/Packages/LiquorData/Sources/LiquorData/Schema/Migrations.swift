import Foundation
import GRDB

/// The local SQLite schema.
///
/// **THIS FILE AND `shared/schema/postgres/0001_init.sql` ARE A PAIRED EDIT.**
/// They mirror each other column for column. Nothing at runtime notices when
/// they drift: a column present in one and absent from the other syncs into a
/// void with no error. `scripts/check_schema_mirror.py` catches it and CI runs
/// it on every push.
///
/// The mirror is exact except for two deliberate differences, which the check
/// script knows about:
///
/// - **`dirty` is local only.** A push queue, not state. It never appears in a
///   request body and does not exist server-side.
/// - **`server_updated_at` is server only.** Written by the server on every
///   write and never by a client. The pull cursor comes from the response's
///   `server_time`; a device holding its own copy of the server's clock would
///   have two answers to one question.
public enum Migrations {

    public static func migrator() -> DatabaseMigrator {
        var migrator = DatabaseMigrator()

        #if DEBUG
        // Erasing on a schema change is fine in development and catastrophic in
        // production, so it is compiled out of release builds entirely rather
        // than guarded by a flag somebody could flip.
        migrator.eraseDatabaseOnSchemaChange = true
        #endif

        migrator.registerMigration("0001_init") { db in
            try db.create(table: "custom_catalog_entries") { t in
                t.primaryKey("id", .text).notNull()
                t.column("user_id", .text)
                t.column("distillery", .text).notNull()
                t.column("brand", .text).notNull()
                t.column("expression", .text).notNull().defaults(to: "")
                t.column("class_type", .text).notNull()
                t.column("production_type", .text).notNull().defaults(to: "unspecified")
                t.column("is_barrel_proof", .boolean).notNull().defaults(to: false)
                t.column("is_bottled_in_bond", .boolean).notNull().defaults(to: false)
                t.column("abv", .double)
                t.column("stated_age_years", .integer)
                t.column("recipe_code", .text)
                t.column("msrp_cents", .integer)
                t.column("msrp_source", .text)
                t.column("msrp_as_of_year", .integer)
                t.column("created_at", .integer).notNull()
                t.column("updated_at", .integer).notNull()
                t.column("deleted_at", .integer)
                t.column("dirty", .boolean).notNull().defaults(to: true)
            }

            try db.create(table: "bottles") { t in
                t.primaryKey("id", .text).notNull()
                t.column("user_id", .text)
                t.column("catalog_product_id", .text)
                t.column("category", .text).notNull().defaults(to: "spirit")
                t.column("custom_name", .text)
                t.column("is_store_pick", .boolean).notNull().defaults(to: false)
                t.column("pick_store", .text)
                t.column("pick_name", .text)
                t.column("barrel_number", .text)
                t.column("batch_number", .text)
                t.column("pick_group", .text)
                t.column("warehouse", .text)
                t.column("rick", .text)
                t.column("floor", .text)
                t.column("recipe_code", .text)
                t.column("age_months", .integer)
                t.column("entry_proof", .double)
                t.column("char_level", .integer)
                t.column("finish", .text)
                t.column("bottle_number", .integer)
                t.column("bottles_in_batch", .integer)
                t.column("dumped_at", .integer)
                t.column("abv", .double)
                t.column("chill_filtered", .boolean)
                t.column("distilled_year", .integer)
                t.column("bottled_year", .integer)
                t.column("vintage_year", .integer)
                t.column("volume_ml", .double).notNull()
                t.column("pour_size_ml", .double).notNull().defaults(to: 44.36029434375)
                t.column("purchase_date", .integer)
                t.column("purchase_price_cents", .integer)
                t.column("purchase_store", .text)
                t.column("shelf_price_cents", .integer)
                t.column("barcode", .text)
                t.column("storage_location", .text)
                t.column("shelf_number", .integer)
                t.column("opened_at", .integer)
                t.column("finished_at", .integer)
                t.column("last_verified_at", .integer)
                t.column("created_at", .integer).notNull()
                t.column("updated_at", .integer).notNull()
                t.column("deleted_at", .integer)
                t.column("dirty", .boolean).notNull().defaults(to: true)
            }

            try db.create(table: "pours") { t in
                t.primaryKey("id", .text).notNull()
                t.column("user_id", .text)
                t.column("bottle_id", .text).notNull()
                    .references("bottles", onDelete: .cascade)
                t.column("poured_at", .integer).notNull()
                t.column("volume_ml", .double).notNull()
                t.column("note", .text)
                t.column("created_at", .integer).notNull()
                t.column("updated_at", .integer).notNull()
                t.column("deleted_at", .integer)
                t.column("dirty", .boolean).notNull().defaults(to: true)
            }

            // "There is this much left, and I am looking at it right now."
            //
            // The pour log assumes a bottle started full and that every pour
            // since was logged. Both are routinely false. A reading lets a
            // human overrule that without rewriting the pours: the fill is the
            // latest reading minus the pours logged after it.
            try db.create(table: "fill_readings") { t in
                t.primaryKey("id", .text).notNull()
                t.column("user_id", .text)
                t.column("bottle_id", .text).notNull()
                    .references("bottles", onDelete: .cascade)
                t.column("read_at", .integer).notNull()
                t.column("remaining_ml", .double).notNull()
                t.column("note", .text)
                t.column("created_at", .integer).notNull()
                t.column("updated_at", .integer).notNull()
                t.column("deleted_at", .integer)
                t.column("dirty", .boolean).notNull().defaults(to: true)
            }

            try db.create(table: "tastings") { t in
                t.primaryKey("id", .text).notNull()
                t.column("user_id", .text)
                t.column("bottle_id", .text).references("bottles", onDelete: .cascade)
                t.column("catalog_product_id", .text)
                // Set null, never cascade: deleting a pour must not delete the
                // opinion that came with it.
                t.column("pour_id", .text).references("pours", onDelete: .setNull)
                t.column("tasted_at", .integer).notNull()
                t.column("rating", .integer)
                t.column("would_rebuy", .text)
                t.column("worth_the_price", .boolean)
                t.column("perceived_heat", .integer)
                t.column("finish_seconds", .integer)
                t.column("liked", .text)
                t.column("disliked", .text)
                t.column("created_at", .integer).notNull()
                t.column("updated_at", .integer).notNull()
                t.column("deleted_at", .integer)
                t.column("dirty", .boolean).notNull().defaults(to: true)
            }

            try db.create(table: "tasting_notes") { t in
                t.primaryKey("id", .text).notNull()
                t.column("user_id", .text)
                t.column("tasting_id", .text).notNull()
                    .references("tastings", onDelete: .cascade)
                t.column("stage", .text).notNull()
                t.column("descriptor_key", .text).notNull()
                t.column("intensity", .integer)
                t.column("created_at", .integer).notNull()
                t.column("updated_at", .integer).notNull()
                t.column("deleted_at", .integer)
                t.column("dirty", .boolean).notNull().defaults(to: true)
            }

            try db.create(table: "wishlist_items") { t in
                t.primaryKey("id", .text).notNull()
                t.column("user_id", .text)
                t.column("catalog_product_id", .text)
                t.column("custom_name", .text)
                t.column("target_price_cents", .integer)
                t.column("note", .text)
                t.column("created_at", .integer).notNull()
                t.column("updated_at", .integer).notNull()
                t.column("deleted_at", .integer)
                t.column("dirty", .boolean).notNull().defaults(to: true)
            }

            try db.create(table: "knowledge_notes") { t in
                t.primaryKey("id", .text).notNull()
                t.column("user_id", .text)
                t.column("title", .text).notNull()
                t.column("body", .text).notNull().defaults(to: "")
                t.column("subject_kind", .text)
                t.column("subject_id", .text)
                t.column("created_at", .integer).notNull()
                t.column("updated_at", .integer).notNull()
                t.column("deleted_at", .integer)
                t.column("dirty", .boolean).notNull().defaults(to: true)
            }

            try db.create(table: "subscriptions") { t in
                t.primaryKey("id", .text).notNull()
                t.column("user_id", .text)
                t.column("tier", .text).notNull().defaults(to: "free")
                t.column("expires_at", .integer)
                t.column("created_at", .integer).notNull()
                t.column("updated_at", .integer).notNull()
                t.column("deleted_at", .integer)
                t.column("dirty", .boolean).notNull().defaults(to: false)
            }

            // The reads the app actually makes, plus one per table for the
            // push queue.
            try db.create(index: "pours_by_bottle", on: "pours",
                          columns: ["bottle_id", "poured_at"])
            try db.create(index: "tastings_by_bottle", on: "tastings",
                          columns: ["bottle_id", "tasted_at"])
            try db.create(index: "tastings_by_product", on: "tastings",
                          columns: ["catalog_product_id", "tasted_at"])
            try db.create(index: "tasting_notes_by_tasting", on: "tasting_notes",
                          columns: ["tasting_id"])
            try db.create(index: "bottles_by_product", on: "bottles",
                          columns: ["catalog_product_id"])
            try db.create(index: "bottles_dirty", on: "bottles", columns: ["dirty"])
            try db.create(index: "pours_dirty", on: "pours", columns: ["dirty"])
            try db.create(index: "tastings_dirty", on: "tastings", columns: ["dirty"])
        }

        return migrator
    }
}
