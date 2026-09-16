# AI Weather V2 — Validation du câblage amont (Bloc Jeudi-bis)

**Statut** : câblage préparé et démontré en shadow/dry-run uniquement. Aucun statut public, `weather.json`, widget, capsule historique ou route publique n'a changé.

---

## 1. Flux avant

```
run_weather_*.ps1 (12 scripts, deja executes plus tot dans la journee)
    -> AI_WEATHER_RUNNER/results/<date>/*_results.jsonl (donnees brutes, inchangees)
    -> aggregate_and_publish_weather.ps1
         Get-ProbeAggregate (role=daily)       -> $daily  (condition reelle)
         Get-ProbeAggregate (role=longitudinal) -> $longitudinal (condition: null, jamais interprete)
         $systems += $system   (ligne 1382, systems[].daily / systems[].longitudinal)
    -> Set-Content weather.json / data/current.json / data/history/<date>.json
       (memes $json, lignes 1966-1993)
    -> (plus tard, separement) generate_capsule.py --input data/history/<date>.json
    -> capsule schema_version "0.2", aucun champ V2
```

## 2. Flux après (implémenté, actif uniquement en sortie shadow)

```
... (identique jusqu'a la ligne 1993, AUCUN changement avant ce point) ...
-> [NOUVEAU, ligne ~1996] try {
       . longitudinal_v2_bridge.ps1
       Invoke-LongitudinalV2ShadowPipeline($output, $runnerRoot, $repoRoot, $Date)
           -> Get-LongitudinalV2Report          (dot-source longitudinal_engine.ps1,
                                                   relit tout l'historique y compris le
                                                   data/history/<date>.json qui vient
                                                   d'etre ecrit ci-dessus)
           -> Merge-LongitudinalV2IntoHistory    (clone $output via JSON round-trip,
                                                   injecte les champs V2 DANS
                                                   systems[].longitudinal, jamais dans
                                                   systems[].daily)
           -> Write-ShadowHistoryV2              (ecrit UNIQUEMENT
                                                   data/shadow/v2/<date>.json)
   } catch { log seulement, ne bloque rien }
-> (nouveau, a la demande) generate_capsule.py --input data/shadow/v2/<date>.json
-> capsule V2 de test, schema_version "2.0", longitudinal_reference + daily_challenge
   (ecrite dans un dossier temporaire, jamais aiweather-capsule/capsules/)
```

## 3. Fonctions et fichiers modifiés

| Fichier | Nature du changement |
|---|---|
| `AI_WEATHER_RUNNER/longitudinal_v2_bridge.ps1` | **Nouveau**. 5 fonctions pures (`Get-LongitudinalV2Report`, `Test-LongitudinalV2SystemUsable`, `Merge-LongitudinalV2IntoHistory`, `Write-ShadowHistoryV2`, `Invoke-LongitudinalV2ShadowPipeline`). Aucune instruction au niveau racine — dot-sourcer ce fichier n'a aucun effet de bord. |
| `AI_WEATHER_RUNNER/aggregate_and_publish_weather.ps1` | **~25 lignes ajoutées**, strictement après les 3 écritures legacy (ligne 1993) et avant la section "18. Console report" — un dot-source conditionnel (`Test-Path`) et un appel unique, le tout enveloppé dans un `try/catch` qui ne fait que journaliser. Aucune ligne existante modifiée ou supprimée. |
| `AI_WEATHER_RUNNER/tests/test_longitudinal_v2_bridge.ps1` | **Nouveau**. 20 tests. |
| `aiweather-capsule/tests/test_generate_capsule_v2.py` | Complété d'1 test consommant la vraie sortie shadow. |

**Principe respecté (section 2 de la commande)** : aucune réimplémentation de baseline/MAD/plancher/états/événements/uncertainty. Le pont ne fait qu'appeler `Invoke-LongitudinalEngine` (source unique de vérité, `longitudinal_engine.ps1`) et projeter son résultat.

## 4. Mécanisme shadow

