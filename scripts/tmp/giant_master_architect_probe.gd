extends SceneTree

const GiantMasterArchitectScript := preload("res://scripts/cards/Creatures/GiantMasterArchitect.gd")
const EriduCityOfSagesScript := preload("res://scripts/cards/Structures/EriduCityOfSages.gd")
const WardingStoneScript := preload("res://scripts/cards/Structures/WardingStone.gd")
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
	game_manager.turn_number = 1
	game_manager.feedback_viewer = player1

	var architect := GiantMasterArchitectScript.new()
	architect.card_owner = player1
	player1.frontline_zones[0].add_card(architect)

	var eridu := EriduCityOfSagesScript.new()
	eridu.card_owner = player1
	player1.deck_zone.add_card(eridu)

	var warding_stone := WardingStoneScript.new()
	warding_stone.card_owner = player1
	player1.deck_zone.add_card(warding_stone)

	var non_structure := EnkiduScript.new()
	non_structure.card_owner = player1
	player1.deck_zone.add_card(non_structure)

	var valid_targets: Array[Card] = architect.get_valid_targets(game_manager)
	_assert_state(eridu in valid_targets, "Master Plan should include structures from your deck.")
	_assert_state(warding_stone in valid_targets, "Master Plan should include multiple structure options.")
	_assert_state(non_structure not in valid_targets, "Master Plan should exclude non-structure cards.")

	var result := architect.resolve_master_plan_impact(game_manager, warding_stone)
	_assert_state(warding_stone.current_zone == player1.hand_zone, "Master Plan should move the chosen structure from deck to hand.")
	_assert_state(player1.hand_zone.cards.has(warding_stone), "The chosen structure should be present in hand.")
	_assert_state(eridu.current_zone == player1.deck_zone, "Unchosen structures should remain in the deck.")
	_assert_state(non_structure.current_zone == player1.deck_zone, "Non-structure cards should remain in the deck.")

	var moved_callback := Callable(game_manager, "_on_player_card_moved")
	var defeated_callback := Callable(game_manager, "_on_player_defeated")
	for player in game_manager.players:
		if player.card_moved.is_connected(moved_callback):
			player.card_moved.disconnect(moved_callback)
		if player.defeated.is_connected(defeated_callback):
			player.defeated.disconnect(defeated_callback)

	print("giant_master_architect_probe: PASS")
	print("PROBE: result=", result)
	quit()
