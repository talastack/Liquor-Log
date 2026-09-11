import XCTest
@testable import LiquorEngine

/// A changing opinion as one sentence. These pin the restraint: one rating is
/// not a trend, a one-point move is noise, and the words describe the
/// person's ratings rather than explaining them.
final class TastingTrendTests: XCTestCase {

    private func day(_ n: Int) -> Date {
        Date(timeIntervalSince1970: Double(n) * 86_400)
    }

    func testOneTastingIsNotATrend() {
        XCTAssertNil(TastingTrend.summarise([
            TastingTrend.Point(tastedAt: day(0), rating: 7),
        ]))
    }

    func testNoTastingsIsNotATrend() {
        XCTAssertNil(TastingTrend.summarise([]))
    }

    func testRisingTwoPointsOpenedUp() throws {
        let summary = try XCTUnwrap(TastingTrend.summarise([
            TastingTrend.Point(tastedAt: day(0), rating: 6, daysOpen: 0),
            TastingTrend.Point(tastedAt: day(40), rating: 8, daysOpen: 40),
        ]))
        XCTAssertEqual(summary.direction, .openedUp)
        XCTAssertEqual(summary.text, "Opened up: 6 to 8 over 40 days open.")
        XCTAssertEqual(summary.spanDays, 40)
    }

    func testFallingTwoPointsIsFading() throws {
        let summary = try XCTUnwrap(TastingTrend.summarise([
            TastingTrend.Point(tastedAt: day(0), rating: 8, daysOpen: 3),
            TastingTrend.Point(tastedAt: day(200), rating: 6, daysOpen: 203),
        ]))
        XCTAssertEqual(summary.direction, .fading)
        XCTAssertEqual(summary.text, "Fading: 8 to 6 over 203 days open.")
    }

    func testOnePointIsNoise() throws {
        let summary = try XCTUnwrap(TastingTrend.summarise([
            TastingTrend.Point(tastedAt: day(0), rating: 7),
            TastingTrend.Point(tastedAt: day(10), rating: 8),
            TastingTrend.Point(tastedAt: day(20), rating: 8),
        ]))
        XCTAssertEqual(summary.direction, .holding)
        XCTAssertEqual(summary.text, "Holding around 8 across 3 tastings over 20 days.")
    }

    func testSameRatingHoldsAt() throws {
        let summary = try XCTUnwrap(TastingTrend.summarise([
            TastingTrend.Point(tastedAt: day(0), rating: 8),
            TastingTrend.Point(tastedAt: day(1), rating: 8),
        ]))
        XCTAssertEqual(summary.text, "Holding at 8 across 2 tastings over 1 day.")
    }

    /// The order tastings arrive in is the database's business, not the
    /// trend's: newest-first input must give the same answer.
    func testInputOrderDoesNotMatter() {
        let oldestFirst = TastingTrend.summarise([
            TastingTrend.Point(tastedAt: day(0), rating: 5),
            TastingTrend.Point(tastedAt: day(30), rating: 9),
        ])
        let newestFirst = TastingTrend.summarise([
            TastingTrend.Point(tastedAt: day(30), rating: 9),
            TastingTrend.Point(tastedAt: day(0), rating: 5),
        ])
        XCTAssertEqual(oldestFirst, newestFirst)
        XCTAssertEqual(oldestFirst?.firstRating, 5)
        XCTAssertEqual(oldestFirst?.latestRating, 9)
    }

    /// Only the first and latest ratings decide the direction. A dip in the
    /// middle is a bad evening, not a trend.
    func testTheMiddleDoesNotDecide() throws {
        let summary = try XCTUnwrap(TastingTrend.summarise([
            TastingTrend.Point(tastedAt: day(0), rating: 7),
            TastingTrend.Point(tastedAt: day(5), rating: 4),
            TastingTrend.Point(tastedAt: day(10), rating: 7),
        ]))
        XCTAssertEqual(summary.direction, .holding)
    }

    func testTwoTastingsOnOneDay() throws {
        let summary = try XCTUnwrap(TastingTrend.summarise([
            TastingTrend.Point(tastedAt: day(0), rating: 6),
            TastingTrend.Point(tastedAt: day(0).addingTimeInterval(3_600), rating: 8),
        ]))
        XCTAssertEqual(summary.text, "Opened up: 6 to 8 on the same day.")
    }
}
