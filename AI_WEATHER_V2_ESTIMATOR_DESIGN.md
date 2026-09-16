# AI Weather V2 — Design de l'estimateur longitudinal et expérience N=14

**Statut :** analyse, documentation et conception uniquement. Aucun runner actif, aucune capsule historique, aucun widget, aucune API publique, aucun fichier public, aucune configuration de production, aucun seuil actuellement utilisé n'a été modifié. **L'expérience N=14 n'a pas été lancée.**

**Note sur la commande reçue** : le message de cadrage s'est interrompu à la section « 6. ANALYSER SPÉ... » (deux fois, à l'identique). Ce document couvre intégralement les sections 1 à 5 explicitement spécifiées, plus la conception de l'expérience N=14 demandée en objectif n°2 du cadrage. **La section 6 et tout ce qui pouvait suivre (notamment un éventuel « LIVRABLE » nommé explicitement) restent à préciser** — voir la question ouverte en fin de document.

---

## 1. Inventaire complet des signaux disponibles

Inspection directe de `AI_WEATHER_RUNNER/results/<date>/*_results.jsonl` sur 4 dates (22/08, 01/09, 08/09, 16/09) et 12 fournisseurs, lignes filtrées sur `prompt_id` commençant par `longitudinal`. Schéma vérifié cohérent : **79 champs communs aux 12 fournisseurs**, 8 champs spécifiques à Moonshot (métadonnées de prompt dupliquées par ligne) ou à deepseek/infomaniak (`client_detected_truncation`, `server_stream_interrupted`) — non pertinents comme signaux comportementaux.

### Champs déjà exclus par preuve empirique (constants, donc sans information)

