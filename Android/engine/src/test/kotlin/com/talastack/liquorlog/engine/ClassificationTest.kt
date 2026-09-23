package com.talastack.liquorlog.engine

import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertFalse
import kotlin.test.assertNull
import kotlin.test.assertTrue

/**
 * The rules here are regulation, not opinion, so the tests read like the
 * regulation. The ones that matter most are the refusals: a rule that
 * wrongly rejects real whiskey is worse than no rule.
 */
class ClassificationTest {

    @Test
    fun `every storage key round-trips, so nothing in the database orphans`() {
        for (type in ClassType.entries) {
            assertEquals(type, ClassType.fromStorageKey(type.storageKey), type.name)
        }
        for (type in ProductionType.entries) {
            assertEquals(type, ProductionType.fromStorageKey(type.storageKey), type.name)
        }
        assertNull(ClassType.fromStorageKey("notAClass"))
    }

    @Test
    fun `storage keys are the lowerCamelCase the Swift engine and Postgres use`() {
        assertEquals("kentuckyStraightBourbon", ClassType.KENTUCKY_STRAIGHT_BOURBON.storageKey)
        assertEquals("singleMaltScotch", ClassType.SINGLE_MALT_SCOTCH.storageKey)
        assertEquals("singleBarrel", ProductionType.SINGLE_BARREL.storageKey)
    }

    @Test
    fun `families group the way the filters expect`() {
        assertEquals(ClassType.Family.WHISKEY, ClassType.KENTUCKY_STRAIGHT_BOURBON.family)
        assertEquals(ClassType.Family.AGAVE, ClassType.MEZCAL.family)
        assertEquals(ClassType.Family.BRANDY, ClassType.COGNAC.family)
        assertEquals(ClassType.Family.LIQUEUR, ClassType.AMARO.family)
        assertEquals(ClassType.Family.BEER, ClassType.MALT_BEVERAGE.family)
        // Not beer: cider is a wine for tax purposes and seltzer is not one
        // thing at all.
        assertEquals(ClassType.Family.CIDER, ClassType.HARD_CIDER.family)
        assertEquals(ClassType.Family.SELTZER, ClassType.HARD_SELTZER.family)
        assertEquals(ClassType.Family.OTHER, ClassType.ABSINTHE.family)
    }

    @Test
    fun `tennessee whiskey counts as straight, because bonded ones exist`() {
        // Jack Daniel's Bonded and George Dickel Bottled in Bond are both on
        // shelves; excluding Tennessee here said they could not be.
        assertTrue(ClassType.TENNESSEE_WHISKEY.isStraight)
        assertTrue(ClassType.STRAIGHT_RYE.isStraight)
        assertFalse(ClassType.BOURBON.isStraight, "plain bourbon makes no straight claim")
        assertFalse(ClassType.SINGLE_MALT_SCOTCH.isStraight, "not an American designation")
    }

    @Test
    fun `the forty percent floor applies to spirits but never to a liqueur`() {
        assertEquals(ABV(percent = 40.0), ClassType.KENTUCKY_STRAIGHT_BOURBON.minimumBottlingStrength)
        assertEquals(ABV(percent = 40.0), ClassType.TEQUILA_BLANCO.minimumBottlingStrength)
        // A 16% amaro is correct by design; rejecting it would be the app
        // being wrong with confidence.
        assertNull(ClassType.AMARO.minimumBottlingStrength)
        assertNull(ClassType.VERMOUTH.minimumBottlingStrength)
        assertNull(ClassType.MALT_BEVERAGE.minimumBottlingStrength)

        // A 5% cider is not an under-strength spirit; it is a cider. The 40%
        // floor is an American spirits rule and applying it here would flag
        // every can on the shelf.
        assertNull(ClassType.HARD_CIDER.minimumBottlingStrength)
        assertNull(ClassType.HARD_SELTZER.minimumBottlingStrength)
    }

