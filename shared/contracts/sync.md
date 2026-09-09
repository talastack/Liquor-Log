# Sync contract

Supabase (Postgres + PostgREST + GoTrue). The app is **offline-first**: every
feature works with no account and no network, and sync is additive. Nothing in
the app may block on a request.

---

## The two clocks

Every synced table carries both, and they are not interchangeable.

| Column | Written by | Used for |
|---|---|---|
| `updated_at` | the **device**, at the moment of the edit | last-write-wins |
| `server_updated_at` | the **server**, on every insert and update | the pull cursor |

`dirty` is a third flag that exists **only on the client**. It is the push
queue. It is absent from the Postgres schema entirely and never crosses the
wire.

### Why they cannot be collapsed

**The pull must filter on `server_updated_at`.** A device that has been offline
for a week comes back with edits stamped last Tuesday. It pushes them, and the
server stamps them *now*. A second device pulling on `updated_at > cursor` would
never see them — its cursor is already past last Tuesday. The rows are lost
silently, with no error anywhere, and nobody finds out until somebody notices a
bottle missing months later.

**Conflicts must resolve on `updated_at`.** Resolving by arrival time means
whichever device happens to sync last wins, regardless of when the human
actually made the change. Edit a bottle on your phone on Monday, edit it on
your iPad on Tuesday, open the phone on Wednesday — the Monday edit would win
because it arrived last. `updated_at` is the device's own clock precisely so the
later *edit* wins, not the later *upload*.

The cost is that a device with a badly wrong clock can win conflicts it should
not. That is accepted: the failure is visible and rare, and the alternative
fails silently and constantly.

---

## Push

Dirty rows, oldest `updated_at` first, in **dependency order**:

```
custom_catalog_entries → bottles → pours → fill_readings → tastings → tasting_notes
wishlist_items          (independent)
knowledge_notes         (independent)
```

A pour references a bottle. Pushing pours first fails the foreign key, and the
error arrives as a 409 that says nothing useful about which table was wrong.

Upsert via PostgREST:

```
POST /rest/v1/<table>
Prefer: resolution=merge-duplicates,return=minimal
```

`dirty` is stripped from the body before sending. `server_updated_at` is never
sent — the trigger overwrites anything a client puts there.

**`dirty` is cleared only on a 2xx.** Clearing it optimistically loses the edit
if the request fails, and that edit is somebody's tasting note.

### Stale writes are rejected by the server, not the client

Two devices can push concurrently, so the client cannot be the arbiter. The
`reject_stale_writes` trigger drops any update whose `updated_at` is older than
the row already stored. The push still returns 2xx — from the pusher's point of
view the write was accepted and then superseded, which is exactly what
happened, and the next pull brings back the winning version.

---

## Pull

Per table, ordered and paged on the server clock:

```
GET /rest/v1/<table>?server_updated_at=gt.<cursor>&order=server_updated_at.asc&limit=500
```

Rows are written with `saveFromServer`, which does **not** set `dirty` and does
**not** restamp `updated_at`. Marking incoming rows dirty would make every pull
schedule a push, and two devices would ping-pong forever.

The cursor advances to the **highest `server_updated_at` actually received**,
and only after the batch is written. Advancing first loses the batch if the
write fails.

The cursor lives in `UserDefaults`, not the database, and losing it is safe: the
next pull starts from zero and re-applies everything. Re-applying is idempotent
because every write is an upsert keyed on a device-generated uuid.

**Tombstones arrive like any other row.** A deletion is an update setting
`deleted_at`, so it travels the same path. There is no delete endpoint and no
`DELETE` anywhere in the client.

---

## Accounts

`user_id` is NULL until somebody signs in. The app is fully usable before that,
and a local collection is not a degraded state.

On first sign-in every local row is stamped with the new `user_id` **in one
transaction**, then pushed. A partial stamp would leave rows RLS can never
return, invisible to their owner and impossible to repair from the client.

Row-level security scopes every table to `auth.uid() = user_id`, with `USING`
for reads and `WITH CHECK` for writes. Both are required: `USING` alone would
let somebody rewrite a row's `user_id` and hand it to another account.

---

## What is not synced

- **The bundled catalogue and flavour wheel.** Files in the app bundle, updated
  by shipping a build. They are the same for everyone and have no owner.
- **`dirty`.** Local only, by definition.
- **Display preferences** such as whether the collection total is shown. Those
  are per-device, live in `UserDefaults`, and a preference about what you would
  rather not look at is not something to put on a server.
