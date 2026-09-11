import SwiftUI
import LiquorData
import LiquorEngine

/// Two to four open bottles, tasted side by side -- blind if you like.
///
/// A flight is how enthusiasts actually compare: the same pour from each,
/// the same evening, one against the other. Blind is the part they talk
/// about most, because it is the only way to find out whether the $300
/// bottle beats the $30 one without the label voting. So the glasses are
/// A, B, C, D until every one is rated, and only then do the names come
/// back, ranked by what you said.
///
/// Every glass logs a real pour of the size you choose and every rating is
/// a real tasting pinned to that pour, so a flight leaves the same record
/// four separate evenings would. Nothing here counts flights or glasses
/// over time; the screen is about tonight.
struct FlightView: View {
    @Environment(AppEnvironment.self) private var env
    @Environment(\.dismiss) private var dismiss

    struct Glass: Identifiable {
        let letter: String
        let summary: BottleSummary
        var pourId: String?
        var rating: Int?
        var tasted = false
        var id: String { summary.id }
    }

    @State private var open: [BottleSummary] = []
    @State private var chosen: [String] = []
    @State private var glasses: [Glass] = []
    @State private var isBlind = true
    @State private var pourOunces = 0.5
    @State private var tasting: Glass?
    @State private var error: String?

    private var stage: Stage {
        if glasses.isEmpty { return .choosing }
        return glasses.allSatisfy(\.tasted) ? .revealed : .tasting
    }

