extends Node
class_name LobbyServer

const LobbyProtocolScript = preload("res://scripts/network/LobbyProtocol.gd")
const AppReleaseInfoScript = preload("res://scripts/client/AppReleaseInfo.gd")
const LobbyRoomScript = preload("res://scripts/server/LobbyRoom.gd")
const MatchSupervisorScript = preload("res://scripts/server/MatchSupervisor.gd")
const NetworkManagerScript = preload("res://scripts/Other/NetworkManager.gd")
const ProfileStoreScript = preload("res://scripts/server/ProfileStore.gd")
const AccountStoreScript = preload("res://scripts/server/AccountStore.gd")
const DeckStoreScript = preload("res://scripts/server/DeckStore.gd")
const DeckValidatorScript = preload("res://scripts/server/DeckValidator.gd")
const MatchHistoryStoreScript = preload("res://scripts/server/MatchHistoryStore.gd")
const LOBBY_EVENT_TYPE := "__lobby_event__"
const SEEK_TIMEOUT_SECONDS := 30 * 60
const SEEK_TIMEOUT_CHECK_INTERVAL_SECONDS := 5.0

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
var trace_network: bool = false
var trace_file_path: String = ""
var multiplayer_mount_path: NodePath = NodePath("")
var use_default_multiplayer: bool = false

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
var deck_validator = null
var match_history_store = null

var _rng := RandomNumberGenerator.new()
var _seek_timeout_check_elapsed: float = 0.0

func _ready() -> void:
	_rng.randomize()
	_ensure_profile_store()
	_ensure_account_store()
	_ensure_deck_store()
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

func start_server(p_advertised_host: String = "127.0.0.1", port: int = LobbyProtocolScript.PORT, p_match_port: int = LobbyProtocolScript.MATCH_PORT) -> Error:
	if is_listening:
		return OK

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

func create_room_for_local_session(is_ranked: bool = true) -> Dictionary:
	if local_session_id.is_empty():
		return {}
	var room: LobbyRoom = _create_room_for_session(local_session_id, is_ranked)
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
			_handle_login_guest(peer_id, payload)
		LobbyProtocolScript.LOGIN_ACCOUNT:
			_handle_login_account(peer_id, payload)
		LobbyProtocolScript.REGISTER_ACCOUNT:
			_handle_register_account(peer_id, payload)
		LobbyProtocolScript.CREATE_ROOM:
			var session: Dictionary = _get_session_for_peer(peer_id)
			if session.is_empty():
				_send_error_to_peer(peer_id, "Join the lobby before creating a room.")
				return
			var room: LobbyRoom = _create_room_for_session(str(session.get("session_id", "")), bool(payload.get("is_ranked", true)))
			_broadcast_room_snapshot(room)
		LobbyProtocolScript.LIST_ROOMS:
			_send_room_list_to_peer(peer_id)
		LobbyProtocolScript.JOIN_ROOM:
			var join_session: Dictionary = _get_session_for_peer(peer_id)
			if join_session.is_empty():
				_send_error_to_peer(peer_id, "Join the lobby before entering a room.")
				return
			_join_room_for_session(str(join_session.get("session_id", "")), str(payload.get("room_id", "")))
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
				payload.get("special_setup", {})
			)
		LobbyProtocolScript.REQUEST_ACCOUNT_DECKS:
			_handle_request_account_decks(peer_id)
		LobbyProtocolScript.SAVE_ACCOUNT_DECK:
			_handle_save_account_deck(peer_id, payload)
		LobbyProtocolScript.DELETE_ACCOUNT_DECK:
			_handle_delete_account_deck(peer_id, payload)
		LobbyProtocolScript.SET_ACCOUNT_PREFERRED_DECK:
			_handle_set_account_preferred_deck(peer_id, payload)
		LobbyProtocolScript.REQUEST_PROFILE_SUMMARY:
			_handle_request_profile_summary(peer_id)
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
		LobbyProtocolScript.LOGIN_GUEST
	)

