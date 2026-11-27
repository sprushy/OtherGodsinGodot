extends RefCounted

const OLD_NAME := "Hermes Psychopompus"
const GOD_NAME := "Hermes Psychopompos"
const MIGRATION_DIR := ".hermes_psychopompos_v1"
const POOL_FILES := ["bot_pool_state.json", "bot_pool_state_bo3.json"]
const POOL_SECTIONS := ["lists", "pending", "quarantined_lists"]

static func run(server_data: String) -> Error:
	var migration_dir := server_data.path_join(MIGRATION_DIR)
	var marker := migration_dir.path_join("complete")
	if FileAccess.file_exists(marker) or not DirAccess.dir_exists_absolute(server_data):
		return OK
	var staging_dir := migration_dir.path_join("staging")
	var changed := PackedStringArray()
	for relative in _store_files(server_data):
		var file := FileAccess.open(server_data.path_join(relative), FileAccess.READ)
		if file == null:
			return _report_error(relative, FileAccess.get_open_error())
		var original := file.get_as_text()
		file.close()
		if not original.contains(OLD_NAME):
			continue
		var parsed = JSON.parse_string(original)
		if not parsed is Dictionary:
			return _report_error(relative, ERR_PARSE_ERROR)
		var before := JSON.stringify(parsed)
		var err := _migrate_store(relative, parsed)
		if err != OK:
			return _report_error(relative, err)
		var after := JSON.stringify(parsed)
		if before == after:
			continue
		err = _write_file(staging_dir.path_join(relative), after)
		if err != OK:
			return _report_error(relative, err)
		changed.append(relative)

	# Every changed file is staged before any live file is replaced. If a write
	# fails mid-commit, the next attempt can finish without overwriting originals.
	for relative in changed:
		var target := server_data.path_join(relative)
		var backup := migration_dir.path_join("originals").path_join(relative)
		if not FileAccess.file_exists(backup):
			var err := DirAccess.make_dir_recursive_absolute(backup.get_base_dir())
			if err == OK:
				err = DirAccess.copy_absolute(target, backup + ".tmp")
			if err == OK:
				err = DirAccess.rename_absolute(backup + ".tmp", backup)
			if err != OK:
				return _report_error(relative, err)
		var err := DirAccess.rename_absolute(staging_dir.path_join(relative), target)
		if err != OK:
			return _report_error(relative, err)
	var err := _write_file(marker + ".tmp", "Hermes Psychopompos ladder migration complete.\n")
	if err == OK:
		err = DirAccess.rename_absolute(marker + ".tmp", marker)
	if err != OK:
		return _report_error(marker, err)
	print("Hermes ladder migration completed: updated %d files." % changed.size())
	return OK

static func _store_files(server_data: String) -> PackedStringArray:
	var paths := PackedStringArray()
	for name in ["match_history.json", "accounts.json", "account_decks.json"] + POOL_FILES:
		for suffix in ["", ".bak"]:
			var relative: String = name + suffix
			if FileAccess.file_exists(server_data.path_join(relative)):
				paths.append(relative)
	for directory: String in ["match_history_results", "community_bot_pool"]:
		var absolute := server_data.path_join(directory)
		if not DirAccess.dir_exists_absolute(absolute):
			continue
		for name in DirAccess.get_files_at(absolute):
			if name.ends_with(".json") or name.ends_with(".json.bak"):
				paths.append(directory.path_join(name))
	return paths

static func _migrate_store(path: String, data: Dictionary) -> Error:
	var name := path.get_file().trim_suffix(".bak")
	match path.get_base_dir():
		"match_history_results":
			_rename_match(data)
		"community_bot_pool":
			_rename_deck(data)
			_rename_bot_label(data, "deck_name")
		_:
			match name:
				"match_history.json":
					for entry: Dictionary in data.get("matches_by_id", {}).values():
						_rename_match(entry)
				"accounts.json":
					for account: Dictionary in data.get("accounts_by_id", {}).values():
						for portrait: Dictionary in account.get("rank_badges", {}).values():
							_rename_field(portrait, "card")
				"account_decks.json":
					for decks: Dictionary in data.get("decks_by_account_id", {}).values():
						for deck: Dictionary in decks.values():
							_rename_deck(deck)
				_:
					if name in POOL_FILES:
						return _rename_pool(data)
	return OK

