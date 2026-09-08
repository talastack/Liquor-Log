#!/usr/bin/env python3
"""Authoring tool for shared/data/spirits.v1.json.

    python3 scripts/build_catalog.py

The table below is the editable source; the JSON is what ships. Editing a
hundred-odd products as raw JSON invites a misplaced comma and a bad proof, and
a bad proof propagates into every cost-per-pour figure downstream.

DEPTH IS DELIBERATE. The app launches on bourbon, so American whiskey is covered
properly and the other families carry enough entries to prove the structure
branches. Adding a category later means adding rows here, not reshaping
anything.

EVERY ROW IS verified=False. These are stable, widely-published product facts,
used so the app works end to end. Each still needs checking against the TTB COLA
registry before release, and check_catalog.py refuses a row claiming verified
without a source_url.

abv=None means the strength genuinely varies by release -- barrel proof, cask
strength. A catalog claiming one number for those would be wrong for almost
every bottle on almost every shelf.
"""

import json
import sys
from pathlib import Path

OUT = Path(__file__).resolve().parent.parent / "shared" / "data" / "spirits.v1.json"

BP = "barrel_proof"
BIB = "bottled_in_bond"

# (id, distillery, brand, expression, class_type, production, abv, age, flags, mashbill)
ROWS = [
    # ---------------------------------------------------------------- Heaven Hill
    ("ec-small-batch", "Heaven Hill", "Elijah Craig", "Small Batch", "kentuckyStraightBourbon", "smallBatch", 47.0, None, [], None),
    ("ec-barrel-proof", "Heaven Hill", "Elijah Craig", "Barrel Proof", "kentuckyStraightBourbon", "smallBatch", None, None, [BP], None),
    ("ec-18-year", "Heaven Hill", "Elijah Craig", "18 Year", "kentuckyStraightBourbon", "singleBarrel", 45.0, 18, [], None),
    ("ec-toasted-barrel", "Heaven Hill", "Elijah Craig", "Toasted Barrel", "kentuckyStraightBourbon", "smallBatch", 47.0, None, [], None),
    ("henry-mckenna-10", "Heaven Hill", "Henry McKenna", "10 Year Single Barrel", "kentuckyStraightBourbon", "singleBarrel", 50.0, 10, [BIB], None),
    ("evan-williams-black", "Heaven Hill", "Evan Williams", "Black Label", "kentuckyStraightBourbon", "unspecified", 43.0, None, [], None),
    ("evan-williams-bib", "Heaven Hill", "Evan Williams", "Bottled in Bond", "kentuckyStraightBourbon", "unspecified", 50.0, 4, [BIB], None),
    ("evan-williams-single-barrel", "Heaven Hill", "Evan Williams", "Single Barrel", "kentuckyStraightBourbon", "singleBarrel", 43.3, None, [], None),
    ("larceny-small-batch", "Heaven Hill", "Larceny", "Small Batch", "kentuckyStraightBourbon", "smallBatch", 46.0, None, [], "wheated"),
    ("larceny-barrel-proof", "Heaven Hill", "Larceny", "Barrel Proof", "kentuckyStraightBourbon", "smallBatch", None, None, [BP], "wheated"),
    ("old-fitzgerald-bib", "Heaven Hill", "Old Fitzgerald", "Bottled in Bond", "kentuckyStraightBourbon", "unspecified", 50.0, 8, [BIB], "wheated"),
    ("heaven-hill-bib-7", "Heaven Hill", "Heaven Hill", "Bottled in Bond 7 Year", "kentuckyStraightBourbon", "unspecified", 50.0, 7, [BIB], None),
    ("rittenhouse-rye-bib", "Heaven Hill", "Rittenhouse", "Rye Bottled in Bond", "straightRye", "unspecified", 50.0, 4, [BIB], None),
    ("pikesville-rye", "Heaven Hill", "Pikesville", "Straight Rye", "straightRye", "unspecified", 55.0, 6, [], None),

    # -------------------------------------------------------------- Buffalo Trace
    ("buffalo-trace", "Buffalo Trace", "Buffalo Trace", "", "kentuckyStraightBourbon", "unspecified", 45.0, None, [], None),
    ("eagle-rare-10", "Buffalo Trace", "Eagle Rare", "10 Year", "kentuckyStraightBourbon", "unspecified", 45.0, 10, [], None),
    ("weller-special-reserve", "Buffalo Trace", "W L Weller", "Special Reserve", "kentuckyStraightBourbon", "unspecified", 45.0, None, [], "wheated"),
    ("weller-antique-107", "Buffalo Trace", "W L Weller", "Antique 107", "kentuckyStraightBourbon", "unspecified", 53.5, None, [], "wheated"),
    ("weller-12", "Buffalo Trace", "W L Weller", "12 Year", "kentuckyStraightBourbon", "unspecified", 45.0, 12, [], "wheated"),
    ("blantons-single-barrel", "Buffalo Trace", "Blanton's", "Original Single Barrel", "kentuckyStraightBourbon", "singleBarrel", 46.5, None, [], None),
    ("eh-taylor-small-batch", "Buffalo Trace", "E.H. Taylor", "Small Batch", "kentuckyStraightBourbon", "smallBatch", 50.0, 4, [BIB], None),
    ("eh-taylor-single-barrel", "Buffalo Trace", "E.H. Taylor", "Single Barrel", "kentuckyStraightBourbon", "singleBarrel", 50.0, 4, [BIB], None),
    ("sazerac-rye", "Buffalo Trace", "Sazerac", "Straight Rye", "straightRye", "unspecified", 45.0, None, [], None),
    ("ancient-age", "Buffalo Trace", "Ancient Age", "", "kentuckyStraightBourbon", "unspecified", 40.0, None, [], None),
    ("benchmark-old-no-8", "Buffalo Trace", "Benchmark", "Old No. 8", "kentuckyStraightBourbon", "unspecified", 40.0, None, [], None),

    # --------------------------------------------------------------- Wild Turkey
    ("wild-turkey-101", "Wild Turkey", "Wild Turkey", "101", "kentuckyStraightBourbon", "unspecified", 50.5, None, [], None),
    ("wild-turkey-rare-breed", "Wild Turkey", "Wild Turkey", "Rare Breed", "kentuckyStraightBourbon", "smallBatch", None, None, [BP], None),
    ("wild-turkey-101-rye", "Wild Turkey", "Wild Turkey", "101 Rye", "straightRye", "unspecified", 50.5, None, [], None),
    ("wild-turkey-longbranch", "Wild Turkey", "Wild Turkey", "Longbranch", "kentuckyStraightBourbon", "unspecified", 43.0, None, [], None),
    ("russells-reserve-10", "Wild Turkey", "Russell's Reserve", "10 Year", "kentuckyStraightBourbon", "smallBatch", 45.0, 10, [], None),
    ("russells-reserve-single-barrel", "Wild Turkey", "Russell's Reserve", "Single Barrel", "kentuckyStraightBourbon", "singleBarrel", 55.0, None, [], None),

    # ------------------------------------------------------------------ Jim Beam
    ("knob-creek-9", "Jim Beam", "Knob Creek", "9 Year", "kentuckyStraightBourbon", "smallBatch", 50.0, 9, [], None),
    ("knob-creek-single-barrel", "Jim Beam", "Knob Creek", "Single Barrel Reserve", "kentuckyStraightBourbon", "singleBarrel", 60.0, None, [], None),
    ("knob-creek-rye", "Jim Beam", "Knob Creek", "Straight Rye", "straightRye", "smallBatch", 50.0, None, [], None),
    ("bookers", "Jim Beam", "Booker's", "", "kentuckyStraightBourbon", "smallBatch", None, None, [BP], None),
    ("bakers-7", "Jim Beam", "Baker's", "7 Year Single Barrel", "kentuckyStraightBourbon", "singleBarrel", 53.5, 7, [], None),
    ("basil-hayden", "Jim Beam", "Basil Hayden", "", "kentuckyStraightBourbon", "unspecified", 40.0, None, [], None),
    ("jim-beam-white", "Jim Beam", "Jim Beam", "White Label", "kentuckyStraightBourbon", "unspecified", 40.0, None, [], None),
    ("old-grand-dad-114", "Jim Beam", "Old Grand-Dad", "114", "kentuckyStraightBourbon", "unspecified", 57.0, None, [], None),
    ("old-grand-dad-bib", "Jim Beam", "Old Grand-Dad", "Bottled in Bond", "kentuckyStraightBourbon", "unspecified", 50.0, 4, [BIB], None),

    # ---------------------------------------------------------------- Four Roses
    ("four-roses-bourbon", "Four Roses", "Four Roses", "Bourbon", "kentuckyStraightBourbon", "blend", 40.0, None, [], None),
    ("four-roses-small-batch", "Four Roses", "Four Roses", "Small Batch", "kentuckyStraightBourbon", "smallBatch", 45.0, None, [], None),
    ("four-roses-small-batch-select", "Four Roses", "Four Roses", "Small Batch Select", "kentuckyStraightBourbon", "smallBatch", 52.0, None, [], None),
    ("four-roses-single-barrel", "Four Roses", "Four Roses", "Single Barrel", "kentuckyStraightBourbon", "singleBarrel", 50.0, None, [], None),

    # ------------------------------------------------------------- Brown-Forman
    ("old-forester-86", "Brown-Forman", "Old Forester", "86 Proof", "kentuckyStraightBourbon", "unspecified", 43.0, None, [], None),
    ("old-forester-100", "Brown-Forman", "Old Forester", "100 Proof", "kentuckyStraightBourbon", "unspecified", 50.0, None, [], None),
    ("old-forester-1897", "Brown-Forman", "Old Forester", "1897 Bottled in Bond", "kentuckyStraightBourbon", "unspecified", 50.0, 4, [BIB], None),
    ("old-forester-1920", "Brown-Forman", "Old Forester", "1920 Prohibition Style", "kentuckyStraightBourbon", "unspecified", 57.5, None, [], None),
    ("woodford-reserve", "Woodford Reserve", "Woodford Reserve", "Distiller's Select", "kentuckyStraightBourbon", "smallBatch", 45.2, None, [], None),
    ("woodford-double-oaked", "Woodford Reserve", "Woodford Reserve", "Double Oaked", "kentuckyStraightBourbon", "smallBatch", 45.2, None, [], None),
    ("jack-daniels-no-7", "Jack Daniel's", "Jack Daniel's", "Old No. 7", "tennesseeWhiskey", "unspecified", 40.0, None, [], None),
    ("jack-daniels-single-barrel", "Jack Daniel's", "Jack Daniel's", "Single Barrel Select", "tennesseeWhiskey", "singleBarrel", 47.0, None, [], None),

    # -------------------------------------------------------------- Maker's Mark
    ("makers-mark", "Maker's Mark", "Maker's Mark", "", "kentuckyStraightBourbon", "unspecified", 45.0, None, [], "wheated"),
    ("makers-46", "Maker's Mark", "Maker's Mark", "46", "kentuckyStraightBourbon", "unspecified", 47.0, None, [], "wheated"),
    ("makers-cask-strength", "Maker's Mark", "Maker's Mark", "Cask Strength", "kentuckyStraightBourbon", "unspecified", None, None, [BP], "wheated"),

    # ------------------------------------------------------- Other American
    ("michters-us1-bourbon", "Michter's", "Michter's", "US*1 Small Batch Bourbon", "kentuckyStraightBourbon", "smallBatch", 45.7, None, [], None),
    ("michters-us1-rye", "Michter's", "Michter's", "US*1 Single Barrel Rye", "straightRye", "singleBarrel", 42.4, None, [], None),
    ("bulleit-bourbon", "Bulleit", "Bulleit", "Bourbon", "kentuckyStraightBourbon", "unspecified", 45.0, None, [], None),
    ("bulleit-rye", "Bulleit", "Bulleit", "Rye", "straightRye", "unspecified", 45.0, None, [], None),
    ("angels-envy", "Angel's Envy", "Angel's Envy", "Port Barrel Finish", "kentuckyStraightBourbon", "smallBatch", 43.3, None, [], None),
    ("willett-pot-still", "Willett", "Willett", "Pot Still Reserve", "kentuckyStraightBourbon", "smallBatch", 47.0, None, [], None),
    ("new-riff-bib", "New Riff", "New Riff", "Bottled in Bond Bourbon", "straightBourbon", "unspecified", 50.0, 4, [BIB], None),
    ("high-west-double-rye", "High West", "High West", "Double Rye", "rye", "blend", 46.0, None, [], None),
    ("whistlepig-10", "WhistlePig", "WhistlePig", "10 Year Rye", "straightRye", "unspecified", 50.0, 10, [], None),
    ("sagamore-rye", "Sagamore Spirit", "Sagamore Spirit", "Signature Rye", "straightRye", "blend", 41.5, None, [], None),
    ("uncle-nearest-1856", "Uncle Nearest", "Uncle Nearest", "1856 Premium", "tennesseeWhiskey", "smallBatch", 50.0, None, [], None),
    ("westward-single-malt", "Westward", "Westward", "American Single Malt", "americanSingleMalt", "unspecified", 45.0, None, [], None),
    ("balcones-baby-blue", "Balcones", "Balcones", "Baby Blue", "cornWhiskey", "unspecified", 46.0, None, [], None),

    # ------------------------------------------------------------------- Scotch
    ("lagavulin-16", "Lagavulin", "Lagavulin", "16 Year", "singleMaltScotch", "unspecified", 43.0, 16, [], None),
    ("ardbeg-10", "Ardbeg", "Ardbeg", "10 Year", "singleMaltScotch", "unspecified", 46.0, 10, [], None),
    ("laphroaig-10", "Laphroaig", "Laphroaig", "10 Year", "singleMaltScotch", "unspecified", 43.0, 10, [], None),
    ("glenfiddich-12", "Glenfiddich", "Glenfiddich", "12 Year", "singleMaltScotch", "unspecified", 40.0, 12, [], None),
    ("macallan-12-sherry", "The Macallan", "The Macallan", "12 Year Sherry Oak", "singleMaltScotch", "unspecified", 43.0, 12, [], None),
    ("johnnie-walker-black", "Johnnie Walker", "Johnnie Walker", "Black Label", "blendedScotch", "blend", 40.0, 12, [], None),
    ("monkey-shoulder", "Monkey Shoulder", "Monkey Shoulder", "", "blendedMaltScotch", "blend", 40.0, None, [], None),

    # -------------------------------------------------------------------- Irish
    ("redbreast-12", "Midleton", "Redbreast", "12 Year", "singlePotStillIrish", "unspecified", 40.0, 12, [], None),
    ("green-spot", "Midleton", "Green Spot", "", "singlePotStillIrish", "unspecified", 40.0, None, [], None),
    ("jameson", "Midleton", "Jameson", "", "irishWhiskey", "blend", 40.0, None, [], None),

    # ----------------------------------------------------------------- Japanese
    ("nikka-coffey-grain", "Nikka", "Nikka", "Coffey Grain", "japaneseWhisky", "unspecified", 45.0, None, [], None),
    ("suntory-toki", "Suntory", "Suntory", "Toki", "japaneseWhisky", "blend", 43.0, None, [], None),

    # ------------------------------------------------------------------- Agave
    ("fortaleza-blanco", "Fortaleza", "Fortaleza", "Blanco", "tequilaBlanco", "unspecified", 40.0, None, [], None),
    ("espolon-reposado", "Espolon", "Espolon", "Reposado", "tequilaReposado", "unspecified", 40.0, None, [], None),
    ("don-julio-anejo", "Don Julio", "Don Julio", "Añejo", "tequilaAnejo", "unspecified", 40.0, None, [], None),
    ("del-maguey-vida", "Del Maguey", "Del Maguey", "Vida", "mezcal", "unspecified", 42.0, None, [], None),

    # --------------------------------------------------------------------- Rum
    ("appleton-12", "Appleton Estate", "Appleton Estate", "12 Year Rare Casks", "rum", "blend", 43.0, 12, [], None),
    ("plantation-xaymaca", "Plantation", "Plantation", "Xaymaca Special Dry", "rum", "blend", 43.0, None, [], None),
    ("rhum-jm-vsop", "Rhum J.M", "Rhum J.M", "VSOP", "rhumAgricole", "unspecified", 43.0, None, [], None),

    # --------------------------------------------------------------------- Gin
    ("tanqueray-london-dry", "Tanqueray", "Tanqueray", "London Dry", "londonDryGin", "unspecified", 47.3, None, [], None),
    ("beefeater", "Beefeater", "Beefeater", "London Dry", "londonDryGin", "unspecified", 44.0, None, [], None),
    ("hendricks", "Hendrick's", "Hendrick's", "", "distilledGin", "unspecified", 44.0, None, [], None),

    # ------------------------------------------------------------------- Vodka
    ("titos", "Tito's", "Tito's", "Handmade", "vodka", "unspecified", 40.0, None, [], None),

    # ------------------------------------------------------------------ Brandy
    ("hennessy-vs", "Hennessy", "Hennessy", "VS", "cognac", "blend", 40.0, None, [], None),
    ("remy-martin-vsop", "Rémy Martin", "Rémy Martin", "VSOP", "cognac", "blend", 40.0, None, [], None),

    # ---------------------------------------------------------------- Liqueur
    # No strength floor here, by design: a 16% vermouth is not under-strength.
    ("campari", "Campari", "Campari", "", "amaro", "unspecified", 24.0, None, [], None),
    ("fernet-branca", "Fratelli Branca", "Fernet-Branca", "", "amaro", "unspecified", 39.0, None, [], None),
    ("cointreau", "Cointreau", "Cointreau", "", "liqueur", "unspecified", 40.0, None, [], None),
    ("carpano-antica", "Carpano", "Carpano", "Antica Formula", "vermouth", "unspecified", 16.5, None, [], None),
]

