#!/usr/bin/env python3
"""Turn a state control board's published price list into cited MSRP data.

    # 1. See what is actually in the file you downloaded
    python3 scripts/import_price_list.py inspect --file ~/Downloads/va-abc.csv

    # 2. Map the columns you saw, and dry-run the match
    python3 scripts/import_price_list.py match --board virginia-abc \\
        --file ~/Downloads/va-abc.csv --name-column "Product" --price-column "Price"

    # 3. Write it, once the report looks right
    python3 scripts/import_price_list.py match --board virginia-abc \\
        --file ~/Downloads/va-abc.csv --name-column "Product" --price-column "Price" \\
        --write

WHY THIS IS NOT A FETCHER.

There is no MSRP API. MSRP is not published centrally: TTB records LABELS, not
prices, and producers state a suggested retail in press releases at best. The
only free, legal, stable price data in the US is the price lists the ~17 control
states publish as public records -- Virginia ABC, Oregon OLCC, Pennsylvania
PLCB, North Carolina, Idaho, New Hampshire, Utah.

Those are published FILES, not feeds, and that suits this app: a snapshot ships
with the build, so a price question is answerable in a shop basement with no
signal. A live API call would break the offline promise exactly where it counts.

WHAT A CONTROL-STATE PRICE IS, AND IS NOT.

It is THAT STATE'S posted shelf price. It is not a national MSRP and it is not a
resale value. Virginia's price for a bottle is not what a Kentucky shop charges.
So every figure written here carries the board's name and the year, and the app
prints them beside the number -- see PriceReference.

THE RULE THIS SCRIPT EXISTS TO ENFORCE: NEVER GUESS A MATCH.

A price attached to the wrong bottle is worse than no price, because nobody can
tell by looking. Anything short of a confident match is reported for a human
rather than written, and the report is the normal output -- --write is opt-in.

NOTHING THIS SCRIPT PRODUCES SHIPS BY DEFAULT.

17 U.S.C. 105 removes copyright from FEDERAL works. It does not apply to the
states, and a state may assert rights in its own publications. In practice
these lists are public records that get republished constantly -- but "in
practice" is not a licence, and the standing instruction on this project is to
avoid legal issues rather than argue them.

So --write is gated behind --licence-checked, which exists to make importing a
DECISION rather than a default. Read that board's terms first, and prefer a
board publishing under an explicit open-data policy.

The app is complete without any of this. The price comparison runs on the
user's own record -- what they paid, and what they saw on the shelf -- which is
their data, needs no licence, and cannot go stale in a way that misleads
anybody. See PriceHistory. This importer is an optional extra for somebody who
has done the legal work, not a dependency.
"""

import argparse
import csv
import json
import re
import sys
import unicodedata
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
CATALOG = ROOT / "shared" / "data" / "spirits.v1.json"
PRICES = ROOT / "shared" / "data" / "prices"

