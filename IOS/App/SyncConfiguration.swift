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
    /// Called after a sync that pulled rows. The app wires this to
    /// `AppEnvironment.noteChange`.
    var onPulled: (() -> Void)?

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
    /// The same transport, for the community views. Nil without a project.
    let communityTransport: SupabaseTransport?

    /// The household this account is in, if any. Asked of the server after
    /// sign-in and after every change; nil while signed out.
    struct Household: Decodable, Equatable {
        let id: String
        let name: String
        let inviteCode: String
        let members: Int

        enum CodingKeys: String, CodingKey {
            case id, name, inviteCode = "invite_code", members
        }
    }
    private(set) var household: Household?
    private(set) var householdError: String?
    /// Where a published menu is served: the project's functions host.
    let menuBase: URL?

    /// Which account this device's rows were last stamped for.
    ///
    /// Device state, like the sync cursors, and kept in the same place for the
    /// same reasons: it must not sync, and losing it is safe -- an absent
    /// value only means the switch check asks the database instead.
    private static let lastUserKey = "sync.lastUserId"

    private var lastSignedInUserId: String? {
        get { UserDefaults.standard.string(forKey: Self.lastUserKey) }
        set { UserDefaults.standard.set(newValue, forKey: Self.lastUserKey) }
    }

    init(database: AppDatabase, configuration: SyncConfiguration?) {
        self.database = database

        guard let configuration else {
            self.auth = nil
            self.engine = nil
            self.communityTransport = nil
            self.menuBase = nil
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
        self.communityTransport = transport
        self.menuBase = URL(string: "https://\(configuration.host)/functions/v1/menu/")
        self.state = .signedOut

        // Started here rather than from a view's .task so the restore happens
        // once per launch whichever screen opens first -- and so a tab nobody
        // visits is not the reason sync never runs.
        Task { await restore() }
    }

    var isSignedIn: Bool {
        if case .signedIn = state { return true }
        return false
    }

    /// Signs back in from the refresh token already in the keychain.
    ///
    /// Without this the app starts signed out on every launch even though the
    /// credential is still good. The transport would refresh happily on its
    /// next request, but nothing tells the screens, so the Sync tab offers a
    /// sign-in form to somebody who is already signed in and no sync runs
    /// until they use it.
    ///
    /// A dead token is not an error worth a banner. Signed out is a normal
    /// state this app is built to work in.
    func restore() async {
        guard let auth, case .signedOut = state else { return }
        guard await auth.hasStoredCredentials else { return }
        state = .working
        guard let session = await auth.restoredSession() else {
            state = .signedOut
            return
        }
        state = .signedIn(email: session.email)
        lastSignedInUserId = session.userId
        await sync()
        await refreshHousehold()
    }

    // MARK: - Account

    func signIn(email: String, password: String) async {
        await authenticate(email: email) { try await $0.signIn(email: email, password: password) }
    }

    func signUp(email: String, password: String) async {
        await authenticate(email: email) { try await $0.signUp(email: email, password: password) }
    }

    /// Where the browser sends the person back. Registered as a URL scheme
    /// in Info.plist, and it must also be on the project's redirect
    /// allow-list or GoTrue refuses to redirect to it.
    static let redirect = URL(string: "liquorlog://auth-callback")!

    /// A sign-in that failed in the sheet rather than on the wire.
    func report(signInError message: String) {
        state = .signedOut
        lastError = message
    }

    /// Sign in with Apple. The token is Apple's, already signed; the nonce
    /// is the raw one whose hash the token carries.
    func signIn(appleIdentityToken token: String, nonce: String) async {
        await authenticate(email: nil) {
            try await $0.signIn(provider: .apple, idToken: token, nonce: nonce)
        }
    }

    /// Google, through the system's sign-in browser. Cancelling is not an
    /// error: the state goes back to signed out with nothing said.
    func signInWithGoogle() async {
        guard let auth else { return }
        let pkce = PKCE()
        let url = auth.authorizationURL(provider: .google, redirectTo: Self.redirect, pkce: pkce)
        state = .working
        lastError = nil
        do {
            let code = try await BrowserSignIn.authorizationCode(
                at: url, scheme: Self.redirect.scheme ?? "liquorlog")
            await authenticate(email: nil) { try await $0.exchange(authCode: code, pkce: pkce) }
        } catch BrowserSignIn.Failure.cancelled {
            state = .signedOut
        } catch BrowserSignIn.Failure.noCode(let why) {
            state = .signedOut
            lastError = why ?? "Google did not complete the sign-in."
        } catch {
            state = .signedOut
            lastError = Self.describe(error)
        }
    }

    /// `email` is what the screen should show. Nil where the provider
    /// decides it -- Apple's relay address, or whatever Google hands back --
    /// and then the session's own answer is used.
    private func authenticate(
        email: String?,
        _ body: (SupabaseAuth) async throws -> SupabaseAuth.Session
    ) async {
        guard let auth else { return }
        state = .working
        lastError = nil
        do {
            let session = try await body(auth)

            // A DIFFERENT person on a device that already holds a collection.
            // Their rows go, and the cursors go with them -- the cursor is a
            // per-table high-water mark with no account in its key, so the new
            // account's first pull would otherwise start from the previous
            // account's mark and silently skip every row older than it.
            if isAccountSwitch(to: session.userId) {
                try AccountLinker(database).evict(keeping: session.userId)
                await engine?.forgetCursors()
            }

            // BEFORE any push. A row pushed without an owner is rejected by a
            // NOT NULL and, if it somehow landed, could never be read back
            // through RLS.
            try AccountLinker(database).adopt(userId: session.userId)
            lastSignedInUserId = session.userId

            state = .signedIn(email: email ?? session.email)
            await sync()
            await refreshHousehold()
        } catch {
            state = .signedOut
            lastError = Self.describe(error)
        }
    }

    /// Whether the account signing in is not the one this device's rows
    /// belong to.
    ///
    /// The stored id answers it outright. When there is none -- a fresh
    /// install, or a build from before this check existed -- the database
    /// answers instead, which also repairs a device that already merged two
    /// collections before the check was written.
    ///
    /// Signing the SAME account back in is not a switch, which is what keeps
    /// a household partner's rows from being thrown away and re-downloaded on
    /// every sign-in.
    private func isAccountSwitch(to userId: String) -> Bool {
        if let previous = lastSignedInUserId { return previous != userId }
        return ((try? AccountLinker(database).foreignCount(excluding: userId)) ?? 0) > 0
    }

    // MARK: - A shelf shared with a partner

    func refreshHousehold() async {
        guard let communityTransport, isSignedIn else { household = nil; return }
        do {
            let data = try await communityTransport.rpc("my_household")
            household = try JSONDecoder().decode([Household].self, from: data).first
        } catch {
            // Not an error worth a banner: the server may not have the
            // patch yet, and the section simply stays absent.
            household = nil
        }
    }

    /// Creates the household and gets its invite code back.
    func createHousehold(named name: String) async {
        await changeHousehold("create_household", ["household_name": name])
    }

    /// Joins with a partner's code. The server touches both shelves so the
    /// next pull brings theirs across; the cursors are forgotten so the
    /// pull starts from the beginning.
    func joinHousehold(code: String) async {
        await changeHousehold("join_household", ["code": code.uppercased().trimmingCharacters(in: .whitespaces)])
    }

    /// Leaves. Rows already pulled stay on this phone -- nothing that was
    /// read is destroyed -- and the next pull brings nothing new of theirs.
    func leaveHousehold() async {
        await changeHousehold("leave_household", [:])
    }

    private func changeHousehold(_ function: String, _ arguments: [String: any Sendable]) async {
        guard let communityTransport, isSignedIn else { return }
        householdError = nil
        do {
            _ = try await communityTransport.rpc(function, arguments: arguments)
            await engine?.forgetCursors()
            await refreshHousehold()
            await sync()
        } catch SyncError.http(_, let body) {
            householdError = Self.describeHousehold(body)
        } catch {
            householdError = Self.describe(error)
        }
    }

    /// The function's own words, when it raised them.
    private static func describeHousehold(_ body: String) -> String {
        if body.contains("no household with that code") { return "No household has that code." }
        if body.contains("already in a household") { return "This account is already in a household. Leave it first." }
        if body.contains("not signed in") { return "Signed out. Sign in again." }
        if body.contains("function") && body.contains("does not exist") {
            return "The server does not have households yet; run patch 0009."
        }
        return "Could not change the household."
    }

    func signOut() async {
        await auth?.signOut()
        state = .signedOut
        household = nil
        // Local data is deliberately untouched. Signing out on a shared iPad is
        // not a request to lose a collection.
    }

    /// Deletes the account on the server -- the auth row and, by cascade,
    /// every row synced under it -- then unlinks the collection on this
    /// phone so it is nobody's again. The collection itself stays here.
    /// App Store guideline 5.1.1(v).
    func deleteAccount() async {
        guard let communityTransport, let auth, case .signedIn(let email) = state,
              let userId = await auth.userId else { return }
        state = .working
        lastError = nil
        do {
            _ = try await communityTransport.rpc("delete_my_account")
            try AccountLinker(database).disown(userId: userId)
            await engine?.forgetCursors()
            await auth.signOut()
            // The rows are nobody's again, so there is no previous account for
            // the next sign-in to be a switch away from.
            lastSignedInUserId = nil
            household = nil
            state = .signedOut
        } catch {
            state = .signedIn(email: email)
            lastError = Self.describe(error)
        }
    }

    // MARK: - Sync

    func sync() async {
        guard let engine else { return }
        let outcome = await engine.sync()
        lastOutcome = outcome
        unowned = (try? AccountLinker(database).unownedCount()) ?? 0
        // Rows pulled from the server changed the shelf; the widget and
        // the search index are told the way any write tells them.
        if outcome.pulled > 0 { onPulled?() }
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
