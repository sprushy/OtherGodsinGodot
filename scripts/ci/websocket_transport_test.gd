extends SceneTree

const NetworkScript = preload("res://scripts/Other/NetworkManager.gd")
const SessionScript = preload("res://scripts/server/MatchSession.gd")
const EndpointsScript = preload("res://scripts/network/WebSocketEndpoints.gd")
const LobbyClientScript = preload("res://scripts/client/LobbyClient.gd")
const MatchClientScript = preload("res://scripts/client/MatchClient.gd")
const MatchHostScript = preload("res://scripts/server/HeadlessMatchHost.gd")
const MatchSupervisorScript = preload("res://scripts/server/MatchSupervisor.gd")
const LobbyServerScript = preload("res://scripts/server/LobbyServer.gd")
const MainMenuScript = preload("res://scripts/Other/MainMenu.gd")
const LobbyProtocolScript = preload("res://scripts/network/LobbyProtocol.gd")
const PunchReflectorScript = preload("res://scripts/network/PunchReflector.gd")

class RecoveryLobbyClient extends LobbyClientScript:
	var requests: Array[Dictionary] = []
	var transport_fails := false

	func _start_next_transport_attempt() -> Error:
		if transport_fails:
			return _finish_transport_ladder_failure()
		return OK

	func _send_request(message_type: String, payload: Dictionary = {}) -> void:
		requests.append({"type": message_type, "payload": payload.duplicate(true)})

class DeferredUpdateMenu extends MainMenuScript:
	func _release_updates_enabled() -> bool:
		return true

	func _write_update_log(_message: String) -> void:
		pass

class ObserveRecoveryMenu extends MainMenuScript:
	var notices: Array[String] = []

	func _show_lobby_notice(message: String) -> void:
		notices.append(message)

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
	_check_lobby_endpoint_configuration()
	_check_punch_endpoint_normalization()
	await _check_stale_client_disconnect_events()
	await _check_direct_spectator_punch()
	await _check_verified_punch_from_alternate_ip()
	await _check_udp_relay()
	await _check_relay_cleanup_on_match_end()
	_check_spectate_endpoint_selection()
	_check_spectate_relay_fallback_selection()
	await _check_failed_lobby_transport_cleanup()
	await _check_lobby_auth_rejection_cleanup()
	_check_detached_lobby_transport()
	_check_local_match_transport_cleanup()
	_check_lobby_restart_recovery()
	_check_observe_session_recovery()
	await _check_practice_lobby_suspension()
	_check_update_deferral()
	if not _failures.is_empty():
		_finish()
		return
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

func _check_lobby_endpoint_configuration() -> void:
	var previous_url: Variant = ProjectSettings.get_setting(EndpointsScript.PUBLIC_URL_SETTING, "")
	var previous_url_env := OS.get_environment(EndpointsScript.PUBLIC_URL_ENV)
	var previous_transport_env := OS.get_environment(LobbyClientScript.TRANSPORT_OVERRIDE_ENV)
	OS.set_environment(EndpointsScript.PUBLIC_URL_ENV, "")
	OS.set_environment(LobbyClientScript.TRANSPORT_OVERRIDE_ENV, "")
	ProjectSettings.set_setting(EndpointsScript.PUBLIC_URL_SETTING, "")
	var lobby := LobbyClientScript.new()
	var host := str(ProjectSettings.get_setting("application/config/default_lobby_host", ""))
	_check(EndpointsScript.lobby_url(host).is_empty(), "UDP host does not invent a TLS endpoint")
	var attempts: Array = lobby._build_transport_attempts(host, LobbyProtocolScript.PORT)
	for attempt in attempts:
		_check(attempt.transport != NetworkScript.TRANSPORT_WEBSOCKET, "unconfigured WebSocket is not attempted")
	var failures: Array[String] = []
	lobby.connection_failed.connect(func(message: String) -> void: failures.append(message))
	lobby._last_server_address = host
	lobby._last_transport_failure_was_timeout = true
	lobby._finish_transport_ladder_failure()
	_check(failures.size() == 1 and failures[0].contains("no secure WebSocket endpoint"), "restricted-network failure explains missing endpoint")
	ProjectSettings.set_setting(EndpointsScript.PUBLIC_URL_SETTING, "wss://game.example.com")
	attempts = lobby._build_transport_attempts(host, LobbyProtocolScript.PORT)
	_check(not attempts.is_empty() and attempts[0].get("url", "") == "wss://game.example.com/lobby", "configured TLS endpoint is preferred")
	ProjectSettings.set_setting(EndpointsScript.PUBLIC_URL_SETTING, previous_url)
	OS.set_environment(EndpointsScript.PUBLIC_URL_ENV, previous_url_env)
	OS.set_environment(LobbyClientScript.TRANSPORT_OVERRIDE_ENV, previous_transport_env)
	lobby.free()

