import XCTest
@testable import LiquorEngine

final class PriceCheckTests: XCTestCase {

    private let vaShelf = PriceReference(cents: 17999, source: "Virginia ABC", asOfYear: 2026)

    func testShelfPriceIsAtOrBelow() {
        let result = PriceCheck.compare(paidCents: 17999, reference: vaShelf)
        XCTAssertEqual(result.band, .atOrBelow)
        XCTAssertEqual(result.differenceCents, 0)
    }

    func testUnderShelfIsAtOrBelow() {
        let result = PriceCheck.compare(paidCents: 15999, reference: vaShelf)
        XCTAssertEqual(result.band, .atOrBelow)
        XCTAssertEqual(result.differenceCents, -2000)
    }

    /// Shelf prices vary legitimately between states and retailers. A band that
    /// called a normal regional difference "overpriced" would be wrong far more
    /// often than it was useful.
    func testASmallMarkupIsNotAnAccusation() {
        let result = PriceCheck.compare(paidCents: 18999, reference: vaShelf)
        XCTAssertEqual(result.band, .slightlyOver)
    }

    func testAThirdOverIsWellOver() {
        let result = PriceCheck.compare(paidCents: 23999, reference: vaShelf)
        XCTAssertEqual(result.band, .wellOver)
    }

    /// The Elijah Craig 18 case from the design: $269 against a $179.99 shelf
    /// price. Secondary pricing, and the app should say so plainly.
    func testSecondaryPricingIsFarOver() {
        let result = PriceCheck.compare(paidCents: 26900, reference: vaShelf)
        XCTAssertEqual(result.band, .farOver)
        XCTAssertEqual(result.differenceCents, 8901)
        XCTAssertEqual(try XCTUnwrap(result.fractionOver), 0.494, accuracy: 0.001)
    }

    func testBoundariesLandOnTheGentlerBand() {
        // Exactly 10% over is still "slightly", exactly 40% still "well".
        XCTAssertEqual(PriceCheck.compare(paidCents: 19798, reference: vaShelf).band, .slightlyOver)
        XCTAssertEqual(PriceCheck.compare(paidCents: 25198, reference: vaShelf).band, .wellOver)
    }

    // MARK: - Honesty about what was compared

    func testNoReferenceIsAnAnswerRatherThanASilentZero() {
        let result = PriceCheck.compare(paidCents: 26900, reference: nil)
        XCTAssertEqual(result.band, .noReference)
        XCTAssertNil(result.differenceCents)
        XCTAssertNil(result.fractionOver)
        XCTAssertEqual(result.caveat, "No published shelf price for this bottle.")
    }

    /// The caveat is not decoration. A user reading "far over shelf price"
    /// without knowing it is a shelf comparison would take it as a market
    /// valuation, which this app cannot make.
    func testTheCaveatNamesTheSourceAndDisclaimsResale() {
        let result = PriceCheck.compare(paidCents: 26900, reference: vaShelf)
        XCTAssertTrue(result.caveat.contains("Virginia ABC"))
        XCTAssertTrue(result.caveat.contains("2026"))
        XCTAssertTrue(result.caveat.contains("Not a resale value"))
    }

    func testAZeroReferenceIsTreatedAsNoReference() {
        let bogus = PriceReference(cents: 0, source: "unknown")
        XCTAssertEqual(PriceCheck.compare(paidCents: 5000, reference: bogus).band, .noReference)
    }

    func testEveryBandHasAHeadline() {
        for band in PriceCheck.Band.allCases {
            let result = PriceCheck.Result(
                paidCents: 1, reference: nil, band: band,
                differenceCents: nil, fractionOver: nil)
            XCTAssertFalse(result.headline.isEmpty, "\(band) has no headline")
        }
    }

    // MARK: - The number that needs no external data

    func testCostPerPourNeedsNoReferenceAtAll() {
        let cents = PriceCheck.costPerPourCents(paidCents: 7999, capacityMilliliters: 750)
        XCTAssertEqual(cents, 471)
    }
}
