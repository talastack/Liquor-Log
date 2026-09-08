# Generates every artboard. Run:  python screens.py
#
# Numbers are engine values, not decoration:
#   750 ml / 1.5 fl oz pour = 17 pours   4 poured -> 13 left, 573 ml, 76%
#   8 poured -> 9 left, 399 ml, 53%      12 poured -> 5 left, 222 ml, 30%
#   cost per pour = price / total pours  ($79.99 / 17 = $4.71)

from build import DARK, LIGHT, ICON, status, bottle, tabs, stars, write

I = ICON


def nav(left, title="", right=""):
    return ('<div class="nav"><div class="navbtn" style="justify-content:flex-start">' + left +
            '</div><div class="lab" style="letter-spacing:.06em">' + title +
            '</div><div class="navbtn" style="justify-content:flex-end">' + right + '</div></div>')


def head(title, sub=""):
    s = '<div style="padding:14px 20px 16px"><h1 class="h1">' + title + '</h1>'
    if sub:
        s += '<div class="body" style="margin-top:6px">' + sub + '</div>'
    return s + '</div>'


def search(text, placeholder=False, clear=True):
    inner = ('<span class="faint" style="flex:1">' + text + '</span>') if placeholder else \
            ('<span style="flex:1">' + text + '</span>')
    x = ('<span class="faint" style="min-width:24px;text-align:right">' + I["close"] + '</span>') if clear else ""
    return ('<div style="padding:0 20px 14px"><div class="field">'
            '<span class="faint" style="display:flex">' + I["search"] + '</span>' + inner + x +
            '</div></div>')


# ---------------------------------------------------------------- 1. tokens
def design_system():
    def sw(c):
        return ('<div style="width:34px;height:34px;border-radius:8px;background:' + c +
                ';border:1px solid rgba(255,255,255,.08)"></div>')
    dark = "".join(sw(c) for c in ["#15100a", "#1e1710", "#2a2016", "#3a2d1e", "#c9973a", "#e2b661", "#f2e9db"])
    light = "".join(sw(c) for c in ["#f6f1e7", "#fffdf7", "#ece4d4", "#dcd0ba", "#8a5f18", "#a87c2c", "#1b1510"])

    sem = [("Background", "#15100a"), ("Surface", "#1e1710"), ("Card", "#2a2016"),
           ("Text primary", "#f2e9db"), ("Text secondary", "#c0b19a"), ("Brand / accent", "#c9973a"),
           ("Success", "#7faa72"), ("Warning", "#c9973a"), ("Error", "#c07862")]
    semrows = "".join(
        '<div style="display:flex;align-items:center;gap:10px;padding:7px 0">'
        '<span style="width:13px;height:13px;border-radius:7px;background:' + c +
        ';border:1px solid rgba(255,255,255,.12);flex:none"></span>'
        '<span style="font-size:14px" class="dim">' + n + '</span></div>' for n, c in sem)

    badges = "".join([
        '<span class="badge b-shelf">On your shelf</span>',
        '<span class="badge b-line">Have the line</span>',
        '<span class="badge b-bar">Tasted, not owned</span>',
        '<span class="badge b-had">Had it before</span>',
        '<span class="badge b-never">Never had it</span>',
        '<span class="badge b-wish">Wishlist</span>',
    ])

    typ = [("Large title", "h1", 'font-family:Newsreader,Georgia,serif;font-size:30px;font-weight:600'),
           ("Title", "h2", 'font-family:Newsreader,Georgia,serif;font-size:23px;font-weight:500'),
           ("Headline", "h3", 'font-size:17px;font-weight:700'),
           ("Body", "body", 'font-size:16px'),
           ("Caption", "caption", 'font-size:12px;letter-spacing:.09em;text-transform:uppercase;font-weight:700')]
    typrows = "".join(
        '<div style="display:flex;justify-content:space-between;align-items:baseline;gap:14px;'
        'padding:9px 0;border-bottom:1px solid var(--line)"><span style="' + st + '">' + n +
        '</span><span class="mono faint" style="font-size:12px">' + tag + '</span></div>'
        for n, tag, st in typ)

    space = "".join('<div style="display:flex;flex-direction:column;align-items:center;gap:6px">'
                    '<div style="width:' + str(v) + 'px;height:8px;background:var(--gold);border-radius:2px"></div>'
                    '<span class="mono faint" style="font-size:12px">' + str(v) + '</span></div>'
                    for v in [4, 8, 12, 16, 24])

    return ('<div class="sc">' + status() +
            '<div style="padding:16px 20px 10px"><h1 class="h1">Liquor&#8209;Log</h1>'
            '<div class="serif gold" style="font-size:23px;line-height:1.2">Design system</div></div>'
            '<div style="padding:0 20px 26px">'
            '<div class="lab" style="margin-bottom:10px">Colour tokens</div>'
            '<div class="faint" style="font-size:13px;margin-bottom:7px">Dark</div>'
            '<div style="display:flex;gap:8px;flex-wrap:wrap">' + dark + '</div>'
            '<div class="faint" style="font-size:13px;margin:14px 0 7px">Light</div>'
            '<div style="display:flex;gap:8px;flex-wrap:wrap">' + light + '</div>'

            '<div class="lab" style="margin:26px 0 6px">Semantics</div>' + semrows +

            '<div class="lab" style="margin:26px 0 12px">Verdict badges</div>'
            '<div class="chips" style="gap:9px">' + badges + '</div>'
            '<div class="body" style="font-size:14px;margin-top:12px">Owned states are filled; states you '
            'do not own are outlined. The fill is what carries at arm&#8217;s length in a shop.</div>'

            '<div class="lab" style="margin:26px 0 6px">Typography</div>' + typrows +

            '<div class="lab" style="margin:26px 0 12px">Components</div>'
            '<div style="display:flex;gap:11px;align-items:center;margin-bottom:14px">'
            '<div class="fill"><i style="width:76%"></i></div>'
            '<span class="mono" style="font-size:14px">76%</span></div>'
            '<div style="display:flex;gap:12px;align-items:center">' + stars(8) +
            '<span class="badge b-open">Open</span>'
            '<span class="mono faint" style="font-size:13px">13 of 17</span></div>'

            '<div class="lab" style="margin:26px 0 12px">Spacing rhythm</div>'
            '<div style="display:flex;gap:16px;align-items:flex-end">' + space + '</div>'
            '</div></div>')


