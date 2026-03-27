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

	var player1: Player = card_test.player1
	var player2: Player = card_test.player2

	var dromi: Dromi = null
	for card in player1.hand_zone.cards:
		if card is Dromi:
			dromi = card
			break
	_assert_state(dromi != null, "Expected Dromi in Player 1 hand.")

	var exorcism: Exorcism = null
	for card in player2.hand_zone.cards:
		if card is Exorcism:
			exorcism = card
			break
	_assert_state(exorcism != null, "Expected Exorcism in Player 2 hand.")

	var target: Card = player2.frontline_zones[1].get_creature()
	_assert_state(target != null, "Expected a Player 2 creature target in frontline lane 2.")

	card_test._begin_hand_permanent_hex_target_selection(dromi)
	_assert_state(card_test._has_pending_click_selection(), "Dromi should enter click-to-select targeting mode.")
	_assert_state(card_test.selected_card == dromi, "Dromi should remain selected during targeting.")

	var handled := card_test._try_handle_pending_click_selection(target)
	_assert_state(handled, "Dromi targeting flow should accept the chosen target.")
	_assert_state(dromi.attached_target == target, "Dromi should remain attached to the target creature.")
	_assert_state(dromi.current_zone == target.current_zone, "Dromi should share the target creature's board zone.")
	_assert_state(target.has_status_effect("cannot_attack"), "The Dromi-bound creature should have cannot_attack.")

	_assert_state(exorcism.current_zone == player2.hand_zone, "Exorcism should remain in Player 2 hand.")
	_assert_state(exorcism.is_valid_target(target), "Exorcism should be able to target the Dromi-bound friendly creature.")

	print("dromi_exorcism_probe: PASS")
	scene.queue_free()
	quit()
