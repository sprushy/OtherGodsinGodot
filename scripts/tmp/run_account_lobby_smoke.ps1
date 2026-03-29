$godot = 'C:\Users\spaul\Downloads\Godot_v4.6.1-stable_win64.exe\Godot_v4.6.1-stable_win64.exe'
$project = 'C:\Users\spaul\Documents\other-godsin-godot-main'
$tmp = Join-Path $project 'scripts\tmp'
. (Join-Path $tmp 'GodotPortableEnv.ps1')
$null = Set-GodotPortableEnvironment -ProjectRoot $project

function Get-SmokeStatus {
    param(
        [string]$Path
    )

    if (-not (Test-Path $Path)) {
        return ''
    }

    return (Get-Content $Path -Raw).Trim()
}

function Stop-TrackedProcess {
    param(
        $Process
    )

    if ($null -eq $Process) {
        return
    }

    try {
        if (-not $Process.HasExited) {
            Stop-Process -Id $Process.Id -Force
        }
    } catch {
    }
}

function Invoke-SmokePass {
    param(
        [string]$PassName,
        [int]$LobbyPort,
        [int]$MatchPort,
        [string]$HostAuthMode,
        [string]$HostName,
        [string]$HostPassword,
        [string]$ClientAuthMode,
        [string]$ClientName,
        [string]$ClientPassword
    )

    $roomFile = Join-Path $tmp ("account_smoke_" + $PassName + "_room_code.txt")
    $hostResult = Join-Path $tmp ("account_smoke_" + $PassName + "_host_result.txt")
    $clientResult = Join-Path $tmp ("account_smoke_" + $PassName + "_client_result.txt")
    $lobbyPidFile = Join-Path $tmp ("account_smoke_" + $PassName + "_lobby_pid.txt")
    $lobbyReadyFile = Join-Path $tmp ("account_smoke_" + $PassName + "_lobby_ready.txt")
    $hostLog = Join-Path $tmp ("account_smoke_" + $PassName + "_host.log")
    $clientLog = Join-Path $tmp ("account_smoke_" + $PassName + "_client.log")
    $hostTrace = Join-Path $tmp ("account_smoke_" + $PassName + "_host.trace.log")
    $clientTrace = Join-Path $tmp ("account_smoke_" + $PassName + "_client.trace.log")
    $lobbyServerTrace = Join-Path $tmp ("account_smoke_" + $PassName + "_lobby_server.trace.log")
    $lobbyServerLog = Join-Path $tmp ("account_smoke_" + $PassName + "_lobby_server.log")

    foreach ($path in @($roomFile, $hostResult, $clientResult, $lobbyPidFile, $lobbyReadyFile, $hostLog, $clientLog, $hostTrace, $clientTrace, $lobbyServerTrace, $lobbyServerLog)) {
        if (Test-Path $path) {
            Remove-Item -LiteralPath $path -Force
        }
    }

    $hostArgs = @(
        '--path', $project,
        '--log-file', $hostLog,
        '--',
        'smoke_role=host',
        'smoke_ip=127.0.0.1',
        ('smoke_name=' + $HostName),
        ('smoke_auth_mode=' + $HostAuthMode),
        ('smoke_password=' + $HostPassword),
        ('smoke_lobby_port=' + $LobbyPort),
        ('smoke_match_port=' + $MatchPort),
        ('smoke_room_file=' + $roomFile),
        ('smoke_result_file=' + $hostResult),
        ('smoke_trace_file=' + $hostTrace),
        ('smoke_lobby_server_trace_file=' + $lobbyServerTrace),
        ('smoke_lobby_server_log_file=' + $lobbyServerLog),
        ('smoke_lobby_pid_file=' + $lobbyPidFile),
        ('smoke_lobby_ready_file=' + $lobbyReadyFile),
        'smoke_timeout=35'
    )

    $clientArgs = @(
        '--path', $project,
        '--log-file', $clientLog,
        '--',
        'smoke_role=client',
        'smoke_ip=127.0.0.1',
        ('smoke_name=' + $ClientName),
        ('smoke_auth_mode=' + $ClientAuthMode),
        ('smoke_password=' + $ClientPassword),
        ('smoke_lobby_port=' + $LobbyPort),
        ('smoke_match_port=' + $MatchPort),
        ('smoke_room_file=' + $roomFile),
        ('smoke_result_file=' + $clientResult),
        ('smoke_trace_file=' + $clientTrace),
        'smoke_timeout=35'
    )

    $hostProc = $null
    $clientProc = $null
    try {
        $hostProc = Start-Process -FilePath $godot -ArgumentList $hostArgs -PassThru
        Start-Sleep -Milliseconds 1200
        $clientProc = Start-Process -FilePath $godot -ArgumentList $clientArgs -PassThru

        $deadline = (Get-Date).AddSeconds(45)
        while ((Get-Date) -lt $deadline) {
            $hostStatus = Get-SmokeStatus -Path $hostResult
            $clientStatus = Get-SmokeStatus -Path $clientResult
            $hostDone = $hostStatus -match '^(PASS|FAIL):'
            $clientDone = $clientStatus -match '^(PASS|FAIL):'
            if ($hostDone -and $clientDone) {
                break
            }
            Start-Sleep -Milliseconds 500
        }

        $finalHostStatus = Get-SmokeStatus -Path $hostResult
        $finalClientStatus = Get-SmokeStatus -Path $clientResult

        return @{
            pass_name = $PassName
            host_result = $(if ($finalHostStatus) { $finalHostStatus } else { 'MISSING' })
            client_result = $(if ($finalClientStatus) { $finalClientStatus } else { 'MISSING' })
            room_code = $(if (Test-Path $roomFile) { (Get-Content $roomFile -Raw).Trim() } else { 'MISSING' })
            host_log = $(if (Test-Path $hostLog) { Get-Content $hostLog -Raw } else { 'MISSING' })
            client_log = $(if (Test-Path $clientLog) { Get-Content $clientLog -Raw } else { 'MISSING' })
            host_trace = $(if (Test-Path $hostTrace) { Get-Content $hostTrace -Raw } else { 'MISSING' })
            client_trace = $(if (Test-Path $clientTrace) { Get-Content $clientTrace -Raw } else { 'MISSING' })
            lobby_server_trace = $(if (Test-Path $lobbyServerTrace) { Get-Content $lobbyServerTrace -Raw } else { 'MISSING' })
            lobby_server_log = $(if (Test-Path $lobbyServerLog) { Get-Content $lobbyServerLog -Raw } else { 'MISSING' })
        }
    }
    finally {
        Stop-TrackedProcess -Process $hostProc
        Stop-TrackedProcess -Process $clientProc

        if (Test-Path $lobbyPidFile) {
            try {
                $lobbyPid = [int]((Get-Content $lobbyPidFile -Raw).Trim())
                if ($lobbyPid -gt 0) {
                    Stop-Process -Id $lobbyPid -Force -ErrorAction SilentlyContinue
                }
            } catch {
            }
        }
    }
}

