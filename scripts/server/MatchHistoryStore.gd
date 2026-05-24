extends RefCounted
class_name MatchHistoryStore

const ServerPathsScript = preload("res://scripts/server/ServerPaths.gd")
const JsonStoreScript = preload("res://scripts/server/JsonStore.gd")
const DEFAULT_STORAGE_FILE_NAME := "match_history.json"

var _storage_file_name: String = DEFAULT_STORAGE_FILE_NAME
var _matches_by_id: Dictionary = {}
var _history_ids_by_profile_id: Dictionary = {}
var _loaded: bool = false

func _init(storage_file_name: String = DEFAULT_STORAGE_FILE_NAME) -> void:
	_storage_file_name = storage_file_name.strip_edges()
	if _storage_file_name.is_empty():
		_storage_file_name = DEFAULT_STORAGE_FILE_NAME

func record_completed_match(
	match_session,
	winner_index: int,
	loser_index: int,
	winner_god_name: String,
	loser_god_name: String
) -> Dictionary:
	_ensure_loaded()
	if match_session == null:
		return {"success": false, "message": "Missing match session.", "entry": {}}

	var match_id: String = str(match_session.match_id).strip_edges()
	if match_id.is_empty():
		return {"success": false, "message": "Missing match id.", "entry": {}}

	if _matches_by_id.has(match_id):
		var existing = _matches_by_id.get(match_id, {})
		if existing is Dictionary:
			return {"success": true, "message": "", "entry": (existing as Dictionary).duplicate(true)}
		return {"success": true, "message": "", "entry": {}}

	var player_entries: Array[Dictionary] = []
	var session_ids: Array[String] = match_session.player_session_ids
	for player_index in range(session_ids.size()):
		var session_id: String = str(session_ids[player_index]).strip_edges()
		if session_id.is_empty():
			continue
		player_entries.append(_build_player_entry(match_session, session_id, player_index, winner_index, loser_index, winner_god_name, loser_god_name))

	if player_entries.is_empty():
		return {"success": false, "message": "The match had no player entries to record.", "entry": {}}

	var previous_matches_by_id := _matches_by_id.duplicate(true)
	var previous_history_ids_by_profile_id := _history_ids_by_profile_id.duplicate(true)
	var now_unix: int = int(Time.get_unix_time_from_system())
	var entry := {
		"match_id": match_id,
		"room_id": str(match_session.room_id),
		"played_unix": now_unix,
		"status": "finished",
		"players": player_entries,
	}
	_matches_by_id[match_id] = entry

	for player_entry in player_entries:
		var profile_id: String = str(player_entry.get("profile_id", "")).strip_edges()
		if profile_id.is_empty():
			continue
		var history_ids: Array = _history_ids_by_profile_id.get(profile_id, [])
		if history_ids is Array and not (history_ids as Array).has(match_id):
			var updated_history_ids: Array = (history_ids as Array).duplicate()
			updated_history_ids.append(match_id)
			_history_ids_by_profile_id[profile_id] = updated_history_ids

	if not _save():
		_matches_by_id = previous_matches_by_id
		_history_ids_by_profile_id = previous_history_ids_by_profile_id
		return {"success": false, "message": "Could not save match history.", "entry": {}}
	return {"success": true, "message": "", "entry": entry.duplicate(true)}

