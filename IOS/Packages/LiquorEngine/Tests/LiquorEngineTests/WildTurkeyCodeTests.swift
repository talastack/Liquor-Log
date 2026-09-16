import XCTest
@testable import LiquorEngine

/// Rare Bird 101's own worked examples, one per format.
final class WildTurkeyCodeTests: XCTestCase {

    func testTheLetteredFormatOf2013To2021() throws {
        let code = try XCTUnwrap(WildTurkeyCode("LL/DF021000"))
        XCTAssertEqual([code.year, code.month, code.day], [2015, 6, 2])
        XCTAssertEqual(code.hour, 10)
        XCTAssertEqual(code.minute, 0)
        XCTAssertEqual(code.format, .lettered2013)
        XCTAssertEqual(code.summary, "Bottled 2 June 2015 at 10:00.")
        XCTAssertEqual(WildTurkeyCode("ll df02 1000")?.year, 2015, "spaces and the slash are optional")
    }

    func testTheYearLettersRunFromA2012() {
        XCTAssertEqual(WildTurkeyCode("LL/HA01")?.year, 2019)
        XCTAssertEqual(WildTurkeyCode("LL/IA01")?.year, 2020)
        XCTAssertEqual(WildTurkeyCode("LL/JL31")?.year, 2021)
        XCTAssertEqual(WildTurkeyCode("LL/JL31")?.month, 12)
        XCTAssertEqual(WildTurkeyCode("LL/KA150900")?.year, 2022)
        XCTAssertEqual(WildTurkeyCode("LL/LC011200")?.year, 2023)
        XCTAssertNil(WildTurkeyCode("LL/MA01"), "2024 bottles start with LA")
    }

    /// A fullwidth or Arabic-Indic digit is not a code; it must not be a
    /// crash either.
    func testNonASCIIDigitsAreRefusedNotTrapped() {
        XCTAssertNil(WildTurkeyCode("LL/DF０２"))
        XCTAssertNil(WildTurkeyCode("L٩١٣٢FH"))
    }

    func testTheFormatFrom2024() throws {
        let code = try XCTUnwrap(WildTurkeyCode("LA MI26E0719"))
        XCTAssertEqual([code.year, code.month, code.day], [2024, 9, 26])
        XCTAssertEqual(code.hour, 7)
        XCTAssertEqual(code.minute, 19)
        XCTAssertEqual(code.format, .lettered2024)
    }

    func testTheDayOfYearFormatFrom2006To2014() throws {
        let nine = try XCTUnwrap(WildTurkeyCode("L9132FH 1253"))
        XCTAssertEqual([nine.year, nine.month, nine.day], [2009, 5, 12])
        XCTAssertEqual(nine.hour, 12)
        XCTAssertEqual(nine.minute, 53)

        let six = try XCTUnwrap(WildTurkeyCode("L6229NU7A"))
        XCTAssertEqual([six.year, six.month, six.day], [2006, 8, 17])
        XCTAssertNil(six.hour)

        XCTAssertEqual(WildTurkeyCode("L3040AB")?.year, 2013)
        XCTAssertNil(WildTurkeyCode("L5040AB"), "no year of the format ends in 5")
    }

    func testTheHyphenatedNineties() throws {
        let code = try XCTUnwrap(WildTurkeyCode("L-15-220"))
        XCTAssertEqual([code.year, code.month, code.day], [1995, 8, 8])
        XCTAssertEqual(code.format, .hyphenated1990s)
    }

    /// Impossible dates are refused, not rounded.
    func testImpossibleDatesAreRefused() {
        XCTAssertNil(WildTurkeyCode("LL/DF311000"), "31 June")
        XCTAssertNil(WildTurkeyCode("LL/DF022500"), "25 o'clock")
        XCTAssertNil(WildTurkeyCode("L9366FH"), "day 366 of a common year")
        XCTAssertNil(WildTurkeyCode("LL/DM02"), "M is not a month")
    }

    /// Other brands' codes are not Wild Turkey's.
    func testOtherCodesAreLeftAlone() {
        XCTAssertNil(WildTurkeyCode("OESQ"))
        XCTAssertNil(WildTurkeyCode("B523"))
        XCTAssertNil(WildTurkeyCode("L19274"), "a Buffalo Trace laser code")
        XCTAssertNil(WildTurkeyCode("DSP-KY-113"))
        XCTAssertNil(WildTurkeyCode("L12358"), "the unhyphenated 1992 form is left to the laser decoder")
    }
}
