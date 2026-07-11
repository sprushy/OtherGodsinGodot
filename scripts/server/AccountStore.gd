extends RefCounted
class_name AccountStore

const ServerPathsScript = preload("res://scripts/server/ServerPaths.gd")
const JsonStoreScript = preload("res://scripts/server/JsonStore.gd")

const MIN_USERNAME_LENGTH := 3
const MAX_USERNAME_LENGTH := 24
const MIN_PASSWORD_LENGTH := 8
const PASSWORD_HASH_SCHEME := "pbkdf2_hmac_sha256_v1"
const PASSWORD_HASH_ITERATIONS := 120000
const PASSWORD_HASH_BYTES := 32
const PASSWORD_SALT_BYTES := 32
const LEGACY_PASSWORD_HASH_ROUNDS := 4096
const SHA256_BLOCK_BYTES := 64

var _accounts_by_id: Dictionary = {}
var _account_id_by_email: Dictionary = {}
var _account_id_by_username: Dictionary = {}
var _loaded: bool = false
var _rng := RandomNumberGenerator.new()

func _init() -> void:
	_rng.randomize()

func register_account(email: String, password: String, username: String = "", accepts_game_updates: bool = false) -> Dictionary:
	_ensure_loaded()
	var normalized_email := _normalize_email(email)
	var email_error := _validate_email(normalized_email)
	if not email_error.is_empty():
		return _result(false, email_error)
	var password_error := _validate_password(password)
	if not password_error.is_empty():
		return _result(false, password_error)
	var email_key := _email_key(normalized_email)
	if not _find_account_id_by_email(email_key).is_empty():
		return _result(false, "That email address already has an account.")

	var normalized_username := _normalize_username(username)
	var username_error := _validate_username(normalized_username)
	if not username_error.is_empty():
		return _result(false, username_error)
	var username_key := _username_key(normalized_username)
	if _account_id_by_username.has(username_key):
		return _result(false, "That username is already taken.")

	var account_id := _generate_account_id()
	while account_id.is_empty() or _accounts_by_id.has(account_id):
		account_id = _generate_account_id()

	var now_unix := int(Time.get_unix_time_from_system())
	var password_record := _build_password_record(password)
	if password_record.is_empty():
		return _result(false, "Could not secure account password.")
	var account := {
		"account_id": account_id,
		"email": normalized_email,
		"email_key": email_key,
		"username": normalized_username,
		"username_key": username_key,
		"accepts_game_updates": accepts_game_updates,
		"created_unix": now_unix,
		"last_seen_unix": now_unix,
	}
	account.merge(password_record, true)
	_accounts_by_id[account_id] = account
	_account_id_by_email[email_key] = account_id
	_account_id_by_username[username_key] = account_id
	if not _save():
		_accounts_by_id.erase(account_id)
		_account_id_by_email.erase(email_key)
		_account_id_by_username.erase(username_key)
		return _result(false, "Could not save account storage.")
	print(
		"AccountStore: registered account email=%s username=%s account=%s total_accounts=%d" % [
			_redact_email_for_log(normalized_email),
			normalized_username,
			_redact_id_for_log(account_id),
			_accounts_by_id.size(),
		]
	)
	return _result(true, "", _sanitize_account(account))

