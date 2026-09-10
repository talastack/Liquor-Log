import XCTest
@testable import LiquorEngine

/// Reading a spreadsheet. The first thing anybody's file contains is a bottle
/// with a comma in its name, so the parser has to be a real one.
final class CSVReaderTests: XCTestCase {

    func testACommaInsideQuotesIsNotASeparator() {
        let rows = CSVReader.rows("name,proof\n\"Elijah Craig, Batch B523\",124.2\n")
        XCTAssertEqual(rows[1], ["Elijah Craig, Batch B523", "124.2"])
    }

    func testADoubledQuoteIsALiteralQuote() {
        let rows = CSVReader.rows("note\n\"the \"\"good\"\" barrel\"\n")
        XCTAssertEqual(rows[1], ["the \"good\" barrel"])
    }

    func testANewlineInsideQuotesStaysInTheField() {
        let rows = CSVReader.rows("note\n\"nose: toffee\nfinish: hot\"\n")
        XCTAssertEqual(rows.count, 2)
        XCTAssertEqual(rows[1], ["nose: toffee\nfinish: hot"])
    }

    /// Excel writes CRLF; a Mac spreadsheet writes LF. Both are one record.
    func testCRLFAndLFBothEndARecord() {
        XCTAssertEqual(CSVReader.rows("a,b\r\n1,2\r\n").count, 2)
        XCTAssertEqual(CSVReader.rows("a,b\n1,2\n").count, 2)
    }

    func testATrailingNewlineDoesNotMakeAnEmptyRow() {
        XCTAssertEqual(CSVReader.rows("a\n1\n").count, 2)
        XCTAssertEqual(CSVReader.rows("a\n1").count, 2)
    }

    /// Excel prefixes UTF-8 files with a byte-order mark, which would otherwise
    /// make the first header "\u{FEFF}name" and match nothing.
    func testExcelsByteOrderMarkIsStripped() {
        let (header, _) = CSVReader.records("\u{FEFF}Name,Proof\nWeller,90\n")
        XCTAssertEqual(header, ["name", "proof"])
    }

    func testOurOwnExportRoundTrips() {
        let text = CSVWriter.document(
            header: ["name", "proof"],
            rows: [["Weller 107, Special", "107"], ["Booker's", ""]])
        let rows = CSVReader.rows(text)
        XCTAssertEqual(rows, [["name", "proof"], ["Weller 107, Special", "107"], ["Booker's", ""]])
    }
}

final class CollectionImportTests: XCTestCase {

    // MARK: - Recognising columns

    /// Nobody should have to rename a column to import.
    func testItRecognisesTheWordsPeopleActuallyUse() {
        let plan = CollectionImport.plan(csv: """
        Whiskey,Proof,Purchase Price ($),Bought At,Where Kept
        Blanton's,93,$79.99,Total Wine,hall closet
        """)
        XCTAssertEqual(plan.rows.count, 1)
        let row = plan.rows[0]
        XCTAssertEqual(row.name, "Blanton's")
        XCTAssertEqual(row.proof, 93)
        XCTAssertEqual(row.paidCents, 7999)
        XCTAssertEqual(row.store, "Total Wine")
        XCTAssertEqual(row.storageLocation, "hall closet")
    }

    func testTheMappingSaysWhichColumnBecameWhat() {
        let plan = CollectionImport.plan(csv: "Bottle,ABV\nWeller,45\n")
        XCTAssertEqual(plan.mapping[.name], "bottle")
        XCTAssertEqual(plan.mapping[.abv], "abv")
    }

