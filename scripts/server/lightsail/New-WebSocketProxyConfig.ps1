param(
    [Parameter(Mandatory = $true)]
    [ValidatePattern('^(?=.{1,253}$)(?:[a-zA-Z0-9](?:[a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?\.)+[a-zA-Z]{2,63}$')]
    [string]$Domain,
    [string]$OutputDirectory = 'C:\OtherGodsServer',
    [ValidateRange(1024, 65535)]
    [int]$LobbyWebSocketPort = 24443,
    [ValidateRange(1024, 65472)]
    [int]$MatchPort = 12345
)

$ErrorActionPreference = 'Stop'
$matchPortCount = 64
if ($LobbyWebSocketPort -ge $MatchPort -and $LobbyWebSocketPort -lt $MatchPort + $matchPortCount) {
    throw 'The lobby WebSocket port must not overlap the match port range.'
}
$null = New-Item -ItemType Directory -Path $OutputDirectory -Force
$configPath = Join-Path $OutputDirectory 'network.json'
$caddyPath = Join-Path $OutputDirectory 'Caddyfile'
if ((Test-Path -LiteralPath $configPath) -or (Test-Path -LiteralPath $caddyPath)) {
    throw 'network.json or Caddyfile already exists. Generate into a new directory and review the changes.'
}

$lines = [System.Collections.Generic.List[string]]::new()
$lines.Add("$Domain {")
$lines.Add('    handle /healthz {')
$lines.Add('        respond "Other Gods TLS proxy" 200')
$lines.Add('    }')
$lines.Add('    handle /lobby {')
$lines.Add("        reverse_proxy 127.0.0.1:$LobbyWebSocketPort")
$lines.Add('    }')
for ($port = $MatchPort; $port -lt $MatchPort + $matchPortCount; $port++) {
    $lines.Add("    handle /match/$port {")
    $lines.Add("        reverse_proxy 127.0.0.1:$port")
    $lines.Add('    }')
}
$lines.Add('    handle {')
$lines.Add('        respond "Not found" 404')
$lines.Add('    }')
$lines.Add('}')
$lines | Set-Content -LiteralPath $caddyPath -Encoding utf8
@{
    public_websocket_url = "wss://$Domain"
    lobby_websocket_port = $LobbyWebSocketPort
    match_port = $MatchPort
} | ConvertTo-Json | Set-Content -LiteralPath $configPath -Encoding utf8

Write-Output "Generated $caddyPath and $configPath"
Write-Output "Client project setting: application/config/public_websocket_url = wss://$Domain"
Write-Output 'Validate with: caddy validate --config Caddyfile --adapter caddyfile'
