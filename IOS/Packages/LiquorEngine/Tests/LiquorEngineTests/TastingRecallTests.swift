import XCTest
@testable import LiquorEngine

/// One sentence from the last tasting, built only from what was recorded.
final class TastingRecallTests: XCTestCase {

    private let weller = ProductIdentity(
        productId: "w12", distillery: "Buffalo Trace", brand: "W. L. Weller",
        expression: "12 Year", classType: .kentuckyStraightBourbon, productionType: .unspecified)

    private var calendar: Calendar {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(identifier: "UTC")!
        return c
    }

    private func date(_ y: Int, _ m: Int, _ d: Int) -> Date {
        calendar.date(from: DateComponents(year: y, month: m, day: d, hour: 12))!
    }

    private func record(
        at: Date, rating: Int? = nil, rebuy: Bool? = nil,
        liked: String? = nil, disliked: String? = nil, where_: String? = nil
    ) -> TastingRecord {
        TastingRecord(
            tastingId: "t", product: weller, tastedAt: at, rating: rating,
            wouldRebuy: rebuy, liked: liked, disliked: disliked, where_: where_)
    }

    func testEverythingRecordedReadsAsOneLine() {
        let now = date(2026, 9, 15)
        let line = TastingRecall.line(
            record(at: date(2026, 3, 2), rating: 8, rebuy: true, liked: "toffee", disliked: "the heat"),
            now: now, calendar: calendar)
        XCTAssertEqual(line, "Last time, in March: 8/10, would buy again. Liked toffee. Not the heat.")
    }

    func testOnlyWhatWasRecordedAppears() {
        let now = date(2026, 9, 15)
        XCTAssertEqual(
            TastingRecall.line(record(at: date(2026, 9, 14), rating: 6), now: now, calendar: calendar),
            "Last time, yesterday: 6/10.")
        XCTAssertEqual(
            TastingRecall.line(record(at: date(2026, 9, 15), liked: "  the finish "), now: now, calendar: calendar),
            "Last time, today. Liked the finish.")
        XCTAssertEqual(
            TastingRecall.line(record(at: date(2026, 9, 3), rebuy: false), now: now, calendar: calendar),
            "Last time, 12 days ago: would not buy again.")
    }

    /// A tasting with nothing in it is not a memory. No line, rather than
    /// "Last time: ." on the card.
    func testNothingRecordedMeansNoLine() {
        XCTAssertNil(TastingRecall.line(record(at: date(2026, 9, 1), liked: "  "), now: date(2026, 9, 15), calendar: calendar))
    }

    func testWhereItHappenedIsKept() {
        let line = TastingRecall.line(
            record(at: date(2025, 11, 20), rating: 7, where_: "At a bar"),
            now: date(2026, 9, 15), calendar: calendar)
        XCTAssertEqual(line, "Last time, in November 2025 (at a bar): 7/10.")
    }

    func testTheMonthCarriesItsYearOnlyWhenItIsNotThisYear() {
        let now = date(2026, 9, 15)
        XCTAssertEqual(TastingRecall.when(date(2026, 1, 3), now: now, calendar: calendar), "in January")
        XCTAssertEqual(TastingRecall.when(date(2024, 7, 3), now: now, calendar: calendar), "in July 2024")
        XCTAssertEqual(TastingRecall.when(date(2026, 8, 20), now: now, calendar: calendar), "26 days ago")
    }
}
