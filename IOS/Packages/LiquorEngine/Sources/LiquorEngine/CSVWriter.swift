import Foundation

/// Writes a CSV anyone can open in a spreadsheet.
///
/// **Export is free, always, and prominent.** In this category people have been
/// burned by apps losing their data or vanishing, and the advice they give each
/// other is blunt: *be wary of any app that will not let you export.* It costs
/// almost nothing to build and it is the strongest trust signal available, so
/// putting it behind a paywall would be trading the thing that earns adoption
/// for a rounding error in revenue.
///
/// Spreadsheets are also the real incumbent. A collection that can leave is a
/// collection somebody is willing to put in.
public enum CSVWriter: Sendable {

    /// RFC 4180: quote a field that contains a comma, a quote or a newline, and
    /// double any quote inside it.
    ///
    /// Bourbon data hits every one of these. Pick names contain commas
    /// ("Barrel 42, Floor 5"), tasting notes contain quotes and line breaks, and
    /// a naive join would produce a file that opens misaligned and looks like
    /// lost data.
    public static func escape(_ field: String) -> String {
        let needsQuoting = field.contains(",")
            || field.contains("\"")
            || field.contains("\n")
            || field.contains("\r")
        guard needsQuoting else { return field }
        return "\"" + field.replacingOccurrences(of: "\"", with: "\"\"") + "\""
    }

    public static func row(_ fields: [String]) -> String {
        fields.map(escape).joined(separator: ",")
    }

    /// A whole document. CRLF line endings, because Excel is the destination
    /// often enough to be worth not arguing with.
    public static func document(header: [String], rows: [[String]]) -> String {
        ([row(header)] + rows.map(row)).joined(separator: "\r\n") + "\r\n"
    }

    // MARK: - Formatting helpers

    /// Empty rather than "nil" or "0". A blank cell reads as "not recorded",
    /// which is the truth for most optional fields on most bottles.
    public static func text(_ value: String?) -> String { value ?? "" }

    public static func number(_ value: Int?) -> String {
        value.map(String.init) ?? ""
    }

    public static func decimal(_ value: Double?, places: Int = 1) -> String {
        guard let value else { return "" }
        return String(format: "%.\(places)f", value)
    }

    /// Money as a plain decimal, no currency symbol. A symbol makes the column
    /// text in every spreadsheet that opens it.
    public static func money(cents: Int?) -> String {
        guard let cents else { return "" }
        return String(format: "%.2f", Double(cents) / 100)
    }

    /// ISO dates, because they sort correctly as text in every spreadsheet.
    public static func date(millis: Int64?, calendar: Calendar = .current) -> String {
        guard let millis else { return "" }
        let date = Date(timeIntervalSince1970: Double(millis) / 1000)
        let parts = calendar.dateComponents([.year, .month, .day], from: date)
        guard let year = parts.year, let month = parts.month, let day = parts.day else {
            return ""
        }
        return String(format: "%04d-%02d-%02d", year, month, day)
    }

    public static func flag(_ value: Bool) -> String { value ? "yes" : "" }
}
