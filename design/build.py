# Design system + component helpers for every Liquor-Log artboard.
#
# One theme definition drives all thirteen screens in two modes, so a token
# change is one edit rather than thirteen. Run `python screens.py` to
# regenerate the .dc.html files, then re-seed the canvas.
#
# Type: Newsreader for bottle and screen names (character), Public Sans for
# everything else (readability), Spline Sans Mono for batch codes, proof and
# volumes. Nothing is below 12px.

import io
import os

HERE = os.path.dirname(os.path.abspath(__file__))

FONTS = ("https://fonts.googleapis.com/css2?"
         "family=Newsreader:opsz,wght@6..72,400;6..72,500;6..72,600"
         "&family=Public+Sans:wght@400;500;600;700"
         "&family=Spline+Sans+Mono:wght@400;500&display=swap")

# Warm brown-black with gold, rather than amber on cool slate.
DARK = {
    "bg": "#15100a", "surface": "#1e1710", "surface2": "#2a2016", "line": "#3a2d1e",
    "text": "#f2e9db", "dim": "#c0b19a", "faint": "#968771",
    "gold": "#c9973a", "goldSoft": "#e2b661", "onGold": "#1a1309",
    "shelf": "#c9973a", "line_v": "#a5763c", "bar_v": "#9d84b8", "had": "#7f96ab",
    "never": "#b5705a", "good": "#7faa72", "bad": "#c07862",
    "glass": "#5a4326", "liquid": "#8a5a24",
}

LIGHT = {
    "bg": "#f6f1e7", "surface": "#fffdf7", "surface2": "#ece4d4", "line": "#dcd0ba",
    "text": "#1b1510", "dim": "#4a4036", "faint": "#6b5f50",
    "gold": "#8a5f18", "goldSoft": "#a87c2c", "onGold": "#fffdf7",
    "shelf": "#8a5f18", "line_v": "#8a5f18", "bar_v": "#4e4176", "had": "#3a5670",
    "never": "#94402a", "good": "#356038", "bad": "#94402a",
    "glass": "#c9b48c", "liquid": "#c08a3a",
}

