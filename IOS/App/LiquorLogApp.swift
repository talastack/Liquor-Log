import SwiftUI

@main
struct LiquorLogApp: App {
    /// Built once at launch. Opening the database and decoding the bundled
    /// catalog are the only startup work, and neither touches the network.
    @State private var environment = AppEnvironment.live()

    var body: some Scene {
        WindowGroup {
            MainTabView()
                .environment(environment)
                // Both palettes ship and the system setting decides. Nothing
                // here pins a mode -- see the note in project.yml about the
                // deliberately absent UIUserInterfaceStyle key.
                .tint(Palette.gold)
        }
    }
}
