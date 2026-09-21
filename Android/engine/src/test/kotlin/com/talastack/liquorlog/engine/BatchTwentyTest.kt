package com.talastack.liquorlog.engine

import java.time.Instant
import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertFalse
import kotlin.test.assertNotNull
import kotlin.test.assertNull
import kotlin.test.assertTrue

/**
 * Finding one bottle in two hundred. These pin the rules the screen relies
 * on: prefix matching like the shop search, kinds that narrow rather than
 * widen, and sorts that put the useless rows (never poured, unrated,
 * finished) at the bottom rather than the top.
 */
class CollectionFilterTest {

    private fun day(n: Long): Instant = Instant.EPOCH.plusSeconds(n * 86_400)

    private val shelf = listOf(
        CollectionFilter.Row(
            id = "ecbp", name = "Elijah Craig Barrel Proof B523", distillery = "Heaven Hill",
            extraSearchText = listOf("B523", "Cabinet"),
            classType = ClassType.KENTUCKY_STRAIGHT_BOURBON,
            productionType = ProductionType.SMALL_BATCH,
            isBarrelProof = true, isOpen = true, storageLocation = "Cabinet",
            addedAt = day(10), lastPouredAt = day(12), rating = 8, fillFraction = 0.6
        ),
        CollectionFilter.Row(
            id = "fr", name = "Four Roses Single Barrel OESQ", distillery = "Four Roses",
            extraSearchText = listOf("42-3C", "Total Wine", "Basement"),
            classType = ClassType.KENTUCKY_STRAIGHT_BOURBON,
            productionType = ProductionType.SINGLE_BARREL,
            isBarrelProof = true, isStorePick = true, storageLocation = "Basement",
            addedAt = day(20), rating = null, fillFraction = 1.0
        ),
        CollectionFilter.Row(
            id = "weller", name = "W L Weller Special Reserve", distillery = "Buffalo Trace",
            classType = ClassType.KENTUCKY_STRAIGHT_BOURBON,
            isOpen = true, storageLocation = "Cabinet",
            addedAt = day(5), lastPouredAt = day(30), rating = 6, fillFraction = 0.1
        ),
        CollectionFilter.Row(
            id = "rye", name = "Rittenhouse Rye", distillery = "Heaven Hill",
            classType = ClassType.STRAIGHT_RYE, isBottledInBond = true,
            addedAt = day(1), fillFraction = 1.0
        ),
        CollectionFilter.Row(
            id = "dead", name = "Eagle Rare 10", distillery = "Buffalo Trace",
            classType = ClassType.KENTUCKY_STRAIGHT_BOURBON,
            productionType = ProductionType.SINGLE_BARREL,
            isOpen = true, isFinished = true,
            addedAt = day(0), lastPouredAt = day(2), rating = 7, fillFraction = 0.0
        ),
        CollectionFilter.Row(
            id = "lag", name = "Lagavulin 16", distillery = "Lagavulin",
            classType = ClassType.SINGLE_MALT_SCOTCH, addedAt = day(3), fillFraction = 0.8
        )
    )

    private fun ids(criteria: CollectionFilter.Criteria): List<String> =
        CollectionFilter.apply(criteria, shelf).map { it.id }

    /** The default is what you own now: finished bottles wait to be asked for. */
    @Test
    fun `no criteria returns the shelf, newest first`() {
        assertEquals(
            listOf("fr", "ecbp", "weller", "lag", "rye"),
            ids(CollectionFilter.Criteria.none)
        )
    }

    @Test
    fun `everything includes finished`() {
        assertEquals(
            listOf("fr", "ecbp", "weller", "lag", "rye", "dead"),
            ids(CollectionFilter.Criteria(status = CollectionFilter.Status.ANY))
        )
    }

    @Test
    fun `every token must prefix something`() {
        assertEquals(listOf("ecbp"), ids(CollectionFilter.Criteria(query = "eli bar")))
        assertEquals(emptyList(), ids(CollectionFilter.Criteria(query = "eli lag")))
    }

    @Test
    fun `distillery is searchable`() {
        assertEquals(
            setOf("ecbp", "rye"),
            ids(CollectionFilter.Criteria(query = "heaven")).toSet()
        )
    }

    @Test
    fun `barrel number, store and location are searchable`() {
        assertEquals(listOf("fr"), ids(CollectionFilter.Criteria(query = "42-3c")))
        assertEquals(listOf("fr"), ids(CollectionFilter.Criteria(query = "total wine")))
        assertEquals(
            setOf("ecbp", "weller"),
            ids(CollectionFilter.Criteria(query = "cabinet")).toSet()
        )
    }

