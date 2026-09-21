package com.talastack.liquorlog.data

import app.cash.sqldelight.db.QueryResult
import app.cash.sqldelight.db.SqlDriver
import app.cash.sqldelight.driver.jdbc.sqlite.JdbcSqliteDriver
import com.talastack.liquorlog.engine.ClassType
import com.talastack.liquorlog.engine.ProductionType
import kotlin.test.AfterTest
import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertFalse
import kotlin.test.assertNotNull
import kotlin.test.assertNull
import kotlin.test.assertTrue

/**
 * The write paths, exercised against a real database.
 *
 * These exist because of a bug that compiled perfectly and failed at runtime:
 * an insert that left out a NOT NULL column. Nothing static catches that, and
 * nothing catches it on the phone either until somebody taps the button. Every
 * insert and update in the two repositories is executed here at least once.
 */
class RepositoryTest {

    private val driver: SqlDriver = JdbcSqliteDriver(JdbcSqliteDriver.IN_MEMORY)
    private val database = Database.open(driver)
    private val bottles = BottleRepository(database)
    private val tastings = TastingRepository(database)

    @AfterTest
    fun close() = driver.close()

    // Bottles

    @Test
    fun `a bottle added with every field comes back with every field`() {
        val id = bottles.add(
            name = "Elijah Craig Barrel Proof",
            volumeMl = 750.0,
            abv = 62.1,
            classType = ClassType.KENTUCKY_STRAIGHT_BOURBON,
            productionType = ProductionType.SMALL_BATCH,
            isBarrelProof = true,
            distillery = "Heaven Hill",
            batchNumber = "B523",
            isStorePick = true,
            pickStore = "Total Wine",
            barrelNumber = "42-3C",
            purchasePriceCents = 7_999,
            purchaseStore = "Total Wine",
            storageLocation = "Top shelf",
            now = 1_000,
        )

        val summary = assertNotNull(bottles.byId(id))
        assertEquals("Elijah Craig Barrel Proof", summary.name)
        assertEquals(750.0, summary.volumeMl)
        assertEquals(62.1, summary.abv)
        assertTrue(summary.isStorePick)
        assertFalse(summary.isOpen)
        assertEquals("Top shelf", summary.storageLocation)
        // Both facts, in the order the detail screen prints them.
        assertEquals("B523 · Barrel 42-3C", summary.releaseLabel)

        // The custom catalogue entry travels with it, because that is what
        // the collection filter reads a bottle's kind from.
        val entry = assertNotNull(
            summary.bottle.catalog_product_id?.let { bottles.customEntry(it) }
        )
        assertEquals("Heaven Hill", entry.distillery)
        assertEquals(ClassType.KENTUCKY_STRAIGHT_BOURBON.storageKey, entry.class_type)
        assertEquals(ProductionType.SMALL_BATCH.storageKey, entry.production_type)
        assertEquals(1L, entry.is_barrel_proof)
    }

    @Test
    fun `a bottle with no class type gets no catalogue entry`() {
        val id = bottles.add(name = "Something a friend poured", volumeMl = 750.0)
        assertNull(assertNotNull(bottles.byId(id)).bottle.catalog_product_id)
        assertEquals(0, bottles.customEntries().size)
    }

    @Test
    fun `pouring opens the bottle and moves the fill`() {
        val id = bottles.add(name = "Weller 12", volumeMl = 750.0, now = 1_000)
        val sealed = assertNotNull(bottles.byId(id))
        assertFalse(sealed.isOpen)
        assertEquals(17, sealed.status.totalPours)
        assertEquals(17, sealed.status.remainingPours)

        bottles.logPour(id, now = 2_000)
        bottles.logPour(id, now = 3_000)

        val poured = assertNotNull(bottles.byId(id))
        assertTrue(poured.isOpen)
        assertEquals(15, poured.status.remainingPours)
        assertEquals(3_000L, poured.lastPouredAt)
        assertEquals(2, bottles.poursFor(id).size)
    }

    @Test
    fun `undoing a pour puts the whiskey back`() {
        val id = bottles.add(name = "Weller 12", volumeMl = 750.0, now = 1_000)
        val pourId = bottles.logPour(id, now = 2_000)
        assertEquals(16, assertNotNull(bottles.byId(id)).status.remainingPours)

        bottles.deletePour(pourId, now = 3_000)
        assertEquals(17, assertNotNull(bottles.byId(id)).status.remainingPours)
        assertTrue(bottles.poursFor(id).isEmpty())
    }

