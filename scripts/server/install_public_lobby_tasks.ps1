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
$StartupTaskName = "OtherGods Public Lobby Startup"
$UpdateTaskName = "OtherGods Public Lobby AutoUpdate"

if (-not (Test-Path -LiteralPath $StartScript)) {
    throw "Start script not found at $StartScript"
}
if (-not (Test-Path -LiteralPath $UpdateScript)) {
    throw "Update script not found at $UpdateScript"
}

$principal = New-ScheduledTaskPrincipal -UserId "SYSTEM" -RunLevel Highest
$settings = New-ScheduledTaskSettingsSet -ExecutionTimeLimit (New-TimeSpan -Minutes 10) -StartWhenAvailable

$startAction = New-ScheduledTaskAction -Execute $PowerShellExe `
    -Argument "-NoProfile -ExecutionPolicy Bypass -File `"$StartScript`""
$startTrigger = New-ScheduledTaskTrigger -AtStartup
Register-ScheduledTask -TaskName $StartupTaskName `
    -Action $startAction -Trigger $startTrigger `
    -Settings $settings -Principal $principal -Force | Out-Null

$updateAction = New-ScheduledTaskAction -Execute $PowerShellExe `
    -Argument "-NoProfile -ExecutionPolicy Bypass -File `"$UpdateScript`""
$updateTrigger = New-ScheduledTaskTrigger -RepetitionInterval (New-TimeSpan -Minutes $UpdateIntervalMinutes) `
    -Once -At "00:00"
Register-ScheduledTask -TaskName $UpdateTaskName `
    -Action $updateAction -Trigger $updateTrigger `
    -Settings $settings -Principal $principal -Force | Out-Null

Write-Host "Installed scheduled tasks:"
Write-Host " - $StartupTaskName"
Write-Host " - $UpdateTaskName (every $UpdateIntervalMinutes minutes)"

if ($RunUpdateNow) {
    & $UpdateScript
}
