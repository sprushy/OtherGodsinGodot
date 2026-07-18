extends RefCounted
class_name MatchSession

const STATUS_STARTING := "starting"
const STATUS_ACTIVE := "active"
const STATUS_FINISHED := "finished"
const STATUS_ABANDONED := "abandoned"
const SERVER_MODE_IN_PROCESS_HOST := "in_process_host"
const SERVER_MODE_DEDICATED_HEADLESS := "dedicated_headless"
const SERVER_MODE_PLAYER_HOST := "player_host"
const BOT_SESSION_PREFIX := "BOT_"

var match_id: String = ""
var room_id: String = ""
var server_ip: String = "127.0.0.1"
var match_port: int = 12345
var player_session_ids: Array[String] = []
var status: String = STATUS_STARTING
var server_mode: String = SERVER_MODE_IN_PROCESS_HOST
var is_ranked: bool = true
var launch_config_path: String = ""
var status_file_path: String = ""
var process_id: int = 0
var process_launch_error: String = ""
var reconnect_deadline_unix: int = 0
var reconnect_window_seconds: int = 90
var created_unix: int = 0
var player_match_tokens: Dictionary = {}
var player_decks_by_session: Dictionary = {}
var player_identity_by_session: Dictionary = {}
var session_id_by_peer: Dictionary = {}
var peer_id_by_session: Dictionary = {}
var disconnected_sessions: Dictionary = {}
var spectator_peer_ids: Array[int] = []
var spectator_visible_player_indices_by_session: Dictionary = {}
var spectator_match_tokens_by_session: Dictionary = {}
var series_best_of: int = 1
var games_to_win: int = 1
var series_game_number: int = 1
var series_wins_by_session: Dictionary = {}
var registered_player_decks_by_session: Dictionary = {}
var reinforcement_ready_by_session: Dictionary = {}

## Player-hosted (listen-server) match bookkeeping. Only meaningful when
## server_mode == SERVER_MODE_PLAYER_HOST. host_session_id names the player who
## runs the authoritative match; host_reachable_ip/port is their UPnP-mapped
## public endpoint the opponent connects to. host_bind_port is the local port
## the host binds and that the lobby probes for inbound reachability.
var host_session_id: String = ""
var host_reachable_ip: String = ""
var host_reachable_port: int = 0
var host_bind_port: int = 0

func _init(
	p_match_id: String = "",
	p_room_id: String = "",
	p_server_ip: String = "127.0.0.1",
	p_match_port: int = 12345,
	p_player_session_ids: Array[String] = [],
	p_player_decks_by_session: Dictionary = {},
	p_player_identity_by_session: Dictionary = {}
) -> void:
	match_id = p_match_id
	room_id = p_room_id
	server_ip = p_server_ip
	match_port = p_match_port
	player_session_ids = p_player_session_ids.duplicate()
	player_decks_by_session = p_player_decks_by_session.duplicate(true)
	registered_player_decks_by_session = p_player_decks_by_session.duplicate(true)
	player_identity_by_session = p_player_identity_by_session.duplicate(true)
	created_unix = int(Time.get_unix_time_from_system())
	_ensure_player_match_tokens()
	_ensure_series_state()

func mark_active() -> void:
	status = STATUS_ACTIVE

func mark_finished() -> void:
	status = STATUS_FINISHED

func mark_abandoned() -> void:
	status = STATUS_ABANDONED

func configure_series_format(best_of: int) -> void:
	series_best_of = 3 if best_of == 3 else 1
	games_to_win = 2 if series_best_of == 3 else 1

func get_player_index(session_id: String) -> int:
	return player_session_ids.find(session_id)

func is_bot_session(session_id: String) -> bool:
	var resolved_session_id := session_id.strip_edges()
	if resolved_session_id.is_empty():
		return false
	var identity := get_player_identity(resolved_session_id)
	if bool(identity.get("is_bot", false)):
		return true
	return resolved_session_id.to_upper().begins_with(BOT_SESSION_PREFIX)

func get_human_player_count() -> int:
	var count := 0
	for session_id in player_session_ids:
		if is_bot_session(str(session_id)):
			continue
		count += 1
	return count

func get_connected_human_player_count() -> int:
	var count := 0
	for session_id in player_session_ids:
		var resolved_session_id := str(session_id).strip_edges()
		if resolved_session_id.is_empty() or is_bot_session(resolved_session_id):
			continue
		if peer_id_by_session.has(resolved_session_id):
			count += 1
	return count

