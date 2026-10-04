# 用 SDK 自带的签名工具离线生成调试签名并安装到真机。
#
# 原理：DevEco Studio 的 SDK 里自带了一整套调试签名材料——
#   OpenHarmony.p12                  含 OpenHarmony 根 CA 与应用 CA 的私钥（口令 123456）
#   OpenHarmonyProfileDebug.pem      调试 Profile 的签名证书
#   UnsgnedDebugProfileTemplate.json 未签名的调试 Profile 模板
# 所以可以完全离线地：生成应用密钥 → 签发应用证书 → 定制并签名 Profile → 签名 HAP。
#
# NOTE: ASCII-only on purpose; Windows PowerShell 5.1 reads .ps1 files without a
# BOM using the system ANSI codepage, which corrupts non-ASCII text.
#
# Usage:
#   powershell -ExecutionPolicy Bypass -File tools\sign-and-install.ps1
#   powershell -ExecutionPolicy Bypass -File tools\sign-and-install.ps1 -Install:$false

param(
  [switch]$Install = $true,
  [string]$BundleName = '',
  [string]$UnsignedHap = ''
)

$ErrorActionPreference = 'Stop'

# ---------------------------------------------------------------- paths
$ToolsDir = $PSScriptRoot
$Workspace = Split-Path $ToolsDir -Parent
$SdkLib   = 'D:\DevEco26\DevEco Studio\sdk\default\openharmony\toolchains\lib'
$Java     = 'D:\DevEco26\DevEco Studio\jbr\bin\java.exe'
$Hdc      = 'D:\DevEco26\DevEco Studio\sdk\default\openharmony\toolchains\hdc.exe'
$SignTool = Join-Path $SdkLib 'hap-sign-tool.jar'
$Keystore = Join-Path $SdkLib 'OpenHarmony.p12'
$OutDir   = Join-Path $ToolsDir 'signing'

if (-not (Test-Path $SignTool)) { throw "hap-sign-tool.jar not found: $SignTool" }
if (-not (Test-Path $Java))     { throw "java not found: $Java" }
if (-not (Test-Path $Keystore)) { throw "OpenHarmony.p12 not found: $Keystore" }

# DevEco Studio rewrites the bundle name when it generates signing material, so
# always take the authoritative value from AppScope/app.json5 instead of assuming.
if ([string]::IsNullOrWhiteSpace($BundleName)) {
  $appJson = Join-Path $Workspace 'AppScope\app.json5'
  if (-not (Test-Path $appJson)) { throw "app.json5 not found: $appJson" }
  $bm = [regex]::Match((Get-Content $appJson -Raw), '"bundleName"\s*:\s*"([^"]+)"')
  if (-not $bm.Success) { throw "Could not read bundleName from $appJson" }
  $BundleName = $bm.Groups[1].Value
}

if ([string]::IsNullOrWhiteSpace($UnsignedHap)) {
  $UnsignedHap = Join-Path $ToolsDir 'proj\entry\build\default\outputs\default\entry-default-unsigned.hap'
}
if (-not (Test-Path $UnsignedHap)) {
  throw "Unsigned HAP not found: $UnsignedHap -- run tools\build.ps1 first."
}

New-Item -ItemType Directory -Path $OutDir -Force | Out-Null

# ---------------------------------------------------------------- device UDID
Write-Host '[sign] reading device UDID ...'
$udidRaw = & $Hdc shell bm get -u 2>&1 | Out-String
$m = [regex]::Match($udidRaw, '([0-9A-Fa-f]{64})')
if (-not $m.Success) {
  throw "Could not read device UDID. Is the device connected with USB debugging on? Output: $udidRaw"
}
$udid = $m.Groups[1].Value.ToUpper()
Write-Host "[sign] udid   = $udid"
Write-Host "[sign] bundle = $BundleName"

# ---------------------------------------------------------------- constants
# Keystore aliases shipped inside OpenHarmony.p12
$KsPwd      = '123456'
$CaAlias    = 'openharmony application ca'
$ProfileAlias = 'openharmony application profile debug'
$ProfileCert = Join-Path $SdkLib 'OpenHarmonyProfileDebug.pem'
$Template   = Join-Path $SdkLib 'UnsgnedDebugProfileTemplate.json'

# Our own app signing key
$AppAlias   = 'calorielite-key'
$AppPwd     = 'calorielite123'
$AppKs      = Join-Path $OutDir 'calorielite.p12'
$AppCert    = Join-Path $OutDir 'calorielite-app.cer'
$RootCaCert = Join-Path $OutDir 'root-ca.cer'
$SubCaCert  = Join-Path $OutDir 'sub-app-ca.cer'
$ProfileJson   = Join-Path $OutDir 'profile.json'
$SignedProfile = Join-Path $OutDir 'calorielite.p7b'
$SignedHap     = Join-Path $OutDir 'entry-default-signed.hap'

$ProfileCertContent = (Get-Content $ProfileCert -Raw).Trim()

function Invoke-SignTool {
  param([string[]]$SignArgs, [string]$Step)
  Write-Host "[sign] $Step"
  $out = & $Java -jar $SignTool @SignArgs 2>&1 | Out-String
  if ($LASTEXITCODE -ne 0 -or $out -match '(?m)^\s*ERROR') {
    Write-Host $out
    throw "hap-sign-tool failed at step: $Step"
  }
  return $out
}

