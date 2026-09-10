import XCTest
@testable import LiquorEngine

/// Rarity from measured allocation, never from opinion. These pin the
/// restraint: three honest states, and no fabricated tier below "allocated".
final class RarityTests: XCTestCase {

    /// The example the research found: 640 bottles, 44,696 entries.
    private var stagg: Rarity.Allocation {
        Rarity.Allocation(bottles: 640, entries: 44_696, source: "Virginia ABC", year: 2026)
    }

    func testMeasuredDemandBecomesARatio() {
        XCTAssertEqual(stagg.demandRatio ?? 0, 69.8, accuracy: 0.05)
        if case .contested(let ratio) = Rarity.assess(stagg).verdict {
            XCTAssertEqual(ratio, 69.8, accuracy: 0.05)
        } else {
            XCTFail("a lottery with both numbers is contested")
        }
    }

    func testSeventyToOneIsExtremelyContested() {
        XCTAssertEqual(Rarity.assess(stagg).verdict.headline, "Extremely contested")
    }

    func testTenToOneIsContested() {
        let allocation = Rarity.Allocation(bottles: 100, entries: 1_200, source: "Virginia ABC")
        XCTAssertEqual(Rarity.assess(allocation).verdict.headline, "Contested")
    }

    func testAQuietLotteryIsJustAllocatedByLottery() {
        let allocation = Rarity.Allocation(bottles: 500, entries: 800, source: "Virginia ABC")
        XCTAssertEqual(Rarity.assess(allocation).verdict.headline, "Allocated, by lottery")
    }

    /// Pennsylvania publishes counts with no lottery. Supply without demand
    /// gets a different verdict rather than a guessed ratio.
    func testACountWithoutEntriesIsAllocatedNotContested() {
        let allocation = Rarity.Allocation(bottles: 2_016, source: "Pennsylvania PLCB")
        let result = Rarity.assess(allocation)
        XCTAssertEqual(result.verdict, .allocated(bottles: 2_016))
        XCTAssertNil(allocation.demandRatio)
    }

    /// The most important test in the file. No record is NOT "common": every
    /// free source skews to the scarce end, so there is no basis for a tier
    /// below allocated, and inventing one is exactly the incumbent's mistake.
    func testNoRecordIsNotAllocatedAndNeverCommon() {
        let result = Rarity.assess(nil)
        XCTAssertEqual(result.verdict, .notAllocated)
        XCTAssertFalse(result.verdict.headline.lowercased().contains("common"))
        XCTAssertTrue(result.summary.contains("not the same as common"))
    }

    // MARK: - What it says

    func testTheSummaryCarriesBothNumbers() {
        let summary = Rarity.assess(stagg).summary
        XCTAssertTrue(summary.contains("44,696"))
        XCTAssertTrue(summary.contains("640"))
        XCTAssertTrue(summary.contains("70 people"))
    }

    /// Two states' allocations do not add up to a national picture.
    func testTheCaveatNamesTheStateAndDisclaimsTheNation() {
        let caveat = Rarity.assess(stagg).caveat
        XCTAssertTrue(caveat.contains("Virginia ABC"))
        XCTAssertTrue(caveat.contains("2026"))
        XCTAssertTrue(caveat.contains("not a national figure"))
    }

    func testAZeroBottleAllocationDoesNotDivide() {
        let allocation = Rarity.Allocation(bottles: 0, entries: 100, source: "x")
        XCTAssertNil(allocation.demandRatio)
        XCTAssertEqual(Rarity.assess(allocation).verdict, .allocated(bottles: 0))
    }
}
