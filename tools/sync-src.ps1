# Sync workspace sources into tools\proj (the build copy).
#
# Why a copy: hvigor writes .hvigor/ and build/ intermediates into the project
# directory. Building a copy keeps the workspace clean.
#
# NOTE: This file is intentionally ASCII-only. Windows PowerShell 5.1 reads
# .ps1 files without a BOM as the system ANSI codepage (GBK on this machine),
# which corrupts non-ASCII text and can swallow real code lines.
#
# Usage: powershell -ExecutionPolicy Bypass -File tools\sync-src.ps1

$ErrorActionPreference = 'Stop'

$WorkspaceRoot = Split-Path $PSScriptRoot -Parent
$Target        = Join-Path $PSScriptRoot 'proj'
$Ide           = 'D:\DevEco26\DevEco Studio'
$SdkDir        = Join-Path $Ide 'sdk'

Write-Host "[sync] workspace : $WorkspaceRoot"
Write-Host "[sync] build copy: $Target"

$items = @('AppScope', 'entry', 'hvigor', 'hvigorfile.ts', 'oh-package.json5', 'build-profile.json5')

if (Test-Path $Target) { Remove-Item $Target -Recurse -Force }
New-Item -ItemType Directory -Path $Target -Force | Out-Null

foreach ($item in $items) {
  $src = Join-Path $WorkspaceRoot $item
  if (-not (Test-Path $src)) {
    Write-Host "[sync] skip (missing): $item"
    continue
  }
  Copy-Item $src -Destination $Target -Recurse -Force
  Write-Host "[sync] copied: $item"
}

# Report whether DevEco-generated signing material is present. It lives in
# build-profile.json5 and points at C:\Users\<user>\.ohos\config\*, so builds
# driven from here pick it up automatically and produce a signed HAP.
$profileFile = Join-Path $Target 'build-profile.json5'
$profileText = Get-Content $profileFile -Raw
if ($profileText -match '"certpath"') {
  Write-Host '[sync] signing config found -> build will produce a SIGNED hap'
} else {
  Write-Host '[sync] no signing config -> build will produce an UNSIGNED hap'
}

# Point the build at the installed SDK.
"sdk.dir=$SdkDir" | Set-Content (Join-Path $Target 'local.properties') -Encoding ASCII
Write-Host "[sync] local.properties -> sdk.dir=$SdkDir"

# Install module dependencies with ohpm (using the in-workspace toolchain copy).
$Local   = Join-Path $PSScriptRoot 'local'
$NodeDir = Join-Path $Local 'node'
$OhpmBin = Join-Path $Local 'ohpm\bin\ohpm.bat'

if (-not (Test-Path $OhpmBin)) { throw "Local toolchain missing: $OhpmBin -- run tools\prepare-toolchain.ps1 first." }

$env:NODE_HOME             = $NodeDir
$env:npm_config_registry   = 'https://registry.npmmirror.com'
$env:npm_config_cache      = Join-Path $PSScriptRoot '.npmcache'
$env:npm_config_strict_ssl = 'false'
$env:Path = "$NodeDir;$(Join-Path $Local 'ohpm\bin');$env:Path"

Write-Host '[sync] running ohpm install ...'
Push-Location $Target
& $OhpmBin install --all 2>&1 | Select-Object -Last 5
Pop-Location

Write-Host '[sync] done.'
