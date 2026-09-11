import Foundation
import GRDB

/// Everything, as one file, and everything back from it.
///
/// The CSV export is the trust signal the research asks for, and it is also
/// lossy: a spreadsheet cannot carry pours, fill readings, tasting notes or
/// the link from a tasting to its pour. This is the other half -- every row
/// of every table the person owns, tombstones included, plus the photos --
/// so a phone in a river costs nothing but the phone.
///
/// Restore MERGES. For every row in the file: absent locally, it is
/// inserted; present, the newer `updated_at` wins, the same rule sync uses.
/// A restore onto an empty phone is therefore a full restore and a restore
/// onto a full phone is a harmless no-op, and restoring the same file twice
/// changes nothing the second time. Restored rows are marked for push, so a
/// second device that syncs receives them.
public struct CollectionBackup: Sendable {

    public static let format = "liquorlog-backup"
    public static let version = 1

    public struct Counts: Hashable, Sendable {
        public var rows: [String: Int] = [:]
        public var photos = 0
        public var total: Int { rows.values.reduce(0, +) }
    }

    public struct Outcome: Hashable, Sendable {
        public var inserted = 0
        public var updated = 0
        public var unchanged = 0
        public var photosWritten = 0
    }

    /// What a file holds, before anything is written.
    public struct Preview: Hashable, Sendable {
        public let exportedAt: Date?
        public let counts: Counts
    }

    private let db: AppDatabase
    private let photos: BottlePhotoStore?

    public init(_ db: AppDatabase, photos: BottlePhotoStore? = nil) {
        self.db = db
        self.photos = photos
    }

    // MARK: - Writing

    public func write(to url: URL, now: Date = Date()) throws -> Counts {
        var counts = Counts()
        var tables: [String: [Any]] = [:]

        try db.queue.read { db in
            for table in Self.tables {
                let rows = try table.allRows(db)
                tables[table.name] = rows
                counts.rows[table.name] = rows.count
            }
        }

        var photoBlobs: [String: String] = [:]
        if let photos {
            let names = (tables[Bottle.databaseTableName] ?? [])
                .compactMap { ($0 as? [String: Any])?["photo_file"] as? String }
            for name in names {
                if let data = photos.data(for: name) {
                    photoBlobs[name] = data.base64EncodedString()
                }
            }
            counts.photos = photoBlobs.count
        }

        let document: [String: Any] = [
            "format": Self.format,
            "version": Self.version,
            "exported_at": Int64(now.timeIntervalSince1970 * 1000),
            "tables": tables,
            "photos": photoBlobs,
        ]
        let data = try JSONSerialization.data(withJSONObject: document, options: [.sortedKeys])
        try data.write(to: url, options: .atomic)
        return counts
    }

    // MARK: - Reading

    public enum BackupError: Error, LocalizedError, Sendable {
        case notABackup
        case newerThanThisApp(Int)

        public var errorDescription: String? {
            switch self {
            case .notABackup:
                return "That file is not a backup made by this app."
            case .newerThanThisApp(let version):
                return "That backup (version \(version)) was made by a newer version of the app."
            }
        }
    }

    public func preview(_ data: Data) throws -> Preview {
        let document = try parse(data)
        var counts = Counts()
        for table in Self.tables {
            counts.rows[table.name] = (document.tables[table.name] ?? []).count
        }
        counts.photos = document.photos.count
        return Preview(
            exportedAt: document.exportedAt.map { Date(timeIntervalSince1970: Double($0) / 1000) },
            counts: counts)
    }

    public func restore(_ data: Data) throws -> Outcome {
        let document = try parse(data)
        var outcome = Outcome()

        try db.queue.write { db in
            // Sync order: a referencing row is never written before the row
            // it references.
            for table in Self.tables {
                for row in document.tables[table.name] ?? [] {
                    let rowData = try JSONSerialization.data(withJSONObject: row)
                    switch try table.merge(rowData, db) {
                    case .inserted: outcome.inserted += 1
                    case .updated: outcome.updated += 1
                    case .unchanged: outcome.unchanged += 1
                    }
                }
            }
        }

        if let photos {
            for (name, base64) in document.photos where !photos.exists(name) {
                guard let bytes = Data(base64Encoded: base64) else { continue }
                try bytes.write(to: photos.url(for: name), options: .atomic)
                outcome.photosWritten += 1
            }
        }
        return outcome
    }

    // MARK: - Internals

    private struct Parsed {
        let exportedAt: Int64?
        let tables: [String: [[String: Any]]]
        let photos: [String: String]
    }

    private func parse(_ data: Data) throws -> Parsed {
        guard let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              object["format"] as? String == Self.format,
              let version = object["version"] as? Int
        else { throw BackupError.notABackup }
        guard version <= Self.version else { throw BackupError.newerThanThisApp(version) }

        var tables: [String: [[String: Any]]] = [:]
        for (name, rows) in (object["tables"] as? [String: Any]) ?? [:] {
            tables[name] = (rows as? [[String: Any]]) ?? []
        }
        return Parsed(
            exportedAt: (object["exported_at"] as? NSNumber)?.int64Value,
            tables: tables,
            photos: (object["photos"] as? [String: String]) ?? [:])
    }

    enum Merge { case inserted, updated, unchanged }

    /// One table, type-erased so the list above can be walked.
    struct Table: Sendable {
        let name: String
        let allRows: @Sendable (Database) throws -> [Any]
        let merge: @Sendable (Data, Database) throws -> Merge

        init<R: SyncableRecord & TableRecord>(_ type: R.Type) {
            name = R.databaseTableName
            allRows = { db in
                let encoder = JSONEncoder()
                return try R.fetchAll(db).map { record in
                    let data = try encoder.encode(record)
                    return try JSONSerialization.jsonObject(with: data)
                }
            }
            merge = { data, db in
                var incoming = try JSONDecoder().decode(R.self, from: data)
                if let existing = try R.filter(key: incoming.id).fetchOne(db) {
                    guard incoming.updatedAt > existing.updatedAt else { return .unchanged }
                    incoming.dirty = true
                    try incoming.save(db)
                    return .updated
                }
                incoming.dirty = true
                try incoming.save(db)
                return .inserted
            }
        }
    }

    /// Everything the person owns. `subscriptions` is the server's, not
    /// theirs, and is neither written nor restored.
    static let tables: [Table] = [
        Table(CustomCatalogEntry.self),
        Table(Bottle.self),
        Table(Pour.self),
        Table(FillReading.self),
        Table(Tasting.self),
        Table(TastingNote.self),
        Table(WishlistItem.self),
        Table(KnowledgeNote.self),
    ]
}
