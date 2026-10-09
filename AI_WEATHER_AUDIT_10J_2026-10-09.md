# AI Weather — audit des dix derniers jours et harmonisation du wording

**Date de l'audit :** 2026-10-09
**Fenêtre examinée :** 2026-09-29 → 2026-10-09 (11 journées de mesure)
**Dépôt :** `neomundi-io/neomundi-ai-weather`, branche `main`

---

## 0. Périmètre vérifié

Deux hébergements distincts, à ne jamais confondre :

| Rôle | Hôte | Mécanisme | Vérification |
|---|---|---|---|
| **Flux de mesure** (`weather.json`, `data/history/`, capsules, widgets) | `weather.controltowerai.io` | `CNAME` du dépôt → **GitHub Pages**, publié par `git push origin main` depuis `release_ai_weather.ps1` | `Server: GitHub.com`, `Last-Modified: Fri, 09 Oct 2026 12:01:13 GMT` (= fenêtre Release 14 h Paris) |
| **Site éditorial** (pages FR/EN, wording) | `aiweather.controltowerai.io` | WordPress Infomaniak, thème **`ai-weather-v2` 0.1.0-alpha** actif, Polylang FR/EN ; le texte vit dans `post_content`, pas dans les fichiers du thème | `302 → /fr/`, IP Infomaniak, `wp-cli theme list` |

`neomundi.org` et `neomundi.cloud` existent sur le même compte SSH et **n'ont pas été touchés**.

