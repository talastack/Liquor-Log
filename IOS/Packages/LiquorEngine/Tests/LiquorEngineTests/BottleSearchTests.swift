import XCTest
@testable import LiquorEngine

final class BottleSearchTests: XCTestCase {

    private func product(
        _ id: String,
        _ distillery: String,
        _ brand: String,
        _ expression: String
    ) -> ProductIdentity {
        ProductIdentity(
            productId: id,
            distillery: distillery,
            brand: brand,
            expression: expression,
            classType: .kentuckyStraightBourbon
        )
    }

    private lazy var ecSmallBatch = product("ec-sb", "Heaven Hill", "Elijah Craig", "Small Batch")
    private lazy var ecBarrelProof = product("ec-bp", "Heaven Hill", "Elijah Craig", "Barrel Proof")
    private lazy var wellerSpecial = product("wl-sr", "Buffalo Trace", "W L Weller", "Special Reserve")
    private lazy var wellerAntique = product("wl-107", "Buffalo Trace", "W L Weller", "Antique 107")
    private lazy var eagleRare = product("er-10", "Buffalo Trace", "Eagle Rare", "10 Year")
    private lazy var fourRoses = product("fr-sb", "Four Roses", "Four Roses", "Single Barrel")

    private var catalog: [SearchCandidate] {
        [
            SearchCandidate(product: ecSmallBatch),
            SearchCandidate(product: ecBarrelProof),
            SearchCandidate(product: wellerSpecial),
            SearchCandidate(product: wellerAntique),
            SearchCandidate(product: eagleRare),
            SearchCandidate(product: fourRoses, recipeCode: RecipeCode("OESQ"))
        ]
    }

    // MARK: - Typing

    func testEmptyQueryReturnsNothing() {
        XCTAssertTrue(BottleSearch.search(query: "   ", in: catalog).isEmpty)
    }

    func testExactNameScoresHighest() {
        let hits = BottleSearch.search(query: "Elijah Craig Barrel Proof", in: catalog)
        XCTAssertEqual(hits.first?.product.productId, "ec-bp")
        XCTAssertEqual(hits.first?.reason, .exact)
    }

    /// Abbreviated typing, which is what actually happens one-handed in a shop.
    func testAbbreviatedTokensStillFindTheBottle() {
        let hits = BottleSearch.search(query: "eli cra bar", in: catalog)
        XCTAssertEqual(hits.first?.product.productId, "ec-bp")
        XCTAssertEqual(hits.first?.reason, .prefix)
    }

    func testDistilleryNameMatchesToo() {
        let ids = BottleSearch.search(query: "buffalo trace", in: catalog).map(\.product.productId)
        XCTAssertTrue(ids.contains("wl-sr"))
        XCTAssertTrue(ids.contains("er-10"))
        XCTAssertFalse(ids.contains("ec-sb"))
    }

    func testTyposStillMatch() {
        let hits = BottleSearch.search(query: "elijah craig smal batch", in: catalog)
        XCTAssertEqual(hits.first?.product.productId, "ec-sb")
    }

    func testNonsenseMatchesNothing() {
        XCTAssertTrue(BottleSearch.search(query: "zzzzqqqq", in: catalog).isEmpty)
    }

    /// The bottle you are typing is usually one you have had before.
    func testYourHistoryOutranksAnEquallyGoodCatalogRow() {
        let withHistory = [
            SearchCandidate(product: ecSmallBatch, isInYourHistory: false),
            SearchCandidate(product: ecBarrelProof, isInYourHistory: true)
        ]
        let hits = BottleSearch.search(query: "elijah craig", in: withHistory)
        XCTAssertEqual(hits.first?.product.productId, "ec-bp")
    }

    func testResultsAreOrderedStablyOnTies() {
        let first = BottleSearch.search(query: "weller", in: catalog).map(\.product.productId)
        let second = BottleSearch.search(query: "weller", in: catalog).map(\.product.productId)
        XCTAssertEqual(first, second)
    }

    func testLimitIsRespected() {
        XCTAssertEqual(BottleSearch.search(query: "e", in: catalog, limit: 2).count, 2)
    }

    // MARK: - Related, which is structural rather than textual

    /// Typing Weller surfaces the other Weller, and then the rest of the
    /// distillery. String similarity alone would never connect Weller to Eagle
    /// Rare, which is the point of a separate relatedness pass.
    func testRelatedFindsTheLineThenTheDistillery() {
        let hits = BottleSearch.related(to: wellerSpecial, in: catalog)
        XCTAssertEqual(hits.first?.product.productId, "wl-107")
        XCTAssertEqual(hits.first?.reason, .sameLine)

        let eagle = hits.first { $0.product.productId == "er-10" }
        XCTAssertEqual(eagle?.reason, .sameDistillery)
    }

    func testRelatedExcludesTheProductItself() {
        let hits = BottleSearch.related(to: wellerSpecial, in: catalog)
        XCTAssertFalse(hits.contains { $0.product.productId == "wl-sr" })
    }

    /// An OESQ pick surfaces the other bottles of that recipe.
    func testRelatedMatchesOnRecipeCode() {
        let anotherOESQ = product("fr-pick", "Four Roses", "Four Roses", "Store Pick")
        let extended = catalog + [
            SearchCandidate(product: anotherOESQ, recipeCode: RecipeCode("OESQ"))
        ]
        let hits = BottleSearch.related(
            to: product("other", "Wild Turkey", "Wild Turkey", "101"),
            recipeCode: RecipeCode("OESQ"),
            in: extended
        )
        XCTAssertTrue(hits.contains { $0.product.productId == "fr-pick" && $0.reason == .sameRecipe })
    }

    func testUnrelatedProductsAreNotReturned() {
        let hits = BottleSearch.related(to: fourRoses, in: catalog)
        XCTAssertFalse(hits.contains { $0.product.productId == "ec-sb" })
    }

    // MARK: - Primitives

    func testNormalisationCollapsesPunctuationAndCase() {
        XCTAssertEqual(
            "Elijah Craig Barrel-Proof (B523)".normalizedForMatching(),
            "elijah craig barrel proof b523"
        )
    }

    func testLevenshteinBasics() {
        XCTAssertEqual(BottleSearch.levenshtein("", ""), 0)
        XCTAssertEqual(BottleSearch.levenshtein("abc", ""), 3)
        XCTAssertEqual(BottleSearch.levenshtein("", "abc"), 3)
        XCTAssertEqual(BottleSearch.levenshtein("kitten", "sitting"), 3)
        XCTAssertEqual(BottleSearch.levenshtein("same", "same"), 0)
    }

    func testSimilarityIsBounded() {
        XCTAssertEqual(BottleSearch.similarity("", ""), 1.0, accuracy: 0.0001)
        XCTAssertEqual(BottleSearch.similarity("abc", "abc"), 1.0, accuracy: 0.0001)
        XCTAssertEqual(BottleSearch.similarity("abc", "xyz"), 0.0, accuracy: 0.0001)
    }
}
