# AI Weather V2 — Plan de mise en production (lundi 21 septembre 2026)

**Statut** : plan de sprint + décision de méthodologie de lancement. Ce document ne bascule rien en production. Aucun fichier public, capsule historique, widget ou API publique n'est modifié par ce document lui-même.

**Principe directeur** : ce qui a déjà été validé sur des données réelles devient le socle du lancement. Ce qui reste ouvert (N=7 vs N=14, calibration Wilson) devient un chantier shadow post-lancement, explicitement versionné pour ne jamais réécrire l'histoire du V2.0.

---

## 1. Méthodologie de lancement figée

Synthèse de tous les travaux existants (audit, architecture, implémentation, Gates, études de résolution et d'estimateur, expérience Wilson) en une configuration unique, défendable, et déjà en grande partie testée.

| Décision | Valeur retenue pour le lancement | Fondement |
|---|---|---|
| Nombre de répétitions (`repetition_count`) | **7** | Seule configuration validée sur données réelles à ce jour (25 tests Phase 1 + 19 tests Wilson) ; N=14 n'a produit aucune donnée réelle (arme live jamais lancée, Gate §9 : `NEEDS_STATISTICAL_RULE_FIX`) |
| Tendance centrale de la baseline | Médiane sur les 14 premiers jours valides depuis le 21/08/2026 | Inchangé depuis la Phase 1, déjà testé |
| Dispersion | **MAD avec plancher explicite**, pas de MAD brut | **Nouvelle décision de ce tour** — corrige le seul cas de non-régression qui échouait (Perplexity, voir §2) |
| Détection d'état/rupture | Écart normalisé (médiane/MAD-plancher) + hystérésis de persistance (2/3/3 jours), moteur déjà construit et testé | Repris tel quel de la Phase 1 — c'est la seule règle de détection déjà validée sur les 3 cas de non-régression demandés |
| Rôle de Wilson | **Descriptif uniquement** (`uncertainty`), jamais déclencheur d'état | Voir §2 — aucun niveau de confiance Wilson n'a satisfait les 4 critères de la Gate précédente |
| Événements `WHAT CHANGED?` | Les 7 événements déjà conçus (Architecture §5), calculés par le moteur déjà testé | Inchangé |
| Autorité du statut météo | **Le canal longitudinal devient l'autorité** du statut "AI Weather" public ; `daily_challenge` devient définitivement non-autoritatif | Bascule explicitement prévue depuis la Gate de validation (§0, modèle à 3 états) — c'est l'état 3, celui que ce lancement doit produire |
| Méthodologie | `AI_WEATHER_METHOD_V2_0` | §3 |

**Aucune expérience N=14 non terminée ne bloque cette configuration** — elle n'y figure nulle part comme dépendance.

---

## 2. Rôle exact de Wilson — séparation des responsabilités

Le seuil Wilson n'est **pas** calibré pour "faire repasser Mistral" — au contraire, la Gate précédente a explicitement constaté qu'aucun niveau fixe (95/90/80 %) ne satisfait à la fois la détection de Mistral, la stabilité d'OpenAI/Anthropic/Qwen, l'absence de faux positif Perplexity et l'absence d'inflation ailleurs. **Décision : Wilson n'entre dans aucune décision d'état pour le lancement.**

| Responsabilité | Mécanisme retenu pour V2.0 | Où |
|---|---|---|
| Estimation d'incertitude (descriptive) | Intervalle de Wilson 90 %, calculé et exposé tel quel, jamais interprété comme seuil | Nouveau champ `uncertainty` du contrat JSON (§5) |
| Détection d'événement / rupture | Écart normalisé médiane/MAD-plancher | Moteur déjà testé, plancher ajouté (§4) |
| Persistance temporelle (anti-flapping) | Hystérésis 2/3/3 jours, déjà validée (25 tests Phase 1 + vérifiée sans oscillation dans l'expérience Wilson) | Moteur, inchangé |
| Détermination de l'état météo public | Sévérité par palier (Standard/Attention accrue/renforcée/critique/Insufficient data) | Moteur, avec le plancher de MAD comme seule correction |

**Correction du plancher de MAD** (nouvelle décision, justifiée par les données déjà collectées) : le plancher `epsilon` actuel (0,0001) permettait techniquement d'éviter une division par zéro, mais laissait un `deviation_index` numériquement absurde (jusqu'à -290 000 sur les cas déjà documentés) et surtout laissait Perplexity sauter directement au palier `attention_critique` dès qu'une déviation modeste (71→57, soit un seul pas de la grille à 8 valeurs) se répétait, puisque toute déviation devient "infinie" en unités de MAD quand MAD=0. **Nouveau plancher : la moitié d'un pas de la grille de score**, soit `100 / repetition_count / 2` ≈ **7,14 points pour N=7** — une valeur dérivée directement de la granularité déjà documentée (étude de résolution du protocole), pas un réglage arbitraire. Avec ce plancher, une déviation d'un seul pas (14,3 points) vaut désormais 2 unités de MAD-plancher — exactement à la frontière `attention_accrue`/`attention_renforcée`, jamais un saut direct à `critique`.

**Cas de non-régression, vérifiés avant tout déploiement (voir §10 pour le statut d'exécution réelle de ce tour)** :
1. **Rupture Mistral déjà confirmée** → doit rester détectée (`persistent_deviation`, `attention_accrue`) — le plancher ne change rien pour Mistral (MAD=14, très au-dessus du plancher 7,14).
2. **Faux positif Perplexity** → ne doit plus sauter directement à `attention_critique` sur une déviation modeste — corrigé par le plancher.
3. **Stabilité OpenAI/Anthropic/Qwen** → doit rester `standard` en continu — inchangé, ces systèmes ne dépendent pas du plancher puisqu'ils ne dévient quasiment jamais.

---

## 3. Versionnement de la méthodologie

| Champ | Valeur de lancement | Portée |
|---|---|---|
| `methodology_version` | **`AI_WEATHER_METHOD_V2_0`** | Identité de l'algorithme : médiane/MAD-plancher, hystérésis 2/3/3, 7 événements, Wilson descriptif uniquement, N=7 |
| `baseline_config_version` | `v2.0-launch` | Valeurs numériques précises : fenêtre 14 jours, seuils 1.0/2.0/3.0, persistance 2/3/3, plancher MAD = 7,14, confiance Wilson descriptive = 90 % |
| `repetition_count` | `7` | Externalisé, jamais codé en dur — un futur passage à 14 change ce seul champ |

**Règle de non-réécriture de l'histoire** : toute évolution future (N=14, changement de formule) crée `AI_WEATHER_METHOD_V2_1` (ou une version ultérieure) et une nouvelle `baseline_config_version` — les capsules déjà publiées sous `AI_WEATHER_METHOD_V2_0` ne sont jamais recalculées ni réétiquetées rétroactivement. Une comparaison entre deux périodes de versions différentes est explicitement signalée comme non directement comparable (déjà spécifié dans la Gate §3.C).

---

## 4. Finalisation du moteur V2 (production)

Construit par extension additive de `AI_WEATHER_RUNNER/longitudinal_engine.ps1` (Phase 1, déjà 25 tests) — **pas une réécriture**.

**Ajouts nécessaires** :
- Plancher de MAD (§2), externalisé dans `longitudinal_engine_config.json`.
- Calcul de l'intervalle de Wilson par jour et par système (déjà implémenté et testé dans `wilson_n14_experiment/compute_wilson_retrospective.ps1`) intégré comme champ `uncertainty`, jamais comme entrée du calcul d'état.
- `methodology_version`/`baseline_config_version`/`repetition_count` explicitement portés dans la sortie.
- `evidence_integrity` (identité de modèle, `identity_status`, chaîne de capsule) déjà partiellement défini (Gate §2.A) à finaliser dans le schéma de sortie.

**Contraintes, toutes déjà respectées par la conception existante, à ne pas régresser** :
- Aucune capsule historique réécrite (immuabilité déjà garantie par `generate_capsule.py`).
- Architecture additive et fail-open (déjà le principe du moteur Phase 1).
- Données manquantes ≠ stabilité (`insufficient_data` déjà distinct de `standard`, testé).
- Identité incertaine visible (`system_identity.identity_status`, déjà implémenté).
- Today's Challenge totalement séparé (partition stricte des lignes déjà démontrée, Gate §1).
- Rollback trivial (fichiers additifs, suppression sans effet sur l'existant).
- **Aucune primitive continue opaque de l'API externe comme entrée principale supplémentaire** — le moteur continue de n'utiliser que `decision` (ALLOW/FLAG/ERROR), exactement comme aujourd'hui ; Wilson lui-même n'utilise que ce même comptage, jamais `stability_score`/`g_score`/`esi_*`.

---

## 5. Contrat JSON V2 (capsule)

Extension additive du schéma déjà spécifié (Architecture §7), avec les champs supplémentaires requis par ce sprint :

```jsonc
{
  "schema_version": "3.0",
  "methodology_version": "AI_WEATHER_METHOD_V2_0",
  "baseline_config_version": "v2.0-launch",
  "repetition_count": 7,
  "evidence_integrity": { "chain": { /* existant */ }, "capsule_generator_note": "reconstructed_v0.2" },
  "systems": [
    {
      /* --- champs existants, inchangés (compatibilité widgets) --- */
      "id": "mistral", "model": "...", "model_display": "...",
      "daily_challenge": { /* ex-"daily", renommé pour clarte editoriale, weather_authority:false desormais */ },

      /* --- nouveau bloc, devient l'autorite publique --- */
      "longitudinal_reference": {
        "weather_authority": true,
        "repetition_count": 7,
        "baseline": { "status": "established", "window_start": "...", "median": 86, "mad": 14, "mad_floor_applied": false },
        "uncertainty": { "estimator": "wilson_90pct_descriptive", "low": 54.8, "mid": 75.8, "high": 96.7 },
        "current_longitudinal_state": { "state": "attention_accrue", "deviation_index": -1.07, "as_of": "..." },
        "coverage": { "value": 1.0, "status": "nominal" },
        "system_identity": { "model_declared": "...", "model_requested": "...", "model_returned": null, "identity_status": "declared" },
        "detected_events": [ /* les 7 types definis en Architecture §5 */ ]
      }
    }
  ]
}
```

**Compatibilité descendante** : tous les champs déjà lus par `index.html`/`scripts/weather-data.js`/les widgets existants (`global_condition`, `panel_summary`, `systems[].condition/score/coverage/model/model_display`) **restent présents et inchangés** pendant la période de transition — ils cessent d'être présentés comme "the weather" dans l'interface (§6) mais ne disparaissent pas du JSON, pour ne casser aucun consommateur externe qui les lit directement.

---

## 6. Interface V2

Hiérarchie imposée, dans l'ordre : **état → changement → trajectoire → challenge du jour**.

| # | Section | Source de données | Composant |
|---|---|---|---|
| 1 | **AI WEATHER** | `longitudinal_reference.current_longitudinal_state` (nouvelle autorité) | Remplace le mur actuel comme statut principal affiché |
| 2 | **WHAT CHANGED?** | `longitudinal_reference.detected_events` (max 3, les plus significatifs) | Nouveau composant, état vide explicite si aucun événement |
| 3 | **TODAY'S CHALLENGE** | `daily_challenge` (ex-mur actuel), explicitement non-autoritatif | Mur existant, reformulé éditorialement |
| 4 | **MODEL DETAIL** | Trajectoire complète + baseline + `uncertainty` + historique d'événements | Nouvelle vue par système |
| 5 | **METHODOLOGY / DATA** | `methodology_version`, limites d'interprétation, lien JSON brut | Page consolidée, absente aujourd'hui (bloqueur déjà noté, Gate §11.8) |

---

## 7. Widgets — migration sans casse

**Fichiers concernés** (inventoriés dans l'audit d'exposition) : `weather-bar-{2x6,5,6,10,us-320}.html`, `weather-sidebar-{5,8,12,12-v2,12-220,us5}.html`, `weather-block-3x4-logos.html`, `weather-home-1180.html`, `weather-icons-320.html`, `core-panel.html`, `provider-widget.html`, `widget.html`, `index_full.html`.

**Stratégie** : additive uniquement (§5) — aucun widget n'est modifié dans l'immédiat. Une fois le JSON V2 publié, chaque widget continue de fonctionner à l'identique (il lit toujours `systems[].condition`, désormais alimenté par `daily_challenge.condition`, valeur identique à aujourd'hui). Le remplacement du statut affiché par le statut longitudinal se fait widget par widget, après le lancement du cœur V2, jamais en un seul geste sur les 14 fichiers.

**Tests requis avant bascule** : ouverture manuelle de chacun des 14 fichiers avec le JSON V2 étendu, confirmation de rendu identique à l'actuel.

---

## 8. N=14 en shadow — après le lancement

Déjà construit et testé (`AI_WEATHER_RUNNER/shadow/longitudinal_engine.ps1`, `AI_WEATHER_RUNNER/shadow/wilson_n14_experiment/`) — **continue de tourner en parallèle, jamais lu par la production**. Aucune fonctionnalité du 21/09 n'en dépend. Une décision future de passer à N=14 produira `AI_WEATHER_METHOD_V2_1` et sa propre `baseline_config_version`, sans jamais recalculer les données déjà publiées sous `AI_WEATHER_METHOD_V2_0`.

---

## 9. Plan de sprint

### Mercredi 16/09 (aujourd'hui)
- **Fichiers** : `AI_WEATHER_RUNNER/longitudinal_engine_config.json` (plancher MAD, versions), `AI_WEATHER_RUNNER/longitudinal_engine.ps1` (plancher, Wilson descriptif, champs de version)
- **Résultat attendu** : moteur V2 produisant les 3 cas de non-régression corrects
- **Tests** : suite existante étendue (25 → ~30 tests), 3 assertions dédiées aux cas de non-régression
- **GO/NO-GO** : les 3 cas de non-régression passent, zéro fichier public touché

### Jeudi 17/09
- **Fichiers** : `aiweather-capsule/generate_capsule.py` (extension additive), nouveau `AI_WEATHER_V2_SCHEMA.md`
- **Résultat attendu** : capsule V2 complète générable sur une copie de test, `verify_chain.py` toujours vert
- **Tests** : golden-file diff avant/après sur une capsule de test, chaîne de hash vérifiée
- **GO/NO-GO** : aucune régression de schéma sur les champs existants

### Vendredi 18/09
- **Fichiers** : `index.html`, `scripts/weather-data.js` (extension), nouvelle vue Model Detail
- **Résultat attendu** : les 3 premières sections de la hiérarchie (§6) fonctionnelles sur données réelles
- **Tests** : parcours navigateur (chemin nominal, aucun événement, un système en attention_critique, couverture insuffisante)
- **GO/NO-GO** : rendu correct sur les 4 scénarios, wording revu contre l'invariant "comportement jamais modèle"

### Samedi 19/09
- **Fichiers** : les 14 widgets (§7), `config/panel.yml` (vérification, pas de modification de logique)
- **Résultat attendu** : les 14 widgets rendent correctement avec le JSON V2
- **Tests** : ouverture manuelle de chacun, comparaison visuelle avant/après
- **GO/NO-GO** : zéro régression visuelle sur l'ensemble des widgets

### Dimanche 20/09
- **Fichiers** : aucun nouveau — répétition générale complète
- **Résultat attendu** : snapshot de `weather.json`/`data/current.json`/toutes les capsules avant bascule ; procédure de rollback testée au moins une fois
- **Tests** : audit zéro régression sur l'ensemble du site, simulation d'une panne du moteur longitudinal (doit rester fail-open)
- **GO/NO-GO** : rollback démontré fonctionnel, snapshot pris, aucune anomalie ouverte non documentée

### Lundi 21/09
- **Bascule contrôlée**, uniquement après validation explicite de Sébastien — jamais automatique

---

## 10. Statut réel à l'instant présent (ce tour)

Voir la réponse qui suit ce document pour : ce qui est déjà terminé, ce qui reste à coder, ce qui reste à tester, les blocages potentiels, et le prochain bloc de travail.

---

*Fin du plan. Aucune bascule publique effectuée. En attente de validation avant toute exécution.*
