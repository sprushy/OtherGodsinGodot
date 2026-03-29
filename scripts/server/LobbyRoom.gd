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
var deck_submission_by_session_id: Dictionary = {}

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
	deck_submission_by_session_id[session_id] = {}
	if host_session_id.is_empty():
		host_session_id = session_id
	refresh_status()
	return true

func remove_member(session_id: String) -> void:
	members.erase(session_id)
	ready_by_session_id.erase(session_id)
	deck_submission_by_session_id.erase(session_id)
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
		if not has_valid_deck(session_id):
			return false
	return true

func set_ready(session_id: String, is_ready: bool) -> bool:
	if not contains_session(session_id):
		return false
	ready_by_session_id[session_id] = is_ready
	refresh_status()
	return true

func reset_after_match() -> void:
	assigned_match_id = ""
	status = STATUS_WAITING
	for session_id in ready_by_session_id.keys():
		ready_by_session_id[session_id] = false
	refresh_status()

func get_ready(session_id: String) -> bool:
	return bool(ready_by_session_id.get(session_id, false))

func submit_deck(session_id: String, deck_name: String, deck_id: String, deck_cards: Dictionary, validation: Dictionary) -> bool:
	if not contains_session(session_id):
		return false
	deck_submission_by_session_id[session_id] = {
		"deck_name": deck_name.strip_edges(),
		"deck_id": deck_id.strip_edges(),
		"cards": deck_cards.duplicate(true),
		"validation": validation.duplicate(true),
	}
	refresh_status()
	return true

func has_valid_deck(session_id: String) -> bool:
	var submission: Dictionary = deck_submission_by_session_id.get(session_id, {})
	if submission.is_empty():
		return false
	var validation: Dictionary = submission.get("validation", {})
	return bool(validation.get("is_valid", false))

func get_deck_submission(session_id: String) -> Dictionary:
	var submission = deck_submission_by_session_id.get(session_id, {})
	if submission is Dictionary:
		return (submission as Dictionary).duplicate(true)
	return {}

func refresh_status() -> void:
	if status == STATUS_IN_MATCH:
		return
	status = STATUS_READY if can_start() else STATUS_WAITING

func to_snapshot(sessions_by_id: Dictionary) -> Dictionary:
	var member_snapshots: Array[Dictionary] = []
	for session_id in members:
		var session: Dictionary = sessions_by_id.get(session_id, {})
		var submission: Dictionary = get_deck_submission(session_id)
		var validation: Dictionary = submission.get("validation", {})
		member_snapshots.append({
			"session_id": session_id,
			"player_name": str(session.get("player_name", "Guest")),
			"is_host": session_id == host_session_id,
			"is_ready": bool(ready_by_session_id.get(session_id, false)),
			"is_connected": bool(session.get("connected", false)),
			"selected_deck_id": str(submission.get("deck_id", "")),
			"selected_deck_name": str(submission.get("deck_name", "")),
			"has_valid_deck": bool(validation.get("is_valid", false)),
			"deck_error": str(validation.get("error", "")),
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
