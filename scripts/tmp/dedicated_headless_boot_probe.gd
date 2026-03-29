extends SceneTree

func _initialize() -> void:
	call_deferred("_run_probe")

func _run_probe() -> void:
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	var port := 18000 + rng.randi_range(0, 5000)

	var session := MatchSession.new(
		"match_dedicated_probe",
		"ROOM01",
		"127.0.0.1",
		port,
		["HOST", "CLIENT"]
	)
	session.server_mode = MatchSession.SERVER_MODE_DEDICATED_HEADLESS

	var rebuilt := MatchSession.from_launch_config(session.to_launch_config())
	if rebuilt == null:
		push_error("dedicated_headless_boot_probe: failed to rebuild launch config")
		quit(1)
		return
	if rebuilt.get_match_token("HOST") != session.get_match_token("HOST"):
		push_error("dedicated_headless_boot_probe: launch config changed the host match token")
		quit(1)
		return

	var server := HeadlessMatchServer.new()
	get_root().add_child(server)
	var start_err: Error = server.start_from_config(session.to_launch_config())
	if start_err != OK:
		push_error("dedicated_headless_boot_probe: server failed to start (%s)" % error_string(start_err))
		quit(1)
		return

	if server.network_manager == null or not server.network_manager.is_server:
		push_error("dedicated_headless_boot_probe: transport did not boot as a server")
		quit(1)
		return
	if int(server.network_manager.local_player_index) != -1:
		push_error("dedicated_headless_boot_probe: dedicated server claimed a local player seat")
		quit(1)
		return
	if not server.network_manager.player_peer_ids.is_empty():
		push_error("dedicated_headless_boot_probe: dedicated server should not map a local peer to a player")
		quit(1)
		return
	if server.has_started_match():
		push_error("dedicated_headless_boot_probe: dedicated server started before players authenticated")
		quit(1)
		return

	var host_token: String = server.match_session.get_match_token("HOST")
	var client_token: String = server.match_session.get_match_token("CLIENT")
	server.match_session.authenticate_join("HOST", host_token, 2)
	server.network_manager.player_peer_ids[0] = 2
	server.match_session.authenticate_join("CLIENT", client_token, 3)
	server.network_manager.player_peer_ids[1] = 3

	if not server.maybe_start_match_if_ready():
		push_error("dedicated_headless_boot_probe: dedicated server did not start after both players authenticated")
		quit(1)
		return
	if not server.has_started_match():
		push_error("dedicated_headless_boot_probe: dedicated server start flag was not set")
		quit(1)
		return
	if server.game_manager == null or int(server.game_manager.turn_number) <= 0:
		push_error("dedicated_headless_boot_probe: match did not advance into turn flow")
		quit(1)
		return

	print("dedicated_headless_boot_probe: PASS")
	quit()
