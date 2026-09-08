import XCTest
@testable import LiquorEngine

/// The two numbers this whole design is pinned to: a 750 ml bottle gives 17
/// pours and a 700 ml gives 16. Only a 1.5 oz pour rounded to nearest satisfies
/// both, so these two tests are load-bearing -- if either changes, the constant
/// or the rounding rule changed with it.
final class PourMathTests: XCTestCase {

    func testFullSevenFiftyReadsSeventeenOfSeventeen() {
        let status = PourMath.status(capacityMilliliters: 750, pouredMilliliters: 0)
        XCTAssertEqual(status.totalPours, 17)
        XCTAssertEqual(status.remainingPours, 17, "a full bottle must not read 16 of 17")
    }

    func testFullSevenHundredReadsSixteenOfSixteen() {
        let status = PourMath.status(capacityMilliliters: 700, pouredMilliliters: 0)
        XCTAssertEqual(status.totalPours, 16)
        XCTAssertEqual(status.remainingPours, 16)
    }

    /// The plan's end-to-end acceptance case, at the unit level.
    func testFourPoursFromSevenFiftyReadsThirteenOfSeventeen() {
        let poured = 4 * PourSize.standard.milliliters
        let status = PourMath.status(capacityMilliliters: 750, pouredMilliliters: poured)
        XCTAssertEqual(status.remainingPours, 13)
        XCTAssertEqual(status.totalPours, 17, "the denominator is capacity, not what is left")
    }

    func testStandardPourIsFortyFourPointThreeSixMilliliters() {
        XCTAssertEqual(PourSize.standard.milliliters, 44.36, accuracy: 0.01)
    }

    /// Enough for a pour once rounded, so it reports one rather than none.
    func testThirtyMillilitresRemainingReadsOnePour() {
        let status = PourMath.status(capacityMilliliters: 750, pouredMilliliters: 720)
        XCTAssertEqual(status.remainingPours, 1)
        XCTAssertFalse(status.hasPartialPourOnly)
        XCTAssertEqual(status.remainingMilliliters, 30, accuracy: 0.001)
    }

    /// Liquid left, but not enough to round to a pour. The UI must say "less
    /// than a pour" rather than "0", which reads as empty.
    func testTenMillilitresIsAPartialPourNotEmpty() {
        let status = PourMath.status(capacityMilliliters: 750, pouredMilliliters: 740)
        XCTAssertEqual(status.remainingPours, 0)
        XCTAssertTrue(status.hasPartialPourOnly)
        XCTAssertFalse(status.isEmpty)
    }

    /// Over-pouring past empty is a logging mistake, not a bottle that owes you.
    func testOverPouringClampsAtEmpty() {
        let status = PourMath.status(capacityMilliliters: 750, pouredMilliliters: 900)
        XCTAssertEqual(status.remainingMilliliters, 0)
        XCTAssertEqual(status.remainingPours, 0)
        XCTAssertTrue(status.isEmpty)
        XCTAssertFalse(status.hasPartialPourOnly)
    }

    /// Divided by the count the user is shown, so the arithmetic checks out in
    /// their head: 60 dollars across 17 pours.
    func testCostPerPourUsesTheDisplayedCount() {
        let cents = PourMath.costPerPourCents(
            priceCents: 6000,
            capacityMilliliters: 750,
            pourSize: .standard
        )
        XCTAssertEqual(cents, 353)
    }

    func testCostPerPourIsNilWithoutAPrice() {
        XCTAssertNil(PourMath.costPerPourCents(
            priceCents: 0, capacityMilliliters: 750, pourSize: .standard
        ))
    }

    func testCustomPourSizeChangesTheCount() {
        let double = PourSize(usFluidOunces: 3.0)
        XCTAssertEqual(PourMath.pourCount(milliliters: 750, pourSize: double), 8)
    }
}
