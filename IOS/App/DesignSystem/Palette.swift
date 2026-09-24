import SwiftUI
import UIKit
import LiquorData

/// Every colour in the app, in both modes, in four looks.
///
/// The first version of this file was one look: warm near-black with an
/// amber accent. It is also the look most AI-assisted apps ship with, and
/// the owner asked for something that was not that. So the palette became
/// a set of looks, chosen in More, each rooted in something a bourbon
/// collector actually sees:
///
/// - **Cellar** -- green-black and copper, the inside of a rickhouse at dusk.
///   The default, chosen by the owner from the four.
/// - **Label** -- cream paper and oxblood ink, the look of an old label.
///   Light-first.
/// - **Bond** -- navy and brass, the tax strip and the bonded seal.
/// - **Amber** -- the original, kept for anybody who liked it.
///
/// Every screen reads `Palette.gold`, `Palette.text` and so on; the names
/// stayed so that two hundred call sites did not move. Under each name is
/// the current look's value, resolved per light/dark trait, so a mode switch
/// needs no invalidation and a look switch is a rebuild of the root view.
///
/// The rule that matters is unchanged: **no colour literal appears anywhere
/// else in the app.**
enum Palette {

    // MARK: - Looks

    enum Look: String, CaseIterable, Identifiable {
        case cellar, label, bond, amber

        var id: String { rawValue }

        var name: String {
            switch self {
            case .label: return "Label"
            case .cellar: return "Cellar"
            case .bond: return "Bond"
            case .amber: return "Amber"
            }
        }

        var line: String {
            switch self {
            case .label: return "Cream paper and oxblood ink. Light by default."
            case .cellar: return "Green-black and copper. The rickhouse at dusk."
            case .bond: return "Navy and brass. The tax strip and the seal."
            case .amber: return "Warm black and gold. The first look."
            }
        }

        static let key = "theme.look"
        static let standard: Look = .cellar

        /// The app group's defaults, so the widget -- a separate process
        /// with defaults of its own -- renders the look the app chose.
        /// Falls back to the app's standard defaults, where a choice made
        /// before the group existed still lives.
        static var defaults: UserDefaults { shared.defaults }
        /// One instance, so @AppStorage observes the same object the widget
        /// reads. UserDefaults is documented thread-safe; the box says so.
        private struct Shared: @unchecked Sendable { let defaults: UserDefaults }
        private static let shared = Shared(defaults: UserDefaults(suiteName: AppDatabase.appGroup) ?? .standard)

        static var current: Look {
            let stored = defaults.string(forKey: key) ?? UserDefaults.standard.string(forKey: key)
            return Look(rawValue: stored ?? "") ?? standard
        }
    }

    // MARK: - Light or dark

    /// Which half of a look to use.
    ///
    /// Separate from `Look` on purpose. A look is a colour family -- the
    /// green of a rickhouse, the cream and oxblood of a label -- and each
    /// one has a light set of tokens and a dark set. Until now the phone
    /// chose between them and nothing in the app could, so somebody who
    /// keeps their phone in light mode could not have a dark shelf, and
    /// picking "Cellar: green-black and copper" gave them a pale green
    /// screen.
    ///
    /// The WIDGET cannot follow this. A widget renders in the system
    /// appearance and an app cannot override that for it, so a forced-dark
    /// app on a light phone has a light widget. Better than the alternative,
    /// which is a widget that disagrees with the Home Screen around it.
    enum Appearance: String, CaseIterable, Identifiable {
        case system, light, dark

        var id: String { rawValue }

        var name: String {
            switch self {
            case .system: return "Follow the phone"
            case .light: return "Always light"
            case .dark: return "Always dark"
            }
        }

        var line: String {
            switch self {
            case .system: return "Light by day, dark at night, as the phone is set."
            case .light: return "Paper, whatever the phone is doing."
            case .dark: return "The bar at night, whatever the phone is doing."
            }
        }

