import XCTest
import GRDB
import LiquorEngine
@testable import LiquorData

/// Everything out, everything back, and nothing twice.
final class CollectionBackupTests: XCTestCase {

    private var url: URL!

    override func setUpWithError() throws {
        url = FileManager.default.temporaryDirectory
            .appendingPathComponent("backup-\(UUID().uuidString).json")
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: url)
    }

    private func populated() throws -> AppDatabase {
        let db = try AppDatabase.inMemory()
        let bottles = BottleRepository(db)
        let tastings = TastingRepository(db)
        let bottle = try bottles.add(Bottle(catalogProductId: "ec-barrel-proof", purchasePriceCents: 6_999))
        _ = try bottles.logPour(bottleId: bottle.id)
        try tastings.save(Tasting(bottleId: bottle.id, catalogProductId: "ec-barrel-proof", rating: 8),
                          descriptors: [.nose: ["caramel"]])
        try WishlistRepository(db).add(catalogProductId: "weller-12", targetPriceCents: 5_000)
        try KnowledgeNoteRepository(db).set(productId: "weller-12", title: "Weller 12", body: "Runs hot.")
        // A removed bottle: tombstones travel too.
        let gone = try bottles.add(Bottle(catalogProductId: "weller-12"))
        try bottles.remove(bottleId: gone.id)
        return db
    }

    func testRoundTripOntoAnEmptyDatabase() throws {
        let source = try populated()
        let counts = try CollectionBackup(source).write(to: url)
        XCTAssertEqual(counts.rows["bottles"], 2)
        XCTAssertEqual(counts.rows["pours"], 1)
        XCTAssertEqual(counts.rows["tastings"], 1)
        XCTAssertEqual(counts.rows["tasting_notes"], 1)
        XCTAssertEqual(counts.rows["wishlist_items"], 1)
        XCTAssertEqual(counts.rows["knowledge_notes"], 1)

        let target = try AppDatabase.inMemory()
        let data = try Data(contentsOf: url)
        let preview = try CollectionBackup(target).preview(data)
        XCTAssertEqual(preview.counts.total, counts.total)

        let outcome = try CollectionBackup(target).restore(data)
        XCTAssertEqual(outcome.inserted, counts.total)
        XCTAssertEqual(outcome.updated, 0)

        let shelf = try BottleRepository(target).summaries()
        XCTAssertEqual(shelf.count, 1, "the tombstoned bottle stays removed")
        XCTAssertEqual(shelf.first?.status.remainingPours, 16, "the pour came back")
        XCTAssertEqual(try TastingRepository(target).history(bottleId: shelf[0].id).first?.descriptorCount, 1)
        XCTAssertEqual(try WishlistRepository(target).items().count, 1)
        XCTAssertEqual(try KnowledgeNoteRepository(target).note(productId: "weller-12")?.body, "Runs hot.")
    }

    func testRestoringTwiceChangesNothingTheSecondTime() throws {
        let source = try populated()
        try CollectionBackup(source).write(to: url)
        let data = try Data(contentsOf: url)
        let target = try AppDatabase.inMemory()
        let first = try CollectionBackup(target).restore(data)
        let second = try CollectionBackup(target).restore(data)
        XCTAssertEqual(second.inserted, 0)
        XCTAssertEqual(second.updated, 0)
        XCTAssertEqual(second.unchanged, first.inserted)
    }

    func testTheNewerRowWins() throws {
        let source = try populated()
        try CollectionBackup(source).write(to: url)
        let data = try Data(contentsOf: url)

        // Edit locally AFTER the backup was taken: the local edit is newer.
        let bottles = BottleRepository(source)
        var bottle = try XCTUnwrap(bottles.summaries().first?.bottle)
        Thread.sleep(forTimeInterval: 0.01)
        bottle.purchaseStore = "Edited later"
        _ = try bottles.update(bottle)

        let outcome = try CollectionBackup(source).restore(data)
        XCTAssertEqual(outcome.updated, 0)
        XCTAssertEqual(try bottles.summaries().first?.bottle.purchaseStore, "Edited later")
    }

    func testRestoredRowsAreMarkedForPush() throws {
        let source = try populated()
        try CollectionBackup(source).write(to: url)
        let target = try AppDatabase.inMemory()
        try CollectionBackup(target).restore(try Data(contentsOf: url))
        let pending = try target.queue.read { db in try Bottle.pending().fetchCount(db) }
        XCTAssertEqual(pending, 2)
    }

    func testANonBackupIsRefused() {
        XCTAssertThrowsError(try CollectionBackup(try AppDatabase.inMemory()).preview(Data("{}".utf8)))
    }
}
