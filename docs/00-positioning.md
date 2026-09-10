# Positioning

What this app is, what it refuses to be, and the evidence behind each call.

Every claim here traces to *Bourbon Collection App: Market Research & Strategy*
(8 September 2026) or to the earlier product plan (`bottle-app-plan.md`, August
2026). Where the two disagree, the research wins and this file says so.

---

## The gap is architectural, not featural

> Every bourbon app is built on the UPC. A UPC identifies a SKU. It cannot
> identify a barrel.

Bourbon collecting happens at barrel level — store picks, single barrels, Four
Roses recipe codes, Elijah Craig batch codes, Blanton's dump dates — so
barcode-first apps break on exactly the bottles enthusiasts care most about.
Two documented failures settle it: a Publix Buzzard's Roost pick that scans as a
completely different release, and Stagg 25A shipping with a barrel-select
barcode stickered over by a standard one.

**So:** every bottle is its own record with optional structured fields. The
catalogue is a convenience fallback. A store pick never needs approval to exist
in somebody's own collection, which is also why this has no moderation queue to
staff — the thing that has OnlyDrams sitting on a 3,000-bottle backlog.

## The job

> I don't really care about a bunch of info about the product in the app. I have
> the bottle. I just want to know if I have it or not.

Standing in an aisle, offline, answering *do I already own this* in under three
seconds. That is the shelf check, and it is the home tab. Everything else in the
app is the input that makes that answer good.

The threshold where people need this is around **50 bottles**. Below that they
use their eyes.

## What we build

| Scope item | Where it lives |
|---|---|
| Barrel-as-object model | `bottles` — pick, barrel, batch, recipe, dump date, warehouse, rick, floor |
| The aisle question, offline | `ShelfCheck`, `BottleSearch` |
| Three dates and a status | `purchase_date`, `opened_at`, `finished_at`, `Bottle.Status` |
| Storage location | `storage_location`, `shelf_number` |
| CSV export, free | `CSVWriter`, `CollectionExport` |
| Re-inventory mode | `ReInventory`, `ReInventoryRepository` |
| Suppressible money | `CollectionValue`, off by default |
| Pick my pour | `PickMyPour` |
| Open-date oxidation clock | `OxidationBand` — no other app markets this |
| Fill level as a real quantity | `fill_readings`, `PourMath`, `SetLevelView` — optional, never required |

### Fill level, and why it is a reading rather than a subtraction

The research verdict on fill level is **contested**, and both halves are real:

> Real demand (*"track purchase location, cost, bottle status (% full)"*, 8
> upvotes) but also open derision: *"At least I don't track fill level like some
> people, that seems extreme."* **Ship it, make it optional, do not make it a
> required step.** — §5

And the capability is close to unserved:

> **Fill level as a real quantity** — 5 tiny apps. Absent from Distiller,
> Whiskybase, BAXUS, Whizzky, Drammer, Whiskey Searcher. Whiskybase Plus's
> workaround is letting you *upload a photo of the fill line*. — §6

So it ships, and nothing requires it. Adding a bottle defaults to sealed and
full; the level control appears only if somebody says the bottle is already
open, and skipping it costs nothing.

The modelling decision behind it: a fill is a **reading**, not a subtraction.
Deriving the level purely from the pour log assumes every bottle started full
and that every pour since was logged, and §3f says plainly that neither holds:

> *"I forget to add a bottle sometimes and forget to delete on sometimes when
> it's finished. According to only drams, I'm sitting on 307 bottles with 120
> open."*

And §3b is the reason a 200-bottle shelf cannot be entered pour by pour:

> *"So I have 200+ bottles, and zero interest in manually adding each one."*

`fill_readings` records what somebody observed at a moment, and the fill is the
latest reading minus the pours logged after it. Correcting a bottle therefore
never rewrites history — `FillReadingTests` pins that the pours stay logged —
and two readings a year apart are a real record of how fast that bottle went
down.

### Catalogue depth, and what it is for

The catalogue is *"a convenience fallback, not the foundation"* (§1), because a
store pick must never need approval to exist. That stands. But depth still
matters, because every miss pushes somebody into typing, and §3c is what that
feels like at scale:

> *"Cannot enter items unless it's in the database already. The review process
> to add new items to the database takes too long."* / *"they have a backlog of
> around 3,000 bottles."*

So the shipped catalogue covers the bourbon shelf properly — 172 American
whiskey rows across 74 producers, including the ranges people name unprompted in
§5: Blanton's, Four Roses recipe codes, Elijah Craig batches, E.H. Taylor,
Stagg, Weller. Two rules keep it from becoming the other failure mode in §3d
(*"198 options for Arran 10"*): `check_catalog.py` rejects a duplicate
distillery/brand/expression, and it rejects an ABV on anything barrel proof,
because a catalogue claiming one number for a barrel-proof release is wrong for
almost every bottle on the shelf.