func get_player_index_for_peer(peer_id: int) -> int:
	var session_id := str(session_id_by_peer.get(peer_id, "")).strip_edges()
	if session_id.is_empty():
		return -1
	return get_player_index(session_id)

func get_match_token(session_id: String) -> String:
	return str(player_match_tokens.get(session_id, ""))

func get_spectator_match_token(session_id: String) -> String:
	return str(spectator_match_tokens_by_session.get(session_id.strip_edges(), ""))

func get_player_identity(session_id: String) -> Dictionary:
	var identity = player_identity_by_session.get(session_id, {})
	if identity is Dictionary:
		return (identity as Dictionary).duplicate(true)
	return {}

func get_player_display_name(session_id: String, player_index: int = -1) -> String:
	var resolved_index := player_index
	if resolved_index < 0:
		resolved_index = get_player_index(session_id)
	var fallback := "Player"
	if resolved_index >= 0:
		fallback = "Player %d" % [resolved_index + 1]
	var identity := get_player_identity(session_id)
	var username := str(identity.get("username", "")).strip_edges()
	if not username.is_empty():
		return username
	var player_name := str(identity.get("player_name", "")).strip_edges()
	if not player_name.is_empty():
		return player_name
	return fallback

func get_public_player_names() -> Array[String]:
	var names: Array[String] = []
	for player_index in range(player_session_ids.size()):
		var session_id := str(player_session_ids[player_index]).strip_edges()
		names.append(get_player_display_name(session_id, player_index))
	return names

func record_series_game_win(winner_index: int) -> Dictionary:
	if winner_index < 0 or winner_index >= player_session_ids.size():
		return get_series_snapshot()
	var winner_session_id := str(player_session_ids[winner_index]).strip_edges()
	series_wins_by_session[winner_session_id] = int(series_wins_by_session.get(winner_session_id, 0)) + 1
	reinforcement_ready_by_session.clear()
	return get_series_snapshot()

func is_series_complete() -> bool:
	for session_id in player_session_ids:
		if int(series_wins_by_session.get(session_id, 0)) >= games_to_win:
			return true
	return false

func begin_next_series_game() -> void:
	series_game_number += 1
	reinforcement_ready_by_session.clear()

func set_reinforcement_ready(session_id: String, ready: bool = true) -> void:
	var resolved_session_id := session_id.strip_edges()
	if resolved_session_id.is_empty() or not player_session_ids.has(resolved_session_id):
		return
	reinforcement_ready_by_session[resolved_session_id] = ready

func all_reinforcement_submissions_ready() -> bool:
	for session_id in player_session_ids:
		if not bool(reinforcement_ready_by_session.get(session_id, false)):
			return false
	return not player_session_ids.is_empty()

func get_series_snapshot() -> Dictionary:
	var wins: Array[int] = []
	for session_id in player_session_ids:
		wins.append(int(series_wins_by_session.get(session_id, 0)))
	return {
		"best_of": series_best_of,
		"games_to_win": games_to_win,
		"game_number": series_game_number,
		"wins": wins,
		"is_complete": is_series_complete(),
	}

func authenticate_join(session_id: String, match_token: String, peer_id: int) -> int:
	var resolved_session_id := session_id.strip_edges()
	if is_bot_session(resolved_session_id):
		return -1
	var expected_token := get_match_token(resolved_session_id)
	if peer_id <= 0 \
		or resolved_session_id.is_empty() \
		or expected_token.is_empty() \
		or match_token.is_empty() \
		or expected_token != match_token:
		return -1
	var player_index := get_player_index(resolved_session_id)
	if player_index == -1:
		return -1
	var existing_session_id := str(session_id_by_peer.get(peer_id, "")).strip_edges()
	if not existing_session_id.is_empty() and existing_session_id != resolved_session_id:
		return -1
	var previous_peer_id := int(peer_id_by_session.get(resolved_session_id, 0))
	if previous_peer_id > 0:
		session_id_by_peer.erase(previous_peer_id)
	for existing_peer_id in session_id_by_peer.keys():
		if int(existing_peer_id) == peer_id:
			var mapped_session_id := str(session_id_by_peer[existing_peer_id])
			peer_id_by_session.erase(mapped_session_id)
			session_id_by_peer.erase(existing_peer_id)
			break
	session_id_by_peer[peer_id] = resolved_session_id
	peer_id_by_session[resolved_session_id] = peer_id
	disconnected_sessions.erase(resolved_session_id)
	spectator_peer_ids.erase(peer_id)
	_refresh_reconnect_deadline()
	return player_index

func note_peer_disconnected(peer_id: int) -> Dictionary:
	if spectator_peer_ids.has(peer_id):
		spectator_peer_ids.erase(peer_id)
		return {}
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

