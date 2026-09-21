import XCTest
import GRDB
import LiquorEngine
@testable import LiquorData

/// The worst failure in the codebase is a half-stamped collection: rows that
/// look normal locally, can never be pushed, and could never be read back if
/// they were. These pin that it cannot happen.
final class AccountLinkerTests: XCTestCase {

    private func database() throws -> AppDatabase { try AppDatabase.inMemory() }

    private func populate(_ db: AppDatabase) throws -> Bottle {
        let bottles = BottleRepository(db)
        let bottle = try bottles.add(Bottle(customName: "Weller 107", volumeMl: 750))
        try bottles.logPour(bottleId: bottle.id)
        try bottles.setLevel(bottleId: bottle.id, remainingMl: 500)
        try TastingRepository(db).save(Tasting(bottleId: bottle.id, rating: 8), descriptors: [:])
        try WishlistRepository(db).add(customName: "Pappy 15", targetPriceCents: 12_000)
        return bottle
    }

    /// The app is usable with no account, so everything starts unowned.
    func testLocalRowsStartWithNoOwner() throws {
        let db = try database()
        _ = try populate(db)
        XCTAssertGreaterThan(try AccountLinker(db).unownedCount(), 0)
    }

    func testAdoptStampsEveryTable() throws {
        let db = try database()
        _ = try populate(db)
        let linker = AccountLinker(db)

        let stamped = try linker.adopt(userId: "user-1")

        XCTAssertGreaterThan(stamped, 0)
        XCTAssertEqual(
            try linker.unownedCount(), 0,
            "a single unowned row is one that can never be pushed or read back")
        let unownedBottles = try db.queue.read { db in
            try Bottle.filter(Column("user_id") == nil).fetchCount(db)
        }
        XCTAssertEqual(unownedBottles, 0, "every bottle now carries the user")
    }

    /// These rows have never been pushed, so adoption has to queue them.
    func testAdoptedRowsAreQueuedForPush() throws {
        let db = try database()
        let bottle = try populate(db)
        try db.queue.write { db in
            // Pretend an earlier sync had cleared the flag.
            try db.execute(sql: "update bottles set dirty = 0")
        }

        try AccountLinker(db).adopt(userId: "user-1")

        let pending = try db.queue.read { db in try Bottle.pending().fetchCount(db) }
        XCTAssertEqual(pending, 1)
        XCTAssertEqual(
            try db.queue.read { db in try Bottle.filter(key: bottle.id).fetchOne(db) }?.userId,
            "user-1")
    }

    /// `updated_at` is the last-write-wins key and must say when the HUMAN
    /// edited the bottle. Restamping it at sign-up would make a years-old note
    /// beat a genuinely newer edit from another device.
    func testAdoptDoesNotRestampUpdatedAt() throws {
        let db = try database()
        let bottle = try populate(db)
        let before = try XCTUnwrap(
            try db.queue.read { db in try Bottle.filter(key: bottle.id).fetchOne(db) }).updatedAt

        try AccountLinker(db).adopt(userId: "user-1")

        let after = try XCTUnwrap(
            try db.queue.read { db in try Bottle.filter(key: bottle.id).fetchOne(db) }).updatedAt
        XCTAssertEqual(before, after)
    }

    /// Signing in on a device that already synced must not steal another
    /// account's rows.
    func testAdoptOnlyTouchesUnownedRows() throws {
        let db = try database()
        _ = try populate(db)
        try AccountLinker(db).adopt(userId: "user-1")

        _ = try BottleRepository(db).add(Bottle(customName: "Later bottle", volumeMl: 750))
        let stamped = try AccountLinker(db).adopt(userId: "user-2")

        XCTAssertEqual(stamped, 1, "only the new unowned row")
        let stillOwned = try db.queue.read { db in
            try Bottle.filter(Column("user_id") == "user-1").fetchCount(db)
        }
        XCTAssertGreaterThan(stillOwned, 0)
    }

