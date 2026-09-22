package com.talastack.liquorlog.engine

import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertNull
import kotlin.test.assertTrue

/**
 * An infinity bottle's two numbers: what it is made of, and how strong it
 * is. Both come from what went in, never from what came out.
 */
class BlendTest {

    private fun part(key: String, ml: Double, abv: Double?) =
        Blend.Part(
            key = key,
            name = key.replaceFirstChar { it.uppercase() },
            milliliters = ml,
            abv = abv
        )

    /**
     * Alcohol is conserved: 100 ml at 60% and 100 ml at 40% is 200 ml at
     * 50%, not "somewhere in between".
     */
    @Test
    fun `strength is alcohol over volume`() {
        val profile = Blend.profile(listOf(part("a", 100.0, 60.0), part("b", 100.0, 40.0)))
        assertEquals(50.0, profile.abv ?: 0.0, 0.0001)
        assertEquals(100.0, profile.proof ?: 0.0, 0.0001)
        assertEquals("100.0 proof", profile.strengthText)
    }

    @Test
    fun `an uneven blend weights by volume`() {
        // 300 ml at 62.1% and 100 ml at 45%: (300*62.1 + 100*45) / 400
        val profile = Blend.profile(listOf(part("a", 300.0, 62.1), part("b", 100.0, 45.0)))
        assertEquals(57.825, profile.abv ?: 0.0, 0.0001)
    }

    /**
     * A part with no known proof makes the whole strength unknown. Guessing
     * a barrel-proof bottle at the catalogue's null would print a number
     * that is wrong for every bottle.
     */
    @Test
    fun `one unknown part makes the strength unknown and says how much`() {
        val profile = Blend.profile(listOf(part("a", 100.0, 50.0), part("b", 60.0, null)))
        assertNull(profile.abv)
        assertEquals(60.0, profile.unknownMilliliters)
        assertEquals("Unknown — 60 ml went in without a proof", profile.strengthText)
    }

    @Test
    fun `shares are by what went in, merged by source`() {
        val profile = Blend.profile(
            listOf(
                part("weller", 50.0, 45.0),
                part("stagg", 100.0, 65.0),
                part("weller", 50.0, 45.0)
            )
        )
        assertEquals(listOf("stagg", "weller"), profile.shares.map { it.key })
        assertEquals(listOf(100.0, 100.0), profile.shares.map { it.milliliters })
        assertEquals(listOf(0.5, 0.5), profile.shares.map { it.fraction })
        assertEquals(200.0, profile.addedMilliliters)
        assertEquals(2, profile.partCount)
    }

    @Test
    fun `equal shares sort by name so the list is stable`() {
        val profile = Blend.profile(listOf(part("zed", 50.0, 45.0), part("abe", 50.0, 45.0)))
        assertEquals(listOf("abe", "zed"), profile.shares.map { it.key })
    }

    @Test
    fun `a splash is under one percent rather than zero`() {
        val profile = Blend.profile(listOf(part("a", 1000.0, 45.0), part("b", 5.0, 45.0)))
        assertEquals("under 1%", profile.shares.last().percentText)
        assertEquals("100%", profile.shares.first().percentText)
    }

    @Test
    fun `nothing in it yet`() {
        val profile = Blend.profile(emptyList())
        assertTrue(profile.isEmpty)
        assertNull(profile.abv)
        assertEquals("Nothing in it yet", profile.strengthText)
        assertTrue(profile.shares.isEmpty())
    }

    @Test
    fun `zero and negative volumes are ignored`() {
        val profile = Blend.profile(
            listOf(part("a", 0.0, 50.0), part("b", -5.0, 50.0), part("c", 30.0, 50.0))
        )
        assertEquals(listOf("c"), profile.shares.map { it.key })
        assertEquals(50.0, profile.abv ?: 0.0, 0.0001)
    }
}

/**
 * The CRT registry, as the app reads it: a NOM to its plant, a brand to
 * its NOM. Fixture rows are real registry rows (September 2026).
 */
class TequilaRegistryTest {