# --------------------------------------------------------- 2. shelf, empty
def shelf_empty():
    recents = "".join('<span class="chip ghost">' + t + '</span>'
                      for t in ["elijah craig", "four roses", "bourbon county"])
    return ('<div class="sc">' + status() +
            nav("", "", '<span class="faint">' + I["share"] + '</span>') +
            head("Shelf Check") +
            search("Search for a bottle&hellip;", placeholder=True, clear=False) +
            '<div style="padding:0 20px"><div class="lab" style="margin-bottom:10px">Recent lookups</div>'
            '<div class="chips">' + recents + '</div></div>'
            '<div style="padding:44px 34px 0;text-align:center">'
            '<div style="display:flex;justify-content:center;gap:9px;align-items:flex-end;opacity:.5">' +
            bottle(64) + bottle(84) + bottle(70) +
            '</div>'
            '<div class="serif" style="font-size:21px;margin-top:22px;line-height:1.3">'
            'Search for a bottle to see your shelf status</div>'
            '<div class="body" style="font-size:14px;margin-top:9px">We&#8217;ll show you what you have, '
            'what you&#8217;ve tasted, and what is still on your radar.</div></div>' +
            tabs("Shelf Check") + '</div>')


# ------------------------------------------------------- 3. shelf, results
def _result(thumb_label, kicker, name, badge, meta, extra="", rating=None):
    r = ('<div style="margin-left:auto">' + stars(rating) + '</div>') if rating else ""
    return ('<div class="card"><div class="thumb">' + bottle(58, thumb_label) + '</div>'
            '<div style="flex:1;min-width:0">'
            '<div class="lab" style="font-size:12px">' + kicker + '</div>'
            '<div class="name" style="margin:4px 0 8px">' + name + '</div>'
            '<div style="display:flex;gap:9px;align-items:center;flex-wrap:wrap">' + badge + r + '</div>'
            '<div class="meta" style="margin-top:9px">' + meta + '</div>' + extra +
            '</div></div>')


def shelf_results():
    fill = ('<div style="display:flex;gap:10px;align-items:center;margin-top:11px">'
            '<div class="fill"><i style="width:76%"></i></div>'
            '<span class="mono" style="font-size:13px;white-space:nowrap">13/17 &middot; 573 ml</span></div>')

    filters = ('<div style="padding:0 20px 14px;display:flex;gap:8px">'
               '<span class="chip on">All 3</span>'
               '<span class="chip ghost">On shelf 1</span>'
               '<span class="chip ghost">Have the line 1</span></div>')

    cards = (
        _result("var(--gold)", "Elijah Craig", "Barrel Proof B523",
                '<span class="badge b-shelf">On your shelf</span>',
                "Kentucky Straight &middot; Small batch<br>62.1% ABV &middot; 124.2 proof &middot; 750 ml",
                fill, 8) +
        _result("var(--v-bar)", "Elijah Craig", "Small Batch",
                '<span class="badge b-bar">Tasted, not owned</span>',
                "Kentucky Straight &middot; Small batch<br>47% ABV &middot; 94 proof",
                '<div class="body" style="font-size:14px;margin-top:9px">Bar Vendetta, March. '
                'Never owned a bottle.</div>', 7) +
        _result("var(--v-line)", "Elijah Craig", "18 Year",
                '<span class="badge b-line">Have the line</span>',
                "Kentucky Straight &middot; Single barrel<br>45% ABV &middot; 90 proof",
                '<div class="body" style="font-size:14px;margin-top:9px">You own two other Elijah Craigs. '
                'This one you have never had.</div>'
                '<div class="btn2" style="min-height:44px;margin-top:12px;font-size:15px">' +
                I["mark"] + 'Add to wishlist</div>'))

    return ('<div class="sc">' + status() +
            nav("", "", '<span class="faint">' + I["share"] + '</span>') +
            head("Shelf Check") + search("elijah craig") + filters +
            '<div style="padding:0 20px">' + cards + '</div>' +
            tabs("Shelf Check") + '</div>')


