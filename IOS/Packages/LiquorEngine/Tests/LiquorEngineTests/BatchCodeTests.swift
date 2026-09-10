import XCTest
@testable import LiquorEngine

/// Heaven Hill batch codes, made a function. The one static guide stopped in
/// 2019 and no interactive decoder existed anywhere.
final class BatchCodeTests: XCTestCase {

    func testItDecodesTheCanonicalExample() throws {
        let code = try XCTUnwrap(BatchCode("B523"))
        XCTAssertEqual(code.release, .second)
        XCTAssertEqual(code.month, 5)
        XCTAssertEqual(code.year, 2023)
        XCTAssertEqual(code.summary, "Second release of 2023, bottled in May")
    }

    func testItDecodesEachRelease() throws {
        XCTAssertEqual(try XCTUnwrap(BatchCode("A125")).summary, "First release of 2025, bottled in January")
        XCTAssertEqual(try XCTUnwrap(BatchCode("C923")).summary, "Third release of 2023, bottled in September")
    }

    /// The older form carried a two-digit month.
    func testItDecodesATwoDigitMonth() throws {
        let code = try XCTUnwrap(BatchCode("A1023"))
        XCTAssertEqual(code.month, 10)
        XCTAssertEqual(code.year, 2023)
    }

    func testItIsForgivingAboutCaseAndSpacing() throws {
        XCTAssertEqual(try XCTUnwrap(BatchCode("b523")).code, "B523")
        XCTAssertEqual(try XCTUnwrap(BatchCode("B 5 23")).code, "B523")
        XCTAssertEqual(try XCTUnwrap(BatchCode(" b-523 ")).code, "B523")
    }

    // MARK: - Refusing

    /// Nil, never a partial reading. Three of four characters decoded and the
    /// fourth invented is worse than nothing, because nobody can tell.
    func testAnUnknownLetterIsRefused() {
        XCTAssertNil(BatchCode("D523"))
        XCTAssertNil(BatchCode("523"))
    }

    func testAnImpossibleMonthIsRefused() {
        XCTAssertNil(BatchCode("B1323"), "there is no thirteenth month")
        XCTAssertNil(BatchCode("B023"), "there is no zeroth month")
    }

    func testTheWrongNumberOfDigitsIsRefused() {
        XCTAssertNil(BatchCode("B5"))
        XCTAssertNil(BatchCode("B52"))
        XCTAssertNil(BatchCode("B52345"))
    }

    /// Distinct from a Four Roses code, which has no digits at all.
    func testAFourRosesCodeIsNotABatchCode() {
        XCTAssertNil(BatchCode("OESQ"))
    }

    // MARK: - The schedule as a sanity check

    /// Releases ship in January, May and September. A code whose letter and
    /// month disagree is far more likely a misread than a real bottle.
    func testTheUsualScheduleIsRecognised() throws {
        XCTAssertTrue(try XCTUnwrap(BatchCode("A125")).followsTheUsualSchedule)
        XCTAssertTrue(try XCTUnwrap(BatchCode("B523")).followsTheUsualSchedule)
        XCTAssertTrue(try XCTUnwrap(BatchCode("C923")).followsTheUsualSchedule)
    }

    func testADepartureFromTheScheduleIsFlaggedNotRefused() throws {
        let odd = try XCTUnwrap(BatchCode("A923"))
        XCTAssertFalse(odd.followsTheUsualSchedule, "first release in September is unusual")
        XCTAssertEqual(odd.month, 9, "but it still decodes -- the screen can warn")
    }
}
