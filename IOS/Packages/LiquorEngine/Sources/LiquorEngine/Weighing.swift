import Foundation

/// The fill level of a bottle from its weight on a kitchen scale.
///
/// A spirit's density is fixed by its proof, so the grams on a scale are
/// millilitres once the empty bottle's weight is known. The density comes
/// from the same TTB Table 6 the water card uses -- the volumes of alcohol
/// and water in 100 volumes of spirit -- and two constants the Gauging
/// Manual states: water weighs **8.32823** pounds per gallon in air at
/// 60 °F (27 CFR 30.66, its worked example), and 200-proof spirit
/// **6.6096** (Table 5, weight per wine gallon). Mass is conserved when
/// water and alcohol mix even though volume is not, so the density of a
/// spirit at any proof is its alcohol's mass plus its water's mass over
/// the 100 volumes they make:
///
///     grams per ml  =  (alcohol × 0.79364 + water × 1.0) / 100 × 0.99798
///
/// where alcohol is proof over two and water is Table 6's figure. Checked
/// against the table's own specific-gravity-in-air column, this
/// reproduces it to within five thousandths of a percent from 101 to 150
/// proof -- the arithmetic the table was built with. On a full 750 the
/// difference is a few hundredths of a gram; the scale is the limit.
///
/// The tare (the empty bottle: glass, cork, label) is not looked up
/// anywhere; it is measured once, when the level is known -- a new bottle
/// is full -- and kept. After that, every weighing is a level.
public enum Weighing: Sendable {

    /// Water in air at 60 °F, 8.32823 lb per US gallon, in grams per ml.
    static let waterGramsPerMilliliter = 8.32823 * 453.59237 / 3785.411784
    /// 200 proof against water, in air: 6.6096 / 8.32823.
    static let absoluteAlcoholRelativeDensity = 6.6096 / 8.32823

    /// Grams per millilitre of a spirit at `proof`, in air at 60 °F. Nil
    /// outside Table 6's range.
    public static func density(proof: Double) -> Double? {
        guard let water = Proofing.waterParts(atProof: proof) else { return nil }
        let alcohol = proof / 2
        return (alcohol * absoluteAlcoholRelativeDensity + water) / 100 * waterGramsPerMilliliter
    }

    /// The empty bottle's weight, from one weighing at a known level.
    public static func tare(grossGrams: Double, knownMilliliters: Double, proof: Double) -> Double? {
        guard grossGrams > 0, knownMilliliters >= 0, let density = density(proof: proof) else { return nil }
        let tare = grossGrams - knownMilliliters * density
        return tare > 0 ? tare : nil
    }

    /// What is in the bottle, from its weight now.
    public static func remainingMilliliters(grossGrams: Double, tareGrams: Double, proof: Double) -> Double? {
        guard grossGrams > 0, tareGrams > 0, let density = density(proof: proof) else { return nil }
        return max(0, (grossGrams - tareGrams) / density)
    }
}
