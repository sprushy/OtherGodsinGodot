extends Node
class_name LobbyServer

const LobbyProtocolScript = preload("res://scripts/network/LobbyProtocol.gd")
const AppReleaseInfoScript = preload("res://scripts/client/AppReleaseInfo.gd")
const LobbyRoomScript = preload("res://scripts/server/LobbyRoom.gd")
const MatchSupervisorScript = preload("res://scripts/server/MatchSupervisor.gd")
const MatchSessionScript = preload("res://scripts/server/MatchSession.gd")
const NetworkManagerScript = preload("res://scripts/Other/NetworkManager.gd")
const PunchReflectorScript = preload("res://scripts/network/PunchReflector.gd")
const WebSocketEndpointsScript = preload("res://scripts/network/WebSocketEndpoints.gd")
const ProfileStoreScript = preload("res://scripts/server/ProfileStore.gd")
const AccountStoreScript = preload("res://scripts/server/AccountStore.gd")
const PasswordRecoveryMailerScript = preload("res://scripts/server/PasswordRecoveryMailer.gd")
const DeckStoreScript = preload("res://scripts/server/DeckStore.gd")
const FriendStoreScript = preload("res://scripts/server/FriendStore.gd")
const DeckValidatorScript = preload("res://scripts/server/DeckValidator.gd")
const MatchHistoryStoreScript = preload("res://scripts/server/MatchHistoryStore.gd")
const PracticeAutofillDeckFactoryScript = preload("res://scripts/server/PracticeAutofillDeckFactory.gd")
const RankedBotDeckPoolScript = preload("res://scripts/server/RankedBotDeckPool.gd")
const RankedProgressionScript = preload("res://scripts/server/RankedProgression.gd")
const RankBadgeCatalog = preload("res://scripts/core/RankBadgeCatalog.gd")
const JsonStoreScript = preload("res://scripts/server/JsonStore.gd")
const ServerPathsScript = preload("res://scripts/server/ServerPaths.gd")
const LOBBY_EVENT_TYPE := "__lobby_event__"
const SEEK_TIMEOUT_SECONDS := 30 * 60
const SEEK_TIMEOUT_CHECK_INTERVAL_SECONDS := 5.0
const ROOM_MEMBER_RECONNECT_GRACE_SECONDS := 5 * 60
const DEDICATED_MATCH_ASSIGNMENT_POLL_SECONDS := 0.25
const DEDICATED_MATCH_ASSIGNMENT_TIMEOUT_SECONDS := 90.0
const BOT_SESSION_PREFIX := "BOT_"
const SERVER_BOT_AUTH_MODE := "bot"
const SERVER_BOT_TYPE_FUZZ := "practice_fuzz"
const ADMIN_USERNAMES_ENV := "OTHERGODS_ADMIN_USERNAMES"
const MAX_BOT_SELF_PLAY := 10
const MAX_CLIENT_BOT_WORKERS_PER_ACCOUNT := 6
const LEAGUE_ROUND_ROBIN_DEFAULT_MATCHES_PER_BOT := 50
# Debug-only rubric evaluation: a batch of freshly built bots plays until each
# has this many games, then the lobby builds fresh bots from the same rules.
const NEW_BOT_BATCH_GAME_LIMIT := 20
const NEW_BOT_BATCH_SIZE := 8
const BOT_SELF_PLAY_LIMIT_ENV := "OTHERGODS_BOT_SELF_PLAY_LIMIT"
const BOT_SELF_PLAY_FRAME_LIMIT := 0.055
const BOT_SELF_PLAY_MEMORY_RESERVE := 512 * 1024 * 1024
const BOT_SELF_PLAY_MEMORY_PER_WORKER := 256 * 1024 * 1024
const BOT_SELF_PLAY_RETRY_SECONDS := 30
## Idle-worker ceiling regardless of the configured bot_self_play_limit; each
## worker simulates on the lobby's single main thread, so this stays small.
const BOT_SELF_PLAY_MAX_IDLE_WORKERS := 2
const BOT_SELF_PLAY_BLOCK_LOG_INTERVAL_SECONDS := 60.0
## Server-bot challenge matches run in the challenger's own client (like the
## volunteer bot workers); the lobby only brokers the pairing and records the
## reported result. This bounds how long an unreported match may hold its room.
const LOCAL_BOT_MATCH_RESULT_TIMEOUT_SECONDS := 3 * 60 * 60
const LOCAL_BOT_MATCH_RESULT_RELAY_GRACE_SECONDS := 5.0
## How long the lobby waits for a client-hosted match's host to acknowledge a
## spectator approval before telling the spectator the match is not watchable.
# A client host can receive the approval before its match session exists and
# queue token registration until launch. Five seconds was too short for that
# handoff and caused spectators to be rejected after the host was ready.
const MATCH_SPECTATOR_ACK_TIMEOUT_SECONDS := 20.0
# Hole punching: a single reflector socket next to the lobby keeps zero-session
# UDP bounce records; the fallback port scan covers crowded deployments.
const PUNCH_REFLECTOR_PORT_ATTEMPTS := 10
const PUNCH_DISCOVERY_BOUNCE_TTL_SECONDS := 30.0
const PUNCH_CLIENT_BOUNCE_TTL_SECONDS := 20.0
const LOCAL_BOT_MATCH_PUNCH_RELAY_INTERVAL_MSEC := 1000
const ISSUE_REPORT_COOLDOWN_SECONDS := 60
const BOT_PROPOSAL_COOLDOWN_SECONDS := 60
const ALLOW_INSECURE_ACCOUNT_AUTH_ENV := "OTHERGODS_ALLOW_INSECURE_ACCOUNT_AUTH"
const ALLOW_INSECURE_ACCOUNT_AUTH_SETTING := "application/config/allow_insecure_account_auth"

signal local_room_snapshot_updated(snapshot: Dictionary)
signal room_list_updated(rooms: Array)
signal local_match_assigned(match_info: Dictionary)
signal status_changed(message: String)

var advertised_host: String = "127.0.0.1"
var lobby_port: int = LobbyProtocolScript.PORT
var match_port: int = LobbyProtocolScript.MATCH_PORT
var ws_port: int = 0
var is_listening: bool = false
var use_dedicated_match_processes: bool = true
var allow_in_process_match_fallback: bool = true
var server_bots_enabled: bool = true
var server_bot_self_play_limit: int = 0
var trace_network: bool = false
var trace_file_path: String = ""
var multiplayer_mount_path: NodePath = NodePath("")
var use_default_multiplayer: bool = false
var allow_insecure_account_auth: bool = false

var sessions_by_id: Dictionary = {}
var session_id_by_peer: Dictionary = {}
var rooms_by_id: Dictionary = {}
var room_id_by_session: Dictionary = {}
var local_session_id: String = ""
var match_supervisor = null
var network_manager: Node = null
var ws_transport: Node = null
var punch_reflector: Node = null
var profile_store = null
var account_store = null
var recovery_mailer = null
var _recovery_request_times: Array[int] = []
var deck_store = null
var friend_store = null
var deck_validator = null
var match_history_store = null
var server_bot_deck_factory = null

var _seek_timeout_check_elapsed: float = 0.0
var _server_bot_seed_counter: int = 0
# Bot ladders replay separate Bo1 and Bo3 result streams so records, stars,
# quarantine, and trials stay per-format, but bot identities (decklists plus
# display names) are reconciled across both pools after every refresh, so one
# bot name always means the same deck on either ladder. `_ranked_bot_deck_pool`
# stays as the Bo1 pool name for existing callers and stored state; Bo3 uses its
# own pool, result replay, and persistence file.
var _ranked_bot_deck_pool := RankedBotDeckPoolScript.new()
var _ranked_bot_deck_pool_bo3 := RankedBotDeckPoolScript.new()
var _bot_deck_rng := RandomNumberGenerator.new()
var _lobby_frame_seconds := 0.0
var _next_bot_self_play_msec := 0
var _last_bot_self_play_block_reason := ""
var _punch_reflector_port: int = 0
var _punch_ready_last_msec_by_key: Dictionary = {}
var _next_bot_self_play_block_log_msec := 0
var _client_bot_jobs: Dictionary = {}
var _pending_league_pairings: Array = []
# Debug-only rubric batches, keyed by match format. Each value holds `serial`,
# `decks` (list id -> deck submission), and `records` (list id -> game counts).
var _new_rubric_bot_batches: Dictionary = {}
var _local_bot_matches_by_id: Dictionary = {}
var _spectator_acks_by_key: Dictionary = {}
var _issue_report_last_submit_by_peer: Dictionary = {}
var _bot_proposal_last_submit_by_account: Dictionary = {}

# Ladder cache — the full sorted ladder is expensive to rebuild on every request.
# It is rebuilt only when _ladder_cache_dirty is true, then reused for subsequent
# requests until something mutates bot standings or match history.
var _ladder_cache: Array[Dictionary] = []
var _ladder_cache_bo3: Array[Dictionary] = []
var _ladder_cache_dirty: bool = true
var _ladder_cache_bo3_dirty: bool = true
var _ladder_cache_last_build_msec: int = 0
var _ladder_cache_bo3_last_build_msec: int = 0
const LADDER_CACHE_MIN_REBUILD_INTERVAL_MSEC: int = 1500
const TOP_BOT_HOSTING_LIMIT := 50
# Recent-result notifications track bots in the top 100 and human players deeper.
const LADDER_NOTIFICATION_DEPTH := 100
const PLAYER_LADDER_NOTIFICATION_DEPTH := 200
const TOP_TEN_NOTIFICATION_DEPTH := 10

# Pool rebuild is expensive (replays all bot match results). Only rebuild when
# something has actually changed since the last refresh.
var _pool_dirty: bool = true
var _pool_state_paths: Dictionary = {}
# Per-format result buckets for the two bot pools. Maintained by appending only
# newly recorded results, so the full history is split once instead of on every
# pool refresh.
var _pool_results_by_format := {1: [] as Array[Dictionary], 3: [] as Array[Dictionary]}
var _pool_results_bucketed_count := 0
var _pool_results_boundary_id := ""
var _bot_self_play_format_index: int = 0

# Room-list broadcast throttle — limits broadcasts to at most once per second so
# rapid room churn (e.g. bot self-play cycling) does not flood every connected peer.
var _room_list_broadcast_pending: bool = false
var _room_list_broadcast_last_msec: int = 0
const _ROOM_LIST_BROADCAST_MIN_INTERVAL_MSEC: int = 1000

# Bot-history broadcast throttle. Building the history page is expensive (it can
# refresh the bot pools and rebuild the ladder), so bursts of bot-work events
# coalesce instead of each paying the full chain.
var _bot_history_broadcast_pending: bool = false
var _bot_history_broadcast_last_msec: int = 0
const _BOT_HISTORY_BROADCAST_MIN_INTERVAL_MSEC: int = 1500

# Owner-bot deck fingerprints, cached per list id and cleared whenever the bot
# pools refresh (community syncs and adoptions are the only ways deck content
# changes). Avoids re-hashing every owned bot's full deck on each ladder rebuild.
var _bot_deck_fingerprints_by_list_id: Dictionary = {}

# Slow-path diagnostics: expensive rebuilds log (rate-limited) only when they
# exceed this budget, so healthy servers stay silent in the log.
const _SLOW_PATH_LOG_THRESHOLD_MSEC: int = 25
const _SLOW_PATH_LOG_INTERVAL_MSEC: int = 60000

func _invalidate_ladder_cache() -> void:
	_ladder_cache_dirty = true
	_ladder_cache_bo3_dirty = true
	_pool_dirty = true

func _clear_ladder_caches() -> void:
	_ladder_cache.clear()
	_ladder_cache_bo3.clear()
	_invalidate_ladder_cache()

func _bot_pool(best_of: int) -> RankedBotDeckPoolScript:
	return _ranked_bot_deck_pool_bo3 if int(best_of) == 3 else _ranked_bot_deck_pool

func _bot_pool_state_path(best_of: int) -> String:
	return "bot_pool_state_bo3.json" if int(best_of) == 3 else "bot_pool_state.json"

static func get_dedicated_bot_self_play_limit(launch_args: Dictionary) -> int:
	var default_limit := MAX_BOT_SELF_PLAY
	if OS.has_environment(BOT_SELF_PLAY_LIMIT_ENV):
		default_limit = int(OS.get_environment(BOT_SELF_PLAY_LIMIT_ENV))
	return clampi(int(launch_args.get("bot_self_play_limit", default_limit)), 0, MAX_BOT_SELF_PLAY)

func _ready() -> void:
	_bot_deck_rng.randomize()
	allow_insecure_account_auth = _runtime_allows_insecure_account_auth()
	_ensure_profile_store()
	_ensure_account_store()
	_ensure_deck_store()
	_ensure_friend_store()
	_ensure_deck_validator()
	_ensure_match_history_store()
	_ensure_server_bot_deck_factory()
	_ensure_match_supervisor()
	_ensure_network_manager()

func _process(delta: float) -> void:
	if not is_listening:
		_seek_timeout_check_elapsed = 0.0
		return
	_lobby_frame_seconds = lerpf(_lobby_frame_seconds, delta, 0.08)
	_seek_timeout_check_elapsed += delta
	if _seek_timeout_check_elapsed < SEEK_TIMEOUT_CHECK_INTERVAL_SECONDS:
		return
	_seek_timeout_check_elapsed = 0.0
	_expire_stale_seeks()
	_expire_client_bot_jobs()
	_expire_disconnected_room_members()
	_expire_abandoned_player_host_matches()
	_expire_stale_local_bot_matches()
	_ensure_server_bot_seeks()
	_maintain_bot_self_play()

func start_server(p_advertised_host: String = "127.0.0.1", port: int = LobbyProtocolScript.PORT, p_match_port: int = LobbyProtocolScript.MATCH_PORT, p_ws_port: int = LobbyProtocolScript.WS_PORT) -> Error:
	if is_listening:
		return OK
	var public_ws_url := WebSocketEndpointsScript.public_base_url()
	if not public_ws_url.is_empty() and (not WebSocketEndpointsScript.is_valid_base_url(public_ws_url) or p_ws_port <= 0):
		status_changed.emit("Public WebSocket URL must be a wss:// origin with an enabled backend listener.")
		return ERR_INVALID_PARAMETER
	allow_insecure_account_auth = _runtime_allows_insecure_account_auth()

	advertised_host = p_advertised_host.strip_edges()
	if advertised_host.is_empty():
		advertised_host = "127.0.0.1"

	lobby_port = port
	match_port = p_match_port
	_ensure_match_supervisor()
	if match_supervisor != null:
		match_supervisor.public_websocket_url = public_ws_url
		match_supervisor.configure(
			advertised_host,
			match_port,
			use_dedicated_match_processes,
			"",
			"",
			allow_in_process_match_fallback
		)

	_ensure_network_manager()
	if network_manager == null:
		status_changed.emit("Failed to initialize lobby network transport.")
		return ERR_UNAVAILABLE

	var err: Error = network_manager.create_server(lobby_port, false)
	if err != OK:
		status_changed.emit("Failed to start lobby server on port %d." % lobby_port)
		return err

	ws_port = max(0, p_ws_port)
	if ws_port > 0:
		var ws_err := _start_websocket_transport(ws_port)
		if ws_err != OK and not public_ws_url.is_empty():
			stop_server()
			return ws_err

	is_listening = true
	_start_punch_reflector()
	_trace("listening on %s:%d" % [advertised_host, lobby_port])
	status_changed.emit("Lobby server listening on %s:%d" % [advertised_host, lobby_port])
	_ensure_server_bot_seeks()
	return OK

## UDP bounce endpoint for NAT hole punching. Failure never blocks the lobby:
## clients without it simply stay on the UPnP/LAN spectate paths.
func _start_punch_reflector() -> void:
	if punch_reflector != null:
		return
	var candidate := PunchReflectorScript.new()
	candidate.name = "PunchReflector"
	add_child(candidate)
	var base_port := int(LobbyProtocolScript.PUNCH_REFLECTOR_PORT)
	for attempt in PUNCH_REFLECTOR_PORT_ATTEMPTS:
		var port := base_port + attempt
		if candidate.setup(port):
			punch_reflector = candidate
			_punch_reflector_port = port
			_trace("punch reflector listening on port %d" % port)
			return
	candidate.queue_free()
	status_changed.emit("Punch reflector could not bind port %d..%d; spectating falls back to UPnP and LAN only." % [
		base_port, base_port + PUNCH_REFLECTOR_PORT_ATTEMPTS - 1
	])

## Secondary transport for restrictive networks: WebSocket over TCP, so clients
## behind firewalls that drop UDP can still reach the lobby. Runs as a second
## NetworkManager instance whose peer ids are namespaced before they reach the
## shared lobby logic; a ws bind failure never blocks the ENet lobby.
func _start_websocket_transport(p_ws_port: int) -> Error:
	if ws_transport != null:
		return OK
	var ws_network_manager: Node = NetworkManagerScript.new()
	ws_network_manager.name = "LobbyTransportWS"
	ws_network_manager.trace_file_path = trace_file_path
	ws_network_manager.use_current_scene_relative_path = true
	ws_network_manager.validate_match_command_types = false
	ws_network_manager.set("is_websocket_transport", true)
	add_child(ws_network_manager)
	var ws_err: Error = ws_network_manager.create_server_websocket(p_ws_port)
	if ws_err != OK:
		status_changed.emit("Lobby WebSocket fallback unavailable on port %d." % p_ws_port)
		ws_network_manager.queue_free()
		return ws_err
	ws_transport = ws_network_manager
	network_manager.set("websocket_transport", ws_transport)
	if not ws_transport.command_received.is_connected(_on_network_command_received):
		ws_transport.command_received.connect(_on_network_command_received)
	if not ws_transport.peer_disconnected.is_connected(_on_peer_disconnected):
		ws_transport.peer_disconnected.connect(_on_peer_disconnected)
	status_changed.emit("Lobby WebSocket fallback listening on %s:%d" % [advertised_host, p_ws_port])
	return OK

func stop_server() -> void:
	if ws_transport != null:
		ws_transport.disconnect_client()
		ws_transport.queue_free()
		ws_transport = null
	if punch_reflector != null:
		punch_reflector.shutdown()
		punch_reflector.queue_free()
		punch_reflector = null
	_punch_reflector_port = 0
	_punch_ready_last_msec_by_key.clear()
	if network_manager != null:
		network_manager.set("websocket_transport", null)
		network_manager.disconnect_client()
	is_listening = false
	advertised_host = "127.0.0.1"
	lobby_port = LobbyProtocolScript.PORT
	match_port = LobbyProtocolScript.MATCH_PORT
	ws_port = 0
	_seek_timeout_check_elapsed = 0.0
	_lobby_frame_seconds = 0.0
	_next_bot_self_play_msec = 0
	sessions_by_id.clear()
	session_id_by_peer.clear()
	rooms_by_id.clear()
	room_id_by_session.clear()
	local_session_id = ""
	if match_supervisor != null:
		match_supervisor.clear()

func create_local_guest_session(player_name: String = "Host") -> Dictionary:
	var existing: Dictionary = _get_local_session()
	if not existing.is_empty():
		return existing.duplicate(true)

	_ensure_profile_store()
	var profile := {}
	if profile_store != null:
		profile = profile_store.login_profile("", player_name)
	var session: Dictionary = _create_session(
		player_name,
		1,
		true,
		str(profile.get("profile_id", ""))
	)
	local_session_id = str(session.get("session_id", ""))
	return session.duplicate(true)

func create_room_for_local_session(is_ranked: bool = true, best_of: int = 1) -> Dictionary:
	if local_session_id.is_empty():
		return {}
	var room: LobbyRoom = _create_room_for_session(local_session_id, is_ranked, best_of)
	return room.to_snapshot(sessions_by_id)

func set_local_ready(is_ready: bool) -> void:
	if local_session_id.is_empty():
		return
	_set_ready_for_session(local_session_id, is_ready)

func get_local_room_snapshot() -> Dictionary:
	var room_id: String = str(room_id_by_session.get(local_session_id, ""))
	if room_id.is_empty() or not rooms_by_id.has(room_id):
		return {}
	var room: LobbyRoom = rooms_by_id[room_id]
	return room.to_snapshot(sessions_by_id)

func get_match_session(match_id: String):
	if match_supervisor == null:
		return null
	return match_supervisor.get_match(match_id)

func _handle_request(peer_id: int, message: Dictionary) -> void:
	var validation_error: String = LobbyProtocolScript.validate_request(message)
	if not validation_error.is_empty():
		_send_error_to_peer(peer_id, validation_error)
		return

	_expire_stale_seeks()

	var message_type: String = LobbyProtocolScript.get_type(message)
	var payload: Dictionary = LobbyProtocolScript.get_payload(message)

	match message_type:
		LobbyProtocolScript.REQUEST_PASSWORD_RESET:
			_handle_password_recovery(peer_id, payload, false)
		LobbyProtocolScript.RESET_PASSWORD:
			_handle_password_recovery(peer_id, payload, true)
		LobbyProtocolScript.LOGIN_GUEST:
			_send_error_to_peer(peer_id, "Guest sign-in is no longer supported.")
		LobbyProtocolScript.LOGIN_ACCOUNT:
			_handle_login_account(peer_id, payload)
		LobbyProtocolScript.REGISTER_ACCOUNT:
			_handle_register_account(peer_id, payload)
		LobbyProtocolScript.CLAIM_LEGACY_ACCOUNT:
			_handle_claim_legacy_account(peer_id, payload)
		LobbyProtocolScript.UPDATE_ACCOUNT_SETTINGS:
			_handle_update_account_settings(peer_id, payload)
		LobbyProtocolScript.CREATE_ROOM:
			var session: Dictionary = _get_session_for_peer(peer_id)
			if session.is_empty():
				_send_error_to_peer(peer_id, "Join the lobby before creating a room.")
				return
			var room: LobbyRoom = _create_room_for_session(
				str(session.get("session_id", "")),
				_payload_is_ranked(payload),
				_payload_best_of(payload)
			)
			_broadcast_room_snapshot(room)
		LobbyProtocolScript.LIST_ROOMS:
			_send_room_list_to_peer(peer_id)
		LobbyProtocolScript.JOIN_ROOM:
			var join_session: Dictionary = _get_session_for_peer(peer_id)
			if join_session.is_empty():
				_send_error_to_peer(peer_id, "Join the lobby before entering a room.")
				return
			_join_room_for_session(str(join_session.get("session_id", "")), str(payload.get("room_id", "")))
		LobbyProtocolScript.REJOIN_ROOM:
			var rejoin_session: Dictionary = _get_session_for_peer(peer_id)
			if rejoin_session.is_empty():
				_send_error_to_peer(peer_id, "Join the lobby before rejoining a match.")
				return
			_rejoin_room_for_session(str(rejoin_session.get("session_id", "")), str(payload.get("room_id", "")))
		LobbyProtocolScript.OBSERVE_ROOM:
			var observe_session: Dictionary = _get_session_for_peer(peer_id)
			if observe_session.is_empty():
				_send_error_to_peer(peer_id, LobbyProtocolScript.OBSERVE_ROOM_AUTH_ERROR)
				return
			_observe_room_for_session(str(observe_session.get("session_id", "")), str(payload.get("room_id", "")))
		LobbyProtocolScript.REQUEST_NEXT:
			_handle_request_next(peer_id, str(payload["match_id"]).strip_edges())
		LobbyProtocolScript.LEAVE_ROOM:
			var leave_session: Dictionary = _get_session_for_peer(peer_id)
			if leave_session.is_empty():
				return
			_leave_room_for_session(str(leave_session.get("session_id", "")))
		LobbyProtocolScript.SELECT_DECK:
			var deck_session: Dictionary = _get_session_for_peer(peer_id)
			if deck_session.is_empty():
				_send_error_to_peer(peer_id, "Join the lobby before selecting a deck.")
				return
			_submit_deck_for_session(
				str(deck_session.get("session_id", "")),
				str(payload.get("deck_name", "")),
				str(payload.get("deck_id", "")),
				payload.get("cards", {}),
				payload.get("special_setup", {}),
				payload.get("reinforcements", {}),
				bool(payload.get("is_purpose_deck", false))
			)
		LobbyProtocolScript.REQUEST_ACCOUNT_DECKS:
			_handle_request_account_decks(peer_id)
		LobbyProtocolScript.SAVE_ACCOUNT_DECK:
			_handle_save_account_deck(peer_id, payload)
		LobbyProtocolScript.DELETE_ACCOUNT_DECK:
			_handle_delete_account_deck(peer_id, payload)
		LobbyProtocolScript.SET_ACCOUNT_PREFERRED_DECK:
			_handle_set_account_preferred_deck(peer_id, payload)
		LobbyProtocolScript.SET_OBSERVER_FRIEND_CARD_VISIBILITY:
			_handle_set_observer_friend_card_visibility(peer_id, payload)
		LobbyProtocolScript.REQUEST_PROFILE_SUMMARY:
			_handle_request_profile_summary(peer_id)
		LobbyProtocolScript.SET_RANK_BADGE:
			_handle_set_rank_badge(peer_id, payload)
		LobbyProtocolScript.REQUEST_BOT_LADDER, LobbyProtocolScript.REQUEST_BOT_DECK, LobbyProtocolScript.REQUEST_BOT_RECORD:
			_handle_request_bot_ladder(peer_id, message_type, payload)
		LobbyProtocolScript.REQUEST_BOT_MATCH_HISTORY:
			if not _get_session_for_peer(peer_id).is_empty():
				var cursor: String = payload.get("before_match_id", "")
				var page: Dictionary = match_history_store.get_recent_bot_matches(50, cursor)
				page["before_match_id"] = cursor
				page["live_matches"] = _get_live_bot_work_matches()
				page["activities"] = _get_recent_match_activity_notifications()
				_send_to_peer(peer_id, LobbyProtocolScript.BOT_MATCH_HISTORY, page)
		LobbyProtocolScript.REQUEST_BOT_WORK:
			_handle_request_bot_work(peer_id, payload)
		LobbyProtocolScript.SEED_BOT_LEAGUE:
			_handle_seed_bot_league(peer_id, payload)
		LobbyProtocolScript.FINALIZE_BOT_LEAGUE:
			_handle_finalize_bot_league(peer_id, payload)
		LobbyProtocolScript.REQUEST_BOT_LEAGUE_STATUS:
			_handle_request_bot_league_status(peer_id, payload)
		LobbyProtocolScript.RUN_LEAGUE_ROUND_ROBIN:
			_handle_run_league_round_robin(peer_id, payload)
		LobbyProtocolScript.CLEAR_LEAGUE_BOTS:
			_handle_clear_league_bots(peer_id, payload)
		LobbyProtocolScript.REBUILD_LEAGUE_RECORDS:
			_handle_rebuild_league_records(peer_id, payload)
		LobbyProtocolScript.DUMP_BOT_DECK_RESULTS:
			_handle_dump_bot_deck_results(peer_id, payload)
		LobbyProtocolScript.SUBMIT_ISSUE_REPORT:
			_handle_submit_issue_report(peer_id, payload)
		LobbyProtocolScript.SUBMIT_BOT_PROPOSAL:
			_handle_submit_bot_proposal(peer_id, payload)
		LobbyProtocolScript.SUBMIT_BOT_DECK:
			_handle_submit_bot_deck(peer_id, payload)
		LobbyProtocolScript.REQUEST_MY_BOTS:
			_handle_request_my_bots(peer_id)
		LobbyProtocolScript.DELETE_BOT:
			_handle_delete_bot(peer_id, payload)
		LobbyProtocolScript.QUARANTINE_BOT:
			_handle_quarantine_bot(peer_id, payload)
		LobbyProtocolScript.REPORT_BOT_WORK_STARTED:
			_handle_report_bot_work_started(peer_id, payload)
		LobbyProtocolScript.CANCEL_BOT_WORK:
			_handle_cancel_bot_work(peer_id, payload)
		LobbyProtocolScript.SUBMIT_BOT_WORK_RESULT:
			_handle_submit_bot_work_result(peer_id, payload)
		LobbyProtocolScript.REQUEST_FRIENDS:
			_handle_request_friends(peer_id)
		LobbyProtocolScript.SEND_FRIEND_REQUEST:
			_handle_send_friend_request(peer_id, payload)
		LobbyProtocolScript.RESPOND_FRIEND_REQUEST:
			_handle_respond_friend_request(peer_id, payload)
		LobbyProtocolScript.SEND_DECK_TO_FRIEND:
			_handle_send_deck_to_friend(peer_id, payload)
		LobbyProtocolScript.RESPOND_DECK_SHARE:
			_handle_respond_deck_share(peer_id, payload)
		LobbyProtocolScript.SET_READY:
			var ready_session: Dictionary = _get_session_for_peer(peer_id)
			if ready_session.is_empty():
				_send_error_to_peer(peer_id, "Join a room before changing ready state.")
				return
			_set_ready_for_session(str(ready_session.get("session_id", "")), bool(payload.get("is_ready", false)))
		LobbyProtocolScript.LOCAL_BOT_MATCH_RESULT:
			_handle_local_bot_match_result(peer_id, payload)
		LobbyProtocolScript.LOCAL_BOT_MATCH_SPECTATE_INFO:
			_handle_local_bot_match_spectate_info(peer_id, payload)
		LobbyProtocolScript.MATCH_SPECTATOR_ACK:
			_handle_match_spectator_ack(peer_id, payload)
		LobbyProtocolScript.LOCAL_BOT_MATCH_PUNCH_READY:
			_handle_local_bot_match_punch_ready(peer_id, payload)
		LobbyProtocolScript.REQUEST_RECONNECT_LOBBY:
			_handle_reconnect_request(peer_id, payload)
		LobbyProtocolScript.REPORT_HOST_VIABILITY:
			_handle_report_host_viability(peer_id, payload)
		LobbyProtocolScript.REQUEST_PLAYERS_ONLINE:
			_handle_request_players_online(peer_id)

func _can_accept_password_recovery(peer_id: int) -> bool:
	if peer_id == 1:
		return true
	if ws_transport != null and peer_id >= NetworkManagerScript.WS_PEER_ID_BASE:
		return WebSocketEndpointsScript.public_base_url().begins_with("wss://")
	if network_manager != null and network_manager.peer is ENetMultiplayerPeer:
		var packet_peer: ENetPacketPeer = network_manager.peer.get_peer(peer_id)
		if packet_peer != null:
			var address := packet_peer.get_remote_address()
			return address.begins_with("127.") or address == "::1"
	return false

func _handle_password_recovery(peer_id: int, payload: Dictionary, completing: bool) -> void:
	if not _can_accept_password_recovery(peer_id):
		_send_error_to_peer(peer_id, "Password recovery requires a secure WSS lobby connection.")
		return
	# A bounded server-wide budget also covers unknown emails and fresh peers.
	var now := int(Time.get_unix_time_from_system())
	while not _recovery_request_times.is_empty() and _recovery_request_times[0] <= now - 60:
		_recovery_request_times.pop_front()
	if _recovery_request_times.size() >= 30:
		_send_error_to_peer(peer_id, "Too many recovery attempts. Please try again in a minute.")
		return
	_recovery_request_times.append(now)
	_ensure_account_store()
	if completing:
		var result: Dictionary = account_store.reset_password(
			str(payload.get("email", "")), str(payload.get("token", "")), str(payload.get("new_password", "")))
		if bool(result.get("success", false)):
			_revoke_recovered_account_sessions(str(result.get("account", {}).get("account_id", "")))
		_send_to_peer(peer_id, LobbyProtocolScript.PASSWORD_RESET_RESULT, {
			"completed": true, "success": bool(result.get("success", false)), "message": str(result.get("message", "")),
		})
		return
	if recovery_mailer == null:
		recovery_mailer = PasswordRecoveryMailerScript.new()
		add_child(recovery_mailer)
	if not recovery_mailer.is_configured():
		_send_error_to_peer(peer_id, "Email recovery is not configured on this server. Contact the server administrator.")
		return
	var email := str(payload.get("email", "")).strip_edges().to_lower()
	if email.length() > 254 or account_store._validate_email(email) != "":
		_send_error_to_peer(peer_id, "Enter a valid account email address.")
		return
	var recovery: Dictionary = account_store.create_password_reset(email)
	if not recovery.is_empty():
		var account_id := str(recovery.get("account_id", ""))
		var token := str(recovery.get("token", ""))
		var queued: bool = recovery_mailer.send_recovery_email(str(recovery.get("email", "")), token, func(sent: bool) -> void:
			if not sent:
				account_store.cancel_password_reset(account_id, token)
		)
		if not queued:
			account_store.cancel_password_reset(account_id, token)
			push_warning("Password recovery email could not be queued.")
	# Respond immediately and identically regardless of account existence or delivery.
	_send_to_peer(peer_id, LobbyProtocolScript.PASSWORD_RESET_RESULT, {
		"completed": false, "success": true,
		"message": "If this email belongs to an account, a recovery code will arrive shortly. Check your spam folder. Codes expire after 15 minutes. You can request another email after one minute.",
	})

func _revoke_recovered_account_sessions(account_id: String) -> void:
	for session_id in sessions_by_id.keys():
		var session: Dictionary = sessions_by_id[session_id]
		if str(session.get("account_id", "")) != account_id:
			continue
		# Retain match bookkeeping, but invalidate reconnect and command access.
		session["reconnect_token"] = ""
		var peer_id := int(session.get("peer_id", 0))
		if peer_id > 0:
			_send_error_to_peer(peer_id, "Your password was reset. Sign in again.")
			_on_peer_disconnected(peer_id)
		session["connected"] = false
		session["peer_id"] = 0
		sessions_by_id[session_id] = session

func _handle_login_guest(peer_id: int, payload: Dictionary) -> void:
	var requested_player_name := str(payload.get("player_name", "Guest"))
	var requested_profile_id := str(payload.get("profile_id", "")).strip_edges()
	_ensure_profile_store()
	var profile := {}
	if profile_store != null:
		profile = profile_store.login_profile(requested_profile_id, requested_player_name)
	_complete_login_for_peer(
		peer_id,
		str(profile.get("display_name", requested_player_name)),
		str(profile.get("profile_id", requested_profile_id)),
		"",
		"",
		"",
		LobbyProtocolScript.LOGIN_GUEST
	)

