extends SceneTree

func _initialize() -> void:
	var game_manager := GameManager.new()
	var player_one := Player.new()
	player_one.player_name = "Player 1"
	game_manager.players.append(player_one)

	var player_two := Player.new()
	player_two.player_name = "Player 2"
	game_manager.players.append(player_two)

	game_manager.current_player = player_one
	game_manager.other_player = player_two
	game_manager.turn_player = player_one
	game_manager.turn_number = 1

	var match_manager := MatchManager.new(game_manager)

	var attacker := BaseCard.new()
	attacker.card_name = "Probe Attacker"
	attacker.card_type = Card.CardType.CREATURE
	attacker.creature_mode = Card.CreatureMode.AGGRESSIVE
	attacker.card_owner = player_one
	player_one.frontline_zones[0].add_card(attacker)

	var unauthorized := match_manager.process_command(
		{
			"type": "select_attacker",
			"card_uid": attacker.uid,
		},
		{
			"peer_id": 2,
			"player_index": 1,
		}
	)
	if unauthorized:
		push_error("match_command_auth_probe: unauthorized player was allowed to select attacker")
		quit(1)
		return
	if match_manager.last_move_failed_reason.find("belongs to Player 1") == -1:
		push_error("match_command_auth_probe: unauthorized failure reason was unexpected: %s" % match_manager.last_move_failed_reason)
		quit(1)
		return

	match_manager.last_move_failed_reason = ""
	var authorized := match_manager.process_command(
		{
			"type": "select_attacker",
			"card_uid": attacker.uid,
		},
		{
			"peer_id": 1,
			"player_index": 0,
		}
	)
	if not authorized:
		push_error("match_command_auth_probe: authorized player could not select attacker: %s" % match_manager.last_move_failed_reason)
		quit(1)
		return
	if match_manager.selected_attacker != attacker:
		push_error("match_command_auth_probe: authorized attacker selection did not stick")
		quit(1)
		return

	print("match_command_auth_probe: PASS")
	quit()