func _handle_register_account(peer_id: int, payload: Dictionary) -> void:
	_ensure_account_store()
	_ensure_profile_store()
	if account_store == null or profile_store == null:
		_send_error_to_peer(peer_id, "Account storage is unavailable.")
		return
	var requested_username := str(payload.get("username", ""))
	var requested_password := str(payload.get("password", ""))
	var account_result: Dictionary = account_store.register_account(requested_username, requested_password)
	if not bool(account_result.get("success", false)):
		_send_error_to_peer(peer_id, str(account_result.get("message", "Could not create account.")))
		return
	var account: Dictionary = account_result.get("account", {})
	var profile: Dictionary = profile_store.login_profile(
		"",
		str(account.get("username", requested_username)),
		str(account.get("account_id", "")),
		str(account.get("username", requested_username))
	)
	_complete_login_for_peer(
		peer_id,
		str(profile.get("display_name", requested_username)),
		str(profile.get("profile_id", "")),
		str(account.get("account_id", "")),
		str(account.get("username", requested_username)),
		LobbyProtocolScript.REGISTER_ACCOUNT
	)

func _handle_login_account(peer_id: int, payload: Dictionary) -> void:
	_ensure_account_store()
	_ensure_profile_store()
	if account_store == null or profile_store == null:
		_send_error_to_peer(peer_id, "Account storage is unavailable.")
		return
	var requested_username := str(payload.get("username", ""))
	var requested_password := str(payload.get("password", ""))
	var account_result: Dictionary = account_store.login_account(requested_username, requested_password)
	if not bool(account_result.get("success", false)):
		_send_error_to_peer(peer_id, str(account_result.get("message", "Could not log in.")))
		return
	var account: Dictionary = account_result.get("account", {})
	var profile: Dictionary = profile_store.login_profile(
		"",
		str(account.get("username", requested_username)),
		str(account.get("account_id", "")),
		str(account.get("username", requested_username))
	)
	_complete_login_for_peer(
		peer_id,
		str(profile.get("display_name", requested_username)),
		str(profile.get("profile_id", "")),
		str(account.get("account_id", "")),
		str(account.get("username", requested_username)),
		LobbyProtocolScript.LOGIN_ACCOUNT
	)

func _complete_login_for_peer(
	peer_id: int,
	player_name: String,
	profile_id: String,
	account_id: String = "",
	username: String = "",
	auth_mode: String = LobbyProtocolScript.LOGIN_GUEST
) -> void:
	var existing: Dictionary = _get_session_for_peer(peer_id)
	if existing.is_empty():
		existing = _create_session(player_name, peer_id, false, profile_id, account_id, username, auth_mode)
	else:
		existing["player_name"] = player_name
		existing["profile_id"] = profile_id
		existing["account_id"] = account_id
		existing["username"] = username
		existing["auth_mode"] = auth_mode
		sessions_by_id[str(existing.get("session_id", ""))] = existing
	_trace("login accepted for peer %d as session %s" % [peer_id, str(existing.get("session_id", ""))])
	_send_to_peer(peer_id, LobbyProtocolScript.HELLO_OK, {
		"session_id": str(existing.get("session_id", "")),
		"reconnect_token": str(existing.get("reconnect_token", "")),
		"player_name": str(existing.get("player_name", "Guest")),
		"profile_id": str(existing.get("profile_id", "")),
		"account_id": str(existing.get("account_id", "")),
		"username": str(existing.get("username", "")),
		"auth_mode": str(existing.get("auth_mode", LobbyProtocolScript.LOGIN_GUEST)),
		"server_version": _get_server_version(),
	})
	_send_room_list_to_peer(peer_id)

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
	sessions_by_id[session_id] = session
	session_id_by_peer[peer_id] = session_id

	var room_snapshot: Dictionary = {}
	var active_match_info: Dictionary = {}
	var room_id: String = str(room_id_by_session.get(session_id, ""))
	if not room_id.is_empty() and rooms_by_id.has(room_id):
		var room: LobbyRoom = rooms_by_id[room_id]
		room_snapshot = room.to_snapshot(sessions_by_id)
		active_match_info = _build_active_match_info_for_session(session_id, room)
		_broadcast_room_snapshot(room)
	else:
		_send_room_list_to_peer(peer_id)

	_send_to_peer(peer_id, LobbyProtocolScript.LOBBY_RECONNECT_OK, {
		"session_id": session_id,
		"reconnect_token": reconnect_token,
		"player_name": str(session.get("player_name", "Guest")),
		"profile_id": str(session.get("profile_id", "")),
		"account_id": str(session.get("account_id", "")),
		"username": str(session.get("username", "")),
		"auth_mode": str(session.get("auth_mode", LobbyProtocolScript.LOGIN_GUEST)),
		"server_version": _get_server_version(),
		"room": room_snapshot,
		"active_match_info": active_match_info,
	})

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
		payload.get("special_setup", {})
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

