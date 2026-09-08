import SwiftUI
import LiquorData
import LiquorEngine

/// Record a tasting: nose, entry, mid, finish, a rating, and what you liked.
///
/// **Nothing here is required.** A rating on its own is a complete tasting.
/// Every optional field that becomes mandatory costs sessions, and sessions are
/// the only thing that produces the history the app is for.
struct TastingSheetView: View {
    @Environment(AppEnvironment.self) private var env
    @Environment(\.dismiss) private var dismiss

    let bottleId: String?
    var catalogProductId: String?

    /// The pour this tasting is of, when the sheet was opened from one.
    ///
    /// This is what turns a pile of tastings into a record of how a bottle
    /// changed after it was opened — each opinion pinned to a pour on a known
    /// date. Nil for a tasting at a bar, where there is no pour of your own.
    var pourId: String?

    @State private var rating: Int?
    @State private var rebuy: Rebuy?
    @State private var liked = ""
    @State private var disliked = ""
    @State private var picks: [TastingStage: [String]] = [:]
    @State private var editingStage: TastingStage?
    @State private var finishLength: FinishLength = .notRecorded
    @State private var error: String?

    init(bottleId: String? = nil, catalogProductId: String? = nil, pourId: String? = nil) {
        self.bottleId = bottleId
        self.catalogProductId = catalogProductId
        self.pourId = pourId
    }

    /// Bands, not a stopwatch. Nobody times a finish, but everybody can say
    /// whether it was gone straight away or still there a minute later — and
    /// that comparison between bottles is the thing free text loses.
    enum FinishLength: String, CaseIterable, Identifiable {
        case notRecorded = "—"
        case brief = "Brief"
        case medium = "Medium"
        case long = "Long"
        case veryLong = "Very long"

        var id: String { rawValue }

        /// Representative seconds for the band. Stored as a number so it can be
        /// compared and exported; shown as a band because that is the precision
        /// anybody actually has.
        var seconds: Int? {
            switch self {
            case .notRecorded: return nil
            case .brief: return 10
            case .medium: return 30
            case .long: return 60
            case .veryLong: return 120
            }
        }

