import XCTest
import GRDB
import LiquorEngine
@testable import LiquorData

/// A transport that never touches a network, so the rules that can lose
/// somebody's data are testable on any machine.
private actor FakeTransport: SyncTransport {
    var uploaded: [String: [[String: Any]]] = [:]
    var toReturn: [String: [[String: Any]]] = [:]
    var failNextUpsert: Bool = false
    var upsertCalls = 0

    func setFailNextUpsert(_ value: Bool) { failNextUpsert = value }
    func stage(_ table: String, _ rows: [[String: Any]]) { toReturn[table] = rows }
    func uploads(_ table: String) -> [[String: Any]] { uploaded[table] ?? [] }

    func upsert(table: String, rows: [Data]) async throws {
        upsertCalls += 1
        if failNextUpsert {
            failNextUpsert = false
            throw SyncError.http(status: 500, body: "nope")
        }
        let decoded = rows.compactMap {
            (try? JSONSerialization.jsonObject(with: $0)) as? [String: Any]
        }
        uploaded[table, default: []].append(contentsOf: decoded)
    }

    func fetch(table: String, since: Int64, limit: Int) async throws -> Data {
        // NSNumber, not Int64: a literal in a [String: Any] is a Swift Int,
        // and `as? Int64` on it is nil, which filtered every staged row out
        // and made the pull tests fail on their first real run.
        let rows = (toReturn[table] ?? []).filter {
            (($0["server_updated_at"] as? NSNumber)?.int64Value ?? 0) > since
        }
        toReturn[table] = []          // one page, then done
        return try JSONSerialization.data(withJSONObject: rows)
    }
}

private final class MemoryCursors: SyncCursorStore, @unchecked Sendable {
    private var values: [String: Int64] = [:]
    func cursor(for table: String) -> Int64 { values[table] ?? 0 }
    func setCursor(_ value: Int64, for table: String) { values[table] = value }
}

final class SyncEngineTests: XCTestCase {

    private func database() throws -> AppDatabase { try AppDatabase.inMemory() }

    // MARK: - What crosses the wire

    /// `dirty` is a local push queue. It does not exist in Postgres, and
    /// sending it would be rejected.
    func testDirtyIsStrippedBeforeSending() throws {
        let body = try SyncEngine.encodeForServer(
            ["id": "a", "dirty": true, "updated_at": 5])
        let json = try XCTUnwrap(
            JSONSerialization.jsonObject(with: body) as? [String: Any])
        XCTAssertNil(json["dirty"])
        XCTAssertEqual(json["id"] as? String, "a")
    }

    /// Harmless — the trigger overwrites it — but a client that believes it can
    /// set the server's clock is one somebody will make depend on it.
    func testTheServerClockIsNeverSent() throws {
        let body = try SyncEngine.encodeForServer(
            ["id": "a", "server_updated_at": 99, "updated_at": 5])
        let json = try XCTUnwrap(
            JSONSerialization.jsonObject(with: body) as? [String: Any])
        XCTAssertNil(json["server_updated_at"])
    }

    /// `dirty` is not optional on the record and never appears on a server row,
    /// so decoding without injecting it fails outright.
    func testIncomingRowsAreNotDirty() {
        let prepared = SyncEngine.decodeFromServer(
            ["id": "a", "server_updated_at": 99])
        XCTAssertEqual(prepared["dirty"] as? Bool, false)
        XCTAssertNil(prepared["server_updated_at"])
    }

    // MARK: - Push

    func testPushSendsDirtyRowsAndClearsTheFlag() async throws {
        let db = try database()
        let bottles = BottleRepository(db)
        let bottle = try bottles.add(Bottle(customName: "Weller", volumeMl: 750))

        let transport = FakeTransport()
        let engine = SyncEngine(
            db: db, transport: transport, cursors: MemoryCursors())
        let outcome = await engine.sync()

        XCTAssertEqual(outcome.pushed, 1)
        let sent = await transport.uploads("bottles")
        XCTAssertEqual(sent.first?["id"] as? String, bottle.id)

        let stillDirty = try await db.queue.read { db in
            try Bottle.pending().fetchCount(db)
        }
        XCTAssertEqual(stillDirty, 0, "a pushed row is no longer pending")
    }

