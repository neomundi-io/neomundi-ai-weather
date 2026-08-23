# AI WEATHER — PHASE 1 AUDIT (READ-ONLY)

Date de l'audit : 2026-08-23
Racine : `neomundi-ai-weather/neomundi-ai-weather`
Aucune modification n'a été faite. Ce document est strictement observationnel.

---

## 0. État Git

```
branch: main (up to date with origin/main)
staged: aiweather-capsule/verify_chain.py (new file)
modified (unstaged): data/current.json, weather.json
untracked: data/history/2026-08-23.json
```

Rien de destructif en attente. Le dépôt est propre (pas de conflit, pas de divergence avec origin).
`.gitignore` couvre correctement `secrets.weather.xml`, `**/raw/`, `**/scored/` — pas de fuite de clés détectée.

---

## 1. Cartographie réelle de la chaîne (fichiers vérifiés, pas supposés)

```
AI_WEATHER_RUNNER\config\daily_questions.csv        (30 lignes, 1 par date, PAS de prompt_id/repetitions)
AI_WEATHER_RUNNER\config\longitudinal_probe.csv      (1 ligne fixe)
        ↓
AI_WEATHER_RUNNER\build_daily_panel.ps1
        → lit les deux CSV ci-dessus, filtre daily_questions.csv sur $Date
        → écrit AI_WEATHER_RUNNER\data\panels\ai_weather_panel.csv
          (2 lignes : "daily-$Date" x23 reps, "longitudinal-core-01" x7 reps = 30/système)
        → sauvegarde l'ancien panel en ai_weather_panel_backup_<timestamp>.csv avant d'écraser
        ↓
AI_WEATHER_RUNNER\launch_ai_weather.ps1
        → lit AI_WEATHER_RUNNER\data\panels\ai_weather_panel.csv (chemin RELATIF à AI_WEATHER_RUNNER, pas à la racine repo)
        → exige exactement 12 fichiers run_weather_*.ps1
        → fixe $env:NEOMUNDI_RESULTS_DIR = results\<date UTC>\ (hérité par les process enfants)
        → lance les 12 runners en Start-Process (avec -WaitForCompletion si appelé depuis le pipeline)
        ↓
12 runners run_weather_*.ps1
        → 11 runners lisent data\panels\ai_weather_panel.csv (chemin relatif à AI_WEATHER_RUNNER) — CORRECT
        → 1 runner (moonshot/Kimi) lit par défaut .\config\daily_questions.csv — INCORRECT (voir §3)
        → écrivent dans $env:NEOMUNDI_RESULTS_DIR (ou results\ en fallback) :
          <provider>_<model>_<wave>_<timestampUTC>_results.jsonl / .csv / _summary.json
        ↓
AI_WEATHER_RUNNER\aggregate_and_publish_weather.ps1 -Date $Date -NoPublish
        → lit config\panel.yml (racine repo, PAS AI_WEATHER_RUNNER\config) pour la liste canonique des 12 systèmes
          et leur `runner_provider` (préfixe de fichier attendu)
        → pour chaque système : Get-ChildItem -Filter "<runner_provider>_*_results.jsonl" dans results\<date>\
        → classe chaque ligne JSONL en daily / longitudinal / unknown via Get-ProbeRole :
              1. row.probe_role si présent
              2. sinon prefixe de prompt_id : ^daily(-|_) ou ^longitudinal(-|_)
        → calcule condition/score/coverage par système, panel_summary global (systems_count, coverage)
        → écrit data\history\<date>.json, data\current.json, weather.json
        → NE fait JAMAIS git add/commit/push (délégué à release_ai_weather.ps1 / run_ai_weather_pipeline.ps1)
        ↓
aiweather-capsule\generate_capsule.py  ⚠ FICHIER INTROUVABLE (voir §4)
        → censé produire aiweather-capsule\capsules\<yyyy>\<mm>\<dd>.json à partir de data\history\<date>.json
        ↓
aiweather-capsule\verify_chain.py
        → vérifie content_hash (SHA-256 canonique) + prev_hash + sequence_index strictement croissant
          sur toutes les capsules capsules/*/*/*.json triées par nom de fichier
        → exit code non-zéro si rupture
        ↓
AI_WEATHER_RUNNER\release_ai_weather.ps1 -Date $Date   (PUBLICATION — le seul endroit qui doit pousser)
        → vérifie présence : history, current.json, weather.json, capsule du jour, latest.json, verify_chain.py
        → vérifie probe_contract.daily.prompt_id == "daily-$Date" et question non vide
        → vérifie panel_summary.systems_count == systems_expected, daily/longitudinal coverage ≥ 0.9
        → vérifie capsule.date == $Date
        → exécute `python verify_chain.py` — bloque si non-zéro
        → vérifie branch=main ET local HEAD == origin/main (git fetch avant comparaison)
        → git reset ; git add uniquement les 5 fichiers canoniques ; refuse tout fichier staged inattendu
        → git commit "AI Weather canonical release $Date" ; git push origin main
```