    /// Our own export must come back in whole. This is the backup promise.
    func testOurOwnExportImportsCleanly() {
        let text = CSVWriter.document(
            header: ["name", "status", "size_ml", "proof", "batch", "price", "storage_location"],
            rows: [["Elijah Craig Barrel Proof", "open", "750", "124.2", "B523", "79.99", "closet"]])
        let plan = CollectionImport.plan(csv: text)
        let row = try! XCTUnwrap(plan.rows.first)
        XCTAssertEqual(row.name, "Elijah Craig Barrel Proof")
        XCTAssertTrue(row.isOpen)
        XCTAssertEqual(row.volumeMilliliters, 750)
        XCTAssertEqual(row.proof ?? 0, 124.2, accuracy: 0.01)
        XCTAssertEqual(row.batch, "B523")
        XCTAssertEqual(row.paidCents, 7999)
    }

    // MARK: - Numbers as people type them

    func testABVBecomesProofWhenThereIsNoProofColumn() {
        let plan = CollectionImport.plan(csv: "Name,ABV\nWeller,45%\n")
        XCTAssertEqual(plan.rows[0].proof ?? 0, 90, accuracy: 0.01)
    }

    /// The number people wrote down wins.
    func testProofWinsOverABVWhenBothArePresent() {
        let plan = CollectionImport.plan(csv: "Name,ABV,Proof\nWeller,45,107\n")
        XCTAssertEqual(plan.rows[0].proof ?? 0, 107, accuracy: 0.01)
    }

    /// "0.75" in a size column is litres; 750 is millilitres.
    func testASizeInLitresIsConvertedToMillilitres() {
        XCTAssertEqual(CollectionImport.plan(csv: "Name,Size\nA,0.75\n").rows[0].volumeMilliliters, 750)
        XCTAssertEqual(CollectionImport.plan(csv: "Name,Size\nA,750\n").rows[0].volumeMilliliters, 750)
        XCTAssertEqual(CollectionImport.plan(csv: "Name,Size\nA,750ml\n").rows[0].volumeMilliliters, 750)
    }

    func testStatusWordsAreRead() {
        let plan = CollectionImport.plan(csv: """
        Name,Status
        A,Open
        B,Sealed
        C,Killed
        D,finished
        """)
        XCTAssertTrue(plan.rows[0].isOpen)
        XCTAssertFalse(plan.rows[1].isOpen)
        XCTAssertTrue(plan.rows[2].isFinished)
        XCTAssertTrue(plan.rows[3].isFinished)
        XCTAssertFalse(plan.rows[3].isOpen, "finished is not open")
    }

    // MARK: - Refusing to guess

    /// A row with no name is reported by line, never saved as "Untitled".
    func testRowsWithNoNameAreSkippedAndNamedByLine() {
        let plan = CollectionImport.plan(csv: "Name,Proof\nWeller,90\n,100\nBooker's,125\n")
        XCTAssertEqual(plan.rows.map(\.name), ["Weller", "Booker's"])
        XCTAssertEqual(plan.skippedLines, [3])
    }

    /// With no recognisable name column there is nothing to import, and the
    /// honest plan is every line skipped rather than the first column guessed.
    func testAFileWithNoNameColumnImportsNothing() {
        let plan = CollectionImport.plan(csv: "Foo,Bar\n1,2\n3,4\n")
        XCTAssertTrue(plan.isEmpty)
        XCTAssertEqual(plan.skippedLines, [2, 3])
        XCTAssertNil(plan.mapping[.name])
    }

    func testBlankRowsAreIgnoredNotSkipped() {
        let plan = CollectionImport.plan(csv: "Name\nWeller\n\n\nBooker's\n")
        XCTAssertEqual(plan.rows.count, 2)
        XCTAssertTrue(plan.skippedLines.isEmpty, "an empty line is not a bottle with no name")
    }

    /// Each column is claimed once. A file with both "Price" and "Cost" reads
    /// price and leaves cost alone rather than reading it twice.
    func testAColumnIsClaimedByOnlyOneField() {
        let mapping = CollectionImport.map(["name", "price", "cost"])
        XCTAssertEqual(mapping[.paid], "price")
        XCTAssertEqual(Set(mapping.values).count, mapping.count)
    }
}
