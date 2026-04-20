$ErrorActionPreference = "Stop"
$Root = "C:\OtherGodsServer"
$Exe  = Join-Path $Root "ClaudeOtherGodsServer.exe"
$Zip  = Join-Path $Root "ClaudeOtherGodsServer-windows.zip"
$VersionFile = Join-Path $Root "release_version.txt"
$Log  = Join-Path $Root "updater.log"

function Write-Log($m) {
    Add-Content -LiteralPath $Log -Value ("{0} {1}" -f (Get-Date -Format 'yyyy-MM-dd HH:mm:ss'), $m)
}

try {
    $headers = @{ "User-Agent" = "OtherGodsUpdater" }
    $release = Invoke-RestMethod -Headers $headers -Uri "https://api.github.com/repos/sprushy/OtherGodsinGodot/releases/latest"
    $latest = [string]$release.tag_name

    $current = if (Test-Path -LiteralPath $VersionFile) { (Get-Content -LiteralPath $VersionFile -Raw).Trim() } else { "" }

    if ($current -eq $latest) { Write-Log "Already on $current."; return }

    Write-Log "Updating from '$current' to '$latest'"
    Stop-Process -Name ClaudeOtherGodsServer -Force -ErrorAction SilentlyContinue
    Start-Sleep -Seconds 2
    Remove-Item -LiteralPath $Zip -Force -ErrorAction SilentlyContinue

    & curl.exe -L "https://github.com/sprushy/OtherGodsinGodot/releases/latest/download/ClaudeOtherGodsServer-windows.zip" -o $Zip
    if ($LASTEXITCODE -ne 0) { throw "curl failed: $LASTEXITCODE" }

    Expand-Archive -LiteralPath $Zip -DestinationPath $Root -Force
    Start-Process -FilePath $Exe -WorkingDirectory $Root
    Set-Content -LiteralPath $VersionFile -Value $latest -NoNewline
    Write-Log "Updated to $latest and restarted."
} catch {
    Write-Log "ERROR: $($_.Exception.Message)"
    throw
}
