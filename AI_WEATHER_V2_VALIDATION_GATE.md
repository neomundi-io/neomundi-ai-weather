# AI Weather V2 — Gate de validation méthodologique

**Statut :** document de validation uniquement. Aucun fichier de production, script, capsule ou API n'a été modifié pour produire ce document. Aucun déploiement n'a eu lieu.
**S'appuie sur (relus intégralement)** : `AI_WEATHER_LONGITUDINAL_AUDIT.md`, `AI_WEATHER_V2_ARCHITECTURE.md`, `AI_WEATHER_V2_IMPLEMENTATION_PLAN.md`.
**Objectif** : donner à Sébastien une base de décision rapide avant le développement du moteur longitudinal — ce qui est déjà tranché, ce qui reste ouvert, où en sont les 6 bloqueurs de l'audit, ce que le système ne devra jamais dire, et ce qui doit être configurable plutôt que codé en dur.
**Ce document ne donne pas de GO.** La section finale liste les éléments à vérifier ; la décision revient à Sébastien.

**Mise à jour du 2026-09-16 (fermeture des points RÉSOLVABLE AVANT CODE)** : ce tour de travail (1) corrige une contradiction sémantique trouvée entre ce document, `AI_WEATHER_V2_ARCHITECTURE.md` et la commande de cadrage initiale, concernant l'autorité du statut longitudinal ; (2) ferme les 4 points classés RÉSOLVABLE AVANT CODE ; (3) ajoute un tableau de traçabilité des fermetures ; (4) produit le bilan chiffré en fin de document. Aucun fichier de production, script, capsule ou API n'a été modifié pour ce faire — seule l'inspection en lecture seule des capsules `aiweather-capsule/capsules/2026/08/{17,21,22}.json` a été effectuée comme preuve du point B.

---

## 0. Correction sémantique prioritaire — autorité du statut longitudinal

**Contradiction trouvée** : la version précédente de ce document (§1.1/§1.2 originaux) et de `AI_WEATHER_V2_ARCHITECTURE.md` (§2) présentaient la non-autorité du canal longitudinal sur le "Weather" public comme une **règle permanente** de la V2. Ce n'est pas ce que demande le cadrage initial, qui établit explicitement que la sonde longitudinale « doit potentiellement devenir le socle principal d'AI Weather V2 » et que le challenge quotidien « deviendrait un objet distinct : TODAY'S CHALLENGE ». Confirmé à nouveau dans la commande de ce tour : *« le statut météo principal est déterminé par le moteur longitudinal ; Today's Challenge ne détermine jamais ce statut. »*

**Cause de l'erreur** : le fait actuel du code de production (`weather_authority: false` pour le canal longitudinal, `true` pour le canal daily) a été traité comme un invariant de conception à préserver indéfiniment, alors qu'il ne décrit que l'état présent (et l'état pendant le shadow mode, où rien du canal longitudinal n'est de toute façon publié). C'est un fait transitoire, pas une doctrine.

**Modèle corrigé — trois états, pas une règle unique** (détaillé et propagé dans `AI_WEATHER_V2_ARCHITECTURE.md` §2, corrigé dans ce tour) :

| État | Statut "météo principal" affiché | Canal longitudinal | Canal daily / Today's Challenge |
|---|---|---|---|
| 1. Aujourd'hui (production actuelle) | `global_condition` (daily) | Mesuré, non publié, `condition: null` | Autoritatif de fait |
| 2. Pendant le shadow mode | Reste `global_condition` (daily) — aucun changement public | Calculé en parallèle, non publié par construction du shadow mode (transitoire, pas doctrinal) | Reste autoritatif par prudence, pas par principe |
| 3. Cible V2 (post-validation) | Nouveau statut "AI Weather" (Standard/Attention accrue/renforcée/critique/Insufficient data) | **Devient l'autorité du statut AI Weather** | Devient "Today's Challenge" — non-autoritatif, définitivement, jamais fusionné |

