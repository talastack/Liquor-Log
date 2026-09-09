import XCTest
@testable import LiquorEngine

/// The rule these exist to hold: everything counts the COLLECTION, never the
/// drinking. Nothing here may go up because somebody drank more.
final class CollectionStatsTests: XCTestCase {

    private func entry(
        _ classType: ClassType? = .kentuckyStraightBourbon,
        distillery: String? = "Heaven Hill",
        abv: Double? = 47,
        open: Bool = false,
        finished: Bool = false,
        ageMonths: Int? = nil
    ) -> CollectionStats.Entry {
        CollectionStats.Entry(
            classType: classType, distillery: distillery, abv: abv,
            isOpen: open, isFinished: finished, ageMonths: ageMonths)
    }

    // MARK: - What it counts

    /// A collection is what you have, not what you have had.
    func testFinishedBottlesAreCountedApartAndNeverFoldedIn() {
        let summary = CollectionStats.summarise([
            entry(), entry(), entry(finished: true),
        ])
        XCTAssertEqual(summary.onShelf, 2)
        XCTAssertEqual(summary.finished, 1)
    }

    func testOpenAndSealedAddUpToTheShelf() {
        let summary = CollectionStats.summarise([
            entry(open: true), entry(open: true), entry(),
        ])
        XCTAssertEqual(summary.open, 2)
        XCTAssertEqual(summary.sealed, 1)
        XCTAssertEqual(summary.open + summary.sealed, summary.onShelf)
    }

    /// The whole point of the guardrail: drinking a bottle must not make any
    /// number here go up.
    func testFinishingABottleNeverIncreasesAnything() {
        let before = CollectionStats.summarise([entry(open: true), entry()])
        let after = CollectionStats.summarise([entry(finished: true), entry()])

        XCTAssertLessThan(after.onShelf, before.onShelf)
        XCTAssertLessThanOrEqual(after.open, before.open)
        XCTAssertLessThanOrEqual(after.byClass.first?.count ?? 0,
                                 before.byClass.first?.count ?? 0)
    }

    // MARK: - The slices

    func testItBreaksDownByClass() {
        let summary = CollectionStats.summarise([
            entry(.kentuckyStraightBourbon), entry(.kentuckyStraightBourbon),
            entry(.straightRye),
        ])
        XCTAssertEqual(summary.byClass.first?.count, 2)
        XCTAssertEqual(summary.classCount, 2)
    }

    func testItBreaksDownByDistillery() {
        let summary = CollectionStats.summarise([
            entry(distillery: "Buffalo Trace"), entry(distillery: "Buffalo Trace"),
            entry(distillery: "Wild Turkey"),
        ])
        XCTAssertEqual(summary.byDistillery.first?.label, "Buffalo Trace")
        XCTAssertEqual(summary.distilleryCount, 2)
    }

    /// The interesting fact is "I own a lot of barrel proof", which four labels
    /// say better than a histogram of exact figures.
    func testStrengthIsBanded() {
        XCTAssertEqual(CollectionStats.strengthBand(43), "80–89 proof")
        XCTAssertEqual(CollectionStats.strengthBand(47), "90–99 proof")
        XCTAssertEqual(CollectionStats.strengthBand(50), "100–114 proof")
        XCTAssertEqual(CollectionStats.strengthBand(62.1), "115 proof and up")
    }

    /// A chart whose order changes between launches reads as a bug.
    func testEqualCountsSortAlphabeticallyRatherThanArbitrarily() {
        let summary = CollectionStats.summarise([
            entry(distillery: "Wild Turkey"), entry(distillery: "Buffalo Trace"),
        ])
        XCTAssertEqual(summary.byDistillery.map(\.label), ["Buffalo Trace", "Wild Turkey"])
    }

    func testSharesAreProportions() {
        let summary = CollectionStats.summarise([
            entry(.kentuckyStraightBourbon), entry(.kentuckyStraightBourbon),
            entry(.straightRye), entry(.straightRye),
        ])
        XCTAssertEqual(summary.byClass.first?.share(of: summary.onShelf), 0.5)
    }

    func testAShareOfNothingIsZeroRatherThanACrash() {
        XCTAssertEqual(CollectionStats.Slice(label: "x", count: 3).share(of: 0), 0)
    }

    // MARK: - Bottle properties

    /// Rarity and strength work as properties of a bottle. Scoreboards do not.
    func testItReportsTheStrongestBottleAsProof() {
        let summary = CollectionStats.summarise([entry(abv: 47), entry(abv: 62.1)])
        XCTAssertEqual(summary.highestProof ?? 0, 124.2, accuracy: 0.01)
    }

    func testMissingFactsAreSimplyAbsent() {
        let summary = CollectionStats.summarise([entry(nil, distillery: nil, abv: nil)])
        XCTAssertNil(summary.highestProof)
        XCTAssertNil(summary.oldestStatedAgeMonths)
        XCTAssertTrue(summary.byClass.isEmpty)
        XCTAssertEqual(summary.onShelf, 1, "a bottle with no facts is still a bottle")
    }

    func testAnEmptyCollectionIsEmpty() {
        XCTAssertTrue(CollectionStats.summarise([]).isEmpty)
    }
}

/// The guest menu. Asked for unprompted in the research and never built until
/// now: *"I really like the menu concept! Now if there was a way to take the
/// spreadsheet and populate the menu......"*
final class PourMenuTests: XCTestCase {

    func testItListsWhatIsOpen() {
        let text = PourMenu.text(title: "Open tonight", items: [
            PourMenu.Item(name: "Elijah Craig Barrel Proof", proof: 124.2),
            PourMenu.Item(name: "Four Roses Single Barrel", detail: "OESQ", proof: 100),
        ])
        XCTAssertTrue(text.contains("Elijah Craig Barrel Proof"))
        XCTAssertTrue(text.contains("124.2 proof"))
        XCTAssertTrue(text.contains("OESQ"))
    }

    func testAnEmptyMenuSaysSoRatherThanBeingBlank() {
        let text = PourMenu.text(title: "Open tonight", items: [])
        XCTAssertTrue(text.contains("Nothing open"))
    }

    /// A menu with prices on it reads as bragging about what the evening cost,
    /// and the one thing a guest cannot do with that is enjoy the whiskey.
    func testAMenuNeverCarriesPrices() {
        let text = PourMenu.text(title: "Open tonight", items: [
            PourMenu.Item(name: "Weller 12", detail: "wheated", proof: 90),
        ])
        XCTAssertFalse(text.contains("$"))
    }

    /// It has to survive being pasted into a message, so no markup.
    func testItIsPlainText() {
        let text = PourMenu.text(title: "Open tonight", items: [
            PourMenu.Item(name: "Weller 12", proof: 90),
        ])
        XCTAssertFalse(text.contains("<"))
        XCTAssertFalse(text.contains("*"))
    }
}
