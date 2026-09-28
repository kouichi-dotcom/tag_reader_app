# Android 実機へフルビルドでデプロイする（ホットリロード不可の変更向け）
# Usage:
#   cd C:\dev\tag_reader_app; .\scripts\run-android-device.ps1
#   cd C:\dev\tag_reader_app; .\scripts\run-android-device.ps1 -Flavor prod
#
# flutter clean のあと flutter run する。flutter run は長時間プロセス。
# Cursor から実行するときは block_until_ms: 0 でバックグラウンド起動する。

#Requires -Version 5.1
param(
    [string]$DeviceId = "A142",
    [ValidateSet("staging", "prod")]
    [string]$Flavor = "staging"
)

$ErrorActionPreference = "Stop"

$ProjectRoot = Split-Path -Parent $PSScriptRoot
$FallbackDeviceId = "00067245O000580"
$AppEnv = if ($Flavor -eq "prod") { "prod" } else { "test" }

function Ensure-Command([string]$Name, [string]$Hint) {
    if (-not (Get-Command $Name -ErrorAction SilentlyContinue)) {
        throw "$Name not found. $Hint"
    }
}

function Resolve-DeviceId([string]$Preferred, [string]$Fallback) {
    $output = flutter devices 2>&1 | Out-String
    if ($output -match [regex]::Escape($Preferred)) {
        return $Preferred
    }
    if ($output -match [regex]::Escape($Fallback)) {
        Write-Host "Device $Preferred not found. Using fallback: $Fallback" -ForegroundColor DarkYellow
        return $Fallback
    }
    throw "Android device not found. Connect USB debugging device and run: flutter devices"
}

Write-Host "=== Flutter Android Device (full rebuild) ===" -ForegroundColor Cyan
Write-Host "Flavor=$Flavor APP_ENV=$AppEnv" -ForegroundColor DarkGray

Ensure-Command "flutter" "Install Flutter SDK and add it to PATH."

Push-Location $ProjectRoot
try {
    $resolvedDeviceId = Resolve-DeviceId $DeviceId $FallbackDeviceId
    Write-Host "Target device: $resolvedDeviceId" -ForegroundColor DarkGray

    Write-Host "(1/2) flutter clean..." -ForegroundColor Yellow
    flutter clean
    if ($LASTEXITCODE -ne 0) {
        throw "flutter clean failed (exit $LASTEXITCODE)"
    }

    Write-Host "(2/2) flutter run --flavor $Flavor -d $resolvedDeviceId ..." -ForegroundColor Yellow
    flutter run --flavor $Flavor `
        --dart-define=FLAVOR=$Flavor `
        --dart-define=APP_ENV=$AppEnv `
        -d $resolvedDeviceId
    if ($LASTEXITCODE -ne 0) {
        throw "flutter run failed (exit $LASTEXITCODE)"
    }
}
finally {
    Pop-Location
}
