# NeoMundi AI Weather

**Measure once. Publish everywhere.**

An open-source embed kit for runtime AI behavioral observation. One daily
measurement source, published as a full observation wall and as several
lightweight embeddable widgets — all reading the same data.

**This is not a leaderboard.** It does not rank AI systems, determine
which one is "best", or judge whether individual responses are true or
false. Every view shows an *observed condition*, not a competitive score.

For micro-widgets specifically: **color is the signal. Provider and model
are the identity. Everything else belongs to the detail** (the full wall,
one click away).

---

## Branding

Public product name: **AI Weather by ControlTowerAI**. NeoMundi is the
underlying measurement layer, credited as a discreet secondary signature
(`NeoMundi measurement` / `Powered by NeoMundi`), never competing with
the primary brand in small formats.

Visual priority: **1. AI Weather → 2. ControlTowerAI → 3. NeoMundi**
(secondary signature).

All public link destinations are centralized in `config/wording.json →
links` — never hardcoded per component:

```json
{
  "links": {
    "methodology_url": "https://neomundi.org/methodology",
    "controltower_home": "https://controltowerai.io/",
    "full_weather_url": "./index.html"
  }
}
```

`topbar.html` and `sidebar.html` link their brand mark to
`controltower_home`; each provider links to `full_weather_url` deep-linked
to that system. Changing `controltowerai.io` later means editing one
value in this one file.

---

## Repository structure

```text
/
├── index.html              Full Observation Wall (12 systems, click for detail)
├── core-panel.html          Core Panel — 8 major global providers (compact, controltowerai.io)
├── widget.html              Compact global-condition widget
├── topbar.html               Horizontal Topbar — Core 8 providers only
├── sidebar.html               Vertical Sidebar — Core 8 providers only
├── provider-widget.html        Single-system widget (generic, ?system=)
├── embed-demo.html              Integration Gallery — every format, theme, language
├── demo.html                     Standalone snapshot (data inlined, works via file://)
│
├── assets/
│   ├── logo-controltower.png       real ControlTower mark, used everywhere
│   └── partners/
│       └── README.md                 where to drop partner logos (e.g. Infomaniak)
│
├── config/
│   ├── panel.yml            observed panel definition (source for weather.json)
│   ├── panels.json           panel VIEW definitions: which system ids belong to
│   │                           "core" (8 providers) vs "full" (12 systems) — one
│   │                           dataset, multiple public views, no duplication
│   ├── wording.json          non-translatable config: brand name, links, partner logo path
│   └── languages.json         which languages are available
│
├── i18n/
│   ├── en.json    fr.json    de.json    es.json    it.json
│
├── styles/
│   ├── themes.css        theme definitions (CSS custom properties)
│   └── base.css            shared styles for topbar/sidebar/provider-widget
│
├── scripts/
│   ├── weather-data.js     shared data access (fetch weather.json once, resolve ?system=)
│   ├── i18n.js               language loader, detection, fallback
│   ├── themes.js              theme loader (?theme= → data-theme attribute)
│   └── launcher/README.md      placeholder docs for the future daily measurement launcher
│
├── data/
│   ├── current.json      mirrors weather.json
│   └── history/             dated snapshots
│
├── weather.json         current measurement — the single source of truth
├── manifest.json / service-worker.js / icons-*.png    PWA (installable wall)
└── README.md            this file
```

This is a minimal migration from the previous single-page structure —
nothing that already worked was reorganized without reason.

---

## Architecture

```text
              measurement pipeline (future launcher)
                            │
                            ▼
                     weather.json
     (semantic ids only: "clear" / "variable" / "disrupted" — never
      translated text, never a rendered label)
                            │
        ┌───────────┬───────┴───────┬────────────────┐
        │           │               │                │
   index.html   topbar.html    sidebar.html   provider-widget.html
   Full Wall    Horizontal      Vertical         Single system
                   Bar           Panel

  All four read weather.json through scripts/weather-data.js.
  All four translate through scripts/i18n.js + i18n/*.json.
  All four theme through scripts/themes.js + styles/themes.css.
```

**Separation of responsibilities**, strictly:

| Layer | Lives in | Changes when |
|---|---|---|
| Measurement data | `weather.json` | daily, by the launcher |
| Interpretation vocabulary | `weather.json` condition ids (`clear`/`variable`/`disrupted`) | rarely, a scientific/threshold decision |
| Translations | `i18n/*.json` | a new language is added, or wording is refined |
| Themes | `styles/themes.css` | a new partner surface is needed |
| Presentation format | `index.html` / `topbar.html` / `sidebar.html` / `provider-widget.html` | a new integration format is needed |

None of these layers can break another. `weather.json` never contains
rendered text — only stable ids like `"condition": "clear"`.

---

## Formats

### Full Observation Wall — `index.html`

The complete page. 12 systems, minimal cards (condition + simple reading
+ provider + model, no score), click for full metrology detail. Includes
the language selector. Installable as a PWA.

