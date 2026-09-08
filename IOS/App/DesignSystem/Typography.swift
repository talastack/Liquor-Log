import SwiftUI

/// The type ramp, mirroring `design/build.py`.
///
/// Three faces, each with one job:
///
/// - **Newsreader** — bottle and expression names only. The character.
/// - **Public Sans** — everything else. The readability.
/// - **Spline Sans Mono** — batch codes, barrel numbers, proof, volumes.
///   Anything you would read out digit by digit.
///
/// **The font files are not in the repo yet.** They are open-licensed (SIL OFL)
/// Google Fonts, and until the .ttf files are added to `App/Resources/Fonts/`
/// and listed under `UIAppFonts` in Info.plist, every call here falls back to
/// the matching system face. That fallback is deliberate: the app must render
/// correctly before the assets land, and a missing font should degrade rather
/// than crash.
enum Typeface {
    static let serif = "Newsreader"
    static let sans = "PublicSans"
    static let mono = "SplineSansMono"
}

enum TypeScale {

    /// Screen titles. Newsreader, because a screen title names a thing.
    static func largeTitle() -> Font { serif(32, .semibold, relativeTo: .largeTitle) }

    /// Bottle and expression names in a card.
    static func title() -> Font { serif(23, .medium, relativeTo: .title2) }

    /// Section headings inside a screen.
    static func headline() -> Font { sans(17, .bold, relativeTo: .headline) }

    /// Default reading size. 16pt, not 14 -- this gets read one-handed in bad
    /// light.
    static func body() -> Font { sans(16, .regular, relativeTo: .body) }

    /// Supporting copy under a heading.
    static func secondary() -> Font { sans(15, .regular, relativeTo: .subheadline) }

    /// Uppercase section labels. The floor for anything in the app is 12pt.
    static func caption() -> Font { sans(12, .bold, relativeTo: .caption) }

    /// Batch codes, proof, millilitres.
    static func code(_ size: CGFloat = 14) -> Font {
        custom(Typeface.mono, size: size, weight: .regular, relativeTo: .footnote)
    }

    // MARK: - Construction

    private static func serif(
        _ size: CGFloat, _ weight: Font.Weight, relativeTo style: Font.TextStyle
    ) -> Font {
        custom(Typeface.serif, size: size, weight: weight, relativeTo: style)
    }

    private static func sans(
        _ size: CGFloat, _ weight: Font.Weight, relativeTo style: Font.TextStyle
    ) -> Font {
        custom(Typeface.sans, size: size, weight: weight, relativeTo: style)
    }

    /// `.custom(_:size:relativeTo:)` scales with Dynamic Type, which
    /// `.custom(_:fixedSize:)` does not. Every size in this file is therefore a
    /// starting point, not a fixed measurement -- §11 requires the app to work
    /// at the largest accessibility size, so nothing may pin a height around
    /// text.
    private static func custom(
        _ name: String, size: CGFloat, weight: Font.Weight, relativeTo style: Font.TextStyle
    ) -> Font {
        if UIFont.familyNames.contains(where: { $0.replacingOccurrences(of: " ", with: "") == name }) {
            return .custom(name, size: size, relativeTo: style).weight(weight)
        }
        return .system(style, design: name == Typeface.mono ? .monospaced
                                    : name == Typeface.serif ? .serif : .default)
            .weight(weight)
    }
}

/// Spacing rhythm. Four steps, and everything in the app is one of them.
enum Space {
    static let xs: CGFloat = 4
    static let s: CGFloat = 8
    static let m: CGFloat = 12
    static let l: CGFloat = 16
    static let xl: CGFloat = 24

    /// Minimum tap target on every platform Apple ships. Applied with
    /// `.frame(minWidth:minHeight:)`, never a fixed frame.
    static let tapTarget: CGFloat = 44
}
