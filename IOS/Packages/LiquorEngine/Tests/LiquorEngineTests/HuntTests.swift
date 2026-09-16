import XCTest
@testable import LiquorEngine

/// The hunt log read back: stores by what was found there, the wishlist
/// against recent sightings, lotteries as a count. Only from what was
/// logged.
final class HuntTests: XCTestCase {

    private let now = Date(timeIntervalSince1970: 1_760_000_000)

    private func daysAgo(_ n: Int) -> Date { now.addingTimeInterval(-Double(n) * 86_400) }

    private func seen(_ id: String, _ product: String?, at store: String, days: Int,
                      cents: Int? = nil, count: Int? = nil, bought: String? = nil) -> Hunt.Sighting {
        Hunt.Sighting(id: id, productId: product, name: product ?? id, store: store,
                      kind: .seen, cents: cents, count: count, at: daysAgo(days), boughtBottleId: bought)
    }

    private func entered(_ id: String, _ product: String, at runner: String, days: Int,
                         outcome: Hunt.Outcome? = nil) -> Hunt.Sighting {
        Hunt.Sighting(id: id, productId: product, name: product, store: runner,
                      kind: .entered, outcome: outcome, at: daysAgo(days))
    }

    func testStoresRankByWhatWasFoundThereAndMergeSpellings() {
        let summary = Hunt.summarise([
            seen("a", "blantons", at: "Total Wine", days: 30),
            seen("b", "weller-sr", at: "total wine ", days: 2),
            seen("c", "blantons", at: "Total Wine", days: 10),
            seen("d", "ecbp", at: "Liquor Barn", days: 1),
        ], wishlist: ["blantons"])

        XCTAssertEqual(summary.seen, 4)
        XCTAssertEqual(summary.stores.map(\.name), ["total wine", "Liquor Barn"], "most recent spelling, most sightings first")
        XCTAssertEqual(summary.stores[0].sightings, 3)
        XCTAssertEqual(summary.stores[0].products, 2)
        XCTAssertEqual(summary.stores[0].wishlistHits, 2)
        XCTAssertEqual(summary.headline, "4 sightings at 2 stores")
    }

    func testLotteriesCountEnteredWonLostAndPending() {
        let summary = Hunt.summarise([
            entered("a", "stagg", at: "Virginia ABC", days: 90, outcome: .lost),
            entered("b", "stagg", at: "Virginia ABC", days: 40, outcome: .won),
            entered("c", "weller-12", at: "Virginia ABC", days: 5),
            entered("d", "blantons-gold", at: "Ohio", days: 2),
        ])
        XCTAssertEqual(summary.lotteries.entered, 4)
        XCTAssertEqual(summary.lotteries.won, 1)
        XCTAssertEqual(summary.lotteries.lost, 1)
        XCTAssertEqual(summary.lotteries.pending, 2)
        XCTAssertEqual(summary.lotteries.line, "4 entered · 1 won · 1 lost · 2 pending")
        XCTAssertEqual(summary.headline, "4 lotteries entered, 1 won")
        XCTAssertTrue(summary.stores.isEmpty, "a lottery runner is not a store you found something at")
    }

    func testAnEmptyLogSaysNothing() {
        let summary = Hunt.summarise([])
        XCTAssertNil(summary.headline)
        XCTAssertNil(summary.lotteries.line)
        XCTAssertEqual(summary, .empty)
    }

    func testLatestSightingOfAProductIsTheNewestShelfOne() {
        let log = [
            seen("a", "blantons", at: "Total Wine", days: 30, cents: 7499),
            seen("b", "blantons", at: "Liquor Barn", days: 3, cents: 6999, count: 2),
            entered("c", "blantons", at: "Virginia ABC", days: 1),
        ]
        let latest = Hunt.latest(productId: "blantons", in: log)
        XCTAssertEqual(latest?.id, "b")
        XCTAssertEqual(Hunt.line(latest!, now: now), "At Liquor Barn 3 days ago · $69.99 · 2 on the shelf")
        XCTAssertNil(Hunt.latest(productId: "stagg", in: log))
    }

    func testOnYourListIsRecentWishlistSightingsNewestPerProductNotYetBought() {
        let log = [
            seen("a", "blantons", at: "Total Wine", days: 30),
            seen("b", "blantons", at: "Liquor Barn", days: 3),
            seen("c", "weller-12", at: "Total Wine", days: 90),
            seen("d", "ecbp", at: "Total Wine", days: 1),
            seen("e", "stagg", at: "Total Wine", days: 2, bought: "bottle-1"),
        ]
        let rows = Hunt.onYourList(log, wishlist: ["blantons", "weller-12", "stagg"], within: 60, now: now)
        XCTAssertEqual(rows.map(\.id), ["b"], "one per product, inside the window, not already bought")
    }

    func testLinesSayWhenAndWhatInPlainWords() {
        XCTAssertEqual(Hunt.line(seen("a", nil, at: "Total Wine", days: 0, cents: 7499), now: now),
                       "At Total Wine today · $74.99")
        XCTAssertEqual(Hunt.line(seen("a", nil, at: "Total Wine", days: 1, count: 0), now: now),
                       "At Total Wine yesterday · sold out")
        XCTAssertEqual(Hunt.line(seen("a", nil, at: "Total Wine", days: 21, bought: "b"), now: now),
                       "At Total Wine 3 weeks ago · bought")
        XCTAssertEqual(Hunt.line(entered("a", "stagg", at: "Virginia ABC", days: 45), now: now),
                       "Virginia ABC, 6 weeks ago · pending")
        XCTAssertEqual(Hunt.line(entered("a", "stagg", at: "Virginia ABC", days: 400, outcome: .won), now: now),
                       "Virginia ABC, a year ago · won")
    }

    func testAgoRoundsTheWayPeopleSayIt() {
        XCTAssertEqual(Hunt.ago(0), "today")
        XCTAssertEqual(Hunt.ago(13), "13 days ago")
        XCTAssertEqual(Hunt.ago(14), "2 weeks ago")
        XCTAssertEqual(Hunt.ago(59), "8 weeks ago")
        XCTAssertEqual(Hunt.ago(60), "2 months ago")
        XCTAssertEqual(Hunt.ago(364), "12 months ago")
        XCTAssertEqual(Hunt.ago(800), "2 years ago")
    }
}