        /// What SwiftUI needs. `nil` means "do not override", which is the
        /// only way to say "follow the phone" -- there is no `.system` case
        /// on ColorScheme.
        var colorScheme: ColorScheme? {
            switch self {
            case .system: return nil
            case .light: return .light
            case .dark: return .dark
            }
        }

        static let key = "theme.appearance"
        static let standard: Appearance = .system

        /// The same app-group defaults the look uses.
        static var defaults: UserDefaults { Look.defaults }

        static var current: Appearance {
            let stored = defaults.string(forKey: key)
                ?? UserDefaults.standard.string(forKey: key)
            return Appearance(rawValue: stored ?? "") ?? standard
        }
    }

    /// One look: every token as a dark and a light hex.
    struct Scheme {
        let background, surface, surfaceRaised, line: (dark: UInt32, light: UInt32)
        let text, textSecondary, textMuted: (dark: UInt32, light: UInt32)
        let accent, accentSoft, onAccent: (dark: UInt32, light: UInt32)
        let haveTheLine: (dark: UInt32, light: UInt32)
        let good, bad, glass: (dark: UInt32, light: UInt32)
    }

    static func scheme(for look: Look) -> Scheme {
        switch look {
        case .label:
            return Scheme(
                background: (0x17120E, 0xF4EBD8),
                surface: (0x211A15, 0xFBF5E8),
                surfaceRaised: (0x2C231C, 0xEADFC6),
                line: (0x3E3228, 0xD5C7A8),
                text: (0xF0E7D8, 0x1E1A14),
                textSecondary: (0xBBAD97, 0x5A4F3F),
                textMuted: (0x998B77, 0x6C6052),
                accent: (0xD66F5A, 0x8B2E1F),
                accentSoft: (0xE06A52, 0xA63D2C),
                onAccent: (0x17120E, 0xFBF5E8),
                haveTheLine: (0xB07A63, 0x9A5A45),
                good: (0x7FAA72, 0x3E6B3A),
                bad: (0xC17B66, 0x9A3A22),
                glass: (0x5A4A38, 0xB8A57E))
        case .cellar:
            return Scheme(
                background: (0x0E1613, 0xEEF2EA),
                surface: (0x152019, 0xF7F9F4),
                surfaceRaised: (0x1F2C24, 0xDFE7DD),
                line: (0x2F4034, 0xC3D0C2),
                text: (0xEAF0E9, 0x14201A),
                textSecondary: (0xA9B8AC, 0x4A5A4F),
                textMuted: (0x869589, 0x59685E),
                accent: (0xCA7F4F, 0x915631),
                accentSoft: (0xE09466, 0xB56E42),
                onAccent: (0x10140F, 0xFFFBF6),
                haveTheLine: (0xA5764F, 0x7E5A3C),
                good: (0x86B37A, 0x37693B),
                bad: (0xC97C68, 0x9B3E2A),
                glass: (0x3E4F44, 0xB6C4B2))
        case .bond:
            return Scheme(
                background: (0x0D1626, 0xEFF2F7),
                surface: (0x14203A, 0xFFFFFF),
                surfaceRaised: (0x1D2B49, 0xDFE5EF),
                line: (0x2E3E60, 0xC6CFDD),
                text: (0xEEF1F7, 0x101828),
                textSecondary: (0xB4BDD0, 0x475467),
                textMuted: (0x8795AF, 0x5C657A),
                accent: (0xC8A44A, 0x7A5D14),
                accentSoft: (0xDDBB62, 0x94722A),
                onAccent: (0x0D1626, 0xFFFFFF),
                haveTheLine: (0xA48A4E, 0x6E5A22),
                good: (0x7FAA72, 0x356038),
                bad: (0xC58471, 0x94402A),
                glass: (0x3A4A6A, 0xB9C4D6))
        case .amber:
            return Scheme(
                background: (0x15100A, 0xF6F1E7),
                surface: (0x1E1710, 0xFFFDF7),
                surfaceRaised: (0x2A2016, 0xECE4D4),
                line: (0x3A2D1E, 0xDCD0BA),
                text: (0xF2E9DB, 0x1B1510),
                textSecondary: (0xC0B19A, 0x4A4036),
                textMuted: (0x968771, 0x6B5F50),
                accent: (0xC9973A, 0x875D18),
                accentSoft: (0xE2B661, 0xA87C2C),
                onAccent: (0x1A1309, 0xFFFDF7),
                haveTheLine: (0xA5763C, 0x8A5F18),
                good: (0x7FAA72, 0x356038),
                bad: (0xC07862, 0x94402A),
                glass: (0x5A4326, 0xC9B48C))
        }
    }

