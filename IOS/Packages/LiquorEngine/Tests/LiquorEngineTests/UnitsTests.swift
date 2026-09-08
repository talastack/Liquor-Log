import XCTest
@testable import LiquorEngine

final class UnitsTests: XCTestCase {

    /// The number from the original notes: 62.6% ABV is 125.2 proof.
    func testProofIsTwiceABV() {
        XCTAssertEqual(ABV(percent: 62.6).proof, 125.2, accuracy: 0.0001)
        XCTAssertEqual(ABV(proof: 125.2).percent, 62.6, accuracy: 0.0001)
    }

    func testProofRoundTrips() {
        let original = ABV(percent: 47.3)
        XCTAssertEqual(ABV(proof: original.proof).percent, original.percent, accuracy: 0.0001)
    }

    /// Catches the decimal slip: 6.26 typed where 62.6 was meant.
    func testImplausibleABVIsRejected() {
        XCTAssertFalse(ABV(percent: 6.26).isPlausible)
        XCTAssertTrue(ABV(percent: 62.6).isPlausible)
        XCTAssertFalse(ABV(percent: 0).isPlausible)
        XCTAssertFalse(ABV(percent: 120).isPlausible)
    }

    func testStandardsOfFillAcceptTheCommonSizes() {
        XCTAssertTrue(Volume.isStandardFill(milliliters: 750))
        XCTAssertTrue(Volume.isStandardFill(milliliters: 700))
        XCTAssertTrue(Volume.isStandardFill(milliliters: 375))
        XCTAssertFalse(Volume.isStandardFill(milliliters: 733))
    }
}