    private enum Stage { case choosing, tasting, revealed }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Space.xl) {
                switch stage {
                case .choosing: choosing
                case .tasting: tastingList
                case .revealed: revealed
                }
            }
            .padding(.horizontal, Space.xl)
            .padding(.top, Space.l)
            .padding(.bottom, 96)
        }
        .background(Palette.background)
        .navigationTitle("A flight")
        .navigationBarTitleDisplayMode(.inline)
        .task { load() }
        .sheet(item: $tasting) { glass in
            NavigationStack {
                TastingSheetView(
                    bottleId: glass.summary.id,
                    pourId: glass.pourId,
                    onSaved: { markTasted(glass.id) })
                .navigationTitle(isBlind ? "Glass \(glass.letter)" : env.name(for: glass.summary.bottle))
            }
        }
        .alert("Something went wrong", isPresented: .constant(error != nil)) {
            Button("OK") { error = nil }
        } message: { Text(error ?? "") }
    }

    // MARK: - Choosing

    private var choosing: some View {
        VStack(alignment: .leading, spacing: Space.l) {
            VStack(alignment: .leading, spacing: Space.xs) {
                Text("Pick two to four open bottles")
                    .font(TypeScale.largeTitle())
                    .foregroundStyle(Palette.text)
                Text("Each gets the same pour and its own tasting. Blind hides the "
                     + "names until every glass is rated.")
                    .font(TypeScale.secondary())
                    .foregroundStyle(Palette.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            if open.count < 2 {
                Text("A flight needs at least two open bottles.")
                    .font(TypeScale.secondary())
                    .foregroundStyle(Palette.textMuted)
            }

            ForEach(open) { summary in
                Button { toggle(summary.id) } label: {
                    HStack(spacing: Space.m) {
                        Image(systemName: chosen.contains(summary.id) ? "checkmark.circle.fill" : "circle")
                            .foregroundStyle(chosen.contains(summary.id) ? Palette.gold : Palette.textMuted)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(env.name(for: summary.bottle))
                                .font(TypeScale.body())
                                .foregroundStyle(Palette.text)
                                .multilineTextAlignment(.leading)
                            Text("\(summary.status.remainingPours) pours left")
                                .font(TypeScale.caption())
                                .textCase(nil)
                                .foregroundStyle(Palette.textMuted)
                        }
                        Spacer()
                    }
                    .padding(Space.l)
                    .frame(maxWidth: .infinity, minHeight: Space.tapTarget, alignment: .leading)
                    .background(RoundedRectangle(cornerRadius: 12).fill(Palette.surface))
                    .overlay(RoundedRectangle(cornerRadius: 12)
                        .stroke(chosen.contains(summary.id) ? Palette.gold : Palette.line, lineWidth: 1))
                }
            }

            VStack(alignment: .leading, spacing: Space.m) {
                Toggle(isOn: $isBlind) {
                    Text("Blind — letters until the end")
                        .font(TypeScale.body())
                        .foregroundStyle(Palette.text)
                }
                .tint(Palette.gold)

                HStack(spacing: Space.s) {
                    Text("Pour")
                        .font(TypeScale.secondary())
                        .foregroundStyle(Palette.textSecondary)
                    ForEach([0.5, 1.0, 1.5], id: \.self) { oz in
                        Button { pourOunces = oz } label: {
                            Text(oz == 1 ? "1 oz" : String(format: "%.1f oz", oz))
                                .font(TypeScale.secondary())
                                .foregroundStyle(pourOunces == oz ? Palette.onGold : Palette.textSecondary)
                                .padding(.horizontal, Space.l)
                                .frame(minHeight: Space.tapTarget - 8)
                                .background(RoundedRectangle(cornerRadius: 9)
                                    .fill(pourOunces == oz ? Palette.gold : Palette.surfaceRaised))
                        }
                    }
                }
            }
            .padding(Space.l)
            .background(RoundedRectangle(cornerRadius: 12).fill(Palette.surface))
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(Palette.line, lineWidth: 1))

            Button(action: pour) {
                Text(chosen.count < 2 ? "Pick at least two" : "Pour the flight")
                    .font(TypeScale.headline())
                    .foregroundStyle(Palette.onGold)
                    .frame(maxWidth: .infinity, minHeight: 50)
                    .background(RoundedRectangle(cornerRadius: 11)
                        .fill(chosen.count >= 2 ? Palette.gold : Palette.surfaceRaised))
            }
            .disabled(chosen.count < 2)
        }
    }

    // MARK: - Tasting

    private var tastingList: some View {
        VStack(alignment: .leading, spacing: Space.l) {
            VStack(alignment: .leading, spacing: Space.xs) {
                Text(isBlind ? "Taste each glass" : "Taste each bottle")
                    .font(TypeScale.largeTitle())
                    .foregroundStyle(Palette.text)
                Text(isBlind
                     ? "Names come back once every glass is rated. Have somebody else pour if you can."
                     : "Poured. Rate each one in any order.")
                    .font(TypeScale.secondary())
                    .foregroundStyle(Palette.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            ForEach(glasses) { glass in
                Button { tasting = glass } label: {
                    HStack(spacing: Space.m) {
                        Text(glass.letter)
                            .font(TypeScale.title())
                            .foregroundStyle(Palette.gold)
                            .frame(width: 36)
                        Text(isBlind ? "Glass \(glass.letter)" : env.name(for: glass.summary.bottle))
                            .font(TypeScale.body())
                            .foregroundStyle(Palette.text)
                            .multilineTextAlignment(.leading)
                        Spacer()
                        if glass.tasted {
                            if let rating = glass.rating {
                                RatingChip(rating: rating)
                            } else {
                                Image(systemName: "checkmark").foregroundStyle(Palette.good)
                            }
                        } else {
                            Text("Rate")
                                .font(TypeScale.secondary())
                                .foregroundStyle(Palette.gold)
                        }
                    }
                    .padding(Space.l)
                    .frame(maxWidth: .infinity, minHeight: Space.tapTarget, alignment: .leading)
                    .background(RoundedRectangle(cornerRadius: 12).fill(Palette.surface))
                    .overlay(RoundedRectangle(cornerRadius: 12).stroke(Palette.line, lineWidth: 1))
                }
                .disabled(glass.tasted)
            }
        }
    }

    // MARK: - Revealed

    private var revealed: some View {
        let ranked = glasses.sorted { ($0.rating ?? 0) > ($1.rating ?? 0) }
        return VStack(alignment: .leading, spacing: Space.l) {
            VStack(alignment: .leading, spacing: Space.xs) {
                Text("Tonight's order")
                    .font(TypeScale.largeTitle())
                    .foregroundStyle(Palette.text)
                Text("By your ratings, highest first. Each tasting is saved on its bottle.")
                    .font(TypeScale.secondary())
                    .foregroundStyle(Palette.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            ForEach(Array(ranked.enumerated()), id: \.element.id) { index, glass in
                HStack(spacing: Space.m) {
                    Text("\(index + 1)")
                        .font(TypeScale.title())
                        .foregroundStyle(index == 0 ? Palette.gold : Palette.textMuted)
                        .frame(width: 28)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(env.name(for: glass.summary.bottle))
                            .font(TypeScale.body())
                            .foregroundStyle(Palette.text)
                            .fixedSize(horizontal: false, vertical: true)
                        Text("Glass \(glass.letter)")
                            .font(TypeScale.caption())
                            .textCase(nil)
                            .foregroundStyle(Palette.textMuted)
                    }
                    Spacer()
                    if let rating = glass.rating {
                        RatingChip(rating: rating)
                    }
                }
                .padding(Space.l)
                .background(RoundedRectangle(cornerRadius: 12).fill(Palette.surface))
                .overlay(RoundedRectangle(cornerRadius: 12)
                    .stroke(index == 0 ? Palette.gold : Palette.line, lineWidth: 1))
            }

            Button { dismiss() } label: {
                Text("Done")
                    .font(TypeScale.headline())
                    .foregroundStyle(Palette.onGold)
                    .frame(maxWidth: .infinity, minHeight: 50)
                    .background(RoundedRectangle(cornerRadius: 11).fill(Palette.gold))
            }
        }
    }

    // MARK: - Actions

    private func load() {
        open = ((try? env.bottles.summaries()) ?? []).filter { $0.bottle.isOpen && !$0.status.isEmpty }
    }

    private func toggle(_ id: String) {
        if let index = chosen.firstIndex(of: id) {
            chosen.remove(at: index)
        } else if chosen.count < 4 {
            chosen.append(id)
        }
    }

    /// Logs one pour per glass, then shuffles the letters so blind is blind.
    private func pour() {
        let picked = open.filter { chosen.contains($0.id) }.shuffled()
        let letters = ["A", "B", "C", "D"]
        do {
            let ml = PourSize(usFluidOunces: pourOunces).milliliters
            glasses = try picked.enumerated().map { index, summary in
                let pourId = try env.bottles.logPour(bottleId: summary.id, volumeMl: ml).id
                return Glass(letter: letters[index], summary: summary, pourId: pourId)
            }
        } catch {
            self.error = error.localizedDescription
        }
    }

    private func markTasted(_ id: String) {
        guard let index = glasses.firstIndex(where: { $0.id == id }) else { return }
        glasses[index].tasted = true
        // The rating just saved is the newest tasting on that bottle.
        glasses[index].rating = (try? env.tastings.history(bottleId: id))?.first?.tasting.rating
    }
}
