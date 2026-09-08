import SwiftUI
import LiquorData
import LiquorEngine

/// Add a bottle: find it in the catalogue, or type in what is not there.
///
/// **Typing it in is a first-class path, not a fallback.** The catalogue will
/// always be small next to what exists — there is a new store pick every week —
/// so an app that can only log what it already knows about is useless to
/// anybody who actually buys picks.
struct AddBottleView: View {
    @Environment(AppEnvironment.self) private var env
    @Environment(\.dismiss) private var dismiss

    // What it is
    @State private var query = ""
    @State private var family: ClassType.Family?
    @State private var chosen: CatalogProduct?
    @State private var isTypingItIn = false

    // Custom product
    @State private var customBrand = ""
    @State private var customExpression = ""
    @State private var customDistillery = ""
    @State private var customClass: ClassType = .kentuckyStraightBourbon

    // This bottle
    @State private var volumeMl = "750"
    @State private var proof = ""
    @State private var price = ""
    @State private var store = ""

    // Release detail
    @State private var isStorePick = false
    @State private var batchNumber = ""
    @State private var barrelNumber = ""
    @State private var pickGroup = ""
    @State private var warehouse = ""
    @State private var recipeCode = ""
    @State private var ageYears = ""
    @State private var ageMonths = ""
    @State private var entryProof = ""
    @State private var charLevel = ""
    @State private var finish = ""
    @State private var bottleNumber = ""
    @State private var bottlesInBatch = ""

