#!/usr/bin/env python3
"""Validate the shipped flavour wheel.

Two jobs.

STRUCTURE. Descriptor keys are stored in `tasting_notes.descriptor_key` and are
therefore permanent. A duplicate key makes a stored note ambiguous; a renamed
key orphans every note that used it. This script is what stops either reaching
a build.

PROVENANCE. Every descriptor must carry an `origin`. That field is the axis the
taxonomy is organised on, and it is the evidence that the wheel was derived from
where flavours come from rather than copied from a published diagram. See
docs/06-flavour-wheel-provenance.md. A descriptor with no origin is not just
incomplete data -- it is a hole in that argument.

Exit 0 when clean, 1 with a report otherwise.
"""

import json
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
WHEEL = ROOT / "shared" / "data" / "flavor-wheel.v1.json"
SWIFT_ORIGINS = (ROOT / "IOS" / "Packages" / "LiquorEngine" / "Sources"
                 / "LiquorEngine" / "FlavorWheel.swift")

KEY = re.compile(r"^[a-z0-9]+(-[a-z0-9]+)*$")


def swift_origin_cases():
    """The FlavorOrigin cases the engine will actually decode."""
    text = SWIFT_ORIGINS.read_text(encoding="utf-8")
    block = text.split("public enum FlavorOrigin", 1)
    if len(block) < 2:
        return None
    body = block[1].split("}", 1)[0]
    return set(re.findall(r"^\s*case\s+([a-z][A-Za-z]*)\s*$", body, re.MULTILINE))


def main():
    if not WHEEL.exists():
        print("missing: %s" % WHEEL, file=sys.stderr)
        return 1

    try:
        wheel = json.loads(WHEEL.read_text(encoding="utf-8"))
    except json.JSONDecodeError as exc:
        print("flavour wheel is not valid JSON: %s" % exc, file=sys.stderr)
        return 1

    problems = []

    for field in ("version", "name", "families", "origins", "provenance"):
        if field not in wheel:
            problems.append("top level is missing %r" % field)
    if problems:
        for p in problems:
            print("  - %s" % p, file=sys.stderr)
        return 1

    declared_origins = {o["key"] for o in wheel["origins"]}

    # The JSON and the Swift enum have to agree, or a perfectly good data file
    # fails to decode on device with no useful message.
    swift = swift_origin_cases()
    if swift is None:
        problems.append("could not read FlavorOrigin from %s" % SWIFT_ORIGINS.name)
    else:
        for missing in sorted(declared_origins - swift):
            problems.append(
                "origin %r is in the data but not in Swift FlavorOrigin -- the file "
                "would fail to decode" % missing)
        for unused in sorted(swift - declared_origins):
            problems.append(
                "Swift FlavorOrigin has %r but the data does not declare it" % unused)

    seen_descriptors = {}
    seen_families = set()
    descriptor_count = 0

    for family in wheel["families"]:
        fkey = family.get("key", "")
        if not KEY.match(fkey):
            problems.append("family key %r must be lowercase and hyphenated" % fkey)
        if fkey in seen_families:
            problems.append("duplicate family key %r" % fkey)
        seen_families.add(fkey)

        if not family.get("label"):
            problems.append("family %r has no label" % fkey)

        descriptors = family.get("descriptors") or []
        if not descriptors:
            problems.append(
                "family %r has no descriptors and would render an empty tray" % fkey)

        for d in descriptors:
            descriptor_count += 1
            key = d.get("key", "")

            if not KEY.match(key):
                problems.append(
                    "descriptor key %r must be lowercase and hyphenated: keys are "
                    "stored in tasting notes and can never change" % key)
            if key in seen_descriptors:
                problems.append(
                    "descriptor %r appears in both %r and %r -- a stored note would "
                    "be ambiguous" % (key, seen_descriptors[key], fkey))
            seen_descriptors[key] = fkey

            if not d.get("label"):
                problems.append("descriptor %r has no label" % key)

            origin = d.get("origin")
            if not origin:
                problems.append(
                    "descriptor %r has no origin -- origin is the axis this taxonomy "
                    "is organised on and the evidence it is our own" % key)
            elif origin not in declared_origins:
                problems.append(
                    "descriptor %r has origin %r, which is not declared" % (key, origin))

            # A chemical claim we cannot stand behind is worse than none.
            if d.get("compound") and not d.get("why"):
                problems.append(
                    "descriptor %r names a compound but does not say why -- state the "
                    "mechanism or drop the compound" % key)

    if problems:
        print("flavour wheel FAILED\n", file=sys.stderr)
        for p in problems:
            print("  - %s" % p, file=sys.stderr)
        print("\n%d problem(s)." % len(problems), file=sys.stderr)
        return 1

    by_origin = {}
    for family in wheel["families"]:
        for d in family["descriptors"]:
            by_origin[d["origin"]] = by_origin.get(d["origin"], 0) + 1

    print("flavour wheel ok: %d families, %d descriptors"
          % (len(wheel["families"]), descriptor_count))
    for origin in sorted(by_origin):
        print("  %-14s %d" % (origin, by_origin[origin]))
    return 0


if __name__ == "__main__":
    sys.exit(main())
