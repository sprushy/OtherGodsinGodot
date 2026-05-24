extends RefCounted
class_name AccountStore

const ServerPathsScript = preload("res://scripts/server/ServerPaths.gd")
const JsonStoreScript = preload("res://scripts/server/JsonStore.gd")
const MIN_USERNAME_LENGTH := 3
const MAX_USERNAME_LENGTH := 24
const MIN_PASSWORD_LENGTH := 8
const PASSWORD_HASH_ROUNDS := 4096

var _accounts_by_id: Dictionary = {}
var _account_id_by_username: Dictionary = {}
var _loaded: bool = false
var _rng := RandomNumberGenerator.new()

func _init() -> void:
	_rng.randomize()

func register_account(username: String, password: String) -> Dictionary:
	_ensure_loaded()
	var normalized_username := _normalize_username(username)
	var username_error := _validate_username(normalized_username)
	if not username_error.is_empty():
		return _result(false, username_error)
	var password_error := _validate_password(password)
	if not password_error.is_empty():
		return _result(false, password_error)
	var username_key := _username_key(normalized_username)
	if _account_id_by_username.has(username_key):
		return _result(false, "That username is already taken.")

	var account_id := _generate_account_id()
	while _accounts_by_id.has(account_id):
		account_id = _generate_account_id()

	var now_unix := int(Time.get_unix_time_from_system())
	var password_salt := _generate_salt(24)
	var account := {
		"account_id": account_id,
		"username": normalized_username,
		"username_key": username_key,
		"password_salt": password_salt,
		"password_hash": _hash_password(password, password_salt),
		"created_unix": now_unix,
		"last_seen_unix": now_unix,
	}
	_accounts_by_id[account_id] = account
	_account_id_by_username[username_key] = account_id
	if not _save():
		_accounts_by_id.erase(account_id)
		_account_id_by_username.erase(username_key)
		return _result(false, "Could not save account storage.")
	print(
		"AccountStore: registered account username=%s account_id=%s storage=%s total_accounts=%d" % [
			normalized_username,
			account_id,
			get_storage_path_for_debug(),
			_accounts_by_id.size(),
		]
	)
	return _result(true, "", _sanitize_account(account))

func login_account(username: String, password: String) -> Dictionary:
	_ensure_loaded()
	var normalized_username := _normalize_username(username)
	var username_error := _validate_username(normalized_username)
	if not username_error.is_empty():
		return _result(false, username_error)
	var username_key := _username_key(normalized_username)
	if not _account_id_by_username.has(username_key):
		print(
			"AccountStore: login failed, username not found username=%s key=%s storage=%s total_accounts=%d" % [
				normalized_username,
				username_key,
				get_storage_path_for_debug(),
				_accounts_by_id.size(),
			]
		)
		return _result(false, "That account was not found.")
	var account_id := str(_account_id_by_username.get(username_key, "")).strip_edges()
	if account_id.is_empty() or not _accounts_by_id.has(account_id):
		print(
			"AccountStore: login failed, username index points at missing account username=%s key=%s account_id=%s storage=%s total_accounts=%d" % [
				normalized_username,
				username_key,
				account_id,
				get_storage_path_for_debug(),
				_accounts_by_id.size(),
			]
		)
		return _result(false, "That account was not found.")
	var account: Dictionary = (_accounts_by_id[account_id] as Dictionary).duplicate(true)
	var expected_hash := str(account.get("password_hash", ""))
	var salt := str(account.get("password_salt", ""))
	if expected_hash.is_empty() or salt.is_empty():
		print(
			"AccountStore: login failed, account missing password data username=%s account_id=%s storage=%s" % [
				normalized_username,
				account_id,
				get_storage_path_for_debug(),
			]
		)
		return _result(false, "That account is missing password data.")
	if _hash_password(password, salt) != expected_hash:
		print(
			"AccountStore: login failed, incorrect password username=%s account_id=%s storage=%s" % [
				normalized_username,
				account_id,
				get_storage_path_for_debug(),
			]
		)
		return _result(false, "Incorrect password.")
	var previous_account := account.duplicate(true)
	account["last_seen_unix"] = int(Time.get_unix_time_from_system())
	_accounts_by_id[account_id] = account
	if not _save():
		_accounts_by_id[account_id] = previous_account
		return _result(false, "Could not update account storage.")
	print(
		"AccountStore: login succeeded username=%s account_id=%s storage=%s" % [
			normalized_username,
			account_id,
			get_storage_path_for_debug(),
		]
	)
	return _result(true, "", _sanitize_account(account))

