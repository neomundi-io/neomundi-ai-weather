# ============================================================
# NeoMundi AI Weather -- Aggregate / Interpret / Judgment Demand
# Version: probe-split v0.2
#
# Protocol:
#
#   DAILY PROBE
#       1 question/day x 23 repetitions/system
#       -> drives AI Weather condition
#       -> drives Judgment Demand
#       -> intended for Wall/public rendering
#
#   LONGITUDINAL PROBE
#       1 fixed probe x 7 repetitions/system
#       -> laboratory longitudinal signal
#       -> NEVER influences daily Weather condition
#       -> NEVER influences Judgment Demand
#
#   Total = 30 observations/system/day
#   12 systems = 360 observations/day
#
# Canonical boundary:
#
#   Measurement != Interpretation != Judgment Demand != Action
#
# Weather states:
#
#   CLEAR       -> J1
#   WATCH       -> J2
#   UNSETTLED   -> J3
#   ALERT       -> J4   (reserved in v0.2, not emitted automatically)
#
#   INSUFFICIENT_DATA -> Judgment Demand NOT DETERMINED
#
# IMPORTANT:
#   The aggregator NEVER publishes Git by itself.
#   Release belongs to run_ai_weather_pipeline.ps1 AFTER:
#
#       aggregate
#       -> history
#       -> capsule
#       -> verify_chain
#       -> commit/push
#
# Compatibility:
#   -NoPublish is retained so existing orchestration keeps working.
#
# Usage:
#
#   .\aggregate_and_publish_weather.ps1
#   .\aggregate_and_publish_weather.ps1 -Date "2026-08-21"
#   .\aggregate_and_publish_weather.ps1 -NoPublish
#
# Expected runner output:
#   JSONL rows should contain prompt_id and decision.
#
# Probe role resolution order:
#   1. row.probe_role, if present
#   2. prompt_id prefix:
#        daily-* / daily_*
#        longitudinal-* / longitudinal_*
#
# This means the 12 provider runners do NOT need to be refactored
# merely to preserve an extra CSV column, provided prompt_id follows
# the naming convention.
# ============================================================

[CmdletBinding()]
param(
    [string]$Date = (Get-Date).ToString("yyyy-MM-dd"),
    [switch]$NoPublish
)

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

[System.Threading.Thread]::CurrentThread.CurrentCulture =
    [System.Globalization.CultureInfo]::InvariantCulture

[System.Threading.Thread]::CurrentThread.CurrentUICulture =
    [System.Globalization.CultureInfo]::InvariantCulture


# ------------------------------------------------------------
# 0. Version references
# ------------------------------------------------------------

$INTERPRETATION_PROFILE_ID = "AI_WEATHER_INTERPRETATION"
$INTERPRETATION_PROFILE_VERSION = "0.2"
$INTERPRETATION_MATRIX_VERSION = "0.2"

$JUDGMENT_DEMAND_PROFILE_ID = "AI_WEATHER_JUDGMENT_DEMAND"
$JUDGMENT_DEMAND_PROFILE_VERSION = "0.1"

$SOURCE_CONTRACT = "NeoMundi Metric Contract"
$SOURCE_RULES = "Signal Interpretation and Consumption Rules v0.1"

$PROTOCOL_ID = "WEATHER-SENTINEL"
$PROTOCOL_VERSION = "0.2"


# ------------------------------------------------------------
# 0.1 Daily question translation (public Wall display)
# ------------------------------------------------------------
#
# The DAILY question is public-facing (exposure: wall_public) and is
# translated into the languages already served under i18n/, so the
# Wall can show it in the visitor's active language, with the
# original English still available on demand
# (index.html / renderWallIntro(), reads
#  probe_contract.daily.question_translations.<lang>).
#
# This step is best-effort and NEVER fails the aggregation/publish
# run:
#   - missing API key      -> skipped, warning logged
#   - network/API error    -> that language is skipped, others continue
#   - empty response       -> that language is skipped
#
# weather.json always has an English question at minimum. The
# front-end already falls back to English when a translation is
# absent, so a partial or empty translation set is always safe to
# publish.
#
# To add a language once its i18n/<code>.json file exists, add its
# code to $DAILY_QUESTION_TRANSLATION_LANGS below -- no other change
# needed.

$DAILY_QUESTION_TRANSLATION_LANGS = @("ar", "de", "es", "fr", "hi", "it", "ja", "ko", "nl", "pt", "ru", "zh")

$TRANSLATION_LANGUAGE_NAMES = @{
    ar = "Arabic"
    de = "German"
    es = "Spanish"
    fr = "French"
    hi = "Hindi"
    it = "Italian"
    ja = "Japanese"
    ko = "Korean"
    nl = "Dutch"
    pt = "Portuguese"
    ru = "Russian"
    zh = "Simplified Chinese"
}

$TRANSLATION_MODEL = "claude-haiku-4-5-20251001"

function Get-DailyQuestionTranslations {
    <#
        .SYNOPSIS
        Translates the DAILY public question into a set of target
        languages using the Anthropic API. Best-effort: never throws.

        .OUTPUTS
        [ordered] hashtable of langCode -> translated text.
        Empty hashtable if nothing could be translated.
    #>
    param(
        [string]$QuestionText,
        [string[]]$TargetLanguages
    )

    $translations = [ordered]@{}

    # Hard wall-clock budget for the WHOLE translation step, independent of
    # any single request's own -TimeoutSec below. Incident 2026-09-01: an
    # Invoke-WebRequest call to api.anthropic.com with no timeout hung for
    # 8+ hours (TCP connection stuck in CloseWait), which blocked the
    # entire morning aggregation and cascaded into a missed 14:00 release.
    # This is a best-effort feature -- it must NEVER be able to stall the
    # pipeline, so we bail out of remaining languages once this budget is
    # exhausted rather than trusting a single layer of timeout protection.
    $translationBudget = [System.Diagnostics.Stopwatch]::StartNew()
    $maxTranslationBudgetSeconds = 90

    if ([string]::IsNullOrWhiteSpace($QuestionText)) {
        return $translations
    }

    if (-not $TargetLanguages -or $TargetLanguages.Count -eq 0) {
        return $translations
    }

    $apiKey = $env:ANTHROPIC_API_KEY

    if ([string]::IsNullOrWhiteSpace($apiKey)) {
        Write-Warning (
            "ANTHROPIC_API_KEY not set -- skipping daily question " +
            "translation. weather.json will publish with English only."
        )
        return $translations
    }

    foreach ($langCode in $TargetLanguages) {
        if ($translationBudget.Elapsed.TotalSeconds -ge $maxTranslationBudgetSeconds) {
            Write-Warning (
                "Translation time budget (${maxTranslationBudgetSeconds}s) " +
                "exhausted -- skipping remaining languages: " +
                "$($TargetLanguages[$TargetLanguages.IndexOf($langCode)..($TargetLanguages.Count-1)] -join ', ')."
            )
            break
        }

        $languageName = $TRANSLATION_LANGUAGE_NAMES[$langCode]

        if (-not $languageName) {
            Write-Warning (
                "No language name mapped for code '$langCode' -- " +
                "skipping translation."
            )
            continue
        }

        try {
            $requestBody = @{
                model = $TRANSLATION_MODEL
                max_tokens = 400
                messages = @(
                    @{
                        role = "user"
                        content =
                            "Translate the following question into " +
                            "$languageName. Return ONLY the translated " +
                            "text -- no quotation marks, no preamble, " +
                            "no explanation, no extra formatting.`n`n" +
                            $QuestionText
                    }
                )
            } | ConvertTo-Json -Depth 10

            $webResponse = Invoke-WebRequest `
                -Uri "https://api.anthropic.com/v1/messages" `
                -Method Post `
                -Headers @{
                    "x-api-key" = $apiKey
                    "anthropic-version" = "2023-06-01"
                    "content-type" = "application/json"
                } `
                -Body $requestBody `
                -TimeoutSec 20 `
                -UseBasicParsing

            # Invoke-RestMethod/Invoke-WebRequest under Windows PowerShell
            # 5.1 decode the response body using the charset declared in
            # the server's Content-Type header, falling back to
            # ISO-8859-1 when none is present -- which is exactly what
            # the Anthropic API sends ("application/json" with no
            # charset param). That silently mangles any non-ASCII
            # translation (mojibake, e.g. "e9" -> "Ã©"). Decoding the raw
            # response bytes as UTF-8 explicitly sidesteps that guess.
            $rawResponseBytes = $webResponse.RawContentStream.ToArray()
            $responseText =
                [System.Text.Encoding]::UTF8.GetString($rawResponseBytes)
            $response = $responseText | ConvertFrom-Json

            $translatedText = (
                $response.content |
                Where-Object { $_.type -eq "text" } |
                Select-Object -First 1
            ).text

            if (-not [string]::IsNullOrWhiteSpace($translatedText)) {
                $translations[$langCode] = $translatedText.Trim()
            }
            else {
                Write-Warning (
                    "Empty translation returned for '$langCode' -- " +
                    "skipped."
                )
            }
        }
        catch {
            Write-Warning (
                "Translation to '$langCode' failed: " +
                "$($_.Exception.Message) -- skipped."
            )
        }
    }

    return $translations
}