Every row is still `verified: false`. None has been checked against a TTB COLA.

Still unbuilt, and the research ranks them first: **label capture as the primary
entry path**, and **bulk onboarding** — point a camera down a shelf, confirm a
list. *"This is the #1 adoption barrier and solving it is worth more than any
feature."*

## What we refuse to build

**Social feed.** The clearest negative signal in the research. *"I really don't
want some app having a big database of me and all the booze I own."*

**Gamification, streaks, leaderboards.** An app pitched on exactly this scored
1, 1, 1 across three r/bourbon posts. Rarity as a *property of a bottle* works;
points do not. This also aligns with Apple guideline 1.4.3 — nothing here may
treat drinking more as progress. The collection screen counts bottles owned,
never drinks had.

**Marketed AI.** *"LLMs/Pseudo AI are the wrong direction for an industry driven
by people, experiences, personalities and subjective taste."* One developer
built label recognition and removed it before launch. AI is acceptable as
invisible data-entry plumbing and is never a feature name, a badge, or a line on
the store page.

**Our own secondary price feed.** *"the fair price on a ton of bottles is
absolute horse shit."* We have no market data, cannot keep it current, and being
wrong costs more than silence. `PriceCheck` reports a *published shelf price*
with its source attached and the words "Not a resale value."

**Any estimate of intoxication.** No BAC, no standard drinks against a limit, no
pacing. There is deliberately no place in the design where such a thing would
obviously go.

**Beer.** *"Beer cellaring is a graveyard. Every app in that niche died."* The
schema columns stay so adding it later needs no migration, and `BeerFreshness`
was cut before it was written.

## Where the two documents disagree

The August plan proposed a free tier capped by bottle count, with export behind
the paywall. The research refutes both.

> Never charge for export. It costs you almost nothing and it is the single
> strongest trust signal in a category where people have been burned.

Free unlimited bottles is also table stakes, not a differentiator: OnlyDrams is
already free with 10,000 ratings. **You cannot out-free a free incumbent. You
can only out-fit it, and the fit gap is barrel identity.**

Permanently free: unlimited bottles, all barrel and batch fields, CSV export,
backup, offline. Chargeable later, because they are services rather than your
own data handed back: multi-device sync, the insurance PDF, a shareable menu.

Price is never scaled by collection size — that punishes exactly the users worth
having.

## The risk that is not code

> Your hardest problem is not the app. It is distribution and database seeding.

r/whiskey removes app promotion by rule and flags the account. r/bourbon is a
review forum that bans link posts outright. The one thing that community has
demonstrably welcomed is a dump-date registry: non-commercial, no app, one
narrow bourbon-native problem, an explicit ask for contributions, and the author
giving up control of the data.

**A correction from the 10 September brief:** the domain the original research
named, BlantonsDumpDate.com, is dormant — one Wayback capture in six years, and
the root refuses automated clients. The live registry is **bourbondumpdate.com**,
founded 2019 by Chris White, with a Wayback 200 in February 2026. Its data
model is dump date, state found, and which letter of B-L-A-N-T-O-N-'-S is on the
cork topper. No app, no visible monetisation.

**The opening the brief confirmed:** a national, crowdsourced, queryable
registry of store picks and single barrels has no incumbent — only fragments
that are brand-captive (Nashville Barrel Co. covers its own barrels) or
state-captive (The Tater Tracker stops at the North Carolina line). And the
graveyard explains why: *"Manual curation of bourbon minutiae has a half-life of
about two to three years."* ModernThirst's Elijah Craig batch guide froze in
2019, gobourbon in 2021, Meta-Critic in 2023. The viable entry is one that
crowdsources with moderation cheap enough to survive its founder's attention
span — which is exactly the `bottles` table this app already has, with the
barrel fields already structured.

The research's recommendation stands: build that registry as a free web utility
**first**, and let the app follow the data. It is a separate project from this
repository and it is not started.

### Two things the brief found that nobody has

*"Interactive barrel-code decoders don't exist. No tool takes a Buffalo Trace
laser code or Four Roses recipe and returns an answer. Everything found is a
static explainer."* Ours has existed since the first commit; it is now a tool in
More rather than something only visible on a bottle that already had a code.

And rarity. The incumbent's tiers are *"an editorial label of unknown and
demonstrably inconsistent provenance"* — two records for one bottle showing
different tiers, no methodology anywhere. *"This is an attack surface, not a
moat."* Virginia ABC publishes bottles AND lottery entries per release, which is
measured demand against measured supply: 640 bottles of Stagg, 44,696 entries.
`Rarity` is built on that number and refuses to invent a tier below "allocated",
because every free source skews to the scarce end and there is no basis for
"common" versus "uncommon" — which is likely why the incumbent's are
inconsistent in the first place.
