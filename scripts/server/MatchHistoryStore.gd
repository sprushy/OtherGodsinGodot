extends RefCounted
class_name MatchHistoryStore

const ServerPathsScript = preload("res://scripts/server/ServerPaths.gd")
const JsonStoreScript = preload("res://scripts/server/JsonStore.gd")
const RankedProgressionScript = preload("res://scripts/server/RankedProgression.gd")
const DEFAULT_STORAGE_FILE_NAME := "match_history.json"

var _storage_file_name: String = DEFAULT_STORAGE_FILE_NAME
var _uses_dedicated_results: bool
var _matches_by_id: Dictionary = {}
var _history_ids_by_profile_id: Dictionary = {}
var _ranked_history_ids_by_account_id: Dictionary = {}
var _bot_deck_match_ids: Array[String] = []
var _sorted_bot_match_ids: Array[String] = []
var _bot_results: Array[Dictionary] = []
var _dedicated_result_files_loaded: Dictionary = {}
var _loaded: bool = false

func _init(storage_file_name: String = DEFAULT_STORAGE_FILE_NAME, uses_dedicated_results: bool = false) -> void:
	_uses_dedicated_results = uses_dedicated_results
	_storage_file_name = storage_file_name.strip_edges()
	if _storage_file_name.is_empty():
		_storage_file_name = DEFAULT_STORAGE_FILE_NAME

func record_completed_match(
	match_session,
	winner_index: int,
	loser_index: int,
	winner_god_name: String,
	loser_god_name: String,
	bot_battle: Dictionary = {}
) -> Dictionary:
	if match_session == null:
		return {"success": false, "message": "Missing match session.", "entry": {}}

	var match_id: String = str(match_session.match_id).strip_edges()
	if match_id.is_empty():
		return {"success": false, "message": "Missing match id.", "entry": {}}

	var player_entries: Array[Dictionary] = []
	var session_ids: Array[String] = match_session.player_session_ids
	for player_index in range(session_ids.size()):
		var session_id: String = str(session_ids[player_index]).strip_edges()
		if session_id.is_empty():
			continue
		player_entries.append(_build_player_entry(match_session, session_id, player_index, winner_index, loser_index, winner_god_name, loser_god_name))

	if player_entries.is_empty():
		return {"success": false, "message": "The match had no player entries to record.", "entry": {}}

	var entry := {
		"match_id": match_id,
		"room_id": str(match_session.room_id),
		"best_of": int(match_session.series_best_of),
		"played_unix": Time.get_unix_time_from_system(),
		"status": "finished",
		"players": player_entries,
	}
	if _uses_dedicated_results:
		# Each match subprocess writes its own file. Both players' results are
		# committed together and no subprocess rewrites another match's history.
		entry["advances_rank"] = _is_ranked_ladder_match(match_session, player_entries)
		var bot_results := _build_bot_deck_results(match_session, player_entries)
		if not bot_results.is_empty():
			entry["bot_deck_results"] = bot_results
		if match_session.is_bot_self_play():
			entry["bot_battle"] = bot_battle.duplicate(true)
		var result_path := _get_dedicated_results_dir().path_join("%s.json" % match_id.sha256_text())
		if FileAccess.file_exists(result_path):
			var existing := JsonStoreScript.load_dictionary(result_path, {}, "MatchHistoryStore")
			if not existing.is_empty():
				return {"success": true, "message": "", "entry": existing}
		if not JsonStoreScript.save_json(result_path, entry, "MatchHistoryStore"):
			return {"success": false, "message": "Could not save dedicated match result.", "entry": {}}
		return {"success": true, "message": "", "entry": entry}

	_ensure_loaded()
	if _matches_by_id.has(match_id):
		return {"success": true, "message": "", "entry": _get_match_entry(match_id)}
	var previous_matches_by_id := _matches_by_id.duplicate(true)
	var previous_history_ids_by_profile_id := _history_ids_by_profile_id.duplicate(true)
	_matches_by_id[match_id] = entry
	_index_result(entry)

	if not _save():
		_matches_by_id = previous_matches_by_id
		_history_ids_by_profile_id = previous_history_ids_by_profile_id
		return {"success": false, "message": "Could not save match history.", "entry": {}}
	return {"success": true, "message": "", "entry": entry.duplicate(true)}

