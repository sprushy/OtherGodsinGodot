extends RefCounted

const PUBLIC_URL_SETTING := "application/config/public_websocket_url"
const PUBLIC_URL_ENV := "OTHERGODS_PUBLIC_WEBSOCKET_URL"
const MATCH_PORT_COUNT := 64

static func public_base_url() -> String:
	var configured := OS.get_environment(PUBLIC_URL_ENV).strip_edges()
	if configured.is_empty():
		configured = str(ProjectSettings.get_setting(PUBLIC_URL_SETTING, "")).strip_edges()
	return configured.trim_suffix("/")

static func is_websocket_url(address: String) -> bool:
	return address.begins_with("wss://") or address.begins_with("ws://")

static func is_valid_base_url(address: String) -> bool:
	if not is_websocket_url(address):
		return false
	var authority := address.get_slice("://", 1)
	if authority.is_empty():
		return false
	for delimiter in ["/", "?", "#", "@", " ", "\t", "\n", "\r"]:
		if authority.contains(delimiter):
			return false
	return address.begins_with("wss://") or authority.get_slice(":", 0) in ["localhost", "127.0.0.1"]

static func lobby_url(address: String) -> String:
	if is_websocket_url(address):
		return address
	var configured := public_base_url()
	var default_host := str(ProjectSettings.get_setting("application/config/default_lobby_host", ""))
	if not configured.is_empty() and (address == default_host or not OS.get_environment(PUBLIC_URL_ENV).is_empty()):
		return configured + "/lobby"
	if address.contains(":"):
		return "wss://[%s]/lobby" % address
	return "wss://%s/lobby" % address

static func match_url(base_url: String, port: int) -> String:
	if not is_valid_base_url(base_url.trim_suffix("/")) or port <= 0 or port > 65535:
		return ""
	return "%s/match/%d" % [base_url.trim_suffix("/"), port]