    func testAdoptingTwiceIsHarmless() throws {
        let db = try database()
        _ = try populate(db)
        let linker = AccountLinker(db)

        let first = try linker.adopt(userId: "user-1")
        let second = try linker.adopt(userId: "user-1")

        XCTAssertGreaterThan(first, 0)
        XCTAssertEqual(second, 0, "nothing left unowned")
    }
}

/// Auth parsing, which has to be right about one thing above all: the user id
/// comes from the server, never from the client.
final class SupabaseAuthParsingTests: XCTestCase {

    private func payload(_ extra: String = "") -> Data {
        Data("""
        {
          "access_token": "access-abc",
          "refresh_token": "refresh-xyz",
          "expires_in": 3600,
          "user": { "id": "11111111-2222-3333-4444-555555555555" }
          \(extra)
        }
        """.utf8)
    }

    func testItReadsTheSession() throws {
        let now = Date(timeIntervalSince1970: 1_000_000)
        let session = try SupabaseAuth.parse(payload(), now: now)

        XCTAssertEqual(session.accessToken, "access-abc")
        XCTAssertEqual(session.refreshToken, "refresh-xyz")
        XCTAssertEqual(session.userId, "11111111-2222-3333-4444-555555555555")
        XCTAssertEqual(session.expiresAt, now.addingTimeInterval(3600))
    }

    /// The id is what RLS compares against. Guessing it wrong writes rows their
    /// owner can never read back, so a response without one is a hard failure.
    func testAResponseWithNoUserIdIsRefused() {
        let data = Data("""
        {"access_token": "a", "refresh_token": "b", "expires_in": 3600}
        """.utf8)
        XCTAssertThrowsError(try SupabaseAuth.parse(data))
    }

    func testAResponseWithNoTokensIsRefused() {
        let data = Data("""
        {"user": {"id": "abc"}}
        """.utf8)
        XCTAssertThrowsError(try SupabaseAuth.parse(data))
    }

    /// Refreshed a minute early: a token expiring between the check and the
    /// request produces a 401 that reads as a sign-in problem.
    func testATokenNearExpiryIsNotConsideredFresh() throws {
        let now = Date(timeIntervalSince1970: 1_000_000)
        let session = try SupabaseAuth.parse(payload(), now: now.addingTimeInterval(-3_570))
        XCTAssertFalse(
            session.isFresh,
            "30 seconds left must not count as usable")
    }

    // MARK: - Deleting the account

    /// After the server account is gone: the rows that were its are nobody's
    /// again and queued, a partner's rows are removed, and a later account
    /// adopts what is left like a first sign-in.
    func testDisownReversesAdoptAndDropsAPartnersRows() throws {
        let db = try AppDatabase.inMemory()
        let bottles = BottleRepository(db)
        let mine = try bottles.add(Bottle(customName: "Mine", volumeMl: 750))
        var theirs = Bottle(customName: "Partner's", volumeMl: 750)
        theirs.userId = "partner"
        theirs.dirty = false
        try db.queue.write { db in try theirs.save(db) }

        let linker = AccountLinker(db)
        try linker.adopt(userId: "me")
        XCTAssertEqual(try bottles.summaries().count, 2)

        let changed = try linker.disown(userId: "me")
        XCTAssertEqual(changed, 2, "one row disowned, one removed")
        let left = try bottles.summaries()
        XCTAssertEqual(left.map(\.id), [mine.id], "the partner's row is gone")
        XCTAssertNil(left[0].bottle.userId)
        XCTAssertTrue(left[0].bottle.dirty, "queued for the next account")
        XCTAssertEqual(try linker.unownedCount(), 1)

        try linker.adopt(userId: "new-me")
        XCTAssertEqual(try bottles.summaries().first?.bottle.userId, "new-me")
    }
}

/// A credential store that forgets when the test does. The protocol's
/// setter is nonmutating because the Keychain one writes through a struct;
/// a class satisfies that by holding the value in a reference box.
private struct MemoryCredentialStore: CredentialStore {
    private final class Box: @unchecked Sendable { var token: String? }
    private let box = Box()

    var refreshToken: String? {
        get { box.token }
        nonmutating set { box.token = newValue }
    }
}

