extends Node
class_name LobbyClient

const LobbyProtocolScript = preload("res://scripts/network/LobbyProtocol.gd")
const AppReleaseInfoScript = preload("res://scripts/client/AppReleaseInfo.gd")
const NetworkManagerScript = preload("res://scripts/Other/NetworkManager.gd")
const LOBBY_EVENT_TYPE := "__lobby_event__"
const CONNECT_ATTEMPT_TIMEOUT_SECONDS := 5.0
const INITIAL_AUTH_RETRY_INTERVAL_SECONDS := 0.1
const INITIAL_AUTH_MAX_ATTEMPTS := 30
const AUTH_RESPONSE_TIMEOUT_SECONDS := 8.0
const ALLOW_INSECURE_ACCOUNT_AUTH_ENV := "OTHERGODS_ALLOW_INSECURE_ACCOUNT_AUTH"
const ALLOW_INSECURE_ACCOUNT_AUTH_SETTING := "application/config/allow_insecure_account_auth"

signal connected_to_lobby()
signal server_version_updated(version: String)
signal login_succeeded(session_id: String, reconnect_token: String, player_name: String)
signal reconnect_succeeded(
	session_id: String,
	reconnect_token: String,
	player_name: String,
	room: Dictionary,
	active_match_info: Dictionary
)
signal room_list_updated(rooms: Array)
signal room_snapshot_updated(snapshot: Dictionary)
signal room_error(message: String)
signal match_assigned(match_info: Dictionary)
signal account_deck_list_received(decks: Array, preferred_deck_id: String)
signal account_deck_saved(deck: Dictionary)
signal account_deck_deleted(deck_id: String)
signal profile_summary_received(summary: Dictionary)
signal friends_state_received(state: Dictionary)
signal account_settings_updated(account: Dictionary)
signal connection_failed(message: String)
signal disconnected_from_lobby()

var current_session_id: String = ""
var current_reconnect_token: String = ""
var current_player_name: String = "Player"
var current_profile_id: String = ""
var current_account_id: String = ""
var current_email: String = ""
var current_username: String = ""
var current_auth_mode: String = "login"
var current_accepts_game_updates: bool = false
var current_server_version: String = ""
var current_allow_friend_observers_to_see_cards: bool = true
var current_active_match_info: Dictionary = {}
var current_room_snapshot: Dictionary = {}
var current_preferred_account_deck_id: String = ""
var trace_network: bool = false
var trace_file_path: String = ""
var multiplayer_mount_path: NodePath = NodePath("")
var use_default_multiplayer: bool = false
var network_manager: Node = null
var _is_authenticated: bool = false

var _pending_account_email: String = ""
var _pending_account_username: String = ""
var _pending_accepts_game_updates: bool = false
var _pending_player_name: String = "Player"
var _pending_session_id: String = ""
var _pending_reconnect_token: String = ""
var _pending_profile_id: String = ""
var _pending_auth_mode: String = "login"
var _pending_password: String = ""
var _connect_attempt_serial: int = 0
var _initial_auth_attempt_serial: int = 0
var _auth_response_serial: int = 0
var _transport_connected_signal_received: bool = false
var _ignore_network_events: bool = false
var _reconnect_fallback_attempted: bool = false
var _password_auth_allowed_for_current_connection: bool = true

func _ready() -> void:
	_ensure_network_manager()

