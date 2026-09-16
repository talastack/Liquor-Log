import XCTest
@testable import LiquorEngine

/// Windows, never dates; overlap, never an average.
final class DustyCluesTests: XCTestCase {

    private func clue(_ id: String) -> DustyClues.Clue {
        DustyClues.Clue.allCases.first { $0.id == id }!
    }

    func testNothingChosenAsksForSomething() {
        XCTAssertEqual(DustyClues.window(for: []).text, "Pick what the bottle shows.")
    }

    func testOneClueIsOneSidedWindow() {
        XCTAssertEqual(DustyClues.window(for: [clue("strip")]).text, "Before 1986.")
        XCTAssertEqual(DustyClues.window(for: [clue("metric")]).text, "1976 or later.")
        XCTAssertEqual(DustyClues.window(for: [clue("irs")]).text, "Before 1977.")
    }

    /// One strip cannot say both IRS and ATF; a bottle cannot both have
    /// and lack a strip, even in 1985 when either was possible.
    func testMutuallyExclusiveCluesConflictWhateverTheYear() {
        XCTAssertNotNil(DustyClues.window(for: [clue("irs"), clue("atf")]).conflict)
        XCTAssertNotNil(DustyClues.window(for: [clue("strip"), clue("no-strip")]).conflict)
        XCTAssertNotNil(DustyClues.window(for: [clue("quart"), clue("metric")]).conflict)
    }

    /// ATF strip and a 4/5 quart: 1977 to 1979, the three years both held.
    func testCluesOverlap() {
        let window = DustyClues.window(for: [clue("atf"), clue("quart")])
        XCTAssertEqual(window.from, 1977)
        XCTAssertEqual(window.to, 1979)
        XCTAssertEqual(window.text, "Between 1977 and 1979.")
    }

    func testAMetricStripBottleIsLateSeventiesToMidEighties() {
        let window = DustyClues.window(for: [clue("strip"), clue("metric")])
        XCTAssertEqual(window.text, "Between 1976 and 1985.")
    }

    /// An IRS strip and a metric size cannot both be right about the same
    /// bottle -- well, they can for 1976, so make it ATF and Series 111.
    func testContradictionIsSaidNotAveraged() {
        let window = DustyClues.window(for: [clue("atf"), clue("series")])
        XCTAssertNotNil(window.conflict)
        XCTAssertTrue(window.text.hasPrefix("Those cannot both be true"))
    }

    func testEveryClueHasAReason() {
        for clue in DustyClues.Clue.allCases {
            XCTAssertFalse(clue.why.isEmpty, clue.id)
            XCTAssertTrue(clue.from != nil || clue.to != nil, clue.id)
        }
    }
}