func _handle_register_account(peer_id: int, payload: Dictionary) -> void:
	if not _can_accept_password_account_auth(peer_id):
		_send_error_to_peer(peer_id, _insecure_account_auth_message())
		return
	_ensure_account_store()
	_ensure_profile_store()
	if account_store == null or profile_store == null:
		_send_error_to_peer(peer_id, "Account storage is unavailable.")
		return
	var requested_email := str(payload.get("email", payload.get("username", "")))
	var requested_username := str(payload.get("username", ""))
	var requested_password := str(payload.get("password", ""))
	var accepts_game_updates := bool(payload.get("accepts_game_updates", false))
	var account_result: Dictionary = account_store.register_account(
		requested_email,
		requested_password,
		requested_username,
		accepts_game_updates
	)
	if not bool(account_result.get("success", false)):
		_send_error_to_peer(peer_id, str(account_result.get("message", "Could not create account.")))
		return
	var account: Dictionary = account_result.get("account", {})
	var account_username := str(account.get("username", requested_username)).strip_edges()
	if account_username.is_empty():
		account_username = str(account.get("email", requested_email)).strip_edges()
	var profile: Dictionary = profile_store.login_profile(
		"",
		account_username,
		str(account.get("account_id", "")),
		account_username
	)
	_complete_login_for_peer(
		peer_id,
		str(profile.get("display_name", account_username)),
		str(profile.get("profile_id", "")),
		str(account.get("account_id", "")),
		str(account.get("email", requested_email)),
		account_username,
		LobbyProtocolScript.REGISTER_ACCOUNT,
		bool(account.get("accepts_game_updates", accepts_game_updates))
	)

func _handle_claim_legacy_account(peer_id: int, payload: Dictionary) -> void:
	if not _can_accept_password_account_auth(peer_id):
		_send_error_to_peer(peer_id, _insecure_account_auth_message())
		return
	_ensure_account_store()
	_ensure_profile_store()
	if account_store == null or profile_store == null:
		_send_error_to_peer(peer_id, "Account storage is unavailable.")
		return
	var requested_username := str(payload.get("username", ""))
	var requested_email := str(payload.get("email", ""))
	var requested_password := str(payload.get("password", ""))
	var accepts_game_updates := bool(payload.get("accepts_game_updates", false))
	var account_result: Dictionary = account_store.claim_legacy_account(
		requested_username,
		requested_password,
		requested_email,
		accepts_game_updates
	)
	if not bool(account_result.get("success", false)):
		_send_error_to_peer(peer_id, str(account_result.get("message", "Could not update that account.")))
		return
	var account: Dictionary = account_result.get("account", {})
	var account_id := str(account.get("account_id", "")).strip_edges()
	var merged_account_id := str(account_result.get("merged_account_id", "")).strip_edges()
	if not merged_account_id.is_empty() and not account_id.is_empty() and merged_account_id != account_id:
		_merge_account_server_state(merged_account_id, account_id)
	var account_username := str(account.get("username", requested_username)).strip_edges()
	var profile: Dictionary = profile_store.login_profile(
		"",
		account_username,
		account_id,
		account_username
	)
	_complete_login_for_peer(
		peer_id,
		str(profile.get("display_name", account_username)),
		str(profile.get("profile_id", "")),
		account_id,
		str(account.get("email", requested_email)),
		account_username,
		LobbyProtocolScript.CLAIM_LEGACY_ACCOUNT,
		bool(account.get("accepts_game_updates", accepts_game_updates))
	)

func _handle_login_account(peer_id: int, payload: Dictionary) -> void:
	if not _can_accept_password_account_auth(peer_id):
		_send_error_to_peer(peer_id, _insecure_account_auth_message())
		return
	_ensure_account_store()
	_ensure_profile_store()
	if account_store == null or profile_store == null:
		_send_error_to_peer(peer_id, "Account storage is unavailable.")
		return
	var requested_email := str(payload.get("email", payload.get("username", "")))
	var requested_password := str(payload.get("password", ""))
	var account_result: Dictionary = account_store.login_account(requested_email, requested_password)
	if not bool(account_result.get("success", false)):
		_send_error_to_peer(peer_id, str(account_result.get("message", "Could not log in.")))
		return
	var account: Dictionary = account_result.get("account", {})
	var account_username := str(account.get("username", "")).strip_edges()
	if account_username.is_empty():
		account_username = str(account.get("email", requested_email)).strip_edges()
	var profile: Dictionary = profile_store.login_profile(
		"",
		account_username,
		str(account.get("account_id", "")),
		account_username
	)
	_complete_login_for_peer(
		peer_id,
		str(profile.get("display_name", account_username)),
		str(profile.get("profile_id", "")),
		str(account.get("account_id", "")),
		str(account.get("email", requested_email)),
		account_username,
		LobbyProtocolScript.LOGIN_ACCOUNT,
		bool(account.get("accepts_game_updates", false))
	)

func _handle_update_account_settings(peer_id: int, payload: Dictionary) -> void:
	var session: Dictionary = _get_session_for_peer(peer_id)
	if session.is_empty():
		_send_error_to_peer(peer_id, "Join the lobby before changing account settings.")
		return
	var account_id := str(session.get("account_id", "")).strip_edges()
	if account_id.is_empty():
		_send_error_to_peer(peer_id, "Log into an account before changing account settings.")
		return
	var sends_password_material := not str(payload.get("current_password", "")).is_empty() \
		or not str(payload.get("new_password", "")).is_empty() \
		or not str(payload.get("new_email", "")).strip_edges().is_empty()
	if sends_password_material and not _can_accept_password_account_auth(peer_id):
		_send_error_to_peer(peer_id, _insecure_account_auth_message())
		return
	_ensure_account_store()
	if account_store == null:
		_send_error_to_peer(peer_id, "Account storage is unavailable.")
		return
	var update_result: Dictionary = account_store.update_account_settings(
		account_id,
		str(payload.get("current_password", "")),
		str(payload.get("new_email", "")),
		str(payload.get("new_password", "")),
		bool(payload.get("accepts_game_updates", false)),
		payload.has("accepts_game_updates")
	)
	if not bool(update_result.get("success", false)):
		_send_error_to_peer(peer_id, str(update_result.get("message", "Could not update account settings.")))
		return
	var account: Dictionary = update_result.get("account", {})
	session["email"] = str(account.get("email", session.get("email", "")))
	session["username"] = str(account.get("username", session.get("username", "")))
	session["accepts_game_updates"] = bool(account.get("accepts_game_updates", false))
	sessions_by_id[str(session.get("session_id", ""))] = session
	_send_to_peer(peer_id, LobbyProtocolScript.ACCOUNT_SETTINGS_UPDATED, {
		"account": account,
	})

func _can_accept_password_account_auth(peer_id: int) -> bool:
	if peer_id == 1:
		return true
	# The WebSocket backend is loopback-only and reached through the TLS proxy.
	if ws_transport != null and peer_id >= NetworkManagerScript.WS_PEER_ID_BASE \
			and WebSocketEndpointsScript.public_base_url().begins_with("wss://"):
		return true
	return allow_insecure_account_auth

func _runtime_allows_insecure_account_auth() -> bool:
	if allow_insecure_account_auth:
		return true
	if OS.is_debug_build() or Engine.is_editor_hint():
		return true
	if _truthy_string(OS.get_environment(ALLOW_INSECURE_ACCOUNT_AUTH_ENV)):
		return true
	return bool(ProjectSettings.get_setting(ALLOW_INSECURE_ACCOUNT_AUTH_SETTING, false))

func _truthy_string(value: String) -> bool:
	match value.strip_edges().to_lower():
		"1", "true", "yes", "on":
			return true
	return false

func _insecure_account_auth_message() -> String:
	return (
		"Password account auth is disabled on this lobby because the ENet transport is not encrypted. "
		+ "Enable %s only for trusted/private deployments."
	) % ALLOW_INSECURE_ACCOUNT_AUTH_ENV

func _complete_login_for_peer(
	peer_id: int,
	player_name: String,
	profile_id: String,
	account_id: String = "",
	email: String = "",
	username: String = "",
	auth_mode: String = LobbyProtocolScript.LOGIN_ACCOUNT,
	accepts_game_updates: bool = false
) -> void:
	var existing: Dictionary = _get_session_for_peer(peer_id)
	if not existing.is_empty() and not _session_matches_login_identity(existing, profile_id, account_id):
		var existing_session_id := str(existing.get("session_id", "")).strip_edges()
		if not existing_session_id.is_empty():
			session_id_by_peer.erase(peer_id)
			existing["peer_id"] = 0
			existing["connected"] = false
			sessions_by_id[existing_session_id] = existing
		existing = {}
	if existing.is_empty():
		existing = _find_resumable_session(profile_id, account_id)
		if existing.is_empty():
			existing = _create_session(player_name, peer_id, false, profile_id, account_id, email, username, auth_mode, accepts_game_updates)
		else:
			existing = _reclaim_session_for_peer(existing, peer_id, player_name, profile_id, account_id, email, username, auth_mode, accepts_game_updates)
	else:
		existing["player_name"] = player_name
		existing["profile_id"] = profile_id
		existing["account_id"] = account_id
		existing["email"] = email
		existing["username"] = username
		existing["auth_mode"] = auth_mode
		existing["accepts_game_updates"] = accepts_game_updates
		sessions_by_id[str(existing.get("session_id", ""))] = existing
	existing["is_admin"] = _is_admin_username(username) or _is_admin_username(player_name)
	sessions_by_id[str(existing.get("session_id", ""))] = existing
	var session_id := str(existing.get("session_id", "")).strip_edges()
	var room_snapshot: Dictionary = {}
	var room_id := str(room_id_by_session.get(session_id, "")).strip_edges()
	if not room_id.is_empty() and rooms_by_id.has(room_id):
		room_snapshot = rooms_by_id[room_id].to_snapshot(sessions_by_id)
	var active_match_info := _build_active_match_info_for_session(session_id)
	_trace("login accepted for peer %d as session %s" % [peer_id, str(existing.get("session_id", ""))])
	_send_to_peer(peer_id, LobbyProtocolScript.HELLO_OK, {
		"session_id": str(existing.get("session_id", "")),
		"reconnect_token": str(existing.get("reconnect_token", "")),
		"player_name": str(existing.get("player_name", "Guest")),
		"profile_id": str(existing.get("profile_id", "")),
		"account_id": str(existing.get("account_id", "")),
		"email": str(existing.get("email", "")),
		"username": str(existing.get("username", "")),
		"auth_mode": str(existing.get("auth_mode", LobbyProtocolScript.LOGIN_ACCOUNT)),
		"accepts_game_updates": bool(existing.get("accepts_game_updates", false)),
		"allow_friend_observers_to_see_cards": _get_allow_friend_observers_to_see_cards(existing),
		"server_version": _get_server_version(),
		"supports_bot_ladder": true,
		"supports_ladder_pages": true,
		"supports_ladder_filter": true,
		"can_see_players_online": OS.is_debug_build() or Engine.is_editor_hint() or bool(existing.get("is_admin", false)),
		"can_host_top_50_bot_matches": _is_admin_account(existing),
		"can_host_below_top_50_bot_matches": _can_host_below_top_50_bot_matches(existing),
		"can_view_quarantined_bots": _is_admin_account(existing),
		"room": room_snapshot,
		"active_match_info": active_match_info,
	})
	if not room_id.is_empty() and rooms_by_id.has(room_id):
		var restored_room: LobbyRoom = rooms_by_id[room_id]
		_broadcast_room_snapshot(restored_room)
	_send_room_list_to_peer(peer_id)
	if not room_id.is_empty() and rooms_by_id.has(room_id):
		_try_assign_match(rooms_by_id[room_id])

func _session_matches_login_identity(session: Dictionary, profile_id: String, account_id: String) -> bool:
	if session.is_empty():
		return false
	var resolved_account_id := account_id.strip_edges()
	if not resolved_account_id.is_empty():
		return str(session.get("account_id", "")).strip_edges() == resolved_account_id
	var resolved_profile_id := profile_id.strip_edges()
	if resolved_profile_id.is_empty():
		return false
	return str(session.get("profile_id", "")).strip_edges() == resolved_profile_id

func _handle_reconnect_request(peer_id: int, payload: Dictionary) -> void:
	var session_id: String = str(payload.get("session_id", "")).strip_edges()
	var reconnect_token: String = str(payload.get("reconnect_token", "")).strip_edges()
	var session: Dictionary = sessions_by_id.get(session_id, {})

	if session.is_empty():
		_send_error_to_peer(peer_id, "Lobby session not found.")
		return
	if str(session.get("reconnect_token", "")).is_empty() or str(session.get("reconnect_token", "")) != reconnect_token:
		_send_error_to_peer(peer_id, "Reconnect token did not match.")
		return

	var previous_peer_id: int = int(session.get("peer_id", 0))
	if previous_peer_id > 0:
		session_id_by_peer.erase(previous_peer_id)

	session["peer_id"] = peer_id
	session["connected"] = true
	session["room_disconnected_since_unix"] = 0
	sessions_by_id[session_id] = session
	session_id_by_peer[peer_id] = session_id

	var room_snapshot: Dictionary = {}
	var active_match_info: Dictionary = {}
	var restored_room: LobbyRoom = null
	var room_id: String = str(room_id_by_session.get(session_id, ""))
	if not room_id.is_empty() and rooms_by_id.has(room_id):
		restored_room = rooms_by_id[room_id]
		room_snapshot = restored_room.to_snapshot(sessions_by_id)
		active_match_info = _build_active_match_info_for_session(session_id, restored_room)

	_send_to_peer(peer_id, LobbyProtocolScript.LOBBY_RECONNECT_OK, {
		"session_id": session_id,
		"reconnect_token": reconnect_token,
		"player_name": str(session.get("player_name", "Guest")),
		"profile_id": str(session.get("profile_id", "")),
		"account_id": str(session.get("account_id", "")),
		"email": str(session.get("email", "")),
		"username": str(session.get("username", "")),
		"auth_mode": str(session.get("auth_mode", LobbyProtocolScript.LOGIN_ACCOUNT)),
		"accepts_game_updates": bool(session.get("accepts_game_updates", false)),
		"allow_friend_observers_to_see_cards": _get_allow_friend_observers_to_see_cards(session),
		"server_version": _get_server_version(),
		"supports_bot_ladder": true,
		"supports_ladder_pages": true,
		"supports_ladder_filter": true,
		"can_see_players_online": OS.is_debug_build() or Engine.is_editor_hint() or bool(session.get("is_admin", false)),
		"can_host_top_50_bot_matches": _is_admin_account(session),
		"can_host_below_top_50_bot_matches": _can_host_below_top_50_bot_matches(session),
		"can_view_quarantined_bots": _is_admin_account(session),
		"room": room_snapshot,
		"active_match_info": active_match_info,
	})
	if restored_room != null:
		_broadcast_room_snapshot(restored_room)
	_send_room_list_to_peer(peer_id)
	if restored_room != null and rooms_by_id.has(room_id):
		_try_assign_match(rooms_by_id[room_id])

func _handle_report_host_viability(peer_id: int, payload: Dictionary) -> void:
	var session: Dictionary = _get_session_for_peer(peer_id)
	if session.is_empty():
		_send_error_to_peer(peer_id, "Join the lobby before reporting host viability.")
		return
	var session_id := str(session.get("session_id", "")).strip_edges()
	if session_id.is_empty():
		return
	var viable := bool(payload.get("viable", false))
	var reachable_ip := str(payload.get("reachable_ip", "")).strip_edges()
	var reachable_port := int(payload.get("reachable_port", 0))
	var bind_port := int(payload.get("bind_port", reachable_port))
	if reachable_port <= 0:
		bind_port = 0
		viable = false
	var updated: Dictionary = session.duplicate(true)
	updated["host_viable"] = bool(viable)
	updated["host_reachable_ip"] = reachable_ip if viable else ""
	updated["host_reachable_port"] = reachable_port if viable else 0
	updated["host_bind_port"] = bind_port if viable else 0
	sessions_by_id[session_id] = updated
	_trace("host viability session=%s viable=%s ip=%s port=%d" % [
		session_id, str(viable), reachable_ip, reachable_port
	])


## Debug-only roster of signed-in accounts. Release builds silently ignore the
## request so a public server never tells anyone who is logged in.
func _handle_request_players_online(peer_id: int) -> void:
	var session: Dictionary = _get_session_for_peer(peer_id)
	if session.is_empty():
		return
	var is_admin := bool(session.get("is_admin", false))
	if not (OS.is_debug_build() or Engine.is_editor_hint() or is_admin):
		return
	var players: Array[Dictionary] = []
	for session_id_variant in sessions_by_id.keys():
		var raw_entry: Variant = sessions_by_id.get(session_id_variant, {})
		if not (raw_entry is Dictionary) or raw_entry.is_empty():
			continue
		var entry := raw_entry as Dictionary
		if bool(entry.get("is_bot", false)):
			continue
		var username := str(entry.get("username", "")).strip_edges()
		var player_name := str(entry.get("player_name", "")).strip_edges()
		if username.is_empty() and player_name.is_empty():
			continue
		players.append({
			"session_id": str(entry.get("session_id", "")),
			"username": username,
			"player_name": player_name,
			"is_connected": bool(entry.get("connected", false)),
			"is_local": bool(entry.get("is_local", false)),
		})
	players.sort_custom(_compare_players_online_entries)
	_send_to_peer(peer_id, LobbyProtocolScript.PLAYERS_ONLINE, {
		"players": players,
		"count": players.size(),
	})


static func _compare_players_online_entries(a: Dictionary, b: Dictionary) -> bool:
	var a_name := str(a.get("username", "")).strip_edges()
	if a_name.is_empty():
		a_name = str(a.get("player_name", "")).strip_edges()
	var b_name := str(b.get("username", "")).strip_edges()
	if b_name.is_empty():
		b_name = str(b.get("player_name", "")).strip_edges()
	return a_name.to_lower() < b_name.to_lower()


func _handle_request_account_decks(peer_id: int) -> void:
	var session: Dictionary = _get_session_for_peer(peer_id)
	if session.is_empty():
		_send_error_to_peer(peer_id, "Join the lobby before requesting account decks.")
		return
	var account_id: String = str(session.get("account_id", "")).strip_edges()
	if account_id.is_empty():
		_send_error_to_peer(peer_id, "Log into an account before requesting saved decks.")
		return
	_ensure_deck_store()
	_ensure_profile_store()
	if deck_store == null:
		_send_error_to_peer(peer_id, "Deck storage is unavailable.")
		return
	_send_to_peer(peer_id, LobbyProtocolScript.ACCOUNT_DECK_LIST, {
		"decks": deck_store.list_decks(account_id),
		"preferred_deck_id": str(profile_store.get_preferred_deck_id_for_account(account_id)) if profile_store != null else "",
	})

func _handle_save_account_deck(peer_id: int, payload: Dictionary) -> void:
	var session: Dictionary = _get_session_for_peer(peer_id)
	if session.is_empty():
		_send_error_to_peer(peer_id, "Join the lobby before saving account decks.")
		return
	var account_id: String = str(session.get("account_id", "")).strip_edges()
	if account_id.is_empty():
		_send_error_to_peer(peer_id, "Log into an account before saving decks.")
		return
	_ensure_deck_store()
	if deck_store == null:
		_send_error_to_peer(peer_id, "Deck storage is unavailable.")
		return
	var save_result: Dictionary = deck_store.save_deck(
		account_id,
		str(payload.get("deck_name", "")),
		payload.get("cards", {}),
		str(payload.get("deck_id", "")),
		payload.get("special_setup", {}),
		payload.get("reinforcements", {})
	)
	if not bool(save_result.get("success", false)):
		_send_error_to_peer(peer_id, str(save_result.get("message", "Could not save that deck.")))
		return
	_send_to_peer(peer_id, LobbyProtocolScript.ACCOUNT_DECK_SAVED, {
		"deck": save_result.get("deck", {}),
	})

func _handle_delete_account_deck(peer_id: int, payload: Dictionary) -> void:
	var session: Dictionary = _get_session_for_peer(peer_id)
	if session.is_empty():
		_send_error_to_peer(peer_id, "Join the lobby before deleting account decks.")
		return
	var account_id: String = str(session.get("account_id", "")).strip_edges()
	if account_id.is_empty():
		_send_error_to_peer(peer_id, "Log into an account before deleting decks.")
		return
	_ensure_deck_store()
	_ensure_profile_store()
	if deck_store == null:
		_send_error_to_peer(peer_id, "Deck storage is unavailable.")
		return
	var delete_result: Dictionary = deck_store.delete_deck(account_id, str(payload.get("deck_id", "")))
	if not bool(delete_result.get("success", false)):
		_send_error_to_peer(peer_id, str(delete_result.get("message", "Could not delete that deck.")))
		return
	if profile_store != null:
		var deleted_deck_id := str(delete_result.get("deck_id", ""))
		if profile_store.get_preferred_deck_id_for_account(account_id) == deleted_deck_id:
			profile_store.set_preferred_deck_id_for_account(account_id, "")
	_send_to_peer(peer_id, LobbyProtocolScript.ACCOUNT_DECK_DELETED, {
		"deck_id": str(delete_result.get("deck_id", "")),
	})

func _handle_set_account_preferred_deck(peer_id: int, payload: Dictionary) -> void:
	var session: Dictionary = _get_session_for_peer(peer_id)
	if session.is_empty():
		_send_error_to_peer(peer_id, "Join the lobby before choosing a preferred deck.")
		return
	var account_id: String = str(session.get("account_id", "")).strip_edges()
	var deck_id: String = str(payload.get("deck_id", "")).strip_edges()
	if account_id.is_empty():
		_send_error_to_peer(peer_id, "Log into an account before choosing a preferred deck.")
		return
	if deck_id.is_empty():
		_send_error_to_peer(peer_id, "Choose a saved deck first.")
		return
	_ensure_deck_store()
	_ensure_profile_store()
	if deck_store == null or profile_store == null:
		_send_error_to_peer(peer_id, "Deck storage is unavailable.")
		return
	if deck_store.get_deck(account_id, deck_id).is_empty():
		_send_error_to_peer(peer_id, "That saved deck was not found.")
		return
	profile_store.set_preferred_deck_id_for_account(account_id, deck_id)

func _handle_set_observer_friend_card_visibility(peer_id: int, payload: Dictionary) -> void:
	var session: Dictionary = _get_session_for_peer(peer_id)
	if session.is_empty():
		_send_error_to_peer(peer_id, "Join the lobby before changing observer privacy.")
		return
	var account_id := str(session.get("account_id", "")).strip_edges()
	if account_id.is_empty():
		_send_error_to_peer(peer_id, "Log into an account before changing observer privacy.")
		return
	_ensure_profile_store()
	if profile_store == null:
		_send_error_to_peer(peer_id, "Profile storage is unavailable.")
		return
	profile_store.set_allow_friend_observers_to_see_cards_for_account(
		account_id,
		bool(payload.get("allow_friend_observers_to_see_cards", true))
	)

func _handle_request_profile_summary(peer_id: int) -> void:
	var session: Dictionary = _get_session_for_peer(peer_id)
	if session.is_empty():
		_send_error_to_peer(peer_id, "Join the lobby before requesting your match history.")
		return
	var profile_id: String = str(session.get("profile_id", "")).strip_edges()
	if profile_id.is_empty():
		_send_error_to_peer(peer_id, "No profile is attached to this session.")
		return
	_ensure_match_history_store()
	if match_history_store == null:
		_send_error_to_peer(peer_id, "Match history storage is unavailable.")
		return
	var account_id := str(session.get("account_id", "")).strip_edges()
	var summary: Dictionary = match_history_store.get_profile_summary(profile_id, 5, account_id)
	if not account_id.is_empty() and account_store != null:
		summary["supports_rank_badges"] = true
		for key in ["ranked_progress", "ranked_bo3_progress"]:
			var progress: Dictionary = summary.get(key, {})
			if not progress.is_empty():
				var league := RankBadgeCatalog.league_for_rank(progress["rank_name"])
				progress["portrait"] = account_store.get_rank_badge(account_id, league)
	_send_to_peer(peer_id, LobbyProtocolScript.PROFILE_SUMMARY, summary)

func _handle_set_rank_badge(peer_id: int, payload: Dictionary) -> void:
	var account_id := str(_get_session_for_peer(peer_id).get("account_id", ""))
	var message := ""
	if account_id.is_empty() or account_store == null:
		message = "Sign in to save your rank badge."
	else:
		_ensure_match_history_store()
		var progress: Dictionary = match_history_store.get_current_ranked_progress(account_id, int(payload["best_of"]))
		var league := RankBadgeCatalog.league_for_rank(str(progress.get("rank_name", "")))
		var requested: Dictionary = payload["portrait"]
		var portrait := RankBadgeCatalog.validate_portrait(league, requested)
		if league < 0 or league != payload["league"]:
			message = "Your rank changed. Reopen the badge picker to choose again."
		elif not requested.is_empty() and portrait.is_empty():
			message = "This portrait is unavailable at your current rank."
		elif not account_store.set_rank_badge(account_id, league, portrait):
			message = "Could not save your rank badge."
	var success := message.is_empty()
	_send_to_peer(peer_id, LobbyProtocolScript.RANK_BADGE_RESULT, {"success": success, "message": message})
	if success:
		_handle_request_profile_summary(peer_id)

func _is_admin_account(session: Dictionary) -> bool:
	return bool(session.get("is_admin", false)) and not str(session.get("account_id", "")).is_empty()

func _can_host_below_top_50_bot_matches(session: Dictionary) -> bool:
	return OS.is_debug_build() or Engine.is_editor_hint() or _is_admin_account(session)

func _handle_request_bot_work(peer_id: int, payload: Dictionary = {}) -> void:
	var session := _get_session_for_peer(peer_id)
	if session.is_empty() or str(session.get("account_id", "")).is_empty():
		return
	var best_of := _payload_best_of(payload)
	var top_50 := bool(payload.get("top_50", false))
	if top_50 and not _is_admin_account(session):
		_send_to_peer(peer_id, LobbyProtocolScript.BOT_WORK_RESULT, {
			"job_id": "", "success": false, "message": "Only admins can host top 50 bot matches.",
		})
		return
	var below_top_50 := bool(payload.get("below_top_50", false))
	if below_top_50 and not _can_host_below_top_50_bot_matches(session):
		_send_to_peer(peer_id, LobbyProtocolScript.BOT_WORK_RESULT, {
			"job_id": "", "success": false, "message": "Only debug clients can host bot matches below the top 50.",
		})
		return
	var new_bots_only := bool(payload.get("new_bots_only", false))
	if new_bots_only and not _can_host_below_top_50_bot_matches(session):
		_send_to_peer(peer_id, LobbyProtocolScript.BOT_WORK_RESULT, {
			"job_id": "", "success": false, "message": "Only debug clients can host new bot batch matches.",
		})
		return
	var requested_god := str(payload.get("god_name", "")).strip_edges()
	if not requested_god.is_empty() and not _can_host_below_top_50_bot_matches(session):
		_send_to_peer(peer_id, LobbyProtocolScript.BOT_WORK_RESULT, {
			"job_id": "", "success": false, "message": "Only debug clients can host god-specific bot matches.",
		})
		return
	var busy := {}
	var excluded_list_ids: Array = payload.get("excluded_list_ids", [])
	for list_id in excluded_list_ids:
		busy[str(list_id)] = true
	var account_job_count := 0
	for job: Dictionary in _client_bot_jobs.values():
		if int(job.get("expires_unix", 0)) > Time.get_unix_time_from_system():
			if str(job.get("account_id", "")) == str(session["account_id"]):
				account_job_count += 1
			busy[str(job.get("deck_a", {}).get("bot_list_id", ""))] = true
			busy[str(job.get("deck_b", {}).get("bot_list_id", ""))] = true
	if account_job_count >= MAX_CLIENT_BOT_WORKERS_PER_ACCOUNT:
		_send_to_peer(peer_id, LobbyProtocolScript.BOT_WORK_RESULT, {
			"job_id": "",
			"success": false,
			"message": "This account already has the maximum number of volunteer matches running.",
		})
		return
	# Serve pending league round-robin pairings first so volunteers play the
	# scheduled tournament matches instead of random self-play pairs.
	var pending_index := -1
	if not top_50 and not below_top_50 and not new_bots_only and requested_god.is_empty():
		for index in range(_pending_league_pairings.size()):
			if int((_pending_league_pairings[index] as Dictionary).get("best_of", 1)) == best_of:
				pending_index = index
				break
	if pending_index >= 0:
		var pairing: Dictionary = _pending_league_pairings[pending_index]
		_pending_league_pairings.remove_at(pending_index)
		var candidate_a := _validate_server_bot_deck(pairing["deck_a"])
		var candidate_b := _validate_server_bot_deck(pairing["deck_b"])
		if not candidate_a.is_empty() and not candidate_b.is_empty() \
				and not busy.has(str(candidate_a.get("list_id", ""))) \
				and not busy.has(str(candidate_b.get("list_id", ""))):
			var deck_a := candidate_a
			var deck_b := candidate_b
			for deck in [deck_a, deck_b]:
				deck["bot_god_name"] = deck["god_name"]
				deck["bot_list_id"] = deck["list_id"]
				deck["bot_stars"] = deck["stars"]
				deck["bot_win_streak"] = int(deck.get("win_streak", 0))
			var job_id := _generate_id(32)
			_client_bot_jobs[job_id] = {
				"account_id": str(session["account_id"]),
				"session_id": str(session.get("session_id", "")),
				"deck_a": deck_a,
				"deck_b": deck_b,
				"expires_unix": int(Time.get_unix_time_from_system()) + 600,
				"status": "assigned",
				"league_match": true,
				"best_of": best_of,
			}
			_send_to_peer(peer_id, LobbyProtocolScript.BOT_WORK_ASSIGNMENT, {
				"job_id": job_id,
				"decks": [deck_a, deck_b],
			})
			return
	# Pairing failed validation (deck changed or retired); try next pairing on
	# the next work request.
	_refresh_ranked_bot_deck_pool()
	var requested_bot_id := str(payload.get("bot_id", "")).strip_edges()
	var deck_a: Dictionary
	var deck_b: Dictionary
	if new_bots_only:
		var batch_pair := _select_new_rubric_bot_pair(busy, best_of)
		if batch_pair.size() != 2:
			_send_to_peer(peer_id, LobbyProtocolScript.BOT_WORK_RESULT, {
				"job_id": "", "success": false,
				"message": "No new rubric bot batch is available for this computer right now.",
			})
			return
		deck_a = batch_pair[0]
		deck_b = batch_pair[1]
	elif not requested_bot_id.is_empty():
		busy[requested_bot_id] = true
		var owned_bot := _find_community_bot(str(session["account_id"]), requested_bot_id, best_of)
		if owned_bot.is_empty():
			_send_to_peer(peer_id, LobbyProtocolScript.BOT_WORK_RESULT, {
				"job_id": "", "success": false, "message": "That submitted bot is unavailable.",
			})
			return
		if bool(owned_bot.get("quarantined", false)):
			_send_to_peer(peer_id, LobbyProtocolScript.BOT_WORK_RESULT, {
				"job_id": "", "success": false,
				"message": "That bot is quarantined and cannot be paired into a match. Release it from quarantine first.",
			})
			return
		deck_a = owned_bot
		var available := _bot_pool(best_of).select_deck(busy, _bot_deck_rng, 0)
		deck_b = _validate_server_bot_deck(available) if not available.is_empty() else _build_fresh_bot_deck_submission({}, best_of)
	elif below_top_50:
		var below_ids := _get_bots_below_top_50_list_ids(best_of)
		if below_ids.is_empty():
			_send_to_peer(peer_id, LobbyProtocolScript.BOT_WORK_RESULT, {
				"job_id": "", "success": false,
				"message": "No bot match below the top 50 is available right now.",
			})
			return
		var below_pair := _bot_pool(best_of).select_self_play_pair(
			busy, _bot_deck_rng, below_ids, below_ids, true
		)
		if below_pair.size() != 2:
			_send_to_peer(peer_id, LobbyProtocolScript.BOT_WORK_RESULT, {
				"job_id": "", "success": false,
				"message": "No bot match below the top 50 is available right now.",
			})
			return
		deck_a = _validate_server_bot_deck(below_pair[0])
		deck_b = _validate_server_bot_deck(below_pair[1])
	elif not requested_god.is_empty():
		# Debug god-specific hosting: seat a ladder bot of the requested god
		# first, then pair it with any eligible opponent. When the ladder has
		# no usable pair, fall back to freshly built decks of that god so the
		# match still runs.
		var god_list_ids := _get_bot_list_ids_for_god(requested_god, best_of)
		var god_pair: Array[Dictionary] = []
		if not god_list_ids.is_empty():
			god_pair = _bot_pool(best_of).select_self_play_pair(busy, _bot_deck_rng, god_list_ids, {}, true)
		if god_pair.size() == 2:
			deck_a = _validate_server_bot_deck(god_pair[0])
			deck_b = _validate_server_bot_deck(god_pair[1])
		if deck_a.is_empty():
			deck_a = _build_fresh_bot_deck_submission({}, best_of, requested_god)
		if deck_b.is_empty():
			deck_b = _build_fresh_bot_deck_submission({requested_god: 1}, best_of, requested_god)
	else:
		var top_list_ids := _get_top_50_bot_list_ids(best_of) if top_50 else {}
		var pair: Array[Dictionary] = []
		if not top_50 or not top_list_ids.is_empty():
			pair = _bot_pool(best_of).select_self_play_pair(busy, _bot_deck_rng, top_list_ids)
		if not pair.is_empty():
			deck_a = _validate_server_bot_deck(pair[0])
		elif not top_50:
			deck_a = _build_fresh_bot_deck_submission({}, best_of)
		if pair.size() == 2:
			deck_b = _validate_server_bot_deck(pair[1])
		elif not top_50 or not deck_a.is_empty():
			deck_b = _build_fresh_bot_deck_submission({str(deck_a.get("god_name", "")): 1}, best_of)
	if deck_a.is_empty() or deck_b.is_empty():
		var unavailable_message := "No bot match is available for this computer right now."
		if top_50:
			unavailable_message = "No top 50 bot match is available right now."
		elif not requested_god.is_empty():
			unavailable_message = "No %s bot match is available right now." \
				% RankedBotDeckPoolScript.display_god_name(requested_god)
		_send_to_peer(peer_id, LobbyProtocolScript.BOT_WORK_RESULT, {
			"job_id": "",
			"success": false,
			"message": unavailable_message,
		})
		return
	for deck in [deck_a, deck_b]:
		var g_name := str(deck.get("god_name", ""))
		deck["bot_god_name"] = g_name
		var l_id := str(deck.get("bot_list_id", deck.get("list_id", ""))).strip_edges()
		deck["list_id"] = l_id
		deck["bot_list_id"] = l_id
		deck["bot_stars"] = int(deck.get("stars", deck.get("bot_stars", 0)))
		deck["bot_win_streak"] = int(deck.get("win_streak", deck.get("bot_win_streak", 0)))
		if not deck.has("bot_name") or str(deck["bot_name"]).is_empty():
			deck["bot_name"] = str(deck.get("deck_name", ""))
	var job_id := _generate_id(32)
	_client_bot_jobs[job_id] = {
		"account_id": str(session["account_id"]),
		"session_id": str(session.get("session_id", "")),
		"deck_a": deck_a,
		"deck_b": deck_b,
		"best_of": best_of,
		"expires_unix": int(Time.get_unix_time_from_system()) + 600,
		"status": "assigned",
		"new_bot_evaluation": new_bots_only,
	}
	_send_to_peer(peer_id, LobbyProtocolScript.BOT_WORK_ASSIGNMENT, {
		"job_id": job_id,
		"decks": [deck_a, deck_b],
		"best_of": best_of,
	})

