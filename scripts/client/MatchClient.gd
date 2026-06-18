extends RefCounted
class_name MatchClient

## Wraps the client's gameplay submission path and match event subscriptions.
## The current direct-connect flow still works, but CombatMockGame now depends
## on this boundary instead of talking to transport details directly.

const CONNECT_ATTEMPT_TIMEOUT_SECONDS := 5.0

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
var _is_retrying_initial_connect: bool = false
var _match_join_requested: bool = false
var _has_authenticated_match: bool = false
var _connect_attempt_serial: int = 0
var _reconnect_attempt_serial: int = 0
var _match_completed: bool = false
var _series_between_games: bool = false

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
	_try_submit_match_join_if_already_connected()
	_arm_connect_timeout_if_connecting()

func get_game_input() -> GameInput:
	return _game_input

func is_networked_client() -> bool:
	return _is_networked_client

func receives_network_events() -> bool:
	return _receives_network_events

func shutdown() -> void:
	_cancel_connect_attempt_timeout()
	_reconnect_attempt_serial += 1
	_reconnect_attempts_remaining = 0
	_is_reconnecting = false
	_is_retrying_initial_connect = false
	_match_join_requested = false
	_has_authenticated_match = false
	_match_completed = false
	if not _receives_network_events or network_manager == null:
		return
	if network_manager.has_signal("game_event_received") and network_manager.game_event_received.is_connected(_on_game_event_received):
		network_manager.game_event_received.disconnect(_on_game_event_received)
	if network_manager.has_signal("peer_disconnected") and network_manager.peer_disconnected.is_connected(_on_peer_disconnected):
		network_manager.peer_disconnected.disconnect(_on_peer_disconnected)
	if network_manager.has_signal("connected_to_server") and network_manager.connected_to_server.is_connected(_on_connected_to_server):
		network_manager.connected_to_server.disconnect(_on_connected_to_server)
	if network_manager.has_signal("match_join_approved") and network_manager.match_join_approved.is_connected(_on_match_join_approved):
		network_manager.match_join_approved.disconnect(_on_match_join_approved)
	if network_manager.has_signal("match_join_denied") and network_manager.match_join_denied.is_connected(_on_match_join_denied):
		network_manager.match_join_denied.disconnect(_on_match_join_denied)
	if network_manager.has_signal("server_disconnected") and network_manager.server_disconnected.is_connected(_on_server_disconnected):
		network_manager.server_disconnected.disconnect(_on_server_disconnected)
	if network_manager.has_signal("connection_failed") and network_manager.connection_failed.is_connected(_on_connection_failed):
		network_manager.connection_failed.disconnect(_on_connection_failed)
	_receives_network_events = false

func get_local_player_index() -> int:
	if network_manager == null:
		return 0
	return network_manager.local_player_index

func requires_match_auth() -> bool:
	if not _is_networked_client or _match_info.is_empty():
		return false
	if bool(_match_info.get("observer_mode", false)):
		return not str(_match_info.get("observer_match_token", "")).strip_edges().is_empty()
	return str(_match_info.get("match_token", "")).strip_edges() != ""

func _on_connected_to_server() -> void:
	_cancel_connect_attempt_timeout()
	_is_retrying_initial_connect = false
	_submit_match_join_request()

func _on_match_join_approved(match_info: Dictionary) -> void:
	_cancel_connect_attempt_timeout()
	_reconnect_attempt_serial += 1
	var was_reconnecting := _is_reconnecting
	_match_info.merge(match_info, true)
	_is_reconnecting = false
	_is_retrying_initial_connect = false
	_match_join_requested = false
	_has_authenticated_match = true
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
	_cancel_connect_attempt_timeout()
	_reconnect_attempt_serial += 1
	var was_reconnecting := _is_reconnecting
	_is_reconnecting = false
	_is_retrying_initial_connect = false
	_match_join_requested = false
	_has_authenticated_match = false
	match_join_failed.emit(reason)
	if was_reconnecting:
		game_event_received.emit("match_reconnect_failed", {"reason": reason})
	game_event_received.emit("match_join_denied", {"reason": reason})

