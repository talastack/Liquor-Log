import XCTest
@testable import LiquorEngine

/// The Buffalo Trace bottling code: year, day of the year, time, line.
final class LaserCodeTests: XCTestCase {

    private var utc: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        return calendar
    }

    func testTheCanonicalExample() throws {
        let code = try XCTUnwrap(LaserCode("L19274 15:02 K"))
        XCTAssertEqual(code.year, 2019)
        XCTAssertEqual(code.dayOfYear, 274)
        XCTAssertEqual(code.hour, 15)
        XCTAssertEqual(code.minute, 2)
        XCTAssertEqual(code.line, "K")
        XCTAssertEqual(code.prefix, "L")
        let parts = utc.dateComponents([.year, .month, .day], from: try XCTUnwrap(code.date(calendar: utc)))
        XCTAssertEqual([parts.year, parts.month, parts.day], [2019, 10, 1])
        XCTAssertEqual(code.summary(calendar: utc), "Bottled 1 October 2019 at 15:02, line K.")
        XCTAssertEqual(code.description, "L19274 15:02 K")
    }

    /// The modern code as the public write-ups give it, plant number and all.
    func testTheModernFormatWithAPlantNumber() throws {
        let code = try XCTUnwrap(LaserCode("L 18 096 01 1050 K"))
        XCTAssertEqual(code.year, 2018)
        XCTAssertEqual(code.dayOfYear, 96)
        XCTAssertEqual(code.plant, 1)
        XCTAssertEqual(code.hour, 10)
        XCTAssertEqual(code.minute, 50)
        XCTAssertEqual(code.line, "K")
        XCTAssertEqual(code.summary(calendar: utc), "Bottled 6 April 2018 at 10:50, line K.")
        XCTAssertEqual(code.description, "L18096 01 10:50 K")
        let plantOnly = try XCTUnwrap(LaserCode("L1809601"))
        XCTAssertEqual(plantOnly.plant, 1)
        XCTAssertNil(plantOnly.hour)
    }

    /// 2007-2011: line, day, year, time.
    func testTheOlderFormat() throws {
        let code = try XCTUnwrap(LaserCode("K 259 10 15:47"))
        XCTAssertEqual(code.year, 2010)
        XCTAssertEqual(code.dayOfYear, 259)
        XCTAssertEqual(code.hour, 15)
        XCTAssertEqual(code.minute, 47)
        XCTAssertEqual(code.line, "K")
        XCTAssertNil(code.prefix)
        XCTAssertEqual(code.summary(calendar: utc), "Bottled 16 September 2010 at 15:47, line K.")
    }

    func testSpacesAndColonAreOptional() throws {
        XCTAssertEqual(LaserCode("l192741502k"), LaserCode("L19274 15:02 K"))
        let bare = try XCTUnwrap(LaserCode("L19274"))
        XCTAssertNil(bare.hour)
        XCTAssertEqual(bare.summary(calendar: utc), "Bottled 1 October 2019.")
    }

    func testDayOneAndTheLastDay() throws {
        let first = try XCTUnwrap(LaserCode("L21001"))
        XCTAssertEqual(utc.dateComponents([.month, .day], from: try XCTUnwrap(first.date(calendar: utc))).day, 1)
        let leap = try XCTUnwrap(LaserCode("L20366"))
        let parts = utc.dateComponents([.month, .day], from: try XCTUnwrap(leap.date(calendar: utc)))
        XCTAssertEqual([parts.month, parts.day], [12, 31])
        XCTAssertNil(LaserCode("L21366"), "2021 has no day 366")
        XCTAssertNil(LaserCode("L19400"))
        XCTAssertNil(LaserCode("L19000"))
    }

    /// The other decoders' inputs must not be mistaken for a laser code.
    func testDoesNotEatTheOtherSchemes() {
        XCTAssertNil(LaserCode("OESQ"))
        XCTAssertNil(LaserCode("B523"), "a Heaven Hill batch code has three digits, not five")
        XCTAssertNil(LaserCode("A1123"))
        XCTAssertNil(LaserCode(""))
    }

    func testABadTimeIsIgnoredNotInvented() throws {
        let code = try XCTUnwrap(LaserCode("L19274 25:99 K"))
        XCTAssertNil(code.hour)
        XCTAssertEqual(code.line, "K")
    }
}
