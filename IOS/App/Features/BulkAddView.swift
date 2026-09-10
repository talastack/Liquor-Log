import SwiftUI
import LiquorData
import LiquorEngine

/// Add a shelf, one scan after another, without leaving the screen.
///
/// The research ranks this first: *"Bulk onboarding. Point the camera down a
/// shelf, confirm a list. This is the #1 adoption barrier and solving it is
/// worth more than any feature."* And the quote behind it: *"So I have 200+
/// bottles, and zero interest in manually adding each one."*
///
/// Without a vision model there is no "one photo of a shelf" — that is the
/// case a model would earn its keep on, and it was decided against. What this
/// does instead is remove everything BETWEEN scans: no form, no navigation
/// back, no tapping Add and starting over. Scan, glance, confirm, the camera is
/// already open again. Twenty bottles in a few minutes rather than an evening.
///
/// **Every bottle lands sealed, full and bought today, with only what the
/// label said.** Details go on later, from the bottle screen. Asking for
/// storage location and price on bottle eleven of forty is how a bulk add
/// becomes the form it was meant to replace.
struct BulkAddView: View {
    @Environment(AppEnvironment.self) private var env
    @Environment(\.dismiss) private var dismiss

    @State private var isScanning = false
    @State private var added: [Added] = []
    @State private var skipped = 0
    @State private var error: String?

    struct Added: Identifiable {
        let id: String
        let name: String
        let detail: String?
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Space.xl) {
                header
                scanButton
                if !added.isEmpty { list }
                guidance
            }
            .padding(.horizontal, Space.xl)
            .padding(.top, Space.l)
            .padding(.bottom, 96)
        }
        .background(Palette.background)
        .navigationTitle("Add a shelf")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("Done") { dismiss() }.foregroundStyle(Palette.gold)
            }
        }
        .sheet(isPresented: $isScanning) {
            NavigationStack {
                ScanLabelView { reading, product, barcode in
                    add(reading, product, barcode)
                }
            }
        }
        .alert("Could not save", isPresented: .constant(error != nil)) {
            Button("OK") { error = nil }
        } message: { Text(error ?? "") }
    }

    // MARK: - Sections

    private var header: some View {
        VStack(alignment: .leading, spacing: Space.s) {
            HStack(alignment: .firstTextBaseline) {
                Text("\(added.count)")
                    .font(TypeScale.largeTitle())
                    .foregroundStyle(Palette.gold)
                Text(added.count == 1 ? "bottle added" : "bottles added")
                    .font(TypeScale.secondary())
                    .foregroundStyle(Palette.textMuted)
                Spacer()
            }
            if skipped > 0 {
                Text("\(skipped) skipped")
                    .font(TypeScale.caption())
                    .textCase(nil)
                    .foregroundStyle(Palette.textMuted)
            }
        }
    }

    private var scanButton: some View {
        Button { isScanning = true } label: {
            HStack(spacing: Space.s) {
                Image(systemName: "camera")
                Text(added.isEmpty ? "Scan the first bottle" : "Scan the next one")
            }
            .font(TypeScale.headline())
            .foregroundStyle(Palette.onGold)
            .frame(maxWidth: .infinity, minHeight: 56)
            .background(RoundedRectangle(cornerRadius: 11).fill(Palette.gold))
        }
    }

    /// Newest at the top, so the one just added is under the button.
    private var list: some View {
        VStack(alignment: .leading, spacing: Space.s) {
            SectionLabel("This session")
            ForEach(added.reversed()) { item in
                HStack(spacing: Space.m) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(Palette.good)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(item.name)
                            .font(TypeScale.body())
                            .foregroundStyle(Palette.text)
                        if let detail = item.detail {
                            Text(detail)
                                .font(TypeScale.caption())
                                .textCase(nil)
                                .foregroundStyle(Palette.textMuted)
                        }
                    }
                    Spacer()
                }
                .padding(.vertical, Space.xs)
            }
        }
    }

    private var guidance: some View {
        Text("Each bottle is saved as sealed and full, with whatever the label "
             + "said. Open the bottle later to set the level, the price and where "
             + "you keep it — asking for all that on bottle eleven of forty is how "
             + "a bulk add turns back into a form.")
            .font(TypeScale.caption())
            .textCase(nil)
            .foregroundStyle(Palette.textMuted)
            .fixedSize(horizontal: false, vertical: true)
    }

    // MARK: - Adding

    /// One bottle from one scan, then the camera again.
    ///
    /// A scan with no name and no match is skipped rather than saved as
    /// "Untitled bottle": a collection full of untitled rows is worse than a
    /// shorter one, and the count of skips is shown so nothing vanishes
    /// silently.
    private func add(_ reading: LabelReader.Reading, _ product: CatalogProduct?, _ barcode: String?) {
        let name = product?.identity.displayName
            ?? (reading.nameCandidate.isEmpty ? nil : reading.nameCandidate.capitalized)
        guard let name else {
            skipped += 1
            reopen()
            return
        }

        var bottle = Bottle(
            catalogProductId: product?.id,
            customName: product == nil ? name : nil,
            isStorePick: reading.isSingleBarrel || reading.barrelNumber != nil,
            barrelNumber: reading.barrelNumber,
            batchNumber: reading.batchCode,
            recipeCode: reading.recipeCode,
            ageMonths: reading.statedAgeYears.map { $0 * 12 },
            abv: reading.abv,
            volumeMl: reading.volumeMilliliters ?? 750,
            purchaseDate: Bottle.nowMilliseconds(),
            barcode: barcode)

        do {
            if product != nil {
                try env.bottles.add(bottle)
            } else {
                // No catalogue match: the name becomes a private product so
                // the shelf check can still answer for it, exactly as the
                // single-bottle form does.
                let custom = CustomCatalogEntry(
                    distillery: name, brand: name, classType: .bourbon)
                bottle.customName = name
                try env.bottles.addCustom(product: custom, bottle: bottle)
            }
            added.append(Added(id: bottle.id, name: name, detail: reading.batchCode
                ?? reading.barrelNumber
                ?? reading.proof.map { String(format: "%.1f proof", $0) }))
            reopen()
        } catch {
            self.error = error.localizedDescription
        }
    }

    /// The camera comes straight back. Dismissing the sheet and re-presenting
    /// it on the next run of the loop is what makes this a loop rather than a
    /// form with a camera button.
    private func reopen() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
            isScanning = true
        }
    }
}

#Preview {
    NavigationStack { BulkAddView() }
        .environment(AppEnvironment.preview())
        .preferredColorScheme(.dark)
}
