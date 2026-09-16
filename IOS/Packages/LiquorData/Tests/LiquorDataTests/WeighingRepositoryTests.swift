import XCTest
import GRDB
import LiquorEngine
@testable import LiquorData

/// A scale as the source of a level: the tare from a known level, then
/// every weighing a reading.
final class WeighingRepositoryTests: XCTestCase {

    private var db: AppDatabase!
    private var bottles: BottleRepository!

    override func setUpWithError() throws {
        db = try AppDatabase.inMemory()
        bottles = BottleRepository(db)
    }

    func testTheTareComesFromAFullBottleAndAWeighingBecomesALevel() throws {
        let bottle = try bottles.add(Bottle(catalogProductId: "ec-barrel-proof", abv: 50, volumeMl: 750))
        let density = try XCTUnwrap(Weighing.density(proof: 100))

        // New and full: 551 g of glass plus the whiskey.
        let tare = try bottles.setTare(bottleId: bottle.id, grossGrams: 551 + 750 * density, proof: 100)
        XCTAssertEqual(tare, 551, accuracy: 0.001)
        XCTAssertEqual(try bottles.summary(id: bottle.id)?.bottle.tareGrams ?? 0, 551, accuracy: 0.001)

        // Later, 375 ml worth on the scale.
        let reading = try bottles.weigh(bottleId: bottle.id, grossGrams: 551 + 375 * density, proof: 100)
        XCTAssertEqual(reading.remainingMl, 375, accuracy: 0.01)
        XCTAssertEqual(reading.note, "By weight: 901 g on the scale")
        XCTAssertEqual(try bottles.summary(id: bottle.id)?.status.remainingMilliliters ?? 0, 375, accuracy: 0.01)
    }

    func testAWeighingNeverExceedsTheBottle() throws {
        let bottle = try bottles.add(Bottle(catalogProductId: "ec-barrel-proof", abv: 50, volumeMl: 750))
        let density = try XCTUnwrap(Weighing.density(proof: 100))
        _ = try bottles.setTare(bottleId: bottle.id, grossGrams: 551 + 750 * density, proof: 100)
        let reading = try bottles.weigh(bottleId: bottle.id, grossGrams: 551 + 900 * density, proof: 100)
        XCTAssertEqual(reading.remainingMl, 750, accuracy: 0.01, "an overfull reading is a full bottle")
    }

    func testNonsenseIsRefusedNotStored() throws {
        let bottle = try bottles.add(Bottle(catalogProductId: "ec-barrel-proof", abv: 50, volumeMl: 750))
        XCTAssertThrowsError(try bottles.setTare(bottleId: bottle.id, grossGrams: 100, proof: 100)) {
            XCTAssertEqual($0 as? DataError, .weightMakesNoSense)
        }
        XCTAssertNil(try bottles.summary(id: bottle.id)?.bottle.tareGrams)
        XCTAssertThrowsError(try bottles.weigh(bottleId: bottle.id, grossGrams: 900, proof: 100), "no tare yet") {
            XCTAssertEqual($0 as? DataError, .weightMakesNoSense)
        }
    }
}
