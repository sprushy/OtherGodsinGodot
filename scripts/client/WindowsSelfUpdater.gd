extends Node
class_name WindowsSelfUpdater

const MODE_ARG := "self_update"
const TARGET_DIR_ARG := "update_target_dir"
const TARGET_EXE_ARG := "update_target_exe"
const WAIT_PID_ARG := "update_wait_pid"
const HANDSHAKE_ARG := "update_handshake"
const EXPECTED_SHA256_ARG := "update_expected_sha256"
const VERSION_ARG := "update_version"
const LOG_PATH_ARG := "update_log_path"
const FAILURE_MARKER_ARG := "update_failure_marker"
const UPDATE_MODE_VALUE := "windows_native"
const PROCESS_WAIT_ATTEMPTS := 120
const PROCESS_WAIT_DELAY_SECONDS := 0.25
const FILE_RETRY_ATTEMPTS := 20
const FILE_RETRY_DELAY_SECONDS := 0.5

var _log_path: String = ""
var _failure_marker_path: String = ""
var _target_exe_path: String = ""
var _target_dir: String = ""
var _source_dir: String = ""
var _version: String = ""

static func is_update_launch(launch_args: Dictionary) -> bool:
	return str(launch_args.get(MODE_ARG, "")).strip_edges() == UPDATE_MODE_VALUE

func start(launch_args: Dictionary) -> void:
	call_deferred("_run_update", launch_args)

func _run_update(launch_args: Dictionary) -> void:
	_log_path = str(launch_args.get(LOG_PATH_ARG, "")).strip_edges()
	_failure_marker_path = str(launch_args.get(FAILURE_MARKER_ARG, "")).strip_edges()
	_target_dir = str(launch_args.get(TARGET_DIR_ARG, "")).strip_edges().simplify_path()
	_target_exe_path = str(launch_args.get(TARGET_EXE_ARG, "")).strip_edges().simplify_path()
	_version = str(launch_args.get(VERSION_ARG, "")).strip_edges()
	var handshake_path := str(launch_args.get(HANDSHAKE_ARG, "")).strip_edges()
	var expected_sha256 := str(
		launch_args.get(EXPECTED_SHA256_ARG, "")
	).strip_edges().to_lower()
	var source_exe_path := OS.get_executable_path().simplify_path()
	_source_dir = source_exe_path.get_base_dir()
	var wait_pid := int(str(launch_args.get(WAIT_PID_ARG, "0")))

	_write_log(
		"native_runner_started version=%s pid=%d source=%s target=%s"
		% [_version, OS.get_process_id(), source_exe_path, _target_exe_path]
	)
	var validation_error := _validate_launch(
		source_exe_path,
		expected_sha256,
		handshake_path
	)
	if not validation_error.is_empty():
		_write_log("native_runner_rejected error=%s" % validation_error)
		get_tree().quit(1)
		return

	var handshake_file := FileAccess.open(handshake_path, FileAccess.WRITE)
	if handshake_file == null:
		_write_log("native_runner_handshake_failed path=%s" % handshake_path)
		get_tree().quit(1)
		return
	handshake_file.store_string("ready")
	handshake_file.close()
	_write_log("native_runner_ready wait_pid=%d" % wait_pid)

	if wait_pid > 0:
		for _attempt in range(PROCESS_WAIT_ATTEMPTS):
			if not OS.is_process_running(wait_pid):
				break
			await get_tree().create_timer(PROCESS_WAIT_DELAY_SECONDS).timeout
		if OS.is_process_running(wait_pid):
			_fail_and_restart(
				"The automatic updater timed out waiting for the previous game process to close."
			)
			return

	var relative_files := _collect_relative_files(_source_dir)
	if relative_files.is_empty():
		_fail_and_restart("The automatic updater could not find the staged update files.")
		return
	var target_exe_relative := _target_exe_path.get_file()
	if not relative_files.has(target_exe_relative):
		_fail_and_restart("The staged update did not contain the expected game executable.")
		return
	relative_files.erase(target_exe_relative)
	relative_files.append(target_exe_relative)

	var committed_files: Array[Dictionary] = []
	for relative_path in relative_files:
		var source_path := _source_dir.path_join(relative_path)
		var target_path := _target_dir.path_join(relative_path)
		var install_result := await _install_file_transactionally(source_path, target_path)
		if not bool(install_result.get("ok", false)):
			_rollback_committed_files(committed_files)
			_fail_and_restart(
				"Windows security or antivirus blocked installing %s: %s"
				% [relative_path, str(install_result.get("error", "unknown error"))]
			)
			return
		committed_files.append(install_result)

	for committed in committed_files:
		var backup_path := str(committed.get("backup_path", ""))
		if not backup_path.is_empty() and FileAccess.file_exists(backup_path):
			DirAccess.remove_absolute(backup_path)

	var restart_pid := OS.create_process(_target_exe_path, PackedStringArray(), false)
	if restart_pid == -1:
		_write_failure(
			"The update was installed, but Windows security blocked restarting Other Gods."
		)
		_write_log("native_update_installed restart_failed target=%s" % _target_exe_path)
		get_tree().quit(1)
		return
	_remove_file_if_present(_failure_marker_path)
	_write_log(
		"native_update_complete version=%s restart_pid=%d target=%s"
		% [_version, restart_pid, _target_exe_path]
	)
	get_tree().quit()

