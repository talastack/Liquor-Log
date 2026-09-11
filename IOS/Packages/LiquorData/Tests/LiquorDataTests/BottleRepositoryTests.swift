import XCTest
import GRDB
import LiquorEngine
@testable import LiquorData

/// The fill level is DERIVED from the pour log, so these tests are what stand
/// between the app and a number that quietly disagrees with its own history.
final class BottleRepositoryTests: XCTestCase {

    private var db: AppDatabase!
    private var bottles: BottleRepository!

    override func setUpWithError() throws {
        db = try AppDatabase.inMemory()
        bottles = BottleRepository(db)
    }

    private func addBottle(volume: Double = 750, price: Int? = nil) throws -> Bottle {
        try bottles.add(Bottle(
            catalogProductId: "ec-barrel-proof",
            volumeMl: volume,
            purchasePriceCents: price
        ))
    }

    // MARK: - Resolving custom products

    /// A typed-in bottle resolves by querying THIS database, so the resolver
    /// must run outside the read. Inside it, GRDB's re-entrancy check is a
    /// fatal error, and the shelf check crashed the moment somebody had a
    /// bottle the catalogue did not know. This test is the crash, made green.
    func testHoldingsResolveATypedInProductWithoutReEnteringTheDatabase() throws {
        let entry = CustomCatalogEntry(
            distillery: "Kentucky Artisan Distillery",
            brand: "Jefferson's",
            expression: "Ocean",
            classType: .bourbon)
        let saved = try bottles.addCustom(product: entry, bottle: Bottle(volumeMl: 750))

        let holdings = try bottles.holdings { id in
            // The same resolver the app uses: catalogue first, then a second
            // database read for a custom product.
            guard let custom = try? self.bottles.customProduct(id: id) else { return nil }
            return ProductIdentity(
                productId: custom.id,
                distillery: custom.distillery,
                brand: custom.brand,
                expression: custom.expression,
                classType: custom.classType,
                productionType: custom.productionType)
        }

        XCTAssertEqual(holdings.count, 1)
        XCTAssertEqual(holdings.first?.product.productId, saved.product.id)
        XCTAssertEqual(holdings.first?.product.brand, "Jefferson's")
    }

    // MARK: - Derivation

    func testFullBottleReadsSeventeenOfSeventeen() throws {
        let bottle = try addBottle()
        let summary = try XCTUnwrap(bottles.summary(id: bottle.id))
        XCTAssertEqual(summary.status.totalPours, 17)
        XCTAssertEqual(summary.status.remainingPours, 17)
        XCTAssertEqual(summary.status.remainingMilliliters, 750, accuracy: 0.001)
    }

    /// The canvas number, end to end through the database.
    func testFourPoursReadsThirteenOfSeventeen() throws {
        let bottle = try addBottle()
        for _ in 0..<4 { try bottles.logPour(bottleId: bottle.id) }

        let summary = try XCTUnwrap(bottles.summary(id: bottle.id))
        XCTAssertEqual(summary.status.remainingPours, 13)
        XCTAssertEqual(summary.status.totalPours, 17, "the denominator is capacity, not what is left")
        XCTAssertEqual(summary.status.remainingMilliliters, 572.56, accuracy: 0.01)
    }

    func testSevenHundredMillilitreBottleReadsSixteen() throws {
        let bottle = try addBottle(volume: 700)
        let summary = try XCTUnwrap(bottles.summary(id: bottle.id))
        XCTAssertEqual(summary.status.totalPours, 16)
    }

    /// A mis-logged pour is undone by tombstoning it, and the fill comes back.
    /// This is why the log is the source of truth and not a stored counter.
    func testRemovingAPourRestoresTheFill() throws {
        let bottle = try addBottle()
        let pour = try bottles.logPour(bottleId: bottle.id)
        XCTAssertEqual(try bottles.summary(id: bottle.id)?.status.remainingPours, 16)

        try db.queue.write { db in
            var p = try XCTUnwrap(Pour.filter(key: pour.id).fetchOne(db))
            p.softDelete()
            try p.save(db)
        }
        XCTAssertEqual(try bottles.summary(id: bottle.id)?.status.remainingPours, 17)
    }

    // MARK: - Pouring

    /// Nobody taps "open" and then "pour" as two separate acts, and a bottle
    /// with pours but no open date makes every age calculation lie.
    func testFirstPourOpensTheBottle() throws {
        let bottle = try addBottle()
        XCTAssertNil(bottle.openedAt)

        let pour = try bottles.logPour(bottleId: bottle.id)
        let reloaded = try XCTUnwrap(bottles.summary(id: bottle.id))
        XCTAssertEqual(reloaded.bottle.openedAt, pour.pouredAt)
        XCTAssertTrue(reloaded.bottle.isOpen)
    }

