extends SceneTree

const FirstSageAdapaScript := preload("res://scripts/cards/Creatures/FirstSageAdapa.gd")
const FenrirScript := preload("res://scripts/cards/Creatures/Fenrir.gd")
const AncientWisdomScript := preload("res://scripts/cards/Powers/AncientWisdom.gd")
const ThorScript := preload("res://scripts/cards/Gods/Thor.gd")

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
	game_manager.turn_number = 1
	game_manager.feedback_viewer = player1

	var adapa := FirstSageAdapaScript.new()
	adapa.card_owner = player1
	player1.frontline_zones[0].add_card(adapa)

	var fenrir := FenrirScript.new()
	fenrir.card_owner = player1
	player1.frontline_zones[1].add_card(fenrir)

	var target_power := AncientWisdomScript.new()
	target_power.card_owner = player2
	target_power.relock()
	player2.power_zones[0].add_card(target_power)

	var target_god := ThorScript.new()
	target_god.card_owner = player2
	player2.god_zone.add_card(target_god)

	var valid_targets := adapa.get_valid_targets(game_manager)
	_assert_state(target_power in valid_targets, "Adapa should be able to choose an opposing power.")
	_assert_state(target_god in valid_targets, "Adapa should be able to choose the opposing God ability.")

	var result := adapa.resolve_silence_divine_impact(game_manager, target_power)
	_assert_state(target_power.is_muted, "Adapa should mute the chosen opposing power.")
	_assert_state(target_power.mute_turns_remaining == 2, "Adapa should mute for exactly 2 of the target owner's turns.")

	var god_result := adapa.resolve_silence_divine_impact(game_manager, target_god)
	_assert_state(target_god.is_muted, "Adapa should mute the chosen opposing God ability.")
	_assert_state(target_god.mute_turns_remaining == 2, "Adapa should mute a God ability for exactly 2 of the target owner's turns.")

	game_manager.current_player = player1
	_assert_state(target_power.mute_turns_remaining == 2, "The mute should not tick down on the wrong player's turn.")
	_assert_state(target_god.mute_turns_remaining == 2, "A God mute should not tick down on the wrong player's turn.")

	game_manager.current_player = player2
	game_manager.turn_number = 2
	target_power.on_turn_end(game_manager)
	target_god.on_turn_end(game_manager)
	_assert_state(target_power.is_muted and target_power.mute_turns_remaining == 1, "The mute should tick down after the first owner turn.")
	_assert_state(target_god.is_muted and target_god.mute_turns_remaining == 1, "A God mute should tick down after the first owner turn.")

	game_manager.current_player = player1
	game_manager.turn_number = 3
	_assert_state(target_power.is_muted and target_power.mute_turns_remaining == 1, "The mute should still wait for the target owner's next turn.")
	_assert_state(target_god.is_muted and target_god.mute_turns_remaining == 1, "A God mute should still wait for the target owner's next turn.")

	game_manager.current_player = player2
	game_manager.turn_number = 4
	target_power.on_turn_end(game_manager)
	target_god.on_turn_end(game_manager)
	_assert_state(not target_power.is_muted and target_power.mute_turns_remaining == 0, "The mute should expire after the second owner turn.")
	_assert_state(not target_god.is_muted and target_god.mute_turns_remaining == 0, "A God mute should expire after the second owner turn.")

	var moved_callback := Callable(game_manager, "_on_player_card_moved")
	var defeated_callback := Callable(game_manager, "_on_player_defeated")
	for player in game_manager.players:
		if player.card_moved.is_connected(moved_callback):
			player.card_moved.disconnect(moved_callback)
		if player.defeated.is_connected(defeated_callback):
			player.defeated.disconnect(defeated_callback)
	game_manager.players.clear()
	game_manager.current_player = null
	game_manager.other_player = null
	game_manager.turn_player = null
	player1 = null
	player2 = null
	game_manager = null

	print("first_sage_adapa_probe: PASS")
	print("PROBE: result=", result)
	print("PROBE: god_result=", god_result)
	quit()