func connect_to_server(
	address: String,
	account_email: String = "",
	session_id: String = "",
	reconnect_token: String = "",
	port: int = LobbyProtocolScript.PORT,
	profile_id: String = "",
	auth_mode: String = "login",
	password: String = "",
	account_username: String = "",
	accepts_game_updates: bool = false
) -> Error:
	_cancel_initial_auth_request()
	_cancel_auth_response_timeout()
	_transport_connected_signal_received = false
	_ignore_network_events = false
	_reconnect_fallback_attempted = false
	_is_authenticated = false
	current_session_id = ""
	current_reconnect_token = ""
	current_profile_id = ""
	current_account_id = ""
	current_email = ""
	current_username = ""
	current_auth_mode = "login"
	current_accepts_game_updates = false
	current_allow_friend_observers_to_see_cards = true
	current_room_snapshot = {}
	current_active_match_info = {}
	current_preferred_account_deck_id = ""
	_set_current_server_version("")
	_pending_account_email = account_email.strip_edges()
	_pending_account_username = account_username.strip_edges()
	_pending_accepts_game_updates = accepts_game_updates
	_pending_session_id = session_id.strip_edges()
	_pending_reconnect_token = reconnect_token.strip_edges()
	_pending_profile_id = profile_id.strip_edges()
	_pending_auth_mode = auth_mode.strip_edges().to_lower()
	if not _pending_auth_mode in ["login", "register", "claim_legacy_account"]:
		_pending_auth_mode = "login"
	_pending_player_name = _pending_account_username
	if _pending_player_name.is_empty():
		_pending_player_name = "Player" if _pending_auth_mode == "login" else _display_name_from_email(_pending_account_email)
	_pending_password = password

	var connect_address: String = address.strip_edges()
	if connect_address.is_empty():
		connect_address = "127.0.0.1"
	_password_auth_allowed_for_current_connection = _can_send_password_auth_to_address(connect_address)
	if _password_auth_would_be_sent_immediately() and not _password_auth_allowed_for_current_connection:
		connection_failed.emit(_insecure_account_auth_message())
		return ERR_UNAUTHORIZED

	_ensure_network_manager()
	if network_manager == null:
		connection_failed.emit("Could not initialize lobby network transport.")
		return ERR_UNAVAILABLE
	var connect_err = network_manager.create_client(connect_address, port)
	if connect_err == OK:
		_arm_connect_attempt_timeout()
	return connect_err

func disconnect_from_server() -> void:
	_ignore_network_events = true
	_cancel_connect_attempt_timeout()
	_cancel_initial_auth_request()
	_cancel_auth_response_timeout()
	_transport_connected_signal_received = false
	_is_authenticated = false
	current_session_id = ""
	current_reconnect_token = ""
	current_profile_id = ""
	current_account_id = ""
	current_email = ""
	current_username = ""
	current_auth_mode = "login"
	current_accepts_game_updates = false
	current_allow_friend_observers_to_see_cards = true
	current_room_snapshot = {}
	current_active_match_info = {}
	current_preferred_account_deck_id = ""
	_pending_player_name = "Player"
	_pending_account_email = ""
	_pending_account_username = ""
	_pending_accepts_game_updates = false
	_pending_session_id = ""
	_pending_reconnect_token = ""
	_pending_profile_id = ""
	_pending_auth_mode = "login"
	_pending_password = ""
	_reconnect_fallback_attempted = false
	_set_current_server_version("")
	if network_manager != null:
		network_manager.disconnect_client()

func is_transport_connected() -> bool:
	if _transport_connected_signal_received and not _ignore_network_events:
		return true
	if network_manager == null:
		return false
	var multiplayer_api: MultiplayerAPI = network_manager.multiplayer
	if multiplayer_api == null:
		return false
	var multiplayer_peer := multiplayer_api.multiplayer_peer
	if multiplayer_peer == null:
		return false
	return multiplayer_peer.get_connection_status() == MultiplayerPeer.CONNECTION_CONNECTED

func is_authenticated() -> bool:
	return _is_authenticated \
		and is_transport_connected() \
		and not current_session_id.strip_edges().is_empty()

func create_room(is_ranked: bool = true, best_of: int = 1) -> void:
	var normalized_best_of := 3 if best_of == 3 else 1
	var match_format := "bo%d_%s" % [normalized_best_of, "rated" if is_ranked else "unrated"]
	_send_request(LobbyProtocolScript.CREATE_ROOM, {
		"is_ranked": is_ranked,
		"best_of": normalized_best_of,
		"match_format": match_format,
	})

func list_rooms() -> void:
	_send_request(LobbyProtocolScript.LIST_ROOMS)

func join_room(room_id: String) -> void:
	_send_request(LobbyProtocolScript.JOIN_ROOM, {"room_id": room_id.strip_edges().to_upper()})

