import XCTest
@testable import LiquorEngine

final class EntitlementTests: XCTestCase {

    /// `displayOrder` is an array, so the compiler cannot catch a feature
    /// missing from it -- and a feature missing from it is silently absent from
    /// the paywall comparison table while still being gated in code. This test
    /// is the only thing standing between that and a shipped build.
    func testDisplayOrderCoversEveryFeature() {
        XCTAssertEqual(
            Set(Entitlement.displayOrder),
            Set(Feature.allCases),
            "a Feature is missing from displayOrder, or listed twice"
        )
        XCTAssertEqual(
            Entitlement.displayOrder.count,
            Feature.allCases.count,
            "displayOrder contains a duplicate"
        )
    }

    func testEveryFeatureHasATitle() {
        for feature in Feature.allCases {
            XCTAssertFalse(Entitlement.title(for: feature).isEmpty, "\(feature) has no title")
        }
    }

    func testProGetsEverything() {
        for feature in Feature.allCases {
            XCTAssertTrue(Entitlement.isAvailable(feature, in: .pro), "\(feature) gated from pro")
        }
    }

    /// The reason to open the app. An app that will not tell you whether you
    /// already own the bottle in your hand is not worth installing to find out.
    func testShelfCheckIsNeverGated() {
        XCTAssertTrue(Entitlement.isAvailable(.shelfCheck, in: .free))
    }

    /// A collection app that refuses to show you your own data is hostile, so
    /// the free tier logs bottles, pours and tastings -- it is capped, not
    /// crippled.
    func testFreeTierCanActuallyUseTheApp() {
        XCTAssertTrue(Entitlement.isAvailable(.bottleCollection, in: .free))
        XCTAssertTrue(Entitlement.isAvailable(.pourLogging, in: .free))
        XCTAssertTrue(Entitlement.isAvailable(.tastingNotes, in: .free))
        XCTAssertTrue(Entitlement.isAvailable(.wishlist, in: .free))
    }

    func testFreeTierIsCapped() {
        XCTAssertEqual(Entitlement.bottleLimit(for: .free), 25)
        XCTAssertNil(Entitlement.bottleLimit(for: .pro))
    }

    func testSyncAndExportArePaid() {
        XCTAssertFalse(Entitlement.isAvailable(.cloudSync, in: .free))
        XCTAssertFalse(Entitlement.isAvailable(.csvExport, in: .free))
    }
}
