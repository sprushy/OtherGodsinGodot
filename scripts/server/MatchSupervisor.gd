extends Node
class_name MatchSupervisor

const MatchSessionScript = preload("res://scripts/server/MatchSession.gd")

signal match_created(match_session)
signal match_closed(match_id: String)

var server_ip: String = "127.0.0.1"
var default_match_port: int = 12345
var active_matches: Dictionary = {}

var _rng := RandomNumberGenerator.new()

func _ready() -> void:
	_rng.randomize()

func configure(p_server_ip: String, p_default_match_port: int) -> void:
	server_ip = p_server_ip
	default_match_port = p_default_match_port

func create_match(room_id: String, player_session_ids: Array[String]):
	var match_id: String = _generate_match_id()
	while active_matches.has(match_id):
		match_id = _generate_match_id()

	var session := MatchSessionScript.new(
		match_id,
		room_id,
		server_ip,
		default_match_port,
		player_session_ids
	)
	session.mark_active()
	active_matches[match_id] = session
	match_created.emit(session)
	return session

func get_match(match_id: String):
	return active_matches.get(match_id, null)

func close_match(match_id: String) -> void:
	if not active_matches.has(match_id):
		return
	var session = active_matches[match_id]
	session.mark_finished()
	active_matches.erase(match_id)
	match_closed.emit(match_id)

func clear() -> void:
	active_matches.clear()

func _generate_match_id() -> String:
	const CHARS := "ABCDEFGHJKLMNPQRSTUVWXYZ23456789"
	var output: String = "match_"
	for _i in 8:
		output += CHARS[_rng.randi_range(0, CHARS.length() - 1)]
	return output