func claim_legacy_account(
	username: String,
	password: String,
	email: String,
	accepts_game_updates: bool = false
) -> Dictionary:
	_ensure_loaded()
	var normalized_username := _normalize_username(username)
	var username_error := _validate_username(normalized_username)
	if not username_error.is_empty():
		return _result(false, username_error)
	var normalized_email := _normalize_email(email)
	var email_error := _validate_email(normalized_email)
	if not email_error.is_empty():
		return _result(false, email_error)
	var email_key := _email_key(normalized_email)
	var username_key := _username_key(normalized_username)
	if not _account_id_by_username.has(username_key):
		return _result(false, "That account was not found.")
	var account_id := str(_account_id_by_username.get(username_key, "")).strip_edges()
	if account_id.is_empty() or not _accounts_by_id.has(account_id):
		return _result(false, "That account was not found.")
	var account: Dictionary = (_accounts_by_id[account_id] as Dictionary).duplicate(true)
	if not str(account.get("email", "")).strip_edges().is_empty():
		return _result(false, "That account already has an email address. Log in with email instead.")
	var password_result := _verify_password(password, account)
	if not bool(password_result.get("success", false)):
		return _result(false, "Incorrect password.")
	var upgraded_record := {}
	if bool(password_result.get("needs_rehash", false)):
		upgraded_record = _build_password_record(password)
		if upgraded_record.is_empty():
			return _result(false, "Could not upgrade account password storage.")
	var matching_email_account_id := _find_account_id_by_email(email_key, account_id)
	var existing_email_account_id := ""
	if not matching_email_account_id.is_empty():
		existing_email_account_id = _find_reassignable_email_account_id(email_key, account_id, normalized_email, normalized_username)
	var displaced_account_id := ""
	var previous_email_account: Dictionary = {}
	if not matching_email_account_id.is_empty():
		if existing_email_account_id.is_empty():
			return _result(false, "That email address already has an account.")
		var existing_email_account = _accounts_by_id.get(existing_email_account_id, {})
		if not (existing_email_account is Dictionary) \
				or not _can_reassign_email_account_for_legacy_claim(
					existing_email_account as Dictionary,
					normalized_email,
					normalized_username
				):
			return _result(false, "That email address already has an account.")
		previous_email_account = (existing_email_account as Dictionary).duplicate(true)
		var updated_email_account := previous_email_account.duplicate(true)
		updated_email_account["email"] = ""
		updated_email_account["email_key"] = ""
		updated_email_account["last_seen_unix"] = int(Time.get_unix_time_from_system())
		_accounts_by_id[existing_email_account_id] = updated_email_account
		displaced_account_id = existing_email_account_id
	var previous_account := account.duplicate(true)
	account["email"] = normalized_email
	account["email_key"] = email_key
	account["accepts_game_updates"] = accepts_game_updates
	account["last_seen_unix"] = int(Time.get_unix_time_from_system())
	if not upgraded_record.is_empty():
		account.merge(upgraded_record, true)
	_accounts_by_id[account_id] = account
	_rebuild_account_indexes()
	if not _save():
		_accounts_by_id[account_id] = previous_account
		if not displaced_account_id.is_empty():
			_accounts_by_id[displaced_account_id] = previous_email_account
		_rebuild_account_indexes()
		return _result(false, "Could not update account storage.")
	var extra := {}
	if not displaced_account_id.is_empty():
		extra["merged_account_id"] = displaced_account_id
	return _result(true, "", _sanitize_account(account), extra)

