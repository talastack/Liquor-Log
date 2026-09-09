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
    ("george-dickel-bib", "George Dickel", "George Dickel", "Bottled in Bond", "tennesseeWhiskey", "unspecified", 50.0, 13, [BIB], None),
    ("george-dickel-rye", "George Dickel", "George Dickel", "Straight Rye", "straightRye", "unspecified", 45.0, None, [], None),

    # ------------------------------------------------------- Barton / Sazerac
    ("1792-small-batch", "Barton 1792", "1792", "Small Batch", "kentuckyStraightBourbon", "smallBatch", 46.85, None, [], None),
    ("1792-full-proof", "Barton 1792", "1792", "Full Proof", "kentuckyStraightBourbon", "unspecified", 62.5, None, [], None),
    ("1792-single-barrel", "Barton 1792", "1792", "Single Barrel", "kentuckyStraightBourbon", "singleBarrel", 49.3, None, [], None),
    ("1792-bib", "Barton 1792", "1792", "Bottled in Bond", "kentuckyStraightBourbon", "unspecified", 50.0, 4, [BIB], None),
    ("very-old-barton-bib", "Barton 1792", "Very Old Barton", "Bottled in Bond", "kentuckyStraightBourbon", "unspecified", 50.0, 6, [BIB], None),

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
    ("high-west-rendezvous", "High West", "High West", "Rendezvous Rye", "straightRye", "blend", 46.0, None, [], None),
    ("high-west-american-prairie", "High West", "High West", "American Prairie", "blendOfStraightBourbon", "blend", 46.0, None, [], None),
    ("smooth-ambler-contradiction", "Smooth Ambler", "Smooth Ambler", "Contradiction", "blendOfStraightBourbon", "blend", 50.0, None, [], None),
    ("smooth-ambler-old-scout", "Smooth Ambler", "Smooth Ambler", "Old Scout", "straightBourbon", "unspecified", 49.5, None, [], None),
    ("redemption-rye", "Redemption", "Redemption", "Straight Rye", "straightRye", "unspecified", 46.0, None, [], None),
    ("widow-jane-10", "Widow Jane", "Widow Jane", "10 Year", "blendOfStraightBourbon", "blend", 45.5, 10, [], None),
    ("templeton-rye-4", "Templeton", "Templeton", "4 Year Rye", "straightRye", "unspecified", 40.0, 4, [], None),

    # ------------------------------------------------------ Craft distilleries
    ("new-riff-single-barrel", "New Riff", "New Riff", "Single Barrel", "straightBourbon", "singleBarrel", None, None, [BP], None),
    ("new-riff-rye-bib", "New Riff", "New Riff", "Bottled in Bond Rye", "straightRye", "unspecified", 50.0, 4, [BIB], None),
    ("wilderness-trail-bib", "Wilderness Trail", "Wilderness Trail", "Small Batch Bottled in Bond", "straightBourbon", "smallBatch", 50.0, 4, [BIB], None),
    ("green-river-bourbon", "Green River", "Green River", "Straight Bourbon", "kentuckyStraightBourbon", "unspecified", 45.0, None, [], None),
    ("castle-key-small-batch", "Castle & Key", "Castle & Key", "Small Batch Bourbon", "kentuckyStraightBourbon", "smallBatch", 50.0, None, [], None),
    ("old-elk-blended", "Old Elk", "Old Elk", "Blended Straight Bourbon", "blendOfStraightBourbon", "blend", 44.0, None, [], None),
    ("frey-ranch-bourbon", "Frey Ranch", "Frey Ranch", "Straight Bourbon", "straightBourbon", "unspecified", 45.0, None, [], None),
    ("penelope-four-grain", "Penelope", "Penelope", "Four Grain", "straightBourbon", "blend", 40.0, None, [], None),
    ("penelope-architect", "Penelope", "Penelope", "Architect", "straightBourbon", "blend", 50.0, None, [], None),
    ("penelope-barrel-strength", "Penelope", "Penelope", "Barrel Strength", "straightBourbon", "blend", None, None, [BP], None),
    ("smoke-wagon-uncut", "Nevada H&C", "Smoke Wagon", "Uncut Unfiltered", "straightBourbon", "smallBatch", None, None, [BP], None),
    ("smoke-wagon-small-batch", "Nevada H&C", "Smoke Wagon", "Small Batch", "straightBourbon", "smallBatch", 45.0, None, [], None),
    ("yellowstone-select", "Limestone Branch", "Yellowstone", "Select", "kentuckyStraightBourbon", "smallBatch", 46.5, None, [], None),
    ("laws-four-grain", "Laws Whiskey House", "Laws", "Four Grain", "straightBourbon", "unspecified", 47.5, 4, [], None),
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
    ("macallan-double-cask-12", "The Macallan", "The Macallan", "Double Cask 12 Year", "singleMaltScotch", "unspecified", 40.0, 12, [], None),
    ("highland-park-12", "Highland Park", "Highland Park", "12 Year Viking Honour", "singleMaltScotch", "unspecified", 40.0, 12, [], None),
    ("highland-park-18", "Highland Park", "Highland Park", "18 Year", "singleMaltScotch", "unspecified", 43.0, 18, [], None),
    ("balvenie-doublewood-12", "William Grant", "The Balvenie", "DoubleWood 12 Year", "singleMaltScotch", "unspecified", 43.0, 12, [], None),
    ("balvenie-caribbean-14", "William Grant", "The Balvenie", "Caribbean Cask 14 Year", "singleMaltScotch", "unspecified", 43.0, 14, [], None),
    ("glenmorangie-10", "Glenmorangie", "Glenmorangie", "Original 10 Year", "singleMaltScotch", "unspecified", 40.0, 10, [], None),
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
    ("aberlour-12", "Aberlour", "Aberlour", "12 Year Double Cask", "singleMaltScotch", "unspecified", 40.0, 12, [], None),
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
