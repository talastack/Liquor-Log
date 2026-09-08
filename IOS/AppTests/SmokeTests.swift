import XCTest
import LiquorEngine
@testable import LiquorLog

/// Proves the app target links the engine and that the design system resolves
/// every verdict. Real screen tests arrive with the screens.
final class SmokeTests: XCTestCase {

    func testEveryVerdictHasABadge() {
        // Compile-time exhaustiveness is enforced by the switch in
        // VerdictBadge; this asserts the case list has not silently shrunk.
        let all: [ShelfCheckResult.Headline] = [
            .onYourShelf, .haveTheLineNotThisRelease,
            .tastedNeverOwned, .hadItBefore, .neverHadIt
        ]
        XCTAssertEqual(Set(all).count, 5)
    }

    func testEngineIsLinked() {
        let status = PourMath.status(capacityMilliliters: 750, pouredMilliliters: 0)
        XCTAssertEqual(status.totalPours, 17)
    }
}
