import Foundation
import LiquorData

/// Where the Supabase project is, read from the bundle.
///
/// Empty is a valid, expected state: `Config/Base.xcconfig` defines both keys
/// blank and `IOS/Secrets.xcconfig` — which fills them in — is gitignored. So a
/// fresh clone builds and runs with **sync simply absent**, not broken. The
/// whole app works that way, and treating a missing project as an error would
/// make an offline-first product refuse to start over a feature nobody has
/// asked for yet.
struct SyncConfiguration: Sendable {
    let host: String
    let anonKey: String

    /// Nil when the app was built without a project configured.
    static func fromBundle(_ bundle: Bundle = .main) -> SyncConfiguration? {
        let host = string(bundle, "SupabaseHost")
        let key = string(bundle, "SupabaseAnonKey")
        guard let host, let key else { return nil }
        return SyncConfiguration(host: host, anonKey: key)
    }

    /// Trims, and treats an unsubstituted build setting as absent.
    ///
    /// A blank xcconfig value can reach the plist as the literal `$(NAME)` when
    /// the setting is not defined at all, and that string would otherwise be
    /// used as a hostname and fail as a DNS error hours later.
    private static func string(_ bundle: Bundle, _ key: String) -> String? {
        guard let raw = bundle.object(forInfoDictionaryKey: key) as? String else { return nil }
        let value = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !value.isEmpty, !value.hasPrefix("$(") else { return nil }
        return value
    }
}

/// Sign-in, and pushing what has changed.
///
/// **Nothing on any screen waits for this.** The collection, the shelf check,
/// tastings and the export all work with no account and no network; sync adds a
/// second device and nothing else.
@Observable
@MainActor
final class SyncController {
    enum State: Equatable {
        case unavailable            // no Supabase project in this build
        case signedOut
        case working
        case signedIn(email: String?)
    }

    private(set) var state: State
    private(set) var lastOutcome: SyncEngine.Outcome?
    private(set) var lastError: String?
    private(set) var unowned: Int = 0

    private let database: AppDatabase
    private let auth: SupabaseAuth?
    private let engine: SyncEngine?

    init(database: AppDatabase, configuration: SyncConfiguration?) {
        self.database = database

        guard let configuration else {
            self.auth = nil
            self.engine = nil
            self.state = .unavailable
            return
        }

        let auth = SupabaseAuth(
            host: configuration.host,
            anonKey: configuration.anonKey,
            store: KeychainCredentialStore())
        self.auth = auth

        // Read fresh on every request rather than captured once: a JWT expires
        // while the phone is in a pocket.
        let transport = SupabaseTransport(
            baseURL: URL(string: "https://\(configuration.host)")!,
            anonKey: configuration.anonKey,
            accessToken: { await auth.accessToken() })

        self.engine = SyncEngine(
            db: database,
            transport: transport,
            cursors: UserDefaultsCursorStore())
        self.state = .signedOut
    }

    // MARK: - Account

    func signIn(email: String, password: String) async {
        await authenticate(email: email) { try await $0.signIn(email: email, password: password) }
    }

    func signUp(email: String, password: String) async {
        await authenticate(email: email) { try await $0.signUp(email: email, password: password) }
    }

    private func authenticate(
        email: String,
        _ body: (SupabaseAuth) async throws -> SupabaseAuth.Session
    ) async {
        guard let auth else { return }
        state = .working
        lastError = nil
        do {
            let session = try await body(auth)

            // BEFORE any push. A row pushed without an owner is rejected by a
            // NOT NULL and, if it somehow landed, could never be read back
            // through RLS.
            try AccountLinker(database).adopt(userId: session.userId)

            state = .signedIn(email: email)
            await sync()
        } catch {
            state = .signedOut
            lastError = Self.describe(error)
        }
    }

    func signOut() async {
        await auth?.signOut()
        state = .signedOut
        // Local data is deliberately untouched. Signing out on a shared iPad is
        // not a request to lose a collection.
    }

    // MARK: - Sync

    func sync() async {
        guard let engine else { return }
        let outcome = await engine.sync()
        lastOutcome = outcome
        unowned = (try? AccountLinker(database).unownedCount()) ?? 0
        if let first = outcome.failures.first {
            lastError = "\(first.key): \(first.value)"
        }
    }

    /// Plain words. "The operation couldn't be completed" tells nobody
    /// anything, and a raw PostgREST body is worse.
    private static func describe(_ error: Error) -> String {
        switch error {
        case SyncError.notAuthenticated:
            return "Signed out. Sign in again to sync."
        case SyncError.http(let status, _) where status == 400 || status == 401:
            return "That email and password did not match."
        case SyncError.http(let status, _) where status == 422:
            return "That email is already registered."
        case SyncError.http(let status, _) where status >= 500:
            return "The server is having trouble. Your collection is safe on this phone."
        default:
            return "Could not reach the server. Everything still works offline."
        }
    }
}
