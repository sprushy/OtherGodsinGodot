extends SceneTree

const DedicatedLobbyServerScenePath := "res://scenes/server/DedicatedLobbyServer.tscn"

var _lobby_client = null
var _lobby_pid: int = 0
var _lobby_port: int = 0
var _match_port: int = 0
var _connect_attempts_remaining: int = 12
var _server_trace_file: String = ""

func _initialize() -> void:
	call_deferred("_run_probe")

func _run_probe() -> void:
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	_lobby_port = 23000 + rng.randi_range(0, 500)
	_match_port = _lobby_port + 1000
	_server_trace_file = ProjectSettings.globalize_path("res://scripts/tmp/dedicated_lobby_process_probe_server.log")
	if FileAccess.file_exists(_server_trace_file):
		DirAccess.remove_absolute(_server_trace_file)

	var args := PackedStringArray([
		"--headless",
		"--path",
		ProjectSettings.globalize_path("res://"),
		"--scene",
		DedicatedLobbyServerScenePath,
		"--",
		"lobby_host=127.0.0.1",
		"lobby_port=%d" % _lobby_port,
		"match_port=%d" % _match_port,
		"trace_file=%s" % _server_trace_file,
	])
	_lobby_pid = OS.create_process(_resolve_headless_executable_path(OS.get_executable_path()), args, false)
	if _lobby_pid <= 0:
		push_error("dedicated_lobby_process_probe: failed to spawn dedicated lobby process")
		quit(1)
		return

	var timeout := create_timer(25.0)
	timeout.timeout.connect(func() -> void:
		_dump_server_trace()
		_cleanup_lobby_process()
		push_error("dedicated_lobby_process_probe: timed out waiting for dedicated lobby handshake")
		quit(1)
	)

	await create_timer(1.0).timeout
	_try_connect()

func _try_connect() -> void:
	if _connect_attempts_remaining <= 0:
		_dump_server_trace()
		_cleanup_lobby_process()
		push_error("dedicated_lobby_process_probe: timed out connecting to dedicated lobby process")
		quit(1)
		return
	_connect_attempts_remaining -= 1

	if _lobby_client != null and is_instance_valid(_lobby_client):
		_lobby_client.queue_free()

	_lobby_client = LobbyClient.new()
	_lobby_client.name = "LobbyPeer"
	_lobby_client.trace_network = true
	get_root().add_child(_lobby_client)
	current_scene = _lobby_client
	_lobby_client.multiplayer_mount_path = get_root().get_path()
	_lobby_client.connected_to_lobby.connect(func() -> void:
		print("dedicated_lobby_process_probe: connected to lobby")
	)
	_lobby_client.login_succeeded.connect(func(_session_id: String, _reconnect_token: String, _player_name: String) -> void:
		print("dedicated_lobby_process_probe: logged in")
		_lobby_client.create_room()
	)
	_lobby_client.room_snapshot_updated.connect(func(snapshot: Dictionary) -> void:
		if str(snapshot.get("room_id", "")).strip_edges().is_empty():
			return
		print("dedicated_lobby_process_probe: PASS")
		_cleanup_lobby_process()
		quit()
	)
	_lobby_client.room_error.connect(func(message: String) -> void:
		_dump_server_trace()
		push_error("dedicated_lobby_process_probe: room error: %s" % message)
	)
	_lobby_client.disconnected_from_lobby.connect(func() -> void:
		_dump_server_trace()
		push_error("dedicated_lobby_process_probe: disconnected from lobby")
	)
	_lobby_client.connection_failed.connect(func(_message: String) -> void:
		var timer := create_timer(0.75)
		timer.timeout.connect(func() -> void:
			_try_connect()
		)
	)

	await process_frame

	var err: Error = _lobby_client.connect_to_server("127.0.0.1", "ProbeHost", "", "", _lobby_port)
	if err != OK:
		var timer := create_timer(0.75)
		timer.timeout.connect(func() -> void:
			_try_connect()
		)

func _cleanup_lobby_process() -> void:
	if _lobby_pid > 0 and OS.is_process_running(_lobby_pid):
		OS.kill(_lobby_pid)
	_lobby_pid = 0

func _resolve_headless_executable_path(executable_path: String) -> String:
	var normalized_path := executable_path.strip_edges()
	if normalized_path.is_empty():
		return normalized_path
	if normalized_path.ends_with(".exe"):
		var console_candidate := normalized_path.substr(0, normalized_path.length() - 4) + "_console.exe"
		if FileAccess.file_exists(console_candidate):
			return console_candidate
	return normalized_path

func _dump_server_trace() -> void:
	if _server_trace_file.is_empty() or not FileAccess.file_exists(_server_trace_file):
		return
	var file := FileAccess.open(_server_trace_file, FileAccess.READ)
	if file == null:
		return
	var contents := file.get_as_text().strip_edges()
	file.close()
	if contents.is_empty():
		return
	print("dedicated_lobby_process_probe: server trace begin")
	print(contents)
	print("dedicated_lobby_process_probe: server trace end")