func _on_server_disconnected() -> void:
	_cancel_connect_attempt_timeout()
	_match_join_requested = false
	if _match_completed:
		return
	if _is_reconnecting:
		return
	if _try_reconnect():
		return
	server_disconnected.emit()
	game_event_received.emit("server_disconnected", {})

func _on_connection_failed() -> void:
	_handle_connection_failure("Could not connect to the match server.", "Reconnect attempt failed.")

func _on_connect_attempt_timeout() -> void:
	if network_manager == null:
		return
	var multiplayer_api = network_manager.multiplayer
	if multiplayer_api != null:
		var multiplayer_peer = multiplayer_api.multiplayer_peer
		if multiplayer_peer != null and multiplayer_peer.get_connection_status() == MultiplayerPeer.CONNECTION_CONNECTED:
			return
	network_manager.disconnect_client()
	_handle_connection_failure(
		"Connection attempt to the match server timed out.",
		"Reconnect attempt timed out."
	)

func _handle_connection_failure(initial_reason: String, reconnect_reason: String) -> void:
	_cancel_connect_attempt_timeout()
	_match_join_requested = false
	if _match_completed:
		_is_reconnecting = false
		_is_retrying_initial_connect = false
		return
	if _has_authenticated_match and _is_reconnecting:
		_is_reconnecting = false
		if _try_reconnect():
			return
		game_event_received.emit("match_reconnect_failed", {
			"reason": reconnect_reason,
		})
		return
	if _has_authenticated_match:
		if _try_reconnect():
			return
		server_disconnected.emit()
		game_event_received.emit("server_disconnected", {})
		return
	if _is_retrying_initial_connect:
		_is_retrying_initial_connect = false
	if _try_initial_connect_retry():
		return
	match_join_failed.emit(initial_reason)
	game_event_received.emit("match_join_denied", {"reason": initial_reason})

func _try_reconnect() -> bool:
	if _match_completed or not requires_match_auth() or network_manager == null:
		return false
	if _reconnect_attempts_remaining <= 0:
		return false
	_reconnect_attempts_remaining -= 1
	_is_reconnecting = true
	game_event_received.emit("match_reconnect_started", {
		"attempts_remaining": _reconnect_attempts_remaining,
	})
	_reconnect_attempt_serial += 1
	var expected_serial := _reconnect_attempt_serial
	call_deferred("_perform_reconnect", expected_serial)
	return true

func _perform_reconnect(expected_serial: int) -> void:
	if expected_serial != _reconnect_attempt_serial or not _is_reconnecting:
		return
	if _match_completed or network_manager == null:
		_is_reconnecting = false
		return
	var reconnect_err: Error = network_manager.reconnect_client(_server_ip, _server_port)
	if reconnect_err == OK:
		_arm_connect_attempt_timeout()
		return
	_is_reconnecting = false
	game_event_received.emit("match_reconnect_failed", {
		"reason": "Reconnect attempt failed.",
	})
	_handle_connection_failure(
		"Could not connect to the match server.",
		"Reconnect attempt failed."
	)

func _try_initial_connect_retry() -> bool:
	if not requires_match_auth() or network_manager == null:
		return false
	if _reconnect_attempts_remaining <= 0:
		return false
	_reconnect_attempts_remaining -= 1
	_is_retrying_initial_connect = true
	game_event_received.emit("match_connect_retry_started", {
		"attempts_remaining": _reconnect_attempts_remaining,
	})
	_reconnect_attempt_serial += 1
	var expected_serial := _reconnect_attempt_serial
	call_deferred("_perform_initial_connect_retry", expected_serial)
	return true

