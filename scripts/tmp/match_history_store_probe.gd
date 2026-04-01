extends SceneTree

const MatchSessionScript = preload("res://scripts/server/MatchSession.gd")
const MatchHistoryStoreScript = preload("res://scripts/server/MatchHistoryStore.gd")
const ServerPathsScript = preload("res://scripts/server/ServerPaths.gd")

const STORAGE_FILE_NAME := "tmp_match_history_probe.json"

func _initialize() -> void:
	var session := MatchSessionScript.new(
		"match_probe_001",
		"room_probe",
		"127.0.0.1",
		12345,
		["session_alpha", "session_beta"],
		{
			"session_alpha": {
				"deck_id": "deck_alpha",
				"deck_name": "Baldr Trial Deck",
				"cards": {
					"Baldr": 1,
					"Brown Bear": 35,
				},
			},
			"session_beta": {
				"deck_id": "deck_beta",
				"deck_name": "Mummu Trial Deck",
				"cards": {
					"Mummu": 1,
					"Absence": 35,
				},
			},
		},
		{
			"session_alpha": {
				"profile_id": "profile_alpha",
				"account_id": "account_alpha",
				"username": "alpha",
				"player_name": "Alpha",
			},
			"session_beta": {
				"profile_id": "profile_beta",
				"account_id": "account_beta",
				"username": "beta",
				"player_name": "Beta",
			},
		}
	)
	var store = MatchHistoryStoreScript.new(STORAGE_FILE_NAME)
	var first_result: Dictionary = store.record_completed_match(session, 0, 1, "Baldr", "Mummu")
	if not bool(first_result.get("success", false)):
		_fail("record_completed_match failed")
		return

	var duplicate_result: Dictionary = store.record_completed_match(session, 0, 1, "Baldr", "Mummu")
	if not bool(duplicate_result.get("success", false)):
		_fail("duplicate record_completed_match failed")
		return

	var winner_summary: Dictionary = store.get_profile_summary("profile_alpha")
	var loser_summary: Dictionary = store.get_profile_summary("profile_beta")
	if int(winner_summary.get("total_wins", 0)) != 1 or int(winner_summary.get("total_losses", 0)) != 0:
		_fail("winner summary totals were wrong")
		return
	if int(loser_summary.get("total_wins", 0)) != 0 or int(loser_summary.get("total_losses", 0)) != 1:
		_fail("loser summary totals were wrong")
		return
	if _get_god_record_value(winner_summary, "Baldr", "wins") != 1:
		_fail("winner god record was wrong")
		return
	if _get_god_record_value(loser_summary, "Mummu", "losses") != 1:
		_fail("loser god record was wrong")
		return
	if _get_deck_record_value(winner_summary, "Baldr Trial Deck", "wins") != 1:
		_fail("winner deck record was wrong")
		return
	if _get_deck_record_value(loser_summary, "Mummu Trial Deck", "losses") != 1:
		_fail("loser deck record was wrong")
		return

	_cleanup_probe_file()
	print("PASS")
	quit()

func _get_god_record_value(summary: Dictionary, god_name: String, field_name: String) -> int:
	var god_records = summary.get("god_records", [])
	if not (god_records is Array):
		return 0
	for raw_record in god_records:
		if not (raw_record is Dictionary):
			continue
		var god_record: Dictionary = raw_record as Dictionary
		if str(god_record.get("god_name", "")) == god_name:
			return int(god_record.get(field_name, 0))
	return 0

func _get_deck_record_value(summary: Dictionary, deck_name: String, field_name: String) -> int:
	var deck_records = summary.get("deck_records", [])
	if not (deck_records is Array):
		return 0
	for raw_record in deck_records:
		if not (raw_record is Dictionary):
			continue
		var deck_record: Dictionary = raw_record as Dictionary
		if str(deck_record.get("deck_name", "")) == deck_name:
			return int(deck_record.get(field_name, 0))
	return 0

func _cleanup_probe_file() -> void:
	var storage_path: String = ServerPathsScript.get_server_data_file_path(STORAGE_FILE_NAME)
	if FileAccess.file_exists(storage_path):
		DirAccess.remove_absolute(storage_path)

func _fail(message: String) -> void:
	_cleanup_probe_file()
	push_error(message)
	quit(1)