    @Test
    fun `finishing takes a bottle off the shelf and unfinishing puts it back`() {
        val id = bottles.add(name = "Weller 12", volumeMl = 750.0, now = 1_000)
        assertEquals(1, bottles.onShelf().size)

        bottles.finish(id, now = 2_000)
        assertEquals(0, bottles.onShelf().size)
        // Finished, not gone. The history stays.
        assertEquals(1, bottles.all().size)
        assertTrue(assertNotNull(bottles.byId(id)).isFinished)

        bottles.unfinish(id, now = 3_000)
        assertEquals(1, bottles.onShelf().size)
        assertFalse(assertNotNull(bottles.byId(id)).isFinished)
    }

    @Test
    fun `a removed bottle is gone from every read but still a row`() {
        val id = bottles.add(name = "Typed by mistake", volumeMl = 750.0, now = 1_000)
        bottles.softDelete(id, now = 2_000)

        assertNull(bottles.byId(id))
        assertEquals(0, bottles.all().size)
        assertEquals(0L, bottles.countOnShelf())
        // The tombstone stays so the other devices learn of the deletion.
        // selectAll filters it out, so the row has to be counted directly.
        assertEquals(1, rawCount("select count(*) from bottles"))
    }

    @Test
    fun `editing a bottle edits its catalogue entry too`() {
        val id = bottles.add(
            name = "Mystery rye",
            volumeMl = 750.0,
            classType = ClassType.BOURBON,
            now = 1_000,
        )
        bottles.update(
            id = id,
            name = "Pikesville Rye",
            volumeMl = 700.0,
            abv = 55.0,
            classType = ClassType.STRAIGHT_RYE,
            productionType = ProductionType.SMALL_BATCH,
            distillery = "Heaven Hill",
            now = 2_000,
        )

        val summary = assertNotNull(bottles.byId(id))
        assertEquals("Pikesville Rye", summary.name)
        assertEquals(700.0, summary.volumeMl)

        val entry = assertNotNull(
            summary.bottle.catalog_product_id?.let { bottles.customEntry(it) }
        )
        // The two must not be allowed to disagree about what the bottle is.
        assertEquals(ClassType.STRAIGHT_RYE.storageKey, entry.class_type)
        assertEquals("Heaven Hill", entry.distillery)
    }

    @Test
    fun `an infinity bottle starts open and empty of pours`() {
        val id = bottles.startInfinityBottle(name = "The infinity", volumeMl = 750.0, now = 1_000)
        val summary = assertNotNull(bottles.byId(id))
        assertTrue(summary.isInfinity)
        assertTrue(summary.isOpen)
        assertEquals(0, bottles.poursFor(id).size)
    }

    @Test
    fun `cost per pour comes from what was paid`() {
        val id = bottles.add(
            name = "Weller 12",
            volumeMl = 750.0,
            purchasePriceCents = 3_400,
            now = 1_000,
        )
        // 750 ml is 17 pours; $34.00 over 17 is $2.00.
        assertEquals(200, assertNotNull(bottles.byId(id)).costPerPourCents)
    }

    // Tastings

    @Test
    fun `a tasting keeps its descriptors`() {
        val bottleId = bottles.add(name = "Weller 12", volumeMl = 750.0, now = 1_000)
        val id = tastings.record(
            bottleId = bottleId,
            rating = 8,
            rebuy = TastingRepository.Rebuy.YES,
            liked = "Brown sugar and soft oak",
            descriptors = mapOf(
                TastingRepository.Stage.NOSE to listOf("vanilla", "charredOak"),
                TastingRepository.Stage.FINISH to listOf("blackPepper"),
            ),
            tastedAt = 2_000,
            now = 2_000,
        )

        val detail = assertNotNull(tastings.byId(id))
        assertEquals(8, detail.rating)
        assertEquals(TastingRepository.Rebuy.YES, detail.rebuy)
        assertEquals(listOf("vanilla", "charredOak"), detail.descriptors(TastingRepository.Stage.NOSE))
        assertEquals(listOf("blackPepper"), detail.descriptors(TastingRepository.Stage.FINISH))
        assertTrue(detail.descriptors(TastingRepository.Stage.ENTRY).isEmpty())
    }