    @Test
    fun `punctuation and case do not matter`() {
        assertEquals(listOf("weller"), ids(CollectionFilter.Criteria(query = "W.L. WELLER")))
    }

    @Test
    fun `open excludes finished`() {
        assertEquals(
            setOf("ecbp", "weller"),
            ids(CollectionFilter.Criteria(status = CollectionFilter.Status.OPEN)).toSet()
        )
    }

    @Test
    fun `unopened`() {
        assertEquals(
            setOf("fr", "rye", "lag"),
            ids(CollectionFilter.Criteria(status = CollectionFilter.Status.UNOPENED)).toSet()
        )
    }

    @Test
    fun `finished`() {
        assertEquals(
            listOf("dead"),
            ids(CollectionFilter.Criteria(status = CollectionFilter.Status.FINISHED))
        )
    }

    @Test
    fun `kinds narrow rather than widen`() {
        assertEquals(
            setOf("ecbp", "fr"),
            ids(CollectionFilter.Criteria(kinds = setOf(CollectionFilter.Kind.BARREL_PROOF))).toSet()
        )
        assertEquals(
            listOf("fr"),
            ids(
                CollectionFilter.Criteria(
                    kinds = setOf(
                        CollectionFilter.Kind.BARREL_PROOF,
                        CollectionFilter.Kind.STORE_PICK
                    )
                )
            )
        )
        assertEquals(
            emptyList(),
            ids(
                CollectionFilter.Criteria(
                    kinds = setOf(
                        CollectionFilter.Kind.BARREL_PROOF,
                        CollectionFilter.Kind.BOTTLED_IN_BOND
                    )
                )
            )
        )
    }

    /** Class and production are separate facts and separate chips. */
    @Test
    fun `single barrel is production, not class`() {
        assertEquals(
            setOf("fr", "dead"),
            ids(
                CollectionFilter.Criteria(
                    status = CollectionFilter.Status.ANY,
                    kinds = setOf(CollectionFilter.Kind.SINGLE_BARREL)
                )
            ).toSet()
        )
        assertEquals(
            setOf("ecbp", "fr", "weller", "dead"),
            ids(
                CollectionFilter.Criteria(
                    status = CollectionFilter.Status.ANY,
                    kinds = setOf(CollectionFilter.Kind.BOURBON)
                )
            ).toSet()
        )
        assertEquals(
            listOf("rye"),
            ids(CollectionFilter.Criteria(kinds = setOf(CollectionFilter.Kind.RYE)))
        )
        assertEquals(
            listOf("lag"),
            ids(CollectionFilter.Criteria(kinds = setOf(CollectionFilter.Kind.SCOTCH)))
        )
    }

    @Test
    fun `only kinds something matches are offered`() {
        val offered = CollectionFilter.availableKinds(shelf)
        assertTrue(offered.contains(CollectionFilter.Kind.STORE_PICK))
        assertTrue(offered.contains(CollectionFilter.Kind.SCOTCH))
        assertFalse(offered.contains(CollectionFilter.Kind.WHEAT_WHISKEY))
        assertFalse(offered.contains(CollectionFilter.Kind.NOT_WHISKEY))
    }

    @Test
    fun `locations, most used first`() {
        assertEquals(listOf("Cabinet", "Basement"), CollectionFilter.locations(shelf))
    }

    @Test
    fun `the location filter is case insensitive`() {
        assertEquals(
            setOf("ecbp", "weller"),
            ids(CollectionFilter.Criteria(location = "cabinet")).toSet()
        )
    }

    @Test
    fun `nearly gone puts finished last`() {
        val order = ids(
            CollectionFilter.Criteria(
                status = CollectionFilter.Status.ANY,
                sort = CollectionFilter.Sort.NEARLY_GONE
            )
        )
        assertEquals(listOf("weller", "ecbp", "lag"), order.take(3))
        assertEquals("dead", order.last())
    }

    @Test
    fun `fullest first`() {
        assertEquals(
            setOf("fr", "rye"),
            ids(CollectionFilter.Criteria(sort = CollectionFilter.Sort.FULLEST)).take(2).toSet()
        )
    }

    @Test
    fun `last poured puts never poured last`() {
        val order = ids(
            CollectionFilter.Criteria(
                status = CollectionFilter.Status.ANY,
                sort = CollectionFilter.Sort.LAST_POURED
            )
        )
        assertEquals(listOf("weller", "ecbp", "dead"), order.take(3))
        assertEquals(setOf("fr", "rye", "lag"), order.takeLast(3).toSet())
    }