**Constat important** : il existe **deux mécanismes de publication Git distincts** :
1. `release_ai_weather.ps1` — validations strictes (coverage ≥0.9, alignement origin/main, staging canonique).
2. `run_ai_weather_pipeline.ps1 -Publish` — publication plus sommaire (add/commit/push direct, vérifie seulement que AI Weather et aiweather-capsule sont dans le même worktree Git).

`run_daily_ai_weather.ps1` (le wrapper visiblement prévu pour la tâche planifiée de 12:30) appelle `build_daily_panel.ps1` puis `run_ai_weather_pipeline.ps1` **sans** `-Publish`, et son commentaire dit explicitement : *"Public release is handled separately at 14:00"*. Cela suggère que `release_ai_weather.ps1` est le vrai mécanisme de publication en production, et que la branche `-Publish` de `run_ai_weather_pipeline.ps1` est soit un chemin manuel/de secours, soit un reliquat non branché sur une tâche planifiée. **À confirmer avec vous** — voir §6.

---

## 2. Incohérence confirmée : `install_ai_weather_task.ps1` vs `run_daily_ai_weather.ps1`

`install_ai_weather_task.ps1` construit la commande de la tâche planifiée avec l'argument `-TargetUtcHour $TargetUtcHour`.

Mais `run_daily_ai_weather.ps1` (version actuelle) n'a **aucun paramètre `-TargetUtcHour`** — seulement `[switch]$Force`. Sa description dit aussi "Scheduled by Windows at 12:30 local France time" (heure fixe), alors que le script d'installation décrit une logique "check hourly, publish at most once per UTC date" avec un trigger horaire répété.

**Conclusion** : soit une tâche Windows existante appelle `run_daily_ai_weather.ps1 -TargetUtcHour ...` et échouerait immédiatement (paramètre inconnu → erreur PowerShell), soit `install_ai_weather_task.ps1` documente une version antérieure du wrapper qui a été refactorée depuis sans mettre à jour l'installeur. Aucune tâche planifiée Windows nommée n'a pu être énumérée sur cette machine au moment de l'audit (voir §7) — donc ceci n'a peut-être pas encore d'impact réel, mais bloquerait la réinstallation de la tâche telle quelle.

---

## 3. CAS KIMI — cause racine confirmée avec les données réelles du jour

### Ce qui a été vérifié, pas supposé

- `run_weather_moonshot_v1_2.ps1` ligne 32 :
  ```powershell
  [string]$PanelFile = ".\config\daily_questions.csv",
  ```
  C'est le **seul** des 12 runners dont le panel par défaut n'est pas `data\panels\ai_weather_panel.csv`.
  (`run_weather_perplexity.ps1` a aussi un paramètre `-PanelFile`, mais résout un défaut vide vers `data\panels\ai_weather_panel.csv` — il est correct.)

- `launch_ai_weather.ps1` ne passe **jamais** `-PanelFile` aux runners qu'il lance (seulement `-WaveId`, `-SmokeTest`, `-MaxRepetitions`, `-TargetPromptId`). Donc en usage normal (lancement orchestré), Kimi utilise systématiquement son défaut incorrect.

- `AI_WEATHER_RUNNER\config\daily_questions.csv` contient **30 lignes** (une par date, du 2026-08-21 au-delà), avec les colonnes `date, prompt_version, prompt_family, analysis_role, difficulty, domain, expected_behavior, language, question, reference_answer_or_criterion, sensitivity`. **Il n'y a ni colonne `prompt_id` ni colonne `repetitions`.**

