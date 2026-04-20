param(
    [int]$UpdateIntervalMinutes = 3
)

$ErrorActionPreference = "Stop"

$Root          = "C:\OtherGodsServer"
$UpdateScript  = Join-Path $Root "update_server.ps1"
$StartupScript = Join-Path $Root "start_server.ps1"
$UpdateTask    = "OtherGodsServerAutoUpdate"
$StartupTask   = "OtherGodsServerStartup"

if (-not (Test-Path -LiteralPath $UpdateScript))  { throw "Missing $UpdateScript" }
if (-not (Test-Path -LiteralPath $StartupScript)) { throw "Missing $StartupScript" }

$principal = New-ScheduledTaskPrincipal -UserId "SYSTEM" -RunLevel Highest
$settings  = New-ScheduledTaskSettingsSet -StartWhenAvailable -ExecutionTimeLimit (New-TimeSpan -Minutes 10)

$updateAction  = New-ScheduledTaskAction -Execute "powershell.exe" -Argument "-NoProfile -ExecutionPolicy Bypass -File `"$UpdateScript`""
$updateTrigger = New-ScheduledTaskTrigger -Once -At (Get-Date) -RepetitionInterval (New-TimeSpan -Minutes $UpdateIntervalMinutes)
Register-ScheduledTask -TaskName $UpdateTask -Action $updateAction -Trigger $updateTrigger -Principal $principal -Settings $settings -Force | Out-Null

$startupAction  = New-ScheduledTaskAction -Execute "powershell.exe" -Argument "-NoProfile -ExecutionPolicy Bypass -File `"$StartupScript`""
$startupTrigger = New-ScheduledTaskTrigger -AtStartup
Register-ScheduledTask -TaskName $StartupTask -Action $startupAction -Trigger $startupTrigger -Principal $principal -Settings $settings -Force | Out-Null

Write-Host "Registered scheduled tasks:"
Write-Host " - $UpdateTask (every $UpdateIntervalMinutes min)"
Write-Host " - $StartupTask (at boot)"
