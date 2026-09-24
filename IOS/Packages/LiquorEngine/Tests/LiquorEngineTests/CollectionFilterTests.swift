import XCTest
@testable import LiquorEngine

/// Finding one bottle in two hundred. These pin the rules the screen relies
/// on: prefix matching like the shop search, kinds that narrow rather than
/// widen, and sorts that put the useless rows (never poured, unrated,
/// finished) at the bottom rather than the top.
final class CollectionFilterTests: XCTestCase {

    private func day(_ n: Int) -> Date { Date(timeIntervalSince1970: Double(n) * 86_400) }

    /// A row that is nothing but its class, for the family-chip tests.
    private func row(classType: ClassType) -> CollectionFilter.Row {
        CollectionFilter.Row(
            id: classType.rawValue, name: classType.label, distillery: "Somewhere",
            classType: classType, addedAt: day(1), fillFraction: 1)
    }

    private var shelf: [CollectionFilter.Row] {
        [
            CollectionFilter.Row(
                id: "ecbp", name: "Elijah Craig Barrel Proof B523", distillery: "Heaven Hill",
                extraSearchText: ["B523", "Cabinet"],
                classType: .kentuckyStraightBourbon, productionType: .smallBatch,
                isBarrelProof: true, isOpen: true, storageLocation: "Cabinet",
                addedAt: day(10), lastPouredAt: day(12), rating: 8, fillFraction: 0.6),
            CollectionFilter.Row(
                id: "fr", name: "Four Roses Single Barrel OESQ", distillery: "Four Roses",
                extraSearchText: ["42-3C", "Total Wine", "Basement"],
                classType: .kentuckyStraightBourbon, productionType: .singleBarrel,
                isBarrelProof: true, isStorePick: true, storageLocation: "Basement",
                addedAt: day(20), rating: nil, fillFraction: 1),
            CollectionFilter.Row(
                id: "weller", name: "W L Weller Special Reserve", distillery: "Buffalo Trace",
                classType: .kentuckyStraightBourbon, isOpen: true, storageLocation: "Cabinet",
                addedAt: day(5), lastPouredAt: day(30), rating: 6, fillFraction: 0.1),
            CollectionFilter.Row(
                id: "rye", name: "Rittenhouse Rye", distillery: "Heaven Hill",
                classType: .straightRye, isBottledInBond: true,
                addedAt: day(1), fillFraction: 1),
            CollectionFilter.Row(
                id: "dead", name: "Eagle Rare 10", distillery: "Buffalo Trace",
                classType: .kentuckyStraightBourbon, productionType: .singleBarrel,
                isOpen: true, isFinished: true,
                addedAt: day(0), lastPouredAt: day(2), rating: 7, fillFraction: 0),
            CollectionFilter.Row(
                id: "lag", name: "Lagavulin 16", distillery: "Lagavulin",
                classType: .singleMaltScotch, addedAt: day(3), fillFraction: 0.8),
        ]
    }

    private func ids(_ criteria: CollectionFilter.Criteria) -> [String] {
        CollectionFilter.apply(criteria, to: shelf).map(\.id)
    }

    // MARK: - Query

    /// The default is what you own now: finished bottles wait to be asked for.
    func testNoCriteriaReturnsTheShelfNewestFirst() {
        XCTAssertEqual(ids(.none), ["fr", "ecbp", "weller", "lag", "rye"])
    }

    func testEverythingIncludesFinished() {
        XCTAssertEqual(ids(.init(status: .any)), ["fr", "ecbp", "weller", "lag", "rye", "dead"])
    }

    func testEveryTokenMustPrefixSomething() {
        XCTAssertEqual(ids(.init(query: "eli bar")), ["ecbp"])
        XCTAssertEqual(ids(.init(query: "eli lag")), [])
    }

    func testDistilleryIsSearchable() {
        XCTAssertEqual(Set(ids(.init(query: "heaven"))), ["ecbp", "rye"])
    }

    func testBarrelNumberStoreAndLocationAreSearchable() {
        XCTAssertEqual(ids(.init(query: "42-3c")), ["fr"])
        XCTAssertEqual(ids(.init(query: "total wine")), ["fr"])
        XCTAssertEqual(Set(ids(.init(query: "cabinet"))), ["ecbp", "weller"])
    }

    func testPunctuationAndCaseDoNotMatter() {
        XCTAssertEqual(ids(.init(query: "W.L. WELLER")), ["weller"])
    }

    // MARK: - Status

    func testOpenExcludesFinished() {
        XCTAssertEqual(Set(ids(.init(status: .open))), ["ecbp", "weller"])
    }

    func testUnopened() {
        XCTAssertEqual(Set(ids(.init(status: .unopened))), ["fr", "rye", "lag"])
    }

    func testFinished() {
        XCTAssertEqual(ids(.init(status: .finished)), ["dead"])
    }

    // MARK: - Kinds

