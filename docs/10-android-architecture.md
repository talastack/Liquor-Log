# The Android side: architecture

*Written for whoever builds it — you now, someone else later.*

The iOS app is ~37,000 lines: an engine of 8,900 (plus 5,500 of tests), a
data layer of 5,500, and 17,300 of SwiftUI. This document settles how the
Android app relates to that before any of it is typed twice, because the
expensive mistakes here are structural and are made in the first week.

---

## 1. The decision that shapes everything: two engines, not one

The obvious idea is Kotlin Multiplatform — write the domain logic once,
consume it from both platforms. **We are not doing that**, and the reason
is worth stating plainly because it will be questioned again later.

The Swift engine exists, is 546 tests green, and sits under an app that is
days from submission. Moving to KMP means deleting it, rewriting the iOS
app to consume a generated framework, adding Gradle to the iOS build, and
re-proving everything — on the platform that is nearly shipping, to save
duplication on a platform that does not exist yet. That trade is backwards.

So: **a parallel Kotlin engine.** iOS is untouched.

### The obvious objection, and the answer

Two engines drift. A rounding rule changes on one side and not the other,
and a 750 ml bottle reads 17 pours on a phone and 16 on a tablet — the
exact class of bug this codebase already guards against between the local
and Postgres schemas, with `scripts/check_schema_mirror.py`.

The answer is the same shape: **shared golden vectors.** A file of inputs
and expected outputs in `shared/vectors/`, read by *both* test suites.

    shared/vectors/pour-math.json
    { "cases": [ { "capacity": 750, "poured": 0,
                   "totalPours": 17, "remainingPours": 17 }, ... ] }

Neither engine owns the truth; the file does. A change to the rounding rule
fails on whichever platform did not follow, in CI, on the next push. This
is the one piece of shared infrastructure that must exist before the port
gets large.

**Status:** `shared/vectors/pour-math.json` exists, with sixteen cases, and
the Kotlin suite reads it (`GoldenVectorsTest`). **The Swift side is not
wired to it yet** — that means editing the iOS test target, which is out of
scope on this branch. Until it is, the vectors pin Kotlin against a file
computed from Swift's constants rather than against Swift itself. Wiring
`LiquorEngineTests` to read the same file is the first iOS-side task
whenever that branch is open again.

What is already shared and needs no port at all:

| Already platform-neutral | Where |
|---|---|
| The catalogue (534 products) | `shared/data/spirits.v1.json` |
| The flavour wheel | `shared/data/flavor-wheel.v1.json` |
| The CRT tequila registry | `shared/data/tequila-nom.v1.json` |
| The Postgres schema and RLS | `shared/schema/` |
| The sync wire format | `shared/contracts/` |

---

## 2. Modules

Mirroring the Swift layering, because that layering has held:

    Android/
      engine/   pure Kotlin, JVM only, zero dependencies
      data/     SQLDelight + sync + auth
      app/      Compose, ViewModels, Glance widget

**`engine` has no Android dependency at all.** It is a `kotlin("jvm")`
module, so its tests run in seconds on a free Linux runner instead of
booting an emulator — the same reason `LiquorEngine` is Linux-tested. This
is not a stylistic choice: the domain logic is where a bug is expensive and
where the tests need to be cheap enough to run constantly.

`data` may depend on `engine`. `app` may depend on both. Nothing depends
upwards, and `engine` never learns what a screen is.

---

## 3. Choices, with the reason attached

| Concern | Choice | Why this one |
|---|---|---|
| Local database | **SQLDelight** | The schema already exists as SQL in `shared/schema`. SQLDelight takes real SQL and generates typed Kotlin, so the Android schema can be *checked against Postgres by the same script that checks Swift's* — a three-way mirror instead of a second hand-maintained copy. Room would mean re-describing the schema in annotations, which is a third dialect to keep in step. |
| UI | **Jetpack Compose** | Declarative, matches how the SwiftUI screens are written, so porting a screen is a translation rather than a redesign. |
| State | **ViewModel + StateFlow** | The Swift side uses `@Observable` classes with a `changeCount` that screens watch. `StateFlow` is the same idea with the platform's own vocabulary. |
| Dependency injection | **Constructor injection, by hand** | The Swift side hand-rolls `AppEnvironment`; Hilt would be a large dependency to replace about forty lines. Revisit only if the graph gets genuinely deep. |
| Networking | **Ktor client, or `HttpURLConnection`** | The Swift side deliberately uses no SDK — the Supabase surface is four requests. Kotlin has no `URLSession`; Ktor is the smallest honest substitute. Not the Supabase SDK, for the same reason as iOS: a dependency that owns token refresh owns whether somebody can reach their collection. |
| Serialisation | **kotlinx.serialization** | Needed for the catalogue JSON and the sync bodies. |

