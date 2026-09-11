import SwiftUI
import PhotosUI
import LiquorData

/// Bottle photos: shrinking them, showing them, and the menu that sets one.
///
/// A photo is the "which one was it" of a collection past fifty bottles, and
/// the thing an insurance claim asks for. It is stored on this device only
/// (see `BottlePhotoStore`); nothing here uploads anything.
enum BottlePhoto {
    /// Longest side after shrinking. A shelf photo at full resolution is
    /// several megabytes; at 1600 px it is a few hundred kilobytes and still
    /// reads a label.
    static let maxPixels: CGFloat = 1600

    static func jpeg(from image: UIImage) -> Data? {
        let longest = max(image.size.width, image.size.height)
        let scale = min(1, maxPixels / max(longest, 1))
        let size = CGSize(width: image.size.width * scale, height: image.size.height * scale)
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        let shrunk = UIGraphicsImageRenderer(size: size, format: format).image { _ in
            image.draw(in: CGRect(origin: .zero, size: size))
        }
        return shrunk.jpegData(compressionQuality: 0.82)
    }

    static func load(_ fileName: String?, from store: BottlePhotoStore?) -> UIImage? {
        guard let fileName, let store, store.exists(fileName) else { return nil }
        return UIImage(contentsOfFile: store.url(for: fileName).path)
    }
}

/// The photo when there is one, the bottle mark when there is not. Both
/// sit in the same frame so a list does not jump between the two.
struct BottleImage: View {
    @Environment(AppEnvironment.self) private var env
    let fileName: String?
    var height: CGFloat = 58

    var body: some View {
        if let image = BottlePhoto.load(fileName, from: env.photos) {
            Image(uiImage: image)
                .resizable()
                .scaledToFill()
                .frame(width: height * 0.72, height: height)
                .clipShape(RoundedRectangle(cornerRadius: max(4, height / 12)))
                .overlay(RoundedRectangle(cornerRadius: max(4, height / 12))
                    .stroke(Palette.line, lineWidth: 1))
        } else {
            BottleMark(height: height)
        }
    }
}

/// Take, choose or remove. Presented from the bottle screen.
struct BottlePhotoMenu: View {
    @Environment(AppEnvironment.self) private var env
    let bottleId: String
    let current: String?
    let onChange: () -> Void

    @State private var libraryItem: PhotosPickerItem?
    @State private var isTakingPhoto = false
    @State private var error: String?

    var body: some View {
        Menu {
            Button {
                isTakingPhoto = true
            } label: {
                Label("Take a photo", systemImage: "camera")
            }
            PhotosPicker(selection: $libraryItem, matching: .images) {
                Label("Choose from library", systemImage: "photo.on.rectangle")
            }
            if current != nil {
                Button(role: .destructive) {
                    set(nil)
                } label: {
                    Label("Remove photo", systemImage: "trash")
                }
            }
        } label: {
            HStack(spacing: Space.xs) {
                Image(systemName: current == nil ? "camera" : "camera.on.rectangle")
                Text(current == nil ? "Add a photo" : "Change photo")
            }
            .font(TypeScale.secondary())
            .foregroundStyle(Palette.gold)
            .frame(minHeight: Space.tapTarget)
        }
        .sheet(isPresented: $isTakingPhoto) {
            ImagePicker(source: .camera) { picked in
                set(picked)
            }
            .ignoresSafeArea()
        }
        .onChange(of: libraryItem) { _, item in
            guard let item else { return }
            Task {
                if let data = try? await item.loadTransferable(type: Data.self),
                   let picked = UIImage(data: data) {
                    set(picked)
                } else {
                    error = "That photo could not be loaded."
                }
                libraryItem = nil
            }
        }
        .alert("Could not save the photo", isPresented: .constant(error != nil)) {
            Button("OK") { error = nil }
        } message: { Text(error ?? "") }
    }

    /// New file first, then the row, then the old file. A failure anywhere
    /// before the row is written leaves the old photo in place.
    private func set(_ image: UIImage?) {
        guard let store = env.photos else {
            error = "Photos are not available on this device."
            return
        }
        do {
            var newName: String?
            if let image {
                guard let data = BottlePhoto.jpeg(from: image) else {
                    error = "That image could not be read."
                    return
                }
                newName = try store.save(jpeg: data)
            }
            try env.bottles.setPhoto(bottleId: bottleId, fileName: newName)
            if let old = current, old != newName {
                store.delete(old)
            }
            onChange()
        } catch {
            self.error = error.localizedDescription
        }
    }
}
