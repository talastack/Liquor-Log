package com.talastack.liquorlog.data

import app.cash.sqldelight.db.SqlDriver

/**
 * Opening the local database, and the one pragma that is not optional.
 *
 * **SQLite does not enforce foreign keys unless it is told to**, per
 * connection, every time. The default is off for backwards compatibility with
 * software written before 3.6.19, and nothing warns you: a delete simply
 * leaves the children behind. In this schema that means a bottle removed with
 * its pours still pointing at it -- rows that no screen can reach, that no
 * repository will ever load, and that sync keeps pushing forever.
 *
 * GRDB turns it on for the iOS side. This is the same decision, said out loud
 * because on the JVM and on Android it is the caller's to make.
 */
object Database {

    /**
     * Prepares a driver and returns the database on it.
     *
     * The driver is the caller's: a JDBC one in tests, `AndroidSqliteDriver`
     * on a device. Nothing below this line knows which, which is what lets
     * the whole data layer be tested without an emulator.
     */
    fun open(driver: SqlDriver, createSchema: Boolean = true): LiquorDatabase {
        if (createSchema) LiquorDatabase.Schema.create(driver)
        enforceForeignKeys(driver)
        return LiquorDatabase(driver)
    }

    /**
     * Per connection, and after the schema exists.
     *
     * Turning it on mid-transaction is a no-op in SQLite, which is a silent
     * way to end up with it off, so this is deliberately a separate step that
     * runs before any repository is handed the database.
     */
    fun enforceForeignKeys(driver: SqlDriver) {
        driver.execute(identifier = null, sql = "PRAGMA foreign_keys = ON", parameters = 0)
    }
}
