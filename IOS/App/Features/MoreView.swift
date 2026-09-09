import SwiftUI
import LiquorData
import LiquorEngine

/// Settings, and the tools that are not a tab of their own.
struct MoreView: View {
    @Environment(AppEnvironment.self) private var env

    /// **Off by default, and it stays off until somebody asks.** The number is
    /// wanted for insurance and for recall, and it is also actively avoided:
    /// *"I have at least double that number and I don't want to know."*
    /// A per-device display preference, so it never syncs and never leaves.
    @AppStorage("showsCollectionValue") private var showsValue = CollectionValue.shownByDefault

    @State private var exportURL: URL?
    @State private var isWalkDue = false
    @State private var error: String?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Space.xl) {
                Text("More")
                    .font(TypeScale.largeTitle())
                    .foregroundStyle(Palette.text)
                    .padding(.top, Space.s)

                tools
                money
                exportSection
                aboutTheData
            }
            .padding(.horizontal, Space.xl)
            .padding(.bottom, 96)
        }
        .background(Palette.background)
        .navigationBarTitleDisplayMode(.inline)
        .task { refresh() }
        .alert("Something went wrong", isPresented: .constant(error != nil)) {
            Button("OK") { error = nil }
        } message: { Text(error ?? "") }
    }

    // MARK: - Tools

    private var tools: some View {
        VStack(alignment: .leading, spacing: Space.m) {
            SectionLabel("Tools")

            NavigationLink {
                WishlistView()
            } label: {
                row(
                    "Wishlist",
                    detail: "Bottles you want, and what you would pay",
                    symbol: "star")
            }

            NavigationLink {
                PickMyPourView()
            } label: {
                row(
                    "Pick my pour",
                    detail: "Something open you have not had in a while",
                    symbol: "dice")
            }

            NavigationLink {
                ReInventoryView()
            } label: {
                row(
                    "Shelf walk",
                    detail: isWalkDue
                        ? "Some bottles have not been checked in months"
                        : "Walk your shelves and bring the list back in line",
                    symbol: "checklist",
                    highlighted: isWalkDue)
            }
        }
    }

    // MARK: - Money

    private var money: some View {
        VStack(alignment: .leading, spacing: Space.m) {
            SectionLabel("Money")

            Toggle(isOn: $showsValue) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Show what your shelf cost")
                        .font(TypeScale.body())
                        .foregroundStyle(Palette.text)
                    Text("Off by default. Plenty of people would rather not see it.")
                        .font(TypeScale.caption())
                        .textCase(nil)
                        .foregroundStyle(Palette.textMuted)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .tint(Palette.gold)
            .padding(Space.l)
            .background(RoundedRectangle(cornerRadius: 12).fill(Palette.surface))
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(Palette.line, lineWidth: 1))

            if showsValue {
                shelfValueCard
            }
        }
    }

    private var shelfValueCard: some View {
        let total = shelfValue
        return VStack(alignment: .leading, spacing: Space.s) {
            Text(Money.short(total.cents))
                .font(TypeScale.largeTitle())
                .foregroundStyle(Palette.text)
            // Never optional. We have no market data, cannot keep it current,
            // and being wrong about it costs more than saying nothing.
            Text(total.caveat)
                .font(TypeScale.caption())
                .textCase(nil)
                .foregroundStyle(Palette.textMuted)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(Space.l)
        .background(RoundedRectangle(cornerRadius: 12).fill(Palette.surface))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Palette.line, lineWidth: 1))
    }

    // MARK: - Export

    /// **Free, always, and prominent.** People here have been burned by apps
    /// losing collections, and the advice they give each other is to be wary of
    /// anything that will not let you export. It is the cheapest trust there is.
    private var exportSection: some View {
        VStack(alignment: .leading, spacing: Space.m) {
            SectionLabel("Your data")

            if let exportURL {
                ShareLink(item: exportURL) {
                    row(
                        "Share your collection",
                        detail: exportURL.lastPathComponent,
                        symbol: "square.and.arrow.up",
                        highlighted: true)
                }
            }

            Button { buildExport() } label: {
                row(
                    exportURL == nil ? "Export everything as CSV" : "Rebuild the export",
                    detail: "Every bottle, every barrel field, free and complete",
                    symbol: "tablecells")
            }

            Text("Opens in any spreadsheet. It includes your barrel and pick "
                 + "detail and the bottles you have finished, because an export "
                 + "missing those would look like a backup without being one.")
                .font(TypeScale.caption())
                .textCase(nil)
                .foregroundStyle(Palette.textMuted)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    // MARK: - About

    private var aboutTheData: some View {
        VStack(alignment: .leading, spacing: Space.m) {
            VStack(alignment: .leading, spacing: 0) {
                SectionLabel("Data on this phone")
                    .padding(.bottom, Space.xs)
                FactRow(label: "Catalogue", value: "\(env.catalog.products.count) products")
                FactRow(
                    label: "Flavour wheel",
                    value: "\(env.wheel.families.count) families · "
                        + "\(env.wheel.allDescriptors.count) descriptors")
                FactRow(label: "Works offline", value: "Always", isLast: true)
            }

            Text("Every bottle, note and pour is stored on this phone. Nothing "
                 + "here needs a network.")
                .font(TypeScale.secondary())
                .foregroundStyle(Palette.textMuted)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    // MARK: - Pieces

    private func row(
        _ title: String,
        detail: String,
        symbol: String,
        highlighted: Bool = false
    ) -> some View {
        HStack(spacing: Space.m) {
            Image(systemName: symbol)
                .font(.system(size: 18))
                .foregroundStyle(highlighted ? Palette.gold : Palette.textSecondary)
                .frame(width: 28)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(TypeScale.body())
                    .foregroundStyle(Palette.text)
                    .multilineTextAlignment(.leading)
                Text(detail)
                    .font(TypeScale.caption())
                    .textCase(nil)
                    .foregroundStyle(Palette.textMuted)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: Space.s)
            Image(systemName: "chevron.right")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(Palette.textMuted)
        }
        .padding(Space.l)
        .frame(maxWidth: .infinity, minHeight: Space.tapTarget, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 12).fill(Palette.surface))
        .overlay(RoundedRectangle(cornerRadius: 12)
            .stroke(highlighted ? Palette.gold : Palette.line, lineWidth: 1))
    }

    // MARK: - Derivation

    private var shelfValue: CollectionValue.Total {
        let summaries = (try? env.bottles.summaries(includeFinished: true)) ?? []
        return CollectionValue.onTheShelf(summaries.map {
            CollectionValue.Holding(
                purchasePriceCents: $0.bottle.purchasePriceCents,
                isFinished: $0.bottle.isFinished)
        })
    }

    // MARK: - Actions

    private func refresh() {
        isWalkDue = (try? env.shelfWalk.isDue()) ?? false
    }

    private func buildExport() {
        do {
            exportURL = try env.export.write(
                to: FileManager.default.temporaryDirectory,
                resolveName: { env.name(for: $0) },
                resolveIdentity: { env.identity($0) })
        } catch {
            self.error = error.localizedDescription
        }
    }
}

#Preview {
    NavigationStack { MoreView() }
        .environment(AppEnvironment.preview())
        .preferredColorScheme(.dark)
}