- Dans `run_weather_moonshot_v1_2.ps1`, quand la colonne `repetitions` est absente, `Get-PromptField` retombe sur la valeur par défaut **1**. Et sans colonne `prompt_id`, l'identifiant retombe sur `"prompt_$($requestCounter+1)"`.
  → Résultat mécanique : 30 lignes × 1 répétition chacune = **30 observations**, mais ce sont 30 **questions différentes** (une par date du CSV), chacune posée une seule fois — pas "23× la question du jour + 7× la sonde longitudinale" comme le protocole l'exige.

- **Preuve sur données réelles** — fichier généré aujourd'hui par le vrai lancement (`weather_sentinel_0_1`, 2026-08-23 12:30 UTC) :
  ```
  results/2026-08-23/moonshot_kimi-k3_weather_sentinel_0_1_20260823T123004Z_results.jsonl
  ```
  contient 29 lignes avec des `prompt_id` = `prompt_1`, `prompt_2`, ... `prompt_30` (aucun `daily-*`, aucun `longitudinal-*`).

- `aggregate_and_publish_weather.ps1` retrouve bien le fichier de Kimi (le filtre `Get-ChildItem -Filter "moonshot_*_results.jsonl"` fonctionne, `runner_provider: "moonshot"` est correctement déclaré dans `config\panel.yml` racine). **La découverte de fichier n'est pas le problème.**

- Le problème est dans `Get-ProbeRole` (aggregate_and_publish_weather.ps1, ligne ~193) : elle classe chaque ligne en `daily` / `longitudinal` / `unknown` uniquement via `probe_role` explicite ou le préfixe de `prompt_id`. Comme tous les `prompt_id` de Kimi sont `prompt_N`, **toutes les lignes tombent dans `unknown`** → `dailyRows.Count = 0`, `longitudinalRows.Count = 0` → `DAILY=insufficient_data`, `Dcov=0%`, `LONGcov=0%`, alors que le résumé brut du runner affiche bien 30/30 succès, 0 erreur.

### Ce n'est pas une hypothèse à corriger à l'aveugle — c'est une régression documentée

`README_KIMI3.md` (écrit le 2026-08-20, faisant autorité sur "l'architecture qui a fonctionné") dit explicitement en §5 :
> Default AI Weather panel: `.\data\panels\ai_weather_panel.csv`

Et `AI_WEATHER_RUNNER\FULL_AUTOMATISATION\ROADMAP.md` (2026-08-18) liste déjà :
> Fix panel Moonshot (mauvais CSV par défaut) | ✅ corrigé

