extends SceneTree

const LobbyProtocolScript = preload("res://scripts/network/LobbyProtocol.gd")
const LobbyClientScript = preload("res://scripts/client/LobbyClient.gd")

var _client: LobbyClient = null
var _scene_root: Node = null
var _room_id: String = ""
var _result_file_path: String = ""
var _ready_sent: bool = false

func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() < 2:
		push_error("lobby_client_smoke: expected room code and result file path")
		quit(1)
		return

	_room_id = args[0].strip_edges().to_upper()
	_result_file_path = args[1]
	_prepare_file(_result_file_path)

	_scene_root = Node.new()
	_scene_root.name = "SmokeRoot"
	root.add_child(_scene_root)
	current_scene = _scene_root

	_client = LobbyClientScript.new()
	_client.name = "LobbyPeer"
	_scene_root.add_child(_client)

	_client.login_succeeded.connect(_on_login_succeeded)
	_client.reconnect_succeeded.connect(_on_reconnect_succeeded)
	_client.room_snapshot_updated.connect(_on_room_snapshot_updated)
	_client.room_error.connect(_on_room_error)
	_client.match_assigned.connect(_on_match_assigned)
	_client.connection_failed.connect(_on_connection_failed)
	_client.disconnected_from_lobby.connect(_on_disconnected)

	call_deferred("_boot")

func _boot() -> void:
	await process_frame

	var err: Error = _client.connect_to_server("127.0.0.1", "SmokeClient", "", "", LobbyProtocolScript.PORT)
	if err != OK:
		_fail("lobby_client_smoke: failed to connect to lobby server")
		return

	var timeout := create_timer(20.0)
	timeout.timeout.connect(_on_timeout)

func _on_login_succeeded(_session_id: String, _reconnect_token: String, _player_name: String) -> void:
	print("lobby_client_smoke: logged in, joining room %s" % _room_id)
	_client.join_room(_room_id)

func _on_reconnect_succeeded(_session_id: String, _reconnect_token: String, _player_name: String, room: Dictionary) -> void:
	if room.is_empty():
		_client.join_room(_room_id)
		return
	_on_room_snapshot_updated(room)

func _on_room_snapshot_updated(snapshot: Dictionary) -> void:
	if _ready_sent:
		return
	var room_id: String = str(snapshot.get("room_id", ""))
	if room_id != _room_id:
		return
	_ready_sent = true
	print("lobby_client_smoke: joined room %s, sending ready" % room_id)
	_client.set_ready(true)

func _on_match_assigned(match_info: Dictionary) -> void:
	_write_text(_result_file_path, "PASS:%s" % str(match_info))
	print("lobby_client_smoke: PASS")
	quit()

func _on_room_error(message: String) -> void:
	_fail("lobby_client_smoke: %s" % message)

func _on_connection_failed(message: String) -> void:
	_fail("lobby_client_smoke: %s" % message)

func _on_disconnected() -> void:
	_fail("lobby_client_smoke: disconnected before match assignment")

func _on_timeout() -> void:
	_fail("lobby_client_smoke: timed out waiting for match assignment")

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
		push_error("lobby_client_smoke: could not write %s" % path)
		return
	file.store_string(text)
	file.flush()
	file.close()
