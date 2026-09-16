# AI Weather V2 — Étude de résolution du protocole longitudinal

**Statut :** analyse uniquement. Aucun runner actif, aucune capsule historique, aucun widget, aucune API publique et aucune configuration actuellement utilisée n'a été modifiée. Aucune expérience prospective n'a été lancée. Toutes les données citées sont réelles (rejeu du moteur shadow du 2026-09-16, fenêtre 21/08→16/09, et lecture directe des fichiers `AI_WEATHER_RUNNER/results/*/*.jsonl`), sauf mention explicite « simulation » ou « estimation théorique ».

---

## 1. Variations historiques réellement observées

### Synthèse quantitative par système (26 jours, 21/08 → 16/09)

| Système | Jours valides | Couverture | Valeurs distinctes (/8 max) | Jours identiques au précédent | Jours changés | Écart moyen \|Δ\| | Écart max \|Δ\| | MAD baseline | Médiane | État final (seuils provisoires) |
|---|---|---|---|---|---|---|---|---|---|---|
| OpenAI | 25/26 | 0.962 | 3 | 21 | 3 | 5.3 | 100 | **0** | 100 | standard |
| Anthropic | 25/26 | 0.962 | 2 | 23 | 1 | 2.4 | 57 | **0** | 100 | standard |
| Google | 24/26 | 0.923 | 4 | 6 | 17 | 13.1 | 43 | 14 | 14 | standard |
| xAI | 26/26 | 1.000 | 6 | 5 | 20 | 20.0 | 43 | 14.5 | 71 | standard |
| Mistral | 26/26 | 1.000 | 5 | 9 | 16 | 13.8 | 57 | 14 | 86 | **attention_accrue** |
| DeepSeek | 25/26 | 0.962 | 6 | 6 | 18 | 19.7 | 71 | 7 | 93 | **attention_accrue** |
| Qwen | 26/26 | 1.000 | 3 | 20 | 5 | 4.5 | 57 | **0** | 100 | standard |
| Moonshot | 26/26 | 1.000 | 4 | 9 | 16 | 13.2 | 43 | 7 | 93 | **attention_accrue** |
| Cohere | 25/26 | 0.962 | **8** | 2 | 22 | 28.8 | 83 | 28 | 43 | standard |
| Meta | 25/26 | 0.962 | 4 | 20 | 4 | 4.8 | 43 | **0** | 100 | standard |
| Infomaniak | 26/26 | 1.000 | 6 | 9 | 16 | 14.4 | 43 | 14 | 29 | **attention_accrue** |
| Perplexity | 25/26 | 0.962 | 4 | 12 | 12 | 9.6 | 29 | **0** | 71 | **attention_critique** |

**MAD = 0 pour 5 systèmes sur 12 (41,7 %)** : OpenAI, Anthropic, Qwen, Meta, Perplexity. **MAD > 0 pour 7 systèmes**, de 7 (DeepSeek, Moonshot) à 28 (Cohere).

