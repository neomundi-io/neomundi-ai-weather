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
