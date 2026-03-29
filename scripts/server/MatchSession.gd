extends RefCounted
class_name MatchSession

const STATUS_STARTING := "starting"
const STATUS_ACTIVE := "active"
const STATUS_FINISHED := "finished"
const STATUS_ABANDONED := "abandoned"

var match_id: String = ""
var room_id: String = ""
var server_ip: String = "127.0.0.1"
var match_port: int = 12345
var player_session_ids: Array[String] = []
var status: String = STATUS_STARTING
var reconnect_deadline_unix: int = 0

func _init(
	p_match_id: String = "",
	p_room_id: String = "",
	p_server_ip: String = "127.0.0.1",
	p_match_port: int = 12345,
	p_player_session_ids: Array[String] = []
) -> void:
	match_id = p_match_id
	room_id = p_room_id
	server_ip = p_server_ip
	match_port = p_match_port
	player_session_ids = p_player_session_ids.duplicate()

func mark_active() -> void:
	status = STATUS_ACTIVE

func mark_finished() -> void:
	status = STATUS_FINISHED

func mark_abandoned() -> void:
	status = STATUS_ABANDONED

func get_player_index(session_id: String) -> int:
	return player_session_ids.find(session_id)

func to_match_info(session_id: String = "") -> Dictionary:
	return {
		"match_id": match_id,
		"room_id": room_id,
		"server_ip": server_ip,
		"match_port": match_port,
		"player_index": get_player_index(session_id) if not session_id.is_empty() else -1,
		"status": status,
	}
