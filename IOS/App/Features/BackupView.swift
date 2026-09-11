import SwiftUI
import UniformTypeIdentifiers
import LiquorData
import LiquorEngine

/// Everything out as one file, and everything back from one.
///
/// The CSV export is the trust signal; this is the actual insurance. A
/// spreadsheet cannot carry pours, fill readings, the wheel picks on a
/// tasting or the photos, and this does. Restore merges by the same
/// newer-wins rule sync uses, so it is safe to run onto a phone that already
/// has bottles and safe to run twice.
struct BackupView: View {
    @Environment(AppEnvironment.self) private var env

    @State private var backupURL: URL?
    @State private var backupCounts: CollectionBackup.Counts?
    @State private var isPicking = false
    @State private var pendingData: Data?
    @State private var preview: CollectionBackup.Preview?
    @State private var outcome: CollectionBackup.Outcome?
    @State private var error: String?

    private var backup: CollectionBackup {
        CollectionBackup(env.database, photos: env.photos)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Space.xl) {
                backUp
                restore
            }
            .padding(.horizontal, Space.xl)
            .padding(.top, Space.l)
            .padding(.bottom, 96)
        }
        .background(Palette.background)
        .navigationTitle("Back up and restore")
        .navigationBarTitleDisplayMode(.inline)
        .fileImporter(
            isPresented: $isPicking,
            allowedContentTypes: [.json, .data],
            allowsMultipleSelection: false
        ) { result in
            switch result {
            case .success(let urls):
                if let url = urls.first { read(url) }
            case .failure(let failure):
                error = failure.localizedDescription
            }
        }
        .alert("Something went wrong", isPresented: .constant(error != nil)) {
            Button("OK") { error = nil }
        } message: { Text(error ?? "") }
    }

    // MARK: - Back up

    private var backUp: some View {
        VStack(alignment: .leading, spacing: Space.m) {
            SectionLabel("Back up")
            Text("One file with every bottle, pour, fill reading, tasting, wheel pick, "
                 + "wishlist row, note and photo. Save it to Files or iCloud Drive, or "
                 + "send it anywhere.")
                .font(TypeScale.secondary())
                .foregroundStyle(Palette.textSecondary)
                .fixedSize(horizontal: false, vertical: true)

            if let backupURL, let backupCounts {
                VStack(alignment: .leading, spacing: 0) {
                    FactRow(label: "Rows", value: "\(backupCounts.total)")
                    FactRow(label: "Photos", value: "\(backupCounts.photos)", isLast: true)
                }
                ShareLink(item: backupURL) {
                    HStack(spacing: Space.s) {
                        Image(systemName: "square.and.arrow.up")
                        Text("Save the backup")
                    }
                    .font(TypeScale.headline())
                    .foregroundStyle(Palette.onGold)
                    .frame(maxWidth: .infinity, minHeight: 50)
                    .background(RoundedRectangle(cornerRadius: 11).fill(Palette.gold))
                }
            } else {
                Button(action: writeBackup) {
                    Text("Build a backup")
                        .font(TypeScale.headline())
                        .foregroundStyle(Palette.onGold)
                        .frame(maxWidth: .infinity, minHeight: 50)
                        .background(RoundedRectangle(cornerRadius: 11).fill(Palette.gold))
                }
            }
        }
    }

    // MARK: - Restore

    private var restore: some View {
        VStack(alignment: .leading, spacing: Space.m) {
            SectionLabel("Restore")
            Text("Pick a backup file. Nothing is written until you confirm. Rows you "
                 + "already have are kept unless the backup's copy is newer, so "
                 + "restoring onto a phone with bottles on it is safe, and so is "
                 + "restoring twice.")
                .font(TypeScale.secondary())
                .foregroundStyle(Palette.textSecondary)
                .fixedSize(horizontal: false, vertical: true)

            if let outcome {
                VStack(alignment: .leading, spacing: 0) {
                    FactRow(label: "Added", value: "\(outcome.inserted)")
                    FactRow(label: "Updated", value: "\(outcome.updated)")
                    FactRow(label: "Already had", value: "\(outcome.unchanged)")
                    FactRow(label: "Photos written", value: "\(outcome.photosWritten)", isLast: true)
                }
                Text("Done. Your collection now includes everything in that file.")
                    .font(TypeScale.secondary())
                    .foregroundStyle(Palette.good)
            } else if let preview {
                VStack(alignment: .leading, spacing: 0) {
                    if let at = preview.exportedAt {
                        FactRow(label: "Backed up", value: at.formatted(date: .abbreviated, time: .shortened))
                    }
                    FactRow(label: "Bottles", value: "\(preview.counts.rows["bottles"] ?? 0)")
                    FactRow(label: "Pours", value: "\(preview.counts.rows["pours"] ?? 0)")
                    FactRow(label: "Tastings", value: "\(preview.counts.rows["tastings"] ?? 0)")
                    FactRow(label: "Photos", value: "\(preview.counts.photos)", isLast: true)
                }
                Button(action: applyRestore) {
                    Text("Restore these")
                        .font(TypeScale.headline())
                        .foregroundStyle(Palette.onGold)
                        .frame(maxWidth: .infinity, minHeight: 50)
                        .background(RoundedRectangle(cornerRadius: 11).fill(Palette.gold))
                }
                Button {
                    self.preview = nil
                    pendingData = nil
                } label: {
                    Text("Choose a different file")
                        .font(TypeScale.secondary())
                        .foregroundStyle(Palette.gold)
                        .frame(maxWidth: .infinity, minHeight: Space.tapTarget)
                }
            } else {
                Button { isPicking = true } label: {
                    Text("Choose a backup file")
                        .font(TypeScale.headline())
                        .foregroundStyle(Palette.text)
                        .frame(maxWidth: .infinity, minHeight: 50)
                        .overlay(RoundedRectangle(cornerRadius: 11).stroke(Palette.line, lineWidth: 1))
                }
            }
        }
    }

    // MARK: - Actions

    private func writeBackup() {
        do {
            let stamp = Date().formatted(.iso8601.year().month().day())
            let url = FileManager.default.temporaryDirectory
                .appendingPathComponent("liquorlog-backup-\(stamp).json")
            backupCounts = try backup.write(to: url)
            backupURL = url
        } catch {
            self.error = error.localizedDescription
        }
    }

    private func read(_ url: URL) {
        let granted = url.startAccessingSecurityScopedResource()
        defer { if granted { url.stopAccessingSecurityScopedResource() } }
        do {
            let data = try Data(contentsOf: url)
            preview = try backup.preview(data)
            pendingData = data
            outcome = nil
        } catch {
            self.error = error.localizedDescription
        }
    }

    private func applyRestore() {
        guard let pendingData else { return }
        do {
            outcome = try backup.restore(pendingData)
            preview = nil
            self.pendingData = nil
        } catch {
            self.error = error.localizedDescription
        }
    }
}
