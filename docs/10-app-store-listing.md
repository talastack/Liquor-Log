# The App Store listing, ready to paste

Every text field App Store Connect asks for, written out. Copy each one
across; nothing here needs thinking about at the keyboard at midnight.

Character limits are Apple's, and `python scripts/check_listing.py` counts
every field against its limit, so an edit that overruns is caught here
rather than by a form that refuses to save.

The subtitle, promotional text and description are written for somebody in
the App Store who has never heard of this app. The review notes are written
for the reviewer.

---

## App Name — limit 30

```
Pour Memo
```

## Subtitle — limit 30

```
Bourbon collection & tastings
```

## Promotional text — limit 170

Changeable any time without a new build. This is the field to edit when
something is worth saying; changing the description needs a review.

```
Standing in the shop with a bottle in your hand: do you have it already, or only the standard release? That question, answered offline, is the app.
```

## Description — limit 4000

```
Pour Memo keeps track of the bottles you own, what is left in each one, and what you thought of them.

It is built around the question you actually have in a shop. You are holding a bottle. Do you already have it? Do you have this release, or only the standard bottling? Did you like it last time? Pour Memo answers that in one search, with no connection — a liquor store is a concrete box, and that is the normal case rather than an error.

THE BARREL, NOT THE LABEL

Most apps stop at the label. If you buy store picks and single barrels, the label is the least interesting thing about the bottle. Pour Memo records the barrel number, who selected it, the shop it was picked for, the warehouse, the rick and the floor, the dump date, the entry proof and the char level — and keeps them apart, because a rick you follow across releases is only useful if it was never merged into one line of text.

Four Roses recipe codes are decoded: OESQ tells you the mashbill and the yeast, and Pour Memo says so in words. Batch codes are decoded where the scheme is known, and left alone where it is not.

WHAT IS LEFT

Every pour is a tap. The bottle shows what is left in millilitres or ounces, how many pours that is, what each one has cost you, and how long it has been open. Measured a bottle by hand? Set the level and the count rebases from there. Infinity bottles work the other way round: they start empty and rise with what you add.

TASTING NOTES WORTH KEEPING

Nose, entry, mid palate, finish. A flavour wheel to pick from when the words will not come. A rating, whether you would buy it again, and room for what you liked and what you did not. Every tasting of a bottle is kept, so an opinion that changed is visible as a change rather than overwritten.

AND THE REST OF IT

Where you saw what, and for how much. Distilleries you have visited. What a friend sent you and what you sent them. What to open tonight. What your palate has turned out to be, drawn from your own ratings rather than a guess.

HONEST ABOUT WHAT IT KNOWS

Bottles carry facts from a bundled catalogue, and each one says where its facts came from and whether anybody has checked them against a published source. A starting point you can correct is more useful than a confident wrong answer.

NO SUBSCRIPTION, NO ACCOUNT, NO TRACKING

There is nothing to buy. There is no advertising and no third-party analytics. The app works completely offline and needs no account at all. Signing in is optional and exists for one reason: so that a second device, or a partner, can see the same shelf. Your collection exports to plain CSV whenever you want it, and deleting your account removes everything from the server.

Pour Memo counts bottles. It does not count drinks, and it has no streaks, no pacing, and nothing that treats drinking more as progress.
```

## Keywords — limit 100, comma separated, no space after a comma

Singular and plural are matched for you, and the app name and subtitle are
already indexed, so repeating "Pour Memo" or "bourbon" here would spend the
allowance twice.

```
whiskey,whisky,barrel,single,pick,shelf,cellar,liquor,spirits,rye,scotch,pour,journal,notes,cabinet
```

## URLs

| Field | Value |
|---|---|
| Support URL | `https://talastack.github.io/Liquor-Log/` |
| Marketing URL | leave empty |
| Privacy Policy URL | `https://talastack.github.io/Liquor-Log/privacy.html` |

All of these need GitHub Pages switched on first — section 0 of the release
checklist.

## Category

Primary **Food & Drink**. Secondary **Lifestyle**.

Not Reference: the app is used while shopping and while drinking, not
consulted like an encyclopaedia, and Food & Drink is where somebody looking
for this would look.

## Copyright

```
2026 TALASTACK LLC
```

## Version and What's New

This is the first version, so What's New does not appear.
`MARKETING_VERSION` is what the store shows. `CURRENT_PROJECT_VERSION` is
the build number, which must increase on every upload even when the version
does not.

---

## Age rating

Answer honestly rather than defensively. The questionnaire asks about
"Alcohol, Tobacco, or Drug Use or References". This app is about spirits, so
the answer is not None. **Infrequent/Mild** is the usual outcome for an app
that catalogues and journals without encouraging consumption, and that puts
the rating at 17+.

Everything else is None: no violence, no sexual content, no gambling, no
contests, no user-generated content shown to strangers, no unrestricted web
access.

---

## App privacy questionnaire

The honest answers, in Apple's own categories. All of it is optional and
none of it happens until somebody signs in.

**Data used to track you:** none. No tracking, no advertising identifier, no
third-party SDK.

**Data linked to you:**

- *Contact info — email address.* Only if you sign in, and only to identify
  the account. Used for App Functionality.
- *User content — other user content.* Your collection, tastings, pours,
  hunt log and visits, when sync is on. Stored as your own rows and
  protected by row-level security. Used for App Functionality.

**Data not linked to you:**

- *User content — other user content.* Shelf-price and wax-drip reports,
  only if you switch sharing on. A report carries the product, the figure,
  the date and your state if you entered one. It carries no name, no email,
  no account id and no location. Used for App Functionality.

**Data not collected:** everything else — location, contacts, health,
financial info, browsing history, identifiers, diagnostics, usage data.

---

## Review notes

Paste this with the placeholders filled in:

```
No account is needed. Every feature except Sync works with no sign-in at
all, and the app is fully usable offline, so it can be reviewed exactly as
installed.

To review Sync, please use this account:
    <email>
    <password>

An account is supplied rather than asking you to sign up because the project
requires email confirmation, and the confirmation mail would go to an address
you do not control.

Households (two accounts sharing one shelf) need a second account, supplied
here in case you would like to test that too:
    <second email>
    <second password>

There are no purchases of any kind: no subscription, no in-app purchase, no
advertising and no third-party analytics.

On guideline 1.4.3: the app counts bottles, never drinks. There is no blood
alcohol estimate, no pacing, no streaks, and no notification that encourages
drinking. Pour tracking exists to show how much of a bottle is left and what
each pour cost, which is inventory rather than consumption.

The bundled catalogue is reference data about commercially available
products. Where a fact has not been checked against a published source, the
app says so on the bottle itself rather than presenting it as verified.
```

**Before pasting:** create the two accounts in the app and put the real
addresses and passwords in. Use throwaway addresses on a domain you control;
they stay inside App Store Connect and are not published.

---

## After the first upload

- The build takes ten minutes to an hour to finish processing before it can
  be selected on the version page. It is not stuck.
- Export compliance is already answered: `ITSAppUsesNonExemptEncryption` is
  `false` in `Info.plist`, so the upload does not stop to ask. That is the
  correct answer for an app whose only cryptography is HTTPS.
