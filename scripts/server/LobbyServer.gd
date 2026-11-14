extends Node
class_name LobbyServer

const LobbyProtocolScript = preload("res://scripts/network/LobbyProtocol.gd")
const AppReleaseInfoScript = preload("res://scripts/client/AppReleaseInfo.gd")
const LobbyRoomScript = preload("res://scripts/server/LobbyRoom.gd")
const MatchSupervisorScript = preload("res://scripts/server/MatchSupervisor.gd")
const MatchSessionScript = preload("res://scripts/server/MatchSession.gd")
const NetworkManagerScript = preload("res://scripts/Other/NetworkManager.gd")
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
const MAX_BOT_SELF_PLAY := 10
const BOT_SELF_PLAY_LIMIT_ENV := "OTHERGODS_BOT_SELF_PLAY_LIMIT"
const BOT_SELF_PLAY_FRAME_LIMIT := 0.055
const BOT_SELF_PLAY_MEMORY_RESERVE := 512 * 1024 * 1024
const BOT_SELF_PLAY_MEMORY_PER_WORKER := 256 * 1024 * 1024
const BOT_SELF_PLAY_RETRY_SECONDS := 30
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
var _ranked_bot_deck_pool := RankedBotDeckPoolScript.new()
var _bot_deck_rng := RandomNumberGenerator.new()
var _lobby_frame_seconds := 0.0
var _next_bot_self_play_msec := 0
var _client_bot_jobs: Dictionary = {}

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
	_expire_disconnected_room_members()
	_expire_abandoned_player_host_matches()
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
	_trace("listening on %s:%d" % [advertised_host, lobby_port])
	status_changed.emit("Lobby server listening on %s:%d" % [advertised_host, lobby_port])
	_ensure_server_bot_seeks()
	return OK

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
				_send_error_to_peer(peer_id, "Join the lobby before observing a match.")
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
		LobbyProtocolScript.REQUEST_BOT_LADDER, LobbyProtocolScript.REQUEST_BOT_DECK:
			_handle_request_bot_ladder(peer_id, message_type, payload)
		LobbyProtocolScript.REQUEST_BOT_MATCH_HISTORY:
			if not _get_session_for_peer(peer_id).is_empty():
				var cursor: String = payload.get("before_match_id", "")
				var page: Dictionary = match_history_store.get_recent_bot_matches(50, cursor)
				page["before_match_id"] = cursor
				_send_to_peer(peer_id, LobbyProtocolScript.BOT_MATCH_HISTORY, page)
		LobbyProtocolScript.REQUEST_BOT_WORK:
			_handle_request_bot_work(peer_id)
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
		LobbyProtocolScript.REQUEST_RECONNECT_LOBBY:
			_handle_reconnect_request(peer_id, payload)
		LobbyProtocolScript.REPORT_HOST_VIABILITY:
			_handle_report_host_viability(peer_id, payload)

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

func _handle_request_bot_work(peer_id: int) -> void:
	var session := _get_session_for_peer(peer_id)
	if session.is_empty() or str(session.get("account_id", "")).is_empty():
		return
	var busy := {}
	for job: Dictionary in _client_bot_jobs.values():
		if int(job.get("expires_unix", 0)) > Time.get_unix_time_from_system():
			if str(job.get("account_id", "")) == str(session["account_id"]):
				return
			busy[str(job.get("deck_a", {}).get("bot_list_id", ""))] = true
			busy[str(job.get("deck_b", {}).get("bot_list_id", ""))] = true
	_ranked_bot_deck_pool.refresh(match_history_store.get_bot_deck_results())
	var pair := _ranked_bot_deck_pool.select_self_play_pair(busy, _bot_deck_rng)
	var deck_a := _validate_server_bot_deck(pair[0]) if pair.size() == 2 else _build_fresh_bot_deck_submission()
	var deck_b := _validate_server_bot_deck(pair[1]) if pair.size() == 2 else _build_fresh_bot_deck_submission()
	if deck_a.is_empty() or deck_b.is_empty():
		return
	for deck in [deck_a, deck_b]:
		deck["bot_god_name"] = deck["god_name"]
		deck["bot_list_id"] = deck["list_id"]
		deck["bot_stars"] = deck["stars"]
	var job_id := _generate_id(32)
	_client_bot_jobs[job_id] = {
		"account_id": str(session["account_id"]),
		"deck_a": deck_a,
		"deck_b": deck_b,
		"expires_unix": int(Time.get_unix_time_from_system()) + 600,
	}
	_send_to_peer(peer_id, LobbyProtocolScript.BOT_WORK_ASSIGNMENT, {
		"job_id": job_id,
		"decks": [deck_a, deck_b],
	})

