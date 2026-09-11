import SwiftUI
import LiquorData
import LiquorEngine

/// What you know about a product, as one note kept current.
///
/// Not a tasting. A tasting is a night; this is the accumulated fact -- which
/// batches to avoid, which store has it at list, whether the pick beats the
/// standard. It shows on the bottle and on the shelf-check card, which is
/// where a note like "not worth it over $60" earns its keep.
struct ProductNoteView: View {
    @Environment(AppEnvironment.self) private var env
    @Environment(\.dismiss) private var dismiss

    let productId: String
    let productName: String
    var onSave: (() -> Void)?

    @State private var body_ = ""
    @State private var error: String?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Space.xl) {
                VStack(alignment: .leading, spacing: Space.xs) {
                    SectionLabel("About")
                    Text(productName)
                        .font(TypeScale.largeTitle())
                        .foregroundStyle(Palette.text)
                        .fixedSize(horizontal: false, vertical: true)
                }

                VStack(alignment: .leading, spacing: Space.s) {
                    TextEditor(text: $body_)
                        .font(TypeScale.body())
                        .foregroundStyle(Palette.text)
                        .scrollContentBackground(.hidden)
                        .frame(minHeight: 180)
                        .padding(Space.m)
                        .background(RoundedRectangle(cornerRadius: 12).fill(Palette.surface))
                        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Palette.line, lineWidth: 1))

                    Text("Things you have learned about this whiskey, not about one "
                         + "glass of it. Batches to avoid, where it is at list price, "
                         + "whether the pick is worth it. Leave it empty to remove the note.")
                        .font(TypeScale.caption())
                        .textCase(nil)
                        .foregroundStyle(Palette.textMuted)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Button(action: save) {
                    Text("Save")
                        .font(TypeScale.headline())
                        .foregroundStyle(Palette.onGold)
                        .frame(maxWidth: .infinity, minHeight: 50)
                        .background(RoundedRectangle(cornerRadius: 11).fill(Palette.gold))
                }
            }
            .padding(.horizontal, Space.xl)
            .padding(.top, Space.l)
            .padding(.bottom, 96)
        }
        .background(Palette.background)
        .navigationTitle("Your note")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") { dismiss() }.foregroundStyle(Palette.textSecondary)
            }
        }
        .task { body_ = (try? env.notes.note(productId: productId))?.body ?? "" }
        .alert("Could not save", isPresented: .constant(error != nil)) {
            Button("OK") { error = nil }
        } message: { Text(error ?? "") }
    }

    private func save() {
        do {
            try env.notes.set(productId: productId, title: productName, body: body_)
            onSave?()
            dismiss()
        } catch {
            self.error = error.localizedDescription
        }
    }
}

/// The note as it appears on a bottle or a card: the body, and a way in.
struct ProductNoteCard: View {
    let body_: String?
    let onEdit: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: Space.s) {
            HStack {
                SectionLabel("What you know about this")
                Spacer()
                Button(action: onEdit) {
                    Text(body_ == nil ? "Add a note" : "Edit")
                        .font(TypeScale.secondary())
                        .foregroundStyle(Palette.gold)
                        .frame(minHeight: Space.tapTarget)
                }
            }
            if let body_ {
                Text(body_)
                    .font(TypeScale.body())
                    .foregroundStyle(Palette.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(Space.l)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(RoundedRectangle(cornerRadius: 12).fill(Palette.surface))
                    .overlay(RoundedRectangle(cornerRadius: 12).stroke(Palette.line, lineWidth: 1))
            } else {
                Text("Batches to avoid, where it sells at list, whether the pick "
                     + "beats the standard. It shows here and on the shelf check.")
                    .font(TypeScale.caption())
                    .textCase(nil)
                    .foregroundStyle(Palette.textMuted)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}