/// Apple and Google. The nonce and the verifier are the whole security
/// story of both flows, so they are pinned against the published vectors
/// rather than against themselves.
final class ProviderSignInTests: XCTestCase {

    func testTheNonceHashIsWhatAppleWillCarry() {
        let nonce = SignInNonce(raw: "abc")
        XCTAssertEqual(
            nonce.hashed,
            "ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad",
            "SHA-256 of the raw nonce, lowercase hex, as Apple expects in the request")
        XCTAssertEqual(nonce.raw, "abc", "the raw one is what the server is given")
    }

    func testAFreshNonceIsRandomAndUrlSafe() {
        let a = SignInNonce(), b = SignInNonce()
        XCTAssertNotEqual(a.raw, b.raw)
        for character in a.raw {
            XCTAssertTrue(
                character.isLetter || character.isNumber || character == "-" || character == "_",
                "a nonce travels in a URL and a JWT claim: \(character) does not")
        }
    }

    func testThePkceChallengeIsBase64UrlOfTheVerifiersHash() {
        let pkce = PKCE(verifier: "abc")
        XCTAssertEqual(pkce.challenge, "ungWv48Bz-pBQUDeXa4iI7ADYaOWF3qctBD_YfIAFa0",
                       "RFC 7636 S256: base64url, unpadded")
        XCTAssertFalse(pkce.challenge.contains("="))
        XCTAssertFalse(pkce.challenge.contains("+"))
        XCTAssertFalse(pkce.challenge.contains("/"))
    }

    func testTheAuthorizationUrlCarriesTheChallengeAndTheRedirect() throws {
        let auth = SupabaseAuth(
            host: "example.supabase.co", anonKey: "anon", store: MemoryCredentialStore())
        let pkce = PKCE(verifier: "abc")
        let url = auth.authorizationURL(
            provider: .google,
            redirectTo: URL(string: "liquorlog://auth-callback")!,
            pkce: pkce)

        let parts = try XCTUnwrap(URLComponents(url: url, resolvingAgainstBaseURL: false))
        func value(_ name: String) -> String? { parts.queryItems?.first { $0.name == name }?.value }
        XCTAssertEqual(parts.host, "example.supabase.co")
        XCTAssertEqual(parts.path, "/auth/v1/authorize")
        XCTAssertEqual(value("provider"), "google")
        XCTAssertEqual(value("redirect_to"), "liquorlog://auth-callback")
        XCTAssertEqual(value("code_challenge"), pkce.challenge)
        XCTAssertEqual(value("code_challenge_method"), "s256")
        XCTAssertNil(value("code_verifier"), "the verifier never leaves the device")
    }

    func testTheSessionKeepsTheProvidersAddress() throws {
        let data = Data("""
        {
          "access_token": "a", "refresh_token": "r", "expires_in": 3600,
          "user": { "id": "u-1", "email": "abc123@privaterelay.appleid.com" }
        }
        """.utf8)
        XCTAssertEqual(try SupabaseAuth.parse(data).email, "abc123@privaterelay.appleid.com")

        let noEmail = Data(#"{"access_token":"a","refresh_token":"r","user":{"id":"u-1"}}"#.utf8)
        XCTAssertNil(try SupabaseAuth.parse(noEmail).email)
    }
}

/// Two people, one phone.
///
/// Nothing reads by `user_id` -- the local database is "this device's
/// collection" -- so a second account signing in on a device that already
/// holds a first one's rows would see them as its own, and any edit would be
/// pushed carrying the wrong owner and rejected by RLS forever.
final class AccountSwitchTests: XCTestCase {

    private func database() throws -> AppDatabase { try AppDatabase.inMemory() }

    /// A bottle already stamped for `owner`, as a pull would have left it.
    @discardableResult
    private func bottle(_ db: AppDatabase, _ name: String, owner: String?) throws -> Bottle {
        let added = try BottleRepository(db).add(Bottle(customName: name, volumeMl: 750))
        try db.queue.write { db in
            try db.execute(
                sql: "update bottles set user_id = ?, dirty = 0 where id = ?",
                arguments: [owner, added.id])
        }
        return added
    }

