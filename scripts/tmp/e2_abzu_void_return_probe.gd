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
	var e2_abzu: E2Abzu = null
	var void_enki: Card = null

	for zone in player1.frontline_zones + player1.reserve_zones:
		for card in zone.cards:
			if card is E2Abzu:
				e2_abzu = card
				break
		if e2_abzu != null:
			break

	for card in player1.abyss_zone.cards:
		if card is EnkiLordOfEridu:
			void_enki = card
			break

	_assert_state(e2_abzu != null, "Expected E2-abzu on Player 1's board.")
	_assert_state(void_enki != null, "Expected Enki, Lord of Eridu in Player 1's Void.")

	player1.spend_mana(player1.mana)
	player1.gain_mana(void_enki.level + E2Abzu.RETURN_TO_HAND_COST)

	var valid_void_targets := e2_abzu.get_valid_void_targets(card_test.game_manager)
	_assert_state(
		void_enki not in valid_void_targets,
		"E2-abzu should not target a Void creature when paying its return cost would leave mana equal to that creature's level."
	)

	e2_abzu.activate(card_test.game_manager, void_enki)
	_assert_state(void_enki.current_zone == player1.abyss_zone, "Invalid Void return target should stay in the Void.")
	_assert_state(
		player1.mana == void_enki.level + E2Abzu.RETURN_TO_HAND_COST,
		"Mana should not be spent when E2-abzu's Void return target is invalid after payment."
	)

	scene.queue_free()
	print("e2_abzu_void_return_probe: PASS")
	quit()
