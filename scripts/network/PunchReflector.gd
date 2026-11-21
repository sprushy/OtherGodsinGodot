extends Node
class_name PunchReflector

## Minimal UDP "STUN-lite" reflector used for NAT hole punching.
##
## A client-hosted match's ENet socket and a spectator's ENet socket each send
## one small marker packet here from the socket they will actually dial with.
## The reflector records the sender's public ip/port under the marker's key so
## lobby signaling can hand each side the other side's endpoint and the ENet
## peers can punch through home routers (most keep endpoint-independent UDP
## mappings, so matching local ports is enough). The reflector keeps no
## session state and never replies; the rendezvous itself runs over the
## reliable lobby connection, keeping the UDP side a dumb lookup table.

const PUNCH_MARKER_KEY := "othergods_punch"
const BOUNCE_KIND_HOST := "host"
const BOUNCE_KIND_CLIENT := "client"
const PUNCH_KIND_PACKET := "punch"
const MARKER_REGISTRY_LIMIT := 64
const SPECTATOR_PRIME_ATTEMPTS := 4
# The same UDP socket also acts as a last-resort relay when two private NATs
# cannot punch through to each other. Both sides already send their marker from
# the exact ENet socket they use for the match, so source endpoints identify
# the two halves of a session without adding a header to ENet packets.
const HOST_BOUNCE_TTL_SECONDS := 30.0
const CLIENT_BOUNCE_TTL_SECONDS := 20.0
const RELAY_SESSION_TTL_SECONDS := 45.0
const RELAY_MAX_PACKET_BYTES := 2048

var bound_port: int = 0

var _udp: PacketPeerUDP = null
var _bounce_by_key: Dictionary = {}
var _relay_sessions: Dictionary = {}
var _relay_ready_printed: Dictionary = {}

static func make_marker(bounce_kind: String, match_id: String, observer_session_id: String = "") -> PackedByteArray:
	var marker := {
		PUNCH_MARKER_KEY: true,
		"kind": bounce_kind,
		"match_id": match_id.strip_edges(),
	}
	if not observer_session_id.strip_edges().is_empty():
		marker["observer"] = observer_session_id.strip_edges()
	return JSON.stringify(marker).to_utf8_buffer()

static func make_host_punch(match_id: String, observer_token: String) -> PackedByteArray:
	# The watcher already has the token from the lobby. Put only a proof on the
	# wire so a punch from a remapped port does not disclose the join credential.
	var proof := ("othergods:spectator-punch:%s:%s" % [match_id, observer_token]).sha256_text()
	return JSON.stringify({
		PUNCH_MARKER_KEY: true,
		"kind": PUNCH_KIND_PACKET,
		"match_id": match_id,
		"proof": proof,
	}).to_utf8_buffer()

## Windows/dual-stack sockets can report IPv4 senders as ::ffff:a.b.c.d. Keep
## the registry and every downstream endpoint plain IPv4 so ENet socket_send
## and create_client never receive an address form they may reject.
static func normalize_ip(address: String) -> String:
	var resolved := address.strip_edges()
	if resolved.begins_with("::ffff:"):
		return resolved.trim_prefix("::ffff:")
	return resolved

static func endpoint_key(ip: String, port: int) -> String:
	return "%s:%d" % [normalize_ip(ip), port]

## Private IPv4 helpers used for the same-LAN spectate shortcut. Loopback is
## handled separately because it is reachable only on the same machine.
static func is_loopback_ipv4(address: String) -> bool:
	return normalize_ip(address).begins_with("127.")

static func is_private_ipv4(address: String) -> bool:
	var resolved := normalize_ip(address)
	if resolved.begins_with("10.") or is_loopback_ipv4(resolved):
		return true
	var parts := resolved.split(".")
	if parts.size() != 4:
		return false
	if parts[0] == "192" and parts[1] == "168":
		return true
	if parts[0] == "172":
		var second := int(parts[1])
		return second >= 16 and second <= 31
	return false

static func is_same_private_subnet(first: String, second: String) -> bool:
	var a := normalize_ip(first)
	var b := normalize_ip(second)
	if is_loopback_ipv4(a) or is_loopback_ipv4(b):
		return is_loopback_ipv4(a) and is_loopback_ipv4(b)
	if not is_private_ipv4(a) or not is_private_ipv4(b):
		return false
	var a_parts := a.split(".")
	var b_parts := b.split(".")
	if a_parts.size() != 4 or b_parts.size() != 4:
		return false
	if a.begins_with("10.") and b.begins_with("10."):
		return true
	if a_parts[0] == "192" and a_parts[1] == "168" and b_parts[0] == "192" and b_parts[1] == "168":
		return a_parts[2] == b_parts[2]
	if a_parts[0] == "172" and b_parts[0] == "172":
		return a_parts[1] == b_parts[1]
	return false