### Global Widget — `widget.html`

Compact card showing only the aggregate global condition — for a simple
"how's AI behaving today" badge.

```html
<iframe src="widget.html?theme=light&lang=en" width="380" height="220" loading="lazy" title="NeoMundi AI Weather"></iframe>
```

### Horizontal Topbar — `topbar.html`

Shows exactly the **Core Panel's 8 providers** — the same
`config/panels.json → panels.core` list used by `core-panel.html`. Not a
separate provider list: change the 8 providers in one place and the
topbar updates automatically.

Maximum signal, minimum interface: `AI Weather · ControlTowerAI` followed
immediately by 8 color dots + provider names. No score, no CLEAR/VARIABLE
label text, no other wording. One line on desktop; scrolls horizontally
on narrow viewports without breaking layout. Target height 64–80px.

```html
<iframe src="topbar.html?theme=light&lang=en" width="100%" height="80" loading="lazy" title="AI Weather by ControlTowerAI"></iframe>
```

### Vertical Sidebar — `sidebar.html`

Same Core 8 providers, stacked vertically. Just a two-line brand header
(`AI Weather` / `by ControlTowerAI`), the 8 providers, and a discreet
`NeoMundi measurement` attribution at the bottom — no subtitle, no
methodology link, no metrics. Target width 280–320px, flexible height.

```html
<iframe src="sidebar.html?theme=light&lang=en" width="300" height="520" loading="lazy" title="AI Weather by ControlTowerAI"></iframe>
```

