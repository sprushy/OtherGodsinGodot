extends LobbyServer
class_name DedicatedLobbyServerNode

const DedicatedLobbyProtocolScript = preload("res://scripts/network/LobbyProtocol.gd")

func _ready() -> void:
	use_dedicated_match_processes = true
	allow_in_process_match_fallback = false
	super._ready()

	var launch_args: Dictionary = _parse_user_args(OS.get_cmdline_user_args())
	var advertised_host: String = str(launch_args.get("lobby_host", "127.0.0.1")).strip_edges()
	if advertised_host.is_empty():
		advertised_host = "127.0.0.1"
	var lobby_port: int = int(launch_args.get("lobby_port", DedicatedLobbyProtocolScript.PORT))
	var match_port: int = int(launch_args.get("match_port", DedicatedLobbyProtocolScript.MATCH_PORT))
	var ready_file_path: String = str(launch_args.get("ready_file", "")).strip_edges()
	var trace_output_path: String = str(launch_args.get("trace_file", "")).strip_edges()

	if not status_changed.is_connected(_on_status_changed):
		status_changed.connect(_on_status_changed)
	use_default_multiplayer = true
	trace_network = true
	trace_file_path = trace_output_path
	if get_parent() != null:
		multiplayer_mount_path = get_parent().get_path()

	var err: Error = start_server(advertised_host, lobby_port, match_port)
	if err != OK:
		push_error("DedicatedLobbyServerNode: failed to start lobby server (%s)" % error_string(err))
		get_tree().quit(1)
		return

	print("DedicatedLobbyServerNode: ready on %s:%d" % [advertised_host, lobby_port])
	if not ready_file_path.is_empty():
		var file := FileAccess.open(ready_file_path, FileAccess.WRITE)
		if file != null:
			file.store_string("READY")
			file.flush()
			file.close()

func _on_status_changed(message: String) -> void:
	print("DedicatedLobbyServerNode: %s" % message)

func _parse_user_args(args: PackedStringArray) -> Dictionary:
	var parsed: Dictionary = {}
	for arg in args:
		var parts := String(arg).split("=", false, 1)
		if parts.size() != 2:
			continue
		parsed[str(parts[0]).strip_edges()] = str(parts[1]).strip_edges()
	return parsed
