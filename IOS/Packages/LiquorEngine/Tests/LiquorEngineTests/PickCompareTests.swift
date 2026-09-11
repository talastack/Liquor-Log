import XCTest
@testable import LiquorEngine

/// A pick beside its standard release. These pin the restraint: a row only
/// exists when both sides have something to say, and the difference is a
/// phrase about the numbers, never a judgement.
final class PickCompareTests: XCTestCase {

    /// A Four Roses OESQ store pick at barrel proof next to the 100-proof
    /// shelf single barrel, which is OBSV.
    private var fourRoses: PickCompare.Comparison {
        PickCompare.compare(
            pick: PickCompare.Pick(
                abv: 58.7, ageMonths: 112, recipeCode: "OESQ", paidCents: 8_999, rating: 9),
            standard: PickCompare.Standard(
                abv: 50, statedAgeYears: 7, recipeCode: "OBSV",
                priceCents: 4_999, priceLabel: "Virginia ABC", rating: 7))
    }

    func testEveryRowWhenBothSidesAreKnown() {
        XCTAssertEqual(fourRoses.rows.map(\.field), [.proof, .age, .recipe, .price, .rating])
    }

    func testProofRow() throws {
        let row = try XCTUnwrap(fourRoses.rows.first { $0.field == .proof })
        XCTAssertEqual(row.pick, "117.4")
        XCTAssertEqual(row.standard, "100.0")
        XCTAssertEqual(row.difference, "+17.4 proof")
        XCTAssertEqual(row.delta ?? 0, 17.4, accuracy: 0.01)
    }

    func testAgeRowSpeaksInMonthsForThePick() throws {
        let row = try XCTUnwrap(fourRoses.rows.first { $0.field == .age })
        XCTAssertEqual(row.pick, "9 years 4 months")
        XCTAssertEqual(row.standard, "7 years")
        XCTAssertEqual(row.difference, "+2.3 years")
    }

    func testRecipeRowSaysWhatDiffers() throws {
        let row = try XCTUnwrap(fourRoses.rows.first { $0.field == .recipe })
        // OESQ vs OBSV: E vs B mashbill, Q vs V yeast.
        XCTAssertEqual(row.difference, "different mashbill, different yeast")
        XCTAssertNil(row.delta)
    }

    func testPriceRow() throws {
        let row = try XCTUnwrap(fourRoses.rows.first { $0.field == .price })
        XCTAssertEqual(row.pick, "$89.99")
        XCTAssertEqual(row.standard, "$49.99 (Virginia ABC)")
        XCTAssertEqual(row.difference, "$40.00 more")
    }

    func testRatingRow() throws {
        let row = try XCTUnwrap(fourRoses.rows.first { $0.field == .rating })
        XCTAssertEqual(row.difference, "+2 for the pick")
    }

    /// A pick with nothing recorded compares to nothing. "Unknown" beside a
    /// number would read as a fact about the pick.
    func testNoRowWithoutBothSides() {
        let comparison = PickCompare.compare(
            pick: PickCompare.Pick(abv: 60),
            standard: PickCompare.Standard(statedAgeYears: 7, priceCents: 4_999))
        XCTAssertTrue(comparison.isEmpty)
    }

    func testSameValuesSaySo() {
        let comparison = PickCompare.compare(
            pick: PickCompare.Pick(abv: 50, ageMonths: 84, recipeCode: "obsv", paidCents: 4_999, rating: 7),
            standard: PickCompare.Standard(abv: 50, statedAgeYears: 7, recipeCode: "OBSV", priceCents: 4_999, rating: 7))
        XCTAssertEqual(comparison.rows.map(\.difference), [
            "same proof", "same age", "same recipe", "same price", "rated the same",
        ])
    }

    func testAPickBelowTheStandard() {
        let comparison = PickCompare.compare(
            pick: PickCompare.Pick(abv: 45, ageMonths: 66, paidCents: 3_999, rating: 5),
            standard: PickCompare.Standard(abv: 50, statedAgeYears: 7, priceCents: 4_999, rating: 7))
        XCTAssertEqual(comparison.rows.map(\.difference), [
            "−10.0 proof", "−18 months", "$10.00 less", "-2 for the pick",
        ])
    }

    func testSameYeastDifferentMashbill() {
        let comparison = PickCompare.compare(
            pick: PickCompare.Pick(recipeCode: "OESV"),
            standard: PickCompare.Standard(recipeCode: "OBSV"))
        XCTAssertEqual(comparison.rows.first?.difference, "different mashbill")
    }

    func testNonFourRosesRecipesAreJustDifferent() {
        let comparison = PickCompare.compare(
            pick: PickCompare.Pick(recipeCode: "wheated"),
            standard: PickCompare.Standard(recipeCode: "rye"))
        XCTAssertEqual(comparison.rows.first?.difference, "different recipe")
    }

    func testAgeDescription() {
        XCTAssertEqual(AgeMath.describe(months: 11), "11 months")
        XCTAssertEqual(AgeMath.describe(months: 12), "1 year")
        XCTAssertEqual(AgeMath.describe(months: 13), "1 year 1 month")
        XCTAssertEqual(AgeMath.describe(months: 150), "12 years 6 months")
    }
}
