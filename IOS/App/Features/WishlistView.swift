import SwiftUI
import LiquorData
import LiquorEngine

/// Bottles you want, and the price you would pay.
///
/// The target price is what makes this more than a list of names you already
/// remember. It answers the question you actually have standing in the aisle:
/// *I want this, but not at that price.*
struct WishlistView: View {
    @Environment(AppEnvironment.self) private var env

    @State private var items: [WishlistItem] = []
    @State private var isAdding = false
    /// The wish being turned into a bottle, while its sheet is up.
    @State private var buying: WishlistItem?
    @State private var error: String?

    /// Bottles killed in the last three months that are not on the list.
    /// The moment after a bottle goes is when "would I buy it again" has an
    /// answer, and the tasting sheet may already hold it.
    @State private var recentlyFinished: [Finished] = []

    struct Finished: Identifiable {
        let bottle: Bottle
        let name: String
        let saidRebuy: Rebuy?
        var id: String { bottle.id }
    }

    /// How long a killed bottle stays in the "buy again?" list.
    private static let recentDays = 90

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: Space.m) {
                header
                if items.isEmpty && recentlyFinished.isEmpty {
                    empty
                } else if items.isEmpty {
                    Text("Nothing on the list yet.")
                        .font(TypeScale.secondary())
                        .foregroundStyle(Palette.textMuted)
                } else {
                    ForEach(items) { item in
                        WishlistRow(
                            item: item,
                            name: name(for: item),
                            onBuy: { buying = item },
                            onRemove: { remove(item) })
                    }
                }

                if !recentlyFinished.isEmpty {
                    buyAgain
                }
            }
            .padding(.horizontal, Space.xl)
            .padding(.bottom, 96)
        }
        .background(Palette.background)
        .navigationTitle("Wishlist")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button { isAdding = true } label: { Image(systemName: "plus") }
                    .foregroundStyle(Palette.gold)
            }
        }
        .sheet(isPresented: $isAdding) {
            NavigationStack { AddToWishlistView(onSave: { reload() }) }
        }
        .sheet(item: $buying) { item in
            NavigationStack {
                BuyFromWishlistView(item: item, name: name(for: item), onDone: { reload() })
            }
        }
        .task { reload() }
        .refreshable { reload() }
        .alert("Something went wrong", isPresented: .constant(error != nil)) {
            Button("OK") { error = nil }
        } message: { Text(error ?? "") }
    }

    private var header: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(items.count == 1 ? "1 bottle" : "\(items.count) bottles")
                .font(TypeScale.secondary())
                .foregroundStyle(Palette.textSecondary)
            Spacer()
            // The list as a gift list: names only. A ceiling is a note to
            // yourself and a price on a list you hand somebody is a demand.
            if !items.isEmpty {
                ShareLink(item: giftList) {
                    HStack(spacing: Space.xs) {
                        Image(systemName: "gift")
                        Text("Share as a list")
                    }
                    .font(TypeScale.secondary())
                    .foregroundStyle(Palette.gold)
                    .frame(minHeight: Space.tapTarget)
                }
            }
        }
        .padding(.top, Space.s)
    }

    /// Names only, one per line, ready for a message.
    private var giftList: String {
        (["Bottles I am looking for:"] + items.map { "• " + name(for: $0) })
            .joined(separator: "\n")
    }

    private var empty: some View {
        VStack(spacing: Space.l) {
            BottleMark(height: 84)
            Text("Nothing on the list")
                .font(TypeScale.title())
                .foregroundStyle(Palette.text)
            Text("Add a bottle you are looking for, with the most you would pay "
                 + "for it. The price is the useful part.")
                .font(TypeScale.secondary())
                .foregroundStyle(Palette.textMuted)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 64)
    }

    /// Killed lately, and not yet on the list. Stated as bookkeeping -- a
    /// bottle went, do you want another -- never as a tally of bottles
    /// finished.
    private var buyAgain: some View {
        VStack(alignment: .leading, spacing: Space.m) {
            SectionLabel("Finished lately — buy again?")
            ForEach(recentlyFinished) { finished in
                HStack(alignment: .center, spacing: Space.m) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(finished.name)
                            .font(TypeScale.body())
                            .foregroundStyle(Palette.text)
                            .fixedSize(horizontal: false, vertical: true)
                        if let said = finished.saidRebuy {
                            Text(rebuyLine(said))
                                .font(TypeScale.caption())
                                .textCase(nil)
                                .foregroundStyle(said == .no ? Palette.bad : Palette.textMuted)
                        }
                    }
                    Spacer()
                    Button {
                        wishFor(finished)
                    } label: {
                        Text("Add")
                            .font(TypeScale.secondary().weight(.semibold))
                            .foregroundStyle(Palette.gold)
                            .frame(minWidth: Space.tapTarget, minHeight: Space.tapTarget)
                    }
                }
                .padding(Space.l)
                .background(RoundedRectangle(cornerRadius: 12).fill(Palette.surface))
                .overlay(RoundedRectangle(cornerRadius: 12).stroke(Palette.line, lineWidth: 1))
            }
        }
        .padding(.top, Space.l)
    }

    private func rebuyLine(_ rebuy: Rebuy) -> String {
        switch rebuy {
        case .yes: return "You said you would buy it again"
        case .maybe: return "You said maybe"
        case .no: return "You said you would not"
        }
    }

    private func wishFor(_ finished: Finished) {
        do {
            try env.wishlist.add(
                catalogProductId: finished.bottle.catalogProductId,
                customName: finished.bottle.catalogProductId == nil ? finished.name : nil,
                targetPriceCents: finished.bottle.purchasePriceCents)
            reload()
        } catch { self.error = error.localizedDescription }
    }

    private func loadRecentlyFinished() {
        let cutoff = Int64(Date().addingTimeInterval(-Double(Self.recentDays) * 86_400)
            .timeIntervalSince1970 * 1000)
        let listed = Set(items.compactMap(\.catalogProductId))
        let killed = ((try? env.bottles.summaries(includeFinished: true)) ?? [])
            .filter { $0.bottle.isFinished }
            .filter { ($0.bottle.finishedAt ?? 0) >= cutoff }
            .filter { $0.bottle.catalogProductId.map { !listed.contains($0) } ?? true }
            .sorted { ($0.bottle.finishedAt ?? 0) > ($1.bottle.finishedAt ?? 0) }

        // One row per product: three empties of one thing is one question.
        var seen = Set<String>()
        recentlyFinished = killed.compactMap { summary in
            let key = summary.bottle.catalogProductId ?? summary.id
            guard seen.insert(key).inserted else { return nil }
            let latest = (try? env.tastings.history(bottleId: summary.id))?.first
            return Finished(
                bottle: summary.bottle,
                name: env.name(for: summary.bottle),
                saidRebuy: latest?.tasting.wouldRebuy)
        }
    }

    private func name(for item: WishlistItem) -> String {
        if let id = item.catalogProductId, let identity = env.identity(id) {
            return identity.displayName
        }
        return item.customName ?? "Untitled"
    }

    private func reload() {
        do { items = try env.wishlist.items() } catch { self.error = error.localizedDescription }
        loadRecentlyFinished()
    }

    private func remove(_ item: WishlistItem) {
        do {
            try env.wishlist.remove(id: item.id)
            reload()
        } catch { self.error = error.localizedDescription }
    }
}

