extends RefCounted
class_name ServerPaths

const DEDICATED_SERVER_EXECUTABLE_NAMES := [
	"claudeothergodsserver.exe",
	"claudeothergodsserver_console.exe",
]

static func get_server_root_dir() -> String:
	if _should_use_portable_server_root():
		var executable_path: String = OS.get_executable_path().strip_edges()
		if not executable_path.is_empty():
			return executable_path.get_base_dir().path_join("server_runtime")
	return ProjectSettings.globalize_path("user://")

static func get_server_data_file_path(file_name: String) -> String:
	return get_server_root_dir().path_join("server_data").path_join(file_name.strip_edges())

static func get_dedicated_matches_dir() -> String:
	return get_server_root_dir().path_join("dedicated_matches")

static func _should_use_portable_server_root() -> bool:
	if OS.has_feature("dedicated_server"):
		return true
	var executable_path: String = OS.get_executable_path().strip_edges().to_lower()
	for executable_name in DEDICATED_SERVER_EXECUTABLE_NAMES:
		if executable_path.ends_with(executable_name):
			return true
	return false