func _check_punch_endpoint_normalization() -> void:
	_check(PunchReflectorScript.normalize_ip("::ffff:127.0.0.1") == "127.0.0.1", "normalize IPv4-mapped reflector endpoint")
	_check(PunchReflectorScript.normalize_ip(" 127.0.0.2 ") == "127.0.0.2", "trim reflector endpoint")
	_check(PunchReflectorScript.normalize_ip("2001:db8::1") == "2001:db8::1", "leave non-mapped endpoints intact")
	_check(PunchReflectorScript.is_loopback_ipv4("127.0.0.1"), "recognize loopback spectate endpoint")
	_check(PunchReflectorScript.is_private_ipv4("192.168.1.5"), "recognize private spectate endpoint")
	_check(PunchReflectorScript.is_same_private_subnet("192.168.1.5", "192.168.1.9"), "same LAN uses private endpoint")
	_check(not PunchReflectorScript.is_same_private_subnet("192.168.1.5", "192.168.2.9"), "different LAN keeps public endpoint")
	_check(PunchReflectorScript.is_same_private_subnet("10.0.0.5", "10.4.5.9"), "10.x private range uses private endpoint")

func _check_stale_client_disconnect_events() -> void:
	var network := _network_node("CanceledTransport")
	var failures: Array[String] = []
	network.connection_failed.connect(func() -> void: failures.append("failed"))
	network.server_disconnected.connect(func() -> void: failures.append("disconnected"))
	network.peer_disconnected.connect(func(_id: int) -> void: failures.append("peer disconnected"))
	_check(network.create_client("127.0.0.1", 9) == OK, "start canceled UDP attempt")
	network._on_connection_failed()
	network._on_server_disconnected()
	network._on_peer_disconnected(1)
	_check(failures.is_empty(), "client disconnect notifications wait until polling completes")
	network.disconnect_client()
	_check(network.create_client("127.0.0.1", 9) == OK, "replace canceled UDP attempt")
	await process_frame
	_check(failures.is_empty(), "old disconnect notifications cannot fail a replacement transport")
	network.disconnect_client()
	network.get_parent().queue_free()
	await process_frame

