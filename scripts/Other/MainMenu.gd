extends Control

const LobbyProtocolScript = preload("res://scripts/network/LobbyProtocol.gd")
const LobbyServerScript = preload("res://scripts/server/LobbyServer.gd")
const LobbyClientScript = preload("res://scripts/client/LobbyClient.gd")
const MatchSessionScript = preload("res://scripts/server/MatchSession.gd")
const DEDICATED_LOBBY_ENTRY_SCRIPT_PATH := "res://scripts/server/DedicatedLobbyServerMain.gd"
const DEDICATED_SERVER_EXPORT_RELATIVE_PATH := "res://.exports/server/ClaudeOtherGodsServer.exe"

@onready var menu_container = $MenuContainer
@onready var game_container = $GameContainer
@onready var multiplayer_container = $MenuContainer/MultiplayerContainer
@onready var ip_line_edit = $MenuContainer/MultiplayerContainer/IPLineEdit
@onready var player_name_line_edit = $MenuContainer/MultiplayerContainer/PlayerNameLineEdit
@onready var room_code_line_edit = $MenuContainer/MultiplayerContainer/RoomCodeLineEdit
@onready var connect_button = $MenuContainer/MultiplayerContainer/ConnectButton
@onready var ready_button = $MenuContainer/MultiplayerContainer/ReadyButton
@onready var status_label = $MenuContainer/MultiplayerContainer/StatusLabel

var _smoke_config: Dictionary = {}
var lobby_server = null
var lobby_client = null
var _current_room_snapshot: Dictionary = {}
var _lobby_session_id: String = ""
var _lobby_reconnect_token: String = ""
var _pending_join_room_code: String = ""
var _current_lobby_ip: String = "127.0.0.1"
var _is_local_lobby_host: bool = false
var _match_launch_queued: bool = false
var _pending_host_room_creation: bool = false
var _spawned_lobby_process_id: int = 0
var _dedicated_lobby_connect_attempts_remaining: int = 0

func _ready() -> void:
	_fit_to_viewport()
	get_viewport().size_changed.connect(_fit_to_viewport)

	get_node("GameContainer/MockGame").visible = false
	get_node("GameContainer/CardTest").visible = false
	_bind_game_signals()

	var mock_btn = $MenuContainer/MockGameButton
	var deck_btn = $MenuContainer/DeckBuilderButton
	var card_test_btn = $MenuContainer/CardTestButton
	var host_btn = $MenuContainer/HostGameButton
	var join_btn = $MenuContainer/JoinGameButton

	if mock_btn:
		mock_btn.pressed.connect(_on_mock_game_pressed)
	if deck_btn:
		deck_btn.pressed.connect(_on_deck_builder_pressed)
	if card_test_btn:
		card_test_btn.pressed.connect(_on_card_test_pressed)
	if host_btn:
		host_btn.pressed.connect(_on_host_game_pressed)
	if join_btn:
		join_btn.pressed.connect(_on_join_game_pressed)
	if connect_button:
		connect_button.pressed.connect(_on_connect_pressed)
	if ready_button:
		ready_button.pressed.connect(_on_ready_button_pressed)

	show_menu()
	_smoke_config = _parse_smoke_config(OS.get_cmdline_user_args())
	if not _smoke_config.is_empty():
		call_deferred("_start_smoke_mode")

func _bind_game_signals() -> void:
	for node_name in ["MockGame", "CardTest"]:
		var game = get_node_or_null("GameContainer/" + node_name)
		if game != null and game.has_signal("forfeit_requested"):
			var callback := Callable(self, "_on_game_forfeit_requested")
			if not game.forfeit_requested.is_connected(callback):
				game.forfeit_requested.connect(callback)

func _fit_to_viewport() -> void:
	position = Vector2.ZERO
	size = get_viewport().get_visible_rect().size

func show_menu() -> void:
	menu_container.visible = true
	game_container.visible = false

func show_game() -> void:
	menu_container.visible = false
	game_container.visible = true

