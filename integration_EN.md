# AI Weather — Integration Guide

**Everything needed to embed a widget anywhere: the exact snippet, ready
to copy, nothing to guess.**

Reference domain: `https://neomundi-io.github.io/neomundi-ai-weather/`
— always the absolute URL (never relative) outside this repo's own pages.

---

## Overview — which format for which use

| Format | File | Use case | Default size | Placement |
|---|---|---|---|---|
| Full wall | `index.html` | Dedicated page, exhaustive view | `100%` × `900` | Inline, in the page flow |
| Core Panel | `core-panel.html` | Compact showcase for controltowerai.io (8 systems) | `100%` × `520` | Inline |
| Global badge | `widget.html` | "How's AI behaving today" at a glance | `380` × `220` | Inline or floating |
| Horizontal bar | `topbar.html` | Banner at the top of a page, 8 systems | `100%` × `80` | Inline |
| Vertical bar | `sidebar.html` | Side column, 8 systems | `300` × `520` | Inline |
| Individual widget | `provider-widget.html` | A single system, discreet badge | `300` × `120` (reducible to `150` × `90`) | Inline or floating |

**Inline** = embedded normally in an HTML block, scrolls with the page.
**Floating** = stays fixed at a screen corner even while scrolling (see
dedicated section below — mainly relevant to the individual widget).

---

## 1. Full wall — `index.html`

All 12 systems, click-through detail card, language selector included.

```html
<iframe src="https://neomundi-io.github.io/neomundi-ai-weather/index.html?theme=light&lang=en" width="100%" height="900" loading="lazy" title="NeoMundi AI Weather — Full Observation Wall"></iframe>
```

---

## 2. Core Panel — `core-panel.html`

8 major systems (4 US + Mistral + 3 Chinese), compact view.

```html
<iframe src="https://neomundi-io.github.io/neomundi-ai-weather/core-panel.html?theme=light&lang=en" width="100%" height="520" loading="lazy" title="NeoMundi AI Weather — Core Provider Panel"></iframe>
```

---

## 3. Global badge — `widget.html`

A single aggregate condition, no per-system detail.

```html
<iframe src="https://neomundi-io.github.io/neomundi-ai-weather/widget.html?theme=light&lang=en" width="380" height="220" loading="lazy" title="NeoMundi AI Weather"></iframe>
```

---

## 4. Horizontal bar — `topbar.html`

```html
<iframe src="https://neomundi-io.github.io/neomundi-ai-weather/topbar.html?theme=light&lang=en" width="100%" height="80" loading="lazy" title="AI Weather by ControlTowerAI"></iframe>
```

---

## 5. Vertical bar — `sidebar.html`

```html
<iframe src="https://neomundi-io.github.io/neomundi-ai-weather/sidebar.html?theme=light&lang=en" width="300" height="520" loading="lazy" title="AI Weather by ControlTowerAI"></iframe>
```

---

## 6. Individual widget — `provider-widget.html`

A single system, the most compact format. Swap `system=` for the id you
want (full table below).

**Standard size:**
```html
<iframe src="https://neomundi-io.github.io/neomundi-ai-weather/provider-widget.html?system=openai&theme=light&lang=en" width="300" height="120" loading="lazy" title="NeoMundi AI Weather — OpenAI"></iframe>
```

**Reduced size (recommended minimum — below this, content gets cramped):**
```html
<iframe src="https://neomundi-io.github.io/neomundi-ai-weather/provider-widget.html?system=openai&theme=light&lang=en" width="150" height="90" loading="lazy" title="NeoMundi AI Weather — OpenAI"></iframe>
```

### The 12 available ids

| id | Model shown |
|---|---|
| `openai` | ChatGPT |
| `anthropic` | Claude |
| `google` | Gemini |
| `xai` | Grok |
| `mistral` | Mistral |
| `deepseek` | DeepSeek |
| `qwen` | Qwen |
| `moonshot` | Kimi |
| `cohere` | Command |
| `meta` | Llama |
| `infomaniak` | NVIDIA |
| `perplexity` | Perplexity |

---

## Floating widget (fixed screen position, stays put while scrolling)

Default below: **top-left corner**. To change it, replace the `style="..."`
block on the `<div>` with one of the variants right after — nothing else
needs to change.

**Top-left (default):**
```html
<div style="position: fixed; top: 20px; left: 20px; z-index: 9999;">
  <iframe src="https://neomundi-io.github.io/neomundi-ai-weather/provider-widget.html?system=openai&theme=light&lang=en" width="150" height="90" loading="lazy" title="NeoMundi AI Weather — OpenAI"></iframe>
</div>
```

**Top-right:**
```html
<div style="position: fixed; top: 20px; right: 20px; z-index: 9999;">
  <iframe src="https://neomundi-io.github.io/neomundi-ai-weather/provider-widget.html?system=openai&theme=light&lang=en" width="150" height="90" loading="lazy" title="NeoMundi AI Weather — OpenAI"></iframe>
</div>
```

**Bottom-left:**
```html
<div style="position: fixed; bottom: 20px; left: 20px; z-index: 9999;">
  <iframe src="https://neomundi-io.github.io/neomundi-ai-weather/provider-widget.html?system=openai&theme=light&lang=en" width="150" height="90" loading="lazy" title="NeoMundi AI Weather — OpenAI"></iframe>
</div>
```

**Bottom-right:**
```html
<div style="position: fixed; bottom: 20px; right: 20px; z-index: 9999;">
  <iframe src="https://neomundi-io.github.io/neomundi-ai-weather/provider-widget.html?system=openai&theme=light&lang=en" width="150" height="90" loading="lazy" title="NeoMundi AI Weather — OpenAI"></iframe>
</div>
```

The `20px` value can be adjusted (margin from the edge). The global badge
(`widget.html`) can float using the same principle if needed — just swap
the `src` and keep its dimensions (`380`×`220`).

**Multiple floating badges on the same page**: give each one a different
`z-index` and space out the positions so they don't overlap.

---

## Options common to every format

| Parameter | Values |
|---|---|
| `theme=` | `light` · `dark` · `slate` · `warm` · `transparent` |
| `lang=` | `en` · `fr` · `de` · `es` · `it` |

`transparent` is useful for a floating widget that should blend into the
page's own background instead of showing its own white card.

---

## Classic inline placement (non-floating)

For inline formats (full wall, Core Panel, topbar, sidebar), no special
CSS is needed — paste the snippet into a WordPress HTML block, and use
the block's alignment icons (left / center / right / wide / full width)
if you want to reposition it within the page layout.

---

*Last updated: 2026-08-17. To be checked/synced with `embed-demo.html`
once `weather.json` is running on real data (see README.md → GitHub
Pages section).*