    func testKindsNarrowRatherThanWiden() {
        XCTAssertEqual(Set(ids(.init(kinds: [.barrelProof]))), ["ecbp", "fr"])
        XCTAssertEqual(ids(.init(kinds: [.barrelProof, .storePick])), ["fr"])
        XCTAssertEqual(ids(.init(kinds: [.barrelProof, .bottledInBond])), [])
    }

    /// Class and production are separate facts and separate chips.
    func testSingleBarrelIsProductionNotClass() {
        XCTAssertEqual(Set(ids(.init(status: .any, kinds: [.singleBarrel]))), ["fr", "dead"])
        XCTAssertEqual(Set(ids(.init(status: .any, kinds: [.bourbon]))), ["ecbp", "fr", "weller", "dead"])
        XCTAssertEqual(ids(.init(kinds: [.rye])), ["rye"])
        XCTAssertEqual(ids(.init(kinds: [.scotch])), ["lag"])
    }

    func testOnlyKindsSomethingMatchesAreOffered() {
        let offered = CollectionFilter.availableKinds(in: shelf)
        XCTAssertTrue(offered.contains(.storePick))
        XCTAssertTrue(offered.contains(.scotch))
        XCTAssertFalse(offered.contains(.wheatWhiskey))
        XCTAssertFalse(offered.contains(.notWhiskey))
    }

    // MARK: - Location

    func testLocationsMostUsedFirst() {
        XCTAssertEqual(CollectionFilter.locations(in: shelf), ["Cabinet", "Basement"])
    }

    func testLocationFilterIsCaseInsensitive() {
        XCTAssertEqual(Set(ids(.init(location: "cabinet"))), ["ecbp", "weller"])
    }

    // MARK: - Sorts

    func testNearlyGonePutsFinishedLast() {
        let order = ids(.init(status: .any, sort: .nearlyGone))
        XCTAssertEqual(order.prefix(3), ["weller", "ecbp", "lag"])
        XCTAssertEqual(order.last, "dead")
    }

    func testFullestFirst() {
        XCTAssertEqual(Set(ids(.init(sort: .fullest)).prefix(2)), ["fr", "rye"])
    }

    func testLastPouredPutsNeverPouredLast() {
        let order = ids(.init(status: .any, sort: .lastPoured))
        XCTAssertEqual(order.prefix(3), ["weller", "ecbp", "dead"])
        XCTAssertEqual(Set(order.suffix(3)), ["fr", "rye", "lag"])
    }

    func testRatingPutsUnratedLast() {
        let order = ids(.init(status: .any, sort: .rating))
        XCTAssertEqual(order.prefix(3), ["ecbp", "dead", "weller"])
    }

    func testNameSortIgnoresCase() {
        XCTAssertEqual(ids(.init(status: .any, sort: .name)).first, "dead")  // Eagle Rare
    }

    // MARK: - Criteria

    func testIsNarrowing() {
        XCTAssertFalse(CollectionFilter.Criteria.none.isNarrowing)
        XCTAssertFalse(CollectionFilter.Criteria(sort: .rating).isNarrowing)
        XCTAssertTrue(CollectionFilter.Criteria(query: " x").isNarrowing)
        XCTAssertTrue(CollectionFilter.Criteria(status: .open).isNarrowing)
        XCTAssertTrue(CollectionFilter.Criteria(status: .any).isNarrowing)
        XCTAssertTrue(CollectionFilter.Criteria(location: "Cabinet").isNarrowing)
    }

    // MARK: - Samples

    func testTheSamplesKindFindsSamplesAndSearchFindsWhoTheyCameFrom() {
        let rows = shelf + [
            CollectionFilter.Row(
                id: "s1", name: "Stagg Jr", distillery: "Buffalo Trace",
                extraSearchText: ["Mike"], classType: .kentuckyStraightBourbon,
                isOpen: true, isSample: true, addedAt: day(40), fillFraction: 1),
        ]
        XCTAssertEqual(CollectionFilter.apply(.init(kinds: [.sample]), to: rows).map(\.id), ["s1"])
        XCTAssertEqual(CollectionFilter.apply(.init(query: "mike"), to: rows).map(\.id), ["s1"])
        XCTAssertTrue(CollectionFilter.availableKinds(in: rows).contains(.sample))
        XCTAssertFalse(CollectionFilter.availableKinds(in: shelf).contains(.sample))
    }

    func testTheInfinityKindFindsInfinityBottles() {
        let rows = shelf + [
            CollectionFilter.Row(
                id: "inf", name: "The Ever Bottle", isOpen: true, isInfinity: true,
                addedAt: day(50), fillFraction: 0.3),
        ]
        XCTAssertEqual(CollectionFilter.apply(.init(kinds: [.infinity]), to: rows).map(\.id), ["inf"])
        XCTAssertFalse(CollectionFilter.availableKinds(in: shelf).contains(.infinity))
    }
    // MARK: - What has been open longest

