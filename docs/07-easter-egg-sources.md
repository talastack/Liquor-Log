# What the bourbon lore features rest on

Every one of these features makes a claim a collector could check. This file
says where each claim comes from, what the app deliberately does *not* claim,
and what to verify against a primary source before release. All links were
read on 15 September 2026.

The rule throughout: **a fact from the label or a photo is shown; an inference
the app cannot back is not.** Where the honest answer is "nobody knows", the
screen says so.

---

## Four Roses recipe codes — `RecipeCode`

**Source: Four Roses itself.** The distillery's own process page states the
four letters (O = Four Roses, B/E = mashbill, S = straight, last = yeast), the
two mashbills (B: 60% corn / 35% rye / 5% barley; E: 75 / 20 / 5) and the five
yeast characters (V delicate fruit, K slight spice, O rich fruit, Q floral
essence, F herbal). The engine's values match them word for word.

- https://www.fourrosesbourbon.com/our-process

## Elijah Craig / Larceny batch codes — `BatchCode`

**Source: Heaven Hill's stated schedule, documented by The Bourbon Review.**
Letter = release of the year (A, B, C), next digit = month (1, 5, 9), last two
= year. Heaven Hill has said the releases are January, May and September. The
decoder flags a code whose month does not match its letter as unusual rather
than refusing it, because a real bottle can depart from the plan.

- https://www.gobourbon.com/elijah-craig-and-larceny-barrel-proof-codes/
- https://heavenhilldistillery.com/elijah-craig-barrel-proof.php (the batch list)

## Blanton's stopper letters — `TopperLetters`

**Source: Blanton's own FAQ.** Since 1999 the stoppers come as a set of eight,
each marked with one letter, spelling BLANTONS when complete. There are two
different N's — the second is followed by a subtle colon, "N:" — and no
apostrophe stopper. All eight are made in equal numbers and placed at random.

An earlier version of the app treated the apostrophe as a ninth stopper. That
was wrong and is fixed; the set is eight, the second N is stored as "N:".

Because Blanton's makes all eight equally, **no letter is rare**, and the
screen never suggests one is. The set is a fact about a shelf, not a score.

- https://www.blantonsbourbon.com/pages/faq

## Buffalo Trace laser codes — `LaserCode`

**Source: two independent community write-ups that agree.** Buffalo Trace has
never published the scheme. Since 2012 a code reads `L YY DDD PP HHMM X`: lot
letter, two-digit year, day of the year, plant number, 24-hour time, bottling
line. From 2007 to 2011 the order was `X DDD YY HH:MM`. Both are read.

What the app decodes is the date arithmetic, which is deterministic. What it
does **not** decode is what any letter names — no source publishes that.

- https://debonairgentlemen.com/2023/09/25/how-to-read-a-buffalo-trace-laser-code/
- https://whiskeyjar.blog/2020/06/14/happy-national-bourbon-day-sipping-on-col-e-h-taylor-single-barrel-and-a-bit-about-laser-codes-on-buffalo-trace-bottles-and-the-vintage-of-those-bourbons/

## Maker's Mark Private Select staves — `StaveRecipe`

**Source: Maker's Mark for the programme; two write-ups for the per-stave
notes.** Maker's own page states ten wood-finishing staves per barrel, five
kinds, nine weeks in the limestone cellar, "over 1,001" combinations. Maker's
site does not publish the per-stave flavour descriptions; those are the
programme's stave cards as reported, in agreement, by Bourbon Guy and Bourbon
Banter, and the screen attributes them to "the programme's stave cards", not
to Maker's directly.

The rule that a recipe totals ten is the programme's, and the app enforces it.

- https://www.makersmark.com/en-us/bourbons/makers-mark-private-selection
- https://www.bourbonguy.com/blog/2017/12/12/makers-mark-private-select-part-1
- https://www.bourbonbanter.com/makers-mark-private-select-review-randalls-wine-spirits/

## Maker's Mark wax drip — `WaxDrip`

**Source: none, and the app says so.** The measurement is geometry on the
user's own photo — drip length over bottle height — and is a fact. The ranking
is against the user's own bottles and is a fact. There is **no published data**
on drip lengths; Maker's says only that every bottle is hand-dipped. So:

- the app shows the percentage, the millimetres if the user typed the bottle's
  height, and the standing among their own bottles;
- it does **not** call any drip rare, and an earlier set of descriptive bands
  ("a proper drip", "a cascade") was removed because the app had invented
  where the lines fell;
- `standing(among:)` accepts any sample so that a community distribution, if
  sync ever provides one, can be shown with attribution and no redesign.

## Who really made it — `DistilleryPermit`

**Source: two independent public lists, cross-checked; the TTB is the
authority.** Every entry was checked against both lists below; entries only
one list carries are marked and the screen says "likely, not certain". A
number not in the table is shown as unknown, never guessed. The check caught
two errors in the author's own memory (MGP is DSP-IN-15016, Jack Daniel's is
DSP-TN-4), which is the argument for never shipping such a table from memory.