func rejoin_room(room_id: String) -> void:
	_send_request(LobbyProtocolScript.REJOIN_ROOM, {"room_id": room_id.strip_edges().to_upper()})

func observe_room(room_id: String) -> void:
	_send_request(LobbyProtocolScript.OBSERVE_ROOM, {"room_id": room_id.strip_edges().to_upper()})

func leave_room() -> void:
	_send_request(LobbyProtocolScript.LEAVE_ROOM)

func set_ready(is_ready: bool) -> void:
	_send_request(LobbyProtocolScript.SET_READY, {"is_ready": is_ready})

func submit_deck(
	deck_name: String = "",
	cards: Dictionary = {},
	deck_id: String = "",
	special_setup: Dictionary = {},
	reinforcements: Dictionary = {},
	is_purpose_deck: bool = false
) -> void:
	var payload: Dictionary = {
		"deck_id": deck_id.strip_edges(),
	}
	if not deck_name.strip_edges().is_empty():
		payload["deck_name"] = deck_name.strip_edges()
	if not cards.is_empty():
		payload["cards"] = cards.duplicate(true)
	if not special_setup.is_empty():
		payload["special_setup"] = special_setup.duplicate(true)
	if not reinforcements.is_empty():
		payload["reinforcements"] = reinforcements.duplicate(true)
	if is_purpose_deck:
		# Top-level flag survives deck-store sanitization (which strips special_setup
		# to only art-variant keys) and lets the server bypass construction validation
		# for campaign/scenario/smoke decks. Never set for normal matchmaking decks.
		payload["is_purpose_deck"] = true
	_send_request(LobbyProtocolScript.SELECT_DECK, payload)

func request_account_decks() -> void:
	_send_request(LobbyProtocolScript.REQUEST_ACCOUNT_DECKS)

func save_account_deck(
	deck_name: String,
	cards: Dictionary,
	deck_id: String = "",
	special_setup: Dictionary = {},
	reinforcements: Dictionary = {}
) -> void:
	_send_request(LobbyProtocolScript.SAVE_ACCOUNT_DECK, {
		"deck_name": deck_name.strip_edges(),
		"deck_id": deck_id.strip_edges(),
		"cards": cards.duplicate(true),
		"reinforcements": reinforcements.duplicate(true),
		"special_setup": special_setup.duplicate(true),
	})

func delete_account_deck(deck_id: String) -> void:
	_send_request(LobbyProtocolScript.DELETE_ACCOUNT_DECK, {
		"deck_id": deck_id.strip_edges(),
	})

func set_account_preferred_deck(deck_id: String) -> void:
	current_preferred_account_deck_id = deck_id.strip_edges()
	_send_request(LobbyProtocolScript.SET_ACCOUNT_PREFERRED_DECK, {
		"deck_id": current_preferred_account_deck_id,
	})

func set_allow_friend_observers_to_see_cards(allowed: bool) -> void:
	current_allow_friend_observers_to_see_cards = allowed
	_send_request(LobbyProtocolScript.SET_OBSERVER_FRIEND_CARD_VISIBILITY, {
		"allow_friend_observers_to_see_cards": allowed,
	})

func request_profile_summary() -> void:
	_send_request(LobbyProtocolScript.REQUEST_PROFILE_SUMMARY)

func request_friends() -> void:
	_send_request(LobbyProtocolScript.REQUEST_FRIENDS)

func send_friend_request(username: String) -> void:
	_send_request(LobbyProtocolScript.SEND_FRIEND_REQUEST, {
		"username": username.strip_edges(),
	})

func respond_friend_request(request_id: String, accept: bool) -> void:
	_send_request(LobbyProtocolScript.RESPOND_FRIEND_REQUEST, {
		"request_id": request_id.strip_edges(),
		"accept": accept,
	})

func send_deck_to_friend(
	username: String,
	deck_name: String,
	cards: Dictionary,
	special_setup: Dictionary = {},
	reinforcements: Dictionary = {}
) -> void:
	_send_request(LobbyProtocolScript.SEND_DECK_TO_FRIEND, {
		"username": username.strip_edges(),
		"deck_name": deck_name.strip_edges(),
		"cards": cards.duplicate(true),
		"reinforcements": reinforcements.duplicate(true),
		"special_setup": special_setup.duplicate(true),
	})

