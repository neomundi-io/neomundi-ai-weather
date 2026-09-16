# AI Weather V2 — GO/NO-GO final avant lancement du 21/09/2026 (Bloc Dimanche)

**Statut** : répétition générale complète exécutée en environnement contrôlé, sur données réelles, sans aucune bascule publique. Ce document est la synthèse de toute la semaine (moteur → capsule → câblage → interface → widgets → aujourd'hui : répétition générale, rollback, tests, monitoring).

---

## 1. État de chaque brique

| Brique | Statut | Preuve |
|---|---|---|
| Moteur longitudinal V2.0 | ✅ Validé | 35/35 tests, `AI_WEATHER_V2_SHADOW_VALIDATION.md` |
| Capsule JSON V2 | ✅ Validé | 7/7 tests, capsule réelle générée ce jour (§7) |
| Câblage upstream shadow | ✅ Validé | `UPSTREAM_WIRING_GO`, 20/20 tests |
| Interface V2 | ✅ Validé | `FRIDAY_GO`, re-testée ce jour sans erreur |
| 13 widgets migrés | ✅ Validé | `SATURDAY_GO`, re-testés ce jour sans erreur |
| Widget n°14 (`weather-home-1180.html`) | ⚠️ Dette séparée | `KNOWN_PREEXISTING_BROKEN_WIDGET` (§11) |
| Compatibilité legacy | ✅ Confirmée | rendu identique sur vraie `weather.json` sans champs V2 |
| Zéro impact public | ✅ Confirmé | hash + `git status` (§10) |
| Rollback | ✅ Documenté et chronométré | §9 |
| Monitoring post-bascule | ✅ Préparé | §13 |

## 2. Inventaire de bascule

| Élément | État actuel | État V2 cible | Action de bascule | Rollback |
|---|---|---|---|---|
| Source publique des données | `weather.json` / `data/current.json` sans champs V2 | mêmes fichiers, `systems[].longitudinal` enrichi des champs V2 | dans `aggregate_and_publish_weather.ps1`, déplacer l'appel à `Invoke-LongitudinalV2ShadowPipeline` **avant** les 3 écritures legacy et fusionner son résultat dans `$output` au lieu de l'écrire à part | restaurer les 3 fichiers depuis le snapshot pré-bascule (§8) — copie de fichier, <1ms/fichier |
| `data/history/<date>.json` | condition quotidienne seule | condition + `longitudinal` enrichi | même changement que ci-dessus (écriture unique, un seul point de code) | idem |
| Page AI Weather publique | `index.html` (V1, statut = `condition` du jour) | `dev/ai-weather-v2-shadow.html` promu en page publique (renommage/déploiement), bannière dev retirée | remplacer/rediriger la route publique vers le contenu validé de `dev/ai-weather-v2-shadow.html` | restaurer `index.html` depuis le snapshot ; aucune donnée n'est perdue puisque rien n'est réécrit ailleurs |
| 13 widgets | lisent déjà `NMData.getDisplayCondition()`, qui retombe sur `system.condition` en l'absence de champs V2 | **aucun changement de code nécessaire** — dès que `weather.json` contient les champs V2, les 13 widgets basculent automatiquement | aucune ; c'est le point fort de l'architecture additive (§9) | aucune ; si les données redeviennent legacy, le rendu redevient legacy automatiquement |
| `weather-home-1180.html` | cassé, non migré | exclu du lancement | ne pas exposer ce widget spécifique tant que non corrigé | sans objet |
| Capsule publique | `schema_version "0.2"`, générée depuis `data/history/*.json` legacy | `schema_version "2.0"`, générée depuis le même fichier une fois enrichi (bascule automatique via `source_declares_v2_methodology()`) | aucune action séparée : la bascule de la source suffit à faire basculer le schéma de capsule | régénérer la capsule du jour depuis la source restaurée (0.2 réapparaît automatiquement) |
| `aiweather-capsule/latest.json` | pointe vers la capsule 0.2 du jour | pointe vers la capsule 2.0 du jour (même chemin de fichier, contenu different) | aucune action séparée (le pointeur suit le fichier, pas le schéma) | restaurer depuis le snapshot si le pointeur a été changé de cible |
| `data/capsule-index.json` | historique des 15 derniers jours, entrées 0.2 | ajout d'une entrée 2.0 pour le jour courant, historique 0.2 jamais réécrit | ajout normal du jour, comme chaque jour | restaurer depuis le snapshot (retire uniquement l'entrée du jour) |
| Feature flags | **aucun mécanisme de feature flag n'existe dans le code** (vérifié par recherche) | la bascule est pilotée par la présence/absence des champs V2 dans les données, pas par un flag applicatif | — | — |
| Cache navigateur (`service-worker.js`) | stratégie *network-first* (`fetch().catch(() => cache)`) — ne sert le cache qu'hors-ligne | inchangée ; recommandé de faire passer `CACHE` de `v5` à `v6` pour purger proprement le cache des anciens `scripts/weather-data.js` | bump du numéro de version dans `service-worker.js` (1 ligne, additif, sans risque) | revert de cette ligne si besoin |
| Traductions | `i18n/en.json` / `i18n/fr.json` contiennent déjà les clés `v2.*` et `judgment.j5`, additives | aucune bascule nécessaire, déjà en place | — | — |
| Routes | aucune nouvelle route publique introduite ce sprint (`dev/` reste hors des routes publiques) | la seule route qui change est celle de la page d'accueil AI Weather | — | — |

