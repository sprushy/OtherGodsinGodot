param(
    [switch]$SkipMutex
)

$ErrorActionPreference = "Stop"
$Root = "C:\OtherGodsServer"
$PreferredExe = Join-Path $Root "OtherGodsServer.exe"
$LegacyExe = Join-Path $Root "ClaudeOtherGodsServer.exe"
$PreferredConsoleExe = Join-Path $Root "OtherGodsServer_console.exe"
$LegacyConsoleExe = Join-Path $Root "ClaudeOtherGodsServer_console.exe"
$ExeCandidates = @(
    $PreferredConsoleExe,
    $PreferredExe,
    $LegacyConsoleExe,
    $LegacyExe
)
$Log = Join-Path $Root "updater.log"
$LogDir = Join-Path $Root "logs"
$LobbyHost = "63.33.96.156"
$LobbyPort = 22345
$MatchPort = 12345
$LifecycleMutexName = "Global\OtherGodsServerLifecycle"
$RetainedLogFilesPerPattern = 20

function Write-Log($m) {
    Add-Content -LiteralPath $Log -Value ("{0} {1}" -f (Get-Date -Format 'yyyy-MM-dd HH:mm:ss'), $m)
}

function Get-ServerProcess {
    @(Get-Process -Name OtherGodsServer, OtherGodsServer_console, ClaudeOtherGodsServer, ClaudeOtherGodsServer_console -ErrorAction SilentlyContinue)
}

function Test-LobbyListener {
    @(Get-NetUDPEndpoint -LocalPort $LobbyPort -ErrorAction SilentlyContinue).Count -gt 0
}

function Remove-OldLogs {
    param(
        [string]$Pattern
    )

    if (-not (Test-Path -LiteralPath $LogDir)) {
        return
    }

    Get-ChildItem -LiteralPath $LogDir -Filter $Pattern -File -ErrorAction SilentlyContinue |
        Sort-Object LastWriteTime -Descending |
        Select-Object -Skip $RetainedLogFilesPerPattern |
        Remove-Item -Force -ErrorAction SilentlyContinue
}

function Stop-StaleServerProcess {
    $serverProcesses = @(Get-ServerProcess)
    if ($serverProcesses.Count -eq 0) {
        return
    }
    foreach ($serverProcess in $serverProcesses) {
        try {
            Stop-Process -Id $serverProcess.Id -Force -ErrorAction Stop
            Write-Log "Startup: stopped stale process $($serverProcess.ProcessName) (PID $($serverProcess.Id))."
        } catch {
            Write-Log "Startup: failed to stop stale process $($serverProcess.ProcessName) (PID $($serverProcess.Id)): $($_.Exception.Message)"
        }
    }
    Start-Sleep -Seconds 2
}

function Resolve-LaunchPath {
    $preferredExistingExe = $ExeCandidates | Where-Object { Test-Path -LiteralPath $_ } | Select-Object -First 1
    if ($preferredExistingExe) {
        return $preferredExistingExe
    }
    return $PreferredExe
}

$mutex = $null
$acquiredMutex = $false
if (-not $SkipMutex) {
    $mutex = New-Object System.Threading.Mutex($false, $LifecycleMutexName)
    try {
        $acquiredMutex = $mutex.WaitOne(0)
    } catch [System.Threading.AbandonedMutexException] {
        $acquiredMutex = $true
    }
    if (-not $acquiredMutex) {
        Write-Log "Startup: skipped because another lifecycle action is already running."
        return
    }
}

try {
    $launchPath = Resolve-LaunchPath

    if (-not (Test-Path -LiteralPath $launchPath)) {
        Write-Log "Startup: executable missing at $launchPath"
        throw "Server executable not found at $launchPath"
    }

    if (Test-LobbyListener) {
        Write-Log "Startup: lobby listener already healthy on UDP $LobbyPort."
        return
    }

    if (@(Get-ServerProcess).Count -gt 0) {
        Write-Log "Startup: process exists but lobby listener on UDP $LobbyPort is down; restarting."
        Stop-StaleServerProcess
    }

    New-Item -ItemType Directory -Force -Path $LogDir | Out-Null
    foreach ($pattern in @("server-*.stdout.log", "server-*.stderr.log", "server-*.godot.log", "server-*.trace.log")) {
        Remove-OldLogs -Pattern $pattern
    }

    $timestamp = Get-Date -Format "yyyyMMdd-HHmmss"
    $godotLogPath = Join-Path $LogDir "server-$timestamp.godot.log"
    $tracePath = Join-Path $LogDir "server-$timestamp.trace.log"

    $startArgs = @{
        FilePath = $launchPath
        ArgumentList = @(
            "--headless"
            "--log-file"
            $godotLogPath
            "--"
            "server_mode=lobby"
            "lobby_host=$LobbyHost"
            "lobby_port=$LobbyPort"
            "match_port=$MatchPort"
            "trace_file=$tracePath"
        )
        WorkingDirectory = $Root
        WindowStyle = "Hidden"
        PassThru = $true
    }
    if ($launchPath.ToLowerInvariant().EndsWith("_console.exe")) {
        $stdoutPath = Join-Path $LogDir "server-$timestamp.stdout.log"
        $stderrPath = Join-Path $LogDir "server-$timestamp.stderr.log"
        $startArgs.RedirectStandardOutput = $stdoutPath
        $startArgs.RedirectStandardError = $stderrPath
        Write-Log "Startup: launching $launchPath with godot_log=$godotLogPath trace=$tracePath stdout=$stdoutPath stderr=$stderrPath"
    } else {
        Write-Log "Startup: launching $launchPath with godot_log=$godotLogPath trace=$tracePath"
    }

    $serverProcess = Start-Process @startArgs
    Write-Log "Startup: launched server process PID $($serverProcess.Id)."

    $listenerReady = $false
    foreach ($attempt in 1..10) {
        Start-Sleep -Seconds 1
        if (Test-LobbyListener) {
            $listenerReady = $true
            break
        }
        if ($serverProcess.HasExited) {
            Write-Log "Startup: server process exited during startup with code $($serverProcess.ExitCode)."
            break
        }
    }

    if ($listenerReady) {
        Write-Log "Startup: lobby listener recovered on UDP $LobbyPort."
        return
    }

    if (-not $serverProcess.HasExited) {
        Write-Log "Startup: process is running but lobby listener on UDP $LobbyPort did not appear within 10s."
    }
} finally {
    if ($acquiredMutex -and $null -ne $mutex) {
        $mutex.ReleaseMutex() | Out-Null
    }
    if ($null -ne $mutex) {
        $mutex.Dispose()
    }
}