**On the TTB as a check (tried 15 September 2026):** the TTB's public List of
Permittees (https://www.ttb.gov/public-information/foia/list-of-permittees,
"Spirits Producers and Bottlers List", CSV) carries *basic permit* numbers of
the form `KY-S-113`, which are a different numbering from DSP registry numbers
and do not correspond to them: `KY-S-20022` is Casey Jones Distillery, not
Angel's Envy; `KY-S-15014` is Wild Turkey, not Limestone Branch; most of the
Kentucky majors' DSP numbers do not appear at all. A few coincide (Jim Beam
230, MGP 15016, Michter's 20003), which is coincidence, not confirmation. So
that file cannot verify the table. The DSP number is what the label prints,
and the primary check is a COLA record or the label itself. The two lists
below remain the working sources, marked as such on screen.

- https://modernthirst.com/home/dsp-numbers/
- https://www.whiskeyprof.com/distilled-spirits-plant-numbers-d-s-p-work-in-progress/

## Warehouse lore — `WarehouseLore`

**Source: the producers, one line each.** Buffalo Trace on Warehouse H
(metal-clad, 1935, Blanton's); Four Roses on its single-story rack warehouses
at Cox's Creek (about 8 °F top to bottom); Wild Turkey / Russell's Reserve on
the Camp Nelson rickhouses and the Single Rickhouse series; Maker's on the
limestone cellar. A warehouse with nothing sourced about it gets no line.

- https://www.buffalotracedistillery.com/our-brands/blantons-single-barrel/
- https://www.fourrosesbourbon.com/our-process
- https://www.russellsreserve.com/our-products/single-rickhouse/
- https://www.makersmark.com/en-us/bourbons/makers-mark-private-selection

## Allocation and rarity — `Rarity`

**Source: Virginia ABC's own lottery pages.** The example the app is built
around — George T. Stagg, 640 bottles, 44,696 entries — is the January 2026
lottery as published by the ABC. That is measured demand against measured
supply, which is why `Rarity` refuses to invent a tier below "allocated": the
only sources are for the scarce end, and there is no basis for "common".

- https://www.abc.virginia.gov/products/limited-availability/lottery
- https://www.abc.virginia.gov/products/bourbon/george-t-stagg-bourbon

## The catalogue's ABVs — `spirits.v1.json`

Every row is `verified: false` and the check script refuses `verified: true`
without a source URL. The primary source is the TTB COLA registry
(https://ttbonline.gov/colasonline/publicSearchColasBasic.do); each row should
be checked there before release. The 12-row audit of 11 September corrected
label facts from published sources but did not flip any row to verified.

## Water (proofing)

- **Method and anchors:** 27 CFR 30.66, the text of § 30.66 itself: divide
  the alcohol in the given strength by the alcohol in the required strength,
  multiply by the water in the required strength, subtract the water in the
  given strength. Its printed example, 112 proof to 100 proof = 1.12 × 53.73
  − 47.75. Fetched from ecfr.gov on 15 September 2026.
- **Table 6 values (51–150 proof):** TTB, Gauging Manual Tables, Table_6.pdf
  (ttb.gov/system/files/images/pdfs/foia_Gauging_Manual_Tables/Table_6.pdf),
  a scan. Transcribed and checked against the regulation's anchors and the
  step between neighbours (0.45–0.53, rising smoothly); every misread digit
  in the OCR broke that pattern. Outside 51–150 the app answers nothing.
- **Teaspoon:** a US teaspoon is 4.92892 ml (NIST Handbook 44, Appendix C).

## Wild Turkey bottling codes

- Rare Bird 101, "Wild Turkey Bottle Codes" (rarebird101.com/bottle-codes),
  the collectors' reference for the brand: every format from 1992 to the
  present with a worked example each, which are the tests. Wild Turkey
  publishes nothing; the app says so on screen and leaves the undocumented
  letters undecoded.

## Tequila NOM

- Consejo Regulador del Tequila, "Brands and Companies" registry
  (crt.org.mx/en/brands-and-associates/), fetched 15 September 2026 and
  rebuilt by `scripts/build_tequila_registry.py` into
  `shared/data/tequila-nom.v1.json`: 201 producers, 2,577 registered brands,
  names exactly as the CRT lists them. Nothing added by hand — an earlier
  from-memory draft had Sauza and Tapatío on the wrong numbers, which is why
  the file is generated and not typed.

## Dating a dusty

- Strip stamps ended 1 July 1985: Deficit Reduction Act of 1984, repeal of
  26 U.S.C. 5205's strip stamp requirement.
- ATF created 1 July 1972; the IRS → ATF wording on strips, "Series 111/112"
  1945–1972, volume marks on strip ends before 1973, green BIB strips with
  seasons discontinued 1 December 1982: Whiskey Prof, "Tax Stamps – BIB &
  Other" (whiskeyprof.com/tax-stamps-bib), and whiskeyid.com, "How to
  date / identify vintage whiskey bottles".
- Metric standards of fill mandatory 1 January 1980, permitted from 1976:
  27 CFR 5.47a (as then numbered).
