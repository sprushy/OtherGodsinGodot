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

	var card_test: CardTestGame = scene.get_node("Control/GameContainer/CardTest")
	await card_test.start_game()
	await process_frame
	await process_frame

	_assert_state(card_test.game_manager.current_player == card_test.player1, "Expected CardTestGame to start on player 1.")
	_assert_state(not card_test.choice_container.visible, "CardTestGame setup should begin after the initial upkeep window.")

	card_test._do_end_turn()
	await process_frame
	await process_frame
	await process_frame

	_assert_state(card_test.game_manager.current_player == card_test.player2, "Ending player 1's turn should pass control to player 2.")
	_assert_state(card_test.choice_container.visible, "Player 2 should receive an upkeep choice window in CardTestGame.")

	scene.queue_free()
	print("cardtest_player2_upkeep_probe: PASS")
	quit()
