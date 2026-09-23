#!/usr/bin/env python3
"""Assert both engines know the same classes, and the catalogue only uses them.

`ClassType` is written twice -- once in Swift, once in Kotlin -- and its
storage keys are what travel: they sit in the local database, in the
bundled catalogue, and in the Postgres rows that sync between the two
apps. The two copies are kept in step by hand, which is exactly the kind
of job that goes wrong quietly.

What it costs when it does: a bottle whose class is `port` arrives on a
phone whose engine has never heard of `port`, `fromStorageKey` answers
null, and the bottle loses its class. No crash, no error, no log. It just
silently becomes a bottle that is not anything.

`check_catalog.py` cannot catch this on its own. It reads the case list
out of the SWIFT file, so a class present in Swift and missing in Kotlin
passes every check there is and ships.

Three assertions:

1. The two engines declare the same ClassType storage keys.
2. They declare the same Family keys.
3. Every `class_type` in the shipped catalogue exists in BOTH.

This is the same discipline `check_schema_mirror.py` applies to the
database schema, for the same reason: two hand-maintained copies of one
truth need something that notices when they stop agreeing.
"""

import json
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
SWIFT = ROOT / "IOS/Packages/LiquorEngine/Sources/LiquorEngine/Classification.swift"
KOTLIN = ROOT / "Android/engine/src/main/kotlin/com/talastack/liquorlog/engine/Classification.kt"
CATALOG = ROOT / "shared/data/spirits.v1.json"

# The filter chips are a third hand-mirrored list with storage keys of its
# own, and they are persisted: a saved filter names its kinds by key. A kind
# on one platform and not the other is the same silent failure in a
# different place.
SWIFT_FILTER = ROOT / "IOS/Packages/LiquorEngine/Sources/LiquorEngine/CollectionFilter.swift"
KOTLIN_FILTER = ROOT / "Android/engine/src/main/kotlin/com/talastack/liquorlog/engine/CollectionFilter.kt"


def swift_class_keys(text):
    """`case port` -- the case name IS the storage key, via RawRepresentable."""
    body = text.split("public enum ClassType", 1)[1].split("\n}", 1)[0]
    return set(re.findall(r"^\s*case ([a-zA-Z]+)$", body, re.M))


def swift_family_keys(text):
    """`case whiskey, agave, rum` -- several to a line, over several lines."""
    body = text.split("public enum Family", 1)[1].split("\n        }", 1)[0]
    keys = set()
    for line in re.findall(r"^\s*case ([a-zA-Z, ]+)$", body, re.M):
        keys.update(part.strip() for part in line.split(",") if part.strip())
    return keys


def swift_filter_kinds(text):
    body = text.split("public enum Kind", 1)[1].split("\n        }", 1)[0]
    return set(re.findall(r"^\s*case ([a-zA-Z]+)$", body, re.M))


def kotlin_keys(text, header, end):
    """`PORT("port"),` and `FORTIFIED("fortified", "Fortified wine"),`.

    The quoted key is what matters, not the Kotlin name: SCREAMING_CASE on
    one side and lowerCamelCase on the other is deliberate, and only the
    string in the parentheses ever reaches a database.
    """
    body = text.split(header, 1)[1].split(end, 1)[0]
    return set(re.findall(r'^\s*[A-Z][A-Z_0-9]*\("([a-zA-Z]+)"', body, re.M))


def main():
    for path in (SWIFT, KOTLIN, CATALOG, SWIFT_FILTER, KOTLIN_FILTER):
        if not path.exists():
            print("class parity FAILED\n\n  - missing %s"
                  % path.relative_to(ROOT).as_posix(), file=sys.stderr)
            return 1

    swift = SWIFT.read_text(encoding="utf-8")
    kotlin = KOTLIN.read_text(encoding="utf-8")

    s_class = swift_class_keys(swift)
    k_class = kotlin_keys(kotlin, "enum class ClassType", "\n    ;")
    s_family = swift_family_keys(swift)
    k_family = kotlin_keys(kotlin, "enum class Family", "\n    }")

    problems = []

    if not s_class or not k_class:
        problems.append(
            "could not read the ClassType cases (swift=%d, kotlin=%d) -- the"
            " enum was probably reshaped, so reshape this check with it"
            % (len(s_class), len(k_class))
        )
    if not s_family or not k_family:
        problems.append(
            "could not read the Family cases (swift=%d, kotlin=%d)"
            % (len(s_family), len(k_family))
        )

    s_kind = swift_filter_kinds(SWIFT_FILTER.read_text(encoding="utf-8"))
    k_kind = kotlin_keys(
        KOTLIN_FILTER.read_text(encoding="utf-8"), "enum class Kind",
        "\n\n        val label")
    if not s_kind or not k_kind:
        problems.append(
            "could not read the filter kinds (swift=%d, kotlin=%d)"
            % (len(s_kind), len(k_kind))
        )

    for label, swift_set, kotlin_set in [
        ("ClassType", s_class, k_class),
        ("Family", s_family, k_family),
        ("filter Kind", s_kind, k_kind),
    ]:
        for key in sorted(swift_set - kotlin_set):
            problems.append(
                "%s %r is in the Swift engine and not the Kotlin one" % (label, key))
        for key in sorted(kotlin_set - swift_set):
            problems.append(
                "%s %r is in the Kotlin engine and not the Swift one" % (label, key))

    if s_class and k_class:
        catalog = json.loads(CATALOG.read_text(encoding="utf-8"))
        unknown = {}
        for product in catalog.get("products", []):
            key = product.get("class_type")
            if key and (key not in s_class or key not in k_class):
                unknown.setdefault(key, []).append(product.get("id", "<no id>"))
        for key, ids in sorted(unknown.items()):
            where = "Swift" if key not in s_class else "Kotlin"
            problems.append(
                "the catalogue ships class_type %r, which the %s engine does"
                " not know: %d row(s), e.g. %s"
                % (key, where, len(ids), ids[0])
            )

    if problems:
        print("class parity FAILED\n", file=sys.stderr)
        for problem in problems:
            print("  - %s" % problem, file=sys.stderr)
        print(
            "\nA class one engine does not know does not crash anything. The"
            "\nbottle just quietly stops having a class on that platform.",
            file=sys.stderr,
        )
        return 1

    print("class parity ok: %d classes, %d families and %d filter kinds,"
          " identical on both engines and used by the catalogue"
          % (len(s_class), len(s_family), len(s_kind)))
    return 0


if __name__ == "__main__":
    sys.exit(main())
