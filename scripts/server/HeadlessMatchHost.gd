extends RefCounted
class_name HeadlessMatchHost

## Owns the authoritative match transport/broadcast wiring.
## This keeps server responsibilities out of CombatMockGame's UI bootstrap.

const PromptRouterScript = preload("res://scripts/server/PromptRouter.gd")
const NETWORK_MANAGER_NODE_NAME := "MatchNetworkManager"

signal game_event_received(event_type: String, data: Dictionary)
signal peer_disconnected(peer_id: int)
signal match_player_authenticated(player_index: int, session_id: String, was_reconnect: bool)

var game_manager: GameManager = null
var match_manager: MatchManager = null
var prompt_router = null
var network_manager: Node = null
var game_event_broadcaster: GameEventBroadcaster = null
var match_session = null

var _is_host: bool = false
var _is_client: bool = false

func attach(p_game_manager: GameManager, p_match_manager: MatchManager, p_prompt_router) -> void:
	game_manager = p_game_manager
	match_manager = p_match_manager
	prompt_router = p_prompt_router

func configure_match_session(p_match_session) -> void:
	match_session = p_match_session

func setup_transport(
	parent: Node,
	is_host: bool = false,
	is_client: bool = false,
	server_ip: String = "127.0.0.1",
	server_port: int = 12345,
	assign_local_host_player: bool = true
) -> Node:
	_is_host = is_host
	_is_client = is_client

	var nm_script = load("res://scripts/Other/NetworkManager.gd")
	if nm_script == null:
		return null

	if parent == null or parent.get_tree() == null:
		return null
	var transport_root: Node = parent.get_tree().root
	var existing_transport := transport_root.get_node_or_null(NETWORK_MANAGER_NODE_NAME)
	if existing_transport != null:
		if existing_transport.get_parent() != null:
			existing_transport.get_parent().remove_child(existing_transport)
		existing_transport.queue_free()

	network_manager = nm_script.new()
	network_manager.name = NETWORK_MANAGER_NODE_NAME
	transport_root.add_child(network_manager)

	if is_host:
		network_manager.create_server(server_port, assign_local_host_player)
	elif is_client:
		network_manager.create_client(server_ip, server_port)
	else:
		network_manager.is_server = true
		network_manager.local_player_index = 0
		network_manager.player_peer_ids.clear()
		network_manager.player_peer_ids[0] = 1

	if match_manager != null:
		match_manager.network_manager = network_manager
		match_manager.authoritative_match_flow_enabled = is_host
		network_manager.command_received.connect(func(command: Dictionary, sender_info: Dictionary) -> void:
			match_manager.process_command(command, sender_info)
		)

	if is_host or is_client:
		network_manager.game_event_received.connect(_on_game_event_received)
		network_manager.peer_disconnected.connect(_on_peer_disconnected)

	return network_manager

func enable_authoritative_broadcasts() -> void:
	if network_manager == null or not _is_host or game_manager == null or match_manager == null:
		return
	game_event_broadcaster = GameEventBroadcaster.new(game_manager, match_manager, network_manager, prompt_router)
	if match_session == null:
		network_manager.peer_connected.connect(_on_peer_connected)
	else:
		network_manager.match_join_requested.connect(_on_match_join_requested)

func should_route_prompts_via_network() -> bool:
	return network_manager != null and _is_host

func should_receive_network_events() -> bool:
	return network_manager != null and (_is_host or _is_client)

func is_networked_client() -> bool:
	return _is_client

func _on_peer_connected(peer_id: int) -> void:
	network_manager.assign_peer_to_player(peer_id, 1)
	var state := GameState.serialize(game_manager, 1)
	network_manager.broadcast_event_to_peer(peer_id, "full_state", {
		state = state,
		action_message = "Connected! Syncing game state.",
	})

func _on_match_join_requested(join_request: Dictionary, sender_info: Dictionary) -> void:
	if network_manager == null or match_session == null:
		return
	var peer_id := int(sender_info.get("peer_id", -1))
	if peer_id <= 0:
		return
	var match_id := str(join_request.get("match_id", "")).strip_edges()
	var session_id := str(join_request.get("session_id", "")).strip_edges()
	var match_token := str(join_request.get("match_token", "")).strip_edges()
	if match_id != str(match_session.match_id):
		network_manager.deny_match_join(peer_id, "That match ID is no longer valid.")
		return
	var was_reconnect: bool = match_session.is_session_waiting_for_reconnect(session_id)
	var player_index := int(match_session.authenticate_join(session_id, match_token, peer_id))
	if player_index == -1:
		network_manager.deny_match_join(peer_id, "Match authentication failed.")
		return
	var join_info: Dictionary = match_session.to_match_info(session_id)
	network_manager.approve_match_join(peer_id, player_index, join_info)
	match_player_authenticated.emit(player_index, session_id, was_reconnect)
	if was_reconnect:
		_broadcast_match_event("peer_rejoined", {
			"player_index": player_index,
			"session_id": session_id,
		})
	var state := GameState.serialize(game_manager, player_index)
	network_manager.broadcast_event_to_peer(peer_id, "full_state", {
		state = state,
		action_message = "Connected! Syncing game state.",
	})

func _on_game_event_received(event_type: String, data: Dictionary) -> void:
	game_event_received.emit(event_type, data)

func _on_peer_disconnected(peer_id: int) -> void:
	if match_session != null:
		network_manager.unassign_peer(peer_id)
		var disconnect_info: Dictionary = match_session.note_peer_disconnected(peer_id)
		if not disconnect_info.is_empty():
			_broadcast_match_event("peer_left", disconnect_info)
	peer_disconnected.emit(peer_id)

func _broadcast_match_event(event_type: String, data: Dictionary) -> void:
	if network_manager == null:
		return
	network_manager.game_event_received.emit(event_type, data)
	for player_index in network_manager.player_peer_ids.keys():
		var peer_id := int(network_manager.player_peer_ids[player_index])
		if peer_id == 1:
			continue
		network_manager.broadcast_event_to_peer(peer_id, event_type, data)
