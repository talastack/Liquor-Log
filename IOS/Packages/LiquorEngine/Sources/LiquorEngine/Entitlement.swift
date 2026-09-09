import Foundation

/// The free/Pro split.
///
/// **Rewritten against the market research.** The first version of this file
/// was written in Phase 0, before any of it, and it got the split backwards in
/// five places: it capped free accounts at 25 bottles, and it charged for CSV
/// export, the oxidation clock, the price check and perceived proof.
///
/// Every one of those is now free, and the reasons are worth keeping:
///
/// **Export is never charged for.** *"Never charge for export. It costs you
/// almost nothing and it is the single strongest trust signal in a category
/// where people have been burned."* Paywalling it is cited by name as a reason
/// people abandoned OnlyDrams.
///
/// **Bottles are unlimited.** The stated threshold for needing this kind of app
/// at all is around fifty bottles, so a 25-bottle cap locked out exactly the
/// people it is for. *"Free unlimited bottles alone beats Whiskey Shelf (about
/// $80/yr for 499 bottles) and Barrelbook (10-bottle free cap)."*
///
/// **The differentiators are free.** The oxidation clock is a capability
/// essentially no app has, and the barrel fields are the wedge this whole
/// product turns on. Hiding them behind a paywall means nobody ever discovers
/// the reason to switch.
///
/// **You are never charged for your own data back.** The price check runs on
/// prices the user recorded themselves. Charging to see those is the same move
/// as charging for export, and it reads the same way.
///
/// What remains chargeable is the list the research calls tolerable: *"multi-
/// device sync and cloud backup, the insurance/estate PDF report, valuation
/// history, and a shareable public menu. These are the things where paying
/// feels like paying for a service rather than for your own data back."*
///
/// One more constraint from §8: **price does not scale with collection size.**
/// CellarTracker's most engaged users call that "opportunistic", and it
/// punishes exactly the people worth having.
public enum Tier: String, Sendable, CaseIterable, Codable {
    case free
    case pro
}

public enum Feature: String, Sendable, CaseIterable, Codable {
    // MARK: Free, permanently, and said so on the store page

    /// The home tab. Never gated — it is the reason to open the app, and one
    /// that will not say whether you own the bottle in your hand is not worth
    /// installing to find out.
    case shelfCheck
    case bottleCollection
    case pourLogging
    case fillLevel
    case tastingNotes
    case flavorWheel
    case wishlist
    /// The barrel fields. THE WEDGE — gating it would hide the only reason to
    /// choose this app over a free incumbent with 56,000 bottles.
    case barrelDetail
    case pickCompare
    /// Essentially no app has this. A differentiator nobody can discover is
    /// not a differentiator.
    case oxidationTracking
    case perceivedProof
    /// Runs on prices the user recorded. Charging for it is charging for their
    /// own data back.
    case priceCheck
    /// Never, ever charged for.
    case csvExport
    case labelScanning
    case shelfWalk
    case pickMyPour
    case collectionStats
    /// Sharing the text of what is open. The HOSTED version is the paid one.
    case guestMenu
    /// Notes the user wrote. Searching your own writing is not a service, and
    /// charging for it fails the same test that moved export to free.
    case knowledgeBase

    // MARK: Pro — services, not your own data

    case cloudSync
    case insuranceReport
    /// A link somebody else can open, rather than text you paste.
    case hostedMenu
}

public enum Entitlement: Sendable {

    /// Bottles a free account may hold.
    ///
    /// **Nil. Unlimited, for everybody.** Free is not a differentiator here —
    /// OnlyDrams is already free with 56,000 bottles catalogued — so a cap
    /// buys nothing and costs the users who most need the app. You cannot
    /// out-free a free incumbent; you can only out-fit it.
    public static func bottleLimit(for tier: Tier) -> Int? {
        switch tier {
        case .free, .pro: return nil
        }
    }

    /// Exhaustive, with no `default`. Adding a `Feature` is a compile error
    /// until somebody decides which tier it belongs to, rather than silently
    /// landing in free — or worse, silently landing behind the paywall.
    public static func isAvailable(_ feature: Feature, in tier: Tier) -> Bool {
        switch tier {
        case .pro:
            return true
        case .free:
            switch feature {
            case .shelfCheck, .bottleCollection, .pourLogging, .fillLevel,
                 .tastingNotes, .flavorWheel, .wishlist, .barrelDetail,
                 .pickCompare, .oxidationTracking, .perceivedProof, .priceCheck,
                 .csvExport, .labelScanning, .shelfWalk, .pickMyPour,
                 .collectionStats, .guestMenu, .knowledgeBase:
                return true
            case .cloudSync, .insuranceReport, .hostedMenu:
                return false
            }
        }
    }

    /// Order the comparison table renders in. An array, so the compiler cannot
    /// catch a feature missing from it — which is exactly how something ends up
    /// gated in code and absent from the table. `EntitlementTests` asserts it
    /// covers every case.
    public static let displayOrder: [Feature] = [
        .shelfCheck,
        .bottleCollection,
        .barrelDetail,
        .pourLogging,
        .fillLevel,
        .oxidationTracking,
        .tastingNotes,
        .flavorWheel,
        .perceivedProof,
        .pickCompare,
        .priceCheck,
        .wishlist,
        .shelfWalk,
        .pickMyPour,
        .collectionStats,
        .labelScanning,
        .guestMenu,
        .knowledgeBase,
        .csvExport,
        .cloudSync,
        .insuranceReport,
        .hostedMenu,
    ]

    /// User-facing label, kept beside the tier mapping so the paywall copy and
    /// the gate cannot describe different things.
    public static func title(for feature: Feature) -> String {
        switch feature {
        case .shelfCheck: return "Do I already own this?"
        case .bottleCollection: return "Unlimited bottles"
        case .barrelDetail: return "Barrel, batch, rick and pick details"
        case .pourLogging: return "Pour tracking"
        case .fillLevel: return "How much is left"
        case .oxidationTracking: return "How an open bottle is holding up"
        case .tastingNotes: return "Tasting notes"
        case .flavorWheel: return "The full flavour wheel"
        case .perceivedProof: return "Does it drink its proof"
        case .pickCompare: return "Compare a pick to the standard release"
        case .priceCheck: return "What you have paid before"
        case .wishlist: return "Wishlist"
        case .shelfWalk: return "Shelf walk"
        case .pickMyPour: return "Pick my pour"
        case .collectionStats: return "Your collection at a glance"
        case .labelScanning: return "Scan a label"
        case .guestMenu: return "Share what's open"
        case .csvExport: return "Export everything, always free"
        case .cloudSync: return "Sync across your devices"
        case .insuranceReport: return "Insurance and estate report"
        case .hostedMenu: return "A shareable menu link"
        case .knowledgeBase: return "Your own notes, searchable"
        }
    }

    /// Why a Pro feature costs money, in one line.
    ///
    /// Nil for free features. Every one of these is a SERVICE with an ongoing
    /// cost behind it, which is the test the research sets for what people
    /// tolerate paying for.
    public static func reason(for feature: Feature) -> String? {
        switch feature {
        case .cloudSync:
            return "Storage and a server, running whether you open the app or not."
        case .insuranceReport:
            return "A document you can hand to an insurer or an executor."
        case .hostedMenu:
            return "A page hosted for you, that guests open without the app."
        default:
            return nil
        }
    }
}