    @Test
    fun `rating puts unrated last`() {
        val order = ids(
            CollectionFilter.Criteria(
                status = CollectionFilter.Status.ANY,
                sort = CollectionFilter.Sort.RATING
            )
        )
        assertEquals(listOf("ecbp", "dead", "weller"), order.take(3))
    }

    @Test
    fun `the name sort ignores case`() {
        val order = ids(
            CollectionFilter.Criteria(
                status = CollectionFilter.Status.ANY,
                sort = CollectionFilter.Sort.NAME
            )
        )
        assertEquals("dead", order.first(), "Eagle Rare")
    }

    @Test
    fun `is narrowing`() {
        assertFalse(CollectionFilter.Criteria.none.isNarrowing)
        assertFalse(CollectionFilter.Criteria(sort = CollectionFilter.Sort.RATING).isNarrowing)
        assertTrue(CollectionFilter.Criteria(query = " x").isNarrowing)
        assertTrue(CollectionFilter.Criteria(status = CollectionFilter.Status.OPEN).isNarrowing)
        assertTrue(CollectionFilter.Criteria(status = CollectionFilter.Status.ANY).isNarrowing)
        assertTrue(CollectionFilter.Criteria(location = "Cabinet").isNarrowing)
    }

    @Test
    fun `the samples kind finds samples and search finds who they came from`() {
        val rows = shelf + CollectionFilter.Row(
            id = "s1", name = "Stagg Jr", distillery = "Buffalo Trace",
            extraSearchText = listOf("Mike"), classType = ClassType.KENTUCKY_STRAIGHT_BOURBON,
            isOpen = true, isSample = true, addedAt = day(40), fillFraction = 1.0
        )
        assertEquals(
            listOf("s1"),
            CollectionFilter.apply(
                CollectionFilter.Criteria(kinds = setOf(CollectionFilter.Kind.SAMPLE)), rows
            ).map { it.id }
        )
        assertEquals(
            listOf("s1"),
            CollectionFilter.apply(CollectionFilter.Criteria(query = "mike"), rows).map { it.id }
        )
        assertTrue(CollectionFilter.availableKinds(rows).contains(CollectionFilter.Kind.SAMPLE))
        assertFalse(CollectionFilter.availableKinds(shelf).contains(CollectionFilter.Kind.SAMPLE))
    }

    @Test
    fun `the infinity kind finds infinity bottles`() {
        val rows = shelf + CollectionFilter.Row(
            id = "inf", name = "The Ever Bottle", isOpen = true, isInfinity = true,
            addedAt = day(50), fillFraction = 0.3
        )
        assertEquals(
            listOf("inf"),
            CollectionFilter.apply(
                CollectionFilter.Criteria(kinds = setOf(CollectionFilter.Kind.INFINITY)), rows
            ).map { it.id }
        )
        assertFalse(CollectionFilter.availableKinds(shelf).contains(CollectionFilter.Kind.INFINITY))
    }
}

/**
 * Somebody's spreadsheet, turned into bottles. It plans rather than writes,
 * and it reports what it could not read instead of inventing it.
 */
class CollectionImportTest {

    /** Nobody should have to rename a column to import. */
    @Test
    fun `it recognises the words people actually use`() {
        val plan = CollectionImport.plan(
            "Whiskey,Proof,Purchase Price (\$),Bought At,Where Kept\n" +
                "Blanton's,93,\$79.99,Total Wine,hall closet"
        )
        assertEquals(1, plan.rows.size)
        val row = plan.rows[0]
        assertEquals("Blanton's", row.name)
        assertEquals(93.0, row.proof)
        assertEquals(7999, row.paidCents)
        assertEquals("Total Wine", row.store)
        assertEquals("hall closet", row.storageLocation)
    }

    @Test
    fun `the mapping says which column became what`() {
        val plan = CollectionImport.plan("Bottle,ABV\nWeller,45\n")
        assertEquals("bottle", plan.mapping[CollectionImport.Field.NAME])
        assertEquals("abv", plan.mapping[CollectionImport.Field.ABV])
    }

    /** Our own export must come back in whole. This is the backup promise. */
    @Test
    fun `our own export imports cleanly`() {
        val text = CSVWriter.document(
            header = listOf(
                "name", "status", "size_ml", "proof", "batch", "price", "storage_location"
            ),
            rows = listOf(
                listOf("Elijah Craig Barrel Proof", "open", "750", "124.2", "B523", "79.99", "closet")
            )
        )
        val row = assertNotNull(CollectionImport.plan(text).rows.firstOrNull())
        assertEquals("Elijah Craig Barrel Proof", row.name)
        assertTrue(row.isOpen)
        assertEquals(750.0, row.volumeMilliliters)
        assertEquals(124.2, row.proof ?: 0.0, 0.01)
        assertEquals("B523", row.batch)
        assertEquals(7999, row.paidCents)
    }

