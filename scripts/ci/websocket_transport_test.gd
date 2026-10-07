extends SceneTree

const NetworkScript = preload("res://scripts/Other/NetworkManager.gd")
const SessionScript = preload("res://scripts/server/MatchSession.gd")
const EndpointsScript = preload("res://scripts/network/WebSocketEndpoints.gd")
const LobbyClientScript = preload("res://scripts/client/LobbyClient.gd")
const MatchHostScript = preload("res://scripts/server/HeadlessMatchHost.gd")
const MatchSupervisorScript = preload("res://scripts/server/MatchSupervisor.gd")
const LobbyServerScript = preload("res://scripts/server/LobbyServer.gd")

var _failures: PackedStringArray = []
var _clients: Array[Node] = []
var _approvals: Dictionary = {}
var _events: Dictionary = {}
var _commands: Dictionary = {}
var _denied := false
var _host: Node
var _session

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	_check(EndpointsScript.match_url("wss://game.example.com", 12345) == "wss://game.example.com/match/12345", "match URL")
	_check(not EndpointsScript.is_valid_base_url("wss://game.example.com/lobby"), "reject base URL path")
	_check(not EndpointsScript.is_valid_base_url("ws://game.example.com"), "reject plaintext public origin")
	_check(EndpointsScript.lobby_url("wss://game.example.com/lobby") == "wss://game.example.com/lobby", "explicit lobby URL")
	var lobby = LobbyClientScript.new()
	var attempts: Array = lobby._build_transport_attempts("wss://game.example.com/lobby", 22345)
	_check(attempts.size() == 1 and attempts[0].url.begins_with("wss://"), "explicit WSS has no downgrade")
	lobby.free()
	var port_probe := TCPServer.new()
	if port_probe.listen(0, "127.0.0.1") != OK:
		_check(false, "allocate loopback port")
		_finish()
		return
	var port := port_probe.get_local_port()
	port_probe.stop()
	var ws_url := "ws://127.0.0.1:%d/match/%d" % [port, port]
	_session = SessionScript.new("transport-test", "room", "127.0.0.1", port, ["ws-player", "udp-player"])
	_session.match_websocket_url = ws_url
	var restored = SessionScript.from_launch_config(_session.to_launch_config())
	_check(restored.match_websocket_url == ws_url, "launch config retains endpoint")
	_check(restored.to_spectator_match_info("observer").match_websocket_url == ws_url, "observer receives endpoint")
	var supervisor = MatchSupervisorScript.new()
	supervisor.public_websocket_url = "wss://game.example.com"
	for offset in range(EndpointsScript.MATCH_PORT_COUNT):
		var allocated = SessionScript.new("pool-%d" % offset, "room", "127.0.0.1", 12345 + offset, [])
		supervisor.active_matches[allocated.match_id] = allocated
	_check(supervisor._allocate_match_port() == -1, "match pool stays within proxy routes")
	supervisor.active_matches.erase("pool-7")
	_check(supervisor._allocate_match_port() == 12352, "freed proxy route is reused")
	supervisor.free()
	var lobby_server = LobbyServerScript.new()
	_check(not lobby_server._can_accept_password_account_auth(2), "UDP password auth is not implicitly enabled")
	lobby_server.free()
	_host = _network_node("TransportServer")
	_check(_host.create_server(port, false) == OK, "UDP listener")
	_check(_host.start_match_websocket_server(port) == OK, "WebSocket listener")
	_host.match_join_requested.connect(_on_join)
	_host.command_received.connect(func(_command: Dictionary, sender: Dictionary) -> void:
		_commands[int(sender.player_index)] = true
	)
	_host.peer_disconnected.connect(func(id: int) -> void:
		_host.unassign_peer(id)
		_session.note_peer_disconnected(id)
	)
	for index in range(4):
		var client := _network_node("TransportClient%d" % index)
		_clients.append(client)
		_events[index] = []
		client.match_join_approved.connect(func(info: Dictionary) -> void: _approvals[index] = info)
		client.match_join_denied.connect(func(_reason: String) -> void: _denied = true)
		client.game_event_received.connect(func(type: String, data: Dictionary) -> void:
			_events[index].append({"type": type, "data": data})
		)
		client.connected_to_server.connect(func() -> void:
			var session_id := "ws-player" if index == 0 else "udp-player"
			client.submit_match_join({
				"match_id": "transport-test", "session_id": session_id,
				"match_token": "invalid" if index == 3 else _session.get_match_token(session_id),
				"observer": index == 2,
			})
		)
		_check(client.create_match_client("127.0.0.1", port, ws_url, index != 1) == OK, "create client %d" % index)
	await _wait_for(func() -> bool: return _approvals.size() == 3 and _denied)
	_check(_approvals.size() == 3 and _denied, "mixed clients authenticate; invalid token denied")
	if _approvals.size() != 3:
		_finish()
		return
	_check(_clients[0].local_player_index == 0 and _clients[1].local_player_index == 1, "player assignment across transports")
	_check(int(_host.player_peer_ids[0]) >= NetworkScript.WS_PEER_ID_BASE, "WebSocket ids are namespaced")
	var large_state: Dictionary = {"recipient": 0, "chunks": []}
	for _index in range(24):
		large_state.chunks.append("x".repeat(4000))
	_host.broadcast_event_to_peer(int(_host.player_peer_ids[0]), "full_state", large_state)
	_host.broadcast_event_to_peer(int(_host.player_peer_ids[1]), "full_state", {"recipient": 1})
	for id in _host.spectator_peer_ids:
		_host.broadcast_event_to_peer(id, "full_state", {"recipient": 2})
	_clients[0].request_action({"type": "forfeit"})
	_clients[1].request_action({"type": "forfeit"})
	await _wait_for(func() -> bool: return _events[0].size() == 1 and _events[1].size() == 1 and _events[2].size() == 1 and _commands.size() == 2)
	for index in range(3):
		_check(_events[index].size() == 1 and int(_events[index][0].data.recipient) == index, "private state for recipient %d" % index)
	_check(_events[3].is_empty(), "rejected peer receives no private state")
	_check(_commands.size() == 2, "commands resolve both player identities")
	_approvals.erase(1)
	_check(_clients[1].reconnect_client("127.0.0.1", port) == OK, "UDP retry switches to WebSocket")
	await _wait_for(func() -> bool: return _approvals.has(1))
	_check(_approvals.has(1) and _clients[1].peer is WebSocketMultiplayerPeer, "retry authenticates over WebSocket")
	_approvals.erase(1)
	_check(_clients[1].reconnect_client("127.0.0.1", port) == OK, "WebSocket reconnect")
	await _wait_for(func() -> bool: return _approvals.has(1))
	_check(_approvals.has(1) and _clients[1].peer is WebSocketMultiplayerPeer, "reconnect retains WebSocket")
	_finish()

