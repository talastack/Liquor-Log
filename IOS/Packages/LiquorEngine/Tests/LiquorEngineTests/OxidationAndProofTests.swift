import XCTest
@testable import LiquorEngine

final class OxidationBandTests: XCTestCase {

    /// The design's own two cases, which pin the model.
    func testAMostlyFullBottleOpenSixWeeksIsFresh() {
        let e = OxidationBand.estimate(headroomFraction: 0.24, daysOpen: 44)
        XCTAssertEqual(e.band, .fresh)
    }

    func testAMostlyEmptyBottleOpenSevenMonthsIsFading() {
        let e = OxidationBand.estimate(headroomFraction: 0.70, daysOpen: 213)
        XCTAssertEqual(e.band, .fading)
        XCTAssertEqual(e.headroomPercent, 70)
    }

    /// Headroom is the input that matters, but it cannot act without time. A
    /// bottle drunk three-quarters down in a fortnight has barely changed.
    func testDrinkingItFastDoesNotAgeIt() {
        let e = OxidationBand.estimate(headroomFraction: 0.80, daysOpen: 10)
        XCTAssertEqual(e.band, .fresh)
    }

    /// And time cannot act without air. A sealed-full bottle does not oxidise.
    func testAFullBottleNeverFadesHoweverLongItSits() {
        let e = OxidationBand.estimate(headroomFraction: 0, daysOpen: 3_650)
        XCTAssertEqual(e.band, .fresh)
        XCTAssertEqual(e.exposure, 0, accuracy: 0.0001)
    }

    func testAHeelLeftForYearsIsFaded() {
        XCTAssertEqual(OxidationBand.estimate(headroomFraction: 0.92, daysOpen: 900).band, .faded)
    }

    func testBandsRunInOrder() {
        XCTAssertEqual(OxidationBand.Band.fresh.step, 0)
        XCTAssertEqual(OxidationBand.Band.faded.step, 3)
        for band in OxidationBand.Band.allCases {
            XCTAssertFalse(band.label.isEmpty)
        }
    }

    func testInputsAreClamped() {
        let silly = OxidationBand.estimate(headroomFraction: 5, daysOpen: -20)
        XCTAssertEqual(silly.headroomFraction, 1, accuracy: 0.0001)
        XCTAssertEqual(silly.daysOpen, 0)
        XCTAssertEqual(silly.band, .fresh)
    }

    /// The estimate is not defensible without the hedge, so it travels with it.
    func testEveryEstimateCarriesTheCaveat() {
        for days in [1, 60, 200, 900] {
            let e = OxidationBand.estimate(headroomFraction: 0.6, daysOpen: days)
            XCTAssertTrue(e.caveat.contains("rule of thumb"))
            XCTAssertTrue(e.caveat.contains("never a date"))
            XCTAssertFalse(e.summary.isEmpty)
        }
    }

    func testItTakesAFillLevelDirectly() {
        let level = FillLevel(remainingMilliliters: 222, capacityMilliliters: 750)
        let e = OxidationBand.estimate(fillLevel: level, daysOpen: 213)
        XCTAssertEqual(e.band, .fading)
    }
}

final class PerceivedProofTests: XCTestCase {

    func testStrengthMapsToExpectedHeat() {
        XCTAssertEqual(PerceivedProof.expectedHeat(for: ABV(percent: 40)), .gentle)
        XCTAssertEqual(PerceivedProof.expectedHeat(for: ABV(percent: 47)), .warm)
        XCTAssertEqual(PerceivedProof.expectedHeat(for: ABV(percent: 50.5)), .firm)
        XCTAssertEqual(PerceivedProof.expectedHeat(for: ABV(percent: 57.7)), .hot)
        XCTAssertEqual(PerceivedProof.expectedHeat(for: ABV(percent: 62.1)), .scorching)
    }

    /// The compliment, and the reason the feature exists: a barrel-proof
    /// bourbon you can drink neat.
    func testABarrelProofThatGoesDownEasyDrinksBelowItsProof() {
        let r = PerceivedProof.compare(abv: ABV(percent: 62.1), felt: .hot)
        XCTAssertEqual(r.verdict, .drinksBelowItsProof)
        XCTAssertTrue(r.summary.contains("124.2"))
    }

    func testAMatchingHeatDrinksAboutRight() {
        let r = PerceivedProof.compare(abv: ABV(percent: 47), felt: .warm)
        XCTAssertEqual(r.verdict, .drinksAtItsProof)
        XCTAssertEqual(r.difference, 0)
    }

    func testAHarshLowProofDrinksAboveItsProof() {
        let r = PerceivedProof.compare(abv: ABV(percent: 40), felt: .scorching)
        XCTAssertEqual(r.verdict, .drinksAboveItsProof)
        XCTAssertEqual(r.difference, 4)
        XCTAssertTrue(r.summary.contains("water"))
    }

    /// One step is within the noise of a person's own palate on the day.
    func testOneStepEitherWayIsStillAboutRight() {
        XCTAssertEqual(
            PerceivedProof.compare(abv: ABV(percent: 50.5), felt: .firm).verdict,
            .drinksAtItsProof)
    }

    func testEveryHeatAndVerdictHasALabel() {
        for heat in PerceivedProof.Heat.allCases { XCTAssertFalse(heat.label.isEmpty) }
        for verdict in PerceivedProof.Verdict.allCases { XCTAssertFalse(verdict.label.isEmpty) }
    }
}
