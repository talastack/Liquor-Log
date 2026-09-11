import Foundation

/// Where a bottle's photo lives: a JPEG file on this device, named by a UUID.
///
/// The bottle row stores the file NAME and the name syncs; the bytes do not.
/// That is deliberate. Photo backup is a service somebody could pay for
/// later, and the free tier is the person's own data handed back -- a CSV
/// and a folder of JPEGs they can copy off the device in Files.
///
/// Foundation only, no UIKit: the app decides how to shrink an image, this
/// only keeps bytes. A missing file is not an error here; the screen shows
/// the bottle mark instead, the same as a bottle that never had a photo.
public struct BottlePhotoStore: Sendable {
    public let folder: URL
    /// Not stored: FileManager is not Sendable, and the default instance is
    /// the only one this ever needs.
    private var fileManager: FileManager { .default }

    /// Under Application Support beside the database by default, so a
    /// device backup that carries the collection carries its photos.
    public init(folder: URL? = nil) throws {
        let fileManager = FileManager.default
        if let folder {
            self.folder = folder
        } else {
            let support = try fileManager.url(
                for: .applicationSupportDirectory,
                in: .userDomainMask,
                appropriateFor: nil,
                create: true)
            self.folder = support
                .appendingPathComponent("LiquorLog", isDirectory: true)
                .appendingPathComponent("photos", isDirectory: true)
        }
        try FileManager.default.createDirectory(at: self.folder, withIntermediateDirectories: true)
    }

    /// Writes JPEG bytes under a fresh name and returns the name to store on
    /// the bottle. Never overwrites: replacing a photo is a new file and a
    /// delete of the old one, so a failed write cannot destroy the previous
    /// picture.
    public func save(jpeg data: Data) throws -> String {
        let name = UUID().uuidString + ".jpg"
        try data.write(to: url(for: name), options: .atomic)
        return name
    }

    public func url(for fileName: String) -> URL {
        folder.appendingPathComponent(fileName)
    }

    public func exists(_ fileName: String) -> Bool {
        fileManager.fileExists(atPath: url(for: fileName).path)
    }

    public func data(for fileName: String) -> Data? {
        try? Data(contentsOf: url(for: fileName))
    }

    /// Silently fine when the file is already gone.
    public func delete(_ fileName: String) {
        try? fileManager.removeItem(at: url(for: fileName))
    }
}