func login_account(email: String, password: String) -> Dictionary:
	_ensure_loaded()
	var normalized_email := _normalize_email(email)
	var email_error := _validate_email(normalized_email)
	if not email_error.is_empty():
		return _result(false, email_error)
	var email_key := _email_key(normalized_email)
	var matching_account_ids := _get_account_ids_by_email(email_key)
	if matching_account_ids.is_empty():
		print(
			"AccountStore: login failed, email not found email=%s key=%s total_accounts=%d" % [
				_redact_email_for_log(normalized_email),
				_redact_id_for_log(email_key),
				_accounts_by_id.size(),
			]
		)
		return _result(false, "That account was not found.")
	var account_id := ""
	var password_result := {}
	if matching_account_ids.size() > 1:
		var password_matched_account_ids: Array[String] = []
		var password_result_by_account_id := {}
		for candidate_account_id in matching_account_ids:
			var candidate_account = _accounts_by_id.get(candidate_account_id, {})
			if not (candidate_account is Dictionary):
				continue
			var candidate_password_result := _verify_password(password, candidate_account as Dictionary)
			if not bool(candidate_password_result.get("success", false)):
				continue
			password_matched_account_ids.append(candidate_account_id)
			password_result_by_account_id[candidate_account_id] = candidate_password_result
		if password_matched_account_ids.is_empty():
			print(
				"AccountStore: login failed, duplicate email records had no password match email=%s key=%s matches=%d" % [
					_redact_email_for_log(normalized_email),
					_redact_id_for_log(email_key),
					matching_account_ids.size(),
				]
			)
			return _result(false, "Incorrect password.")
		account_id = _choose_duplicate_email_login_account(password_matched_account_ids, normalized_email)
		if account_id.is_empty():
			print(
				"AccountStore: login failed, duplicate email records email=%s key=%s matches=%d password_matches=%d" % [
					_redact_email_for_log(normalized_email),
					_redact_id_for_log(email_key),
					matching_account_ids.size(),
					password_matched_account_ids.size(),
				]
			)
			return _result(false, "More than one account uses that email address. Contact support.")
		password_result = password_result_by_account_id.get(account_id, {})
		print(
			"AccountStore: resolved duplicate email login email=%s key=%s selected=%s password_matches=%d" % [
				_redact_email_for_log(normalized_email),
				_redact_id_for_log(email_key),
				_redact_id_for_log(account_id),
				password_matched_account_ids.size(),
			]
		)
	else:
		account_id = matching_account_ids[0]
	if account_id.is_empty() or not _accounts_by_id.has(account_id):
		print(
			"AccountStore: login failed, email index points at missing account email=%s key=%s account=%s total_accounts=%d" % [
				_redact_email_for_log(normalized_email),
				_redact_id_for_log(email_key),
				_redact_id_for_log(account_id),
				_accounts_by_id.size(),
			]
		)
		return _result(false, "That account was not found.")
	var account: Dictionary = (_accounts_by_id[account_id] as Dictionary).duplicate(true)
	if password_result.is_empty():
		password_result = _verify_password(password, account)
	if not bool(password_result.get("success", false)):
		print(
			"AccountStore: login failed, incorrect password email=%s account=%s" % [
				_redact_email_for_log(normalized_email),
				_redact_id_for_log(account_id),
			]
		)
		return _result(false, "Incorrect password.")
	var previous_account := account.duplicate(true)
	account["last_seen_unix"] = int(Time.get_unix_time_from_system())
	if bool(password_result.get("needs_rehash", false)):
		var upgraded_record := _build_password_record(password)
		if upgraded_record.is_empty():
			return _result(false, "Could not upgrade account password storage.")
		account.merge(upgraded_record, true)
	_accounts_by_id[account_id] = account
	if not _save():
		_accounts_by_id[account_id] = previous_account
		return _result(false, "Could not update account storage.")
	print(
		"AccountStore: login succeeded email=%s username=%s account=%s" % [
			_redact_email_for_log(normalized_email),
			str(account.get("username", "")),
			_redact_id_for_log(account_id),
		]
	)
	return _result(true, "", _sanitize_account(account))

