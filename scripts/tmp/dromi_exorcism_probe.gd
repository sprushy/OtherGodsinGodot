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

	card_test._add_test_hand_card(player2, Exorcism.new())

	var dromi := Dromi.new()
	card_test._place_test_prepared_card(player1, player1.reserve_zones[4], dromi)
	_assert_state(dromi.is_prepared, "Expected Dromi to begin prepared on the board.")

	var exorcism: Exorcism = null
	for card in player2.hand_zone.cards:
		if card is Exorcism:
			exorcism = card
			break
	_assert_state(exorcism != null, "Expected Exorcism in Player 2 hand.")

	var target: Card = player2.frontline_zones[1].get_creature()
	_assert_state(target != null, "Expected a Player 2 creature target in frontline lane 2.")
	var prepared_zone := dromi.current_zone

	_assert_state(dromi.activate_on_target(card_test.game_manager, target), "Prepared Dromi should attach successfully.")
	_assert_state(dromi.attached_target == target, "Dromi should remain attached to the target creature.")
	_assert_state(dromi.current_zone == prepared_zone, "Dromi should stay in the zone it was prepared in after attaching.")
	_assert_state(target.has_status_effect("cannot_attack"), "The Dromi-bound creature should have cannot_attack.")
	_assert_state(not card_test.match_manager.can_attack(target), "The Dromi-bound creature should not be able to attack.")

	var moved_zone := player2.reserve_zones[2]
	_assert_state(moved_zone != null and moved_zone.cards.is_empty(), "Expected an empty reserve lane to test target movement while Dromi stays in place.")
	player2.move_card(target, moved_zone)
	_assert_state(dromi.current_zone == prepared_zone, "Dromi should remain in its original prepared zone when the target moves.")
	_assert_state(dromi.attached_target == target, "Dromi should stay attached after the target moves.")
	_assert_state(target.has_status_effect("cannot_attack"), "Moving the target should not clear Dromi's attack lock.")

	_assert_state(exorcism.current_zone == player2.hand_zone, "Exorcism should remain in Player 2 hand.")
	_assert_state(exorcism.is_valid_target(target), "Exorcism should be able to target the Dromi-bound friendly creature.")

	print("dromi_exorcism_probe: PASS")
	scene.queue_free()
	quit()
