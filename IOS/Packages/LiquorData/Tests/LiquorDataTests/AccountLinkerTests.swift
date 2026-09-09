import XCTest
import GRDB
import LiquorEngine
@testable import LiquorData

/// The worst failure in the codebase is a half-stamped collection: rows that
/// look normal locally, can never be pushed, and could never be read back if
/// they were. These pin that it cannot happen.
final class AccountLinkerTests: XCTestCase {

    private func database() throws -> AppDatabase { try AppDatabase.inMemory() }

    private func populate(_ db: AppDatabase) throws -> Bottle {
        let bottles = BottleRepository(db)
        let bottle = try bottles.add(Bottle(customName: "Weller 107", volumeMl: 750))
        try bottles.logPour(bottleId: bottle.id)
        try bottles.setLevel(bottleId: bottle.id, remainingMl: 500)
        try TastingRepository(db).save(Tasting(bottleId: bottle.id, rating: 8), descriptors: [:])
        try WishlistRepository(db).add(customName: "Pappy 15", targetPriceCents: 12_000)
        return bottle
    }

    /// The app is usable with no account, so everything starts unowned.
    func testLocalRowsStartWithNoOwner() throws {
        let db = try database()
        _ = try populate(db)
        XCTAssertGreaterThan(try AccountLinker(db).unownedCount(), 0)
    }

    func testAdoptStampsEveryTable() throws {
        let db = try database()
        _ = try populate(db)
        let linker = AccountLinker(db)

        let stamped = try linker.adopt(userId: "user-1")

        XCTAssertGreaterThan(stamped, 0)
        XCTAssertEqual(
            try linker.unownedCount(), 0,
            "a single unowned row is one that can never be pushed or read back")
        XCTAssertEqual(try linker.rowsOwned(by: "user-1"), stamped)
    }

    /// These rows have never been pushed, so adoption has to queue them.
    func testAdoptedRowsAreQueuedForPush() throws {
        let db = try database()
        let bottle = try populate(db)
        try db.queue.write { db in
            // Pretend an earlier sync had cleared the flag.
            try db.execute(sql: "update bottles set dirty = 0")
        }

        try AccountLinker(db).adopt(userId: "user-1")

        let pending = try db.queue.read { db in try Bottle.pending().fetchCount(db) }
        XCTAssertEqual(pending, 1)
        XCTAssertEqual(
            try db.queue.read { db in try Bottle.filter(key: bottle.id).fetchOne(db) }?.userId,
            "user-1")
    }

    /// `updated_at` is the last-write-wins key and must say when the HUMAN
    /// edited the bottle. Restamping it at sign-up would make a years-old note
    /// beat a genuinely newer edit from another device.
    func testAdoptDoesNotRestampUpdatedAt() throws {
        let db = try database()
        let bottle = try populate(db)
        let before = try XCTUnwrap(
            try db.queue.read { db in try Bottle.filter(key: bottle.id).fetchOne(db) }).updatedAt

        try AccountLinker(db).adopt(userId: "user-1")

        let after = try XCTUnwrap(
            try db.queue.read { db in try Bottle.filter(key: bottle.id).fetchOne(db) }).updatedAt
        XCTAssertEqual(before, after)
    }

    /// Signing in on a device that already synced must not steal another
    /// account's rows.
    func testAdoptOnlyTouchesUnownedRows() throws {
        let db = try database()
        _ = try populate(db)
        try AccountLinker(db).adopt(userId: "user-1")

        _ = try BottleRepository(db).add(Bottle(customName: "Later bottle", volumeMl: 750))
        let stamped = try AccountLinker(db).adopt(userId: "user-2")

        XCTAssertEqual(stamped, 1, "only the new unowned row")
        XCTAssertGreaterThan(try AccountLinker(db).rowsOwned(by: "user-1"), 0)
    }

    func testAdoptingTwiceIsHarmless() throws {
        let db = try database()
        _ = try populate(db)
        let linker = AccountLinker(db)

        let first = try linker.adopt(userId: "user-1")
        let second = try linker.adopt(userId: "user-1")

        XCTAssertGreaterThan(first, 0)
        XCTAssertEqual(second, 0, "nothing left unowned")
    }
}

/// Auth parsing, which has to be right about one thing above all: the user id
/// comes from the server, never from the client.
final class SupabaseAuthParsingTests: XCTestCase {

    private func payload(_ extra: String = "") -> Data {
        Data("""
        {
          "access_token": "access-abc",
          "refresh_token": "refresh-xyz",
          "expires_in": 3600,
          "user": { "id": "11111111-2222-3333-4444-555555555555" }
          \(extra)
        }
        """.utf8)
    }

    func testItReadsTheSession() throws {
        let now = Date(timeIntervalSince1970: 1_000_000)
        let session = try SupabaseAuth.parse(payload(), now: now)

        XCTAssertEqual(session.accessToken, "access-abc")
        XCTAssertEqual(session.refreshToken, "refresh-xyz")
        XCTAssertEqual(session.userId, "11111111-2222-3333-4444-555555555555")
        XCTAssertEqual(session.expiresAt, now.addingTimeInterval(3600))
    }

    /// The id is what RLS compares against. Guessing it wrong writes rows their
    /// owner can never read back, so a response without one is a hard failure.
    func testAResponseWithNoUserIdIsRefused() {
        let data = Data("""
        {"access_token": "a", "refresh_token": "b", "expires_in": 3600}
        """.utf8)
        XCTAssertThrowsError(try SupabaseAuth.parse(data))
    }

    func testAResponseWithNoTokensIsRefused() {
        let data = Data("""
        {"user": {"id": "abc"}}
        """.utf8)
        XCTAssertThrowsError(try SupabaseAuth.parse(data))
    }

    /// Refreshed a minute early: a token expiring between the check and the
    /// request produces a 401 that reads as a sign-in problem.
    func testATokenNearExpiryIsNotConsideredFresh() throws {
        let now = Date(timeIntervalSince1970: 1_000_000)
        let session = try SupabaseAuth.parse(payload(), now: now.addingTimeInterval(-3_570))
        XCTAssertFalse(
            session.isFresh,
            "30 seconds left must not count as usable")
    }
}
