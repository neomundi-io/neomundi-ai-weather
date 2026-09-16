<#
.SYNOPSIS
    Tests for the Phase 1 shadow-mode longitudinal engine.

.DESCRIPTION
    1) Synthetic unit tests against Build-SystemReport (hysteresis, anti-flapping,
       progressive de-escalation, missing-coverage handling, identity caveat).
    2) A real-data regression guard: runs the engine against the actual repository
       data and asserts that NOT ONE public/production file was modified - the
       hard requirement of GO SHADOW MODE - PHASE 1.

    Read-only against the real repository except for writing under
    AI_WEATHER_RUNNER/shadow/, which this test also verifies is the *only* thing
    that changes on disk.
#>

[CmdletBinding()]
param()

$ErrorActionPreference = "Stop"
$here = $PSScriptRoot
$enginePath = Join-Path $here "..\longitudinal_engine.ps1"
$testRepoRoot   = Split-Path (Split-Path $here -Parent) -Parent

. $enginePath

$script:PassCount = 0
$script:FailCount = 0

function Assert-True {
    param([bool]$Condition, [string]$Message)
    if ($Condition) { $script:PassCount++; Write-Host "  [OK] $Message" }
    else { $script:FailCount++; Write-Host "  [FAIL] $Message" -ForegroundColor Red }
}

function New-FakeConfig {
    param(
        [int]$WindowDays = 10,
        [string]$StartDate = "2026-01-01",
        [bool]$OpenAiLikePinning = $true,
        [bool]$MadFloorEnabled = $true
    )
    $pinnedJson = if ($OpenAiLikePinning) { "true" } else { "false" }
    $madFloorJson = if ($MadFloorEnabled) { "true" } else { "false" }
    $json = @"
{
  "baseline": { "window_days": $WindowDays, "dispersion_method": "mad", "start_date": "$StartDate" },
  "mad_floor": { "enabled": $madFloorJson },
  "uncertainty": { "z": 1.645 },
  "deviation_thresholds": { "attention_accrue": 1.0, "attention_renforcee": 2.0, "attention_critique": 3.0 },
  "persistence_days": { "attention_accrue": 2, "attention_renforcee": 3, "attention_critique": 3 },
  "return_to_baseline_days": { "attention_accrue": 2, "attention_renforcee": 3, "attention_critique": 3 },
  "coverage": { "longitudinal_expected_repetitions": 7, "longitudinal_min_scored_repetitions": 5 },
  "event_rules": { "variability_increase_variation_fraction_delta": 0.15 },
  "model_requested_known": {
    "testsys": { "value": "test-model-pinned-2026-01-01", "pinned": $pinnedJson, "verified_in_session": false }
  }
}
"@
    return $json | ConvertFrom-Json
}

function New-SyntheticDates {
    param([int]$Count, [string]$Start = "2026-01-01")
    $d0 = Get-Date $Start
    return @(0..($Count - 1) | ForEach-Object { $d0.AddDays($_).ToString("yyyy-MM-dd") })
}

function New-DayRecord {
    param([double]$Score, [int]$FullyScored = 7, [double]$VariationFraction = 0.0, [string]$ModelDeclared = "test-model-pinned-2026-01-01")
    return [PSCustomObject]@{
        id             = "testsys"
        model_declared = $ModelDeclared
        longitudinal   = [PSCustomObject]@{
            score                 = $Score
            fully_scored          = $FullyScored
            expected_observations = 7
            coverage              = [double]$FullyScored / 7.0
            metrics               = [PSCustomObject]@{ normal = $Score / 100.0; variation = $VariationFraction; factual_alert = 0; incomplete = 0 }
        }
    }
}

# A tight, deterministic 10-day jitter pattern with a known median (95) and a known
# MAD (1), reused across tests so deviation magnitudes are predictable and comparable
# to the 1.0 / 2.0 / 3.0 MAD thresholds instead of accidentally saturating them.
$JitterBaseline = @(94, 96, 95, 93, 97, 95, 96, 94, 95, 96)   # median 95, MAD 1

