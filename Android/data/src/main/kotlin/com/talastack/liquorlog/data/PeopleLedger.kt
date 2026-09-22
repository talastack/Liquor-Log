package com.talastack.liquorlog.data

import com.talastack.liquorlog.engine.People
import java.time.Instant

/**
 * Who sent you samples, and who you poured for.
 *
 * **Derived, never kept.** Every fact this needs is already recorded
 * somewhere else: a sample bottle says who it came from, a pour says who it
 * went to, a tasting says what you thought of it. A people table would be a
 * second copy of all three, and the copy would drift the first time somebody
 * corrected a name on the bottle and not on the person.
 *
 * Nothing here is about how much anybody drank. It is about what changed
 * hands, which is why it counts millilitres given and received and nothing
 * else.
 */
class PeopleLedger(private val database: LiquorDatabase) {

    private val q = database.bottlesQueries
    private val t = database.tastingsQueries

    /**
     * The ledger, most recent exchange first.
     *
     * [names] maps a bottle id to what it should be called, so a catalogue
     * bottle reads as the catalogue names it rather than as whatever was
     * typed. A map rather than a callback because only the caller knows the
     * catalogue, and because it keeps this file independent of the row types
     * SQLDelight happens to generate per query.
     */
    fun ledger(names: Map<String, String> = emptyMap()): List<People.Person> {
        // The newest rating per bottle, so "their samples average 8 with you"
        // rests on what you actually thought of what they sent.
        val ratings = t.latestRatings().executeAsList()
            .mapNotNull { row ->
                val bottleId = row.bottle_id ?: return@mapNotNull null
                val rating = row.rating ?: return@mapNotNull null
                bottleId to rating.toInt()
            }
            .toMap()

        val received = q.samplesReceived().executeAsList().mapNotNull { bottle ->
            val from = bottle.sample_from?.takeIf { it.isNotBlank() } ?: return@mapNotNull null
            People.ReceivedEntry(
                from = from,
                bottle = names[bottle.id] ?: bottle.custom_name ?: "A bottle",
                milliliters = bottle.volume_ml,
                how = bottle.sample_source?.takeIf { it.isNotBlank() },
                at = Instant.ofEpochMilli(bottle.created_at),
                rating = ratings[bottle.id],
            )
        }

        val given = q.poursGivenAway().executeAsList().mapNotNull { row ->
            val to = row.given_to?.takeIf { it.isNotBlank() } ?: return@mapNotNull null
            People.GivenEntry(
                to = to,
                bottle = names[row.bottle_id] ?: row.custom_name ?: "A bottle",
                milliliters = row.volume_ml,
                at = Instant.ofEpochMilli(row.poured_at),
            )
        }

        return People.ledger(received = received, given = given)
    }
}
