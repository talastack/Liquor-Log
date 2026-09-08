import XCTest
@testable import LiquorEngine

/// The screen this app is actually for: standing in a shop with a bottle in
/// hand, offline, asking whether you already have it.
final class ShelfCheckTests: XCTestCase {

    // Two expressions of one line. Same distillery, same brand, different
    // whiskey -- which is the whole difficulty.
    private let smallBatch = ProductIdentity(
        productId: "ec-small-batch",
        distillery: "Heaven Hill",
        brand: "Elijah Craig",
        expression: "Small Batch",
        classType: .kentuckyStraightBourbon,
        productionType: .smallBatch
    )

    private let barrelProof = ProductIdentity(
        productId: "ec-barrel-proof",
        distillery: "Heaven Hill",
        brand: "Elijah Craig",
        expression: "Barrel Proof",
        classType: .kentuckyStraightBourbon,
        productionType: .smallBatch
    )

    private let unrelated = ProductIdentity(
        productId: "fr-single-barrel",
        distillery: "Four Roses",
        brand: "Four Roses",
        expression: "Single Barrel",
        classType: .kentuckyStraightBourbon,
        productionType: .singleBarrel
    )

    private func date(_ day: Int) -> Date {
        Date(timeIntervalSince1970: Double(day) * 86_400)
    }

    // MARK: - The case a merged product/release model gets wrong

    /// The regression test named in the plan. Owning the Small Batch must NOT
    /// make the Barrel Proof read as owned -- they are different whiskey -- and
    /// must NOT make it read as never had, because knowing you already like the
    /// line is exactly what you want to see in the aisle.
    func testOwningTheSmallBatchDoesNotMeanYouOwnTheBarrelProof() {
        let result = ShelfCheck.evaluate(
            product: barrelProof,
            holdings: [Holding(bottleId: "b1", product: smallBatch)],
            tastings: []
        )

        XCTAssertEqual(result.headline, .haveTheLineNotThisRelease)
        XCTAssertNotEqual(result.headline, .onYourShelf)
        XCTAssertNotEqual(result.headline, .neverHadIt)
        XCTAssertTrue(result.onShelf.isEmpty)
        XCTAssertEqual(result.sameLine.map(\.productId), ["ec-small-batch"])
    }

    /// The other half of the same regression: a tasting on the sibling must not
    /// bleed onto this product, while the sibling itself still reports its own
    /// rating.
    func testATastingOnTheSiblingDoesNotAttachToThisRelease() {
        let holdings = [Holding(bottleId: "b1", product: smallBatch)]
        let tastings = [
            TastingRecord(
                tastingId: "t1",
                product: smallBatch,
                tastedAt: date(1),
                rating: 8,
                liked: "toffee"
            )
        ]

        let onBarrelProof = ShelfCheck.evaluate(
            product: barrelProof, holdings: holdings, tastings: tastings
        )
        XCTAssertEqual(onBarrelProof.headline, .haveTheLineNotThisRelease)
        XCTAssertFalse(onBarrelProof.hasTasted)
        XCTAssertNil(onBarrelProof.bestRating)

        let onSmallBatch = ShelfCheck.evaluate(
            product: smallBatch, holdings: holdings, tastings: tastings
        )
        XCTAssertEqual(onSmallBatch.headline, .onYourShelf)
        XCTAssertEqual(onSmallBatch.bestRating, 8)
        XCTAssertEqual(onSmallBatch.latestTasting?.liked, "toffee")
    }

    // MARK: - The four verdicts

    func testNeverHadItWhenNothingRelates() {
        let result = ShelfCheck.evaluate(
            product: barrelProof,
            holdings: [Holding(bottleId: "b1", product: unrelated)],
            tastings: []
        )
        XCTAssertEqual(result.headline, .neverHadIt)
        XCTAssertTrue(result.sameLine.isEmpty)
    }