struct WishlistRow: View {
    let item: WishlistItem
    let name: String
    let onBuy: () -> Void
    let onRemove: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: Space.m) {
            BottleMark(height: 52)

            VStack(alignment: .leading, spacing: Space.xs) {
                Text(name)
                    .font(TypeScale.title())
                    .foregroundStyle(Palette.text)
                    .fixedSize(horizontal: false, vertical: true)

                if let target = item.targetPriceCents {
                    Text("Up to \(Money.short(target))")
                        .font(TypeScale.code(13))
                        .foregroundStyle(Palette.gold)
                } else {
                    Text("No price set")
                        .font(TypeScale.caption())
                        .textCase(nil)
                        .foregroundStyle(Palette.textMuted)
                }

                if let note = item.note, !note.isEmpty {
                    Text(note)
                        .font(TypeScale.caption())
                        .textCase(nil)
                        .foregroundStyle(Palette.textMuted)
                        .fixedSize(horizontal: false, vertical: true)
                }

                // The one action a wishlist row exists for. Getting the bottle
                // and still seeing it on the list is the drift that makes
                // people stop trusting the list.
                Button(action: onBuy) {
                    HStack(spacing: Space.xs) {
                        Image(systemName: "bag")
                        Text("Bought it")
                    }
                    .font(TypeScale.secondary().weight(.semibold))
                    .foregroundStyle(Palette.gold)
                    .frame(minHeight: Space.tapTarget)
                }
                .accessibilityLabel("Add \(name) to your collection")
            }

            Spacer(minLength: Space.s)

            Button(action: onRemove) {
                Image(systemName: "xmark")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Palette.textMuted)
                    .frame(width: Space.tapTarget, height: Space.tapTarget)
            }
            .accessibilityLabel("Remove \(name) from the wishlist")
        }
        .padding(Space.l)
        .background(RoundedRectangle(cornerRadius: 12).fill(Palette.surface))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Palette.line, lineWidth: 1))
    }
}