func get_profile_summary(profile_id: String, recent_limit: int = 5, account_id: String = "") -> Dictionary:
	_ensure_loaded()
	if _uses_dedicated_results:
		_load_dedicated_results()
	var resolved_profile_id: String = profile_id.strip_edges()
	if resolved_profile_id.is_empty():
		return _make_empty_summary("")

	var total_wins: int = 0
	var total_losses: int = 0
	var total_draws: int = 0
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
		elif result == "draw":
			total_draws += 1

		var god_name: String = str(player_entry.get("god_name", "Unknown God")).strip_edges()
		if god_name.is_empty():
			god_name = "Unknown God"
		var god_record: Dictionary = god_records_map.get(god_name, {
			"god_name": god_name,
			"wins": 0,
			"losses": 0,
			"draws": 0,
			"games": 0,
		})
		god_record["games"] = int(god_record.get("games", 0)) + 1
		if result == "win":
			god_record["wins"] = int(god_record.get("wins", 0)) + 1
		elif result == "loss":
			god_record["losses"] = int(god_record.get("losses", 0)) + 1
		elif result == "draw":
			god_record["draws"] = int(god_record.get("draws", 0)) + 1
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
			"draws": 0,
			"games": 0,
		})
		deck_record["games"] = int(deck_record.get("games", 0)) + 1
		if result == "win":
			deck_record["wins"] = int(deck_record.get("wins", 0)) + 1
		elif result == "loss":
			deck_record["losses"] = int(deck_record.get("losses", 0)) + 1
		elif result == "draw":
			deck_record["draws"] = int(deck_record.get("draws", 0)) + 1
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

	var season := RankedProgressionScript.season_for_time(Time.get_unix_time_from_system())
	return {
		"profile_id": resolved_profile_id,
		"total_wins": total_wins,
		"total_losses": total_losses,
		"total_draws": total_draws,
		"total_matches": total_wins + total_losses + total_draws,
		"god_records": god_records,
		"deck_records": deck_records,
		"recent_matches": recent_matches,
		"ranked_progress": _get_ranked_progress(account_id, 1, season),
		"ranked_bo3_progress": _get_ranked_progress(account_id, 3, season),
	}

func _is_ranked_ladder_match(match_session, player_entries: Array[Dictionary]) -> bool:
	if not match_session.is_ranked or player_entries.size() != 2:
		return false
	var account_ids: Array[String] = []
	for player_entry in player_entries:
		if match_session.is_bot_session(player_entry["session_id"]):
			continue
		var account_id := str(player_entry["account_id"]).strip_edges()
		if account_id.is_empty() or account_ids.has(account_id):
			return false
		account_ids.append(account_id)
	return not account_ids.is_empty()

func _build_bot_deck_results(match_session, player_entries: Array[Dictionary]) -> Array[Dictionary]:
	var results: Array[Dictionary] = []
	if not match_session.is_ranked or player_entries.size() != 2:
		return results
	for player_entry in player_entries:
		var session_id: String = player_entry["session_id"]
		if not match_session.is_bot_session(session_id):
			continue
		var deck: Dictionary = match_session.registered_player_decks_by_session.get(session_id, {})
		if str(deck.get("bot_god_name", "")).is_empty() or deck.get("cards", {}).is_empty():
			continue
		results.append({
			"god_name": deck["bot_god_name"],
			"bot_name": player_entry["player_name"],
			"list_id": deck.get("bot_list_id", ""),
			"cards": deck["cards"],
			"reinforcements": deck.get("reinforcements", {}),
			"special_setup": deck.get("special_setup", {}),
			"result": player_entry["result"],
			"player_index": player_entry["player_index"],
			"is_self_play": match_session.is_bot_self_play(),
		})
	return results

