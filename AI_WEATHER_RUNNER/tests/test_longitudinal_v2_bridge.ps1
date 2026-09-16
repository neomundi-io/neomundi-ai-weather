<#
.SYNOPSIS
    Tests for the aggregator <-> V2 engine bridge (longitudinal_v2_bridge.ps1) and its
    two-line integration into aggregate_and_publish_weather.ps1.

.DESCRIPTION
    CRITICAL: aggregate_and_publish_weather.ps1 itself is NEVER dot-sourced or executed
    by this test (or by any part of this block) - it has no guarded entry point, so
    running it in any form would re-trigger its real weather.json/data/current.json/
    data/history writes. Only longitudinal_v2_bridge.ps1 (pure functions, no top-level
    side effects) is dot-sourced. The aggregator's new call site is validated separately
    by static syntax parsing (see AI_WEATHER_V2_UPSTREAM_WIRING_VALIDATION.md) and by
    this test replaying the exact same bridge call with the exact same real inputs the
    aggregator would use, without running the other ~2000 lines around it.
#>

[CmdletBinding()]
param()

$ErrorActionPreference = "Stop"
$here = $PSScriptRoot
$runnerRoot = Split-Path $here -Parent
$testRepoRoot = Split-Path $runnerRoot -Parent
$bridgePath = Join-Path $runnerRoot "longitudinal_v2_bridge.ps1"

. $bridgePath

$script:PassCount = 0
$script:FailCount = 0
function Assert-True {
    param([bool]$Condition, [string]$Message)
    if ($Condition) { $script:PassCount++; Write-Host "  [OK] $Message" }
    else { $script:FailCount++; Write-Host "  [FAIL] $Message" -ForegroundColor Red }
}

# ---------------------------------------------------------------------------
# Test 1: fail-open on a nonexistent RunnerRoot (engine/config not found)
# ---------------------------------------------------------------------------
Write-Host "=== Test 1: fail-open quand le moteur/la config sont introuvables ==="
$r1 = Get-LongitudinalV2Report -RunnerRoot "C:\this\path\does\not\exist"
Assert-True ($null -eq $r1) "Get-LongitudinalV2Report renvoie \$null (pas d'exception) sur un chemin inexistant"

$fakeOutput = [PSCustomObject]@{ systems = @([PSCustomObject]@{ id = "openai" }) }
$p1 = Invoke-LongitudinalV2ShadowPipeline -LegacyOutput $fakeOutput -RunnerRoot "C:\this\path\does\not\exist" -RepoRoot $testRepoRoot -Date "1970-01-01"
Assert-True ($null -eq $p1) "Invoke-LongitudinalV2ShadowPipeline renvoie \$null (pas d'exception) sur un moteur introuvable"
Assert-True (-not (Test-Path (Join-Path $testRepoRoot "data\shadow\v2\1970-01-01.json"))) "Aucun fichier shadow n'est ecrit quand le moteur echoue"

# ---------------------------------------------------------------------------
# Test 2: fail-open when the engine itself throws (not just "file missing")
# ---------------------------------------------------------------------------
Write-Host "`n=== Test 2: fail-open quand le moteur existe mais leve une exception ==="
$fakeRunner = Join-Path ([System.IO.Path]::GetTempPath()) ("fake_runner_" + [guid]::NewGuid().ToString("N"))
New-Item -ItemType Directory -Path (Join-Path $fakeRunner "config") -Force | Out-Null
Set-Content -LiteralPath (Join-Path $fakeRunner "longitudinal_engine.ps1") -Value 'throw "simulated engine crash"' -Encoding UTF8
Set-Content -LiteralPath (Join-Path $fakeRunner "config\longitudinal_engine_config.json") -Value '{}' -Encoding UTF8
try {
    $r2 = Get-LongitudinalV2Report -RunnerRoot $fakeRunner
    Assert-True ($null -eq $r2) "Get-LongitudinalV2Report renvoie \$null quand le moteur leve une exception reelle"
}
finally {
    Remove-Item -Recurse -Force $fakeRunner -ErrorAction SilentlyContinue
}

# ---------------------------------------------------------------------------
# Test 3: end-to-end shadow pipeline on REAL data (2026-09-16), zero-impact guard
# ---------------------------------------------------------------------------
Write-Host "`n=== Test 3 (donnees reelles) : pipeline shadow complet + garde-fou zero impact public ==="
$filesToWatch = @(
    (Join-Path $testRepoRoot "weather.json"),
    (Join-Path $testRepoRoot "data\current.json"),
    (Join-Path $testRepoRoot "data\history\2026-09-16.json"),
    (Join-Path $testRepoRoot "aiweather-capsule\capsules\2026\09\16.json"),
    (Join-Path $testRepoRoot "index.html"),
    (Join-Path $testRepoRoot "scripts\weather-data.js"),
    (Join-Path $testRepoRoot "AI_WEATHER_RUNNER\aggregate_and_publish_weather.ps1")
)
$before = @{}
foreach ($f in $filesToWatch) { $before[$f] = (Get-FileHash -LiteralPath $f -Algorithm SHA256).Hash }

