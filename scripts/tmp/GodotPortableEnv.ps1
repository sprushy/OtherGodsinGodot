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
