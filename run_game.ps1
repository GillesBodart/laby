param(
    [string]$Godot = $(if ($env:GODOT_EXE) { $env:GODOT_EXE } else { 'C:\Tool\Godot\Godot_v4.7.2-stable_win64.exe' }),
    [Parameter(ValueFromRemainingArguments = $true)]
    [string[]]$GameArgs
)
# Launches LABY. Usage: .\run_game.ps1 [--seed=5] [--time=12:00] [--area=labyrinth]
# Override the engine path with -Godot <path> or the GODOT_EXE environment variable.

if (-not (Test-Path $Godot)) {
    Write-Error "Godot not found at '$Godot'. Set GODOT_EXE or pass -Godot <path>."
    exit 1
}

$args = @('--path', $PSScriptRoot)
if ($GameArgs) { $args += '--'; $args += $GameArgs }
Start-Process -FilePath $Godot -ArgumentList $args