func _handle_submit_bot_work_result(peer_id: int, payload: Dictionary) -> void:
	var job_id := str(payload.get("job_id", "")).strip_edges()
	var job: Dictionary = _client_bot_jobs.get(job_id, {})
	var session := _get_session_for_peer(peer_id)
	var accepted := false
	if not job.is_empty() and not session.is_empty() \
			and str(job.get("account_id", "")) == str(session.get("account_id", "")) \
			and int(job.get("expires_unix", 0)) >= Time.get_unix_time_from_system():
		var first: Dictionary = job["deck_a"]
		var second: Dictionary = job["deck_b"]
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
		match_session.configure_series_format(1)
		var winner_index := int(payload["winner_index"])
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
	_send_to_peer(peer_id, LobbyProtocolScript.BOT_WORK_RESULT, {
		"success": accepted,
		"message": "Bot match added to the shared ladder." if accepted else "Bot match could not be recorded.",
	})
	if accepted:
		_broadcast_room_lists()

func _handle_request_bot_ladder(peer_id: int, message_type: String, payload: Dictionary) -> void:
	var session := _get_session_for_peer(peer_id)
	if str(session.get("account_id", "")).is_empty():
		_send_error_to_peer(peer_id, "Sign in to view the ladder.")
		return
	_ensure_match_history_store()
	if message_type == LobbyProtocolScript.REQUEST_BOT_DECK:
		_ranked_bot_deck_pool.refresh(match_history_store.get_bot_deck_results())
		var list_id: String = payload["list_id"]
		_send_to_peer(peer_id, LobbyProtocolScript.BOT_DECK, {
			"list_id": list_id,
			"deck": _ranked_bot_deck_pool.get_deck_details(list_id),
		})
		return
	_send_to_peer(peer_id, LobbyProtocolScript.BOT_LADDER, _build_ladder_page(payload))

func _build_ladder_page(request: Dictionary) -> Dictionary:
	var is_paged := request.has("request_id")
	var best_of := int(request["best_of"]) if is_paged else 1
	var ladder: Array[Dictionary] = match_history_store.get_human_ladder(account_store.get_ladder_usernames(), best_of)
	if best_of == 1:
		_ranked_bot_deck_pool.refresh(match_history_store.get_bot_deck_results())
		for god: Dictionary in _ranked_bot_deck_pool.get_ladder_summary()["gods"]:
			var lists: Array = god["lists"].duplicate()
			if not god["challenger"].is_empty():
				lists.append(god["challenger"])
			for bot: Dictionary in lists:
				var rank := RankedProgressionScript.summarize_bot_stars(int(bot["stars"]))
				ladder.append({"name": bot["name"], "list_id": bot["list_id"], "points": bot["stars"],
					"rank": rank["name"], "stars": rank["stars"], "is_bot": true})
	ladder.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return a["name"].nocasecmp_to(b["name"]) < 0 if a["points"] == b["points"] else int(a["points"]) > int(b["points"])
	)
	if not is_paged:
		return {"ladder": _public_ladder_rows(ladder.slice(0, NetworkManagerScript.MAX_NETWORK_PAYLOAD_ITEMS))}
	var last_page := maxi(0, ceili(float(ladder.size()) / LobbyProtocolScript.LADDER_PAGE_SIZE) - 1)
	var page := mini(int(request["page"]), last_page)
	var start := page * LobbyProtocolScript.LADDER_PAGE_SIZE
	return {
		"ladder": _public_ladder_rows(ladder.slice(start, start + LobbyProtocolScript.LADDER_PAGE_SIZE)),
		"request_id": request["request_id"],
		"page": page,
		"last_page": last_page,
	}

func _public_ladder_rows(rows: Array[Dictionary]) -> Array[Dictionary]:
	for row in rows:
		var account_id := str(row.get("account_id", ""))
		row.erase("account_id")
		if account_id.is_empty():
			continue
		var portrait := _get_public_rank_portrait(account_id, row["rank"])
		if not portrait.is_empty():
			row["portrait"] = portrait
	return rows

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
			open_formats[room.is_ranked] = true
	for ranked in [true, false]:
		if not open_formats.has(ranked):
			_create_server_bot_seek(ranked)

