# Release checklist

Everything between the code as it stands and a build on the App Store,
in the order to do it. Every step here is one only a person with the Mac,
the Supabase project or the Apple account can take; CI has already
proven the code (`swift test` on Linux and macOS, `xcodebuild test` on a
simulator, the schema applied to a live Postgres, on every push).

Tick the boxes as you go. Where a step needs a decision, the decision is
named and where it lands in the repo is given.

## 1. On the Mac

- [ ] `cd ~/Liquor-Log && git pull` — `main` carries everything.
- [ ] `cp IOS/Secrets.example.xcconfig IOS/Secrets.xcconfig` if it is not
      there yet, and fill in `SUPABASE_HOST` and `SUPABASE_ANON_KEY` from
      the project's Settings → API. The anon key is not a secret; a
      service-role key must never appear in this file or anywhere in the
      app.
- [ ] `cd IOS && xcodegen generate && open LiquorLog.xcodeproj`.
- [ ] Run on your phone (not just the simulator: the widget, Spotlight
      and Siri only prove themselves on a device).
- [ ] First launch moves the database into the app group container. Open
      the Collection and confirm every bottle is there.
- [ ] Walk the new screens under More: Hunt log, People, Passport, Your
      year, Try next, Tonight, Your palate; Sync → household; Your data →
      "Export everything as CSV" (four or five files when there is data).
- [ ] Ask: "what's open", "saw Blanton's at Total Wine for $75, 3 on the
      shelf", "where did I see Blanton's", "what did Mike send me",
      "visited Buffalo Trace", "have I been to Buffalo Trace".
- [ ] Siri: "What's open in Liquor-Log", "Ask Liquor-Log". (The phrases
      follow the display name; see step 4.)
- [ ] Add the What's open widget to the Home Screen and tap a pour button.
- [ ] Search the phone for a bottle's name (Spotlight) and open it.

## 2. Supabase

Project ref `fppntlzyorvfnncgpvmo`. The runbook is `shared/schema/README.md`.
Done on 16 September 2026:

- [x] Patches 0002 through 0012 applied in the SQL editor; 17 tables and
      the two community views present.
- [x] `rls/policies.sql` applied; `rowsecurity` true on every table.
- [x] RLS proven by direct API call against the live project: a row owned
      by user A is invisible anonymously and to user B; B cannot insert in
      A's name (42501) nor rewrite A's row; the server clock trigger
      stamps `server_updated_at`.

Still to do:

- [ ] `npx supabase@latest login`, `npx supabase@latest link --project-ref
      fppntlzyorvfnncgpvmo`, `npx supabase@latest functions deploy menu
      --no-verify-jwt`, from the repo root. Publish a menu from the app and
      open its link.
- [ ] The dashboard now issues keys as `sb_publishable_…` (the anon key's
      new name) and `sb_secret_…` (the service role's). The publishable one
      is what `SUPABASE_ANON_KEY` takes; the secret one never leaves the
      dashboard.

## 2b. Sign in with Apple and with Google

Neither provider is on yet; the app's code for both is done and tested.
Apple is required by guideline 4.8 once Google is offered, so they go on
together or not at all.

**Supabase dashboard** (project `fppntlzyorvfnncgpvmo`):

- [ ] Authentication -> URL Configuration -> Redirect URLs: add
      `liquorlog://auth-callback`. Without it GoTrue refuses to send the
      browser back and Google sign-in ends in an error.
- [ ] Authentication -> Sign In / Providers -> **Apple**: enable, and put
      the app's bundle id (`com.talastack.liquorlog`, or whatever it
      becomes) in **Client IDs**. The Team ID / Key ID / secret fields
      below it are for the web flow only; the app uses the native one, so
      they stay empty.
- [ ] Authentication -> Sign In / Providers -> **Google**: enable, and
      paste the client ID and secret from the Google Cloud step below.

**Google Cloud console** (console.cloud.google.com, free):

- [ ] Create a project, then APIs & Services -> OAuth consent screen:
      External, app name, support email, and the app's privacy policy and
      terms URLs (the same ones from section 3 -- Google asks for them
      before it will let the screen out of testing).