# Boards known to publish a price list as a public record. `source` is the
# string the app shows the user verbatim, so it names the board, not the file.
BOARDS = {
    # Verified 2026-09-10 by fetching each board's own pages. See
    # docs/05-data-sourcing.md for the terms found on each, and the section
    # "where a lawyer is needed" -- silence and "All Rights Reserved" are not
    # licences, and nothing below is cleared for shipping by this file.
    "virginia-abc": {
        "source": "Virginia ABC",
        "home": "https://www.abc.virginia.gov/products/products-faqs/product-downloads",
        "file": "https://www.abc.virginia.gov/library/products/other-documents/"
                "quarterly-price-list-july--september-2026.xlsx",
        "format": "xlsx, quarterly; also a PDF. Convert to CSV first.",
        "terms": "SILENT. No terms of use exists; only a privacy policy. robots.txt "
                 "permits the price files and disallows the live catalogue API.",
    },
    "oregon-olcc": {
        "source": "Oregon OLCC",
        "home": "https://data.oregon.gov/Business/OLCC-Monthly-Pricing/vmf2-f83h",
        "file": "https://data.oregon.gov/api/v3/views/vmf2-f83h/export.csv?accessType=DOWNLOAD",
        "format": "csv, monthly, ~263,000 rows. The cleanest bulk source of the three.",
        "terms": "SILENT. Socrata dataset with NO licence field; the only assertion is "
                 "'All Rights Reserved' on the search site.",
    },
    "pennsylvania-plcb": {
        "source": "Pennsylvania PLCB",
        "home": "https://www.pa.gov/agencies/lcb/supplier-vendors/"
                "wine-and-spirits-suppliers/item-catalogs",
        "file": "https://www.apps.lcb.pa.gov/webapp/reports/Wholesale_Spirits_Catalog_Full.xlsx",
        "format": "xlsx wholesale catalogue with a published field dictionary. "
                  "Convert to CSV first.",
        "terms": "SPLIT. The pa.gov catalogues carry no terms at all. "
                 "finewineandgoodspirits.com EXPRESSLY PROHIBITS commercial use and "
                 "scraping -- never import from that domain.",
    },
    "north-carolina-abc": {
        "source": "North Carolina ABC",
        "home": "https://abc.nc.gov/Pricing/PriceList",
        "terms": "Not yet checked.",
    },
    "idaho-isldd": {
        "source": "Idaho State Liquor Division",
        "home": "https://liquor.idaho.gov",
        "terms": "Not yet checked.",
    },
    "new-hampshire-nhlc": {
        "source": "New Hampshire Liquor Commission",
        "home": "https://www.liquorandwine.com",
        "terms": "Not yet checked.",
    },
    "utah-dabs": {
        "source": "Utah DABS",
        "home": "https://abs.utah.gov",
        "terms": "Not yet checked.",
    },
}

# Words that say nothing about which bottle this is. Dropped before matching so
# "Elijah Craig Small Batch Bourbon 750ML" and "Elijah Craig Small Batch" agree.
NOISE = {
    "whiskey", "whisky", "bourbon", "straight", "kentucky", "tennessee",
    "rye", "the", "brand", "co", "company", "distillery", "distilling",
    # "l" is deliberately absent: it is the middle initial in "W L Weller",
    # and the SIZE pattern already removes "750 l" and "1 litre".
    "ml", "liter", "litre", "pk", "pack", "btl", "bottle", "case",
    "proof", "yr", "year", "years", "old", "aged",
}

SIZE = re.compile(r"\b\d{2,4}\s?(ml|l|ltr|liter|litre)\b", re.I)
PROOF = re.compile(r"\b\d{2,3}(\.\d)?\s?(proof|pf)\b", re.I)
MONEY = re.compile(r"[-+]?\d[\d,]*\.?\d*")


def normalise(text):
    """A comparable key: accents folded, punctuation gone, noise words removed."""
    text = unicodedata.normalize("NFKD", text or "")
    text = "".join(c for c in text if not unicodedata.combining(c))
    # Apostrophes are DELETED, not replaced with a space. A price list writes
    # "Jeffersons" and the catalogue writes "Jefferson's"; turning the second
    # into "jefferson s" makes every possessive brand miss -- Blanton's,
    # Booker's, Baker's, Rowan's Creek.
    text = re.sub(r"[\u2018\u2019']", "", text)
    text = SIZE.sub(" ", text)
    text = PROOF.sub(" ", text)
    text = re.sub(r"[^a-z0-9 ]+", " ", text.lower())
    words = [w for w in text.split() if w and w not in NOISE]
    return " ".join(words)


def cents(raw):
    """Dollars as written on a price list -> integer cents. None if unreadable."""
    if raw is None:
        return None
    match = MONEY.search(str(raw).replace(",", ""))
    if not match:
        return None
    try:
        value = float(match.group(0))
    except ValueError:
        return None
    if value <= 0:
        return None
    return int(round(value * 100))


def read_rows(path):
    """Rows from a CSV or TSV. Deliberately not PDF or XLS.

    A board that only publishes PDF needs converting first (`pdftotext -layout`,
    or opening the XLS and saving as CSV). Parsing a PDF layout heuristically is
    exactly the kind of silent-wrongness this script exists to avoid.
    """
    text = path.read_text(encoding="utf-8-sig", errors="replace")
    sample = text[:8192]
    try:
        dialect = csv.Sniffer().sniff(sample, delimiters=",\t;|")
    except csv.Error:
        dialect = csv.excel
    return list(csv.DictReader(text.splitlines(), dialect=dialect))


