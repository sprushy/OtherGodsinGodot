extends RefCounted
class_name LobbyRoom

const MAX_PLAYERS: int = 2
const STATUS_WAITING := "waiting"
const STATUS_READY := "ready"
const STATUS_IN_MATCH := "in_match"

var room_id: String = ""
var host_session_id: String = ""
var assigned_match_id: String = ""
var status: String = STATUS_WAITING
var members: Array[String] = []
var ready_by_session_id: Dictionary = {}

func _init(p_room_id: String = "", p_host_session_id: String = "") -> void:
	room_id = p_room_id
	host_session_id = p_host_session_id

func add_member(session_id: String) -> bool:
	if members.has(session_id):
		return true
	if members.size() >= MAX_PLAYERS:
		return false
	members.append(session_id)
	ready_by_session_id[session_id] = false
	if host_session_id.is_empty():
		host_session_id = session_id
	refresh_status()
	return true

func remove_member(session_id: String) -> void:
	members.erase(session_id)
	ready_by_session_id.erase(session_id)
	if host_session_id == session_id:
		host_session_id = members[0] if not members.is_empty() else ""
	assigned_match_id = ""
	if status == STATUS_IN_MATCH:
		status = STATUS_WAITING
	refresh_status()

func contains_session(session_id: String) -> bool:
	return members.has(session_id)

func is_empty() -> bool:
	return members.is_empty()

func is_full() -> bool:
	return members.size() >= MAX_PLAYERS

func can_start() -> bool:
	if members.size() != MAX_PLAYERS:
		return false
	for session_id in members:
		if not bool(ready_by_session_id.get(session_id, false)):
			return false
	return true

func set_ready(session_id: String, is_ready: bool) -> bool:
	if not contains_session(session_id):
		return false
	ready_by_session_id[session_id] = is_ready
	refresh_status()
	return true

func get_ready(session_id: String) -> bool:
	return bool(ready_by_session_id.get(session_id, false))

func refresh_status() -> void:
	if status == STATUS_IN_MATCH:
		return
	status = STATUS_READY if can_start() else STATUS_WAITING

func to_snapshot(sessions_by_id: Dictionary) -> Dictionary:
	var member_snapshots: Array[Dictionary] = []
	for session_id in members:
		var session: Dictionary = sessions_by_id.get(session_id, {})
		member_snapshots.append({
			"session_id": session_id,
			"player_name": str(session.get("player_name", "Guest")),
			"is_host": session_id == host_session_id,
			"is_ready": bool(ready_by_session_id.get(session_id, false)),
			"is_connected": bool(session.get("connected", false)),
		})

	return {
		"room_id": room_id,
		"host_session_id": host_session_id,
		"assigned_match_id": assigned_match_id,
		"status": status,
		"member_count": members.size(),
		"max_players": MAX_PLAYERS,
		"members": member_snapshots,
	}

func to_room_list_entry(sessions_by_id: Dictionary) -> Dictionary:
	var host_name := "Host"
	if sessions_by_id.has(host_session_id):
		host_name = str(sessions_by_id[host_session_id].get("player_name", "Host"))
	return {
		"room_id": room_id,
		"host_name": host_name,
		"member_count": members.size(),
		"max_players": MAX_PLAYERS,
		"status": status,
	}
