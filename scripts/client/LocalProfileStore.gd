extends RefCounted
class_name LocalProfileStore

const STORAGE_PATH := "user://player_profiles.json"
const LEGACY_DECK_PATH := "user://saved_deck.json"
const DEFAULT_PROFILE_NAME := "Player"
const DEFAULT_DECK_NAME := "Default Deck"
const AUTH_MODE_GUEST := "guest"
const AUTH_MODE_LOGIN := "login"
const AUTH_MODE_REGISTER := "register"
const DISMISSED_RELEASE_VERSION_KEY := "dismissed_release_version"

var _data: Dictionary = {}
var _loaded: bool = false
var _rng := RandomNumberGenerator.new()

func _init() -> void:
	_rng.randomize()

func restore_last_profile(default_name: String = DEFAULT_PROFILE_NAME) -> Dictionary:
	_ensure_loaded()
	var current_profile_id := str(_data.get("current_profile_id", "")).strip_edges()
	if not current_profile_id.is_empty():
		var existing := get_profile(current_profile_id)
		if not existing.is_empty():
			var restored := remember_profile(current_profile_id, str(existing.get("display_name", default_name)))
			_import_legacy_deck_if_needed(str(restored.get("profile_id", "")))
			return restored
	var created := ensure_profile("", default_name, true)
	_import_legacy_deck_if_needed(str(created.get("profile_id", "")))
	return created

func ensure_profile(profile_id: String = "", display_name: String = DEFAULT_PROFILE_NAME, make_current: bool = true) -> Dictionary:
	_ensure_loaded()
	var clean_name := display_name.strip_edges()
	if clean_name.is_empty():
		clean_name = DEFAULT_PROFILE_NAME

	var profiles := _get_profiles()
	var resolved_profile_id := profile_id.strip_edges()
	var now_unix := int(Time.get_unix_time_from_system())
	if resolved_profile_id.is_empty():
		resolved_profile_id = _generate_id("profile_", 12)

	var profile: Dictionary = profiles.get(resolved_profile_id, {
		"profile_id": resolved_profile_id,
		"created_unix": now_unix,
	})
	profile["profile_id"] = resolved_profile_id
	profile["display_name"] = clean_name
	if not profile.has("created_unix"):
		profile["created_unix"] = now_unix
	profile["last_seen_unix"] = now_unix
	profiles[resolved_profile_id] = profile
	_data["profiles"] = profiles
	if make_current:
		_data["current_profile_id"] = resolved_profile_id
	_save()
	return profile.duplicate(true)

func remember_profile(profile_id: String, display_name: String = DEFAULT_PROFILE_NAME) -> Dictionary:
	return ensure_profile(profile_id, display_name, true)

func get_profile(profile_id: String) -> Dictionary:
	_ensure_loaded()
	var profiles := _get_profiles()
	var existing = profiles.get(profile_id, {})
	if existing is Dictionary:
		return (existing as Dictionary).duplicate(true)
	return {}

func get_current_profile_id() -> String:
	_ensure_loaded()
	return str(_data.get("current_profile_id", "")).strip_edges()

func save_deck(profile_id: String, deck_name: String, cards: Dictionary, deck_id: String = "") -> Dictionary:
	var profile := ensure_profile(profile_id, DEFAULT_PROFILE_NAME, true)
	var resolved_profile_id := str(profile.get("profile_id", "")).strip_edges()
	var clean_name := deck_name.strip_edges()
	if clean_name.is_empty():
		clean_name = DEFAULT_DECK_NAME

	var deck_bucket := _get_deck_bucket(resolved_profile_id, true)
	var resolved_deck_id := deck_id.strip_edges()
	if resolved_deck_id.is_empty() or not deck_bucket.has(resolved_deck_id):
		resolved_deck_id = _generate_id("deck_", 12)

	var now_unix := int(Time.get_unix_time_from_system())
	var deck_entry: Dictionary = deck_bucket.get(resolved_deck_id, {
		"deck_id": resolved_deck_id,
		"created_unix": now_unix,
	})
	deck_entry["deck_id"] = resolved_deck_id
	deck_entry["name"] = clean_name
	deck_entry["cards"] = _sanitize_cards(cards)
	if not deck_entry.has("created_unix"):
		deck_entry["created_unix"] = now_unix
	deck_entry["updated_unix"] = now_unix
	deck_bucket[resolved_deck_id] = deck_entry
	_set_deck_bucket(resolved_profile_id, deck_bucket)
	remember_last_selected_deck(resolved_profile_id, resolved_deck_id)
	_save()
	return deck_entry.duplicate(true)

