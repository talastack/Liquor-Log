import Foundation
import Observation
import LiquorData
import LiquorEngine

/// Everything the screens read from: the database, the bundled catalog, the
/// flavour wheel, and the repositories over them.
///
/// **Nothing here touches the network.** The catalog and the wheel are files in
/// the app bundle and the data is a local SQLite file, which is what makes the
/// shelf check work in a shop with no signal.
@Observable
final class AppEnvironment {
    let database: AppDatabase
    let catalog: Catalog
    let wheel: FlavorWheel

    /// Set when the database could not be opened at all. The app stays up and
    /// says so rather than crashing on launch — a collection you cannot reach
    /// is bad, and a crash you cannot report is worse.
    private(set) var startupError: String?

    var bottles: BottleRepository { BottleRepository(database) }
    var tastings: TastingRepository { TastingRepository(database) }
    var shelfWalk: ReInventoryRepository { ReInventoryRepository(database) }
    var wishlist: WishlistRepository { WishlistRepository(database) }
    var export: CollectionExport { CollectionExport(database) }

    init(database: AppDatabase, catalog: Catalog, wheel: FlavorWheel, startupError: String? = nil) {
        self.database = database
        self.catalog = catalog
        self.wheel = wheel
        self.startupError = startupError
    }

    // MARK: - Construction

    static func live() -> AppEnvironment {
        let catalog = loadCatalog()
        let wheel = loadWheel()
        do {
            return AppEnvironment(
                database: try AppDatabase.onDisk(), catalog: catalog, wheel: wheel)
        } catch {
            // Fall back to an in-memory database so the app runs and can
            // explain itself, rather than dying at launch.
            let memory = Self.fallbackDatabase()
            return AppEnvironment(
                database: memory, catalog: catalog, wheel: wheel,
                startupError: "Could not open your collection: \(error.localizedDescription)")
        }
    }

    /// Previews and the simulator, seeded with the same bottles the design
    /// canvas shows — so a preview and a mockup describe one app.
    static func preview() -> AppEnvironment {
        AppEnvironment(
            database: (try? AppDatabase.populatedForPreviews()) ?? fallbackDatabase(),
            catalog: loadCatalog(),
            wheel: loadWheel())
    }

    // MARK: - Bundled files

    /// A missing or corrupt catalog degrades to an empty one. The app still
    /// works: you can type a bottle in yourself, which it supports anyway.
    static func loadCatalog() -> Catalog {
        guard let data = bundled("spirits.v1"),
              let catalog = try? Catalog.decode(from: data)
        else { return .empty }
        return catalog
    }

    static func loadWheel() -> FlavorWheel {
        guard let data = bundled("flavor-wheel.v1"),
              let wheel = try? FlavorWheel.decode(from: data)
        else { return FlavorWheel(version: 0, name: "Unavailable", families: []) }
        return wheel
    }

    private static func bundled(_ name: String) -> Data? {
        guard let url = Bundle.main.url(forResource: name, withExtension: "json") else {
            return nil
        }
        return try? Data(contentsOf: url)
    }

    // MARK: - Reading

    /// The product ids the user has any history with, for the search boost.
    func historyProductIds() -> Set<String> {
        let owned = (try? bottles.summaries(includeFinished: true))?
            .compactMap(\.bottle.catalogProductId) ?? []
        return Set(owned)
    }

    /// A product id resolves against the BUNDLED catalog first and the user's
    /// own entries second. A bottle somebody typed in has to answer the shelf
    /// check exactly like a catalogue one, or half their collection is invisible
    /// to the screen the app exists for.
    func identity(_ productId: String) -> ProductIdentity? {
        if let identity = catalog.identity(productId) { return identity }
        guard let custom = try? bottles.customProduct(id: productId) else { return nil }
        return ProductIdentity(
            productId: custom.id,
            distillery: custom.distillery,
            brand: custom.brand,
            expression: custom.expression,
            classType: custom.classType,
            productionType: custom.productionType)
    }

    func name(for bottle: Bottle) -> String {
        if let id = bottle.catalogProductId, let identity = identity(id) {
            return identity.displayName
        }
        return bottle.customName ?? "Untitled bottle"
    }

    func distillery(for bottle: Bottle) -> String? {
        bottle.catalogProductId.flatMap { identity($0)?.distillery }
    }

    /// The class of what is in the bottle, from either catalog.
    func classType(for bottle: Bottle) -> ClassType? {
        bottle.catalogProductId.flatMap { identity($0)?.classType }
    }

    func product(for bottle: Bottle) -> CatalogProduct? {
        bottle.catalogProductId.flatMap { catalog.product($0) }
    }
}

private extension AppEnvironment {
    /// Last resort. An in-memory queue has no filesystem to fail on, so if this
    /// throws the device is beyond help and crashing is more honest than
    /// pretending the app has a database.
    static func fallbackDatabase() -> AppDatabase {
        // swiftlint:disable:next force_try
        try! AppDatabase.inMemory()
    }
}
