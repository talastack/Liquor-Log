# 5. Data sourcing and the legal position

**Not legal advice.** This is an engineering document written to make the legal
questions visible and answerable, and to keep the app's data defensible by
construction. The items marked **ASK A LAWYER** are the ones worth an actual
opinion before launch.

Two rules govern everything below.

1. **No paid API and no runtime third-party dependency.** The app works fully
   offline on what it ships. Every dataset is pulled once by a build script,
   committed to `shared/data/`, and updated on our schedule — never queried
   live. A shop is a concrete box, and an app whose search box depends on
   somebody else's uptime is an app that fails exactly where it is needed.
2. **Every row cites its source.** Each catalog entry carries `source` and
   `source_url`. `scripts/check_catalog_sources.py` fails CI on any row without
   one. This is what makes "real data" enforceable rather than a promise.

---

## Current state, stated plainly

As of this commit **there is no bottle catalog.** `shared/data/` holds the files
listed below and nothing else. The `catalog_product_id` values in
`AppDatabase.seedFixtures()` — `ec-barrel-proof`, `weller-antique-107` and the
rest — are placeholders that resolve to nothing. The app will not have a working
autocomplete until the ingestion described here is actually run.

That is deliberate. Inventing a catalog from memory is how a wrong proof ends up
in a cost-per-pour figure that nobody ever checks.

---

## 1. Copyright: three real traps

### 1.1 Flavour wheels are copyrighted works

The well-known whisky flavour wheels — the Scotch Whisky Research Institute's,
and Charles MacLean's — are **published, copyrighted diagrams**. Their
particular selection and arrangement of descriptors into families is exactly the
kind of creative compilation copyright protects. Reproducing one, or building a
picker that is recognisably a copy of one, is infringement.

**What we ship instead:** `shared/data/flavor-wheel.v1.json` is our own
vocabulary. Individual descriptors — caramel, dried fig, charred oak — are
ordinary English words for tastes and are not ownable by anyone. The grouping
into eight bourbon-oriented families is ours, chosen for this app.

Do not "improve" it by importing a published wheel's structure.

### 1.2 Beer style guidelines are copyrighted

The BJCP Style Guidelines and the Brewers Association Beer Style Guidelines are
both copyrighted documents with explicit terms. Style *names* ("imperial stout",
"American IPA") are generic and freely usable; the guideline **text**,
and the specific numeric ranges those documents publish, are not ours to copy.

**What we ship instead:** `shared/data/beer-styles.v1.json` carries only a style
key, a plain-language name, and a shelf-life window sourced from a **named
brewery's own published freshness guidance**, quoted per row. Where no brewery
has published one, the row says so and the app widens the band rather than
inventing a number.

### 1.3 A curated database can be protected even when its facts are not

Individual facts are not copyrightable — a proof, an ABV, a mashbill, a
distillery name. But a *compilation* can be protected where the selection and
arrangement are creative. Assembling our own catalog from public records is
fine. Copying somebody else's finished bottle database wholesale is not, even
though every individual row in it is a fact.

**ASK A LAWYER** if anyone proposes seeding from an existing enthusiast database
or a competitor's export.

---

## 2. Trademark: using brand names

The catalog necessarily says "Elijah Craig" and "Four Roses". That is
**nominative use** — the name is needed to identify the product, and there is no
other way to refer to it. A collection app that could not name the bottles would
be useless.

The lines that must not be crossed:

| Allowed | Not allowed |
|---|---|
| The brand and expression as text | Their logos, wordmarks or label artwork |
| Stating facts about the product | Trade dress — recreating the look of a label |
| Our own drawn bottle silhouette | Anything implying endorsement or affiliation |
| Comparing bottles the user owns | A brand name in **our** app name or icon |

This is why `BottleMark` is a drawn SVG silhouette and not label art, and why
the app's own name — still unchosen — must not contain a distillery's brand.

**A user's own photograph of their own bottle is a different question** and is
fine to store locally. **ASK A LAWYER** before any feature that publishes user
photographs to other users.

---

## 3. Where the real data comes from

| Need | Source | Licence position |
|---|---|---|
| Label facts — brand, class/type, ABV, net contents, bottler | **TTB COLA public registry** | US federal government work. Not subject to copyright under 17 U.S.C. §105. The strongest position available. |
| Who actually distilled it — DSP numbers, permit holders | **TTB permit / DSP listings** | Same basis. |
| Distillery and brand ownership | **Wikidata** | CC0 public-domain dedication. No attribution burden, nothing to propagate. |
| Four Roses recipe codes and mashbills | **Distillery-published material** | Facts the distillery states publicly about its own product. |
| Retail price reference | **State control-board price lists** — Oregon OLCC, Virginia ABC, Pennsylvania PLCB and peers | Public records. **See the caveat below.** |
| Beer shelf life | **Per-brewery published freshness statements**, quoted per row | Facts, individually cited. |

### The state price list caveat — ASK A LAWYER

