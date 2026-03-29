extends SceneTree

const MAIN_SCENE := preload("res://scenes/mainfork.tscn")
const BeardedAxeScript = preload("res://scripts/cards/Equipment/BeardedAxe.gd")
const BlessedKnightsScript = preload("res://scripts/cards/Creatures/BlessedKnights.gd")
const BrownBearScript = preload("res://scripts/cards/Creatures/BrownBear.gd")

func _assert_state(condition: bool, message: String) -> void:
	if condition:
		return
	push_error(message)
	quit(1)

func _initialize() -> void:
	call_deferred("_run_probe")

func _run_probe() -> void:
	var scene: Node = MAIN_SCENE.instantiate()
	root.add_child(scene)

	var card_test: CardTestGame = scene.get_node("Control/GameContainer/CardTest")
	await card_test.start_game()
	await process_frame
	await process_frame

	card_test._reset_player_test_state(card_test.player1)
	card_test._reset_player_test_state(card_test.player2)

	var game_manager: GameManager = card_test.game_manager
	var match_manager: MatchManager = card_test.match_manager
	var player1: Player = card_test.player1
	var player2: Player = card_test.player2
	player1.mana = 10
	player2.mana = 10
	game_manager.current_player = player1
	game_manager.other_player = player2
	game_manager.turn_player = player1
	game_manager.priority_player = player1
	game_manager.feedback_viewer = player1

	var stealth_creature := BlessedKnightsScript.new()
	var visible_creature := BrownBearScript.new()
	card_test._place_test_hidden_creature(player1, player1.frontline_zones[0], stealth_creature)
	card_test._place_test_board_card(player1, player1.frontline_zones[1], visible_creature, Card.CreatureMode.AGGRESSIVE)

	var direct_equip := BeardedAxeScript.new()
	direct_equip.card_owner = player1
	player1.frontline_zones[0].add_card(direct_equip)
	_assert_state(not direct_equip.equip_to(stealth_creature), "Equipment should not attach directly to a stealth creature.")
	_assert_state(direct_equip.equipped_on == null, "Rejected direct equip should leave equipment unattached.")

	var hidden_hand_equip := BeardedAxeScript.new()
	card_test._add_test_hand_card(player1, hidden_hand_equip)
	_assert_state(
		not game_manager.can_play_card(player1, hidden_hand_equip, player1.frontline_zones[0]),
		"Equipment should not be playable onto a stealth creature's zone."
	)

	var visible_hand_equip := BeardedAxeScript.new()
	card_test._add_test_hand_card(player1, visible_hand_equip)
	_assert_state(
		game_manager.can_play_card(player1, visible_hand_equip, player1.frontline_zones[1]),
		"Equipment should still be playable onto a face-up creature's zone."
	)

	var command_hidden_equip := BeardedAxeScript.new()
	card_test._add_test_hand_card(player1, command_hidden_equip)
	_assert_state(
		not match_manager.process_command({
			"type": "play_card",
			"card_uid": command_hidden_equip.uid,
			"player_index": game_manager.players.find(player1),
			"zone_type": player1.frontline_zones[0].zone_type,
			"zone_index": player1.frontline_zones[0].zone_index,
		}),
		"Server-side command processing should reject equipping a stealth creature."
	)
	_assert_state(command_hidden_equip.current_zone == player1.hand_zone, "Rejected network-style equip should leave the equipment in hand.")

	var command_visible_equip := BeardedAxeScript.new()
	card_test._add_test_hand_card(player1, command_visible_equip)
	_assert_state(
		match_manager.process_command({
			"type": "play_card",
			"card_uid": command_visible_equip.uid,
			"player_index": game_manager.players.find(player1),
			"zone_type": player1.frontline_zones[1].zone_type,
			"zone_index": player1.frontline_zones[1].zone_index,
		}),
		"Server-side command processing should still allow equipping a face-up creature."
	)
	_assert_state(command_visible_equip.equipped_on == visible_creature, "Successful network-style equip should attach to the face-up creature.")

	scene.queue_free()
	print("equipment_faceup_only_probe: PASS")
	quit()
