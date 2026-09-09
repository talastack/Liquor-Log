import XCTest
@testable import LiquorEngine

/// Reading a label is regular expressions over text Vision recognised, not a
/// model — so unlike the camera half, all of it is testable on any machine.
///
/// The bar these have to clear: a misread proof that silently becomes a
/// bottle's strength poisons cost-per-pour, the perceived-proof verdict and the
/// shelf check at once, and unlike a typo nobody would know they had made it.
final class LabelReaderTests: XCTestCase {

    // MARK: - Strength

    func testItReadsProofFromALabel() {
        let reading = LabelReader.read(["ELIJAH CRAIG", "BARREL PROOF", "124.2 PROOF"])
        XCTAssertEqual(reading.proof ?? 0, 124.2, accuracy: 0.01)
        XCTAssertEqual(reading.abv ?? 0, 62.1, accuracy: 0.01)
    }

    func testItReadsProofWrittenTheOtherWayRound() {
        let reading = LabelReader.read(["PROOF: 107"])
        XCTAssertEqual(reading.proof ?? 0, 107, accuracy: 0.01)
    }

    func testItReadsAbvAndDerivesProof() {
        let reading = LabelReader.read(["45% ALC/VOL"])
        XCTAssertEqual(reading.abv ?? 0, 45, accuracy: 0.01)
        XCTAssertEqual(reading.proof ?? 0, 90, accuracy: 0.01)
    }

    /// Proof is printed larger and is the number people read off a label, so
    /// when both are present the proof decides. Deriving the wrong way round is
    /// how a bottle gets recorded at half its strength.
    func testProofWinsWhenBothArePrinted() {
        let reading = LabelReader.read(["62.1% ALC/VOL", "124.2 PROOF"])
        XCTAssertEqual(reading.abv ?? 0, 62.1, accuracy: 0.01)
    }

    /// Labels print mashbill percentages too. A "%" over 95 is not a strength.
    func testAMashbillPercentageIsNotMistakenForStrength() {
        let reading = LabelReader.read(["MASHBILL: 99% CORN"])
        XCTAssertNil(reading.abv, "99% is a grain share, not a strength")
    }

    /// And the mashbill must not shadow the real one. Taking only the FIRST
    /// percentage would find 99, reject it, and lose the 45 further down.
    func testAMashbillDoesNotHideTheStrengthBelowIt() {
        let reading = LabelReader.read([
            "MASHBILL: 99% CORN 1% MALTED BARLEY",
            "45% ALC/VOL",
        ])
        XCTAssertEqual(reading.abv ?? 0, 45, accuracy: 0.01)
    }

    /// A bare number is not a proof. Labels are covered in numbers.
    func testABareNumberIsNotTakenAsProof() {
        let reading = LabelReader.read(["ESTABLISHED 1789", "LOT 4211"])
        XCTAssertNil(reading.proof)
    }

    // MARK: - The barrel fields

    func testItReadsAnElijahCraigBatchCode() {
        let reading = LabelReader.read(["BATCH B523"])
        XCTAssertEqual(reading.batchCode, "B523")
    }

    func testItReadsABarrelNumber() {
        let reading = LabelReader.read(["BARREL NO. 42-3C"])
        XCTAssertEqual(reading.barrelNumber, "42-3C")
    }

    /// Validated against the ten real codes rather than matched by shape, so
    /// any other four-letter word on the label is not mistaken for one.
    func testItRecognisesAFourRosesRecipeCode() {
        let reading = LabelReader.read(["FOUR ROSES", "SINGLE BARREL", "OESQ"])
        XCTAssertEqual(reading.recipeCode, "OESQ")
    }

    func testAFourLetterWordIsNotARecipeCode() {
        let reading = LabelReader.read(["FOUR ROSES", "MASH", "OAKY", "CASK"])
        XCTAssertNil(reading.recipeCode)
    }

