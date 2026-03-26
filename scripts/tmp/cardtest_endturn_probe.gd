extends SceneTree

const MAIN_SCENE := preload("res://scenes/mainfork.tscn")

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

	var menu: Control = scene.get_node("Control")
	var card_test: CardTestGame = scene.get_node("Control/GameContainer/CardTest")
	await card_test.start_game()
	await process_frame
	await process_frame

	var player1: Player = card_test.player1
	var player2: Player = card_test.player2

	var dromi: Dromi = null
	for card in player1.hand_zone.cards:
		if card is Dromi:
			dromi = card
			break
	_assert_state(dromi != null, "Expected Dromi in player 1 hand.")

	var target: Card = player2.frontline_zones[1].get_creature()
	_assert_state(target != null, "Expected a creature target in player 2 frontline lane 2.")

	card_test._begin_hand_permanent_hex_target_selection(dromi)
	_assert_state(card_test._has_pending_click_selection(), "Dromi should enter click-to-select targeting mode.")
	_assert_state(card_test.selected_card == dromi, "Dromi should remain the selected hand card during targeting.")

	var handled: bool = card_test._try_handle_pending_click_selection(target)
	_assert_state(handled, "Click-selection handler should accept Dromi's chosen target.")
	_assert_state(dromi.current_zone == target.current_zone, "Dromi should attach into the target's board zone.")
	_assert_state(dromi.attached_target == target, "Dromi should record its attached target.")
	_assert_state(target.has_status_effect("cannot_attack"), "Dromi should apply the cannot_attack status to its target.")
	_assert_state(not card_test._creature_can_attack(target), "Combat UI should block attacks from a Dromi-bound creature.")

	var followers_before: int = player2.followers
	card_test.game_manager.current_player = player2
	card_test.game_manager.other_player = player1
	card_test.game_manager.turn_player = player2
	card_test.game_manager.start_turn()
	_assert_state(player2.followers == followers_before - 7, "Dromi should drain 7 followers at the start of the bound creature controller's turn.")

	menu.queue_free()
	scene.queue_free()
	print("cardtest_endturn_probe: PASS")
	quit()
