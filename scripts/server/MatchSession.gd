extends RefCounted
class_name MatchSession

const STATUS_STARTING := "starting"
const STATUS_ACTIVE := "active"
const STATUS_FINISHED := "finished"
const STATUS_ABANDONED := "abandoned"
const SERVER_MODE_IN_PROCESS_HOST := "in_process_host"
const SERVER_MODE_DEDICATED_HEADLESS := "dedicated_headless"

var match_id: String = ""
var room_id: String = ""
var server_ip: String = "127.0.0.1"
var match_port: int = 12345
var player_session_ids: Array[String] = []
var status: String = STATUS_STARTING
var server_mode: String = SERVER_MODE_IN_PROCESS_HOST
var is_ranked: bool = true
var launch_config_path: String = ""
var process_id: int = 0
var process_launch_error: String = ""
var reconnect_deadline_unix: int = 0
var reconnect_window_seconds: int = 30
var player_match_tokens: Dictionary = {}
var player_decks_by_session: Dictionary = {}
var player_identity_by_session: Dictionary = {}
var session_id_by_peer: Dictionary = {}
var peer_id_by_session: Dictionary = {}
var disconnected_sessions: Dictionary = {}

var _rng := RandomNumberGenerator.new()

func _init(
	p_match_id: String = "",
	p_room_id: String = "",
	p_server_ip: String = "127.0.0.1",
	p_match_port: int = 12345,
	p_player_session_ids: Array[String] = [],
	p_player_decks_by_session: Dictionary = {},
	p_player_identity_by_session: Dictionary = {}
) -> void:
	_rng.randomize()
	match_id = p_match_id
	room_id = p_room_id
	server_ip = p_server_ip
	match_port = p_match_port
	player_session_ids = p_player_session_ids.duplicate()
	player_decks_by_session = p_player_decks_by_session.duplicate(true)
	player_identity_by_session = p_player_identity_by_session.duplicate(true)
	_ensure_player_match_tokens()

func mark_active() -> void:
	status = STATUS_ACTIVE

func mark_finished() -> void:
	status = STATUS_FINISHED

func mark_abandoned() -> void:
	status = STATUS_ABANDONED

func get_player_index(session_id: String) -> int:
	return player_session_ids.find(session_id)

func get_match_token(session_id: String) -> String:
	return str(player_match_tokens.get(session_id, ""))

func get_player_identity(session_id: String) -> Dictionary:
	var identity = player_identity_by_session.get(session_id, {})
	if identity is Dictionary:
		return (identity as Dictionary).duplicate(true)
	return {}

func authenticate_join(session_id: String, match_token: String, peer_id: int) -> int:
	if get_match_token(session_id) != match_token:
		return -1
	var player_index := get_player_index(session_id)
	if player_index == -1:
		return -1
	var previous_peer_id := int(peer_id_by_session.get(session_id, 0))
	if previous_peer_id > 0:
		session_id_by_peer.erase(previous_peer_id)
	for existing_peer_id in session_id_by_peer.keys():
		if int(existing_peer_id) == peer_id:
			var existing_session_id := str(session_id_by_peer[existing_peer_id])
			peer_id_by_session.erase(existing_session_id)
			session_id_by_peer.erase(existing_peer_id)
			break
	session_id_by_peer[peer_id] = session_id
	peer_id_by_session[session_id] = peer_id
	disconnected_sessions.erase(session_id)
	_refresh_reconnect_deadline()
	return player_index

func note_peer_disconnected(peer_id: int) -> Dictionary:
	var session_id := str(session_id_by_peer.get(peer_id, ""))
	if session_id.is_empty():
		return {}
	session_id_by_peer.erase(peer_id)
	peer_id_by_session.erase(session_id)
	var player_index := get_player_index(session_id)
	var deadline_unix := Time.get_unix_time_from_system() + reconnect_window_seconds
	disconnected_sessions[session_id] = deadline_unix
	_refresh_reconnect_deadline()
	return {
		"session_id": session_id,
		"player_index": player_index,
		"reconnect_deadline_unix": deadline_unix,
	}

func clear_peer(peer_id: int) -> void:
	note_peer_disconnected(peer_id)

func is_waiting_for_reconnect() -> bool:
	return not disconnected_sessions.is_empty()

func is_session_waiting_for_reconnect(session_id: String) -> bool:
	return disconnected_sessions.has(session_id)

func get_reconnect_deadline_for_session(session_id: String) -> int:
	return int(disconnected_sessions.get(session_id, 0))

func all_players_connected() -> bool:
	for session_id in player_session_ids:
		if not peer_id_by_session.has(session_id):
			return false
	return not player_session_ids.is_empty()

