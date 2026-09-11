import SwiftUI
import LiquorData
import LiquorEngine

/// What you own, with how much is left in each.
///
/// Counts **bottles owned, never drinks had.** Apple rejects apps that
/// encourage excessive consumption, which rules out streaks, totals and
/// anything that makes drinking more feel like progress.
struct CollectionView: View {
    @Environment(AppEnvironment.self) private var env

    /// Everything, finished included. The filter decides what is shown, so
    /// switching between "on the shelf" and "finished" is a pass over memory
    /// and never a database round trip.
    @State private var summaries: [BottleSummary] = []
    /// The same bottles as the engine's filter sees them, built once per load.
    @State private var rows: [CollectionFilter.Row] = []
    @State private var criteria = CollectionFilter.Criteria.none
    /// "1 of 3" for bottles that are the same thing. Picks come by the
    /// case; the cards stay separate because each bottle has its own fill.
    @State private var places: [String: Multiples.Place] = [:]
    @State private var error: String?

    /// Shared with the switch in More. Off unless somebody turned it on: the
    /// figure is wanted by some people and actively avoided by others, and a
    /// total nobody asked for is the version that causes harm.
    @AppStorage("showsCollectionValue") private var showsValue = CollectionValue.shownByDefault

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: Space.m) {
                header

                if summaries.isEmpty {
                    empty
                } else {
                    finder
                    if shown.isEmpty {
                        nothingMatches
                    } else {
                        ForEach(shown) { summary in
                            NavigationLink {
                                BottleDetailView(bottleId: summary.id)
                            } label: {
                                BottleCard(summary: summary, place: places[summary.id])
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
            .padding(.horizontal, Space.xl)
            .padding(.bottom, 96)
        }
        .background(Palette.background)
        .navigationTitle("Collection")
        .navigationBarTitleDisplayMode(.inline)
        .task { reload() }
        .refreshable { reload() }
        .alert("Something went wrong", isPresented: .constant(error != nil)) {
            Button("OK") { error = nil }
        } message: {
            Text(error ?? "")
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: Space.m) {
            HStack(alignment: .firstTextBaseline) {
                Text(criteria.status == .onShelf ? "On your shelf" : criteria.status.label)
                    .font(TypeScale.largeTitle())
                    .foregroundStyle(Palette.text)
                Spacer()
            }

            // Bottles, not drinks. See the note on this view.
            Text(countLine)
                .font(TypeScale.secondary())
                .foregroundStyle(Palette.textSecondary)

            if showsValue {
                VStack(alignment: .leading, spacing: 2) {
                    Text(Money.short(shelfValue.cents))
                        .font(TypeScale.title())
                        .foregroundStyle(Palette.gold)
                    Text(shelfValue.caveat)
                        .font(TypeScale.caption())
                        .textCase(nil)
                        .foregroundStyle(Palette.textMuted)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

        }
        .padding(.top, Space.s)
    }

    // MARK: - Finding a bottle

    /// Type, narrow, order. The research puts the point where somebody needs
    /// this app at about fifty bottles, and the bulk-onboarding paths exist to
    /// get two hundred in; a flat list stops working long before that.
    private var finder: some View {
        VStack(alignment: .leading, spacing: Space.s) {
            HStack(spacing: Space.m) {
                Image(systemName: "magnifyingglass").foregroundStyle(Palette.textMuted)
                TextField("Name, distillery, barrel, store, shelf", text: $criteria.query)
                    .font(TypeScale.body())
                    .foregroundStyle(Palette.text)
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.never)
                if !criteria.query.isEmpty {
                    Button { criteria.query = "" } label: {
                        Image(systemName: "xmark.circle.fill").foregroundStyle(Palette.textMuted)
                    }
                    .frame(minWidth: Space.tapTarget, minHeight: Space.tapTarget)
                }
                sortMenu
            }
            .padding(.horizontal, Space.l)
            .frame(minHeight: 52)
            .background(RoundedRectangle(cornerRadius: 11).fill(Palette.surface))
            .overlay(RoundedRectangle(cornerRadius: 11).stroke(Palette.line, lineWidth: 1))

            // Status first, because "what is open" is the question people ask
            // most. Kinds and places follow only when the shelf has them: a
            // chip that can never narrow anything is noise on a control that
            // exists to narrow.
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: Space.s) {
                    ForEach(CollectionFilter.Status.allCases, id: \.self) { status in
                        chip(status.label, isOn: criteria.status == status) {
                            criteria.status = status
                        }
                    }
                }
            }

            let kinds = CollectionFilter.availableKinds(in: rows)
            let places = CollectionFilter.locations(in: rows)
            if !kinds.isEmpty || !places.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: Space.s) {
                        ForEach(kinds, id: \.self) { kind in
                            chip(kind.label, isOn: criteria.kinds.contains(kind)) {
                                if criteria.kinds.contains(kind) {
                                    criteria.kinds.remove(kind)
                                } else {
                                    criteria.kinds.insert(kind)
                                }
                            }
                        }
                        ForEach(places, id: \.self) { place in
                            chip(place, isOn: criteria.location == place, symbol: "mappin") {
                                criteria.location = criteria.location == place ? nil : place
                            }
                        }
                    }
                }
            }

            if criteria.isNarrowing {
                HStack {
                    Text(shown.count == 1 ? "1 bottle" : "\(shown.count) bottles")
                        .font(TypeScale.caption())
                        .textCase(nil)
                        .foregroundStyle(Palette.textMuted)
                    Spacer()
                    Button {
                        let sort = criteria.sort
                        criteria = .none
                        criteria.sort = sort
                    } label: {
                        Text("Clear")
                            .font(TypeScale.caption())
                            .textCase(nil)
                            .foregroundStyle(Palette.gold)
                            .frame(minHeight: Space.tapTarget)
                    }
                }
            }
        }
    }

    private var sortMenu: some View {
        Menu {
            ForEach(CollectionFilter.Sort.allCases, id: \.self) { sort in
                Button {
                    criteria.sort = sort
                } label: {
                    if criteria.sort == sort {
                        Label(sort.label, systemImage: "checkmark")
                    } else {
                        Text(sort.label)
                    }
                }
            }
        } label: {
            HStack(spacing: 4) {
                Image(systemName: "arrow.up.arrow.down")
                Text(criteria.sort.label)
            }
            .font(TypeScale.caption())
            .textCase(nil)
            .foregroundStyle(Palette.gold)
            .frame(minHeight: Space.tapTarget)
        }
        .accessibilityLabel("Sort by \(criteria.sort.label)")
    }

    private func chip(
        _ title: String,
        isOn: Bool,
        symbol: String? = nil,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 4) {
                if let symbol {
                    Image(systemName: symbol).font(.system(size: 11))
                }
                Text(title)
            }
            .font(TypeScale.secondary())
            .foregroundStyle(isOn ? Palette.onGold : Palette.textSecondary)
            .padding(.horizontal, Space.l)
            .frame(minHeight: Space.tapTarget - 8)
            .background(RoundedRectangle(cornerRadius: 9)
                .fill(isOn ? Palette.gold : Palette.surfaceRaised))
        }
    }

    private var nothingMatches: some View {
        VStack(spacing: Space.m) {
            Text("Nothing matches")
                .font(TypeScale.title())
                .foregroundStyle(Palette.text)
            Text("Try fewer words, or clear the filters.")
                .font(TypeScale.secondary())
                .foregroundStyle(Palette.textMuted)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 48)
    }

    /// The bottles the criteria leave, in the chosen order.
    private var shown: [BottleSummary] {
        let byId = Dictionary(uniqueKeysWithValues: summaries.map { ($0.id, $0) })
        return CollectionFilter.apply(criteria, to: rows).compactMap { byId[$0.id] }
    }

    /// What is on the shelf cost, never what it is worth. We have no market
    /// data and will not invent any.
    private var shelfValue: CollectionValue.Total {
        CollectionValue.onTheShelf(shown.map {
            CollectionValue.Holding(
                purchasePriceCents: $0.bottle.purchasePriceCents,
                isFinished: $0.bottle.isFinished)
        })
    }

    private var countLine: String {
        let onShelf = summaries.filter { !$0.bottle.isFinished }
        let open = onShelf.filter(\.bottle.isOpen).count
        let bottles = onShelf.count == 1 ? "1 bottle" : "\(onShelf.count) bottles"
        return open > 0 ? "\(bottles) · \(open) open" : bottles
    }

    private var empty: some View {
        VStack(spacing: Space.l) {
            BottleMark(height: 84)
            Text("Nothing here yet")
                .font(TypeScale.title())
                .foregroundStyle(Palette.text)
            Text("Add a bottle and it will show up here with how much is left in it.")
                .font(TypeScale.secondary())
                .foregroundStyle(Palette.textMuted)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 64)
    }

    private func reload() {
        do {
            summaries = try env.bottles.summaries(includeFinished: true)
            // One read for every custom product rather than one per bottle:
            // a typed-in bottle's class and proof flags live on its entry.
            let custom = Dictionary(
                uniqueKeysWithValues: try env.bottles.customProducts().map { ($0.id, $0) })
            rows = summaries.map { row(for: $0, custom: custom) }
            places = Multiples.places(in: summaries.map { summary in
                Multiples.Bottle(
                    id: summary.id,
                    productKey: summary.bottle.catalogProductId
                        ?? summary.bottle.customName ?? summary.id,
                    barrel: summary.bottle.barrelNumber,
                    batch: summary.bottle.batchNumber,
                    isFinished: summary.bottle.isFinished)
            })
        } catch {
            self.error = error.localizedDescription
        }
    }

    /// A bottle flattened for the filter. Class and production come from the
    /// catalogue for a catalogue bottle and from the custom entry for a typed
    /// one, so both filter the same way.
    private func row(
        for summary: BottleSummary,
        custom: [String: CustomCatalogEntry]
    ) -> CollectionFilter.Row {
        let bottle = summary.bottle
        let product = env.product(for: bottle)
        let entry = bottle.catalogProductId.flatMap { custom[$0] }
        let capacity = summary.status.capacityMilliliters
        return CollectionFilter.Row(
            id: bottle.id,
            name: env.name(for: bottle),
            distillery: env.distillery(for: bottle),
            extraSearchText: [
                bottle.releaseLabel, bottle.barrelNumber, bottle.batchNumber,
                bottle.pickStore, bottle.purchaseStore, bottle.pickGroup,
                bottle.customName,
            ].compactMap { $0 },
            classType: product?.classType ?? entry?.classType,
            productionType: product?.productionType ?? entry?.productionType ?? .unspecified,
            isBarrelProof: product?.isBarrelProof ?? entry?.isBarrelProof ?? false,
            isBottledInBond: product?.isBottledInBond ?? entry?.isBottledInBond ?? false,
            isStorePick: bottle.isStorePick,
            isOpen: bottle.isOpen,
            isFinished: bottle.isFinished,
            storageLocation: bottle.storageLocation,
            addedAt: Date(timeIntervalSince1970: Double(bottle.createdAt) / 1000),
            lastPouredAt: summary.lastPouredAt,
            rating: summary.latestRating,
            fillFraction: capacity > 0
                ? summary.status.remainingMilliliters / capacity
                : 0)
    }
}

