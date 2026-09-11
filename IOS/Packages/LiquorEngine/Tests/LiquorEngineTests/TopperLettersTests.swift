import XCTest
@testable import LiquorEngine

final class TopperLettersTests: XCTestCase {

    func testTheSetSpellsTheName() {
        XCTAssertEqual(String(TopperLetters.set), "BLANTON'S")
        XCTAssertEqual(TopperLetters.distinct.count, 8)
    }

    func testNormalisingAcceptsCaseAndTypographicApostrophe() {
        XCTAssertEqual(TopperLetters.normalise("b"), "B")
        XCTAssertEqual(TopperLetters.normalise(" n "), "N")
        XCTAssertEqual(TopperLetters.normalise("\u{2019}"), "'")
        XCTAssertNil(TopperLetters.normalise("X"))
        XCTAssertNil(TopperLetters.normalise("BL"))
        XCTAssertNil(TopperLetters.normalise(""))
    }

    func testProgressCountsAndBlanksTheWord() {
        let progress = TopperLetters.progress(["B", "l", "A", "T", "O", "'", "S", "b"])
        XCTAssertEqual(progress.owned["B"], 2)
        XCTAssertEqual(progress.missing, ["N"])
        XCTAssertFalse(progress.isComplete)
        XCTAssertEqual(progress.ownedCount, 7)
        XCTAssertEqual(progress.wordLine, "B L A _ T O _ ' S")
    }

    func testOneNCoversBothPositions() {
        let progress = TopperLetters.progress(["B", "L", "A", "N", "T", "O", "'", "S"])
        XCTAssertTrue(progress.isComplete)
        XCTAssertEqual(progress.wordLine, "B L A N T O N ' S")
    }

    func testUnknownLettersAreIgnored() {
        let progress = TopperLetters.progress(["Z", "?", ""])
        XCTAssertEqual(progress.ownedCount, 0)
        XCTAssertEqual(progress.missing.count, 8)
    }
}