**Ce qui reste vrai dans les trois états, sans exception** : NeoMundi fournit un signal et un état *documentés*, jamais une décision. L'interprétation métier, la décision et l'action restent toujours sous l'autorité de l'utilisateur ou de son système de gouvernance (chaîne Observation → Signal → Interprétation contextuelle → Décision → Action, architecture §6 — cette partie n'était pas en contradiction et reste inchangée).

**Documents corrigés** : `AI_WEATHER_V2_ARCHITECTURE.md` §2 (tableaux d'autorité, note de bascule ajoutée), §4 (portée des 5 états), §8 (deux lignes du tableau de bloqueurs), §9 (section CURRENT STATE) ; ce document, §1.2 ci-dessous et l'invariant n°2 de la section 5.

---

## 1. Décisions déjà suffisamment établies

Pour chacune : pourquoi elle est considérée comme réglée, quelles alternatives ont été examinées et écartées, ce qui reste néanmoins configurable, et ce que le shadow mode continuera de vérifier (sans la remettre en cause).

### 1.1 Séparation `longitudinal_reference` / `daily_challenge`

- **Pourquoi** : ce n'est pas une proposition nouvelle mais la formalisation d'un design déjà présent et vérifié dans le pipeline actuel (`probe_contract.daily`/`probe_contract.longitudinal`, `weather_authority`, `longitudinal_policy: "measured_separately_never_influences_daily_weather_v0.2"`).
- **Alternatives écartées** : fusionner les deux canaux en un score composite unique (reproduirait exactement la confusion que la commande initiale demande d'éliminer) ; laisser le score longitudinal influencer marginalement le Weather public (romprait une garantie déjà publiée et déjà vérifiée intacte par l'audit).
- **Configurable plutôt que codé en dur** : le nombre de répétitions attendu par canal (23/7) est déjà un paramètre de fichier (CSV panel), pas une constante — à conserver tel quel.
- **Vérifié en shadow mode** : un test de "contrat gelé" (Phase 3) confirme qu'aucun couplage accidentel n'apparaît entre les deux canaux pendant toute la durée du shadow mode.

### 1.2 Rôle du statut longitudinal — trajectoire vers l'autorité du statut AI Weather (corrigé, voir §0)

- **Pourquoi cette formulation** : le fait actuel du code (`weather_authority: false` côté longitudinal, commentaire « NEVER influences daily Weather condition ») décrit correctement l'**état 1 et l'état 2** (aujourd'hui, et pendant tout le shadow mode, où rien du canal longitudinal n'est publié par construction). Il ne décrit **pas** l'objectif final : en cible V2 (état 3), c'est le canal longitudinal qui devient l'autorité du statut "AI Weather" principal, et `daily_challenge`/Today's Challenge qui devient définitivement non-autoritatif. La version précédente de cette Gate confondait ces deux niveaux — corrigé ici.
- **Alternatives écartées** : combiner les deux canaux dans un score de confiance global publié — toujours écarté, cette fois pour une raison différente et plus précise : cela romprait la clarté d'attribution (le lecteur ne saurait plus si le statut vient du comportement de fond ou de l'édition du jour), pas parce que le canal longitudinal ne devrait "jamais" être autoritatif.
- **Configurable** : le champ `weather_authority` reste une donnée (déjà le cas) qui **s'inverse explicitement à la bascule** (état 2 → état 3), jamais une constante figée — permet un audit automatisé continu du sens de l'autorité à tout instant.
- **Vérifié en shadow mode** : pendant le shadow mode, test de non-publication du canal longitudinal (rien de sa sortie n'atteint `weather.json` public) — différent d'un test de "non-autorité permanente". À la bascule, un test symétrique inversé prend le relais : `global_condition`/`global_score` (daily) ne doivent alors plus être lus comme "le" statut AI Weather par aucun composant.

### 1.3 Immutabilité des capsules historiques

- **Pourquoi** : déjà implémentée (`generate_capsule.py` refuse d'écraser un fichier existant) et déjà vérifiée par l'audit (chaîne SHA-256 ininterrompue sur les 27 capsules existantes).
- **Alternatives écartées** : réécrire rétroactivement les capsules du 17/21 août une fois leur schéma exact identifié — explicitement écarté, casserait la chaîne de hash des capsules suivantes.
- **Configurable** : aucune — c'est une invariante structurelle, pas un paramètre.
- **Vérifié en shadow mode** : le backfill rétrospectif (Plan, Phase 5) produit un rapport dérivé séparé ; le shadow mode est précisément l'espace où ce rapport est produit et relu avant toute autre décision, sans jamais toucher aux capsules d'origine.

### 1.4 Architecture additive et fail-open

- **Pourquoi** : cohérente avec la politique already-push déjà en vigueur (`AI_WEATHER_KNOWN_FIXES.md` #11) et avec le principe déjà affirmé dans `generate_capsule.py` (« Measurement != Interpretation != Judgment Demand != Action »).
- **Alternatives écartées** : bloquer la publication quotidienne si le moteur longitudinal échoue — contredirait directement la politique already-push déjà validée.
- **Configurable** : le comportement fail-open lui-même est un invariant, non un paramètre ; le niveau de journalisation en cas d'échec peut, lui, être configurable.
- **Vérifié en shadow mode** : simulation volontaire de panne du moteur, pour confirmer que `daily_challenge` continue de se publier normalement (test déjà listé au Plan, Phase 5).

### 1.5 Shadow mode

- **Pourquoi** : c'est le seul mécanisme qui permet de calibrer les décisions encore provisoires (section 2) sur des données réelles, sans aucun risque de publication puisqu'il ne produit aucune sortie publique.
- **Alternatives écartées** : calibrer directement en production dès l'intégration au contrat JSON — écarté, car cela publierait des seuils non calibrés comme s'ils étaient définitifs, reproduisant l'écueil déjà relevé par l'audit sur `METHODOLOGY_THRESHOLDS.md` (seuils annoncés « à recalibrer » mais jamais suivis faute de mécanisme).
- **Configurable** : la durée du shadow mode (nombre de jours avant toute décision de bascule) doit elle-même être un paramètre explicite, pas une décision informelle.
- **Auto-référence** : le shadow mode est l'instrument de calibration des autres décisions, pas l'inverse — sa propre durée peut être prolongée si les données montrent qu'une baseline n'est pas encore stable.

### 1.6 Compatibilité descendante

- **Pourquoi** : de multiples widgets déjà déployés (`weather-bar-*`, `weather-sidebar-*`, embeds tiers) ne doivent jamais casser ; c'est une contrainte externe, pas un choix de conception à débattre.
- **Alternatives écartées** : publier un nouveau fichier/endpoint pour le schéma V2 — écarté pour ne pas casser silencieusement les intégrations tierces existantes.
- **Configurable** : sans objet — le principe « additif uniquement » est une contrainte testée (test de contrat gelé, Plan Phase 3), pas un paramètre ajustable.
- **Vérifié en shadow mode** : confirmation qu'aucune régression visuelle n'apparaît sur les pages existantes avant toute bascule.

### 1.7 Capture de `model_returned`

- **Pourquoi** : seule façon de transformer la correction de l'alias OpenAI d'une simple promesse de configuration en une preuve vérifiable en continu — répond directement au bloqueur le plus critique de l'audit (§3 ci-dessous).
- **Alternatives écartées** : se contenter d'épingler `panel.yml` sans vérification continue — écarté, car cela recréerait la même vulnérabilité si un alias non épinglé était un jour réintroduit sans que personne ne s'en aperçoive.
- **Configurable** : la liste des fournisseurs exposant réellement ce champ (tous ne le font pas nécessairement) doit être un paramètre documenté, jamais une hypothèse silencieuse.
- **Vérifié en shadow mode** : observation, avant toute décision, de quels fournisseurs exposent effectivement ce champ et avec quelle fiabilité, avant de fonder un événement `known_model_version_change` dessus.

---

## 2. Décisions encore provisoires

### 2.1 Fenêtre de baseline de 14 jours

- **Pourquoi proposée** : compromis entre robustesse statistique et données réellement disponibles (~26 jours utiles au 16/09/2026) — 14 jours laisse une seconde moitié de fenêtre pour tester la baseline sur des données non utilisées pour la construire.
- **Alternatives** : 7 jours (trop sensible à un incident isolé sur une seule semaine) ; 21 jours (plus robuste, mais ne laisserait presque aucun jour "hors échantillon" pour la valider) ; fenêtre glissante continue (écartée en V1, cf. architecture §3, risque de "baseline qui chasse la donnée").
- **Configurable** : oui, impérativement — `baseline_window_days`.
- **Calibration en shadow mode** : comparer, sur l'historique déjà disponible, la stabilité de la médiane/MAD calculée sur 7 / 14 / 21 jours, et retenir la valeur qui minimise les faux positifs sur la portion restante de l'historique connu.

### 2.2 Médiane + MAD comme mesure centrale

- **Pourquoi proposée** : robuste aux valeurs aberrantes, explicable publiquement, adaptée à un historique encore court (cf. comparaison des 4 méthodes, architecture §3).
- **Alternatives** : moyenne/écart-type (écartée, trop sensible aux outliers sur petit N) ; détection de rupture CUSUM (prématurée avant plusieurs mois de données) ; écart interquartile (IQR) à la place de MAD — alternative proche à considérer si le MAD réagit mal à la distribution réelle observée.
- **Configurable** : oui — `dispersion_method: "mad" | "iqr" | "stdev"`.
- **Calibration en shadow mode** : rejouer les trois méthodes sur l'historique réel et comparer leur taux de faux positifs (`behavioral_deviation_detected`) avant de figer un choix définitif.

### 2.3 Seuils des 5 états (multiplicateurs de déviation)

- **Pourquoi proposée** : valeurs par défaut usuelles (1× / 2× / 3× MAD), explicitement qualifiées de provisoires dans l'architecture (§4) — non calibrées sur les données réelles du projet à ce stade.
- **Alternatives** : seuils exprimés en percentiles de la distribution historique plutôt qu'en multiples de MAD ; seuils différenciés par système plutôt qu'uniformes pour les 12.
- **Configurable** : oui, impérativement — objet `deviation_thresholds` externalisé (voir section 5).
- **Calibration en shadow mode** : observer la distribution réelle des `deviation_index` journaliers sur les 12 systèmes pendant toute la durée du shadow mode, et ajuster pour que "Attention accrue" reste un événement rare mais pas inexistant — décision partagée avec Sébastien, pas un chiffre imposé.

### 2.4 Seuils de persistance (N jours consécutifs)

- **Pourquoi proposée** : nombre minimal jugé suffisant pour distinguer un bruit d'un jour d'une tendance réelle, sans retarder excessivement la détection.
- **Alternatives** : persistance proportionnelle à la longueur de la fenêtre de baseline plutôt que fixe ; nombre de jours différent à l'élévation et à la désescalade (asymétrie) plutôt que symétrique.
- **Configurable** : oui — objet `persistence_days` par palier.
- **Calibration en shadow mode** : rejouer sur l'historique réel pour vérifier qu'aucune séquence déjà connue (incident Mistral du 14/09, bug de panel Moonshot) ne déclenche à tort un état persistant, et ajuster N en conséquence.

### 2.5 Couverture minimale interprétable côté longitudinal

- **Pourquoi proposée** : réutilise directement `$COVERAGE_MIN_INTERPRETABLE = 0.80` déjà en place pour le canal daily, plutôt que d'inventer un nouveau chiffre.
- **Alternatives** : seuil propre au canal longitudinal, potentiellement plus strict (ex. 6/7 plutôt que 5/7), puisque chaque répétition manquante pèse proportionnellement plus lourd sur 7 répétitions que sur 23.
- **Configurable** : oui — `longitudinal_min_scored_repetitions`.
- **Calibration en shadow mode** : mesurer la fréquence réelle de jours à 5/6/7 répétitions scorées sur l'historique disponible, et choisir un seuil qui ne classe pas une proportion excessive de jours par ailleurs normaux en `insufficient_data`.

### 2.6 Règles exactes de retour à la baseline

- **Pourquoi proposée** : symétrie par défaut avec les seuils d'élévation (mêmes N jours) — choix de simplicité, pas de preuve empirique à ce stade.
- **Alternatives** : désescalade plus lente que l'élévation (principe de prudence, éviter de déclarer un retour à la normale trop vite) ; zone tampon plus large pour éviter un effet de "clignotement" si le comportement oscille juste autour du seuil.
- **Configurable** : oui — `return_to_baseline_days`, séparé de `persistence_days` pour permettre l'asymétrie si le shadow mode le justifie.
- **Calibration en shadow mode** : observer spécifiquement les cas d'oscillation autour d'un seuil et ajuster (symétrie, asymétrie, ou hystérésis élargie) selon ce qui est réellement constaté, pas selon une préférence a priori.

---

## 3. Fermeture des 4 points classés RÉSOLVABLE AVANT CODE

Rappel des 6 bloqueurs de l'audit et de leur classement précédent, avant fermeture :

| # | Bloqueur (audit §11 / architecture §8) | Classement précédent |
|---|---|---|
| 1 | Alias OpenAI non épinglé + 3 configurations divergentes | RÉSOLVABLE AVANT CODE |
| 2 | Divergence secondaire Anthropic/Cohere | RÉSOLVABLE AVANT CODE |
| 3 | Schéma des capsules du 17 et du 21 août non vérifié | RÉSOLVABLE AVANT CODE |
| 4 | Grounding Perplexity / paramètres Google | À TESTER EN SHADOW MODE (inchangé, hors périmètre de cette fermeture) |
| 5 | Détection de changement futur de snapshot | À TESTER EN SHADOW MODE (inchangé, hors périmètre de cette fermeture) |
| 6 | Version du protocole/méthode non tracée | RÉSOLVABLE AVANT CODE |

Les points 1, 2 et 6 sont traités par les sous-sections A et C ci-dessous ; le point 3 par la sous-section B. Aucun point RÉSOLVABLE AVANT CODE ne subsiste en dehors de ces trois sujets (voir D).

### A. Identité des modèles — schéma canonique `system_identity`

**Champs canoniques** (à intégrer au contrat JSON V2, Phase 2 — non codé à ce stade) :

| Champ | Définition |
|---|---|
| `provider` | Fournisseur déclaré (existant, inchangé, ex. "OpenAI") |
| `model_declared` | Identifiant canonique documenté dans `config/panel.yml` — ce que le projet affirme utiliser publiquement |
| `model_requested` | Chaîne littérale réellement envoyée à l'API par le runner (vérité de terrain de la requête) — ex. `"chat-latest"` pour OpenAI aujourd'hui |
| `model_returned` | Identifiant échoïsé par la réponse de l'API pour cet appel précis, quand le fournisseur l'expose — **non capturé aujourd'hui**, instrumentation à ajouter en Phase 0 |
| `snapshot_or_version` | Champ de version/empreinte distinct du nom de modèle quand le fournisseur l'expose séparément (ex. `system_fingerprint`) — permet de détecter qu'un même `model_returned` recouvre en réalité deux versions différentes |

**Statut d'identité — 4 cas, définition opérationnelle** :

| `identity_status` | Définition | Condition |
|---|---|---|
| `verified` | L'API a confirmé, pour cette observation précise, quel modèle a répondu | `model_returned` capturé et exploitable |
| `declared` | Aucune confirmation API, mais la configuration déclare un identifiant de snapshot daté et stable par construction (le fournisseur garantit qu'un identifiant daté sert toujours les mêmes poids) | `model_returned` indisponible, ET `model_requested` == un identifiant épinglé daté (pas un alias) |
| `inferred` | Aucune confirmation automatique, mais une source externe (changelog fournisseur, annonce publique) corrobore manuellement l'identité à cette date | Corroboration manuelle enregistrée dans `config/provider_changelog.json` |
| `unknown` | Ni confirmation API, ni déclaration stable, ni corroboration externe | `model_requested` est un alias non épinglé (ex. `"chat-latest"`), ou aucune référence fiable n'existe |

**Point de vigilance explicite** : un alias non épinglé (cas OpenAI actuel) doit être classé `unknown`, **pas** `declared` — même si `panel.yml` documente une valeur, cette valeur n'a aucune garantie de stabilité tant que le runner interroge un alias. `declared` suppose que la configuration elle-même est fiable dans le temps, ce qui n'est pas le cas d'un alias.

**Comment l'incertitude d'identité affecte la couverture, jamais artificiellement la stabilité** : `identity_status` est publié dans un bloc distinct (`evidence_integrity`, architecture §7), **jamais** injecté dans le calcul de `current_longitudinal_state`. Un système en `identity_status: unknown` ou `inferred` doit afficher un badge de réserve explicite partout où son état longitudinal est montré, et ne peut jamais apparaître "plus stable" qu'un système `verified` simplement parce qu'on dispose de moins de munitions pour détecter un écart chez lui. Concrètement : l'incertitude d'identité dégrade la **confiance/preuve** affichée à côté du statut, elle ne modifie jamais le calcul du statut lui-même — c'est l'application directe de l'invariant "absence de donnée ≠ stabilité" (§5.3) au domaine de l'identité plutôt qu'à celui de la couverture de répétitions.

**Statut** : le schéma ci-dessus est complet et sans ambiguïté de conception. Reste à exécuter en Phase 0 (hors périmètre de ce tour, qui est documentaire) : l'édition mécanique de `panel.yml`/`run_weather_openai.ps1` pour remplacer l'alias, et l'instrumentation de la capture de `model_returned` dans les 12 runners.

### B. Capsules historiques des 17 et 21 août — vérifiées par inspection directe

**Méthode** : lecture seule (aucune modification) de `aiweather-capsule/capsules/2026/08/17.json`, `21.json` et `22.json`, comparaison de leurs champs `interpretation_contract`, `coverage` et `chain`.

**Constats vérifiés** :

| Capsule | `interpretation_contract.profile_version` | `longitudinal_policy` présent | `coverage` (champs longitudinaux) | Verdict |
|---|---|---|---|---|
| **17/08** (`sequence_index: 0`, genèse) | `"0.1"` | **absent** | pas de `daily_fully_scored`/`longitudinal_fully_scored` — un seul `panel_coverage` global | Design pré-scission ("WEATHER-SENTINEL 0.1", 1 question × 30 répétitions) — **incompatible structurellement** avec le canal longitudinal actuel, pas un problème de qualité de données |
| **21/08** (`sequence_index: 1`) | `"0.2"` | présent (`"measured_separately_never_influences_daily_weather_v0.2"`) | `daily_fully_scored: 276/276` ; `longitudinal_fully_scored: 77/84` (**91,67 %**) | Split daily/longitudinal déjà actif — **utilisable**, avec une couverture longitudinale partielle documentée ce jour-là (au-dessus du seuil interprétable existant de 0,80) |
| **22/08** (`sequence_index: 2`) | `"0.2"` | présent | `longitudinal_fully_scored: 84/84` (100 %) | Référence, conforme en tout point |

**Décision de traitement** :
- **17/08 : exclue structurellement** du calcul de baseline et de toute trajectoire longitudinale — pas marquée `insufficient_evidence` (qui suggérerait un problème de données), mais explicitement `protocol_incompatible` : le protocole lui-même n'est pas celui qu'on mesure aujourd'hui. La capsule reste intacte et immuable, simplement hors périmètre.
- **21/08 : utilisable**, premier jour valide de la fenêtre longitudinale — avec une réserve de couverture partielle (91,67 % panel-wide) à vérifier système par système lors du rejeu de backtest (Plan, Phase 1), sans que cela bloque son inclusion.
- **18, 19, 20/08 : absentes de la chaîne de capsules** (trou déjà documenté par l'audit) — non concernées par cette fermeture, simplement inexistantes.
- **Correction factuelle propagée** : l'audit et l'architecture citaient par prudence le "22/08" comme début confirmé de la fenêtre v0.2 (faute d'avoir inspecté directement les capsules du 17/21). La preuve directe montre que la fenêtre exploitable démarre en réalité le **21/08/2026**, un jour plus tôt. Corrigé dans `AI_WEATHER_V2_ARCHITECTURE.md` (§2, §7, §8).
- **Aucune capsule n'a été ni modifiée ni réécrite** pour produire ce constat — inspection en lecture seule uniquement.

**Statut** : entièrement résolu — aucune ambiguïté ne subsiste sur le traitement de ces deux capsules.

### C. Versionnement méthodologique

**`methodology_version`** — version de la **méthode de calcul** elle-même (formule, algorithme de baseline, logique d'état). Change uniquement quand la méthode change (ex. passer de médiane/MAD à une détection de rupture CUSUM) — un événement rare et structurant.

**`baseline_config_version`** — version des **valeurs numériques** d'un fichier de configuration externalisé (fenêtre, seuils, persistance, couverture minimale — cf. §6), pour la même méthode. Change à chaque recalibration de seuils, plus fréquemment que `methodology_version`, sans changer l'algorithme sous-jacent.

**Comment une capsule indique la version qui l'a produite** : chaque capsule/`data/history/*.json` futur porte, dans son bloc `evidence_integrity` (architecture §7), le couple exact `{ methodology_version, baseline_config_version }` actif au moment du calcul — jamais déduit après coup, toujours estampillé à la production.

**Règle de comparaison entre deux périodes calculées avec des versions différentes** :
- Si `methodology_version` diffère entre deux périodes → **non comparables directement**. La méthode elle-même a changé ; toute comparaison brute serait trompeuse. La baseline doit être recalculée entièrement pour la période suivant le changement (jamais reportée silencieusement). Le point de bascule doit apparaître comme une rupture visible dans la trajectoire affichée (Model Detail, architecture §9), jamais lissé.
- Si seul `baseline_config_version` diffère (méthode inchangée, seuils retouchés) → la baseline elle-même n'a pas besoin d'être recalculée, mais toute réinterprétation rétroactive des états historiques doit passer par un **jeu de données dérivé** distinct (jamais une réécriture des capsules d'origine — cohérent avec l'invariant d'immuabilité, §5.7).
- **Point ouvert, non tranché ici** : faut-il un 8ᵉ événement structuré (ex. `methodology_change_boundary`) pour signaler formellement ces bascules dans `detected_events[]` ? C'est une extension possible, pas décidée dans ce tour — à soumettre à Sébastien avant la Phase 2 si jugé utile.

**Statut** : concepts et règles de comparaison entièrement définis, sans ambiguïté de conception. Reste à exécuter en Phase 0/2 : création effective du fichier `AI_WEATHER_METHODOLOGY_CHANGELOG.md` et intégration des deux champs de version au contrat JSON.

### D. Autres points RÉSOLVABLE AVANT CODE de la Gate

Vérification exhaustive : les 4 points classés RÉSOLVABLE AVANT CODE dans le tableau de rappel ci-dessus (1, 2, 3, 6) sont intégralement couverts par les sous-sections A (points 1 et 2 — identité OpenAI et divergence Anthropic/Cohere relèvent du même schéma canonique), B (point 3) et C (point 6). **Aucun point RÉSOLVABLE AVANT CODE ne reste non traité.**

---

## 4. Tableau final de fermeture

| Point | Statut précédent | Action réalisée | Nouveau statut | Preuve / justification |
|---|---|---|---|---|
| Autorité du statut longitudinal (contradiction sémantique) | *(non classé — erreur de conception)* | Modèle à 3 états défini (§0) ; correction propagée dans `AI_WEATHER_V2_ARCHITECTURE.md` §2/§4/§8/§9 et dans cette Gate §1.2/§5.2 | **RÉSOLU** | Relecture croisée avec le message de cadrage initial ("doit potentiellement devenir le socle principal") et la commande de ce tour ; contradiction identifiée et corrigée par édition directe des deux documents |
| 1. Alias OpenAI non épinglé + 3 configs divergentes | RÉSOLVABLE AVANT CODE | Schéma canonique `system_identity`/`identity_status` défini (§3.A) ; OpenAI classé `unknown` tant que l'alias subsiste | **RÉSOLU (méthodologiquement)** — édition mécanique de `panel.yml`/du runner différée à la Phase 0 d'exécution, hors périmètre documentaire de ce tour | Schéma complet et sans ambiguïté §3.A ; aucun fichier de production modifié conformément à la consigne de ce tour |
| 2. Divergence secondaire Anthropic/Cohere | RÉSOLVABLE AVANT CODE | Même schéma et même règle de réconciliation que le point 1 | **RÉSOLU (méthodologiquement)**, édition mécanique différée à la Phase 0 | §3.A |
| 3. Schéma des capsules du 17 et du 21 août | RÉSOLVABLE AVANT CODE | Inspection directe en lecture seule des 3 capsules (17, 21, 22/08) ; comparaison de `interpretation_contract`/`coverage` | **RÉSOLU** | Preuve : `profile_version` 0.1 vs 0.2, présence/absence de `longitudinal_policy`, `longitudinal_fully_scored: 77/84` le 21/08 — détail complet §3.B |
| 6. Version du protocole/méthode non tracée | RÉSOLVABLE AVANT CODE | `methodology_version` et `baseline_config_version` définis séparément, règle de comparaison inter-périodes établie | **RÉSOLU (méthodologiquement)** — création effective des fichiers différée aux Phases 0/2 | §3.C |
| 4. Grounding Perplexity / paramètres Google | À TESTER EN SHADOW MODE | Aucune (hors périmètre de cette fermeture, confirmé non résolvable avant données réelles) | **À TESTER EN SHADOW MODE** (inchangé) | Architecture §8 — nécessite une observation empirique, pas une décision de configuration |
| 5. Détection de changement futur de snapshot | À TESTER EN SHADOW MODE | Aucune (dépend d'un fait inconnu : quels fournisseurs exposent `model_returned`) | **À TESTER EN SHADOW MODE** (inchangé) | Architecture §8 — réserve signalée : dépendance à un comportement d'API hors du contrôle de NeoMundi |

**Aucun point n'est classé BLOQUANT.** Le point 5 conserve une réserve durable (et non temporaire) : si un fournisseur n'expose jamais de champ modèle échoïsé, l'événement `known_model_version_change` restera structurellement de confiance basse pour ce système — ce n'est pas un blocage, c'est une limite à accepter comme durable plutôt qu'à chercher à résoudre.

---

## 5. Invariants méthodologiques — ce que le système ne devra jamais affirmer

1. **Une variation comportementale observable ne prouve jamais, à elle seule, une modification interne du modèle** (poids, entraînement, version). Sans corroboration externe (changelog fournisseur, écho API confirmé), tout écart reste qualifié de « comportement observé », jamais de « modèle modifié ».
2. **Today's Challenge ne détermine jamais, ni directement ni indirectement, le statut AI Weather** (dérivé du canal longitudinal). Cet invariant est **asymétrique et le reste dans les trois états d'autorité décrits en §0** : il n'a pas de réciproque à interdire — au contraire, que le statut AI Weather finisse par être dérivé du canal longitudinal une fois celui-ci calibré est l'objectif même de la V2, pas une violation à empêcher. Les deux canaux restent en toutes circonstances calculés et publiés séparément (aucune dérivation croisée de Today's Challenge vers AI Weather, dans aucun sens), mais seule la direction "Today's Challenge → AI Weather" est proscrite.
3. **L'absence de données n'est jamais interprétée comme une stabilité.** Un jour à couverture insuffisante produit l'état `insufficient_data`, jamais `standard`, et n'est jamais compté ni pour ni contre un streak de persistance ou de retour à la baseline.
4. **Un changement de fournisseur, de snapshot, ou une identité de modèle incertaine doit toujours rester visible dans les champs de couverture/identité** (`system_identity.model_pinned`, `model_identity_unverified`) — jamais absorbé silencieusement dans un score agrégé qui masquerait cette incertitude.
5. **Les actions suggérées à l'utilisateur** (chercheur, développeur, QA, opérateur, gouvernance) **sont des exemples d'usage indicatifs, jamais des décisions automatiques prises ou déclenchées par NeoMundi.** NeoMundi s'arrête au signal documenté (chaîne Observation → Signal → Interprétation contextuelle → Décision → Action, architecture §6).
6. **Aucun événement longitudinal ne s'accompagne d'une pénalité de score, d'une note ou d'un jugement de qualité.** Le principe déjà publié (« the displayed signal is an observation, not a performance or quality score ») s'étend explicitement au canal longitudinal.
7. **Aucune capsule historique déjà publiée n'est jamais modifiée pour "corriger" une méthode de calcul a posteriori.** Toute recalibration s'applique aux publications futures ; jamais rétroactivement aux données déjà chaînées par hash.
8. **L'état "Attention critique" n'est jamais déclenché sur la seule base d'une couverture faible.** Une couverture faible produit `insufficient_data`, pas une escalade de sévérité.

---

## 6. Configuration du moteur — ce qui doit être externalisé, pas codé en dur

Principe : toute valeur numérique encore provisoire (section 2) doit vivre dans un fichier de configuration versionné, jamais en constante dans le code du moteur — c'est la correction directe du problème déjà identifié par l'audit sur `METHODOLOGY_THRESHOLDS.md` (seuils annoncés « à recalibrer » mais sans mécanisme réel de suivi).

Proposition de fichier `AI_WEATHER_RUNNER/config/longitudinal_engine_config.json` (nom indicatif, à trancher) :

```jsonc
{
  "config_version": "shadow-v0.1",       // à incrémenter à chaque changement, référencé par methodology_version
  "baseline": {
    "window_days": 14,                    // §2.1
    "dispersion_method": "mad"            // §2.2 — "mad" | "iqr" | "stdev"
  },
  "deviation_thresholds": {               // §2.3 — multiplicateurs de dispersion
    "attention_accrue": 1.0,
    "attention_renforcee": 2.0,
    "attention_critique": 3.0
  },
  "persistence_days": {                   // §2.4
    "attention_accrue": 2,
    "attention_renforcee": 3,
    "attention_critique": 3
  },
  "return_to_baseline_days": {            // §2.6
    "attention_accrue": 2,
    "attention_renforcee": 3,
    "attention_critique": 3
  },
  "coverage": {                           // §2.5
    "longitudinal_min_scored_repetitions": 5,
    "longitudinal_expected_repetitions": 7
  },
  "event_rules": {
    "variability_increase_dispersion_multiplier": null,   // à calibrer en shadow mode
    "coverage_anomaly_min_coverage": 0.71
  },
  "known_data_exclusions": {              // jours à exclure explicitement du calcul de baseline
    "moonshot": ["<jours identifiés en Phase 0>"]
  }
}
```

Chaque changement de ce fichier doit s'accompagner d'un incrément de `config_version` et d'une entrée dans `AI_WEATHER_METHODOLOGY_CHANGELOG.md` (Plan, Phase 0) — c'est le mécanisme qui manquait jusqu'ici pour tenir la promesse, déjà faite une fois sans suite, de recalibrer les seuils.

---

## 7. GO / NO-GO pour le shadow mode — checklist de vérification

*Ce document ne tranche pas. Les points ci-dessous sont à cocher par Sébastien avant toute décision de lancement du shadow mode.*

1. ☐ La date de début officielle de la fenêtre longitudinale (17, 21 ou 22 août) a été tranchée après inspection réelle des capsules du 17 et du 21 août.
2. ☐ L'identifiant de modèle OpenAI a été épinglé et aligné entre `panel.yml` et le runner — ou la décision de ne pas le faire avant le shadow mode est explicitement assumée et documentée.
3. ☐ La liste des jours à exclure du calcul de baseline (bug de panel Moonshot, incident clé API Mistral du 14/09) a été validée.
4. ☐ Le fichier de configuration externalisé (section 5) existe, même avec des valeurs provisoires, et est versionné.
5. ☐ Le moteur longitudinal produit une sortie reproductible sur un rejeu de l'historique existant (même entrée → même sortie, vérifié).
6. ☐ Le principe fail-open a été testé par simulation de panne du moteur, sans impact constaté sur la publication du `daily_challenge`.
7. ☐ Un test de "contrat gelé" confirme qu'aucun champ actuellement lu par `index.html`/`weather-data.js`/les widgets n'a été renommé ou supprimé.
8. ☐ Le wording des 7 événements `WHAT CHANGED?` a été relu et validé contre les invariants méthodologiques (section 4 de ce document).
9. ☐ La durée prévue du shadow mode (nombre de jours avant toute décision de bascule vers la Phase 5) est explicitement fixée.
10. ☐ Sébastien a revu les 6 décisions encore provisoires (section 2) et indiqué lesquelles il souhaite trancher avant le shadow mode plutôt que de les laisser se calibrer pendant.

---

## 8. Bilan de fermeture (2026-09-16)

- **Points RÉSOLUS** : 5 — autorité du statut longitudinal (contradiction sémantique corrigée), identité OpenAI, divergence Anthropic/Cohere, capsules du 17/21 août, versionnement méthodologique. (Les points identité et versionnement sont résolus au niveau méthodologique/documentaire ; l'édition mécanique des fichiers de configuration reste à exécuter en Phase 0, non commencée.)
- **Points À TESTER EN SHADOW MODE** : 2 — grounding Perplexity/paramètres Google, détection de changement futur de snapshot fournisseur.
- **Points BLOQUANTS** : 0.
- **Contradictions restantes** : aucune identifiée à ce stade. Un point ouvert et non tranché a été noté (§3.C) : l'opportunité d'un 8ᵉ événement structuré (`methodology_change_boundary`) pour signaler formellement une bascule de méthode dans `detected_events[]` — à soumettre à Sébastien avant la Phase 2, ce n'est pas une contradiction mais une extension possible non décidée.
- **Fichiers documentaires modifiés dans ce tour** : `AI_WEATHER_V2_ARCHITECTURE.md` (§2, §4, §8, §9), `AI_WEATHER_V2_VALIDATION_GATE.md` (§0 ajoutée, §1.2, §3, §4, invariant n°2, renumérotation §5-§7, §8 ajoutée). Aucun fichier de production, script, capsule ou API modifié ; deux fichiers de capsule (`17.json`, `21.json`) et un troisième (`22.json`) ont été lus, jamais écrits.

---

*Fin du document de validation. Aucune implémentation n'a été commencée. En attente de la décision de Sébastien — le GO shadow mode n'est toujours pas donné.*