$uniqueSuffix = [DateTimeOffset]::UtcNow.ToUnixTimeSeconds().ToString()
$hostUsername = "SmokeHost_" + $uniqueSuffix
$clientUsername = "SmokeClient_" + $uniqueSuffix
$hostPassword = "SmokePass123"
$clientPassword = "SmokePass456"

$registerPass = Invoke-SmokePass `
    -PassName 'register' `
    -LobbyPort 22545 `
    -MatchPort 12545 `
    -HostAuthMode 'register' `
    -HostName $hostUsername `
    -HostPassword $hostPassword `
    -ClientAuthMode 'register' `
    -ClientName $clientUsername `
    -ClientPassword $clientPassword

$loginPass = Invoke-SmokePass `
    -PassName 'login' `
    -LobbyPort 22645 `
    -MatchPort 12645 `
    -HostAuthMode 'login' `
    -HostName $hostUsername `
    -HostPassword $hostPassword `
    -ClientAuthMode 'login' `
    -ClientName $clientUsername `
    -ClientPassword $clientPassword

foreach ($result in @($registerPass, $loginPass)) {
    Write-Output ('PASS_NAME:' + $result.pass_name)
    Write-Output 'HOST_RESULT:'
    Write-Output $result.host_result
    Write-Output 'CLIENT_RESULT:'
    Write-Output $result.client_result
    Write-Output 'ROOM_CODE:'
    Write-Output $result.room_code
    Write-Output 'HOST_LOG:'
    Write-Output $result.host_log
    Write-Output 'CLIENT_LOG:'
    Write-Output $result.client_log
    Write-Output 'HOST_TRACE:'
    Write-Output $result.host_trace
    Write-Output 'CLIENT_TRACE:'
    Write-Output $result.client_trace
    Write-Output 'LOBBY_SERVER_TRACE:'
    Write-Output $result.lobby_server_trace
    Write-Output 'LOBBY_SERVER_LOG:'
    Write-Output $result.lobby_server_log
}
