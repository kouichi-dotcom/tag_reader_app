$ErrorActionPreference = "Stop"

# TSS SDK 配置スクリプト（リポジトリにはバイナリをコミットしない運用）
# 参照元: 共有フォルダ内の SDK_for_Android6.2.1

$repoRoot = Split-Path -Parent $PSScriptRoot

$srcRoot = "\\OOMIYASV1\ohmiya\個人用ファイル\宮城宏一\TagReader\AndroidSDK\SDK_for_Android6.2.1\Library"
$srcAar  = Join-Path $srcRoot "TSS_SDK.aar"
$srcJni  = Join-Path $srcRoot "jniLibs"

$dstAarDir = Join-Path $repoRoot "android\app\libs"
$dstAar    = Join-Path $dstAarDir "TSS_SDK.aar"
$dstJniDir = Join-Path $repoRoot "android\app\src\main\jniLibs"

Write-Host "Source AAR : $srcAar"
Write-Host "Source JNI : $srcJni"
Write-Host "Dest   AAR : $dstAar"
Write-Host "Dest   JNI : $dstJniDir"

if (!(Test-Path $srcAar)) {
  throw "AAR not found: $srcAar"
}
if (!(Test-Path $srcJni)) {
  throw "jniLibs not found: $srcJni"
}

New-Item -ItemType Directory -Force -Path $dstAarDir | Out-Null
New-Item -ItemType Directory -Force -Path $dstJniDir | Out-Null

Copy-Item -Force $srcAar $dstAar

# jniLibs 配下（arm64-v8a等）を丸ごとコピー
Get-ChildItem -Path $srcJni -Directory | ForEach-Object {
  $arch = $_.Name
  $dstArchDir = Join-Path $dstJniDir $arch
  New-Item -ItemType Directory -Force -Path $dstArchDir | Out-Null
  Copy-Item -Force -Path (Join-Path $_.FullName "*.so") -Destination $dstArchDir -ErrorAction SilentlyContinue
}

Write-Host "Done. (AAR + *.so copied)"

