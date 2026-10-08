# AI Weather — Known Fixes (ne jamais régresser)

> **Avant toute modification du pipeline AI Weather** (scripts PowerShell,
> agrégation, widgets, planification), **relire cette liste intégralement.**
> **Après toute modification**, vérifier qu'aucun des points ci-dessous n'a
> régressé, et **ajouter une entrée** si un nouveau comportement doit être
> figé.

Check-list à relire **avant tout changement** touchant `AI_WEATHER_RUNNER/`,
`index.html`, `i18n/`, `data/`, `weather.json` ou les tâches planifiées.
Chaque entrée décrit un comportement qui a déjà cassé une fois et le
comportement attendu qui doit rester vrai en permanence. Voir aussi
`AI_WEATHER_PIPELINE_AUDIT.md` (audit ponctuel, daté) et `TODO_NEXT.md`
(travail à venir) — ce fichier-ci est le seul des trois qui sert de
check-list figée.

## Script compagnon : `AI_WEATHER_RUNNER/check_known_fixes.ps1`

Certains points ci-dessous sont vérifiables mécaniquement — ce script les
teste et affiche `[OK]`/`[FAIL]`/`[SKIP]`/`[MANUAL]` par point numéroté.
**Statut actuel (2026-09-01) : non-bloquant.** Il est appelé en info-only
au début de `release_ai_weather.ps1` et après le coverage gate dans
`run_full_pipeline.ps1` (repérer `TODO(blocking)` dans ces deux fichiers
pour le rendre bloquant plus tard).

```
.\AI_WEATHER_RUNNER\check_known_fixes.ps1 -Date "2026-09-01"
```

| # | Point | Vérifiable auto ? |
|---|---|---|
| 1 | Label "Mesuré le" en UTC de mesure | Partiel — code + cohérence des dates |
| 2 | Légende judgment-word prefix | Partiel — code + présence de la clé i18n |
| 3 | Encodage UTF-8 (pas de mojibake) | Oui |
| 4 | `question_translations` : 12 langues, non vides, ≠ EN | Oui |
| 5 | Budget/timeout de l'étape de traduction | Oui (présence du garde-fou dans le code) |
| 6 | Agrégation avant push ; horaire Measure/Release | Partiel — code, + tâches planifiées (cette machine seulement) |
| 7 | Runner Moonshot/Kimi lit le panel généré | Oui |
| 8 | CTA quiz → controltowerai.io | Oui |
| 12 | Volume d'observation : source unique datée, pas de littéral | Oui — `tests/test_protocol_volume.ps1` |

**Jamais automatisable (reste manuel)** : qualité/exactitude des
traductions, rendu visuel réel dans un navigateur (RTL, mise en page),
confirmation que les tâches planifiées se sont *effectivement*
déclenchées à l'heure (à relire dans `AI_WEATHER_RUNNER\logs`).

---

