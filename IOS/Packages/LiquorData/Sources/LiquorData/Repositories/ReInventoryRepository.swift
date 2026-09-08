import Foundation
import GRDB
import LiquorEngine

/// The shelf walk, against the database.
///
/// `ReInventory` in the engine decides the ORDER — group by where a bottle is,
/// stalest shelf first. This decides what happens when somebody answers.
public struct ReInventoryRepository: Sendable {
    private let db: AppDatabase

    public init(_ db: AppDatabase) { self.db = db }

    // MARK: - Reading

    /// Everything on the shelf, in the shape the engine wants.
    ///
    /// Finished bottles are excluded: they are archived history, and walking
    /// past a shelf asking "is this bottle still here?" about something you
    /// killed last year is how a walk loses people.
    public func items(resolveName: (Bottle) -> String) throws -> [ReInventory.Item] {
        try db.queue.read { db in
            try Bottle
                .live()
                .filter(Column("finished_at") == nil)
                .fetchAll(db)
                .map { bottle in
                    ReInventory.Item(
                        id: bottle.id,
                        name: resolveName(bottle),
                        storageLocation: bottle.storageLocation,
                        lastVerifiedAt: bottle.lastVerifiedAt.map {
                            Date(timeIntervalSince1970: Double($0) / 1000)
                        },
                        isOpen: bottle.isOpen)
                }
        }
    }

    public func plan(
        now: Date = Date(),
        resolveName: (Bottle) -> String
    ) throws -> [ReInventory.Leg] {
        ReInventory.plan(try items(resolveName: resolveName), now: now)
    }

    /// Whether to offer a walk at all. Nagging sooner than people actually do
    /// this trains them to dismiss it.
    public func isDue(now: Date = Date()) throws -> Bool {
        // Names are irrelevant to the decision, so this skips resolving them.
        ReInventory.isDue(try items(resolveName: { $0.id }), now: now)
    }

    // MARK: - Writing

    /// Applies a batch of decisions in ONE transaction, so a batch either lands
    /// or does not.
    ///
    /// This is not the same as requiring a whole walk to be answered at once.
    /// A walk of two hundred bottles takes an evening and people stop partway;
    /// the screen commits each answer as it is given (`record`) precisely so
    /// that stopping is progress. `last_verified_at` is what makes resuming
    /// work — an unanswered bottle is still stale, so it leads the next walk.
    ///
    /// - `present` stamps `last_verified_at`, which is what orders the next walk.
    /// - `gone` marks the bottle finished. **Archived, never deleted** — a
    ///   bottle you drank is history you keep, and it stays in the export.
    /// - `skipped` writes nothing at all, so a skipped bottle leads the next walk.
    @discardableResult
    public func apply(
        _ decisions: [(id: String, verdict: ReInventory.Verdict)],
        at when: Int64 = Bottle.nowMilliseconds()
    ) throws -> ReInventory.Outcome {
        let outcome = ReInventory.outcome(from: decisions)

        try db.queue.write { db in
            for id in outcome.confirmed {
                guard var bottle = try Bottle.filter(key: id).fetchOne(db) else { continue }
                bottle.lastVerifiedAt = when
                try bottle.saveLocal(db)
            }
            for id in outcome.gone {
                guard var bottle = try Bottle.filter(key: id).fetchOne(db) else { continue }
                bottle.finishedAt = when
                // Confirmed by eye, even though the answer was "it is gone".
                // The walk did look at it.
                bottle.lastVerifiedAt = when
                try bottle.saveLocal(db)
            }
        }

        return outcome
    }

    /// One bottle, mid-walk. The whole walk is applied at once by `apply`; this
    /// is for a screen that wants to commit as it goes.
    public func record(
        _ verdict: ReInventory.Verdict,
        for bottleId: String,
        at when: Int64 = Bottle.nowMilliseconds()
    ) throws {
        try apply([(id: bottleId, verdict: verdict)], at: when)
    }
}
