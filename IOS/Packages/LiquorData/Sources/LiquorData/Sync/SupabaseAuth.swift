import Foundation

/// Supabase GoTrue: sign up, sign in, refresh, sign out.
///
/// **The app is fully usable with no account.** Everything works offline and a
/// local-only collection is not a degraded state — it is the normal one until
/// somebody wants their bottles on a second device. Nothing here is on the path
/// of any screen.
///
/// Written against the REST endpoints rather than the Supabase SDK, for the
/// same reason as `SupabaseTransport`: the surface is four requests, and a
/// dependency that owns token refresh is a dependency that owns whether
/// somebody can reach their own collection.
public actor SupabaseAuth {

    public struct Session: Sendable, Equatable {
        public let accessToken: String
        public let refreshToken: String
        public let userId: String
        /// Absolute, not a duration. A duration decided at login is wrong by
        /// however long the phone spent in a pocket.
        public let expiresAt: Date

        /// Refreshed a minute early. A token that expires between the check and
        /// the request produces a 401 that looks like a sign-in problem.
        var isFresh: Bool { expiresAt.timeIntervalSinceNow > 60 }
    }

    private let host: String
    private let anonKey: String
    private let session: URLSession
    private let store: CredentialStore

    private var current: Session?

    public init(
        host: String,
        anonKey: String,
        store: CredentialStore,
        session: URLSession = .shared
    ) {
        self.host = host
        self.anonKey = anonKey
        self.store = store
        self.session = session
    }

    public var isSignedIn: Bool { current != nil || store.refreshToken != nil }
    public var userId: String? { current?.userId }

    // MARK: - The token everything else asks for

    /// A usable access token, refreshing if needed. Nil when signed out.
    ///
    /// `SupabaseTransport` calls this on **every** request rather than
    /// capturing a token once, because a JWT expires while an app sits in a
    /// pocket and a captured one produces a 401 after lunch.
    public func accessToken() async -> String? {
        if let current, current.isFresh { return current.accessToken }
        if let refreshed = try? await refresh() { return refreshed.accessToken }
        return nil
    }

    // MARK: - Account

    @discardableResult
    public func signUp(email: String, password: String) async throws -> Session {
        let body = ["email": email, "password": password]
        // Sign-up returns a session only when email confirmation is off. With
        // it on the caller gets a "check your email" state, which is why this
        // throws rather than inventing a session.
        return try await authenticate(path: "signup", query: [], body: body)
    }

    @discardableResult
    public func signIn(email: String, password: String) async throws -> Session {
        try await authenticate(
            path: "token",
            query: [URLQueryItem(name: "grant_type", value: "password")],
            body: ["email": email, "password": password])
    }

    @discardableResult
    public func refresh() async throws -> Session {
        guard let token = store.refreshToken else { throw SyncError.notAuthenticated }
        do {
            return try await authenticate(
                path: "token",
                query: [URLQueryItem(name: "grant_type", value: "refresh_token")],
                body: ["refresh_token": token])
        } catch SyncError.http(let status, _) where status == 400 || status == 401 {
            // The refresh token is dead: revoked, expired, or the account is
            // gone. Clearing it is what stops every later call retrying a
            // credential that will never work again.
            //
            // LOCAL DATA IS UNTOUCHED. Being signed out is not a reason to lose
            // somebody's collection, and they may sign back in on this device.
            signOutLocally()
            throw SyncError.notAuthenticated
        }
    }

    /// Forgets the credentials on this device. **Never deletes local data.**
    public func signOut() async {
        if let token = current?.accessToken {
            var request = URLRequest(url: endpoint("logout", query: []))
            request.httpMethod = "POST"
            request.setValue(anonKey, forHTTPHeaderField: "apikey")
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
            // Best effort. A failed revoke must not strand somebody signed in
            // on a device they are trying to sign out of.
            _ = try? await session.data(for: request)
        }
        signOutLocally()
    }

    private func signOutLocally() {
        current = nil
        store.refreshToken = nil
    }

    // MARK: - Plumbing

    private func endpoint(_ path: String, query: [URLQueryItem]) -> URL {
        var components = URLComponents()
        components.scheme = "https"
        components.host = host
        components.path = "/auth/v1/" + path
        if !query.isEmpty { components.queryItems = query }
        return components.url!
    }

    private func authenticate(
        path: String, query: [URLQueryItem], body: [String: String]
    ) async throws -> Session {
        var request = URLRequest(url: endpoint(path, query: query))
        request.httpMethod = "POST"
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(anonKey, forHTTPHeaderField: "apikey")

        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw SyncError.malformedResponse(table: "auth")
        }
        guard (200..<300).contains(http.statusCode) else {
            throw SyncError.http(
                status: http.statusCode,
                body: String(data: data, encoding: .utf8) ?? "")
        }

        let parsed = try Self.parse(data)
        current = parsed
        store.refreshToken = parsed.refreshToken
        return parsed
    }

    /// Reads GoTrue's token response.
    static func parse(_ data: Data, now: Date = Date()) throws -> Session {
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let access = json["access_token"] as? String,
              let refresh = json["refresh_token"] as? String
        else { throw SyncError.malformedResponse(table: "auth") }

        // The user id has to come from the response, never from anything the
        // client decides. It is the value RLS compares against, so guessing it
        // wrong writes rows their owner can never read back.
        let user = json["user"] as? [String: Any]
        guard let userId = user?["id"] as? String else {
            throw SyncError.malformedResponse(table: "auth")
        }

        let seconds = (json["expires_in"] as? Double)
            ?? (json["expires_in"] as? NSNumber)?.doubleValue
            ?? 3600
        return Session(
            accessToken: access,
            refreshToken: refresh,
            userId: userId,
            expiresAt: now.addingTimeInterval(seconds))
    }
}