func get_account(account_id: String) -> Dictionary:
	_ensure_loaded()
	var existing = _accounts_by_id.get(account_id.strip_edges(), {})
	if existing is Dictionary:
		return _sanitize_account(existing as Dictionary)
	return {}

func get_account_by_username(username: String) -> Dictionary:
	_ensure_loaded()
	var username_key := _username_key(_normalize_username(username))
	if username_key.is_empty() or not _account_id_by_username.has(username_key):
		return {}
	var account_id := str(_account_id_by_username.get(username_key, "")).strip_edges()
	if account_id.is_empty():
		return {}
	return get_account(account_id)

func get_username_map(account_ids: Array) -> Dictionary:
	_ensure_loaded()
	var usernames: Dictionary = {}
	for raw_account_id in account_ids:
		var account_id := str(raw_account_id).strip_edges()
		if account_id.is_empty() or usernames.has(account_id):
			continue
		var account := get_account(account_id)
		var username := str(account.get("username", "")).strip_edges()
		if not username.is_empty():
			usernames[account_id] = username
	return usernames

func get_storage_path_for_debug() -> String:
	return ProjectSettings.globalize_path(_get_storage_path())

func get_account_count() -> int:
	_ensure_loaded()
	return _accounts_by_id.size()

func _ensure_loaded() -> void:
	if _loaded:
		return
	_loaded = true
	_accounts_by_id = {}
	_account_id_by_username = {}
	var storage_path: String = _get_storage_path()
	var storage_global_path := ProjectSettings.globalize_path(storage_path)
	print("AccountStore: loading accounts from %s" % storage_global_path)
	if not FileAccess.file_exists(storage_path):
		print("AccountStore: no account storage file found at %s" % storage_global_path)
		return
	var root := JsonStoreScript.load_dictionary(storage_path, {}, "AccountStore")
	if root.is_empty():
		print("AccountStore: account storage file was not a Dictionary payload at %s" % storage_global_path)
		return
	var extracted_payload := _extract_accounts_payload(root)
	_accounts_by_id = extracted_payload.get("accounts_by_id", {})
	_rebuild_account_username_index()
	print(
		"AccountStore: loaded %d account(s) from %s" % [
			_accounts_by_id.size(),
			storage_global_path,
		]
	)
	if bool(extracted_payload.get("migration_dirty", false)):
		_save()

func _save() -> bool:
	var storage_path: String = _get_storage_path()
	return JsonStoreScript.save_json(storage_path, {
		"accounts_by_id": _accounts_by_id,
		"account_id_by_username": _account_id_by_username,
	}, "AccountStore")

func _result(success: bool, message: String, account: Dictionary = {}) -> Dictionary:
	return {
		"success": success,
		"message": message,
		"account": account.duplicate(true),
	}

func _sanitize_account(account: Dictionary) -> Dictionary:
	return {
		"account_id": str(account.get("account_id", "")),
		"username": str(account.get("username", "")),
		"created_unix": int(account.get("created_unix", 0)),
		"last_seen_unix": int(account.get("last_seen_unix", 0)),
	}

func _normalize_username(username: String) -> String:
	return username.strip_edges()

func _validate_username(username: String) -> String:
	if username.is_empty():
		return "Enter a username."
	if username.length() < MIN_USERNAME_LENGTH:
		return "Username must be at least %d characters." % MIN_USERNAME_LENGTH
	if username.length() > MAX_USERNAME_LENGTH:
		return "Username must be at most %d characters." % MAX_USERNAME_LENGTH
	for char_index in range(username.length()):
		var codepoint := username.unicode_at(char_index)
		var is_letter := (codepoint >= 48 and codepoint <= 57) or (codepoint >= 65 and codepoint <= 90) or (codepoint >= 97 and codepoint <= 122)
		var is_allowed_symbol := codepoint == 95
		if not is_letter and not is_allowed_symbol:
			return "Username can only use letters, numbers, and underscores."
	return ""

