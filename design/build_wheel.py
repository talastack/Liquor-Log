# Generates the interactive flavour-wheel artboard from the real data.
#
#     python build_wheel.py
#
# The wheel screen and shared/data/flavor-wheel.v1.json must show the same
# families and the same descriptors. Hand-maintaining the artboard let them
# drift immediately -- the canvas drew eight segments while the data had ten.
# Now the geometry and the descriptor lists are computed from the file.

import io
import json
import math
import os

HERE = os.path.dirname(os.path.abspath(__file__))
WHEEL = os.path.join(HERE, "..", "shared", "data", "flavor-wheel.v1.json")
OUT = os.path.join(HERE, "FlavourWheel.dc.html")

CX = CY = 150.0
R_OUTER = 136.0
R_INNER = 63.0
R_LABEL = 100.0


def point(radius, degrees):
    rad = math.radians(degrees)
    return (round(CX + radius * math.cos(rad), 1),
            round(CY + radius * math.sin(rad), 1))


def segment_path(index, count):
    """One wedge, from the top, clockwise."""
    step = 360.0 / count
    a1 = -90.0 + step * index
    a2 = a1 + step
    ox1, oy1 = point(R_OUTER, a1)
    ox2, oy2 = point(R_OUTER, a2)
    ix2, iy2 = point(R_INNER, a2)
    ix1, iy1 = point(R_INNER, a1)
    # Arc sweep flag 1 outward (clockwise), 0 back along the inner edge.
    large = 1 if step > 180 else 0
    return ("M{ox1},{oy1} A{ro},{ro} 0 {lg} 1 {ox2},{oy2} "
            "L{ix2},{iy2} A{ri},{ri} 0 {lg} 0 {ix1},{iy1} Z").format(
        ox1=ox1, oy1=oy1, ox2=ox2, oy2=oy2, ix1=ix1, iy1=iy1, ix2=ix2, iy2=iy2,
        ro=R_OUTER, ri=R_INNER, lg=large)


def label_point(index, count):
    step = 360.0 / count
    mid = -90.0 + step * index + step / 2
    return point(R_LABEL, mid)


def js_string(value):
    return "'" + value.replace("\\", "\\\\").replace("'", "\\'") + "'"


def main():
    wheel = json.load(io.open(WHEEL, encoding="utf-8"))
    families = wheel["families"]
    count = len(families)

    entries = []
    for i, family in enumerate(families):
        lx, ly = label_point(i, count)
        items = ", ".join(js_string(d["label"]) for d in family["descriptors"])
        entries.append(
            "      { name: %s, path: '%s',\n"
            "        lx: %s, ly: %s,\n"
            "        items: [%s] }"
            % (js_string(family["label"]), segment_path(i, count), lx, ly, items))
    families_js = "    var FAMILIES = [\n" + ",\n".join(entries) + "\n    ];"

    # Labels get tighter as the family count rises.
    label_size = 13 if count <= 8 else (12 if count <= 10 else 11)

    html = TEMPLATE.replace("__FAMILIES__", families_js) \
                   .replace("__LABEL_SIZE__", str(label_size))
    io.open(OUT, "w", encoding="utf-8").write(html)

    total = sum(len(f["descriptors"]) for f in families)
    print("wrote FlavourWheel.dc.html: %d families, %d descriptors" % (count, total))


