import XCTest
@testable import LiquorEngine

/// Plain English in, the app's own verbs out. These pin the grammar and, more
/// importantly, the things it must NOT do: eat the 12 in "Weller 12", or
/// guess when it does not understand.
final class AskTests: XCTestCase {

    private func product(_ id: String, _ brand: String, _ expression: String = "",
                         distillery: String = "Buffalo Trace") -> SearchCandidate {
        SearchCandidate(product: ProductIdentity(
            productId: id, distillery: distillery, brand: brand,
            expression: expression, classType: .kentuckyStraightBourbon))
    }

    private var catalog: [SearchCandidate] {
        [
            product("weller-12", "W L Weller", "12 Year"),
            product("weller-sr", "W L Weller", "Special Reserve"),
            product("blantons", "Blanton's", "Original Single Barrel"),
            product("eagle-rare-10", "Eagle Rare", "10 Year"),
            product("stagg", "Stagg"),
            product("fr-small-batch", "Four Roses", "Small Batch", distillery: "Four Roses"),
        ]
    }

    private func command(_ text: String) -> Ask.Command? {
        if case .command(let c) = Ask.understand(text, catalog: catalog) { return c }
        return nil
    }

    private func question(_ text: String) -> Ask.Question? {
        if case .question(let q) = Ask.understand(text, catalog: catalog) { return q }
        return nil
    }

    // MARK: - Pours

    func testLogAPourKeepsTheNumberInTheName() throws {
        guard case .pour(let subject, let ml)? = command("log a pour of weller 12") else {
            return XCTFail("expected a pour")
        }
        XCTAssertEqual(subject.best?.productId, "weller-12")
        XCTAssertNil(ml, "no size given: the bottle's own pour size applies")
    }

    func testAQuantityCanLeadTheSentence() throws {
        guard case .pour(let subject, let ml)? = command("1 oz of the blanton's") else {
            return XCTFail("expected a pour")
        }
        XCTAssertEqual(subject.best?.productId, "blantons")
        XCTAssertEqual(ml ?? 0, PourSize(usFluidOunces: 1).milliliters, accuracy: 0.01)
    }

    func testMillilitresAreReadAsWell() throws {
        guard case .pour(_, let ml)? = command("pour 30 ml of stagg") else {
            return XCTFail("expected a pour")
        }
        XCTAssertEqual(ml ?? 0, 30, accuracy: 0.01)
    }

    func testPoliteness() throws {
        guard case .pour(let subject, _)? = command("Please log a pour of the Eagle Rare 10") else {
            return XCTFail("expected a pour")
        }
        XCTAssertEqual(subject.best?.productId, "eagle-rare-10")
    }

    // MARK: - State changes

    func testOpenAndFinish() {
        guard case .open(let opened)? = command("opened the stagg") else { return XCTFail() }
        XCTAssertEqual(opened.best?.productId, "stagg")
        guard case .finish(let killed)? = command("finished the weller special reserve") else { return XCTFail() }
        XCTAssertEqual(killed.best?.productId, "weller-sr")
    }

    func testSetLevel() {
        guard case .setLevel(let subject, let percent)? = command("set the weller 12 level to 50%") else {
            return XCTFail("expected a level")
        }
        XCTAssertEqual(subject.best?.productId, "weller-12")
        XCTAssertEqual(percent, 50)
        guard case .setLevel(_, let half)? = command("set the stagg to half full") else { return XCTFail() }
        XCTAssertEqual(half, 50)
    }

    func testRating() {
        guard case .rate(let subject, let rating)? = command("rate the stagg an 8") else {
            return XCTFail("expected a rating")
        }
        XCTAssertEqual(subject.best?.productId, "stagg")
        XCTAssertEqual(rating, 8)
        guard case .rate(let ten, let r)? = command("rate the eagle rare 10 a 9") else { return XCTFail() }
        XCTAssertEqual(ten.best?.productId, "eagle-rare-10", "the 10 in the name survives")
        XCTAssertEqual(r, 9)
    }

    // MARK: - Adding

    func testAddABottleWithPriceAndStore() {
        guard case .addBottle(let subject, let paid, let store)? =
                command("add a bottle of Eagle Rare, paid 40 at Total Wine") else {
            return XCTFail("expected an add")
        }
        XCTAssertEqual(subject.best?.productId, "eagle-rare-10")
        XCTAssertEqual(paid, 4_000)
        XCTAssertEqual(store, "Total Wine")
    }

    func testDollarSign() {
        guard case .addBottle(_, let paid, _)? = command("bought a blanton's for $65") else { return XCTFail() }
        XCTAssertEqual(paid, 6_500)
    }

    func testWishlistWithACeiling() {
        guard case .wishlist(let subject, let ceiling)? = command("add four roses small batch to my wishlist under $40") else {
            return XCTFail("expected a wish")
        }
        XCTAssertEqual(subject.best?.productId, "fr-small-batch")
        XCTAssertEqual(ceiling, 4_000)
    }

    func testANote() {
        guard case .note(let subject, let body)? = command("note on Weller 12: runs hot in 2019 batches") else {
            return XCTFail("expected a note")
        }
        XCTAssertEqual(subject.best?.productId, "weller-12")
        XCTAssertEqual(body, "runs hot in 2019 batches")
    }

    // MARK: - Questions

    func testQuestions() {
        XCTAssertEqual(question("what's open"), .whatIsOpen)
        XCTAssertEqual(question("what is on my wishlist"), .whatIsOnMyWishlist)
        XCTAssertEqual(question("what's nearly gone"), .nearlyGone)
        guard case .howMany(let none)? = question("how many bottles do I have") else { return XCTFail() }
        XCTAssertNil(none)
        guard case .howMany(let some)? = question("how many wellers do I have") else { return XCTFail() }
        XCTAssertEqual(some?.best?.brand, "W L Weller")
        guard case .doIHave(let have)? = question("do I have any blanton's") else { return XCTFail() }
        XCTAssertEqual(have.best?.productId, "blantons")
        guard case .lastPoured(let last)? = question("when did I last pour the stagg") else { return XCTFail() }
        XCTAssertEqual(last.best?.productId, "stagg")
        guard case .whatDidIThink(let think)? = question("what did I think of the eagle rare") else { return XCTFail() }
        XCTAssertEqual(think.best?.productId, "eagle-rare-10")
        guard case .whereIs(let where_)? = question("where is my weller 12") else { return XCTFail() }
        XCTAssertEqual(where_.best?.productId, "weller-12")
    }

    // MARK: - Not guessing

    func testNonsenseIsUnknownNotAGuess() {
        if case .unknown = Ask.understand("the weather is nice", catalog: catalog) { return }
        XCTFail("a sentence the grammar does not know must come back unknown")
    }

    func testAnUnknownBottleIsStillACommandWithNoMatch() throws {
        guard case .pour(let subject, _)? = command("log a pour of pappy 23") else { return XCTFail() }
        XCTAssertEqual(subject.text, "pappy 23")
        XCTAssertNil(subject.best)
    }

    func testAmbiguityIsVisible() throws {
        guard case .pour(let subject, _)? = command("log a pour of weller") else { return XCTFail() }
        XCTAssertTrue(subject.isAmbiguous, "two Wellers score alike; the screen must ask which")
    }
}
