# NetworkManager.gd
extends Node

## Handles low-level networking and command routing.

signal command_received(command: Dictionary, sender_info: Dictionary)
signal game_event_received(event_type: String, data: Dictionary)
signal peer_connected(peer_id: int)
signal peer_disconnected(peer_id: int)
signal connected_to_server()
signal connection_failed()
signal server_disconnected()
signal match_join_requested(join_request: Dictionary, sender_info: Dictionary)
signal match_join_approved(match_info: Dictionary)
signal match_join_denied(reason: String)

var peer: ENetMultiplayerPeer = ENetMultiplayerPeer.new()
var is_server: bool = false
var last_client_address: String = "127.0.0.1"
var last_client_port: int = 12345
var last_server_error: int = OK
var trace_file_path: String = ""
var use_current_scene_relative_path: bool = false

## Maps player_index (0/1) to their ENet peer_id.
## Player 0 = host (peer_id 1), Player 1 = first remote client.
var player_peer_ids: Dictionary = {}
var spectator_peer_ids: Array[int] = []

## The local player index on this machine (-1 until assigned).
var local_player_index: int = -1

func _ready() -> void:
	var api := _ensure_multiplayer_api()
	if api == null:
		return
	api.peer_connected.connect(_on_peer_connected)
	api.peer_disconnected.connect(_on_peer_disconnected)
	api.connected_to_server.connect(_on_connected_to_server)
	api.connection_failed.connect(_on_connection_failed)
	api.server_disconnected.connect(_on_server_disconnected)

func _on_peer_connected(id: int) -> void:
	peer_connected.emit(id)

func _on_peer_disconnected(id: int) -> void:
	peer_disconnected.emit(id)

func _on_connected_to_server() -> void:
	_trace("connected_to_server")
	connected_to_server.emit()

func _on_connection_failed() -> void:
	_trace("connection_failed")
	connection_failed.emit()

func _on_server_disconnected() -> void:
	_trace("server_disconnected")
	server_disconnected.emit()

func create_server(port: int = 12345, assign_local_host_player: bool = true) -> Error:
	var api := _ensure_multiplayer_api()
	if api == null:
		last_server_error = ERR_UNAVAILABLE
		_trace("create_server failed: multiplayer unavailable")
		return ERR_UNAVAILABLE
	var err := (peer as ENetMultiplayerPeer).create_server(port)
	last_server_error = err
	if err == OK:
		api.multiplayer_peer = peer
		is_server = true
		local_player_index = 0 if assign_local_host_player else -1
		player_peer_ids.clear()
		if assign_local_host_player:
			player_peer_ids[0] = 1  # server's own peer_id in ENet is always 1
		print("Server started on port ", port)
		_trace("server started on port %d path=%s" % [port, str(get_path())])
	return err

func create_client(address: String = "127.0.0.1", port: int = 12345) -> Error:
	last_client_address = address
	last_client_port = port
	var api := _ensure_multiplayer_api()
	if api == null:
		_trace("create_client failed: multiplayer unavailable")
		return ERR_UNAVAILABLE
	var err := (peer as ENetMultiplayerPeer).create_client(address, port)
	if err == OK:
		api.multiplayer_peer = peer
		is_server = false
		print("Client connecting to ", address, ":", port)
		_trace("client connecting to %s:%d path=%s" % [address, port, str(get_path())])
	return err

func disconnect_client() -> void:
	var api := _ensure_multiplayer_api()
	if api != null and api.multiplayer_peer != null:
		api.multiplayer_peer = null
	if peer != null:
		peer.close()
	peer = ENetMultiplayerPeer.new()
	is_server = false
	local_player_index = -1
	player_peer_ids.clear()
	spectator_peer_ids.clear()
	last_server_error = OK

func reconnect_client(address: String = "", port: int = -1) -> Error:
	var connect_address := address.strip_edges()
	if connect_address.is_empty():
		connect_address = last_client_address
	var connect_port := port if port > 0 else last_client_port
	disconnect_client()
	return create_client(connect_address, connect_port)

# ---------------------------------------------------------------------------
# Client → server: submit a player action
# ---------------------------------------------------------------------------

@rpc("any_peer", "call_remote", "reliable")
func send_command(command: Dictionary) -> void:
	if is_server:
		var peer_id := multiplayer.get_remote_sender_id()
		_trace("received send_command from peer %d" % peer_id)
		command_received.emit(command, _build_sender_info(peer_id))

## Call from client to send an action to the server.
## If already the server (local host), processes directly.
func request_action(command: Dictionary) -> void:
	if is_server:
		command_received.emit(command, _build_sender_info(1))
	else:
		_trace("sending request_action %s" % str(command.get("type", command)))
		rpc_id(1, "send_command", command)

