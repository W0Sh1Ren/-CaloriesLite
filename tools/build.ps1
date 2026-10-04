# Build the HarmonyOS project (API 26) inside the DSH sandbox.
#
# Sandbox constraints this script works around (all hit while setting up):
#
#   1) hvigor keeps its user-level cache in ~/.hvigor, outside the writable
#      sandbox area -> redirect it with HVIGOR_USER_HOME.
#
#   2) hvigor injects the DevEco toolchain's @ohos/hvigor and
#      @ohos/hvigor-ohos-plugin into its project cache as *junctions*
#      (node symlinkSync with type "junction" on Windows). The file sandbox
#      refuses to create a link whose target is outside the workspace, so
#      linking straight to "D:\DevEco26\..." fails with EPERM. Fix: keep a
#      toolchain copy inside the workspace (tools\local). Run
#      tools\prepare-toolchain.ps1 once to create it.
#
#   3) The sandbox forbids named pipes, so every child process created with
#      piped stdio fails with "spawn EPERM". That breaks hvigor's own
#      child_process.fork handoff and would break the resource compiler too.
#      tools\run-hvigor.js patches the spawn helpers to retry with
#      stdio: 'inherit'; this script runs the build through that shim.
#
#   4) restool.exe loads libimage_transcoder_shared.dll from the SDK, and that
#      DLL needs its sibling SDK directories on PATH. Without them restool dies
#      with "11201001 Failed to load the library ... (126)".
#
#   5) The public npm registry has a broken certificate chain on this machine,
#      so npm goes through a mirror.
#
# NOTE: This file is intentionally ASCII-only. Windows PowerShell 5.1 reads
# .ps1 files without a BOM using the system ANSI codepage (GBK here), which
# corrupts non-ASCII text and can swallow real code lines.
#
# Usage:
#   powershell -ExecutionPolicy Bypass -File tools\build.ps1
#   powershell -ExecutionPolicy Bypass -File tools\build.ps1 -Clean

param(
  [switch]$Clean,
  [string]$Task = 'assembleHap',
  [string]$BuildMode = 'debug'
)

$ErrorActionPreference = 'Continue'

# ---------------------------------------------------------------- paths
$ToolsDir   = $PSScriptRoot
$ProjectDir = Join-Path $ToolsDir 'proj'
$Local      = Join-Path $ToolsDir 'local'
$NodeExe    = Join-Path $Local 'node\node.exe'
$Shim       = Join-Path $ToolsDir 'run-hvigor.js'
$IdeSdk     = 'D:\DevEco26\DevEco Studio\sdk'
$SdkDefault = Join-Path $IdeSdk 'default'
$HvigorHome = Join-Path $ToolsDir '.hvigorhome'
$NpmCache   = Join-Path $ToolsDir '.npmcache'

if (-not (Test-Path $NodeExe)) {
  throw "Local toolchain missing: $NodeExe -- run tools\prepare-toolchain.ps1 first."
}
if (-not (Test-Path $ProjectDir)) {
  throw "Build copy missing: $ProjectDir -- run tools\sync-src.ps1 first."
}
if (-not (Test-Path $SdkDefault)) {
  throw "HarmonyOS SDK not found: $SdkDefault"
}

# ---------------------------------------------------------------- environment
$env:HVIGOR_USER_HOME      = $HvigorHome
$env:NODE_HOME             = Join-Path $Local 'node'
$env:DEVECO_SDK_HOME       = $IdeSdk
$env:npm_config_cache      = $NpmCache
$env:npm_config_registry   = 'https://registry.npmmirror.com'
$env:npm_config_strict_ssl = 'false'

# restool and friends resolve their sibling DLLs through PATH.
$sdkPath = @(
  (Join-Path $SdkDefault 'hms\toolchains\lib'),
  (Join-Path $SdkDefault 'hms\toolchains'),
  (Join-Path $SdkDefault 'openharmony\toolchains'),
  (Join-Path $SdkDefault 'openharmony\previewer\common\bin')
) -join ';'
$env:Path = "$sdkPath;$env:Path"

New-Item -ItemType Directory -Path $HvigorHome -Force | Out-Null
New-Item -ItemType Directory -Path $NpmCache   -Force | Out-Null

if ($Clean) {
  Write-Host '[build] cleaning ...'
  Remove-Item (Join-Path $ProjectDir '.hvigor') -Recurse -Force -ErrorAction SilentlyContinue
  Remove-Item (Join-Path $HvigorHome 'project_caches') -Recurse -Force -ErrorAction SilentlyContinue
  Get-ChildItem $ProjectDir -Recurse -Directory -Filter 'build' -ErrorAction SilentlyContinue |
    Remove-Item -Recurse -Force -ErrorAction SilentlyContinue
}

$logFile = Join-Path $ToolsDir 'build.log'

Write-Host "[build] task=$Task mode=$BuildMode"
Write-Host "[build] project=$ProjectDir"
Write-Host "[build] sdk=$IdeSdk"

$script:exitCode = 0
Push-Location $ProjectDir
try {
  # Capture into the log while still showing the build live.
  & $NodeExe $Shim $Task --mode module -p product=default -p "buildMode=$BuildMode" --no-daemon 2>&1 |
    Tee-Object -FilePath $logFile | ForEach-Object { Write-Host $_ }
  $script:exitCode = $LASTEXITCODE
} finally {
  Pop-Location
}

if ($script:exitCode -eq 0) {
  Write-Host '[build] SUCCESS'
  Get-ChildItem $ProjectDir -Recurse -File -Include '*.hap' -ErrorAction SilentlyContinue |
    ForEach-Object { Write-Host ("[build] artifact: {0} ({1:N0} KB)" -f $_.FullName, ($_.Length / 1KB)) }
  exit 0
}

Write-Host "[build] FAILED (exit $script:exitCode). See $logFile"
exit 1