func _create_session(
	player_name: String,
	peer_id: int,
	is_local: bool,
	profile_id: String = "",
	account_id: String = "",
	username: String = "",
	auth_mode: String = LobbyProtocolScript.LOGIN_GUEST
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
		"reconnect_token": reconnect_token,
		"player_name": clean_name,
		"username": username.strip_edges(),
		"auth_mode": auth_mode,
		"peer_id": peer_id,
		"connected": true,
		"is_local": is_local,
	}
	sessions_by_id[session_id] = session
	if peer_id > 0 and not is_local:
		session_id_by_peer[peer_id] = session_id
	return session

func _create_room_for_session(session_id: String, is_ranked: bool = true) -> LobbyRoom:
	var existing_room_id: String = str(room_id_by_session.get(session_id, ""))
	if not existing_room_id.is_empty() and rooms_by_id.has(existing_room_id):
		return rooms_by_id[existing_room_id]
	_prune_excess_open_seeks_for_session(session_id)

	var room_id: String = _generate_room_code()
	while rooms_by_id.has(room_id):
		room_id = _generate_room_code()

	var room: LobbyRoom = LobbyRoomScript.new(room_id, session_id)
	room.is_ranked = is_ranked
	room.add_member(session_id)
	rooms_by_id[room_id] = room
	room_id_by_session[session_id] = room_id
	_emit_room_updates(room)
	return room

func _join_room_for_session(session_id: String, room_id: String) -> void:
	var normalized_room_id: String = room_id.strip_edges().to_upper()
	if normalized_room_id.is_empty():
		_send_error_to_session(session_id, "Enter a room code first.")
		return
	if not rooms_by_id.has(normalized_room_id):
		_send_error_to_session(session_id, "Room %s was not found." % normalized_room_id)
		return
	if room_id_by_session.has(session_id):
		var current_room_id: String = str(room_id_by_session.get(session_id, ""))
		if current_room_id == normalized_room_id:
			_broadcast_room_snapshot(rooms_by_id[normalized_room_id])
			return
		_send_error_to_session(session_id, "Leave your current room before joining a new one.")
		return

	var room: LobbyRoom = rooms_by_id[normalized_room_id]
	if room.status == LobbyRoomScript.STATUS_IN_MATCH:
		_send_error_to_session(session_id, "Room %s is already in a match." % normalized_room_id)
		return
	if room.is_full():
		_send_error_to_session(session_id, "Room %s is already full." % normalized_room_id)
		return

	if not room.add_member(session_id):
		_send_error_to_session(session_id, "Unable to join room %s." % normalized_room_id)
		return

	room_id_by_session[session_id] = normalized_room_id
	_emit_room_updates(room)

func _leave_room_for_session(session_id: String) -> void:
	var room_id: String = str(room_id_by_session.get(session_id, ""))
	if room_id.is_empty() or not rooms_by_id.has(room_id):
		return

	var room: LobbyRoom = rooms_by_id[room_id]
	room.remove_member(session_id)
	room_id_by_session.erase(session_id)

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
	if room.can_start() and room.status != LobbyRoomScript.STATUS_IN_MATCH:
		_assign_match(room)

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
		}

	var match_session = match_supervisor.create_match(
		room.room_id,
		room.members,
		player_decks_by_session,
		player_identity_by_session,
		room.is_ranked
	)
	if match_session == null:
		var error_message := str(match_supervisor.last_create_match_error).strip_edges()
		if error_message.is_empty():
			error_message = "Failed to launch the match server."
		_send_error_to_session(room.host_session_id, error_message)
		return
	room.status = LobbyRoomScript.STATUS_IN_MATCH
	room.assigned_match_id = match_session.match_id
	var local_match_info: Dictionary = {}

	for session_id in room.members:
		var match_info: Dictionary = match_session.to_match_info(session_id)
		_send_to_session(session_id, LobbyProtocolScript.MATCH_ASSIGNED, match_info)
		if session_id == local_session_id:
			local_match_info = match_info.duplicate(true)
	_emit_room_updates(room)
	if not local_match_info.is_empty():
		call_deferred("_emit_local_match_assigned", local_match_info)

func _emit_room_updates(room: LobbyRoom) -> void:
	_broadcast_room_snapshot(room)
	_broadcast_room_lists()

