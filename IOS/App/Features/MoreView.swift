import SwiftUI
import LiquorData
import LiquorEngine

/// Settings, and the tools that are not a tab of their own.
struct MoreView: View {
    @Environment(AppEnvironment.self) private var env
    @Environment(ProStore.self) private var store

    /// **Off by default, and it stays off until somebody asks.** The number is
    /// wanted for insurance and for recall, and it is also actively avoided:
    /// *"I have at least double that number and I don't want to know."*
    /// A per-device display preference, so it never syncs and never leaves.
    @AppStorage("showsCollectionValue") private var showsValue = CollectionValue.shownByDefault

    /// Ounces beside the millilitres. Display only; nothing stored changes.
    @AppStorage(VolumeDisplay.key) private var ounces = false

    @State private var exportURL: URL?
    /// Your Blanton's with a dump date, in the registry's shape. Nil until
    /// there is at least one, so nobody without a Blanton's sees the word.
    @State private var registryURL: URL?
    @State private var registryCount = 0
    @State private var isWalkDue = false
    @State private var isShowingPaywall = false
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
                units
                exportSection
                pro
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
                AskView()
            } label: {
                row(
                    "Ask",
                    detail: "\"What's open\", \"log a pour of Weller 12\" — answered from your shelf",
                    symbol: "text.bubble",
                    highlighted: true)
            }

            NavigationLink {
                CodeDecoderView()
            } label: {
                row(
                    "Decode a code",
                    detail: "Four Roses recipes, Elijah Craig batches",
                    symbol: "textformat.abc")
            }

            NavigationLink {
                CatalogBrowseView()
            } label: {
                row(
                    "Browse the catalogue",
                    detail: "Every product it knows, distillery by distillery, against your shelf",
                    symbol: "books.vertical")
            }

            NavigationLink {
                StatsView()
            } label: {
                row(
                    "Your collection",
                    detail: "What is on your shelf, at a glance",
                    symbol: "chart.bar")
            }

            NavigationLink {
                PourMenuView()
            } label: {
                row(
                    "What's open",
                    detail: "A menu for guests, without the prices",
                    symbol: "list.bullet.rectangle")
            }

            NavigationLink {
                SyncView()
            } label: {
                row(
                    "Sync",
                    detail: "Optional. Only for a second device.",
                    symbol: "arrow.triangle.2.circlepath")
            }

            NavigationLink {
                WishlistView()
            } label: {
                row(
                    "Wishlist",
                    detail: "Bottles you want, and what you would pay",
                    symbol: "star")
            }

            NavigationLink {
                FlightView()
            } label: {
                row(
                    "Taste a flight",
                    detail: "Two to four open bottles side by side, blind if you like",
                    symbol: "square.grid.2x2")
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

    // MARK: - Units

    private var units: some View {
        VStack(alignment: .leading, spacing: Space.m) {
            SectionLabel("Units")
            Toggle(isOn: $ounces) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Show ounces")
                        .font(TypeScale.body())
                        .foregroundStyle(Palette.text)
                    Text("Beside the millilitres. Bottles are labelled in ml; pours are "
                         + "thought about in oz. Nothing stored changes.")
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
        }
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

            NavigationLink {
                ImportView()
            } label: {
                row(
                    "Import a spreadsheet",
                    detail: "Bring in a CSV. Free, and you see the plan first.",
                    symbol: "square.and.arrow.down")
            }

            Button { buildExport() } label: {
                row(
                    exportURL == nil ? "Export everything as CSV" : "Rebuild the export",
                    detail: "Every bottle, every barrel field, free and complete",
                    symbol: "tablecells")
            }

            if registryCount > 0 {
                Button { buildRegistryExport() } label: {
                    row(
                        "Your Blanton's, for the dump-date registry",
                        detail: registryCount == 1
                            ? "1 bottle with a dump date, as a CSV to contribute"
                            : "\(registryCount) bottles with dump dates, as a CSV to contribute",
                        symbol: "calendar.badge.clock")
                }
                if let registryURL {
                    ShareLink(item: registryURL) {
                        row(
                            "Share the registry CSV",
                            detail: "Dump date, topper letter, barrel, warehouse, rick",
                            symbol: "square.and.arrow.up",
                            highlighted: true)
                    }
                }
            }

            NavigationLink {
                BackupView()
            } label: {
                row(
                    "Back up and restore",
                    detail: "Everything as one file — pours, tastings and photos included",
                    symbol: "externaldrive")
            }

            NavigationLink {
                InsuranceReportView()
            } label: {
                row(
                    "Insurance report",
                    detail: "A PDF for an insurer or an executor — what you paid, with photos",
                    symbol: "doc.text")
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

    // MARK: - Pro

    private var pro: some View {
        VStack(alignment: .leading, spacing: Space.m) {
            SectionLabel("Pro")
            Button { isShowingPaywall = true } label: {
                row(
                    store.isPro ? "You have Pro" : "Pro",
                    detail: store.isPro
                        ? "Sync, the insurance report and a shareable menu"
                        : "Services only. Your own data is never behind it.",
                    symbol: store.isPro ? "checkmark.seal" : "seal",
                    highlighted: store.isPro)
            }
            #if DEBUG
            // Simulator testing without an App Store account. Not in release.
            Toggle(isOn: Binding(
                get: { store.debugOverride },
                set: { store.debugOverride = $0 })
            ) {
                Text("Pretend to be Pro (debug build only)")
                    .font(TypeScale.caption())
                    .textCase(nil)
                    .foregroundStyle(Palette.textMuted)
            }
            .tint(Palette.gold)
            #endif
        }
        .sheet(isPresented: $isShowingPaywall) {
            NavigationStack { PaywallView() }
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
        registryCount = registryEntries().count
    }

    /// Every bottle with a dump date. Blanton's is what prints one, so no
    /// name check is needed; a dump date on anything else is still a fact
    /// the registry's shape can hold.
    private func registryEntries() -> [DumpDateRegistry.Entry] {
        ((try? env.bottles.summaries(includeFinished: true)) ?? [])
            .map(\.bottle)
            .filter { $0.dumpedAt != nil }
            .map { bottle in
                DumpDateRegistry.Entry(
                    dumpedAt: bottle.dumpedAt.map { Date(timeIntervalSince1970: Double($0) / 1000) },
                    topperLetter: bottle.topperLetter,
                    barrel: bottle.barrelNumber,
                    warehouse: bottle.warehouse,
                    rick: bottle.rick,
                    bottleNumber: bottle.bottleNumber,
                    store: bottle.purchaseStore ?? bottle.pickStore,
                    // Never guessed from a store name. Blank until the
                    // person records it somewhere the app can read.
                    stateFound: nil)
            }
    }

    private func buildRegistryExport() {
        let csv = DumpDateRegistry.csv(registryEntries())
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("blantons-dump-dates.csv")
        do {
            try csv.write(to: url, atomically: true, encoding: .utf8)
            registryURL = url
        } catch {
            self.error = error.localizedDescription
        }
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
        .environment(ProStore())
        .preferredColorScheme(.dark)
}
