# AI Weather V2 — Résultats expérience shadow Wilson N=7 vs N=14

**Statut** : arme rétrospective (N=7, coût zéro) **complète et réelle**. Arme live (N=14, appels API réels payants) **non lancée** — voir section « Ce qui reste à décider avant tout appel réel ». Aucun runner de production modifié, aucune capsule réécrite, aucun fichier public touché, aucun seuil de production changé.

---

## 0. Ce qui a été construit et exécuté

| Élément | Statut |
|---|---|
| `AI_WEATHER_RUNNER/shadow/wilson_n14_experiment/wilson_config.json` | Créé |
| `AI_WEATHER_RUNNER/shadow/wilson_n14_experiment/compute_wilson_retrospective.ps1` | Créé, exécuté (arme N=7, coût zéro) |
| `AI_WEATHER_RUNNER/shadow/wilson_n14_experiment/tests/test_wilson.ps1` | Créé, **19/19 tests passés** au dernier run |
| `AI_WEATHER_RUNNER/shadow/wilson_n14_experiment/output/*.json` | Sortie shadow, isolée, jamais lue par un consommateur public |
| Script de collecte live N=14 (`fetch_n14_pilot.ps1`) | **Non créé/non lancé** — dépend de la décision de confiance ci-dessous, voir fin de document |

**Confirmation d'isolation** : cette expérience réutilise uniquement les fonctions de lecture déjà validées en Phase 1 (`Read-HistoryDay`, `Get-AvailableDates`) et écrit exclusivement sous `AI_WEATHER_RUNNER/shadow/wilson_n14_experiment/`. `AI_WEATHER_RUNNER/` étant intégralement gitignoré, rien de ceci n'apparaît dans `git status`/`git diff`. Contrôle de hachage SHA-256 sur `weather.json`, `data/current.json`, `index.html`, `scripts/weather-data.js`, capsule du 16/09 : **identiques avant/après** (Test 4 de la suite, passé).

**Bugs trouvés et corrigés pendant la construction** (transparence méthodologique) :
- Erreur PowerShell classique `[math]::Max(0, $double)` → sélectionne l'overload entier et arrondit — corrigé en `[math]::Max(0.0, ...)`.
- Collision de nom de variable `$RepoRoot`/`$OutputDir` par dot-sourcing (même bug de casse trouvé une fois en Phase 1) — corrigé par sauvegarde/restauration explicite.
- `$PSScriptRoot` observé vide dans cet environnement quand ce script précis est la cible directe de `powershell -File` — corrigé par un repli sur `$MyInvocation.MyCommand.Path`.

---

## 1. Comparaison des quatre configurations — état actuel

| Configuration | Statut | Coût |
|---|---|---|
| ① Score actuel N=7 | Disponible (données déjà publiées) | 0 (déjà en production) |
| ② Wilson N=7 | **Calculé, réel, complet** (cette section) | 0 (recalcul sur données existantes) |
| ③ Score actuel N=14 | Non disponible — nécessite des répétitions 8-14 réelles qui n'existent pas | À venir |
| ④ Wilson N=14 | Non disponible, même raison | À venir |

**Seule la comparaison ① vs ② est donc rapportée ici avec des données réelles complètes.** Les comparaisons impliquant N=14 (③, ④) sont projetées théoriquement où c'est honnête de le faire, jamais inventées comme si elles étaient mesurées.

---

## 2. Faux positifs évités (① vs ②)

| Système | Score actuel (Phase 1) | Wilson N=7 (90% confiance) |
|---|---|---|
| OpenAI | `deviation_index` allant jusqu'à **-290 000** sur les jours à 6/7 (MAD=0) | Jamais d'alerte (`attention_wilson` : 0 jour sur 26) — le jour à 6/7 reste dans la bande normale, comme il se doit |
| Anthropic | MAD=0, un futur écart isolé produirait le même artefact numérique | 0 jour d'alerte sur 26 (aucun FLAG dans toute la fenêtre) |
| Qwen | Même profil qu'OpenAI | 0 jour d'alerte sur 26 |
| Meta | Rupture réelle du 27/08 correctement vue, mais MAD=0 le reste du temps | 0 jour d'alerte — cohérent, la rupture Meta était isolée (1 jour), donc ni le système actuel ni Wilson ne l'auraient élevée en état persistant |

**Résultat confirmé** : les 4 systèmes signalés comme faussement instables par le calcul de `deviation_index` (MAD=0) restent silencieux sous Wilson, sans exception, aux deux niveaux de confiance testés (80 % et 90 %).

---

