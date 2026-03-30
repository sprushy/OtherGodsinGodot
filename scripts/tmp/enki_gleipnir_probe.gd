extends SceneTree

const EnkiScript := preload("res://scripts/cards/Creatures/EnkiLordOfEridu.gd")
const GleipnirScript := preload("res://scripts/cards/Hexes/Gleipnir.gd")

func _assert_state(condition: bool, message: String) -> void:
	if condition:
		return
	push_error(message)
	quit(1)

func _initialize() -> void:
	call_deferred("_run_probe")

func _run_probe() -> void:
	var game_manager := GameManager.new()
	var player1 := Player.new()
	player1.player_name = "Player 1"
	var player2 := Player.new()
	player2.player_name = "Player 2"

	game_manager.players = [player1, player2]
	game_manager.setup_game()
	game_manager.current_player = player2
	game_manager.other_player = player1
	game_manager.turn_player = player2
	game_manager.turn_number = 1
	game_manager.feedback_viewer = player2

	var enki := EnkiScript.new()
	enki.card_owner = player1
	player1.frontline_zones[0].add_card(enki)

	var gleipnir := GleipnirScript.new()
	gleipnir.card_owner = player2
	player2.frontline_zones[0].add_card(gleipnir)

	_assert_state(
		game_manager.is_immune_to_source(enki, gleipnir),
		"Enki should be hex-immune while on the field."
	)
	_assert_state(
		gleipnir.can_activate_on_target(game_manager, enki),
		"Gleipnir should be able to target Enki."
	)
	_assert_state(
		gleipnir.activate_on_target(game_manager, enki),
		"Gleipnir should still attach to Enki."
	)
	_assert_state(
		not enki.has_status_effect("cannot_attack"),
		"Enki should not gain cannot_attack from Gleipnir."
	)
	_assert_state(
		not enki.has_status_effect(Card.ABILITY_NEGATED_STATUS),
		"Enki should keep his abilities while his hex protection is active."
	)
	_assert_state(
		gleipnir.attached_target == enki,
		"Gleipnir should remain attached to Enki even while inert."
	)

	enki.mute_for_turns(1, game_manager)

	_assert_state(
		not game_manager.is_immune_to_source(enki, gleipnir),
		"Once Enki loses his ability, his hex protection should drop."
	)
	_assert_state(
		enki.has_status_effect("cannot_attack"),
		"Gleipnir should start preventing attacks once Enki loses his ability."
	)
	_assert_state(
		enki.has_status_effect(Card.ABILITY_NEGATED_STATUS),
		"Gleipnir should negate Enki's abilities while his own protection is offline."
	)

	enki.mute_for_turns(0, game_manager)

	_assert_state(
		game_manager.is_immune_to_source(enki, gleipnir),
		"Enki should regain hex protection once his own ability comes back."
	)
	_assert_state(
		not enki.has_status_effect("cannot_attack"),
		"Gleipnir should go back to being inert once Enki's protection returns."
	)
	_assert_state(
		not enki.has_status_effect(Card.ABILITY_NEGATED_STATUS),
		"Ability negation should also switch back off when Enki is protected again."
	)

	print("enki_gleipnir_probe: PASS")
	quit()