func _handle_seed_bot_league(peer_id: int, payload: Dictionary = {}) -> void:
	var session := _get_session_for_peer(peer_id)
	if session.is_empty() or str(session.get("account_id", "")).is_empty():
		_send_error_to_peer(peer_id, "Sign in before seeding the bot league.")
		return
	var count_per_god := clampi(int(payload.get("count_per_god", 10)), 1, 64)
	var best_of := 3 if int(payload.get("best_of", 1)) == 3 else 1
	var result := seed_bot_league(count_per_god, best_of)
	_send_to_peer(peer_id, LobbyProtocolScript.BOT_LEAGUE_RESULT, {
		"request": LobbyProtocolScript.SEED_BOT_LEAGUE,
		"success": bool(result.get("success", false)),
		"message": result.get("message", ""),
		"gods": result.get("gods", {}),
		"count_per_god": count_per_god,
	})

func _handle_finalize_bot_league(peer_id: int, payload: Dictionary = {}) -> void:
	var session := _get_session_for_peer(peer_id)
	if session.is_empty():
		_send_error_to_peer(peer_id, "Join the lobby before finalizing the bot league.")
		return
	var best_of := 3 if int(payload.get("best_of", 1)) == 3 else 1
	var result := finalize_bot_league(best_of)
	_send_to_peer(peer_id, LobbyProtocolScript.BOT_LEAGUE_RESULT, {
		"request": LobbyProtocolScript.FINALIZE_BOT_LEAGUE,
		"success": bool(result.get("success", false)),
		"summary": result.get("summary", {}),
	})

func _handle_request_bot_league_status(peer_id: int, payload: Dictionary = {}) -> void:
	var session := _get_session_for_peer(peer_id)
	if session.is_empty():
		_send_error_to_peer(peer_id, "Join the lobby to view bot league status.")
		return
	var best_of := 3 if int(payload.get("best_of", 1)) == 3 else 1
	var status := get_bot_league_status(best_of)
	_send_to_peer(peer_id, LobbyProtocolScript.BOT_LEAGUE_STATUS, {
		"success": true,
		"league_mode": bool(status.get("league_mode", false)),
		"gods": status.get("gods", []),
		"total_bots": int(status.get("total_bots", 0)),
		"total_matches": int(status.get("total_matches", 0)),
		"target_matches_per_bot": LEAGUE_ROUND_ROBIN_DEFAULT_MATCHES_PER_BOT,
	})

func _handle_run_league_round_robin(peer_id: int, payload: Dictionary = {}) -> void:
	var session := _get_session_for_peer(peer_id)
	if session.is_empty() or str(session.get("account_id", "")).is_empty():
		_send_error_to_peer(peer_id, "Sign in before running the league round robin.")
		return
	var matches_per_bot := clampi(int(payload.get("matches_per_bot", 50)), 1, 500)
	var best_of := 3 if int(payload.get("best_of", 1)) == 3 else 1
	var result := run_league_round_robin(matches_per_bot, best_of)
	_send_to_peer(peer_id, LobbyProtocolScript.LEAGUE_ROUND_ROBIN_RESULT, {
		"success": bool(result.get("success", false)),
		"message": result.get("message", ""),
		"total_matches": int(result.get("total_matches", 0)),
		"matches_per_bot": matches_per_bot,
		"bot_count": int(result.get("bot_count", 0)),
	})

func _handle_clear_league_bots(peer_id: int, payload: Dictionary = {}) -> void:
	var session := _get_session_for_peer(peer_id)
	if session.is_empty() or str(session.get("account_id", "")).is_empty():
		_send_error_to_peer(peer_id, "Sign in before clearing league bots.")
		return
	_refresh_ranked_bot_deck_pool()
	var best_of := 3 if int(payload.get("best_of", 1)) == 3 else 1
	var league_pool := _bot_pool(best_of)
	var result := league_pool.clear_league_bots()
	league_pool.set_league_mode(false)
	_pending_league_pairings = _pending_league_pairings.filter(func(pairing: Dictionary) -> bool:
		return int(pairing.get("best_of", 1)) != best_of
	)
	_invalidate_ladder_cache()
	_send_to_peer(peer_id, LobbyProtocolScript.CLEAR_LEAGUE_BOTS_RESULT, {
		"success": true,
		"removed": int(result.get("removed", 0)),
		"removed_by_god": result.get("removed_by_god", {}),
	})

func _handle_rebuild_league_records(peer_id: int, payload: Dictionary = {}) -> void:
	var session := _get_session_for_peer(peer_id)
	if session.is_empty() or str(session.get("account_id", "")).is_empty():
		_send_error_to_peer(peer_id, "Sign in before rebuilding league records.")
		return
	_ensure_match_history_store()
	_refresh_ranked_bot_deck_pool()
	# Scan dedicated result files directly, bypassing get_bot_deck_results() cache
	# which can return empty on a fresh server instance if results were written
	# to per-match files rather than match_history.json.
	var best_of := 3 if int(payload.get("best_of", 1)) == 3 else 1
	var results: Array[Dictionary] = _collect_bot_deck_results_from_files(best_of)
	var result := _bot_pool(best_of).rebuild_league_records(results)
	_invalidate_ladder_cache()
	_send_to_peer(peer_id, LobbyProtocolScript.REBUILD_LEAGUE_RECORDS_RESULT, {
		"success": true,
		"re_registered": int(result.get("re_registered", 0)),
		"replayed": int(result.get("replayed", 0)),
		"league_result_count": int(result.get("league_result_count", 0)),
	})

# Scans server_data/match_history_results/ directly and collects every
# bot_deck_results entry. Bypasses the MatchHistoryStore cache so results are
# found even on a fresh server instance.
func _count_bot_result_files() -> int:
	var count := 0
	var results_dir := ServerPathsScript.get_server_data_file_path("match_history_results")
	var dir := DirAccess.open(results_dir)
	if dir != null:
		dir.list_dir_begin()
		var file_name := dir.get_next()
		while not file_name.is_empty():
			if not dir.current_is_dir() and file_name.ends_with(".json"):
				count += 1
			file_name = dir.get_next()
		dir.list_dir_end()
	if FileAccess.file_exists(ServerPathsScript.get_server_data_file_path("match_history.json")):
		count += 1
	return count

func _collect_bot_deck_results_from_files(best_of: int = 0) -> Array[Dictionary]:
	var results: Array[Dictionary] = []
	# Source 1: dedicated per-match result files (dedicated results mode)
	var results_dir := ServerPathsScript.get_server_data_file_path("match_history_results")
	var dir := DirAccess.open(results_dir)
	if dir != null:
		dir.list_dir_begin()
		var file_name := dir.get_next()
		while not file_name.is_empty():
			if not dir.current_is_dir() and file_name.ends_with(".json"):
				var path := results_dir.path_join(file_name)
				var entry := JsonStoreScript.load_dictionary(path, {}, "MatchHistoryStore")
				var entry_best_of := int(entry.get("best_of", 1))
				if not entry.is_empty() and entry.has("bot_deck_results") and (best_of == 0 or entry_best_of == best_of):
					for row: Dictionary in entry.get("bot_deck_results", []):
						if row is Dictionary:
							var result := row.duplicate(true)
							result["match_id"] = str(entry.get("match_id", ""))
							if entry.get("bot_deck_results", []).size() > 1:
								result["match_id"] = "%s_%d" % [result["match_id"], int(result.get("player_index", 0))]
							result["bot_eliminated"] = false
							if not result.has("played_unix"):
								result["played_unix"] = float(entry.get("played_unix", 0.0))
							if not result.has("best_of"):
								result["best_of"] = entry_best_of
							results.append(result)
			file_name = dir.get_next()
		dir.list_dir_end()
	print("[Bot League Debug] collected %d results from dedicated dir %s" % [results.size(), results_dir])
	# Source 2: legacy match_history.json (non-dedicated results mode)
	var history_path := ServerPathsScript.get_server_data_file_path("match_history.json")
	if FileAccess.file_exists(history_path):
		var history := JsonStoreScript.load_dictionary(history_path, {}, "MatchHistoryStore")
		var stored_matches: Dictionary = history.get("matches_by_id", {})
		if stored_matches is Dictionary:
			for match_id_variant in stored_matches.keys():
				var entry: Dictionary = stored_matches[match_id_variant]
				var entry_best_of := int(entry.get("best_of", 1))
				if entry is Dictionary and entry.has("bot_deck_results") and (best_of == 0 or entry_best_of == best_of):
					for row: Dictionary in entry.get("bot_deck_results", []):
						if row is Dictionary:
							var result := row.duplicate(true)
							result["match_id"] = str(match_id_variant)
							if entry.get("bot_deck_results", []).size() > 1:
								result["match_id"] = "%s_%d" % [result["match_id"], int(result.get("player_index", 0))]
							result["bot_eliminated"] = false
							if not result.has("played_unix"):
								result["played_unix"] = float(entry.get("played_unix", 0.0))
							if not result.has("best_of"):
								result["best_of"] = entry_best_of
							results.append(result)
		print("[Bot League Debug] collected %d results total (including legacy match_history.json)" % results.size())
	else:
		print("[Bot League Debug] no legacy match_history.json at %s" % history_path)
	return results

func _handle_dump_bot_deck_results(peer_id: int, payload: Dictionary = {}) -> void:
	var session := _get_session_for_peer(peer_id)
	if session.is_empty() or str(session.get("account_id", "")).is_empty():
		_send_error_to_peer(peer_id, "Sign in before dumping bot deck results.")
		return
	_ensure_match_history_store()
	_refresh_ranked_bot_deck_pool()
	var results = _collect_bot_deck_results_from_files()
	var total := 0
	var league_count := 0
	var non_league_count := 0
	var dump_paths: Array[String] = []
	var dump_ok := true
	for best_of in [1, 3]:
		var format_results: Array[Dictionary] = []
		for result: Dictionary in results:
			if int(result.get("best_of", 1)) == int(best_of):
				format_results.append(result)
		var dump_result := _bot_pool(best_of).dump_bot_deck_results(format_results)
		var pool_dump := _bot_pool(best_of).dump_pool_state()
		total += int(dump_result.get("total", 0))
		league_count += int(dump_result.get("league_count", 0))
		non_league_count += int(dump_result.get("non_league_count", 0))
		dump_ok = dump_ok and bool(pool_dump.get("success", false))
		if not str(pool_dump.get("path", "")).is_empty():
			dump_paths.append("Bo%d: %s" % [best_of, str(pool_dump.get("path", ""))])
	_send_to_peer(peer_id, LobbyProtocolScript.DUMP_BOT_DECK_RESULTS_RESULT, {
		"success": true,
		"total": total,
		"league_count": league_count,
		"non_league_count": non_league_count,
		"pool_dump_path": ", ".join(dump_paths),
		"pool_dump_ok": dump_ok,
	})

func _find_community_bot(account_id: String, bot_id: String, best_of: int = 1) -> Dictionary:
	if account_id.is_empty() or bot_id.is_empty() or bot_id.contains("/") or bot_id.contains("\\"):
		return {}
	var bot_path := ServerPathsScript.get_server_data_file_path("community_bot_pool").path_join("%s.json" % bot_id)
	if not FileAccess.file_exists(bot_path):
		return {}
	var bot := JsonStoreScript.load_dictionary(bot_path, {}, "CommunityBotPool")
	if str(bot.get("account_id", "")) != account_id:
		return {}
	var display_name := _community_bot_display_name(bot)
	bot["name"] = display_name
	bot["deck_name"] = display_name
	bot["is_community_bot"] = true
	bot["bot_list_id"] = bot_id
	bot["list_id"] = bot_id
	bot["bot_god_name"] = str(bot.get("god_name", ""))
	bot["owner_name"] = str(bot.get("owner_name", account_id)).strip_edges()
	bot["bot_name"] = str(bot.get("bot_name", "")).strip_edges()
	if bot["bot_name"].is_empty():
		bot["bot_name"] = display_name
	# Attach the ladder record replayed from this bot's stored results so its
	# rank badge, live-match rows, and win-streak scoring keep updating as it
	# plays, instead of restarting at zero stars in every hosted match.
	_refresh_ranked_bot_deck_pool()
	var record := _bot_pool(best_of).get_deck_details(bot_id)
	var stars := int(record.get("stars", 0))
	bot["bot_stars"] = stars
	bot["stars"] = stars
	bot["bot_win_streak"] = int(record.get("win_streak", 0))
	bot["win_streak"] = int(record.get("win_streak", 0))
	return bot

## Community bots use the same "God: Name" ladder format as the rest of the
## ranked bot pool; the creator is surfaced separately as a "Created by" field.
func _community_bot_display_name(bot: Dictionary) -> String:
	var raw_name := str(bot.get("bot_name", "")).strip_edges()
	if raw_name.is_empty():
		# Bots submitted before bot_name was stored kept the creator inside
		# deck_name as "Owner's Bot": strip that prefix back off.
		var deck_name := str(bot.get("deck_name", "")).strip_edges()
		var owner_name := str(bot.get("owner_name", "")).strip_edges()
		var legacy_prefix := "%s's " % owner_name
		if not owner_name.is_empty() and deck_name.begins_with(legacy_prefix):
			raw_name = deck_name.substr(legacy_prefix.length()).strip_edges()
		else:
			raw_name = deck_name
	if raw_name.is_empty():
		raw_name = "Community Bot"
	var god_name := RankedBotDeckPoolScript.display_god_name(str(bot.get("god_name", ""))).strip_edges()
	if god_name.is_empty():
		return raw_name
	return "%s: %s" % [god_name, raw_name]

func _public_bot_entry(bot: Dictionary) -> Dictionary:
	return {
		"bot_id": str(bot.get("bot_id", "")),
		"deck_name": _community_bot_display_name(bot),
		"god_name": str(bot.get("god_name", "")),
		"submitted_unix": int(bot.get("submitted_unix", 0)),
		"quarantined": bool(bot.get("quarantined", false)),
	}

func _handle_submit_issue_report(peer_id: int, payload: Dictionary) -> void:
	var session := _get_session_for_peer(peer_id)
	if session.is_empty():
		_send_to_peer(peer_id, LobbyProtocolScript.ISSUE_REPORT_RESULT, {
			"success": false,
			"message": "Sign in to the lobby before submitting a report.",
		})
		return
	var account_id := str(session.get("account_id", ""))
	var now_unix := int(Time.get_unix_time_from_system())
	var last_submit := int(_issue_report_last_submit_by_peer.get(account_id, 0))
	if now_unix - last_submit < ISSUE_REPORT_COOLDOWN_SECONDS:
		_send_to_peer(peer_id, LobbyProtocolScript.ISSUE_REPORT_RESULT, {
			"success": false,
			"message": "Please wait a minute before sending another report.",
		})
		return
	var screenshot_bytes := PackedByteArray()
	var screenshot_jpeg := str(payload.get("screenshot_jpeg", ""))
	if not screenshot_jpeg.is_empty():
		screenshot_bytes = Marshalls.base64_to_raw(screenshot_jpeg)
		if screenshot_bytes.size() < 3 or screenshot_bytes[0] != 0xFF or screenshot_bytes[1] != 0xD8 or screenshot_bytes[2] != 0xFF:
			_send_to_peer(peer_id, LobbyProtocolScript.ISSUE_REPORT_RESULT, {
				"success": false,
				"message": "The screenshot could not be read. Please choose a JPEG or submit without it.",
			})
			return
	var report_id := "%d_%d_%d" % [now_unix, peer_id, Time.get_ticks_usec() % 1000000]
	var report_dir := ServerPathsScript.get_server_data_file_path("issue_reports")
	DirAccess.make_dir_recursive_absolute(report_dir)
	var screenshot_file := ""
	if not screenshot_bytes.is_empty():
		screenshot_file = "%s.jpg" % report_id
		var screenshot_path := report_dir.path_join(screenshot_file)
		DirAccess.make_dir_recursive_absolute(report_dir)
		var screenshot_handle := FileAccess.open(screenshot_path, FileAccess.WRITE)
		if screenshot_handle == null:
			_send_to_peer(peer_id, LobbyProtocolScript.ISSUE_REPORT_RESULT, {
				"success": false,
				"message": "The server could not save the screenshot. Please try again without it.",
			})
			return
		screenshot_handle.store_buffer(screenshot_bytes)
		screenshot_handle.flush()
		screenshot_handle.close()
	var report := {
		"report_id": report_id,
		"submitted_unix": now_unix,
		"account_id": str(session.get("account_id", "")),
		"username": str(session.get("username", session.get("player_name", "Player"))),
		"expected": str(payload.get("expected", "")).strip_edges(),
		"actual": str(payload.get("actual", "")).strip_edges(),
		"client_version": str(payload.get("client_version", "")).substr(0, 80),
		"platform": str(payload.get("platform", "")).substr(0, 40),
		"screenshot_file": screenshot_file,
	}
	var report_path := report_dir.path_join("%s.json" % report_id)
	var report_handle := FileAccess.open(report_path, FileAccess.WRITE)
	if report_handle == null:
		if not screenshot_file.is_empty():
			DirAccess.remove_absolute(report_dir.path_join(screenshot_file))
		_send_to_peer(peer_id, LobbyProtocolScript.ISSUE_REPORT_RESULT, {
			"success": false,
			"message": "The server could not save the report. Please try again later.",
		})
		return
	report_handle.store_string(JSON.stringify(report, "\t"))
	report_handle.flush()
	report_handle.close()
	_issue_report_last_submit_by_peer[account_id] = now_unix
	print("LobbyServer: issue report received id=%s account=%s" % [report_id, str(session.get("account_id", ""))])
	_send_to_peer(peer_id, LobbyProtocolScript.ISSUE_REPORT_RESULT, {
		"success": true,
		"message": "Report submitted. Thank you.",
	})

func _handle_submit_bot_proposal(peer_id: int, payload: Dictionary) -> void:
	var session := _get_session_for_peer(peer_id)
	if session.is_empty():
		_send_to_peer(peer_id, LobbyProtocolScript.BOT_PROPOSAL_RESULT, {
			"success": false,
			"message": "Sign in to the lobby before submitting a bot suggestion.",
		})
		return
	var account_id := str(session.get("account_id", ""))
	var now_unix := int(Time.get_unix_time_from_system())
	var last_submit := int(_bot_proposal_last_submit_by_account.get(account_id, 0))
	if now_unix - last_submit < BOT_PROPOSAL_COOLDOWN_SECONDS:
		_send_to_peer(peer_id, LobbyProtocolScript.BOT_PROPOSAL_RESULT, {
			"success": false,
			"message": "Please wait a minute before sending another bot suggestion.",
		})
		return
	var submission_id := "%d_%d_%d" % [now_unix, peer_id, Time.get_ticks_usec() % 1000000]
	var submission := {
		"submission_id": submission_id,
		"submitted_unix": now_unix,
		"account_id": account_id,
		"username": str(session.get("username", session.get("player_name", "Player"))),
		"strategy": str(payload.get("strategy", "")).strip_edges(),
		"deck_text": str(payload.get("deck_text", "")).strip_edges(),
		"deck_code": str(payload.get("deck_code", "")).strip_edges(),
		"client_version": str(payload.get("client_version", "")).substr(0, 80),
		"platform": str(payload.get("platform", "")).substr(0, 40),
	}
	var submission_dir := ServerPathsScript.get_server_data_file_path("bot_submissions")
	DirAccess.make_dir_recursive_absolute(submission_dir)
	var submission_path := submission_dir.path_join("%s.json" % submission_id)
	var file := FileAccess.open(submission_path, FileAccess.WRITE)
	if file == null:
		_send_to_peer(peer_id, LobbyProtocolScript.BOT_PROPOSAL_RESULT, {
			"success": false,
			"message": "The server could not save the suggestion. Please try again later.",
		})
		return
	file.store_string(JSON.stringify(submission, "\t"))
	file.flush()
	file.close()
	_bot_proposal_last_submit_by_account[account_id] = now_unix
	print("LobbyServer: bot suggestion received id=%s account=%s" % [submission_id, account_id])
	_send_to_peer(peer_id, LobbyProtocolScript.BOT_PROPOSAL_RESULT, {
		"success": true,
		"message": "Bot suggestion submitted. Thank you.",
	})

func _handle_submit_bot_deck(peer_id: int, payload: Dictionary) -> void:
	var session := _get_session_for_peer(peer_id)
	var account_id := str(session.get("account_id", ""))
	var deck_variant = payload.get("deck", {})
	if account_id.is_empty() or not (deck_variant is Dictionary):
		_send_to_peer(peer_id, LobbyProtocolScript.BOT_DECK_SUBMISSION_RESULT, {
			"success": false, "message": "Sign in and provide a bot deck before submitting.", "bot": {},
		})
		return
	var deck: Dictionary = deck_variant
	var cards_variant = deck.get("cards", {})
	var special_variant = deck.get("special_setup", {})
	var reinforcements_variant = deck.get("reinforcements", {})
	if not cards_variant is Dictionary or not special_variant is Dictionary or not reinforcements_variant is Dictionary:
		_send_to_peer(peer_id, LobbyProtocolScript.BOT_DECK_SUBMISSION_RESULT, {
			"success": false, "message": "The submitted bot deck has invalid card data.", "bot": {},
		})
		return
	var cards: Dictionary = cards_variant
	var special_setup: Dictionary = special_variant
	var reinforcements: Dictionary = reinforcements_variant
	var validation: Dictionary = DeckValidatorScript.new().validate_deck(cards, special_setup, reinforcements)
	if not bool(validation.get("is_valid", false)):
		_send_to_peer(peer_id, LobbyProtocolScript.BOT_DECK_SUBMISSION_RESULT, {
			"success": false,
			"message": str(validation.get("error", "This deck is not legal for bot matches.")),
			"bot": {},
		})
		return
	var bot_id := "%s_%s" % [account_id.sha256_text().substr(0, 12), _generate_id(12)]
	var bot_name := str(deck.get("name", deck.get("deck_name", ""))).strip_edges().substr(0, 48)
	if bot_name.is_empty():
		bot_name = "Community Bot"
	var owner_name := str(session.get("username", session.get("player_name", "Player"))).strip_edges()
	if owner_name.is_empty():
		owner_name = "Player"
	var god_name := ""
	var catalog_cards := DeckValidatorScript.get_shared_cards_by_name()
	for card_name in validation["cards"]:
		var card: Card = catalog_cards.get(card_name)
		if card != null and card.is_god:
			god_name = card.card_name
			break
	var bot := {
		"bot_id": bot_id,
		"account_id": account_id,
		"owner_name": owner_name,
		"bot_name": bot_name,
		"deck_name": _community_bot_display_name({"bot_name": bot_name, "god_name": god_name}),
		"cards": validation.get("cards", {}),
		"special_setup": validation.get("special_setup", special_setup),
		"reinforcements": validation.get("reinforcements", reinforcements),
		"god_name": god_name,
		"submitted_unix": int(Time.get_unix_time_from_system()),
	}
	var bot_dir := ServerPathsScript.get_server_data_file_path("community_bot_pool")
	DirAccess.make_dir_recursive_absolute(bot_dir)
	var file := FileAccess.open(bot_dir.path_join("%s.json" % bot_id), FileAccess.WRITE)
	if file == null:
		_send_to_peer(peer_id, LobbyProtocolScript.BOT_DECK_SUBMISSION_RESULT, {
			"success": false, "message": "The server could not save this bot.", "bot": {},
		})
		return
	file.store_string(JSON.stringify(bot, "\t"))
	file.flush()
	file.close()
	_invalidate_ladder_cache()
	_send_to_peer(peer_id, LobbyProtocolScript.BOT_DECK_SUBMISSION_RESULT, {
		"success": true, "message": "Bot submitted to the community pool.",
		"bot": _public_bot_entry(bot),
	})

func _handle_request_my_bots(peer_id: int) -> void:
	var session := _get_session_for_peer(peer_id)
	var account_id := str(session.get("account_id", ""))
	var bots: Array[Dictionary] = []
	if not account_id.is_empty():
		var bot_dir := ServerPathsScript.get_server_data_file_path("community_bot_pool")
		var directory := DirAccess.open(bot_dir)
		if directory != null:
			directory.list_dir_begin()
			var file_name := directory.get_next()
			while not file_name.is_empty():
				if not directory.current_is_dir() and file_name.ends_with(".json"):
					var bot := JsonStoreScript.load_dictionary(bot_dir.path_join(file_name), {}, "CommunityBotPool")
					if str(bot.get("account_id", "")) == account_id:
						var entry := _public_bot_entry(bot)
						entry.merge({"cards": bot.get("cards", {}), "special_setup": bot.get("special_setup", {}),
							"reinforcements": bot.get("reinforcements", {}), "bot_list_id": str(bot.get("bot_id", "")),
							"bot_god_name": str(bot.get("god_name", "")), "bot_stars": 0}, true)
						bots.append(entry)
				file_name = directory.get_next()
			directory.list_dir_end()
	_send_to_peer(peer_id, LobbyProtocolScript.MY_BOTS, {"bots": bots})

func _handle_delete_bot(peer_id: int, payload: Dictionary) -> void:
	var session := _get_session_for_peer(peer_id)
	var account_id := str(session.get("account_id", ""))
	var bot_id := str(payload.get("bot_id", "")).strip_edges()
	if account_id.is_empty() or bot_id.is_empty() or bot_id.contains("/") or bot_id.contains("\\"):
		_send_to_peer(peer_id, LobbyProtocolScript.BOT_DELETED, {
			"success": false, "message": "Could not delete that bot.", "bot_id": bot_id,
		})
		return
	var bot_dir := ServerPathsScript.get_server_data_file_path("community_bot_pool")
	var bot_path := bot_dir.path_join("%s.json" % bot_id)
	var bot := JsonStoreScript.load_dictionary(bot_path, {}, "CommunityBotPool")
	if bot.is_empty() or str(bot.get("account_id", "")) != account_id:
		_send_to_peer(peer_id, LobbyProtocolScript.BOT_DELETED, {
			"success": false, "message": "That bot does not exist or is not yours.", "bot_id": bot_id,
		})
		return
	var directory := DirAccess.open(bot_dir)
	if directory == null or directory.remove("%s.json" % bot_id) != OK:
		_send_to_peer(peer_id, LobbyProtocolScript.BOT_DELETED, {
			"success": false, "message": "The server could not delete that bot.", "bot_id": bot_id,
		})
		return
	# Expunge the deleted bot's record from the ranked bot ladder so it no
	# longer appears in standings or recent bot activity.
	_clear_ladder_caches()
	_refresh_ranked_bot_deck_pool()
	_send_to_peer(peer_id, LobbyProtocolScript.BOT_DELETED, {
		"success": true, "message": "Bot deleted from the community pool.", "bot_id": bot_id,
	})

## Quarantine is a reversible flag on the submitter's own bot: the submission
## stays on disk (and in the ladder) but the ranked pool stops pairing it into
## matches. Only the account that submitted the bot may change this flag.
func _handle_quarantine_bot(peer_id: int, payload: Dictionary) -> void:
	var session := _get_session_for_peer(peer_id)
	var account_id := str(session.get("account_id", ""))
	var bot_id := str(payload.get("bot_id", "")).strip_edges()
	var quarantined := bool(payload.get("quarantined", true))
	if account_id.is_empty() or bot_id.is_empty() or bot_id.contains("/") or bot_id.contains("\\"):
		_send_to_peer(peer_id, LobbyProtocolScript.BOT_QUARANTINED, {
			"success": false, "message": "Could not update that bot.", "bot_id": bot_id, "quarantined": quarantined,
		})
		return
	var bot_dir := ServerPathsScript.get_server_data_file_path("community_bot_pool")
	var bot_path := bot_dir.path_join("%s.json" % bot_id)
	var bot := JsonStoreScript.load_dictionary(bot_path, {}, "CommunityBotPool")
	if bot.is_empty() or str(bot.get("account_id", "")) != account_id:
		_send_to_peer(peer_id, LobbyProtocolScript.BOT_QUARANTINED, {
			"success": false, "message": "That bot does not exist or is not yours.", "bot_id": bot_id, "quarantined": quarantined,
		})
		return
	bot["quarantined"] = quarantined
	bot["quarantined_unix"] = int(Time.get_unix_time_from_system()) if quarantined else 0
	if not JsonStoreScript.save_json(bot_path, bot, "CommunityBotPool"):
		_send_to_peer(peer_id, LobbyProtocolScript.BOT_QUARANTINED, {
			"success": false, "message": "The server could not update that bot.", "bot_id": bot_id, "quarantined": quarantined,
		})
		return
	_clear_ladder_caches()
	_refresh_ranked_bot_deck_pool()
	_send_to_peer(peer_id, LobbyProtocolScript.BOT_QUARANTINED, {
		"success": true,
		"message": "Bot quarantined. It stays in the pool but will not be paired into matches." if quarantined \
			else "Bot released from quarantine and returned to matchmaking.",
		"bot_id": bot_id,
		"quarantined": quarantined,
	})

func _handle_report_bot_work_started(peer_id: int, payload: Dictionary) -> void:
	var session := _get_session_for_peer(peer_id)
	var job_id := str(payload.get("job_id", "")).strip_edges()
	var job: Dictionary = _client_bot_jobs.get(job_id, {})
	if job.is_empty() or session.is_empty() \
			or str(job.get("account_id", "")) != str(session.get("account_id", "")) \
			or int(job.get("expires_unix", 0)) < Time.get_unix_time_from_system():
		return
	var was_running := str(job.get("status", "")) == "running"
	if not was_running:
		job["started_unix"] = int(Time.get_unix_time_from_system())
	if str(job.get("session_id", "")).is_empty():
		job["session_id"] = str(session.get("session_id", ""))
	job["status"] = "running"
	# Hosts piggyback the match's current turn count on each lease heartbeat so
	# the live list can show how far each game has progressed.
	if payload.has("turn_count"):
		job["turn_count"] = clampi(int(payload.get("turn_count", 0)), 0, 9999)
	var heartbeat_unix := int(Time.get_unix_time_from_system())
	job["heartbeat_unix"] = heartbeat_unix
	job["expires_unix"] = heartbeat_unix + 90
	_client_bot_jobs[job_id] = job
	if not was_running:
		_broadcast_bot_match_history()

func _expire_client_bot_jobs() -> void:
	var now_unix := int(Time.get_unix_time_from_system())
	var expired: Array[String] = []
	for job_id_variant in _client_bot_jobs.keys():
		var job_id := str(job_id_variant)
		var job: Dictionary = _client_bot_jobs.get(job_id, {})
		var heartbeat_unix := int(job.get("heartbeat_unix", job.get("started_unix", 0)))
		var stalled_running_job := str(job.get("status", "")) == "running" \
			and heartbeat_unix > 0 \
			and now_unix - heartbeat_unix >= 90
		if int(job.get("expires_unix", 0)) <= now_unix or stalled_running_job:
			expired.append(job_id)
	if expired.is_empty():
		return
	for job_id in expired:
		_client_bot_jobs.erase(job_id)
	_broadcast_bot_match_history()

func _cancel_client_bot_jobs_for_session(session_id: String) -> void:
	var resolved_session_id := session_id.strip_edges()
	if resolved_session_id.is_empty():
		return
	var cancelled: Array[String] = []
	for job_id_variant in _client_bot_jobs.keys():
		var job_id := str(job_id_variant)
		var job: Dictionary = _client_bot_jobs.get(job_id, {})
		if str(job.get("session_id", "")) == resolved_session_id:
			cancelled.append(job_id)
	if cancelled.is_empty():
		return
	for job_id in cancelled:
		_client_bot_jobs.erase(job_id)
	_broadcast_bot_match_history()

func _handle_cancel_bot_work(peer_id: int, payload: Dictionary) -> void:
	var session := _get_session_for_peer(peer_id)
	var job_id := str(payload.get("job_id", "")).strip_edges()
	var job: Dictionary = _client_bot_jobs.get(job_id, {})
	if job.is_empty() or session.is_empty() \
			or str(job.get("account_id", "")) != str(session.get("account_id", "")):
		return
	_client_bot_jobs.erase(job_id)
	_broadcast_bot_match_history()

