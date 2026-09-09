import SwiftUI
import UIKit
import LiquorData
import LiquorEngine

/// Photograph a label, check what it read, then fill the form.
///
/// **Everything here is a suggestion, and nothing is saved from this screen.**
/// It hands its reading back to Add a bottle, where every field is still
/// editable. A misread proof written silently would poison cost-per-pour, the
/// perceived-proof verdict and the shelf check at once — and unlike a typo,
/// nobody would ever know they had made it.
///
/// The research's warning is worth keeping in view while using this: a
/// developer built label recognition and *removed it before launch* because
/// *"the photo recognition flow felt slower and didn't really add much benefit
/// compared to just adding bottles manually."* If confirming a scan is not
/// genuinely faster than typing, it should go.
struct ScanLabelView: View {
    @Environment(AppEnvironment.self) private var env
    @Environment(\.dismiss) private var dismiss

    /// Called with what was read and whichever catalogue row was chosen, if any.
    let onUse: (LabelReader.Reading, CatalogProduct?) -> Void

    @State private var image: UIImage?
    @State private var reading: LabelReader.Reading?
    @State private var lines: [String] = []
    @State private var chosen: CatalogProduct?
    @State private var isPicking = false
    @State private var source: UIImagePickerController.SourceType = .camera
    @State private var isReading = false
    @State private var error: String?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Space.xl) {
                if let image {
                    preview(image)
                }

                if isReading {
                    ProgressView("Reading the label")
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, Space.xl)
                } else if let reading {
                    found(reading)
                    matches(reading)
                    useButton(reading)
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
        .navigationTitle("Scan a label")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") { dismiss() }.foregroundStyle(Palette.textSecondary)
            }
        }
        .sheet(isPresented: $isPicking) {
            ImagePicker(source: source) { picked in
                image = picked
                Task { await read(picked) }
            }
            .ignoresSafeArea()
        }
    }

    // MARK: - Sections

    private var intro: some View {
        VStack(alignment: .leading, spacing: Space.m) {
            Text("Point it at the front label")
                .font(TypeScale.title())
                .foregroundStyle(Palette.text)

            Text("It reads the proof, batch and barrel numbers, recipe codes and "
                 + "age off the label, then looks for a match. Everything it "
                 + "finds is a suggestion you can change.")
                .font(TypeScale.secondary())
                .foregroundStyle(Palette.textSecondary)
                .fixedSize(horizontal: false, vertical: true)

            // The camera is absent in the simulator, and offering it there
            // presents a black screen with no explanation.
            if ImagePicker.cameraAvailable {
                Button {
                    source = .camera
                    isPicking = true
                } label: {
                    Text("Take a photo")
                        .font(TypeScale.headline())
                        .foregroundStyle(Palette.onGold)
                        .frame(maxWidth: .infinity, minHeight: 50)
                        .background(RoundedRectangle(cornerRadius: 11).fill(Palette.gold))
                }
            }

            Button {
                source = .photoLibrary
                isPicking = true
            } label: {
                Text("Choose a photo")
                    .font(TypeScale.headline())
                    .foregroundStyle(Palette.text)
                    .frame(maxWidth: .infinity, minHeight: 50)
                    .overlay(RoundedRectangle(cornerRadius: 11)
                        .stroke(Palette.line, lineWidth: 1))
            }

            Text("Runs entirely on this phone. Nothing is uploaded and it works "
                 + "with no signal.")
                .font(TypeScale.caption())
                .textCase(nil)
                .foregroundStyle(Palette.textMuted)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func preview(_ image: UIImage) -> some View {
        Image(uiImage: image)
            .resizable()
            .scaledToFit()
            .frame(maxHeight: 220)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(Palette.line, lineWidth: 1))
    }

    /// What it read, as facts rather than a paragraph, so a wrong one is
    /// obvious at a glance.
    private func found(_ reading: LabelReader.Reading) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            SectionLabel("What it read")
                .padding(.bottom, Space.xs)

            if reading.isEmpty {
                Text("Nothing recognisable. Try filling the frame with the label.")
                    .font(TypeScale.secondary())
                    .foregroundStyle(Palette.textMuted)
                    .fixedSize(horizontal: false, vertical: true)
            } else {
                if let proof = reading.proof {
                    FactRow(label: "Proof", value: String(format: "%.1f", proof))
                }
                if let batch = reading.batchCode {
                    FactRow(label: "Batch", value: batch)
                }
                if let barrel = reading.barrelNumber {
                    FactRow(label: "Barrel", value: barrel)
                }
                if let code = reading.recipeCode {
                    FactRow(label: "Recipe", value: code)
                }
                if let age = reading.statedAgeYears {
                    FactRow(label: "Age", value: "\(age) years")
                }
                if let size = reading.volumeMilliliters {
                    FactRow(label: "Size", value: "\(Int(size)) ml")
                }
                if reading.isBottledInBond {
                    FactRow(label: "Claim", value: "Bottled in bond")
                }
                if reading.isSingleBarrel {
                    FactRow(label: "Claim", value: "Single barrel")
                }
                FactRow(
                    label: "Lines read",
                    value: "\(lines.count)",
                    isLast: true)
            }
        }
    }

    /// Catalogue rows it might be. Never chosen automatically: a wrong match
    /// attaches somebody's tasting notes to the wrong whiskey.
    private func matches(_ reading: LabelReader.Reading) -> some View {
        let hits = LabelReader.candidates(for: reading, in: candidates)
        return VStack(alignment: .leading, spacing: Space.s) {
            SectionLabel("Might be")

            if hits.isEmpty {
                Text("No match in the catalogue. You can still use what it read "
                     + "and type the name yourself.")
                    .font(TypeScale.secondary())
                    .foregroundStyle(Palette.textMuted)
                    .fixedSize(horizontal: false, vertical: true)
            } else {
                ForEach(hits, id: \.product.productId) { hit in
                    let product = env.catalog.product(hit.product.productId)
                    Button {
                        chosen = (chosen?.id == product?.id) ? nil : product
                    } label: {
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(hit.product.displayName)
                                    .font(TypeScale.body())
                                    .foregroundStyle(Palette.text)
                                    .multilineTextAlignment(.leading)
                                Text(hit.product.distillery)
                                    .font(TypeScale.caption())
                                    .textCase(nil)
                                    .foregroundStyle(Palette.textMuted)
                            }
                            Spacer(minLength: Space.s)
                            if chosen?.id == product?.id {
                                Image(systemName: "checkmark")
                                    .foregroundStyle(Palette.gold)
                            }
                        }
                        .padding(Space.m)
                        .frame(maxWidth: .infinity, minHeight: Space.tapTarget,
                               alignment: .leading)
                        .background(RoundedRectangle(cornerRadius: 10)
                            .fill(Palette.surface))
                        .overlay(RoundedRectangle(cornerRadius: 10)
                            .stroke(chosen?.id == product?.id ? Palette.gold : Palette.line,
                                    lineWidth: 1))
                    }
                }
            }
        }
    }

    private func useButton(_ reading: LabelReader.Reading) -> some View {
        VStack(spacing: Space.m) {
            Button {
                onUse(reading, chosen)
                dismiss()
            } label: {
                Text("Use this")
                    .font(TypeScale.headline())
                    .foregroundStyle(Palette.onGold)
                    .frame(maxWidth: .infinity, minHeight: 50)
                    .background(RoundedRectangle(cornerRadius: 11).fill(Palette.gold))
            }

            Button {
                image = nil
                self.reading = nil
                chosen = nil
                lines = []
            } label: {
                Text("Try another photo")
                    .font(TypeScale.secondary())
                    .foregroundStyle(Palette.gold)
                    .frame(maxWidth: .infinity, minHeight: Space.tapTarget)
            }

            Text("Nothing is saved yet. Every field stays editable on the next "
                 + "screen.")
                .font(TypeScale.caption())
                .textCase(nil)
                .foregroundStyle(Palette.textMuted)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    // MARK: - Work

    private var candidates: [SearchCandidate] {
        env.catalog.searchCandidates(history: env.historyProductIds())
    }

    private func read(_ image: UIImage) async {
        isReading = true
        error = nil
        defer { isReading = false }
        do {
            let found = try await LabelScanner.recognise(image)
            lines = found
            reading = LabelReader.read(found)
        } catch {
            self.error = error.localizedDescription
            reading = nil
        }
    }
}
