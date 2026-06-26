extends RefCounted
class_name LocalProfileStore

const TiamatScript = preload("res://scripts/cards/Gods/TiamatThePrimordial.gd")
const DeckCatalogUtilsScript = preload("res://scripts/core/DeckCatalogUtils.gd")
const CardArtVariantsScript = preload("res://scripts/core/CardArtVariants.gd")

const STORAGE_PATH := "user://player_profiles.json"
const STORAGE_TEMP_PATH := "user://player_profiles.json.tmp"
const STORAGE_BACKUP_PATH := "user://player_profiles.json.bak"
const LEGACY_DECK_PATH := "user://saved_deck.json"
const LEGACY_APP_USER_DIR_NAMES := [
	"ClaudeOtherGods",
]
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
	var current_profile_id: String = str(_data.get("current_profile_id", "")).strip_edges()
	if not current_profile_id.is_empty():
		var existing: Dictionary = get_profile(current_profile_id)
		if not existing.is_empty():
			var restored: Dictionary = remember_profile(current_profile_id, str(existing.get("display_name", default_name)))
			_import_legacy_deck_if_needed(str(restored.get("profile_id", "")))
			return restored
	var created: Dictionary = ensure_profile("", default_name, true)
	_import_legacy_deck_if_needed(str(created.get("profile_id", "")))
	return created

func ensure_guest_profile(display_name: String = DEFAULT_PROFILE_NAME, make_current: bool = true) -> Dictionary:
	_ensure_loaded()
	var guest_profile_id := str(_data.get("guest_profile_id", "")).strip_edges()
	if not guest_profile_id.is_empty():
		var existing := get_profile(guest_profile_id)
		if not existing.is_empty():
			var restored := ensure_profile(guest_profile_id, display_name, make_current)
			_import_legacy_deck_if_needed(str(restored.get("profile_id", "")))
			return restored
	var created := ensure_profile("", display_name, make_current)
	var created_profile_id := str(created.get("profile_id", "")).strip_edges()
	if created_profile_id.is_empty():
		return created
	_data["guest_profile_id"] = created_profile_id
	_save()
	_import_legacy_deck_if_needed(created_profile_id)
	return created

func get_guest_profile_id() -> String:
	_ensure_loaded()
	return str(_data.get("guest_profile_id", "")).strip_edges()

func ensure_account_profile(
	account_username: String,
	preferred_profile_id: String = "",
	make_current: bool = true,
	prefer_preferred_profile_id: bool = false
) -> Dictionary:
	_ensure_loaded()
	var normalized_username := account_username.strip_edges()
	if normalized_username.is_empty():
		return ensure_profile(preferred_profile_id, DEFAULT_PROFILE_NAME, make_current)
	var normalized_key := normalized_username.to_lower()
	var resolved_preferred_id := preferred_profile_id.strip_edges()
	var matched_profile_id := _find_best_account_profile_id(
		normalized_username,
		resolved_preferred_id,
		prefer_preferred_profile_id
	)
	if not matched_profile_id.is_empty():
		return _remember_account_profile_mapping(
			normalized_key,
			ensure_profile(matched_profile_id, normalized_username, make_current)
		)
	var created_profile := ensure_profile("", normalized_username, make_current)
	return _remember_account_profile_mapping(normalized_key, created_profile)

func find_profile_id_by_account_username(account_username: String) -> String:
	_ensure_loaded()
	return _find_best_account_profile_id(account_username)

func find_profile_id_by_display_name(display_name: String) -> String:
	_ensure_loaded()
	var normalized_name := display_name.strip_edges().to_lower()
	if normalized_name.is_empty():
		return ""
	var profiles := _get_profiles()
	for profile_id in profiles.keys():
		var profile = profiles.get(profile_id, {})
		if not (profile is Dictionary):
			continue
		var stored_name := str((profile as Dictionary).get("display_name", "")).strip_edges().to_lower()
		if stored_name == normalized_name:
			return str(profile_id)
	return ""

func ensure_profile(profile_id: String = "", display_name: String = DEFAULT_PROFILE_NAME, make_current: bool = true) -> Dictionary:
	_ensure_loaded()
	var clean_name: String = display_name.strip_edges()
	if clean_name.is_empty():
		clean_name = DEFAULT_PROFILE_NAME

	var profiles: Dictionary = _get_profiles()
	var resolved_profile_id: String = profile_id.strip_edges()
	var now_unix: int = int(Time.get_unix_time_from_system())
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

func get_profile_display_name(profile_id: String, default_name: String = DEFAULT_PROFILE_NAME) -> String:
	var profile := get_profile(profile_id)
	var resolved_default := default_name.strip_edges()
	if resolved_default.is_empty():
		resolved_default = DEFAULT_PROFILE_NAME
	var display_name := str(profile.get("display_name", resolved_default)).strip_edges()
	if display_name.is_empty():
		return resolved_default
	return display_name

func get_current_profile_id() -> String:
	_ensure_loaded()
	return str(_data.get("current_profile_id", "")).strip_edges()

func activate_guest_session(display_name: String = DEFAULT_PROFILE_NAME) -> Dictionary:
	_ensure_loaded()
	var resolved_display_name := display_name.strip_edges()
	if resolved_display_name.is_empty():
		resolved_display_name = DEFAULT_PROFILE_NAME
	var profile := ensure_guest_profile(resolved_display_name, true)
	_data["preferred_auth_mode"] = AUTH_MODE_LOGIN
	_save()
	return get_profile(str(profile.get("profile_id", "")))