    @State private var error: String?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Space.xl) {
                whatIsIt
                if chosen != nil || isTypingItIn {
                    thisBottle
                    releaseDetail
                    saveButton
                }
            }
            .padding(.horizontal, Space.xl)
            .padding(.top, Space.l)
            .padding(.bottom, 96)
        }
        .background(Palette.background)
        .navigationTitle("Add a bottle")
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

    // MARK: - What is it

    @ViewBuilder
    private var whatIsIt: some View {
        if let chosen {
            VStack(alignment: .leading, spacing: Space.m) {
                SectionLabel("What it is")
                HStack(alignment: .top, spacing: Space.m) {
                    BottleMark(height: 52)
                    VStack(alignment: .leading, spacing: Space.xs) {
                        Text(chosen.identity.displayName)
                            .font(TypeScale.title())
                            .foregroundStyle(Palette.text)
                        Text(chosen.classType.label)
                            .font(TypeScale.code(13))
                            .foregroundStyle(Palette.textMuted)
                        Text(chosen.strengthDescription)
                            .font(TypeScale.code(13))
                            .foregroundStyle(Palette.textMuted)
                    }
                    Spacer()
                    Button("Change") { self.chosen = nil }
                        .font(TypeScale.secondary())
                        .foregroundStyle(Palette.gold)
                        .frame(minHeight: Space.tapTarget)
                }
                .padding(Space.l)
                .background(RoundedRectangle(cornerRadius: 12).fill(Palette.surface))
                .overlay(RoundedRectangle(cornerRadius: 12).stroke(Palette.gold, lineWidth: 1))
            }
        } else if isTypingItIn {
            customEntry
        } else {
            searchAndPick
        }
    }

    private var searchAndPick: some View {
        VStack(alignment: .leading, spacing: Space.m) {
            SectionLabel("What is it?")

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

            // Narrow by what kind of thing you are after, which is how people
            // actually shop: "a rye", "a tequila".
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: Space.s) {
                    familyChip(nil, label: "All")
                    ForEach(availableFamilies, id: \.self) { option in
                        familyChip(option, label: option.label)
                    }
                }
            }

            ForEach(matches, id: \.id) { product in
                Button { choose(product) } label: {
                    HStack(spacing: Space.m) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(product.identity.displayName)
                                .font(TypeScale.body())
                                .foregroundStyle(Palette.text)
                                .multilineTextAlignment(.leading)
                            Text("\(product.distillery) · \(product.classType.label)")
                                .font(TypeScale.caption())
                                .textCase(nil)
                                .foregroundStyle(Palette.textMuted)
                                .multilineTextAlignment(.leading)
                        }
                        Spacer()
                    }
                    .padding(.vertical, Space.m)
                    .frame(maxWidth: .infinity, minHeight: Space.tapTarget, alignment: .leading)
                }
                Divider().overlay(Palette.line)
            }

            Button { isTypingItIn = true } label: {
                HStack(spacing: Space.s) {
                    Image(systemName: "plus")
                    Text(query.isEmpty ? "Add one yourself" : "Not here — add “\(query)” yourself")
                        .multilineTextAlignment(.leading)
                }
                .font(TypeScale.body().weight(.semibold))
                .foregroundStyle(Palette.gold)
                .frame(maxWidth: .infinity, minHeight: 50)
                .overlay(RoundedRectangle(cornerRadius: 11).stroke(Palette.gold, lineWidth: 1))
            }
            .padding(.top, Space.s)
        }
    }

    private func familyChip(_ option: ClassType.Family?, label: String) -> some View {
        let isOn = family == option
        return Button { family = isOn ? nil : option } label: {
            Text(label)
                .font(TypeScale.secondary())
                .foregroundStyle(isOn ? Palette.onGold : Palette.textSecondary)
                .padding(.horizontal, Space.l)
                .frame(minHeight: Space.tapTarget)
                .background(RoundedRectangle(cornerRadius: 9)
                    .fill(isOn ? Palette.gold : Palette.surfaceRaised))
        }
    }

    private var customEntry: some View {
        VStack(alignment: .leading, spacing: Space.m) {
            HStack {
                SectionLabel("Add it yourself")
                Spacer()
                Button("Search instead") { isTypingItIn = false }
                    .font(TypeScale.secondary())
                    .foregroundStyle(Palette.gold)
                    .frame(minHeight: Space.tapTarget)
            }

            field("Brand", text: $customBrand, placeholder: "Elijah Craig")
            field("Expression", text: $customExpression, placeholder: "Barrel Proof")
            field("Distillery", text: $customDistillery, placeholder: "Heaven Hill")

            VStack(alignment: .leading, spacing: Space.s) {
                Text("Kind")
                    .font(TypeScale.caption())
                    .textCase(nil)
                    .foregroundStyle(Palette.textMuted)
                Picker("Kind", selection: $customClass) {
                    ForEach(ClassType.allCases, id: \.self) { type in
                        Text(type.label).tag(type)
                    }
                }
                .pickerStyle(.menu)
                .tint(Palette.gold)
            }

            Text("It stays private to you, and behaves like any catalogue bottle.")
                .font(TypeScale.caption())
                .textCase(nil)
                .foregroundStyle(Palette.textMuted)
        }
    }

    // MARK: - This bottle

    private var thisBottle: some View {
        VStack(alignment: .leading, spacing: Space.m) {
            SectionLabel("This bottle")
            HStack(spacing: Space.m) {
                field("Size (ml)", text: $volumeMl, keyboard: .numberPad)
                field("Proof", text: $proof, keyboard: .decimalPad, placeholder: "124.2")
            }
            HStack(spacing: Space.m) {
                field("Paid", text: $price, keyboard: .decimalPad, placeholder: "79.99")
                field("Bought at", text: $store, placeholder: "Total Wine")
            }
            if chosen?.isBarrelProof == true {
                Text("Barrel proof changes every batch — read the proof off the label.")
                    .font(TypeScale.caption())
                    .textCase(nil)
                    .foregroundStyle(Palette.gold)
            }
        }
    }

    // MARK: - Release detail

    private var releaseDetail: some View {
        VStack(alignment: .leading, spacing: Space.m) {
            Toggle(isOn: $isStorePick) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Store pick or single barrel")
                        .font(TypeScale.body())
                        .foregroundStyle(Palette.text)
                    Text("The details on the label that make this barrel different")
                        .font(TypeScale.caption())
                        .textCase(nil)
                        .foregroundStyle(Palette.textMuted)
                }
            }
            .tint(Palette.gold)
            .padding(Space.l)
            .background(RoundedRectangle(cornerRadius: 12).fill(Palette.surface))
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(Palette.line, lineWidth: 1))

            HStack(spacing: Space.m) {
                field("Batch", text: $batchNumber, placeholder: "B523")
                field("Barrel", text: $barrelNumber, placeholder: "42-3C")
            }

            if isStorePick {
                // Everything a real pick prints and most apps drop.
                HStack(spacing: Space.m) {
                    field("Selected by", text: $pickGroup, placeholder: "Bourbon club")
                    field("Warehouse", text: $warehouse, placeholder: "QN / Floor 5")
                }
                HStack(spacing: Space.m) {
                    field("Recipe code", text: $recipeCode, placeholder: "OESQ")
                    field("Entry proof", text: $entryProof, keyboard: .decimalPad, placeholder: "125")
                }
                HStack(spacing: Space.m) {
                    field("Age (years)", text: $ageYears, keyboard: .numberPad, placeholder: "9")
                    field("and months", text: $ageMonths, keyboard: .numberPad, placeholder: "4")
                }
                HStack(spacing: Space.m) {
                    field("Char level", text: $charLevel, keyboard: .numberPad, placeholder: "4")
                    field("Finish", text: $finish, placeholder: "Toasted oak")
                }
                HStack(spacing: Space.m) {
                    field("Bottle no.", text: $bottleNumber, keyboard: .numberPad, placeholder: "47")
                    field("of", text: $bottlesInBatch, keyboard: .numberPad, placeholder: "240")
                }
                Text("A single barrel is nine years and four months, not nine. The "
                     + "months are the reason the pick was chosen.")
                    .font(TypeScale.caption())
                    .textCase(nil)
                    .foregroundStyle(Palette.textMuted)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private var saveButton: some View {
        Button(action: save) {
            Text("Add to collection")
                .font(TypeScale.headline())
                .foregroundStyle(Palette.onGold)
                .frame(maxWidth: .infinity, minHeight: 50)
                .background(RoundedRectangle(cornerRadius: 11)
                    .fill(canSave ? Palette.gold : Palette.surfaceRaised))
        }
        .disabled(!canSave)
    }

    // MARK: - Pieces

    private func field(
        _ title: String,
        text: Binding<String>,
        keyboard: UIKeyboardType = .default,
        placeholder: String = ""
    ) -> some View {
        VStack(alignment: .leading, spacing: Space.xs + 2) {
            Text(title)
                .font(TypeScale.caption())
                .textCase(nil)
                .foregroundStyle(Palette.textMuted)
            TextField(placeholder, text: text)
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

    // MARK: - Derivation

    private var availableFamilies: [ClassType.Family] {
        let present = Set(env.catalog.products.map(\.classType.family))
        return ClassType.Family.allCases.filter { present.contains($0) }
    }

    private var matches: [CatalogProduct] {
        let pool = env.catalog.products.filter { family == nil || $0.classType.family == family }
        let trimmed = query.trimmingCharacters(in: .whitespaces)

        guard !trimmed.isEmpty else {
            return Array(pool.sorted { $0.identity.displayName < $1.identity.displayName }.prefix(12))
        }
        let candidates = pool.map {
            SearchCandidate(product: $0.identity, recipeCode: $0.code, mashbillKey: $0.mashbillKey)
        }
        let hits = BottleSearch.search(query: trimmed, in: candidates, limit: 12)
        return hits.compactMap { hit in pool.first { $0.id == hit.product.productId } }
    }

    private var canSave: Bool {
        if chosen != nil { return true }
        return !customBrand.trimmingCharacters(in: .whitespaces).isEmpty
    }

    private func choose(_ product: CatalogProduct) {
        chosen = product
        if let abv = product.abv { proof = String(format: "%.1f", ABV(percent: abv).proof) }
    }

    // MARK: - Saving

    private func save() {
        let months = (Int(ageYears).map { $0 * 12 } ?? 0) + (Int(ageMonths) ?? 0)
        var bottle = Bottle(
            catalogProductId: chosen?.id,
            customName: chosen == nil ? customName : nil,
            isStorePick: isStorePick,
            pickStore: store.isEmpty ? nil : store,
            barrelNumber: barrelNumber.isEmpty ? nil : barrelNumber,
            batchNumber: batchNumber.isEmpty ? nil : batchNumber,
            pickGroup: pickGroup.isEmpty ? nil : pickGroup,
            warehouse: warehouse.isEmpty ? nil : warehouse,
            recipeCode: recipeCode.isEmpty ? nil : recipeCode.uppercased(),
            ageMonths: months > 0 ? months : nil,
            entryProof: Double(entryProof),
            charLevel: Int(charLevel),
            finish: finish.isEmpty ? nil : finish,
            bottleNumber: Int(bottleNumber),
            bottlesInBatch: Int(bottlesInBatch),
            abv: Double(proof).map { $0 / 2 },
            volumeMl: Double(volumeMl) ?? 750,
            purchasePriceCents: price.isEmpty ? nil : Int((Double(price) ?? 0) * 100),
            purchaseStore: store.isEmpty ? nil : store)

        do {
            if chosen != nil {
                try env.bottles.add(bottle)
            } else {
                let product = CustomCatalogEntry(
                    distillery: customDistillery.isEmpty ? customBrand : customDistillery,
                    brand: customBrand,
                    expression: customExpression,
                    classType: customClass)
                bottle.customName = customName
                try env.bottles.addCustom(product: product, bottle: bottle)
            }
            dismiss()
        } catch {
            self.error = error.localizedDescription
        }
    }

    private var customName: String {
        customExpression.isEmpty ? customBrand : "\(customBrand) \(customExpression)"
    }
}

#Preview {
    NavigationStack { AddBottleView() }
        .environment(AppEnvironment.preview())
        .preferredColorScheme(.dark)
}