## Open the UDP route before ENet starts its handshake. The temporary socket
## hands its local port to ENet even if the host's punch is delayed. If no
## verified host reply arrives and a lobby relay was supplied, the ENet dial is
## pointed at that relay; the reflector already knows both public endpoints.
static func prime_spectator_socket(
	tree: SceneTree, host_ip: String, host_port: int, reflector_host: String, reflector_port: int,
	marker: PackedByteArray, host_punch: PackedByteArray, report_ready: Callable,
	relay_ip: String = "", relay_port: int = 0
) -> Dictionary:
	if host_ip.is_empty() or host_port <= 0:
		return {}
	var socket := PacketPeerUDP.new()
	if socket.bind(0) != OK:
		return {}
	var local_port := socket.get_local_port()
	var punch := make_marker(PUNCH_KIND_PACKET, "")
	var advertised_ip := normalize_ip(host_ip)
	var fallback_ip := normalize_ip(relay_ip)
	var fallback_port := 0 if fallback_ip.is_empty() else relay_port
	if relay_port <= 0:
		fallback_port = 0
	for _attempt in range(SPECTATOR_PRIME_ATTEMPTS):
		if socket.set_dest_address(host_ip, host_port) == OK:
			socket.put_packet(punch)
		if socket.set_dest_address(reflector_host, reflector_port) != OK or socket.put_packet(marker) != OK:
			break
		# Give the UDP marker a chance to reach the reflector before lookup.
		await tree.create_timer(0.1, true, false, true).timeout
		if not report_ready.call():
			break
		await tree.create_timer(0.35, true, false, true).timeout
		for _packet_index in range(mini(socket.get_available_packet_count(), 16)):
			var reply := socket.get_packet()
			var reply_port := socket.get_packet_port()
			if normalize_ip(socket.get_packet_ip()) != advertised_ip or reply_port <= 0:
				continue
			# A legacy host can confirm the advertised endpoint. A verified
			# reply can also teach us the port the host's router used toward us.
			if (not host_punch.is_empty() and reply == host_punch) or (reply == punch and reply_port == host_port):
				socket.close()
				return {
					"local_port": local_port,
					"host_port": reply_port,
					"host_replied": true,
					"connect_ip": advertised_ip,
					"connect_port": reply_port,
					"via_relay": false,
				}
	socket.close()
	var use_relay := not fallback_ip.is_empty() and fallback_port > 0
	return {
		"local_port": local_port,
		"host_port": host_port,
		"host_replied": false,
		"connect_ip": fallback_ip if use_relay else advertised_ip,
		"connect_port": fallback_port if use_relay else host_port,
		"via_relay": use_relay,
	}

static func is_punch_marker(marker) -> bool:
	return (marker is Dictionary) and bool((marker as Dictionary).get(PUNCH_MARKER_KEY, false))

## Registry key for one marker. Host bounces are keyed by match alone; client
## bounces are keyed per observer so several spectators of the same match get
## punched from their own endpoint.
static func get_marker_key(marker: Dictionary) -> String:
	var kind := str(marker.get("kind", "")).strip_edges()
	var match_id := str(marker.get("match_id", "")).strip_edges()
	if kind.is_empty() or match_id.is_empty():
		return ""
	var key := "%s:%s" % [kind, match_id]
	var observer := str(marker.get("observer", "")).strip_edges()
	if not observer.is_empty():
		key += ":%s" % observer
	return key

static func _relay_session_key(match_id: String, observer_session_id: String) -> String:
	return "%s|%s" % [match_id.strip_edges(), observer_session_id.strip_edges()]

## Arm a relay for one approved spectator. The lobby calls this after approval
## and again whenever the spectator bounces from a fresh socket, so a reconnect
## can replace a stale endpoint without exposing the spectator to other rooms.
func enable_relay_session(match_id: String, observer_session_id: String) -> bool:
	if _udp == null or match_id.strip_edges().is_empty() or observer_session_id.strip_edges().is_empty():
		return false
	var key := _relay_session_key(match_id, observer_session_id)
	var session_variant = _relay_sessions.get(key, null)
	var session: Dictionary = session_variant if session_variant is Dictionary else {
		"match_id": match_id.strip_edges(),
		"observer": observer_session_id.strip_edges(),
		"host": {},
		"client": {},
	}
	session["expires_msec"] = Time.get_ticks_msec() + int(RELAY_SESSION_TTL_SECONDS * 1000.0)
	_sync_relay_endpoints(session, key)
	_relay_sessions[key] = session
	if _relay_sessions.size() > MARKER_REGISTRY_LIMIT:
		_prune_oldest_relay_session()
	return true

