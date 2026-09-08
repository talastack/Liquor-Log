import Foundation

/// The free/Pro split.
///
/// Designed in Phase 0 even though the paywall does not ship until Phase 4,
/// because gating is the thing that is expensive to retrofit: a screen built
/// with no notion of tier acquires one by being rewritten.
///
/// Every mapping below is an **exhaustive switch with no `default`**. Adding a
/// `Feature` is then a compile error until somebody decides which tier it
/// belongs to, rather than silently defaulting to free.
public enum Tier: String, Sendable, CaseIterable, Codable {
    case free
    case pro
}

public enum Feature: String, Sendable, CaseIterable, Codable {
    /// The home tab. Never gated -- it is the reason to open the app, and an app
    /// that will not tell you whether you already own the bottle in your hand is
    /// not worth installing to find out.
    case shelfCheck
    case bottleCollection
    case pourLogging
    case tastingNotes
    case wishlist
    case flavorWheel
    case pickCompare
    case oxidationTracking
    case beerFreshness
    case priceCheck
    case perceivedProof
    case cloudSync
    case csvExport
    case knowledgeBase
}

public enum Entitlement: Sendable {

    /// Bottles a free account may hold. Nil means unlimited.
    ///
    /// A cap rather than a feature lock, because a collection app that refuses to
    /// show you your own data is hostile. The free tier is a real app for someone
    /// with a small shelf.
    public static func bottleLimit(for tier: Tier) -> Int? {
        switch tier {
        case .free: return 25
        case .pro: return nil
        }
    }

    public static func isAvailable(_ feature: Feature, in tier: Tier) -> Bool {
        switch tier {
        case .pro:
            return true
        case .free:
            switch feature {
            case .shelfCheck, .bottleCollection, .pourLogging, .tastingNotes, .wishlist:
                return true
            case .flavorWheel, .pickCompare, .oxidationTracking, .beerFreshness,
                 .priceCheck, .perceivedProof, .cloudSync, .csvExport, .knowledgeBase:
                return false
            }
        }
    }

    /// Order the paywall comparison table renders in.
    ///
    /// This is an array, so the compiler cannot catch a feature missing from it --
    /// which is precisely how a feature ends up absent from the comparison table
    /// while being gated in code. `EntitlementTests` asserts it covers every case.
    public static let displayOrder: [Feature] = [
        .shelfCheck,
        .bottleCollection,
        .pourLogging,
        .tastingNotes,
        .wishlist,
        .flavorWheel,
        .pickCompare,
        .perceivedProof,
        .oxidationTracking,
        .beerFreshness,
        .priceCheck,
        .cloudSync,
        .csvExport,
        .knowledgeBase
    ]

    /// User-facing label. Kept beside the tier mapping so the paywall copy and
    /// the gate cannot describe different things.
    public static func title(for feature: Feature) -> String {
        switch feature {
        case .shelfCheck: return "Shelf check"
        case .bottleCollection: return "Your collection"
        case .pourLogging: return "Pour tracking"
        case .tastingNotes: return "Tasting notes"
        case .wishlist: return "Wishlist"
        case .flavorWheel: return "Full flavour wheel"
        case .pickCompare: return "Compare a pick to the standard release"
        case .oxidationTracking: return "How long an open bottle has left"
        case .beerFreshness: return "Beer drink-by dates"
        case .priceCheck: return "Price against retail"
        case .perceivedProof: return "Does it drink its proof"
        case .cloudSync: return "Backup and sync"
        case .csvExport: return "Export your data"
        case .knowledgeBase: return "Your own notes, searchable"
        }
    }
}
