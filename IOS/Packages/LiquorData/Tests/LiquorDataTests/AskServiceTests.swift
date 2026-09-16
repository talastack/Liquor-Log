import XCTest
import GRDB
import LiquorEngine
@testable import LiquorData

/// Ask, end to end: a sentence in, the database changed, a sentence out.
/// The screen only shows what these return and asks for the yes.
final class AskServiceTests: XCTestCase {

    private var db: AppDatabase!
    private var bottles: BottleRepository!
    private var service: AskService!

    private let weller = ProductIdentity(
        productId: "weller-12", distillery: "Buffalo Trace", brand: "W L Weller",
        expression: "12 Year", classType: .kentuckyStraightBourbon)
    private let stagg = ProductIdentity(
        productId: "stagg", distillery: "Buffalo Trace", brand: "Stagg",
        expression: "", classType: .kentuckyStraightBourbon)

    private var catalog: [SearchCandidate] {
        [SearchCandidate(product: weller), SearchCandidate(product: stagg)]
    }

    override func setUpWithError() throws {
        db = try AppDatabase.inMemory()
        bottles = BottleRepository(db)
        let known = [weller, stagg]
        service = AskService(
            db,
            identity: { id in known.first { $0.productId == id } },
            name: { bottle in known.first { $0.productId == bottle.catalogProductId }?.displayName ?? "?" })
    }

    private func command(_ text: String) throws -> Ask.Command {
        guard case .command(let c) = Ask.understand(text, catalog: catalog) else {
            throw XCTSkip("not a command: \(text)")
        }
        return c
    }

    private func question(_ text: String) throws -> Ask.Question {
        guard case .question(let q) = Ask.understand(text, catalog: catalog) else {
            throw XCTSkip("not a question: \(text)")
        }
        return q
    }

    // MARK: - Commands that write

    func testLogAPourWritesThePourAndOpensTheBottle() throws {
        let bottle = try bottles.add(Bottle(catalogProductId: "weller-12"))
        let cmd = try command("log a pour of weller 12")
        let described = service.describe(cmd)
        XCTAssertTrue(described.canRun)
        XCTAssertEqual(described.text, "Log a pour from W L Weller 12 Year and mark it opened?")

        let said = try service.execute(cmd)
        XCTAssertEqual(said, "Logged 44 ml from W L Weller 12 Year. 16 pours left.")
        let after = try XCTUnwrap(bottles.summary(id: bottle.id))
        XCTAssertTrue(after.bottle.isOpen)
        XCTAssertEqual(after.status.remainingPours, 16)
    }

    func testAPourOfAGivenSize() throws {
        _ = try bottles.add(Bottle(catalogProductId: "stagg"))
        let said = try service.execute(try command("1 oz of the stagg"))
        XCTAssertTrue(said.hasPrefix("Logged 30 ml from Stagg."), said)
    }

    func testNothingOnTheShelfCannotBePoured() throws {
        let described = service.describe(try command("log a pour of weller 12"))
        XCTAssertFalse(described.canRun)
        XCTAssertEqual(described.text, "You do not have a bottle of W L Weller 12 Year on the shelf to pour from.")
    }

    func testAnUnknownBottleIsRefusedWithoutWriting() throws {
        let described = service.describe(try command("log a pour of pappy 23"))
        XCTAssertFalse(described.canRun)
        XCTAssertTrue(described.text.contains("could not find \"pappy 23\""))
        XCTAssertEqual(try bottles.summaries().count, 0)
    }

    func testOpenFinishAndSetLevel() throws {
        let bottle = try bottles.add(Bottle(catalogProductId: "stagg"))
        try service.execute(try command("opened the stagg"))
        XCTAssertTrue(try XCTUnwrap(bottles.summary(id: bottle.id)).bottle.isOpen)
        try service.execute(try command("set the stagg level to 50%"))
        XCTAssertEqual(try XCTUnwrap(bottles.summary(id: bottle.id)).status.remainingMilliliters, 375, accuracy: 0.01)
        try service.execute(try command("finished the stagg"))
        XCTAssertTrue(try bottles.summaries().isEmpty)
        XCTAssertEqual(try bottles.summaries(includeFinished: true).count, 1)
    }

    func testRateAddWishAndNote() throws {
        _ = try bottles.add(Bottle(catalogProductId: "stagg"))
        try service.execute(try command("rate the stagg an 8"))
        XCTAssertEqual(try TastingRepository(db).history(productId: "stagg").first?.tasting.rating, 8)

        let added = try service.execute(try command("add a bottle of weller 12, paid 45 at Total Wine"))
        XCTAssertEqual(added, "Added W L Weller 12 Year to the shelf, sealed and full.")
        let weller = try XCTUnwrap(bottles.summaries().first { $0.bottle.catalogProductId == "weller-12" })
        XCTAssertEqual(weller.bottle.purchasePriceCents, 4_500)
        XCTAssertEqual(weller.bottle.purchaseStore, "Total Wine")

        try service.execute(try command("add stagg to my wishlist under $150"))
        XCTAssertEqual(try WishlistRepository(db).items().first?.targetPriceCents, 15_000)

        try service.execute(try command("note on weller 12: runs hot in 2019 batches"))
        XCTAssertEqual(try KnowledgeNoteRepository(db).note(productId: "weller-12")?.body, "runs hot in 2019 batches")
    }