    func testOpeningTwiceKeepsTheFirstDate() throws {
        let bottle = try addBottle()
        try bottles.open(bottleId: bottle.id, at: 1_000)
        try bottles.open(bottleId: bottle.id, at: 9_999)
        XCTAssertEqual(try bottles.summary(id: bottle.id)?.bottle.openedAt, 1_000)
    }

    /// A bottle cannot owe you whiskey. The last pour is clamped to what is
    /// actually left rather than driving the fill negative.
    func testTheLastPourIsClampedToWhatRemains() throws {
        let bottle = try addBottle(volume: 60)
        let first = try bottles.logPour(bottleId: bottle.id)
        XCTAssertEqual(first.volumeMl, PourSize.standard.milliliters, accuracy: 0.001)

        let second = try bottles.logPour(bottleId: bottle.id)
        XCTAssertEqual(second.volumeMl, 60 - PourSize.standard.milliliters, accuracy: 0.001)

        let summary = try XCTUnwrap(bottles.summary(id: bottle.id))
        XCTAssertEqual(summary.status.remainingMilliliters, 0, accuracy: 0.001)
    }

    func testPouringFromAnEmptyBottleThrows() throws {
        let bottle = try addBottle(volume: 40)
        try bottles.logPour(bottleId: bottle.id)
        XCTAssertThrowsError(try bottles.logPour(bottleId: bottle.id)) { error in
            XCTAssertEqual(error as? DataError, .bottleIsEmpty(bottle.id))
        }
    }

    func testPouringFromAMissingBottleThrows() throws {
        XCTAssertThrowsError(try bottles.logPour(bottleId: "nope"))
    }

    // MARK: - Cost

    func testCostPerPourUsesTheDisplayedCount() throws {
        let bottle = try addBottle(price: 7999)
        let summary = try XCTUnwrap(bottles.summary(id: bottle.id))
        XCTAssertEqual(summary.costPerPourCents, 471)
    }

    func testCostPerPourIsNilWithoutAPrice() throws {
        let bottle = try addBottle()
        XCTAssertNil(try bottles.summary(id: bottle.id)?.costPerPourCents)
    }

    // MARK: - Lifecycle

    func testFinishedBottlesLeaveTheShelfButKeepTheirHistory() throws {
        let bottle = try addBottle()
        try bottles.logPour(bottleId: bottle.id)
        try bottles.finish(bottleId: bottle.id)

        XCTAssertTrue(try bottles.summaries().isEmpty)
        XCTAssertEqual(try bottles.summaries(includeFinished: true).count, 1)
    }

    /// A hard delete would break sync and destroy the history the product is
    /// sold on, so removal is a tombstone.
    func testRemovingABottleTombstonesRatherThanDeletes() throws {
        let bottle = try addBottle()
        try bottles.remove(bottleId: bottle.id)

        XCTAssertTrue(try bottles.summaries(includeFinished: true).isEmpty)
        let raw = try db.queue.read { db in try Bottle.filter(key: bottle.id).fetchOne(db) }
        XCTAssertNotNil(raw, "the row must survive so the delete can sync")
        XCTAssertTrue(try XCTUnwrap(raw).isDeleted)
    }

    // MARK: - Sync bookkeeping

    func testWritesAreMarkedForPush() throws {
        let bottle = try addBottle()
        let stored = try db.queue.read { db in try Bottle.filter(key: bottle.id).fetchOne(db) }
        XCTAssertTrue(try XCTUnwrap(stored).dirty)
        XCTAssertGreaterThan(try XCTUnwrap(stored).updatedAt, 0)
    }

    func testRowsFromTheServerAreNotMarkedForPush() throws {
        try db.queue.write { db in
            var incoming = Bottle(catalogProductId: "x", volumeMl: 750, dirty: true)
            try incoming.saveFromServer(db)
            let stored = try XCTUnwrap(Bottle.filter(key: incoming.id).fetchOne(db))
            XCTAssertFalse(stored.dirty, "a pull that marks rows dirty makes two devices ping-pong")
        }
    }

    // MARK: - Fixtures

    /// The preview database and the design canvas must describe one app.
    func testFixturesMatchTheCanvas() throws {
        let seeded = try AppDatabase.populatedForPreviews()
        let repo = BottleRepository(seeded)
        let summaries = try repo.summaries()

        let barrelProof = try XCTUnwrap(summaries.first { $0.id == "fixture-ec-bp" })
        XCTAssertEqual(barrelProof.status.remainingPours, 13)
        XCTAssertEqual(barrelProof.status.totalPours, 17)
        XCTAssertEqual(barrelProof.costPerPourCents, 471)

        let pick = try XCTUnwrap(summaries.first { $0.id == "fixture-fr-pick" })
        XCTAssertEqual(pick.status.remainingPours, 9)

        let weller = try XCTUnwrap(summaries.first { $0.id == "fixture-weller-107" })
        XCTAssertEqual(weller.status.remainingPours, 5)
        XCTAssertEqual(weller.fillLevel.headroom, .high, "the fading bottle")
    }
}