func activate_account_session(
	account_username: String,
	preferred_profile_id: String = "",
	auth_mode: String = AUTH_MODE_LOGIN,
	password: String = "",
	persist_password: bool = false,
	prefer_preferred_profile_id: bool = false
) -> Dictionary:
	_ensure_loaded()
	var resolved_username := account_username.strip_edges()
	if resolved_username.is_empty():
		return ensure_profile(preferred_profile_id, DEFAULT_PROFILE_NAME, true)
	var resolved_auth_mode := auth_mode.strip_edges().to_lower()
	if resolved_auth_mode not in [AUTH_MODE_LOGIN, AUTH_MODE_REGISTER]:
		resolved_auth_mode = AUTH_MODE_LOGIN
	var profile := ensure_account_profile(
		resolved_username,
		preferred_profile_id,
		true,
		prefer_preferred_profile_id
	)
	var resolved_profile_id := str(profile.get("profile_id", "")).strip_edges()
	if resolved_profile_id.is_empty():
		return profile
	var profiles := _get_profiles()
	var stored_profile = profiles.get(resolved_profile_id, {})
	if stored_profile is Dictionary:
		var updated_profile := (stored_profile as Dictionary).duplicate(true)
		updated_profile["display_name"] = resolved_username
		updated_profile["account_username_key"] = resolved_username.to_lower()
		profiles[resolved_profile_id] = updated_profile
		_data["profiles"] = profiles
	_data["current_profile_id"] = resolved_profile_id
	_data["preferred_auth_mode"] = resolved_auth_mode
	_data["last_account_username"] = resolved_username
	if persist_password:
		_data["last_account_password"] = password
	_save()
	return get_profile(resolved_profile_id)

func save_deck(
	profile_id: String,
	deck_name: String,
	cards: Dictionary,
	deck_id: String = "",
	special_setup: Dictionary = {},
	reinforcements: Dictionary = {}
) -> Dictionary:
	var profile := ensure_profile(profile_id, DEFAULT_PROFILE_NAME, true)
	var resolved_profile_id := str(profile.get("profile_id", "")).strip_edges()
	var clean_name := deck_name.strip_edges()
	if clean_name.is_empty():
		clean_name = DEFAULT_DECK_NAME

	var deck_bucket := _get_deck_bucket(resolved_profile_id, true)
	var resolved_deck_id := deck_id.strip_edges()
	if resolved_deck_id.is_empty():
		resolved_deck_id = _generate_id("deck_", 12)

	var now_unix := int(Time.get_unix_time_from_system())
	var deck_entry: Dictionary = deck_bucket.get(resolved_deck_id, {
		"deck_id": resolved_deck_id,
		"created_unix": now_unix,
	})
	deck_entry["deck_id"] = resolved_deck_id
	deck_entry["name"] = clean_name
	deck_entry["cards"] = _sanitize_cards(cards)
	deck_entry["reinforcements"] = _sanitize_cards(reinforcements)
	deck_entry["special_setup"] = _sanitize_special_setup(special_setup)
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
	decks = _dedupe_exact_deck_copies(resolved_profile_id, decks)
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

func get_synced_account_deck_ids(profile_id: String) -> PackedStringArray:
	_ensure_loaded()
	var resolved_profile_id := profile_id.strip_edges()
	if resolved_profile_id.is_empty():
		return PackedStringArray()
	var synced_by_profile := _get_synced_account_deck_ids_by_profile()
	var synced_bucket = synced_by_profile.get(resolved_profile_id, {})
	var synced_ids := PackedStringArray()
	if synced_bucket is Dictionary:
		for raw_deck_id in (synced_bucket as Dictionary).keys():
			var deck_id := str(raw_deck_id).strip_edges()
			if deck_id.is_empty():
				continue
			synced_ids.append(deck_id)
	return synced_ids

func mark_account_decks_synced(profile_id: String, deck_ids: Array) -> void:
	_ensure_loaded()
	var resolved_profile_id := profile_id.strip_edges()
	if resolved_profile_id.is_empty():
		return
	var synced_by_profile := _get_synced_account_deck_ids_by_profile()
	var synced_bucket = synced_by_profile.get(resolved_profile_id, {})
	var bucket: Dictionary = {}
	if synced_bucket is Dictionary:
		bucket = (synced_bucket as Dictionary).duplicate(true)
	var deleted_by_profile := _get_deleted_account_deck_ids_by_profile()
	var deleted_bucket = deleted_by_profile.get(resolved_profile_id, {})
	var deleted_lookup: Dictionary = {}
	if deleted_bucket is Dictionary:
		deleted_lookup = (deleted_bucket as Dictionary).duplicate(true)
	var bucket_changed := false
	for raw_deck_id in deck_ids:
		var deck_id := str(raw_deck_id).strip_edges()
		if deck_id.is_empty():
			continue
		if deleted_lookup.has(deck_id):
			deleted_lookup.erase(deck_id)
			bucket_changed = true
		if bucket.has(deck_id):
			continue
		bucket[deck_id] = true
		bucket_changed = true
	if not bucket_changed:
		return
	synced_by_profile[resolved_profile_id] = bucket
	_data["synced_account_deck_ids_by_profile"] = synced_by_profile
	if deleted_lookup.is_empty():
		deleted_by_profile.erase(resolved_profile_id)
	else:
		deleted_by_profile[resolved_profile_id] = deleted_lookup
	_data["deleted_account_deck_ids_by_profile"] = deleted_by_profile
	_save()

