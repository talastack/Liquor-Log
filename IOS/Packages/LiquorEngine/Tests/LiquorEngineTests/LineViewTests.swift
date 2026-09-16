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

    /// A sample of an expression is its own standing: not owned, not
    /// history, on hand tonight.
    func testASampleIsItsOwnStanding() {
        let product = ProductIdentity(
            productId: "w12", distillery: "Buffalo Trace", brand: "W. L. Weller",
            expression: "12 Year", classType: .kentuckyStraightBourbon, productionType: .unspecified)
        let line = LineView.line(
            of: product, catalogue: [product],
            holdings: [Holding(bottleId: "s", product: product, isSample: true)],
            tastings: [])
        XCTAssertEqual(line.rows.map(\.standing), [.sample])
    }

    // MARK: - Completion

    private func expression(_ id: String, _ name: String, brand: String = "W. L. Weller") -> ProductIdentity {
        ProductIdentity(
            productId: id, distillery: "Buffalo Trace", brand: brand, expression: name,
            classType: .kentuckyStraightBourbon, productionType: .unspecified)
    }

    /// A count of bottles against what the catalogue lists, never a goal.
    /// Owned, sampled and finished count; a tasting at a bar does not.
    func testTheLineCountsBottlesAgainstTheCatalogue() {
        let sr = expression("sr", "Special Reserve")
        let antique = expression("antique", "Antique 107")
        let twelve = expression("12", "12 Year")
        let full = expression("full", "Full Proof")
        let line = LineView.line(
            of: sr, catalogue: [sr, antique, twelve, full],
            holdings: [
                Holding(bottleId: "b", product: sr),
                Holding(bottleId: "s", product: antique, isSample: true),
                Holding(bottleId: "f", product: twelve, isFinished: true),
            ],
            tastings: [TastingRecord(tastingId: "t", product: full, tastedAt: Date(), rating: 8)])
        XCTAssertEqual(line.hadCount, 3, "the tasting of Full Proof is a drink, not a bottle")
        XCTAssertEqual(line.completionLine, "3 of the 4 releases the catalogue lists have been on your shelf.")
        XCTAssertEqual(line.notYet.map(\.productId), [])
    }

    func testAllAndNoneReadAsSuch() {
        let a = expression("a", "A"), b = expression("b", "B")
        let all = LineView.line(of: a, catalogue: [a, b],
                                holdings: [Holding(bottleId: "1", product: a), Holding(bottleId: "2", product: b)],
                                tastings: [])
        XCTAssertEqual(all.completionLine, "All 2 releases the catalogue lists have been on your shelf.")
        let none = LineView.line(of: a, catalogue: [a, b], holdings: [], tastings: [])
        XCTAssertEqual(none.completionLine, "None of the 2 releases the catalogue lists has been on your shelf yet.")
    }

    func testALineOfOneSaysNothingAboutCompletion() {
        let a = expression("a", "A")
        let line = LineView.line(of: a, catalogue: [a], holdings: [Holding(bottleId: "1", product: a)], tastings: [])
        XCTAssertNil(line.completionLine)
    }

    func testCompletionsListEveryLineYouHaveSomethingOfMostCompleteFirst() {
        let w1 = expression("w1", "Special Reserve"), w2 = expression("w2", "Antique"), w3 = expression("w3", "12")
        let s1 = expression("s1", "Jr", brand: "Stagg"), s2 = expression("s2", "Sr", brand: "Stagg")
        let lone = expression("l", "", brand: "Lonely")
        let e1 = expression("e1", "Small Batch", brand: "Elijah Craig"), e2 = expression("e2", "18", brand: "Elijah Craig")
        let completions = LineView.completions(
            catalogue: [w1, w2, w3, s1, s2, lone, e1, e2],
            holdings: [Holding(bottleId: "a", product: w1), Holding(bottleId: "b", product: w2),
                       Holding(bottleId: "c", product: s1), Holding(bottleId: "d", product: s2),
                       Holding(bottleId: "e", product: lone)])
        XCTAssertEqual(completions.map(\.brand), ["Stagg", "W. L. Weller"])
        XCTAssertEqual(completions.map(\.had), [2, 2])
        XCTAssertEqual(completions.map(\.total), [2, 3])
    }
}
