import XCTest
@testable import LiquorEngine

/// A contribution in the registry's shape, from the person's own data.
final class DumpDateRegistryTests: XCTestCase {

    private var utc: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        return calendar
    }

    private func day(_ n: Int) -> Date { Date(timeIntervalSince1970: Double(n) * 86_400) }

    /// CSVWriter ends lines with CRLF for Excel's sake.
    private func lines(of csv: String) -> [String] {
        csv.components(separatedBy: "\r\n").filter { !$0.isEmpty }
    }

    func testOnlyDatedEntriesOldestFirst() {
        let csv = DumpDateRegistry.csv([
            DumpDateRegistry.Entry(dumpedAt: day(400), topperLetter: "b", barrel: "12", warehouse: "H", rick: "34"),
            DumpDateRegistry.Entry(topperLetter: "S"),
            DumpDateRegistry.Entry(dumpedAt: day(10), topperLetter: "'", store: "Total Wine", stateFound: "VA"),
        ], calendar: utc)
        let rows = lines(of: csv)
        XCTAssertEqual(rows.count, 3)
        XCTAssertEqual(rows[0], DumpDateRegistry.header.joined(separator: ","))
        XCTAssertEqual(rows[1], "1970-01-11,',,,,,Total Wine,VA")
        XCTAssertEqual(rows[2], "1971-02-05,B,12,H,34,,,")
    }

    func testAnUnknownLetterIsLeftBlankRatherThanInvented() {
        let csv = DumpDateRegistry.csv([
            DumpDateRegistry.Entry(dumpedAt: day(0), topperLetter: "Z"),
        ], calendar: utc)
        XCTAssertEqual(lines(of: csv).last, "1970-01-01,,,,,,,")
    }
}
