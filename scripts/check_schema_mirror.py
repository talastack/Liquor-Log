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
SQLDELIGHT = (ROOT / "Android" / "data" / "src" / "main" / "sqldelight"
              / "com" / "talastack" / "liquorlog" / "data" / "Schema.sq")

# The two account linkers. Each stamps `user_id` onto every row the client
# writes at sign-in, and each keeps its own hard-coded list of which tables
# those are. A table on one list and not the other is a table whose rows are
# never adopted on that platform -- and an unstamped row can never be pushed
# and could never be read back if it were.
SWIFT_LINKER = (ROOT / "IOS" / "Packages" / "LiquorData" / "Sources" / "LiquorData"
                / "Sync" / "AccountLinker.swift")
KOTLIN_LINKER = (ROOT / "Android" / "data" / "src" / "main" / "kotlin" / "com"
                 / "talastack" / "liquorlog" / "data" / "AccountLinker.kt")

# Server-owned: its rows arrive by pull already carrying their owner, so no
# client ever stamps them.
NEVER_ADOPTED = {"subscriptions"}

LOCAL_ONLY = {"dirty"}
SERVER_ONLY = {"server_updated_at"}

# Tables Supabase owns, or that we stub only so the file applies standalone,
# and the household tables, which live on the server only: membership is
# asked for over the network, never synced.
IGNORED_TABLES = {"auth.users", "users", "households", "household_members"}

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
        # Depth tracks unclosed parentheses so a CONSTRAINT that wraps across
        # lines is skipped whole. Without it the continuation of
        #
        #     check (a is null or b is null
        #            or a <= b)
        #
        # reads as a column called "or", and the mirror fails on a table that is
        # perfectly correct.
        depth = 0
        for raw in body.splitlines():
            line = raw.strip()
            if not line or line.startswith("--"):
                continue

            if depth == 0:
                token = line.split()[0].strip(",").lower()
                if token not in NOT_A_COLUMN and re.fullmatch(r"[a-z_][a-z0-9_]*", token):
                    columns.add(token)

            depth = max(0, depth + line.count("(") - line.count(")"))
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


def sqldelight_tables(text):
    """{table: {column, ...}} from the Android schema's `CREATE TABLE` blocks.

    The same schema a third time, for the Android client. A local schema that
    has drifted from Postgres fails the same way on either platform -- the
    column syncs into a void -- so it is held to the same comparison rather
    than to a looser one.
    """
    tables = {}
    pattern = re.compile(
        r"create\s+table\s+(?:if\s+not\s+exists\s+)?([a-z_]+)\s*\((.*?)\)\s*;",
        re.IGNORECASE | re.DOTALL,
    )
    for name, body in pattern.findall(text):
        columns = set()
        depth = 0
        for raw in body.splitlines():
            line = raw.strip()
            if not line or line.startswith("--"):
                continue
            if depth == 0:
                token = line.split()[0].strip(",").lower()
                if token not in NOT_A_COLUMN and re.fullmatch(r"[a-z_][a-z0-9_]*", token):
                    columns.add(token)
            depth = max(0, depth + line.count("(") - line.count(")"))
        if columns:
            tables[name.lower()] = columns
    return tables


def compare(pg, local, label, problems):
    """Every way a local schema can disagree with the server's."""
    for t in sorted(set(pg) - set(local)):
        problems.append("[%s] table %s is in Postgres but not in the local schema"
                        % (label, t))
    for t in sorted(set(local) - set(pg)):
        problems.append("[%s] table %s is in the local schema but not in Postgres"
                        % (label, t))

    for table in sorted(set(pg) & set(local)):
        pg_cols, local_cols = pg[table], local[table]

        for c in sorted(pg_cols - local_cols - SERVER_ONLY):
            problems.append(
                "[%s] %s.%s exists in Postgres but not locally -- rows pulled from "
                "the server will drop this column" % (label, table, c))
        for c in sorted(local_cols - pg_cols - LOCAL_ONLY):
            problems.append(
                "[%s] %s.%s exists locally but not in Postgres -- this column syncs "
                "into a void" % (label, table, c))

        # The two allowed differences must actually be present on both sides,
        # or sync is broken in a way this check would otherwise excuse.
        for c in LOCAL_ONLY:
            if c not in local_cols:
                problems.append("[%s] %s is missing the local-only column %s"
                                % (label, table, c))
        for c in SERVER_ONLY:
            if c in local_cols:
                problems.append(
                    "[%s] %s.%s must NOT exist locally: the pull cursor comes from "
                    "the server's response, not a device's copy of its clock"
                    % (label, table, c))


def linker_tables(path, anchor):
    """The table list an AccountLinker stamps, read from either language.

    Both declare it the same way -- an identifier, then a bracketed list of
    quoted lowercase names -- so one reader does for both. Returns an empty
    set when the file or the anchor is absent, which the caller reports.
    """
    if not path.exists():
        return set()
    text = path.read_text(encoding="utf-8")
    at = text.find(anchor)
    if at < 0:
        return set()
    # Long enough for the list and nothing after it.
    window = text[at:at + 900]
    return set(re.findall(r'"([a-z][a-z0-9_]*)"', window))


def check_linkers(pg, problems):
    """Both linkers must stamp exactly the tables the schema says they own."""
    expected = {t for t, cols in pg.items() if "user_id" in cols} - NEVER_ADOPTED
    for path, anchor, label in (
        (SWIFT_LINKER, "private var tables", "swift"),
        (KOTLIN_LINKER, "val TABLES", "kotlin"),
    ):
        found = linker_tables(path, anchor)
        if not found:
            problems.append(
                "[%s] could not read the account linker's table list from %s"
                % (label, path.name))
            continue
        for t in sorted(expected - found):
            problems.append(
                "[%s] the account linker never stamps %s -- rows in it can never "
                "be pushed and could never be read back" % (label, t))
        for t in sorted(found - expected):
            problems.append(
                "[%s] the account linker stamps %s, which is not a table the "
                "client owns" % (label, t))


def main():
    for path in (POSTGRES, SWIFT, SQLDELIGHT):
        if not path.exists():
            print("missing: %s" % path, file=sys.stderr)
            return 1

    pg = postgres_tables(POSTGRES.read_text(encoding="utf-8"))
    sw = swift_tables(SWIFT.read_text(encoding="utf-8"))
    sq = sqldelight_tables(SQLDELIGHT.read_text(encoding="utf-8"))

    problems = []

    # What Postgres owes both clients, checked once rather than per client.
    for table in sorted(pg):
        for c in LOCAL_ONLY:
            if c in pg[table]:
                problems.append(
                    "%s.%s must NOT exist in Postgres: it is a local push queue"
                    % (table, c))
        for c in SERVER_ONLY:
            if c not in pg[table]:
                problems.append("%s is missing the server-only column %s" % (table, c))

    compare(pg, sw, "swift", problems)
    compare(pg, sq, "sqldelight", problems)
    check_linkers(pg, problems)

    if problems:
        print("schema mirror FAILED\n", file=sys.stderr)
        for p in problems:
            print("  - %s" % p, file=sys.stderr)
        print("\n%d problem(s). %s, %s and %s are one paired edit."
              % (len(problems), POSTGRES.name, SWIFT.name, SQLDELIGHT.name),
              file=sys.stderr)
        return 1

    total = sum(len(v) for v in pg.values())
    print("schema mirror ok: %d tables, %d columns, 3 copies agree"
          % (len(pg), total))
    return 0


if __name__ == "__main__":
    sys.exit(main())
