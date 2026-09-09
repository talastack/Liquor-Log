import Foundation

/// Moving JSON to and from the server, and nothing else.
///
/// A protocol rather than a concrete client so `SyncEngine` — where every rule
/// that can lose somebody's data lives — is testable with no network at all.
/// The transport is mechanical; the ordering, the cursor and the dirty flag are
/// where the damage happens.
public protocol SyncTransport: Sendable {

    /// Upsert rows, keyed on `id`. Bodies are complete JSON objects.
    ///
    /// Must throw on anything that is not 2xx. `SyncEngine` clears `dirty` only
    /// when this returns, so a transport that swallows an error silently
    /// discards the edit it failed to send.
    func upsert(table: String, rows: [Data]) async throws

    /// Rows with `server_updated_at` greater than `since`, ascending, capped at
    /// `limit`. Returns one JSON array.
    func fetch(table: String, since: Int64, limit: Int) async throws -> Data
}

/// Where the pull got to, per table.
///
/// `UserDefaults` rather than the database, deliberately. It is device state,
/// not user data — it must not sync — and putting a local-only table in the
/// schema would break the Postgres mirror that `check_schema_mirror.py`
/// enforces.
///
/// **Losing it is safe.** The next pull starts from zero and re-applies
/// everything, which is idempotent: every write is an upsert keyed on a
/// device-generated uuid. A slow first sync is a much better failure than a
/// cursor that cannot be rebuilt.
public protocol SyncCursorStore: Sendable {
    func cursor(for table: String) -> Int64
    func setCursor(_ value: Int64, for table: String)
}

public struct UserDefaultsCursorStore: SyncCursorStore {
    private let defaults: UserDefaults
    private let prefix: String

    public init(defaults: UserDefaults = .standard, prefix: String = "sync.cursor.") {
        self.defaults = defaults
        self.prefix = prefix
    }

    public func cursor(for table: String) -> Int64 {
        Int64(defaults.integer(forKey: prefix + table))
    }

    public func setCursor(_ value: Int64, for table: String) {
        defaults.set(Int(value), forKey: prefix + table)
    }
}

public enum SyncError: Error, Sendable, Equatable {
    /// Not 2xx. Carries the status so a caller can tell "sign in again" (401)
    /// from "try later" (5xx).
    case http(status: Int, body: String)
    case notAuthenticated
    case malformedResponse(table: String)
}
