extends RefCounted
class_name MatchClient

## Wraps the client's gameplay submission path and match event subscriptions.
## The current direct-connect flow still works, but CombatMockGame now depends
## on this boundary instead of talking to transport details directly.

signal game_event_received(event_type: String, data: Dictionary)
signal peer_disconnected(peer_id: int)
signal match_join_failed(reason: String)
signal server_disconnected()

var match_manager: MatchManager = null
var network_manager: Node = null
var _receives_network_events: bool = false
var _is_networked_client: bool = false
var _game_input: GameInput = null
var _match_info: Dictionary = {}
var _server_ip: String = "127.0.0.1"
var _server_port: int = 12345
var _reconnect_attempts_remaining: int = 0
var _is_reconnecting: bool = false

func _init(
	p_match_manager: MatchManager,
	p_network_manager: Node = null,
	p_receives_network_events: bool = false,
	p_is_networked_client: bool = false,
	p_match_info: Dictionary = {},
	p_server_ip: String = "127.0.0.1",
	p_server_port: int = 12345
) -> void:
	match_manager = p_match_manager
	network_manager = p_network_manager
	_receives_network_events = p_receives_network_events
	_is_networked_client = p_is_networked_client
	_match_info = p_match_info.duplicate(true)
	_server_ip = p_server_ip
	_server_port = p_server_port
	if requires_match_auth():
		_reconnect_attempts_remaining = 2

	if _is_networked_client:
		_game_input = NetworkedGameInput.new(network_manager)
	else:
		_game_input = LocalGameInput.new(match_manager)

	if _receives_network_events and network_manager != null:
		network_manager.game_event_received.connect(_on_game_event_received)
		network_manager.peer_disconnected.connect(_on_peer_disconnected)
		if network_manager.has_signal("connected_to_server"):
			network_manager.connected_to_server.connect(_on_connected_to_server)
		if network_manager.has_signal("match_join_approved"):
			network_manager.match_join_approved.connect(_on_match_join_approved)
		if network_manager.has_signal("match_join_denied"):
			network_manager.match_join_denied.connect(_on_match_join_denied)
		if network_manager.has_signal("server_disconnected"):
			network_manager.server_disconnected.connect(_on_server_disconnected)
		if network_manager.has_signal("connection_failed"):
			network_manager.connection_failed.connect(_on_connection_failed)

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

func requires_match_auth() -> bool:
	return _is_networked_client and not _match_info.is_empty() and str(_match_info.get("match_token", "")).strip_edges() != ""

func _on_connected_to_server() -> void:
	if not requires_match_auth() or network_manager == null:
		return
	network_manager.submit_match_join({
		"match_id": str(_match_info.get("match_id", "")),
		"session_id": str(_match_info.get("session_id", "")),
		"match_token": str(_match_info.get("match_token", "")),
	})

func _on_match_join_approved(match_info: Dictionary) -> void:
	var was_reconnecting := _is_reconnecting
	_match_info.merge(match_info, true)
	_is_reconnecting = false
	_reconnect_attempts_remaining = 2 if requires_match_auth() else 0
	if str(match_info.get("server_ip", "")).strip_edges() != "":
		_server_ip = str(match_info.get("server_ip", _server_ip))
	if int(match_info.get("match_port", 0)) > 0:
		_server_port = int(match_info.get("match_port", _server_port))
	if requires_match_auth() and int(match_info.get("reconnect_window_seconds", 0)) > 0:
		_reconnect_attempts_remaining = 2
	if was_reconnecting:
		game_event_received.emit("match_reconnect_ok", match_info)
	game_event_received.emit("match_join_ok", match_info)

func _on_match_join_denied(reason: String) -> void:
	var was_reconnecting := _is_reconnecting
	_is_reconnecting = false
	match_join_failed.emit(reason)
	if was_reconnecting:
		game_event_received.emit("match_reconnect_failed", {"reason": reason})
	game_event_received.emit("match_join_denied", {"reason": reason})

func _on_server_disconnected() -> void:
	if _try_reconnect():
		return
	server_disconnected.emit()
	game_event_received.emit("server_disconnected", {})

func _on_connection_failed() -> void:
	if _is_reconnecting:
		_is_reconnecting = false
		game_event_received.emit("match_reconnect_failed", {
			"reason": "Reconnect attempt failed.",
		})
		return

func _try_reconnect() -> bool:
	if not requires_match_auth() or network_manager == null:
		return false
	if _reconnect_attempts_remaining <= 0:
		return false
	_reconnect_attempts_remaining -= 1
	_is_reconnecting = true
	game_event_received.emit("match_reconnect_started", {
		"attempts_remaining": _reconnect_attempts_remaining,
	})
	var reconnect_err: Error = network_manager.reconnect_client(_server_ip, _server_port)
	if reconnect_err == OK:
		return true
	_is_reconnecting = false
	game_event_received.emit("match_reconnect_failed", {
		"reason": "Reconnect attempt failed.",
	})
	return false

func _on_game_event_received(event_type: String, data: Dictionary) -> void:
	game_event_received.emit(event_type, data)

func _on_peer_disconnected(peer_id: int) -> void:
	peer_disconnected.emit(peer_id)
