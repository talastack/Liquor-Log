#!/usr/bin/env python3
"""Validate the shipped spirits catalog.

Sourced is not the same as valid. A citation proves a number came from
somewhere; it does not prove it is right, and a catalog of real-but-wrong rows
is worse than a small one because every downstream calculation inherits the
error in silence.

Most of the rules below are regulation, which makes them checkable rather than
arguable. The CONSTANTS AND THE CLASS VOCABULARY ARE READ FROM THE SWIFT so the
two cannot drift: LiquorEngine/Classification.swift is the authority and this
script asserts the shipped JSON agrees with it. That is the same arrangement
Reef-Ledger uses for its safety clamps -- a remotely-updatable data file is
exactly where a bad value could otherwise arrive without review.

A row that fails is a build failure, not a warning. An incomplete catalog
degrades to typing it in yourself, which the app supports anyway. A wrong
catalog degrades to a wrong proof inside a cost-per-pour figure that nobody
ever checks.
"""

import json
import re
import sys
import unicodedata
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
CATALOG = ROOT / "shared" / "data" / "spirits.v1.json"
ENGINE = ROOT / "IOS" / "Packages" / "LiquorEngine" / "Sources" / "LiquorEngine"
CLASSIFICATION = ENGINE / "Classification.swift"
RECIPE = ENGINE / "RecipeCode.swift"

KEY = re.compile(r"^[a-z0-9]+(-[a-z0-9]+)*$")
PRODUCTION_TYPES = {"singleBarrel", "smallBatch", "blend", "singleCask", "unspecified"}

# Families with no bottling-strength floor, mirroring
# ClassType.minimumBottlingStrength. A 16% vermouth is not under-strength, and
# rejecting it would be the app being wrong with confidence.
# Expressions that name no particular bottling, so they are the same
# product as a row with no expression at all.
GENERIC_EXPRESSIONS = {"", "original", "originale", "classic", "standard"}

NO_FLOOR_FAMILIES = {
    "liqueur", "beer", "cider", "seltzer", "fortified", "eastAsian", "other",
}


def swift_constant(text, name):
    m = re.search(r"static let " + name + r"\s*=\s*ABV\(percent:\s*([0-9.]+)\)", text)
    if m:
        return float(m.group(1))
    m = re.search(r"static let " + name + r"\s*=\s*([0-9]+)", text)
    return int(m.group(1)) if m else None


def swift_class_types(text):
    """Returns (all cases, straight cases, {case: family})."""
    block = text.split("public enum ClassType", 1)
    if len(block) < 2:
        return None, None, None
    body = block[1].split("\n}", 1)[0]

    cases = set(re.findall(r"^\s*case\s+([a-zA-Z]+)\s*$", body, re.MULTILINE))

    straight = set()
    straight_block = body.split("var isStraight", 1)
    if len(straight_block) > 1:
        head = straight_block[1].split("return true", 1)[0]
        straight = set(re.findall(r"\.([a-zA-Z]+)", head))

    # The strength floor is a FAMILY rule, so read which family each class is
    # in rather than restating a list of exemptions here.
    families = {}
    family_block = body.split("public var family: Family", 1)
    if len(family_block) > 1:
        chunk = family_block[1].split("\n    }", 1)[0]
        pattern = re.compile(
            r"case\s+((?:\.[a-zA-Z]+\s*,?\s*)+):\s*\n?\s*return\s+\.([a-zA-Z]+)")
        for cases_text, family in pattern.findall(chunk):
            for name in re.findall(r"\.([a-zA-Z]+)", cases_text):
                families[name] = family

    return cases, straight, families


def swift_class_floors(text):
    """Per-class floors that override the family rule.

    `minimumBottlingStrength` answers from the family for almost every
    class, but several carry their own figure: TTB's flavoured spirits
    are bottled at 30%, cachaca at 38%, grappa at 37.5%, the agave
    classes at 35% under NOM, jenever at 30% in the EU. Read them out of
    the engine rather than keeping a second list here that can disagree
    with the app somebody is holding.
    """
    floors = {}
    block = text.split("public var minimumBottlingStrength", 1)
    if len(block) < 2:
        return floors
    head = block[1].split("switch family", 1)[0]
    # One case or a list of them, over one line or two, so the whole
    # list is captured rather than only its first name.
    pattern = re.compile(
        r"case\s+((?:\.[a-zA-Z]+\s*,?\s*)+):\s*\n?\s*return\s+ABV\(percent:\s*([0-9.]+)\)")
    for names, percent in pattern.findall(head):
        for name in re.findall(r"\.([a-zA-Z]+)", names):
            floors[name] = float(percent)
    return floors


