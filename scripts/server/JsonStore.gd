extends RefCounted
class_name JsonStore

const MAX_JSON_STORE_BYTES := 16777216

static func load_dictionary(storage_path: String, fallback: Dictionary = {}, label: String = "JsonStore") -> Dictionary:
	var resolved_path := _globalize_path(storage_path)
	var primary := _read_dictionary_result(resolved_path)
	if bool(primary.get("ok", false)):
		return (primary.get("data", {}) as Dictionary).duplicate(true)
	if FileAccess.file_exists(resolved_path):
		push_warning("%s: failed to read %s, trying backup." % [label, resolved_path])
	var backup_path := _backup_path(resolved_path)
	var backup := _read_dictionary_result(backup_path)
	if bool(backup.get("ok", false)):
		push_warning("%s: recovered %s from backup." % [label, resolved_path])
		return (backup.get("data", {}) as Dictionary).duplicate(true)
	return fallback.duplicate(true)

static func save_json(storage_path: String, payload, label: String = "JsonStore") -> bool:
	var resolved_path := _globalize_path(storage_path)
	var parent_dir := resolved_path.get_base_dir()
	if not parent_dir.is_empty():
		DirAccess.make_dir_recursive_absolute(parent_dir)

	var temp_path := _temp_path(resolved_path)
	var backup_path := _backup_path(resolved_path)
	var json_text := JSON.stringify(payload, "\t")
	if json_text.to_utf8_buffer().size() > MAX_JSON_STORE_BYTES:
		push_warning("%s: refusing to write oversized JSON store %s." % [label, resolved_path])
		return false

	var file := FileAccess.open(temp_path, FileAccess.WRITE)
	if file == null:
		push_warning("%s: failed to open temp JSON store %s." % [label, temp_path])
		return false
	file.store_string(json_text)
	file.flush()
	file.close()

	if FileAccess.file_exists(resolved_path):
		if FileAccess.file_exists(backup_path):
			DirAccess.remove_absolute(backup_path)
		if not _copy_file(resolved_path, backup_path):
			push_warning("%s: failed to create JSON backup %s." % [label, backup_path])
			DirAccess.remove_absolute(temp_path)
			return false
		var remove_error := DirAccess.remove_absolute(resolved_path)
		if remove_error != OK:
			push_warning("%s: failed to replace JSON store %s (%s)." % [label, resolved_path, error_string(remove_error)])
			DirAccess.remove_absolute(temp_path)
			return false

	var rename_error := DirAccess.rename_absolute(temp_path, resolved_path)
	if rename_error == OK:
		return true

	push_warning("%s: failed to promote temp JSON store %s (%s)." % [label, resolved_path, error_string(rename_error)])
	if FileAccess.file_exists(backup_path) and not FileAccess.file_exists(resolved_path):
		_copy_file(backup_path, resolved_path)
	DirAccess.remove_absolute(temp_path)
	return false

static func _read_dictionary_result(storage_path: String) -> Dictionary:
	if not FileAccess.file_exists(storage_path):
		return {"ok": false, "data": {}}
	var file := FileAccess.open(storage_path, FileAccess.READ)
	if file == null:
		return {"ok": false, "data": {}}
	if file.get_length() > MAX_JSON_STORE_BYTES:
		file.close()
		return {"ok": false, "data": {}}
	var parsed = JSON.parse_string(file.get_as_text())
	file.close()
	if parsed is Dictionary:
		return {"ok": true, "data": (parsed as Dictionary).duplicate(true)}
	return {"ok": false, "data": {}}

static func _copy_file(source_path: String, target_path: String) -> bool:
	if not FileAccess.file_exists(source_path):
		return false
	var source_file := FileAccess.open(source_path, FileAccess.READ)
	if source_file == null:
		return false
	var content := source_file.get_buffer(source_file.get_length())
	source_file.close()

	var parent_dir := target_path.get_base_dir()
	if not parent_dir.is_empty():
		DirAccess.make_dir_recursive_absolute(parent_dir)
	var target_file := FileAccess.open(target_path, FileAccess.WRITE)
	if target_file == null:
		return false
	target_file.store_buffer(content)
	target_file.flush()
	target_file.close()
	return FileAccess.file_exists(target_path)

static func _globalize_path(storage_path: String) -> String:
	if storage_path.begins_with("res://") or storage_path.begins_with("user://"):
		return ProjectSettings.globalize_path(storage_path)
	return storage_path

static func _temp_path(storage_path: String) -> String:
	return "%s.tmp" % storage_path

static func _backup_path(storage_path: String) -> String:
	return "%s.bak" % storage_path
