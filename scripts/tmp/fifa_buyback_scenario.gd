extends SceneTree

const MAIN_SCENE := preload("res://scenes/mainfork.tscn")
const BUYBACK_COST := 4

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

	await _run_same_turn_buyback_scenario(card_test)
	await _run_expiry_scenario(card_test)

	scene.queue_free()
	print("fifa_buyback_scenario: PASS")
	quit()

func _run_same_turn_buyback_scenario(card_test: CardTestGame) -> void:
	var state := await _setup_fifa_scenario(card_test, 11)
	var game_manager: GameManager = card_test.game_manager
	var player1: Player = state["player1"]
	var player2: Player = state["player2"]
	var archer: Card = state["archer"]
	var victim: Card = state["victim"]
	var fifa: FifaTheMagicalArrow = state["fifa"]

	card_test._resolve_charm_action(fifa, archer)
	_assert_state(fifa.current_zone == player1.graveyard_zone, "Fifa should move to the graveyard after resolving.")
	_assert_state(not fifa.can_activate_from_graveyard(game_manager), "Fifa should not be activatable before the enchanted Archer gets a kill.")

	card_test.update_ui()
	await process_frame
	var pre_kill_proxy := _find_hand_visual(card_test, fifa)
	_assert_state(pre_kill_proxy == null, "Fifa should not show a hand proxy before the Archer destroys an attack target.")

	game_manager._combat_kill(archer, victim)
	_assert_state(victim.current_zone == player2.graveyard_zone, "The test victim should be destroyed and sent to the graveyard.")
	_assert_state(fifa.can_activate_from_graveyard(game_manager), "Fifa should become activatable from the graveyard after the enchanted Archer gets a same-turn kill.")

	card_test.update_ui()
	await process_frame
	var proxy_visual := _find_hand_visual(card_test, fifa)
	_assert_state(proxy_visual != null, "Fifa should appear in hand as a proxy once buyback is legal.")
	_assert_state(proxy_visual._ghostly_hand_proxy, "The graveyard proxy should use the ghost hand-card styling.")
	_assert_state(proxy_visual._click_only, "The graveyard proxy should be click-only instead of draggable.")

	var mana_before_buyback := player1.mana
	var handled := card_test._try_activate_graveyard_hand_proxy(fifa)
	_assert_state(handled, "Clicking the proxy should route through the graveyard activation handler.")
	_assert_state(fifa.current_zone == player1.hand_zone, "Successful buyback should return Fifa to hand.")
	_assert_state(player1.mana == mana_before_buyback - BUYBACK_COST, "Buyback should spend 4 mana.")
	_assert_state(card_test.action_label.text.contains("returns from the graveyard"), "The UI should report the successful buyback.")

	card_test.update_ui()
	await process_frame
	_assert_state(_find_hand_visual(card_test, fifa) != null, "After buyback, Fifa should still be visible in hand as a real card.")

func _run_expiry_scenario(card_test: CardTestGame) -> void:
	var state := await _setup_fifa_scenario(card_test, 21)
	var game_manager: GameManager = card_test.game_manager
	var player1: Player = state["player1"]
	var archer: Card = state["archer"]
	var victim: Card = state["victim"]
	var fifa: FifaTheMagicalArrow = state["fifa"]

	card_test._resolve_charm_action(fifa, archer)
	_assert_state(fifa.current_zone == player1.graveyard_zone, "Expiry scenario setup should also put Fifa in the graveyard.")

	game_manager.end_turn()
	game_manager.feedback_viewer = player1
	card_test.hide_turn_choice()
	card_test.update_ui()
	await process_frame

	_assert_state(not fifa.can_activate_from_graveyard(game_manager), "Fifa buyback should expire when the turn ends.")
	_assert_state(not (fifa in card_test._get_graveyard_hand_proxy_cards(player1)), "Expired Fifa buyback should not be offered as a graveyard hand proxy on the next turn.")

	game_manager._combat_kill(archer, victim)
	card_test.update_ui()
	await process_frame

	_assert_state(not fifa.can_activate_from_graveyard(game_manager), "A kill on a later turn must not re-enable Fifa buyback.")
	_assert_state(not (fifa in card_test._get_graveyard_hand_proxy_cards(player1)), "A later-turn kill must not recreate the graveyard hand proxy.")

func _setup_fifa_scenario(card_test: CardTestGame, turn_number: int) -> Dictionary:
	var game_manager := card_test.game_manager
	var player1 := card_test.player1
	var player2 := card_test.player2

	card_test._reset_player_test_state(player1)
	card_test._reset_player_test_state(player2)
	game_manager.prepared_hexes.clear()
	game_manager.prepared_charms.clear()
	game_manager.attack_restrictions.clear()
	game_manager.died_this_turn.clear()
	game_manager.pending_resurrections.clear()
	game_manager.combat_destroy_events_this_turn.clear()
	game_manager.action_stack.clear()
	game_manager.consecutive_passes = 0
	game_manager.priority_player = null
	game_manager._temporary_summon_cost_modifiers.clear()

	var archer := GenericCreature.new({
		"name": "Test Archer",
		"types": ["Warrior", "Archer"],
		"speed": 2,
		"strength": 3,
		"resilience": 6,
		"culture": "Norse",
	})
	var victim := GenericCreature.new({
		"name": "Test Target",
		"types": ["Warrior"],
		"speed": 1,
		"strength": 1,
		"resilience": 2,
		"culture": "Neutral",
	})
	var fifa := FifaTheMagicalArrow.new()

	card_test._place_test_board_card(player1, player1.frontline_zones[0], archer, Card.CreatureMode.AGGRESSIVE)
	card_test._place_test_board_card(player2, player2.frontline_zones[0], victim, Card.CreatureMode.DEFENSIVE)
	card_test._add_test_hand_card(player1, fifa)

	player1.spend_mana(player1.mana)
	player2.spend_mana(player2.mana)
	player1.gain_mana(10)
	player2.gain_mana(10)
	player1.followers = 100
	player2.followers = 100
	player1.followers_changed.emit(player1.followers)
	player2.followers_changed.emit(player2.followers)
	player1.has_summoned_this_turn = false
	player2.has_summoned_this_turn = false

	game_manager.current_player = player1
	game_manager.other_player = player2
	game_manager.turn_player = player1
	game_manager.feedback_viewer = player1
	game_manager.current_phase = GameManager.GamePhase.MAIN
	game_manager.turn_number = turn_number
	player1.is_turn_player = true
	player2.is_turn_player = false

	card_test.selected_card = null
	card_test.selected_attacker = null
	card_test.selected_interceptor = null
	card_test.hide_turn_choice()
	card_test.update_ui()
	await process_frame

	return {
		"player1": player1,
		"player2": player2,
		"archer": archer,
		"victim": victim,
		"fifa": fifa,
	}

func _find_hand_visual(card_test: CardTestGame, target_card: Card) -> VisualCard:
	for visual in card_test._hand_visual_cards:
		if visual != null and visual.card_data == target_card:
			return visual
	return null
