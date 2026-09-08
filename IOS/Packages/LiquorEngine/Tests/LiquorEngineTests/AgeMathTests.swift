import XCTest
@testable import LiquorEngine

final class AgeMathTests: XCTestCase {

    private let utc: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        return calendar
    }()

    private func date(_ year: Int, _ month: Int, _ day: Int) -> Date {
        utc.date(from: DateComponents(year: year, month: month, day: day))!
    }

    func testMaturationIsBarrelTime() {
        XCTAssertEqual(AgeMath.maturationYears(distilledYear: 2010, bottledYear: 2022), 12)
    }

    func testMaturationNeedsBothYears() {
        XCTAssertNil(AgeMath.maturationYears(distilledYear: 2010, bottledYear: nil))
        XCTAssertNil(AgeMath.maturationYears(distilledYear: nil, bottledYear: 2022))
    }

    func testImpossibleMaturationIsNilRatherThanNegative() {
        XCTAssertNil(AgeMath.maturationYears(distilledYear: 2022, bottledYear: 2010))
    }

    /// Whiskey does not mature in glass. A 1985 bottling of a 12-year is a
    /// 12-year-old whiskey in a 40-year-old bottle, and these must never be the
    /// same number.
    func testTimeInGlassIsSeparateFromMaturation() {
        let now = date(2025, 6, 1)
        let inGlass = AgeMath.yearsInGlass(bottledYear: 1985, now: now, calendar: utc)
        let matured = AgeMath.maturationYears(distilledYear: 1973, bottledYear: 1985)

        XCTAssertEqual(inGlass, 40)
        XCTAssertEqual(matured, 12)
        XCTAssertNotEqual(inGlass, matured)
    }

    func testDaysOpenAndDaysOwnedAreDifferentNumbers() {
        let bought = date(2025, 1, 1)
        let opened = date(2025, 3, 1)
        let now = date(2025, 6, 1)

        XCTAssertEqual(AgeMath.daysOwned(purchasedAt: bought, now: now, calendar: utc), 151)
        XCTAssertEqual(AgeMath.daysOpen(openedAt: opened, now: now, calendar: utc), 92)
    }

    func testUnopenedBottleHasNoDaysOpen() {
        XCTAssertNil(AgeMath.daysOpen(openedAt: nil, now: date(2025, 6, 1), calendar: utc))
    }

    /// A device clock that has jumped backwards should not produce a bottle
    /// opened in the future.
    func testBackwardsClockClampsToZero() {
        let now = date(2025, 1, 1)
        let opened = date(2025, 6, 1)
        XCTAssertEqual(AgeMath.daysOpen(openedAt: opened, now: now, calendar: utc), 0)
    }
}
