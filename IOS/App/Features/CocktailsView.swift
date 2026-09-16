import SwiftUI
import LiquorEngine
import LiquorData

/// What can be made tonight from what is open: the IBA's recipes, each
/// with the bottle from your shelf that fills each slot.
struct CocktailsView: View {
    @Environment(AppEnvironment.self) private var env

    @State private var matches: [Cocktails.Match] = []
    @State private var expanded: Set<String> = []
    @State private var hasLooked = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Space.xl) {
                VStack(alignment: .leading, spacing: Space.s) {
                    Text("Tonight")
                        .font(TypeScale.largeTitle())
                        .foregroundStyle(Palette.text)
                    Text("The IBA's official recipes, against your open bottles.")
                        .font(TypeScale.secondary())
                        .foregroundStyle(Palette.textSecondary)
                }

                let ready = matches.filter(\.isReady)
                let nearly = matches.filter { !$0.isReady }

                if hasLooked, matches.isEmpty {
                    Text("Nothing open that these recipes call for. Open a bourbon, a gin or a rum and come back.")
                        .font(TypeScale.secondary())
                        .foregroundStyle(Palette.textMuted)
                        .fixedSize(horizontal: false, vertical: true)
                }
                if !ready.isEmpty {
                    section("Ready", ready)
                }
                if !nearly.isEmpty {
                    section("One bottle short", nearly)
                }

                Text("Recipes as the International Bartenders Association lists them. Bitters, citrus, sugar and soda are assumed to be in the kitchen.")
                    .font(TypeScale.caption())
                    .textCase(nil)
                    .foregroundStyle(Palette.textMuted)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.horizontal, Space.xl)
            .padding(.top, Space.l)
            .padding(.bottom, 96)
        }
        .background(Palette.background)
        .navigationTitle("Tonight")
        .navigationBarTitleDisplayMode(.inline)
        .task { reload() }
        .onChange(of: env.changeCount) { _, _ in reload() }
    }

    private func section(_ title: String, _ items: [Cocktails.Match]) -> some View {
        VStack(alignment: .leading, spacing: Space.m) {
            SectionLabel(title)
            ForEach(items) { match in
                card(match)
            }
        }
    }

    private func card(_ match: Cocktails.Match) -> some View {
        let isOpen = expanded.contains(match.id)
        return VStack(alignment: .leading, spacing: Space.s) {
            Button {
                if isOpen { expanded.remove(match.id) } else { expanded.insert(match.id) }
            } label: {
                HStack(alignment: .firstTextBaseline) {
                    Text(match.recipe.name)
                        .font(TypeScale.headline())
                        .foregroundStyle(Palette.text)
                    Spacer()
                    Image(systemName: isOpen ? "chevron.up" : "chevron.down")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(Palette.textMuted)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            // The bottle for each slot, or what is missing, in one line.
            Text(summaryLine(match))
                .font(TypeScale.secondary())
                .foregroundStyle(match.isReady ? Palette.textSecondary : Palette.gold)
                .fixedSize(horizontal: false, vertical: true)

            if isOpen {
                VStack(alignment: .leading, spacing: Space.xs) {
                    ForEach(Array(match.recipe.ingredients.enumerated()), id: \.offset) { _, ingredient in
                        HStack(alignment: .top, spacing: Space.s) {
                            Text("·")
                                .foregroundStyle(Palette.textMuted)
                            Text(ingredientLine(ingredient, match))
                                .font(TypeScale.secondary())
                                .foregroundStyle(Palette.text)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                }
                .padding(.top, Space.xs)
                Text(match.recipe.method)
                    .font(TypeScale.secondary())
                    .foregroundStyle(Palette.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
                Text("Glass: \(match.recipe.glass)")
                    .font(TypeScale.caption())
                    .textCase(nil)
                    .foregroundStyle(Palette.textMuted)
            }
        }
        .padding(Space.l)
        .background(RoundedRectangle(cornerRadius: 12).fill(Palette.surface))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Palette.line, lineWidth: 1))
    }

    /// "With Elijah Craig Small Batch and Cocchi di Torino" or "Needs
    /// sweet vermouth — Carpano Antica is unopened".
    private func summaryLine(_ match: Cocktails.Match) -> String {
        if let short = match.missing.first {
            var line = "Needs \(short.slot.label)"
            if let sealed = short.sealed { line += " — \(sealed.name) is unopened" }
            return line + "."
        }
        let names = match.recipe.slots.compactMap { match.picks[$0]?.name }
        var seen = Set<String>()
        let unique = names.filter { seen.insert($0).inserted }
        return "With " + unique.joined(separator: " and ") + "."
    }

    private func ingredientLine(_ ingredient: Cocktails.Ingredient, _ match: Cocktails.Match) -> String {
        if case let .bottle(slot, _) = ingredient, let pick = match.picks[slot] {
            return ingredient.text + " — " + pick.name
        }
        return ingredient.text
    }

    private func reload() {
        let shelf = ((try? env.bottles.summaries()) ?? []).compactMap { summary -> Cocktails.Candidate? in
            let bottle = summary.bottle
            guard !bottle.isInfinity, let classType = env.classType(for: bottle) else { return nil }
            let capacity = summary.status.capacityMilliliters
            return Cocktails.Candidate(
                id: bottle.id,
                name: env.name(for: bottle),
                classType: classType,
                isOpen: bottle.isOpen && !summary.status.isEmpty,
                rating: summary.latestRating,
                fillFraction: capacity > 0 ? summary.status.remainingMilliliters / capacity : 0)
        }
        matches = Cocktails.matches(shelf: shelf)
        hasLooked = true
    }
}

#Preview {
    NavigationStack { CocktailsView() }
        .environment(AppEnvironment.preview())
        .preferredColorScheme(.dark)
}
