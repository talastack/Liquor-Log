import SwiftUI

@main
struct LiquorLogApp: App {
    var body: some Scene {
        WindowGroup {
            MainTabView()
                // Both palettes ship and the system setting decides. Nothing
                // here pins a mode -- see the note in project.yml about the
                // deliberately absent UIUserInterfaceStyle key.
                .tint(Palette.gold)
        }
    }
}