func get_deleted_account_deck_ids(profile_id: String) -> PackedStringArray:
	_ensure_loaded()
	var resolved_profile_id := profile_id.strip_edges()
	if resolved_profile_id.is_empty():
		return PackedStringArray()
	var deleted_by_profile := _get_deleted_account_deck_ids_by_profile()
	var deleted_bucket = deleted_by_profile.get(resolved_profile_id, {})
	var deleted_ids := PackedStringArray()
	if deleted_bucket is Dictionary:
		for raw_deck_id in (deleted_bucket as Dictionary).keys():
			var deck_id := str(raw_deck_id).strip_edges()
			if deck_id.is_empty():
				continue
			deleted_ids.append(deck_id)
	return deleted_ids

func mark_account_decks_deleted(profile_id: String, deck_ids: Array) -> void:
	_ensure_loaded()
	var resolved_profile_id := profile_id.strip_edges()
	if resolved_profile_id.is_empty():
		return
	var deleted_by_profile := _get_deleted_account_deck_ids_by_profile()
	var deleted_bucket = deleted_by_profile.get(resolved_profile_id, {})
	var bucket: Dictionary = {}
	if deleted_bucket is Dictionary:
		bucket = (deleted_bucket as Dictionary).duplicate(true)
	var bucket_changed := false
	for raw_deck_id in deck_ids:
		var deck_id := str(raw_deck_id).strip_edges()
		if deck_id.is_empty() or bucket.has(deck_id):
			continue
		bucket[deck_id] = true
		bucket_changed = true
	if not bucket_changed:
		return
	deleted_by_profile[resolved_profile_id] = bucket
	_data["deleted_account_deck_ids_by_profile"] = deleted_by_profile
	_save()

func get_preferred_auth_mode() -> String:
	_ensure_loaded()
	var mode := str(_data.get("preferred_auth_mode", AUTH_MODE_LOGIN)).strip_edges().to_lower()
	if mode in [AUTH_MODE_LOGIN, AUTH_MODE_REGISTER]:
		return mode
	return AUTH_MODE_LOGIN

func get_allow_friend_observers_to_see_cards() -> bool:
	_ensure_loaded()
	return bool(_data.get("allow_friend_observers_to_see_cards", true))

func set_allow_friend_observers_to_see_cards(allowed: bool) -> void:
	_ensure_loaded()
	_data["allow_friend_observers_to_see_cards"] = allowed
	_save()

func set_preferred_auth_mode(auth_mode: String) -> void:
	_ensure_loaded()
	var resolved_mode := auth_mode.strip_edges().to_lower()
	if not resolved_mode in [AUTH_MODE_LOGIN, AUTH_MODE_REGISTER]:
		resolved_mode = AUTH_MODE_LOGIN
	_data["preferred_auth_mode"] = resolved_mode
	_save()

func get_account_auto_login_enabled() -> bool:
	_ensure_loaded()
	if _data.has("account_auto_login_enabled"):
		return bool(_data.get("account_auto_login_enabled", false))
	return not str(_data.get("last_account_password", "")).is_empty()

func set_account_auto_login_enabled(enabled: bool) -> void:
	_ensure_loaded()
	_data["account_auto_login_enabled"] = enabled
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
	auth_mode: String = AUTH_MODE_LOGIN
) -> Dictionary:
	_ensure_loaded()
	var resolved_profile_id := _resolve_profile_id(profile_id)
	if resolved_profile_id.is_empty():
		return {}
	var resolved_auth_mode := auth_mode.strip_edges().to_lower()
	if resolved_auth_mode not in [AUTH_MODE_LOGIN, AUTH_MODE_REGISTER]:
		resolved_auth_mode = AUTH_MODE_LOGIN
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
		"guest_profile_id": "",
		"account_profile_id_by_username": {},
		"profiles": {},
		"decks_by_profile": {},
		"synced_account_deck_ids_by_profile": {},
		"deleted_account_deck_ids_by_profile": {},
		"last_selected_deck_by_profile": {},
		"lobby_resume_by_profile": {},
		"active_match_by_profile": {},
		"preferred_auth_mode": AUTH_MODE_LOGIN,
		"account_auto_login_enabled": false,
		"allow_friend_observers_to_see_cards": true,
		"last_account_username": "",
		"last_account_password": "",
		DISMISSED_RELEASE_VERSION_KEY: "",
	}
	var primary_snapshot: Dictionary = _read_storage_snapshot(STORAGE_PATH, "primary")
	if _merge_storage_snapshot(primary_snapshot):
		_try_migrate_legacy_storage_over_placeholder_data()
		var repaired_primary_mappings := _repair_account_profile_mappings()
		if bool(primary_snapshot.get("recovered", false)):
			print("LocalProfileStore: Repairing malformed primary snapshot.")
			_save(true)
			if not FileAccess.file_exists(STORAGE_BACKUP_PATH):
				_copy_storage_snapshot(STORAGE_PATH, STORAGE_BACKUP_PATH)
			return
		if repaired_primary_mappings:
			print("LocalProfileStore: Repairing account profile mappings in primary snapshot.")
			_save()
		if not FileAccess.file_exists(STORAGE_BACKUP_PATH):
			_copy_storage_snapshot(STORAGE_PATH, STORAGE_BACKUP_PATH)
		return

	var temp_snapshot: Dictionary = _read_storage_snapshot(STORAGE_TEMP_PATH, "temp")
	if _merge_storage_snapshot(temp_snapshot):
		_try_migrate_legacy_storage_over_placeholder_data()
		_repair_account_profile_mappings()
		print("LocalProfileStore: Restoring profile data from temp snapshot.")
		_save(true)
		return

	var backup_snapshot: Dictionary = _read_storage_snapshot(STORAGE_BACKUP_PATH, "backup")
	if _merge_storage_snapshot(backup_snapshot):
		_try_migrate_legacy_storage_over_placeholder_data()
		_repair_account_profile_mappings()
		print("LocalProfileStore: Restoring profile data from backup snapshot.")
		_save(true)
		return

	var legacy_snapshot: Dictionary = _read_legacy_storage_snapshot()
	if _merge_storage_snapshot(legacy_snapshot):
		_repair_account_profile_mappings()
		print("LocalProfileStore: Migrating profile data from legacy app storage.")
		_save(true)