func _check_direct_spectator_punch() -> void:
	var host := _network_node("DirectSpectatorHost")
	if host.create_server(0, false) != OK:
		_check(false, "bind direct spectator host")
		host.get_parent().queue_free()
		return
	var host_port: int = host.peer.get_host().get_local_port()
	var reflector := PunchReflectorScript.new()
	root.add_child(reflector)
	var port_probe := PacketPeerUDP.new()
	if port_probe.bind(0) != OK:
		_check(false, "allocate reflector port")
		host.get_parent().queue_free()
		reflector.queue_free()
		return
	var reflector_port := port_probe.get_local_port()
	port_probe.close()
	if not reflector.setup(reflector_port):
		_check(false, "bind reflector")
		host.get_parent().queue_free()
		reflector.queue_free()
		return
	var session := SessionScript.new("direct-match", "room", "127.0.0.2", reflector_port, ["human", "bot"])
	session.set_spectator_visible_player_indices("observer", [])
	var token := session.get_spectator_match_token("observer")
	var host_punch := PunchReflectorScript.make_host_punch("direct-match", token)
	var unsigned_sender := PacketPeerUDP.new()
	var unsigned_punch := PunchReflectorScript.make_marker(PunchReflectorScript.PUNCH_KIND_PACKET, "")
	var reported_ports: Array[int] = []
	var report_ready := func() -> bool:
		var bounce := reflector.get_bounce("client:direct-match:observer", 2.0)
		if not bounce.is_empty():
			reported_ports.append(int(bounce["port"]))
			unsigned_sender.set_dest_address(str(bounce["ip"]), int(bounce["port"]))
			unsigned_sender.put_packet(unsigned_punch)
			_check(host.begin_spectator_punch("observer", str(bounce["ip"]), int(bounce["port"]), host_punch) == OK, "host punches the reported endpoint")
		return true
	var marker := PunchReflectorScript.make_marker(PunchReflectorScript.BOUNCE_KIND_CLIENT, "direct-match", "observer")
	# The reflector advertises one port, but the host replies from another.
	var route := await PunchReflectorScript.prime_spectator_socket(
		self, "127.0.0.1", reflector_port, "127.0.0.1", reflector_port, marker, host_punch, report_ready
	)
	unsigned_sender.close()
	var local_port := int(route.get("local_port", 0))
	_check(local_port > 0 and reported_ports == [local_port], "host punch completes rendezvous before the ENet dial")
	_check(route.get("host_port") == host_port, "verified reply selects the remapped host port and ignores unsigned alternates")
	host.match_join_requested.connect(func(request: Dictionary, sender: Dictionary) -> void:
		var peer_id := int(sender["peer_id"])
		if session.authenticate_spectator(str(request.get("observer_session_id")), str(request.get("observer_match_token")), peer_id):
			host.approve_match_join(peer_id, -1, session.to_spectator_match_info("observer"))
	)
	var spectator := _network_node("DirectSpectatorClient")
	var dial_port := int(route.get("host_port", reflector_port))
	_check(spectator.create_match_client("127.0.0.1", dial_port, "", false, local_port) == OK, "start direct spectator client")
	var client := MatchClientScript.new(null, spectator, true, true, session.to_spectator_match_info("observer"), "127.0.0.1", dial_port)
	var approvals: Array[Dictionary] = []
	spectator.match_join_approved.connect(func(info: Dictionary) -> void: approvals.append(info))
	await _wait_for(func() -> bool: return approvals.size() == 1)
	_check(approvals.size() == 1, "spectator connects and authenticates directly")
	_check(spectator.peer.get_host().get_local_port() == local_port, "ENet uses the port registered by the reflector")
	_check(spectator.reconnect_client(client._server_ip, client._server_port) == OK, "retry direct spectator connection")
	await _wait_for(func() -> bool: return approvals.size() == 2)
	_check(approvals.size() == 2, "spectator reconnects at the discovered endpoint")
	_check(spectator.peer.get_host().get_local_port() == local_port, "spectator retries keep the punched port")
	client.shutdown()
	spectator.disconnect_client()
	host.disconnect_client()
	spectator.get_parent().queue_free()
	host.get_parent().queue_free()
	reflector.queue_free()
	await process_frame

## A verified host punch carries the observer token, so a multi-WAN or CGNAT
## host may legitimately answer from a different public IP than the advertised
## one. The spectator must accept that proof and dial the IP that answered, while
## still rejecting unsigned punches from unexpected sources.
func _check_verified_punch_from_alternate_ip() -> void:
	var listener := PacketPeerUDP.new()
	if listener.bind(0, "127.0.0.1") != OK:
		_check(false, "bind punch listener")
		return
	var alternate := PacketPeerUDP.new()
	if alternate.bind(0, "127.0.0.2") != OK:
		listener.close()
		alternate.close()
		# Windows and most Unix hosts route all of 127/8 to loopback; skip when
		# this sandbox cannot source from 127.0.0.2 instead of failing the suite.
		print("websocket_transport_test: skipped alternate-IP punch (127.0.0.2 unavailable)")
		return
	var host_punch := PunchReflectorScript.make_host_punch("alternate-match", "token")
	var unsigned := PunchReflectorScript.make_marker(PunchReflectorScript.PUNCH_KIND_PACKET, "")
	var marker := PunchReflectorScript.make_marker(PunchReflectorScript.BOUNCE_KIND_CLIENT, "alternate-match", "observer")
	var reply_from_alternate := func(reply: PackedByteArray) -> Callable:
		return func() -> bool:
			for _packet_index in range(mini(listener.get_available_packet_count(), 16)):
				listener.get_packet()
				alternate.set_dest_address(listener.get_packet_ip(), listener.get_packet_port())
				alternate.put_packet(reply)
				return true
			return true
	var verified_route := await PunchReflectorScript.prime_spectator_socket(
		self, "127.0.0.1", listener.get_local_port(), "127.0.0.1", listener.get_local_port(),
		marker, host_punch, reply_from_alternate.call(host_punch)
	)
	_check(bool(verified_route.get("host_replied", false)), "verified host punch completes the rendezvous")
	_check(str(verified_route.get("connect_ip", "")) == "127.0.0.2", "verified punch dials the reply IP, not the advertised one")
	var unsigned_route := await PunchReflectorScript.prime_spectator_socket(
		self, "127.0.0.1", listener.get_local_port(), "127.0.0.1", listener.get_local_port(),
		marker, host_punch, reply_from_alternate.call(unsigned)
	)
	_check(not bool(unsigned_route.get("host_replied", false)), "unsigned punch from another IP is rejected")
	listener.close()
	alternate.close()

