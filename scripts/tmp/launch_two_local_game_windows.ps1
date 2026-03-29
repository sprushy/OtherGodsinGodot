$godot = 'C:\Users\spaul\Downloads\Godot_v4.6.1-stable_win64.exe\Godot_v4.6.1-stable_win64.exe'
$project = 'C:\Users\spaul\Documents\other-godsin-godot-main'
. (Join-Path $project 'scripts\tmp\GodotPortableEnv.ps1')
$null = Set-GodotPortableEnvironment -ProjectRoot $project

Start-Process -FilePath $godot -ArgumentList @('--path', $project)
Start-Sleep -Milliseconds 750
Start-Process -FilePath $godot -ArgumentList @('--path', $project)