Write-Host "=== Test 1: systeme parfaitement stable -> reste 'standard' apres la baseline ==="
$dates = New-SyntheticDates -Count 20
$dateToSystems = @{}
for ($i = 0; $i -lt 20; $i++) { $dateToSystems[$dates[$i]] = @{ testsys = (New-DayRecord -Score 95) } }
$cfg = New-FakeConfig -WindowDays 10
$r1 = Build-SystemReport -SystemId "testsys" -Dates $dates -DateToSystems $dateToSystems -Config $cfg
Assert-True ($r1.baseline.status -eq "established") "Baseline etablie apres 10 jours valides"
$postBaseline = @($r1.daily_series | Where-Object { $_.date -gt $r1.baseline.window_end })
$allStandard = (@($postBaseline | Where-Object { $_.state -ne "standard" })).Count -eq 0
Assert-True $allStandard "Tous les jours post-baseline restent 'standard' (systeme parfaitement stable)"
$persistentEvents = @($r1.detected_events | Where-Object { $_.type -eq "persistent_deviation" })
Assert-True ($persistentEvents.Count -eq 0) "Aucun evenement persistent_deviation sur une serie stable"
Assert-True ($r1.baseline.mad_floor_applied -eq $true) "V2.0 : systeme plafonne (MAD brut = 0, cas OpenAI/Anthropic/Qwen) -- le plancher s'active, comme attendu"
$unc1 = $r1.current_longitudinal_state.uncertainty
Assert-True ($null -ne $unc1 -and $unc1.low -le $unc1.mid -and $unc1.mid -le $unc1.high) "V2.0 : le champ 'uncertainty' (Wilson descriptif) est present et coherent (low <= mid <= high)"
$lastValidDay1 = @($r1.daily_series | Where-Object { $_.valid })[-1]
Assert-True ([math]::Abs($unc1.mid - $lastValidDay1.uncertainty.mid) -lt 0.01) "V2.0 : 'uncertainty' au niveau de l'etat courant correspond bien a celui du dernier jour valide de la serie quotidienne"

Write-Host "`n=== Test 2: observation aberrante isolee -> ne change pas l'etat affiche ==="
$dates = New-SyntheticDates -Count 13
$dateToSystems = @{}
for ($i = 0; $i -lt 10; $i++) { $dateToSystems[$dates[$i]] = @{ testsys = (New-DayRecord -Score $JitterBaseline[$i]) } }
$dateToSystems[$dates[10]] = @{ testsys = (New-DayRecord -Score 40) }   # outlier isole, tres au-dela de tous les seuils
$dateToSystems[$dates[11]] = @{ testsys = (New-DayRecord -Score 95) }
$dateToSystems[$dates[12]] = @{ testsys = (New-DayRecord -Score 96) }
$cfg = New-FakeConfig -WindowDays 10 -MadFloorEnabled $false   # teste l'hysteresis isolement du plancher (MAD reel = 1, synthetique)
$r2 = Build-SystemReport -SystemId "testsys" -Dates $dates -DateToSystems $dateToSystems -Config $cfg
$outlierDay = $r2.daily_series | Where-Object { $_.date -eq $dates[10] }
Assert-True ($outlierDay.state -eq "standard") "Le jour aberrant isole reste classe 'standard' (pas d'escalade sur 1 jour)"
$bdd = @($r2.detected_events | Where-Object { $_.type -eq "behavioral_deviation_detected" -and $_.date -eq $dates[10] })
Assert-True ($bdd.Count -eq 1) "behavioral_deviation_detected est bien emis pour le jour isole"
$persistentEvents2 = @($r2.detected_events | Where-Object { $_.type -eq "persistent_deviation" })
Assert-True ($persistentEvents2.Count -eq 0) "Aucun persistent_deviation pour une seule journee aberrante"

