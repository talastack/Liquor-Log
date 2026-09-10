import SwiftUI
import LiquorData
import LiquorEngine

/// One bottle: what is left, what it cost, what it is, and how it is holding up.
struct BottleDetailView: View {
    @Environment(AppEnvironment.self) private var env
    let bottleId: String

    @State private var summary: BottleSummary?
    @State private var error: String?

    /// The pour just logged on this screen, if any.
    ///
    /// While it is set, a tasting recorded here is attached to THAT pour rather
    /// than floating loose against the bottle. That link is what lets the app
    /// show how a bottle changed as it sat open, instead of only asserting that
    /// it did.
    @State private var justPouredId: String?
    @State private var isSettingLevel = false
    @State private var isEditing = false
    /// What you paid for OTHER bottles of this product. Excludes this one --
    /// comparing a price against itself always reports "about what you usually
    /// pay".
    @State private var priceHistory: PriceHistory.Summary?

    /// The shelf price to compare against, from every bottle of this product
    /// INCLUDING this one.
    ///
    /// A separate load on purpose. These are two different questions and one
    /// query cannot answer both: derived from `priceHistory`, the shelf price
    /// you just typed onto your only bottle would be invisible on the very
    /// screen you typed it into.
    @State private var shelfReference: PriceReference?

    var body: some View {
        ScrollView {
            if let summary {
                VStack(alignment: .leading, spacing: Space.xl) {
                    hero(summary)
                    fill(summary)
                    if let estimate = oxidation(summary) {
                        OxidationCard(estimate: estimate)
                    }
                    priceCard(summary)
                    facts(summary)
                    if summary.bottle.hasPickDetail {
                        pickDetail(summary)
                    }
                    if hasLocation(summary) {
                        whereItIs(summary)
                    }
                    actions(summary)
                }
                .padding(.horizontal, Space.xl)
                .padding(.bottom, 96)
            } else {
                ProgressView().padding(.top, 80)
            }
        }
        .background(Palette.background)
        .navigationBarTitleDisplayMode(.inline)
        .task { reload() }
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button("Edit") { isEditing = true }
                    .foregroundStyle(Palette.gold)
            }
        }
        .sheet(isPresented: $isEditing) {
            NavigationStack {
                EditBottleView(bottleId: bottleId, onSave: { reload() })
            }
        }
        .sheet(isPresented: $isSettingLevel) {
            NavigationStack {
                SetLevelView(bottleId: bottleId, onSave: { reload() })
            }
        }
        .alert("Something went wrong", isPresented: .constant(error != nil)) {
            Button("OK") { error = nil }
        } message: {
            Text(error ?? "")
        }
    }

    // MARK: - Sections

    private func hero(_ summary: BottleSummary) -> some View {
        VStack(spacing: Space.m) {
            BottleMark(height: 104)
            if let distillery = env.distillery(for: summary.bottle) {
                SectionLabel(distillery)
            }
            Text(env.name(for: summary.bottle))
                .font(TypeScale.largeTitle())
                .foregroundStyle(Palette.text)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)

            if let rating = summary.latestRating {
                RatingChip(rating: rating)
            }

            Text(strength(summary))
                .font(TypeScale.code(14))
                .foregroundStyle(Palette.textMuted)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, Space.s)
    }

    private func fill(_ summary: BottleSummary) -> some View {
        VStack(alignment: .leading, spacing: Space.m) {
            HStack {
                SectionLabel("Fill level")
                Spacer()
                // The pour log cannot know about the bottle you opened two
                // years ago or the pours you pulled at a party. This is the
                // way to tell it.
                Button { isSettingLevel = true } label: {
                    Text("Set level")
                        .font(TypeScale.secondary())
                        .foregroundStyle(Palette.gold)
                        .frame(minHeight: Space.tapTarget)
                }
            }
            FillBar(status: summary.status)

            HStack {
                if let days = summary.daysOpen() {
                    Text("Open \(days) \(days == 1 ? "day" : "days")")
                        .font(TypeScale.secondary())
                        .foregroundStyle(Palette.textSecondary)
                } else {
                    Text("Unopened")
                        .font(TypeScale.secondary())
                        .foregroundStyle(Palette.textSecondary)
                }
                Spacer()
                if let cents = summary.costPerPourCents {
                    Text("\(Money.short(cents)) a pour")
                        .font(TypeScale.secondary())
                        .foregroundStyle(Palette.gold)
                }
            }

            // Stated as a fact, never as a prompt. People use it to dig out a
            // bottle they liked and forgot about; nothing here suggests that
            // pouring more often would be better.
            if let days = summary.daysSinceLastPour() {
                Text(days == 0
                     ? "Last poured today"
                     : "Last poured \(days) \(days == 1 ? "day" : "days") ago")
                    .font(TypeScale.secondary())
                    .foregroundStyle(Palette.textSecondary)
            }
        }
    }

    private func facts(_ summary: BottleSummary) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            SectionLabel("What it is")
                .padding(.bottom, Space.xs)

            // Class and production are ALWAYS two rows. Kentucky Straight is
            // one fact; small batch is another. Merging them is what makes an
            // app unable to answer "do I have this, or do I have this type?"
            if let product = env.product(for: summary.bottle) {
                FactRow(label: "Class", value: classLabel(product.classType))
                FactRow(label: "How it is made", value: productionLabel(product))
            }
            if let batch = summary.bottle.batchNumber {
                // Decoded where the scheme is known. "B523" on its own is a
                // string; "second release of 2023, bottled in May" is a fact
                // about the whiskey.
                FactRow(
                    label: "Batch",
                    value: BatchCode(batch).map { "\(batch) · \($0.summary)" } ?? batch)
            }
            // Barrel, pick and recipe live in "This barrel" below when the
            // bottle carries them. Printing them twice reads as a bug.
            if summary.bottle.code == nil,
               let code = env.product(for: summary.bottle)?.code {
                FactRow(label: "Recipe", value: "\(code.code) · \(code.yeast.character)")
                FactRow(label: "Mashbill", value: code.mashbill.summary)
            }
            if let filtered = summary.bottle.chillFiltered {
                FactRow(
                    label: "Chill filtration",
                    value: filtered ? "Chill filtered" : "Non-chill filtered")
            }
            if let bought = summary.bottle.purchaseDate {
                FactRow(
                    label: "Bought",
                    value: Date(timeIntervalSince1970: Double(bought) / 1000)
                        .formatted(date: .abbreviated, time: .omitted))
            }
            if let store = summary.bottle.purchaseStore {
                FactRow(label: "Bought at", value: store)
            }
            FactRow(
                label: "Size",
                value: "\(Int(summary.bottle.volumeMl.rounded())) ml",
                isLast: true)
        }
    }

    /// What it cost, what a pour costs, and what you have paid before.
    private func priceCard(_ summary: BottleSummary) -> some View {
        PriceCard(
            paidCents: summary.bottle.purchasePriceCents,
            capacityMilliliters: summary.bottle.volumeMl,
            pourSize: summary.bottle.pourSize,
            history: priceHistory,
            // YOUR OWN shelf sightings first. A bundled figure is somebody
            // else's data with a licence attached and no board has been
            // imported, so in practice this is always the user's own record --
            // which is the point.
            reference: shelfReference
                ?? env.product(for: summary.bottle)?.priceReference)
    }

    /// The barrel's own facts. This is the section most apps do not have, and
    /// the reason somebody who buys picks would keep using this one.
    private func pickDetail(_ summary: BottleSummary) -> some View {
        let bottle = summary.bottle
        return VStack(alignment: .leading, spacing: 0) {
            SectionLabel("This barrel")
                .padding(.bottom, Space.xs)

            if let group = bottle.pickGroup {
                FactRow(label: "Selected by", value: group)
            }
            if let store = bottle.pickStore, bottle.isStorePick {
                FactRow(label: "Picked at", value: store)
            }
            // The barrel number was being captured and never shown anywhere.
            // On a product built around barrel identity that is the one field
            // least allowed to go missing.
            if let barrel = bottle.barrelNumber {
                FactRow(label: "Barrel", value: barrel)
            }
            // Three rows, not one. A Blanton's label prints warehouse, rick and
            // floor separately, and people follow a specific rick across
            // releases — which only works if they were never merged.
            if let warehouse = bottle.warehouse {
                FactRow(label: "Warehouse", value: warehouse)
            }
            if let rick = bottle.rick {
                FactRow(label: "Rick", value: rick)
            }
            if let floor = bottle.floor {
                FactRow(label: "Floor", value: floor)
            }
            if let dumped = bottle.dumpedAt {
                FactRow(
                    label: "Dumped",
                    value: Date(timeIntervalSince1970: Double(dumped) / 1000)
                        .formatted(date: .abbreviated, time: .omitted))
            }
            if let code = bottle.code {
                FactRow(label: "Recipe", value: "\(code.code) · \(code.yeast.character)")
                FactRow(label: "Mashbill", value: code.mashbill.summary)
            }
            if let age = bottle.ageDescription {
                FactRow(label: "Age at bottling", value: age)
            }
            if let entry = bottle.entryProof {
                FactRow(label: "Entry proof", value: String(format: "%.1f", entry))
            }
            if let char = bottle.charLevel {
                FactRow(label: "Char", value: "#\(char)")
            }
            if let finish = bottle.finish {
                FactRow(label: "Finish", value: finish)
            }
            if let numbered = bottle.bottleNumberDescription {
                FactRow(label: "Bottle", value: numbered, isLast: true)
            }
        }
    }

    /// Where the bottle physically is, and the walk that keeps that honest.
    ///
    /// People report this mattering more than remembering what they own:
    /// *"I learned it is MORE important to remember WHERE I put the stuff."*
    private func whereItIs(_ summary: BottleSummary) -> some View {
        let bottle = summary.bottle
        return VStack(alignment: .leading, spacing: 0) {
            SectionLabel("Where you keep it")
                .padding(.bottom, Space.xs)

            if let location = bottle.storageLocation {
                FactRow(label: "Location", value: location)
            }
            if let number = bottle.shelfNumber {
                FactRow(label: "Your number", value: "#\(number)")
            }
            FactRow(
                label: "Last checked",
                value: lastChecked(bottle),
                isLast: true)
        }
    }

    private func hasLocation(_ summary: BottleSummary) -> Bool {
        summary.bottle.storageLocation != nil
            || summary.bottle.shelfNumber != nil
            || summary.bottle.lastVerifiedAt != nil
    }

    private func lastChecked(_ bottle: Bottle) -> String {
        guard let verified = bottle.lastVerifiedAt else { return "Never" }
        return Date(timeIntervalSince1970: Double(verified) / 1000)
            .formatted(date: .abbreviated, time: .omitted)
    }

    private func actions(_ summary: BottleSummary) -> some View {
        HStack(spacing: Space.m) {
            Button {
                logPour(summary)
            } label: {
                Text(summary.status.isEmpty ? "Empty" : "Log a pour")
                    .font(TypeScale.headline())
                    .foregroundStyle(Palette.onGold)
                    .frame(maxWidth: .infinity, minHeight: 50)
                    .background(RoundedRectangle(cornerRadius: 11).fill(Palette.gold))
            }
            .disabled(summary.status.isEmpty)
            .opacity(summary.status.isEmpty ? 0.5 : 1)

            NavigationLink {
                TastingSheetView(bottleId: summary.id, pourId: justPouredId)
            } label: {
                Text(justPouredId == nil ? "New tasting" : "Taste this pour")
                    .font(TypeScale.headline())
                    .foregroundStyle(Palette.text)
                    .frame(maxWidth: .infinity, minHeight: 50)
                    .overlay(RoundedRectangle(cornerRadius: 11).stroke(Palette.line, lineWidth: 1))
            }
        }
    }

    // MARK: - Derivation

    private func oxidation(_ summary: BottleSummary) -> OxidationBand.Estimate? {
        guard let days = summary.daysOpen() else { return nil }
        return OxidationBand.estimate(fillLevel: summary.fillLevel, daysOpen: days)
    }

    private func strength(_ summary: BottleSummary) -> String {
        if let abv = summary.bottle.abv {
            let value = ABV(percent: abv)
            return String(format: "%.1f%% ABV · %.1f proof", value.percent, value.proof)
        }
        return env.product(for: summary.bottle)?.strengthDescription ?? "Strength not recorded"
    }

    private func classLabel(_ type: ClassType) -> String {
        switch type {
        case .kentuckyStraightBourbon: return "Kentucky Straight Bourbon Whiskey"
        case .straightBourbon: return "Straight Bourbon Whiskey"
        case .bourbon: return "Bourbon Whiskey"
        case .blendOfStraightBourbon: return "Blend of Straight Bourbon Whiskeys"
        case .straightRye: return "Straight Rye Whiskey"
        case .rye: return "Rye Whiskey"
        case .maltBeverage: return "Malt Beverage"
        default: return type.rawValue
        }
    }

    private func productionLabel(_ product: CatalogProduct) -> String {
        var parts: [String] = []
        switch product.productionType {
        case .singleBarrel: parts.append("Single barrel")
        case .smallBatch: parts.append("Small batch")
        case .blend: parts.append("Blend")
        case .singleCask: parts.append("Single cask")
        case .unspecified: break
        }
        if product.isBarrelProof { parts.append("barrel proof") }
        if product.isBottledInBond { parts.append("bottled in bond") }
        return parts.isEmpty ? "Not stated on the label" : parts.joined(separator: " · ")
    }

    // MARK: - Actions

    private func reload() {
        do {
            summary = try env.bottles.summary(id: bottleId)
            // Excluding this bottle: comparing a price against itself would
            // always report "about what you usually pay".
            if let productId = summary?.bottle.catalogProductId {
                priceHistory = PriceHistory.summarise(
                    try env.bottles.purchaseHistory(
                        catalogProductId: productId, excluding: bottleId))

                // Not excluding this bottle. Its own shelf price is a sighting
                // like any other, and the most common collection has exactly
                // one bottle of a thing.
                shelfReference = PriceHistory.shelfReference(
                    try env.bottles.purchaseHistory(catalogProductId: productId))
            }
        } catch {
            self.error = error.localizedDescription
        }
    }

    private func logPour(_ summary: BottleSummary) {
        do {
            justPouredId = try env.bottles.logPour(bottleId: summary.id).id
            reload()
        } catch DataError.bottleIsEmpty {
            error = "That bottle is empty."
        } catch {
            self.error = error.localizedDescription
        }
    }
}

