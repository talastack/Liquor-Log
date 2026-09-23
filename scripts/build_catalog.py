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
    ("old-fitzgerald-bib", "Heaven Hill", "Old Fitzgerald", "Bottled in Bond", "kentuckyStraightBourbon", "unspecified", 50.0, None, [BIB], "wheated"),
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
    ("new-riff-bib", "New Riff", "New Riff", "Bottled in Bond Bourbon", "kentuckyStraightBourbon", "unspecified", 50.0, 4, [BIB], None),
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

    # =========================================================================
    # Second pass: the bourbon shelf in depth.
    #
    # The first pass proved the structure. This one makes the catalogue usable
    # in a shop, because a lookup that misses Jefferson's or Blanton's Gold
    # sends somebody straight to typing it in -- which works, but not on the
    # screen the app exists for.
    #
    # The catalogue stays a CONVENIENCE, not the foundation: a store pick never
    # needs approval to exist, which is what keeps this app clear of the
    # moderation queue that has OnlyDrams sitting on a 3,000-bottle backlog
    # ("Cannot enter items unless it's in the database already. The review
    # process to add new items to the database takes too long."). Depth here
    # only reduces how often somebody has to fall back to typing.
    #
    # The ranges below are the ones r/bourbon reviewers name unprompted:
    # Blanton's with its warehouse and rick, the Four Roses recipe codes, the
    # Elijah Craig and E.H. Taylor batches, Stagg, Weller.
    #
    # abv is still null ONLY where the strength genuinely varies by release.
    # Everything else states a strength, and every row is verified:false until
    # somebody checks it against a COLA.
    # =========================================================================

    # ----------------------------------------------------------- Jefferson's
    ("jeffersons-very-small-batch", "Jefferson's", "Jefferson's", "Very Small Batch", "straightBourbon", "smallBatch", 41.15, None, [], None),
    ("jeffersons-reserve", "Jefferson's", "Jefferson's", "Reserve Very Old", "straightBourbon", "smallBatch", 45.1, None, [], None),
    ("jeffersons-ocean", "Jefferson's", "Jefferson's", "Ocean Aged at Sea", "straightBourbon", "smallBatch", 45.0, None, [], None),

    # ------------------------------------------------- Buffalo Trace, in full
    ("blantons-gold", "Buffalo Trace", "Blanton's", "Gold Edition", "kentuckyStraightBourbon", "singleBarrel", 51.5, None, [], None),
    ("blantons-sftb", "Buffalo Trace", "Blanton's", "Straight From the Barrel", "kentuckyStraightBourbon", "singleBarrel", None, None, [BP], None),
    ("eh-taylor-barrel-proof", "Buffalo Trace", "E.H. Taylor", "Barrel Proof", "kentuckyStraightBourbon", "unspecified", None, None, [BP], None),
    ("eh-taylor-rye", "Buffalo Trace", "E.H. Taylor", "Straight Rye", "straightRye", "unspecified", 50.0, 4, [BIB], None),
    ("eh-taylor-four-grain", "Buffalo Trace", "E.H. Taylor", "Four Grain", "kentuckyStraightBourbon", "unspecified", 50.0, 4, [BIB], None),
    ("elmer-t-lee", "Buffalo Trace", "Elmer T. Lee", "Single Barrel", "kentuckyStraightBourbon", "singleBarrel", 45.0, None, [], None),
    ("rock-hill-farms", "Buffalo Trace", "Rock Hill Farms", "Single Barrel", "kentuckyStraightBourbon", "singleBarrel", 50.0, None, [], None),
    ("hancocks-president", "Buffalo Trace", "Hancock's", "President's Reserve", "kentuckyStraightBourbon", "singleBarrel", 44.45, None, [], None),
    ("weller-full-proof", "Buffalo Trace", "W L Weller", "Full Proof", "kentuckyStraightBourbon", "unspecified", 57.0, None, [], "wheated"),
    ("weller-single-barrel", "Buffalo Trace", "W L Weller", "Single Barrel", "kentuckyStraightBourbon", "singleBarrel", 48.5, None, [], "wheated"),
    ("weller-cypb", "Buffalo Trace", "W L Weller", "C.Y.P.B.", "kentuckyStraightBourbon", "unspecified", 47.5, None, [], "wheated"),
    ("stagg", "Buffalo Trace", "Stagg", "", "kentuckyStraightBourbon", "smallBatch", None, None, [BP], None),
    ("george-t-stagg", "Buffalo Trace", "George T. Stagg", "", "kentuckyStraightBourbon", "unspecified", None, None, [BP], None),
    ("william-larue-weller", "Buffalo Trace", "William Larue Weller", "", "kentuckyStraightBourbon", "unspecified", None, None, [BP], "wheated"),
    ("thomas-h-handy", "Buffalo Trace", "Thomas H. Handy", "Sazerac Rye", "straightRye", "unspecified", None, None, [BP], None),
    ("sazerac-18", "Buffalo Trace", "Sazerac", "18 Year", "straightRye", "unspecified", 45.0, 18, [], None),
    ("eagle-rare-17", "Buffalo Trace", "Eagle Rare", "17 Year", "kentuckyStraightBourbon", "unspecified", 50.5, 17, [], None),

    # ------------------------------------------------------------- Van Winkle
    # Distilled at Buffalo Trace for the Van Winkle family, on the wheated
    # mashbill. The most-hunted line in American whiskey and the one the
    # catalogue was missing entirely, which meant the app answered NEVER HAD
    # IT about the bottle a collector is proudest of owning.
    #
    # The proofs here are fixed by the label, unlike the annual barrel-proof
    # releases above: Pappy 15 is 107 proof every year, not a new number each
    # autumn.
    ("orvw-10", "Buffalo Trace", "Old Rip Van Winkle", "10 Year", "kentuckyStraightBourbon", "unspecified", 53.5, 10, [], "wheated"),
    ("van-winkle-12", "Buffalo Trace", "Van Winkle", "Special Reserve 12 Year Lot B", "kentuckyStraightBourbon", "unspecified", 45.2, 12, [], "wheated"),
    ("pappy-15", "Buffalo Trace", "Pappy Van Winkle", "15 Year", "kentuckyStraightBourbon", "unspecified", 53.5, 15, [], "wheated"),
    ("pappy-20", "Buffalo Trace", "Pappy Van Winkle", "20 Year", "kentuckyStraightBourbon", "unspecified", 45.2, 20, [], "wheated"),
    ("pappy-23", "Buffalo Trace", "Pappy Van Winkle", "23 Year", "kentuckyStraightBourbon", "unspecified", 47.8, 23, [], "wheated"),
    ("van-winkle-family-rye-13", "Buffalo Trace", "Van Winkle", "Family Reserve Rye 13 Year", "straightRye", "unspecified", 47.8, 13, [], None),

    # -------------------------------------------------- Heaven Hill, in full
    ("evan-williams-1783", "Heaven Hill", "Evan Williams", "1783 Small Batch", "kentuckyStraightBourbon", "smallBatch", 43.0, None, [], None),
    ("mellow-corn", "Heaven Hill", "Mellow Corn", "Bottled in Bond", "straightCornWhiskey", "unspecified", 50.0, 4, [BIB], None),
    ("bernheim-wheat", "Heaven Hill", "Bernheim", "Original Wheat Whiskey", "straightWheatWhiskey", "smallBatch", 45.0, 7, [], None),
    ("jts-brown-bib", "Heaven Hill", "J.T.S. Brown", "Bottled in Bond", "kentuckyStraightBourbon", "unspecified", 50.0, 4, [BIB], None),

    # ------------------------------------------------------ Jim Beam, in full
    ("knob-creek-12", "Jim Beam", "Knob Creek", "12 Year", "kentuckyStraightBourbon", "smallBatch", 50.0, 12, [], None),
    ("knob-creek-15", "Jim Beam", "Knob Creek", "15 Year", "kentuckyStraightBourbon", "smallBatch", 50.0, 15, [], None),
    ("jim-beam-black", "Jim Beam", "Jim Beam", "Black Label", "kentuckyStraightBourbon", "unspecified", 43.0, None, [], None),
    ("jim-beam-rye", "Jim Beam", "Jim Beam", "Pre-Prohibition Style Rye", "straightRye", "unspecified", 45.0, None, [], None),
    ("old-crow", "Jim Beam", "Old Crow", "", "kentuckyStraightBourbon", "unspecified", 40.0, None, [], None),
    ("old-overholt-bib", "Jim Beam", "Old Overholt", "Bottled in Bond", "straightRye", "unspecified", 50.0, 4, [BIB], None),
    ("old-overholt-86", "Jim Beam", "Old Overholt", "86 Proof", "straightRye", "unspecified", 43.0, None, [], None),
    ("basil-hayden-toast", "Jim Beam", "Basil Hayden", "Toast", "kentuckyStraightBourbon", "unspecified", 40.0, None, [], None),

    # -------------------------------------------------- Brown-Forman, in full
    ("old-forester-1870", "Brown-Forman", "Old Forester", "1870 Original Batch", "kentuckyStraightBourbon", "smallBatch", 45.0, None, [], None),
    ("old-forester-rye", "Brown-Forman", "Old Forester", "Rye 100 Proof", "straightRye", "unspecified", 50.0, None, [], None),
    ("old-forester-single-barrel-bs", "Brown-Forman", "Old Forester", "Single Barrel Barrel Strength", "kentuckyStraightBourbon", "singleBarrel", None, None, [BP], None),
    ("woodford-rye", "Woodford Reserve", "Woodford Reserve", "Straight Rye", "straightRye", "unspecified", 45.2, None, [], None),
    ("woodford-wheat", "Woodford Reserve", "Woodford Reserve", "Straight Wheat", "straightWheatWhiskey", "unspecified", 45.2, None, [], None),
    ("coopers-craft", "Brown-Forman", "Coopers' Craft", "", "kentuckyStraightBourbon", "unspecified", 41.1, None, [], None),
    ("early-times-bib", "Brown-Forman", "Early Times", "Bottled in Bond", "kentuckyStraightBourbon", "unspecified", 50.0, 4, [BIB], None),

    # ------------------------------------------------- Jack Daniel's, in full
    ("gentleman-jack", "Jack Daniel's", "Jack Daniel's", "Gentleman Jack", "tennesseeWhiskey", "unspecified", 40.0, None, [], None),
    ("jack-daniels-bonded", "Jack Daniel's", "Jack Daniel's", "Bonded", "tennesseeWhiskey", "unspecified", 50.0, 4, [BIB], None),
    ("jack-daniels-rye", "Jack Daniel's", "Jack Daniel's", "Tennessee Rye", "tennesseeWhiskey", "unspecified", 45.0, None, [], None),
    ("jack-daniels-sbbp", "Jack Daniel's", "Jack Daniel's", "Single Barrel Barrel Proof", "tennesseeWhiskey", "singleBarrel", None, None, [BP], None),
    ("george-dickel-12", "George Dickel", "George Dickel", "No. 12", "tennesseeWhiskey", "unspecified", 45.0, None, [], None),
    ("george-dickel-bib", "George Dickel", "George Dickel", "Bottled in Bond", "tennesseeWhiskey", "unspecified", 50.0, None, [BIB], None),
    ("george-dickel-rye", "George Dickel", "George Dickel", "Straight Rye", "straightRye", "unspecified", 45.0, None, [], None),

    # ------------------------------------------------------- Barton / Sazerac
    ("1792-small-batch", "Barton 1792", "1792", "Small Batch", "kentuckyStraightBourbon", "smallBatch", 46.85, None, [], None),
    ("1792-full-proof", "Barton 1792", "1792", "Full Proof", "kentuckyStraightBourbon", "unspecified", 62.5, None, [], None),
    ("1792-single-barrel", "Barton 1792", "1792", "Single Barrel", "kentuckyStraightBourbon", "singleBarrel", 49.3, None, [], None),
    ("1792-bib", "Barton 1792", "1792", "Bottled in Bond", "kentuckyStraightBourbon", "unspecified", 50.0, 4, [BIB], None),
    ("very-old-barton-bib", "Barton 1792", "Very Old Barton", "Bottled in Bond", "kentuckyStraightBourbon", "unspecified", 50.0, None, [BIB], None),

    # -------------------------------------------------------------- Lux Row
    ("ezra-brooks-99", "Lux Row", "Ezra Brooks", "99", "kentuckyStraightBourbon", "unspecified", 49.5, None, [], None),
    ("old-ezra-7", "Lux Row", "Old Ezra", "7 Year Barrel Strength", "kentuckyStraightBourbon", "smallBatch", 58.5, 7, [], None),
    ("rebel-100", "Lux Row", "Rebel", "100 Proof", "kentuckyStraightBourbon", "unspecified", 50.0, None, [], "wheated"),
    ("david-nicholson-1843", "Lux Row", "David Nicholson", "1843", "kentuckyStraightBourbon", "unspecified", 50.0, None, [], "wheated"),
    ("daviess-county", "Lux Row", "Daviess County", "Straight Bourbon", "kentuckyStraightBourbon", "unspecified", 48.0, None, [], None),

    # -------------------------------------------------------------- Michter's
    ("michters-10-bourbon", "Michter's", "Michter's", "10 Year Bourbon", "kentuckyStraightBourbon", "singleBarrel", 47.2, 10, [], None),
    ("michters-toasted-bourbon", "Michter's", "Michter's", "US*1 Toasted Barrel Bourbon", "kentuckyStraightBourbon", "smallBatch", 45.7, None, [], None),

    # ---------------------------------------------------------------- Willett
    ("noahs-mill", "Willett", "Noah's Mill", "", "kentuckyStraightBourbon", "smallBatch", 57.15, None, [], None),
    ("rowans-creek", "Willett", "Rowan's Creek", "", "kentuckyStraightBourbon", "smallBatch", 50.05, None, [], None),
    ("old-bardstown-estate", "Willett", "Old Bardstown", "Estate Bottled", "kentuckyStraightBourbon", "unspecified", 50.5, None, [], None),
    ("johnny-drum", "Willett", "Johnny Drum", "Private Stock", "kentuckyStraightBourbon", "smallBatch", 50.5, None, [], None),
    ("willett-family-estate-rye", "Willett", "Willett", "Family Estate Rye", "straightRye", "singleBarrel", None, None, [BP], None),
    ("willett-family-estate-bourbon", "Willett", "Willett", "Family Estate Bourbon", "kentuckyStraightBourbon", "singleBarrel", None, None, [BP], None),

    # ----------------------------------------------------- Wild Turkey, more
    ("wild-turkey-81", "Wild Turkey", "Wild Turkey", "81", "kentuckyStraightBourbon", "unspecified", 40.5, None, [], None),
    ("russells-reserve-13", "Wild Turkey", "Russell's Reserve", "13 Year", "kentuckyStraightBourbon", "smallBatch", 57.3, 13, [], None),
    ("russells-reserve-6-rye", "Wild Turkey", "Russell's Reserve", "6 Year Rye", "straightRye", "smallBatch", 45.0, 6, [], None),

    # --------------------------------------------------- Independent bottlers
    ("angels-envy-cask-strength", "Angel's Envy", "Angel's Envy", "Cask Strength", "kentuckyStraightBourbon", "smallBatch", None, None, [BP], None),
    ("angels-envy-rye", "Angel's Envy", "Angel's Envy", "Rye Rum Cask Finish", "rye", "smallBatch", 50.0, None, [], None),
    ("bulleit-10", "Bulleit", "Bulleit", "10 Year", "straightBourbon", "unspecified", 45.6, 10, [], None),
    ("bulleit-barrel-strength", "Bulleit", "Bulleit", "Barrel Strength", "straightBourbon", "unspecified", None, None, [BP], None),
    ("barrell-bourbon", "Barrell Craft Spirits", "Barrell", "Bourbon", "blendOfStraightBourbon", "blend", None, None, [BP], None),
    ("barrell-seagrass", "Barrell Craft Spirits", "Barrell", "Seagrass", "rye", "blend", None, None, [BP], None),
    ("barrell-dovetail", "Barrell Craft Spirits", "Barrell", "Dovetail", "blendedWhiskey", "blend", None, None, [BP], None),

    # --------------------------------------------------- Annual releases
    # The bottles people queue for. Every one of these is a new whiskey each
    # year, so abv is null on purpose -- the convention already used for
    # barrel proof above. A catalogue claiming one proof for Birthday
    # Bourbon would be wrong for every year but one.
    #
    # Three kinds of bottle are deliberately NOT here, because the model
    # cannot hold them honestly and check_catalog.py is right to refuse
    # them:
    #
    #   Parker's Heritage changes CLASS between releases -- bourbon one
    #   year, wheat whiskey or rye the next -- and class cannot say "it
    #   depends". One row would be wrong for whichever year you hold.
    #
    #   Old Forester Birthday Bourbon and the Kentucky Owl batches change
    #   STRENGTH every release without being barrel proof. `abv = None` is
    #   allowed only alongside the barrel-proof flag, which is the correct
    #   rule: it makes the app say "whatever this barrel came out at"
    #   rather than leaving a number blank for no stated reason. There is
    #   no flag yet for "a new recipe each year at a stated proof", and
    #   inventing a proof to get past the check would put a wrong number
    #   on every bottle but one.
    #
    # Adding them means adding that flag first, not adding a row.
    ("king-of-kentucky", "Brown-Forman", "King of Kentucky", "", "kentuckyStraightBourbon", "singleBarrel", None, None, [BP], None),
    ("little-book", "Jim Beam", "Little Book", "", "blendedWhiskey", "blend", None, None, [BP], None),
    ("kentucky-owl-confiscated", "Kentucky Owl", "Kentucky Owl", "Confiscated", "kentuckyStraightBourbon", "smallBatch", 48.2, None, [], None),
    ("high-west-rendezvous", "High West", "High West", "Rendezvous Rye", "straightRye", "blend", 46.0, None, [], None),
    ("high-west-american-prairie", "High West", "High West", "American Prairie", "blendOfStraightBourbon", "blend", 46.0, None, [], None),
    ("smooth-ambler-contradiction", "Smooth Ambler", "Smooth Ambler", "Contradiction", "blendOfStraightBourbon", "blend", 50.0, None, [], None),
    ("smooth-ambler-old-scout", "Smooth Ambler", "Smooth Ambler", "Old Scout", "straightBourbon", "unspecified", 49.5, None, [], None),
    ("redemption-rye", "Redemption", "Redemption", "Straight Rye", "straightRye", "unspecified", 46.0, None, [], None),
    ("widow-jane-10", "Widow Jane", "Widow Jane", "10 Year", "blendOfStraightBourbon", "blend", 45.5, 10, [], None),
    ("templeton-rye-4", "Templeton", "Templeton", "4 Year Rye", "straightRye", "unspecified", 40.0, 4, [], None),

    # ------------------------------------------------------ Craft distilleries
    ("new-riff-single-barrel", "New Riff", "New Riff", "Single Barrel", "kentuckyStraightBourbon", "singleBarrel", None, None, [BP], None),
    ("new-riff-rye-bib", "New Riff", "New Riff", "Bottled in Bond Rye", "straightRye", "unspecified", 50.0, 4, [BIB], None),
    ("wilderness-trail-bib", "Wilderness Trail", "Wilderness Trail", "Small Batch Bottled in Bond", "kentuckyStraightBourbon", "smallBatch", 50.0, 4, [BIB], None),
    ("green-river-bourbon", "Green River", "Green River", "Straight Bourbon", "kentuckyStraightBourbon", "unspecified", 45.0, None, [], None),
    ("castle-key-small-batch", "Castle & Key", "Castle & Key", "Small Batch Bourbon", "kentuckyStraightBourbon", "smallBatch", 49.0, None, [], None),
    ("old-elk-blended", "Old Elk", "Old Elk", "Blended Straight Bourbon", "blendOfStraightBourbon", "blend", 44.0, None, [], None),
    ("frey-ranch-bourbon", "Frey Ranch", "Frey Ranch", "Straight Bourbon", "straightBourbon", "unspecified", 45.0, None, [], None),
    ("penelope-four-grain", "Penelope", "Penelope", "Four Grain", "straightBourbon", "blend", 40.0, None, [], None),
    ("penelope-architect", "Penelope", "Penelope", "Architect", "straightBourbon", "blend", 52.0, None, [], None),
    ("penelope-barrel-strength", "Penelope", "Penelope", "Barrel Strength", "straightBourbon", "blend", None, None, [BP], None),
    ("smoke-wagon-uncut", "Nevada H&C", "Smoke Wagon", "Uncut Unfiltered", "straightBourbon", "smallBatch", None, None, [BP], None),
    ("smoke-wagon-small-batch", "Nevada H&C", "Smoke Wagon", "Small Batch", "straightBourbon", "smallBatch", 50.0, None, [], None),
    ("yellowstone-select", "Limestone Branch", "Yellowstone", "Select", "kentuckyStraightBourbon", "smallBatch", 46.5, None, [], None),
    ("laws-four-grain", "Laws Whiskey House", "Laws", "Four Grain", "straightBourbon", "unspecified", 47.5, None, [], None),
    ("leopold-three-chamber", "Leopold Bros", "Leopold Bros", "Three Chamber Rye", "straightRye", "unspecified", 50.0, None, [], None),
    ("kings-county-bourbon", "Kings County", "Kings County", "Straight Bourbon", "straightBourbon", "unspecified", 45.0, None, [], None),
    ("woodinville-bourbon", "Woodinville", "Woodinville", "Straight Bourbon", "straightBourbon", "unspecified", 45.0, None, [], None),
    ("few-bourbon", "FEW Spirits", "FEW", "Straight Bourbon", "straightBourbon", "unspecified", 46.5, None, [], None),
    ("garrison-brothers-small-batch", "Garrison Brothers", "Garrison Brothers", "Small Batch", "straightBourbon", "smallBatch", 47.0, None, [], None),
    ("balcones-pot-still", "Balcones", "Balcones", "Pot Still Bourbon", "straightBourbon", "unspecified", 46.0, None, [], None),
    ("hudson-bright-lights", "Hudson", "Hudson", "Bright Lights Big Bourbon", "straightBourbon", "unspecified", 46.0, None, [], None),
    ("breckenridge-bourbon", "Breckenridge", "Breckenridge", "Blended Bourbon", "blendOfStraightBourbon", "blend", 43.0, None, [], None),
    ("stranahans-original", "Stranahan's", "Stranahan's", "Original", "americanSingleMalt", "smallBatch", 47.0, None, [], None),
    ("westland-american-oak", "Westland", "Westland", "American Oak", "americanSingleMalt", "smallBatch", 46.0, None, [], None),

    # =========================================================================
    # Third pass: what a bourbon drinker branches into.
    #
    # American whiskey was 172 rows and everything else was one to five, so a
    # shelf check missed every Scotch on the shelf. The app still launches on
    # bourbon -- that is not changing -- but somebody with a dozen single malts
    # beside their bourbon should not have to type all twelve.
    #
    # Same rules as the other passes: a stated strength or an honest null for a
    # cask-strength release, no duplicate identity, and verified:false until a
    # COLA says otherwise.
    # =========================================================================

    # ---------------------------------------------------------- Scotch, malt
    ("glenfiddich-15", "William Grant", "Glenfiddich", "15 Year Solera", "singleMaltScotch", "unspecified", 40.0, 15, [], None),
    ("glenfiddich-18", "William Grant", "Glenfiddich", "18 Year", "singleMaltScotch", "unspecified", 40.0, 18, [], None),
    ("glenlivet-12", "The Glenlivet", "The Glenlivet", "12 Year", "singleMaltScotch", "unspecified", 40.0, 12, [], None),
    ("glenlivet-18", "The Glenlivet", "The Glenlivet", "18 Year", "singleMaltScotch", "unspecified", 43.0, 18, [], None),
    ("macallan-18-sherry", "The Macallan", "The Macallan", "18 Year Sherry Oak", "singleMaltScotch", "unspecified", 43.0, 18, [], None),
    ("macallan-double-cask-12", "The Macallan", "The Macallan", "Double Cask 12 Year", "singleMaltScotch", "unspecified", 43.0, 12, [], None),
    ("highland-park-12", "Highland Park", "Highland Park", "12 Year Viking Honour", "singleMaltScotch", "unspecified", 43.0, 12, [], None),
    ("highland-park-18", "Highland Park", "Highland Park", "18 Year", "singleMaltScotch", "unspecified", 43.0, 18, [], None),
    ("balvenie-doublewood-12", "William Grant", "The Balvenie", "DoubleWood 12 Year", "singleMaltScotch", "unspecified", 43.0, 12, [], None),
    ("balvenie-caribbean-14", "William Grant", "The Balvenie", "Caribbean Cask 14 Year", "singleMaltScotch", "unspecified", 43.0, 14, [], None),
    ("glenmorangie-10", "Glenmorangie", "Glenmorangie", "Original 10 Year", "singleMaltScotch", "unspecified", 43.0, 10, [], None),
    ("glenmorangie-lasanta", "Glenmorangie", "Glenmorangie", "Lasanta 12 Year", "singleMaltScotch", "unspecified", 43.0, 12, [], None),
    ("glenmorangie-nectar-dor", "Glenmorangie", "Glenmorangie", "Nectar d'Or", "singleMaltScotch", "unspecified", 46.0, None, [], None),
    ("ardbeg-uigeadail", "Ardbeg", "Ardbeg", "Uigeadail", "singleMaltScotch", "unspecified", 54.2, None, [], None),
    ("ardbeg-corryvreckan", "Ardbeg", "Ardbeg", "Corryvreckan", "singleMaltScotch", "unspecified", 57.1, None, [], None),
    ("lagavulin-8", "Lagavulin", "Lagavulin", "8 Year", "singleMaltScotch", "unspecified", 48.0, 8, [], None),
    ("laphroaig-quarter-cask", "Laphroaig", "Laphroaig", "Quarter Cask", "singleMaltScotch", "unspecified", 48.0, None, [], None),
    ("laphroaig-lore", "Laphroaig", "Laphroaig", "Lore", "singleMaltScotch", "unspecified", 48.0, None, [], None),
    ("talisker-10", "Talisker", "Talisker", "10 Year", "singleMaltScotch", "unspecified", 45.8, 10, [], None),
    ("talisker-storm", "Talisker", "Talisker", "Storm", "singleMaltScotch", "unspecified", 45.8, None, [], None),
    ("oban-14", "Oban", "Oban", "14 Year", "singleMaltScotch", "unspecified", 43.0, 14, [], None),
    ("springbank-10", "Springbank", "Springbank", "10 Year", "singleMaltScotch", "unspecified", 46.0, 10, [], None),
    ("bruichladdich-classic", "Bruichladdich", "Bruichladdich", "The Classic Laddie", "singleMaltScotch", "unspecified", 50.0, None, [], None),
    ("port-charlotte-10", "Bruichladdich", "Port Charlotte", "10 Year", "singleMaltScotch", "unspecified", 50.0, 10, [], None),
    ("bowmore-12", "Bowmore", "Bowmore", "12 Year", "singleMaltScotch", "unspecified", 40.0, 12, [], None),
    ("bunnahabhain-12", "Bunnahabhain", "Bunnahabhain", "12 Year", "singleMaltScotch", "unspecified", 46.3, 12, [], None),
    ("caol-ila-12", "Caol Ila", "Caol Ila", "12 Year", "singleMaltScotch", "unspecified", 43.0, 12, [], None),
    ("aberlour-12", "Aberlour", "Aberlour", "12 Year Double Cask", "singleMaltScotch", "unspecified", 43.0, 12, [], None),
    ("aberlour-abunadh", "Aberlour", "Aberlour", "A'bunadh", "singleMaltScotch", "unspecified", None, None, [BP], None),
    ("glendronach-12", "GlenDronach", "GlenDronach", "12 Year Original", "singleMaltScotch", "unspecified", 43.0, 12, [], None),
    ("glendronach-15", "GlenDronach", "GlenDronach", "15 Year Revival", "singleMaltScotch", "unspecified", 46.0, 15, [], None),
    ("dalmore-12", "The Dalmore", "The Dalmore", "12 Year", "singleMaltScotch", "unspecified", 40.0, 12, [], None),
    ("glenfarclas-12", "Glenfarclas", "Glenfarclas", "12 Year", "singleMaltScotch", "unspecified", 43.0, 12, [], None),
    ("glenfarclas-105", "Glenfarclas", "Glenfarclas", "105 Cask Strength", "singleMaltScotch", "unspecified", 60.0, None, [], None),
    ("kilchoman-machir-bay", "Kilchoman", "Kilchoman", "Machir Bay", "singleMaltScotch", "unspecified", 46.0, None, [], None),
    ("arran-10", "Arran", "Arran", "10 Year", "singleMaltScotch", "unspecified", 46.0, 10, [], None),
    ("craigellachie-13", "Craigellachie", "Craigellachie", "13 Year", "singleMaltScotch", "unspecified", 46.0, 13, [], None),

    # ------------------------------------------------------ Scotch, blended
    ("jw-green", "Johnnie Walker", "Johnnie Walker", "Green Label 15 Year", "blendedMaltScotch", "blend", 43.0, 15, [], None),
    ("jw-blue", "Johnnie Walker", "Johnnie Walker", "Blue Label", "blendedScotch", "blend", 40.0, None, [], None),
    ("chivas-12", "Chivas Brothers", "Chivas Regal", "12 Year", "blendedScotch", "blend", 40.0, 12, [], None),
    ("dewars-white", "Dewar's", "Dewar's", "White Label", "blendedScotch", "blend", 40.0, None, [], None),
    ("famous-grouse", "Edrington", "The Famous Grouse", "", "blendedScotch", "blend", 40.0, None, [], None),

    # ----------------------------------------------------------------- Irish
    ("jameson-black-barrel", "Midleton", "Jameson", "Black Barrel", "irishWhiskey", "blend", 40.0, None, [], None),
    ("redbreast-15", "Midleton", "Redbreast", "15 Year", "singlePotStillIrish", "unspecified", 46.0, 15, [], None),
    ("yellow-spot-12", "Midleton", "Yellow Spot", "12 Year", "singlePotStillIrish", "unspecified", 46.0, 12, [], None),
    ("powers-gold", "Midleton", "Powers", "Gold Label", "irishWhiskey", "blend", 43.2, None, [], None),
    ("powers-johns-lane", "Midleton", "Powers", "John's Lane 12 Year", "singlePotStillIrish", "unspecified", 46.0, 12, [], None),
    ("bushmills-10", "Bushmills", "Bushmills", "10 Year Single Malt", "singleMaltIrish", "unspecified", 40.0, 10, [], None),
    ("bushmills-black-bush", "Bushmills", "Bushmills", "Black Bush", "irishWhiskey", "blend", 40.0, None, [], None),
    ("teeling-small-batch", "Teeling", "Teeling", "Small Batch", "irishWhiskey", "smallBatch", 46.0, None, [], None),
    ("tullamore-dew", "Tullamore", "Tullamore D.E.W.", "Original", "irishWhiskey", "blend", 40.0, None, [], None),

    # -------------------------------------------------------------- Japanese
    ("nikka-from-the-barrel", "Nikka", "Nikka", "From The Barrel", "japaneseWhisky", "blend", 51.4, None, [], None),
    ("nikka-coffey-malt", "Nikka", "Nikka", "Coffey Malt", "japaneseWhisky", "unspecified", 45.0, None, [], None),
    ("hibiki-harmony", "Suntory", "Hibiki", "Japanese Harmony", "japaneseWhisky", "blend", 43.0, None, [], None),
    ("yamazaki-12", "Suntory", "Yamazaki", "12 Year", "japaneseWhisky", "unspecified", 43.0, 12, [], None),
    ("hakushu-12", "Suntory", "Hakushu", "12 Year", "japaneseWhisky", "unspecified", 43.0, 12, [], None),

    # ------------------------------------------------------------------- Rum
    ("appleton-signature", "Appleton Estate", "Appleton Estate", "Signature", "rum", "blend", 40.0, None, [], None),
    ("mount-gay-black-barrel", "Mount Gay", "Mount Gay", "Black Barrel", "rum", "blend", 43.0, None, [], None),
    ("mount-gay-xo", "Mount Gay", "Mount Gay", "XO", "rum", "blend", 43.0, None, [], None),
    ("diplomatico-reserva", "Diplomatico", "Diplomatico", "Reserva Exclusiva", "rum", "blend", 40.0, None, [], None),
    ("el-dorado-12", "Demerara Distillers", "El Dorado", "12 Year", "rum", "blend", 40.0, 12, [], None),
    ("el-dorado-15", "Demerara Distillers", "El Dorado", "15 Year", "rum", "blend", 43.0, 15, [], None),
    ("flor-de-cana-12", "Flor de Caña", "Flor de Caña", "12 Year", "rum", "blend", 40.0, 12, [], None),
    ("smith-and-cross", "Hampden", "Smith & Cross", "Navy Strength", "rum", "blend", 57.0, None, [], None),
    ("wray-and-nephew", "J. Wray", "Wray & Nephew", "White Overproof", "rum", "unspecified", 63.0, None, [], None),

    # ----------------------------------------------------------------- Agave
    ("fortaleza-reposado", "Fortaleza", "Fortaleza", "Reposado", "tequilaReposado", "unspecified", 40.0, None, [], None),
    ("fortaleza-anejo", "Fortaleza", "Fortaleza", "Añejo", "tequilaAnejo", "unspecified", 40.0, None, [], None),
    ("espolon-blanco", "Espolon", "Espolon", "Blanco", "tequilaBlanco", "unspecified", 40.0, None, [], None),
    ("don-julio-blanco", "Don Julio", "Don Julio", "Blanco", "tequilaBlanco", "unspecified", 40.0, None, [], None),
    ("don-julio-reposado", "Don Julio", "Don Julio", "Reposado", "tequilaReposado", "unspecified", 40.0, None, [], None),
    ("tequila-ocho-plata", "Tequila Ocho", "Tequila Ocho", "Plata", "tequilaBlanco", "unspecified", 40.0, None, [], None),
    ("herradura-reposado", "Herradura", "Herradura", "Reposado", "tequilaReposado", "unspecified", 40.0, None, [], None),
    ("del-maguey-chichicapa", "Del Maguey", "Del Maguey", "Chichicapa", "mezcal", "unspecified", 46.0, None, [], None),
    ("montelobos-joven", "Montelobos", "Montelobos", "Joven", "mezcal", "unspecified", 43.2, None, [], None),

    # ------------------------------------------------------------------- Gin
    ("tanqueray-ten", "Tanqueray", "Tanqueray", "No. Ten", "distilledGin", "unspecified", 47.3, None, [], None),
    ("bombay-sapphire", "Bombay", "Bombay Sapphire", "", "londonDryGin", "unspecified", 47.0, None, [], None),
    ("plymouth-gin", "Plymouth", "Plymouth", "Original", "distilledGin", "unspecified", 41.2, None, [], None),
    ("sipsmith-london-dry", "Sipsmith", "Sipsmith", "London Dry", "londonDryGin", "unspecified", 41.6, None, [], None),
    ("roku-gin", "Suntory", "Roku", "", "distilledGin", "unspecified", 43.0, None, [], None),
    ("fords-gin", "Ford's", "Ford's", "London Dry", "londonDryGin", "unspecified", 45.0, None, [], None),
    ("monkey-47", "Black Forest", "Monkey 47", "Schwarzwald Dry", "distilledGin", "unspecified", 47.0, None, [], None),
    ("aviation-gin", "Aviation", "Aviation", "American Gin", "distilledGin", "unspecified", 42.0, None, [], None),

    # ---------------------------------------------------------------- Brandy
    ("hennessy-vsop", "Hennessy", "Hennessy", "VSOP Privilège", "cognac", "blend", 40.0, None, [], None),
    ("remy-xo", "Rémy Martin", "Rémy Martin", "XO", "cognac", "blend", 40.0, None, [], None),
    ("courvoisier-vs", "Courvoisier", "Courvoisier", "VS", "cognac", "blend", 40.0, None, [], None),
    ("martell-vs", "Martell", "Martell", "VS Single Distillery", "cognac", "blend", 40.0, None, [], None),
    ("pierre-ferrand-1840", "Pierre Ferrand", "Pierre Ferrand", "1840 Original Formula", "cognac", "blend", 45.0, None, [], None),

    # ----------------------------------------------------------------- Vodka
    ("grey-goose", "Grey Goose", "Grey Goose", "", "vodka", "unspecified", 40.0, None, [], None),
    ("ketel-one", "Nolet", "Ketel One", "", "vodka", "unspecified", 40.0, None, [], None),
    ("belvedere", "Belvedere", "Belvedere", "", "vodka", "unspecified", 40.0, None, [], None),

    # -------------------------------------------------- Liqueur, amaro, vermouth
    # No 40% floor on this family, and that is correct rather than lenient: a
    # 16% vermouth is not under-strength, and rejecting it would be the app
    # being confidently wrong. See ClassType.minimumBottlingStrength.
    ("grand-marnier", "Marnier-Lapostolle", "Grand Marnier", "Cordon Rouge", "liqueur", "unspecified", 40.0, None, [], None),
    ("aperol", "Campari Group", "Aperol", "", "amaro", "unspecified", 11.0, None, [], None),
    ("amaro-nonino", "Nonino", "Amaro Nonino", "Quintessentia", "amaro", "unspecified", 35.0, None, [], None),
    ("averna", "Averna", "Averna", "Amaro Siciliano", "amaro", "unspecified", 29.0, None, [], None),
    ("cynar", "Campari Group", "Cynar", "", "amaro", "unspecified", 16.5, None, [], None),
    ("chartreuse-green", "Chartreuse", "Chartreuse", "Green", "liqueur", "unspecified", 55.0, None, [], None),
    ("chartreuse-yellow", "Chartreuse", "Chartreuse", "Yellow", "liqueur", "unspecified", 40.0, None, [], None),
    ("benedictine", "Bénédictine", "Bénédictine", "D.O.M.", "liqueur", "unspecified", 40.0, None, [], None),
    ("luxardo-maraschino", "Luxardo", "Luxardo", "Maraschino", "liqueur", "unspecified", 32.0, None, [], None),
    ("st-germain", "St-Germain", "St-Germain", "Elderflower", "liqueur", "unspecified", 20.0, None, [], None),
    ("dolin-dry", "Dolin", "Dolin", "Dry", "vermouth", "unspecified", 17.5, None, [], None),
    ("cocchi-torino", "Cocchi", "Cocchi", "Vermouth di Torino", "vermouth", "unspecified", 16.0, None, [], None),
    # ------------------------------------- More American whiskey (15 Sep 2026)
    ("old-forester-1910", "Brown-Forman", "Old Forester", "1910 Old Fine Whisky", "kentuckyStraightBourbon", "unspecified", 46.5, None, [], None),
    ("old-forester-statesman", "Brown-Forman", "Old Forester", "Statesman", "kentuckyStraightBourbon", "unspecified", 47.5, None, [], None),
    ("jim-beam-devils-cut", "Jim Beam", "Jim Beam", "Devil's Cut", "kentuckyStraightBourbon", "unspecified", 45.0, None, [], None),
    ("jim-beam-single-barrel", "Jim Beam", "Jim Beam", "Single Barrel", "kentuckyStraightBourbon", "singleBarrel", 54.0, None, [], None),
    ("old-grand-dad-80", "Jim Beam", "Old Grand-Dad", "80 Proof", "kentuckyStraightBourbon", "unspecified", 40.0, None, [], None),
    ("wild-turkey-kentucky-spirit", "Wild Turkey", "Wild Turkey", "Kentucky Spirit", "kentuckyStraightBourbon", "singleBarrel", 50.5, None, [], None),
    ("russells-reserve-single-barrel-rye", "Wild Turkey", "Russell's Reserve", "Single Barrel Rye", "straightRye", "singleBarrel", 52.0, None, [], None),
    ("bowman-brothers", "A. Smith Bowman", "Bowman Brothers", "Small Batch", "straightBourbon", "smallBatch", 45.0, None, [], None),
    ("john-j-bowman", "A. Smith Bowman", "John J. Bowman", "Single Barrel", "straightBourbon", "singleBarrel", 50.0, None, [], None),
    ("elijah-craig-rye", "Heaven Hill", "Elijah Craig", "Straight Rye", "straightRye", "unspecified", 47.0, None, [], None),
    ("michters-us1-sour-mash", "Michter's", "Michter's", "US*1 Sour Mash", "blendedWhiskey", "unspecified", 43.0, None, [], None),
    ("michters-us1-american", "Michter's", "Michter's", "US*1 American Whiskey", "blendedWhiskey", "unspecified", 41.7, None, [], None),
    ("michters-10-rye", "Michter's", "Michter's", "10 Year Rye", "straightRye", "singleBarrel", 46.4, 10, [], None),
    ("bardstown-origin-bourbon", "Bardstown Bourbon Company", "Bardstown Bourbon Company", "Origin Series Kentucky Straight Bourbon", "kentuckyStraightBourbon", "unspecified", 48.0, None, [], None),
    ("bardstown-origin-bib", "Bardstown Bourbon Company", "Bardstown Bourbon Company", "Origin Series Bottled in Bond", "kentuckyStraightBourbon", "unspecified", 50.0, None, [BIB], None),
    ("rabbit-hole-cavehill", "Rabbit Hole", "Rabbit Hole", "Cavehill", "kentuckyStraightBourbon", "unspecified", 47.5, None, [], None),
    ("rabbit-hole-heigold", "Rabbit Hole", "Rabbit Hole", "Heigold", "kentuckyStraightBourbon", "unspecified", 50.0, None, [], None),
    ("belle-meade-bourbon", "Nelson's Green Brier", "Belle Meade", "Bourbon", "straightBourbon", "unspecified", 45.2, None, [], None),
    ("nelsons-green-brier-tennessee", "Nelson's Green Brier", "Nelson's Green Brier", "Tennessee Whiskey", "tennesseeWhiskey", "unspecified", 45.5, None, [], None),
    ("george-dickel-8", "George Dickel", "George Dickel", "8 Year", "tennesseeWhiskey", "unspecified", 45.0, 8, [], None),
    ("jack-daniels-10", "Jack Daniel's", "Jack Daniel's", "10 Year", "tennesseeWhiskey", "unspecified", 48.5, 10, [], None),
    ("uncle-nearest-1884", "Uncle Nearest", "Uncle Nearest", "1884 Small Batch", "tennesseeWhiskey", "smallBatch", 46.5, None, [], None),
    ("whistlepig-piggyback-6", "WhistlePig", "WhistlePig", "PiggyBack 6 Year Rye", "straightRye", "unspecified", 48.28, 6, [], None),
    ("dads-hat-rye", "Mountain Laurel Spirits", "Dad's Hat", "Pennsylvania Rye", "straightRye", "unspecified", 45.0, None, [], None),
    ("balcones-texas-single-malt", "Balcones", "Balcones", "Texas Single Malt", "americanSingleMalt", "unspecified", 53.0, None, [], None),

    # ---------------------------------------------------------------- Canadian
    ("crown-royal", "Crown Royal", "Crown Royal", "Deluxe", "canadianWhisky", "unspecified", 40.0, None, [], None),
    ("crown-royal-northern-harvest", "Crown Royal", "Crown Royal", "Northern Harvest Rye", "canadianWhisky", "unspecified", 45.0, None, [], None),
    ("canadian-club", "Canadian Club", "Canadian Club", "1858", "canadianWhisky", "unspecified", 40.0, None, [], None),
    ("lot-40", "Hiram Walker", "Lot No. 40", "Canadian Rye", "canadianWhisky", "unspecified", 43.0, None, [], None),
    ("pendleton", "Pendleton", "Pendleton", "Blended Canadian Whisky", "canadianWhisky", "unspecified", 40.0, None, [], None),
    ("forty-creek-barrel-select", "Forty Creek", "Forty Creek", "Barrel Select", "canadianWhisky", "unspecified", 40.0, None, [], None),

    # ------------------------------------------------------------- More Scotch
    ("ardbeg-wee-beastie", "Ardbeg", "Ardbeg", "Wee Beastie 5 Year", "singleMaltScotch", "unspecified", 47.4, 5, [], None),
    ("ardbeg-an-oa", "Ardbeg", "Ardbeg", "An Oa", "singleMaltScotch", "unspecified", 46.6, None, [], None),
    ("lagavulin-distillers-edition", "Lagavulin", "Lagavulin", "Distillers Edition", "singleMaltScotch", "unspecified", 43.0, None, [], None),
    ("glenfiddich-14", "William Grant", "Glenfiddich", "14 Year Bourbon Barrel Reserve", "singleMaltScotch", "unspecified", 43.0, 14, [], None),
    ("macallan-rare-cask", "The Macallan", "The Macallan", "Rare Cask", "singleMaltScotch", "unspecified", 43.0, None, [], None),
    ("balvenie-15-single-barrel", "William Grant", "The Balvenie", "15 Year Single Barrel Sherry Cask", "singleMaltScotch", "singleCask", 47.8, 15, [], None),
    ("glenallachie-12", "GlenAllachie", "GlenAllachie", "12 Year", "singleMaltScotch", "unspecified", 46.0, 12, [], None),
    ("deanston-12", "Deanston", "Deanston", "12 Year", "singleMaltScotch", "unspecified", 46.3, 12, [], None),
    ("old-pulteney-12", "Old Pulteney", "Old Pulteney", "12 Year", "singleMaltScotch", "unspecified", 40.0, 12, [], None),
    ("ledaig-10", "Tobermory", "Ledaig", "10 Year", "singleMaltScotch", "unspecified", 46.3, 10, [], None),
    ("tobermory-12", "Tobermory", "Tobermory", "12 Year", "singleMaltScotch", "unspecified", 46.3, 12, [], None),
    ("compass-box-peat-monster", "Compass Box", "Compass Box", "The Peat Monster", "blendedMaltScotch", "unspecified", 46.0, None, [], None),
    ("compass-box-spice-tree", "Compass Box", "Compass Box", "The Spice Tree", "blendedMaltScotch", "unspecified", 46.0, None, [], None),
    ("glengoyne-12", "Glengoyne", "Glengoyne", "12 Year", "singleMaltScotch", "unspecified", 43.0, 12, [], None),
    ("tamdhu-12", "Tamdhu", "Tamdhu", "12 Year", "singleMaltScotch", "unspecified", 43.0, 12, [], None),
    ("benromach-10", "Benromach", "Benromach", "10 Year", "singleMaltScotch", "unspecified", 43.0, 10, [], None),
    ("bruichladdich-islay-barley", "Bruichladdich", "Bruichladdich", "Islay Barley", "singleMaltScotch", "unspecified", 50.0, None, [], None),
    ("jw-red", "Johnnie Walker", "Johnnie Walker", "Red Label", "blendedScotch", "unspecified", 40.0, None, [], None),
    ("jw-gold-reserve", "Johnnie Walker", "Johnnie Walker", "Gold Label Reserve", "blendedScotch", "unspecified", 40.0, None, [], None),
    ("chivas-18", "Chivas Brothers", "Chivas Regal", "18 Year", "blendedScotch", "unspecified", 40.0, 18, [], None),
    ("dalmore-15", "The Dalmore", "The Dalmore", "15 Year", "singleMaltScotch", "unspecified", 40.0, 15, [], None),
    ("glenmorangie-quinta-ruban", "Glenmorangie", "Glenmorangie", "Quinta Ruban 14 Year", "singleMaltScotch", "unspecified", 46.0, 14, [], None),
    ("ardmore-legacy", "Ardmore", "Ardmore", "Legacy", "singleMaltScotch", "unspecified", 40.0, None, [], None),
    ("ancnoc-12", "Knockdhu", "anCnoc", "12 Year", "singleMaltScotch", "unspecified", 40.0, 12, [], None),
    ("auchentoshan-three-wood", "Auchentoshan", "Auchentoshan", "Three Wood", "singleMaltScotch", "unspecified", 43.0, None, [], None),
    ("glenkinchie-12", "Glenkinchie", "Glenkinchie", "12 Year", "singleMaltScotch", "unspecified", 43.0, 12, [], None),
    ("cragganmore-12", "Cragganmore", "Cragganmore", "12 Year", "singleMaltScotch", "unspecified", 40.0, 12, [], None),
    ("dalwhinnie-15", "Dalwhinnie", "Dalwhinnie", "15 Year", "singleMaltScotch", "unspecified", 43.0, 15, [], None),
    ("clynelish-14", "Clynelish", "Clynelish", "14 Year", "singleMaltScotch", "unspecified", 46.0, 14, [], None),
    ("springbank-15", "Springbank", "Springbank", "15 Year", "singleMaltScotch", "unspecified", 46.0, 15, [], None),
    ("kilkerran-12", "Glengyle", "Kilkerran", "12 Year", "singleMaltScotch", "unspecified", 46.0, 12, [], None),
    ("bunnahabhain-18", "Bunnahabhain", "Bunnahabhain", "18 Year", "singleMaltScotch", "unspecified", 46.3, 18, [], None),
    ("bowmore-15", "Bowmore", "Bowmore", "15 Year", "singleMaltScotch", "unspecified", 43.0, 15, [], None),

    # -------------------------------------------------------------- More Irish
    ("redbreast-lustau", "Midleton", "Redbreast", "Lustau Edition", "singlePotStillIrish", "unspecified", 46.0, None, [], None),
    ("redbreast-21", "Midleton", "Redbreast", "21 Year", "singlePotStillIrish", "unspecified", 46.0, 21, [], None),
    ("green-spot-leoville-barton", "Midleton", "Green Spot", "Château Léoville Barton", "singlePotStillIrish", "unspecified", 46.0, None, [], None),
    ("powers-three-swallow", "Midleton", "Powers", "Three Swallow", "singlePotStillIrish", "unspecified", 43.2, None, [], None),
    ("method-and-madness-pot-still", "Midleton", "Method and Madness", "Single Pot Still", "singlePotStillIrish", "unspecified", 46.0, None, [], None),
    ("teeling-single-malt", "Teeling", "Teeling", "Single Malt", "singleMaltIrish", "unspecified", 46.0, None, [], None),
    ("teeling-single-pot-still", "Teeling", "Teeling", "Single Pot Still", "singlePotStillIrish", "unspecified", 46.0, None, [], None),
    ("knappogue-castle-12", "Knappogue Castle", "Knappogue Castle", "12 Year", "singleMaltIrish", "unspecified", 43.0, 12, [], None),
    ("connemara-peated", "Cooley", "Connemara", "Peated Single Malt", "singleMaltIrish", "unspecified", 40.0, None, [], None),
    ("bushmills-16", "Bushmills", "Bushmills", "16 Year Single Malt", "singleMaltIrish", "unspecified", 40.0, 16, [], None),
    ("bushmills-21", "Bushmills", "Bushmills", "21 Year Single Malt", "singleMaltIrish", "unspecified", 40.0, 21, [], None),
    ("jameson-caskmates-stout", "Midleton", "Jameson", "Caskmates Stout Edition", "irishWhiskey", "unspecified", 40.0, None, [], None),
    ("writers-tears-copper-pot", "Walsh Whiskey", "Writers' Tears", "Copper Pot", "irishWhiskey", "unspecified", 40.0, None, [], None),
    ("roe-and-co", "Roe & Co", "Roe & Co", "Blended Irish Whiskey", "irishWhiskey", "unspecified", 45.0, None, [], None),
    ("slane", "Slane", "Slane", "Triple Casked", "irishWhiskey", "unspecified", 40.0, None, [], None),
    ("tullamore-dew-12", "Tullamore", "Tullamore D.E.W.", "12 Year Special Reserve", "irishWhiskey", "unspecified", 40.0, 12, [], None),

    # ----------------------------------------------------------- More Japanese
    ("hakushu-distillers-reserve", "Suntory", "Hakushu", "Distiller's Reserve", "japaneseWhisky", "unspecified", 43.0, None, [], None),
    ("yamazaki-distillers-reserve", "Suntory", "Yamazaki", "Distiller's Reserve", "japaneseWhisky", "unspecified", 43.0, None, [], None),
    ("hibiki-21", "Suntory", "Hibiki", "21 Year", "japaneseWhisky", "unspecified", 43.0, 21, [], None),
    ("nikka-taketsuru", "Nikka", "Nikka", "Taketsuru Pure Malt", "japaneseWhisky", "unspecified", 43.0, None, [], None),
    ("nikka-yoichi", "Nikka", "Nikka", "Yoichi Single Malt", "japaneseWhisky", "unspecified", 45.0, None, [], None),
    ("nikka-miyagikyo", "Nikka", "Nikka", "Miyagikyo Single Malt", "japaneseWhisky", "unspecified", 45.0, None, [], None),
    ("nikka-days", "Nikka", "Nikka", "Days", "japaneseWhisky", "unspecified", 40.0, None, [], None),
    ("mars-iwai-tradition", "Mars Shinshu", "Mars", "Iwai Tradition", "japaneseWhisky", "unspecified", 40.0, None, [], None),
    ("akashi-white-oak", "Eigashima", "Akashi", "White Oak", "japaneseWhisky", "unspecified", 40.0, None, [], None),
    ("kaiyo-mizunara", "Kaiyo", "Kaiyō", "The Signature Mizunara Oak", "japaneseWhisky", "unspecified", 43.0, None, [], None),

    # -------------------------------------------------------------- More agave
    ("don-julio-1942", "Don Julio", "Don Julio", "1942", "tequilaAnejo", "unspecified", 40.0, None, [], None),
    ("don-julio-70", "Don Julio", "Don Julio", "70 Cristalino", "tequilaAnejo", "unspecified", 40.0, None, [], None),
    ("patron-silver", "Patrón", "Patrón", "Silver", "tequilaBlanco", "unspecified", 40.0, None, [], None),
    ("patron-reposado", "Patrón", "Patrón", "Reposado", "tequilaReposado", "unspecified", 40.0, None, [], None),
    ("patron-anejo", "Patrón", "Patrón", "Añejo", "tequilaAnejo", "unspecified", 40.0, None, [], None),
    ("casamigos-blanco", "Casamigos", "Casamigos", "Blanco", "tequilaBlanco", "unspecified", 40.0, None, [], None),
    ("casamigos-reposado", "Casamigos", "Casamigos", "Reposado", "tequilaReposado", "unspecified", 40.0, None, [], None),
    ("casamigos-anejo", "Casamigos", "Casamigos", "Añejo", "tequilaAnejo", "unspecified", 40.0, None, [], None),
    ("clase-azul-reposado", "Clase Azul", "Clase Azul", "Reposado", "tequilaReposado", "unspecified", 40.0, None, [], None),
    ("herradura-silver", "Herradura", "Herradura", "Silver", "tequilaBlanco", "unspecified", 40.0, None, [], None),
    ("herradura-anejo", "Herradura", "Herradura", "Añejo", "tequilaAnejo", "unspecified", 40.0, None, [], None),
    ("el-tesoro-blanco", "El Tesoro", "El Tesoro", "Blanco", "tequilaBlanco", "unspecified", 40.0, None, [], None),
    ("el-tesoro-reposado", "El Tesoro", "El Tesoro", "Reposado", "tequilaReposado", "unspecified", 40.0, None, [], None),
    ("siete-leguas-blanco", "Siete Leguas", "Siete Leguas", "Blanco", "tequilaBlanco", "unspecified", 40.0, None, [], None),
    ("cazadores-reposado", "Cazadores", "Cazadores", "Reposado", "tequilaReposado", "unspecified", 40.0, None, [], None),
    ("olmeca-altos-plata", "Olmeca Altos", "Olmeca Altos", "Plata", "tequilaBlanco", "unspecified", 40.0, None, [], None),
    ("espolon-anejo", "Espolon", "Espolon", "Añejo", "tequilaAnejo", "unspecified", 40.0, None, [], None),
    ("fortaleza-still-strength", "Fortaleza", "Fortaleza", "Blanco Still Strength", "tequilaBlanco", "unspecified", 46.0, None, [], None),
    ("tequila-ocho-reposado", "Tequila Ocho", "Tequila Ocho", "Reposado", "tequilaReposado", "unspecified", 40.0, None, [], None),
    ("g4-blanco", "G4", "G4", "Blanco", "tequilaBlanco", "unspecified", 40.0, None, [], None),
    ("cimarron-blanco", "Cimarrón", "Cimarrón", "Blanco", "tequilaBlanco", "unspecified", 40.0, None, [], None),
    ("ilegal-joven", "Ilegal", "Ilegal", "Joven", "mezcal", "unspecified", 40.0, None, [], None),
    ("ilegal-reposado", "Ilegal", "Ilegal", "Reposado", "mezcal", "unspecified", 40.0, None, [], None),
    ("bozal-ensamble", "Bozal", "Bozal", "Ensamble", "mezcal", "unspecified", 47.0, None, [], None),
    ("los-vecinos-espadin", "Los Vecinos del Campo", "Los Vecinos del Campo", "Espadín", "mezcal", "unspecified", 45.0, None, [], None),
    ("banhez-ensamble", "Banhez", "Banhez", "Ensamble", "mezcal", "unspecified", 42.0, None, [], None),
    ("casamigos-mezcal", "Casamigos", "Casamigos", "Mezcal Joven", "mezcal", "unspecified", 40.0, None, [], None),
    ("el-silencio-espadin", "El Silencio", "El Silencio", "Espadín", "mezcal", "unspecified", 43.0, None, [], None),

    # ---------------------------------------------------------------- More rum
    ("bacardi-superior", "Bacardí", "Bacardí", "Superior", "rum", "unspecified", 40.0, None, [], None),
    ("bacardi-8", "Bacardí", "Bacardí", "Reserva Ocho", "rum", "unspecified", 40.0, 8, [], None),
    ("kraken-black-spiced", "Kraken", "The Kraken", "Black Spiced", "rum", "unspecified", 47.0, None, [], None),
    ("zacapa-23", "Ron Zacapa", "Ron Zacapa", "Centenario 23", "rum", "unspecified", 40.0, None, [], None),
    ("diplomatico-planas", "Diplomatico", "Diplomatico", "Planas", "rum", "unspecified", 47.0, None, [], None),
    ("plantation-3-stars", "Plantation", "Plantation", "3 Stars", "rum", "unspecified", 41.2, None, [], None),
    ("plantation-xo-20th", "Plantation", "Plantation", "XO 20th Anniversary", "rum", "unspecified", 40.0, None, [], None),
    ("plantation-original-dark", "Plantation", "Plantation", "Original Dark", "rum", "unspecified", 40.0, None, [], None),
    ("doorlys-xo", "Foursquare", "Doorly's", "XO", "rum", "unspecified", 40.0, None, [], None),
    ("doorlys-12", "Foursquare", "Doorly's", "12 Year", "rum", "unspecified", 40.0, 12, [], None),
    ("foursquare-probitas", "Foursquare", "Foursquare", "Probitas", "rum", "unspecified", 47.0, None, [], None),
    ("mount-gay-eclipse", "Mount Gay", "Mount Gay", "Eclipse", "rum", "unspecified", 40.0, None, [], None),
    ("appleton-8", "Appleton Estate", "Appleton Estate", "8 Year Reserve", "rum", "unspecified", 43.0, 8, [], None),
    ("appleton-15", "Appleton Estate", "Appleton Estate", "15 Year Black River Casks", "rum", "unspecified", 43.0, 15, [], None),
    ("hamilton-86-demerara", "Hamilton", "Hamilton", "86 Demerara", "rum", "unspecified", 43.0, None, [], None),
    ("clement-vsop", "Rhum Clément", "Rhum Clément", "VSOP", "rhumAgricole", "unspecified", 40.0, None, [], None),
    ("rhum-jm-white-50", "Rhum J.M", "Rhum J.M", "Blanc 50", "rhumAgricole", "unspecified", 50.0, None, [], None),
    ("barbancourt-8", "Barbancourt", "Barbancourt", "Réserve Spéciale 8 Year", "rum", "unspecified", 43.0, 8, [], None),
    ("flor-de-cana-18", "Flor de Caña", "Flor de Caña", "18 Year", "rum", "unspecified", 40.0, 18, [], None),
    ("flor-de-cana-4", "Flor de Caña", "Flor de Caña", "4 Year Extra Seco", "rum", "unspecified", 40.0, 4, [], None),
    ("angostura-1919", "Angostura", "Angostura", "1919", "rum", "unspecified", 40.0, None, [], None),
    ("angostura-7", "Angostura", "Angostura", "7 Year", "rum", "unspecified", 40.0, 7, [], None),
    ("pussers-blue-label", "Pusser's", "Pusser's", "Blue Label", "rum", "unspecified", 42.0, None, [], None),
    ("goslings-black-seal", "Goslings", "Goslings", "Black Seal", "rum", "unspecified", 40.0, None, [], None),
    ("myerss-dark", "Myers's", "Myers's", "Original Dark", "rum", "unspecified", 40.0, None, [], None),
    ("sailor-jerry", "Sailor Jerry", "Sailor Jerry", "Spiced", "rum", "unspecified", 46.0, None, [], None),

    # ---------------------------------------------------------------- More gin
    ("tanqueray-rangpur", "Tanqueray", "Tanqueray", "Rangpur", "distilledGin", "unspecified", 41.3, None, [], None),
    ("gordons", "Gordon's", "Gordon's", "London Dry", "londonDryGin", "unspecified", 40.0, None, [], None),
    ("beefeater-24", "Beefeater", "Beefeater", "24", "londonDryGin", "unspecified", 45.0, None, [], None),
    ("hendricks-orbium", "Hendrick's", "Hendrick's", "Orbium", "distilledGin", "unspecified", 43.4, None, [], None),
    ("the-botanist", "Bruichladdich", "The Botanist", "Islay Dry Gin", "distilledGin", "unspecified", 46.0, None, [], None),
    ("nolets-silver", "Nolet", "Nolet's", "Silver", "distilledGin", "unspecified", 47.6, None, [], None),
    ("citadelle", "Citadelle", "Citadelle", "Original", "distilledGin", "unspecified", 44.0, None, [], None),
    ("st-george-terroir", "St. George", "St. George", "Terroir", "distilledGin", "unspecified", 45.0, None, [], None),
    ("st-george-botanivore", "St. George", "St. George", "Botanivore", "distilledGin", "unspecified", 45.0, None, [], None),
    ("empress-1908", "Victoria Distillers", "Empress 1908", "Indigo", "distilledGin", "unspecified", 42.5, None, [], None),
    ("malfy-con-limone", "Malfy", "Malfy", "Con Limone", "distilledGin", "unspecified", 41.0, None, [], None),
    ("ki-no-bi", "Kyoto Distillery", "Ki No Bi", "Kyoto Dry Gin", "distilledGin", "unspecified", 45.7, None, [], None),
    ("gin-mare", "Gin Mare", "Gin Mare", "Mediterranean", "distilledGin", "unspecified", 42.7, None, [], None),
    ("sipsmith-vjop", "Sipsmith", "Sipsmith", "V.J.O.P.", "londonDryGin", "unspecified", 57.7, None, [], None),
    ("plymouth-navy-strength", "Plymouth", "Plymouth", "Navy Strength", "distilledGin", "unspecified", 57.0, None, [], None),
    ("junipero", "Hotaling & Co", "Junípero", "Gin", "distilledGin", "unspecified", 49.3, None, [], None),
    ("bluecoat", "Philadelphia Distilling", "Bluecoat", "American Dry Gin", "distilledGin", "unspecified", 47.0, None, [], None),
    ("brooklyn-gin", "Brooklyn Gin", "Brooklyn Gin", "", "distilledGin", "unspecified", 40.0, None, [], None),
    ("drumshanbo-gunpowder", "The Shed Distillery", "Drumshanbo", "Gunpowder Irish Gin", "distilledGin", "unspecified", 43.0, None, [], None),

    # -------------------------------------------------------------- More vodka
    ("absolut", "Absolut", "Absolut", "", "vodka", "unspecified", 40.0, None, [], None),
    ("smirnoff-21", "Smirnoff", "Smirnoff", "No. 21", "vodka", "unspecified", 40.0, None, [], None),
    ("stolichnaya", "Stolichnaya", "Stolichnaya", "", "vodka", "unspecified", 40.0, None, [], None),
    ("chopin-potato", "Chopin", "Chopin", "Potato", "vodka", "unspecified", 40.0, None, [], None),
    ("reyka", "Reyka", "Reyka", "", "vodka", "unspecified", 40.0, None, [], None),
    ("haku", "Suntory", "Haku", "", "vodka", "unspecified", 40.0, None, [], None),
    ("ciroc", "Cîroc", "Cîroc", "", "vodka", "unspecified", 40.0, None, [], None),
    ("skyy", "Skyy", "Skyy", "", "vodka", "unspecified", 40.0, None, [], None),

    # ------------------------------------------------------------- More brandy
    ("hennessy-xo", "Hennessy", "Hennessy", "XO", "cognac", "unspecified", 40.0, None, [], None),
    ("remy-1738", "Rémy Martin", "Rémy Martin", "1738 Accord Royal", "cognac", "unspecified", 40.0, None, [], None),
    ("martell-cordon-bleu", "Martell", "Martell", "Cordon Bleu", "cognac", "unspecified", 40.0, None, [], None),
    ("courvoisier-vsop", "Courvoisier", "Courvoisier", "VSOP", "cognac", "unspecified", 40.0, None, [], None),
    ("courvoisier-xo", "Courvoisier", "Courvoisier", "XO", "cognac", "unspecified", 40.0, None, [], None),
    ("camus-vsop", "Camus", "Camus", "VSOP", "cognac", "unspecified", 40.0, None, [], None),
    ("delamain-pale-dry", "Delamain", "Delamain", "Pale & Dry XO", "cognac", "unspecified", 42.0, None, [], None),
    ("frapin-vsop", "Frapin", "Frapin", "VSOP", "cognac", "unspecified", 40.0, None, [], None),
    ("hine-rare-vsop", "Hine", "Hine", "Rare VSOP", "cognac", "unspecified", 40.0, None, [], None),
    ("pierre-ferrand-ambre", "Pierre Ferrand", "Pierre Ferrand", "Ambre", "cognac", "unspecified", 40.0, None, [], None),
    ("pierre-ferrand-reserve", "Pierre Ferrand", "Pierre Ferrand", "Réserve", "cognac", "unspecified", 40.0, None, [], None),
    ("tariquet-vsop", "Château du Tariquet", "Tariquet", "VSOP Bas-Armagnac", "armagnac", "unspecified", 40.0, None, [], None),
    ("delord-25", "Delord", "Delord", "25 Year Bas-Armagnac", "armagnac", "unspecified", 40.0, 25, [], None),
    ("drouin-pays-dauge-vsop", "Christian Drouin", "Christian Drouin", "Pays d'Auge VSOP", "calvados", "unspecified", 40.0, None, [], None),
    ("boulard-vsop", "Boulard", "Boulard", "VSOP Pays d'Auge", "calvados", "unspecified", 40.0, None, [], None),
    ("lairds-applejack", "Laird & Company", "Laird's", "Applejack", "brandy", "unspecified", 40.0, None, [], None),
    ("lairds-bib-apple-brandy", "Laird & Company", "Laird's", "Straight Apple Brandy Bottled in Bond", "brandy", "unspecified", 50.0, None, [BIB], None),
    ("copper-and-kings-brandy", "Copper & Kings", "Copper & Kings", "American Craft Brandy", "brandy", "unspecified", 45.0, None, [], None),
    ("germain-robin-alambic", "Germain-Robin", "Germain-Robin", "Fine Alambic Brandy", "brandy", "unspecified", 40.0, None, [], None),
    ("pisco-porton", "Caravedo", "Pisco Portón", "Mosto Verde", "pisco", "unspecified", 43.0, None, [], None),
    ("capel-pisco", "Capel", "Capel", "Pisco Especial", "pisco", "unspecified", 40.0, None, [], None),
    ("metaxa-7", "Metaxa", "Metaxa", "7 Stars", "brandy", "unspecified", 40.0, None, [], None),

    # ------------------------------------------- More liqueur, amaro, vermouth
    ("amaro-montenegro", "Montenegro", "Amaro Montenegro", "", "amaro", "unspecified", 23.0, None, [], None),
    ("amaro-lucano", "Lucano", "Amaro Lucano", "", "amaro", "unspecified", 28.0, None, [], None),
    ("ramazzotti", "Ramazzotti", "Ramazzotti", "Amaro", "amaro", "unspecified", 30.0, None, [], None),
    ("meletti", "Meletti", "Meletti", "Amaro", "amaro", "unspecified", 32.0, None, [], None),
    ("braulio", "Braulio", "Braulio", "Amaro Alpino", "amaro", "unspecified", 21.0, None, [], None),
    ("amaro-ciociaro", "Paolucci", "Amaro CioCiaro", "", "amaro", "unspecified", 30.0, None, [], None),
    ("amaro-dell-etna", "Amaro dell'Etna", "Amaro dell'Etna", "", "amaro", "unspecified", 29.0, None, [], None),
    ("fernet-branca-menta", "Fratelli Branca", "Fernet-Branca", "Menta", "amaro", "unspecified", 28.0, None, [], None),
    ("cynar-70", "Campari Group", "Cynar", "70 Proof", "amaro", "unspecified", 35.0, None, [], None),
    ("select-aperitivo", "Select", "Select", "Aperitivo", "amaro", "unspecified", 17.5, None, [], None),
    ("suze", "Suze", "Suze", "", "liqueur", "unspecified", 20.0, None, [], None),
    ("lillet-blanc", "Lillet", "Lillet", "Blanc", "vermouth", "unspecified", 17.0, None, [], None),
    ("cocchi-americano", "Cocchi", "Cocchi", "Americano", "vermouth", "unspecified", 16.5, None, [], None),
    ("punt-e-mes", "Carpano", "Punt e Mes", "", "vermouth", "unspecified", 16.0, None, [], None),
    ("dolin-rouge", "Dolin", "Dolin", "Rouge", "vermouth", "unspecified", 16.0, None, [], None),
    ("dolin-blanc", "Dolin", "Dolin", "Blanc", "vermouth", "unspecified", 16.0, None, [], None),
    ("noilly-prat-extra-dry", "Noilly Prat", "Noilly Prat", "Extra Dry", "vermouth", "unspecified", 18.0, None, [], None),
    ("drambuie", "Drambuie", "Drambuie", "", "liqueur", "unspecified", 40.0, None, [], None),
    ("frangelico", "Frangelico", "Frangelico", "", "liqueur", "unspecified", 20.0, None, [], None),
    ("disaronno", "Disaronno", "Disaronno", "Originale", "liqueur", "unspecified", 28.0, None, [], None),
    ("kahlua", "Kahlúa", "Kahlúa", "", "liqueur", "unspecified", 20.0, None, [], None),
    ("baileys", "Baileys", "Baileys", "Original Irish Cream", "liqueur", "unspecified", 17.0, None, [], None),
    ("chambord", "Chambord", "Chambord", "", "liqueur", "unspecified", 16.5, None, [], None),
    ("ancho-reyes", "Ancho Reyes", "Ancho Reyes", "Original", "liqueur", "unspecified", 40.0, None, [], None),
    ("genepy-le-chamois", "Dolin", "Génépy le Chamois", "", "liqueur", "unspecified", 40.0, None, [], None),
    ("strega", "Alberti", "Strega", "", "liqueur", "unspecified", 40.0, None, [], None),
    ("galliano", "Galliano", "Galliano", "L'Autentico", "liqueur", "unspecified", 42.3, None, [], None),
    ("romana-sambuca", "Romana", "Romana", "Sambuca", "liqueur", "unspecified", 40.0, None, [], None),
    ("licor-43", "Diego Zamora", "Licor 43", "", "liqueur", "unspecified", 31.0, None, [], None),
    ("pimms-no-1", "Pimm's", "Pimm's", "No. 1", "liqueur", "unspecified", 25.0, None, [], None),
    ("cherry-heering", "Heering", "Cherry Heering", "", "liqueur", "unspecified", 24.0, None, [], None),
    ("pernod", "Pernod", "Pernod", "Anise", "liqueur", "unspecified", 40.0, None, [], None),
    ("st-george-absinthe", "St. George", "St. George", "Absinthe Verte", "absinthe", "unspecified", 60.0, None, [], None),
    ("pernod-absinthe", "Pernod", "Pernod", "Absinthe", "absinthe", "unspecified", 68.0, None, [], None),
    ("lucid-absinthe", "Lucid", "Lucid", "Absinthe Supérieure", "absinthe", "unspecified", 62.0, None, [], None),
    ("linie-aquavit", "Arcus", "Linie", "Aquavit", "aquavit", "unspecified", 41.5, None, [], None),
    ("aalborg-taffel", "Aalborg", "Aalborg", "Taffel", "aquavit", "unspecified", 45.0, None, [], None),
    ("krogstad-aquavit", "House Spirits", "Krogstad", "Festlig Aquavit", "aquavit", "unspecified", 40.0, None, [], None),

    # ------------------------------------------- The bottles every shop has
    # The catalogue was built by somebody who knows bourbon, and it showed.
    # 112 Kentucky straight bourbons, five E.H. Taylors, the whole Antique
    # Collection -- and no Captain Morgan, no Jose Cuervo, no Fireball, no
    # Jagermeister. Those outsell every bottle above them put together. A
    # shelf check that cannot find Captain Morgan is not a shelf check,
    # however many store picks it knows.
    #
    # Nothing here is exciting. That is the point.
    ("captain-morgan-spiced", "Captain Morgan", "Captain Morgan", "Original Spiced", "flavoredRum", "unspecified", 35.0, None, [], None),
    ("havana-club-7", "Havana Club", "Havana Club", "Anejo 7 Anos", "rum", "unspecified", 40.0, 7, [], None),
    ("don-q-cristal", "Destileria Serralles", "Don Q", "Cristal", "rum", "unspecified", 40.0, None, [], None),
    ("brugal-1888", "Brugal", "Brugal", "1888 Gran Reserva", "rum", "unspecified", 40.0, None, [], None),
    ("santa-teresa-1796", "Santa Teresa", "Santa Teresa", "1796", "rum", "unspecified", 40.0, None, [], None),
    ("ron-barcelo-imperial", "Ron Barcelo", "Ron Barcelo", "Imperial", "rum", "unspecified", 40.0, None, [], None),
    ("cuervo-especial-silver", "Jose Cuervo", "Jose Cuervo", "Especial Silver", "tequilaBlanco", "unspecified", 40.0, None, [], None),
    ("cuervo-tradicional-reposado", "Jose Cuervo", "Jose Cuervo", "Tradicional Reposado", "tequilaReposado", "unspecified", 40.0, None, [], None),
    ("1800-silver", "Jose Cuervo", "1800", "Silver", "tequilaBlanco", "unspecified", 40.0, None, [], None),
    ("hornitos-plata", "Sauza", "Hornitos", "Plata", "tequilaBlanco", "unspecified", 40.0, None, [], None),
    ("sauza-silver", "Sauza", "Sauza", "Silver", "tequilaBlanco", "unspecified", 40.0, None, [], None),
    ("milagro-silver", "Milagro", "Milagro", "Silver", "tequilaBlanco", "unspecified", 40.0, None, [], None),
    ("teremana-blanco", "Teremana", "Teremana", "Blanco", "tequilaBlanco", "unspecified", 40.0, None, [], None),
    ("tapatio-blanco", "La Alteria", "Tapatio", "Blanco", "tequilaBlanco", "unspecified", 40.0, None, [], None),
    ("lalo-blanco", "LALO", "LALO", "Blanco", "tequilaBlanco", "unspecified", 40.0, None, [], None),
    ("codigo-1530-blanco", "Codigo 1530", "Codigo 1530", "Blanco", "tequilaBlanco", "unspecified", 40.0, None, [], None),
    ("volcan-blanco", "Volcan de mi Tierra", "Volcan", "Blanco", "tequilaBlanco", "unspecified", 40.0, None, [], None),
    ("herradura-suprema", "Herradura", "Herradura", "Seleccion Suprema", "tequilaExtraAnejo", "unspecified", 40.0, None, [], None),
    ("fireball", "Sazerac", "Fireball", "Cinnamon Whisky", "liqueur", "unspecified", 33.0, None, [], None),
    ("jagermeister", "Mast-Jaegermeister", "Jagermeister", "", "liqueur", "unspecified", 35.0, None, [], None),
    ("malibu", "Malibu", "Malibu", "Original Coconut", "liqueur", "unspecified", 21.0, None, [], None),
    ("southern-comfort", "Southern Comfort", "Southern Comfort", "Original", "liqueur", "unspecified", 35.0, None, [], None),
    ("midori", "Suntory", "Midori", "Melon", "liqueur", "unspecified", 20.0, None, [], None),
    ("rumchata", "RumChata", "RumChata", "", "liqueur", "unspecified", 13.75, None, [], None),
    ("tia-maria", "Tia Maria", "Tia Maria", "", "liqueur", "unspecified", 20.0, None, [], None),
    ("luxardo-limoncello", "Luxardo", "Luxardo", "Limoncello", "liqueur", "unspecified", 27.0, None, [], None),
    ("ouzo-12", "Ouzo 12", "Ouzo 12", "", "liqueur", "unspecified", 40.0, None, [], None),
    ("amarula", "Amarula", "Amarula", "Cream", "liqueur", "unspecified", 17.0, None, [], None),
    ("screwball", "Screwball", "Screwball", "Peanut Butter Whiskey", "liqueur", "unspecified", 35.0, None, [], None),
    ("svedka", "Svedka", "Svedka", "", "vodka", "unspecified", 40.0, None, [], None),
    ("new-amsterdam-vodka", "New Amsterdam", "New Amsterdam", "Original", "vodka", "unspecified", 40.0, None, [], None),
    ("deep-eddy-vodka", "Deep Eddy", "Deep Eddy", "Original", "vodka", "unspecified", 40.0, None, [], None),
    ("russian-standard", "Russian Standard", "Russian Standard", "Original", "vodka", "unspecified", 40.0, None, [], None),
    ("pinnacle-vodka", "Pinnacle", "Pinnacle", "Original", "vodka", "unspecified", 40.0, None, [], None),
    ("three-olives", "Three Olives", "Three Olives", "Original", "vodka", "unspecified", 40.0, None, [], None),
    ("seagrams-extra-dry-gin", "Seagram's", "Seagram's", "Extra Dry", "distilledGin", "unspecified", 40.0, None, [], None),
    ("bols-genever", "Lucas Bols", "Bols", "Genever", "genever", "unspecified", 42.0, None, [], None),
    ("glen-scotia-double-cask", "Glen Scotia", "Glen Scotia", "Double Cask", "singleMaltScotch", "unspecified", 46.0, None, [], None),
    ("cameron-brig", "Cameronbridge", "Cameron Brig", "", "singleGrainScotch", "unspecified", 40.0, None, [], None),
    ("haig-club-clubman", "Cameronbridge", "Haig Club", "Clubman", "singleGrainScotch", "unspecified", 40.0, None, [], None),
    ("jp-wisers-deluxe", "Hiram Walker", "J.P. Wiser's", "Deluxe", "canadianWhisky", "unspecified", 40.0, None, [], None),
    ("pike-creek-10", "Hiram Walker", "Pike Creek", "10 Year", "canadianWhisky", "unspecified", 42.0, 10, [], None),
    ("goose-island-bcbs", "Goose Island", "Goose Island", "Bourbon County Brand Stout", "maltBeverage", "unspecified", 14.7, None, [], None),

    # -------------------------------- The back bar and the flavoured shelf
    # Two things were missing that a shop devotes whole aisles to.
    #
    # The cocktail bottles: curacao, maraschino, creme de violette,
    # falernum, allspice dram, both Chartreuses. Somebody who owns a
    # shaker owns most of them, and the app knew none.
    #
    # The flavoured shelf: Tennessee Honey, Crown Royal Apple, Absolut
    # Citron. These need flavoredWhiskey and flavoredVodka to be listed
    # honestly -- TTB's Class 9 is bottled at 30%, and calling a 35%
    # Tennessee Honey a weak whiskey or a strong liqueur would both be
    # wrong.
    ("pierre-ferrand-dry-curacao", "Pierre Ferrand", "Pierre Ferrand", "Dry Curacao", "liqueur", "unspecified", 40.0, None, [], None),
    ("rothman-creme-de-violette", "Rothman and Winter", "Rothman and Winter", "Creme de Violette", "liqueur", "unspecified", 20.0, None, [], None),
    ("tempus-fugit-creme-de-cacao", "Tempus Fugit", "Tempus Fugit", "Creme de Cacao", "liqueur", "unspecified", 24.0, None, [], None),
    ("tempus-fugit-creme-de-menthe", "Tempus Fugit", "Tempus Fugit", "Creme de Menthe", "liqueur", "unspecified", 24.0, None, [], None),
    ("velvet-falernum", "John D. Taylor", "John D. Taylor", "Velvet Falernum", "liqueur", "unspecified", 11.0, None, [], None),
    ("st-elizabeth-allspice-dram", "St. Elizabeth", "St. Elizabeth", "Allspice Dram", "liqueur", "unspecified", 22.0, None, [], None),
    ("combier-triple-sec", "Combier", "Combier", "Liqueur d'Orange", "liqueur", "unspecified", 40.0, None, [], None),
    ("giffard-banane", "Giffard", "Giffard", "Banane du Bresil", "liqueur", "unspecified", 25.0, None, [], None),
    ("italicus", "Italicus", "Italicus", "Rosolio di Bergamotto", "liqueur", "unspecified", 20.0, None, [], None),
    ("amer-picon", "Picon", "Picon", "Amer", "amaro", "unspecified", 21.0, None, [], None),
    ("brancamenta", "Fratelli Branca", "Branca", "Brancamenta", "amaro", "unspecified", 28.0, None, [], None),
    ("jack-daniels-tennessee-honey", "Jack Daniel's", "Jack Daniel's", "Tennessee Honey", "flavoredWhiskey", "unspecified", 35.0, None, [], None),
    ("jack-daniels-tennessee-fire", "Jack Daniel's", "Jack Daniel's", "Tennessee Fire", "flavoredWhiskey", "unspecified", 35.0, None, [], None),
    ("jack-daniels-tennessee-apple", "Jack Daniel's", "Jack Daniel's", "Tennessee Apple", "flavoredWhiskey", "unspecified", 35.0, None, [], None),
    ("crown-royal-apple", "Crown Royal", "Crown Royal", "Regal Apple", "flavoredWhiskey", "unspecified", 35.0, None, [], None),
    ("crown-royal-peach", "Crown Royal", "Crown Royal", "Peach", "flavoredWhiskey", "unspecified", 35.0, None, [], None),
    ("crown-royal-vanilla", "Crown Royal", "Crown Royal", "Vanilla", "flavoredWhiskey", "unspecified", 35.0, None, [], None),
    ("jim-beam-honey", "Jim Beam", "Jim Beam", "Honey", "flavoredWhiskey", "unspecified", 32.5, None, [], None),
    ("jim-beam-apple", "Jim Beam", "Jim Beam", "Apple", "flavoredWhiskey", "unspecified", 32.5, None, [], None),
    ("evan-williams-honey", "Heaven Hill", "Evan Williams", "Honey", "flavoredWhiskey", "unspecified", 35.0, None, [], None),
    ("wild-turkey-american-honey", "Wild Turkey", "Wild Turkey", "American Honey", "flavoredWhiskey", "unspecified", 35.5, None, [], None),
    ("absolut-citron", "Absolut", "Absolut", "Citron", "flavoredVodka", "unspecified", 40.0, None, [], None),
    ("absolut-vanilia", "Absolut", "Absolut", "Vanilia", "flavoredVodka", "unspecified", 40.0, None, [], None),
    ("deep-eddy-lemon", "Deep Eddy", "Deep Eddy", "Lemon", "flavoredVodka", "unspecified", 35.0, None, [], None),
    ("deep-eddy-ruby-red", "Deep Eddy", "Deep Eddy", "Ruby Red", "flavoredVodka", "unspecified", 35.0, None, [], None),
    ("smirnoff-raspberry", "Smirnoff", "Smirnoff", "Raspberry", "flavoredVodka", "unspecified", 30.0, None, [], None),
    ("stoli-vanil", "Stolichnaya", "Stoli", "Vanil", "flavoredVodka", "unspecified", 37.5, None, [], None),
    ("ketel-one-botanical-cucumber", "Ketel One", "Ketel One", "Botanical Cucumber and Mint", "flavoredVodka", "unspecified", 30.0, None, [], None),
    ("new-amsterdam-pineapple", "New Amsterdam", "New Amsterdam", "Pineapple", "flavoredVodka", "unspecified", 35.0, None, [], None),
    ("haymans-old-tom", "Hayman's", "Hayman's", "Old Tom", "distilledGin", "unspecified", 41.4, None, [], None),
    ("ransom-old-tom", "Ransom", "Ransom", "Old Tom", "distilledGin", "unspecified", 43.8, None, [], None),
    ("perrys-tot-navy-strength", "New York Distilling", "Perry's Tot", "Navy Strength", "distilledGin", "unspecified", 57.0, None, [], None),
    ("four-pillars-rare-dry", "Four Pillars", "Four Pillars", "Rare Dry", "distilledGin", "unspecified", 41.8, None, [], None),
    ("brockmans", "Brockmans", "Brockmans", "Intensely Smooth", "distilledGin", "unspecified", 40.0, None, [], None),
    ("barr-hill-gin", "Caledonia Spirits", "Barr Hill", "Gin", "distilledGin", "unspecified", 45.0, None, [], None),
    ("bluecoat-gin", "Philadelphia Distilling", "Bluecoat", "American Dry", "distilledGin", "unspecified", 47.0, None, [], None),
    ("deaths-door-gin", "Death's Door", "Death's Door", "Gin", "distilledGin", "unspecified", 47.0, None, [], None),
    ("haymans-sloe-gin", "Hayman's", "Hayman's", "Sloe Gin", "liqueur", "unspecified", 26.0, None, [], None),

    # ------------------------------- Beer, cider and bourbon, by request
    # Beer went from three rows to a category. The macro lagers are here
    # because they are what is in most fridges and somebody logging a
    # shelf should not have to type Budweiser in by hand; the imperial
    # stouts because they are what sits beside a bourbon shelf.
    #
    # The bourbon added is the bonded and everyday end rather than more
    # allocated bottles. The catalogue already knew every bottle nobody
    # can buy; it did not know Evan Williams Bottled in Bond.
    ("budweiser", "Anheuser-Busch", "Budweiser", "", "maltBeverage", "unspecified", 5.0, None, [], None),
    ("bud-light", "Anheuser-Busch", "Bud Light", "", "maltBeverage", "unspecified", 4.2, None, [], None),
    ("michelob-ultra", "Anheuser-Busch", "Michelob", "Ultra", "maltBeverage", "unspecified", 4.2, None, [], None),
    ("coors-light", "Molson Coors", "Coors", "Light", "maltBeverage", "unspecified", 4.2, None, [], None),
    ("miller-lite", "Molson Coors", "Miller", "Lite", "maltBeverage", "unspecified", 4.2, None, [], None),
    ("miller-high-life", "Molson Coors", "Miller", "High Life", "maltBeverage", "unspecified", 4.6, None, [], None),
    ("blue-moon-belgian-white", "Molson Coors", "Blue Moon", "Belgian White", "maltBeverage", "unspecified", 5.4, None, [], None),
    ("corona-extra", "Grupo Modelo", "Corona", "Extra", "maltBeverage", "unspecified", 4.6, None, [], None),
    ("modelo-especial", "Grupo Modelo", "Modelo", "Especial", "maltBeverage", "unspecified", 4.4, None, [], None),
    ("negra-modelo", "Grupo Modelo", "Modelo", "Negra", "maltBeverage", "unspecified", 5.4, None, [], None),
    ("pacifico-clara", "Grupo Modelo", "Pacifico", "Clara", "maltBeverage", "unspecified", 4.4, None, [], None),
    ("dos-equis-lager", "Cuauhtemoc Moctezuma", "Dos Equis", "Lager Especial", "maltBeverage", "unspecified", 4.2, None, [], None),
    ("heineken", "Heineken", "Heineken", "", "maltBeverage", "unspecified", 5.0, None, [], None),
    ("stella-artois", "Stella Artois", "Stella Artois", "", "maltBeverage", "unspecified", 5.0, None, [], None),
    ("guinness-draught", "Guinness", "Guinness", "Draught", "maltBeverage", "unspecified", 4.2, None, [], None),
    ("pabst-blue-ribbon", "Pabst", "Pabst", "Blue Ribbon", "maltBeverage", "unspecified", 4.74, None, [], None),
    ("yuengling-lager", "Yuengling", "Yuengling", "Traditional Lager", "maltBeverage", "unspecified", 4.5, None, [], None),
    ("sam-adams-boston-lager", "Boston Beer Co.", "Samuel Adams", "Boston Lager", "maltBeverage", "unspecified", 5.0, None, [], None),
    ("sierra-nevada-pale-ale", "Sierra Nevada", "Sierra Nevada", "Pale Ale", "maltBeverage", "unspecified", 5.6, None, [], None),
    ("sierra-nevada-hazy-little-thing", "Sierra Nevada", "Sierra Nevada", "Hazy Little Thing", "maltBeverage", "unspecified", 6.7, None, [], None),
    ("bells-two-hearted", "Bell's", "Bell's", "Two Hearted Ale", "maltBeverage", "unspecified", 7.0, None, [], None),
    ("lagunitas-ipa", "Lagunitas", "Lagunitas", "IPA", "maltBeverage", "unspecified", 6.2, None, [], None),
    ("founders-all-day-ipa", "Founders", "Founders", "All Day IPA", "maltBeverage", "unspecified", 4.7, None, [], None),
    ("stone-ipa", "Stone", "Stone", "IPA", "maltBeverage", "unspecified", 6.9, None, [], None),
    ("new-belgium-fat-tire", "New Belgium", "New Belgium", "Fat Tire", "maltBeverage", "unspecified", 5.2, None, [], None),
    ("dogfish-60-minute", "Dogfish Head", "Dogfish Head", "60 Minute IPA", "maltBeverage", "unspecified", 6.0, None, [], None),
    ("allagash-white", "Allagash", "Allagash", "White", "maltBeverage", "unspecified", 5.2, None, [], None),
    ("deschutes-black-butte", "Deschutes", "Deschutes", "Black Butte Porter", "maltBeverage", "unspecified", 5.5, None, [], None),
    ("goose-island-312", "Goose Island", "Goose Island", "312 Urban Wheat", "maltBeverage", "unspecified", 4.2, None, [], None),
    ("oskar-blues-dales", "Oskar Blues", "Oskar Blues", "Dale's Pale Ale", "maltBeverage", "unspecified", 6.5, None, [], None),
    ("founders-breakfast-stout", "Founders", "Founders", "Breakfast Stout", "maltBeverage", "unspecified", 8.3, None, [], None),
    ("old-rasputin", "North Coast", "North Coast", "Old Rasputin", "maltBeverage", "unspecified", 9.0, None, [], None),
    ("sam-smith-oatmeal-stout", "Samuel Smith", "Samuel Smith", "Oatmeal Stout", "maltBeverage", "unspecified", 5.0, None, [], None),
    ("great-divide-yeti", "Great Divide", "Great Divide", "Yeti Imperial Stout", "maltBeverage", "unspecified", 9.5, None, [], None),
    ("bells-expedition-stout", "Bell's", "Bell's", "Expedition Stout", "maltBeverage", "unspecified", 10.5, None, [], None),
    ("firestone-walker-parabola", "Firestone Walker", "Firestone Walker", "Parabola", "maltBeverage", "unspecified", 14.0, None, [], None),
    ("angry-orchard-green-apple", "Angry Orchard", "Angry Orchard", "Green Apple", "hardCider", "unspecified", 5.0, None, [], None),
    ("blakes-flannel-mouth", "Blake's", "Blake's", "Flannel Mouth", "hardCider", "unspecified", 6.5, None, [], None),
    ("blakes-triple-jam", "Blake's", "Blake's", "Triple Jam", "hardCider", "unspecified", 6.5, None, [], None),
    ("seattle-cider-dry", "Seattle Cider", "Seattle Cider", "Dry", "hardCider", "unspecified", 6.9, None, [], None),
    ("schilling-grapefruit", "Schilling", "Schilling", "Grapefruit and Chill", "hardCider", "unspecified", 5.0, None, [], None),
    ("citizen-unified-press", "Citizen Cider", "Citizen Cider", "Unified Press", "hardCider", "unspecified", 6.9, None, [], None),
    ("farnum-hill-semi-dry", "Farnum Hill", "Farnum Hill", "Semi-Dry", "hardCider", "unspecified", 7.5, None, [], None),
    ("anxo-cidre-blanc", "ANXO", "ANXO", "Cidre Blanc", "hardCider", "unspecified", 6.9, None, [], None),
    ("original-sin-crisp-apple", "Original Sin", "Original Sin", "Crisp Apple", "hardCider", "unspecified", 6.0, None, [], None),
    ("jks-scrumpy-orchard-gate", "JK's", "JK's", "Scrumpy Orchard Gate Gold", "hardCider", "unspecified", 6.0, None, [], None),
    ("samuel-smith-organic-cider", "Samuel Smith", "Samuel Smith", "Organic Cider", "hardCider", "unspecified", 5.0, None, [], None),
    ("crispin-original", "Crispin", "Crispin", "Original", "hardCider", "unspecified", 5.0, None, [], None),
    ("bold-rock-virginia-apple", "Bold Rock", "Bold Rock", "Virginia Apple", "hardCider", "unspecified", 4.7, None, [], None),
    ("woodchuck-granny-smith", "Vermont Cider Co.", "Woodchuck", "Granny Smith", "hardCider", "unspecified", 5.0, None, [], None),
    ("woodchuck-pear", "Vermont Cider Co.", "Woodchuck", "Pear", "hardCider", "unspecified", 4.0, None, [], None),
    ("strongbow-honey-apple", "Bulmers", "Strongbow", "Honey and Apple", "hardCider", "unspecified", 5.0, None, [], None),
    ("somersby-apple", "Carlsberg", "Somersby", "Apple", "hardCider", "unspecified", 4.5, None, [], None),
    ("thatchers-gold", "Thatchers", "Thatchers", "Gold", "hardCider", "unspecified", 4.8, None, [], None),
    ("aspall-draught-suffolk", "Aspall", "Aspall", "Draught Suffolk", "hardCider", "unspecified", 5.5, None, [], None),
    ("rekorderlig-strawberry-lime", "Rekorderlig", "Rekorderlig", "Strawberry-Lime", "hardCider", "unspecified", 4.0, None, [], None),
    ("kopparberg-mixed-fruit", "Kopparberg", "Kopparberg", "Mixed Fruit", "hardCider", "unspecified", 4.0, None, [], None),
    ("downeast-cranberry", "Downeast Cider House", "Downeast", "Cranberry Blend", "hardCider", "unspecified", 5.1, None, [], None),
    ("heaven-hill-7-bib", "Heaven Hill", "Heaven Hill", "7 Year Bottled in Bond", "kentuckyStraightBourbon", "unspecified", 50.0, 7, [BIB], None),
    ("fighting-cock", "Heaven Hill", "Fighting Cock", "6 Year", "kentuckyStraightBourbon", "unspecified", 51.5, 6, [], None),
    ("old-fitzgerald-decanter", "Heaven Hill", "Old Fitzgerald", "Bottled in Bond Decanter", "kentuckyStraightBourbon", "unspecified", 50.0, None, [BIB], None),
    ("old-tub-bib", "Jim Beam", "Old Tub", "Bottled in Bond", "kentuckyStraightBourbon", "unspecified", 50.0, None, [BIB], None),
    ("jw-dant-bib", "Heaven Hill", "J.W. Dant", "Bottled in Bond", "kentuckyStraightBourbon", "unspecified", 50.0, None, [BIB], None),
    ("ezra-brooks-90", "Lux Row", "Ezra Brooks", "90 Proof", "kentuckyStraightBourbon", "unspecified", 45.0, None, [], None),
    ("kentucky-gentleman", "Barton 1792", "Kentucky Gentleman", "", "kentuckyStraightBourbon", "unspecified", 40.0, None, [], None),
    ("four-roses-limited-edition", "Four Roses", "Four Roses", "Limited Edition Small Batch", "kentuckyStraightBourbon", "smallBatch", None, None, [BP], None),
    ("jefferson-reserve", "Jefferson's", "Jefferson's", "Reserve", "straightBourbon", "smallBatch", 45.0, None, [], None),
    ("joseph-magnus-bourbon", "Joseph Magnus", "Joseph Magnus", "Straight Bourbon", "straightBourbon", "smallBatch", 50.0, None, [], None),
    ("bombergers-declaration", "Michter's", "Bomberger's", "Declaration", "kentuckyStraightBourbon", "smallBatch", 54.0, None, [], None),
    ("remus-repeal-reserve", "MGP", "George Remus", "Repeal Reserve", "straightBourbon", "smallBatch", 50.0, None, [], None),
    ("redwood-empire-pipe-dream", "Redwood Empire", "Redwood Empire", "Pipe Dream", "straightBourbon", "blend", 45.5, None, [], None),

    # ------------------------------------------------- Depth, where it was thin
    # An audit by class turned up categories carrying one row or two:
    # mezcal had one name of thirteen, rum three, and half a dozen
    # classes existed with a single bottle behind them. A class with one
    # example is a promise the data does not keep.
    #
    # bourbon, wheatWhiskey and lightWhiskey are still empty on purpose.
    # Almost every American bourbon and wheat whiskey on a shelf is the
    # STRAIGHT version, and light whiskey is barely bottled at all, so
    # there is no honest row to write. An empty class is better than a
    # bottle filed under the wrong one.
    ("vago-espadin", "Mezcal Vago", "Mezcal Vago", "Espadin", "mezcal", "unspecified", 50.2, None, [], None),
    ("rey-campero-espadin", "Rey Campero", "Rey Campero", "Espadin", "mezcal", "unspecified", 47.0, None, [], None),
    ("xicaru-silver", "Xicaru", "Xicaru", "Silver 102", "mezcal", "unspecified", 51.0, None, [], None),
    ("madre-mezcal", "Madre", "Madre", "Espadin y Cuishe", "mezcal", "unspecified", 45.0, None, [], None),
    ("alipus-san-andres", "Alipus", "Alipus", "San Andres", "mezcal", "unspecified", 47.5, None, [], None),
    ("derrumbes-oaxaca", "Derrumbes", "Derrumbes", "Oaxaca", "mezcal", "unspecified", 45.0, None, [], None),
    ("nuestra-soledad-lachigui", "Nuestra Soledad", "Nuestra Soledad", "Lachigui", "mezcal", "unspecified", 46.0, None, [], None),
    ("wahaka-espadin", "Wahaka", "Wahaka", "Espadin", "mezcal", "unspecified", 40.0, None, [], None),
    ("sombra-mezcal", "Sombra", "Sombra", "Joven", "mezcal", "unspecified", 45.0, None, [], None),
    # Union Uno, 400 Conejos and Bols Corenwyn are 38% and are NOT here.
    # Those are the Mexican and Dutch bottlings; the US standards of
    # identity require 80 proof for tequila, mezcal and gin, so the US
    # bottling of each is 40% and the 38% figure would be wrong for the
    # bottle in an American hand. I tried lowering the floor to NOM's 35%
    # to fit them and an existing test caught it, which is the test doing
    # its job: that 40% was a decision, not an oversight.
    ("clase-azul-ultra", "Clase Azul", "Clase Azul", "Ultra Extra Anejo", "tequilaExtraAnejo", "unspecified", 40.0, None, [], None),
    ("hamilton-jamaican-pot", "Hamilton", "Hamilton", "Jamaican Pot Still Black", "rum", "unspecified", 46.5, None, [], None),
    ("rum-fire", "Hampden Estate", "Rum Fire", "Overproof", "rum", "unspecified", 63.0, None, [], None),
    ("worthy-park-109", "Worthy Park", "Worthy Park", "109", "rum", "unspecified", 54.5, None, [], None),
    ("ten-to-one-dark", "Ten To One", "Ten To One", "Dark", "rum", "blend", 45.0, None, [], None),
    ("denizen-merchants", "Denizen", "Denizen", "Merchants Reserve", "rum", "blend", 43.0, None, [], None),
    ("cruzan-black-strap", "Cruzan", "Cruzan", "Black Strap", "rum", "unspecified", 40.0, None, [], None),
    ("privateer-signature", "Privateer", "Privateer", "Signature Reserve", "rum", "blend", 40.0, None, [], None),
    ("richland-single-estate", "Richland", "Richland", "Single Estate Old Georgia", "rum", "unspecified", 43.0, None, [], None),
    ("neisson-blanc", "Neisson", "Neisson", "Blanc 52.5", "rhumAgricole", "unspecified", 52.5, None, [], None),
    ("clement-premiere-canne", "Clement", "Clement", "Premiere Canne", "rhumAgricole", "unspecified", 40.0, None, [], None),
    ("captain-morgan-black", "Captain Morgan", "Captain Morgan", "Black Spiced", "flavoredRum", "unspecified", 40.0, None, [], None),
    ("bacardi-spiced", "Bacardi", "Bacardi", "Spiced", "flavoredRum", "unspecified", 35.0, None, [], None),
    ("tomatin-12", "Tomatin", "Tomatin", "12 Year", "singleMaltScotch", "unspecified", 43.0, 12, [], None),
    ("benriach-the-twelve", "BenRiach", "BenRiach", "The Twelve", "singleMaltScotch", "unspecified", 46.0, 12, [], None),
    ("jura-10", "Jura", "Jura", "10 Year", "singleMaltScotch", "unspecified", 40.0, 10, [], None),
    ("glenrothes-12", "Glenrothes", "Glenrothes", "12 Year", "singleMaltScotch", "unspecified", 40.0, 12, [], None),
    ("edradour-10", "Edradour", "Edradour", "10 Year", "singleMaltScotch", "unspecified", 40.0, 10, [], None),
    ("glen-garioch-12", "Glen Garioch", "Glen Garioch", "12 Year", "singleMaltScotch", "unspecified", 48.0, 12, [], None),
    ("longrow-peated", "Springbank", "Longrow", "Peated", "singleMaltScotch", "unspecified", 46.0, None, [], None),
    ("octomore-cask-strength", "Bruichladdich", "Octomore", "Cask Strength", "singleMaltScotch", "unspecified", None, None, [BP], None),
    ("big-peat", "Douglas Laing", "Big Peat", "", "blendedMaltScotch", "blend", 46.0, None, [], None),
    ("waterford-cuvee", "Waterford", "Waterford", "Cuvee Koffi", "singleMaltIrish", "unspecified", 50.0, None, [], None),
    ("dingle-single-malt", "Dingle", "Dingle", "Single Malt", "singleMaltIrish", "unspecified", 46.3, None, [], None),
    ("kilbeggan-traditional", "Kilbeggan", "Kilbeggan", "Traditional", "irishWhiskey", "blend", 40.0, None, [], None),
    ("tyrconnell-single-malt", "Cooley", "Tyrconnell", "Single Malt", "singleMaltIrish", "unspecified", 43.0, None, [], None),
    ("chita-single-grain", "Suntory", "Chita", "Single Grain", "japaneseWhisky", "unspecified", 43.0, None, [], None),
    ("ohishi-brandy-cask", "Ohishi", "Ohishi", "Brandy Cask", "japaneseWhisky", "unspecified", 41.0, None, [], None),
    ("fuji-single-blended", "Kirin", "Fuji", "Single Blended", "japaneseWhisky", "blend", 43.0, None, [], None),
    ("togouchi-premium", "Chugoku Jozo", "Togouchi", "Premium", "japaneseWhisky", "blend", 40.0, None, [], None),
    ("tenjaku-blended", "Tenjaku", "Tenjaku", "Blended", "japaneseWhisky", "blend", 40.0, None, [], None),
    ("wyoming-whiskey-small-batch", "Wyoming Whiskey", "Wyoming Whiskey", "Small Batch", "straightBourbon", "smallBatch", 44.0, None, [], None),
    ("cedar-ridge-bourbon", "Cedar Ridge", "Cedar Ridge", "Straight Bourbon", "straightBourbon", "unspecified", 43.0, None, [], None),
    ("copper-fox-rye", "Copper Fox", "Copper Fox", "Rye", "rye", "unspecified", 45.0, None, [], None),
    ("corsair-triple-smoke", "Corsair", "Corsair", "Triple Smoke", "americanSingleMalt", "smallBatch", 40.0, None, [], None),
    ("virginia-distillery-courage", "Virginia Distillery", "Virginia Distillery", "Courage and Conviction", "americanSingleMalt", "unspecified", 46.0, None, [], None),
    ("boulder-american-single-malt", "Boulder Spirits", "Boulder", "American Single Malt", "americanSingleMalt", "unspecified", 42.0, None, [], None),
    ("byrrh-grand-quinquina", "Byrrh", "Byrrh", "Grand Quinquina", "vermouth", "unspecified", 18.0, None, [], None),
    ("bonal-gentiane-quina", "Bonal", "Bonal", "Gentiane-Quina", "vermouth", "unspecified", 16.0, None, [], None),
    ("salers-gentiane", "Salers", "Salers", "Gentiane", "amaro", "unspecified", 16.0, None, [], None),
    ("cappelletti-aperitivo", "Cappelletti", "Cappelletti", "Aperitivo Americano Rosso", "amaro", "unspecified", 17.0, None, [], None),
    ("chateau-de-laubade-vsop", "Chateau de Laubade", "Chateau de Laubade", "VSOP", "armagnac", "unspecified", 40.0, None, [], None),
    ("castarede-vsop", "Castarede", "Castarede", "VSOP", "armagnac", "unspecified", 40.0, None, [], None),
    ("baron-de-sigognac-10", "Baron de Sigognac", "Baron de Sigognac", "10 Year", "armagnac", "unspecified", 40.0, 10, [], None),
    ("christian-drouin-selection", "Christian Drouin", "Christian Drouin", "Selection", "calvados", "unspecified", 40.0, None, [], None),
    ("roger-groult-8", "Roger Groult", "Roger Groult", "8 Year", "calvados", "unspecified", 41.0, 8, [], None),
    ("macchu-pisco", "Macchu Pisco", "Macchu Pisco", "", "pisco", "unspecified", 40.0, None, [], None),
    ("campo-de-encanto", "Campo de Encanto", "Campo de Encanto", "Grand Pisco", "pisco", "unspecified", 40.5, None, [], None),
    ("hitachino-nest-white", "Kiuchi", "Hitachino Nest", "White Ale", "maltBeverage", "unspecified", 5.5, None, [], None),
    ("founders-kbs", "Founders", "Founders", "KBS", "maltBeverage", "unspecified", 12.0, None, [], None),
    ("jinro-is-back", "HiteJinro", "Jinro", "Is Back", "soju", "unspecified", 16.5, None, [], None),
    ("kannoko-shochu", "Satsuma Shuzo", "Kannoko", "Barley Shochu", "shochu", "unspecified", 25.0, None, [], None),
    ("mizu-shochu", "Mizu", "Mizu", "Lemongrass Shochu", "shochu", "unspecified", 24.0, None, [], None),
    ("born-gold", "Katoukichibee", "Born", "Gold Junmai Daiginjo", "sake", "unspecified", 15.5, None, [], None),
    ("fenjiu-classic", "Shanxi Xinghuacun Fen", "Fenjiu", "Classic", "baijiu", "unspecified", 53.0, None, [], None),
    ("yanghe-daqu", "Yanghe", "Yanghe", "Daqu", "baijiu", "unspecified", 52.0, None, [], None),
    ("nonino-grappa-riserva", "Nonino", "Nonino", "Riserva Antica Cuvee", "grappa", "unspecified", 41.0, None, [], None),
    ("berta-tre-soli", "Berta", "Berta", "Tre Soli Tre", "grappa", "unspecified", 43.0, None, [], None),
    ("sandeman-founders", "Sandeman", "Sandeman", "Founders Reserve", "port", "unspecified", 19.5, None, [], None),
    ("quinta-do-noval-lbv", "Quinta do Noval", "Quinta do Noval", "Late Bottled Vintage", "port", "unspecified", 19.5, None, [], None),
    ("lustau-amontillado", "Lustau", "Lustau", "Los Arcos Amontillado", "sherry", "unspecified", 18.5, None, [], None),
    ("hidalgo-manzanilla", "Hidalgo", "Hidalgo", "La Gitana Manzanilla", "sherry", "unspecified", 15.0, None, [], None),
    ("barbeito-10-verdelho", "Barbeito", "Barbeito", "10 Year Verdelho", "madeira", "unspecified", 19.0, 10, [], None),
    ("leblon-reserva", "Leblon", "Leblon", "Reserva Especial", "cachaca", "unspecified", 40.0, None, [], None),
    ("avua-prata", "Avua", "Avua", "Prata", "cachaca", "unspecified", 42.0, None, [], None),

    # ------------------------------------------------ The rest of the shelf
    # Whole categories the class system could not express until now. Each of
    # these was somebody's whole shelf being invisible to the app.

    # World whisky. The five that were dropped last time for being filed as
    # Japanese, which they are not.
    ("kavalan-classic", "Kavalan", "Kavalan", "Classic Single Malt", "worldWhisky", "unspecified", 40.0, None, [], None),
    ("kavalan-solist-sherry", "Kavalan", "Kavalan", "Solist Sherry Cask", "worldWhisky", "singleCask", None, None, [BP], None),
    ("amrut-fusion", "Amrut", "Amrut", "Fusion", "worldWhisky", "unspecified", 50.0, None, [], None),
    ("paul-john-brilliance", "Paul John", "Paul John", "Brilliance", "worldWhisky", "unspecified", 46.0, None, [], None),
    ("starward-nova", "Starward", "Starward", "Nova", "worldWhisky", "unspecified", 41.0, None, [], None),
    ("mackmyra-brukswhisky", "Mackmyra", "Mackmyra", "Brukswhisky", "worldWhisky", "unspecified", 41.4, None, [], None),
    ("stauning-rye", "Stauning", "Stauning", "Rye", "worldWhisky", "unspecified", 48.0, None, [], None),

    # Port, sherry, madeira. Fortified wine keeps its own family: 20% is
    # correct for a port and would be an under-strength anything else.
    ("grahams-six-grapes", "Graham's", "Graham's", "Six Grapes Reserve", "port", "unspecified", 20.0, None, [], None),
    ("grahams-10-tawny", "Graham's", "Graham's", "10 Year Tawny", "port", "unspecified", 20.0, 10, [], None),
    ("taylor-fladgate-20", "Taylor Fladgate", "Taylor Fladgate", "20 Year Tawny", "port", "unspecified", 20.0, 20, [], None),
    ("fonseca-bin-27", "Fonseca", "Fonseca", "Bin 27 Reserve", "port", "unspecified", 20.0, None, [], None),
    ("warres-otima-10", "Warre's", "Warre's", "Otima 10 Year Tawny", "port", "unspecified", 20.0, 10, [], None),
    ("dows-late-bottled-vintage", "Dow's", "Dow's", "Late Bottled Vintage", "port", "unspecified", 20.0, None, [], None),
    ("tio-pepe", "Gonzalez Byass", "Tio Pepe", "Fino", "sherry", "unspecified", 15.0, None, [], None),
    ("lustau-east-india", "Lustau", "Lustau", "East India Solera", "sherry", "unspecified", 20.0, None, [], None),
    ("harveys-bristol-cream", "Harveys", "Harveys", "Bristol Cream", "sherry", "unspecified", 17.5, None, [], None),
    ("sandeman-medium-dry", "Sandeman", "Sandeman", "Medium Dry Amontillado", "sherry", "unspecified", 17.5, None, [], None),
    ("blandys-5-bual", "Blandy's", "Blandy's", "5 Year Bual", "madeira", "unspecified", 19.0, 5, [], None),
    ("rainwater-madeira", "Broadbent", "Broadbent", "Rainwater", "madeira", "unspecified", 18.0, None, [], None),

    # Cachaca. Its own floor at 38%, which is why Leblon does not read as an
    # under-strength rum.
    ("leblon-cachaca", "Leblon", "Leblon", "", "cachaca", "unspecified", 40.0, None, [], None),
    ("novo-fogo-silver", "Novo Fogo", "Novo Fogo", "Silver", "cachaca", "unspecified", 40.0, None, [], None),
    ("ypioca-prata", "Ypioca", "Ypioca", "Prata", "cachaca", "unspecified", 39.0, None, [], None),

    # Grappa, at the EU's 37.5%.
    ("nardini-bianca", "Nardini", "Nardini", "Grappa Bianca", "grappa", "unspecified", 50.0, None, [], None),
    ("jacopo-poli-sarpa", "Poli", "Jacopo Poli", "Sarpa di Poli", "grappa", "unspecified", 40.0, None, [], None),

    # East Asia. Nothing here shares a definition with anything else here,
    # which is why the family is a grouping and the floor is nothing.
    ("jinro-chamisul-fresh", "HiteJinro", "Jinro", "Chamisul Fresh", "soju", "unspecified", 16.9, None, [], None),
    ("chum-churum", "Lotte", "Chum Churum", "Original", "soju", "unspecified", 16.5, None, [], None),
    ("hwayo-41", "Hwayo", "Hwayo", "41", "soju", "unspecified", 41.0, None, [], None),
    ("iichiko-silhouette", "Sanwa Shurui", "Iichiko", "Silhouette", "shochu", "unspecified", 25.0, None, [], None),
    ("kurokirishima", "Kirishima", "Kuro Kirishima", "", "shochu", "unspecified", 25.0, None, [], None),
    ("dassai-45", "Asahi Shuzo", "Dassai", "45 Junmai Daiginjo", "sake", "unspecified", 16.0, None, [], None),
    ("hakkaisan-tokubetsu", "Hakkaisan", "Hakkaisan", "Tokubetsu Junmai", "sake", "unspecified", 15.5, None, [], None),
    ("kubota-manju", "Asahi Shuzo Niigata", "Kubota", "Manju Junmai Daiginjo", "sake", "unspecified", 15.5, None, [], None),
    ("moutai-flying-fairy", "Kweichow Moutai", "Kweichow Moutai", "Flying Fairy", "baijiu", "unspecified", 53.0, None, [], None),
    ("wuliangye-classic", "Wuliangye", "Wuliangye", "Classic", "baijiu", "unspecified", 52.0, None, [], None),
    ("hong-kong-baijiu-luzhou", "Luzhou Laojiao", "Luzhou Laojiao", "Tequ", "baijiu", "unspecified", 52.0, None, [], None),

    # ------------------------------------------------------------------ Cider
    # Hard cider is a real TTB class -- a wine made from apples or pears,
    # still or lightly carbonated, under 8.5% -- so these rows say what they
    # are without hedging. Pear cider (perry) goes here too, because the tax
    # class covers it.
    #
    # The "distillery" column holds the producer, which for cider is a cidery
    # and for seltzer below is a brewer. The column is named for the app's
    # first subject, not for these.
    ("angry-orchard-crisp", "Angry Orchard", "Angry Orchard", "Crisp Apple", "hardCider", "unspecified", 5.0, None, [], None),
    ("angry-orchard-rose", "Angry Orchard", "Angry Orchard", "Rosé", "hardCider", "unspecified", 5.5, None, [], None),
    ("angry-orchard-unfiltered", "Angry Orchard", "Angry Orchard", "Crisp Unfiltered", "hardCider", "unspecified", 5.0, None, [], None),
    ("woodchuck-amber", "Vermont Cider Co.", "Woodchuck", "Amber", "hardCider", "unspecified", 5.0, None, [], None),
    ("austin-eastciders-original", "Austin Eastciders", "Austin Eastciders", "Original Dry", "hardCider", "unspecified", 5.0, None, [], None),
    ("austin-eastciders-pineapple", "Austin Eastciders", "Austin Eastciders", "Pineapple", "hardCider", "unspecified", 5.0, None, [], None),
    ("downeast-original", "Downeast Cider House", "Downeast", "Original Blend", "hardCider", "unspecified", 5.1, None, [], None),
    ("ace-pineapple", "California Cider Co.", "Ace", "Pineapple", "hardCider", "unspecified", 5.0, None, [], None),
    ("stella-cidre", "Stella Artois", "Stella Artois", "Cidre", "hardCider", "unspecified", 4.5, None, [], None),
    ("magners-original", "C&C Group", "Magners", "Original Irish Cider", "hardCider", "unspecified", 4.5, None, [], None),
    ("strongbow-gold-apple", "Bulmers", "Strongbow", "Gold Apple", "hardCider", "unspecified", 5.0, None, [], None),
    ("2-towns-bright-cider", "2 Towns Ciderhouse", "2 Towns", "Bright Cider", "hardCider", "unspecified", 5.0, None, [], None),

    # --------------------------------------------------------------- Seltzer
    # "Hard seltzer" is a market category rather than a class -- see the
    # comment on ClassType.hardSeltzer. The bases genuinely differ: White
    # Claw ferments cane sugar, Truly and Bud Light are malt. Flavours are
    # expressions because that is what is on the can and what somebody would
    # search for.
    ("white-claw-black-cherry", "White Claw", "White Claw", "Black Cherry", "hardSeltzer", "unspecified", 5.0, None, [], None),
    ("white-claw-mango", "White Claw", "White Claw", "Mango", "hardSeltzer", "unspecified", 5.0, None, [], None),
    ("white-claw-lime", "White Claw", "White Claw", "Natural Lime", "hardSeltzer", "unspecified", 5.0, None, [], None),
    ("white-claw-watermelon", "White Claw", "White Claw", "Watermelon", "hardSeltzer", "unspecified", 5.0, None, [], None),
    ("white-claw-ruby-grapefruit", "White Claw", "White Claw", "Ruby Grapefruit", "hardSeltzer", "unspecified", 5.0, None, [], None),
    ("white-claw-raspberry", "White Claw", "White Claw", "Raspberry", "hardSeltzer", "unspecified", 5.0, None, [], None),
    ("white-claw-surge-blackberry", "White Claw", "White Claw", "Surge Blackberry", "hardSeltzer", "unspecified", 8.0, None, [], None),
    ("white-claw-surge-cranberry", "White Claw", "White Claw", "Surge Cranberry", "hardSeltzer", "unspecified", 8.0, None, [], None),
    ("truly-wild-berry", "Boston Beer Co.", "Truly", "Wild Berry", "hardSeltzer", "unspecified", 5.0, None, [], None),
    ("truly-lime", "Boston Beer Co.", "Truly", "Lime", "hardSeltzer", "unspecified", 5.0, None, [], None),
    ("bud-light-seltzer-lemon-lime", "Anheuser-Busch", "Bud Light Seltzer", "Lemon Lime", "hardSeltzer", "unspecified", 5.0, None, [], None),
    ("topo-chico-strawberry-guava", "Topo Chico", "Topo Chico Hard Seltzer", "Strawberry Guava", "hardSeltzer", "unspecified", 4.7, None, [], None),
    ("high-noon-black-cherry", "High Noon", "High Noon", "Black Cherry", "hardSeltzer", "unspecified", 4.5, None, [], None),
    ("high-noon-pineapple", "High Noon", "High Noon", "Pineapple", "hardSeltzer", "unspecified", 4.5, None, [], None),
]

