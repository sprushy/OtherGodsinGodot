extends SceneTree

const LobbyProtocolScript = preload("res://scripts/network/LobbyProtocol.gd")
const LobbyServerScript = preload("res://scripts/server/LobbyServer.gd")

var _server: LobbyServer = null
var _scene_root: Node = null
var _room_file_path: String = ""
var _result_file_path: String = ""

func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() < 2:
		push_error("lobby_host_smoke: expected room and result file paths")
		quit(1)
		return

	_room_file_path = args[0]
	_result_file_path = args[1]
	_prepare_file(_room_file_path)
	_prepare_file(_result_file_path)

	_scene_root = Node.new()
	_scene_root.name = "SmokeRoot"
	root.add_child(_scene_root)
	current_scene = _scene_root

	_server = LobbyServerScript.new()
	_server.name = "LobbyPeer"
	_scene_root.add_child(_server)
	_server.local_match_assigned.connect(_on_local_match_assigned)
	_server.status_changed.connect(_on_status_changed)

	call_deferred("_boot")

func _boot() -> void:
	await process_frame

	var err: Error = _server.start_server("127.0.0.1", LobbyProtocolScript.PORT, LobbyProtocolScript.MATCH_PORT)
	if err != OK:
		_fail("lobby_host_smoke: failed to start lobby server")
		return

	var session: Dictionary = _server.create_local_guest_session("SmokeHost")
	if str(session.get("session_id", "")).is_empty():
		_fail("lobby_host_smoke: host session was not created")
		return

	var snapshot: Dictionary = _server.create_room_for_local_session()
	var room_id: String = str(snapshot.get("room_id", ""))
	if room_id.is_empty():
		_fail("lobby_host_smoke: host room was not created")
		return

	_write_text(_room_file_path, room_id)
	_server.set_local_ready(true)
	print("lobby_host_smoke: room %s ready" % room_id)

	var timeout := create_timer(20.0)
	timeout.timeout.connect(_on_timeout)

func _on_local_match_assigned(match_info: Dictionary) -> void:
	_write_text(_result_file_path, "PASS:%s" % str(match_info))
	print("lobby_host_smoke: PASS")
	quit()

func _on_status_changed(message: String) -> void:
	print("lobby_host_smoke: %s" % message)

func _on_timeout() -> void:
	_fail("lobby_host_smoke: timed out waiting for client match assignment")

func _fail(message: String) -> void:
	_write_text(_result_file_path, "FAIL:%s" % message)
	push_error(message)
	quit(1)

func _prepare_file(path: String) -> void:
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(path)

func _write_text(path: String, text: String) -> void:
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		push_error("lobby_host_smoke: could not write %s" % path)
		return
	file.store_string(text)
	file.flush()
	file.close()
