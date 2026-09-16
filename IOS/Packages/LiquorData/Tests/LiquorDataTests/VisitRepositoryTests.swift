import XCTest
import GRDB
import LiquorEngine
@testable import LiquorData

/// The passport as rows: a visit is a synced record with a place and a
/// date, removed by tombstone, read to the engine as facts.
final class VisitRepositoryTests: XCTestCase {

    private var db: AppDatabase!
    private var visits: VisitRepository!

    override func setUpWithError() throws {
        db = try AppDatabase.inMemory()
        visits = VisitRepository(db)
    }

    func testAVisitIsARowToPush() throws {
        let row = try visits.record(distillery: " Buffalo Trace ", visitedAt: 86_400_000, note: "")
        XCTAssertEqual(row.distillery, "Buffalo Trace", "trimmed")
        XCTAssertNil(row.note, "an empty note is no note")
        XCTAssertTrue(row.dirty)
        XCTAssertEqual(try visits.all().map(\.id), [row.id])
    }

    func testAVisitNeedsAPlace() {
        XCTAssertThrowsError(try visits.record(distillery: "   ")) { error in
            XCTAssertEqual(error as? DataError, .visitNeedsAPlace)
        }
    }

    func testRemovalIsATombstone() throws {
        let row = try visits.record(distillery: "Four Roses")
        try visits.remove(id: row.id)
        XCTAssertTrue(try visits.all().isEmpty)
        let stored = try db.queue.read { db in try Visit.filter(key: row.id).fetchOne(db) }
        XCTAssertNotNil(stored?.deletedAt)
    }

    func testFactsReachTheEngine() throws {
        try visits.record(distillery: "Buffalo Trace", visitedAt: 86_400_000)
        try visits.record(distillery: "buffalo trace distillery", visitedAt: 2 * 86_400_000)
        let summary = Passport.summarise(visits: try visits.facts(), shelf: [])
        XCTAssertEqual(summary.headline, "1 distillery, 2 visits.")
        XCTAssertEqual(summary.stamps.first?.firstAt, Date(timeIntervalSince1970: 86_400))
    }
}
