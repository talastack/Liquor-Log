# What the app does

Every feature, where it lives, and what it rests on. Written 15 September 2026
from the code on `research-features`; every item here compiles and is covered
by CI (391 engine tests, 113 data tests, the app built for the simulator).
Nothing listed is a stub.

Engine files are `IOS/Packages/LiquorEngine/Sources/LiquorEngine/`, data files
`IOS/Packages/LiquorData/Sources/LiquorData/`, screens `IOS/App/Features/`.

---

## Shelf Check — the home tab

The aisle question, offline: *do I already own this?*

- Search by distillery, brand or expression; three example chips.
- Six verdicts, each a badge and a sentence: on your shelf · have a sample,
  no bottle · have the line, not this release · tasted, never owned · had it
  before · never had it.
- **Tap the brand** on a card → every expression of that line with your
  standing on each, and "3 of the 7 releases the catalogue lists have
  been on your shelf" — a count of bottles, never of tastings, and not a
  checklist (`LineView`). Your collection lists every line the same way.
- **Price on the shelf?** — type it, get it against what you usually pay,
  the shelf reference, and your wishlist ceiling (`PriceHistory`,
  `PriceCheck`).
- **You might also mean** — related products (same line, recipe, distillery),
  yours first (`BottleSearch.related`).
- Your note on the product shows on the card (`KnowledgeNoteRepository`).
- **You said** — the last tasting of it as one line: "Last time, in March:
  8/10, would buy again. Liked toffee. Not the heat." Built only from what
  was recorded; also on Pick my pour, the line sheet and Browse
  (`TastingRecall`).
- Recent lookups, per device.
- **Scan** — camera or photo; Apple Vision reads proof, batch, barrel, recipe
  code, age, laser code, DSP; barcode scan against your own barcode table
  (`LabelReader`, `BarcodeIndex`). No model, nothing uploaded.

## Collection

- Search, status chips (on the shelf · open · unopened · finished ·
  everything), kind chips (store pick, single barrel, barrel proof, bourbon,
  rye, samples, infinity bottles…), place chips, seven sorts (`CollectionFilter`).
- **Samples** — a sample is a bottle in every way but size and provenance:
  30/50/60/100 ml, who it came from, how (gift, swap, bought, decanted).
  Shown as "Sample · 50 ml · from Mike", searchable by the name, counted
  apart from bottles, kept off the guest menu; the shelf check says "have a
  sample" rather than "on your shelf".
- "1 of 3" on multiples of one pick (`Multiples`).
- Long-press → others like this on your shelf.
- Empty shelf offers three ways in: scan a shelf, import a spreadsheet, add one.
- Photo thumbnail on the card; a grid button shows the shelf as photos,
  three across.

## A bottle

