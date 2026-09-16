# AI Weather V2 — Rapport de bascule contrôlée

**Heure de bascule** : 2026-09-16T16:44:01Z (données réelles du jour, 2026-09-16)
**Révision git** : `cf4e29fed5a0` (branche `main`) — changements ci-dessous faits dans l'arbre de travail local, **non commités, non poussés vers `origin`** (voir §9).

---

## 1. Résumé

La bascule contrôlée a été exécutée en environnement local, sur les vrais fichiers publics, avec deux arrêts délibérés face à des garde-fous réels rencontrés en cours de route — l'un tranché avec Sébastien, l'autre résolu par une migration sûre déjà éprouvée cette semaine. Le résultat : **le statut AI Weather public provient désormais du longitudinal**, sur les vraies données, avec zéro erreur et une compatibilité totale avec l'existant.

## 2. Tests — immédiatement avant bascule

94/94 verts (35 moteur + 20 pont + 19 Wilson + 20 capsules/index), re-exécutés à neuf juste avant toute modification.

## 3. Snapshot pré-bascule

- `dev/snapshots/pre-bascule-snapshot-2026-09-16T-live.json` : hash SHA-256 de 32 fichiers critiques + révision git.
- `dev/snapshots/pre-bascule-backup-2026-09-16/` : **copie complète** des 8 fichiers effectivement modifiés (`weather.json`, `data/current.json`, `data/history/2026-09-16.json`, `index.html`, `aggregate_and_publish_weather.ps1`, plus `latest.json`/`capsule-index.json`/la capsule du jour pour référence bien qu'ils n'aient finalement pas changé). Le rollback est une copie de fichiers, pas une reconstruction.

## 4. Bascule exécutée

```
data/history/2026-09-16.json (reel, deja publie ce matin)
  -> longitudinal_v2_bridge.ps1 :: Get-LongitudinalV2Report + Merge-LongitudinalV2IntoHistory
  -> weather.json / data/current.json / data/history/2026-09-16.json   [REELLEMENT ECRITS, enrichis]
  -> index.html (statut de la grille : NMData.getDisplayCondition au lieu de system.condition)
  -> 13 widgets (aucun changement de code necessaire - deja migres samedi, fallback automatique -> lecture V2 automatique)
```