func _validate_launch(
	source_exe_path: String,
	expected_sha256: String,
	handshake_path: String
) -> String:
	if OS.get_name() != "Windows":
		return "native updater was launched on a non-Windows platform"
	if source_exe_path.is_empty() or not FileAccess.file_exists(source_exe_path):
		return "staged updater executable is missing"
	if _target_dir.is_empty() or _target_exe_path.is_empty():
		return "target path is missing"
	if _target_exe_path.get_base_dir() != _target_dir:
		return "target executable is outside the target directory"
	if handshake_path.is_empty():
		return "handshake path is missing"
	if not expected_sha256.is_empty():
		var source_sha256 := FileAccess.get_sha256(source_exe_path).to_lower()
		if source_sha256.is_empty() or source_sha256 != expected_sha256:
			return "staged updater executable failed SHA-256 verification"
	return ""

func _collect_relative_files(root_path: String) -> Array[String]:
	var relative_files: Array[String] = []
	_collect_relative_files_recursive(root_path, "", relative_files)
	relative_files.sort()
	return relative_files

func _collect_relative_files_recursive(
	root_path: String,
	relative_dir: String,
	relative_files: Array[String]
) -> void:
	var absolute_dir := root_path
	if not relative_dir.is_empty():
		absolute_dir = root_path.path_join(relative_dir)
	var dir := DirAccess.open(absolute_dir)
	if dir == null:
		return
	dir.list_dir_begin()
	var entry_name := dir.get_next()
	while not entry_name.is_empty():
		if entry_name == "." or entry_name == "..":
			entry_name = dir.get_next()
			continue
		var relative_path := entry_name
		if not relative_dir.is_empty():
			relative_path = relative_dir.path_join(entry_name)
		if dir.current_is_dir():
			_collect_relative_files_recursive(root_path, relative_path, relative_files)
		else:
			relative_files.append(relative_path)
		entry_name = dir.get_next()
	dir.list_dir_end()

