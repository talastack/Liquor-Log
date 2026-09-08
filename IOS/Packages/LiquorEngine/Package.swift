// swift-tools-version: 5.9
import PackageDescription

// LiquorEngine has NO dependencies, and that is a constraint rather than an
// accident. It is the code most likely to be wrong in a way that matters -- a
// pour count, a proof, an age -- so it stays testable with `swift test` on any
// machine, including Windows and a free Linux CI runner. No Mac, no simulator,
// no database fixture.
//
// If something in here seems to need a database or a network, it needs its
// inputs passed in instead.
let package = Package(
    name: "LiquorEngine",
    platforms: [.iOS(.v17), .macOS(.v13)],
    products: [
        .library(name: "LiquorEngine", targets: ["LiquorEngine"])
    ],
    targets: [
        .target(name: "LiquorEngine"),
        .testTarget(name: "LiquorEngineTests", dependencies: ["LiquorEngine"])
    ]
)