func list_decks(profile_id: String) -> Array[Dictionary]:
	_ensure_loaded()
	var resolved_profile_id := profile_id.strip_edges()
	if resolved_profile_id.is_empty():
		return []
	var deck_bucket := _get_deck_bucket(resolved_profile_id, false)
	var decks: Array[Dictionary] = []
	for raw_deck in deck_bucket.values():
		if raw_deck is Dictionary:
			decks.append((raw_deck as Dictionary).duplicate(true))
	decks.sort_custom(_sort_decks)
	return decks

func get_deck(profile_id: String, deck_id: String) -> Dictionary:
	_ensure_loaded()
	var deck_bucket := _get_deck_bucket(profile_id.strip_edges(), false)
	var raw_deck = deck_bucket.get(deck_id.strip_edges(), {})
	if raw_deck is Dictionary:
		return (raw_deck as Dictionary).duplicate(true)
	return {}

func replace_decks(profile_id: String, decks: Array[Dictionary]) -> void:
	var profile := ensure_profile(profile_id, DEFAULT_PROFILE_NAME, true)
	var resolved_profile_id := str(profile.get("profile_id", "")).strip_edges()
	var replacement_bucket: Dictionary = {}
	for saved_deck in decks:
		var normalized_deck: Dictionary = _normalize_saved_deck(saved_deck)
		var deck_id := str(normalized_deck.get("deck_id", "")).strip_edges()
		if deck_id.is_empty():
			continue
		replacement_bucket[deck_id] = normalized_deck
	_set_deck_bucket(resolved_profile_id, replacement_bucket)
	var last_selected := _get_last_selected_deck_by_profile()
	var selected_deck_id := str(last_selected.get(resolved_profile_id, "")).strip_edges()
	if selected_deck_id.is_empty() or not replacement_bucket.has(selected_deck_id):
		if replacement_bucket.is_empty():
			last_selected.erase(resolved_profile_id)
		else:
			selected_deck_id = str(replacement_bucket.keys()[0])
			last_selected[resolved_profile_id] = selected_deck_id
		_data["last_selected_deck_by_profile"] = last_selected
	_save()

func merge_decks(profile_id: String, decks: Array[Dictionary]) -> void:
	var profile := ensure_profile(profile_id, DEFAULT_PROFILE_NAME, true)
	var resolved_profile_id := str(profile.get("profile_id", "")).strip_edges()
	var deck_bucket := _get_deck_bucket(resolved_profile_id, true)
	for saved_deck in decks:
		var normalized_deck: Dictionary = _normalize_saved_deck(saved_deck)
		var deck_id := str(normalized_deck.get("deck_id", "")).strip_edges()
		if deck_id.is_empty():
			continue
		deck_bucket[deck_id] = normalized_deck
	_set_deck_bucket(resolved_profile_id, deck_bucket)
	_save()

