[CmdletBinding(SupportsShouldProcess = $true)]
param(
    [string]$Address = 'OtherGodsGame@gmail.com'
)

$ErrorActionPreference = 'Stop'
$Address = $Address.Trim().ToLowerInvariant()
if ($Address -notmatch '^[a-z0-9._%+\-]+@(gmail|googlemail)\.com$') {
    throw 'Enter a valid Gmail sender address.'
}
if (-not $PSCmdlet.ShouldProcess('Windows System environment', 'Configure Gmail recovery email')) {
    return
}

$identity = [System.Security.Principal.WindowsIdentity]::GetCurrent()
$principal = New-Object System.Security.Principal.WindowsPrincipal($identity)
if (-not $principal.IsInRole([System.Security.Principal.WindowsBuiltInRole]::Administrator)) {
    throw 'Run this setup command in Administrator PowerShell on the server.'
}

$securePassword = Read-Host 'Paste the Google app password (input is hidden)' -AsSecureString
$passwordPointer = [IntPtr]::Zero
$appPassword = $null
$previousAddress = [Environment]::GetEnvironmentVariable('OTHERGODS_GMAIL_ADDRESS', 'Machine')
$previousPassword = [Environment]::GetEnvironmentVariable('OTHERGODS_GMAIL_APP_PASSWORD', 'Machine')
try {
    $passwordPointer = [Runtime.InteropServices.Marshal]::SecureStringToBSTR($securePassword)
    $appPassword = [Runtime.InteropServices.Marshal]::PtrToStringBSTR($passwordPointer).Replace(' ', '').Trim()
    if ($appPassword -cnotmatch '^[A-Za-z0-9]{16}$') {
        throw 'Use the 16-character Google app password, not the Google account password.'
    }
    try {
        [Environment]::SetEnvironmentVariable('OTHERGODS_GMAIL_ADDRESS', $Address, 'Machine')
        [Environment]::SetEnvironmentVariable('OTHERGODS_GMAIL_APP_PASSWORD', $appPassword, 'Machine')
    } catch {
        [Environment]::SetEnvironmentVariable('OTHERGODS_GMAIL_ADDRESS', $previousAddress, 'Machine')
        [Environment]::SetEnvironmentVariable('OTHERGODS_GMAIL_APP_PASSWORD', $previousPassword, 'Machine')
        throw 'Could not save Gmail recovery settings.'
    }
    Write-Host 'Gmail recovery settings saved on this server.'
    Write-Host 'The next lobby restart or server update will apply them. No Windows reboot is required.'
} finally {
    if ($passwordPointer -ne [IntPtr]::Zero) {
        [Runtime.InteropServices.Marshal]::ZeroFreeBSTR($passwordPointer)
    }
    $securePassword.Dispose()
    $appPassword = $null
    $previousPassword = $null
}