    func testOnYourShelfReportsOpenBottles() {
        let result = ShelfCheck.evaluate(
            product: barrelProof,
            holdings: [
                Holding(bottleId: "b1", product: barrelProof, releaseLabel: "B523", isOpen: true),
                Holding(bottleId: "b2", product: barrelProof, releaseLabel: "C923")
            ],
            tastings: []
        )
        XCTAssertEqual(result.headline, .onYourShelf)
        XCTAssertEqual(result.onShelf.count, 2)
        XCTAssertEqual(result.openBottleCount, 1)
    }

    func testHadItBeforeWhenTheBottleIsFinished() {
        let result = ShelfCheck.evaluate(
            product: barrelProof,
            holdings: [Holding(bottleId: "b1", product: barrelProof, isFinished: true)],
            tastings: []
        )
        XCTAssertEqual(result.headline, .hadItBefore)
        XCTAssertTrue(result.onShelf.isEmpty)
        XCTAssertEqual(result.finished.count, 1)
    }

    /// The bar pour. You tasted it, you never owned it, and the app has to be
    /// able to say so -- which is why tastings hang off a product rather than a
    /// bottle.
    func testTastedNeverOwned() {
        let result = ShelfCheck.evaluate(
            product: barrelProof,
            holdings: [],
            tastings: [
                TastingRecord(
                    tastingId: "t1",
                    product: barrelProof,
                    tastedAt: date(1),
                    rating: 9,
                    disliked: "too hot neat"
                )
            ]
        )
        XCTAssertEqual(result.headline, .tastedNeverOwned)
        XCTAssertTrue(result.hasTasted)
        XCTAssertEqual(result.bestRating, 9)
        XCTAssertEqual(result.latestTasting?.disliked, "too hot neat")
    }

    // MARK: - Ownership and tasting are independent

    /// Owning something unopened you have never tried is an ordinary state, and
    /// the headline must not imply a verdict you never gave.
    func testOwnedButNeverTastedReportsNoRating() {
        let result = ShelfCheck.evaluate(
            product: barrelProof,
            holdings: [Holding(bottleId: "b1", product: barrelProof)],
            tastings: []
        )
        XCTAssertEqual(result.headline, .onYourShelf)
        XCTAssertFalse(result.hasTasted)
        XCTAssertNil(result.bestRating)
    }

    func testLatestTastingWinsOverTheFirst() {
        let result = ShelfCheck.evaluate(
            product: barrelProof,
            holdings: [],
            tastings: [
                TastingRecord(tastingId: "old", product: barrelProof, tastedAt: date(1), rating: 6),
                TastingRecord(tastingId: "new", product: barrelProof, tastedAt: date(9), rating: 8)
            ]
        )
        XCTAssertEqual(result.latestTasting?.tastingId, "new")
        XCTAssertEqual(result.bestRating, 8)
    }

    func testWishlistIsReported() {
        let result = ShelfCheck.evaluate(
            product: barrelProof,
            holdings: [],
            tastings: [],
            wishlistProductIds: ["ec-barrel-proof"]
        )
        XCTAssertEqual(result.headline, .neverHadIt)
        XCTAssertTrue(result.isOnWishlist)
    }

    func testSameLineIsDeduplicatedAndOrdered() {
        let eighteen = ProductIdentity(
            productId: "ec-18",
            distillery: "Heaven Hill",
            brand: "Elijah Craig",
            expression: "18 Year",
            classType: .kentuckyStraightBourbon
        )
        let result = ShelfCheck.evaluate(
            product: barrelProof,
            holdings: [
                Holding(bottleId: "b1", product: smallBatch),
                Holding(bottleId: "b2", product: smallBatch),
                Holding(bottleId: "b3", product: eighteen)
            ],
            tastings: [
                TastingRecord(tastingId: "t1", product: smallBatch, tastedAt: date(1))
            ]
        )
        XCTAssertEqual(result.sameLine.map(\.expression), ["18 Year", "Small Batch"])
    }

    func testLineMatchingIgnoresPunctuationAndCase() {
        let messy = ProductIdentity(
            productId: "ec-toasted",
            distillery: "heaven-hill",
            brand: "ELIJAH  CRAIG",
            expression: "Toasted Barrel",
            classType: .kentuckyStraightBourbon
        )
        XCTAssertEqual(messy.lineKey, barrelProof.lineKey)
    }
}
