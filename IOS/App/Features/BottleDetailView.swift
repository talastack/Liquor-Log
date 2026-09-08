import SwiftUI
import LiquorData
import LiquorEngine

/// One bottle: what is left, what it cost, what it is, and how it is holding up.
struct BottleDetailView: View {
    @Environment(AppEnvironment.self) private var env
    let bottleId: String

    @State private var summary: BottleSummary?
    @State private var error: String?

    var body: some View {
        ScrollView {
            if let summary {
                VStack(alignment: .leading, spacing: Space.xl) {
                    hero(summary)
                    fill(summary)
                    if let estimate = oxidation(summary) {
                        OxidationCard(estimate: estimate)
                    }
                    facts(summary)
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
            SectionLabel("Fill level")
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
                FactRow(label: "Batch", value: batch)
            }
            if summary.bottle.isStorePick {
                if let barrel = summary.bottle.barrelNumber {
                    FactRow(label: "Barrel", value: barrel)
                }
                if let store = summary.bottle.pickStore {
                    FactRow(label: "Picked by", value: store)
                }
            }
            if let code = env.product(for: summary.bottle)?.code {
                FactRow(label: "Recipe", value: "\(code.code) · \(code.yeast.character)")
                FactRow(label: "Mashbill", value: code.mashbill.summary)
            }
            if let paid = summary.bottle.purchasePriceCents {
                FactRow(label: "Paid", value: Money.short(paid))
            }
            FactRow(
                label: "Size",
                value: "\(Int(summary.bottle.volumeMl.rounded())) ml",
                isLast: true)
        }
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
                TastingSheetView(bottleId: summary.id)
            } label: {
                Text("New tasting")
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
        } catch {
            self.error = error.localizedDescription
        }
    }

    private func logPour(_ summary: BottleSummary) {
        do {
            try env.bottles.logPour(bottleId: summary.id)
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
