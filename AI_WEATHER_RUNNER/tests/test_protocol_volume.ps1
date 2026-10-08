<#
    AI Weather -- protocol observation volume regression test.

    Proves, with no API call and without leaving a single production
    file modified, that:

      1. the volume is resolved from the ONE effective-dated config
         (config\protocol_volume.json) and nowhere else;
      2. an already measured day keeps the volume it was measured with
         (no retroactive rewriting of historical coverage);
      3. build_daily_panel.ps1 -- the step run_full_pipeline.ps1 calls --
         really writes that volume into the execution panel the 12
         runners read;
      4. the scripts hold no literal volume any more;
      5. all 12 runners honor the observation-spacing FLOOR without ever
         tightening their own provider-specific pacing;
      6. the scheduled Measure task really runs that pipeline, with no
         volume override on its command line.

    The panel file is snapshotted and restored byte-for-byte, and any
    backup build_daily_panel.ps1 creates while the test runs is removed,
    so this test is safe to run at any time -- including on a day whose
    measurement has already happened.

    Usage:
      .\tests\test_protocol_volume.ps1
#>

[CmdletBinding()]
param(
    # A day already measured under the previous volume.
    [string]$LegacyDate = "2026-10-08",
    # The first day under the reduced volume.
    [string]$ReducedDate = "2026-10-09"
)

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

$RunnerRoot = Split-Path $PSScriptRoot -Parent

. (Join-Path $RunnerRoot "lib\Get-ProtocolVolume.ps1")

$script:Passed = 0
$script:Failed = 0

function Assert-True {
    param([bool]$Condition, [string]$Message, [string]$Detail = "")
    if ($Condition) {
        $script:Passed++
        Write-Host "  [OK]   $Message" -ForegroundColor Green
    }
    else {
        $script:Failed++
        Write-Host "  [FAIL] $Message" -ForegroundColor Red
        if ($Detail) { Write-Host "         $Detail" -ForegroundColor Red }
    }
}

function Assert-Equal {
    param($Expected, $Actual, [string]$Message)
    Assert-True ($Expected -eq $Actual) $Message "expected '$Expected', got '$Actual'"
}


Write-Host ""
Write-Host "=== Test 1: the volume is resolved from the single effective-dated config ===" -ForegroundColor Cyan

$configPath = Join-Path $RunnerRoot "config\protocol_volume.json"
Assert-True (Test-Path -LiteralPath $configPath) "config\protocol_volume.json exists (single source of truth)"

$legacy  = Resolve-ProtocolVolume -Date $LegacyDate  -RunnerRoot $RunnerRoot
$reduced = Resolve-ProtocolVolume -Date $ReducedDate -RunnerRoot $RunnerRoot

Assert-Equal 23 $legacy.daily_repetitions         "$LegacyDate keeps 23 daily repetitions"
Assert-Equal 7  $legacy.longitudinal_repetitions  "$LegacyDate keeps 7 longitudinal repetitions"
Assert-Equal 30 $legacy.total_repetitions         "$LegacyDate keeps 30 observations / system"
Assert-Equal 3  $reduced.daily_repetitions        "$ReducedDate uses 3 daily repetitions"
Assert-Equal 7  $reduced.longitudinal_repetitions "$ReducedDate uses 7 longitudinal repetitions"
Assert-Equal 10 $reduced.total_repetitions        "$ReducedDate uses 10 observations / system"

$later = Resolve-ProtocolVolume -Date "2026-12-31" -RunnerRoot $RunnerRoot
Assert-Equal 3 $later.daily_repetitions "a later date still resolves to the reduced volume (not a one-off)"

Assert-True ($reduced.inter_observation_spacing_ms -gt 0) "the reduced profile declares a spacing between observations"


Write-Host ""
Write-Host "=== Test 2: no literal volume left in the scripts ===" -ForegroundColor Cyan

foreach ($rel in @("build_daily_panel.ps1", "aggregate_and_publish_weather.ps1", "launch_ai_weather.ps1")) {
    $path = Join-Path $RunnerRoot $rel
    $code = @(
        Get-Content -LiteralPath $path |
        Where-Object { $_ -notmatch '^\s*#' }
    ) -join "`n"

    Assert-True `
        ($code -notmatch '(?m)^\s*\$\w*(DAILY|Daily)\w*\s*=\s*23\s*$') `
        "$rel has no hardcoded 23"

    Assert-True `
        ($code -match 'Resolve-ProtocolVolume') `
        "$rel reads the volume through the shared resolver"
}

