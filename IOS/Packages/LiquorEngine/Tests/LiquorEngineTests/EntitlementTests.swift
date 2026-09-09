import XCTest
@testable import LiquorEngine

/// The paywall, and mostly what must never be behind it.
///
/// These are not structural tests. Each one pins a decision the research is
/// explicit about, so that a future "let's gate one more thing" has to argue
/// with a failing test rather than slip through a diff.
final class EntitlementTests: XCTestCase {

    /// `displayOrder` is an array, so the compiler cannot catch a feature
    /// missing from it — which is precisely how something ends up gated in code
    /// and absent from the comparison table.
    func testDisplayOrderCoversEveryFeatureExactlyOnce() {
        XCTAssertEqual(
            Set(Feature.allCases),
            Set(Entitlement.displayOrder),
            "a Feature is missing from displayOrder, or listed twice")
        XCTAssertEqual(
            Feature.allCases.count,
            Entitlement.displayOrder.count,
            "displayOrder contains a duplicate")
    }

    func testEveryFeatureHasALabel() {
        for feature in Feature.allCases {
            XCTAssertFalse(
                Entitlement.title(for: feature).isEmpty,
                "\(feature) would render as a blank row")
        }
    }

    func testProHasEverything() {
        for feature in Feature.allCases {
            XCTAssertTrue(Entitlement.isAvailable(feature, in: .pro), "\(feature) gated from pro")
        }
    }

    // MARK: - What must never be paid

    /// *"Never charge for export. It costs you almost nothing and it is the
    /// single strongest trust signal in a category where people have been
    /// burned."* Paywalling it is named as a reason people left OnlyDrams.
    func testExportIsFreeForever() {
        XCTAssertTrue(Entitlement.isAvailable(.csvExport, in: .free))
    }

    /// You cannot out-free a free incumbent, and the threshold for needing this
    /// app at all is about fifty bottles — so a cap locks out the people it is
    /// for. The first version of this file capped free at 25.
    func testBottlesAreUnlimitedOnEveryTier() {
        for tier in Tier.allCases {
            XCTAssertNil(
                Entitlement.bottleLimit(for: tier),
                "\(tier) has a bottle cap; free unlimited is the price of entry here")
        }
    }

    /// The home tab. An app that will not say whether you own the bottle in
    /// your hand is not worth installing to find out.
    func testTheShelfCheckIsFree() {
        XCTAssertTrue(Entitlement.isAvailable(.shelfCheck, in: .free))
    }

    /// The wedge. Gating it hides the only reason to choose this over a free
    /// incumbent that already has 56,000 bottles catalogued.
    func testTheBarrelFieldsAreFree() {
        XCTAssertTrue(Entitlement.isAvailable(.barrelDetail, in: .free))
        XCTAssertTrue(Entitlement.isAvailable(.pickCompare, in: .free))
    }

    /// A differentiator nobody can discover is not a differentiator. Section 6
    /// calls the oxidation clock "wide open" — essentially no app has it.
    func testTheDifferentiatorsAreFree() {
        XCTAssertTrue(Entitlement.isAvailable(.oxidationTracking, in: .free))
        XCTAssertTrue(Entitlement.isAvailable(.perceivedProof, in: .free))
        XCTAssertTrue(Entitlement.isAvailable(.fillLevel, in: .free))
    }

    /// The price check runs on prices the user recorded, and the knowledge base
    /// is their own writing. Charging for either is charging for their own data
    /// back, which is the same move as paywalling export.
    func testYourOwnDataIsNeverBehindThePaywall() {
        XCTAssertTrue(Entitlement.isAvailable(.priceCheck, in: .free))
        XCTAssertTrue(Entitlement.isAvailable(.knowledgeBase, in: .free))
        XCTAssertTrue(Entitlement.isAvailable(.tastingNotes, in: .free))
        XCTAssertTrue(Entitlement.isAvailable(.bottleCollection, in: .free))
    }

    /// Scanning behind a paywall is cited by name for Distiller and Vivino:
    /// *"Putting the scanning behind a pay wall is kind of lame."*
    func testScanningIsFree() {
        XCTAssertTrue(Entitlement.isAvailable(.labelScanning, in: .free))
    }

    // MARK: - What may be paid

    /// The whole of Pro, and the test that keeps it honest: every paid feature
    /// must be a SERVICE with an ongoing cost, never a piece of the user's own
    /// data withheld.
    func testEveryPaidFeatureIsAServiceAndSaysWhy() {
        let paid = Feature.allCases.filter { !Entitlement.isAvailable($0, in: .free) }

        XCTAssertEqual(
            Set(paid), [.cloudSync, .insuranceReport, .hostedMenu],
            "the paid list changed -- is the new one a service, or somebody's own data?")

        for feature in paid {
            XCTAssertNotNil(
                Entitlement.reason(for: feature),
                "\(feature) is charged for with no stated reason")
        }
    }

    func testFreeFeaturesGiveNoReasonToPay() {
        for feature in Feature.allCases where Entitlement.isAvailable(feature, in: .free) {
            XCTAssertNil(
                Entitlement.reason(for: feature),
                "\(feature) is free but carries paywall copy")
        }
    }

    /// Most of the app is free, and by a wide margin. If this ever fails,
    /// something has been quietly moved behind the paywall.
    func testTheOverwhelmingMajorityOfTheAppIsFree() {
        let free = Feature.allCases.filter { Entitlement.isAvailable($0, in: .free) }
        XCTAssertGreaterThan(
            Double(free.count) / Double(Feature.allCases.count), 0.8,
            "less than four fifths of the app is free")
    }
}