func update_account_settings(
	account_id: String,
	current_password: String = "",
	new_email: String = "",
	new_password: String = "",
	accepts_game_updates: bool = false,
	update_game_updates: bool = false
) -> Dictionary:
	_ensure_loaded()
	var resolved_account_id := account_id.strip_edges()
	if resolved_account_id.is_empty() or not _accounts_by_id.has(resolved_account_id):
		return _result(false, "Account was not found.")
	var account: Dictionary = (_accounts_by_id[resolved_account_id] as Dictionary).duplicate(true)
	var previous_account := account.duplicate(true)
	var normalized_new_email := _normalize_email(new_email)
	var changing_email := not normalized_new_email.is_empty() \
		and normalized_new_email != str(account.get("email", "")).strip_edges().to_lower()
	var changing_password := not new_password.is_empty()
	if changing_email or changing_password:
		var password_result := _verify_password(current_password, account)
		if not bool(password_result.get("success", false)):
			return _result(false, "Enter your current password to change account security settings.")
		if bool(password_result.get("needs_rehash", false)) and not changing_password:
			var upgraded_record := _build_password_record(current_password)
			if upgraded_record.is_empty():
				return _result(false, "Could not upgrade account password storage.")
			account.merge(upgraded_record, true)
		if changing_email:
			var email_error := _validate_email(normalized_new_email)
			if not email_error.is_empty():
				return _result(false, email_error)
			var new_email_key := _email_key(normalized_new_email)
			if not _find_account_id_by_email(new_email_key, resolved_account_id).is_empty():
				return _result(false, "That email address already has an account.")
			account["email"] = normalized_new_email
			account["email_key"] = new_email_key
		if changing_password:
			var password_error := _validate_password(new_password)
			if not password_error.is_empty():
				return _result(false, password_error)
			var password_record := _build_password_record(new_password)
			if password_record.is_empty():
				return _result(false, "Could not secure account password.")
			account.merge(password_record, true)
	if update_game_updates:
		account["accepts_game_updates"] = accepts_game_updates
	account["last_seen_unix"] = int(Time.get_unix_time_from_system())
	_accounts_by_id[resolved_account_id] = account
	_rebuild_account_indexes()
	if not _save():
		_accounts_by_id[resolved_account_id] = previous_account
		_rebuild_account_indexes()
		return _result(false, "Could not update account settings.")
	return _result(true, "", _sanitize_account(account))

func get_account(account_id: String) -> Dictionary:
	_ensure_loaded()
	var existing = _accounts_by_id.get(account_id.strip_edges(), {})
	if existing is Dictionary:
		return _sanitize_account(existing as Dictionary)
	return {}

func get_account_by_email(email: String) -> Dictionary:
	_ensure_loaded()
	var email_key := _email_key(_normalize_email(email))
	if email_key.is_empty():
		return {}
	var matching_account_ids := _get_account_ids_by_email(email_key)
	if matching_account_ids.size() != 1:
		return {}
	return get_account(matching_account_ids[0])

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
	_account_id_by_email = {}
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
	_rebuild_account_indexes()
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
		"account_id_by_email": _account_id_by_email,
		"account_id_by_username": _account_id_by_username,
	}, "AccountStore")

func _result(success: bool, message: String, account: Dictionary = {}, extra: Dictionary = {}) -> Dictionary:
	var result := {
		"success": success,
		"message": message,
		"account": account.duplicate(true),
	}
	for key in extra.keys():
		result[key] = extra[key]
	return result

func _sanitize_account(account: Dictionary) -> Dictionary:
	return {
		"account_id": str(account.get("account_id", "")),
		"email": str(account.get("email", "")),
		"username": str(account.get("username", "")),
		"accepts_game_updates": bool(account.get("accepts_game_updates", false)),
		"created_unix": int(account.get("created_unix", 0)),
		"last_seen_unix": int(account.get("last_seen_unix", 0)),
	}

func _normalize_email(email: String) -> String:
	return email.strip_edges().to_lower()

func _validate_email(email: String) -> String:
	if email.is_empty():
		return "Enter an email address."
	if email.length() > 254:
		return "Email address is too long."
	var at_index := email.find("@")
	if at_index <= 0 or at_index != email.rfind("@"):
		return "Enter a valid email address."
	var local_part := email.substr(0, at_index)
	var domain_part := email.substr(at_index + 1)
	if local_part.is_empty() or domain_part.is_empty():
		return "Enter a valid email address."
	if local_part.length() > 64:
		return "Email address is too long."
	if domain_part.find(".") <= 0 or domain_part.ends_with("."):
		return "Enter a valid email address."
	for char_index in range(email.length()):
		var codepoint := email.unicode_at(char_index)
		if codepoint <= 32 or codepoint >= 127:
			return "Email address can only use standard email characters."
	return ""

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
		var is_letter_or_number := (codepoint >= 48 and codepoint <= 57) or (codepoint >= 65 and codepoint <= 90) or (codepoint >= 97 and codepoint <= 122)
		var is_allowed_symbol := codepoint == 95
		if not is_letter_or_number and not is_allowed_symbol:
			return "Username can only use letters, numbers, and underscores."
	return ""

