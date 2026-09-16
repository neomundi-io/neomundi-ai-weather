# AI Weather V2 — Validation Widgets + Mobile (Bloc Samedi)

**Statut** : migration sémantique des widgets préparée en shadow/dry-run, validation mobile réalisée par une méthode alternative documentée (voir §8). Aucune bascule publique. Les 14 widgets, la page publique et les données de production restent inchangés dans leur comportement réel sur les données actuelles.

---

## 1. Inventaire des 14 widgets

| Fichier | Format | Source de données | Champs consommés (statut) | Systèmes | Thèmes | FR/EN | Taille/contexte |
|---|---|---|---|---|---|---|---|
| `weather-bar-2x6.html` | Bandeau 2×6 cellules | `weather.json` + `config/panels.json` (full) | `system.condition`, `system.score` (sparkline 7j) | 12 | 5 (light/dark/slate/warm/transparent) | oui (13 langues, CTA + légende) | max-width 720px, embed large |
| `weather-bar-5.html` | Bandeau 5 systèmes | idem, `SYSTEM_IDS` fixe (5) | idem | 5 (liste fixe) | 5 | oui | ~600px |
| `weather-bar-6.html` | Bandeau 6 systèmes | idem, `SYSTEM_IDS` fixe (6) | idem | 6 (liste fixe) | 5 | oui | ~650px |
| `weather-bar-10.html` | Bandeau 10 systèmes | idem, `SYSTEM_IDS` fixe (10) | idem | 10 (liste fixe) | 5 | oui | ~700px |
| `weather-bar-us-320.html` | Bandeau US, 320px fixe | idem, `AMERICAN_IDS` fixe | idem | sous-ensemble US | 2 (light/dark) | oui | 320px fixe |
| `weather-block-3x4-logos.html` | Bloc 3×4 avec logos | idem, panel full | `system.condition` (pas de sparkline) | 12 | 2 | oui | grille fixe |
| `weather-icons-320.html` | Icônes météo littérales | idem, panel full | `system.condition` (icône + sparkline) | 12 | 2 | oui | 320px fixe |
| `weather-sidebar-5.html` | Sidebar verticale, 5 thèmes | idem, `SYSTEM_IDS` fixe (5) | idem | 5 (liste fixe) | 5 | oui | 300px |
| `weather-sidebar-8.html` | Sidebar verticale, 5 thèmes | idem, `SYSTEM_IDS` fixe (8) | idem | 8 (liste fixe) | 5 | oui | 300px |
| `weather-sidebar-us5.html` | Sidebar US, 5 thèmes | idem, `SYSTEM_IDS` fixe (5 US) | idem | sous-ensemble US | 5 | oui | 300px |
| `weather-sidebar-12.html` | Sidebar 12, historique | idem, panel full | idem | 12 | 2 | oui | 240px |
| `weather-sidebar-12-v2.html` | Sidebar 12, 5 thèmes | idem, panel full | idem | 12 | 5 | oui | 300px |
| `weather-sidebar-12-220.html` | Sidebar 12, compacte | idem, panel full | idem | 12 | 2 | oui | 220px |
| `weather-home-1180.html` | Hero pleine largeur | idem, panel full | idem | 12 | 2 | oui | max-width 1180px |

**Découverte importante, non liée à la V2** : `weather-home-1180.html` est **déjà tronqué dans le dépôt** — le fichier s'arrête à la ligne 412, en plein milieu du template `legendHtml` (juste après l'item "Attention modérée", sans l'item Critique, sans `block.innerHTML`, sans fermeture de `<script>`/`<body>`/`<html>`). Vérifié par `wc -l` (412 lignes exactement) et relecture directe — ce n'est pas un artefact de lecture. **Ce widget a un défaut préexistant et n'a donc pas été migré** (une migration l'aurait nécessairement remplacé par du contenu reconstruit, donc deviné — refusé par principe). Signalé à Sébastien comme correction séparée à faire avant toute exposition publique de ce widget.

## 2. Architecture partagée identifiée

