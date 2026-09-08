// swift-tools-version: 5.9
import PackageDescription

// LiquorData is persistence and sync. It depends on GRDB and on LiquorEngine,
// and on nothing else.
//
// GRDB over SwiftData, for two reasons that outweigh SwiftData being the more
// idiomatic choice:
//
//   1. The local schema is HALF OF A SYNC CONTRACT. It has to mirror Postgres
//      column for column, including deleted_at, dirty and integer-millisecond
//      timestamps. SwiftData's store is opaque, so "mirror this exact schema"
//      is something you approximate rather than state.
//   2. Migrations are explicit SQL. With a shipped app syncing to a shared
//      Postgres schema, a migration that does something surprising is
//      expensive.
//
// The cost is boilerplate per model. SyncableRecord absorbs most of it.
//
// NOTE: these tests do NOT run on Linux. GRDB calls sqlite3_snapshot_* and
// Ubuntu's libsqlite3 is not built with SQLITE_ENABLE_SNAPSHOT, so the package
// compiles there and then fails to link. macOS ships a SQLite that has it.
let package = Package(
    name: "LiquorData",
    platforms: [.iOS(.v17), .macOS(.v13)],
    products: [
        .library(name: "LiquorData", targets: ["LiquorData"])
    ],
    dependencies: [
        .package(url: "https://github.com/groue/GRDB.swift.git", from: "6.29.0"),
        .package(path: "../LiquorEngine")
    ],
    targets: [
        .target(
            name: "LiquorData",
            dependencies: [
                .product(name: "GRDB", package: "GRDB.swift"),
                "LiquorEngine"
            ]
        ),
        .testTarget(name: "LiquorDataTests", dependencies: ["LiquorData"])
    ]
)
