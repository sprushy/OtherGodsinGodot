extends SceneTree

const FreyjaScript := preload("res://scripts/cards/Gods/Freyja.gd")
const CallOfTheValkyrieScript := preload("res://scripts/cards/Powers/CallOfTheValkyrie.gd")
const AgainWalkerScript := preload("res://scripts/cards/Creatures/AgainWalker.gd")

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
	game_manager.start_turn()

	var freyja := FreyjaScript.new()
	freyja.card_owner = player1
	player1.god_zone.add_card(freyja)

	var call_of_the_valkyrie := CallOfTheValkyrieScript.new()
	call_of_the_valkyrie.card_owner = player1
	call_of_the_valkyrie.is_face_down = false
	player1.power_zones[0].add_card(call_of_the_valkyrie)

	var warrior := AgainWalkerScript.new()
	warrior.card_owner = player1
	player1.graveyard_zone.add_card(warrior)

	player1.gain_mana(10)

	_assert_state(freyja.get_activation_mana_cost(game_manager) == 4, "Freyja should cost 1 less with Call of the Valkyrie in play.")
	_assert_state(freyja.can_activate(game_manager), "Freyja should be activatable with a valid Norse Warrior target.")

	freyja.activate(game_manager, warrior)

	_assert_state(warrior.current_zone != player1.graveyard_zone, "Freyja should summon the target out of the graveyard.")
	_assert_state(warrior.current_zone != null and warrior.current_zone.is_board_zone(), "Freyja should summon the target onto the field.")
	_assert_state(warrior.has_type("Spirit"), "The summoned Warrior should gain Spirit.")
	_assert_state(player1.mana == 6, "Freyja should spend the discounted activation cost.")

	game_manager.end_turn()
	_assert_state(warrior.current_zone != player1.graveyard_zone, "The resurrected Warrior should survive the opponent's turn.")
	game_manager.end_turn()

	_assert_state(warrior.current_zone == player1.graveyard_zone, "The resurrected Warrior should be destroyed at the start of its owner's next turn.")
	_assert_state(not warrior.has_type("Spirit"), "The temporary Spirit class should be removed once the Warrior leaves the field.")

	var moved_callback := Callable(game_manager, "_on_player_card_moved")
	var defeated_callback := Callable(game_manager, "_on_player_defeated")
	for player in game_manager.players:
		if player.card_moved.is_connected(moved_callback):
			player.card_moved.disconnect(moved_callback)
		if player.defeated.is_connected(defeated_callback):
			player.defeated.disconnect(defeated_callback)

	print("freyja_probe: PASS")
	quit()