CSS = """
    :root{
      --bg:%(bg)s; --surface:%(surface)s; --surface2:%(surface2)s; --line:%(line)s;
      --text:%(text)s; --dim:%(dim)s; --faint:%(faint)s;
      --gold:%(gold)s; --gold-soft:%(goldSoft)s; --on-gold:%(onGold)s;
      --v-shelf:%(shelf)s; --v-line:%(line_v)s; --v-bar:%(bar_v)s; --v-had:%(had)s;
      --v-never:%(never)s; --good:%(good)s; --bad:%(bad)s;
    }
    *{box-sizing:border-box}
    body{margin:0;background:var(--bg);color:var(--text);
      font:400 16px/1.5 "Public Sans","Helvetica Neue",Arial,sans-serif;
      -webkit-font-smoothing:antialiased}
    a{color:var(--gold)} a:hover{opacity:.82}
    .sc{width:390px;min-height:844px;background:var(--bg);display:flex;flex-direction:column}
    .serif{font-family:Newsreader,Georgia,"Times New Roman",serif;font-weight:500}
    .mono{font-family:"Spline Sans Mono",ui-monospace,Menlo,monospace}
    .dim{color:var(--dim)} .faint{color:var(--faint)} .gold{color:var(--gold)}
    /* Nothing below 12px anywhere on any screen. */
    .lab{font-size:12px;letter-spacing:.09em;text-transform:uppercase;font-weight:700;color:var(--dim)}
    .h1{font-family:Newsreader,Georgia,serif;font-size:32px;line-height:1.06;font-weight:600;margin:0}
    .name{font-family:Newsreader,Georgia,serif;font-size:23px;line-height:1.15;font-weight:500;margin:0}
    .meta{font-family:"Spline Sans Mono",Menlo,monospace;font-size:13px;color:var(--faint)}
    .body{font-size:15px;line-height:1.55;color:var(--dim);text-wrap:pretty}

    /* Status strip is presentation only -- the real app never draws one,
       because iOS paints the real thing on top. */
    .status{display:flex;justify-content:space-between;align-items:center;
      padding:14px 20px 0;font-size:13px;font-weight:600;color:var(--text)}
    .nav{display:flex;align-items:center;justify-content:space-between;gap:12px;padding:10px 18px 4px}
    .navbtn{min-width:44px;min-height:44px;display:flex;align-items:center;justify-content:center;
      color:var(--dim)}

    .field{display:flex;align-items:center;gap:11px;min-height:50px;padding:0 15px;font-size:16px;
      background:var(--surface);border:1px solid var(--line);border-radius:11px}

    .badge{display:inline-flex;align-items:center;gap:6px;min-height:26px;padding:4px 11px;
      border-radius:6px;font-size:12px;font-weight:700;letter-spacing:.05em;text-transform:uppercase;
      line-height:1.2}
    .b-shelf{background:var(--v-shelf);color:var(--on-gold)}
    .b-line{background:var(--v-line);color:var(--on-gold)}
    .b-bar{background:transparent;color:var(--v-bar);border:1px solid var(--v-bar)}
    .b-had{background:transparent;color:var(--v-had);border:1px solid var(--v-had)}
    .b-never{background:transparent;color:var(--v-never);border:1px solid var(--v-never)}
    .b-wish{background:transparent;color:var(--gold);border:1px solid var(--gold)}
    .b-open{background:transparent;color:var(--gold);border:1px solid var(--gold);
      font-size:12px;padding:2px 9px;min-height:22px}

    .card{background:var(--surface);border:1px solid var(--line);border-radius:12px;
      padding:14px;margin-bottom:11px;display:flex;gap:13px}
    .plain{background:var(--surface);border:1px solid var(--line);border-radius:12px;padding:15px}
    .thumb{flex:none;width:46px;display:flex;align-items:flex-start;justify-content:center;padding-top:2px}

    .fill{height:9px;background:var(--surface2);border-radius:5px;flex:1;overflow:hidden}
    .fill > i{display:block;height:100%%;border-radius:5px;
      background:linear-gradient(90deg,var(--gold),var(--gold-soft))}

    .rate{display:inline-flex;align-items:center;gap:5px;min-height:28px;padding:3px 10px;
      border-radius:7px;border:1px solid var(--line);background:var(--surface2);
      font-size:14px;font-weight:600;color:var(--gold);white-space:nowrap}

    .fact{display:flex;justify-content:space-between;gap:16px;padding:12px 0;
      border-bottom:1px solid var(--line)}
    .fact > span:first-child{color:var(--dim);font-size:15px;flex:none}
    .fact > span:last-child{text-align:right;font-size:15px;text-wrap:pretty}
    .fact.last{border-bottom:none}

    .btn{display:flex;align-items:center;justify-content:center;gap:8px;min-height:50px;
      border-radius:11px;background:var(--gold);color:var(--on-gold);font-weight:700;font-size:16px;flex:1}
    .btn2{display:flex;align-items:center;justify-content:center;gap:8px;min-height:50px;
      border-radius:11px;border:1px solid var(--line);color:var(--text);font-weight:600;
      font-size:16px;flex:1;background:transparent}

    .chip{display:inline-flex;align-items:center;gap:6px;min-height:44px;padding:9px 14px;
      border-radius:9px;font-size:15px;background:var(--surface2);color:var(--dim)}
    .chip.on{background:var(--gold);color:var(--on-gold);font-weight:700}
    .chip.ghost{background:transparent;border:1px solid var(--line)}
    .chips{display:flex;flex-wrap:wrap;gap:8px}

    .tabs{margin-top:auto;display:flex;align-items:flex-end;border-top:1px solid var(--line);
      background:var(--surface);padding:9px 0 30px}
    .tab{flex:1;min-height:46px;display:flex;flex-direction:column;align-items:center;
      justify-content:center;gap:4px;font-size:12px;font-weight:600;color:var(--faint)}
    .tab.on{color:var(--gold)}
    .tabadd{flex:1;display:flex;flex-direction:column;align-items:center;gap:4px;
      font-size:12px;font-weight:600;color:var(--faint)}
    .tabadd > div{width:44px;height:44px;border-radius:22px;background:var(--gold);
      color:var(--on-gold);display:flex;align-items:center;justify-content:center}
"""

