extends RefCounted
class_name MatchClient

## Wraps the client's gameplay submission path and match event subscriptions.
## The current direct-connect flow still works, but CombatMockGame now depends
## on this boundary instead of talking to transport details directly.

signal game_event_received(event_type: String, data: Dictionary)
signal peer_disconnected(peer_id: int)

var match_manager: MatchManager = null
var network_manager: Node = null
var _receives_network_events: bool = false
var _is_networked_client: bool = false
var _game_input: GameInput = null

func _init(
	p_match_manager: MatchManager,
	p_network_manager: Node = null,
	p_receives_network_events: bool = false,
	p_is_networked_client: bool = false
) -> void:
	match_manager = p_match_manager
	network_manager = p_network_manager
	_receives_network_events = p_receives_network_events
	_is_networked_client = p_is_networked_client

	if _is_networked_client:
		_game_input = NetworkedGameInput.new(network_manager)
	else:
		_game_input = LocalGameInput.new(match_manager)

	if _receives_network_events and network_manager != null:
		network_manager.game_event_received.connect(_on_game_event_received)
		network_manager.peer_disconnected.connect(_on_peer_disconnected)

func get_game_input() -> GameInput:
	return _game_input

func is_networked_client() -> bool:
	return _is_networked_client

func receives_network_events() -> bool:
	return _receives_network_events

func get_local_player_index() -> int:
	if network_manager == null:
		return 0
	return network_manager.local_player_index

func _on_game_event_received(event_type: String, data: Dictionary) -> void:
	game_event_received.emit(event_type, data)

func _on_peer_disconnected(peer_id: int) -> void:
	peer_disconnected.emit(peer_id)