func upsert_saved_deck(profile_id: String, saved_deck: Dictionary, make_selected: bool = false) -> Dictionary:
	var profile := ensure_profile(profile_id, DEFAULT_PROFILE_NAME, true)
	var resolved_profile_id := str(profile.get("profile_id", "")).strip_edges()
	var normalized_deck: Dictionary = _normalize_saved_deck(saved_deck)
	var deck_id := str(normalized_deck.get("deck_id", "")).strip_edges()
	if deck_id.is_empty():
		return {}
	var deck_bucket := _get_deck_bucket(resolved_profile_id, true)
	deck_bucket[deck_id] = normalized_deck
	_set_deck_bucket(resolved_profile_id, deck_bucket)
	if make_selected:
		remember_last_selected_deck(resolved_profile_id, deck_id)
	else:
		_save()
	return normalized_deck.duplicate(true)

func delete_deck(profile_id: String, deck_id: String) -> void:
	_ensure_loaded()
	var resolved_profile_id := profile_id.strip_edges()
	var resolved_deck_id := deck_id.strip_edges()
	if resolved_profile_id.is_empty() or resolved_deck_id.is_empty():
		return
	var deck_bucket := _get_deck_bucket(resolved_profile_id, false)
	if not deck_bucket.has(resolved_deck_id):
		return
	deck_bucket.erase(resolved_deck_id)
	_set_deck_bucket(resolved_profile_id, deck_bucket)
	var last_selected := _get_last_selected_deck_by_profile()
	if str(last_selected.get(resolved_profile_id, "")) == resolved_deck_id:
		last_selected.erase(resolved_profile_id)
		_data["last_selected_deck_by_profile"] = last_selected
	_save()

func get_last_selected_deck_id(profile_id: String) -> String:
	_ensure_loaded()
	return str(_get_last_selected_deck_by_profile().get(profile_id.strip_edges(), "")).strip_edges()

func remember_last_selected_deck(profile_id: String, deck_id: String) -> void:
	_ensure_loaded()
	var resolved_profile_id := profile_id.strip_edges()
	var resolved_deck_id := deck_id.strip_edges()
	if resolved_profile_id.is_empty() or resolved_deck_id.is_empty():
		return
	var last_selected := _get_last_selected_deck_by_profile()
	last_selected[resolved_profile_id] = resolved_deck_id
	_data["last_selected_deck_by_profile"] = last_selected
	_save()

func get_preferred_auth_mode() -> String:
	_ensure_loaded()
	var mode := str(_data.get("preferred_auth_mode", AUTH_MODE_GUEST)).strip_edges().to_lower()
	if mode in [AUTH_MODE_GUEST, AUTH_MODE_LOGIN, AUTH_MODE_REGISTER]:
		return mode
	return AUTH_MODE_GUEST

func has_seen_auth_onboarding() -> bool:
	_ensure_loaded()
	return bool(_data.get("auth_onboarding_seen", false))

func mark_auth_onboarding_seen(seen: bool = true) -> void:
	_ensure_loaded()
	_data["auth_onboarding_seen"] = seen
	_save()

func set_preferred_auth_mode(auth_mode: String) -> void:
	_ensure_loaded()
	var resolved_mode := auth_mode.strip_edges().to_lower()
	if not resolved_mode in [AUTH_MODE_GUEST, AUTH_MODE_LOGIN, AUTH_MODE_REGISTER]:
		resolved_mode = AUTH_MODE_GUEST
	_data["preferred_auth_mode"] = resolved_mode
	_save()

func get_last_account_username() -> String:
	_ensure_loaded()
	return str(_data.get("last_account_username", "")).strip_edges()

func remember_account_username(username: String) -> void:
	_ensure_loaded()
	_data["last_account_username"] = username.strip_edges()
	_save()

func get_last_account_password() -> String:
	_ensure_loaded()
	return str(_data.get("last_account_password", ""))

func remember_account_password(password: String) -> void:
	_ensure_loaded()
	_data["last_account_password"] = password
	_save()

func clear_account_password() -> void:
	_ensure_loaded()
	_data["last_account_password"] = ""
	_save()

func get_dismissed_release_version() -> String:
	_ensure_loaded()
	return str(_data.get(DISMISSED_RELEASE_VERSION_KEY, "")).strip_edges()