func add_spectator_peer(peer_id: int) -> void:
	if peer_id <= 0 or spectator_peer_ids.has(peer_id):
		return
	spectator_peer_ids.append(peer_id)

func authenticate_spectator(session_id: String, match_token: String, peer_id: int) -> bool:
	var resolved_session_id := session_id.strip_edges()
	var expected_token := get_spectator_match_token(resolved_session_id)
	if peer_id <= 0 \
		or session_id_by_peer.has(peer_id) \
		or resolved_session_id.is_empty() \
		or expected_token.is_empty() \
		or match_token.is_empty() \
		or expected_token != match_token:
		return false
	add_spectator_peer(peer_id)
	return true

func is_spectator_peer(peer_id: int) -> bool:
	return spectator_peer_ids.has(peer_id)

func get_spectator_peer_ids() -> Array[int]:
	return spectator_peer_ids.duplicate()

func set_spectator_visible_player_indices(session_id: String, player_indices: Array) -> void:
	var resolved_session_id := session_id.strip_edges()
	if resolved_session_id.is_empty():
		return
	if not spectator_match_tokens_by_session.has(resolved_session_id):
		spectator_match_tokens_by_session[resolved_session_id] = _generate_token(20)
	var sanitized: Array[int] = []
	for raw_index in player_indices:
		var player_index := int(raw_index)
		if player_index < 0 or player_index >= player_session_ids.size() or player_index in sanitized:
			continue
		sanitized.append(player_index)
	spectator_visible_player_indices_by_session[resolved_session_id] = sanitized

func get_spectator_visible_player_indices(session_id: String) -> Array[int]:
	var resolved_session_id := session_id.strip_edges()
	if resolved_session_id.is_empty():
		return []
	var stored = spectator_visible_player_indices_by_session.get(resolved_session_id, [])
	var output: Array[int] = []
	if not (stored is Array):
		return output
	for raw_index in stored:
		var player_index := int(raw_index)
		if player_index < 0 or player_index >= player_session_ids.size() or player_index in output:
			continue
		output.append(player_index)
	return output

func is_waiting_for_reconnect() -> bool:
	return not disconnected_sessions.is_empty()

func is_session_waiting_for_reconnect(session_id: String) -> bool:
	return disconnected_sessions.has(session_id)

func get_reconnect_deadline_for_session(session_id: String) -> int:
	return int(disconnected_sessions.get(session_id, 0))

func all_players_connected() -> bool:
	for session_id in player_session_ids:
		if is_bot_session(str(session_id)):
			continue
		if not peer_id_by_session.has(session_id):
			return false
	return not player_session_ids.is_empty()

func is_dedicated_headless() -> bool:
	return server_mode == SERVER_MODE_DEDICATED_HEADLESS

func is_player_host() -> bool:
	return server_mode == SERVER_MODE_PLAYER_HOST

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
	status_file_path = ""

func to_match_info(session_id: String = "") -> Dictionary:
	var match_info := {
		"match_id": match_id,
		"room_id": room_id,
		"server_ip": server_ip,
		"match_port": match_port,
		"player_index": get_player_index(session_id) if not session_id.is_empty() else -1,
		"player_names": get_public_player_names(),
		"status": status,
		"server_mode": server_mode,
		"is_ranked": is_ranked,
		"series": get_series_snapshot(),
	}
	if not session_id.is_empty():
		var selected_deck := _get_player_deck(session_id)
		match_info["session_id"] = session_id
		match_info["match_token"] = get_match_token(session_id)
		match_info["reconnect_deadline_unix"] = get_reconnect_deadline_for_session(session_id)
		match_info["selected_deck_name"] = str(selected_deck.get("deck_name", ""))
		match_info["selected_deck_cards"] = selected_deck.get("cards", {})
		match_info["selected_deck_reinforcements"] = selected_deck.get("reinforcements", {})
		match_info["selected_deck_special_setup"] = selected_deck.get("special_setup", {})
	match_info["reconnect_window_seconds"] = reconnect_window_seconds
	match_info["waiting_for_reconnect"] = is_waiting_for_reconnect()
	_apply_player_host_match_info(match_info, session_id)
	return match_info

