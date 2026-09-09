#!/usr/bin/env python3
"""Authoring tool for shared/data/flavor-wheel.v1.json.

    python3 scripts/build_flavor_wheel.py

THE TABLE BELOW IS THE SOURCE. The JSON is what ships.

Three things about the shape of this wheel, all deliberate.

ORGANISED BY ORIGIN, NOT BY RESEMBLANCE. Every descriptor carries the stage it
comes from -- grain, ferment, still, barrel, air, fault. That is a chemical and
process fact rather than an aesthetic judgement, which is what makes this an
independent derivation rather than a rearrangement of somebody's published
wheel. See docs/06-flavour-wheel-provenance.md. It also earns its keep at
runtime: OxidationBand reasons about what changes in an open bottle, and the
oxidation notes are exactly the ones that arrive while maturation notes flatten.

THREE TIERS. Family -> group -> descriptor. A flat list of three hundred words
is unusable on a phone; nobody scrolling "Fruit" wants to pass forty entries to
reach "Lemon". The group is presentational only, so it can be renamed freely --
the DESCRIPTOR KEY is what a tasting note stores, and those can never change.

MOUTHFEEL IS A FAMILY. Texture is on every serious wheel and was missing here
entirely, which left no way to record the single most distinctive thing about a
barrel-proof bourbon: that it can be 62% and still feel soft.

KEYS ARE FOREVER. A note stores the key, so renaming one silently changes what
somebody wrote about a bottle years ago. Labels may be edited; keys may not.
"""

import json
import sys
from pathlib import Path

OUT = Path(__file__).resolve().parent.parent / "shared" / "data" / "flavor-wheel.v1.json"

# Origins, mirroring LiquorEngine/FlavorWheel.swift. check_flavor_wheel.py
# asserts these agree with the Swift enum.
GRAIN = "grain"
FERMENT = "fermentation"
STILL = "distillation"
BARREL = "maturation"
AIR = "oxidation"
FAULT = "fault"

PROVENANCE = (
    "Own work. Descriptors are the ordinary sensory vocabulary in common use "
    "and are not owned by anyone. The grouping is by ORIGIN - where the flavour "
    "comes from in the grain, the ferment, the still or the barrel - which is a "
    "chemical and process fact rather than a copy of any published wheel's "
    "arrangement. Sub-groups within a family are presentational only. "
    "See docs/06-flavour-wheel-provenance.md."
)

ORIGINS = [
    {"key": GRAIN, "label": "From the grain",
     "note": "The mashbill itself."},
    {"key": FERMENT, "label": "From the ferment",
     "note": "Made by yeast. Esters, mostly fruit and flowers."},
    {"key": STILL, "label": "From the still",
     "note": "Congeners carried or created during distillation."},
    {"key": BARREL, "label": "From the barrel",
     "note": "Oak, char and time."},
    {"key": AIR, "label": "From air and time",
     "note": "Appears as an open bottle ages."},
    {"key": FAULT, "label": "Something went wrong",
     "note": "A flaw rather than a characteristic."},
]

