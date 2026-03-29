extends Node
class_name MatchSupervisor

const MatchSessionScript = preload("res://scripts/server/MatchSession.gd")
const ServerPathsScript = preload("res://scripts/server/ServerPaths.gd")
const HEADLESS_ENTRY_SCRIPT_PATH := "res://scripts/server/HeadlessMatchServerMain.gd"
const DEDICATED_SERVER_EXPORT_RELATIVE_PATH := "res://.exports/server/ClaudeOtherGodsServer.exe"

signal match_created(match_session)
signal match_closed(match_id: String, room_id: String, final_status: String)

var server_ip: String = "127.0.0.1"
var default_match_port: int = 12345
var use_dedicated_headless: bool = true
var godot_executable_path: String = ""
var project_path: String = ""
var allow_in_process_fallback: bool = true
var active_matches: Dictionary = {}
var last_create_match_error: String = ""

var _rng := RandomNumberGenerator.new()
var _cleanup_poll_interval_seconds: float = 1.0
var _cleanup_poll_elapsed: float = 0.0

func _ready() -> void:
	_rng.randomize()

func _process(delta: float) -> void:
	_cleanup_poll_elapsed += delta
	if _cleanup_poll_elapsed < _cleanup_poll_interval_seconds:
		return
	_cleanup_poll_elapsed = 0.0
	_refresh_active_matches()

func configure(
	p_server_ip: String,
	p_default_match_port: int,
	p_use_dedicated_headless: bool = true,
	p_godot_executable_path: String = "",
	p_project_path: String = "",
	p_allow_in_process_fallback: bool = true
) -> void:
	server_ip = p_server_ip
	default_match_port = p_default_match_port
	use_dedicated_headless = p_use_dedicated_headless
	godot_executable_path = _resolve_runtime_executable_path(p_godot_executable_path)
	project_path = p_project_path if not p_project_path.is_empty() else ProjectSettings.globalize_path("res://")
	allow_in_process_fallback = p_allow_in_process_fallback

func create_match(
	room_id: String,
	player_session_ids: Array[String],
	player_decks_by_session: Dictionary = {},
	player_identity_by_session: Dictionary = {}
):
	last_create_match_error = ""
	var match_id: String = _generate_match_id()
	while active_matches.has(match_id):
		match_id = _generate_match_id()

	var match_port := _allocate_match_port()

	var session := MatchSessionScript.new(
		match_id,
		room_id,
		server_ip,
		match_port,
		player_session_ids,
		player_decks_by_session,
		player_identity_by_session
	)
	session.mark_active()
	if use_dedicated_headless and _launch_dedicated_match(session):
		session.server_mode = MatchSessionScript.SERVER_MODE_DEDICATED_HEADLESS
	elif use_dedicated_headless and not allow_in_process_fallback:
		last_create_match_error = session.process_launch_error
		return null
	else:
		session.server_mode = MatchSessionScript.SERVER_MODE_IN_PROCESS_HOST
	active_matches[match_id] = session
	match_created.emit(session)
	return session

func get_match(match_id: String):
	return active_matches.get(match_id, null)

func close_match(
	match_id: String,
	final_status: String = MatchSessionScript.STATUS_FINISHED,
	terminate_process: bool = true
) -> void:
	if not active_matches.has(match_id):
		return
	var session = active_matches[match_id]
	_apply_final_status(session, final_status)
	_shutdown_match_runtime(session, terminate_process)
	active_matches.erase(match_id)
	match_closed.emit(match_id, str(session.room_id), str(session.status))

func clear() -> void:
	for match_id in active_matches.keys().duplicate():
		close_match(str(match_id), MatchSessionScript.STATUS_ABANDONED, true)

func _generate_match_id() -> String:
	const CHARS := "ABCDEFGHJKLMNPQRSTUVWXYZ23456789"
	var output: String = "match_"
	for _i in 8:
		output += CHARS[_rng.randi_range(0, CHARS.length() - 1)]
	return output

func _allocate_match_port() -> int:
	var allocated_port := default_match_port
	var used_ports: Dictionary = {}
	for session in active_matches.values():
		if session == null:
			continue
		used_ports[int(session.match_port)] = true
	while used_ports.has(allocated_port):
		allocated_port += 1
	return allocated_port

