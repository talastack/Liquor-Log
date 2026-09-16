import XCTest
@testable import LiquorEngine

/// The CRT registry, as the app reads it: a NOM to its plant, a brand to
/// its NOM. Fixture rows are real registry rows (September 2026).
final class TequilaRegistryTests: XCTestCase {

    private let registry = TequilaRegistry(producers: [
        .init(nom: "1139", company: "TEQUILA TAPATIO, S.A. DE C.V.",
              brands: ["EL TESORO", "EL TESORO DE DON FELIPE", "PARADISO", "TAPATIO"]),
        .init(nom: "1142", company: "LA MADRILEÑA, S.A. DE C.V.",
              brands: ["CORONA", "JARANA", "KIRKLAND SIGNATURE", "MAYORAZGO"]),
        .init(nom: "1609", company: "DIAGEO MEXICO OPERACIONES, S.A. DE C.V.", brands: ["CASAMIGOS"]),
        .init(nom: "1108", company: "JORGE SALLES CUERVO Y SUCESORES, S.A. DE C.V.", brands: ["EL TEQUILEÑO"]),
        .init(nom: "1143", company: "DESTILADORA DEL VALLE DE TEQUILA, S.A. DE C.V.", brands: ["TRADER JOE´S"]),
        .init(nom: "1577", company: "AGAVE CONQUISTA, S.A. DE C.V.", brands: ["1519"]),
    ])

    func testANOMReadsHoweverItIsTyped() {
        XCTAssertEqual(TequilaRegistry.normalise("NOM 1139"), "1139")
        XCTAssertEqual(TequilaRegistry.normalise("nom-1139"), "1139")
        XCTAssertEqual(TequilaRegistry.normalise("1139"), "1139")
        XCTAssertNil(TequilaRegistry.normalise("DSP-KY-113"))
        XCTAssertNil(TequilaRegistry.normalise("B523"))
        XCTAssertNil(TequilaRegistry.normalise("11390"))
    }

    func testANOMNamesItsPlant() {
        XCTAssertEqual(registry.producer(nom: "NOM 1139")?.company, "TEQUILA TAPATIO, S.A. DE C.V.")
        XCTAssertNil(registry.producer(nom: "1104"))
    }

    /// The question people actually have: who makes this?
    func testABrandFindsItsNOM() {
        let hits = registry.find(brand: "casamigos")
        XCTAssertEqual(hits.map(\.producer.nom), ["1609"])
        XCTAssertEqual(hits.first?.brand, "CASAMIGOS")
    }

    func testExactBeatsPrefixBeatsContains() {
        let hits = registry.find(brand: "el tesoro")
        XCTAssertEqual(hits.map(\.brand), ["EL TESORO", "EL TESORO DE DON FELIPE"])
        let partial = registry.find(brand: "signature")
        XCTAssertEqual(partial.map(\.producer.nom), ["1142"])
    }

    func testThreeLettersAreNotASearch() {
        XCTAssertTrue(registry.find(brand: "el").isEmpty)
        XCTAssertTrue(registry.find(brand: "OES").isEmpty, "the start of a Four Roses code")
    }

    /// Accents and the CRT's own apostrophe fold away, as everywhere else
    /// in the app.
    func testAccentsAndApostrophesFold() {
        XCTAssertEqual(registry.find(brand: "el tequileno").map(\.producer.nom), ["1108"])
        XCTAssertEqual(registry.find(brand: "Trader Joe's").map(\.producer.nom), ["1143"])
        XCTAssertEqual(registry.find(brand: "trader joe").map(\.producer.nom), ["1143"])
    }

    func testFourDigitsCanBeABrandAsWellAsANOM() {
        XCTAssertEqual(registry.exact(brand: "1519").map(\.producer.nom), ["1577"])
        XCTAssertTrue(registry.exact(brand: "1139").isEmpty)
    }

    func testDecodesTheShippedShape() throws {
        let json = """
        {"version": 1, "source": "x", "producers": [
          {"nom": "1493", "company": "TEQUILA LOS ABUELOS, S.A. DE C.V.", "brands": ["FORTALEZA", "LOS ABUELOS"]}
        ]}
        """
        let decoded = try TequilaRegistry.decode(from: Data(json.utf8))
        XCTAssertEqual(decoded.producer(nom: "1493")?.brands, ["FORTALEZA", "LOS ABUELOS"])
    }
}
