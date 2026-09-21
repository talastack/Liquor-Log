package com.talastack.liquorlog.data

import app.cash.sqldelight.db.QueryResult
import app.cash.sqldelight.db.SqlDriver
import app.cash.sqldelight.db.SqlPreparedStatement

/**
 * Whose rows these are.
 *
 * The app works with no account, so `user_id` is NULL on every row until
 * somebody signs in. At that moment every one of those rows has to be stamped
 * with the new id -- and **in a single transaction**.
 *
 * A partial stamp is the worst failure this codebase has. `user_id` is NOT
 * NULL server-side and RLS matches on `auth.uid() = user_id`, so a row that
 * missed the stamp can never be pushed and, if it somehow were, could never
 * be read back. It would sit in the local database looking perfectly normal,
 * invisible to its owner on every other device, with nothing in the app able
 * to find or repair it.
 *
 * **[evict] is here from the first day, unlike on iOS.** That side shipped
 * without it and the consequence was found by reading rather than by running:
 * nothing reads by `user_id` -- the local database is "this device's
 * collection" -- so a second account signing in on a phone that already held
 * a first one's rows saw them as its own, and any edit to one was pushed
 * carrying the wrong owner, refused by RLS, and retried forever. Android does
 * not get to repeat that.
 *
 * Raw statements rather than named SQLDelight queries, deliberately: the same
 * four statements run against fourteen tables, and fifty-six generated
 * functions would be fifty-six places for one of them to be subtly different.
 * The table list is a constant below and never comes from input.
 */
class AccountLinker(
    private val database: LiquorDatabase,
    private val driver: SqlDriver,
) {

    /**
     * Stamps every unowned row and queues it for push. Returns how many.
     *
     * `updated_at` is deliberately NOT bumped. It is the last-write-wins key
     * and it should say when the human edited the bottle, not when they
     * happened to create an account -- restamping it would make a years-old
     * note win a conflict against a genuinely newer edit from another device.
     *
     * `dirty` IS set, because these rows have never been pushed.
     */
    fun adopt(userId: String): Long = database.transactionWithResult {
        var stamped = 0L
        for (table in TABLES) {
            stamped += driver.execute(
                identifier = null,
                sql = """update "$table" set user_id = ?, dirty = 1 where user_id is null""",
                parameters = 1,
            ) { bindString(0, userId) }.value
        }
        stamped
    }

    /**
     * The reverse of [adopt], after the account was deleted on the server.
     *
     * Rows that were the account's become nobody's again, and dirty, so a new
     * account made later adopts and pushes them exactly like a first sign-in.
     * Rows that were somebody else's -- a household partner's, pulled while
     * that household stood -- are removed: there is no account left that may
     * hold them.
     */
    fun disown(userId: String): Long = database.transactionWithResult {
        var changed = 0L
        for (table in TABLES) {
            changed += driver.execute(
                identifier = null,
                sql = """delete from "$table" where user_id is not null and user_id <> ?""",
                parameters = 1,
            ) { bindString(0, userId) }.value
            changed += driver.execute(
                identifier = null,
                sql = """update "$table" set user_id = null, dirty = 1 where user_id = ?""",
                parameters = 1,
            ) { bindString(0, userId) }.value
        }
        changed
    }

    /**
     * Removes every row owned by an account other than [keeping], for when a
     * DIFFERENT person signs in on a device that already holds a collection.
     *
     * **What this costs, stated plainly.** These rows are not lost: they are
     * on the server under the account that owns them, and that account pulls
     * them again at its next sign-in. What IS lost is a change made under the
     * previous account that never reached the server -- an edit made offline,
     * then signed out of, then a different account signed in. That is a real
     * loss and there is no better terminal state for such a row: it can never
     * be pushed as the new user, and it must not be shown to them.
     *
     * The returned count is of DIRECT deletes only. Pours and tastings cascade
     * from their bottle and SQLite does not count those, so the number is a
     * floor rather than a total.
     */
    fun evict(keeping: String): Long = database.transactionWithResult {
        var removed = 0L
        for (table in TABLES) {
            removed += driver.execute(
                identifier = null,
                sql = """delete from "$table" where user_id is not null and user_id <> ?""",
                parameters = 1,
            ) { bindString(0, keeping) }.value
        }
        removed
    }

    /**
     * Rows owned by some OTHER account.
     *
     * Non-zero means this device is holding a collection that is not the
     * signing-in user's, which is what makes a sign-in a switch rather than a
     * return.
     */
    fun foreignCount(excluding: String): Long =
        count("where user_id is not null and user_id <> ?", parameters = 1) {
            bindString(0, excluding)
        }

    /**
     * Rows that belong to nobody. Zero after a successful [adopt], and a
     * non-zero result afterwards means the stamp did not finish.
     */
    fun unownedCount(): Long = count("where user_id is null", parameters = 0) {}

    private fun count(
        clause: String,
        parameters: Int,
        binders: SqlPreparedStatement.() -> Unit,
    ): Long {
        var total = 0L
        for (table in TABLES) {
            total += driver.executeQuery(
                identifier = null,
                sql = """select count(*) from "$table" $clause""",
                mapper = { cursor ->
                    val value = if (cursor.next().value) cursor.getLong(0) ?: 0L else 0L
                    QueryResult.Value(value)
                },
                parameters = parameters,
                binders = binders,
            ).value
        }
        return total
    }

    companion object {
        /**
         * Every table the client writes. `subscriptions` is absent because it
         * is server-owned: rows arrive by pull already carrying their owner.
         *
         * The same fourteen as the iOS side, in the same order. They are a
         * paired list; a table added to one and not the other is a table
         * whose rows never get adopted on that platform.
         */
        val TABLES: List<String> = listOf(
            "custom_catalog_entries", "bottles", "pours", "fill_readings",
            "blend_additions", "price_reports", "drip_reports", "menus",
            "tastings", "tasting_notes", "wishlist_items", "knowledge_notes",
            "sightings", "visits",
        )
    }
}
