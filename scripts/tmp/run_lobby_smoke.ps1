$godot = 'C:\Users\spaul\Downloads\Godot_v4.6.1-stable_win64.exe\Godot_v4.6.1-stable_win64.exe'
$project = 'C:\Users\spaul\Documents\other-godsin-godot-main'
$tmp = Join-Path $project 'scripts\tmp'
. (Join-Path $tmp 'GodotPortableEnv.ps1')
$null = Set-GodotPortableEnvironment -ProjectRoot $project
$roomFile = Join-Path $tmp 'smoke_room_code.txt'
$hostResult = Join-Path $tmp 'smoke_host_result.txt'
$clientResult = Join-Path $tmp 'smoke_client_result.txt'
$lobbyPidFile = Join-Path $tmp 'smoke_lobby_pid.txt'
$lobbyReadyFile = Join-Path $tmp 'smoke_lobby_ready.txt'
$hostLog = Join-Path $tmp 'smoke_host.log'
$clientLog = Join-Path $tmp 'smoke_client.log'
$hostTrace = Join-Path $tmp 'smoke_host.trace.log'
$clientTrace = Join-Path $tmp 'smoke_client.trace.log'
$lobbyServerTrace = Join-Path $tmp 'smoke_lobby_server.trace.log'
$lobbyServerLog = Join-Path $tmp 'smoke_lobby_server.log'
$lobbyPort = 22445
$matchPort = 12445

function Get-SmokeStatus {
    param(
        [string]$Path
    )

    if (-not (Test-Path $Path)) {
        return ''
    }

    return (Get-Content $Path -Raw).Trim()
}

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
    'smoke_name=SmokeHost',
    ('smoke_lobby_port=' + $lobbyPort),
    ('smoke_match_port=' + $matchPort),
    ('smoke_room_file=' + $roomFile),
    ('smoke_result_file=' + $hostResult),
    ('smoke_trace_file=' + $hostTrace),
    ('smoke_lobby_server_trace_file=' + $lobbyServerTrace),
    ('smoke_lobby_server_log_file=' + $lobbyServerLog),
    ('smoke_lobby_pid_file=' + $lobbyPidFile),
    ('smoke_lobby_ready_file=' + $lobbyReadyFile),
    'smoke_timeout=30'
)

$clientArgs = @(
    '--path', $project,
    '--log-file', $clientLog,
    '--',
    'smoke_role=client',
    'smoke_ip=127.0.0.1',
    'smoke_name=SmokeClient',
    ('smoke_lobby_port=' + $lobbyPort),
    ('smoke_match_port=' + $matchPort),
    ('smoke_room_file=' + $roomFile),
    ('smoke_result_file=' + $clientResult),
    ('smoke_trace_file=' + $clientTrace),
    'smoke_timeout=30'
)

$hostProc = Start-Process -FilePath $godot -ArgumentList $hostArgs -PassThru
Start-Sleep -Milliseconds 1000
$clientProc = Start-Process -FilePath $godot -ArgumentList $clientArgs -PassThru

$deadline = (Get-Date).AddSeconds(40)
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

foreach ($proc in @($hostProc, $clientProc)) {
    if ($null -ne $proc) {
        try {
            if (-not $proc.HasExited) {
                Stop-Process -Id $proc.Id -Force
            }
        } catch {
        }
    }
}

if (Test-Path $lobbyPidFile) {
    try {
        $lobbyPid = [int]((Get-Content $lobbyPidFile -Raw).Trim())
        if ($lobbyPid -gt 0) {
            Stop-Process -Id $lobbyPid -Force -ErrorAction SilentlyContinue
        }
    } catch {
    }
}

Write-Output 'HOST_RESULT:'
if ($finalHostStatus) {
    Write-Output $finalHostStatus
} else {
    Write-Output 'MISSING'
}

Write-Output 'CLIENT_RESULT:'
if ($finalClientStatus) {
    Write-Output $finalClientStatus
} else {
    Write-Output 'MISSING'
}

Write-Output 'ROOM_CODE:'
if (Test-Path $roomFile) {
    Get-Content $roomFile
} else {
    Write-Output 'MISSING'
}

Write-Output 'HOST_LOG:'
if (Test-Path $hostLog) {
    Get-Content $hostLog
} else {
    Write-Output 'MISSING'
}

Write-Output 'CLIENT_LOG:'
if (Test-Path $clientLog) {
    Get-Content $clientLog
} else {
    Write-Output 'MISSING'
}

Write-Output 'HOST_TRACE:'
if (Test-Path $hostTrace) {
    Get-Content $hostTrace
} else {
    Write-Output 'MISSING'
}

Write-Output 'CLIENT_TRACE:'
if (Test-Path $clientTrace) {
    Get-Content $clientTrace
} else {
    Write-Output 'MISSING'
}

Write-Output 'LOBBY_SERVER_TRACE:'
if (Test-Path $lobbyServerTrace) {
    Get-Content $lobbyServerTrace
} else {
    Write-Output 'MISSING'
}

Write-Output 'LOBBY_SERVER_LOG:'
if (Test-Path $lobbyServerLog) {
    Get-Content $lobbyServerLog
} else {
    Write-Output 'MISSING'
}
