extends SceneTree

var _client = null
var _port: int = 22345
var _scene_root: Node = null
var _probe_username: String = ""

func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if not args.is_empty():
		_port = int(str(args[0]).to_int())
	_probe_username = "Attach%d" % int(Time.get_ticks_msec() % 1000000)
	call_deferred("_run_probe")

func _run_probe() -> void:
	_scene_root = Node.new()
	_scene_root.name = "DedicatedLobbyRoot"
	get_root().add_child(_scene_root)
	current_scene = _scene_root

	_client = LobbyClient.new()
	_client.name = "LobbyPeer"
	_scene_root.add_child(_client)
	_client.multiplayer_mount_path = _scene_root.get_path()
	_client.connected_to_lobby.connect(func() -> void:
		print("dedicated_lobby_attach_probe: connected")
	)
	_client.login_succeeded.connect(func(_session_id: String, _reconnect_token: String, _player_name: String) -> void:
		print("dedicated_lobby_attach_probe: logged in")
		_client.create_room()
	)
	_client.room_snapshot_updated.connect(func(snapshot: Dictionary) -> void:
		if str(snapshot.get("room_id", "")).strip_edges().is_empty():
			return
		print("dedicated_lobby_attach_probe: PASS")
		quit()
	)
	_client.room_error.connect(func(message: String) -> void:
		push_error("dedicated_lobby_attach_probe: %s" % message)
		quit(1)
	)
	_client.connection_failed.connect(func(message: String) -> void:
		push_error("dedicated_lobby_attach_probe: %s" % message)
		quit(1)
	)

	await process_frame

	var err: Error = _client.connect_to_server(
		"127.0.0.1",
		_probe_username,
		"",
		"",
		_port,
		"",
		"register",
		"ProbePass123"
	)
	if err != OK:
		push_error("dedicated_lobby_attach_probe: connect_to_server failed")
		quit(1)
		return

	var timeout := create_timer(20.0)
	timeout.timeout.connect(func() -> void:
		push_error("dedicated_lobby_attach_probe: timed out")
		quit(1)
	)
