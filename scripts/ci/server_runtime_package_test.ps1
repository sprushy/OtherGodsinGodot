param(
    [string]$CaddyExe = ''
)

$ErrorActionPreference = 'Stop'
$projectRoot = [System.IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..\..'))
$runtimeSource = Join-Path $projectRoot 'scripts/server/lightsail'
$testRoot = Join-Path $projectRoot ('.codex_tmp/server-runtime-test-' + [guid]::NewGuid().ToString('N'))
$releaseRoot = Join-Path $testRoot 'release'
$installRoot = Join-Path $testRoot 'installed'
$projectFixture = Join-Path $testRoot 'project.godot'

function Assert-Condition([bool]$Condition, [string]$Message) {
    if (-not $Condition) {
        throw $Message
    }
}

function Test-LobbyStartup {
    param(
        [string]$Name,
        [bool]$InitiallyHealthy = $false,
        [bool]$RecoverWebSocket = $true,
        [bool]$WithConfig = $false,
        [int]$Port = 24443,
        [string]$InitialAddress = '127.0.0.1',
        [bool]$InitiallyRunning = $true
    )
    $startupRoot = Join-Path $testRoot $Name
    $null = New-Item -ItemType Directory -Path $startupRoot -Force
    Copy-Item -LiteralPath (Join-Path $runtimeSource 'start_server.ps1') -Destination $startupRoot
    Set-Content -LiteralPath (Join-Path $startupRoot 'OtherGodsServer.exe') -Value 'must not execute'
    if ($WithConfig) {
        @{
            public_websocket_url = 'wss://startup.example.com'
            lobby_websocket_port = $Port
            match_port = 12345
        } | ConvertTo-Json | Set-Content -LiteralPath (Join-Path $startupRoot 'network.json')
    }
    $startupState = @{
        Running = $InitiallyRunning; WebSocket = $InitiallyHealthy; Address = $InitialAddress
        Starts = 0; Stops = 0
    }
    # Exercise the real launcher, replacing every process, port and wait call.
    # The invalid fixture executable must never run, and no real server stops.
    function Get-NetUDPEndpoint {
        [CmdletBinding()] param($LocalPort)
        if ($startupState.Running) { [pscustomobject]@{ LocalPort = $LocalPort } }
    }
    function Get-NetTCPConnection {
        [CmdletBinding()] param($LocalPort, $State)
        Assert-Condition ($LocalPort -eq $Port -and $State -eq 'Listen') 'Health must check the configured WebSocket listener.'
        if ($startupState.Running -and $startupState.WebSocket) {
            [pscustomobject]@{ LocalPort = $LocalPort; LocalAddress = $startupState.Address }
        }
    }
    function Get-Process {
        [CmdletBinding()] param($Name)
        if ($startupState.Running) { [pscustomobject]@{ Id = 424242; ProcessName = 'OtherGodsServer' } }
    }
    function Stop-Process {
        [CmdletBinding()] param($Id, [switch]$Force)
        Assert-Condition ($Id -eq 424242) 'Only the mocked server process may be stopped.'
        $startupState.Stops += 1
        $startupState.Running = $false
    }
    function Start-Sleep { param($Seconds) }
    function Start-Process {
        [CmdletBinding()]
        param($FilePath, $ArgumentList, $WorkingDirectory, $WindowStyle, [switch]$PassThru)
        Assert-Condition ($WorkingDirectory -eq $startupRoot -and $WindowStyle -eq 'Hidden') 'Startup must use the selected install directory and hide its process.'
        Assert-Condition ($ArgumentList -contains "ws_port=$Port") 'Startup must explicitly enable the configured WebSocket port.'
        if ($WithConfig) {
            Assert-Condition ($env:OTHERGODS_PUBLIC_WEBSOCKET_URL -eq 'wss://startup.example.com') 'Startup must pass the configured public endpoint to Godot.'
        }
        $startupState.Starts += 1
        $startupState.Running = $true
        $startupState.WebSocket = $RecoverWebSocket
        $startupState.Address = '127.0.0.1'
        [pscustomobject]@{ Id = 424242; HasExited = $false }
    }
    $savedPublicUrl = $env:OTHERGODS_PUBLIC_WEBSOCKET_URL
    try {
        $env:OTHERGODS_PUBLIC_WEBSOCKET_URL = $null
        $startupError = $null
        try {
            & (Join-Path $startupRoot 'start_server.ps1') -Root $startupRoot -SkipMutex
        } catch {
            $startupError = $_
        }
        $alreadyHealthy = $InitiallyRunning -and $InitiallyHealthy -and $InitialAddress -in @('127.0.0.1', '0.0.0.0')
        if ($alreadyHealthy) {
            Assert-Condition ($null -eq $startupError -and $startupState.Starts -eq 0 -and $startupState.Stops -eq 0) 'A healthy UDP/WebSocket lobby must not restart.'
        } else {
            Assert-Condition ($startupState.Starts -eq 1 -and $startupState.Stops -eq [int]$InitiallyRunning) 'An unhealthy or stopped lobby must launch with WebSockets even without a public URL environment variable.'
            if ($RecoverWebSocket) {
                Assert-Condition ($null -eq $startupError) "WebSocket recovery failed: $startupError"
            } else {
                Assert-Condition ($null -ne $startupError -and $startupError.ToString().Contains('required lobby listeners')) 'A missing WebSocket listener must fail startup so the updater cannot report success.'
            }
        }
        $startupLog = Get-Content -LiteralPath (Join-Path $startupRoot 'updater.log') -Raw
        if ($alreadyHealthy -or $RecoverWebSocket) {
            Assert-Condition ($startupLog.Contains("WebSocket TCP $Port")) 'Healthy and recovery logs must identify the WebSocket port.'
        } else {
            Assert-Condition (-not $startupLog.Contains('listeners recovered')) 'Startup must not claim recovery while WebSockets are down.'
        }
    } finally {
        $env:OTHERGODS_PUBLIC_WEBSOCKET_URL = $savedPublicUrl
    }
}

function Test-ProxyServiceSetup([string]$ServerRoot, [string]$CaddySource) {
    $proxyState = @{ FirewallCreates = 0; ServiceCreates = 0; ServiceStarts = 0; AutomaticUpdates = 0; BinaryPath = ''; Running = $false }
    # Shadow the Windows machine-level cmdlets. Caddy only validates the
    # generated configuration; no real service or firewall rule is changed.
    function Get-NetFirewallRule {
        [CmdletBinding()] param($Name)
        if ($proxyState.FirewallCreates -gt 0) { [pscustomobject]@{ Name = $Name } }
    }
    function New-NetFirewallRule {
        [CmdletBinding()] param($Name, $DisplayName, $Direction, $Action, $Protocol, $LocalPort, $Program)
        Assert-Condition ($Protocol -eq 'TCP' -and ($LocalPort -join ',') -eq '80,443') 'The proxy may expose only its public TCP ports.'
        $proxyState.FirewallCreates += 1
    }
    function Get-Service {
        [CmdletBinding()] param($Name)
        if ($proxyState.ServiceCreates -gt 0) {
            [pscustomobject]@{ Status = $(if ($proxyState.Running) { 'Running' } else { 'Stopped' }) }
        }
    }
    function New-Service {
        [CmdletBinding()] param($Name, $DisplayName, $BinaryPathName, $StartupType)
        Assert-Condition ($StartupType -eq 'Automatic') 'Caddy must restart after a server reboot.'
        $proxyState.ServiceCreates += 1
        $proxyState.BinaryPath = $BinaryPathName
    }
    function Get-CimInstance {
        [CmdletBinding()] param($ClassName, $Filter)
        [pscustomobject]@{ PathName = $proxyState.BinaryPath }
    }
    function Set-Service {
        [CmdletBinding()] param($Name, $StartupType)
        $proxyState.AutomaticUpdates += 1
    }
    function Start-Service {
        [CmdletBinding()] param($Name)
        $proxyState.ServiceStarts += 1
        $proxyState.Running = $true
    }

    Expand-Archive -LiteralPath $archivePath -DestinationPath $ServerRoot -Force
    Copy-Item -LiteralPath $CaddySource -Destination (Join-Path $ServerRoot 'caddy.exe')
    & (Join-Path $ServerRoot 'Initialize-WebSocketProxy.ps1') -Root $ServerRoot
    & (Join-Path $ServerRoot 'Initialize-WebSocketProxy.ps1') -Root $ServerRoot
    Assert-Condition ($proxyState.FirewallCreates -eq 1 -and $proxyState.ServiceCreates -eq 1 -and $proxyState.ServiceStarts -eq 1) 'Repeated startup must not duplicate the firewall rule, reinstall Caddy, or restart a running proxy.'
    Assert-Condition ($proxyState.AutomaticUpdates -eq 1) 'Existing Caddy service must retain automatic startup.'
    $proxyState.Running = $false
    & (Join-Path $ServerRoot 'Initialize-WebSocketProxy.ps1') -Root $ServerRoot
    Assert-Condition ($proxyState.ServiceStarts -eq 2) 'The watchdog must recover a stopped proxy.'
}

try {
    $null = New-Item -ItemType Directory -Path $releaseRoot -Force
    Set-Content -LiteralPath $projectFixture -Value 'config/public_websocket_url="wss://othergods-server.duckdns.org"'
    Set-Content -LiteralPath (Join-Path $releaseRoot 'OtherGodsServer.exe') -Value 'export fixture'
    & (Join-Path $runtimeSource 'Stage-ServerRuntimeFiles.ps1') -OutputDirectory $releaseRoot -ProjectFile $projectFixture

    Assert-Condition ((Get-Content -LiteralPath (Join-Path $releaseRoot 'OtherGodsServer.exe') -Raw).Trim() -eq 'export fixture') 'Staging must preserve the exported server binary.'
    foreach ($fileName in @('start_server.ps1', 'update_server.ps1', 'Initialize-WebSocketProxy.ps1', 'New-WebSocketProxyConfig.ps1', 'install_lightsail_tasks.ps1', 'Set-RecoveryEmail.ps1')) {
        Assert-Condition (Test-Path -LiteralPath (Join-Path $releaseRoot $fileName)) "Missing packaged runtime script $fileName."
    }
    Assert-Condition (-not (Test-Path -LiteralPath (Join-Path $releaseRoot 'network.json'))) 'Release defaults must not overwrite installed network.json during extraction.'
    Assert-Condition (-not (Test-Path -LiteralPath (Join-Path $releaseRoot 'Caddyfile'))) 'Release defaults must not overwrite an installed Caddyfile during extraction.'

    $archivePath = Join-Path $testRoot 'OtherGodsServer-windows.zip'
    Compress-Archive -Path (Join-Path $releaseRoot '*') -DestinationPath $archivePath
    # This is the extraction behavior used by the already-deployed updater.
    Expand-Archive -LiteralPath $archivePath -DestinationPath $installRoot -Force
    # The setup helper ships without credentials. Preview must not prompt or
    # mutate the real machine, including when CI runs on Linux.
    $recoveryNames = @('OTHERGODS_GMAIL_ADDRESS', 'OTHERGODS_GMAIL_APP_PASSWORD')
    $previousRecoveryValues = @{}
    foreach ($name in $recoveryNames) {
        $previousRecoveryValues[$name] = [Environment]::GetEnvironmentVariable($name, 'Machine')
    }
    & (Join-Path $installRoot 'Set-RecoveryEmail.ps1') -Address 'test@gmail.com' -WhatIf
    foreach ($name in $recoveryNames) {
        Assert-Condition ([Environment]::GetEnvironmentVariable($name, 'Machine') -ceq $previousRecoveryValues[$name]) 'Recovery setup preview must not change System credentials.'
    }
    $recoverySetupContent = Get-Content -LiteralPath (Join-Path $installRoot 'Set-RecoveryEmail.ps1') -Raw
    Assert-Condition ($recoverySetupContent.Contains('-AsSecureString')) 'Recovery setup must prompt with hidden input.'
    Assert-Condition (-not $recoverySetupContent.Contains('[string]$AppPassword')) 'Recovery setup must not accept credentials in command arguments.'
    & (Join-Path $installRoot 'Initialize-WebSocketProxy.ps1') -Root $installRoot
    $networkConfig = Get-Content -LiteralPath (Join-Path $installRoot 'network.json') -Raw | ConvertFrom-Json
    Assert-Condition ($networkConfig.public_websocket_url -eq 'wss://othergods-server.duckdns.org') 'Installed origin must match the client origin.'
    Assert-Condition ($networkConfig.lobby_websocket_port -eq 24443 -and $networkConfig.match_port -eq 12345) 'Installed backend ports must match the proxy routes.'
    $caddyContent = Get-Content -LiteralPath (Join-Path $installRoot 'Caddyfile') -Raw
    Assert-Condition ($caddyContent.StartsWith('othergods-server.duckdns.org {')) 'Caddy must serve the configured hostname.'
    Assert-Condition ($caddyContent.Contains('reverse_proxy 127.0.0.1:24443')) 'Lobby backend must stay loopback-only.'
    Assert-Condition ([regex]::Matches($caddyContent, 'handle /match/\d+').Count -eq 64) 'Every dedicated match port needs a proxy route.'
    Assert-Condition ($caddyContent.Contains('handle /match/12345') -and $caddyContent.Contains('handle /match/12408')) 'Proxy routes must cover both ends of the match port pool.'

    # A second release must retain the operator's existing local settings.
    Set-Content -LiteralPath (Join-Path $installRoot 'network.json') -Value '{"public_websocket_url":"wss://custom.example.com"}'
    Set-Content -LiteralPath (Join-Path $installRoot 'Caddyfile') -Value 'custom operator configuration'
    Expand-Archive -LiteralPath $archivePath -DestinationPath $installRoot -Force
    & (Join-Path $installRoot 'Initialize-WebSocketProxy.ps1') -Root $installRoot
    Assert-Condition ((Get-Content -LiteralPath (Join-Path $installRoot 'network.json') -Raw).Contains('custom.example.com')) 'Updating must preserve local network configuration.'
    Assert-Condition ((Get-Content -LiteralPath (Join-Path $installRoot 'Caddyfile') -Raw).Trim() -eq 'custom operator configuration') 'Updating must preserve local Caddy configuration.'

    # An invalid executable is enough to prove -WhatIf stops before invoking
    # Caddy or any Windows firewall/service cmdlet, even on Linux CI.
    Set-Content -LiteralPath (Join-Path $installRoot 'caddy.exe') -Value 'must not execute'
    & (Join-Path $installRoot 'Initialize-WebSocketProxy.ps1') -Root $installRoot -WhatIf

    if (-not [string]::IsNullOrWhiteSpace($CaddyExe)) {
        Test-ProxyServiceSetup -ServerRoot (Join-Path $testRoot 'proxy-service') -CaddySource $CaddyExe
    }

    Test-LobbyStartup -Name 'startup-no-public-url'
    Test-LobbyStartup -Name 'startup-cold-start' -InitiallyRunning $false
    Test-LobbyStartup -Name 'startup-custom-port' -WithConfig $true -Port 24444
    Test-LobbyStartup -Name 'startup-already-healthy' -InitiallyHealthy $true
    Test-LobbyStartup -Name 'startup-wildcard-listener' -InitiallyHealthy $true -InitialAddress '0.0.0.0'
    Test-LobbyStartup -Name 'startup-wrong-interface' -InitiallyHealthy $true -InitialAddress '192.0.2.1'
    Test-LobbyStartup -Name 'startup-websocket-failed' -RecoverWebSocket $false

    Set-Content -LiteralPath $projectFixture -Value 'config/public_websocket_url=""'
    $udpReleaseRoot = Join-Path $testRoot 'udp-release'
    & (Join-Path $runtimeSource 'Stage-ServerRuntimeFiles.ps1') -OutputDirectory $udpReleaseRoot -ProjectFile $projectFixture
    Assert-Condition (-not (Test-Path -LiteralPath (Join-Path $udpReleaseRoot 'websocket-defaults'))) 'A UDP-only export must not invent public TLS configuration.'

    foreach ($scriptPath in (Get-ChildItem -LiteralPath $runtimeSource -Filter '*.ps1' -File | Select-Object -ExpandProperty FullName)) {
        $parseTokens = $null
        $parseErrors = $null
        $null = [System.Management.Automation.Language.Parser]::ParseFile($scriptPath, [ref]$parseTokens, [ref]$parseErrors)
        Assert-Condition ($parseErrors.Count -eq 0) "PowerShell parse errors in $scriptPath."
    }
    Write-Output 'server_runtime_package_test: PASS'
} finally {
    # Remove only this test's generated directory, after checking its absolute
    # path is inside this repository. Never touch the real server directory.
    $resolvedTestRoot = [System.IO.Path]::GetFullPath($testRoot)
    $workspacePrefix = $projectRoot.TrimEnd([System.IO.Path]::DirectorySeparatorChar) + [System.IO.Path]::DirectorySeparatorChar
    if ($resolvedTestRoot.StartsWith($workspacePrefix, [System.StringComparison]::OrdinalIgnoreCase) -and (Test-Path -LiteralPath $resolvedTestRoot)) {
        Remove-Item -LiteralPath $resolvedTestRoot -Recurse -Force
    }
}
