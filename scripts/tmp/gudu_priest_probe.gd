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

	var berserker: Card = card_test.player1.frontline_zones[0].get_creature()
	var gudu_priest: GududPriest = card_test.player1.frontline_zones[3].get_creature() as GududPriest

	_assert_state(berserker != null, "Expected Berserker on the card test board.")
	_assert_state(gudu_priest != null, "Expected Gudu Priest on the card test board.")
	_assert_state(berserker.has_status_effect("cannot_attack"), "Berserker should begin with the test cannot_attack effect.")
	_assert_state(gudu_priest.has_method("get_valid_targets"), "Gudu Priest should expose valid targets for targeted activation UI.")
	_assert_state(berserker in gudu_priest.get_valid_targets(card_test.game_manager), "Berserker should be a valid target for Creature Ward.")

	gudu_priest.activate(card_test.game_manager, berserker)

	_assert_state(not berserker.has_status_effect("cannot_attack"), "Creature Ward should clear Berserker's creature-applied cannot_attack effect.")
	_assert_state(berserker.has_status_effect("blessed_ward"), "Creature Ward should apply a blessed_ward status.")
	_assert_state(gudu_priest.is_used, "Creature Ward should mark Gudu Priest used for the turn.")
	_assert_state(not gudu_priest.creature_major_action_used, "Creature Ward should not spend Gudu Priest's major action.")
	_assert_state(gudu_priest.creature_minor_actions_used == 0, "Creature Ward should not spend Gudu Priest's minor actions.")
	_assert_state((berserker as Berserker).can_activate(card_test.game_manager), "Berserker Rage should still be activatable while Creature Ward is active on Berserker.")

	(berserker as Berserker).activate(card_test.game_manager)

	_assert_state(not (berserker as Berserker).rage_active_this_turn, "Ward-suppressed Berserker Rage should not become active.")
	_assert_state(berserker.get_effective_strength() == berserker.strength, "Ward-suppressed Berserker Rage should not grant its strength buff.")
	_assert_state(not berserker.has_status_effect("berserker_rage_guard"), "Ward-suppressed Berserker Rage should not add its guard status.")
	_assert_state((berserker as Berserker).is_used, "Ward-suppressed Berserker Rage should still consume Berserker's once-per-turn use.")

	print("gudu_priest_probe: PASS")
	scene.queue_free()
	quit()
