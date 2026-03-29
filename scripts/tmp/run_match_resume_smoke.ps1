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

$hostResult = Join-Path $tmp 'resume_smoke_host_result.txt'
$clientResult = Join-Path $tmp 'resume_smoke_client_result.txt'
$resumeResult = Join-Path $tmp 'resume_smoke_resume_result.txt'
$roomFile = Join-Path $tmp 'resume_smoke_room_code.txt'
$lobbyPidFile = Join-Path $tmp 'resume_smoke_lobby_pid.txt'
$lobbyReadyFile = Join-Path $tmp 'resume_smoke_lobby_ready.txt'
$hostLog = Join-Path $tmp 'resume_smoke_host.log'
$clientLog = Join-Path $tmp 'resume_smoke_client.log'
$resumeLog = Join-Path $tmp 'resume_smoke_resume.log'
$hostTrace = Join-Path $tmp 'resume_smoke_host.trace.log'
$clientTrace = Join-Path $tmp 'resume_smoke_client.trace.log'
$resumeTrace = Join-Path $tmp 'resume_smoke_resume.trace.log'
$lobbyServerTrace = Join-Path $tmp 'resume_smoke_lobby_server.trace.log'
$lobbyServerLog = Join-Path $tmp 'resume_smoke_lobby_server.log'

foreach ($path in @(
    $hostResult, $clientResult, $resumeResult,
    $roomFile, $lobbyPidFile, $lobbyReadyFile,
    $hostLog, $clientLog, $resumeLog,
    $hostTrace, $clientTrace, $resumeTrace,
    $lobbyServerTrace, $lobbyServerLog
)) {
    if (Test-Path $path) {
        Remove-Item -LiteralPath $path -Force
    }
}

$uniqueSuffix = [DateTimeOffset]::UtcNow.ToUnixTimeSeconds().ToString()
$hostUsername = "ResumeHost_" + $uniqueSuffix
$clientUsername = "ResumeClient_" + $uniqueSuffix
$hostPassword = "ResumePass123"
$clientPassword = "ResumePass456"

$hostArgs = @(
    '--path', $project,
    '--log-file', $hostLog,
    '--',
    'smoke_role=host',
    'smoke_ip=127.0.0.1',
    ('smoke_name=' + $hostUsername),
    'smoke_auth_mode=register',
    ('smoke_password=' + $hostPassword),
    'smoke_lobby_port=22745',
    'smoke_match_port=12745',
    ('smoke_room_file=' + $roomFile),
    ('smoke_result_file=' + $hostResult),
    ('smoke_trace_file=' + $hostTrace),
    ('smoke_lobby_server_trace_file=' + $lobbyServerTrace),
    ('smoke_lobby_server_log_file=' + $lobbyServerLog),
    ('smoke_lobby_pid_file=' + $lobbyPidFile),
    ('smoke_lobby_ready_file=' + $lobbyReadyFile),
    'smoke_timeout=45'
)

$clientArgs = @(
    '--path', $project,
    '--log-file', $clientLog,
    '--',
    'smoke_role=client',
    'smoke_ip=127.0.0.1',
    ('smoke_name=' + $clientUsername),
    'smoke_auth_mode=register',
    ('smoke_password=' + $clientPassword),
    'smoke_lobby_port=22745',
    'smoke_match_port=12745',
    ('smoke_room_file=' + $roomFile),
    ('smoke_result_file=' + $clientResult),
    ('smoke_trace_file=' + $clientTrace),
    'smoke_timeout=45'
)

$resumeArgs = @(
    '--path', $project,
    '--log-file', $resumeLog,
    '--',
    'smoke_role=resume',
    'smoke_ip=127.0.0.1',
    ('smoke_name=' + $clientUsername),
    'smoke_auth_mode=login',
    ('smoke_password=' + $clientPassword),
    'smoke_lobby_port=22745',
    'smoke_match_port=12745',
    ('smoke_result_file=' + $resumeResult),
    ('smoke_trace_file=' + $resumeTrace),
    'smoke_timeout=45'
)

$hostProc = $null
$clientProc = $null
$resumeProc = $null

try {
    $hostProc = Start-Process -FilePath $godot -ArgumentList $hostArgs -PassThru
    Start-Sleep -Milliseconds 1200
    $clientProc = Start-Process -FilePath $godot -ArgumentList $clientArgs -PassThru

    $initialDeadline = (Get-Date).AddSeconds(55)
    while ((Get-Date) -lt $initialDeadline) {
        $hostStatus = Get-SmokeStatus -Path $hostResult
        $clientStatus = Get-SmokeStatus -Path $clientResult
        if (($hostStatus -match '^(PASS|FAIL):') -and ($clientStatus -match '^(PASS|FAIL):')) {
            break
        }
        Start-Sleep -Milliseconds 500
    }

    $finalHostStatus = Get-SmokeStatus -Path $hostResult
    $finalClientStatus = Get-SmokeStatus -Path $clientResult

    if ($finalHostStatus -notmatch '^PASS:' -or $finalClientStatus -notmatch '^PASS:') {
        Write-Output ('HOST_RESULT:' + $(if ($finalHostStatus) { $finalHostStatus } else { 'MISSING' }))
        Write-Output ('CLIENT_RESULT:' + $(if ($finalClientStatus) { $finalClientStatus } else { 'MISSING' }))
        Write-Output 'RESUME_RESULT:MISSING'
    } else {
        Stop-TrackedProcess -Process $clientProc
        $clientProc = $null
        Start-Sleep -Milliseconds 1200
        $resumeProc = Start-Process -FilePath $godot -ArgumentList $resumeArgs -PassThru

        $resumeDeadline = (Get-Date).AddSeconds(55)
        while ((Get-Date) -lt $resumeDeadline) {
            $resumeStatus = Get-SmokeStatus -Path $resumeResult
            if ($resumeStatus -match '^(PASS|FAIL):') {
                break
            }
            Start-Sleep -Milliseconds 500
        }

        $finalResumeStatus = Get-SmokeStatus -Path $resumeResult
        Write-Output ('HOST_RESULT:' + $finalHostStatus)
        Write-Output ('CLIENT_RESULT:' + $finalClientStatus)
        Write-Output ('RESUME_RESULT:' + $(if ($finalResumeStatus) { $finalResumeStatus } else { 'MISSING' }))
    }

    foreach ($label in @(
        @{ Name = 'HOST_TRACE'; Path = $hostTrace },
        @{ Name = 'CLIENT_TRACE'; Path = $clientTrace },
        @{ Name = 'RESUME_TRACE'; Path = $resumeTrace },
        @{ Name = 'LOBBY_SERVER_TRACE'; Path = $lobbyServerTrace }
    )) {
        Write-Output ($label.Name + ':')
        if (Test-Path $label.Path) {
            Get-Content $label.Path -Raw
        } else {
            Write-Output 'MISSING'
        }
    }
}
finally {
    Stop-TrackedProcess -Process $resumeProc
    Stop-TrackedProcess -Process $clientProc
    Stop-TrackedProcess -Process $hostProc

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
