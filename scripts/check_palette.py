#!/usr/bin/env python3
"""Assert the two palettes agree, and that every text colour can be read.

Two claims, one file each side:

1. **The platforms carry the same colours.** `Palette.kt` and
   `Palette.swift` spell four looks in two modes as hex, by hand, in
   different shapes -- Kotlin as one `Palette(...)` per look and mode, Swift
   as one `Scheme` per look with `(dark, light)` pairs. Nothing else keeps
   them together, and a colour tuned on one side and forgotten on the other
   is a look that is not the same look on the other phone.

2. **Text clears WCAG AA against what it sits on.** 4.5:1 for every text
   token on the ground, a card and a raised chip, and for the ink on an
   accent button and on the HAVE THE LINE badge. A pass here was measured,
   not assumed: the first run of this check found twenty-two pairs under
   the line, the faint caption grey in every light look worst of all, and
   Label's dark mode putting pale ink on a red that could not carry it.
"""

import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
KOTLIN = ROOT / "Android/app/src/main/kotlin/com/talastack/liquorlog/ui/theme/Palette.kt"
SWIFT = ROOT / "IOS/App/DesignSystem/Palette.swift"

AA = 4.5
GROUNDS = ("background", "surface", "surfaceRaised")
TEXT = ("text", "textSecondary", "textMuted", "accent", "good", "bad")
INKED = ("accent", "haveTheLine")  # fills that carry onAccent text


def kotlin_palettes(src):
    """{(look, mode): {token: HEX}} from `private val cellarDark = Palette(...)`."""
    out = {}
    for m in re.finditer(r"private val (\w+?)(Dark|Light) = Palette\((.*?)\n\)", src, re.S):
        look, mode, body = m.group(1), m.group(2).lower(), m.group(3)
        out[(look, mode)] = {
            k: v.upper() for k, v in re.findall(r"(\w+) = Color\(0xFF([0-9A-Fa-f]{6})\)", body)
        }
    return out


def swift_palettes(src):
    """The same shape from `case .cellar: return Scheme(token: (0xDARK, 0xLIGHT), ...)`."""
    out = {}
    for m in re.finditer(r"case \.(\w+):\s*return Scheme\((.*?)\)\s*(?=case|\})", src, re.S):
        look, body = m.group(1), m.group(2)
        dark, light = {}, {}
        for k, d, l in re.findall(r"(\w+): \(0x([0-9A-Fa-f]{6}), 0x([0-9A-Fa-f]{6})\)", body):
            dark[k], light[k] = d.upper(), l.upper()
        out[(look, "dark")] = dark
        out[(look, "light")] = light
    return out


def luminance(hex6):
    def channel(c):
        c = c / 255
        return c / 12.92 if c <= 0.03928 else ((c + 0.055) / 1.055) ** 2.4
    r, g, b = (int(hex6[i:i + 2], 16) for i in (0, 2, 4))
    return 0.2126 * channel(r) + 0.7152 * channel(g) + 0.0722 * channel(b)


def contrast(a, b):
    la, lb = luminance(a), luminance(b)
    return (max(la, lb) + 0.05) / (min(la, lb) + 0.05)


def main():
    for path in (KOTLIN, SWIFT):
        if not path.exists():
            print("palette FAILED\n\n  - %s is missing" % path, file=sys.stderr)
            return 1

    kt = kotlin_palettes(KOTLIN.read_text(encoding="utf-8"))
    sw = swift_palettes(SWIFT.read_text(encoding="utf-8"))
    problems = []

    if len(kt) != 8 or len(sw) != 8:
        problems.append(
            "expected four looks in two modes on each side; read %d from Kotlin"
            " and %d from Swift. If the files changed shape, change this check"
            " with them." % (len(kt), len(sw)))

    for key in sorted(set(kt) | set(sw)):
        look, mode = key
        if key not in kt or key not in sw:
            problems.append("%s %s exists on one platform only" % (look, mode))
            continue
        for token in sorted(set(kt[key]) | set(sw[key])):
            a, b = kt[key].get(token), sw[key].get(token)
            if a != b:
                problems.append("%s %s %s: Android %s, iOS %s" % (look, mode, token, a, b))

    for (look, mode), p in sorted(kt.items()):
        for fg in TEXT:
            for bg in GROUNDS:
                if fg in p and bg in p:
                    r = contrast(p[fg], p[bg])
                    if r < AA:
                        problems.append("%s %s: %s on %s is %.2f:1, under %.1f"
                                        % (look, mode, fg, bg, r, AA))
        for fill in INKED:
            if fill in p and "onAccent" in p:
                r = contrast(p["onAccent"], p[fill])
                if r < AA:
                    problems.append("%s %s: onAccent on %s is %.2f:1, under %.1f"
                                    % (look, mode, fill, r, AA))

    if problems:
        print("palette FAILED\n", file=sys.stderr)
        for p in problems:
            print("  - " + p, file=sys.stderr)
        return 1

    print("palette ok: %d schemes identical on both platforms, every text pair at AA"
          % len(kt))
    return 0


if __name__ == "__main__":
    sys.exit(main())
