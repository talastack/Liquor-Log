import XCTest
@testable import LiquorEngine

/// Visits become stamps; the shelf says what came from each place and
/// which distilleries on it you have never been to.
final class PassportTests: XCTestCase {

    private var calendar: Calendar {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(identifier: "UTC")!
        return c
    }
    private func day(_ y: Int, _ m: Int, _ d: Int) -> Date {
        calendar.date(from: DateComponents(year: y, month: m, day: d, hour: 12))!
    }

    private var shelf: [Passport.Bottle] {
        [
            Passport.Bottle(name: "Weller 12", distillery: "Buffalo Trace", boughtAt: "Total Wine"),
            Passport.Bottle(name: "Stagg", distillery: "Buffalo Trace", boughtAt: "Buffalo Trace Distillery"),
            Passport.Bottle(name: "Four Roses OESQ", distillery: "Four Roses", boughtAt: "Four Roses"),
            Passport.Bottle(name: "Rittenhouse", distillery: "Heaven Hill"),
            Passport.Bottle(name: "ECBP", distillery: "Heaven Hill"),
            Passport.Bottle(name: "Something typed in", distillery: nil),
        ]
    }

    func testStampsMergeSpellingsAndCarryTheShelf() {
        let summary = Passport.summarise(
            visits: [
                Passport.Visit(distillery: "Buffalo Trace Distillery", at: day(2024, 3, 10)),
                Passport.Visit(distillery: "buffalo trace", at: day(2026, 8, 1)),
                Passport.Visit(distillery: "Four Roses", at: day(2025, 5, 5), note: "the Cox's Creek warehouses"),
            ],
            shelf: shelf)

        XCTAssertEqual(summary.headline, "2 distilleries, 3 visits.")
        XCTAssertEqual(summary.stamps.map(\.name), ["buffalo trace", "Four Roses"], "most recent first, newest spelling")
        let bt = summary.stamps[0]
        XCTAssertEqual(bt.visits, 2)
        XCTAssertEqual(bt.firstAt, day(2024, 3, 10))
        XCTAssertEqual(bt.bottlesFromThere, ["Stagg", "Weller 12"])
        XCTAssertEqual(bt.boughtThere, ["Stagg"], "the store name is the distillery, however it was spelled")
        XCTAssertEqual(Passport.shelfLine(bt), "2 bottles from there on the shelf, 1 bought there.")
        XCTAssertEqual(Passport.line(bt, now: day(2026, 8, 22), calendar: calendar), "2 visits · first March 2024 · last 3 weeks ago")
        XCTAssertEqual(Passport.line(summary.stamps[1], now: day(2025, 5, 5), calendar: calendar), "Once, today")
    }

    func testNotYetVisitedIsTheShelfMinusTheStamps() {
        let summary = Passport.summarise(
            visits: [Passport.Visit(distillery: "Buffalo Trace", at: day(2026, 1, 1))],
            shelf: shelf)
        XCTAssertEqual(summary.notYetVisited.map(\.name), ["Heaven Hill", "Four Roses"], "most bottles first")
        XCTAssertEqual(summary.notYetVisited.map(\.bottles), [2, 1])
    }

    func testNothingVisitedIsAnEmptyPassportWithAShelfToVisit() {
        let summary = Passport.summarise(visits: [], shelf: shelf)
        XCTAssertNil(summary.headline)
        XCTAssertTrue(summary.stamps.isEmpty)
        XCTAssertEqual(summary.notYetVisited.count, 3)
    }
}
