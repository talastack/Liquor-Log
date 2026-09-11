import Foundation

/// The collection as a document for an insurer or an executor.
///
/// The research names this as one of three things people will pay for,
/// because it is a service rather than their own data handed back: *"the
/// insurance/estate PDF report."* It is also the one place the money is
/// wanted without hesitation -- an inventory with what was paid, when, and
/// where, with a photo, is what a claim asks for.
///
/// This is the content. The app draws it. Every number is what the owner
/// recorded; nothing here is a valuation, and the document says so on
/// every page, because a report that reads as an appraisal is a liability
/// the app must never carry.
public enum InsuranceReport: Sendable {

    public struct Line: Hashable, Sendable, Identifiable {
        public let id: String
        public let name: String
        public let distillery: String?
        /// Barrel, batch, pick, bottle number -- the identity of THIS bottle.
        public let detail: String?
        public let sizeMilliliters: Double
        public let status: String
        public let purchasedAt: Date?
        public let store: String?
        public let paidCents: Int?
        public let photoFile: String?
        public let storageLocation: String?

        public init(
            id: String,
            name: String,
            distillery: String? = nil,
            detail: String? = nil,
            sizeMilliliters: Double,
            status: String,
            purchasedAt: Date? = nil,
            store: String? = nil,
            paidCents: Int? = nil,
            photoFile: String? = nil,
            storageLocation: String? = nil
        ) {
            self.id = id
            self.name = name
            self.distillery = distillery
            self.detail = detail
            self.sizeMilliliters = sizeMilliliters
            self.status = status
            self.purchasedAt = purchasedAt
            self.store = store
            self.paidCents = paidCents
            self.photoFile = photoFile
            self.storageLocation = storageLocation
        }
    }

    public struct Document: Hashable, Sendable {
        public let generatedAt: Date
        public let lines: [Line]
        public let bottleCount: Int
        public let pricedCount: Int
        /// The sum of what was paid, over the bottles with a price.
        public let paidTotalCents: Int
        public let title: String
        public let caveat: String

        public var unpricedCount: Int { bottleCount - pricedCount }
    }

    public static let title = "Spirits collection inventory"

    /// On every page. Not negotiable, and not softened.
    public static let caveat =
        "Purchase prices as recorded by the owner. Not an appraisal and not a "
        + "statement of current value."

    /// Only bottles on the shelf, sealed or open. A finished bottle has no
    /// value to insure and an executor does not need the empties. Ordered by
    /// distillery then name so an adjuster can find a line.
    public static func build(_ lines: [Line], generatedAt: Date = Date()) -> Document {
        let ordered = lines.sorted {
            let a = ($0.distillery ?? "") + " " + $0.name
            let b = ($1.distillery ?? "") + " " + $1.name
            return a.localizedCaseInsensitiveCompare(b) == .orderedAscending
        }
        let priced = ordered.compactMap(\.paidCents)
        return Document(
            generatedAt: generatedAt,
            lines: ordered,
            bottleCount: ordered.count,
            pricedCount: priced.count,
            paidTotalCents: priced.reduce(0, +),
            title: title,
            caveat: caveat)
    }

    /// The identity line for a bottle: whatever barrel-level facts it has,
    /// in a fixed order, or nil for a plain standard release.
    public static func detail(
        barrel: String? = nil,
        batch: String? = nil,
        pickStore: String? = nil,
        bottleNumber: Int? = nil,
        bottlesInBatch: Int? = nil,
        topperLetter: String? = nil
    ) -> String? {
        var parts: [String] = []
        if let barrel { parts.append("Barrel \(barrel)") }
        if let batch { parts.append("Batch \(batch)") }
        if let pickStore { parts.append("Pick · \(pickStore)") }
        if let bottleNumber {
            if let bottlesInBatch {
                parts.append("Bottle \(bottleNumber) of \(bottlesInBatch)")
            } else {
                parts.append("Bottle \(bottleNumber)")
            }
        }
        if let topperLetter { parts.append("Topper \(topperLetter)") }
        return parts.isEmpty ? nil : parts.joined(separator: " · ")
    }
}
