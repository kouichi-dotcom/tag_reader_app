# TSS iOS SDK 配置スクリプト
# 既定の参照元: 共有フォルダ TagReader 直下の SDK_for_iOS_6.2.0
# 配置先: ios/third_party/SDK_for_iOS_6.2.0/

param(
  [string]$SourceRoot = "\\OOMIYASV1\ohmiya\個人用ファイル\宮城宏一\TagReader\SDK_for_iOS_6.2.0"
)

$ErrorActionPreference = "Stop"

$repoRoot = Split-Path -Parent $PSScriptRoot
$dstRoot = Join-Path $repoRoot "ios\third_party\SDK_for_iOS_6.2.0"

Write-Host "Source : $SourceRoot"
Write-Host "Dest   : $dstRoot"

if (!(Test-Path $SourceRoot)) {
  throw "SDK source not found: $SourceRoot`nUse -SourceRoot to point at your SDK_for_iOS_6.2.0 folder."
}

New-Item -ItemType Directory -Force -Path $dstRoot | Out-Null

# ソース直下のファイル・フォルダをすべてコピー（既存は上書き）
Copy-Item -Path (Join-Path $SourceRoot "*") -Destination $dstRoot -Recurse -Force

Write-Host "Done. Review ios/third_party/SDK_for_iOS_6.2.0 then: git add ios/third_party/SDK_for_iOS_6.2.0"