## For SERVER_MODE_PLAYER_HOST, override server_ip/match_port per recipient:
## the host binds locally (no remote endpoint), while the opponent and any
## spectators are pointed at the host's UPnP-mapped public endpoint. Also emit
## is_match_host so the host client knows to launch authoritatively. The host
## additionally receives the full roster (session ids, tokens, identities, decks)
## so its local MatchSession can authenticate the opponent's join and resolve
## the right per-player state.
func _apply_player_host_match_info(match_info: Dictionary, session_id: String) -> void:
	if not is_player_host():
		return
	var is_recipient_host := not session_id.is_empty() and session_id == host_session_id
	match_info["is_match_host"] = is_recipient_host
	match_info["host_session_id"] = host_session_id
	match_info["host_bind_port"] = host_bind_port
	match_info["host_reachable_ip"] = host_reachable_ip
	match_info["host_reachable_port"] = host_reachable_port
	if is_recipient_host:
		# The host binds its own port; it does not connect to a remote endpoint.
		match_info["server_ip"] = "127.0.0.1"
		match_info["match_port"] = host_bind_port
		_apply_host_roster(match_info)
	elif host_reachable_ip != "" and host_reachable_port > 0:
		match_info["server_ip"] = host_reachable_ip
		match_info["match_port"] = host_reachable_port

## Host-private roster: every player's session id, match token, identity, and
## submitted deck. Lets the host client rebuild a MatchSession capable of
## authenticating joins and seeding both Player objects.
func _apply_host_roster(match_info: Dictionary) -> void:
	var roster: Array = []
	for player_session_id in player_session_ids:
		var resolved_session_id := str(player_session_id).strip_edges()
		if resolved_session_id.is_empty():
			continue
		var deck := _get_player_deck(resolved_session_id)
		roster.append({
			"session_id": resolved_session_id,
			"match_token": get_match_token(resolved_session_id),
			"identity": get_player_identity(resolved_session_id),
			"deck_name": str(deck.get("deck_name", "")),
			"cards": deck.get("cards", {}),
			"reinforcements": deck.get("reinforcements", {}),
			"special_setup": deck.get("special_setup", {}),
		})
	match_info["host_roster"] = roster

func to_spectator_match_info(observer_session_id: String = "") -> Dictionary:
	var match_info := to_match_info("")
	match_info["observer_mode"] = true
	match_info["player_index"] = -1
	var resolved_observer_session_id := observer_session_id.strip_edges()
	match_info["observer_session_id"] = resolved_observer_session_id
	match_info["observer_match_token"] = get_spectator_match_token(resolved_observer_session_id)
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
		"created_unix": created_unix,
		"status_file_path": status_file_path,
		"player_match_tokens": player_match_tokens.duplicate(true),
		"player_decks_by_session": player_decks_by_session.duplicate(true),
		"player_identity_by_session": player_identity_by_session.duplicate(true),
		"series_best_of": series_best_of,
		"games_to_win": games_to_win,
		"series_game_number": series_game_number,
		"series_wins_by_session": series_wins_by_session.duplicate(true),
		"registered_player_decks_by_session": registered_player_decks_by_session.duplicate(true),
		"reinforcement_ready_by_session": reinforcement_ready_by_session.duplicate(true),
		"spectator_visible_player_indices_by_session": spectator_visible_player_indices_by_session.duplicate(true),
		"spectator_match_tokens_by_session": spectator_match_tokens_by_session.duplicate(true),
		"host_session_id": host_session_id,
		"host_reachable_ip": host_reachable_ip,
		"host_reachable_port": host_reachable_port,
		"host_bind_port": host_bind_port,
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
	session.reconnect_window_seconds = int(config.get("reconnect_window_seconds", 90))
	session.created_unix = int(config.get("created_unix", session.created_unix))
	session.configure_series_format(int(config.get("series_best_of", 1)))
	session.series_game_number = int(config.get("series_game_number", 1))
	session.series_wins_by_session = _to_dictionary(config.get("series_wins_by_session", {}))
	session.registered_player_decks_by_session = _to_dictionary(
		config.get("registered_player_decks_by_session", session.player_decks_by_session)
	)
	session.reinforcement_ready_by_session = _to_dictionary(config.get("reinforcement_ready_by_session", {}))
	session.status_file_path = str(config.get("status_file_path", "")).strip_edges()
	session.launch_config_path = str(config.get("_launch_config_path", "")).strip_edges()
	var configured_tokens = config.get("player_match_tokens", {})
	if configured_tokens is Dictionary:
		session.player_match_tokens = (configured_tokens as Dictionary).duplicate(true)
	var configured_spectator_visibility = config.get("spectator_visible_player_indices_by_session", {})
	if configured_spectator_visibility is Dictionary:
		session.spectator_visible_player_indices_by_session = (configured_spectator_visibility as Dictionary).duplicate(true)
	var configured_spectator_tokens = config.get("spectator_match_tokens_by_session", {})
	if configured_spectator_tokens is Dictionary:
		session.spectator_match_tokens_by_session = (configured_spectator_tokens as Dictionary).duplicate(true)
	session._ensure_player_match_tokens()
	session._ensure_series_state()
	session.host_session_id = str(config.get("host_session_id", "")).strip_edges()
	session.host_reachable_ip = str(config.get("host_reachable_ip", "")).strip_edges()
	session.host_reachable_port = int(config.get("host_reachable_port", 0))
	session.host_bind_port = int(config.get("host_bind_port", 0))
	return session

