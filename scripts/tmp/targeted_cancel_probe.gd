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

	var game_manager: GameManager = card_test.game_manager
	var player1: Player = card_test.player1
	var player2: Player = card_test.player2

	game_manager.current_player = player2
	game_manager.other_player = player1
	game_manager.turn_player = player2
	player1.is_turn_player = false
	player2.is_turn_player = true

	var absence: Absence = null
	for card in player2.hand_zone.cards:
		if card is Absence:
			absence = card
			break
	_assert_state(absence != null, "Expected Absence in Player 2 hand.")

	var target_power: Card = player1.power_zones[0].cards[0]
	_assert_state(target_power != null and target_power is PowerCard and not target_power.is_face_down, "Expected a face-up power target for Absence.")

	var mana_before := player2.mana
	var hand_before := player2.hand_zone.cards.size()
	var graveyard_before := player2.graveyard_zone.cards.size()

	card_test.selected_card = absence
	card_test._cast_targeted_spell(absence, target_power)
	_assert_state(card_test.get_node_or_null("AbsenceModePromptPanel") != null, "Absence should open its mode prompt for a face-up power.")

	card_test._on_absence_cancel_pressed()

	_assert_state(absence.current_zone == player2.hand_zone, "Cancelled Absence should stay in hand.")
	_assert_state(player2.hand_zone.cards.size() == hand_before, "Cancelled Absence should remain in hand.")
	_assert_state(player2.graveyard_zone.cards.size() == graveyard_before, "Cancelled Absence should not go to the graveyard.")
	_assert_state(player2.mana == mana_before, "Cancelled Absence should not spend mana.")
	_assert_state(card_test.selected_card == null, "Cancelled Absence should clear the selected card.")

	scene.queue_free()
	print("targeted_cancel_probe: PASS")
	quit()
