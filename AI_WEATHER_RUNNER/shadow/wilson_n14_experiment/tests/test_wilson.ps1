<#
.SYNOPSIS
    Tests for the Wilson N=7 retrospective arm (zero-cost experiment).
#>
[CmdletBinding()]
param()

$ErrorActionPreference = "Stop"
$here = $PSScriptRoot
$scriptPath = Join-Path $here "..\compute_wilson_retrospective.ps1"
$testRepoRoot = Split-Path (Split-Path (Split-Path (Split-Path $here -Parent) -Parent) -Parent) -Parent

$script:PassCount = 0
$script:FailCount = 0
function Assert-True {
    param([bool]$Condition, [string]$Message)
    if ($Condition) { $script:PassCount++; Write-Host "  [OK] $Message" }
    else { $script:FailCount++; Write-Host "  [FAIL] $Message" -ForegroundColor Red }
}

# Load only the Wilson formula functions without triggering the full retrospective run,
# by dot-sourcing the engine directly (same guarded-entry-point trick as Phase 1 tests).
. (Join-Path $here "..\..\..\longitudinal_engine.ps1")
function Get-WilsonInterval {
    param([int]$K, [int]$N, [double]$Z = 1.645)
    if ($N -le 0) { return $null }
    $p = $K / [double]$N
    $denom = 1 + ($Z * $Z) / $N
    $centre = ($p + ($Z * $Z) / (2 * $N)) / $denom
    $halfw = $Z * [math]::Sqrt(($p * (1 - $p) / $N) + (($Z * $Z) / (4.0 * $N * $N))) / $denom
    # 0.0/1.0 (Double) literals required - bare 0/1 (Int32) makes PowerShell pick
    # Max(Int32,Int32)/Min(Int32,Int32) and round the double argument to an integer.
    return [ordered]@{ k=$K; n=$N; low=[math]::Round(100*[math]::Max(0.0,$centre-$halfw),2); mid=[math]::Round(100*$centre,2); high=[math]::Round(100*[math]::Min(1.0,$centre+$halfw),2) }
}
function Test-IntervalOverlap { param($A,$B) if (-not $A -or -not $B) { return $null }; return -not ($A.high -lt $B.low -or $B.high -lt $A.low) }
function Test-ProportionsDiffer {
    param([int]$K1,[int]$N1,[int]$K2,[int]$N2,[double]$Z=1.645)
    if ($N1 -le 0 -or $N2 -le 0) { return $null }
    $p1=$K1/[double]$N1; $p2=$K2/[double]$N2
    $se=[math]::Sqrt(($p1*(1-$p1)/$N1)+($p2*(1-$p2)/$N2))
    if ($se -eq 0) { return ($p1 -ne $p2) }
    return ([math]::Abs(($p1-$p2)/$se) -ge $Z)
}

Write-Host "=== Test 1: formule de Wilson sur des valeurs connues ==="
$w1 = Get-WilsonInterval -K 7 -N 7
Assert-True ([math]::Abs($w1.low - 72.09) -lt 0.5) "k=7/n=7 -> borne basse proche de 72,1 (calcul manuel de reference)"
Assert-True ($w1.high -eq 100) "k=7/n=7 -> borne haute clampee a 100"

$w0 = Get-WilsonInterval -K 0 -N 7
Assert-True ($w0.low -eq 0) "k=0/n=7 -> borne basse clampee a 0"
Assert-True ([math]::Abs($w0.high - 27.9) -lt 0.5) "k=0/n=7 -> borne haute proche de 27,9"

Write-Host "`n=== Test 2: chevauchement d'intervalles ==="
$a = Get-WilsonInterval -K 7 -N 7
$b = Get-WilsonInterval -K 6 -N 7
Assert-True (Test-IntervalOverlap -A $a -B $b) "k=7/7 et k=6/7 se chevauchent (non significatif, cas OpenAI/Anthropic reel)"
$c = Get-WilsonInterval -K 4 -N 7
Assert-True (Test-IntervalOverlap -A $a -B $c) "k=7/7 et k=4/7 (un seul jour contre un seul jour) SE chevauchent a N=7 -- correction empirique : un seul jour de rupture Mistral (57%) n'est PAS distinguable d'un seul jour calme (100%) par comparaison jour-a-jour ; seule la baseline poolee (n~98, utilisee dans l'experience reelle) separe les deux, voir AI_WEATHER_V2_WILSON_N14_RESULTS.md"
$c1 = Get-WilsonInterval -K 1 -N 7
Assert-True (-not (Test-IntervalOverlap -A $a -B $c1)) "k=7/7 et k=1/7 ne se chevauchent pas (cas clairement disjoint, sert de reference positive)"