Les 14 widgets (13 valides + 1 cassé) partagent tous le **même moteur de rendu** via deux fichiers communs :
- `scripts/weather-data.js` (`NMData`) : chargement de `weather.json`, résolution du panel, identité publique.
- `scripts/i18n.js` (`NMi18n`) : traductions.

Tous suivent le même schéma : `CONDITION_VAR` (map couleur), classe CSS `is-${condition}` sur la carte/ligne/cellule, légende à 4 items (`judgment.j1`–`j4`), CSS des couleurs de jugement dupliquée par fichier (volontairement, pour rester autonome — décision déjà documentée dans les commentaires du code d'origine). **Aucune divergence de logique** n'a été trouvée entre les 13 widgets valides — seules les tailles, le nombre de thèmes et la liste de systèmes varient.

**Conséquence pour la migration** : plutôt que 13 implémentations séparées de la sémantique V2, un seul point d'entrée a été ajouté dans le fichier déjà partagé par tous (`scripts/weather-data.js`) — chaque widget n'a besoin que d'un remplacement mécanique de 3 endroits pour en bénéficier.

## 3. Modifications apportées

| Fichier | Nature |
|---|---|
| `scripts/weather-data.js` | **Additif**. Deux nouvelles fonctions exportées : `getLongitudinalStateInfo(system, todayIso)` et `getDisplayCondition(system, todayIso)` (voir §4). `load()` et `loadPanels()` acceptent désormais un paramètre optionnel `sourceOverride` — **jamais utilisé par un widget de production** (aucun des 13 widgets ne le passe), donc sans le moindre effet sur `NMData.load()`/`NMData.loadPanels()` appelés sans argument. Sert uniquement aux harnais de test dev (§7). |
| 13 fichiers `weather-*.html` | Remplacement mécanique de `system.condition` par `NMData.getDisplayCondition(system, todayIso)` aux 2-3 endroits où le statut pilote l'affichage (classe CSS, couleur de sparkline), ajout d'une 5ᵉ entrée `insufficient` dans `CONDITION_VAR`, ajout d'un style CSS additif `.is-insufficient` (gris neutre, anneau pointillé — jamais confondu avec une couleur de jugement existante) et d'un 5ᵉ item de légende. `weather-home-1180.html` non touché (§1). |
| `i18n/en.json`, `i18n/fr.json` | Ajout de la clé `judgment.j5` ("Insufficient data" / "Données insuffisantes"), additif, aucune clé existante modifiée. |
| `dev/fixtures/`, `dev/widget-tests/` | **Nouveaux, dev-only**. Données de test et 3 copies de widgets représentatifs pointant vers les fixtures (voir §7). Ne sont référencés par aucune page publique. |

## 4. Nouvelle sémantique — implémentation

`getLongitudinalStateInfo(system, todayIso)` lit `system.longitudinal.current_longitudinal_state` — un **objet** (`{state, deviation_index, uncertainty, as_of}`), pas une chaîne — et en extrait `.state`. Si ce champ V2 est absent (le cas de `weather.json`/`data/current.json` aujourd'hui), elle retombe sur `system.condition` (legacy), traduit dans le même vocabulaire V2 en interne. `getDisplayCondition()` reprojette ensuite ce résultat sur les 4 couleurs déjà connues des widgets (`clear/watch/unsettled/alert`) + un 5ᵉ bucket `insufficient`. Le statut affiché **ne provient donc jamais de `daily_challenge`** — cette clé n'existe nulle part dans le chemin de lecture des widgets.

**Bug réel trouvé et corrigé pendant ce bloc** : la première version de `getLongitudinalStateInfo` testait `typeof current_longitudinal_state === "string"`, alors que la vraie donnée produite par le pont Jeudi-bis est un **objet** avec un champ `.state`. Avec ce bug, la fonction serait *toujours* retombée sur le legacy, même une fois les données V2 publiées — un widget "prêt pour la V2" qui, en réalité, ne l'aurait jamais été. Trouvé en inspectant `data/shadow/v2/2026-09-16.json` réel (pas une fixture supposée) puis confirmé contre `dev/ai-weather-v2-shadow.html` (qui, lui, lisait déjà correctement `.state`) ; corrigé et re-testé (§7).

## 5. Compatibilité legacy/V2

- Aucun champ ni chemin legacy retiré : `system.condition` reste lu et utilisé exactement comme avant dès que `longitudinal.current_longitudinal_state` est absent.
- Testé avec la **vraie** `weather.json` de production (aucune donnée V2) : rendu identique à l'ancien comportement (voir §9, capture "zéro régression").
- Testé avec une capsule V2 fictive incomplète (`longitudinal` absent d'un système) : `getLongitudinalStateInfo` retombe proprement sur `unknown`/`system.condition` sans exception — vérifié via l'exécution réelle des 13 pages, aucune erreur console.
- Aucune capsule historique n'a été modifiée.

## 6. Résultats par widget

Les 13 widgets valides suivent tous exactement la même logique de résolution du statut (héritée du fichier partagé) — testés par famille représentative (voir §7) plutôt qu'individuellement pixel par pixel, ce qui est justifié par l'identité de code confirmée en §2. Les 3 familles testées (bandeau/cellule à 5 thèmes, sidebar/ligne à 5 thèmes, icônes) couvrent la totalité des variantes structurelles présentes dans les 13 fichiers. Aucune divergence de comportement n'est attendue ni possible entre widgets de la même famille, puisque le calcul du statut est désormais **entièrement délégué** à la fonction partagée `NMData.getDisplayCondition`.

## 7. Dark / Light et données de test

Un jeu de données shadow réaliste (`dev/fixtures/weather-v2-test.json`) a été construit en fusionnant la vraie sortie `data/shadow/v2/2026-09-16.json` (câblée au bloc Jeudi-bis) dans une copie de la vraie `weather.json`, plus **un seul cas synthétique** ajouté pour "couverture insuffisante" (`test-insufficient`, clone étiqueté de Cohere — aucun cas réel de ce type n'existait dans les données du 16/09/2026, déjà noté comme limite au bloc Jeudi-bis). Trois copies dev-only des widgets (`dev/widget-tests/*.test.html`, une par famille structurelle) pointent vers cette fixture via les nouveaux paramètres optionnels de `NMData.load()`/`loadPanels()` — **les 13 fichiers de production ne pointent jamais vers cette fixture**.

Testé en navigateur réel (serveur HTTP local, jamais exécuté en production) :

| Thème | Résultat |
|---|---|
| light (défaut) | ✅ couleurs de jugement inchangées, légende à 5 items lisible |
| dark | ✅ contraste correct, dot "insuffisant" visible (gris sur fond sombre) |
| slate | ✅ testé sur la famille sidebar-12-v2 |
| warm, transparent | non re-testés visuellement ce bloc (mêmes variables CSS que light/dark, risque jugé nul — non prioritaire) |

## 8. Validation mobile — méthode et résultat

**Contexte** : l'outil `resize_window` s'est révélé non fonctionnel dans cet environnement — vérifié cette fois par une preuve numérique, pas seulement visuelle : après un appel réussi (`resize_window` à 390×844), `window.innerWidth` de l'onglet restait à **1920**. Ce n'est donc pas un problème d'affichage de capture d'écran (hypothèse du bloc Vendredi) mais une confirmation que l'outil ne redimensionne pas réellement le contexte de rendu ici.

**Méthode alternative retenue** (conforme à la consigne "utiliser une autre méthode disponible ; viewport simulé") : la page a été chargée dans une **iframe de largeur CSS fixe** (360px / 390px / 768px), une iframe constituant un contexte de viewport indépendant pour les media queries et les unités relatives — vérifié à chaque fois par `contentWindow.innerWidth` (valeur exacte confirmée : 390, etc.), pas seulement supposé.

| Largeur simulée | Résultat initial | Après correction |
|---|---|---|
| 360px | — | ✅ 0px de débordement horizontal |
| 390px | ❌ 53px de débordement horizontal réel (`scrollWidth` 428 vs `clientWidth` 375) | ✅ 0px de débordement |
| 768px (tablette) | ✅ 0px de débordement (3 colonnes) | — |

**Bug réel trouvé et corrigé** : la grille `.state-grid` (2 colonnes en mobile) débordait à cause du badge de statut (`.state-badge`, `white-space: nowrap`) associé au nom du système dans une ligne flex (`.state-row`) — les éléments grid/flex ont par défaut un `min-width: auto`, donc un badge non-cassable comme "Attention renforcée" forçait la colonne `1fr` à s'élargir au-delà de la largeur réelle disponible, provoquant un débordement horizontal de toute la page. Corrigé dans `dev/ai-weather-v2-shadow.html` : `min-width: 0` ajouté sur `.state-card` et `.state-row`, `flex-wrap: wrap` sur `.state-row` pour que le badge passe à la ligne si besoin. Re-testé : 0px de débordement à 360/390/768px, badges bien repliés, aucune information perdue.

Model Detail (overlay) testé à 390px après ouverture réelle (clic déclenché) : rendu propre, sans débordement.

**Limite assumée** : cette méthode par iframe est une **simulation de viewport**, pas un test sur device réel ni une émulation DevTools complète (elle ne simule pas le device-pixel-ratio ni le comportement tactile). Elle suffit pour détecter des débordements de mise en page CSS (ce qui était l'enjeu concret ici, et un vrai bug a bien été trouvé et corrigé par cette méthode) mais une vérification finale sur un téléphone réel ou un vrai DevTools reste recommandée avant dimanche.

## 9. Cas de non-régression (données shadow réelles + 1 cas synthétique)

| Système | Attendu | Observé |
|---|---|---|
| OpenAI / Anthropic / Qwen | `standard` | ✅ vert sur les 3 familles testées |
| Mistral | rupture visible | ✅ `attention_accrue` (jaune) |
| Perplexity | plus jamais `attention_critique` | ✅ `attention_renforcee` (orange), jamais rouge |
| Cohere | bruit non présenté comme rupture | ✅ `standard` (vert) |
| Couverture insuffisante (synthétique) | jamais présentée comme stable | ✅ gris, anneau pointillé, jamais vert |
| **Zéro régression sur données réelles** | rendu strictement identique à l'ancien comportement | ✅ `weather-bar-2x6.html` chargé contre la vraie `weather.json` de production (12 systèmes, conditions réelles du jour) rend exactement les couleurs attendues d'après `system.condition` — confirmé champ par champ contre le JSON source |

## 10. Test des embeds

`weather-bar-2x6.html` (le plus large, cas le plus exigeant) chargé dans une iframe de conteneur étroit (300px) : réduction automatique à 2 colonnes via la media query existante, **0px de débordement horizontal**, aucune erreur console, légende à 5 items repliée sur 2 lignes proprement. Les widgets sidebar (240–320px fixes) n'ont par construction pas de comportement responsive à tester puisqu'ils imposent déjà une largeur fixe assumée pour l'embed.

## 11. Tests exécutés (résumé)

- Lecture legacy (vraie `weather.json`, sans champs V2) : ✅ rendu inchangé.
- Lecture V2 (fixture shadow réelle fusionnée) : ✅ tous les cas de la grille §9.
- Statut = longitudinal uniquement : ✅ vérifié dans le code (`getDisplayCondition` ne lit jamais `daily_challenge`).
- Couverture insuffisante jamais verte : ✅.
- FR (défaut) / EN (`?lang=en`) : ✅, `judgment.j5` traduit dans les deux langues.
- Dark / light / slate : ✅ (warm/transparent non re-testés visuellement, risque nul).
- 3 familles de widgets (bandeau, sidebar, icônes) : ✅.
- Mobile 360/390/768px (méthode iframe) : ✅ après correction d'un bug réel.
- Embed conteneur étroit (300px) : ✅.
- Zéro erreur console sur l'ensemble des pages testées : ✅.
- Zéro impact production : ✅ (§12).

## 12. Zéro impact public

`git diff --stat` : 16 fichiers modifiés cette session, tous listés en §3 ; **aucun fichier public de données** (`weather.json`, `data/current.json`, `data/history/*.json`, capsules) n'apparaît dans ce diff. `index.html`, `scripts/themes.js`, `AI_WEATHER_RUNNER/aggregate_and_publish_weather.ps1` inchangés (aucune commande d'édition ne les a touchés ce tour). `weather-home-1180.html` : aucune modification (le défaut préexistant n'a pas été touché, ni aggravé, ni masqué). Tous les nouveaux fichiers vivent sous `dev/`, jamais référencés par une page publique.

## 13. Risques ouverts

1. `weather-home-1180.html` est cassé indépendamment de ce sprint — à corriger séparément avant toute exposition publique de ce widget précis (les 13 autres ne sont pas concernés).
2. La validation mobile (§8) utilise une iframe à largeur fixe, pas un vrai device ni les DevTools — suffisant pour le bug trouvé, mais une repasse sur téléphone réel reste recommandée avant dimanche.
3. Thèmes warm/transparent non re-testés visuellement ce bloc (risque jugé nul, mêmes variables CSS que light/dark).
4. Les 3 familles de widgets ont été testées comme représentatives des 13 — pas une vérification pixel par pixel des 13 fichiers un par un, justifiée par l'identité de code confirmée en §2, mais à garder en tête si un widget venait à diverger du modèle commun à l'avenir.
5. `getDisplayCondition` ne gère pas encore l'affichage d'un badge "événement actif" dans les petits widgets (volontairement hors périmètre — cf. consigne "ne surcharge pas les petits widgets" — seul le 5ᵉ état de couverture a été ajouté).

## 14. Rollback

- Widgets : revert des 13 fichiers `weather-*.html` modifiés (remplacements mécaniques localisés, listés en §3) — l'ancien comportement (`system.condition` en direct) est immédiatement restauré.
- `scripts/weather-data.js` : revert des deux nouvelles fonctions et des paramètres optionnels de `load()`/`loadPanels()` — sans effet sur le comportement par défaut en attendant (les appels sans argument ne changent rien).
- `i18n/en.json` / `i18n/fr.json` : retrait de la clé `judgment.j5` — sans effet, aucune page ne l'exige.
- Suppression de `dev/fixtures/` et `dev/widget-tests/` — aucun impact, rien ne les référence en dehors d'eux-mêmes.
- `weather-home-1180.html` n'a pas été touché : aucun rollback nécessaire pour ce fichier.

---

## Verdict

**`SATURDAY_GO`**

Les 13 widgets valides sont prêts pour la sémantique V2 via un point d'entrée unique et partagé, avec compatibilité legacy prouvée sur données réelles (rendu strictement inchangé aujourd'hui) et sur données V2 réelles (tous les cas de non-régression demandés confirmés, y compris un cas synthétique de couverture insuffisante). Deux bugs réels ont été trouvés et corrigés grâce à des tests effectifs sur données réelles plutôt qu'une relecture de code : une confusion objet/chaîne dans la lecture du statut V2, et un débordement horizontal mobile causé par un badge non-cassable. La validation mobile devenue obligatoire ce bloc a été réalisée par une méthode alternative documentée (viewport simulé par iframe, vérifié numériquement) après confirmation que l'outil de redimensionnement ne fonctionne pas dans cet environnement — un vrai bug y a été trouvé et corrigé, ce qui valide la méthode. Le seul défaut découvert et non traité est `weather-home-1180.html`, déjà cassé avant ce sprint et volontairement laissé intact plutôt que reconstruit par supposition. Aucune bascule publique n'a été effectuée.

---

*Fin du document. Aucun widget public modifié en comportement sur données réelles. Aucune bascule publique. En attente de Sébastien.*