func _check_udp_relay() -> void:
	var reflector := PunchReflectorScript.new()
	root.add_child(reflector)
	var probe := PacketPeerUDP.new()
	if probe.bind(0) != OK:
		_check(false, "allocate relay reflector port")
		reflector.queue_free()
		return
	var relay_port := probe.get_local_port()
	probe.close()
	if not reflector.setup(relay_port):
		_check(false, "bind relay reflector")
		reflector.queue_free()
		return
	var host_socket := PacketPeerUDP.new()
	var client_socket := PacketPeerUDP.new()
	if host_socket.bind(0) != OK or client_socket.bind(0) != OK:
		_check(false, "bind relay test sockets")
		host_socket.close()
		client_socket.close()
		reflector.shutdown()
		reflector.queue_free()
		return
	host_socket.set_dest_address("127.0.0.1", relay_port)
	host_socket.put_packet(PunchReflectorScript.make_marker(PunchReflectorScript.BOUNCE_KIND_HOST, "relay-match"))
	client_socket.set_dest_address("127.0.0.1", relay_port)
	client_socket.put_packet(PunchReflectorScript.make_marker(
		PunchReflectorScript.BOUNCE_KIND_CLIENT, "relay-match", "relay-observer"))
	await _wait_for(func() -> bool:
		return not reflector.get_bounce("host:relay-match", 2.0).is_empty() \
			and not reflector.get_bounce("client:relay-match:relay-observer", 2.0).is_empty())
	_check(reflector.enable_relay_session("relay-match", "relay-observer"), "enable UDP relay session")
	await process_frame
	client_socket.set_dest_address("127.0.0.1", relay_port)
	client_socket.put_packet("client-enet".to_utf8_buffer())
	await _wait_for(func() -> bool: return host_socket.get_available_packet_count() > 0)
	_check(host_socket.get_available_packet_count() > 0, "relay forwards spectator traffic to host")
	if host_socket.get_available_packet_count() > 0:
		_check(host_socket.get_packet().get_string_from_utf8() == "client-enet", "relayed spectator payload is unchanged")
	host_socket.set_dest_address("127.0.0.1", relay_port)
	host_socket.put_packet("host-enet".to_utf8_buffer())
	await _wait_for(func() -> bool: return client_socket.get_available_packet_count() > 0)
	_check(client_socket.get_available_packet_count() > 0, "relay forwards host traffic to spectator")
	if client_socket.get_available_packet_count() > 0:
		_check(client_socket.get_packet().get_string_from_utf8() == "host-enet", "relayed host payload is unchanged")
	host_socket.close()
	client_socket.close()
	reflector.shutdown()
	reflector.queue_free()
	await process_frame