    private val registry = TequilaRegistry(
        listOf(
            TequilaRegistry.Producer(
                "1139", "TEQUILA TAPATIO, S.A. DE C.V.",
                listOf("EL TESORO", "EL TESORO DE DON FELIPE", "PARADISO", "TAPATIO")
            ),
            TequilaRegistry.Producer(
                "1142", "LA MADRILEÑA, S.A. DE C.V.",
                listOf("CORONA", "JARANA", "KIRKLAND SIGNATURE", "MAYORAZGO")
            ),
            TequilaRegistry.Producer(
                "1609", "DIAGEO MEXICO OPERACIONES, S.A. DE C.V.", listOf("CASAMIGOS")
            ),
            TequilaRegistry.Producer(
                "1108", "JORGE SALLES CUERVO Y SUCESORES, S.A. DE C.V.",
                listOf("EL TEQUILEÑO")
            ),
            TequilaRegistry.Producer(
                "1143", "DESTILADORA DEL VALLE DE TEQUILA, S.A. DE C.V.",
                listOf("TRADER JOE´S")
            ),
            TequilaRegistry.Producer("1577", "AGAVE CONQUISTA, S.A. DE C.V.", listOf("1519"))
        )
    )

    @Test
    fun `a NOM reads however it is typed`() {
        assertEquals("1139", TequilaRegistry.normalise("NOM 1139"))
        assertEquals("1139", TequilaRegistry.normalise("nom-1139"))
        assertEquals("1139", TequilaRegistry.normalise("1139"))
        assertNull(TequilaRegistry.normalise("DSP-KY-113"))
        assertNull(TequilaRegistry.normalise("B523"))
        assertNull(TequilaRegistry.normalise("11390"))
    }

    @Test
    fun `a NOM names its plant`() {
        assertEquals("TEQUILA TAPATIO, S.A. DE C.V.", registry.producer("NOM 1139")?.company)
        assertNull(registry.producer("1104"))
    }

    /** The question people actually have: who makes this? */
    @Test
    fun `a brand finds its NOM`() {
        val hits = registry.find("casamigos")
        assertEquals(listOf("1609"), hits.map { it.producer.nom })
        assertEquals("CASAMIGOS", hits.first().brand)
    }

    @Test
    fun `exact beats prefix beats contains`() {
        val hits = registry.find("el tesoro")
        assertEquals(listOf("EL TESORO", "EL TESORO DE DON FELIPE"), hits.map { it.brand })
        val partial = registry.find("signature")
        assertEquals(listOf("1142"), partial.map { it.producer.nom })
    }

    @Test
    fun `three letters are not a search`() {
        assertTrue(registry.find("el").isEmpty())
        assertTrue(registry.find("OES").isEmpty(), "the start of a Four Roses code")
    }

    /**
     * Accents and the CRT's own apostrophe fold away, as everywhere else
     * in the app.
     */
    @Test
    fun `accents and apostrophes fold`() {
        assertEquals(listOf("1108"), registry.find("el tequileno").map { it.producer.nom })
        assertEquals(listOf("1143"), registry.find("Trader Joe's").map { it.producer.nom })
        assertEquals(listOf("1143"), registry.find("trader joe").map { it.producer.nom })
    }

    @Test
    fun `four digits can be a brand as well as a NOM`() {
        assertEquals(listOf("1577"), registry.exact("1519").map { it.producer.nom })
        assertTrue(registry.exact("1139").isEmpty())
    }

    /**
     * Swift decodes `tequila-nom.v1.json` here with Foundation's
     * JSONDecoder. This module has no JSON dependency by design, so the
     * Android data layer parses the file and hands the rows to the
     * constructor -- which is the path this test walks instead.
     */
    @Test
    fun `rows handed in from the data layer are queryable`() {
        val decoded = TequilaRegistry(
            listOf(
                TequilaRegistry.Producer(
                    "1493", "TEQUILA LOS ABUELOS, S.A. DE C.V.",
                    listOf("FORTALEZA", "LOS ABUELOS")
                )
            )
        )
        assertEquals(listOf("FORTALEZA", "LOS ABUELOS"), decoded.producer("1493")?.brands)
        assertTrue(TequilaRegistry.empty.isEmpty)
    }
}
