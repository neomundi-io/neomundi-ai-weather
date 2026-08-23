# AI WEATHER — CLEANUP PLAN (PROPOSITION — RIEN N'EST ENCORE DÉPLACÉ)

Ce document est une proposition. Aucun fichier n'a été déplacé, renommé ou supprimé.
Toute action listée ici nécessite votre validation avant exécution.

---

## A. Corrections à traiter EN PRIORITÉ (bugs, pas du nettoyage)

Ces deux points bloquent la fiabilité du pipeline et ne sont pas des "vieux fichiers" — ce sont des
incohérences actives dans des scripts ACTIFS. Recommandation : les traiter avant tout archivage.

1. ✅ **FAIT (2026-08-23)** — `run_weather_moonshot_v1_2.ps1` ligne 32 corrigée :
   `[string]$PanelFile = ".\data\panels\ai_weather_panel.csv",`
   Sauvegarde créée avant modification : `run_weather_moonshot_v1_2.ps1.bak_2026-08-23`.
   Test Kimi seul en `-SmokeTest` exécuté en conditions réelles (vrai appel API Moonshot + NeoMundi) :
   `prompt_id` obtenu = `daily-2026-08-23`, `error` vide, 1/1 ligne sauvegardée. Correctif confirmé fonctionnel.
   Fichier de test isolé : `results\moonshot_kimi-k3_kimi_fix_smoketest_20260823T133600Z_*` (hors dossier
   daté, n'interfère pas avec la campagne officielle du jour — à nettoyer plus tard si souhaité).

2. **`aiweather-capsule\generate_capsule.py` introuvable** (AUDIT §4) — bloque `run_ai_weather_pipeline.ps1`
   dès la validation des prérequis. Avant toute correction : confirmer avec vous si ce script existe
   ailleurs (autre machine, autre commit, dans un des `.zip` d'ARCHIVES) ou s'il faut le reconstruire.
   **Je ne recrée pas ce fichier sans votre confirmation** — un générateur de capsule mal reconstruit
   pourrait casser la hash-chain existante.

3. **`install_ai_weather_task.ps1` désynchronisé de `run_daily_ai_weather.ps1`** (AUDIT §2) —
   ne pas relancer cet installeur tel quel : il produirait une tâche planifiée appelant un paramètre
   (`-TargetUtcHour`) que le wrapper actuel ne reconnaît pas. À corriger seulement après avoir confirmé
   avec vous ce que fait réellement la tâche planifiée existante (si elle existe).

---

## B. Candidats à archivage (déplacement vers `AI_WEATHER_RUNNER\ARCHIVES\LEGACY_2026-08\`)

Pour chacun : vérifié qu'aucun script actif ne le référence (grep exhaustif, voir AUDIT §5/§7).
Aucune tâche Windows confirmée ne les cible (AUDIT §8 — à reconfirmer par vous en direct).

| Fichier | Raison | Confiance |
|---|---|---|
| `run_ai_weather.ps1` | Appelle `run_provider.ps1`, absent hors ARCHIVES → cassé, non appelé ailleurs | Haute |
| `run_ai_weather_full.ps1` | Suite de commandes commentées, pas un vrai script param., remplacé par `run_ai_weather_pipeline.ps1` | Haute |
| `aggregate_and_publish_weather_PRE_MULTI_SIGNAL.ps1` | Snapshot explicite pré-refonte, nom auto-descriptif | Haute |
| `FULL_AUTOMATISATION\launch_ai_weather.ps1` | Brouillon antérieur du launcher (`-Unattended`/`-TimeoutMinutes`), diverge de l'actif | Haute |
| `FULL_AUTOMATISATION\Runner_patched.zip` | Archive zip d'une itération antérieure, déjà dans un dossier "FULL_AUTOMATISATION" non actif | Moyenne |
| `weather_models.json` | Non référencé par aucun script actif trouvé | Moyenne — à confirmer (peut être lu par un HTML/JS front-end non audité ici) |
| `index_last.html` | Non référencé, nom suggère un ancien instantané de build | Moyenne |
| `AI_WEATHER_RUNNER\data\daily_questions.csv` | Doublon apparent de `config\daily_questions.csv`, non référencé | **UNKNOWN — DO NOT MOVE tant que la structure des deux fichiers n'est pas comparée colonne à colonne** |
| `AI_WEATHER_RUNNER\data\panels\Panel_vert\ai_weather_panel.csv` | Sous-dossier isolé, non référencé | **UNKNOWN — DO NOT MOVE** (nom "Panel_vert" suggère un test manuel volontaire ; à confirmer avec vous) |

Ne PAS archiver (déjà couvert par `.gitignore` ou déjà dans une zone d'archive reconnue par le projet
lui-même) :
- `AI_WEATHER_RUNNER\ARCHIVES\*` — déjà archivé par vous/un run précédent, aucune action.
- `AI_WEATHER_RUNNER\data\panels\ai_weather_panel_backup_*.csv` — sauvegardes automatiques légitimes de
  `build_daily_panel.ps1`. Suggestion (optionnelle, plus tard) : les faire écrire dans un sous-dossier
  `data\panels\backups\` plutôt qu'à plat, pour lisibilité — pas urgent.
- `aiweather-capsule-smoke\` — généré et nettoyé automatiquement par `run_ai_weather_pipeline.ps1
  -SmokeTest` (le script fait lui-même `Remove-Item -Recurse -Force` dessus avant régénération).
- `aiweather-capsule.zip` (racine) — à clarifier avec vous : pourrait être une sauvegarde manuelle de
  sécurité de tout le moteur de capsule. Ne pas toucher sans confirmation.

---

## C. Ce que je NE propose PAS de toucher

- Les 12 runners actifs (`run_weather_*.ps1`) — fonctionnels, un seul bug ponctuel isolé (§A.1).
- `launch_ai_weather.ps1`, `aggregate_and_publish_weather.ps1`, `release_ai_weather.ps1`,
  `build_daily_panel.ps1` — chaîne active vérifiée fonctionnelle de bout en bout (hors §A).
- `config\daily_questions.csv`, `config\longitudinal_probe.csv`, `config\providers.json`,
  `config\sentinel.json` — sources de vérité actuelles, conformes à votre description.
- `aiweather-capsule\verify_chain.py`, `aiweather-capsule\capsules\`, `aiweather-capsule\latest.json`
  — chaîne de hash vérifiée saine, ne jamais modifier sans nécessité absolue.

---

## D. Procédure d'exécution proposée (quand vous validez)

1. Créer `AI_WEATHER_RUNNER\ARCHIVES\LEGACY_2026-08\` (dossier neuf, vide).
2. Déplacer un fichier à la fois depuis la liste B "Haute confiance" uniquement (pas les UNKNOWN).
3. Après chaque déplacement : relancer `launch_ai_weather.ps1 -SmokeTest` (Test 4, un seul cycle rapide)
   pour confirmer qu'aucun chemin cassé n'apparaît.
4. Ne traiter les entrées "UNKNOWN — DO NOT MOVE" qu'après votre confirmation explicite dossier par dossier.
5. Corriger §A.1 (Kimi) en premier, avec sauvegarde horodatée, puis Test 3 (Kimi seul) avant tout run complet.
6. Ne pas toucher à §A.2 et §A.3 sans votre validation — ce sont des décisions produit, pas du nettoyage.

Rien dans ce plan n'est exécuté automatiquement. Dites-moi par quoi vous voulez commencer :
le fix Kimi (§A.1), la clarification `generate_capsule.py` (§A.2), ou l'archivage "haute confiance" (§B).
