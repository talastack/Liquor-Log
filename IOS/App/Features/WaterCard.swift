import SwiftUI
import LiquorEngine

/// How much water takes this pour down to the proof you want, by the
/// TTB's Table 6 -- the contraction of ethanol and water accounted for,
/// which a straight ratio gets wrong by nearly a part in twenty-five.
/// Only for a bottle whose proof is known and above the lowest target.
struct WaterCard: View {
    @AppStorage(VolumeDisplay.key) private var ounces = false

    /// The bottle's proof.
    let proof: Double
    /// The pour it will be added to, in ml.
    let pourMilliliters: Double

    @State private var target: Double = 100
    @State private var customTarget = ""
    @State private var splash = ""

    private static let targets: [Double] = [110, 100, 90, 80]

    var body: some View {
        VStack(alignment: .leading, spacing: Space.m) {
            SectionLabel("Water")

            HStack(spacing: Space.s) {
                ForEach(Self.targets.filter { $0 < proof }, id: \.self) { candidate in
                    Button {
                        target = candidate
                        customTarget = ""
                    } label: {
                        Text("\(Int(candidate))")
                            .font(TypeScale.code(13))
                            .foregroundStyle(target == candidate ? Palette.onGold : Palette.text)
                            .padding(.horizontal, Space.m)
                            .frame(minHeight: Space.tapTarget - 8)
                            .background(
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(target == candidate ? Palette.gold : Palette.surfaceRaised))
                    }
                    .buttonStyle(.plain)
                }
                TextField("proof", text: $customTarget)
                    .keyboardType(.decimalPad)
                    .font(TypeScale.code(13))
                    .foregroundStyle(Palette.text)
                    .padding(.horizontal, Space.m)
                    .frame(width: 76, height: Space.tapTarget - 8)
                    .background(RoundedRectangle(cornerRadius: 8).fill(Palette.surfaceRaised))
                    .onChange(of: customTarget) { _, text in
                        if let typed = Double(text), typed > 0 { target = typed }
                    }
            }

            if let water = Proofing.waterToAdd(from: proof, to: target, spiritMilliliters: pourMilliliters) {
                Text("Add \(Proofing.describe(waterMilliliters: water)) to a "
                     + "\(VolumeDisplay.text(pourMilliliters, ounces: ounces)) pour for \(Self.proofText(target)) proof.")
                    .font(TypeScale.body())
                    .foregroundStyle(Palette.text)
                    .fixedSize(horizontal: false, vertical: true)
            } else if target >= proof {
                Text("That is not lower than \(Self.proofText(proof)).")
                    .font(TypeScale.secondary())
                    .foregroundStyle(Palette.textMuted)
            } else {
                Text("Table 6 runs from \(Int(Proofing.lowestProof)) to \(Int(Proofing.highestProof)) proof.")
                    .font(TypeScale.secondary())
                    .foregroundStyle(Palette.textMuted)
            }

            HStack(spacing: Space.m) {
                Text("Added")
                    .font(TypeScale.secondary())
                    .foregroundStyle(Palette.textSecondary)
                TextField("ml of water", text: $splash)
                    .keyboardType(.decimalPad)
                    .font(TypeScale.code(13))
                    .foregroundStyle(Palette.text)
                    .padding(.horizontal, Space.m)
                    .frame(width: 110, height: Space.tapTarget - 8)
                    .background(RoundedRectangle(cornerRadius: 8).fill(Palette.surfaceRaised))
                if let ml = Double(splash), ml > 0,
                   let landed = Proofing.proofAfterAdding(waterMilliliters: ml, to: proof, spiritMilliliters: pourMilliliters) {
                    Text("→ about \(Self.proofText(landed)) proof")
                        .font(TypeScale.secondary())
                        .foregroundStyle(Palette.text)
                }
            }

            Text("TTB Gauging Manual, Table 6. Water and spirit contract when mixed, so this is more than the plain ratio.")
                .font(TypeScale.caption())
                .textCase(nil)
                .foregroundStyle(Palette.textMuted)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(Space.l)
        .background(RoundedRectangle(cornerRadius: 12).fill(Palette.surface))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Palette.line, lineWidth: 1))
        .onAppear {
            if let first = Self.targets.first(where: { $0 < proof }) { target = first }
        }
    }

    private static func proofText(_ proof: Double) -> String {
        proof == proof.rounded() ? String(Int(proof)) : String(format: "%.1f", proof)
    }
}