func get_bot_deck_results() -> Array[Dictionary]:
	_ensure_loaded()
	_load_dedicated_results()
	if _sorted_bot_match_ids.size() == _bot_deck_match_ids.size():
		return _bot_results
	var start := _sorted_bot_match_ids.size()
	var updated_ids := _get_sorted_match_ids(_bot_deck_match_ids)
	if start > 0 and updated_ids[start - 1] != _sorted_bot_match_ids.back():
		start = 0
		_bot_results = []
	else:
		_bot_results = _bot_results.duplicate()
	_sorted_bot_match_ids = updated_ids
	for index in range(start, _sorted_bot_match_ids.size()):
		var match_id := _sorted_bot_match_ids[index]
		var entry: Dictionary = _matches_by_id[match_id]
		if entry.has("bot_deck_result"):
			var legacy: Dictionary = entry["bot_deck_result"].duplicate(true)
			legacy["match_id"] = match_id
			_bot_results.append(legacy)
		for row: Dictionary in entry.get("bot_deck_results", []):
			var result := row.duplicate(true)
			result["match_id"] = match_id
			if entry["bot_deck_results"].size() > 1:
				result["match_id"] = "%s_%d" % [match_id, int(result["player_index"])]
			_bot_results.append(result)
	return _bot_results

func get_recent_bot_matches(limit: int = 50, before_match_id: String = "") -> Dictionary:
	get_bot_deck_results()
	var matches: Array[Dictionary] = []
	var start := _sorted_bot_match_ids.size() - 1 if before_match_id.is_empty() else _sorted_bot_match_ids.find(before_match_id) - 1
	var next_cursor := ""
	for index in range(start, -1, -1):
		var match_id := _sorted_bot_match_ids[index]
		var entry: Dictionary = _matches_by_id[match_id]
		if entry.get("bot_deck_results", []).size() != 2:
			continue
		if matches.size() >= limit:
			next_cursor = matches.back()["match_id"]
			break
		var seats: Array[Dictionary] = []
		for seat: Dictionary in entry["players"]:
			var start_stars := int(seat.get("bot_stars", 0))
			var rank := RankedProgressionScript.summarize_bot_stars(start_stars)
			seats.append({"name": seat["player_name"], "result": seat["result"], "rank": rank["name"], "stars": rank["stars"]})
		matches.append({"match_id": match_id, "played_unix": entry["played_unix"], "players": seats, "battle": entry.get("bot_battle", {})})
	return {"matches": matches, "next_cursor": next_cursor}

func get_human_ladder(usernames: Dictionary, best_of: int) -> Array[Dictionary]:
	_ensure_loaded()
	_load_dedicated_results()
	var season := RankedProgressionScript.season_for_time(Time.get_unix_time_from_system())
	var players: Array[Dictionary] = []
	for account_id in usernames:
		var progress := _get_ranked_progress(account_id, best_of, season)
		players.append({"name": usernames[account_id], "points": progress["points"], "rank": progress["rank_name"], "stars": progress["stars"]})
	return players

func get_current_ranked_progress(account_id: String, best_of: int) -> Dictionary:
	_ensure_loaded()
	if _uses_dedicated_results:
		_load_dedicated_results()
	return _get_ranked_progress(account_id, best_of, RankedProgressionScript.season_for_time(Time.get_unix_time_from_system()))

func _get_ranked_progress(account_id: String, best_of: int, season: int) -> Dictionary:
	if account_id.is_empty():
		return {}
	return RankedProgressionScript.summarize(_replay_ranked_history(account_id, best_of), season)

