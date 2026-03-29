extends RefCounted
class_name HeadlessMatchHost

## Owns the authoritative match transport/broadcast wiring.
## This keeps server responsibilities out of CombatMockGame's UI bootstrap.

const PromptRouterScript = preload("res://scripts/server/PromptRouter.gd")

signal game_event_received(event_type: String, data: Dictionary)
signal peer_disconnected(peer_id: int)

var game_manager: GameManager = null
var match_manager: MatchManager = null
var prompt_router = null
var network_manager: Node = null
var game_event_broadcaster: GameEventBroadcaster = null

var _is_host: bool = false
var _is_client: bool = false

func attach(p_game_manager: GameManager, p_match_manager: MatchManager, p_prompt_router) -> void:
	game_manager = p_game_manager
	match_manager = p_match_manager
	prompt_router = p_prompt_router

func setup_transport(
	parent: Node,
	is_host: bool = false,
	is_client: bool = false,
	server_ip: String = "127.0.0.1",
	server_port: int = 12345
) -> Node:
	_is_host = is_host
	_is_client = is_client

	var nm_script = load("res://scripts/Other/NetworkManager.gd")
	if nm_script == null:
		return null

	network_manager = Node.new()
	network_manager.set_script(nm_script)
	parent.add_child(network_manager)

	if is_host:
		network_manager.create_server(server_port)
	elif is_client:
		network_manager.create_client(server_ip, server_port)
	else:
		network_manager.is_server = true

	if match_manager != null:
		match_manager.network_manager = network_manager
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
	network_manager.peer_connected.connect(_on_peer_connected)

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

func _on_game_event_received(event_type: String, data: Dictionary) -> void:
	game_event_received.emit(event_type, data)

func _on_peer_disconnected(peer_id: int) -> void:
	peer_disconnected.emit(peer_id)
