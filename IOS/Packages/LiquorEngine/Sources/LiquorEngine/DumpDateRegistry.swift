import Foundation

/// Your Blanton's, written out in the shape of the dump-date registry.
///
/// The one thing the bourbon community has demonstrably welcomed (research
/// §"The risk that is not code") is a non-commercial dump-date registry with
/// an explicit ask for contributions. The live one is bourbondumpdate.com,
/// whose record is the dump date, the state the bottle was found in, and the
/// letter on the cork topper. This writes the same three things, plus the
/// barrel identity the label prints, as a CSV a person can paste into a
/// form or send to the registry's author.
///
/// It is a contribution the person makes, by hand, from their own data.
/// Nothing here contacts anybody; the app has no relationship with the
/// registry and claims none. State found is the purchase store's state
/// when the person recorded one, otherwise blank -- guessing a state from a
/// store name is the kind of thing that poisons a registry.
public enum DumpDateRegistry: Sendable {

    public struct Entry: Hashable, Sendable {
        public let dumpedAt: Date?
        public let topperLetter: String?
        public let barrel: String?
        public let warehouse: String?
        public let rick: String?
        public let bottleNumber: Int?
        public let store: String?
        public let stateFound: String?

        public init(
            dumpedAt: Date? = nil,
            topperLetter: String? = nil,
            barrel: String? = nil,
            warehouse: String? = nil,
            rick: String? = nil,
            bottleNumber: Int? = nil,
            store: String? = nil,
            stateFound: String? = nil
        ) {
            self.dumpedAt = dumpedAt
            self.topperLetter = topperLetter
            self.barrel = barrel
            self.warehouse = warehouse
            self.rick = rick
            self.bottleNumber = bottleNumber
            self.store = store
            self.stateFound = stateFound
        }

        /// A registry entry needs a dump date; the letter alone is a
        /// collector's fact, not a registry one.
        public var isSubmittable: Bool { dumpedAt != nil }
    }

    public static let header = [
        "dump_date", "topper_letter", "barrel", "warehouse", "rick",
        "bottle_number", "store", "state_found",
    ]

    /// Only entries with a dump date, oldest dump first. Dates as ISO
    /// (yyyy-mm-dd), because that is the one format every form parses.
    public static func csv(_ entries: [Entry], calendar: Calendar = .current) -> String {
        let rows = entries
            .filter(\.isSubmittable)
            .sorted { ($0.dumpedAt ?? .distantPast) < ($1.dumpedAt ?? .distantPast) }
            .map { entry -> [String] in
                [
                    entry.dumpedAt.map { isoDay($0, calendar: calendar) } ?? "",
                    entry.topperLetter.flatMap(TopperLetters.normalise).map(String.init) ?? "",
                    entry.barrel ?? "",
                    entry.warehouse ?? "",
                    entry.rick ?? "",
                    entry.bottleNumber.map(String.init) ?? "",
                    entry.store ?? "",
                    entry.stateFound ?? "",
                ]
            }
        return CSVWriter.document(header: header, rows: rows)
    }

    static func isoDay(_ date: Date, calendar: Calendar) -> String {
        let parts = calendar.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d-%02d-%02d", parts.year ?? 0, parts.month ?? 0, parts.day ?? 0)
    }
}