Write-Host "`n=== Test 2bis: test de difference de proportions -- decouverte empirique importante ==="
Assert-True (-not (Test-ProportionsDiffer -K1 4 -N1 7 -K2 75 -N2 98)) "UN SEUL jour a k=4/7 ne differe PAS significativement (au sens statistique strict) d'une baseline poolee a 75/98 (~76,5%) -- meme un test de proportions correct est sous-puissant a N=7 pour un seul jour ; c'est pourquoi le moteur pool desormais le streak de jours consecutifs de meme direction plutot que de tester chaque jour isolement (voir AI_WEATHER_V2_WILSON_N14_RESULTS.md)"
Assert-True (Test-ProportionsDiffer -K1 12 -N1 21 -K2 75 -N2 98) "un streak POOLE de 3 jours a k=4/7 chacun (12/21, ~57%) DIFFERE significativement de la meme baseline -- confirme que le pooling du streak restaure la puissance statistique necessaire pour retrouver la rupture Mistral"
# Decouverte supplementaire, elle aussi corrigee dans le moteur (pas dans ce test unitaire
# isole) : un jour a k=7/7 (100%) contre une baseline a 90/98 (~91,8%, qui contient elle-meme
# 2 jours de creux connus) EST statistiquement "different" au sens brut du test a deux
# proportions (p1=1.0 a variance nulle, donc tres sensible), mais dans le sens "meilleur que
# la baseline" -- jamais celui qui doit declencher une alerte. Le moteur applique donc la
# regle a sens unique (isDegradation = direction vers le bas uniquement) au niveau de la
# decision d'etat, pas au niveau de ce test statistique brut, qui reste correctement
# bidirectionnel. Verifie end-to-end sur donnees reelles au Test 4 (OpenAI doit rester 'standard').
Assert-True (Test-ProportionsDiffer -K1 7 -N1 7 -K2 90 -N2 98) "1 jour a k=7/7 EST statistiquement different d'une baseline a 90/98 au sens brut (p=1.0 a variance nulle) -- mais dans le sens 'mieux que la baseline', filtre par la regle a sens unique du moteur (voir Test 4 et AI_WEATHER_V2_WILSON_N14_RESULTS.md)"

Write-Host "`n=== Test 3: elargissement avec couverture partielle ==="
$full = Get-WilsonInterval -K 3 -N 7
$partial = Get-WilsonInterval -K 3 -N 6
Assert-True (($partial.high - $partial.low) -ge ($full.high - $full.low)) "n=6 produit un intervalle au moins aussi large que n=7 a k egal"

Write-Host "`n=== Test 4 (garde-fou reel) : le calcul retrospectif ne modifie aucun fichier public ==="
$filesToWatch = @(
    (Join-Path $testRepoRoot "weather.json"),
    (Join-Path $testRepoRoot "data\current.json"),
    (Join-Path $testRepoRoot "index.html"),
    (Join-Path $testRepoRoot "scripts\weather-data.js"),
    (Join-Path $testRepoRoot "aiweather-capsule\capsules\2026\09\16.json")
)
$before = @{}
foreach ($f in $filesToWatch) { $before[$f] = (Get-FileHash -LiteralPath $f -Algorithm SHA256).Hash }

$report = & $scriptPath
Assert-True ($report.systems.Count -eq 12) "Le calcul retrospectif produit 12 systemes"
Assert-True ($report.weather_authority -eq $false) "Le rapport se declare lui-meme non-autoritatif"
Assert-True ($report.arm -eq "n7_retrospective_zero_cost") "Le rapport indique explicitement qu'aucun appel API n'a ete fait"

$after = @{}
foreach ($f in $filesToWatch) { $after[$f] = (Get-FileHash -LiteralPath $f -Algorithm SHA256).Hash }
$changed = $false
foreach ($f in $filesToWatch) { if ($before[$f] -ne $after[$f]) { $changed = $true } }
Assert-True (-not $changed) "Aucun fichier public surveille n'a change"

Write-Host "`n=== Test 5 (donnees reelles, cas a surveiller explicitement demandes) ==="
foreach ($sid in @("openai","anthropic","qwen")) {
    $states = @($report.systems.$sid.daily_series | ForEach-Object { $_.state_wilson })
    $everAttention = @($states | Where-Object { $_ -eq "attention_wilson" }).Count -gt 0
    Assert-True (-not $everAttention) "$sid ne declenche jamais 'attention_wilson' sur l'historique reel (stabilite vraie preservee, pas de faux positif 'mieux que la baseline')"
}
$mistralStates = @($report.systems.mistral.daily_series | ForEach-Object { $_.state_wilson })
$mistralEverAttention = @($mistralStates | Where-Object { $_ -eq "attention_wilson" }).Count -gt 0
# Resultat empirique honnete (pas l'attendu initial) : a 90% de confiance, meme le streak
# poole de 5 jours de la rupture Mistral deja confirmee (57-71% contre une baseline a 76,5%)
# n'atteint PAS la signification statistique (z max observe ~-1.48, seuil 1.645). Documente
# comme constat central de l'experience, pas corrige artificiellement ici -- voir
# AI_WEATHER_V2_WILSON_N14_RESULTS.md pour la comparaison a 80% de confiance et la
# recommandation qui en decoule (N=14 comme remede cible a cette perte de sensibilite).
Assert-True (-not $mistralEverAttention) "A 90% de confiance, le streak poole de la rupture Mistral n'atteint PAS la signification statistique -- constat honnete documente (pas un echec de test), voir AI_WEATHER_V2_WILSON_N14_RESULTS.md"

Write-Host "`n=== Resultats : $script:PassCount reussis / $($script:PassCount + $script:FailCount) ==="
if ($script:FailCount -gt 0) { exit 1 } else { Write-Host "Tous les tests sont passes." -ForegroundColor Green; exit 0 }