Write-Host "`n=== Test 3: rupture persistante (magnitude controlee, ~1.5 MAD) -> escalade + persistent_deviation ==="
$dates = New-SyntheticDates -Count 15
$dateToSystems = @{}
for ($i = 0; $i -lt 10; $i++) { $dateToSystems[$dates[$i]] = @{ testsys = (New-DayRecord -Score $JitterBaseline[$i]) } }
for ($i = 10; $i -lt 15; $i++) { $dateToSystems[$dates[$i]] = @{ testsys = (New-DayRecord -Score 93.5) } }   # dev = -1.5 MAD -> tier1 uniquement
$cfg = New-FakeConfig -WindowDays 10 -MadFloorEnabled $false   # teste l'hysteresis isolement du plancher (MAD reel = 1, synthetique)
$r3 = Build-SystemReport -SystemId "testsys" -Dates $dates -DateToSystems $dateToSystems -Config $cfg
$pd3 = @($r3.detected_events | Where-Object { $_.type -eq "persistent_deviation" -and $_.tier -eq "attention_accrue" })
Assert-True ($pd3.Count -ge 1) "persistent_deviation (attention_accrue) declenche apres N jours consecutifs de deviation"
$lastDay = $r3.daily_series[$r3.daily_series.Count - 1]
Assert-True ($lastDay.state -eq "attention_accrue") "L'etat final est 'attention_accrue' (deviation moderee et persistante), pas 'critique'"
$pdRenforcee3 = @($r3.detected_events | Where-Object { $_.type -eq "persistent_deviation" -and $_.tier -ne "attention_accrue" })
Assert-True ($pdRenforcee3.Count -eq 0) "Une deviation de magnitude tier1 seule n'escalade jamais au-dela de 'attention_accrue'"
Assert-True ($r3.baseline.mad_floor_applied -eq $false) "V2.0 : MAD reel (14, non degenere) -- le plancher ne s'applique pas ici, comme attendu (cas Mistral)"
Assert-True ($r3.baseline.effective_mad -eq $r3.baseline.mad) "V2.0 : effective_mad == mad quand le plancher ne s'applique pas"

Write-Host "`n=== Test 3bis (V2.0, lancement) : correction du faux positif 'critique' sur baseline MAD=0-par-mode (cas Perplexity) ==="
$datesFloor = New-SyntheticDates -Count 15
$dateToSystemsFloor = @{}
for ($i = 0; $i -lt 10; $i++) { $dateToSystemsFloor[$datesFloor[$i]] = @{ testsys = (New-DayRecord -Score 71) } }   # baseline plate -> MAD=0
for ($i = 10; $i -lt 15; $i++) { $dateToSystemsFloor[$datesFloor[$i]] = @{ testsys = (New-DayRecord -Score 57) } }  # 1 seul pas de grille en dessous, persistant
$cfgWithFloor = New-FakeConfig -WindowDays 10 -MadFloorEnabled $true
$cfgNoFloor   = New-FakeConfig -WindowDays 10 -MadFloorEnabled $false
$rFloor   = Build-SystemReport -SystemId "testsys" -Dates $datesFloor -DateToSystems $dateToSystemsFloor -Config $cfgWithFloor
$rNoFloor = Build-SystemReport -SystemId "testsys" -Dates $datesFloor -DateToSystems $dateToSystemsFloor -Config $cfgNoFloor
Assert-True ($rFloor.baseline.mad -eq 0) "Baseline plate a 71 -> MAD brut bien nul (reproduit le regime Perplexity)"
Assert-True ($rFloor.baseline.mad_floor_applied -eq $true) "Le plancher s'active bien quand MAD brut = 0"
$lastFloor = $rFloor.daily_series[$rFloor.daily_series.Count - 1]
Assert-True ($lastFloor.state -ne "attention_critique") "AVEC plancher : une deviation d'un seul pas de grille, meme persistante, n'atteint JAMAIS 'attention_critique' -- corrige le faux positif Perplexity"
Assert-True ($lastFloor.state -eq "attention_accrue") "AVEC plancher : cette deviation modeste plafonne a 'attention_accrue', conforme au calcul (~1.96 unite de MAD-plancher, sous le seuil 'renforcee')"
$lastNoFloor = $rNoFloor.daily_series[$rNoFloor.daily_series.Count - 1]
Assert-True ($lastNoFloor.state -eq "attention_critique") "SANS plancher (ancien comportement, epsilon=0.0001) : la meme deviation modeste saute bien directement a 'attention_critique' -- confirme que c'est le bug reellement corrige, pas un non-probleme"

