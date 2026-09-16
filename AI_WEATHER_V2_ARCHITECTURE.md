# AI Weather V2 — Architecture cible

**Statut :** document de conception uniquement. Aucun fichier de production n'a été modifié pour produire ce document. Aucune ligne de code n'a été écrite.
**S'appuie sur :** `AI_WEATHER_LONGITUDINAL_AUDIT.md` (2026-09-16), relu intégralement, ainsi que sur une vérification directe complémentaire de `weather.json`, `aiweather-capsule/generate_capsule.py`, `config/panel.yml`, `AI_WEATHER_RUNNER/weather_models.json` et des noms de fonctions de `aggregate_and_publish_weather.ps1`.

---

## 1. Cartographie de l'architecture actuelle

```
CONFIGURATION
  AI_WEATHER_RUNNER/config/daily_questions.csv      (question du jour, 1 ligne/date)
  AI_WEATHER_RUNNER/config/longitudinal_probe.csv   (question constante, 1 ligne fixe)
        │
        ▼
  build_daily_panel.ps1
        │  fusionne les 2 lignes → panel du jour (23 reps daily + 7 reps longitudinal)
        ▼
  AI_WEATHER_RUNNER/data/panels/ai_weather_panel.csv   (+ sauvegarde horodatée)
        │
        ▼
EXÉCUTION (12 scripts, un par système)
  run_weather_{openai,anthropic,google,xai,mistral,cohere,deepseek,
               qwen,moonshot_v1_2,meta,infomaniak,perplexity}.ps1
        │  pour chaque ligne du panel × répétitions : appel API, retries (≤3),
        │  classification decision=ALLOW/FLAG/ERROR via API de gouvernance tierce
        │  (Invoke-CompleteGovernance), écrit aussi baseline_*/esi_q/
        │  classification_confidence (jamais consommés en aval)
        ▼
  AI_WEATHER_RUNNER/results/<date>/*_results.jsonl  (brut, une ligne = une répétition)
        │
        ▼
AGRÉGATION — AI_WEATHER_RUNNER/aggregate_and_publish_weather.ps1
        │  Get-ProbeRole()          classe chaque ligne daily / longitudinal / unknown
        │  Get-ProbeAggregate()     score = 100 × ALLOW / scored   (ligne ~754)
        │  Get-WeatherInterpretation()  seuils $THRESHOLD_CLEAR=90 / $THRESHOLD_VARIABLE=65 (l.535)
        │  Get-JudgmentDemand()     mappe condition → J1..J4                (l.680)
        │  Get-GlobalCondition()    agrège les 12 systèmes                  (l.1401)
        │  Parse-PanelYml()         lit config/panel.yml (identité déclarée)(l.1061)
        ▼
  data/history/YYYY-MM-DD.json   (nouveau fichier chaque jour)
  data/current.json  ==  weather.json   (identiques, "état du jour")
        │
        ▼
CAPSULE — aiweather-capsule/generate_capsule.py  (⚠ reconstruction v0.2, original perdu)
        │  build_public_model_record() projette daily{} et longitudinal{} par système
        │  chaîne SHA-256 : chain.prev_hash / chain.content_hash / chain.sequence_index
        ▼
  aiweather-capsule/capsules/YYYY/MM/DD.json  (immuable — jamais réécrit)
  aiweather-capsule/latest.json               (pointeur)
  data/capsule-index.json                     (index daté)
        │
        ▼
EXPOSITION PUBLIQUE
  scripts/weather-data.js   NMData.load() (fetch weather.json, no-store)
                            NMData.loadHistory(7) (sparkline 7 jours, condition daily uniquement)
        ▼
  index.html, index_full.html, core-panel.html, weather-bar-*.html,
  weather-sidebar-*.html, provider-widget.html, widget.html
        → lisent : global_condition, panel_summary, systems[].{condition,score,
          judgment_demand,coverage,model,model_display,public_label},
          probe_contract.daily.question(+translations)
        → NE LISENT JAMAIS : systems[].longitudinal, protocol.longitudinal_*
```

**Constat clé pour la conception V2** : le bloc `longitudinal` existe déjà de bout en bout dans le pipeline (exécuté, agrégé, capsulé) mais s'arrête à `condition: null` / `interpretation: null` — **aucun calcul ne le transforme en état**, et **aucune page ne le lit**. La séparation demandée n'est donc pas à inventer : elle est à *terminer*.

---

## 2. Deux pipelines explicitement séparés

### ⚠️ Correction sémantique (Gate de validation, tour du 2026-09-16) — modèle d'autorité à trois états

Une relecture croisée avec la commande initiale a révélé une contradiction dans ce document et dans `AI_WEATHER_V2_VALIDATION_GATE.md` : la version précédente présentait la non-autorité du canal longitudinal comme une règle **permanente**. Ce n'est pas l'objectif. L'objectif initial (premier message de cadrage) est explicite : *« Cette sonde doit potentiellement devenir le socle principal d'AI Weather V2 »* et *« Le challenge variable quotidien deviendrait un objet distinct : TODAY'S CHALLENGE »*. Le modèle correct comporte **trois états temporels**, pas une règle unique :