func _save(skip_backup_refresh: bool = false) -> void:
	if not _ensure_storage_parent_exists(STORAGE_PATH):
		return
	var json_string := JSON.stringify(_data, "\t")
	if not skip_backup_refresh and FileAccess.file_exists(STORAGE_PATH):
		if FileAccess.file_exists(STORAGE_BACKUP_PATH):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(STORAGE_BACKUP_PATH))
		if not _copy_storage_snapshot(STORAGE_PATH, STORAGE_BACKUP_PATH):
			print("LocalProfileStore: Warning - could not refresh backup snapshot %s." % STORAGE_BACKUP_PATH)
	if not _write_storage_snapshot(STORAGE_PATH, json_string):
		if not FileAccess.file_exists(STORAGE_PATH) and FileAccess.file_exists(STORAGE_BACKUP_PATH):
			_copy_storage_snapshot(STORAGE_BACKUP_PATH, STORAGE_PATH)
		return
	if not FileAccess.file_exists(STORAGE_BACKUP_PATH):
		_copy_storage_snapshot(STORAGE_PATH, STORAGE_BACKUP_PATH)

func _read_storage_snapshot(storage_path: String, label: String) -> Dictionary:
	if not FileAccess.file_exists(storage_path):
		return {
			"ok": false,
			"data": {},
			"recovered": false,
		}
	var file := FileAccess.open(storage_path, FileAccess.READ)
	if file == null:
		print("LocalProfileStore: Error opening ", label, " snapshot for read: ", storage_path)
		return {
			"ok": false,
			"data": {},
			"recovered": false,
		}
	var content_bytes := file.get_buffer(file.get_length())
	file.close()
	var decode_result := _decode_utf8_bytes_lossy(content_bytes)
	var content: String = str(decode_result.get("text", ""))
	var had_invalid_utf8 := bool(decode_result.get("had_invalid_utf8", false))
	if had_invalid_utf8:
		print(
			"LocalProfileStore: Recovered ",
			label,
			" snapshot text from invalid UTF-8 bytes: ",
			storage_path
		)
	if content.strip_edges().is_empty():
		print("LocalProfileStore: ", label, " snapshot was empty: ", storage_path)
		return {
			"ok": false,
			"data": {},
			"recovered": false,
		}
	var parsed_snapshot := _parse_storage_snapshot_content(content, storage_path, label)
	if had_invalid_utf8 and bool(parsed_snapshot.get("ok", false)):
		parsed_snapshot["recovered"] = true
	return parsed_snapshot

func _decode_utf8_bytes_lossy(content_bytes: PackedByteArray) -> Dictionary:
	if content_bytes.is_empty():
		return {
			"text": "",
			"had_invalid_utf8": false,
		}
	var text := ""
	var had_invalid_utf8 := false
	var index := 0
	if content_bytes.size() >= 3 and (
		content_bytes[0] == 0xef
		and content_bytes[1] == 0xbb
		and content_bytes[2] == 0xbf
	):
		index = 3
	while index < content_bytes.size():
		var leading_byte := int(content_bytes[index])
		if leading_byte <= 0x7f:
			text += char(leading_byte)
			index += 1
			continue
		var sequence_length := _get_utf8_sequence_length(leading_byte)
		if sequence_length < 2 or index + sequence_length > content_bytes.size():
			had_invalid_utf8 = true
			text += char(65533)
			index += 1
			continue
		var codepoint := _decode_utf8_sequence(content_bytes, index, sequence_length)
		if codepoint < 0:
			had_invalid_utf8 = true
			text += char(65533)
			index += 1
			continue
		text += char(codepoint)
		index += sequence_length
	return {
		"text": text,
		"had_invalid_utf8": had_invalid_utf8,
	}

func _get_utf8_sequence_length(leading_byte: int) -> int:
	if (leading_byte & 0xe0) == 0xc0:
		return 2
	if (leading_byte & 0xf0) == 0xe0:
		return 3
	if (leading_byte & 0xf8) == 0xf0:
		return 4
	return -1

