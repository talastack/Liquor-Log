import Foundation
import GRDB
import LiquorEngine

/// Reading everyone's reports back, reduced. The server holds individual
/// sightings under row-level security; the two views expose counts and
/// medians and never a user id, and the anon key can read them.
public protocol CommunityTransport: Sendable {
    /// GET a public view with PostgREST query items. Returns the JSON array.
    func fetchPublic(view: String, query: [URLQueryItem]) async throws -> Data
}

/// The community figures the app shows: a shelf price others saw, where a
/// wax drip falls. Cached for the session so an aisle check does not
/// hit the network on every keystroke; nil whenever the network or the
/// project is not there, which is a normal state and never an error.
public actor CommunityService {
    private let transport: CommunityTransport
    private var prices: [String: (rows: [CommunityPrice.Aggregate], at: Date)] = [:]
    private var drips: [String: (row: WaxDrip.CommunityStanding?, at: Date)] = [:]
    private let ttl: TimeInterval = 3600

    public init(transport: CommunityTransport) {
        self.transport = transport
    }

    public func prices(for productId: String, now: Date = Date()) async -> [CommunityPrice.Aggregate] {
        if let cached = prices[productId], now.timeIntervalSince(cached.at) < ttl { return cached.rows }
        do {
            let data = try await transport.fetchPublic(
                view: "community_prices",
                query: [URLQueryItem(name: "catalog_product_id", value: "eq.\(productId)"),
                        URLQueryItem(name: "select", value: "*")])
            let rows = try JSONDecoder().decode([CommunityPrice.Aggregate].self, from: data)
            prices[productId] = (rows, now)
            return rows
        } catch {
            return []
        }
    }

    public func drips(for productId: String, now: Date = Date()) async -> WaxDrip.CommunityStanding? {
        if let cached = drips[productId], now.timeIntervalSince(cached.at) < ttl { return cached.row }
        do {
            let data = try await transport.fetchPublic(
                view: "community_drips",
                query: [URLQueryItem(name: "catalog_product_id", value: "eq.\(productId)"),
                        URLQueryItem(name: "select", value: "*")])
            let row = try JSONDecoder().decode([WaxDrip.CommunityStanding].self, from: data).first
            drips[productId] = (row, now)
            return row
        } catch {
            return nil
        }
    }
}

/// What this person contributes: their own sightings and measurements,
/// kept locally, pushed by sync like any row, and withdrawable as a
/// whole. Nothing is recorded unless sharing is switched on; switching it
/// off withdraws everything already sent.
public struct ReportRepository: Sendable {
    private let db: AppDatabase

    public init(_ db: AppDatabase) {
        self.db = db
    }

    @discardableResult
    public func recordPrice(productId: String, cents: Int, region: String?) throws -> PriceReport {
        var report = PriceReport(catalogProductId: productId, cents: cents, region: region)
        try db.queue.write { db in try report.saveLocal(db) }
        return report
    }

    @discardableResult
    public func recordDrip(productId: String, fraction: Double) throws -> DripReport {
        var report = DripReport(catalogProductId: productId, fraction: min(1, max(0, fraction)))
        try db.queue.write { db in try report.saveLocal(db) }
        return report
    }

    public func priceReports() throws -> [PriceReport] {
        try db.queue.read { db in try PriceReport.live().order(Column("seen_at").desc).fetchAll(db) }
    }

    public func dripReports() throws -> [DripReport] {
        try db.queue.read { db in try DripReport.live().order(Column("created_at").desc).fetchAll(db) }
    }

    /// Tombstones every report. They sync as deletions and the server's
    /// views stop counting them.
    public func withdrawAll() throws {
        try db.queue.write { db in
            for var report in try PriceReport.live().fetchAll(db) {
                report.softDelete()
                try report.save(db)
            }
            for var report in try DripReport.live().fetchAll(db) {
                report.softDelete()
                try report.save(db)
            }
        }
    }

    // MARK: - The hosted menu

    public func currentMenu() throws -> HostedMenu? {
        try db.queue.read { db in try HostedMenu.live().fetchOne(db) }
    }

    /// Publishes, or republishes under the same slug so a link that was
    /// already shared keeps working.
    @discardableResult
    public func publishMenu(title: String, body: String) throws -> HostedMenu {
        try db.queue.write { db in
            if var existing = try HostedMenu.live().fetchOne(db) {
                existing.title = title
                existing.body = body
                existing.publishedAt = HostedMenu.nowMilliseconds()
                try existing.saveLocal(db)
                return existing
            }
            var menu = HostedMenu(slug: HostedMenu.makeSlug(), title: title, body: body)
            try menu.saveLocal(db)
            return menu
        }
    }

    public func unpublishMenu() throws {
        try db.queue.write { db in
            for var menu in try HostedMenu.live().fetchAll(db) {
                menu.softDelete()
                try menu.save(db)
            }
        }
    }
}
