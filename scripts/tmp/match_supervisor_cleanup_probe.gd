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

	closed_events.clear()
	var finished_session := MatchSession.new(
		"match_cleanup_finished_probe",
		"ROOMF1",
		"127.0.0.1",
		14568,
		["HOST", "CLIENT"]
	)
	finished_session.server_mode = MatchSession.SERVER_MODE_DEDICATED_HEADLESS
	var finished_config_path := cleanup_dir.path_join("match_cleanup_finished_probe.json")
	var finished_status_path := cleanup_dir.path_join("match_cleanup_finished_probe.status.json")
	_write_json_file(finished_config_path, {})
	_write_json_file(finished_status_path, {
		"match_id": finished_session.match_id,
		"room_id": finished_session.room_id,
		"status": MatchSession.STATUS_FINISHED,
		"heartbeat_unix": int(Time.get_unix_time_from_system()),
	})
	finished_session.status_file_path = finished_status_path
	finished_session.mark_process_launched(0, finished_config_path)
	supervisor.active_matches[finished_session.match_id] = finished_session
	supervisor._refresh_active_matches()

	if supervisor.active_matches.has(finished_session.match_id):
		push_error("match_supervisor_cleanup_probe: finished status match was not removed")
		quit(1)
		return
	if closed_events.size() != 1 or str(closed_events[0].get("final_status", "")) != MatchSession.STATUS_FINISHED:
		push_error("match_supervisor_cleanup_probe: finished status did not close as finished")
		quit(1)
		return
	if FileAccess.file_exists(finished_config_path) or FileAccess.file_exists(finished_status_path):
		push_error("match_supervisor_cleanup_probe: finished status cleanup left files behind")
		quit(1)
		return

	closed_events.clear()
	var stale_session := MatchSession.new(
		"match_cleanup_stale_probe",
		"ROOMS1",
		"127.0.0.1",
		14569,
		["HOST", "CLIENT"]
	)
	stale_session.server_mode = MatchSession.SERVER_MODE_DEDICATED_HEADLESS
	var stale_config_path := cleanup_dir.path_join("match_cleanup_stale_probe.json")
	var stale_status_path := cleanup_dir.path_join("match_cleanup_stale_probe.status.json")
	_write_json_file(stale_config_path, {})
	_write_json_file(stale_status_path, {
		"match_id": stale_session.match_id,
		"room_id": stale_session.room_id,
		"status": MatchSession.STATUS_ACTIVE,
		"heartbeat_unix": int(Time.get_unix_time_from_system()) - 60,
	})
	stale_session.status_file_path = stale_status_path
	stale_session.mark_process_launched(0, stale_config_path)
	supervisor.active_matches[stale_session.match_id] = stale_session
	supervisor._refresh_active_matches()

	if supervisor.active_matches.has(stale_session.match_id):
		push_error("match_supervisor_cleanup_probe: stale heartbeat match was not removed")
		quit(1)
		return
	if closed_events.size() != 1 or str(closed_events[0].get("final_status", "")) != MatchSession.STATUS_ABANDONED:
		push_error("match_supervisor_cleanup_probe: stale heartbeat did not close as abandoned")
		quit(1)
		return
	if FileAccess.file_exists(stale_config_path) or FileAccess.file_exists(stale_status_path):
		push_error("match_supervisor_cleanup_probe: stale heartbeat cleanup left files behind")
		quit(1)
		return

	print("match_supervisor_cleanup_probe: PASS")
	quit()

func _write_json_file(path: String, payload: Dictionary) -> void:
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return
	file.store_string(JSON.stringify(payload))
	file.close()
