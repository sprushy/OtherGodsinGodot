extends Node
class_name LobbyClient

const LobbyProtocolScript = preload("res://scripts/network/LobbyProtocol.gd")

signal connected_to_lobby()
signal login_succeeded(session_id: String, reconnect_token: String, player_name: String)
signal reconnect_succeeded(session_id: String, reconnect_token: String, player_name: String, room: Dictionary)
signal room_list_updated(rooms: Array)
signal room_snapshot_updated(snapshot: Dictionary)
signal room_error(message: String)
signal match_assigned(match_info: Dictionary)
signal connection_failed(message: String)
signal disconnected_from_lobby()

var peer: ENetMultiplayerPeer = ENetMultiplayerPeer.new()
var current_session_id: String = ""
var current_reconnect_token: String = ""
var current_player_name: String = "Guest"

var _pending_player_name: String = "Guest"
var _pending_session_id: String = ""
var _pending_reconnect_token: String = ""

func _ready() -> void:
	var api: MultiplayerAPI = _ensure_multiplayer_api()
	if api == null:
		return
	if not api.connected_to_server.is_connected(_on_connected_to_server):
		api.connected_to_server.connect(_on_connected_to_server)
	if not api.connection_failed.is_connected(_on_connection_failed):
		api.connection_failed.connect(_on_connection_failed)
	if not api.server_disconnected.is_connected(_on_server_disconnected):
		api.server_disconnected.connect(_on_server_disconnected)

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

	var err: Error = peer.create_client(connect_address, port)
	if err != OK:
		connection_failed.emit("Could not connect to %s:%d" % [connect_address, port])
		return err

	var api: MultiplayerAPI = _ensure_multiplayer_api()
	if api == null:
		connection_failed.emit("Could not initialize lobby multiplayer API.")
		return ERR_UNAVAILABLE
	api.multiplayer_peer = peer
	return OK

func disconnect_from_server() -> void:
	var api: MultiplayerAPI = _ensure_multiplayer_api()
	if api != null and api.multiplayer_peer != null:
		api.multiplayer_peer = null
	if peer != null:
		peer.close()
	peer = ENetMultiplayerPeer.new()

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

@rpc("any_peer", "call_remote", "reliable")
func lobby_request(_message: Dictionary) -> void:
	# Clients only send lobby_request; the server consumes it.
	pass

@rpc("authority", "call_remote", "reliable")
func lobby_event(message: Dictionary) -> void:
	var message_type: String = LobbyProtocolScript.get_type(message)
	var payload: Dictionary = LobbyProtocolScript.get_payload(message)

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
	connection_failed.emit("The lobby connection failed.")

func _on_server_disconnected() -> void:
	disconnected_from_lobby.emit()

func _send_request(message_type: String, payload: Dictionary = {}) -> void:
	var api: MultiplayerAPI = _ensure_multiplayer_api()
	if api == null or api.multiplayer_peer == null:
		return
	rpc_id(1, "lobby_request", LobbyProtocolScript.make_message(message_type, payload))

func _ensure_multiplayer_api() -> MultiplayerAPI:
	if multiplayer != null:
		return multiplayer
	if get_tree() == null:
		return null
	var fallback_api := MultiplayerAPI.create_default_interface()
	get_tree().set_multiplayer(fallback_api, get_path())
	return multiplayer
