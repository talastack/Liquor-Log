#!/usr/bin/env python3
"""Assert the app sells nothing, on either platform.

The paid tier was removed by the owner's decision: no subscription, no
in-app purchase, no tier. This guards that, because the removal was easy to
get *almost* right. Deleting StoreKit and the Entitlement enum left four
pieces of copy behind that still told people about a subscription -- the
sync screen's delete-account note, two sections of the privacy policy and
the terms -- and none of them named a symbol, so grepping for the code
found none of them.

So this checks two different things:

1. **Symbols.** Any billing framework, client or permission appearing
   anywhere is a failure. This catches the code coming back.

2. **Strings people can read.** Every string literal in a source file that
   is not a comment, checked for the words a paywall is made of. This
   catches the copy coming back, which is the half that actually reaches a
   user.

Deliberately NOT in the string pattern: "price". Almost five thousand
strings in this app mention one, and every single one is the price of a
BOTTLE -- what was paid, the shelf price, the wishlist target. Putting it
here would mean a hundred exceptions, and a check with a hundred
exceptions is one nobody reads.
"""

import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent

# Where a user-visible string can come from. Tests are excluded: a test may
# legitimately name a thing it is asserting the absence of.
SOURCE_DIRS = [
    "IOS/App",
    "IOS/Packages/LiquorEngine/Sources",
    "IOS/Packages/LiquorData/Sources",
    "Android/app/src/main",
    "Android/engine/src/main",
    "Android/data/src/main",
]
SOURCE_EXTS = {".swift", ".kt", ".xml"}

# Everything else that could carry a billing integration.
CONFIG_GLOBS = [
    "IOS/project.yml",
    "IOS/**/*.plist",
    "IOS/**/*.entitlements",
    "IOS/**/*.storekit",
    "Android/**/build.gradle.kts",
    "Android/**/AndroidManifest.xml",
]

# A billing integration, by name. Any of these is a hard failure.
SYMBOLS = re.compile(
    r"StoreKit"
    r"|SKPayment|SKProduct"
    r"|ProStore|PaywallView|ProLockedCard"
    r"|com\.android\.vending\.BILLING"
    r"|BillingClient|billingclient|Play Billing"
    r"|RevenueCat|Purchases\.configure"
    r"|\.storekit\b",
)

# The words a paywall is made of, as a person would read them.
COPY = re.compile(
    r"subscription|subscribe|auto.?renew"
    r"|in-?app purchase|restore purchase"
    r"|paywall|premium|free trial"
    r"|upgrade to|unlock (?:the |this |all |more )"
    # A billing period is always attached to a figure: "per month",
    # "$9/year". The bare "a month" and "a year" are how this app talks
    # about a bottle nobody has poured from in a while.
    r"|per month|per year|/month|/year|a month for|a year for"
    r"|start your trial|cancel any time"
    # Advertising something as free is the paid tier's shadow. It only says
    # anything if something else is not, so after the tier went it left
    # three lines implying a paid version nobody could find: "Export and
    # backup are free, account or not", "Bring in a CSV. Free", "Free and
    # complete". "Free pour" is excluded below -- it is a real thing to do
    # with a bottle and has nothing to do with money.
    r"|\bfree\b",
    re.I,
)

# "Free" in its bartending sense: pouring by eye, with no measure.
FREE_POUR = re.compile(r"free[ -]pour", re.I)

STRING = re.compile(r'"((?:[^"\\]|\\.)*)"')
COMMENT_PREFIXES = ("//", "/*", "*", "///", "<!--", "#")

# Names of the `subscriptions` table, which still exists in the schema
# because dropping it is a destructive migration against a deployed
# database. It is server-owned, never written by the app and never shown.
TABLE_NAME_ONLY = {"subscriptions"}

# A schema file states column defaults as string literals, and one of them
# is the word this check now looks for: `tier text not null default 'free'`.
# That is a value in a column nothing reads, not a sentence anybody sees.
# Scoped to the file rather than allowed everywhere, so a screen that says
# "free" still fails.
SCHEMA_LITERALS = {
    "Migrations.swift": {"free", "pro", "subscriptions"},
}


def source_files():
    for d in SOURCE_DIRS:
        base = ROOT / d
        if not base.is_dir():
            continue
        for f in sorted(base.rglob("*")):
            if f.is_file() and f.suffix in SOURCE_EXTS:
                yield f


def config_files():
    seen = set()
    for pattern in CONFIG_GLOBS:
        for f in sorted(ROOT.glob(pattern)):
            if f.is_file() and f not in seen:
                seen.add(f)
                yield f


def main():
    problems = []
    strings_checked = 0
    files_checked = 0

    for f in list(source_files()) + list(config_files()):
        files_checked += 1
        rel = f.relative_to(ROOT).as_posix()
        text = f.read_text(encoding="utf-8", errors="replace")

        for i, line in enumerate(text.splitlines(), 1):
            if SYMBOLS.search(line):
                problems.append(
                    "%s:%d billing symbol -- %s" % (rel, i, line.strip()[:90])
                )

            if line.lstrip().startswith(COMMENT_PREFIXES):
                continue
            for m in STRING.finditer(line):
                strings_checked += 1
                value = m.group(1)
                if value in TABLE_NAME_ONLY:
                    continue
                if value in SCHEMA_LITERALS.get(f.name, ()):
                    continue
                if FREE_POUR.search(value):
                    continue
                if COPY.search(value):
                    problems.append(
                        "%s:%d copy a user can read -- %r" % (rel, i, value[:90])
                    )

    if problems:
        print("no-paywall FAILED\n", file=sys.stderr)
        for p in problems:
            print("  - %s" % p, file=sys.stderr)
        print(
            "\nThe app is free on every platform. If a paid tier is being added"
            "\nback deliberately, this check is the place to say so.",
            file=sys.stderr,
        )
        return 1

    print(
        "no-paywall ok: %d files, %d on-screen strings, nothing sells anything"
        % (files_checked, strings_checked)
    )
    return 0


if __name__ == "__main__":
    sys.exit(main())