    private static var current: Scheme { scheme(for: Look.current) }

    // MARK: - Ground

    static var background: Color { dynamic(current.background) }
    static var surface: Color { dynamic(current.surface) }
    static var surfaceRaised: Color { dynamic(current.surfaceRaised) }
    static var line: Color { dynamic(current.line) }

    // MARK: - Type

    static var text: Color { dynamic(current.text) }
    static var textSecondary: Color { dynamic(current.textSecondary) }
    static var textMuted: Color { dynamic(current.textMuted) }

    // MARK: - Accent

    /// Carries meaning only: fill level, rating, the primary action. Never
    /// decoration. Named `gold` from the first look; it is whatever the
    /// current look's accent is.
    static var gold: Color { dynamic(current.accent) }
    static var goldSoft: Color { dynamic(current.accentSoft) }
    /// Text and icons that sit *on* the accent.
    static var onGold: Color { dynamic(current.onAccent) }

    // MARK: - Verdicts

    /// The one place colour is categorical. Every one of these is paired with a
    /// text label in the UI -- colour alone fails a dim shop aisle and fails
    /// anyone colour-blind. Four of the six are fixed across looks so they
    /// stay distinguishable from each other and from the accent.
    enum Verdict {
        static var onShelf: Color { Palette.gold }
        static var haveTheLine: Color { dynamic(Palette.current.haveTheLine) }
        static var haveASample: Color { dynamic((0x6FA8A0, 0x2E6B64)) }
        static var tastedNotOwned: Color { dynamic((0x9D84B8, 0x4E4176)) }
        static var hadItBefore: Color { dynamic((0x7F96AB, 0x3A5670)) }
        static var neverHadIt: Color { dynamic((0xB5705A, 0x94402A)) }
    }

    // MARK: - Status

    static var good: Color { dynamic(current.good) }
    static var bad: Color { dynamic(current.bad) }

    // MARK: - Bottle artwork

    static var glass: Color { dynamic(current.glass) }

    // MARK: - Fixed

    /// The one colour no look changes: the white behind a QR code, which
    /// a camera has to read whatever the theme.
    static var paper: Color { Color(uiColor: .white) }

    // MARK: - Swatches, for the picker

    /// The accent and the ground of a look, for a swatch that shows what
    /// choosing it would do, without switching.
    static func swatch(for look: Look, dark: Bool) -> (accent: Color, ground: Color, ink: Color) {
        let s = scheme(for: look)
        func pick(_ pair: (dark: UInt32, light: UInt32)) -> Color {
            Color(uiColor: UIColor(rgb: dark ? pair.dark : pair.light))
        }
        return (pick(s.accent), pick(s.background), pick(s.text))
    }

    // MARK: - Construction

    /// One colour that resolves per trait collection, so a mode switch needs no
    /// view invalidation of our own.
    private static func dynamic(_ pair: (dark: UInt32, light: UInt32)) -> Color {
        Color(uiColor: UIColor { traits in
            traits.userInterfaceStyle == .dark
                ? UIColor(rgb: pair.dark)
                : UIColor(rgb: pair.light)
        })
    }
}

private extension UIColor {
    convenience init(rgb: UInt32) {
        self.init(
            red: CGFloat((rgb >> 16) & 0xFF) / 255,
            green: CGFloat((rgb >> 8) & 0xFF) / 255,
            blue: CGFloat(rgb & 0xFF) / 255,
            alpha: 1
        )
    }
}
