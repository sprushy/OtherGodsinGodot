extends SceneTree

const EarthquakeScript := preload("res://scripts/cards/Spells/Earthquake.gd")
const AncientPyreScript := preload("res://scripts/cards/Structures/AncientPyre.gd")
const BrownBearScript := preload("res://scripts/cards/Creatures/BrownBear.gd")
const TitanicMechScript := preload("res://scripts/cards/Creatures/TitanicMech.gd")

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

	var friendly_structure := AncientPyreScript.new()
	friendly_structure.card_owner = player1
	player1.frontline_zones[0].add_card(friendly_structure)

	var enemy_structure := AncientPyreScript.new()
	enemy_structure.card_owner = player2
	player2.frontline_zones[0].add_card(enemy_structure)

	var hidden_structure := AncientPyreScript.new()
	hidden_structure.card_owner = player2
	hidden_structure.is_face_down = true
	player2.frontline_zones[1].add_card(hidden_structure)

	var visible_machine := TitanicMechScript.new()
	visible_machine.card_owner = player1
	player1.reserve_zones[0].add_card(visible_machine)

	var hidden_machine := TitanicMechScript.new()
	hidden_machine.card_owner = player2
	hidden_machine.is_face_down = true
	player2.reserve_zones[0].add_card(hidden_machine)

	var survivor := BrownBearScript.new()
	survivor.card_owner = player2
	player2.reserve_zones[1].add_card(survivor)

	var earthquake := EarthquakeScript.new()
	earthquake.card_owner = player1
	earthquake.resolve(game_manager)

	_assert_state(
		friendly_structure.current_zone == player1.graveyard_zone,
		"Earthquake should destroy your structures."
	)
	_assert_state(
		enemy_structure.current_zone == player2.graveyard_zone,
		"Earthquake should destroy enemy structures."
	)
	_assert_state(
		hidden_structure.current_zone == player2.frontline_zones[1],
		"Earthquake should ignore face-down cards entirely."
	)
	_assert_state(
		visible_machine.current_zone == player1.graveyard_zone,
		"Earthquake should destroy face-up machines."
	)
	_assert_state(
		hidden_machine.current_zone == player2.reserve_zones[0],
		"Earthquake should not destroy face-down machines."
	)
	_assert_state(
		survivor.current_zone == player2.reserve_zones[1],
		"Earthquake should not destroy non-machine creatures."
	)

	var moved_callback := Callable(game_manager, "_on_player_card_moved")
	var defeated_callback := Callable(game_manager, "_on_player_defeated")
	for player in game_manager.players:
		if player.card_moved.is_connected(moved_callback):
			player.card_moved.disconnect(moved_callback)
		if player.defeated.is_connected(defeated_callback):
			player.defeated.disconnect(defeated_callback)

	print("earthquake_probe: PASS")
	quit()