func disable_relay_session(match_id: String, observer_session_id: String) -> void:
	var key := _relay_session_key(match_id, observer_session_id)
	_relay_sessions.erase(key)
	_relay_ready_printed.erase(key)

func _sync_relay_endpoints(session: Dictionary, key: String) -> void:
	var match_id := str(session.get("match_id", ""))
	var observer := str(session.get("observer", ""))
	var host_bounce := get_bounce("host:%s" % match_id, HOST_BOUNCE_TTL_SECONDS)
	if not host_bounce.is_empty():
		session["host"] = {
			"ip": normalize_ip(str(host_bounce.get("ip", ""))),
			"port": int(host_bounce.get("port", 0)),
		}
	var client_bounce := get_bounce("client:%s:%s" % [match_id, observer], CLIENT_BOUNCE_TTL_SECONDS)
	if not client_bounce.is_empty():
		session["client"] = {
			"ip": normalize_ip(str(client_bounce.get("ip", ""))),
			"port": int(client_bounce.get("port", 0)),
		}
	_check_relay_ready(key, session)

func _refresh_relay_endpoints_from_marker(marker_key: String, bounce: Dictionary) -> void:
	for key in _relay_sessions.keys():
		var session_variant = _relay_sessions.get(key, null)
		if not (session_variant is Dictionary):
			continue
		var session: Dictionary = session_variant
		var match_id := str(session.get("match_id", ""))
		if marker_key == "host:%s" % match_id:
			session["host"] = {
				"ip": normalize_ip(str(bounce.get("ip", ""))),
				"port": int(bounce.get("port", 0)),
			}
		elif marker_key == "client:%s:%s" % [match_id, str(session.get("observer", ""))]:
			session["client"] = {
				"ip": normalize_ip(str(bounce.get("ip", ""))),
				"port": int(bounce.get("port", 0)),
			}
		else:
			continue
		session["expires_msec"] = Time.get_ticks_msec() + int(RELAY_SESSION_TTL_SECONDS * 1000.0)
		_check_relay_ready(str(key), session)

func _check_relay_ready(key: String, session: Dictionary) -> void:
	if _relay_ready_printed.has(key):
		return
	var host_variant = session.get("host", {})
	var client_variant = session.get("client", {})
	if not (host_variant is Dictionary) or not (client_variant is Dictionary):
		return
	var host: Dictionary = host_variant
	var client: Dictionary = client_variant
	if int(host.get("port", 0)) <= 0 or int(client.get("port", 0)) <= 0:
		return
	_relay_ready_printed[key] = true
	print("Spectate breadcrumb role=reflector stage=relay_ready match=%s observer=%s host=%s:%d spectator=%s:%d" % [
		str(session.get("match_id", "")),
		str(session.get("observer", "")),
		str(host.get("ip", "")), int(host.get("port", 0)),
		str(client.get("ip", "")), int(client.get("port", 0)),
	])

func _expire_relay_sessions() -> void:
	var now_msec := Time.get_ticks_msec()
	for key in _relay_sessions.keys():
		var session_variant = _relay_sessions.get(key, null)
		if not (session_variant is Dictionary):
			_relay_sessions.erase(key)
			continue
		if now_msec > int((session_variant as Dictionary).get("expires_msec", 0)):
			_relay_sessions.erase(key)
			_relay_ready_printed.erase(key)

