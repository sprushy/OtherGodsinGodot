extends SceneTree

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

	player1.gain_mana(5)
	player2.gain_mana(3)

	game_manager.start_turn()
	_assert_state(player1.mana == 5, "start_turn() should not grant upkeep mana before upkeep resolves.")

	game_manager.player_chooses_draw()
	_assert_state(player1.mana == 6, "Choosing the upkeep draw option should grant 1 mana during upkeep.")

	game_manager.end_turn()
	_assert_state(player2.mana == 3, "The next player's start_turn() should also leave mana unchanged until upkeep.")

	game_manager.player_chooses_mana()
	_assert_state(player2.mana == 8, "Choosing the upkeep mana option should grant 5 mana during upkeep.")

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

	print("upkeep_mana_timing_probe: PASS")
	quit()
