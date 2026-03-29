extends Node
class_name LobbyClient

const LobbyProtocolScript = preload("res://scripts/network/LobbyProtocol.gd")
const NetworkManagerScript = preload("res://scripts/Other/NetworkManager.gd")
const LOBBY_EVENT_TYPE := "__lobby_event__"

signal connected_to_lobby()
signal login_succeeded(session_id: String, reconnect_token: String, player_name: String)
signal reconnect_succeeded(session_id: String, reconnect_token: String, player_name: String, room: Dictionary)
signal room_list_updated(rooms: Array)
signal room_snapshot_updated(snapshot: Dictionary)
signal room_error(message: String)
signal match_assigned(match_info: Dictionary)
signal connection_failed(message: String)
signal disconnected_from_lobby()

var current_session_id: String = ""
var current_reconnect_token: String = ""
var current_player_name: String = "Guest"
var trace_network: bool = false
var trace_file_path: String = ""
var multiplayer_mount_path: NodePath = NodePath("")
var use_default_multiplayer: bool = false
var network_manager: Node = null

var _pending_player_name: String = "Guest"
var _pending_session_id: String = ""
var _pending_reconnect_token: String = ""

func _ready() -> void:
	_ensure_network_manager()

func connect_to_server(
	address: String,
	player_name: String = "Guest",
	session_id: String = "",
	reconnect_token: String = "",
	port: int = LobbyProtocolScript.PORT
) -> Error:
	_pending_player_name = player_name.strip_edges()
	if _pending_player_name.is_empty():
		_pending_player_name = "Guest"
	_pending_session_id = session_id.strip_edges()
	_pending_reconnect_token = reconnect_token.strip_edges()

	var connect_address: String = address.strip_edges()
	if connect_address.is_empty():
		connect_address = "127.0.0.1"

	_ensure_network_manager()
	if network_manager == null:
		connection_failed.emit("Could not initialize lobby network transport.")
		return ERR_UNAVAILABLE
	return network_manager.create_client(connect_address, port)

func disconnect_from_server() -> void:
	if network_manager != null:
		network_manager.disconnect_client()

func create_room() -> void:
	_send_request(LobbyProtocolScript.CREATE_ROOM)

func list_rooms() -> void:
	_send_request(LobbyProtocolScript.LIST_ROOMS)

func join_room(room_id: String) -> void:
	_send_request(LobbyProtocolScript.JOIN_ROOM, {"room_id": room_id.strip_edges().to_upper()})

func leave_room() -> void:
	_send_request(LobbyProtocolScript.LEAVE_ROOM)

func set_ready(is_ready: bool) -> void:
	_send_request(LobbyProtocolScript.SET_READY, {"is_ready": is_ready})

func lobby_event(message: Dictionary) -> void:
	var message_type: String = LobbyProtocolScript.get_type(message)
	var payload: Dictionary = LobbyProtocolScript.get_payload(message)
	_trace("received %s" % message_type)

	match message_type:
		LobbyProtocolScript.HELLO_OK:
			current_session_id = str(payload.get("session_id", ""))
			current_reconnect_token = str(payload.get("reconnect_token", ""))
			current_player_name = str(payload.get("player_name", _pending_player_name))
			login_succeeded.emit(current_session_id, current_reconnect_token, current_player_name)
		LobbyProtocolScript.LOBBY_RECONNECT_OK:
			current_session_id = str(payload.get("session_id", ""))
			current_reconnect_token = str(payload.get("reconnect_token", ""))
			current_player_name = str(payload.get("player_name", _pending_player_name))
			reconnect_succeeded.emit(
				current_session_id,
				current_reconnect_token,
				current_player_name,
				payload.get("room", {})
			)
		LobbyProtocolScript.ROOM_LIST:
			room_list_updated.emit(payload.get("rooms", []))
		LobbyProtocolScript.ROOM_SNAPSHOT:
			room_snapshot_updated.emit(payload)
		LobbyProtocolScript.ROOM_ERROR:
			room_error.emit(str(payload.get("message", "Unknown lobby error.")))
		LobbyProtocolScript.MATCH_ASSIGNED:
			match_assigned.emit(payload)

func _on_connected_to_server() -> void:
	_trace("connected to server")
	connected_to_lobby.emit()
	if not _pending_session_id.is_empty() and not _pending_reconnect_token.is_empty():
		_send_request(LobbyProtocolScript.REQUEST_RECONNECT_LOBBY, {
			"session_id": _pending_session_id,
			"reconnect_token": _pending_reconnect_token,
		})
		return

	_send_request(LobbyProtocolScript.LOGIN_GUEST, {
		"player_name": _pending_player_name,
	})

func _on_connection_failed() -> void:
	_trace("connection failed")
	connection_failed.emit("The lobby connection failed.")

func _on_server_disconnected() -> void:
	_trace("server disconnected")
	disconnected_from_lobby.emit()

func _send_request(message_type: String, payload: Dictionary = {}) -> void:
	if network_manager == null:
		return
	_trace("sending %s" % message_type)
	network_manager.request_action(LobbyProtocolScript.make_message(message_type, payload))

func _ensure_multiplayer_api() -> MultiplayerAPI:
	if use_default_multiplayer:
		if get_tree() == null:
			return null
		return get_tree().get_multiplayer()
	if multiplayer != null:
		return multiplayer
	if get_tree() == null:
		return null
	var fallback_api := MultiplayerAPI.create_default_interface()
	var target_path: NodePath = get_path()
	if multiplayer_mount_path != NodePath(""):
		target_path = multiplayer_mount_path
	get_tree().set_multiplayer(fallback_api, target_path)
	return multiplayer

func _ensure_network_manager() -> void:
	if network_manager != null:
		return
	network_manager = NetworkManagerScript.new()
	network_manager.name = "LobbyTransport"
	network_manager.trace_file_path = trace_file_path
	network_manager.use_current_scene_relative_path = true
	add_child(network_manager)
	if not network_manager.connected_to_server.is_connected(_on_connected_to_server):
		network_manager.connected_to_server.connect(_on_connected_to_server)
	if not network_manager.connection_failed.is_connected(_on_connection_failed):
		network_manager.connection_failed.connect(_on_connection_failed)
	if not network_manager.server_disconnected.is_connected(_on_server_disconnected):
		network_manager.server_disconnected.connect(_on_server_disconnected)
	if not network_manager.game_event_received.is_connected(_on_network_game_event_received):
		network_manager.game_event_received.connect(_on_network_game_event_received)

func _on_network_game_event_received(event_type: String, data: Dictionary) -> void:
	if event_type != LOBBY_EVENT_TYPE:
		return
	lobby_event(data)

func _trace(message: String) -> void:
	if not trace_network and trace_file_path.is_empty():
		return
	var line := "LobbyClient[%s]: %s" % [name, message]
	if trace_network:
		print(line)
	if trace_file_path.is_empty():
		return
	var file := FileAccess.open(trace_file_path, FileAccess.READ_WRITE)
	if file == null:
		file = FileAccess.open(trace_file_path, FileAccess.WRITE)
	if file == null:
		return
	file.seek_end()
	file.store_line(line)
	file.flush()
	file.close()
