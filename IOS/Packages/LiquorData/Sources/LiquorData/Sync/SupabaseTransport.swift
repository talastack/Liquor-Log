import Foundation

/// PostgREST over `URLSession`.
///
/// **No SDK.** The Supabase Swift package would be the app's second dependency
/// and its first networking one, to save perhaps eighty lines of URL building.
/// The REST surface this needs is two verbs, and keeping it here means the sync
/// rules and the wire format sit in one place where they can be read together.
///
/// Row-level security does the authorisation. Every request carries the user's
/// JWT, Postgres scopes each table to `auth.uid() = user_id`, and no filter
/// here is load-bearing for privacy — a bug in this file cannot leak somebody
/// else's collection.
public struct SupabaseTransport: SyncTransport {

    private let baseURL: URL
    private let anonKey: String
    private let accessToken: @Sendable () async -> String?
    private let session: URLSession

    /// - Parameter accessToken: read fresh on every request, not captured once.
    ///   A JWT expires while an app sits in a pocket, and a token captured at
    ///   construction produces a 401 on the first sync after lunch.
    public init(
        baseURL: URL,
        anonKey: String,
        accessToken: @escaping @Sendable () async -> String?,
        session: URLSession = .shared
    ) {
        self.baseURL = baseURL
        self.anonKey = anonKey
        self.accessToken = accessToken
        self.session = session
    }

    // MARK: - Push

    public func upsert(table: String, rows: [Data]) async throws {
        guard let token = await accessToken() else { throw SyncError.notAuthenticated }

        // One array body, not one request per row: a shelf walk can dirty two
        // hundred bottles at once and that must not be two hundred round trips.
        let array = try rows.map { try JSONSerialization.jsonObject(with: $0) }
        var request = URLRequest(url: endpoint(table))
        request.httpMethod = "POST"
        request.httpBody = try JSONSerialization.data(withJSONObject: array)
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        // merge-duplicates makes this an upsert on the primary key. Without it
        // PostgREST inserts, and every re-push of an edited row is a 409.
        request.setValue(
            "resolution=merge-duplicates,return=minimal",
            forHTTPHeaderField: "Prefer")
        sign(&request, token: token)

        try await send(request)
    }

    // MARK: - Pull

    public func fetch(table: String, since: Int64, limit: Int) async throws -> Data {
        guard let token = await accessToken() else { throw SyncError.notAuthenticated }

        var components = URLComponents(
            url: endpoint(table), resolvingAgainstBaseURL: false)!
        components.queryItems = [
            URLQueryItem(name: "select", value: "*"),
            URLQueryItem(name: "server_updated_at", value: "gt.\(since)"),
            // Ascending, so a partial page still leaves the cursor somewhere
            // that can be resumed from without a gap.
            URLQueryItem(name: "order", value: "server_updated_at.asc"),
            URLQueryItem(name: "limit", value: String(limit)),
        ]

        var request = URLRequest(url: components.url!)
        request.httpMethod = "GET"
        sign(&request, token: token)

        return try await send(request)
    }

    // MARK: - Plumbing

    private func endpoint(_ table: String) -> URL {
        baseURL.appendingPathComponent("rest/v1").appendingPathComponent(table)
    }

    private func sign(_ request: inout URLRequest, token: String) {
        request.setValue(anonKey, forHTTPHeaderField: "apikey")
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
    }

    @discardableResult
    private func send(_ request: URLRequest) async throws -> Data {
        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw SyncError.malformedResponse(table: request.url?.lastPathComponent ?? "?")
        }
        guard (200..<300).contains(http.statusCode) else {
            // The body carries PostgREST's actual complaint -- which constraint,
            // which column. Dropping it leaves "sync failed" and nothing to act
            // on.
            throw SyncError.http(
                status: http.statusCode,
                body: String(data: data, encoding: .utf8) ?? "")
        }
        return data
    }
}
