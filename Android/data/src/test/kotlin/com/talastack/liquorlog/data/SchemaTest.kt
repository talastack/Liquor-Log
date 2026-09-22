package com.talastack.liquorlog.data

import app.cash.sqldelight.db.QueryResult
import app.cash.sqldelight.db.SqlDriver
import app.cash.sqldelight.driver.jdbc.sqlite.JdbcSqliteDriver
import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertTrue

/**
 * The local database, proved on a JVM rather than an emulator.
 *
 * `scripts/check_schema_mirror.py` already asserts that this schema names the
 * same tables and columns as Postgres and as GRDB. What it cannot tell you is
 * whether the SQL is VALID -- a mirror check compares names, and a name can be
 * right in a statement SQLite refuses. That is what these do.
 */
class SchemaTest {

    private fun open(): SqlDriver {
        val driver = JdbcSqliteDriver(JdbcSqliteDriver.IN_MEMORY)
        // Throws if a single statement in Schema.sq is not valid SQLite.
        LiquorDatabase.Schema.create(driver)
        return driver
    }

    private fun names(driver: SqlDriver, type: String): List<String> =
        driver.executeQuery(
            identifier = null,
            sql = "select name from sqlite_master where type = ? order by name",
            mapper = { cursor ->
                val found = mutableListOf<String>()
                while (cursor.next().value) {
                    cursor.getString(0)?.let { found.add(it) }
                }
                QueryResult.Value(found)
            },
            parameters = 1,
            binders = { bindString(0, type) },
        ).value

    @Test
    fun `every table the schema declares is created`() {
        val driver = open()
        try {
            val tables = names(driver, "table")
            assertEquals(
                listOf(
                    "blend_additions", "bottles", "custom_catalog_entries",
                    "drip_reports", "fill_readings", "knowledge_notes", "menus",
                    "pours", "price_reports", "sightings", "subscriptions",
                    "tasting_notes", "tastings", "visits", "wishlist_items",
                ),
                tables.filterNot { it.startsWith("sqlite_") },
            )
        } finally {
            driver.close()
        }
    }

    /**
     * The push queue is an index, not a scan. Without it every sync walks
     * every bottle to find the handful that changed.
     */
    @Test
    fun `the indexes the sync and the collection screen rely on exist`() {
        val driver = open()
        try {
            val indexes = names(driver, "index")
            for (expected in listOf(
                "bottles_dirty", "pours_dirty", "tastings_dirty",
                "pours_by_bottle", "tastings_by_bottle", "bottles_by_product",
            )) {
                assertTrue(indexes.contains(expected), "$expected is missing: $indexes")
            }
        } finally {
            driver.close()
        }
    }

    /**
     * `dirty` is local only and every synced table needs one, or that table's
     * changes are never queued for push. The mirror check asserts the same
     * thing against the other two copies of this schema; this asserts it
     * against the database SQLite actually built.
     */
    @Test
    fun `every synced table carries the push queue column`() {
        val driver = open()
        try {
            val synced = listOf(
                "custom_catalog_entries", "bottles", "pours", "fill_readings",
                "blend_additions", "price_reports", "drip_reports", "menus",
                "tastings", "tasting_notes", "wishlist_items", "knowledge_notes",
                "sightings", "visits", "subscriptions",
            )
            for (table in synced) {
                val columns = driver.executeQuery(
                    identifier = null,
                    sql = "select name from pragma_table_info('$table')",
                    mapper = { cursor ->
                        val found = mutableListOf<String>()
                        while (cursor.next().value) {
                            cursor.getString(0)?.let { found.add(it) }
                        }
                        QueryResult.Value(found)
                    },
                    parameters = 0,
                ).value
                assertTrue(columns.contains("dirty"), "$table has no dirty column")
                assertTrue(columns.contains("id"), "$table has no id")
                assertTrue(
                    columns.contains("updated_at"),
                    "$table has no updated_at, which is the last-write-wins key",
                )
                assertTrue(
                    !columns.contains("server_updated_at"),
                    "$table must not keep a device's copy of the server clock",
                )
            }
        } finally {
            driver.close()
        }
    }
}