# ------------------------------------------------- 4. never had it, related
def shelf_related():
    def rel(name, why):
        return ('<div style="display:flex;align-items:center;gap:13px;padding:14px 0;'
                'border-bottom:1px solid var(--line)">'
                '<div class="thumb" style="width:34px">' + bottle(44, "var(--faint)") + '</div>'
                '<div style="flex:1;min-width:0"><div class="serif" style="font-size:17px">' + name + '</div>'
                '<div class="faint" style="font-size:14px;margin-top:2px">' + why + '</div></div>'
                '<span class="faint" style="transform:rotate(180deg);display:flex">' + I["back"] + '</span>'
                '</div>')

    return ('<div class="sc">' + status() +
            nav('<span class="faint">' + I["back"] + '</span>', "",
                '<span class="faint">' + I["share"] + '</span>') +
            '<div style="padding:8px 20px 0;text-align:center">' + bottle(96, "var(--v-line)") +
            '<div class="lab" style="margin-top:14px">Elijah Craig</div>'
            '<h1 class="h1" style="font-size:28px;margin-top:5px">18 Year</h1>'
            '<div style="margin-top:12px"><span class="badge b-never">Never had it</span></div>'
            '<div class="meta" style="margin-top:12px">Kentucky Straight Bourbon &middot; Single barrel<br>'
            '45% ABV &middot; 90 proof</div>'
            '<div class="btn2" style="margin-top:18px">' + I["mark"] + 'Add to wishlist</div></div>'
            '<div style="padding:26px 20px 0"><div class="lab" style="margin-bottom:4px">Related suggestions</div>'
            '<div class="faint" style="font-size:13px;margin-bottom:6px">Matched on what these share, '
            'not how the names are spelled.</div>' +
            rel("Elijah Craig Barrel Proof B523", "Same line &middot; Elijah Craig") +
            rel("Elijah Craig Small Batch", "Same line &middot; Elijah Craig") +
            rel("Heaven Hill Bottled in Bond", "Same distillery &middot; Heaven Hill") +
            '</div>' + tabs("Shelf Check") + '</div>')


# ------------------------------------------------------------- 5. offline
def shelf_offline():
    banner = ('<div style="margin:10px 20px 0;padding:13px 15px;border-radius:11px;'
              'background:var(--surface);border:1px solid var(--line);display:flex;gap:11px">'
              '<span class="faint" style="display:flex;flex:none;margin-top:1px">' + I["wifi_off"] + '</span>'
              '<div><div style="font-size:15px;font-weight:600">You are offline</div>'
              '<div class="faint" style="font-size:14px;margin-top:2px">Search and your collection '
              'still work as expected.</div></div></div>')

    fill = ('<div style="display:flex;gap:10px;align-items:center;margin-top:11px">'
            '<div class="fill"><i style="width:76%"></i></div>'
            '<span class="mono" style="font-size:13px;white-space:nowrap">13/17 &middot; 573 ml</span></div>')

    return ('<div class="sc">' + status() + banner + head("Shelf Check") + search("elijah craig") +
            '<div style="padding:0 20px">' +
            _result("var(--gold)", "Elijah Craig", "Barrel Proof B523",
                    '<span class="badge b-shelf">On your shelf</span>',
                    "Kentucky Straight &middot; Small batch<br>62.1% ABV &middot; 124.2 proof &middot; 750 ml",
                    fill, 8) +
            _result("var(--v-bar)", "Elijah Craig", "Small Batch",
                    '<span class="badge b-bar">Tasted, not owned</span>',
                    "Kentucky Straight &middot; Small batch<br>47% ABV &middot; 94 proof", "", 7) +
            '</div>'
            '<div style="margin-top:auto;padding:0 20px 18px"><div class="plain">'
            '<div style="font-size:15px;font-weight:600">Nothing here needs the network</div>'
            '<div class="body" style="font-size:14px;margin-top:5px">Every bottle, batch and note is on '
            'the phone. Pours and tastings sync when there is signal, and never block anything meanwhile.'
            '</div></div></div>' + tabs("Shelf Check") + '</div>')


