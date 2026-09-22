import XCTest
import Foundation
@testable import LiquorEngine

/// The parity test.
///
/// `shared/vectors/pour-math.json` is read by this suite and by the Kotlin
/// engine's `GoldenVectorsTest`. Neither implementation owns the truth; the
/// file does. Two separate implementations of the same rounding rule drift,
/// and the drift is invisible in the worst way: a 750 ml bottle reads 17
/// pours on a phone and 16 on a tablet, and both look plausible.
///
/// It reads the real file rather than a copy, for the same reason the Kotlin
/// side does: a transcribed copy is a second thing to keep in step, which is
/// the problem being solved.
///
/// The path comes from `#filePath` because a Swift package test has no
/// working directory worth relying on and no resource bundle here -- adding
/// one would mean copying the file, which is the thing not to do.
final class GoldenVectorsTests: XCTestCase {

    /// The repository root, walked up from this file.
    ///
    /// .../IOS/Packages/LiquorEngine/Tests/LiquorEngineTests/<this file>
    private static let repositoryRoot: URL = {
        var url = URL(fileURLWithPath: #filePath)
        for _ in 0..<6 { url.deleteLastPathComponent() }
        return url
    }()

    private struct Vectors {
        let pourSizeMilliliters: Double
        let cases: [[String: Any]]
    }

    private func loadVectors() throws -> Vectors {
        let url = Self.repositoryRoot
            .appendingPathComponent("shared")
            .appendingPathComponent("vectors")
            .appendingPathComponent("pour-math.json")

        guard FileManager.default.fileExists(atPath: url.path) else {
            XCTFail("the vectors are missing at \(url.path)")
            throw CocoaError(.fileNoSuchFile)
        }

        let data = try Data(contentsOf: url)
        let object = try JSONSerialization.jsonObject(with: data)
        guard let root = object as? [String: Any],
              let size = root["pourSizeMilliliters"] as? Double,
              let cases = root["cases"] as? [[String: Any]] else {
            XCTFail("the vectors are not the shape this test expects")
            throw CocoaError(.propertyListReadCorrupt)
        }
        return Vectors(pourSizeMilliliters: size, cases: cases)
    }

    func testPourSizeMatchesTheOneTheVectorsWereComputedWith() throws {
        let vectors = try loadVectors()
        XCTAssertEqual(
            PourSize.standard.milliliters,
            vectors.pourSizeMilliliters,
            accuracy: 1e-9,
            "every case below is computed from this constant, so it is checked first")
    }

    func testEveryGoldenCaseHolds() throws {
        let vectors = try loadVectors()
        XCTAssertGreaterThanOrEqual(
            vectors.cases.count, 16,
            "the vectors were emptied rather than fixed")

        for row in vectors.cases {
            guard let capacity = row["capacity"] as? Double,
                  let poured = row["poured"] as? Double,
                  let expectedRemaining = row["remainingMilliliters"] as? Double,
                  let expectedTotal = row["totalPours"] as? Int,
                  let expectedLeft = row["remainingPours"] as? Int else {
                XCTFail("a case is missing a field: \(row)")
                continue
            }

            // A JSON null arrives as NSNull, which is not nil and is not a
            // Double. Read through it rather than around it: the absent
            // reading is the case being tested.
            let startingFrom = row["startingFrom"] as? Double

            let status = PourMath.status(
                capacityMilliliters: capacity,
                pouredMilliliters: poured,
                startingMilliliters: startingFrom)

            // The reason travels with the case, so a failure says what broke
            // rather than only which numbers disagreed.
            let why = row["_why"] as? String ?? ""
            let where_ = "capacity=\(capacity) poured=\(poured) "
                + "startingFrom=\(String(describing: startingFrom)) -- \(why)"

            XCTAssertEqual(
                status.remainingMilliliters, expectedRemaining,
                accuracy: 1e-6, where_)
            XCTAssertEqual(status.totalPours, expectedTotal, where_)
            XCTAssertEqual(status.remainingPours, expectedLeft, where_)
        }
    }
}
