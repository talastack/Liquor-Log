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

    /// The global range is a coarse sanity check and nothing more. It
    /// deliberately accepts 6.26%, because that is an ordinary beer -- and no
    /// range that admits beer can also reject a bourbon typed as 6.26 when 62.6
    /// was meant.
    func testPlausibleRangeIsCoarseAndAcceptsBeerStrengths() {
        XCTAssertTrue(ABV(percent: 6.26).isPlausible)
        XCTAssertTrue(ABV(percent: 62.6).isPlausible)
        XCTAssertFalse(ABV(percent: 0).isPlausible)
        XCTAssertFalse(ABV(percent: 120).isPlausible)
    }

    /// So the decimal slip is caught by class, not by range: a bourbon has a
    /// 40% floor and 6.26 falls straight through it. Worth stating as a test
    /// because the obvious assumption -- that a range catches typos -- is wrong
    /// here, and acting on it would leave the slip unguarded.
    func testBourbonMistypedAsSixPointTwoSixIsCaughtByClassNotRange() {
        let issues = Classification.validate(
            classType: .kentuckyStraightBourbon,
            abv: ABV(percent: 6.26),
            statedAgeYears: 8,
            isBottledInBond: false,
            volumeMilliliters: 750
        )
        XCTAssertTrue(issues.contains { $0.rule == "abv.americanMinimum" })
    }

    func testStandardsOfFillAcceptTheCommonSizes() {
        XCTAssertTrue(Volume.isStandardFill(milliliters: 750))
        XCTAssertTrue(Volume.isStandardFill(milliliters: 700))
        XCTAssertTrue(Volume.isStandardFill(milliliters: 375))
        XCTAssertFalse(Volume.isStandardFill(milliliters: 733))
    }
}