TEMPLATE = r"""<!doctype html>
<html>
<head>
  <meta charset="utf-8">
  <script src="./support.js"></script>
</head>
<body>
<x-dc>
<helmet>
  <link rel="stylesheet" href="https://fonts.googleapis.com/css2?family=Newsreader:opsz,wght@6..72,400;6..72,500;6..72,600&family=Public+Sans:wght@400;500;600;700&family=Spline+Sans+Mono:wght@400;500&display=swap">
  <style>
    :root{
      --bg:#15100a; --surface:#1e1710; --surface2:#2a2016; --line:#3a2d1e;
      --text:#f2e9db; --dim:#c0b19a; --faint:#968771;
      --gold:#c9973a; --gold-soft:#e2b661; --on-gold:#1a1309;
    }
    *{box-sizing:border-box}
    body{margin:0;background:var(--bg);color:var(--text);
      font:400 16px/1.5 "Public Sans","Helvetica Neue",Arial,sans-serif;-webkit-font-smoothing:antialiased}
    a{color:var(--gold)} a:hover{opacity:.82}
    .sc{width:390px;min-height:844px;background:var(--bg);display:flex;flex-direction:column}
    .dim{color:var(--dim)} .faint{color:var(--faint)} .gold{color:var(--gold)}
    .lab{font-size:12px;letter-spacing:.09em;text-transform:uppercase;font-weight:700;color:var(--dim)}
    .status{display:flex;justify-content:space-between;align-items:center;padding:14px 20px 0;
      font-size:13px;font-weight:600}
    .nav{display:flex;align-items:center;justify-content:space-between;gap:12px;padding:10px 18px 4px}
    .navbtn{min-width:44px;min-height:44px;display:flex;align-items:center;color:var(--dim)}
    .seg{display:flex;gap:5px;background:var(--surface2);padding:5px;border-radius:12px}
    .segi{flex:1;min-height:46px;display:flex;flex-direction:column;align-items:center;
      justify-content:center;border-radius:9px;font-size:14px;cursor:pointer;line-height:1.15}
    .chips{display:flex;flex-wrap:wrap;gap:8px}
    .chip{display:inline-flex;align-items:center;min-height:44px;padding:9px 14px;border-radius:9px;
      font-size:15px;cursor:pointer}
    .btn{display:flex;align-items:center;justify-content:center;min-height:50px;border-radius:11px;
      background:var(--gold);color:var(--on-gold);font-weight:700;font-size:16px}
    .seg-row{display:flex;gap:12px;padding:12px 0;border-bottom:1px solid var(--line)}
  </style>
</helmet>

<div class="sc">

  <div class="status"><span>9:41</span>
    <span style="display:flex;gap:6px;align-items:center">
      <svg width="17" height="11" viewBox="0 0 18 12" fill="currentColor"><rect x="0" y="8" width="3" height="4" rx="1"></rect><rect x="5" y="5.5" width="3" height="6.5" rx="1"></rect><rect x="10" y="3" width="3" height="9" rx="1"></rect><rect x="15" y="0" width="3" height="12" rx="1"></rect></svg>
      <svg width="24" height="12" viewBox="0 0 26 12" fill="none"><rect x="0.6" y="0.6" width="21" height="10.8" rx="3" stroke="currentColor" stroke-opacity=".5"></rect><rect x="2.4" y="2.4" width="15" height="7.2" rx="1.6" fill="currentColor"></rect></svg>
    </span>
  </div>

  <div class="nav">
    <div class="navbtn">
      <svg width="22" height="22" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.9" stroke-linecap="round" stroke-linejoin="round"><path d="M15 5l-7 7 7 7"></path></svg>
    </div>
    <div class="lab" style="letter-spacing:.06em">Bourbon flavour wheel</div>
    <div class="navbtn" style="justify-content:flex-end;color:var(--gold);font-weight:700;font-size:16px">Done</div>
  </div>

  <div style="padding:6px 20px 0">
    <div class="lab" style="margin-bottom:9px">Adding to</div>
    <div class="seg">
      <sc-for list="{{stages}}" as="s" hint-placeholder-count="4">
        <div class="segi" style="{{s.style}}" onClick="{{s.pick}}">
          <span>{{s.label}}</span>
          <span style="font-size:12px;opacity:.75">{{s.count}}</span>
        </div>
      </sc-for>
    </div>
  </div>

  <div style="display:flex;justify-content:center;padding:16px 20px 0">
    <svg width="300" height="300" viewBox="0 0 300 300" role="img" aria-label="Bourbon flavour wheel">
      <g stroke="#15100a" stroke-width="2">
        <sc-for list="{{families}}" as="f" hint-placeholder-count="10">
          <path d="{{f.path}}" fill="{{f.fill}}" onClick="{{f.pick}}" style="cursor:pointer"></path>
        </sc-for>
      </g>
      <g font-family="Public Sans, Helvetica, Arial, sans-serif" font-size="__LABEL_SIZE__" text-anchor="middle" dominant-baseline="middle">
        <sc-for list="{{families}}" as="f" hint-placeholder-count="10">
          <text x="{{f.lx}}" y="{{f.ly}}" fill="{{f.textFill}}" font-weight="{{f.weight}}" onClick="{{f.pick}}" style="cursor:pointer">{{f.name}}</text>
        </sc-for>
      </g>
      <circle cx="150" cy="150" r="59" fill="#1e1710" stroke="#3a2d1e"></circle>
      <text x="150" y="139" text-anchor="middle" font-family="Public Sans, Helvetica, Arial, sans-serif" font-size="12" letter-spacing="1.5" fill="#968771">{{stageUpper}}</text>
      <text x="150" y="171" text-anchor="middle" font-family="Newsreader, Georgia, serif" font-size="28" font-weight="600" fill="#c9973a">{{stageCount}}</text>
    </svg>
  </div>

  <div style="padding:14px 20px 0">
    <div style="display:flex;justify-content:space-between;align-items:baseline;margin-bottom:11px">
      <span class="lab">{{famName}}</span>
      <span class="faint" style="font-size:13px">Tap to add to the {{stageLower}}</span>
    </div>
    <div class="chips">
      <sc-for list="{{items}}" as="d" hint-placeholder-count="8">
        <span class="chip" style="{{d.style}}" onClick="{{d.toggle}}">{{d.name}}</span>
      </sc-for>
    </div>
  </div>

  <div style="padding:24px 20px 0">
    <div class="lab" style="margin-bottom:2px">On this tasting</div>
    <sc-for list="{{rows}}" as="r" hint-placeholder-count="4">
      <div class="seg-row">
        <span class="lab" style="width:56px;flex:none">{{r.label}}</span>
        <span style="font-size:15px;flex:1;color:{{r.color}}">{{r.text}}</span>
      </div>
    </sc-for>
  </div>

  <div style="padding:22px 20px 30px;margin-top:auto">
    <div class="btn">Save {{total}} descriptors</div>
  </div>

</div>
</x-dc>

<script data-dc-script data-props='{"$preview":{"width":390,"height":1120}}'>
class Component extends DCLogic {
  constructor(props) {
    super(props);
    // Seeded with the picks the tasting sheet already shows, so the two
    // screens tell one story.
    this.state = {
      stage: 'nose',
      family: 1,
      picks: {
        nose: ['Caramel', 'Vanilla', 'Charred oak'],
        entry: ['Brown sugar', 'Baking spice'],
        mid: ['Dried fig'],
        finish: ['Rye spice']
      }
    };
  }

  renderVals() {
    var self = this;
    var st = this.state;

    // GENERATED from shared/data/flavor-wheel.v1.json by design/build_wheel.py.
    // Do not hand-edit: the artboard and the data must not drift.
__FAMILIES__

    var STAGES = [
      { key: 'nose', label: 'Nose' },
      { key: 'entry', label: 'Entry' },
      { key: 'mid', label: 'Mid' },
      { key: 'finish', label: 'Finish' }
    ];

    var current = st.picks[st.stage] || [];
    var active = STAGES.filter(function (s) { return s.key === st.stage; })[0] || STAGES[0];

    var stages = STAGES.map(function (s) {
      var on = s.key === st.stage;
      return {
        label: s.label,
        count: (st.picks[s.key] || []).length,
        style: on
          ? 'background:var(--gold);color:var(--on-gold);font-weight:700'
          : 'background:transparent;color:var(--dim);font-weight:500',
        pick: function () { self.setState({ stage: s.key }); }
      };
    });

    var families = FAMILIES.map(function (f, i) {
      var on = i === st.family;
      return {
        name: f.name, path: f.path, lx: f.lx, ly: f.ly,
        fill: on ? '#c9973a' : '#2a2016',
        textFill: on ? '#1a1309' : '#c0b19a',
        weight: on ? '700' : '600',
        pick: function () { self.setState({ family: i }); }
      };
    });

    var fam = FAMILIES[st.family];
    var items = fam.items.map(function (name) {
      var on = current.indexOf(name) >= 0;
      return {
        name: name,
        style: on
          ? 'background:var(--surface);color:var(--gold);border:1px solid var(--gold);font-weight:600'
          : 'background:var(--surface2);color:var(--dim);border:1px solid transparent',
        toggle: function () {
          var picks = {};
          for (var k in st.picks) { picks[k] = st.picks[k].slice(); }
          var list = picks[st.stage] || [];
          var at = list.indexOf(name);
          if (at >= 0) { list.splice(at, 1); } else { list.push(name); }
          picks[st.stage] = list;
          self.setState({ picks: picks });
        }
      };
    });

    var rows = STAGES.map(function (s) {
      var list = st.picks[s.key] || [];
      return {
        label: s.label,
        text: list.length ? list.join(', ') : 'Nothing yet',
        color: list.length ? 'var(--text)' : 'var(--faint)'
      };
    });

    var total = STAGES.reduce(function (n, s) { return n + (st.picks[s.key] || []).length; }, 0);

    return {
      stages: stages,
      families: families,
      items: items,
      rows: rows,
      famName: fam.name,
      total: total,
      stageCount: current.length,
      stageUpper: active.label.toUpperCase(),
      stageLower: active.label.toLowerCase()
    };
  }
}
</script>
</body>
</html>
"""


if __name__ == "__main__":
    main()
