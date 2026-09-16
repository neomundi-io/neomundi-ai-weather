# AI Weather V2 — Plan d'implémentation

**Statut :** plan uniquement. Aucun fichier de production n'a été modifié, aucun code écrit, aucun déploiement effectué. Ce document découpe la mise en œuvre de `AI_WEATHER_V2_ARCHITECTURE.md` en six phases séquentielles, chacune livrable et testable indépendamment.

**Principe transversal valable pour toutes les phases** : conformément à la politique déjà en vigueur (« always-push », `AI_WEATHER_KNOWN_FIXES.md` #11 — une journée à faible couverture doit être publiée telle quelle, jamais retenue), toute nouvelle logique introduite doit échouer *ouvert* (log + valeur `insufficient_data`/`baseline_not_established`), jamais bloquer la publication quotidienne existante.

---

## Phase 0 — Verrouillage méthodologique et identité des modèles

**Objectif** : éliminer les ambiguïtés d'identité de modèle et fixer la date de départ officielle de la fenêtre longitudinale, avant qu'aucun calcul ne s'appuie dessus.

**Fichiers concernés**
- `config/panel.yml` (déclaré comme source unique par son propre en-tête)
- `AI_WEATHER_RUNNER/run_weather_openai.ps1` (alias `"chat-latest"` à remplacer)
- `AI_WEATHER_RUNNER/weather_models.json` (à régénérer depuis `panel.yml` ou marquer explicitement non-autoritatif)
- Les 12 `AI_WEATHER_RUNNER/run_weather_*.ps1` (ajout de la capture du champ modèle échoïsé par chaque API)
- `aiweather-capsule/capsules/2026/08/17.json` et `21.json` (lecture seule, inspection)
- Nouveau : `AI_WEATHER_METHODOLOGY_CHANGELOG.md`
- Nouveau : `config/provider_changelog.json` (vide au départ, alimenté manuellement)

**Modifications prévues**
1. Épingler `run_weather_openai.ps1` sur l'identifiant déclaré dans `panel.yml` (`gpt-4o-2024-11-20`, ou toute valeur explicitement choisie et documentée), suppression de l'alias `"chat-latest"`.
2. Régénérer ou déprécier explicitement `weather_models.json` pour qu'il cesse d'être une deuxième source de vérité concurrente.
3. Ajouter, dans chaque runner, la capture du champ modèle renvoyé par la réponse API (quand le fournisseur l'expose) dans une nouvelle colonne `model_returned` des lignes `*_results.jsonl`.
4. Inspecter en lecture seule les capsules du 17 et 21 août pour déterminer leur schéma exact (v0.1 "1 question × 30 répétitions" ou déjà v0.2 daily+longitudinal) et consigner le verdict.
5. Créer `methodology_version` comme concept versionné documenté (pas encore intégré au JSON — ça, c'est Phase 2) et démarrer `AI_WEATHER_METHODOLOGY_CHANGELOG.md`.

**Tests nécessaires**
- Script de vérification (lecture seule) comparant `panel.yml.model_id` au littéral `$MODEL` de chacun des 12 runners → doit produire zéro divergence.
- Test manuel sur quelques jours : comparer `model_requested` vs `model_returned` pour OpenAI avant de déclarer le point résolu.
- Relecture manuelle du schéma des capsules 17/21 août par un humain (pas automatisable de façon fiable vu qu'il s'agit potentiellement de deux générations de schéma différentes).

**Critères d'acceptation**
- Une seule source déclarée d'identité de modèle par système, sans divergence entre `panel.yml`, le runner, et (s'il subsiste) `weather_models.json`.
- Date de début officielle de la fenêtre longitudinale fixée et documentée (17, 21 ou 22 août).
- `AI_WEATHER_METHODOLOGY_CHANGELOG.md` créé avec sa première entrée.

**Dépendances** : aucune — phase fondatrice.

**Risques**
- Épingler OpenAI sur un snapshot précis expose au risque que ce snapshot soit un jour déprécié par le fournisseur → mitigation : revue périodique manuelle documentée, pas de retour à un alias "latest".
- Le fournisseur peut ne pas exposer de champ modèle échoïsé dans sa réponse → dans ce cas, documenter explicitement l'impossibilité plutôt que de laisser un flou (le système reste marqué `model_identity_unverified` en continu, ce qui est une information honnête).

**Rollback** : modifications de configuration pures, réversibles trivialement via `git revert`. Aucune donnée de production n'est réécrite à cette phase.

---

## Phase 1 — Moteur longitudinal

**Objectif** : produire, pour la première fois, un état longitudinal calculé (baseline, écart, persistance) à partir des données déjà collectées — en lecture seule sur l'historique, sans toucher à la publication existante.

**Fichiers concernés**
- Nouveau : `AI_WEATHER_RUNNER/longitudinal_engine.ps1` (module autonome, non encore invoqué par le pipeline de publication)
- Lecture (pas d'écriture) : `data/history/*.json`, `AI_WEATHER_RUNNER/results/<date>/*_results.jsonl`

**Modifications prévues**
- Implémenter le calcul défini dans l'architecture (§3) : `longitudinal_score_jour`, baseline médiane/MAD sur fenêtre fixe (14 premiers jours valides, à partir de la date confirmée en Phase 0), `deviation_index`, état avec hystérésis (Standard / Attention accrue / Attention renforcée / Attention critique / Insufficient data / Baseline not established).
- Le moteur tourne **hors ligne**, produit un rapport (fichier de sortie séparé, hors des chemins de publication), pour permettre une relecture humaine avant toute intégration.

**Tests nécessaires**
- Tests unitaires sur séquences synthétiques : système stable, dérive graduelle, rupture brutale persistante, observation aberrante isolée, jours manquants — vérifier que chaque scénario produit l'état attendu et qu'aucun ne déclenche de bascule sur une seule observation.
- Rejeu (backtest) sur l'historique réel (22/08 → 16/09, en excluant les jours identifiés comme suspects en Phase 0 pour Moonshot) : revue manuelle des sorties pour vérifier leur plausibilité, sans publication.

**Critères d'acceptation**
- Sortie reproductible : même entrée → même sortie.
- Aucun fichier de production touché (le moteur ne fait que lire).
- Méthode de baseline et seuils provisoires documentés dans le code et dans le changelog méthodologique.

**Dépendances** : Phase 0 (identité de modèle fiable, date de départ de fenêtre confirmée).

**Risques**
- Un système récemment onboardé (moins de 14 jours valides) n'a pas de baseline → traité explicitement comme `baseline_not_established`, jamais comme une erreur silencieuse.
- Les jours Moonshot antérieurs à la correction du bug de panel (audit §4/§11) pourraient fausser sa baseline si inclus par erreur → exclusion explicite et documentée de ces jours pour ce système spécifiquement.

**Rollback** : le moteur est un nouveau fichier non branché à la publication — le désactiver revient à ne pas l'invoquer, sans aucun effet sur l'existant.

---

## Phase 2 — Contrat JSON V2 et événements

**Objectif** : intégrer la sortie du moteur longitudinal dans les fichiers publiés, en ajoutant les nouveaux champs sans toucher aux champs existants, et implémenter le calcul des 7 événements `WHAT CHANGED?`.

**Fichiers concernés**
- `AI_WEATHER_RUNNER/aggregate_and_publish_weather.ps1` (appel du moteur Phase 1, extension de l'objet de sortie)
- `aiweather-capsule/generate_capsule.py` (extension de `build_public_model_record`/`normalize_ai_weather_history` pour projeter `system_identity` et `longitudinal_reference`)
- `aiweather-capsule/verify_chain.py` (revalidation, pas de modification de logique attendue)
- Nouveau : `AI_WEATHER_V2_SCHEMA.md` (documentation formelle du contrat, référence pour Phase 3 et les intégrateurs externes)
- `i18n/en.json`, `i18n/fr.json` (nouvelles clés pour le wording des événements et des états longitudinaux — ajout, pas de renommage des clés existantes)

**Modifications prévues**
- Ajouter, de façon strictement additive, à `data/history/YYYY-MM-DD.json` et `weather.json` : `schema_version`, `methodology_version`, `evidence_integrity`, `global_longitudinal_summary`, `detected_events[]`, et par système `system_identity{}` et `longitudinal_reference{}` (remplaçant le `longitudinal{}` actuel à `condition:null` par la version enrichie, en conservant toutes ses clés actuelles).
- Implémenter la détection des 7 événements (§5 de l'architecture) côté agrégateur, à partir de la sortie du moteur Phase 1.
- Étendre `generate_capsule.py` pour projeter ces nouveaux blocs dans les capsules **futures uniquement** — les capsules existantes restent immuables (règle déjà en place dans le générateur : « existing capsules are never overwritten »).

**Tests nécessaires**
- Test de schéma : toutes les clés lues aujourd'hui par `index.html`/`weather-data.js`/les widgets sont toujours présentes, avec le même type et la même forme.
- Test de non-régression visuelle : capture de `weather.json` avant/après extension, rendu comparé sur les pages existantes — doit être pixel-identique.
- `verify_chain.py` exécuté sur une copie de la chaîne réelle + une capsule générée avec le générateur étendu, pour confirmer qu'aucune rupture de chaîne n'est introduite.

**Critères d'acceptation**
- `verify_chain.py` passe sans erreur.
- Aucune page publique existante ne change visuellement.
- Les nouveaux champs sont cohérents avec la sortie du moteur Phase 1.

**Dépendances** : Phase 1.

**Risques**
- `generate_capsule.py` est une reconstruction (original perdu, cf. son propre en-tête) : toute modification s'appuie sur une base déjà incertaine → mitigation : capturer un instantané des capsules générées avant modification, comparer champ par champ après, et ne jamais toucher aux capsules déjà écrites.
- Croissance de la taille de `weather.json` (déjà ~206 Ko) → à surveiller, sans action requise à ce stade.

**Rollback** : les champs ajoutés sont additifs — un retour arrière consiste à revenir à la version précédente de l'agrégateur/générateur ; les consommateurs existants n'auraient de toute façon jamais lu les nouveaux champs.

---

## Phase 3 — API et compatibilité

**Objectif** : s'assurer que l'écosystème d'intégration (widgets embarqués, documentation) reste compatible avec le contrat V2, et formaliser la garantie de compatibilité.

**Fichiers concernés**
- `integration_EN.md`, `intégration_FR.md` (documentation, section additive)
- Tous les fichiers `weather-bar-*.html`, `weather-sidebar-*.html`, `provider-widget.html`, `widget.html`, `core-panel.html` (vérification, pas de modification de logique attendue)
- Nouveau (documentation) : `AI_WEATHER_V2_SCHEMA.md` référencé depuis la documentation d'intégration

**Modifications prévues**
- Documenter les nouveaux champs dans la documentation d'intégration, dans une section clairement marquée "V2 — additions", sans toucher aux sections existantes qui restent valables telles quelles.
- Ajouter un test de compatibilité automatisé : test un test de "contrat gelé" qui échoue si un champ actuellement lu par un widget venait à être renommé ou supprimé.

**Tests nécessaires**
- Passage manuel sur chacun des widgets embarqués existants avec le `weather.json` étendu, pour confirmer un rendu identique.
- Vérification que `data/current.json` == `weather.json` reste vrai après extension.

**Critères d'acceptation**
- Tous les embeds existants continuent de fonctionner sans modification de leur propre code.
- Documentation à jour.

**Dépendances** : Phase 2.

**Risques** : faibles, changement purement additif. Risque principal : taille de payload pour les intégrateurs à faible bande passante — à monitorer, non bloquant pour cette phase.

**Rollback** : modifications documentaires uniquement, triviales à annuler.

---

## Phase 4 — Interface AI Weather V2

**Objectif** : construire les six sections définies dans l'architecture (§9) sans casser les widgets existants ni le mur d'observation actuel.

**Fichiers concernés**
- `index.html` (nouvelles sections CURRENT STATE enrichi, WHAT CHANGED?, recadrage de TODAY'S CHALLENGE, lien vers MODEL DETAIL)
- `scripts/weather-data.js` (extension : nouvelle fonction de chargement de la trajectoire longitudinale, aux côtés de `loadHistory()` existant, sans le modifier)
- Nouveau : vue/page de détail par système (MODEL DETAIL) — n'existe pas aujourd'hui
- `i18n/en.json`, `i18n/fr.json` (nouvelles clés : libellés d'états longitudinaux, wording des événements, section FOR DEVELOPERS)
- Nouveau : page de documentation consolidée "comment lire ces données" (FOR DEVELOPERS / RESEARCHERS)
- **Non touchés à cette phase** : `weather-bar-*.html`, `weather-sidebar-*.html`, `provider-widget.html`, `widget.html` (restent sur leur usage actuel, hors périmètre de la refonte de `index.html`)

**Modifications prévues**
- Implémenter CURRENT STATE (rollup longitudinal + couverture), WHAT CHANGED? (max 3 cartes d'événements avec état vide explicite), recadrage de TODAY'S CHALLENGE (même contenu qu'aujourd'hui, reformulé éditorialement), MODEL DETAIL (graphique de trajectoire + bande de baseline + chronologie d'événements + réponse du jour), FOR DEVELOPERS / RESEARCHERS (page de méthodologie consolidée).

**Tests nécessaires**
- Démarrage du serveur de développement et test manuel dans le navigateur (conformément à la pratique du projet pour tout changement front-end), sur : le chemin nominal (données complètes), le cas "aucun événement", le cas "un système en Attention critique", le cas "couverture insuffisante".
- Vérification de non-régression sur les widgets embarqués non touchés par cette phase.
- Relecture éditoriale du wording par rapport à la discipline "comportement, jamais modèle" déjà en place ailleurs dans le projet (audit §8, "bonne discipline de copie constatée").

**Critères d'acceptation**
- Les six sections s'affichent correctement avec les données réelles actuelles et avec des données synthétiques couvrant les cas limites.
- Aucune régression sur les widgets hors périmètre.
- Le wording public a été relu et validé contre le principe méthodologique (aucune affirmation de changement de modèle sans preuve externe).

**Dépendances** : Phase 2 (contrat JSON disponible).

**Risques** : dérive de périmètre vers une refonte visuelle complète → mitigation : réutiliser au maximum les styles/i18n existants plutôt que reconstruire le système visuel.

**Rollback** : les nouvelles sections sont des ajouts à `index.html` — peuvent être masquées ou retirées indépendamment des Phases 0-3, qui restent valides et utiles même sans l'interface V2.

---

## Phase 5 — Vérification, backfill prudent et déploiement

**Objectif** : passer le moteur longitudinal en production quotidienne, produire un historique rétrospectif documenté sans jamais réécrire de capsule existante, et publier l'interface V2.

**Fichiers concernés**
- `AI_WEATHER_RUNNER/run_full_pipeline.ps1` (intégration de l'appel au moteur Phase 1/2 dans le run quotidien)
- Aucune capsule existante n'est modifiée (règle d'immuabilité déjà en place, respectée)
- Nouveau : rapport de backfill (fichier séparé, dérivé, jamais substitué aux capsules d'origine)

**Modifications prévues**
- Rejeu du moteur longitudinal sur toute la fenêtre validée en Phase 0/1, produisant un jeu de données dérivé (baseline, trajectoire, événements rétrospectifs) séparé des capsules d'origine.
- Activation du moteur dans le run quotidien de production (`run_full_pipeline.ps1`), en mode "échoue ouvert" : une erreur du moteur longitudinal ne doit jamais empêcher la publication du `daily_challenge`, conformément à la politique already-push existante.
- Activation de l'interface V2 (Phase 4) une fois le backfill relu.
- Publication du changelog méthodologique et incrément de `methodology_version`.

**Tests nécessaires**
- Exécution du pipeline complet en parallèle (chemin de sortie séparé, pas encore publié publiquement) pendant plusieurs jours consécutifs avant bascule.
- Vérification de l'intégrité de la chaîne de capsules après plusieurs jours de production réelle avec le nouveau générateur étendu.
- Test explicite de la politique fail-open : simuler une panne du moteur longitudinal et confirmer que `daily_challenge` continue d'être publié normalement.
- Répétition d'un scénario de rollback en environnement de test avant la bascule réelle.

**Critères d'acceptation**
- N jours consécutifs de run parallèle sans incident.
- Chaîne de capsules toujours vérifiable après activation.
- Rollback testé au moins une fois avec succès en environnement non-production.

**Dépendances** : Phases 0 à 4 complètes et relues.

**Risques**
- Risque principal : qu'une erreur du moteur longitudinal casse silencieusement la publication quotidienne existante → mitigation explicite par le principe fail-open, calqué sur la gestion d'erreur déjà en place pour les lignes `ERROR` individuelles.
- Risque de calculer une baseline rétrospective sur une période polluée par un incident connu (bug Moonshot, incident Mistral) → exclusion documentée de ces jours, déjà actée en Phase 0.

**Rollback** : les Phases 0 à 3 étant additives et la Phase 4 étant une addition d'interface, le rollback consiste à désactiver l'appel au moteur dans `run_full_pipeline.ps1` et/ou masquer les nouvelles sections de `index.html` — à aucun moment une capsule existante ou une donnée historique n'est réécrite ou supprimée, donc aucune étape destructive n'existe dans ce plan.

---

*Fin du plan d'implémentation. Aucune de ces phases n'a été démarrée. En attente de validation avant tout début de mise en œuvre.*
