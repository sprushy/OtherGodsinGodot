extends Node
class_name LobbyServer

const LobbyProtocolScript = preload("res://scripts/network/LobbyProtocol.gd")
const LobbyRoomScript = preload("res://scripts/server/LobbyRoom.gd")
const MatchSupervisorScript = preload("res://scripts/server/MatchSupervisor.gd")

signal local_room_snapshot_updated(snapshot: Dictionary)
signal room_list_updated(rooms: Array)
signal local_match_assigned(match_info: Dictionary)
signal status_changed(message: String)

var peer: ENetMultiplayerPeer = ENetMultiplayerPeer.new()
var advertised_host: String = "127.0.0.1"
var lobby_port: int = LobbyProtocolScript.PORT
var match_port: int = LobbyProtocolScript.MATCH_PORT
var is_listening: bool = false

var sessions_by_id: Dictionary = {}
var session_id_by_peer: Dictionary = {}
var rooms_by_id: Dictionary = {}
var room_id_by_session: Dictionary = {}
var local_session_id: String = ""
var match_supervisor = null

var _rng := RandomNumberGenerator.new()

func _ready() -> void:
	_rng.randomize()
	_ensure_match_supervisor()
	var api: MultiplayerAPI = _ensure_multiplayer_api()
	if api != null and not api.peer_disconnected.is_connected(_on_peer_disconnected):
		api.peer_disconnected.connect(_on_peer_disconnected)

func start_server(p_advertised_host: String = "127.0.0.1", port: int = LobbyProtocolScript.PORT, p_match_port: int = LobbyProtocolScript.MATCH_PORT) -> Error:
	if is_listening:
		return OK

	advertised_host = p_advertised_host.strip_edges()
	if advertised_host.is_empty():
		advertised_host = "127.0.0.1"

	lobby_port = port
	match_port = p_match_port
	_ensure_match_supervisor()
	if match_supervisor != null:
		match_supervisor.configure(advertised_host, match_port)

	var err := peer.create_server(lobby_port)
	if err != OK:
		status_changed.emit("Failed to start lobby server on port %d." % lobby_port)
		return err

	var api: MultiplayerAPI = _ensure_multiplayer_api()
	if api == null:
		status_changed.emit("Failed to initialize lobby multiplayer API.")
		return ERR_UNAVAILABLE
	api.multiplayer_peer = peer
	is_listening = true
	status_changed.emit("Lobby server listening on %s:%d" % [advertised_host, lobby_port])
	return OK

func stop_server() -> void:
	var api: MultiplayerAPI = _ensure_multiplayer_api()
	if api != null and api.multiplayer_peer != null:
		api.multiplayer_peer = null
	if peer != null:
		peer.close()
	peer = ENetMultiplayerPeer.new()
	is_listening = false
	advertised_host = "127.0.0.1"
	lobby_port = LobbyProtocolScript.PORT
	match_port = LobbyProtocolScript.MATCH_PORT
	sessions_by_id.clear()
	session_id_by_peer.clear()
	rooms_by_id.clear()
	room_id_by_session.clear()
	local_session_id = ""
	if match_supervisor != null:
		match_supervisor.clear()

func create_local_guest_session(player_name: String = "Host") -> Dictionary:
	var existing: Dictionary = _get_local_session()
	if not existing.is_empty():
		return existing.duplicate(true)

	var session: Dictionary = _create_session(player_name, 1, true)
	local_session_id = str(session.get("session_id", ""))
	return session.duplicate(true)

func create_room_for_local_session() -> Dictionary:
	if local_session_id.is_empty():
		return {}
	var room: LobbyRoom = _create_room_for_session(local_session_id)
	return room.to_snapshot(sessions_by_id)

func set_local_ready(is_ready: bool) -> void:
	if local_session_id.is_empty():
		return
	_set_ready_for_session(local_session_id, is_ready)

func get_local_room_snapshot() -> Dictionary:
	var room_id: String = str(room_id_by_session.get(local_session_id, ""))
	if room_id.is_empty() or not rooms_by_id.has(room_id):
		return {}
	var room: LobbyRoom = rooms_by_id[room_id]
	return room.to_snapshot(sessions_by_id)

@rpc("any_peer", "call_remote", "reliable")
func lobby_request(message: Dictionary) -> void:
	var api: MultiplayerAPI = _ensure_multiplayer_api()
	if api == null:
		return
	var peer_id: int = api.get_remote_sender_id()
	_handle_request(peer_id, message)

@rpc("authority", "call_remote", "reliable")
func lobby_event(_message: Dictionary) -> void:
	# Server only sends lobby_event; clients consume it.
	pass

