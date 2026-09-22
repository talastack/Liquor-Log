#!/usr/bin/env python3
"""Assert every App Store listing field is inside Apple's character limit.

`docs/10-app-store-listing.md` holds the text that goes into App Store
Connect. The form counts characters and refuses to save a field that is
one over -- at midnight, in a browser, with the rest of the listing
half-entered. Counting them here costs nothing and moves that discovery to
a place where it can be fixed calmly.

The limits are Apple's, and they are on the field as pasted:

    name                30
    subtitle            30
    promotional text   170
    description       4000
    keywords           100   (comma separated; the commas count)

Keywords have a second rule the form does not enforce and this does: a
space after a comma is a wasted character, because the field is parsed on
commas alone.

Each field is the fenced block under its heading, so the document stays
readable prose rather than a config file wearing a disguise.
"""

import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
LISTING = ROOT / "docs" / "10-app-store-listing.md"

# (heading prefix, limit, joined) -- `joined` collapses a wrapped block to
# one line first, which is what pasting it into a single-line field does.
FIELDS = [
    ("## App Name", 30, True),
    ("## Subtitle", 30, True),
    ("## Promotional text", 170, True),
    ("## Description", 4000, False),
    ("## Keywords", 100, True),
]

FENCE = re.compile(r"```\n(.*?)\n```", re.S)


def first_block(section):
    match = FENCE.search(section)
    return match.group(1) if match else None


def main():
    if not LISTING.exists():
        print(
            "listing FAILED\n\n  - missing %s"
            % LISTING.relative_to(ROOT).as_posix(),
            file=sys.stderr,
        )
        return 1

    text = LISTING.read_text(encoding="utf-8")
    problems = []
    counted = []

    for heading, limit, joined in FIELDS:
        start = text.find(heading)
        if start < 0:
            problems.append("no %r section" % heading)
            continue
        # Up to the next top-level heading, so a field cannot borrow the
        # next one's fenced block when its own is missing.
        end = text.find("\n## ", start + 1)
        section = text[start:end if end > 0 else len(text)]

        block = first_block(section)
        if block is None:
            problems.append("%s has no fenced block" % heading)
            continue

        value = " ".join(block.split()) if joined else block
        counted.append((heading[3:], len(value), limit))

        if len(value) > limit:
            problems.append(
                "%s is %d characters; the limit is %d (%d over)"
                % (heading[3:], len(value), limit, len(value) - limit)
            )

        if heading == "## Keywords":
            if ", " in value:
                problems.append(
                    "Keywords has a space after a comma. The field is split on"
                    " commas alone, so each space is a keyword character spent"
                    " on nothing."
                )
            if value != value.strip():
                problems.append("Keywords is padded with whitespace")

    if problems:
        print("listing FAILED\n", file=sys.stderr)
        for problem in problems:
            print("  - %s" % problem, file=sys.stderr)
        return 1

    print("listing ok:")
    for name, length, limit in counted:
        print("  %-18s %5d / %d" % (name, length, limit))
    return 0


if __name__ == "__main__":
    sys.exit(main())