    /// The rule that protects somebody's tasting note: clearing `dirty`
    /// optimistically discards the edit the request failed to deliver.
    func testAFailedPushLeavesTheRowDirty() async throws {
        let db = try database()
        try BottleRepository(db).add(Bottle(customName: "Weller", volumeMl: 750))

        let transport = FakeTransport()
        await transport.setFailNextUpsert(true)
        let engine = SyncEngine(db: db, transport: transport, cursors: MemoryCursors())
        let outcome = await engine.sync()

        XCTAssertEqual(outcome.pushed, 0)
        XCTAssertNotNil(outcome.failures["bottles"])
        XCTAssertFalse(outcome.isCompletelyClean)

        let stillDirty = try await db.queue.read { db in try Bottle.pending().fetchCount(db) }
        XCTAssertEqual(stillDirty, 1, "the edit must survive to go again")
    }

    /// One table failing must not stop the rest. A partial sync is normal and
    /// safe: what did not go stays dirty.
    func testOneTableFailingDoesNotAbortTheRest() async throws {
        let db = try database()
        try BottleRepository(db).add(Bottle(customName: "Weller", volumeMl: 750))
        try WishlistRepository(db).add(customName: "Pappy 15", targetPriceCents: 12_000)

        let transport = FakeTransport()
        await transport.setFailNextUpsert(true)   // fails on the first table
        let engine = SyncEngine(db: db, transport: transport, cursors: MemoryCursors())
        let outcome = await engine.sync()

        XCTAssertGreaterThan(outcome.pushed, 0, "later tables still went")
        XCTAssertFalse(outcome.failures.isEmpty)
    }

    /// Soft deletes travel as ordinary rows. There is no delete endpoint.
    func testATombstoneIsPushedLikeAnyOtherRow() async throws {
        let db = try database()
        let bottles = BottleRepository(db)
        let bottle = try bottles.add(Bottle(customName: "Gone", volumeMl: 750))
        try bottles.remove(bottleId: bottle.id)

        let transport = FakeTransport()
        let engine = SyncEngine(db: db, transport: transport, cursors: MemoryCursors())
        await engine.sync()

        let sent = await transport.uploads("bottles")
        let row = try XCTUnwrap(sent.first { $0["id"] as? String == bottle.id })
        XCTAssertFalse(row["deleted_at"] is NSNull, "the tombstone carries a date")
        XCTAssertNotNil(row["deleted_at"])
    }

    // MARK: - Pull

    func testPullWritesRowsAndAdvancesTheCursor() async throws {
        let db = try database()
        let transport = FakeTransport()
        let cursors = MemoryCursors()

        await transport.stage("bottles", [[
            "id": "remote-1",
            "custom_name": "Elijah Craig",
            "category": "spirit",
            "is_store_pick": false,
            "volume_ml": 750.0,
            "pour_size_ml": 44.36029434375,
            "created_at": 1000,
            "updated_at": 1000,
            "server_updated_at": 4242,
        ]])

        let engine = SyncEngine(db: db, transport: transport, cursors: cursors)
        let outcome = await engine.sync()

        XCTAssertEqual(outcome.pulled, 1)
        XCTAssertEqual(cursors.cursor(for: "bottles"), 4242)

        let stored = try await db.queue.read { db in
            try Bottle.filter(key: "remote-1").fetchOne(db)
        }
        XCTAssertEqual(stored?.customName, "Elijah Craig")
        XCTAssertEqual(stored?.dirty, false, "a pulled row must not schedule a push")
    }

    /// Every write is an upsert on a device-generated uuid, so losing the
    /// cursor costs time and nothing else.
    func testReapplyingTheSameRowIsIdempotent() async throws {
        let db = try database()
        let transport = FakeTransport()
        let row: [String: Any] = [
            "id": "remote-1",
            "custom_name": "Elijah Craig",
            "category": "spirit",
            "is_store_pick": false,
            "volume_ml": 750.0,
            "pour_size_ml": 44.36029434375,
            "created_at": 1000,
            "updated_at": 1000,
            "server_updated_at": 4242,
        ]

        await transport.stage("bottles", [row])
        _ = await SyncEngine(db: db, transport: transport, cursors: MemoryCursors()).sync()
        await transport.stage("bottles", [row])
        _ = await SyncEngine(db: db, transport: transport, cursors: MemoryCursors()).sync()

        let count = try await db.queue.read { db in try Bottle.fetchCount(db) }
        XCTAssertEqual(count, 1, "same id, one row")
    }
}
