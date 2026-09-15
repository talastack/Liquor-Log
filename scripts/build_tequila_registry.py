#!/usr/bin/env python3
"""Builds shared/data/tequila-nom.v1.json from the CRT's public registry.

The Consejo Regulador del Tequila publishes every authorised producer with
its NOM number and the brands registered against it, as one HTML page at
https://www.crt.org.mx/en/brands-and-associates/ . This reads that page
(a saved copy, or fetched with --fetch) and writes one entry per NOM: the
company, and the brand names as the CRT lists them.

Nothing is edited by hand. Re-run when the registry changes; the checker
keeps the bundled copy identical to the canonical one.
"""
import collections
import html
import json
import re
import sys
import urllib.request
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
OUT = ROOT / "shared" / "data" / "tequila-nom.v1.json"
SOURCE = "https://www.crt.org.mx/en/brands-and-associates/"


def rows_from(page: str):
    for tr in re.findall(r"<tr[^>]*>(.*?)</tr>", page, re.S):
        cells = [html.unescape(re.sub(r"<[^>]+>", "", c)).strip()
                 for c in re.findall(r"<td[^>]*>(.*?)</td>", tr, re.S)]
        # Company, address, NOM, DOT, brand -- the producers table. The other
        # tables on the page have different widths and are skipped.
        if len(cells) == 5 and re.fullmatch(r"\d{4}", cells[2]):
            yield cells[0], cells[2], cells[4]


def tidy(name: str) -> str:
    return re.sub(r"\s+", " ", name).strip()


def main(argv):
    if "--fetch" in argv:
        page = urllib.request.urlopen(SOURCE, timeout=60).read().decode("utf-8", "ignore")
    else:
        path = next((a for a in argv[1:] if not a.startswith("--")), None)
        if not path:
            print("usage: build_tequila_registry.py <saved crt page.html> | --fetch", file=sys.stderr)
            return 2
        page = Path(path).read_text(encoding="utf-8", errors="ignore")

    by_nom = collections.OrderedDict()
    for company, nom, brand in rows_from(page):
        entry = by_nom.setdefault(nom, {"nom": nom, "company": tidy(company), "brands": []})
        brand = tidy(brand)
        if brand and brand not in entry["brands"]:
            entry["brands"].append(brand)

    entries = sorted(by_nom.values(), key=lambda e: e["nom"])
    for e in entries:
        e["brands"].sort()
    doc = {
        "version": 1,
        "source": SOURCE,
        "note": "Consejo Regulador del Tequila, public registry of authorised producers and their registered brands. Company and brand names as the CRT lists them.",
        "producers": entries,
    }
    OUT.write_text(json.dumps(doc, ensure_ascii=False, indent=1) + "\n", encoding="utf-8")
    print("wrote %s: %d producers, %d brands" % (
        OUT.name, len(entries), sum(len(e["brands"]) for e in entries)))
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