static func _rename_match(entry: Dictionary) -> void:
	for player: Dictionary in entry.get("players", []):
		_rename_field(player, "god_name")
		if str(player.get("session_id", "")).strip_edges().to_upper().begins_with("BOT_"):
			_rename_bot_label(player, "player_name")
			_rename_bot_label(player, "deck_name")
	for result: Dictionary in entry.get("bot_deck_results", []):
		_rename_deck(result)
		_rename_bot_label(result, "bot_name")
	if entry.has("bot_deck_result"):
		_rename_deck(entry["bot_deck_result"])
		_rename_bot_label(entry["bot_deck_result"], "bot_name")

static func _rename_pool(state: Dictionary) -> Error:
	var pools: Dictionary = state.get("by_god", {})
	for name in [OLD_NAME, GOD_NAME]:
		for deck: Dictionary in _pool_decks(pools.get(name, {})):
			_rename_deck(deck)
			_rename_bot_label(deck, "deck_name")
			_rename_bot_label(deck, "self_play_name")
	if pools.has(OLD_NAME):
		if not pools.has(GOD_NAME):
			pools[GOD_NAME] = pools[OLD_NAME]
		elif not _merge_pools(pools[GOD_NAME], pools[OLD_NAME]):
			return ERR_ALREADY_EXISTS
		pools.erase(OLD_NAME)
	var assigned: Dictionary = state.get("assigned_names", {})
	for list_id: String in assigned:
		_rename_bot_label(assigned, list_id)
	return OK

static func _pool_decks(pool: Dictionary) -> Array:
	var decks: Array = []
	for section in POOL_SECTIONS:
		decks.append_array(pool.get(section, []))
	var challenger: Dictionary = pool.get("challenger", {})
	if not challenger.is_empty():
		decks.append(challenger)
	return decks

static func _merge_pools(current: Dictionary, legacy: Dictionary) -> bool:
	var current_by_id := {}
	for deck: Dictionary in _pool_decks(current):
		current_by_id[deck["list_id"]] = deck
	for deck: Dictionary in _pool_decks(legacy):
		var duplicate: Dictionary = current_by_id.get(deck["list_id"], {})
		if duplicate.is_empty():
			continue
		var existing_record := duplicate.duplicate()
		var legacy_record := deck.duplicate()
		existing_record.erase("fingerprint")
		legacy_record.erase("fingerprint")
		if existing_record != legacy_record:
			push_error("Hermes ladder migration: conflicting snapshots for bot %s." % deck["list_id"])
			return false
	for section in POOL_SECTIONS:
		var decks: Array = current.get_or_add(section, [])
		for deck: Dictionary in legacy.get(section, []):
			if not current_by_id.has(deck["list_id"]):
				decks.append(deck)
	var challenger: Dictionary = legacy.get("challenger", {})
	if not challenger.is_empty() and not current_by_id.has(challenger["list_id"]):
		if current.get("challenger", {}).is_empty():
			current["challenger"] = challenger
			current["quarantined_id"] = legacy.get("quarantined_id", "")
		else:
			# Only one trial can run at a time. Queue the other with its record intact.
			current["pending"].push_front(challenger)
	var quarantined: Array = current.get_or_add("quarantined_ids", [])
	for id in legacy.get("quarantined_ids", []):
		if id not in quarantined:
			quarantined.append(id)
	return true

static func _rename_deck(deck: Dictionary) -> void:
	for field in ["god", "god_name", "bot_god_name"]:
		_rename_field(deck, field)
	var changed := false
	for field in ["cards", "reinforcements"]:
		var cards: Dictionary = deck.get(field, {})
		if cards.has(OLD_NAME):
			cards[GOD_NAME] = maxi(int(cards.get(OLD_NAME, 0)), int(cards.get(GOD_NAME, 0)))
			cards.erase(OLD_NAME)
			changed = true
	if changed and deck.has("fingerprint"):
		deck["fingerprint"] = JSON.stringify([
			deck.get("cards", {}), deck.get("reinforcements", {}), deck.get("special_setup", {}),
		]).sha256_text()

static func _rename_field(data: Dictionary, field: String) -> void:
	if data.get(field) == OLD_NAME:
		data[field] = GOD_NAME

static func _rename_bot_label(data: Dictionary, field: String) -> void:
	var label := str(data.get(field, ""))
	if label.begins_with(OLD_NAME + ": "):
		data[field] = GOD_NAME + label.substr(OLD_NAME.length())
	else:
		_rename_field(data, field)

static func _write_file(path: String, content: String) -> Error:
	var err := DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	if err != OK:
		return err
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return FileAccess.get_open_error()
	file.store_string(content)
	file.flush()
	err = file.get_error()
	file.close()
	return err

static func _report_error(path: String, err: Error) -> Error:
	push_error("Hermes ladder migration: %s (%s)." % [path, error_string(err)])
	return err
