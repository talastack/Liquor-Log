import XCTest
@testable import LiquorEngine

/// A drip as a fraction of the bottle, ranked among your own, never called
/// rare.
final class WaxDripTests: XCTestCase {

    private func p(_ x: Double, _ y: Double) -> WaxDrip.Point { WaxDrip.Point(x: x, y: y) }

    func testAFractionOfTheBottle() throws {
        // A bottle 400 units tall, a drip 100 units long: a quarter.
        let m = try XCTUnwrap(WaxDrip.measure(
            bottleBase: p(50, 500), bottleTop: p(50, 100),
            waxEdge: p(60, 120), dripTip: p(60, 220)))
        XCTAssertEqual(m.fraction, 0.25, accuracy: 0.0001)
        XCTAssertEqual(m.percent, 25)
        XCTAssertNil(m.millimeters, "no height typed, no millimetres")
    }

    func testMillimetresOnlyWithARealHeight() throws {
        let m = try XCTUnwrap(WaxDrip.measure(
            bottleBase: p(0, 400), bottleTop: p(0, 0),
            waxEdge: p(0, 0), dripTip: p(0, 100),
            bottleHeightMillimeters: 240))
        XCTAssertEqual(m.millimeters ?? 0, 60, accuracy: 0.001)
        XCTAssertNil(WaxDrip.measure(
            bottleBase: p(0, 400), bottleTop: p(0, 0),
            waxEdge: p(0, 0), dripTip: p(0, 100),
            bottleHeightMillimeters: 0)?.millimeters)
    }

    func testTheUnitsDoNotMatter() throws {
        let small = try XCTUnwrap(WaxDrip.measure(bottleBase: p(0, 40), bottleTop: p(0, 0), waxEdge: p(0, 0), dripTip: p(0, 10)))
        let large = try XCTUnwrap(WaxDrip.measure(bottleBase: p(0, 4000), bottleTop: p(0, 0), waxEdge: p(0, 0), dripTip: p(0, 1000)))
        XCTAssertEqual(small.fraction, large.fraction, accuracy: 0.0001)
    }

    func testADiagonalDripIsMeasuredAlongItsLength() throws {
        let m = try XCTUnwrap(WaxDrip.measure(
            bottleBase: p(0, 100), bottleTop: p(0, 0),
            waxEdge: p(0, 0), dripTip: p(30, 40)))
        XCTAssertEqual(m.fraction, 0.5, accuracy: 0.0001)
    }

    func testTwoTapsInOnePlaceIsNotABottle() {
        XCTAssertNil(WaxDrip.measure(bottleBase: p(1, 1), bottleTop: p(1, 1), waxEdge: p(0, 0), dripTip: p(0, 5)))
    }

    func testADripCannotBeLongerThanTheBottle() throws {
        let m = try XCTUnwrap(WaxDrip.measure(bottleBase: p(0, 10), bottleTop: p(0, 0), waxEdge: p(0, 0), dripTip: p(0, 50)))
        XCTAssertEqual(m.fraction, 1)
    }

    func testStandingAmongYourOwn() {
        XCTAssertEqual(WaxDrip.standing(of: 0.3, among: []).text, "The only drip measured so far.")
        XCTAssertEqual(WaxDrip.standing(of: 0.3, among: [0.1, 0.2]).text, "Longest of 3.")
        let mid = WaxDrip.standing(of: 0.2, among: [0.1, 0.3, 0.05, 0.4])
        XCTAssertEqual(mid.rank, 3)
        XCTAssertEqual(mid.text, "Longer than 50% of 5.")
    }

    // MARK: - Among everyone's

    func testCommunityStandingSpeaksInQuarters() {
        let standing = WaxDrip.CommunityStanding(catalogProductId: "makers", reports: 40, p25: 0.1, p50: 0.15, p75: 0.2)
        XCTAssertEqual(standing.text(for: 0.25), "Longer than three quarters of the 40 drips people have measured.")
        XCTAssertEqual(standing.text(for: 0.16), "Longer than half of the 40 drips people have measured.")
        XCTAssertEqual(standing.text(for: 0.12), "Longer than a quarter of the 40 drips people have measured.")
        XCTAssertEqual(standing.text(for: 0.05), "Among the shortest quarter of the 40 drips people have measured.")
    }

    func testTooFewMeasuredDripsSayNothing() {
        let standing = WaxDrip.CommunityStanding(catalogProductId: "makers", reports: 3, p25: 0.1, p50: 0.15, p75: 0.2)
        XCTAssertNil(standing.text(for: 0.5))
    }
}
