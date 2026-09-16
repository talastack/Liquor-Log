import SwiftUI
import LiquorEngine
import LiquorData

/// The hunt: where you looked, what was on the shelf, the lotteries you
/// entered. Read back as the stores that actually turn things up, your
/// wishlist against what was seen lately, and entered / won / pending.
struct HuntLogView: View {
    @Environment(AppEnvironment.self) private var env

    @State private var records: [Sighting] = []
    @State private var facts: [Hunt.Sighting] = []
    @State private var summary = Hunt.Summary.empty
    @State private var onList: [Hunt.Sighting] = []
    @State private var isAdding = false
    @State private var buying: Sighting?
    @State private var error: String?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Space.xl) {
                VStack(alignment: .leading, spacing: Space.s) {
                    Text("Hunt log")
                        .font(TypeScale.largeTitle())
                        .foregroundStyle(Palette.text)
                    Text(summary.headline ?? "Where you looked, what was on the shelf, the lotteries you entered. Nobody writes it down; this does.")
                        .font(TypeScale.secondary())
                        .foregroundStyle(Palette.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                if !onList.isEmpty { onYourList }
                if !summary.stores.isEmpty { stores }
                if let line = summary.lotteries.line { lotteries(line) }

                if records.isEmpty {
                    Text("Log the first one: a bottle you saw on a shelf, or a lottery you put your name in.")
                        .font(TypeScale.secondary())
                        .foregroundStyle(Palette.textMuted)
                        .fixedSize(horizontal: false, vertical: true)
                } else {
                    VStack(alignment: .leading, spacing: Space.m) {
                        SectionLabel("The log")
                        ForEach(records) { record in
                            if let fact = facts.first(where: { $0.id == record.id }) {
                                SightingRow(
                                    fact: fact,
                                    onOutcome: { outcome in setOutcome(record, outcome) },
                                    onBuy: { buying = record },
                                    onRemove: { remove(record) })
                            }
                        }
                    }
                }

                Text("Your own record, on this phone. Nothing here says where a bottle is now.")
                    .font(TypeScale.caption())
                    .textCase(nil)
                    .foregroundStyle(Palette.textMuted)
            }
            .padding(.horizontal, Space.xl)
            .padding(.top, Space.l)
            .padding(.bottom, 96)
        }
        .background(Palette.background)
        .navigationTitle("Hunt log")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button { isAdding = true } label: {
                    Image(systemName: "plus")
                }
                .accessibilityLabel("Log a sighting")
                .foregroundStyle(Palette.gold)
            }
        }
        .task { reload() }
        .onChange(of: env.changeCount) { _, _ in reload() }
        .sheet(isPresented: $isAdding, onDismiss: env.noteChange) {
            NavigationStack { SightingSheet() }
        }
        .sheet(item: $buying, onDismiss: env.noteChange) { record in
            NavigationStack {
                AddBottleView(
                    product: record.catalogProductId.flatMap { env.catalog.product($0) },
                    store: record.store,
                    priceCents: record.cents,
                    onSaved: { bottle in _ = try? env.sightings.markBought(id: record.id, bottleId: bottle.id) })
            }
        }
        .alert("Something went wrong", isPresented: .constant(error != nil)) {
            Button("OK") { error = nil }
        } message: { Text(error ?? "") }
    }

    // MARK: - Sections

    /// The wishlist against the log: what is for sale, where, as of when.
    private var onYourList: some View {
        VStack(alignment: .leading, spacing: Space.m) {
            SectionLabel("On your list, seen lately")
            ForEach(onList) { fact in
                VStack(alignment: .leading, spacing: 2) {
                    Text(fact.name)
                        .font(TypeScale.body())
                        .foregroundStyle(Palette.text)
                    Text(Hunt.line(fact))
                        .font(TypeScale.caption())
                        .textCase(nil)
                        .foregroundStyle(Palette.good)
                }
            }
        }
        .padding(Space.l)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 12).fill(Palette.surface))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Palette.line, lineWidth: 1))
    }

    /// Stores ranked by what you have found there: the answer to "which
    /// one is worth the drive".
    private var stores: some View {
        VStack(alignment: .leading, spacing: Space.m) {
            SectionLabel("Stores")
            ForEach(summary.stores.prefix(6)) { store in
                HStack(alignment: .firstTextBaseline) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(store.name)
                            .font(TypeScale.body())
                            .foregroundStyle(Palette.text)
                        Text(storeLine(store))
                            .font(TypeScale.caption())
                            .textCase(nil)
                            .foregroundStyle(Palette.textMuted)
                    }
                    Spacer()
                    Text("\(store.sightings)")
                        .font(TypeScale.code(15))
                        .foregroundStyle(Palette.gold)
                }
            }
        }
    }

    private func storeLine(_ store: Hunt.Store) -> String {
        var parts = ["\(store.products) \(store.products == 1 ? "product" : "products")"]
        if store.wishlistHits > 0 { parts.append("\(store.wishlistHits) from your wishlist") }
        parts.append("last \(Hunt.ago(AgeMath.days(from: store.lastAt, to: Date())))")
        return parts.joined(separator: " · ")
    }

    private func lotteries(_ line: String) -> some View {
        VStack(alignment: .leading, spacing: Space.s) {
            SectionLabel("Lotteries")
            Text(line)
                .font(TypeScale.body())
                .foregroundStyle(Palette.text)
        }
    }

    // MARK: - Data

    private func reload() {
        do {
            records = try env.sightings.all()
            facts = try env.sightings.facts { env.sightingName($0) }
            let wanted = Set(((try? env.wishlist.items()) ?? []).compactMap(\.catalogProductId))
            summary = Hunt.summarise(facts, wishlist: wanted)
            onList = Hunt.onYourList(facts, wishlist: wanted)
        } catch {
            self.error = error.localizedDescription
        }
    }

    private func setOutcome(_ record: Sighting, _ outcome: Hunt.Outcome?) {
        do { try env.sightings.setOutcome(id: record.id, outcome: outcome); reload() } catch { self.error = error.localizedDescription }
    }

    private func remove(_ record: Sighting) {
        do { try env.sightings.remove(id: record.id); reload() } catch { self.error = error.localizedDescription }
    }
}

