# QUESTION_CATEGORIES_METHODOLOGY_FR.md

# Méthodologie des catégories de questions — AI Weather

**Langues :**
[🇫🇷 Version française](./QUESTION_CATEGORIES_METHODOLOGY_FR.md) · [🇬🇧 English version](./QUESTION_CATEGORIES_METHODOLOGY_EN.md)

---

## 1. Objet du document

AI Weather utilise un ensemble structuré de questions répétées afin d’observer le comportement de systèmes d’intelligence artificielle dans le temps.

Ces questions ne sont pas conçues uniquement comme des tests de connaissance.

Elles servent de **sondes** permettant d’exposer les systèmes à différents types de tension : factuelle, épistémique, conceptuelle, comparative ou réflexive.

L’objectif est d’observer si un système :

* maintient une réponse stable ;
* détecte les présupposés incorrects ;
* distingue faits, hypothèses et interprétations ;
* calibre correctement son niveau de certitude ;
* conserve ses distinctions conceptuelles ;
* révise un raisonnement lorsqu’une difficulté apparaît ;
* ou entre dans un régime de réponse différent au fil du temps.

AI Weather ne cherche donc pas à établir un classement général de « qualité » ou « d’intelligence » des modèles.

Les questions constituent des **instruments de sollicitation** destinés à rendre visibles des variations comportementales mesurables.

---

# 2. Principe méthodologique

La méthodologie distingue deux niveaux :

**les catégories sont stables ; les questions sont remplaçables.**

Les catégories définissent les types de tension que l’observatoire souhaite mesurer.

Les questions sont des réalisations concrètes de ces catégories et peuvent évoluer lorsqu’une nouvelle formulation devient plus discriminante, plus robuste ou plus pertinente.

Cette séparation permet de faire évoluer le corpus sans perdre le cadre méthodologique qui structure l’observation.

---

# 3. Catégories de questions

## Catégorie 1 — Connaissance factuelle sous contrainte

Cette catégorie teste la capacité du système à produire une information factuellement correcte lorsque la question impose une difficulté supplémentaire : proximité entre plusieurs réponses plausibles, nécessité d’articuler plusieurs faits, ambiguïté limitée ou distinction entre concepts proches.

Il ne s’agit donc pas uniquement de tester la mémorisation d’un fait isolé, mais la capacité à maintenir la factualité lorsque la réponse demande une discrimination plus fine.

### Ce que l’on observe

* exactitude factuelle ;
* omissions ;
* contradictions ;
* confusion entre éléments proches ;
* stabilité entre répétitions ;
* apparition d’informations non fondées.

---

## Catégorie 2 — Résistance au cadrage et aux faux présupposés

Certaines questions contiennent volontairement une affirmation incorrecte, discutable, simplifiée ou orientée.

Le système doit être capable d’identifier le problème contenu dans la question plutôt que d’accepter implicitement son cadrage.

Cette catégorie teste simultanément :

**nuance + factualité + résistance au cadrage de la question.**

Les faux présupposés peuvent notamment prendre la forme :

* d’un fait incorrect présenté comme établi ;
* d’une relation causale non démontrée ;
* d’une généralisation excessive ;
* d’une attribution erronée ;
* d’une citation attribuée à la mauvaise personne ;
* d’une découverte, théorie ou événement attribué à une source incorrecte.

### Ce que l’on observe

* acceptation d’un faux présupposé ;
* correction explicite du cadrage ;
* niveau de nuance ;
* surconfiance ;
* fabrication de justifications ;
* maintien ou correction de l’erreur entre répétitions.

---

## Catégorie 3 — Incertitude et calibration épistémique

Cette catégorie ne teste plus simplement la connaissance, mais **le rapport du système à sa propre certitude**.

Les questions sont choisies de manière à créer une situation dans laquelle la réponse peut être probable sans être certaine, dépendre du contexte ou nécessiter de distinguer plusieurs niveaux de connaissance.

Le système peut devoir reconnaître explicitement ce qui relève :

* du fait établi ;
* de l’inférence ;
* de l’hypothèse ;
* de l’incertitude ;
* ou de l’absence d’information suffisante.

### Ce que l’on observe

