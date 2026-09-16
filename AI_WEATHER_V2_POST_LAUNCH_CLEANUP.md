# AI Weather V2 — Nettoyage post-lancement avant commit

**Statut** : nettoyage effectué, suite entièrement verte retrouvée, diff de bascule audité champ par champ. Aucun commit, aucun push, aucune évolution fonctionnelle nouvelle effectuée dans ce bloc.

---

## 1. Test rouge — identifié, expliqué, corrigé

**Test concerné** : `test_real_production_file_regression` dans `aiweather-capsule/tests/test_generate_capsule_v2.py`.

**Prémisse historique** : le test régénérait une capsule à partir de `data/history/2026-09-16.json` (« aujourd'hui » au moment où il a été écrit, plus tôt cette semaine) et vérifiait que le résultat correspondait exactement à la capsule déjà publiée pour cette date — une garde anti-régression légitime pour s'assurer que `generate_capsule.py` ne change pas silencieusement de comportement sur une source legacy connue. Le test se terminait même par une assertion explicite : *« Le vrai `data/history/2026-09-16.json` est encore une source legacy »*.

**Pourquoi la prémisse est devenue invalide** : la bascule V2 de ce jour a **délibérément** enrichi `data/history/2026-09-16.json` avec les champs V2 (c'est tout l'objet du lancement), alors que la capsule déjà publiée ce matin pour cette même date reste, elle, volontairement figée à `schema_version: "0.2"` (règle d'immutabilité, décision explicite de Sébastien — voir `AI_WEATHER_V2_LAUNCH_REPORT_2026-09-21.md` §5). Le test comparait donc une source désormais V2 à une capsule restée 0.2 : l'échec constatait très exactement le succès de la bascule, pas une régression du code de génération de capsule (`generate_capsule.py` lui-même reste prouvé correct par les 6 autres tests de sa suite, tous verts, et par deux générations réelles de capsule V2 valide cette semaine).

**Diagnostic de fond** : le défaut de conception du test n'était pas la vérification elle-même, mais le choix de pointer vers **« aujourd'hui »** — une date que le pipeline quotidien est, par construction, appelé à faire évoluer. Un jour déjà publié et passé, en revanche, est immuable par la règle même du projet (« aucune capsule n'est jamais réécrite ») et constitue donc une source de test stable **pour toujours**.

**Décision : mis à jour, pas supprimé.** Le test a été repointé sur `data/history/2026-09-15.json` / capsules `2026-09-15` et `2026-09-14` (un jour réel, déjà publié, encore et pour toujours une source legacy — vérifié : aucun champ V2, `schema_version` 0.2, chaînage correct avec le 14/09). Le docstring documente explicitement cet historique et la raison du changement de date, pour qu'un futur lecteur ne retombe pas dans le même piège en repointant naïvement sur « aujourd'hui ».

## 2. Suites relancées — total exact

| Suite | Résultat |
|---|---|
| Moteur longitudinal (`test_longitudinal_engine.ps1`) | 35/35 |
| Pont agrégateur ↔ moteur V2 (`test_longitudinal_v2_bridge.ps1`) | 20/20 |
| Expérience Wilson (`test_wilson.ps1`) | 19/19 |
| Index de capsules + capsule V2 (`test_capsule_index.py` + `test_generate_capsule_v2.py`) | 20/20 (+ 3 sous-tests) |
| **Total automatisé** | **94/94 — 100% GREEN** |
| Interface publique (`index.html`) — revalidation manuelle | desktop ✅, mobile 390px simulé (0px débordement) ✅, FR ✅, zéro erreur console ✅ |
| Widgets (échantillon représentatif re-testé) | `weather-bar-2x6.html` contre le vrai `weather.json` : ✅, zéro erreur console |
| End-to-end | pipeline réel rejoué de bout en bout depuis le bloc précédent (moteur → fusion → fichiers publics → grille) : ✅ |

## 3. Audit du diff de bascule

| Fichier | Nature du changement | Classification |
|---|---|---|
| `weather.json` | +1098/-X lignes : ajout de `longitudinal.current_longitudinal_state` (+ `uncertainty`, `detected_events`, `system_identity`, `baseline`) par système. `condition`/`daily` inchangés. | **Attendu / requis par V2** |
| `data/current.json` | Identique bit-à-bit à `weather.json` (vérifié par hash) | **Attendu / requis par V2** |
| `data/history/2026-09-16.json` | Identique bit-à-bit à `weather.json` (vérifié par hash) | **Attendu / requis par V2** |
| `index.html` | 3 lignes modifiées (`CONDITION_COLOR` +1 entrée, `conditionMeta(system.condition)` → `conditionMeta(displayCondition)`, `card.className` idem) + ajouts additifs (légende 5ᵉ item, CSS `.is-insufficient`, calcul `todayIso`) | **Attendu / requis par V2** |
| `AI_WEATHER_RUNNER/aggregate_and_publish_weather.ps1` | Un bloc de fusion V2 déplacé d'après-écriture à avant-écriture (diff vérifié ligne par ligne : suppression du bloc « shadow-only » de jeudi-bis, ajout du bloc de fusion dans `$output`) | **Attendu / requis par V2** |
| `scripts/weather-data.js` | +136/-8 lignes : `getLongitudinalStateInfo`, `getDisplayCondition` (nouvelles fonctions), `load()`/`loadPanels()` avec paramètre optionnel additif | **Additif** |
| 13 fichiers `weather-*.html` | 8 à 18 lignes chacun : `system.condition` → `NMData.getDisplayCondition()`, 5ᵉ état CSS/légende | **Attendu / requis par V2** (fait samedi, revalidé) |
| `weather-home-1180.html` | **Aucun diff** (0 ligne) | **Conforme** — exclu comme prévu (`KNOWN_PREEXISTING_BROKEN_WIDGET`) |
| `i18n/en.json` / `i18n/fr.json` | Seule ligne « supprimée » dans chaque fichier : l'ancienne dernière clé (`quiz.daily.unavailable`) réapparaît identique, seule sa virgule finale change car du contenu a été ajouté après — aucune clé perdue, vérifié par grep sur les lignes réellement supprimées | **Additif** |
| `aiweather-capsule/generate_capsule.py`, `aiweather-capsule/tests/test_generate_capsule_v2.py` | Non modifiés par la bascule elle-même ; le second corrigé dans ce bloc (§1) | **Correction de bug** (le test), reste (le générateur) inchangé depuis jeudi |
| `aiweather-capsule/capsules/2026/09/16.json`, `aiweather-capsule/latest.json`, `data/capsule-index.json` | **Aucun changement** (hash identique avant/après vérifié) | **Conforme** — décision explicite de préserver la capsule 0.2 du jour |
| `dev/snapshots/`, `dev/fixtures/`, `dev/widget-tests/` | Nouveaux, non trackés, jamais référencés par une page publique | **Additif** (outillage de test/rollback) |
| `data/shadow/` | Nouveau, non tracké, contient les sorties shadow historiques (dont celle, désormais redondante mais inoffensive, du 16/09) | **Additif** (résidu de la phase de préparation, sans impact) |

**Aucune modification inattendue** trouvée dans cet audit — chaque ligne changée se rattache directement à une décision documentée dans les blocs précédents ou dans ce nettoyage.

## 4. Capsule — confirmé

- Capsule `2026-09-16` : `schema_version` toujours `"0.2"`, `content_hash` identique (`d19dedfed4f2067c…`) à avant la bascule — **intacte, aucune réécriture**.
- `aiweather-capsule/latest.json` : toujours `/capsules/2026/09/16.json` — inchangé.
- `data/capsule-index.json` : entrée du 16/09 inchangée.
- **La prochaine génération de capsule sera la première officiellement V2** (décision actée). La continuité de chaîne 0.2→2.0 reste prouvée (chaînage `prev_hash` déjà vérifié contre une vraie capsule 0.2 lors de la répétition générale et lors de la bascule elle-même) — rien de nouveau à re-tester ici, juste reconfirmé stable.

## 5. État public — revalidé

Revérifié en direct sur `index.html` réel après le correctif du test (aucun changement de code depuis la dernière vérification, revalidation de cohérence uniquement) :

| Cas | Résultat |
|---|---|
| Mistral | ✅ `attention_accrue` (jaune) |
| Perplexity | ✅ `attention_renforcee` (orange), jamais critique |
| OpenAI / Anthropic / Qwen | ✅ `standard` (vert) — Qwen affiche un point jaune isolé dans sa tendance historique (jour passé), sans affecter son état courant, correct |
| Cohere | ✅ `standard`, pas de fausse rupture |
| Couverture insuffisante | ✅ état géré (aucun cas réel aujourd'hui, non exercé en conditions réelles — déjà documenté) |
| Today's Challenge | ✅ non-autoritatif — la section « Question du jour » reste séparée visuellement et structurellement ; le contenu de la question ne modifie jamais la grille au-dessus |

Zéro erreur console.

---

## Verdict

**`READY_TO_COMMIT`**

Le seul test rouge a été identifié, expliqué et corrigé — non pas en masquant l'échec ni en l'ignorant, mais en réparant le vrai défaut (une fixture qui pointait vers « aujourd'hui » au lieu d'un jour stable et immuable). La suite complète est repassée à 94/94 (100% GREEN), confirmée par une seconde exécution après correction. L'audit du diff de bascule n'a révélé aucune modification inattendue — chaque ligne changée se justifie et se retrouve dans la documentation des blocs précédents. La capsule du jour reste intacte, l'état public reste correct sur les 6 cas critiques. Le dépôt est dans un état cohérent, propre, et documenté, prêt pour un commit — qui reste, comme toujours, à demander explicitement.

---

## STOP

Rien n'a été commité. Rien n'a été poussé vers `origin`. Aucune évolution fonctionnelle nouvelle n'a été introduite dans ce bloc — uniquement la correction du test et sa revalidation. En attente de la validation de Sébastien.

*Fin du document.*