func remember_dismissed_release_version(version: String) -> void:
	_ensure_loaded()
	var normalized := version.strip_edges()
	if normalized.is_empty():
		_data.erase(DISMISSED_RELEASE_VERSION_KEY)
	else:
		_data[DISMISSED_RELEASE_VERSION_KEY] = normalized
	_save()

func remember_lobby_resume(
	profile_id: String,
	session_id: String,
	reconnect_token: String,
	player_name: String,
	lobby_ip: String,
	lobby_port: int,
	username: String = "",
	auth_mode: String = AUTH_MODE_GUEST
) -> Dictionary:
	_ensure_loaded()
	var resolved_profile_id := _resolve_profile_id(profile_id)
	if resolved_profile_id.is_empty():
		return {}
	var resolved_auth_mode := auth_mode.strip_edges().to_lower()
	if resolved_auth_mode not in [AUTH_MODE_GUEST, AUTH_MODE_LOGIN, AUTH_MODE_REGISTER]:
		resolved_auth_mode = AUTH_MODE_GUEST
	var resume_entry := {
		"profile_id": resolved_profile_id,
		"session_id": session_id.strip_edges(),
		"reconnect_token": reconnect_token.strip_edges(),
		"player_name": player_name.strip_edges(),
		"lobby_ip": lobby_ip.strip_edges(),
		"lobby_port": lobby_port,
		"username": username.strip_edges(),
		"auth_mode": resolved_auth_mode,
		"saved_unix": int(Time.get_unix_time_from_system()),
	}
	var lobby_resume_by_profile := _get_lobby_resume_by_profile()
	lobby_resume_by_profile[resolved_profile_id] = resume_entry
	_data["lobby_resume_by_profile"] = lobby_resume_by_profile
	_save()
	return resume_entry.duplicate(true)

func get_lobby_resume(profile_id: String = "") -> Dictionary:
	_ensure_loaded()
	var resolved_profile_id := _resolve_profile_id(profile_id)
	if resolved_profile_id.is_empty():
		return {}
	var entry = _get_lobby_resume_by_profile().get(resolved_profile_id, {})
	if entry is Dictionary:
		return (entry as Dictionary).duplicate(true)
	return {}

func clear_lobby_resume(profile_id: String = "") -> void:
	_ensure_loaded()
	var resolved_profile_id := _resolve_profile_id(profile_id)
	if resolved_profile_id.is_empty():
		return
	var lobby_resume_by_profile := _get_lobby_resume_by_profile()
	if not lobby_resume_by_profile.has(resolved_profile_id):
		return
	lobby_resume_by_profile.erase(resolved_profile_id)
	_data["lobby_resume_by_profile"] = lobby_resume_by_profile
	_save()

func remember_active_match(profile_id: String, match_info: Dictionary) -> Dictionary:
	_ensure_loaded()
	var resolved_profile_id := _resolve_profile_id(profile_id)
	if resolved_profile_id.is_empty():
		return {}
	var normalized_match_info := match_info.duplicate(true)
	normalized_match_info["profile_id"] = resolved_profile_id
	normalized_match_info["saved_unix"] = int(Time.get_unix_time_from_system())
	var active_match_by_profile := _get_active_match_by_profile()
	active_match_by_profile[resolved_profile_id] = normalized_match_info
	_data["active_match_by_profile"] = active_match_by_profile
	_save()
	return normalized_match_info.duplicate(true)

func get_active_match(profile_id: String = "") -> Dictionary:
	_ensure_loaded()
	var resolved_profile_id := _resolve_profile_id(profile_id)
	if resolved_profile_id.is_empty():
		return {}
	var entry = _get_active_match_by_profile().get(resolved_profile_id, {})
	if entry is Dictionary:
		return (entry as Dictionary).duplicate(true)
	return {}