# (family key, family label, [(group label, [(key, label, origin), ...]), ...])
FAMILIES = [
    ("grain", "Grain", [
        ("Corn", [
            ("corn", "Corn", GRAIN),
            ("cornbread", "Cornbread", GRAIN),
            ("corn-syrup", "Corn syrup", GRAIN),
            ("popcorn", "Popcorn", GRAIN),
            ("polenta", "Polenta", GRAIN),
            ("sweet-grain", "Sweet grain", GRAIN),
        ]),
        ("Malt and barley", [
            ("malt", "Malt", GRAIN),
            ("barley", "Barley", GRAIN),
            ("malted-milk", "Malted milk", GRAIN),
            ("cereal", "Cereal", GRAIN),
            ("oatmeal", "Oatmeal", GRAIN),
            ("porridge", "Porridge", GRAIN),
            ("wort", "Wort", FERMENT),
        ]),
        ("Rye and wheat", [
            ("rye-bread", "Rye bread", GRAIN),
            ("pumpernickel", "Pumpernickel", GRAIN),
            ("caraway", "Caraway", GRAIN),
            ("wheat", "Wheat", GRAIN),
            ("wheat-toast", "Wheat toast", GRAIN),
            ("shortbread", "Shortbread", GRAIN),
        ]),
        ("Baked", [
            ("biscuit", "Biscuit", GRAIN),
            ("bread-dough", "Bread dough", FERMENT),
            ("sourdough", "Sourdough", FERMENT),
            ("pie-crust", "Pie crust", GRAIN),
            ("graham-cracker", "Graham cracker", GRAIN),
            ("digestive", "Digestive biscuit", GRAIN),
        ]),
    ]),

    ("sweet", "Sweet", [
        ("Caramelised sugar", [
            ("caramel", "Caramel", BARREL),
            ("toffee", "Toffee", BARREL),
            ("butterscotch", "Butterscotch", BARREL),
            ("burnt-sugar", "Burnt sugar", BARREL),
            ("brown-sugar", "Brown sugar", BARREL),
            ("demerara", "Demerara", BARREL),
            ("molasses", "Molasses", BARREL),
            ("treacle", "Treacle", BARREL),
        ]),
        ("Syrup and honey", [
            ("maple-syrup", "Maple syrup", BARREL),
            ("honey", "Honey", BARREL),
            ("honeycomb", "Honeycomb", BARREL),
            ("golden-syrup", "Golden syrup", BARREL),
            ("agave-syrup", "Agave syrup", BARREL),
        ]),
        ("Confection", [
            ("vanilla", "Vanilla", BARREL),
            ("marshmallow", "Marshmallow", BARREL),
            ("nougat", "Nougat", BARREL),
            ("candy-floss", "Candy floss", BARREL),
            ("bubblegum", "Bubblegum", FERMENT),
            ("sugared-almond", "Sugared almond", BARREL),
        ]),
        ("Dairy", [
            ("butter", "Butter", FERMENT),
            ("cream", "Cream", BARREL),
            ("creme-brulee", "Creme brulee", BARREL),
            ("custard", "Custard", BARREL),
            ("condensed-milk", "Condensed milk", BARREL),
        ]),
        ("Chocolate", [
            ("chocolate", "Chocolate", BARREL),
            ("dark-chocolate", "Dark chocolate", BARREL),
            ("milk-chocolate", "Milk chocolate", BARREL),
            ("cocoa", "Cocoa", BARREL),
            ("mocha", "Mocha", BARREL),
            ("espresso", "Espresso", BARREL),
        ]),
    ]),

    ("fruit", "Fruit", [
        ("Orchard", [
            ("apple", "Apple", FERMENT),
            ("baked-apple", "Baked apple", BARREL),
            ("apple-skin", "Apple skin", FERMENT),
            ("pear", "Pear", FERMENT),
            ("quince", "Quince", FERMENT),
        ]),
        ("Stone fruit", [
            ("apricot", "Apricot", FERMENT),
            ("peach", "Peach", FERMENT),
            ("nectarine", "Nectarine", FERMENT),
            ("plum", "Plum", FERMENT),
            ("black-cherry", "Black cherry", BARREL),
            ("cherry", "Cherry", BARREL),
            ("cherry-pie", "Cherry pie", BARREL),
            ("maraschino", "Maraschino", BARREL),
        ]),
        ("Citrus", [
            ("orange-peel", "Orange peel", BARREL),
            ("orange-marmalade", "Marmalade", BARREL),
            ("lemon", "Lemon", FERMENT),
            ("lemon-zest", "Lemon zest", FERMENT),
            ("lime", "Lime", FERMENT),
            ("grapefruit", "Grapefruit", FERMENT),
            ("tangerine", "Tangerine", FERMENT),
        ]),
        ("Berry", [
            ("strawberry", "Strawberry", FERMENT),
            ("raspberry", "Raspberry", FERMENT),
            ("blackberry", "Blackberry", BARREL),
            ("blackcurrant", "Blackcurrant", BARREL),
            ("berry-jam", "Berry jam", BARREL),
            ("red-berries", "Red berries", FERMENT),
        ]),
        ("Tropical", [
            ("banana", "Banana", FERMENT),
            ("pineapple", "Pineapple", FERMENT),
            ("mango", "Mango", FERMENT),
            ("melon", "Melon", FERMENT),
            ("coconut-flesh", "Coconut flesh", BARREL),
            ("passion-fruit", "Passion fruit", FERMENT),
        ]),
        ("Dried", [
            ("raisin", "Raisin", BARREL),
            ("sultana", "Sultana", BARREL),
            ("dried-fig", "Dried fig", BARREL),
            ("date", "Date", BARREL),
            ("prune", "Prune", BARREL),
            ("dried-apricot", "Dried apricot", BARREL),
            ("candied-fruit", "Candied fruit", BARREL),
            ("fruitcake", "Fruitcake", BARREL),
        ]),
    ]),

    ("floral", "Floral", [
        ("Flowers", [
            ("rose", "Rose", FERMENT),
            ("violet", "Violet", FERMENT),
            ("honeysuckle", "Honeysuckle", FERMENT),
            ("lavender", "Lavender", FERMENT),
            ("jasmine", "Jasmine", FERMENT),
            ("elderflower", "Elderflower", FERMENT),
            ("orange-blossom", "Orange blossom", FERMENT),
            ("geranium", "Geranium", FERMENT),
        ]),
        ("Perfumed", [
            ("perfume", "Perfume", FERMENT),
            ("potpourri", "Potpourri", BARREL),
            ("rose-water", "Rose water", FERMENT),
            ("talc", "Talc", BARREL),
        ]),
    ]),

    ("spice", "Spice", [
        ("Baking spice", [
            ("cinnamon", "Cinnamon", BARREL),
            ("cassia", "Cassia", BARREL),
            ("clove", "Clove", BARREL),
            ("nutmeg", "Nutmeg", BARREL),
            ("allspice", "Allspice", BARREL),
            ("baking-spice", "Baking spice", BARREL),
            ("gingerbread", "Gingerbread", BARREL),
            ("mulling-spice", "Mulling spice", BARREL),
        ]),
        ("Hot spice", [
            ("black-pepper", "Black pepper", GRAIN),
            ("white-pepper", "White pepper", GRAIN),
            ("pink-peppercorn", "Pink peppercorn", GRAIN),
            ("chilli", "Chilli", GRAIN),
            ("rye-spice", "Rye spice", GRAIN),
            ("ginger", "Ginger", BARREL),
            ("horseradish", "Horseradish", GRAIN),
        ]),
        ("Aromatic", [
            ("anise", "Anise", GRAIN),
            ("liquorice", "Liquorice", BARREL),
            ("star-anise", "Star anise", GRAIN),
            ("cardamom", "Cardamom", GRAIN),
            ("coriander-seed", "Coriander seed", GRAIN),
            ("juniper", "Juniper", STILL),
        ]),
    ]),

    ("wood", "Wood", [
        ("Oak", [
            ("new-oak", "New oak", BARREL),
            ("charred-oak", "Charred oak", BARREL),
            ("toasted-oak", "Toasted oak", BARREL),
            ("dry-oak", "Dry oak", BARREL),
            ("old-oak", "Old oak", BARREL),
            ("oak-spice", "Oak spice", BARREL),
        ]),
        ("Other woods", [
            ("cedar", "Cedar", BARREL),
            ("sandalwood", "Sandalwood", BARREL),
            ("pine", "Pine", BARREL),
            ("sawdust", "Sawdust", BARREL),
            ("pencil-shavings", "Pencil shavings", BARREL),
            ("cigar-box", "Cigar box", BARREL),
        ]),
        ("Lactone", [
            ("coconut", "Coconut", BARREL),
            ("creamy-oak", "Creamy oak", BARREL),
        ]),
        ("Dry and tannic", [
            ("tannin", "Tannin", BARREL),
            ("old-books", "Old books", BARREL),
            ("library", "Library", BARREL),
            ("parchment", "Parchment", BARREL),
            ("resin", "Resin", BARREL),
            ("varnish", "Varnish", BARREL),
        ]),
    ]),

    ("nutty", "Nutty", [
        ("Tree nut", [
            ("almond", "Almond", BARREL),
            ("walnut", "Walnut", BARREL),
            ("pecan", "Pecan", BARREL),
            ("hazelnut", "Hazelnut", BARREL),
            ("brazil-nut", "Brazil nut", BARREL),
            ("chestnut", "Chestnut", BARREL),
        ]),
        ("Roasted", [
            ("toasted-nut", "Toasted nut", BARREL),
            ("peanut", "Peanut", BARREL),
            ("peanut-brittle", "Peanut brittle", BARREL),
            ("praline", "Praline", BARREL),
        ]),
        ("Confected", [
            ("marzipan", "Marzipan", BARREL),
            ("almond-paste", "Almond paste", BARREL),
            ("nut-oil", "Nut oil", STILL),
        ]),
    ]),

    ("herbal", "Herbal and vegetal", [
        ("Mint", [
            ("mint", "Mint", GRAIN),
            ("spearmint", "Spearmint", GRAIN),
            ("menthol", "Menthol", GRAIN),
            ("eucalyptus", "Eucalyptus", GRAIN),
            ("camphor", "Camphor", BARREL),
        ]),
        ("Green", [
            ("grass", "Grass", GRAIN),
            ("hay", "Hay", GRAIN),
            ("straw", "Straw", GRAIN),
            ("green-stem", "Green stem", STILL),
            ("cucumber", "Cucumber", STILL),
            ("dill", "Dill", GRAIN),
            ("fennel", "Fennel", GRAIN),
            ("celery", "Celery", STILL),
        ]),
        ("Tea and tobacco", [
            ("black-tea", "Black tea", BARREL),
            ("green-tea", "Green tea", GRAIN),
            ("tobacco", "Tobacco", BARREL),
            ("pipe-tobacco", "Pipe tobacco", BARREL),
            ("cigar-leaf", "Cigar leaf", BARREL),
        ]),
        ("Earthy", [
            ("leather", "Leather", BARREL),
            ("saddle-leather", "Saddle leather", BARREL),
            ("forest-floor", "Forest floor", BARREL),
            ("damp-earth", "Damp earth", BARREL),
            ("mushroom", "Mushroom", BARREL),
            ("moss", "Moss", BARREL),
        ]),
    ]),

    ("smoke", "Smoke", [
        ("Char and ash", [
            ("char", "Char", BARREL),
            ("ash", "Ash", BARREL),
            ("bonfire", "Bonfire", BARREL),
            ("campfire", "Campfire", BARREL),
            ("burnt-toast", "Burnt toast", BARREL),
            ("roasted", "Roasted", BARREL),
        ]),
        ("Peat", [
            ("peat", "Peat", GRAIN),
            ("peat-smoke", "Peat smoke", GRAIN),
            ("bog", "Bog", GRAIN),
            ("smoked-meat", "Smoked meat", GRAIN),
        ]),
        ("Industrial", [
            ("tar", "Tar", GRAIN),
            ("creosote", "Creosote", GRAIN),
            ("diesel", "Diesel", GRAIN),
            ("rubber", "Rubber", STILL),
        ]),
        ("Medicinal", [
            ("medicinal", "Medicinal", GRAIN),
            ("iodine", "Iodine", GRAIN),
            ("antiseptic", "Antiseptic", GRAIN),
            ("brine", "Brine", GRAIN),
            ("sea-air", "Sea air", GRAIN),
        ]),
    ]),

    ("mouthfeel", "Mouthfeel", [
        ("Body", [
            ("thin", "Thin", STILL),
            ("light-body", "Light bodied", STILL),
            ("medium-body", "Medium bodied", STILL),
            ("full-body", "Full bodied", STILL),
            ("viscous", "Viscous", STILL),
            ("syrupy", "Syrupy", STILL),
        ]),
        ("Texture", [
            ("oily", "Oily", STILL),
            ("silky", "Silky", STILL),
            ("velvety", "Velvety", BARREL),
            ("creamy", "Creamy", BARREL),
            ("chewy", "Chewy", BARREL),
            ("waxy", "Waxy", STILL),
            ("prickly", "Prickly", STILL),
        ]),
        ("Heat", [
            ("soft-heat", "Soft heat", BARREL),
            ("warming", "Warming", STILL),
            ("hot", "Hot", STILL),
            ("burning", "Burning", STILL),
            ("ethanol-bite", "Ethanol bite", STILL),
        ]),
        ("Drying", [
            ("drying", "Drying", BARREL),
            ("astringent", "Astringent", BARREL),
            ("puckering", "Puckering", BARREL),
            ("mouth-coating", "Mouth coating", STILL),
            ("clean-finish", "Clean finish", STILL),
        ]),
    ]),

    ("faults", "Faults and off notes", [
        ("Solvent", [
            ("nail-polish", "Nail polish", STILL),
            ("solvent", "Solvent", STILL),
            ("acetone", "Acetone", STILL),
            ("glue", "Glue", STILL),
            ("plastic", "Plastic", STILL),
        ]),
        ("Sulphur", [
            ("sulphur", "Sulphur", FERMENT),
            ("struck-match", "Struck match", FERMENT),
            ("cabbage", "Cabbage", FERMENT),
            ("rotten-egg", "Rotten egg", FERMENT),
            ("burnt-rubber", "Burnt rubber", FERMENT),
        ]),
        ("Tired", [
            ("wet-cardboard", "Wet cardboard", AIR),
            ("flat", "Flat", AIR),
            ("stale", "Stale", AIR),
            ("dusty", "Dusty", AIR),
            ("faded-fruit", "Faded fruit", AIR),
        ]),
        ("Microbial", [
            ("musty", "Musty", FAULT),
            ("mouldy", "Mouldy", FAULT),
            ("wet-dog", "Wet dog", FAULT),
            ("vinegar", "Vinegar", FAULT),
            ("sour-milk", "Sour milk", FAULT),
        ]),
        ("Other off notes", [
            ("soapy", "Soapy", FAULT),
            ("metallic", "Metallic", FAULT),
            ("bitter", "Bitter", FAULT),
            ("green-apple-fault", "Green apple (harsh)", STILL),
            ("cork", "Cork taint", FAULT),
        ]),
    ]),
]