func is_dedicated_headless() -> bool:
	return server_mode == SERVER_MODE_DEDICATED_HEADLESS

func has_spawned_process() -> bool:
	return process_id > 0

func has_reconnect_timed_out(now_unix: int = -1) -> bool:
	if reconnect_deadline_unix <= 0:
		return false
	var resolved_now := now_unix if now_unix >= 0 else int(Time.get_unix_time_from_system())
	return resolved_now >= reconnect_deadline_unix

func clear_process_tracking() -> void:
	process_id = 0
	launch_config_path = ""

func to_match_info(session_id: String = "") -> Dictionary:
	var match_info := {
		"match_id": match_id,
		"room_id": room_id,
		"server_ip": server_ip,
		"match_port": match_port,
		"player_index": get_player_index(session_id) if not session_id.is_empty() else -1,
		"status": status,
		"server_mode": server_mode,
		"is_ranked": is_ranked,
	}
	if not session_id.is_empty():
		var selected_deck := _get_player_deck(session_id)
		match_info["session_id"] = session_id
		match_info["match_token"] = get_match_token(session_id)
		match_info["reconnect_deadline_unix"] = get_reconnect_deadline_for_session(session_id)
		match_info["selected_deck_name"] = str(selected_deck.get("deck_name", ""))
		match_info["selected_deck_cards"] = selected_deck.get("cards", {})
	match_info["reconnect_window_seconds"] = reconnect_window_seconds
	match_info["waiting_for_reconnect"] = is_waiting_for_reconnect()
	return match_info

func to_launch_config() -> Dictionary:
	return {
		"match_id": match_id,
		"room_id": room_id,
		"server_ip": server_ip,
		"match_port": match_port,
		"player_session_ids": player_session_ids.duplicate(),
		"status": status,
		"server_mode": server_mode,
		"is_ranked": is_ranked,
		"reconnect_window_seconds": reconnect_window_seconds,
		"player_match_tokens": player_match_tokens.duplicate(true),
		"player_decks_by_session": player_decks_by_session.duplicate(true),
		"player_identity_by_session": player_identity_by_session.duplicate(true),
	}

func mark_process_launched(p_process_id: int, p_launch_config_path: String) -> void:
	process_id = p_process_id
	launch_config_path = p_launch_config_path
	process_launch_error = ""

func mark_process_launch_failed(message: String) -> void:
	process_id = 0
	process_launch_error = message

static func from_launch_config(config: Dictionary) -> MatchSession:
	if config.is_empty():
		return null
	var session := MatchSession.new(
		str(config.get("match_id", "")),
		str(config.get("room_id", "")),
		str(config.get("server_ip", "127.0.0.1")),
		int(config.get("match_port", 12345)),
		_to_string_array(config.get("player_session_ids", [])),
		_to_dictionary(config.get("player_decks_by_session", {})),
		_to_dictionary(config.get("player_identity_by_session", {}))
	)
	session.status = str(config.get("status", STATUS_STARTING))
	session.server_mode = str(config.get("server_mode", SERVER_MODE_IN_PROCESS_HOST))
	session.is_ranked = bool(config.get("is_ranked", true))
	session.reconnect_window_seconds = int(config.get("reconnect_window_seconds", 30))
	var configured_tokens = config.get("player_match_tokens", {})
	if configured_tokens is Dictionary:
		session.player_match_tokens = (configured_tokens as Dictionary).duplicate(true)
	session._ensure_player_match_tokens()
	return session

static func _to_string_array(value) -> Array[String]:
	var output: Array[String] = []
	if not (value is Array):
		return output
	for entry in value:
		output.append(str(entry))
	return output

static func _to_dictionary(value) -> Dictionary:
	if value is Dictionary:
		return (value as Dictionary).duplicate(true)
	return {}

func _get_player_deck(session_id: String) -> Dictionary:
	var deck = player_decks_by_session.get(session_id, {})
	if deck is Dictionary:
		return (deck as Dictionary).duplicate(true)
	return {}

func _ensure_player_match_tokens() -> void:
	for session_id in player_session_ids:
		if player_match_tokens.has(session_id):
			continue
		player_match_tokens[session_id] = _generate_token(20)

func _generate_token(length: int) -> String:
	const CHARS := "ABCDEFGHJKLMNPQRSTUVWXYZ23456789"
	var output := ""
	for _i in length:
		output += CHARS[_rng.randi_range(0, CHARS.length() - 1)]
	return output

func _refresh_reconnect_deadline() -> void:
	reconnect_deadline_unix = 0
	for session_id in disconnected_sessions.keys():
		reconnect_deadline_unix = maxi(reconnect_deadline_unix, int(disconnected_sessions[session_id]))
