package com.talastack.liquorlog.data

import app.cash.sqldelight.db.QueryResult
import app.cash.sqldelight.db.SqlDriver
import app.cash.sqldelight.driver.jdbc.sqlite.JdbcSqliteDriver
import com.talastack.liquorlog.engine.ClassType
import com.talastack.liquorlog.engine.ABV
import com.talastack.liquorlog.engine.CollectionImport
import com.talastack.liquorlog.engine.Hunt
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
    private val wishlist = WishlistRepository(database)
    private val sightings = SightingRepository(database)
    private val people = PeopleLedger(database)

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
    fun `a bottle matched to the catalogue carries the catalogue id`() {
        val id = bottles.add(
            name = "W L Weller 12 Year",
            volumeMl = 750.0,
            catalogProductId = "weller-12",
            classType = ClassType.KENTUCKY_STRAIGHT_BOURBON,
            now = 1_000,
        )

        val summary = assertNotNull(bottles.byId(id))
        // The catalogue's id, verbatim. Anything else and the shelf check
        // tells somebody in the aisle "never had it" about a bottle on
        // their own shelf.
        assertEquals("weller-12", summary.bottle.catalog_product_id)
        // And no custom entry beside it: the catalogue already answers all
        // of this, and two answers is how they come to disagree.
        assertTrue(bottles.customEntries().isEmpty())
    }

    @Test
    fun `editing a catalogue bottle does not rewrite the catalogue`() {
        val id = bottles.add(
            name = "W L Weller 12 Year",
            volumeMl = 750.0,
            catalogProductId = "weller-12",
            classType = ClassType.KENTUCKY_STRAIGHT_BOURBON,
            now = 1_000,
        )
        bottles.update(
            id = id,
            name = "W L Weller 12 Year",
            volumeMl = 750.0,
            classType = ClassType.STRAIGHT_RYE,
            storageLocation = "Top shelf",
            now = 2_000,
        )

        val summary = assertNotNull(bottles.byId(id))
        assertEquals("Top shelf", summary.storageLocation)
        assertEquals("weller-12", summary.bottle.catalog_product_id)
        // The bundled catalogue is not this app's to rewrite, so an edit
        // must not have invented a row shadowing it.
        assertTrue(bottles.customEntries().isEmpty())
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

    // Import

    /**
     * Somebody else's spreadsheet, end to end.
     *
     * The engine's own tests cover the column guessing. This covers the half
     * the screen owns: that a planned row becomes a bottle with the right
     * fields, and that the defaults it has to invent are the harmless ones.
     */
    @Test
    fun `a planned row becomes a bottle`() {
        val csv = listOf(
            "Whiskey,Proof,Size,Cost,Bought at,Batch,Status,Sample",
            "Elijah Craig Barrel Proof,124.2,750,79.99,Total Wine,B523,open,",
            "Weller 12,90,,34.99,,,,Mike",
            // Values but no name: cannot be imported, and must be reported.
            ",100,750,19.99,,,,",
            // Wholly blank: not a row at all. Our own export writes CRLF, and
            // a reader that did not drop these would see one of them between
            // every bottle.
            ",,,,,,,",
        ).joinToString("\n")

        val plan = CollectionImport.plan(csv)
        assertEquals(2, plan.rows.size)
        // One skipped, not two: the blank line was never a record.
        assertEquals(1, plan.skippedLines.size)

        for (row in plan.rows) {
            bottles.add(
                name = row.name,
                volumeMl = row.volumeMilliliters ?: 750.0,
                abv = row.proof?.let { ABV.fromProof(it).percent },
                batchNumber = row.batch,
                purchasePriceCents = row.paidCents?.toLong(),
                purchaseStore = row.store,
                isSample = row.isSample,
                sampleFrom = row.sampleFrom,
                openNow = row.isOpen,
                now = 1_000,
            )
        }

        val shelf = bottles.all().associateBy { it.name }
        val ec = assertNotNull(shelf["Elijah Craig Barrel Proof"])
        assertEquals(750.0, ec.volumeMl)
        assertEquals(62.1, ec.abv)
        assertEquals(7_999L, ec.purchasePriceCents)
        assertEquals("Total Wine", ec.bottle.purchase_store)
        assertEquals("B523", ec.bottle.batch_number)
        assertTrue(ec.isOpen)

        val weller = assertNotNull(shelf["Weller 12"])
        // The file gave no size. 750 is the default, because every pour count
        // in the app derives from it and it cannot be left absent.
        assertEquals(750.0, weller.volumeMl)
        assertEquals(45.0, weller.abv)
        // "Mike" in the sample column is a sample FROM Mike, not the word yes.
        assertTrue(weller.isSample)
        assertEquals("Mike", weller.bottle.sample_from)
        assertFalse(weller.isOpen)
    }

    @Test
    fun `a file with no name column imports nothing`() {
        val csv = "Proof,Size\n124.2,750"
        val plan = CollectionImport.plan(csv)
        // Every line skipped rather than a name invented from the first column.
        assertTrue(plan.rows.isEmpty())
        assertEquals(listOf(2), plan.skippedLines)
    }

    // People

    @Test
    fun `the ledger is read from bottles and pours, not kept`() {
        val gift = bottles.add(
            name = "Weller 12", volumeMl = 50.0,
            isSample = true, sampleFrom = "Mike", now = 1_000,
        )
        tastings.record(bottleId = gift, rating = 9, tastedAt = 1_500, now = 1_500)

        val mine = bottles.add(name = "Elijah Craig", volumeMl = 750.0, now = 2_000)
        bottles.logPour(mine, milliliters = 60.0, givenTo = "Mike", now = 3_000)
        bottles.logPour(mine, milliliters = 44.0, now = 3_500)

        val ledger = people.ledger()
        assertEquals(1, ledger.size)
        val mike = ledger[0]
        assertEquals("Mike", mike.name)
        // One sample in, one pour out. The pour with no recipient is not an
        // exchange and must not appear.
        assertEquals(1, mike.received.size)
        assertEquals(1, mike.given.size)
        assertEquals(50.0, mike.receivedMilliliters)
        assertEquals(60.0, mike.givenMilliliters)
    }

    @Test
    fun `two spellings of a name are one person`() {
        val a = bottles.add(
            name = "Weller 12", volumeMl = 50.0,
            isSample = true, sampleFrom = "Mike", now = 1_000,
        )
        val mine = bottles.add(name = "Elijah Craig", volumeMl = 750.0, now = 2_000)
        bottles.logPour(mine, milliliters = 60.0, givenTo = "mike ", now = 3_000)

        val ledger = people.ledger()
        // The engine folds on a trimmed, lowercased key, so one person.
        assertEquals(1, ledger.size)
        assertEquals(1, ledger[0].received.size)
        assertEquals(1, ledger[0].given.size)
    }

    @Test
    fun `a sample with nobody named is nobody's`() {
        bottles.add(
            name = "Weller 12", volumeMl = 50.0,
            isSample = true, sampleFrom = "   ", now = 1_000,
        )
        assertTrue(people.ledger().isEmpty())
    }

    @Test
    fun `the ledger names bottles the way the screen does`() {
        val mine = bottles.add(name = "Typed name", volumeMl = 750.0, now = 1_000)
        bottles.logPour(mine, milliliters = 60.0, givenTo = "Mike", now = 2_000)

        val named = people.ledger(mapOf(mine to "W L Weller 12 Year"))
        assertEquals("W L Weller 12 Year", named[0].given[0].bottle)
        // Without the map it falls back to what was typed rather than to an id.
        assertEquals("Typed name", people.ledger()[0].given[0].bottle)
    }

    // The hunt log

    @Test
    fun `a sighting and a lottery entry live in the same log`() {
        sightings.record(
            customName = "Weller 12", store = "Total Wine",
            cents = 3_500, count = 2, seenAt = 1_000, now = 1_000,
        )
        val lottery = sightings.record(
            customName = "Blanton's", store = "Virginia ABC",
            kind = Hunt.Kind.ENTERED, seenAt = 2_000, now = 2_000,
        )

        val all = sightings.all()
        assertEquals(2, all.size)
        // Newest first.
        assertEquals(Hunt.Kind.ENTERED, all[0].kind)
        assertEquals(Hunt.Kind.SEEN, all[1].kind)
        assertNull(assertNotNull(sightings.byId(lottery)).outcome)
    }

    @Test
    fun `a lottery result can arrive later`() {
        val id = sightings.record(
            customName = "Blanton's", store = "Virginia ABC",
            kind = Hunt.Kind.ENTERED, seenAt = 1_000, now = 1_000,
        )
        sightings.setOutcome(id, Hunt.Outcome.WON, now = 2_000)
        assertEquals(Hunt.Outcome.WON, assertNotNull(sightings.byId(id)).outcome)

        // And can go back to unknown, for a result entered by mistake.
        sightings.setOutcome(id, null, now = 3_000)
        assertNull(assertNotNull(sightings.byId(id)).outcome)
    }

    @Test
    fun `the engine reads the log this repository writes`() {
        sightings.record(customName = "Weller 12", store = "Total Wine", seenAt = 1_000, now = 1_000)
        sightings.record(customName = "Weller 12", store = "total wine ", seenAt = 2_000, now = 2_000)
        sightings.record(customName = "Blanton's", store = "Virginia ABC", seenAt = 3_000, now = 3_000)
        sightings.record(
            customName = "Pappy", store = "Virginia ABC",
            kind = Hunt.Kind.ENTERED, outcome = Hunt.Outcome.LOST,
            seenAt = 4_000, now = 4_000,
        )

        val summary = Hunt.summarise(sightings.huntSightings())
        assertEquals(3, summary.seen)
        // "Total Wine" and "total wine " are one store, which is the engine's
        // rule and the reason the raw string is stored rather than a key.
        assertEquals(2, summary.stores.size)
        assertEquals(1, summary.lotteries.entered)
        assertEquals(1, summary.lotteries.lost)
        assertNotNull(summary.headline)
    }

    @Test
    fun `a removed sighting leaves the log and leaves a tombstone`() {
        val id = sightings.record(customName = "Weller 12", store = "Total Wine", now = 1_000)
        sightings.remove(id, now = 2_000)

        assertNull(sightings.byId(id))
        assertTrue(sightings.all().isEmpty())
        assertEquals(1, rawCount("select count(*) from sightings"))
    }

    @Test
    fun `a visit is a date and a place`() {
        sightings.recordVisit(
            distillery = "Buffalo Trace",
            note = "Hard hat tour",
            visitedAt = 1_000,
            now = 1_000,
        )
        val visits = sightings.visits()
        assertEquals(1, visits.size)
        assertEquals("Buffalo Trace", visits[0].distillery)
        assertEquals("Hard hat tour", visits[0].note)
    }

    // Infinity bottles

    @Test
    fun `an infinity bottle starts empty and fills from what goes in`() {
        val blend = bottles.startInfinityBottle(name = "The infinity", volumeMl = 750.0, now = 1_000)
        // Empty, not full: the whole point is that what is in it arrived
        // from somewhere else.
        assertEquals(0.0, assertNotNull(bottles.byId(blend)).status.remainingMilliliters)

        val source = bottles.add(name = "Weller 12", volumeMl = 750.0, abv = 45.0, now = 1_000)
        bottles.addToBlend(blend, milliliters = 100.0, sourceBottleId = source, now = 2_000)

        assertEquals(100.0, assertNotNull(bottles.byId(blend)).status.remainingMilliliters)
    }

    @Test
    fun `whiskey that leaves one bottle arrives in the other`() {
        val blend = bottles.startInfinityBottle(name = "The infinity", volumeMl = 750.0, now = 1_000)
        val source = bottles.add(name = "Weller 12", volumeMl = 750.0, abv = 45.0, now = 1_000)

        bottles.addToBlend(blend, milliliters = 100.0, sourceBottleId = source, now = 2_000)

        // Off the source as a real pour...
        assertEquals(650.0, assertNotNull(bottles.byId(source)).status.remainingMilliliters)
        assertEquals(1, bottles.poursFor(source).size)
        // ...and on to the blend as an addition. A half-written version of
        // this is a volume nothing in the app could explain.
        assertEquals(100.0, assertNotNull(bottles.byId(blend)).status.remainingMilliliters)
        assertEquals(1, bottles.additionsFor(blend).size)
    }

    @Test
    fun `undoing a blend pour takes it out of the blend as well`() {
        // The other half of "whiskey that leaves one bottle arrives in the
        // other". Undo used to put the liquid back in the source and leave
        // it in the blend, so the two disagreed for good: a blend has no
        // capacity to check itself against, so nothing would ever notice.
        val blend = bottles.startInfinityBottle(name = "The infinity", volumeMl = 750.0, now = 1_000)
        val source = bottles.add(name = "Weller 12", volumeMl = 750.0, abv = 45.0, now = 1_000)
        bottles.addToBlend(blend, milliliters = 100.0, sourceBottleId = source, now = 2_000)

        val pour = bottles.poursFor(source).single()
        // The pour knows where it went, which is what makes the undo
        // possible and what tells the screen it was not an ordinary pour.
        assertEquals(blend, pour.into_bottle_id)

        bottles.deletePour(pour.id, now = 3_000)

        assertEquals(750.0, assertNotNull(bottles.byId(source)).status.remainingMilliliters)
        assertEquals(0.0, assertNotNull(bottles.byId(blend)).status.remainingMilliliters)
        assertEquals(0, bottles.additionsFor(blend).size)
    }

    @Test
    fun `undoing an ordinary pour leaves every blend alone`() {
        val blend = bottles.startInfinityBottle(name = "The infinity", volumeMl = 750.0, now = 1_000)
        val source = bottles.add(name = "Weller 12", volumeMl = 750.0, abv = 45.0, now = 1_000)
        bottles.addToBlend(blend, milliliters = 100.0, sourceBottleId = source, now = 2_000)
        val drunk = bottles.logPour(source, milliliters = 50.0, now = 3_000)

        bottles.deletePour(drunk, now = 4_000)

        // The blend keeps what it was given; only the drink goes back.
        assertEquals(100.0, assertNotNull(bottles.byId(blend)).status.remainingMilliliters)
        assertEquals(1, bottles.additionsFor(blend).size)
        assertEquals(650.0, assertNotNull(bottles.byId(source)).status.remainingMilliliters)
    }

    @Test
    fun `something poured in from outside the collection still counts`() {
        val blend = bottles.startInfinityBottle(name = "The infinity", volumeMl = 750.0, now = 1_000)
        bottles.addToBlend(
            blend,
            milliliters = 60.0,
            sourceName = "A sample from Mike",
            abv = 62.1,
            now = 2_000,
        )

        assertEquals(60.0, assertNotNull(bottles.byId(blend)).status.remainingMilliliters)
        val addition = bottles.additionsFor(blend).single()
        assertNull(addition.source_bottle_id)
        assertNull(addition.pour_id)
        assertEquals("A sample from Mike", addition.source_name)
        assertEquals(62.1, addition.abv)
    }

    @Test
    fun `pouring from an infinity bottle takes it back down`() {
        val blend = bottles.startInfinityBottle(name = "The infinity", volumeMl = 750.0, now = 1_000)
        bottles.addToBlend(blend, milliliters = 200.0, sourceName = "Something", now = 2_000)
        bottles.logPour(blend, milliliters = 50.0, now = 3_000)

        assertEquals(150.0, assertNotNull(bottles.byId(blend)).status.remainingMilliliters)
    }

    @Test
    fun `a reading of an infinity bottle counts only what came after it`() {
        val blend = bottles.startInfinityBottle(name = "The infinity", volumeMl = 750.0, now = 1_000)
        bottles.addToBlend(blend, milliliters = 300.0, sourceName = "Early", now = 2_000)

        // Somebody looks at it: there is really 250 in there.
        bottles.setLevel(blend, remainingMilliliters = 250.0, now = 3_000)
        assertEquals(250.0, assertNotNull(bottles.byId(blend)).status.remainingMilliliters)

        // A later addition counts on top of the reading; the earlier one is
        // already accounted for by the person who looked.
        bottles.addToBlend(blend, milliliters = 100.0, sourceName = "Later", now = 4_000)
        assertEquals(350.0, assertNotNull(bottles.byId(blend)).status.remainingMilliliters)
    }

    @Test
    fun `the blend keeps the name of a source that later goes away`() {
        val blend = bottles.startInfinityBottle(name = "The infinity", volumeMl = 750.0, now = 1_000)
        val source = bottles.add(name = "Weller 12", volumeMl = 750.0, abv = 45.0, now = 1_000)
        bottles.addToBlend(blend, milliliters = 100.0, sourceBottleId = source, now = 2_000)

        bottles.softDelete(source, now = 3_000)

        // The bottle is gone from the shelf; what went into the blend is not.
        assertNull(bottles.byId(source))
        val addition = bottles.additionsFor(blend).single()
        assertEquals("Weller 12", addition.source_name)
        assertEquals(45.0, addition.abv)
        assertEquals(100.0, assertNotNull(bottles.byId(blend)).status.remainingMilliliters)
    }

    // Fill readings

    @Test
    fun `a reading rebases the fill and earlier pours stop counting`() {
        val id = bottles.add(name = "Weller 12", volumeMl = 750.0, now = 1_000)
        bottles.logPour(id, milliliters = 100.0, now = 2_000)
        bottles.logPour(id, milliliters = 100.0, now = 3_000)
        assertEquals(550.0, assertNotNull(bottles.byId(id)).status.remainingMilliliters)

        // Somebody looks at the bottle: it is actually down to 300.
        bottles.setLevel(id, remainingMilliliters = 300.0, now = 4_000)
        assertEquals(300.0, assertNotNull(bottles.byId(id)).status.remainingMilliliters)

        // A pour after the reading counts against the reading, not against
        // the capacity, and the two pours before it are gone for good.
        bottles.logPour(id, milliliters = 50.0, now = 5_000)
        assertEquals(250.0, assertNotNull(bottles.byId(id)).status.remainingMilliliters)
    }

    @Test
    fun `the newest reading is the one that counts`() {
        val id = bottles.add(name = "Weller 12", volumeMl = 750.0, now = 1_000)
        bottles.setLevel(id, remainingMilliliters = 500.0, now = 2_000)
        bottles.setLevel(id, remainingMilliliters = 200.0, now = 3_000)

        assertEquals(200.0, assertNotNull(bottles.byId(id)).status.remainingMilliliters)
        // The older one stays, so the screen can show how the level was
        // corrected rather than silently replacing the history.
        assertEquals(2, bottles.readingsFor(id).size)
    }

    @Test
    fun `a reading cannot put more in the bottle than it holds`() {
        val id = bottles.add(name = "Weller 12", volumeMl = 750.0, now = 1_000)
        bottles.setLevel(id, remainingMilliliters = 9_000.0, now = 2_000)
        // A fill bar showing 1200% is the app being visibly wrong.
        assertEquals(750.0, assertNotNull(bottles.byId(id)).status.remainingMilliliters)

        bottles.setLevel(id, remainingMilliliters = -50.0, now = 3_000)
        assertEquals(0.0, assertNotNull(bottles.byId(id)).status.remainingMilliliters)
    }

    @Test
    fun `setting a level below full opens a sealed bottle`() {
        val id = bottles.add(name = "Weller 12", volumeMl = 750.0, now = 1_000)
        assertFalse(assertNotNull(bottles.byId(id)).isOpen)

        bottles.setLevel(id, remainingMilliliters = 400.0, now = 2_000)

        // A bottle visibly part-empty and still marked sealed is a state
        // nothing can explain, and it leaves the oxidation clock unstarted.
        val summary = assertNotNull(bottles.byId(id))
        assertTrue(summary.isOpen)
        assertEquals(2_000L, summary.bottle.opened_at)
    }

    @Test
    fun `a reading of a full bottle leaves it sealed`() {
        val id = bottles.add(name = "Weller 12", volumeMl = 750.0, now = 1_000)
        bottles.setLevel(id, remainingMilliliters = 750.0, now = 2_000)
        // Confirming a sealed bottle is still full is not opening it.
        assertFalse(assertNotNull(bottles.byId(id)).isOpen)
    }

    @Test
    fun `one bottle's reading does not touch another's fill`() {
        val a = bottles.add(name = "Weller 12", volumeMl = 750.0, now = 1_000)
        val b = bottles.add(name = "Elijah Craig", volumeMl = 750.0, now = 1_000)
        bottles.logPour(a, milliliters = 100.0, now = 2_000)
        bottles.logPour(b, milliliters = 100.0, now = 2_000)
        bottles.setLevel(a, remainingMilliliters = 300.0, now = 3_000)

        val shelf = bottles.onShelf().associateBy { it.name }
        assertEquals(300.0, assertNotNull(shelf["Weller 12"]).status.remainingMilliliters)
        // b has no reading, so its pour still counts from a full bottle.
        assertEquals(650.0, assertNotNull(shelf["Elijah Craig"]).status.remainingMilliliters)
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

    // Wishlist

    @Test
    fun `a wishlist item can name a product or just a string`() {
        val fromCatalogue = wishlist.add(
            catalogProductId = "ec-small-batch",
            targetPriceCents = 3_000,
            now = 1_000,
        )
        val typed = wishlist.add(
            customName = "That rye from the back shelf",
            note = "No label I could read",
            now = 2_000,
        )

        assertEquals(2, wishlist.all().size)
        assertEquals(setOf("ec-small-batch"), wishlist.wishedProductIds())
        // A typed row is on the list but is not a product, so the shelf
        // check cannot and must not match it.
        assertNull(assertNotNull(wishlist.byId(typed)).catalogProductId)
        assertEquals(3_000, assertNotNull(wishlist.byId(fromCatalogue)).targetPriceCents)
        assertEquals(
            "No label I could read",
            assertNotNull(wishlist.byId(typed)).note,
        )
    }

    @Test
    fun `a blank name or note is stored as absent rather than empty`() {
        val id = wishlist.add(customName = "   ", note = "", now = 1_000)
        val item = assertNotNull(wishlist.byId(id))
        assertNull(item.customName)
        assertNull(item.note)
    }

    @Test
    fun `taking an item off leaves a tombstone and clears the shelf check`() {
        val id = wishlist.add(catalogProductId = "ec-small-batch", now = 1_000)
        assertTrue(wishlist.isWished("ec-small-batch"))

        wishlist.remove(id, now = 2_000)

        assertNull(wishlist.byId(id))
        assertTrue(wishlist.all().isEmpty())
        assertFalse(wishlist.isWished("ec-small-batch"))
        // The row survives so the other devices learn it went.
        assertEquals(1, rawCount("select count(*) from wishlist_items"))
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
