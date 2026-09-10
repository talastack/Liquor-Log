import XCTest
@testable import LiquorEngine

/// The shareable pick record. Fixed shape, so a registry can parse it back
/// without a person in the loop.
final class PickCardTests: XCTestCase {

    private var utc: Calendar {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(identifier: "UTC")!
        return c
    }

    func testItWritesOneKeyPerLineInAFixedOrder() {
        let text = PickCard.text(PickCard.Pick(
            product: "Four Roses Single Barrel",
            pickedBy: "Bourbon Society",
            store: "Total Wine",
            barrel: "42-3C",
            recipeCode: "OESQ",
            warehouse: "QN",
            proof: 112.4,
            ageMonths: 112))
        let lines = text.components(separatedBy: "\n")
        XCTAssertEqual(lines[0], "Pick: Four Roses Single Barrel")
        XCTAssertEqual(lines[1], "Picked by: Bourbon Society")
        XCTAssertEqual(lines[2], "Store: Total Wine")
        XCTAssertEqual(lines[3], "Barrel: 42-3C")
        XCTAssertTrue(lines[4].hasPrefix("Recipe: OESQ"))
        XCTAssertEqual(lines[5], "Warehouse: QN")
        XCTAssertEqual(lines[6], "Proof: 112.4")
        XCTAssertEqual(lines[7], "Age: 9 years 4 months")
    }

    /// A reader who does not know what OESQ means gets the answer inline.
    func testARecipeCodeIsDecodedOnItsOwnLine() {
        let text = PickCard.text(PickCard.Pick(product: "x", recipeCode: "OESQ"))
        XCTAssertTrue(text.contains("75% corn, 20% rye, 5% malted barley"))
        XCTAssertTrue(text.contains("floral essence yeast"))
    }

    func testBlankFieldsAreOmittedNotPrintedAsEmpty() {
        let text = PickCard.text(PickCard.Pick(product: "x", barrel: "7"))
        XCTAssertEqual(text, "Pick: x\nBarrel: 7")
        XCTAssertFalse(text.contains("Warehouse"))
    }

    /// The months are the reason the pick was chosen.
    func testAgeKeepsTheMonths() {
        XCTAssertEqual(PickCard.ageText(112), "9 years 4 months")
        XCTAssertEqual(PickCard.ageText(120), "10 years")
        XCTAssertEqual(PickCard.ageText(7), "7 months")
    }

    func testBottleNumberReadsAsOfBatch() {
        let both = PickCard.text(PickCard.Pick(product: "x", bottleNumber: 47, bottlesInBatch: 240))
        XCTAssertTrue(both.contains("Bottle: 47 of 240"))
        let countOnly = PickCard.text(PickCard.Pick(product: "x", bottlesInBatch: 240))
        XCTAssertTrue(countOnly.contains("Bottles: 240"))
    }

    func testDumpDateIsISO() {
        let date = utc.date(from: DateComponents(year: 2025, month: 5, day: 10))!
        let text = PickCard.text(PickCard.Pick(product: "Blanton's", dumpedAt: date), calendar: utc)
        XCTAssertTrue(text.contains("Dumped: 2025-05-10"))
    }

    /// A standard release is not a pick, and a card with only a name would be
    /// noise in a registry.
    func testAStandardReleaseHasNothingToShare() {
        XCTAssertFalse(PickCard.Pick(product: "Buffalo Trace", proof: 90).hasBarrelDetail)
        XCTAssertTrue(PickCard.Pick(product: "Buffalo Trace", barrel: "12").hasBarrelDetail)
    }

    /// Plain text, no markup, so it survives every paste target.
    func testItIsPlainText() {
        let text = PickCard.text(PickCard.Pick(product: "x", barrel: "1", pickedBy: "y"))
        XCTAssertFalse(text.contains("<"))
        XCTAssertFalse(text.contains("*"))
        XCTAssertFalse(text.contains("|"))
    }
}