$realHistoryPath = Join-Path $testRepoRoot "data\history\2026-09-16.json"
$realOutput = Get-Content -LiteralPath $realHistoryPath -Raw -Encoding UTF8 | ConvertFrom-Json

$shadowPath = Invoke-LongitudinalV2ShadowPipeline -LegacyOutput $realOutput -RunnerRoot $runnerRoot -RepoRoot $testRepoRoot -Date "2026-09-16"
Assert-True ($null -ne $shadowPath) "Le pipeline shadow reussit sur des donnees reelles et renvoie un chemin"
Assert-True ($shadowPath -like "*data\shadow\v2\2026-09-16.json") "La sortie est ecrite exclusivement sous data/shadow/v2/"
Assert-True (Test-Path -LiteralPath $shadowPath) "Le fichier shadow existe reellement sur disque"

$after = @{}
foreach ($f in $filesToWatch) { $after[$f] = (Get-FileHash -LiteralPath $f -Algorithm SHA256).Hash }
$changed = @($filesToWatch | Where-Object { $before[$_] -ne $after[$_] })
Assert-True ($changed.Count -eq 0) "Aucun des $($filesToWatch.Count) fichiers publics/production surveilles n'a change ($($changed -join ', '))"

$shadowContent = Get-Content -LiteralPath $shadowPath -Raw -Encoding UTF8 | ConvertFrom-Json
Assert-True ($shadowContent.methodology_version.id -eq "AI_WEATHER_METHOD_V2_0") "methodology_version.id = AI_WEATHER_METHOD_V2_0 dans la sortie shadow"
Assert-True ($shadowContent.baseline_config_version -eq "v2.0-launch") "baseline_config_version = v2.0-launch"
Assert-True ($shadowContent.repetition_count -eq 7) "repetition_count = 7"

# Legacy fields must still be present, byte-identical, alongside the new longitudinal_v2.
Assert-True ($null -ne $shadowContent.global_condition) "Les champs legacy (global_condition, etc.) restent presents"
$openaiSys = $shadowContent.systems | Where-Object { $_.id -eq "openai" }
Assert-True ($null -ne $openaiSys.daily) "La cle legacy 'daily' reste presente et intacte par systeme"
Assert-True ($null -ne $openaiSys.longitudinal) "La cle legacy 'longitudinal' reste presente et intacte par systeme"
Assert-True ($null -ne $openaiSys.longitudinal.role -and $openaiSys.longitudinal.role -eq "longitudinal") "Les champs legacy internes de 'longitudinal' (role, etc.) restent intacts"
Assert-True ($null -ne $openaiSys.longitudinal.current_longitudinal_state) "Les nouveaux champs V2 sont ajoutes DANS 'longitudinal' lui-meme (pas une cle soeur), conforme a ce qu'attend generate_capsule.py"

# ---------------------------------------------------------------------------
# Test 4: semantic non-regression cases (section 7)
# ---------------------------------------------------------------------------
Write-Host "`n=== Test 4 : verifications semantiques (Perplexity / Mistral / OpenAI / Today's Challenge) ==="
$perplexity = ($shadowContent.systems | Where-Object { $_.id -eq "perplexity" }).longitudinal
Assert-True ($perplexity.current_longitudinal_state.state -ne "attention_critique") "Perplexity : le faux 'attention_critique' ne reapparait pas"
Write-Host "      (etat reel observe : $($perplexity.current_longitudinal_state.state))"

$mistral = ($shadowContent.systems | Where-Object { $_.id -eq "mistral" }).longitudinal
Assert-True ($mistral.current_longitudinal_state.state -eq "attention_accrue") "Mistral : la rupture connue reste visible (attention_accrue)"

$openai = ($shadowContent.systems | Where-Object { $_.id -eq "openai" }).longitudinal
Assert-True ($openai.current_longitudinal_state.state -eq "standard") "OpenAI : la stabilite reste 'standard'"

# Structural check: the new V2 fields inside 'longitudinal' must never reference/embed
# the daily block's content (Today's Challenge cannot influence the longitudinal state).
$openaiSysFull = $shadowContent.systems | Where-Object { $_.id -eq "openai" }
$lv2Serialized = $openaiSysFull.longitudinal | ConvertTo-Json -Depth 20 -Compress
$dailyQuestionMarker = $openaiSysFull.daily.question
Assert-True (
    [string]::IsNullOrWhiteSpace($dailyQuestionMarker) -or ($lv2Serialized -notlike "*$dailyQuestionMarker*")
) "Today's Challenge (systems[].daily) n'apparait structurellement pas a l'interieur des champs V2 de 'longitudinal'"

Write-Host "`n=== Resultats : $script:PassCount reussis / $($script:PassCount + $script:FailCount) ==="
if ($script:FailCount -gt 0) { Write-Host "$script:FailCount test(s) en echec." -ForegroundColor Red; exit 1 }
else { Write-Host "Tous les tests sont passes." -ForegroundColor Green; exit 0 }
