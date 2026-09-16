# AI Weather V2 — Validation du moteur shadow (Phase 1)

**Statut :** vérification uniquement. Aucun fichier public, aucune capsule historique, aucun widget, aucune API publique n'a été modifié pour produire ce document. Aucun paramètre de calibration n'a été changé. La Phase 2 n'a pas commencé.

---

## 1. Provenance du score historique (`systems[].longitudinal.score`)

**Fichier / fonction exacts** : `AI_WEATHER_RUNNER/aggregate_and_publish_weather.ps1`, fonction `Get-ProbeAggregate` (ligne 754), appelée pour le rôle longitudinal à la ligne 1279-1286 :

```powershell
$longitudinalRows = @($rows | Where-Object { (Get-ProbeRole $_) -eq "longitudinal" })
$longitudinal = Get-ProbeAggregate -Rows $longitudinalRows -ExpectedObservations $LONGITUDINAL_PROBE_EXPECTED `
    -Role "longitudinal" -WeatherAuthority $false -Provider $entry.runner_provider -DateStr $Date
```

**Données sources** : `$rows` = lecture brute (`Read-Jsonl`, ligne 410) du fichier `AI_WEATHER_RUNNER/results/<date>/*_results.jsonl` le plus récent pour ce fournisseur ce jour-là. Ces lignes sont ensuite **filtrées AVANT tout calcul** par `Get-ProbeRole` (ligne 374), qui classe chaque ligne `daily` / `longitudinal` / `unknown` selon le champ explicite `probe_role`, ou à défaut le préfixe de `prompt_id` (`^longitudinal(-|_)`). Seules les lignes classées `longitudinal` entrent dans `Get-ProbeAggregate` pour ce calcul — **structurellement, aucune ligne de la question quotidienne ne peut y entrer**, puisque `$dailyRows` et `$longitudinalRows` sont deux partitions disjointes du même flux, construites par deux `Where-Object` séparés (lignes 1244-1256).

**Formule exacte** (`Get-ProbeAggregate`, lignes 764-833) :
```
validRows   = lignes dont decision n'est ni vide ni "ERROR"
fullyScored = count(validRows)
normalCount = count(validRows où decision == "ALLOW")
score       = round(100 * normalCount / fullyScored)   si fullyScored > 0, sinon 0
```
Note de précision : `metrics.normal/variation/factual_alert/incomplete` (utilisés par le moteur V2 pour `variability_increase`) sont des fractions sur `ExpectedObservations` (7), **pas** sur `fullyScored` — un dénominateur différent de celui de `score`. Les deux sont cohérents mais pas interchangeables ; le moteur V2 ne mélange jamais les deux dénominateurs (il lit `score` directement pour le niveau, `metrics.variation` séparément pour la dispersion).

**A-t-elle changé depuis le 21/08 ?** Non vérifiable formellement : `AI_WEATHER_RUNNER/` est intégralement gitignoré (`.gitignore:163`), donc **aucun historique Git n'existe** pour ce script — impossible de diffractures des versions passées. Preuve indirecte forte en revanche : la capsule réelle du 21/08 (`aiweather-capsule/capsules/2026/08/21.json`) contient, pour OpenAI, `regime_distribution:{normal:0,...}` et `score:0` sur `fully_scored:7` — exactement la valeur que produit la formule actuelle appliquée à ces mêmes comptages. C'est une reproduction exacte, pas une simple plausibilité, ce qui constitue un indice solide de continuité de la formule, sans être une preuve de version control.

**Dépend-il de la question quotidienne ?** Non — démontré structurellement ci-dessus (partition disjointe des lignes avant agrégation).

**Utilise-t-il exclusivement la sonde longitudinale constante ?** Oui — le filtre `Get-ProbeRole` ne retient que les lignes dont `prompt_id` commence par `longitudinal` (en pratique : `longitudinal-core-01`, le seul `prompt_id` longitudinal existant depuis le 21/08, cf. audit §3).

**Le score est-il "identique pour toutes les dates" ?** La *formule* est appliquée identiquement à chaque date par le même code (pas de branchement par date) — la *valeur* varie naturellement jour après jour, c'est la mesure elle-même qui fluctue (attendu et souhaité).

**Contient-il déjà une interprétation ?** Non — confirmé ligne par ligne (`Get-ProbeAggregate`, lignes 932-972) : le bloc `interpretation`/`condition`/`judgment_demand` n'est construit que `if ($WeatherAuthority)`. Pour l'appel longitudinal, `$WeatherAuthority = $false` (ligne 1284) → la branche `else` s'exécute, qui fixe `condition = $null` sans jamais appeler `Get-WeatherInterpretation`. `score` est donc une **mesure pure** (un comptage transformé en pourcentage), jamais un jugement.

**Réserve honnête à conserver** : `score` repose sur le champ `decision` (ALLOW/FLAG/ERROR), lui-même produit en amont par une API de gouvernance tierce non documentée dans ce dépôt (`Invoke-CompleteGovernance`, déjà signalée dans l'audit §11.4). Ce n'est pas une dépendance nouvelle introduite par le moteur V2 — c'est la même dépendance que le Weather quotidien public utilise déjà aujourd'hui. Le moteur V2 n'ajoute aucune couche d'opacité supplémentaire ; il en hérite une déjà existante.

---

## 2. Compatibilité avec l'invariant V2

> AI Weather = état longitudinal du comportement observable sous stimulus constant.

**Verdict : compatible, démontré.**

| Critère | Résultat |
|---|---|
| Calculé exclusivement à partir de la sonde constante | ✅ démontré (partition de rôle avant agrégation) |
| Indépendant de la question quotidienne variable | ✅ démontré (partitions disjointes) |
| Mesure pure, sans interprétation pré-injectée | ✅ démontré (`WeatherAuthority=$false` court-circuite l'interprétation) |
| Formule stable dans le temps | ⚠️ non vérifiable formellement (pas d'historique Git), mais reproduite exactement sur la capsule du 21/08 |
| Dépendance amont documentée | ⚠️ dépend de `decision`, produit par une API de gouvernance tierce non documentée — dépendance héritée, pas nouvelle |

Aucune dette méthodologique bloquante n'a été trouvée sur la provenance elle-même. La réserve sur la formule non versionnée est déjà couverte par la recommandation Gate §3.C (`methodology_version`/`baseline_config_version`, déjà implémentée dans le moteur V2).

---

## 3. Exemple de sortie réelle — 3 systèmes

Rejeu réel exécuté le 2026-09-16, fenêtre 21/08 → 16/09 (26 jours). `methodology_version` et `baseline_config_version` sont identiques pour les 3 systèmes (paramètres globaux du moteur) :
```
methodology_version = { protocol_version: "0.2", longitudinal_methodology_version: "1.0",
                         baseline_method: "median_mad_fixed_window_v1", thresholds_status: "provisional" }
baseline_config_version = "shadow-v0.1"
```

### Système stable malgré un bruit brut réel — Cohere

| Champ | Valeur |
|---|---|
| Date (état courant) | 2026-09-16 |
| Score courant | 57 |
| Baseline (médiane / dispersion) | médiane = 43, MAD = 28 (fenêtre 22/08 → 05/09, 14 jours) |
| Écart normalisé | 0.5 |
| Couverture | 1.0 |
| État longitudinal | **standard** |
| Événements | 4× `behavioral_deviation_detected` (06/09, 08/09, 10/09, 14/09) — jamais confirmés en `persistent_deviation` ; 1× `coverage_anomaly` (21/08, jour capsule sans donnée valide) ; 1× `model_identity_unverified` (portée système) |
| Identité modèle | `model_declared: command-a-03-2025`, `identity_status: declared` |
| `model_requested` | `command-a-03-2025` |
| `model_returned` | `null` (non capturé — voir §7) |

Cohere illustre le mieux l'anti-flapping : ses scores bruts oscillent violemment jour après jour (71, 14, 43, 29, 0, 71, 83, 0, 57, 0...), avec quatre alertes ponctuelles isolées, et pourtant **aucune escalade** ne se produit puisque deux jours consécutifs n'ont jamais franchi le seuil dans la même direction.

### Système présentant une variation détectée — Mistral

| Champ | Valeur |
|---|---|
| Date (état courant) | 2026-09-16 |
| Score courant | 71 |
| Baseline (médiane / dispersion) | médiane = 86, MAD = 14 (fenêtre 21/08 → 04/09, 14 jours) |
| Écart normalisé | -1.07 |
| Couverture | 1.0 |
| État longitudinal | **attention_accrue** |
| Événements | 2 épisodes complets : rupture (05-09/09, `persistent_deviation` le 06/09) → retour (`return_to_baseline` le 11/09) → nouvelle rupture (13-16/09, `persistent_deviation` le 14/09, toujours active) ; 1× `model_identity_unverified` |
| Identité modèle | `model_declared: mistral-medium-3-5`, `identity_status: declared` |
| `model_requested` | `mistral-medium-3-5` |
| `model_returned` | `null` |

### Système à identité et couverture imparfaites — OpenAI

| Champ | Valeur |
|---|---|
| Date (état courant) | 2026-09-16 |
| Score courant | 100 |
| Baseline (médiane / dispersion) | médiane = 100, MAD = 0 (fenêtre 21/08 → 04/09) — voir limite §7 |
| Écart normalisé | 0 |
| Couverture | 1.0 (aujourd'hui ; a été 0 le 10/09) |
| État longitudinal | **standard** |
| Événements | `coverage_anomaly` le 10/09 (`fully_scored:0/7`, panne complète ce jour) ; `model_identity_unverified` (portée système) |
| Identité modèle | `model_declared: gpt-4o-2024-11-20` |
| `model_requested` | **`chat-latest`** (alias non épinglé — cf. audit, Gate §3.A) |
| `model_returned` | `null` (jamais capturé pour aucun système à ce jour) |
| `identity_status` | **`unknown`** (pas `declared` : un alias non épinglé n'a pas la stabilité requise pour ce statut) |

---

## 4. Analyse temporelle — Mistral, 12 jours (05/09 → 16/09)

Baseline fixe sur toute la période : médiane 86, MAD 14.

| Date | Score | État | Événement |
|---|---|---|---|
| 2026-09-05 | 57 | standard | `behavioral_deviation_detected` (isolé, non confirmé) |
| 2026-09-06 | 71 | **attention_accrue** | `persistent_deviation` (2ᵉ jour consécutif de déviation) |
| 2026-09-07 | 57 | attention_accrue | — |
| 2026-09-08 | 71 | attention_accrue | — |
| 2026-09-09 | 57 | attention_accrue | — |
| 2026-09-10 | 86 | attention_accrue | — (retour sous le seuil, 1ᵉʳ jour du décompte de désescalade) |
| 2026-09-11 | 86 | **standard** | `return_to_baseline` (2ᵉ jour consécutif sous le seuil) |
| 2026-09-12 | 86 | standard | — |
| 2026-09-13 | 71 | standard | `behavioral_deviation_detected` (isolé) |
| 2026-09-14 | 71 | **attention_accrue** | `persistent_deviation` (2ᵉ jour consécutif) |
| 2026-09-15 | 86 | attention_accrue | — |
| 2026-09-16 | 71 | attention_accrue | — |

**Constats visuels** :
- **Pas de flapping** : le 05/09 (1 seul jour à 57) ne change pas l'état affiché ; il faut le 06/09 (2ᵉ jour consécutif) pour escalader.
- **Persistance correcte** : l'état reste `attention_accrue` du 06/09 au 09/09 sans repasser à `standard` malgré une légère remontée à 71 le 06 et 08/09 (le seuil reste franchi).
- **Rupture détectée** : deux épisodes distincts, correctement isolés l'un de l'autre.
- **Stabilisation / retour à la baseline** : cycle complet 10/09→11/09, désescalade en exactement 2 jours (conforme à `return_to_baseline_days.attention_accrue = 2`), jamais un saut direct.
- **Deuxième rupture** : le système replonge le 13-14/09 — le moteur ne "mémorise" pas faussement une bonne santé après un seul retour, il réévalue chaque fenêtre de persistance indépendamment.

---

## 5. Résultat des tests

**25/25 réussis** (23 initiaux + 2 assertions ajoutées lors de cette vérification pour verrouiller l'exclusion du jour démo `2026-08-16`, découverte comme bug pendant la Phase 1 — voir §6/§7).

Détail des 7 suites : stabilité, observation isolée, rupture persistante, retour à la baseline, couverture insuffisante, identité non épinglée, garde-fou réel (hash + diff git). Sortie complète disponible sur demande — aucun échec au dernier passage (2026-09-16, après correction de l'exclusion du 16/08).

---

## 6. Fichiers créés / modifiés

**Aucun fichier public ou de production modifié.** Fichiers créés, tous nouveaux, tous sous `AI_WEATHER_RUNNER/` (intégralement gitignoré, `.gitignore:163`) :

| Fichier | Statut |
|---|---|
| `AI_WEATHER_RUNNER/longitudinal_engine.ps1` | Créé |
| `AI_WEATHER_RUNNER/config/longitudinal_engine_config.json` | Créé (corrigé en cours de route : ajout de `2026-08-16` aux dates exclues) |
| `AI_WEATHER_RUNNER/config/provider_changelog.json` | Créé |
| `AI_WEATHER_RUNNER/tests/test_longitudinal_engine.ps1` | Créé |
| `AI_WEATHER_RUNNER/shadow/longitudinal_shadow_report_*.json` | Généré à l'exécution (sortie, jamais lue par le public) |
| `AI_WEATHER_V2_SHADOW_VALIDATION.md` | Ce document |

**Preuve d'impact zéro (`git diff --stat`, dépôt entier, exécuté le 2026-09-16 après le dernier rejeu)** :
```
 AI_WEATHER_KNOWN_FIXES.md    | 61 +++++++++++++++++++++++++++++++
 AI_WEATHER_PIPELINE_AUDIT.md | 19 +++++++++--
 config/panel.yml             |  2 +-
 index.html                   | 45 +++++++++++++++++++++++
 4 files changed, 124 insertions(+), 3 deletions(-)
```
Ces 4 modifications **préexistaient à toute cette investigation** (visibles dès le tout premier état du dépôt en début de conversation, avant toute intervention sur la sonde longitudinale) et ne touchent ni `weather.json`, ni `data/current.json`, ni `data/history/*.json`, ni aucune capsule, ni aucun widget. `git diff` sur ces 4 fichiers ne montre aucune trace du moteur longitudinal.

`weather.json`, `data/current.json`, `data/capsule-index.json`, `aiweather-capsule/latest.json` apparaissaient modifiés au tout début de la conversation (probablement republiés depuis par le pipeline de production planifié, Measure@7h/Release@14h, sans rapport avec ce travail) et n'apparaissent plus modifiés au moment de cette vérification — confirmé par `git status --porcelain` et par le contrôle de hachage SHA-256 ci-dessous, tous deux indépendants de ce constat.

**`AI_WEATHER_RUNNER/` étant intégralement gitignoré, `git diff`/`git status` ne peuvent physiquement pas y montrer les nouveaux fichiers** — c'est pourquoi la preuve d'impact zéro repose sur un contrôle de hachage SHA-256 direct (Test 7, ci-dessous), plus rigoureux qu'un simple `git diff` pour ce cas précis.

**Contrôle de hachage SHA-256 avant/après le dernier rejeu réel** — `weather.json`, `data/current.json`, `data/capsule-index.json`, `aiweather-capsule/latest.json`, capsules du 17/08, 21/08, 16/09, `index.html`, `scripts/weather-data.js` : **identiques bit à bit avant et après**, confirmé par le test automatisé "garde-fou réel" (§5), passé au dernier run.

---

## 7. Anomalies ou limites restantes

1. **Découverte de calibration majeure** : avec 7 répétitions/jour, le score ne prend que 8 valeurs discrètes possibles (0, 14, 29, 43, 57, 71, 86, 100). Le MAD de la fenêtre de baseline tombe fréquemment à **0** (OpenAI, Meta, Perplexity ce mois-ci) dès qu'une majorité de jours partagent la même valeur — rendant le seuillage "en multiples de MAD" hypersensible à la moindre variation. Ce n'est pas un défaut du moteur (il gère le cas sans diviser par zéro et sans fausse escalade sur un jour isolé, cf. Meta au §précédent tour) mais une limite de la méthode "médiane+MAD" recommandée en V1 sur des séries aussi courtes/discrètes. **À trancher explicitement en calibration (Gate §2.2/§2.3)**, pas silencieusement.
2. `model_returned` n'est capturé pour aucun système à ce jour (instrumentation Phase 0 non exécutée) — `identity_status` ne peut donc jamais atteindre `verified` dans ce rejeu. Attendu, documenté, pas un défaut du moteur.
3. `known_data_exclusions` (dates précises du bug de panel Moonshot) reste vide — Phase 0 non exécutée dans ce tour.
4. `known_model_version_change` ne détecte qu'un changement du champ `model` déclaré (config), pas un écho API réel — confiance volontairement abaissée en conséquence.
5. La formule de `score` n'est pas formellement vérifiable dans le temps faute d'historique Git sur `AI_WEATHER_RUNNER/` (gitignoré) — seule une preuve de reproduction exacte sur la capsule du 21/08 est disponible (§1).

Aucune de ces limites ne remet en cause l'intégrité du moteur ou l'absence d'impact public — elles concernent toutes la **qualité de la calibration à venir**, pas la correction de ce qui a été construit en Phase 1.

---

## 8. Verdict technique

**READY_FOR_CALIBRATION**

La provenance du score est démontrée et compatible avec l'invariant "AI Weather = état longitudinal sous stimulus constant" (§1-2). Le moteur passe 25/25 tests, y compris un garde-fou de non-régression sur données réelles. Aucun fichier public, capsule, widget ou API n'a été modifié. Le seul point substantiel trouvé (dégénérescence du MAD à 0 sur une échelle à 8 valeurs) est une question de **calibration des seuils**, explicitement hors périmètre de cette étape et déjà prévue comme décision provisoire à trancher (Gate §2.2/§2.3) — ce n'est ni un défaut de provenance (`NEEDS_SCORE_LINEAGE_FIX`) ni un défaut du moteur lui-même (`NEEDS_ENGINE_FIX`), mais l'exact type de résultat que le shadow mode est censé produire avant calibration.

---

*Fin du document. Phase 2 non commencée. Aucun paramètre de calibration modifié. En attente de validation.*