## Relay sessions and punch throttles used to linger until the reflector TTL
## expired. They should be dropped as soon as a client-hosted bot match settles.
func _check_relay_cleanup_on_match_end() -> void:
	var reflector := PunchReflectorScript.new()
	root.add_child(reflector)
	var probe := PacketPeerUDP.new()
	if probe.bind(0) != OK:
		_check(false, "allocate cleanup reflector port")
		reflector.queue_free()
		return
	var port := probe.get_local_port()
	probe.close()
	if not reflector.setup(port):
		_check(false, "bind cleanup reflector")
		reflector.queue_free()
		return
	_check(reflector.enable_relay_session("cleanup-match", "observer"), "enable relay session before cleanup")
	var lobby := LobbyServerScript.new()
	lobby.punch_reflector = reflector
	lobby._punch_ready_last_msec_by_key["cleanup-match|observer"] = Time.get_ticks_msec()
	lobby._punch_ready_last_msec_by_key["other-match|observer"] = Time.get_ticks_msec()
	lobby._cleanup_local_bot_spectate_state("cleanup-match", {
		"spectator_match_tokens_by_session": {"observer": "token"},
	})
	_check(not reflector._relay_sessions.has("cleanup-match|observer"), "match cleanup disables its relay sessions")
	_check(not lobby._punch_ready_last_msec_by_key.has("cleanup-match|observer"), "match cleanup clears its punch throttles")
	_check(lobby._punch_ready_last_msec_by_key.has("other-match|observer"), "match cleanup leaves other matches alone")
	lobby.free()
	reflector.shutdown()
	reflector.queue_free()
	await process_frame

## Public lobbies must never treat a host's RFC1918 hint as reachable. Only a
## local/private lobby may prefer the host's real listener port.
func _check_spectate_endpoint_selection() -> void:
	var menu := MainMenuScript.new()
	menu._is_local_lobby_host = false
	menu._current_lobby_ip = "lobby.example.com"
	var public_result: Dictionary = menu._resolve_spectate_server_endpoint({
		"observer_mode": true,
		"spectate_lan_ip": "192.168.1.2",
		"spectate_lan_port": 33872,
	}, "203.0.113.7", 41000)
	_check(str(public_result.get("ip", "")) == "203.0.113.7" \
		and int(public_result.get("port", 0)) == 41000 \
		and not bool(public_result.get("private_selected", false)),
		"public lobby ignores a private spectate hint")
	menu._is_local_lobby_host = true
	var lan_result: Dictionary = menu._resolve_spectate_server_endpoint({
		"observer_mode": true,
		"spectate_lan_ip": "127.0.0.1",
		"spectate_lan_port": 33872,
	}, "203.0.113.7", 41000)
	_check(str(lan_result.get("ip", "")) == "127.0.0.1" \
		and int(lan_result.get("port", 0)) == 33872 \
		and bool(lan_result.get("private_selected", false)),
		"local lobby prefers the host listener port")
	var missing_port: Dictionary = menu._resolve_spectate_server_endpoint({
		"observer_mode": true,
		"spectate_lan_ip": "127.0.0.1",
	}, "203.0.113.7", 41000)
	_check(not bool(missing_port.get("private_selected", false)) \
		and int(missing_port.get("port", 0)) == 41000,
		"private hint without a listener port falls back to the advertised endpoint")
	menu.free()

## Direct-first spectators dial the advertised endpoint and only move to the
## relay after that dial fails. Punch-assigned spectators already dial a
## relay-ready endpoint, so their target must not change.
func _check_spectate_relay_fallback_selection() -> void:
	var direct_client := MatchClientScript.new(null, null, false, false, {
		"observer_mode": true,
		"match_id": "fallback-match",
		"observer_session_id": "observer",
		"spectate_relay_ip": "203.0.113.9",
		"spectate_relay_port": 22346,
	}, "198.51.100.7", 33872)
	_check(direct_client._maybe_switch_spectate_retry_to_relay("initial"), "direct-first spectator retries through the relay")
	_check(direct_client._server_ip == "203.0.113.9" and direct_client._server_port == 22346, "relay fallback retries the reflector endpoint")
	_check(not direct_client._maybe_switch_spectate_retry_to_relay("initial"), "relay fallback is attempted once")
	var punch_client := MatchClientScript.new(null, null, false, false, {
		"observer_mode": true,
		"match_id": "fallback-match",
		"observer_session_id": "observer",
		"spectate_via_punch": true,
		"spectate_relay_ip": "203.0.113.9",
		"spectate_relay_port": 22346,
	}, "198.51.100.7", 33872)
	_check(not punch_client._maybe_switch_spectate_retry_to_relay("initial") \
		and punch_client._server_ip == "198.51.100.7",
		"punch assignments keep their relay-ready endpoint")