Write-Host "`n=== Test 4: retour a la baseline -> desescalade puis evenement return_to_baseline ==="
$dates = New-SyntheticDates -Count 19
$dateToSystems = @{}
for ($i = 0; $i -lt 10; $i++) { $dateToSystems[$dates[$i]] = @{ testsys = (New-DayRecord -Score $JitterBaseline[$i]) } }
for ($i = 10; $i -lt 15; $i++) { $dateToSystems[$dates[$i]] = @{ testsys = (New-DayRecord -Score 93.5) } }
for ($i = 15; $i -lt 19; $i++) { $dateToSystems[$dates[$i]] = @{ testsys = (New-DayRecord -Score 95) } }
$cfg = New-FakeConfig -WindowDays 10 -MadFloorEnabled $false   # teste l'hysteresis isolement du plancher (MAD reel = 1, synthetique)
$r4 = Build-SystemReport -SystemId "testsys" -Dates $dates -DateToSystems $dateToSystems -Config $cfg
$rtb = @($r4.detected_events | Where-Object { $_.type -eq "return_to_baseline" })
Assert-True ($rtb.Count -ge 1) "return_to_baseline se declenche apres retour durable sous le seuil"
$lastDay4 = $r4.daily_series[$r4.daily_series.Count - 1]
Assert-True ($lastDay4.state -eq "standard") "L'etat final revient a 'standard' apres desescalade complete"
$deescalationDates = @($rtb | ForEach-Object { $_.date })
Assert-True ($deescalationDates.Count -ge 1 -and $deescalationDates[0] -gt $dates[14]) "Le retour a la baseline survient apres la fin de la rupture, jamais avant"

Write-Host "`n=== Test 5: couverture insuffisante -> insufficient_data, jamais compte comme standard, ne casse pas le streak ==="
$dates = New-SyntheticDates -Count 14
$dateToSystems = @{}
for ($i = 0; $i -lt 10; $i++) { $dateToSystems[$dates[$i]] = @{ testsys = (New-DayRecord -Score $JitterBaseline[$i]) } }
$dateToSystems[$dates[10]] = @{ testsys = (New-DayRecord -Score 93.5) }             # violation jour 1 (valide)
$dateToSystems[$dates[11]] = @{ testsys = (New-DayRecord -Score 93.5 -FullyScored 3) } # couverture insuffisante au milieu
$dateToSystems[$dates[12]] = @{ testsys = (New-DayRecord -Score 93.5) }             # violation jour 2 (valide)
$dateToSystems[$dates[13]] = @{ testsys = (New-DayRecord -Score 93.5) }             # violation jour 3 (valide)
$cfg = New-FakeConfig -WindowDays 10 -MadFloorEnabled $false   # teste l'hysteresis isolement du plancher (MAD reel = 1, synthetique)
$r5 = Build-SystemReport -SystemId "testsys" -Dates $dates -DateToSystems $dateToSystems -Config $cfg
$gapDay = $r5.daily_series | Where-Object { $_.date -eq $dates[11] }
Assert-True ($gapDay.state -eq "insufficient_data") "Le jour a couverture insuffisante est marque 'insufficient_data'"
Assert-True ($gapDay.state -ne "standard") "Un jour a couverture insuffisante n'est jamais lu comme 'standard' (absence de donnee != stabilite)"
$covAnomaly = @($r5.detected_events | Where-Object { $_.type -eq "coverage_anomaly" -and $_.date -eq $dates[11] })
Assert-True ($covAnomaly.Count -eq 1) "coverage_anomaly est emis pour le jour a couverture insuffisante"
$pd5 = @($r5.detected_events | Where-Object { $_.type -eq "persistent_deviation" })
Assert-True ($pd5.Count -ge 1) "Le streak de deviation continue de se construire malgre le jour manquant intercale (jour manquant neutre, ni pour ni contre)"

Write-Host "`n=== Test 6: identite non epinglee -> model_identity_unverified emis une fois (system_wide) ==="
$dates = New-SyntheticDates -Count 12
$dateToSystems = @{}
for ($i = 0; $i -lt 10; $i++) { $dateToSystems[$dates[$i]] = @{ testsys = (New-DayRecord -Score $JitterBaseline[$i]) } }
$dateToSystems[$dates[10]] = @{ testsys = (New-DayRecord -Score 95) }
$dateToSystems[$dates[11]] = @{ testsys = (New-DayRecord -Score 95) }
$cfg = New-FakeConfig -WindowDays 10 -OpenAiLikePinning $false
$r6 = Build-SystemReport -SystemId "testsys" -Dates $dates -DateToSystems $dateToSystems -Config $cfg
Assert-True ($r6.system_identity.identity_status -eq "unknown") "Un alias non epingle est classe 'unknown', pas 'declared'"
$idEvents = @($r6.detected_events | Where-Object { $_.type -eq "model_identity_unverified" })
Assert-True ($idEvents.Count -eq 1) "model_identity_unverified est emis exactement une fois (pas une fois par jour)"
Assert-True ($idEvents[0].scope -eq "system_wide") "model_identity_unverified est bien un evenement de portee systeme, pas quotidienne"

