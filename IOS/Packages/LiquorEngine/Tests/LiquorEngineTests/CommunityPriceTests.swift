import XCTest
@testable import LiquorEngine

/// The only price data the app can honestly own. These pin the restraint: it
/// stays quiet until it has enough to say, and it never claims to be a value.
final class CommunityPriceTests: XCTestCase {

    private var now: Date { Date(timeIntervalSince1970: 1_000 * 86_400) }

    private func report(
        _ dollars: Double, daysAgo: Int = 1, region: String? = nil
    ) -> CommunityPrice.Report {
        CommunityPrice.Report(
            cents: Int(dollars * 100),
            seenAt: now.addingTimeInterval(Double(-daysAgo) * 86_400),
            region: region)
    }

    // MARK: - Staying quiet

    /// One sighting is an anecdote and two is a coincidence. Showing a
    /// "community price" from a single report borrows authority the app has
    /// not earned.
    func testTooFewReportsSaysNothing() {
        XCTAssertNil(CommunityPrice.estimate(from: [], now: now))
        XCTAssertNil(CommunityPrice.estimate(from: [report(50)], now: now))
        XCTAssertNil(CommunityPrice.estimate(from: [report(50), report(52)], now: now))
    }

    func testThreeReportsIsEnough() {
        let estimate = CommunityPrice.estimate(
            from: [report(50), report(52), report(54)], now: now)
        XCTAssertNotNil(estimate)
        XCTAssertEqual(estimate?.reportCount, 3)
    }

    /// Shelf prices move. A three-year-old sighting shown as current is worse
    /// than nothing, because somebody would plan around it.
    func testStaleReportsAreDropped() {
        let old = [report(50, daysAgo: 900), report(52, daysAgo: 900), report(54, daysAgo: 900)]
        XCTAssertNil(CommunityPrice.estimate(from: old, now: now))
    }

    func testStaleReportsDoNotPropUpFreshOnes() {
        let mixed = [report(50), report(52), report(999, daysAgo: 900)]
        XCTAssertNil(
            CommunityPrice.estimate(from: mixed, now: now),
            "two fresh reports is still too few")
    }

    // MARK: - The figure

    /// One duty-free bottle or one airport markup would drag a mean somewhere
    /// nobody shops.
    func testItUsesTheMedianNotTheMean() {
        let reports = [report(45), report(48), report(50), report(52), report(400)]
        let estimate = CommunityPrice.estimate(from: reports, now: now)
        XCTAssertEqual(estimate?.cents, 5000, "median, not the 11900 mean")
    }

    func testItReportsTheFullSpread() {
        let estimate = CommunityPrice.estimate(
            from: [report(45), report(60), report(90)], now: now)
        XCTAssertEqual(estimate?.lowestCents, 4500)
        XCTAssertEqual(estimate?.highestCents, 9000)
    }

    // MARK: - Saying what it is

    /// It must never read as a manufacturer's figure or a valuation.
    func testTheSourceNamesItselfAsReports() {
        let estimate = CommunityPrice.estimate(
            from: [report(45), report(50), report(55)], now: now)
        XCTAssertEqual(estimate?.source, "3 shelf prices reported")
        XCTAssertFalse(estimate?.source.lowercased().contains("msrp") ?? true)
    }

    func testTheCaveatRefusesTheWordValuation() throws {
        let estimate = try XCTUnwrap(
            CommunityPrice.estimate(from: [report(45), report(50), report(55)], now: now))
        XCTAssertTrue(estimate.caveat.contains("not a valuation"))
        XCTAssertTrue(estimate.caveat.contains("$45.00"))
        XCTAssertTrue(estimate.caveat.contains("$55.00"))
    }

    func testTheReferenceCarriesTheSourceThrough() throws {
        let estimate = try XCTUnwrap(
            CommunityPrice.estimate(from: [report(45), report(50), report(55)], now: now))
        XCTAssertEqual(estimate.reference.cents, estimate.cents)
        XCTAssertEqual(estimate.reference.source, estimate.source)
    }

    // MARK: - Region

    /// A Kentucky shelf price is not a Virginia one, so a national median is a
    /// number nobody recognises.
    func testARegionalFigureIsPreferred() throws {
        let reports = [
            report(40, region: "KY"), report(42, region: "KY"), report(44, region: "KY"),
            report(90, region: "CA"), report(95, region: "CA"), report(99, region: "CA"),
        ]
        let local = try XCTUnwrap(
            CommunityPrice.best(from: reports, preferring: "KY", now: now))
        XCTAssertEqual(local.cents, 4200)
        XCTAssertEqual(local.region, "KY")
        XCTAssertTrue(local.source.contains("in KY"))
    }

    /// Two local reports beaten by twenty national ones is still better than
    /// showing nothing, and the source line says which you are looking at.
    func testItFallsBackToEverywhereWhenLocalIsThin() throws {
        let reports = [
            report(40, region: "KY"),
            report(90, region: "CA"), report(95, region: "CA"), report(99, region: "CA"),
        ]
        let any = try XCTUnwrap(
            CommunityPrice.best(from: reports, preferring: "KY", now: now))
        XCTAssertEqual(any.reportCount, 4)
        XCTAssertNil(any.region, "fell back, and says so by not naming a region")
    }

    func testAnUnknownRegionStillGetsTheNationalFigure() {
        let reports = [report(50, region: "TX"), report(52, region: "TX"), report(54, region: "TX")]
        XCTAssertNotNil(CommunityPrice.best(from: reports, preferring: nil, now: now))
    }
}
