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
const PROCESS_WAIT_ATTEMPTS := 300
const PROCESS_WAIT_DELAY_SECONDS := 0.1
const FILE_RETRY_ATTEMPTS := 20
const FILE_RETRY_DELAY_SECONDS := 0.5
const COPY_BUFFER_BYTES := 4194304
const UPDATE_WINDOW_WIDTH := 620
const UPDATE_WINDOW_HEIGHT := 300
const PROGRESS_PULSE_SPEED := 28.0

var _log_path: String = ""
var _failure_marker_path: String = ""
var _target_exe_path: String = ""
var _target_dir: String = ""
var _source_dir: String = ""
var _version: String = ""
var _expected_sha256: String = ""
var _status_label: Label = null
var _detail_label: Label = null
var _progress_bar: ProgressBar = null

static func is_update_launch(launch_args: Dictionary) -> bool:
	return str(launch_args.get(MODE_ARG, "")).strip_edges() == UPDATE_MODE_VALUE

func start(launch_args: Dictionary) -> void:
	get_tree().auto_accept_quit = false
	_build_update_window()
	_set_update_status(
		"Preparing update...",
		"Other Gods will close and reopen automatically. Do not close this updater window."
	)
	call_deferred("_run_update", launch_args)

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		_set_update_status(
			"Update in progress...",
			"Please keep this updater window open. Other Gods will reopen automatically when installation finishes."
		)

func _process(delta: float) -> void:
	if _progress_bar == null or not is_instance_valid(_progress_bar):
		return
	_progress_bar.value = fmod(_progress_bar.value + delta * PROGRESS_PULSE_SPEED, 100.0)

func _run_update(launch_args: Dictionary) -> void:
	_log_path = str(launch_args.get(LOG_PATH_ARG, "")).strip_edges()
	_failure_marker_path = str(launch_args.get(FAILURE_MARKER_ARG, "")).strip_edges()
	_target_dir = str(launch_args.get(TARGET_DIR_ARG, "")).strip_edges().simplify_path()
	_target_exe_path = str(launch_args.get(TARGET_EXE_ARG, "")).strip_edges().simplify_path()
	_version = str(launch_args.get(VERSION_ARG, "")).strip_edges()
	var handshake_path := str(launch_args.get(HANDSHAKE_ARG, "")).strip_edges()
	_expected_sha256 = str(
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
		handshake_path
	)
	if not validation_error.is_empty():
		_set_update_status(
			"Update could not start.",
			"Reopening the existing install. %s" % validation_error
		)
		_write_log("native_runner_rejected error=%s" % validation_error)
		get_tree().quit(1)
		return

	var handshake_file := FileAccess.open(handshake_path, FileAccess.WRITE)
	if handshake_file == null:
		_set_update_status(
			"Update could not start.",
			"Reopening the existing install. Windows blocked the updater readiness check."
		)
		_write_log("native_runner_handshake_failed path=%s" % handshake_path)
		get_tree().quit(1)
		return
	handshake_file.store_string("ready")
	handshake_file.close()
	_write_log("native_runner_ready wait_pid=%d" % wait_pid)
	_set_update_status(
		"Waiting for Other Gods to close...",
		"The game window may disappear briefly. This updater will install the verified files and reopen it."
	)

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
	for file_index in range(relative_files.size()):
		var relative_path := relative_files[file_index]
		_set_update_status(
			"Installing update files...",
			"File %d of %d: %s\nDo not close this window. Windows security may scan new files here."
			% [file_index + 1, relative_files.size(), relative_path]
		)
		var source_path := _source_dir.path_join(relative_path)
		var target_path := _target_dir.path_join(relative_path)
		var expected_sha256 := _expected_sha256 if relative_path == target_exe_relative else ""
		var install_result := await _install_file_transactionally(
			source_path,
			target_path,
			expected_sha256
		)
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

	_set_update_status(
		"Restarting Other Gods...",
		"The update is installed. The game should reopen in a moment."
	)
	var restart_pid := OS.create_process(_target_exe_path, PackedStringArray(), false)
	if restart_pid == -1:
		_set_update_status(
			"Update installed, restart blocked.",
			"Windows security blocked reopening Other Gods. Start it manually from the install folder."
		)
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

