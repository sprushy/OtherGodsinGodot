extends SceneTree

const MAIN_SCENE := preload("res://scenes/mainfork.tscn")
const EnHeduAnnaScript = preload("res://scripts/cards/Creatures/EnHeduAnna.gd")

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
	var god: Card = player1.god_zone.cards[0]

	var en_hedu = EnHeduAnnaScript.new()
	card_test._place_test_board_card(player1, player1.frontline_zones[2], en_hedu, Card.CreatureMode.DEFENSIVE)

	en_hedu.on_friendly_god_power_activated(game_manager, god, null)
	_assert_state(en_hedu.has_pending_exaltation_choice(), "En-hedu-anna should queue Exaltation after a friendly god power activation.")

	var speed_option: Dictionary = {}
	for option in en_hedu.get_exaltation_options():
		if int(option.get("spd", 0)) == 1:
			speed_option = option
			break
	_assert_state(not speed_option.is_empty(), "Expected to find the +1 SPD Exaltation option.")

	var result := en_hedu.resolve_exaltation_choice(game_manager, speed_option)
	_assert_state(result.contains("+1 SPD"), "Exaltation should report the chosen +1 SPD bonus.")
	_assert_state(en_hedu.get_effective_speed() == 2, "En-hedu-anna should gain +1 SPD until the end of the next turn.")
	_assert_state(en_hedu.has_status_effect("cannot_attack"), "En-hedu-anna should be unable to attack during Exaltation.")
	_assert_state(en_hedu.has_status_effect("en_hedu_anna_exaltation_guard"), "En-hedu-anna should gain its Exaltation guard status.")
	_assert_state(not game_manager.request_send_to_graveyard(en_hedu, Callable(), false, true), "En-hedu-anna should resist destruction while Exaltation is active.")

	game_manager.end_turn()
	_assert_state(en_hedu.get_effective_speed() == 2, "Exaltation should persist through the opponent's turn.")
	_assert_state(en_hedu.has_status_effect("cannot_attack"), "Cannot-attack should persist through the opponent's turn.")

	game_manager.end_turn()
	_assert_state(en_hedu.get_effective_speed() == 1, "Exaltation bonus should expire at the end of the next turn.")
	_assert_state(not en_hedu.has_status_effect("cannot_attack"), "Cannot-attack should expire at the end of the next turn.")
	_assert_state(not en_hedu.has_status_effect("en_hedu_anna_exaltation_guard"), "Exaltation guard should expire at the end of the next turn.")

	en_hedu.on_friendly_god_power_activated(game_manager, god, null)
	_assert_state(en_hedu.has_pending_exaltation_choice(), "En-hedu-anna should be able to trigger again on a later turn.")
	en_hedu.has_attacked_this_turn = true
	en_hedu.consume_pending_exaltation_choice()
	en_hedu.on_friendly_god_power_activated(game_manager, god, null)
	_assert_state(not en_hedu.has_pending_exaltation_choice(), "En-hedu-anna should not trigger if it has already attacked this turn.")

	scene.queue_free()
	print("en_hedu_anna_probe: PASS")
	quit()
