import XCTest
@testable import LiquorEngine

/// The walk has one job: be finishable. Every test here is about the order the
/// bottles come in, because that is the only thing standing between a shelf
/// walk and an abandoned list.
final class ReInventoryTests: XCTestCase {

    private var now: Date { Date(timeIntervalSince1970: 400 * 86_400) }

    private func item(
        _ id: String, at location: String? = nil, verifiedDaysAgo: Int? = nil
    ) -> ReInventory.Item {
        ReInventory.Item(
            id: id,
            name: id,
            storageLocation: location,
            lastVerifiedAt: verifiedDaysAgo.map { now.addingTimeInterval(Double(-$0) * 86_400) })
    }

    // MARK: - Grouping

    /// You are walking past shelves. A queue that sends you from the closet to
    /// the basement and back is a queue nobody finishes.
    func testBottlesAreGroupedByWhereTheyAre() {
        let plan = ReInventory.plan([
            item("a", at: "closet", verifiedDaysAgo: 10),
            item("b", at: "basement", verifiedDaysAgo: 10),
            item("c", at: "closet", verifiedDaysAgo: 10),
        ], now: now)

        XCTAssertEqual(plan.count, 2)
        let closet = plan.first { $0.location == "closet" }
        XCTAssertEqual(closet?.items.map(\.id).sorted(), ["a", "c"])
    }

    /// The shelf you have not looked at in longest is the one worth walking
    /// first, in case the walk stops early.
    func testStalestLocationComesFirst() {
        let plan = ReInventory.plan([
            item("fresh", at: "bar top", verifiedDaysAgo: 5),
            item("stale", at: "basement", verifiedDaysAgo: 300),
        ], now: now)

        XCTAssertEqual(plan.first?.location, "basement")
    }

    func testStalestBottleLeadsItsOwnLeg() {
        let plan = ReInventory.plan([
            item("recent", at: "closet", verifiedDaysAgo: 3),
            item("old", at: "closet", verifiedDaysAgo: 200),
        ], now: now)

        XCTAssertEqual(plan.first?.items.map(\.id), ["old", "recent"])
    }

    /// A bottle nobody has ever confirmed is the least trustworthy row there is.
    func testNeverVerifiedSortsAboveEverything() {
        let plan = ReInventory.plan([
            item("ancient", at: "closet", verifiedDaysAgo: 900),
            item("never", at: "closet", verifiedDaysAgo: nil),
        ], now: now)

        XCTAssertEqual(plan.first?.items.first?.id, "never")
    }

    /// Bottles with no location are the ones you have to hunt for. Leading with
    /// them is how a walk stalls on its first entry — even though they are, by
    /// staleness alone, the most urgent.
    func testUnplacedBottlesGoLastDespiteBeingStalest() {
        let plan = ReInventory.plan([
            item("homeless", at: nil, verifiedDaysAgo: nil),
            item("shelved", at: "closet", verifiedDaysAgo: 1),
        ], now: now)

        XCTAssertEqual(plan.map(\.location), ["closet", nil])
        XCTAssertEqual(plan.last?.title, "No location recorded")
    }

    func testAnEmptyCollectionPlansNothing() {
        XCTAssertTrue(ReInventory.plan([], now: now).isEmpty)
    }

    // MARK: - Prompting

    /// People do this once or twice a year. Nagging sooner trains them to
    /// ignore it.
    func testAWalkIsNotDueUntilSomethingIsSixMonthsStale() {
        let recent = [item("a", at: "closet", verifiedDaysAgo: 30)]
        XCTAssertFalse(ReInventory.isDue(recent, now: now))

        let stale = [item("a", at: "closet", verifiedDaysAgo: 200)]
        XCTAssertTrue(ReInventory.isDue(stale, now: now))
    }

    func testAnEmptyCollectionIsNeverDue() {
        XCTAssertFalse(ReInventory.isDue([], now: now))
    }

