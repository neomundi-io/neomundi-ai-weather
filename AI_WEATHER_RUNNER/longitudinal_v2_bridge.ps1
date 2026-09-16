<#
.SYNOPSIS
    Bridge between the production aggregator (aggregate_and_publish_weather.ps1) and the
    V2 longitudinal engine (longitudinal_engine.ps1).

.DESCRIPTION
    Pure function definitions only - NO top-level executing statements. Dot-sourcing this
    file has zero side effects until one of its functions is explicitly called. This is
    what makes it safe to dot-source from the live production aggregator.

    Single source of truth rule (AI_WEATHER_V2_UPSTREAM_WIRING_VALIDATION.md section 2):
    this file NEVER reimplements baseline/MAD/MAD-floor/state-machine/event/uncertainty
    math. It only calls longitudinal_engine.ps1's own Invoke-LongitudinalEngine, checks
    the result is usable, and additively merges it into a COPY of the aggregator's
    already-published output. It never mutates the aggregator's own $output.

    Fail-open by construction: every public function here returns $null on any failure
    (missing files, an engine exception, an invalid/empty schema) - it never throws past
    its own boundary. The production call site wraps it in a try/catch anyway, as
    defense in depth, not because this file is expected to throw.
#>

function Get-LongitudinalV2Report {
    <#
        Runs the V2 longitudinal engine (read-only against data/history/*.json and the
        one capsule fallback - see longitudinal_engine.ps1) and returns its report, or
        $null on any failure. Never throws.
    #>
    param([string]$RunnerRoot)
    try {
        $enginePath = Join-Path $RunnerRoot "longitudinal_engine.ps1"
        $configPath = Join-Path $RunnerRoot "config\longitudinal_engine_config.json"
        if (-not (Test-Path -LiteralPath $enginePath)) { return $null }
        if (-not (Test-Path -LiteralPath $configPath)) { return $null }

        . $enginePath

        $repoRootForEngine = Split-Path $RunnerRoot -Parent
        $config = Get-EngineConfig -Path $configPath
        $report = Invoke-LongitudinalEngine -Config $config -RepoRoot $repoRootForEngine

        if (-not $report -or -not $report.systems -or $report.systems.Count -eq 0) { return $null }
        return $report
    }
    catch {
        return $null
    }
}

function Test-LongitudinalV2SystemUsable {
    <#
        A system's V2 result is "usable" only with an established baseline and an
        interpretable current state. Anything else (insufficient_data,
        baseline_not_established) is still surfaced AS DATA in the shadow file - never
        hidden - but flagged usable:false rather than silently treated as normal.
    #>
    param($SystemReport)
    if (-not $SystemReport) { return $false }
    if (-not $SystemReport.baseline -or $SystemReport.baseline.status -ne "established") { return $false }
    if (-not $SystemReport.current_longitudinal_state) { return $false }
    return $true
}

function Merge-LongitudinalV2IntoHistory {
    <#
        Additive merge only. Takes a deep-cloned copy of the aggregator's own $output
        (a JSON round-trip guarantees zero shared object references, so this function
        can never mutate the caller's original) plus a V2 engine report, and injects the
        new V2 fields DIRECTLY INTO the existing systems[].longitudinal sub-object (not
        a new sibling key) - this is the exact shape generate_capsule.py's
        build_longitudinal_reference() already expects (it checks for
        "current_longitudinal_state" inside system["longitudinal"]). No existing field
        (role, score, condition, coverage, metrics, regime_distribution, probe_id, ...)
        is renamed or removed - only new keys are added alongside them. Three root-level
        version fields are also added. No existing field anywhere is renamed or removed.

        Structural non-regression (AI_WEATHER_V2_UPSTREAM_WIRING_VALIDATION.md section 7):
        this function reads ONLY from $V2Report (the longitudinal engine's own output) to
        build these new fields - it never reads systems[].daily to derive them, so
        Today's Challenge structurally cannot influence this block.
    #>
    param($LegacyOutput, $V2Report)

    $enriched = $LegacyOutput | ConvertTo-Json -Depth 40 | ConvertFrom-Json

    $enriched | Add-Member -NotePropertyName "methodology_version" -NotePropertyValue $V2Report.methodology_version -Force
    $enriched | Add-Member -NotePropertyName "baseline_config_version" -NotePropertyValue $V2Report.baseline_config_version -Force
    $enriched | Add-Member -NotePropertyName "repetition_count" -NotePropertyValue $null -Force

    foreach ($system in $enriched.systems) {
        $v2sys = $V2Report.systems[$system.id]
        if (-not $v2sys) { continue }
        if (-not $system.longitudinal) { continue }   # nothing to enrich into

        if ((-not $enriched.repetition_count) -and $v2sys.repetition_count) {
            $enriched.repetition_count = $v2sys.repetition_count
        }

        $usable = Test-LongitudinalV2SystemUsable -SystemReport $v2sys

        $system.longitudinal | Add-Member -NotePropertyName "usable" -NotePropertyValue $usable -Force
        $system.longitudinal | Add-Member -NotePropertyName "repetition_count" -NotePropertyValue $v2sys.repetition_count -Force
        $system.longitudinal | Add-Member -NotePropertyName "current_longitudinal_state" -NotePropertyValue $v2sys.current_longitudinal_state -Force
        $system.longitudinal | Add-Member -NotePropertyName "deviation_index" -NotePropertyValue $v2sys.current_longitudinal_state.deviation_index -Force
        $system.longitudinal | Add-Member -NotePropertyName "baseline" -NotePropertyValue $v2sys.baseline -Force
        $system.longitudinal | Add-Member -NotePropertyName "uncertainty" -NotePropertyValue $v2sys.current_longitudinal_state.uncertainty -Force
        $system.longitudinal | Add-Member -NotePropertyName "detected_events" -NotePropertyValue $v2sys.detected_events -Force
        $system.longitudinal | Add-Member -NotePropertyName "system_identity" -NotePropertyValue $v2sys.system_identity -Force
    }

    return $enriched
}

function Write-ShadowHistoryV2 {
    <#
        Writes the enriched object to data/shadow/v2/<date>.json ONLY - never to
        data/history, weather.json, or data/current.json, and never to any file that
        already exists as production output. Returns the written path, or $null on
        failure (fail-open).
    #>
    param($EnrichedOutput, [string]$RepoRoot, [string]$Date)
    try {
        $shadowDir = Join-Path $RepoRoot "data\shadow\v2"
        New-Item -ItemType Directory -Force -Path $shadowDir | Out-Null
        $shadowPath = Join-Path $shadowDir "$Date.json"
        $json = $EnrichedOutput | ConvertTo-Json -Depth 40
        Set-Content -LiteralPath $shadowPath -Value $json -Encoding UTF8
        return $shadowPath
    }
    catch {
        return $null
    }
}

function Invoke-LongitudinalV2ShadowPipeline {
    <#
        THE single call site meant to be invoked from aggregate_and_publish_weather.ps1,
        strictly AFTER the legacy weather.json/data/current.json/data/history writes have
        already completed successfully. Fail-open end-to-end: any failure at any stage
        returns $null and writes nothing under data/shadow/v2/ - it never raises, and the
        production call site wraps it in a try/catch anyway as defense in depth.
    #>
    param($LegacyOutput, [string]$RunnerRoot, [string]$RepoRoot, [string]$Date)
    try {
        $v2Report = Get-LongitudinalV2Report -RunnerRoot $RunnerRoot
        if (-not $v2Report) { return $null }

        $enriched = Merge-LongitudinalV2IntoHistory -LegacyOutput $LegacyOutput -V2Report $v2Report
        if (-not $enriched) { return $null }

        return Write-ShadowHistoryV2 -EnrichedOutput $enriched -RepoRoot $RepoRoot -Date $Date
    }
    catch {
        return $null
    }
}
