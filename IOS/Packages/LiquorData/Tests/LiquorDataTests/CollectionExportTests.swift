import XCTest
import LiquorEngine
@testable import LiquorData

/// Export is the app's strongest trust signal, so the failure that matters most
/// here is a silent one: a header and a row that drift out of step produce a
/// file that opens misaligned and looks exactly like corrupted data.
final class CollectionExportTests: XCTestCase {

    private func database() throws -> AppDatabase { try AppDatabase.inMemory() }

    private func export(_ db: AppDatabase) -> CollectionExport { CollectionExport(db) }

    private func csv(_ db: AppDatabase) throws -> [[String]] {
        let text = try export(db).csv(
            resolveName: { $0.customName ?? $0.id },
            resolveIdentity: { _ in nil })
        return text
            .components(separatedBy: "\r\n")
            .filter { !$0.isEmpty }
            .map { $0.components(separatedBy: ",") }
    }

    /// The one assertion that catches a column added to the header and not the
    /// row, or the reverse.
    func testEveryRowIsAsWideAsTheHeader() throws {
        let db = try database()
        let bottles = BottleRepository(db)
        try bottles.add(Bottle(customName: "Elijah Craig Barrel Proof", volumeMl: 750))
        try bottles.add(Bottle(customName: "Four Roses OESQ", volumeMl: 750))

        let rows = try csv(db)
        XCTAssertEqual(rows.count, 3, "header plus two bottles")
        for row in rows {
            XCTAssertEqual(
                row.count, CollectionExport.header.count,
                "row width must match the header")
        }
    }

    /// A backup that silently drops your history is not a backup.
    func testKilledBottlesAreExported() throws {
        let db = try database()
        let bottles = BottleRepository(db)
        let bottle = try bottles.add(Bottle(customName: "Gone but logged", volumeMl: 750))
        try bottles.finish(bottleId: bottle.id)

        let text = try export(db).csv(
            resolveName: { $0.customName ?? $0.id },
            resolveIdentity: { _ in nil })
        XCTAssertTrue(text.contains("Gone but logged"))
        XCTAssertTrue(text.contains("killed"))
    }

    /// An export missing the barrel fields would look like a backup and not be
    /// one — those are the fields somebody chose this app for.
    func testTheBarrelFieldsAreAllInTheHeader() {
        for column in [
            "batch", "barrel", "store_pick", "pick_group", "pick_store",
            "warehouse", "rick", "floor", "recipe_code",
            "age_months", "entry_proof", "char_level", "finish",
            "bottle_number", "bottles_in_batch",
            "storage_location", "shelf_number",
        ] {
            XCTAssertTrue(
                CollectionExport.header.contains(column),
                "\(column) missing from the export")
        }
    }

    func testHeaderHasNoDuplicateColumns() {
        XCTAssertEqual(
            Set(CollectionExport.header).count, CollectionExport.header.count)
    }

    // MARK: - Pick my pour

    func testSealedBottlesAreNotOfferedAsCandidates() throws {
        let db = try database()
        let bottles = BottleRepository(db)
        let sealed = try bottles.add(Bottle(customName: "Sealed", volumeMl: 750))
        let opened = try bottles.add(Bottle(customName: "Opened", volumeMl: 750))
        try bottles.logPour(bottleId: opened.id)

        let candidates = try export(db).pourCandidates()
        let eligible = PickMyPour.eligible(from: candidates).map(\.id)
        XCTAssertEqual(eligible, [opened.id])
        XCTAssertFalse(eligible.contains(sealed.id))
    }

    func testACandidateCarriesItsLastPour() throws {
        let db = try database()
        let bottles = BottleRepository(db)
        let bottle = try bottles.add(Bottle(customName: "Weller", volumeMl: 750))
        try bottles.logPour(bottleId: bottle.id)

        let candidate = try XCTUnwrap(
            try export(db).pourCandidates().first { $0.id == bottle.id })
        XCTAssertNotNil(candidate.lastPouredAt)
        XCTAssertEqual(candidate.name, "Weller")
    }

    // MARK: - The rest of the record