    @Test
    fun `a correct bottle raises nothing`() {
        val issues = Classification.validate(
            classType = ClassType.KENTUCKY_STRAIGHT_BOURBON,
            abv = ABV(percent = 62.1),
            statedAgeYears = 8,
            isBottledInBond = false,
            volumeMilliliters = 750.0,
        )
        assertTrue(issues.isEmpty(), issues.toString())
    }

    @Test
    fun `a barrel proof bottling is not rejected for exceeding the entry proof`() {
        // Bourbon's 125-proof cap is an ENTRY proof. Whiskey gains strength in
        // a hot warehouse, so real barrel-proof bottlings sit above it.
        val issues = Classification.validate(
            classType = ClassType.KENTUCKY_STRAIGHT_BOURBON,
            abv = ABV(percent = 71.3),
            statedAgeYears = 12,
            isBottledInBond = false,
            volumeMilliliters = 750.0,
        )
        assertTrue(issues.isEmpty(), "142.6 proof is a real bottle: $issues")
    }

    @Test
    fun `a decimal slip is caught`() {
        val issues = Classification.validate(
            classType = ClassType.KENTUCKY_STRAIGHT_BOURBON,
            abv = ABV(percent = 6.26),
            statedAgeYears = null,
            isBottledInBond = false,
            volumeMilliliters = 750.0,
        )
        // Not by the plausible range -- 6.26% is a real beer strength -- but
        // by the class's own floor.
        assertTrue(issues.any { it.rule == "abv.americanMinimum" }, issues.toString())
    }

    @Test
    fun `bonded means exactly one hundred proof, four years, and straight`() {
        val wrongProof = Classification.validate(
            classType = ClassType.KENTUCKY_STRAIGHT_BOURBON,
            abv = ABV(percent = 47.0), statedAgeYears = 6,
            isBottledInBond = true, volumeMilliliters = 750.0,
        )
        assertTrue(wrongProof.any { it.rule == "bond.proof" }, wrongProof.toString())

        val tooYoung = Classification.validate(
            classType = ClassType.KENTUCKY_STRAIGHT_BOURBON,
            abv = ABV(percent = 50.0), statedAgeYears = 2,
            isBottledInBond = true, volumeMilliliters = 750.0,
        )
        assertTrue(tooYoung.any { it.rule == "bond.minimumAge" }, tooYoung.toString())

        val notStraight = Classification.validate(
            classType = ClassType.BOURBON,
            abv = ABV(percent = 50.0), statedAgeYears = 6,
            isBottledInBond = true, volumeMilliliters = 750.0,
        )
        assertTrue(notStraight.any { it.rule == "bond.requiresStraight" }, notStraight.toString())

        val correct = Classification.validate(
            classType = ClassType.KENTUCKY_STRAIGHT_BOURBON,
            abv = ABV(percent = 50.0), statedAgeYears = 4,
            isBottledInBond = true, volumeMilliliters = 750.0,
        )
        assertTrue(correct.isEmpty(), correct.toString())
    }

    @Test
    fun `a bonded brandy is allowed, because 27 CFR 5 88 allows it`() {
        // Laird's bottles a bonded apple brandy. The straight requirement is
        // a whiskey rule only.
        val issues = Classification.validate(
            classType = ClassType.CALVADOS,
            abv = ABV(percent = 50.0), statedAgeYears = 4,
            isBottledInBond = true, volumeMilliliters = 750.0,
        )
        assertTrue(issues.isEmpty(), issues.toString())
    }

    @Test
    fun `a size that is not a standard of fill is caught`() {
        val issues = Classification.validate(
            classType = ClassType.VODKA, abv = ABV(percent = 40.0), statedAgeYears = null,
            isBottledInBond = false, volumeMilliliters = 751.0,
        )
        assertTrue(issues.any { it.rule == "volume.standardOfFill" }, issues.toString())
    }

    @Test
    fun `a missing abv is said rather than assumed`() {
        val issues = Classification.validate(
            classType = ClassType.RUM, abv = null, statedAgeYears = null,
            isBottledInBond = false, volumeMilliliters = 750.0,
        )
        assertTrue(issues.any { it.rule == "abv.missing" }, issues.toString())
    }
}
