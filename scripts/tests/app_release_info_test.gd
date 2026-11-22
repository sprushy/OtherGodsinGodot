extends SceneTree

const ReleaseInfo = preload("res://scripts/client/AppReleaseInfo.gd")
const MacUpdater = preload("res://scripts/client/MacOSSelfUpdater.gd")

func _init() -> void:
	assert(ReleaseInfo.compare_versions("v0.2.318", "v0.2.324") < 0)
	assert(ReleaseInfo.compare_versions("v0.2.324", "v0.2.318") > 0)
	assert(ReleaseInfo.compare_versions("0.2.324", "v0.2.324") == 0)
	assert(MacUpdater.get_app_bundle_path("/Applications/Other Gods.app/Contents/MacOS/Other Gods") == "/Applications/Other Gods.app")
	assert(MacUpdater.get_app_bundle_path("/Applications/Other Gods.app/Contents/Helpers/Helper.app/Contents/MacOS/Helper") == "/Applications/Other Gods.app/Contents/Helpers/Helper.app")
	assert(MacUpdater.get_app_bundle_path("C:/Godot/godot.exe").is_empty())
	var output: Array = []
	var result := OS.execute("git", ["-C", ProjectSettings.globalize_path("res://"), "describe", "--tags", "--match", "v[0-9]*", "--abbrev=0"], output)
	if OS.has_feature("editor") and result == 0:
		assert(ReleaseInfo.get_current_version() == str(output[0]).strip_edges())
	assert(ReleaseInfo.get_display_version().ends_with(" (debug)"))
	print("PASS: release version, editor checkout version, and macOS bundle paths")
	quit()