    private func rows(_ text: String) -> [[String]] {
        text.components(separatedBy: "\r\n").filter { !$0.isEmpty }.map { $0.components(separatedBy: ",") }
    }

    func testEveryTastingIsARowWithItsWheelPicks() throws {
        let db = try database()
        let bottles = BottleRepository(db)
        let bottle = try bottles.add(Bottle(customName: "Stagg", volumeMl: 750))
        let tastings = TastingRepository(db)
        try tastings.save(Tasting(bottleId: bottle.id, tastedAt: 86_400_000, rating: 8, blind: true, liked: "the heat"),
                          descriptors: [.nose: ["caramel", "oak"], .finish: ["pepper"]])
        try tastings.save(Tasting(bottleId: bottle.id, tastedAt: 2 * 86_400_000, rating: 9))

        let out = rows(try export(db).tastingsCSV(
            resolveName: { $0.customName ?? $0.id }, resolveIdentity: { _ in nil },
            word: { $0.capitalized }))
        XCTAssertEqual(out.count, 3, "header plus two tastings; the bottle export would carry one")
        for row in out { XCTAssertEqual(row.count, CollectionExport.tastingsHeader.count) }
        let older = out[2]
        XCTAssertEqual(older[0], "1970-01-02")
        XCTAssertEqual(older[1], "Stagg")
        XCTAssertEqual(older[4], "8")
        XCTAssertEqual(older[5], "yes", "blind")
        XCTAssertEqual(older[12], "the heat")
        XCTAssertEqual(older[14], "Caramel; Oak", "nose, as words")
        XCTAssertEqual(older[17], "Pepper", "finish")
    }

    func testEveryPourIsARowWithWhoItWentTo() throws {
        let db = try database()
        let bottles = BottleRepository(db)
        let bottle = try bottles.add(Bottle(customName: "Stagg", volumeMl: 750))
        try bottles.open(bottleId: bottle.id)
        _ = try bottles.logPour(bottleId: bottle.id, volumeMl: 30, givenTo: "Mike")
        _ = try bottles.logPour(bottleId: bottle.id, volumeMl: 44.36)

        let out = rows(try export(db).poursCSV(resolveName: { $0.customName ?? $0.id }))
        XCTAssertEqual(out.count, 3)
        for row in out { XCTAssertEqual(row.count, CollectionExport.poursHeader.count) }
        // Two pours in the same millisecond have no order; find them by
        // what they are.
        let given = try XCTUnwrap(out.first { $0[3] == "Mike" })
        XCTAssertEqual(given[1], "Stagg")
        XCTAssertEqual(given[2], "30.0")
        let own = try XCTUnwrap(out.first { $0[2] == "44.4" })
        XCTAssertEqual(own[3], "")
    }

    func testTheHuntLogIsARowPerSighting() throws {
        let db = try database()
        let log = SightingRepository(db)
        let seen = try log.record(customName: "Blanton's Gold", store: "Total Wine", cents: 12_999, count: 2, seenAt: 86_400_000)
        try log.markBought(id: seen.id, bottleId: "b1")
        let entry = try log.record(customName: "Stagg", kind: .entered, store: "Virginia ABC", seenAt: 2 * 86_400_000)
        try log.setOutcome(id: entry.id, outcome: .won)

        let out = rows(try export(db).huntLogCSV(resolveIdentity: { _ in nil }))
        XCTAssertEqual(out.count, 3)
        for row in out { XCTAssertEqual(row.count, CollectionExport.huntLogHeader.count) }
        XCTAssertEqual(out[1], ["1970-01-03", "entered", "Stagg", "Virginia ABC", "", "", "", "won", "", ""])
        XCTAssertEqual(out[2], ["1970-01-02", "seen", "Blanton's Gold", "Total Wine", "", "129.99", "2", "", "yes", ""])
    }

