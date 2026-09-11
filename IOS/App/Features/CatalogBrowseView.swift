import SwiftUI
import LiquorData
import LiquorEngine

/// The bundled catalogue, distillery by distillery, against what you have.
///
/// The catalogue is a convenience fallback, never the foundation (research
/// §1), and it is also three hundred bottles nobody could see without
/// searching for each by name. Browsing it answers "what else does Heaven
/// Hill make that I have not tried", and each row can become a bottle on
/// the shelf or a wish with one tap.
///
/// A list, not a checklist: no percentages, no "collected". The standing
/// beside each row is the same fact the shelf check reports.
struct CatalogBrowseView: View {
    @Environment(AppEnvironment.self) private var env

    struct Row: Identifiable {
        let product: CatalogProduct
        let standing: LineView.Standing
        var id: String { product.id }
    }

    @State private var groups: [(distillery: String, rows: [Row])] = []
    @State private var query = ""
    @State private var adding: CatalogProduct?
    @State private var error: String?

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: Space.xl, pinnedViews: [.sectionHeaders]) {
                searchField

                ForEach(filtered, id: \.distillery) { group in
                    Section {
                        VStack(spacing: 0) {
                            ForEach(Array(group.rows.enumerated()), id: \.element.id) { index, row in
                                productRow(row)
                                if index < group.rows.count - 1 {
                                    Divider().overlay(Palette.line)
                                }
                            }
                        }
                        .padding(.horizontal, Space.l)
                        .background(RoundedRectangle(cornerRadius: 12).fill(Palette.surface))
                        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Palette.line, lineWidth: 1))
                    } header: {
                        SectionLabel(group.distillery)
                            .padding(.vertical, Space.xs)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Palette.background)
                    }
                }

                Text("\(env.catalog.products.count) products in the bundled catalogue. A bottle "
                     + "that is not here can still be typed in and is yours alone.")
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
        .navigationTitle("The catalogue")
        .navigationBarTitleDisplayMode(.inline)
        .task { load() }
        .sheet(item: $adding, onDismiss: load) { product in
            NavigationStack { AddBottleView(product: product) }
        }
        .alert("Something went wrong", isPresented: .constant(error != nil)) {
            Button("OK") { error = nil }
        } message: { Text(error ?? "") }
    }

    private var searchField: some View {
        HStack(spacing: Space.m) {
            Image(systemName: "magnifyingglass").foregroundStyle(Palette.textMuted)
            TextField("Filter by name or distillery", text: $query)
                .font(TypeScale.body())
                .foregroundStyle(Palette.text)
                .autocorrectionDisabled()
                .textInputAutocapitalization(.never)
            if !query.isEmpty {
                Button { query = "" } label: {
                    Image(systemName: "xmark.circle.fill").foregroundStyle(Palette.textMuted)
                }
            }
        }
        .padding(.horizontal, Space.l)
        .frame(minHeight: 52)
        .background(RoundedRectangle(cornerRadius: 11).fill(Palette.surface))
        .overlay(RoundedRectangle(cornerRadius: 11).stroke(Palette.line, lineWidth: 1))
    }

    private func productRow(_ row: Row) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: Space.m) {
            Image(systemName: symbol(row.standing))
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(color(row.standing))
                .frame(width: 20)
            VStack(alignment: .leading, spacing: 2) {
                Text(row.product.identity.displayName)
                    .font(TypeScale.body())
                    .foregroundStyle(Palette.text)
                    .fixedSize(horizontal: false, vertical: true)
                Text(row.product.classType.label + " · " + row.product.strengthDescription)
                    .font(TypeScale.caption())
                    .textCase(nil)
                    .foregroundStyle(Palette.textMuted)
            }
            Spacer(minLength: Space.s)
            Menu {
                Button {
                    adding = row.product
                } label: {
                    Label("Add a bottle of this", systemImage: "plus")
                }
                Button {
                    wish(row.product)
                } label: {
                    Label("Add to wishlist", systemImage: "star")
                }
            } label: {
                Image(systemName: "ellipsis")
                    .foregroundStyle(Palette.gold)
                    .frame(width: Space.tapTarget, height: Space.tapTarget)
            }
        }
        .frame(minHeight: Space.tapTarget)
    }

    private var filtered: [(distillery: String, rows: [Row])] {
        let tokens = query.matchTokens
        guard !tokens.isEmpty else { return groups }
        return groups.compactMap { group in
            let rows = group.rows.filter { row in
                let haystack = (group.distillery + " " + row.product.identity.displayName).matchTokens
                return tokens.allSatisfy { token in haystack.contains { $0.hasPrefix(token) } }
            }
            return rows.isEmpty ? nil : (distillery: group.distillery, rows: rows)
        }
    }

    private func load() {
        let holdings = (try? env.bottles.holdings { env.identity($0) }) ?? []
        let tastings = (try? env.tastings.records { env.identity($0) }) ?? []
        let onShelf = Set(holdings.filter { !$0.isFinished }.map(\.product.productId))
        let finished = Set(holdings.filter(\.isFinished).map(\.product.productId))
        let tasted = Set(tastings.map(\.product.productId))

        let byDistillery = Dictionary(grouping: env.catalog.products, by: \.distillery)
        groups = byDistillery.keys.sorted { $0.localizedCaseInsensitiveCompare($1) == .orderedAscending }
            .map { distillery in
                let rows = (byDistillery[distillery] ?? [])
                    .sorted { $0.identity.displayName.localizedCaseInsensitiveCompare($1.identity.displayName) == .orderedAscending }
                    .map { product -> Row in
                        let standing: LineView.Standing
                        if onShelf.contains(product.id) {
                            standing = .onShelf
                        } else if finished.contains(product.id) {
                            standing = .hadItBefore
                        } else if tasted.contains(product.id) {
                            standing = .tastedOnly
                        } else {
                            standing = .never
                        }
                        return Row(product: product, standing: standing)
                    }
                return (distillery: distillery, rows: rows)
            }
    }

    private func wish(_ product: CatalogProduct) {
        do {
            try env.wishlist.add(catalogProductId: product.id)
        } catch {
            self.error = error.localizedDescription
        }
    }

    private func symbol(_ standing: LineView.Standing) -> String {
        switch standing {
        case .onShelf: return "checkmark.circle.fill"
        case .hadItBefore: return "clock"
        case .tastedOnly: return "mouth"
        case .never: return "circle"
        }
    }

    private func color(_ standing: LineView.Standing) -> Color {
        switch standing {
        case .onShelf: return Palette.Verdict.onShelf
        case .hadItBefore: return Palette.Verdict.hadItBefore
        case .tastedOnly: return Palette.Verdict.tastedNotOwned
        case .never: return Palette.textMuted
        }
    }
}
