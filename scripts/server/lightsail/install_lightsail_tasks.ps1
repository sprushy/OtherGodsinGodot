param(
    [int]$UpdateIntervalMinutes = 3,
    [int]$WatchdogIntervalMinutes = 1
)

$ErrorActionPreference = "Stop"

if ($UpdateIntervalMinutes -lt 1) {
    throw "UpdateIntervalMinutes must be at least 1."
}
if ($WatchdogIntervalMinutes -lt 1) {
    throw "WatchdogIntervalMinutes must be at least 1."
}

$Root          = "C:\OtherGodsServer"
$PowerShellExe = Join-Path $env:SystemRoot "System32\WindowsPowerShell\v1.0\powershell.exe"
$UpdateScript  = Join-Path $Root "update_server.ps1"
$StartupScript = Join-Path $Root "start_server.ps1"
$UpdateTask    = "OtherGodsServerAutoUpdate"
$StartupTask   = "OtherGodsServerStartup"
$WatchdogTask  = "OtherGodsServerWatchdog"

if (-not (Test-Path -LiteralPath $UpdateScript))  { throw "Missing $UpdateScript" }
if (-not (Test-Path -LiteralPath $StartupScript)) { throw "Missing $StartupScript" }

$principal = New-ScheduledTaskPrincipal -UserId "SYSTEM" -RunLevel Highest
$settings  = New-ScheduledTaskSettingsSet -StartWhenAvailable -ExecutionTimeLimit (New-TimeSpan -Hours 1)
$repetitionDuration = New-TimeSpan -Days 9999

$updateAction  = New-ScheduledTaskAction -Execute $PowerShellExe -Argument "-NoProfile -ExecutionPolicy Bypass -File `"$UpdateScript`""
$updateTrigger = New-ScheduledTaskTrigger -Once -At (Get-Date) -RepetitionInterval (New-TimeSpan -Minutes $UpdateIntervalMinutes) -RepetitionDuration $repetitionDuration
Register-ScheduledTask -TaskName $UpdateTask -Action $updateAction -Trigger $updateTrigger -Principal $principal -Settings $settings -Force | Out-Null

$startupAction  = New-ScheduledTaskAction -Execute $PowerShellExe -Argument "-NoProfile -ExecutionPolicy Bypass -File `"$StartupScript`""
$startupTrigger = New-ScheduledTaskTrigger -AtStartup
Register-ScheduledTask -TaskName $StartupTask -Action $startupAction -Trigger $startupTrigger -Principal $principal -Settings $settings -Force | Out-Null

$watchdogAction  = New-ScheduledTaskAction -Execute $PowerShellExe -Argument "-NoProfile -ExecutionPolicy Bypass -File `"$StartupScript`""
$watchdogTrigger = New-ScheduledTaskTrigger -Once -At (Get-Date) -RepetitionInterval (New-TimeSpan -Minutes $WatchdogIntervalMinutes) -RepetitionDuration $repetitionDuration
Register-ScheduledTask -TaskName $WatchdogTask -Action $watchdogAction -Trigger $watchdogTrigger -Principal $principal -Settings $settings -Force | Out-Null

Write-Host "Registered scheduled tasks:"
Write-Host " - $UpdateTask (every $UpdateIntervalMinutes min)"
Write-Host " - $StartupTask (at boot)"
Write-Host " - $WatchdogTask (every $WatchdogIntervalMinutes min)"