func _on_deck_builder_pressed() -> void:
	_cleanup_lobby(true)

	var existing := game_container.get_node_or_null("DeckBuilder")
	if existing:
		existing.queue_free()

	var db := DeckBuilderUI.new()
	db.name = "DeckBuilder"
	db.back_pressed.connect(func() -> void:
		db.queue_free()
		show_menu()
	)
	get_node("GameContainer/MockGame").visible = false
	get_node("GameContainer/CardTest").visible = false
	game_container.add_child(db)
	show_game()

func _on_mock_game_pressed() -> void:
	_match_launch_queued = false
	_cleanup_lobby(true)
	get_node("GameContainer/MockGame").visible = true
	get_node("GameContainer/CardTest").visible = false
	show_game()
	get_node("GameContainer/MockGame").start_game()

func _on_card_test_pressed() -> void:
	_match_launch_queued = false
	_cleanup_lobby(true)
	get_node("GameContainer/CardTest").visible = true
	get_node("GameContainer/MockGame").visible = false
	show_game()
	get_node("GameContainer/CardTest").start_game()

func _on_host_game_pressed() -> void:
	_match_launch_queued = false
	_cleanup_lobby(false)
	_is_local_lobby_host = true
	_pending_host_room_creation = true
	_current_lobby_ip = _get_lobby_ip()
	_write_smoke_trace("host_pressed")
	multiplayer_container.visible = true
	ready_button.visible = true
	ready_button.text = "Ready"
	status_label.text = "Starting dedicated lobby server..."
	_dedicated_lobby_connect_attempts_remaining = 20
	_spawned_lobby_process_id = _launch_dedicated_lobby_server()
	if _spawned_lobby_process_id > 0:
		_write_smoke_trace("host_spawned_lobby_pid=%d" % _spawned_lobby_process_id)
		_write_smoke_lobby_pid(_spawned_lobby_process_id)
	call_deferred("_connect_local_host_to_dedicated_lobby")

func _on_join_game_pressed() -> void:
	_match_launch_queued = false
	_cleanup_lobby(false)
	_is_local_lobby_host = false
	_pending_host_room_creation = false
	multiplayer_container.visible = true
	ready_button.visible = false
	status_label.text = "Enter the host IP and room code, then join the lobby."

func _on_connect_pressed() -> void:
	_match_launch_queued = false
	_pending_host_room_creation = false
	_pending_join_room_code = room_code_line_edit.text.strip_edges().to_upper()
	_write_smoke_trace("join_connect_pressed room=%s" % _pending_join_room_code)
	if _pending_join_room_code.is_empty():
		status_label.text = "Enter a room code before joining."
		return

	_cleanup_lobby_client()
	_is_local_lobby_host = false
	_current_lobby_ip = _get_lobby_ip()
	status_label.text = "Connecting to lobby at %s..." % _current_lobby_ip

	lobby_client = LobbyClientScript.new()
	lobby_client.name = "LobbyPeer"
	lobby_client.use_default_multiplayer = true
	_configure_lobby_client_trace(lobby_client)
	_attach_lobby_client(lobby_client)
	_bind_lobby_client_signals()

	var connect_err: Error = lobby_client.connect_to_server(
		_current_lobby_ip,
		_get_player_name("Guest"),
		_lobby_session_id,
		_lobby_reconnect_token,
		_get_configured_lobby_port()
	)
	if connect_err != OK:
		status_label.text = "Could not connect to lobby at %s." % _current_lobby_ip

