#!/usr/bin/env python3
"""Prove, against the live project, that a signed-in account's data is saved.

CI applies the schema to a bare Postgres with no auth and no RLS, so the one
thing it can never answer is the one that matters most: when a real person
signs in and syncs, do their rows land, come back, stay theirs, and survive
an edit? This asks the server directly, over the same REST calls the app
makes -- same headers, same Prefer, same cursor -- so a pass here is a pass
for `SyncEngine`.

Nothing here uses a service-role key. It signs in as two ordinary users and
is bound by exactly the policies the app is bound by.

    python scripts/verify_sync.py \\
        --host abcdefghijklm.supabase.co \\
        --key  sb_publishable_... \\
        --a a@example.com:password --b b@example.com:password

Make the two users in the dashboard (Authentication -> Users -> Add user,
with Auto Confirm ticked). They can be deleted afterwards; the script
removes every row it wrote either way.
"""
import argparse
import json
import sys
import time
import urllib.error
import urllib.request

PASSED, FAILED = [], []


def check(name, ok, detail=""):
    (PASSED if ok else FAILED).append(name)
    print("  %s %s%s" % ("PASS" if ok else "FAIL", name, (" -- " + detail) if detail else ""))
    return ok


def call(method, url, key, token=None, body=None, prefer=None):
    """Returns (status, parsed-or-text). Never raises on an HTTP error: the
    status is frequently the thing being asserted."""
    request = urllib.request.Request(url, method=method)
    request.add_header("apikey", key)
    request.add_header("Authorization", "Bearer " + (token or key))
    if body is not None:
        request.add_header("Content-Type", "application/json")
        request.data = json.dumps(body).encode()
    if prefer:
        request.add_header("Prefer", prefer)
    try:
        with urllib.request.urlopen(request) as response:
            raw = response.read().decode()
            status = response.status
    except urllib.error.HTTPError as error:
        raw, status = error.read().decode(), error.code
    try:
        return status, json.loads(raw) if raw else None
    except json.JSONDecodeError:
        return status, raw


