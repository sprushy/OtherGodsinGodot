extends RefCounted

const SCRIPT_PATH := "res://scripts/client/macos_self_update.sh"
const PREPARE_TIMEOUT_SECONDS := 900.0

static func get_app_bundle_path(executable_path: String) -> String:
	var marker := executable_path.rfind(".app/Contents/MacOS/")
	if marker < 0:
		return ""
	return executable_path.substr(0, marker + 4)

# The install folder is expensive to discover only after a ~1 GB download, so
# report the same placement problems the shell helper enforces before it starts.
static func get_placement_error() -> String:
	var target := get_app_bundle_path(OS.get_executable_path())
	if target.is_empty():
		return "Could not locate the installed Other Gods app bundle."
	if not target.ends_with(".app"):
		return "Could not locate the installed Other Gods app bundle."
	if target.contains("/AppTranslocation/"):
		return "Move Other Gods to Applications and reopen it before updating."
	if not FileAccess.file_exists(target.path_join("Contents/Info.plist")):
		return "The installed app bundle is incomplete."
	var parent := target.get_base_dir()
	var probe := parent.path_join(
		".othergods-update-preflight-%d-%d" % [OS.get_process_id(), Time.get_ticks_msec()]
	)
	var make_dir_error := DirAccess.make_dir_recursive_absolute(probe)
	if make_dir_error != OK:
		return "Cannot update this folder. Move Other Gods to a writable Applications folder and reopen it."
	DirAccess.remove_absolute(probe)
	return ""

static func _stage_message(stage: String) -> String:
	match stage:
		"unpacking":
			return "Unpacking the macOS update...\nOther Gods will restart automatically."
		"verifying":
			return "Verifying the unpacked macOS update...\nOther Gods will restart automatically."
	return "Preparing and verifying the macOS update...\nOther Gods will restart automatically."

# The helper stages and verifies the signed bundle while Godot stays open.
# It replaces the app only after the caller receives "ready" and quits.
static func install(tree: SceneTree, archive_path: String, version: String, report: Callable) -> String:
	var target := get_app_bundle_path(OS.get_executable_path())
	if target.is_empty():
		return "Could not locate the installed Other Gods app bundle."
	var user_dir := OS.get_user_data_dir()
	var script_path := user_dir.path_join("macos_self_update.sh")
	var status_path := user_dir.path_join("macos_update_status.txt")
	var failure_path := user_dir.path_join("update_failure.txt")
	DirAccess.remove_absolute(status_path)
	DirAccess.remove_absolute(failure_path)
	var source := FileAccess.get_file_as_string(SCRIPT_PATH)
	if source.is_empty():
		return "The macOS updater is missing from this build."
	var script := FileAccess.open(script_path, FileAccess.WRITE)
	if script == null:
		return "Could not prepare the macOS updater. Check the app's folder permissions."
	script.store_string(source.replace("\r\n", "\n"))
	script.close()
	var pid := OS.create_process("/bin/sh", PackedStringArray([
		script_path, archive_path, target, version, str(OS.get_process_id()),
		status_path, failure_path, user_dir.path_join("update.log"),
	]), false)
	if pid <= 0:
		return "macOS could not start the automatic updater."
	report.call("Preparing and verifying the macOS update...\nOther Gods will restart automatically.")
	var last_stage := ""
	var deadline := Time.get_ticks_msec() + int(PREPARE_TIMEOUT_SECONDS * 1000.0)
	while Time.get_ticks_msec() < deadline:
		if FileAccess.file_exists(status_path):
			var status := FileAccess.get_file_as_string(status_path).strip_edges()
			if status == "ready":
				report.call("Installing update...\nOther Gods will close and reopen automatically.")
				await tree.process_frame
				tree.quit()
				return ""
			if status.begins_with("stage:"):
				var stage := status.trim_prefix("stage:")
				if stage != last_stage:
					last_stage = stage
					report.call(_stage_message(stage))
			if status.begins_with("error:"):
				DirAccess.remove_absolute(failure_path)
				return status.trim_prefix("error:")
		if not OS.is_process_running(pid):
			return "The macOS updater stopped before installation. Open Update Log Folder for details."
		await tree.create_timer(0.1).timeout
	OS.kill(pid)
	return "Preparing the macOS update took too long. Try again or open the download page."
