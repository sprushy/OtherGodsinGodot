extends RefCounted
class_name ProfileStore

const ServerPathsScript = preload("res://scripts/server/ServerPaths.gd")
const DEFAULT_PLAYER_NAME := "Guest"

var _profiles_by_id: Dictionary = {}
var _profile_id_by_account_id: Dictionary = {}
var _loaded: bool = false
var _rng := RandomNumberGenerator.new()

func _init() -> void:
	_rng.randomize()

func login_profile(
	requested_profile_id: String,
	requested_player_name: String,
	account_id: String = "",
	account_username: String = ""
) -> Dictionary:
	_ensure_loaded()
	var clean_name := requested_player_name.strip_edges()
	if clean_name.is_empty():
		clean_name = DEFAULT_PLAYER_NAME

	var now_unix := int(Time.get_unix_time_from_system())
	var resolved_account_id := account_id.strip_edges()
	var resolved_profile_id := ""
	if not resolved_account_id.is_empty():
		resolved_profile_id = str(_profile_id_by_account_id.get(resolved_account_id, "")).strip_edges()
		if resolved_profile_id.is_empty():
			resolved_profile_id = _generate_profile_id()
	elif requested_profile_id.strip_edges().is_empty():
		resolved_profile_id = ""
	else:
		resolved_profile_id = requested_profile_id.strip_edges()
	if resolved_profile_id.is_empty():
		resolved_profile_id = _generate_profile_id()

	var profile: Dictionary = _profiles_by_id.get(resolved_profile_id, {
		"profile_id": resolved_profile_id,
		"created_unix": now_unix,
	})
	profile["profile_id"] = resolved_profile_id
	profile["display_name"] = clean_name
	profile["account_id"] = resolved_account_id
	profile["account_username"] = account_username.strip_edges()
	if not profile.has("created_unix"):
		profile["created_unix"] = now_unix
	profile["last_seen_unix"] = now_unix
	_profiles_by_id[resolved_profile_id] = profile
	if not resolved_account_id.is_empty():
		_profile_id_by_account_id[resolved_account_id] = resolved_profile_id
	_save()
	return profile.duplicate(true)

func get_profile(profile_id: String) -> Dictionary:
	_ensure_loaded()
	var existing = _profiles_by_id.get(profile_id.strip_edges(), {})
	if existing is Dictionary:
		return (existing as Dictionary).duplicate(true)
	return {}

func _ensure_loaded() -> void:
	if _loaded:
		return
	_loaded = true
	_profiles_by_id = {}
	_profile_id_by_account_id = {}
	var storage_path: String = _get_storage_path()
	if not FileAccess.file_exists(storage_path):
		return
	var file := FileAccess.open(storage_path, FileAccess.READ)
	if file == null:
		return
	var parsed = JSON.parse_string(file.get_as_text())
	file.close()
	if parsed is Dictionary:
		_profiles_by_id = (parsed as Dictionary).duplicate(true)
	for profile_id in _profiles_by_id.keys():
		var profile = _profiles_by_id[profile_id]
		if not (profile is Dictionary):
			continue
		var account_id := str((profile as Dictionary).get("account_id", "")).strip_edges()
		if not account_id.is_empty():
			_profile_id_by_account_id[account_id] = str(profile_id)

func _save() -> void:
	var storage_path: String = _get_storage_path()
	var parent_dir := storage_path.get_base_dir()
	if not parent_dir.is_empty():
		DirAccess.make_dir_recursive_absolute(parent_dir)
	var file := FileAccess.open(storage_path, FileAccess.WRITE)
	if file == null:
		return
	file.store_string(JSON.stringify(_profiles_by_id, "\t"))
	file.flush()
	file.close()

func _get_storage_path() -> String:
	return ServerPathsScript.get_server_data_file_path("profiles.json")

func _generate_profile_id() -> String:
	const CHARS := "ABCDEFGHJKLMNPQRSTUVWXYZ23456789"
	var output := "profile_"
	while true:
		output = "profile_"
		for _i in 12:
			output += CHARS[_rng.randi_range(0, CHARS.length() - 1)]
		if not _profiles_by_id.has(output):
			return output
	return ""
