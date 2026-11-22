[CmdletBinding(SupportsShouldProcess = $true)]
param(
    [string]$Root = $PSScriptRoot
)

$ErrorActionPreference = 'Stop'
$serviceName = 'OtherGodsCaddy'
$firewallName = 'OtherGodsWebSocketProxy'
$defaultsDirectory = Join-Path $Root 'websocket-defaults'
$networkConfigPath = Join-Path $Root 'network.json'
$caddyConfigPath = Join-Path $Root 'Caddyfile'
$caddyExePath = Join-Path $Root 'caddy.exe'
$logPath = Join-Path $Root 'updater.log'

function Write-ProxyLog([string]$Message) {
    if (-not $WhatIfPreference) {
        Add-Content -LiteralPath $logPath -Value ('{0} WebSocket proxy: {1}' -f (Get-Date -Format 'yyyy-MM-dd HH:mm:ss'), $Message)
    }
    Write-Verbose $Message
}

# The older updater can bootstrap this release simply by extracting the ZIP
# and calling its newly-installed start_server.ps1. Existing local settings
# are preserved across every subsequent update.
foreach ($fileName in @('network.json', 'Caddyfile')) {
    $sourcePath = Join-Path $defaultsDirectory $fileName
    $destinationPath = Join-Path $Root $fileName
    if ((Test-Path -LiteralPath $sourcePath) -and -not (Test-Path -LiteralPath $destinationPath)) {
        if ($PSCmdlet.ShouldProcess($destinationPath, 'Install release WebSocket configuration')) {
            Copy-Item -LiteralPath $sourcePath -Destination $destinationPath
            Write-ProxyLog "Installed $fileName from the release defaults."
        }
    }
}

if (-not (Test-Path -LiteralPath $networkConfigPath) -or -not (Test-Path -LiteralPath $caddyConfigPath)) {
    return
}
if (-not (Test-Path -LiteralPath $caddyExePath)) {
    $downloadedCaddyPath = Join-Path $Root 'caddy_windows_amd64.exe'
    if (Test-Path -LiteralPath $downloadedCaddyPath) {
        if ($PSCmdlet.ShouldProcess($caddyExePath, 'Install the downloaded Windows Caddy executable')) {
            Copy-Item -LiteralPath $downloadedCaddyPath -Destination $caddyExePath
        }
    }
    if (-not (Test-Path -LiteralPath $caddyExePath)) {
        Write-ProxyLog "Place the Windows Caddy executable at $caddyExePath to enable public HTTPS."
        return
    }
}

$networkConfig = Get-Content -LiteralPath $networkConfigPath -Raw | ConvertFrom-Json
if ([string]::IsNullOrWhiteSpace([string]$networkConfig.public_websocket_url)) {
    return
}

# ShouldProcess covers every machine-level operation so the setup can be
# inspected with -WhatIf without opening ports or installing a service.
if (-not $PSCmdlet.ShouldProcess($Root, 'Validate Caddy, allow TCP 80/443, and ensure the OtherGodsCaddy service is running')) {
    return
}

$validationErrorPreference = $ErrorActionPreference
try {
    # Windows PowerShell 5.1 treats redirected native stderr as ErrorRecords.
    # Caddy writes successful validation diagnostics there too, so use its
    # exit code to decide whether validation failed.
    $ErrorActionPreference = 'Continue'
    $global:LASTEXITCODE = -1
    $validationOutput = & $caddyExePath validate --config $caddyConfigPath --adapter caddyfile 2>&1
    $validationExitCode = $LASTEXITCODE
} finally {
    $ErrorActionPreference = $validationErrorPreference
}
if ($validationExitCode -ne 0) {
    throw "Caddy configuration validation failed: $($validationOutput | Out-String)"
}

if ($null -eq (Get-NetFirewallRule -Name $firewallName -ErrorAction SilentlyContinue)) {
    New-NetFirewallRule -Name $firewallName -DisplayName 'Other Gods HTTPS proxy' -Direction Inbound -Action Allow -Protocol TCP -LocalPort 80,443 -Program $caddyExePath | Out-Null
    Write-ProxyLog 'Allowed inbound TCP 80 and 443 in Windows Firewall.'
}

$binaryPath = '"{0}" run --config "{1}" --adapter caddyfile' -f $caddyExePath, $caddyConfigPath
$service = Get-Service -Name $serviceName -ErrorAction SilentlyContinue
if ($null -eq $service) {
    New-Service -Name $serviceName -DisplayName 'Other Gods HTTPS proxy' -BinaryPathName $binaryPath -StartupType Automatic | Out-Null
    Write-ProxyLog 'Installed the automatic OtherGodsCaddy Windows service.'
} else {
    $installedService = Get-CimInstance -ClassName Win32_Service -Filter "Name = '$serviceName'"
    if ($installedService.PathName.Replace('"', '').Trim() -ne $binaryPath.Replace('"', '').Trim()) {
        throw "Existing $serviceName service uses a different command. Expected: $binaryPath"
    }
    Set-Service -Name $serviceName -StartupType Automatic
}

$service = Get-Service -Name $serviceName
if ($service.Status -ne 'Running') {
    Start-Service -Name $serviceName
    Write-ProxyLog 'Started OtherGodsCaddy. Certificate provisioning requires public TCP 80/443 and working DNS.'
}