func _get_live_bot_work_matches() -> Array[Dictionary]:
	var matches: Array[Dictionary] = []
	var now_unix := int(Time.get_unix_time_from_system())
	for job_id in _client_bot_jobs:
		var job: Dictionary = _client_bot_jobs[job_id]
		if str(job.get("status", "")) != "running" or int(job.get("expires_unix", 0)) < now_unix:
			continue
		var first: Dictionary = job.get("deck_a", {})
		var second: Dictionary = job.get("deck_b", {})
		if first.is_empty() or second.is_empty():
			continue
		var first_stars := int(first.get("stars", 0))
		var second_stars := int(second.get("stars", 0))
		var first_league := int(RankedProgressionScript.summarize_bot_stars(first_stars)["league"])
		var second_league := int(RankedProgressionScript.summarize_bot_stars(second_stars)["league"])
		matches.append({
			"match_id": "volunteer_%s" % str(job_id),
			"best_of": 3 if int(job.get("best_of", 1)) == 3 else 1,
			"played_unix": int(job.get("started_unix", now_unix)),
			"status": "live",
			"turn_count": maxi(0, int(job.get("turn_count", 0))),
			"players": [
				{"name": str(first.get("deck_name", "Bot")), "result": "pending", "stars": first_stars,
					"rank": str(RankedProgressionScript.summarize_bot_stars(first_stars)["name"])},
				{"name": str(second.get("deck_name", "Bot")), "result": "pending", "stars": second_stars,
					"rank": str(RankedProgressionScript.summarize_bot_stars(second_stars)["name"])},
			],
			# Sort keys: higher-ranked matchups list first regardless of when
			# they started. Stripped before the page is sent.
			"_league_high": maxi(first_league, second_league),
			"_league_low": mini(first_league, second_league),
			"_stars_high": maxi(first_stars, second_stars),
			"_stars_low": mini(first_stars, second_stars),
		})
	matches.sort_custom(_compare_live_bot_match_rank)
	for entry in matches:
		entry.erase("_league_high")
		entry.erase("_league_low")
		entry.erase("_stars_high")
		entry.erase("_stars_low")
	return matches

## Live bot match ordering: highest-ranked matchup first, then the weaker half
## of the matchup, then star counts, with start time only breaking ties.
func _compare_live_bot_match_rank(a: Dictionary, b: Dictionary) -> bool:
	for key in ["_league_high", "_league_low", "_stars_high", "_stars_low"]:
		var a_value := int(a.get(key, -1))
		var b_value := int(b.get(key, -1))
		if a_value != b_value:
			return a_value > b_value
	return int(a.get("played_unix", 0)) > int(b.get("played_unix", 0))

func _broadcast_bot_match_history() -> void:
	var now_msec := Time.get_ticks_msec()
	if now_msec - _bot_history_broadcast_last_msec >= _BOT_HISTORY_BROADCAST_MIN_INTERVAL_MSEC:
		_bot_history_broadcast_last_msec = now_msec
		_do_broadcast_bot_match_history()
	else:
		_bot_history_broadcast_pending = true
		call_deferred("_flush_pending_bot_history_broadcast")

func _flush_pending_bot_history_broadcast() -> void:
	if not _bot_history_broadcast_pending:
		return
	_bot_history_broadcast_pending = false
	_bot_history_broadcast_last_msec = Time.get_ticks_msec()
	_do_broadcast_bot_match_history()

func _do_broadcast_bot_match_history() -> void:
	# Building the page can refresh the bot pools and rebuild the ladder, so do
	# not pay for any of that when nobody is signed in to receive it. Clients
	# request their first page via REQUEST_BOT_MATCH_HISTORY on join.
	if not _has_signed_in_peer():
		return
	var started_msec := Time.get_ticks_msec()
	var page: Dictionary = match_history_store.get_recent_bot_matches(50)
	page["before_match_id"] = ""
	page["live_matches"] = _get_live_bot_work_matches()
	page["activities"] = _get_recent_match_activity_notifications()
	for raw_peer_id in session_id_by_peer.keys():
		var peer_id := int(raw_peer_id)
		var session := _get_session_for_peer(peer_id)
		if not str(session.get("account_id", "")).is_empty():
			_send_to_peer(peer_id, LobbyProtocolScript.BOT_MATCH_HISTORY, page)
	_log_slow_path("bot history broadcast", started_msec)

func _has_signed_in_peer() -> bool:
	for raw_peer_id in session_id_by_peer.keys():
		var session := _get_session_for_peer(int(raw_peer_id))
		if not str(session.get("account_id", "")).is_empty():
			return true
	return false

var _slow_path_log_next_msec: Dictionary = {}

func _log_slow_path(label: String, started_msec: int, detail: String = "") -> void:
	var elapsed_msec := Time.get_ticks_msec() - started_msec
	if elapsed_msec < _SLOW_PATH_LOG_THRESHOLD_MSEC:
		return
	var now_msec := Time.get_ticks_msec()
	if now_msec < int(_slow_path_log_next_msec.get(label, 0)):
		return
	_slow_path_log_next_msec[label] = now_msec + _SLOW_PATH_LOG_INTERVAL_MSEC
	var suffix := "" if detail.is_empty() else " (%s)" % detail
	push_warning("Slow server path: %s took %d ms%s." % [label, elapsed_msec, suffix])

func _get_recent_match_activity_notifications() -> Array[Dictionary]:
	_refresh_ranked_bot_deck_pool()
	var eliminated_ids := _ranked_bot_deck_pool.get_eliminated_bot_match_ids()
	for match_id in _ranked_bot_deck_pool_bo3.get_eliminated_bot_match_ids():
		eliminated_ids[match_id] = true
	var activities: Array[Dictionary] = match_history_store.get_recent_match_activities(
		12,
		eliminated_ids
	)
	if activities.is_empty():
		return activities
	var ladder_bo1 := _get_cached_ladder()
	var place_lookup_bo1 := _build_ladder_place_lookup(ladder_bo1)
	var ladder_bo3: Array[Dictionary] = []
	var place_lookup_bo3: Dictionary = {}
	for activity: Dictionary in activities:
		var best_of := int(activity.get("best_of", 1))
		var ladder: Array[Dictionary] = ladder_bo1
		var place_lookup: Dictionary = place_lookup_bo1
		if best_of == 3:
			if ladder_bo3.is_empty():
				ladder_bo3 = _build_full_ladder_for_best_of(3)
				place_lookup_bo3 = _build_ladder_place_lookup(ladder_bo3)
			ladder = ladder_bo3
			place_lookup = place_lookup_bo3
		var list_id := str(activity.get("winner_bot_list_id", ""))
		var account_id := str(activity.get("winner_account_id", ""))
		var before_points := int(activity.get("winner_before_points", -1))
		var after_points := int(activity.get("winner_after_points", -1))
		if (list_id.is_empty() and account_id.is_empty()) or before_points < 0 or after_points < 0:
			continue
		# O(1) winner lookup instead of scanning the ladder per activity.
		var winner_key := list_id if not list_id.is_empty() else account_id
		var current_place := int(place_lookup.get(winner_key, -1))
		var current_points := -1
		if current_place >= 0:
			current_points = int(ladder[current_place].get("points", -1))
		var is_player := not account_id.is_empty()
		var notification_depth := PLAYER_LADDER_NOTIFICATION_DEPTH if is_player else LADDER_NOTIFICATION_DEPTH
		if current_place < 0 or current_place >= notification_depth or current_points != after_points:
			continue
		var previous_place := 0
		var winner_entry: Dictionary = ladder[current_place]
		var winner_name := str(winner_entry.get("name", ""))
		var winner_games := int(winner_entry.get("wins", 0)) + int(winner_entry.get("losses", 0))
		var winner_score := int(winner_entry.get("wins", 0)) * winner_games
		for index in range(ladder.size()):
			if index == current_place:
				continue
			var other: Dictionary = ladder[index]
			var other_points := int(other.get("points", 0))
			if other_points > before_points:
				previous_place += 1
			elif other_points == before_points:
				var other_games := int(other.get("wins", 0)) + int(other.get("losses", 0))
				var other_score := int(other.get("wins", 0)) * other_games
				if other_score > winner_score:
					previous_place += 1
				elif other_score == winner_score and str(other.get("name", "")).nocasecmp_to(winner_name) < 0:
					previous_place += 1
		var rank_update := _ladder_rank_update(previous_place, current_place, notification_depth)
		if not rank_update.is_empty():
			activity["ladder_update"] = rank_update
	for activity: Dictionary in activities:
		activity.erase("winner_account_id")
		activity.erase("winner_bot_list_id")
		activity.erase("winner_before_points")
		activity.erase("winner_after_points")
	return activities

## Maps each ladder row's bot list id (and human account id) to its ladder
## position, so activity notifications can find winners without scanning the
## full ladder once per activity.
func _build_ladder_place_lookup(ladder: Array[Dictionary]) -> Dictionary:
	var lookup := {}
	for index in range(ladder.size()):
		var row: Dictionary = ladder[index]
		var list_id := str(row.get("list_id", ""))
		if not list_id.is_empty():
			lookup[list_id] = index
		var account_id := str(row.get("account_id", ""))
		if not account_id.is_empty():
			lookup[account_id] = index
	return lookup

## Rank-change phrase for a recent ranked result. Human winners are tracked
## deeper than bots, and every move inside the top ten is reported rather than
## only crossing a ten-place band.
func _ladder_rank_update(previous_place: int, current_place: int, notification_depth: int) -> String:
	var current_number := current_place + 1
	var previous_number := previous_place + 1
	var rank_update := ""
	var band := notification_depth - 10
	while band >= TOP_TEN_NOTIFICATION_DEPTH:
		if previous_place >= band and current_place < band:
			rank_update = "enters the top %d" % band
		band -= 10
	if rank_update.is_empty() and previous_place >= notification_depth and current_place < notification_depth:
		rank_update = "enters the top %d" % notification_depth
	if not rank_update.is_empty():
		return "%s at position #%d" % [rank_update, current_number]
	if current_place < TOP_TEN_NOTIFICATION_DEPTH or previous_place < TOP_TEN_NOTIFICATION_DEPTH:
		if previous_place == current_place:
			return ""
		if current_place < previous_place:
			return "climbs from #%d to #%d" % [previous_number, current_number]
		return "drops from #%d to #%d" % [previous_number, current_number]
	return ""

func _handle_submit_bot_work_result(peer_id: int, payload: Dictionary) -> void:
	var job_id := str(payload.get("job_id", "")).strip_edges()
	var job: Dictionary = _client_bot_jobs.get(job_id, {})
	var session := _get_session_for_peer(peer_id)
	var accepted := false
	var success_message := "Bot match added to the shared ladder."
	var is_evaluation_match := bool(job.get("new_bot_evaluation", false))
	if not job.is_empty() and not session.is_empty() \
			and str(job.get("account_id", "")) == str(session.get("account_id", "")) \
			and int(job.get("expires_unix", 0)) >= Time.get_unix_time_from_system():
		var first: Dictionary = job["deck_a"]
		var second: Dictionary = job["deck_b"]
		var winner_index := int(payload.get("winner_index", -1))
		if is_evaluation_match:
			accepted = _record_new_rubric_bot_result(
				int(job.get("best_of", 1)), first, second, winner_index
			)
			success_message = "New rubric bot match recorded in the debug batch."
		else:
			var first_id := "%s%s" % [BOT_SESSION_PREFIX, _generate_id(10)]
			var second_id := "%s%s" % [BOT_SESSION_PREFIX, _generate_id(10)]
			var player_ids: Array[String] = [first_id, second_id]
			var decks := {first_id: first, second_id: second}
			var identities := {
				first_id: {"is_bot": true, "player_name": first["deck_name"]},
				second_id: {"is_bot": true, "player_name": second["deck_name"]},
			}
			var match_id := "volunteer_%s" % job_id
			var match_session := MatchSessionScript.new(match_id, match_id, "127.0.0.1", 0, player_ids, decks, identities)
			match_session.is_ranked = true
			match_session.configure_series_format(int(job.get("best_of", 1)))
			var result: Dictionary = match_history_store.record_completed_match(
				match_session,
				winner_index,
				1 - winner_index,
				str(first["god_name"]) if winner_index == 0 else str(second["god_name"]),
				str(second["god_name"]) if winner_index == 0 else str(first["god_name"]),
				{"turns": clampi(int(payload.get("turns", 1)), 1, 1000)}
			)
			accepted = bool(result.get("success", false))
		if accepted:
			_client_bot_jobs.erase(job_id)
			if not is_evaluation_match:
				_invalidate_ladder_cache()
	_send_to_peer(peer_id, LobbyProtocolScript.BOT_WORK_RESULT, {
		"job_id": job_id,
		"success": accepted,
		"message": success_message if accepted else "Bot match could not be recorded.",
	})
	if accepted and not is_evaluation_match:
		_broadcast_room_lists()
		_broadcast_bot_match_history()

func _handle_request_bot_ladder(peer_id: int, message_type: String, payload: Dictionary) -> void:
	var session := _get_session_for_peer(peer_id)
	if str(session.get("account_id", "")).is_empty():
		_send_error_to_peer(peer_id, "Sign in to view the ladder.")
		return
	var quarantined_only := bool(payload.get("quarantined_only", false))
	if quarantined_only and not _is_admin_account(session):
		_send_error_to_peer(peer_id, "Only admins can view quarantined bots.")
		return
	_ensure_match_history_store()
	if message_type == LobbyProtocolScript.REQUEST_BOT_RECORD:
		_refresh_ranked_bot_deck_pool()
		var list_id: String = payload["list_id"]
		var best_of := int(payload.get("best_of", 1))
		var cursor: String = payload.get("before_match_id", "")
		var available := not _bot_pool(best_of).get_deck_details(list_id, quarantined_only).is_empty()
		var record: Dictionary = match_history_store.get_ranked_bot_record_page(list_id, best_of, 50, cursor, cursor.is_empty()) if available else {}
		record["available"] = available
		record["request_id"] = payload["request_id"]
		_send_to_peer(peer_id, LobbyProtocolScript.BOT_RECORD, record)
		return
	if message_type == LobbyProtocolScript.REQUEST_BOT_DECK:
		_refresh_ranked_bot_deck_pool()
		var list_id: String = payload["list_id"]
		var best_of := 3 if int(payload.get("best_of", 1)) == 3 else 1
		_ensure_server_bot_deck_factory()
		var deck_details := _bot_pool(best_of).get_deck_details(list_id, quarantined_only)
		var completed_deck: Dictionary = server_bot_deck_factory.complete_ranked_power_slots(deck_details)
		if not completed_deck.is_empty():
			completed_deck.merge({
				"wins": int(deck_details.get("wins", 0)),
				"losses": int(deck_details.get("losses", 0)),
				"draws": int(deck_details.get("draws", 0)),
				"stars": int(deck_details.get("stars", 0)),
			}, false)
			deck_details = completed_deck
		_send_to_peer(peer_id, LobbyProtocolScript.BOT_DECK, {
			"list_id": list_id,
			"deck": deck_details,
		})
		return
	var ladder_username := str(session.get("username", "")).strip_edges()
	_send_to_peer(peer_id, LobbyProtocolScript.BOT_LADDER, _build_ladder_page(payload, ladder_username))

func _get_cached_ladder(best_of: int = 1) -> Array[Dictionary]:
	var is_bo3 := int(best_of) == 3
	var format := 3 if is_bo3 else 1
	var cache: Array[Dictionary] = _ladder_cache_bo3 if is_bo3 else _ladder_cache
	var dirty: bool = _ladder_cache_bo3_dirty if is_bo3 else _ladder_cache_dirty
	var last_build_msec: int = _ladder_cache_bo3_last_build_msec if is_bo3 else _ladder_cache_last_build_msec
	var now_msec := Time.get_ticks_msec()
	if cache.is_empty() or (dirty and now_msec - last_build_msec >= LADDER_CACHE_MIN_REBUILD_INTERVAL_MSEC):
		cache = _build_full_ladder_for_best_of(format)
		if is_bo3:
			_ladder_cache_bo3 = cache
			_ladder_cache_bo3_dirty = false
			_ladder_cache_bo3_last_build_msec = now_msec
		else:
			_ladder_cache = cache
			_ladder_cache_dirty = false
			_ladder_cache_last_build_msec = now_msec
	return cache

func _get_top_50_bot_list_ids(best_of: int = 1) -> Dictionary:
	var list_ids := {}
	for row in _get_cached_ladder(best_of):
		if not bool(row.get("is_bot", false)):
			continue
		var list_id := str(row.get("list_id", ""))
		if list_id.is_empty() or bool(row.get("matchmaking_excluded", false)):
			continue
		list_ids[list_id] = true
		if list_ids.size() == TOP_BOT_HOSTING_LIMIT:
			break
	return list_ids

# Complement of the top-bot pool: every matchmaking-eligible bot ranked below
# the first TOP_BOT_HOSTING_LIMIT bots on the ladder.
func _get_bots_below_top_50_list_ids(best_of: int = 1) -> Dictionary:
	var top_ids := _get_top_50_bot_list_ids(best_of)
	var list_ids := {}
	for row in _get_cached_ladder(best_of):
		if not bool(row.get("is_bot", false)):
			continue
		var list_id := str(row.get("list_id", ""))
		if list_id.is_empty() or bool(row.get("matchmaking_excluded", false)):
			continue
		if not top_ids.has(list_id):
			list_ids[list_id] = true
	return list_ids

# Every matchmaking-eligible ladder bot whose main god matches the requested
# name. Used by debug god-specific bot hosting.
func _get_bot_list_ids_for_god(god_name: String, best_of: int = 1) -> Dictionary:
	var list_ids := {}
	if god_name.is_empty():
		return list_ids
	for row in _get_cached_ladder(best_of):
		if not bool(row.get("is_bot", false)):
			continue
		var list_id := str(row.get("list_id", ""))
		if list_id.is_empty() or bool(row.get("matchmaking_excluded", false)):
			continue
		var main_gods: Array = row.get("main_gods", [])
		if main_gods.has(god_name):
			list_ids[list_id] = true
	return list_ids

func _build_ladder_page(request: Dictionary, current_username: String = "") -> Dictionary:
	var is_paged := request.has("request_id")
	var quarantined_only := bool(request.get("quarantined_only", false))
	var best_of := int(request.get("best_of", 1)) if is_paged else 1
	# Bo1 and Bo3 each have their own cached full ladder. Other best_of values
	# are rare admin queries — always compute those fresh.
	var ladder: Array[Dictionary]
	if quarantined_only:
		ladder = _build_quarantined_bot_ladder(best_of)
	elif best_of == 1 or best_of == 3:
		# Deep-duplicate so per-request mutations (can_delete, filtering) don't
		# corrupt the cache for other callers.
		ladder = []
		for row in _get_cached_ladder(best_of):
			ladder.append(row.duplicate(true))
	else:
		ladder = _build_full_ladder_for_best_of(best_of)
	# Annotate can_delete per request (depends on who is asking).
	var trimmed_username := current_username.strip_edges()
	for row in ladder:
		var bot_owner := str(row.get("owner_name", "")).strip_edges()
		var owns_bot := not bot_owner.is_empty() and bot_owner == trimmed_username
		row["can_delete"] = not quarantined_only and owns_bot
		row["can_quarantine"] = not quarantined_only and owns_bot
	var player_type := LobbyProtocolScript.LADDER_FILTER_BOTS if quarantined_only \
		else str(request.get("player_type", LobbyProtocolScript.LADDER_FILTER_EVERYONE))
	if player_type == LobbyProtocolScript.LADDER_FILTER_PLAYERS or player_type == LobbyProtocolScript.LADDER_FILTER_BOTS:
		# Filter before paging so one type's standings compact into consecutive
		# pages while rows keep their overall ladder positions.
		var bots_only := player_type == LobbyProtocolScript.LADDER_FILTER_BOTS
		var typed_rows: Array[Dictionary] = []
		for row in ladder:
			if bool(row.get("is_bot", false)) == bots_only:
				typed_rows.append(row)
		ladder = typed_rows
	var search_query := str(request.get("search_query", "")).strip_edges().to_lower()
	if not search_query.is_empty():
		var matching_rows: Array[Dictionary] = []
		for row in ladder:
			if str(row.get("name", "")).to_lower().contains(search_query) \
					or str(row.get("owner_name", "")).to_lower().contains(search_query):
				matching_rows.append(row)
		ladder = matching_rows
	if search_query.is_empty() and player_type == LobbyProtocolScript.LADDER_FILTER_EVERYONE and ladder.size() > 100:
		ladder.resize(100)
	if not is_paged:
		return {"ladder": _public_ladder_rows(ladder, best_of), "supports_bot_records": true}
	var last_page := maxi(0, ceili(float(ladder.size()) / LobbyProtocolScript.LADDER_PAGE_SIZE) - 1)
	var page := mini(int(request.get("page", 0)), last_page)
	var start := page * LobbyProtocolScript.LADDER_PAGE_SIZE
	return {
		"ladder": _public_ladder_rows(ladder.slice(start, start + LobbyProtocolScript.LADDER_PAGE_SIZE), best_of),
		"supports_bot_records": true,
		"request_id": request.get("request_id", 0),
		"page": page,
		"last_page": last_page,
	}

func _build_quarantined_bot_ladder(best_of: int = 1) -> Array[Dictionary]:
	_refresh_ranked_bot_deck_pool()
	var ladder: Array[Dictionary] = []
	for bot in _bot_pool(best_of).get_quarantined_ladder_summary():
		var row := _build_bot_ladder_row(bot, str(bot["god_name"]))
		row["quarantine_status"] = bot["quarantine_status"]
		ladder.append(row)
	ladder.sort_custom(_is_higher_ladder_row)
	for index in range(ladder.size()):
		ladder[index]["ladder_position"] = index + 1
	return ladder

# Expensive: builds the full sorted ladder with humans + bots for the requested
# format. Each format draws bots from its own pool.
func _build_full_ladder() -> Array[Dictionary]:
	return _build_full_ladder_for_best_of(1)

func _build_full_ladder_for_best_of(best_of: int) -> Array[Dictionary]:
	var started_msec := Time.get_ticks_msec()
	var format := 3 if int(best_of) == 3 else 1
	var ladder: Array[Dictionary] = match_history_store.get_human_ladder(account_store.get_ladder_usernames(), format)
	_refresh_ranked_bot_deck_pool()
	var bot_pool := _bot_pool(format)
	var seen_bot_ids: Dictionary = {}
	var seen_owner_fps: Dictionary = {}
	for god: Dictionary in bot_pool.get_ladder_summary()["gods"]:
		var lists: Array = god["lists"].duplicate()
		if not god["challenger"].is_empty():
			lists.append(god["challenger"])
		for bot: Dictionary in lists:
			var bot_id_str := str(bot.get("list_id", "")).strip_edges()
			if not bot_id_str.is_empty() and seen_bot_ids.has(bot_id_str):
				continue
			var bot_owner_name := str(bot.get("owner_name", "")).strip_edges()
			if not bot_owner_name.is_empty():
				var bot_fp := _owner_bot_fingerprint(bot_pool, bot_id_str)
				var owner_key := "%s:%s" % [bot_owner_name, bot_fp]
				if seen_owner_fps.has(owner_key):
					continue
				seen_owner_fps[owner_key] = true
			if not bot_id_str.is_empty():
				seen_bot_ids[bot_id_str] = true
			ladder.append(_build_bot_ladder_row(bot, str(god.get("god_name", ""))))
	ladder.sort_custom(_is_higher_ladder_row)
	var unique_ladder: Array[Dictionary] = []
	var seen_display_names: Dictionary = {}
	for row in ladder:
		var display_name := str(row.get("name", "")).strip_edges().to_lower()
		if not display_name.is_empty() and seen_display_names.has(display_name):
			continue
		if not display_name.is_empty():
			seen_display_names[display_name] = true
		unique_ladder.append(row)
	ladder = unique_ladder
	for index in range(ladder.size()):
		ladder[index]["ladder_position"] = index + 1
	# Decorate once per rebuild so every request (and peer) reuses the cached
	# rows' portraits and recent matches instead of recomputing them.
	_decorate_ladder_rows(ladder, format)
	_log_slow_path("ladder rebuild", started_msec, "%d rows" % ladder.size())
	return ladder

## Stable content fingerprint for an owned bot's deck. Hashing the full deck is
## expensive, so results are cached until the next pool refresh (community syncs
## and adoptions are the only ways owned deck content changes).
func _owner_bot_fingerprint(bot_pool: RankedBotDeckPoolScript, list_id: String) -> String:
	var cached := str(_bot_deck_fingerprints_by_list_id.get(list_id, ""))
	if not cached.is_empty():
		return cached
	var bot_deck := bot_pool.get_deck_details(list_id)
	var fingerprint := JSON.stringify([bot_deck.get("cards", {}), bot_deck.get("reinforcements", {}), bot_deck.get("special_setup", {})]).sha256_text()
	_bot_deck_fingerprints_by_list_id[list_id] = fingerprint
	return fingerprint

func _build_bot_ladder_row(bot: Dictionary, god_name: String) -> Dictionary:
	var rank := RankedProgressionScript.summarize_bot_stars(int(bot["stars"]))
	return {
		"name": bot["name"],
		"list_id": str(bot.get("list_id", "")).strip_edges(),
		"points": bot["stars"],
		"rank": rank["name"],
		"league": int(rank["league"]),
		"stars": rank["stars"],
		"is_bot": true,
		"owner_name": str(bot.get("owner_name", "")).strip_edges(),
		"can_delete": false,
		"can_quarantine": false,
		"matchmaking_excluded": bool(bot.get("matchmaking_excluded", false)),
		"wins": int(bot.get("wins", 0)),
		"losses": int(bot.get("losses", 0)),
		"draws": int(bot.get("draws", 0)),
		"main_gods": [god_name],
	}

func _is_higher_ladder_row(a: Dictionary, b: Dictionary) -> bool:
	if int(a["points"]) != int(b["points"]):
		return int(a["points"]) > int(b["points"])
	var a_wins := int(a.get("wins", 0))
	var b_wins := int(b.get("wins", 0))
	var a_games := a_wins + int(a.get("losses", 0))
	var b_games := b_wins + int(b.get("losses", 0))
	var a_record_score := a_wins * b_games
	var b_record_score := b_wins * a_games
	if a_record_score != b_record_score:
		return a_record_score > b_record_score
	return a["name"].nocasecmp_to(b["name"]) < 0

func _decorate_ladder_rows(rows: Array[Dictionary], best_of: int = 1) -> void:
	for row in rows:
		if bool(row.get("is_bot", false)):
			var list_id := str(row.get("list_id", ""))
			if not row.has("portrait"):
				var league := int(row.get("league", 0))
				var bot_deck := _bot_pool(best_of).get_deck_details(list_id, row.has("quarantine_status"))
				row["portrait"] = RankBadgeCatalog.portrait_from_deck(
					league,
					bot_deck.get("cards", {}),
					bot_deck.get("reinforcements", {})
				)
			if not row.has("recent_matches"):
				row["recent_matches"] = match_history_store.get_recent_ranked_bot_matches_for_list(list_id, 10, false, best_of)

func _public_ladder_rows(rows: Array[Dictionary], best_of: int = 1) -> Array[Dictionary]:
	_decorate_ladder_rows(rows, best_of)
	# Rows are references into the cached ladder array, so strip private fields
	# from per-request copies. Mutating the cached rows themselves would erase
	# account ids that activity notifications still need.
	var public_rows: Array[Dictionary] = []
	for row in rows:
		var public_row: Dictionary = row.duplicate()
		var account_id := str(public_row.get("account_id", ""))
		public_row.erase("account_id")
		if not account_id.is_empty():
			var portrait := _get_public_rank_portrait(account_id, public_row["rank"])
			if not portrait.is_empty():
				public_row["portrait"] = portrait
		public_rows.append(public_row)
	return public_rows

func _handle_request_friends(peer_id: int) -> void:
	var session: Dictionary = _get_session_for_peer(peer_id)
	if session.is_empty():
		_send_error_to_peer(peer_id, "Join the lobby before requesting friends.")
		return
	var account_id := str(session.get("account_id", "")).strip_edges()
	if account_id.is_empty():
		_send_error_to_peer(peer_id, "Log into an account before using friends.")
		return
	_send_friends_state_to_account(account_id)

func _handle_send_friend_request(peer_id: int, payload: Dictionary) -> void:
	var session: Dictionary = _get_session_for_peer(peer_id)
	if session.is_empty():
		_send_error_to_peer(peer_id, "Join the lobby before adding friends.")
		return
	var account_id := str(session.get("account_id", "")).strip_edges()
	if account_id.is_empty():
		_send_error_to_peer(peer_id, "Log into an account before adding friends.")
		return
	_ensure_account_store()
	_ensure_friend_store()
	if account_store == null or friend_store == null:
		_send_error_to_peer(peer_id, "Friend storage is unavailable.")
		return
	var recipient_account: Dictionary = account_store.get_account_by_username(str(payload.get("username", "")))
	var recipient_account_id := str(recipient_account.get("account_id", "")).strip_edges()
	if recipient_account_id.is_empty():
		_send_error_to_peer(peer_id, "That account username was not found. Friends only works with registered accounts.")
		return
	var result: Dictionary = friend_store.send_friend_request(account_id, recipient_account_id)
	if not bool(result.get("success", false)):
		_send_error_to_peer(peer_id, str(result.get("message", "Could not send that friend request.")))
		return
	_send_friends_state_to_account(account_id)
	_send_friends_state_to_account(recipient_account_id)

func _handle_respond_friend_request(peer_id: int, payload: Dictionary) -> void:
	var session: Dictionary = _get_session_for_peer(peer_id)
	if session.is_empty():
		_send_error_to_peer(peer_id, "Join the lobby before responding to friends.")
		return
	var account_id := str(session.get("account_id", "")).strip_edges()
	if account_id.is_empty():
		_send_error_to_peer(peer_id, "Log into an account before responding to friends.")
		return
	_ensure_friend_store()
	if friend_store == null:
		_send_error_to_peer(peer_id, "Friend storage is unavailable.")
		return
	var result: Dictionary = friend_store.respond_to_friend_request(
		account_id,
		str(payload.get("request_id", "")),
		bool(payload.get("accept", false))
	)
	if not bool(result.get("success", false)):
		_send_error_to_peer(peer_id, str(result.get("message", "Could not update that friend request.")))
		return
	var entry: Dictionary = result.get("entry", {})
	_send_friends_state_to_account(str(entry.get("requester_account_id", "")).strip_edges())
	_send_friends_state_to_account(str(entry.get("recipient_account_id", "")).strip_edges())

func _handle_send_deck_to_friend(peer_id: int, payload: Dictionary) -> void:
	var session: Dictionary = _get_session_for_peer(peer_id)
	if session.is_empty():
		_send_error_to_peer(peer_id, "Join the lobby before sending decks.")
		return
	var account_id := str(session.get("account_id", "")).strip_edges()
	if account_id.is_empty():
		_send_error_to_peer(peer_id, "Log into an account before sending decks.")
		return
	_ensure_account_store()
	_ensure_friend_store()
	if account_store == null or friend_store == null:
		_send_error_to_peer(peer_id, "Friend storage is unavailable.")
		return
	var recipient_account: Dictionary = account_store.get_account_by_username(str(payload.get("username", "")))
	var recipient_account_id := str(recipient_account.get("account_id", "")).strip_edges()
	if recipient_account_id.is_empty():
		_send_error_to_peer(peer_id, "That account username was not found. Friends only works with registered accounts.")
		return
	var result: Dictionary = friend_store.send_deck_share(
		account_id,
		recipient_account_id,
		str(payload.get("deck_name", "")),
		payload.get("cards", {}),
		payload.get("special_setup", {}),
		payload.get("reinforcements", {})
	)
	if not bool(result.get("success", false)):
		_send_error_to_peer(peer_id, str(result.get("message", "Could not send that deck.")))
		return
	_send_friends_state_to_account(account_id)
	_send_friends_state_to_account(recipient_account_id)

func _handle_respond_deck_share(peer_id: int, payload: Dictionary) -> void:
	var session: Dictionary = _get_session_for_peer(peer_id)
	if session.is_empty():
		_send_error_to_peer(peer_id, "Join the lobby before responding to deck shares.")
		return
	var account_id := str(session.get("account_id", "")).strip_edges()
	if account_id.is_empty():
		_send_error_to_peer(peer_id, "Log into an account before responding to deck shares.")
		return
	_ensure_friend_store()
	_ensure_deck_store()
	if friend_store == null or deck_store == null:
		_send_error_to_peer(peer_id, "Deck sharing storage is unavailable.")
		return
	var result: Dictionary = friend_store.respond_to_deck_share(
		account_id,
		str(payload.get("share_id", "")),
		bool(payload.get("accept", false)),
		deck_store
	)
	if not bool(result.get("success", false)):
		_send_error_to_peer(peer_id, str(result.get("message", "Could not update that deck share.")))
		return
	var saved_deck: Dictionary = result.get("deck", {})
	if not saved_deck.is_empty():
		_send_to_peer(peer_id, LobbyProtocolScript.ACCOUNT_DECK_SAVED, {"deck": saved_deck})
	var entry: Dictionary = result.get("entry", {})
	_send_friends_state_to_account(str(entry.get("sender_account_id", "")).strip_edges())
	_send_friends_state_to_account(str(entry.get("recipient_account_id", "")).strip_edges())

func _create_session(
	player_name: String,
	peer_id: int,
	is_local: bool,
	profile_id: String = "",
	account_id: String = "",
	email: String = "",
	username: String = "",
	auth_mode: String = LobbyProtocolScript.LOGIN_ACCOUNT,
	accepts_game_updates: bool = false
) -> Dictionary:
	var clean_name: String = player_name.strip_edges()
	if clean_name.is_empty():
		clean_name = "Guest"

	var session_id: String = _generate_id(12)
	while sessions_by_id.has(session_id):
		session_id = _generate_id(12)

	var reconnect_token: String = _generate_id(18)
	var session := {
		"session_id": session_id,
		"profile_id": profile_id.strip_edges(),
		"account_id": account_id.strip_edges(),
		"email": email.strip_edges(),
		"reconnect_token": reconnect_token,
		"player_name": clean_name,
		"username": username.strip_edges(),
		"auth_mode": auth_mode,
		"accepts_game_updates": accepts_game_updates,
		"peer_id": peer_id,
		"connected": true,
		"room_disconnected_since_unix": 0,
		"is_local": is_local,
	}
	sessions_by_id[session_id] = session
	if peer_id > 0 and not is_local:
		session_id_by_peer[peer_id] = session_id
	return session

