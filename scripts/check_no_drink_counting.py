#!/usr/bin/env python3
"""Assert nothing on screen counts drinks, paces them, or rewards more.

App Store guideline 1.4.3 refuses apps that encourage excessive consumption
of alcohol. This app was designed against it from the beginning -- it counts
BOTTLES, and what is left in them, which is inventory. It never counts
drinks, estimates intoxication, or turns drinking into a run to keep going.

That is a design decision, and design decisions erode. A "you've had 3 this
week" summary or a streak badge is an obvious feature to add on a Tuesday
and an obvious rejection on the Thursday after. So the rule is checked
rather than remembered.

Scans user-facing STRINGS in both apps, not identifiers -- the same lesson
as `check_no_paywall.py`, where a search for symbols passed while four
pieces of visible copy still said the opposite.

Each phrase below is one that has no innocent reading in this app:

    streak                  a run to keep going, which is the mechanic
    blood alcohol / BAC     an intoxication estimate
    standard drink          the unit of a consumption tracker
    units of alcohol        the same, in British
    drinks today/this week  counting drinks over a period
    bottles killed          consumption as achievement
    pace yourself           pacing, which needs a model of intoxication

Deliberately NOT here: "drinks" alone. "Drinks below its proof" is how a
whiskey tastes, and "how it has drunk" is a tasting note. Banning the word
would fail on the app's own vocabulary, which is the fastest way to have a
check switched off.
"""

import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent

# Where a person can read a string. Tests are excluded: a test that asserts
# the app does NOT say something has to name the thing.
SOURCES = [
    (ROOT / "IOS" / "App", "*.swift"),
    (ROOT / "IOS" / "Widgets", "*.swift"),
    (ROOT / "IOS" / "Packages" / "LiquorEngine" / "Sources", "*.swift"),
    (ROOT / "IOS" / "Packages" / "LiquorData" / "Sources", "*.swift"),
    (ROOT / "Android" / "app" / "src" / "main", "*.kt"),
    (ROOT / "Android" / "engine" / "src" / "main", "*.kt"),
    (ROOT / "Android" / "data" / "src" / "main", "*.kt"),
]

PHRASES = [
    (r"\bstreaks?\b", "a streak is a run to keep going; that is the mechanic 1.4.3 names"),
    (r"blood alcohol", "an intoxication estimate"),
    (r"\bBAC\b", "an intoxication estimate"),
    (r"standard drinks?", "the unit of a consumption tracker"),
    (r"units? of alcohol", "the unit of a consumption tracker"),
    (r"drinks?\s+(today|this week|this month|tonight|so far)", "counting drinks over a period"),
    (r"(bottles|drinks)\s+killed", "consumption as an achievement"),
    (r"pace yourself", "pacing needs a model of intoxication"),
    (r"\bdrinking goal", "a target to drink towards"),
]

# A double-quoted string literal. Good enough for both languages: neither
# app writes user-facing copy anywhere else.
STRING = re.compile(r'"([^"\\\n]|\\.)*"')


def main():
    findings = []
    scanned = 0

    for folder, glob in SOURCES:
        if not folder.exists():
            continue
        for path in sorted(folder.rglob(glob)):
            scanned += 1
            for number, line in enumerate(
                path.read_text(encoding="utf-8", errors="replace").splitlines(), 1
            ):
                stripped = line.lstrip()
                if stripped.startswith("//"):
                    continue
                for literal in STRING.finditer(line):
                    text = literal.group(0)
                    for pattern, why in PHRASES:
                        if re.search(pattern, text, re.IGNORECASE):
                            findings.append(
                                (path.relative_to(ROOT).as_posix(), number, text[:70], why)
                            )

    if findings:
        print("drink counting FAILED\n", file=sys.stderr)
        for rel, number, text, why in findings:
            print("  - %s:%d" % (rel, number), file=sys.stderr)
            print("      %s" % text, file=sys.stderr)
            print("      %s" % why, file=sys.stderr)
        print(
            "\nApp Store guideline 1.4.3 refuses apps that encourage excessive"
            "\nconsumption. Count bottles, not drinks.",
            file=sys.stderr,
        )
        return 1

    print("drink counting ok: %d files, nothing on screen counts drinks" % scanned)
    return 0


if __name__ == "__main__":
    sys.exit(main())