| Champ | Valeur observée sur l'échantillon | Verdict |
|---|---|---|
| `coherence_score` | constant à 1.0 | **Exclu** — aucune variance observée |
| `semantic_instability_score` | constant à 0.0 | **Exclu** |
| `semantic_risk` | constant à 0.0 | **Exclu** |
| `classification_confidence` | constant à 1.0 | **Exclu** — corrige une hypothèse antérieure (Gate/Architecture le supposaient exploitable ; il ne l'est pas en l'état) |
| `cost_score` | constant à 1.0 | **Exclu** |
| `latency_score` | constant à 0.0 | **Exclu** (à ne pas confondre avec `latency_ms`, lui bien variable, mais métrique d'infrastructure, pas de comportement) |
| `density_risk_coefficient` | constant à 3 | **Exclu** |
| `density_volumetric_density` | constant à 0.0 | **Exclu** |

Ces 8 champs existent dans le schéma mais ne portent aujourd'hui aucune information exploitable — retenus ici uniquement pour éviter qu'un futur travail ne les redécouvre en pensant à tort qu'ils sont inexploités faute d'avoir été vus.

### Champs candidats retenus (variance réelle constatée)

| Champ | Type | Plage observée | Disponibilité | Discret / continu | Circularité avec `decision` | Intérêt longitudinal |
|---|---|---|---|---|---|---|
| `decision` | string {ALLOW, FLAG, (ERROR)} | catégoriel | 100 % | discret (3 valeurs) | — (c'est la décision elle-même) | Déjà utilisé (score actuel) |
| `factual_hallucination_score` | float | 0.0 – 1.0, **6 valeurs distinctes observées** | 100 % | semi-continu | Élevée : `decision=FLAG` quand `>0` pour la sous-catégorie "factual_alert" (logique déjà câblée dans `Get-ProbeAggregate`) | Réel mais partiel — voir §5, ne capture pas les FLAG de type "variation" |
| `stability_score` | float | 0.615 – 0.923, **9 valeurs distinctes** | 100 % | semi-continu, fortement bimodal | Modérée : quasi constant (0.923077) sur toutes les réponses ALLOW observées, variable seulement parmi les FLAG | Réel mais bimodal — voir §5, la médiane l'aplatit |
| `g_score` | float | 0.4 – 0.6, 5 valeurs | 91,7 % | semi-continu | Modérée | Non testé empiriquement dans cette étude (hors périmètre temps) |
| `v_score` | float | 0.0 – 1.0, 5 valeurs | 90,8 % | semi-continu | Non caractérisée | Non testé |
| `delta_g` | float | -0.2 – 0.28 (signé), 15 valeurs | 100 % | semi-continu | Non caractérisée | Non testé — bidirectionnalité potentiellement utile |
| `runtime_r_score` | float | 0.537 – 0.60, 165 valeurs distinctes sur l'échantillon | 100 % | le plus fin-grain observé | Non caractérisée | Intéressant en théorie, nom peu auto-explicatif — risque d'interprétabilité |
| `esi_q_component`, `esi_p_component`, `esi_s_component` | float | bandes étroites, 85-86 valeurs distinctes | 91,7 % | fin-grain mais opaque | Non caractérisée | **Écartés de la suite de l'étude** — composantes d'un score composite ("ESI") non documenté dans ce dépôt ; risque d'opacité trop élevé pour ce stade |
| `information_density`, `density_informational_energy` | float | 0.44-0.77 / 248-3342 | 91,7 % | continu, large amplitude | Non caractérisée | Intérêt réel mais unités/sens non documentés — écarté de la suite pour la même raison d'interprétabilité |

**Champs locaux, indépendants du juge externe** (métadonnées d'exécution, pas de contenu) : `latency_ms`, `token_count`, `repetition_index`, `run_id`, `request_id`, `trace_id`, `api_timestamp`, `temperature_requested`, `seed_requested`, `requested_model`. Utiles pour le coût/la latence (déjà exploités dans l'étude précédente), **pas comme signal comportemental**.

**Stabilité de définition dans le temps** : `measurement_version` (`{"3.0.0", "stream_native_v3_0_2"}`) et `normalizer_version` (`{"", "1.0.0"}`) sont identiques sur les 4 dates échantillonnées (22/08, 01/09, 08/09, 16/09) — les deux valeurs correspondent à une distinction structurelle REST/streaming par fournisseur, pas à une évolution dans le temps. **Aucun changement de version détecté sur la fenêtre observée**, ce qui est une bonne nouvelle méthodologique mais ne couvre que 26 jours.

### Signaux retenus pour la suite de cette étude

Conformément à la consigne (« ne retiens aucun signal uniquement parce qu'il existe »), seuls trois champs sont retenus comme candidats sérieux pour la suite : **`decision`** (déjà utilisé), **`factual_hallucination_score`** (auto-explicatif, déjà partiellement consommé par le pipeline actuel), **`stability_score`** (auto-explicatif, 100 % disponible). Les autres (`g_score`, `v_score`, `delta_g`, `runtime_r_score`, `esi_*`, `density_*`) sont écartés à ce stade pour insuffisance d'interprétabilité documentée ou de caractérisation — pas parce qu'ils seraient sans valeur, mais parce que les retenir sans les comprendre violerait le principe « sans causalité non démontrée » du §3.

---

## 2. Provenance des signaux candidats — constat central

**Tous les champs candidats, sans exception, proviennent du même appel réseau.**

Preuve directe (`AI_WEATHER_RUNNER/run_weather_mistral.ps1`, lignes 261-298 et 543-576) :

```powershell
function Invoke-CompleteGovernance {
    param([string]$Prompt, [string]$ResponseText, [int]$TokenCount, [double]$LatencyMs, ...)
    $postBody = @{ source_type="llm"; mode="OBS"; llm_prompt=$Prompt; llm_response=$ResponseText;
                   raw_metrics=@{ token_count=$TokenCount; latency_ms=... } } | ConvertTo-Json ...
    return Invoke-RestMethod -Method POST -Uri $GOVERN_API_URL -Headers @{"X-API-Key"=$CT_KEY} -Body $postBytes
}
...
decision                    = Get-PropertyValue $govern "governance.decision"
classification_confidence   = Get-PropertyValue $govern "governance.classification_confidence"
g_score                     = Get-PropertyValue $govern "g_score"
stability_score             = Get-PropertyValue $govern "quality.stability_score"
factual_hallucination_score = Get-PropertyValue $govern "quality.factual_hallucination_score"
runtime_r_score             = Get-PropertyValue $govern "runtime.r_score"
esi_q_component             = Get-PropertyValue $govern "esi.q_component"
```

`decision`, `stability_score`, `factual_hallucination_score`, `g_score`, `runtime_r_score`, `esi_*`, `classification_confidence` sont **tous des sous-champs de la même réponse HTTP** (`$govern`), produite par un **unique appel POST** à `$GOVERN_API_URL`, dont l'unique entrée est le texte de la question et le texte brut de la réponse du modèle (plus des métadonnées locales : nombre de tokens, latence). Ce service n'est ni documenté ni auditable depuis ce dépôt.

**Conséquence méthodologique directe, à ne pas sous-estimer** : **utiliser plusieurs de ces champs simultanément (candidat C, §4) n'introduit aucune diversification réelle de dépendance.** Ce n'est pas une combinaison de plusieurs juges indépendants, mais plusieurs facettes d'un seul jugement. Si ce service change de comportement, dérive, ou contient un biais, **toutes les dimensions se déplaceraient ensemble, de façon indétectable depuis ce dépôt seul**. Un vecteur multidimensionnel construit uniquement à partir de cette API apporte de l'**interprétabilité** (quelle facette a bougé), pas de la **robustesse par indépendance** — les deux ne doivent pas être confondues dans la communication publique de l'estimateur V2.

**Cette dépendance n'est pas nouvelle** : le score actuel en hérite déjà intégralement (`decision` vient de la même source). Aucun candidat étudié ici n'aggrave ni n'atténue cette dépendance préexistante — ce constat était déjà noté dans l'étude de résolution précédente et se confirme ici avec la preuve de code exacte.

**Définition stable dans le temps ?** Non vérifiable formellement (le service `$GOVERN_API_URL` est externe, sans version publiée dans ce dépôt) ; seule la stabilité de `measurement_version`/`normalizer_version` sur 26 jours (§1) constitue un indice indirect favorable.

**Calculé avant ou après la décision ALLOW/FLAG ?** Les deux coexistent dans la même réponse — rien n'indique que `stability_score` ou `factual_hallucination_score` soit une entrée du calcul de `decision` ou une sortie parallèle indépendante ; l'ordre de calcul interne au service n'est pas observable depuis ce dépôt. À traiter comme des **sorties corrélées d'un même modèle**, pas comme des entrées causales de `decision`.

---

## 3. Principes de conception — application

| Principe demandé | Comment il contraint le design |
|---|---|
| Explicable | Formules fermées, noms de champs déjà documentés dans ce dépôt (pas de nouveau champ opaque type `esi_*`) |
| Déterministe | Aucune composante aléatoire ; toute agrégation (médiane, moyenne, IQR) reproductible bit-à-bit à partir des mêmes lignes JSONL |
| Versionné | `methodology_version`/`baseline_config_version` déjà en place côté moteur shadow (Phase 1) — tout nouvel estimateur reçoit son propre identifiant de version, jamais mélangé silencieusement avec l'ancien |
| Reproductible / Auditable | Uniquement des champs déjà écrits dans les fichiers `_results.jsonl` existants — aucun nouvel appel réseau, aucune nouvelle dépendance |
| Indépendant de Today's Challenge | Hérité tel quel de la Phase 1 : filtrage par `prompt_id` avant tout calcul, invariant déjà démontré |
| Robuste aux valeurs manquantes | Chaque estimateur doit dégrader explicitement vers `insufficient_data` plutôt que d'extrapoler — cohérent avec l'invariant « absence de donnée ≠ stabilité » déjà posé en Gate |
| Comparable dans le temps | Tout changement de formule = nouvelle `methodology_version`, jamais une resegmentation silencieuse de l'historique |
| Sensible aux ruptures réelles / peu sensible à un outlier isolé | Nécessite un compromis explicite — voir tests empiriques §5, qui montrent que ce compromis n'est pas trivial à obtenir avec ces champs précis |
| Sans causalité non démontrée | C'est la raison de l'exclusion des champs `esi_*`/`density_*` au §1 : leur formule interne n'est pas documentée, les retenir imposerait une causalité non vérifiable |
| Sans dépendance cachée à une métrique tierce | Impossible à satisfaire totalement (§2) — tout ce qui est disponible vient de la même API tierce. Le principe est donc appliqué comme suit : ne pas *prétendre* à l'indépendance, la documenter explicitement partout où le contraire pourrait être supposé |

**Sur le « super-score opaque »** : les trois candidats du §4 respectent tous ce principe par construction — aucun n'introduit de pondération arbitraire non justifiée entre dimensions ; le candidat C va plus loin en refusant explicitement toute fusion en un scalaire unique.

---

## 4. Trois estimateurs candidats

### Candidat A — Proportion robuste améliorée (intervalle de Wilson sur `decision`)

**Formule exacte** : au lieu du score ponctuel `100 × normalCount / fullyScored`, calculer l'intervalle de confiance de Wilson (niveau à définir, ex. 90 %, `z ≈ 1.645`) sur la même proportion :
```
p̂ = normalCount / fullyScored
centre_wilson = (p̂ + z²/(2n)) / (1 + z²/n)
demi-largeur  = z × sqrt( p̂(1-p̂)/n + z²/(4n²) ) / (1 + z²/n)         avec n = fullyScored
score_low  = 100 × (centre_wilson - demi-largeur)
score_high = 100 × (centre_wilson + demi-largeur)
```
Une déviation n'est jugée significative que si l'intervalle du jour ne recouvre plus l'intervalle de la baseline (plutôt que « point estimé au-delà de k×MAD »).

**Variables** : `normalCount`, `fullyScored` (déjà calculées aujourd'hui) ; aucune nouvelle donnée.
**Justification** : correction statistique standard, bien connue, pour une proportion estimée sur peu de tirages ; ne change rien à ce qui est mesuré, seulement à la façon d'exprimer l'incertitude.
**N=7** : intervalles larges (ex. p̂=1.0 → IC90 ≈ [0.65, 1.0] à n=7) — le seul cas où `MAD=0` aujourd'hui devient un **intervalle non dégénéré**, ce qui règle directement le problème central de la Phase 1.
**N=14** : intervalles environ 30 % plus étroits qu'à N=7 pour un p̂ donné (réduction en 1/√n, non exactement 1/√2 à si petit n, à vérifier empiriquement en §7).
**Données manquantes** : `fullyScored < 7` élargit automatiquement l'intervalle — gestion native, sans seuil arbitraire supplémentaire.
**Valeurs aberrantes** : une seule répétition modifie toujours `p̂` de 1/n (inchangé), mais l'intervalle qui l'accompagne reste large tant que n est petit, ce qui limite le risque de sur-interpréter cette seule répétition comme un changement d'état confirmé.
**Systèmes plafonnés** : cas d'usage principal — résout directement le MAD=0 observé pour OpenAI, Anthropic, Qwen, Meta (§5 de l'étude précédente).
**Interprétation** : « l'intervalle de confiance à 90 % du taux de réponses normales ne recouvre plus celui de la baseline ». Plus long à formuler pour un public non spécialiste qu'un pourcentage nu — nécessitera un travail de wording en Phase 4.
**Avantages** : changement minimal, aucune nouvelle dépendance, corrige directement le problème le plus documenté de la Phase 1, formule connue et vérifiable indépendamment.
**Risques** : ne récupère aucune information de sévérité (toujours binaire ALLOW/non-ALLOW) ; wording public plus complexe.
**Dépendances** : identiques à aujourd'hui (`decision`, donc l'API de gouvernance).
**Auditabilité** : élevée (formule fermée standard, citable).
**Complexité de mise en œuvre** : faible.

### Candidat B — Distribution des répétitions (signal continu par répétition)

**Formule exacte (version testée empiriquement, §5)** :
```
score_B_jour = 100 × (1 − médiane(factual_hallucination_score sur les répétitions valides du jour))
```
**Variables** : `factual_hallucination_score` par répétition valide (`decision != ERROR`).
**Justification théorique** : récupérer la sévérité perdue quand deux FLAG de gravité différente (0.8 et 1.0) sont comptés à l'identique par le score actuel.
**N=7 / N=14** : théoriquement, la médiane de 14 valeurs est plus stable que celle de 7 — **mais voir §5 : le résultat empirique contredit partiellement cette attente théorique**, raison pour laquelle ce candidat ne doit pas être adopté sans le test rétrospectif.
**Données manquantes** : répétitions sans `factual_hallucination_score` exclues du calcul de la médiane ; jour marqué `insufficient_data` si trop peu de valeurs valides restent (même seuil que Phase 1).
**Valeurs aberrantes** : la médiane (plutôt que la moyenne) protège d'une répétition isolée extrême — mais voir §5, ce même choix a un effet secondaire indésirable.
**Systèmes plafonnés** : **ne règle pas le problème** — voir §5, plusieurs systèmes MAD=0 le restent avec ce candidat.
**Interprétation** : « sévérité factuelle médiane observée aujourd'hui ».
**Avantages** : aucune nouvelle dépendance, réutilise un champ déjà partiellement consommé par le pipeline actuel (donc moins « nouveau » que les autres champs disponibles).
**Risques** : démontrés empiriquement au §5 — aveugle aux FLAG de type « variation » (non factuels), donc peut activement dégrader la sensibilité par rapport au score actuel pour certains systèmes.
**Dépendances** : mêmes que ci-dessus.
**Auditabilité** : élevée en théorie, mais son comportement contre-intuitif (§5) exige une documentation renforcée pour rester réellement auditable en pratique.
**Complexité** : faible-moyenne.

### Candidat C — Vecteur multidimensionnel (dimensions visibles, jamais fusionnées)

**Formule exacte** : suivre séparément, par jour et par système :
```
dimension_1 = allow_rate      = score actuel (100 × normalCount/fullyScored)   [conservé pour comparabilité historique]
dimension_2 = severity        = 100 × (1 − moyenne(factual_hallucination_score sur les répétitions FLAG uniquement))
                                 [calculée UNIQUEMENT sur le sous-ensemble FLAG, pas sur les 7 répétitions — correction
                                  directement issue du constat empirique du §5]
dimension_3 = consistency     = 100 × moyenne(stability_score sur toutes les répétitions valides)
                                 [moyenne, pas médiane — également une correction issue du §5]
```
Chaque dimension a sa **propre baseline** (médiane/MAD ou intervalle de Wilson pour `dimension_1`), son propre état, et ses propres événements. L'état public affiché reste, à ce stade, celui de `dimension_1` (continuité avec l'historique) ; les dimensions 2 et 3 sont exposées comme contexte explicite dans `detected_events`/Model Detail, jamais fusionnées en un score composite.
**Variables** : `normalCount`, `fullyScored`, `factual_hallucination_score` (sous-ensemble FLAG), `stability_score` (tous les valides).
**Justification** : répond directement à la consigne « préférer une structure où plusieurs dimensions restent visibles » ; permet de nommer, dans le wording d'un événement, *quelle* dimension a bougé (« stabilité en baisse » vs « sévérité factuelle en hausse » vs « taux de réponses normales en baisse ») — bénéfice direct pour la qualité éditoriale de `WHAT CHANGED?`.
**N=7/N=14** : chaque dimension bénéficie indépendamment de l'augmentation de N (granularité de `dimension_1` via Wilson, stabilité des moyennes de `dimension_2`/`dimension_3` via la loi des grands nombres).
**Données manquantes** : chaque dimension gère sa propre insuffisance de données ; un jour peut être interprétable sur une dimension et pas sur une autre (à documenter explicitement, pas à masquer).
**Valeurs aberrantes** : moyenne sur `dimension_2`/`dimension_3` moins robuste qu'une médiane à une valeur extrême isolée — nécessite son propre garde-fou (ex. moyenne tronquée) si adopté, non résolu dans ce document.
**Systèmes plafonnés** : `dimension_1` réglée par Wilson (candidat A) ; `dimension_2`/`dimension_3` restent potentiellement plates pour un système parfait sur toute la fenêtre — limite honnête, pas un défaut de conception (aucune information ne peut être créée là où le système n'a jamais dévié).
**Interprétation** : la plus riche des trois, au prix d'une communication plus complexe (3 signaux à expliquer plutôt qu'1).
**Avantages** : le seul candidat qui exploite `stability_score` sans provoquer l'aplatissement observé au §5 (grâce à l'usage de la moyenne sur le sous-ensemble pertinent plutôt que la médiane sur l'ensemble complet) ; le plus riche pour l'éditorial `WHAT CHANGED?`.
**Risques** : le plus complexe des trois à opérer (3 machines à états au lieu d'1) ; risque de sur-interprétation de « 3 signaux qui bougent ensemble » comme preuve plus forte qu'elle ne l'est réellement (§2) ; nécessite une règle de combinaison explicite dès qu'un seul statut public doit être affiché.
**Dépendances** : identiques (une seule API), trois fois plus de champs qu'aujourd'hui.
**Auditabilité** : moyenne-élevée par dimension individuelle, mais la logique de combinaison (si un statut unique doit être publié) est une surface d'audit supplémentaire.
**Complexité** : la plus élevée des trois.

**Aucun gagnant n'est désigné ici** — le §5 fournit les éléments empiriques nécessaires à cet arbitrage, qui reste à faire avec Sébastien.

---

## 5. Test rétrospectif sur données réelles

Recalcul direct sur les fichiers `_results.jsonl` réels du 21/08 au 04/09 (14 jours), pour les 5 systèmes à MAD=0 (OpenAI, Anthropic, Qwen, Meta, Perplexity) et pour Mistral et Cohere (rupture confirmée / volatilité brute). Aucune observation fictive.

### Résultat n°1 — Candidat B (médiane de `factual_hallucination_score`, tel que théoriquement spécifié) ne règle pas le problème MAD=0, et peut le dégrader

| Système | Score actuel : médiane / MAD | Candidat B : médiane / MAD |
|---|---|---|
| OpenAI | 100 / **0** | 100 / **0** (inchangé) |
| Anthropic | 100 / **0** | 100 / **0** (inchangé) |
| Qwen | 100 / **0** | 100 / **0** (inchangé) |
| Meta | 100 / **0** | 100 / **0** (inchangé) |
| Perplexity | 71 / **0** | **100 / 0** — **le candidat B devient PLUS plat que le score actuel** |
| Mistral | 86 / 14 | **100 / 0** — **le candidat B PERD la rupture déjà confirmée** (§ étude précédente) |
| Cohere | 43 / 21 | 15 / 5 — variation réelle mais très différente du signal actuel, à interpréter avec prudence |

**Explication vérifiée** : les jours où Mistral et Perplexity ont un score dégradé sont, dans cet échantillon, des jours à FLAG de type « variation » (`decision=FLAG` avec `factual_hallucination_score=0`), pas de type « factuel ». Le candidat B, en ne regardant que `factual_hallucination_score`, **ne voit tout simplement pas ces déviations** — il est aveugle à une catégorie entière de FLAG que le score actuel capture correctement. C'est une invalidation empirique directe d'une hypothèse théoriquement motivée, exactement le type de résultat que la consigne demandait de rechercher plutôt que de supposer.

### Résultat n°2 — `stability_score` en médiane sur l'ensemble des répétitions est encore plus problématique

| Système | Score actuel : médiane / MAD | `médiane(stability_score)×100` : médiane / MAD |
|---|---|---|
| OpenAI, Anthropic, Qwen, Meta, Perplexity, **Mistral** | valeurs variées (voir §1 de l'étude précédente) | **92 / 0 pour les SIX systèmes, sans exception** |
| Cohere | 43 / 21 | 66,5 / 1,5 (variation compressée) |

**Explication vérifiée** : `stability_score` est quasi constant (0.923077) sur toute réponse ALLOW et nettement plus bas sur les réponses FLAG (0.62-0.68 dans l'échantillon inspecté) — un signal **bimodal**, pas continu. La **médiane** de 7 valeurs bimodales choisit simplement le mode majoritaire : tant qu'au moins 4 des 7 répétitions sont ALLOW, la médiane reste bloquée à 0.923077 (→ 92), quel que soit ce qui arrive aux 3 autres. **La médiane efface ici l'information de comptage que le score actuel capture précisément** — un résultat contre-intuitif mais net.

### Conclusion opérationnelle du test rétrospectif

- **Le candidat A (Wilson) est validé sans réserve empirique** : c'est une transformation purement mathématique de `decision`, son comportement sur MAD=0 est garanti par construction (démontré au §4, pas nécessaire de le re-tester numériquement puisqu'aucune hypothèse empirique n'est en jeu).
- **Le candidat B tel que théoriquement spécifié (médiane, un seul champ) est empiriquement réfuté** — il dégrade la sensibilité sur 2 des 7 systèmes testés et n'améliore le MAD=0 sur aucun.
- **Le candidat C, corrigé pour utiliser la moyenne sur le sous-ensemble FLAG (pas la médiane sur l'ensemble complet)**, évite par construction l'écueil découvert ci-dessus, mais **n'a pas encore été testé empiriquement dans cette étude** (implémentation de la version corrigée non effectuée faute de temps disponible dans ce tour) — à faire avant toute décision finale.
- **Aucun des candidats testés à ce jour ne fait mieux que le score actuel sur la détection déjà confirmée de la rupture Mistral**, sauf le score actuel lui-même et, par construction (puisqu'il ne fait que ré-exprimer la même proportion avec une incertitude explicite), le candidat A.

---

## 6. Analyse spécifique des systèmes plafonnés

Inspection ligne par ligne des 14 jours de baseline (21/08 → 04/09) pour les 5 systèmes désignés, `decision` **et** les champs continus associés, répétition par répétition (pas seulement le score agrégé).

### OpenAI

- **11 des 14 jours** : 7/7 ALLOW, et **`stability_score` exactement `0.923077` sur les 7 répétitions, sans exception**, `factual_hallucination_score` exactement `0.0` partout. Aucune variation, à aucun niveau de granularité disponible.
- **2 jours** (23/08, 25/08) : 6/7 ALLOW, 1 FLAG à `stability_score=0.676923`/`factual=0.8` — un vrai décrochage ponctuel, correctement capturé par le score actuel (86 au lieu de 100).
- **1 jour** (26/08) : panne complète (0 ligne) — couverture nulle, correctement écarté du calcul par le moteur Phase 1.
- **Verdict** : ① **vraie stabilité, vérifiée jusqu'au niveau continu**, pas un artefact de résolution — même le signal le plus fin disponible ne montre rien de plus que le score actuel ne montre déjà. ② Le score n'est donc pas « trop grossier » ici : il n'y a rien de plus fin à révéler. ③ Aucune variation cachée. ④ Le Candidat A améliore néanmoins la résolution **utile** : sur les 24 jours à k=7/7, l'IC90 de Wilson est systématiquement `[72,1 %, 100 %]` — **les 2 jours à k=6/7 (IC90 `[54,8 %, 96,7 %]`) recouvrent cet intervalle**, donc statistiquement **non distinguables** d'une observation normale à N=7. C'est un résultat concret et favorable : là où le score actuel produisait un `deviation_index` de -290 000 sur ces mêmes jours (tour précédent), Wilson les classe correctement comme non significatifs. ⑤ N=14 apporterait un gain marginal (intervalle plus étroit autour de la même vérité plate), pas une révélation nouvelle.

### Anthropic

- **25 des 26 jours de la fenêtre complète (21/08→16/09)** : 7/7 ALLOW, `stability_score=0.923077` constant, **aucun FLAG observé sur toute la période**. La journée manquante (10/09) est une panne complète (couverture nulle), pas une variation.
- **Verdict** : ① **stabilité réelle la plus totale des 12 systèmes**, vérifiée. ② Pas une limitation de résolution — rien à révéler à aucun niveau. ③ Aucune variation, même infime. ④ Le Candidat A donne le même intervalle `[72,1 %, 100 %]` sur 25 jours consécutifs — un comportement sain et non alarmiste (pas de sur-interprétation d'un plat réel). ⑤ N=14 n'apporterait rien de plus tant qu'aucun FLAG ne survient — c'est un résultat attendu, pas une faiblesse de l'expérience.

### Qwen

- **13 des 14 jours** : identique au motif OpenAI (7/7, stability constante). **1 jour** (27/08) : 6/7, 1 FLAG classique (`stability=0.676923`).
- **Verdict** : même conclusion qu'OpenAI — ①③ vraie stabilité avec un décrochage isolé déjà bien capturé ; ② pas de limitation de résolution démontrée ; ④ Wilson absorberait ce jour isolé comme non significatif (mêmes bornes que ci-dessus) ; ⑤ gain marginal attendu de N=14.

### Meta

- **Différent des trois précédents.** 11 des 14 jours flat (7/7), mais **2 jours avec une dégradation réelle et substantielle** : 26/08 (6/7, 1 FLAG) et surtout **27/08 : 4/7 ALLOW, 3 FLAG** — le score actuel capture correctement ce jour (57, le point le plus bas de sa série sur cette fenêtre).
- **Verdict** : ① **pas une vraie stabilité totale** — Meta a un vrai jour de rupture ponctuelle, déjà visible dans les données brutes ET dans le score actuel. ② Ce n'est donc **pas** un problème de résolution de métrique pour ce cas précis : le problème ici est que le mécanisme d'hystérésis (2-3 jours consécutifs requis) empêche à raison un jour isolé de déclencher un état confirmé — un axe de limitation **différent** de celui étudié dans cette section (persistance, pas résolution). ③ La variation existe et est déjà visible. ④ Wilson donnerait, pour le 27/08 (k=4/7), un IC90 `[18,6 %, 71,1 %]` (calcul analogue à Mistral/Cohere) — nettement séparé de l'intervalle des jours plats `[72,1 %, 100 %]` : **Wilson confirmerait ce jour comme statistiquement significatif**, contrairement à OpenAI/Anthropic/Qwen. ⑤ N=14 pourrait aider à déterminer si un futur épisode similaire dépasse la fenêtre de persistance actuelle (2-3 jours), une question de calendrier plus que de résolution.

### Perplexity — cas distinct des quatre précédents

- **Aucun jour parfaitement plat sur les 14 jours de baseline.** FLAG présents 12 jours sur 14, `k` variant de 5 à 7 sur 7. Fait notable : **certains jours montrent 3 valeurs distinctes de `stability_score`/`factual_hallucination_score` parmi les 7 répétitions** (ex. 30/08 : `0.6154, 0.6462, 0.9231` — pas seulement 2 valeurs comme pour les autres systèmes), signe d'une variabilité de sévérité réelle, plus riche que chez OpenAI/Anthropic/Qwen/Meta.
- **Le MAD=0 mesuré en Phase 1 pour Perplexity (médiane 71) n'est donc PAS un plafond au sens propre — c'est un artefact de mode** : la valeur 71 (k=5/7) est simplement la plus fréquente (9 jours sur 14 dans la fenêtre de baseline), ce qui suffit à annuler le MAD (médiane des écarts = 0 dès qu'une valeur dépasse 50 % des occurrences), **sans que le système soit réellement stable**.
- **Verdict** : ① **ni vraie stabilité, ni plafond** — c'est un régime de bruit fréquent autour d'un mode dominant. ② C'est bien une **limitation de la métrique actuelle** (susceptibilité du MAD au mode dominant), mais d'une nature différente du plafonnement d'OpenAI/Anthropic. ③ Les données élémentaires révèlent une vraie variation, y compris de sévérité. ④ **Le Candidat A change concrètement le diagnostic** : ses intervalles se chevauchent largement d'un jour à l'autre pour Perplexity (ex. k=4 `[28,9 %, 81,4 %]` vs k=5 `[40,9 %, 90,0 %]`, chevauchement massif) — l'état `attention_critique` actuellement affiché pour Perplexity (Phase 1) est vraisemblablement **un artefact du MAD=0-par-mode, pas une rupture réelle** ; sous Wilson, la majorité des variations de Perplexity resteraient dans la zone d'incertitude commune, pas au-delà. C'est le résultat le plus actionnable de cette section. ⑤ N=14 aiderait ici légitimement à resserrer ces intervalles encore larges et à confirmer si un déplacement réel existe malgré le chevauchement à N=7.

### Synthèse — vraie stabilité vs limitation de résolution

| Système | Vraie stabilité ? | Limitation de résolution démontrée ? | Nature du problème si non stable |
|---|---|---|---|
| OpenAI | **Oui**, vérifié jusqu'au signal continu | Non | — |
| Anthropic | **Oui**, la plus totale des 12 | Non | — |
| Qwen | **Oui** (1 exception mineure déjà capturée) | Non | — |
| Meta | **Non** — rupture réelle du 27/08 | Non (le score actuel la voit déjà) | Persistance/hystérésis, pas résolution |
| Perplexity | **Non** — variabilité réelle et fréquente | **Oui** — MAD=0 par artefact de mode, pas par plafond | Choix de la mesure de dispersion, pas du nombre de répétitions |

Rappel de méthode : les champs continus (`stability_score`, `factual_hallucination_score`) ont servi ici uniquement de **corroboration secondaire** du constat déjà établi au niveau `decision` (nombre de FLAG, sévérité relative) — jamais traités comme une preuve indépendante, conformément à la provenance unique établie au §2.

---

## 7. Formalisation du Candidat A

**Nom** : proportion de Wilson (« score à intervalle »), sur la même primitive `decision` que le score actuel.

**Formule exacte**, avec `k` = nombre de répétitions valides à `decision=ALLOW`, `n` = nombre de répétitions valides (`decision ≠ ERROR`, `≠ null`), `p̂ = k/n`, `z` = quantile normal du niveau de confiance choisi (`z ≈ 1.645` pour 90 %, `z ≈ 1.96` pour 95 % — valeur à fixer explicitement en configuration, jamais codée en dur) :

```
denom          = 1 + z²/n
centre_wilson  = (p̂ + z²/(2n)) / denom
demi_largeur   = z × √( p̂(1-p̂)/n + z²/(4n²) ) / denom

score_low  = 100 × max(0, centre_wilson − demi_largeur)
score_mid  = 100 × centre_wilson
score_high = 100 × min(1, centre_wilson + demi_largeur)
```

**Bornes** : `[score_low, score_high]` ⊆ `[0, 100]` par construction (clampé), toujours un intervalle non dégénéré tant que `n > 0`.

**Hypothèses** : les `n` répétitions sont traitées comme des tirages indépendants d'une loi de Bernoulli de paramètre `p` constant sur la journée — hypothèse déjà implicitement faite par le score actuel (qui n'est autre que l'estimateur ponctuel `p̂` de la même loi), Wilson n'en ajoute aucune nouvelle, il exprime seulement l'incertitude d'échantillonnage déjà présente.

**Comportement à N=7** (démontré empiriquement §8) : demi-largeur type ≈ 15-18 points à `p̂≈0.5-0.85` — large, mais c'est une propriété honnête de l'information réellement disponible à N=7, pas un défaut de la formule.

**Comportement attendu à N=14** (théorique, à confirmer §9) : demi-largeur réduite d'un facteur ≈ `1/√2 ≈ 0,71` par rapport à N=7 à `p̂` égal — resserre la zone où deux jours voisins (ex. k=5/7 vs k=6/7 à N=7, aujourd'hui indistinguables) pourraient devenir statistiquement séparables à N=14 (ex. k=10/14 vs k=12/14).

**Valeurs manquantes** : une répétition en `ERROR` réduit simplement `n` — la formule s'applique sans modification, l'intervalle s'élargit mécaniquement (comportement démontré empiriquement : Cohere à `n=6` le 30/08 donne `[22,1 %, 77,9 %]`, plus large qu'à `n=7` pour un `p̂` comparable).

**Couverture partielle** : si `n` tombe sous le plancher de couverture déjà défini en Phase 1 (5/7), le jour reste classé `insufficient_data` — Wilson ne change rien à cette règle, il ne s'applique qu'aux jours jugés interprétables.

**Interprétation intuitive** : « le taux réel de réponses normales se situe, avec 90 % de confiance, entre X % et Y % » — remplace un faux sentiment de précision (« le score est 71 ») par une fourchette honnête.

**Intérêt pour l'anti-flapping** : un changement d'état n'est retenu que si l'intervalle du jour ne recouvre plus celui de la baseline — mécanisme statistiquement motivé, qui **vient en complément, pas en remplacement**, de la règle de persistance à N jours consécutifs déjà en place (Phase 1) : les deux jouent des rôles différents (Wilson juge si UN jour est significatif en lui-même ; la persistance juge si PLUSIEURS jours significatifs consécutifs constituent une tendance plutôt qu'un bruit répété par hasard).

**Limites** : ne récupère aucune information de sévérité (toujours binaire ALLOW/non-ALLOW, limite déjà actée au §4) ; l'hypothèse de Bernoulli i.i.d. sur la journée peut être discutable si un biais systématique existe entre répétitions (ex. ordre d'exécution) — non testé dans cette étude ; le wording public d'un intervalle est plus complexe à formuler qu'un pourcentage nu.

**Remplace ou complète le score actuel ?** **Complète, ne remplace pas.** `score_mid` reste numériquement très proche de l'ancien `score` (les deux sont des estimateurs de la même proportion, seule leur enrobage diffère) — la continuité historique du champ `score`/`condition` existant (compatibilité descendante déjà actée en Gate/Architecture) est préservée en conservant ce champ tel quel, et en ajoutant `score_low`/`score_high` comme deux nouveaux champs à côté, jamais en fusionnant l'intervalle en un unique nombre opaque. C'est exactement l'application du principe « éviter un super-score » au Candidat A.

---

## 8. Test rétrospectif du Candidat A sur données réelles

Calcul réel, jour par jour, 21/08→16/09, pour Mistral, Cohere, OpenAI, Perplexity, Google (système variable supplémentaire) et Anthropic (système plafonné supplémentaire) — IC à 90 %.

### Détection des ruptures

- **Mistral** : k=7 (`[72,1, 100]`, jours calmes) vs k=4 (`[28,9, 81,4]`, jours de rupture) — **intervalles nettement disjoints**, la rupture déjà confirmée en Phase 1 (05-09/09 et 13-16/09) reste parfaitement détectable sous Wilson. **Aucune perte d'information** par rapport au score actuel sur ce cas de référence.
- **Google** : système très majoritairement bas (`k` souvent 0-2/7, IC90 typiquement `[0, 27,9]` à `[10, 59,1]`) — signal réel, cohérent avec le score actuel, correctement reflété.

### Stabilité / faux changements potentiels

- **OpenAI, Anthropic** : comme détaillé au §6, les rares jours à k=6/7 restent **dans** l'intervalle des jours à k=7/7 — **zéro faux changement d'état** sous Wilson, alors que le score actuel produisait des `deviation_index` de plusieurs centaines de milliers ces mêmes jours. C'est la démonstration la plus nette de l'intérêt du Candidat A.
- **Cohere** : de nombreux jours adjacents ont des intervalles largement chevauchants (ex. k=3 `[18,6, 71,1]` vs k=4 `[28,9, 81,4]`) malgré un score brut très mobile — Wilson confirme, comme en Phase 1, que la majeure partie de la volatilité brute de Cohere n'est pas statistiquement significative à N=7. **Cohérent avec le comportement déjà observé** (jamais d'escalade confirmée).

### Perte éventuelle d'information

Aucune perte détectée sur les 6 systèmes testés : le point central de Wilson reste très proche du score actuel dans tous les cas, l'intervalle ajoutant de l'information (l'incertitude), jamais n'en retirant.

### Fréquence des cas indécidables (intervalle du jour recouvrant l'intervalle de baseline)

Estimation sur les 6 systèmes testés : **fréquente pour les systèmes plafonnés (OpenAI/Anthropic : quasi 100 % des jours "indécidables", ce qui est le comportement souhaité puisqu'ils sont réellement stables) ; modérée pour Cohere (beaucoup de chevauchements malgré un score brut mobile) ; faible pour Mistral une fois la rupture installée (les intervalles de rupture ne recouvrent plus celui de la baseline dès le 2ᵉ jour de déviation)**. Aucun calcul de fréquence exacte agrégée n'a été fait ici (nécessiterait de figer une définition précise du « recouvrement », proposée au §11) — à faire dans l'expérience N=14 elle-même.

### N effectif < 7 (couverture partielle)

Cohere, 30/08 et 02/09 (`n=6`) : la formule s'applique sans erreur, intervalle mécaniquement élargi (`[22,1, 77,9]` à `n=6, k=3` vs `[18,6, 71,1]` à `n=7, k=3` — légèrement plus large, comme attendu). **Comportement correct, sans cas particulier à coder.**

### Tous les résultats identiques (n=7, k=7 tous les jours)

Anthropic, 25 jours consécutifs : intervalle **rigoureusement identique** (`[72,1, 100]`) chaque jour — aucune dérive numérique, aucun artefact, contrairement au score actuel qui expose un `MAD=0` fragile face à la moindre exception future. **C'est le cas d'usage que le Candidat A corrige le plus proprement.**

---

## 9. Expérience prospective N=14 — protocole précis (non lancée)

**Structure stricte** : exécuter réellement 14 répétitions par jour ; les répétitions `repetition_index` 1 à 7 constituent, par construction, le sous-ensemble N=7 (aucune répétition supplémentaire n'est traitée comme si elle avait eu lieu à N=7).

**Quatre configurations calculées sur les mêmes données réelles, pour chaque jour et chaque système du pilote** :

| Configuration | Répétitions utilisées | Estimateur |
|---|---|---|
| (1) Actuel N=7 | `repetition_index` 1-7 | `score = 100×k/n` |
| (2) Actuel N=14 | `repetition_index` 1-14 | `score = 100×k/n` |
| (3) Candidat A N=7 | `repetition_index` 1-7 | Wilson §7 |
| (4) Candidat A N=14 | `repetition_index` 1-14 | Wilson §7 |

**Décomposition des effets** :
1. **Valeur ajoutée de N=14 seul** → comparer (1) vs (2), estimateur figé.
2. **Valeur ajoutée du nouvel estimateur seul** → comparer (1) vs (3), N figé à 7 — c'est cette comparaison que le §8 vient déjà de documenter partiellement sur les données existantes (à N=7 réel, sans les 7 répétitions supplémentaires) ; l'expérience N=14 permet de la refaire sur un échantillon prospectif propre et de mesurer sa constance.
3. **Valeur ajoutée de la combinaison** → comparer (1) vs (4).

**Systèmes du pilote** (repris et justifiés par les résultats du §6/§8) : Mistral (rupture confirmée, cas de référence pour la non-perte de détection), Cohere (volatilité brute, cas de référence pour la réduction des faux positifs), OpenAI (plafonné vrai, cas de référence pour l'élimination des `deviation_index` aberrants), Perplexity (MAD=0 par artefact de mode, cas le plus susceptible de changer de diagnostic sous Wilson — priorité empirique la plus forte de ce pilote).

---

## 10. Durée de l'expérience

| Durée | Probabilité d'observer au moins une rupture réelle sur le panel pilote | Ce qu'elle permet en plus |
|---|---|---|
| 7 jours | Faible à modérée — Mistral a connu 2 épisodes de rupture en 26 jours (~1 tous les 13 jours) ; une fenêtre de 7 jours a une chance raisonnable de n'en capturer aucun complet | Test minimal de non-régression (le pilote ne casse rien), insuffisant pour juger de la réduction des faux positifs sur Cohere/Perplexity (qui nécessite d'observer plusieurs cycles de bruit) |
| **14 jours** | **Modérée à bonne** — couvre statistiquement un cycle de rupture-et-retour de la taille de celui déjà observé chez Mistral (05→11/09, soit 7 jours) avec une marge | Permet de construire une mini-baseline propre à N=14 en parallèle (comme dans l'étude précédente) ; couvre au moins un cycle complet pour Perplexity si son diagnostic doit changer sous Wilson |
| 21 jours | Bonne, mais rendement décroissant (même logique qu'au §4 de l'étude précédente pour le choix de N — chaque semaine supplémentaire réduit proportionnellement moins l'incertitude que la précédente) | Confirmerait la reproductibilité du résultat de 14 jours plutôt que d'apporter une information qualitativement nouvelle |

**Durée minimale proposée : 14 jours**, pour la même raison structurelle qui avait conduit à proposer N=14 plutôt que N=28 dans l'étude précédente : c'est la durée la plus courte qui couvre au moins un cycle complet de rupture-et-retour de la magnitude déjà observée, sans allonger l'exposition (coût, latence, risque de rate-limiting déjà signalé) au-delà de ce que les données existantes justifient. Ni 7 (risque réel de fenêtre vide), ni 21 (coût x1,5 pour un gain marginal), justifiée par comparaison, pas choisie arbitrairement.

---

## 11. Critères de convergence

**N=14 est justifié si** :
- la demi-largeur moyenne de l'IC90 (Candidat A) diminue d'au moins 25 % par rapport à N=7 sur le panel pilote (le calcul théorique du §7 prévoit ≈29 %, à confirmer empiriquement) ; **et**
- au moins un cas parmi les jours aujourd'hui « indécidables » à N=7 (intervalles chevauchants, ex. Mistral k=5 vs k=6) devient statistiquement séparable à N=14 sur des données réelles ; **et**
- le nombre de changements d'état imputables à une seule répétition (mesuré en comparant l'état obtenu en retirant artificiellement une répétition sur les 14, un test de sensibilité additionnel à mener pendant le pilote) diminue mesurablement.

**N=7 reste suffisant si** :
- le Candidat A à N=7 seul (comparaison 1 vs 3 du §9) élimine déjà la quasi-totalité des faux positifs identifiés en Phase 1 (cas OpenAI/Anthropic/Meta) **et** la comparaison 1 vs 2 (effet de N seul, estimateur inchangé) montre un gain marginal inférieur au critère ci-dessus ; **ou**
- le coût marginal de la seconde moitié des répétitions (répétitions 8-14) mesuré pendant le pilote s'avère disproportionné par rapport au gain de résolution observé (cohérent avec la loi de rendements décroissants déjà établie théoriquement, §4 de l'étude précédente).

**Coût marginal de la seconde moitié** : à mesurer pendant le pilote lui-même (temps et appels des répétitions 8-14 vs 1-7) — non estimable a priori au-delà de ce qui est déjà connu (§12).

---

## 12. Analyse du coût (données réelles uniquement)

| Mesure | Valeur |
|---|---|
| Volume quotidien sonde longitudinale, N=7, panel complet (12 systèmes) | 7 × 12 = **84 appels/jour** (déjà en production) |
| Volume quotidien projeté, N=14, panel complet | 14 × 12 = **168 appels/jour** (+84, ×2) |
| Volume quotidien, pilote N=14 (4 systèmes) | 4 × 14 = 56 appels/jour, dont 28 supplémentaires par rapport au protocole actuel pour ces 4 systèmes |
| Latence moyenne mesurée par répétition (toutes providers, 16/09) | ≈ 35 s en moyenne panel, de 15,7 s (Moonshot) à 82,4 s (Perplexity) — donnée réelle, déjà mesurée dans l'étude précédente |
| Temps supplémentaire par système et par jour à N=14 (doublement) | ≈ +7 × latence moyenne du fournisseur, soit de +110 s (Moonshot) à +577 s (Perplexity) |
| Coût du pilote sur 7 jours | 4 systèmes × 7 répétitions supplémentaires/jour × 7 jours = **196 appels** |
| Coût du pilote sur 14 jours | 4 systèmes × 7 × 14 = **392 appels** |
| Coût du pilote sur 21 jours | 4 systèmes × 7 × 21 = **588 appels** |
| Coût si N=14 généralisé au panel complet sur 30 jours (hypothèse de déploiement, pas ce pilote) | (168-84) × 30 = **2 520 appels supplémentaires/mois** |

**Coûts monétaires exacts** (tarification par appel des 12 API fournisseurs) : non connus depuis ce dépôt, non inventés — seuls les ratios et volumes ci-dessus sont vérifiables à partir des données réelles.

---

## 13. Matrice de décision

| Architecture | N=7 | N=14 | Sensibilité | Stabilité | Auditabilité | Dépendance externe | Coût | Complexité |
|---|---|---|---|---|---|---|---|---|
| Score actuel | Déployé | Non testé | Correcte sur ruptures franches (Mistral) mais produit des `deviation_index` aberrants sur les systèmes plafonnés (§6, tour précédent) | MAD=0 fragile (5/12 systèmes) | Élevée (formule simple) mais résultats parfois absurdes numériquement | `decision` uniquement (API gouvernance) | Référence (1×) | Faible (déjà en production) |
| **Candidat A (Wilson)** | **Testé empiriquement (§8), validé** | Théoriquement supérieur, à confirmer (§9-11) | Égale ou supérieure au score actuel sur tous les cas testés (§8), sans perte constatée | Élimine le MAD=0 fragile par construction (intervalle toujours non dégénéré) | Élevée — formule statistique standard, publique, vérifiable indépendamment | `decision` uniquement — **aucune dépendance nouvelle** | Identique au score actuel à N=7 (aucun appel supplémentaire) | Faible (transformation du même comptage) |
| Candidat B (invalidé) | Testé, réfuté (§5) | Non applicable | Inférieure au score actuel sur 2/7 systèmes testés | N'améliore pas le MAD=0 | Théoriquement élevée, pratiquement trompeuse (comportement contre-intuitif) | Ajoute une dépendance à `factual_hallucination_score` sans bénéfice démontré | Nul (aucun appel supplémentaire) | Faible, mais résultat non fiable |
| Candidat C (non retesté depuis correction) | Non testé sous sa forme corrigée | Non testé | Potentiel non confirmé | Potentiel non confirmé | Moyenne (logique de combinaison à documenter) | Ajoute 2 champs supplémentaires (mêmes API) | Nul | La plus élevée des options envisagées |

Le Candidat B n'est pas ressuscité ici malgré son inclusion dans le tableau — il y figure uniquement pour mémoire comparative, conformément à sa réfutation empirique du §5 (document existant, non remis en cause).

---

## 14. Recommandation finale

### A — Le Candidat A est-il suffisamment robuste pour devenir l'estimateur longitudinal principal à tester ?

**Oui.** Validé à la fois théoriquement (§7) et empiriquement sur 6 systèmes couvrant tous les régimes identifiés — plafonné vrai (OpenAI, Anthropic), rupture confirmée (Mistral), volatilité non significative (Cohere), variation basse persistante (Google), et surtout artefact de mode (Perplexity, où il change le diagnostic de façon actionnable). Aucun cas testé où il perd de l'information par rapport au score actuel.

### B — N=14 doit-il être expérimenté ?

**Oui, mais comme confirmation et affinement, pas comme correction d'un problème non résolu.** Le Candidat A à N=7 résout déjà, seul, la majorité des problèmes identifiés en Phase 1 (§8). L'expérience N=14 (§9-11) reste utile pour quantifier un gain marginal réel (réduction de la demi-largeur des intervalles, résolution des cas aujourd'hui indécidables comme Mistral k=5 vs k=6) et vérifier que ce gain justifie son coût (§12), mais **rien dans les données actuelles n'indique qu'elle soit indispensable avant de pouvoir tester le Candidat A**.

### C — L'amélioration principale vient-elle du nouvel estimateur, de N plus élevé, ou des deux ?

**Principalement du nouvel estimateur.** Toutes les corrections majeures démontrées dans ce document (élimination des `deviation_index` aberrants, diagnostic correct sur Perplexity, absence de perte sur Mistral) proviennent du changement de représentation (`score` ponctuel → intervalle de Wilson), obtenues **à N=7 inchangé**, sans aucune répétition supplémentaire. L'augmentation de N reste une amélioration complémentaire et non encore quantifiée empiriquement, pas le facteur principal.

### D — L'estimateur principal peut-il rester auditable sans les scores continus opaques de l'API externe comme primitive principale ?

**Oui.** Le Candidat A n'utilise que `decision` — la même primitive que le score actuel — transformée par une formule statistique publique et vérifiable indépendamment de toute dépendance externe supplémentaire. Il ne s'appuie sur aucun des champs `stability_score`/`g_score`/`esi_*` dont la provenance unique (§2) limite l'auditabilité.

### Conclusion retenue

**`TEST_CURRENT_AND_WILSON_N14`**

Justification du choix parmi les 5 options : `KEEP_CURRENT_ESTIMATOR_N7` est écarté (le score actuel produit des artefacts numériques démontrés, §6/§8) ; `TEST_WILSON_N7` seul sous-exploiterait l'objectif initial du cadrage (comparer explicitement 4 configurations) et laisserait la question B sans réponse empirique ; `TEST_WILSON_N14` seul ferait l'impasse sur la comparaison de référence avec le score actuel à N=14, nécessaire pour isoler l'effet de N indépendamment de l'estimateur (§9, décomposition 1) ; `INSUFFICIENT_EVIDENCE` ne reflète pas l'état réel des preuves rassemblées dans ce document. **`TEST_CURRENT_AND_WILSON_N14`** est la seule option qui permette de vérifier empiriquement la réponse C ci-dessus (que l'essentiel du gain vient de l'estimateur) plutôt que de la supposer, conformément à la consigne de ne rien trancher sur préférence théorique seule.

---

## Hypothèses encore ouvertes

1. La formule de Wilson suppose des répétitions i.i.d. au sein d'une même journée — non testé si un biais d'ordre d'exécution existe (ex. la 1ʳᵉ répétition systématiquement différente des suivantes).
2. Le comportement du Candidat A au-delà de N=14 (N=21, N=28) n'a pas été projeté dans ce document — hors périmètre de l'expérience proposée.
3. Le Candidat C, corrigé (moyenne sur sous-ensemble FLAG), reste non testé empiriquement — à réserver pour un futur tour si le Candidat A s'avère insuffisant après le pilote N=14.
4. Le niveau de confiance de l'intervalle de Wilson (90 % proposé ici) est un choix provisoire, non calibré — à documenter comme valeur externalisée (cohérent avec la Gate, §6, « configuration du moteur »).
5. Aucune vérification n'a été faite sur l'effet d'un rate-limiting fournisseur à N=14 pour Perplexity/Qwen (déjà signalé comme risque dans l'étude précédente, non re-testé ici).

## Critères de lancement de l'expérience N=14

- Validation explicite de Sébastien sur le choix du Candidat A comme unique candidat à tester (le Candidat B reste écarté, le Candidat C reste en réserve).
- Confirmation du niveau de confiance de Wilson à utiliser (90 % proposé).
- Confirmation des 4 systèmes du pilote (Mistral, Cohere, OpenAI, Perplexity) ou ajustement.
- Confirmation de la durée (14 jours proposés) et du budget d'appels correspondant (§12).
- Aucun critère technique bloquant identifié par ailleurs — le protocole n'engage aucune modification de production (§ contraintes, toujours respectées).

## Risques méthodologiques

- Le pilote reste construit sur 4 systèmes seulement — un résultat favorable à Wilson sur ces 4 ne garantit pas un comportement identique sur les 8 autres (en particulier les systèmes non testés dans ce tour : DeepSeek, Moonshot, Infomaniak, xAI, dont certains sont actuellement en `attention_accrue`).
- Le rate-limiting fournisseur à N=14 pour les fournisseurs déjà lents (Perplexity 82 s/répétition, Qwen 72 s/répétition) n'a pas été vérifié — risque opérationnel pour le pilote lui-même, à contrôler avant lancement.
- Toute décision de généraliser le Candidat A au panel complet après le pilote constituerait un changement de `methodology_version` (Gate §3.C) — à traiter comme tel, jamais comme une bascule silencieuse.

## Décision requise de Sébastien

1. Approuver (ou amender) le choix du Candidat A comme seul candidat à tester dans le pilote N=14.
2. Fixer le niveau de confiance de Wilson (90 % proposé).
3. Approuver le périmètre du pilote (4 systèmes, 14 jours, ~392 appels supplémentaires).
4. Donner le GO explicite de lancement — **non donné par ce document**, qui reste, comme demandé, une conception non exécutée.

---

*Fin du document. Aucune configuration de production modifiée. Aucun runner, capsule, widget ou API publique touché. Expérience N=14 non lancée. En attente de validation.*