---

## 4. What cannot port, and what replaces it

Every one of these is a rewrite, not a translation. They are also the parts
most likely to be underestimated, so they are listed early.

| iOS | Android | Notes |
|---|---|---|
| WidgetKit "What's open" | **Glance** | Same idea, different API. Glance also has no App Intents, so the pour button posts to a broadcast receiver. |
| Spotlight (`CSSearchableIndex`) | **AppSearch** | Comparable; indexes bottles for system search. |
| Siri + App Intents | **App Actions** (`shortcuts.xml`) + assistant integration | Less capable. The Ask grammar is engine code and ports fine; the assistant surface is thinner. |
| StoreKit 2 | **Play Billing 7** | Different entitlement model: Play has no `currentEntitlements` stream, so Pro state is fetched on connect and after each purchase. |
| Apple Vision OCR | **ML Kit Text Recognition** | On-device, free, no account. The `LabelReader` parsing rules are engine code and port unchanged — only the text extraction differs. |
| Keychain | **EncryptedSharedPreferences** (Android Keystore) | Holds the Supabase refresh token. |
| App Group container | not needed | The Glance widget runs in the app's own process and opens the same database file. This removes an entire class of problem the iOS side had to solve. |
| `ASWebAuthenticationSession` | **Custom Tabs** | Same PKCE flow, same redirect, same `liquorlog://auth-callback`. |
| Sign in with Apple (native) | **web flow** through Supabase | Android has no native Apple sheet; it goes through the browser. Google, conversely, gets *better* — Credential Manager gives a native sheet. |
| PDF via `UIGraphicsPDFRenderer` | **PdfDocument** | For the insurance report. |

---

## 5. Order of work

Bottom-up, because each layer is provable before the next one leans on it —
and because the engine is where the product actually lives.

1. **`engine`, module by module, with the golden vectors.** Start with the
   spine everything else imports: `Units`, `PourMath`, `Classification`,
   `FillLevel`, `BottleSearch`, `ShelfCheck`. ~8,900 lines, and the single
   largest block of work. Nothing visible happens during it, which is worth
   knowing in advance.
2. **`data`**: SQLDelight schema (checked against Postgres), the
   repositories, then sync and auth against the same Supabase project the
   iOS app already uses — no server work at all, because the schema, the
   policies and the functions are already live.
3. **`app`**: the four tabs, in the order the iOS app was built — Shelf
   check first, because it is the home tab and the reason to open the app.
4. **The surfaces**: Glance widget, AppSearch, Play Billing, ML Kit.

---

## 6. How it is proven

The same rule as the rest of this repository: **CI is the proof.** There is
no JDK on the Windows machine this is authored from, exactly as there is no
Swift toolchain, so nothing is "tested locally" and nothing is assumed.

- `Android engine (JVM)` runs `gradle test` on `ubuntu-latest` on every
  push. Free, and seconds rather than the ten-minute macOS job.
- No Gradle wrapper jar is committed. The CI action installs a pinned
  Gradle version instead, which keeps a binary nobody can read out of a
  repository whose whole argument is that its data is auditable.
- The golden vectors mean the Android engine's failures are the Swift
  engine's failures. Parity is a test result, not a promise.

---

## 7. What this does not settle

- **Whether the Android app ships at the same time as iOS.** It cannot;
  the engine port alone is substantial. The honest sequencing is iOS
  first, Android second.
- **Play Store compliance**, which has its own rules on alcohol apps and
  its own age-rating questionnaire. Neither has been read yet.
- **Tablet layout.** iOS has an iPad split view; Android's equivalent
  (window size classes) is a later decision, not an early one.