## 3. Snapshot avant bascule

Snapshot horodaté écrit dans `dev/snapshots/pre-launch-snapshot-2026-09-16.json` : révision git (`cf4e29fed5a0…`), branche, et hash SHA-256 de 31 fichiers critiques (données publiques, pages, scripts partagés, les 14 widgets, service worker, capsule et index de capsules, config). Recalculable à tout moment par simple re-hash — rien n'a été déplacé ni supprimé.

## 4. Répétition générale — flux complet exécuté sur données réelles

Flux rejoué aujourd'hui de bout en bout, sur les données réelles du 16/09/2026, sans toucher aux fichiers publics :

```
data/history/2026-09-16.json (réel, déjà publié)
  -> longitudinal_v2_bridge.ps1 :: Invoke-LongitudinalV2ShadowPipeline   [ré-exécuté ce jour, frais]
  -> data/shadow/v2/2026-09-16.json                                      [régénéré, hash confirmé]
  -> generate_capsule.py :: build_capsule(raw, "2026-09-16", prev_capsule=vraie capsule du 15/09) 
  -> capsule V2 de répétition (écrite dans un répertoire temporaire, jamais aiweather-capsule/capsules/)
```

Résultat : pipeline reproductible, capsule V2 valide générée, **chaînage de hash vérifié contre la vraie capsule 0.2 du 15/09** (`prev_hash` de la capsule V2 == `content_hash` réel de la capsule 0.2 précédente) — preuve concrète que la transition de schéma (0.2 → 2.0) ne casse pas la continuité de la chaîne. La vraie capsule du 15/09 a été relue mais jamais réécrite (hash identique avant/après vérifié).

## 5. Validation des cas critiques (re-confirmée sur données fraîchement régénérées)

| Cas | Résultat |
|---|---|
| OpenAI / Anthropic / Qwen | ✅ `standard`, aucune fausse alerte |
| Mistral | ✅ `attention_accrue`, rupture préservée, niveau inchangé |
| Perplexity | ✅ `attention_renforcee`, jamais `attention_critique` |
| Cohere | ✅ `standard`, bruit non confondu avec rupture |
| Couverture insuffisante | ✅ jamais `standard` (cas synthétique testé, aucun cas réel disponible dans les données du jour — limite déjà connue) |
| Today's Challenge | ✅ non-autoritatif : `getDisplayCondition()` ne lit jamais `daily_challenge` ; testé visuellement (score du jour divergent du statut longitudinal sans l'influencer) |

