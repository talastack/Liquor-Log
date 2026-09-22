#!/usr/bin/env python3
"""Build the public pages GitHub Pages serves, from the Markdown sources.

Apple requires a reachable privacy policy URL for every app, and a link in
App Store Connect is not the same thing as a page: a reviewer opens it.

The Markdown in `docs/` stays the one source of truth. These pages are
generated from it so the two cannot drift -- edit the `.md`, re-run this,
commit both. `scripts/check_pages.py` asserts they are in step.

Deliberately no Jekyll and no dependencies: a `.nojekyll` file goes beside
the output so GitHub serves exactly these bytes, and the converter below is
the small subset of Markdown these two documents actually use. A page that
renders through someone else's pipeline is a page that can break on a day
nobody is watching.
"""

import html
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
DOCS = ROOT / "docs"

PAGES = [
    ("privacy-policy.md", "privacy.html", "Privacy policy"),
    ("terms.md", "terms.html", "Terms of use"),
]

STYLE = """
:root {
  color-scheme: light dark;
  --ground: #faf9f7;
  --ink: #1b1a18;
  --quiet: #5d5a54;
  --rule: #e0ddd6;
  --accent: #8a5a2b;
}
@media (prefers-color-scheme: dark) {
  :root {
    --ground: #14130f;
    --ink: #ecead9;
    --quiet: #a5a091;
    --rule: #2e2b24;
    --accent: #d9a05b;
  }
}
* { box-sizing: border-box; }
body {
  margin: 0;
  padding: 48px 20px 96px;
  background: var(--ground);
  color: var(--ink);
  font: 17px/1.65 ui-serif, Georgia, "Times New Roman", serif;
  -webkit-text-size-adjust: 100%;
}
main { max-width: 34rem; margin: 0 auto; }
h1 {
  font-size: 2rem;
  line-height: 1.2;
  margin: 0 0 4px;
  letter-spacing: -0.01em;
}
.meta {
  color: var(--quiet);
  font-size: 0.95rem;
  font-style: italic;
  margin: 0 0 32px;
  padding-bottom: 24px;
  border-bottom: 1px solid var(--rule);
}
h2 {
  font-size: 1.15rem;
  margin: 40px 0 12px;
  letter-spacing: 0.01em;
}
p, li { margin: 0 0 14px; }
ul { padding-left: 1.2rem; }
strong { font-weight: 600; }
a { color: var(--accent); }
.back {
  display: inline-block;
  margin-top: 48px;
  padding-top: 24px;
  border-top: 1px solid var(--rule);
  width: 100%;
  font-size: 0.95rem;
  font-family: ui-sans-serif, system-ui, sans-serif;
}
"""


def inline(text):
    """Escape, then put back the three inline forms these documents use."""
    out = html.escape(text, quote=False)
    out = re.sub(r"\*\*(.+?)\*\*", r"<strong>\1</strong>", out)
    out = re.sub(r"\[(.+?)\]\((.+?)\)", r'<a href="\2">\1</a>', out)
    out = re.sub(r"(?<!\*)\*(?!\*)(.+?)(?<!\*)\*(?!\*)", r"<em>\1</em>", out)
    return out


def render(markdown):
    """The subset these two documents use: h1, h2, paragraphs, bullets."""
    title = ""
    meta = ""
    body = []
    bullets = []

    def flush():
        if bullets:
            body.append("<ul>" + "".join("<li>%s</li>" % b for b in bullets) + "</ul>")
            bullets.clear()

    for raw in markdown.splitlines():
        line = raw.rstrip()
        if not line:
            flush()
            continue
        if line.startswith("# "):
            title = line[2:].strip()
        elif line.startswith("## "):
            flush()
            body.append("<h2>%s</h2>" % inline(line[3:].strip()))
        elif line.startswith("- "):
            bullets.append(inline(line[2:].strip()))
        elif line.startswith("*") and line.endswith("*") and not meta and not body:
            meta = inline(line.strip("*").strip())
        else:
            flush()
            body.append("<p>%s</p>" % inline(line))
    flush()
    return title, meta, "\n".join(body)


def page(title, meta, body, other_name, other_href):
    return """<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>%s &middot; Pour Memo</title>
<meta name="description" content="%s for Pour Memo, by TALASTACK LLC.">
<style>%s</style>
</head>
<body>
<main>
<h1>%s</h1>
<p class="meta">%s</p>
%s
<a class="back" href="%s">%s</a>
</main>
</body>
</html>
""" % (
        html.escape(title), html.escape(title), STYLE,
        html.escape(title), meta, body, other_href, html.escape(other_name),
    )


def main():
    written = []
    for source, target, label in PAGES:
        path = DOCS / source
        if not path.exists():
            print("missing %s" % path, file=sys.stderr)
            return 1
        title, meta, body = render(path.read_text(encoding="utf-8"))
        other = [p for p in PAGES if p[1] != target][0]
        (DOCS / target).write_text(
            page(title or label, meta, body, other[2], other[1]),
            encoding="utf-8",
        )
        written.append(target)

    # Served verbatim: no Jekyll, so nothing between these bytes and a
    # reviewer opening the link.
    (DOCS / ".nojekyll").write_text("", encoding="utf-8")

    (DOCS / "index.html").write_text(
        page(
            "Pour Memo",
            "A bourbon and spirits collection, by TALASTACK LLC.",
            "<p>The legal documents for the app.</p>"
            '<ul><li><a href="privacy.html">Privacy policy</a></li>'
            '<li><a href="terms.html">Terms of use</a></li></ul>',
            "Privacy policy",
            "privacy.html",
        ),
        encoding="utf-8",
    )
    written.append("index.html")

    print("built %s in docs/" % ", ".join(written))
    return 0


if __name__ == "__main__":
    sys.exit(main())
