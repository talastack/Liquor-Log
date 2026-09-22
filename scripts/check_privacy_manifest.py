#!/usr/bin/env python3
"""Assert the privacy manifest exists and covers what the app actually uses.

Apple has required a privacy manifest since May 2024 for any app touching a
"required reason API". The failure mode is the reason this check exists: it
is not a build error. The app compiles, archives, uploads, and only then does
App Store Connect answer with ITMS-91053 and a list of APIs -- at the end of
the slowest loop in the whole process, on the day somebody is trying to ship.

So this runs on the Linux runner in a second, and it checks two directions:

1. **The manifest is there and parses.** A malformed plist fails the same
   way a missing one does.

2. **Nothing is used that is not declared.** Every required-reason category
   is looked for in the Swift, and a hit that the manifest does not declare
   fails. This is the half that matters later: the manifest written today is
   correct today, and the check is what keeps it correct after somebody adds
   a feature that reads the disk.

Reason codes are NOT validated against Apple's list. They change, the list
is not machine-readable anywhere stable, and a wrong-but-plausible code is a
judgement call for a person rather than a string match.
"""

import plistlib
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
MANIFEST = ROOT / "IOS" / "App" / "Resources" / "PrivacyInfo.xcprivacy"

# Where app code lives. The local packages are included: a required-reason
# API called from LiquorData ships inside the app bundle just the same.
SOURCE_DIRS = [
    ROOT / "IOS" / "App",
    ROOT / "IOS" / "Packages" / "LiquorEngine" / "Sources",
    ROOT / "IOS" / "Packages" / "LiquorData" / "Sources",
]

# Apple's four required-reason categories, and the symbols that reach them.
# Deliberately a small, literal list: a regex broad enough to catch every
# spelling would also catch every comment mentioning one.
CATEGORIES = {
    "NSPrivacyAccessedAPICategoryUserDefaults": [
        r"\bUserDefaults\b",
        r"@AppStorage\b",
    ],
    "NSPrivacyAccessedAPICategoryFileTimestamp": [
        r"\.creationDate\b",
        r"\bmodificationDate\b",
        r"\bcontentModificationDateKey\b",
        r"\battributesOfItem\b",
        r"\bNSFileCreationDate\b",
    ],
    "NSPrivacyAccessedAPICategoryDiskSpace": [
        r"\bvolumeAvailableCapacity",
        r"\bsystemFreeSize\b",
        r"\bNSFileSystemFreeSize\b",
    ],
    "NSPrivacyAccessedAPICategorySystemBootTime": [
        r"\bsystemUptime\b",
        r"\bmach_absolute_time\b",
        r"kern\.boottime",
    ],
}

COMMENT = re.compile(r"^\s*(//|/\*|\*)")


def declared_categories():
    data = plistlib.loads(MANIFEST.read_bytes())
    entries = data.get("NSPrivacyAccessedAPITypes", [])
    out = {}
    for entry in entries:
        name = entry.get("NSPrivacyAccessedAPIType")
        reasons = entry.get("NSPrivacyAccessedAPITypeReasons") or []
        if name:
            out[name] = reasons
    return data, out


def used_categories():
    """Every category the Swift actually reaches, with one example each."""
    found = {}
    for base in SOURCE_DIRS:
        if not base.is_dir():
            continue
        for path in sorted(base.rglob("*.swift")):
            text = path.read_text(encoding="utf-8", errors="replace")
            for number, line in enumerate(text.splitlines(), 1):
                if COMMENT.match(line):
                    continue
                for category, patterns in CATEGORIES.items():
                    if category in found:
                        continue
                    for pattern in patterns:
                        if re.search(pattern, line):
                            rel = path.relative_to(ROOT).as_posix()
                            found[category] = "%s:%d  %s" % (
                                rel, number, line.strip()[:70]
                            )
                            break
    return found


def main():
    if not MANIFEST.exists():
        print(
            "privacy manifest FAILED\n\n  - missing %s\n"
            % MANIFEST.relative_to(ROOT).as_posix(),
            file=sys.stderr,
        )
        return 1

    try:
        data, declared = declared_categories()
    except Exception as error:  # a malformed plist fails like a missing one
        print(
            "privacy manifest FAILED\n\n  - %s does not parse: %s"
            % (MANIFEST.relative_to(ROOT).as_posix(), error),
            file=sys.stderr,
        )
        return 1

    problems = []

    if "NSPrivacyTracking" not in data:
        problems.append("NSPrivacyTracking is not declared")

    for category, reasons in declared.items():
        if not reasons:
            problems.append("%s is declared with no reason" % category)

    used = used_categories()
    for category, where in sorted(used.items()):
        if category not in declared:
            problems.append(
                "%s is used but not declared -- %s" % (category, where)
            )

    if problems:
        print("privacy manifest FAILED\n", file=sys.stderr)
        for problem in problems:
            print("  - %s" % problem, file=sys.stderr)
        print(
            "\nAdd the category to NSPrivacyAccessedAPITypes in"
            "\n%s, with a reason code from Apple's list for it."
            % MANIFEST.relative_to(ROOT).as_posix(),
            file=sys.stderr,
        )
        return 1

    print(
        "privacy manifest ok: %d categor%s declared, %d used, tracking=%s"
        % (
            len(declared),
            "y" if len(declared) == 1 else "ies",
            len(used),
            data.get("NSPrivacyTracking"),
        )
    )
    return 0


if __name__ == "__main__":
    sys.exit(main())
