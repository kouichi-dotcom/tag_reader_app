# TSS SDK 配置スクリプト（リポジトリにはバイナリをコミットしない運用）
# 参照元: 共有フォルダ内の SDK_for_Android6.2.1
#
# PowerShell 5.x はスクリプトをシステム既定エンコーディングで読むことがあるため、
# 日本語パスは Unicode コードポイントから組み立てる（UTF-8 文字化け対策）。

param(
  [string]$SourceRoot = ""
)

$ErrorActionPreference = "Stop"

$repoRoot = Split-Path -Parent $PSScriptRoot

if ([string]::IsNullOrWhiteSpace($SourceRoot)) {
  # "個人用ファイル\宮城宏一"
  $personal = -join ([char]0x500B, [char]0x4EBA, [char]0x7528, [char]0x30D5, [char]0x30A1, [char]0x30A4, [char]0x30EB)
  $name = -join ([char]0x5BAE, [char]0x57CE, [char]0x5B8F, [char]0x4E00)
  $SourceRoot = Join-Path "\\OOMIYASV1\ohmiya" "$personal\$name\TagReader\AndroidSDK\SDK_for_Android6.2.1\Library"
}

$srcAar  = Join-Path $SourceRoot "TSS_SDK.aar"
$srcJni  = Join-Path $SourceRoot "jniLibs"

$dstAarDir = Join-Path $repoRoot "android\app\libs"
$dstAar    = Join-Path $dstAarDir "TSS_SDK.aar"
$dstJniDir = Join-Path $repoRoot "android\app\src\main\jniLibs"

Write-Host "Source AAR : $srcAar"
Write-Host "Source JNI : $srcJni"
Write-Host "Dest   AAR : $dstAar"
Write-Host "Dest   JNI : $dstJniDir"

if (!(Test-Path -LiteralPath $srcAar)) {
  throw "AAR not found: $srcAar`nUse -SourceRoot to point at the Library folder (contains TSS_SDK.aar)."
}
if (!(Test-Path -LiteralPath $srcJni)) {
  throw "jniLibs not found: $srcJni"
}

New-Item -ItemType Directory -Force -Path $dstAarDir | Out-Null
New-Item -ItemType Directory -Force -Path $dstJniDir | Out-Null

Copy-Item -Force -LiteralPath $srcAar -Destination $dstAar

# jniLibs 配下（arm64-v8a等）を丸ごとコピー
Get-ChildItem -Path $srcJni -Directory | ForEach-Object {
  $arch = $_.Name
  $dstArchDir = Join-Path $dstJniDir $arch
  New-Item -ItemType Directory -Force -Path $dstArchDir | Out-Null
  Copy-Item -Force -Path (Join-Path $_.FullName "*.so") -Destination $dstArchDir -ErrorAction SilentlyContinue
}

Write-Host "Done. (AAR + *.so copied)"
