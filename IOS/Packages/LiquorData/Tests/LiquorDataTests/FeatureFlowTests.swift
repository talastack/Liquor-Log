import XCTest
import GRDB
import LiquorEngine
@testable import LiquorData

/// Whole features, end to end across the engine and the database, the way
/// the screens drive them. Each one is a path a person actually takes, and
/// each was chosen because a unit test of either layer alone would pass
/// while the feature was a dud.
final class FeatureFlowTests: XCTestCase {

    private var db: AppDatabase!
    private var bottles: BottleRepository!
    private var tastings: TastingRepository!
    private var wishlist: WishlistRepository!

    override func setUpWithError() throws {
        db = try AppDatabase.inMemory()
        bottles = BottleRepository(db)
        tastings = TastingRepository(db)
        wishlist = WishlistRepository(db)
    }

    /// The resolver the app uses: catalogue first, then a typed-in product.
    /// Here there is no bundled catalogue, so only the second half applies.
    private func identity(_ id: String) -> ProductIdentity? {
        guard let custom = try? bottles.customProduct(id: id), custom.deletedAt == nil else { return nil }
        return ProductIdentity(
            productId: custom.id, distillery: custom.distillery, brand: custom.brand,
            expression: custom.expression, classType: custom.classType,
            productionType: custom.productionType)
    }

    // MARK: - A typed-in bottle answers the shelf check

    func testATypedInBottleReadsOnYourShelf() throws {
        let entry = CustomCatalogEntry(distillery: "Jefferson's", brand: "Jefferson's", expression: "Ocean", classType: .bourbon)
        let saved = try bottles.addCustom(product: entry, bottle: Bottle())

        let holdings = try bottles.holdings { self.identity($0) }
        let records = try tastings.records { self.identity($0) }
        let verdict = ShelfCheck.evaluate(
            product: identity(saved.product.id)!, holdings: holdings, tastings: records)
        XCTAssertEqual(verdict.headline, .onYourShelf)
        XCTAssertEqual(verdict.onShelf.count, 1)
    }

    // MARK: - Pours, the fill, and the nearly-gone offer

    func testPoursRunTheFillDownAndTheOfferFiresOnce() throws {
        // A 150 ml bottle is three standard pours (150 / 44.36 = 3.4 -> 3).
        let bottle = try bottles.add(Bottle(volumeMl: 150))
        var offers: [Replenish.Offer] = []
        for _ in 0..<3 {
            let before = try bottles.summary(id: bottle.id)!.status.remainingPours
            _ = try bottles.logPour(bottleId: bottle.id)
            let after = try bottles.summary(id: bottle.id)!.status.remainingPours
            if let offer = Replenish.offer(
                remainingBefore: before, remainingAfter: after, isOnWishlist: false, wouldRebuy: nil) {
                offers.append(offer)
            }
        }
        XCTAssertEqual(offers.count, 1, "asked once, on the crossing pour")
        XCTAssertEqual(offers.first?.remainingPours, 2)
        // Three full pours leave 16.9 ml: less than a pour, not empty, and
        // the screen says so rather than showing "0 pours" and reading as
        // empty. Only a pour into that remainder is clamped.
        let status = try bottles.summary(id: bottle.id)!.status
        XCTAssertEqual(status.remainingMilliliters, 150 - 3 * PourSize.standard.milliliters, accuracy: 0.01)
        XCTAssertTrue(status.hasPartialPourOnly)
        _ = try bottles.logPour(bottleId: bottle.id)
        XCTAssertTrue(try bottles.summary(id: bottle.id)!.status.isEmpty)
    }

    // MARK: - Tastings on pours become a trend

