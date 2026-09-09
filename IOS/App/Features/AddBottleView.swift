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
    @State private var shelfPrice = ""
    @State private var purchasedOn = Date()

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
    @State private var rick = ""
    @State private var floor = ""
    @State private var dumpedAt: Date = Date()
    @State private var hasDumpDate = false
    @State private var chillFiltered: ChillFiltration = .notStated

    // Where you put it
    @State private var storageLocation = ""
    @State private var shelfNumber = ""

    // How full it is right now
    @State private var isAlreadyOpen = false
    @State private var openedOn = Date()
    @State private var fillPercent: Double = 100

    @State private var error: String?
    @State private var isScanning = false

    /// What you have paid for the chosen product before, for the live verdict
    /// as a price is typed.
    @State private var priceHistory: PriceHistory.Summary?

    /// Three states, not two. Most labels say nothing at all, and recording
    /// "no" for every one of those would be inventing a fact.
    enum ChillFiltration: String, CaseIterable, Identifiable {
        case notStated = "Not stated"
        case filtered = "Chill filtered"
        case notFiltered = "Non-chill filtered"

        var id: String { rawValue }

        var value: Bool? {
            switch self {
            case .notStated: return nil
            case .filtered: return true
            case .notFiltered: return false
            }
        }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Space.xl) {
                whatIsIt
                if chosen != nil || isTypingItIn {
                    thisBottle
                    releaseDetail
                    whereYouKeepIt
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
        .sheet(isPresented: $isScanning) {
            NavigationStack {
                ScanLabelView { reading, product in apply(reading, product) }
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

            // Offered ALONGSIDE search and typing, never instead of them.
            // The research has a developer who built label recognition and
            // removed it because it was slower than typing; if that turns out
            // to be true here, this button goes and nothing else changes.
            Button { isScanning = true } label: {
                HStack(spacing: Space.s) {
                    Image(systemName: "camera")
                    Text("Scan the label")
                }
                .font(TypeScale.body().weight(.semibold))
                .foregroundStyle(Palette.text)
                .frame(maxWidth: .infinity, minHeight: 50)
                .overlay(RoundedRectangle(cornerRadius: 11)
                    .stroke(Palette.line, lineWidth: 1))
            }
            .padding(.top, Space.s)

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

            // The shelf price, which is not always what you paid -- a sale, a
            // club discount and a bundle all make the two differ.
            //
            // This is the app's price reference and it belongs to you. Every
            // third-party source carries a licensing question; a price you
            // wrote down about a shelf you stood in front of carries none, and
            // it gets better with use rather than staler.
            field(
                "Shelf price (if it differed)", text: $shelfPrice,
                keyboard: .decimalPad, placeholder: "89.99")

            // The third of the three dates people keep -- purchased, opened,
            // killed -- and the only one that was never captured. Without it
            // "which of these has sat longest" cannot be answered, the price
            // history has no dates on it, and the CSV column is always blank.
            //
            // Defaults to today because adding a bottle usually means having
            // just bought it, and is editable for one that has been on the
            // shelf for years.
            VStack(alignment: .leading, spacing: Space.xs + 2) {
                Text("Bought on")
                    .font(TypeScale.caption())
                    .textCase(nil)
                    .foregroundStyle(Palette.textMuted)
                DatePicker("", selection: $purchasedOn, displayedComponents: .date)
                    .datePickerStyle(.compact)
                    .labelsHidden()
                    .tint(Palette.gold)
            }

            // Quiet on purpose. It reports a comparison with YOUR OWN record
            // and stops -- it never tells anybody not to buy a bottle they are
            // holding, and there is no wording where the app calls a price
            // "overpriced" in its own voice.
            if let cents = typedPriceCents, priceHistory != nil {
                PriceVerdictLine(askingCents: cents, history: priceHistory)
            }
            if chosen?.isBarrelProof == true {
                Text("Barrel proof changes every batch — read the proof off the label.")
                    .font(TypeScale.caption())
                    .textCase(nil)
                    .foregroundStyle(Palette.gold)
            }

            alreadyOpen

            VStack(alignment: .leading, spacing: Space.s) {
                Text("Chill filtration")
                    .font(TypeScale.caption())
                    .textCase(nil)
                    .foregroundStyle(Palette.textMuted)
                Picker("Chill filtration", selection: $chillFiltered) {
                    ForEach(ChillFiltration.allCases) { option in
                        Text(option.rawValue).tag(option)
                    }
                }
                .pickerStyle(.segmented)
            }
        }
    }

    /// Most bottles somebody adds are not new.
    ///
    /// An app that can only start a bottle full is wrong about most of a real
    /// shelf on the day it is filled in, and wrong in the direction that makes
    /// the oxidation estimate and the cost-per-pour figure quietly useless.
    /// Somebody with two hundred bottles is not going to log the pours they
    /// already took -- *"I have 200+ bottles, and zero interest in manually
    /// adding each one"* -- so the only way to be right about that shelf is to
    /// let them say roughly where each bottle stands.
    ///
    /// Defaulted OFF. Fill tracking is contested in the research and the
    /// verdict is explicit: ship it, make it optional, do not make it a
    /// required step.
    private var alreadyOpen: some View {
        VStack(alignment: .leading, spacing: Space.m) {
            Toggle(isOn: $isAlreadyOpen) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Already opened")
                        .font(TypeScale.body())
                        .foregroundStyle(Palette.text)
                    Text("Say when, and roughly how much is left")
                        .font(TypeScale.caption())
                        .textCase(nil)
                        .foregroundStyle(Palette.textMuted)
                }
            }
            .tint(Palette.gold)
            .padding(Space.l)
            .background(RoundedRectangle(cornerRadius: 12).fill(Palette.surface))
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(Palette.line, lineWidth: 1))

            if isAlreadyOpen {
                DatePicker("Opened on", selection: $openedOn, displayedComponents: .date)
                    .datePickerStyle(.compact)
                    .tint(Palette.gold)
                    .font(TypeScale.secondary())
                    .foregroundStyle(Palette.textSecondary)

                VStack(alignment: .leading, spacing: Space.s) {
                    HStack {
                        Text("About \(Int(shownFillPercent))% left")
                            .font(TypeScale.body())
                            .foregroundStyle(Palette.text)
                        Spacer()
                        Text("\(Int(remainingMilliliters.rounded())) ml")
                            .font(TypeScale.code(13))
                            .foregroundStyle(Palette.textMuted)
                    }
                    Slider(value: $fillPercent, in: 0...100, step: 1)
                        .tint(Palette.gold)
                }

                Text("A rough answer is worth far more than none: it is what makes "
                     + "the fill bar and the days-open estimate mean anything. You "
                     + "can correct it any time.")
                    .font(TypeScale.caption())
                    .textCase(nil)
                    .foregroundStyle(Palette.textMuted)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    /// The percentage AS SHOWN, and the only one anything derives from.
    ///
    /// A SwiftUI slider with `step: 1` does not always land on an exact
    /// integer, so displaying `Int(percent.rounded())` while computing
    /// millilitres from the raw value gives "50%" beside "374 ml" on a 750 ml
    /// bottle. Two derivations of one number that can disagree is the failure
    /// this codebase already has a rule against: the count and the millilitres
    /// have to travel together, or the rounding carries weight on its own.
    private var shownFillPercent: Double { fillPercent.rounded() }

    private var remainingMilliliters: Double {
        PourMath.milliliters(
            percentFull: shownFillPercent, capacity: Double(volumeMl) ?? 750)
    }

    // MARK: - Where you keep it

    /// People report this mattering more than remembering what they own:
    /// *"I learned it is MORE important to remember WHERE I put the stuff."*
    /// It is also what makes a shelf walk finishable, because the walk is
    /// ordered by location.
    private var whereYouKeepIt: some View {
        VStack(alignment: .leading, spacing: Space.m) {
            SectionLabel("Where you keep it")
            HStack(spacing: Space.m) {
                field("Location", text: $storageLocation, placeholder: "Hall closet")
                field("Your number", text: $shelfNumber, keyboard: .numberPad, placeholder: "12")
            }
            Text("Your number is the sticker on the glass, not the “47 of 240” "
                 + "printed on a pick. It is what connects a shelf to this list.")
                .font(TypeScale.caption())
                .textCase(nil)
                .foregroundStyle(Palette.textMuted)
                .fixedSize(horizontal: false, vertical: true)
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
                field("Selected by", text: $pickGroup, placeholder: "Bourbon club")

                // Warehouse, rick and floor are three separate things and a
                // Blanton's label prints all three. Merging them into one box
                // is what stops an app answering "anything else from rick 41?"
                HStack(spacing: Space.m) {
                    field("Warehouse", text: $warehouse, placeholder: "H")
                    field("Rick", text: $rick, placeholder: "41")
                    field("Floor", text: $floor, placeholder: "5")
                }
                HStack(spacing: Space.m) {
                    field("Recipe code", text: $recipeCode, placeholder: "OESQ")
                    field("Entry proof", text: $entryProof, keyboard: .decimalPad, placeholder: "125")
                }

                // Often the only date on a single-barrel label, and more precise
                // than a bottling year.
                Toggle(isOn: $hasDumpDate) {
                    Text("Dump date on the label")
                        .font(TypeScale.body())
                        .foregroundStyle(Palette.text)
                }
                .tint(Palette.gold)
                .frame(minHeight: Space.tapTarget)

                if hasDumpDate {
                    DatePicker(
                        "Dumped", selection: $dumpedAt, displayedComponents: .date)
                        .datePickerStyle(.compact)
                        .tint(Palette.gold)
                        .foregroundStyle(Palette.textSecondary)
                        .font(TypeScale.secondary())
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

    /// Fills the form from a scan. **Only fields the label actually carried**,
    /// so a second scan cannot blank something already typed, and a field the
    /// reader is unsure about is left alone rather than overwritten with a
    /// guess.
    private func apply(_ reading: LabelReader.Reading, _ product: CatalogProduct?) {
        if let product {
            choose(product)
        } else if !reading.nameCandidate.isEmpty, chosen == nil {
            // No catalogue match: fall into the type-it-in path with the name
            // already there, rather than leaving somebody at an empty form
            // holding a bottle the catalogue has never heard of.
            isTypingItIn = true
            if customBrand.isEmpty {
                customBrand = reading.nameCandidate.capitalized
            }
        }

        // The proof, not the ABV. It is what the label prints and what the
        // rest of the form expects.
        if let proof = reading.proof { self.proof = String(format: "%.1f", proof) }
        if let size = reading.volumeMilliliters { volumeMl = String(Int(size)) }
        if let batch = reading.batchCode { batchNumber = batch }
        if let barrel = reading.barrelNumber { barrelNumber = barrel }
        if let code = reading.recipeCode { recipeCode = code }
        if let age = reading.statedAgeYears { ageYears = String(age) }

        // A label saying "single barrel" or naming a barrel is a store pick or
        // a single barrel, so the section holding those fields opens itself.
        if reading.isSingleBarrel || reading.barrelNumber != nil {
            isStorePick = true
        }
    }

    private var typedPriceCents: Int? {
        guard let value = Double(price), value > 0 else { return nil }
        return Int((value * 100).rounded())
    }

    private func choose(_ product: CatalogProduct) {
        chosen = product
        if let abv = product.abv { proof = String(format: "%.1f", ABV(percent: abv).proof) }
        priceHistory = PriceHistory.summarise(
            (try? env.bottles.purchaseHistory(catalogProductId: product.id)) ?? [])
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
            rick: rick.isEmpty ? nil : rick,
            floor: floor.isEmpty ? nil : floor,
            recipeCode: recipeCode.isEmpty ? nil : recipeCode.uppercased(),
            ageMonths: months > 0 ? months : nil,
            entryProof: Double(entryProof),
            charLevel: Int(charLevel),
            finish: finish.isEmpty ? nil : finish,
            bottleNumber: Int(bottleNumber),
            bottlesInBatch: Int(bottlesInBatch),
            dumpedAt: hasDumpDate ? Int64(dumpedAt.timeIntervalSince1970 * 1000) : nil,
            abv: Double(proof).map { $0 / 2 },
            chillFiltered: chillFiltered.value,
            volumeMl: Double(volumeMl) ?? 750,
            purchaseDate: Int64(purchasedOn.timeIntervalSince1970 * 1000),
            purchasePriceCents: price.isEmpty ? nil : Int((Double(price) ?? 0) * 100),
            purchaseStore: store.isEmpty ? nil : store,
            shelfPriceCents: Double(shelfPrice).map { Int(($0 * 100).rounded()) },
            storageLocation: storageLocation.isEmpty ? nil : storageLocation,
            shelfNumber: Int(shelfNumber),
            openedAt: isAlreadyOpen ? Int64(openedOn.timeIntervalSince1970 * 1000) : nil)

        do {
            if chosen != nil {
                try env.bottles.add(bottle)
                try recordOpeningLevel(bottle)
            } else {
                let product = CustomCatalogEntry(
                    distillery: customDistillery.isEmpty ? customBrand : customDistillery,
                    brand: customBrand,
                    expression: customExpression,
                    classType: customClass)
                bottle.customName = customName
                let saved = try env.bottles.addCustom(product: product, bottle: bottle)
                try recordOpeningLevel(saved.bottle)
            }
            dismiss()
        } catch {
            self.error = error.localizedDescription
        }
    }

    /// A full bottle needs no reading -- that is what the app assumes anyway,
    /// and an unnecessary row is one more thing to sync.
    private func recordOpeningLevel(_ bottle: Bottle) throws {
        guard isAlreadyOpen, shownFillPercent < 100 else { return }
        try env.bottles.setLevel(
            bottleId: bottle.id,
            remainingMl: remainingMilliliters,
            note: "Set when the bottle was added",
            at: Int64(openedOn.timeIntervalSince1970 * 1000))
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