    @Test
    fun `a tasting with no bottle is still a tasting`() {
        // A pour at a bar. It has no bottle and never will, and it must not
        // vanish the moment it is saved.
        val id = tastings.record(
            rating = 7,
            source = "At a bar",
            sourceNote = "Jack Rose",
            tastedAt = 1_000,
            now = 1_000,
        )
        val detail = assertNotNull(tastings.byId(id))
        assertNull(detail.bottleId)
        assertEquals("At a bar · Jack Rose", detail.whereLabel)
        assertEquals(1, tastings.allDetails().size)
    }

    @Test
    fun `editing a tasting replaces its picks rather than adding to them`() {
        val id = tastings.record(
            rating = 6,
            descriptors = mapOf(TastingRepository.Stage.NOSE to listOf("vanilla", "caramel")),
            tastedAt = 1_000,
            now = 1_000,
        )
        tastings.update(
            id = id,
            rating = 9,
            descriptors = mapOf(TastingRepository.Stage.NOSE to listOf("charredOak")),
            tastedAt = 1_000,
            now = 2_000,
        )

        val detail = assertNotNull(tastings.byId(id))
        assertEquals(9, detail.rating)
        assertEquals(listOf("charredOak"), detail.descriptors(TastingRepository.Stage.NOSE))
    }

    @Test
    fun `the newest rating is the one a bottle shows`() {
        val bottleId = bottles.add(name = "Weller 12", volumeMl = 750.0, now = 1_000)
        tastings.record(bottleId = bottleId, rating = 6, tastedAt = 2_000, now = 2_000)
        tastings.record(bottleId = bottleId, rating = 9, tastedAt = 3_000, now = 3_000)

        val summary = assertNotNull(bottles.byId(bottleId))
        // An opinion that changed is the newer one; the older stays in the history.
        assertEquals(9, summary.latestRating)
        assertEquals(2, summary.tastingCount)
        assertEquals(2, tastings.forBottle(bottleId).size)
    }

    @Test
    fun `a deleted tasting stops counting`() {
        val bottleId = bottles.add(name = "Weller 12", volumeMl = 750.0, now = 1_000)
        val id = tastings.record(bottleId = bottleId, rating = 9, tastedAt = 2_000, now = 2_000)
        tastings.softDelete(id, now = 3_000)

        assertNull(tastings.byId(id))
        assertEquals(0, tastings.allDetails().size)
        assertNull(assertNotNull(bottles.byId(bottleId)).latestRating)
    }

    /**
     * The whole shelf in a fixed number of queries.
     *
     * Not a timing test -- a count of rows returned, which is what would
     * silently break if a read went back to one query per bottle and started
     * attributing another bottle's pours.
     */
    @Test
    fun `each bottle gets its own pours and its own rating`() {
        val a = bottles.add(name = "Weller 12", volumeMl = 750.0, now = 1_000)
        val b = bottles.add(name = "Elijah Craig", volumeMl = 750.0, now = 1_000)
        bottles.logPour(a, now = 2_000)
        bottles.logPour(a, now = 2_100)
        bottles.logPour(b, now = 2_200)
        tastings.record(bottleId = a, rating = 8, tastedAt = 3_000, now = 3_000)

        val shelf = bottles.onShelf().associateBy { it.name }
        assertEquals(15, assertNotNull(shelf["Weller 12"]).status.remainingPours)
        assertEquals(16, assertNotNull(shelf["Elijah Craig"]).status.remainingPours)
        assertEquals(8, assertNotNull(shelf["Weller 12"]).latestRating)
        assertNull(assertNotNull(shelf["Elijah Craig"]).latestRating)
    }

    /**
     * A count straight off the driver, for the rows the repositories
     * deliberately hide. Every read in [BottleRepository] filters deleted
     * rows, which is exactly what makes a tombstone unverifiable through it.
     */
    private fun rawCount(sql: String): Long =
        driver.executeQuery(
            identifier = null,
            sql = sql,
            mapper = { cursor ->
                cursor.next()
                QueryResult.Value(cursor.getLong(0) ?: 0L)
            },
            parameters = 0,
        ).value
}
