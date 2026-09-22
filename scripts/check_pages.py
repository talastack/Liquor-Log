#!/usr/bin/env python3
"""Assert the published pages match the Markdown they are built from.

`docs/privacy.html` and `docs/terms.html` are what Apple's reviewer and the
app's users actually open; `docs/privacy-policy.md` and `docs/terms.md` are
what anybody editing will edit. Two files meant to say the same thing drift,
and the one that drifts here is the one nobody looks at until it is quoted
back at them.

So this rebuilds the pages in memory and compares. It does not write: a
check that silently fixes what it is checking is a check that never fails.

    python scripts/build_pages.py     # after editing either .md
"""

import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(ROOT / "scripts"))

import build_pages  # noqa: E402  (path set above)

DOCS = ROOT / "docs"


def main():
    problems = []

    for source, target, label in build_pages.PAGES:
        md = DOCS / source
        page = DOCS / target
        if not md.exists():
            problems.append("missing source docs/%s" % source)
            continue
        if not page.exists():
            problems.append(
                "missing docs/%s -- run python scripts/build_pages.py" % target
            )
            continue
        title, meta, body = build_pages.render(md.read_text(encoding="utf-8"))
        other = [p for p in build_pages.PAGES if p[1] != target][0]
        expected = build_pages.page(title or label, meta, body, other[2], other[1])
        if page.read_text(encoding="utf-8") != expected:
            problems.append(
                "docs/%s is out of step with docs/%s"
                " -- run python scripts/build_pages.py" % (target, source)
            )

    if not (DOCS / ".nojekyll").exists():
        problems.append(
            "docs/.nojekyll is missing; GitHub would put Jekyll between the"
            " reviewer and these bytes"
        )

    if problems:
        print("pages FAILED\n", file=sys.stderr)
        for problem in problems:
            print("  - %s" % problem, file=sys.stderr)
        return 1

    print("pages ok: %d built from Markdown, in step" % len(build_pages.PAGES))
    return 0


if __name__ == "__main__":
    sys.exit(main())
