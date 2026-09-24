package com.talastack.liquorlog.ui

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.FlowRow
import androidx.compose.foundation.layout.ExperimentalLayoutApi
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.remember
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.unit.dp
import com.talastack.liquorlog.engine.People
import com.talastack.liquorlog.ui.theme.Space
import com.talastack.liquorlog.ui.theme.TypeScale
import com.talastack.liquorlog.ui.theme.palette
import java.time.Instant

/**
 * Who sent you samples, who you poured for, whose turn it is.
 *
 * Nothing here is recorded twice. The ledger is read from facts the app
 * already holds -- a sample bottle names who it came from, a pour names who
 * it went to -- so there is no people list to keep in step with the bottles.
 *
 * It counts what changed hands and nothing else. There is no total of what
 * anybody drank, and the balance is a fact about generosity in both
 * directions rather than a debt anybody owes.
 */
@Composable
fun PeopleScreen(onBack: () -> Unit) {
    val state = LocalAppState.current
    val colors = palette
    val now = remember(state.changeCount) { Instant.now() }

    val people = remember(state.changeCount) {
        val names = state.bottles.all().associate { it.id to state.name(it) }
        state.people.ledger(names)
    }

    Column(Modifier.fillMaxWidth()) {
        DetailBar("People", onBack)
        LazyColumn(
            contentPadding = PaddingValues(Space.xl),
            verticalArrangement = Arrangement.spacedBy(Space.m),
        ) {
            if (people.isEmpty()) {
                item {
                    Empty(
                        "Nobody yet",
                        "Mark a bottle as a sample and say who it came from, or " +
                            "pour one for somebody. They appear here on their own.",
                    )
                }
            } else {
                item {
                    Text(
                        "Read from your bottles and pours. Nothing here is a " +
                            "separate list to keep up to date.",
                        style = TypeScale.secondary,
                        color = colors.textSecondary,
                    )
                }
                items(people, key = { it.key }) { person ->
                    PersonCard(person, now, state.ounces)
                }
            }
        }
    }
}

@Composable
private fun PersonCard(person: People.Person, now: Instant, ounces: Boolean) {
    val colors = palette
    Card {
        Row(
            modifier = Modifier.fillMaxWidth(),
            verticalAlignment = Alignment.CenterVertically,
        ) {
            Text(
                person.name,
                style = TypeScale.title,
                color = colors.text,
                modifier = Modifier.weight(1f),
            )
            person.averageRating?.let {
                RatingChip(it.toInt())
            }
        }

        // The engine's own sentences, so a person reads the same on both
        // platforms.
        Text(People.line(person, now), style = TypeScale.secondary, color = colors.textSecondary)
        People.balance(person, ounces)?.let {
            Text(it, style = TypeScale.secondary, color = colors.accent)
        }
        People.taste(person)?.let {
            Text(it, style = TypeScale.caption, color = colors.textMuted)
        }

        if (person.received.isNotEmpty()) {
            SectionLabel("From them")
            for (sample in person.received.take(4)) {
                ExchangeRow(
                    sample.bottle,
                    VolumeDisplay.text(sample.milliliters, ounces),
                    shortDate(sample.at.toEpochMilli()),
                )
            }
        }
        if (person.given.isNotEmpty()) {
            SectionLabel("To them")
            for (pour in person.given.take(4)) {
                ExchangeRow(
                    pour.bottle,
                    VolumeDisplay.text(pour.milliliters, ounces),
                    shortDate(pour.at.toEpochMilli()),
                )
            }
        }
    }
}

@OptIn(ExperimentalLayoutApi::class)
@Composable
private fun ExchangeRow(bottle: String, volume: String, date: String) {
    val colors = palette
    // The bottle first and at full width, the amount and date after it when
    // they fit and on the next line when they do not. As three columns, the
    // amount and date took their whole width and left the name what was
    // over: at a large text size "Elijah Craig Barrel Proof" stood one word
    // to a line.
    FlowRow(
        modifier = Modifier.fillMaxWidth(),
        horizontalArrangement = Arrangement.SpaceBetween,
        verticalArrangement = Arrangement.spacedBy(2.dp),
    ) {
        Text(
            bottle,
            style = TypeScale.secondary,
            color = colors.text,
            modifier = Modifier.padding(end = Space.s),
        )
        Row(
            horizontalArrangement = Arrangement.spacedBy(Space.s),
            verticalAlignment = Alignment.CenterVertically,
        ) {
            Text(volume, style = TypeScale.code, color = colors.textSecondary)
            Text(date, style = TypeScale.caption, color = colors.textMuted)
        }
    }
}