func _build_update_window() -> void:
	if DisplayServer.get_name() == "headless":
		return
	DisplayServer.window_set_title("Other Gods Updater")
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	DisplayServer.window_set_size(Vector2i(UPDATE_WINDOW_WIDTH, UPDATE_WINDOW_HEIGHT))

	var layer := CanvasLayer.new()
	layer.name = "UpdateStatusLayer"
	add_child(layer)

	var root := Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_STOP
	layer.add_child(root)

	var background := ColorRect.new()
	background.color = Color(0.018, 0.022, 0.038, 1.0)
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	background.mouse_filter = Control.MOUSE_FILTER_STOP
	root.add_child(background)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(center)

	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(520.0, 0.0)
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = Color(0.08, 0.09, 0.14, 0.98)
	panel_style.border_color = Color(0.38, 0.66, 1.0, 0.92)
	panel_style.corner_radius_top_left = 8
	panel_style.corner_radius_top_right = 8
	panel_style.corner_radius_bottom_left = 8
	panel_style.corner_radius_bottom_right = 8
	for side in [SIDE_LEFT, SIDE_RIGHT, SIDE_TOP, SIDE_BOTTOM]:
		panel_style.set_border_width(side as Side, 2)
	panel.add_theme_stylebox_override("panel", panel_style)
	center.add_child(panel)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 22)
	margin.add_theme_constant_override("margin_right", 22)
	margin.add_theme_constant_override("margin_top", 20)
	margin.add_theme_constant_override("margin_bottom", 20)
	panel.add_child(margin)

	var content := VBoxContainer.new()
	content.alignment = BoxContainer.ALIGNMENT_CENTER
	content.add_theme_constant_override("separation", 12)
	margin.add_child(content)

	var title := Label.new()
	title.text = "Updating Other Gods"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 26)
	title.add_theme_color_override("font_color", Color(0.92, 0.84, 0.62))
	content.add_child(title)

	_status_label = Label.new()
	_status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_status_label.add_theme_font_size_override("font_size", 18)
	_status_label.add_theme_color_override("font_color", Color(0.94, 0.96, 1.0))
	content.add_child(_status_label)

	_progress_bar = ProgressBar.new()
	_progress_bar.min_value = 0.0
	_progress_bar.max_value = 100.0
	_progress_bar.value = 8.0
	_progress_bar.show_percentage = false
	_progress_bar.custom_minimum_size = Vector2(420.0, 10.0)
	content.add_child(_progress_bar)

	_detail_label = Label.new()
	_detail_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_detail_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_detail_label.custom_minimum_size = Vector2(460.0, 64.0)
	_detail_label.add_theme_font_size_override("font_size", 14)
	_detail_label.add_theme_color_override("font_color", Color(0.76, 0.82, 0.92))
	content.add_child(_detail_label)

	set_process(true)

func _set_update_status(status: String, detail: String = "") -> void:
	if _status_label != null and is_instance_valid(_status_label):
		_status_label.text = status
	if _detail_label != null and is_instance_valid(_detail_label):
		_detail_label.text = detail