func _create_server_bot_seek(ranked: bool) -> LobbyRoom:
	_ensure_deck_validator()
	_ensure_server_bot_deck_factory()
	if deck_validator == null or server_bot_deck_factory == null:
		return null
	var bot_session_id := _create_server_bot_session()
	if bot_session_id.is_empty():
		return null
	var deck_submission := _build_fresh_bot_deck_submission()
	if deck_submission.is_empty():
		_remove_server_bot_session(bot_session_id)
		return null
	var room := _create_room_for_session(bot_session_id, ranked, 1)
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
	room.deck_submission_by_session_id[bot_session_id]["bot_list_id"] = deck_submission["list_id"]
	room.deck_submission_by_session_id[bot_session_id]["bot_god_name"] = deck_submission["god_name"]
	room.deck_submission_by_session_id[bot_session_id]["bot_stars"] = deck_submission["stars"]
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
		var matched := _find_rank_matched_bot_deck(room.best_of, account_id)
		if not matched.is_empty():
			_apply_server_bot_deck(room, matched)
			return true
	var existing := room.get_deck_submission(room.host_session_id)
	if str(existing.get("bot_list_id", "")).is_empty():
		return not existing.is_empty()
	var fresh := _build_fresh_bot_deck_submission()
	if fresh.is_empty():
		return false
	_apply_server_bot_deck(room, fresh)
	return true

func _find_rank_matched_bot_deck(best_of: int, account_id: String) -> Dictionary:
	_ensure_match_history_store()
	_ranked_bot_deck_pool.refresh(match_history_store.get_bot_deck_results())
	var progress: Dictionary = match_history_store.get_current_ranked_progress(account_id, best_of)
	var target_stars := int(progress.get("points", 0))
	var unavailable := _busy_bot_list_ids()
	var deck := _ranked_bot_deck_pool.select_deck(unavailable, _bot_deck_rng, target_stars)
	while not deck.is_empty():
		var submission := _validate_server_bot_deck(deck)
		if not submission.is_empty():
			return submission
		unavailable[deck["list_id"]] = true
		deck = _ranked_bot_deck_pool.select_deck(unavailable, _bot_deck_rng, target_stars)
	return {}

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

func _build_fresh_bot_deck_submission() -> Dictionary:
	_ensure_server_bot_deck_factory()
	_server_bot_seed_counter += 1
	var deck_seed := int(Time.get_unix_time_from_system()) + _server_bot_seed_counter
	var fresh_deck: Dictionary = server_bot_deck_factory.build_random_deck(deck_seed, "", true)
	return _validate_server_bot_deck(fresh_deck)

func _validate_server_bot_deck(deck: Dictionary) -> Dictionary:
	if deck.is_empty():
		return {}
	var validation: Dictionary = deck_validator.validate_deck(
		deck.get("cards", {}),
		deck.get("special_setup", {}),
		deck.get("reinforcements", {})
	)
	if not bool(validation.get("is_valid", false)):
		return {}
	var validation_cards := _duplicate_dictionary(validation.get("cards", {}))
	var validation_reinforcements := _duplicate_dictionary(validation.get("reinforcements", {}))
	var validation_special_setup := _duplicate_dictionary(validation.get("special_setup", {}))
	if validation_cards.is_empty():
		return {}
	var god_name: String = deck["god_name"]
	var list_id := str(deck.get("list_id", ""))
	var deck_name := str(deck["deck_name"]) if not list_id.is_empty() else "%s: Challenger" % RankedBotDeckPoolScript.display_god_name(god_name)
	return {
		"deck_name": deck_name,
		"list_id": list_id,
		"god_name": god_name,
		"stars": int(deck.get("stars", 0)),
		"cards": validation_cards,
		"reinforcements": validation_reinforcements,
		"special_setup": validation_special_setup,
		"validation": validation.duplicate(true),
	}

func _ensure_server_bot_deck_factory() -> void:
	if server_bot_deck_factory != null:
		return
	server_bot_deck_factory = PracticeAutofillDeckFactoryScript.new()

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