func _validate_password(password: String) -> String:
	if password.length() < MIN_PASSWORD_LENGTH:
		return "Password must be at least %d characters." % MIN_PASSWORD_LENGTH
	return ""

func _redact_email_for_log(email: String) -> String:
	var normalized := email.strip_edges()
	if normalized.is_empty():
		return "<empty>"
	var at_index := normalized.find("@")
	if at_index <= 0:
		return _redact_id_for_log(normalized)
	var prefix := normalized.substr(0, 1)
	var domain := normalized.substr(at_index)
	return "%s***%s" % [prefix, domain]

func _redact_id_for_log(value: String) -> String:
	var normalized := value.strip_edges()
	if normalized.is_empty():
		return "<empty>"
	if normalized.length() <= 6:
		return "***"
	return "%s...%s" % [normalized.left(3), normalized.substr(normalized.length() - 3, 3)]

func _email_key(email: String) -> String:
	return email.to_lower()

func _username_key(username: String) -> String:
	return username.to_lower()

func _find_reassignable_email_account_id(
	email_key: String,
	excluded_account_id: String,
	normalized_email: String,
	legacy_username: String
) -> String:
	for account_id in _get_account_ids_by_email(email_key, excluded_account_id):
		var account = _accounts_by_id.get(account_id, {})
		if not (account is Dictionary):
			continue
		if _can_reassign_email_account_for_legacy_claim(account as Dictionary, normalized_email, legacy_username):
			return account_id
	return ""

func _can_reassign_email_account_for_legacy_claim(
	email_account: Dictionary,
	normalized_email: String,
	legacy_username: String
) -> bool:
	var email_account_id := str(email_account.get("account_id", "")).strip_edges()
	if email_account_id.is_empty():
		return false
	var stored_email_key := str(email_account.get("email_key", "")).strip_edges().to_lower()
	if stored_email_key.is_empty():
		stored_email_key = _email_key(str(email_account.get("email", "")).strip_edges().to_lower())
	if stored_email_key != _email_key(normalized_email):
		return false
	var email_username_key := str(email_account.get("username_key", "")).strip_edges().to_lower()
	if email_username_key.is_empty():
		email_username_key = _username_key(str(email_account.get("username", "")).strip_edges())
	var generated_username_key := _username_key(_derive_username_from_email(normalized_email))
	var legacy_username_key := _username_key(legacy_username)
	if email_username_key.is_empty() or email_username_key == legacy_username_key:
		return false
	return email_username_key == generated_username_key

func _find_account_id_by_email(email_key: String, excluded_account_id: String = "") -> String:
	var matching_account_ids := _get_account_ids_by_email(email_key, excluded_account_id)
	if matching_account_ids.is_empty():
		return ""
	return matching_account_ids[0]

func _get_account_ids_by_email(email_key: String, excluded_account_id: String = "") -> Array[String]:
	var resolved_email_key := email_key.strip_edges().to_lower()
	var excluded_id := excluded_account_id.strip_edges()
	var matching_account_ids: Array[String] = []
	if resolved_email_key.is_empty():
		return matching_account_ids
	for account_id_variant in _accounts_by_id.keys():
		var account_id := str(account_id_variant).strip_edges()
		if account_id.is_empty() or account_id == excluded_id:
			continue
		var account = _accounts_by_id.get(account_id_variant, {})
		if not (account is Dictionary):
			continue
		var account_dict := account as Dictionary
		var stored_email_key := str(account_dict.get("email_key", "")).strip_edges().to_lower()
		if stored_email_key.is_empty():
			stored_email_key = _email_key(str(account_dict.get("email", "")).strip_edges().to_lower())
		if stored_email_key == resolved_email_key:
			matching_account_ids.append(account_id)
	return matching_account_ids

