import XCTest
import GRDB
import LiquorEngine
@testable import LiquorData

/// What a person contributes and reads back: reports kept locally and
/// pushed like any row, withdrawable as a whole; the views cached for the
/// session and silent when the network is not there.
final class CommunityTests: XCTestCase {

    private var db: AppDatabase!
    private var reports: ReportRepository!

    override func setUpWithError() throws {
        db = try AppDatabase.inMemory()
        reports = ReportRepository(db)
    }

    func testAPriceSightingIsARowToPush() throws {
        let report = try reports.recordPrice(productId: "weller-12", cents: 2999, region: "KY")
        XCTAssertEqual(report.region, "KY")
        XCTAssertTrue(report.dirty, "queued for push")
        XCTAssertEqual(try reports.priceReports().map(\.id), [report.id])
    }

    func testADripIsClampedToAFraction() throws {
        XCTAssertEqual(try reports.recordDrip(productId: "makers-mark", fraction: 1.4).fraction, 1)
        XCTAssertEqual(try reports.recordDrip(productId: "makers-mark", fraction: -0.1).fraction, 0)
    }

    /// Switching sharing off is a withdrawal: every report becomes a
    /// tombstone that syncs, and the views stop counting it.
    func testWithdrawingTombstonesEverything() throws {
        try reports.recordPrice(productId: "weller-12", cents: 2999, region: nil)
        try reports.recordDrip(productId: "makers-mark", fraction: 0.2)
        try reports.withdrawAll()
        XCTAssertTrue(try reports.priceReports().isEmpty)
        XCTAssertTrue(try reports.dripReports().isEmpty)
        let tombstones = try db.queue.read { db in
            try PriceReport.filter(Column("deleted_at") != nil).fetchCount(db)
                + DripReport.filter(Column("deleted_at") != nil).fetchCount(db)
        }
        XCTAssertEqual(tombstones, 2)
    }

    func testReportsAreStampedWhenAnAccountIsMade() throws {
        try reports.recordPrice(productId: "weller-12", cents: 2999, region: nil)
        let stamped = try AccountLinker(db).adopt(userId: "11111111-1111-1111-1111-111111111111")
        XCTAssertEqual(stamped, 1)
        XCTAssertEqual(try reports.priceReports().first?.userId, "11111111-1111-1111-1111-111111111111")
    }

    // MARK: - The hosted menu

    func testPublishingKeepsTheSlugOnRepublish() throws {
        let first = try reports.publishMenu(title: "Open tonight", body: "Weller 12")
        XCTAssertEqual(first.slug.count, 12)
        let second = try reports.publishMenu(title: "Open tonight", body: "Weller 12, Stagg")
        XCTAssertEqual(second.slug, first.slug, "a link already shared keeps working")
        XCTAssertEqual(second.id, first.id)
        XCTAssertEqual(try reports.currentMenu()?.body, "Weller 12, Stagg")
    }

    func testUnpublishingIsATombstone() throws {
        try reports.publishMenu(title: "Open tonight", body: "Weller 12")
        try reports.unpublishMenu()
        XCTAssertNil(try reports.currentMenu())
        let next = try reports.publishMenu(title: "Open tonight", body: "Stagg")
        XCTAssertEqual(next.slug.count, 12, "a fresh slug after unpublishing")
    }

    // MARK: - Reading the views

    private struct FakeCommunity: CommunityTransport {
        let body: String
        let fails: Bool
        func fetchPublic(view: String, query: [URLQueryItem]) async throws -> Data {
            if fails { throw SyncError.http(status: 500, body: "") }
            return Data(body.utf8)
        }
    }

    func testPricesComeBackAsAggregatesAndAreCached() async throws {
        let transport = FakeCommunity(body: """
        [{"catalog_product_id":"weller-12","region":"KY","is_all":false,"reports":5,"median_cents":2999,
          "lowest_cents":2499,"highest_cents":3499,"oldest_seen_at":1700000000000,"latest_seen_at":1750000000000}]
        """, fails: false)
        let service = CommunityService(transport: transport)
        let rows = await service.prices(for: "weller-12")
        XCTAssertEqual(rows.first?.reports, 5)
        XCTAssertEqual(CommunityPrice.best(from: rows, preferring: "KY")?.cents, 2999)
    }

    func testANetworkFailureIsSilence() async {
        let service = CommunityService(transport: FakeCommunity(body: "", fails: true))
        let rows = await service.prices(for: "weller-12")
        XCTAssertTrue(rows.isEmpty)
        let drip = await service.drips(for: "makers-mark")
        XCTAssertNil(drip)
    }

    func testDripsDecodeToAStanding() async {
        let service = CommunityService(transport: FakeCommunity(body: """
        [{"catalog_product_id":"makers-mark","reports":12,"p25":0.1,"p50":0.15,"p75":0.2}]
        """, fails: false))
        let standing = await service.drips(for: "makers-mark")
        XCTAssertEqual(standing?.text(for: 0.3), "Longer than three quarters of the 12 drips people have measured.")
    }
}
