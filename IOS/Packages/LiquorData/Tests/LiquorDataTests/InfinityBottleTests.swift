import XCTest
import GRDB
import LiquorEngine
@testable import LiquorData

/// An infinity bottle is filled from other bottles. Every millilitre that
/// goes in comes off a source, both fills are derived from the same rows,
/// and the blend's strength is what the additions say -- never a guess.
final class InfinityBottleTests: XCTestCase {

    private var db: AppDatabase!
    private var bottles: BottleRepository!

    override func setUpWithError() throws {
        db = try AppDatabase.inMemory()
        bottles = BottleRepository(db)
    }

    private func source(abv: Double? = 50, volume: Double = 750) throws -> Bottle {
        try bottles.add(Bottle(catalogProductId: "ec-barrel-proof", abv: abv, volumeMl: volume))
    }

    private func level(_ id: String) throws -> Double {
        try XCTUnwrap(try bottles.summary(id: id)).status.remainingMilliliters
    }

    // MARK: - Filling

    func testANewInfinityBottleIsEmptyAndOpen() throws {
        let blend = try bottles.startInfinityBottle(name: "  The Ever Bottle ", volumeMl: 700)
        XCTAssertTrue(blend.isInfinity)
        XCTAssertEqual(blend.customName, "The Ever Bottle")
        XCTAssertTrue(blend.isOpen)
        XCTAssertEqual(try level(blend.id), 0)
        XCTAssertEqual(try bottles.infinityBottles().map(\.id), [blend.id])
    }

    func testABlankNameGetsTheObviousOne() throws {
        XCTAssertEqual(try bottles.startInfinityBottle(name: "   ").customName, "Infinity bottle")
    }

    /// The whole point: one act, two fills.
    func testAddingFromAShelfBottleMovesTheWhiskeyAndLinksThePour() throws {
        let blend = try bottles.startInfinityBottle(name: "Infinity")
        let weller = try source(abv: 45)

        let addition = try bottles.addToBlend(blendId: blend.id, fromBottleId: weller.id, volumeMl: 100)

        XCTAssertEqual(try level(weller.id), 650)
        XCTAssertEqual(try level(blend.id), 100)
        XCTAssertEqual(addition.sourceBottleId, weller.id)
        XCTAssertEqual(addition.abv, 45)
        let pour = try XCTUnwrap(try bottles.pours(bottleId: weller.id).first)
        XCTAssertEqual(pour.id, addition.pourId)
        XCTAssertEqual(pour.intoBottleId, blend.id)
    }

    func testTheBlendCarriesItsOwnStrength() throws {
        let blend = try bottles.startInfinityBottle(name: "Infinity")
        let strong = try source(abv: 60)
        let mild = try source(abv: 40)
        try bottles.addToBlend(blendId: blend.id, fromBottleId: strong.id, volumeMl: 100)
        try bottles.addToBlend(blendId: blend.id, fromBottleId: mild.id, volumeMl: 100)

        let stored = try XCTUnwrap(try bottles.summary(id: blend.id)?.bottle)
        XCTAssertEqual(stored.abv ?? 0, 50, accuracy: 0.0001)
    }

    /// A barrel-proof source whose proof was never typed has no strength to
    /// give. The catalogue figure fills in when the caller passes one; with
    /// neither, the blend's strength is honestly unknown.
    func testAnUnknownSourceStrengthMakesTheBlendUnknown() throws {
        let blend = try bottles.startInfinityBottle(name: "Infinity")
        let known = try source(abv: 50)
        let unknown = try source(abv: nil)
        try bottles.addToBlend(blendId: blend.id, fromBottleId: known.id, volumeMl: 100)
        try bottles.addToBlend(blendId: blend.id, fromBottleId: unknown.id, volumeMl: 50)

        XCTAssertNil(try bottles.summary(id: blend.id)?.bottle.abv)
        let parts = try bottles.blendParts(blendId: blend.id) { _ in "Source" }
        let profile = Blend.profile(parts)
        XCTAssertNil(profile.abv)
        XCTAssertEqual(profile.unknownMilliliters, 50)
    }

    func testTheCatalogueStrengthFillsInForASourceWithNoneOfItsOwn() throws {
        let blend = try bottles.startInfinityBottle(name: "Infinity")
        let unknown = try source(abv: nil)
        let addition = try bottles.addToBlend(
            blendId: blend.id, fromBottleId: unknown.id, volumeMl: 50, catalogABV: 47)
        XCTAssertEqual(addition.abv, 47)
    }

    func testSomethingNotOnTheShelfIsAddedByName() throws {
        let blend = try bottles.startInfinityBottle(name: "Infinity")
        let addition = try bottles.addToBlend(
            blendId: blend.id, sourceName: " Mike's Stagg ", abv: 65, volumeMl: 60)
        XCTAssertEqual(addition.sourceName, "Mike's Stagg")
        XCTAssertNil(addition.pourId)
        XCTAssertEqual(try level(blend.id), 60)
        let parts = try bottles.blendParts(blendId: blend.id) { _ in nil }
        XCTAssertEqual(parts.map(\.name), ["Mike's Stagg"])
    }

    // MARK: - Limits

    func testAnAdditionIsClampedToWhatTheSourceHas() throws {
        let blend = try bottles.startInfinityBottle(name: "Infinity")
        let nearlyGone = try source(abv: 50, volume: 750)
        try bottles.setLevel(bottleId: nearlyGone.id, remainingMl: 30)
        let addition = try bottles.addToBlend(blendId: blend.id, fromBottleId: nearlyGone.id, volumeMl: 100)
        XCTAssertEqual(addition.volumeMl, 30)
        XCTAssertEqual(try level(nearlyGone.id), 0)
        XCTAssertEqual(try level(blend.id), 30)
    }

