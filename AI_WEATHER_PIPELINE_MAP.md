# AI WEATHER — PIPELINE MAP (fichiers réels, vérifiés)

Chemins relatifs à `AI_WEATHER_RUNNER\` sauf mention contraire (`REPO\` = racine du dépôt).

```
01 — DAILY CONFIG / PANEL
     config\daily_questions.csv  (30 lignes, 1/date, colonnes: date,prompt_version,prompt_family,
                                   analysis_role,difficulty,domain,expected_behavior,language,
                                   question,reference_answer_or_criterion,sensitivity)
     config\longitudinal_probe.csv (1 ligne fixe)
            │
            ▼  build_daily_panel.ps1 -Date <yyyy-MM-dd>
     Consomme : les 2 CSV ci-dessus, filtrés sur $Date pour le daily.
     Produit  : data\panels\ai_weather_panel.csv (2 lignes : daily-$Date x23, longitudinal-core-01 x7)
                + sauvegarde ai_weather_panel_backup_<timestamp>.csv de l'ancien panel.
     Succès si : exactement 2 lignes, total repetitions == 30, prompt_id[0] == "daily-$Date".

02 — LAUNCHER
            │
            ▼  launch_ai_weather.ps1 [-WaveId] [-WaitForCompletion] [-SmokeTest] [-MaxRepetitions]
     Consomme : secrets.weather.xml (clés), data\panels\ai_weather_panel.csv, les 12 run_weather_*.ps1.
     Produit  : $env:NEOMUNDI_RESULTS_DIR = results\<yyyy-MM-dd>\ (variable héritée par les 12 process enfants).
     Succès si : exactement 12 fichiers run_weather_*.ps1 détectés ; sinon throw immédiat.
     ⚠ Ne passe jamais -PanelFile aux runners → chaque runner utilise SON PROPRE défaut.