def load_catalog():
    return json.loads(CATALOG.read_text(encoding="utf-8"))


def catalog_index(catalog):
    """{normalised name: [product, ...]}, so a collision is visible not silent."""
    index = {}
    for product in catalog["products"]:
        full = " ".join(
            part for part in (product.get("brand"), product.get("expression")) if part)
        key = normalise(full)
        if key:
            index.setdefault(key, []).append(product)
    return index


def near_misses(key, index):
    """Catalogue ids whose words are wholly contained in this listing's words.

    Deliberately one-directional and deliberately not fuzzy. Edit distance
    would happily pair "Weller 12 Year" with "Weller Full Proof"; requiring the
    catalogue name to be a strict subset of the listing name only tolerates a
    listing carrying EXTRA words, which is the failure that actually happens.
    """
    words = set(key.split())
    if not words:
        return []
    hits = []
    for candidate, products in index.items():
        parts = set(candidate.split())
        if len(parts) < 2:
            continue
        if parts <= words or words <= parts:
            hits.extend(p["id"] for p in products)
    return sorted(set(hits))


def cmd_inspect(args):
    path = Path(args.file).expanduser()
    if not path.exists():
        print("no such file: %s" % path, file=sys.stderr)
        return 1

    rows = read_rows(path)
    if not rows:
        print("no rows parsed -- is this a CSV? PDF and XLS need converting "
              "first, see the note in read_rows()", file=sys.stderr)
        return 1

    print("%d rows" % len(rows))
    print("\ncolumns:")
    for column in rows[0].keys():
        values = [r.get(column) for r in rows[:5]]
        shown = ", ".join(repr(v)[:28] for v in values if v)
        print("  %-32s %s" % (column, shown))

    print("\nPick the column holding the PRODUCT NAME and the one holding the")
    print("PRICE, then run:  match --name-column ... --price-column ...")
    return 0