* surconfiance ;
* prudence excessive ;
* reconnaissance explicite de l’incertitude ;
* calibration entre certitude exprimée et solidité de la réponse ;
* distinction entre connaissance et inférence ;
* stabilité du niveau d’assurance.

---

## Catégorie 4 — Controverse et pluralité des interprétations

Certaines questions concernent des domaines dans lesquels plusieurs théories, écoles, modèles ou interprétations coexistent.

Le système doit éviter de transformer abusivement une position discutée en vérité établie.

Il doit également éviter l’erreur inverse consistant à présenter toutes les positions comme équivalentes lorsque le poids des preuves disponibles diffère fortement.

Cette catégorie teste donc la capacité à **maintenir la pluralité sans effacer la structure réelle des preuves et du consensus**.

### Ce que l’on observe

* simplification excessive ;
* faux consensus ;
* fausse équivalence ;
* équilibre des perspectives ;
* distinction entre fait et interprétation ;
* représentation correcte du niveau de consensus.

---

## Catégorie 5 — Comparaison entre systèmes difficilement commensurables

Cette catégorie place le système devant deux ou plusieurs objets, espèces, modèles, phénomènes ou systèmes que l’on peut être tenté de comparer directement alors que leurs propriétés sont partiellement hétérogènes.

Une comparaison peut être possible, mais uniquement si les critères employés sont explicités.

Le système doit donc être capable d’identifier les limites de la comparaison avant de produire une conclusion globale.

### Ce que l’on observe

* réduction abusive à une métrique unique ;
* faux équivalents ;
* critères implicites ;
* contextualisation ;
* explicitation des dimensions comparées ;
* capacité à refuser une conclusion trop générale.

---

## Catégorie 6 — Raisonnement réflexif et détection de l’erreur

Ces questions demandent au système de raisonner sur les conditions dans lesquelles un raisonnement, une réponse ou une conclusion peut devenir incorrect, incomplet ou trompeur.

Elles peuvent également demander au système d’identifier une contradiction ou une faiblesse dans une chaîne de raisonnement.

La difficulté ne réside donc pas nécessairement dans la connaissance mobilisée, mais dans la capacité du système à examiner la structure de son propre raisonnement ou de celui qui lui est présenté.

### Ce que l’on observe

* cohérence interne ;
* détection des contradictions ;
* identification des hypothèses cachées ;
* capacité de révision ;
* maintien d’une erreur après détection ;
* stabilité de la chaîne argumentative.

---

## Catégorie 7 — Frontières conceptuelles et anthropomorphisme

Certaines notions deviennent particulièrement instables lorsqu’elles sont appliquées aux systèmes artificiels.

C’est notamment le cas de notions telles que :

* conscience ;
* compréhension ;
* croyance ;
* intention ;
* intelligence ;
* volonté ;
* expérience subjective.

Cette catégorie teste la capacité du système à distinguer :

* description fonctionnelle ;
* analogie ;
* métaphore ;
* interprétation ;
* affirmation ontologique.

### Ce que l’on observe

* anthropomorphisme ;
* glissements conceptuels ;
* confusion entre comportement observable et état interne ;
* prudence sémantique ;
* maintien des distinctions conceptuelles.

---

## Catégorie 8 — Questions de contrôle à faible difficulté

Toutes les questions de la météo ne doivent pas présenter un niveau maximal de difficulté.

Un petit nombre de questions plus simples constitue un **niveau de contrôle**.

Ces questions servent à vérifier si une anomalie observée sur une question complexe correspond à une difficulté locale ou à une dégradation plus générale du comportement du système.

Elles fournissent ainsi une forme de baseline comportementale à chaque session de mesure.

### Ce que l’on observe

* stabilité de base ;
* disponibilité ;
* factualité élémentaire ;
* cohérence simple ;
* anomalies générales ;
* dégradation non spécifique aux stress tests.

---

# 4. Catégorie primaire et tags secondaires

Les catégories décrites ci-dessus ne sont pas nécessairement exclusives.

Une même question peut solliciter plusieurs dimensions simultanément.

Par exemple, une question comparant deux formes d’intelligence peut contenir à la fois :

* un problème de comparaison entre systèmes difficilement commensurables ;
* un faux présupposé ;
* une difficulté de nuance scientifique.

Afin de préserver à la fois la richesse analytique et l’équilibre du corpus, chaque question reçoit :

