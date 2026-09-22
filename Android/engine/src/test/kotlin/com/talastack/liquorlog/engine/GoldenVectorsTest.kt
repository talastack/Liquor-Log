package com.talastack.liquorlog.engine

import java.io.File
import kotlinx.serialization.json.Json
import kotlinx.serialization.json.double
import kotlinx.serialization.json.doubleOrNull
import kotlinx.serialization.json.int
import kotlinx.serialization.json.jsonArray
import kotlinx.serialization.json.jsonObject
import kotlinx.serialization.json.jsonPrimitive
import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertTrue

/**
 * The parity test.
 *
 * `shared/vectors/pour-math.json` is read by this suite and by the Swift
 * engine's. Neither implementation owns the truth; the file does. If the
 * rounding rule changes on one platform and not the other, the platform
 * that did not follow fails here.
 *
 * It reads the real file rather than a copy on purpose: a transcribed copy
 * is a second thing to keep in step, which is the problem this is solving.
 */
class GoldenVectorsTest {

    private val vectors by lazy {
        val root = System.getProperty("repoRoot")
            ?: error("repoRoot was not passed; see the test task in build.gradle.kts")
        val file = File(root, "shared/vectors/pour-math.json")
        assertTrue(file.exists(), "the vectors are missing at ${file.path}")
        Json.parseToJsonElement(file.readText()).jsonObject
    }

    @Test
    fun `the pour size matches the one the vectors were computed with`() {
        val expected = vectors.getValue("pourSizeMilliliters").jsonPrimitive.double
        assertEquals(
            expected, PourSize.standard.milliliters, 1e-9,
            "every case below is computed from this constant, so it is checked first",
        )
    }

    @Test
    fun `every golden case holds`() {
        val cases = vectors.getValue("cases").jsonArray
        assertTrue(cases.size >= 16, "the vectors were emptied rather than fixed")

        for (case in cases) {
            val row = case.jsonObject
            fun number(name: String): Double = row.getValue(name).jsonPrimitive.double
            fun whole(name: String): Int = row.getValue(name).jsonPrimitive.int

            // doubleOrNull rather than a content comparison: a JSON null is
            // JsonNull, and this reads it as the absent reading it means.
            val startingFrom = row.getValue("startingFrom").jsonPrimitive.doubleOrNull

            val status = PourMath.status(
                capacityMilliliters = number("capacity"),
                pouredMilliliters = number("poured"),
                startingMilliliters = startingFrom,
            )

            // The reason travels with the case, so a failure says what broke
            // rather than only which numbers disagreed.
            val why = row["_why"]?.jsonPrimitive?.content ?: ""
            val where = "capacity=${number("capacity")} poured=${number("poured")} " +
                "startingFrom=$startingFrom -- $why"

            assertEquals(number("remainingMilliliters"), status.remainingMilliliters, 1e-6, where)
            assertEquals(whole("totalPours"), status.totalPours, where)
            assertEquals(whole("remainingPours"), status.remainingPours, where)
        }
    }
}