ICON = {
    "search": '<svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.9" stroke-linecap="round"><circle cx="11" cy="11" r="7"></circle><path d="M20 20l-3.6-3.6"></path></svg>',
    "back": '<svg width="22" height="22" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.9" stroke-linecap="round" stroke-linejoin="round"><path d="M15 5l-7 7 7 7"></path></svg>',
    "close": '<svg width="22" height="22" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.9" stroke-linecap="round"><path d="M6 6l12 12M18 6L6 18"></path></svg>',
    "share": '<svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round"><path d="M12 15V4M8.5 7.5L12 4l3.5 3.5"></path><path d="M6 12v7h12v-7"></path></svg>',
    "bottle": '<svg width="21" height="21" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.7" stroke-linecap="round" stroke-linejoin="round"><path d="M10 3h4v4l2.5 4v10H7.5V11L10 7z"></path><path d="M7.5 14h9"></path></svg>',
    "mark": '<svg width="21" height="21" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.7" stroke-linecap="round" stroke-linejoin="round"><path d="M6 4h12v17l-6-4-6 4z"></path></svg>',
    "glass": '<svg width="21" height="21" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.7" stroke-linecap="round" stroke-linejoin="round"><path d="M7 4h10l-1.4 9.5a2 2 0 01-2 1.7h-3.2a2 2 0 01-2-1.7z"></path><path d="M12 15.2V20M9 20h6"></path></svg>',
    "more": '<svg width="21" height="21" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.7" stroke-linecap="round"><circle cx="5" cy="12" r="1.4"></circle><circle cx="12" cy="12" r="1.4"></circle><circle cx="19" cy="12" r="1.4"></circle></svg>',
    "plus": '<svg width="23" height="23" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.2" stroke-linecap="round"><path d="M12 5v14M5 12h14"></path></svg>',
    "info": '<svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.9" stroke-linecap="round" style="flex:none;margin-top:2px"><circle cx="12" cy="12" r="9"></circle><path d="M12 11v5.5M12 7.6v.1"></path></svg>',
    "star": '<svg width="14" height="14" viewBox="0 0 24 24" fill="currentColor"><path d="M12 3l2.7 5.8 6.3.8-4.6 4.4 1.2 6.3L12 17.3 6.4 20.3l1.2-6.3L3 9.6l6.3-.8z"></path></svg>',
    "starOutline": '<svg width="22" height="22" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.6" stroke-linejoin="round"><path d="M12 3l2.7 5.8 6.3.8-4.6 4.4 1.2 6.3L12 17.3 6.4 20.3l1.2-6.3L3 9.6l6.3-.8z"></path></svg>',
    "check": '<svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.2" stroke-linecap="round" stroke-linejoin="round"><path d="M20 6L9 17l-5-5"></path></svg>',
    "wifi_off": '<svg width="17" height="17" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.9" stroke-linecap="round"><path d="M3 3l18 18"></path><path d="M8.5 15.5a5 5 0 017 0"></path><path d="M5 12a10 10 0 013.2-2.2M18.9 12.1a10 10 0 00-4.3-2.7"></path><circle cx="12" cy="19" r="1"></circle></svg>',
    "edit": '<svg width="17" height="17" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round"><path d="M4 20h4l10-10-4-4L4 16z"></path><path d="M13.5 6.5l4 4"></path></svg>',
}


