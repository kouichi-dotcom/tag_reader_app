$ErrorActionPreference = 'Continue'
$log = 'C:\dev\tag_reader_app\scripts\fix-flutter-lock.log'
function Log($m) { "$(Get-Date -Format o) $m" | Tee-Object -FilePath $log -Append }

Log '=== 1. Processes ==='
Get-Process | Where-Object { $_.ProcessName -match '^(dart|flutter|java|adb|Code|Cursor)' } |
  ForEach-Object { Log ("PROC $($_.Id) $($_.ProcessName)") }

Log '=== dart/flutter only ==='
$dartFlutter = Get-CimInstance Win32_Process | Where-Object { $_.Name -match '^(dart|flutter)' }
if ($dartFlutter) {
  $dartFlutter | ForEach-Object { Log ("DF $($_.ProcessId) $($_.Name) $($_.CommandLine)") }
  Log '=== Stopping leftover dart/flutter (not Cursor) ==='
  foreach ($p in $dartFlutter) {
    try {
      Stop-Process -Id $p.ProcessId -Force -ErrorAction Stop
      Log "STOPPED $($p.ProcessId) $($p.Name)"
    } catch {
      Log "STOP_FAIL $($p.ProcessId): $($_.Exception.Message)"
    }
  }
} else {
  Log 'No dart.exe / flutter.exe processes found'
}

Log '=== 2. handle/openfiles ==='
$handle = Get-Command handle.exe -ErrorAction SilentlyContinue
if ($handle) {
  & $handle.Source 'engine.stamp' 2>&1 | ForEach-Object { Log $_ }
} else {
  Log 'handle.exe not available - skip'
}

Log '=== 4. Rename stamp/lock files ==='
$cache = 'C:\Users\kouichiPC\.android\flutter\bin\cache'
$ts = Get-Date -Format 'yyyyMMdd_HHmmss'
$names = @('engine.stamp','engine.realm','flutter.bat.lock')
Get-ChildItem $cache -Filter '*engine*.lock' -ErrorAction SilentlyContinue | ForEach-Object { $names += $_.Name }
Get-ChildItem $cache -Filter '*.lock' -ErrorAction SilentlyContinue | ForEach-Object { $names += $_.Name }
$names = $names | Select-Object -Unique
foreach ($name in $names) {
  $path = Join-Path $cache $name
  if (Test-Path $path) {
    try {
      Rename-Item -LiteralPath $path -NewName "$name.bak_$ts" -ErrorAction Stop
      Log "RENAMED $name"
    } catch {
      try {
        Remove-Item -LiteralPath $path -Force -ErrorAction Stop
        Log "REMOVED $name"
      } catch {
        Log "FAILED $name : $($_.Exception.Message)"
      }
    }
  } else {
    Log "MISSING $name"
  }
}

Log '=== cache after ==='
Get-ChildItem $cache -ErrorAction SilentlyContinue | Where-Object { $_.Name -match 'engine|\.lock' } |
  ForEach-Object { Log ("CACHE $($_.Name) $($_.Length) $($_.LastWriteTime)") }

Log '=== 5. flutter --version ==='
$env:Path = "C:\Users\kouichiPC\.android\flutter\bin;" + $env:Path
Set-Location 'C:\dev\tag_reader_app'
$ver = & flutter --version 2>&1
$ver | ForEach-Object { Log $_ }
$verExit = $LASTEXITCODE
Log "flutter --version exit=$verExit"

if ($verExit -eq 0) {
  Log '=== 6. flutter run -d A142 (background) ==='
  $runLog = 'C:\dev\tag_reader_app\scripts\flutter-run-a142.log'
  Start-Process -FilePath 'powershell.exe' -ArgumentList @(
    '-NoProfile','-ExecutionPolicy','Bypass','-Command',
    "Set-Location 'C:\dev\tag_reader_app'; `$env:Path = 'C:\Users\kouichiPC\.android\flutter\bin;' + `$env:Path; flutter run -d A142 *>&1 | Tee-Object -FilePath '$runLog'"
  ) -WindowStyle Minimized
  Log "Started flutter run; log=$runLog"
} else {
  Log 'SKIP flutter run because --version failed'
}

Log '=== DONE ==='
