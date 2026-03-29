extends SceneTree

func _initialize() -> void:
	call_deferred("_run_probe")

func _run_probe() -> void:
	var supervisor := MatchSupervisor.new()
	get_root().add_child(supervisor)

	var closed_events: Array[Dictionary] = []
	supervisor.match_closed.connect(func(match_id: String, room_id: String, final_status: String) -> void:
		closed_events.append({
			"match_id": match_id,
			"room_id": room_id,
			"final_status": final_status,
		})
	)

	var session := MatchSession.new(
		"match_cleanup_probe",
		"ROOMC1",
		"127.0.0.1",
		14567,
		["HOST", "CLIENT"]
	)
	session.server_mode = MatchSession.SERVER_MODE_DEDICATED_HEADLESS
	session.reconnect_deadline_unix = int(Time.get_unix_time_from_system()) - 1

	var cleanup_dir := ProjectSettings.globalize_path("res://scripts/tmp")
	var launch_config_path := cleanup_dir.path_join("match_cleanup_probe.json")
	var file := FileAccess.open(launch_config_path, FileAccess.WRITE)
	if file == null:
		push_error("match_supervisor_cleanup_probe: failed to create launch config file")
		quit(1)
		return
	file.store_string("{}")
	file.close()
	session.mark_process_launched(0, launch_config_path)

	supervisor.active_matches[session.match_id] = session
	supervisor._refresh_active_matches()

	if supervisor.active_matches.has(session.match_id):
		push_error("match_supervisor_cleanup_probe: expired match was not removed")
		quit(1)
		return
	if FileAccess.file_exists(launch_config_path):
		push_error("match_supervisor_cleanup_probe: launch config file was not removed")
		quit(1)
		return
	if closed_events.size() != 1:
		push_error("match_supervisor_cleanup_probe: match_closed did not fire exactly once")
		quit(1)
		return
	if str(closed_events[0].get("final_status", "")) != MatchSession.STATUS_ABANDONED:
		push_error("match_supervisor_cleanup_probe: expired match did not close as abandoned")
		quit(1)
		return

	print("match_supervisor_cleanup_probe: PASS")
	quit()