func clear_active_match(profile_id: String = "") -> void:
	_ensure_loaded()
	var resolved_profile_id := _resolve_profile_id(profile_id)
	if resolved_profile_id.is_empty():
		return
	var active_match_by_profile := _get_active_match_by_profile()
	if not active_match_by_profile.has(resolved_profile_id):
		return
	active_match_by_profile.erase(resolved_profile_id)
	_data["active_match_by_profile"] = active_match_by_profile
	_save()

func get_latest_resume_profile_id() -> String:
	_ensure_loaded()
	var latest_profile_id := ""
	var latest_saved_unix := -1
	var active_match_by_profile := _get_active_match_by_profile()
	var lobby_resume_by_profile := _get_lobby_resume_by_profile()
	for profile_id in active_match_by_profile.keys():
		var active_match = active_match_by_profile.get(profile_id, {})
		if not (active_match is Dictionary):
			continue
		if not lobby_resume_by_profile.has(profile_id):
			continue
		var saved_unix := int((active_match as Dictionary).get("saved_unix", 0))
		if saved_unix > latest_saved_unix:
			latest_saved_unix = saved_unix
			latest_profile_id = str(profile_id)
	return latest_profile_id

func _ensure_loaded() -> void:
	if _loaded:
		return
	_loaded = true
	_data = {
		"current_profile_id": "",
		"profiles": {},
		"decks_by_profile": {},
		"last_selected_deck_by_profile": {},
		"lobby_resume_by_profile": {},
		"active_match_by_profile": {},
		"preferred_auth_mode": AUTH_MODE_GUEST,
		"last_account_username": "",
		"last_account_password": "",
		"auth_onboarding_seen": false,
		DISMISSED_RELEASE_VERSION_KEY: "",
	}
	if not FileAccess.file_exists(STORAGE_PATH):
		return
	var file := FileAccess.open(STORAGE_PATH, FileAccess.READ)
	if file == null:
		print("LocalProfileStore: Error opening file for read: ", STORAGE_PATH)
		return
	var content := file.get_as_text()
	file.close()
	if content.strip_edges().is_empty():
		return
	var parsed = JSON.parse_string(content)
	if parsed is Dictionary:
		_data.merge(parsed as Dictionary, true)
	else:
		print("LocalProfileStore: Error parsing JSON from ", STORAGE_PATH)

func _save() -> void:
	var global_path := ProjectSettings.globalize_path(STORAGE_PATH)
	var parent_dir := global_path.get_base_dir()
	if not parent_dir.is_empty() and not DirAccess.dir_exists_absolute(parent_dir):
		var err := DirAccess.make_dir_recursive_absolute(parent_dir)
		if err != OK:
			print("LocalProfileStore: Error creating directory ", parent_dir, " : ", err)

	var file := FileAccess.open(STORAGE_PATH, FileAccess.WRITE)
	if file == null:
		print("LocalProfileStore: Error opening file for write: ", STORAGE_PATH, " (Error: ", FileAccess.get_open_error(), ")")
		return
	var json_string := JSON.stringify(_data, "\t")
	file.store_string(json_string)
	file.flush()
	file.close()
	# Verify save by checking file existence if it didn't exist before
	if not FileAccess.file_exists(STORAGE_PATH):
		print("LocalProfileStore: Critical - file does not exist immediately after save!")

func _get_profiles() -> Dictionary:
	var profiles = _data.get("profiles", {})
	if profiles is Dictionary:
		return (profiles as Dictionary).duplicate(true)
	return {}

func _get_decks_by_profile() -> Dictionary:
	var decks_by_profile = _data.get("decks_by_profile", {})
	if decks_by_profile is Dictionary:
		return (decks_by_profile as Dictionary).duplicate(true)
	return {}

func _get_last_selected_deck_by_profile() -> Dictionary:
	var selected = _data.get("last_selected_deck_by_profile", {})
	if selected is Dictionary:
		return (selected as Dictionary).duplicate(true)
	return {}