## 1. Label "Mesuré le" — doit utiliser l'heure de mesure, pas l'heure d'agrégation
**Commit** : `e22de43`
Le header affiche `panel_summary.last_measurement_at` (horodatage UTC réel de
la campagne de mesure du matin), **jamais** `generated_at` (horodatage de
l'agrégation/publication, qui peut être bien plus tardif — cf. §5). Voir
`index.html` → `renderHeader()`.

## 2. Légende judgment-word + affichage de la date mesurée
**Commit** : `2a7c928`
Le préfixe de légende (`legend.prefix`, ex. "Judgment"/"Jugement") doit
précéder chaque libellé de légende (Normal/Watch/Warning/Critical), et la
date affichée dans le header doit rester celle de la mesure (voir §1), pas
une date recalculée côté client.

## 3. Encodage des accents — jamais de mojibake dans les données publiées
**Commit** : `903ad07` (mojibake initial) + protection ajoutée dans
`Get-DailyQuestionTranslations` (aggregate_and_publish_weather.ps1)
`Invoke-WebRequest`/`Invoke-RestMethod` sous Windows PowerShell 5.1 devine
l'encodage de la réponse HTTP à partir du header `Content-Type` et retombe
sur ISO-8859-1 quand aucun charset n'est déclaré — exactement le cas de
l'API Anthropic (`application/json` sans charset). Toute lecture de réponse
API doit décoder les octets bruts (`RawContentStream`/`RawContentBytes`) en
UTF-8 explicitement, jamais laisser PowerShell deviner. Symptôme si ça
régresse : des caractères accentués/non-ASCII transformés en séquences du
type `Ã©`, `Ã¨` dans `data/*.json`.

## 4. Traduction FR/EN/etc de la question du jour — doit être présente et complète
**Régression** : 2026-09-01 (ce fix) — `probe_contract.daily.question_translations`
publié **vide** (`{}`) alors que le code de génération était intact.
**Root cause** : pas un bug de code. `ANTHROPIC_API_KEY` n'est chargé qu'en
scope **Process** par `launch_ai_weather.ps1` (lecture de
`secrets.weather.xml`, `[Environment]::SetEnvironmentVariable(..., "Process")`)
— il n'est persistant nulle part (ni `User`, ni `Machine`). Le
04-09-2026 au matin, l'étape de traduction a bloqué ~8h (voir §5). La
récupération manuelle (relance de `aggregate_and_publish_weather.ps1` seul,
hors de la chaîne `run_full_pipeline.ps1 → launch_ai_weather.ps1`) s'est donc
faite dans une session sans la clé — `Get-DailyQuestionTranslations` a fait
exactement ce qu'elle est censée faire dans ce cas (best-effort, ne bloque
jamais le pipeline) : elle a renvoyé un dictionnaire vide avec un simple
`Write-Warning`, et ce vide a été publié tel quel.
**Comportement attendu** : `question_translations` doit contenir les 12
langues cibles (`ar, de, es, fr, hi, it, ja, ko, nl, pt, ru, zh` —
voir `$DAILY_QUESTION_TRANSLATION_LANGS`) à chaque publication. Le
front-end (`index.html` → `renderWallIntro()`) retombe sur l'anglais quand
une langue manque — **ce fallback est voulu et ne doit pas être supprimé**,
mais il ne doit se déclencher que pour une langue vraiment absente de la
réponse API, jamais parce que la clé API n'était pas dans l'environnement
du processus qui a lancé l'agrégation.
**Ne plus jamais régresser** : ne relancer `aggregate_and_publish_weather.ps1`
en dehors de `run_full_pipeline.ps1` (ou sans avoir vérifié
`$env:ANTHROPIC_API_KEY` dans la session courante) lors d'une récupération
manuelle après incident.

## 5. Le pas de traduction ne doit jamais pouvoir bloquer le pipeline
**Incident** : 2026-09-01 — un appel `Invoke-WebRequest` vers
`api.anthropic.com` sans timeout est resté bloqué 8h+ (connexion TCP
coincée en CloseWait), ce qui a bloqué toute l'agrégation du matin et fait
rater la publication de 14h.
**Fix** : `Get-DailyQuestionTranslations` a maintenant un budget de temps
global de 90s pour l'ensemble des langues (indépendant du `-TimeoutSec 20`
de chaque requête individuelle), et est strictement best-effort — toute
erreur réseau/API sur une langue est catchée et journalisée (`Write-Warning`),
jamais propagée. Ce step ne doit **jamais** pouvoir faire planter ou
suspendre indéfiniment `run_full_pipeline.ps1`.

## 6. Horaire Measure 7h / Release 14h Paris, agrégation avant le push
**Changement** : 2026-08-31/09-01 — passage à deux tâches planifiées
Windows indépendantes (`install_split_pipeline_tasks.ps1`) :
- **Measure @ 07:00** → `run_full_pipeline.ps1 -NoPublish` : panel, 12
  runners (+1 retry), **agrégation**, coverage gate, capsule, hash-chain —
  s'arrête avant tout push git.
- **Release @ 14:00** → `release_ai_weather.ps1` : re-vérifications
  (fichiers requis, coverage, hash-chain, alignement `origin/main`) puis
  commit/push canonique uniquement.
L'agrégation (et donc `data/history/<date>.json`, la capsule, et la
traduction — voir §4/§5) doit **toujours** se terminer pendant la tâche
Measure, avant 14h. `release_ai_weather.ps1` ne doit jamais avoir à générer
ou modifier de données de mesure — il ne fait que valider et publier ce que
Measure a déjà produit. Les horaires sont calculés en heure de Paris via
`TimeZoneInfo` (DST-safe), pas via un offset UTC fixe.

