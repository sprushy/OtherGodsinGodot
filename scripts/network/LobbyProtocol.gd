extends RefCounted
class_name LobbyProtocol

const PORT: int = 22345
const MATCH_PORT: int = 12345

const LOGIN_GUEST := "login_guest"
const CREATE_ROOM := "create_room"
const LIST_ROOMS := "list_rooms"
const JOIN_ROOM := "join_room"
const LEAVE_ROOM := "leave_room"
const SET_READY := "set_ready"
const REQUEST_RECONNECT_LOBBY := "request_reconnect_lobby"

const HELLO_OK := "hello_ok"
const ROOM_LIST := "room_list"
const ROOM_SNAPSHOT := "room_snapshot"
const ROOM_ERROR := "room_error"
const MATCH_ASSIGNED := "match_assigned"
const LOBBY_RECONNECT_OK := "lobby_reconnect_ok"

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
		JOIN_ROOM:
			if str(payload.get("room_id", "")).strip_edges().is_empty():
				return "Missing room code."
		SET_READY:
			if not payload.has("is_ready"):
				return "Missing ready state."
		REQUEST_RECONNECT_LOBBY:
			if str(payload.get("session_id", "")).strip_edges().is_empty():
				return "Missing session id."
			if str(payload.get("reconnect_token", "")).strip_edges().is_empty():
				return "Missing reconnect token."
		CREATE_ROOM, LIST_ROOMS, LEAVE_ROOM:
			pass
		_:
			return "Unknown lobby message type: %s" % message_type

	return ""