def status():
    """Presentation-only status strip, to match the reference sheet."""
    return ('<div class="status"><span>9:41</span>'
            '<span style="display:flex;gap:6px;align-items:center">'
            '<svg width="17" height="11" viewBox="0 0 18 12" fill="currentColor">'
            '<rect x="0" y="8" width="3" height="4" rx="1"></rect>'
            '<rect x="5" y="5.5" width="3" height="6.5" rx="1"></rect>'
            '<rect x="10" y="3" width="3" height="9" rx="1"></rect>'
            '<rect x="15" y="0" width="3" height="12" rx="1"></rect></svg>'
            '<svg width="15" height="11" viewBox="0 0 16 12" fill="currentColor">'
            '<path d="M8 11.2l-2.3-2.5a3.3 3.3 0 014.6 0z"></path>'
            '<path d="M8 6.2a6 6 0 00-4.2 1.7L2.4 6.4a8 8 0 0111.2 0l-1.4 1.5A6 6 0 008 6.2z" '
            'opacity=".9"></path></svg>'
            '<svg width="24" height="12" viewBox="0 0 26 12" fill="none">'
            '<rect x="0.6" y="0.6" width="21" height="10.8" rx="3" stroke="currentColor" '
            'stroke-opacity=".5"></rect>'
            '<rect x="2.4" y="2.4" width="15" height="7.2" rx="1.6" fill="currentColor"></rect>'
            '<path d="M23.6 4.2v3.6a2 2 0 000-3.6z" fill="currentColor" fill-opacity=".5"></path>'
            '</svg></span></div>')


def bottle(h=58, label="var(--gold)", body="var(--glass)"):
    """A drawn bottle silhouette. Placeholder for real label art, which is not
    ours to reproduce."""
    w = int(h * 0.62)
    return ('<svg width="%d" height="%d" viewBox="0 0 36 58" fill="none">'
            '<path d="M14 2h8v9.5l4.2 6.8A6 6 0 0127 21.5V52a4 4 0 01-4 4H13a4 4 0 01-4-4V21.5'
            'a6 6 0 01.8-3.2L14 11.5z" fill="%s" fill-opacity=".55" stroke="%s" stroke-width="1.4"/>'
            '<rect x="13.4" y="1.4" width="9.2" height="4.6" rx="1.4" fill="%s" fill-opacity=".8"/>'
            '<rect x="9.6" y="28" width="16.8" height="15" rx="2" fill="%s" fill-opacity=".85"/>'
            '</svg>') % (w, h, body, body, body, label)


def tabs(active):
    left = [("Shelf Check", ICON["search"]), ("Collection", ICON["bottle"])]
    right = [("Tasting", ICON["glass"]), ("More", ICON["more"])]
    out = ['<div class="tabs">']
    for label, svg in left:
        out.append('<div class="tab%s">%s%s</div>' % (" on" if label == active else "", svg, label))
    out.append('<div class="tabadd"><div>%s</div>Add</div>' % ICON["plus"])
    for label, svg in right:
        out.append('<div class="tab%s">%s%s</div>' % (" on" if label == active else "", svg, label))
    out.append("</div>")
    return "\n  ".join(out)


def stars(n, of=10):
    return '<span class="rate">%s %d/%d</span>' % (ICON["star"], n, of)


def write(name, body, theme):
    html = """<!doctype html>
<html>
<head>
  <meta charset="utf-8">
  <script src="./support.js"></script>
</head>
<body>
<x-dc>
<helmet>
  <link rel="stylesheet" href="%s">
  <style>%s  </style>
</helmet>

%s
</x-dc>
</body>
</html>
""" % (FONTS, CSS % theme, body)
    io.open(os.path.join(HERE, name), "w", encoding="utf-8").write(html)
    return name