/// Put something on the list. Search the catalogue, or type a name.
struct AddToWishlistView: View {
    @Environment(AppEnvironment.self) private var env
    @Environment(\.dismiss) private var dismiss

    var onSave: (() -> Void)?

    @State private var query = ""
    @State private var chosen: CatalogProduct?
    @State private var customName = ""
    @State private var targetPrice = ""
    @State private var note = ""
    @State private var error: String?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Space.xl) {
                if let chosen {
                    chosenCard(chosen)
                } else {
                    search
                }
                details
                saveButton
            }
            .padding(.horizontal, Space.xl)
            .padding(.top, Space.l)
            .padding(.bottom, 96)
        }
        .background(Palette.background)
        .navigationTitle("Add to wishlist")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") { dismiss() }.foregroundStyle(Palette.textSecondary)
            }
        }
        .alert("Could not save", isPresented: .constant(error != nil)) {
            Button("OK") { error = nil }
        } message: { Text(error ?? "") }
    }

    private func chosenCard(_ product: CatalogProduct) -> some View {
        HStack(alignment: .top, spacing: Space.m) {
            VStack(alignment: .leading, spacing: 2) {
                Text(product.identity.displayName)
                    .font(TypeScale.title())
                    .foregroundStyle(Palette.text)
                Text(product.classType.label)
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
            SectionLabel("What are you after?")

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

            ForEach(matches, id: \.id) { product in
                Button { chosen = product } label: {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(product.identity.displayName)
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

            // A wishlist is mostly things you cannot buy yet, so the ones least
            // likely to be in a catalogue are exactly the ones people want on
            // it. Typing a name has to work.
            TextField("Or type a name", text: $customName)
                .font(TypeScale.body())
                .foregroundStyle(Palette.text)
                .padding(.horizontal, Space.m)
                .frame(minHeight: 46)
                .background(RoundedRectangle(cornerRadius: 10).fill(Palette.surface))
                .overlay(RoundedRectangle(cornerRadius: 10).stroke(Palette.line, lineWidth: 1))
        }
    }

    private var details: some View {
        VStack(alignment: .leading, spacing: Space.m) {
            SectionLabel("What would you pay?")

            TextField("Most you would pay", text: $targetPrice)
                .font(TypeScale.body())
                .foregroundStyle(Palette.text)
                .keyboardType(.decimalPad)
                .padding(.horizontal, Space.m)
                .frame(minHeight: 46)
                .background(RoundedRectangle(cornerRadius: 10).fill(Palette.surface))
                .overlay(RoundedRectangle(cornerRadius: 10).stroke(Palette.line, lineWidth: 1))

            TextField("Note (optional)", text: $note)
                .font(TypeScale.body())
                .foregroundStyle(Palette.text)
                .padding(.horizontal, Space.m)
                .frame(minHeight: 46)
                .background(RoundedRectangle(cornerRadius: 10).fill(Palette.surface))
                .overlay(RoundedRectangle(cornerRadius: 10).stroke(Palette.line, lineWidth: 1))

            Text("Optional, but it is the useful part — it turns the list from "
                 + "names you already remember into an answer at the shelf.")
                .font(TypeScale.caption())
                .textCase(nil)
                .foregroundStyle(Palette.textMuted)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var saveButton: some View {
        Button(action: save) {
            Text("Add to wishlist")
                .font(TypeScale.headline())
                .foregroundStyle(Palette.onGold)
                .frame(maxWidth: .infinity, minHeight: 50)
                .background(RoundedRectangle(cornerRadius: 11)
                    .fill(canSave ? Palette.gold : Palette.surfaceRaised))
        }
        .disabled(!canSave)
    }

    private var canSave: Bool {
        chosen != nil || !customName.trimmingCharacters(in: .whitespaces).isEmpty
    }

    private var matches: [CatalogProduct] {
        let trimmed = query.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return [] }
        let candidates = env.catalog.products.map {
            SearchCandidate(product: $0.identity, recipeCode: $0.code, mashbillKey: $0.mashbillKey)
        }
        return BottleSearch.search(query: trimmed, in: candidates, limit: 8)
            .compactMap { hit in env.catalog.products.first { $0.id == hit.product.productId } }
    }

    private func save() {
        do {
            try env.wishlist.add(
                catalogProductId: chosen?.id,
                customName: chosen == nil ? customName : nil,
                targetPriceCents: Double(targetPrice).map { Int(($0 * 100).rounded()) },
                note: note.isEmpty ? nil : note)
            onSave?()
            dismiss()
        } catch {
            self.error = error.localizedDescription
        }
    }
}


/// Turn a wish into a bottle: what you paid, where, and how big.
///
/// Three fields, because at the till that is all anybody knows. Everything
/// else -- the barrel, the batch, the open date -- is editable on the bottle
/// afterwards. The price you said you would pay is shown against the price
/// you did, since that comparison is what the wishlist was for.
struct BuyFromWishlistView: View {
    @Environment(AppEnvironment.self) private var env
    @Environment(\.dismiss) private var dismiss

    let item: WishlistItem
    let name: String
    var onDone: (() -> Void)?

    @State private var paid = ""
    @State private var store = ""
    @State private var volume = 750
    @State private var error: String?

    private let sizes = [375, 700, 750, 1000, 1750]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Space.xl) {
                VStack(alignment: .leading, spacing: Space.xs) {
                    Text(name)
                        .font(TypeScale.largeTitle())
                        .foregroundStyle(Palette.text)
                        .fixedSize(horizontal: false, vertical: true)
                    if let target = item.targetPriceCents {
                        Text("You said up to \(Money.short(target)).")
                            .font(TypeScale.secondary())
                            .foregroundStyle(Palette.textSecondary)
                    }
                }

                VStack(alignment: .leading, spacing: Space.m) {
                    SectionLabel("What you paid")
                    TextField("Price", text: $paid)
                        .font(TypeScale.body())
                        .foregroundStyle(Palette.text)
                        .keyboardType(.decimalPad)
                        .padding(.horizontal, Space.m)
                        .frame(minHeight: 46)
                        .background(RoundedRectangle(cornerRadius: 10).fill(Palette.surface))
                        .overlay(RoundedRectangle(cornerRadius: 10).stroke(Palette.line, lineWidth: 1))

                    if let verdict {
                        Text(verdict.text)
                            .font(TypeScale.secondary())
                            .foregroundStyle(verdict.isOver ? Palette.bad : Palette.good)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    TextField("Where (optional)", text: $store)
                        .font(TypeScale.body())
                        .foregroundStyle(Palette.text)
                        .padding(.horizontal, Space.m)
                        .frame(minHeight: 46)
                        .background(RoundedRectangle(cornerRadius: 10).fill(Palette.surface))
                        .overlay(RoundedRectangle(cornerRadius: 10).stroke(Palette.line, lineWidth: 1))
                }

                VStack(alignment: .leading, spacing: Space.m) {
                    SectionLabel("Bottle size")
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: Space.s) {
                            ForEach(sizes, id: \.self) { ml in
                                Button { volume = ml } label: {
                                    Text("\(ml) ml")
                                        .font(TypeScale.secondary())
                                        .foregroundStyle(volume == ml ? Palette.onGold : Palette.textSecondary)
                                        .padding(.horizontal, Space.l)
                                        .frame(minHeight: Space.tapTarget - 8)
                                        .background(RoundedRectangle(cornerRadius: 9)
                                            .fill(volume == ml ? Palette.gold : Palette.surfaceRaised))
                                }
                            }
                        }
                    }
                }

                Button(action: buy) {
                    Text("Add to my collection")
                        .font(TypeScale.headline())
                        .foregroundStyle(Palette.onGold)
                        .frame(maxWidth: .infinity, minHeight: 50)
                        .background(RoundedRectangle(cornerRadius: 11).fill(Palette.gold))
                }

                Text("It comes off the wishlist and goes on the shelf, sealed and "
                     + "full, dated today. Barrel and batch detail can be added on "
                     + "the bottle afterwards.")
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
        .navigationTitle("Bought it")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") { dismiss() }.foregroundStyle(Palette.textSecondary)
            }
        }
        .alert("Could not save", isPresented: .constant(error != nil)) {
            Button("OK") { error = nil }
        } message: { Text(error ?? "") }
    }

    private var paidCents: Int? {
        Double(paid.trimmingCharacters(in: .whitespaces)).map { Int(($0 * 100).rounded()) }
    }

    /// Paid against what you said you would pay. Only when both exist: no
    /// ceiling means no verdict, and a verdict about nothing reads as a bug.
    private var verdict: (text: String, isOver: Bool)? {
        guard let paidCents, let target = item.targetPriceCents else { return nil }
        let gap = paidCents - target
        if gap > 0 {
            return ("\(Money.short(gap)) over what you said you would pay.", true)
        }
        if gap == 0 {
            return ("Exactly what you said you would pay.", false)
        }
        return ("\(Money.short(-gap)) under your ceiling.", false)
    }

    private func buy() {
        do {
            let bottle = Bottle(
                volumeMl: Double(volume),
                purchaseDate: Bottle.nowMilliseconds(),
                purchasePriceCents: paidCents,
                purchaseStore: store.trimmingCharacters(in: .whitespaces).isEmpty ? nil : store)

            // A typed-name wish has no product yet. It gets a private one, the
            // same as typing a bottle in by hand, so the shelf check can
            // answer for it from now on.
            var product: CustomCatalogEntry?
            if item.catalogProductId == nil, let typed = item.customName {
                product = CustomCatalogEntry(distillery: typed, brand: typed, classType: .bourbon)
            }

            try env.wishlist.buy(item, as: bottle, creating: product)
            onDone?()
            dismiss()
        } catch {
            self.error = error.localizedDescription
        }
    }
}

#Preview {
    NavigationStack { WishlistView() }
        .environment(AppEnvironment.preview())
        .preferredColorScheme(.dark)
}
