package com.talastack.liquorlog.engine

/**
 * Where a flavour comes from.
 *
 * This is the axis the whole wheel is organised on, and it is a chemical and
 * process fact rather than an aesthetic judgement -- which is what makes the
 * taxonomy independently derived rather than a copy of a published wheel's
 * arrangement. See `docs/06-flavour-wheel-provenance.md`.
 *
 * It also earns its place at runtime: [OxidationBand] reasons about what
 * changes in an open bottle, and [OXIDATION] notes are exactly the ones that
 * arrive while [MATURATION] notes flatten.
 */
enum class FlavorOrigin(val storageKey: String) {
    GRAIN("grain"),
    FERMENTATION("fermentation"),
    DISTILLATION("distillation"),
    MATURATION("maturation"),
    OXIDATION("oxidation"),
    FAULT("fault");

    val label: String
        get() = when (this) {
            GRAIN -> "From the grain"
            FERMENTATION -> "From the ferment"
            DISTILLATION -> "From the still"
            MATURATION -> "From the barrel"
            OXIDATION -> "From air and time"
            FAULT -> "Something went wrong"
        }

    /** True for origins that mark a flaw rather than a characteristic. */
    val isUndesirable: Boolean get() = this == FAULT

    companion object {
        /**
         * Null for a word this engine does not know. Swift gets the same
         * refusal from a failed decode: a silently defaulted origin would put
         * a descriptor in the wrong place, so the data layer must treat null
         * as a broken file rather than pick one.
         */
        fun fromStorageKey(key: String): FlavorOrigin? =
            entries.firstOrNull { it.storageKey == key }
    }
}

/** One thing you can taste. */
data class FlavorDescriptor(
    val key: String,
    val label: String,
    val origin: FlavorOrigin,
    /**
     * The sub-group inside its family: "Citrus" within Fruit, "Peat" within
     * Smoke.
     *
     * PRESENTATIONAL ONLY, and free to be renamed. A flat list of 250 words
     * is unusable on a phone -- nobody opening "Fruit" wants to pass forty
     * entries to reach "Lemon". The [key] is what a tasting note stores and
     * that can never change.
     */
    val group: String? = null,
    /**
     * The compound responsible, where it is well established. Not shown in
     * the UI until each attribution carries a citation.
     */
    val compound: String? = null,
    /** A short plain-language note on why the flavour is there. */
    val why: String? = null
) {
    val id: String get() = key
}

/**
 * A sub-group inside a family: "Citrus" within Fruit.
 *
 * Derived from the descriptors rather than stored, so the data file stays a
 * flat list and a descriptor can be moved between groups by editing one
 * field.
 */
data class FlavorGroup(val name: String, val descriptors: List<FlavorDescriptor>) {
    val id: String get() = name
}

data class FlavorFamily(
    val key: String,
    val label: String,
    val descriptors: List<FlavorDescriptor>
) {
    val id: String get() = key

    /**
     * Descriptors in their sub-groups, in the order the data declares them.
     *
     * Order is taken from first appearance rather than sorted: the groups run
     * from the most common note to the least within each family, and
     * alphabetising them would bury "Caramel" under "Chocolate".
     */
    val groups: List<FlavorGroup>
        get() {
            val buckets = LinkedHashMap<String, MutableList<FlavorDescriptor>>()
            for (descriptor in descriptors) {
                val name = descriptor.group ?: label
                buckets.getOrPut(name) { mutableListOf() }.add(descriptor)
            }
            return buckets.map { (name, members) -> FlavorGroup(name, members) }
        }
}

/**
 * The wheel, as `shared/data/flavor-wheel.v1.json` declares it.
 *
 * Swift decodes the file with JSONDecoder, which Foundation gives it for
 * nothing. This module carries no JSON dependency, so the Android data layer
 * parses the file and hands the families in. Everything that could drift
 * between the two engines -- the lookups, the grouping and the structural
 * rules -- is here.
 */
data class FlavorWheel(
    val version: Int,
    val name: String,
    val families: List<FlavorFamily>
) {

    val allDescriptors: List<FlavorDescriptor>
        get() = families.flatMap { it.descriptors }

    /**
     * A tasting note stores a descriptor KEY, so this is how a stored note
     * becomes something to show. Null for a key from a newer wheel version,
     * which the UI must render as the raw key rather than dropping silently
     * -- a note the user wrote should never vanish because the data moved on.
     */
    fun descriptor(key: String): FlavorDescriptor? =
        allDescriptors.firstOrNull { it.key == key }

    fun familyContaining(key: String): FlavorFamily? =
        families.firstOrNull { family -> family.descriptors.any { it.key == key } }

    fun descriptorsFrom(origin: FlavorOrigin): List<FlavorDescriptor> =
        allDescriptors.filter { it.origin == origin }

    data class Issue(val rule: String, val detail: String) {
        override fun toString(): String = "$rule: $detail"
    }

    /**
     * Structural rules. The shipped JSON is checked against these in CI, so a
     * data file with a duplicate key cannot reach a build.
     */
    fun validate(): List<Issue> {
        val issues = mutableListOf<Issue>()

        val seenDescriptors = mutableMapOf<String, Int>()
        for (descriptor in allDescriptors) {
            seenDescriptors[descriptor.key] = (seenDescriptors[descriptor.key] ?: 0) + 1
        }
        for ((key, count) in seenDescriptors.entries.sortedBy { it.key }) {
            if (count <= 1) continue
            issues.add(
                Issue(
                    rule = "descriptor.unique",
                    detail = "$key appears $count times; a stored note would be ambiguous"
                )
            )
        }

        val seenFamilies = mutableSetOf<String>()
        for (family in families) {
            if (!seenFamilies.add(family.key)) {
                issues.add(Issue(rule = "family.unique", detail = family.key))
            }
        }

        for (family in families) {
            if (family.descriptors.isEmpty()) {
                issues.add(
                    Issue(
                        rule = "family.notEmpty",
                        detail = "${family.key} has no descriptors and would render an empty tray"
                    )
                )
            }
        }

        for (descriptor in allDescriptors) {
            if (descriptor.label.trim { it == ' ' || it == '\t' }.isEmpty()) {
                issues.add(Issue(rule = "descriptor.hasLabel", detail = descriptor.key))
            }
            if (descriptor.key != descriptor.key.lowercase() || descriptor.key.contains(" ")) {
                issues.add(
                    Issue(
                        rule = "descriptor.keyIsStable",
                        detail = "${descriptor.key} must be lowercase and hyphenated: keys are " +
                            "stored in tasting notes and cannot change"
                    )
                )
            }
        }

        return issues
    }
}