func _choose_duplicate_email_login_account(account_ids: Array[String], normalized_email: String) -> String:
	if account_ids.is_empty():
		return ""
	if account_ids.size() == 1:
		return account_ids[0]
	var generated_username_key := _username_key(_derive_username_from_email(normalized_email))
	var non_generated_account_ids: Array[String] = []
	for account_id in account_ids:
		var account = _accounts_by_id.get(account_id, {})
		if not (account is Dictionary):
			continue
		var username_key := str((account as Dictionary).get("username_key", "")).strip_edges().to_lower()
		if username_key.is_empty():
			username_key = _username_key(str((account as Dictionary).get("username", "")).strip_edges())
		if not username_key.is_empty() and username_key != generated_username_key:
			non_generated_account_ids.append(account_id)
	var preferred_ids := non_generated_account_ids if not non_generated_account_ids.is_empty() else account_ids
	var oldest_account_id := ""
	var oldest_created_unix := 0
	for account_id in preferred_ids:
		var account = _accounts_by_id.get(account_id, {})
		if not (account is Dictionary):
			continue
		var created_unix := int((account as Dictionary).get("created_unix", 0))
		if oldest_account_id.is_empty() or created_unix < oldest_created_unix:
			oldest_account_id = account_id
			oldest_created_unix = created_unix
	return oldest_account_id

func _derive_username_from_email(email: String) -> String:
	var local_part := email.substr(0, email.find("@"))
	var username := ""
	for char_index in range(local_part.length()):
		var codepoint := local_part.unicode_at(char_index)
		var is_letter_or_number := (codepoint >= 48 and codepoint <= 57) or (codepoint >= 65 and codepoint <= 90) or (codepoint >= 97 and codepoint <= 122)
		if is_letter_or_number:
			username += local_part[char_index]
		elif codepoint == 95 or codepoint == 45 or codepoint == 46:
			username += "_"
	if username.length() > MAX_USERNAME_LENGTH:
		username = username.substr(0, MAX_USERNAME_LENGTH)
	if username.length() < MIN_USERNAME_LENGTH:
		username = "Player%s" % _generate_id_suffix(6)
	return username

func _make_available_username(base_username: String) -> String:
	var clean_base := base_username
	if clean_base.length() > MAX_USERNAME_LENGTH - 5:
		clean_base = clean_base.substr(0, MAX_USERNAME_LENGTH - 5)
	for _attempt in range(100):
		var suffix := _generate_id_suffix(4)
		var candidate := "%s_%s" % [clean_base, suffix]
		if not _account_id_by_username.has(_username_key(candidate)):
			return candidate
	return "%s_%s" % [clean_base.substr(0, MAX_USERNAME_LENGTH - 9), _generate_id_suffix(8)]

func _generate_account_id() -> String:
	return "account_%s" % _generate_id_suffix(16)

func _generate_id_suffix(length: int) -> String:
	const CHARS := "ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnopqrstuvwxyz23456789"
	var bytes := _generate_secure_random_bytes(length)
	var output := ""
	for index in range(length):
		var byte_value := int(bytes[index]) if index < bytes.size() else _rng.randi_range(0, 255)
		output += CHARS[byte_value % CHARS.length()]
	return output

func _build_password_record(password: String) -> Dictionary:
	var salt_bytes := _generate_secure_random_bytes(PASSWORD_SALT_BYTES)
	if salt_bytes.size() != PASSWORD_SALT_BYTES:
		return {}
	var password_hash := _hash_password_pbkdf2(password, salt_bytes, PASSWORD_HASH_ITERATIONS, PASSWORD_HASH_BYTES)
	if password_hash.size() != PASSWORD_HASH_BYTES:
		return {}
	return {
		"password_scheme": PASSWORD_HASH_SCHEME,
		"password_iterations": PASSWORD_HASH_ITERATIONS,
		"password_salt": salt_bytes.hex_encode(),
		"password_hash": password_hash.hex_encode(),
		"password_hash_bytes": PASSWORD_HASH_BYTES,
	}

