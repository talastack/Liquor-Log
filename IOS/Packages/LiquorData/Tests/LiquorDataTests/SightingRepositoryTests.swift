import XCTest
import GRDB
import LiquorEngine
@testable import LiquorData

/// The hunt log as rows: a sighting is a synced record, a lottery has an
/// outcome, a bought bottle takes the sighting off the "where to go" list,
/// and the stores come back one spelling each.
final class SightingRepositoryTests: XCTestCase {

    private var db: AppDatabase!
    private var log: SightingRepository!

    override func setUpWithError() throws {
        db = try AppDatabase.inMemory()
        log = SightingRepository(db)
    }

    func testASightingIsARowToPush() throws {
        let row = try log.record(catalogProductId: "blantons", store: " Total Wine ", cents: 7499, count: 3)
        XCTAssertEqual(row.store, "Total Wine", "trimmed")
        XCTAssertEqual(row.kind, .seen)
        XCTAssertTrue(row.dirty)
        XCTAssertNil(row.customName, "a catalogue product needs no typed name")
        XCTAssertEqual(try log.all().map(\.id), [row.id])
        XCTAssertEqual(try log.latest(catalogProductId: "blantons")?.id, row.id)
    }

    func testASightingNeedsAStoreAndAName() {
        XCTAssertThrowsError(try log.record(catalogProductId: "blantons", store: "  ")) { error in
            XCTAssertEqual(error as? DataError, .sightingNeedsAStore)
        }
        XCTAssertThrowsError(try log.record(customName: "", store: "Total Wine")) { error in
            XCTAssertEqual(error as? DataError, .sightingNeedsAName)
        }
    }

    func testALotteryEntryCarriesItsOutcome() throws {
        let entry = try log.record(catalogProductId: "stagg", kind: .entered, store: "Virginia ABC", count: 4)
        XCTAssertNil(entry.outcome, "pending")
        XCTAssertNil(entry.count, "how many on the shelf means nothing for an entry")
        try log.setOutcome(id: entry.id, outcome: .won)
        XCTAssertEqual(try log.all().first?.outcome, .won)
        try log.setOutcome(id: entry.id, outcome: nil)
        XCTAssertNil(try log.all().first?.outcome)
    }

    func testABoughtSightingIsNoLongerSomewhereToGo() throws {
        let row = try log.record(catalogProductId: "blantons", store: "Liquor Barn", cents: 6999)
        try log.markBought(id: row.id, bottleId: "bottle-1")
        XCTAssertNil(try log.latest(catalogProductId: "blantons"))
        XCTAssertEqual(try log.all().first?.bottleId, "bottle-1", "but it stays in the log")
    }

    func testStoresComeBackOneSpellingEachMostRecentFirst() throws {
        try log.record(catalogProductId: "a", store: "Total Wine", seenAt: 1_000)
        try log.record(catalogProductId: "b", store: "Liquor Barn", seenAt: 2_000)
        try log.record(catalogProductId: "c", store: "total wine", seenAt: 3_000)
        XCTAssertEqual(try log.stores(), ["total wine", "Liquor Barn"])
    }

    func testRemovalIsATombstone() throws {
        let row = try log.record(customName: "Something rare", store: "Total Wine")
        try log.remove(id: row.id)
        XCTAssertTrue(try log.all().isEmpty)
        let stored = try db.queue.read { db in try Sighting.filter(key: row.id).fetchOne(db) }
        XCTAssertNotNil(stored?.deletedAt)
    }

    func testFactsCarryTheLogToTheEngine() throws {
        try log.record(catalogProductId: "blantons", store: "Total Wine", cents: 7499, count: 2, seenAt: 86_400_000)
        let facts = try log.facts { $0.catalogProductId ?? $0.customName ?? "?" }
        XCTAssertEqual(facts.count, 1)
        XCTAssertEqual(facts[0].name, "blantons")
        XCTAssertEqual(facts[0].cents, 7499)
        XCTAssertEqual(facts[0].at, Date(timeIntervalSince1970: 86_400))
        XCTAssertEqual(Hunt.summarise(facts).headline, "1 sighting at 1 store")
    }
}