func respond_deck_share(share_id: String, accept: bool) -> void:
	_send_request(LobbyProtocolScript.RESPOND_DECK_SHARE, {
		"share_id": share_id.strip_edges(),
		"accept": accept,
	})

func update_account_settings(
	current_password: String = "",
	new_email: String = "",
	new_password: String = "",
	accepts_game_updates: bool = false
) -> void:
	if (not current_password.is_empty() or not new_password.is_empty()) and not _password_auth_allowed_for_current_connection:
		connection_failed.emit(_insecure_account_auth_message())
		return
	_send_request(LobbyProtocolScript.UPDATE_ACCOUNT_SETTINGS, {
		"current_password": current_password,
		"new_email": new_email.strip_edges(),
		"new_password": new_password,
		"accepts_game_updates": accepts_game_updates,
	})

func lobby_event(message: Dictionary) -> void:
	var message_type: String = LobbyProtocolScript.get_type(message)
	var payload: Dictionary = LobbyProtocolScript.get_payload(message)
	if message_type == LobbyProtocolScript.ROOM_ERROR:
		_trace("received %s: %s" % [message_type, str(payload.get("message", ""))])
	else:
		_trace("received %s" % message_type)

	match message_type:
		LobbyProtocolScript.HELLO_OK:
			_cancel_initial_auth_request()
			_cancel_auth_response_timeout()
			_is_authenticated = true
			_set_current_server_version(str(payload.get("server_version", "")))
			current_session_id = str(payload.get("session_id", ""))
			current_reconnect_token = str(payload.get("reconnect_token", ""))
			current_player_name = str(payload.get("player_name", _pending_player_name))
			current_profile_id = str(payload.get("profile_id", _pending_profile_id))
			current_account_id = str(payload.get("account_id", ""))
			current_email = str(payload.get("email", _pending_account_email))
			current_username = str(payload.get("username", current_player_name))
			current_auth_mode = str(payload.get("auth_mode", _pending_auth_mode))
			current_accepts_game_updates = bool(payload.get("accepts_game_updates", _pending_accepts_game_updates))
			current_allow_friend_observers_to_see_cards = bool(payload.get("allow_friend_observers_to_see_cards", true))
			var hello_room = payload.get("room", {})
			current_room_snapshot = hello_room.duplicate(true) if hello_room is Dictionary else {}
			var hello_active_match = payload.get("active_match_info", {})
			current_active_match_info = hello_active_match.duplicate(true) if hello_active_match is Dictionary else {}
			current_preferred_account_deck_id = ""
			login_succeeded.emit(current_session_id, current_reconnect_token, current_player_name)
		LobbyProtocolScript.LOBBY_RECONNECT_OK:
			_cancel_initial_auth_request()
			_cancel_auth_response_timeout()
			_is_authenticated = true
			_set_current_server_version(str(payload.get("server_version", "")))
			current_session_id = str(payload.get("session_id", ""))
			current_reconnect_token = str(payload.get("reconnect_token", ""))
			current_player_name = str(payload.get("player_name", _pending_player_name))
			current_profile_id = str(payload.get("profile_id", _pending_profile_id))
			current_account_id = str(payload.get("account_id", ""))
			current_email = str(payload.get("email", _pending_account_email))
			current_username = str(payload.get("username", current_player_name))
			current_auth_mode = str(payload.get("auth_mode", _pending_auth_mode))
			current_accepts_game_updates = bool(payload.get("accepts_game_updates", current_accepts_game_updates))
			current_allow_friend_observers_to_see_cards = bool(payload.get("allow_friend_observers_to_see_cards", true))
			var room = payload.get("room", {})
			current_room_snapshot = room.duplicate(true) if room is Dictionary else {}
			var active_match = payload.get("active_match_info", {})
			current_active_match_info = active_match.duplicate(true) if active_match is Dictionary else {}
			current_preferred_account_deck_id = ""
			reconnect_succeeded.emit(
				current_session_id,
				current_reconnect_token,
				current_player_name,
				payload.get("room", {}),
				current_active_match_info
			)
		LobbyProtocolScript.ROOM_LIST:
			_set_current_server_version(str(payload.get("server_version", current_server_version)))
			room_list_updated.emit(payload.get("rooms", []))
		LobbyProtocolScript.ROOM_SNAPSHOT:
			_set_current_server_version(str(payload.get("server_version", current_server_version)))
			current_room_snapshot = payload.duplicate(true)
			room_snapshot_updated.emit(payload)
		LobbyProtocolScript.ROOM_ERROR:
			var error_message := str(payload.get("message", "Unknown lobby error."))
			if not _is_authenticated:
				_cancel_initial_auth_request()
				_cancel_auth_response_timeout()
				if _try_fallback_to_password_login():
					return
				_trace("auth failed: %s" % error_message)
				disconnect_from_server()
				connection_failed.emit(error_message)
				return
			room_error.emit(error_message)
		LobbyProtocolScript.MATCH_ASSIGNED:
			current_active_match_info = payload.duplicate(true)
			match_assigned.emit(payload)
		LobbyProtocolScript.ACCOUNT_DECK_LIST:
			current_preferred_account_deck_id = str(payload.get("preferred_deck_id", current_preferred_account_deck_id)).strip_edges()
			account_deck_list_received.emit(payload.get("decks", []), current_preferred_account_deck_id)
		LobbyProtocolScript.ACCOUNT_DECK_SAVED:
			account_deck_saved.emit(payload.get("deck", {}))
		LobbyProtocolScript.ACCOUNT_DECK_DELETED:
			account_deck_deleted.emit(str(payload.get("deck_id", "")))
		LobbyProtocolScript.PROFILE_SUMMARY:
			profile_summary_received.emit(payload)
		LobbyProtocolScript.FRIENDS_STATE:
			friends_state_received.emit(payload)
		LobbyProtocolScript.ACCOUNT_SETTINGS_UPDATED:
			var account = payload.get("account", {})
			if account is Dictionary:
				current_email = str((account as Dictionary).get("email", current_email))
				current_username = str((account as Dictionary).get("username", current_username))
				current_accepts_game_updates = bool((account as Dictionary).get("accepts_game_updates", current_accepts_game_updates))
				account_settings_updated.emit((account as Dictionary).duplicate(true))