func _submit_deck_for_session(
	session_id: String,
	deck_name: String,
	deck_id: String,
	cards,
	special_setup = {}
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
		var submitted_special_setup = special_setup
		if submitted_special_setup is Dictionary:
			resolved_special_setup = (submitted_special_setup as Dictionary).duplicate(true)
	_ensure_deck_validator()
	if deck_validator == null:
		_send_error_to_session(session_id, "Deck validator is unavailable.")
		return
	var validation: Dictionary = deck_validator.validate_deck(resolved_cards, resolved_special_setup)
	var room: LobbyRoom = rooms_by_id[room_id]
	if not room.submit_deck(
		session_id,
		resolved_deck_name,
		resolved_deck_id,
		validation.get("cards", {}),
		validation,
		validation.get("special_setup", {})
	):
		_send_error_to_session(session_id, "Unable to store selected deck.")
		return
	var deck_is_valid := bool(validation.get("is_valid", false))
	room.set_ready(session_id, deck_is_valid)
	_emit_room_updates(room)
	if deck_is_valid and room.can_start() and room.status != LobbyRoomScript.STATUS_IN_MATCH:
		_assign_match(room)

func _broadcast_room_snapshot(room: LobbyRoom) -> void:
	var snapshot: Dictionary = room.to_snapshot(sessions_by_id)
	snapshot["server_version"] = _get_server_version()
	for session_id in room.members:
		_send_to_session(session_id, LobbyProtocolScript.ROOM_SNAPSHOT, snapshot)
		if session_id == local_session_id:
			local_room_snapshot_updated.emit(snapshot)

func _broadcast_room_lists() -> void:
	var rooms: Array = _build_room_list()
	for peer_id in session_id_by_peer.keys():
		_send_to_peer(int(peer_id), LobbyProtocolScript.ROOM_LIST, {
			"rooms": rooms,
			"server_version": _get_server_version(),
		})
	room_list_updated.emit(rooms)

func _send_room_list_to_peer(peer_id: int) -> void:
	_send_to_peer(peer_id, LobbyProtocolScript.ROOM_LIST, {
		"rooms": _build_room_list(),
		"server_version": _get_server_version(),
	})

func _build_room_list() -> Array:
	var rooms: Array = []
	for room_id in rooms_by_id.keys():
		rooms.append(rooms_by_id[room_id].to_room_list_entry(sessions_by_id))
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
		if session_id == local_session_id:
			local_room_snapshot_updated.emit({})
		if not message.strip_edges().is_empty():
			_send_error_to_session(session_id, message)

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
			return
		_broadcast_room_snapshot(room)
	_broadcast_room_lists()

func _generate_room_code() -> String:
	return _generate_id(6)

func _generate_id(length: int) -> String:
	const CHARS := "ABCDEFGHJKLMNPQRSTUVWXYZ23456789"
	var output: String = ""
	for _i in length:
		output += CHARS[_rng.randi_range(0, CHARS.length() - 1)]
	return output

func _emit_local_match_assigned(match_info: Dictionary) -> void:
	local_match_assigned.emit(match_info)

func _build_active_match_info_for_session(session_id: String, room: LobbyRoom = null) -> Dictionary:
	if session_id.is_empty():
		return {}
	var resolved_room: LobbyRoom = room
	if resolved_room == null:
		var room_id: String = str(room_id_by_session.get(session_id, ""))
		if room_id.is_empty() or not rooms_by_id.has(room_id):
			return {}
		resolved_room = rooms_by_id[room_id]
	if resolved_room == null:
		return {}
	if resolved_room.status != LobbyRoomScript.STATUS_IN_MATCH:
		return {}
	var match_id: String = str(resolved_room.assigned_match_id).strip_edges()
	if match_id.is_empty() or match_supervisor == null:
		return {}
	var match_session = match_supervisor.get_match(match_id)
	if match_session == null:
		return {}
	return match_session.to_match_info(session_id)

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

func _ensure_profile_store() -> void:
	if profile_store != null:
		return
	profile_store = ProfileStoreScript.new()

func _ensure_account_store() -> void:
	if account_store != null:
		return
	account_store = AccountStoreScript.new()

func _ensure_deck_store() -> void:
	if deck_store != null:
		return
	deck_store = DeckStoreScript.new()

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

func _on_match_closed(match_id: String, room_id: String, _final_status: String) -> void:
	if room_id.is_empty() or not rooms_by_id.has(room_id):
		return
	var room: LobbyRoom = rooms_by_id[room_id]
	if room.assigned_match_id != match_id:
		return
	room.reset_after_match()
	_emit_room_updates(room)

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