Write-Host "`n=== Test 7 (garde-fou reel) : le moteur ne modifie AUCUN fichier public/production ==="
Write-Host "  repoRoot resolu : $testRepoRoot"
$filesToWatch = @(
    (Join-Path $testRepoRoot "weather.json"),
    (Join-Path $testRepoRoot "data\current.json"),
    (Join-Path $testRepoRoot "data\capsule-index.json"),
    (Join-Path $testRepoRoot "aiweather-capsule\latest.json"),
    (Join-Path $testRepoRoot "aiweather-capsule\capsules\2026\08\17.json"),
    (Join-Path $testRepoRoot "aiweather-capsule\capsules\2026\08\21.json"),
    (Join-Path $testRepoRoot "aiweather-capsule\capsules\2026\09\16.json"),
    (Join-Path $testRepoRoot "index.html"),
    (Join-Path $testRepoRoot "scripts\weather-data.js")
)
$hashesBefore = @{}
foreach ($f in $filesToWatch) { $hashesBefore[$f] = (Get-FileHash -LiteralPath $f -Algorithm SHA256).Hash }

Push-Location $testRepoRoot
$gitStatusBefore = @(git status --porcelain 2>$null)
Pop-Location

$realReport = & $enginePath -Quiet
Assert-True ($realReport.systems.Count -eq 12) "Le rejeu reel produit bien 12 systemes"
Assert-True ($realReport.weather_authority -eq $false) "Le rapport shadow se declare lui-meme non-autoritatif (weather_authority:false)"
Assert-True ($realReport.date_range_processed.excluded_pre_split_dates -contains "2026-08-16") "Le jour demo/placeholder 2026-08-16 (demo:true) est bien exclu du rejeu"
Assert-True ($realReport.date_range_processed.first -ge "2026-08-21") "Le premier jour reellement traite n'est jamais anterieur au 21/08 (fenetre protocole v0.2 confirmee)"

$hashesAfter = @{}
foreach ($f in $filesToWatch) { $hashesAfter[$f] = (Get-FileHash -LiteralPath $f -Algorithm SHA256).Hash }
$anyChanged = $false
foreach ($f in $filesToWatch) { if ($hashesBefore[$f] -ne $hashesAfter[$f]) { $anyChanged = $true; Write-Host "  [FAIL] Modifie: $f" -ForegroundColor Red } }
Assert-True (-not $anyChanged) "Aucun des $($filesToWatch.Count) fichiers publics/production surveilles n'a ete modifie par le moteur"

# Compare git status BEFORE vs AFTER running the engine (not against a hardcoded
# allowlist, since the working tree may already carry unrelated untracked clutter
# from other work) - the ONLY delta the engine itself is allowed to introduce is
# new untracked files under AI_WEATHER_RUNNER/shadow/.
Push-Location $testRepoRoot
$gitStatusAfter = @(git status --porcelain 2>$null)
Pop-Location
$newLines = @(Compare-Object -ReferenceObject $gitStatusBefore -DifferenceObject $gitStatusAfter -PassThru |
    Where-Object { $_ -and $_.SideIndicator -eq "=>" })
$unexpectedNew = @($newLines | Where-Object { $_ -notmatch "AI_WEATHER_RUNNER[\\/]shadow[\\/]" })
Assert-True ($unexpectedNew.Count -eq 0) "L'execution du moteur n'introduit, dans git status, aucune nouveaute hors de AI_WEATHER_RUNNER/shadow/ ($($unexpectedNew.Count) inattendu(s) : $($unexpectedNew -join '; '))"

Write-Host "`n=== Resultats : $script:PassCount reussis / $($script:PassCount + $script:FailCount) ==="
if ($script:FailCount -gt 0) {
    Write-Host "$script:FailCount test(s) en echec." -ForegroundColor Red
    exit 1
}
else {
    Write-Host "Tous les tests sont passes." -ForegroundColor Green
    exit 0
}