func _on_connected_to_server() -> void:
	_cancel_connect_attempt_timeout()
	if _ignore_network_events:
		_trace("ignoring connected_to_server after disconnect")
		return
	_transport_connected_signal_received = true
	_trace("connected to server")
	connected_to_lobby.emit()
	_begin_initial_auth_request()

func _begin_initial_auth_request() -> void:
	_initial_auth_attempt_serial += 1
	call_deferred("_try_send_initial_auth_request", _initial_auth_attempt_serial, 1)

func _cancel_initial_auth_request() -> void:
	_initial_auth_attempt_serial += 1

func _arm_auth_response_timeout() -> void:
	var tree := get_tree()
	if tree == null:
		return
	_auth_response_serial += 1
	var expected_serial := _auth_response_serial
	var timeout_timer := tree.create_timer(AUTH_RESPONSE_TIMEOUT_SECONDS)
	timeout_timer.timeout.connect(Callable(self, "_on_auth_response_timeout").bind(expected_serial))

func _cancel_auth_response_timeout() -> void:
	_auth_response_serial += 1

func _on_auth_response_timeout(expected_serial: int) -> void:
	if expected_serial != _auth_response_serial:
		return
	if _is_authenticated or _ignore_network_events:
		return
	if not is_transport_connected():
		return
	_trace("auth response timed out")
	disconnect_from_server()
	connection_failed.emit("The lobby sign-in timed out.")