func _handle_request(peer_id: int, message: Dictionary) -> void:
	var validation_error: String = LobbyProtocolScript.validate_request(message)
	if not validation_error.is_empty():
		_send_error_to_peer(peer_id, validation_error)
		return

	var message_type: String = LobbyProtocolScript.get_type(message)
	var payload: Dictionary = LobbyProtocolScript.get_payload(message)

	match message_type:
		LobbyProtocolScript.LOGIN_GUEST:
			_handle_login_guest(peer_id, payload)
		LobbyProtocolScript.CREATE_ROOM:
			var session: Dictionary = _get_session_for_peer(peer_id)
			if session.is_empty():
				_send_error_to_peer(peer_id, "Join the lobby before creating a room.")
				return
			var room: LobbyRoom = _create_room_for_session(str(session.get("session_id", "")))
			_broadcast_room_snapshot(room)
		LobbyProtocolScript.LIST_ROOMS:
			_send_room_list_to_peer(peer_id)
		LobbyProtocolScript.JOIN_ROOM:
			var join_session: Dictionary = _get_session_for_peer(peer_id)
			if join_session.is_empty():
				_send_error_to_peer(peer_id, "Join the lobby before entering a room.")
				return
			_join_room_for_session(str(join_session.get("session_id", "")), str(payload.get("room_id", "")))
		LobbyProtocolScript.LEAVE_ROOM:
			var leave_session: Dictionary = _get_session_for_peer(peer_id)
			if leave_session.is_empty():
				return
			_leave_room_for_session(str(leave_session.get("session_id", "")))
		LobbyProtocolScript.SET_READY:
			var ready_session: Dictionary = _get_session_for_peer(peer_id)
			if ready_session.is_empty():
				_send_error_to_peer(peer_id, "Join a room before changing ready state.")
				return
			_set_ready_for_session(str(ready_session.get("session_id", "")), bool(payload.get("is_ready", false)))
		LobbyProtocolScript.REQUEST_RECONNECT_LOBBY:
			_handle_reconnect_request(peer_id, payload)

func _handle_login_guest(peer_id: int, payload: Dictionary) -> void:
	var existing: Dictionary = _get_session_for_peer(peer_id)
	if existing.is_empty():
		existing = _create_session(str(payload.get("player_name", "Guest")), peer_id, false)

	_send_to_peer(peer_id, LobbyProtocolScript.HELLO_OK, {
		"session_id": str(existing.get("session_id", "")),
		"reconnect_token": str(existing.get("reconnect_token", "")),
		"player_name": str(existing.get("player_name", "Guest")),
	})
	_send_room_list_to_peer(peer_id)

func _handle_reconnect_request(peer_id: int, payload: Dictionary) -> void:
	var session_id: String = str(payload.get("session_id", "")).strip_edges()
	var reconnect_token: String = str(payload.get("reconnect_token", "")).strip_edges()
	var session: Dictionary = sessions_by_id.get(session_id, {})

	if session.is_empty():
		_send_error_to_peer(peer_id, "Lobby session not found.")
		return
	if str(session.get("reconnect_token", "")) != reconnect_token:
		_send_error_to_peer(peer_id, "Reconnect token did not match.")
		return

	var previous_peer_id: int = int(session.get("peer_id", 0))
	if previous_peer_id > 0:
		session_id_by_peer.erase(previous_peer_id)

	session["peer_id"] = peer_id
	session["connected"] = true
	sessions_by_id[session_id] = session
	session_id_by_peer[peer_id] = session_id

	var room_snapshot: Dictionary = {}
	var room_id: String = str(room_id_by_session.get(session_id, ""))
	if not room_id.is_empty() and rooms_by_id.has(room_id):
		var room: LobbyRoom = rooms_by_id[room_id]
		room_snapshot = room.to_snapshot(sessions_by_id)
		_broadcast_room_snapshot(room)
	else:
		_send_room_list_to_peer(peer_id)

	_send_to_peer(peer_id, LobbyProtocolScript.LOBBY_RECONNECT_OK, {
		"session_id": session_id,
		"reconnect_token": reconnect_token,
		"player_name": str(session.get("player_name", "Guest")),
		"room": room_snapshot,
	})