/// One line of the log, with the one or two things you can do to it.
struct SightingRow: View {
    let fact: Hunt.Sighting
    let onOutcome: (Hunt.Outcome?) -> Void
    let onBuy: () -> Void
    let onRemove: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: Space.m) {
            Image(systemName: fact.kind == .seen ? "eye" : "ticket")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(fact.kind == .seen ? Palette.gold : Palette.textSecondary)
                .frame(width: 22, height: 22)
                .padding(.top, 2)

            VStack(alignment: .leading, spacing: Space.xs) {
                Text(fact.name)
                    .font(TypeScale.body())
                    .foregroundStyle(Palette.text)
                    .fixedSize(horizontal: false, vertical: true)
                Text(Hunt.line(fact))
                    .font(TypeScale.caption())
                    .textCase(nil)
                    .foregroundStyle(fact.outcome == .won ? Palette.good : Palette.textMuted)
                    .fixedSize(horizontal: false, vertical: true)

                if fact.kind == .entered, fact.outcome == nil {
                    HStack(spacing: Space.l) {
                        Button("Won") { onOutcome(.won) }
                        Button("Lost") { onOutcome(.lost) }
                    }
                    .font(TypeScale.secondary().weight(.semibold))
                    .foregroundStyle(Palette.gold)
                    .frame(minHeight: Space.tapTarget - 8)
                } else if fact.kind == .seen, fact.boughtBottleId == nil {
                    Button(action: onBuy) {
                        HStack(spacing: Space.xs) {
                            Image(systemName: "bag")
                            Text("Bought it")
                        }
                        .font(TypeScale.secondary().weight(.semibold))
                        .foregroundStyle(Palette.gold)
                        .frame(minHeight: Space.tapTarget - 8)
                    }
                    .accessibilityLabel("Add \(fact.name) to your collection")
                }
            }

            Spacer(minLength: Space.s)

            Button(action: onRemove) {
                Image(systemName: "xmark")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Palette.textMuted)
                    .frame(width: Space.tapTarget, height: Space.tapTarget)
            }
            .accessibilityLabel("Remove this from the log")
        }
        .padding(Space.l)
        .background(RoundedRectangle(cornerRadius: 12).fill(Palette.surface))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Palette.line, lineWidth: 1))
    }
}