func get_profile_summary(profile_id: String, recent_limit: int = 5) -> Dictionary:
	_ensure_loaded()
	var resolved_profile_id: String = profile_id.strip_edges()
	if resolved_profile_id.is_empty():
		return _make_empty_summary("")

	var total_wins: int = 0
	var total_losses: int = 0
	var god_records_map: Dictionary = {}
	var deck_records_map: Dictionary = {}
	var recent_matches: Array[Dictionary] = []
	var history_ids: Array[String] = _get_profile_history_ids(resolved_profile_id)
	var remaining_recent: int = maxi(1, recent_limit)

	for index in range(history_ids.size() - 1, -1, -1):
		var match_id: String = history_ids[index]
		var entry: Dictionary = _get_match_entry(match_id)
		if entry.is_empty():
			continue
		var player_entry: Dictionary = _get_player_entry_for_profile(entry, resolved_profile_id)
		if player_entry.is_empty():
			continue
		var opponent_entry: Dictionary = _get_opponent_entry(entry, resolved_profile_id)
		var result: String = str(player_entry.get("result", "")).strip_edges().to_lower()
		if result == "win":
			total_wins += 1
		elif result == "loss":
			total_losses += 1

		var god_name: String = str(player_entry.get("god_name", "Unknown God")).strip_edges()
		if god_name.is_empty():
			god_name = "Unknown God"
		var god_record: Dictionary = god_records_map.get(god_name, {
			"god_name": god_name,
			"wins": 0,
			"losses": 0,
			"games": 0,
		})
		god_record["games"] = int(god_record.get("games", 0)) + 1
		if result == "win":
			god_record["wins"] = int(god_record.get("wins", 0)) + 1
		elif result == "loss":
			god_record["losses"] = int(god_record.get("losses", 0)) + 1
		god_records_map[god_name] = god_record

		var deck_id: String = str(player_entry.get("deck_id", "")).strip_edges()
		var deck_name: String = str(player_entry.get("deck_name", "")).strip_edges()
		var deck_display_name: String = deck_name if not deck_name.is_empty() else "Unknown Deck"
		var deck_record_key: String = _get_deck_record_key(deck_id, deck_display_name)
		var deck_record: Dictionary = deck_records_map.get(deck_record_key, {
			"deck_id": deck_id,
			"deck_name": deck_display_name,
			"wins": 0,
			"losses": 0,
			"games": 0,
		})
		deck_record["games"] = int(deck_record.get("games", 0)) + 1
		if result == "win":
			deck_record["wins"] = int(deck_record.get("wins", 0)) + 1
		elif result == "loss":
			deck_record["losses"] = int(deck_record.get("losses", 0)) + 1
		deck_records_map[deck_record_key] = deck_record

		if recent_matches.size() < remaining_recent:
			recent_matches.append({
				"match_id": str(entry.get("match_id", "")),
				"played_unix": int(entry.get("played_unix", 0)),
				"result": result,
				"god_name": god_name,
				"deck_name": deck_name,
				"opponent_name": str(opponent_entry.get("player_name", "Opponent")),
				"opponent_god_name": str(opponent_entry.get("god_name", "Unknown God")),
				"opponent_deck_name": str(opponent_entry.get("deck_name", "")),
			})

	var god_records: Array[Dictionary] = []
	for record in god_records_map.values():
		if record is Dictionary:
			god_records.append((record as Dictionary).duplicate(true))
	god_records.sort_custom(_sort_god_records)

	var deck_records: Array[Dictionary] = []
	for record in deck_records_map.values():
		if record is Dictionary:
			deck_records.append((record as Dictionary).duplicate(true))
	deck_records.sort_custom(_sort_deck_records)

	return {
		"profile_id": resolved_profile_id,
		"total_wins": total_wins,
		"total_losses": total_losses,
		"total_matches": total_wins + total_losses,
		"god_records": god_records,
		"deck_records": deck_records,
		"recent_matches": recent_matches,
	}

func _build_player_entry(
	match_session,
	session_id: String,
	player_index: int,
	winner_index: int,
	loser_index: int,
	winner_god_name: String,
	loser_god_name: String
) -> Dictionary:
	var identity: Dictionary = {}
	if match_session != null and match_session.has_method("get_player_identity"):
		identity = match_session.get_player_identity(session_id)
	var submission: Dictionary = {}
	if match_session != null:
		var raw_submission = match_session.player_decks_by_session.get(session_id, {})
		if raw_submission is Dictionary:
			submission = (raw_submission as Dictionary).duplicate(true)

	var result := "draw"
	if player_index == winner_index:
		result = "win"
	elif player_index == loser_index:
		result = "loss"

	var profile_id: String = str(identity.get("profile_id", "")).strip_edges()
	if profile_id.is_empty():
		profile_id = "session_%s" % session_id

	var god_name := ""
	if player_index == winner_index:
		god_name = winner_god_name.strip_edges()
	elif player_index == loser_index:
		god_name = loser_god_name.strip_edges()

	return {
		"session_id": session_id,
		"profile_id": profile_id,
		"account_id": str(identity.get("account_id", "")),
		"username": str(identity.get("username", "")),
		"player_name": str(identity.get("player_name", "Player %d" % [player_index + 1])),
		"player_index": player_index,
		"result": result,
		"god_name": god_name,
		"deck_name": str(submission.get("deck_name", "")),
		"deck_id": str(submission.get("deck_id", "")),
	}

