# AI Weather — Guide d'intégration

**Tout ce qu'il faut pour coller un widget quelque part : le snippet
exact, prêt à copier, rien à deviner.**

Domaine de référence : `https://neomundi-io.github.io/neomundi-ai-weather/`
— toujours en URL absolue (jamais relative) hors des pages du repo lui-même.

---

## Comment s'écrit un iframe

La syntaxe est toujours la même, quel que soit le widget :

```html
<iframe src="URL_DU_WIDGET?theme=light&lang=en" width="..." height="..." loading="lazy" title="..."></iframe>
```

- **`src`** — l'URL absolue du fichier (jamais relative hors du repo lui-même), avec les paramètres `?theme=` et `?lang=` optionnels ajoutés après le `?` (voir tableau en bas de page).
- **`width` / `height`** — en pixels ou en `%`. `width="100%"` fait prendre toute la largeur disponible du conteneur parent.
- **`loading="lazy"`** — le navigateur ne charge l'iframe que quand elle approche de la zone visible à l'écran (meilleure performance si le widget est bas dans la page).
- **`title="..."`** — obligatoire pour l'accessibilité (lecteurs d'écran) ; décrit ce que contient l'iframe.

Chaque section ci-dessous donne le snippet exact prêt à copier pour chaque format.

---

## Vue d'ensemble — quel format pour quel usage

| Format | Fichier | Usage | Taille par défaut | Se place |
|---|---|---|---|---|
| Mur complet | `index.html` | Page dédiée, vue exhaustive | `100%` × `900` | Inline, dans le flux de la page |
| Panel complet | `core-panel.html` | Vitrine compacte, les 12 systèmes en grille de badges | `100%` × `620` | Inline |
| Badge global | `widget.html` | "Comment se comporte l'IA aujourd'hui" en un coup d'œil | `380` × `220` | Inline ou flottant |
| Barre horizontale | `topbar.html` | Bandeau en haut de page, 8 systèmes | `100%` × `80` | Inline |
| Barre verticale | `sidebar.html` | Colonne latérale, 8 systèmes | `280` × `480` | Inline |
| Widget individuel | `provider-widget.html` | Un seul système, badge discret | `260` × `70` (réductible à `170` × `60`) | Inline ou flottant |

**Inline** = collé normalement dans un bloc HTML, il défile avec la page.
**Flottant** = reste fixe à un coin de l'écran même quand on scrolle (voir
section dédiée plus bas — concerne surtout le widget individuel).

**Note visuelle** : `provider-widget.html`, `sidebar.html`, `topbar.html`,
`core-panel.html` et `widget.html` partagent maintenant le même langage
visuel — badge pilule avec point de statut qui pulse, coloré selon la
condition observée (clear / watch / unsettled / alert). Seul `index.html`
(le mur complet) garde son format carte détaillée.

---

## 1. Mur complet — `index.html`

Les 12 systèmes, carte détaillée au clic, sélecteur de langue et de thème
inclus.

```html
<iframe src="https://neomundi-io.github.io/neomundi-ai-weather/index.html?theme=light&lang=en" width="100%" height="900" loading="lazy" title="NeoMundi AI Weather — Full Observation Wall"></iframe>
```

---

## 2. Panel complet — `core-panel.html`

Les **12 systèmes observés**, en grille compacte de badges (2 à 4 colonnes
selon la largeur disponible). Anciennement limité aux 8 providers "core" —
couvre maintenant l'intégralité du panel, comme le mur complet, mais dans
un format plus léger.

```html
<iframe src="https://neomundi-io.github.io/neomundi-ai-weather/core-panel.html?theme=light&lang=en" width="100%" height="620" loading="lazy" title="NeoMundi AI Weather — Panel"></iframe>
```

Si l'iframe est posée dans un conteneur étroit (moins de ~560px de large,
donc 1 à 2 colonnes de badges au lieu de 3-4), prévoir une hauteur plus
grande — jusqu'à `900` en colonne unique.

---

## 3. Badge global — `widget.html`

