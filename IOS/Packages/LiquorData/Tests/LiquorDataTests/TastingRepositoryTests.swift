import XCTest
import GRDB
import LiquorEngine
@testable import LiquorData

/// The flavour wheel writes through this repository, so these tests are what
/// make "select from a bourbon wheel with your tasting" a real feature rather
/// than a picture of one.
final class TastingRepositoryTests: XCTestCase {

    private var db: AppDatabase!
    private var tastings: TastingRepository!
    private var bottles: BottleRepository!

    override func setUpWithError() throws {
        db = try AppDatabase.inMemory()
        tastings = TastingRepository(db)
        bottles = BottleRepository(db)
    }

    // MARK: - Wheel picks

    func testATastingKeepsItsDescriptorsPerStage() throws {
        let detail = try tastings.save(
            Tasting(catalogProductId: "ec-barrel-proof", rating: 8),
            descriptors: [
                .nose: ["caramel", "dried-fig", "charred-oak"],
                .entry: ["brown-sugar", "baking-spice"],
                .mid: ["dried-fig"],
                .finish: ["rye-spice"]
            ]
        )

        XCTAssertEqual(detail.descriptors(on: .nose), ["caramel", "dried-fig", "charred-oak"])
        XCTAssertEqual(detail.descriptors(on: .entry), ["brown-sugar", "baking-spice"])
        XCTAssertEqual(detail.descriptorCount, 7)
    }

    /// The same descriptor can appear on more than one stage. Dried fig on the
    /// nose and again on the mid is a real tasting note, not a duplicate.
    func testTheSameDescriptorCanSitOnTwoStages() throws {
        let detail = try tastings.save(
            Tasting(catalogProductId: "x"),
            descriptors: [.nose: ["dried-fig"], .mid: ["dried-fig"]]
        )
        XCTAssertEqual(detail.descriptors(on: .nose), ["dried-fig"])
        XCTAssertEqual(detail.descriptors(on: .mid), ["dried-fig"])
    }

    /// What the wheel calls when you leave a stage: whatever is lit is what the
    /// stage holds. It must not touch the other three.
    func testSettingOneStageLeavesTheOthersAlone() throws {
        let detail = try tastings.save(
            Tasting(catalogProductId: "x"),
            descriptors: [.nose: ["caramel"], .finish: ["rye-spice"]]
        )

        try tastings.setDescriptors(
            tastingId: detail.id, stage: .nose, keys: ["caramel", "toffee", "honey"])

        let reloaded = try XCTUnwrap(tastings.history(productId: "x").first)
        XCTAssertEqual(reloaded.descriptors(on: .nose), ["caramel", "toffee", "honey"])
        XCTAssertEqual(reloaded.descriptors(on: .finish), ["rye-spice"])
    }

    func testDeselectingRemovesTheDescriptor() throws {
        let detail = try tastings.save(
            Tasting(catalogProductId: "x"),
            descriptors: [.nose: ["caramel", "toffee"]]
        )
        try tastings.setDescriptors(tastingId: detail.id, stage: .nose, keys: ["caramel"])

        let reloaded = try XCTUnwrap(tastings.history(productId: "x").first)
        XCTAssertEqual(reloaded.descriptors(on: .nose), ["caramel"])
    }

    /// Removal is a tombstone so it syncs, and re-selecting revives that row
    /// rather than inserting a second one for the same descriptor.
    func testReselectingRevivesRatherThanDuplicating() throws {
        let detail = try tastings.save(
            Tasting(catalogProductId: "x"), descriptors: [.nose: ["caramel"]])

        try tastings.setDescriptors(tastingId: detail.id, stage: .nose, keys: [])
        try tastings.setDescriptors(tastingId: detail.id, stage: .nose, keys: ["caramel"])

        let reloaded = try XCTUnwrap(tastings.history(productId: "x").first)
        XCTAssertEqual(reloaded.descriptors(on: .nose), ["caramel"])

        let rows = try db.queue.read { db in
            try TastingNote
                .filter(Column("tasting_id") == detail.id)
                .filter(Column("descriptor_key") == "caramel")
                .fetchCount(db)
        }
        XCTAssertEqual(rows, 1, "the tombstone should be revived, not duplicated")
    }

    func testClearingAStageEmptiesIt() throws {
        let detail = try tastings.save(
            Tasting(catalogProductId: "x"), descriptors: [.nose: ["caramel", "toffee"]])
        try tastings.setDescriptors(tastingId: detail.id, stage: .nose, keys: [])

        let reloaded = try XCTUnwrap(tastings.history(productId: "x").first)
        XCTAssertTrue(reloaded.descriptors(on: .nose).isEmpty)
        XCTAssertEqual(reloaded.descriptorCount, 0)
    }

    // MARK: - Bottle vs product

    /// The bar pour: tasted, never owned. Without this the shelf check has a
    /// verdict it can never actually reach.
    func testATastingNeedsNoBottle() throws {
        let detail = try tastings.save(
            Tasting(catalogProductId: "ec-small-batch", rating: 7, wouldRebuy: .maybe))

        XCTAssertNil(detail.tasting.bottleId)
        XCTAssertEqual(try tastings.history(productId: "ec-small-batch").count, 1)
    }

    func testHistoryIsNewestFirst() throws {
        let old = Tasting(catalogProductId: "x", tastedAt: 1_000, rating: 6)
        let new = Tasting(catalogProductId: "x", tastedAt: 9_000, rating: 8)
        try tastings.save(old)
        try tastings.save(new)

        let history = try tastings.history(productId: "x")
        XCTAssertEqual(history.map(\.tasting.rating), [8, 6])
    }

    func testABottleTastingIsFoundBothWays() throws {
        let bottle = try bottles.add(Bottle(catalogProductId: "ec-barrel-proof", volumeMl: 750))
        try tastings.save(Tasting(
            bottleId: bottle.id, catalogProductId: "ec-barrel-proof", rating: 8))

        XCTAssertEqual(try tastings.history(bottleId: bottle.id).count, 1)
        XCTAssertEqual(try tastings.history(productId: "ec-barrel-proof").count, 1)
    }

    /// A tasting rolls up onto the bottle summary, which is what the list row
    /// and the shelf check both read.
    func testTheLatestRatingReachesTheBottleSummary() throws {
        let bottle = try bottles.add(Bottle(catalogProductId: "x", volumeMl: 750))
        try tastings.save(Tasting(bottleId: bottle.id, tastedAt: 1_000, rating: 6))
        try tastings.save(Tasting(bottleId: bottle.id, tastedAt: 9_000, rating: 8))

        let summary = try XCTUnwrap(bottles.summary(id: bottle.id))
        XCTAssertEqual(summary.latestRating, 8, "your current opinion, not your first")
        XCTAssertEqual(summary.tastingCount, 2)
    }

    func testRemovingATastingTombstonesIt() throws {
        let detail = try tastings.save(Tasting(catalogProductId: "x", rating: 8))
        try tastings.remove(tastingId: detail.id)

        XCTAssertTrue(try tastings.history(productId: "x").isEmpty)
        let raw = try db.queue.read { db in try Tasting.filter(key: detail.id).fetchOne(db) }
        XCTAssertTrue(try XCTUnwrap(raw).isDeleted)
    }
}
