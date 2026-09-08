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
demonstrably welcomed is BlantonsDumpDate.com: non-commercial, no app, one
narrow bourbon-native problem, an explicit ask for contributions, and the author
giving up control of the data.

The research's recommendation is to build that registry as a free web utility
**first**, and let the app follow the data. That is a separate project from this
repository and it is not started.