# ------------------------------------------------------- 6/7/8. bottle detail
def _detail_head(kicker, name, badge, meta, rating, tint):
    return ('<div style="padding:8px 20px 0;text-align:center">' + bottle(104, tint) +
            '<div class="lab" style="margin-top:14px">' + kicker + '</div>'
            '<h1 class="h1" style="font-size:28px;margin-top:5px">' + name + '</h1>'
            '<div style="margin-top:12px;display:flex;justify-content:center;gap:10px;align-items:center">' +
            badge + stars(rating) + '</div>'
            '<div class="meta" style="margin-top:12px">' + meta + '</div></div>')


def _fill_block(pours, total, ml, pct, opened, cost):
    return ('<div style="padding:24px 20px 0"><div class="lab" style="margin-bottom:11px">Fill level</div>'
            '<div style="display:flex;justify-content:space-between;align-items:baseline;margin-bottom:9px">'
            '<span class="mono" style="font-size:18px">' + str(pours) + ' of ' + str(total) +
            ' pours left</span>'
            '<span class="mono dim" style="font-size:14px">' + ml + ' left</span></div>'
            '<div style="display:flex;gap:10px;align-items:center">'
            '<div class="fill"><i style="width:' + pct + '"></i></div>'
            '<span class="mono" style="font-size:14px">' + pct + '</span></div>'
            '<div style="display:flex;justify-content:space-between;margin-top:13px">'
            '<span class="dim" style="font-size:14px">' + opened + '</span>'
            '<span class="dim" style="font-size:14px">Est. cost per pour <span class="mono gold">' +
            cost + '</span></span></div></div>')


def bottle_open():
    return ('<div class="sc">' + status() +
            nav('<span class="faint">' + I["back"] + '</span>', "",
                '<span class="faint">' + I["share"] + '</span>') +
            _detail_head("Elijah Craig &middot; Heaven Hill", "Barrel Proof B523",
                         '<span class="badge b-shelf">On your shelf</span>',
                         "62.1% ABV &middot; 124.2 proof &middot; 750 ml", 8, "var(--gold)") +
            _fill_block(13, 17, "573 ml", "76%", "Opened 44 days ago", "$4.71") +
            '<div style="padding:24px 20px 0">'
            '<div class="fact"><span>Class type</span><span>Kentucky Straight Bourbon Whiskey</span></div>'
            '<div class="fact"><span>Production type</span><span>Small batch &middot; barrel proof</span></div>'
            '<div class="fact"><span>Distilled / bottled</span><span class="mono">2011 &rarr; 2023</span></div>'
            '<div class="fact last"><span>Bought</span><span>Total Wine, 12 May 2026 &middot; $79.99</span></div>'
            '</div>'
            '<div style="padding:22px 20px 0"><div class="lab" style="margin-bottom:10px">Your last tasting</div>'
            '<div class="plain"><div style="display:flex;gap:9px"><span class="good" style="color:var(--good);'
            'font-size:13px;font-weight:700;flex:none">LIKED</span>'
            '<span class="body" style="font-size:14px">Burnt caramel and dried figs, thick on the tongue</span></div>'
            '<div style="display:flex;gap:9px;margin-top:8px"><span style="color:var(--bad);font-size:13px;'
            'font-weight:700;flex:none">NOT</span><span class="body" style="font-size:14px">Runs hot on the '
            'finish without a few drops of water</span></div></div></div>'
            '<div style="display:flex;gap:11px;padding:22px 20px 30px">'
            '<div class="btn2">' + I["edit"] + 'Edit bottle</div>'
            '<div class="btn">' + I["glass"] + 'Add tasting</div></div>'
            '</div>')


def bottle_pick():
    cmp_card = ('<div class="plain" style="margin-top:14px;display:flex;gap:12px;align-items:center">'
                '<div class="thumb" style="width:32px">' + bottle(42, "var(--gold)") + '</div>'
                '<div style="flex:1"><div style="font-size:15px;font-weight:600">PickCompare</div>'
                '<div class="faint" style="font-size:14px;margin-top:2px">How does this pick compare to '
                'the standard release?</div></div>'
                '<span class="faint" style="transform:rotate(180deg);display:flex">' + I["back"] + '</span></div>')

    return ('<div class="sc">' + status() +
            nav('<span class="faint">' + I["back"] + '</span>', "",
                '<span class="faint">' + I["share"] + '</span>') +
            _detail_head("Four Roses", "Store Pick, OESQ",
                         '<span class="badge b-shelf">On your shelf</span>',
                         "57.7% ABV &middot; 115.4 proof &middot; 750 ml", 9, "var(--gold)") +
            _fill_block(9, 17, "399 ml", "53%", "Opened 96 days ago", "$3.53") +
            '<div style="padding:24px 20px 0"><div class="lab" style="margin-bottom:4px">Store pick details</div>'
            '<div class="fact"><span>Recipe code</span><span class="mono gold">OESQ</span></div>'
            '<div class="fact"><span>Mashbill</span><span class="mono">E &mdash; 75/20/5<br>'
            '<span class="faint" style="font-size:13px">75% corn, 20% rye, 5% malted barley</span></span></div>'
            '<div class="fact"><span>Yeast</span><span>Q &mdash; floral essence</span></div>'
            '<div class="fact"><span>Class type</span><span>Kentucky Straight Bourbon Whiskey</span></div>'
            '<div class="fact"><span>Production type</span><span>Single barrel &middot; barrel proof</span></div>'
            '<div class="fact"><span>Picked by</span><span>Total Wine &amp; More</span></div>'
            '<div class="fact last"><span>Barrel number</span><span class="mono">42&#8209;3C</span></div>' +
            cmp_card + '</div>'
            '<div style="display:flex;gap:11px;padding:22px 20px 30px">'
            '<div class="btn2">' + I["edit"] + 'Edit bottle</div>'
            '<div class="btn">' + I["glass"] + 'Add tasting</div></div>'
            '</div>')


