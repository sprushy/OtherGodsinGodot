# NetworkManager.gd
extends Node

## Handles low-level networking and command routing.

signal command_received(command: Dictionary, sender_info: Dictionary)
signal game_event_received(event_type: String, data: Dictionary)
signal peer_connected(peer_id: int)
signal peer_disconnected(peer_id: int)

var peer: ENetMultiplayerPeer = ENetMultiplayerPeer.new()
var is_server: bool = false

## Maps player_index (0/1) to their ENet peer_id.
## Player 0 = host (peer_id 1), Player 1 = first remote client.
var player_peer_ids: Dictionary = {}

## The local player index on this machine (-1 until assigned).
var local_player_index: int = -1

func _ready() -> void:
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)

func _on_peer_connected(id: int) -> void:
	peer_connected.emit(id)

func _on_peer_disconnected(id: int) -> void:
	peer_disconnected.emit(id)

func create_server(port: int = 12345) -> Error:
	var err := (peer as ENetMultiplayerPeer).create_server(port)
	if err == OK:
		multiplayer.multiplayer_peer = peer
		is_server = true
		local_player_index = 0
		player_peer_ids[0] = 1  # server's own peer_id in ENet is always 1
		print("Server started on port ", port)
	return err

func create_client(address: String = "127.0.0.1", port: int = 12345) -> Error:
	var err := (peer as ENetMultiplayerPeer).create_client(address, port)
	if err == OK:
		multiplayer.multiplayer_peer = peer
		is_server = false
		print("Client connecting to ", address, ":", port)
	return err

# ---------------------------------------------------------------------------
# Client → server: submit a player action
# ---------------------------------------------------------------------------

@rpc("any_peer", "call_remote", "reliable")
func send_command(command: Dictionary) -> void:
	if is_server:
		var peer_id := multiplayer.get_remote_sender_id()
		command_received.emit(command, _build_sender_info(peer_id))

## Call from client to send an action to the server.
## If already the server (local host), processes directly.
func request_action(command: Dictionary) -> void:
	if is_server:
		command_received.emit(command, _build_sender_info(1))
	else:
		rpc_id(1, "send_command", command)

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

func get_player_index_for_peer(peer_id: int) -> int:
	for player_index in player_peer_ids.keys():
		if int(player_peer_ids[player_index]) == peer_id:
			return int(player_index)
	return -1

func _build_sender_info(peer_id: int) -> Dictionary:
	return {
		"peer_id": peer_id,
		"player_index": get_player_index_for_peer(peer_id),
		"is_host_peer": peer_id == 1,
	}
