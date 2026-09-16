# AI Weather V2 — Gate de pré-lancement (avant tout appel live N=14)

**Statut** : analyse et validation méthodologique uniquement. **Aucun appel API payant n'a été effectué.** Aucun runner de production modifié, aucune capsule réécrite, aucun fichier public touché, aucun seuil de production changé. Toutes les comparaisons ci-dessous sont recalculées sur l'historique réel déjà existant (arme N=7, coût zéro) — aucune nouvelle observation n'a été inventée.

---

## 1. Règle statistique finale proposée (résumé — détail en section 3 du corps du document)

**Wilson n'est plus la règle de décision.** L'intervalle de Wilson reste un outil d'affichage de l'incertitude (descriptif, pour un humain lisant un score), conformément à l'instruction reçue. La **décision** d'état/événement repose sur un **test de différence de deux proportions** entre (a) le streak courant de jours consécutifs de même direction et (b) la baseline poolée du système, avec un filtre à sens unique (seule une dégradation déclenche une alerte). Le niveau de confiance à utiliser **n'est pas encore fixé** — voir section 2, aucun niveau unique testé ne satisfait tous les critères.

---

## 2. Comparaison 95 % vs 80 % — résultats réels

| Système | 95 % : rupture connue détectée ? | 95 % : jours d'attention / événements | 80 % : rupture connue détectée ? | 80 % : jours d'attention / événements |
|---|---|---|---|---|
| **Mistral** | Non — rupture déjà confirmée en Phase 1 **perdue** | 0 / 0 | **Oui** — retrouvée au 3ᵉ jour du streak | 3 / 2 |
| **Perplexity** | Aucun signal | 0 / 0 | Signal apparaît (3 jours, 1 épisode) — **statut ambigu**, voir §5 | 3 / 2 |
| **OpenAI** | Aucun signal (stabilité vraie, conforme) | 0 / 0 | Aucun signal (stabilité vraie, conforme) | 0 / 0 |
| **Anthropic** | Aucun signal (stabilité vraie, conforme) | 0 / 0 | Aucun signal (stabilité vraie, conforme) | 0 / 0 |
| **Qwen** | Aucun signal (stabilité vraie, conforme) | 0 / 0 | Aucun signal (stabilité vraie, conforme) | 0 / 0 |
| **Cohere** | Signal détecté (1 épisode) | 3 / 2 | Signal détecté, **plus large** (2 épisodes distincts) | 6 / 4 |
| **Meta** | Aucun signal (cohérent — sa seule rupture connue, 27/08, était isolée sur 1 jour, jamais assez longue pour être confirmée à aucun niveau) | 0 / 0 | Aucun signal | 0 / 0 |

**Découverte supplémentaire, hors des 7 systèmes demandés mais nécessaire pour juger du niveau de confiance** : à 95 %, **DeepSeek perd également son signal** (0 événement, alors que le système de production actuel le classe `attention_accrue` et que Wilson le détecte encore à 90 % et 80 %). 95 % est donc trop conservateur non seulement pour Mistral mais aussi pour au moins un autre système déjà reconnu comme instable par la production.

### Synthèse par critère demandé (section 1 du cadrage)