func _connect_local_host_to_dedicated_lobby() -> void:
	_write_smoke_trace("host_connect_attempt remaining=%d" % _dedicated_lobby_connect_attempts_remaining)
	if _dedicated_lobby_connect_attempts_remaining <= 0:
		status_label.text = "Dedicated lobby server did not become available."
		_fail_smoke_if_enabled("LOBBY_HOST_CONNECT_TIMEOUT")
		return
	_dedicated_lobby_connect_attempts_remaining -= 1
	if _smoke_config.has("lobby_ready_file"):
		var ready_file := str(_smoke_config.get("lobby_ready_file", "")).strip_edges()
		if not ready_file.is_empty() and not FileAccess.file_exists(ready_file):
			var ready_wait_timer := get_tree().create_timer(0.5)
			ready_wait_timer.timeout.connect(func() -> void:
				_connect_local_host_to_dedicated_lobby()
			)
			return
	var wait_seconds := 0.8 if _spawned_lobby_process_id > 0 else 0.25
	await get_tree().create_timer(wait_seconds).timeout
	_cleanup_lobby_client()
	status_label.text = "Connecting to dedicated lobby at %s..." % _current_lobby_ip
	_write_smoke_trace("host_connecting_to_lobby ip=%s port=%d" % [_current_lobby_ip, _get_configured_lobby_port()])
	lobby_client = LobbyClientScript.new()
	lobby_client.name = "LobbyPeer"
	lobby_client.use_default_multiplayer = true
	_configure_lobby_client_trace(lobby_client)
	_attach_lobby_client(lobby_client)
	_bind_lobby_client_signals()
	var connect_err: Error = lobby_client.connect_to_server(
		_current_lobby_ip,
		_get_player_name("Host"),
		_lobby_session_id,
		_lobby_reconnect_token,
		_get_configured_lobby_port()
	)
	if connect_err != OK:
		_queue_host_lobby_retry("Could not connect to dedicated lobby at %s." % _current_lobby_ip)

func _on_ready_button_pressed() -> void:
	var next_ready := not _is_local_player_ready()
	if lobby_client != null:
		lobby_client.set_ready(next_ready)
	elif _is_local_lobby_host and lobby_server != null:
		lobby_server.set_local_ready(next_ready)

func _bind_lobby_server_signals() -> void:
	if lobby_server == null:
		return
	if not lobby_server.local_room_snapshot_updated.is_connected(_on_local_room_snapshot_updated):
		lobby_server.local_room_snapshot_updated.connect(_on_local_room_snapshot_updated)
	if not lobby_server.local_match_assigned.is_connected(_on_local_match_assigned):
		lobby_server.local_match_assigned.connect(_on_local_match_assigned)
	if not lobby_server.status_changed.is_connected(_on_lobby_status_changed):
		lobby_server.status_changed.connect(_on_lobby_status_changed)

func _bind_lobby_client_signals() -> void:
	if lobby_client == null:
		return
	if not lobby_client.connected_to_lobby.is_connected(_on_lobby_connected):
		lobby_client.connected_to_lobby.connect(_on_lobby_connected)
	if not lobby_client.login_succeeded.is_connected(_on_lobby_login_succeeded):
		lobby_client.login_succeeded.connect(_on_lobby_login_succeeded)
	if not lobby_client.reconnect_succeeded.is_connected(_on_lobby_reconnect_succeeded):
		lobby_client.reconnect_succeeded.connect(_on_lobby_reconnect_succeeded)
	if not lobby_client.room_snapshot_updated.is_connected(_on_lobby_room_snapshot_updated):
		lobby_client.room_snapshot_updated.connect(_on_lobby_room_snapshot_updated)
	if not lobby_client.room_error.is_connected(_on_lobby_room_error):
		lobby_client.room_error.connect(_on_lobby_room_error)
	if not lobby_client.match_assigned.is_connected(_on_remote_match_assigned):
		lobby_client.match_assigned.connect(_on_remote_match_assigned)
	if not lobby_client.connection_failed.is_connected(_on_lobby_connection_failed):
		lobby_client.connection_failed.connect(_on_lobby_connection_failed)
	if not lobby_client.disconnected_from_lobby.is_connected(_on_lobby_disconnected):
		lobby_client.disconnected_from_lobby.connect(_on_lobby_disconnected)

func _on_lobby_connected() -> void:
	_write_smoke_trace("lobby_connected")
	status_label.text = "Connected to lobby. Signing in..."

func _on_lobby_login_succeeded(session_id: String, reconnect_token: String, player_name: String) -> void:
	_write_smoke_trace("lobby_login_succeeded session=%s player=%s host=%s" % [session_id, player_name, str(_is_local_lobby_host)])
	_lobby_session_id = session_id
	_lobby_reconnect_token = reconnect_token
	player_name_line_edit.text = player_name
	if _is_local_lobby_host and _pending_host_room_creation:
		_pending_host_room_creation = false
		status_label.text = "Signed in as %s. Creating room..." % player_name
		if lobby_client != null:
			lobby_client.create_room()
		return
	status_label.text = "Signed in as %s. Joining room %s..." % [player_name, _pending_join_room_code]
	if lobby_client != null and not _pending_join_room_code.is_empty():
		lobby_client.join_room(_pending_join_room_code)

