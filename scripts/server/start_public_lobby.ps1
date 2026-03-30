$ErrorActionPreference = "Stop"

$RepoRoot = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
$ServerExe = Join-Path $RepoRoot ".exports\server\ClaudeOtherGodsServer.exe"
$LobbyHost = "63.33.96.156"
$LobbyPort = 22345
$MatchPort = 12345

if (-not (Test-Path -LiteralPath $ServerExe)) {
    throw "Server executable not found at $ServerExe"
}

$Existing = netstat -ano -p UDP |
    Select-String ":$LobbyPort\s" |
    ForEach-Object {
        $parts = ($_ -replace '\s+', ' ').Trim().Split(' ')
        if ($parts.Length -gt 0) { [int]$parts[-1] }
    } |
    Select-Object -Unique
if ($Existing) {
    foreach ($ProcessId in $Existing) {
        try {
            Stop-Process -Id $ProcessId -Force -ErrorAction Stop
        } catch {
            Write-Warning "Could not stop process $ProcessId listening on UDP ${LobbyPort}: $($_.Exception.Message)"
        }
    }
    Start-Sleep -Seconds 1
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
