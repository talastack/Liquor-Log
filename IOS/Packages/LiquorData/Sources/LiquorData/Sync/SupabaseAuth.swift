import Foundation
import CryptoKit

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
        /// From the provider, when it gave one. Apple's Hide My Email
        /// returns a relay address, which is the account's address as far
        /// as anything here is concerned.
        public let email: String?
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
    public var userId: String? { current?.userId }
    public var email: String? { current?.email }

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

    /// Whether this device holds a credential worth trying.
    ///
    /// Reads the keychain and makes no request, so the launch path can decide
    /// whether a restore is worth attempting without a signed-out app showing
    /// a spinner for a session that does not exist.
    public var hasStoredCredentials: Bool { store.refreshToken != nil }

    /// The session this device can use right now, for restoring one at launch.
    ///
    /// Nil when there is nothing stored, or when what is stored is dead. It
    /// goes through the actor like everything else here, which is what keeps
    /// it from racing a transport request that refreshes at the same moment
    /// and rotates the token out from under it.
    public func restoredSession() async -> Session? {
        if let current, current.isFresh { return current }
        guard store.refreshToken != nil else { return nil }
        return try? await refresh()
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

    // MARK: - Apple and Google

    /// Signs in with a provider's own identity token.
    ///
    /// The native path: the phone asks Apple, Apple hands back a signed JWT,
    /// and the server verifies it against Apple's public keys. No browser,
    /// no redirect, no SDK.
    ///
    /// `nonce` is the RAW nonce. The request sent to Apple carried its
    /// SHA-256, which Apple copied into the token; the server hashes this one
    /// and compares. That is what stops a token captured elsewhere being
    /// replayed here, so it is not optional.
    @discardableResult
    public func signIn(provider: OAuthProvider, idToken: String, nonce: String) async throws -> Session {
        try await authenticate(
            path: "token",
            query: [URLQueryItem(name: "grant_type", value: "id_token")],
            body: ["provider": provider.rawValue, "id_token": idToken, "nonce": nonce])
    }

    /// Where to send the browser for a provider with no native sheet.
    ///
    /// PKCE, not the implicit flow: the authorisation code comes back in the
    /// redirect and is worthless without the verifier, which never leaves the
    /// device. An implicit flow would put the tokens themselves in a URL, and
    /// a URL is logged, shoulder-read, and handed to whatever claims the
    /// scheme.
    public nonisolated func authorizationURL(
        provider: OAuthProvider, redirectTo: URL, pkce: PKCE
    ) -> URL {
        endpoint("authorize", query: [
            URLQueryItem(name: "provider", value: provider.rawValue),
            URLQueryItem(name: "redirect_to", value: redirectTo.absoluteString),
            URLQueryItem(name: "code_challenge", value: pkce.challenge),
            URLQueryItem(name: "code_challenge_method", value: "s256"),
        ])
    }

    /// Trades the code from the redirect for a session.
    @discardableResult
    public func exchange(authCode: String, pkce: PKCE) async throws -> Session {
        try await authenticate(
            path: "token",
            query: [URLQueryItem(name: "grant_type", value: "pkce")],
            body: ["auth_code": authCode, "code_verifier": pkce.verifier])
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

    private nonisolated func endpoint(_ path: String, query: [URLQueryItem]) -> URL {
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
        let email = (user?["email"] as? String).flatMap { $0.isEmpty ? nil : $0 }

        let seconds = (json["expires_in"] as? Double)
            ?? (json["expires_in"] as? NSNumber)?.doubleValue
            ?? 3600
        return Session(
            accessToken: access,
            refreshToken: refresh,
            userId: userId,
            email: email,
            expiresAt: now.addingTimeInterval(seconds))
    }
}

// MARK: - Providers, nonces and PKCE

/// The providers the app offers besides email.
///
/// Apple is not optional once Google is here: App Store guideline 4.8
/// requires Sign in with Apple wherever a third-party login is offered.
public enum OAuthProvider: String, Sendable, CaseIterable {
    case apple
    case google

    public var label: String {
        switch self {
        case .apple: return "Apple"
        case .google: return "Google"
        }
    }
}

/// A one-time value that ties a provider's reply to the request that asked
/// for it.
///
/// Apple is sent the SHA-256 and copies it into the token it signs; the raw
/// string goes to the server, which hashes it and compares. A token lifted
/// from somewhere else carries somebody else's hash and is refused.
public struct SignInNonce: Sendable, Equatable {
    /// Goes to the server, with the token.
    public let raw: String
    /// Goes to Apple, in the authorization request.
    public let hashed: String

    public init(raw: String = SignInNonce.randomString()) {
        self.raw = raw
        self.hashed = SHA256.hash(data: Data(raw.utf8))
            .map { String(format: "%02x", $0) }
            .joined()
    }

    /// Random bytes in the unreserved characters that survive a URL and a
    /// JWT claim unchanged.
    public static func randomString(byteCount: Int = 32) -> String {
        var generator = SystemRandomNumberGenerator()
        var bytes = [UInt8](repeating: 0, count: byteCount)
        for index in bytes.indices { bytes[index] = UInt8.random(in: 0...255, using: &generator) }
        return Data(bytes).base64URLEncodedString()
    }
}

/// Proof Key for Code Exchange (RFC 7636).
///
/// The verifier stays on the device and only the challenge goes out. An app
/// that intercepts the redirect gets a code it cannot spend.
public struct PKCE: Sendable, Equatable {
    public let verifier: String
    public let challenge: String

    public init(verifier: String = SignInNonce.randomString()) {
        self.verifier = verifier
        self.challenge = Data(SHA256.hash(data: Data(verifier.utf8))).base64URLEncodedString()
    }
}

extension Data {
    /// base64url, unpadded: RFC 4648 section 5, which is what both RFC 7636
    /// and GoTrue expect. Plain base64 would carry +, / and = into a URL.
    func base64URLEncodedString() -> String {
        base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
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