func _on_lobby_reconnect_succeeded(session_id: String, reconnect_token: String, player_name: String, room: Dictionary) -> void:
	_write_smoke_trace("lobby_reconnect_succeeded session=%s player=%s" % [session_id, player_name])
	_lobby_session_id = session_id
	_lobby_reconnect_token = reconnect_token
	player_name_line_edit.text = player_name
	if _is_local_lobby_host and _pending_host_room_creation:
		if room.is_empty():
			_pending_host_room_creation = false
			status_label.text = "Lobby session restored. Creating room..."
			if lobby_client != null:
				lobby_client.create_room()
			return
	if room.is_empty():
		status_label.text = "Lobby session restored. Joining room %s..." % _pending_join_room_code
		if lobby_client != null and not _pending_join_room_code.is_empty():
			lobby_client.join_room(_pending_join_room_code)
		return
	_apply_room_snapshot(room)
	status_label.text = "Lobby session restored."

func _on_lobby_room_snapshot_updated(snapshot: Dictionary) -> void:
	_apply_room_snapshot(snapshot)

func _on_local_room_snapshot_updated(snapshot: Dictionary) -> void:
	_apply_room_snapshot(snapshot)

func _apply_room_snapshot(snapshot: Dictionary) -> void:
	_current_room_snapshot = snapshot.duplicate(true)
	var room_id := str(snapshot.get("room_id", "")).strip_edges()
	if room_id.is_empty():
		return
	_write_smoke_trace("room_snapshot room=%s members=%d" % [room_id, snapshot.get("members", []).size()])
	room_code_line_edit.text = room_id
	_write_smoke_room_code(room_id)
	ready_button.visible = true
	ready_button.text = "Unready" if _is_local_player_ready() else "Ready"

	var member_lines: Array[String] = []
	for member in snapshot.get("members", []):
		var player_name := str(member.get("player_name", "Guest"))
		var ready_text := "ready" if bool(member.get("is_ready", false)) else "waiting"
		var connect_text := "online" if bool(member.get("is_connected", false)) else "offline"
		var host_text := " (host)" if bool(member.get("is_host", false)) else ""
		member_lines.append("%s%s - %s, %s" % [player_name, host_text, ready_text, connect_text])

	var share_text := "Share IP %s and room code %s." % [_current_lobby_ip, room_id]
	status_label.text = "Room %s\n%s\n%s" % [room_id, "\n".join(member_lines), share_text]
	_maybe_progress_smoke_from_room_snapshot(room_id)

func _on_local_match_assigned(match_info: Dictionary) -> void:
	if _match_launch_queued:
		return
	_match_launch_queued = true
	_write_smoke_trace("local_match_assigned match=%s" % str(match_info.get("match_id", "")))
	status_label.text = "Both players are ready. Preparing the match server..."
	_write_smoke_result("MATCH_ASSIGNED_HOST:%s" % str(match_info))
	call_deferred("_launch_host_match_after_lobby_handoff", match_info)

func _on_remote_match_assigned(match_info: Dictionary) -> void:
	if _match_launch_queued:
		return
	_match_launch_queued = true
	_write_smoke_trace("remote_match_assigned match=%s" % str(match_info.get("match_id", "")))
	var match_ip := str(match_info.get("server_ip", _current_lobby_ip))
	var match_port := int(match_info.get("match_port", _get_configured_match_port()))
	status_label.text = "Match found. Connecting to %s..." % match_ip
	_write_smoke_result("MATCH_ASSIGNED_CLIENT:%s" % str(match_info))
	_cleanup_lobby(false)
	call_deferred("_launch_assigned_match", false, match_ip, match_port, match_info)