**Ruptures et retours (sur l'ensemble du panel)** : 10 `persistent_deviation`, 3 `return_to_baseline`, 15 `behavioral_deviation_detected` (dont la majorité jamais confirmés — voir plus bas).

### Zoom sur les 3 cas déjà documentés

- **Cohere** : le système le plus « bruyant » en apparence (8/8 valeurs distinctes utilisées, écart moyen 28,8 points, 22 jours changés sur 24) — et pourtant classé **standard** sans aucune rupture confirmée. Ses 4 `behavioral_deviation_detected` sont tous restés isolés (jamais 2 jours consécutifs dans le même sens). C'est l'exemple le plus clair de la différence entre *variation brute* et *événement significatif*.
- **Mistral** : volatilité modérée (5 valeurs distinctes, écart moyen 13,8) mais **deux ruptures confirmées** avec persistance réelle (05→09/09, puis 13→16/09), séparées par un retour complet à la baseline (10-12/09). C'est le seul des 3 cas où la variation observée constitue un véritable événement au sens de l'audit.
- **OpenAI** : le système le plus « plat » (3 valeurs distinctes, 21 jours identiques sur 24, quasi toujours à 100) — **MAD = 0**. Une seule panne complète (10/09, couverture 0) et un score ponctuellement inférieur à 100 ne suffisent jamais à générer un événement confirmé, mais produisent des `deviation_index` numériquement énormes (déjà signalé au tour précédent, ex. Meta à -290000) du simple fait de la division par un MAD nul.

### Réponse explicite à la question posée

> **La sonde longitudinale produit-elle suffisamment de variation observable dans le temps pour caractériser une trajectoire ?**

**Oui, mais inégalement, et pas toujours au bon niveau de résolution.** Sur les 12 systèmes, la moitié (Google, xAI, Mistral, DeepSeek, Moonshot, Infomaniak, Cohere — 7/12) présentent une variation jour-à-jour substantielle et exploitable (écarts moyens de 9,6 à 28,8 points, changement de valeur plus d'un jour sur deux). L'autre moitié (OpenAI, Anthropic, Qwen, Meta, et dans une moindre mesure Perplexity) opère dans un régime **plafonné** (`ceiling effect`) : le score reste collé à 100 (ou à sa valeur haute) l'immense majorité du temps, la sonde n'ayant presque jamais l'occasion d'exprimer de nuance dans cette zone — c'est précisément ce qui produit un MAD nul. **La variation existe globalement sur le panel, mais elle est structurellement absente pour les systèmes les plus stables**, ce qui n'est pas un défaut de la sonde en soi mais une conséquence directe de la faible résolution de l'instrument de mesure dans cette zone (voir §2).

Distinction variation brute / événement significatif, chiffrée : sur 12 systèmes × 25 jours post-baseline en moyenne ≈ 300 jours-système observés, on compte 15 `behavioral_deviation_detected` (un jour isolé sur ~20) mais seulement 10 `persistent_deviation` — et une bonne partie de ces 10 proviennent de 4 systèmes seulement (Mistral, DeepSeek, Moonshot, Infomaniak), suggérant que le seuillage actuel réagit à un sous-ensemble spécifique de systèmes à MAD modéré, pas uniformément au panel.

---

## 2. Limites statistiques de N = 7

**Formule** : `score = round(100 × normalCount / fullyScored)`, avec `fullyScored` généralement égal à 7 (ou moins en cas de couverture partielle).

- **Nombre de valeurs possibles** : `fullyScored + 1`. Pour 7 répétitions complètes : **8 valeurs** — {0, 14, 29, 43, 57, 71, 86, 100} (pas exactement équidistantes après arrondi : écarts de 14 ou 15 points). Pour un jour à couverture 6/7, la grille change entièrement : {0, 17, 33, 50, 67, 83, 100} — **la grille elle-même n'est pas stable**, elle dépend de la couverture réelle du jour, ce qui ajoute une source de discrétisation variable au-delà du simple pas de 100/N (observé concrètement : Cohere le 30/08 et le 02/09, score 50 et 83, correspondant à `fullyScored=6`).
- **Fréquence historique de MAD = 0** : **5/12 systèmes (41,7 %)** sur la fenêtre actuelle (§1) — pas un cas marginal, un régime courant dès qu'un système reste majoritairement à sa valeur plafond pendant les 14 jours de la fenêtre de baseline.
- **Effet sur les écarts normalisés** : quand MAD = 0, tout score différent de la médiane produit un `deviation_index` divisé par l'epsilon de garde (`0.0001`) plutôt que par une dispersion réelle — écarts observés de -140 000 à -290 000 dans le rejeu réel. Le moteur ne plante pas et n'escalade pas sur un jour isolé (l'hystérésis protège), mais le nombre lui-même est dénué de sens statistique (ce n'est plus un score-z interprétable, c'est un indicateur binaire déguisé en continu).
- **Sensibilité à une seule répétition** : avec N=7, **une seule répétition qui bascule d'ALLOW à FLAG déplace le score de 100/7 ≈ 14,3 points** — soit très exactement, dans la configuration actuelle, un déplacement égal ou supérieur au seuil `attention_accrue` (1,0 × MAD) dès que MAD ≤ 14,3, ce qui est le cas pour 8 des 12 systèmes du panel (tous sauf Cohere, DeepSeek, Moonshot, xAI). **Une seule réponse sur sept peut donc suffire, à elle seule, à faire franchir le premier seuil d'alerte.**
- **Risque de faux changement d'état** : la protection actuelle contre ce risque n'est pas statistique mais temporelle (exiger 2-3 jours consécutifs). Elle fonctionne (démontré §1 : Cohere n'a jamais escaladé malgré une volatilité brute très supérieure à celle des systèmes qui, eux, ont escaladé) mais elle ne corrige pas la cause : le score d'un seul jour reste une estimation à trop faible résolution pour distinguer un vrai changement de comportement d'un aléa d'échantillonnage sur 7 tirages.
- **Perte d'information à l'agrégation** : `decision` (ALLOW/FLAG/ERROR) est lui-même une catégorisation binaire/ternaire d'un signal amont déjà continu (`factual_hallucination_score`, `stability_score`, voir §3). L'agrégation en `normalCount/fullyScored` perd donc de l'information à **deux niveaux successifs** : une fois quand la réponse individuelle est catégorisée, une seconde fois quand les 7 catégories sont réduites à un seul pourcentage arrondi.

---

## 3. Richesse disponible sous le score agrégé (inspection des données élémentaires)

Inspection directe de `AI_WEATHER_RUNNER/results/2026-09-16/mistral_*_results.jsonl` (7 lignes longitudinales) et de plusieurs dates antérieures. Chaque ligne individuelle contient **plus de 60 champs**, dont, au-delà de `decision` :

| Champ | Nature observée | Variabilité constatée |
|---|---|---|
| `factual_hallucination_score` | quasi-continu (0, 0.8, 0.9, 1.0 observés) | distingue déjà la sévérité d'un FLAG, mais binarisé en `decision` avant tout calcul de score |
| `stability_score` | continu | **0.923077 pour toutes les réponses ALLOW observées** (valeur plafond identique), mais **variable parmi les FLAG** (0.646154 à 0.676923 selon la sévérité) |
| `coherence_score` | observé constant à 1.0 sur l'échantillon inspecté | aucune variabilité constatée dans cet échantillon — à ne pas surestimer |
| `g_score`, `esi_q_component`, `semantic_instability_score`, `energy_score`, `v_score`, `density_*` | continus, présents sur chaque ligne | non exploités en aval ; variabilité non caractérisée en détail dans cette étude (hors périmètre temps disponible) |
| `observed_model`, `observed_model_source` | présents structurellement | **`observed_model_source` vaut `runner_declared_fallback` (ou `runner_declared` pour Perplexity) pour les 12 fournisseurs, sans exception, y compris OpenAI où `observed_model="chat-latest"`** — le champ existe dans le schéma mais ne contient à ce jour aucune confirmation API indépendante ; il recopie la valeur demandée. Complète (sans le contredire) le constat de la Gate de validation : la capture d'un `model_returned` réellement vérifié reste à instrumenter. |
| `latency_ms` | continu | utilisé §4/§6 pour l'estimation de coût, pas pour le signal comportemental |

**Constat empirique sur la fenêtre de rupture Mistral (03-14/09), moyenne des 7 répétitions par jour :**

| Date | score (agrégé, 8 valeurs) | mean stability_score | mean g_score | mean factual_hallucination_score |
|---|---|---|---|---|
| 09-03 | 86 | 0.8879 | 0.5771 | 0.1143 |
| 09-04 | 57 | 0.8132 | 0.5286 | 0.3571 |
| 09-05 | 57 | 0.8000 | 0.5200 | 0.4000 |
| 09-06 | 71 | 0.8440 | 0.5486 | 0.2571 |
| 09-09 | 57 | 0.8000 | 0.5200 | 0.4000 |
| 09-10 | 86 | 0.8835 | 0.5743 | 0.1286 |
| 09-12 | 86 | 0.8879 | 0.5771 | 0.1143 |
| 09-14 | 71 | 0.8352 | 0.5429 | 0.2857 |

**Lecture honnête** : ces moyennes continues suivent le score agrégé de très près (elles sont largement dérivées du même comptage de décisions sous-jacent — `mean factual_hallucination_score` sur cet échantillon vaut quasi exactement `count(FLAG sévères)/7`), donc **ce ne sont pas des signaux totalement indépendants**. Leur valeur ajoutée réelle est plus fine que celle du score à trois niveaux : elles distinguent la **sévérité** au sein d'un même bucket FLAG (un facteur `factual_hallucination_score=0.8` n'est pas traité comme un `1.0`), ce que `decision` seul efface complètement. Elles offrent donc un gain de résolution **réel mais partiel** : elles ne créent pas d'information nouvelle sur les réponses ALLOW (plafonnées, invariables dans l'échantillon), mais elles évitent de perdre la gradation déjà présente parmi les réponses FLAG.

### A — Augmenter simplement N

Conserve la formule actuelle, réduit le pas de discrétisation (100/N) et réduit la variance d'échantillonnage, mais **ne récupère aucune information perdue à l'étape `decision`** : une réponse FLAG à 0.51 et une réponse FLAG à 0.99 resteront comptées de façon identique, quel que soit N.

### B — Améliorer l'estimateur

Utiliser directement une moyenne (ou médiane) des champs continus déjà collectés (a minima `1 - factual_hallucination_score`, en combinaison avec `decision` pour les cas ERROR) comme mesure quotidienne, en plus ou à la place du pourcentage ALLOW/N. Avantages démontrés par l'inspection ci-dessus : (a) granularité potentiellement continue plutôt que 8 valeurs fixes, sans changer N ; (b) préserve la gradation de sévérité déjà mesurée et déjà stockée, aujourd'hui jetée ; (c) **coût nul** — ces champs sont déjà collectés et déjà écrits dans les fichiers `_results.jsonl` existants, aucune répétition supplémentaire n'est nécessaire. Limite : ne résout pas la variance d'échantillonnage pure (toujours seulement 7 tirages), et l'effet de plafond côté ALLOW (`stability_score` identique pour toutes les réponses "propres" observées) réduit son bénéfice pour les systèmes déjà très stables — exactement ceux qui souffrent le plus du MAD=0 aujourd'hui.

**Conclusion de cette section** : A et B répondent à des problèmes différents et **partiellement complémentaires**, pas substituables l'un à l'autre — voir recommandation §7.

---

## 4. Comparaison N = 7 / 14 / 21 / 28

Les historiques réels ne contiennent que N=7 : aucune répétition supplémentaire n'a été simulée comme si elle était réelle. Les valeurs ci-dessous sont soit des **données réelles déjà disponibles** (coût, latence), soit des **estimations théoriques explicitement identifiées comme telles**.

| N | Granularité (100/N, théorique) | Valeurs possibles (théorique) | Écart-type attendu du score à p=0.9 fixé (théorique, loi binomiale : 100×√(p(1-p)/N)) | Sensibilité à 1 répétition (théorique) | Coût relatif (réel, linéaire en appels API) | Durée relative par système (estimée depuis `latency_ms` réel) | Intérêt méthodologique attendu |
|---|---|---|---|---|---|---|---|
| **7** (actuel) | 14,3 pts | 8 | 11,3 pts | 14,3 pts | 1× (référence) | 1× (≈15 s à ≈82 s selon fournisseur, mesuré) | Base actuelle — MAD=0 fréquent (§1-2) |
| **14** | 7,1 pts | 15 | 8,0 pts | 7,1 pts | 2× | ≈2× (si séquentiel par fournisseur) | Réduit de moitié la granularité et la sensibilité à 1 réponse ; réduction significative mais non garantie du taux de MAD=0 |
| **21** | 4,8 pts | 22 | 6,5 pts | 4,8 pts | 3× | ≈3× | Gain marginal décroissant par rapport à N=14 (7,1→4,8, soit -32 %, contre 14,3→7,1 soit -50 % pour le premier doublement) |
| **28** | 3,6 pts | 29 | 5,7 pts | 3,6 pts | 4× | ≈4× | Gain marginal plus faible encore (4,8→3,6, soit -25 %) ; coût et latence quadruplés pour un gain de résolution qui décroît |

**Lecture** : la loi de décroissance en `1/√N` (variance) et `1/N` (granularité) implique des **rendements décroissants** — le premier doublement (7→14) apporte le gain relatif le plus important ; chaque doublement supplémentaire coûte proportionnellement plus qu'il n'apporte de résolution. C'est un résultat théorique standard, pas une observation empirique propre à ce projet — il oriente vers un compromis plutôt qu'un extrême, conformément à la consigne de ne pas recommander arbitrairement le N le plus élevé.

**Comparabilité longitudinale** : tout changement de N constitue, par construction, un changement de méthode (`methodology_version`, cf. Gate §3.C) — la série historique à N=7 ne serait alors plus directement comparable point à point à la série future sans le marquer explicitement comme une rupture de segmentation (déjà prévu dans l'architecture V2, §3.C de la Gate). Ceci est vrai pour n'importe quel N choisi, pas spécifique à l'un d'eux.

**Volume quotidien** : passer tout le panel de N=7 à N=14 fait passer le volume de la sonde longitudinale de 7×12=84 à 168 observations/jour ; à N=28, 336/jour. Le protocole quotidien actuel (23 daily + 7 longitudinal = 30/système) resterait dominé par les répétitions quotidiennes de la question du jour jusqu'à N≈23 ; au-delà, la sonde longitudinale deviendrait la composante majoritaire du volume d'appels par système et par jour.

---

## 5. Protocole expérimental prospectif (non lancé)

**Objectif** : déterminer empiriquement, plutôt que théoriquement, à partir de quel N le signal se stabilise, en exploitant la structure même de l'exécution (les répétitions sont numérotées `repetition_index`, ce qui permet de reconstituer des sous-échantillons cumulatifs à partir d'un nombre de répétitions plus élevé exécuté une seule fois par jour).

**Principe** : exécuter, pour un sous-ensemble de systèmes, N=28 répétitions réelles de la sonde longitudinale par jour (au lieu de 7), puis calculer *a posteriori*, sur ces mêmes données, le score qu'auraient donné les 7 premières, les 14 premières, les 21 premières et les 28 répétitions complètes — sans jamais traiter une simulation comme une observation réelle : les 4 sous-échantillons proviennent tous de vraies réponses du modèle, seule leur regroupement diffère.

**Paramètres proposés** :
- **Systèmes** : 4, choisis pour couvrir les régimes identifiés au §1 — un système à MAD=0/plafonné (ex. Anthropic ou Qwen), un système volatile mais stable (Cohere), un système ayant déjà connu une rupture confirmée (Mistral), un système à couverture imparfaite (Perplexity ou OpenAI). Pas les 12, pour limiter le coût pendant la phase exploratoire.
- **Durée minimale** : 14 jours consécutifs, pour permettre de construire une mini-baseline à N=28 elle-même et observer si un régime de stabilité apparaît sur cette fenêtre, en plus des comparaisons intra-jour.
- **Métriques de comparaison** (pour chaque jour, chaque système, entre les sous-échantillons 7/14/21/28) :
  - écart absolu entre le score à N=k et le score à N=28 (référence la plus résolue disponible) ;
  - variance inter-jours du score à chaque N (teste si le signal se stabilise, pas seulement s'il change de valeur) ;
  - taux de MAD=0 obtenu à chaque N sur la mini-fenêtre de 14 jours ;
  - nombre d'événements (`behavioral_deviation_detected`, `persistent_deviation`) détectés à chaque N sur la même période, pour vérifier si un N plus élevé change la détection d'événements déjà identifiés à N=7 (ne doit ni en perdre, ni en halluciner de nouveaux sans justification).
- **Critère d'arrêt (« N suffisant »)** : le N à partir duquel l'écart moyen entre le score à N=k et le score à N=28 devient inférieur à un seuil pré-enregistré (proposition : la moitié du pas de discrétisation visé, soit ≈ 100/(2k)) **et** où l'ajout de répétitions supplémentaires ne change plus la classification en état longitudinal sur au moins 90 % des jours testés. Ce seuil est une proposition de départ à valider avec Sébastien avant tout lancement, pas une valeur figée.
- **Coût estimé** : 4 systèmes × 21 répétitions supplémentaires/jour (28-7) × 14 jours = **1 176 appels API supplémentaires** au total, en plus du protocole normal — un ordre de grandeur mesurable et raisonnable pour un pilote, à comparer au coût d'un déploiement erroné du protocole final sur les 12 systèmes indéfiniment.
- **Sortie** : rapport shadow séparé (même logique que la Phase 1), jamais consommé par l'interface publique, jamais substitué au protocole de production réel pendant l'expérience.

---

## 6. Coût relatif (résumé)

| Option | Coût API relatif | Latence relative par système | Risque de rupture de comparabilité | Implémentation |
|---|---|---|---|---|
| Garder N=7 | 1× | 1× | Aucun | Aucune |
| Améliorer l'estimateur (Option B) seule | **1× (aucun coût additionnel — données déjà collectées)** | 1× | Faible (nouveau champ calculé, ancien score conservable en parallèle) | Modérée (agrégateur existant à étendre, hors périmètre de ce tour) |
| N=14 | 2× | ≈2× | Oui, comme tout changement de N | Faible (paramètre déjà externalisé côté moteur shadow) |
| N=21 | 3× | ≈3× | Oui | Faible |
| N=28 | 4× | ≈4× | Oui | Faible |
| Expérience prospective (§5, 4 systèmes, 14 jours) | +1 176 appels ponctuels | N/A (pilote temporaire) | Aucun (n'affecte pas la production) | Aucune sur la production |

---

## 7. Recommandation argumentée

> **Pour AI Weather V2, avons-nous besoin de davantage de répétitions, d'un meilleur estimateur, ou des deux ?**

**Des deux, mais pas dans les mêmes proportions ni avec la même urgence.**

- L'**amélioration de l'estimateur** (Option B) est soutenue par une preuve directe et immédiate (§3) : les champs continus existent déjà, sont déjà collectés pour chaque répétition, et démontrablement plus informatifs que `decision` seul sur au moins une dimension (sévérité des FLAG) — à coût nul. C'est la correction la plus sûre et la moins coûteuse.
- L'**augmentation de N** est soutenue par un raisonnement théorique solide (rendements décroissants en 1/√N et 1/N, §4) mais **pas encore par une preuve empirique du N optimal** — proposer un N précis (14, 21 ou 28) sans l'expérience du §5 reviendrait à choisir un chiffre par intuition, ce que la consigne interdit explicitement.

**Recommandation technique : `INCREASE_N_AND_IMPROVE_ESTIMATOR`**, avec la précision suivante pour rester fondée sur les données plutôt que sur une hypothèse non testée :
- **Immédiat, fondé sur les données déjà collectées** : concevoir (pas encore implémenter en production) un estimateur secondaire basé sur les champs continus déjà présents dans les JSONL, à comparer au score actuel en shadow mode, avant toute décision de le rendre autoritatif.
- **N recommandé à titre d'hypothèse à tester, pas de décision finale** : **N=14**, comme première augmentation raisonnable (le doublement au meilleur rapport gain/coût selon le calcul théorique du §4) — mais **seule l'expérience prospective du §5** peut confirmer si N=14 suffit ou si un N supérieur reste justifié pour les systèmes les plus plafonnés (MAD=0 aujourd'hui). Ne pas fixer N=21 ou N=28 en production sans ce pilote.

---

## 8. Questions encore ouvertes

1. Les champs `g_score`, `esi_q_component`, `semantic_instability_score`, `energy_score`, `v_score`, `density_*` n'ont pas été caractérisés en détail (variance, corrélation mutuelle, corrélation avec `decision`) faute de temps dans cette étude — nécessaire avant de choisir lequel utiliser comme estimateur secondaire.
2. La méthodologie de l'API de gouvernance tierce qui produit `decision`, `factual_hallucination_score`, `stability_score` et consorts reste non documentée dans ce dépôt (déjà signalé, audit §11.4, Gate §3.A) — un estimateur amélioré qui s'appuierait plus fortement sur ces champs hériterait d'une dépendance non auditée plus fortement encore que le score actuel.
3. Le critère d'arrêt proposé au §5 (« écart < 100/(2k) et classification stable sur 90 % des jours ») est une proposition de départ, pas une valeur validée — à discuter avant tout lancement.
4. Cette étude n'a pas mesuré si l'augmentation de N modifierait le comportement du fournisseur lui-même (coût de rate-limiting, risque de throttling à N=28 pour les fournisseurs déjà lents comme Perplexity/Qwen, mesurés à 70-82 s/répétition) — à vérifier avant de lancer l'expérience du §5 à cette échelle.
5. Rien n'indique à ce stade si le ceiling effect observé pour OpenAI/Anthropic/Qwen/Meta reflète un système réellement extrêmement stable, ou une saturation de l'instrument de mesure lui-même (le protocole ne peut pas distinguer « toujours parfait » de « jamais assez sensible pour détecter une imperfection ») — question ouverte indépendante du choix de N, qui mériterait une sonde à stimulus different pour trancher, hors périmètre de cette étude.

---

*Fin du document. Aucune configuration de production modifiée. Aucune expérience lancée. En attente de validation avant toute suite.*