func get_ranked_match_results(entry: Dictionary) -> Dictionary:
	if not bool(entry.get("advances_rank", false)):
		return {}
	_ensure_loaded()
	_load_dedicated_results()
	var match_id := str(entry["match_id"])
	var stored_entry := _get_match_entry(match_id)
	if not bool(stored_entry.get("advances_rank", false)):
		return {}
	var best_of := int(stored_entry.get("best_of", 1))
	var season := RankedProgressionScript.season_for_time(float(stored_entry["played_unix"]))
	var results := {}
	for player_entry in stored_entry["players"]:
		var account_id := str(player_entry["account_id"])
		if account_id.is_empty():
			continue
		var progress := _replay_ranked_history(account_id, best_of, match_id)
		var before := RankedProgressionScript.summarize(progress, season)
		var outcome := str(player_entry["result"])
		RankedProgressionScript.apply_result(progress, outcome, season)
		var after := RankedProgressionScript.summarize(progress, season)
		results[int(player_entry["player_index"])] = {
			"best_of": best_of,
			"previous_rank_name": before["rank_name"],
			"previous_stars": before["stars"],
			"previous_stars_required": before["stars_required"],
			"rank_name": after["rank_name"],
			"stars": after["stars"],
			"stars_required": after["stars_required"],
			"star_delta": after["last_delta"],
			"loss_protected": outcome == "loss" and int(after["last_delta"]) == 0,
		}
	return results

func _replay_ranked_history(account_id: String, best_of: int, stop_before_match_id: String = "") -> Dictionary:
	var progress := {}
	var match_ids := _get_sorted_match_ids(_ranked_history_ids_by_account_id.get(account_id, []))
	for match_id in match_ids:
		if match_id == stop_before_match_id:
			break
		var entry: Dictionary = _matches_by_id[match_id]
		# Keep older results without a format on the original Bo1 ladder.
		if int(entry.get("best_of", 1)) != best_of:
			continue
		var season := RankedProgressionScript.season_for_time(float(entry["played_unix"]))
		for player_entry in entry["players"]:
			if str(player_entry["account_id"]) == account_id:
				RankedProgressionScript.apply_result(progress, str(player_entry["result"]), season)
				break
	return progress

func _index_result(entry: Dictionary) -> void:
	var match_id := str(entry["match_id"])
	if entry.has("bot_deck_result") or entry.has("bot_deck_results"):
		_bot_deck_match_ids.append(match_id)
	for player_entry in entry["players"]:
		_add_history_id(_history_ids_by_profile_id, str(player_entry["profile_id"]), match_id)
		if bool(entry.get("advances_rank", false)):
			_add_history_id(_ranked_history_ids_by_account_id, str(player_entry["account_id"]), match_id)

func _add_history_id(history_index: Dictionary, owner_id: String, match_id: String) -> void:
	if owner_id.is_empty():
		return
	var history_ids: Array = history_index.get_or_add(owner_id, [])
	if not history_ids.has(match_id):
		history_ids.append(match_id)

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
		"bot_stars": int(submission.get("bot_stars", 0)),
	}

func _get_profile_history_ids(profile_id: String) -> Array[String]:
	return _get_sorted_match_ids(_history_ids_by_profile_id.get(profile_id, []))

func _get_sorted_match_ids(raw_history_ids) -> Array[String]:
	var history_ids: Array[String] = []
	if not (raw_history_ids is Array):
		return history_ids
	for raw_match_id in raw_history_ids:
		history_ids.append(str(raw_match_id))
	history_ids.sort_custom(_match_finished_before)
	return history_ids

func _match_finished_before(left_id: String, right_id: String) -> bool:
	var left_time := float(_matches_by_id.get(left_id, {}).get("played_unix", 0))
	var right_time := float(_matches_by_id.get(right_id, {}).get("played_unix", 0))
	return left_time < right_time if left_time != right_time else left_id < right_id

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
		"total_draws": 0,
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

func _get_dedicated_results_dir() -> String:
	return _get_storage_path().get_basename() + "_results"

func _load_dedicated_results() -> void:
	var results_dir := _get_dedicated_results_dir()
	if not DirAccess.dir_exists_absolute(results_dir):
		return
	for file_name in DirAccess.get_files_at(results_dir):
		if not file_name.ends_with(".json") or _dedicated_result_files_loaded.has(file_name):
			continue
		var entry := JsonStoreScript.load_dictionary(results_dir.path_join(file_name), {}, "MatchHistoryStore")
		var match_id := str(entry.get("match_id", ""))
		if match_id.is_empty() or not (entry.get("players") is Array):
			continue
		_dedicated_result_files_loaded[file_name] = true
		if _matches_by_id.has(match_id):
			continue
		_matches_by_id[match_id] = entry
		_index_result(entry)

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
