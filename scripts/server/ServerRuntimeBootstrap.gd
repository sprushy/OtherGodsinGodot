extends Node2D

const LobbyServerScript = preload("res://scripts/server/LobbyServer.gd")
const HeadlessMatchServerScript = preload("res://scripts/server/HeadlessMatchServer.gd")
const JsonStoreScript = preload("res://scripts/server/JsonStore.gd")
const DEFAULT_LOBBY_HOST_SETTING := "application/config/default_lobby_host"

var _server_node: Node = null
var _launch_args: Dictionary = {}

func _ready() -> void:
	_launch_args = _parse_user_args(OS.get_cmdline_user_args())
	if not _should_boot_server_runtime(_launch_args):
		return
	call_deferred("_boot_server_runtime")

func _boot_server_runtime() -> void:
	var control := get_node_or_null("Control")
	if control != null:
		control.visible = false

	if str(_launch_args.get("match_config", "")).strip_edges() != "":
		_boot_match_runtime(_launch_args)
		return

	_boot_lobby_runtime(_launch_args)

func _boot_lobby_runtime(launch_args: Dictionary) -> void:
	var configured_default_host: String = str(ProjectSettings.get_setting(DEFAULT_LOBBY_HOST_SETTING, "")).strip_edges()
	var advertised_host: String = str(launch_args.get("lobby_host", configured_default_host)).strip_edges()
	if advertised_host.is_empty():
		advertised_host = "127.0.0.1"
	var lobby_port: int = int(launch_args.get("lobby_port", 22345))
	var match_port: int = int(launch_args.get("match_port", 12345))
	var ready_file_path: String = str(launch_args.get("ready_file", "")).strip_edges()
	var trace_file_path: String = str(launch_args.get("trace_file", "")).strip_edges()

	var lobby_server = LobbyServerScript.new()
	lobby_server.name = "LobbyPeer"
	lobby_server.use_dedicated_match_processes = true
	lobby_server.allow_in_process_match_fallback = false
	lobby_server.use_default_multiplayer = true
	lobby_server.trace_file_path = trace_file_path
	var lobby_parent := _resolve_lobby_runtime_parent()
	lobby_parent.add_child(lobby_server)
	_server_node = lobby_server

	lobby_server.status_changed.connect(func(message: String) -> void:
		print("ServerRuntimeBootstrap[lobby]: %s" % message)
	)

	var err: Error = lobby_server.start_server(advertised_host, lobby_port, match_port)
	if err != OK:
		push_error("ServerRuntimeBootstrap: failed to start dedicated lobby server (%s)" % error_string(err))
		get_tree().quit(1)
		return

	print("ServerRuntimeBootstrap: dedicated lobby ready on %s:%d" % [advertised_host, lobby_port])
	_write_ready_file(ready_file_path)

func _resolve_lobby_runtime_parent() -> Node:
	var parent_node := get_parent()
	if parent_node != null and parent_node.name == "Main3D":
		return parent_node
	var tree := get_tree()
	if tree == null:
		return self
	var root := tree.get_root()
	if root == null:
		return self
	var existing_main_3d := root.get_node_or_null("Main3D")
	if existing_main_3d != null:
		return existing_main_3d
	var main_3d_mount := Node.new()
	main_3d_mount.name = "Main3D"
	root.add_child(main_3d_mount)
	return main_3d_mount

func _boot_match_runtime(launch_args: Dictionary) -> void:
	var config_path: String = str(launch_args.get("match_config", "")).strip_edges()
	var config: Dictionary = _load_launch_config(config_path)
	if config.is_empty():
		push_error("ServerRuntimeBootstrap: failed to load match config %s" % config_path)
		get_tree().quit(1)
		return
	config["_launch_config_path"] = config_path

	var match_server = HeadlessMatchServerScript.new()
	match_server.name = "HeadlessMatchServer"
	add_child(match_server)
	_server_node = match_server
	match_server.startup_failed.connect(func(message: String) -> void:
		push_error("ServerRuntimeBootstrap[match]: %s" % message)
		get_tree().quit(1)
	)

	var start_err: Error = match_server.start_from_config(config)
	if start_err != OK:
		push_error("ServerRuntimeBootstrap: dedicated match failed to start (%s)" % error_string(start_err))
		get_tree().quit(1)
		return

	print("ServerRuntimeBootstrap: dedicated match ready for %s on port %d" % [
		str(config.get("match_id", "")),
		int(config.get("match_port", 0)),
	])

func _should_boot_server_runtime(launch_args: Dictionary) -> bool:
	if str(launch_args.get("match_config", "")).strip_edges() != "":
		return true
	var requested_mode: String = str(launch_args.get("server_mode", "")).strip_edges().to_lower()
	if requested_mode == "lobby":
		return true
	return OS.has_feature("dedicated_server")

func _write_ready_file(ready_file_path: String) -> void:
	if ready_file_path.is_empty():
		return
	var file := FileAccess.open(ready_file_path, FileAccess.WRITE)
	if file == null:
		return
	file.store_string("READY")
	file.flush()
	file.close()

func _parse_user_args(args: PackedStringArray) -> Dictionary:
	var parsed: Dictionary = {}
	for arg in args:
		var parts := String(arg).split("=", false, 1)
		if parts.size() != 2:
			continue
		parsed[str(parts[0]).strip_edges()] = str(parts[1]).strip_edges()
	return parsed

func _load_launch_config(config_path: String) -> Dictionary:
	return JsonStoreScript.load_dictionary(config_path, {}, "ServerRuntimeBootstrap")
