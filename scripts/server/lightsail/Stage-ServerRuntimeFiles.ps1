param(
    [Parameter(Mandatory = $true)]
    [string]$OutputDirectory,
    [string]$ProjectFile = (Join-Path $PSScriptRoot '..\..\..\project.godot')
)

$ErrorActionPreference = 'Stop'
$projectContent = Get-Content -LiteralPath $ProjectFile -Raw
$urlMatch = [regex]::Match($projectContent, '(?m)^config/public_websocket_url="(?<url>[^"]*)"\s*$')
if (-not $urlMatch.Success) {
    throw 'project.godot is missing config/public_websocket_url.'
}
$publicUrl = $urlMatch.Groups['url'].Value.TrimEnd('/')

$null = New-Item -ItemType Directory -Path $OutputDirectory -Force
foreach ($fileName in @(
    'start_server.ps1',
    'update_server.ps1',
    'install_lightsail_tasks.ps1',
    'Set-RecoveryEmail.ps1',
    'Initialize-WebSocketProxy.ps1',
    'New-WebSocketProxyConfig.ps1'
)) {
    Copy-Item -LiteralPath (Join-Path $PSScriptRoot $fileName) -Destination (Join-Path $OutputDirectory $fileName) -Force
}

if (-not [string]::IsNullOrWhiteSpace($publicUrl)) {
    if ($publicUrl -notmatch '^wss://(?<domain>(?=.{1,253}$)(?:[a-zA-Z0-9](?:[a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?\.)+[a-zA-Z]{2,63})$') {
        throw 'The release WebSocket origin must be wss:// followed by a public DNS hostname on port 443.'
    }
    $domain = $Matches['domain']
    # Keep release defaults separate so extracting a later release cannot
    # overwrite the server operator's installed configuration.
    & (Join-Path $PSScriptRoot 'New-WebSocketProxyConfig.ps1') -Domain $domain -OutputDirectory (Join-Path $OutputDirectory 'websocket-defaults')
}

Write-Output "Staged Windows server runtime in $OutputDirectory"
