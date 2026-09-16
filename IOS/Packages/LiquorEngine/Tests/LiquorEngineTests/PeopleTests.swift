import XCTest
@testable import LiquorEngine

/// The swap ledger, read from samples and pours: one person per name
/// however it was spelled, what went each way, whose turn it is, and
/// whether their samples rate well with you.
final class PeopleTests: XCTestCase {

    private let now = Date(timeIntervalSince1970: 1_760_000_000)
    private func daysAgo(_ n: Int) -> Date { now.addingTimeInterval(-Double(n) * 86_400) }

    func testOnePersonPerNameWithTheNewestSpellingAndNewestFirst() {
        let people = People.ledger(
            received: [
                (from: "mike", bottle: "Stagg Jr", milliliters: 50, how: "A swap", at: daysAgo(40), rating: 8),
                (from: "Mike ", bottle: "Weller 12", milliliters: 30, how: nil, at: daysAgo(3), rating: 9),
                (from: "Sarah", bottle: "ECBP", milliliters: 60, how: "From a friend", at: daysAgo(90), rating: nil),
            ],
            given: [
                (to: "MIKE", bottle: "Blanton's", milliliters: 44, at: daysAgo(10)),
                (to: "  ", bottle: "nobody", milliliters: 44, at: daysAgo(1)),
            ])

        XCTAssertEqual(people.map(\.name), ["Mike", "Sarah"], "most recent exchange first, blank names dropped")
        let mike = people[0]
        XCTAssertEqual(mike.received.map(\.bottle), ["Weller 12", "Stagg Jr"])
        XCTAssertEqual(mike.given.map(\.bottle), ["Blanton's"])
        XCTAssertEqual(mike.receivedMilliliters, 80)
        XCTAssertEqual(mike.givenMilliliters, 44)
        XCTAssertEqual(mike.lastAt, daysAgo(3))
        XCTAssertEqual(People.line(mike, now: now), "2 samples from them · 1 pour to them · last 3 days ago")
    }

    func testBalanceSaysWhoseTurnItIsInPlainWords() {
        let people = People.ledger(
            received: [(from: "Mike", bottle: "a", milliliters: 100, how: nil, at: daysAgo(1), rating: nil)],
            given: [(to: "Mike", bottle: "b", milliliters: 40, at: daysAgo(2)),
                    (to: "Sarah", bottle: "c", milliliters: 44, at: daysAgo(2)),
                    (to: "Joe", bottle: "d", milliliters: 44, at: daysAgo(2))])
        let mike = people.first { $0.name == "Mike" }!
        let sarah = people.first { $0.name == "Sarah" }!
        XCTAssertEqual(People.balance(mike), "They have sent 60 ml more than you have")
        XCTAssertEqual(People.balance(mike, ounces: true), "They have sent 2.0 oz more than you have")
        XCTAssertEqual(People.balance(sarah), "You have sent 44 ml more than they have")

        let even = People.ledger(
            received: [(from: "Joe", bottle: "a", milliliters: 50, how: nil, at: daysAgo(1), rating: nil)],
            given: [(to: "Joe", bottle: "b", milliliters: 44, at: daysAgo(2))])
        XCTAssertEqual(People.balance(even[0]), "About even")
    }

    func testTasteNeedsTwoRatedSamples() {
        let one = People.ledger(
            received: [(from: "Mike", bottle: "a", milliliters: 50, how: nil, at: daysAgo(1), rating: 9)],
            given: [])
        XCTAssertNil(People.taste(one[0]))

        let two = People.ledger(
            received: [
                (from: "Mike", bottle: "a", milliliters: 50, how: nil, at: daysAgo(1), rating: 9),
                (from: "Mike", bottle: "b", milliliters: 50, how: nil, at: daysAgo(2), rating: 8),
                (from: "Mike", bottle: "c", milliliters: 50, how: nil, at: daysAgo(3), rating: nil),
            ],
            given: [])
        XCTAssertEqual(People.taste(two[0]), "Their samples average 8.5 with you, over 2 rated.")
    }

    func testNobodyIsAnEmptyLedger() {
        XCTAssertTrue(People.ledger(received: [], given: []).isEmpty)
    }
}