## 7. Runner Moonshot/Kimi — doit lire le panel généré du jour, pas le CSV brut
**Fix** : 2026-08-23 (voir `AI_WEATHER_PIPELINE_AUDIT.md` §3 et le
commentaire correspondant dans `run_full_pipeline.ps1`)
Ce runner exitait avec le code 0 (donc invisible au niveau process) tout en
ayant lu par défaut `config/daily_questions.csv` au lieu de
`data/panels/ai_weather_panel.csv` (chemin relatif à `AI_WEATHER_RUNNER`),
produisant un `prompt_id` incorrect. C'est pour détecter cette classe
d'échec silencieux que le coverage gate de `run_full_pipeline.ps1` relit et
valide `panel_summary` **après** agrégation, avant même la génération de
capsule.

## 8. CTA des widgets quiz — doit pointer vers le hub, pas le sous-domaine météo
**Commit** : `6512f4c`
Le call-to-action des widgets `quiz-*.html` doit renvoyer vers
`controltowerai.io` (le hub), jamais vers le sous-domaine AI Weather.

## 9. Aucun appel réseau du pipeline ne doit jamais déclencher de prompt interactif
**Incident** : 2026-09-02 — l'appel `Invoke-WebRequest` de
`Get-DailyQuestionTranslations` (`aggregate_and_publish_weather.ps1`, appel
vers `api.anthropic.com/v1/messages` pour la traduction de la question du
jour) n'avait pas `-UseBasicParsing`. Sous Windows PowerShell 5.1, cela
déclenche un prompt interactif bloquant ("Security Warning: Script
Execution Risk — Invoke-WebRequest parses the content of the web page...
[Y] Yes [A] Yes to All [N] No [L] No to All [S] Suspend") dès qu'IE n'a
jamais été lancé/configuré sur la machine (First Launch Configuration).
Ce prompt attend une entrée clavier — dans une tâche planifiée sans
surveillance, il bloque indéfiniment sans planter ni logguer d'erreur
claire. Le 2026-09-02, le run du matin (Measure @ 07:00) est resté bloqué
sur ce prompt d'environ 08:28 à 12:49 ; le budget de traduction de 90s
(§5) s'est épuisé pendant l'attente et seule la langue `ar` (première de
la liste) a été traduite avant que le prompt n'apparaisse — les 11 autres
langues ont été publiées vides, y compris dans la capsule générée à
partir de cette agrégation.
**Root cause** : les 12 runners (`run_weather_*.ps1`) utilisaient déjà
tous `-UseBasicParsing` sur leur appel `Invoke-WebRequest` (template
partagé) — seul l'appel de traduction dans l'agrégateur en était dépourvu.
Ce n'était donc pas un problème systémique sur les 12 runners, mais un
point d'appel isolé, oublié lors de l'écriture de la fonction de
traduction.
**Fix** : `-UseBasicParsing` ajouté à l'appel `Invoke-WebRequest` de
`Get-DailyQuestionTranslations` (`aggregate_and_publish_weather.ps1`).
Vérifié par relance réelle du script (`-Date "2026-09-02" -NoPublish`) à
partir des résultats bruts déjà produits par les 12 runners du matin
(sans les relancer) : aucun prompt, 12/12 langues traduites,
`check_known_fixes.ps1` entièrement `[OK]`.
`Invoke-RestMethod` (utilisé par `run_weather_moonshot_v1_2.ps1` et par
d'autres appels internes des runners) ne déclenche jamais ce warning —
le switch `-UseBasicParsing` n'existe même pas pour cette cmdlet, il n'y a
donc rien à y ajouter ni à y vérifier.
**Comportement attendu** : tout nouvel appel réseau ajouté au pipeline
(runners, agrégateur, ou tout autre script sous `AI_WEATHER_RUNNER/`)
doit utiliser soit `Invoke-RestMethod`, soit `Invoke-WebRequest` avec
`-UseBasicParsing` systématique — jamais l'un sans l'autre. Un
`Invoke-WebRequest` sans `-UseBasicParsing` ne doit plus jamais être
introduit dans ce dossier.

## 10. Manifeste public des capsules — inventaire atomique et publication cohérente

`aiweather-capsule/generate_capsule_index.py` produit `data/capsule-index.json`
uniquement à partir des capsules existantes et valides, sans modifier leurs octets.
Toutes les dates disponibles sont conservées, y compris les observations avec
données insuffisantes ; les entrées sont uniques et triées par date décroissante.
Le manifeste ne contient que sa version de schéma et les dates/chemins publics.
Il est déterministe (UTF-8 sans BOM, LF, aucun horodatage de génération) et remplacé
atomiquement depuis un temporaire du même répertoire. Une relance identique ne
réécrit pas le fichier. Un inventaire invalide conserve le manifeste précédent.

`run_full_pipeline.ps1` le génère après vérification de chaîne et avant `-NoPublish`,
même si la capsule du jour existait déjà. `release_ai_weather.ps1` ne le génère
jamais : il vérifie sa fraîcheur avant/après synchronisation Git et le publie avec
la capsule dans le même commit canonique. Chaque référence doit correspondre au
contenu présent dans l'index Git du futur commit ; une capsule seulement locale
ou différente bloque la publication. Aucun ajout automatique d'archives non prévues.

`index_full.html` sélectionne au maximum les 15 capsules les plus récentes du manifeste,
sans deviner d'URL ni combler les jours absents. Les conditions publiées ne sont
jamais recalculées ; absence, insuffisance et observation ambiguë sont distinctes.
Le prompt anglais reste accessible et sert de repli lorsque sa traduction manque.
La lecture automatique est désactivée avec `prefers-reduced-motion`.

Tests : `python -B -m unittest discover -s aiweather-capsule/tests -v` et
`node docs/climate-history-review/validate.cjs`. Aucun de ces tests ne publie le dépôt.

## 11. Publication quotidienne inconditionnelle — ON PUSH TOUJOURS
**Décision produit** : 2026-09-06 (demande explicite du propriétaire du
projet). Auparavant, `run_full_pipeline.ps1` (gate `AGGREGATION_COVERAGE`)
et `release_ai_weather.ps1` (§4 "VALIDATE PANEL COVERAGE") bloquaient toute
publication si `daily_panel_coverage` ou `longitudinal_panel_coverage`
tombait sous 0.9, ou si `systems_count != systems_expected` — cf. incident
du 2026-09-06 (DeepSeek 0%, Nvidia 17.4% → coverage globale 84.8% →
pipeline bloqué, `weather.json`/`current.json` mis à jour en local mais
jamais commit/push, widget public resté sur les données de la veille).
**Comportement attendu, sans exception** : ces trois contrôles ne sont
plus bloquants dans aucun des deux scripts — ils journalisent un
`[WARN]`/`COVERAGE WARNING` et le pipeline continue jusqu'à la capsule,
le hash-chain, le commit et le `git push origin main`. Une journée à
faible couverture (voire `insufficient_data`) doit être publiée telle
quelle, jamais retenue. **Ne plus jamais réintroduire** de `Block`/`throw`
sur ces trois métriques dans `run_full_pipeline.ps1` ou
`release_ai_weather.ps1` — les autres gates (fichiers requis, JSON
invalide, git divergent, hash-chain cassée) restent, eux, bloquants : ce
sont des garanties d'intégrité structurelle, pas des seuils de qualité de
données, et ne sont pas concernés par cette décision.
## 12. Volume d'observation — une seule source de vérité, datée

**Changement de protocole** : 2026-10-08 (demande explicite du propriétaire
du projet), **premier cycle concerné : 2026-10-09 07:00 Paris**. Le volume
passe de **23 + 7 = 30** à **3 + 7 = 10** exécutions par modèle actif et
par jour (3 pour Today's Challenge, 7 pour la question fixe de suivi
longitudinal).

**Cause vérifiée des 23 passages** (ce n'était ni un doublon ni une
relance) : le défaut de paramètre `[int]$DailyRepetitions = 23` de
`build_daily_panel.ps1`, écrit dans la colonne `repetitions` de
`data/panels/ai_weather_panel.csv` régénéré chaque matin, que les 12
`run_weather_*.ps1` lisent comme borne de leur boucle
`for ($i = 1; $i -le $rowRepetitions; $i++)`. Le même nombre était
**dupliqué** en dur dans `aggregate_and_publish_weather.ps1`
(`$DAILY_PROBE_EXPECTED = 23`) comme dénominateur de couverture, plus un
garde-fou `if ($totalRepetitions -ne 30)` dans le builder.

**Comportement attendu, à ne plus jamais régresser :**

1. **Une seule source de vérité**, `AI_WEATHER_RUNNER/config/protocol_volume.json`,
   lue via `lib/Get-ProtocolVolume.ps1` par les trois consommateurs
   (`build_daily_panel.ps1`, `launch_ai_weather.ps1`,
   `aggregate_and_publish_weather.ps1`). **Ne jamais réintroduire** de
   littéral de volume dans un script : changer le volume doit rester
   l'édition d'**une seule entrée JSON**.
2. **La configuration est datée** (`schedule[].effective_from`, résolution
   = dernière entrée `<=` la date demandée). C'est indispensable :
   réagréger une journée déjà publiée doit réutiliser le volume avec
   lequel elle a été mesurée, sinon une journée complète se mettrait à
   rapporter une couverture incomplète. Un nouveau volume s'ajoute donc
   **toujours** comme une nouvelle entrée — on ne modifie jamais une
   entrée passée.
3. **`measurement_version` / `methodology_version` ne changent PAS** pour
   un changement de volume : prompts, modèles actifs, paramètres de
   génération et configuration des évaluateurs sont identiques, donc
   l'instrument de mesure est identique. Le changement est identifié par
   `protocol.volume_profile` (`profile_id`, `effective_from`,
   `measurement_instrument_changed: false`) publié dans `weather.json`,
   `data/history/<date>.json` et la capsule.
4. **Le volume longitudinal reste à 7.** La baseline V2 (médiane/MAD sur
   fenêtre de 14 jours, plancher MAD = `100/N/2`, intervalle de Wilson
   descriptif) dépend de `repetition_count = 7` : la faire varier
   casserait la comparabilité de la série. Seul le canal *daily* est
   réduit.
5. **Les effectifs réels restent publiés tels quels** (`observations`,
   `fully_scored`, `regime_distribution`, `expected_observations` par
   système et par sonde). Aucune page, aucun widget, aucun agrégat ne doit
   coder en dur un nombre d'observations.
6. **Honnêteté statistique** : `probe_contract.<sonde>.statistical_basis`
   publie `basis_n`, `share_granularity_points` (= `100/N`) et
   `robustness` (`indicative_only` sous
   `statistical_robustness_min_n = 10`, `descriptive` au-dessus), avec
   `interval_published: false`. À N=3, une observation déplace une part de
   33,33 points : **ne jamais présenter 3 réponses comme une comparaison
   statistiquement robuste**, et ne jamais fabriquer d'intervalle de
   confiance pour la sonde quotidienne (l'intervalle de Wilson existant
   est longitudinal et descriptif uniquement).
7. **Les tentatives techniques ne sont pas des observations.** Les reprises
   `Invoke-StreamWithRetry` (bornées : `MaxAttempts`, 2 tentatives max sur
   la signature de troncature, budget mural) produisent **une seule ligne
   par répétition**. Et l'agrégateur ne lit, par fournisseur et par jour,
   que **le fichier `*_results.jsonl` le plus récemment écrit** : la
   relance unique de `run_full_pipeline.ps1` remplace donc la tentative
   précédente au lieu de s'y ajouter — un quota ne peut pas être dépassé
   par un redémarrage. **Ne jamais remplacer cette sélection par une
   concaténation de tous les fichiers du jour** sans ajouter une
   déduplication par `run_id`.

**Répartition dans la fenêtre de collecte** : les 10 passages d'un même
système sont espacés d'au moins `inter_observation_spacing_ms` (600 000 ms
= 10 min), exporté par `launch_ai_weather.ps1` dans
`NEOMUNDI_OBSERVATION_SPACING_MS` et appliqué comme **plancher** sur le
`$DELAY_MS` propre à chaque fournisseur (`max(pacing, espacement)`, jamais
`min` : on ne resserre jamais la protection anti-rate-limit d'un
fournisseur). Soit 9 intervalles → ~90 min, de 07:00 à ~08:30 Paris, ce
qui laisse intacte la deadline de mesure de 13:30 (assez pour une relance
complète) et l'heure de publication de 14:00.

Test : `.\AI_WEATHER_RUNNER\tests\test_protocol_volume.ps1` (44 assertions,
aucun appel API ; il restaure le panel de production octet pour octet).
