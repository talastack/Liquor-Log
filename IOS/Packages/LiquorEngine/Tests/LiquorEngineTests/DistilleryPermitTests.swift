import XCTest
@testable import LiquorEngine

/// The permit number is how sourced whiskey is unmasked, so the table must
/// be right and the app must say nothing when it does not know.
final class DistilleryPermitTests: XCTestCase {

    func testSpellingsNormalise() {
        XCTAssertEqual(DistilleryPermit.normalise("dsp ky 113"), "DSP-KY-113")
        XCTAssertEqual(DistilleryPermit.normalise("DSP-KY-00113"), "DSP-KY-113")
        XCTAssertEqual(DistilleryPermit.normalise("DSP IN-15016"), "DSP-IN-15016")
        XCTAssertNil(DistilleryPermit.normalise("KY-113"))
        XCTAssertNil(DistilleryPermit.normalise("OESQ"))
    }

    func testTheMajorsResolve() {
        XCTAssertEqual(DistilleryPermit.lookup("DSP-KY-113")?.distillery, "Buffalo Trace")
        XCTAssertEqual(DistilleryPermit.lookup("DSP-KY-44")?.distillery, "Maker's Mark")
        XCTAssertEqual(DistilleryPermit.lookup("dsp-in-15016")?.distillery, "MGP Ingredients (Ross & Squibb)")
        XCTAssertEqual(DistilleryPermit.lookup("DSP-TN-4")?.distillery, "Jack Daniel's")
    }

    func testUnknownIsUnknownNotAGuess() {
        XCTAssertNil(DistilleryPermit.lookup("DSP-KY-99999"))
    }

    func testFoundInsideLabelText() {
        XCTAssertEqual(
            DistilleryPermit.find(in: "DISTILLED AND BOTTLED BY BUFFALO TRACE DISTILLERY DSP-KY-113 FRANKFORT KY"),
            "DSP-KY-113")
    }

    /// The list must not carry the same number twice with different names.
    func testNoDuplicateNumbers() {
        let numbers = DistilleryPermit.plants.map(\.number)
        XCTAssertEqual(numbers.count, Set(numbers).count)
    }

    func testEveryNumberIsInNormalForm() {
        for plant in DistilleryPermit.plants {
            XCTAssertEqual(DistilleryPermit.normalise(plant.number), plant.number, plant.number)
        }
    }
}
