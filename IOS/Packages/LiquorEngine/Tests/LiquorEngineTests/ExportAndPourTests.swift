import XCTest
@testable import LiquorEngine

/// Bourbon data hits every CSV escaping edge case: pick names contain commas,
/// tasting notes contain quotes and line breaks. A naive join produces a file
/// that opens misaligned and looks exactly like lost data — in a category where
/// people have already been burned by apps losing their collections.
final class CSVWriterTests: XCTestCase {

    func testPlainFieldsAreNotQuoted() {
        XCTAssertEqual(CSVWriter.escape("Elijah Craig"), "Elijah Craig")
    }

    func testCommasForceQuoting() {
        XCTAssertEqual(
            CSVWriter.escape("Barrel 42, Floor 5"),
            "\"Barrel 42, Floor 5\"")
    }

    func testQuotesAreDoubled() {
        XCTAssertEqual(
            CSVWriter.escape("the \"good\" barrel"),
            "\"the \"\"good\"\" barrel\"")
    }

    func testNewlinesInNotesSurvive() {
        let note = "Nose: toffee\nFinish: hot"
        XCTAssertEqual(CSVWriter.escape(note), "\"Nose: toffee\nFinish: hot\"")
    }

    func testARowJoinsAndEscapesEachField() {
        XCTAssertEqual(
            CSVWriter.row(["Elijah Craig", "B523, 2023", "8"]),
            "Elijah Craig,\"B523, 2023\",8")
    }

    func testADocumentHasAHeaderAndCRLFEndings() {
        let csv = CSVWriter.document(
            header: ["name", "proof"],
            rows: [["Weller 107", "107"], ["Booker's", ""]])
        XCTAssertEqual(csv, "name,proof\r\nWeller 107,107\r\nBooker's,\r\n")
    }

    /// A blank cell reads as "not recorded", which is the truth for most
    /// optional fields on most bottles. "nil" or "0" would be a claim.
    func testMissingValuesAreBlankNotZero() {
        XCTAssertEqual(CSVWriter.number(nil), "")
        XCTAssertEqual(CSVWriter.decimal(nil), "")
        XCTAssertEqual(CSVWriter.money(cents: nil), "")
        XCTAssertEqual(CSVWriter.text(nil), "")
        XCTAssertEqual(CSVWriter.date(millis: nil), "")
        XCTAssertEqual(CSVWriter.flag(false), "")
    }

    /// No currency symbol: it makes the column text in every spreadsheet.
    func testMoneyIsAPlainDecimal() {
        XCTAssertEqual(CSVWriter.money(cents: 7999), "79.99")
        XCTAssertEqual(CSVWriter.money(cents: 5), "0.05")
    }

    func testDatesAreISOSoTheySortAsText() {
        var utc = Calendar(identifier: .gregorian)
        utc.timeZone = TimeZone(identifier: "UTC")!
        let millis = Int64(utc.date(from: DateComponents(
            year: 2026, month: 5, day: 12))!.timeIntervalSince1970 * 1000)
        XCTAssertEqual(CSVWriter.date(millis: millis, calendar: utc), "2026-05-12")
    }
}

final class PickMyPourTests: XCTestCase {

    private func candidate(
        _ id: String, daysAgo: Int?, open: Bool = true, remaining: Double = 500
    ) -> PickMyPour.Candidate {
        PickMyPour.Candidate(
            id: id,
            name: id,
            lastPouredAt: daysAgo.map { Date(timeIntervalSince1970: 0).addingTimeInterval(
                Double(365 - $0) * 86_400) },
            isOpen: open,
            remainingMilliliters: remaining)
    }

    private var now: Date { Date(timeIntervalSince1970: 365 * 86_400) }

    /// Opening a sealed bottle starts an oxidation clock and is often the whole
    /// point of the bottle. The app should not make that call for somebody.
    func testSealedBottlesAreNeverSuggested() {
        let pool = [
            candidate("sealed", daysAgo: nil, open: false),
            candidate("open", daysAgo: 10),
        ]
        XCTAssertEqual(PickMyPour.eligible(from: pool).map(\.id), ["open"])
    }

    func testEmptyBottlesAreNeverSuggested() {
        let pool = [candidate("empty", daysAgo: 5, remaining: 0)]
        XCTAssertTrue(PickMyPour.eligible(from: pool).isEmpty)
    }

    func testNothingEligibleReturnsNil() {
        var rng = SystemRandomNumberGenerator()
        XCTAssertNil(PickMyPour.choose(from: [], using: &rng))
        let sealed = [candidate("s", daysAgo: nil, open: false)]
        XCTAssertNil(PickMyPour.choose(from: sealed, now: now, using: &rng))
    }

    /// An open bottle you have never tasted is the one most worth a nudge.
    func testNeverPouredCarriesTheStrongestWeight() {
        let never = candidate("never", daysAgo: nil)
        let yesterday = candidate("recent", daysAgo: 1)
        XCTAssertGreaterThan(
            PickMyPour.weight(for: never, now: now),
            PickMyPour.weight(for: yesterday, now: now))
    }

    func testNeglectRaisesTheWeight() {
        let old = candidate("old", daysAgo: 200)
        let recent = candidate("recent", daysAgo: 3)
        XCTAssertGreaterThan(
            PickMyPour.weight(for: old, now: now),
            PickMyPour.weight(for: recent, now: now))
    }

    /// Without a cap one forgotten bottle wins every time and the feature stops
    /// being a surprise.
    func testNeglectIsCappedSoOneBottleCannotAlwaysWin() {
        let ancient = candidate("ancient", daysAgo: 700)
        XCTAssertEqual(
            PickMyPour.weight(for: ancient, now: now),
            PickMyPour.neglectCapDays,
            accuracy: 0.001)
    }

    /// A bottle poured yesterday still has to be reachable, or the suggestion
    /// becomes predictable and people stop tapping it.
    func testEvenARecentPourKeepsAFloor() {
        XCTAssertGreaterThanOrEqual(
            PickMyPour.weight(for: candidate("today", daysAgo: 0), now: now), 1)
    }

    func testASingleEligibleBottleIsAlwaysTheAnswer() {
        var rng = SystemRandomNumberGenerator()
        let only = [candidate("only", daysAgo: 30), candidate("sealed", daysAgo: nil, open: false)]
        XCTAssertEqual(PickMyPour.choose(from: only, now: now, using: &rng)?.candidate.id, "only")
    }

    /// A random pick with no reason feels arbitrary. A reason makes it a
    /// suggestion.
    func testEveryChoiceExplainsItself() {
        var rng = SystemRandomNumberGenerator()
        for days in [0, 10, 60, 200, 400] {
            let pool = [candidate("x", daysAgo: days)]
            let choice = PickMyPour.choose(from: pool, now: now, using: &rng)
            XCTAssertFalse(try! XCTUnwrap(choice).reason.isEmpty)
        }
        let never = [candidate("n", daysAgo: nil)]
        XCTAssertTrue(
            PickMyPour.choose(from: never, now: now, using: &rng)?
                .reason.contains("not poured from it yet") == true)
    }
}