Un seul état agrégé, aucun détail par système.

```html
<iframe src="https://neomundi-io.github.io/neomundi-ai-weather/widget.html?theme=light&lang=en" width="380" height="220" loading="lazy" title="NeoMundi AI Weather"></iframe>
```

---

## 4. Barre horizontale — `topbar.html`

Les 8 providers majeurs, badges en ligne, scroll horizontal fluide si
l'espace manque.

```html
<iframe src="https://neomundi-io.github.io/neomundi-ai-weather/topbar.html?theme=light&lang=en" width="100%" height="80" loading="lazy" title="AI Weather by ControlTowerAI"></iframe>
```

---

## 5. Barre verticale — `sidebar.html`

Les 8 providers majeurs, badges empilés verticalement.

```html
<iframe src="https://neomundi-io.github.io/neomundi-ai-weather/sidebar.html?theme=light&lang=en" width="280" height="480" loading="lazy" title="AI Weather by ControlTowerAI"></iframe>
```

---

## 6. Widget individuel — `provider-widget.html`

Un seul système, format le plus compact — badge pilule avec point qui
pulse. Change `system=` par l'id voulu (table complète ci-dessous).

**Taille standard :**
```html
<iframe src="https://neomundi-io.github.io/neomundi-ai-weather/provider-widget.html?system=openai&theme=light&lang=en" width="260" height="70" loading="lazy" title="NeoMundi AI Weather — OpenAI"></iframe>
```

**Taille réduite (minimum recommandé, en dessous le texte du nom se
tronque) :**
```html
<iframe src="https://neomundi-io.github.io/neomundi-ai-weather/provider-widget.html?system=openai&theme=light&lang=en" width="170" height="60" loading="lazy" title="NeoMundi AI Weather — OpenAI"></iframe>
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
  <iframe src="https://neomundi-io.github.io/neomundi-ai-weather/provider-widget.html?system=openai&theme=light&lang=en" width="170" height="60" loading="lazy" title="NeoMundi AI Weather — OpenAI"></iframe>
</div>
```

**Haut-droite :**
```html
<div style="position: fixed; top: 20px; right: 20px; z-index: 9999;">
  <iframe src="https://neomundi-io.github.io/neomundi-ai-weather/provider-widget.html?system=openai&theme=light&lang=en" width="170" height="60" loading="lazy" title="NeoMundi AI Weather — OpenAI"></iframe>
</div>
```

**Bas-gauche :**
```html
<div style="position: fixed; bottom: 20px; left: 20px; z-index: 9999;">
  <iframe src="https://neomundi-io.github.io/neomundi-ai-weather/provider-widget.html?system=openai&theme=light&lang=en" width="170" height="60" loading="lazy" title="NeoMundi AI Weather — OpenAI"></iframe>
</div>
```

**Bas-droite :**
```html
<div style="position: fixed; bottom: 20px; right: 20px; z-index: 9999;">
  <iframe src="https://neomundi-io.github.io/neomundi-ai-weather/provider-widget.html?system=openai&theme=light&lang=en" width="170" height="60" loading="lazy" title="NeoMundi AI Weather — OpenAI"></iframe>
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
| `lang=` | `en` · `fr` · `de` · `es` · `it` · `pt` · `nl` · `ru` · `ar` · `hi` · `ja` · `ko` · `zh` |

`transparent` est utile pour un widget flottant qui doit se fondre dans
le fond de la page plutôt que d'avoir sa propre carte blanche.

---

## Placement inline classique (non flottant)

Pour les formats inline (mur complet, Panel complet, topbar, sidebar), pas
de CSS particulier — colle le snippet dans un bloc HTML WordPress, et
utilise les icônes d'alignement du bloc (gauche / centre / droite / large
/ pleine largeur) si tu veux le repositionner dans la mise en page.

---

*Dernière mise à jour : 2026-08-24. `core-panel.html` est passé de 8 à
12 systèmes et l'ensemble des widgets (hors mur complet) a été restylé
en badges pilule avec point qui pulse.*