// MARK: - Credential storage

/// Where the refresh token lives.
///
/// A protocol so tests can use memory, and so the Keychain implementation is
/// the only thing that has to be right about protection classes.
public protocol CredentialStore: Sendable {
    var refreshToken: String? { get nonmutating set }
}

/// The Keychain, not `UserDefaults`.
///
/// A refresh token is a credential that can mint access tokens indefinitely.
/// `UserDefaults` is a plist in the app container: readable from a backup,
/// readable on a jailbroken device, and included in an unencrypted iTunes
/// backup by default.
public struct KeychainCredentialStore: CredentialStore {
    private let service: String
    private let account: String

    public init(service: String = "com.talastack.liquorlog.supabase",
                account: String = "refresh_token") {
        self.service = service
        self.account = account
    }

    public var refreshToken: String? {
        get {
            var query = baseQuery
            query[kSecReturnData as String] = true
            query[kSecMatchLimit as String] = kSecMatchLimitOne

            var item: CFTypeRef?
            guard SecItemCopyMatching(query as CFDictionary, &item) == errSecSuccess,
                  let data = item as? Data
            else { return nil }
            return String(data: data, encoding: .utf8)
        }
        nonmutating set {
            // Delete-then-add rather than update: SecItemUpdate fails when the
            // item does not exist, so the add path would need the same branch
            // anyway and this keeps it to one.
            SecItemDelete(baseQuery as CFDictionary)
            guard let value = newValue?.data(using: .utf8) else { return }

            var query = baseQuery
            query[kSecValueData as String] = value
            // AfterFirstUnlock, not WhenUnlocked: a background sync must be
            // able to read this with the phone locked in a pocket. Not
            // ThisDeviceOnly, so restoring to a new phone keeps you signed in.
            query[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlock
            SecItemAdd(query as CFDictionary, nil)
        }
    }

    private var baseQuery: [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
        ]
    }
}

/// For tests and for previews.
public final class InMemoryCredentialStore: CredentialStore, @unchecked Sendable {
    private let lock = NSLock()
    private var value: String?

    public init(refreshToken: String? = nil) { self.value = refreshToken }

    // No `nonmutating` here: a class setter is already non-mutating, and the
    // keyword is rejected outright. The protocol still requires it so that a
    // STRUCT can conform -- KeychainCredentialStore writes to the keychain
    // rather than to itself, and without `nonmutating` in the protocol it
    // could not.
    public var refreshToken: String? {
        get { lock.lock(); defer { lock.unlock() }; return value }
        set { lock.lock(); value = newValue; lock.unlock() }
    }
}