/// Log one: what, where, at what, how many -- or which lottery.
struct SightingSheet: View {
    @Environment(AppEnvironment.self) private var env
    @Environment(\.dismiss) private var dismiss

    /// Opened from a shelf-check card, with the product and the price
    /// already typed.
    init(product: ProductIdentity? = nil, cents: Int? = nil) {
        _chosen = State(initialValue: product)
        _price = State(initialValue: cents.map { String(format: "%.2f", Double($0) / 100) } ?? "")
    }

    @State private var query = ""
    @State private var chosen: ProductIdentity?
    @State private var customName = ""
    @State private var kind: Hunt.Kind = .seen
    @State private var store = ""
    @State private var price = ""
    @State private var count = ""
    @State private var note = ""
    @State private var seenOn = Date()
    @State private var recentStores: [String] = []
    @State private var error: String?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Space.xl) {
                if let chosen {
                    chosenCard(chosen)
                } else {
                    search
                }
                kindPicker
                place
                if kind == .seen { shelf }
                extras
                saveButton
            }
            .padding(.horizontal, Space.xl)
            .padding(.top, Space.l)
            .padding(.bottom, 96)
        }
        .background(Palette.background)
        .navigationTitle(kind == .seen ? "Seen on a shelf" : "Entered a lottery")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") { dismiss() }.foregroundStyle(Palette.textSecondary)
            }
        }
        .task { recentStores = (try? env.sightings.stores()) ?? [] }
        .alert("Could not save", isPresented: .constant(error != nil)) {
            Button("OK") { error = nil }
        } message: { Text(error ?? "") }
    }

    private func chosenCard(_ product: ProductIdentity) -> some View {
        HStack(alignment: .top, spacing: Space.m) {
            VStack(alignment: .leading, spacing: 2) {
                Text(product.displayName)
                    .font(TypeScale.title())
                    .foregroundStyle(Palette.text)
                Text(product.distillery)
                    .font(TypeScale.code(13))
                    .foregroundStyle(Palette.textMuted)
            }
            Spacer()
            Button("Change") { chosen = nil }
                .font(TypeScale.secondary())
                .foregroundStyle(Palette.gold)
                .frame(minHeight: Space.tapTarget)
        }
        .padding(Space.l)
        .background(RoundedRectangle(cornerRadius: 12).fill(Palette.surface))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Palette.gold, lineWidth: 1))
    }

    private var search: some View {
        VStack(alignment: .leading, spacing: Space.m) {
            SectionLabel("What did you see?")
            HStack(spacing: Space.m) {
                Image(systemName: "magnifyingglass").foregroundStyle(Palette.textMuted)
                TextField("Distillery, brand or expression", text: $query)
                    .font(TypeScale.body())
                    .foregroundStyle(Palette.text)
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.never)
            }
            .padding(.horizontal, Space.l)
            .frame(minHeight: 52)
            .background(RoundedRectangle(cornerRadius: 11).fill(Palette.surface))
            .overlay(RoundedRectangle(cornerRadius: 11).stroke(Palette.line, lineWidth: 1))

            ForEach(matches, id: \.productId) { product in
                Button { chosen = product } label: {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(product.displayName)
                            .font(TypeScale.body())
                            .foregroundStyle(Palette.text)
                            .multilineTextAlignment(.leading)
                        Text(product.distillery)
                            .font(TypeScale.caption())
                            .textCase(nil)
                            .foregroundStyle(Palette.textMuted)
                    }
                    .frame(maxWidth: .infinity, minHeight: Space.tapTarget, alignment: .leading)
                }
                Divider().overlay(Palette.line)
            }

            field("Or type a name", text: $customName)
        }
    }

    private var kindPicker: some View {
        Picker("What happened", selection: $kind) {
            ForEach(Hunt.Kind.allCases, id: \.self) { Text($0.label).tag($0) }
        }
        .pickerStyle(.segmented)
    }

    private var place: some View {
        VStack(alignment: .leading, spacing: Space.m) {
            SectionLabel(kind == .seen ? "Where" : "Who runs it")
            field(kind == .seen ? "Store" : "Virginia ABC, a shop's raffle…", text: $store)
            if !recentStores.isEmpty {
                FlowLayout(spacing: Space.s) {
                    ForEach(recentStores.prefix(8), id: \.self) { name in
                        Button { store = name } label: {
                            Text(name)
                                .font(TypeScale.caption())
                                .textCase(nil)
                                .foregroundStyle(Hunt.storeKey(name) == Hunt.storeKey(store) ? Palette.onGold : Palette.textSecondary)
                                .padding(.horizontal, Space.m)
                                .frame(minHeight: 32)
                                .background(Capsule().fill(Hunt.storeKey(name) == Hunt.storeKey(store) ? Palette.gold : Palette.surfaceRaised))
                        }
                    }
                }
            }
        }
    }

    private var shelf: some View {
        VStack(alignment: .leading, spacing: Space.m) {
            SectionLabel("On the shelf")
            HStack(spacing: Space.m) {
                field("Price", text: $price).keyboardType(.decimalPad)
                field("How many", text: $count).keyboardType(.numberPad)
            }
            Text("Zero is worth logging too: it says the store had it and it went.")
                .font(TypeScale.caption())
                .textCase(nil)
                .foregroundStyle(Palette.textMuted)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var extras: some View {
        VStack(alignment: .leading, spacing: Space.m) {
            DatePicker("When", selection: $seenOn, in: ...Date(), displayedComponents: .date)
                .font(TypeScale.body())
                .foregroundStyle(Palette.text)
                .tint(Palette.gold)
            field("Note (optional)", text: $note)
        }
    }

    private func field(_ placeholder: String, text: Binding<String>) -> some View {
        TextField(placeholder, text: text)
            .font(TypeScale.body())
            .foregroundStyle(Palette.text)
            .padding(.horizontal, Space.m)
            .frame(minHeight: 46)
            .background(RoundedRectangle(cornerRadius: 10).fill(Palette.surface))
            .overlay(RoundedRectangle(cornerRadius: 10).stroke(Palette.line, lineWidth: 1))
    }

    private var saveButton: some View {
        Button(action: save) {
            Text(kind == .seen ? "Log the sighting" : "Log the entry")
                .font(TypeScale.headline())
                .foregroundStyle(Palette.onGold)
                .frame(maxWidth: .infinity, minHeight: 50)
                .background(RoundedRectangle(cornerRadius: 11)
                    .fill(canSave ? Palette.gold : Palette.surfaceRaised))
        }
        .disabled(!canSave)
    }

    private var canSave: Bool {
        (chosen != nil || !customName.trimmingCharacters(in: .whitespaces).isEmpty)
            && !store.trimmingCharacters(in: .whitespaces).isEmpty
    }

    private var matches: [ProductIdentity] {
        let trimmed = query.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return [] }
        let candidates = env.catalog.products.map {
            SearchCandidate(product: $0.identity, recipeCode: $0.code, mashbillKey: $0.mashbillKey)
        }
        return BottleSearch.search(query: trimmed, in: candidates, limit: 8).map(\.product)
    }

    private func save() {
        let cents = LocalNumber.parse(price).map { Int(($0 * 100).rounded()) }
        do {
            try env.sightings.record(
                catalogProductId: chosen?.productId,
                customName: chosen == nil ? customName : nil,
                kind: kind,
                store: store,
                region: env.region,
                cents: kind == .seen ? cents : nil,
                count: Int(count.trimmingCharacters(in: .whitespaces)),
                note: note,
                seenAt: Int64(seenOn.timeIntervalSince1970 * 1000))
            // A shelf price is a shelf price: the same anonymous report the
            // aisle check makes, when sharing is on.
            if kind == .seen { env.sawPrice(productId: chosen?.productId, cents: cents) }
            dismiss()
        } catch {
            self.error = error.localizedDescription
        }
    }
}

#Preview {
    NavigationStack { HuntLogView() }
        .environment(AppEnvironment.preview())
}
