import SwiftUI
import LiquorData
import LiquorEngine

/// "There is about this much left."
///
/// The pour log cannot answer that on its own — it assumes a bottle started
/// full and that every pour since was logged, and both are routinely false.
/// This is how somebody adds a bottle they opened two years ago, and how they
/// fix one they poured from at a party without reaching for a phone.
///
/// It does not erase anything. The pours stay logged; the fill is counted down
/// from this reading instead.
///
/// **Optional, and never a required step.** The research verdict on fill level
/// is contested: real demand on one side (*"track purchase location, cost,
/// bottle status (% full)"*) and open derision on the other (*"At least I don't
/// track fill level like some people, that seems extreme"*). So this screen is
/// somewhere you go, never somewhere you are sent. Nothing prompts for it and
/// nothing is worse for skipping it.
///
/// The capability itself is close to unserved: absent from Distiller,
/// Whiskybase, BAXUS, Whizzky, Drammer and Whiskey Searcher, and Whiskybase
/// Plus's workaround is letting you upload a photo of the fill line.
struct SetLevelView: View {
    @Environment(AppEnvironment.self) private var env
    @Environment(\.dismiss) private var dismiss

    let bottleId: String
    /// Called after a successful save, so the screen behind can reload.
    var onSave: (() -> Void)?