- [ ] Credentials -> Create credentials -> OAuth client ID -> **Web
      application** (not iOS: the redirect goes to Supabase, not to the
      app). Authorised redirect URI:
      `https://fppntlzyorvfnncgpvmo.supabase.co/auth/v1/callback`.
- [ ] Copy the client ID and secret into Supabase's Google provider.

**Apple Developer** (developer.apple.com):

- [ ] The App ID needs the Sign In with Apple capability. Xcode adds it
      from the entitlement when the app is signed, so this usually happens
      by itself on the first run; check Certificates, Identifiers &
      Profiles if the button errors.
- [ ] **Before submitting with Sign in with Apple**: Apple requires that
      deleting an account also revokes the Apple token
      (`appleid.apple.com/auth/revoke`). "Delete my account" removes the
      Supabase account today but does not yet call Apple's revoke
      endpoint; that needs an Edge Function holding the team's .p8 key,
      and the key cannot be made until the App ID exists.

**Then, to verify:** sign in with Apple on a device, check a row appears
under Authentication -> Users, sign out, sign in again and confirm the
same user id comes back (not a second account).

## 3. Decisions

- [ ] **The app's name.** Today it is "Liquor-Log" under the icon
      (`IOS/App/Resources/Info.plist`, `CFBundleDisplayName`) and
      `com.talastack.liquorlog` as the bundle id (`IOS/project.yml`). The
      bundle id cannot change after the first upload; the display name
      can. The Siri phrases use whatever the display name is.
- [ ] **The Pro price.** Set in App Store Connect on the two products
      `com.talastack.liquorlog.pro.yearly` and
      `com.talastack.liquorlog.pro.monthly` (`IOS/App/Store/ProStore.swift`).
      The app reads the price from the product; nothing in the code needs
      changing when it moves. The research's rule: it never scales with
      the size of the collection.
- [ ] **Privacy policy and terms.** Drafts are `docs/privacy-policy.md`
      and `docs/terms.md`. Host them at public URLs (GitHub Pages of this
      repo is enough), then put the URLs in
      `ProStore.termsURL` and `ProStore.privacyURL`; the paywall shows the
      links once they are non-nil. Apple requires both beside an
      auto-renewable subscription, and the privacy URL again in App Store
      Connect.

## 4. App Store Connect

- [ ] Create the app record with the bundle id from step 3.
- [ ] Create the two subscription products with the ids above, in one
      subscription group; set the prices.
- [ ] App privacy questionnaire. What the app collects, all optional and
      all off by default: account email (sign-in, for sync); the
      collection, tastings, hunt log and visits (synced to the user's own
      rows under RLS); anonymous shelf-price and wax-drip reports (only
      with sharing on). Nothing is used for tracking; there is no
      advertising and no third-party analytics.
- [ ] Age rating: the app is about spirits; answer the alcohol question
      honestly ("infrequent/mild references" is the usual outcome for a
      catalogue app with no drinking encouragement). Guideline 1.4.3 is
      what the design was built against: the app counts bottles, never
      drinks; no pacing, no BAC, no streaks, no drinking games, no
      notifications that nudge consumption.
- [ ] Screenshots from the device: Shelf check with a verdict, a bottle
      with its fill bar, the tasting sheet, the Collection, the hunt log,
      the story card.
- [ ] Review notes: mention that Sync and Pro are optional and the app is
      fully usable offline with no account; give the reviewer a
      Pro-testing note (StoreKit sandbox) and, if households are to be
      reviewed, a second sandbox account.

## 5. Archive and upload

- [ ] Bump `MARKETING_VERSION` / `CURRENT_PROJECT_VERSION` in
      `IOS/project.yml` if needed, `xcodegen generate` again.
- [ ] Product → Archive with the LiquorLog scheme, signed under
      TALASTACK LLC (`UARGCN2739`, automatic signing; the team is written
      in `project.yml` so regeneration keeps it).
- [ ] Upload, wait for processing, attach to the version, submit.

## After the first release

Things the code is ready for but which need a person:

- COLA verification of catalogue entries (`docs/05-data-sourcing.md`).
- The Blanton's dump-date registry: contributions arrive as CSVs from
  users; the bundled `DumpDateRegistry` is rebuilt from them.
- Community views: once three or more shelf prices exist for a product
  in a region, the aisle price check starts showing the range. Nothing to
  do; it is a note on what to expect.