03 — 12 PROVIDER RUNNERS (run_weather_*.ps1, lancés en parallèle via Start-Process)
     anthropic, cohere, deepseek, google, meta, mistral, nvidia, openai, qwen, xai, perplexity
       → lisent data\panels\ai_weather_panel.csv (11 en dur, perplexity via résolution de défaut) — CORRECT
     moonshot (run_weather_moonshot_v1_2.ps1, Kimi K3)
       → lit .\config\daily_questions.csv PAR DÉFAUT — INCORRECT (voir AUDIT §3)
       → endpoint api.moonshot.ai confirmé (jamais .cn), clé Windows User persistante
     Consomme : $env:NEOMUNDI_API_KEY, clé provider spécifique, panel CSV.
     Produit  : results\<date>\<provider>_<model>_<wave>_<timestampUTC>_results.{jsonl,csv} + _summary.json
                (POST provider → POST https://api.neomundi.io/v1/govern pour chaque observation)
     Succès si : exit code 0 par process ; launch_ai_weather.ps1 -WaitForCompletion agrège les échecs.

04 — RAW / RESULTS / SCORED
     results\<date>\*_results.jsonl   ← fichier canonique lu par l'agrégateur
     raw\, scored\                    ← dossiers legacy peu peuplés (raw\2026-08-16, scored\2026-08-16
                                          seulement), pas alimentés par le pipeline actuel constaté.

05 — AGGREGATION MULTI-SIGNAL
            │
            ▼  aggregate_and_publish_weather.ps1 -Date <yyyy-MM-dd> [-NoPublish]
     Consomme : REPO\config\panel.yml (liste des 12 systèmes + runner_provider),
                results\<date>\<runner_provider>_*_results.jsonl (et repli sur le dossier parent results\),
                REPO\weather.json existant (pour condition précédente, contexte seulement).
     Logique clé : Get-ProbeRole(row) = probe_role explicite, sinon préfixe de prompt_id
                   (^daily(-|_) / ^longitudinal(-|_)), sinon "unknown" (exclu des deux agrégats).
     Produit  : REPO\data\history\<date>.json, REPO\data\current.json, REPO\weather.json.
     Succès si : par système, coverage daily/longitudinal calculée ; ne bloque QUE sur erreurs de parsing,
                 ne bloque jamais sur coverage=0% pour un système (juste condition=insufficient_data).
     Ne fait JAMAIS git add/commit/push (par design, commenté explicitement dans le script).

06 — data\history\YYYY-MM-DD.json (REPO\data\history\)
     Contient : probe_contract.daily.{prompt_id,question}, panel_summary.{systems_count,systems_expected,
                daily_panel_coverage,longitudinal_panel_coverage}, systems[] (12 entrées).
     Vérifié aujourd'hui : 2026-08-23.json existe (untracked), taille cohérente avec 2026-08-22.json.

07 — CAPSULE GENERATION
            │
            ▼  aiweather-capsule\generate_capsule.py --input data\history\<date>.json --date <date>
     ⚠ FICHIER INTROUVABLE dans le dépôt actuel (ni à la racine de aiweather-capsule\, ni ailleurs
       en dehors des .zip d'ARCHIVES non extraits). Référencé par run_ai_weather_pipeline.ps1 comme
       composant requis → ce script échoue au démarrage tel quel.
     Produit (attendu) : aiweather-capsule\capsules\<yyyy>\<mm>\<dd>.json avec un bloc "chain"
       {content_hash, prev_hash, sequence_index}.
     Capsules réellement présentes : 2026/08/{17,21,22}.json — PAS 23 (le 23 n'a pas encore été
     capsulé/publié au moment de l'audit, cohérent avec release_ai_weather.ps1 non encore lancé).

08 — HASH CHAIN
     Chaque capsule embarque : chain.content_hash (SHA-256 sur le JSON canonique sans content_hash),
     chain.prev_hash (= content_hash de la capsule précédente, "genesis" pour la première),
     chain.sequence_index (entier strictement croissant depuis 0).

09 — verify_chain.py [--capsules-dir <dir>]
     Consomme : capsules\*/*/*.json (tri par nom de fichier, donc par date si nommage yyyy/mm/dd.json).
     Vérifie : recalcul du hash == content_hash stocké ; prev_hash == hash de la capsule précédente ;
               sequence_index attendu == stocké.
     Sort avec exit code 1 si rupture, 0 si chaîne valide ou dossier vide. Logique lue et saine.

10 — weather.json / pages HTML / public assets
     REPO\weather.json ← écrit par aggregate_and_publish_weather.ps1 (étape 05), lu par REPO\index.html
     et les widgets (core-panel.html, widget.html, embed-demo.html, etc. — non audités en détail ici,
     hors périmètre "chaîne de mesure").

11 — GIT STATUS (avant publication)
     release_ai_weather.ps1 vérifie : branch == main, git fetch origin, local HEAD == origin/main.
     Bloque la publication si désalignement (évite d'écraser un push distant plus récent).

12 — GIT COMMIT (release_ai_weather.ps1, chemin de publication principal identifié)
     Stage EXCLUSIVEMENT : weather.json, data/current.json, data/history/<date>.json,
     aiweather-capsule/capsules/<y>/<m>/<d>.json, aiweather-capsule/latest.json.
     Refuse si un fichier staged inattendu apparaît (git diff --cached --name-only doit être un
     sous-ensemble exact de la liste canonique). Message : "AI Weather canonical release <date>".

13 — GIT PUSH
     git push origin main. Si échec → throw "PUBLICATION FAILED".
     Chemin alternatif existant : run_ai_weather_pipeline.ps1 -Publish fait un add/commit/push plus
     sommaire (vérifie seulement que aiweather-capsule et le repo weather sont le même worktree Git),
     SANS les contrôles de coverage/alignement origin de release_ai_weather.ps1. À ne pas utiliser en
     parallèle des deux sans clarifier lequel fait foi (voir AUDIT §1 et §6).
```

## Points d'entrée observés (qui appelle quoi)

```
install_ai_weather_task.ps1  →  (tâche planifiée Windows)  →  run_daily_ai_weather.ps1
                                                                     │
                                                     ┌───────────────┼──────────────────────┐
                                                     ▼                                       ▼
                                          build_daily_panel.ps1              run_ai_weather_pipeline.ps1 -Date $Date
                                                                                     │
                                                                    ┌────────────────┼─────────────────────┐
                                                                    ▼                ▼                     ▼
                                                        launch_ai_weather.ps1  aggregate_and_publish   generate_capsule.py (MANQUANT)
                                                        -WaitForCompletion     _weather.ps1 -NoPublish       │
                                                                                                              ▼
                                                                                                      verify_chain.py

release_ai_weather.ps1  ← appelé séparément (manuellement, ou par une 2e tâche planifiée non confirmée à 14:00)
```

**Zone grise à clarifier avec vous** : rien dans les scripts trouvés n'appelle automatiquement
`release_ai_weather.ps1` après `run_daily_ai_weather.ps1`. Soit une tâche planifiée séparée à 14:00
l'appelle (mentionnée en commentaire mais non retrouvée dans `schtasks`), soit ce lancement est
aujourd'hui manuel. À vérifier directement sur votre Planificateur de tâches (AUDIT §8).