RECIPE_CODES = {"four-roses-single-barrel": "OBSV"}


def main():
    seen = set()
    products = []

    for row in ROWS:
        pid, distillery, brand, expression, class_type, production, abv, age, flags, mashbill = row
        if pid in seen:
            print("duplicate id: %s" % pid, file=sys.stderr)
            return 1
        seen.add(pid)

        product = {
            "id": pid,
            "distillery": distillery,
            "brand": brand,
            "expression": expression,
            "class_type": class_type,
            "production_type": production,
            "abv": abv,
        }
        if BP in flags:
            product["is_barrel_proof"] = True
        if BIB in flags:
            product["is_bottled_in_bond"] = True
        if age is not None:
            product["stated_age_years"] = age
        if mashbill:
            product["mashbill_key"] = mashbill
        if pid in RECIPE_CODES:
            product["recipe_code"] = RECIPE_CODES[pid]

        product["source"] = "Producer label"
        product["verified"] = False
        products.append(product)

    catalog = {
        "version": 1,
        "name": "Liquor-Log spirits catalog",
        "status": (
            "SEED, generated by scripts/build_catalog.py. Every row is verified:false: "
            "these are stable, widely-published product facts used so the app works end "
            "to end, and each still needs checking against the TTB COLA registry. "
            "check_catalog.py refuses a row claiming verified without a source_url. "
            "See docs/05-data-sourcing.md."
        ),
        "notes": [
            "Bourbon and American whiskey are covered in depth because the app launches "
            "there. Other families carry enough entries to prove the structure branches; "
            "adding a category later means adding rows, not reshaping anything.",
            "abv is null where the strength genuinely varies by release -- barrel proof, "
            "cask strength. A catalog claiming one number for those would be wrong for "
            "almost every bottle on almost every shelf.",
            "Product-level facts only. Batch numbers, barrel numbers, pick stores and "
            "measured proof belong on the bottle, not here.",
        ],
        "products": products,
    }

    OUT.write_text(json.dumps(catalog, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")
    print("wrote %s: %d products" % (OUT.name, len(products)))
    return 0


if __name__ == "__main__":
    sys.exit(main())
