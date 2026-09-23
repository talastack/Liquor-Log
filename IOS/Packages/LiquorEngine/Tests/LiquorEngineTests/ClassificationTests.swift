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

    /// 27 CFR 5.88 does not limit bonding to whiskey; Laird's bonded apple
    /// brandy is on shelves.
    func testBottledInBondBrandyIsAllowed() {
        XCTAssertTrue(issues(.brandy, abv: 50.0, age: 4, bond: true).isEmpty)
    }

    func testStraightRequiresTwoYears() {
        let found = issues(.straightRye, abv: 50.0, age: 1)
        XCTAssertTrue(found.contains { $0.rule == "straight.minimumAge" })
    }

    /// A one-year bourbon is legal; it just cannot call itself straight.
    func testNonStraightBourbonHasNoMinimumAge() {
        XCTAssertTrue(issues(.bourbon, abv: 45.0, age: 1).isEmpty)
    }

    /// Corrected: imported whisky is NOT exempt. Scotch, Irish, Canadian and
    /// Japanese whisky each carry a 40% floor under their own rules, so the
    /// minimum is the same wherever the bottle came from. Exempting them was
    /// caution rather than accuracy.
    func testEveryWhiskyCarriesTheFortyPercentFloor() {
        for type in ClassType.allCases where type.family == .whiskey {
            XCTAssertEqual(
                type.minimumBottlingStrength?.percent, 40,
                "\(type) should carry the 40% floor")
        }
    }

    /// The real exception is the sugar-bearing classes. A 16% amaro is not
    /// under-strength, and rejecting it would be the app being wrong loudly.
    func testLiqueursHaveNoStrengthFloor() {
        XCTAssertNil(ClassType.liqueur.minimumBottlingStrength)
        XCTAssertNil(ClassType.amaro.minimumBottlingStrength)
        XCTAssertNil(ClassType.vermouth.minimumBottlingStrength)
        XCTAssertNil(ClassType.maltBeverage.minimumBottlingStrength)

        let amaro = Classification.validate(
            classType: .amaro, abv: ABV(percent: 16), statedAgeYears: nil,
            isBottledInBond: false, volumeMilliliters: 750)
        XCTAssertTrue(amaro.isEmpty)
    }

    func testFortifiedWineAndEastAsianCarryNoSpiritsFloor() {
        // A 20% port is a port. A 15% sake is a sake. Holding either to the
        // 40% American spirits floor would flag a correct bottle, which is
        // the failure this whole family rule exists to avoid.
        for type in [ClassType.port, .sherry, .madeira, .soju, .shochu, .sake, .baijiu] {
            XCTAssertNil(type.minimumBottlingStrength, "\(type) should carry no floor")
        }
        XCTAssertTrue(issues(.port, abv: 20.0).isEmpty)
        XCTAssertTrue(issues(.sake, abv: 15.5).isEmpty)
        XCTAssertTrue(issues(.soju, abv: 16.9).isEmpty)

        XCTAssertEqual(ClassType.port.family, .fortified)
        XCTAssertEqual(ClassType.sake.family, .eastAsian)
    }

    func testCachacaAndGrappaSetTheirOwnFloors() {
        // Both sit under their family's 40% by their own definitions:
        // cachaca is 38% to 48% by TTB, grappa 37.5% in the EU. Using the
        // family figure would reject bottles that are exactly what they say.
        XCTAssertEqual(ClassType.cachaca.minimumBottlingStrength?.percent, 38)
        XCTAssertEqual(ClassType.grappa.minimumBottlingStrength?.percent, 37.5)
        XCTAssertTrue(issues(.cachaca, abv: 39.0).isEmpty)
        XCTAssertFalse(issues(.cachaca, abv: 37.0).isEmpty)

        // Still shelved with their relatives.
        XCTAssertEqual(ClassType.cachaca.family, .rum)
        XCTAssertEqual(ClassType.grappa.family, .brandy)
    }

    func testWorldWhiskyIsWhiskeyAndHeldToForty() {
        XCTAssertEqual(ClassType.worldWhisky.family, .whiskey)
        XCTAssertEqual(ClassType.worldWhisky.minimumBottlingStrength?.percent, 40)
    }

    func testFlavouredRumHasItsOwnFloorBelowItsFamily() {
        // Captain Morgan is 35%. Held to rum's 40% it reads as an
        // under-strength rum; it is nothing of the kind, it is a flavoured
        // rum, and TTB bottles those at 30%.
        XCTAssertEqual(ClassType.flavoredRum.minimumBottlingStrength?.percent, 30)
        XCTAssertEqual(ClassType.rum.minimumBottlingStrength?.percent, 40)
        XCTAssertEqual(ClassType.flavoredRum.family, .rum, "still a rum on the shelf")

        XCTAssertTrue(issues(.flavoredRum, abv: 35.0).isEmpty)
        XCTAssertFalse(issues(.flavoredRum, abv: 25.0).isEmpty, "below even its own floor")
    }

    func testCiderAndSeltzerAreNotHeldToASpiritsFloor() {
        // A 5% cider is not an under-strength spirit; it is a cider. The
        // 40% floor is an American *spirits* rule, and applying it here
        // would have the app flag every can on the shelf.
        XCTAssertNil(ClassType.hardCider.minimumBottlingStrength)
        XCTAssertNil(ClassType.hardSeltzer.minimumBottlingStrength)

        let cider = issues(.hardCider, abv: 5.0, volume: 355)
        XCTAssertTrue(cider.isEmpty, "a 5% cider in a 355 ml can is ordinary")

        let seltzer = issues(.hardSeltzer, abv: 5.0, volume: 355)
        XCTAssertTrue(seltzer.isEmpty, "so is a White Claw")
    }

    func testCiderAndSeltzerAreTheirOwnFamilies() {
        // Not beer. Cider is a wine for tax purposes and seltzer is not one
        // thing at all, so filing either under Beer would put a wrong word
        // on a filter chip somebody uses to find their own shelf.
        XCTAssertEqual(ClassType.hardCider.family, .cider)
        XCTAssertEqual(ClassType.hardSeltzer.family, .seltzer)
        XCTAssertEqual(ClassType.maltBeverage.family, .beer)
    }

    func testGinAndTequilaAreHeldToFortyToo() {
        XCTAssertEqual(ClassType.londonDryGin.minimumBottlingStrength?.percent, 40)
        XCTAssertEqual(ClassType.tequilaBlanco.minimumBottlingStrength?.percent, 40)
        XCTAssertEqual(ClassType.rum.minimumBottlingStrength?.percent, 40)
    }

    func testEveryClassHasALabelAndAFamily() {
        for type in ClassType.allCases {
            XCTAssertFalse(type.label.isEmpty, "\(type) has no label")
            XCTAssertFalse(type.label == type.rawValue, "\(type) label is a storage key")
        }
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

/// Tennessee whiskey meets the straight bourbon requirements and then adds the
/// Lincoln County Process. Treating it as not-straight said that a bonded
/// Tennessee whiskey cannot exist, which two bottles on the shelf contradict.
final class TennesseeWhiskeyTests: XCTestCase {

    func testTennesseeWhiskeyIsStraight() {
        XCTAssertTrue(ClassType.tennesseeWhiskey.isStraight)
    }

    /// Jack Daniel's Bonded and George Dickel Bottled in Bond are both real.
    func testABondedTennesseeWhiskeyIsValid() {
        let issues = Classification.validate(
            classType: .tennesseeWhiskey,
            abv: ABV(percent: 50),
            statedAgeYears: 4,
            isBottledInBond: true,
            volumeMilliliters: nil)
        XCTAssertTrue(
            issues.isEmpty,
            "expected no issues, got \(issues.map(\.rule))")
    }

    /// Straight still means straight: the four-year floor for bond applies here
    /// exactly as it does to bourbon.
    func testABondedTennesseeWhiskeyStillNeedsFourYears() {
        let issues = Classification.validate(
            classType: .tennesseeWhiskey,
            abv: ABV(percent: 50),
            statedAgeYears: 2,
            isBottledInBond: true,
            volumeMilliliters: nil)
        XCTAssertTrue(issues.contains { $0.rule == "bond.minimumAge" })
    }
}