func _decode_utf8_sequence(content_bytes: PackedByteArray, start_index: int, sequence_length: int) -> int:
	var codepoint := 0
	if sequence_length == 2:
		var byte_1 := int(content_bytes[start_index + 1])
		if (byte_1 & 0xc0) != 0x80:
			return -1
		codepoint = ((int(content_bytes[start_index]) & 0x1f) << 6) | (byte_1 & 0x3f)
		if codepoint < 0x80:
			return -1
		return codepoint
	if sequence_length == 3:
		var byte_1 := int(content_bytes[start_index + 1])
		var byte_2 := int(content_bytes[start_index + 2])
		if (byte_1 & 0xc0) != 0x80 or (byte_2 & 0xc0) != 0x80:
			return -1
		codepoint = (
			((int(content_bytes[start_index]) & 0x0f) << 12)
			| ((byte_1 & 0x3f) << 6)
			| (byte_2 & 0x3f)
		)
		if codepoint < 0x800 or (codepoint >= 0xd800 and codepoint <= 0xdfff):
			return -1
		return codepoint
	if sequence_length == 4:
		var byte_1 := int(content_bytes[start_index + 1])
		var byte_2 := int(content_bytes[start_index + 2])
		var byte_3 := int(content_bytes[start_index + 3])
		if (byte_1 & 0xc0) != 0x80 or (byte_2 & 0xc0) != 0x80 or (byte_3 & 0xc0) != 0x80:
			return -1
		codepoint = (
			((int(content_bytes[start_index]) & 0x07) << 18)
			| ((byte_1 & 0x3f) << 12)
			| ((byte_2 & 0x3f) << 6)
			| (byte_3 & 0x3f)
		)
		if codepoint < 0x10000 or codepoint > 0x10ffff:
			return -1
		return codepoint
	return -1

func _parse_storage_snapshot_content(content: String, storage_path: String, label: String) -> Dictionary:
	var json := JSON.new()
	var parse_err := json.parse(content)
	if parse_err == OK and json.data is Dictionary:
		return {
			"ok": true,
			"data": (json.data as Dictionary).duplicate(true),
			"recovered": false,
		}
	var recovered_prefix := _extract_root_json_object_prefix(content)
	if not recovered_prefix.is_empty() and recovered_prefix.strip_edges() != content.strip_edges():
		var recovered_json := JSON.new()
		if recovered_json.parse(recovered_prefix) == OK and recovered_json.data is Dictionary:
			print("LocalProfileStore: Recovered valid ", label, " snapshot prefix from malformed file: ", storage_path)
			return {
				"ok": true,
				"data": (recovered_json.data as Dictionary).duplicate(true),
				"recovered": true,
			}
	var error_message := json.get_error_message()
	if error_message.is_empty():
		print("LocalProfileStore: Error parsing ", label, " snapshot from ", storage_path)
	else:
		print(
			"LocalProfileStore: Error parsing ",
			label,
			" snapshot from ",
			storage_path,
			" at line ",
			json.get_error_line(),
			": ",
			error_message
		)
	return {
		"ok": false,
		"data": {},
		"recovered": false,
	}

func _extract_root_json_object_prefix(content: String) -> String:
	var start_index := -1
	for index in range(content.length()):
		var codepoint := content.unicode_at(index)
		if codepoint == 32 or codepoint == 9 or codepoint == 10 or codepoint == 13:
			continue
		start_index = index
		break
	if start_index < 0 or content.unicode_at(start_index) != 123:
		return ""
	var depth := 0
	var in_string := false
	var escaped := false
	for index in range(start_index, content.length()):
		var codepoint := content.unicode_at(index)
		if in_string:
			if escaped:
				escaped = false
			elif codepoint == 92:
				escaped = true
			elif codepoint == 34:
				in_string = false
			continue
		if codepoint == 34:
			in_string = true
			continue
		if codepoint == 123:
			depth += 1
			continue
		if codepoint != 125:
			continue
		depth -= 1
		if depth == 0:
			return content.substr(0, index + 1)
	return ""

func _read_legacy_storage_snapshot() -> Dictionary:
	for storage_path in _get_legacy_storage_paths():
		var label := "legacy %s" % storage_path.get_file()
		var snapshot := _read_storage_snapshot(storage_path, label)
		if bool(snapshot.get("ok", false)):
			return snapshot
	return {
		"ok": false,
		"data": {},
	}

func _get_legacy_storage_paths() -> Array[String]:
	var current_storage_dir := ProjectSettings.globalize_path("user://")
	var app_userdata_dir := current_storage_dir.get_base_dir()
	if app_userdata_dir.is_empty():
		return []
	var legacy_paths: Array[String] = []
	for legacy_dir_name in LEGACY_APP_USER_DIR_NAMES:
		var resolved_dir_name := str(legacy_dir_name).strip_edges()
		if resolved_dir_name.is_empty():
			continue
		var legacy_dir := app_userdata_dir.path_join(resolved_dir_name)
		for file_name in [
			STORAGE_PATH.get_file(),
			STORAGE_TEMP_PATH.get_file(),
			STORAGE_BACKUP_PATH.get_file(),
		]:
			legacy_paths.append(legacy_dir.path_join(file_name))
	return legacy_paths

func _try_migrate_legacy_storage_over_placeholder_data() -> void:
	if _has_meaningful_persisted_state(_data):
		return
	var legacy_snapshot := _read_legacy_storage_snapshot()
	if not bool(legacy_snapshot.get("ok", false)):
		return
	var legacy_data = legacy_snapshot.get("data", {})
	if not (legacy_data is Dictionary):
		return
	if not _has_meaningful_persisted_state(legacy_data as Dictionary):
		return
	print("LocalProfileStore: Replacing placeholder profile data with legacy app storage.")
	_data.merge(legacy_data as Dictionary, true)

func _has_meaningful_persisted_state(data: Dictionary) -> bool:
	if not str(data.get("last_account_username", "")).strip_edges().is_empty():
		return true
	var account_mappings = data.get("account_profile_id_by_username", {})
	if account_mappings is Dictionary and not (account_mappings as Dictionary).is_empty():
		return true
	var lobby_resume = data.get("lobby_resume_by_profile", {})
	if lobby_resume is Dictionary and not (lobby_resume as Dictionary).is_empty():
		return true
	var active_match = data.get("active_match_by_profile", {})
	if active_match is Dictionary and not (active_match as Dictionary).is_empty():
		return true
	var profiles = data.get("profiles", {})
	if profiles is Dictionary:
		for profile_value in (profiles as Dictionary).values():
			if not (profile_value is Dictionary):
				continue
			if not str((profile_value as Dictionary).get("account_username_key", "")).strip_edges().is_empty():
				return true
	return false