func _verify_password(password: String, account: Dictionary) -> Dictionary:
	var expected_hash := str(account.get("password_hash", "")).strip_edges()
	var salt := str(account.get("password_salt", "")).strip_edges()
	if expected_hash.is_empty() or salt.is_empty():
		return {"success": false, "needs_rehash": false}
	var scheme := str(account.get("password_scheme", "")).strip_edges()
	if scheme == PASSWORD_HASH_SCHEME:
		var iterations := int(account.get("password_iterations", PASSWORD_HASH_ITERATIONS))
		var hash_bytes := int(account.get("password_hash_bytes", PASSWORD_HASH_BYTES))
		var salt_bytes := _hex_to_bytes(salt)
		if salt_bytes.is_empty() or iterations <= 0 or hash_bytes <= 0:
			return {"success": false, "needs_rehash": false}
		var actual_hash := _hash_password_pbkdf2(password, salt_bytes, iterations, hash_bytes).hex_encode()
		var hashes_match := _constant_time_equals(actual_hash, expected_hash)
		return {
			"success": hashes_match,
			"needs_rehash": hashes_match and (iterations < PASSWORD_HASH_ITERATIONS or hash_bytes < PASSWORD_HASH_BYTES),
		}
	var legacy_hash := _hash_password_legacy(password, salt)
	var legacy_match := _constant_time_equals(legacy_hash, expected_hash)
	return {
		"success": legacy_match,
		"needs_rehash": legacy_match,
	}

func _hash_password_pbkdf2(password: String, salt_bytes: PackedByteArray, iterations: int, output_bytes: int) -> PackedByteArray:
	var password_bytes := password.to_utf8_buffer()
	var derived := PackedByteArray()
	var block_index := 1
	while derived.size() < output_bytes:
		var block_salt := PackedByteArray()
		block_salt.append_array(salt_bytes)
		block_salt.append((block_index >> 24) & 0xff)
		block_salt.append((block_index >> 16) & 0xff)
		block_salt.append((block_index >> 8) & 0xff)
		block_salt.append(block_index & 0xff)
		var u := _hmac_sha256(password_bytes, block_salt)
		if u.is_empty():
			return PackedByteArray()
		var block := u.duplicate()
		for _round in range(1, iterations):
			u = _hmac_sha256(password_bytes, u)
			if u.is_empty():
				return PackedByteArray()
			for index in range(block.size()):
				block[index] = int(block[index]) ^ int(u[index])
		derived.append_array(block)
		block_index += 1
	derived.resize(output_bytes)
	return derived

func _hmac_sha256(key: PackedByteArray, message: PackedByteArray) -> PackedByteArray:
	var context := HMACContext.new()
	if context.start(HashingContext.HASH_SHA256, key) != OK:
		return PackedByteArray()
	if context.update(message) != OK:
		return PackedByteArray()
	return context.finish()

func _hash_password_legacy(password: String, salt: String) -> String:
	var hash_input := (salt + ":" + password).to_utf8_buffer()
	for _round in range(LEGACY_PASSWORD_HASH_ROUNDS):
		var context := HashingContext.new()
		if context.start(HashingContext.HASH_SHA256) != OK:
			return ""
		context.update(hash_input)
		hash_input = context.finish()
	return hash_input.hex_encode()

func _generate_secure_random_bytes(length: int) -> PackedByteArray:
	var crypto := Crypto.new()
	var random_bytes := crypto.generate_random_bytes(length)
	if random_bytes.size() == length:
		return random_bytes
	var fallback := PackedByteArray()
	fallback.resize(length)
	for index in range(length):
		fallback[index] = _rng.randi_range(0, 255)
	return fallback

