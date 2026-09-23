# Checking it by hand, on the phone

A build that succeeds proves the code compiles. The 740 automated tests
prove the maths and the database. Neither proves that tapping the button on
screen reaches the code underneath it, which is the only part a person can
actually see — and it is where both of this project's real bugs lived.

This is that gap, as twenty minutes of tapping. Every expected number below
comes from `shared/vectors/pour-math.json` or from a test that pins it, so a
disagreement is a defect rather than a matter of opinion.

Work down the list. If a number matches, that path is proven end to end and
does not need looking at again.

---

## 1. The fill, which is the number everything else rests on

Add a bottle at **750 ml**, unopened.

| Step | What the screen must say |
|---|---|
| Just added, opened | **17 pours**, 750 ml |
| After 1 pour | 16 of 17, 705.6 ml |
| After 4 pours | **13 of 17**, 572.6 ml |

The denominator stays **17**. If it counts down with the numerator — 13 of
13 — the bottle is being measured against what is left rather than what it
held, and every cost-per-pour figure in the app is wrong with it.

Then, on the same bottle, **Set level** to **300 ml** and pour twice more.

| Step | What the screen must say |
|---|---|
| Right after setting the level | 300 ml, 7 of 17 |
| After 2 more pours | **211.3 ml, 5 of 17** |

This is the one to watch. The reading has to REBASE the bottle: pours before
it stop counting and only pours after it come off. If the screen instead
shows the level dropping from 572.6, the reading was accepted and ignored,
which is exactly how the Android side was broken for a week while every one
of its tests passed.

Two edge cases worth ten seconds each:

- Set the level **above** the bottle's size — 900 on a 750. It must clamp to
  full, not draw a fill bar past the top of the glass.
- Pour from a nearly-empty bottle until it stops. It must reach **empty**,
  never a negative number of pours.

## 2. The question the app exists for

You need three bottles for this, and it is worth setting them up properly
because it is the only test of the thing people will judge the app on.

1. A bottle you own, from the catalogue.
2. A bottle from the same line but a different release — the standard
   bottling if you own a pick, or the other way round.
3. Something you have never had.

Search each on the **Shelf check** tab:

| Bottle | Verdict |
|---|---|
| The one you own | **ON YOUR SHELF** |
| Same line, other release | **HAVE THE LINE** — not "on your shelf" |
| The stranger | **NEVER HAD IT** |

Now finish the first bottle and search it again. It must change to **HAD IT
BEFORE**. If it still says ON YOUR SHELF, the app will tell you in a shop
that you own something you drank last year.

Then — and this is the one worth doing carefully — **type a bottle in
yourself** rather than picking it from the catalogue, and search for it. It
must read **ON YOUR SHELF**. A typed-in bottle answering NEVER HAD IT is the
bug that shipped once already: the form matched a catalogue product, filled
itself in, and threw the id away.

## 3. Everything under More

Twenty-four rows, in two groups. Most need only opening: what you are
looking for is a screen that loads, says something sensible when there is no
data, and does not crash.

**Tools** — Ask, Decode a code, Browse the catalogue, Your collection,
What's open, Tonight, Your palate, Try next, Sync, Wishlist, Hunt log,
People, Passport, Your year, Taste a flight, Pick my pour, Shelf walk.

**Your data** — Share your collection, Import a spreadsheet, Your Blanton's
for the dump-date registry, Share the registry CSV, Back up and restore,
Insurance report, Shelf labels.

Four of them do something you should check rather than just glance at:

- **Ask** — say "what's open". It must list the bottles you have open, not
  everything you own.
- **Decode a code** — enter **OESQ**. It must come back with the E mashbill
  (75 corn / 20 rye / 5 malt) and the Q yeast's floral character. This is
  the feature somebody who buys Four Roses picks will test first.
- **Export everything as CSV** — four or five files named `pour-memo-*.csv`.
  Open one. Every bottle you own should be a row.
- **Back up and restore** — write a backup, then restore it. Nothing should
  change: restoring merges, and restoring the same file twice is a no-op.

## 4. The things only a device can prove

None of these exist in the simulator, so they have never been run anywhere.

- Add the **What's open** widget to the Home Screen. Tap a pour button on
  it. The count must go down on the widget AND on the bottle in the app.
- **Spotlight**: leave the app, search the phone for a bottle's name, and
  open it from the results. It must land on that bottle.
- **Siri**: "What's open in Pour Memo". The phrase follows the display name,
  so this also proves the rename reached everything.
- Rotate to landscape, and on an iPad open the sidebar. Nothing should
  truncate to ambiguity.
- Turn on **VoiceOver** and swipe through one bottle screen. Every control
  should say what it does rather than reading out a symbol name.
- Turn text size up to the largest accessibility setting on the Collection.
  Rows should grow, not clip.

## 5. Sync, only if you are shipping it on

Sync needs patch 0013 applied to Supabase first, or account deletion answers
with a 404 — see section 0 of the release checklist.

- Sign in, sync, and confirm the bottle count matches.
- Sign out. **Nothing on the phone may disappear.**
- Delete the account. The server rows go; the phone keeps its bottles.

---

## What this does not cover

Being straight about the edges:

- Nothing here proves the app behaves on a **cold install** with no data.
  Delete the app, reinstall, and open every tab once — empty states are the
  first thing a reviewer sees and the last thing anybody tests.
- Nothing here exercises a **large collection**. If you have two hundred
  bottles somewhere, import them and watch the Collection scroll.
- The catalogue's facts are **not verified**. 899 products carry no source
  URL, which the app now says on each bottle rather than hiding. That is a
  disclosure, not a fix.
