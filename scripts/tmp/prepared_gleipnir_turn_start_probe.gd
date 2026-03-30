extends SceneTree

const GleipnirScript := preload("res://scripts/cards/Hexes/Gleipnir.gd")
const FenrirScript := preload("res://scripts/cards/Creatures/Fenrir.gd")
const EnkiduScript := preload("res://scripts/cards/Creatures/Enkidu.gd")

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
	game_manager.turn_number = 3

	var friendly_creature := FenrirScript.new()
	friendly_creature.card_owner = player1
	player1.frontline_zones[0].add_card(friendly_creature)

	var enemy_creature := EnkiduScript.new()
	enemy_creature.card_owner = player2
	player2.frontline_zones[0].add_card(enemy_creature)

	var gleipnir := GleipnirScript.new()
	gleipnir.card_owner = player2
	player2.power_zones[0].add_card(gleipnir)
	gleipnir.is_prepared = true
	gleipnir.is_face_down = true
	game_manager.prepared_hexes[gleipnir] = game_manager.turn_number - 1

	var start_turn_action := CardAction.new()
	start_turn_action.type = CardAction.Type.EVENT
	start_turn_action.source_player = player1
	start_turn_action.initial_priority_player = player1
	start_turn_action.event_name = "start_turn"
	game_manager.push_to_stack(start_turn_action)

	_assert_state(
		game_manager.can_card_respond_to_priority(gleipnir, player2),
		"Prepared Gleipnir should be a legal priority response during the opponent's start-turn window."
	)
	var priority_responses := game_manager.get_priority_responses(player2)
	_assert_state(
		gleipnir in priority_responses,
		"Prepared Gleipnir should appear in the opponent's priority responses."
	)
	_assert_state(
		priority_responses.count(gleipnir) == 1,
		"Prepared Gleipnir should only appear once in the opponent's priority responses."
	)

	game_manager.priority_player = player2
	game_manager._notify_controller_turn_start(player2)

	_assert_state(
		gleipnir.current_zone != null and gleipnir.current_zone.is_board_zone(),
		"Prepared Gleipnir should stay on the board at the start of its owner's turn."
	)
	_assert_state(
		game_manager.prepared_hexes.has(gleipnir),
		"Prepared Gleipnir should remain tracked as prepared at the start of its owner's turn."
	)

	print("prepared_gleipnir_turn_start_probe: PASS")
	quit()
