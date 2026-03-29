extends SceneTree

const HeadlessMatchServerScript = preload("res://scripts/server/HeadlessMatchServer.gd")

var _server = null

func _initialize() -> void:
	var launch_args: Dictionary = _parse_user_args(OS.get_cmdline_user_args())
	var config_path: String = str(launch_args.get("match_config", "")).strip_edges()
	if config_path.is_empty():
		push_error("HeadlessMatchServerMain: missing match_config launch argument")
		quit(1)
		return

	var config: Dictionary = _load_launch_config(config_path)
	if config.is_empty():
		push_error("HeadlessMatchServerMain: failed to load launch config %s" % config_path)
		quit(1)
		return

	call_deferred("_boot_server", config)

func _boot_server(config: Dictionary) -> void:
	_server = HeadlessMatchServerScript.new()
	get_root().add_child(_server)
	_server.startup_failed.connect(_on_server_startup_failed)

	var start_err: Error = _server.start_from_config(config)
	if start_err != OK:
		push_error("HeadlessMatchServerMain: dedicated server failed to start (%s)" % error_string(start_err))
		quit(1)
		return

	print("HeadlessMatchServerMain: listening for %s on port %d" % [
		str(config.get("match_id", "")),
		int(config.get("match_port", 0)),
	])

func _on_server_startup_failed(message: String) -> void:
	push_error("HeadlessMatchServerMain: %s" % message)
	quit(1)

func _parse_user_args(args: PackedStringArray) -> Dictionary:
	var parsed: Dictionary = {}
	for arg in args:
		var parts := String(arg).split("=", false, 1)
		if parts.size() != 2:
			continue
		parsed[str(parts[0]).strip_edges()] = str(parts[1]).strip_edges()
	return parsed

func _load_launch_config(config_path: String) -> Dictionary:
	if not FileAccess.file_exists(config_path):
		return {}
	var file := FileAccess.open(config_path, FileAccess.READ)
	if file == null:
		return {}
	var parsed = JSON.parse_string(file.get_as_text())
	if parsed is Dictionary:
		return parsed
	return {}