@rpc("any_peer", "call_remote", "reliable")
func request_match_join(join_request: Dictionary) -> void:
	if not is_server:
		return
	var peer_id := multiplayer.get_remote_sender_id()
	match_join_requested.emit(join_request, _build_sender_info(peer_id))

func submit_match_join(join_request: Dictionary) -> void:
	if is_server:
		match_join_requested.emit(join_request, _build_sender_info(1))
	else:
		rpc_id(1, "request_match_join", join_request)

@rpc("authority", "call_remote", "reliable")
func notify_match_join_approved(match_info: Dictionary) -> void:
	match_join_approved.emit(match_info)

@rpc("authority", "call_remote", "reliable")
func notify_match_join_denied(reason: String) -> void:
	match_join_denied.emit(reason)

# ---------------------------------------------------------------------------
# Server → all clients: broadcast a game event
# ---------------------------------------------------------------------------

@rpc("authority", "call_remote", "reliable")
func broadcast_event(event_type: String, data: Dictionary) -> void:
	game_event_received.emit(event_type, data)

## Server broadcasts the same event to every connected remote peer.
func broadcast_event_to_all(event_type: String, data: Dictionary) -> void:
	if not is_server:
		return
	rpc("broadcast_event", event_type, data)

## Server sends an event to one specific peer only (for hand privacy).
func broadcast_event_to_peer(target_peer_id: int, event_type: String, data: Dictionary) -> void:
	if not is_server:
		return
	rpc_id(target_peer_id, "broadcast_event", event_type, data)

# ---------------------------------------------------------------------------
# Server → client: tell a client which player index they are
# ---------------------------------------------------------------------------

@rpc("authority", "call_remote", "reliable")
func set_local_player_index(player_index: int) -> void:
	local_player_index = player_index
	print("Assigned as player ", player_index)

## Called by the server to register a new peer as a player and notify them.
func assign_peer_to_player(target_peer_id: int, player_index: int) -> void:
	if not is_server:
		return
	player_peer_ids[player_index] = target_peer_id
	rpc_id(target_peer_id, "set_local_player_index", player_index)

func approve_match_join(target_peer_id: int, player_index: int, match_info: Dictionary = {}) -> void:
	if not is_server:
		return
	if player_index >= 0:
		player_peer_ids[player_index] = target_peer_id
		spectator_peer_ids.erase(target_peer_id)
		rpc_id(target_peer_id, "set_local_player_index", player_index)
	else:
		register_spectator_peer(target_peer_id)
	rpc_id(target_peer_id, "notify_match_join_approved", match_info)

func deny_match_join(target_peer_id: int, reason: String) -> void:
	if not is_server or target_peer_id <= 0:
		return
	rpc_id(target_peer_id, "notify_match_join_denied", reason)

func unassign_peer(peer_id: int) -> void:
	spectator_peer_ids.erase(peer_id)
	for player_index in player_peer_ids.keys():
		if int(player_peer_ids[player_index]) != peer_id:
			continue
		if int(player_index) == 0 and peer_id == 1:
			continue
		player_peer_ids.erase(player_index)
		return

func get_player_index_for_peer(peer_id: int) -> int:
	for player_index in player_peer_ids.keys():
		if int(player_peer_ids[player_index]) == peer_id:
			return int(player_index)
	return -1

func register_spectator_peer(peer_id: int) -> void:
	if peer_id <= 0 or spectator_peer_ids.has(peer_id):
		return
	spectator_peer_ids.append(peer_id)

func is_spectator_peer(peer_id: int) -> bool:
	return spectator_peer_ids.has(peer_id)

func _build_sender_info(peer_id: int) -> Dictionary:
	return {
		"peer_id": peer_id,
		"player_index": get_player_index_for_peer(peer_id),
		"is_host_peer": peer_id == 1,
	}

func _ensure_multiplayer_api() -> MultiplayerAPI:
	if multiplayer != null:
		return multiplayer
	if get_tree() == null:
		return null
	var fallback_api := MultiplayerAPI.create_default_interface()
	var target_path: NodePath = get_path()
	if use_current_scene_relative_path and get_tree().current_scene != null:
		var active_scene: Node = get_tree().current_scene
		if active_scene == self:
			target_path = NodePath(".")
		elif active_scene.is_ancestor_of(self):
			target_path = active_scene.get_path_to(self)
	get_tree().set_multiplayer(fallback_api, target_path)
	return multiplayer

func _trace(message: String) -> void:
	if trace_file_path.is_empty():
		return
	var file := FileAccess.open(trace_file_path, FileAccess.READ_WRITE)
	if file == null:
		file = FileAccess.open(trace_file_path, FileAccess.WRITE)
	if file == null:
		return
	file.seek_end()
	file.store_line("NetworkManager[%s]: %s" % [name, message])
	file.flush()
	file.close()