17 U.S.C. §105 removes copyright from **federal** government works. It does not
apply to the states, and a state may assert copyright in its own publications.
In practice ABC price lists are public records that are routinely republished,
and several boards publish them as open data — but "in practice" is not a
licence. Check the terms of each board actually used before shipping its data,
and prefer boards that publish under an explicit open-data policy.

### How a price actually gets in

`scripts/import_price_list.py`. There is no fetch step and that is deliberate:
these boards publish FILES, not feeds, so you download one, and the script
turns it into cited data.

```
python3 scripts/import_price_list.py inspect --file ~/Downloads/va-abc.csv
python3 scripts/import_price_list.py match --board virginia-abc     --file ~/Downloads/va-abc.csv --name-column Product --price-column Price     --year 2026            # add --write once the report reads correctly
```

Publishing a snapshot rather than calling an API is what keeps the price
answerable in a shop with no signal. A live lookup would fail in exactly the
place the number is wanted.

**It never guesses a match.** A price on the wrong bottle is worse than no
price, because nobody can tell by looking. Output is four buckets: matched,
*probable* (the catalogue name is contained in the listing's — reported for a
human), *ambiguous* (two rows normalise the same, or one product is priced
twice in one file), and unmatched. Only exact matches are ever written, and
`--write` is opt-in so the report is the default behaviour.

Every figure carries the board's name and the year, because a control-state
price is **that state's posted shelf price** — not a national MSRP and not a
resale value. Virginia's price is not what a Kentucky shop charges, and
`PriceReference` prints the source beside the number for that reason.

### Deliberately excluded

- **Any paid API**, including ones with a free tier. A free tier is a pricing
  decision somebody else can reverse.
- **Secondary-market resale prices.** No free, legal, stable source exists, and
  scraping resale listings is a terms-of-service problem before it is a
  technical one. The wishlist says plainly that its figures are shelf prices,
  not resale values.
- **ODbL datasets** (Open Food Facts and similar). Share-alike attaches to
  derived databases, and a commercial catalog should not carry that obligation.
  Free is one test; reusable is the other.
- **Scraping retailer or enthusiast sites.** Terms of service, and a compilation
  copyright question we would rather not have.
- **Anything invented.** A missing proof is a blank field, not a guess.

---

## 4. What the catalog may and may not hold

The catalog carries **product-level facts that are stable**. It does not carry
batch-level values, and this is a correctness decision as much as a legal one:

> A barrel-proof release has a different strength in every batch. Elijah Craig
> Barrel Proof is a different proof each release; George T. Stagg has ranged
> more than fifteen proof points across years. **A catalog that claims one
> number for these is wrong for almost every bottle on almost every shelf.**

So `abv` is `null` for barrel-proof products, and the add-bottle screen asks the
user to read the strength off the label in front of them. The schema already
allows this and the design already shows "varies by batch".

Batch numbers, barrel numbers, pick stores and measured proof live on the
`bottles` row — the release, not the product.

---

## 5. Validation: sourced is not the same as valid

A citation proves a number came from somewhere. It does not prove it is right,
and a catalog of real-but-wrong rows is worse than a small one, because every
downstream calculation inherits the error in silence.

`scripts/check_catalog_valid.py` runs in CI. Most of its rules are federal
regulation, which makes them checkable rather than arguable — bonded is 100
proof, straight is two years, American whiskey bottles at 80 minimum. They live
in compiled Swift (`LiquorEngine/Classification.swift`) and the script asserts
the shipped JSON agrees, which is the same arrangement Reef-Ledger uses for its
safety clamps: a remotely-updatable data file is precisely where a bad value
could otherwise arrive without review.

**A row that fails validation is dropped from the build, not shipped with a
warning.** An incomplete catalog degrades to typing it in yourself, which the
app supports anyway. A wrong catalog degrades to a wrong proof inside a
cost-per-pour figure, and nobody ever notices.

---

## 6. Verification still owed

Ordered by how much it would cost to get wrong.

1. **The TTB standards of fill list in `LiquorEngine/Units.swift` is
   transcribed from memory and is NOT verified.** It rejects bottle sizes, so a
   missing entry rejects valid bottles. Transcribe it from the current
   regulation text before the catalog ships. The list was expanded in recent
   years to authorise sizes that previously were not legal.
2. **The full class-and-type vocabulary** in the same file and in
   `0001_init.sql` needs the same treatment. The *rules* are settled and I am
   confident in them; the *enumerations* should come from the regulation, not
   from recollection.
3. **COLA bulk export format.** The registry's current download endpoints and
   formats need checking before an ingestion script is written against an
   assumed shape.
4. **Per-state price list terms**, per §3 above.
5. **Beer shelf-life windows**, each needing a named brewery's published
   statement or an explicit "not published" marker.

---

## 7. Offline, which is the whole point

Nothing above is queried at runtime. The catalog is bundled JSON loaded into a
local SQLite database on first launch; pours, tastings and wishlist rows are
written locally and are readable with no network at all. Sync, when it arrives,
is best-effort and never blocks a UI action — a failed sync is not an error
state to show the user.

The no-paid-API rule and the standing-in-an-aisle requirement are the same
constraint arriving from two directions, and satisfying either satisfies both.