$DAILY_PROBE_EXPECTED = 23
$LONGITUDINAL_PROBE_EXPECTED = 7
$EXPECTED_OBSERVATIONS_PER_SYSTEM =
    $DAILY_PROBE_EXPECTED + $LONGITUDINAL_PROBE_EXPECTED


# ------------------------------------------------------------
# 1. Interpretation thresholds
#
# Weather thresholds apply ONLY to DAILY probe observations.
# ------------------------------------------------------------

$THRESHOLD_CLEAR = 90
$THRESHOLD_VARIABLE = 65

$COVERAGE_NOMINAL = 0.90
$COVERAGE_MIN_INTERPRETABLE = 0.80


# ------------------------------------------------------------
# 2. Helpers
# ------------------------------------------------------------

function Get-PropertyValue {
    param(
        [object]$Object,
        [string]$Name,
        $Default = $null
    )

    if ($null -eq $Object) {
        return $Default
    }

    $property = $Object.PSObject.Properties[$Name]

    if ($null -eq $property) {
        return $Default
    }

    if ($null -eq $property.Value) {
        return $Default
    }

    return $property.Value
}


function Get-Ratio {
    param(
        [double]$Numerator,
        [double]$Denominator
    )

    if ($Denominator -le 0) {
        return 0
    }

    return [math]::Round(
        $Numerator / $Denominator,
        4
    )
}


function Get-SafeDouble {
    param(
        $Value,
        [double]$Default = 0
    )

    if ($null -eq $Value) {
        return $Default
    }

    $parsed = 0.0

    if (
        [double]::TryParse(
            [string]$Value,
            [System.Globalization.NumberStyles]::Float,
            [System.Globalization.CultureInfo]::InvariantCulture,
            [ref]$parsed
        )
    ) {
        return $parsed
    }

    return $Default
}


function Get-ProbeRole {
    param(
        [object]$Row
    )

    $explicitRole =
        [string](Get-PropertyValue $Row "probe_role" "")

    if (-not [string]::IsNullOrWhiteSpace($explicitRole)) {
        switch ($explicitRole.Trim().ToLowerInvariant()) {
            "daily"        { return "daily" }
            "longitudinal" { return "longitudinal" }
        }
    }

    $promptId =
        [string](Get-PropertyValue $Row "prompt_id" "")

    if (
        $promptId -match
        '^(?i:daily)(?:[-_]|$)'
    ) {
        return "daily"
    }

    if (
        $promptId -match
        '^(?i:longitudinal)(?:[-_]|$)'
    ) {
        return "longitudinal"
    }

    return "unknown"
}


function Read-Jsonl {
    param(
        [string]$Path,
        [ref]$Warnings
    )

    $rows = @()

    foreach (
        $lineRaw in (
            Get-Content `
                -LiteralPath $Path `
                -Encoding UTF8
        )
    ) {
        $line = $lineRaw.Trim()

        if ([string]::IsNullOrWhiteSpace($line)) {
            continue
        }

        try {
            $rows += ($line | ConvertFrom-Json)
        }
        catch {
            $Warnings.Value +=
                "Malformed JSONL line ignored in $Path."
        }
    }

    return @($rows)
}


function Get-LastObservedAt {
    param(
        [array]$Rows
    )

    $timestamps = @(
        $Rows |
        ForEach-Object {
            [string](Get-PropertyValue $_ "api_timestamp" "")
        } |
        Where-Object {
            -not [string]::IsNullOrWhiteSpace($_)
        } |
        Sort-Object -Descending
    )

    if ($timestamps.Count -gt 0) {
        return $timestamps[0]
    }

    return (
        Get-Date
    ).ToUniversalTime().ToString(
        "yyyy-MM-ddTHH:mm:ss.fffZ"
    )
}


function Get-UniqueNonEmptyValues {
    param(
        [array]$Rows,
        [string]$PropertyName
    )

    return @(
        $Rows |
        ForEach-Object {
            [string](Get-PropertyValue $_ $PropertyName "")
        } |
        Where-Object {
            -not [string]::IsNullOrWhiteSpace($_)
        } |
        Select-Object -Unique
    )
}


# Reference-only: lists the already-published NeoMundi RGC interoperability
# contract paths for the observations composing this daily/longitudinal
# aggregate. This never merges, recomputes, or re-derives contract content --
# it only points at files a runner already wrote via
# AI_WEATHER_RUNNER\lib\Publish-InteroperabilityContract.ps1. A row whose
# fetch did not succeed (status other than "published") is simply omitted.
function Get-InteroperabilityContractPaths {
    param(
        [array]$Rows,
        [string]$Provider,
        [string]$DateStr
    )

    return @(
        $Rows |
        Where-Object {
            [string](Get-PropertyValue $_ "interoperability_contract_status" "") -eq "published"
        } |
        ForEach-Object {
            $requestId = [string](Get-PropertyValue $_ "request_id" "")
            if (-not [string]::IsNullOrWhiteSpace($requestId)) {
                "aiweather-capsule/interoperability/$DateStr/$Provider-$requestId.json"
            }
        }
    )
}