func _check_failed_lobby_transport_cleanup() -> void:
	# Exercise the menu's cleanup from a real refused WebSocket connection.
	# Removing the custom multiplayer scope inside poll() used to crash Godot.
	var port_probe := TCPServer.new()
	if port_probe.listen(0, "127.0.0.1") != OK:
		_check(false, "allocate refused lobby port")
		return
	var port := port_probe.get_local_port()
	port_probe.stop()
	var lobby := LobbyClientScript.new()
	lobby.name = "FailedLobby"
	root.add_child(lobby)
	var failures: Array[String] = []
	lobby.connection_failed.connect(func(message: String) -> void:
		failures.append(message)
		lobby.disconnect_from_server()
		root.remove_child(lobby)
		lobby.queue_free()
	)
	_check(lobby.connect_to_server("ws://127.0.0.1:%d/lobby" % port) == OK, "start refused lobby connection")
	await _wait_for(func() -> bool: return not failures.is_empty())
	_check(failures.size() == 1, "refused lobby connection reports one failure without crashing")
	if is_instance_valid(lobby) and not lobby.is_queued_for_deletion():
		lobby.disconnect_from_server()
		lobby.queue_free()
	await process_frame

func _check_lobby_auth_rejection_cleanup() -> void:
	var lobby := LobbyClientScript.new()
	lobby.name = "RejectedAuthLobby"
	root.add_child(lobby)
	var failures: Array[String] = []
	lobby.connection_failed.connect(func(message: String) -> void:
		failures.append(message)
		root.remove_child(lobby)
		lobby.queue_free()
	)
	lobby.network_manager.game_event_received.emit(LobbyClientScript.LOBBY_EVENT_TYPE, LobbyProtocolScript.make_message(
		LobbyProtocolScript.ROOM_ERROR, {"message": "Invalid account credentials."}
	))
	_check(failures.is_empty(), "authentication rejection cannot tear down the lobby inside RPC polling")
	await process_frame
	_check(failures.size() == 1 and failures[0] == "Invalid account credentials.", "deferred authentication rejection reports its error")
	if is_instance_valid(lobby) and not lobby.is_queued_for_deletion():
		lobby.queue_free()
	await process_frame

func _check_detached_lobby_transport() -> void:
	var lobby := LobbyClientScript.new()
	lobby.name = "DetachedLobby"
	root.add_child(lobby)
	lobby._transport_connected_signal_received = true
	lobby._is_authenticated = true
	lobby.current_session_id = "bot-worker-session"
	_check(lobby.is_authenticated(), "attached lobby recognizes its connection signal")
	root.remove_child(lobby)
	_check(not lobby.is_authenticated(), "detached lobby ignores its cached connection signal")
	lobby.cancel_bot_work("active-bot-job")
	lobby.free()

func _check_lobby_restart_recovery() -> void:
	var lobby := RecoveryLobbyClient.new()
	lobby.name = "RecoveryLobby"
	root.add_child(lobby)
	var failures: Array[String] = []
	lobby.disconnected_from_lobby.connect(func() -> void: failures.append("disconnected"))
	lobby.lobby_auto_reconnect_failed.connect(func() -> void: failures.append("reconnect failed"))
	lobby._last_server_address = "wss://game.example.com/lobby"
	lobby._pending_account_email = "restart@example.com"
	lobby._pending_password = "test-password"
	lobby._pending_account_username = "RestartTester"
	lobby.current_session_id = "old-session"
	lobby.current_reconnect_token = "old-token"
	lobby.current_profile_id = "profile"
	_check(lobby._try_auto_reconnect(), "authenticated lobby drop starts recovery")
	lobby._perform_auto_reconnect(lobby._auto_reconnect_serial)
	lobby._transport_connected_signal_received = true
	_check(lobby._pending_password == "test-password" and lobby._pending_account_email == "restart@example.com", "automatic reconnect retains sign-in credentials")
	lobby._send_initial_auth_request()
	_check(lobby.requests[-1].type == LobbyProtocolScript.REQUEST_RECONNECT_LOBBY, "recovery tries the session token first")
	lobby._password_auth_allowed_for_current_connection = true
	lobby.lobby_event(LobbyProtocolScript.make_message(LobbyProtocolScript.ROOM_ERROR, {"message": "Lobby session not found."}))
	_check(failures.is_empty() and lobby.is_auto_reconnecting(), "expired session falls back without a terminal disconnect")
	_check(lobby.requests[-1].type == LobbyProtocolScript.LOGIN_ACCOUNT and lobby.requests[-1].payload.email == "restart@example.com" and lobby.requests[-1].payload.password == "test-password", "restart falls back to account sign-in")
	lobby.lobby_event(LobbyProtocolScript.make_message(LobbyProtocolScript.HELLO_OK, {"session_id": "new-session", "reconnect_token": "new-token"}))
	_check(lobby.is_authenticated() and not lobby.is_auto_reconnecting() and lobby.current_session_id == "new-session", "account sign-in completes restart recovery")
	lobby._on_server_disconnected()
	lobby.transport_fails = true
	var attempts_before := lobby._auto_reconnect_attempt
	lobby._perform_auto_reconnect(lobby._auto_reconnect_serial)
	_check(lobby._auto_reconnect_attempt == attempts_before + 1, "one transport failure schedules only one retry")
	lobby.disconnect_from_server()
	lobby.free()