`data/shadow/v2/YYYY-MM-DD.json` — chemin entièrement nouveau, jamais lu par `index.html`, `scripts/weather-data.js`, aucun widget, ni `generate_capsule.py` en usage normal (celui-ci continue de recevoir `data/history/*.json` en production ; `data/shadow/v2/*.json` ne lui est passé qu'explicitement, à la main, pour ce test).

## 5. Mécanisme fail-open

Double protection : (a) chaque fonction du pont a son propre `try/catch` interne renvoyant `$null` ; (b) le site d'appel dans l'agrégateur enveloppe l'ensemble dans un second `try/catch` qui se contente de journaliser. Le bloc est placé **après** les trois écritures de production réussies — une panne totale du moteur V2, à ce point du script, ne peut structurellement plus rien empêcher.

**Testé, pas seulement affirmé** :
- Moteur/config introuvables → `$null` renvoyé, aucune exception, aucun fichier écrit.
- Moteur présent mais qui lève une exception réelle (simulée avec un faux `longitudinal_engine.ps1` contenant `throw "simulated engine crash"`) → `$null` renvoyé, aucune exception propagée.

## 6. Résultat end-to-end (données réelles, 2026-09-16)

Pipeline complet exécuté avec les vraies données du 16/09/2026 (`data/history/2026-09-16.json` réel en entrée) : succès, écriture confirmée à `data/shadow/v2/2026-09-16.json`.

## 7. Capsule V2 réellement générée à partir du pipeline shadow réel

Tous les champs demandés, vérifiés par test automatisé sur la capsule réellement produite (pas une fixture manuelle) :

| Champ | Valeur observée |
|---|---|
| `schema_version` | `"2.0"` |
| `methodology_version.id` | `"AI_WEATHER_METHOD_V2_0"` |
| `baseline_config_version` | `"v2.0-launch"` |
| `repetition_count` | `7` |
| `observations[].longitudinal_reference` | présent, avec `current_longitudinal_state`, `uncertainty`, `detected_events`, `system_identity`, `coverage`, `baseline` |
| `observations[].daily_challenge` | présent, `weather_authority: false` |
| Chaîne de hash | `compute_content_hash` re-vérifié indépendamment, identique à `chain.content_hash` |

## 8. Tests — 94/94 réussis

| Suite | Résultat |
|---|---|
| Moteur longitudinal (`test_longitudinal_engine.ps1`) | 35/35 |
| Expérience Wilson (`test_wilson.ps1`) | 19/19 |
| Pont agrégateur ↔ moteur V2 (`test_longitudinal_v2_bridge.ps1`, nouveau) | 20/20 |
| Index de capsules (`test_capsule_index.py`) | 13/13 |
| Capsule V2 (`test_generate_capsule_v2.py`) | 7/7 |

**Une régression réelle trouvée et corrigée pendant ce bloc, documentée par honnêteté** : la première version du pont écrivait les champs V2 dans une clé sœur `systems[].longitudinal_v2`, alors que `generate_capsule.py` (bloc de jeudi) les attend **à l'intérieur** de `systems[].longitudinal` lui-même. Le test end-to-end réel (section 6/7) l'a détecté immédiatement ; corrigé, re-testé, 94/94 verts après correction.

## 9. Preuve d'impact public zéro

Hachage SHA-256 avant/après le test end-to-end complet sur 7 fichiers, incluant l'agrégateur lui-même : `weather.json`, `data/current.json`, `data/history/2026-09-16.json`, la capsule réelle du 16/09, `index.html`, `scripts/weather-data.js`, et `aggregate_and_publish_weather.ps1` — **tous identiques bit à bit avant/après**. `git status` confirme que les seules nouveautés introduites par ce bloc sont sous `data/shadow/` (nouveau, non lié à la production) ; `AI_WEATHER_RUNNER/` reste intégralement gitignoré. Les modifications de `config/panel.yml`/`index.html` visibles dans `git status` préexistaient à ce tour et n'ont aucun rapport avec ce bloc.

**Note importante** : `aggregate_and_publish_weather.ps1` a été modifié (section 3) mais **jamais exécuté** dans ce tour — il n'a pas de garde d'entrée comme `longitudinal_engine.ps1`, donc l'invoquer (même par dot-sourcing) déclencherait immédiatement ses écritures réelles. Le test end-to-end (section 6) rejoue exactement le même appel que ferait l'agrégateur (`Invoke-LongitudinalV2ShadowPipeline` avec les mêmes types de paramètres réels), sans exécuter les ~2000 autres lignes du script. La preuve de non-régression sur l'agrégateur lui-même est donc double : validation syntaxique complète du fichier modifié (`[System.Management.Automation.Language.Parser]::ParseFile`, 0 erreur) + hachage bit-à-bit du fichier confirmant qu'aucune écriture ne l'a modifié.

## 10. Rollback

Supprimer `AI_WEATHER_RUNNER/longitudinal_v2_bridge.ps1` (l'agrégateur continue de fonctionner normalement : le nouveau bloc est gardé par un `Test-Path`, son absence est silencieusement tolérée) ; retirer les ~25 lignes ajoutées à `aggregate_and_publish_weather.ps1` (section 3, délimitées par des commentaires explicites) ; supprimer `data/shadow/`. Aucune des trois actions n'affecte quoi que ce soit d'autre.

## 11. Risques restant ouverts

1. Le moteur V2 relit l'intégralité de l'historique (26+ jours, 12 systèmes) à chaque appel — non testé en charge/latence à la cadence de production quotidienne réelle, à vérifier avant lundi.
2. Aucune purge/rotation prévue pour `data/shadow/v2/*.json` — accumulation illimitée si ce câblage tourne quotidiennement après le lancement.
3. `aggregate_and_publish_weather.ps1` n'a pas de garde d'entrée : toute validation future de ce fichier devra continuer à passer par une analyse statique (syntaxe, relecture) plutôt qu'une exécution directe, sauf à lui ajouter un tel garde — non fait aujourd'hui pour rester strictement additif.
4. Le cas "couverture insuffisante" demandé en section 6 n'a pas pu être testé sur une donnée réelle du 16/09/2026 : aucun des 12 systèmes n'était en couverture insuffisante ce jour-là. `Test-LongitudinalV2SystemUsable` est couvert par les tests synthétiques du moteur (35 tests, dont le test 5 dédié), mais pas par ce test end-to-end spécifique — à revérifier le jour où un tel cas réel se présentera.
5. Le bug d'intégration trouvé en section 8 (mauvais emplacement de fusion) confirme la valeur du test end-to-end réel par rapport aux fixtures manuelles isolées — aucune garantie qu'un défaut similaire n'existe pas ailleurs dans une zone non encore testée bout en bout (ex. un système avec un `longitudinal` legacy absent plutôt que présent-mais-vide — géré par un `continue` explicite, mais non exercé par une donnée réelle aujourd'hui).

---

## Verdict

**`UPSTREAM_WIRING_GO`**

Le flux complet (moteur V2 → sortie history-like enrichie → capsule V2) est démontré de bout en bout sur données réelles, avec un mécanisme fail-open testé (pas seulement conçu), une preuve d'impact public nul vérifiée par hachage sur le fichier de l'agrégateur lui-même, et 94/94 tests verts après correction d'une régression réelle trouvée en cours de route. Les risques restants (§11) sont des points de vigilance opérationnelle pour la suite du sprint, pas des raisons de bloquer ce bloc.

---

*Fin du document. Aucune bascule publique effectuée. Aucun widget ni interface modifié. En attente de Sébastien.*
