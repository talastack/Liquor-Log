import XCTest
@testable import LiquorEngine

/// The record in order, with the gaps said in days, and nothing inferred.
final class BottleStoryTests: XCTestCase {

    private var calendar: Calendar {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(identifier: "UTC")!
        return c
    }

    private func day(_ n: Int) -> Date { Date(timeIntervalSince1970: Double(n) * 86_400) }

    func testAWholeLifeInOrderWithItsGaps() {
        let facts = BottleStory.Facts(
            name: "Weller 12",
            bottledAt: day(0), bottledText: "From the laser code",
            boughtAt: day(200), boughtWhere: "Total Wine", paidText: "$79.99",
            openedAt: day(600), finishedAt: day(690),
            pours: [(day(601), 44, nil, nil), (day(620), 60, "Mike", nil), (day(650), 44, nil, nil)],
            tastings: [(day(601), 7, false, "toffee"), (day(680), 9, false, nil)],
            readings: [(day(640), 300, "By weight: 850 g on the scale")])
        let story = BottleStory.tell(facts, calendar: calendar)

        XCTAssertEqual(story.events.map(\.kind), [.bottled, .bought, .opened, .pour, .tasting, .gift, .level, .pour, .tasting, .finished])
        XCTAssertEqual(story.events[1].detail, "$79.99 · at Total Wine · 6 months after bottling")
        XCTAssertEqual(story.events[2].detail, "After 13 months on the shelf")
        XCTAssertEqual(story.events[5].title, "60 ml to Mike")
        XCTAssertEqual(story.events[8].title, "Tasted · 9/10")
        XCTAssertEqual(story.events.last?.detail, "3 months after opening")
        XCTAssertEqual(story.summary, "Opened after 13 months on the shelf. Finished 3 months later: 2 pours, 1 given away, 2 tastings, the rating up from 7 to 9.")
    }

    func testAnOpenBottleHasARunningSummary() {
        let facts = BottleStory.Facts(
            name: "Stagg", boughtAt: day(0), openedAt: day(3),
            pours: [(day(4), 44, nil, nil), (day(9), 44, nil, nil)],
            tastings: [(day(4), 6, true, nil), (day(9), 8, false, nil)])
        let story = BottleStory.tell(facts, calendar: calendar)
        XCTAssertEqual(story.summary, "Opened after 3 days on the shelf. 2 pours so far, the rating up from 6 to 8.")
        XCTAssertEqual(story.events.first { $0.kind == .tasting }?.title, "Tasted · 6/10 · blind")
    }

    /// Nothing dated is nothing told.
    func testNoDatesNoStory() {
        let story = BottleStory.tell(BottleStory.Facts(name: "Sealed"), calendar: calendar)
        XCTAssertTrue(story.events.isEmpty)
        XCTAssertNil(story.summary)
    }

    func testOuncesWhenAsked() {
        let facts = BottleStory.Facts(name: "x", openedAt: day(0), pours: [(day(1), 44.36, nil, nil)])
        XCTAssertEqual(BottleStory.tell(facts, ounces: true, calendar: calendar).events.last?.detail, "1.5 oz")
    }

    func testSpansRound() {
        XCTAssertEqual(BottleStory.span(1), "1 day")
        XCTAssertEqual(BottleStory.span(20), "2 weeks")
        XCTAssertEqual(BottleStory.span(100), "3 months")
        XCTAssertEqual(BottleStory.span(800), "2 years")
    }
}
