import XCTest
@testable import LiquorEngine

/// An infinity bottle's two numbers: what it is made of, and how strong it
/// is. Both come from what went in, never from what came out.
final class BlendTests: XCTestCase {

    private func part(_ key: String, _ ml: Double, abv: Double?) -> Blend.Part {
        Blend.Part(key: key, name: key.capitalized, milliliters: ml, abv: abv)
    }

    /// Alcohol is conserved: 100 ml at 60% and 100 ml at 40% is 200 ml at
    /// 50%, not "somewhere in between".
    func testStrengthIsAlcoholOverVolume() {
        let profile = Blend.profile([part("a", 100, abv: 60), part("b", 100, abv: 40)])
        XCTAssertEqual(profile.abv ?? 0, 50, accuracy: 0.0001)
        XCTAssertEqual(profile.proof ?? 0, 100, accuracy: 0.0001)
        XCTAssertEqual(profile.strengthText, "100.0 proof")
    }

    func testAnUnevenBlendWeightsByVolume() {
        // 300 ml at 62.1% and 100 ml at 45%: (300*62.1 + 100*45) / 400
        let profile = Blend.profile([part("a", 300, abv: 62.1), part("b", 100, abv: 45)])
        XCTAssertEqual(profile.abv ?? 0, 57.825, accuracy: 0.0001)
    }

    /// A part with no known proof makes the whole strength unknown. Guessing
    /// a barrel-proof bottle at the catalogue's null would print a number
    /// that is wrong for every bottle.
    func testOneUnknownPartMakesTheStrengthUnknownAndSaysHowMuch() {
        let profile = Blend.profile([part("a", 100, abv: 50), part("b", 60, abv: nil)])
        XCTAssertNil(profile.abv)
        XCTAssertEqual(profile.unknownMilliliters, 60)
        XCTAssertEqual(profile.strengthText, "Unknown — 60 ml went in without a proof")
    }

    func testSharesAreByWhatWentInMergedBySource() {
        let profile = Blend.profile([
            part("weller", 50, abv: 45), part("stagg", 100, abv: 65), part("weller", 50, abv: 45),
        ])
        XCTAssertEqual(profile.shares.map(\.key), ["stagg", "weller"])
        XCTAssertEqual(profile.shares.map(\.milliliters), [100, 100])
        XCTAssertEqual(profile.shares.map { $0.fraction }, [0.5, 0.5])
        XCTAssertEqual(profile.addedMilliliters, 200)
        XCTAssertEqual(profile.partCount, 2)
    }

    func testEqualSharesSortByNameSoTheListIsStable() {
        let profile = Blend.profile([part("zed", 50, abv: 45), part("abe", 50, abv: 45)])
        XCTAssertEqual(profile.shares.map(\.key), ["abe", "zed"])
    }

    func testASplashIsUnderOnePercentRatherThanZero() {
        let profile = Blend.profile([part("a", 1000, abv: 45), part("b", 5, abv: 45)])
        XCTAssertEqual(profile.shares.last?.percentText, "under 1%")
        XCTAssertEqual(profile.shares.first?.percentText, "100%")
    }

    func testNothingInItYet() {
        let profile = Blend.profile([])
        XCTAssertTrue(profile.isEmpty)
        XCTAssertNil(profile.abv)
        XCTAssertEqual(profile.strengthText, "Nothing in it yet")
        XCTAssertTrue(profile.shares.isEmpty)
    }

    func testZeroAndNegativeVolumesAreIgnored() {
        let profile = Blend.profile([part("a", 0, abv: 50), part("b", -5, abv: 50), part("c", 30, abv: 50)])
        XCTAssertEqual(profile.shares.map(\.key), ["c"])
        XCTAssertEqual(profile.abv ?? 0, 50, accuracy: 0.0001)
    }
}