$builderCode = (Get-Content -LiteralPath (Join-Path $RunnerRoot "build_daily_panel.ps1")) -join "`n"
Assert-True `
    ($builderCode -notmatch '\-ne\s+30\b') `
    "build_daily_panel.ps1 no longer guards against a hardcoded total of 30"
Assert-True `
    ($builderCode -match '\$ExpectedTotalRepetitions') `
    "build_daily_panel.ps1 guards the total against the configured value instead"


Write-Host ""
Write-Host "=== Test 3: build_daily_panel.ps1 writes the configured volume into the execution panel ===" -ForegroundColor Cyan

$panelDir  = Join-Path $RunnerRoot "data\panels"
$panelFile = Join-Path $panelDir "ai_weather_panel.csv"
$builder   = Join-Path $RunnerRoot "build_daily_panel.ps1"

$snapshotBytes = $null
if (Test-Path -LiteralPath $panelFile) {
    $snapshotBytes = [System.IO.File]::ReadAllBytes($panelFile)
}

$backupsBefore = @(
    Get-ChildItem -LiteralPath $panelDir -Filter "ai_weather_panel_backup_*.csv" -File |
    ForEach-Object { $_.Name }
)

try {
    # Exactly how run_full_pipeline.ps1 calls it: -Date only, no volume argument.
    & $builder -Date $ReducedDate | Out-Null

    $rows = @(Import-Csv -LiteralPath $panelFile -Encoding UTF8)

    Assert-Equal 2 $rows.Count "the panel still declares exactly 2 prompts (daily + longitudinal)"
    Assert-Equal "daily-$ReducedDate" ([string]$rows[0].prompt_id) "the daily prompt id follows the date"
    Assert-Equal 3 ([int]$rows[0].repetitions) "the panel row the runners read declares 3 daily repetitions"
    Assert-Equal 7 ([int]$rows[1].repetitions) "the panel row the runners read declares 7 longitudinal repetitions"
    Assert-True `
        (-not [string]::IsNullOrWhiteSpace([string]$rows[0].question)) `
        "the daily question is still present (prompts preserved)"
    Assert-True `
        (-not [string]::IsNullOrWhiteSpace([string]$rows[1].question)) `
        "the longitudinal question is still present (prompts preserved)"

    # An already measured day must never be re-sized.
    & $builder -Date $LegacyDate | Out-Null
    $legacyRows = @(Import-Csv -LiteralPath $panelFile -Encoding UTF8)
    Assert-Equal 23 ([int]$legacyRows[0].repetitions) "rebuilding $LegacyDate still yields 23 (history not rewritten)"
}
finally {
    # Restore production state byte-for-byte, whatever happened above.
    if ($null -ne $snapshotBytes) {
        [System.IO.File]::WriteAllBytes($panelFile, $snapshotBytes)
    }

    Get-ChildItem -LiteralPath $panelDir -Filter "ai_weather_panel_backup_*.csv" -File |
    Where-Object { $backupsBefore -notcontains $_.Name } |
    Remove-Item -Force

    $restored =
        if ($null -ne $snapshotBytes -and (Test-Path -LiteralPath $panelFile)) {
            $now = [System.IO.File]::ReadAllBytes($panelFile)
            (
                $now.Length -eq $snapshotBytes.Length -and
                $null -eq (Compare-Object $now $snapshotBytes)
            )
        }
        else {
            $false
        }

    Assert-True $restored "the production panel was restored byte-for-byte by this test"

    $backupsAfter = @(
        Get-ChildItem -LiteralPath $panelDir -Filter "ai_weather_panel_backup_*.csv" -File |
        ForEach-Object { $_.Name }
    )
    Assert-True `
        ($backupsAfter.Count -eq $backupsBefore.Count) `
        "this test left no extra panel backup behind"
}


Write-Host ""
Write-Host "=== Test 4: all 12 runners honor the spacing floor without tightening provider pacing ===" -ForegroundColor Cyan

$runners = @(Get-ChildItem -LiteralPath $RunnerRoot -Filter "run_weather_*.ps1" -File | Sort-Object Name)
Assert-Equal 12 $runners.Count "12 provider runners found"

$savedSpacing = $env:NEOMUNDI_OBSERVATION_SPACING_MS

