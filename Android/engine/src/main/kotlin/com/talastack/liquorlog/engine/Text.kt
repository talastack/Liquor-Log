package com.talastack.liquorlog.engine

import java.text.Normalizer

/**
 * Folding a name down to what it can be matched on: lowercase, no accents,
 * punctuation gone, single spaces.
 *
 * "Blanton's Single Barrel" and "blantons single barrel" are the same query,
 * and a search that disagreed would fail exactly where a person is standing
 * in a shop typing fast.
 *
 * Swift gets this from `folding(options: .diacriticInsensitive)`; the JVM
 * equivalent is NFD normalisation followed by dropping the combining marks,
 * which is what that option does underneath.
 */
fun String.normalizedForMatching(): String =
    Normalizer.normalize(this, Normalizer.Form.NFD)
        .replace(COMBINING_MARKS, "")
        .lowercase()
        .split(NON_ALPHANUMERIC)
        .filter { it.isNotEmpty() }
        .joinToString(" ")

val String.matchTokens: List<String>
    get() = normalizedForMatching().split(" ").filter { it.isNotEmpty() }

/** Unicode combining marks: what NFD separates an accent into. */
private val COMBINING_MARKS = Regex("\\p{Mn}+")

/**
 * Anything that is not a letter or a digit, in any language -- not `\\W`,
 * which is ASCII-minded and would shred a name that is legitimately not.
 */
private val NON_ALPHANUMERIC = Regex("[^\\p{IsAlphabetic}\\p{IsDigit}]+")
