<#
.SYNOPSIS
    AI Weather - Longitudinal Engine (SHADOW MODE - Phase 1)

.DESCRIPTION
    Reads existing, already-published data (data/history/*.json, and the one capsule
    that has no data/history equivalent: 2026-08-21) and computes, PER SYSTEM, a
    longitudinal baseline (median + MAD over a fixed window), a daily deviation index,
    a hysteresis-based state (standard / attention_accrue / attention_renforcee /
    attention_critique / insufficient_data / baseline_window), and the 7 What Changed?
    events defined in AI_WEATHER_V2_ARCHITECTURE.md section 5.

    THIS SCRIPT NEVER WRITES TO ANY EXISTING FILE. It only reads. Its only output is a
    new JSON report under AI_WEATHER_RUNNER/shadow/, which nothing else in the project
    reads. It is not invoked by run_full_pipeline.ps1 or any other production script.

    Authority model (see AI_WEATHER_V2_VALIDATION_GATE.md section 0):
    the output of this engine is NOT authoritative on the public "Weather" status.
    weather.json, data/current.json, capsules, index.html and every widget remain
    driven exclusively by daily_challenge, unchanged by this script's existence.

    Rollback: delete AI_WEATHER_RUNNER/shadow/, longitudinal_engine.ps1, and its config
    files. Nothing elsewhere in the repository references them.

.NOTES
    Methodology: AI_WEATHER_V2_ARCHITECTURE.md section 3 (baseline), section 4 (states),
    section 5 (events). Provisional numeric values live in
    AI_WEATHER_RUNNER/config/longitudinal_engine_config.json, never hardcoded here.
#>

[CmdletBinding()]
param(
    [string]$RepoRoot   = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path,
    [string]$ConfigPath = (Join-Path $PSScriptRoot "config\longitudinal_engine_config.json"),
    [string]$OutputDir  = (Join-Path $PSScriptRoot "shadow"),
    [switch]$Quiet
)

$ErrorActionPreference = "Stop"

# The 12 systems currently declared in config/panel.yml. Hardcoded here (not parsed
# from YAML, to avoid adding a YAML dependency) - kept in sync manually, same
# discipline panel.yml itself already uses for its own now-superseded protocol block.
$AllSystemIds = @(
    "openai", "anthropic", "google", "xai", "mistral", "deepseek",
    "qwen", "moonshot", "cohere", "meta", "infomaniak", "perplexity"
)

function Get-EngineConfig {
    param([string]$Path)
    if (-not (Test-Path -LiteralPath $Path)) {
        throw "Longitudinal engine config not found: $Path"
    }
    $raw = Get-Content -LiteralPath $Path -Raw -Encoding UTF8
    return $raw | ConvertFrom-Json
}

function Get-Median {
    param([double[]]$Values)
    if (-not $Values -or $Values.Count -eq 0) { return $null }
    $sorted = @($Values | Sort-Object)
    $n = $sorted.Count
    if ($n % 2 -eq 1) {
        return [double]$sorted[[int](($n - 1) / 2)]
    }
    else {
        $a = [double]$sorted[$n / 2 - 1]
        $b = [double]$sorted[$n / 2]
        return ($a + $b) / 2.0
    }
}

function Get-MedianAbsoluteDeviation {
    param([double[]]$Values, [double]$Median)
    if (-not $Values -or $Values.Count -eq 0) { return $null }
    $deviations = @($Values | ForEach-Object { [math]::Abs($_ - $Median) })
    return Get-Median -Values $deviations
}

function Get-WilsonInterval {
    <#
        Descriptive-only uncertainty band on the same decision counts already used for
        the score (k=ALLOW count, n=fully_scored). NEVER used to decide state or events -
        see AI_WEATHER_V2_LAUNCH_PLAN_2026-09-21.md section 2 and
        AI_WEATHER_V2_LIVE_EXPERIMENT_GATE.md (no Wilson confidence level is validated as
        a decision rule as of this launch). Purely for human-readable uncertainty display.
    #>
    param([int]$K, [int]$N, [double]$Z = 1.645)
    if ($N -le 0) { return $null }
    $p = $K / [double]$N
    $denom = 1 + ($Z * $Z) / $N
    $centre = ($p + ($Z * $Z) / (2 * $N)) / $denom
    $halfw = $Z * [math]::Sqrt(($p * (1 - $p) / $N) + (($Z * $Z) / (4.0 * $N * $N))) / $denom
    # 0.0/1.0 (Double) literals required - bare 0/1 (Int32) makes PowerShell pick
    # Max(Int32,Int32)/Min(Int32,Int32) and round the double argument to an integer
    # (a real bug found and fixed once already in the Wilson experiment).
    return [ordered]@{
        estimator = "wilson_90pct_descriptive_only"
        low  = [math]::Round(100 * [math]::Max(0.0, $centre - $halfw), 2)
        mid  = [math]::Round(100 * $centre, 2)
        high = [math]::Round(100 * [math]::Min(1.0, $centre + $halfw), 2)
    }
}

function Get-ModelDisplayMap {
    param($Config)
    $map = @{}
    foreach ($prop in $Config.model_display_to_id.PSObject.Properties) {
        if ($prop.Name -ne "_note") { $map[$prop.Name] = $prop.Value }
    }
    return $map
}

function Read-HistoryDay {
    <#
        Returns a hashtable id -> {id, model_declared, longitudinal} for one calendar
        date, read from data/history/<date>.json when it exists, falling back to the
        capsule tree for the one confirmed gap (2026-08-21, present in the capsule
        chain but absent from data/history - see AI_WEATHER_V2_VALIDATION_GATE.md 3.B).
        Read-only. Never writes.
    #>
    param([string]$Date, [string]$HistoryDir, [string]$CapsuleRoot, $Config)

    $historyPath = Join-Path $HistoryDir "$Date.json"
    if (Test-Path -LiteralPath $historyPath) {
        $raw = Get-Content -LiteralPath $historyPath -Raw -Encoding UTF8 | ConvertFrom-Json
        $systems = @{}
        foreach ($sys in $raw.systems) {
            $systems[$sys.id] = [PSCustomObject]@{
                id             = $sys.id
                model_declared = $sys.model
                longitudinal   = $sys.longitudinal
            }
        }
        return $systems
    }

    $parts = $Date -split "-"
    $capsulePath = Join-Path $CapsuleRoot ("{0}\{1}\{2}.json" -f $parts[0], $parts[1], $parts[2])
    if (Test-Path -LiteralPath $capsulePath) {
        $raw = Get-Content -LiteralPath $capsulePath -Raw -Encoding UTF8 | ConvertFrom-Json
        $map = Get-ModelDisplayMap -Config $Config
        $systems = @{}
        foreach ($obs in $raw.observations) {
            if (-not $map.ContainsKey($obs.model_display)) { continue }
            $id = $map[$obs.model_display]
            $systems[$id] = [PSCustomObject]@{
                id             = $id
                model_declared = $obs.model
                longitudinal   = $obs.longitudinal
            }
        }
        return $systems
    }

    return $null
}

function Get-AvailableDates {
    param([string]$HistoryDir, [string]$CapsuleRoot, $Config)

    $dates = New-Object System.Collections.Generic.List[string]
    Get-ChildItem -LiteralPath $HistoryDir -Filter "*.json" | ForEach-Object { $dates.Add($_.BaseName) }

    if (Test-Path -LiteralPath $CapsuleRoot) {
        Get-ChildItem -LiteralPath $CapsuleRoot -Recurse -Filter "*.json" | ForEach-Object {
            $y = $_.Directory.Parent.Name
            $m = $_.Directory.Name
            $d = "$y-$m-$($_.BaseName)"
            if (-not $dates.Contains($d)) { $dates.Add($d) }
        }
    }

    $excluded = New-Object System.Collections.Generic.List[string]
    if ($Config.protocol_exclusions.pre_split_dates) { $excluded.AddRange([string[]]$Config.protocol_exclusions.pre_split_dates) }
    if ($Config.protocol_exclusions.missing_calendar_days) { $excluded.AddRange([string[]]$Config.protocol_exclusions.missing_calendar_days) }

    return @($dates | Where-Object { -not $excluded.Contains($_) } | Sort-Object)
}

function Get-IdentityStatus {
    <#
        4-case classification per AI_WEATHER_V2_VALIDATION_GATE.md section 3.A.
        'verified' and 'inferred' are structurally unreachable in this backtest
        (no model_returned capture exists historically, no provider_changelog
        entries exist yet) - documented, not a bug.
    #>
    param([string]$SystemId, $Config)

    $known = $null
    if ($Config.model_requested_known.PSObject.Properties.Name -contains $SystemId) {
        $known = $Config.model_requested_known.$SystemId
    }

    $modelRequested = $null
    $pinned = $false
    $verified = $false
    if ($known) {
        $modelRequested = $known.value
        $pinned = [bool]$known.pinned
        $verified = [bool]$known.verified_in_session
    }

    $identityStatus = "unknown"
    if ($pinned) { $identityStatus = "declared" }
    if (-not $pinned) { $identityStatus = "unknown" }
    # 'verified' would require model_returned; not available today for any system.
    if ($verified -and $modelRequested -and $pinned -eq $false) {
        # OpenAI's case: the alias itself was independently confirmed in this session,
        # but confirming an alias is unpinned is not the same as confirming an
        # identity via API echo. Stays 'unknown' - this branch documents the distinction,
        # it does not upgrade the status.
        $identityStatus = "unknown"
    }

    return [PSCustomObject]@{
        model_requested = $modelRequested
        model_returned  = $null
        model_pinned    = $pinned
        identity_status = $identityStatus
    }
}

function Build-SystemReport {
    param([string]$SystemId, [string[]]$Dates, [hashtable]$DateToSystems, $Config)

    $minScored = $Config.coverage.longitudinal_min_scored_repetitions

    $series = New-Object System.Collections.Generic.List[object]
    $lastModelDeclared = $null
    $identityEvents = New-Object System.Collections.Generic.List[object]

    foreach ($date in $Dates) {
        $daySystems = $DateToSystems[$date]
        $rec = $null
        if ($daySystems -and $daySystems.ContainsKey($SystemId)) { $rec = $daySystems[$SystemId] }

        $entry = [ordered]@{
            date                  = $date
            valid                 = $false
            score                 = $null
            allow_count           = $null
            coverage              = $null
            fully_scored          = $null
            expected_observations = $null
            variation_fraction    = $null
            model_declared        = $null
        }

        if ($rec -and $rec.longitudinal) {
            $lon = $rec.longitudinal
            $entry.fully_scored          = $lon.fully_scored
            $entry.expected_observations = $lon.expected_observations
            $entry.coverage              = $lon.coverage
            $entry.model_declared        = $rec.model_declared

            if ($lon.metrics -and ($lon.metrics.PSObject.Properties.Name -contains "variation")) {
                $entry.variation_fraction = $lon.metrics.variation
            }

            if ($null -ne $lon.fully_scored -and $lon.fully_scored -ge $minScored -and $null -ne $lon.score) {
                $entry.valid = $true
                $entry.score = [double]$lon.score
                if ($lon.metrics -and $null -ne $lon.metrics.normal -and $null -ne $lon.expected_observations) {
                    $entry.allow_count = [int][math]::Round($lon.metrics.normal * $lon.expected_observations)
                }
            }

            # Best available proxy for a version-change signal without model_returned:
            # a change in the *declared* model string day over day. Lower confidence
            # than a true API-echo diff would be, and explicitly labeled as such.
            if ($lastModelDeclared -and $rec.model_declared -and ($rec.model_declared -ne $lastModelDeclared)) {
                $identityEvents.Add([ordered]@{
                    type       = "known_model_version_change"
                    date       = $date
                    confidence = "medium_declared_change_only_no_api_echo"
                    evidence   = [ordered]@{ previous_model_declared = $lastModelDeclared; new_model_declared = $rec.model_declared }
                })
            }
            if ($rec.model_declared) { $lastModelDeclared = $rec.model_declared }
        }

        $series.Add([PSCustomObject]$entry)
    }

    # --- Baseline: first N valid days from the configured start date onward ---
    $windowDays = $Config.baseline.window_days
    $startDate  = $Config.baseline.start_date
    $baselineScores    = New-Object System.Collections.Generic.List[double]
    $baselineVariation = New-Object System.Collections.Generic.List[double]
    $windowStart = $null
    $windowEnd   = $null
    $baselineStatus = "not_established"

    foreach ($entry in $series) {
        if ($entry.date -lt $startDate) { continue }
        if (-not $entry.valid) { continue }
        if ($baselineScores.Count -eq 0) { $windowStart = $entry.date }
        $baselineScores.Add($entry.score)
        if ($null -ne $entry.variation_fraction) { $baselineVariation.Add([double]$entry.variation_fraction) }
        $windowEnd = $entry.date
        if ($baselineScores.Count -ge $windowDays) { $baselineStatus = "established"; break }
    }

    $median = $null; $mad = $null; $varMedian = $null
    if ($baselineStatus -eq "established") {
        $median = Get-Median -Values $baselineScores.ToArray()
        $mad    = Get-MedianAbsoluteDeviation -Values $baselineScores.ToArray() -Median $median
        if ($baselineVariation.Count -gt 0) { $varMedian = Get-Median -Values $baselineVariation.ToArray() }
    }

    # MAD floor (V2.0 launch fix): a raw MAD of 0 (mode-dominant baseline, e.g. Perplexity)
    # made ANY deviation register as numerically "infinite", jumping straight to
    # attention_critique on a merely modest, single-grid-step deviation. The floor ties
    # the minimum meaningful dispersion to the score grid's own granularity
    # (100/repetition_count), so a one-step deviation reads as ~2 floor-MAD units -
    # squarely at the attention_accrue/renforcee boundary, never an automatic critique.
    $epsilon = 0.0001
    $repetitionCount = $Config.coverage.longitudinal_expected_repetitions
    $madFloor = $epsilon
    if ($Config.mad_floor -and $Config.mad_floor.enabled -and $repetitionCount -gt 0) {
        $madFloor = (100.0 / $repetitionCount) / 2.0
    }
    $madFloorApplied = ($baselineStatus -eq "established") -and ($mad -lt $madFloor)
    $effectiveMad = if ($baselineStatus -eq "established") { [math]::Max($mad, $madFloor) } else { $null }

    $baseline = [ordered]@{
        status             = $baselineStatus
        window_start       = $windowStart
        window_end         = $windowEnd
        window_days_used   = $baselineScores.Count
        window_days_target = $windowDays
        dispersion_method  = $Config.baseline.dispersion_method
        median             = $median
        mad                = $mad
        mad_floor          = $madFloor
        mad_floor_applied  = $madFloorApplied
        effective_mad      = $effectiveMad
        variation_fraction_median = $varMedian
    }

    # --- Identity (system-wide, not per-day - see rationale in the report generator) ---
    $identityInfo = Get-IdentityStatus -SystemId $SystemId -Config $Config
    $lastDeclared = $null
    foreach ($e in $series) { if ($e.model_declared) { $lastDeclared = $e.model_declared } }

    $systemIdentity = [ordered]@{
        model_declared   = $lastDeclared
        model_requested  = $identityInfo.model_requested
        model_returned   = $identityInfo.model_returned
        model_pinned     = $identityInfo.model_pinned
        identity_status  = $identityInfo.identity_status
    }

    # --- State machine (hysteresis) over the series ---
    $th      = $Config.deviation_thresholds
    $persist = $Config.persistence_days
    $retDays = $Config.return_to_baseline_days
    $stateLabels = @{ 0 = "standard"; 1 = "attention_accrue"; 2 = "attention_renforcee"; 3 = "attention_critique" }
    $tierKeys    = @{ 1 = "attention_accrue"; 2 = "attention_renforcee"; 3 = "attention_critique" }

    $severity    = 0
    $streakAbove = @{ 1 = 0; 2 = 0; 3 = 0 }
    $streakBelow = 0
    $events      = New-Object System.Collections.Generic.List[object]
    $dailyStates = New-Object System.Collections.Generic.List[object]

    foreach ($entry in $series) {
        # A day is "post-baseline" only strictly AFTER the window_end date - the day
        # that closes the baseline window is itself still a baseline_window day, never
        # evaluated against the baseline it helped build (fixes an off-by-one where a
        # mutable flag flipped one iteration too early).
        $isPostBaseline = ($baselineStatus -eq "established") -and ($entry.date -gt $windowEnd)

        $state = "insufficient_data"
        $deviationIndex = $null

        if (-not $entry.valid) {
            $events.Add([ordered]@{
                type       = "coverage_anomaly"
                date       = $entry.date
                confidence = "high_completeness_fact"
                evidence   = [ordered]@{ fully_scored = $entry.fully_scored; expected = $entry.expected_observations; coverage = $entry.coverage }
            })
        }
        elseif (-not $isPostBaseline) {
            $state = "baseline_window"
        }
        else {
            $deviationIndex = ($entry.score - $median) / $effectiveMad
            $absDev = [math]::Abs($deviationIndex)
            $tier = 0
            if ($absDev -ge $th.attention_critique) { $tier = 3 }
            elseif ($absDev -ge $th.attention_renforcee) { $tier = 2 }
            elseif ($absDev -ge $th.attention_accrue) { $tier = 1 }

            if ($tier -ge 1) {
                $streakBelow = 0
                foreach ($t in 1, 2, 3) {
                    if ($tier -ge $t) { $streakAbove[$t] = $streakAbove[$t] + 1 } else { $streakAbove[$t] = 0 }
                }
                if ($tier -ge 1 -and $streakAbove[1] -eq 1 -and $severity -eq 0) {
                    $events.Add([ordered]@{
                        type = "behavioral_deviation_detected"; date = $entry.date; confidence = "low_medium_unconfirmed"
                        evidence = [ordered]@{ score = $entry.score; baseline_median = $median; baseline_mad = $mad; deviation_index = $deviationIndex }
                    })
                }
                foreach ($t in 1, 2, 3) {
                    if ($streakAbove[$t] -ge $persist.($tierKeys[$t]) -and $severity -lt $t) {
                        $severity = $t
                        $events.Add([ordered]@{
                            type = "persistent_deviation"; date = $entry.date; tier = $tierKeys[$t]; confidence = "medium_high"
                            evidence = [ordered]@{ streak_days = $streakAbove[$t]; deviation_index = $deviationIndex }
                        })
                    }
                }
            }
            else {
                foreach ($t in 1, 2, 3) { $streakAbove[$t] = 0 }
                if ($severity -gt 0) {
                    $streakBelow++
                    $needed = $retDays.($tierKeys[$severity])
                    if ($streakBelow -ge $needed) {
                        $severity = $severity - 1
                        $streakBelow = 0
                        if ($severity -eq 0) {
                            $events.Add([ordered]@{
                                type = "return_to_baseline"; date = $entry.date; confidence = "medium_high"
                                evidence = [ordered]@{ deviation_index = $deviationIndex }
                            })
                        }
                    }
                }
                else { $streakBelow = 0 }
            }

            if ($null -ne $varMedian -and $null -ne $entry.variation_fraction) {
                $delta = $entry.variation_fraction - $varMedian
                if ($delta -ge $Config.event_rules.variability_increase_variation_fraction_delta) {
                    $events.Add([ordered]@{
                        type = "variability_increase"; date = $entry.date; confidence = "medium_noisy_n7"
                        evidence = [ordered]@{ variation_fraction = $entry.variation_fraction; baseline_variation_fraction_median = $varMedian }
                    })
                }
            }

            $state = $stateLabels[$severity]
        }

        $uncertainty = $null
        if ($entry.valid -and $null -ne $entry.allow_count) {
            $uncertainty = Get-WilsonInterval -K $entry.allow_count -N $entry.fully_scored -Z $Config.uncertainty.z
        }

        $dailyStates.Add([ordered]@{
            date            = $entry.date
            valid           = $entry.valid
            score           = $entry.score
            coverage        = $entry.coverage
            deviation_index = $deviationIndex
            uncertainty     = $uncertainty
            state           = $state
        })
    }

    foreach ($ie in $identityEvents) { $events.Add($ie) }

    # Identity caveat is a system-wide, standing methodological note - emitted once,
    # not once per day, to avoid drowning the genuinely per-day events in noise.
    if ($systemIdentity.identity_status -ne "verified") {
        $events.Add([ordered]@{
            type     = "model_identity_unverified"
            date     = $null
            scope    = "system_wide"
            confidence = "n_a_methodological_caveat"
            evidence = [ordered]@{ identity_status = $systemIdentity.identity_status; model_requested = $systemIdentity.model_requested; model_declared = $systemIdentity.model_declared }
        })
    }

    $lastValid = $null
    foreach ($d in $dailyStates) { if ($d.valid) { $lastValid = $d } }

    $currentState = [ordered]@{
        state           = if ($lastValid) { $lastValid.state } else { "insufficient_data" }
        deviation_index = if ($lastValid) { $lastValid.deviation_index } else { $null }
        uncertainty     = if ($lastValid) { $lastValid.uncertainty } else { $null }
        as_of           = if ($lastValid) { $lastValid.date } else { $null }
    }

    return [ordered]@{
        system_id                   = $SystemId
        repetition_count            = $repetitionCount
        weather_authority           = $true
        system_identity             = $systemIdentity
        baseline                    = $baseline
        current_longitudinal_state  = $currentState
        daily_series                = $dailyStates
        detected_events             = $events
    }
}

function Invoke-LongitudinalEngine {
    param($Config, [string]$RepoRoot)

    $historyDir  = Join-Path $RepoRoot "data\history"
    $capsuleRoot = Join-Path $RepoRoot "aiweather-capsule\capsules"

    $dates = Get-AvailableDates -HistoryDir $historyDir -CapsuleRoot $capsuleRoot -Config $Config

    $dateToSystems = @{}
    foreach ($date in $dates) {
        $dateToSystems[$date] = Read-HistoryDay -Date $date -HistoryDir $historyDir -CapsuleRoot $capsuleRoot -Config $Config
    }

    $systemsReport = [ordered]@{}
    foreach ($id in $AllSystemIds) {
        $systemsReport[$id] = Build-SystemReport -SystemId $id -Dates $dates -DateToSystems $dateToSystems -Config $Config
    }

    $stateCounts = @{ standard = 0; attention_accrue = 0; attention_renforcee = 0; attention_critique = 0; insufficient_data = 0; baseline_window = 0 }
    $eventTypeCounts = @{}
    foreach ($id in $AllSystemIds) {
        $s = $systemsReport[$id].current_longitudinal_state.state
        if ($stateCounts.ContainsKey($s)) { $stateCounts[$s] = $stateCounts[$s] + 1 }
        foreach ($ev in $systemsReport[$id].detected_events) {
            if (-not $eventTypeCounts.ContainsKey($ev.type)) { $eventTypeCounts[$ev.type] = 0 }
            $eventTypeCounts[$ev.type] = $eventTypeCounts[$ev.type] + 1
        }
    }

    # NOTE on the two "authority" flags below: this run is still written only under
    # AI_WEATHER_RUNNER/shadow/ and this script is still not invoked by
    # run_full_pipeline.ps1 - top-level weather_authority:false truthfully describes
    # TODAY's deployment status. Each system's own weather_authority:true (set in
    # Build-SystemReport) describes the INTENDED target once wired into production
    # (AI_WEATHER_V2_LAUNCH_PLAN_2026-09-21.md section 1) - the two are not a
    # contradiction, they describe two different points on the same timeline.
    return [ordered]@{
        shadow_report        = $true
        weather_authority     = $false
        generated_at          = (Get-Date).ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ssZ")
        engine_version        = "longitudinal_engine_v2_0_launch_candidate"
        methodology_version   = $Config.methodology_version
        baseline_config_version = $Config.baseline_config_version
        date_range_processed  = [ordered]@{
            first    = if ($dates.Count -gt 0) { $dates[0] } else { $null }
            last     = if ($dates.Count -gt 0) { $dates[$dates.Count - 1] } else { $null }
            count    = $dates.Count
            excluded_pre_split_dates   = $Config.protocol_exclusions.pre_split_dates
            missing_calendar_days      = $Config.protocol_exclusions.missing_calendar_days
        }
        known_limitations = @(
            "model_returned n'est capture pour aucun systeme aujourd'hui (instrumentation Phase 0 non executee) - identity_status ne peut donc jamais atteindre 'verified' dans ce rejeu.",
            "known_data_exclusions (ex. dates precises du bug de panel Moonshot) est vide - Phase 0 non executee dans ce tour, aucune date n'a ete retiree du calcul de baseline pour Moonshot.",
            "model_identity_unverified est un evenement 'system_wide' emis une fois par systeme, pas par jour, pour rester lisible.",
            "known_model_version_change ne detecte ici qu'un changement du champ 'model' declare (config), pas un echo API reel - confiance abaissee en consequence.",
            "variability_increase est calcule a partir de metrics.variation (fraction deja publiee), pas d'une dispersion recalculee depuis les reponses brutes."
        )
        global_summary = [ordered]@{
            systems_count    = $AllSystemIds.Count
            state_counts     = $stateCounts
            event_type_counts = $eventTypeCounts
        }
        systems = $systemsReport
    }
}

# --- Entry point ---
# Guarded so that test scripts can dot-source this file (". .\longitudinal_engine.ps1")
# to reuse its functions without triggering a run or any file write.
if ($MyInvocation.InvocationName -ne ".") {

    $config = Get-EngineConfig -Path $ConfigPath
    $report = Invoke-LongitudinalEngine -Config $config -RepoRoot $RepoRoot

    if (-not (Test-Path -LiteralPath $OutputDir)) {
        New-Item -ItemType Directory -Path $OutputDir -Force | Out-Null
    }

    $timestamp = (Get-Date).ToUniversalTime().ToString("yyyyMMddTHHmmssZ")
    $timestampedPath = Join-Path $OutputDir "longitudinal_shadow_report_$timestamp.json"
    $latestPath      = Join-Path $OutputDir "longitudinal_shadow_report_latest.json"

    $json = $report | ConvertTo-Json -Depth 20
    Set-Content -LiteralPath $timestampedPath -Value $json -Encoding UTF8
    Set-Content -LiteralPath $latestPath -Value $json -Encoding UTF8

    if (-not $Quiet) {
        Write-Host "[longitudinal_engine] SHADOW MODE - not authoritative on any public status."
        Write-Host "[longitudinal_engine] Dates processed : $($report.date_range_processed.first) -> $($report.date_range_processed.last) ($($report.date_range_processed.count) jours)"
        Write-Host "[longitudinal_engine] Etats courants   : $($report.global_summary.state_counts | ConvertTo-Json -Compress)"
        Write-Host "[longitudinal_engine] Rapport ecrit    : $timestampedPath"
        Write-Host "[longitudinal_engine] Dernier rapport  : $latestPath"
    }

    return $report
}
