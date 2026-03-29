extends SceneTree

const GambanteinnScript := preload("res://scripts/cards/Equipment/Gambanteinn.gd")
const BrownBearScript := preload("res://scripts/cards/Creatures/BrownBear.gd")
const EnHeduAnnaScript := preload("res://scripts/cards/Creatures/EnHeduAnna.gd")

func _assert_state(condition: bool, message: String) -> void:
	if condition:
		return
	push_error(message)
	quit(1)

func _initialize() -> void:
	call_deferred("_run_probe")

func _run_probe() -> void:
	var game_manager := GameManager.new()
	var player1 := Player.new()
	player1.player_name = "Player 1"
	var player2 := Player.new()
	player2.player_name = "Player 2"

	game_manager.players = [player1, player2]
	game_manager.setup_game()
	game_manager.current_player = player1
	game_manager.other_player = player2
	game_manager.turn_player = player1
	game_manager.priority_player = player1
	game_manager.turn_number = 1
	game_manager.feedback_viewer = player1

	player1.mana = 10
	player2.mana = 10

	var non_mage := BrownBearScript.new()
	non_mage.card_owner = player1
	player1.frontline_zones[0].add_card(non_mage)

	var mage := EnHeduAnnaScript.new()
	mage.card_owner = player1
	player1.frontline_zones[1].add_card(mage)

	var sleep_target := BrownBearScript.new()
	sleep_target.card_owner = player2
	player2.frontline_zones[0].add_card(sleep_target)

	var invalid_equip := GambanteinnScript.new()
	invalid_equip.card_owner = player1
	player1.hand_zone.add_card(invalid_equip)
	_assert_state(
		not game_manager.can_play_card(player1, invalid_equip, player1.frontline_zones[0]),
		"Gambanteinn should not be playable onto a non-Mage, non-Shaman creature."
	)
	_assert_state(not invalid_equip.equip_to(non_mage), "Gambanteinn should reject direct equip onto other creature types.")

	var mage_equip := GambanteinnScript.new()
	mage_equip.card_owner = player1
	player1.hand_zone.add_card(mage_equip)
	_assert_state(
		game_manager.can_play_card(player1, mage_equip, player1.frontline_zones[1]),
		"Gambanteinn should be playable onto a Mage."
	)
	game_manager.play_card(player1, mage_equip, player1.frontline_zones[1])
	_assert_state(mage_equip.equipped_on == mage, "Playing Gambanteinn onto a Mage should auto-equip it.")

	mage_equip.activate(game_manager, sleep_target)
	_assert_state(sleep_target.is_sleeping, "Mage-equipped Gambanteinn should put the target to sleep.")
	_assert_state(player1.mana == 8, "Gambanteinn should spend 2 mana when activated.")

	game_manager.end_turn()
	_assert_state(not sleep_target.is_sleeping, "Gambanteinn sleep should wear off at end of turn.")

	game_manager.current_player = player1
	game_manager.other_player = player2
	game_manager.turn_player = player1
	game_manager.priority_player = player1
	game_manager.turn_number = 2
	player1.mana = 10

	var shaman := BrownBearScript.new()
	shaman.card_owner = player1
	shaman.card_types.append("Shaman")
	player1.reserve_zones[0].add_card(shaman)

	var stance_target := BrownBearScript.new()
	stance_target.card_owner = player2
	stance_target.creature_mode = Card.CreatureMode.DEFENSIVE
	player2.frontline_zones[1].add_card(stance_target)

	var shaman_equip := GambanteinnScript.new()
	shaman_equip.card_owner = player1
	player1.hand_zone.add_card(shaman_equip)
	_assert_state(
		game_manager.can_play_card(player1, shaman_equip, player1.reserve_zones[0]),
		"Gambanteinn should be playable onto a Shaman."
	)
	game_manager.play_card(player1, shaman_equip, player1.reserve_zones[0])
	_assert_state(shaman_equip.equipped_on == shaman, "Playing Gambanteinn onto a Shaman should auto-equip it.")

	shaman_equip.activate(game_manager, stance_target)
	_assert_state(
		stance_target.creature_mode == Card.CreatureMode.AGGRESSIVE,
		"Shaman-equipped Gambanteinn should force a defensive creature into aggressive stance."
	)
	_assert_state(player1.mana == 8, "Shaman activation should also spend 2 mana.")

	game_manager.end_turn()
	_assert_state(
		stance_target.creature_mode == Card.CreatureMode.DEFENSIVE,
		"Gambanteinn's forced aggressive stance should end at turn end."
	)

	var moved_callback := Callable(game_manager, "_on_player_card_moved")
	var defeated_callback := Callable(game_manager, "_on_player_defeated")
	for player in game_manager.players:
		if player.card_moved.is_connected(moved_callback):
			player.card_moved.disconnect(moved_callback)
		if player.defeated.is_connected(defeated_callback):
			player.defeated.disconnect(defeated_callback)

	print("gambanteinn_probe: PASS")
	quit()