    @State private var summary: BottleSummary?
    @State private var percent: Double = 100
    @State private var millilitresText = ""
    @State private var note = ""
    @State private var error: String?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Space.xl) {
                if let summary {
                    preview(summary)
                    slider(summary)
                    presets(summary)
                    exact(summary)
                    noteField
                    saveButton(summary)
                    explanation
                } else {
                    ProgressView().padding(.top, 80)
                }
            }
            .padding(.horizontal, Space.xl)
            .padding(.top, Space.l)
            .padding(.bottom, 96)
        }
        .background(Palette.background)
        .navigationTitle("How much is left?")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") { dismiss() }.foregroundStyle(Palette.textSecondary)
            }
        }
        .task { load() }
        .alert("Could not save", isPresented: .constant(error != nil)) {
            Button("OK") { error = nil }
        } message: { Text(error ?? "") }
    }

    // MARK: - Sections

    private func preview(_ summary: BottleSummary) -> some View {
        VStack(spacing: Space.s) {
            Text(env.name(for: summary.bottle))
                .font(TypeScale.title())
                .foregroundStyle(Palette.text)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)

            Text("\(Int(shownPercent))%")
                .font(TypeScale.largeTitle())
                .foregroundStyle(Palette.gold)

            // Millilitres and pours travel with the percentage, because a
            // percentage on its own is the one number nobody can check against
            // the bottle in their hand.
            Text("\(Int(chosenMilliliters(summary).rounded())) ml · about \(pourCount(summary)) "
                 + "\(pourCount(summary) == 1 ? "pour" : "pours") left")
                .font(TypeScale.code(13))
                .foregroundStyle(Palette.textMuted)
        }
        .frame(maxWidth: .infinity)
    }

    private func slider(_ summary: BottleSummary) -> some View {
        VStack(alignment: .leading, spacing: Space.s) {
            Slider(value: $percent, in: 0...100, step: 1)
                .tint(Palette.gold)
                .onChange(of: percent) { _, _ in syncTextFromPercent(summary) }
            HStack {
                Text("Empty")
                Spacer()
                Text("Full")
            }
            .font(TypeScale.caption())
            .textCase(nil)
            .foregroundStyle(Palette.textMuted)
        }
    }

    /// The fractions people actually say out loud. Nobody eyeballs 63%.
    private func presets(_ summary: BottleSummary) -> some View {
        HStack(spacing: Space.s) {
            ForEach(Preset.allCases) { preset in
                Button {
                    percent = preset.percent
                    syncTextFromPercent(summary)
                } label: {
                    Text(preset.label)
                        .font(TypeScale.secondary())
                        .foregroundStyle(
                            isSelected(preset) ? Palette.onGold : Palette.textSecondary)
                        .frame(maxWidth: .infinity, minHeight: Space.tapTarget)
                        .background(RoundedRectangle(cornerRadius: 9)
                            .fill(isSelected(preset) ? Palette.gold : Palette.surfaceRaised))
                }
            }
        }
    }

    private func exact(_ summary: BottleSummary) -> some View {
        VStack(alignment: .leading, spacing: Space.xs + 2) {
            Text("Or type the millilitres")
                .font(TypeScale.caption())
                .textCase(nil)
                .foregroundStyle(Palette.textMuted)
            HStack(spacing: Space.m) {
                TextField("0", text: $millilitresText)
                    .font(TypeScale.body())
                    .foregroundStyle(Palette.text)
                    .keyboardType(.numberPad)
                    .padding(.horizontal, Space.m)
                    .frame(minHeight: 46)
                    .background(RoundedRectangle(cornerRadius: 10).fill(Palette.surface))
                    .overlay(RoundedRectangle(cornerRadius: 10)
                        .stroke(Palette.line, lineWidth: 1))
                    .onChange(of: millilitresText) { _, _ in syncPercentFromText(summary) }

                Text("of \(Int(summary.bottle.volumeMl.rounded())) ml")
                    .font(TypeScale.secondary())
                    .foregroundStyle(Palette.textMuted)
            }
        }
    }

    private var noteField: some View {
        VStack(alignment: .leading, spacing: Space.xs + 2) {
            Text("How did you measure it? (optional)")
                .font(TypeScale.caption())
                .textCase(nil)
                .foregroundStyle(Palette.textMuted)
            TextField("Eyeballed against the label", text: $note)
                .font(TypeScale.body())
                .foregroundStyle(Palette.text)
                .padding(.horizontal, Space.m)
                .frame(minHeight: 46)
                .background(RoundedRectangle(cornerRadius: 10).fill(Palette.surface))
                .overlay(RoundedRectangle(cornerRadius: 10).stroke(Palette.line, lineWidth: 1))
        }
    }

    private func saveButton(_ summary: BottleSummary) -> some View {
        Button { save(summary) } label: {
            Text("Save this level")
                .font(TypeScale.headline())
                .foregroundStyle(Palette.onGold)
                .frame(maxWidth: .infinity, minHeight: 50)
                .background(RoundedRectangle(cornerRadius: 11).fill(Palette.gold))
        }
    }

    private var explanation: some View {
        Text("This does not delete anything. The pours you logged stay logged — "
             + "the app just counts down from here instead.")
            .font(TypeScale.caption())
            .textCase(nil)
            .foregroundStyle(Palette.textMuted)
            .fixedSize(horizontal: false, vertical: true)
    }

    // MARK: - Presets

    enum Preset: String, CaseIterable, Identifiable {
        case full = "Full"
        case threeQuarters = "¾"
        case half = "½"
        case quarter = "¼"
        case heel = "Heel"

        var id: String { rawValue }
        var label: String { rawValue }

        var percent: Double {
            switch self {
            case .full: return 100
            case .threeQuarters: return 75
            case .half: return 50
            case .quarter: return 25
            case .heel: return 10
            }
        }
    }

    private func isSelected(_ preset: Preset) -> Bool {
        abs(shownPercent - preset.percent) < 0.5
    }

    // MARK: - Derivation

    /// The percentage AS SHOWN, and the only one anything derives from. A
    /// slider with `step: 1` does not always land on an exact integer, and
    /// showing "50%" beside "374 ml" on a 750 ml bottle is the app visibly
    /// disagreeing with itself.
    private var shownPercent: Double { percent.rounded() }

    private func chosenMilliliters(_ summary: BottleSummary) -> Double {
        PourMath.milliliters(percentFull: shownPercent, capacity: summary.bottle.volumeMl)
    }

    private func pourCount(_ summary: BottleSummary) -> Int {
        PourMath.pourCount(
            milliliters: chosenMilliliters(summary), pourSize: summary.bottle.pourSize)
    }

    // MARK: - Two-way binding

    private func syncTextFromPercent(_ summary: BottleSummary) {
        let millilitres = Int(chosenMilliliters(summary).rounded())
        if millilitresText != String(millilitres) { millilitresText = String(millilitres) }
    }

    private func syncPercentFromText(_ summary: BottleSummary) {
        guard let typed = Double(millilitresText) else { return }
        let next = PourMath.percentFull(
            remaining: typed, capacity: summary.bottle.volumeMl)
        if abs(next - percent) >= 0.5 { percent = next.rounded() }
    }

    // MARK: - Actions

    private func load() {
        do {
            let found = try env.bottles.summary(id: bottleId)
            summary = found
            if let found {
                percent = PourMath.percentFull(
                    remaining: found.status.remainingMilliliters,
                    capacity: found.bottle.volumeMl).rounded()
                syncTextFromPercent(found)
            }
        } catch {
            self.error = error.localizedDescription
        }
    }

    private func save(_ summary: BottleSummary) {
        do {
            try env.bottles.setLevel(
                bottleId: summary.id,
                remainingMl: chosenMilliliters(summary),
                note: note.isEmpty ? nil : note)
            onSave?()
            dismiss()
        } catch {
            self.error = error.localizedDescription
        }
    }
}

#Preview {
    NavigationStack { SetLevelView(bottleId: "fixture-weller-107") }
        .environment(AppEnvironment.preview())
        .preferredColorScheme(.dark)
}
