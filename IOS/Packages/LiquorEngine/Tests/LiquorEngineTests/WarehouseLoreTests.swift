import XCTest
@testable import LiquorEngine

/// A line from the producer about the building, or nothing.
final class WarehouseLoreTests: XCTestCase {

    func testWarehouseHIsBlantons() throws {
        let note = try XCTUnwrap(WarehouseLore.note(distillery: "Buffalo Trace", warehouse: "H"))
        XCTAssertTrue(note.text.contains("metal-clad"))
        XCTAssertTrue(note.source.contains("buffalotracedistillery.com"))
    }

    func testAnotherBuffaloTraceWarehouseSaysNothing() {
        XCTAssertNil(WarehouseLore.note(distillery: "Buffalo Trace", warehouse: "K"))
        XCTAssertNil(WarehouseLore.note(distillery: "Buffalo Trace", warehouse: nil))
    }

    func testFourRosesIsAboutTheBuildingsInGeneral() throws {
        let note = try XCTUnwrap(WarehouseLore.note(distillery: "Four Roses", warehouse: nil))
        XCTAssertTrue(note.text.contains("single-story"))
    }

    func testWildTurkeyCampNelsonIsSpecific() throws {
        let specific = try XCTUnwrap(WarehouseLore.note(distillery: "Wild Turkey", warehouse: "Camp Nelson B"))
        XCTAssertTrue(specific.text.contains("Camp Nelson B"))
        let general = try XCTUnwrap(WarehouseLore.note(distillery: "Wild Turkey", warehouse: "Tyrone F"))
        XCTAssertFalse(general.text.contains("Camp Nelson B"))
    }

    func testUnknownDistilleryHasNoLore() {
        XCTAssertNil(WarehouseLore.note(distillery: "Heaven Hill", warehouse: "Y"))
    }
}