def bottle_fading():
    band = ('<div style="display:grid;grid-template-columns:repeat(3,minmax(0,1fr));gap:6px;margin-top:14px">'
            '<div style="height:6px;border-radius:3px;background:var(--surface2)"></div>'
            '<div style="height:6px;border-radius:3px;background:var(--gold)"></div>'
            '<div style="height:6px;border-radius:3px;background:var(--surface2)"></div></div>'
            '<div style="display:grid;grid-template-columns:repeat(3,minmax(0,1fr));gap:6px;margin-top:8px">'
            '<span class="faint" style="font-size:12px">Likely good</span>'
            '<span style="font-size:12px;color:var(--gold);text-align:center">May be fading</span>'
            '<span class="faint" style="font-size:12px;text-align:right">Likely faded</span></div>')

    return ('<div class="sc">' + status() +
            nav('<span class="faint">' + I["back"] + '</span>', "",
                '<span class="faint">' + I["share"] + '</span>') +
            _detail_head("W L Weller &middot; Buffalo Trace", "Antique 107",
                         '<span class="badge b-shelf">On your shelf</span>',
                         "53.5% ABV &middot; 107 proof &middot; 750 ml", 7, "var(--v-never)") +
            _fill_block(5, 17, "222 ml", "30%", "Opened 213 days ago", "$2.94") +
            '<div style="padding:22px 20px 0"><div class="plain" style="border-color:var(--gold)">'
            '<div style="display:flex;gap:9px;align-items:center">'
            '<span class="gold" style="display:flex;flex:none">' + I["info"] + '</span>'
            '<span style="font-size:16px;font-weight:700;color:var(--gold)">Oxidation outlook: fading</span></div>'
            '<div class="body" style="font-size:14px;margin-top:10px">With 70% of the bottle now air, expect '
            'noticeable change in flavour over time. The sweetness usually goes first.</div>' + band +
            '<div class="faint" style="font-size:13px;margin-top:14px;padding-top:12px;'
            'border-top:1px solid var(--line)">A guideline, not a precise date. Nobody has published a real '
            'curve for this, so the app gives you a band and never a deadline.</div></div></div>'
            '<div style="padding:22px 20px 0">'
            '<div class="fact"><span>Class type</span><span>Kentucky Straight Bourbon Whiskey</span></div>'
            '<div class="fact last"><span>Production type</span><span>Not stated on the label</span></div></div>'
            '<div style="display:flex;gap:11px;padding:22px 20px 30px">'
            '<div class="btn2">Finish it</div><div class="btn">Log a pour</div></div>'
            '</div>')


