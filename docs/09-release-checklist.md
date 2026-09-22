# Release checklist

Everything between the code as it stands and a build on the App Store,
in the order to do it. Every step here is one only a person with the Mac,
the Supabase project or the Apple account can take; CI has already
proven the code (`swift test` on Linux and macOS, `xcodebuild test` on a
simulator, the schema applied to a live Postgres, on every push).

Tick the boxes as you go. Where a step needs a decision, the decision is
named and where it lands in the repo is given.

## 0. What is blocking right now

Read this first. Everything else in this document is ordinary setup; these
are the things without which an upload is refused or a review fails.

- [ ] **The app icon.** There is no asset catalog in the repository at all,
      and an app cannot be submitted without an icon. Drop a 1024x1024 PNG
      (no alpha, no rounded corners -- Apple masks it) and the catalog can
      be built around it in minutes. This is the one hard blocker that
      cannot be worked around.
- [ ] **The app's name**, if it is changing from "Liquor-Log". It sets
      `CFBundleDisplayName`, the Siri phrases and the App Store listing.
      The bundle id `com.talastack.liquorlog` is fixed after the first
      upload; the display name is not.
- [x] **The privacy manifest.** `IOS/App/Resources/PrivacyInfo.xcprivacy`,
      declaring UserDefaults with reasons CA92.1 and 1C8F.1, in both the
      app and the widget bundle. Without it an upload is answered with
      ITMS-91053 after the archive, not before.
      `scripts/check_privacy_manifest.py` keeps it honest as the app grows.
- [ ] **A hosted privacy policy URL.** Apple requires one for every app.
      `docs/privacy-policy.md` is the draft; GitHub Pages on this repo is
      enough to host it.
- [ ] **Screenshots from a real device.** Cannot be faked and cannot be
      taken from the simulator for the App Store sizes you need.

**On the timing.** Submitting today means review overnight at the very
best. Apple's median is roughly a day, but it is not a promise, and a
rejection restarts it. Nothing in the code is what decides that.

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

**Proving an account's data is saved** -- run this after the providers are
on, and after any schema change:

- [ ] Two users in Authentication -> Users -> Add user, **Auto Confirm**
      ticked, then
      `python scripts/verify_sync.py --host fppntlzyorvfnncgpvmo.supabase.co
      --key sb_publishable_... --a a@x:pw --b b@x:pw`. It pushes and pulls
      over the same REST calls the app makes and checks the row lands, the
      server stamps its clock, the cursor advances, an edit wins, a stale
      write is refused, and the other account can neither read nor forge it.

**Then, to verify:** sign in with Apple on a device, check a row appears
under Authentication -> Users, sign out, sign in again and confirm the
same user id comes back (not a second account).

## 3. Decisions

- [ ] **The app icon.** See section 0. No asset catalog exists yet; add
      `IOS/App/Resources/Assets.xcassets` with an `AppIcon.appiconset`
      holding a 1024x1024 PNG, and set `ASSETCATALOG_COMPILER_APPICON_NAME`
      to `AppIcon` in `IOS/project.yml`. A single 1024 image is enough for
      a modern target; Xcode derives the rest.
- [ ] **The app's name.** Today it is "Liquor-Log" under the icon
      (`IOS/App/Resources/Info.plist`, `CFBundleDisplayName`) and
      `com.talastack.liquorlog` as the bundle id (`IOS/project.yml`). The
      bundle id cannot change after the first upload; the display name
      can. The Siri phrases use whatever the display name is.
- [ ] **Privacy policy.** A draft is `docs/privacy-policy.md`. Host it at
      a public URL (GitHub Pages of this repo is enough) and give that URL
      to App Store Connect. Apple requires one for every app. `docs/terms.md`
      is no longer required by the store -- there is nothing to sell -- but
      it costs nothing to host beside it.

## 4. App Store Connect

- [ ] Create the app record with the bundle id from step 3.
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
- [ ] Review notes: mention that the app is free with no purchases of any
      kind, that Sync is optional and the app is fully usable offline with
      no account, and -- if households are to be reviewed -- supply a
      second sandbox account.

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
