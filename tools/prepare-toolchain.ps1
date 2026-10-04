# Copy the DevEco Studio toolchain into the workspace (tools\local).
#
# Why: the DSH file sandbox refuses to create a junction or symlink whose target
# is outside the workspace. hvigor links the toolchain's @ohos/hvigor packages
# into its project cache, so those packages must live under the workspace for
# the link creation to succeed. This script makes that copy once.
#
# Copies hvigor (with its bundled node_modules), node and ohpm -- about 410 MB.
#
# NOTE: ASCII-only on purpose; see the note in build.ps1.
#
# Usage: powershell -ExecutionPolicy Bypass -File tools\prepare-toolchain.ps1

$ErrorActionPreference = 'Continue'

$Ide    = 'D:\DevEco26\DevEco Studio'
$Source = Join-Path $Ide 'tools'
$Local  = Join-Path $PSScriptRoot 'local'

if (-not (Test-Path $Source)) { throw "DevEco tools directory not found: $Source" }

Write-Host "[toolchain] source: $Source"
Write-Host "[toolchain] target: $Local"
New-Item -ItemType Directory -Path $Local -Force | Out-Null

foreach ($part in @('hvigor', 'node', 'ohpm')) {
  $src = Join-Path $Source $part
  $dst = Join-Path $Local $part
  if (-not (Test-Path $src)) { Write-Host "[toolchain] skip (missing): $part"; continue }
  if (Test-Path $dst) {
    Write-Host "[toolchain] already present, refreshing: $part"
    Remove-Item $dst -Recurse -Force -ErrorAction SilentlyContinue
  }
  Write-Host "[toolchain] copying $part ..."
  Copy-Item $src -Destination $dst -Recurse -Force -ErrorAction SilentlyContinue
}

Write-Host '[toolchain] verifying ...'
$required = @(
  'hvigor\bin\hvigorw.bat',
  'hvigor\hvigor\package.json',
  'hvigor\hvigor-ohos-plugin\package.json',
  'node\node.exe',
  'ohpm\bin\ohpm.bat'
)
$ok = $true
foreach ($r in $required) {
  $p = Join-Path $Local $r
  $exists = Test-Path $p
  if (-not $exists) { $ok = $false }
  Write-Host ("[toolchain]   {0,-45} {1}" -f $r, $exists)
}

if ($ok) { Write-Host '[toolchain] ready.' -ForegroundColor Green }
else { Write-Host '[toolchain] INCOMPLETE.' -ForegroundColor Red; exit 1 }