# ------------------------------------------------------------- 9. tasting
def tasting_sheet():
    def stage(n, picks):
        chips = "".join('<span class="chip" style="min-height:38px;padding:8px 13px;font-size:14px;'
                        'color:var(--gold)">' + p + '</span>' for p in picks)
        add = ('<span class="chip ghost" style="min-height:38px;padding:8px 13px;font-size:14px;'
               'color:var(--gold);border-color:var(--gold)">Wheel</span>')
        count = (str(len(picks)) + " picked") if picks else "tap the wheel"
        return ('<div style="padding:14px 0;border-bottom:1px solid var(--line)">'
                '<div style="display:flex;justify-content:space-between;align-items:baseline;'
                'margin-bottom:10px"><span class="lab">' + n + '</span>'
                '<span class="faint" style="font-size:13px">' + count + '</span></div>'
                '<div class="chips">' + chips + add + '</div></div>')

    scale = "".join('<div style="min-height:44px;border-radius:9px;display:flex;align-items:center;'
                    'justify-content:center;font-size:14px;' +
                    ('background:var(--gold);color:var(--on-gold);font-weight:700' if v == 8 else
                     'background:var(--surface2);color:var(--dim)') + '">' + str(v) + '</div>'
                    for v in range(1, 11))

    return ('<div class="sc">' + status() +
            '<div class="nav"><span class="dim" style="font-size:16px">Cancel</span>'
            '<span class="lab">New tasting</span>'
            '<span style="font-size:16px;font-weight:700;color:var(--gold)">Save</span></div>'
            '<div style="padding:14px 20px 0"><div class="card" style="margin-bottom:0">'
            '<div class="thumb">' + bottle(50, "var(--gold)") + '</div>'
            '<div><div class="name" style="font-size:19px">Elijah Craig Barrel Proof B523</div>'
            '<div class="meta" style="margin-top:5px">62.1% ABV &middot; 124.2 proof &middot; neat</div></div>'
            '</div></div>'
            '<div style="padding:8px 20px 0">' +
            stage("Nose", ["Caramel", "Vanilla", "Charred oak"]) +
            stage("Entry", ["Brown sugar", "Baking spice"]) +
            stage("Mid", ["Dried fig"]) +
            stage("Finish", ["Rye spice", "Warm"]) +
            '</div>'
            '<div style="padding:20px 20px 0"><div class="lab" style="margin-bottom:10px">Rating</div>'
            '<div style="display:grid;grid-template-columns:repeat(10,minmax(0,1fr));gap:5px">' + scale + '</div></div>'
            '<div style="padding:22px 20px 0"><div class="lab" style="margin-bottom:10px">Would you rebuy?</div>'
            '<div style="display:flex;gap:9px"><span class="chip on" style="flex:1;justify-content:center">Yes</span>'
            '<span class="chip ghost" style="flex:1;justify-content:center">Maybe</span>'
            '<span class="chip ghost" style="flex:1;justify-content:center">No</span></div></div>'
            '<div style="padding:22px 20px 0"><div class="lab" style="margin-bottom:9px">What you liked</div>'
            '<div class="plain faint" style="font-size:15px">Notes&hellip;</div></div>'
            '<div style="padding:16px 20px 0"><div class="lab" style="margin-bottom:9px">What you did not</div>'
            '<div class="plain faint" style="font-size:15px">Notes&hellip;</div></div>'
            '<div class="faint" style="font-size:13px;text-align:center;padding:18px 30px 30px">'
            'Nothing is required. A rating on its own is a complete tasting.</div>'
            '</div>')


# -------------------------------------------------------- 10. flavour wheel
def flavour_wheel():
    names = ["Fruit", "Sweet", "Spice", "Oak", "Grain", "Floral", "Herbal", "Smoke"]
    paths = [
        "M150,14 A136,136 0 0 1 246.2,53.8 L194.6,105.4 A63,63 0 0 0 150,87 Z",
        "M246.2,53.8 A136,136 0 0 1 286,150 L213,150 A63,63 0 0 0 194.6,105.4 Z",
        "M286,150 A136,136 0 0 1 246.2,246.2 L194.6,194.6 A63,63 0 0 0 213,150 Z",
        "M246.2,246.2 A136,136 0 0 1 150,286 L150,213 A63,63 0 0 0 194.6,194.6 Z",
        "M150,286 A136,136 0 0 1 53.8,246.2 L105.4,194.6 A63,63 0 0 0 150,213 Z",
        "M53.8,246.2 A136,136 0 0 1 14,150 L87,150 A63,63 0 0 0 105.4,194.6 Z",
        "M14,150 A136,136 0 0 1 53.8,53.8 L105.4,105.4 A63,63 0 0 0 87,150 Z",
        "M53.8,53.8 A136,136 0 0 1 150,14 L150,87 A63,63 0 0 0 105.4,105.4 Z",
    ]
    pos = [(188, 58), (242, 112), (242, 188), (188, 242), (112, 242), (58, 188), (58, 112), (112, 58)]
    sel = {1, 3}  # Sweet and Oak
    segs = "".join('<path d="' + p + '" fill="' +
                   ("var(--gold)" if i in sel else "var(--surface2)") + '"></path>'
                   for i, p in enumerate(paths))
    labels = "".join('<text x="' + str(x) + '" y="' + str(y) + '" fill="' +
                     ("var(--on-gold)" if i in sel else "var(--dim)") + '" font-weight="' +
                     ("700" if i in sel else "600") + '">' + names[i] + '</text>'
                     for i, (x, y) in enumerate(pos))

    def row(stage, items):
        return ('<div style="display:flex;gap:12px;padding:12px 0;border-bottom:1px solid var(--line)">'
                '<span class="lab" style="width:58px;flex:none">' + stage + '</span>'
                '<span style="font-size:15px">' + items + '</span></div>')

    return ('<div class="sc">' + status() +
            nav('<span class="faint">' + I["back"] + '</span>', "Flavour wheel", "") +
            '<div style="display:flex;justify-content:center;padding:10px 20px 0">'
            '<svg width="300" height="300" viewBox="0 0 300 300" role="img" '
            'aria-label="Flavour wheel, eight families">'
            '<g stroke="var(--bg)" stroke-width="2">' + segs + '</g>'
            '<g font-family="Public Sans, Helvetica, Arial, sans-serif" font-size="13" '
            'text-anchor="middle" dominant-baseline="middle">' + labels + '</g>'
            '<circle cx="150" cy="150" r="59" fill="var(--surface)" stroke="var(--line)"></circle>'
            '<text x="150" y="151" text-anchor="middle" dominant-baseline="middle" '
            'font-family="Newsreader, Georgia, serif" font-size="21" fill="var(--gold)">Bourbon</text>'
            '</svg></div>'
            '<div style="padding:18px 20px 0"><div class="lab" style="margin-bottom:4px">Selected descriptors</div>' +
            row("Nose", "Caramel, Vanilla, Oak") +
            row("Entry", "Brown sugar, Baking spice") +
            row("Mid", "Oak, Dried fruit") +
            row("Finish", "Long, Warm, Spice") +
            '</div>'
            '<div style="padding:22px 20px 30px;margin-top:auto"><div class="btn">Done &mdash; 10 descriptors</div></div>'
            '</div>')