    func testWriteAllSkipsEmptyFilesAndKeepsTheBottles() throws {
        let db = try database()
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let none = try export(db).writeAll(to: directory, resolveName: { $0.customName ?? $0.id }, resolveIdentity: { _ in nil })
        XCTAssertEqual(none.count, 1, "an empty collection still exports its (empty) bottles file")

        try SightingRepository(db).record(customName: "Stagg", store: "Total Wine")
        let some = try export(db).writeAll(to: directory, resolveName: { $0.customName ?? $0.id }, resolveIdentity: { _ in nil })
        XCTAssertEqual(some.count, 2)
        XCTAssertTrue(some[1].lastPathComponent.hasPrefix("liquor-log-hunt-log-"))
    }
}

/// The shelf walk against real rows. The engine pins the ordering; these pin
/// what answering actually does to the database.
final class ReInventoryRepositoryTests: XCTestCase {

    private func database() throws -> AppDatabase { try AppDatabase.inMemory() }

    func testConfirmingABottleStampsWhenItWasSeen() throws {
        let db = try database()
        let bottles = BottleRepository(db)
        let bottle = try bottles.add(
            Bottle(customName: "Blanton's", volumeMl: 750, storageLocation: "hall closet"))
        XCTAssertNil(bottle.lastVerifiedAt)

        try ReInventoryRepository(db).record(.present, for: bottle.id)

        let after = try XCTUnwrap(try bottles.summary(id: bottle.id)).bottle
        XCTAssertNotNil(after.lastVerifiedAt)
        XCTAssertNil(after.finishedAt, "confirming must not finish a bottle")
    }

    /// A bottle you drank and forgot to log is archived, never deleted. It stays
    /// in the collection's history and in the export.
    func testAMissingBottleIsArchivedNotDeleted() throws {
        let db = try database()
        let bottles = BottleRepository(db)
        let bottle = try bottles.add(Bottle(customName: "Long gone", volumeMl: 750))

        try ReInventoryRepository(db).record(.gone, for: bottle.id)

        let after = try XCTUnwrap(try bottles.summary(id: bottle.id)).bottle
        XCTAssertNotNil(after.finishedAt)
        XCTAssertNil(after.deletedAt, "a finished bottle is not a tombstoned one")
        XCTAssertTrue(
            try bottles.summaries(includeFinished: true).contains { $0.id == bottle.id })
    }

    /// Skipping writes nothing, so the bottle leads the next walk.
    func testSkippingLeavesTheRecordUntouched() throws {
        let db = try database()
        let bottles = BottleRepository(db)
        let bottle = try bottles.add(Bottle(customName: "Not sure", volumeMl: 750))

        let outcome = try ReInventoryRepository(db).apply([(bottle.id, .skipped)])

        XCTAssertEqual(outcome.skipped, [bottle.id])
        let after = try XCTUnwrap(try bottles.summary(id: bottle.id)).bottle
        XCTAssertNil(after.lastVerifiedAt)
        XCTAssertNil(after.finishedAt)
    }

    func testFinishedBottlesAreNotPartOfAWalk() throws {
        let db = try database()
        let bottles = BottleRepository(db)
        let live = try bottles.add(Bottle(customName: "On the shelf", volumeMl: 750))
        let dead = try bottles.add(Bottle(customName: "Killed", volumeMl: 750))
        try bottles.finish(bottleId: dead.id)

        let items = try ReInventoryRepository(db).items(resolveName: { $0.customName ?? $0.id })
        XCTAssertEqual(items.map(\.id), [live.id])
    }

    func testAWholeWalkAppliesInOnePass() throws {
        let db = try database()
        let bottles = BottleRepository(db)
        let a = try bottles.add(Bottle(customName: "A", volumeMl: 750))
        let b = try bottles.add(Bottle(customName: "B", volumeMl: 750))
        let c = try bottles.add(Bottle(customName: "C", volumeMl: 750))

        let outcome = try ReInventoryRepository(db)
            .apply([(a.id, .present), (b.id, .gone), (c.id, .skipped)])

        XCTAssertEqual(outcome.confirmed, [a.id])
        XCTAssertEqual(outcome.gone, [b.id])
        XCTAssertEqual(outcome.skipped, [c.id])
        XCTAssertEqual(outcome.checkedCount, 2)
    }
}
