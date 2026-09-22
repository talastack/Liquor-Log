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

- [x] **The app icon.** `IOS/App/Resources/Assets.xcassets`, a single
      1024x1024 RGB PNG with no alpha, cropped so the art runs to the edge
      and iOS applies its own corner mask rather than double-rounding one
      that was already rounded. `scripts/check_app_icon.py` guards the size
      and the alpha channel, both of which are refused at validation rather
      than at build.
- [x] **The app's name.** "Pour Memo", in `CFBundleDisplayName`. The Siri
      phrases are built from `.applicationName` so they follow it, and the
      iPad sidebar title is set to match.
- [ ] **The bundle id, if it is to match the name.** It is still
      `com.talastack.liquorlog`, and nothing has been uploaded yet, so this
      is the last moment it can change. Changing it means changing the App
      Group, the `liquorlog://` URL scheme, the widget's id and the Supabase
      redirect URLs together. Leaving it is invisible to everybody except
      you; changing it after the first upload is impossible.
- [x] **The privacy manifest.** `IOS/App/Resources/PrivacyInfo.xcprivacy`,
      declaring UserDefaults with reasons CA92.1 and 1C8F.1, in both the
      app and the widget bundle. Without it an upload is answered with
      ITMS-91053 after the archive, not before.
      `scripts/check_privacy_manifest.py` keeps it honest as the app grows.
- [ ] **Turn GitHub Pages on.** The pages themselves are built and in the
      repository: `docs/privacy.html`, `docs/terms.html` and an index, all
      generated from the Markdown by `scripts/build_pages.py` and kept in
      step by `scripts/check_pages.py`. All that is left is the switch:
      repository Settings -> Pages -> Source: *Deploy from a branch*,
      branch `main`, folder `/docs`. The privacy URL is then
      `https://talastack.github.io/Liquor-Log/privacy.html`, which is what
      goes into App Store Connect.
- [ ] **Check `privacy@talastack.com` actually receives mail.** It is the
      contact address on both published pages. A policy naming a mailbox
      nobody reads is worse than one naming none.
- [ ] **Two schema patches the live project has not had.** Section 2
      records 0002 through 0012 as applied on 16 September. `0013` and
      `0014` were written after that and are still only in the repository.
      Both matter before a reviewer touches the app:

      - `0013_delete_account.sql` creates `delete_my_account()`, which is
        what the app's "Delete my account" button calls. Until it exists
        on the server that button answers with a 404 from PostgREST.
        Apple's reviewer tests account deletion, and guideline 5.1.1(v)
        is a rejection, not a note.
      - `0014_community_thresholds.sql` moves the "three reports before a
        figure is shown" rule out of Swift and into the views. The
        publishable key ships in every binary by design, so until this is
        applied anyone can ask the view for `reports=eq.1` and read one
        person's exact price, their state and the day they saw it. The
        privacy policy, now published, says other users see only totals.

      Paste both into Database -> SQL, in order, then `rls/policies.sql`
      again. The runbook is `shared/schema/README.md`.

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
- [ ] Siri: "What's open in Pour Memo", "Ask Pour Memo". (The phrases
      follow the display name; see step 4.)
- [ ] Add the What's open widget to the Home Screen and tap a pour button.
- [ ] Search the phone for a bottle's name (Spotlight) and open it.

## 2. Supabase

Project ref `fppntlzyorvfnncgpvmo`. The runbook is `shared/schema/README.md`.
Done on 16 September 2026:

- [x] Patches 0002 through 0012 applied in the SQL editor; 17 tables and
      the two community views present.
- [ ] **Patches 0013 and 0014 are still outstanding** -- see section 0.
      They were written after this date. Apply them, then `rls/policies.sql`
      again.
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

- [x] **The app icon.** Done. `IOS/App/Resources/Assets.xcassets`
      carries `AppIcon.appiconset` with the 1024x1024 image, and
      `ASSETCATALOG_COMPILER_APPICON_NAME` is set in `IOS/project.yml`.
      A single 1024 image is enough for a modern target; Xcode derives
      the rest.
- [x] **The app's name.** Done: "Pour Memo" under the icon
      (`IOS/App/Resources/Info.plist`, `CFBundleDisplayName`). The Siri
      phrases are built from `.applicationName`, so they followed it
      without an edit, and so will anything else that asks the system
      what the app is called.

      The **bundle id** is a separate decision and is still open; it is
      in section 0. It is `com.talastack.liquorlog` and cannot change
      after the first upload.
- [x] **Privacy policy.** Written and built into a page:
      `docs/privacy-policy.md` is the source, `docs/privacy.html` is what
      a reviewer opens, and `docs/terms.html` sits beside it. Turning
      GitHub Pages on is the one step left, and it is in section 0.

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