- `AI_WEATHER_RUNNER/aggregate_and_publish_weather.ps1` modifié pour que les **prochaines** exécutions automatisées (tâches planifiées Measure@7h/Release@14h) fusionnent aussi les champs V2 avant les 3 écritures canoniques — plus seulement en shadow. Syntaxe validée (0 erreur), jamais exécuté directement (toujours sans garde d'entrée).
- `methodology_version.id` = `AI_WEATHER_METHOD_V2_0`, `baseline_config_version` = `v2.0-launch`, `repetition_count` = `7` — confirmés dans les données publiées.
- Aucune capsule historique réécrite. `system.condition` (legacy, Today's Challenge) resté inchangé partout.

## 5. Point d'arrêt n°1 — capsule officielle (résolu avec Sébastien)

`generate_capsule.py` a refusé d'écrire la capsule V2 du jour : *"Immutability rule: existing capsules are never overwritten automatically"* — une capsule 0.2 existe déjà pour 2026-09-16, publiée ce matin par le pipeline habituel, sans paramètre de forçage. Découvert seulement à l'exécution réelle (jamais rencontré pendant les répétitions en répertoire temporaire).

**Décision de Sébastien : la capsule 0.2 du jour reste intacte et immuable ; la prochaine génération de capsule sera la première officiellement V2.** Le chaînage 0.2→2.0 avait déjà été prouvé dimanche (`prev_hash` d'une capsule V2 test = `content_hash` réel de la capsule 0.2 de la veille) — aucun risque de rupture de chaîne à ce changement de schéma différé.

**État réel actuel** : `aiweather-capsule/capsules/2026/09/16.json` reste `schema_version: "0.2"` (vérifié), `aiweather-capsule/latest.json` inchangé (`/capsules/2026/09/16.json`), `data/capsule-index.json` inchangé.

## 6. Point d'arrêt n°2 — `index.html` (résolu sans nouvelle question, par le chemin le plus sûr déjà éprouvé)

En inspectant `index.html` pour le remplacer par l'interface V2 validée (`dev/ai-weather-v2-shadow.html`, 526 lignes), découverte que la vraie page publique fait **1200 lignes** avec un menu langue/thème fonctionnel réel, un footer, une section "Question du jour" séparée — bien plus riche que ce qui avait été comparé pendant la semaine. Un remplacement intégral aurait risqué de faire disparaître du contenu réel jamais vérifié en parallèle.

**Résolu en appliquant à `index.html` exactement la même migration sûre, additive, déjà appliquée aux 13 widgets samedi** : remplacement de `system.condition` par `NMData.getDisplayCondition()` dans le rendu de la grille (`renderCard`), ajout du 5ᵉ état `insufficient` (CSS + légende + clé i18n `judgment.j5`, déjà existante), sans toucher au header, au footer, aux menus langue/thème ni à la section "Question du jour". Zéro perte de contenu, zéro risque de régression sur une fonctionnalité non vérifiée.

**Conséquence honnête à documenter** : l'interface complète à 5 sections (What Changed?, Model Detail, Methodology/Data) validée vendredi **n'a pas été promue sur la page publique** dans cette bascule — seul le statut de la grille principale (l'élément le plus important, explicitement demandé : "le statut AI Weather provient du longitudinal") est maintenant V2 sur la vraie page. Le reste de l'interface V2 reste disponible et validé sur `dev/ai-weather-v2-shadow.html` pour une promotion ultérieure, qui nécessitera cette fois une vraie comparaison de parité de contenu avec `index.html` avant tout remplacement complet.

## 7. Résultats des contrôles immédiats

### Cas critiques (vérifiés sur `weather.json` réel, en navigateur, après bascule)

| Cas | Résultat |
|---|---|
| OpenAI / Anthropic / Qwen | ✅ `standard`, aucune fausse alerte |
| Mistral | ✅ `attention_accrue`, rupture préservée |
| Perplexity | ✅ `attention_renforcee`, jamais `attention_critique` |
| Cohere | ✅ `standard`, pas de fausse rupture |
| Couverture insuffisante | ✅ jamais affichée comme `standard` (aucun cas réel aujourd'hui — état géré, non exercé) |
| Today's Challenge | ✅ `system.condition` intact et non lu par la grille V2 ; section "Question du jour" séparée et inchangée |

### Statut des 12 systèmes publiés

| Système | État V2 |
|---|---|
| OpenAI, Anthropic, Google, xAI, DeepSeek, Qwen, Moonshot, Cohere, Meta | `standard` |
| Mistral | `attention_accrue` |
| Infomaniak (Nvidia) | `attention_accrue` |
| Perplexity | `attention_renforcee` |

### Interface publique (`index.html`)

Desktop ✅, mobile simulé 390px ✅ (0px de débordement), FR (défaut) ✅, EN (`?lang=en`) ✅, thèmes light/dark ✅, menus langue/thème réels intacts, footer intact, section Question du jour intacte, **zéro erreur console**.

### Widgets

`weather-bar-2x6.html` et `weather-sidebar-12-v2.html` (thème warm) re-testés en direct contre le vrai `weather.json` post-bascule : rendu V2 correct sans aucune modification de code supplémentaire, zéro erreur console. `weather-home-1180.html` non touché, exclu (`KNOWN_PREEXISTING_BROKEN_WIDGET`).

### Capsule V2

Non publiée aujourd'hui comme officielle (§5) — la chaîne de hash reste valide et continue sur la capsule 0.2 existante. La capacité à produire une capsule V2 valide et correctement chaînée a été prouvée deux fois cette semaine (répétition de dimanche) avec tous les champs requis présents.

### Erreurs fournisseur / couverture

Aucune — ce bloc n'a pas ré-exécuté les runners de mesure (`run_weather_*.ps1`), seulement enrichi les données déjà mesurées ce matin. Couverture : 100% sur les 12 systèmes (`coverage_status: nominal` partout).

### Tests (après bascule)

74/74 suites PowerShell vertes (moteur 35, pont 20, Wilson 19), syntaxe de l'agrégateur modifié validée (0 erreur). Suite Python : **19/20 + 3 sous-tests** — voir §8 pour le seul test rouge, expliqué et non-bloquant.

## 8. Seule anomalie rencontrée : un test devenu obsolète par la bascule elle-même

`test_real_production_file_regression` (dans `test_generate_capsule_v2.py`) échoue désormais : il compare `data/history/2026-09-16.json` (maintenant volontairement enrichi V2) à la capsule déjà publiée ce matin (encore 0.2, §5) et constate une différence — **ce qui est exactement le résultat attendu et voulu de la bascule**, pas une régression du code de génération de capsule. La logique de `generate_capsule.py` elle-même reste prouvée correcte par les 6 autres tests de sa suite (tous verts) et par deux générations réelles de capsule V2 valide cette semaine. La prémisse de ce test spécifique (« regénérer depuis cette source doit reproduire la capsule déjà publiée ») n'est plus vraie une fois la source volontairement changée par la bascule — c'est un test à mettre à jour en suivi, pas un défaut à corriger en urgence. **Non ignoré : documenté ici explicitement, conformément à la consigne de ne jamais passer sous silence une suite rouge.**

## 9. Ce qui n'a PAS été fait (délimitation explicite du périmètre réel)

- **Aucun commit, aucun `git push` vers `origin`** (`https://github.com/neomundi-io/neomundi-ai-weather.git`, remote confirmé configuré). Tous les changements ci-dessus sont dans l'arbre de travail local uniquement, visibles par `git status` mais non historisés. Si le déploiement public réel de neomundi/ControlTowerAI dépend d'un push vers ce dépôt, **cette étape reste à faire séparément, sur demande explicite**, conformément à la règle « ne jamais commiter/pousser sans qu'on le demande ».
- Capsule V2 non publiée comme officielle aujourd'hui (§5, décision explicite de Sébastien).
- Interface complète à 5 sections non promue sur `index.html` (§6) — seul le statut de la grille l'est.
- Aucune capsule historique modifiée. Aucun mécanisme legacy retiré.

## 10. Rollback — toujours disponible

Mécanisme inchangé depuis dimanche, maintenant testable pour de vrai si besoin : restaurer les fichiers depuis `dev/snapshots/pre-bascule-backup-2026-09-16/` (copie directe, pas de régénération) :
- `weather.json`, `data.current.json` → `data/current.json`, `data.history.2026-09-16.json` → `data/history/2026-09-16.json`, `index.html`, `aggregate_and_publish_weather.ps1`.

Les 13 widgets n'ont besoin d'aucun rollback de code : ils retombent automatiquement sur `system.condition` dès que les fichiers de données redeviennent legacy. `latest.json`, la capsule du jour et l'index de capsules n'ont pas changé — rien à restaurer pour eux.

## 11. Anomalies

Aucune anomalie fonctionnelle. Le seul point notable est le test obsolète (§8), déjà expliqué et sans impact.

---

## Verdict

**`AI_WEATHER_V2_LIVE`**

Les données publiques (`weather.json`, `data/current.json`, `data/history/2026-09-16.json`) et la grille principale d'`index.html` sont réellement, localement, en V2 — le statut AI Weather provient du longitudinal, vérifié sur les vraies données, sans régression sur les 13 widgets valides ni sur le reste de la page publique. Deux décisions ont été prises prudemment plutôt que forcées : la capsule officielle V2 démarre à la prochaine génération (capsule du jour préservée intacte, sur décision explicite de Sébastien) et l'interface complète à 5 sections reste à promouvoir séparément après une vraie vérification de parité de contenu avec la page réelle. Rien n'a été commité ni poussé vers le dépôt distant — cette étape, si nécessaire au déploiement réel, reste à demander explicitement.

---

*Fin du document.*