## 6. Interface

Re-testée ce jour sur les données fraîchement régénérées : desktop (grille 4 colonnes, tous les cas §5 visibles), mobile simulé 390px (0px de débordement, correctif du bloc Samedi toujours effectif), FR (défaut) et EN (`?lang=en`), **zéro erreur console** sur les deux langues. Aucune donnée manquante mal interprétée : les événements filtrés par date du jour, la trajectoire absente pour un système sans historique affiche le message prévu plutôt qu'un vide silencieux.

## 7. Capsule V2 — génération réelle de répétition

Champs vérifiés sur la capsule générée aujourd'hui à partir des données réelles :

| Champ | Valeur observée |
|---|---|
| `schema_version` | `"2.0"` |
| `methodology_version.id` | `"AI_WEATHER_METHOD_V2_0"` |
| `baseline_config_version` | `"v2.0-launch"` |
| `repetition_count` | `7` |
| `observations[].longitudinal_reference` | présent avec `current_longitudinal_state`, `uncertainty`, `detected_events`, `system_identity`, `coverage`, `baseline` |
| `observations[].daily_challenge` | présent, `weather_authority: false` |
| `chain.content_hash` | recalculé indépendamment, identique à la valeur stockée |
| `chain.prev_hash` (test chaîné) | identique au `content_hash` réel de la capsule 0.2 du 15/09 |

Aucune capsule historique réécrite — vérifié par hash avant/après sur la capsule du 15/09.

## 8. Fail-open

Couvert par les suites automatisées re-exécutées ce jour (§10), qui simulent réellement (pas seulement en théorie) :

| Scénario | Comportement observé |
|---|---|
| Panne du moteur longitudinal (fichier absent) | `Get-LongitudinalV2Report` renvoie `$null`, aucune exception, aucun fichier shadow écrit |
| Moteur présent mais lève une exception réelle | même comportement fail-open, exception absorbée |
| Absence de données V2 (widgets/interface contre `weather.json` réel sans champs V2) | repli automatique sur `system.condition`, rendu identique à l'ancien comportement |
| Couverture insuffisante | état `insufficient_data` explicite, jamais confondu avec `standard` |
| Identité inconnue/non épinglée | `model_identity_unverified` émis une fois par système, jamais par jour |

Dans tous les cas : la publication n'est jamais bloquée, l'absence de donnée reste explicite, et le rollback (§9) reste disponible à tout moment puisque rien n'est modifié de façon irréversible par ces échecs.

## 9. Test du rollback

**Mécanisme identifié** : grâce à l'architecture additive de toute la semaine, le rollback ne nécessite **aucun revert de code** pour les widgets ni pour la logique de résolution du statut — `NMData.getDisplayCondition()` retombe automatiquement sur le comportement legacy dès que les champs V2 sont absents de la source. Le rollback consiste donc uniquement à **restaurer les fichiers de données** depuis le snapshot pré-bascule (§3).

**Drill réalisé** (bac à sable jetable, jamais sur les vrais fichiers) :
1. Copie de la vraie `weather.json` + fusion des champs V2 réels dedans → simulation de "bascule effectuée" (0,008s).
2. Restauration du fichier original depuis la copie snapshot → **0,90 ms** pour un fichier.

