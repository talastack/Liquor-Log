import XCTest
@testable import LiquorEngine

/// These assert federal regulation, not preference, which is what makes them
/// worth having in CI.
final class ClassificationTests: XCTestCase {

    private func issues(
        _ classType: ClassType,
        abv: Double?,
        age: Int? = nil,
        bond: Bool = false,
        volume: Double? = 750
    ) -> [Classification.Issue] {
        Classification.validate(
            classType: classType,
            abv: abv.map { ABV(percent: $0) },
            statedAgeYears: age,
            isBottledInBond: bond,
            volumeMilliliters: volume
        )
    }

    func testATypicalBourbonPasses() {
        XCTAssertTrue(issues(.kentuckyStraightBourbon, abv: 47.0, age: 8).isEmpty)
    }

    /// Barrel proof bottlings legitimately exceed 62.5% -- the 125-proof cap is
    /// an entry proof, and whiskey gains strength in a hot warehouse. Validating
    /// bottled ABV against it would reject real whiskey.
    func testBarrelProofAboveSixtyTwoPointFiveIsValid() {
        XCTAssertTrue(issues(.kentuckyStraightBourbon, abv: 72.4, age: 15).isEmpty)
    }

    func testBourbonBelowEightyProofIsRejected() {
        let found = issues(.straightBourbon, abv: 38.0, age: 4)
        XCTAssertTrue(found.contains { $0.rule == "abv.americanMinimum" })
    }

    func testBottledInBondMustBeExactlyOneHundredProof() {
        XCTAssertTrue(issues(.kentuckyStraightBourbon, abv: 50.0, age: 5, bond: true).isEmpty)

        let wrong = issues(.kentuckyStraightBourbon, abv: 47.0, age: 5, bond: true)
        XCTAssertTrue(wrong.contains { $0.rule == "bond.proof" })
    }

    func testBottledInBondRequiresFourYears() {
        let found = issues(.kentuckyStraightBourbon, abv: 50.0, age: 3, bond: true)
        XCTAssertTrue(found.contains { $0.rule == "bond.minimumAge" })
    }

    func testBottledInBondRequiresAStraightDesignation() {
        let found = issues(.bourbon, abv: 50.0, age: 5, bond: true)
        XCTAssertTrue(found.contains { $0.rule == "bond.requiresStraight" })
    }

    func testStraightRequiresTwoYears() {
        let found = issues(.straightRye, abv: 50.0, age: 1)
        XCTAssertTrue(found.contains { $0.rule == "straight.minimumAge" })
    }

    /// A one-year bourbon is legal; it just cannot call itself straight.
    func testNonStraightBourbonHasNoMinimumAge() {
        XCTAssertTrue(issues(.bourbon, abv: 45.0, age: 1).isEmpty)
    }

    /// Scotch and Irish are not bound by the American 40% floor in our rules.
    func testImportedClassesSkipTheAmericanMinimum() {
        XCTAssertFalse(ClassType.singleMaltScotch.hasAmericanMinimumStrength)
        XCTAssertTrue(ClassType.straightBourbon.hasAmericanMinimumStrength)
    }

    func testMissingABVIsAnIssue() {
        XCTAssertTrue(issues(.bourbon, abv: nil).contains { $0.rule == "abv.missing" })
    }

    func testNonStandardFillIsRejected() {
        let found = issues(.bourbon, abv: 45.0, volume: 733)
        XCTAssertTrue(found.contains { $0.rule == "volume.standardOfFill" })
    }

    func testBeerIsNotHeldToWhiskeyRules() {
        XCTAssertTrue(issues(.maltBeverage, abv: 6.2, volume: 355).isEmpty)
    }
}
