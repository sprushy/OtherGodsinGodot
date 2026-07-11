extends Node
class_name LobbyServer

const LobbyProtocolScript = preload("res://scripts/network/LobbyProtocol.gd")
const AppReleaseInfoScript = preload("res://scripts/client/AppReleaseInfo.gd")
const LobbyRoomScript = preload("res://scripts/server/LobbyRoom.gd")
const MatchSupervisorScript = preload("res://scripts/server/MatchSupervisor.gd")
const MatchSessionScript = preload("res://scripts/server/MatchSession.gd")
const NetworkManagerScript = preload("res://scripts/Other/NetworkManager.gd")
const ProfileStoreScript = preload("res://scripts/server/ProfileStore.gd")
const AccountStoreScript = preload("res://scripts/server/AccountStore.gd")
const DeckStoreScript = preload("res://scripts/server/DeckStore.gd")
const FriendStoreScript = preload("res://scripts/server/FriendStore.gd")
const DeckValidatorScript = preload("res://scripts/server/DeckValidator.gd")
const MatchHistoryStoreScript = preload("res://scripts/server/MatchHistoryStore.gd")
const PracticeAutofillDeckFactoryScript = preload("res://scripts/server/PracticeAutofillDeckFactory.gd")
const LOBBY_EVENT_TYPE := "__lobby_event__"
const SEEK_TIMEOUT_SECONDS := 30 * 60
const SEEK_TIMEOUT_CHECK_INTERVAL_SECONDS := 5.0
const ROOM_MEMBER_RECONNECT_GRACE_SECONDS := 5 * 60
const DEDICATED_MATCH_ASSIGNMENT_POLL_SECONDS := 0.25
const DEDICATED_MATCH_ASSIGNMENT_TIMEOUT_SECONDS := 90.0
const BOT_SESSION_PREFIX := "BOT_"
const SERVER_BOT_AUTH_MODE := "bot"
const SERVER_BOT_TYPE_FUZZ := "practice_fuzz"
const ALLOW_INSECURE_ACCOUNT_AUTH_ENV := "OTHERGODS_ALLOW_INSECURE_ACCOUNT_AUTH"
const ALLOW_INSECURE_ACCOUNT_AUTH_SETTING := "application/config/allow_insecure_account_auth"

signal local_room_snapshot_updated(snapshot: Dictionary)
signal room_list_updated(rooms: Array)
signal local_match_assigned(match_info: Dictionary)
signal status_changed(message: String)

var advertised_host: String = "127.0.0.1"
var lobby_port: int = LobbyProtocolScript.PORT
var match_port: int = LobbyProtocolScript.MATCH_PORT
var is_listening: bool = false
var use_dedicated_match_processes: bool = true
var allow_in_process_match_fallback: bool = true
var server_bots_enabled: bool = true
var server_bot_seek_count: int = 1
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
var profile_store = null
var account_store = null
var deck_store = null
var friend_store = null
var deck_validator = null
var match_history_store = null
var server_bot_deck_factory = null

var _seek_timeout_check_elapsed: float = 0.0
var _server_bot_seed_counter: int = 0

func _ready() -> void:
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
	if not is_listening or rooms_by_id.is_empty():
		_seek_timeout_check_elapsed = 0.0
		return
	_seek_timeout_check_elapsed += delta
	if _seek_timeout_check_elapsed < SEEK_TIMEOUT_CHECK_INTERVAL_SECONDS:
		return
	_seek_timeout_check_elapsed = 0.0
	_expire_stale_seeks()
	_expire_disconnected_room_members()
	_ensure_server_bot_seeks()

func start_server(p_advertised_host: String = "127.0.0.1", port: int = LobbyProtocolScript.PORT, p_match_port: int = LobbyProtocolScript.MATCH_PORT) -> Error:
	if is_listening:
		return OK
	allow_insecure_account_auth = _runtime_allows_insecure_account_auth()

	advertised_host = p_advertised_host.strip_edges()
	if advertised_host.is_empty():
		advertised_host = "127.0.0.1"

	lobby_port = port
	match_port = p_match_port
	_ensure_match_supervisor()
	if match_supervisor != null:
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

	is_listening = true
	_trace("listening on %s:%d" % [advertised_host, lobby_port])
	status_changed.emit("Lobby server listening on %s:%d" % [advertised_host, lobby_port])
	_ensure_server_bot_seeks()
	return OK

func stop_server() -> void:
	if network_manager != null:
		network_manager.disconnect_client()
	is_listening = false
	advertised_host = "127.0.0.1"
	lobby_port = LobbyProtocolScript.PORT
	match_port = LobbyProtocolScript.MATCH_PORT
	_seek_timeout_check_elapsed = 0.0
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
	if str(session.get("reconnect_token", "")) != reconnect_token:
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
		"room": room_snapshot,
		"active_match_info": active_match_info,
	})
	if restored_room != null:
		_broadcast_room_snapshot(restored_room)
	_send_room_list_to_peer(peer_id)
	if restored_room != null and rooms_by_id.has(room_id):
		_try_assign_match(rooms_by_id[room_id])

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
	_send_to_peer(peer_id, LobbyProtocolScript.PROFILE_SUMMARY, match_history_store.get_profile_summary(profile_id))

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
	if not is_listening or not server_bots_enabled or server_bot_seek_count <= 0:
		return
	var available_bot_seek_count := 0
	for room_variant in rooms_by_id.values():
		var room := room_variant as LobbyRoom
		if _is_available_server_bot_seek(room):
			available_bot_seek_count += 1
	while available_bot_seek_count < server_bot_seek_count:
		if _create_server_bot_seek() == null:
			break
		available_bot_seek_count += 1

