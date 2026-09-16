import XCTest
import GRDB
import LiquorEngine
@testable import LiquorData

/// Moving the database into the app group container: once, with its
/// sidecars, and never over a shelf that already has bottles in it.
final class DatabaseMigrationTests: XCTestCase {

    private var folder: URL!

    override func setUpWithError() throws {
        folder = FileManager.default.temporaryDirectory
            .appendingPathComponent("migration-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: folder)
    }

    private func database(named name: String, bottles count: Int) throws -> URL {
        let url = folder.appendingPathComponent(name)
        let db = try AppDatabase.onDisk(at: url)
        for _ in 0..<count {
            try BottleRepository(db).add(Bottle(catalogProductId: "weller-12"))
        }
        return url
    }

    func testTheOldDatabaseMovesAcrossWithItsSidecars() throws {
        let legacy = try database(named: "legacy.sqlite", bottles: 3)
        let shared = folder.appendingPathComponent("group").appendingPathComponent("shared.sqlite")
        try FileManager.default.createDirectory(
            at: shared.deletingLastPathComponent(), withIntermediateDirectories: true)

        try AppDatabase.migrate(from: legacy, to: shared, fileManager: .default)

        XCTAssertFalse(FileManager.default.fileExists(atPath: legacy.path))
        XCTAssertTrue(try AppDatabase.holdsBottles(at: shared))
        XCTAssertEqual(try BottleRepository(try AppDatabase.onDisk(at: shared)).summaries().count, 3)
        // The WAL was checkpointed into the main file before the move, so
        // nothing of the old database is left behind.
        for suffix in AppDatabase.sidecars {
            XCTAssertFalse(FileManager.default.fileExists(atPath: legacy.path + suffix), suffix)
        }
    }

    /// Settling puts rows still in the WAL into the main file, so the main
    /// file alone is the whole database. Checked while a connection is
    /// open, which is when a WAL is real: the main file is copied on its
    /// own and read back.
    func testSettlingPutsTheWALIntoTheMainFile() throws {
        let legacy = folder.appendingPathComponent("legacy.sqlite")
        let db = try AppDatabase.onDisk(at: legacy)
        for _ in 0..<4 { try BottleRepository(db).add(Bottle(catalogProductId: "weller-12")) }
        XCTAssertTrue(FileManager.default.fileExists(atPath: legacy.path + "-wal"))

        try AppDatabase.settle(legacy)

        let copy = folder.appendingPathComponent("copy.sqlite")
        try FileManager.default.copyItem(at: legacy, to: copy)
        XCTAssertEqual(try BottleRepository(try AppDatabase.onDisk(at: copy)).summaries().count, 4)
        _ = db
    }

    /// The widget of an earlier build could have created an empty group
    /// database before the app ran. That is not a shelf; it is replaced.
    func testAnEmptyGroupDatabaseIsReplacedByTheOldOne() throws {
        let legacy = try database(named: "legacy.sqlite", bottles: 2)
        let shared = try database(named: "shared.sqlite", bottles: 0)

        try AppDatabase.migrate(from: legacy, to: shared, fileManager: .default)

        XCTAssertEqual(try BottleRepository(try AppDatabase.onDisk(at: shared)).summaries().count, 2)
        XCTAssertFalse(FileManager.default.fileExists(atPath: legacy.path))
    }

    /// A group database with bottles in it is somebody's shelf. It stays,
    /// and the old file is left where it was rather than lost.
    func testAGroupDatabaseWithBottlesIsKept() throws {
        let legacy = try database(named: "legacy.sqlite", bottles: 2)
        let shared = try database(named: "shared.sqlite", bottles: 5)

        try AppDatabase.migrate(from: legacy, to: shared, fileManager: .default)

        XCTAssertEqual(try BottleRepository(try AppDatabase.onDisk(at: shared)).summaries().count, 5)
        XCTAssertTrue(FileManager.default.fileExists(atPath: legacy.path))
    }

    func testTheSharedDatabaseRunsInWALMode() throws {
        let url = try database(named: "wal.sqlite", bottles: 0)
        let mode = try AppDatabase.onDisk(at: url).queue.read { db in
            try String.fetchOne(db, sql: "PRAGMA journal_mode")
        }
        XCTAssertEqual(mode?.lowercased(), "wal")
    }
}