    private func names(_ db: AppDatabase) throws -> [String] {
        try db.queue.read { db in
            try String.fetchAll(db, sql: "select custom_name from bottles order by custom_name")
        }
    }

    func testForeignCountSeesOnlyOtherAccountsRows() throws {
        let db = try database()
        try bottle(db, "Mine", owner: "user-b")
        try bottle(db, "Theirs", owner: "user-a")
        try bottle(db, "Nobodys", owner: nil)

        XCTAssertEqual(try AccountLinker(db).foreignCount(excluding: "user-b"), 1)
        XCTAssertEqual(
            try AccountLinker(db).foreignCount(excluding: "user-a"), 1,
            "it is symmetric: whoever is asking, the other one's row is foreign")
    }

    /// An unowned row is the local-only collection, which the signing-in
    /// account is about to adopt. It must survive.
    func testEvictRemovesTheOtherAccountAndNothingElse() throws {
        let db = try database()
        try bottle(db, "Mine", owner: "user-b")
        try bottle(db, "Theirs", owner: "user-a")
        try bottle(db, "Nobodys", owner: nil)

        let removed = try AccountLinker(db).evict(keeping: "user-b")

        XCTAssertEqual(removed, 1)
        XCTAssertEqual(try names(db), ["Mine", "Nobodys"])
    }

    /// The whole sequence a sign-in performs, in order.
    func testASecondAccountInheritsOnlyTheUnownedCollection() throws {
        let db = try database()
        try bottle(db, "Theirs", owner: "user-a")
        try bottle(db, "Nobodys", owner: nil)
        let linker = AccountLinker(db)

        try linker.evict(keeping: "user-b")
        try linker.adopt(userId: "user-b")

        XCTAssertEqual(try names(db), ["Nobodys"])
        XCTAssertEqual(try linker.unownedCount(), 0)
        XCTAssertEqual(
            try db.queue.read { db in
                try String.fetchAll(db, sql: "select distinct user_id from bottles")
            },
            ["user-b"],
            "the first account's bottle is not quietly re-owned by the second")
    }

    /// Signing the same account back in is not a switch, and a household
    /// partner's rows must not be thrown away and re-downloaded every time.
    func testTheSameAccountEvictsNothing() throws {
        let db = try database()
        try bottle(db, "Mine", owner: "user-b")
        try bottle(db, "Partners", owner: "user-a")

        XCTAssertEqual(try AccountLinker(db).foreignCount(excluding: "user-b"), 1)
        // The controller only evicts when the stored last user differs, so
        // this path is never reached for a repeat sign-in. Pinned here so the
        // cost of getting that wrong stays visible: it would be this.
        XCTAssertEqual(try AccountLinker(db).evict(keeping: "user-b"), 1)
        XCTAssertEqual(try names(db), ["Mine"])
    }

    func testEvictIsAcrossEveryTableNotJustBottles() throws {
        let db = try database()
        let mine = try BottleRepository(db).add(Bottle(customName: "Mine", volumeMl: 750))
        try BottleRepository(db).logPour(bottleId: mine.id)
        try TastingRepository(db).save(Tasting(bottleId: mine.id, rating: 8), descriptors: [:])
        try WishlistRepository(db).add(customName: "Pappy 15", targetPriceCents: 12_000)
        try db.queue.write { db in
            for table in ["bottles", "pours", "tastings", "wishlist_items"] {
                try db.execute(sql: "update \(table) set user_id = 'user-a'")
            }
        }

        let removed = try AccountLinker(db).evict(keeping: "user-b")

        // The count is of DIRECT deletes only -- pours and tastings cascade
        // from their bottle, and sqlite3_changes does not count those -- so
        // the end state is what this asserts, not the number.
        XCTAssertGreaterThan(removed, 0)
        for table in ["bottles", "pours", "tastings", "wishlist_items"] {
            XCTAssertEqual(
                try db.queue.read { db in
                    try Int.fetchOne(db, sql: "select count(*) from \(table)") ?? -1
                },
                0,
                table)
        }
    }
}