func _launch_dedicated_match(session) -> bool:
	if session == null:
		return false
	var uses_exported_runtime := _is_exported_server_runtime(godot_executable_path)
	if godot_executable_path.is_empty() or (not uses_exported_runtime and project_path.is_empty()):
		session.mark_process_launch_failed("Godot executable path or project path was not configured.")
		return false

	var config_path := _write_launch_config(session)
	if config_path.is_empty():
		session.mark_process_launch_failed("Failed to write the dedicated match launch config.")
		return false

	var args := PackedStringArray(["--headless"])
	if uses_exported_runtime:
		args.append_array([
			"--",
			"server_mode=match",
			"match_config=%s" % config_path,
		])
	else:
		if not OS.has_feature("template"):
			args.append("--editor")
		args.append_array([
			"--path",
			project_path,
			"--script",
			HEADLESS_ENTRY_SCRIPT_PATH,
			"--",
			"match_config=%s" % config_path,
		])
	var pid := OS.create_process(godot_executable_path, args, false)
	if pid <= 0:
		session.mark_process_launch_failed("OS.create_process failed for the dedicated headless match server.")
		return false

	session.mark_process_launched(pid, config_path)
	return true

func _write_launch_config(session) -> String:
	var base_dir := ServerPathsScript.get_dedicated_matches_dir()
	var mkdir_err := DirAccess.make_dir_recursive_absolute(base_dir)
	if mkdir_err != OK and mkdir_err != ERR_ALREADY_EXISTS:
		return ""
	var config_path := base_dir.path_join("%s.json" % str(session.match_id))
	var file := FileAccess.open(config_path, FileAccess.WRITE)
	if file == null:
		return ""
	file.store_string(JSON.stringify(session.to_launch_config(), "\t"))
	file.close()
	return config_path

func _refresh_active_matches() -> void:
	if active_matches.is_empty():
		return
	var now_unix := int(Time.get_unix_time_from_system())
	for match_id in active_matches.keys().duplicate():
		var session = active_matches.get(match_id, null)
		if session == null or not session.is_dedicated_headless():
			continue
		if session.has_reconnect_timed_out(now_unix):
			close_match(str(match_id), MatchSessionScript.STATUS_ABANDONED, true)
			continue
		if session.has_spawned_process() and not OS.is_process_running(int(session.process_id)):
			close_match(str(match_id), MatchSessionScript.STATUS_FINISHED, false)

func _apply_final_status(session, final_status: String) -> void:
	match final_status:
		MatchSessionScript.STATUS_ABANDONED:
			session.mark_abandoned()
		MatchSessionScript.STATUS_FINISHED:
			session.mark_finished()
		MatchSessionScript.STATUS_ACTIVE:
			session.mark_active()
		_:
			session.status = final_status

func _shutdown_match_runtime(session, terminate_process: bool) -> void:
	if session == null:
		return
	if session.is_dedicated_headless() and terminate_process and session.has_spawned_process() and OS.is_process_running(int(session.process_id)):
		OS.kill(int(session.process_id))
	_cleanup_launch_config(session)
	session.clear_process_tracking()

func _cleanup_launch_config(session) -> void:
	if session == null:
		return
	var config_path := str(session.launch_config_path).strip_edges()
	if config_path.is_empty() or not FileAccess.file_exists(config_path):
		return
	DirAccess.remove_absolute(config_path)

func _resolve_headless_executable_path(executable_path: String) -> String:
	var normalized_path := executable_path.strip_edges()
	if normalized_path.is_empty():
		return normalized_path
	if normalized_path.ends_with(".exe"):
		var console_candidate := normalized_path.substr(0, normalized_path.length() - 4) + "_console.exe"
		if FileAccess.file_exists(console_candidate):
			return console_candidate
	return normalized_path

func _resolve_runtime_executable_path(configured_path: String) -> String:
	if not configured_path.is_empty():
		return configured_path
	if OS.has_feature("dedicated_server"):
		return OS.get_executable_path()
	var exported_server_path := ProjectSettings.globalize_path(DEDICATED_SERVER_EXPORT_RELATIVE_PATH)
	if FileAccess.file_exists(exported_server_path):
		return exported_server_path
	return _resolve_headless_executable_path(OS.get_executable_path())

func _is_exported_server_runtime(executable_path: String) -> bool:
	var normalized_path := executable_path.strip_edges().to_lower()
	return normalized_path.ends_with("claudeothergodsserver.exe") or normalized_path.ends_with("claudeothergodsserver_console.exe")
