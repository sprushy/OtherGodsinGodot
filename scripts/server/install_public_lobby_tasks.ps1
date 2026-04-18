param(
    [int]$UpdateIntervalMinutes = 15,
    [switch]$RunUpdateNow
)

$ErrorActionPreference = "Stop"

if ($UpdateIntervalMinutes -lt 5) {
    throw "UpdateIntervalMinutes must be at least 5."
}

$PowerShellExe = Join-Path $env:SystemRoot "System32\WindowsPowerShell\v1.0\powershell.exe"
$StartScript = Join-Path $PSScriptRoot "start_public_lobby.ps1"
$UpdateScript = Join-Path $PSScriptRoot "update_public_lobby.ps1"
$StartupTaskName = "ClaudeOtherGods Public Lobby Startup"
$UpdateTaskName = "ClaudeOtherGods Public Lobby AutoUpdate"

if (-not (Test-Path -LiteralPath $StartScript)) {
    throw "Start script not found at $StartScript"
}
if (-not (Test-Path -LiteralPath $UpdateScript)) {
    throw "Update script not found at $UpdateScript"
}

function Register-Task {
    param(
        [string]$Name,
        [string[]]$Arguments
    )

    & schtasks.exe @Arguments | Out-Null
    if ($LASTEXITCODE -ne 0) {
        throw "Failed to register scheduled task: $Name"
    }
}

$startCommand = "$PowerShellExe -NoProfile -ExecutionPolicy Bypass -File `"$StartScript`""
$updateCommand = "$PowerShellExe -NoProfile -ExecutionPolicy Bypass -File `"$UpdateScript`""

Register-Task -Name $StartupTaskName -Arguments @(
    "/Create",
    "/TN", $StartupTaskName,
    "/TR", $startCommand,
    "/SC", "ONSTART",
    "/RU", "SYSTEM",
    "/RL", "HIGHEST",
    "/F"
)

Register-Task -Name $UpdateTaskName -Arguments @(
    "/Create",
    "/TN", $UpdateTaskName,
    "/TR", $updateCommand,
    "/SC", "MINUTE",
    "/MO", "$UpdateIntervalMinutes",
    "/RU", "SYSTEM",
    "/RL", "HIGHEST",
    "/F"
)

Write-Host "Installed scheduled tasks:"
Write-Host " - $StartupTaskName"
Write-Host " - $UpdateTaskName (every $UpdateIntervalMinutes minutes)"

if ($RunUpdateNow) {
    & $UpdateScript
}
