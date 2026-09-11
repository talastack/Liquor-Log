import SwiftUI
import LiquorData
import LiquorEngine

/// Fix a bottle.
///
/// Until this existed every field was write-once. A mistyped proof, a storage
/// location that changed, a barrel number read off the label later — the only
/// remedy was deleting the bottle, which takes its pours and its tastings with
/// it. People do not delete a year of notes to fix a typo; they stop trusting
/// the app and go back to a spreadsheet.
///
/// **The pour log is deliberately not editable here.** What is left in a bottle
/// is derived from pours and level readings, and a screen that let somebody
/// type a remaining volume directly would be a second source of truth that
/// disagrees with the first. Use "Set level" for that — it records an
/// observation instead of overwriting history.
struct EditBottleView: View {
    @Environment(AppEnvironment.self) private var env
    @Environment(\.dismiss) private var dismiss

    let bottleId: String
    var onSave: (() -> Void)?

    @State private var bottle: Bottle?
    @State private var error: String?

    // Strings rather than numbers: a half-typed "12." is not a Double, and a
    // field that fights the keyboard is a field people abandon.
    @State private var proof = ""
    @State private var volumeMl = ""
    @State private var pourOunces = ""
    @State private var price = ""
    @State private var shelfPrice = ""
    @State private var store = ""
    @State private var batchNumber = ""
    @State private var barrelNumber = ""
    @State private var pickGroup = ""
    @State private var warehouse = ""
    @State private var rick = ""
    @State private var floor = ""
    @State private var recipeCode = ""
    @State private var finish = ""
    @State private var topperLetter = ""
    @State private var storageLocation = ""
    @State private var shelfNumber = ""
    @State private var customName = ""

