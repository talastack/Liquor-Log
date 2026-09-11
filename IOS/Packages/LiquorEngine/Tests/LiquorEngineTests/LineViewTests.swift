import XCTest
@testable import LiquorEngine

/// A line, expression by expression, as a fact and never a score.
final class LineViewTests: XCTestCase {

    private func ec(_ id: String, _ expression: String) -> ProductIdentity {
        ProductIdentity(
            productId: id, distillery: "Heaven Hill", brand: "Elijah Craig",
            expression: expression, classType: .kentuckyStraightBourbon, productionType: .smallBatch)
    }

    private lazy var smallBatch = ec("ec-sb", "Small Batch")
    private lazy var barrelProof = ec("ec-bp", "Barrel Proof")
    private lazy var eighteen = ec("ec-18", "18 Year")
    private let weller = ProductIdentity(
        productId: "weller-sr", distillery: "Buffalo Trace", brand: "W L Weller",
        expression: "Special Reserve", classType: .kentuckyStraightBourbon, productionType: .unspecified)

    func testEveryExpressionOfTheLineWithAStanding() {
        let line = LineView.line(
            of: barrelProof,
            catalogue: [smallBatch, barrelProof, eighteen, weller],
            holdings: [
                Holding(bottleId: "1", product: smallBatch, isOpen: true, isFinished: false),
                Holding(bottleId: "2", product: barrelProof, isOpen: false, isFinished: true),
            ],
            tastings: [
                TastingRecord(tastingId: "t", product: eighteen, tastedAt: Date()),
            ])
        XCTAssertEqual(line.brand, "Elijah Craig")
        XCTAssertEqual(line.rows.map(\.product.productId), ["ec-sb", "ec-bp", "ec-18"])
        XCTAssertEqual(line.rows.map(\.standing), [.onShelf, .hadItBefore, .tastedOnly])
    }

    func testOnTheShelfOutranksHadIt() {
        let line = LineView.line(
            of: smallBatch,
            catalogue: [smallBatch],
            holdings: [
                Holding(bottleId: "1", product: smallBatch, isOpen: false, isFinished: true),
                Holding(bottleId: "2", product: smallBatch, isOpen: false, isFinished: false),
            ],
            tastings: [])
        XCTAssertEqual(line.rows.first?.standing, .onShelf)
    }

    func testTheOtherLineIsLeftOut() {
        let line = LineView.line(of: weller, catalogue: [smallBatch, weller], holdings: [], tastings: [])
        XCTAssertEqual(line.rows.map(\.product.productId), ["weller-sr"])
        XCTAssertEqual(line.rows.first?.standing, .never)
    }
}
