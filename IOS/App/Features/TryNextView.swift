import SwiftUI
import LiquorEngine
import LiquorData

/// What to try next, from what you rated highest: the same line, recipe,
/// mashbill or distillery as a bottle you rated 7 or better, minus what
/// you have had. Every row says which bottle of yours put it there.
struct TryNextView: View {
    @Environment(AppEnvironment.self) private var env

    @State private var suggestions: [TryNext.Suggestion] = []
    @State private var sources = 0
    @State private var hasLooked = false
    @State private var adding: CatalogProduct?
    @State private var error: String?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Space.xl) {
                VStack(alignment: .leading, spacing: Space.s) {
                    Text("Try next")
                        .font(TypeScale.largeTitle())
                        .foregroundStyle(Palette.text)
                    Text(sources == 0
                         ? "From the bottles you rate 7 or better, once there are some."
                         : "From the \(sources) \(sources == 1 ? "bottle" : "bottles") you rated 7 or better. Related by line, recipe or distillery; nothing you have had.")
                        .font(TypeScale.secondary())
                        .foregroundStyle(Palette.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                if hasLooked, suggestions.isEmpty {
                    Text(sources == 0
                         ? "Rate a few tastings 7 or better and this fills in."
                         : "Nothing in the catalogue is related to those that you have not already had.")
                        .font(TypeScale.secondary())
                        .foregroundStyle(Palette.textMuted)
                        .fixedSize(horizontal: false, vertical: true)
                }

                VStack(spacing: Space.m) {
                    ForEach(suggestions) { suggestion in
                        row(suggestion)
                    }
                }
            }
            .padding(.horizontal, Space.xl)
            .padding(.top, Space.l)
            .padding(.bottom, 96)
        }
        .background(Palette.background)
        .navigationTitle("Try next")
        .navigationBarTitleDisplayMode(.inline)
        .task { reload() }
        .onChange(of: env.changeCount) { _, _ in reload() }
        .sheet(item: $adding, onDismiss: env.noteChange) { product in
            NavigationStack { AddBottleView(product: product) }
        }
        .alert("Something went wrong", isPresented: .constant(error != nil)) {
            Button("OK") { error = nil }
        } message: { Text(error ?? "") }
    }

    private func row(_ suggestion: TryNext.Suggestion) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: Space.m) {
            VStack(alignment: .leading, spacing: 3) {
                Text(suggestion.product.displayName)
                    .font(TypeScale.body())
                    .foregroundStyle(Palette.text)
                    .fixedSize(horizontal: false, vertical: true)
                if let product = env.catalog.product(suggestion.product.productId) {
                    Text(product.classType.label + " · " + product.strengthDescription)
                        .font(TypeScale.caption())
                        .textCase(nil)
                        .foregroundStyle(Palette.textMuted)
                }
                Text(suggestion.why)
                    .font(TypeScale.caption())
                    .textCase(nil)
                    .foregroundStyle(Palette.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: Space.s)
            Menu {
                if let product = env.catalog.product(suggestion.product.productId) {
                    Button { adding = product } label: {
                        Label("Add a bottle of this", systemImage: "plus")
                    }
                    Button { wish(product) } label: {
                        Label("Add to wishlist", systemImage: "star")
                    }
                }
            } label: {
                Image(systemName: "ellipsis")
                    .foregroundStyle(Palette.gold)
                    .frame(width: Space.tapTarget, height: Space.tapTarget)
            }
        }
        .padding(Space.l)
        .background(RoundedRectangle(cornerRadius: 12).fill(Palette.surface))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Palette.line, lineWidth: 1))
    }

    private func wish(_ product: CatalogProduct) {
        do {
            try env.wishlist.add(catalogProductId: product.id)
            env.noteChange()
        } catch {
            self.error = error.localizedDescription
        }
    }

    private func reload() {
        let holdings = (try? env.bottles.holdings { env.identity($0) }) ?? []
        let tastings = (try? env.tastings.records { env.identity($0) }) ?? []
        // The best rating you gave each product, from any tasting of it.
        var best: [String: (product: ProductIdentity, rating: Int)] = [:]
        for record in tastings {
            guard let rating = record.rating else { continue }
            let id = record.product.productId
            if (best[id]?.rating ?? 0) < rating { best[id] = (record.product, rating) }
        }
        let liked = best.values.map { entry -> TryNext.Liked in
            let product = env.catalog.product(entry.product.productId)
            return TryNext.Liked(
                product: entry.product, rating: entry.rating,
                recipeCode: product?.code, mashbillKey: product?.mashbillKey)
        }
        sources = liked.filter { $0.rating >= TryNext.threshold }.count
        let had = Set(holdings.map(\.product.productId) + tastings.map(\.product.productId))
        suggestions = TryNext.suggest(
            liked: liked,
            catalogue: env.catalog.searchCandidates(history: had),
            had: had)
        hasLooked = true
    }
}

#Preview {
    NavigationStack { TryNextView() }
        .environment(AppEnvironment.preview())
        .preferredColorScheme(.dark)
}
