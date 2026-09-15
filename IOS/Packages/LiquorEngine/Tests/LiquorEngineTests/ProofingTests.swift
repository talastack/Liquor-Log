import XCTest
@testable import LiquorEngine

/// Water to add, by the TTB's Table 6 method. The regulation text carries
/// two worked figures; these pin them and the shape of the table.
final class ProofingTests: XCTestCase {

    /// 27 CFR 30.66: "to reduce 112 proof spirits to 100 proof: 1.12 × 53.73
    /// − 47.75 equals 12.42 gallons of water to be added to each 100 wine
    /// gallons." (12.4276 before the regulation's truncation.)
    func testTheRegulationsOwnExample() {
        let parts = Proofing.waterToAdd(from: 112, to: 100, spiritMilliliters: 100)
        XCTAssertEqual(parts ?? 0, 12.4276, accuracy: 0.001)
    }

    func testAPourIsScaledFromTheHundredPartRule() {
        // A 44 ml pour of 124 proof down to 100: 1.24 × 53.73 − 41.67 = 24.96
        // parts per hundred, so 10.98 ml.
        let ml = Proofing.waterToAdd(from: 124, to: 100, spiritMilliliters: 44)
        XCTAssertEqual(ml ?? 0, 24.9552 * 0.44, accuracy: 0.001)
        XCTAssertEqual(ml ?? 0, 10.98, accuracy: 0.01)
    }

    /// Contraction is the whole point: the straight ratio (24 parts for 124
    /// → 100) is short by nearly a part.
    func testItIsNotTheStraightRatio() {
        let parts = Proofing.waterToAdd(from: 124, to: 100, spiritMilliliters: 100) ?? 0
        XCTAssertGreaterThan(parts, 24.5)
    }

    func testTheTableStepsSmoothly() {
        for proof in 51..<150 {
            let step = Proofing.water[proof]! - Proofing.water[proof + 1]!
            XCTAssertGreaterThanOrEqual(step, 0.44, "step at \(proof)")
            XCTAssertLessThanOrEqual(step, 0.54, "step at \(proof)")
        }
        XCTAssertEqual(Proofing.water[100], 53.73)
        XCTAssertEqual(Proofing.water[112], 47.75)
    }

    func testHalfProofsInterpolate() {
        XCTAssertEqual(Proofing.waterParts(atProof: 100.5) ?? 0, (53.73 + 53.24) / 2, accuracy: 0.0001)
        XCTAssertEqual(Proofing.waterParts(atProof: 150) ?? 0, 28.19, accuracy: 0.0001)
    }

    func testOutsideTheTableOrUpwardsIsNil() {
        XCTAssertNil(Proofing.waterToAdd(from: 160, to: 100, spiritMilliliters: 44))
        XCTAssertNil(Proofing.waterToAdd(from: 100, to: 40, spiritMilliliters: 44))
        XCTAssertNil(Proofing.waterToAdd(from: 90, to: 100, spiritMilliliters: 44))
        XCTAssertNil(Proofing.waterToAdd(from: 100, to: 100, spiritMilliliters: 44))
        XCTAssertNil(Proofing.waterToAdd(from: 100, to: 90, spiritMilliliters: 0))
    }

    /// The other direction is the same arithmetic run backwards, so a
    /// round trip lands where it started.
    func testProofAfterASplashRoundTrips() throws {
        let water = try XCTUnwrap(Proofing.waterToAdd(from: 124.2, to: 100, spiritMilliliters: 44))
        let landed = try XCTUnwrap(Proofing.proofAfterAdding(waterMilliliters: water, to: 124.2, spiritMilliliters: 44))
        XCTAssertEqual(landed, 100, accuracy: 0.01)
        XCTAssertEqual(Proofing.proofAfterAdding(waterMilliliters: 0, to: 124.2, spiritMilliliters: 44), 124.2)
        XCTAssertNil(Proofing.proofAfterAdding(waterMilliliters: 500, to: 124.2, spiritMilliliters: 44), "below the table")
    }

    func testTheKitchenMeasure() {
        XCTAssertEqual(Proofing.describe(waterMilliliters: 6.2), "6.2 ml — about 1¼ teaspoons")
        XCTAssertEqual(Proofing.describe(waterMilliliters: 4.9), "4.9 ml — about 1 teaspoon")
        XCTAssertEqual(Proofing.describe(waterMilliliters: 2.4), "2.4 ml — about ½ teaspoon")
        XCTAssertEqual(Proofing.describe(waterMilliliters: 0.5), "0.5 ml — a few drops")
        XCTAssertEqual(Proofing.describe(waterMilliliters: 11.0), "11.0 ml — about 2¼ teaspoons")
    }
}
