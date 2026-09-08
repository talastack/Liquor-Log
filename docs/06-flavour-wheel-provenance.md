# 6. The flavour wheel: provenance and independent derivation

**Not legal advice.** This document exists to make one claim defensible: that
`shared/data/flavor-wheel.v1.json` is our own work, derived from facts, and not
a copy of anybody's published diagram.

Keep it current. A provenance record written *before* the data is far more
valuable than one reconstructed afterwards.

---

## 1. What is and is not protectable

| | Status | Why |
|---|---|---|
| Individual descriptors — *caramel, charred oak, dried fig* | **Free** | Ordinary English words for tastes. Used independently by every taster, every distiller, every reviewer. Nobody owns the word for a smell. |
| Top-level family names — *Sweet, Fruit, Spice, Wood* | **Effectively free** | There are only so many ways to name a category of tastes. Where expression is that constrained it merges with the idea, and the obvious generic label is not protectable. |
| A published wheel's **hierarchy and arrangement** | **Protected** | Selection and arrangement is precisely what compilation copyright covers. This is the part that must be ours. |
| A published wheel's **visual design** | **Protected** | Colours, ring structure, typography, layout. |

The consequence: we may use the whole standard sensory vocabulary. We may not
reproduce somebody's particular tree of it.

---

## 2. Our organising principle: origin, not resemblance

Every published whisky wheel we are aware of groups descriptors by **sensory
resemblance** — things that smell alike sit together. That is one reasonable
arrangement, and it is theirs.

Ours groups by **where the flavour comes from**. Each descriptor carries an
`origin`:

| Origin | Means |
|---|---|
| `grain` | From the mashbill itself — corn sweetness, rye spice, malt |
| `fermentation` | Made by yeast — esters, the fruit and floral notes |
| `distillation` | Carried or created in the still — congeners, some vegetal notes |
| `maturation` | From the barrel — vanillin, lactones, tannin, char |
| `oxidation` | Appears with air and time, in the bottle |
| `fault` | Something went wrong |

This is not decoration. It is:

- **Independently derived.** Origin is a chemical and process fact, not an
  aesthetic judgement. Two people working from the chemistry arrive at the same
  grouping; that is the opposite of copying an arrangement.
- **Genuinely more useful.** "Vanilla comes from the barrel, rye spice comes
  from the grain" teaches a taster something. A resemblance wheel cannot.
- **Load-bearing elsewhere.** `OxidationBand` already reasons about what fades
  in an open bottle. Descriptors tagged `oxidation` are exactly the ones that
  arrive as a bottle ages, and `maturation` notes are the ones that flatten.

Families remain the familiar generic ones, so the picker feels like every wheel
a bourbon drinker has used. The **structure underneath them is ours.**

---

## 3. The factual basis for each grouping

Where a descriptor has a well-established chemical origin, the entry records the
compound. Chemistry is fact and cannot be owned, and stating it is the clearest
possible evidence of independent derivation.

Representative examples, all long-established in flavour chemistry:

| Descriptor | Compound | Origin |
|---|---|---|
| Vanilla | vanillin | Oak lignin breaking down under char |
| Coconut | whisky lactone (oak lactone) | Oak, more pronounced in American oak |
| Almond, marzipan | furfural | Sugar degradation during toasting |
| Smoke, medicinal | guaiacol | Lignin pyrolysis |
| Clove | eugenol | Oak |
| Banana | isoamyl acetate | Fermentation ester |
| Butter | diacetyl | Fermentation |
| Nail polish, solvent | ethyl acetate at high concentration | Fermentation; a fault above threshold |
| Green apple | acetaldehyde | Oxidation |
| Wet cardboard | trans-2-nonenal | Staling, chiefly a beer fault |

**Owed:** each compound attribution should carry a citation to a published
source before launch. They are stated here from general flavour-chemistry
knowledge and are believed correct, but "believed correct" is not a citation.
The app does not currently show compound names to users, so this is a
credibility debt rather than a correctness risk — do not surface them in the UI
until they are cited.

---

## 4. What we deliberately did not do

- **Did not open, transcribe or reference any published wheel** while building
  the taxonomy. The descriptor list was assembled from the vocabulary in common
  use; the grouping was derived from origin as described above.
- **Did not copy any wheel's visual design.** The picker's ring structure,
  colours and type come from our own design system.
- **Did not use the SWRI wheel, the Charles MacLean wheel, or any brand's
  proprietary tasting framework** as a source or a template.
- **Did not copy BJCP or Brewers Association guideline text** for the beer side.
  Style names are generic; their text and numeric ranges are not ours.

---

## 5. If somebody claims otherwise

The defence is independent creation, and it rests on things in this repository:

1. **This document**, written before the data.
2. **`shared/data/flavor-wheel.v1.json`**, whose every entry carries an `origin`
   and, where known, a `compound` — a structure no published wheel uses.
3. **Git history**, showing the taxonomy assembled here rather than imported.
4. **The generic-family argument**, which covers the only part that resembles
   convention.

Keep all four. Do not "tidy" the origin field out of the data because the UI
does not show it yet — it is the evidence.

---

## 6. Rules for anyone extending it

1. **Add descriptors freely.** Ordinary tasting words are free, and a wheel that
   cannot express what somebody smelled is a wheel they stop using.
2. **Every new descriptor gets an `origin`.** If you cannot say where it comes
   from, you do not understand it well enough to add it.
3. **Never import a hierarchy.** If a published wheel groups something
   surprisingly, that surprise is the protected part. Work it out from origin.
4. **Never add a compound you cannot cite.** A wrong chemical claim is worse
   than none, and this file is our evidence of care.
