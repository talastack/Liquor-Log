import XCTest
@testable import LiquorEngine

final class CatalogTests: XCTestCase {

    private let json = """
    {
      "version": 1,
      "products": [
        { "id": "ec-small-batch", "distillery": "Heaven Hill", "brand": "Elijah Craig",
          "expression": "Small Batch", "class_type": "kentuckyStraightBourbon",
          "production_type": "smallBatch", "abv": 47.0, "source": "Producer label" },
        { "id": "ec-barrel-proof", "distillery": "Heaven Hill", "brand": "Elijah Craig",
          "expression": "Barrel Proof", "class_type": "kentuckyStraightBourbon",
          "production_type": "smallBatch", "is_barrel_proof": true, "abv": null,
          "source": "Producer label" },
        { "id": "four-roses-single-barrel", "distillery": "Four Roses", "brand": "Four Roses",
          "expression": "Single Barrel", "class_type": "kentuckyStraightBourbon",
          "production_type": "singleBarrel", "abv": 50.0, "recipe_code": "OBSV",
          "source": "Producer label" },
        { "id": "weller-antique-107", "distillery": "Buffalo Trace", "brand": "W L Weller",
          "expression": "Antique 107", "class_type": "kentuckyStraightBourbon",
          "abv": 53.5, "mashbill_key": "wheated", "source": "Producer label" }
      ]
    }
    """

    private func catalog() throws -> Catalog {
        try Catalog.decode(from: Data(json.utf8))
    }

    // MARK: - Decoding

    func testDecodesWithSensibleDefaults() throws {
        let c = try catalog()
        XCTAssertEqual(c.products.count, 4)

        let weller = try XCTUnwrap(c.product("weller-antique-107"))
        XCTAssertEqual(weller.productionType, .unspecified, "omitted means unspecified")
        XCTAssertFalse(weller.isBarrelProof)
        XCTAssertFalse(weller.verified, "nothing is verified until it is checked")
    }

    /// The strength of a barrel-proof release changes every batch, so a catalog
    /// claiming one number would be wrong for almost every bottle on a shelf.
    func testBarrelProofCarriesNoStrength() throws {
        let bp = try XCTUnwrap(try catalog().product("ec-barrel-proof"))
        XCTAssertNil(bp.abv)
        XCTAssertEqual(bp.strengthDescription, "Varies by batch")
    }

    func testStrengthShowsBothUnits() throws {
        let sb = try XCTUnwrap(try catalog().product("ec-small-batch"))
        XCTAssertEqual(sb.strengthDescription, "47.0% ABV · 94.0 proof")
    }

    func testRecipeCodeDecodesThroughTheEngine() throws {
        let fr = try XCTUnwrap(try catalog().product("four-roses-single-barrel"))
        XCTAssertEqual(fr.code?.mashbill, .b)
        XCTAssertEqual(fr.code?.yeast, .v)
    }

    // MARK: - Search and relatedness

    func testSearchCandidatesCarryTheHistoryBoost() throws {
        let candidates = try catalog().searchCandidates(history: ["ec-barrel-proof"])
        let boosted = candidates.filter(\.isInYourHistory).map(\.product.productId)
        XCTAssertEqual(boosted, ["ec-barrel-proof"])
    }

    func testSearchFindsAProductByAbbreviatedTyping() throws {
        let hits = BottleSearch.search(
            query: "eli cra bar", in: try catalog().searchCandidates())
        XCTAssertEqual(hits.first?.product.productId, "ec-barrel-proof")
    }

    /// The line-versus-release distinction, straight out of the catalog.
    func testTwoElijahCraigsAreDifferentProductsOnOneLine() throws {
        let c = try catalog()
        let sb = try XCTUnwrap(c.identity("ec-small-batch"))
        let bp = try XCTUnwrap(c.identity("ec-barrel-proof"))

        XCTAssertEqual(sb.lineKey, bp.lineKey, "same line")
        XCTAssertNotEqual(sb.productId, bp.productId, "different whiskey")
    }

    func testRelatedFindsTheLine() throws {
        let hits = try catalog().related(to: "ec-small-batch")
        XCTAssertEqual(hits.first?.product.productId, "ec-barrel-proof")
        XCTAssertEqual(hits.first?.reason, .sameLine)
    }

    func testRelatedToAnUnknownProductIsEmptyRatherThanEverything() throws {
        XCTAssertTrue(try catalog().related(to: "no-such-bottle").isEmpty)
    }

    // MARK: - Integrity

    func testACleanCatalogHasNoIssues() throws {
        XCTAssertTrue(try catalog().validate().isEmpty)
    }

    /// The engine's abv.missing rule must NOT fire on a barrel-proof row: a
    /// missing strength there is the correct value, not a fault.
    func testBarrelProofIsNotReportedAsMissingItsStrength() throws {
        let issues = try catalog().validate()
        XCTAssertFalse(issues.contains { $0.rule == "abv.missing" })
    }

    func testAFixedStrengthOnABarrelProofRowIsRejected() throws {
        let bad = """
        {"version":1,"products":[{"id":"x","distillery":"D","brand":"B",
          "class_type":"bourbon","is_barrel_proof":true,"abv":62.1,"source":"label"}]}
        """
        let issues = try Catalog.decode(from: Data(bad.utf8)).validate()
        XCTAssertTrue(issues.contains { $0.rule == "product.barrelProofHasNoFixedABV" })
    }

    func testASourcelessRowIsRejected() throws {
        let bad = """
        {"version":1,"products":[{"id":"x","distillery":"D","brand":"B",
          "class_type":"bourbon","abv":45.0}]}
        """
        let issues = try Catalog.decode(from: Data(bad.utf8)).validate()
        XCTAssertTrue(issues.contains { $0.rule == "product.hasSource" })
    }

    func testFederalRulesApplyToCatalogRows() throws {
        // Bonded is exactly 100 proof, and this row claims 94.
        let bad = """
        {"version":1,"products":[{"id":"x","distillery":"D","brand":"B",
          "class_type":"straightBourbon","is_bottled_in_bond":true,"abv":47.0,
          "stated_age_years":5,"source":"label"}]}
        """
        let issues = try Catalog.decode(from: Data(bad.utf8)).validate()
        XCTAssertTrue(issues.contains { $0.rule == "bond.proof" })
    }

    func testDuplicateIdsAreRejected() throws {
        let bad = """
        {"version":1,"products":[
          {"id":"x","distillery":"D","brand":"B","class_type":"bourbon","abv":45,"source":"l"},
          {"id":"x","distillery":"D","brand":"C","class_type":"bourbon","abv":45,"source":"l"}]}
        """
        let issues = try Catalog.decode(from: Data(bad.utf8)).validate()
        XCTAssertTrue(issues.contains { $0.rule == "product.unique" })
    }

    func testAnEmptyCatalogIsValidAndSearchable() {
        XCTAssertTrue(Catalog.empty.validate().isEmpty)
        XCTAssertTrue(BottleSearch.search(query: "anything", in: Catalog.empty.searchCandidates()).isEmpty)
    }
}