# ---------------------------------------------------------------- 1. app key + cert
# Root CA and sub CA certificates must exist before generate-app-cert can build a
# certificate chain, so export them from the bundled keystore first.
if (-not (Test-Path $RootCaCert)) {
  Invoke-SignTool -Step 'exporting root CA certificate' -SignArgs @(
    'generate-ca',
    '-keyAlias', 'openharmony application root ca',
    '-keyPwd', $KsPwd,
    '-issuerKeyAlias', 'openharmony application root ca',
    '-issuerKeyPwd', $KsPwd,
    '-subject', 'C=CN,O=OpenHarmony,OU=OpenHarmony Team,CN=OpenHarmony Application Root CA',
    '-signAlg', 'SHA384withECDSA',
    '-keystoreFile', $Keystore,
    '-keystorePwd', $KsPwd,
    '-outFile', $RootCaCert
  ) | Out-Null
}

if (-not (Test-Path $AppKs)) {
  Invoke-SignTool -Step 'generating app keypair' -SignArgs @(
    'generate-keypair',
    '-keyAlias', $AppAlias,
    '-keyPwd', $AppPwd,
    '-keyAlg', 'ECC',
    '-keySize', 'NIST-P-256',
    '-keystoreFile', $AppKs,
    '-keystorePwd', $AppPwd
  ) | Out-Null
}

if (-not (Test-Path $AppCert)) {
  Invoke-SignTool -Step 'issuing app certificate' -SignArgs @(
    'generate-app-cert',
    '-keyAlias', $AppAlias,
    '-keyPwd', $AppPwd,
    '-issuer', 'C=CN,O=OpenHarmony,OU=OpenHarmony Team,CN=OpenHarmony Application CA',
    '-issuerKeyAlias', $CaAlias,
    '-issuerKeyPwd', $KsPwd,
    '-subject', 'C=CN,O=OpenHarmony,OU=OpenHarmony Team,CN=CalorieLite Debug',
    '-validity', '3650',
    '-signAlg', 'SHA256withECDSA',
    '-keystoreFile', $AppKs,
    '-keystorePwd', $AppPwd,
    '-issuerKeystoreFile', $Keystore,
    '-issuerKeystorePwd', $KsPwd,
    '-outForm', 'certChain',
    '-rootCaCertFile', $RootCaCert,
    '-subCaCertFile', $SubCaCert,
    '-outFile', $AppCert
  ) | Out-Null
}

if (-not (Test-Path $AppCert)) { throw "App certificate was not produced: $AppCert" }
Write-Host "[sign] app certificate -> $AppCert"

# ---------------------------------------------------------------- 2. profile
Write-Host '[sign] composing debug profile'
$appCertContent = (Get-Content $AppCert -Raw).Trim()
# The profile embeds the signing certificate with escaped newlines.
$appCertEscaped = $appCertContent -replace "`r`n", '\n' -replace "`n", '\n'

$now = [int][double]::Parse((Get-Date -UFormat %s))
$profile = [ordered]@{
  'version-name'   = '2.0.0'
  'version-code'   = 2
  'uuid'           = [guid]::NewGuid().ToString()
  'validity'       = [ordered]@{
    'not-before' = $now - 3600
    'not-after'  = $now + (3650 * 24 * 3600)
  }
  'type'           = 'debug'
  'bundle-info'    = [ordered]@{
    'developer-id'            = 'OpenHarmony'
    'development-certificate' = $appCertEscaped
    'bundle-name'             = $BundleName
    'apl'                     = 'normal'
    'app-feature'             = 'hos_normal_app'
  }
  'acls'           = [ordered]@{ 'allowed-acls' = @('') }
  'permissions'    = [ordered]@{ 'restricted-permissions' = @() }
  'debug-info'     = [ordered]@{
    'device-ids'     = @($udid)
    'device-id-type' = 'udid'
  }
  'issuer'         = 'pki_internal'
}
$profile | ConvertTo-Json -Depth 10 | Set-Content -Path $ProfileJson -Encoding UTF8
Write-Host "[sign] profile json -> $ProfileJson"

Invoke-SignTool -Step 'signing profile' -SignArgs @(
  'sign-profile',
  '-keyAlias', $ProfileAlias,
  '-keyPwd', $KsPwd,
  '-signAlg', 'SHA256withECDSA',
  '-mode', 'localSign',
  '-profileCertFile', $ProfileCert,
  '-inFile', $ProfileJson,
  '-keystoreFile', $Keystore,
  '-keystorePwd', $KsPwd,
  '-outFile', $SignedProfile
) | Out-Null

if (-not (Test-Path $SignedProfile)) { throw "Signed profile was not produced: $SignedProfile" }
Write-Host "[sign] signed profile -> $SignedProfile"

# ---------------------------------------------------------------- 3. sign hap
Invoke-SignTool -Step 'signing HAP' -SignArgs @(
  'sign-app',
  '-keyAlias', $AppAlias,
  '-keyPwd', $AppPwd,
  '-appCertFile', $AppCert,
  '-profileFile', $SignedProfile,
  '-inForm', 'zip',
  '-signAlg', 'SHA256withECDSA',
  '-mode', 'localSign',
  '-keystoreFile', $AppKs,
  '-keystorePwd', $AppPwd,
  '-inFile', $UnsignedHap,
  '-outFile', $SignedHap
) | Out-Null

if (-not (Test-Path $SignedHap)) { throw "Signed HAP was not produced: $SignedHap" }
Write-Host "[sign] signed HAP -> $SignedHap" -ForegroundColor Green

# ---------------------------------------------------------------- 4. install
if ($Install) {
  Write-Host '[sign] installing to device ...'
  $installOut = & $Hdc install -r $SignedHap 2>&1 | Out-String
  Write-Host $installOut
  if ($installOut -match 'failed|error') {
    Write-Host '[sign] INSTALL FAILED' -ForegroundColor Red
    exit 1
  }
  Write-Host "[sign] launching $BundleName ..."
  & $Hdc shell aa start -a EntryAbility -b $BundleName 2>&1 | Out-String | Write-Host
  Write-Host '[sign] done.' -ForegroundColor Green
}
