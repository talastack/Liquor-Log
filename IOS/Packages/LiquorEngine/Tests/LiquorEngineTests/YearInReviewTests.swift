import XCTest
@testable import LiquorEngine

/// A year in sentences, from the record: bottles, tastings, words, people
/// and stores. Nothing about pours or bottles emptied.
final class YearInReviewTests: XCTestCase {

    private var calendar: Calendar {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(identifier: "UTC")!
        return c
    }

    private func day(_ year: Int, _ month: Int, _ day: Int) -> Date {
        calendar.date(from: DateComponents(year: year, month: month, day: day, hour: 12))!
    }

    private var facts: YearInReview.Facts {
        YearInReview.Facts(
            added: [
                (name: "Weller 12", classLabel: "Kentucky Straight Bourbon", distillery: "Buffalo Trace", cents: 3999, at: day(2026, 1, 3)),
                (name: "Stagg", classLabel: "Kentucky Straight Bourbon", distillery: "Buffalo Trace", cents: nil, at: day(2026, 4, 9)),
                (name: "Four Roses Small Batch", classLabel: "Kentucky Straight Bourbon", distillery: "Four Roses", cents: 3499, at: day(2026, 6, 1)),
                (name: "Rittenhouse", classLabel: "Straight Rye", distillery: "Heaven Hill", cents: 2799, at: day(2026, 8, 20)),
                (name: "Last year's bottle", classLabel: nil, distillery: "Old Forester", cents: 5000, at: day(2025, 12, 30)),
            ],
            opened: [day(2026, 1, 5), day(2026, 7, 4), day(2025, 3, 3)],
            tastings: [
                (name: "Weller 12", rating: 8, at: day(2026, 1, 6), words: ["caramel", "oak", "caramel"]),
                (name: "Stagg", rating: 9, at: day(2026, 4, 10), words: ["caramel", "cherry"]),
                (name: "Rittenhouse", rating: nil, at: day(2026, 8, 21), words: ["rye-spice"]),
            ],
            samples: [(from: "mike", at: day(2026, 2, 2)), (from: "Mike", at: day(2026, 3, 3)), (from: "Sarah", at: day(2026, 5, 5))],
            sightings: [(store: "Total Wine", at: day(2026, 2, 1)), (store: "Total Wine", at: day(2026, 3, 1)), (store: "Liquor Barn", at: day(2026, 3, 2))],
            lotteries: [(won: false, at: day(2026, 3, 1)), (won: true, at: day(2026, 9, 1)), (won: nil, at: day(2026, 9, 2))])
    }

    func testTheYearInSentences() {
        let review = YearInReview.review(facts, year: 2026, words: { $0 == "caramel" ? "Caramel" : $0 }, calendar: calendar)!
        XCTAssertEqual(review.lines, [
            "4 bottles added, from 3 distilleries. Buffalo Trace most, 2 times.",
            "Mostly kentucky straight bourbon: 3 of them.",
            "First of the year: Weller 12, 3 January.",
            "3 tastings written. Highest: Stagg, 9/10.",
            "The word you reached for most: Caramel, 2 times.",
            "3 samples from Sarah, Mike.",
            "3 sightings at 2 stores; Total Wine most.",
            "3 lotteries entered, 1 won.",
        ])
        XCTAssertEqual(review.moneyLine, "$102.97 across the 3 with a price.")
        XCTAssertEqual(review.bottlesAdded, 4, "last year's bottle is last year's")
        XCTAssertEqual(review.opened, 2, "counted, and deliberately not among the sentences")
        XCTAssertEqual(review.wordOfTheYear, YearInReview.Count(name: "Caramel", count: 2), "once per tasting, not three")
        XCTAssertEqual(review.sampleSenders, ["Sarah", "Mike"], "newest first, one Mike")
    }

    func testAYearWithNothingIsNil() {
        XCTAssertNil(YearInReview.review(facts, year: 2019, calendar: calendar))
        XCTAssertEqual(YearInReview.years(facts, calendar: calendar), [2026, 2025])
    }

    func testMoneyCoversEveryBottleWhenEveryBottleHasAPrice() {
        let f = YearInReview.Facts(added: [
            (name: "A", classLabel: nil, distillery: nil, cents: 1000, at: day(2026, 1, 1)),
            (name: "B", classLabel: nil, distillery: nil, cents: 2000, at: day(2026, 1, 2)),
        ])
        let review = YearInReview.review(f, year: 2026, calendar: calendar)!
        XCTAssertEqual(review.moneyLine, "$30.00 across them.")
        XCTAssertEqual(review.lines, ["2 bottles added.", "First of the year: A, 1 January."])
    }
}
