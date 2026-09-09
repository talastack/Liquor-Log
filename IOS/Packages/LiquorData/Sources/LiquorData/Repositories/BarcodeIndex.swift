import Foundation
import GRDB
import LiquorEngine

/// Your own barcode lookup, built from bottles you have scanned.
///
/// **There is no UPC database behind this, and there is not meant to be.**
/// Commercial ones are paid and scraped ones are a terms-of-service problem,
/// both excluded from this project on day one. So the lookup table is the
/// user's own shelf: scan a bottle once, say what it is, and it is recognised
/// forever after. Offline, free, and better the more the app is used.
///
/// **A barcode is a shortcut, never an identity.** The central finding behind
/// this whole product is that a UPC identifies a SKU and cannot identify a
/// barrel — a store pick usually carries the base product's code, sometimes a
/// generic "barrel select" one, and sometimes a sticker over the original. So a
/// scan resolves to a PRODUCT, and the shelf check decides from there whether
/// that means "you own this" or only "you have this line". Never the barrel.
public struct BarcodeIndex: Sendable {
    private let db: AppDatabase

    public init(_ db: AppDatabase) { self.db = db }

    /// What a scanned code resolves to, if anything.
    public struct Match: Sendable, Hashable {
        /// The catalogue product, when the remembered bottle had one.
        public let catalogProductId: String?
        /// A bottle carrying this code, for a name to show.
        public let bottleId: String
        public let bottleName: String?
        /// How many of your bottles carry this code.
        ///
        /// More than one is NORMAL and is the point: three Elijah Craig Barrel
        /// Proofs share a UPC and are three different whiskeys. It is the
        /// clearest possible evidence that a barcode cannot identify a barrel.
        public let bottleCount: Int

        public var isAmbiguous: Bool { bottleCount > 1 }
    }

    /// Looks a code up against bottles you already own or owned.
    ///
    /// Finished bottles count. A barcode you scanned two years ago on a bottle
    /// you have since killed still tells the app what the product is, and that
    /// is exactly the "did I have this before?" the shelf check answers.
    public func match(_ code: String) throws -> Match? {
        let trimmed = normalise(code)
        guard !trimmed.isEmpty else { return nil }

        return try db.queue.read { db in
            let bottles = try Bottle
                .live()
                .filter(Column("barcode") == trimmed)
                .order(Column("created_at").desc)
                .fetchAll(db)

            guard let newest = bottles.first else { return nil }
            return Match(
                catalogProductId: newest.catalogProductId,
                bottleId: newest.id,
                bottleName: newest.customName,
                bottleCount: bottles.count)
        }
    }

    /// Remembers a code against a bottle.
    ///
    /// Called after somebody confirms what a scan was, which is what turns one
    /// correction into every future scan of that product being instant.
    public func remember(_ code: String, forBottleId bottleId: String) throws {
        let trimmed = normalise(code)
        guard !trimmed.isEmpty else { return }

        try db.queue.write { db in
            guard var bottle = try Bottle.filter(key: bottleId).fetchOne(db) else { return }
            bottle.barcode = trimmed
            try bottle.saveLocal(db)
        }
    }

    /// Every code you have taught it, for a settings screen or an export.
    public func knownCodes() throws -> [String] {
        try db.queue.read { db in
            try String.fetchAll(
                db,
                sql: """
                    select distinct barcode from bottles
                     where barcode is not null and deleted_at is null
                     order by barcode
                    """)
        }
    }

    /// Digits only, and never re-encoded.
    ///
    /// Scanners return UPC-A and EAN-13 for the same physical barcode, and the
    /// difference is a leading zero: a US bottle reads as 12 digits from one
    /// device and 13 from another. Padding to 13 makes both spellings of one
    /// barcode agree, which is the difference between a bottle being recognised
    /// and not.
    func normalise(_ code: String) -> String {
        let digits = code.filter(\.isNumber)
        guard digits.count == 12 else { return digits }
        return "0" + digits
    }
}
