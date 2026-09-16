# Exercises ONLY sections 16b/17, never the provider runners or publication entry point.
[CmdletBinding()]
param()
$ErrorActionPreference = 'Stop'
$repo = Split-Path $PSScriptRoot -Parent
$source = Get-Content -LiteralPath (Join-Path $repo 'AI_WEATHER_RUNNER/aggregate_and_publish_weather.ps1') -Raw -Encoding UTF8
$tokens=$null; $parseErrors=$null
[System.Management.Automation.Language.Parser]::ParseInput($source,[ref]$tokens,[ref]$parseErrors) | Out-Null
if($parseErrors.Count){throw 'Aggregator syntax errors'}
$start=$source.IndexOf('# 16b.')
$end=$source.IndexOf('# 18. Console report')
if($start -lt 0 -or $end -le $start){throw 'Integration section not found'}
$integration=[scriptblock]::Create($source.Substring($start,$end-$start))
$fixture=Join-Path ([IO.Path]::GetTempPath()) ('aw-v2-wiring-'+[guid]::NewGuid().ToString('N'))
$fixture=[IO.Path]::GetFullPath($fixture)
$tempRoot=[IO.Path]::GetFullPath([IO.Path]::GetTempPath()).TrimEnd('\')+'\'
if(-not $fixture.StartsWith($tempRoot,[StringComparison]::OrdinalIgnoreCase)){throw 'Unsafe fixture path'}
$script:checks=0
function Check([bool]$ok,[string]$message){if(-not $ok){throw $message};$script:checks++;Write-Host "[PASS] $message"}
function Hashes([string]$dir){$result=@{};Get-ChildItem -LiteralPath $dir -Recurse -File | ForEach-Object {$result[$_.FullName]=(Get-FileHash -LiteralPath $_.FullName).Hash};return $result}
$capsBefore=Hashes (Join-Path $repo 'aiweather-capsule/capsules')
try{
 New-Item -ItemType Directory -Path (Join-Path $fixture 'data/history'),(Join-Path $fixture 'aiweather-capsule/capsules'),(Join-Path $fixture 'AI_WEATHER_RUNNER/config') -Force | Out-Null
 Get-ChildItem -LiteralPath (Join-Path $repo 'data/history') -File | Copy-Item -Destination (Join-Path $fixture 'data/history')
 Get-ChildItem -LiteralPath (Join-Path $repo 'aiweather-capsule/capsules') | Copy-Item -Destination (Join-Path $fixture 'aiweather-capsule/capsules') -Recurse
 foreach($file in @('longitudinal_engine.ps1','longitudinal_v2_bridge.ps1','config/longitudinal_engine_config.json','config/provider_changelog.json')){
  Copy-Item -LiteralPath (Join-Path $repo ('AI_WEATHER_RUNNER/'+$file)) -Destination (Join-Path $fixture ('AI_WEATHER_RUNNER/'+$file))
 }
 $legacy=Get-Content -LiteralPath (Join-Path $repo 'data/history/2026-09-16.json') -Raw -Encoding UTF8 | ConvertFrom-Json
 foreach($key in @('methodology_version','baseline_config_version','repetition_count')){$legacy.PSObject.Properties.Remove($key)}
 foreach($s in $legacy.systems){
  foreach($key in @('usable','repetition_count','current_longitudinal_state','deviation_index','baseline','uncertainty','detected_events','system_identity')){$s.longitudinal.PSObject.Properties.Remove($key)}
 }
 $legacy.generated_at='2026-09-17T06:00:00Z'
 $legacy.systems[0].longitudinal.score=0
 $inputJson=$legacy | ConvertTo-Json -Depth 40
 function Invoke-Fixture([switch]$BadHistoryPath){
  $runnerRoot=Join-Path $fixture 'AI_WEATHER_RUNNER'
  $repoRoot=$fixture
  $historyDir=Join-Path $fixture 'data/history'
  $Date='2026-09-17'
  $historyJsonPath=Join-Path $historyDir ($Date+'.json')
  if($BadHistoryPath){$historyJsonPath=$historyDir}
  $weatherJsonPath=Join-Path $fixture 'weather.json'
  $currentJsonPath=Join-Path $fixture 'data/current.json'
  $output=$inputJson | ConvertFrom-Json
  . $integration
  return $output
 }
 Check (-not (Test-Path -LiteralPath (Join-Path $fixture 'data/history/2026-09-17.json'))) 'New day absent before aggregation'
 $result=Invoke-Fixture
 Check ($result.systems.Count -eq 12) 'All 12 systems preserved'
 Check (@($result.systems | Where-Object {$_.longitudinal.current_longitudinal_state.as_of -ne '2026-09-17'}).Count -eq 0) 'Real engine includes the persisted new day for all 12 systems'
 Check ($result.systems[0].longitudinal.current_longitudinal_state.deviation_index -lt -10) 'New measurement affects calculation, not just its date label'
 Check ($result.systems[0].condition -eq $legacy.systems[0].condition) 'Legacy daily condition preserved'
 $payloads=@('weather.json','data/current.json','data/history/2026-09-17.json') | ForEach-Object {Get-Content -LiteralPath (Join-Path $fixture $_) -Raw -Encoding UTF8}
 Check ($payloads[0] -ceq $payloads[1] -and $payloads[1] -ceq $payloads[2]) 'All three final files contain identical enriched data'
 Check ($payloads[0] -match 'AI_WEATHER_METHOD_V2_0') 'Enrichment precedes current-file publication'
 Move-Item -LiteralPath (Join-Path $fixture 'AI_WEATHER_RUNNER/longitudinal_engine.ps1') -Destination (Join-Path $fixture 'AI_WEATHER_RUNNER/longitudinal_engine.disabled')
 $fallback=Invoke-Fixture
 Check (($fallback | ConvertTo-Json -Depth 40) -ceq $inputJson) 'Missing engine retains exact legacy fallback and removes stale V2 fields'
 $beforeFailure=(Get-FileHash -LiteralPath (Join-Path $fixture 'weather.json')).Hash
 $failed=$false;try{Invoke-Fixture -BadHistoryPath | Out-Null}catch{$failed=$true}
 Check $failed 'History persistence failure stops before publication'
 Check ((Get-FileHash -LiteralPath (Join-Path $fixture 'weather.json')).Hash -eq $beforeFailure) 'Public current file unchanged after persistence failure'
 $capsAfter=Hashes (Join-Path $repo 'aiweather-capsule/capsules')
 Check (@($capsBefore.Keys | Where-Object {$capsBefore[$_] -ne $capsAfter[$_]}).Count -eq 0 -and $capsBefore.Count -eq $capsAfter.Count) 'All historical capsule bytes preserved'
 Write-Host "PASS: $script:checks wiring assertions; aggregator syntax valid."
}finally{
 if($fixture.StartsWith($tempRoot,[StringComparison]::OrdinalIgnoreCase) -and (Test-Path -LiteralPath $fixture)){Remove-Item -LiteralPath $fixture -Recurse -Force}
}
