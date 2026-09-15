import XCTest
@testable import LiquorEngine

/// Eight stoppers spelling BLANTONS, two of them N, per Blanton's own FAQ.
final class TopperLettersTests: XCTestCase {

    func testTheSetIsEightStoppersWithTwoNs() {
        XCTAssertEqual(TopperLetters.stoppers.count, 8)
        XCTAssertEqual(TopperLetters.stoppers.joined(), "BLANTON:S")
        XCTAssertEqual(TopperLetters.word, "BLANTONS")
    }

    func testNormalisingKnowsBothNs() {
        XCTAssertEqual(TopperLetters.normalise("b"), "B")
        XCTAssertEqual(TopperLetters.normalise(" n "), "N")
        XCTAssertEqual(TopperLetters.normalise("n:"), "N:")
        XCTAssertEqual(TopperLetters.normalise("N2"), "N:")
        XCTAssertNil(TopperLetters.normalise("'"), "there is no apostrophe stopper")
        XCTAssertNil(TopperLetters.normalise("X"))
        XCTAssertNil(TopperLetters.normalise("BL"))
        XCTAssertNil(TopperLetters.normalise(""))
    }

    func testProgressCountsAndBlanksTheWord() {
        let progress = TopperLetters.progress(["B", "l", "A", "T", "O", "N:", "S", "b"])
        XCTAssertEqual(progress.owned["B"], 2)
        XCTAssertEqual(progress.missing, ["N"])
        XCTAssertFalse(progress.isComplete)
        XCTAssertEqual(progress.ownedCount, 7)
        XCTAssertEqual(progress.wordLine, "B L A _ T O N: S")
    }

    func testTheTwoNsAreDifferentStoppers() {
        let oneN = TopperLetters.progress(["B", "L", "A", "N", "T", "O", "S"])
        XCTAssertEqual(oneN.missing, ["N:"])
        let both = TopperLetters.progress(["B", "L", "A", "N", "T", "O", "N:", "S"])
        XCTAssertTrue(both.isComplete)
        XCTAssertEqual(both.wordLine, "B L A N T O N: S")
    }

    func testUnknownLettersAreIgnored() {
        let progress = TopperLetters.progress(["Z", "?", "", "'"])
        XCTAssertEqual(progress.ownedCount, 0)
        XCTAssertEqual(progress.missing.count, 8)
    }
}