    func testItReadsAnAgeStatement() {
        XCTAssertEqual(LabelReader.read(["AGED 12 YEARS"]).statedAgeYears, 12)
        XCTAssertEqual(LabelReader.read(["10 YEARS OLD"]).statedAgeYears, 10)
    }

    func testItReadsTheSize() {
        XCTAssertEqual(LabelReader.read(["750 ML"]).volumeMilliliters, 750)
        XCTAssertEqual(LabelReader.read(["1.75 L"]).volumeMilliliters, 1750)
    }

    // MARK: - Claims on the label

    func testItNoticesTheProductionClaims() {
        let reading = LabelReader.read([
            "KENTUCKY STRAIGHT BOURBON", "BOTTLED IN BOND", "SINGLE BARREL",
        ])
        XCTAssertTrue(reading.isBottledInBond)
        XCTAssertTrue(reading.isSingleBarrel)
        XCTAssertFalse(reading.isSmallBatch)
    }

    // MARK: - Finding the name

    /// The warning text is the largest block on many labels and would drag any
    /// search straight away from the brand.
    func testTheGovernmentWarningIsNotTakenForAName() {
        let lines = LabelReader.nameLines([
            "ELIJAH CRAIG",
            "GOVERNMENT WARNING: ACCORDING TO THE SURGEON GENERAL",
            "WOMEN SHOULD NOT DRINK ALCOHOLIC BEVERAGES DURING PREGNANCY",
        ])
        XCTAssertEqual(lines, ["ELIJAH CRAIG"])
    }

    func testMeasuresAreNotTakenForAName() {
        let lines = LabelReader.nameLines(["750 ML", "124.2 PROOF", "WELLER"])
        XCTAssertEqual(lines, ["WELLER"])
    }

    func testShortFragmentsAreDropped() {
        XCTAssertEqual(LabelReader.nameLines(["A", "OF", "BUFFALO TRACE"]), ["BUFFALO TRACE"])
    }

    // MARK: - Matching the catalogue

    func testItSuggestsCatalogueMatches() {
        let catalog = [
            SearchCandidate(product: ProductIdentity(
                productId: "ec-barrel-proof", distillery: "Heaven Hill",
                brand: "Elijah Craig", expression: "Barrel Proof",
                classType: .kentuckyStraightBourbon, productionType: .smallBatch)),
            SearchCandidate(product: ProductIdentity(
                productId: "buffalo-trace", distillery: "Buffalo Trace",
                brand: "Buffalo Trace", expression: "",
                classType: .kentuckyStraightBourbon, productionType: .unspecified)),
        ]

        let reading = LabelReader.read([
            "ELIJAH CRAIG", "BARREL PROOF", "124.2 PROOF", "750 ML",
        ])
        let hits = LabelReader.candidates(for: reading, in: catalog)

        XCTAssertEqual(hits.first?.product.productId, "ec-barrel-proof")
    }

    /// A photo of a wall returns nothing, and must produce nothing rather than
    /// a confident wrong answer.
    func testAnUnreadableLabelSuggestsNothing() {
        let reading = LabelReader.read([])
        XCTAssertTrue(reading.isEmpty)
        XCTAssertTrue(LabelReader.candidates(for: reading, in: []).isEmpty)
    }

    /// Vision returns lines in the order it found them, which on a wrap-around
    /// label is not reading order.
    func testLineOrderDoesNotMatter() {
        let forwards = LabelReader.read(["ELIJAH CRAIG", "BATCH B523", "124.2 PROOF"])
        let backwards = LabelReader.read(["124.2 PROOF", "BATCH B523", "ELIJAH CRAIG"])
        XCTAssertEqual(forwards.proof, backwards.proof)
        XCTAssertEqual(forwards.batchCode, backwards.batchCode)
    }

    /// Recognition is case-noisy in practice.
    func testItToleratesLowercase() {
        let reading = LabelReader.read(["elijah craig", "batch b523", "124.2 proof"])
        XCTAssertEqual(reading.batchCode, "B523")
        XCTAssertEqual(reading.proof ?? 0, 124.2, accuracy: 0.01)
    }
}