# ------------------------------------------------------------
# 3. Multi-signal Weather interpretation
#
# ACTIVE v0.2 states:
#   CLEAR / WATCH / UNSETTLED
#
# RESERVED:
#   ALERT -> J4
#
# Technical state:
#   INSUFFICIENT_DATA
#
# Precedence:
#   INSUFFICIENT_DATA > UNSETTLED > WATCH > CLEAR
# ------------------------------------------------------------

function Get-WeatherInterpretation {
    param(
        [int]$FullyScored,
        [int]$ExpectedObservations,
        [int]$NormalCount,
        [int]$VariationCount,
        [int]$FactualAlertCount,
        [double]$Score,
        [bool]$ProtocolValid = $true
    )

    if (-not $ProtocolValid) {
        return [PSCustomObject]@{
            condition = "insufficient_data"
            coverage = Get-Ratio $FullyScored $ExpectedObservations
            coverage_status = "insufficient"
            drivers = @("daily_probe_protocol_mismatch")
            rules_matched = @("AWI-000")
        }
    }

    $coverage =
        Get-Ratio `
            -Numerator $FullyScored `
            -Denominator $ExpectedObservations

    if ($coverage -lt $COVERAGE_MIN_INTERPRETABLE) {
        return [PSCustomObject]@{
            condition = "insufficient_data"
            coverage = $coverage
            coverage_status = "insufficient"
            drivers = @("insufficient_coverage")
            rules_matched = @("AWI-001")
        }
    }

    $drivers = @()
    $rulesMatched = @()

    if ($Score -lt $THRESHOLD_VARIABLE) {
        $drivers += "runtime_degradation_material"
        $rulesMatched += "AWI-012"

        if ($FactualAlertCount -gt 0) {
            $drivers += "factual_signal_elevated"
        }

        if ($VariationCount -gt 0) {
            $drivers += "runtime_variation_elevated"
        }

        if (
            $NormalCount -gt 0 -and
            $FactualAlertCount -gt 0
        ) {
            $drivers += "signal_conflict_material"
        }

        if ($coverage -lt $COVERAGE_NOMINAL) {
            $drivers += "coverage_reduced_but_valid"
        }

        return [PSCustomObject]@{
            condition = "unsettled"
            coverage = $coverage
            coverage_status = $(
                if ($coverage -ge $COVERAGE_NOMINAL) {
                    "nominal"
                }
                else {
                    "reduced_but_valid"
                }
            )
            drivers = @($drivers | Select-Object -Unique)
            rules_matched = @($rulesMatched | Select-Object -Unique)
        }
    }

    if ($FactualAlertCount -gt 0) {
        $drivers += "factual_signal_elevated"
        $rulesMatched += "AWI-020"
    }

    if ($VariationCount -gt 0) {
        $drivers += "runtime_variation_elevated"
        $rulesMatched += "AWI-021"
    }

    if (
        $coverage -ge $COVERAGE_MIN_INTERPRETABLE -and
        $coverage -lt $COVERAGE_NOMINAL
    ) {
        $drivers += "coverage_reduced_but_valid"
        $rulesMatched += "AWI-025"
    }

    if ($Score -lt $THRESHOLD_CLEAR) {
        $drivers += "aggregate_runtime_deviation"
        $rulesMatched += "AWI-023"
    }

    if ($drivers.Count -gt 0) {
        return [PSCustomObject]@{
            condition = "watch"
            coverage = $coverage
            coverage_status = $(
                if ($coverage -ge $COVERAGE_NOMINAL) {
                    "nominal"
                }
                else {
                    "reduced_but_valid"
                }
            )
            drivers = @($drivers | Select-Object -Unique)
            rules_matched = @($rulesMatched | Select-Object -Unique)
        }
    }

    return [PSCustomObject]@{
        condition = "clear"
        coverage = $coverage
        coverage_status = "nominal"
        drivers = @("no_adverse_signal_detected")
        rules_matched = @("AWI-030")
    }
}


# ------------------------------------------------------------
# 4. Judgment Demand
#
# 4 Weather states exist conceptually:
#
# CLEAR     -> J1
# WATCH     -> J2
# UNSETTLED -> J3
# ALERT     -> J4
#
# ALERT/J4 is RESERVED in this profile version.
# It is not automatically emitted by Get-WeatherInterpretation.
#
# INSUFFICIENT_DATA is not a fifth Judgment level.
# It means Judgment Demand cannot be determined.
# ------------------------------------------------------------

function Get-JudgmentDemand {
    param(
        [string]$Condition
    )

    switch ($Condition.ToLowerInvariant()) {
        "clear" {
            return [PSCustomObject]@{
                profile = $JUDGMENT_DEMAND_PROFILE_ID
                profile_version = $JUDGMENT_DEMAND_PROFILE_VERSION
                level = "J1"
                label = "standard_judgment"
                meaning = "Standard judgment"
                derived_from_condition = "clear"
                status = "determined"
            }
        }

        "watch" {
            return [PSCustomObject]@{
                profile = $JUDGMENT_DEMAND_PROFILE_ID
                profile_version = $JUDGMENT_DEMAND_PROFILE_VERSION
                level = "J2"
                label = "increased_attention"
                meaning = "Increased attention"
                derived_from_condition = "watch"
                status = "determined"
            }
        }

        "unsettled" {
            return [PSCustomObject]@{
                profile = $JUDGMENT_DEMAND_PROFILE_ID
                profile_version = $JUDGMENT_DEMAND_PROFILE_VERSION
                level = "J3"
                label = "reinforced_review"
                meaning = "Reinforced review / judgment"
                derived_from_condition = "unsettled"
                status = "determined"
            }
        }

        "alert" {
            return [PSCustomObject]@{
                profile = $JUDGMENT_DEMAND_PROFILE_ID
                profile_version = $JUDGMENT_DEMAND_PROFILE_VERSION
                level = "J4"
                label = "explicit_oversight_required"
                meaning = "Explicit oversight required"
                derived_from_condition = "alert"
                status = "determined"
            }
        }

        default {
            return [PSCustomObject]@{
                profile = $JUDGMENT_DEMAND_PROFILE_ID
                profile_version = $JUDGMENT_DEMAND_PROFILE_VERSION
                level = $null
                label = $null
                meaning = "Judgment demand not determined"
                derived_from_condition = $Condition
                status = "not_determined"
                reason = "insufficient_data"
            }
        }
    }
}


# ------------------------------------------------------------
# 5. Probe aggregation
# ------------------------------------------------------------

