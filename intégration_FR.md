# AI Weather — Guide d'intégration

**Tout ce qu'il faut pour coller un widget quelque part : le snippet
exact, prêt à copier, rien à deviner.**

Domaine de référence : `https://neomundi-io.github.io/neomundi-ai-weather/`
— toujours en URL absolue (jamais relative) hors des pages du repo lui-même.

---

## Vue d'ensemble — quel format pour quel usage

| Format | Fichier | Usage | Taille par défaut | Se place |
|---|---|---|---|---|
| Mur complet | `index.html` | Page dédiée, vue exhaustive | `100%` × `900` | Inline, dans le flux de la page |
| Core Panel | `core-panel.html` | Vitrine compacte controltowerai.io (8 systèmes) | `100%` × `520` | Inline |
| Badge global | `widget.html` | "Comment se comporte l'IA aujourd'hui" en un coup d'œil | `380` × `220` | Inline ou flottant |
| Barre horizontale | `topbar.html` | Bandeau en haut de page, 8 systèmes | `100%` × `80` | Inline |
| Barre verticale | `sidebar.html` | Colonne latérale, 8 systèmes | `300` × `520` | Inline |
| Widget individuel | `provider-widget.html` | Un seul système, badge discret | `300` × `120` (réductible à `150` × `90`) | Inline ou flottant |

**Inline** = collé normalement dans un bloc HTML, il défile avec la page.
**Flottant** = reste fixe à un coin de l'écran même quand on scrolle (voir
section dédiée plus bas — concerne surtout le widget individuel).

---

## 1. Mur complet — `index.html`

Les 12 systèmes, carte détaillée au clic, sélecteur de langue inclus.

```html
<iframe src="https://neomundi-io.github.io/neomundi-ai-weather/index.html?theme=light&lang=en" width="100%" height="900" loading="lazy" title="NeoMundi AI Weather — Full Observation Wall"></iframe>
```

---

## 2. Core Panel — `core-panel.html`

8 systèmes majeurs (4 US + Mistral + 3 chinois), vue compacte.

```html
<iframe src="https://neomundi-io.github.io/neomundi-ai-weather/core-panel.html?theme=light&lang=en" width="100%" height="520" loading="lazy" title="NeoMundi AI Weather — Core Provider Panel"></iframe>
```

---

## 3. Badge global — `widget.html`

Un seul état agrégé, aucun détail par système.

```html
<iframe src="https://neomundi-io.github.io/neomundi-ai-weather/widget.html?theme=light&lang=en" width="380" height="220" loading="lazy" title="NeoMundi AI Weather"></iframe>
```

---

## 4. Barre horizontale — `topbar.html`

```html
<iframe src="https://neomundi-io.github.io/neomundi-ai-weather/topbar.html?theme=light&lang=en" width="100%" height="80" loading="lazy" title="AI Weather by ControlTowerAI"></iframe>
```

---

## 5. Barre verticale — `sidebar.html`

```html
<iframe src="https://neomundi-io.github.io/neomundi-ai-weather/sidebar.html?theme=light&lang=en" width="300" height="520" loading="lazy" title="AI Weather by ControlTowerAI"></iframe>
```

---

## 6. Widget individuel — `provider-widget.html`

Un seul système, format le plus compact. Change `system=` par l'id
voulu (table complète ci-dessous).

**Taille standard :**
```html
<iframe src="https://neomundi-io.github.io/neomundi-ai-weather/provider-widget.html?system=openai&theme=light&lang=en" width="300" height="120" loading="lazy" title="NeoMundi AI Weather — OpenAI"></iframe>
```

**Taille réduite (minimum recommandé, en dessous le contenu se tasse) :**
```html
<iframe src="https://neomundi-io.github.io/neomundi-ai-weather/provider-widget.html?system=openai&theme=light&lang=en" width="150" height="90" loading="lazy" title="NeoMundi AI Weather — OpenAI"></iframe>
```

### Les 12 ids disponibles

| id | Modèle affiché |
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

## Widget flottant (position fixe à l'écran, même en scrollant)

Par défaut ci-dessous : **coin haut-gauche**. Pour changer, remplace le
bloc `style="..."` de la `<div>` par une des variantes juste après —
rien d'autre à toucher.

**Haut-gauche (défaut) :**
```html
<div style="position: fixed; top: 20px; left: 20px; z-index: 9999;">
  <iframe src="https://neomundi-io.github.io/neomundi-ai-weather/provider-widget.html?system=openai&theme=light&lang=en" width="150" height="90" loading="lazy" title="NeoMundi AI Weather — OpenAI"></iframe>
</div>
```

**Haut-droite :**
```html
<div style="position: fixed; top: 20px; right: 20px; z-index: 9999;">
  <iframe src="https://neomundi-io.github.io/neomundi-ai-weather/provider-widget.html?system=openai&theme=light&lang=en" width="150" height="90" loading="lazy" title="NeoMundi AI Weather — OpenAI"></iframe>
</div>
```

**Bas-gauche :**
```html
<div style="position: fixed; bottom: 20px; left: 20px; z-index: 9999;">
  <iframe src="https://neomundi-io.github.io/neomundi-ai-weather/provider-widget.html?system=openai&theme=light&lang=en" width="150" height="90" loading="lazy" title="NeoMundi AI Weather — OpenAI"></iframe>
</div>
```

**Bas-droite :**
```html
<div style="position: fixed; bottom: 20px; right: 20px; z-index: 9999;">
  <iframe src="https://neomundi-io.github.io/neomundi-ai-weather/provider-widget.html?system=openai&theme=light&lang=en" width="150" height="90" loading="lazy" title="NeoMundi AI Weather — OpenAI"></iframe>
</div>
```

Le `20px` peut être ajusté (marge par rapport au bord). Le badge global
(`widget.html`) peut se flotter avec le même principe si besoin — juste
remplacer le `src` et garder ses dimensions (`380`×`220`).

**Sur plusieurs badges flottants en même temps** : si tu en mets plus
d'un sur la même page (ex: deux systèmes différents), donne à chaque
`z-index` une valeur différente et espace les positions pour qu'ils ne
se chevauchent pas.

---

## Options communes à tous les formats

| Paramètre | Valeurs |
|---|---|
| `theme=` | `light` · `dark` · `slate` · `warm` · `transparent` |
| `lang=` | `en` · `fr` · `de` · `es` · `it` |

`transparent` est utile pour un widget flottant qui doit se fondre dans
le fond de la page plutôt que d'avoir sa propre carte blanche.

---

## Placement inline classique (non flottant)

Pour les formats inline (mur complet, Core Panel, topbar, sidebar), pas
de CSS particulier — colle le snippet dans un bloc HTML WordPress, et
utilise les icônes d'alignement du bloc (gauche / centre / droite / large
/ pleine largeur) si tu veux le repositionner dans la mise en page.

---

*Dernière mise à jour : 2026-08-17. À vérifier/synchroniser avec
`embed-demo.html` une fois que `weather.json` sera passé en donnée
réelle (voir README.md → section GitHub Pages).*
