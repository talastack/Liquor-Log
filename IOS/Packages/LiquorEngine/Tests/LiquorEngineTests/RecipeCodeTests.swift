import XCTest
@testable import LiquorEngine

final class RecipeCodeTests: XCTestCase {

    /// The code named in the original notes.
    func testOESQDecodes() {
        let code = RecipeCode("OESQ")
        XCTAssertNotNil(code)
        XCTAssertEqual(code?.mashbill, .e)
        XCTAssertEqual(code?.yeast, .q)
        XCTAssertEqual(code?.mashbill.ryePercent, 20)
        XCTAssertEqual(code?.yeast.character, "Floral essence")
    }

    func testOBSVDecodes() {
        let code = RecipeCode("OBSV")
        XCTAssertEqual(code?.mashbill, .b)
        XCTAssertEqual(code?.mashbill.ryePercent, 35)
        XCTAssertEqual(code?.yeast.character, "Delicate fruit")
    }

    func testMashbillsSumToOneHundred() {
        for mashbill in RecipeCode.Mashbill.allCases {
            let g = mashbill.grains
            XCTAssertEqual(g.corn + g.rye + g.maltedBarley, 100, "\(mashbill) does not sum to 100")
        }
    }

    func testExactlyTenCodesExist() {
        XCTAssertEqual(RecipeCode.all.count, 10)
        XCTAssertEqual(RecipeCode.validCodes.count, 10)
    }

    func testEveryValidCodeRoundTrips() {
        for code in RecipeCode.all {
            XCTAssertEqual(RecipeCode(code.code), code, "\(code.code) did not round-trip")
        }
    }

    func testParsingIsCaseAndWhitespaceInsensitive() {
        XCTAssertEqual(RecipeCode("  oesq "), RecipeCode("OESQ"))
    }

    /// Decoding three letters and inventing the fourth is worse than saying
    /// nothing, because the user cannot tell which happened.
    func testInvalidCodesReturnNilRatherThanGuessing() {
        XCTAssertNil(RecipeCode("OASV"), "A is not a mashbill")
        XCTAssertNil(RecipeCode("OESZ"), "Z is not a yeast")
        XCTAssertNil(RecipeCode("XESQ"), "must begin with O")
        XCTAssertNil(RecipeCode("OEXQ"), "third letter is always S")
        XCTAssertNil(RecipeCode("OES"))
        XCTAssertNil(RecipeCode(""))
        XCTAssertNil(RecipeCode("OESQQ"))
    }
}
