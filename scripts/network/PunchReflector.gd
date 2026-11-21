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

var bound_port: int = 0

var _udp: PacketPeerUDP = null
var _bounce_by_key: Dictionary = {}

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
## hands its local port to ENet even if the host's punch is delayed.
static func prime_spectator_socket(
	tree: SceneTree, host_ip: String, host_port: int, reflector_host: String, reflector_port: int,
	marker: PackedByteArray, host_punch: PackedByteArray, report_ready: Callable
) -> Dictionary:
	if host_ip.is_empty() or host_port <= 0:
		return {}
	var socket := PacketPeerUDP.new()
	if socket.bind(0) != OK:
		return {}
	var local_port := socket.get_local_port()
	var punch := make_marker(PUNCH_KIND_PACKET, "")
	var advertised_ip := normalize_ip(host_ip)
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
				return {"local_port": local_port, "host_port": reply_port, "host_replied": true}
	socket.close()
	return {"local_port": local_port, "host_port": host_port, "host_replied": false}

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
	while _udp.get_available_packet_count() > 0:
		var packet := _udp.get_packet()
		var marker_variant = JSON.parse_string(packet.get_string_from_utf8())
		if not is_punch_marker(marker_variant):
			# Never parse strangers' traffic beyond the marker check.
			continue
		var bounce := {
			"ip": normalize_ip(_udp.get_packet_ip()),
			"port": _udp.get_packet_port(),
			"msec": Time.get_ticks_msec(),
		}
		_bounce_by_key[PunchReflector.get_marker_key(marker_variant)] = bounce
		if _bounce_by_key.size() > MARKER_REGISTRY_LIMIT:
			_prune_oldest_bounce()

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

func _exit_tree() -> void:
	shutdown()
