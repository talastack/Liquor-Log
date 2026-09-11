import XCTest
@testable import LiquorEngine

/// The document says what was paid and never what it is worth.
final class InsuranceReportTests: XCTestCase {

    private func line(_ name: String, distillery: String? = nil, paid: Int? = nil) -> InsuranceReport.Line {
        InsuranceReport.Line(
            id: name, name: name, distillery: distillery,
            sizeMilliliters: 750, status: "Sealed", paidCents: paid)
    }

    func testTotalsCoverOnlyPricedBottles() {
        let doc = InsuranceReport.build([
            line("Weller 12", paid: 4_999),
            line("Stagg", paid: 9_999),
            line("Gift"),
        ])
        XCTAssertEqual(doc.bottleCount, 3)
        XCTAssertEqual(doc.pricedCount, 2)
        XCTAssertEqual(doc.unpricedCount, 1)
        XCTAssertEqual(doc.paidTotalCents, 14_998)
    }

    func testOrderedByDistilleryThenName() {
        let doc = InsuranceReport.build([
            line("Zed", distillery: "Buffalo Trace"),
            line("Elijah Craig", distillery: "Heaven Hill"),
            line("Blanton's", distillery: "Buffalo Trace"),
        ])
        XCTAssertEqual(doc.lines.map(\.name), ["Blanton's", "Zed", "Elijah Craig"])
    }

    func testTheCaveatIsPartOfTheDocument() {
        let doc = InsuranceReport.build([])
        XCTAssertTrue(doc.caveat.contains("Not an appraisal"))
        XCTAssertEqual(doc.title, "Spirits collection inventory")
    }

    func testDetailLineInFixedOrder() {
        XCTAssertEqual(
            InsuranceReport.detail(barrel: "42-3C", batch: nil, pickStore: "Total Wine",
                                   bottleNumber: 47, bottlesInBatch: 240, topperLetter: "B"),
            "Barrel 42-3C · Pick · Total Wine · Bottle 47 of 240 · Topper B")
        XCTAssertNil(InsuranceReport.detail())
        XCTAssertEqual(InsuranceReport.detail(bottleNumber: 3), "Bottle 3")
    }
}