def main():
    families = []
    seen_keys = {}
    seen_labels = {}

    for fkey, flabel, groups in FAMILIES:
        descriptors = []
        for group_label, entries in groups:
            for key, label, origin in entries:
                if key in seen_keys:
                    print("duplicate descriptor key %r" % key, file=sys.stderr)
                    return 1
                seen_keys[key] = fkey

                # Two identical labels in different families would be
                # indistinguishable in a tasting note read back later.
                if label.lower() in seen_labels:
                    print(
                        "duplicate label %r in %s and %s"
                        % (label, seen_labels[label.lower()], fkey), file=sys.stderr)
                    return 1
                seen_labels[label.lower()] = fkey

                descriptors.append({
                    "key": key,
                    "label": label,
                    "origin": origin,
                    "group": group_label,
                })
        families.append({"key": fkey, "label": flabel, "descriptors": descriptors})

    wheel = {
        "version": 1,
        "name": "Liquor-Log flavour wheel",
        # Load-bearing, not decoration. The whole legal position of this file
        # rests on the arrangement being derived from process rather than
        # copied from a published wheel, and the claim has to travel WITH the
        # data -- a provenance note kept only in a doc is one refactor away
        # from being separated from the thing it describes.
        "provenance": PROVENANCE,
        "origins": ORIGINS,
        "families": families,
    }

    OUT.write_text(
        json.dumps(wheel, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")

    total = sum(len(f["descriptors"]) for f in families)
    groups = sum(len(g) for _, _, g in FAMILIES)
    print("wrote %s: %d families, %d groups, %d descriptors"
          % (OUT.name, len(families), groups, total))
    return 0


if __name__ == "__main__":
    sys.exit(main())