function Get-ProbeAggregate {
    param(
        [array]$Rows,
        [int]$ExpectedObservations,
        [string]$Role,
        [bool]$WeatherAuthority,
        [string]$Provider = "",
        [string]$DateStr = ""
    )

    $validRows = @(
        $Rows |
        Where-Object {
            $decision =
                [string](Get-PropertyValue $_ "decision" "")

            -not [string]::IsNullOrWhiteSpace($decision) -and
            $decision -ne "ERROR"
        }
    )

    $fullyScored = $validRows.Count

    $normalCount = @(
        $validRows |
        Where-Object {
            [string](Get-PropertyValue $_ "decision" "") -eq "ALLOW"
        }
    ).Count

    $factualAlertCount = @(
        $validRows |
        Where-Object {
            $decision =
                [string](Get-PropertyValue $_ "decision" "")

            $factual =
                Get-SafeDouble (
                    Get-PropertyValue $_ "factual_hallucination_score" 0
                )

            $decision -eq "FLAG" -and $factual -gt 0
        }
    ).Count

    $variationCount = @(
        $validRows |
        Where-Object {
            $decision =
                [string](Get-PropertyValue $_ "decision" "")

            $factual =
                Get-SafeDouble (
                    Get-PropertyValue $_ "factual_hallucination_score" 0
                )

            $decision -eq "FLAG" -and -not ($factual -gt 0)
        }
    ).Count

    $incompleteCount =
        [math]::Max(
            0,
            $ExpectedObservations - $fullyScored
        )

    $coverage =
        Get-Ratio `
            -Numerator $fullyScored `
            -Denominator $ExpectedObservations

    $score =
        if ($fullyScored -gt 0) {
            [math]::Round(
                100.0 * $normalCount / $fullyScored
            )
        }
        else {
            0
        }

    $promptIds = @(
        Get-UniqueNonEmptyValues `
            -Rows $Rows `
            -PropertyName "prompt_id"
    )

    $questions = @(
        Get-UniqueNonEmptyValues `
            -Rows $Rows `
            -PropertyName "question"
    )

    # Exactly one stimulus per probe role is part of protocol v0.2.
    # A missing prompt id is tolerated only if there are no rows;
    # once rows exist, ambiguity is treated as a protocol failure.
    $protocolValid =
        if ($Rows.Count -eq 0) {
            $true
        }
        else {
            $promptIds.Count -eq 1
        }

    $base = [ordered]@{
        role = $Role
        observations = $Rows.Count
        expected_observations = $ExpectedObservations
        fully_scored = $fullyScored
        coverage = $coverage
        coverage_status = $(
            if ($coverage -ge $COVERAGE_NOMINAL) {
                "nominal"
            }
            elseif ($coverage -ge $COVERAGE_MIN_INTERPRETABLE) {
                "reduced_but_valid"
            }
            else {
                "insufficient"
            }
        )
        protocol_valid = $protocolValid
        prompt_id = $(
            if ($promptIds.Count -eq 1) {
                $promptIds[0]
            }
            else {
                $null
            }
        )
        prompt_ids_observed = @($promptIds)
        score = $score
        metrics = [PSCustomObject]@{
            normal =
                Get-Ratio $normalCount $ExpectedObservations
            variation =
                Get-Ratio $variationCount $ExpectedObservations
            factual_alert =
                Get-Ratio $factualAlertCount $ExpectedObservations
            incomplete =
                Get-Ratio $incompleteCount $ExpectedObservations
        }
        regime_distribution = [PSCustomObject]@{
            normal = $normalCount
            variation = $variationCount
            factual_alert = $factualAlertCount
            incomplete = $incompleteCount
        }
        last_observed_at =
            Get-LastObservedAt -Rows $Rows
        interoperability_contracts = @(
            Get-InteroperabilityContractPaths `
                -Rows $Rows `
                -Provider $Provider `
                -DateStr $DateStr
        )
    }

    if ($Role -eq "daily") {
        # DAILY is intended for public Wall rendering.
        $base["question"] =
            if ($questions.Count -eq 1) {
                $questions[0]
            }
            else {
                $null
            }

        $base["question_exposure"] = "public_daily"
    }
    else {
        # Longitudinal probe content stays in the private panel/lab.
        # Public daily JSON carries the stable probe id and measurements,
        # not the raw fixed question text.
        $base["question"] = $null
        $base["question_exposure"] = "lab_only"
    }

    if ($WeatherAuthority) {
        $interpretation =
            Get-WeatherInterpretation `
                -FullyScored $fullyScored `
                -ExpectedObservations $ExpectedObservations `
                -NormalCount $normalCount `
                -VariationCount $variationCount `
                -FactualAlertCount $factualAlertCount `
                -Score $score `
                -ProtocolValid $protocolValid

        $base["condition"] =
            $interpretation.condition

        $base["interpretation"] =
            [PSCustomObject]@{
                profile = $INTERPRETATION_PROFILE_ID
                profile_version = $INTERPRETATION_PROFILE_VERSION
                matrix_version = $INTERPRETATION_MATRIX_VERSION
                condition = $interpretation.condition
                drivers = @($interpretation.drivers)
                rules_matched = @($interpretation.rules_matched)
                coverage_status = $interpretation.coverage_status
                coverage_thresholds = [PSCustomObject]@{
                    nominal_min = $COVERAGE_NOMINAL
                    interpretable_min = $COVERAGE_MIN_INTERPRETABLE
                }
                evaluated_at =
                    (
                        Get-Date
                    ).ToUniversalTime().ToString(
                        "yyyy-MM-ddTHH:mm:ss.fffZ"
                    )
            }

        $base["judgment_demand"] =
            Get-JudgmentDemand `
                -Condition $interpretation.condition
    }
    else {
        $base["condition"] = $null
        $base["interpretation"] = $null
        $base["judgment_demand"] = $null
        $base["weather_authority"] = $false
        $base["lab_status"] =
            if (
                $protocolValid -and
                $coverage -ge $COVERAGE_MIN_INTERPRETABLE
            ) {
                "measured"
            }
            else {
                "insufficient_data"
            }
    }

    return [PSCustomObject]$base
}


# ------------------------------------------------------------
# 6. Locate repository
# ------------------------------------------------------------

$runnerRoot = $PSScriptRoot
$repoRoot = $runnerRoot

while (
    -not (
        Test-Path (
            Join-Path $repoRoot "weather.json"
        )
    ) -and
    (Split-Path $repoRoot -Parent) -ne $repoRoot
) {
    $repoRoot = Split-Path $repoRoot -Parent
}

if (
    -not (
        Test-Path (
            Join-Path $repoRoot "weather.json"
        )
    )
) {
    throw @"
Could not locate repository root.

No weather.json was found while walking upward from:

$runnerRoot
"@
}

$resultsDirCandidates = @(
    (Join-Path $runnerRoot "results\$Date"),
    (Join-Path $repoRoot "AI_WEATHER_RUNNER\results\$Date")
)

$resultsDir =
    $resultsDirCandidates |
    Where-Object { Test-Path $_ } |
    Select-Object -First 1

if (-not $resultsDir) {
    throw @"
No results folder found for $Date.

Tried:

$($resultsDirCandidates -join "`n")
"@
}

$panelYmlPath = Join-Path $repoRoot "config\panel.yml"
$weatherJsonPath = Join-Path $repoRoot "weather.json"
$currentJsonPath = Join-Path $repoRoot "data\current.json"
$historyDir = Join-Path $repoRoot "data\history"
$historyJsonPath = Join-Path $historyDir "$Date.json"

if (-not (Test-Path -LiteralPath $panelYmlPath)) {
    throw "Panel file not found: $panelYmlPath"
}


# ------------------------------------------------------------
# 7. Minimal panel.yml parser
# ------------------------------------------------------------

function Parse-PanelYml {
    param(
        [string]$Path
    )

    $entries = @()

    $lines =
        Get-Content `
            -LiteralPath $Path `
            -Encoding UTF8

    foreach ($line in $lines) {
        if ($line -notmatch '^\s*-\s*\{(.+)\}\s*$') {
            continue
        }

        $body = $Matches[1]

        function Get-Field {
            param(
                [string]$Body,
                [string]$Key
            )

            if ($Body -match "$Key\s*:\s*""([^""]*)""") {
                return $Matches[1]
            }

            if ($Body -match "$Key\s*:\s*null") {
                return $null
            }

            if ($Body -match "$Key\s*:\s*(true|false)") {
                return [bool]::Parse($Matches[1])
            }

            return $null
        }

        $entries += [PSCustomObject]@{
            id = Get-Field $body "id"
            provider = Get-Field $body "provider"
            model_id = Get-Field $body "model_id"
            model_display = Get-Field $body "model_display"
            runner_provider = Get-Field $body "runner_provider"
            display_name = Get-Field $body "display_name"
            public_label = Get-Field $body "public_label"
            enabled = Get-Field $body "enabled"
        }
    }

    return $entries
}

$panel = @(
    Parse-PanelYml -Path $panelYmlPath |
    Where-Object {
        $_.enabled -ne $false
    }
)


# ------------------------------------------------------------
# 8. Previous state
#
# Previous daily condition is context only.
# It is never treated as a new measurement.
# ------------------------------------------------------------

$previousData = $null

if (Test-Path $weatherJsonPath) {
    try {
        $previousData =
            Get-Content `
                -LiteralPath $weatherJsonPath `
                -Raw `
                -Encoding UTF8 |
            ConvertFrom-Json
    }
    catch {
        Write-Host `
            "WARNING: existing weather.json could not be parsed." `
            -ForegroundColor Yellow
    }
}

function Get-PreviousSystem {
    param(
        [string]$Id
    )

    if ($null -eq $previousData) {
        return $null
    }

    $previousSystems =
        Get-PropertyValue `
            -Object $previousData `
            -Name "systems" `
            -Default @()

    return (
        @($previousSystems) |
        Where-Object {
            [string](Get-PropertyValue $_ "id" "") -eq $Id
        } |
        Select-Object -First 1
    )
}


# ------------------------------------------------------------
# 9. Candidate result directories
# ------------------------------------------------------------

$dateObj =
    [datetime]::ParseExact(
        $Date,
        "yyyy-MM-dd",
        [System.Globalization.CultureInfo]::InvariantCulture
    )

$resultsFlatDir =
    Split-Path $resultsDir -Parent

$searchDirs = @($resultsDir)

if (
    $resultsFlatDir -and
    (Test-Path -LiteralPath $resultsFlatDir) -and
    ($resultsFlatDir -ne $resultsDir)
) {
    $searchDirs += $resultsFlatDir
}


# ------------------------------------------------------------
# 10. Aggregate systems
# ------------------------------------------------------------

$systems = @()
$warnings = @()

foreach ($entry in $panel) {
    $prevSys =
        Get-PreviousSystem `
            -Id $entry.id

    $rawMatches =
        foreach ($dir in $searchDirs) {
            Get-ChildItem `
                -LiteralPath $dir `
                -Filter "$($entry.runner_provider)_*_results.jsonl" `
                -File `
                -ErrorAction SilentlyContinue
        }

    $matchedFiles = @(
        $rawMatches |
        Where-Object {
            $_.LastWriteTime -ge $dateObj -and
            $_.LastWriteTime -lt $dateObj.AddDays(1).AddHours(8)
        } |
        Sort-Object LastWriteTime -Descending
    )

    $rows = @()
    $resultsFile = $null

    if ($matchedFiles.Count -gt 0) {
        $resultsFile = $matchedFiles[0].FullName
        $rows =
            Read-Jsonl `
                -Path $resultsFile `
                -Warnings ([ref]$warnings)
    }
    else {
        $warnings +=
            "No result file found for '$($entry.id)' on $Date."
    }

    $dailyRows = @(
        $rows |
        Where-Object {
            (Get-ProbeRole $_) -eq "daily"
        }
    )

    $longitudinalRows = @(
        $rows |
        Where-Object {
            (Get-ProbeRole $_) -eq "longitudinal"
        }
    )

    $unknownRows = @(
        $rows |
        Where-Object {
            (Get-ProbeRole $_) -eq "unknown"
        }
    )

    if ($unknownRows.Count -gt 0) {
        $warnings +=
            "$($entry.id): $($unknownRows.Count) row(s) have no recognized probe role and were excluded."
    }

    $daily =
        Get-ProbeAggregate `
            -Rows $dailyRows `
            -ExpectedObservations $DAILY_PROBE_EXPECTED `
            -Role "daily" `
            -WeatherAuthority $true `
            -Provider $entry.runner_provider `
            -DateStr $Date

    $longitudinal =
        Get-ProbeAggregate `
            -Rows $longitudinalRows `
            -ExpectedObservations $LONGITUDINAL_PROBE_EXPECTED `
            -Role "longitudinal" `
            -WeatherAuthority $false `
            -Provider $entry.runner_provider `
            -DateStr $Date

    $previousCondition =
        if ($null -ne $prevSys) {
            [string](Get-PropertyValue $prevSys "condition" "")
        }
        else {
            $null
        }

    if ([string]::IsNullOrWhiteSpace($previousCondition)) {
        $previousCondition = $null
    }

    # Backward-compatible top-level Weather fields are aliases of DAILY.
    # This lets the current Wall continue reading systems[].condition,
    # score, coverage and metrics while the richer probe split is added.
    $system = [PSCustomObject]@{
        id = $entry.id
        display_name = $entry.display_name
        provider = $entry.provider
        provider_slug = $entry.id
        provider_display = $entry.provider
        model = $entry.model_id
        model_display = $entry.model_display
        model_public = $(
            if (
                [string]::IsNullOrWhiteSpace(
                    [string]$entry.public_label
                )
            ) {
                $entry.model_id
            }
            else {
                $null
            }
        )
        public_label = $entry.public_label

        condition = $daily.condition
        judgment_demand = $daily.judgment_demand
        score = $daily.score
        coverage = $daily.coverage
        coverage_status = $daily.coverage_status
        metrics = $daily.metrics
        interpretation = $daily.interpretation

        observations =
            $daily.observations +
            $longitudinal.observations

        expected_observations =
            $EXPECTED_OBSERVATIONS_PER_SYSTEM

        fully_scored =
            $daily.fully_scored +
            $longitudinal.fully_scored

        total_coverage =
            Get-Ratio `
                -Numerator (
                    $daily.fully_scored +
                    $longitudinal.fully_scored
                ) `
                -Denominator $EXPECTED_OBSERVATIONS_PER_SYSTEM

        daily = $daily
        longitudinal = $longitudinal

        last_observed_at =
            @(
                $daily.last_observed_at,
                $longitudinal.last_observed_at
            ) |
            Where-Object {
                -not [string]::IsNullOrWhiteSpace([string]$_)
            } |
            Sort-Object -Descending |
            Select-Object -First 1

        detail = [PSCustomObject]@{
            previous_condition = $previousCondition
            source_file = $(
                if ($null -ne $resultsFile) {
                    [System.IO.Path]::GetFileName($resultsFile)
                }
                else {
                    $null
                }
            )
            unknown_probe_rows = $unknownRows.Count
            weather_authority = "daily_only"
            longitudinal_influences_weather = $false
        }
    }

    $systems += $system
}


# ------------------------------------------------------------
# 11. Global Weather state
#
# Uses systems[].condition, which is DAILY ONLY.
#
# If one or more systems are INSUFFICIENT_DATA:
# global panel condition is INSUFFICIENT_DATA.
#
# Otherwise strongest active observed state:
#
# ALERT > UNSETTLED > WATCH > CLEAR
#
# ALERT remains reserved, but the reducer understands it.
# ------------------------------------------------------------

function Get-GlobalCondition {
    param(
        [array]$Systems
    )

    if ($Systems.Count -eq 0) {
        return "insufficient_data"
    }

    foreach ($state in @(
        "insufficient_data",
        "alert",
        "unsettled",
        "watch"
    )) {
        if (
            @(
                $Systems |
                Where-Object {
                    $_.condition -eq $state
                }
            ).Count -gt 0
        ) {
            return $state
        }
    }

    return "clear"
}

$globalCondition =
    Get-GlobalCondition `
        -Systems $systems

$globalJudgmentDemand =
    Get-JudgmentDemand `
        -Condition $globalCondition


# ------------------------------------------------------------
# 12. Panel summaries
# ------------------------------------------------------------

$dailyScoredSystems = @(
    $systems |
    Where-Object {
        $null -ne $_.daily.score
    }
)

$globalScore =
    if ($dailyScoredSystems.Count -gt 0) {
        [math]::Round(
            (
                $dailyScoredSystems |
                ForEach-Object {
                    $_.daily.score
                } |
                Measure-Object -Average
            ).Average
        )
    }
    else {
        $null
    }

$totalObservations = (
    $systems |
    Measure-Object -Property observations -Sum
).Sum

$totalExpectedObservations =
    $panel.Count *
    $EXPECTED_OBSERVATIONS_PER_SYSTEM

$totalFullyScored = (
    $systems |
    Measure-Object -Property fully_scored -Sum
).Sum

$panelCoverage =
    Get-Ratio `
        -Numerator $totalFullyScored `
        -Denominator $totalExpectedObservations

$dailyFullyScored = (
    $systems |
    ForEach-Object {
        $_.daily.fully_scored
    } |
    Measure-Object -Sum
).Sum

$dailyExpected =
    $panel.Count *
    $DAILY_PROBE_EXPECTED

$dailyPanelCoverage =
    Get-Ratio `
        -Numerator $dailyFullyScored `
        -Denominator $dailyExpected

$longitudinalFullyScored = (
    $systems |
    ForEach-Object {
        $_.longitudinal.fully_scored
    } |
    Measure-Object -Sum
).Sum

$longitudinalExpected =
    $panel.Count *
    $LONGITUDINAL_PROBE_EXPECTED

$longitudinalPanelCoverage =
    Get-Ratio `
        -Numerator $longitudinalFullyScored `
        -Denominator $longitudinalExpected

$lastMeasurementAt = (
    $systems |
    ForEach-Object {
        $_.last_observed_at
    } |
    Where-Object {
        -not [string]::IsNullOrWhiteSpace([string]$_)
    } |
    Sort-Object -Descending |
    Select-Object -First 1
)

$clearSystems = @(
    $systems |
    Where-Object {
        $_.condition -eq "clear"
    }
)

$watchSystems = @(
    $systems |
    Where-Object {
        $_.condition -eq "watch"
    }
)

$unsettledSystems = @(
    $systems |
    Where-Object {
        $_.condition -eq "unsettled"
    }
)

$alertSystems = @(
    $systems |
    Where-Object {
        $_.condition -eq "alert"
    }
)

$insufficientSystems = @(
    $systems |
    Where-Object {
        $_.condition -eq "insufficient_data"
    }
)


# ------------------------------------------------------------
# 13. Probe metadata
# ------------------------------------------------------------

$dailyPromptIds = @(
    $systems |
    ForEach-Object {
        $_.daily.prompt_id
    } |
    Where-Object {
        -not [string]::IsNullOrWhiteSpace([string]$_)
    } |
    Select-Object -Unique
)

$dailyQuestions = @(
    $systems |
    ForEach-Object {
        $_.daily.question
    } |
    Where-Object {
        -not [string]::IsNullOrWhiteSpace([string]$_)
    } |
    Select-Object -Unique
)

# DAILY question fallback.
#
# Some provider JSONL rows do not preserve the source question text.
# The selected execution panel is therefore the authoritative fallback for
# the public Question of the Day. The fallback is used only when the
# aggregated DAILY rows do not already expose exactly one question.
$dailyQuestionFromPanel = $null
$executionPanelPath =
    Join-Path $runnerRoot "data\panels\ai_weather_panel.csv"

if (Test-Path -LiteralPath $executionPanelPath) {
    try {
        $executionPanelRows = @(
            Import-Csv -LiteralPath $executionPanelPath
        )

        $dailyPanelCandidates = @(
            $executionPanelRows |
            Where-Object {
                $panelPromptId = [string](
                    Get-PropertyValue $_ "prompt_id" ""
                )

                $panelPromptId -match
                    '^(?i:daily)(?:[-_]|$)'
            }
        )

        # If the measured systems agree on one DAILY prompt_id, prefer the
        # matching panel row. This prevents a stale/extra DAILY row from
        # becoming public by accident.
        if ($dailyPromptIds.Count -eq 1) {
            $expectedDailyPromptId =
                [string]$dailyPromptIds[0]

            $matchingDailyPanelRows = @(
                $dailyPanelCandidates |
                Where-Object {
                    [string](
                        Get-PropertyValue $_ "prompt_id" ""
                    ) -eq $expectedDailyPromptId
                }
            )

            if ($matchingDailyPanelRows.Count -eq 1) {
                $candidateQuestion = [string](
                    Get-PropertyValue `
                        $matchingDailyPanelRows[0] `
                        "question" `
                        ""
                )

                if (-not [string]::IsNullOrWhiteSpace(
                    $candidateQuestion
                )) {
                    $dailyQuestionFromPanel =
                        $candidateQuestion.Trim()
                }
            }
        }
        elseif ($dailyPanelCandidates.Count -eq 1) {
            # Defensive fallback for incomplete/smoke data where a unique
            # DAILY prompt_id may not be recoverable from result rows.
            $candidateQuestion = [string](
                Get-PropertyValue `
                    $dailyPanelCandidates[0] `
                    "question" `
                    ""
            )

            if (-not [string]::IsNullOrWhiteSpace(
                $candidateQuestion
            )) {
                $dailyQuestionFromPanel =
                    $candidateQuestion.Trim()
            }
        }
    }
    catch {
        Write-Warning (
            "Unable to read DAILY question fallback from " +
            "'$executionPanelPath': $($_.Exception.Message)"
        )
    }
}

$longitudinalPromptIds = @(
    $systems |
    ForEach-Object {
        $_.longitudinal.prompt_id
    } |
    Where-Object {
        -not [string]::IsNullOrWhiteSpace([string]$_)
    } |
    Select-Object -Unique
)

$resolvedDailyQuestion = $(
    if ($dailyQuestions.Count -eq 1) {
        $dailyQuestions[0]
    }
    elseif (-not [string]::IsNullOrWhiteSpace(
        $dailyQuestionFromPanel
    )) {
        $dailyQuestionFromPanel
    }
    else {
        $null
    }
)

# Best-effort translation of today's public question. Never throws;
# returns an empty set on any failure (see Get-DailyQuestionTranslations
# in section 0.1). The front-end already falls back to English when a
# language is missing from this set.
$dailyQuestionTranslations =
    Get-DailyQuestionTranslations `
        -QuestionText $resolvedDailyQuestion `
        -TargetLanguages $DAILY_QUESTION_TRANSLATION_LANGS

$dailyProbeMetadata = [PSCustomObject]@{
    role = "daily"
    weather_authority = $true
    expected_repetitions_per_system =
        $DAILY_PROBE_EXPECTED
    prompt_id = $(
        if ($dailyPromptIds.Count -eq 1) {
            $dailyPromptIds[0]
        }
        else {
            $null
        }
    )
    question = $resolvedDailyQuestion
    question_translations = $dailyQuestionTranslations
    exposure = "wall_public"
    panel_coverage = $dailyPanelCoverage
}

$longitudinalProbeMetadata = [PSCustomObject]@{
    role = "longitudinal"
    weather_authority = $false
    expected_repetitions_per_system =
        $LONGITUDINAL_PROBE_EXPECTED
    probe_id = $(
        if ($longitudinalPromptIds.Count -eq 1) {
            $longitudinalPromptIds[0]
        }
        else {
            $null
        }
    )
    question = $null
    exposure = "lab_only"
    panel_coverage = $longitudinalPanelCoverage
}


# ------------------------------------------------------------
# 14. Canonical daily output
# ------------------------------------------------------------

$output = [PSCustomObject]@{
    demo = $false

    generated_at =
        (
            Get-Date
        ).ToUniversalTime().ToString(
            "yyyy-MM-ddTHH:mm:ss.fffZ"
        )

    protocol = [PSCustomObject]@{
        id = $PROTOCOL_ID
        version = $PROTOCOL_VERSION

        expected_observations_per_system =
            $EXPECTED_OBSERVATIONS_PER_SYSTEM

        daily_probe_expected =
            $DAILY_PROBE_EXPECTED

        longitudinal_probe_expected =
            $LONGITUDINAL_PROBE_EXPECTED

        daily_weather_authority =
            $true

        longitudinal_weather_authority =
            $false

        total_expected_panel_observations =
            $panel.Count *
            $EXPECTED_OBSERVATIONS_PER_SYSTEM

        role_resolution =
            "probe_role_then_prompt_id_prefix"

        alert_status =
            "reserved"

        temperature =
            $null
    }

    probe_contract = [PSCustomObject]@{
        daily = $dailyProbeMetadata
        longitudinal = $longitudinalProbeMetadata
    }

    interpretation_contract = [PSCustomObject]@{
        source_contract = $SOURCE_CONTRACT
        source_rules = $SOURCE_RULES

        profile = $INTERPRETATION_PROFILE_ID
        profile_version = $INTERPRETATION_PROFILE_VERSION
        matrix_version = $INTERPRETATION_MATRIX_VERSION

        judgment_demand_profile =
            $JUDGMENT_DEMAND_PROFILE_ID

        judgment_demand_profile_version =
            $JUDGMENT_DEMAND_PROFILE_VERSION

        coverage_policy =
            "ai_weather_probe_split_coverage_v0.2"

        coverage_nominal_min =
            $COVERAGE_NOMINAL

        coverage_interpretable_min =
            $COVERAGE_MIN_INTERPRETABLE

        active_weather_states =
            @(
                "clear",
                "watch",
                "unsettled"
            )

        reserved_weather_states =
            @(
                "alert"
            )

        non_weather_states =
            @(
                "insufficient_data"
            )

        global_aggregation_policy =
            "daily_probe_full_panel_required_then_strongest_state_v0.2"

        longitudinal_policy =
            "measured_separately_never_influences_daily_weather_v0.2"
    }

    global_condition = $globalCondition
    global_judgment_demand = $globalJudgmentDemand

    # Legacy score preserved for continuity.
    # It is computed from DAILY observations only.
    global_score = $globalScore

    panel_summary = [PSCustomObject]@{
        systems_count = $systems.Count
        systems_expected = $panel.Count

        systems_clear = $clearSystems.Count
        systems_watch = $watchSystems.Count
        systems_unsettled = $unsettledSystems.Count
        systems_alert = $alertSystems.Count
        systems_insufficient_data =
            $insufficientSystems.Count

        total_observations = $totalObservations
        total_expected_observations =
            $totalExpectedObservations
        total_fully_scored = $totalFullyScored
        panel_coverage = $panelCoverage

        daily_observations_expected =
            $dailyExpected
        daily_fully_scored =
            $dailyFullyScored
        daily_panel_coverage =
            $dailyPanelCoverage

        longitudinal_observations_expected =
            $longitudinalExpected
        longitudinal_fully_scored =
            $longitudinalFullyScored
        longitudinal_panel_coverage =
            $longitudinalPanelCoverage

        last_measurement_at =
            $lastMeasurementAt
    }

    systems = $systems
}


# ------------------------------------------------------------
# 15. Local safety checks
#
# These do NOT publish.
# They flag malformed/incomplete daily artifacts for inspection.
# ------------------------------------------------------------

$validationIssues = @()

if ($systems.Count -lt $panel.Count) {
    $validationIssues +=
        "Only $($systems.Count)/$($panel.Count) systems are present."
}

if ($systems.Count -eq 0) {
    $validationIssues +=
        "No systems available."
}

if ($dailyPromptIds.Count -gt 1) {
    $validationIssues +=
        "Multiple DAILY prompt_id values detected across systems: $($dailyPromptIds -join ', ')"
}

if ($dailyQuestions.Count -gt 1) {
    $validationIssues +=
        "Multiple DAILY question texts detected across systems."
}

if ($longitudinalPromptIds.Count -gt 1) {
    $validationIssues +=
        "Multiple LONGITUDINAL probe ids detected across systems: $($longitudinalPromptIds -join ', ')"
}

try {
    $null =
        $output |
        ConvertTo-Json -Depth 40 -Compress |
        ConvertFrom-Json
}
catch {
    $validationIssues +=
        "Generated JSON failed round-trip validation: $($_.Exception.Message)"
}


# ------------------------------------------------------------
# 16. Warnings
# ------------------------------------------------------------

if ($warnings.Count -gt 0) {
    Write-Host ""
    Write-Host "--- Warnings ---" -ForegroundColor Yellow

    $warnings |
    ForEach-Object {
        Write-Host "  $_" -ForegroundColor Yellow
    }
}


# ------------------------------------------------------------
# 16b. V2 longitudinal enrichment (fail-open, merged BEFORE the canonical
# writes below)
#
# Activated 2026-09-16 as part of the AI Weather V2 launch (see
# AI_WEATHER_V2_FINAL_GO_NO_GO.md / AI_WEATHER_V2_LAUNCH_REPORT_2026-09-21.md).
# Until this date, this block only wrote an isolated shadow copy under
# data/shadow/v2/ and never touched $output - see git history /
# AI_WEATHER_V2_UPSTREAM_WIRING_VALIDATION.md for that shadow-only phase.
#
# Fail-open: any failure here (missing engine, exception, invalid schema,
# insufficient coverage) is caught and silently skipped, leaving $output
# exactly as the legacy pipeline produced it - the three writes below then
# still succeed with legacy-only data, exactly as before this date. Single
# source of truth for the longitudinal math stays longitudinal_engine.ps1
# (via longitudinal_v2_bridge.ps1) - nothing here reimplements
# baseline/MAD/state/event/uncertainty logic.
# ------------------------------------------------------------

try {
    $bridgePath = Join-Path $runnerRoot "longitudinal_v2_bridge.ps1"
    if (Test-Path -LiteralPath $bridgePath) {
        . $bridgePath
        $v2Report = Get-LongitudinalV2Report -RunnerRoot $runnerRoot -RepoRoot $repoRoot -Date $Date
        if ($v2Report) {
            $enriched = Merge-LongitudinalV2IntoHistory -LegacyOutput $output -V2Report $v2Report
            if ($enriched) {
                $output = $enriched
                Write-Host "V2 longitudinal enrichment merged into canonical output."
            }
        }
    }
}
catch {
    Write-Host "V2 longitudinal enrichment skipped (fail-open): $($_.Exception.Message)" -ForegroundColor DarkYellow
}


# ------------------------------------------------------------
# 17. Write canonical local JSON
# ------------------------------------------------------------

$json =
    $output |
    ConvertTo-Json -Depth 40

Set-Content `
    -LiteralPath $weatherJsonPath `
    -Value $json `
    -Encoding UTF8

New-Item `
    -ItemType Directory `
    -Force `
    -Path (
        Split-Path $currentJsonPath -Parent
    ) |
    Out-Null

Set-Content `
    -LiteralPath $currentJsonPath `
    -Value $json `
    -Encoding UTF8

New-Item `
    -ItemType Directory `
    -Force `
    -Path $historyDir |
    Out-Null

Set-Content `
    -LiteralPath $historyJsonPath `
    -Value $json `
    -Encoding UTF8


# ------------------------------------------------------------
# 18. Console report
# ------------------------------------------------------------

Write-Host ""
Write-Host `
    "=== AI WEATHER -- DAILY + LONGITUDINAL v0.2 ===" `
    -ForegroundColor Cyan

Write-Host "Date                         : $Date"
Write-Host "Repo root                    : $repoRoot"
Write-Host "Results dir                  : $resultsDir"
Write-Host "Panel systems enabled        : $($panel.Count)"
Write-Host ""
Write-Host "DAILY expected / system      : $DAILY_PROBE_EXPECTED"
Write-Host "LONGITUDINAL expected/system : $LONGITUDINAL_PROBE_EXPECTED"
Write-Host "TOTAL expected / system      : $EXPECTED_OBSERVATIONS_PER_SYSTEM"
Write-Host ""
Write-Host "Global condition             : $globalCondition"

if ($null -ne $globalJudgmentDemand.level) {
    Write-Host `
        "Global Judgment              : $($globalJudgmentDemand.level) -- $($globalJudgmentDemand.meaning)"
}
else {
    Write-Host `
        "Global Judgment              : NOT DETERMINED"
}

Write-Host "Legacy DAILY global score    : $globalScore"
Write-Host `
    "DAILY panel coverage         : $([math]::Round($dailyPanelCoverage * 100, 1))%"

Write-Host `
    "LONGITUDINAL panel coverage  : $([math]::Round($longitudinalPanelCoverage * 100, 1))%"

Write-Host `
    "TOTAL panel coverage         : $([math]::Round($panelCoverage * 100, 1))%"

Write-Host ""
Write-Host "Systems written              : $($systems.Count)/$($panel.Count)"
Write-Host "CLEAR                        : $($clearSystems.Count)"
Write-Host "WATCH                        : $($watchSystems.Count)"
Write-Host "UNSETTLED                    : $($unsettledSystems.Count)"
Write-Host "ALERT (reserved)             : $($alertSystems.Count)"
Write-Host "INSUFFICIENT_DATA            : $($insufficientSystems.Count)"
Write-Host ""
Write-Host "weather.json                 : $weatherJsonPath"
Write-Host "current.json                 : $currentJsonPath"
Write-Host "history/$Date.json           : $historyJsonPath"
Write-Host ""

Write-Host `
    "--- Model Weather (DAILY) + Longitudinal Lab ---" `
    -ForegroundColor Cyan

foreach ($system in $systems) {
    $driverText =
        @($system.interpretation.drivers) -join ", "

    $jLevel = $system.judgment_demand.level

    if ($null -eq $jLevel) {
        $jLevel = "-"
    }

    $dailyCoveragePercent =
        [math]::Round(
            [double]$system.daily.coverage * 100,
            1
        )

    $longCoveragePercent =
        [math]::Round(
            [double]$system.longitudinal.coverage * 100,
            1
        )

    Write-Host (
        "{0,-18} DAILY={1,-18} {2,-4} Dcov={3,5}% | LONG cov={4,5}% | {5}" -f
        $system.model_display,
        $system.condition,
        $jLevel,
        $dailyCoveragePercent,
        $longCoveragePercent,
        $driverText
    )
}

Write-Host ""


# ------------------------------------------------------------
# 19. Validation report
# ------------------------------------------------------------

if ($validationIssues.Count -gt 0) {
    Write-Host `
        "=== LOCAL VALIDATION ISSUES ===" `
        -ForegroundColor Yellow

    $validationIssues |
    ForEach-Object {
        Write-Host "  - $_" -ForegroundColor Yellow
    }

    Write-Host ""
}


# ------------------------------------------------------------
# 20. Publication boundary
#
# Intentionally NO git add / commit / push here.
#
# The canonical release sequence is:
#
# aggregate -> history -> capsule -> verify_chain -> publish
#
# run_ai_weather_pipeline.ps1 owns that sequence.
# ------------------------------------------------------------

Write-Host `
    "Aggregation complete locally." `
    -ForegroundColor Green

Write-Host `
    "Git publication intentionally disabled in aggregator; release occurs only after capsule + hash-chain verification." `
    -ForegroundColor Cyan

if ($NoPublish) {
    Write-Host `
        "NoPublish accepted (compatibility mode)." `
        -ForegroundColor DarkGray
}

exit 0

