import XCTest
@testable import LiquorEngine

/// Grams to millilitres by proof, pinned to the Gauging Manual's own
/// specific-gravity column.
final class WeighingTests: XCTestCase {

    /// Table 6's specific gravity in air, 101 proof: 0.93320; 130 proof:
    /// 0.90190; 150 proof: 0.87714. Times water's 0.99794 g/ml in air.
    func testDensityReproducesTheTablesSpecificGravityColumn() {
        XCTAssertEqual(Weighing.density(proof: 101) ?? 0, 0.93320 * 0.99794, accuracy: 0.0001)
        XCTAssertEqual(Weighing.density(proof: 130) ?? 0, 0.90190 * 0.99794, accuracy: 0.0001)
        XCTAssertEqual(Weighing.density(proof: 150) ?? 0, 0.87714 * 0.99794, accuracy: 0.0001)
    }

    func testTheConstantsAreTheRegulations() {
        XCTAssertEqual(Weighing.waterGramsPerMilliliter, 0.99794, accuracy: 0.00001)
        XCTAssertEqual(Weighing.absoluteAlcoholRelativeDensity, 0.79364, accuracy: 0.00001)
    }

    /// A new 750 of 100 proof on the scale reads 1,251 g; the glass is
    /// therefore 551 g. Half gone, it reads 901 g: 375 ml left.
    func testATareFromAFullBottleThenALevelFromALaterWeighing() throws {
        let density = try XCTUnwrap(Weighing.density(proof: 100))
        let full = 551 + 750 * density
        let tare = try XCTUnwrap(Weighing.tare(grossGrams: full, knownMilliliters: 750, proof: 100))
        XCTAssertEqual(tare, 551, accuracy: 0.0001)

        let later = 551 + 375 * density
        let left = try XCTUnwrap(Weighing.remainingMilliliters(grossGrams: later, tareGrams: tare, proof: 100))
        XCTAssertEqual(left, 375, accuracy: 0.001)
    }

    func testNonsenseIsRefused() {
        XCTAssertNil(Weighing.density(proof: 40), "below the table")
        XCTAssertNil(Weighing.tare(grossGrams: 100, knownMilliliters: 750, proof: 100), "lighter than its contents")
        XCTAssertEqual(Weighing.remainingMilliliters(grossGrams: 500, tareGrams: 551, proof: 100), 0, "below the tare is empty, not negative")
        XCTAssertNil(Weighing.remainingMilliliters(grossGrams: 900, tareGrams: 0, proof: 100))
    }
}