**Autrement dit : ce bug précis a déjà existé et a déjà été corrigé une première fois.** La version actuelle `run_weather_moonshot_v1_2.ps1` (modifiée aujourd'hui, 2026-08-23 13:16, la plus récente de tous les runners) a réintroduit la régression — très probablement lors d'une réécriture/renommage vers "v1.2" qui a réinitialisé la valeur par défaut du paramètre.

### Correctif proposé (non appliqué à ce stade — Phase 1 = lecture seule)

Changer une seule ligne dans `run_weather_moonshot_v1_2.ps1` :
```powershell
[string]$PanelFile = ".\data\panels\ai_weather_panel.csv",
```
Cela aligne Kimi sur les 11 autres runners, sur sa propre documentation (`README_KIMI3.md`), et sur le contrat de `prompt_id` attendu par l'agrégateur — sans toucher à l'endpoint `api.moonshot.ai` (confirmé correct, aucune référence à `api.moonshot.cn` trouvée nulle part dans le dépôt actif) ni à la politique de clé.

**Robustesse suggérée en plus (optionnelle)** : dans `aggregate_and_publish_weather.ps1`, avertir explicitement (au lieu de classer silencieusement en `unknown`) quand un système attendu a 0 ligne `daily` alors que son fichier de résultats existe et contient N>0 lignes — ça aurait rendu ce bug visible immédiatement au lieu d'un `insufficient_data` silencieux.

---

## 4. `aiweather-capsule\generate_capsule.py` — restauré par vous, mais VERSION INCOMPATIBLE (mise à jour post-audit)

Vous avez replacé un `generate_capsule.py` récupéré d'une ancienne sauvegarde. Vérification effectuée par lecture de code + un dry-run isolé (copie de `data\history\2026-08-23.json` dans un dossier temporaire hors du dépôt, jamais dans `aiweather-capsule\capsules\`).

**Résultat : ce fichier n'est PAS la version qui a produit les capsules 17/21/22.json actuelles. Ne pas l'utiliser tel quel pour générer la capsule du 23.**

Deux problèmes concrets, vérifiés :

1. **Crash immédiat sur BOM.** Le fichier lit l'input avec `.read_text(encoding="utf-8")` (ligne 184). Tous les JSON produits par ce pipeline (`data\history\*.json`, `weather.json`, etc.) sont écrits par PowerShell (`ConvertTo-Json` / `Out-File -Encoding UTF8`) et portent donc un BOM UTF-8. Test réel :
   ```
   json.decoder.JSONDecodeError: Unexpected UTF-8 BOM (decode using utf-8-sig)
   ```
   → Sur un vrai fichier `data\history\<date>.json`, ce script plante avant même de commencer.

2. **Schéma incompatible avec le format probe-split v0.2 réellement en usage.** Après avoir contourné le BOM pour le seul besoin du test (fichier temporaire, jamais le fichier réel), le dry-run produit une capsule avec :
   ```
   coverage: {}          (vide — le script cherche raw["coverage"], qui n'existe pas au niveau racine
                           de data\history\*.json ; ces données sont dans "panel_summary")
   observations: []      (vide — le script cherche raw["profiles"] ou raw["observations"], mais
                           data\history\*.json a une clé "systems")
   interpretation_boundaries: "reserved"   (chaîne fixe, pas les vraies règles d'interprétation)
   ```
   Comparaison factuelle avec la vraie capsule `22.json` (`schema_version: "0.2"`) :

   | Champ racine de la vraie capsule 22.json | Présent dans le fichier restauré ? |
   |---|---|
   | `schema_version` = `"0.2"` | Oui mais valeur `"0.1"` dans le fichier restauré (docstring du fichier confirme "Schema v0.1") |
   | `source_format` = `"ai_weather_history_v0.2"` | **Absent** |
   | `protocol` (copié tel quel depuis l'history) | **Absent** |
   | `global_condition` (copié tel quel) | **Absent** |
   | `global_judgment_demand` | **Absent** |
   | `legacy_global_score` (= `history.global_score` renommé) | **Absent** |
   | `interpretation_contract` | **Absent** |
   | `panel_summary` | **Absent** |
   | `probe_contract` (copié tel quel — vérifié égal à `history.probe_contract`) | **Absent** |
   | `interpretation_boundaries` (vrai dict de règles) | Remplacé par la chaîne `"reserved"` |
   | `rendering_metadata` (vrai dict : `daily_question_visibility`, `wall_source`, etc.) | Remplacé par la chaîne `"reserved"` |
   | `signature` = `"reserved_for_future_version"` | Valeur différente : `"reserved_for_v0.2"` |
   | `observations` (dérivé de `history.systems`, transformé) | Vide `[]` |
   | `coverage` (dérivé de `history.panel_summary`, transformé) | Vide `{}` |

   **Le point le plus dangereux** : `verify_chain.py` ne vérifie QUE la cohérence des hash/`prev_hash`/`sequence_index` — il ne vérifie jamais la richesse du contenu. Une capsule vide (`coverage: {}`, `observations: []`) générée par ce script passerait quand même la vérification de chaîne avec succès, et `release_ai_weather.ps1` ne bloque que sur `capsule.date == $Date` (pas sur le contenu). **Une capsule creuse pourrait donc être publiée sans qu'aucun garde-fou actuel ne la bloque.**

**Recommandation** : ne pas exécuter ce `generate_capsule.py` contre de vraies données pour l'instant. Il faut soit retrouver la vraie version v0.2 (celle qui a produit 17/21/22.json — peut-être dans un autre `.zip` d'ARCHIVES, non extrait à ce jour), soit la reconstruire à partir du tableau ci-dessus (transformation directe de `data\history\<date>.json` : copier `protocol`, `global_condition`, `global_judgment_demand`, `interpretation_contract`, `panel_summary`, `probe_contract` tels quels ; renommer `global_score`→`legacy_global_score` et `systems`→`observations` ; ajouter `capsule_id`, `chain`, `schema_version: "0.2"`, `source_format: "ai_weather_history_v0.2"`, plus les vrais dicts `interpretation_boundaries`/`rendering_metadata`/`signature` — actuellement visibles en clair dans `capsules\2026\08\22.json`, à recopier comme constantes). Je ne fais ni l'un ni l'autre sans votre feu vert explicite.

---

## 5. Inventaire des scripts orchestrateurs candidats (statut)

| Fichier | Rôle réel constaté | Statut |
|---|---|---|
| `launch_ai_weather.ps1` | Lance les 12 runners (Start-Process), gère `NEOMUNDI_RESULTS_DIR` | **ACTIVE** |
| `aggregate_and_publish_weather.ps1` | Agrège JSONL → history/current/weather.json, ne publie jamais Git | **ACTIVE** |
| `release_ai_weather.ps1` | Validation stricte + commit/push canonique | **ACTIVE** (mécanisme de publication le plus rigoureux) |
| `build_daily_panel.ps1` | Construit `ai_weather_panel.csv` depuis les CSV config | **ACTIVE** |
| `run_daily_ai_weather.ps1` | Wrapper "préparation" (panel + pipeline, sans publish) | **ACTIVE mais incohérent** (§2) |
| `run_ai_weather_pipeline.ps1` | Pipeline bout-en-bout (launch→aggregate→capsule→verify→publish optionnel) | **ACTIVE mais cassé** (§4 : dépendance manquante) |
| `install_ai_weather_task.ps1` | Installe la tâche planifiée Windows | **DÉSYNCHRONISÉ** de `run_daily_ai_weather.ps1` actuel (§2) |
| `run_ai_weather.ps1` | Boucle sur `config\providers.json` + `run_provider.ps1` | **LEGACY / CASSÉ** — `run_provider.ps1` n'existe qu'en `ARCHIVES\`, absent à la racine. Aucun script actif ne l'appelle. |
| `run_ai_weather_full.ps1` | Suite de commandes commentées (pas un vrai script paramétré) | **LEGACY** — remplacé par `run_ai_weather_pipeline.ps1`. Aucune référence entrante. |
| `aggregate_and_publish_weather_PRE_MULTI_SIGNAL.ps1` | Version antérieure de l'agrégateur (pré "multi-signal") | **LEGACY / snapshot explicite** — nom auto-descriptif, aucune référence entrante. |
| `FULL_AUTOMATISATION\launch_ai_weather.ps1` | Ancien brouillon de launcher (`-Unattended`, `-TimeoutMinutes`, pas de `-WaitForCompletion`) | **LEGACY / DUPLICATE** — diverge du launcher actif, aucune référence entrante. |
| `FULL_AUTOMATISATION\Runner_patched.zip` | Archive zip d'une ancienne itération | **LEGACY (archive)** |
| `FULL_AUTOMATISATION\ROADMAP.md` | Roadmap historique (2026-08-18), utile comme contexte | **RÉFÉRENCE — garder, ne pas archiver** (documente déjà le bug Kimi comme "corrigé", précieux pour comprendre la régression) |
| `ARCHIVES\*` (zips, `Runner_patched\`, anciens `run_weather_*.ps1`, `run_provider.ps1`, `run_kimi_k3_cross_domain_panel_direct_v1_1.ps1`) | Anciennes versions déjà déplacées dans ARCHIVES par le passé | **LEGACY (déjà archivé)** — aucune action requise, confirme que la pratique d'archivage existe déjà dans ce projet |

---

## 6. Inventaire des runners providers (12 attendus)

Tous lus/vérifiés par leur usage de `$PANEL_FILE` :

| Runner | Panel par défaut | Statut |
|---|---|---|
| `run_weather_anthropic.ps1` | `data\panels\ai_weather_panel.csv` (hardcodé) | ACTIVE |
| `run_weather_cohere.ps1` | idem | ACTIVE |
| `run_weather_deepseek.ps1` | idem | ACTIVE |
| `run_weather_google.ps1` | idem | ACTIVE |
| `run_weather_meta.ps1` | idem | ACTIVE |
| `run_weather_mistral.ps1` | idem | ACTIVE |
| `run_weather_nvidia.ps1` | idem | ACTIVE |
| `run_weather_openai.ps1` | idem | ACTIVE |
| `run_weather_qwen.ps1` | idem | ACTIVE |
| `run_weather_xai.ps1` | idem | ACTIVE |
| `run_weather_perplexity.ps1` | param `-PanelFile ""` → résout vers `data\panels\ai_weather_panel.csv` | ACTIVE (correct) |
| `run_weather_moonshot_v1_2.ps1` | param `-PanelFile ".\config\daily_questions.csv"` | **ACTIVE mais BUGUÉ** (§3) |

`config\panel.yml` (racine repo) liste bien 12 systèmes avec un `runner_provider` par système, cohérent avec les 12 noms de fichiers ci-dessus (`moonshot` → Kimi confirmé, endpoint `api.moonshot.ai`, jamais `.cn`, conforme à votre consigne).

---

## 7. Doublons/fichiers non référencés identifiés (candidats à archivage, PAS déplacés)

Vérifiés par grep : **aucune référence entrante** dans un script actif pour :
- `AI_WEATHER_RUNNER\data\daily_questions.csv` (doublon du vrai `config\daily_questions.csv` — structure à vérifier avant d'y toucher)
- `AI_WEATHER_RUNNER\data\panels\Panel_vert\ai_weather_panel.csv` (sous-dossier isolé, jamais référencé)
- `AI_WEATHER_RUNNER\data\panels\ai_weather_panel_backup_*.csv` (5 fichiers — normal, ce sont les sauvegardes automatiques de `build_daily_panel.ps1`, à garder mais pourraient être déplacées vers un sous-dossier `backups\` pour alléger `data\panels\`)
- `AI_WEATHER_RUNNER\weather_models.json`
- `AI_WEATHER_RUNNER\index_last.html`
- `aiweather-capsule.zip` (racine repo) et `aiweather-capsule-smoke\` (généré/nettoyé par `run_ai_weather_pipeline.ps1` en mode `-SmokeTest`, transitoire)

Aucun de ces fichiers n'a été déplacé — conformément à la consigne "ne rien déplacer avant d'avoir compris".

---

## 8. Tâches planifiées Windows

`schtasks /query` n'a renvoyé **aucune tâche** correspondant à "weather" ou "neomundi" au moment de l'audit (et même une requête générale n'a rien retourné de visible dans ce contexte d'exécution — à reconfirmer directement depuis une session PowerShell interactive avec vos propres droits, l'outil d'audit peut ne pas avoir la visibilité complète sur le Planificateur de tâches). **Ne pas supposer qu'aucune tâche n'existe** tant que ce n'est pas revérifié en direct par vous (`Get-ScheduledTask | Where-Object TaskName -like "*weather*"`).

---

## 9. Résumé simple

```
CURRENT PIPELINE STATUS
-----------------------
CONFIG (daily_questions.csv → panel) OK
12 RUNNERS (lancement)                OK
KIMI / MOONSHOT DATA QUALITY          BROKEN — mauvais panel par défaut (régression confirmée)
AGGREGATION                           OK (mécanisme sain, mais reflète fidèlement le bug Kimi)
HISTORY (data/history/*.json)         OK
CAPSULE GENERATION (generate_capsule.py) BLOQUÉ — script introuvable
HASH CHAIN (verify_chain.py)          OK (logique saine, testée en lecture)
PUBLIC BUILD (weather.json)           OK
GIT COMMIT / PUSH                     NOT TESTED (deux mécanismes distincts à clarifier, §1)
WINDOWS TASK SCHEDULER                DÉSYNCHRONISÉ avec install_ai_weather_task.ps1 (§2), tâches réelles non confirmées (§8)
```

**Rien n'a été modifié.** Les sections suivantes (carte détaillée, plan de nettoyage) sont dans `AI_WEATHER_PIPELINE_MAP.md` et `AI_WEATHER_CLEANUP_PLAN.md`.
