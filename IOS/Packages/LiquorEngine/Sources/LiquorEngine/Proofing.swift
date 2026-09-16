import Foundation

/// How much water takes a pour from one proof to another.
///
/// Not a straight ratio. Ethanol and water contract when they mix, so 100
/// parts of spirit at 100 proof hold 50 parts of alcohol and **53.73**
/// parts of water, not 50. The TTB's Gauging Manual Table 6 (27 CFR
/// 30.66) tabulates those two figures for every proof, and gives the
/// method: *divide the alcohol in the given strength by the alcohol in
/// the required strength, multiply by the water in the required strength,
/// and subtract the water in the given strength -- the remainder is the
/// water to add to 100 parts of spirit.* Its own example: 112 proof to
/// 100 proof is 1.12 × 53.73 − 47.75 = 12.42 parts.
///
/// The water column here is 51 to 150 proof, transcribed from the TTB's
/// scan of the table (ttb.gov, foia Gauging Manual Tables, Table_6.pdf)
/// and checked two ways: the anchors the regulation text prints (100 →
/// 53.73, 112 → 47.75, 191 → 5.59, 188 → 7.36) and the step between
/// neighbours, which runs smoothly from 0.45 to 0.53 across the range and
/// exposed every misread digit. Alcohol is proof over two by definition.
/// Whiskey is bottled between 80 and about 145 proof, so the range covers
/// every pour this app will see; outside it the answer is nil, never a
/// guess. Between whole proofs the water figure is interpolated, which
/// over a half-step of 0.25 parts is exact to the hundredth.
public enum Proofing: Sendable {

    /// Parts of water in 100 parts of spirit at 60 °F, by proof.
    static let water: [Int: Double] = [
        51: 76.79, 52: 76.34, 53: 75.89, 54: 75.44, 55: 74.98,
        56: 74.53, 57: 74.08, 58: 73.62, 59: 73.17, 60: 72.72,
        61: 72.26, 62: 71.81, 63: 71.36, 64: 70.89, 65: 70.43,
        66: 69.97, 67: 69.51, 68: 69.06, 69: 68.59, 70: 68.12,
        71: 67.66, 72: 67.19, 73: 66.72, 74: 66.26, 75: 65.78,
        76: 65.31, 77: 64.84, 78: 64.37, 79: 63.90, 80: 63.42,
        81: 62.95, 82: 62.47, 83: 61.99, 84: 61.52, 85: 61.04,
        86: 60.56, 87: 60.08, 88: 59.59, 89: 59.11, 90: 58.63,
        91: 58.14, 92: 57.66, 93: 57.17, 94: 56.68, 95: 56.19,
        96: 55.70, 97: 55.21, 98: 54.72, 99: 54.22, 100: 53.73,
        101: 53.24, 102: 52.74, 103: 52.25, 104: 51.75, 105: 51.25,
        106: 50.75, 107: 50.26, 108: 49.76, 109: 49.26, 110: 48.76,
        111: 48.25, 112: 47.75, 113: 47.25, 114: 46.75, 115: 46.24,
        116: 45.74, 117: 45.23, 118: 44.72, 119: 44.22, 120: 43.71,
        121: 43.20, 122: 42.69, 123: 42.18, 124: 41.67, 125: 41.16,
        126: 40.65, 127: 40.14, 128: 39.62, 129: 39.11, 130: 38.60,
        131: 38.08, 132: 37.57, 133: 37.05, 134: 36.54, 135: 36.02,
        136: 35.50, 137: 34.99, 138: 34.47, 139: 33.95, 140: 33.43,
        141: 32.91, 142: 32.38, 143: 31.86, 144: 31.34, 145: 30.82,
        146: 30.29, 147: 29.76, 148: 29.24, 149: 28.71, 150: 28.19,
    ]

    public static let lowestProof = 51.0
    public static let highestProof = 150.0

    /// Water in 100 parts of spirit at any proof the table covers,
    /// interpolated between whole proofs.
    static func waterParts(atProof proof: Double) -> Double? {
        guard proof >= lowestProof, proof <= highestProof else { return nil }
        let lower = Int(proof.rounded(.down))
        let upper = min(lower + 1, Int(highestProof))
        guard let low = water[lower], let high = water[upper] else { return nil }
        let t = proof - Double(lower)
        return low + (high - low) * t
    }

    /// Millilitres of water to add to `spiritMilliliters` at `from` proof to
    /// bring it to `to` proof. Nil when either proof is outside the table
    /// or the target is not below the start.
    public static func waterToAdd(
        from: Double, to: Double, spiritMilliliters spirit: Double
    ) -> Double? {
        guard to < from, spirit > 0,
              let waterFrom = waterParts(atProof: from),
              let waterTo = waterParts(atProof: to) else { return nil }
        let alcoholFrom = from / 2
        let alcoholTo = to / 2
        let partsPerHundred = alcoholFrom / alcoholTo * waterTo - waterFrom
        return partsPerHundred / 100 * spirit
    }

    /// The proof a pour lands at after `waterMilliliters` of water go into
    /// `spiritMilliliters` at `from` proof. Found by walking the table
    /// downward, so it is the same arithmetic as `waterToAdd` run the other
    /// way. Nil below the table's floor or outside it.
    public static func proofAfterAdding(
        waterMilliliters water: Double, to from: Double, spiritMilliliters spirit: Double
    ) -> Double? {
        guard water >= 0, spirit > 0, waterParts(atProof: from) != nil else { return nil }
        if water == 0 { return from }
        var low = lowestProof
        var high = from
        guard let atFloor = waterToAdd(from: from, to: low, spiritMilliliters: spirit),
              water <= atFloor else { return nil }
        for _ in 0..<40 {
            let mid = (low + high) / 2
            let needed = waterToAdd(from: from, to: mid, spiritMilliliters: spirit) ?? 0
            if needed > water { low = mid } else { high = mid }
        }
        return (low + high) / 2
    }

    /// "6.2 ml — about 1¼ teaspoons". A kitchen measure beside the number,
    /// because nobody owns a 6 ml pipette. A US teaspoon is 4.93 ml.
    public static func describe(waterMilliliters ml: Double) -> String {
        // A pour size typed as a wall of digits reaches here as a volume
        // no spoon measures; the count is capped so the conversion to an
        // integer cannot trap, and the sentence stays true.
        guard ml.isFinite, ml >= 0 else { return "—" }
        let teaspoons = ml / 4.92892
        let quarters = min((teaspoons * 4).rounded(), 4_000_000)
        let spoons: String
        switch quarters {
        case ..<1: spoons = "a few drops"
        case 1: spoons = "about ¼ teaspoon"
        case 2: spoons = "about ½ teaspoon"
        case 3: spoons = "about ¾ teaspoon"
        default:
            let whole = Int(quarters) / 4
            let rest = Int(quarters) % 4
            let fraction = ["", "¼", "½", "¾"][rest]
            spoons = "about \(whole)\(fraction) \(whole == 1 && rest == 0 ? "teaspoon" : "teaspoons")"
        }
        return String(format: "%.1f ml — %@", ml, spoons)
    }
}
