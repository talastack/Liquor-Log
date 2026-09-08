#!/usr/bin/env python3
"""Assert the local GRDB schema and the Postgres schema are the same schema.

They are a PAIRED EDIT and nothing at runtime notices when they drift. A column
present in one and absent from the other syncs into a void with no error: the
client writes it forever, the server never stores it, and nobody sees a failure.
This is the single highest-value check in the repo, which is why it runs on the
free Linux job before a Mac runner has been paid for.

Two differences are expected and are the only ones allowed:

  dirty              local only  -- a push queue, not state. Never crosses the
                                    wire and does not exist server-side.
  server_updated_at  server only -- written by the server on every write. The
                                    pull cursor comes from the response, not
                                    from a client's copy of the server clock.

Exit 0 when they agree, 1 with a report when they do not.
"""

import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
POSTGRES = ROOT / "shared" / "schema" / "postgres" / "0001_init.sql"
SWIFT = (ROOT / "IOS" / "Packages" / "LiquorData" / "Sources" / "LiquorData"
         / "Schema" / "Migrations.swift")

LOCAL_ONLY = {"dirty"}
SERVER_ONLY = {"server_updated_at"}

# Tables Supabase owns, or that we stub only so the file applies standalone.
IGNORED_TABLES = {"auth.users", "users"}

# Line starts that are table constraints rather than columns.
NOT_A_COLUMN = {
    "constraint", "primary", "unique", "check", "foreign", "exclude", "like",
}


def postgres_tables(text):
    """{table: {column, ...}} from `create table ... ( ... );` blocks."""
    tables = {}
    pattern = re.compile(
        # Stops at the paren that CLOSES the table, not at the first newline
        # followed by ");". The auth.users stub is a single-line create table,
        # and a pattern anchored on a newline runs straight past it, swallowing
        # the next real table into a block that is then skipped as ignored.
        r"create\s+table\s+(?:if\s+not\s+exists\s+)?([a-z_.]+)\s*\((.*?)\)\s*;",
        re.IGNORECASE | re.DOTALL,
    )
    for name, body in pattern.findall(text):
        if name.lower() in IGNORED_TABLES:
            continue
        columns = set()
        for raw in body.splitlines():
            line = raw.strip()
            if not line or line.startswith("--"):
                continue
            token = line.split()[0].strip(",").lower()
            if token in NOT_A_COLUMN:
                continue
            if re.fullmatch(r"[a-z_][a-z0-9_]*", token):
                columns.add(token)
        if columns:
            tables[name.lower()] = columns
    return tables


def swift_tables(text):
    """{table: {column, ...}} from `db.create(table:)` blocks."""
    tables = {}
    blocks = re.split(r'try\s+db\.create\(table:\s*"', text)[1:]
    for block in blocks:
        name, _, rest = block.partition('"')
        # Stop at the next create(table:) or create(index:).
        rest = re.split(r"try\s+db\.create\(", rest)[0]
        columns = set(re.findall(r't\.column\(\s*"([a-z_][a-z0-9_]*)"', rest))
        columns |= set(re.findall(r't\.primaryKey\(\s*"([a-z_][a-z0-9_]*)"', rest))
        if columns:
            tables[name.lower()] = columns
    return tables


def main():
    for path in (POSTGRES, SWIFT):
        if not path.exists():
            print("missing: %s" % path, file=sys.stderr)
            return 1

    pg = postgres_tables(POSTGRES.read_text(encoding="utf-8"))
    sw = swift_tables(SWIFT.read_text(encoding="utf-8"))

    problems = []

    only_pg = sorted(set(pg) - set(sw))
    only_sw = sorted(set(sw) - set(pg))
    for t in only_pg:
        problems.append("table %s is in Postgres but not in the local schema" % t)
    for t in only_sw:
        problems.append("table %s is in the local schema but not in Postgres" % t)

    for table in sorted(set(pg) & set(sw)):
        pg_cols, sw_cols = pg[table], sw[table]

        missing_locally = pg_cols - sw_cols - SERVER_ONLY
        missing_on_server = sw_cols - pg_cols - LOCAL_ONLY

        for c in sorted(missing_locally):
            problems.append(
                "%s.%s exists in Postgres but not locally -- rows pulled from the "
                "server will drop this column" % (table, c))
        for c in sorted(missing_on_server):
            problems.append(
                "%s.%s exists locally but not in Postgres -- this column syncs "
                "into a void" % (table, c))

        # The two allowed differences must actually be present on both sides,
        # or sync is broken in a way this check would otherwise excuse.
        for c in LOCAL_ONLY:
            if c not in sw_cols:
                problems.append("%s is missing the local-only column %s" % (table, c))
            if c in pg_cols:
                problems.append(
                    "%s.%s must NOT exist in Postgres: it is a local push queue"
                    % (table, c))
        for c in SERVER_ONLY:
            if c not in pg_cols:
                problems.append("%s is missing the server-only column %s" % (table, c))
            if c in sw_cols:
                problems.append(
                    "%s.%s must NOT exist locally: the pull cursor comes from the "
                    "server's response, not a device's copy of its clock"
                    % (table, c))

    if problems:
        print("schema mirror FAILED\n", file=sys.stderr)
        for p in problems:
            print("  - %s" % p, file=sys.stderr)
        print("\n%d problem(s). %s and %s are a paired edit."
              % (len(problems), POSTGRES.name, SWIFT.name), file=sys.stderr)
        return 1

    total = sum(len(v) for v in pg.values())
    print("schema mirror ok: %d tables, %d columns" % (len(pg), total))
    return 0


if __name__ == "__main__":
    sys.exit(main())
