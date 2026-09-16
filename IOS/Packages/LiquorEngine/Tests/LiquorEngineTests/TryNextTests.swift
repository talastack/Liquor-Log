import XCTest
@testable import LiquorEngine

/// Suggestions with their reasons on the screen, from what you rated
/// well, never from what you already have.
final class TryNextTests: XCTestCase {

    private func product(_ id: String, _ distillery: String, _ brand: String, _ expression: String) -> ProductIdentity {
        ProductIdentity(productId: id, distillery: distillery, brand: brand, expression: expression,
                        classType: .kentuckyStraightBourbon, productionType: .unspecified)
    }

    private let w12 = ProductIdentity(productId: "w12", distillery: "Buffalo Trace", brand: "W. L. Weller",
                                      expression: "12 Year", classType: .kentuckyStraightBourbon, productionType: .unspecified)
    private var wsr: ProductIdentity { product("wsr", "Buffalo Trace", "W. L. Weller", "Special Reserve") }
    private var antique: ProductIdentity { product("antique", "Buffalo Trace", "W. L. Weller", "Antique 107") }
    private var eagle: ProductIdentity { product("eagle", "Buffalo Trace", "Eagle Rare", "10 Year") }
    private var makers: ProductIdentity { product("makers", "Maker's Mark", "Maker's Mark", "") }
    private var ecbp: ProductIdentity { product("ecbp", "Heaven Hill", "Elijah Craig", "Barrel Proof") }

    private var catalogue: [SearchCandidate] {
        [
            SearchCandidate(product: w12, mashbillKey: "wheated"),
            SearchCandidate(product: wsr, mashbillKey: "wheated"),
            SearchCandidate(product: antique, mashbillKey: "wheated"),
            SearchCandidate(product: eagle),
            SearchCandidate(product: makers, mashbillKey: "wheated"),
            SearchCandidate(product: ecbp),
        ]
    }

    func testTheLineComesFirstThenMashbillThenDistilleryAndEachSaysWhy() {
        let suggestions = TryNext.suggest(
            liked: [TryNext.Liked(product: w12, rating: 9, mashbillKey: "wheated")],
            catalogue: catalogue, had: ["w12"])
        XCTAssertEqual(suggestions.map(\.product.productId), ["antique", "wsr", "makers", "eagle"])
        XCTAssertEqual(suggestions.first?.why, "Same line as W. L. Weller 12 Year, which you rated 9.")
        XCTAssertEqual(suggestions.last?.reason, .sameDistillery)
        XCTAssertEqual(suggestions[2].reason, .sameRecipe, "a shared mashbill reads as the same recipe")
    }

    func testWhatYouHaveHadIsNotASuggestion() {
        let suggestions = TryNext.suggest(
            liked: [TryNext.Liked(product: w12, rating: 9)],
            catalogue: catalogue, had: ["w12", "wsr", "antique"])
        XCTAssertEqual(suggestions.map(\.product.productId), ["eagle"])
    }

    func testOnlyBottlesRatedWellAreSources() {
        let suggestions = TryNext.suggest(
            liked: [TryNext.Liked(product: w12, rating: 5)],
            catalogue: catalogue, had: [])
        XCTAssertTrue(suggestions.isEmpty)
    }

    /// A product reachable from two of your bottles is listed once, under
    /// the better-rated one.
    func testAProductIsSuggestedOnceUnderTheHigherRating() {
        let suggestions = TryNext.suggest(
            liked: [TryNext.Liked(product: eagle, rating: 7), TryNext.Liked(product: w12, rating: 9)],
            catalogue: catalogue, had: ["eagle", "w12"])
        let wsr = suggestions.first { $0.product.productId == "wsr" }
        XCTAssertEqual(wsr?.because.productId, "w12")
        XCTAssertEqual(suggestions.filter { $0.product.productId == "wsr" }.count, 1)
    }

    func testTheLimitHolds() {
        let suggestions = TryNext.suggest(
            liked: [TryNext.Liked(product: w12, rating: 9, mashbillKey: "wheated")],
            catalogue: catalogue, had: ["w12"], limit: 2)
        XCTAssertEqual(suggestions.count, 2)
    }
}