func _forward_relay_packet(packet: PackedByteArray, source_ip: String, source_port: int) -> void:
	if _udp == null or packet.is_empty() or packet.size() > RELAY_MAX_PACKET_BYTES:
		return
	var source := endpoint_key(source_ip, source_port)
	for key in _relay_sessions.keys():
		var session_variant = _relay_sessions.get(key, null)
		if not (session_variant is Dictionary):
			continue
		var session: Dictionary = session_variant
		var host_variant = session.get("host", {})
		var client_variant = session.get("client", {})
		if not (host_variant is Dictionary) or not (client_variant is Dictionary):
			continue
		var host: Dictionary = host_variant
		var client: Dictionary = client_variant
		var host_endpoint := endpoint_key(str(host.get("ip", "")), int(host.get("port", 0)))
		var client_endpoint := endpoint_key(str(client.get("ip", "")), int(client.get("port", 0)))
		if host_endpoint == source:
			# One host socket serves every spectator, so fan out to all of them.
			if client_endpoint != source and int(client.get("port", 0)) > 0:
				_send_relay_packet(client, packet)
		elif client_endpoint == source:
			if host_endpoint != source and int(host.get("port", 0)) > 0:
				_send_relay_packet(host, packet)
				return

func _send_relay_packet(target: Dictionary, packet: PackedByteArray) -> void:
	if _udp.set_dest_address(str(target.get("ip", "")), int(target.get("port", 0))) != OK:
		return
	_udp.put_packet(packet)

func _prune_oldest_relay_session() -> void:
	var oldest_key := ""
	var oldest_msec := 0
	for key in _relay_sessions.keys():
		var session_variant = _relay_sessions.get(key, null)
		if not (session_variant is Dictionary):
			continue
		var msec := int((session_variant as Dictionary).get("expires_msec", 0))
		if oldest_key.is_empty() or msec < oldest_msec:
			oldest_key = str(key)
			oldest_msec = msec
	if not oldest_key.is_empty():
		_relay_sessions.erase(oldest_key)
		_relay_ready_printed.erase(oldest_key)

func setup(port: int) -> bool:
	if port <= 0:
		return false
	var udp := PacketPeerUDP.new()
	if udp.bind(port) != OK:
		return false
	_udp = udp
	bound_port = port
	return true

## Latest bounce recorded for a key, or {} when missing or older than the
## allowed age (bounces are only meaningful while the NAT mapping is fresh).
func get_bounce(key: String, max_age_seconds: float) -> Dictionary:
	if key.is_empty():
		return {}
	var bounce_variant = _bounce_by_key.get(key, null)
	if not (bounce_variant is Dictionary):
		return {}
	var bounce: Dictionary = bounce_variant
	var age_seconds := (Time.get_ticks_msec() - int(bounce.get("msec", 0))) / 1000.0
	if age_seconds < 0.0 or age_seconds > max_age_seconds:
		return {}
	return bounce.duplicate(true)

func _process(_delta: float) -> void:
	if _udp == null:
		return
	_expire_relay_sessions()
	while _udp.get_available_packet_count() > 0:
		var packet := _udp.get_packet()
		var source_ip := normalize_ip(_udp.get_packet_ip())
		var source_port := int(_udp.get_packet_port())
		# Markers are JSON.stringify objects and always start with '{'. ENet
		# traffic is binary; parsing it only produces console errors and waste.
		if packet.is_empty() or packet[0] != 123:
			_forward_relay_packet(packet, source_ip, source_port)
			continue
		var marker_variant = JSON.parse_string(packet.get_string_from_utf8())
		if is_punch_marker(marker_variant):
			var marker_key := PunchReflector.get_marker_key(marker_variant)
			if marker_key.is_empty():
				continue
			var bounce := {
				"ip": source_ip,
				"port": source_port,
				"msec": Time.get_ticks_msec(),
			}
			_bounce_by_key[marker_key] = bounce
			if _bounce_by_key.size() > MARKER_REGISTRY_LIMIT:
				_prune_oldest_bounce()
			_refresh_relay_endpoints_from_marker(marker_key, bounce)
			continue
		# Non-marker traffic is only forwarded for an approved, endpoint-matched
		# session; everything else is ignored without further parsing.
		_forward_relay_packet(packet, source_ip, source_port)

func _prune_oldest_bounce() -> void:
	var oldest_key := ""
	var oldest_msec := 0
	for key in _bounce_by_key.keys():
		var bounce = _bounce_by_key.get(key, {})
		if not (bounce is Dictionary):
			continue
		var msec := int((bounce as Dictionary).get("msec", 0))
		if oldest_key.is_empty() or msec < oldest_msec:
			oldest_key = str(key)
			oldest_msec = msec
	if not oldest_key.is_empty():
		_bounce_by_key.erase(oldest_key)

func shutdown() -> void:
	if _udp != null:
		_udp.close()
		_udp = null
	bound_port = 0
	_bounce_by_key.clear()
	_relay_sessions.clear()
	_relay_ready_printed.clear()

func _exit_tree() -> void:
	shutdown()
