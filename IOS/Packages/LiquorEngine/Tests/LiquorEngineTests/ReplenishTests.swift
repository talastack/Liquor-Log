import XCTest
@testable import LiquorEngine

/// The offer fires once, on the crossing pour, and never nags.
final class ReplenishTests: XCTestCase {

    func testTheCrossingPourOffers() throws {
        let offer = try XCTUnwrap(Replenish.offer(
            remainingBefore: 3, remainingAfter: 2, isOnWishlist: false, wouldRebuy: nil))
        XCTAssertEqual(offer.remainingPours, 2)
        XCTAssertEqual(offer.text, "About 2 pours left.")
    }

    func testPoursAfterTheCrossingDoNotAskAgain() {
        XCTAssertNil(Replenish.offer(
            remainingBefore: 2, remainingAfter: 1, isOnWishlist: false, wouldRebuy: nil))
        XCTAssertNil(Replenish.offer(
            remainingBefore: 1, remainingAfter: 0, isOnWishlist: false, wouldRebuy: nil))
    }

    func testABigPourCanCrossStraightToEmpty() throws {
        let offer = try XCTUnwrap(Replenish.offer(
            remainingBefore: 3, remainingAfter: 0, isOnWishlist: false, wouldRebuy: nil))
        XCTAssertEqual(offer.text, "That was the last pour.")
    }

    func testOnePourLeft() throws {
        let offer = try XCTUnwrap(Replenish.offer(
            remainingBefore: 4, remainingAfter: 1, isOnWishlist: false, wouldRebuy: true))
        XCTAssertEqual(offer.text, "About one pour left. You said you would buy it again.")
    }

    func testAFullBottleNeverAsks() {
        XCTAssertNil(Replenish.offer(
            remainingBefore: 17, remainingAfter: 16, isOnWishlist: false, wouldRebuy: true))
    }

    func testAlreadyOnTheWishlistIsNotAskedTwice() {
        XCTAssertNil(Replenish.offer(
            remainingBefore: 3, remainingAfter: 2, isOnWishlist: true, wouldRebuy: true))
    }

    /// The person answered this question already, on the tasting sheet.
    func testWouldNotRebuyIsRespected() {
        XCTAssertNil(Replenish.offer(
            remainingBefore: 3, remainingAfter: 2, isOnWishlist: false, wouldRebuy: false))
    }
}