func _find_resumable_session(profile_id: String, account_id: String) -> Dictionary:
	var resolved_profile_id := profile_id.strip_edges()
	var resolved_account_id := account_id.strip_edges()
	var best_match: Dictionary = {}
	var best_score := -1
	for session_id_variant in sessions_by_id.keys():
		var session_id := str(session_id_variant).strip_edges()
		if session_id.is_empty():
			continue
		var existing = sessions_by_id.get(session_id, {})
		if not (existing is Dictionary):
			continue
		var session := existing as Dictionary
		if bool(session.get("is_local", false)):
			continue
		var score := _get_resumable_session_score(session, resolved_profile_id, resolved_account_id)
		if score < 0:
			continue
		if bool(session.get("connected", false)):
			# Abruptly closed clients can remain marked connected until ENet times out.
			# An authenticated account login must still reclaim its active match.
			if resolved_account_id.is_empty() or _build_active_match_info_for_session(session_id).is_empty():
				continue
			score += 1000
		if score <= best_score:
			continue
		best_score = score
		best_match = session.duplicate(true)
	return best_match

func _get_resumable_session_score(session: Dictionary, profile_id: String, account_id: String) -> int:
	if session.is_empty():
		return -1
	var session_profile_id := str(session.get("profile_id", "")).strip_edges()
	var session_account_id := str(session.get("account_id", "")).strip_edges()
	var session_id := str(session.get("session_id", "")).strip_edges()
	var identity_score := -1
	if not account_id.is_empty():
		if session_account_id != account_id:
			return -1
		identity_score = 100
	elif not profile_id.is_empty():
		if session_profile_id != profile_id:
			return -1
		identity_score = 50
	else:
		return -1
	if not _build_active_match_info_for_session(session_id).is_empty():
		return identity_score + 20
	if not str(room_id_by_session.get(session_id, "")).strip_edges().is_empty():
		return identity_score + 10
	return identity_score

func _get_matching_participant_session_id(session_id: String, participant_session_ids: Array) -> String:
	var session: Dictionary = sessions_by_id.get(session_id, {})
	if session.is_empty():
		return ""
	var account_id := str(session.get("account_id", "")).strip_edges()
	var profile_id := str(session.get("profile_id", "")).strip_edges()
	if account_id.is_empty() and profile_id.is_empty():
		return ""
	for participant_session_id_variant in participant_session_ids:
		var participant_session_id := str(participant_session_id_variant).strip_edges()
		if participant_session_id.is_empty():
			continue
		var participant: Dictionary = sessions_by_id.get(participant_session_id, {})
		if participant.is_empty():
			continue
		if not account_id.is_empty() and str(participant.get("account_id", "")).strip_edges() == account_id:
			return participant_session_id
		if account_id.is_empty() \
			and not profile_id.is_empty() \
			and str(participant.get("profile_id", "")).strip_edges() == profile_id:
			return participant_session_id
	return ""

func _reclaim_session_for_peer(
	session: Dictionary,
	peer_id: int,
	player_name: String,
	profile_id: String,
	account_id: String,
	email: String,
	username: String,
	auth_mode: String,
	accepts_game_updates: bool = false
) -> Dictionary:
	if session.is_empty():
		return {}
	var session_id := str(session.get("session_id", "")).strip_edges()
	if session_id.is_empty():
		return {}
	var previous_peer_id := int(session.get("peer_id", 0))
	if previous_peer_id > 0:
		session_id_by_peer.erase(previous_peer_id)
	session["player_name"] = player_name
	session["profile_id"] = profile_id
	session["account_id"] = account_id
	session["email"] = email
	session["username"] = username
	session["auth_mode"] = auth_mode
	session["accepts_game_updates"] = accepts_game_updates
	session["peer_id"] = peer_id
	session["connected"] = true
	session["room_disconnected_since_unix"] = 0
	sessions_by_id[session_id] = session
	if peer_id > 0:
		session_id_by_peer[peer_id] = session_id
	return session.duplicate(true)

func _create_room_for_session(session_id: String, is_ranked: bool = true, best_of: int = 1) -> LobbyRoom:
	var existing_room_id: String = str(room_id_by_session.get(session_id, ""))
	if not existing_room_id.is_empty() and rooms_by_id.has(existing_room_id):
		var existing_room: LobbyRoom = rooms_by_id[existing_room_id]
		if existing_room.status == LobbyRoomScript.STATUS_IN_MATCH:
			_send_error_to_session(session_id, "Finish or forfeit your active match before creating a new seek.")
		return existing_room
	_prune_excess_open_seeks_for_session(session_id)

	var room_id: String = _generate_room_code()
	while rooms_by_id.has(room_id):
		room_id = _generate_room_code()

	var room: LobbyRoom = LobbyRoomScript.new(room_id, session_id)
	room.is_ranked = is_ranked
	room.best_of = 3 if best_of == 3 else 1
	room.add_member(session_id)
	rooms_by_id[room_id] = room
	room_id_by_session[session_id] = room_id
	_emit_room_updates(room)
	return room

func _ensure_server_bot_seeks() -> void:
	if not is_listening or not server_bots_enabled or not use_dedicated_match_processes:
		return
	var open_formats := {}
	for room_variant in rooms_by_id.values():
		var room := room_variant as LobbyRoom
		if _is_available_server_bot_seek(room):
			open_formats["%s|%d" % [room.is_ranked, room.best_of]] = true
	for ranked in [true, false]:
		for best_of in [1, 3]:
			var format_key := "%s|%d" % [ranked, best_of]
			if not open_formats.has(format_key):
				_create_server_bot_seek(ranked, best_of)

func _create_server_bot_seek(ranked: bool, best_of: int = 1) -> LobbyRoom:
	_ensure_deck_validator()
	_ensure_server_bot_deck_factory()
	if deck_validator == null or server_bot_deck_factory == null:
		return null
	var bot_session_id := _create_server_bot_session()
	if bot_session_id.is_empty():
		return null
	var deck_submission := _build_fresh_bot_deck_submission({}, best_of)
	if deck_submission.is_empty():
		_remove_server_bot_session(bot_session_id)
		return null
	var room := _create_room_for_session(bot_session_id, ranked, best_of)
	if room == null:
		_remove_server_bot_session(bot_session_id)
		return null
	_apply_server_bot_deck(room, deck_submission)
	_emit_room_updates(room)
	return room

func _apply_server_bot_deck(room: LobbyRoom, deck_submission: Dictionary, bot_session_id: String = "") -> void:
	if bot_session_id.is_empty():
		bot_session_id = room.host_session_id
	if not room.submit_deck(
		bot_session_id,
		str(deck_submission.get("deck_name", "Practice Bot")),
		str(deck_submission["list_id"]),
		deck_submission.get("cards", {}),
		deck_submission.get("validation", {}),
		deck_submission.get("special_setup", {}),
		deck_submission.get("reinforcements", {})
	):
		return
	room.deck_submission_by_session_id[bot_session_id]["bot_list_id"] = str(deck_submission.get("bot_list_id", deck_submission["list_id"]))
	room.deck_submission_by_session_id[bot_session_id]["bot_god_name"] = str(deck_submission.get("bot_god_name", deck_submission["god_name"]))
	room.deck_submission_by_session_id[bot_session_id]["bot_stars"] = int(deck_submission.get("stars", 0))
	room.deck_submission_by_session_id[bot_session_id]["bot_win_streak"] = int(deck_submission.get("win_streak", 0))
	room.deck_submission_by_session_id[bot_session_id]["bot_name"] = str(deck_submission.get("bot_name", deck_submission.get("deck_name", "")))
	room.deck_submission_by_session_id[bot_session_id]["owner_name"] = str(deck_submission.get("owner_name", "")).strip_edges()
	room.deck_submission_by_session_id[bot_session_id]["is_community_bot"] = bool(deck_submission.get("is_community_bot", false))
	sessions_by_id[bot_session_id]["player_name"] = deck_submission["deck_name"]
	sessions_by_id[bot_session_id]["username"] = deck_submission["deck_name"]
	room.set_ready(bot_session_id, true)

func _create_server_bot_session() -> String:
	var session_id := "%s%s" % [BOT_SESSION_PREFIX, _generate_id(9)]
	while sessions_by_id.has(session_id):
		session_id = "%s%s" % [BOT_SESSION_PREFIX, _generate_id(9)]
	sessions_by_id[session_id] = {
		"session_id": session_id,
		"profile_id": "",
		"account_id": "",
		"email": "",
		"reconnect_token": "",
		"player_name": "Bot",
		"username": "Bot",
		"auth_mode": SERVER_BOT_AUTH_MODE,
		"peer_id": 0,
		"connected": true,
		"room_disconnected_since_unix": 0,
		"is_local": false,
		"is_bot": true,
		"bot_type": SERVER_BOT_TYPE_FUZZ,
	}
	return session_id

func _match_server_bot_to_player(room: LobbyRoom) -> bool:
	var opponent_id := room.members[1]
	var account_id := str(sessions_by_id.get(opponent_id, {}).get("account_id", ""))
	if not account_id.is_empty():
		var matched := _find_rank_matched_bot_deck(room.best_of, account_id, room.is_ranked)
		if not matched.is_empty():
			_apply_server_bot_deck(room, matched)
			return true
	var existing := room.get_deck_submission(room.host_session_id)
	if str(existing.get("bot_list_id", "")).is_empty():
		return not existing.is_empty()
	var fresh := _build_fresh_bot_deck_submission({}, room.best_of)
	if fresh.is_empty():
		return false
	_apply_server_bot_deck(room, fresh)
	return true

func _find_rank_matched_bot_deck(best_of: int, account_id: String, is_ranked: bool = true) -> Dictionary:
	_ensure_match_history_store()
	_refresh_ranked_bot_deck_pool()
	var progress: Dictionary = match_history_store.get_current_ranked_progress(account_id, best_of)
	var target_stars := int(progress.get("points", 0))
	var rank := RankedProgressionScript.summarize_bot_stars(target_stars)
	var league := int(rank["league"])
	var post_loss: bool = is_ranked and league <= 1 and match_history_store.should_serve_quarantined_next(account_id)
	# Iron V always uses this pool in ranked bot challenges. Other Iron and
	# Bronze divisions use it once after a qualifying loss.
	var force_quarantined: bool = is_ranked and (rank["name"] == "Iron V" or post_loss)
	var unavailable := _busy_bot_list_ids()
	var bot_pool := _bot_pool(best_of)
	var deck := bot_pool.select_deck(unavailable, _bot_deck_rng, target_stars, force_quarantined)
	var attempt := 0
	while not deck.is_empty():
		attempt += 1
		var list_id := str(deck.get("list_id", ""))
		var deck_stars := int(deck.get("stars", 0))
		var deck_name := str(deck.get("deck_name", ""))
		var submission := _validate_server_bot_deck(deck)
		if not submission.is_empty():
			if post_loss:
				match_history_store.set_serve_quarantined_next(account_id, false)
			print("[BotMatchmaker] account=%s best_of=%d target_stars=%d league=%d(%s) force_quarantined=%s -> matched list_id=%s stars=%d name=%s (attempt %d)" % [
				account_id, best_of, target_stars, league, RankedProgressionScript.LEAGUES[league] if league < RankedProgressionScript.LEAGUES.size() else "?", force_quarantined, list_id, deck_stars, deck_name, attempt
			])
			return submission
		print("[BotMatchmaker] account=%s best_of=%d target_stars=%d league=%d(%s) force_quarantined=%s -> rejected list_id=%s stars=%d name=%s (attempt %d), retrying" % [
			account_id, best_of, target_stars, league, RankedProgressionScript.LEAGUES[league] if league < RankedProgressionScript.LEAGUES.size() else "?", force_quarantined, list_id, deck_stars, deck_name, attempt
		])
		unavailable[deck["list_id"]] = true
		deck = bot_pool.select_deck(unavailable, _bot_deck_rng, target_stars, force_quarantined)
	print("[BotMatchmaker] account=%s best_of=%d target_stars=%d league=%d(%s) force_quarantined=%s -> no bot available after %d attempts" % [
		account_id, best_of, target_stars, league, RankedProgressionScript.LEAGUES[league] if league < RankedProgressionScript.LEAGUES.size() else "?", force_quarantined, attempt
	])
	return {}

# Seeds a bot league: builds `count_per_god` ranked-legal bot decks for every
# ranked god and registers them in the ranked bot deck pool as tournament lists.
# The lists are exempt from early retirement so they can finish their round-robin.
# Actual games are then run by the existing bot self-play / volunteer workers,
# which record results into match history; the pool replays them into records.
func seed_bot_league(count_per_god: int = 10, best_of: int = 1) -> Dictionary:
	_ensure_match_history_store()
	_ensure_server_bot_deck_factory()
	_refresh_ranked_bot_deck_pool()
	if server_bot_deck_factory == null:
		return {"success": false, "message": "Bot deck factory is unavailable."}
	var format := 3 if int(best_of) == 3 else 1
	var bot_pool := _bot_pool(format)
	var god_names: Array[String] = server_bot_deck_factory.get_ranked_god_names()
	god_names.sort()
	var seeded: Dictionary = {}
	var base_seed := int(Time.get_unix_time_from_system())
	for god_name in god_names:
		var list_ids: Array = []
		for i in range(count_per_god):
			var deck: Dictionary = {}
			var attempt := 0
			while attempt < 32:
				var seed_value := base_seed + i * 1000 + attempt
				deck = server_bot_deck_factory.build_random_deck(seed_value, str(god_name), true)
				attempt += 1
				if not deck.is_empty() and not deck.get("cards", {}).is_empty():
					break
				deck = {}
			if deck.is_empty():
				continue
			var list_id := bot_pool.register_league_list(str(god_name), deck)
			if not list_id.is_empty():
				list_ids.append(list_id)
		seeded[str(god_name)] = {"list_ids": list_ids.duplicate(), "count": list_ids.size()}
	_invalidate_ladder_cache()
	return {"success": true, "gods": seeded, "count_per_god": count_per_god}

# Finalizes the seeded bot league. Keeps the strongest seeded bot of each god as
# the active ladder bot, quarantines the weakest seeded bot of each god as a
# forced-matchmaking bad bot (for Iron V and post-loss Iron/Bronze pairing), and
# removes every other seeded bot.
func finalize_bot_league(best_of: int = 1) -> Dictionary:
	_ensure_match_history_store()
	_ensure_server_bot_deck_factory()
	_refresh_ranked_bot_deck_pool()
	var bot_pool := _bot_pool(best_of)
	var god_names: Array[String] = server_bot_deck_factory.get_ranked_god_names()
	var summary := bot_pool.finalize_league(god_names)
	bot_pool.set_league_mode(false)
	_invalidate_ladder_cache()
	return {"success": true, "summary": summary}

func get_bot_league_status(best_of: int = 1) -> Dictionary:
	_refresh_ranked_bot_deck_pool()
	return _bot_pool(best_of).get_league_status()

# Schedules a round robin where every league bot plays `matches_per_bot` matches
# against randomly chosen opponents. Pairings are stored and served to volunteer
# bot workers through the existing request_bot_work flow, so matches are played
# and recorded through the normal match-history pipeline.
func run_league_round_robin(matches_per_bot: int = 50, best_of: int = 1) -> Dictionary:
	_ensure_match_history_store()
	_ensure_server_bot_deck_factory()
	_refresh_ranked_bot_deck_pool()
	if server_bot_deck_factory == null:
		return {"success": false, "message": "Bot deck factory is unavailable."}
	var format := 3 if int(best_of) == 3 else 1
	var bot_pool := _bot_pool(format)
	var god_names: Array[String] = server_bot_deck_factory.get_ranked_god_names()
	var all_bots: Array = []
	for god_name in god_names:
		var pool: Dictionary = bot_pool._by_god.get(str(god_name), {})
		if pool.is_empty():
			continue
		for list in pool.get("lists", []):
			if bool(list.get("league_list", false)):
				all_bots.append(list.duplicate(true))
	if all_bots.is_empty():
		return {"success": false, "message": "No league bots found. Seed the bot league first."}
	var pairings: Array = []
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	var match_counts: Dictionary = {}
	for bot in all_bots:
		match_counts[str(bot.get("list_id", ""))] = 0
	for bot in all_bots:
		var bot_id := str(bot.get("list_id", ""))
		var attempts := 0
		while int(match_counts.get(bot_id, 0)) < matches_per_bot and attempts < matches_per_bot * 10:
			attempts += 1
			var opponent: Dictionary = all_bots[rng.randi_range(0, all_bots.size() - 1)]
			var opponent_id := str(opponent.get("list_id", ""))
			if opponent_id == bot_id:
				continue
			if int(match_counts.get(opponent_id, 0)) >= matches_per_bot:
				continue
			pairings.append({
				"deck_a": bot.duplicate(true),
				"deck_b": opponent.duplicate(true),
				"best_of": format,
			})
			match_counts[bot_id] = int(match_counts.get(bot_id, 0)) + 1
			match_counts[opponent_id] = int(match_counts.get(opponent_id, 0)) + 1
	# Keep any pending pairings for the other format so a round-robin rebuild
	# for one ladder cannot silently cancel the other ladder's scheduled games.
	var retained_pairings: Array = []
	for existing in _pending_league_pairings:
		if int(existing.get("best_of", 1)) != format:
			retained_pairings.append(existing)
	retained_pairings.append_array(pairings)
	_pending_league_pairings = retained_pairings
	_invalidate_ladder_cache()
	return {"success": true, "total_matches": pairings.size(), "matches_per_bot": matches_per_bot, "bot_count": all_bots.size()}

func _busy_bot_list_ids() -> Dictionary:
	var busy := {}
	for room: LobbyRoom in rooms_by_id.values():
		if room.status != LobbyRoomScript.STATUS_IN_MATCH:
			continue
		for session_id in room.members:
			if not _is_server_bot_session(session_id):
				continue
			var list_id := str(room.get_deck_submission(session_id).get("bot_list_id", ""))
			if not list_id.is_empty():
				busy[list_id] = true
	return busy

# --- Debug rubric bot batches -------------------------------------------------
# These batches are deliberately kept out of the ranked pools: the debug button
# is for evaluating the current deck-building rubrics, not for changing ladder
# records. Each batch lives in memory on the lobby and is replaced once every
# bot in it has reached NEW_BOT_BATCH_GAME_LIMIT games.

func _get_new_rubric_bot_batch(best_of: int) -> Dictionary:
	var format := 3 if int(best_of) == 3 else 1
	if not _new_rubric_bot_batches.has(format):
		_new_rubric_bot_batches[format] = {
			"serial": 0,
			"decks": {},
			"records": {},
		}
	return _new_rubric_bot_batches[format]

func _generate_new_rubric_bot_batch(best_of: int, minimum_new_bots: int = NEW_BOT_BATCH_SIZE) -> void:
	_ensure_deck_validator()
	_ensure_server_bot_deck_factory()
	if server_bot_deck_factory == null:
		return
	var god_names: Array[String] = server_bot_deck_factory.get_ranked_god_names()
	god_names.sort()
	if god_names.is_empty():
		return
	var format := 3 if int(best_of) == 3 else 1
	var batch := _get_new_rubric_bot_batch(format)
	var serial := int(batch.get("serial", 0)) + 1
	# Append instead of replacing: a result from a match still in flight must
	# still find its bot when the new batch has already been generated.
	var decks: Dictionary = batch.get("decks", {})
	var records: Dictionary = batch.get("records", {})
	var base_seed := int(Time.get_unix_time_from_system()) + serial * 100000
	var generated := 0
	var index := 0
	while generated < minimum_new_bots and index < minimum_new_bots * 8:
		var god_name := str(god_names[index % god_names.size()])
		var deck: Dictionary = {}
		for attempt in range(32):
			deck = server_bot_deck_factory.build_random_deck(
				base_seed + index * 1000 + attempt, god_name, true
			)
			if not deck.is_empty() and not (deck.get("cards", {}) as Dictionary).is_empty():
				break
			deck = {}
		index += 1
		if deck.is_empty():
			continue
		var validated := _validate_server_bot_deck(deck)
		if validated.is_empty():
			continue
		var list_id := "newrubric_%d_%d" % [serial, index]
		var bot_name := "%s New Bot %d-%d" % [
			RankedBotDeckPoolScript.display_god_name(god_name), serial, index
		]
		validated["list_id"] = list_id
		validated["bot_list_id"] = list_id
		validated["deck_name"] = bot_name
		validated["bot_name"] = bot_name
		validated["bot_god_name"] = god_name
		validated["bot_stars"] = 0
		validated["bot_win_streak"] = 0
		decks[list_id] = validated
		records[list_id] = {"wins": 0, "losses": 0, "draws": 0, "games": 0}
		generated += 1
	batch["serial"] = serial
	batch["decks"] = decks
	batch["records"] = records
	print("[New Bot Batch] generated %d rubric bots (serial %d, best_of %d)" % [generated, serial, format])

func _ensure_new_rubric_bot_batch(best_of: int) -> void:
	var batch := _get_new_rubric_bot_batch(best_of)
	var decks: Dictionary = batch.get("decks", {})
	if decks.size() < 2:
		_generate_new_rubric_bot_batch(best_of, maxi(2, 2 - decks.size()))

func _select_new_rubric_bot_pair(busy: Dictionary, best_of: int) -> Array[Dictionary]:
	_ensure_new_rubric_bot_batch(best_of)
	var format := 3 if int(best_of) == 3 else 1
	var batch := _get_new_rubric_bot_batch(format)
	var decks: Dictionary = batch.get("decks", {})
	var records: Dictionary = batch.get("records", {})
	var eligible: Array[String] = []
	for raw_id in decks.keys():
		var list_id := str(raw_id)
		if busy.has(list_id):
			continue
		var record: Dictionary = records.get(list_id, {})
		if int(record.get("games", 0)) >= NEW_BOT_BATCH_GAME_LIMIT:
			continue
		eligible.append(list_id)
	if eligible.size() < 2:
		# Everything left in the batch is busy or finished: add fresh rubric
		# bots without dropping records for matches that are still in flight.
		_generate_new_rubric_bot_batch(format, maxi(2, 3 - eligible.size()))
		batch = _get_new_rubric_bot_batch(format)
		decks = batch.get("decks", {})
		records = batch.get("records", {})
		eligible.clear()
		for raw_id in decks.keys():
			var list_id := str(raw_id)
			if busy.has(list_id):
				continue
			var record: Dictionary = records.get(list_id, {})
			if int(record.get("games", 0)) >= NEW_BOT_BATCH_GAME_LIMIT:
				continue
			eligible.append(list_id)
	if eligible.size() < 2:
		return []
	eligible.sort_custom(func(first, second) -> bool:
		var first_record: Dictionary = records[first]
		var second_record: Dictionary = records[second]
		return int(first_record.get("games", 0)) < int(second_record.get("games", 0))
	)
	# Prefer the least-played half of the batch, then pick randomly inside it.
	var candidate_count := maxi(2, mini(eligible.size(), maxi(2, eligible.size() / 2)))
	var first_index := _bot_deck_rng.randi_range(0, candidate_count - 1)
	var first_id := eligible[first_index]
	eligible.remove_at(first_index)
	var second_id := eligible[_bot_deck_rng.randi_range(0, eligible.size() - 1)]
	return [
		(decks[first_id] as Dictionary).duplicate(true),
		(decks[second_id] as Dictionary).duplicate(true),
	]

func _record_new_rubric_bot_result(
	best_of: int, first: Dictionary, second: Dictionary, winner_index: int
) -> bool:
	var format := 3 if int(best_of) == 3 else 1
	var batch := _get_new_rubric_bot_batch(format)
	var records: Dictionary = batch.get("records", {})
	var first_id := str(first.get("bot_list_id", first.get("list_id", "")))
	var second_id := str(second.get("bot_list_id", second.get("list_id", "")))
	if first_id.is_empty() or second_id.is_empty() or first_id == second_id:
		return false
	if not records.has(first_id) or not records.has(second_id):
		return false
	var first_record: Dictionary = records[first_id]
	var second_record: Dictionary = records[second_id]
	if winner_index == 0:
		first_record["wins"] = int(first_record.get("wins", 0)) + 1
		second_record["losses"] = int(second_record.get("losses", 0)) + 1
	elif winner_index == 1:
		second_record["wins"] = int(second_record.get("wins", 0)) + 1
		first_record["losses"] = int(first_record.get("losses", 0)) + 1
	else:
		first_record["draws"] = int(first_record.get("draws", 0)) + 1
		second_record["draws"] = int(second_record.get("draws", 0)) + 1
	for record in [first_record, second_record]:
		record["games"] = int(record.get("wins", 0)) \
			+ int(record.get("losses", 0)) + int(record.get("draws", 0))
	print("[New Bot Batch] recorded match: %s vs %s (serial %d, best_of %d)" % [
		first_id, second_id, int(batch.get("serial", 0)), format
	])
	return true

func _build_fresh_bot_deck_submission(extra_reserved: Dictionary = {}, best_of: int = 1, forced_god_name: String = "") -> Dictionary:
	_ensure_server_bot_deck_factory()
	_refresh_ranked_bot_deck_pool()
	_server_bot_seed_counter += 1
	var deck_seed := int(Time.get_unix_time_from_system()) + _server_bot_seed_counter
	if not forced_god_name.is_empty():
		# Debug god-specific hosting needs a deck of exactly this god, not the
		# underrepresented-god preference used for regular fresh bots.
		var forced_deck: Dictionary = server_bot_deck_factory.build_random_deck(deck_seed, forced_god_name, true)
		return _validate_server_bot_deck(forced_deck)
	var reserved := _get_reserved_fresh_bot_god_counts()
	for god_name in extra_reserved:
		reserved[god_name] = int(reserved.get(god_name, 0)) + int(extra_reserved[god_name])
	var preferred_gods := _bot_pool(best_of).rank_underrepresented_gods(
		server_bot_deck_factory.get_ranked_god_names(), _bot_deck_rng, reserved
	)
	for god_name in preferred_gods:
		var preferred_deck: Dictionary = server_bot_deck_factory.build_random_deck(deck_seed, god_name, true)
		var preferred_submission := _validate_server_bot_deck(preferred_deck)
		if not preferred_submission.is_empty():
			return preferred_submission
	var fresh_deck: Dictionary = server_bot_deck_factory.build_random_deck(deck_seed, "", true)
	return _validate_server_bot_deck(fresh_deck)

func _get_reserved_fresh_bot_god_counts() -> Dictionary:
	var reserved := {}
	for room: LobbyRoom in rooms_by_id.values():
		for session_id in room.members:
			if not _is_server_bot_session(session_id):
				continue
			var submission := room.get_deck_submission(session_id)
			if not str(submission.get("bot_list_id", "")).is_empty():
				continue
			var god_name := str(submission.get("bot_god_name", ""))
			if not god_name.is_empty():
				reserved[god_name] = int(reserved.get(god_name, 0)) + 1
	var now_unix := int(Time.get_unix_time_from_system())
	for job: Dictionary in _client_bot_jobs.values():
		if int(job.get("expires_unix", 0)) <= now_unix:
			continue
		for deck_key in ["deck_a", "deck_b"]:
			var deck: Dictionary = job.get(deck_key, {})
			if not str(deck.get("list_id", "")).is_empty():
				continue
			var god_name := str(deck.get("god_name", ""))
			if not god_name.is_empty():
				reserved[god_name] = int(reserved.get(god_name, 0)) + 1
	return reserved

func _validate_server_bot_deck(deck: Dictionary) -> Dictionary:
	if deck.is_empty():
		return {}
	deck = deck.duplicate(true)
	_ensure_server_bot_deck_factory()
	var completed_deck: Dictionary = server_bot_deck_factory.complete_ranked_power_slots(deck)
	if completed_deck.is_empty():
		return {}
	if (completed_deck.get("reinforcements", {}) as Dictionary).is_empty():
		# Community submissions and older bot decks may predate sideboards;
		# derive a deterministic Reinforcement pool so every bot can sideboard
		# in best-of-three series.
		completed_deck["reinforcements"] = server_bot_deck_factory.build_reinforcements_for_deck(
			(completed_deck.get("cards", {}) as Dictionary).duplicate(true),
			str(completed_deck.get("god_name", "")),
			completed_deck.get("special_setup", {}),
			absi(hash(str(completed_deck.get("list_id", completed_deck.get("bot_list_id", ""))) + JSON.stringify(completed_deck.get("cards", {}))))
		)
	var validation: Dictionary = deck_validator.validate_deck(
		completed_deck.get("cards", {}),
		completed_deck.get("special_setup", {}),
		completed_deck.get("reinforcements", {})
	)
	if not bool(validation.get("is_valid", false)):
		return {}
	var validation_cards := _duplicate_dictionary(validation.get("cards", {}))
	var validation_reinforcements := _duplicate_dictionary(validation.get("reinforcements", {}))
	var validation_special_setup := _duplicate_dictionary(validation.get("special_setup", {}))
	if validation_cards.is_empty():
		return {}
	var god_name: String = str(completed_deck.get("god_name", ""))
	var list_id := str(completed_deck.get("bot_list_id", completed_deck.get("list_id", "")))
	var deck_name := str(completed_deck.get("deck_name", completed_deck.get("name", "")))
	if deck_name.is_empty() or list_id.is_empty():
		deck_name = "%s: Challenger" % RankedBotDeckPoolScript.display_god_name(god_name)
	return {
		"deck_name": deck_name,
		"list_id": list_id,
		"bot_list_id": list_id,
		"god_name": god_name,
		"bot_god_name": god_name,
		"owner_name": str(completed_deck.get("owner_name", "")).strip_edges(),
		"bot_name": str(completed_deck.get("bot_name", "")).strip_edges(),
		"is_community_bot": bool(completed_deck.get("is_community_bot", false)),
		"stars": int(deck.get("stars", 0)),
		"win_streak": int(deck.get("win_streak", 0)),
		"cards": validation_cards,
		"reinforcements": validation_reinforcements,
		"special_setup": validation_special_setup,
		"validation": validation.duplicate(true),
	}

func _ensure_server_bot_deck_factory() -> void:
	if server_bot_deck_factory == null:
		server_bot_deck_factory = PracticeAutofillDeckFactoryScript.new()
	var auditor := Callable(server_bot_deck_factory, "audit_ranked_bot_deck")
	_ranked_bot_deck_pool.set_deck_auditor(auditor)
	_ranked_bot_deck_pool_bo3.set_deck_auditor(auditor)

func _refresh_ranked_bot_deck_pool() -> void:
	if not _pool_dirty:
		return
	var started_msec := Time.get_ticks_msec()
	_pool_dirty = false
	_ensure_match_history_store()
	_ensure_server_bot_deck_factory()
	var is_default_store: bool = not match_history_store.has_method("get_storage_file_name") \
		or match_history_store.get_storage_file_name() == MatchHistoryStoreScript.DEFAULT_STORAGE_FILE_NAME
	var community_bots := _load_community_bots_by_id()
	_update_pool_results_by_format(match_history_store.get_bot_deck_results())
	# Deck content only changes through the pools (community syncs, adoptions),
	# so cached owner fingerprints are valid until the next dirty refresh.
	_bot_deck_fingerprints_by_list_id.clear()
	for best_of in [1, 3]:
		var bot_pool := _bot_pool(best_of)
		if is_default_store and not _pool_state_paths.has(best_of):
			var state_path := ServerPathsScript.get_server_data_file_path(_bot_pool_state_path(best_of))
			_pool_state_paths[best_of] = state_path
			# The saved cursor resumes incrementally across restarts; refresh()
			# validates it against the result stream (count + boundary match id)
			# and full-replays only when the saved state describes a stale or
			# mismatched stream (for example a pre-split combined cursor).
			bot_pool.load_state(state_path)
		bot_pool.sync_community_bots(community_bots)
		var format_results: Array[Dictionary] = _pool_results_by_format[best_of]
		bot_pool.refresh(format_results)
	# Reconcile bot identities across the two format pools so one bot name
	# means the same decklist on both ladders. Bo3 naming collisions yield to
	# Bo1 names, missing identities are mirrored with zeroed records, and the
	# assigned-name maps are unified; records and quarantine stay per-format.
	_ranked_bot_deck_pool.sync_shared_identities(_ranked_bot_deck_pool_bo3, true)
	# Persist only when the replay, community sync, or identity reconciliation
	# actually changed pool state; a refresh triggered by a human result or
	# profile change must not rewrite both format's state files.
	for best_of in [1, 3]:
		var bot_pool := _bot_pool(best_of)
		if is_default_store and bot_pool.needs_save():
			bot_pool.save_state(_pool_state_paths[best_of], (_pool_results_by_format[best_of] as Array[Dictionary]).size())
	_log_slow_path("bot pool refresh", started_msec)

# Splits the bot result stream into per-format buckets incrementally: the full
# history is split exactly once, and only newly recorded results are appended
# afterwards. If the store reordered its history (late-arriving worker
# results), the boundary id no longer matches and the buckets re-split once so
# both ladders stay consistent with finish order — mirroring the same cursor
# validation RankedBotDeckPool.refresh applies to its replay.
func _update_pool_results_by_format(results: Array[Dictionary]) -> void:
	if _pool_results_bucketed_count > results.size() \
			or (_pool_results_bucketed_count > 0 \
			and str(results[_pool_results_bucketed_count - 1].get("match_id", "")) != _pool_results_boundary_id):
		(_pool_results_by_format[1] as Array[Dictionary]).clear()
		(_pool_results_by_format[3] as Array[Dictionary]).clear()
		_pool_results_bucketed_count = 0
	for index in range(_pool_results_bucketed_count, results.size()):
		var result: Dictionary = results[index]
		var format := 3 if int(result.get("best_of", 1)) == 3 else 1
		(_pool_results_by_format[format] as Array[Dictionary]).append(result)
	_pool_results_bucketed_count = results.size()
	_pool_results_boundary_id = str(results.back().get("match_id", "")) if not results.is_empty() else ""