# ------------------------------------------------------- 11. tasting history
def tasting_history():
    def entry(date, rating, note):
        return ('<div class="plain" style="margin-bottom:11px">'
                '<div style="display:flex;justify-content:space-between;align-items:center;gap:12px">'
                '<span style="font-size:15px;font-weight:600">' + date + '</span>' + stars(rating) + '</div>'
                '<div class="body" style="font-size:14px;margin-top:9px">' + note + '</div></div>')

    return ('<div class="sc">' + status() +
            nav('<span class="faint">' + I["back"] + '</span>', "Tasting history", "") +
            '<div style="padding:14px 20px 0"><div class="card">'
            '<div class="thumb">' + bottle(50, "var(--gold)") + '</div>'
            '<div><div class="name" style="font-size:19px">Elijah Craig Barrel Proof B523</div>'
            '<div class="meta" style="margin-top:5px">62.1% ABV &middot; 124.2 proof</div>'
            '<div class="faint" style="font-size:13px;margin-top:7px">4 tastings &middot; 7 &rarr; 8</div>'
            '</div></div></div>'
            '<div style="padding:8px 20px 0">' +
            entry("8 Sep 2026", 8, "Burnt caramel and dried figs, thick on the tongue. Runs hot on the "
                                   "finish without a few drops of water.") +
            entry("18 Aug 2026", 8, "Opened right up with a splash of water &mdash; cherry underneath.") +
            entry("2 Aug 2026", 7, "Settling down. The oak is coming forward as the bottle breathes.") +
            entry("26 Jul 2026", 7, "Straight off the shelf and far too hot. Needs a few weeks open.") +
            '</div>'
            '<div style="padding:8px 20px 30px;margin-top:auto">'
            '<div class="btn2">' + I["plus"] + 'Add tasting</div></div>'
            '</div>')


# ---------------------------------------------------------- 12. collection
def collection():
    def item(kicker, name, meta, pours, ml, pct, rating, open_=True):
        return ('<div class="card"><div class="thumb">' + bottle(58, "var(--gold)") + '</div>'
                '<div style="flex:1;min-width:0">'
                '<div style="display:flex;justify-content:space-between;gap:10px;align-items:flex-start">'
                '<div style="min-width:0"><div class="lab">' + kicker + '</div>'
                '<div class="name" style="font-size:20px;margin:4px 0 0">' + name + '</div></div>' +
                ('<span class="badge b-open">Open</span>' if open_ else '') + '</div>'
                '<div class="meta" style="margin-top:7px">' + meta + '</div>'
                '<div style="display:flex;gap:10px;align-items:center;margin-top:11px">'
                '<div class="fill"><i style="width:' + pct + '"></i></div>'
                '<span class="mono" style="font-size:13px;white-space:nowrap">' + pours + '</span></div>'
                '<div style="display:flex;justify-content:space-between;align-items:center;margin-top:9px">'
                '<span class="mono faint" style="font-size:13px">' + ml + '</span>' + stars(rating) + '</div>'
                '</div></div>')

    beer = ('<div class="card"><div class="thumb">' + bottle(58, "var(--v-had)") + '</div>'
            '<div style="flex:1;min-width:0">'
            '<div style="display:flex;justify-content:space-between;gap:10px;align-items:flex-start">'
            '<div style="min-width:0"><div class="lab">Goose Island</div>'
            '<div class="name" style="font-size:20px;margin:4px 0 0">Bourbon County</div></div>'
            '<span class="badge b-had">Beer</span></div>'
            '<div class="meta" style="margin-top:7px">Barrel&#8209;aged imperial stout<br>'
            '14.7% ABV &middot; 500 ml</div>'
            '<div style="display:flex;justify-content:space-between;align-items:center;margin-top:11px">'
            '<span style="font-size:14px;color:var(--good)">Cellars well &mdash; no rush</span>' +
            stars(9) + '</div></div></div>')

    return ('<div class="sc">' + status() +
            nav("", "", '<span class="faint">' + I["share"] + '</span>') +
            head("My Collection") +
            '<div style="padding:0 20px 12px;display:flex;gap:8px">'
            '<span class="chip on">Owned 3</span><span class="chip ghost">Wishlist 1</span>'
            '<span class="chip ghost">All</span></div>'
            '<div style="padding:0 20px 14px;display:flex;gap:8px">'
            '<span class="chip ghost" style="min-height:38px;font-size:14px">Class type</span>'
            '<span class="chip ghost" style="min-height:38px;font-size:14px">Production type</span>'
            '<span class="chip ghost" style="min-height:38px;font-size:14px">Open</span></div>'
            '<div style="padding:0 20px">' +
            item("Elijah Craig", "Barrel Proof B523", "62.1% ABV &middot; 124.2 proof",
                 "13 of 17", "573 ml left", "76%", 8) +
            item("Four Roses", "Store Pick, OESQ", "57.7% ABV &middot; 115.4 proof",
                 "9 of 17", "399 ml left", "53%", 9) +
            item("W L Weller", "Antique 107", "53.5% ABV &middot; 107 proof",
                 "5 of 17", "222 ml left", "30%", 7) +
            '<div class="lab" style="margin:18px 0 11px">Other beverages</div>' + beer +
            '</div>' + tabs("Collection") + '</div>')