def sign_in(host, key, email, password):
    status, body = call(
        "POST", "https://%s/auth/v1/token?grant_type=password" % host, key,
        body={"email": email, "password": password})
    if status != 200 or not isinstance(body, dict) or "access_token" not in body:
        print("could not sign in as %s: %s %s" % (email, status, body), file=sys.stderr)
        sys.exit(1)
    return body["access_token"], body["user"]["id"]


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--host", required=True, help="abcdefghijklm.supabase.co")
    parser.add_argument("--key", required=True, help="the publishable (anon) key")
    parser.add_argument("--a", required=True, help="email:password of the first user")
    parser.add_argument("--b", required=True, help="email:password of the second user")
    args = parser.parse_args()

    host, key = args.host, args.key
    a_token, a_id = sign_in(host, key, *args.a.split(":", 1))
    b_token, b_id = sign_in(host, key, *args.b.split(":", 1))
    print("signed in: A=%s  B=%s\n" % (a_id, b_id))

    rest = "https://%s/rest/v1/" % host
    now = int(time.time() * 1000)
    bottle_id, pour_id = "verify-bottle-1", "verify-pour-1"

    def cleanup():
        for table, row in (("pours", pour_id), ("bottles", bottle_id)):
            call("DELETE", rest + table + "?id=eq." + row, key, a_token)

    cleanup()
    try:
        # ------------------------------------------------------------ push
        print("A pushes, exactly as SyncEngine does")
        status, body = call(
            "POST", rest + "bottles", key, a_token,
            body=[{
                "id": bottle_id, "user_id": a_id, "category": "spirit",
                "custom_name": "Verify Stagg", "volume_ml": 750, "pour_size_ml": 44.36,
                "created_at": now, "updated_at": now,
            }],
            prefer="resolution=merge-duplicates,return=minimal")
        check("a bottle is accepted", status in (200, 201, 204), "%s %s" % (status, body))

        # A pour, to prove the dependency order the engine relies on.
        status, body = call(
            "POST", rest + "pours", key, a_token,
            body=[{
                "id": pour_id, "user_id": a_id, "bottle_id": bottle_id,
                "poured_at": now, "volume_ml": 44.36,
                "created_at": now, "updated_at": now,
            }],
            prefer="resolution=merge-duplicates,return=minimal")
        check("a pour referencing it is accepted", status in (200, 201, 204), "%s %s" % (status, body))

        # ------------------------------------------------------------ pull
        print("\nA pulls it back")
        status, rows = call(
            "GET", rest + "bottles?select=*&server_updated_at=gt.0"
            "&order=server_updated_at.asc&limit=50", key, a_token)
        mine = [r for r in (rows or []) if r.get("id") == bottle_id]
        check("the row comes back on a pull", len(mine) == 1, "%s rows" % len(mine))
        if mine:
            row = mine[0]
            check("it kept what was written", row.get("custom_name") == "Verify Stagg")
            check("it is owned by A", row.get("user_id") == a_id)
            check("the server stamped its own clock",
                  isinstance(row.get("server_updated_at"), int) and row["server_updated_at"] > 0,
                  str(row.get("server_updated_at")))
            check("no local-only column leaked to the server", "dirty" not in row)
            first_clock = row.get("server_updated_at", 0)
        else:
            first_clock = 0

        # ------------------------------------------------------- the cursor
        print("\nThe cursor moves past what was already pulled")
        status, rows = call(
            "GET", rest + "bottles?select=id&server_updated_at=gt.%d"
            "&order=server_updated_at.asc&limit=50" % first_clock, key, a_token)
        check("a cursor at the newest row returns nothing new",
              not any(r.get("id") == bottle_id for r in (rows or [])))

        # ---------------------------------------------------------- an edit
        print("\nAn edit re-pushes and wins")
        status, body = call(
            "POST", rest + "bottles", key, a_token,
            body=[{
                "id": bottle_id, "user_id": a_id, "category": "spirit",
                "custom_name": "Verify Stagg, renamed", "volume_ml": 750,
                "pour_size_ml": 44.36, "created_at": now, "updated_at": now + 1000,
            }],
            prefer="resolution=merge-duplicates,return=minimal")
        check("an upsert of the same id is not a conflict", status in (200, 201, 204),
              "%s %s" % (status, body))
        status, rows = call("GET", rest + "bottles?select=*&id=eq." + bottle_id, key, a_token)
        edited = (rows or [{}])[0]
        check("the edit is what the server now holds",
              edited.get("custom_name") == "Verify Stagg, renamed")
        check("the server clock moved with it",
              edited.get("server_updated_at", 0) > first_clock)

        # --------------------------------------------------- a stale write
        print("\nA stale write is refused (the reject_stale_writes trigger)")
        status, body = call(
            "POST", rest + "bottles", key, a_token,
            body=[{
                "id": bottle_id, "user_id": a_id, "category": "spirit",
                "custom_name": "Stale, from an older device", "volume_ml": 750,
                "pour_size_ml": 44.36, "created_at": now, "updated_at": now - 99_000,
            }],
            prefer="resolution=merge-duplicates,return=minimal")
        status, rows = call("GET", rest + "bottles?select=custom_name&id=eq." + bottle_id,
                            key, a_token)
        kept = (rows or [{}])[0].get("custom_name")
        check("the older edit did not overwrite the newer one",
              kept == "Verify Stagg, renamed", "server holds %r" % kept)

        # ------------------------------------------------------- isolation
        print("\nB is a different account")
        status, rows = call("GET", rest + "bottles?select=id", key, b_token)
        check("B's pull does not contain A's row",
              not any(r.get("id") == bottle_id for r in (rows or [])),
              "%s rows" % len(rows or []))
        status, body = call(
            "POST", rest + "bottles", key, b_token,
            body=[{
                "id": "verify-forged", "user_id": a_id, "category": "spirit",
                "custom_name": "Forged", "volume_ml": 750, "pour_size_ml": 44.36,
                "created_at": now, "updated_at": now,
            }],
            prefer="resolution=merge-duplicates,return=minimal")
        check("B cannot write a row in A's name", status == 403,
              "%s %s" % (status, (body or {}).get("code") if isinstance(body, dict) else body))
        status, body = call(
            "PATCH", rest + "bottles?id=eq." + bottle_id, key, b_token,
            body={"custom_name": "Tampered"}, prefer="return=representation")
        check("B cannot edit A's row", body in ([], None), str(body))

        # ------------------------------------------------- the soft delete
        print("\nRemoving a bottle is a tombstone, not a hole")
        status, body = call(
            "POST", rest + "bottles", key, a_token,
            body=[{
                "id": bottle_id, "user_id": a_id, "category": "spirit",
                "custom_name": "Verify Stagg, renamed", "volume_ml": 750,
                "pour_size_ml": 44.36, "created_at": now,
                "updated_at": now + 2000, "deleted_at": now + 2000,
            }],
            prefer="resolution=merge-duplicates,return=minimal")
        status, rows = call("GET", rest + "bottles?select=deleted_at&id=eq." + bottle_id,
                            key, a_token)
        check("the tombstone is stored and still pullable",
              bool((rows or [{}])[0].get("deleted_at")),
              "a second device needs to see the delete")
    finally:
        cleanup()
        call("DELETE", rest + "bottles?id=eq.verify-forged", key, a_token)

    print("\n%d passed, %d failed" % (len(PASSED), len(FAILED)))
    if FAILED:
        print("failed: " + ", ".join(FAILED))
    return 1 if FAILED else 0


if __name__ == "__main__":
    sys.exit(main())
