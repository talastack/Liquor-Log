import SwiftUI
import UIKit

/// Every colour in the app, in both modes.
///
/// **This file and `design/build.py` are a paired edit.** The hex values here
/// mirror the `DARK` and `LIGHT` dictionaries in that file, which generate the
/// design canvas. Nothing at runtime notices when they drift; the canvas simply
/// stops describing the app.
///
/// Colours live in code rather than an asset catalog for one reason: the canvas
/// is generated from a Python dictionary, and a Swift dictionary can be diffed
/// against it by eye in a single screen. An asset catalog spreads the same
/// values across a directory of JSON files where nobody would ever check.
///
/// The rule that matters is unchanged either way: **no colour literal appears
/// anywhere else in the app.**
enum Palette {

    // MARK: - Ground

    /// Warm near-black, never pure black -- gold vibrates against #000.
    static let background = dynamic(dark: 0x15100A, light: 0xF6F1E7)
    static let surface = dynamic(dark: 0x1E1710, light: 0xFFFDF7)
    static let surfaceRaised = dynamic(dark: 0x2A2016, light: 0xECE4D4)
    static let line = dynamic(dark: 0x3A2D1E, light: 0xDCD0BA)

    // MARK: - Type

    static let text = dynamic(dark: 0xF2E9DB, light: 0x1B1510)
    static let textSecondary = dynamic(dark: 0xC0B19A, light: 0x4A4036)
    static let textMuted = dynamic(dark: 0x968771, light: 0x6B5F50)

    // MARK: - Accent

    /// Carries meaning only: fill level, rating, the primary action. Never
    /// decoration.
    static let gold = dynamic(dark: 0xC9973A, light: 0x8A5F18)
    static let goldSoft = dynamic(dark: 0xE2B661, light: 0xA87C2C)
    /// Text and icons that sit *on* gold.
    static let onGold = dynamic(dark: 0x1A1309, light: 0xFFFDF7)

    // MARK: - Verdicts

    /// The one place colour is categorical. Every one of these is paired with a
    /// text label in the UI -- colour alone fails a dim shop aisle and fails
    /// anyone colour-blind.
    enum Verdict {
        static let onShelf = dynamic(dark: 0xC9973A, light: 0x8A5F18)
        static let haveTheLine = dynamic(dark: 0xA5763C, light: 0x8A5F18)
        static let tastedNotOwned = dynamic(dark: 0x9D84B8, light: 0x4E4176)
        static let hadItBefore = dynamic(dark: 0x7F96AB, light: 0x3A5670)
        static let neverHadIt = dynamic(dark: 0xB5705A, light: 0x94402A)
    }

    // MARK: - Status

    static let good = dynamic(dark: 0x7FAA72, light: 0x356038)
    static let bad = dynamic(dark: 0xC07862, light: 0x94402A)

    // MARK: - Bottle artwork

    static let glass = dynamic(dark: 0x5A4326, light: 0xC9B48C)

    // MARK: - Construction

    /// One colour that resolves per trait collection, so a mode switch needs no
    /// view invalidation of our own.
    private static func dynamic(dark: UInt32, light: UInt32) -> Color {
        Color(uiColor: UIColor { traits in
            traits.userInterfaceStyle == .dark
                ? UIColor(rgb: dark)
                : UIColor(rgb: light)
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