func _constant_time_equals(left: String, right: String) -> bool:
	var left_bytes := left.to_utf8_buffer()
	var right_bytes := right.to_utf8_buffer()
	var max_size := maxi(left_bytes.size(), right_bytes.size())
	var diff := left_bytes.size() ^ right_bytes.size()
	for index in range(max_size):
		var left_value := int(left_bytes[index]) if index < left_bytes.size() else 0
		var right_value := int(right_bytes[index]) if index < right_bytes.size() else 0
		diff = diff | (left_value ^ right_value)
	return diff == 0

func _hex_to_bytes(hex: String) -> PackedByteArray:
	var clean_hex := hex.strip_edges().to_lower()
	var output := PackedByteArray()
	if clean_hex.length() % 2 != 0:
		return output
	output.resize(clean_hex.length() / 2)
	for index in range(output.size()):
		var high := _hex_value(clean_hex.unicode_at(index * 2))
		var low := _hex_value(clean_hex.unicode_at(index * 2 + 1))
		if high < 0 or low < 0:
			return PackedByteArray()
		output[index] = (high << 4) | low
	return output

func _hex_value(codepoint: int) -> int:
	if codepoint >= 48 and codepoint <= 57:
		return codepoint - 48
	if codepoint >= 97 and codepoint <= 102:
		return codepoint - 87
	return -1

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
	var email := _normalize_email(str(account.get("email", "")))
	if email.is_empty() and username.find("@") > 0:
		email = _normalize_email(username)
		username = _derive_username_from_email(email)
		migration_dirty = true
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
	if not email.is_empty():
		if str(account.get("email", "")).strip_edges() != email:
			migration_dirty = true
		account["email"] = email
		var email_key := _email_key(email)
		if str(account.get("email_key", "")).strip_edges() != email_key:
			migration_dirty = true
		account["email_key"] = email_key
	if not account.has("accepts_game_updates"):
		account["accepts_game_updates"] = false
		migration_dirty = true

	var password_hash := str(account.get("password_hash", "")).strip_edges()
	var password_salt := str(account.get("password_salt", "")).strip_edges()
	if password_hash.is_empty() or password_salt.is_empty():
		var legacy_password := str(account.get("password", ""))
		if legacy_password.is_empty():
			return {
				"account": {},
				"migration_dirty": migration_dirty,
			}
		account.merge(_build_password_record(legacy_password), true)
		account.erase("password")
		migration_dirty = true
	elif str(account.get("password_scheme", "")).strip_edges().is_empty():
		account["password_scheme"] = "legacy_sha256_rounds"
		account["password_iterations"] = LEGACY_PASSWORD_HASH_ROUNDS
		migration_dirty = true
	return {
		"account": account,
		"migration_dirty": migration_dirty,
	}

func _rebuild_account_indexes() -> void:
	_account_id_by_email = {}
	_account_id_by_username = {}
	for account_id in _accounts_by_id.keys():
		var account = _accounts_by_id[account_id]
		if not (account is Dictionary):
			continue
		var email_key := str((account as Dictionary).get("email_key", "")).strip_edges()
		if email_key.is_empty():
			email_key = _email_key(str((account as Dictionary).get("email", "")))
		if not email_key.is_empty():
			if _account_id_by_email.has(email_key):
				print(
					"AccountStore: duplicate email index ignored key=%s existing=%s duplicate=%s" % [
						_redact_id_for_log(email_key),
						_redact_id_for_log(str(_account_id_by_email.get(email_key, ""))),
						_redact_id_for_log(str(account_id)),
					]
				)
			else:
				_account_id_by_email[email_key] = str(account_id)
		var username_key := str((account as Dictionary).get("username_key", "")).strip_edges()
		if username_key.is_empty():
			username_key = _username_key(str((account as Dictionary).get("username", "")))
		if not username_key.is_empty():
			if _account_id_by_username.has(username_key):
				print(
					"AccountStore: duplicate username index ignored key=%s existing=%s duplicate=%s" % [
						username_key,
						_redact_id_for_log(str(_account_id_by_username.get(username_key, ""))),
						_redact_id_for_log(str(account_id)),
					]
				)
			else:
				_account_id_by_username[username_key] = str(account_id)
