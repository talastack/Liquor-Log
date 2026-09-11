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
    /// The bottle whose relatives are being shown, while that sheet is up.
    @State private var likeThis: BottleSummary?

    /// The three ways in, from the empty shelf. The research's first-ranked
    /// finding is that getting an existing collection in is the adoption
    /// barrier, so an empty screen offers the bulk paths, not just one
    /// bottle at a time.
    @State private var isAddingShelf = false
    @State private var isImporting = false
    @State private var isAddingOne = false
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
                            .contextMenu {
                                Button {
                                    likeThis = summary
                                } label: {
                                    Label("Others like this on your shelf",
                                          systemImage: "rectangle.on.rectangle")
                                }
                            }
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
        .sheet(item: $likeThis) { summary in
            NavigationStack {
                LikeThisView(summary: summary, shelf: summaries.filter { !$0.bottle.isFinished })
            }
        }
        .sheet(isPresented: $isAddingShelf, onDismiss: reload) {
            NavigationStack { BulkAddView() }
        }
        .sheet(isPresented: $isImporting, onDismiss: reload) {
            NavigationStack { ImportView() }
        }
        .sheet(isPresented: $isAddingOne, onDismiss: reload) {
            NavigationStack { AddBottleView() }
        }
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
            Text("Three ways in. A shelf of two hundred should not take two hundred forms.")
                .font(TypeScale.secondary())
                .foregroundStyle(Palette.textMuted)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)

            VStack(spacing: Space.s) {
                wayIn("Scan a shelf", detail: "Point the camera at each label, confirm, next",
                      symbol: "camera.viewfinder", highlighted: true) { isAddingShelf = true }
                wayIn("Import a spreadsheet", detail: "A CSV from wherever you kept it before",
                      symbol: "tablecells") { isImporting = true }
                wayIn("Add one bottle", detail: "Search the catalogue or type it in",
                      symbol: "plus") { isAddingOne = true }
            }
            .padding(.top, Space.m)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 48)
    }

    private func wayIn(
        _ title: String, detail: String, symbol: String,
        highlighted: Bool = false, action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: Space.m) {
                Image(systemName: symbol)
                    .font(.system(size: 18))
                    .foregroundStyle(highlighted ? Palette.gold : Palette.textSecondary)
                    .frame(width: 28)
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(TypeScale.body())
                        .foregroundStyle(Palette.text)
                    Text(detail)
                        .font(TypeScale.caption())
                        .textCase(nil)
                        .foregroundStyle(Palette.textMuted)
                        .multilineTextAlignment(.leading)
                }
                Spacer()
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


/// The bottles on YOUR shelf that are structurally related to one: same
/// line, same recipe, same distillery. The shelf-check "you might also
/// mean" row, pointed at what you own instead of the catalogue.
///
/// "Do I have others like this?" is the question behind a shelf of eighty
/// bourbons: which of these are wheated, which are the other Four Roses
/// recipes, what else from this distillery is open.
struct LikeThisView: View {
    @Environment(AppEnvironment.self) private var env
    @Environment(\.dismiss) private var dismiss

    let summary: BottleSummary
    let shelf: [BottleSummary]

    struct Match: Identifiable {
        let summary: BottleSummary
        let reason: SearchHit.Reason
        var id: String { summary.id }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Space.l) {
                VStack(alignment: .leading, spacing: Space.xs) {
                    SectionLabel("Like")
                    Text(env.name(for: summary.bottle))
                        .font(TypeScale.largeTitle())
                        .foregroundStyle(Palette.text)
                        .fixedSize(horizontal: false, vertical: true)
                }

                if matches.isEmpty {
                    Text("Nothing else on your shelf shares a line, a recipe or a "
                         + "distillery with this one.")
                        .font(TypeScale.secondary())
                        .foregroundStyle(Palette.textMuted)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.top, Space.m)
                } else {
                    ForEach(matches) { match in
                        NavigationLink {
                            BottleDetailView(bottleId: match.summary.id)
                        } label: {
                            VStack(alignment: .leading, spacing: Space.xs) {
                                Text(reasonLabel(match.reason))
                                    .font(TypeScale.caption())
                                    .foregroundStyle(Palette.gold)
                                BottleCard(summary: match.summary)
                            }
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .padding(.horizontal, Space.xl)
            .padding(.top, Space.l)
            .padding(.bottom, 96)
        }
        .background(Palette.background)
        .navigationTitle("Others like this")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Done") { dismiss() }.foregroundStyle(Palette.gold)
            }
        }
    }

    /// Structural relatedness over the shelf. The bottle itself and its
    /// exact multiples are left out: "this is like itself" is not an answer.
    private var matches: [Match] {
        guard let productId = summary.bottle.catalogProductId,
              let identity = env.identity(productId)
        else { return [] }

        var seen = Set<String>()
        let candidates: [(SearchCandidate, BottleSummary)] = shelf.compactMap { other in
            guard other.id != summary.id,
                  let otherId = other.bottle.catalogProductId,
                  otherId != productId,
                  let otherIdentity = env.identity(otherId)
            else { return nil }
            // One candidate per product; the bottles of it come back below.
            guard seen.insert(otherId).inserted else { return nil }
            let product = env.catalog.product(otherId)
            return (SearchCandidate(
                product: otherIdentity,
                recipeCode: product?.code,
                mashbillKey: product?.mashbillKey,
                isInYourHistory: true), other)
        }

        let hits = BottleSearch.related(
            to: identity,
            recipeCode: env.product(for: summary.bottle)?.code,
            in: candidates.map(\.0),
            limit: 30)

        return hits.flatMap { hit -> [Match] in
            shelf
                .filter { $0.bottle.catalogProductId == hit.product.productId }
                .map { Match(summary: $0, reason: hit.reason) }
        }
    }

    private func reasonLabel(_ reason: SearchHit.Reason) -> String {
        switch reason {
        case .sameLine: return "SAME LINE"
        case .sameRecipe: return "SAME RECIPE"
        case .sameDistillery: return "SAME DISTILLERY"
        case .exact, .prefix, .fuzzy: return "RELATED"
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
