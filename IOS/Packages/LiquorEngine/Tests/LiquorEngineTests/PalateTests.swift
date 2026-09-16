import XCTest
@testable import LiquorEngine

/// Averages over your own ratings, each with its count, and nothing said
/// below three a side.
final class PalateTests: XCTestCase {

    private func t(
        _ classType: ClassType? = .kentuckyStraightBourbon, abv: Double? = 50, wheated: Bool? = nil,
        rating: Int? = nil, heat: Int? = nil, finish: Int? = nil, rebuy: Bool? = nil, words: [String] = []
    ) -> Palate.Tasting {
        Palate.Tasting(classType: classType, abv: abv, isWheated: wheated, rating: rating,
                       perceivedHeat: heat, finishSeconds: finish, wouldRebuy: rebuy, descriptors: words)
    }

    func testWordsAreCountedOncePerTastingMostUsedFirst() {
        let profile = Palate.profile([
            t(words: ["caramel", "oak", "caramel"]), t(words: ["caramel", "cherry"]), t(words: ["oak"]),
        ])
        XCTAssertEqual(profile.words.map(\.key), ["caramel", "oak", "cherry"])
        XCTAssertEqual(profile.words.first?.count, 2, "twice in one tasting is one use")
    }

    func testRatingsByClassNeedThreeASide() {
        let profile = Palate.profile([
            t(.straightRye, rating: 9), t(.straightRye, rating: 8), t(.straightRye, rating: 8),
            t(.kentuckyStraightBourbon, rating: 6), t(.kentuckyStraightBourbon, rating: 7), t(.kentuckyStraightBourbon, rating: 8),
            t(.singleMaltScotch, rating: 10), t(.singleMaltScotch, rating: 10),
        ])
        XCTAssertEqual(profile.byClass.map(\.label), ["Straight Rye Whiskey", "Kentucky Straight Bourbon Whiskey"])
        XCTAssertEqual(profile.byClass.first?.averageText, "8.3")
        XCTAssertEqual(profile.byClass.first?.count, 3)
        let sentences = Palate.sentences(profile) { $0 }
        XCTAssertTrue(sentences.contains {
            $0 == "Straight Rye Whiskey rates highest with you: 8.3 on average over 3, against 7.0 for Kentucky Straight Bourbon Whiskey."
        })
    }

    func testStrengthBandsRunStrongestFirstAndReadAsASentence() {
        let profile = Palate.profile([
            t(abv: 62, rating: 9), t(abv: 60, rating: 9), t(abv: 65, rating: 8),
            t(abv: 43, rating: 6), t(abv: 44, rating: 7), t(abv: 41, rating: 6),
        ])
        XCTAssertEqual(profile.byStrength.map(\.label), ["115 proof and up", "80–89 proof"])
        let sentences = Palate.sentences(profile) { $0 }
        XCTAssertTrue(sentences.contains { $0.hasPrefix("The stronger the better") })
    }

    func testWheatedAgainstTheRest() {
        let profile = Palate.profile([
            t(wheated: true, rating: 9), t(wheated: true, rating: 8), t(wheated: true, rating: 9),
            t(wheated: false, rating: 6), t(wheated: false, rating: 7), t(wheated: false, rating: 7),
            t(.singleMaltScotch, rating: 8),
        ])
        XCTAssertEqual(profile.wheated?.averageText, "8.7")
        XCTAssertEqual(profile.otherBourbon?.averageText, "6.7")
        XCTAssertTrue(Palate.sentences(profile) { $0 }.contains { $0.hasPrefix("Wheated bourbons rate 8.7") })
    }

    func testHeatFinishAndRebuy() {
        let profile = Palate.profile([
            t(rating: 6, heat: 5, finish: 30, rebuy: true), t(rating: 6, heat: 4, finish: 60, rebuy: false),
            t(rating: 5, heat: 5, finish: 45, rebuy: true), t(rating: 8, heat: 1, rebuy: true),
            t(rating: 9, heat: 2), t(rating: 8, heat: 2),
        ])
        XCTAssertEqual(profile.averageFinishSeconds, 45)
        XCTAssertEqual(profile.rebuyShare ?? 0, 0.75, accuracy: 0.0001)
        let sentences = Palate.sentences(profile) { $0 }
        XCTAssertTrue(sentences.contains { $0.hasPrefix("Heat costs a bottle points with you") })
        XCTAssertTrue(sentences.contains("A finish runs about 45 seconds by your count."))
        XCTAssertTrue(sentences.contains("You would buy again 8 of every 10 you rated."))
    }

    /// The same bottle rated blind and knowing what it was, paired by
    /// product; the average gap is the label's worth to you.
    func testLabelBiasPairsBlindAndSightedRatingsOfTheSameBottle() {
        let profile = Palate.profile([
            t(rating: 9, words: []).with(product: "w12"), t(rating: 7).with(product: "w12", blind: true),
            t(rating: 8).with(product: "ec"), t(rating: 6).with(product: "ec", blind: true), t(rating: 8).with(product: "ec", blind: true),
            t(rating: 7).with(product: "fr"), t(rating: 7).with(product: "fr", blind: true),
            t(rating: 10).with(product: "lonely"),
        ])
        // w12: 9 − 7 = 2; ec: 8 − 7 = 1; fr: 0 → 1.0 over three pairs.
        XCTAssertEqual(profile.labelBiasPairs, 3)
        XCTAssertEqual(profile.labelBias ?? 0, 1.0, accuracy: 0.0001)
        let sentences = Palate.sentences(profile) { $0 }
        XCTAssertTrue(sentences.contains { $0.hasPrefix("Knowing the label adds 1.0 points") })
    }

    func testTwoPairsAreNotABias() {
        let profile = Palate.profile([
            t(rating: 9).with(product: "a"), t(rating: 5).with(product: "a", blind: true),
            t(rating: 9).with(product: "b"), t(rating: 5).with(product: "b", blind: true),
        ])
        XCTAssertNil(profile.labelBias)
    }

    /// Two tastings say nothing yet. Silence is the honest profile.
    func testTooFewSaysNothing() {
        let profile = Palate.profile([t(rating: 9, words: ["oak"]), t(rating: 3, words: ["oak"])])
        XCTAssertTrue(profile.byClass.isEmpty)
        XCTAssertNil(profile.rebuyShare)
        XCTAssertTrue(Palate.sentences(profile) { $0 }.isEmpty)
        XCTAssertTrue(Palate.profile([]).isEmpty)
    }
}

private extension Palate.Tasting {
    func with(product: String, blind: Bool = false) -> Palate.Tasting {
        Palate.Tasting(
            productId: product, isBlind: blind, classType: classType, abv: abv, isWheated: isWheated,
            rating: rating, perceivedHeat: perceivedHeat, finishSeconds: finishSeconds,
            wouldRebuy: wouldRebuy, descriptors: descriptors)
    }
}