def swift_recipe_codes(text):
    letters = re.findall(r'case\s+([a-z])\s*=\s*"([A-Z])"', text)
    if len(letters) < 7:
        return None
    mashbills = [upper for _, upper in letters[:2]]
    yeasts = [upper for _, upper in letters[2:]]
    return {"O" + m + "S" + y for m in mashbills for y in yeasts}


def stale_doc_counts(total):
    """Docs that state the catalogue's size, and disagree with it.

    Three of them said "534 products" while the file held 793. A number
    written once into prose is outlived by the data it describes, quietly,
    and the reader has no way to tell which of the two is wrong.
    """
    stale = []
    for path in sorted((ROOT / "docs").glob("*.md")):
        text = path.read_text(encoding="utf-8")
        for match in re.finditer(r"(?<![0-9])([0-9]{3,4}) (?:products|rows)", text):
            if int(match.group(1)) != total:
                line = text[:match.start()].count(chr(10)) + 1
                stale.append((path.relative_to(ROOT).as_posix(), line, match.group(1)))
    return stale


def fold(text):
    """Accent- and punctuation-insensitive, the way both engines match."""
    text = unicodedata.normalize("NFD", text)
    text = "".join(c for c in text if unicodedata.category(c) != "Mn")
    # "&" and "and" are the same word on a label, and the difference hid a
    # duplicate Copper & Kings for weeks.
    text = text.lower().replace("&", " and ")
    return re.sub(r"[^a-z0-9]+", " ", text).strip()


def generic_expression(text):
    """An empty expression and a generic one name the same bottle.

    "Absolut" and "Absolut Original" are one product; so are "Skyy" and
    "Skyy Original". Folding those together is what catches the pair.
    """
    folded = fold(text)
    return "" if folded in GENERIC_EXPRESSIONS else folded


