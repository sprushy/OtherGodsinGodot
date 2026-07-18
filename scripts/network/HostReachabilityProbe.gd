extends RefCounted
## HostReachabilityProbe
##
## Best-effort UPnP/IGD probe that determines whether this client can host a
## player-hosted (listen-server) match reachable from the public internet. When
## viable, returns the router's external IP and a freshly-mapped external port
## that the opponent can connect to. This is the automatic, no-user-config path
## for player hosting; the lobby server still verifies inbound reachability
## before committing to a player-hosted assignment, and falls back to the
## dedicated server when UPnP is unavailable or behind CGNAT.
##
## The probe never raises: any failure (no UPnP module, no gateway, mapping
## denied) resolves to a not-viable Dictionary. It performs only the local
## UPnP/IGD exchange; no gameplay network bytes are sent.

const DISCOVER_TIMEOUT_MSEC := 2000
const DISCOVER_TTL := 2
const MAPPING_PROTO := "UDP"
const MAX_EXTERNAL_PORT_ATTEMPTS := 4

## Probe whether the local machine can host on local_port. Returns:
##   { viable: bool, reachable_ip: String, reachable_port: int, bind_port: int, reason: String }
## bind_port mirrors local_port (the host binds the same port internally);
## reachable_port is the external mapped port the opponent should target.
static func probe(local_port: int) -> Dictionary:
	var resolved_local_port := int(local_port)
	if resolved_local_port <= 0 or resolved_local_port > 65535:
		return _not_viable("Invalid host port.")
	if not ClassDB.class_exists("UPNP"):
		return _not_viable("UPnP is not available in this build.")
	var upnp = UPNP.new()
	var discover_err := upnp.discover(DISCOVER_TIMEOUT_MSEC, DISCOVER_TTL, "InternetGatewayDevice")
	if discover_err != OK:
		return _not_viable("No UPnP gateway was discovered.")
	var gateway = upnp.get_gateway()
	if gateway == null or not gateway.is_valid_gateway():
		return _not_viable("The discovered UPnP gateway is not usable.")
	var external_ip := str(upnp.query_external_address()).strip_edges()
	if external_ip.is_empty() or external_ip == "0.0.0.0":
		return _not_viable("Could not determine the router's external address.")
	var mapped_external_port := _add_port_mapping(upnp, resolved_local_port)
	if mapped_external_port <= 0:
		return _not_viable("The router refused the UPnP port mapping.")
	# Delete the discovery device list and free the UPNP instance; the mapping
	# persists on the router for the lifetime of this process (or until the
	# router's lease expires). The host's ENet server binds resolved_local_port.
	return {
		"viable": true,
		"reachable_ip": external_ip,
		"reachable_port": mapped_external_port,
		"bind_port": resolved_local_port,
		"reason": "",
	}

## Try the preferred external port (== local port) and a few neighbors. Returns
## the external port that was successfully mapped, or 0 on total failure.
static func _add_port_mapping(upnp, local_port: int) -> int:
	var candidate := local_port
	for attempt in range(MAX_EXTERNAL_PORT_ATTEMPTS):
		var err: int = upnp.add_port_mapping(local_port, candidate, "", MAPPING_PROTO)
		if err == OK:
			return candidate
		# Walk a small window above the requested port; avoid privileged ports.
		candidate = local_port + attempt + 1
		if candidate > 65535:
			break
	return 0

## Best-effort removal of a previously-created mapping. Called when the host
## match ends so the router mapping does not linger. Failures are ignored.
static func remove_mapping(external_port: int) -> void:
	if external_port <= 0 or not ClassDB.class_exists("UPNP"):
		return
	var upnp = UPNP.new()
	if upnp.discover(DISCOVER_TIMEOUT_MSEC, DISCOVER_TTL, "InternetGatewayDevice") != OK:
		return
	if upnp.get_gateway() == null or not upnp.get_gateway().is_valid_gateway():
		return
	upnp.delete_port_mapping(int(external_port), MAPPING_PROTO)

static func _not_viable(reason: String) -> Dictionary:
	return {
		"viable": false,
		"reachable_ip": "",
		"reachable_port": 0,
		"bind_port": 0,
		"reason": reason,
	}
