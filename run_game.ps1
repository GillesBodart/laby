param(
    [string]$Godot = $env:GODOT_EXE,
    [Parameter(ValueFromRemainingArguments = $true)]
    [string[]]$GameArgs
)
# Launches LABY. Usage: .\run_game.ps1 [--seed=5] [--time=12:00] [--area=labyrinth]
# Engine lookup: -Godot, $env:GODOT_EXE, C:\Tool\Godot, then PATH.

$ErrorActionPreference = 'Stop'
$project = $PSScriptRoot
if (-not $project) { $project = (Get-Location).Path }

if (-not $Godot -or -not (Test-Path $Godot)) {
    $candidates = @(Get-ChildItem 'C:\Tool\Godot\Godot_v*_win64.exe' -ErrorAction SilentlyContinue |
        Sort-Object Name -Descending | ForEach-Object FullName)
    $onPath = Get-Command 'godot*' -CommandType Application -ErrorAction SilentlyContinue | Select-Object -First 1
    if ($onPath) { $candidates += $onPath.Source }
    $Godot = $candidates | Where-Object { $_ -and (Test-Path $_) } | Select-Object -First 1
}
if (-not $Godot) {
    Write-Host "Godot not found. Set GODOT_EXE or pass -Godot <path to Godot .exe>." -ForegroundColor Red
    Read-Host "Press Enter to close"
    exit 1
}

$launch = @('--path', "`"$project`"")
if ($GameArgs) { $launch += '--'; $launch += $GameArgs }
Write-Host "Starting LABY with $Godot"
Start-Process -FilePath $Godot -ArgumentList $launch -WorkingDirectory $project