## 3. Ruptures conservées / perdues — résultat le plus important de cette expérience

| Système | État actuel (Phase 1) | Wilson N=7 à 90 % | Wilson N=7 à 80 % |
|---|---|---|---|
| DeepSeek | `attention_accrue` | **`attention_wilson` confirmé** (3 jours + retour) | Identique |
| Google | `standard` (mais signal bas persistant) | **`attention_wilson` confirmé** (3 jours + retour) | Identique |
| Moonshot | `attention_accrue` | **`attention_wilson` confirmé** (1 jour) | Confirmé plus tôt/plus souvent (6 jours, 2 épisodes) |
| Infomaniak | `attention_accrue` | **`attention_wilson` confirmé** (6 jours) | Confirmé plus largement (11 jours, 2 épisodes) |
| **Mistral** | `attention_accrue` (rupture déjà validée en Phase 1) | **PERDUE — 0 jour d'alerte** | **Récupérée — 3 jours + retour** |
| Cohere | `standard` (jamais confirmé, bruit) | Confirmé (3 jours + retour) — **nouveau signal, pas dans le système actuel** | Confirmé plus largement (6 jours, 2 épisodes) |
| Perplexity | `attention_critique` (probable artefact MAD=0-par-mode, cf. document précédent) | 0 jour d'alerte à 90 % | Signal modéré à 80 % (3 jours + retour) — à interpréter avec prudence |

