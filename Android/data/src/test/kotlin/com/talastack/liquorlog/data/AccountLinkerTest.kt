package com.talastack.liquorlog.data

import app.cash.sqldelight.db.QueryResult
import app.cash.sqldelight.db.SqlDriver
import app.cash.sqldelight.driver.jdbc.sqlite.JdbcSqliteDriver
import kotlin.test.AfterTest
import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertTrue

/**
 * Two people, one phone -- proved before Android ever ships it, because iOS
 * shipped the other way round and the bug was found by reading the code
 * rather than by anything failing.
 */
class AccountLinkerTest {

    private val driver: SqlDriver = JdbcSqliteDriver(JdbcSqliteDriver.IN_MEMORY)
    private val database = Database.open(driver)
    private val linker = AccountLinker(database, driver)

    @AfterTest
    fun close() = driver.close()

    /**
     * A bottle already stamped for [owner], as a pull would have left it.
     *
     * Every NOT NULL column without a default has to be here. The schema is
     * generated from the one GRDB uses, so this list is not a guess: id,
     * volume_ml, created_at, updated_at.
     */
    private fun bottle(name: String, owner: String?) {
        driver.execute(
            identifier = null,
            sql = """
                insert into bottles
                    (id, user_id, custom_name, volume_ml, created_at, updated_at, dirty)
                values (?, ?, ?, 750, 0, 0, 0)
            """.trimIndent(),
            parameters = 3,
        ) {
            bindString(0, name)
            bindString(1, owner)
            bindString(2, name)
        }
    }

    private fun pour(id: String, bottleId: String, owner: String?) {
        driver.execute(
            identifier = null,
            sql = """
                insert into pours
                    (id, user_id, bottle_id, poured_at, volume_ml, created_at, updated_at, dirty)
                values (?, ?, ?, 0, 44, 0, 0, 0)
            """.trimIndent(),
            parameters = 3,
        ) {
            bindString(0, id)
            bindString(1, owner)
            bindString(2, bottleId)
        }
    }

    private fun names(): List<String> = driver.executeQuery(
        identifier = null,
        sql = "select custom_name from bottles order by custom_name",
        mapper = { cursor ->
            val found = mutableListOf<String>()
            while (cursor.next().value) {
                cursor.getString(0)?.let { found.add(it) }
            }
            QueryResult.Value(found)
        },
        parameters = 0,
    ).value

    private fun count(table: String): Long = driver.executeQuery(
        identifier = null,
        sql = "select count(*) from $table",
        mapper = { cursor ->
            cursor.next()
            QueryResult.Value(cursor.getLong(0) ?: 0L)
        },
        parameters = 0,
    ).value

    @Test
    fun `an unowned collection is adopted whole`() {
        bottle("Mine", owner = null)
        bottle("Also mine", owner = null)

        assertEquals(2L, linker.adopt("user-b"))
        assertEquals(0L, linker.unownedCount(), "one unstamped row can never be pushed")
    }

    @Test
    fun `foreign count sees only other accounts rows`() {
        bottle("Mine", owner = "user-b")
        bottle("Theirs", owner = "user-a")
        bottle("Nobodys", owner = null)

        assertEquals(1L, linker.foreignCount(excluding = "user-b"))
        assertEquals(
            1L, linker.foreignCount(excluding = "user-a"),
            "it is symmetric: whoever is asking, the other one's row is foreign",
        )
    }

    /**
     * An unowned row is the local-only collection the signing-in account is
     * about to adopt. It must survive.
     */
    @Test
    fun `evict removes the other account and nothing else`() {
        bottle("Mine", owner = "user-b")
        bottle("Theirs", owner = "user-a")
        bottle("Nobodys", owner = null)

        assertEquals(1L, linker.evict(keeping = "user-b"))
        assertEquals(listOf("Mine", "Nobodys"), names())
    }

    /** The whole sequence a sign-in performs, in order. */
    @Test
    fun `a second account inherits only the unowned collection`() {
        bottle("Theirs", owner = "user-a")
        bottle("Nobodys", owner = null)

        linker.evict(keeping = "user-b")
        linker.adopt("user-b")

        assertEquals(listOf("Nobodys"), names())
        assertEquals(0L, linker.unownedCount())
        assertEquals(
            0L, linker.foreignCount(excluding = "user-b"),
            "the first account's bottle is not quietly re-owned by the second",
        )
    }

    /**
     * Foreign keys are off in SQLite unless the connection turns them on, and
     * nothing warns you. A pour left pointing at a deleted bottle is a row no
     * screen can reach and sync pushes forever.
     */
    @Test
    fun `evicting a bottle takes its pours with it`() {
        bottle("Theirs", owner = "user-a")
        pour("p1", bottleId = "Theirs", owner = "user-a")

        linker.evict(keeping = "user-b")

        assertEquals(0L, count("bottles"))
        assertEquals(0L, count("pours"), "the cascade did not run: foreign keys are off")
    }

    @Test
    fun `disown hands the rows back to nobody and drops everyone elses`() {
        bottle("Mine", owner = "user-a")
        bottle("Theirs", owner = "user-b")

        linker.disown("user-a")

        assertEquals(listOf("Mine"), names())
        assertEquals(1L, linker.unownedCount(), "mine are nobody's again, ready to re-adopt")
    }

    /**
     * The fourteen tables are a paired list with the iOS side. A table on one
     * list and not the other is a table whose rows never get adopted on that
     * platform -- and those rows can never be pushed or read back.
     */
    @Test
    fun `the linker covers every table the client writes`() {
        assertEquals(14, AccountLinker.TABLES.size)
        assertTrue(
            "subscriptions" !in AccountLinker.TABLES,
            "subscriptions is server-owned; its rows arrive already carrying their owner",
        )
        // Every named table must actually exist, or the statements are silently
        // running against nothing.
        for (table in AccountLinker.TABLES) {
            count(table)
        }
    }
}
