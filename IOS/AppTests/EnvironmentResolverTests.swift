import XCTest
import LiquorEngine
import LiquorData
@testable import LiquorLog

/// The resolver every screen goes through.
///
/// `AppEnvironment.identity(_:)` turns a product id into something with a
/// name, a distillery and a class. Every screen in the app calls it, directly
/// or through `name(for:)`, and it is where the worst bug of this project
/// lived: the add-bottle form matched a catalogue product, filled itself in,
/// and then threw the matched id away, so the bottle became a typed-in entry
/// and the shelf check answered NEVER HAD IT about a bottle on the shelf.
///
/// The engine has 535 tests and the data layer 184, and not one of them would
/// have caught that, because the fault was in neither layer -- it was in the
/// wiring between them, which is what this file tests.
///
/// Hermetic on purpose: the catalogue here is built in the test rather than
/// read from the app bundle, so these prove the resolution rules and not
/// whether a JSON file happened to be copied into a test host.
final class EnvironmentResolverTests: XCTestCase {

    private func environment(catalog: Catalog = Catalog(products: [])) throws -> AppEnvironment {
        AppEnvironment(
            database: try AppDatabase.inMemory(),
            catalog: catalog,
            wheel: FlavorWheel(version: 0, name: "test", families: []))
    }

    private var wellerProduct: CatalogProduct {
        CatalogProduct(
            id: "weller-12",
            distillery: "Buffalo Trace",
            brand: "W. L. Weller",
            expression: "12 Year",
            classType: .bourbon,
            productionType: .smallBatch)
    }

    // MARK: - The two halves of the resolver

    func testACatalogueProductResolves() throws {
        let env = try environment(catalog: Catalog(products: [wellerProduct]))

        let identity = env.identity("weller-12")
        XCTAssertNotNil(identity)
        XCTAssertEqual(identity?.distillery, "Buffalo Trace")
        XCTAssertEqual(identity?.classType, .bourbon)
    }

    func testATypedInProductResolves() throws {
        let env = try environment()
        let entry = CustomCatalogEntry(
            distillery: "Jefferson's", brand: "Jefferson's",
            expression: "Ocean", classType: .bourbon)
        let saved = try env.bottles.addCustom(product: entry, bottle: Bottle())

        let identity = env.identity(saved.product.id)
        XCTAssertNotNil(
            identity,
            "a bottle somebody typed in has to resolve exactly like a catalogue one")
        XCTAssertEqual(identity?.distillery, "Jefferson's")
    }

    func testAnUnknownIdResolvesToNothing() throws {
        let env = try environment(catalog: Catalog(products: [wellerProduct]))
        XCTAssertNil(env.identity("not-a-product"))
    }

    func testTheCatalogueWinsWhenBothCouldAnswer() throws {
        // Same id in both places. The bundled catalogue is the one the app
        // ships and the one other people's data refers to, so it answers
        // first; a local row cannot shadow it.
        let env = try environment(catalog: Catalog(products: [wellerProduct]))
        var entry = CustomCatalogEntry(
            distillery: "Somewhere else", brand: "Not Weller",
            expression: "", classType: .rye)
        entry.id = "weller-12"
        _ = try env.bottles.addCustom(product: entry, bottle: Bottle())

        XCTAssertEqual(env.identity("weller-12")?.distillery, "Buffalo Trace")
    }

    // MARK: - What the screens actually call

    func testNameFallsBackAllTheWayToSomethingPrintable() throws {
        let env = try environment(catalog: Catalog(products: [wellerProduct]))

        var catalogued = Bottle()
        catalogued.catalogProductId = "weller-12"
        XCTAssertTrue(env.name(for: catalogued).contains("Weller"))

        var typed = Bottle()
        typed.customName = "The one from Dave"
        XCTAssertEqual(env.name(for: typed), "The one from Dave")

        // No id, no name. A row in the collection with an empty label reads
        // as a broken app, so there is always a word.
        XCTAssertEqual(env.name(for: Bottle()), "Untitled bottle")
    }

