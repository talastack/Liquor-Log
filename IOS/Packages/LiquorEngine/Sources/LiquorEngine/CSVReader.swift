import Foundation

/// Reads a CSV the way a spreadsheet wrote it.
///
/// The inverse of `CSVWriter`, and the reason it has to be a real parser
/// rather than a split on commas: the first thing anybody's spreadsheet
/// contains is a bottle called *"Elijah Craig Barrel Proof, Batch B523"*, and
/// a tasting note with a line break in it. Splitting on commas hands back a
/// collection where half the bottles are named `"B523"`.
///
/// RFC 4180: a quoted field may contain commas, quotes (doubled) and newlines.
/// CRLF and LF both end a record. A trailing newline does not produce an empty
/// last row.
public enum CSVReader: Sendable {

    /// Rows of fields. The first row is whatever the file said it was — the
    /// caller decides whether that is a header.
    public static func rows(_ text: String) -> [[String]] {
        var rows: [[String]] = []
        var row: [String] = []
        var field = ""
        var inQuotes = false
        var iterator = text.makeIterator()
        var pending: Character? = nil

        func next() -> Character? {
            if let p = pending { pending = nil; return p }
            return iterator.next()
        }

        while let character = next() {
            if inQuotes {
                if character == "\"" {
                    // A doubled quote inside a quoted field is a literal
                    // quote. Anything else after a quote ends the field.
                    if let following = next() {
                        if following == "\"" {
                            field.append("\"")
                        } else {
                            inQuotes = false
                            pending = following
                        }
                    } else {
                        inQuotes = false
                    }
                } else {
                    field.append(character)
                }
                continue
            }

            switch character {
            case "\"":
                inQuotes = true
            case ",":
                row.append(field)
                field = ""
            case "\r":
                // CRLF: swallow the LF that follows.
                if let following = next(), following != "\n" { pending = following }
                row.append(field)
                rows.append(row)
                row = []
                field = ""
            case "\n":
                row.append(field)
                rows.append(row)
                row = []
                field = ""
            default:
                field.append(character)
            }
        }

        // The last record, unless the file ended cleanly on a newline.
        if !field.isEmpty || !row.isEmpty {
            row.append(field)
            rows.append(row)
        }

        return rows
    }

    /// Rows as dictionaries keyed by the header, with the header normalised to
    /// lowercase and trimmed so `"Bottle Name"` and `"bottle name "` agree.
    public static func records(_ text: String) -> (header: [String], rows: [[String: String]]) {
        let all = rows(text)
        guard let first = all.first else { return ([], []) }
        let header = first.map { normalise($0) }
        let body = all.dropFirst().filter { row in row.contains { !$0.isEmpty } }
        let records = body.map { row -> [String: String] in
            var record: [String: String] = [:]
            for (index, key) in header.enumerated() where index < row.count {
                record[key] = row[index].trimmingCharacters(in: .whitespaces)
            }
            return record
        }
        return (header, records)
    }

    static func normalise(_ header: String) -> String {
        header.trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
            .replacingOccurrences(of: "\u{FEFF}", with: "")   // Excel's BOM
    }
}