| État | Ce qui est publié comme "statut météo principal" | Rôle du canal longitudinal | Rôle de `daily_challenge` |
|---|---|---|---|
| **1. Aujourd'hui (production actuelle, non modifiée par ce plan)** | `global_condition` (`clear`/`watch`/`unsettled`), calculé sur les 23 répétitions du jour | Mesuré, capsulé, mais `condition: null` — aucun état, aucune publication | Autoritatif de fait sur ce qui est affiché aujourd'hui |
| **2. Pendant le shadow mode (Phases 1-4)** | Reste `global_condition` (daily) — **aucun changement visible publiquement** | Calculé en parallèle, non publié, par construction du shadow mode (rien n'y est public) — non-autorité **temporaire et instrumentale**, pas un principe de conception définitif | Reste autoritatif sur l'affichage public pendant toute cette période, par prudence, pas par doctrine |
| **3. Cible V2 (après validation, fin de Phase 5)** | Un nouveau statut "AI Weather" (Standard / Attention accrue / renforcée / critique / Insufficient data), **dérivé du canal longitudinal calibré** | **Devient l'autorité du statut AI Weather principal** | Devient **Today's Challenge** : comparaison éditoriale du jour, explicitement et définitivement **non-autoritative** sur AI Weather, jamais fusionnée avec lui |

**Ce qui ne change pas entre les trois états** : NeoMundi fournit toujours un signal et un état *documentés* (jamais une décision) ; l'interprétation métier, la décision et l'action restent toujours sous l'autorité de l'utilisateur ou de son système de gouvernance (chaîne Observation → Signal → Interprétation → Décision → Action, §6, inchangée). **Ce qui change** : à la bascule de l'état 2 vers l'état 3, l'autorité sur "le statut météo principal" passe de `daily_challenge` à `longitudinal_reference` — un événement de bascule explicite, documenté par un incrément de `methodology_version`, jamais silencieux, jamais avant la fin d'un shadow mode validé.

Les tableaux et invariants ci-dessous sont corrigés en conséquence.

### A. `longitudinal_reference`

| Propriété | Valeur |
|---|---|
| Stimulus | `longitudinal-core-01`, constant depuis le 21/08/2026 (date corrigée — voir Gate de validation §2.B) |
| Répétitions | 7 / système / jour |
| Comparaison | à l'historique **du même système**, jamais aux 11 autres |
| Sortie | baseline, trajectoire, écart du jour, persistance, rupture, stabilisation, couverture |
| Autorité sur le statut "AI Weather" principal | **Cible V2 : totale**, une fois calibré et sorti du shadow mode. **Aujourd'hui et pendant le shadow mode : non publiée**, par construction temporaire (rien du shadow mode n'est public) — `weather_authority: false` reste le fait actuel du code de production, pas la règle définitive de la V2 |

### B. `daily_challenge`

| Propriété | Valeur |
|---|---|
| Stimulus | `daily-YYYY-MM-DD`, nouveau chaque jour |
| Répétitions | 23 / système / jour |
| Comparaison | transversale entre les 12 systèmes, pour l'édition du jour uniquement |
| Sortie | condition du jour, score du jour, réponse publique — devient "Today's Challenge" en cible V2 |
| Autorité sur le statut "AI Weather" principal | **Aujourd'hui : totale de fait** (c'est le seul canal calculé). **Cible V2 : aucune, définitivement** — Today's Challenge ne détermine jamais le statut AI Weather, ni directement ni indirectement, à aucun des trois états du tableau ci-dessus |

### Modifications de schéma pour lever toute ambiguïté

Le schéma actuel sépare déjà `daily{}`/`longitudinal{}` par système et par contrat (`probe_contract.daily`/`probe_contract.longitudinal`), mais l'ambiguïté restante vient de trois endroits :

1. **`longitudinal.condition`/`interpretation` valent `null`** aujourd'hui, ce qui est indiscernable de "non calculé" et de "aucun état". → V2 introduit un état explicite `insufficient_data` / `baseline_not_established` plutôt que `null`, pour qu'un consommateur ne puisse jamais confondre "pas encore mesuré" avec "mesuré et neutre".
2. **Le risque à surveiller n'est pas symétrique.** Une fois la bascule effectuée (état 3 du tableau ci-dessus), le risque devient qu'un code hérité continue par erreur de lire `global_condition` (daily) comme s'il s'agissait du statut AI Weather affiché, alors que celui-ci doit désormais provenir de `longitudinal_reference.current_longitudinal_state`. → V2 ajoute un champ auto-descriptif `weather_authority` **répété à chaque niveau** (système et événement), dont la valeur s'inverse explicitement à la bascule, et un test automatisé (Phase 3) qui échoue si le champ affiché comme "statut AI Weather" ne correspond pas à celui déclaré autoritatif par `methodology_version` à cet instant.
3. **Aucun champ ne distingue aujourd'hui** "donnée déclarée" (ce que la config dit) de "donnée observée" (ce que l'API a réellement renvoyé) — cœur du problème OpenAI. → V2 ajoute `system_identity.model_declared`, `system_identity.model_requested` **et** `system_identity.model_returned` séparément, avec un statut `identity_status` (`verified`/`declared`/`inferred`/`unknown`) — schéma canonique complet dans `AI_WEATHER_V2_VALIDATION_GATE.md` §2.A (voir aussi §7 et §8 ci-dessous).