func _perform_initial_connect_retry(expected_serial: int) -> void:
	if expected_serial != _reconnect_attempt_serial or not _is_retrying_initial_connect:
		return
	if _match_completed or network_manager == null:
		_is_retrying_initial_connect = false
		return
	var reconnect_err: Error = network_manager.reconnect_client(_server_ip, _server_port)
	if reconnect_err == OK:
		_arm_connect_attempt_timeout()
		return
	_is_retrying_initial_connect = false
	_handle_connection_failure(
		"Could not connect to the match server.",
		"Reconnect attempt failed."
	)

func _submit_match_join_request() -> void:
	if not requires_match_auth() or network_manager == null or _match_join_requested:
		return
	_match_join_requested = true
	network_manager.submit_match_join({
		"match_id": str(_match_info.get("match_id", "")),
		"session_id": str(_match_info.get("session_id", "")),
		"match_token": str(_match_info.get("match_token", "")),
		"observer_mode": bool(_match_info.get("observer_mode", false)),
		"observer_session_id": str(_match_info.get("observer_session_id", "")),
		"observer_match_token": str(_match_info.get("observer_match_token", "")),
	})

func _try_submit_match_join_if_already_connected() -> void:
	if not requires_match_auth() or network_manager == null:
		return
	var multiplayer_peer = network_manager.multiplayer.multiplayer_peer
	if multiplayer_peer == null:
		return
	if multiplayer_peer.get_connection_status() != MultiplayerPeer.CONNECTION_CONNECTED:
		return
	_submit_match_join_request()

func _arm_connect_timeout_if_connecting() -> void:
	if network_manager == null:
		return
	var multiplayer_api = network_manager.multiplayer
	if multiplayer_api == null:
		return
	var multiplayer_peer = multiplayer_api.multiplayer_peer
	if multiplayer_peer == null:
		return
	if multiplayer_peer.get_connection_status() != MultiplayerPeer.CONNECTION_CONNECTING:
		return
	_arm_connect_attempt_timeout()

func _arm_connect_attempt_timeout() -> void:
	if network_manager == null:
		return
	var tree := network_manager.get_tree()
	if tree == null:
		return
	_connect_attempt_serial += 1
	var expected_serial := _connect_attempt_serial
	var timeout_timer := tree.create_timer(CONNECT_ATTEMPT_TIMEOUT_SECONDS)
	timeout_timer.timeout.connect(Callable(self, "_on_connect_attempt_timer_timeout").bind(expected_serial))

func _cancel_connect_attempt_timeout() -> void:
	_connect_attempt_serial += 1

func _on_connect_attempt_timer_timeout(expected_serial: int) -> void:
	if expected_serial != _connect_attempt_serial:
		return
	_on_connect_attempt_timeout()

func _on_game_event_received(event_type: String, data: Dictionary) -> void:
	if event_type == "reinforcement_phase":
		_series_between_games = true
		_match_completed = false
	elif event_type == "series_game_ended":
		_series_between_games = true
		_match_completed = false
	elif event_type == "series_game_started":
		_series_between_games = false
		_match_completed = false
	elif event_type == "series_ended":
		_series_between_games = false
	elif event_type == "game_ended":
		_match_completed = true
	elif event_type == "full_state":
		var state = data.get("state", {})
		if not _series_between_games and state is Dictionary and bool((state as Dictionary).get("is_game_over", false)):
			_match_completed = true
	game_event_received.emit(event_type, data)

func _on_peer_disconnected(peer_id: int) -> void:
	if _is_networked_client and requires_match_auth():
		_match_join_requested = false
		if _match_completed:
			return
		if _is_reconnecting:
			return
		if _has_authenticated_match and _try_reconnect():
			return
		if _has_authenticated_match:
			server_disconnected.emit()
			game_event_received.emit("server_disconnected", {})
			return
		_handle_connection_failure(
			"Disconnected from the match server before authentication completed.",
			"Reconnect attempt failed."
		)
		return
	peer_disconnected.emit(peer_id)
