function Get-GodotProjectRoot {
    $projectRoot = Resolve-Path (Join-Path $PSScriptRoot '..\..')
    return $projectRoot.Path
}

function Resolve-GodotExecutable {
    param(
        [string]$PreferredPath = ''
    )

    $candidates = @()

    if (-not [string]::IsNullOrWhiteSpace($PreferredPath)) {
        $candidates += $PreferredPath
    }
    if (-not [string]::IsNullOrWhiteSpace($env:GODOT_EXE)) {
        $candidates += $env:GODOT_EXE
    }

    $homeGodot = Join-Path $HOME 'bin\godot.exe'
    $candidates += $homeGodot

    try {
        $command = Get-Command godot.exe -ErrorAction Stop
        if ($command -and $command.Source) {
            $candidates += $command.Source
        }
    } catch {
    }

    $downloadRoots = @(
        (Join-Path $HOME 'Downloads'),
        (Join-Path $HOME 'bin')
    )
    foreach ($root in $downloadRoots) {
        if (-not (Test-Path $root)) {
            continue
        }
        try {
            $candidates += Get-ChildItem -Path $root -Recurse -File -Filter 'godot*.exe' -ErrorAction SilentlyContinue |
                Select-Object -ExpandProperty FullName
            $candidates += Get-ChildItem -Path $root -Recurse -File -Filter 'Godot*.exe' -ErrorAction SilentlyContinue |
                Select-Object -ExpandProperty FullName
        } catch {
        }
    }

    $resolved = @()
    foreach ($candidate in $candidates) {
        if ([string]::IsNullOrWhiteSpace($candidate)) {
            continue
        }
        if (-not (Test-Path $candidate)) {
            continue
        }
        $resolved += (Resolve-Path $candidate).Path
    }
    $resolved = $resolved | Select-Object -Unique

    $expectedVersion = ''
    try {
        $projectRoot = Get-GodotProjectRoot
        $versionFile = Join-Path $projectRoot '.godot-version'
        if (Test-Path -LiteralPath $versionFile) {
            $expectedVersion = (Get-Content -LiteralPath $versionFile -Raw).Trim()
        }
    } catch {
    }

    $matchingExpectedVersion = @()
    $preferred = @()
    foreach ($path in $resolved) {
        $versionText = ''
        try {
            $versionText = (& $path --version 2>&1 | Out-String)
        } catch {
        }
        if ($path -match 'mono' -or $versionText -match 'mono') {
            continue
        }
        if (-not [string]::IsNullOrWhiteSpace($expectedVersion) -and $versionText -match [regex]::Escape($expectedVersion)) {
            $matchingExpectedVersion += $path
            continue
        }
        $preferred += $path
    }
    if ($matchingExpectedVersion.Count -gt 0) {
        return $matchingExpectedVersion[0]
    }
    if ($preferred.Count -gt 0) {
        return $preferred[0]
    }
    if ($resolved.Count -gt 0) {
        return $resolved[0]
    }

    throw 'Could not find a Godot executable. Set $env:GODOT_EXE or install a non-Mono godot.exe.'
}

function Set-GodotPortableEnvironment {
    param(
        [string]$ProjectRoot
    )

    if ([string]::IsNullOrWhiteSpace($ProjectRoot)) {
        throw 'ProjectRoot is required.'
    }

    $portableRoot = Join-Path $ProjectRoot '.godot_portable'
    $roamingRoot = Join-Path $portableRoot 'Roaming'
    $localRoot = Join-Path $portableRoot 'Local'
    $godotRoaming = Join-Path $roamingRoot 'Godot'
    $godotLocal = Join-Path $localRoot 'Godot'

    foreach ($path in @($portableRoot, $roamingRoot, $localRoot, $godotRoaming, $godotLocal)) {
        if (-not (Test-Path $path)) {
            New-Item -ItemType Directory -Path $path -Force | Out-Null
        }
    }

    $env:APPDATA = $roamingRoot
    $env:LOCALAPPDATA = $localRoot
    $env:GODOT_MCP_DISABLED = '1'

    return @{
        PortableRoot = $portableRoot
        AppData = $roamingRoot
        LocalAppData = $localRoot
    }
}