Accès serveur contrôlé en lecture avant toute écriture (clé ED25519 dédiée chargée dans l'agent Windows, empreinte `SHA256:BYoQ…DRXM`). Aucun secret affiché, aucun secret écrit dans ce document.

**Correction d'une croyance antérieure :** une note interne du 2026-09-26 concluait que la mise en ligne de `weather.controltowerai.io` venait d'une « synchro hors-dépôt côté hébergeur ». L'en-tête `Server: GitHub.com` observé aujourd'hui établit que l'hôte **est** GitHub Pages et que le `git push` est bien le mécanisme de publication du flux. Le délai constaté à l'époque était un retard de propagation, pas un autre pipeline.

---

## 1. Volume du protocole : valeurs confirmées

Source de vérité unique et **datée** : `AI_WEATHER_RUNNER/config/protocol_volume.json`, résolue par date de mesure par `AI_WEATHER_RUNNER/lib/Get-ProtocolVolume.ps1`.

| Profil | En vigueur | Challenge du jour (`daily`) | Question de référence (`longitudinal`) | Total / système / jour | Panel (12 systèmes) |
|---|---|---|---|---|---|
| `WEATHER-SENTINEL-VOL-30` | 2026-08-21 → 2026-10-08 | 23 | 7 | 30 | 360 |
| `WEATHER-SENTINEL-VOL-10` | **depuis 2026-10-09** | **3** | **7** | **10** | **120** |

Confirmé dans les exécutions réelles, pas seulement dans la configuration :

- `data/history/2026-10-09.json` → `protocol.expected_observations_per_system = 10`, `daily_probe_expected = 3`, `longitudinal_probe_expected = 7`, `total_expected_panel_observations = 120`, `volume_profile.profile_id = "WEATHER-SENTINEL-VOL-10"`.
- `data/history/2026-10-08.json` et antérieurs → `30 / 23 / 7 / 360`, sans `volume_profile` (le champ n'existait pas).
- Fichiers bruts : `AI_WEATHER_RUNNER/results/2026-10-09/` contient **120 lignes** (10 × 12) contre **360** les jours précédents.
- Suite de tests `AI_WEATHER_RUNNER/tests/test_protocol_volume.ps1` : **44 / 44** au 2026-10-09.

Les valeurs annoncées dans la demande (7 longitudinales + 3 Challenge) sont donc **exactes et en production**.

---

## 2. Chronologie des versions — une version par axe, à ne pas confondre

La demande évoquait « deux versions successives et une troisième en cours de déploiement ». Les preuves ne confirment pas une chronologie unique à trois temps : **il y a quatre axes de version indépendants**, qui n'ont pas bougé aux mêmes dates. C'est précisément cette désynchronisation qui rend la fenêtre non homogène.

| Axe | Valeurs sur la fenêtre | Date de bascule | Preuve |
|---|---|---|---|
| **Site / thème WordPress** | `ai-weather` 0.2.1 → **`ai-weather-v2` 0.1.0-alpha** (actif) | avant la fenêtre (thème v2 déposé le 2026-09-26) | `wp-cli theme list`, `mtime` des répertoires de thèmes |
| **Agrégateur (ce dépôt)** | inchangé | **aucune bascule dans la fenêtre** : dernier commit sur `aggregate_and_publish_weather.ps1` / `config/` avant la fenêtre = `0b14085` (2026-09-22) ; suivant = `4efa0c4` (2026-10-08) | `git log -- AI_WEATHER_RUNNER/aggregate_and_publish_weather.ps1 config/panel.yml AI_WEATHER_RUNNER/config/` |
| **Protocole / volume** | VOL-30 → **VOL-10** | **2026-10-09** (cycle Measure 07 h Paris) ; versionné la veille par `4efa0c4` | `protocol_volume.json`, `volume_profile` publié, comptage des lignes brutes |
| **`measurement_version` de l'API** | **3.0.0 → 3.1.0** | **2026-10-03** | `provenance.measurement_version` des contrats d'interopérabilité et champ `measurement_version` des lignes brutes |
| **Évaluateurs / modèles / prompts / paramètres** | inchangés | **aucune bascule** | §4 |

**Point méthodologique explicitement respecté :** la version de mesure n'a **pas** été déduite d'une date de commit. Elle a été relevée observation par observation dans la provenance des données, et elle ne coïncide avec aucun commit : la bascule 3.1.0 du **2026-10-03** tombe un jour où le dépôt n'a produit qu'une release canonique automatique (`f11c666`), sans aucun changement de code.

Ce qui est « en cours de déploiement » au 2026-10-09 n'est donc pas une troisième version de mesure : c'est **VOL-10** (premier cycle mesuré aujourd'hui) et l'harmonisation du wording livrée par cet audit. Aucune troisième entrée de volume, aucune `measurement_version` 3.2.x, aucun troisième thème n'existe dans les preuves disponibles.

---

## 3. Volumes attendus, reçus, mesurés

| Date | Attendu | Reçu | ERROR | Valides | Contrats API à couverture 1.0 | `measurement_version` | FLAG | `global_score` | Condition | États longitudinaux |
|---|---|---|---|---|---|---|---|---|---|---|
| 2026-09-29 | 360 | 360 | 0 | 360 | 18/360 | 3.0.0 | 8 % | 95 | unsettled | standard 5 · accrue 5 · renforcée 2 |
| 2026-09-30 | 360 | 360 | 1 | 359 | 13/359 | 3.0.0 | 41 % | 54 | unsettled | accrue 6 · standard 4 · renforcée 2 |
| 2026-10-01 | 360 | 360 | 0 | 360 | 8/360 | 3.0.0 | 66 % | 19 | unsettled | standard 5 · accrue 5 · renforcée 2 |
| 2026-10-02 | 360 | 360 | 0 | 360 | 19/360 | 3.0.0 | 8 % | 97 | watch | standard 6 · accrue 4 · renforcée 2 |
| **2026-10-03** | 360 | 360 | 0 | 360 | 12/360 | **3.1.0** | **77 %** | **26** | unsettled | accrue 8 · standard 2 · renforcée 2 |
| 2026-10-04 | 360 | 360 | 15 | 345 | 20/345 | 3.1.0 | 86 % | 8 | insufficient_data | accrue 8 · **critique 2** · renforcée 2 |
| 2026-10-05 | 360 | 360 | 0 | 360 | 7/360 | 3.1.0 | 92 % | 4 | unsettled | **critique 7** · accrue 3 · renforcée 2 |
| 2026-10-06 | 360 | 360 | 1 | 359 | 19/359 | 3.1.0 | 61 % | 44 | unsettled | critique 7 · accrue 3 · renforcée 2 |
| 2026-10-07 | 360 | 360 | 0 | 360 | 12/360 | 3.1.0 | 90 % | 8 | unsettled | **critique 8** · accrue 2 · renforcée 2 |
| 2026-10-08 | 360 | 360 | 0 | 360 | 17/360 | 3.1.0 | 84 % | 15 | unsettled | critique 8 · accrue 2 · renforcée 2 |
| **2026-10-09** | **120** | **120** | 0 | 120 | 50/120 | 3.1.0 | 54 % | 45 | unsettled | critique 8 · accrue 2 · renforcée 2 |

### Intégrité : rien ne manque, rien n'est dupliqué

- **Volume reçu = volume attendu** chaque jour de la fenêtre. Aucune journée tronquée, aucune journée périmée, aucun trou dans `data/history/`.
- **Aucun doublon d'observation.** Le triplet `(provider, prompt_id, repetition_index)` est unique sur les 11 journées.
- Les 14 « `request_id` dupliqués » du 2026-10-04 sont des **chaînes vides** portées par les 15 lignes `ERROR` de DeepSeek (`error_phase = stream_truncated_neomundi`). Ce n'est pas un doublon de mesure, c'est l'absence d'identifiant sur un échec de relais. Ces 15 lignes sont correctement exclues du scoring (`fully_scored` 345/360) et font basculer la journée en `insufficient_data`.
- Lignes `ERROR` sur la fenêtre : 0 sauf 2026-09-30 (1), 2026-10-04 (15), 2026-10-06 (1).

---

## 4. Ni les modèles, ni les prompts, ni les paramètres n'ont changé

Relevé sur les 11 journées de lignes brutes :

- `requested_model` **identique** pour les 12 fournisseurs du premier au dernier jour (`chat-latest`, `claude-sonnet-4-5-20250929`, `gemini-3.6-flash`, `grok-4.5`, `mistral-medium-3-5`, `deepseek-v4-pro`, `qwen3.7-max-2026-06-08`, `kimi-k3`, `command-a-03-2025`, `meta-llama/Llama-3.3-70B-Instruct-Turbo`, `nvidia/NVIDIA-Nemotron-3-Nano-30B-A3B-FP8`, `sonar-reasoning-pro`).
- `temperature_requested = 0.7` partout où le fournisseur l'accepte, `null` sinon. Aucune variation.
- **Exactement un** `prompt_id` quotidien et **un** `prompt_id` longitudinal par jour → `protocol_valid = true` partout.
- La **question de référence longitudinale est strictement identique** sur les 11 jours (`longitudinal-core-01`, sonde à fausse prémisse « poulpes ») : 1 seule formulation distincte sur 11 journées.
- Le seul changement de configuration du dépôt dans la fenêtre est `config/panel.yml`, et uniquement sur le **libellé d'affichage** `model_display` d'Infomaniak (`NVIDIA` → `Nvidia`). Aucun effet sur la mesure.
- `normalizer_version = 1.0.0` sur toute la fenêtre.

**Conséquence :** la baisse observée ne peut pas être attribuée à un changement de stimulus, de modèle ou de paramètre de génération. Aucun de ces leviers n'a bougé.

---

## 5. La baisse : ce que les preuves établissent

### 5.1 Deux ruptures distinctes, aucune des deux dans ce dépôt

**Rupture A — 2026-09-29, canal quotidien seul, `measurement_version` encore 3.0.0.**

Dans les contrats d'interopérabilité, deux signaux cessent largement d'être mesurés :

| Date | `coherence_score` mesuré | `semantic_risk` mesuré | `measurement_status` |
|---|---|---|---|
| 2026-09-26 | 330/360 | 330/360 | complete 330 |
| 2026-09-27 | 329/359 | 329/359 | complete 320 |
| 2026-09-28 | 330/360 | 330/360 | complete 323 |
| **2026-09-29** | **133/360** | **28/360** | **partial 342** |
| 2026-09-30 | 104/359 | 21/359 | partial 346 |

`checks_emitted` passe majoritairement de 3 à 1–2. Le motif de gouvernance `[OBS] Core says WARN -> FLAG` **apparaît pour la première fois le 2026-09-30** (31 lignes). Les 2026-09-30 et 2026-10-01 voient la masse de `stability_score` se déplacer sur 0,615 — juste sous le seuil amont de FLAG — puis le 2026-10-02 revient au comportement antérieur (`global_score` 97). Cet épisode n'affecte **que** le canal quotidien : la médiane longitudinale reste à 86 les 09-30 et 10-01.

**Rupture B — 2026-10-03, les deux canaux, exactement à la bascule 3.1.0.**

| Date | `measurement_version` | `stability_score` modal | `coherence_score` nul | `semantic_risk` nul | `Core says STOP -> FLAG` | Médiane quotidienne | Médiane longitudinale |
|---|---|---|---|---|---|---|---|
| 2026-10-02 | 3.0.0 | **0,9231** (12/13) | 19/360 | 30/360 | **0** | 100 | 71 |
| **2026-10-03** | **3.1.0** | **0,1538** (2/13) | **267/360** | **337/360** | **257** | **26** | **14** |
| 2026-10-05 | 3.1.0 | 0,1538 | 330/360 | 347/360 | 324 | 4 | 14 |
| 2026-10-08 | 3.1.0 | 0,1538 | 289/360 | 330/360 | 279 | 15 | 14 |

Le motif `[OBS] Core says STOP -> FLAG` **n'existe dans aucune ligne avant le 2026-10-03**. Il explique à lui seul 257 à 324 des FLAG quotidiens.

### 5.2 Pourquoi ce n'est pas le comportement des modèles

Quatre arguments indépendants, tous vérifiables :

1. **Les deux canaux s'effondrent le même jour** alors que leurs stimuli n'ont rien en commun : le Challenge change chaque jour, la sonde longitudinale est figée depuis 11 jours. Le 2026-10-03, la médiane quotidienne passe de 100 à 26 **et** la médiane longitudinale de 71 à 14. Deux stimuli indépendants qui chutent simultanément désignent l'instrument partagé, pas douze modèles qui changeraient de comportement le même matin.
2. **Les réponses restent correctes et stables pendant que le signal les déclare instables.** Exemple intégralement vérifiable — OpenAI, Challenge du 2026-10-05, 4 premières répétitions : les quatre réponses rejettent correctement la fausse prémisse (« la Grande Muraille visible depuis l'espace est un mythe »), sont mutuellement cohérentes, et portent `factual_hallucination_score = 0`. Les quatre sont pourtant `FLAG`, avec `stability_score = 0,153846` et `coherence_score = null`.
3. **Aucun code de ce dépôt n'a changé dans la fenêtre.** L'agrégateur et sa configuration n'ont pas été touchés entre le 2026-09-22 et le 2026-10-08.
4. **La chute suit la disparition des signaux, pas une dégradation de contenu.** `coherence_score` et `semantic_risk` passent de ~30 valeurs nulles par jour (les 30 lignes du chemin `stream_native`) à 267–347 par jour, exactement à partir du 2026-10-03.

### 5.3 Mécanisme : hypothèse, pas fait établi

Les valeurs de `stability_score` sont quantifiées par pas de 1/13 : 0, 2/13 = 0,1538, 4/13 = 0,3077, 12/13 = 0,9231. La même grille avant et après la bascule indique une **même famille de formule** — un compte de contrôles réussis sur 13 — alimentée par des entrées différentes. Le passage du mode 12/13 au mode 2/13, **simultané** à la perte de mesure de `coherence_score` et `semantic_risk`, est cohérent avec l'hypothèse suivante :

> en 3.1.0, les signaux non mesurés seraient comptés comme des contrôles **en échec** au lieu d'être exclus du domaine mesuré, et le seuil amont de FLAG n'aurait pas été recalibré.

**Ceci est une hypothèse et doit être présentée comme telle.** Le cœur de mesure ControlTowerAI n'est pas dans ce dépôt : ni son code, ni ses journaux de déploiement, ni sa note de version 3.1.0 ne sont accessibles ici. Il est **invérifiable depuis ce dépôt** de savoir si la bascule 3.1.0 était intentionnelle et recalibrée, ou s'il s'agit d'une régression. L'épisode des 09-30 / 10-01 ressemble à un pré-déploiement du même changement, avec un retour en arrière le 10-02 — également invérifiable sans les journaux amont.

---

## 6. Ruptures de comparabilité

### 6.1 Ne pas comparer G entre 3.0.0 et 3.1.0

`g_score` médian : 0,6000 jusqu'au 2026-10-02 → 0,1000 à partir du 2026-10-03. `g_final` : 0,9749 → 0,4996. Ces grandeurs sont produites par deux versions différentes du même instrument, sans recalibration documentée. **Toute comparaison directe de G de part et d'autre du 2026-10-03 est sans objet**, et aucun delta franchissant cette date ne doit être publié comme une évolution de comportement.

### 6.2 Périodes homogènes utilisables

| Période | Instrument | Volume | Comparabilité interne |
|---|---|---|---|
| 2026-08-21 → 2026-09-28 | 3.0.0, signaux complets | 23 + 7 | **oui** |
| 2026-09-29 → 2026-10-02 | 3.0.0, canal quotidien dégradé, 10-02 revenu à la normale | 23 + 7 | **non** — régime instable, à traiter comme une transition |
| 2026-10-03 → 2026-10-08 | 3.1.0 | 23 + 7 | **oui, entre ces jours seulement** |
| 2026-10-09 → | 3.1.0 | 3 + 7 | **oui, entre ces jours seulement** — une seule journée à ce stade |

Trois frontières de non-comparabilité : **2026-09-29**, **2026-10-03**, **2026-10-09**.

### 6.3 La baseline longitudinale traverse deux versions de mesure

Les 12 systèmes ont tous leur fenêtre de baseline sur **2026-08-21 → 2026-09-04/05**, donc entièrement sous `measurement_version` 3.0.0 et sous le volume 23 + 7. Les états publiés depuis le 2026-10-03 sont des écarts mesurés en **3.1.0** contre une référence établie en **3.0.0**.

Conséquence directement visible : `attention_critique`, absent jusqu'au 2026-10-03, apparaît le 2026-10-04 (2 systèmes), atteint 7 le 2026-10-05 et 8 à partir du 2026-10-07. Quatre systèmes (ChatGPT, Qwen, Meta, Perplexity) ont une baseline `median = 100, mad = 0` : avec une dispersion de référence nulle, le moindre écart les projette dans les états hauts.

**La comparabilité longitudinale n'est pas établie sur la fenêtre.** Les états `attention_critique` publiés depuis le 2026-10-04 ne doivent pas être lus comme une dérive comportementale observée.

### 6.4 La provenance de mesure n'est pas publiée

`measurement_version` **n'existe comme champ dans aucun artefact publié** — ni `weather.json`, ni `data/current.json`, ni `data/history/<date>.json`, ni les capsules. Il n'apparaît que dans le texte libre de la note de `protocol.volume_profile`. Un consommateur du flux n'a donc **aucun moyen** de distinguer une journée 3.0.0 d'une journée 3.1.0, ni de savoir qu'une fenêtre longitudinale mélange les deux. C'est la cause racine de la rupture de comparabilité silencieuse.

### 6.5 Une mesure dégradée est publiée comme couverture nominale

`Get-ProbeAggregate` (`AI_WEATHER_RUNNER/aggregate_and_publish_weather.ps1:886`) compte comme `fully_scored` toute ligne dont `decision` est non vide et différent de `ERROR`. Une observation dont l'API déclare `measurement_status = "partial"` et `measurement_coverage = 0.6` — deux signaux sur cinq non mesurés — est donc comptée comme pleinement mesurée. Résultat : les 2026-10-05 et 2026-10-07, le flux publie `panel_coverage = 1` et `coverage_status = "nominal"` alors que seules 7 et 12 observations sur 360 ont une couverture de mesure de 1,0.

La couverture publiée mesure **la présence d'une décision**, pas **l'étendue de ce qui a été mesuré**. Les deux sont nécessaires et une seule est publiée.

---

## 7. Séparation Challenge / longitudinal : vérifiée dans le code, les deux sens

| Sens | Verdict | Preuve dans le code |
|---|---|---|
| Le longitudinal influence-t-il la condition météo publiée ? | **Non** | `aggregate_and_publish_weather.ps1:1448` → `condition = $daily.condition` ; l'agrégat longitudinal est construit avec `-WeatherAuthority $false` (`:1410`) et ressort `condition = null` ; `detail.longitudinal_influences_weather = $false` (`:1505`) |
| Le Challenge détermine-t-il la condition longitudinale annoncée ? | **Non** | `longitudinal_engine.ps1:250` → la série par système est construite **exclusivement** depuis `$rec.longitudinal` (`score`, `metrics`, `coverage`, `fully_scored`). `$rec.daily` n'est lu **nulle part** dans le moteur. `longitudinal_v2_bridge.ps1:78-79` le documente et n'enrichit que `systems[].longitudinal` depuis la sortie du moteur |

Cohérent avec le contrat publié : `interpretation_contract.longitudinal_policy = "measured_separately_never_influences_daily_weather_v0.2"`.

**Nuance à connaître, qui n'est pas une fuite entre canaux :** `global_condition` suit la politique `daily_probe_full_panel_required_then_strongest_state_v0.2`, soit l'**état le plus grave du panel**. Le 2026-09-29, le panel affiche `unsettled` avec un `global_score` de 95, parce qu'un seul système sur douze était `unsettled`. Condition globale et score global ne se lisent pas l'un à la place de l'autre.

---

## 8. Limites imposées par N = 3

Avec 3 répétitions du Challenge par système et par jour, la granularité du score est de **33,3 points** : le score par système ne peut valoir que 0, 33, 67 ou 100. Les seuils sont inchangés (`THRESHOLD_CLEAR = 90`, `THRESHOLD_VARIABLE = 65`), donc mécaniquement :

| FLAG sur 3 | Score | Condition |
|---|---|---|
| 0 | 100 | `clear` |
| 1 | 67 | `watch` |
| 2 | 33 | `unsettled` |
| 3 | 0 | `unsettled` |

**Un seul FLAG sur trois fait quitter `clear`.** À N = 23, une observation en FLAG donnait 96 et restait `clear`.

Et sur la couverture : `COVERAGE_MIN_INTERPRETABLE = 0.80` est inchangé, donc perdre **une seule** des 3 observations quotidiennes d'un système donne 2/3 = 0,667 → `insufficient_data` pour ce système, et la précédence fait basculer la condition **globale** du panel en `insufficient_data` / `NOT DETERMINED`. À N = 23, il fallait en perdre 5.

Le flux est honnête sur ce point : `probe_contract.daily.statistical_basis` publie `robustness = "indicative_only"` (`robustness_min_n = 10`, `share_granularity_points = 33.33`).

**Conséquence pour la lecture :** sur le canal quotidien, **aucune conclusion de tendance ne peut être tirée d'une journée isolée** depuis le 2026-10-09. Les parts de régime publiées sont indicatives. Toute lecture sérieuse du canal quotidien demande désormais l'agrégation de plusieurs journées — et cette agrégation ne pourra pas franchir les frontières du §6.2.

---

## 9. Preuves rejouables

Volume effectif par date, dans les données brutes :

    for d in 2026-10-08 2026-10-09; do
      echo -n "$d : "; cat AI_WEATHER_RUNNER/results/$d/*_results.jsonl | wc -l
    done
    # 360 puis 120

Bascule de `measurement_version`, observation par observation :

    for d in 2026-10-02 2026-10-03; do
      echo -n "$d : "
      grep -ho '"measurement_version":"[^"]*"' aiweather-capsule/interoperability/$d/*.json \
        | sort | uniq -c | tr '\n' ' '; echo
    done
    # 3.0.0 puis 3.1.0

Première apparition du motif de gouvernance qui explique la chute :

    grep -l 'Core says STOP' AI_WEATHER_RUNNER/results/*/*_results.jsonl | head -1

Le code de l'agrégateur n'a pas bougé dans la fenêtre :

    git log --date=short --pretty='%h %ad %s' \
      -- AI_WEATHER_RUNNER/aggregate_and_publish_weather.ps1 config/panel.yml AI_WEATHER_RUNNER/config/

Suite de tests du volume :

    powershell -NoProfile -ExecutionPolicy Bypass -File AI_WEATHER_RUNNER/tests/test_protocol_volume.ps1

---

## 10. Corrections de wording livrées

### 10.1 Pages publiques (WordPress, `post_content`)

Quatre pages portaient des valeurs devenues fausses. Aucune autre page, aucune métadonnée SEO (`_awv2_description`) et aucun chapô du site n'en contenait — vérifié sur les 20 pages de l'installation.

| Page | ID | Avant | Après |
|---|---|---|---|
| `/fr/today/` | 19 | « 30 répétitions », « posée 23 fois », « 360 exécutions », « 23 fois par système » | « 10 », « posé 3 fois », « 120 exécutions », « 3 fois par système » |
| `/en/todays-weather/` | 29 | « 30 repetitions », « asked 23 times », « 360 runs », « 23 times per system » | « 10 », « asked 3 times », « 120 runs », « 3 times per system » |
| `/fr/how-it-works/` | 20 | « 30 exécutions quotidiennes : une question sentinelle **principale** répétée 23 fois et une question **complémentaire** fixe répétée 7 fois » | « 10 exécutions quotidiennes : une question de référence fixe, identique dans le temps, répétée 7 fois pour l'observation longitudinale, et le Challenge du jour répété 3 fois en observation complémentaire » |
| `/en/how-ai-weather-works/` | 61 | idem en anglais | idem en anglais |

Le renversement de cadrage est volontaire et faisait partie de l'inexactitude : l'ancien texte présentait la question variable comme **principale** et la question fixe comme **complémentaire**. Le protocole actuel est l'inverse — la question fixe porte l'observation longitudinale, le Challenge est l'observation complémentaire. La distinction est désormais énoncée explicitement sur les deux pages « météo du jour », avec la mention que le Challenge **n'entre pas dans la condition longitudinale**.

Design, URL, structure de blocs Gutenberg, titres et balisage inchangés.

### 10.2 Les dénominateurs dérivent maintenant de la mesure

Pour que le décalage ne puisse pas se reproduire, chaque nombre de répétitions dans ces pages est enveloppé dans `<span data-awv2-vol="…">`, rempli au chargement depuis `weather.json → protocol.volume_profile` par le nouveau module `ai-weather-v2/assets/js/protocol-volume.js` (chargé sur toutes les pages, **aucun appel réseau** si la page ne contient aucune cible).

Clés : `longitudinal`, `daily`, `total`, `systems`, `panel-total`.

La valeur écrite dans le HTML reste le **repli** et doit rester juste : elle est servie aux visiteurs sans JavaScript et à l'indexation. Vérifié sur le flux réel du 2026-10-09 (7 / 3 / 10 / 12 / 120) **et** sur une journée antérieure au changement, où le même module restitue 7 / 23 / 30 / 12 / 360 depuis `protocol.daily_probe_expected`. Le module suit la mesure dans les deux sens.

### 10.3 Widget publié

`weather-longitudinal-fr.html` annonçait « 7 fois par système » et « 7 répétitions » en dur — valeurs justes aujourd'hui, mais figées. Elles sont désormais lues via `repsLongitudinales(data)` depuis `protocol.volume_profile`, avec repli sur `protocol.longitudinal_probe_expected` puis `probe_contract.longitudinal.expected_repetitions_per_system`. Son commentaire d'en-tête mentionnait « 23 répétitions » pour le canal quotidien : corrigé.

### 10.4 Commentaires et documentation

- `ai-weather-v2/assets/js/pages/meteo-du-jour.js` : « 23 répétitions » et « total_observations (360) … 276 + 84 » → valeurs datées du 2026-10-09 (120 = 36 + 84), avec la valeur antérieure conservée et datée.
- `AI_WEATHER_V2_ARCHITECTURE.md` : la ligne « Répétitions | 23 / système / jour » reçoit une **note datée** plutôt qu'une réécriture — elle décrivait correctement le protocole jusqu'au 2026-10-08.
- `controltowerai-wordpress-redesign/{index,how-it-works,for-media}.html` : chantier de refonte non déployé, mentions corrigées pour ne pas repartir d'un texte faux.

### 10.5 Mentions historiques délibérément préservées

Ces documents décrivent **correctement** le protocole à leur date et ne sont pas modifiés : `AI_WEATHER_LONGITUDINAL_AUDIT.md`, `AI_WEATHER_PIPELINE_AUDIT.md`, `AI_WEATHER_V2_PROTOCOL_RESOLUTION_STUDY.md`, `AI_WEATHER_V2_VALIDATION_GATE.md`, `AI_WEATHER_KNOWN_FIXES.md`, l'entrée `effective_from: 2026-08-21` de `protocol_volume.json`, les copies archivées sous `controltowerai-wordpress-redesign/v2-wiring-review/` et `…/wordpress-staging-worktree/`, et l'intégralité de `data/history/` et des capsules.

**Aucune observation historique n'a été effacée, recalculée ni réécrite.**

---

## 11. Corrections scientifiques proposées — NON appliquées

Présentées séparément, conformément à la demande. Chacune touche l'interprétation ou le calcul, et relève d'une décision, pas d'une correction de texte.

**P1 — Publier `measurement_version` dans les artefacts.** Ajouter la provenance de mesure (`measurement_version`, `normalizer_version`, et leur homogénéité sur la journée) dans `protocol` et dans le contrat d'interprétation. **Priorité la plus haute :** sans elle, aucune des autres corrections n'est vérifiable par un consommateur, et la rupture du 2026-10-03 reste invisible dans le flux.

**P2 — Publier la couverture de mesure, distincte de la couverture de décision.** Exposer la distribution de `measurement_status` / `measurement_coverage` de l'API à côté de `fully_scored`, et introduire un `coverage_status` dégradé lorsque la couverture de mesure amont s'effondre. Aujourd'hui une journée à 60 % de signaux mesurés se publie en `nominal`.

**P3 — Marquer les fenêtres longitudinales hétérogènes.** Le moteur doit détecter qu'une fenêtre baseline/courante traverse plusieurs `measurement_version` et le déclarer (`baseline.status = "not_comparable"` ou un drapeau explicite) plutôt que de publier un `deviation_index` et un état. Les états `attention_critique` publiés depuis le 2026-10-04 relèvent de ce cas.

**P4 — Décider du sort de la baseline.** Deux options exclusives, à trancher explicitement : **(a)** geler la baseline 3.0.0 et suspendre la publication des états longitudinaux jusqu'à 14 jours homogènes en 3.1.0 ; **(b)** rouvrir une **nouvelle** baseline à partir du 2026-10-03, en conservant l'ancienne intacte et datée. Dans les deux cas, **aucun recalcul rétroactif de l'historique** — les journées publiées restent ce qu'elles étaient.

**P5 — Revoir les seuils à N = 3, ou ne pas les revoir sciemment.** `THRESHOLD_CLEAR = 90` et `COVERAGE_MIN_INTERPRETABLE = 0.80` ont été calibrés à N = 30. À N = 3 ils produisent les effets de bord du §8 (1 FLAG → sortie de `clear` ; 1 observation perdue → panel `NOT DETERMINED`). Soit les seuils sont adaptés à la granularité, soit la décision de les laisser tels quels est documentée comme un choix.

**P6 — Qualifier la rupture amont auprès de ControlTowerAI.** Obtenir la note de version 3.1.0 et les journaux de déploiement du 2026-09-29 et du 2026-10-03 : la sémantique de `stability_score`, le traitement des signaux non mesurés dans le compte de contrôles, et la calibration du seuil FLAG. L'hypothèse du §5.3 ne peut être confirmée ou écartée que là.

---

## 12. Bilan

**Textes.** Les quatre pages inexactes sont corrigées en FR et en EN, le cadrage principal/complémentaire est remis dans le bon sens, la distinction observation longitudinale / Challenge est explicitée, et les dénominateurs dérivent désormais de la configuration publiée — avec un repli statique juste, donc sans régression SEO ni pour les visiteurs sans JavaScript. Design, URL et structure inchangés.

**Résultats.** **Non comparables sur la fenêtre.** Trois frontières : 2026-09-29 (dégradation des signaux amont, canal quotidien), 2026-10-03 (`measurement_version` 3.0.0 → 3.1.0, les deux canaux), 2026-10-09 (volume 30 → 10). La baisse visible sur plusieurs systèmes à des dates proches **coïncide avec un changement de mesure**, pas avec un changement de comportement des modèles : modèles, prompts, paramètres et code de l'agrégateur sont inchangés sur toute la fenêtre, les deux canaux chutent le même jour malgré des stimuli sans rapport, et les réponses restent correctes et mutuellement cohérentes au moment où le signal les déclare instables. Le mécanisme amont exact reste une hypothèse — le cœur de mesure n'est pas dans ce dépôt.

**Prochaine action prioritaire.** **P1 — publier `measurement_version` dans les artefacts.** C'est la correction qui rend toutes les autres vérifiables, et qui empêche qu'une future bascule d'instrument soit à nouveau lue comme un comportement de modèle.