# Community bot submissions change rarely; parsed files are cached keyed on
# name + modification time + size so refreshes skip re-parsing unchanged JSON.
var _community_bot_cache_by_key: Dictionary = {}

func _load_community_bots_by_id() -> Dictionary:
	var bots := {}
	var bot_dir := ServerPathsScript.get_server_data_file_path("community_bot_pool")
	var directory := DirAccess.open(bot_dir)
	if directory == null:
		return bots
	directory.list_dir_begin()
	var file_name := directory.get_next()
	while not file_name.is_empty():
		if not directory.current_is_dir() and file_name.ends_with(".json"):
			var file_path := bot_dir.path_join(file_name)
			var cache_key := ""
			var file := FileAccess.open(file_path, FileAccess.READ)
			if file != null:
				cache_key = "%s|%d|%d" % [file_name, FileAccess.get_modified_time(file_path), file.get_length()]
				file.close()
			var cached: Dictionary = _community_bot_cache_by_key.get(cache_key, {}) if not cache_key.is_empty() else {}
			var bot: Dictionary
			if not cached.is_empty():
				bot = cached.duplicate(true)
			else:
				bot = JsonStoreScript.load_dictionary(file_path, {}, "CommunityBotPool")
				if not bot.is_empty() and not cache_key.is_empty():
					if _community_bot_cache_by_key.size() > 4096:
						_community_bot_cache_by_key.clear()
					_community_bot_cache_by_key[cache_key] = bot.duplicate(true)
			if not bot.is_empty():
				bot["deck_name"] = _community_bot_display_name(bot)
				bots[file_name.get_basename()] = bot
		file_name = directory.get_next()
	directory.list_dir_end()
	return bots

func _duplicate_dictionary(value) -> Dictionary:
	if value is Dictionary:
		return (value as Dictionary).duplicate(true)
	return {}

func _is_available_server_bot_seek(room: LobbyRoom) -> bool:
	if room == null or room.status == LobbyRoomScript.STATUS_IN_MATCH:
		return false
	if room.members.size() != 1:
		return false
	var only_session_id := str(room.members[0]).strip_edges()
	return _is_server_bot_session(only_session_id) \
		and room.host_session_id == only_session_id \
		and room.has_valid_deck(only_session_id) \
		and room.get_ready(only_session_id)

## Rate-limited visibility for why no background bot match is running while the
## lobby is otherwise idle. The dedicated lobby prints these to its log file,
## so an idle-zero state is never silent.
func _log_bot_self_play_block(reason: String) -> void:
	var now_msec := Time.get_ticks_msec()
	if reason == _last_bot_self_play_block_reason and now_msec < _next_bot_self_play_block_log_msec:
		return
	_last_bot_self_play_block_reason = reason
	_next_bot_self_play_block_log_msec = now_msec + int(BOT_SELF_PLAY_BLOCK_LOG_INTERVAL_SECONDS * 1000)
	push_warning("Bot self-play not running: %s" % reason)

func _maintain_bot_self_play() -> void:
	if not server_bots_enabled or not use_dedicated_match_processes or match_supervisor == null:
		return
	if server_bot_self_play_limit <= 0:
		_log_bot_self_play_block("server_bot_self_play_limit is 0 (set OTHERGODS_BOT_SELF_PLAY_LIMIT or bot_self_play_limit= to enable).")
		return
	var background: Array = []
	var foreground := 0
	for match_session in match_supervisor.active_matches.values():
		if match_session.is_bot_self_play():
			background.append(match_session)
		else:
			foreground += 1
	var cpu_budget := maxi(0, OS.get_processor_count() - 1 - foreground)
	var target := mini(server_bot_self_play_limit, BOT_SELF_PLAY_MAX_IDLE_WORKERS) if foreground == 0 else 0
	target = mini(target, cpu_budget)
	var memory := OS.get_memory_info()
	var free_bytes := int(memory.get("free", -1))
	var available_bytes := int(memory.get("available", -1))
	var headroom := free_bytes if free_bytes >= 0 else available_bytes
	if available_bytes >= 0 and headroom >= 0:
		headroom = mini(available_bytes, headroom)
	var overloaded := _lobby_frame_seconds > BOT_SELF_PLAY_FRAME_LIMIT or (headroom >= 0 and headroom < BOT_SELF_PLAY_MEMORY_RESERVE)
	if foreground > 0 and not background.is_empty():
		for worker in background:
			match_supervisor.close_match(worker.match_id, MatchSessionScript.STATUS_ABANDONED, true, "Yielded capacity to a human match.")
		_next_bot_self_play_msec = Time.get_ticks_msec() + BOT_SELF_PLAY_RETRY_SECONDS * 1000
		return
	if not background.is_empty() and (overloaded or background.size() > target):
		var keep_count := 0 if overloaded else target
		for index in range(keep_count, background.size()):
			var worker = background[index]
			match_supervisor.close_match(
				worker.match_id,
				MatchSessionScript.STATUS_ABANDONED,
				true,
				"Yielded excess bot match capacity."
			)
		_next_bot_self_play_msec = Time.get_ticks_msec() + BOT_SELF_PLAY_RETRY_SECONDS * 1000
		return
	if overloaded or background.size() >= target or Time.get_ticks_msec() < _next_bot_self_play_msec:
		if background.is_empty() and foreground == 0 and overloaded:
			if headroom >= 0 and headroom < BOT_SELF_PLAY_MEMORY_RESERVE:
				@warning_ignore("integer_division")
				_log_bot_self_play_block("Memory headroom %d MB is below the 512 MB reserve." % int(headroom / (1024 * 1024)))
			else:
				_log_bot_self_play_block("Lobby frame time %d ms exceeds the %d ms shed threshold." % [
					int(_lobby_frame_seconds * 1000),
					int(BOT_SELF_PLAY_FRAME_LIMIT * 1000),
				])
		return
	# The lobby is idle, below target, and should be launching a worker here;
	# surface whatever is blocking it so an idle-zero state is never silent.
	if cpu_budget <= 0:
		_log_bot_self_play_block("cpu_budget is 0 with %d logical cores reserved for the lobby." % OS.get_processor_count())
		return
	if headroom >= 0 and headroom < BOT_SELF_PLAY_MEMORY_RESERVE + BOT_SELF_PLAY_MEMORY_PER_WORKER:
		@warning_ignore("integer_division")
		_log_bot_self_play_block("Memory headroom %d MB is below the %d MB needed to launch a worker." % [
			int(headroom / (1024 * 1024)),
			int((BOT_SELF_PLAY_MEMORY_RESERVE + BOT_SELF_PLAY_MEMORY_PER_WORKER) / (1024 * 1024)),
		])
		return
	var capacity_blocker: String = match_supervisor.get_background_worker_capacity_blocker()
	if not capacity_blocker.is_empty():
		_log_bot_self_play_block(capacity_blocker)
		return
	# Alternate background self-play between the two bot ladders so both stay populated.
	var next_best_of := 3 if _bot_self_play_format_index % 2 == 1 else 1
	_bot_self_play_format_index += 1
	_launch_bot_self_play(next_best_of)


func _launch_bot_self_play(best_of: int = 1) -> void:
	_refresh_ranked_bot_deck_pool()
	var format := 3 if int(best_of) == 3 else 1
	var pair := _bot_pool(format).select_self_play_pair(_busy_bot_list_ids(), _bot_deck_rng)
	var first := _build_fresh_bot_deck_submission({}, format) if pair.is_empty() else _validate_server_bot_deck(pair[0])
	var second := _build_fresh_bot_deck_submission({str(first.get("god_name", "")): 1}, format) if pair.is_empty() else _validate_server_bot_deck(pair[1])
	if first.is_empty() or second.is_empty() or not RankedBotDeckPoolScript.can_self_play_pair(first, second):
		_log_bot_self_play_block("The ranked bot deck pool produced no valid self-play pair.")
		return
	if first["cards"] == second["cards"] and first["special_setup"] == second["special_setup"]:
		_log_bot_self_play_block("The selected self-play pair decks are identical.")
		return
	# Keep the public name from the first appearance onward, including history.
	for deck in [first, second]:
		if str(deck["list_id"]).is_empty():
			deck["deck_name"] = "%s: %s" % [RankedBotDeckPoolScript.display_god_name(deck["god_name"]), _generate_id(5)]
	var room_id := _generate_room_code()
	while rooms_by_id.has(room_id):
		room_id = _generate_room_code()
	var first_id := _create_server_bot_session()
	var second_id := _create_server_bot_session()
	var room := LobbyRoomScript.new(room_id, first_id)
	room.best_of = format
	room.is_bot_self_play = true
	for bot_id in [first_id, second_id]:
		room.add_member(bot_id)
		room_id_by_session[bot_id] = room_id
	rooms_by_id[room_id] = room
	_apply_server_bot_deck(room, first, first_id)
	_apply_server_bot_deck(room, second, second_id)
	_assign_match(room)
	if room.assigned_match_id.is_empty():
		push_warning("Bot self-play could not start: %s" % match_supervisor.last_create_match_error)
		JsonStoreScript.save_json(ServerPathsScript.get_bot_review_path("launch_" + room_id), {
			"room_id": room_id,
			"closed_unix": Time.get_unix_time_from_system(),
			"status": "launch_failed",
			"names": [first["deck_name"], second["deck_name"]],
			"close_reason": match_supervisor.last_create_match_error,
		}, "BotSelfPlay")
		_close_room(room_id)
		_next_bot_self_play_msec = Time.get_ticks_msec() + BOT_SELF_PLAY_RETRY_SECONDS * 1000

func _room_has_server_bot(room: LobbyRoom) -> bool:
	if room == null:
		return false
	for session_id in room.members:
		if _is_server_bot_session(str(session_id)):
			return true
	return false

func _is_server_bot_session(session_id: String) -> bool:
	var resolved_session_id := session_id.strip_edges()
	if resolved_session_id.is_empty():
		return false
	var session: Dictionary = sessions_by_id.get(resolved_session_id, {})
	return bool(session.get("is_bot", false)) or resolved_session_id.to_upper().begins_with(BOT_SESSION_PREFIX)

func _remove_server_bot_session(session_id: String) -> void:
	var resolved_session_id := session_id.strip_edges()
	if resolved_session_id.is_empty() or not _is_server_bot_session(resolved_session_id):
		return
	room_id_by_session.erase(resolved_session_id)
	sessions_by_id.erase(resolved_session_id)

func _payload_bool(payload: Dictionary, key: String, default_value: bool = false) -> bool:
	if not payload.has(key):
		return default_value
	var value = payload.get(key)
	if value is bool:
		return bool(value)
	if value is int or value is float:
		return int(value) != 0
	var text := str(value).strip_edges().to_lower()
	if text in ["true", "1", "yes", "y", "on", "rated"]:
		return true
	if text in ["false", "0", "no", "n", "off", "unrated"]:
		return false
	return default_value

func _payload_is_ranked(payload: Dictionary) -> bool:
	var format := str(payload.get("match_format", "")).strip_edges().to_lower()
	if not format.is_empty():
		if format.find("unrated") != -1:
			return false
		if format.find("rated") != -1:
			return true
	return _payload_bool(payload, "is_ranked", true)

func _payload_best_of(payload: Dictionary) -> int:
	var format := str(payload.get("match_format", "")).strip_edges().to_lower()
	if format.find("bo3") != -1 or format.find("best_of_3") != -1 or format.find("best-of-3") != -1:
		return 3
	var value = payload.get("best_of", 1)
	if value is int or value is float:
		return 3 if int(value) == 3 else 1
	var text := str(value).strip_edges().to_lower()
	if text in ["3", "bo3", "best_of_3", "best-of-3"]:
		return 3
	return 1

func _join_room_for_session(session_id: String, room_id: String) -> void:
	var normalized_room_id: String = room_id.strip_edges().to_upper()
	if normalized_room_id.is_empty():
		_send_error_to_session(session_id, "Enter a room code first.")
		return
	if not rooms_by_id.has(normalized_room_id):
		_send_error_to_session(session_id, "Room %s was not found." % normalized_room_id)
		return
	var previous_room_id := ""
	if room_id_by_session.has(session_id):
		var current_room_id: String = str(room_id_by_session.get(session_id, ""))
		if current_room_id == normalized_room_id:
			_broadcast_room_snapshot(rooms_by_id[normalized_room_id])
			return
		if rooms_by_id.has(current_room_id):
			var current_room: LobbyRoom = rooms_by_id[current_room_id]
			if current_room.status == LobbyRoomScript.STATUS_IN_MATCH:
				_send_error_to_session(session_id, "Finish or forfeit your active match before joining another seek.")
				return
			previous_room_id = current_room_id
		else:
			room_id_by_session.erase(session_id)

	var room: LobbyRoom = rooms_by_id[normalized_room_id]
	if room.status == LobbyRoomScript.STATUS_IN_MATCH:
		_send_error_to_session(session_id, "Room %s is already in a match." % normalized_room_id)
		return
	if room.is_ranked and _room_has_server_bot(room) and str(sessions_by_id.get(session_id, {}).get("account_id", "")).is_empty():
		_send_error_to_session(session_id, "Sign in to play a rated bot match.")
		return
	if room.is_waiting_for_opponent() and not _room_has_connected_member(room):
		_send_error_to_session(session_id, "Room %s is unavailable until its host reconnects." % normalized_room_id)
		return
	if room.is_full():
		_send_error_to_session(session_id, "Room %s is already full." % normalized_room_id)
		return

	if not room.add_member(session_id):
		_send_error_to_session(session_id, "Unable to join room %s." % normalized_room_id)
		return

	if not previous_room_id.is_empty():
		_leave_non_match_room_for_seek_switch(session_id, previous_room_id)
	room_id_by_session[session_id] = normalized_room_id
	_emit_room_updates(room)
	if _room_has_server_bot(room):
		call_deferred("_ensure_server_bot_seeks")

func _leave_non_match_room_for_seek_switch(session_id: String, room_id: String) -> void:
	if room_id.is_empty():
		return
	if not rooms_by_id.has(room_id):
		if str(room_id_by_session.get(session_id, "")) == room_id:
			room_id_by_session.erase(session_id)
		return
	var room: LobbyRoom = rooms_by_id[room_id]
	if room.status == LobbyRoomScript.STATUS_IN_MATCH:
		return
	room.remove_member(session_id)
	if str(room_id_by_session.get(session_id, "")) == room_id:
		room_id_by_session.erase(session_id)
	if room.is_empty():
		rooms_by_id.erase(room_id)
		_broadcast_room_lists()
		return
	if _is_available_server_bot_seek(room):
		_remove_duplicate_bot_seek(room)
		return
	_emit_room_updates(room)

func _observe_room_for_session(session_id: String, room_id: String) -> void:
	var normalized_room_id: String = room_id.strip_edges().to_upper()
	if normalized_room_id.is_empty():
		_send_error_to_session(session_id, "Enter a room code first.")
		return
	if room_id_by_session.has(session_id):
		var current_room_id := str(room_id_by_session.get(session_id, "")).strip_edges().to_upper()
		if current_room_id != normalized_room_id \
			or not rooms_by_id.has(current_room_id) \
			or rooms_by_id[current_room_id].status != LobbyRoomScript.STATUS_IN_MATCH:
			_send_error_to_session(session_id, "Leave your current seek before observing another match.")
			return
	if not rooms_by_id.has(normalized_room_id):
		_send_error_to_session(session_id, "Room %s was not found." % normalized_room_id)
		return
	var room: LobbyRoom = rooms_by_id[normalized_room_id]
	if room.status != LobbyRoomScript.STATUS_IN_MATCH:
		_send_error_to_session(session_id, "Room %s is not currently in a live match." % normalized_room_id)
		return
	if match_supervisor == null:
		_send_error_to_session(session_id, "Match supervisor is unavailable.")
		return
	var match_id := str(room.assigned_match_id).strip_edges()
	if match_id.is_empty():
		_send_error_to_session(session_id, "That room does not have an active match yet.")
		return
	if _local_bot_matches_by_id.has(match_id):
		_observe_local_bot_match(session_id, match_id)
		return
	if match_supervisor == null:
		_send_error_to_session(session_id, "Match supervisor is unavailable.")
		return
	var match_session = match_supervisor.get_match(match_id)
	if match_session == null:
		_send_error_to_session(session_id, "That live match is no longer available to observe.")
		return
	if match_session.is_dedicated_headless() and not match_supervisor.is_match_ready_for_clients(match_id):
		_send_error_to_session(session_id, "That live match is still starting. Try again in a moment.")
		return
	var participant_session_id := _get_matching_participant_session_id(session_id, match_session.player_session_ids)
	if not participant_session_id.is_empty():
		_send_to_session(session_id, LobbyProtocolScript.MATCH_ASSIGNED, match_session.to_match_info(participant_session_id))
		return
	var visible_player_indices: Array[int] = []
	if room.is_bot_self_play:
		visible_player_indices.assign([0, 1])
	else:
		visible_player_indices = _get_friend_visible_player_indices(session_id, match_session.player_session_ids)
	match_supervisor.set_spectator_visible_player_indices(match_id, session_id, visible_player_indices)
	# For player-hosted matches the authority lives in the host's client, so the
	# host must know the spectator's token before the spectator connects (a
	# join with an unknown token is denied outright).
	if match_session.is_player_host():
		var approved := await _push_spectator_approval_to_host(
			match_id,
			str(match_session.host_session_id),
			session_id,
			match_session.get_spectator_match_token(session_id),
			visible_player_indices
		)
		if not approved:
			_send_error_to_session(session_id, "That live match is not accepting spectators right now.")
			return
	_send_to_session(session_id, LobbyProtocolScript.MATCH_ASSIGNED, match_session.to_spectator_match_info(session_id))

## Broker a spectator into a client-side bot challenge: hand the challenger's
## client the spectator's token and visibility, then point the spectator at
## the challenger's spectate endpoint.
func _observe_local_bot_match(session_id: String, match_id: String) -> void:
	var entry_variant = _local_bot_matches_by_id.get(match_id, null)
	if entry_variant == null or not (entry_variant is Dictionary):
		_send_error_to_session(session_id, "That match is no longer available.")
		return
	var entry: Dictionary = entry_variant
	_spectate_breadcrumb("observe_requested", {
		"observer": session_id, "match": match_id,
		"host": str(entry.get("human_session_id", "")),
	})
	var via_punch := bool(entry.get("spectate_via_punch", false))
	var relay_enabled := bool(entry.get("spectate_relay_enabled", false))
	var spectate_ip := str(entry.get("spectate_ip", "")).strip_edges()
	var spectate_port := int(entry.get("spectate_port", 0))
	var lan_ip := PunchReflectorScript.normalize_ip(str(entry.get("spectate_lan_ip", "")))
	var lan_port := int(entry.get("spectate_lan_port", 0))
	# Keepalive bounces can update the host's public mapping after it first
	# advertised the room. Refresh before rejecting an empty stored endpoint so
	# a late bounce can still make this room watchable.
	if via_punch:
		var host_bounce := _get_punch_bounce("host:%s" % match_id, PUNCH_DISCOVERY_BOUNCE_TTL_SECONDS)
		if not host_bounce.is_empty():
			spectate_ip = PunchReflectorScript.normalize_ip(str(host_bounce.get("ip", spectate_ip)))
			spectate_port = int(host_bounce.get("port", spectate_port))
	if spectate_ip.is_empty() or spectate_port <= 0:
		_send_error_to_session(session_id, "That bot challenge can't be watched live from the host's network.")
		return
	var human_session_id := str(entry.get("human_session_id", ""))
	var bot_session_id := str(entry.get("bot_session_id", ""))
	if session_id == human_session_id:
		_send_error_to_session(session_id, "You are playing in this match.")
		return
	var player_session_ids: Array[String] = [human_session_id, bot_session_id]
	var visible_player_indices := _get_friend_visible_player_indices(session_id, player_session_ids)
	# The bot has no private hand, so its cards are always fair game to watch.
	var bot_index := player_session_ids.find(bot_session_id)
	if bot_index >= 0 and not visible_player_indices.has(bot_index):
		visible_player_indices.append(bot_index)
	visible_player_indices.sort()
	var observer_match_token := _generate_spectator_token()
	var spectator_tokens: Dictionary = entry.get("spectator_match_tokens_by_session", {})
	if not (spectator_tokens is Dictionary):
		spectator_tokens = {}
	spectator_tokens[session_id] = observer_match_token
	entry["spectator_match_tokens_by_session"] = spectator_tokens
	_punch_ready_last_msec_by_key.erase("%s|%s" % [match_id, session_id])
	_spectate_breadcrumb("host_approval_requested", {
		"observer": session_id, "match": match_id, "host": human_session_id,
	})

	var approved := await _push_spectator_approval_to_host(
		match_id, human_session_id, session_id, observer_match_token, visible_player_indices)
	_spectate_breadcrumb("host_approval_result", {
		"observer": session_id, "match": match_id, "approved": str(approved),
	})
	if not approved:
		_send_error_to_session(session_id, "That bot challenge is not accepting spectators right now.")
		return
	# Arm the public UDP relay for cross-NAT spectators. The reflector only
	# forwards packets for sessions the lobby approved, and only between the
	# exact endpoints that already bounced from each side's match socket.
	var via_relay := (via_punch or relay_enabled) and punch_reflector != null and _punch_reflector_port > 0
	if via_relay and punch_reflector.has_method("enable_relay_session"):
		punch_reflector.enable_relay_session(match_id, session_id)
	_spectate_breadcrumb("relay_session_armed", {
		"observer": session_id, "match": match_id,
		"via_punch": str(via_punch), "relay_enabled": str(relay_enabled),
		"via_relay": str(via_relay),
		"public": "%s:%d" % [spectate_ip, spectate_port],
		"lan": "%s:%d" % [lan_ip, lan_port],
	})

	var identities: Dictionary = entry.get("identity_by_session", {})
	if not (identities is Dictionary):
		identities = {}
	var player_names: Array = []
	var rank_badges: Array = []
	for player_session_id in player_session_ids:
		var identity: Dictionary = (identities as Dictionary).get(player_session_id, {})
		player_names.append(str(identity.get("player_name", identity.get("username", "Player"))))
		rank_badges.append(identity.get("rank_badge", {}))
	var bot_submission: Dictionary = (entry.get("decks_by_session", {}) as Dictionary).get(bot_session_id, {})
	if not (bot_submission is Dictionary):
		bot_submission = {}
	# Build bot_player_stars as an array (human=-1, bot=stars) to match the
	# shape CombatMockGame expects, instead of a single int.
	var spectator_bot_stars: Array = []
	for psid in player_session_ids:
		if _is_server_bot_session(str(psid)):
			spectator_bot_stars.append(int(bot_submission.get("bot_stars", 0)))
		else:
			spectator_bot_stars.append(-1)
	# The host client owns the live series state; the lobby only knows the
	# format. Publish it so spectators can tell Bo1 from Bo3 immediately, and
	# let the host's series events correct the win counts as games end.
	var spectator_best_of := 3 if int(entry.get("best_of", 1)) == 3 else 1
	_send_to_session(session_id, LobbyProtocolScript.MATCH_ASSIGNED, {
		"match_id": match_id,
		"room_id": str(entry.get("room_id", "")),
		"server_ip": spectate_ip,
		"spectate_lan_ip": lan_ip,
		"spectate_lan_port": lan_port,
		"match_port": spectate_port,
		"match_websocket_url": "",
		"player_index": -1,
		"observer_mode": true,
		"observer_session_id": session_id,
		"observer_match_token": observer_match_token,
		"player_names": player_names,
		"rank_badges": rank_badges,
		"bot_player_stars": spectator_bot_stars,
		"has_bot": true,
		"is_bot_self_play": false,
		"status": "active",
		"server_mode": "in_process_host",
		"is_ranked": bool(entry.get("is_ranked", false)),
		# The host's direct public endpoint as bounced to the reflector. A punch
		# spectator's client alternates retries between the reflector relay and
		# this endpoint when the relay never comes up.
		"spectate_direct_host_ip": spectate_ip,
		"spectate_direct_host_port": spectate_port,
		"series": {
			"best_of": spectator_best_of,
			"games_to_win": 2 if spectator_best_of == 3 else 1,
			"game_number": 1,
			"wins": [0, 0],
			"is_complete": false,
		},
		"reconnect_window_seconds": 0,
		"waiting_for_reconnect": false,
		"spectate_via_punch": via_punch,
		"spectate_relay_enabled": relay_enabled,
		"punch_reflector_port": _punch_reflector_port,
		"spectate_relay_port": _punch_reflector_port if via_relay else 0,
		"spectate_via_relay": via_relay,
	})
	_spectate_breadcrumb("assignment_sent", {
		"observer": session_id, "match": match_id,
		"public": "%s:%d" % [spectate_ip, spectate_port],
		"lan": "%s:%d" % [lan_ip, lan_port],
		"via_punch": str(via_punch), "relay_enabled": str(relay_enabled),
		"via_relay": str(via_relay),
	})
	_trace("observer %s joined local bot match %s via_punch=%s via_relay=%s" % [
		session_id, match_id, str(via_punch), str(via_relay),
	])

## Push a spectator's credentials to a client-hosted match's host and wait for
## its acknowledgement so the spectator never dials an unprepared host.
func _push_spectator_approval_to_host(
	match_id: String,
	host_session_id: String,
	observer_session_id: String,
	observer_match_token: String,
	visible_player_indices: Array[int]
) -> bool:
	if host_session_id.is_empty() or observer_match_token.is_empty():
		return false
	var ack_key := "%s|%s" % [match_id, observer_session_id]
	_spectator_acks_by_key.erase(ack_key)
	_send_to_session(host_session_id, LobbyProtocolScript.MATCH_SPECTATOR_APPROVED, {
		"match_id": match_id,
		"observer_session_id": observer_session_id,
		"observer_match_token": observer_match_token,
		"visible_player_indices": visible_player_indices,
		"punch_reflector_port": _punch_reflector_port,
	})
	var waited_seconds := 0.0
	while waited_seconds < MATCH_SPECTATOR_ACK_TIMEOUT_SECONDS:
		if _spectator_acks_by_key.has(ack_key):
			_spectator_acks_by_key.erase(ack_key)
			return true
		if not is_inside_tree() or get_tree() == null:
			return false
		await get_tree().create_timer(0.2).timeout
		waited_seconds += 0.2
	_spectator_acks_by_key.erase(ack_key)
	return false

func _handle_match_spectator_ack(peer_id: int, payload: Dictionary) -> void:
	var session: Dictionary = _get_session_for_peer(peer_id)
	if session.is_empty():
		return
	var session_id := str(session.get("session_id", ""))
	var match_id := str(payload.get("match_id", "")).strip_edges()
	var observer_session_id := str(payload.get("observer_session_id", "")).strip_edges()
	if match_id.is_empty() or observer_session_id.is_empty():
		return
	var entry_variant = _local_bot_matches_by_id.get(match_id, null)
	if entry_variant == null or not (entry_variant is Dictionary):
		return
	var entry: Dictionary = entry_variant
	if str(entry.get("human_session_id", "")) != session_id:
		return
	var spectator_tokens = entry.get("spectator_match_tokens_by_session", {})
	if not (spectator_tokens is Dictionary) or not (spectator_tokens as Dictionary).has(observer_session_id):
		return
	_spectator_acks_by_key["%s|%s" % [match_id, observer_session_id]] = true

func _handle_local_bot_match_spectate_info(peer_id: int, payload: Dictionary) -> void:
	var session: Dictionary = _get_session_for_peer(peer_id)
	if session.is_empty():
		return
	var session_id := str(session.get("session_id", ""))
	var match_id := str(payload.get("match_id", "")).strip_edges()
	var entry_variant = _local_bot_matches_by_id.get(match_id, null)
	if entry_variant == null or not (entry_variant is Dictionary):
		return
	var entry: Dictionary = entry_variant
	if str(entry.get("human_session_id", "")) != session_id:
		return
	var viable := bool(payload.get("viable", false))
	var spectate_ip := str(payload.get("spectate_ip", "")).strip_edges()
	var spectate_port := int(payload.get("spectate_port", 0))
	var punched := false
	var lan_ip := PunchReflectorScript.normalize_ip(str(payload.get("lan_ip", "")))
	var lan_port := int(payload.get("lan_port", 0))
	var relay_enabled := bool(payload.get("relay_enabled", false))
	if not lan_ip.is_empty() \
			and not PunchReflectorScript.is_private_ipv4(lan_ip) \
			and not PunchReflectorScript.is_loopback_ipv4(lan_ip):
		lan_ip = ""
	if lan_port <= 0 or lan_port > 65535:
		lan_port = 0
	if bool(payload.get("via_punch", false)):
		# Hole-punch fallback: the host bounced our reflector through the exact
		# socket its ENet spectate server listens on, so the recorded bounce is
		# the observable public endpoint. A missing bounce keeps whatever
		# endpoint (if any) this match already advertised.
		var bounce := _get_punch_bounce("host:%s" % match_id, PUNCH_DISCOVERY_BOUNCE_TTL_SECONDS)
		if not bounce.is_empty():
			spectate_ip = PunchReflectorScript.normalize_ip(str(bounce.get("ip", "")))
			spectate_port = int(bounce.get("port", 0))
			viable = spectate_port > 0 and not spectate_ip.is_empty()
			punched = viable
		else:
			return
	elif viable:
		entry.erase("spectate_via_punch")
	if not viable or spectate_ip.is_empty() or spectate_port <= 0:
		viable = false
	if punched:
		entry["spectate_via_punch"] = true
	entry["spectate_ip"] = spectate_ip if viable else ""
	entry["spectate_port"] = spectate_port if viable else 0
	entry["spectate_lan_ip"] = lan_ip if viable else ""
	entry["spectate_lan_port"] = lan_port if viable and not lan_ip.is_empty() else 0
	entry["spectate_relay_enabled"] = relay_enabled if viable else false
	_spectate_breadcrumb("host_endpoint_recorded", {
		"match": match_id, "host": session_id,
		"public": "%s:%d" % [spectate_ip, spectate_port],
		"lan": "%s:%d" % [entry["spectate_lan_ip"], int(entry["spectate_lan_port"])],
		"via_punch": str(punched), "relay_enabled": str(relay_enabled),
	})
	var room_id := str(entry.get("room_id", ""))
	if viable and not room_id.is_empty() and rooms_by_id.has(room_id):
		_emit_room_updates(rooms_by_id[room_id])
	_trace("local bot match %s spectate endpoint viable=%s via_punch=%s" % [match_id, str(viable), str(punched)])

## Relay an approved spectator's punch endpoint to a client-hosted match's
## host so it can open its NAT toward that spectator before the ENet dial.
func _handle_local_bot_match_punch_ready(peer_id: int, payload: Dictionary) -> void:
	var session: Dictionary = _get_session_for_peer(peer_id)
	if session.is_empty() or punch_reflector == null:
		return
	var session_id := str(session.get("session_id", ""))
	var match_id := str(payload.get("match_id", "")).strip_edges()
	var entry_variant = _local_bot_matches_by_id.get(match_id, null)
	if entry_variant == null or not (entry_variant is Dictionary):
		return
	var entry: Dictionary = entry_variant
	var spectator_tokens = entry.get("spectator_match_tokens_by_session", {})
	if not (spectator_tokens is Dictionary) or not (spectator_tokens as Dictionary).has(session_id):
		return
	_spectate_breadcrumb("punch_ready_received", {"observer": session_id, "match": match_id})
	var bounce := _get_punch_bounce("client:%s:%s" % [match_id, session_id], PUNCH_CLIENT_BOUNCE_TTL_SECONDS)
	if bounce.is_empty():
		_spectate_breadcrumb("punch_ready_missing_bounce", {"observer": session_id, "match": match_id})
		return
	var punch_ip := PunchReflectorScript.normalize_ip(str(bounce.get("ip", "")))
	var punch_port := int(bounce.get("port", 0))
	if punch_ip.is_empty() or punch_port <= 0:
		return
	# Refresh the relay with the spectator's current endpoint on every report,
	# including throttled ones, so retries do not forward to a stale NAT port.
	if punch_reflector.has_method("enable_relay_session"):
		punch_reflector.enable_relay_session(match_id, session_id)
	_spectate_breadcrumb("spectator_endpoint_resolved", {
		"observer": session_id, "match": match_id,
		"endpoint": "%s:%d" % [punch_ip, punch_port],
	})
	var rate_key := "%s|%s" % [match_id, session_id]
	var now_msec := Time.get_ticks_msec()
	if _punch_ready_last_msec_by_key.size() > 256:
		var stale_cutoff := now_msec - LOCAL_BOT_MATCH_PUNCH_RELAY_INTERVAL_MSEC * 60
		for stale_key in _punch_ready_last_msec_by_key.keys():
			if int(_punch_ready_last_msec_by_key[stale_key]) < stale_cutoff:
				_punch_ready_last_msec_by_key.erase(stale_key)
	# The reflector only stores the latest endpoint, so throttle relays; a
	# reconnecting spectator's fresher bounce arrives right after the interval.
	if now_msec - int(_punch_ready_last_msec_by_key.get(rate_key, -LOCAL_BOT_MATCH_PUNCH_RELAY_INTERVAL_MSEC)) \
			< LOCAL_BOT_MATCH_PUNCH_RELAY_INTERVAL_MSEC:
		return
	var first_relay := not _punch_ready_last_msec_by_key.has(rate_key)
	_punch_ready_last_msec_by_key[rate_key] = now_msec
	_send_to_session(str(entry.get("human_session_id", "")), LobbyProtocolScript.MATCH_SPECTATOR_PUNCH, {
		"match_id": match_id,
		"observer_session_id": session_id,
		"punch_ip": punch_ip,
		"punch_port": punch_port,
	})
	_spectate_breadcrumb("host_punch_relayed", {
		"observer": session_id, "match": match_id,
		"host": str(entry.get("human_session_id", "")),
		"endpoint": "%s:%d" % [punch_ip, punch_port], "first": str(first_relay),
	})
	if first_relay:
		_send_to_session(session_id, LobbyProtocolScript.MATCH_SPECTATOR_PUNCH_RELAYED, {"match_id": match_id})
	_trace("relay spectator punch target for match %s observer %s via_relay=%s" % [
		match_id, session_id,
		str(punch_reflector != null and punch_reflector.has_method("enable_relay_session")),
	])