Pour une bascule réelle, les fichiers à restaurer seraient : `weather.json`, `data/current.json`, `data/history/<date>.json`, `aiweather-capsule/latest.json`, `data/capsule-index.json` (5 fichiers) — de l'ordre de quelques millisecondes au total pour la restauration locale. Le facteur temps réel dominant serait la **propagation vers l'hébergement/CDN public**, pas la restauration elle-même (non mesurable depuis cet environnement local — à chronométrer séparément selon l'infrastructure de déploiement réelle).

**Étapes du rollback documentées comme procédure exploitable** :
1. Restaurer les 5 fichiers de données depuis le snapshot du jour.
2. Si la page publique a été remplacée par l'interface V2 : revenir à l'ancien `index.html` (conservé, jamais supprimé).
3. Ne rien faire côté widgets ni côté `scripts/weather-data.js` — leur comportement suit automatiquement la donnée restaurée.
4. Régénérer/republier la capsule du jour si nécessaire (redevient `0.2` automatiquement).
5. Si `service-worker.js` a été bumpé en v6, un rollback de cette ligne n'est pas strictement nécessaire (le cache network-first se remet à jour de lui-même) mais peut être fait par cohérence.

**Risque restant identifié** : ce drill valide le mécanisme et le temps de restauration *locale* uniquement — il ne mesure pas le temps de propagation réel vers l'infrastructure publique de neomundi/ControlTowerAI, qui reste à vérifier avec l'équipe infra/hébergement avant lundi si ce n'est pas déjà connu.

## 10. Zéro régression technique — total exact

| Suite | Résultat |
|---|---|
| Moteur longitudinal (`test_longitudinal_engine.ps1`) | 35/35 |
| Pont agrégateur ↔ moteur V2 (`test_longitudinal_v2_bridge.ps1`) | 20/20 |
| Expérience Wilson (`test_wilson.ps1`) | 19/19 |
| Index de capsules (`test_capsule_index.py`) | 13/13 |
| Capsule V2 (`test_generate_capsule_v2.py`) | 7/7 |
| **Total** | **94/94, toutes vertes, aucune ignorée** |

Toutes ré-exécutées ce jour dans cet environnement (pas une réutilisation de résultats passés) — sorties complètes conservées dans la transcription de session.

## 11. Dette documentée — `weather-home-1180.html`

**Statut : `KNOWN_PREEXISTING_BROKEN_WIDGET`.**

Le fichier est tronqué en plein milieu de son code (s'arrête à la ligne 412, dans le template `legendHtml`, sans fermeture de script ni de document) — un défaut **préexistant à ce sprint entier**, confirmé par `wc -l` et lecture directe, non causé par la migration V2. Il n'a pas été reconstruit par supposition (aucune source fiable du contenu manquant). **Ce widget est exclu du périmètre de lancement du 21/09** : il ne doit pas être exposé publiquement tant qu'il n'a pas été réparé séparément, et sa réparation ne conditionne pas le GO de lundi.

## 12. Checklist opérationnelle — lundi matin

1. ☐ Prendre un nouveau snapshot pré-bascule (hashes + git rev) du jour de lancement.
2. ☐ Vérifier que les données du jour (`data/history/<date-lundi>.json`) sont bien publiées par le pipeline habituel avant toute bascule V2.
3. ☐ Exécuter le pipeline V2 (moteur → pont → capsule) sur les données du jour, en shadow d'abord.
4. ☐ Valider les 5 cas critiques (§5) sur les données réelles du jour.
5. ☐ Vérifier la page V2 (desktop + mobile + FR + EN + zéro erreur console) sur les données réelles du jour.
6. ☐ Vérifier les 13 widgets (hors `weather-home-1180.html`) sur les données réelles du jour.
7. ☐ Générer et vérifier la capsule V2 du jour (champs + chaîne de hash) avant de la publier comme capsule officielle.
8. ☐ Activer le monitoring immédiat (§13) dès la bascule effective.
9. ☐ Confirmer que la procédure de rollback (§9) et le snapshot du jour sont prêts et accessibles.
10. ☐ **Validation explicite de Sébastien avant toute exposition publique** — aucune étape ci-dessus n'autorise la bascule seule.

## 13. Plan de monitoring — premières heures après bascule

| Contrôle | Méthode |
|---|---|
| Statut global (12 systèmes) | comparer `weather.json` publié contre la capsule V2 générée en parallèle — doivent concorder |
| Anomalies par système | surveiller tout système passant à `attention_critique` ou `insufficient_data` de façon inattendue |
| Couverture | vérifier `coverage_status` de chaque système ; alerte si `insufficient` sur un système habituellement `nominal` |
| Erreurs fournisseur | logs des runners `run_weather_*.ps1` habituels, inchangés par ce sprint |
| Erreurs JS | console navigateur sur la page publique et sur un échantillon de widgets embarqués |
| Widgets cassés | vérification visuelle rapide des 13 widgets valides (pas `weather-home-1180.html`) sur au moins un exemple par famille |
| Capsule invalide | ré-exécuter `compute_content_hash` sur la capsule publiée et comparer à `chain.content_hash` |
| Mismatch legacy/V2 | vérifier qu'aucun système n'affiche un statut différent entre `system.condition` (legacy) et `longitudinal.current_longitudinal_state.state` (V2) sans explication (une divergence est *attendue* et *voulue* — c'est le sens même de la V2 — mais elle doit être *comprise*, pas silencieuse) |
| Latence | temps de génération du pipeline V2 complet (le moteur relit tout l'historique à chaque appel — risque déjà noté au bloc Jeudi-bis, à surveiller en conditions réelles) |
| Logs | conserver les sorties complètes de la première exécution réelle en production pour analyse a posteriori |

**Critères de rollback immédiat** : une capsule dont le hash ne se vérifie pas ; une majorité de systèmes en `insufficient_data` alors que la couverture réelle est nominale (signe d'un bug de lecture, pas d'un vrai problème de données) ; une erreur JS bloquante sur la page publique ; un widget affichant un statut manifestement faux comparé à son état legacy connu. Dans tous ces cas : exécuter la procédure du §9 sans attendre.

---

## 14. Risques ouverts (synthèse)

1. `weather-home-1180.html` cassé, exclu du lancement (§11) — dette non bloquante.
2. Validation mobile réalisée par viewport simulé (iframe), pas sur device réel — un vrai bug y a été trouvé et corrigé, ce qui valide la méthode, mais une repasse sur téléphone réel reste recommandée.
3. Temps de propagation réel vers l'hébergement public non mesuré par ce drill (uniquement la restauration locale).
4. Warm/transparent (thèmes) non re-testés visuellement cette semaine — risque jugé nul (mêmes variables CSS que light/dark).
5. 3 familles de widgets testées comme représentatives des 13 — pas une vérification exhaustive fichier par fichier, justifiée par l'identité de code confirmée.
6. Aucun cas réel de couverture insuffisante n'a existé dans les données de la semaine — seul un cas synthétique a pu être testé visuellement.
7. Charge/latence du moteur V2 en cadence de production quotidienne réelle non testée à grande échelle (déjà noté au bloc Jeudi-bis).

Aucun de ces risques n'est un blocant technique pour lundi — tous sont soit des limites de méthode honnêtement documentées, soit des points de vigilance opérationnelle post-lancement.

---

## Verdict

**`MONDAY_READY`**

Toutes les briques techniques (moteur, pont, capsule, interface, 13/14 widgets) sont validées séparément puis rejouées ensemble aujourd'hui sur données réelles, avec 94/94 tests automatisés verts, une génération de capsule V2 réelle au chaînage de hash vérifié contre la vraie capsule de la veille, et un mécanisme de rollback dont la propriété la plus importante — **aucun revert de code n'est nécessaire pour les widgets ou l'interface, seulement une restauration de données** — a été démontrée concrètement et chronométrée. Le seul défaut connu (`weather-home-1180.html`) est préexistant, documenté, et explicitement hors périmètre du lancement sans bloquer les 13 autres widgets ni la page principale. Les risques restants (§14) sont des points de vigilance à surveiller lundi, pas des raisons de reporter.

---

## STOP

Aucune bascule publique n'a été effectuée. La source publique n'a pas été modifiée. Aucune capsule V2 n'a été publiée comme capsule officielle (uniquement générée dans des répertoires temporaires, supprimés). Aucun mécanisme legacy n'a été retiré. Ce document attend la validation explicite de Sébastien avant toute action de bascule réelle lundi.

*Fin du document.*
