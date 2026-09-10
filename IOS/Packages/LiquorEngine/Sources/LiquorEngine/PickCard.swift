import Foundation

/// A store pick, written out as a record somebody else can use.
///
/// The research brief found that a national, crowdsourced registry of store
/// picks and single barrels has no incumbent — only fragments that are
/// brand-captive or stop at a state line — and that what survives in this
/// space is *"crowdsourcing with moderation cheap enough to survive its
/// founder's attention span."* It also found the only community-welcomed
/// pattern: a non-commercial registry with *"an explicit ask for contribution."*
///
/// This is the contribution. Every pick in the app already carries the fields
/// the Nashville Barrel Co. database uses — barrel number, mashbill, proof,
/// bottle count, who picked it — as structured columns rather than a notes
/// field. Writing them out in a fixed shape means a pick shared to a forum, a
/// group chat or a future registry arrives as data rather than prose.
///
/// **Plain text with a fixed key order.** It has to survive being pasted
/// anywhere, and a stable shape is what lets a registry parse it back without
/// a person in the loop.
public enum PickCard: Sendable {

    public struct Pick: Hashable, Sendable {
        public let product: String
        public let distillery: String?
        public let pickedBy: String?
        public let store: String?
        public let barrel: String?
        public let batch: String?
        public let recipeCode: String?
        public let warehouse: String?
        public let rick: String?
        public let floor: String?
        public let proof: Double?
        public let ageMonths: Int?
        public let entryProof: Double?
        public let charLevel: Int?
        public let finish: String?
        public let bottleNumber: Int?
        public let bottlesInBatch: Int?
        public let dumpedAt: Date?
        public let bottledYear: Int?

        public init(
            product: String, distillery: String? = nil, pickedBy: String? = nil,
            store: String? = nil, barrel: String? = nil, batch: String? = nil,
            recipeCode: String? = nil, warehouse: String? = nil, rick: String? = nil,
            floor: String? = nil, proof: Double? = nil, ageMonths: Int? = nil,
            entryProof: Double? = nil, charLevel: Int? = nil, finish: String? = nil,
            bottleNumber: Int? = nil, bottlesInBatch: Int? = nil,
            dumpedAt: Date? = nil, bottledYear: Int? = nil
        ) {
            self.product = product; self.distillery = distillery; self.pickedBy = pickedBy
            self.store = store; self.barrel = barrel; self.batch = batch
            self.recipeCode = recipeCode; self.warehouse = warehouse; self.rick = rick
            self.floor = floor; self.proof = proof; self.ageMonths = ageMonths
            self.entryProof = entryProof; self.charLevel = charLevel; self.finish = finish
            self.bottleNumber = bottleNumber; self.bottlesInBatch = bottlesInBatch
            self.dumpedAt = dumpedAt; self.bottledYear = bottledYear
        }

        /// Whether there is anything barrel-specific to share. A standard
        /// release is not a pick, and a card with only a product name on it
        /// would be noise in a registry.
        public var hasBarrelDetail: Bool {
            barrel != nil || batch != nil || recipeCode != nil || warehouse != nil
                || rick != nil || floor != nil || ageMonths != nil || pickedBy != nil
                || dumpedAt != nil
        }
    }

    /// One `key: value` per line, in a fixed order, blank fields omitted.
    ///
    /// The order is the order somebody reads a label: what it is, who chose
    /// it, where the barrel sat, what came out of it.
    public static func text(_ pick: Pick, calendar: Calendar = .current) -> String {
        var lines: [String] = []

        func add(_ key: String, _ value: String?) {
            guard let value, !value.isEmpty else { return }
            lines.append("\(key): \(value)")
        }

        add("Pick", pick.product)
        add("Distillery", pick.distillery)
        add("Picked by", pick.pickedBy)
        add("Store", pick.store)

        add("Barrel", pick.barrel)
        add("Batch", pick.batch)
        if let code = pick.recipeCode {
            // Decoded inline where the scheme is known, so a reader who does
            // not know what OESQ means gets the answer on the same line.
            let decoded = RecipeCode(code).map { " (\($0.mashbill.summary); \($0.yeast.character.lowercased()) yeast)" } ?? ""
            add("Recipe", code + decoded)
        }
        add("Warehouse", pick.warehouse)
        add("Rick", pick.rick)
        add("Floor", pick.floor)

        add("Proof", pick.proof.map { String(format: "%.1f", $0) })
        add("Age", pick.ageMonths.map(ageText))
        add("Entry proof", pick.entryProof.map { String(format: "%.1f", $0) })
        add("Char", pick.charLevel.map { "#\($0)" })
        add("Finish", pick.finish)
        if let number = pick.bottleNumber {
            add("Bottle", pick.bottlesInBatch.map { "\(number) of \($0)" } ?? "\(number)")
        } else if let count = pick.bottlesInBatch {
            add("Bottles", "\(count)")
        }
        add("Dumped", pick.dumpedAt.map { isoDate($0, calendar) })
        add("Bottled", pick.bottledYear.map(String.init))

        return lines.joined(separator: "\n")
    }

    /// "9 years 4 months", because the months are the reason the pick was
    /// chosen and rounding them off throws that away.
    static func ageText(_ months: Int) -> String {
        let years = months / 12
        let rest = months % 12
        switch (years, rest) {
        case (0, let m): return "\(m) months"
        case (let y, 0): return "\(y) years"
        case (let y, let m): return "\(y) years \(m) months"
        }
    }

    static func isoDate(_ date: Date, _ calendar: Calendar) -> String {
        let parts = calendar.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d-%02d-%02d", parts.year ?? 0, parts.month ?? 0, parts.day ?? 0)
    }
}
