param(
    [switch]$StopOnly
)

$ErrorActionPreference = "Stop"

$RepoRoot = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
$ServerExe = Join-Path $RepoRoot ".exports\server\ClaudeOtherGodsServer.exe"
$LobbyHost = "63.33.96.156"
$LobbyPort = 22345
$MatchPort = 12345

function Stop-LobbyListener {
    param(
        [int]$Port
    )

    $existing = netstat -ano -p UDP |
        Select-String ":$Port\s" |
        ForEach-Object {
            $parts = ($_ -replace '\s+', ' ').Trim().Split(' ')
            if ($parts.Length -gt 0) { [int]$parts[-1] }
        } |
        Select-Object -Unique

    if (-not $existing) {
        return $false
    }

    foreach ($processId in $existing) {
        try {
            Stop-Process -Id $processId -Force -ErrorAction Stop
        } catch {
            Write-Warning "Could not stop process $processId listening on UDP ${Port}: $($_.Exception.Message)"
        }
    }

    Start-Sleep -Seconds 1
    return $true
}

$stoppedExisting = Stop-LobbyListener -Port $LobbyPort
if ($StopOnly) {
    if ($stoppedExisting) {
        Write-Host "Stopped public lobby server listener on UDP ${LobbyPort}"
    } else {
        Write-Host "No public lobby server listener found on UDP ${LobbyPort}"
    }
    return
}

if (-not (Test-Path -LiteralPath $ServerExe)) {
    throw "Server executable not found at $ServerExe"
}

$Arguments = @(
    "--headless"
    "--"
    "server_mode=lobby"
    "lobby_host=$LobbyHost"
    "lobby_port=$LobbyPort"
    "match_port=$MatchPort"
)

Start-Process -FilePath $ServerExe -ArgumentList $Arguments -WorkingDirectory $RepoRoot
Write-Host "Started public lobby server at $LobbyHost`:$LobbyPort"