RECIPE_CODES = {"four-roses-single-barrel": "OBSV"}


def load_prices():
    """{product id: {cents, source, as_of_year}} from every imported board.

    A product priced by two boards keeps the FIRST by filename order, and the
    count of clashes is printed. Averaging them would invent a figure no board
    published; showing both would ask the user to arbitrate between states.
    """
    directory = OUT.parent / "prices"
    if not directory.exists():
        return {}

    merged = {}
    clashes = 0
    for path in sorted(directory.glob("*.json")):
        payload = json.loads(path.read_text(encoding="utf-8"))
        for pid, entry in payload.get("prices", {}).items():
            if pid in merged:
                clashes += 1
                continue
            merged[pid] = {
                "cents": entry["cents"],
                "source": payload["source"],
                "as_of_year": payload.get("as_of_year"),
            }
    if clashes:
        print("note: %d products priced by more than one board; kept the first"
              % clashes)
    return merged


def main():
    prices = load_prices()
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

        # Cited shelf prices, imported from a control board's published price
        # list by scripts/import_price_list.py. Merged here rather than typed
        # into the table above so a price always arrives WITH its source and
        # its year -- there is no way to write one by hand and forget them.
        price = prices.get(pid)
        if price:
            product["msrp_cents"] = price["cents"]
            product["msrp_source"] = price["source"]
            product["msrp_as_of_year"] = price["as_of_year"]

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
    priced = sum(1 for p in products if p.get("msrp_cents") is not None)
    print("wrote %s: %d products, %d with a cited shelf price"
          % (OUT.name, len(products), priced))
    return 0


if __name__ == "__main__":
    sys.exit(main())