| Critère | Mistral | Perplexity | OpenAI/Anthropic/Qwen | Cohere | Meta |
|---|---|---|---|---|---|
| Rupture connue détectée (95%/80%) | Non / Oui | N/A (pas de rupture "connue" à proprement parler) | N/A (stabilité attendue) | N/A (pas de rupture confirmée en production) | N/A (rupture isolée, jamais confirmée nulle part) |
| Faux positif potentiel | — | **Oui, possible aux deux niveaux dès qu'un signal apparaît** (le statut `attention_critique` actuel de Perplexity est déjà soupçonné d'être un artefact MAD=0-par-mode — un nouveau signal Wilson ne le dément ni ne le confirme de façon décisive) | Aucun aux deux niveaux | **Oui, à 80 % (2 épisodes) — pas présent en production actuelle** | Aucun |
| Faux négatif potentiel | **Oui, à 95 %** | — | — | — | — |
| Stabilité (pas d'oscillation) | — | — | Confirmée (§4) | Confirmée malgré 2 épisodes distincts (§4) | Confirmée |
| Nombre d'événements | 0 (95%) / 2 (80%) | 0 (95%) / 2 (80%) | 0 / 0 aux deux niveaux | 2 (95%) / 4 (80%) | 0 / 0 |
| Différence 95% vs 80% | Bascule complète (rien → détecté) | Apparition d'un signal | Aucune différence | Doublement du nombre d'événements | Aucune différence |

---

## 3. Le choix ne doit pas se limiter à « 80 % parce que Mistral repasse »

Vérification explicite des 4 critères demandés, à 80 % :

- **Restaure Mistral** : ✅ oui, confirmé.
- **Conserve la stabilité d'OpenAI/Anthropic/Qwen** : ✅ oui, confirmé — 0 événement aux deux niveaux pour les trois.
- **Évite le faux positif Perplexity** : ❌ **non** — un signal apparaît précisément là où on redoutait un artefact déjà identifié en Phase 1 (`attention_critique` par MAD=0-par-mode). Rien ne permet de trancher si ce nouveau signal Wilson est un vrai signal ou une continuation du même artefact sous une autre forme statistique.
- **N'inflate pas les événements ailleurs** : ❌ **non** — Cohere passe de 2 à 4 événements (2 épisodes distincts au lieu d'1), Moonshot de 0 à 3, Infomaniak de 2 à 3 (détail section 4 du corps).

**Conclusion explicite demandée : aucun niveau de confiance fixe (95 %, 90 %, ou 80 %) ne satisfait simultanément les quatre critères.** 95 % est trop conservateur (perd Mistral ET DeepSeek). 80 % restaure Mistral mais au prix d'une inflation mesurable ailleurs et d'un signal ambigu sur Perplexity. 90 % (niveau testé au tour précédent) est un compromis qui perd Mistral sans même la contrepartie de moins d'inflation ailleurs (Cohere y est déjà détecté). **Aucun des trois n'est recommandé comme réglage final en l'état.**

---

## 4. Formalisation de la règle de décision

