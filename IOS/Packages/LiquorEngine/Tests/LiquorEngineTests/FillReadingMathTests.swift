import XCTest
@testable import LiquorEngine

/// A bottle you opened two years ago is the normal case, not the exception.
/// These pin the arithmetic that lets somebody say so.
final class FillReadingMathTests: XCTestCase {

    // MARK: - Counting down from a reading

    /// With no reading the app assumes a full bottle, which is only true for
    /// one you opened after adding it.
    func testWithoutAReadingItCountsDownFromCapacity() {
        XCTAssertEqual(
            PourMath.remainingMilliliters(capacity: 750, poured: 100),
            650, accuracy: 0.001)
    }

    func testAReadingBecomesTheNewStartingPoint() {
        // Half a bottle observed, then two pours since.
        XCTAssertEqual(
            PourMath.remainingMilliliters(
                capacity: 750, poured: 88.72, startingFrom: 375),
            286.28, accuracy: 0.01)
    }

    /// The whole point: correcting a bottle must not rewrite the pour log, and
    /// pours from before the reading are already in what somebody saw.
    func testAReadingOverridesEverythingPouredBeforeIt() {
        // Nine pours logged historically, but the bottle is visibly still half
        // full. The reading wins; only pours after it count.
        let status = PourMath.status(
            capacityMilliliters: 750,
            pouredMilliliters: 0,
            startingMilliliters: 375)
        XCTAssertEqual(status.remainingMilliliters, 375, accuracy: 0.001)
        XCTAssertEqual(status.totalPours, 17)
        XCTAssertEqual(status.remainingPours, 8)
    }

    /// A reading can be stored slightly over capacity -- a generously filled
    /// bottle, a rounded guess -- but a fill bar over 100% is the app being
    /// visibly wrong.
    func testAnOverfullReadingIsClampedToTheBottle() {
        XCTAssertEqual(
            PourMath.remainingMilliliters(capacity: 750, poured: 0, startingFrom: 900),
            750, accuracy: 0.001)
    }

    func testANegativeReadingIsClampedToEmpty() {
        XCTAssertEqual(
            PourMath.remainingMilliliters(capacity: 750, poured: 0, startingFrom: -50),
            0, accuracy: 0.001)
    }

    /// A bottle cannot owe you whiskey.
    func testPouringPastAReadingStopsAtEmpty() {
        XCTAssertEqual(
            PourMath.remainingMilliliters(capacity: 750, poured: 500, startingFrom: 200),
            0, accuracy: 0.001)
    }

    // MARK: - Percentages

    /// People say "about a third left". Nobody eyeballs 63%.
    func testPercentagesConvertToMillilitres() {
        XCTAssertEqual(
            PourMath.milliliters(percentFull: 50, capacity: 750), 375, accuracy: 0.001)
        XCTAssertEqual(
            PourMath.milliliters(percentFull: 0, capacity: 750), 0, accuracy: 0.001)
        XCTAssertEqual(
            PourMath.milliliters(percentFull: 100, capacity: 700), 700, accuracy: 0.001)
    }

    func testPercentagesAreClampedBothWays() {
        XCTAssertEqual(
            PourMath.milliliters(percentFull: 140, capacity: 750), 750, accuracy: 0.001)
        XCTAssertEqual(
            PourMath.milliliters(percentFull: -20, capacity: 750), 0, accuracy: 0.001)
    }

    func testMillilitresConvertBackToAPercentage() {
        XCTAssertEqual(
            PourMath.percentFull(remaining: 375, capacity: 750), 50, accuracy: 0.001)
        XCTAssertEqual(
            PourMath.percentFull(remaining: 900, capacity: 750), 100, accuracy: 0.001)
        XCTAssertEqual(
            PourMath.percentFull(remaining: -5, capacity: 750), 0, accuracy: 0.001)
    }

    /// The case that shipped wrong: a slider reading "50%" beside "374 ml" on a
    /// 750 ml bottle. The engine was right; the screen displayed a ROUNDED
    /// percentage while computing millilitres from the raw slider value, which
    /// a `step: 1` slider does not guarantee is an integer. Anything showing a
    /// percentage must derive the millilitres from the SAME rounded number.
    func testAHalfFullSevenFiftyIsExactlyThreeSeventyFive() {
        XCTAssertEqual(
            PourMath.milliliters(percentFull: 50, capacity: 750), 375, accuracy: 0.0001)
    }

    /// Every whole percentage of a 750 ml bottle has to land somewhere a person
    /// can read back, so no integer percentage may produce a figure that
    /// rounds away from its own percentage.
    func testEveryWholePercentageRoundTripsOnA750() {
        for percent in 0...100 {
            let ml = PourMath.milliliters(percentFull: Double(percent), capacity: 750)
            XCTAssertEqual(
                Int(PourMath.percentFull(remaining: ml, capacity: 750).rounded()),
                percent,
                "\(percent)% of 750 ml came back as a different percentage")
        }
    }

    /// A bottle with no stated size cannot be expressed as a fraction of
    /// itself. Zero rather than a crash or a NaN on screen.
    func testAZeroCapacityBottleIsNotDividedBy() {
        XCTAssertEqual(PourMath.milliliters(percentFull: 50, capacity: 0), 0)
        XCTAssertEqual(PourMath.percentFull(remaining: 100, capacity: 0), 0)
    }

    /// The round trip has to survive, or the slider and the millilitre field
    /// fight each other every time one updates the other.
    func testPercentAndMillilitresRoundTrip() {
        for percent in stride(from: 0.0, through: 100.0, by: 5.0) {
            let ml = PourMath.milliliters(percentFull: percent, capacity: 750)
            XCTAssertEqual(
                PourMath.percentFull(remaining: ml, capacity: 750),
                percent, accuracy: 0.001)
        }
    }

    // MARK: - What it means downstream

    /// Headroom is what drives the oxidation estimate, so a reading has to
    /// reach it. A half-full bottle somebody typed in is a moderate-headroom
    /// bottle, not a fresh one.
    func testAReadingFeedsTheHeadroomBands() {
        let status = PourMath.status(
            capacityMilliliters: 750, pouredMilliliters: 0, startingMilliliters: 200)
        let level = FillLevel(
            remainingMilliliters: status.remainingMilliliters,
            capacityMilliliters: status.capacityMilliliters)
        XCTAssertEqual(level.headroom, .high)
    }
}
