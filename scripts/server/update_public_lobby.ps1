param(
    [switch]$Force,
    [string]$ReleaseTag = "",
    [string]$RepoOwner = "sprushy",
    [string]$RepoName = "OtherGodsinGodot",
    [string]$AssetName = "OtherGodsServer-windows.zip"
)

$ErrorActionPreference = "Stop"

$RepoRoot = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
$ServerDir = Join-Path $RepoRoot ".exports\server"
$PreferredServerExeName = "OtherGodsServer.exe"
$LegacyServerExeNames = @("ClaudeOtherGodsServer.exe")
$PreferredAssetNames = @($AssetName, "ClaudeOtherGodsServer-windows.zip")
$ServerExe = Join-Path $ServerDir $PreferredServerExeName
$LegacyServerExePaths = @()
foreach ($legacyName in $LegacyServerExeNames) {
    $LegacyServerExePaths += Join-Path $ServerDir $legacyName
}
$VersionFile = Join-Path $ServerDir "release_version.txt"
$StartScript = Join-Path $PSScriptRoot "start_public_lobby.ps1"
$LogDir = Join-Path $RepoRoot "scripts\tmp"
$LogFile = Join-Path $LogDir "public_lobby_updater.log"
$ReleaseApiUrl = if ($ReleaseTag.Trim()) {
    "https://api.github.com/repos/$RepoOwner/$RepoName/releases/tags/$ReleaseTag"
} else {
    "https://api.github.com/repos/$RepoOwner/$RepoName/releases/latest"
}

New-Item -ItemType Directory -Force -Path $ServerDir | Out-Null
New-Item -ItemType Directory -Force -Path $LogDir | Out-Null

function Write-Log {
    param(
        [string]$Message
    )

    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $line = "$timestamp $Message"
    Add-Content -LiteralPath $LogFile -Value $line
    Write-Host $line
}

function Normalize-Version {
    param(
        [string]$Value
    )

    $normalized = $Value.Trim()
    if (-not $normalized) {
        return ""
    }
    if ($normalized.StartsWith("refs/tags/")) {
        $normalized = $normalized.Substring(10)
    }
    if ($normalized -notmatch '^[vV]' -and $normalized -match '^\d+(\.\d+)*$') {
        $normalized = "v$normalized"
    }
    return $normalized.ToLowerInvariant()
}

function Get-VersionParts {
    param(
        [string]$Version
    )

    $normalized = Normalize-Version $Version
    if (-not $normalized) {
        return @()
    }

    if ($normalized.StartsWith("v")) {
        $normalized = $normalized.Substring(1)
    }

    $segments = $normalized.Split('.', [System.StringSplitOptions]::RemoveEmptyEntries)
    $parts = @()
    foreach ($segment in $segments) {
        if ($segment -notmatch '^\d+$') {
            return @()
        }
        $parts += [int]$segment
    }
    return $parts
}

function Compare-Version {
    param(
        [string]$Left,
        [string]$Right
    )

    $leftParts = Get-VersionParts $Left
    $rightParts = Get-VersionParts $Right
    $maxCount = [Math]::Max($leftParts.Count, $rightParts.Count)
    for ($index = 0; $index -lt $maxCount; $index++) {
        $leftValue = if ($index -lt $leftParts.Count) { $leftParts[$index] } else { 0 }
        $rightValue = if ($index -lt $rightParts.Count) { $rightParts[$index] } else { 0 }
        if ($leftValue -lt $rightValue) {
            return -1
        }
        if ($leftValue -gt $rightValue) {
            return 1
        }
    }
    return 0
}

function Get-Existing-ServerExePath {
    $candidates = @($ServerExe) + $LegacyServerExePaths
    foreach ($candidate in $candidates) {
        if (Test-Path -LiteralPath $candidate) {
            return $candidate
        }
    }
    return ""
}

function Get-Current-Version {
    if (Test-Path -LiteralPath $VersionFile) {
        return Normalize-Version ((Get-Content -LiteralPath $VersionFile -Raw).Trim())
    }

    $existingServerExe = Get-Existing-ServerExePath
    if ($existingServerExe) {
        $versionInfo = [System.Diagnostics.FileVersionInfo]::GetVersionInfo($existingServerExe)
        if ($versionInfo.ProductVersion) {
            return Normalize-Version $versionInfo.ProductVersion
        }
        if ($versionInfo.FileVersion) {
            return Normalize-Version $versionInfo.FileVersion
        }
    }

    return ""
}

$mutex = New-Object System.Threading.Mutex($false, "Global\OtherGodsPublicLobbyUpdater")
$acquiredMutex = $false
try {
    $acquiredMutex = $mutex.WaitOne(0)
} catch [System.Threading.AbandonedMutexException] {
    # Previous run was killed without releasing; we now own it.
    $acquiredMutex = $true
}
if (-not $acquiredMutex) {
    Write-Log "Another updater instance is already running."
    return
}

