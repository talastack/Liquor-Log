import SwiftUI
import UniformTypeIdentifiers
import LiquorData
import LiquorEngine

/// Bring a spreadsheet in.
///
/// The research calls spreadsheets *"the actual market leader"*, and the
/// people this app most wants are the ones with two hundred rows already
/// typed into one. This is how they arrive without retyping — and it is free,
/// because charging at the moment somebody hands you their whole collection is
/// charging at the exact point you most want them to succeed.
///
/// **Nothing lands until the plan is shown.** The screen says which column it
/// read as the name, lists what it would create, and names the lines it would
/// skip. An import that silently produced forty untitled bottles from a
/// misaligned column would be worse than no import.
struct ImportView: View {
    @Environment(AppEnvironment.self) private var env
    @Environment(\.dismiss) private var dismiss

    @State private var isPicking = false
    @State private var plan: CollectionImport.Plan?
    @State private var fileName = ""
    @State private var outcome: CollectionImporter.Outcome?
    @State private var error: String?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Space.xl) {
                if let outcome {
                    done(outcome)
                } else if let plan {
                    preview(plan)
                } else {
                    intro
                }

                if let error {
                    Text(error)
                        .font(TypeScale.secondary())
                        .foregroundStyle(Palette.bad)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .padding(.horizontal, Space.xl)
            .padding(.top, Space.l)
            .padding(.bottom, 96)
        }
        .background(Palette.background)
        .navigationTitle("Import a spreadsheet")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button(outcome == nil ? "Cancel" : "Done") { dismiss() }
                    .foregroundStyle(Palette.textSecondary)
            }
        }
        .fileImporter(
            isPresented: $isPicking,
            allowedContentTypes: [.commaSeparatedText, .plainText, .text],
            allowsMultipleSelection: false
        ) { result in
            load(result)
        }
    }

    // MARK: - Steps

    private var intro: some View {
        VStack(alignment: .leading, spacing: Space.m) {
            Text("Already have a spreadsheet?")
                .font(TypeScale.largeTitle())
                .foregroundStyle(Palette.text)

            Text("Export it as CSV and choose it here. Columns are recognised by "
                 + "name — Bottle, Whiskey or Name; Proof or ABV; Price, Paid or "
                 + "Cost — so nothing needs renaming first. The app's own export "
                 + "comes back in whole.")
                .font(TypeScale.secondary())
                .foregroundStyle(Palette.textSecondary)
                .fixedSize(horizontal: false, vertical: true)

            Button { isPicking = true } label: {
                Text("Choose a CSV file")
                    .font(TypeScale.headline())
                    .foregroundStyle(Palette.onGold)
                    .frame(maxWidth: .infinity, minHeight: 50)
                    .background(RoundedRectangle(cornerRadius: 11).fill(Palette.gold))
            }

            Text("You will see exactly what it found before anything is added.")
                .font(TypeScale.caption())
                .textCase(nil)
                .foregroundStyle(Palette.textMuted)
        }
    }

    private func preview(_ plan: CollectionImport.Plan) -> some View {
        VStack(alignment: .leading, spacing: Space.xl) {
            VStack(alignment: .leading, spacing: Space.s) {
                Text(fileName)
                    .font(TypeScale.code(13))
                    .foregroundStyle(Palette.textMuted)
                HStack(alignment: .firstTextBaseline) {
                    Text("\(plan.rows.count)")
                        .font(TypeScale.largeTitle())
                        .foregroundStyle(Palette.gold)
                    Text(plan.rows.count == 1 ? "bottle found" : "bottles found")
                        .font(TypeScale.secondary())
                        .foregroundStyle(Palette.textMuted)
                }
            }

            // Which column became what. This is the line somebody reads to
            // catch "it thinks my Notes column is the name" before it lands.
            VStack(alignment: .leading, spacing: 0) {
                SectionLabel("How it read the columns")
                    .padding(.bottom, Space.xs)
                let known = CollectionImport.Field.allCases.filter { plan.mapping[$0] != nil }
                ForEach(Array(known.enumerated()), id: \.element) { index, field in
                    FactRow(
                        label: label(field),
                        value: "\u{201C}\(plan.mapping[field] ?? "")\u{201D}",
                        isLast: index == known.count - 1)
                }
            }

            if plan.isEmpty {
                Text("No column looked like a bottle name, so nothing would be "
                     + "imported. Add a column called Name, Bottle or Whiskey and "
                     + "try again.")
                    .font(TypeScale.secondary())
                    .foregroundStyle(Palette.bad)
                    .fixedSize(horizontal: false, vertical: true)
            } else {
                VStack(alignment: .leading, spacing: Space.s) {
                    SectionLabel("First few")
                    ForEach(plan.rows.prefix(8), id: \.line) { row in
                        HStack(alignment: .firstTextBaseline) {
                            Text(row.name)
                                .font(TypeScale.body())
                                .foregroundStyle(Palette.text)
                            Spacer(minLength: Space.s)
                            if let proof = row.proof {
                                Text(String(format: "%.1f", proof))
                                    .font(TypeScale.code(13))
                                    .foregroundStyle(Palette.textMuted)
                            }
                        }
                    }
                    if plan.rows.count > 8 {
                        Text("and \(plan.rows.count - 8) more")
                            .font(TypeScale.caption())
                            .textCase(nil)
                            .foregroundStyle(Palette.textMuted)
                    }
                }

                if !plan.skippedLines.isEmpty {
                    Text("Skipping \(plan.skippedLines.count) "
                         + (plan.skippedLines.count == 1 ? "line" : "lines")
                         + " with no name: "
                         + plan.skippedLines.prefix(10).map(String.init).joined(separator: ", ")
                         + (plan.skippedLines.count > 10 ? "…" : ""))
                        .font(TypeScale.caption())
                        .textCase(nil)
                        .foregroundStyle(Palette.gold)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Button { apply(plan) } label: {
                    Text("Import \(plan.rows.count) \(plan.rows.count == 1 ? "bottle" : "bottles")")
                        .font(TypeScale.headline())
                        .foregroundStyle(Palette.onGold)
                        .frame(maxWidth: .infinity, minHeight: 50)
                        .background(RoundedRectangle(cornerRadius: 11).fill(Palette.gold))
                }

                Text("All or nothing: either every row lands or none does, so a "
                     + "problem halfway through cannot leave you with half a "
                     + "collection and no way to tell which half.")
                    .font(TypeScale.caption())
                    .textCase(nil)
                    .foregroundStyle(Palette.textMuted)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Button { self.plan = nil } label: {
                Text("Choose a different file")
                    .font(TypeScale.secondary())
                    .foregroundStyle(Palette.gold)
                    .frame(maxWidth: .infinity, minHeight: Space.tapTarget)
            }
        }
    }

    private func done(_ outcome: CollectionImporter.Outcome) -> some View {
        VStack(alignment: .leading, spacing: Space.l) {
            Text("Imported")
                .font(TypeScale.largeTitle())
                .foregroundStyle(Palette.text)
            VStack(alignment: .leading, spacing: 0) {
                FactRow(label: "Bottles added", value: "\(outcome.imported)")
                FactRow(label: "Matched to the catalogue", value: "\(outcome.matchedToCatalog)")
                FactRow(label: "Lines skipped", value: "\(outcome.skippedLines.count)", isLast: true)
            }
            Text("Every one arrived as sealed unless the spreadsheet said "
                 + "otherwise. Open any bottle to fill in the rest.")
                .font(TypeScale.secondary())
                .foregroundStyle(Palette.textMuted)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func label(_ field: CollectionImport.Field) -> String {
        switch field {
        case .name: return "Name"
        case .proof: return "Proof"
        case .abv: return "ABV"
        case .volume: return "Size"
        case .paid: return "Paid"
        case .store: return "Bought at"
        case .batch: return "Batch"
        case .barrel: return "Barrel"
        case .location: return "Location"
        case .status: return "Status"
        case .note: return "Notes"
        }
    }

    // MARK: - Work

    private func load(_ result: Result<[URL], Error>) {
        error = nil
        do {
            guard let url = try result.get().first else { return }
            // Security-scoped: the picker grants access to this one file for
            // as long as the scope is held, and reading outside it fails
            // silently with an empty string.
            let granted = url.startAccessingSecurityScopedResource()
            defer { if granted { url.stopAccessingSecurityScopedResource() } }

            let text = try String(contentsOf: url, encoding: .utf8)
            fileName = url.lastPathComponent
            plan = CollectionImport.plan(csv: text)
        } catch {
            self.error = "Could not read that file. It needs to be a CSV."
        }
    }

    private func apply(_ plan: CollectionImport.Plan) {
        do {
            outcome = try CollectionImporter(env.database).apply(plan) { name in
                exactMatch(name)
            }
        } catch {
            self.error = error.localizedDescription
        }
    }

    /// Only a CONFIDENT match. A spreadsheet row attached to the wrong product
    /// makes the shelf check answer for a whiskey the person does not own,
    /// which is worse than leaving it as a custom bottle.
    private func exactMatch(_ name: String) -> String? {
        let candidates = env.catalog.searchCandidates(history: [])
        let hits = BottleSearch.search(query: name, in: candidates, limit: 1)
        guard let hit = hits.first, hit.reason == .exact else { return nil }
        return hit.product.productId
    }
}

#Preview {
    NavigationStack { ImportView() }
        .environment(AppEnvironment.preview())
        .preferredColorScheme(.dark)
}