foreach ($runner in $runners) {
    $lines = @(Get-Content -LiteralPath $runner.FullName)

    $assignment = @(
        $lines | Select-String -Pattern '^\$DELAY_MS\s*=\s*(\d+)\s*$'
    ) | Select-Object -First 1

    if (-not $assignment) {
        Assert-True $false "$($runner.Name): a single '`$DELAY_MS = <n>' line exists"
        continue
    }

    $baseDelay = [int]$assignment.Matches[0].Groups[1].Value
    $start = $assignment.LineNumber

    $window = $lines[($start - 1)..([Math]::Min($start + 25, $lines.Count - 1))]

    $closing = @(
        $window | Select-String -Pattern '^\}$'
    ) | Select-Object -First 1

    if (-not $closing) {
        Assert-True $false "$($runner.Name): the spacing-floor block is present after `$DELAY_MS"
        continue
    }

    $block = ($window[0..($closing.LineNumber - 1)]) -join "`n"
    $probe = [scriptblock]::Create($block + "`n`$DELAY_MS")

    $cases = @(
        @{ Value = $null;            Expected = $baseDelay; Label = "unset -> provider pacing untouched" }
        @{ Value = "0";              Expected = $baseDelay; Label = "0 -> provider pacing untouched" }
        @{ Value = "600000";         Expected = 600000;     Label = "600000 -> spacing applied" }
        @{ Value = "1";              Expected = $baseDelay; Label = "below provider pacing -> never tightened" }
        @{ Value = "not-a-number";   Expected = $baseDelay; Label = "garbage -> ignored, provider pacing kept" }
    )

    $allOk = $true
    $detail = @()

    foreach ($case in $cases) {
        if ($null -eq $case.Value) {
            Remove-Item Env:\NEOMUNDI_OBSERVATION_SPACING_MS -ErrorAction SilentlyContinue
        }
        else {
            $env:NEOMUNDI_OBSERVATION_SPACING_MS = $case.Value
        }

        $got = & $probe 3>$null

        if ($got -ne $case.Expected) {
            $allOk = $false
            $detail += "$($case.Label): got $got, expected $($case.Expected)"
        }
    }

    Remove-Item Env:\NEOMUNDI_OBSERVATION_SPACING_MS -ErrorAction SilentlyContinue

    Assert-True $allOk "$($runner.Name) (pacing $baseDelay ms): spacing floor correct in all 5 cases" ($detail -join "; ")
}

if (-not [string]::IsNullOrWhiteSpace($savedSpacing)) {
    $env:NEOMUNDI_OBSERVATION_SPACING_MS = $savedSpacing
}


Write-Host ""
Write-Host "=== Test 5: the pipeline passes no volume override, and the Measure task runs that pipeline ===" -ForegroundColor Cyan

$pipelinePath = Join-Path $RunnerRoot "run_full_pipeline.ps1"
$pipelineCode = (Get-Content -LiteralPath $pipelinePath) -join "`n"

Assert-True `
    ($pipelineCode -match '&\s*\$BuildPanel\s+-Date\s+\$Date') `
    "run_full_pipeline.ps1 calls build_daily_panel.ps1 with -Date only (no volume override)"

Assert-True `
    ($pipelineCode -notmatch 'DailyRepetitions|LongitudinalRepetitions') `
    "run_full_pipeline.ps1 never overrides the configured volume"

$task = Get-ScheduledTask -TaskName "NeoMundi AI Weather - Measure" -ErrorAction SilentlyContinue

if ($null -eq $task) {
    Write-Host "  [SKIP] 'NeoMundi AI Weather - Measure' is not registered on this machine" -ForegroundColor Yellow
}
else {
    $taskArgs = ($task.Actions | ForEach-Object { $_.Arguments }) -join " "

    Assert-True `
        ($taskArgs -match 'run_full_pipeline\.ps1') `
        "the Measure task executes run_full_pipeline.ps1"
    Assert-True `
        ($taskArgs -notmatch 'DailyRepetitions|LongitudinalRepetitions|MaxRepetitions') `
        "the Measure task passes no volume override on its command line"
    Assert-True `
        ($task.State -ne "Disabled") `
        "the Measure task is enabled (state: $($task.State))"
}


Write-Host ""
Write-Host "=== Results: $script:Passed passed / $($script:Passed + $script:Failed) ===" -ForegroundColor Cyan

if ($script:Failed -gt 0) {
    Write-Host "$script:Failed test(s) failed." -ForegroundColor Red
    exit 1
}

Write-Host "All protocol-volume tests passed." -ForegroundColor Green
exit 0
