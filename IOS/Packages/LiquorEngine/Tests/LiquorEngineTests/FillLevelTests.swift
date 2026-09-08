import XCTest
@testable import LiquorEngine

final class FillLevelTests: XCTestCase {

    func testFullBottleHasNoHeadroom() {
        let level = FillLevel(remainingMilliliters: 750, capacityMilliliters: 750)
        XCTAssertEqual(level.fraction, 1.0, accuracy: 0.0001)
        XCTAssertEqual(level.headroomFraction, 0.0, accuracy: 0.0001)
        XCTAssertEqual(level.headroom, .minimal)
    }

    /// The case the oxidation model actually cares about: a quarter-full bottle
    /// is mostly air, and fades on a different schedule from a full one opened
    /// the same day.
    func testQuarterFullBottleIsMostlyAir() {
        let level = FillLevel(remainingMilliliters: 187.5, capacityMilliliters: 750)
        XCTAssertEqual(level.headroomFraction, 0.75, accuracy: 0.0001)
        XCTAssertEqual(level.headroom, .high)
    }

    func testHalfFullIsModerateHeadroom() {
        let level = FillLevel(remainingMilliliters: 375, capacityMilliliters: 750)
        XCTAssertEqual(level.headroom, .moderate)
    }

    /// The heel of the bottle, which is where oxidation actually bites.
    func testHeelOfTheBottleIsSevere() {
        let level = FillLevel(remainingMilliliters: 75, capacityMilliliters: 750)
        XCTAssertEqual(level.headroomFraction, 0.90, accuracy: 0.0001)
        XCTAssertEqual(level.headroom, .severe)
    }

    func testFractionIsClampedToTheBottle() {
        let over = FillLevel(remainingMilliliters: 900, capacityMilliliters: 750)
        XCTAssertEqual(over.fraction, 1.0, accuracy: 0.0001)

        let under = FillLevel(remainingMilliliters: -50, capacityMilliliters: 750)
        XCTAssertEqual(under.fraction, 0.0, accuracy: 0.0001)
    }

    func testZeroCapacityDoesNotDivideByZero() {
        let level = FillLevel(remainingMilliliters: 0, capacityMilliliters: 0)
        XCTAssertEqual(level.fraction, 0)
        XCTAssertEqual(level.headroomFraction, 1)
    }
}
