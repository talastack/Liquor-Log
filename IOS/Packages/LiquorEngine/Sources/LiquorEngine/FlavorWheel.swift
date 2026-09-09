import Foundation

/// Where a flavour comes from.
///
/// This is the axis the whole wheel is organised on, and it is a chemical and
/// process fact rather than an aesthetic judgement — which is what makes the
/// taxonomy independently derived rather than a copy of a published wheel's
/// arrangement. See `docs/06-flavour-wheel-provenance.md`.
///
/// It also earns its place at runtime: `OxidationBand` reasons about what
/// changes in an open bottle, and `oxidation` notes are exactly the ones that
/// arrive while `maturation` notes flatten.
public enum FlavorOrigin: String, Codable, Sendable, Hashable, CaseIterable {
    case grain
    case fermentation
    case distillation
    case maturation
    case oxidation
    case fault

    public var label: String {
        switch self {
        case .grain: return "From the grain"
        case .fermentation: return "From the ferment"
        case .distillation: return "From the still"
        case .maturation: return "From the barrel"
        case .oxidation: return "From air and time"
        case .fault: return "Something went wrong"
        }
    }

    /// True for origins that mark a flaw rather than a characteristic.
    public var isUndesirable: Bool { self == .fault }
}

/// One thing you can taste.
public struct FlavorDescriptor: Codable, Sendable, Hashable, Identifiable {
    public let key: String
    public let label: String
    public let origin: FlavorOrigin

    /// The sub-group inside its family: "Citrus" within Fruit, "Peat" within
    /// Smoke.
    ///
    /// PRESENTATIONAL ONLY, and free to be renamed. A flat list of 250 words is
    /// unusable on a phone -- nobody opening "Fruit" wants to pass forty
    /// entries to reach "Lemon". The `key` is what a tasting note stores and
    /// that can never change.
    public let group: String?
    /// The compound responsible, where it is well established. Not shown in the
    /// UI until each attribution carries a citation.
    public let compound: String?
    /// A short plain-language note on why the flavour is there.
    public let why: String?

    public var id: String { key }

    public init(
        key: String, label: String, origin: FlavorOrigin,
        group: String? = nil, compound: String? = nil, why: String? = nil
    ) {
        self.key = key; self.label = label; self.origin = origin
        self.group = group; self.compound = compound; self.why = why
    }
}

/// A sub-group inside a family: "Citrus" within Fruit.
///
/// Derived from the descriptors rather than stored, so the data file stays a
/// flat list and a descriptor can be moved between groups by editing one field.
public struct FlavorGroup: Sendable, Hashable, Identifiable {
    public let name: String
    public let descriptors: [FlavorDescriptor]

    public var id: String { name }

    public init(name: String, descriptors: [FlavorDescriptor]) {
        self.name = name
        self.descriptors = descriptors
    }
}

public struct FlavorFamily: Codable, Sendable, Hashable, Identifiable {
    public let key: String
    public let label: String
    public let descriptors: [FlavorDescriptor]

    public var id: String { key }

    public init(key: String, label: String, descriptors: [FlavorDescriptor]) {
        self.key = key; self.label = label; self.descriptors = descriptors
    }

    /// Descriptors in their sub-groups, in the order the data declares them.
    ///
    /// Order is taken from first appearance rather than sorted: the groups run
    /// from the most common note to the least within each family, and
    /// alphabetising them would bury "Caramel" under "Chocolate".
    ///
    /// A named type rather than a tuple because Swift has no key path into a
    /// tuple element, and `ForEach(groups, id: \.name)` is exactly what the
    /// picker needs to do with this.
    public var groups: [FlavorGroup] {
        var order: [String] = []
        var buckets: [String: [FlavorDescriptor]] = [:]
        for descriptor in descriptors {
            let name = descriptor.group ?? label
            if buckets[name] == nil { order.append(name) }
            buckets[name, default: []].append(descriptor)
        }
        return order.map { FlavorGroup(name: $0, descriptors: buckets[$0] ?? []) }
    }
}

/// The wheel, loaded from `shared/data/flavor-wheel.v1.json`.
///
/// Decoded from `Data` rather than a bundle so the engine keeps no dependency
/// on Foundation's resource machinery and stays testable on any machine. The
/// app hands it the file contents.
public struct FlavorWheel: Codable, Sendable, Hashable {
    public let version: Int
    public let name: String
    public let families: [FlavorFamily]

    private enum CodingKeys: String, CodingKey {
        case version, name, families
    }

    public init(version: Int, name: String, families: [FlavorFamily]) {
        self.version = version; self.name = name; self.families = families
    }

    public static func decode(from data: Data) throws -> FlavorWheel {
        try JSONDecoder().decode(FlavorWheel.self, from: data)
    }

    // MARK: - Lookup

    public var allDescriptors: [FlavorDescriptor] {
        families.flatMap(\.descriptors)
    }

    /// A tasting note stores a descriptor KEY, so this is how a stored note
    /// becomes something to show. Nil for a key from a newer wheel version,
    /// which the UI must render as the raw key rather than dropping silently —
    /// a note the user wrote should never vanish because the data moved on.
    public func descriptor(_ key: String) -> FlavorDescriptor? {
        allDescriptors.first { $0.key == key }
    }

    public func family(containing key: String) -> FlavorFamily? {
        families.first { $0.descriptors.contains { $0.key == key } }
    }

    public func descriptors(from origin: FlavorOrigin) -> [FlavorDescriptor] {
        allDescriptors.filter { $0.origin == origin }
    }

    // MARK: - Validation

    public struct Issue: Hashable, Sendable, CustomStringConvertible {
        public let rule: String
        public let detail: String
        public var description: String { "\(rule): \(detail)" }
    }

    /// Structural rules. The shipped JSON is checked against these in CI, so a
    /// data file with a duplicate key cannot reach a build.
    public func validate() -> [Issue] {
        var issues: [Issue] = []

        var seenDescriptors: [String: Int] = [:]
        for descriptor in allDescriptors {
            seenDescriptors[descriptor.key, default: 0] += 1
        }
        for (key, count) in seenDescriptors.sorted(by: { $0.key < $1.key }) where count > 1 {
            issues.append(Issue(
                rule: "descriptor.unique",
                detail: "\(key) appears \(count) times; a stored note would be ambiguous"))
        }

        var seenFamilies: Set<String> = []
        for family in families where !seenFamilies.insert(family.key).inserted {
            issues.append(Issue(rule: "family.unique", detail: family.key))
        }

        for family in families where family.descriptors.isEmpty {
            issues.append(Issue(
                rule: "family.notEmpty",
                detail: "\(family.key) has no descriptors and would render an empty tray"))
        }

        for descriptor in allDescriptors {
            if descriptor.label.trimmingCharacters(in: .whitespaces).isEmpty {
                issues.append(Issue(rule: "descriptor.hasLabel", detail: descriptor.key))
            }
            if descriptor.key != descriptor.key.lowercased()
                || descriptor.key.contains(" ") {
                issues.append(Issue(
                    rule: "descriptor.keyIsStable",
                    detail: "\(descriptor.key) must be lowercase and hyphenated: keys are "
                        + "stored in tasting notes and cannot change"))
            }
        }

        return issues
    }
}
