import XCTest
@testable import LiquorEngine

/// Ten staves of five kinds. A recipe that does not total ten is a typo.
final class StaveRecipeTests: XCTestCase {

    func testTheLabelsCompactForm() throws {
        let recipe = try XCTUnwrap(StaveRecipe("P2×3 Cu×2 46×2 Mo×1 Sp×2"))
        XCTAssertEqual(recipe.count(of: .bakedAmericanPure2), 3)
        XCTAssertEqual(recipe.count(of: .roastedFrenchMocha), 1)
        XCTAssertEqual(recipe.code, "P2×3 Cu×2 46×2 Mo×1 Sp×2")
    }

    func testLooseSpellingsRead() throws {
        XCTAssertEqual(StaveRecipe("p2x3, cu x 2, 46x2, mo x1, sp x2"), StaveRecipe("P2×3 Cu×2 46×2 Mo×1 Sp×2"))
        let all46 = try XCTUnwrap(StaveRecipe("46x10"))
        XCTAssertEqual(all46.code, "46×10")
    }

    func testMustTotalTen() {
        XCTAssertNil(StaveRecipe("P2×3 Cu×2"))
        XCTAssertNil(StaveRecipe("P2×11"))
        XCTAssertNil(StaveRecipe(counts: [.makers46: 5, .roastedFrenchMocha: 6]))
        XCTAssertNil(StaveRecipe(""))
    }

    func testZerosAreDropped() throws {
        let recipe = try XCTUnwrap(StaveRecipe(counts: [.makers46: 10, .toastedFrenchSpice: 0]))
        XCTAssertEqual(recipe.counts.count, 1)
    }

    func testLeaning() throws {
        XCTAssertTrue(try XCTUnwrap(StaveRecipe("46x10")).leaning.hasPrefix("All Maker's 46"))
        let spread = try XCTUnwrap(StaveRecipe("P2×3 Cu×2 46×2 Mo×1 Sp×2"))
        XCTAssertTrue(spread.leaning.hasPrefix("Led by Baked American Pure 2 (3 of 10)"))
        let tie = try XCTUnwrap(StaveRecipe("Mo×5 Sp×5"))
        XCTAssertTrue(tie.leaning.hasPrefix("Led equally by Roasted French Mocha and Toasted French Spice"))
    }

    func testComparison() throws {
        let mine = try XCTUnwrap(StaveRecipe("P2×3 Cu×2 46×2 Mo×3"))
        let theirs = try XCTUnwrap(StaveRecipe("P2×3 Cu×2 46×2 Mo×1 Sp×2"))
        let comparison = StaveRecipe.compare(mine, theirs)
        XCTAssertEqual(comparison.shared, [.bakedAmericanPure2, .searedFrenchCuvee, .makers46, .roastedFrenchMocha])
        XCTAssertEqual(comparison.moreInFirst.first?.0, .roastedFrenchMocha)
        XCTAssertEqual(comparison.moreInFirst.first?.1, 2)
        XCTAssertEqual(comparison.moreInSecond.first?.0, .toastedFrenchSpice)
        XCTAssertEqual(comparison.text, "The first leans more to Roasted French Mocha (+2); the second to Toasted French Spice (+2).")
        XCTAssertTrue(StaveRecipe.compare(mine, mine).isIdentical)
    }
}