func _launch_assigned_match(
	is_host: bool,
	server_ip: String,
	match_port: int = LobbyProtocolScript.MATCH_PORT,
	match_info: Dictionary = {},
	server_match_session = null
) -> void:
	get_node("GameContainer/MockGame").visible = true
	get_node("GameContainer/CardTest").visible = false
	show_game()
	if is_host:
		get_node("GameContainer/MockGame").start_game(true, false, server_ip, match_port, match_info, server_match_session)
		_finish_smoke_if_enabled("PASS:host_launched_match")
		return
	var connect_delay_seconds := 0.4
	if _uses_dedicated_match_server(match_info):
		connect_delay_seconds = 1.1
	await get_tree().create_timer(connect_delay_seconds).timeout
	get_node("GameContainer/MockGame").start_game(false, true, server_ip, match_port, match_info)
	_finish_smoke_if_enabled("PASS:client_launched_match")

func _launch_host_match_after_lobby_handoff(match_info: Dictionary) -> void:
	if _uses_dedicated_match_server(match_info):
		await get_tree().create_timer(1.1).timeout
		_launch_assigned_match(
			false,
			str(match_info.get("server_ip", _current_lobby_ip)),
			int(match_info.get("match_port", _get_configured_match_port())),
			match_info
		)
		return
	var match_session = null
	if lobby_server != null:
		match_session = lobby_server.get_match_session(str(match_info.get("match_id", "")))
	await get_tree().create_timer(0.75).timeout
	_cleanup_lobby(false)
	_launch_assigned_match(
		true,
		str(match_info.get("server_ip", _current_lobby_ip)),
		int(match_info.get("match_port", _get_configured_match_port())),
		match_info,
		match_session
	)

func _uses_dedicated_match_server(match_info: Dictionary) -> bool:
	return str(match_info.get("server_mode", "")) == MatchSessionScript.SERVER_MODE_DEDICATED_HEADLESS

func _on_lobby_room_error(message: String) -> void:
	_write_smoke_trace("lobby_room_error %s" % message)
	status_label.text = message
	_fail_smoke_if_enabled("ROOM_ERROR:%s" % message)

func _on_lobby_status_changed(message: String) -> void:
	_write_smoke_trace("lobby_status %s" % message)
	status_label.text = message

func _on_lobby_connection_failed(message: String) -> void:
	_write_smoke_trace("lobby_connection_failed %s" % message)
	if _should_retry_host_lobby_connect():
		_queue_host_lobby_retry(message)
		return
	status_label.text = message
	_fail_smoke_if_enabled("CONNECTION_FAILED:%s" % message)

func _on_lobby_disconnected() -> void:
	_write_smoke_trace("lobby_disconnected")
	if _should_retry_host_lobby_connect():
		_queue_host_lobby_retry("Dedicated lobby disconnected before room setup completed.")
		return
	status_label.text = "Lobby connection lost. Press Join Game to reconnect."
	_fail_smoke_if_enabled("DISCONNECTED_FROM_LOBBY")

func _on_back_to_menu_pressed() -> void:
	_return_to_menu()

func _on_game_forfeit_requested() -> void:
	_return_to_menu()

func _return_to_menu() -> void:
	show_menu()
	_match_launch_queued = false
	_cleanup_lobby(true)
	for node_name in ["MockGame", "CardTest"]:
		var game = get_node_or_null("GameContainer/" + node_name)
		if game and game.has_method("cleanup"):
			game.cleanup()
	var db := game_container.get_node_or_null("DeckBuilder")
	if db:
		db.queue_free()
	multiplayer_container.visible = false

func _cleanup_lobby(clear_session: bool) -> void:
	_cleanup_lobby_client()
	_cleanup_lobby_server()
	_current_room_snapshot.clear()
	ready_button.visible = false
	if clear_session:
		_match_launch_queued = false
		_pending_host_room_creation = false
		_dedicated_lobby_connect_attempts_remaining = 0
		_lobby_session_id = ""
		_lobby_reconnect_token = ""
		_pending_join_room_code = ""
		_current_lobby_ip = "127.0.0.1"
		_is_local_lobby_host = false
		room_code_line_edit.text = ""
		status_label.text = "Host a room on this machine, or join one by IP and room code."