func _merge_storage_snapshot(snapshot: Dictionary) -> bool:
	if not bool(snapshot.get("ok", false)):
		return false
	var snapshot_data = snapshot.get("data", {})
	if not (snapshot_data is Dictionary):
		return false
	_data.merge(snapshot_data as Dictionary, true)
	return true

func _ensure_storage_parent_exists(storage_path: String) -> bool:
	var global_path := ProjectSettings.globalize_path(storage_path)
	var parent_dir := global_path.get_base_dir()
	if parent_dir.is_empty() or DirAccess.dir_exists_absolute(parent_dir):
		return true
	var err := DirAccess.make_dir_recursive_absolute(parent_dir)
	if err != OK:
		print("LocalProfileStore: Error creating directory ", parent_dir, " : ", err)
		return false
	return true

func _write_storage_snapshot(storage_path: String, content: String) -> bool:
	return _write_storage_snapshot_bytes(storage_path, content.to_utf8_buffer())

func _write_storage_snapshot_bytes(storage_path: String, content_bytes: PackedByteArray) -> bool:
	if not _ensure_storage_parent_exists(storage_path):
		return false
	var file := FileAccess.open(storage_path, FileAccess.WRITE)
	if file == null:
		print("LocalProfileStore: Error opening file for write: ", storage_path, " (Error: ", FileAccess.get_open_error(), ")")
		return false
	file.store_buffer(content_bytes)
	file.flush()
	file.close()
	if not FileAccess.file_exists(storage_path):
		print("LocalProfileStore: Critical - file does not exist immediately after save: ", storage_path)
		return false
	return true

func _copy_storage_snapshot(source_path: String, target_path: String) -> bool:
	if not FileAccess.file_exists(source_path):
		return false
	if not _ensure_storage_parent_exists(target_path):
		return false
	var source_file := FileAccess.open(source_path, FileAccess.READ)
	if source_file == null:
		print("LocalProfileStore: Error opening source snapshot for read: ", source_path)
		return false
	var content_bytes := source_file.get_buffer(source_file.get_length())
	source_file.close()
	return _write_storage_snapshot_bytes(target_path, content_bytes)

func _get_profiles() -> Dictionary:
	var profiles = _data.get("profiles", {})
	if profiles is Dictionary:
		return (profiles as Dictionary).duplicate(true)
	return {}

func _get_account_profile_id_by_username() -> Dictionary:
	var mappings = _data.get("account_profile_id_by_username", {})
	if mappings is Dictionary:
		return (mappings as Dictionary).duplicate(true)
	return {}

func _remember_account_profile_mapping(account_username_key: String, profile: Dictionary) -> Dictionary:
	var resolved_key := account_username_key.strip_edges().to_lower()
	if resolved_key.is_empty():
		return profile.duplicate(true)
	var resolved_profile_id := str(profile.get("profile_id", "")).strip_edges()
	if resolved_profile_id.is_empty():
		return profile.duplicate(true)
	var mappings := _get_account_profile_id_by_username()
	mappings[resolved_key] = resolved_profile_id
	_data["account_profile_id_by_username"] = mappings
	_save()
	return profile.duplicate(true)

func _find_best_account_profile_id(
	account_username: String,
	preferred_profile_id: String = "",
	prefer_preferred_profile_id: bool = false
) -> String:
	var normalized_username := account_username.strip_edges()
	var normalized_key := normalized_username.to_lower()
	if normalized_key.is_empty():
		return ""

	var resolved_preferred_id := preferred_profile_id.strip_edges()
	var mapped_profile_id := str(_get_account_profile_id_by_username().get(normalized_key, "")).strip_edges()
	var profiles := _get_profiles()
	var candidate_ids: Array[String] = []
	var seen_candidate_ids: Dictionary = {}

	if not mapped_profile_id.is_empty():
		_append_account_profile_candidate(candidate_ids, seen_candidate_ids, mapped_profile_id)
	if not resolved_preferred_id.is_empty():
		_append_account_profile_candidate(candidate_ids, seen_candidate_ids, resolved_preferred_id)
	for profile_id_variant in profiles.keys():
		var profile_id := str(profile_id_variant).strip_edges()
		if profile_id.is_empty():
			continue
		var profile = profiles.get(profile_id, {})
		if not (profile is Dictionary):
			continue
		if not _profile_matches_account_username(profile as Dictionary, normalized_key):
			continue
		_append_account_profile_candidate(candidate_ids, seen_candidate_ids, profile_id)
	for profile_id_variant in profiles.keys():
		var profile_id := str(profile_id_variant).strip_edges()
		if profile_id.is_empty():
			continue
		var profile = profiles.get(profile_id, {})
		if not (profile is Dictionary):
			continue
		if str((profile as Dictionary).get("display_name", "")).strip_edges().to_lower() != normalized_key:
			continue
		_append_account_profile_candidate(candidate_ids, seen_candidate_ids, profile_id)

	var best_profile_id := ""
	var best_score := -1
	var best_last_seen := -1
	for candidate_profile_id in candidate_ids:
		var candidate_profile = get_profile(candidate_profile_id)
		if candidate_profile.is_empty():
			continue
		var score := _score_account_profile_candidate(
			candidate_profile_id,
			candidate_profile,
			normalized_key,
			normalized_username,
			mapped_profile_id,
			resolved_preferred_id,
			prefer_preferred_profile_id
		)
		var last_seen := int(candidate_profile.get("last_seen_unix", 0))
		if score > best_score or (score == best_score and last_seen > best_last_seen):
			best_score = score
			best_last_seen = last_seen
			best_profile_id = candidate_profile_id
	return best_profile_id