/// One bottle in the list. Fill count and millilitres always travel together —
/// the pour count rounds to nearest, and the millilitres are what stop that
/// rounding carrying weight on its own.
struct BottleCard: View {
    @Environment(AppEnvironment.self) private var env
    let summary: BottleSummary
    var place: Multiples.Place? = nil

    var body: some View {
        HStack(alignment: .top, spacing: Space.m) {
            BottleImage(fileName: summary.bottle.photoFile, height: 58)

            VStack(alignment: .leading, spacing: Space.s) {
                if let distillery = env.distillery(for: summary.bottle) {
                    SectionLabel(distillery)
                }

                HStack(alignment: .firstTextBaseline) {
                    Text(env.name(for: summary.bottle))
                        .font(TypeScale.title())
                        .foregroundStyle(Palette.text)
                        .fixedSize(horizontal: false, vertical: true)
                    Spacer(minLength: Space.s)
                    if let label = place?.label {
                        Text(label)
                            .font(TypeScale.caption())
                            .textCase(nil)
                            .foregroundStyle(Palette.textMuted)
                            .padding(.horizontal, Space.s)
                            .padding(.vertical, 3)
                            .overlay(
                                RoundedRectangle(cornerRadius: 5)
                                    .stroke(Palette.line, lineWidth: 1))
                    }
                    if summary.bottle.isOpen {
                        Text("Open")
                            .font(TypeScale.caption())
                            .foregroundStyle(Palette.gold)
                            .padding(.horizontal, Space.s)
                            .padding(.vertical, 3)
                            .overlay(
                                RoundedRectangle(cornerRadius: 5)
                                    .stroke(Palette.gold, lineWidth: 1))
                    }
                }

                if let release = summary.bottle.releaseLabel {
                    Text(release)
                        .font(TypeScale.code(13))
                        .foregroundStyle(Palette.textMuted)
                }

                FillBar(status: summary.status)

                HStack(spacing: Space.m) {
                    if let rating = summary.latestRating {
                        RatingChip(rating: rating)
                    }
                    if let cents = summary.costPerPourCents {
                        Text(Money.short(cents) + " a pour")
                            .font(TypeScale.code(13))
                            .foregroundStyle(Palette.textMuted)
                    }
                    Spacer()
                }

                // People use this to dig out a bottle they liked and have not
                // poured from in months. It is a fact about the bottle, never a
                // nudge to drink: no streak, no "it has been too long".
                if let line = lastPourLine {
                    Text(line)
                        .font(TypeScale.caption())
                        .textCase(nil)
                        .foregroundStyle(Palette.textMuted)
                }

                if let location = summary.bottle.storageLocation {
                    Text(location)
                        .font(TypeScale.caption())
                        .textCase(nil)
                        .foregroundStyle(Palette.textMuted)
                }
            }
        }
        .padding(Space.l)
        .background(RoundedRectangle(cornerRadius: 12).fill(Palette.surface))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Palette.line, lineWidth: 1))
    }

    /// Nil for a bottle that has never been poured from — "never poured" on a
    /// sealed bottle states the obvious, and on an open one it reads as a
    /// reproach.
    private var lastPourLine: String? {
        guard let days = summary.daysSinceLastPour() else { return nil }
        switch days {
        case 0: return "Last poured today"
        case 1: return "Last poured yesterday"
        case ..<30: return "Last poured \(days) days ago"
        case ..<60: return "Last poured about a month ago"
        case ..<365: return "Last poured \(days / 30) months ago"
        default: return "Last poured over a year ago"
        }
    }
}

// `Money` now lives in LiquorEngine. It moved because the engine renders prices
// inside sentences of its own -- "You paid $79.99 for this before" -- and two
// formatters would eventually disagree inside a single screen.

#Preview {
    NavigationStack {
        CollectionView()
    }
    .environment(AppEnvironment.preview())
    .preferredColorScheme(.dark)
}