func _get_punch_bounce(key: String, max_age_seconds: float) -> Dictionary:
	if punch_reflector == null:
		return {}
	var bounce: Dictionary = punch_reflector.get_bounce(key, max_age_seconds)
	return bounce if bounce is Dictionary else {}

## Clear punch throttles immediately. Completed matches can keep forwarding
## briefly so ENet can deliver the final board and result to spectators.
func _cleanup_local_bot_spectate_state(match_id: String, entry: Dictionary, relay_grace_seconds: float = 0.0) -> void:
	if match_id.is_empty():
		return
	if punch_reflector != null and punch_reflector.has_method("disable_relay_session"):
		var spectator_tokens = entry.get("spectator_match_tokens_by_session", {})
		if spectator_tokens is Dictionary:
			for observer_variant in (spectator_tokens as Dictionary).keys():
				punch_reflector.disable_relay_session(match_id, str(observer_variant), relay_grace_seconds)
	var stale_keys: Array[String] = []
	for key_variant in _punch_ready_last_msec_by_key.keys():
		var key := str(key_variant)
		if key.begins_with(match_id + "|"):
			stale_keys.append(key)
	for key in stale_keys:
		_punch_ready_last_msec_by_key.erase(key)
	_spectate_breadcrumb("relay_cleanup", {"match": match_id, "grace_seconds": relay_grace_seconds})

func _generate_spectator_token() -> String:
	var crypto := Crypto.new()
	var random_bytes := crypto.generate_random_bytes(20)
	var output := ""
	for random_byte in random_bytes:
		output += "%02x" % int(random_byte)
	return output

func _get_local_bot_match_player_names(entry: Dictionary) -> Array:
	var identities: Dictionary = entry.get("identity_by_session", {})
	if not (identities is Dictionary):
		return []
	var names: Array = []
	for session_id in [str(entry.get("human_session_id", "")), str(entry.get("bot_session_id", ""))]:
		var identity: Dictionary = (identities as Dictionary).get(session_id, {})
		names.append(str(identity.get("player_name", identity.get("username", "Player"))))
	return names

func _get_local_bot_match_player_rank_names(entry: Dictionary) -> Array:
	var identities: Dictionary = entry.get("identity_by_session", {})
	if not (identities is Dictionary):
		return []
	var rank_names: Array = []
	for session_id in [str(entry.get("human_session_id", "")), str(entry.get("bot_session_id", ""))]:
		var identity: Dictionary = (identities as Dictionary).get(session_id, {})
		var badge: Variant = identity.get("rank_badge", {})
		rank_names.append(str(badge.get("rank_name", "")) if badge is Dictionary else "")
	return rank_names

func _get_match_player_rank_names(badges: Array) -> Array:
	var rank_names: Array = []
	for badge in badges:
		rank_names.append(str(badge.get("rank_name", "")) if badge is Dictionary else "")
	return rank_names

func _rejoin_room_for_session(session_id: String, room_id: String) -> void:
	var normalized_room_id := room_id.strip_edges().to_upper()
	if normalized_room_id.is_empty() or not rooms_by_id.has(normalized_room_id):
		_send_error_to_session(session_id, "That live match was not found.")
		return
	var room: LobbyRoom = rooms_by_id[normalized_room_id]
	var match_id := str(room.assigned_match_id).strip_edges()
	if match_supervisor != null \
			and not match_id.is_empty() \
			and match_supervisor.get_match(match_id) != null \
			and not match_supervisor.is_match_ready_for_clients(match_id):
		_send_error_to_session(session_id, "That live match is still starting. Try again in a moment.")
		return
	var match_info := _build_active_match_info_for_session(session_id, room)
	if match_info.is_empty():
		_send_error_to_session(session_id, "This account is not a player in that live match.")
		return
	_send_to_session(session_id, LobbyProtocolScript.MATCH_ASSIGNED, match_info)

func _get_request_next_target(match_session: MatchSession, requester: Dictionary) -> String:
	if match_session == null or match_session.status != MatchSessionScript.STATUS_ACTIVE \
			or match_session.player_session_ids.size() != 2 or match_session.get_human_player_count() != 1:
		return ""
	var account_id := str(requester.get("account_id", ""))
	if account_id.is_empty():
		return ""
	for session_id in match_session.player_session_ids:
		if match_session.is_bot_session(session_id):
			continue
		var player: Dictionary = sessions_by_id.get(session_id, {})
		if str(player.get("account_id", "")) != account_id \
				and bool(player.get("connected", false)) and int(player.get("peer_id", 0)) > 0 \
				and not bool(player.get("is_local", false)):
			return session_id
	return ""

func _handle_request_next(peer_id: int, match_id: String) -> void:
	var requester := _get_session_for_peer(peer_id)
	var match_session: MatchSession = get_match_session(match_id)
	var target_id := _get_request_next_target(match_session, requester)
	var message := "That player is no longer available for a Request Next notification."
	if str(requester.get("account_id", "")).is_empty():
		message = "Sign in to request the next match."
	elif not target_id.is_empty():
		var room: LobbyRoom = rooms_by_id.get(match_session.room_id)
		if room != null and room.status == LobbyRoomScript.STATUS_IN_MATCH and room.assigned_match_id == match_id \
				and match_supervisor.is_match_ready_for_clients(match_id, false):
			var account_id: String = requester["account_id"]
			var player_name := str(sessions_by_id[target_id].get("player_name", "Player"))
			if match_session.next_requests_by_account.has(account_id):
				message = "%s already received your request." % player_name
			else:
				match_session.next_requests_by_account[account_id] = true
				_send_to_session(target_id, LobbyProtocolScript.REQUEST_NEXT_RECEIVED, {
					"requester_name": str(requester.get("player_name", "Player")),
				})
				message = "Request sent to %s." % player_name
	_send_to_peer(peer_id, LobbyProtocolScript.REQUEST_NEXT_RESULT, {"message": message})

func _leave_room_for_session(session_id: String) -> void:
	var room_id: String = str(room_id_by_session.get(session_id, ""))
	if room_id.is_empty() or not rooms_by_id.has(room_id):
		return

	var room: LobbyRoom = rooms_by_id[room_id]
	if room.status == LobbyRoomScript.STATUS_IN_MATCH:
		var match_id := str(room.assigned_match_id).strip_edges()
		if not match_id.is_empty() and match_supervisor != null:
			# The game can report its result before the lobby's next status poll.
			# Refresh now so leaving the result screen cannot erase the rematch seek.
			match_supervisor.refresh_match_status(match_id)
		room_id = str(room_id_by_session.get(session_id, ""))
		if room_id.is_empty() or not rooms_by_id.has(room_id):
			return
		room = rooms_by_id[room_id]
		if room.status == LobbyRoomScript.STATUS_IN_MATCH:
			_abandon_match_room(room)
			_broadcast_room_lists()
			return
	room.remove_member(session_id)
	room_id_by_session.erase(session_id)
	_notify_session_room_cleared(session_id)

	if room.is_empty():
		rooms_by_id.erase(room_id)
		_broadcast_room_lists()
		return

	if _is_available_server_bot_seek(room):
		_remove_duplicate_bot_seek(room)
		return
	_emit_room_updates(room)

func _remove_duplicate_bot_seek(room: LobbyRoom) -> void:
	for other: LobbyRoom in rooms_by_id.values():
		if other != room and other.is_ranked == room.is_ranked \
				and other.best_of == room.best_of and _is_available_server_bot_seek(other):
			_close_room(room.room_id)
			_broadcast_room_lists()
			return
	_emit_room_updates(room)

func _set_ready_for_session(session_id: String, is_ready: bool) -> void:
	var room_id: String = str(room_id_by_session.get(session_id, ""))
	if room_id.is_empty() or not rooms_by_id.has(room_id):
		_send_error_to_session(session_id, "Join a room before readying up.")
		return

	var room: LobbyRoom = rooms_by_id[room_id]
	if is_ready and not room.has_valid_deck(session_id):
		var deck_submission := room.get_deck_submission(session_id)
		var validation: Dictionary = deck_submission.get("validation", {})
		var error_message := str(validation.get("error", "")).strip_edges()
		if error_message.is_empty():
			error_message = "Select a valid deck before readying up."
		_send_error_to_session(session_id, error_message)
		return
	if not room.set_ready(session_id, is_ready):
		_send_error_to_session(session_id, "Unable to update ready state.")
		return

	_emit_room_updates(room)
	_try_assign_match(room)

func _assign_match(room: LobbyRoom) -> void:
	_ensure_match_supervisor()
	if match_supervisor == null:
		_send_error_to_session(room.host_session_id, "Match supervisor is unavailable.")
		return
	if not room.is_bot_self_play and _is_server_bot_session(room.host_session_id):
		if not _match_server_bot_to_player(room):
			_close_room(room.room_id, "Could not prepare a bot deck. Join a new bot challenge.")
			_broadcast_room_lists()
			return

	var player_decks_by_session: Dictionary = {}
	for session_id in room.members:
		var submission := room.get_deck_submission(session_id)
		if submission.is_empty():
			_send_error_to_session(session_id, "Select a valid deck before starting the match.")
			return
		player_decks_by_session[session_id] = submission.duplicate(true)

	var player_identity_by_session: Dictionary = {}
	for session_id in room.members:
		var session: Dictionary = sessions_by_id.get(session_id, {})
		var account_id := str(session.get("account_id", ""))
		var is_bot := bool(session.get("is_bot", false))
		var submission: Dictionary = player_decks_by_session[session_id]
		var bot_stars := int(submission.get("bot_stars", 0)) if is_bot else -1
		player_identity_by_session[session_id] = {
			"profile_id": str(session.get("profile_id", "")),
			"account_id": account_id,
			"username": str(session.get("username", "")),
			"player_name": str(session.get("player_name", "Guest")),
			"is_bot": is_bot,
			"bot_type": str(session.get("bot_type", "")),
			"rank_badge": _get_match_rank_badge(account_id, room.best_of, bot_stars),
		}

	# Server-bot challenge matches run entirely inside the challenger's own
	# client (in-process authority, like practice matches), keeping dedicated
	# server subprocesses free for human-vs-human matches. The lobby still
	# brokers the pairing and records the reported result.
	if _is_server_bot_challenge_room(room):
		_assign_local_bot_match(room, player_decks_by_session, player_identity_by_session)
		return

	var spectator_visibility := {} if room.is_bot_self_play else _build_spectator_visibility_by_session(room.members)
	# Unranked matches prefer a player-hosted (listen-server) topology when the
	# seek creator can host: one player runs the authoritative match and the
	# opponent connects directly, sparing a dedicated subprocess. Ranked matches
	# always use the dedicated/in-process path for integrity. The player-host
	# assignment is async (host must bind, lobby verifies reachability, then the
	# opponent is assigned or we fall back to dedicated).
	if _should_try_player_host(room):
		_begin_player_host_assignment(room, player_decks_by_session, player_identity_by_session, spectator_visibility)
		return
	var match_session = match_supervisor.create_match(
		room.room_id,
		room.members,
		player_decks_by_session,
		player_identity_by_session,
		spectator_visibility,
		room.is_ranked,
		room.best_of
	)
	_finalize_match_assignment(room, match_session)

## A server-bot challenge room pairs exactly one human with one bot session;
## bot self-play rooms are supervised instead, and human rooms never qualify.
func _is_server_bot_challenge_room(room: LobbyRoom) -> bool:
	if room == null or room.is_bot_self_play or room.members.size() != 2:
		return false
	var has_bot := false
	var has_human := false
	for session_id in room.members:
		if _is_server_bot_session(str(session_id)):
			has_bot = true
		else:
			has_human = true
	return has_bot and has_human

## Assign a server-bot challenge match to the challenger's own client. The
## human keeps player index 0 and the bot runs as player 1 with in-process
## authority; the lobby records the reported result through the normal
## MatchHistoryStore pipeline.
func _assign_local_bot_match(
	room: LobbyRoom,
	player_decks_by_session: Dictionary,
	player_identity_by_session: Dictionary
) -> void:
	var human_session_id := ""
	var bot_session_id := ""
	for session_id in room.members:
		if _is_server_bot_session(str(session_id)):
			bot_session_id = str(session_id)
		else:
			human_session_id = str(session_id)
	if human_session_id.is_empty() or bot_session_id.is_empty():
		_send_error_to_session(room.host_session_id, "Could not prepare the bot challenge.")
		_close_room(room.room_id)
		return

	var match_id := "match_%s" % _generate_id(8)
	# Mirror MatchSession.get_public_rank_badges() / get_public_bot_player_stars()
	# so the challenger's client can render the deck rank badges and names.
	var rank_badges: Array = []
	for player_session_id in [human_session_id, bot_session_id]:
		var identity: Dictionary = player_identity_by_session.get(player_session_id, {})
		rank_badges.append((identity.get("rank_badge", {}) as Dictionary).duplicate(true))
	var bot_player_stars: Array = []
	var bot_deck: Dictionary = player_decks_by_session.get(bot_session_id, {}) as Dictionary
	bot_player_stars.append(-1)
	bot_player_stars.append(int(bot_deck.get("bot_stars", 0)))
	var match_info: Dictionary = {
		"match_id": match_id,
		"room_id": room.room_id,
		"is_ranked": room.is_ranked,
		"best_of": 3 if room.best_of == 3 else 1,
		"player_session_ids": [human_session_id, bot_session_id],
		"human_session_id": human_session_id,
		"bot_session_id": bot_session_id,
		"decks_by_session": player_decks_by_session.duplicate(true),
		"identity_by_session": player_identity_by_session.duplicate(true),
		"rank_badges": rank_badges,
		"bot_player_stars": bot_player_stars,
		"has_bot": true,
	}
	_local_bot_matches_by_id[match_id] = {
		"match_id": match_id,
		"room_id": room.room_id,
		"human_session_id": human_session_id,
		"bot_session_id": bot_session_id,
		"is_ranked": room.is_ranked,
		"best_of": 3 if room.best_of == 3 else 1,
		"decks_by_session": player_decks_by_session.duplicate(true),
		"identity_by_session": player_identity_by_session.duplicate(true),
		"assigned_unix": int(Time.get_unix_time_from_system()),
		"reported": false,
		"spectate_ip": "",
		"spectate_port": 0,
		"spectate_lan_ip": "",
		"spectate_lan_port": 0,
		"spectate_relay_enabled": false,
	}
	room.status = LobbyRoomScript.STATUS_IN_MATCH
	room.assigned_match_id = match_id
	_emit_room_updates(room)
	if _room_has_server_bot(room):
		call_deferred("_ensure_server_bot_seeks")
	_send_to_session(human_session_id, LobbyProtocolScript.LOCAL_BOT_MATCH_ASSIGNED, match_info)
	_trace("assigned local bot match %s for room %s (ranked=%s)" % [match_id, room.room_id, str(room.is_ranked)])

func _handle_local_bot_match_result(peer_id: int, payload: Dictionary) -> void:
	var session: Dictionary = _get_session_for_peer(peer_id)
	if session.is_empty():
		_send_error_to_peer(peer_id, "Sign in before reporting match results.")
		return
	var human_session_id := str(session.get("session_id", ""))
	var match_id := str(payload.get("match_id", "")).strip_edges()
	var entry_variant = _local_bot_matches_by_id.get(match_id, null)
	if entry_variant == null or not (entry_variant is Dictionary):
		_send_error_to_peer(peer_id, "That match result was already settled or is unknown.")
		return
	var entry: Dictionary = entry_variant
	if str(entry.get("human_session_id", "")) != human_session_id:
		_send_error_to_peer(peer_id, "Only the challenger may report this match result.")
		return
	if bool(entry.get("reported", false)):
		_send_error_to_peer(peer_id, "This match result was already reported.")
		return

	var bot_session_id := str(entry.get("bot_session_id", ""))
	var winner_session_id := str(payload.get("winner_session_id", "")).strip_edges()
	var winner_index := -1
	var loser_index := -1
	if not winner_session_id.is_empty():
		var session_ids: Array[String] = [human_session_id, bot_session_id]
		var found_winner := session_ids.find(winner_session_id)
		if found_winner < 0:
			_send_error_to_peer(peer_id, "Invalid match winner session.")
			return
		winner_index = found_winner
		loser_index = 1 - found_winner
	entry["reported"] = true

	var match_session = MatchSessionScript.new(
		match_id,
		str(entry.get("room_id", "")),
		"127.0.0.1",
		0,
		[human_session_id, bot_session_id] as Array[String],
		(entry.get("decks_by_session", {}) as Dictionary).duplicate(true),
		(entry.get("identity_by_session", {}) as Dictionary).duplicate(true)
	)
	match_session.is_ranked = bool(entry.get("is_ranked", false))
	match_session.configure_series_format(int(entry.get("best_of", 1)))
	match_session.mark_finished()
	_ensure_match_history_store()
	var record_result: Dictionary = match_history_store.record_completed_match(
		match_session,
		winner_index,
		loser_index,
		str(payload.get("winner_god_name", "")).strip_edges(),
		str(payload.get("loser_god_name", "")).strip_edges()
	)
	if not bool(record_result.get("success", false)):
		entry["reported"] = false
		var record_message := str(record_result.get("message", "")).strip_edges()
		if record_message.is_empty():
			record_message = "Could not record the match result."
		_send_error_to_peer(peer_id, record_message)
		return
	_invalidate_ladder_cache()
	# If a human Iron/Bronze challenger lost, serve them a quarantined bad bot on
	# their next ranked match, exactly once per loss.
	if match_session.is_ranked and winner_index == 1:
		var loser_account_id := str(session.get("account_id", "")).strip_edges()
		if not loser_account_id.is_empty():
			var loser_progress: Dictionary = match_history_store.get_current_ranked_progress(loser_account_id, int(match_session.series_best_of))
			var loser_rank_name := str(loser_progress.get("rank_name", ""))
			if loser_rank_name.begins_with("Iron") or loser_rank_name.begins_with("Bronze"):
				match_history_store.set_serve_quarantined_next(loser_account_id, true)
	# The host reports through the lobby independently of its ENet result broadcast.
	_cleanup_local_bot_spectate_state(match_id, entry, LOCAL_BOT_MATCH_RESULT_RELAY_GRACE_SECONDS)
	_local_bot_matches_by_id.erase(match_id)
	var room_id := str(entry.get("room_id", ""))
	if not room_id.is_empty() and rooms_by_id.has(room_id):
		_close_room(room_id)
	call_deferred("_ensure_server_bot_seeks")
	_broadcast_room_lists()
	# The result screen wants a single player's ranked result dict, so send the
	# challenger's entry (player index 0) rather than a per-session map.
	var ranked_result := {}
	if record_result.get("entry", {}) is Dictionary and not (record_result["entry"] as Dictionary).is_empty():
		var by_index: Dictionary = match_history_store.get_ranked_match_results(record_result["entry"])
		if by_index.get(0, {}) is Dictionary:
			ranked_result = by_index[0]
	_send_to_session(human_session_id, LobbyProtocolScript.LOCAL_BOT_MATCH_CONFIRMED, {
		"match_id": match_id,
		"success": true,
		"ranked_result": ranked_result,
	})
	_trace("recorded local bot match result for %s (winner_index=%d)" % [match_id, winner_index])

## A room waiting on its challenger's client must not hold the bot list and
## seek slots forever if the client quit or crashed without reporting.
func _expire_stale_local_bot_matches() -> void:
	if _local_bot_matches_by_id.is_empty():
		return
	var now_unix := int(Time.get_unix_time_from_system())
	var expired_ids: Array[String] = []
	for match_id_variant in _local_bot_matches_by_id.keys():
		var match_id := str(match_id_variant)
		var entry: Dictionary = _local_bot_matches_by_id[match_id]
		if now_unix - int(entry.get("assigned_unix", 0)) >= LOCAL_BOT_MATCH_RESULT_TIMEOUT_SECONDS:
			expired_ids.append(match_id)
	for match_id in expired_ids:
		var entry: Dictionary = _local_bot_matches_by_id[match_id]
		_cleanup_local_bot_spectate_state(match_id, entry)
		_local_bot_matches_by_id.erase(match_id)
		var room_id := str(entry.get("room_id", ""))
		if not room_id.is_empty() and rooms_by_id.has(room_id):
			_close_room(room_id)
	if not expired_ids.is_empty():
		call_deferred("_ensure_server_bot_seeks")
		_broadcast_room_lists()

func _get_match_rank_badge(account_id: String, best_of: int, bot_stars: int) -> Dictionary:
	if bot_stars >= 0:
		var rank := RankedProgressionScript.summarize_bot_stars(bot_stars)
		return {"rank_name": rank["name"]}
	if account_id.is_empty() or match_history_store == null:
		return {}
	var progress: Dictionary = match_history_store.get_current_ranked_progress(account_id, best_of)
	var rank_name := str(progress.get("rank_name", ""))
	return {"rank_name": rank_name, "portrait": _get_public_rank_portrait(account_id, rank_name)}

func _get_public_rank_portrait(account_id: String, rank_name: String) -> Dictionary:
	if account_store == null:
		return {}
	var league := RankBadgeCatalog.league_for_rank(rank_name)
	return RankBadgeCatalog.validate_portrait(league, account_store.get_rank_badge(account_id, league))

## Finalize a (non-player-host) match: emit room updates, then either poll the
## dedicated subprocess for readiness or send both assignments immediately.
func _finalize_match_assignment(room: LobbyRoom, match_session) -> void:
	if match_session == null:
		var error_message := str(match_supervisor.last_create_match_error).strip_edges()
		if error_message.is_empty():
			error_message = "Failed to launch the match server."
		for session_id in room.members:
			_send_error_to_session(session_id, error_message)
		return
	room.status = LobbyRoomScript.STATUS_IN_MATCH
	room.assigned_match_id = match_session.match_id
	if room.is_bot_self_play:
		call_deferred("_poll_dedicated_match_assignment_ready", room.room_id, match_session.match_id, 0.0)
		return
	_emit_room_updates(room)
	if match_session.is_dedicated_headless():
		_trace("waiting for dedicated match %s to become ready for room %s" % [match_session.match_id, room.room_id])
		if _room_has_server_bot(room):
			call_deferred("_ensure_server_bot_seeks")
		call_deferred("_poll_dedicated_match_assignment_ready", room.room_id, match_session.match_id, 0.0)
		return
	_send_match_assignments_to_room(room, match_session)
	if _room_has_server_bot(room):
		call_deferred("_ensure_server_bot_seeks")

# --- Player-hosted (listen-server) match assignment ---------------------------

const PLAYER_HOST_READY_POLL_SECONDS := 0.4
const PLAYER_HOST_READY_TIMEOUT_SECONDS := 12.0
const PLAYER_HOST_PROBE_TIMEOUT_SECONDS := 4.0
const PLAYER_HOST_FALLBACK_MESSAGE := "Hosted match unavailable — using dedicated server."

## Player-host is attempted only for unranked rooms whose creator is a human,
## connected, and has reported a viable UPnP endpoint. Bots never host.
func _should_try_player_host(room: LobbyRoom) -> bool:
	if room == null:
		return false
	# Public TLS routing targets dedicated matches, not a player's UDP listener.
	if match_supervisor != null and not match_supervisor.public_websocket_url.is_empty():
		return false
	if room.is_ranked:
		return false
	var host_session_id := str(room.host_session_id).strip_edges()
	if host_session_id.is_empty() or not room.members.has(host_session_id):
		return false
	var host_session: Dictionary = sessions_by_id.get(host_session_id, {})
	if host_session.is_empty():
		return false
	if bool(host_session.get("is_bot", false)):
		return false
	if not bool(host_session.get("connected", false)):
		return false
	if not bool(host_session.get("host_viable", false)):
		return false
	if int(host_session.get("host_reachable_port", 0)) <= 0:
		return false
	return true

## Create a player-host MatchSession, assign the host (so it binds), then poll
## reachability before assigning the opponent. On any failure, abandon the
## player-host session and fall back to the dedicated/in-process path.
func _begin_player_host_assignment(
	room: LobbyRoom,
	player_decks_by_session: Dictionary,
	player_identity_by_session: Dictionary,
	spectator_visibility: Dictionary
) -> void:
	_ensure_match_supervisor()
	if match_supervisor == null:
		_send_error_to_session(room.host_session_id, "Match supervisor is unavailable.")
		return
	var host_session_id := str(room.host_session_id).strip_edges()
	var host_session: Dictionary = sessions_by_id.get(host_session_id, {})
	var reachable_ip := str(host_session.get("host_reachable_ip", "")).strip_edges()
	var reachable_port := int(host_session.get("host_reachable_port", 0))
	var bind_port := int(host_session.get("host_bind_port", reachable_port))
	var match_session = match_supervisor.create_match(
		room.room_id,
		room.members,
		player_decks_by_session,
		player_identity_by_session,
		spectator_visibility,
		room.is_ranked,
		room.best_of,
		host_session_id,
		reachable_ip,
		reachable_port,
		bind_port
	)
	if match_session == null or not match_session.is_player_host():
		# Supervisor declined the player-host path; fall back immediately.
		_finalize_match_assignment(room, match_session)
		return
	room.status = LobbyRoomScript.STATUS_IN_MATCH
	room.assigned_match_id = match_session.match_id
	_emit_room_updates(room)
	_trace("player-host match %s created for room %s host=%s endpoint=%s:%d" % [
		match_session.match_id, room.room_id, host_session_id, reachable_ip, reachable_port
	])
	# Send the host its assignment first so it binds the local port and starts
	# accepting the opponent's connection. The opponent is assigned only after
	# the lobby confirms the host endpoint is reachable.
	_send_match_assignment_to_session(room, match_session, host_session_id)
	if _room_has_server_bot(room):
		call_deferred("_ensure_server_bot_seeks")
	call_deferred(
		"_poll_player_host_assignment_ready",
		str(room.room_id),
		str(match_session.match_id),
		0.0
	)

## Wait briefly for the host to bind, verify the host endpoint is reachable via
## a short ENet probe, then assign the opponent. On timeout/failure, abandon and
## fall back to the dedicated/in-process path for both players.
func _poll_player_host_assignment_ready(room_id: String, match_id: String, elapsed_seconds: float) -> void:
	var resolved_room_id := room_id.strip_edges().to_upper()
	var resolved_match_id := match_id.strip_edges()
	if resolved_room_id.is_empty() or not rooms_by_id.has(resolved_room_id):
		return
	var room: LobbyRoom = rooms_by_id[resolved_room_id]
	if room == null or str(room.assigned_match_id).strip_edges() != resolved_match_id:
		return
	if match_supervisor == null:
		_fallback_player_host_to_dedicated(room, "Match supervisor is unavailable.")
		return
	var match_session = match_supervisor.get_match(resolved_match_id)
	if match_session == null or not match_session.is_player_host():
		return
	var reachable := await _probe_player_host_reachable(
		str(match_session.host_reachable_ip),
		int(match_session.host_reachable_port)
	)
	if reachable:
		_send_match_assignment_to_session(room, match_session, _opponent_session_id(room, match_session))
		return
	if elapsed_seconds >= PLAYER_HOST_READY_TIMEOUT_SECONDS:
		_fallback_player_host_to_dedicated(room, "The host endpoint was not reachable.")
		return
	var tree := get_tree()
	if tree == null:
		_fallback_player_host_to_dedicated(room, "Match readiness could not be checked.")
		return
	var timer := tree.create_timer(PLAYER_HOST_READY_POLL_SECONDS)
	await timer.timeout
	_poll_player_host_assignment_ready(resolved_room_id, resolved_match_id, elapsed_seconds + PLAYER_HOST_READY_POLL_SECONDS)

## Open a throwaway ENet client to the host's advertised endpoint and report
## whether it completes the ENet handshake within a short window. This is a true
## reachability proof for the UDP transport the match actually uses. The probe
## never sends a match_join_requested, so the host treats it as a transient peer
## and does not assign it a player slot; closing it cleans up cleanly.
func _probe_player_host_reachable(host_ip: String, host_port: int) -> bool:
	var resolved_ip := host_ip.strip_edges()
	if resolved_ip.is_empty() or host_port <= 0:
		return false
	var probe_peer := ENetMultiplayerPeer.new()
	if probe_peer.create_client(resolved_ip, host_port) != OK:
		return false
	var connected := false
	var tree := get_tree()
	if tree == null:
		probe_peer.close()
		return false
	var deadline_msec := Time.get_ticks_msec() + int(PLAYER_HOST_PROBE_TIMEOUT_SECONDS * 1000.0)
	while Time.get_ticks_msec() < deadline_msec:
		await tree.process_frame
		probe_peer.poll()
		var status := probe_peer.get_connection_status()
		if status == MultiplayerPeer.CONNECTION_CONNECTED:
			connected = true
			break
		if status == MultiplayerPeer.CONNECTION_DISCONNECTED:
			break
	probe_peer.close()
	return connected

func _opponent_session_id(room: LobbyRoom, match_session) -> String:
	for session_id in room.members:
		var resolved := str(session_id).strip_edges()
		if resolved != str(match_session.host_session_id).strip_edges():
			return resolved
	return ""

func _send_match_assignment_to_session(room: LobbyRoom, match_session, session_id: String) -> void:
	if room == null or match_session == null:
		return
	var resolved_session_id := str(session_id).strip_edges()
	if resolved_session_id.is_empty():
		return
	var match_info: Dictionary = match_session.to_match_info(resolved_session_id)
	_send_to_session(resolved_session_id, LobbyProtocolScript.MATCH_ASSIGNED, match_info)
	if resolved_session_id == local_session_id:
		call_deferred("_emit_local_match_assigned", match_info.duplicate(true))

## Abandon a player-host attempt and reassign the room on the dedicated/in-process
## path so both players still get a match. The host client tears down its bind
## when it receives the replacement assignment (its match_info no longer carries
## is_match_host).
func _fallback_player_host_to_dedicated(room: LobbyRoom, reason: String) -> void:
	if room == null:
		return
	var match_id := str(room.assigned_match_id).strip_edges()
	_trace("player-host fallback for room %s match %s: %s" % [room.room_id, match_id, reason])
	if not match_id.is_empty() and match_supervisor != null and match_supervisor.get_match(match_id) != null:
		match_supervisor.close_match(match_id, MatchSessionScript.STATUS_ABANDONED, false)
	room.assigned_match_id = ""
	room.status = LobbyRoomScript.STATUS_READY if room.can_start() else LobbyRoomScript.STATUS_WAITING
	_emit_room_updates(room)
	for session_id in room.members:
		_send_error_to_session(session_id, PLAYER_HOST_FALLBACK_MESSAGE)
	# Brief pause so clients can tear down the host bind before reconnecting.
	var tree := get_tree()
	if tree != null:
		await tree.create_timer(1.0).timeout
	if not is_inside_tree() or not rooms_by_id.has(str(room.room_id)):
		return
	if room.status == LobbyRoomScript.STATUS_IN_MATCH:
		return  # Another assignment path already took over.
	_assign_match(room)


func _send_match_assignments_to_room(room: LobbyRoom, match_session) -> void:
	if room == null or match_session == null:
		return
	_trace("sending match assignments for %s room %s" % [str(match_session.match_id), str(room.room_id)])
	var local_match_info: Dictionary = {}
	for session_id in room.members:
		var match_info: Dictionary = match_session.to_match_info(session_id)
		_send_to_session(session_id, LobbyProtocolScript.MATCH_ASSIGNED, match_info)
		if session_id == local_session_id:
			local_match_info = match_info.duplicate(true)
	if not local_match_info.is_empty():
		call_deferred("_emit_local_match_assigned", local_match_info)

func _poll_dedicated_match_assignment_ready(room_id: String, match_id: String, elapsed_seconds: float) -> void:
	var resolved_room_id := room_id.strip_edges().to_upper()
	var resolved_match_id := match_id.strip_edges()
	if resolved_room_id.is_empty() or resolved_match_id.is_empty():
		return
	if not rooms_by_id.has(resolved_room_id):
		return
	var room: LobbyRoom = rooms_by_id[resolved_room_id]
	if room == null \
			or room.status != LobbyRoomScript.STATUS_IN_MATCH \
			or str(room.assigned_match_id).strip_edges() != resolved_match_id:
		return
	if match_supervisor == null:
		_fail_dedicated_match_assignment(room, "Match supervisor is unavailable.")
		return

	var match_session = match_supervisor.get_match(resolved_match_id)
	if match_session == null:
		_fail_dedicated_match_assignment(room, "Match server is no longer available.")
		return
	if match_supervisor.is_match_ready_for_clients(resolved_match_id):
		if room.is_bot_self_play:
			_broadcast_room_lists()
		else:
			_send_match_assignments_to_room(room, match_session)
		return

	var failure_reason := str(match_supervisor.get_match_startup_failure_reason(resolved_match_id)).strip_edges()
	if not failure_reason.is_empty():
		_fail_dedicated_match_assignment(room, failure_reason)
		return
	if elapsed_seconds >= DEDICATED_MATCH_ASSIGNMENT_TIMEOUT_SECONDS:
		_fail_dedicated_match_assignment(room, "Match server did not become available in time.")
		return

	var tree := get_tree()
	if tree == null:
		_fail_dedicated_match_assignment(room, "Match server readiness could not be checked.")
		return
	var timer := tree.create_timer(DEDICATED_MATCH_ASSIGNMENT_POLL_SECONDS)
	timer.timeout.connect(
		Callable(self, "_poll_dedicated_match_assignment_ready").bind(
			resolved_room_id,
			resolved_match_id,
			elapsed_seconds + DEDICATED_MATCH_ASSIGNMENT_POLL_SECONDS
		)
	)