func _check_observe_session_recovery() -> void:
	var lobby := RecoveryLobbyClient.new()
	root.add_child(lobby)
	lobby._last_server_address = "wss://game.example.com/lobby"
	lobby.current_session_id = "watcher"
	lobby.current_reconnect_token = "saved-token"
	lobby._is_authenticated = true
	lobby._transport_connected_signal_received = true
	var menu := ObserveRecoveryMenu.new()
	menu.status_label = Label.new()
	menu.lobby_client = lobby
	menu._pending_observe_room_id = "ROOM1"
	lobby.room_error.connect(menu._on_lobby_room_error)
	lobby.reconnect_succeeded.connect(func(_id: String, _token: String, _name: String, _room: Dictionary, _match: Dictionary) -> void:
		menu._run_pending_multiplayer_action()
	)
	menu._run_pending_multiplayer_action()
	var rejection := LobbyProtocolScript.make_message(LobbyProtocolScript.ROOM_ERROR, {
		"message": LobbyProtocolScript.OBSERVE_ROOM_AUTH_ERROR,
	})
	lobby.lobby_event(rejection)
	_check(lobby.is_auto_reconnecting() and not lobby.is_authenticated(), "observe rejection restores the stale lobby session")
	_check(menu._pending_observe_room_id == "ROOM1", "recovery remembers the selected room")
	lobby._perform_auto_reconnect(lobby._auto_reconnect_serial)
	lobby._transport_connected_signal_received = true
	lobby._send_initial_auth_request()
	_check(lobby.requests[-1].type == LobbyProtocolScript.REQUEST_RECONNECT_LOBBY, "observe recovery uses the saved session credentials")
	lobby.lobby_event(LobbyProtocolScript.make_message(LobbyProtocolScript.LOBBY_RECONNECT_OK, {
		"session_id": "watcher", "reconnect_token": "saved-token", "room": {},
	}))
	_check(lobby.requests[-1].type == LobbyProtocolScript.OBSERVE_ROOM and lobby.requests[-1].payload.room_id == "ROOM1", "recovery retries the same watch request")
	lobby.lobby_event(rejection)
	_check(not lobby.is_auto_reconnecting() and menu._pending_observe_room_id.is_empty(), "a second rejection ends the retry")
	_check(menu.notices == [LobbyProtocolScript.OBSERVE_ROOM_AUTH_ERROR], "a second rejection stays visible in a notice")
	lobby.disconnect_from_server()
	lobby.free()
	menu.status_label.free()
	menu.free()

