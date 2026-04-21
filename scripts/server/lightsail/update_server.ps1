$ErrorActionPreference = "Stop"
$Root = "C:\OtherGodsServer"
$PreferredExe = Join-Path $Root "OtherGodsServer.exe"
$LegacyExe = Join-Path $Root "ClaudeOtherGodsServer.exe"
$Exe  = if (Test-Path -LiteralPath $PreferredExe) { $PreferredExe } elseif (Test-Path -LiteralPath $LegacyExe) { $LegacyExe } else { $PreferredExe }
$Zip  = Join-Path $Root "OtherGodsServer-windows.zip"
$VersionFile = Join-Path $Root "release_version.txt"
$Log  = Join-Path $Root "updater.log"

function Write-Log($m) {
    Add-Content -LiteralPath $Log -Value ("{0} {1}" -f (Get-Date -Format 'yyyy-MM-dd HH:mm:ss'), $m)
}

try {
    $headers = @{ "User-Agent" = "OtherGodsUpdater" }
    $release = Invoke-RestMethod -Headers $headers -Uri "https://api.github.com/repos/sprushy/OtherGodsinGodot/releases/latest"
    $latest = [string]$release.tag_name
    $asset = $null
    foreach ($assetNameCandidate in @("OtherGodsServer-windows.zip", "ClaudeOtherGodsServer-windows.zip")) {
        $asset = @($release.assets) | Where-Object { $_.name -eq $assetNameCandidate } | Select-Object -First 1
        if ($null -ne $asset) {
            break
        }
    }
    if ($null -eq $asset) { throw "No compatible Windows server asset found in the latest release." }

    $current = if (Test-Path -LiteralPath $VersionFile) { (Get-Content -LiteralPath $VersionFile -Raw).Trim() } else { "" }

    if ($current -eq $latest) { Write-Log "Already on $current."; return }

    Write-Log "Updating from '$current' to '$latest'"
    Stop-Process -Name OtherGodsServer -Force -ErrorAction SilentlyContinue
    Stop-Process -Name ClaudeOtherGodsServer -Force -ErrorAction SilentlyContinue
    Start-Sleep -Seconds 2
    Remove-Item -LiteralPath $Zip -Force -ErrorAction SilentlyContinue

    $ProgressPreference = 'SilentlyContinue'
    Invoke-WebRequest -Uri $asset.browser_download_url -OutFile $Zip -UseBasicParsing

    Expand-Archive -LiteralPath $Zip -DestinationPath $Root -Force
    if ((Test-Path -LiteralPath $LegacyExe) -and -not (Test-Path -LiteralPath $PreferredExe)) {
        Move-Item -LiteralPath $LegacyExe -Destination $PreferredExe -Force
    }
    $LegacyConsole = Join-Path $Root "ClaudeOtherGodsServer_console.exe"
    $PreferredConsole = Join-Path $Root "OtherGodsServer_console.exe"
    if ((Test-Path -LiteralPath $LegacyConsole) -and -not (Test-Path -LiteralPath $PreferredConsole)) {
        Move-Item -LiteralPath $LegacyConsole -Destination $PreferredConsole -Force
    }
    $LegacyPck = Join-Path $Root "ClaudeOtherGodsServer.pck"
    $PreferredPck = Join-Path $Root "OtherGodsServer.pck"
    if ((Test-Path -LiteralPath $LegacyPck) -and -not (Test-Path -LiteralPath $PreferredPck)) {
        Move-Item -LiteralPath $LegacyPck -Destination $PreferredPck -Force
    }
    $Exe = if (Test-Path -LiteralPath $PreferredExe) { $PreferredExe } elseif (Test-Path -LiteralPath $LegacyExe) { $LegacyExe } else { $PreferredExe }
    if ((Test-Path -LiteralPath $LegacyExe) -and $Exe -eq $PreferredExe) {
        Remove-Item -LiteralPath $LegacyExe -Force -ErrorAction SilentlyContinue
    }
    if ((Test-Path -LiteralPath $LegacyPck) -and (Test-Path -LiteralPath (Join-Path $Root "OtherGodsServer.pck"))) {
        Remove-Item -LiteralPath $LegacyPck -Force -ErrorAction SilentlyContinue
    }
    Start-Process -FilePath $Exe -WorkingDirectory $Root
    Set-Content -LiteralPath $VersionFile -Value $latest -NoNewline
    Write-Log "Updated to $latest and restarted."
} catch {
    Write-Log "ERROR: $($_.Exception.Message)"
    throw
}
