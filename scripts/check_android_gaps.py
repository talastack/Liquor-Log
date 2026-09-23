#!/usr/bin/env python3
"""Assert the Android "Not built yet" list does not name something that is.

`MoreScreen.kt` ends with a list headed "Not built on Android yet". It is
honest design -- somebody coming from the iPhone should be told what is
missing rather than hunting for it -- and it is the kind of copy that is
written once and then quietly outlived by the code.

It already happened. Infinity bottles were built, shipped, and left on the
list, so the app told people a feature was absent while it sat two taps away
on their own bottle. That is worse than the gap: a gap is a thing not done,
and this is the app being wrong about itself.

So each line is tied to the symbol that exists only once the feature does.
If the symbol turns up in the Compose UI, the line has to go.

This cannot prove the reverse -- that everything missing IS listed -- and
does not try. It catches the direction that actually rots: shipping
something and forgetting to stop apologising for it.
"""

import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
MORE = ROOT / "Android/app/src/main/kotlin/com/talastack/liquorlog/ui/MoreScreen.kt"
UI = ROOT / "Android/app/src/main/kotlin/com/talastack/liquorlog/ui"

# (what a line says, what exists in the UI once it is built, how to say so)
#
# The symbols are Compose entry points, not engine types: the engine has
# had PriceHistory and CommunityPrice since the port began, and neither is
# reachable from a screen, so naming those would fail on a true claim.
CLAIMS = [
    ("infinity", r"\bInfinityCard\b|\bInfinityBottleDialog\b", "the infinity bottle"),
    ("flight", r"\bFlightScreen\b|\bFlightSetup\b", "flights"),
    ("shelf walk", r"\bShelfWalkScreen\b|\bReInventoryScreen\b", "the shelf walk"),
    ("backup", r"\bBackupScreen\b|\bRestoreScreen\b", "backup and restore"),
    ("sync", r"\bSyncScreen\b|\bSignInScreen\b", "sync and sign-in"),
    ("scan", r"\bScanScreen\b|\bLabelScanner\b", "label scanning"),
    ("price", r"\bPriceScreen\b|\bPriceCheckScreen\b", "the price check"),
]


def listed_lines():
    """The strings inside the NOT_YET list."""
    text = MORE.read_text(encoding="utf-8")
    match = re.search(r"NOT_YET\s*=\s*listOf\((.*?)\)", text, re.S)
    if not match:
        return None
    return re.findall(r'"([^"]+)"', match.group(1))


def built():
    """Every identifier the Compose UI defines or calls."""
    blob = []
    for path in sorted(UI.rglob("*.kt")):
        if path.name == "MoreScreen.kt":
            continue  # the list itself is not evidence of anything
        blob.append(path.read_text(encoding="utf-8", errors="replace"))
    return "\n".join(blob)


def main():
    if not MORE.exists():
        print("android gaps FAILED\n\n  - %s is missing" % MORE.name, file=sys.stderr)
        return 1

    lines = listed_lines()
    if lines is None:
        print(
            "android gaps FAILED\n\n  - no NOT_YET list in MoreScreen.kt."
            "\n    If the list was renamed, rename it here too; if it was"
            "\n    removed because nothing is missing any more, remove this"
            "\n    check with it.",
            file=sys.stderr,
        )
        return 1

    code = built()
    problems = []

    for line in lines:
        for word, pattern, feature in CLAIMS:
            if word not in line.lower():
                continue
            found = re.search(pattern, code)
            if found:
                problems.append(
                    '"%s" says %s is not built, but %s is in the UI'
                    % (line, feature, found.group(0))
                )

    if problems:
        print("android gaps FAILED\n", file=sys.stderr)
        for problem in problems:
            print("  - %s" % problem, file=sys.stderr)
        print(
            "\nThe app is telling people a feature is missing while they can"
            "\nuse it. Take the line out of NOT_YET in MoreScreen.kt.",
            file=sys.stderr,
        )
        return 1

    print("android gaps ok: %d listed, none of them built" % len(lines))
    return 0


if __name__ == "__main__":
    sys.exit(main())
