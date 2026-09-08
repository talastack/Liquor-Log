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

    /// The real one.
    public static func onDisk(
        at url: URL? = nil,
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
            let folder = support.appendingPathComponent("LiquorLog", isDirectory: true)
            try fileManager.createDirectory(at: folder, withIntermediateDirectories: true)
            location = folder.appendingPathComponent("liquorlog.sqlite")
        }

        var config = Configuration()
        // Foreign keys are ON by default in GRDB; stated here because the
        // cascade from bottles to pours is load-bearing for the fixtures.
        config.foreignKeysEnabled = true
        return try AppDatabase(try DatabaseQueue(path: location.path, configuration: config))
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