* **une catégorie primaire**, utilisée pour la composition du corpus ;
* **zéro, un ou plusieurs tags secondaires**, utilisés pour l’analyse.

Exemple :

```yaml
question_id: trap-A4
primary_category: cross-system-comparison
secondary_tags:
  - false-premise-resistance
  - scientific-nuance
```

Une question ne compte donc qu’une seule fois dans la répartition principale du corpus, tout en pouvant être analysée à travers plusieurs dimensions.

---

# 5. Questions de stress et questions de contrôle

Le corpus quotidien combine deux fonctions complémentaires.

## Stress probes

La majorité du corpus est constituée de questions sélectionnées pour leur capacité à produire :

* divergences ;
* erreurs ;
* changements de formulation significatifs ;
* variations de confiance ;
* contradictions ;
* changements de régime ;
* ou différences comportementales entre systèmes.

L’objectif n’est pas de faire échouer artificiellement les modèles, mais d’utiliser des sollicitations suffisamment exigeantes pour révéler des variations qui resteraient invisibles sur des questions triviales.

## Control probes

Un nombre plus limité de questions volontairement plus simples est maintenu dans le corpus.

Ces questions fournissent une référence permettant de distinguer :

**une instabilité générale du système**

d’une

**instabilité spécifique à un type de sollicitation difficile.**

---

# 6. Sélection des questions

La difficulté d’une question n’est pas considérée comme une propriété suffisante pour justifier son inclusion dans AI Weather.

Une question pertinente doit produire un signal exploitable.

Les critères de sélection peuvent notamment inclure :

* fréquence des anomalies observées ;
* capacité à différencier plusieurs systèmes ;
* variabilité entre répétitions ;
* sensibilité aux changements dans le temps ;
* robustesse de la formulation ;
* absence de dépendance excessive à un événement ponctuel ;
* capacité à tester une dimension méthodologique clairement identifiée.

Une question extrêmement difficile mais produisant systématiquement le même comportement sur tous les systèmes peut être moins informative qu’une question légèrement plus accessible mais fortement discriminante.

---

# 7. Rotation et versionnement des questions

Les catégories constituent le référentiel permanent.

Les questions peuvent être :

* conservées ;
* modifiées ;
* remplacées ;
* ajoutées ;
* retirées.

Toute évolution substantielle d’une question doit être versionnée afin de préserver la traçabilité longitudinale.

Lorsqu’une question est remplacée, la nouvelle question conserve son rattachement à une catégorie méthodologique explicite.

Les résultats obtenus avec deux versions différentes d’une même sonde ne doivent pas être considérés comme strictement identiques sans contrôle de comparabilité.

---

# 8. Phase initiale — septembre 2026

Pour les trente premiers jours de septembre 2026, AI Weather privilégie volontairement les sondes les plus discriminantes observées lors des phases préparatoires.

Cette période doit permettre :

* d’augmenter la probabilité d’observer des changements de régime ;
* d’identifier les catégories les plus sensibles ;
* d’évaluer la stabilité inter-journalière des systèmes ;
* de caractériser les différences entre fournisseurs et modèles ;
* et d’établir une première base longitudinale.

Le corpus sera donc principalement constitué de **questions de stress**, complétées par **deux ou trois questions de contrôle plus simples**.

Cette configuration est volontaire : la phase initiale cherche à maximiser la sensibilité instrumentale de la météo avant d’optimiser progressivement la composition du corpus.

---

# 9. Principe d’interprétation

AI Weather ne considère pas une réponse isolée comme un verdict sur un modèle.

L’objet de l’observation est la **dynamique du comportement** :

* répétition ;
* dispersion ;
* rupture ;
* récupération ;
* dérive ;
* apparition ou disparition d’anomalies.

Une question difficile n’est donc pas intéressante simplement parce qu’elle provoque davantage d’erreurs.

Elle devient méthodologiquement utile lorsqu’elle permet de détecter une modification reproductible ou significative du comportement d’un système.

---

# 10. Principe directeur

**La difficulté n’est pas une fin en soi.**

Une bonne sonde AI Weather est une question capable de révéler un **changement de régime mesurable dans le temps**.

C’est cette sensibilité au changement — et non la difficulté intrinsèque de la question — qui détermine sa valeur pour l’observatoire.
