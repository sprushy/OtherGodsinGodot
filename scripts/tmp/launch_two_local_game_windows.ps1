$tmp = $PSScriptRoot
. (Join-Path $tmp 'GodotPortableEnv.ps1')
$project = Get-GodotProjectRoot
$godot = Resolve-GodotExecutable
$null = Set-GodotPortableEnvironment -ProjectRoot $project

Start-Process -FilePath $godot -ArgumentList @('--path', $project)
Start-Sleep -Milliseconds 750
Start-Process -FilePath $godot -ArgumentList @('--path', $project)