func _create_session(player_name: String, peer_id: int, is_local: bool) -> Dictionary:
	var clean_name: String = player_name.strip_edges()
	if clean_name.is_empty():
		clean_name = "Guest"

	var session_id: String = _generate_id(12)
	while sessions_by_id.has(session_id):
		session_id = _generate_id(12)

	var reconnect_token: String = _generate_id(18)
	var session := {
		"session_id": session_id,
		"reconnect_token": reconnect_token,
		"player_name": clean_name,
		"peer_id": peer_id,
		"connected": true,
		"is_local": is_local,
	}
	sessions_by_id[session_id] = session
	if peer_id > 0 and not is_local:
		session_id_by_peer[peer_id] = session_id
	return session

func _create_room_for_session(session_id: String) -> LobbyRoom:
	var existing_room_id: String = str(room_id_by_session.get(session_id, ""))
	if not existing_room_id.is_empty() and rooms_by_id.has(existing_room_id):
		return rooms_by_id[existing_room_id]

	var room_id: String = _generate_room_code()
	while rooms_by_id.has(room_id):
		room_id = _generate_room_code()

	var room: LobbyRoom = LobbyRoomScript.new(room_id, session_id)
	room.add_member(session_id)
	rooms_by_id[room_id] = room
	room_id_by_session[session_id] = room_id
	_emit_room_updates(room)
	return room

func _join_room_for_session(session_id: String, room_id: String) -> void:
	var normalized_room_id: String = room_id.strip_edges().to_upper()
	if normalized_room_id.is_empty():
		_send_error_to_session(session_id, "Enter a room code first.")
		return
	if not rooms_by_id.has(normalized_room_id):
		_send_error_to_session(session_id, "Room %s was not found." % normalized_room_id)
		return
	if room_id_by_session.has(session_id):
		var current_room_id: String = str(room_id_by_session.get(session_id, ""))
		if current_room_id == normalized_room_id:
			_broadcast_room_snapshot(rooms_by_id[normalized_room_id])
			return
		_send_error_to_session(session_id, "Leave your current room before joining a new one.")
		return

	var room: LobbyRoom = rooms_by_id[normalized_room_id]
	if room.status == LobbyRoomScript.STATUS_IN_MATCH:
		_send_error_to_session(session_id, "Room %s is already in a match." % normalized_room_id)
		return
	if room.is_full():
		_send_error_to_session(session_id, "Room %s is already full." % normalized_room_id)
		return

	if not room.add_member(session_id):
		_send_error_to_session(session_id, "Unable to join room %s." % normalized_room_id)
		return

	room_id_by_session[session_id] = normalized_room_id
	_emit_room_updates(room)

func _leave_room_for_session(session_id: String) -> void:
	var room_id: String = str(room_id_by_session.get(session_id, ""))
	if room_id.is_empty() or not rooms_by_id.has(room_id):
		return

	var room: LobbyRoom = rooms_by_id[room_id]
	room.remove_member(session_id)
	room_id_by_session.erase(session_id)

	if room.is_empty():
		rooms_by_id.erase(room_id)
		_broadcast_room_lists()
		return

	_emit_room_updates(room)

func _set_ready_for_session(session_id: String, is_ready: bool) -> void:
	var room_id: String = str(room_id_by_session.get(session_id, ""))
	if room_id.is_empty() or not rooms_by_id.has(room_id):
		_send_error_to_session(session_id, "Join a room before readying up.")
		return

	var room: LobbyRoom = rooms_by_id[room_id]
	if not room.set_ready(session_id, is_ready):
		_send_error_to_session(session_id, "Unable to update ready state.")
		return

	_emit_room_updates(room)
	if room.can_start() and room.status != LobbyRoomScript.STATUS_IN_MATCH:
		_assign_match(room)

func _assign_match(room: LobbyRoom) -> void:
	_ensure_match_supervisor()
	if match_supervisor == null:
		_send_error_to_session(room.host_session_id, "Match supervisor is unavailable.")
		return

	var match_session = match_supervisor.create_match(room.room_id, room.members)
	room.status = LobbyRoomScript.STATUS_IN_MATCH
	room.assigned_match_id = match_session.match_id
	var local_match_info: Dictionary = {}

	for session_id in room.members:
		var match_info: Dictionary = match_session.to_match_info(session_id)
		_send_to_session(session_id, LobbyProtocolScript.MATCH_ASSIGNED, match_info)
		if session_id == local_session_id:
			local_match_info = match_info.duplicate(true)
	_emit_room_updates(room)
	if not local_match_info.is_empty():
		call_deferred("_emit_local_match_assigned", local_match_info)

func _emit_room_updates(room: LobbyRoom) -> void:
	_broadcast_room_snapshot(room)
	_broadcast_room_lists()