func _maintain_bot_self_play() -> void:
	if not server_bots_enabled or not use_dedicated_match_processes or server_bot_self_play_limit <= 0 or match_supervisor == null:
		return
	var background: Array = []
	var foreground := 0
	for match_session in match_supervisor.active_matches.values():
		if match_session.is_bot_self_play():
			background.append(match_session)
		elif match_session.is_dedicated_headless() or not match_session.is_player_host():
			foreground += 1
	var cpu_budget := maxi(0, OS.get_processor_count() - 1 - foreground)
	var target := mini(clampi(server_bot_self_play_limit, 0, MAX_BOT_SELF_PLAY), cpu_budget)
	var memory := OS.get_memory_info()
	var free_bytes := int(memory.get("free", -1))
	var available_bytes := int(memory.get("available", -1))
	var headroom := free_bytes if free_bytes >= 0 else available_bytes
	if available_bytes >= 0 and headroom >= 0:
		headroom = mini(available_bytes, headroom)
	var overloaded := _lobby_frame_seconds > BOT_SELF_PLAY_FRAME_LIMIT or (headroom >= 0 and headroom < BOT_SELF_PLAY_MEMORY_RESERVE)
	if not background.is_empty() and (overloaded or background.size() > target):
		# Shed at most one worker each tick. Human games keep their slots.
		var worker = background.back()
		_next_bot_self_play_msec = Time.get_ticks_msec() + BOT_SELF_PLAY_RETRY_SECONDS * 1000
		match_supervisor.close_match(worker.match_id, MatchSessionScript.STATUS_ABANDONED, true, "Yielded capacity to the lobby or human matches.")
		return
	if overloaded or background.size() >= target or Time.get_ticks_msec() < _next_bot_self_play_msec:
		return
	if headroom < BOT_SELF_PLAY_MEMORY_RESERVE + BOT_SELF_PLAY_MEMORY_PER_WORKER:
		return
	if not match_supervisor.has_background_worker_capacity():
		return
	_launch_bot_self_play()

func _launch_bot_self_play() -> void:
	_ranked_bot_deck_pool.refresh(match_history_store.get_bot_deck_results())
	var pair := _ranked_bot_deck_pool.select_self_play_pair(_busy_bot_list_ids(), _bot_deck_rng)
	var first := _build_fresh_bot_deck_submission() if pair.is_empty() else _validate_server_bot_deck(pair[0])
	var second := _build_fresh_bot_deck_submission() if pair.is_empty() else _validate_server_bot_deck(pair[1])
	if first.is_empty() or second.is_empty() or not RankedBotDeckPoolScript.can_self_play_pair(first, second):
		return
	if first["cards"] == second["cards"] and first["special_setup"] == second["special_setup"]:
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
	_send_to_session(session_id, LobbyProtocolScript.MATCH_ASSIGNED, match_session.to_spectator_match_info(session_id))

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
		if other != room and other.is_ranked == room.is_ranked and _is_available_server_bot_seek(other):
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
	for peer_id in session_id_by_peer.keys():
		var session_id := str(session_id_by_peer.get(peer_id, "")).strip_edges()
		_send_to_peer(int(peer_id), LobbyProtocolScript.ROOM_LIST, {
			"rooms": _build_room_list(session_id),
			"server_version": _get_server_version(),
		})
	room_list_updated.emit(_build_room_list(local_session_id))

func _send_room_list_to_peer(peer_id: int) -> void:
	var session_id := str(session_id_by_peer.get(peer_id, "")).strip_edges()
	_send_to_peer(peer_id, LobbyProtocolScript.ROOM_LIST, {
		"rooms": _build_room_list(session_id),
		"server_version": _get_server_version(),
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
			entry["viewer_can_rejoin"] = (
				not _get_matching_participant_session_id(viewer_session_id, room.members).is_empty()
				and (match_session == null or match_supervisor.is_match_ready_for_clients(match_id))
			)
			if match_session != null and match_session.player_session_ids.size() == 2 and match_session.get_human_player_count() == 1:
				entry["match_player_names"] = match_session.get_public_player_names()
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

func _get_server_version() -> String:
	return AppReleaseInfoScript.get_current_version()

func _trace(message: String) -> void:
	if not trace_network and trace_file_path.is_empty():
		return
	var line := "LobbyServer[%s]: %s" % [name, message]
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