func _check_practice_lobby_suspension() -> void:
	var menu := MainMenuScript.new()
	var lobby := RecoveryLobbyClient.new()
	lobby.name = "PracticeBackgroundLobby"
	root.add_child(lobby)
	menu.lobby_client = lobby
	menu._lobby_session_id = "practice-session"
	menu._lobby_reconnect_token = "practice-token"
	menu._startup_autologin_pending = true
	menu._startup_autologin_in_progress = true
	var completions: Array[String] = []
	menu._pending_background_lobby_auth_completion = func() -> void: completions.append("auth")
	lobby.current_session_id = menu._lobby_session_id
	lobby.current_reconnect_token = menu._lobby_reconnect_token
	lobby._last_server_address = "wss://game.example.com/lobby"
	_check(lobby._try_auto_reconnect(), "background lobby schedules recovery before practice")
	var retry_serial := lobby._auto_reconnect_serial
	var connect_serial := menu._authenticated_lobby_connect_serial
	var watchdog_serial := menu._lobby_sign_in_watchdog_serial
	menu._suspend_lobby_for_practice()
	_check(menu._lobby_suspended_for_practice and menu.lobby_client == null, "practice detaches the background lobby")
	_check(not lobby.is_auto_reconnecting() and lobby._ignore_network_events, "practice cancels automatic lobby recovery")
	_check(menu._authenticated_lobby_connect_serial != connect_serial and menu._lobby_sign_in_watchdog_serial != watchdog_serial, "practice invalidates queued sign-in and its watchdog")
	_check(not menu._startup_autologin_pending and not menu._startup_autologin_in_progress and not menu._pending_background_lobby_auth_completion.is_valid(), "practice cancels background authentication completion")
	_check(menu._lobby_session_id == "practice-session" and menu._lobby_reconnect_token == "practice-token", "practice preserves credentials for returning to the menu")
	lobby._perform_auto_reconnect(retry_serial)
	# These calls would access uninitialized menu controls if suspension failed.
	menu._connect_to_browseable_lobby("Must wait for practice to end")
	menu._maybe_connect_authenticated_lobby()
	menu._deferred_authenticated_lobby_connect("Stale sign-in", connect_serial)
	_check(lobby.requests.is_empty() and menu.lobby_client == null and completions.is_empty(), "stale retries and sign-in cannot open a lobby during practice")
	menu.free()
	await process_frame

func _check_update_deferral() -> void:
	var menu := DeferredUpdateMenu.new()
	var games := Control.new()
	games.name = "GameContainer"
	menu.add_child(games)
	menu.game_container = games
	var game := Control.new()
	game.name = "MockGame"
	games.add_child(game)
	menu._begin_required_update("v0.2.999", "https://example.com/release", "https://example.com/game.zip", 1024, "hash", false, "https://example.com/game.zip.sha256")
	_check(not menu._deferred_required_update.is_empty() and not menu._is_auto_updating, "new release waits while a game is visible")
	_check(str(menu._deferred_required_update.get("download_sha256_url", "")) == "https://example.com/game.zip.sha256", "deferred release retains verification metadata")
	games.visible = false
	_check(not menu._should_defer_required_update(), "returning to menu permits the deferred update")
	menu._match_launch_queued = true
	_check(menu._should_defer_required_update(), "match handoff defers updates before the game is visible")
	menu.free()

func _check_local_match_transport_cleanup() -> void:
	var parent := Node.new()
	parent.name = "LocalMatchTransition"
	root.add_child(parent)
	var local_host = MatchHostScript.new()
	var local_transport: Node = local_host.setup_transport(parent)
	var local_api: MultiplayerAPI = local_transport.multiplayer
	var transport_path := local_transport.get_path()
	_check(local_api != get_multiplayer(), "local match has an isolated transport")
	root.remove_child(local_transport)
	local_transport.queue_free()
	_check(get_multiplayer(transport_path) != local_api, "leaving local match removes its multiplayer scope")
	# Online matches reuse this node name after Story or Practice ends.
	var online_transport = NetworkScript.new()
	online_transport.name = "MatchNetworkManager"
	root.add_child(online_transport)
	_check(online_transport.multiplayer == get_multiplayer(), "online match does not inherit local multiplayer scope")
	var rpc_root: Node = root.get_node(online_transport.multiplayer.root_path)
	var rpc_path := rpc_root.get_path_to(online_transport)
	_check(rpc_path == NodePath("MatchNetworkManager"), "online RPCs address MatchNetworkManager instead of scene root")
	root.remove_child(online_transport)
	online_transport.queue_free()
	parent.queue_free()

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