    func testProductIsCatalogueOnlyAndScreensMustSurviveThat() throws {
        // `identity` answers for both kinds; `product` answers only for the
        // bundled catalogue, because only a catalogue product carries ABV,
        // allocation and provenance. A screen that assumes a bottle with a
        // name also has a product will show nothing for every typed-in
        // bottle, which is half of some people's shelves.
        let env = try environment()
        let entry = CustomCatalogEntry(
            distillery: "Home", brand: "Home", expression: "", classType: .bourbon)
        let saved = try env.bottles.addCustom(product: entry, bottle: Bottle())

        XCTAssertNotNil(env.identity(saved.bottle.catalogProductId ?? ""))
        XCTAssertNil(env.product(for: saved.bottle))
    }

    func testDistilleryAndClassResolveForBothKinds() throws {
        let env = try environment(catalog: Catalog(products: [wellerProduct]))

        var catalogued = Bottle()
        catalogued.catalogProductId = "weller-12"
        XCTAssertEqual(env.distillery(for: catalogued), "Buffalo Trace")
        XCTAssertEqual(env.classType(for: catalogued), .bourbon)

        let entry = CustomCatalogEntry(
            distillery: "Willett", brand: "Willett", expression: "", classType: .rye)
        let saved = try env.bottles.addCustom(product: entry, bottle: Bottle())
        XCTAssertEqual(env.distillery(for: saved.bottle), "Willett")
        XCTAssertEqual(env.classType(for: saved.bottle), .rye)
    }

    func testHistoryCountsBottlesYouHaveFinished() throws {
        // The search boost is about what you have KNOWN, not what you still
        // have. A bottle you killed last year is still a reason to rank its
        // product above a stranger's.
        let env = try environment(catalog: Catalog(products: [wellerProduct]))
        var bottle = Bottle()
        bottle.catalogProductId = "weller-12"
        let saved = try env.bottles.add(bottle)
        try env.bottles.finish(bottleId: saved.id)

        XCTAssertTrue(env.historyProductIds().contains("weller-12"))
    }

    // MARK: - The whole path, through the real resolver

    func testATypedInBottleAnswersTheShelfCheck() throws {
        // The same assertion `FeatureFlowTests` makes, but driven through
        // `env.identity` instead of a resolver written inside the test. That
        // difference is the point: a test that supplies its own resolver
        // proves the engine, not the app.
        let env = try environment()
        let entry = CustomCatalogEntry(
            distillery: "Jefferson's", brand: "Jefferson's",
            expression: "Ocean", classType: .bourbon)
        let saved = try env.bottles.addCustom(product: entry, bottle: Bottle())

        let holdings = try env.bottles.holdings { env.identity($0) }
        let records = try env.tastings.records { env.identity($0) }
        let verdict = ShelfCheck.evaluate(
            product: env.identity(saved.product.id)!,
            holdings: holdings,
            tastings: records)

        XCTAssertEqual(verdict.headline, .onYourShelf)
        XCTAssertEqual(verdict.onShelf.count, 1)
    }

    func testAFinishedBottleReadsHadItBeforeNotOnYourShelf() throws {
        // The distinction the whole app exists for, driven end to end. The
        // engine decides it, but only from the `isFinished` flag `holdings`
        // carries across -- drop that on the floor in the repository and the
        // app confidently tells somebody in a shop they already have a
        // bottle they drank last year.
        let env = try environment(catalog: Catalog(products: [wellerProduct]))
        var bottle = Bottle()
        bottle.catalogProductId = "weller-12"
        let saved = try env.bottles.add(bottle)
        try env.bottles.finish(bottleId: saved.id)

        let holdings = try env.bottles.holdings { env.identity($0) }
        let verdict = ShelfCheck.evaluate(
            product: env.identity("weller-12")!,
            holdings: holdings,
            tastings: try env.tastings.records { env.identity($0) })

        XCTAssertEqual(verdict.headline, .hadItBefore)
        XCTAssertTrue(verdict.onShelf.isEmpty)
    }

    func testACatalogueBottleAnswersTheShelfCheck() throws {
        let env = try environment(catalog: Catalog(products: [wellerProduct]))
        var bottle = Bottle()
        bottle.catalogProductId = "weller-12"
        _ = try env.bottles.add(bottle)

        let holdings = try env.bottles.holdings { env.identity($0) }
        let records = try env.tastings.records { env.identity($0) }
        let verdict = ShelfCheck.evaluate(
            product: env.identity("weller-12")!, holdings: holdings, tastings: records)

        XCTAssertEqual(verdict.headline, .onYourShelf)
    }
}