func _append_account_profile_candidate(candidate_ids: Array[String], seen_candidate_ids: Dictionary, profile_id: String) -> void:
	var resolved_profile_id := profile_id.strip_edges()
	if resolved_profile_id.is_empty() or seen_candidate_ids.has(resolved_profile_id):
		return
	seen_candidate_ids[resolved_profile_id] = true
	candidate_ids.append(resolved_profile_id)

func _profile_matches_account_username(profile: Dictionary, normalized_key: String) -> bool:
	if profile.is_empty() or normalized_key.is_empty():
		return false
	var stored_username_key := str(profile.get("account_username_key", "")).strip_edges().to_lower()
	if not stored_username_key.is_empty():
		return stored_username_key == normalized_key
	return str(profile.get("display_name", "")).strip_edges().to_lower() == normalized_key

func _score_account_profile_candidate(
	profile_id: String,
	profile: Dictionary,
	normalized_key: String,
	normalized_username: String,
	mapped_profile_id: String,
	preferred_profile_id: String,
	prefer_preferred_profile_id: bool
) -> int:
	if profile.is_empty():
		return -1
	var score := 0
	var stored_username_key := str(profile.get("account_username_key", "")).strip_edges().to_lower()
	if stored_username_key == normalized_key:
		score += 1000
	elif not stored_username_key.is_empty():
		score -= 2000
	var display_name := str(profile.get("display_name", "")).strip_edges()
	if display_name.to_lower() == normalized_key:
		score += 150
	elif display_name == normalized_username:
		score += 125
	if profile_id == mapped_profile_id:
		score += 10
	if profile_id == preferred_profile_id:
		score += 40 if prefer_preferred_profile_id else 15
	var deck_count := _get_saved_deck_count_for_profile(profile_id)
	if deck_count > 0:
		score += 500
	score += mini(deck_count, 50) * 5
	score += mini(_get_synced_account_deck_count_for_profile(profile_id), 50) * 2
	if _has_lobby_resume_for_profile(profile_id):
		score += 25
	if _has_active_match_for_profile(profile_id):
		score += 25
	return score

func _get_saved_deck_count_for_profile(profile_id: String) -> int:
	return _get_deck_bucket(profile_id.strip_edges(), false).size()

func _get_synced_account_deck_count_for_profile(profile_id: String) -> int:
	var synced_by_profile := _get_synced_account_deck_ids_by_profile()
	var synced_bucket = synced_by_profile.get(profile_id.strip_edges(), {})
	if synced_bucket is Dictionary:
		return (synced_bucket as Dictionary).size()
	return 0

func _has_lobby_resume_for_profile(profile_id: String) -> bool:
	var resume_by_profile := _get_lobby_resume_by_profile()
	var resume = resume_by_profile.get(profile_id.strip_edges(), {})
	return resume is Dictionary and not (resume as Dictionary).is_empty()

func _has_active_match_for_profile(profile_id: String) -> bool:
	var active_by_profile := _get_active_match_by_profile()
	var active = active_by_profile.get(profile_id.strip_edges(), {})
	return active is Dictionary and not (active as Dictionary).is_empty()

func _repair_account_profile_mappings() -> bool:
	var mappings_changed := false
	var account_mappings := _get_account_profile_id_by_username()
	var profiles := _get_profiles()
	var normalized_usernames: Dictionary = {}

	for raw_username_key in account_mappings.keys():
		var normalized_key := str(raw_username_key).strip_edges().to_lower()
		if normalized_key.is_empty():
			continue
		normalized_usernames[normalized_key] = true
	for profile in profiles.values():
		if not (profile is Dictionary):
			continue
		var stored_username_key := str((profile as Dictionary).get("account_username_key", "")).strip_edges().to_lower()
		if stored_username_key.is_empty():
			continue
		normalized_usernames[stored_username_key] = true

	for normalized_username_key in normalized_usernames.keys():
		var best_profile_id := _find_best_account_profile_id(str(normalized_username_key))
		if best_profile_id.is_empty():
			continue
		if str(account_mappings.get(normalized_username_key, "")).strip_edges() == best_profile_id:
			continue
		account_mappings[normalized_username_key] = best_profile_id
		mappings_changed = true

	if mappings_changed:
		_data["account_profile_id_by_username"] = account_mappings

	var current_profile_id := str(_data.get("current_profile_id", "")).strip_edges()
	if current_profile_id.is_empty():
		return mappings_changed
	var current_profile := get_profile(current_profile_id)
	if current_profile.is_empty():
		return mappings_changed
	var current_username_key := str(current_profile.get("account_username_key", "")).strip_edges().to_lower()
	if current_username_key.is_empty():
		return mappings_changed
	var repaired_current_profile_id := str(account_mappings.get(current_username_key, "")).strip_edges()
	if repaired_current_profile_id.is_empty() or repaired_current_profile_id == current_profile_id:
		return mappings_changed
	_data["current_profile_id"] = repaired_current_profile_id
	return true

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

func _get_synced_account_deck_ids_by_profile() -> Dictionary:
	var synced = _data.get("synced_account_deck_ids_by_profile", {})
	if synced is Dictionary:
		return (synced as Dictionary).duplicate(true)
	return {}

