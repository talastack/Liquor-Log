import Foundation
import GRDB
import LiquorEngine

/// The database, and the three ways to get one.
///
/// A `DatabaseQueue` rather than a pool: this is a single-user app with modest
/// data, the writes are small, and a queue is thread-safe with far less to
/// reason about under strict concurrency.
public struct AppDatabase: Sendable {
    public let queue: DatabaseQueue

    public init(_ queue: DatabaseQueue) throws {
        self.queue = queue
        try Migrations.migrator().migrate(queue)
    }

    /// The app group the app and its widgets share. The database lives in
    /// the group container so a widget can read what is open without the
    /// app running; the value is also in both targets' entitlements.
    public static let appGroup = "group.com.talastack.liquorlog"

    public enum OpenError: Error, Sendable, Equatable {
        /// The shared database does not exist yet: the app has not run
        /// since it moved there. A widget shows a line saying so rather
        /// than creating an empty shelf the app would then adopt.
        case notCreatedYet
    }

    /// The on-disk database. In the app group container when the group is
    /// available (a widget can then read it), otherwise in Application
    /// Support as before.
    ///
    /// A database left in Application Support by an earlier build is moved
    /// across once, the first time the app opens with the container
    /// present -- with its journal, WAL and shm files, since a hot journal
    /// is the crash recovery SQLite performs on the next open. The move is
    /// recorded by a marker file, not by the group file's absence: the
    /// widget cannot be the one to create the group database (see
    /// `createIfMissing`), but a failed or partial move must not be
    /// retried forever either. If a group database somehow exists before
    /// the move and holds bottles, it is kept and the old file left where
    /// it is; an empty one is replaced.
    public static func onDisk(
        at url: URL? = nil,
        appGroup: String? = appGroup,
        createIfMissing: Bool = true,
        fileManager: FileManager = .default
    ) throws -> AppDatabase {
        let location: URL
        if let url {
            location = url
        } else {
            let support = try fileManager.url(
                for: .applicationSupportDirectory,
                in: .userDomainMask,
                appropriateFor: nil,
                create: true
            )
            let legacyFolder = support.appendingPathComponent("LiquorLog", isDirectory: true)
            let legacy = legacyFolder.appendingPathComponent("liquorlog.sqlite")

            if let appGroup,
               let container = fileManager.containerURL(forSecurityApplicationGroupIdentifier: appGroup) {
                let folder = container.appendingPathComponent("LiquorLog", isDirectory: true)
                try fileManager.createDirectory(at: folder, withIntermediateDirectories: true)
                let shared = folder.appendingPathComponent("liquorlog.sqlite")
                let marker = folder.appendingPathComponent("moved-from-application-support")

                if createIfMissing {
                    if !fileManager.fileExists(atPath: marker.path),
                       fileManager.fileExists(atPath: legacy.path) {
                        try migrate(from: legacy, to: shared, fileManager: fileManager)
                        fileManager.createFile(atPath: marker.path, contents: Data())
                    }
                    location = shared
                } else {
                    guard fileManager.fileExists(atPath: shared.path) else { throw OpenError.notCreatedYet }
                    location = shared
                }
            } else {
                guard createIfMissing || fileManager.fileExists(atPath: legacy.path) else {
                    throw OpenError.notCreatedYet
                }
                try fileManager.createDirectory(at: legacyFolder, withIntermediateDirectories: true)
                location = legacy
            }
        }

        var config = Configuration()
        // Foreign keys are ON by default in GRDB; stated here because the
        // cascade from bottles to pours is load-bearing for the fixtures.
        config.foreignKeysEnabled = true
        // Two processes open this file -- the app and the widget -- so it
        // runs in WAL mode, waits out the other side's transaction instead
        // of failing on the spot, and takes the write lock up front rather
        // than upgrading a read into one, which is the deadlock case.
        config.busyMode = .timeout(5)
        config.defaultTransactionKind = .immediate
        config.prepareDatabase { db in
            try db.execute(sql: "PRAGMA journal_mode = WAL")
        }
        return try AppDatabase(try DatabaseQueue(path: location.path, configuration: config))
    }

    /// The sidecar files SQLite keeps beside a database, in either journal
    /// mode. A hot "-journal" is the rollback of an interrupted write and
    /// must travel with the file it belongs to.
    static let sidecars = ["", "-journal", "-wal", "-shm"]

    /// Moves a database and its sidecars. A group database that already
    /// holds bottles wins and the move is skipped; an empty one (a build
    /// that created it before this rule) is replaced.
    static func migrate(from legacy: URL, to shared: URL, fileManager: FileManager) throws {
        if fileManager.fileExists(atPath: shared.path) {
            if try holdsBottles(at: shared) { return }
            for suffix in sidecars {
                let stale = URL(fileURLWithPath: shared.path + suffix)
                if fileManager.fileExists(atPath: stale.path) { try fileManager.removeItem(at: stale) }
            }
        }
        for suffix in sidecars {
            let source = URL(fileURLWithPath: legacy.path + suffix)
            let target = URL(fileURLWithPath: shared.path + suffix)
            if fileManager.fileExists(atPath: source.path) {
                try fileManager.moveItem(at: source, to: target)
            }
        }
    }

