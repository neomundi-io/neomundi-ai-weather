# ============================================================
# Get-ProtocolVolume
#
# Shared resolver for the AI Weather daily observation volume.
#
# The volume (how many executions per ACTIVE MODEL per DAY, for each
# of the two probes) lives in exactly ONE place:
#
#     AI_WEATHER_RUNNER\config\protocol_volume.json
#
# and is EFFECTIVE-DATED. Resolution picks the entry with the latest
# effective_from that is <= the requested date. That date-awareness is
# the point: re-aggregating an already published day must keep using
# the volume that day was actually measured with, otherwise its
# coverage ratios would be recomputed against the wrong denominator
# and a complete historical day could start reporting as incomplete.
#
# Consumers (none of them holds a literal volume value anymore):
#   build_daily_panel.ps1            -> repetitions column of
#                                       data\panels\ai_weather_panel.csv
#                                       (the file the 12 runners read)
#   launch_ai_weather.ps1            -> NEOMUNDI_OBSERVATION_SPACING_MS
#                                       exported to the runner processes
#   aggregate_and_publish_weather.ps1 -> coverage denominators and the
#                                       published protocol contract
#
# Fails loud: an unreadable/empty/invalid config throws rather than
# silently falling back to a hardcoded number, which is exactly the
# failure mode this file exists to remove.
# ============================================================

function Get-ProtocolVolumeConfigPath {
    param([string]$RunnerRoot)

    if ([string]::IsNullOrWhiteSpace($RunnerRoot)) {
        $RunnerRoot = Split-Path $PSScriptRoot -Parent
    }

    return (Join-Path $RunnerRoot "config\protocol_volume.json")
}

function Resolve-ProtocolVolume {
    <#
        .SYNOPSIS
        Returns the observation volume in force on a given date.

        .PARAMETER Date
        Measurement day, "yyyy-MM-dd". Defaults to today (system clock,
        which the pipeline keeps on Paris time -- see run_full_pipeline.ps1).

        .PARAMETER ConfigPath
        Override the config location (tests only).

        .OUTPUTS
        PSCustomObject:
          profile_id                      string
          effective_from                  "yyyy-MM-dd"
          daily_repetitions               int  >= 1
          longitudinal_repetitions        int  >= 1
          total_repetitions               int  (daily + longitudinal)
          inter_observation_spacing_ms    int  >= 0
          statistical_robustness_min_n    int  >= 1
          note                            string
          config_version                  string
          resolved_for_date               "yyyy-MM-dd"
          resolved_before_first_entry     bool (true = requested date is
                                          older than the earliest entry;
                                          the earliest entry is used)
    #>
    [CmdletBinding()]
    param(
        [string]$Date = (Get-Date).ToString("yyyy-MM-dd"),
        [string]$ConfigPath = $null,
        [string]$RunnerRoot = $null
    )

    if ([string]::IsNullOrWhiteSpace($ConfigPath)) {
        $ConfigPath = Get-ProtocolVolumeConfigPath -RunnerRoot $RunnerRoot
    }

    if (-not (Test-Path -LiteralPath $ConfigPath)) {
        throw "Protocol volume config not found: $ConfigPath"
    }

    try {
        $config =
            Get-Content -LiteralPath $ConfigPath -Raw -Encoding UTF8 |
            ConvertFrom-Json
    }
    catch {
        throw "Protocol volume config is not valid JSON ($ConfigPath): $($_.Exception.Message)"
    }

    $requested = [datetime]::ParseExact(
        $Date,
        "yyyy-MM-dd",
        [System.Globalization.CultureInfo]::InvariantCulture
    )

    $entries = @($config.schedule)

    if ($entries.Count -eq 0) {
        throw "Protocol volume config has an empty 'schedule' ($ConfigPath)."
    }

    $parsed = @(
        foreach ($entry in $entries) {
            $from = [string]$entry.effective_from

            if ([string]::IsNullOrWhiteSpace($from)) {
                throw "Protocol volume config has an entry without 'effective_from' ($ConfigPath)."
            }

            [PSCustomObject]@{
                effective_from_date = [datetime]::ParseExact(
                    $from,
                    "yyyy-MM-dd",
                    [System.Globalization.CultureInfo]::InvariantCulture
                )
                entry = $entry
            }
        }
    )

    $ordered = @($parsed | Sort-Object effective_from_date)

    $applicable = @(
        $ordered | Where-Object { $_.effective_from_date -le $requested }
    )

    $beforeFirst = ($applicable.Count -eq 0)

    $selected =
        if ($beforeFirst) {
            # Requested date predates every declared profile (e.g. a
            # re-read of a pre-v0.2 day). Use the earliest declared
            # profile rather than inventing a value, and say so in the
            # returned object so the caller can surface it.
            $ordered[0]
        }
        else {
            $applicable[-1]
        }

    $entry = $selected.entry

    $daily = [int]$entry.daily_repetitions
    $long  = [int]$entry.longitudinal_repetitions

    if ($daily -lt 1) {
        throw "Protocol volume profile '$([string]$entry.profile_id)' has daily_repetitions=$daily; at least 1 is required."
    }

    if ($long -lt 1) {
        throw "Protocol volume profile '$([string]$entry.profile_id)' has longitudinal_repetitions=$long; at least 1 is required."
    }

    $spacing =
        if ($entry.PSObject.Properties.Name -contains "inter_observation_spacing_ms" -and
            $null -ne $entry.inter_observation_spacing_ms) {
            [int]$entry.inter_observation_spacing_ms
        }
        else {
            0
        }

    if ($spacing -lt 0) {
        throw "Protocol volume profile '$([string]$entry.profile_id)' has a negative inter_observation_spacing_ms=$spacing."
    }

    $minN =
        if ($config.PSObject.Properties.Name -contains "statistical_robustness_min_n" -and
            $null -ne $config.statistical_robustness_min_n) {
            [int]$config.statistical_robustness_min_n
        }
        else {
            0
        }

    return [PSCustomObject]@{
        profile_id                   = [string]$entry.profile_id
        effective_from               = $selected.effective_from_date.ToString("yyyy-MM-dd")
        daily_repetitions            = $daily
        longitudinal_repetitions     = $long
        total_repetitions            = $daily + $long
        inter_observation_spacing_ms = $spacing
        statistical_robustness_min_n = $minN
        note                         = [string]$entry.note
        config_version               = [string]$config.config_version
        resolved_for_date            = $requested.ToString("yyyy-MM-dd")
        resolved_before_first_entry  = $beforeFirst
    }
}