---

## 3. Méthode de baseline

### Contrainte de départ

La seule donnée fiable et déjà exploitée par le pipeline actuel est la classification `decision` (ALLOW/FLAG/ERROR) par répétition — c'est exactement ce qu'utilise déjà `Get-ProbeAggregate` pour calculer le score `daily`. Réutiliser cette même primitive pour le canal `longitudinal` n'introduit **aucune nouvelle boîte noire** : c'est la même mesure, appliquée à l'autre canal. Les champs `baseline_*`/`esi_q`/`classification_confidence` (API de gouvernance tierce, non documentée dans ce dépôt) ne sont **pas** utilisés en V1 — les utiliser reviendrait à construire la baseline sur un mécanisme non audité, ce que l'audit déconseille explicitement (Blocage §11.4).

### Définition V1

Pour chaque système, chaque jour valide (couverture suffisante — voir plus bas) :

```
longitudinal_score_jour = 100 × (nb répétitions "ALLOW") / (nb répétitions scorées, sur 7)
```//
*(formule strictement identique à celle déjà utilisée pour `daily`, `Get-ProbeAggregate`, ligne ~825 — aucune formule nouvelle inventée)*

### Comparaison des méthodes de baseline envisageables

| Méthode | Principe | Avantage | Inconvénient | Adapté à ~26 jours de données ? |
|---|---|---|---|---|
| Moyenne mobile ± écart-type (z-score classique) | Fenêtre glissante des N derniers jours | Simple, universellement connu | Sensible à un seul jour aberrant ; écart-type instable sur petit N | Non recommandé en V1 |
| **Médiane ± MAD sur fenêtre fixe** | Fenêtre gelée une fois établie (ex. 14 premiers jours valides) | Robuste aux valeurs aberrantes ; explicable ("votre propre référence de départ") ; ne "poursuit" pas une dérive lente | Ne s'adapte pas automatiquement à une évolution légitime | **Recommandé pour V1** |
| Détection de rupture (CUSUM / change-point) | Test statistique de changement de régime | Plus puissant pour détecter une rupture fine | Complexe à expliquer publiquement ; nécessite un historique plus long pour être fiable | Non recommandé avant plusieurs mois de données (option future, §12 de l'audit) |
| Baseline glissante recalculée en continu | Moyenne/médiane des N derniers jours, mise à jour chaque jour | S'adapte à une dérive lente | Risque de "baseline qui chasse la donnée" : une dérive progressive devient invisible car elle finit par être absorbée dans sa propre référence | Non recommandé en V1 |

**Recommandation V1 : médiane + MAD (Median Absolute Deviation), sur une fenêtre de référence fixe** = les 14 premiers jours valides de chaque système depuis le début confirmé du protocole v0.2 (à dater précisément en Phase 0, §8). Cette baseline est **gelée** — elle ne bouge plus une fois établie, jusqu'à une décision explicite et documentée de la réétablir (ex. après un `known_model_version_change` confirmé).

### Écart quotidien

```
deviation_index_jour = (longitudinal_score_jour − baseline_median) / max(baseline_MAD, ε)
```

### Gestion des données manquantes / couverture insuffisante

- Si moins de 5 répétitions sur 7 sont scorées un jour donné (cohérent avec le seuil déjà en place ailleurs, `$COVERAGE_MIN_INTERPRETABLE = 0.80` ≈ 5.6/7) → le jour est marqué `insufficient_data` pour le canal longitudinal : **il n'entre ni dans le calcul de la baseline, ni dans le comptage de persistance, ni dans le comptage de retour à la baseline.** Il n'est jamais traité comme "0" ou "neutre".
- Si un système n'a pas encore accumulé les 14 jours valides nécessaires (nouveau système, ou système avec trop de jours `insufficient_data` en début de fenêtre) → état `baseline_not_established`, distinct de tous les autres états.

### Éviter qu'une observation aberrante ne déclenche un changement de statut

Mécanisme d'hystérésis symétrique, seul mécanisme structurel (les valeurs numériques restent provisoires) :
- **Élévation d'état** : nécessite `deviation_index` au-delà d'un seuil pendant **N jours valides consécutifs** (provisoire : N=2 pour le premier palier, N=3 pour les paliers supérieurs).
- **Désescalade** : nécessite un retour sous le seuil pendant **N jours valides consécutifs** (mêmes N, pour éviter une désescalade aussi nerveuse qu'une élévation).
- Un seul jour isolé au-delà du seuil, suivi d'un retour, est journalisé (`behavioral_deviation_detected`) mais **ne change pas l'état affiché**.

### Distinction variation ponctuelle / rupture persistante / retour à la baseline

| Cas | Règle |
|---|---|
| Variation ponctuelle | Seuil franchi 1 seul jour valide, puis retour sous le seuil le jour valide suivant |
| Rupture persistante | Seuil franchi ≥ N jours valides consécutifs |
| Retour à la baseline | Après une rupture persistante active, ≥ N jours valides consécutifs de retour sous le seuil |

---

## 4. États calculables

Les libellés demandés (Standard / Attention accrue / Attention renforcée / Attention critique / Insufficient data) sont calculés par le **canal longitudinal** et sont destinés à devenir, en cible V2 (état 3 du tableau §2), **le statut "AI Weather" principal lui-même** — pas une catégorie secondaire à côté de `clear`/`watch`/`unsettled`. Ces derniers (calculés par `daily_challenge`) restent affichés mais deviennent le résultat éditorial de "Today's Challenge", explicitement non-autoritatif sur AI Weather. Pendant le shadow mode (état 2), les deux jeux d'états coexistent dans les données sans que le second (longitudinal) ne soit publié. Par cohérence avec le contrat existant (`active_weather_states`/`reserved_weather_states`/`non_weather_states`), V2 introduit l'équivalent côté longitudinal : `active_longitudinal_states`, `reserved_longitudinal_states`, `non_longitudinal_states` — ce triplet est celui qui, à terme, gouverne le statut public principal.

| État | Signification exacte | Données nécessaires | Condition de déclenchement (structurelle) | Persistance | Retour à un état inférieur | Garde-fous couverture |
|---|---|---|---|---|---|---|
| **Standard** | Comportement observé conforme à la baseline propre du système | baseline établie + jour(s) valide(s) | `deviation_index` dans la bande normale | état par défaut, pas de compteur | — | nécessite ≥1 jour valide récent ; sinon reste au dernier état connu avec horodatage explicite |
| **Attention accrue** | Un écart a été mesuré et confirmé sur plusieurs jours consécutifs, de faible amplitude | idem + historique de streak | `deviation_index` dépasse le seuil 1 pendant N1 jours valides consécutifs (provisoire N1=2) | doit rester ≥ N1 jours pour se déclencher | retour à Standard après N1 jours valides sous le seuil | si couverture insuffisante pendant le streak, le jour ne compte ni pour ni contre |
| **Attention renforcée** | Écart confirmé de plus forte amplitude, ou "Attention accrue" prolongée au-delà d'une durée provisoire | idem | `deviation_index` dépasse le seuil 2 pendant N2 jours (provisoire N2=3), ou Attention accrue soutenue > durée provisoire (ex. 7 jours) | ≥ N2 jours | désescalade progressive (renforcée → accrue → standard), jamais un saut direct | idem |
| **Attention critique** | Réservé — écart majeur confirmé, ou déviation corroborée par un événement `known_model_version_change`/`model_identity_unverified` non résolu | idem + corroboration externe si disponible | seuil 3 franchi durablement, ou combinaison déviation + incident de couverture répété | ≥ N3 jours (provisoire N3=3), publication de cet état accompagnée obligatoirement de son évidence | jamais de retour direct à Standard : passage obligé par Attention renforcée | ne doit jamais être déclenché sur la seule base d'une couverture faible — la couverture faible déclenche `insufficient_data`, pas `critique` |
| **Insufficient data** | Donnée manquante ou baseline non encore établie — **n'est pas un jugement sur le comportement** | coverage du jour, ou historique du système | couverture < seuil interprétable, ou `baseline_not_established` | n'a pas de logique de persistance : recalculé chaque jour indépendamment | disparaît dès que la couverture redevient suffisante | c'est lui-même le garde-fou |

**Distinction règles structurelles / valeurs provisoires** : les *règles* ci-dessus (hystérésis, non-régression directe depuis "critique", exclusion des jours à couverture insuffisante) sont considérées comme stables dès la V1. Les *valeurs numériques* (N1=2, N2=3, N3=3, durée de 7 jours, multiplicateurs de MAD) sont explicitement provisoires et doivent être marquées comme telles dans `methodology_version` (§7), suivant exactement la même discipline que `METHODOLOGY_THRESHOLDS.md` (qui l'avait annoncé sans jamais formaliser de mécanisme de suivi — à corriger, voir Implementation Plan Phase 0).

---

## 5. WHAT CHANGED? — événements structurés

| Événement | Condition | Confiance | Preuves associées | Wording public prudent | Actions suggérées (jamais déclenchées automatiquement) |
|---|---|---|---|---|---|
| `behavioral_deviation_detected` | 1 jour valide franchit le seuil 1, sans confirmation de persistance | Faible-Moyenne, explicitement "non confirmé" | score du jour, baseline médiane/MAD, deviation_index, couverture du jour | « Le [date], le comportement de [Système] sur la question de référence a divergé de sa base habituelle. Observation isolée, non encore confirmée. » | Chercheur : noter pour suivi. Développeur : aucune action requise avant confirmation. QA : surveillance passive. Opérateur : aucune action. Gouvernance : horodater, pas de changement de statut. |
| `persistent_deviation` | Seuil franchi ≥ N jours valides consécutifs | Moyenne-Haute (signal répété) | durée du streak, tendance de la magnitude, couverture sur la période, présence ou non de `model_identity_unverified` | « Depuis N jours, le comportement de [Système] sur la question de référence diffère durablement de sa base établie. Ceci décrit un changement de comportement observé — cela n'indique ni ne prouve une modification interne du modèle. » | Chercheur : ouvrir une investigation, extraire les réponses brutes de la fenêtre. Développeur : relancer les tests de régression. QA : revue des scénarios sensibles cette semaine. Opérateur : examiner routing/fallback. Gouvernance : documenter l'événement et sa couverture, sans pénalité de score automatique. |
| `return_to_baseline` | Après une `persistent_deviation` active, ≥ N jours valides consécutifs sous le seuil | Moyenne-Haute | durée du retour, dates de l'épisode précédent | « Le comportement de [Système] est revenu dans sa plage de référence habituelle depuis le [date], après N jours d'écart observé. » | Chercheur/Gouvernance : clore ou annoter l'investigation. QA : lever la vigilance renforcée. |
| `variability_increase` | Dispersion intra-jour (7 répétitions) significativement supérieure à la dispersion de référence, indépendamment du niveau moyen | Moyenne (mesure bruitée sur n=7) | dispersion du jour vs dispersion de référence | « Les réponses de [Système] à la question de référence sont devenues moins cohérentes entre elles que d'habitude, sans que la réponse typique ait clairement changé. » | Chercheur : étudier la stabilité indépendamment de l'exactitude. QA : vérifier si la variabilité est liée à une formulation particulière. Opérateur : évaluer l'impact sur la fiabilité du routing automatisé. |
| `coverage_anomaly` | Couverture du jour < seuil interprétable | Haute (fait de complétude, pas une inférence comportementale) | fraction de couverture, nb de lignes ERROR, incident connu éventuel | « Données insuffisantes collectées pour [Système] le [date] pour évaluer son comportement de façon fiable. Aucune conclusion comportementale n'est tirée pour ce jour. » | Développeur/Opérateur : vérifier logs/clé API/rate limits. QA : vérifier l'absence de mauvaise configuration de panel (précédent Moonshot). Gouvernance : exclure le jour du calcul de baseline. |
| `known_model_version_change` | Changement de modèle/version confirmé par une source externe (changelog fournisseur curé manuellement, ou écho API du modèle réellement utilisé différent du précédent, corroboré) | Haute, mais explicitement sourcée à une preuve externe — jamais inférée du seul comportement | référence changelog / diff de l'identifiant de modèle renvoyé par l'API, date | « [Fournisseur] a annoncé publiquement, ou l'API a rapporté, un changement de modèle/version pour [Système] le [date]. Tout écart comportemental observé autour de cette date peut y être lié — ceci est un fait documenté, pas une inférence tirée du comportement. » | Chercheur : prioriser cette fenêtre. Développeur : ré-établir une baseline segmentée avant/après. QA : passage de régression obligatoire. Gouvernance : ré-ouvrir formellement le calcul de baseline pour ce système. |
| `model_identity_unverified` | Le runner interroge un alias non épinglé (ex. `chat-latest` pour OpenAI aujourd'hui), ou l'identifiant de modèle réellement renvoyé par l'API n'a pas pu être capturé/confirmé | N/A — c'est une réserve méthodologique, pas une affirmation comportementale | `model_declared` vs alias réellement demandé ; présence/absence d'un champ modèle échoïsé dans la réponse brute | « Pour [Système], la version exacte du modèle interrogé chaque jour n'est pas totalement épinglée ni vérifiable depuis la réponse de l'API. Toute tendance longitudinale pour ce système doit être lue avec cette réserve. » | Développeur : prioriser l'épinglage + la capture de l'ID échoïsé (Phase 0). Chercheur : traiter la série de ce système comme provisoire. Gouvernance : ne jamais publier un état "critique" pour ce système sans cette réserve attachée. |

---

## 6. Actionnabilité — sans dépasser le rôle de NeoMundi

```
Observation  →  Signal            →  Interprétation contextuelle →  Décision  →  Action
(mesure brute)  (événement         (rôle du consommateur,           (propre au    (propre au
                 structuré,         pas de NeoMundi)                 consommateur)  consommateur)
                 documenté,
                 avec preuves)
```

NeoMundi s'arrête strictement à la colonne "Signal" : chaque événement est publié avec ses preuves et son wording prudent, **jamais** avec un bouton qui déclenche une action (pas de relance automatique de tests, pas de changement de routing automatique, pas de notation automatique). L'interface propose un texte "Prochaine étape suggérée" par profil, jamais une action exécutable par NeoMundi lui-même.

| Profil | Action suggérée (affichée, jamais déclenchée) |
|---|---|
| Chercheur | Ouvrir une investigation — lien vers l'export des données brutes de la fenêtre concernée |
| Développeur | Relancer les tests de régression internes concernant ce système |
| Équipe QA | Vérifier les scénarios sensibles pour ce système sur la période |
| Opérateur d'agents | Examiner le routing et les règles de fallback impliquant ce système |
| Gouvernance / observabilité | Documenter l'événement et sa couverture dans son propre registre |

---

## 7. Contrat JSON V2

Principe directeur : **extension additive**, jamais de renommage ni de suppression d'un champ lu aujourd'hui par `index.html`/`scripts/weather-data.js`/les widgets embarqués/`generate_capsule.py`.

```jsonc
{
  "schema_version": "3.0",                         // nouveau — obligatoire
  "methodology_version": {                         // nouveau — obligatoire
    "protocol_version": "0.3",
    "longitudinal_methodology_version": "1.0",
    "baseline_method": "median_mad_fixed_window_v1",
    "thresholds_status": "provisional",
    "changed_at": "..."
  },
  "observation_metadata": {                        // existant, complété
    "generated_at": "...",                         // existant (déjà "generated_at")
    "protocol": { /* existant, inchangé */ }
  },
  "evidence_integrity": {                          // nouveau — obligatoire
    "chain": { "prev_hash": "...", "content_hash": "...", "sequence_index": 0 }, // existant, déplacé/répété ici pour clarté
    "capsule_generator_note": "reconstructed_v0.2" // nouveau — traçabilité de l'incident generate_capsule.py
  },
  "probe_contract": { /* existant, inchangé : daily{} / longitudinal{} */ },
  "global_condition": "unsettled",                 // existant, inchangé — daily uniquement
  "global_judgment_demand": { /* existant, inchangé */ },
  "global_score": 40,                              // existant, inchangé
  "panel_summary": { /* existant, inchangé */ },
  "global_longitudinal_summary": {                 // nouveau — calculé
    "systems_standard": 0,
    "systems_attention_accrue": 0,
    "systems_attention_renforcee": 0,
    "systems_attention_critique": 0,
    "systems_insufficient_data": 0,
    "baseline_window": { "start": "2026-08-21", "days": 14 }
  },
  "detected_events": [ /* nouveau — calculé, cf. §5, niveau global */ ],
  "systems": [
    {
      /* --- champs existants, INCHANGÉS --- */
      "id": "openai", "display_name": "OpenAI", "provider": "OpenAI",
      "model": "gpt-4o-2024-11-20", "model_display": "ChatGPT",
      "condition": "clear", "score": 100, "coverage": 1,
      "judgment_demand": { /* existant */ }, "metrics": { /* existant */ },
      "daily": { /* existant, inchangé — daily_challenge */ },

      /* --- nouveau : identité vérifiable --- */
      "system_identity": {                          // nouveau — obligatoire
        "model_declared": "gpt-4o-2024-11-20",       // = config/panel.yml aujourd'hui
        "model_requested": "chat-latest",            // nouveau — ce que le runner envoie réellement
        "model_returned": null,                      // nouveau — capturé depuis la réponse API (non disponible actuellement, à ajouter §8)
        "model_pinned": false,                        // calculé
        "sampling_params_controlled": true            // calculé — false pour Google
      },

      /* --- nouveau : canal longitudinal complet --- */
      "longitudinal_reference": {                    // nouveau bloc — remplace le "longitudinal" actuel, l'étend
        "role": "longitudinal", "weather_authority": false,   // existant, inchangé
        "probe_id": "longitudinal-core-01",           // existant, inchangé
        "exposure": "lab_only",                       // existant, inchangé
        "expected_repetitions_per_system": 7,          // existant, inchangé
        "coverage_today": 1.0,                          // existant (déjà présent sous une autre forme)
        "baseline": {                                  // nouveau — calculé
          "status": "established",                      // established | not_established
          "window_start": "2026-08-21", "window_days": 14,
          "median": 92.8, "mad": 4.1
        },
        "current_longitudinal_state": {                 // nouveau — calculé, remplace condition:null
          "state": "standard",                            // standard | attention_accrue | attention_renforcee | attention_critique | insufficient_data
          "deviation_index": 0.3,
          "streak_days": 0,
          "since": "2026-09-16"
        },
        "trajectory_available": true                     // nouveau — calculé
      },

      "coverage_detail": { /* existant, complété avec longitudinal_panel_coverage déjà présent au niveau panel_summary, ajouté ici au niveau système si utile */ }
    }
  ]
}
```

### Statut de chaque champ

| Statut | Champs |
|---|---|
| **Obligatoire (nouveau)** | `schema_version`, `methodology_version`, `evidence_integrity`, `system_identity.model_declared/model_requested/model_pinned`, `longitudinal_reference.baseline.status`, `longitudinal_reference.current_longitudinal_state.state` |
| **Optionnel (nouveau)** | `detected_events[]` (peut être vide), `global_longitudinal_summary`, `longitudinal_reference.current_longitudinal_state.streak_days` |
| **Calculé** | tout `current_longitudinal_state`, `baseline.median/mad`, `deviation_index`, `global_longitudinal_summary.*`, `model_pinned`, `sampling_params_controlled` |
| **Non disponible actuellement — à instrumenter** | `system_identity.model_returned` (nécessite de capturer le champ modèle échoïsé par chaque API dans les 12 runners), corroboration externe de `known_model_version_change` (nécessite `config/provider_changelog.json`, à créer) |
| **Existant, strictement inchangé** | tous les champs déjà lus par `index.html`/`scripts/weather-data.js`/les widgets : `global_condition`, `global_score`, `panel_summary.*`, `systems[].{id,display_name,model,model_display,public_label,condition,score,coverage,judgment_demand,metrics,daily}`, `probe_contract.daily.*` |

### Compatibilité avec les consommateurs actuels

- `index.html`, `weather-data.js`, tous les `weather-bar-*.html`/`weather-sidebar-*.html` ne lisent que les champs listés "existant, strictement inchangé" ci-dessus → **aucune régression attendue** tant que ces clés ne sont ni renommées ni supprimées.
- `aiweather-capsule/generate_capsule.py` (`build_public_model_record`, `normalize_ai_weather_history`) devra être **étendu** (pas réécrit) pour projeter `system_identity` et `longitudinal_reference` dans les capsules futures — en gardant à l'esprit que ce générateur est une **reconstruction** (original perdu, cf. son propre en-tête) : toute modification doit être revalidée avec `verify_chain.py` sur une copie de la chaîne réelle avant toute écriture en production (voir Implementation Plan, Phase 2).
- `data/current.json` == `weather.json` doit rester une égalité stricte après extension (les deux fichiers continuent d'être générés à partir de la même structure interne).

---

## 8. Corrections aux bloqueurs identifiés par l'audit

| Bloqueur (audit §11) | Correction proposée | Comment la vérifier |
|---|---|---|
| Alias OpenAI non épinglé + 3 configs divergentes (`chat-latest` / `gpt-4o-2024-11-20` / `gpt-5.2`) | **Résolu méthodologiquement (Gate de validation, 2026-09-16)** : `config/panel.yml` devient la **seule** source déclarée (son propre en-tête le prévoit déjà : « single editable source »). `run_weather_openai.ps1` doit demander exactement ce que `panel.yml.model_id` déclare, plus jamais un alias. `weather_models.json` est soit régénéré depuis `panel.yml`, soit explicitement marqué "documentation historique, non source de vérité". Le schéma canonique `system_identity` (avec `identity_status`: `verified`/`declared`/`inferred`/`unknown`) est défini dans `AI_WEATHER_V2_VALIDATION_GATE.md` §2.A — l'alias `chat-latest` actuel classerait OpenAI en `unknown`, pas `declared`, tant qu'il n'est pas remplacé. L'édition mécanique de `panel.yml`/du runner reste à exécuter en Phase 0 | Test automatisé (Phase 0) comparant `panel.yml.model_id` au littéral `$MODEL` de chaque `run_weather_*.ps1` — échoue si divergence. Capture de `model_returned` (voir ci-dessous) comme preuve continue. |
| Divergence secondaire Anthropic/Cohere entre `panel.yml` et `weather_models.json` | Même réconciliation ; priorité moindre car `weather_models.json` n'est lu par aucun runner actif (à confirmer en Phase 0) | Même test automatisé, étendu aux 12 systèmes |
| Capsules du 17 et du 21 août au schéma non vérifié | **Résolu par inspection directe (Gate de validation, 2026-09-16)** : la capsule du 17/08 (`sequence_index:0`) est confirmée protocole v0.1 (design pré-scission "1 question × 30 répétitions", pas de `longitudinal_policy`) → exclue structurellement du canal longitudinal. La capsule du 21/08 (`sequence_index:1`) est confirmée protocole v0.2 (split daily/longitudinal déjà actif, `longitudinal_fully_scored: 77/84 = 91.67%`) → **utilisable**, avec une couverture partielle documentée ce jour-là. La fenêtre longitudinale démarre donc le **21/08**, un jour plus tôt que ce que ce document affirmait précédemment | Voir `AI_WEATHER_V2_VALIDATION_GATE.md` §2.B pour le détail des champs inspectés et la preuve |
| Grounding web permanent (Perplexity) / paramètres non contrôlés (Google) | Tag permanent `system_identity.sampling_params_controlled: false` (Google) et `protocol_notes: ["web_grounding_active"]` (Perplexity), affiché partout où leur état longitudinal est montré ; confiance des événements `persistent_deviation` structurellement abaissée pour ces deux systèmes tant que non résolu | Champ visible dans le JSON public + dans Model Detail (§9) |
| Changements futurs de snapshot/identité fournisseur | Capture systématique de `model_returned` (champ modèle échoïsé par l'API, quand disponible) pour les 12 runners ; diff automatique jour/jour → déclenche `known_model_version_change` (confiance haute si corroboré par `config/provider_changelog.json`, nouveau fichier curé manuellement ; confiance moyenne sinon, mais toujours signalé) | Test de non-régression : le pipeline doit échouer bruyamment (log, pas blocage de publication — cf. politique "always-push") si `model_returned` cesse d'être capturable pour un système auparavant instrumenté |
| Version du protocole et de la méthode de calcul non tracée | `methodology_version` devient un objet versionné explicite (protocole, méthode de baseline, statut des seuils), publié dans chaque snapshot, avec journal de changement associé (`AI_WEATHER_METHODOLOGY_CHANGELOG.md`, nouveau) | Toute modification de seuil/méthode doit s'accompagner d'un incrément de version et d'une entrée de changelog — corrige la dérive doc/code déjà constatée (`AWI-023`, seuils "à recalibrer" jamais recalibrés) |

---

## 9. Architecture du site V2

| Section | Données nécessaires | Composant / affichage | Wording possible | Cas données insuffisantes | Existant vs à créer |
|---|---|---|---|---|---|
| **HERO** | aucune (statique) | bannière d'en-tête | « AI WEATHER — Observable AI behavior under constant reference conditions. » | n/a | Existe déjà un bandeau de marque dans `index.html` ; à créer : la formulation exacte + lien vers la méthodologie |
| **CURRENT STATE** | `global_longitudinal_summary` (nouveau — devient la synthèse **principale** en cible V2, §2) + `panel_summary` (existant, daily, affiché en contexte secondaire "Today's Challenge") | bande de synthèse / cartes, statut AI Weather en avant, couverture Today's Challenge en second plan | « AI Weather : N/12 systèmes en Standard. Couverture longitudinale : X %. N systèmes présentent un changement de comportement notable (voir What Changed). » | si couverture longitudinale globale faible : « Couverture longitudinale insuffisante aujourd'hui — dernier état confirmé du [date]. » Pendant le shadow mode (état 2, §2) : cette section continue d'afficher le statut daily existant, le rollup longitudinal n'étant pas encore publié | Rendu de `panel_summary` déjà existant (aujourd'hui seul statut affiché) ; à créer : le rollup longitudinal + la bannière de couverture, et l'inversion de mise en avant à la bascule finale |
| **WHAT CHANGED?** | `detected_events[]` (nouveau), limité aux 3 plus significatifs/récents | nouvelle "carte événement" (titre, wording prudent, date, système concerné, lien vers Model Detail) | textes-types de la section 5 | état vide explicite : « Aucun changement de comportement significatif détecté sur le panel dans la fenêtre d'observation actuelle. » | N'existe pas aujourd'hui (le quiz "Spot the Drift" est adjacent mais différent) ; entièrement à créer |
| **TODAY'S CHALLENGE** | `probe_contract.daily.question`(+traductions), `systems[].daily/condition/score` — déjà existant | mur d'observation actuel, reformulé | « Comment 12 systèmes IA ont répondu aujourd'hui à cette question. » + texte de la question | déjà géré (`insufficient_data` par système existe déjà) | C'est essentiellement le rendu actuel de `index.html` ; à créer : le recadrage éditorial (ce n'est plus "the weather", c'est "the challenge") |
| **MODEL DETAIL** | `longitudinal_reference` complet (baseline, trajectoire, état, événements), `daily` du jour, historique de couverture | vue détaillée par système : graphique trajectoire + bande de baseline, chronologie d'événements, réponse du jour | « Comportement de [Système] sur la question de référence, comparé à sa propre base, sur les N derniers jours. » / « Réponse au challenge du jour : ... » | jours manquants affichés comme trous dans le graphique (jamais interpolés, cohérent avec `loadHistory()` actuel) ; si baseline non établie : « Historique insuffisant pour établir une base (N jours nécessaires, M disponibles). » | `scripts/weather-data.js` fournit déjà `loadHistory()`/`sparklineSvg()` à étendre ; à créer : tracé du score longitudinal, bande de baseline, chronologie d'événements, page/vue de détail par système (n'existe pas aujourd'hui) |
| **FOR DEVELOPERS / RESEARCHERS** | docs de méthodologie, schéma JSON, liens vers données brutes, limites d'interprétation | page de documentation | reprend/étend les avertissements déjà écrits (« observation, not a performance or quality score », `QUESTION_CATEGORIES_METHODOLOGY_EN.md`) | n/a | `README.md`/`integration_EN.md`/docs de méthodologie existent déjà et sont de bonne qualité ; à créer : une page unique consolidée expliquant la distinction daily/longitudinal aux visiteurs (absente aujourd'hui — bloqueur §11.8 de l'audit) |

---

*Fin du document d'architecture. Voir `AI_WEATHER_V2_IMPLEMENTATION_PLAN.md` pour le découpage en phases. Aucune implémentation n'a été commencée.*