func _install_file_transactionally(source_path: String, target_path: String) -> Dictionary:
	var temp_path := "%s.update-new" % target_path
	var backup_path := "%s.update-old" % target_path
	var source_sha256 := FileAccess.get_sha256(source_path).to_lower()
	if source_sha256.is_empty():
		return {"ok": false, "error": "could not hash staged file"}
	var last_error := "copy failed"

	for attempt in range(1, FILE_RETRY_ATTEMPTS + 1):
		if DirAccess.make_dir_recursive_absolute(target_path.get_base_dir()) != OK:
			last_error = "could not create target directory"
		else:
			_remove_file_if_present(temp_path)
			var copy_error := DirAccess.copy_absolute(source_path, temp_path)
			if copy_error == OK:
				var temp_sha256 := FileAccess.get_sha256(temp_path).to_lower()
				if temp_sha256 != source_sha256:
					last_error = "temporary copy failed SHA-256 verification"
				else:
					var had_existing_target := FileAccess.file_exists(target_path)
					if not _prepare_backup(target_path, backup_path, had_existing_target):
						last_error = "could not move the existing file aside"
					else:
						var replace_error := DirAccess.rename_absolute(temp_path, target_path)
						if replace_error != OK:
							last_error = "could not move the verified file into place (%d)" % replace_error
							_restore_backup(target_path, backup_path, had_existing_target)
						elif FileAccess.get_sha256(target_path).to_lower() != source_sha256:
							last_error = "installed file failed SHA-256 verification"
							_restore_backup(target_path, backup_path, had_existing_target)
						else:
							_write_log(
								"native_file_installed attempt=%d path=%s sha256=%s"
								% [attempt, target_path, source_sha256]
							)
							return {
								"ok": true,
								"target_path": target_path,
								"backup_path": backup_path if had_existing_target else "",
								"had_existing_target": had_existing_target,
							}
			else:
				last_error = "copy failed (%d)" % copy_error

		_write_log(
			"native_file_attempt_failed attempt=%d path=%s error=%s"
			% [attempt, target_path, last_error]
		)
		await get_tree().create_timer(FILE_RETRY_DELAY_SECONDS).timeout

	_remove_file_if_present(temp_path)
	return {"ok": false, "error": last_error}

func _prepare_backup(target_path: String, backup_path: String, had_existing_target: bool) -> bool:
	_remove_file_if_present(backup_path)
	if FileAccess.file_exists(backup_path):
		return false
	if not had_existing_target:
		return true
	return DirAccess.rename_absolute(target_path, backup_path) == OK

func _restore_backup(target_path: String, backup_path: String, had_existing_target: bool) -> void:
	_remove_file_if_present(target_path)
	if had_existing_target and FileAccess.file_exists(backup_path):
		DirAccess.rename_absolute(backup_path, target_path)

func _rollback_committed_files(committed_files: Array[Dictionary]) -> void:
	committed_files.reverse()
	for committed in committed_files:
		var target_path := str(committed.get("target_path", ""))
		var backup_path := str(committed.get("backup_path", ""))
		var had_existing_target := bool(committed.get("had_existing_target", false))
		_restore_backup(target_path, backup_path, had_existing_target)
		_write_log("native_file_rolled_back path=%s" % target_path)

func _fail_and_restart(message: String) -> void:
	_write_failure(message)
	_write_log("native_update_failed version=%s message=%s" % [_version, message])
	if FileAccess.file_exists(_target_exe_path):
		var restart_pid := OS.create_process(_target_exe_path, PackedStringArray(), false)
		_write_log("native_failure_restart pid=%d target=%s" % [restart_pid, _target_exe_path])
	get_tree().quit(1)

func _write_log(message: String) -> void:
	if _log_path.is_empty():
		return
	var file := FileAccess.open(_log_path, FileAccess.READ_WRITE)
	if file == null:
		file = FileAccess.open(_log_path, FileAccess.WRITE)
	if file == null:
		return
	file.seek_end()
	file.store_line("%s %s" % [Time.get_datetime_string_from_system(), message])
	file.flush()
	file.close()

func _write_failure(message: String) -> void:
	if _failure_marker_path.is_empty():
		return
	var file := FileAccess.open(_failure_marker_path, FileAccess.WRITE)
	if file == null:
		return
	file.store_string(message)
	file.close()

func _remove_file_if_present(path: String) -> void:
	if not path.is_empty() and FileAccess.file_exists(path):
		DirAccess.remove_absolute(path)