    static func holdsBottles(at url: URL) throws -> Bool {
        var config = Configuration()
        config.readonly = true
        let queue = try DatabaseQueue(path: url.path, configuration: config)
        return try queue.read { db in
            guard try db.tableExists("bottles") else { return false }
            return try Int.fetchOne(db, sql: "SELECT count(*) FROM bottles") ?? 0 > 0
        }
    }

    /// Tests. Every test gets its own empty database.
    public static func inMemory() throws -> AppDatabase {
        try AppDatabase(try DatabaseQueue())
    }

    /// SwiftUI previews and the simulator, seeded with the same fixtures the
    /// design canvas shows — so a preview and a mockup describe one app.
    public static func populatedForPreviews() throws -> AppDatabase {
        let db = try inMemory()
        try db.seedFixtures()
        return db
    }
}

// MARK: - Fixtures

public extension AppDatabase {

    /// The canvas fixture set. Numbers here are the engine's, not decoration:
    /// four pours from a 750 ml bottle leaves 13 of 17 and 573 ml.
    func seedFixtures() throws {
        try queue.write { db in
            let pour = PourSize.standard.milliliters

            var ecBarrelProof = Bottle(
                id: "fixture-ec-bp",
                catalogProductId: "ec-barrel-proof",
                batchNumber: "B523",
                abv: 62.1,
                distilledYear: 2011,
                bottledYear: 2023,
                volumeMl: 750,
                purchasePriceCents: 7999,
                purchaseStore: "Total Wine & More",
                openedAt: Bottle.nowMilliseconds() - 44 * 86_400_000
            )
            try ecBarrelProof.insert(db)

            for i in 1...4 {
                var p = Pour(
                    bottleId: ecBarrelProof.id,
                    pouredAt: Bottle.nowMilliseconds() - Int64(i) * 7 * 86_400_000,
                    volumeMl: pour
                )
                try p.insert(db)
            }

            var fourRoses = Bottle(
                id: "fixture-fr-pick",
                catalogProductId: "four-roses-single-barrel",
                isStorePick: true,
                pickStore: "Total Wine & More",
                pickName: "OESQ pick",
                barrelNumber: "42-3C",
                abv: 57.7,
                volumeMl: 750,
                purchasePriceCents: 5999,
                openedAt: Bottle.nowMilliseconds() - 96 * 86_400_000
            )
            try fourRoses.insert(db)
            for i in 1...8 {
                var p = Pour(
                    bottleId: fourRoses.id,
                    pouredAt: Bottle.nowMilliseconds() - Int64(i) * 10 * 86_400_000,
                    volumeMl: pour
                )
                try p.insert(db)
            }

            var weller = Bottle(
                id: "fixture-weller-107",
                catalogProductId: "weller-antique-107",
                abv: 53.5,
                volumeMl: 750,
                purchasePriceCents: 4999,
                openedAt: Bottle.nowMilliseconds() - 213 * 86_400_000
            )
            try weller.insert(db)
            for i in 1...12 {
                var p = Pour(
                    bottleId: weller.id,
                    pouredAt: Bottle.nowMilliseconds() - Int64(i) * 15 * 86_400_000,
                    volumeMl: pour
                )
                try p.insert(db)
            }

            // A tasting with no bottle: the bar pour. Without this the shelf
            // check can never report "tasted, never owned".
            var barTasting = Tasting(
                catalogProductId: "ec-small-batch",
                tastedAt: Bottle.nowMilliseconds() - 180 * 86_400_000,
                rating: 7,
                wouldRebuy: .maybe,
                liked: "Easy going, classic profile",
                disliked: "A little thin next to the barrel proof"
            )
            try barTasting.insert(db)

            var owned = Tasting(
                bottleId: ecBarrelProof.id,
                catalogProductId: "ec-barrel-proof",
                tastedAt: Bottle.nowMilliseconds() - 2 * 86_400_000,
                rating: 8,
                wouldRebuy: .yes,
                liked: "Burnt caramel and dried figs, thick on the tongue",
                disliked: "Runs hot on the finish without a few drops of water"
            )
            try owned.insert(db)

            for (stage, keys) in [
                (TastingStage.nose, ["caramel", "dried-fig", "charred-oak"]),
                (.entry, ["brown-sugar", "baking-spice"]),
                (.mid, ["dried-fig"]),
                (.finish, ["rye-spice"])
            ] as [(TastingStage, [String])] {
                for key in keys {
                    var note = TastingNote(
                        tastingId: owned.id, stage: stage, descriptorKey: key)
                    try note.insert(db)
                }
            }

            var wish = WishlistItem(
                catalogProductId: "ec-18-year",
                targetPriceCents: 18000,
                note: "Only at shelf price"
            )
            try wish.insert(db)
        }
    }
}