    func testAVesselHoldsWhatItHolds() throws {
        let blend = try bottles.startInfinityBottle(name: "Small", volumeMl: 200)
        let big = try source(abv: 50)
        let first = try bottles.addToBlend(blendId: blend.id, fromBottleId: big.id, volumeMl: 500)
        XCTAssertEqual(first.volumeMl, 200)
        XCTAssertEqual(try level(big.id), 550, "only what fit came off the source")
        XCTAssertThrowsError(try bottles.addToBlend(blendId: blend.id, fromBottleId: big.id, volumeMl: 10)) {
            XCTAssertEqual($0 as? DataError, .bottleIsFull(blend.id))
        }
    }

    func testABottleCannotBePouredIntoItself() throws {
        let blend = try bottles.startInfinityBottle(name: "Infinity")
        XCTAssertThrowsError(try bottles.addToBlend(blendId: blend.id, fromBottleId: blend.id, volumeMl: 10))
    }

    func testOnlyAnInfinityBottleTakesAdditions() throws {
        let plain = try source()
        let other = try source()
        XCTAssertThrowsError(try bottles.addToBlend(blendId: plain.id, fromBottleId: other.id, volumeMl: 10))
    }

    // MARK: - Pouring out and undoing

    func testPouringOutOfTheBlendLeavesTheMakeUpAlone() throws {
        let blend = try bottles.startInfinityBottle(name: "Infinity")
        let a = try source(abv: 60)
        let b = try source(abv: 40)
        try bottles.addToBlend(blendId: blend.id, fromBottleId: a.id, volumeMl: 100)
        try bottles.addToBlend(blendId: blend.id, fromBottleId: b.id, volumeMl: 100)
        try bottles.logPour(bottleId: blend.id, volumeMl: 44)

        XCTAssertEqual(try level(blend.id), 156)
        let profile = Blend.profile(try bottles.blendParts(blendId: blend.id) { $0 })
        XCTAssertEqual(profile.shares.map(\.fraction), [0.5, 0.5])
        XCTAssertEqual(profile.abv ?? 0, 50, accuracy: 0.0001)
    }

    func testAnEmptyBlendCannotBePouredFrom() throws {
        let blend = try bottles.startInfinityBottle(name: "Infinity")
        XCTAssertThrowsError(try bottles.logPour(bottleId: blend.id, volumeMl: 30)) {
            XCTAssertEqual($0 as? DataError, .bottleIsEmpty(blend.id))
        }
    }

    /// Undo from either side undoes both: the whiskey did not go in if it
    /// never left.
    func testUndoingTheSourcePourRemovesTheAddition() throws {
        let blend = try bottles.startInfinityBottle(name: "Infinity")
        let weller = try source(abv: 45)
        let addition = try bottles.addToBlend(blendId: blend.id, fromBottleId: weller.id, volumeMl: 100)

        try bottles.removePour(id: try XCTUnwrap(addition.pourId))

        XCTAssertEqual(try level(weller.id), 750)
        XCTAssertEqual(try level(blend.id), 0)
        XCTAssertTrue(try bottles.additions(blendId: blend.id).isEmpty)
        XCTAssertNil(try bottles.summary(id: blend.id)?.bottle.abv)
    }

    func testRemovingTheAdditionUndoesTheSourcePour() throws {
        let blend = try bottles.startInfinityBottle(name: "Infinity")
        let weller = try source(abv: 45)
        let addition = try bottles.addToBlend(blendId: blend.id, fromBottleId: weller.id, volumeMl: 100)

        try bottles.removeAddition(id: addition.id)

        XCTAssertEqual(try level(weller.id), 750)
        XCTAssertTrue(try bottles.pours(bottleId: weller.id).isEmpty)
        XCTAssertEqual(try level(blend.id), 0)
    }

    /// A level set by eye on the blend overrules the additions before it
    /// and is added to by the ones after, the same rule as pours.
    func testAReadingOnTheBlendIsAStartingPointForLaterAdditions() throws {
        let blend = try bottles.startInfinityBottle(name: "Infinity")
        let a = try source(abv: 50)
        try bottles.addToBlend(blendId: blend.id, fromBottleId: a.id, volumeMl: 200)
        try bottles.setLevel(bottleId: blend.id, remainingMl: 150, at: Bottle.nowMilliseconds() + 1)
        XCTAssertEqual(try level(blend.id), 150)

        // Additions are stamped with the clock; the next one must land
        // after the reading's millisecond.
        Thread.sleep(forTimeInterval: 0.005)
        try bottles.addToBlend(blendId: blend.id, fromBottleId: a.id, volumeMl: 50)
        XCTAssertEqual(try level(blend.id), 200)
    }

    /// The infinity bottle has no product, so the aisle never mistakes it
    /// for a bottle of something.
    func testAnInfinityBottleIsNotAHolding() throws {
        _ = try bottles.startInfinityBottle(name: "Infinity")
        let holdings = try bottles.holdings { _ in nil }
        XCTAssertTrue(holdings.isEmpty)
    }

    func testTheBackupCarriesAdditions() throws {
        let blend = try bottles.startInfinityBottle(name: "Infinity")
        try bottles.addToBlend(blendId: blend.id, sourceName: "Mike's Stagg", abv: 65, volumeMl: 60)
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("infinity-\(UUID().uuidString).json")
        _ = try CollectionBackup(db).write(to: url)
        let text = try String(contentsOf: url, encoding: .utf8)
        XCTAssertTrue(text.contains("blend_additions"))
        XCTAssertTrue(text.contains("Mike's Stagg"))
    }
}
