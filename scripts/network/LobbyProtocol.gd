extends RefCounted
class_name LobbyProtocol

const PORT: int = 22345
const MATCH_PORT: int = 12345

const LOGIN_GUEST := "login_guest"
const LOGIN_ACCOUNT := "login_account"
const REGISTER_ACCOUNT := "register_account"
const CREATE_ROOM := "create_room"
const LIST_ROOMS := "list_rooms"
const JOIN_ROOM := "join_room"
const LEAVE_ROOM := "leave_room"
const SET_READY := "set_ready"
const SELECT_DECK := "select_deck"
const REQUEST_ACCOUNT_DECKS := "request_account_decks"
const SAVE_ACCOUNT_DECK := "save_account_deck"
const DELETE_ACCOUNT_DECK := "delete_account_deck"
const SET_ACCOUNT_PREFERRED_DECK := "set_account_preferred_deck"
const REQUEST_PROFILE_SUMMARY := "request_profile_summary"
const REQUEST_FRIENDS := "request_friends"
const SEND_FRIEND_REQUEST := "send_friend_request"
const RESPOND_FRIEND_REQUEST := "respond_friend_request"
const SEND_DECK_TO_FRIEND := "send_deck_to_friend"
const RESPOND_DECK_SHARE := "respond_deck_share"
const REQUEST_RECONNECT_LOBBY := "request_reconnect_lobby"

const HELLO_OK := "hello_ok"
const ROOM_LIST := "room_list"
const ROOM_SNAPSHOT := "room_snapshot"
const ROOM_ERROR := "room_error"
const MATCH_ASSIGNED := "match_assigned"
const LOBBY_RECONNECT_OK := "lobby_reconnect_ok"
const ACCOUNT_DECK_LIST := "account_deck_list"
const ACCOUNT_DECK_SAVED := "account_deck_saved"
const ACCOUNT_DECK_DELETED := "account_deck_deleted"
const PROFILE_SUMMARY := "profile_summary"
const FRIENDS_STATE := "friends_state"

static func make_message(message_type: String, payload: Dictionary = {}) -> Dictionary:
	return {
		"type": message_type,
		"payload": payload,
	}

static func get_type(message: Dictionary) -> String:
	return str(message.get("type", ""))

static func get_payload(message: Dictionary) -> Dictionary:
	var payload = message.get("payload", {})
	if payload is Dictionary:
		return payload
	return {}

static func validate_request(message: Dictionary) -> String:
	var message_type := get_type(message)
	var payload := get_payload(message)

	if message_type.is_empty():
		return "Missing lobby message type."

	match message_type:
		LOGIN_GUEST:
			if str(payload.get("player_name", "")).strip_edges().is_empty():
				return "Missing player name."
		LOGIN_ACCOUNT, REGISTER_ACCOUNT:
			if str(payload.get("username", "")).strip_edges().is_empty():
				return "Missing username."
			if str(payload.get("password", "")).strip_edges().is_empty():
				return "Missing password."
		JOIN_ROOM:
			if str(payload.get("room_id", "")).strip_edges().is_empty():
				return "Missing room code."
		SELECT_DECK:
			var has_deck_id := not str(payload.get("deck_id", "")).strip_edges().is_empty()
			var has_cards := payload.has("cards") and payload.get("cards") is Dictionary
			if not has_deck_id and not has_cards:
				return "Missing saved deck id or deck cards."
			if has_cards and str(payload.get("deck_name", "")).strip_edges().is_empty():
				return "Missing deck name."
		SAVE_ACCOUNT_DECK:
			if str(payload.get("deck_name", "")).strip_edges().is_empty():
				return "Missing deck name."
			if not payload.has("cards") or not (payload.get("cards") is Dictionary):
				return "Missing deck cards."
		DELETE_ACCOUNT_DECK:
			if str(payload.get("deck_id", "")).strip_edges().is_empty():
				return "Missing deck id."
		SET_ACCOUNT_PREFERRED_DECK:
			if str(payload.get("deck_id", "")).strip_edges().is_empty():
				return "Missing deck id."
		SEND_FRIEND_REQUEST:
			if str(payload.get("username", "")).strip_edges().is_empty():
				return "Missing friend username."
		RESPOND_FRIEND_REQUEST:
			if str(payload.get("request_id", "")).strip_edges().is_empty():
				return "Missing friend request id."
			if not payload.has("accept"):
				return "Missing friend request response."
		SEND_DECK_TO_FRIEND:
			if str(payload.get("username", "")).strip_edges().is_empty():
				return "Missing friend username."
			if str(payload.get("deck_name", "")).strip_edges().is_empty():
				return "Missing deck name."
			if not payload.has("cards") or not (payload.get("cards") is Dictionary):
				return "Missing deck cards."
		RESPOND_DECK_SHARE:
			if str(payload.get("share_id", "")).strip_edges().is_empty():
				return "Missing deck share id."
			if not payload.has("accept"):
				return "Missing deck share response."
		SET_READY:
			if not payload.has("is_ready"):
				return "Missing ready state."
		REQUEST_RECONNECT_LOBBY:
			if str(payload.get("session_id", "")).strip_edges().is_empty():
				return "Missing session id."
			if str(payload.get("reconnect_token", "")).strip_edges().is_empty():
				return "Missing reconnect token."
		CREATE_ROOM, LIST_ROOMS, LEAVE_ROOM, REQUEST_ACCOUNT_DECKS, REQUEST_PROFILE_SUMMARY, REQUEST_FRIENDS:
			pass
		_:
			return "Unknown lobby message type: %s" % message_type

	return ""