- Fill bar as pours and ml (and oz if you like); **Set level** by eye —
  a reading, not a subtraction (`PourMath`, `fill_readings`) — or **by
  weight**: weigh the bottle once at a known level (new is full) and the
  app keeps the empty bottle's weight; every weighing after is a level to
  a few millilitres, because density is fixed by proof (TTB Table 6 with
  the Gauging Manual's constants; `Weighing`). No app does this.
- Pour log with undo; readings log; open-date oxidation band (`OxidationBand`).
- **How it has drunk** — every tasting, day-N-open, and the trend as a
  sentence (`TastingTrend`).
- Price card: what you paid, cost per pour, what you usually pay, shelf
  reference; never a resale value.
- Facts: class and production as two rows, recipe/mashbill, chill filtration,
  bought (and days owned), in the barrel, bottled (years in the glass), size,
  **Made at** from the DSP (`DistilleryPermit`).
- **This barrel**: pick group, store, barrel, warehouse/rick/floor, dump date,
  recipe, age, entry proof, char, finish, bottle number, Blanton's topper
  letter, producer warehouse lore (`WarehouseLore`); **Share this pick** as
  a record (`PickCard`).
- **Against the standard release** (`PickCompare`).
- **Water** — how much takes this pour to 110/100/90/80 or any proof, and
  what proof a splash you already added landed at. TTB Gauging Manual
  Table 6 (27 CFR 30.66), contraction included; a kitchen measure beside
  the millilitres (`Proofing`).
- **The wax** — measure a Maker's drip from a photo, ranked among your own
  (`WaxDrip`). **The staves** — a Private Select recipe as a flavour profile,
  compared with your other picks (`StaveRecipe`).
- Your note on the product; you have N more of this (siblings).
- Menu: pours at ½/1/1½/2 oz or any amount, **pour for someone** (a sample
  decanted for a friend — comes off the fill, logged against their name),
  mark opened, mark finished, remove, share as an image. Photo:
  take/choose/remove.
- Nearly-gone → wishlist offer, asked once (`Replenish`).
- **The story of this bottle** — the record in order with the gaps in
  days: bottled (from the label year), bought where and for what, opened
  after N months on the shelf, each pour and who it went to, each tasting
  and how the rating moved, each level set by eye or by weight, finished N
  weeks later; a one-line summary and a card to share (`BottleStory`).
  Nothing inferred: an event with no date is not an event.

## Adding

- **Add a bottle** — catalogue search or type it in; scan fills the form;
  already-opened slider; shelf price; bought-on date; DSP; bottled year.
- **Add a shelf** — scan after scan, nothing in between.
- **Start an infinity bottle** — an empty vessel you fill from your other
  bottles. Each addition is a pour off the source (both fills move, both
  undo together) or something typed in by name and proof. The bottle shows
  its strength — alcohol over volume, as blending records are kept, or
  "unknown, N ml went in without a proof" — and its make-up as shares of
  what went in, which pours out never change (`Blend`, `blend_additions`).
  Other bottles get "Pour into <name>…" in their menu.
- **Import a spreadsheet** — CSV, columns matched by name, all-or-nothing
  (`CollectionImport`, `CSVReader`). A "sample" column imports a samples
  tab: "yes" or a name.
- **Record a tasting** without a bottle — what it was, where (bar, friend's,
  sample, store, event).

## Tasting

- Nose / entry / mid / finish with a 252-descriptor wheel (`FlavorWheel`);
  faults coloured as faults; heat vs proof (`PerceivedProof`); finish length;
  rating; would-rebuy; liked / not.
- **A flight** — 2–4 open bottles, blind (A/B/C/D) until all are rated.
- The Tastings tab lists every tasting, bottle or not.

## More

- **Ask** — "log a pour of Weller 12", "what's open", "how many Wellers do I
  have", "rate the Stagg an 8"… Grammar in the engine (`Ask`), execution in
  `AskService`, confirmation before any write; Apple's on-device model as an
  optional rephraser on iOS 26 (`AskModel`). Nothing leaves the phone; no
  "AI" on screen. Also the hunt log and the people: "saw Blanton's at
  Total Wine for $74.99, 3 on the shelf", "entered the Stagg lottery at
  Virginia ABC", "where did I see Blanton's", "what did Mike send me",
  "visited Buffalo Trace", "have I been to Four Roses".
- **Decode a code** — Four Roses recipe, Heaven Hill batch, Buffalo Trace
  laser code, Wild Turkey bottling code (four formats, 1992 on), DSP
  permit, tequila NOM or brand against the CRT's registry of 201 producers
  and 2,577 brands, and a tick-list for dating a dusty (tax strip, IRS/ATF,
  4/5 quart, metric…) that returns a window, never a date (`RecipeCode`,
  `BatchCode`, `LaserCode`, `WildTurkeyCode`, `DistilleryPermit`,
  `TequilaRegistry`, `DustyClues`).
- **Browse the catalogue** — 971 products by distillery, each with your
  standing; add or wish from the row.
- **Your collection** — counts, by kind/distillery/brand/strength/place,
  added-by-year, notable (strongest, oldest, open longest, Blanton's set),
  samples on hand, **given away** (every pour marked as somebody else's);
  money behind the switch; share as a card (`CollectionStats`).
- **What's open** — a guest menu as text or image (`PourMenu`), and, for
  With an account, **as a link**: a page served by the `menu` Edge
  Function at an address nobody can guess, republished under the same
  link, taken down on request (`HostedMenu`).
- **Your palate** — from your tastings: the words you reach for (counted
  once per tasting), average rating by class, by strength band, wheated
  against other bourbon, when it drank hot against easy, your typical
  finish, how often you'd buy again — and **label bias**: bottles you
  rated both blind (in a flight) and knowing what they were, paired by
  product; "knowing the label adds 1.4 points" or "the label does not
  move you". Three ratings a side, three pairs, before anything is said
  (`Palate`). No journal app tells you this.
- **Try next** — catalogue products related to the bottles you rated 7 or
  better — same line, same recipe code, same mashbill, same distillery —
  minus everything you have had, each row saying which bottle of yours put
  it there and why. Structural, no taste model; add or wishlist from the
  row (`TryNext`).
- **Tonight** — the IBA's official cocktails (29 of them, the IBA's own
  measures) against your open bottles: ready ones with the bottle chosen
  for each slot (highest rated, then fullest), then those one bottle
  short with what would fill it, sealed bottle named if you have one.
  Slots match by class — sweet vs dry vermouth, white vs dark rum and the
  named liqueurs by name (`Cocktails`).
- **Signing in** — a page, not a gate. Sign in with Apple (native, no
  browser), Continue with Google (the system's sign-in browser, PKCE, no
  Google SDK), or an email address; and **Continue without an account**,
  weighted like the others, because every screen works without one. The
  page says what an account does and what stays true either way: nothing
  leaves the phone until you sign in, the bottles stay here regardless,
  export and backup are free either way (`SignInView`, `SupabaseAuth`).
- **Sync** — optional, Supabase, two-clock LWW (`SyncEngine`).
  **Delete my account** under it: the server account and everything
  synced under it go (a definer function, patch 0013); the collection on
  the phone stays and is unlinked, ready for a new account. App Store
  5.1.1(v).
- **Share with a partner** (under Sync, signed in) — a household: create
  one and pass on its six-character code, or enter a partner's. Both
  shelves show on both phones from the next sync; what each of you logs
  stays attributed to you. Leave at any time. Server-side: households,
  definer functions, and every data table's policy reading "yours, or a
  household member's" (patch 0009).
- **Sharing** (off by default) — shelf prices you type and wax drips you
  measure go up as anonymous reports carrying only your state; switching
  it off withdraws them. In return the aisle price check shows "N shelf
  prices reported in KY, $X to $Y" once three or more exist, and the wax
  card says where your drip falls among everyone's measured ones
  (`CommunityService`, `ReportRepository`, the `community_prices` and
  `community_drips` views). Nothing is a valuation.
- **Wishlist** — ceiling, buy it (one transaction), change the price, share
  as a gift list, finished-lately → buy again; each row says where the
  hunt log last saw it, when, at what.
- **Hunt log** — the half of collecting that happens before a bottle is
  bought. A sighting: a bottle seen on a shelf, where, at what price, how
  many (zero counts: it was there and went). An entry: a lottery or raffle
  entered, who runs it, and won / lost / pending. Read back as stores
  ranked by what you have found there (spellings merged, "3 products · 2
  from your wishlist · last 3 weeks ago"), your wishlist against the last
  60 days of sightings, and "4 entered · 1 won · 2 pending". A shelf-check
  card shows your last sighting of the product and logs a new one with
  the price already typed; "Bought it" on a sighting opens Add with the
  store and price filled and points the sighting at the bottle. Prices go
  into the community reports when sharing is on. Synced, backed up, in
  the household. Your own record only; nothing says where a bottle is
  now (`Hunt`, `SightingRepository`, `sightings`, patch 0011).
- **People** — the swap ledger, read rather than kept: every sample that
  names who it came from and every pour marked as somebody else's,
  grouped by person (spellings merged). Per person: "2 samples from them
  · 1 pour to them · last 3 days ago", whose turn it is in millilitres
  ("They have sent 60 ml more than you have", "About even" inside one
  pour), and, over two or more rated samples, "Their samples average 8.5
  with you". Tap through to both lists with dates, sizes and your
  ratings. Nothing about how much anyone drank; what changed hands
  (`People`). No schema change.
- **Your year** — a calendar year of collecting in sentences, from the
  record: "14 bottles added, from 9 distilleries. Buffalo Trace most, 4
  times." / "Mostly kentucky straight bourbon: 9 of them." / "First of
  the year: Weller 12, 3 January." / "23 tastings
  written. Highest: Stagg, 9/10." / "The word you reached for most:
  caramel, 11 times." (once per tasting) / "5 samples from Mike, Sarah."
  / "31 sightings at 6 stores; Total Wine most." / "3 lotteries entered,
  1 won." What it cost appears only behind the money switch, and never on
  the share card. Nothing about pours or bottles emptied, no comparison
  with last year, no streak (`YearInReview`).
- **Passport** — the distilleries you have stood in: a visit is a place
  (from the catalogue's list, or typed) and a day. Read back as a stamp
  per distillery ("2 visits · first March 2024 · last 3 weeks ago") with
  what the shelf says about it — "2 bottles from there on the shelf, 1
  bought there" — and the list that is actually useful: the distilleries
  whose bottles you own and have never visited, most bottles first. Not
  a checklist of the catalogue. New table `visits` (patch 0012), synced,
  backed up, exported (`Passport`, `VisitRepository`).
- **Taste a flight**, **Pick my pour**, **Shelf walk** (`ReInventory`).
- **Look** — Cellar (default), Label, Bond, Amber.
- Money switch; ounces switch.
- **Your data** — CSV export, always free: the bottles (57 columns), and
  alongside it every tasting with its wheel picks per stage, every pour
  with who it went to, and the hunt log, each as its own file when there
  is anything in it; **back up and
  restore** everything including photos (`CollectionBackup`), Blanton's
  registry CSV (`DumpDateRegistry`), **insurance report** PDF,
  **shelf labels** — a PDF of stickers (30 a sheet, the 2⅝ × 1 inch
  address-label grid) with your number, the name and a QR the camera
  reads to open the bottle in the app (`ShelfLabelsPDF`). A published
  menu also shows its link as a QR to prop on the bar.
- **Money** — there is none. No purchases, no subscription, no tier and
  no billing code in the app. Every feature is available to everybody,
  which is also why nothing may be built on a service with a per-user
  bill without that decision being taken again, explicitly.

## On an iPad

The same four screens as a sidebar with the screen in the wide column
(`NavigationSplitView`), instead of a phone tab bar stretched across a
tablet; the photo grid runs six across. Everything else is the same view.

## Outside the app

- **Siri and Shortcuts** — "What's open in <the app>", "What's nearly gone
  in <the app>", and "Ask <the app>", which takes any sentence the Ask
  grammar knows: a question is answered, a command is read back and
  confirmed before it is written, as in the app (on iOS 17, where the
  only confirmation call left is deprecated, the command is read back and
  done in the app instead; nothing is ever written unconfirmed). Each returns its answer
  as text for a Shortcut to use. Runs in the app's own process against
  its own database (`AskIntent`, `WhatsOpenIntent`, `NearlyGoneIntent`,
  `LiquorLogShortcuts`).

- **What's open widget** — small, medium, large: your open bottles with a
  fill bar each and, from medium up, a pour button per bottle that logs one
  pour of its usual size without opening the app (an App Intent running
  against the shared database in the app group). Tapping the widget opens
  the Collection. Refreshed after every write and hourly.
- **Search** — every bottle on the shelf is in the phone's own search
  (Spotlight): name, distillery, "Open · 13 of 17 pours" or "Sample from
  Mike", where it is kept. A result opens the bottle.
- The database now lives in the app group container
  (`group.com.talastack.liquorlog`), in WAL mode with a busy timeout so
  the two processes share it; an existing one is moved there by the app
  on first launch, journal and all, and recorded by a marker so the move
  happens once. The widget never creates the database: before the app has
  run it says so.

## Not built, on purpose

Social feed, gamification, drink pacing or BAC, marketed AI, our own resale
price feed, beer. See `docs/00-positioning.md`.

## Waiting on something outside the code

Applying `shared/schema/README.md` to the live project and deploying the
menu function; COLA verification of the catalogue; the app's name
price, terms and privacy pages.