func _broadcast_room_snapshot(room: LobbyRoom) -> void:
	var snapshot: Dictionary = room.to_snapshot(sessions_by_id)
	for session_id in room.members:
		_send_to_session(session_id, LobbyProtocolScript.ROOM_SNAPSHOT, snapshot)
		if session_id == local_session_id:
			local_room_snapshot_updated.emit(snapshot)

func _broadcast_room_lists() -> void:
	var rooms: Array = _build_room_list()
	for peer_id in session_id_by_peer.keys():
		_send_to_peer(int(peer_id), LobbyProtocolScript.ROOM_LIST, {"rooms": rooms})
	room_list_updated.emit(rooms)

func _send_room_list_to_peer(peer_id: int) -> void:
	_send_to_peer(peer_id, LobbyProtocolScript.ROOM_LIST, {"rooms": _build_room_list()})

func _build_room_list() -> Array:
	var rooms: Array = []
	for room_id in rooms_by_id.keys():
		rooms.append(rooms_by_id[room_id].to_room_list_entry(sessions_by_id))
	return rooms

func _send_to_session(session_id: String, message_type: String, payload: Dictionary) -> void:
	var session: Dictionary = sessions_by_id.get(session_id, {})
	if session.is_empty():
		return
	if bool(session.get("is_local", false)):
		return
	var target_peer_id: int = int(session.get("peer_id", 0))
	if target_peer_id <= 0 or not bool(session.get("connected", false)):
		return
	_send_to_peer(target_peer_id, message_type, payload)

func _send_to_peer(peer_id: int, message_type: String, payload: Dictionary) -> void:
	var api: MultiplayerAPI = _ensure_multiplayer_api()
	if peer_id <= 0 or api == null or api.multiplayer_peer == null:
		return
	rpc_id(peer_id, "lobby_event", LobbyProtocolScript.make_message(message_type, payload))

func _send_error_to_session(session_id: String, message: String) -> void:
	var session: Dictionary = sessions_by_id.get(session_id, {})
	if session.is_empty():
		return
	if bool(session.get("is_local", false)) and session_id == local_session_id:
		status_changed.emit(message)
	if not bool(session.get("is_local", false)) and int(session.get("peer_id", 0)) > 0:
		_send_to_peer(int(session.get("peer_id", 0)), LobbyProtocolScript.ROOM_ERROR, {"message": message})

func _send_error_to_peer(peer_id: int, message: String) -> void:
	_send_to_peer(peer_id, LobbyProtocolScript.ROOM_ERROR, {"message": message})

func _get_session_for_peer(peer_id: int) -> Dictionary:
	var session_id: String = str(session_id_by_peer.get(peer_id, ""))
	if session_id.is_empty():
		return {}
	return sessions_by_id.get(session_id, {})

func _get_local_session() -> Dictionary:
	if local_session_id.is_empty():
		return {}
	return sessions_by_id.get(local_session_id, {})

func _on_peer_disconnected(peer_id: int) -> void:
	var session_id: String = str(session_id_by_peer.get(peer_id, ""))
	if session_id.is_empty():
		return

	session_id_by_peer.erase(peer_id)
	if not sessions_by_id.has(session_id):
		return

	var session: Dictionary = sessions_by_id[session_id]
	session["peer_id"] = 0
	session["connected"] = false
	sessions_by_id[session_id] = session

	var room_id: String = str(room_id_by_session.get(session_id, ""))
	if not room_id.is_empty() and rooms_by_id.has(room_id):
		var room: LobbyRoom = rooms_by_id[room_id]
		_broadcast_room_snapshot(room)
	_broadcast_room_lists()

func _generate_room_code() -> String:
	return _generate_id(6)

func _generate_id(length: int) -> String:
	const CHARS := "ABCDEFGHJKLMNPQRSTUVWXYZ23456789"
	var output: String = ""
	for _i in length:
		output += CHARS[_rng.randi_range(0, CHARS.length() - 1)]
	return output

func _emit_local_match_assigned(match_info: Dictionary) -> void:
	local_match_assigned.emit(match_info)

func _ensure_match_supervisor() -> void:
	if match_supervisor != null:
		return
	match_supervisor = MatchSupervisorScript.new()
	match_supervisor.name = "MatchSupervisor"
	add_child(match_supervisor)
	match_supervisor.configure(advertised_host, match_port)

func _ensure_multiplayer_api() -> MultiplayerAPI:
	if multiplayer != null:
		return multiplayer
	if get_tree() == null:
		return null
	var fallback_api := MultiplayerAPI.create_default_interface()
	get_tree().set_multiplayer(fallback_api, get_path())
	return multiplayer
