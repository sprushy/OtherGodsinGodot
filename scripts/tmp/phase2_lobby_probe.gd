extends SceneTree

func _initialize() -> void:
	var script_paths := [
		"res://scripts/network/LobbyProtocol.gd",
		"res://scripts/server/LobbyRoom.gd",
		"res://scripts/server/MatchSession.gd",
		"res://scripts/server/MatchSupervisor.gd",
		"res://scripts/server/LobbyServer.gd",
		"res://scripts/client/LobbyClient.gd",
		"res://scripts/Other/MainMenu.gd",
	]

	for path in script_paths:
		print("phase2_lobby_probe: loading %s" % path)
		var script := load(path)
		if script == null:
			push_error("phase2_lobby_probe: failed to load %s" % path)
			quit(1)
			return

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

	var supervisor_script = load("res://scripts/server/MatchSupervisor.gd")
	var supervisor = supervisor_script.new()
	supervisor.configure("127.0.0.1", 12345)
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
	var match_info: Dictionary = match_session.to_match_info("CLIENT")
	if str(match_info.get("match_token", "")).is_empty():
		push_error("phase2_lobby_probe: match session did not issue a client auth token")
		quit(1)
		return

	print("phase2_lobby_probe: PASS")
	quit()