def main():
    for path in (CATALOG, CLASSIFICATION, RECIPE):
        if not path.exists():
            print("missing: %s" % path, file=sys.stderr)
            return 1

    classification = CLASSIFICATION.read_text(encoding="utf-8")
    bond_abv = swift_constant(classification, "bottledInBondABV")
    min_abv = swift_constant(classification, "americanMinimumABV")
    straight_years = swift_constant(classification, "straightMinimumYears")
    bond_years = swift_constant(classification, "bottledInBondMinimumYears")
    class_types, straight_types, families = swift_class_types(classification)
    valid_codes = swift_recipe_codes(RECIPE.read_text(encoding="utf-8"))

    missing = [name for name, value in [
        ("bottledInBondABV", bond_abv), ("americanMinimumABV", min_abv),
        ("straightMinimumYears", straight_years),
        ("bottledInBondMinimumYears", bond_years),
        ("ClassType cases", class_types), ("ClassType families", families),
        ("recipe codes", valid_codes),
    ] if not value]
    if missing:
        print("could not read from the engine: %s" % ", ".join(missing), file=sys.stderr)
        return 1

    class_floors = swift_class_floors(classification)

    def strength_floor(class_type):
        """The floor for this class, or None when it has none."""
        if class_type in class_floors:
            return class_floors[class_type]
        if families.get(class_type, "other") in NO_FLOOR_FAMILIES:
            return None
        return min_abv

    try:
        catalog = json.loads(CATALOG.read_text(encoding="utf-8"))
    except json.JSONDecodeError as exc:
        print("catalog is not valid JSON: %s" % exc, file=sys.stderr)
        return 1

    problems = []
    seen_ids = set()
    seen_products = set()
    verified = 0

    for product in catalog.get("products", []):
        pid = product.get("id", "")
        where = pid or "<no id>"

        if not KEY.match(pid):
            problems.append("%s: id must be lowercase and hyphenated" % where)
        if pid in seen_ids:
            problems.append("%s: duplicate id" % where)
        seen_ids.add(pid)

        for field in ("distillery", "brand"):
            if not product.get(field):
                problems.append("%s: missing %s" % (where, field))

        # Accents, punctuation and a generic expression all hid duplicates.
        # The catalogue carried Bacardi Superior twice, Absolut twice and
        # Copper & Kings twice, because the raw triple reads Bacardi and
        # Bacardi as different producers, and an empty expression as a
        # different bottle from "Original". Two rows for one bottle means
        # the shelf check answers a question twice.
        identity = (fold(product.get("distillery", "")),
                    fold(product.get("brand", "")),
                    generic_expression(product.get("expression", "")))
        if identity in seen_products:
            problems.append(
                "%s: duplicate product %s -- the shelf check must return one"
                " answer, not two" % (where, identity))
        seen_products.add(identity)

        class_type = product.get("class_type")
        if class_type not in class_types:
            problems.append("%s: class_type %r is not a ClassType case" % (where, class_type))
            continue

        production = product.get("production_type", "unspecified")
        if production not in PRODUCTION_TYPES:
            problems.append("%s: production_type %r is unknown" % (where, production))

        abv = product.get("abv")
        barrel_proof = bool(product.get("is_barrel_proof"))
        bonded = bool(product.get("is_bottled_in_bond"))
        age = product.get("stated_age_years")

        # A barrel-proof release is a different strength every batch. A catalog
        # claiming one number is wrong for almost every bottle on the shelf.
        if barrel_proof and abv is not None:
            problems.append(
                "%s: barrel proof must have abv null -- strength changes every batch "
                "and the user reads it off the label" % where)

        if abv is not None:
            if not (0.5 < abv <= 95.0):
                problems.append("%s: abv %s is outside 0.5-95" % (where, abv))
            floor = strength_floor(class_type)
            if floor is not None and abv < floor:
                problems.append(
                    "%s: %s bottles at no less than %s%% ABV; got %s"
                    % (where, class_type, floor, abv))
            if bonded and abv != bond_abv:
                problems.append(
                    "%s: bottled in bond is exactly %s%% ABV; got %s"
                    % (where, bond_abv, abv))
        elif not barrel_proof:
            problems.append(
                "%s: no abv and not marked barrel proof -- state the strength or say "
                "why it varies" % where)

        if bonded:
            if families.get(class_type) == "whiskey" and class_type not in straight_types:
                problems.append(
                    "%s: a bottled in bond whiskey is a straight whiskey; got %s"
                    % (where, class_type))
            if age is not None and age < bond_years:
                problems.append(
                    "%s: bottled in bond requires %d years; got %s"
                    % (where, bond_years, age))

        # A price with no provenance is a number nobody can check, so it may
        # not be stored -- the same rule the Postgres constraint enforces on
        # user-entered products.
        msrp = product.get("msrp_cents")
        if msrp is not None:
            if not product.get("msrp_source"):
                problems.append(
                    "%s: msrp_cents needs msrp_source -- a price with no named "
                    "source cannot be shown to the user" % where)
            if msrp < 0:
                problems.append("%s: msrp_cents is negative" % where)

        # An allocation count with no named board is a number nobody can
        # check. Same rule as msrp.
        bottles = product.get("allocation_bottles")
        if bottles is not None:
            if not product.get("allocation_source"):
                problems.append(
                    "%s: allocation_bottles needs allocation_source" % where)
            if bottles < 0:
                problems.append("%s: allocation_bottles is negative" % where)
            entries = product.get("allocation_entries")
            if entries is not None and entries < 0:
                problems.append("%s: allocation_entries is negative" % where)

        if class_type in straight_types and age is not None and age < straight_years:
            problems.append(
                "%s: straight requires %d years; got %s" % (where, straight_years, age))

        code = product.get("recipe_code")
        if code and code not in valid_codes:
            problems.append(
                "%s: recipe_code %r is not one of the ten valid codes" % (where, code))

        if not product.get("source"):
            problems.append("%s: no source -- a number nobody can check is not data" % where)
        if product.get("verified"):
            verified += 1
            if not product.get("source_url"):
                problems.append("%s: marked verified but has no source_url" % where)

    for where, line, stated in stale_doc_counts(len(catalog.get("products", []))):
        problems.append(
            "%s:%d says %s products; the catalogue holds %d"
            % (where, line, stated, len(catalog.get("products", [])))
        )

    if problems:
        print("catalog FAILED\n", file=sys.stderr)
        for problem in problems:
            print("  - %s" % problem, file=sys.stderr)
        print("\n%d problem(s)." % len(problems), file=sys.stderr)
        return 1

    total = len(catalog.get("products", []))
    by_family = {}
    for product in catalog.get("products", []):
        family = families.get(product["class_type"], "other")
        by_family[family] = by_family.get(family, 0) + 1

    print("catalog ok: %d products, %d verified against a source url" % (total, verified))
    for family in sorted(by_family, key=lambda f: -by_family[f]):
        print("  %-10s %d" % (family, by_family[family]))
    if verified < total:
        print("  NOTE: %d rows still need COLA verification before release."
              % (total - verified))
    return 0


if __name__ == "__main__":
    sys.exit(main())