func _try_send_initial_auth_request(expected_serial: int, attempt: int) -> void:
	if expected_serial != _initial_auth_attempt_serial:
		return
	if _ignore_network_events:
		return
	if not is_transport_connected():
		if attempt >= INITIAL_AUTH_MAX_ATTEMPTS:
			_trace("initial auth request timed out waiting for connected transport")
			disconnect_from_server()
			connection_failed.emit("The lobby connection timed out.")
			return
		var tree := get_tree()
		if tree == null:
			connection_failed.emit("The lobby connection failed.")
			return
		var retry_timer := tree.create_timer(INITIAL_AUTH_RETRY_INTERVAL_SECONDS)
		retry_timer.timeout.connect(
			Callable(self, "_try_send_initial_auth_request").bind(expected_serial, attempt + 1)
		)
		return
	_send_initial_auth_request()

func _send_initial_auth_request() -> void:
	if _should_attempt_pending_lobby_reconnect():
		_send_request(LobbyProtocolScript.REQUEST_RECONNECT_LOBBY, {
			"session_id": _pending_session_id,
			"reconnect_token": _pending_reconnect_token,
		})
		_arm_auth_response_timeout()
		return

	if _pending_auth_mode == "register":
		_send_request(LobbyProtocolScript.REGISTER_ACCOUNT, {
			"email": _pending_account_email,
			"username": _pending_account_username,
			"password": _pending_password,
			"accepts_game_updates": _pending_accepts_game_updates,
		})
		_arm_auth_response_timeout()
		return
	if _pending_auth_mode == "claim_legacy_account":
		_send_request(LobbyProtocolScript.CLAIM_LEGACY_ACCOUNT, {
			"email": _pending_account_email,
			"username": _pending_account_username,
			"password": _pending_password,
			"accepts_game_updates": _pending_accepts_game_updates,
		})
		_arm_auth_response_timeout()
		return
	if _pending_auth_mode == "login":
		_send_request(LobbyProtocolScript.LOGIN_ACCOUNT, {
			"email": _pending_account_email,
			"password": _pending_password,
		})
		_arm_auth_response_timeout()
		return

	_send_request(LobbyProtocolScript.LOGIN_ACCOUNT, {
		"email": _pending_account_email,
		"password": _pending_password,
	})
	_arm_auth_response_timeout()

func _should_attempt_pending_lobby_reconnect() -> bool:
	if _pending_session_id.is_empty() or _pending_reconnect_token.is_empty():
		return false
	return true

func _try_fallback_to_password_login() -> bool:
	if _reconnect_fallback_attempted \
		or _pending_session_id.is_empty() \
		or _pending_reconnect_token.is_empty() \
		or _pending_password.is_empty():
		return false
	if not _password_auth_allowed_for_current_connection:
		connection_failed.emit(_insecure_account_auth_message())
		return false
	_reconnect_fallback_attempted = true
	_pending_session_id = ""
	_pending_reconnect_token = ""
	# A reconnect token can only belong to an account that already exists.
	_pending_auth_mode = "login"
	_send_initial_auth_request()
	return true

func _password_auth_would_be_sent_immediately() -> bool:
	return not _pending_password.is_empty() and not _should_attempt_pending_lobby_reconnect()

func _can_send_password_auth_to_address(address: String) -> bool:
	if _is_loopback_address(address):
		return true
	if OS.is_debug_build() or Engine.is_editor_hint():
		return true
	if _truthy_string(OS.get_environment(ALLOW_INSECURE_ACCOUNT_AUTH_ENV)):
		return true
	return bool(ProjectSettings.get_setting(ALLOW_INSECURE_ACCOUNT_AUTH_SETTING, false))

func _is_loopback_address(address: String) -> bool:
	var normalized := address.strip_edges().to_lower()
	return normalized == "localhost" \
		or normalized == "::1" \
		or normalized == "0:0:0:0:0:0:0:1" \
		or normalized.begins_with("127.")

func _truthy_string(value: String) -> bool:
	match value.strip_edges().to_lower():
		"1", "true", "yes", "on":
			return true
	return false

func _insecure_account_auth_message() -> String:
	return (
		"Password sign-in is disabled for this lobby because the ENet transport is not encrypted. "
		+ "Use a local lobby or enable %s only for trusted/private deployments."
	) % ALLOW_INSECURE_ACCOUNT_AUTH_ENV