func _get_lobby_resume_by_profile() -> Dictionary:
	var resume = _data.get("lobby_resume_by_profile", {})
	if resume is Dictionary:
		return (resume as Dictionary).duplicate(true)
	return {}

func _get_active_match_by_profile() -> Dictionary:
	var active = _data.get("active_match_by_profile", {})
	if active is Dictionary:
		return (active as Dictionary).duplicate(true)
	return {}

func _get_deck_bucket(profile_id: String, create_if_missing: bool) -> Dictionary:
	var decks_by_profile := _get_decks_by_profile()
	var deck_bucket = decks_by_profile.get(profile_id, {})
	if deck_bucket is Dictionary:
		return (deck_bucket as Dictionary).duplicate(true)
	if create_if_missing:
		return {}
	return {}

func _set_deck_bucket(profile_id: String, deck_bucket: Dictionary) -> void:
	var decks_by_profile := _get_decks_by_profile()
	decks_by_profile[profile_id] = deck_bucket.duplicate(true)
	_data["decks_by_profile"] = decks_by_profile

func _sanitize_cards(cards: Dictionary) -> Dictionary:
	var sanitized: Dictionary = {}
	for raw_card_name in cards.keys():
		var card_name := str(raw_card_name).strip_edges()
		var count := int(cards[raw_card_name])
		if card_name.is_empty() or count <= 0:
			continue
		sanitized[card_name] = count
	return sanitized

func _normalize_saved_deck(saved_deck: Dictionary) -> Dictionary:
	var now_unix := int(Time.get_unix_time_from_system())
	var resolved_deck_id := str(saved_deck.get("deck_id", "")).strip_edges()
	if resolved_deck_id.is_empty():
		resolved_deck_id = _generate_id("deck_", 12)
	var normalized_deck := {
		"deck_id": resolved_deck_id,
		"name": str(saved_deck.get("name", DEFAULT_DECK_NAME)).strip_edges(),
		"cards": _sanitize_cards(saved_deck.get("cards", {})),
		"created_unix": int(saved_deck.get("created_unix", now_unix)),
		"updated_unix": int(saved_deck.get("updated_unix", now_unix)),
	}
	if str(normalized_deck.get("name", "")).strip_edges().is_empty():
		normalized_deck["name"] = DEFAULT_DECK_NAME
	return normalized_deck

func _resolve_profile_id(profile_id: String) -> String:
	var resolved_profile_id := profile_id.strip_edges()
	if resolved_profile_id.is_empty():
		resolved_profile_id = get_current_profile_id()
	return resolved_profile_id

func _import_legacy_deck_if_needed(profile_id: String) -> void:
	var resolved_profile_id := profile_id.strip_edges()
	if resolved_profile_id.is_empty():
		return
	if not list_decks(resolved_profile_id).is_empty():
		return
	if not FileAccess.file_exists(LEGACY_DECK_PATH):
		return
	var file := FileAccess.open(LEGACY_DECK_PATH, FileAccess.READ)
	if file == null:
		return
	var parsed = JSON.parse_string(file.get_as_text())
	file.close()
	if not (parsed is Dictionary):
		return
	var sanitized := _sanitize_cards(parsed as Dictionary)
	if sanitized.is_empty():
		return
	save_deck(resolved_profile_id, DEFAULT_DECK_NAME, sanitized)

func _generate_id(prefix: String, length: int) -> String:
	const CHARS := "ABCDEFGHJKLMNPQRSTUVWXYZ23456789"
	var output := prefix
	for _i in length:
		output += CHARS[_rng.randi_range(0, CHARS.length() - 1)]
	return output

func _sort_decks(a: Dictionary, b: Dictionary) -> bool:
	var a_updated := int(a.get("updated_unix", 0))
	var b_updated := int(b.get("updated_unix", 0))
	if a_updated != b_updated:
		return a_updated > b_updated
	return str(a.get("name", "")).to_lower() < str(b.get("name", "")).to_lower()
