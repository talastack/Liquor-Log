import XCTest
@testable import LiquorEngine

/// Two opinions of one bottle, and what changed underneath the score.
final class TastingComparisonTests: XCTestCase {

    private func day(_ n: Int) -> Date { Date(timeIntervalSince1970: Double(n) * 86_400) }
    private let stages = ["nose", "entry", "mid", "finish"]

    func testTheOlderTastingIsTheEarlierOneWhicheverWayItArrives() {
        // A screen passes whatever the user tapped first. "What is new" has
        // to mean new in the later glass regardless.
        let march = TastingComparison.Side(tastedAt: day(10), rating: 6)
        let october = TastingComparison.Side(tastedAt: day(200), rating: 8)

        for pair in [(march, october), (october, march)] {
            let result = TastingComparison.compare(pair.0, pair.1, stageOrder: stages)
            XCTAssertEqual(result.earlier.tastedAt, day(10))
            XCTAssertEqual(result.later.tastedAt, day(200))
            XCTAssertEqual(result.ratingChange, 2)
        }
    }

    func testDescriptorsSplitIntoSharedGoneAndNew() {
        let before = TastingComparison.Side(
            tastedAt: day(1), rating: 7,
            descriptors: ["nose": ["Caramel", "Green apple"], "finish": ["Oak"]])
        let after = TastingComparison.Side(
            tastedAt: day(100), rating: 7,
            descriptors: ["nose": ["Caramel", "Dried fig"], "finish": ["Oak"]])

        let result = TastingComparison.compare(before, after, stageOrder: stages)
        let nose = result.stages.first { $0.stage == "nose" }
        XCTAssertEqual(nose?.shared, ["Caramel"])
        XCTAssertEqual(nose?.goneSince, ["Green apple"])
        XCTAssertEqual(nose?.newSince, ["Dried fig"])

        // A stage that did not move says so, rather than being dropped: it
        // is evidence the two tastings agreed.
        let finish = result.stages.first { $0.stage == "finish" }
        XCTAssertEqual(finish?.shared, ["Oak"])
        XCTAssertTrue(finish?.isUnchanged == true)
    }

    func testAStageNobodyUsedIsLeftOutEntirely() {
        // Printing "mid: nothing, nothing" for a bottle nobody described
        // mid-palate is noise on a screen meant to show a difference.
        let before = TastingComparison.Side(tastedAt: day(1), descriptors: ["nose": ["Caramel"]])
        let after = TastingComparison.Side(tastedAt: day(2), descriptors: ["nose": ["Caramel"]])

        let result = TastingComparison.compare(before, after, stageOrder: stages)
        XCTAssertEqual(result.stages.map(\.stage), ["nose"])
    }

    func testAnUnratedTastingIsNotAZero() {
        // The difference between "I did not score it" and "I scored it 0" is
        // the difference between no opinion and a bad one.
        let rated = TastingComparison.Side(tastedAt: day(1), rating: 8)
        let unrated = TastingComparison.Side(tastedAt: day(50))

        XCTAssertNil(TastingComparison.compare(rated, unrated, stageOrder: stages).ratingChange)
    }

    func testTheLineStatesWhatHappenedWithoutInterpretingIt() {
        let before = TastingComparison.Side(tastedAt: day(1), rating: 6)
        let after = TastingComparison.Side(
            tastedAt: day(200), rating: 8, descriptors: ["nose": ["Dried fig"]])

        let text = TastingComparison.compare(before, after, stageOrder: stages).text
        XCTAssertTrue(text.contains("6"), text)
        XCTAssertTrue(text.contains("8 out of 10"), text)
        XCTAssertTrue(text.contains("up from"), text)
        // "You liked it more" is a claim about a person. This says what the
        // record says and stops.
        XCTAssertFalse(text.lowercased().contains("better"), text)
        XCTAssertFalse(text.lowercased().contains("liked"), text)
    }

    func testTwoTastingsOnOneNightReadAsTheSameDay() {
        let first = TastingComparison.Side(tastedAt: day(5), rating: 7)
        let second = TastingComparison.Side(tastedAt: day(5), rating: 7)

        let result = TastingComparison.compare(first, second, stageOrder: stages)
        XCTAssertEqual(result.daysApart, 0)
        XCTAssertTrue(result.text.hasPrefix("The same day"), result.text)
        XCTAssertTrue(result.text.contains("still 7"), result.text)
    }
}
