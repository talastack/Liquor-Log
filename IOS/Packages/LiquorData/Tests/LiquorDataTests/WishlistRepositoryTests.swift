import XCTest
import GRDB
import LiquorEngine
@testable import LiquorData

/// Buying from the wishlist is one transaction: the bottle appears and the
/// wish disappears together, or neither happens. A list that still shows a
/// bottle you now own is the drift that makes people stop trusting it.
final class WishlistRepositoryTests: XCTestCase {

    private var db: AppDatabase!
    private var wishlist: WishlistRepository!
    private var bottles: BottleRepository!

    override func setUpWithError() throws {
        db = try AppDatabase.inMemory()
        wishlist = WishlistRepository(db)
        bottles = BottleRepository(db)
    }

    func testBuyingACatalogueWishMakesABottleAndClearsTheWish() throws {
        let wish = try wishlist.add(catalogProductId: "ec-barrel-proof", targetPriceCents: 7_000)

        let bought = try wishlist.buy(
            wish,
            as: Bottle(purchasePriceCents: 6_499, purchaseStore: "Total Wine"))

        XCTAssertEqual(bought.catalogProductId, "ec-barrel-proof")
        XCTAssertEqual(try wishlist.items().count, 0)
        let shelf = try bottles.summaries()
        XCTAssertEqual(shelf.count, 1)
        XCTAssertEqual(shelf.first?.bottle.purchaseStore, "Total Wine")
        XCTAssertEqual(shelf.first?.bottle.purchasePriceCents, 6_499)
    }

    /// A wish that was only a typed name becomes a private product AND a
    /// bottle, so the shelf check answers for it like any other bottle.
    func testBuyingATypedWishCreatesItsProductInTheSameTransaction() throws {
        let wish = try wishlist.add(customName: "Jefferson's Ocean")
        let product = CustomCatalogEntry(
            distillery: "Jefferson's", brand: "Jefferson's", expression: "Ocean",
            classType: .bourbon)

        let bought = try wishlist.buy(wish, as: Bottle(), creating: product)

        XCTAssertEqual(bought.catalogProductId, product.id)
        XCTAssertNotNil(try bottles.customProduct(id: product.id))
        XCTAssertEqual(try wishlist.items().count, 0)

        let holdings = try bottles.holdings { id in
            (try? self.bottles.customProduct(id: id)).flatMap { custom in
                ProductIdentity(
                    productId: custom.id, distillery: custom.distillery,
                    brand: custom.brand, expression: custom.expression,
                    classType: custom.classType, productionType: custom.productionType)
            }
        }
        XCTAssertEqual(holdings.first?.product.expression, "Ocean")
    }

    /// Reviving a removed wish rather than inserting a second row.
    func testAddingARemovedProductRevivesTheSameRow() throws {
        let first = try wishlist.add(catalogProductId: "ec-barrel-proof")
        try wishlist.remove(id: first.id)
        XCTAssertEqual(try wishlist.items().count, 0)

        let again = try wishlist.add(catalogProductId: "ec-barrel-proof", targetPriceCents: 5_000)
        XCTAssertEqual(again.id, first.id)
        XCTAssertEqual(try wishlist.items().count, 1)
    }
}
