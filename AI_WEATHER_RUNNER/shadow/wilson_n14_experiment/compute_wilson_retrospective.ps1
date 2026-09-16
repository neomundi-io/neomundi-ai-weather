<#
.SYNOPSIS
    Wilson N=7 experiment - RETROSPECTIVE arm (zero new API cost).

.DESCRIPTION
    Computes, for all 12 systems, over the entire existing real history
    (data/history/*.json + the 21/08 capsule fallback, exactly as
    longitudinal_engine.ps1 already does), two configurations side by side:
      - current_n7   : today's production formula (100*normalCount/fullyScored)
      - wilson_n7     : Wilson 90% interval on the same decision counts

    This script makes ZERO new API calls and reads ONLY already-published,
    already-existing files. It does not touch any runner, capsule, widget,
    public file, or production configuration. Output is written exclusively
    under AI_WEATHER_RUNNER/shadow/wilson_n14_experiment/output/.

    The N=14 arm (current_n14 / wilson_n14) is intentionally NOT computed
    here - it requires real repetitions 8-14 that do not exist yet. See
    fetch_n14_pilot.ps1 for that arm, which is a separate, explicitly-gated
    step because it makes real, paid API calls.
#>

[CmdletBinding()]
param(
    [string]$RepoRoot,
    [string]$EngineConfigPath,
    [string]$WilsonConfigPath,
    [string]$OutputDir,
    [double]$ZOverride = -1,
    [string]$RunLabel = "primary"
)

$ErrorActionPreference = "Stop"

# $PSScriptRoot has been observed empty in this environment when this script is the
# direct target of `powershell -File` (though populated when dot-sourced/called from
# another running script) - resolve a robust fallback via $MyInvocation instead of
# relying on $PSScriptRoot inside the param() defaults above.
$myRoot = $PSScriptRoot
if ([string]::IsNullOrWhiteSpace($myRoot)) { $myRoot = Split-Path -Parent $MyInvocation.MyCommand.Path }
if ([string]::IsNullOrWhiteSpace($RepoRoot)) { $RepoRoot = (Resolve-Path (Join-Path $myRoot "..\..\..")).Path }
if ([string]::IsNullOrWhiteSpace($EngineConfigPath)) { $EngineConfigPath = Join-Path $myRoot "..\..\config\longitudinal_engine_config.json" }
if ([string]::IsNullOrWhiteSpace($WilsonConfigPath)) { $WilsonConfigPath = Join-Path $myRoot "wilson_config.json" }
if ([string]::IsNullOrWhiteSpace($OutputDir)) { $OutputDir = Join-Path $myRoot "output" }

# Reuse the Phase 1 engine's data-loading functions (Read-HistoryDay, Get-AvailableDates,
# Get-IdentityStatus, Get-Median) instead of duplicating them. Dot-sourced, so its guarded
# entry point does not run and it writes nothing on its own.
$enginePath = Join-Path $myRoot "..\..\longitudinal_engine.ps1"
# PowerShell variable names are case-insensitive: dot-sourcing the engine re-runs its
# own param() block in this scope and silently overwrites $RepoRoot (same name as
# this script's own $RepoRoot, just different case) with the engine's own default -
# save and restore it explicitly (see AI_WEATHER_V2_SHADOW_VALIDATION.md, same bug
# found and fixed once already in the Phase 1 test suite).
# Also true for $OutputDir (both scripts declare a parameter of that exact name).
$resolvedRepoRoot = $RepoRoot
$resolvedOutputDir = $OutputDir
. $enginePath
$RepoRoot = $resolvedRepoRoot
$OutputDir = $resolvedOutputDir

function Get-WilsonInterval {
    param([int]$K, [int]$N, [double]$Z = 1.645)
    if ($N -le 0) { return $null }
    $p = $K / [double]$N
    $denom = 1 + ($Z * $Z) / $N
    $centre = ($p + ($Z * $Z) / (2 * $N)) / $denom
    $halfw = $Z * [math]::Sqrt(($p * (1 - $p) / $N) + (($Z * $Z) / (4.0 * $N * $N))) / $denom
    # NOTE: literal 0/1 (Int32) here would make PowerShell pick the Max(Int32,Int32)
    # overload and round the double argument to the nearest integer - always use
    # 0.0/1.0 (Double) literals to force the correct Max(Double,Double) overload.
    $low = [math]::Max(0.0, $centre - $halfw)
    $high = [math]::Min(1.0, $centre + $halfw)
    return [ordered]@{
        k = $K; n = $N
        low = [math]::Round(100 * $low, 2)
        mid = [math]::Round(100 * $centre, 2)
        high = [math]::Round(100 * $high, 2)
    }
}

function Test-IntervalOverlap {
    # Kept for diagnostic/reporting purposes only (shown in output). NOT used to decide
    # significance: comparing two raw confidence intervals for overlap is a well-known
    # statistically CONSERVATIVE (under-powered) proxy for testing whether two
    # proportions differ - it was tried first in this experiment and empirically failed
    # to detect the already-confirmed Mistral rupture (see AI_WEATHER_V2_WILSON_N14_RESULTS.md
    # section on this correction). Test-ProportionsDiffer below is the actual decision rule.
    param($A, $B)
    if (-not $A -or -not $B) { return $null }
    return -not ($A.high -lt $B.low -or $B.high -lt $A.low)
}

function Test-ProportionsDiffer {
    # Two-sample test for a difference between two proportions (day vs pooled baseline),
    # using the standard Wald/Wilson-style pooled standard error. This is the statistically
    # correct way to ask "does today's rate differ from the baseline rate", as opposed to
    # eyeballing whether two independently-computed confidence intervals overlap.
    param([int]$K1, [int]$N1, [int]$K2, [int]$N2, [double]$Z = 1.645)
    if ($N1 -le 0 -or $N2 -le 0) { return $null }
    $p1 = $K1 / [double]$N1
    $p2 = $K2 / [double]$N2
    $se = [math]::Sqrt(($p1 * (1 - $p1) / $N1) + ($p2 * (1 - $p2) / $N2))
    if ($se -eq 0) { return ($p1 -ne $p2) }
    $zscore = ($p1 - $p2) / $se
    return ([math]::Abs($zscore) -ge $Z)
}

$engineConfig = Get-EngineConfig -Path $EngineConfigPath
$wilsonConfig = Get-EngineConfig -Path $WilsonConfigPath
$z = if ($ZOverride -gt 0) { $ZOverride } else { $wilsonConfig.methodology_version.z }

$historyDir  = Join-Path $RepoRoot "data\history"
$capsuleRoot = Join-Path $RepoRoot "aiweather-capsule\capsules"
$dates = Get-AvailableDates -HistoryDir $historyDir -CapsuleRoot $capsuleRoot -Config $engineConfig

$dateToSystems = @{}
foreach ($date in $dates) {
    $dateToSystems[$date] = Read-HistoryDay -Date $date -HistoryDir $historyDir -CapsuleRoot $capsuleRoot -Config $engineConfig
}

$windowDays = $engineConfig.baseline.window_days
$startDate  = $engineConfig.baseline.start_date
$minScored  = $engineConfig.coverage.longitudinal_min_scored_repetitions
$persistAccrue = $engineConfig.persistence_days.attention_accrue

$results = [ordered]@{}

foreach ($id in $AllSystemIds) {

    $series = New-Object System.Collections.Generic.List[object]
    foreach ($date in $dates) {
        $daySystems = $dateToSystems[$date]
        $rec = $null
        if ($daySystems -and $daySystems.ContainsKey($id)) { $rec = $daySystems[$id] }

        $k = $null; $n = $null; $coverage = $null; $modelDeclared = $null; $valid = $false
        if ($rec -and $rec.longitudinal) {
            $lon = $rec.longitudinal
            $n = $lon.fully_scored
            $coverage = $lon.coverage
            $modelDeclared = $rec.model_declared
            if ($null -ne $n -and $n -ge $minScored -and $lon.metrics -and $null -ne $lon.metrics.normal) {
                $k = [int][math]::Round($lon.metrics.normal * $lon.expected_observations)
                $valid = $true
            }
        }
        $series.Add([PSCustomObject]@{ date = $date; valid = $valid; k = $k; n = $n; coverage = $coverage; model_declared = $modelDeclared })
    }

    # Pooled baseline (same window convention as longitudinal_engine.ps1): first
    # window_days valid days from start_date, pooled into one large-n Wilson interval.
    $poolK = 0; $poolN = 0; $windowStart = $null; $windowEnd = $null; $baselineStatus = "not_established"; $daysUsed = 0
    foreach ($e in $series) {
        if ($e.date -lt $startDate) { continue }
        if (-not $e.valid) { continue }
        if ($daysUsed -eq 0) { $windowStart = $e.date }
        $poolK += $e.k; $poolN += $e.n
        $windowEnd = $e.date
        $daysUsed++
        if ($daysUsed -ge $windowDays) { $baselineStatus = "established"; break }
    }
    $baselineWilson = if ($baselineStatus -eq "established") { Get-WilsonInterval -K $poolK -N $poolN -Z $z } else { $null }

    $identity = Get-IdentityStatus -SystemId $id -Config $engineConfig
    $lastDeclared = $null
    foreach ($e in $series) { if ($e.model_declared) { $lastDeclared = $e.model_declared } }

    # Decision rule: pool consecutive same-direction days into a growing streak and test
    # the POOLED streak (not each single day in isolation) against the baseline. Testing
    # single N=7 days one at a time against a much larger pooled baseline turned out,
    # empirically, to be statistically underpowered even with a proper two-proportion
    # test (not just the cruder CI-overlap heuristic) - it failed to flag the already
    # confirmed Mistral rupture. Pooling the streak is the direct statistical fix: it
    # gains power exactly as more consecutive same-direction days accumulate, mirroring
    # what N=14 (more repetitions per day) is separately expected to do.
    $baselineP = if ($poolN -gt 0) { $poolK / [double]$poolN } else { $null }
    $daily = New-Object System.Collections.Generic.List[object]
    $streakK = 0; $streakN = 0; $streakDirection = 0; $streakDays = 0
    $activeAttention = $false
    $returnStreakDays = 0
    $wilsonEvents = New-Object System.Collections.Generic.List[object]

    foreach ($e in $series) {
        $isPostBaseline = ($baselineStatus -eq "established") -and ($e.date -gt $windowEnd)

        $currentScore = if ($e.valid) { [math]::Round(100.0 * $e.k / $e.n) } else { $null }
        $wilson = if ($e.valid) { Get-WilsonInterval -K $e.k -N $e.n -Z $z } else { $null }

        $overlap = $null; $differs = $null; $streakDiffers = $null; $wilsonState = "insufficient_data"
        if (-not $e.valid) {
            $wilsonState = "insufficient_data"
            # A missing day does not reset an in-progress streak - same "neutral, neither
            # for nor against" rule already used by the Phase 1 hysteresis engine.
        }
        elseif (-not $isPostBaseline) {
            $wilsonState = "baseline_window"
        }
        else {
            $overlap = Test-IntervalOverlap -A $wilson -B $baselineWilson
            $differs = Test-ProportionsDiffer -K1 $e.k -N1 $e.n -K2 $poolK -N2 $poolN -Z $z

            $dayP = $e.k / [double]$e.n
            $dir = 0
            if ($dayP -lt $baselineP) { $dir = -1 } elseif ($dayP -gt $baselineP) { $dir = 1 }

            if ($dir -eq 0 -or ($streakDirection -ne 0 -and $dir -ne $streakDirection)) {
                # Direction flip or exact match to baseline: start a fresh streak.
                $streakK = $e.k; $streakN = $e.n; $streakDirection = $dir; $streakDays = 1
            }
            else {
                $streakK += $e.k; $streakN += $e.n; $streakDirection = $dir; $streakDays++
            }

            $streakDiffers = Test-ProportionsDiffer -K1 $streakK -N1 $streakN -K2 $poolK -N2 $poolN -Z $z

            # One-sided by design: only a streak BELOW the baseline rate (more FLAG/ERROR
            # than usual) is treated as an "attention" event. A streak at or above baseline
            # (e.g. a perfect k=7/7 day compared against a baseline that itself contains a
            # couple of known dips, so its pooled rate is <100%) can otherwise register as
            # "significantly better than usual" under a two-sided test - a real, empirically
            # discovered false-positive mode for OpenAI/Anthropic/Qwen specifically, whose
            # baselines are near-ceiling but not exactly 100%. "Better than baseline" is
            # never something this monitoring design should flag.
            $isDegradation = ($streakDirection -eq -1)

            if ($streakDiffers -and $isDegradation -and $streakDays -ge $persistAccrue) {
                $wilsonState = "attention_wilson"
                if (-not $activeAttention) {
                    $wilsonEvents.Add([ordered]@{ type = "wilson_significant_deviation_confirmed"; date = $e.date; streak_days = $streakDays; pooled_k = $streakK; pooled_n = $streakN })
                }
                $activeAttention = $true
                $returnStreakDays = 0
            }
            else {
                if ($activeAttention) {
                    $returnStreakDays++
                    if ($returnStreakDays -ge $persistAccrue) {
                        $wilsonEvents.Add([ordered]@{ type = "wilson_return_to_baseline"; date = $e.date; streak_days = $returnStreakDays })
                        $activeAttention = $false
                        $returnStreakDays = 0
                    }
                    $wilsonState = "attention_wilson"   # still in the confirmed episode until the return persistence threshold is met
                }
                else {
                    $wilsonState = "standard"
                }
            }
        }

        $daily.Add([ordered]@{
            date = $e.date
            n_effective = $e.n
            coverage = $e.coverage
            current_n7 = [ordered]@{ score = $currentScore }
            wilson_n7  = if ($wilson) { $wilson } else { $null }
            wilson_ci_overlaps_baseline_ci = $overlap    # diagnostic only, conservative - kept for transparency, not the decision rule
            wilson_day_significantly_different = $differs                # single day vs pooled baseline (also underpowered alone, kept for transparency)
            wilson_streak_significantly_different = $streakDiffers       # ACTUAL decision rule: pooled consecutive same-direction streak vs pooled baseline
            state_current = $null   # cross-referenced from the Phase 1 engine's own output, not recomputed here to avoid duplicating that logic
            state_wilson  = $wilsonState
        })
    }

    $results[$id] = [ordered]@{
        system_id = $id
        system_identity = [ordered]@{ model_declared = $lastDeclared; model_requested = $identity.model_requested; model_returned = $identity.model_returned; identity_status = $identity.identity_status }
        baseline_pooled = [ordered]@{ status = $baselineStatus; window_start = $windowStart; window_end = $windowEnd; pooled_k = $poolK; pooled_n = $poolN; wilson = $baselineWilson }
        n14_arm = [ordered]@{ status = "not_launched"; note = "requires live paid API calls - see fetch_n14_pilot.ps1, gated separately" }
        daily_series = $daily
        wilson_events = $wilsonEvents
    }
}

if (-not (Test-Path -LiteralPath $OutputDir)) { New-Item -ItemType Directory -Path $OutputDir -Force | Out-Null }

$report = [ordered]@{
    experiment = "wilson_n7_vs_n14"
    arm = "n7_retrospective_zero_cost"
    generated_at = (Get-Date).ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ssZ")
    methodology_version = $wilsonConfig.methodology_version
    config_version = $wilsonConfig.config_version
    weather_authority = $false
    systems = $results
}

$timestamp = (Get-Date).ToUniversalTime().ToString("yyyyMMddTHHmmssZ")
$path = Join-Path $OutputDir "wilson_n7_retrospective_${RunLabel}_$timestamp.json"
$latestPath = Join-Path $OutputDir "wilson_n7_retrospective_${RunLabel}_latest.json"
$json = $report | ConvertTo-Json -Depth 20
Set-Content -LiteralPath $path -Value $json -Encoding UTF8
Set-Content -LiteralPath $latestPath -Value $json -Encoding UTF8

Write-Host "[wilson_n7_retrospective] Zero new API calls. Wrote: $path"
return $report