func _cleanup_lobby_client() -> void:
	if lobby_client == null:
		return
	lobby_client.disconnect_from_server()
	lobby_client.queue_free()
	lobby_client = null
	_cleanup_dedicated_lobby_mount_if_unused()

func _cleanup_lobby_server() -> void:
	if lobby_server == null:
		return
	lobby_server.stop_server()
	lobby_server.queue_free()
	lobby_server = null

func _attach_lobby_client(client: Node) -> void:
	var active_scene := get_tree().current_scene
	if active_scene == null:
		add_child(client)
		return
	active_scene.add_child(client)
	if client is LobbyClient:
		client.multiplayer_mount_path = active_scene.get_path()

func _cleanup_dedicated_lobby_mount_if_unused() -> void:
	pass

func _configure_lobby_client_trace(client: LobbyClient) -> void:
	if client == null or _smoke_config.is_empty():
		return
	var trace_file := str(_smoke_config.get("trace_file", "")).strip_edges()
	if trace_file.is_empty():
		return
	client.trace_file_path = trace_file

func _is_local_player_ready() -> bool:
	for member in _current_room_snapshot.get("members", []):
		if str(member.get("session_id", "")) == _lobby_session_id:
			return bool(member.get("is_ready", false))
	return false

func _get_lobby_ip() -> String:
	var ip: String = ip_line_edit.text.strip_edges()
	if ip.is_empty():
		return "127.0.0.1"
	return ip

func _get_player_name(default_name: String) -> String:
	var player_name: String = player_name_line_edit.text.strip_edges()
	if player_name.is_empty():
		return default_name
	return player_name

func _get_configured_lobby_port() -> int:
	if _smoke_config.is_empty():
		return LobbyProtocolScript.PORT
	return int(_smoke_config.get("lobby_port", LobbyProtocolScript.PORT))

func _get_configured_match_port() -> int:
	if _smoke_config.is_empty():
		return LobbyProtocolScript.MATCH_PORT
	return int(_smoke_config.get("match_port", LobbyProtocolScript.MATCH_PORT))

func _start_smoke_mode() -> void:
	var role := str(_smoke_config.get("role", "")).to_lower()
	if role.is_empty():
		return

	ip_line_edit.text = str(_smoke_config.get("ip", "127.0.0.1"))
	player_name_line_edit.text = str(_smoke_config.get("player_name", "Smoke%s" % role.capitalize()))

	var timeout_seconds := float(_smoke_config.get("timeout", 25.0))
	var timeout_timer := get_tree().create_timer(timeout_seconds)
	timeout_timer.timeout.connect(func() -> void:
		_fail_smoke_if_enabled("TIMEOUT")
	)

	if role == "host":
		_on_host_game_pressed()
		return

	if role == "client":
		_on_join_game_pressed()
		var room_code := _read_smoke_room_code()
		if room_code.is_empty():
			_wait_for_smoke_room_code()
			return
		_join_smoke_room(room_code)

func _wait_for_smoke_room_code() -> void:
	var timer := get_tree().create_timer(0.5)
	timer.timeout.connect(func() -> void:
		var room_code := _read_smoke_room_code()
		if room_code.is_empty():
			_wait_for_smoke_room_code()
			return
		_join_smoke_room(room_code)
	)

func _join_smoke_room(room_code: String) -> void:
	room_code_line_edit.text = room_code
	_pending_join_room_code = room_code
	_on_connect_pressed()

func _maybe_progress_smoke_from_room_snapshot(room_id: String) -> void:
	if _smoke_config.is_empty():
		return

	var role := str(_smoke_config.get("role", "")).to_lower()
	if role == "host":
		if not _is_local_player_ready():
			_on_ready_button_pressed()
	elif role == "client":
		var expected_room := str(_pending_join_room_code).strip_edges().to_upper()
		if expected_room.is_empty() or room_id != expected_room:
			return
		if not _is_local_player_ready():
			_on_ready_button_pressed()