func _on_connection_failed() -> void:
	_cancel_connect_attempt_timeout()
	_cancel_initial_auth_request()
	_cancel_auth_response_timeout()
	_transport_connected_signal_received = false
	if _ignore_network_events:
		_trace("ignoring connection_failed after disconnect")
		return
	_is_authenticated = false
	current_session_id = ""
	current_reconnect_token = ""
	current_profile_id = ""
	current_account_id = ""
	current_email = ""
	current_username = ""
	current_auth_mode = "login"
	current_accepts_game_updates = false
	current_room_snapshot = {}
	current_active_match_info = {}
	current_preferred_account_deck_id = ""
	_set_current_server_version("")
	_trace("connection failed")
	connection_failed.emit("The lobby connection failed.")

func _on_server_disconnected() -> void:
	_cancel_connect_attempt_timeout()
	_cancel_initial_auth_request()
	_cancel_auth_response_timeout()
	_transport_connected_signal_received = false
	if _ignore_network_events:
		_trace("ignoring server_disconnected after disconnect")
		return
	_is_authenticated = false
	current_session_id = ""
	current_reconnect_token = ""
	current_profile_id = ""
	current_account_id = ""
	current_email = ""
	current_username = ""
	current_auth_mode = "login"
	current_accepts_game_updates = false
	current_room_snapshot = {}
	current_active_match_info = {}
	current_preferred_account_deck_id = ""
	_set_current_server_version("")
	_trace("server disconnected")
	disconnected_from_lobby.emit()

func _send_request(message_type: String, payload: Dictionary = {}) -> void:
	if network_manager == null:
		return
	if not is_transport_connected():
		_trace("skipping %s: lobby transport is not connected" % message_type)
		return
	_trace("sending %s" % message_type)
	network_manager.request_action(LobbyProtocolScript.make_message(message_type, payload))

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
	if not network_manager.connected_to_server.is_connected(_on_connected_to_server):
		network_manager.connected_to_server.connect(_on_connected_to_server)
	if not network_manager.connection_failed.is_connected(_on_connection_failed):
		network_manager.connection_failed.connect(_on_connection_failed)
	if not network_manager.server_disconnected.is_connected(_on_server_disconnected):
		network_manager.server_disconnected.connect(_on_server_disconnected)
	if not network_manager.game_event_received.is_connected(_on_network_game_event_received):
		network_manager.game_event_received.connect(_on_network_game_event_received)

func _on_network_game_event_received(event_type: String, data: Dictionary) -> void:
	if _ignore_network_events:
		return
	if event_type != LOBBY_EVENT_TYPE:
		return
	lobby_event(data)

func _arm_connect_attempt_timeout() -> void:
	var tree := get_tree()
	if tree == null:
		return
	_connect_attempt_serial += 1
	var expected_serial := _connect_attempt_serial
	var timeout_timer := tree.create_timer(CONNECT_ATTEMPT_TIMEOUT_SECONDS)
	timeout_timer.timeout.connect(Callable(self, "_on_connect_attempt_timer_timeout").bind(expected_serial))

func _cancel_connect_attempt_timeout() -> void:
	_connect_attempt_serial += 1

func _on_connect_attempt_timer_timeout(expected_serial: int) -> void:
	if expected_serial != _connect_attempt_serial:
		return
	_on_connect_attempt_timeout()

func _on_connect_attempt_timeout() -> void:
	if is_transport_connected():
		return
	_trace("connect attempt timed out")
	disconnect_from_server()
	connection_failed.emit("The lobby connection timed out.")

func _set_current_server_version(version: String) -> void:
	var normalized_version := AppReleaseInfoScript.normalize_version(version)
	if current_server_version == normalized_version:
		return
	current_server_version = normalized_version
	server_version_updated.emit(current_server_version)

func _display_name_from_email(email: String) -> String:
	var normalized_email := email.strip_edges()
	var at_index := normalized_email.find("@")
	if at_index > 0:
		var local_part := normalized_email.substr(0, at_index).strip_edges()
		if not local_part.is_empty():
			return local_part
	return "Player"

func _trace(message: String) -> void:
	if not trace_network and trace_file_path.is_empty():
		return
	var line := "LobbyClient[%s]: %s" % [name, message]
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
