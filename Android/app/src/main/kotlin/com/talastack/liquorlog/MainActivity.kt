package com.talastack.liquorlog

import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Surface
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.compose.ui.unit.dp
import app.cash.sqldelight.db.QueryResult
import app.cash.sqldelight.db.SqlDriver
import app.cash.sqldelight.driver.android.AndroidSqliteDriver
import com.talastack.liquorlog.data.Database
import com.talastack.liquorlog.data.LiquorDatabase
import com.talastack.liquorlog.engine.PourMath
import com.talastack.liquorlog.engine.PourSize

/**
 * The first screen that exists, and it is deliberately a proof rather than a
 * product.
 *
 * Everything below step 1 of the plan is tested without a device: the engine
 * is a JVM library with 526 tests and the data layer is another with its own.
 * What NEITHER can tell you is whether the schema opens on a real Android
 * runtime, whether the pragma that enforces foreign keys survives the
 * Android driver, and whether the engine's java.time use is actually
 * available at minSdk. So this screen answers those three, on the device,
 * and nothing else yet.
 */
class MainActivity : ComponentActivity() {

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)

        val driver: SqlDriver = AndroidSqliteDriver(
            schema = LiquorDatabase.Schema,
            context = this,
            name = "liquorlog.db",
        )
        // The Android driver creates the schema itself, so do not ask
        // Database.open to do it a second time -- but the foreign key pragma
        // is still ours to set, and is still per connection.
        Database.open(driver, createSchema = false)

        val report = Report(
            // android_metadata is the platform's, created by the framework
            // whatever the schema says, and sqlite_* are SQLite's own. Neither
            // is ours, and counting them would report 16 against a schema that
            // declares 15 -- a discrepancy that looks like a bug every time
            // somebody reads this screen.
            tables = count(
                driver,
                """
                select count(*) from sqlite_master
                 where type = 'table'
                   and name <> 'android_metadata'
                   and name not like 'sqlite_%'
                """.trimIndent(),
            ),
            bottles = count(driver, "select count(*) from bottles"),
            foreignKeys = count(driver, "pragma foreign_keys"),
            // A 750 ml bottle gives 17 pours at the standard 1.5 oz. The one
            // number the whole engine is pinned to, computed here rather than
            // hard-coded, so a broken engine dependency is visible instantly.
            poursIn750 = PourMath.status(
                capacityMilliliters = 750.0,
                pouredMilliliters = 0.0,
                pourSize = PourSize.standard,
            ).totalPours,
        )

        setContent { MaterialTheme { Screen(report) } }
    }

    private fun count(driver: SqlDriver, sql: String): Long = driver.executeQuery(
        identifier = null,
        sql = sql,
        mapper = { cursor ->
            cursor.next()
            QueryResult.Value(cursor.getLong(0) ?: -1L)
        },
        parameters = 0,
    ).value
}

private data class Report(
    val tables: Long,
    val bottles: Long,
    val foreignKeys: Long,
    val poursIn750: Int,
)

@Composable
private fun Screen(report: Report) {
    Surface(modifier = Modifier.fillMaxSize(), color = MaterialTheme.colorScheme.background) {
        Column(
            modifier = Modifier
                .fillMaxSize()
                .verticalScroll(rememberScrollState())
                .padding(24.dp),
            verticalArrangement = Arrangement.spacedBy(12.dp),
        ) {
            Text("Liquor Log", style = MaterialTheme.typography.headlineMedium)
            Text(
                "The engine and the database, on the device.",
                style = MaterialTheme.typography.bodyMedium,
                color = MaterialTheme.colorScheme.onSurfaceVariant,
            )

            Line("Tables in the database", "${report.tables}", expected = "15")
            Line("Bottles on the shelf", "${report.bottles}", expected = "0 on a fresh install")
            Line(
                "Foreign keys enforced",
                if (report.foreignKeys == 1L) "yes" else "NO",
                expected = "yes, or a deleted bottle orphans its pours",
            )
            Line(
                "Pours in a 750 ml bottle",
                "${report.poursIn750}",
                expected = "17, the number the engine is pinned to",
            )
        }
    }
}

@Composable
private fun Line(label: String, value: String, expected: String) {
    Column {
        Text("$label: $value", style = MaterialTheme.typography.titleMedium)
        Text(
            expected,
            style = MaterialTheme.typography.bodySmall,
            color = MaterialTheme.colorScheme.onSurfaceVariant,
        )
    }
}