    func testNeverVerifiedCountsAsDue() {
        XCTAssertTrue(ReInventory.isDue([item("a", verifiedDaysAgo: nil)], now: now))
    }

    // MARK: - Outcome

    func testOutcomeSplitsDecisionsThreeWays() {
        let outcome = ReInventory.outcome(from: [
            ("a", .present), ("b", .gone), ("c", .skipped),
        ])
        XCTAssertEqual(outcome.confirmed, ["a"])
        XCTAssertEqual(outcome.gone, ["b"])
        XCTAssertEqual(outcome.skipped, ["c"])
        XCTAssertEqual(outcome.checkedCount, 2)
    }

    /// People change their mind halfway down a shelf.
    func testTheLastDecisionOnABottleWins() {
        let outcome = ReInventory.outcome(from: [("a", .gone), ("a", .present)])
        XCTAssertEqual(outcome.confirmed, ["a"])
        XCTAssertTrue(outcome.gone.isEmpty)
    }

    /// Marking bottles finished is bookkeeping, not an achievement. Nothing in
    /// this app is allowed to read as a score.
    func testTheSummaryDoesNotCelebrate() {
        let outcome = ReInventory.outcome(from: [("a", .present), ("b", .gone)])
        XCTAssertEqual(outcome.summary, "1 still on the shelf, 1 marked finished.")
    }

    func testAnUntouchedWalkSaysSo() {
        XCTAssertEqual(ReInventory.outcome(from: []).summary, "Nothing checked.")
    }
}

final class CollectionValueTests: XCTestCase {

    private func holding(_ cents: Int?, finished: Bool = false) -> CollectionValue.Holding {
        CollectionValue.Holding(purchasePriceCents: cents, isFinished: finished)
    }

    /// The single most important line in this type. Somebody has to ask.
    func testTheTotalIsHiddenByDefault() {
        XCTAssertFalse(CollectionValue.shownByDefault)
    }

    func testItSumsWhatYouPaid() {
        let total = CollectionValue.onTheShelf([holding(7999), holding(4500)])
        XCTAssertEqual(total.cents, 12_499)
        XCTAssertEqual(total.bottlesCounted, 2)
    }

    /// The number people want is for insurance and recall — both about what is
    /// in the house. Lifetime spend is the figure they are running from.
    func testFinishedBottlesAreNotCounted() {
        let total = CollectionValue.onTheShelf([
            holding(7999), holding(9999, finished: true),
        ])
        XCTAssertEqual(total.cents, 7999)
        XCTAssertEqual(total.bottlesCounted, 1)
        XCTAssertEqual(total.bottlesWithoutPrice, 0)
    }

    /// Most people price some bottles and not others. Presenting that sum as a
    /// total would be a claim; it is a floor.
    func testUnpricedBottlesMakeTheFigurePartial() {
        let total = CollectionValue.onTheShelf([holding(7999), holding(nil), holding(nil)])
        XCTAssertTrue(total.isPartial)
        XCTAssertEqual(total.bottlesWithoutPrice, 2)
        XCTAssertTrue(total.caveat.contains("2 bottles have no price"))
        XCTAssertTrue(total.caveat.contains("higher"))
    }

    func testTheCaveatIsSingularForOneBottle() {
        let total = CollectionValue.onTheShelf([holding(nil)])
        XCTAssertTrue(total.caveat.contains("1 bottle has no price"))
    }

    /// We do not have market data, cannot keep it current, and being wrong
    /// about it costs more than being silent.
    func testTheCaveatAlwaysDisclaimsResaleValue() {
        let complete = CollectionValue.onTheShelf([holding(1000)])
        XCTAssertEqual(complete.caveat, "What you paid, not what it is worth.")
        XCTAssertFalse(complete.isPartial)
    }

    func testAnEmptyShelfIsZeroAndNotPartial() {
        let total = CollectionValue.onTheShelf([])
        XCTAssertEqual(total.cents, 0)
        XCTAssertFalse(total.isPartial)
    }
}
