extends SceneTree

func _initialize() -> void:
	var script_paths := [
		"res://scripts/network/LobbyProtocol.gd",
		"res://scripts/server/LobbyRoom.gd",
		"res://scripts/server/MatchSession.gd",
		"res://scripts/server/MatchSupervisor.gd",
		"res://scripts/server/HeadlessMatchHost.gd",
		"res://scripts/server/HeadlessMatchServer.gd",
		"res://scripts/server/LobbyServer.gd",
		"res://scripts/client/LobbyClient.gd",
		"res://scripts/Other/NetworkManager.gd",
		"res://scripts/Other/MainMenu.gd",
	]

	for path in script_paths:
		print("phase2_lobby_probe: loading %s" % path)
		var script := load(path)
		if script == null:
			push_error("phase2_lobby_probe: failed to load %s" % path)
			quit(1)
			return

	var lobby_client = load("res://scripts/client/LobbyClient.gd").new()
	lobby_client._pending_session_id = "resume_session"
	lobby_client._pending_reconnect_token = "resume_token"
	lobby_client._pending_password = "saved_password"
	if not lobby_client._should_attempt_pending_lobby_reconnect():
		push_error("phase2_lobby_probe: saved password prevented deterministic token reconnect")
		quit(1)
		return
	var rejoin_request := LobbyProtocol.make_message(LobbyProtocol.REJOIN_ROOM, {"room_id": "ABC123"})
	if not LobbyProtocol.validate_request(rejoin_request).is_empty():
		push_error("phase2_lobby_probe: rejoin room request was rejected by the lobby protocol")
		quit(1)
		return
	lobby_client.free()

	var room_script = load("res://scripts/server/LobbyRoom.gd")
	var room = room_script.new("ABC123", "HOST")
	if not room.add_member("HOST"):
		push_error("phase2_lobby_probe: could not add host to room")
		quit(1)
		return
	if not room.add_member("CLIENT"):
		push_error("phase2_lobby_probe: could not add client to room")
		quit(1)
		return
	room.submit_deck("HOST", "Host Deck", "host-deck", {}, {"is_valid": true})
	room.submit_deck("CLIENT", "Client Deck", "client-deck", {}, {"is_valid": true})
	room.set_ready("HOST", true)
	room.set_ready("CLIENT", true)
	if not room.can_start():
		push_error("phase2_lobby_probe: ready room did not become startable")
		quit(1)
		return

	var server_script = load("res://scripts/server/LobbyServer.gd")
	var server = server_script.new()
	var session: Dictionary = server.create_local_guest_session("Host")
	if str(session.get("session_id", "")).is_empty():
		push_error("phase2_lobby_probe: local host session was not created")
		quit(1)
		return
	var snapshot: Dictionary = server.create_room_for_local_session()
	if str(snapshot.get("room_id", "")).is_empty():
		push_error("phase2_lobby_probe: local room was not created")
		quit(1)
		return
	server.set_local_ready(true)
	var local_snapshot: Dictionary = server.get_local_room_snapshot()
	if local_snapshot.is_empty():
		push_error("phase2_lobby_probe: local room snapshot was not available")
		quit(1)
		return

	var finished_room = room_script.new("LEAVE1", "HOST")
	finished_room.add_member("HOST")
	finished_room.add_member("LEAVER")
	finished_room.status = finished_room.STATUS_IN_MATCH
	finished_room.assigned_match_id = "match_finished_leave"
	server.rooms_by_id[finished_room.room_id] = finished_room
	server.room_id_by_session["HOST"] = finished_room.room_id
	server.room_id_by_session["LEAVER"] = finished_room.room_id
	var finished_player_ids: Array[String] = ["HOST", "LEAVER"]
	var finished_match = load("res://scripts/server/MatchSession.gd").new(
		finished_room.assigned_match_id,
		finished_room.room_id,
		"127.0.0.1",
		12345,
		finished_player_ids
	)
	finished_match.server_mode = finished_match.SERVER_MODE_DEDICATED_HEADLESS
	finished_match.status_file_path = "user://phase2_finished_leave.status.json"
	var finished_status_file := FileAccess.open(finished_match.status_file_path, FileAccess.WRITE)
	if finished_status_file == null:
		push_error("phase2_lobby_probe: could not create finished match status")
		quit(1)
		return
	finished_status_file.store_string(JSON.stringify({"status": finished_match.STATUS_FINISHED}))
	finished_status_file.close()
	server._ensure_match_supervisor()
	server.match_supervisor.active_matches[finished_match.match_id] = finished_match
	server._leave_room_for_session("LEAVER")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(finished_match.status_file_path))
	if not server.rooms_by_id.has(finished_room.room_id):
		push_error("phase2_lobby_probe: leaving a finished match erased the remaining player's seek")
		quit(1)
		return
	if finished_room.members != ["HOST"] or finished_room.status != finished_room.STATUS_WAITING:
		push_error("phase2_lobby_probe: finished match leave did not preserve only the remaining player")
		quit(1)
		return

	var connected_room = room_script.new("READY1", "READY_HOST")
	connected_room.add_member("READY_HOST")
	connected_room.add_member("READY_CLIENT")
	connected_room.submit_deck("READY_HOST", "Host Deck", "host-deck", {}, {"is_valid": true})
	connected_room.submit_deck("READY_CLIENT", "Client Deck", "client-deck", {}, {"is_valid": true})
	connected_room.set_ready("READY_HOST", true)
	connected_room.set_ready("READY_CLIENT", true)
	server.sessions_by_id["READY_HOST"] = {
		"session_id": "READY_HOST",
		"connected": true,
		"peer_id": 0,
		"is_local": false,
	}
	server.sessions_by_id["READY_CLIENT"] = {
		"session_id": "READY_CLIENT",
		"connected": false,
		"peer_id": 0,
		"is_local": false,
	}
	server.rooms_by_id[connected_room.room_id] = connected_room
	server.room_id_by_session["READY_HOST"] = connected_room.room_id
	server.room_id_by_session["READY_CLIENT"] = connected_room.room_id
	server.match_supervisor.use_dedicated_headless = false
	server._try_assign_match(connected_room)
	if connected_room.status == connected_room.STATUS_IN_MATCH:
		push_error("phase2_lobby_probe: ready room launched while a member was disconnected")
		quit(1)
		return
	var reconnected_session: Dictionary = server.sessions_by_id["READY_CLIENT"]
	reconnected_session["connected"] = true
	server.sessions_by_id["READY_CLIENT"] = reconnected_session
	server._try_assign_match(connected_room)
	if connected_room.status != connected_room.STATUS_IN_MATCH:
		push_error("phase2_lobby_probe: ready room did not launch after the missing member reconnected")
		quit(1)
		return
	var existing_active_room = server._create_room_for_session("READY_HOST")
	if existing_active_room != connected_room or not server.match_supervisor.active_matches.has(connected_room.assigned_match_id):
		push_error("phase2_lobby_probe: creating a seek implicitly abandoned an active match")
		quit(1)
		return
	server.sessions_by_id["READY_HOST"]["account_id"] = "account-host"
	var reclaimed_active_session: Dictionary = server._find_resumable_session("", "account-host")
	if str(reclaimed_active_session.get("session_id", "")) != "READY_HOST":
		push_error("phase2_lobby_probe: authenticated login did not reclaim a still-connected active match session")
		quit(1)
		return
	server.sessions_by_id["DUPLICATE_HOST"] = {
		"session_id": "DUPLICATE_HOST",
		"account_id": "account-host",
		"connected": true,
		"peer_id": 99,
		"is_local": false,
	}
	server.sessions_by_id["OUTSIDER"] = {
		"session_id": "OUTSIDER",
		"account_id": "account-outsider",
		"connected": true,
		"peer_id": 100,
		"is_local": false,
	}
	var matched_participant_session_id: String = server._get_matching_participant_session_id(
		"DUPLICATE_HOST",
		connected_room.members
	)
	if matched_participant_session_id != "READY_HOST":
		push_error("phase2_lobby_probe: self-observe fallback did not resolve the active player session")
		quit(1)
		return
	var replacement_session_match_info: Dictionary = server._build_active_match_info_for_session("DUPLICATE_HOST")
	if str(replacement_session_match_info.get("session_id", "")) != "READY_HOST" \
		or str(replacement_session_match_info.get("match_token", "")).is_empty():
		push_error("phase2_lobby_probe: replacement account session could not resolve player rejoin credentials")
		quit(1)
		return
	var participant_room_list: Array = server._build_room_list("DUPLICATE_HOST")
	var observer_room_list: Array = server._build_room_list("OUTSIDER")
	var participant_room_entry: Dictionary = {}
	var observer_room_entry: Dictionary = {}
	for room_entry in participant_room_list:
		if str(room_entry.get("room_id", "")) == connected_room.room_id:
			participant_room_entry = room_entry
			break
	for room_entry in observer_room_list:
		if str(room_entry.get("room_id", "")) == connected_room.room_id:
			observer_room_entry = room_entry
			break
	if participant_room_entry.is_empty() or not bool(participant_room_entry.get("viewer_can_rejoin", false)):
		push_error("phase2_lobby_probe: active player room list did not advertise rejoin")
		quit(1)
		return
	if observer_room_entry.is_empty() or bool(observer_room_entry.get("viewer_can_rejoin", false)):
		push_error("phase2_lobby_probe: non-participant room list incorrectly advertised rejoin")
		quit(1)
		return

	var offline_room = room_script.new("OFFLINE", "OFFLINE_HOST")
	offline_room.add_member("OFFLINE_HOST")
	server.sessions_by_id["OFFLINE_HOST"] = {
		"session_id": "OFFLINE_HOST",
		"connected": false,
		"peer_id": 0,
		"is_local": false,
	}
	server.sessions_by_id["JOINER"] = {
		"session_id": "JOINER",
		"connected": true,
		"peer_id": 0,
		"is_local": false,
	}
	server.rooms_by_id[offline_room.room_id] = offline_room
	server.room_id_by_session["OFFLINE_HOST"] = offline_room.room_id
	for room_entry in server._build_room_list():
		if str(room_entry.get("room_id", "")) == offline_room.room_id:
			push_error("phase2_lobby_probe: disconnected host seek remained publicly listed")
			quit(1)
			return
	server._join_room_for_session("JOINER", offline_room.room_id)
	if server.room_id_by_session.has("JOINER"):
		push_error("phase2_lobby_probe: player joined a seek whose host was disconnected")
		quit(1)
		return
	var expired_host_session: Dictionary = server.sessions_by_id["OFFLINE_HOST"]
	expired_host_session["room_disconnected_since_unix"] = (
		int(Time.get_unix_time_from_system()) - server.ROOM_MEMBER_RECONNECT_GRACE_SECONDS - 1
	)
	server.sessions_by_id["OFFLINE_HOST"] = expired_host_session
	server._expire_disconnected_room_members()
	if server.rooms_by_id.has(offline_room.room_id) or server.room_id_by_session.has("OFFLINE_HOST"):
		push_error("phase2_lobby_probe: expired disconnected member kept occupying a room")
		quit(1)
		return

	var supervisor_script = load("res://scripts/server/MatchSupervisor.gd")
	var supervisor = supervisor_script.new()
	supervisor.configure("127.0.0.1", 12345, false)
	var player_ids: Array[String] = ["HOST", "CLIENT"]
	var match_session = supervisor.create_match("ABC123", player_ids)
	if match_session == null or match_session.match_id.is_empty():
		push_error("phase2_lobby_probe: match supervisor did not create a match session")
		quit(1)
		return
	if match_session.get_player_index("CLIENT") != 1:
		push_error("phase2_lobby_probe: match session player indexing was incorrect")
		quit(1)
		return
	match_session.disconnected_sessions = {
		"HOST": 200,
		"CLIENT": 150,
	}
	match_session._refresh_reconnect_deadline()
	if match_session.reconnect_deadline_unix != 150:
		push_error("phase2_lobby_probe: reconnect timeout did not use the earliest disconnected player deadline")
		quit(1)
		return
	var match_info: Dictionary = match_session.to_match_info("CLIENT")
	if str(match_info.get("match_token", "")).is_empty():
		push_error("phase2_lobby_probe: match session did not issue a client auth token")
		quit(1)
		return
	match_session.set_spectator_visible_player_indices("OBSERVER", [0])
	var spectator_match_info: Dictionary = match_session.to_spectator_match_info("OBSERVER")
	var observer_match_token := str(spectator_match_info.get("observer_match_token", ""))
	if observer_match_token.is_empty():
		push_error("phase2_lobby_probe: match session did not issue an observer auth token")
		quit(1)
		return
	if match_session.authenticate_spectator("OBSERVER", "wrong-token", 98):
		push_error("phase2_lobby_probe: match session accepted an invalid observer auth token")
		quit(1)
		return
	if not match_session.authenticate_spectator("OBSERVER", observer_match_token, 99):
		push_error("phase2_lobby_probe: match session rejected a valid observer auth token")
		quit(1)
		return
	var host_token: String = match_session.get_match_token("HOST")
	if match_session.authenticate_join("HOST", host_token, 99) != 0 \
		or match_session.authenticate_spectator("OBSERVER", observer_match_token, 99):
		push_error("phase2_lobby_probe: authenticated player peer could also authenticate as an observer")
		quit(1)
		return
	var restored_match_session = load("res://scripts/server/MatchSession.gd").from_launch_config(match_session.to_launch_config())
	if restored_match_session == null \
		or restored_match_session.get_spectator_match_token("OBSERVER") != observer_match_token \
		or not restored_match_session.authenticate_spectator("OBSERVER", observer_match_token, 100):
		push_error("phase2_lobby_probe: observer auth token did not survive launch config persistence")
		quit(1)
		return
	var authority_network_manager = load("res://scripts/Other/NetworkManager.gd").new()
	authority_network_manager.player_peer_ids = {0: 101, 1: 101}
	authority_network_manager.spectator_peer_ids = [101]
	authority_network_manager.spectator_visible_player_indices_by_peer = {101: [0]}
	authority_network_manager.unassign_peer(101)
	if not authority_network_manager.player_peer_ids.is_empty() \
		or not authority_network_manager.spectator_peer_ids.is_empty() \
		or not authority_network_manager.spectator_visible_player_indices_by_peer.is_empty():
		push_error("phase2_lobby_probe: stale peer authority survived unassignment")
		quit(1)
		return
	authority_network_manager.free()

	var menu_script = load("res://scripts/Other/MainMenu.gd")
	var menu = menu_script.new()
	var menu_container := Control.new()
	menu_container.name = "MenuContainer"
	var game_container := Control.new()
	game_container.name = "GameContainer"
	var mock_game = load("res://scripts/Other/CombatMockGame.gd").new()
	mock_game.name = "MockGame"
	mock_game._is_networked_client = true
	mock_game._game_finished = false
	menu.add_child(menu_container)
	menu.add_child(game_container)
	game_container.add_child(mock_game)
	menu.menu_container = menu_container
	menu.game_container = game_container
	menu.show_game()
	menu._on_game_return_to_menu_requested()
	if menu_container.visible or not game_container.visible:
		push_error("phase2_lobby_probe: stale return-to-menu signal hid a live rejoined match")
		quit(1)
		return
	menu.free()

	print("phase2_lobby_probe: PASS")
	quit()
