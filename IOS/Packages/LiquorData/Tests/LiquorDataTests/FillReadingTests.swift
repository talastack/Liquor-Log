import XCTest
import GRDB
import LiquorEngine
@testable import LiquorData

/// Setting the level is how somebody adds a bottle they opened two years ago,
/// and how they fix one they poured from at a party. The rule it must never
/// break: it corrects the fill without erasing what was logged.
final class FillReadingTests: XCTestCase {

    private func database() throws -> AppDatabase { try AppDatabase.inMemory() }

    private func bottle(_ db: AppDatabase, ml: Double = 750) throws -> Bottle {
        try BottleRepository(db).add(Bottle(customName: "Weller 107", volumeMl: ml))
    }

    // MARK: - The baseline

    func testANewBottleIsAssumedFull() throws {
        let db = try database()
        let made = try bottle(db)
        let summary = try XCTUnwrap(try BottleRepository(db).summary(id: made.id))
        XCTAssertEqual(summary.status.remainingMilliliters, 750, accuracy: 0.001)
        XCTAssertEqual(summary.status.remainingPours, 17)
    }

    func testSettingTheLevelChangesWhatIsLeft() throws {
        let db = try database()
        let bottles = BottleRepository(db)
        let made = try bottle(db)

        try bottles.setLevel(bottleId: made.id, remainingMl: 375)

        let summary = try XCTUnwrap(try bottles.summary(id: made.id))
        XCTAssertEqual(summary.status.remainingMilliliters, 375, accuracy: 0.001)
        XCTAssertEqual(summary.status.remainingPours, 8)
        XCTAssertEqual(summary.status.totalPours, 17, "capacity is unchanged")
    }

    func testTheLevelCanBeSetAsAPercentage() throws {
        let db = try database()
        let bottles = BottleRepository(db)
        let made = try bottle(db)

        try bottles.setLevel(bottleId: made.id, percentFull: 20)

        let summary = try XCTUnwrap(try bottles.summary(id: made.id))
        XCTAssertEqual(summary.status.remainingMilliliters, 150, accuracy: 0.001)
    }

    // MARK: - The rule that matters

    /// The correction must not delete history. Pours logged before the reading
    /// stay in the database; they simply stop counting against the fill.
    func testAReadingDoesNotDeleteThePoursBeforeIt() throws {
        let db = try database()
        let bottles = BottleRepository(db)
        let made = try bottle(db)

        try bottles.logPour(bottleId: made.id)
        try bottles.logPour(bottleId: made.id)

        try bottles.setLevel(bottleId: made.id, remainingMl: 375, at: Bottle.nowMilliseconds() + 1)

        let summary = try XCTUnwrap(try bottles.summary(id: made.id))
        XCTAssertEqual(
            summary.status.remainingMilliliters, 375, accuracy: 0.001,
            "the reading wins over the earlier pours")

        let pours = try db.queue.read { db in
            try Pour.live().filter(Column("bottle_id") == made.id).fetchCount(db)
        }
        XCTAssertEqual(pours, 2, "the pours are still logged")
    }

    func testPoursAfterAReadingCountAgainstIt() throws {
        let db = try database()
        let bottles = BottleRepository(db)
        let made = try bottle(db)

        let readingTime = Bottle.nowMilliseconds()
        try bottles.setLevel(bottleId: made.id, remainingMl: 375, at: readingTime)
        try bottles.logPour(bottleId: made.id)

        let summary = try XCTUnwrap(try bottles.summary(id: made.id))
        XCTAssertEqual(
            summary.status.remainingMilliliters,
            375 - PourSize.standard.milliliters, accuracy: 0.01)
    }

    /// Readings accumulate. Two of them a year apart are a real record of how
    /// fast a bottle went down, so the newest one is the baseline.
    func testTheNewestReadingWins() throws {
        let db = try database()
        let bottles = BottleRepository(db)
        let made = try bottle(db)

        let now = Bottle.nowMilliseconds()
        try bottles.setLevel(bottleId: made.id, remainingMl: 600, at: now - 86_400_000)
        try bottles.setLevel(bottleId: made.id, remainingMl: 300, at: now)

        let summary = try XCTUnwrap(try bottles.summary(id: made.id))
        XCTAssertEqual(summary.status.remainingMilliliters, 300, accuracy: 0.001)
        XCTAssertEqual(try bottles.fillHistory(bottleId: made.id).count, 2)
    }

    func testFillHistoryIsNewestFirst() throws {
        let db = try database()
        let bottles = BottleRepository(db)
        let made = try bottle(db)

        let now = Bottle.nowMilliseconds()
        try bottles.setLevel(bottleId: made.id, remainingMl: 600, at: now - 86_400_000)
        try bottles.setLevel(bottleId: made.id, remainingMl: 300, at: now)

        let history = try bottles.fillHistory(bottleId: made.id)
        XCTAssertEqual(history.map(\.remainingMl), [300, 600])
    }

    // MARK: - Clamping and inference

    func testAReadingOverTheBottleSizeIsClamped() throws {
        let db = try database()
        let bottles = BottleRepository(db)
        let made = try bottle(db)

        try bottles.setLevel(bottleId: made.id, remainingMl: 5000)

        let summary = try XCTUnwrap(try bottles.summary(id: made.id))
        XCTAssertEqual(summary.status.remainingMilliliters, 750, accuracy: 0.001)
    }

    func testANegativeReadingIsClampedToEmpty() throws {
        let db = try database()
        let bottles = BottleRepository(db)
        let made = try bottle(db)

        try bottles.setLevel(bottleId: made.id, remainingMl: -100)

        let summary = try XCTUnwrap(try bottles.summary(id: made.id))
        XCTAssertTrue(summary.status.isEmpty)
    }

    /// Saying there is less than a full bottle left is saying it is open.
    /// Without inferring that, every age and oxidation figure on the screen
    /// would be lying.
    func testAPartialReadingOpensAnUnopenedBottle() throws {
        let db = try database()
        let bottles = BottleRepository(db)
        let made = try bottle(db)
        XCTAssertNil(made.openedAt)

        try bottles.setLevel(bottleId: made.id, remainingMl: 500)

        let after = try XCTUnwrap(try bottles.summary(id: made.id)).bottle
        XCTAssertNotNil(after.openedAt)
    }

    func testAFullReadingDoesNotOpenTheBottle() throws {
        let db = try database()
        let bottles = BottleRepository(db)
        let made = try bottle(db)

        try bottles.setLevel(bottleId: made.id, remainingMl: 750)

        let after = try XCTUnwrap(try bottles.summary(id: made.id)).bottle
        XCTAssertNil(after.openedAt)
    }

    func testSettingTheLevelOfAMissingBottleThrows() throws {
        let db = try database()
        XCTAssertThrowsError(try BottleRepository(db).setLevel(bottleId: "nope", remainingMl: 100))
    }

    /// Pouring cannot take a bottle below empty even when the baseline is a
    /// reading rather than the full bottle.
    func testPouringPastAReadingIsRefusedAtEmpty() throws {
        let db = try database()
        let bottles = BottleRepository(db)
        let made = try bottle(db)

        try bottles.setLevel(bottleId: made.id, remainingMl: 20, at: Bottle.nowMilliseconds() - 1000)
        try bottles.logPour(bottleId: made.id)

        let summary = try XCTUnwrap(try bottles.summary(id: made.id))
        XCTAssertTrue(summary.status.isEmpty)
        XCTAssertThrowsError(try bottles.logPour(bottleId: made.id)) { error in
            XCTAssertEqual(error as? DataError, .bottleIsEmpty(made.id))
        }
    }
}