$tempRoot = $null
try {
    $headers = @{
        "User-Agent" = "OtherGodsPublicLobbyUpdater"
        "Accept" = "application/vnd.github+json"
    }

    Write-Log "Checking $ReleaseApiUrl"
    $release = Invoke-RestMethod -Headers $headers -Uri $ReleaseApiUrl
    $latestVersion = Normalize-Version ([string]$release.tag_name)
    if (-not $latestVersion) {
        throw "Release response did not include a usable tag name."
    }

    $currentVersion = Get-Current-Version
    if (-not $Force -and $currentVersion) {
        $comparison = Compare-Version $currentVersion $latestVersion
        if ($comparison -ge 0) {
            Write-Log "Already on $currentVersion. No update needed."
            return
        }
    }

    $asset = $null
    foreach ($assetNameCandidate in $PreferredAssetNames) {
        $asset = @($release.assets) | Where-Object { $_.name -eq $assetNameCandidate } | Select-Object -First 1
        if ($null -ne $asset) {
            break
        }
    }
    if ($null -eq $asset) {
        throw "Release $latestVersion does not contain a supported Windows server asset."
    }

    $tempRoot = Join-Path $env:TEMP ("OtherGodsServerUpdate-" + [guid]::NewGuid().ToString("N"))
    $zipPath = Join-Path $tempRoot $asset.name
    $extractDir = Join-Path $tempRoot "expanded"
    New-Item -ItemType Directory -Force -Path $tempRoot | Out-Null
    New-Item -ItemType Directory -Force -Path $extractDir | Out-Null

    Write-Log "Downloading $($asset.browser_download_url)"
    Invoke-WebRequest -Headers $headers -Uri $asset.browser_download_url -OutFile $zipPath
    Expand-Archive -LiteralPath $zipPath -DestinationPath $extractDir -Force

    $downloadedExe = Get-ChildItem -LiteralPath $extractDir -Recurse -File |
        Where-Object { $_.Name -in @("OtherGodsServer.exe", "ClaudeOtherGodsServer.exe") } |
        Select-Object -ExpandProperty FullName -First 1
    if (-not $downloadedExe) {
        throw "Downloaded archive did not contain a supported server executable."
    }

    $downloadedExeDir = Split-Path -Parent $downloadedExe
    $downloadedExeName = Split-Path -Leaf $downloadedExe
    if ($downloadedExeName -ne $PreferredServerExeName) {
        $renamedExePath = Join-Path $downloadedExeDir $PreferredServerExeName
        Move-Item -LiteralPath $downloadedExe -Destination $renamedExePath -Force
        $downloadedExe = $renamedExePath
    }

    $legacyDownloadedPck = Join-Path $downloadedExeDir "ClaudeOtherGodsServer.pck"
    $preferredDownloadedPck = Join-Path $downloadedExeDir "OtherGodsServer.pck"
    if ((Test-Path -LiteralPath $legacyDownloadedPck) -and -not (Test-Path -LiteralPath $preferredDownloadedPck)) {
        Move-Item -LiteralPath $legacyDownloadedPck -Destination $preferredDownloadedPck -Force
    }

    $legacyDownloadedConsole = Join-Path $downloadedExeDir "ClaudeOtherGodsServer_console.exe"
    $preferredDownloadedConsole = Join-Path $downloadedExeDir "OtherGodsServer_console.exe"
    if ((Test-Path -LiteralPath $legacyDownloadedConsole) -and -not (Test-Path -LiteralPath $preferredDownloadedConsole)) {
        Move-Item -LiteralPath $legacyDownloadedConsole -Destination $preferredDownloadedConsole -Force
    }

    Write-Log "Stopping current public lobby server"
    & $StartScript -StopOnly

    Write-Log "Installing server build $latestVersion"
    $maxAttempts = 5
    for ($attempt = 1; $attempt -le $maxAttempts; $attempt++) {
        try {
            Copy-Item -Path (Join-Path $downloadedExeDir "*") -Destination $ServerDir -Recurse -Force
            break
        } catch {
            if ($attempt -eq $maxAttempts) { throw }
            Write-Log "Build still locked, retrying in 2s (attempt $attempt of $maxAttempts)"
            Start-Sleep -Seconds 2
        }
    }

    foreach ($legacyExePath in $LegacyServerExePaths) {
        if (Test-Path -LiteralPath $legacyExePath) {
            Remove-Item -LiteralPath $legacyExePath -Force -ErrorAction SilentlyContinue
        }
    }
    $legacyPckPath = Join-Path $ServerDir "ClaudeOtherGodsServer.pck"
    if (Test-Path -LiteralPath $legacyPckPath) {
        Remove-Item -LiteralPath $legacyPckPath -Force -ErrorAction SilentlyContinue
    }
    $legacyConsolePath = Join-Path $ServerDir "ClaudeOtherGodsServer_console.exe"
    if (Test-Path -LiteralPath $legacyConsolePath) {
        Remove-Item -LiteralPath $legacyConsolePath -Force -ErrorAction SilentlyContinue
    }

    Set-Content -LiteralPath $VersionFile -Value $latestVersion -NoNewline

    Write-Log "Restarting public lobby server"
    & $StartScript

    Write-Log "Updated public lobby server from $currentVersion to $latestVersion"
} catch {
    Write-Log "Update failed: $($_.Exception.Message)"
    throw
} finally {
    if ($tempRoot -and (Test-Path -LiteralPath $tempRoot)) {
        Remove-Item -LiteralPath $tempRoot -Recurse -Force
    }
    if ($acquiredMutex) {
        $mutex.ReleaseMutex() | Out-Null
    }
    $mutex.Dispose()
}