**Both read the same panel definition as the Core Panel** — see
[Core Panel](#core-panel--core-panelhtml) above. Editing
`config/panels.json → panels.core` updates the Core Panel, the topbar,
and the sidebar simultaneously; nothing is duplicated in their HTML/JS.

By default both show **provider only**, never an internal model
identifier — same `NMData.getPublicIdentity()` boundary described in the
desidentification section below. A system's `model_public`, if one is
explicitly set, could be surfaced later without any change to the
desidentification boundary itself.

### Individual Provider Widget — `provider-widget.html`

One generic component serving all 12 systems — no per-provider HTML
files. Selects the system from the URL:

```text
provider-widget.html?system=infomaniak-euria
provider-widget.html?provider=Infomaniak
```

`system` (a stable id) is preferred over `provider` (a free-text name),
because a provider may eventually have more than one observed model —
`system=infomaniak-euria` stays unambiguous where `provider=Infomaniak`
would not. `provider` is kept as a convenience fallback.

Shows color, provider, model — nothing else. Clicking it opens the full
wall, deep-linked to that system (`index.html?system=infomaniak-euria`),
where the card is highlighted and its detail opens automatically.

```html
<iframe src="provider-widget.html?system=infomaniak-euria&theme=light&lang=en" width="300" height="120" loading="lazy" title="NeoMundi AI Weather — Infomaniak Euria"></iframe>
```

### Core Panel — `core-panel.html`

A more compact public showcase than the Full Wall, built for
**controltowerai.io**: 8 major global AI providers instead of 12
systems.

```text
FULL AI WEATHER WALL          CONTROLTOWER CORE PANEL
12 systems                    8 major providers
→ complete observation        → compact global readability
```

Both views read the **same** `weather.json` — nothing is duplicated.
`config/panels.json` defines which system ids belong to which view:

```json
{
  "panels": {
    "core": ["openai", "anthropic", "google", "xai", "mistral", "deepseek", "qwen", "moonshot"],
    "full": ["openai", "infomaniak-euria", "anthropic", "google", "xai", "mistral", "deepseek", "qwen", "moonshot", "system-j", "system-k", "system-l"]
  }
}
```

`index.html` (Full Wall) and `core-panel.html` both resolve their system
list through `NMData.getPanelSystems(data, panelIds)` — one function,
two configurations, zero hardcoded system lists in either page's HTML.

**Changing the 8 core providers later:** edit the `core` array in
`config/panels.json` (the ids must already exist in `weather.json`). No
HTML or JS change required in `core-panel.html`, `index.html`, or
anywhere else.

```html
<iframe src="core-panel.html?theme=light&lang=en" width="100%" height="520" loading="lazy" title="NeoMundi AI Weather — Core Provider Panel"></iframe>
```

#### Desidentification

The Core Panel shows provider + condition color only — never a specific
internal model identifier. This is enforced at the **data layer**, not
by hiding a field with CSS:

```json
{
  "id": "openai",
  "provider": "OpenAI",
  "provider_display": "OpenAI",
  "model": "openai-model-placeholder",
  "model_public": null,
  "public_label": "SYSTEM-01"
}
```

`scripts/weather-data.js` exposes `NMData.getPublicIdentity(system)`,
which only ever reads `provider_display`/`provider` and
`model_public`/`public_label` — it never touches `system.model`. A
public-facing page that uses this helper structurally cannot leak an
internal field by accident, even if one is added to `weather.json` later.
Systems with `model_public` set (e.g. `infomaniak-euria`) show that value
instead of a `public_label` — desidentification is per-system, not
global.

The Full Wall, `provider-widget.html`, `topbar.html`, and `sidebar.html`
are unaffected — they still read `system.model` directly, as before.



Live demonstration of every format above, every theme, and three
languages side by side, plus copyable iframe snippets. This is also
where a future "Embed Documentation" page can grow from.

---

## Themes

Set via `?theme=`. Default: `light`.

| Theme | Description |
|---|---|
| `light` | White background, dark text |
| `dark` | Dark background, light text |
| `slate` | Neutral grey-blue, enterprise-leaning |
| `warm` | Warm off-white, editorial feel |
| `transparent` | Transparent background, for embedding inside a partner's own design |

Condition colors (`--nm-clear` green, `--nm-variable` orange,
`--nm-disrupted` red) are defined once in `styles/themes.css` and never
change between themes — a color's meaning must stay constant regardless
of which partner is embedding the widget.

**Adding a theme:** add a `[data-theme="yourtheme"] { --nm-bg: ...; --nm-card-bg: ...; --nm-text: ...; --nm-muted: ...; --nm-border: ...; }` block to `styles/themes.css`, then add `"yourtheme"` to the `AVAILABLE` list in `scripts/themes.js`. No other file changes needed.

---

## Languages

Set via `?lang=`. Available today: `en` (default), `fr`, `de`, `es`, `it`.

Resolution order:

1. `?lang=xx` if present;
2. otherwise, browser language;
3. if that language isn't available, fall back to English;
4. if a specific key is missing from a translation file, fall back to
   English for that key only — never a visibly broken string.

**Adding a language:** create `i18n/<code>.json` with the same keys as
`i18n/en.json`, then add `{ "code": "<code>", "label": "..." }` to
`config/languages.json`. No JS/HTML changes needed — the language
selector on the full wall and every widget's `?lang=` support pick it up
automatically.

The full wall's language selector (`EN ▾`) is intentionally not shown on
the small embeddable widgets — they simply honor `?lang=` from the
embedding page.

---

## Query parameters

| Parameter | Used by | Values |
|---|---|---|
| `system` | provider-widget, deep links | stable system id, e.g. `infomaniak-euria` |
| `provider` | provider-widget (fallback) | provider name, case-insensitive |
| `theme` | every widget + wall | `light` · `dark` · `slate` · `warm` · `transparent` |
| `lang` | every widget + wall | `en` · `fr` · `de` · `es` · `it` |

---

## Testing locally

```bash
python3 -m http.server 8000
```

```text
http://localhost:8000/index.html
http://localhost:8000/core-panel.html
http://localhost:8000/provider-widget.html?system=infomaniak-euria
http://localhost:8000/provider-widget.html?system=infomaniak-euria&theme=dark
http://localhost:8000/provider-widget.html?system=infomaniak-euria&theme=transparent&lang=fr
http://localhost:8000/topbar.html
http://localhost:8000/sidebar.html
http://localhost:8000/embed-demo.html
```

All data shown (`weather.json`, `data/current.json`,
`data/history/2026-08-16.json`) is **demonstration data**, marked
`"demo": true`. It must not be interpreted as a live measurement.

---

## Partner logos

Drop official partner logo files under `assets/partners/` (see
`assets/partners/README.md`). `index.html` probes at runtime whether the
configured file exists (`config/wording.json` → `partners.infomaniak_logo`)
and only shows the "Infrastructure partner" footer credit if it does — no
fabricated or remotely-fetched logo, no broken image, no implication that
a partner produces or validates NeoMundi's measurements.

---

## Panel configuration

The observed panel (12 systems) is declared in `config/panel.yml`, not in
code. Edit it and regenerate `weather.json` to change the panel — no
dashboard code changes needed. Current entries are still placeholders
except `infomaniak-euria`, used as the running example throughout this
kit; replace the rest with real provider/model identifiers before going
live.

---

## Measurement principle

AI Weather is a runtime measurement signal. It does not rank AI models,
determine whether individual outputs are true or false, replace
domain-specific evaluation, or act as a governance decision authority.

---

## Planned automation

A launcher (see `scripts/launcher/README.md`) will read `config/panel.yml`,
query each enabled system with the sentinel prompt set, send observations
through NeoMundi measurement, aggregate, update `weather.json` /
`data/current.json`, append a snapshot to `data/history/<date>.json`, and
let GitHub Pages refresh automatically. Everything in this kit already
reads through that same `weather.json` — connecting the launcher requires
no change to any widget.

---

## GitHub Pages

Fully static. No backend, no build step, no framework. Every file above
is served as-is. Nothing is committed automatically by this kit — review
and commit manually.

---

Powered by **NeoMundi — Runtime AI Metrology**