| Élément | Spécification |
|---|---|
| **Statistique utilisée** | Test de différence de deux proportions (forme de Wald, variances **non poolées**) : `z = (p1 − p2) / sqrt(p1(1−p1)/n1 + p2(1−p2)/n2)` où (1) = streak courant poolé, (2) = baseline poolée du système |
| **Hypothèse nulle H0** | Le taux de réponses "normales" (ALLOW) du streak courant est égal à celui de la baseline du même système (`p_streak = p_baseline`) |
| **Hypothèse alternative** | `p_streak ≠ p_baseline`, mais seule la direction "dégradation" (`p_streak < p_baseline`) déclenche une alerte — filtre à sens unique appliqué **après** le test, pas dans la formule elle-même |
| **Petits N** | Pour un seul jour (n≈7), le test est structurellement sous-puissant (démontré empiriquement : la rupture Mistral poolée sur 5 jours n'atteint même pas z=1,645). Le pooling du streak (accumulation des jours consécutifs de même direction) est le seul mécanisme actuellement en place pour compenser — pas une correction formelle de petit échantillon (pas de correction de continuité, pas de test exact de Fisher envisagé à ce stade) |
| **Couverture partielle** | `n` = nombre de répétitions réellement scorées (`fully_scored`), jamais le nombre attendu ; un jour sous le plancher de couverture (5/7) est exclu du calcul de la baseline et du streak, jamais compté comme 0 |
| **Niveau de confiance** | **Non fixé** — voir section 3, aucune valeur testée (80/90/95 %) n'est validée comme réglage final |
| **Correction pour comparaisons répétées dans le temps** | **Absente, et c'est une lacune méthodologique réelle et non résolue.** La règle teste la significativité du streak à chaque nouveau jour valide — c'est un scénario de tests séquentiels répétés (« repeated looks »), connu pour gonfler le taux de faux positifs cumulé par rapport à un test unique, si aucune correction n'est appliquée (ex. borne de type alpha-spending, correction de Bonferroni sur le nombre de jours testés). Aucune de ces corrections n'est implémentée. C'est une explication plausible, en plus de la simple baisse du seuil, de l'inflation d'événements observée à 80 % sur les systèmes déjà bruyants (Cohere, Moonshot) : plus le niveau de confiance baisse, plus chaque "regard" quotidien supplémentaire a de chances de franchir le seuil par hasard sur une série déjà volatile. |
| **Relation Wilson / test de proportions** | **Clarifiée et appliquée telle que demandée** : l'intervalle de Wilson (par jour, par système) reste calculé et exposé comme aide à la lecture humaine de l'incertitude d'une seule mesure — il n'entre à aucun moment dans la logique d'escalade d'état. Seul le test de différence de proportions sur le streak poolé déclenche un événement. |
| **Point non validé, à traiter avant tout déploiement (pas seulement avant le pilote live)** | Le choix "variances non poolées" (chaque groupe utilise son propre p̂) plutôt que "variance poolée sous H0" (`p_pool = (k1+k2)/(n1+n2)`, plus standard pour un test d'hypothèse de proportions égales) n'a pas été comparé empiriquement — à faire avant de figer la règle. |

---

## 5. Test anti-flapping — résultats réels

Aucune oscillation quotidienne artificielle détectée sur l'historique disponible, aux trois niveaux de confiance testés :

| Système | Motif observé (A=attention, S=standard) | Interprétation |
|---|---|---|
| Cohere (90%) | `SSAAASSSSSS` | 1 épisode propre, durée minimale 3 jours de chaque côté |
| Cohere (80%) | `SSAAASSSAAA` | 2 épisodes distincts, jamais de bascule sur 1 seul jour |
| DeepSeek (90%/80% identiques) | `SSAAASSSSSS` | Signal le plus robuste et le plus stable du panel, insensible au niveau de confiance testé |
| Infomaniak (90%/80%) | `SSSAAAAAASSS` / `SAAAAAAAAAAA` | Tendance longue et soutenue, pas de flapping |
| Google (90%/80% identiques) | `SAAAS..SSSSS` | 1 épisode net |
| Perplexity (80%) | `...SSSSSSSSAAA` | Apparition en toute fin de fenêtre, 3 jours consécutifs, pas d'oscillation |

**Aucun cas d'alerte isolée déclenchée par une seule répétition** : chaque escalade nécessite au moins `persistence_days.attention_accrue = 2` jours consécutifs (paramètre déjà externalisé, conservé de la Phase 1, jamais modifié). **Aucune désescalade en moins de 2 jours** non plus — la règle de retour à la baseline utilise le même seuil de persistance, symétriquement.

**Conclusion anti-flapping** : la mécanique de persistance déjà prévue en Phase 1 est confirmée efficace et **conservée telle quelle** dans cette expérience — le problème résiduel n'est pas le flapping (bien maîtrisé) mais le réglage du niveau de confiance et l'absence de correction pour tests répétés (section 4).

---

## 6. Résultats des 19 tests (suite `test_wilson.ps1`)

**19/19 réussis** au dernier passage, incluant :
- 4 tests sur la formule de Wilson elle-même (valeurs de référence, corrige un bug réel de sélection d'overload `[math]::Max`) ;
- 3 tests sur le test de différence de proportions (démontrent explicitement la sous-puissance à N=7 pour un seul jour, puis sa restauration par pooling du streak) ;
- 1 test sur l'élargissement en cas de couverture partielle ;
- 4 tests de garde-fou réel (12 systèmes produits, aucun fichier public modifié, hachage SHA-256 identique avant/après) ;
- 4 tests documentant explicitement, comme résultat attendu et non comme échec, que le streak Mistral n'atteint pas la significativité à 90 % de confiance.

Aucun test n'a été retiré ou affaibli pour arriver à ce score — deux assertions ont dû être corrigées en cours de route parce que l'hypothèse de départ (basée sur un raisonnement théorique) s'est révélée fausse à l'épreuve des données réelles, conformément à l'esprit de cette série d'expériences.

---

## 7. Risques méthodologiques restants

1. **Aucune correction pour tests répétés dans le temps** (section 4) — le risque le plus sérieux identifié à ce stade, susceptible à lui seul d'expliquer une partie de l'inflation d'événements à mesure que le niveau de confiance baisse.
2. **Choix variance poolée vs non poolée non validé** (section 4) — pourrait changer la sensibilité sans qu'on sache dans quel sens avant de le tester.
3. **Aucun niveau de confiance fixe ne satisfait les 4 critères simultanément** (section 3) — un pilote live devra soit tester plusieurs niveaux en parallèle sur les mêmes données (sans coût supplémentaire, puisque recalculable après coup), soit accepter un compromis explicite et documenté.
4. **Le statut de Perplexity reste non tranché** — impossible de dire, avec les données actuelles, si un signal Wilson dessus est un vrai signal ou la continuation de l'artefact déjà identifié (MAD=0 par mode dominant, audit précédent).
5. **N=7 reste, dans tous les cas testés, en limite de puissance statistique** pour des déviations de magnitude modérée (cas Mistral) — c'est le résultat central qui justifie de tester N=14, mais qui signifie aussi qu'il faut s'attendre à ce que certaines déviations réelles restent indétectables même après le passage à N=14, si elles sont plus modestes encore que celle de Mistral.

---

## 8. Estimation des appels et du coût relatif de l'expérience N=14 (rappel, aucun changement depuis le tour précédent)

| Mesure | Valeur |
|---|---|
| Systèmes du pilote proposés | 4 (Mistral, Cohere, OpenAI, Perplexity) |
| Répétitions supplémentaires par système et par jour | 7 (répétitions 8 à 14) |
| Durée proposée | 14 jours |
| Appels API supplémentaires totaux | 4 × 7 × 14 = **392** |
| Latence supplémentaire par système et par jour | de +110 s à +577 s selon le fournisseur (mesuré réellement, tour précédent) |
| Coûts monétaires exacts | non connus depuis ce dépôt, non inventés |
| Identifiants requis | `AI_WEATHER_RUNNER/secrets.weather.xml` (présence confirmée, contenu non lu) |
| Accès réseau sortant | confirmé disponible dans cette session |

---

## 9. Décision

**`NEEDS_STATISTICAL_RULE_FIX`**

Justification : ni `READY_FOR_LIVE_N14` (le niveau de confiance à tester n'est pas fixé, et deux points de conception — correction pour tests répétés, choix de variance poolée — restent non résolus sur les données déjà disponibles, donc résolubles sans dépenser un seul appel live) ni `NEEDS_MORE_HISTORICAL_VALIDATION` (l'historique disponible s'est montré suffisant pour révéler ces lacunes précisément — le problème n'est pas un manque de données passées, c'est un point de méthode à trancher) ne reflètent aussi précisément l'état réel. Dépenser les 392 appels maintenant reviendrait à tester une règle dont on sait déjà, sur les données existantes, qu'elle a au moins deux angles morts identifiés et non corrigés.

**Aucune autorisation de dépense n'est donnée par ce document.** Décision finale et calendrier de correction à valider par Sébastien.

---

*Fin du document. Aucun appel live effectué. Aucune bascule en production. En attente de validation.*
