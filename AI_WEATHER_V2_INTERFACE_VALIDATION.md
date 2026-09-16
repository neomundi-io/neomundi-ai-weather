# AI Weather V2 — Validation de l'interface (Bloc Vendredi)

**Statut** : interface construite et testée en dev/shadow uniquement. La page publique actuelle, les 14 widgets, `weather.json`, `data/current.json`, `data/history/*.json` et les capsules n'ont pas été touchés.

---

## 1. Architecture de la page

Un seul fichier neuf et autonome : `dev/ai-weather-v2-shadow.html`. Il reproduit la hiérarchie imposée dans l'ordre exact (état → changement → trajectoire → challenge du jour → méthodologie), mais place éditorialement **AI WEATHER en premier et Today's Challenge en 3ᵉ position**, conformément à la règle non négociable : le statut principal ne provient que de `longitudinal.current_longitudinal_state`, jamais de `daily`.

Sections implémentées : **AI WEATHER** (hero + grille des 12 systèmes) → **WHAT CHANGED?** (flux d'événements) → **TODAY'S CHALLENGE** (encadré visuellement distinct) → **MODEL DETAIL** (overlay au clic sur une carte) → **METHODOLOGY / DATA** (9 encarts explicatifs).

## 2. Fichiers modifiés

| Fichier | Nature |
|---|---|
| `i18n/en.json`, `i18n/fr.json` | **Modifiés, additivement uniquement** — ~60 nouvelles clés `v2.*` par langue. Vérifié par `git diff` : aucune ligne existante supprimée ou changée (la seule "suppression" détectée est un artefact de virgule JSON en fin de fichier, pas un changement sémantique). Aucune page publique actuelle ne demande jamais une clé `v2.*` : impact nul sur le rendu existant. |
| `dev/ai-weather-v2-shadow.html` | **Nouveau**. |

**Rien d'autre n'a été modifié** : `index.html`, `scripts/*.js`, `styles/*.css`, les 14 widgets, `config/*.json` restent intacts.

## 3. Composants créés

- **Hero** : marque, sous-titre, phrase d'explication (bornée à "comportement observable sous stimulus constant"), badges méthodologie/répétitions/couverture/date.
- **Current State** : grille de 12 cartes triées "pire en premier", couleur = état longitudinal, badge d'incertitude Wilson descriptif, drapeau d'identité incertaine, pastille d'événement actif (limitée au jour courant — voir bug corrigé §6).
- **What Changed?** : flux des 3 événements les plus récents du panel (triés par date, tous systèmes confondus), wording repris mot pour mot des textes déjà validés dans les blocs précédents, section "Preuves" dépliable.
- **Today's Challenge** : encadré à bordure pointillée, disclaimer explicite, question du jour, grille de scores du jour — **jamais dans le même conteneur visuel que Current State**.
- **Model Detail** : överlay au clic — baseline (médiane/MAD + mention du plancher si appliqué), écart, incertitude, identité, liste d'événements, et une trajectoire multi-jours en best-effort (voir §4).
- **Methodology / Data** : 9 encarts (stimulus constant, répétitions, baseline, plancher de dispersion, incertitude Wilson descriptive, séparation longitudinal/challenge, identité, versionnement, limites).

## 4. Source de données shadow utilisée

- **Principale** : `data/shadow/v2/2026-09-16.json` (le vrai fichier produit par le pipeline câblé du bloc Jeudi-bis) — utilisée pour tout : Current State, What Changed, Today's Challenge, Model Detail (hors trajectoire).
- **Secondaire, best-effort** : `AI_WEATHER_RUNNER/shadow/longitudinal_shadow_report_latest.json` (sortie du moteur Phase 1, qui contient un historique sur ~26 jours) — utilisée uniquement pour dessiner la trajectoire multi-jours dans Model Detail. Chargée en arrière-plan, jamais bloquante : si absente, le detail affiche honnêtement "aucune trajectoire disponible" plutôt que d'inventer des points.
- **Aucune donnée n'est inventée** : les jours manquants ne sont jamais interpolés (conforme à la logique déjà en place dans `scripts/weather-data.js`).

## 5. Logique de rendu — vérifiée en navigateur réel, pas seulement en lecture de code

Serveur local (`python3 -m http.server`), page chargée et interagie via navigateur réel (captures d'écran + lecture DOM). **Trois bugs réels trouvés et corrigés pendant cette vérification** :

1. `scripts/i18n.js` résout les chemins relativement à l'URL de la page ; comme la page vit dans `dev/`, les clés de traduction ne se chargeaient pas (tout s'affichait en `v2.xxx.yyy` brut). Corrigé en écrivant un petit chargeur i18n **local à cette page uniquement** (pas de modification du fichier partagé `scripts/i18n.js`, donc aucun risque pour les autres pages).
2. Bug de substitution de gabarit (`{version}`, `{n}`...) laissant des accolades orphelines dans les badges du hero. Corrigé.
3. La pastille "Événement actif" et le tri de "What Changed?" utilisaient **tout l'historique d'événements du système** (26 jours) au lieu du jour courant, faisant apparaître presque tous les systèmes comme ayant un événement actif en permanence. Corrigé pour ne considérer que les événements datés du jour de l'instantané.

## 6. Cas de non-régression visuelle

| Système | Attendu | Observé dans l'interface |
|---|---|---|
| OpenAI (ChatGPT) | `standard` | ✅ Standard |
| Anthropic (Claude) | `standard` | ✅ Standard |
| Qwen | `standard` | ✅ Standard |
| Mistral | rupture visible | ✅ Attention accrue |
| Perplexity | plus jamais `attention_critique` | ✅ Attention renforcée (jamais critique) |
| Cohere | bruit non présenté comme rupture | ✅ Standard |
| Couverture insuffisante | jamais présentée comme stabilité | ⚠️ Non exercé — aucun des 12 systèmes n'était en couverture insuffisante le 16/09/2026 (même constat déjà fait au bloc Jeudi-bis). Le style CSS et le libellé i18n existent et sont prêts (`st-insufficient_data`, `v2.state.insufficient_data`), mais n'ont pas pu être vus avec de vraies données faute de cas réel disponible aujourd'hui. |

## 7. Responsive

Les grilles (`state-grid`, `challenge-grid`) réutilisent **exactement** les points de rupture déjà validés en production dans `index.html` (2 colonnes → 3 à 560px → 4 à 860px). **Limite honnête à signaler** : l'outil de redimensionnement de fenêtre du navigateur s'est révélé peu fiable dans cette session (la capture d'écran continuait de renvoyer une largeur desktop malgré une demande de redimensionnement à 390-400px, sur deux tentatives, y compris sur un nouvel onglet dédié). Je n'ai donc **pas pu vérifier visuellement** le rendu mobile/tablette dans cette session, malgré la demande explicite — seule la réutilisation du CSS déjà éprouvé en production réduit le risque. À revérifier manuellement (téléphone réel, ou DevTools en local) avant la répétition générale de dimanche.

## 8. FR / EN

Les deux langues fonctionnent, testées via le navigateur (FR par défaut selon la langue du navigateur, EN via `?lang=en`), aucune clé orpheline. **Point ouvert à trancher par Sébastien, pas une erreur technique** : les libellés d'état "Attention accrue / Attention renforcée / Attention critique" sont actuellement **identiques en français et en anglais** (traités comme une terminologie de marque, à l'image de "AI Weather" lui-même) — à confirmer, ou à remplacer par de vrais équivalents anglais ("Increased/Reinforced/Critical Attention") si préféré.

## 9. Tests effectués

- Chargement réel des données shadow (`fetch` sur `data/shadow/v2/2026-09-16.json`) : réussi.
- Zéro erreur console sur deux chargements complets de page (vérifié avec le tracking de console actif dès avant le chargement).
- Rendu des 12 systèmes : vérifié (capture d'écran + extraction DOM complète).
- Interaction Model Detail (clic → overlay → fermeture) : vérifiée sur Perplexity, contenu exact confirmé (baseline, plancher, trajectoire, événements, wording prudent).
- Today's Challenge visuellement séparé avec disclaimer : vérifié.
- FR/EN : vérifiés tous les deux.
- Zéro impact public : `git status` confirme qu'aucun widget, aucune page publique, aucune donnée de production n'a changé ; seuls `dev/` (nouveau) et les deux fichiers i18n (additifs, vérifiés par diff) apparaissent.
- **Non fait** : vérification visuelle mobile/tablette (§7, limite d'outillage documentée honnêtement plutôt que masquée).

## 10. Risques restants

1. Responsive non vérifié visuellement cette session (§7) — risque jugé faible (CSS réutilisé tel quel depuis la production) mais non nul.
2. Décision de marque en attente : libellés d'état identiques FR/EN (§8).
3. États `insufficient_data`/`baseline_window` non exercés sur données réelles aujourd'hui — stylés et traduits, jamais vus en situation.
4. La trajectoire de Model Detail lit un fichier sous `AI_WEATHER_RUNNER/shadow/` directement depuis le navigateur — acceptable pour une page de dev, mais ce chemin n'est pas un emplacement public pérenne ; à revoir avant toute exposition au-delà de ce dev-build (déjà noté comme risque ouvert au bloc Jeudi-bis).
5. "What Changed?" ne fonctionne aujourd'hui que sur un seul instantané shadow ; sa logique de tri/déduplication devra être revue une fois plusieurs jours de `data/shadow/v2/*.json` accumulés.

## 11. Rollback

Supprimer `dev/ai-weather-v2-shadow.html`. Les ajouts aux deux fichiers i18n peuvent rester tels quels sans aucun effet (aucune page actuelle ne les lit) ou être retirés par un simple retrait des blocs `v2.*` ajoutés en fin de fichier — dans les deux cas, aucun impact sur le site actuel.

---

## Verdict

**`FRIDAY_GO`**

Les cinq sections demandées existent, fonctionnent sur les vraies données shadow, respectent la règle non négociable (statut = longitudinal uniquement, Today's Challenge visuellement et sémantiquement séparé avec disclaimer explicite), et trois bugs réels ont été trouvés et corrigés par un test en navigateur effectif plutôt qu'une simple relecture de code. Le seul point non complété comme demandé — la vérification visuelle responsive — est documenté honnêtement comme une limite d'outillage de cette session, pas comme un choix de ne pas le faire, et ne bloque pas la suite du sprint : à revérifier manuellement avant dimanche.

---

*Fin du document. Aucun widget modifié. Aucune bascule publique. En attente de Sébastien.*
