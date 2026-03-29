extends SceneTree

func _initialize() -> void:
	var session := MatchSession.new(
		"match_probe",
		"ROOM01",
		"127.0.0.1",
		12345,
		["HOST", "CLIENT"]
	)

	var token := session.get_match_token("CLIENT")
	if token.is_empty():
		push_error("match_reconnect_probe: client match token was not created")
		quit(1)
		return

	var first_join_idx := session.authenticate_join("CLIENT", token, 2)
	if first_join_idx != 1:
		push_error("match_reconnect_probe: initial client join assigned wrong player index")
		quit(1)
		return

	var disconnect_info: Dictionary = session.note_peer_disconnected(2)
	if int(disconnect_info.get("player_index", -1)) != 1:
		push_error("match_reconnect_probe: disconnect did not record the expected player index")
		quit(1)
		return
	if not session.is_waiting_for_reconnect():
		push_error("match_reconnect_probe: match did not enter reconnect wait state")
		quit(1)
		return

	var second_join_idx := session.authenticate_join("CLIENT", token, 7)
	if second_join_idx != 1:
		push_error("match_reconnect_probe: reconnect did not restore the same player index")
		quit(1)
		return
	if session.is_waiting_for_reconnect():
		push_error("match_reconnect_probe: reconnect wait state did not clear after rejoin")
		quit(1)
		return

	print("match_reconnect_probe: PASS")
	quit()