        var caption: String {
            switch self {
            case .notRecorded: return "Not recorded"
            case .brief: return "Gone in a few seconds"
            case .medium: return "Around half a minute"
            case .long: return "About a minute"
            case .veryLong: return "Still there minutes later"
            }
        }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Space.xl) {
                ForEach(TastingStage.allCases, id: \.self) { stage in
                    stageRow(stage)
                }
                finishLengthRow
                ratingRow
                rebuyRow
                noteField("What you liked", text: $liked)
                noteField("What you did not", text: $disliked)
                saveButton
            }
            .padding(.horizontal, Space.xl)
            .padding(.top, Space.l)
            .padding(.bottom, 96)
        }
        .background(Palette.background)
        .navigationTitle("New tasting")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(item: $editingStage) { stage in
            NavigationStack {
                FlavourWheelPicker(
                    stage: stage,
                    selected: picks[stage] ?? [],
                    onDone: { keys in
                        picks[stage] = keys
                        editingStage = nil
                    })
            }
        }
        .alert("Could not save", isPresented: .constant(error != nil)) {
            Button("OK") { error = nil }
        } message: {
            Text(error ?? "")
        }
    }

    // MARK: - Sections

    private func stageRow(_ stage: TastingStage) -> some View {
        VStack(alignment: .leading, spacing: Space.m) {
            HStack(alignment: .firstTextBaseline) {
                SectionLabel(stage.rawValue)
                Spacer()
                Text(countLabel(for: stage))
                    .font(TypeScale.caption())
                    .textCase(nil)
                    .foregroundStyle(Palette.textMuted)
            }

            FlowChips {
                ForEach(picks[stage] ?? [], id: \.self) { key in
                    Text(env.wheel.descriptor(key)?.label ?? key)
                        .font(TypeScale.secondary())
                        .foregroundStyle(Palette.gold)
                        .padding(.horizontal, Space.m)
                        .frame(minHeight: Space.tapTarget)
                        .background(RoundedRectangle(cornerRadius: 9).fill(Palette.surfaceRaised))
                }
                Button { editingStage = stage } label: {
                    Text("Wheel")
                        .font(TypeScale.secondary().weight(.semibold))
                        .foregroundStyle(Palette.gold)
                        .padding(.horizontal, Space.m)
                        .frame(minHeight: Space.tapTarget)
                        .overlay(RoundedRectangle(cornerRadius: 9)
                            .stroke(Palette.gold, lineWidth: 1))
                }
            }
            Divider().overlay(Palette.line)
        }
    }

    private func countLabel(for stage: TastingStage) -> String {
        let count = picks[stage]?.count ?? 0
        return count == 0 ? "tap the wheel" : "\(count) picked"
    }

    private var ratingRow: some View {
        VStack(alignment: .leading, spacing: Space.m) {
            SectionLabel("Rating")
            HStack(spacing: Space.xs + 1) {
                ForEach(1...10, id: \.self) { value in
                    Button { rating = (rating == value) ? nil : value } label: {
                        Text("\(value)")
                            .font(TypeScale.secondary())
                            .foregroundStyle(value == rating ? Palette.onGold : Palette.textSecondary)
                            .frame(maxWidth: .infinity, minHeight: Space.tapTarget)
                            .background(RoundedRectangle(cornerRadius: 9)
                                .fill(value == rating ? Palette.gold : Palette.surfaceRaised))
                    }
                }
            }
        }
    }

    private var rebuyRow: some View {
        VStack(alignment: .leading, spacing: Space.m) {
            SectionLabel("Buy it again?")
            HStack(spacing: Space.s) {
                ForEach(Rebuy.allCases, id: \.self) { option in
                    Button { rebuy = (rebuy == option) ? nil : option } label: {
                        Text(option.rawValue.capitalized)
                            .font(TypeScale.body())
                            .foregroundStyle(option == rebuy ? Palette.onGold : Palette.textSecondary)
                            .frame(maxWidth: .infinity, minHeight: Space.tapTarget)
                            .background(RoundedRectangle(cornerRadius: 9)
                                .fill(option == rebuy ? Palette.gold : Palette.surfaceRaised))
                    }
                }
            }
        }
    }

    private func noteField(_ title: String, text: Binding<String>) -> some View {
        VStack(alignment: .leading, spacing: Space.m) {
            SectionLabel(title)
            TextField("Notes…", text: text, axis: .vertical)
                .font(TypeScale.body())
                .foregroundStyle(Palette.text)
                .lineLimit(2...6)
                .padding(Space.m)
                .background(RoundedRectangle(cornerRadius: 11).fill(Palette.surface))
                .overlay(RoundedRectangle(cornerRadius: 11).stroke(Palette.line, lineWidth: 1))
        }
    }

    /// Sits with the finish stage it describes, not with the rating.
    private var finishLengthRow: some View {
        VStack(alignment: .leading, spacing: Space.s) {
            SectionLabel("How long the finish lasted")
            Picker("Finish length", selection: $finishLength) {
                ForEach(FinishLength.allCases) { option in
                    Text(option.rawValue).tag(option)
                }
            }
            .pickerStyle(.segmented)
            Text(finishLength.caption)
                .font(TypeScale.caption())
                .textCase(nil)
                .foregroundStyle(Palette.textMuted)
        }
    }

    private var saveButton: some View {
        VStack(spacing: Space.m) {
            Button(action: save) {
                Text("Save tasting")
                    .font(TypeScale.headline())
                    .foregroundStyle(Palette.onGold)
                    .frame(maxWidth: .infinity, minHeight: 50)
                    .background(RoundedRectangle(cornerRadius: 11).fill(Palette.gold))
            }
            Text("Nothing is required. A rating on its own is a complete tasting.")
                .font(TypeScale.caption())
                .textCase(nil)
                .foregroundStyle(Palette.textMuted)
                .multilineTextAlignment(.center)
        }
    }

    // MARK: - Saving

    private func save() {
        let tasting = Tasting(
            bottleId: bottleId,
            catalogProductId: catalogProductId ?? resolvedProductId(),
            pourId: pourId,
            rating: rating,
            wouldRebuy: rebuy,
            finishSeconds: finishLength.seconds,
            liked: liked.isEmpty ? nil : liked,
            disliked: disliked.isEmpty ? nil : disliked)
        do {
            // Tasting and picks save in ONE transaction: a rating that survived
            // while its notes did not would be a silent loss.
            try env.tastings.save(tasting, descriptors: picks)
            dismiss()
        } catch {
            self.error = error.localizedDescription
        }
    }

    /// A tasting hangs off a product as well as a bottle, so the shelf check can
    /// still answer for it after the bottle is gone.
    private func resolvedProductId() -> String? {
        guard let bottleId else { return nil }
        return (try? env.bottles.summary(id: bottleId))?.bottle.catalogProductId
    }
}

extension TastingStage: Identifiable {
    public var id: String { rawValue }
}

/// Wraps chips onto as many lines as they need. No fixed height anywhere, so it
/// survives the largest accessibility type size.
struct FlowChips<Content: View>: View {
    @ViewBuilder var content: Content

    var body: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: Space.s) { content }
            VStack(alignment: .leading, spacing: Space.s) { content }
        }
    }
}

#Preview {
    NavigationStack {
        TastingSheetView(bottleId: "fixture-ec-bp")
    }
    .environment(AppEnvironment.preview())
    .preferredColorScheme(.dark)
}
