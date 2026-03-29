extends SceneTree
class_name DedicatedLobbyServerMainLoop

const LobbyServerScript = preload("res://scripts/server/LobbyServer.gd")

var _server = null
var _scene_root: Node = null

func _initialize() -> void:
	var launch_args: Dictionary = _parse_user_args(OS.get_cmdline_user_args())
	call_deferred("_boot_server", launch_args)

func _boot_server(launch_args: Dictionary) -> void:
	var advertised_host: String = str(launch_args.get("lobby_host", "127.0.0.1")).strip_edges()
	if advertised_host.is_empty():
		advertised_host = "127.0.0.1"
	var lobby_port: int = int(launch_args.get("lobby_port", 22345))
	var match_port: int = int(launch_args.get("match_port", 12345))
	var ready_file_path: String = str(launch_args.get("ready_file", "")).strip_edges()
	var trace_file_path: String = str(launch_args.get("trace_file", "")).strip_edges()

	_scene_root = Node.new()
	_scene_root.name = "DedicatedLobbyScene"
	get_root().add_child(_scene_root)
	current_scene = _scene_root

	_server = LobbyServerScript.new()
	_server.name = "LobbyPeer"
	_server.use_dedicated_match_processes = true
	_server.allow_in_process_match_fallback = false
	_server.use_default_multiplayer = true
	_server.trace_network = true
	_server.trace_file_path = trace_file_path
	_scene_root.add_child(_server)
	_server.status_changed.connect(func(message: String) -> void:
		print("DedicatedLobbyServerMain: %s" % message)
	)

	var err: Error = _server.start_server(advertised_host, lobby_port, match_port)
	if err != OK:
		push_error("DedicatedLobbyServerMain: failed to start lobby server (%s)" % error_string(err))
		quit(1)
		return

	print("DedicatedLobbyServerMain: ready on %s:%d" % [advertised_host, lobby_port])
	if not ready_file_path.is_empty():
		var file := FileAccess.open(ready_file_path, FileAccess.WRITE)
		if file != null:
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