## Reconstruct a MatchSession on the host client from the lobby-provided
## match_info payload. The host needs the full roster (player session IDs,
## match tokens, identities, decks) for the authenticated join path
## (HeadlessMatchHost._on_match_join_requested -> authenticate_join) to validate
## the opponent and seed both Player objects. The roster is carried in
## match_info["host_roster"] (host-private; only emitted to the host recipient).
static func from_match_info(match_info: Dictionary) -> MatchSession:
	if match_info.is_empty():
		return null
	var match_id := str(match_info.get("match_id", "")).strip_edges()
	var room_id := str(match_info.get("room_id", "")).strip_edges()
	var roster_value = match_info.get("host_roster", [])
	var roster: Array = roster_value if roster_value is Array else []
	var player_session_ids: Array[String] = []
	var decks_by_session: Dictionary = {}
	var identity_by_session: Dictionary = {}
	var tokens_by_session: Dictionary = {}
	for entry in roster:
		if not (entry is Dictionary):
			continue
		var resolved_session_id := str((entry as Dictionary).get("session_id", "")).strip_edges()
		if resolved_session_id.is_empty() or player_session_ids.has(resolved_session_id):
			continue
		player_session_ids.append(resolved_session_id)
		decks_by_session[resolved_session_id] = {
			"deck_name": str((entry as Dictionary).get("deck_name", "")),
			"cards": (entry as Dictionary).get("cards", {}),
			"reinforcements": (entry as Dictionary).get("reinforcements", {}),
			"special_setup": (entry as Dictionary).get("special_setup", {}),
		}
		identity_by_session[resolved_session_id] = (entry as Dictionary).get("identity", {})
		var token := str((entry as Dictionary).get("match_token", "")).strip_edges()
		if not token.is_empty():
			tokens_by_session[resolved_session_id] = token
	var session := MatchSession.new(
		match_id,
		room_id,
		str(match_info.get("server_ip", "127.0.0.1")),
		int(match_info.get("match_port", 12345)),
		player_session_ids,
		decks_by_session,
		identity_by_session
	)
	session.status = str(match_info.get("status", STATUS_ACTIVE))
	session.server_mode = str(match_info.get("server_mode", SERVER_MODE_IN_PROCESS_HOST))
	session.is_ranked = bool(match_info.get("is_ranked", true))
	session.host_session_id = str(match_info.get("host_session_id", "")).strip_edges()
	session.host_reachable_ip = str(match_info.get("host_reachable_ip", "")).strip_edges()
	session.host_reachable_port = int(match_info.get("host_reachable_port", 0))
	session.host_bind_port = int(match_info.get("host_bind_port", int(match_info.get("match_port", 12345))))
	for resolved_session_id in tokens_by_session.keys():
		session.player_match_tokens[resolved_session_id] = tokens_by_session[resolved_session_id]
	session._ensure_player_match_tokens()
	session._ensure_series_state()
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

func _ensure_series_state() -> void:
	configure_series_format(series_best_of)
	if registered_player_decks_by_session.is_empty():
		registered_player_decks_by_session = player_decks_by_session.duplicate(true)
	for session_id in player_session_ids:
		if not series_wins_by_session.has(session_id):
			series_wins_by_session[session_id] = 0

func _generate_token(length: int) -> String:
	const CHARS := "ABCDEFGHJKLMNPQRSTUVWXYZ23456789"
	var crypto := Crypto.new()
	var random_bytes := crypto.generate_random_bytes(length)
	if random_bytes.size() != length:
		return ""
	var output := ""
	for random_byte in random_bytes:
		output += CHARS[int(random_byte) % CHARS.length()]
	return output

func _refresh_reconnect_deadline() -> void:
	reconnect_deadline_unix = 0
	for session_id in disconnected_sessions.keys():
		var session_deadline := int(disconnected_sessions[session_id])
		if reconnect_deadline_unix == 0 or session_deadline < reconnect_deadline_unix:
			reconnect_deadline_unix = session_deadline