/// The oxidation estimate, always with its hedge attached.
struct OxidationCard: View {
    let estimate: OxidationBand.Estimate

    var body: some View {
        VStack(alignment: .leading, spacing: Space.m) {
            HStack(alignment: .firstTextBaseline) {
                Text(estimate.band.label)
                    .font(TypeScale.headline())
                    .foregroundStyle(tint)
                Spacer()
                Text("\(estimate.headroomPercent)% air")
                    .font(TypeScale.code(13))
                    .foregroundStyle(Palette.textMuted)
            }

            HStack(spacing: Space.xs + 2) {
                ForEach(OxidationBand.Band.allCases, id: \.self) { band in
                    Capsule()
                        .fill(band == estimate.band ? tint : Palette.surfaceRaised)
                        .frame(height: 6)
                }
            }

            Text(estimate.summary)
                .font(TypeScale.secondary())
                .foregroundStyle(Palette.textSecondary)
                .fixedSize(horizontal: false, vertical: true)

            // Never optional. An estimate presented confidently that nobody has
            // measured is worse than no estimate at all.
            Text(estimate.caveat)
                .font(TypeScale.caption())
                .textCase(nil)
                .foregroundStyle(Palette.textMuted)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, Space.xs)
        }
        .padding(Space.l)
        .background(RoundedRectangle(cornerRadius: 12).fill(Palette.surface))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(tint.opacity(0.35), lineWidth: 1))
    }

    private var tint: Color {
        switch estimate.band {
        case .fresh, .peak: return Palette.good
        case .fading: return Palette.gold
        case .faded: return Palette.bad
        }
    }
}

#Preview {
    NavigationStack {
        BottleDetailView(bottleId: "fixture-weller-107")
    }
    .environment(AppEnvironment.preview())
    .preferredColorScheme(.dark)
}