func _parse_smoke_config(args: Array) -> Dictionary:
	var config: Dictionary = {}
	for raw_arg in args:
		var arg := str(raw_arg)
		var separator := arg.find("=")
		if separator <= 0:
			continue
		var key := arg.substr(0, separator)
		var value := arg.substr(separator + 1)
		config[key] = value

	if not config.has("smoke_role"):
		return {}

	return {
		"role": str(config.get("smoke_role", "")),
		"ip": str(config.get("smoke_ip", "127.0.0.1")),
		"player_name": str(config.get("smoke_name", "")),
		"room_file": str(config.get("smoke_room_file", "")),
		"result_file": str(config.get("smoke_result_file", "")),
		"trace_file": str(config.get("smoke_trace_file", "")),
		"lobby_server_trace_file": str(config.get("smoke_lobby_server_trace_file", "")),
		"lobby_server_log_file": str(config.get("smoke_lobby_server_log_file", "")),
		"lobby_pid_file": str(config.get("smoke_lobby_pid_file", "")),
		"lobby_ready_file": str(config.get("smoke_lobby_ready_file", "")),
		"timeout": float(str(config.get("smoke_timeout", "25")).to_float()),
		"lobby_port": int(str(config.get("smoke_lobby_port", str(LobbyProtocolScript.PORT))).to_int()),
		"match_port": int(str(config.get("smoke_match_port", str(LobbyProtocolScript.MATCH_PORT))).to_int()),
	}

func _write_smoke_room_code(room_code: String) -> void:
	if _smoke_config.is_empty():
		return
	var room_file := str(_smoke_config.get("room_file", "")).strip_edges()
	if room_file.is_empty():
		return
	var file := FileAccess.open(room_file, FileAccess.WRITE)
	if file == null:
		return
	file.store_string(room_code)
	file.flush()
	file.close()

func _read_smoke_room_code() -> String:
	if _smoke_config.is_empty():
		return ""
	var room_file := str(_smoke_config.get("room_file", "")).strip_edges()
	if room_file.is_empty() or not FileAccess.file_exists(room_file):
		return ""
	var file := FileAccess.open(room_file, FileAccess.READ)
	if file == null:
		return ""
	var room_code := file.get_as_text().strip_edges().to_upper()
	file.close()
	return room_code

func _write_smoke_result(message: String) -> void:
	if _smoke_config.is_empty():
		return
	var result_file := str(_smoke_config.get("result_file", "")).strip_edges()
	if result_file.is_empty():
		return
	var file := FileAccess.open(result_file, FileAccess.WRITE)
	if file == null:
		return
	file.store_string(message)
	file.flush()
	file.close()

func _write_smoke_trace(message: String) -> void:
	if _smoke_config.is_empty():
		return
	var trace_file := str(_smoke_config.get("trace_file", "")).strip_edges()
	if trace_file.is_empty():
		return
	var file := FileAccess.open(trace_file, FileAccess.READ_WRITE)
	if file == null:
		file = FileAccess.open(trace_file, FileAccess.WRITE)
	if file == null:
		return
	file.seek_end()
	file.store_line(message)
	file.flush()
	file.close()

func _write_smoke_lobby_pid(pid: int) -> void:
	if _smoke_config.is_empty():
		return
	var pid_file := str(_smoke_config.get("lobby_pid_file", "")).strip_edges()
	if pid_file.is_empty():
		return
	var file := FileAccess.open(pid_file, FileAccess.WRITE)
	if file == null:
		return
	file.store_string(str(pid))
	file.flush()
	file.close()

func _finish_smoke_if_enabled(message: String) -> void:
	if _smoke_config.is_empty():
		return
	_write_smoke_result(message)

func _fail_smoke_if_enabled(message: String) -> void:
	if _smoke_config.is_empty():
		return
	_write_smoke_result("FAIL:%s" % message)

