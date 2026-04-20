$ErrorActionPreference = "Stop"
$Root = "C:\OtherGodsServer"
$ExeCandidates = @(
    (Join-Path $Root "OtherGodsServer.exe"),
    (Join-Path $Root "ClaudeOtherGodsServer.exe")
)
$Exe = $ExeCandidates | Where-Object { Test-Path -LiteralPath $_ } | Select-Object -First 1
if (-not $Exe) {
    $Exe = $ExeCandidates[0]
}
$Log  = Join-Path $Root "updater.log"

function Write-Log($m) {
    Add-Content -LiteralPath $Log -Value ("{0} {1}" -f (Get-Date -Format 'yyyy-MM-dd HH:mm:ss'), $m)
}

if ((Get-Process -Name OtherGodsServer -ErrorAction SilentlyContinue) -or (Get-Process -Name ClaudeOtherGodsServer -ErrorAction SilentlyContinue)) {
    Write-Log "Startup: server already running, nothing to do."
    return
}

if (-not (Test-Path -LiteralPath $Exe)) {
    Write-Log "Startup: exe missing at $Exe"
    throw "Server executable not found at $Exe"
}

Start-Process -FilePath $Exe -WorkingDirectory $Root
Write-Log "Startup: launched server."
