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

	card_test.load_habrok_test_scenario()
	await process_frame
	await process_frame

	var player1: Player = card_test.player1
	var player2: Player = card_test.player2
	var habrok: HabrokParagonOfHawks = null
	var blessed_knights: BlessedKnights = null
	var brown_bear: BrownBear = null
	var enkidu: Enkidu = null

	for zone in player1.frontline_zones + player1.reserve_zones:
		for card in zone.cards:
			if card is HabrokParagonOfHawks:
				habrok = card

	for zone in player2.frontline_zones + player2.reserve_zones:
		for card in zone.cards:
			if card is BlessedKnights:
				blessed_knights = card
			elif card is BrownBear:
				brown_bear = card
			elif card is Enkidu:
				enkidu = card

	_assert_state(habrok != null, "Expected Habrok on player 1's board.")
	_assert_state(blessed_knights != null, "Expected Blessed Knights on player 2's board.")
	_assert_state(brown_bear != null, "Expected Brown Bear on player 2's board.")
	_assert_state(enkidu != null, "Expected Enkidu on player 2's board.")
	_assert_state(card_test.game_manager.current_player == player1, "Habrok scenario should begin on player 1.")

	card_test._continue_end_turn_sequence()
	await process_frame
	await process_frame
	_assert_state(card_test.game_manager.current_player == player2, "First end turn should pass to player 2.")
	_assert_state(card_test.choice_container.visible, "Player 2 upkeep choice should open before the breakout test turn.")

	card_test._on_mana_button_pressed()
	await process_frame
	await process_frame
	_assert_state(not card_test.choice_container.visible, "Choosing upkeep should close the turn choice window.")

	card_test._continue_end_turn_sequence()
	await process_frame
	await process_frame
	_assert_state(card_test._pending_habrok_breakout != null, "Habrok should prompt for its optional Breakout trigger.")
	card_test._resolve_habrok_breakout_prompt(true)
	await process_frame
	await process_frame

	_assert_state(habrok.current_zone == player1.hand_zone, "Habrok should return to player 1's hand at the end of player 2's turn.")
	_assert_state(blessed_knights.current_zone == player2.graveyard_zone, "Habrok should destroy Blessed Knights as the weakest enemy creature.")
	_assert_state(brown_bear.current_zone != player2.graveyard_zone, "Brown Bear should survive the breakout test.")
	_assert_state(enkidu.current_zone != player2.graveyard_zone, "Enkidu should survive the breakout test.")

	scene.queue_free()
	print("habrok_breakout_probe: PASS")
	quit()