func _get_profile_history_ids(profile_id: String) -> Array[String]:
	var history_ids: Array[String] = []
	var raw_history_ids = _history_ids_by_profile_id.get(profile_id, [])
	if not (raw_history_ids is Array):
		return history_ids
	for raw_match_id in raw_history_ids:
		history_ids.append(str(raw_match_id))
	return history_ids

func _get_match_entry(match_id: String) -> Dictionary:
	var entry = _matches_by_id.get(match_id, {})
	if entry is Dictionary:
		return (entry as Dictionary).duplicate(true)
	return {}

func _get_player_entry_for_profile(entry: Dictionary, profile_id: String) -> Dictionary:
	for raw_player_entry in entry.get("players", []):
		if not (raw_player_entry is Dictionary):
			continue
		var player_entry: Dictionary = raw_player_entry as Dictionary
		if str(player_entry.get("profile_id", "")).strip_edges() == profile_id:
			return player_entry.duplicate(true)
	return {}

func _get_opponent_entry(entry: Dictionary, profile_id: String) -> Dictionary:
	for raw_player_entry in entry.get("players", []):
		if not (raw_player_entry is Dictionary):
			continue
		var player_entry: Dictionary = raw_player_entry as Dictionary
		if str(player_entry.get("profile_id", "")).strip_edges() != profile_id:
			return player_entry.duplicate(true)
	return {}

func _make_empty_summary(profile_id: String) -> Dictionary:
	return {
		"profile_id": profile_id,
		"total_wins": 0,
		"total_losses": 0,
		"total_matches": 0,
		"god_records": [],
		"deck_records": [],
		"recent_matches": [],
	}

func _ensure_loaded() -> void:
	if _loaded:
		return
	_loaded = true
	_matches_by_id = {}
	_history_ids_by_profile_id = {}
	var storage_path: String = _get_storage_path()
	if not FileAccess.file_exists(storage_path):
		return
	var root := JsonStoreScript.load_dictionary(storage_path, {}, "MatchHistoryStore")
	if root.is_empty():
		return
	var stored_matches = root.get("matches_by_id", {})
	var stored_history_ids = root.get("history_ids_by_profile_id", {})
	if stored_matches is Dictionary:
		_matches_by_id = (stored_matches as Dictionary).duplicate(true)
	if stored_history_ids is Dictionary:
		_history_ids_by_profile_id = (stored_history_ids as Dictionary).duplicate(true)

func _save() -> bool:
	var storage_path: String = _get_storage_path()
	return JsonStoreScript.save_json(storage_path, {
		"matches_by_id": _matches_by_id,
		"history_ids_by_profile_id": _history_ids_by_profile_id,
	}, "MatchHistoryStore")

func _get_storage_path() -> String:
	return ServerPathsScript.get_server_data_file_path(_storage_file_name)

func _sort_god_records(a: Dictionary, b: Dictionary) -> bool:
	var a_games: int = int(a.get("games", 0))
	var b_games: int = int(b.get("games", 0))
	if a_games != b_games:
		return a_games > b_games
	var a_wins: int = int(a.get("wins", 0))
	var b_wins: int = int(b.get("wins", 0))
	if a_wins != b_wins:
		return a_wins > b_wins
	return str(a.get("god_name", "")).to_lower() < str(b.get("god_name", "")).to_lower()

func _get_deck_record_key(deck_id: String, deck_name: String) -> String:
	var resolved_deck_id := deck_id.strip_edges()
	if not resolved_deck_id.is_empty():
		return "id:%s" % resolved_deck_id
	var resolved_deck_name := deck_name.strip_edges()
	if not resolved_deck_name.is_empty():
		return "name:%s" % resolved_deck_name.to_lower()
	return "unknown"

func _sort_deck_records(a: Dictionary, b: Dictionary) -> bool:
	var a_games: int = int(a.get("games", 0))
	var b_games: int = int(b.get("games", 0))
	if a_games != b_games:
		return a_games > b_games
	var a_wins: int = int(a.get("wins", 0))
	var b_wins: int = int(b.get("wins", 0))
	if a_wins != b_wins:
		return a_wins > b_wins
	return str(a.get("deck_name", "")).to_lower() < str(b.get("deck_name", "")).to_lower()