func _fail_dedicated_match_assignment(room: LobbyRoom, message: String) -> void:
	if room == null:
		return
	var room_id := str(room.room_id).strip_edges()
	var match_id := str(room.assigned_match_id).strip_edges()
	_trace("dedicated match assignment failed for %s room %s: %s" % [match_id, room_id, message])
	if room.is_bot_self_play and match_supervisor != null:
		match_supervisor.close_match(match_id, MatchSessionScript.STATUS_ABANDONED, true, message)
		return
	if not room_id.is_empty() and rooms_by_id.has(room_id):
		_close_room(room_id, message)
		_broadcast_room_lists()
	if not match_id.is_empty() and match_supervisor != null and match_supervisor.get_match(match_id) != null:
		match_supervisor.close_match(match_id, MatchSessionScript.STATUS_ABANDONED, true)

func _try_assign_match(room: LobbyRoom) -> void:
	if room == null or room.status == LobbyRoomScript.STATUS_IN_MATCH or not room.can_start():
		return
	if not _room_has_all_members_connected(room):
		return
	_assign_match(room)

func _room_has_connected_member(room: LobbyRoom) -> bool:
	if room == null:
		return false
	for session_id in room.members:
		var session: Dictionary = sessions_by_id.get(session_id, {})
		if bool(session.get("connected", false)):
			return true
	return false

func _room_has_all_members_connected(room: LobbyRoom) -> bool:
	if room == null or room.members.is_empty():
		return false
	for session_id in room.members:
		var session: Dictionary = sessions_by_id.get(session_id, {})
		if session.is_empty() or not bool(session.get("connected", false)):
			return false
	return true

func _build_spectator_visibility_by_session(player_session_ids: Array) -> Dictionary:
	var visibility_by_session: Dictionary = {}
	for session_id_variant in sessions_by_id.keys():
		var observer_session_id := str(session_id_variant).strip_edges()
		if observer_session_id.is_empty():
			continue
		visibility_by_session[observer_session_id] = _get_friend_visible_player_indices(
			observer_session_id,
			player_session_ids
		)
	return visibility_by_session

func _get_friend_visible_player_indices(observer_session_id: String, player_session_ids: Array) -> Array[int]:
	var visible_player_indices: Array[int] = []
	var observer_session: Dictionary = sessions_by_id.get(observer_session_id, {})
	var observer_account_id := str(observer_session.get("account_id", "")).strip_edges()
	if observer_account_id.is_empty():
		return visible_player_indices
	_ensure_friend_store()
	_ensure_profile_store()
	if friend_store == null or profile_store == null:
		return visible_player_indices
	for player_index in range(player_session_ids.size()):
		var player_session_id := str(player_session_ids[player_index]).strip_edges()
		var player_session: Dictionary = sessions_by_id.get(player_session_id, {})
		var player_account_id := str(player_session.get("account_id", "")).strip_edges()
		if player_account_id.is_empty():
			continue
		if not friend_store.are_friends(observer_account_id, player_account_id):
			continue
		if not profile_store.get_allow_friend_observers_to_see_cards_for_account(player_account_id):
			continue
		visible_player_indices.append(player_index)
	return visible_player_indices

func _get_allow_friend_observers_to_see_cards(session: Dictionary) -> bool:
	var account_id := str(session.get("account_id", "")).strip_edges()
	if account_id.is_empty():
		return true
	_ensure_profile_store()
	if profile_store == null:
		return true
	return profile_store.get_allow_friend_observers_to_see_cards_for_account(account_id)

func _emit_room_updates(room: LobbyRoom) -> void:
	_broadcast_room_snapshot(room)
	_broadcast_room_lists()

func _submit_deck_for_session(
	session_id: String,
	deck_name: String,
	deck_id: String,
	cards,
	special_setup = {},
	reinforcements = {},
	payload_is_purpose_deck: bool = false
) -> void:
	var room_id: String = str(room_id_by_session.get(session_id, ""))
	if room_id.is_empty() or not rooms_by_id.has(room_id):
		_send_error_to_session(session_id, "Join a room before selecting a deck.")
		return
	var session: Dictionary = sessions_by_id.get(session_id, {})
	var account_id: String = str(session.get("account_id", "")).strip_edges()
	var resolved_deck_name := deck_name.strip_edges()
	var resolved_deck_id := deck_id.strip_edges()
	var resolved_cards: Dictionary = {}
	var resolved_reinforcements: Dictionary = {}
	var resolved_special_setup: Dictionary = {}
	if not account_id.is_empty():
		_ensure_deck_store()
		_ensure_profile_store()
		if deck_store == null:
			_send_error_to_session(session_id, "Deck storage is unavailable.")
			return
		if resolved_deck_id.is_empty():
			_send_error_to_session(session_id, "Choose one of your saved decks.")
			return
		var saved_deck: Dictionary = deck_store.get_deck(account_id, resolved_deck_id)
		if saved_deck.is_empty():
			_send_error_to_session(session_id, "That saved deck was not found on the server.")
			return
		resolved_deck_name = str(saved_deck.get("name", resolved_deck_name)).strip_edges()
		var saved_cards = saved_deck.get("cards", {})
		if not (saved_cards is Dictionary):
			_send_error_to_session(session_id, "That saved deck is missing its cards.")
			return
		resolved_cards = (saved_cards as Dictionary).duplicate(true)
		var saved_reinforcements = saved_deck.get("reinforcements", {})
		if saved_reinforcements is Dictionary:
			resolved_reinforcements = (saved_reinforcements as Dictionary).duplicate(true)
		var saved_special_setup = saved_deck.get("special_setup", {})
		if saved_special_setup is Dictionary:
			resolved_special_setup = (saved_special_setup as Dictionary).duplicate(true)
		if profile_store != null:
			profile_store.set_preferred_deck_id_for_account(account_id, resolved_deck_id)
	else:
		if not (cards is Dictionary):
			_send_error_to_session(session_id, "Deck submission was missing cards.")
			return
		resolved_cards = (cards as Dictionary).duplicate(true)
		var submitted_reinforcements = reinforcements
		if submitted_reinforcements is Dictionary:
			resolved_reinforcements = (submitted_reinforcements as Dictionary).duplicate(true)
		var submitted_special_setup = special_setup
		if submitted_special_setup is Dictionary:
			resolved_special_setup = (submitted_special_setup as Dictionary).duplicate(true)
	_ensure_deck_validator()
	if deck_validator == null:
		_send_error_to_session(session_id, "Deck validator is unavailable.")
		return
	# Purpose decks (campaign scenarios, scripted smoke runs) are allowed to
	# violate normal construction rules and bypass validation entirely. They
	# must never come from normal matchmaking - only from trusted callers that
	# set is_purpose_deck=true in the submit_deck payload.
	var is_purpose_deck := bool(resolved_special_setup.get("is_purpose_deck", false)) \
		or bool(payload_is_purpose_deck)
	var validation: Dictionary = {}
	if is_purpose_deck:
		validation = {
			"is_valid": true,
			"cards": resolved_cards,
			"special_setup": resolved_special_setup,
			"reinforcements": resolved_reinforcements,
			"is_purpose_deck": true,
		}
	else:
		validation = deck_validator.validate_deck(
			resolved_cards,
			resolved_special_setup,
			resolved_reinforcements
		)
	var room: LobbyRoom = rooms_by_id[room_id]
	if not room.submit_deck(
		session_id,
		resolved_deck_name,
		resolved_deck_id,
		validation.get("cards", {}),
		validation,
		validation.get("special_setup", {}),
		validation.get("reinforcements", {}),
		is_purpose_deck
	):
		_send_error_to_session(session_id, "Unable to store selected deck.")
		return
	var deck_is_valid := bool(validation.get("is_valid", false))
	room.set_ready(session_id, deck_is_valid)
	_emit_room_updates(room)
	if deck_is_valid:
		_try_assign_match(room)

func _broadcast_room_snapshot(room: LobbyRoom) -> void:
	var snapshot: Dictionary = room.to_snapshot(sessions_by_id)
	snapshot["server_version"] = _get_server_version()
	for session_id in room.members:
		_send_to_session(session_id, LobbyProtocolScript.ROOM_SNAPSHOT, snapshot)
		if session_id == local_session_id:
			local_room_snapshot_updated.emit(snapshot)

func _broadcast_room_lists() -> void:
	var now_msec := Time.get_ticks_msec()
	if now_msec - _room_list_broadcast_last_msec >= _ROOM_LIST_BROADCAST_MIN_INTERVAL_MSEC:
		_do_broadcast_room_lists()
		_room_list_broadcast_last_msec = now_msec
		_room_list_broadcast_pending = false
	elif not _room_list_broadcast_pending:
		_room_list_broadcast_pending = true
		call_deferred("_flush_room_list_broadcast")

func _flush_room_list_broadcast() -> void:
	if not _room_list_broadcast_pending:
		return
	_room_list_broadcast_pending = false
	_room_list_broadcast_last_msec = Time.get_ticks_msec()
	_do_broadcast_room_lists()

func _do_broadcast_room_lists() -> void:
	for peer_id in session_id_by_peer.keys():
		var session_id := str(session_id_by_peer.get(peer_id, "")).strip_edges()
		_send_to_peer(int(peer_id), LobbyProtocolScript.ROOM_LIST, {
			"rooms": _build_room_list(session_id),
			"server_version": _get_server_version(),
			"punch_reflector_port": _punch_reflector_port,
		})
	room_list_updated.emit(_build_room_list(local_session_id))

func _send_room_list_to_peer(peer_id: int) -> void:
	var session_id := str(session_id_by_peer.get(peer_id, "")).strip_edges()
	_send_to_peer(peer_id, LobbyProtocolScript.ROOM_LIST, {
		"rooms": _build_room_list(session_id),
		"server_version": _get_server_version(),
		"punch_reflector_port": _punch_reflector_port,
	})

func _send_friends_state_to_account(account_id: String) -> void:
	var resolved_account_id := account_id.strip_edges()
	if resolved_account_id.is_empty():
		return
	_ensure_friend_store()
	_ensure_account_store()
	if friend_store == null:
		return
	var state: Dictionary = friend_store.get_state(resolved_account_id)
	var account_ids := _collect_account_ids_from_friends_state(state)
	if account_store != null:
		state = friend_store.get_state(resolved_account_id, account_store.get_username_map(account_ids))
	for session_id_variant in sessions_by_id.keys():
		var session_id := str(session_id_variant).strip_edges()
		if session_id.is_empty():
			continue
		var session: Dictionary = sessions_by_id.get(session_id, {})
		if str(session.get("account_id", "")).strip_edges() != resolved_account_id:
			continue
		_send_to_session(session_id, LobbyProtocolScript.FRIENDS_STATE, state)

func _collect_account_ids_from_friends_state(state: Dictionary) -> Array:
	var account_ids: Array = []
	for list_key in ["friends", "incoming_requests", "outgoing_requests", "incoming_deck_shares", "outgoing_deck_shares"]:
		var entries = state.get(list_key, [])
		if not (entries is Array):
			continue
		for entry in entries:
			if not (entry is Dictionary):
				continue
			for id_key in ["account_id", "requester_account_id", "recipient_account_id", "sender_account_id"]:
				var account_id := str((entry as Dictionary).get(id_key, "")).strip_edges()
				if account_id.is_empty() or account_id in account_ids:
					continue
				account_ids.append(account_id)
	return account_ids

func _build_room_list(viewer_session_id: String = "") -> Array:
	var rooms: Array = []
	var viewer: Dictionary = sessions_by_id.get(viewer_session_id, {})
	for room_id in rooms_by_id.keys():
		var room: LobbyRoom = rooms_by_id[room_id]
		if room.status != LobbyRoomScript.STATUS_IN_MATCH and not _room_has_connected_member(room):
			continue
		if room.is_waiting_for_opponent() and _is_server_bot_session(room.host_session_id) and not _is_available_server_bot_seek(room):
			continue
		var entry := room.to_room_list_entry(sessions_by_id)
		entry["viewer_can_rejoin"] = false
		if room.status == LobbyRoomScript.STATUS_IN_MATCH:
			var match_id := str(room.assigned_match_id).strip_edges()
			var match_session: MatchSession = get_match_session(match_id)
			if room.is_bot_self_play and (match_session == null or not match_supervisor.is_match_ready_for_clients(match_id)):
				continue
			var local_bot_entry_variant = _local_bot_matches_by_id.get(match_id, null)
			if local_bot_entry_variant is Dictionary:
				# Client-hosted bot challenges have no supervised session; expose
				# the challenger's spectate endpoint so others can watch live.
				var local_bot_entry: Dictionary = local_bot_entry_variant
				entry["local_bot_match"] = true
				if int(local_bot_entry.get("spectate_port", 0)) > 0 \
						and not str(local_bot_entry.get("spectate_ip", "")).is_empty():
					entry["spectatable"] = true
					entry["match_player_names"] = _get_local_bot_match_player_names(local_bot_entry)
					entry["match_rank_names"] = _get_local_bot_match_player_rank_names(local_bot_entry)
			else:
				entry["viewer_can_rejoin"] = (
					not _get_matching_participant_session_id(viewer_session_id, room.members).is_empty()
					and (match_session == null or match_supervisor.is_match_ready_for_clients(match_id))
				)
				if match_session != null and match_session.player_session_ids.size() == 2:
					if match_session.get_human_player_count() == 1:
						entry["match_player_names"] = match_session.get_public_player_names()
					entry["match_rank_names"] = _get_match_player_rank_names(match_session.get_public_rank_badges())
					if not _get_request_next_target(match_session, viewer).is_empty() \
							and not match_session.next_requests_by_account.has(viewer.get("account_id", "")) \
							and match_supervisor.is_match_ready_for_clients(match_id, false):
						entry["request_next_match_id"] = match_id
		rooms.append(entry)
	return rooms

func _expire_stale_seeks() -> void:
	var expired_room_ids: Array[String] = []
	for room_id_variant in rooms_by_id.keys():
		var room_id := str(room_id_variant)
		var room_variant = rooms_by_id.get(room_id, null)
		if room_variant == null or not (room_variant is LobbyRoom):
			continue
		var room: LobbyRoom = room_variant
		if not _is_available_server_bot_seek(room) and room.has_waited_for_opponent_too_long(SEEK_TIMEOUT_SECONDS):
			expired_room_ids.append(room_id)
	if expired_room_ids.is_empty():
		return
	for room_id in expired_room_ids:
		_close_room(
			room_id,
			"Seek %s expired after 30 minutes of waiting for an opponent." % room_id
		)
	_ensure_server_bot_seeks()
	_broadcast_room_lists()

func _expire_disconnected_room_members() -> void:
	var now_unix := int(Time.get_unix_time_from_system())
	var expired_by_room: Dictionary = {}
	for room_id_variant in rooms_by_id.keys():
		var room_id := str(room_id_variant)
		var room: LobbyRoom = rooms_by_id.get(room_id, null)
		if room == null or room.status == LobbyRoomScript.STATUS_IN_MATCH:
			continue
		var expired_sessions: Array[String] = []
		for session_id in room.members:
			var session: Dictionary = sessions_by_id.get(session_id, {})
			if session.is_empty() or bool(session.get("connected", false)):
				continue
			var disconnected_since := int(session.get("room_disconnected_since_unix", 0))
			if disconnected_since <= 0:
				continue
			if now_unix - disconnected_since >= ROOM_MEMBER_RECONNECT_GRACE_SECONDS:
				expired_sessions.append(session_id)
		if not expired_sessions.is_empty():
			expired_by_room[room_id] = expired_sessions
	for room_id_variant in expired_by_room.keys():
		var room_id := str(room_id_variant)
		if not rooms_by_id.has(room_id):
			continue
		var room: LobbyRoom = rooms_by_id[room_id]
		for session_id in expired_by_room[room_id]:
			room.remove_member(session_id)
			if str(room_id_by_session.get(session_id, "")) == room_id:
				room_id_by_session.erase(session_id)
			var session: Dictionary = sessions_by_id.get(session_id, {})
			if not session.is_empty():
				session["room_disconnected_since_unix"] = 0
				sessions_by_id[session_id] = session
		if room.is_empty():
			rooms_by_id.erase(room_id)
			continue
		_broadcast_room_snapshot(room)
	if not expired_by_room.is_empty():
		_broadcast_room_lists()

## Player-hosted matches have no dedicated subprocess heartbeat, so the lobby
## must detect a dropped host itself. If the host's lobby session has been
## disconnected beyond the reconnect grace while the room is in a player-host
## match, abandon the room so the opponent is freed (no host migration).
func _expire_abandoned_player_host_matches() -> void:
	if match_supervisor == null:
		return
	var now_unix := int(Time.get_unix_time_from_system())
	var rooms_to_abandon: Array[LobbyRoom] = []
	for room_id_variant in rooms_by_id.keys():
		var room_id := str(room_id_variant)
		var room: LobbyRoom = rooms_by_id.get(room_id, null)
		if room == null or room.status != LobbyRoomScript.STATUS_IN_MATCH:
			continue
		var match_id := str(room.assigned_match_id).strip_edges()
		if match_id.is_empty():
			continue
		var match_session = match_supervisor.get_match(match_id)
		if match_session == null or not match_session.is_player_host():
			continue
		var host_session_id := str(match_session.host_session_id).strip_edges()
		var host_session: Dictionary = sessions_by_id.get(host_session_id, {})
		if host_session.is_empty() or bool(host_session.get("connected", false)):
			continue
		var disconnected_since := int(host_session.get("room_disconnected_since_unix", 0))
		if disconnected_since <= 0:
			continue
		if now_unix - disconnected_since >= ROOM_MEMBER_RECONNECT_GRACE_SECONDS:
			rooms_to_abandon.append(room)
	for room in rooms_to_abandon:
		_abandon_match_room(room)
	if not rooms_to_abandon.is_empty():
		_broadcast_room_lists()

func _prune_excess_open_seeks_for_session(session_id: String) -> void:
	var seek_owner_key := _get_seek_owner_key_for_session(session_id)
	if seek_owner_key.is_empty():
		return
	var open_seek_room_ids := _get_open_seek_room_ids_for_owner(seek_owner_key)
	if open_seek_room_ids.size() < 2:
		return
	open_seek_room_ids.sort_custom(func(a: String, b: String) -> bool:
		return _get_room_waiting_since_msec(a) < _get_room_waiting_since_msec(b)
	)
	while open_seek_room_ids.size() >= 2:
		var oldest_room_id := open_seek_room_ids[0]
		_close_room(
			oldest_room_id,
			"Seek %s was canceled because you can only keep 2 seeks open at once." % oldest_room_id
		)
		open_seek_room_ids.remove_at(0)
	_broadcast_room_lists()

func _close_room(room_id: String, message: String = "") -> void:
	if room_id.is_empty() or not rooms_by_id.has(room_id):
		return
	var room: LobbyRoom = rooms_by_id[room_id]
	var affected_sessions: Array[String] = []
	for session_id in room.members:
		affected_sessions.append(session_id)
	var room_match_id := str(room.assigned_match_id).strip_edges()
	if not room_match_id.is_empty():
		var local_bot_entry = _local_bot_matches_by_id.get(room_match_id, null)
		if local_bot_entry is Dictionary:
			_cleanup_local_bot_spectate_state(room_match_id, local_bot_entry)
		_local_bot_matches_by_id.erase(room_match_id)
	rooms_by_id.erase(room_id)
	for session_id in affected_sessions:
		if str(room_id_by_session.get(session_id, "")) == room_id:
			room_id_by_session.erase(session_id)
		_notify_session_room_cleared(session_id)
		if not message.strip_edges().is_empty():
			_send_error_to_session(session_id, message)
		if _is_server_bot_session(session_id):
			sessions_by_id.erase(session_id)

func _notify_session_room_cleared(session_id: String) -> void:
	if session_id == local_session_id:
		local_room_snapshot_updated.emit({})
		return
	_send_to_session(session_id, LobbyProtocolScript.ROOM_SNAPSHOT, {})

func _abandon_match_room(room: LobbyRoom) -> void:
	if room == null:
		return
	var room_id := str(room.room_id).strip_edges()
	var match_id := str(room.assigned_match_id).strip_edges()
	if not match_id.is_empty() and match_supervisor != null and match_supervisor.get_match(match_id) != null:
		match_supervisor.close_match(match_id, MatchSessionScript.STATUS_ABANDONED, true)
	if not room_id.is_empty() and rooms_by_id.has(room_id):
		_close_room(room_id)

func _get_seek_owner_key_for_session(session_id: String) -> String:
	var session: Dictionary = sessions_by_id.get(session_id, {})
	return _get_seek_owner_key_for_session_data(session)

func _get_seek_owner_key_for_room(room: LobbyRoom) -> String:
	if room == null:
		return ""
	var host_session: Dictionary = sessions_by_id.get(room.host_session_id, {})
	return _get_seek_owner_key_for_session_data(host_session)

func _get_seek_owner_key_for_session_data(session: Dictionary) -> String:
	if session.is_empty():
		return ""
	var account_id := str(session.get("account_id", "")).strip_edges()
	if not account_id.is_empty():
		return "account:%s" % account_id
	var profile_id := str(session.get("profile_id", "")).strip_edges()
	if not profile_id.is_empty():
		return "profile:%s" % profile_id
	return "session:%s" % str(session.get("session_id", "")).strip_edges()

func _get_open_seek_room_ids_for_owner(seek_owner_key: String) -> Array[String]:
	var room_ids: Array[String] = []
	if seek_owner_key.is_empty():
		return room_ids
	for room_id_variant in rooms_by_id.keys():
		var room_id := str(room_id_variant)
		var room_variant = rooms_by_id.get(room_id, null)
		if room_variant == null or not (room_variant is LobbyRoom):
			continue
		var room: LobbyRoom = room_variant
		if not room.is_waiting_for_opponent():
			continue
		if _get_seek_owner_key_for_room(room) != seek_owner_key:
			continue
		room_ids.append(room_id)
	return room_ids

func _get_room_waiting_since_msec(room_id: String) -> int:
	var room_variant = rooms_by_id.get(room_id, null)
	if room_variant == null or not (room_variant is LobbyRoom):
		return 0
	var room: LobbyRoom = room_variant
	return room.waiting_for_opponent_since_msec

func _send_to_session(session_id: String, message_type: String, payload: Dictionary) -> void:
	var session: Dictionary = sessions_by_id.get(session_id, {})
	if session.is_empty():
		return
	if bool(session.get("is_local", false)):
		return
	var target_peer_id: int = int(session.get("peer_id", 0))
	if target_peer_id <= 0 or not bool(session.get("connected", false)):
		return
	_send_to_peer(target_peer_id, message_type, payload)

func _send_to_peer(peer_id: int, message_type: String, payload: Dictionary) -> void:
	if peer_id <= 0 or network_manager == null or not network_manager.is_server:
		return
	_trace("sending %s to peer %d" % [message_type, peer_id])
	network_manager.broadcast_event_to_peer(peer_id, LOBBY_EVENT_TYPE, LobbyProtocolScript.make_message(message_type, payload))

func _send_error_to_session(session_id: String, message: String) -> void:
	var session: Dictionary = sessions_by_id.get(session_id, {})
	if session.is_empty():
		return
	if bool(session.get("is_local", false)) and session_id == local_session_id:
		status_changed.emit(message)
	if not bool(session.get("is_local", false)) and int(session.get("peer_id", 0)) > 0:
		_send_to_peer(int(session.get("peer_id", 0)), LobbyProtocolScript.ROOM_ERROR, {"message": message})

func _send_error_to_peer(peer_id: int, message: String) -> void:
	_send_to_peer(peer_id, LobbyProtocolScript.ROOM_ERROR, {"message": message})

func _get_session_for_peer(peer_id: int) -> Dictionary:
	var session_id: String = str(session_id_by_peer.get(peer_id, ""))
	if session_id.is_empty():
		return {}
	return sessions_by_id.get(session_id, {})

func _get_local_session() -> Dictionary:
	if local_session_id.is_empty():
		return {}
	return sessions_by_id.get(local_session_id, {})

func _on_peer_disconnected(peer_id: int) -> void:
	var session_id: String = str(session_id_by_peer.get(peer_id, ""))
	if session_id.is_empty():
		return

	session_id_by_peer.erase(peer_id)
	if not sessions_by_id.has(session_id):
		return

	var session: Dictionary = sessions_by_id[session_id]
	session["peer_id"] = 0
	session["connected"] = false
	sessions_by_id[session_id] = session
	_cancel_client_bot_jobs_for_session(session_id)

	var room_id: String = str(room_id_by_session.get(session_id, ""))
	if not room_id.is_empty() and rooms_by_id.has(room_id):
		var room: LobbyRoom = rooms_by_id[room_id]
		if room.status == LobbyRoomScript.STATUS_IN_MATCH:
			# Dedicated matches manage their own reconnect window via the
			# supervisor's status-file polling. Player-host matches have no such
			# heartbeat, so record when the host dropped so the periodic expiry
			# can free the opponent once grace elapses.
			if _is_player_host_session(room, session_id):
				session["room_disconnected_since_unix"] = int(Time.get_unix_time_from_system())
			else:
				session["room_disconnected_since_unix"] = 0
			sessions_by_id[session_id] = session
			return
		session["room_disconnected_since_unix"] = int(Time.get_unix_time_from_system())
		sessions_by_id[session_id] = session
		_broadcast_room_snapshot(room)
	_broadcast_room_lists()

func _is_player_host_session(room: LobbyRoom, session_id: String) -> bool:
	if room == null or match_supervisor == null:
		return false
	var match_id := str(room.assigned_match_id).strip_edges()
	if match_id.is_empty():
		return false
	var match_session = match_supervisor.get_match(match_id)
	if match_session == null or not match_session.is_player_host():
		return false
	return str(match_session.host_session_id).strip_edges() == str(session_id).strip_edges()

func _generate_room_code() -> String:
	return _generate_id(6)

func _generate_id(length: int) -> String:
	const CHARS := "ABCDEFGHJKLMNPQRSTUVWXYZ23456789"
	var crypto := Crypto.new()
	var random_bytes := crypto.generate_random_bytes(length)
	if random_bytes.size() != length:
		return ""
	var output: String = ""
	for random_byte in random_bytes:
		output += CHARS[int(random_byte) % CHARS.length()]
	return output

func _emit_local_match_assigned(match_info: Dictionary) -> void:
	local_match_assigned.emit(match_info)

func _build_active_match_info_for_session(session_id: String, room: LobbyRoom = null) -> Dictionary:
	if session_id.is_empty():
		return {}
	var candidate_rooms: Array[LobbyRoom] = []
	if room != null:
		candidate_rooms.append(room)
	else:
		var room_id: String = str(room_id_by_session.get(session_id, ""))
		if not room_id.is_empty() and rooms_by_id.has(room_id):
			candidate_rooms.append(rooms_by_id[room_id])
		for room_variant in rooms_by_id.values():
			var candidate := room_variant as LobbyRoom
			if candidate != null and candidate not in candidate_rooms:
				candidate_rooms.append(candidate)
	if match_supervisor == null:
		return {}
	for resolved_room in candidate_rooms:
		if resolved_room == null or resolved_room.status != LobbyRoomScript.STATUS_IN_MATCH:
			continue
		var match_id: String = str(resolved_room.assigned_match_id).strip_edges()
		if match_id.is_empty():
			continue
		var match_session = match_supervisor.get_match(match_id)
		if match_session == null:
			continue
		if match_session.is_dedicated_headless() and not match_supervisor.is_match_ready_for_clients(match_id):
			continue
		var participant_session_id := session_id
		if match_session.get_player_index(participant_session_id) < 0:
			participant_session_id = _get_matching_participant_session_id(
				session_id,
				match_session.player_session_ids
			)
		if participant_session_id.is_empty():
			continue
		return match_session.to_match_info(participant_session_id)
	return {}

func _ensure_match_supervisor() -> void:
	if match_supervisor != null:
		return
	match_supervisor = MatchSupervisorScript.new()
	match_supervisor.name = "MatchSupervisor"
	add_child(match_supervisor)
	match_supervisor.configure(
		advertised_host,
		match_port,
		use_dedicated_match_processes,
		"",
		"",
		allow_in_process_match_fallback
	)
	if not match_supervisor.match_closed.is_connected(_on_match_closed):
		match_supervisor.match_closed.connect(_on_match_closed)

func _merge_account_server_state(source_account_id: String, target_account_id: String) -> void:
	var source_id := source_account_id.strip_edges()
	var target_id := target_account_id.strip_edges()
	if source_id.is_empty() or target_id.is_empty() or source_id == target_id:
		return
	_ensure_deck_store()
	_ensure_friend_store()
	if deck_store != null and deck_store.has_method("merge_account_decks"):
		var deck_result: Dictionary = deck_store.merge_account_decks(source_id, target_id)
		if not bool(deck_result.get("success", false)):
			print("LobbyServer: account deck merge failed: %s" % str(deck_result.get("message", "")))
	if friend_store != null and friend_store.has_method("merge_account_references"):
		var friend_result: Dictionary = friend_store.merge_account_references(source_id, target_id)
		if not bool(friend_result.get("success", false)):
			print("LobbyServer: account friend merge failed: %s" % str(friend_result.get("message", "")))

func _ensure_profile_store() -> void:
	if profile_store != null:
		return
	profile_store = ProfileStoreScript.new()

func _ensure_account_store() -> void:
	if account_store != null:
		return
	account_store = AccountStoreScript.new()
	print(
		"LobbyServer: account store ready path=%s accounts=%d" % [
			account_store.get_storage_path_for_debug(),
			account_store.get_account_count(),
		]
	)

func _ensure_deck_store() -> void:
	if deck_store != null:
		return
	deck_store = DeckStoreScript.new()

func _ensure_friend_store() -> void:
	if friend_store != null:
		return
	friend_store = FriendStoreScript.new()

func _ensure_deck_validator() -> void:
	if deck_validator != null:
		return
	deck_validator = DeckValidatorScript.new()

func _ensure_match_history_store() -> void:
	if match_history_store != null:
		return
	match_history_store = MatchHistoryStoreScript.new(MatchHistoryStoreScript.DEFAULT_STORAGE_FILE_NAME, true)

func _ensure_multiplayer_api() -> MultiplayerAPI:
	if use_default_multiplayer:
		if get_tree() == null:
			return null
		return get_tree().get_multiplayer()
	if multiplayer != null:
		return multiplayer
	if get_tree() == null:
		return null
	var fallback_api := MultiplayerAPI.create_default_interface()
	var target_path: NodePath = get_path()
	if multiplayer_mount_path != NodePath(""):
		target_path = multiplayer_mount_path
	get_tree().set_multiplayer(fallback_api, target_path)
	return multiplayer

func _ensure_network_manager() -> void:
	if network_manager != null:
		return
	network_manager = NetworkManagerScript.new()
	network_manager.name = "LobbyTransport"
	network_manager.trace_file_path = trace_file_path
	network_manager.use_current_scene_relative_path = true
	network_manager.validate_match_command_types = false
	add_child(network_manager)
	if not network_manager.command_received.is_connected(_on_network_command_received):
		network_manager.command_received.connect(_on_network_command_received)
	if not network_manager.peer_disconnected.is_connected(_on_peer_disconnected):
		network_manager.peer_disconnected.connect(_on_peer_disconnected)

func _on_network_command_received(command: Dictionary, sender_info: Dictionary) -> void:
	var peer_id := int(sender_info.get("peer_id", 0))
	if peer_id <= 0:
		return
	_trace("received request %s from peer %d" % [LobbyProtocolScript.get_type(command), peer_id])
	_handle_request(peer_id, command)

func _on_match_closed(match_id: String, room_id: String, final_status: String) -> void:
	if room_id.is_empty() or not rooms_by_id.has(room_id):
		return
	var room: LobbyRoom = rooms_by_id[room_id]
	if room.assigned_match_id != match_id:
		return
	if _room_has_server_bot(room):
		_close_room(room_id)
		if room.is_bot_self_play and final_status == MatchSessionScript.STATUS_ABANDONED:
			_next_bot_self_play_msec = Time.get_ticks_msec() + BOT_SELF_PLAY_RETRY_SECONDS * 1000
		_ensure_server_bot_seeks()
		_broadcast_room_lists()
		return
	if final_status == MatchSessionScript.STATUS_FINISHED:
		room.reset_after_match()
		var now_unix := int(Time.get_unix_time_from_system())
		for session_id in room.members:
			var session: Dictionary = sessions_by_id.get(session_id, {})
			if session.is_empty() or bool(session.get("connected", false)):
				continue
			session["room_disconnected_since_unix"] = now_unix
			sessions_by_id[session_id] = session
		_emit_room_updates(room)
		return
	_close_room(room_id)
	_broadcast_room_lists()

func _get_admin_usernames() -> Array:
	var result: Array = []
	var env_value := OS.get_environment(ADMIN_USERNAMES_ENV).strip_edges()
	if not env_value.is_empty():
		for part in env_value.split(","):
			var name := part.strip_edges().to_lower()
			if not name.is_empty():
				result.append(name)
	if result.is_empty():
		result.append("sprush")
	return result

func _is_admin_username(username: String) -> bool:
	return username.strip_edges().to_lower() in _get_admin_usernames()

func _get_server_version() -> String:
	return AppReleaseInfoScript.get_current_version()

## Always-on connection breadcrumb for the spectator rendezvous. Unlike the
## optional network trace, this print is meant to be visible on a public server
## console so host and spectator logs can be compared line for line.
func _spectate_breadcrumb(stage: String, details: Dictionary = {}) -> void:
	var line := "Spectate breadcrumb role=lobby stage=%s t=%d" % [stage, Time.get_ticks_msec()]
	for key in details.keys():
		line += " %s=%s" % [str(key), str(details[key])]
	print(line)

func _trace(message: String) -> void:
	if not trace_network and trace_file_path.is_empty():
		return
	var line := "LobbyServer[%s] @%s: %s" % [name, str(snappedf(Time.get_unix_time_from_system(), 0.001)), message]
	if trace_network:
		print(line)
	if trace_file_path.is_empty():
		return
	var file := FileAccess.open(trace_file_path, FileAccess.READ_WRITE)
	if file == null:
		file = FileAccess.open(trace_file_path, FileAccess.WRITE)
	if file == null:
		return
	file.seek_end()
	file.store_line(line)
	file.flush()
	file.close()