func _network_node(mount_name: String) -> Node:
	if mount_name == "TransportClient0":
		var client = NetworkScript.new()
		client.name = "MatchNetworkManager"
		root.add_child(client)
		return client
	var mount := Node.new()
	mount.name = mount_name
	root.add_child(mount)
	var network = NetworkScript.new()
	network.name = "MatchNetworkManager"
	network.use_current_scene_relative_path = true
	network.managed_multiplayer_root_path = mount.get_path()
	mount.add_child(network)
	return network

func _on_join(request: Dictionary, sender: Dictionary) -> void:
	var id := int(sender.peer_id)
	if bool(request.get("observer", false)):
		_host.approve_match_join(id, -1, {})
		return
	var index := int(_session.authenticate_join(str(request.session_id), str(request.match_token), id))
	if index < 0:
		_host.deny_match_join(id, "Invalid match token")
	else:
		_host.approve_match_join(id, index, _session.to_match_info(str(request.session_id)))

func _wait_for(condition: Callable) -> void:
	var deadline := Time.get_ticks_msec() + 5000
	while not condition.call() and Time.get_ticks_msec() < deadline:
		await process_frame

func _check(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)

func _finish() -> void:
	for client in _clients:
		client.disconnect_client()
	if is_instance_valid(_host):
		if is_instance_valid(_host.websocket_transport):
			_host.websocket_transport.disconnect_client()
		_host.disconnect_client()
	if _failures.is_empty():
		print("websocket_transport_test: PASS")
	else:
		for failure in _failures:
			push_error("websocket_transport_test: " + failure)
	quit(0 if _failures.is_empty() else 1)