func _validate_launch(
	source_exe_path: String,
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
	if not _is_sha256(_expected_sha256):
		return "staged updater executable SHA-256 is missing or invalid"
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

func _install_file_transactionally(
	source_path: String,
	target_path: String,
	expected_sha256: String = ""
) -> Dictionary:
	var temp_path := "%s.update-new" % target_path
	var backup_path := "%s.update-old" % target_path
	var source_sha256 := expected_sha256
	if source_sha256.is_empty():
		source_sha256 = FileAccess.get_sha256(source_path).to_lower()
	if source_sha256.is_empty():
		return {"ok": false, "error": "could not hash staged file"}
	var last_error := "copy failed"

	for attempt in range(1, FILE_RETRY_ATTEMPTS + 1):
		if DirAccess.make_dir_recursive_absolute(target_path.get_base_dir()) != OK:
			last_error = "could not create target directory"
		else:
			_remove_file_if_present(temp_path)
			var moved_source_to_temp := false
			var copy_result := {"ok": false, "error": ""}
			if expected_sha256.is_empty():
				var move_result := _move_source_to_temp_if_possible(
					source_path,
					temp_path,
					source_sha256
				)
				if bool(move_result.get("ok", false)):
					moved_source_to_temp = true
					copy_result = move_result
				else:
					var move_error := str(move_result.get("error", "move unavailable"))
					if not move_error.is_empty():
						_write_log(
							"native_fast_move_unavailable attempt=%d path=%s error=%s"
							% [attempt, target_path, move_error]
						)
			if not bool(copy_result.get("ok", false)):
				copy_result = _copy_file_with_sha256(source_path, temp_path)
			if bool(copy_result.get("ok", false)):
				var temp_sha256 := str(copy_result.get("sha256", "")).to_lower()
				if temp_sha256 != source_sha256:
					last_error = "temporary copy failed SHA-256 verification"
					_restore_moved_source(source_path, temp_path, moved_source_to_temp)
				else:
					var had_existing_target := FileAccess.file_exists(target_path)
					if not _prepare_backup(target_path, backup_path, had_existing_target):
						last_error = "could not move the existing file aside"
						_restore_moved_source(source_path, temp_path, moved_source_to_temp)
					else:
						var replace_error := DirAccess.rename_absolute(temp_path, target_path)
						if replace_error != OK:
							last_error = "could not move the verified file into place (%d)" % replace_error
							_restore_backup(target_path, backup_path, had_existing_target)
							_restore_moved_source(source_path, temp_path, moved_source_to_temp)
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
				last_error = str(copy_result.get("error", "copy failed"))

		_write_log(
			"native_file_attempt_failed attempt=%d path=%s error=%s"
			% [attempt, target_path, last_error]
		)
		await get_tree().create_timer(FILE_RETRY_DELAY_SECONDS).timeout

	_remove_file_if_present(temp_path)
	return {"ok": false, "error": last_error}

func _move_source_to_temp_if_possible(
	source_path: String,
	temp_path: String,
	source_sha256: String
) -> Dictionary:
	if source_path.is_empty() or temp_path.is_empty():
		return {"ok": false, "error": "source or temporary path missing"}
	if not FileAccess.file_exists(source_path):
		return {"ok": false, "error": "staged file is missing"}
	var source_size := _get_file_size(source_path)
	if source_size < 0:
		return {"ok": false, "error": "could not measure staged file"}
	var move_error := DirAccess.rename_absolute(source_path, temp_path)
	if move_error != OK:
		return {"ok": false, "error": "rename returned %d" % move_error}
	if _get_file_size(temp_path) != source_size:
		_restore_moved_source(source_path, temp_path, true)
		return {"ok": false, "error": "moved file size verification failed"}
	_write_log("native_fast_move_used temp=%s sha256=%s" % [temp_path, source_sha256])
	return {
		"ok": true,
		"sha256": source_sha256,
	}

func _restore_moved_source(source_path: String, temp_path: String, moved_source_to_temp: bool) -> void:
	if not moved_source_to_temp or not FileAccess.file_exists(temp_path):
		return
	_remove_file_if_present(source_path)
	var restore_error := DirAccess.rename_absolute(temp_path, source_path)
	if restore_error != OK:
		_write_log(
			"native_fast_move_restore_failed source=%s temp=%s error=%d"
			% [source_path, temp_path, restore_error]
		)

func _copy_file_with_sha256(source_path: String, target_path: String) -> Dictionary:
	var source_file := FileAccess.open(source_path, FileAccess.READ)
	if source_file == null:
		return {"ok": false, "error": "could not open staged file for copying"}
	var target_file := FileAccess.open(target_path, FileAccess.WRITE)
	if target_file == null:
		source_file.close()
		return {"ok": false, "error": "could not open temporary file for copying"}
	var hash_context := HashingContext.new()
	if hash_context.start(HashingContext.HASH_SHA256) != OK:
		source_file.close()
		target_file.close()
		_remove_file_if_present(target_path)
		return {"ok": false, "error": "could not start SHA-256 verification"}

	var source_size := source_file.get_length()
	var copied_bytes := 0
	while copied_bytes < source_size:
		var requested_bytes := mini(COPY_BUFFER_BYTES, source_size - copied_bytes)
		var buffer := source_file.get_buffer(requested_bytes)
		if buffer.size() != requested_bytes:
			source_file.close()
			target_file.close()
			_remove_file_if_present(target_path)
			return {"ok": false, "error": "staged file read ended unexpectedly"}
		if hash_context.update(buffer) != OK:
			source_file.close()
			target_file.close()
			_remove_file_if_present(target_path)
			return {"ok": false, "error": "could not update SHA-256 verification"}
		target_file.store_buffer(buffer)
		if target_file.get_error() != OK:
			source_file.close()
			target_file.close()
			_remove_file_if_present(target_path)
			return {"ok": false, "error": "temporary file write failed"}
		copied_bytes += buffer.size()

	target_file.flush()
	var write_error := target_file.get_error()
	source_file.close()
	target_file.close()
	if write_error != OK or _get_file_size(target_path) != source_size:
		_remove_file_if_present(target_path)
		return {"ok": false, "error": "temporary copy size verification failed"}
	return {
		"ok": true,
		"sha256": hash_context.finish().hex_encode(),
	}

func _is_sha256(value: String) -> bool:
	if value.length() != 64:
		return false
	for index in range(value.length()):
		var code := value.unicode_at(index)
		var is_digit := code >= 48 and code <= 57
		var is_lower_hex := code >= 97 and code <= 102
		if not is_digit and not is_lower_hex:
			return false
	return true

func _get_file_size(path: String) -> int:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return -1
	var file_size := file.get_length()
	file.close()
	return file_size

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