func _create_server_bot_seek() -> LobbyRoom:
	_ensure_deck_validator()
	_ensure_server_bot_deck_factory()
	if deck_validator == null or server_bot_deck_factory == null:
		return null
	var bot_session_id := _create_server_bot_session()
	if bot_session_id.is_empty():
		return null
	var room := _create_room_for_session(bot_session_id, false, 1)
	if room == null:
		_remove_server_bot_session(bot_session_id)
		return null
	var deck_submission := _build_server_bot_deck_submission(bot_session_id)
	if deck_submission.is_empty():
		_close_room(str(room.room_id))
		return null
	if not room.submit_deck(
		bot_session_id,
		str(deck_submission.get("deck_name", "Practice Bot")),
		str(deck_submission.get("deck_id", "")),
		deck_submission.get("cards", {}),
		deck_submission.get("validation", {}),
		deck_submission.get("special_setup", {}),
		deck_submission.get("reinforcements", {})
	):
		_close_room(str(room.room_id))
		return null
	room.set_ready(bot_session_id, true)
	_emit_room_updates(room)
	return room

func _create_server_bot_session() -> String:
	var session_id := "%s%s" % [BOT_SESSION_PREFIX, _generate_id(9)]
	while sessions_by_id.has(session_id):
		session_id = "%s%s" % [BOT_SESSION_PREFIX, _generate_id(9)]
	var bot_number := _count_server_bot_sessions() + 1
	var bot_name := "Practice Bot %d" % bot_number
	sessions_by_id[session_id] = {
		"session_id": session_id,
		"profile_id": "",
		"account_id": "",
		"email": "",
		"reconnect_token": "",
		"player_name": bot_name,
		"username": bot_name,
		"auth_mode": SERVER_BOT_AUTH_MODE,
		"peer_id": 0,
		"connected": true,
		"room_disconnected_since_unix": 0,
		"is_local": false,
		"is_bot": true,
		"bot_type": SERVER_BOT_TYPE_FUZZ,
	}
	return session_id

func _build_server_bot_deck_submission(bot_session_id: String) -> Dictionary:
	_server_bot_seed_counter += 1
	var deck_seed := int(Time.get_unix_time_from_system()) + _server_bot_seed_counter
	var deck: Dictionary = server_bot_deck_factory.build_random_deck(deck_seed)
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
	return {
		"deck_name": str(deck.get("deck_name", deck.get("name", "Practice Bot"))),
		"deck_id": "server-bot-%s" % bot_session_id,
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

func _count_server_bot_sessions() -> int:
	var count := 0
	for session_id_variant in sessions_by_id.keys():
		if _is_server_bot_session(str(session_id_variant)):
			count += 1
	return count

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
	var visible_player_indices := _get_friend_visible_player_indices(session_id, match_session.player_session_ids)
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
		player_identity_by_session[session_id] = {
			"profile_id": str(session.get("profile_id", "")),
			"account_id": str(session.get("account_id", "")),
			"username": str(session.get("username", "")),
			"player_name": str(session.get("player_name", "Guest")),
			"is_bot": bool(session.get("is_bot", false)),
			"bot_type": str(session.get("bot_type", "")),
		}

	var spectator_visibility := _build_spectator_visibility_by_session(room.members)
	var match_session = match_supervisor.create_match(
		room.room_id,
		room.members,
		player_decks_by_session,
		player_identity_by_session,
		spectator_visibility,
		room.is_ranked,
		room.best_of
	)
	if match_session == null:
		var error_message := str(match_supervisor.last_create_match_error).strip_edges()
		if error_message.is_empty():
			error_message = "Failed to launch the match server."
		_send_error_to_session(room.host_session_id, error_message)
		return
	room.status = LobbyRoomScript.STATUS_IN_MATCH
	room.assigned_match_id = match_session.match_id
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
	for room_id in rooms_by_id.keys():
		var room: LobbyRoom = rooms_by_id[room_id]
		if room.status != LobbyRoomScript.STATUS_IN_MATCH and not _room_has_connected_member(room):
			continue
		var entry := room.to_room_list_entry(sessions_by_id)
		var match_ready := true
		var match_id := str(room.assigned_match_id).strip_edges()
		if room.status == LobbyRoomScript.STATUS_IN_MATCH \
				and match_supervisor != null \
				and not match_id.is_empty() \
				and match_supervisor.get_match(match_id) != null:
			match_ready = match_supervisor.is_match_ready_for_clients(match_id)
		entry["viewer_can_rejoin"] = (
			room.status == LobbyRoomScript.STATUS_IN_MATCH
			and match_ready
			and not _get_matching_participant_session_id(viewer_session_id, room.members).is_empty()
		)
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
		if room.has_waited_for_opponent_too_long(SEEK_TIMEOUT_SECONDS):
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
			session["room_disconnected_since_unix"] = 0
			sessions_by_id[session_id] = session
			return
		session["room_disconnected_since_unix"] = int(Time.get_unix_time_from_system())
		sessions_by_id[session_id] = session
		_broadcast_room_snapshot(room)
	_broadcast_room_lists()

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
	match_history_store = MatchHistoryStoreScript.new()

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
