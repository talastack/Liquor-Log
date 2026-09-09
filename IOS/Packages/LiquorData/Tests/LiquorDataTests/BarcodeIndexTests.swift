import XCTest
import GRDB
import LiquorEngine
@testable import LiquorData

/// Your own barcode lookup, with no UPC database behind it.
///
/// The rule these hold: a barcode resolves to a PRODUCT and never to a barrel.
/// That is the central finding of the research, and the reason every other
/// bourbon app breaks on the bottles enthusiasts care most about.
final class BarcodeIndexTests: XCTestCase {

    private func database() throws -> AppDatabase { try AppDatabase.inMemory() }

    // MARK: - UPC-A and EAN-13 are the same barcode

    /// Scanners return 12 digits from one device and 13 from another for one
    /// physical barcode, and the difference is a leading zero. Without padding,
    /// a bottle scanned on an iPhone and looked up from an iPad would miss.
    func testTwelveAndThirteenDigitFormsAgree() throws {
        let index = BarcodeIndex(try database())
        XCTAssertEqual(index.normalise("088076123456"), "0088076123456")
        XCTAssertEqual(index.normalise("0088076123456"), "0088076123456")
    }

    /// Scanners hand back spaces and hyphens depending on the symbology.
    func testItIgnoresPunctuationAndSpacing() throws {
        let index = BarcodeIndex(try database())
        XCTAssertEqual(index.normalise("0 88076 12345 6"), "0088076123456")
        XCTAssertEqual(index.normalise("088076-123456"), "0088076123456")
    }

    func testAnEightDigitCodeIsLeftAlone() throws {
        // EAN-8 is its own thing, not a truncated EAN-13.
        XCTAssertEqual(BarcodeIndex(try database()).normalise("96385074"), "96385074")
    }

    // MARK: - Lookup

    func testAnUnknownCodeMatchesNothing() throws {
        XCTAssertNil(try BarcodeIndex(try database()).match("0088076123456"))
    }

    func testACodeResolvesToTheBottleItWasRememberedOn() throws {
        let db = try database()
        let bottle = try BottleRepository(db).add(
            Bottle(catalogProductId: "ec-small-batch", customName: "EC", volumeMl: 750))
        let index = BarcodeIndex(db)

        try index.remember("0 88076 12345 6", forBottleId: bottle.id)

        let match = try XCTUnwrap(try index.match("088076123456"))
        XCTAssertEqual(match.catalogProductId, "ec-small-batch")
        XCTAssertFalse(match.isAmbiguous)
    }

    /// THE POINT, not a failure. Three Elijah Craig Barrel Proofs share one UPC
    /// and are three different whiskeys, and the app has to say so rather than
    /// pick one.
    func testOneCodeAcrossSeveralBottlesReportsAsAmbiguous() throws {
        let db = try database()
        let bottles = BottleRepository(db)
        let index = BarcodeIndex(db)

        for batch in ["B523", "C923", "A125"] {
            let bottle = try bottles.add(Bottle(
                catalogProductId: "ec-barrel-proof",
                customName: "ECBP \(batch)",
                batchNumber: batch,
                volumeMl: 750))
            try index.remember("0088076123456", forBottleId: bottle.id)
        }

        let match = try XCTUnwrap(try index.match("0088076123456"))
        XCTAssertEqual(match.bottleCount, 3)
        XCTAssertTrue(
            match.isAmbiguous,
            "a barcode identifies the release, never the barrel")
    }

    /// "Did I have this before?" is a question the shelf check answers, and a
    /// bottle you killed last year is still the answer to it.
    func testAFinishedBottleStillTeachesItsCode() throws {
        let db = try database()
        let bottles = BottleRepository(db)
        let bottle = try bottles.add(
            Bottle(catalogProductId: "buffalo-trace", customName: "BT", volumeMl: 750))
        let index = BarcodeIndex(db)
        try index.remember("0088076123456", forBottleId: bottle.id)
        try bottles.finish(bottleId: bottle.id)

        XCTAssertNotNil(try index.match("0088076123456"))
    }

    /// A tombstoned bottle is gone from the collection and must not answer for
    /// it either.
    func testARemovedBottleStopsAnswering() throws {
        let db = try database()
        let bottles = BottleRepository(db)
        let bottle = try bottles.add(Bottle(customName: "Gone", volumeMl: 750))
        let index = BarcodeIndex(db)
        try index.remember("0088076123456", forBottleId: bottle.id)
        try bottles.remove(bottleId: bottle.id)

        XCTAssertNil(try index.match("0088076123456"))
    }

    func testRememberingIsIdempotent() throws {
        let db = try database()
        let bottle = try BottleRepository(db).add(Bottle(customName: "EC", volumeMl: 750))
        let index = BarcodeIndex(db)

        try index.remember("0088076123456", forBottleId: bottle.id)
        try index.remember("0088076123456", forBottleId: bottle.id)

        XCTAssertEqual(try index.knownCodes(), ["0088076123456"])
    }

    func testAnEmptyCodeIsIgnoredRatherThanStored() throws {
        let db = try database()
        let bottle = try BottleRepository(db).add(Bottle(customName: "EC", volumeMl: 750))
        let index = BarcodeIndex(db)

        try index.remember("   ", forBottleId: bottle.id)

        XCTAssertTrue(try index.knownCodes().isEmpty)
        XCTAssertNil(try index.match(""))
    }

    /// Learning a barcode is an edit like any other and has to reach the server.
    func testRememberingQueuesTheBottleForSync() throws {
        let db = try database()
        let bottle = try BottleRepository(db).add(Bottle(customName: "EC", volumeMl: 750))
        try db.queue.write { db in try db.execute(sql: "update bottles set dirty = 0") }

        try BarcodeIndex(db).remember("0088076123456", forBottleId: bottle.id)

        XCTAssertEqual(try db.queue.read { db in try Bottle.pending().fetchCount(db) }, 1)
    }
}
