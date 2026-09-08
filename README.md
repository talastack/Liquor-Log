# Liquor-Log

A bourbon and American whiskey collection log. Native iOS (Swift), with a
shared backend and data layer a future Android client consumes.

The barrel is the object, not the label. Store picks, single barrels, recipe
codes, batch codes, dump dates, warehouse and rick: every one of those lives on
the bottle, which is why a catalogue lookup is a convenience here and never the
foundation. Beer is deliberately out of v1 -- see `docs/00-positioning.md`.

> You are standing in a shop with a bottle in your hand. Do you already have it?
> Do you have *this* release, or just the standard bottling? Did you like it?
> That question is the product; everything else is the input that answers it.

## Layout

```
docs/       the build specification
shared/     Postgres schema, RLS, sync contract, catalog & reference data
IOS/        the Swift app
  Packages/LiquorEngine/   every calculation. no dependencies at all
  Packages/LiquorData/     GRDB persistence and sync
  App/                     SwiftUI
Android/    placeholder. post-v1
scripts/    repo checks
```

## Status

`LiquorEngine` and `LiquorData` are real and tested. The SwiftUI layer is
written but **has never been compiled**: there is no Swift toolchain on the
machine it was authored on. The engine's tests pass on a Linux CI runner -- see
the badge on the Actions tab -- but **the app has not been built on a Mac
yet.**
It was authored on Windows, with no Swift toolchain or Xcode. Expect small
import and signature fixes on the first Xcode build; the surface is bounded
because there are few implementation bodies to be wrong.

## Build

```bash
# Anywhere with a Swift toolchain -- no Mac needed
cd IOS/Packages/LiquorEngine && swift test
```

`LiquorEngine` is dependency-free on purpose: the code most likely to be wrong
in a way a user would notice -- a pour count, a proof, an age -- stays testable
on any machine, including a free Linux CI runner and the Windows box this was
written on.

## Three things to know before changing anything

**Class and production are different axes.** `class_type` is the TTB
designation -- is it *straight*, is it bonded -- and `production_type` is how it
was selected: single barrel, small batch, blend. Elijah Craig Barrel Proof is
Kentucky Straight **and** small batch **and** barrel proof. Collapsing these into
one enum forces a choice between three true things, and it is what makes the app
unable to answer "do I have this bourbon, or do I have *this type*?"

**Owning a line is not owning a release.** `ShelfCheck` reports
`haveTheLineNotThisRelease` as a first-class verdict. Owning the Small Batch must
not make the Barrel Proof read as owned, and must not make it read as never had
either. `ShelfCheckTests` pins this.

**Pour rounding is round-to-nearest, for capacity and remaining alike.** A full
750 ml bottle reads 17 pours and a full 700 ml reads 16 -- the two numbers the
1.5 US fl oz constant is pinned by. Flooring gives 16 and 15 and contradicts
both. Millilitres always travel alongside the count so the rounding never has to
carry weight on its own.

## Data

No paid API, ever, and no runtime third-party dependency -- the app has to work
in a shop with no signal. Every fact in `shared/data/` traces to a named, free,
legally reusable public record, and every catalog row carries its `source` and
`source_url`. See `docs/05-data-sourcing.md`.

A row that fails validation is dropped from the build rather than shipped with a
warning. An incomplete catalog degrades to typing it in yourself, which the app
supports anyway. A wrong catalog degrades to a wrong proof inside a
cost-per-pour figure, and nobody ever notices.

## What this app will not do

It never estimates intoxication. No BAC calculator, no standard-drinks total
against a limit, no drinks-per-hour pacing, not behind a toggle and not with a
disclaimer. A pour tracker is one feature away from being something a person
makes a driving decision with, and it has none of the inputs that would make
such an estimate anything but a guess wearing authority it has not earned.