func _validate_password(password: String) -> String:
	var clean_password := password.strip_edges()
	if clean_password.length() < MIN_PASSWORD_LENGTH:
		return "Password must be at least %d characters." % MIN_PASSWORD_LENGTH
	return ""

func _username_key(username: String) -> String:
	return username.to_lower()

func _generate_account_id() -> String:
	return "account_%s" % _generate_salt(12)

func _generate_salt(length: int) -> String:
	const CHARS := "ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnopqrstuvwxyz23456789"
	var output := ""
	for _i in range(length):
		output += CHARS[_rng.randi_range(0, CHARS.length() - 1)]
	return output

func _hash_password(password: String, salt: String) -> String:
	var hash_input := (salt + ":" + password).to_utf8_buffer()
	for _round in range(PASSWORD_HASH_ROUNDS):
		var context := HashingContext.new()
		if context.start(HashingContext.HASH_SHA256) != OK:
			return ""
		context.update(hash_input)
		hash_input = context.finish()
	return hash_input.hex_encode()

func _get_storage_path() -> String:
	return ServerPathsScript.get_server_data_file_path("accounts.json")

func _extract_accounts_payload(root: Dictionary) -> Dictionary:
	var extracted: Dictionary = {}
	var migration_dirty := false
	var stored_accounts = root.get("accounts_by_id", null)
	if stored_accounts is Dictionary:
		for account_id in (stored_accounts as Dictionary).keys():
			var normalization: Dictionary = _normalize_loaded_account(stored_accounts[account_id], str(account_id))
			var normalized: Dictionary = normalization.get("account", {})
			if normalized.is_empty():
				continue
			extracted[str(normalized.get("account_id", ""))] = normalized
			if bool(normalization.get("migration_dirty", false)) \
					or str(normalized.get("account_id", "")) != str(account_id):
				migration_dirty = true
	else:
		for legacy_key in root.keys():
			var normalization: Dictionary = _normalize_loaded_account(root[legacy_key], str(legacy_key))
			var normalized: Dictionary = normalization.get("account", {})
			if normalized.is_empty():
				continue
			extracted[str(normalized.get("account_id", ""))] = normalized
			migration_dirty = true
	return {
		"accounts_by_id": extracted,
		"migration_dirty": migration_dirty,
	}

func _normalize_loaded_account(raw_account, fallback_key: String = "") -> Dictionary:
	if not (raw_account is Dictionary):
		return {
			"account": {},
			"migration_dirty": false,
		}
	var account: Dictionary = (raw_account as Dictionary).duplicate(true)
	var migration_dirty := false
	var account_id := str(account.get("account_id", fallback_key)).strip_edges()
	var username := _normalize_username(str(account.get("username", "")))
	if account_id.is_empty() or username.is_empty():
		return {
			"account": {},
			"migration_dirty": migration_dirty,
		}
	if str(account.get("account_id", "")).strip_edges() != account_id:
		migration_dirty = true
	if str(account.get("username", "")) != username:
		migration_dirty = true
	account["account_id"] = account_id
	account["username"] = username
	var username_key := _username_key(username)
	if str(account.get("username_key", "")).strip_edges() != username_key:
		migration_dirty = true
	account["username_key"] = username_key
	var password_hash := str(account.get("password_hash", "")).strip_edges()
	var password_salt := str(account.get("password_salt", "")).strip_edges()
	if password_hash.is_empty() or password_salt.is_empty():
		var legacy_password := str(account.get("password", ""))
		if legacy_password.strip_edges().is_empty():
			return {
				"account": {},
				"migration_dirty": migration_dirty,
			}
		password_salt = _generate_salt(24)
		password_hash = _hash_password(legacy_password, password_salt)
		account.erase("password")
		account["password_salt"] = password_salt
		account["password_hash"] = password_hash
		migration_dirty = true
	return {
		"account": account,
		"migration_dirty": migration_dirty,
	}

func _rebuild_account_username_index() -> void:
	_account_id_by_username = {}
	for account_id in _accounts_by_id.keys():
		var account = _accounts_by_id[account_id]
		if not (account is Dictionary):
			continue
		var username_key := str((account as Dictionary).get("username_key", "")).strip_edges()
		if username_key.is_empty():
			username_key = _username_key(str((account as Dictionary).get("username", "")))
		if username_key.is_empty():
			continue
		_account_id_by_username[username_key] = str(account_id)