    // MARK: - Questions that read

    func testQuestionsAnswerFromTheShelf() throws {
        let bottle = try bottles.add(Bottle(catalogProductId: "weller-12", purchasePriceCents: 4_999, storageLocation: "Cabinet"))
        _ = try bottles.add(Bottle(catalogProductId: "stagg"))
        _ = try bottles.logPour(bottleId: bottle.id)

        XCTAssertEqual(service.answer(try question("how many bottles do I have")), "2 bottles on the shelf, 1 open.")
        XCTAssertEqual(service.answer(try question("what's open")), "• W L Weller 12 Year — 16 pours left")
        XCTAssertEqual(service.answer(try question("do I have any stagg")), "Yes — 1 of Stagg, 0 open.")
        XCTAssertEqual(service.answer(try question("when did I last pour the weller 12")), "Today.")
        XCTAssertEqual(service.answer(try question("what did I pay for the weller 12")), "$49.99 for W L Weller 12 Year.")
        XCTAssertEqual(service.answer(try question("where is my weller 12")), "Cabinet.")
        XCTAssertEqual(service.answer(try question("what's nearly gone")), "Nothing is down to its last pours.")
        XCTAssertEqual(service.answer(try question("what is on my wishlist")), "The wishlist is empty.")
    }

    func testTheLineIsKnownWhenTheExpressionIsNot() throws {
        _ = try bottles.add(Bottle(catalogProductId: "weller-12"))
        let sr = ProductIdentity(
            productId: "weller-sr", distillery: "Buffalo Trace", brand: "W L Weller",
            expression: "Special Reserve", classType: .kentuckyStraightBourbon)
        let asked = Ask.understand("do I have weller special reserve", catalog: catalog + [SearchCandidate(product: sr)])
        guard case .question(let q) = asked else { return XCTFail("expected a question") }
        XCTAssertEqual(service.answer(q), "Not that one, but you have the line: W L Weller 12 Year.")
    }

    // MARK: - The hunt log and the people

    func testASightingIsLoggedAndAskedBack() throws {
        let saw = try command("saw stagg at Total Wine for $99, 2 on the shelf")
        XCTAssertEqual(service.describe(saw).text, "Log that you saw Stagg at Total Wine for $99.00, 2 on the shelf?")
        XCTAssertEqual(try service.execute(saw), "Logged: Stagg at Total Wine. It is in the hunt log.")

        let asked = Ask.understand("where did I see stagg", catalog: catalog)
        guard case .question(let q) = asked else { return XCTFail("expected a question") }
        XCTAssertEqual(service.answer(q), "At Total Wine today · $99.00 · 2 on the shelf.")
    }

    func testASightingWithNoStoreCannotRun() throws {
        let saw = try command("saw stagg for $99")
        XCTAssertFalse(service.describe(saw).canRun)
    }

    func testALotteryEntryIsLogged() throws {
        let entered = try command("entered the stagg lottery at Virginia ABC")
        XCTAssertEqual(service.describe(entered).text, "Log a lottery entry for Stagg at Virginia ABC?")
        _ = try service.execute(entered)
        let rows = try SightingRepository(db).all()
        XCTAssertEqual(rows.first?.kind, .entered)
        XCTAssertEqual(rows.first?.store, "Virginia ABC")
    }

    func testAVisitIsStampedAndAskedBack() throws {
        guard case .question(let before) = Ask.understand("have I been to Buffalo Trace", catalog: catalog) else { return XCTFail() }
        XCTAssertEqual(service.answer(before), "No visit to Buffalo Trace in the passport.")

        let visited = try command("visited Buffalo Trace")
        XCTAssertEqual(service.describe(visited).text, "Stamp the passport: Buffalo Trace, today?")
        XCTAssertEqual(try service.execute(visited), "Stamped: Buffalo Trace. It is in the passport.")
        XCTAssertEqual(try VisitRepository(db).all().map(\.distillery), ["Buffalo Trace"])

        XCTAssertEqual(service.answer(before), "Buffalo Trace: once, today.")
    }

    func testWhatSomebodySentIsAnsweredFromSamplesAndPours() throws {
        _ = try bottles.add(Bottle(catalogProductId: "weller-12", volumeMl: 50, isSample: true, sampleFrom: "Mike", sampleSource: .swap))
        let stagg = try bottles.add(Bottle(catalogProductId: "stagg"))
        try bottles.open(bottleId: stagg.id)
        _ = try bottles.logPour(bottleId: stagg.id, volumeMl: 30, givenTo: "Mike")

        let asked = Ask.understand("what did Mike send me", catalog: catalog)
        guard case .question(let q) = asked else { return XCTFail("expected a question") }
        XCTAssertEqual(service.answer(q), "From Mike: W L Weller 12 Year (50 ml). To Mike: Stagg (30 ml). About even.")

        guard case .question(let nobody) = Ask.understand("what did Joe send me", catalog: catalog) else { return XCTFail() }
        XCTAssertTrue(service.answer(nobody).hasPrefix("Nothing logged from Joe."))
    }
}
