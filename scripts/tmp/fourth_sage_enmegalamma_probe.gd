extends SceneTree

const FirstSageAdapaScript := preload("res://scripts/cards/Creatures/FirstSageAdapa.gd")
const EnkiLordOfEriduScript := preload("res://scripts/cards/Creatures/EnkiLordOfEridu.gd")

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

	var enmegalamma_script = load("res://scripts/cards/Creatures/FourthSageEnmegalamma.gd")
	_assert_state(enmegalamma_script != null, "Fourth Sage Enmegalamma script should load.")
	var enmegalamma = enmegalamma_script.new()
	enmegalamma.card_owner = player1
	player1.frontline_zones[0].add_card(enmegalamma)

	var duplicate_copy = enmegalamma_script.new()
	duplicate_copy.card_owner = player1
	player1.deck_zone.add_card(duplicate_copy)

	var adapa := FirstSageAdapaScript.new()
	adapa.card_owner = player1
	player1.deck_zone.add_card(adapa)

	var enki := EnkiLordOfEriduScript.new()
	enki.card_owner = player1
	player1.deck_zone.add_card(enki)

	var valid_targets: Array[Card] = enmegalamma.get_valid_targets(game_manager)
	_assert_state(duplicate_copy not in valid_targets, "Search Sage should exclude another copy of Fourth Sage Enmegalamma.")
	_assert_state(adapa in valid_targets, "Search Sage should include First Sage Adapa as a Mer Sage.")
	_assert_state(enki in valid_targets, "Search Sage should include Enki, Lord of Eridu as a Mer Sage.")

	var result: String = enmegalamma.resolve_search_sage_impact(game_manager, adapa)
	_assert_state(adapa.current_zone == player1.hand_zone, "Search Sage should move the chosen Mer Sage from deck to hand.")
	_assert_state(duplicate_copy.current_zone == player1.deck_zone, "The excluded duplicate copy should remain in the deck.")
	_assert_state(player1.hand_zone.cards.has(adapa), "The chosen Mer Sage should be present in hand.")

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

	print("fourth_sage_enmegalamma_probe: PASS")
	print("PROBE: result=", result)
	quit()