    // A typed-in product, editable here because its identity is what the
    // shelf check matches on: brand groups a line, class is a filter.
    @State private var custom: CustomCatalogEntry?
    @State private var customDistillery = ""
    @State private var customBrand = ""
    @State private var customExpression = ""
    @State private var customClass: ClassType = .bourbon
    @State private var customProduction: ProductionType = .unspecified
    @State private var customBarrelProof = false
    @State private var customBottledInBond = false
    @State private var relinkQuery = ""
    @State private var relinkTarget: CatalogProduct?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Space.xl) {
                if bottle != nil {
                    identity
                    if custom != nil {
                        typedInProduct
                    }
                    strength
                    barrel
                    where_
                    money
                    issues
                    saveButton
                } else {
                    ProgressView().padding(.top, 80)
                }
            }
            .padding(.horizontal, Space.xl)
            .padding(.top, Space.l)
            .padding(.bottom, 96)
        }
        .background(Palette.background)
        .navigationTitle("Edit bottle")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") { dismiss() }.foregroundStyle(Palette.textSecondary)
            }
        }
        .task { load() }
        .alert("Could not save", isPresented: .constant(error != nil)) {
            Button("OK") { error = nil }
        } message: { Text(error ?? "") }
    }

    // MARK: - Sections

    @ViewBuilder
    private var identity: some View {
        if let bottle, bottle.catalogProductId == nil || bottle.customName != nil {
            VStack(alignment: .leading, spacing: Space.m) {
                SectionLabel("Name")
                field("Name", text: $customName)
            }
        }
    }

    private var strength: some View {
        VStack(alignment: .leading, spacing: Space.m) {
            SectionLabel("This bottle")
            HStack(spacing: Space.m) {
                field("Size (ml)", text: $volumeMl, keyboard: .numberPad)
                field("Proof", text: $proof, keyboard: .decimalPad)
                field("Pour (oz)", text: $pourOunces, keyboard: .decimalPad)
            }
        }
    }

    /// The product this bottle is, when the person typed it in. Fixing the
    /// brand here is what makes a "Weller 12" typed under brand "Weller 12"
    /// finally read as the same line as W L Weller. And when the catalogue
    /// turns out to have it after all, everything can be pointed there.
    private var typedInProduct: some View {
        VStack(alignment: .leading, spacing: Space.m) {
            SectionLabel("This product (typed in)")
            field("Distillery", text: $customDistillery)
            HStack(spacing: Space.m) {
                field("Brand", text: $customBrand)
                field("Expression", text: $customExpression)
            }
            Picker("Class", selection: $customClass) {
                ForEach(ClassType.allCases, id: \.self) { type in
                    Text(type.label).tag(type)
                }
            }
            .pickerStyle(.menu)
            .tint(Palette.gold)
            Picker("Production", selection: $customProduction) {
                ForEach(ProductionType.allCases, id: \.self) { type in
                    Text(type.label).tag(type)
                }
            }
            .pickerStyle(.menu)
            .tint(Palette.gold)
            Toggle("Barrel proof", isOn: $customBarrelProof).tint(Palette.gold)
            Toggle("Bottled in bond", isOn: $customBottledInBond).tint(Palette.gold)

            VStack(alignment: .leading, spacing: Space.s) {
                Text("Is it in the catalogue after all?")
                    .font(TypeScale.caption())
                    .textCase(nil)
                    .foregroundStyle(Palette.textMuted)
                if let relinkTarget {
                    HStack(alignment: .top, spacing: Space.m) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(relinkTarget.identity.displayName)
                                .font(TypeScale.body())
                                .foregroundStyle(Palette.text)
                            Text("Every bottle, tasting, wish and note of the typed-in "
                                 + "product moves to this one when you save.")
                                .font(TypeScale.caption())
                                .textCase(nil)
                                .foregroundStyle(Palette.textMuted)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        Spacer()
                        Button("Undo") { self.relinkTarget = nil }
                            .font(TypeScale.secondary())
                            .foregroundStyle(Palette.gold)
                    }
                    .padding(Space.m)
                    .background(RoundedRectangle(cornerRadius: 10).fill(Palette.surface))
                    .overlay(RoundedRectangle(cornerRadius: 10).stroke(Palette.gold, lineWidth: 1))
                } else {
                    field("Search the catalogue", text: $relinkQuery)
                    ForEach(relinkMatches, id: \.id) { product in
                        Button { relinkTarget = product } label: {
                            Text("\(product.identity.displayName) · \(product.distillery)")
                                .font(TypeScale.secondary())
                                .foregroundStyle(Palette.text)
                                .multilineTextAlignment(.leading)
                                .frame(maxWidth: .infinity, minHeight: Space.tapTarget - 8, alignment: .leading)
                        }
                    }
                }
            }
        }
    }

    private var relinkMatches: [CatalogProduct] {
        let trimmed = relinkQuery.trimmingCharacters(in: .whitespaces)
        guard trimmed.count >= 2 else { return [] }
        let candidates = env.catalog.searchCandidates(history: [])
        return BottleSearch.search(query: trimmed, in: candidates, limit: 5)
            .compactMap { env.catalog.product($0.product.productId) }
    }

    private var barrel: some View {
        VStack(alignment: .leading, spacing: Space.m) {
            SectionLabel("This barrel")
            HStack(spacing: Space.m) {
                field("Batch", text: $batchNumber)
                field("Barrel", text: $barrelNumber)
            }
            field("Selected by", text: $pickGroup)
            HStack(spacing: Space.m) {
                field("Warehouse", text: $warehouse)
                field("Rick", text: $rick)
                field("Floor", text: $floor)
            }
            HStack(spacing: Space.m) {
                field("Recipe code", text: $recipeCode)
                field("Finish", text: $finish)
            }
            // The Blanton's stopper letter. Shown for a Blanton's and for any
            // bottle that already has one, never as a field on a Weller.
            if isBlantons || !topperLetter.isEmpty {
                VStack(alignment: .leading, spacing: Space.xs) {
                    field("Topper letter", text: $topperLetter)
                    Text("The letter on the cork: one of B L A N T O N ' S.")
                        .font(TypeScale.caption())
                        .textCase(nil)
                        .foregroundStyle(Palette.textMuted)
                }
            }
        }
    }

    private var isBlantons: Bool {
        guard let bottle else { return false }
        let name = env.name(for: bottle) + " " + (env.distillery(for: bottle) ?? "")
        return name.localizedCaseInsensitiveContains("blanton")
    }

    private var where_: some View {
        VStack(alignment: .leading, spacing: Space.m) {
            SectionLabel("Where you keep it")
            HStack(spacing: Space.m) {
                field("Location", text: $storageLocation)
                field("Your number", text: $shelfNumber, keyboard: .numberPad)
            }
        }
    }

    private var money: some View {
        VStack(alignment: .leading, spacing: Space.m) {
            SectionLabel("Price")
            HStack(spacing: Space.m) {
                field("Paid", text: $price, keyboard: .decimalPad)
                field("Shelf price", text: $shelfPrice, keyboard: .decimalPad)
            }
            field("Bought at", text: $store)
        }
    }

    /// Regulation problems, as WARNINGS.
    ///
    /// The engine has held these rules since the first commit and nothing ever
    /// called them, so a "bottled in bond" at 43% saved in silence. They are
    /// not enforced: a label really can contradict the regulations, an old
    /// bottle can predate a rule, and refusing to save somebody's real bottle
    /// because it fails a check is how an app loses to a spreadsheet.
    @ViewBuilder
    private var issues: some View {
        let found = pending.map { env.bottles.validationIssues(for: $0) } ?? []
        if !found.isEmpty {
            VStack(alignment: .leading, spacing: Space.s) {
                SectionLabel("Worth a look")
                ForEach(found, id: \.rule) { issue in
                    Text(issue.detail)
                        .font(TypeScale.secondary())
                        .foregroundStyle(Palette.gold)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Text("Saved either way. Labels do contradict the regulations, "
                     + "and an old bottle can predate a rule.")
                    .font(TypeScale.caption())
                    .textCase(nil)
                    .foregroundStyle(Palette.textMuted)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private var saveButton: some View {
        VStack(spacing: Space.m) {
            Button(action: save) {
                Text("Save changes")
                    .font(TypeScale.headline())
                    .foregroundStyle(Palette.onGold)
                    .frame(maxWidth: .infinity, minHeight: 50)
                    .background(RoundedRectangle(cornerRadius: 11).fill(Palette.gold))
            }
            Text("Your pours and tastings are untouched.")
                .font(TypeScale.caption())
                .textCase(nil)
                .foregroundStyle(Palette.textMuted)
        }
    }

    private func field(
        _ title: String, text: Binding<String>, keyboard: UIKeyboardType = .default
    ) -> some View {
        VStack(alignment: .leading, spacing: Space.xs + 2) {
            Text(title)
                .font(TypeScale.caption())
                .textCase(nil)
                .foregroundStyle(Palette.textMuted)
            TextField("", text: text)
                .font(TypeScale.body())
                .foregroundStyle(Palette.text)
                .keyboardType(keyboard)
                .autocorrectionDisabled()
                .padding(.horizontal, Space.m)
                .frame(minHeight: 46)
                .background(RoundedRectangle(cornerRadius: 10).fill(Palette.surface))
                .overlay(RoundedRectangle(cornerRadius: 10).stroke(Palette.line, lineWidth: 1))
        }
    }

    // MARK: - Work

    /// The bottle as edited, without saving it — so the warnings above describe
    /// what is on screen rather than what is in the database.
    private var pending: Bottle? {
        guard var edited = bottle else { return nil }
        apply(to: &edited)
        return edited
    }

    /// An empty field means "not recorded" and clears the column. That has to
    /// be possible: a value typed by mistake needs a way out, and treating
    /// blank as "leave alone" makes a wrong entry permanent.
    private func apply(to edited: inout Bottle) {
        edited.customName = blankAsNil(customName) ?? edited.customName
        edited.abv = Double(proof).map { $0 / 2 }
        edited.volumeMl = Double(volumeMl) ?? edited.volumeMl
        // Stored in millilitres; typed in ounces because that is the unit a
        // pour is thought in. Blank keeps the bottle's current size.
        if let oz = Double(pourOunces), oz > 0 {
            edited.pourSizeMl = PourSize(usFluidOunces: oz).milliliters
        }
        edited.purchasePriceCents = Double(price).map { Int(($0 * 100).rounded()) }
        edited.shelfPriceCents = Double(shelfPrice).map { Int(($0 * 100).rounded()) }
        edited.purchaseStore = blankAsNil(store)
        edited.batchNumber = blankAsNil(batchNumber)
        edited.barrelNumber = blankAsNil(barrelNumber)
        edited.pickGroup = blankAsNil(pickGroup)
        edited.warehouse = blankAsNil(warehouse)
        edited.rick = blankAsNil(rick)
        edited.floor = blankAsNil(floor)
        edited.recipeCode = blankAsNil(recipeCode)?.uppercased()
        edited.finish = blankAsNil(finish)
        // Normalised by the engine, so "b" and a curly apostrophe are stored
        // as the letter they mean; anything else is dropped, not saved.
        edited.topperLetter = blankAsNil(topperLetter)
            .flatMap(TopperLetters.normalise)
            .map(String.init)
        edited.storageLocation = blankAsNil(storageLocation)
        edited.shelfNumber = Int(shelfNumber)
    }

    private func blankAsNil(_ value: String) -> String? {
        let trimmed = value.trimmingCharacters(in: .whitespaces)
        return trimmed.isEmpty ? nil : trimmed
    }

    private func load() {
        guard let summary = try? env.bottles.summary(id: bottleId) else { return }
        let found = summary.bottle
        bottle = found

        customName = found.customName ?? ""
        proof = found.abv.map { String(format: "%.1f", ABV(percent: $0).proof) } ?? ""
        volumeMl = String(Int(found.volumeMl.rounded()))
        pourOunces = String(format: "%.1f", found.pourSize.usFluidOunces)
        price = found.purchasePriceCents.map { String(format: "%.2f", Double($0) / 100) } ?? ""
        shelfPrice = found.shelfPriceCents.map { String(format: "%.2f", Double($0) / 100) } ?? ""
        store = found.purchaseStore ?? ""
        batchNumber = found.batchNumber ?? ""
        barrelNumber = found.barrelNumber ?? ""
        pickGroup = found.pickGroup ?? ""
        warehouse = found.warehouse ?? ""
        rick = found.rick ?? ""
        floor = found.floor ?? ""
        recipeCode = found.recipeCode ?? ""
        finish = found.finish ?? ""
        topperLetter = found.topperLetter ?? ""
        storageLocation = found.storageLocation ?? ""

        // A typed-in product resolves to a custom entry; a catalogue one to
        // nothing here, and the section stays hidden.
        if let productId = found.catalogProductId,
           env.catalog.product(productId) == nil,
           let entry = try? env.bottles.customProduct(id: productId), entry.deletedAt == nil {
            custom = entry
            customDistillery = entry.distillery
            customBrand = entry.brand
            customExpression = entry.expression
            customClass = entry.classType
            customProduction = entry.productionType
            customBarrelProof = entry.isBarrelProof
            customBottledInBond = entry.isBottledInBond
        }
        shelfNumber = found.shelfNumber.map(String.init) ?? ""
    }

    private func save() {
        guard var edited = pending else { return }
        do {
            if let custom {
                if let relinkTarget {
                    // Everything referencing the typed-in product moves,
                    // this bottle included, so save the bottle AFTER with
                    // the catalogue id on it.
                    try env.bottles.relinkCustomProduct(id: custom.id, to: relinkTarget.id)
                    edited.catalogProductId = relinkTarget.id
                    edited.customName = nil
                } else {
                    var fixed = custom
                    fixed.distillery = blankAsNil(customDistillery) ?? custom.distillery
                    fixed.brand = blankAsNil(customBrand) ?? custom.brand
                    fixed.expression = customExpression.trimmingCharacters(in: .whitespaces)
                    fixed.classType = customClass
                    fixed.productionType = customProduction
                    fixed.isBarrelProof = customBarrelProof
                    fixed.isBottledInBond = customBottledInBond
                    try env.bottles.updateCustomProduct(fixed)
                }
            }
            try env.bottles.update(edited)
            onSave?()
            dismiss()
        } catch {
            self.error = error.localizedDescription
        }
    }
}

#Preview {
    NavigationStack { EditBottleView(bottleId: "fixture-weller-107") }
        .environment(AppEnvironment.preview())
        .preferredColorScheme(.dark)
}
