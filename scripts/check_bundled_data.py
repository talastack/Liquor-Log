#!/usr/bin/env python3
"""Assert the app's copy of the shared data is identical to the canonical one.

shared/data/ is canonical. The app target needs its own copy because Xcode
bundles resources from under IOS/App/, and it cannot reach outside that
directory. Two files that are meant to be identical will drift, and the app
would ship a stale catalog while shared/ looked perfectly correct.
"""

import filecmp
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
CANONICAL = ROOT / "shared" / "data"
BUNDLED = ROOT / "IOS" / "App" / "Resources" / "Data"

FILES = ["spirits.v1.json", "flavor-wheel.v1.json"]


def main():
    problems = []
    for name in FILES:
        a, b = CANONICAL / name, BUNDLED / name
        if not a.exists():
            problems.append("missing canonical %s" % a)
        elif not b.exists():
            problems.append("missing bundled copy %s -- run: cp %s %s" % (b, a, b))
        elif not filecmp.cmp(a, b, shallow=False):
            problems.append(
                "%s differs from %s -- the app would ship the stale one" % (b, a))

    if problems:
        print("bundled data FAILED\n", file=sys.stderr)
        for p in problems:
            print("  - %s" % p, file=sys.stderr)
        return 1

    print("bundled data ok: %d files identical" % len(FILES))
    return 0


if __name__ == "__main__":
    sys.exit(main())