**Constat central, obtenu par un test statistique correct (test de différence de deux proportions sur le streak de jours consécutifs de même direction, pas un simple chevauchement d'intervalles — voir méthode ci-dessous) : à 90 % de confiance, la rupture Mistral déjà confirmée en Phase 1 n'atteint PAS la signification statistique**, même en poolant l'intégralité des 5 jours de l'épisode (z maximal observé ≈ -1,48, seuil 1,645). **À 80 % de confiance, elle est retrouvée dès le 3ᵉ jour de l'épisode.**

Ce n'est ni un échec de Wilson ni un problème caché : c'est une conséquence directe et honnête de la faible puissance statistique disponible à N=7 pour une déviation de magnitude modérée (57-71 % contre une baseline à 76,5 %). **C'est exactement le type de résultat que cette expérience devait produire pour trancher objectivement, plutôt que de le supposer.**

**Méthode de décision effectivement utilisée** (corrigée en cours d'expérience, documenté par honnêteté) : la première version testait le chevauchement brut des deux intervalles de confiance — un test statistiquement connu pour être trop conservateur — puis un test de proportions jour-par-jour, encore insuffisant à N=7. La version retenue **poole les jours consécutifs de même direction (au-dessus ou en dessous de la baseline) et teste le streak poolé** contre la baseline — c'est ce qui a permis de retrouver la sensibilité nécessaire, au prix d'un ajustement du niveau de confiance. Un garde-fou à sens unique a aussi dû être ajouté : sans lui, un jour parfait (7/7) contre une baseline qui contient elle-même 2 creux connus (donc <100 %) déclenchait une fausse alerte « dans le sens du mieux », un artefact du test de Wald pour des proportions à p=1 exactement.

---

## 4. Différences N=7 vs N=14

**Non mesurable empiriquement à ce stade** (arme live non lancée). Projection théorique fondée sur les données réelles ci-dessus :

- La largeur moyenne de l'IC90 à N=7 mesurée sur les 4 systèmes pilotes est de **44 à 46 points** (Mistral, Cohere, Perplexity) et de **28 points** pour OpenAI (quasi-certain, donc plus étroit malgré N identique). Une réduction théorique de ≈29 % à N=14 ramènerait ces largeurs à environ **31-33 points** — encore large, mais suffisant, selon le calcul refait avec les données réelles de Mistral, pour probablement faire passer le z du streak de rupture au-dessus de 1,645 sans avoir à assouplir le niveau de confiance à 80 %.
- C'est une projection, pas une mesure — à confirmer par l'arme live.

---

## 5. Largeur moyenne des intervalles (mesurée, réelle)

| Système | Largeur moyenne IC90 à N=7 | Largeur min | Largeur max |
|---|---|---|---|
| OpenAI | 28,4 points | 27,9 | 42,0 |
| Mistral | 44,6 points | 27,9 | 52,4 |
| Cohere | 46,1 points | 27,9 | 55,8 |
| Perplexity | 45,1 points | 27,9 | 52,4 |

Le plancher commun (~27,9 points, atteint à k=0 ou k=7) illustre la limite structurelle de N=7 déjà documentée dans l'étude de résolution précédente : même dans le meilleur des cas (proportion extrême, variance minimale), l'intervalle ne descend jamais sous ~28 points de large.

---

## 6. Cas où N=14 changerait réellement l'interprétation

Ne peut être confirmé empiriquement sans l'arme live. Sur la seule base de la projection du §4, le cas le plus probable est **Mistral à 90 % de confiance** : c'est le cas pilote où le passage de N=7 à N=14 permettrait, en théorie, de conserver le niveau de confiance le plus strict (90 %) tout en retrouvant la détection — évitant d'avoir à choisir entre « rater Mistral » et « assouplir le seuil pour tout le monde » (ce qui, au §3, fait aussi apparaître plus de signal chez Cohere/Moonshot/Infomaniak, pas seulement chez Mistral — un compromis qui mériterait sa propre discussion).

---

## 7. Coût supplémentaire

Repris et confirmé de l'étude de résolution précédente, aucune nouvelle donnée inventée :

| Mesure | Valeur |
|---|---|
| Pilote proposé | 4 systèmes (Mistral, Cohere, OpenAI, Perplexity) |
| Répétitions supplémentaires par système et par jour (8-14) | 7 |
| Coût du pilote sur 14 jours | 4 × 7 × 14 = **392 appels API réels et payants** |
| Latence supplémentaire par système et par jour | de +110 s (Moonshot, hors pilote) à +577 s (Perplexity), mesurée réellement dans l'étude précédente |
| Crédentiels nécessaires | `AI_WEATHER_RUNNER/secrets.weather.xml` (confirmé présent, contenu non lu, non affiché) |
| Accès réseau sortant | Confirmé disponible dans cette session (test direct vers l'API Mistral, HTTP 401 reçu — authentification refusée sans clé, réseau fonctionnel) |

**Coûts monétaires exacts par fournisseur** : non connus depuis ce dépôt, non inventés.

---

## 8. Recommandation finale

**`NEED_MORE_DATA`**

Justification, point par point :
- `KEEP_N7_WILSON` est prématuré : à 90 % de confiance, Wilson à N=7 **perd** la rupture Mistral déjà confirmée — un recul net sur exactement le cas que la consigne demandait explicitement de préserver.
- `ADOPT_N14_WILSON` est prématuré à l'inverse : aucune donnée réelle à N=14 n'existe encore pour confirmer que le gain théorique projeté (§4/§6) se matérialise.
- `KEEP_CURRENT` est écarté : le score actuel produit des artefacts numériques démontrés (`deviation_index` à -290 000) que Wilson élimine sans exception aux deux niveaux de confiance testés — un recul serait injustifié au vu de ce résultat.
- **`NEED_MORE_DATA`** reflète honnêtement l'état réel : le zéro-coût (N=7) a déjà livré un résultat décisif — le choix du niveau de confiance (80 % vs 90 %) change matériellement quel système est repéré, et ce choix ne peut être tranché sans savoir si N=14 permet de garder 90 % tout en retrouvant Mistral. C'est précisément la question que l'arme live doit encore trancher.

## Ce qui reste à décider avant tout appel réel (l'arme N=14 n'a pas été lancée)

1. **Niveau de confiance à tester en priorité** : 90 % (plus strict, perd Mistral à N=7) ou 80 % (retrouve Mistral, mais élargit aussi le signal chez Cohere/Moonshot/Infomaniak) — ou les deux en parallèle, au prix du double d'analyse (pas de coût API supplémentaire, la config peut être recalculée à volonté sur les mêmes 14 répétitions une fois collectées).
2. **Confirmation explicite du lancement de la collecte live** : 392 appels API réels, payants, vers Mistral/Cohere/OpenAI/Perplexity, en utilisant les identifiants déjà présents dans `AI_WEATHER_RUNNER/secrets.weather.xml`. Ceci n'a pas été fait de façon autonome dans ce tour — c'est une dépense réelle avec des identifiants live, distincte de tout ce qui a été fait jusqu'ici (qui n'a coûté ni argent ni requis de credentials).
3. **Mécanique d'exécution sur 14 jours** : cette session ne peut pas attendre 14 jours civils pour produire une collecte continue. Deux options à trancher : (a) une nouvelle tâche planifiée Windows dédiée à ce pilote (distincte des tâches Measure@7h/Release@14h existantes, elle aussi à valider séparément), ou (b) une réinvocation manuelle quotidienne par vos soins pendant 14 jours. Aucune des deux n'a été mise en place.

**Aucun appel réel n'a été effectué. Aucune bascule en production. Arrêt du tour ici, en attente de votre décision sur les 3 points ci-dessus.**