# ------------------------------------------------- 13. add bottle + wishlist
def add_bottle():
    matched = ('<div class="card" style="border-color:var(--gold)">'
               '<div class="thumb">' + bottle(52, "var(--gold)") + '</div>'
               '<div style="flex:1;min-width:0">'
               '<div class="name" style="font-size:19px">Elijah Craig Barrel Proof B523</div>'
               '<div class="meta" style="margin-top:5px">Kentucky Straight Bourbon<br>'
               '62.1% ABV &middot; 124.2 proof</div></div>'
               '<span class="gold" style="display:flex;flex:none">' + I["check"] + '</span></div>')

    def field(label, value, faint=False):
        return ('<div style="display:flex;justify-content:space-between;align-items:center;gap:14px;'
                'padding:13px 0;border-bottom:1px solid var(--line)">'
                '<span class="dim" style="font-size:15px;flex:none">' + label + '</span>'
                '<span class="' + ("faint" if faint else "mono") + '" style="font-size:15px;'
                'text-align:right">' + value + '</span></div>')

    return ('<div class="sc">' + status() +
            nav('<span class="faint">' + I["close"] + '</span>', "", "") +
            head("Add Bottle") +
            '<div style="padding:0 20px 14px;display:flex;gap:9px">'
            '<span class="chip on" style="flex:1;justify-content:center">Add bottle</span>'
            '<span class="chip ghost" style="flex:1;justify-content:center">Wishlist</span></div>' +
            search("elijah craig") +
            '<div style="padding:0 20px">' + matched +
            '<div class="btn" style="margin-bottom:6px">Use this bottle</div>'
            '<div class="lab" style="margin:22px 0 2px">Additional details</div>' +
            field("Batch #", "B523") + field("Size", "750 ml") +
            field("Purchase price", "$79.99") +
            field("Notes", "Store, location, or notes&hellip;", faint=True) +
            '<div class="lab" style="margin:24px 0 11px">Your wishlist</div>'
            '<div class="card" style="margin-bottom:12px">'
            '<div class="thumb">' + bottle(52, "var(--v-line)") + '</div>'
            '<div style="flex:1;min-width:0">'
            '<div class="name" style="font-size:19px">Elijah Craig 18 Year</div>'
            '<div class="meta" style="margin-top:5px">Kentucky Straight Bourbon<br>'
            '45% ABV &middot; 90 proof</div></div>'
            '<span style="color:var(--v-never);display:flex;flex:none">' + I["mark"] + '</span></div>'
            '<div class="btn">Buy from wishlist</div>'
            '<div class="faint" style="font-size:13px;text-align:center;margin-top:12px;padding-bottom:30px">'
            'Not in the catalogue? Type the name and it becomes yours alone.</div>'
            '</div></div>')


SCREENS = [
    ("DesignSystem", design_system),
    ("ShelfEmpty", shelf_empty),
    ("Main", shelf_results),
    ("ShelfRelated", shelf_related),
    ("ShelfOffline", shelf_offline),
    ("BottleOpen", bottle_open),
    ("BottleStorePick", bottle_pick),
    ("BottleFading", bottle_fading),
    ("TastingSheet", tasting_sheet),
    ("TastingHistory", tasting_history),
    ("Collection", collection),
    ("AddBottle", add_bottle),
]

# A few screens repeated in the light mode, so both palettes are visible
# without doubling every artboard.
LIGHT_SET = ["Main", "BottleOpen", "Collection", "TastingSheet"]

if __name__ == "__main__":
    written = []
    for name, fn in SCREENS:
        written.append(write(name + ".dc.html", fn(), DARK))
    for name, fn in SCREENS:
        if name in LIGHT_SET:
            written.append(write(name + "Light.dc.html", fn(), LIGHT))
    print("wrote %d artboards:" % len(written))
    for w in written:
        print("  " + w)