func _launch_dedicated_lobby_server() -> int:
	var project_path := ProjectSettings.globalize_path("res://")
	var exported_server_path := _resolve_dedicated_server_runtime_path()
	if not exported_server_path.is_empty():
		return _launch_exported_dedicated_lobby_server(exported_server_path)

	var executable_path := _resolve_headless_executable_path(OS.get_executable_path())
	if project_path.is_empty() or executable_path.is_empty():
		return 0
	var args := PackedStringArray(["--headless"])
	var lobby_server_log_file := str(_smoke_config.get("lobby_server_log_file", "")).strip_edges()
	if not lobby_server_log_file.is_empty():
		args.append_array(["--log-file", lobby_server_log_file])
	if not OS.has_feature("template"):
		args.append("--editor")
	args.append_array([
		"--path",
		project_path,
		"--script",
		DEDICATED_LOBBY_ENTRY_SCRIPT_PATH,
		"--",
		"lobby_host=%s" % _current_lobby_ip,
		"lobby_port=%d" % _get_configured_lobby_port(),
		"match_port=%d" % _get_configured_match_port(),
	])
	var ready_file := str(_smoke_config.get("lobby_ready_file", "")).strip_edges()
	if not ready_file.is_empty():
		args.append("ready_file=%s" % ready_file)
	var lobby_server_trace_file := str(_smoke_config.get("lobby_server_trace_file", "")).strip_edges()
	if not lobby_server_trace_file.is_empty():
		args.append("trace_file=%s" % lobby_server_trace_file)
	return OS.create_process(executable_path, args, false)

func _launch_exported_dedicated_lobby_server(executable_path: String) -> int:
	var args := PackedStringArray(["--headless"])
	var lobby_server_log_file := str(_smoke_config.get("lobby_server_log_file", "")).strip_edges()
	if not lobby_server_log_file.is_empty():
		args.append_array(["--log-file", lobby_server_log_file])
	args.append_array([
		"--",
		"server_mode=lobby",
		"lobby_host=%s" % _current_lobby_ip,
		"lobby_port=%d" % _get_configured_lobby_port(),
		"match_port=%d" % _get_configured_match_port(),
	])
	var ready_file := str(_smoke_config.get("lobby_ready_file", "")).strip_edges()
	if not ready_file.is_empty():
		args.append("ready_file=%s" % ready_file)
	var lobby_server_trace_file := str(_smoke_config.get("lobby_server_trace_file", "")).strip_edges()
	if not lobby_server_trace_file.is_empty():
		args.append("trace_file=%s" % lobby_server_trace_file)
	return OS.create_process(executable_path, args, false)

func _resolve_headless_executable_path(executable_path: String) -> String:
	var normalized_path := executable_path.strip_edges()
	if normalized_path.is_empty():
		return normalized_path
	if normalized_path.ends_with(".exe"):
		var console_candidate := normalized_path.substr(0, normalized_path.length() - 4) + "_console.exe"
		if FileAccess.file_exists(console_candidate):
			return console_candidate
	return normalized_path

func _resolve_dedicated_server_runtime_path() -> String:
	var candidates := PackedStringArray([
		ProjectSettings.globalize_path(DEDICATED_SERVER_EXPORT_RELATIVE_PATH),
		OS.get_executable_path().get_base_dir().path_join("ClaudeOtherGodsServer.exe"),
		OS.get_executable_path().get_base_dir().path_join("ClaudeOtherGodsServer_console.exe"),
	])
	for candidate in candidates:
		if candidate.is_empty():
			continue
		if FileAccess.file_exists(candidate):
			return candidate
	return ""

func _should_retry_host_lobby_connect() -> bool:
	return _is_local_lobby_host and not _match_launch_queued and _current_room_snapshot.is_empty()

func _queue_host_lobby_retry(message: String) -> void:
	if _dedicated_lobby_connect_attempts_remaining <= 0:
		status_label.text = message
		_fail_smoke_if_enabled("CONNECTION_FAILED:%s" % message)
		return
	status_label.text = "%s Retrying..." % message
	var timer := get_tree().create_timer(0.75)
	timer.timeout.connect(func() -> void:
		_connect_local_host_to_dedicated_lobby()
	)

func _on_aggressive_stance_btn_pressed() -> void:
	pass

func _on_defensive_stance_btn_pressed() -> void:
	pass

func _on_stealth_mode_btn_pressed() -> void:
	pass

func _on_toggle_mode_button_pressed() -> void:
	pass