    func testTastingsPinnedToPoursMakeATrend() throws {
        let bottle = try bottles.add(Bottle())
        let first = try bottles.logPour(bottleId: bottle.id)
        try tastings.save(Tasting(bottleId: bottle.id, pourId: first.id, tastedAt: 1_000, rating: 6))
        let second = try bottles.logPour(bottleId: bottle.id)
        try tastings.save(Tasting(bottleId: bottle.id, pourId: second.id, tastedAt: 1_000 + 40 * 86_400_000, rating: 8))

        let history = try tastings.history(bottleId: bottle.id)
        XCTAssertEqual(history.count, 2)
        let trend = TastingTrend.summarise(history.compactMap { detail in
            detail.tasting.rating.map {
                TastingTrend.Point(
                    tastedAt: Date(timeIntervalSince1970: Double(detail.tasting.tastedAt) / 1000),
                    rating: $0)
            }
        })
        XCTAssertEqual(trend?.direction, .openedUp)
        XCTAssertEqual(trend?.text, "Opened up: 6 to 8 over 40 days.")
    }

    // MARK: - Wishlist to shelf

    func testBuyingAWishPutsItOnTheShelfAndTheShelfCheckAgrees() throws {
        let wish = try wishlist.add(customName: "Weller 12", targetPriceCents: 5_000)
        let product = CustomCatalogEntry(distillery: "Buffalo Trace", brand: "W L Weller", expression: "12 Year", classType: .kentuckyStraightBourbon)
        let bought = try wishlist.buy(wish, as: Bottle(purchasePriceCents: 4_999), creating: product)

        XCTAssertTrue(try wishlist.items().isEmpty)
        let holdings = try bottles.holdings { self.identity($0) }
        let verdict = ShelfCheck.evaluate(product: identity(bought.catalogProductId!)!, holdings: holdings, tastings: [])
        XCTAssertEqual(verdict.headline, .onYourShelf)
    }

    // MARK: - Ask finds a typed-in bottle

    func testAskUnderstandsATypedInBottle() throws {
        let entry = CustomCatalogEntry(distillery: "Jefferson's", brand: "Jefferson's", expression: "Ocean", classType: .bourbon)
        let saved = try bottles.addCustom(product: entry, bottle: Bottle())
        let candidates = try bottles.customProducts().map { custom in
            SearchCandidate(product: identity(custom.id)!, isInYourHistory: true)
        }
        guard case .command(.pour(let subject, _)) = Ask.understand("log a pour of jefferson's ocean", catalog: candidates) else {
            return XCTFail("expected a pour")
        }
        XCTAssertEqual(subject.best?.productId, saved.product.id)
    }

    // MARK: - Export re-imports

    /// The export writes CRLF for Excel, and the reader once collapsed a
    /// CRLF file into one row. This is the pair, end to end.
    func testTheExportReadsBackRowForRow() throws {
        _ = try bottles.add(Bottle(customName: "One, with a comma", purchasePriceCents: 1_000))
        _ = try bottles.add(Bottle(customName: "Two \"quoted\""))
        _ = try bottles.add(Bottle(customName: "Three"))

        let csv = try CollectionExport(db).csv(
            resolveName: { $0.customName ?? "?" },
            resolveIdentity: { _ in nil })
        let (header, rows) = CSVReader.records(csv)
        XCTAssertEqual(header.count, CollectionExport.header.count)
        XCTAssertEqual(rows.count, 3)
        XCTAssertEqual(Set(rows.map { $0["name"] ?? "" }), ["One, with a comma", "Two \"quoted\"", "Three"])
    }

    // MARK: - Relink then shelf check

    func testRelinkedBottleAnswersForTheCatalogueProduct() throws {
        let entry = CustomCatalogEntry(distillery: "Weller 12", brand: "Weller 12", classType: .bourbon)
        let saved = try bottles.addCustom(product: entry, bottle: Bottle())
        try bottles.relinkCustomProduct(id: saved.product.id, to: "weller-12")

        let weller = ProductIdentity(
            productId: "weller-12", distillery: "Buffalo Trace", brand: "W L Weller",
            expression: "12 Year", classType: .kentuckyStraightBourbon)
        let holdings = try bottles.holdings { id in id == "weller-12" ? weller : nil }
        XCTAssertEqual(ShelfCheck.evaluate(product: weller, holdings: holdings, tastings: []).headline, .onYourShelf)
        XCTAssertNil(identity(saved.product.id), "the typed-in product is retired")
    }
}