func _get_deleted_account_deck_ids_by_profile() -> Dictionary:
	var deleted = _data.get("deleted_account_deck_ids_by_profile", {})
	if deleted is Dictionary:
		return (deleted as Dictionary).duplicate(true)
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

func _sanitize_special_setup(special_setup: Dictionary) -> Dictionary:
	if special_setup == null or special_setup.is_empty():
		return {}
	return CardArtVariantsScript.sanitize_special_setup(special_setup)

func _normalize_saved_deck(saved_deck: Dictionary) -> Dictionary:
	var now_unix := int(Time.get_unix_time_from_system())
	var resolved_deck_id := str(saved_deck.get("deck_id", "")).strip_edges()
	if resolved_deck_id.is_empty():
		resolved_deck_id = _generate_id("deck_", 12)
	var normalized_deck := {
		"deck_id": resolved_deck_id,
		"name": str(saved_deck.get("name", DEFAULT_DECK_NAME)).strip_edges(),
		"cards": _sanitize_cards(saved_deck.get("cards", {})),
		"reinforcements": _sanitize_cards(saved_deck.get("reinforcements", {})),
		"special_setup": _sanitize_special_setup(saved_deck.get("special_setup", {})),
		"created_unix": int(saved_deck.get("created_unix", now_unix)),
		"updated_unix": int(saved_deck.get("updated_unix", now_unix)),
	}
	if str(normalized_deck.get("name", "")).strip_edges().is_empty():
		normalized_deck["name"] = DEFAULT_DECK_NAME
	return normalized_deck

func _dedupe_exact_deck_copies(profile_id: String, decks: Array[Dictionary]) -> Array[Dictionary]:
	if decks.size() < 2:
		return decks
	var resolved_profile_id := profile_id.strip_edges()
	var selected_deck_id := str(_get_last_selected_deck_by_profile().get(resolved_profile_id, "")).strip_edges()
	var deduped_decks := DeckCatalogUtilsScript.dedupe_exact_copies(decks, "", selected_deck_id)
	if deduped_decks.size() == decks.size():
		return deduped_decks
	_replace_decks_after_dedupe(resolved_profile_id, decks, deduped_decks)
	return deduped_decks

func _replace_decks_after_dedupe(
	profile_id: String,
	original_decks: Array[Dictionary],
	deduped_decks: Array[Dictionary]
) -> void:
	var resolved_profile_id := profile_id.strip_edges()
	if resolved_profile_id.is_empty():
		return
	var replacement_bucket: Dictionary = {}
	var signature_to_retained_id: Dictionary = {}
	for deck in deduped_decks:
		var normalized_deck := _normalize_saved_deck(deck)
		var deck_id := str(normalized_deck.get("deck_id", "")).strip_edges()
		if deck_id.is_empty():
			continue
		replacement_bucket[deck_id] = normalized_deck
		signature_to_retained_id[DeckCatalogUtilsScript.semantic_signature(normalized_deck)] = deck_id
	_set_deck_bucket(resolved_profile_id, replacement_bucket)
	_remap_synced_account_deck_ids_after_dedupe(resolved_profile_id, original_decks, signature_to_retained_id)
	var last_selected := _get_last_selected_deck_by_profile()
	var selected_deck_id := str(last_selected.get(resolved_profile_id, "")).strip_edges()
	if selected_deck_id.is_empty() or replacement_bucket.has(selected_deck_id):
		_save()
		return
	if replacement_bucket.is_empty():
		last_selected.erase(resolved_profile_id)
	else:
		last_selected[resolved_profile_id] = str(replacement_bucket.keys()[0]).strip_edges()
	_data["last_selected_deck_by_profile"] = last_selected
	_save()

func _remap_synced_account_deck_ids_after_dedupe(
	profile_id: String,
	original_decks: Array[Dictionary],
	signature_to_retained_id: Dictionary
) -> void:
	var synced_by_profile := _get_synced_account_deck_ids_by_profile()
	var synced_bucket = synced_by_profile.get(profile_id, {})
	if not (synced_bucket is Dictionary):
		return
	var original_signature_by_id: Dictionary = {}
	for deck in original_decks:
		var deck_id := str(deck.get("deck_id", "")).strip_edges()
		if deck_id.is_empty():
			continue
		original_signature_by_id[deck_id] = DeckCatalogUtilsScript.semantic_signature(deck)
	var remapped_bucket: Dictionary = {}
	for raw_deck_id in (synced_bucket as Dictionary).keys():
		var deck_id := str(raw_deck_id).strip_edges()
		if deck_id.is_empty():
			continue
		if _dictionary_has_value(signature_to_retained_id, deck_id):
			remapped_bucket[deck_id] = true
			continue
		var signature := str(original_signature_by_id.get(deck_id, "")).strip_edges()
		if signature.is_empty():
			continue
		var retained_deck_id := str(signature_to_retained_id.get(signature, "")).strip_edges()
		if retained_deck_id.is_empty():
			continue
		remapped_bucket[retained_deck_id] = true
	if remapped_bucket.is_empty():
		synced_by_profile.erase(profile_id)
	else:
		synced_by_profile[profile_id] = remapped_bucket
	_data["synced_account_deck_ids_by_profile"] = synced_by_profile

func _dictionary_has_value(values: Dictionary, target_value: String) -> bool:
	var resolved_target := target_value.strip_edges()
	if resolved_target.is_empty():
		return false
	for raw_value in values.values():
		if str(raw_value).strip_edges() == resolved_target:
			return true
	return false

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