    @Test
    fun `ABV becomes proof when there is no proof column`() {
        val plan = CollectionImport.plan("Name,ABV\nWeller,45%\n")
        assertEquals(90.0, plan.rows[0].proof ?: 0.0, 0.01)
    }

    /** The number people wrote down wins. */
    @Test
    fun `proof wins over ABV when both are present`() {
        val plan = CollectionImport.plan("Name,ABV,Proof\nWeller,45,107\n")
        assertEquals(107.0, plan.rows[0].proof ?: 0.0, 0.01)
    }

    /** "0.75" in a size column is litres; 750 is millilitres. */
    @Test
    fun `a size in litres is converted to millilitres`() {
        assertEquals(
            750.0,
            CollectionImport.plan("Name,Size\nA,0.75\n").rows[0].volumeMilliliters
        )
        assertEquals(
            750.0,
            CollectionImport.plan("Name,Size\nA,750\n").rows[0].volumeMilliliters
        )
        assertEquals(
            750.0,
            CollectionImport.plan("Name,Size\nA,750ml\n").rows[0].volumeMilliliters
        )
    }

    @Test
    fun `status words are read`() {
        val plan = CollectionImport.plan(
            "Name,Status\nA,Open\nB,Sealed\nC,Killed\nD,finished"
        )
        assertTrue(plan.rows[0].isOpen)
        assertFalse(plan.rows[1].isOpen)
        assertTrue(plan.rows[2].isFinished)
        assertTrue(plan.rows[3].isFinished)
        assertFalse(plan.rows[3].isOpen, "finished is not open")
    }

    /** A row with no name is reported by line, never saved as "Untitled". */
    @Test
    fun `rows with no name are skipped and named by line`() {
        val plan = CollectionImport.plan("Name,Proof\nWeller,90\n,100\nBooker's,125\n")
        assertEquals(listOf("Weller", "Booker's"), plan.rows.map { it.name })
        assertEquals(listOf(3), plan.skippedLines)
    }

    /**
     * With no recognisable name column there is nothing to import, and the
     * honest plan is every line skipped rather than the first column guessed.
     */
    @Test
    fun `a file with no name column imports nothing`() {
        val plan = CollectionImport.plan("Foo,Bar\n1,2\n3,4\n")
        assertTrue(plan.isEmpty)
        assertEquals(listOf(2, 3), plan.skippedLines)
        assertNull(plan.mapping[CollectionImport.Field.NAME])
    }

    @Test
    fun `blank rows are ignored, not skipped`() {
        val plan = CollectionImport.plan("Name\nWeller\n\n\nBooker's\n")
        assertEquals(2, plan.rows.size)
        assertTrue(plan.skippedLines.isEmpty(), "an empty line is not a bottle with no name")
    }

    /**
     * Each column is claimed once. A file with both "Price" and "Cost" reads
     * price and leaves cost alone rather than reading it twice.
     */
    @Test
    fun `a column is claimed by only one field`() {
        val mapping = CollectionImport.map(listOf("name", "price", "cost"))
        assertEquals("price", mapping[CollectionImport.Field.PAID])
        assertEquals(mapping.size, mapping.values.toSet().size)
    }

    /**
     * A "sample" column: "yes" is a sample, a name is a sample from that
     * person, "no" and blank are bottles. The samples tab of a spreadsheet
     * imports without renaming anything.
     */
    @Test
    fun `a sample column marks samples and who they came from`() {
        val plan = CollectionImport.plan(
            "Name,Sample\nWeller 12,Mike\nStagg,yes\nBlanton's,no\nEagle Rare,"
        )
        assertEquals(listOf(true, true, false, false), plan.rows.map { it.isSample })
        assertEquals(listOf("Mike", null, null, null), plan.rows.map { it.sampleFrom })
        assertEquals("sample", plan.mapping[CollectionImport.Field.SAMPLE])
    }

    @Test
    fun `sample from is recognised as a header`() {
        val plan = CollectionImport.plan("Name,Sample From\nWeller 12,the Louisville swap\n")
        assertEquals("the Louisville swap", plan.rows[0].sampleFrom)
        assertTrue(plan.rows[0].isSample)
    }
}
