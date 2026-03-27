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
	var dellingr: DellingrTheDayspring = player1.god_zone.cards[0]

	var enemy_visible_creature: Card = player2.reserve_zones[2].cards[0]
	_assert_state(enemy_visible_creature != null, "Expected an on-field enemy En-hedu-anna.")
	_assert_state(not dellingr.is_valid_activation_target(enemy_visible_creature), "Dellingr should not target a face-up enemy creature.")

	var enemy_face_down_power: PowerCard = player2.power_zones[0].cards[0]
	_assert_state(enemy_face_down_power != null, "Expected an enemy power in slot 1.")
	enemy_face_down_power.is_face_down = true
	enemy_face_down_power.is_publicly_revealed = false
	_assert_state(dellingr.is_valid_activation_target(enemy_face_down_power), "Dellingr should target a hidden enemy power.")

	enemy_face_down_power.temporarily_reveal_until_end_of_turn(game_manager.turn_number, "Probe", dellingr, player1, game_manager)
	_assert_state(not dellingr.is_valid_activation_target(enemy_face_down_power), "Dellingr should not target an already revealed enemy power.")

	var valid_targets := dellingr.get_valid_targets(game_manager)
	_assert_state(enemy_visible_creature not in valid_targets, "Face-up enemy creature should not appear in Dellingr's valid targets.")
	_assert_state(enemy_face_down_power not in valid_targets, "Already revealed enemy power should not appear in Dellingr's valid targets.")

	scene.queue_free()
	print("dellingr_reveal_probe: PASS")
	quit()