def cmd_match(args):
    board = BOARDS.get(args.board)
    if not board:
        print("unknown board %r. known: %s"
              % (args.board, ", ".join(sorted(BOARDS))), file=sys.stderr)
        return 1

    path = Path(args.file).expanduser()
    if not path.exists():
        print("no such file: %s" % path, file=sys.stderr)
        return 1

    rows = read_rows(path)
    if not rows:
        print("no rows parsed", file=sys.stderr)
        return 1

    for column in (args.name_column, args.price_column):
        if column not in rows[0]:
            print("column %r is not in the file. Run `inspect` to see what is."
                  % column, file=sys.stderr)
            return 1

    catalog = load_catalog()
    index = catalog_index(catalog)

    matched = {}
    ambiguous = []
    probable = []
    unpriced = 0
    unmatched = 0

    for row in rows:
        name = (row.get(args.name_column) or "").strip()
        price = cents(row.get(args.price_column))
        if not name:
            continue
        if price is None:
            unpriced += 1
            continue

        key = normalise(name)
        candidates = index.get(key, [])

        if not candidates:
            # Not an exact key. Before giving up, look for a catalogue entry
            # whose words are a subset of this listing's -- "Weller Special
            # Reserve" against "W L Weller Special Reserve". Reported for a
            # human, NEVER written: a price on the wrong bottle is worse than
            # no price, because nobody can tell by looking.
            near = near_misses(key, index)
            if len(near) == 1:
                probable.append((name, near[0], price))
            else:
                unmatched += 1
            continue

        # More than one catalogue row normalising the same way means we cannot
        # tell which bottle this price belongs to. Report it; never pick one.
        if len(candidates) > 1:
            ambiguous.append((name, [c["id"] for c in candidates]))
            continue

        product = candidates[0]
        previous = matched.get(product["id"])
        if previous is not None and previous["cents"] != price:
            # The same product priced twice in one file, usually two sizes.
            # Without a size column we cannot say which is the 750, so neither
            # is trustworthy.
            ambiguous.append((name, [product["id"] + " (two prices in this file)"]))
            matched.pop(product["id"], None)
            continue

        matched[product["id"]] = {"cents": price, "listed_as": name}

    print("board:      %s" % board["source"])
    print("file:       %s" % path.name)
    print("rows:       %d" % len(rows))
    print("matched:    %d" % len(matched))
    print("probable:   %d  (reported, never written)" % len(probable))
    print("ambiguous:  %d  (reported, never written)" % len(ambiguous))
    print("no price:   %d" % unpriced)
    print("no match:   %d  (in the list, not in our catalogue)" % unmatched)

    if probable:
        print("\nprobable -- confirm by hand, then fix the catalogue name or")
        print("add the listing's wording to the row:")
        for name, pid, price in probable[:20]:
            print("  %-44s -> %-28s %s"
                  % (name[:44], pid, "$%.2f" % (price / 100)))
        if len(probable) > 20:
            print("  ... and %d more" % (len(probable) - 20))

    if ambiguous:
        print("\nambiguous -- resolve by hand or leave out:")
        for name, ids in ambiguous[:20]:
            print("  %-44s -> %s" % (name[:44], ", ".join(ids)))
        if len(ambiguous) > 20:
            print("  ... and %d more" % (len(ambiguous) - 20))

    if not args.write:
        print("\nDry run. Nothing written. Add --write when the report looks right.")
        return 0

    # Deliberately awkward. Importing a state's data is a decision with a legal
    # question attached, and a flag somebody has to type is the cheapest way to
    # stop it happening by habit.
    if not args.licence_checked:
        print(
            "\nRefusing to write.\n\n"
            "  %s publishes this list as a public record, but 17 U.S.C. 105\n"
            "  covers FEDERAL works only and does not extend to the states.\n"
            "  Read this board's terms before shipping its data:\n\n"
            "      %s\n\n"
            "  Then re-run with --licence-checked.\n\n"
            "  The app does not need this. The price comparison already works\n"
            "  from the user's own record -- what they paid, and what they saw\n"
            "  on the shelf -- which needs no licence at all."
            % (board["source"], board["home"]),
            file=sys.stderr)
        return 1

    if not matched:
        print("\nnothing matched, so nothing to write", file=sys.stderr)
        return 1

    PRICES.mkdir(parents=True, exist_ok=True)
    out = PRICES / ("%s.json" % args.board)
    payload = {
        "board": args.board,
        "source": board["source"],
        "home": board["home"],
        "as_of_year": args.year,
        "note": (
            "A posted shelf price for this state, taken from a published price "
            "list. NOT a national MSRP and NOT a resale value. Check this "
            "board's terms before shipping -- 17 U.S.C. 105 does not cover "
            "state works. See docs/05-data-sourcing.md."
        ),
        "prices": {
            pid: {"cents": entry["cents"], "listed_as": entry["listed_as"]}
            for pid, entry in sorted(matched.items())
        },
    }
    out.write_text(
        json.dumps(payload, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")
    print("\nwrote %s: %d prices" % (out.relative_to(ROOT), len(matched)))
    print("Now run: python3 scripts/build_catalog.py")
    return 0


def main():
    parser = argparse.ArgumentParser(description=__doc__.split("\n")[0])
    subs = parser.add_subparsers(dest="command", required=True)

    inspect = subs.add_parser("inspect", help="show the columns in a price list")
    inspect.add_argument("--file", required=True)
    inspect.set_defaults(func=cmd_inspect)

    match = subs.add_parser("match", help="match a price list to the catalogue")
    match.add_argument("--board", required=True, help=", ".join(sorted(BOARDS)))
    match.add_argument("--file", required=True)
    match.add_argument("--name-column", required=True)
    match.add_argument("--price-column", required=True)
    match.add_argument(
        "--year", type=int, required=True,
        help="the year this list was published; shown to the user beside the price")
    match.add_argument(
        "--write", action="store_true",
        help="actually write. Without it this is a dry run and a report.")
    match.add_argument(
        "--licence-checked", action="store_true",
        help="you have read this board's terms and may republish its price list")
    match.set_defaults(func=cmd_match)

    args = parser.parse_args()
    return args.func(args)


if __name__ == "__main__":
    sys.exit(main())
