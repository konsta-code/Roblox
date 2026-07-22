$ErrorActionPreference = "Stop"

$blender = "C:\Program Files\Blender Foundation\Blender 5.2\blender.exe"
if (-not (Test-Path -LiteralPath $blender)) {
    throw "Blender 5.2 wurde nicht gefunden: $blender"
}

$root = Split-Path -Parent $MyInvocation.MyCommand.Path
$jobs = @(
    @{ Name = "Titan Alpine"; Script = Join-Path $root "environment\titan_alpine_v01\build_titan_alpine.py" },
    @{ Name = "Arsenal"; Script = Join-Path $root "weapons\arsenal_v01\build_arsenal.py" },
    @{ Name = "Class Armor"; Script = Join-Path $root "characters\class_armor_v01\build_class_armor.py" }
)

foreach ($job in $jobs) {
    Write-Host "`n=== $($job.Name) ===" -ForegroundColor Cyan
    $stdout = [System.IO.Path]::GetTempFileName()
    $stderr = [System.IO.Path]::GetTempFileName()
    try {
        $process = Start-Process -FilePath $blender `
            -ArgumentList @("--background", "--python", "`"$($job.Script)`"") `
            -WindowStyle Hidden -Wait -PassThru `
            -RedirectStandardOutput $stdout -RedirectStandardError $stderr
        $output = @(
            Get-Content -LiteralPath $stdout -ErrorAction SilentlyContinue
            Get-Content -LiteralPath $stderr -ErrorAction SilentlyContinue
        )
    }
    finally {
        Remove-Item -LiteralPath $stdout, $stderr -Force -ErrorAction SilentlyContinue
    }
    $output | Out-Host
    if ($process.ExitCode -ne 0 -or $output -match "Traceback|RuntimeError|TypeError") {
        throw "Blender-Build fehlgeschlagen: $($job.Name)"
    }
}

Write-Host "`nAlle Blender-Packs wurden erfolgreich gebaut." -ForegroundColor Green
