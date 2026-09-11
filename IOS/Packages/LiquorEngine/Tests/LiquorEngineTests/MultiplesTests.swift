import XCTest
@testable import LiquorEngine

/// Same product, same barrel, same batch is the same thing. Anything else is
/// a different whiskey with one name.
final class MultiplesTests: XCTestCase {

    func testThreeOfOnePickAreNumbered() {
        let places = Multiples.places(in: [
            Multiples.Bottle(id: "a", productKey: "fr-sb", barrel: "42-3C"),
            Multiples.Bottle(id: "b", productKey: "fr-sb", barrel: "42-3C"),
            Multiples.Bottle(id: "c", productKey: "fr-sb", barrel: "42-3c"),   // case does not split
        ])
        XCTAssertEqual(places["a"]?.label, "1 of 3")
        XCTAssertEqual(places["c"]?.label, "3 of 3")
        XCTAssertEqual(places["b"]?.siblings, ["a", "c"])
    }

    func testDifferentBatchesAreNotMultiples() {
        let places = Multiples.places(in: [
            Multiples.Bottle(id: "a", productKey: "ecbp", batch: "B523"),
            Multiples.Bottle(id: "b", productKey: "ecbp", batch: "A124"),
        ])
        XCTAssertNil(places["a"]?.label)
        XCTAssertFalse(places["b"]?.isOneOfSeveral ?? true)
    }

    func testABarrelAndNoBarrelAreNotTheSame() {
        let places = Multiples.places(in: [
            Multiples.Bottle(id: "a", productKey: "fr-sb", barrel: "42-3C"),
            Multiples.Bottle(id: "b", productKey: "fr-sb"),
        ])
        XCTAssertEqual(places["a"]?.count, 1)
        XCTAssertEqual(places["b"]?.count, 1)
    }

    func testFinishedBottlesNeitherCountNorAppear() {
        let places = Multiples.places(in: [
            Multiples.Bottle(id: "a", productKey: "weller"),
            Multiples.Bottle(id: "b", productKey: "weller", isFinished: true),
            Multiples.Bottle(id: "c", productKey: "weller", isFinished: true),
        ])
        XCTAssertNil(places["a"]?.label)
        XCTAssertNil(places["b"])
    }

    func testTwoBackupsOfAStandardRelease() {
        let places = Multiples.places(in: [
            Multiples.Bottle(id: "a", productKey: "weller"),
            Multiples.Bottle(id: "b", productKey: "weller"),
        ])
        XCTAssertEqual(places["a"]?.label, "1 of 2")
        XCTAssertEqual(places["b"]?.label, "2 of 2")
    }
}
