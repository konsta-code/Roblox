$ErrorActionPreference = "Stop"

$projectFile = Join-Path $PSScriptRoot "default.project.json"
$pidFile = Join-Path $PSScriptRoot ".rojo.pid"
$stdoutLog = Join-Path $PSScriptRoot ".rojo.log"
$stderrLog = Join-Path $PSScriptRoot ".rojo-error.log"

if (Test-Path $pidFile) {
    $savedPid = Get-Content $pidFile -ErrorAction SilentlyContinue
    if ($savedPid -and (Get-Process -Id $savedPid -ErrorAction SilentlyContinue)) {
        Write-Host "CTFGame Rojo laeuft bereits (PID $savedPid) auf localhost:34872."
        exit 0
    }
}

$rojoCommand = Get-Command rojo -ErrorAction SilentlyContinue
if (-not $rojoCommand) {
    $wingetRoot = Join-Path $env:LOCALAPPDATA "Microsoft\WinGet\Packages"
    $rojoCommand = Get-ChildItem $wingetRoot -Filter "rojo.exe" -Recurse -ErrorAction SilentlyContinue |
        Select-Object -First 1
}
if (-not $rojoCommand) {
    throw "Rojo wurde nicht gefunden. Installiere Rojo und starte diese Datei erneut."
}

$rojoPath = if ($rojoCommand.Source) { $rojoCommand.Source } else { $rojoCommand.FullName }
$process = Start-Process `
    -FilePath $rojoPath `
    -ArgumentList @("serve", $projectFile, "--port", "34872") `
    -WorkingDirectory $PSScriptRoot `
    -WindowStyle Hidden `
    -RedirectStandardOutput $stdoutLog `
    -RedirectStandardError $stderrLog `
    -PassThru

$process.Id | Set-Content $pidFile
Start-Sleep -Milliseconds 700
if ($process.HasExited) {
    throw "Rojo konnte nicht starten. Details: $stderrLog"
}

Write-Host "CTFGame Rojo laeuft im Hintergrund (PID $($process.Id))."
Write-Host "In Studio mit localhost:34872 verbinden. Dieses Fenster darf geschlossen werden."