    func testLongestOpenPutsTheOldestOpenBottleFirst() {
        // The question is about air in a bottle, not about drinking it: a
        // bottle open two years is worth looking at whether it is full or
        // nearly gone.
        let rows = [
            CollectionFilter.Row(
                id: "recent", name: "Recent", distillery: "A",
                isOpen: true, addedAt: day(1), openedAt: day(300), fillFraction: 0.2),
            CollectionFilter.Row(
                id: "ancient", name: "Ancient", distillery: "B",
                isOpen: true, addedAt: day(1), openedAt: day(10), fillFraction: 0.9),
            CollectionFilter.Row(
                id: "sealed", name: "Sealed", distillery: "C",
                addedAt: day(1), fillFraction: 1),
        ]
        var criteria = CollectionFilter.Criteria()
        criteria.status = .any
        criteria.sort = .longestOpen
        // Oldest opening first; never opened last, whatever its fill.
        XCTAssertEqual(
            CollectionFilter.apply(criteria, to: rows).map(\.id),
            ["ancient", "recent", "sealed"])
    }

    func testAFinishedBottleIsNotOpenAtAll() {
        let rows = [
            CollectionFilter.Row(
                id: "done", name: "Finished", distillery: "A",
                isOpen: true, isFinished: true,
                addedAt: day(2), openedAt: day(1), fillFraction: 0),
            CollectionFilter.Row(
                id: "open", name: "Open", distillery: "B",
                isOpen: true, addedAt: day(1), openedAt: day(50), fillFraction: 0.5),
        ]
        var criteria = CollectionFilter.Criteria()
        criteria.status = .any
        criteria.sort = .longestOpen
        // The finished one was opened first and is still last: it is not
        // oxidising, it is gone.
        XCTAssertEqual(
            CollectionFilter.apply(criteria, to: rows).map(\.id), ["open", "done"])
    }

    // MARK: - Finding a bottle by what it tasted of

    func testABottleIsFoundByAFlavourYouRecorded() {
        // The descriptors on your own tastings are carried in
        // extraSearchText, so the same prefix matching that finds a barrel
        // number finds "dried fig". This is the one search in the app that
        // answers from YOUR words rather than anybody's catalogue.
        let rows = [
            CollectionFilter.Row(
                id: "ec", name: "Elijah Craig Barrel Proof", distillery: "Heaven Hill",
                extraSearchText: ["Dried fig", "Charred oak"],
                classType: .kentuckyStraightBourbon, addedAt: day(1), fillFraction: 1),
            CollectionFilter.Row(
                id: "plain", name: "Something Else", distillery: "Nowhere",
                classType: .kentuckyStraightBourbon, addedAt: day(1), fillFraction: 1),
        ]
        var criteria = CollectionFilter.Criteria()
        criteria.status = .any
        criteria.query = "dried fig"
        XCTAssertEqual(CollectionFilter.apply(criteria, to: rows).map(\.id), ["ec"])

        // A prefix of one word is enough, the same rule the shop search uses.
        criteria.query = "fig"
        XCTAssertEqual(CollectionFilter.apply(criteria, to: rows).map(\.id), ["ec"])

        criteria.query = "peat"
        XCTAssertTrue(CollectionFilter.apply(criteria, to: rows).isEmpty)
    }

    // MARK: - Family chips

    func testFamilyChipsAppearOnlyForShelvesThatHaveThem() {
        // The chip list is curated for bourbon, and the catalogue is not any
        // more. These chips are cheap because availableKinds hides the ones
        // that would narrow nothing -- so a bourbon-only shelf must not grow
        // a Cider chip just because ciders exist in the world.
        let bourbonOnly = [row(classType: .kentuckyStraightBourbon)]
        let kinds = CollectionFilter.availableKinds(in: bourbonOnly)
        XCTAssertFalse(kinds.contains(.cider))
        XCTAssertFalse(kinds.contains(.seltzer))
        XCTAssertFalse(kinds.contains(.fortified))
        XCTAssertTrue(kinds.contains(.bourbon))

        let mixed = [
            row(classType: .kentuckyStraightBourbon),
            row(classType: .hardCider),
            row(classType: .port),
            row(classType: .sake),
        ]
        let wider = CollectionFilter.availableKinds(in: mixed)
        XCTAssertTrue(wider.contains(.cider))
        XCTAssertTrue(wider.contains(.fortified))
        XCTAssertTrue(wider.contains(.eastAsian))
    }

    func testAFamilyChipNarrowsToThatFamily() {
        let rows = [
            row(classType: .kentuckyStraightBourbon),
            row(classType: .hardCider),
            row(classType: .hardSeltzer),
        ]
        var criteria = CollectionFilter.Criteria()
        criteria.status = .any
        criteria.kinds = [.cider]
        let found = CollectionFilter.apply(criteria, to: rows)
        XCTAssertEqual(found.count, 1)
        XCTAssertEqual(found.first?.classType, .hardCider)
    }

}
