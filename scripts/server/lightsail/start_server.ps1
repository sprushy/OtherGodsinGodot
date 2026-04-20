$ErrorActionPreference = "Stop"
$Root = "C:\OtherGodsServer"
$Exe  = Join-Path $Root "ClaudeOtherGodsServer.exe"
$Log  = Join-Path $Root "updater.log"

function Write-Log($m) {
    Add-Content -LiteralPath $Log -Value ("{0} {1}" -f (Get-Date -Format 'yyyy-MM-dd HH:mm:ss'), $m)
}

if (Get-Process -Name ClaudeOtherGodsServer -ErrorAction SilentlyContinue) {
    Write-Log "Startup: server already running, nothing to do."
    return
}

if (-not (Test-Path -LiteralPath $Exe)) {
    Write-Log "Startup: exe missing at $Exe"
    throw "Server executable not found at $Exe"
}

Start-Process -FilePath $Exe -WorkingDirectory $Root
Write-Log "Startup: launched server."
