import Foundation

/// What is in a bottle that was filled from other bottles: an infinity
/// bottle, a home vatting, a blend.
///
/// Two numbers people want from it. The **strength**, because a blend of a
/// 124-proof and a 90-proof has no label to read; and the **make-up**, which
/// is what an infinity bottle is for -- "a third Weller, a quarter that
/// Four Roses pick, and everything else in small pieces".
///
/// Strength is worked the way distillers' blending records are kept: the
/// alcohol in each part (its volume times its strength) is added up, and
/// the total is divided by the total volume. Alcohol is conserved when
/// spirits are mixed; the slight contraction of the mixture is ignored, as
/// it is in proof-gallon accounting. When any part's strength is unknown --
/// a barrel-proof bottle whose proof was never typed -- the blend's
/// strength is unknown too, and the profile says how much of it is unknown
/// rather than guessing.
///
/// Make-up is by what went IN. Pouring out takes every part in proportion,
/// so the shares never change on a pour, only on an addition.
public enum Blend: Sendable {

    /// One thing that went into the bottle. `key` groups additions of the
    /// same source; `name` is what to print.
    public struct Part: Hashable, Sendable {
        public let key: String
        public let name: String
        public let milliliters: Double
        public let abv: Double?

        public init(key: String, name: String, milliliters: Double, abv: Double?) {
            self.key = key
            self.name = name
            self.milliliters = milliliters
            self.abv = abv
        }
    }

    public struct Share: Hashable, Sendable, Identifiable {
        public let key: String
        public let name: String
        public let milliliters: Double
        /// 0...1 of everything added.
        public let fraction: Double
        public var id: String { key }

        /// "34%"; "under 1%" rather than "0%" for a splash.
        public var percentText: String {
            let percent = fraction * 100
            if percent > 0, percent < 1 { return "under 1%" }
            return "\(Int(percent.rounded()))%"
        }
    }

    public struct Profile: Hashable, Sendable {
        /// Everything ever added, before any pours out.
        public let addedMilliliters: Double
        /// Nil when any part's strength is unknown.
        public let abv: Double?
        /// The volume added from parts whose strength is not known. Zero
        /// when `abv` is known.
        public let unknownMilliliters: Double
        /// Biggest first; equal shares alphabetical so the list is stable.
        public let shares: [Share]

        public var partCount: Int { shares.count }
        public var isEmpty: Bool { addedMilliliters <= 0 }

        public var proof: Double? { abv.map { ABV(percent: $0).proof } }

        /// "112.4 proof" or why there is no number.
        public var strengthText: String {
            if let proof { return String(format: "%.1f proof", proof) }
            if isEmpty { return "Nothing in it yet" }
            let ml = Int(unknownMilliliters.rounded())
            return "Unknown — \(ml) ml went in without a proof"
        }
    }

    public static func profile(_ parts: [Part]) -> Profile {
        let live = parts.filter { $0.milliliters > 0 }
        let total = live.reduce(0) { $0 + $1.milliliters }

        var byKey: [String: (name: String, ml: Double)] = [:]
        var order: [String] = []
        for part in live {
            if byKey[part.key] == nil { order.append(part.key) }
            byKey[part.key, default: (part.name, 0)].ml += part.milliliters
        }
        let shares = order
            .map { key -> Share in
                let entry = byKey[key]!
                return Share(
                    key: key, name: entry.name, milliliters: entry.ml,
                    fraction: total > 0 ? entry.ml / total : 0)
            }
            .sorted {
                $0.milliliters != $1.milliliters
                    ? $0.milliliters > $1.milliliters
                    : $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending
            }

        let unknown = live.filter { $0.abv == nil }.reduce(0) { $0 + $1.milliliters }
        var abv: Double?
        if total > 0, unknown == 0 {
            let alcohol = live.reduce(0) { $0 + $1.milliliters * ($1.abv ?? 0) }
            abv = alcohol / total
        }

        return Profile(
            addedMilliliters: total,
            abv: abv,
            unknownMilliliters: unknown,
            shares: shares)
    }
}
