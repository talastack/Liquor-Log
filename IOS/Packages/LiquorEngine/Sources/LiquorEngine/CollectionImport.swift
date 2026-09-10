import Foundation

/// Turns somebody's spreadsheet into bottles.
///
/// Spreadsheets are the incumbent — *"the actual market leader"* in the
/// research's own words — and the people this app most wants are the ones
/// with two hundred rows already typed into one. *"So I have 200+ bottles,
/// and zero interest in manually adding each one."* Whiskey Shelf converts
/// paying users by migrating them off other apps; this does the same from the
/// tool people actually use, and does it for free, because charging at the
/// moment somebody hands you their whole collection is charging at the exact
/// point you most want them to succeed.
///
/// Two shapes are handled. **Our own export**, which round-trips exactly. And
/// **anybody's spreadsheet**, by recognising column names — "Bottle",
/// "Whiskey", "Name" are all the name; "Proof" and "ABV" are both the
/// strength; "Paid", "Price" and "Cost" are what it cost. Nothing has to be
/// renamed before import.
///
/// **This plans; it does not write.** It returns what it would create and what
/// it would skip, so a screen can show the plan before a single row lands. An
/// import that silently produced 40 untitled bottles from a misaligned column
/// would be worse than no import, and nobody would find out until they
/// searched for something.
public enum CollectionImport: Sendable {

    /// One bottle, as the spreadsheet described it.
    public struct Row: Hashable, Sendable {
        public var name: String
        public var proof: Double?
        public var volumeMilliliters: Double?
        public var paidCents: Int?
        public var store: String?
        public var batch: String?
        public var barrel: String?
        public var storageLocation: String?
        public var isOpen: Bool
        public var isFinished: Bool
        public var note: String?
        /// Where it came from in the file, for a "row 14 was skipped" message.
        public let line: Int

        public init(
            name: String, proof: Double? = nil, volumeMilliliters: Double? = nil,
            paidCents: Int? = nil, store: String? = nil, batch: String? = nil,
            barrel: String? = nil, storageLocation: String? = nil,
            isOpen: Bool = false, isFinished: Bool = false, note: String? = nil,
            line: Int
        ) {
            self.name = name; self.proof = proof; self.volumeMilliliters = volumeMilliliters
            self.paidCents = paidCents; self.store = store; self.batch = batch
            self.barrel = barrel; self.storageLocation = storageLocation
            self.isOpen = isOpen; self.isFinished = isFinished; self.note = note
            self.line = line
        }
    }

    public struct Plan: Sendable {
        public let rows: [Row]
        /// Line numbers with no usable name. Reported, never guessed.
        public let skippedLines: [Int]
        /// Which spreadsheet column was read as which field, so the screen can
        /// say "reading 'Whiskey' as the name" and somebody can catch a wrong
        /// guess before it lands.
        public let mapping: [Field: String]

        public var isEmpty: Bool { rows.isEmpty }
    }

    public enum Field: String, Sendable, Hashable, CaseIterable {
        case name, proof, abv, volume, paid, store, batch, barrel, location, status, note
    }

    /// Header names that mean each field, lowercase. The first match wins, so
    /// the most specific spellings come first.
    static let synonyms: [Field: [String]] = [
        .name: ["name", "bottle", "bottle name", "whiskey", "whisky", "bourbon",
                "product", "expression", "label", "spirit"],
        .proof: ["proof"],
        .abv: ["abv", "abv %", "alcohol", "strength", "%"],
        .volume: ["size_ml", "size", "volume", "ml", "size (ml)", "bottle size"],
        .paid: ["price", "paid", "cost", "purchase price", "purchase_price", "$"],
        .store: ["bought_at", "store", "bought at", "shop", "retailer", "place of purchase",
                 "purchased at", "where"],
        .batch: ["batch", "batch number", "batch #", "batch_number"],
        .barrel: ["barrel", "barrel number", "barrel #", "barrel_number", "cask"],
        .location: ["storage_location", "location", "storage", "shelf", "where kept"],
        .status: ["status", "state", "opened", "open"],
        .note: ["notes", "note", "comments", "comment", "review", "liked"],
    ]

    /// Reads a whole file into a plan.
    public static func plan(csv text: String) -> Plan {
        let (header, records) = CSVReader.records(text)
        let mapping = map(header)

        guard let nameColumn = mapping[.name] else {
            // No name column at all: nothing can be imported and the plan says
            // so with every line skipped rather than inventing a name from
            // the first column.
            return Plan(rows: [], skippedLines: Array(records.indices.map { $0 + 2 }), mapping: mapping)
        }

        var rows: [Row] = []
        var skipped: [Int] = []

        for (index, record) in records.enumerated() {
            let line = index + 2   // 1-based, after the header
            let name = (record[nameColumn] ?? "").trimmingCharacters(in: .whitespaces)
            guard !name.isEmpty else {
                skipped.append(line)
                continue
            }

            let get: (Field) -> String? = { field in
                mapping[field].flatMap { record[$0] }.flatMap { $0.isEmpty ? nil : $0 }
            }

            // Proof wins over ABV when both exist, for the same reason it does
            // on a label: it is the number people wrote down.
            var proof = number(get(.proof))
            if proof == nil, let abv = number(get(.abv)) {
                proof = abv <= 95 ? ABV(percent: abv).proof : nil
            }

            let status = (get(.status) ?? "").lowercased()
            let isFinished = ["killed", "finished", "empty", "dead", "gone"].contains {
                status.contains($0)
            }
            let isOpen = !isFinished && (
                ["open", "opened", "yes", "y", "true"].contains { status == $0 || status.hasPrefix($0) }
            )

            rows.append(Row(
                name: name,
                proof: proof,
                volumeMilliliters: number(get(.volume)).map { $0 < 10 ? $0 * 1000 : $0 },
                paidCents: number(get(.paid)).map { Int(($0 * 100).rounded()) },
                store: get(.store),
                batch: get(.batch),
                barrel: get(.barrel),
                storageLocation: get(.location),
                isOpen: isOpen,
                isFinished: isFinished,
                note: get(.note),
                line: line))
        }

        return Plan(rows: rows, skippedLines: skipped, mapping: mapping)
    }

    /// Matches header names to fields.
    ///
    /// Exact match first, then a header that CONTAINS a synonym — so
    /// "Purchase Price ($)" still reads as paid. Each spreadsheet column is
    /// claimed by at most one field.
    static func map(_ header: [String]) -> [Field: String] {
        var mapping: [Field: String] = [:]
        var claimed: Set<String> = []

        for field in Field.allCases {
            let candidates = synonyms[field] ?? []
            if let exact = header.first(where: { candidates.contains($0) && !claimed.contains($0) }) {
                mapping[field] = exact
                claimed.insert(exact)
                continue
            }
            if let partial = header.first(where: { column in
                !claimed.contains(column) && candidates.contains { column.contains($0) }
            }) {
                mapping[field] = partial
                claimed.insert(partial)
            }
        }
        return mapping
    }

    /// "$79.99", "79.99", "80", "750ml" all become a number. Nil for anything
    /// that is not one.
    static func number(_ text: String?) -> Double? {
        guard let text else { return nil }
        let cleaned = text.filter { $0.isNumber || $0 == "." }
        guard !cleaned.isEmpty, let value = Double(cleaned), value > 0 else { return nil }
        return value
    }
}
