# NeoMundi AI Weather

**Measure once. Publish everywhere.**

An open-source embed kit for runtime AI behavioral observation. One daily
measurement source, published as a full observation wall and as several
lightweight embeddable widgets — all reading the same data.

**This is not a leaderboard.** It does not rank AI systems, determine
which one is "best", or judge whether individual responses are true or
false. Every view shows an *observed condition*, not a competitive score.

For micro-widgets specifically: **color is the signal. The model is the
identity.** Everything else belongs to the detail (the full wall, one
click away).

> **2026-08-17 policy change, documented here for traceability:** the
> public identity shown across every format is now the **model's public
> brand name** (e.g. "ChatGPT", "Claude", "Gemini"), not the provider
> company name (e.g. "OpenAI", "Anthropic", "Google"). This reverses the
> previous desidentification design, where the Core Panel, Topbar and
> Sidebar showed the provider and hid the model. See
> [Public identity](#public-identity) below for the current rule.

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
`controltower_home`; each system links to `full_weather_url` deep-linked
to that system. Changing `controltowerai.io` later means editing one
value in this one file.

---

## Repository structure

```text
/
├── index.html              Full Observation Wall (12 systems, click for detail)
├── core-panel.html          Core Panel — 8 major global providers (compact, controltowerai.io)
├── widget.html              Compact global-condition widget
├── topbar.html               Horizontal Topbar — Core 8 systems only
├── sidebar.html               Vertical Sidebar — Core 8 systems only
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
│   ├── panel.yml            observed panel definition (source for weather.json) —
│   │                          also carries model_display (public brand name) and
│   │                          runner_provider (API-key routing, see AI_WEATHER_RUNNER)
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
│   └── weather-data.js     shared data access (fetch weather.json once, resolve
│                              ?system=, expose the public-identity boundary — see
│                              scripts/i18n.js and scripts/themes.js for the other two)
│
├── data/
│   ├── current.json      mirrors weather.json
│   └── history/             dated snapshots (data/history/<YYYY-MM-DD>.json)
│
├── weather.json                    current measurement — the single source of truth
│                                     (generated, never edited by hand)
├── aggregate_and_publish_weather.ps1  reads AI_WEATHER_RUNNER's daily results,
│                                        writes weather.json / data/current.json /
│                                        data/history, commits and pushes — see
│                                        QUICKSTART.md and METHODOLOGY_THRESHOLDS.md
├── manifest.json / service-worker.js / icons-*.png    PWA (installable wall)
└── README.md            this file
```

---

## Architecture

```text
        AI_WEATHER_RUNNER (daily measurement, PowerShell)
                            │
                            ▼
        aggregate_and_publish_weather.ps1
        (applies METHODOLOGY_THRESHOLDS.md, reads config/panel.yml)
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
                            │
                    core-panel.html
                     Core Panel (8)

  All formats read weather.json through scripts/weather-data.js.
  All formats translate through scripts/i18n.js + i18n/*.json.
  All formats theme through scripts/themes.js + styles/themes.css.
```

**Separation of responsibilities**, strictly:

| Layer | Lives in | Changes when |
|---|---|---|
| Measurement data | `weather.json` | daily, by `aggregate_and_publish_weather.ps1` |
| Interpretation vocabulary | `weather.json` condition ids (`clear`/`variable`/`disrupted`) | rarely, a scientific/threshold decision — see `METHODOLOGY_THRESHOLDS.md` |
| Public identity (model brand names) | `config/panel.yml` → `model_display` | a system's model changes, or a new system is added |
| Translations | `i18n/*.json` | a new language is added, or wording is refined |
| Themes | `styles/themes.css` | a new partner surface is needed |
| Presentation format | `index.html` / `core-panel.html` / `topbar.html` / `sidebar.html` / `provider-widget.html` | a new integration format is needed |

None of these layers can break another. `weather.json` never contains
rendered text — only stable ids like `"condition": "clear"`.

---

## Formats

### Full Observation Wall — `index.html`

The complete page. 12 systems, minimal cards (condition + simple reading
+ model, no score), click for full metrology detail. Includes the
language selector. Installable as a PWA.

### Global Widget — `widget.html`

Compact card showing only the aggregate global condition — for a simple
"how's AI behaving today" badge. No per-system identity at all.

```html
<iframe src="https://neomundi-io.github.io/neomundi-ai-weather/widget.html?theme=light&lang=en" width="380" height="220" loading="lazy" title="NeoMundi AI Weather"></iframe>
```

### Horizontal Topbar — `topbar.html`

Shows exactly the **Core Panel's 8 systems** — the same
`config/panels.json → panels.core` list used by `core-panel.html`. Not a
separate list: change the 8 systems in one place and the topbar updates
automatically.

Maximum signal, minimum interface: `AI Weather · ControlTowerAI` followed
immediately by 8 color dots + **model names**. No score, no
CLEAR/VARIABLE label text, no other wording. One line on desktop; scrolls
horizontally on narrow viewports without breaking layout. Target height
64–80px.

```html
<iframe src="https://neomundi-io.github.io/neomundi-ai-weather/topbar.html?theme=light&lang=en" width="100%" height="80" loading="lazy" title="AI Weather by ControlTowerAI"></iframe>
```

### Vertical Sidebar — `sidebar.html`

Same Core 8 systems, stacked vertically. Just a two-line brand header
(`AI Weather` / `by ControlTowerAI`), the 8 systems, and a discreet
`NeoMundi measurement` attribution at the bottom — no subtitle, no
methodology link, no metrics. Target width 280–320px, flexible height.

```html
<iframe src="https://neomundi-io.github.io/neomundi-ai-weather/sidebar.html?theme=light&lang=en" width="300" height="520" loading="lazy" title="AI Weather by ControlTowerAI"></iframe>
```

**Both read the same panel definition as the Core Panel** — see
[Core Panel](#core-panel--core-panelhtml) below. Editing
`config/panels.json → panels.core` updates the Core Panel, the topbar,
and the sidebar simultaneously; nothing is duplicated in their HTML/JS.

Both show the **model's public brand name only**, never the provider
company name — see [Public identity](#public-identity) below.

### Individual System Widget — `provider-widget.html`

One generic component serving all 12 systems — no per-system HTML files.
Selects the system from the URL:

```text
provider-widget.html?system=openai
provider-widget.html?provider=OpenAI
```

`system` (a stable id) is preferred over `provider` (a free-text name),
because a provider may eventually have more than one observed model —
`system=infomaniak` stays unambiguous where `provider=Infomaniak` would
not. `provider` is kept as a convenience fallback.

Shows color and the model's brand name — nothing else (the provider name
is kept in the link's `aria-label` for accessibility, never shown
visually). Clicking it opens the full wall, deep-linked to that system
(`index.html?system=openai`), where the card is highlighted and its
detail opens automatically.

```html
<iframe src="https://neomundi-io.github.io/neomundi-ai-weather/provider-widget.html?system=openai&theme=light&lang=en" width="300" height="120" loading="lazy" title="NeoMundi AI Weather — OpenAI"></iframe>
```

### Core Panel — `core-panel.html`

A more compact public showcase than the Full Wall, built for
**controltowerai.io**: 8 major global systems instead of 12.

```text
FULL AI WEATHER WALL          CONTROLTOWER CORE PANEL
12 systems                    8 major systems
→ complete observation        → compact global readability
```

Both views read the **same** `weather.json` — nothing is duplicated.
`config/panels.json` defines which system ids belong to which view:

```json
{
  "panels": {
    "core": ["openai", "anthropic", "google", "xai", "mistral", "deepseek", "qwen", "moonshot"],
    "full": ["openai", "anthropic", "google", "xai", "mistral", "deepseek", "qwen", "moonshot", "cohere", "meta", "infomaniak", "perplexity"]
  }
}
```

`index.html` (Full Wall) and `core-panel.html` both resolve their system
list through `NMData.getPanelSystems(data, panelIds)` — one function,
two configurations, zero hardcoded system lists in either page's HTML.

**Changing the 8 core systems later:** edit the `core` array in
`config/panels.json` (the ids must already exist in `weather.json`, i.e.
in `config/panel.yml`). No HTML or JS change required in
`core-panel.html`, `index.html`, or anywhere else.

**IDs must stay in sync between `config/panel.yml` and
`config/panels.json`.** If a system id changes in one, it must change in
the other, or that system silently disappears from every widget that
reads `panels.json` (no error is thrown — `getPanelSystems()` skips
unresolved ids on purpose, so a stale config never crashes a page, but it
also never warns you it's stale).

```html
<iframe src="https://neomundi-io.github.io/neomundi-ai-weather/core-panel.html?theme=light&lang=en" width="100%" height="520" loading="lazy" title="NeoMundi AI Weather — Core Provider Panel"></iframe>
```

#### Public identity

Every public-facing widget shows the **model's public brand name**,
never the provider company name. This is centralized at the **data
layer**, not per-component markup:

```json
{
  "id": "openai",
  "provider": "OpenAI",
  "provider_display": "OpenAI",
  "model": "gpt-4o-2024-11-20",
  "model_display": "ChatGPT",
  "model_public": null,
  "public_label": "SYSTEM-01"
}
```

`scripts/weather-data.js` exposes `NMData.getPublicIdentity(system)`,
which returns `{ provider, label }` — `label` is what every widget
renders as the visible identity, resolved as `model_display` (preferred)
→ `model_public` → `public_label` → the raw `model` id, in that order.
`provider` is still returned for `aria-label` / accessibility text and
for internal/admin surfaces, but **no public widget renders `provider` as
visible text** — a change to `getPublicIdentity()` is the only place this
rule needs to be enforced.

`config/panel.yml → model_display` is the field to edit for a system's
public brand name (e.g. "ChatGPT", "Claude", "NVIDIA" for the Infomaniak-
hosted Nemotron model). No dashboard code changes needed.

The Full Wall (`index.html`) and `provider-widget.html` follow the same
rule as the Core Panel, Topbar and Sidebar — there is now a single public
identity policy across every format, not two different ones.

### Integration Gallery — `embed-demo.html`

Live demonstration of every format above, every theme, and multiple
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
| `system` | provider-widget, deep links | stable system id, e.g. `openai`, `infomaniak` |
| `provider` | provider-widget (fallback) | provider name, case-insensitive |
| `theme` | every widget + wall | `light` · `dark` · `slate` · `warm` · `transparent` |
| `lang` | every widget + wall | `en` · `fr` · `de` · `es` · `it` |

---

## Embedding — absolute URLs required

Every iframe `src` in this document uses the full GitHub Pages URL
(`https://neomundi-io.github.io/neomundi-ai-weather/...`), not a relative
path. A relative path (`widget.html?...`) only works when the embedding
page is served from the same origin as this repo — everywhere else
(WordPress, Notion, a partner's own site), it resolves against *their*
domain and fails silently or loads nothing. Always use the absolute URL
when embedding outside this repo's own pages.

---

## Testing locally

```bash
python3 -m http.server 8000
```

```text
http://localhost:8000/index.html
http://localhost:8000/core-panel.html
http://localhost:8000/provider-widget.html?system=openai
http://localhost:8000/provider-widget.html?system=openai&theme=dark
http://localhost:8000/provider-widget.html?system=openai&theme=transparent&lang=fr
http://localhost:8000/topbar.html
http://localhost:8000/sidebar.html
http://localhost:8000/embed-demo.html
```

Before the first real measurement is published, `weather.json` is
**demonstration data**, marked `"demo": true` — not to be interpreted as
a live measurement. `aggregate_and_publish_weather.ps1` sets `"demo":
false` on every real run.

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

The observed panel (12 systems) is declared in `config/panel.yml` — the
single editable source. Fields: `id`, `provider`, `model_id`,
`model_display` (public brand name, see
[Public identity](#public-identity)), `runner_provider` (the API-key
routing value used by `AI_WEATHER_RUNNER\run_weather_*.ps1` — not always
identical to `provider`, e.g. the `meta` system is queried through
Together AI's API), `display_name` (internal admin label), `public_label`
(legacy desidentified label, superseded by `model_display` but kept for
fallback), `enabled`.

Editing this file and re-running `aggregate_and_publish_weather.ps1`
regenerates `weather.json` — no dashboard code changes needed. **If a
system id changes here, update `config/panels.json` too** (see
[Core Panel](#core-panel--core-panelhtml)).

All 12 entries carry real, currently-observed model identifiers as of
2026-08-17 — no placeholders remain.

---

## Measurement principle

AI Weather is a runtime measurement signal. It does not rank AI models,
determine whether individual outputs are true or false, replace
domain-specific evaluation, or act as a governance decision authority.

Score and condition thresholds (`clear` / `variable` / `disrupted`) are a
documented, versioned policy decision — see `METHODOLOGY_THRESHOLDS.md`.
Never change a threshold directly in `aggregate_and_publish_weather.ps1`
without updating that document first.

---

## Daily measurement pipeline

The daily pipeline is in place and documented step by step in
`QUICKSTART.md`. Summary:

```text
AI_WEATHER_RUNNER\launch_ai_weather.ps1
        (12 systems, results\<date>\*.jsonl)
                    │
                    ▼
    aggregate_and_publish_weather.ps1
   (applies METHODOLOGY_THRESHOLDS.md, config\panel.yml)
                    │
                    ▼
  weather.json / data/current.json / data/history/<date>.json
              committed and pushed
                    │
                    ▼
       GitHub Pages refreshes automatically
```

A run that produces incomplete or suspicious data (fewer than 12 systems,
several systems on carried-forward stale data, malformed output) is
**not published automatically** — `aggregate_and_publish_weather.ps1`
writes `weather.json` locally for inspection but skips the commit/push,
and prints why. See `QUICKSTART.md` for the recovery procedure.

---

## GitHub Pages

Fully static. No backend, no build step, no framework. Every file above
is served as-is. Commits from `aggregate_and_publish_weather.ps1` are the
only automated commits in this repo — review its output if anything
looks wrong on the public wall.

---

Powered by **NeoMundi — Runtime AI Metrology**
