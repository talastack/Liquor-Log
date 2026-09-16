import XCTest
@testable import LiquorEngine

/// The IBA list against a shelf: ready, nearly, or not tonight.
final class CocktailsTests: XCTestCase {

    private func bottle(
        _ id: String, _ name: String, _ classType: ClassType,
        open: Bool = true, rating: Int? = nil, fill: Double = 1
    ) -> Cocktails.Candidate {
        Cocktails.Candidate(id: id, name: name, classType: classType, isOpen: open, rating: rating, fillFraction: fill)
    }

    func testAnOldFashionedNeedsOnlyAnOpenBourbon() {
        let matches = Cocktails.matches(shelf: [bottle("ec", "Elijah Craig Small Batch", .kentuckyStraightBourbon)])
        let ready = matches.filter(\.isReady).map(\.recipe.id)
        XCTAssertTrue(ready.contains("old-fashioned"))
        XCTAssertTrue(ready.contains("whiskey-sour"))
        XCTAssertTrue(ready.contains("mint-julep"))
        XCTAssertFalse(ready.contains("manhattan"), "no vermouth")
    }

    func testOneBottleShortIsNearlyAndNamesTheSealedOne() {
        let shelf = [
            bottle("rye", "Rittenhouse Rye", .straightRye),
            bottle("v", "Carpano Antica Formula", .vermouth, open: false),
        ]
        let manhattan = Cocktails.matches(shelf: shelf).first { $0.recipe.id == "manhattan" }!
        XCTAssertFalse(manhattan.isReady)
        XCTAssertEqual(manhattan.missing.map(\.slot), [.sweetVermouth])
        XCTAssertEqual(manhattan.missing.first?.sealed?.id, "v", "the sealed bottle that would do")
    }

    func testTwoShortIsNotTonight() {
        let matches = Cocktails.matches(shelf: [bottle("g", "Tanqueray", .londonDryGin)])
        XCTAssertNil(matches.first { $0.recipe.id == "negroni" }, "no Campari, no vermouth")
        XCTAssertTrue(matches.contains { $0.recipe.id == "john-collins" && $0.isReady })
    }

    /// Sweet and dry vermouth are one class; the name settles it.
    func testVermouthIsSweetUnlessItSaysDry() {
        let shelf = [
            bottle("g", "Beefeater", .londonDryGin),
            bottle("d", "Noilly Prat Extra Dry", .vermouth),
            bottle("s", "Cocchi Vermouth di Torino", .vermouth),
        ]
        let martini = Cocktails.matches(shelf: shelf).first { $0.recipe.id == "dry-martini" }!
        XCTAssertEqual(martini.picks[.dryVermouth]?.id, "d")
        let negroni = Cocktails.matches(shelf: shelf).first { $0.recipe.id == "negroni" }
        XCTAssertEqual(negroni?.missing.map(\.slot), [.campari])
    }

    func testTheBestOpenBottleFillsASlot() {
        let shelf = [
            bottle("a", "Old Grand-Dad", .kentuckyStraightBourbon, rating: 6, fill: 0.9),
            bottle("b", "Weller 12", .kentuckyStraightBourbon, rating: 9, fill: 0.2),
            bottle("c", "Sealed Stagg", .kentuckyStraightBourbon, open: false, rating: 10),
        ]
        let julep = Cocktails.matches(shelf: shelf).first { $0.recipe.id == "mint-julep" }!
        XCTAssertEqual(julep.picks[.bourbon]?.id, "b", "highest rated open bottle, not the sealed one")
    }

    func testReadyComesBeforeNearlyAndEachIsAlphabetical() {
        let shelf = [
            bottle("t", "Fortaleza Blanco", .tequilaBlanco),
            bottle("c", "Cointreau", .liqueur, open: false),
        ]
        let matches = Cocktails.matches(shelf: shelf)
        let ids = matches.map(\.recipe.id)
        XCTAssertEqual(ids.prefix(2), ["paloma", "tommys-margarita"])
        XCTAssertEqual(ids.last, "margarita")
        XCTAssertFalse(matches.last!.isReady)
    }

    func testTheListIsTheIBAsAndEveryRecipeHasABottleSlot() {
        XCTAssertGreaterThanOrEqual(Cocktails.all.count, 25)
        XCTAssertEqual(Set(Cocktails.all.map(\.id)).count, Cocktails.all.count)
        for recipe in Cocktails.all {
            XCTAssertFalse(recipe.slots.isEmpty, recipe.name)
            XCTAssertFalse(recipe.method.isEmpty, recipe.name)
        }
    }

    func testIngredientsRead() {
        XCTAssertEqual(Cocktails.Ingredient.bottle(.rye, milliliters: 50).text, "50 ml rye")
        XCTAssertEqual(Cocktails.Ingredient.bottle(.islayScotch, milliliters: 7.5).text, "7.5 ml Islay Scotch")
    }
}
