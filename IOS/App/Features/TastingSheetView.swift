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

    /// Called after a successful save, before the sheet dismisses. A flight
    /// uses it to move to the next glass.
    var onSaved: (() -> Void)?

    @State private var rating: Int?
    @State private var rebuy: Rebuy?
    @State private var liked = ""
    @State private var disliked = ""
    @State private var picks: [TastingStage: [String]] = [:]
    @State private var editingStage: TastingStage?
    @State private var finishLength: FinishLength = .notRecorded
    @State private var heat: PerceivedProof.Heat?
    @State private var error: String?

    // A tasting with no bottle of your own: what it was, and where.
    @State private var productQuery = ""
    @State private var chosenProduct: CatalogProduct?
    @State private var typedName = ""
    @State private var source: TastingSource?
    @State private var sourceNote = ""

    init(
        bottleId: String? = nil,
        catalogProductId: String? = nil,
        pourId: String? = nil,
        onSaved: (() -> Void)? = nil
    ) {
        self.bottleId = bottleId
        self.catalogProductId = catalogProductId
        self.pourId = pourId
        self.onSaved = onSaved
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
                if bottleId == nil {
                    if catalogProductId == nil {
                        whatWasIt
                    }
                    whereWasIt
                }
                ForEach(TastingStage.allCases, id: \.self) { stage in
                    stageRow(stage)
                }
                heatRow
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

    // MARK: - Not your bottle

    /// A tasting at a bar has to hang off a PRODUCT or the shelf check can
    /// never say "you tried this". Search the catalogue, or type a name and
    /// it becomes a private product, the same as a typed-in bottle.
    private var whatWasIt: some View {
        VStack(alignment: .leading, spacing: Space.m) {
            SectionLabel("What was it?")

            if let chosenProduct {
                HStack(alignment: .top, spacing: Space.m) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(chosenProduct.identity.displayName)
                            .font(TypeScale.title())
                            .foregroundStyle(Palette.text)
                        Text(chosenProduct.distillery)
                            .font(TypeScale.caption())
                            .textCase(nil)
                            .foregroundStyle(Palette.textMuted)
                    }
                    Spacer()
                    Button("Change") { self.chosenProduct = nil }
                        .font(TypeScale.secondary())
                        .foregroundStyle(Palette.gold)
                        .frame(minHeight: Space.tapTarget)
                }
                .padding(Space.l)
                .background(RoundedRectangle(cornerRadius: 12).fill(Palette.surface))
                .overlay(RoundedRectangle(cornerRadius: 12).stroke(Palette.gold, lineWidth: 1))
            } else {
                HStack(spacing: Space.m) {
                    Image(systemName: "magnifyingglass").foregroundStyle(Palette.textMuted)
                    TextField("Distillery, brand or expression", text: $productQuery)
                        .font(TypeScale.body())
                        .foregroundStyle(Palette.text)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)
                }
                .padding(.horizontal, Space.l)
                .frame(minHeight: 52)
                .background(RoundedRectangle(cornerRadius: 11).fill(Palette.surface))
                .overlay(RoundedRectangle(cornerRadius: 11).stroke(Palette.line, lineWidth: 1))

                ForEach(productMatches, id: \.id) { product in
                    Button { chosenProduct = product } label: {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(product.identity.displayName)
                                .font(TypeScale.body())
                                .foregroundStyle(Palette.text)
                                .multilineTextAlignment(.leading)
                            Text(product.distillery)
                                .font(TypeScale.caption())
                                .textCase(nil)
                                .foregroundStyle(Palette.textMuted)
                        }
                        .frame(maxWidth: .infinity, minHeight: Space.tapTarget, alignment: .leading)
                    }
                    Divider().overlay(Palette.line)
                }

                TextField("Or type a name", text: $typedName)
                    .font(TypeScale.body())
                    .foregroundStyle(Palette.text)
                    .padding(.horizontal, Space.m)
                    .frame(minHeight: 46)
                    .background(RoundedRectangle(cornerRadius: 10).fill(Palette.surface))
                    .overlay(RoundedRectangle(cornerRadius: 10).stroke(Palette.line, lineWidth: 1))
            }
        }
    }

    private var productMatches: [CatalogProduct] {
        let trimmed = productQuery.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return [] }
        let candidates = env.catalog.searchCandidates(history: env.historyProductIds())
        return BottleSearch.search(query: trimmed, in: candidates, limit: 6)
            .compactMap { env.catalog.product($0.product.productId) }
    }

    /// Where it happened. A 30 ml pour at a bar after two others is a
    /// different kind of evidence from a quiet glass at home, and the record
    /// should say which.
    private var whereWasIt: some View {
        VStack(alignment: .leading, spacing: Space.m) {
            SectionLabel("Where?")
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: Space.s) {
                    ForEach(TastingSource.allCases, id: \.self) { option in
                        Button { source = source == option ? nil : option } label: {
                            Text(option.label)
                                .font(TypeScale.secondary())
                                .foregroundStyle(source == option ? Palette.onGold : Palette.textSecondary)
                                .padding(.horizontal, Space.l)
                                .frame(minHeight: Space.tapTarget - 8)
                                .background(RoundedRectangle(cornerRadius: 9)
                                    .fill(source == option ? Palette.gold : Palette.surfaceRaised))
                        }
                    }
                }
            }
            if source != nil {
                TextField(sourcePlaceholder, text: $sourceNote)
                    .font(TypeScale.body())
                    .foregroundStyle(Palette.text)
                    .padding(.horizontal, Space.m)
                    .frame(minHeight: 46)
                    .background(RoundedRectangle(cornerRadius: 10).fill(Palette.surface))
                    .overlay(RoundedRectangle(cornerRadius: 10).stroke(Palette.line, lineWidth: 1))
            }
        }
    }

    private var sourcePlaceholder: String {
        switch source {
        case .bar: return "Which bar (optional)"
        case .friend: return "Whose bottle (optional)"
        case .sample: return "Who sent it (optional)"
        case .store: return "Which store (optional)"
        case .event: return "Which event (optional)"
        case .other, nil: return "Where (optional)"
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

    /// Does it drink like its proof?
    ///
    /// Your own idea, and still the field nothing else has. A barrel-proof
    /// bourbon that goes down easy is a different bottle from one that
    /// scorches at the same strength, and the label cannot tell you which you
    /// have. It is the reason people chase cask strength at all.
    ///
    /// Shown whenever the tasting has a bottle, and the STRENGTH only gates the
    /// verdict. It used to gate the whole section, which meant that on a
    /// barrel-proof bottle nobody had typed a proof into — exactly the bottles
    /// this question is for — the feature silently did not exist.
    ///
    /// Recording that something drank hot is worth keeping on its own. The
    /// comparison is a bonus, and when it is missing the app says what is
    /// needed rather than hiding.
    @ViewBuilder
    private var heatRow: some View {
        if bottleId != nil {
            VStack(alignment: .leading, spacing: Space.s) {
                SectionLabel("How hot did it drink?")

                HStack(spacing: Space.s) {
                    ForEach(PerceivedProof.Heat.allCases, id: \.self) { option in
                        Button {
                            heat = (heat == option) ? nil : option
                        } label: {
                            Text(option.label)
                                .font(TypeScale.caption())
                                .textCase(nil)
                                .foregroundStyle(
                                    heat == option ? Palette.onGold : Palette.textSecondary)
                                .frame(maxWidth: .infinity, minHeight: Space.tapTarget)
                                .background(RoundedRectangle(cornerRadius: 9)
                                    .fill(heat == option ? Palette.gold : Palette.surfaceRaised))
                        }
                    }
                }

                if let abv = bottleABV {
                    if let heat {
                        let result = PerceivedProof.compare(abv: abv, felt: heat)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(result.headline)
                                .font(TypeScale.body())
                                .foregroundStyle(tint(result.verdict))
                            Text(result.summary)
                                .font(TypeScale.caption())
                                .textCase(nil)
                                .foregroundStyle(Palette.textMuted)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    } else {
                        Text(String(format: "%.1f proof usually drinks ", abv.proof)
                             + PerceivedProof.expectedHeat(for: abv).label.lowercased() + ".")
                            .font(TypeScale.caption())
                            .textCase(nil)
                            .foregroundStyle(Palette.textMuted)
                    }
                } else {
                    // Actionable rather than absent. This is the barrel-proof
                    // case, which is precisely where the comparison is worth
                    // the most.
                    Text("Add the proof on this bottle and the app will tell you "
                         + "whether it drinks above or below it.")
                        .font(TypeScale.caption())
                        .textCase(nil)
                        .foregroundStyle(Palette.textMuted)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
    }

    private func tint(_ verdict: PerceivedProof.Verdict) -> Color {
        switch verdict {
        case .drinksBelowItsProof: return Palette.good
        case .drinksAtItsProof: return Palette.textSecondary
        case .drinksAboveItsProof: return Palette.gold
        }
    }

    /// The bottle's MEASURED strength, falling back to the catalogue figure.
    /// Nil for a barrel-proof release nobody has read off the label yet, which
    /// is exactly when a comparison would be meaningless.
    private var bottleABV: ABV? {
        guard let bottleId,
              let bottle = (try? env.bottles.summary(id: bottleId))?.bottle
        else { return nil }
        if let abv = bottle.abv { return ABV(percent: abv) }
        return env.product(for: bottle)?.abv.map { ABV(percent: $0) }
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
        do {
            let productId = try catalogProductId ?? resolvedProductId() ?? productForTypedName()
            let tasting = Tasting(
                bottleId: bottleId,
                catalogProductId: productId,
                pourId: pourId,
                rating: rating,
                wouldRebuy: rebuy,
                perceivedHeat: heat?.rawValue,
                finishSeconds: finishLength.seconds,
                source: bottleId == nil ? source : nil,
                sourceNote: bottleId == nil && !sourceNote.isEmpty ? sourceNote : nil,
                liked: liked.isEmpty ? nil : liked,
                disliked: disliked.isEmpty ? nil : disliked)
            // Tasting and picks save in ONE transaction: a rating that survived
            // while its notes did not would be a silent loss.
            try env.tastings.save(tasting, descriptors: picks)
            onSaved?()
            dismiss()
        } catch {
            self.error = error.localizedDescription
        }
    }

    /// The chosen catalogue product, or a private one made from the typed
    /// name. Nil when neither was given: a rating with no subject is still
    /// allowed, it just cannot answer a shelf check.
    private func productForTypedName() throws -> String? {
        if let chosenProduct { return chosenProduct.id }
        let name = typedName.trimmingCharacters(in: .whitespaces)
        guard !name.isEmpty else { return nil }
        return try env.bottles.saveCustomProduct(
            CustomCatalogEntry(distillery: name, brand: name, classType: .bourbon)).id
    }

    /// A tasting hangs off a product as well as a bottle, so the shelf check can
    /// still answer for it after the bottle is gone.
    private func resolvedProductId() throws -> String? {
        guard let bottleId else { return nil }
        return try env.bottles.summary(id: bottleId)?.bottle.catalogProductId
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
