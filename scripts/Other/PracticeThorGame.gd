extends CombatMockGame
class_name PracticeThorGame

const DeckBuilderScript = preload("res://scripts/Other/DeckBuilder.gd")
const CardCatalogScript = preload("res://scripts/cards/CardCatalog.gd")

var _practice_active: bool = false
var _thor_ai_step_queued: bool = false
var _player_practice_deck: Dictionary = {}

func set_player_practice_deck(saved_deck: Dictionary) -> void:
	_player_practice_deck = saved_deck.duplicate(true)

func start_game(
	is_host: bool = false,
	is_client: bool = false,
	server_ip: String = "127.0.0.1",
	server_port: int = 12345,
	match_info: Dictionary = {},
	server_match_session = null
) -> void:
	_practice_active = false
	_thor_ai_step_queued = false
	await super.start_game(is_host, is_client, server_ip, server_port, match_info, server_match_session)
	_load_thor_practice_match()

func update_ui() -> void:
	super.update_ui()
	_queue_thor_ai_step()

func _open_upkeep_choice_window() -> void:
	if _practice_active and game_manager != null and _is_thor_player(game_manager.current_player) and not game_manager.has_resolved_turn_upkeep():
		hide_turn_choice()
		action_label.text = "Upkeep for Thor: deciding..."
		_queue_thor_ai_step()
		return
	super._open_upkeep_choice_window()

func _show_priority_prompt(player: Player) -> void:
	if _practice_active and _is_thor_player(player):
		_hide_priority_prompt()
		_queue_thor_ai_step()
		return
	super._show_priority_prompt(player)

func _show_retreat_prompt(ask_card: Askelladen) -> void:
	if _practice_active and ask_card != null and _is_thor_player(ask_card.get_controller()):
		var other_card: Card = null
		if _pending_retreat_action != null and _pending_retreat_target != null:
			other_card = _get_retreat_opponent(ask_card, _pending_retreat_action.attacker, _pending_retreat_target)
		if _should_thor_use_askelladen_retreat(ask_card, other_card):
			call_deferred("_on_retreat_yes")
		else:
			call_deferred("_on_retreat_no")
		return
	super._show_retreat_prompt(ask_card)

func check_for_possible_intercepts() -> void:
	if _practice_active and game_manager != null and pending_attack_target != null:
		var defender: Player = pending_attack_target if pending_attack_target is Player else pending_attack_target.get_controller()
		if _is_thor_player(defender):
			action_label.text = _get_attack_card_label(selected_attacker, "A creature") + " attacking directly - Thor declines to intercept."
			resolve_pending_attack()
			return
	super.check_for_possible_intercepts()

func _load_thor_practice_match() -> void:
	_reset_practice_match_state()

	player1.player_name = "Player 1"
	player2.player_name = "Thor"

	var player_deck_name := _load_player_practice_deck(player1)

	_add_practice_god(player2, Thor.new())
	_add_practice_power(player2, 0, CallOfTheValkyrie.new())
	for card in _build_thor_practice_deck():
		_add_practice_deck_card(player2, card)

	for _draw_index in range(5):
		player1.draw_card()
		player2.draw_card()

	player1.spend_mana(player1.mana)
	player2.spend_mana(player2.mana)
	player2.gain_mana(2)
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
	player1.is_turn_player = true
	player2.is_turn_player = false
	_practice_active = true
	game_manager.start_turn()
	if player_deck_name.is_empty():
		action_label.text = "Practice vs Thor: Thor follows a fixed combat script."
	else:
		action_label.text = "Practice vs Thor: using %s. Thor follows a fixed combat script." % player_deck_name
	update_ui()
	_open_upkeep_choice_window()

func _reset_practice_match_state() -> void:
	_reset_player_practice_state(player1)
	_reset_player_practice_state(player2)
	game_manager.prepared_hexes.clear()
	game_manager.prepared_charms.clear()
	game_manager.attack_restrictions.clear()
	game_manager.died_this_turn.clear()
	game_manager.destroyed_this_turn.clear()
	game_manager.pending_resurrections.clear()
	game_manager.combat_destroy_events_this_turn.clear()
	game_manager.action_stack.clear()
	game_manager.consecutive_passes = 0
	game_manager.priority_player = null
	game_manager.turn_player = null
	game_manager.turn_number = 0
	game_manager._upkeep_started_turn = -1
	game_manager._upkeep_resolved_turn = -1
	game_manager._temporary_summon_cost_modifiers.clear()
	game_manager._next_board_entry_order = 0
	game_manager.last_hex_resolution_text = ""
	game_manager.last_player_feedback_text = ""
	selected_card = null
	selected_attacker = null
	selected_interceptor = null
	pending_attack_target = null
	placement_mode = ""
	awaiting_spell_target = false
	spell_waiting_for_target = null
	spell_waiting_for_action = null
	spell_waiting_for_display_zone = null
	_pending_paid_hand_card = null
	_pending_paid_hand_display_zone = null
	_pending_paid_hand_display_zone_auto = false
	_pending_spell_display_zone = null
	_pending_click_selection_source = null
	_stack_resolution_paused = false
	_executing_stack_action = false
	_pending_post_execute_source_player = null
	_queued_attackers.clear()
	_pending_end_turn_discard_uids.clear()
	_remove_no_intercept_button()
	_hide_priority_prompt()
	hide_turn_choice()
	end_turn_button.visible = false
	_thor_ai_step_queued = false

func _reset_player_practice_state(player: Player) -> void:
	if player == null:
		return
	player.current_deck.clear()
	_clear_zone(player.hand_zone)
	_clear_zone(player.deck_zone)
	_clear_zone(player.graveyard_zone)
	_clear_zone(player.abyss_zone)
	_clear_zone(player.god_zone)
	for zone in player.power_zones:
		_clear_zone(zone)
	for zone in player.frontline_zones:
		_clear_zone(zone)
	for zone in player.reserve_zones:
		_clear_zone(zone)

func _clear_zone(zone: Zone) -> void:
	if zone == null:
		return
	for card in zone.cards.duplicate():
		zone.remove_card(card)

func _add_practice_god(player: Player, god: GodCard) -> void:
	if player == null or god == null:
		return
	god.card_owner = player
	god.is_face_down = false
	god.is_stealth = false
	god.is_muted = false
	god.mute_turns_remaining = 0
	god.reset_creature_action_state()
	god.summoned_this_turn = false
	god.wake_up()
	player.god_zone.add_card(god)
	if god.has_method("on_summon"):
		god.on_summon(game_manager)

func _add_practice_deck_card(player: Player, card: Card) -> void:
	if player == null or card == null:
		return
	card.card_owner = player
	player.deck_zone.add_card(card)

func _add_practice_power(player: Player, slot_index: int, power: PowerCard, unlocked: bool = false) -> void:
	if player == null or power == null:
		return
	if slot_index < 0 or slot_index >= player.power_zones.size():
		return
	power.card_owner = player
	power.is_publicly_revealed = false
	power.is_muted = false
	power.mute_turns_remaining = 0
	if unlocked:
		power.is_face_down = false
	else:
		power.relock()
	player.power_zones[slot_index].add_card(power)
	if unlocked:
		power.on_unlock(game_manager)

func _load_player_practice_deck(player: Player) -> String:
	if _try_load_saved_player_practice_deck(player):
		return str(_player_practice_deck.get("name", "")).strip_edges()
	_add_practice_god(player, Baldr.new())
	create_deck(player)
	return ""

func _try_load_saved_player_practice_deck(player: Player) -> bool:
	if player == null or _player_practice_deck.is_empty():
		return false
	var saved_counts = _player_practice_deck.get("cards", {})
	if not (saved_counts is Dictionary) or (saved_counts as Dictionary).is_empty():
		return false
	var submitted_cards := CardCatalogScript.make_cards_from_counts(saved_counts)
	if submitted_cards.is_empty():
		return false
	var deck_builder := DeckBuilderScript.new()
	return deck_builder.build_deck(player, submitted_cards)

func _build_thor_practice_deck() -> Array[Card]:
	return [
		EnkiLordOfEridu.new(),
		HariiWarrior.new(),
		BrownBear.new(),
		VoidShield.new(),
		MeadOfPoetry.new(),
		DivineLightning.new(),
		FallOfTheMighty.new(),
		HariiWarrior.new(),
		BrownBear.new(),
		EnkiLordOfEridu.new(),
		DivineLightning.new(),
		FallOfTheMighty.new(),
		HariiWarrior.new(),
		BrownBear.new(),
		DivineLightning.new(),
		FallOfTheMighty.new(),
		VoidShield.new(),
		VoidShield.new(),
		Askelladen.new(),
		Askelladen.new(),
	]

func _queue_thor_ai_step() -> void:
	if not _should_queue_thor_ai_step() or _thor_ai_step_queued:
		return
	_thor_ai_step_queued = true
	call_deferred("_run_thor_ai_step")

func _should_queue_thor_ai_step() -> bool:
	if not _practice_active or game_manager == null or player2 == null or _game_finished:
		return false
	if _executing_stack_action or _stack_resolution_paused:
		return false
	if awaiting_spell_target or awaiting_god_ability_target or awaiting_stupefy_target:
		return false
	if awaiting_pyre_target or awaiting_anointing_target or _awaiting_creature_sacrifice:
		return false
	if _awaiting_drag_sacrifice_zone or _awaiting_altar_void_payment:
		return false
	if selected_card != null or selected_attacker != null or selected_interceptor != null:
		return false
	if pending_attack_target != null:
		return false
	if not game_manager.action_stack.is_empty():
		return game_manager.priority_player == player2
	return game_manager.current_player == player2

func _run_thor_ai_step() -> void:
	_thor_ai_step_queued = false
	if not _should_queue_thor_ai_step():
		return
	if not game_manager.action_stack.is_empty():
		_handle_thor_priority()
		return
	if game_manager.current_player != player2:
		return
	if not game_manager.has_resolved_turn_upkeep():
		_handle_thor_upkeep()
		return
	if _take_thor_main_phase_action():
		return
	_finish_thor_turn()

func _handle_thor_upkeep() -> void:
	hide_turn_choice()
	game_input.submit_action({
		type = "upkeep_choice",
		choice = _choose_thor_upkeep_option(),
	})

func _choose_thor_upkeep_option() -> String:
	var best_now := _get_best_affordable_thor_hand_creature(0)
	var best_with_bonus := _get_best_affordable_thor_hand_creature(4)
	if best_with_bonus != null and _is_projected_creature_better(best_with_bonus, best_now):
		return "mana"
	if best_now == null and best_with_bonus != null:
		return "mana"
	return "draw"

func _handle_thor_priority() -> void:
	if game_manager.priority_player != player2:
		return
	var chosen_response := _choose_thor_priority_response()
	if chosen_response != null:
		_on_priority_response_chosen(chosen_response)
		return
	_on_priority_pass_pressed()

func _choose_thor_priority_response() -> Card:
	var responses := game_manager.get_priority_responses(player2)
	var top_action: CardAction = game_manager.action_stack.back() if not game_manager.action_stack.is_empty() else null
	if top_action != null:
		for response_card in responses:
			if response_card is MeadOfPoetry and top_action.target == response_card:
				return response_card
	if _should_activate_prepared_mead_for_enki():
		for response_card in responses:
			if response_card is MeadOfPoetry:
				return response_card
	for response_card in responses:
		if response_card is VoidShield:
			return response_card
	return null

func _take_thor_main_phase_action() -> bool:
	if _try_activate_mead_for_enki():
		return true
	if _try_summon_askelladen_answer():
		return true
	if _try_summon_best_thor_creature():
		return true
	if _try_cast_divine_lightning():
		return true
	if _try_cast_fall_of_the_mighty():
		return true
	if _try_unlock_call_of_the_valkyrie():
		return true
	if _try_activate_call_of_the_valkyrie():
		return true
	if _try_prepare_void_shield():
		return true
	if _try_prepare_mead_of_poetry():
		return true
	if _try_switch_thor_to_aggressive_mode():
		return true
	if _try_attack_with_thor():
		return true
	return false

func _try_activate_mead_for_enki() -> bool:
	var mead := _find_ready_prepared_mead()
	if mead == null or not _should_activate_prepared_mead_for_enki():
		return false
	_queue_charm_action(mead)
	return true

func _should_activate_prepared_mead_for_enki() -> bool:
	if game_manager == null or game_manager.current_player != player2:
		return false
	if player2.has_summoned_this_turn:
		return false
	var enki := _find_hand_enki()
	var mead := _find_ready_prepared_mead()
	if enki == null or mead == null:
		return false
	var mana_cost := _get_play_cost(enki, false)
	if not enki.can_pay_costs_with_mana_cost(player2, mana_cost):
		return false
	return player2.mana < mana_cost and player2.mana + MeadOfPoetry.MANA_GAIN >= mana_cost

func _try_summon_best_thor_creature() -> bool:
	if game_manager == null or player2.has_summoned_this_turn:
		return false
	var zone := _get_first_open_summon_zone(player2)
	if zone == null:
		return false
	var creature := _get_best_affordable_thor_hand_creature(0, zone)
	if creature == null:
		return false
	_do_place_creature(creature, zone, "aggressive")
	return true

func _try_summon_askelladen_answer() -> bool:
	if game_manager == null or player2 == null or player2.has_summoned_this_turn:
		return false
	var askelladen := _find_hand_askelladen()
	if askelladen == null:
		return false
	var zone := _get_first_open_summon_zone(player2)
	if zone == null:
		return false
	var target := _get_thor_askelladen_problem_creature()
	if target == null:
		return false
	if not _can_thor_evaluate_creature_play(askelladen, zone, player2.mana):
		return false
	_do_place_creature(askelladen, zone, "aggressive")
	return true

func _try_cast_divine_lightning() -> bool:
	var divine_lightning := _find_hand_divine_lightning()
	if divine_lightning == null:
		return false
	var target := _pick_divine_lightning_target(player1)
	if target == null:
		return false
	if not divine_lightning.can_activate_from_hand(game_manager):
		return false
	_queue_charm_action(divine_lightning, null, target)
	return true

func _try_cast_fall_of_the_mighty() -> bool:
	var fall := _find_hand_fall_of_the_mighty()
	if fall == null or not _opponent_controls_strictly_strongest_creature():
		return false
	if not _can_afford_hand_card(fall, false):
		return false
	_queue_hand_spell_cast(
		fall,
		null,
		"Fall of the Mighty resolves.",
		func() -> void:
			fall.resolve(game_manager, null)
	)
	return true

func _try_prepare_void_shield() -> bool:
	var void_shield := _find_hand_void_shield()
	if void_shield == null:
		return false
	var zone := _get_first_open_reserve_zone(player2)
	if zone == null:
		return false
	return _submit_prepare_card(void_shield, zone)

func _try_prepare_mead_of_poetry() -> bool:
	var mead := _find_hand_unprepared_mead()
	if mead == null:
		return false
	var zone := _get_first_open_reserve_zone(player2)
	if zone == null:
		return false
	return _submit_prepare_card(mead, zone)

func _try_unlock_call_of_the_valkyrie() -> bool:
	var call := _find_thor_call_of_the_valkyrie()
	if call == null or not call.is_face_down:
		return false
	if not _should_thor_use_call_of_the_valkyrie():
		return false
	return _submit_unlock_power(call)

func _try_activate_call_of_the_valkyrie() -> bool:
	var call := _find_thor_call_of_the_valkyrie()
	if call == null or call.is_face_down:
		return false
	if not _should_thor_use_call_of_the_valkyrie():
		return false
	var target := _choose_thor_call_of_the_valkyrie_target(call)
	if target == null or not call.can_activate(game_manager):
		return false
	return _submit_activate_power(call, target)

func _try_switch_thor_to_aggressive_mode() -> bool:
	var creature := _get_best_thor_mode_switch_candidate()
	if creature == null:
		return false
	return _submit_change_mode(creature, Card.CreatureMode.AGGRESSIVE)

func _try_attack_with_thor() -> bool:
	var attackers := _get_attack_ready_thor_creatures()
	if attackers.is_empty():
		return false
	var opposing_creatures := _get_board_creatures(player1)
	if opposing_creatures.is_empty():
		var direct_attacker := _pick_best_board_creature(attackers)
		return _submit_attack(direct_attacker, player1)
	var askelladen_attack := _get_best_thor_askelladen_attack(attackers, opposing_creatures)
	if not askelladen_attack.is_empty():
		return _submit_attack(askelladen_attack.get("attacker", null), askelladen_attack.get("target", null))
	var attack_threshold := _get_highest_opposing_strength_or_resilience(opposing_creatures)
	var viable_attackers: Array[Card] = []
	for attacker in attackers:
		if attacker.get_effective_strength() > attack_threshold:
			viable_attackers.append(attacker)
	if viable_attackers.is_empty():
		return false
	var chosen_attacker := _pick_best_board_creature(viable_attackers)
	var chosen_target := _pick_best_board_creature(opposing_creatures)
	return _submit_attack(chosen_attacker, chosen_target)

func _finish_thor_turn() -> void:
	_discard_thor_end_turn_cards_if_needed()
	_do_end_turn()

func _discard_thor_end_turn_cards_if_needed() -> void:
	while player2 != null and player2.hand_zone.cards.size() > Player.MAX_HAND_SIZE:
		var discard_card := _choose_thor_end_turn_discard()
		if discard_card == null:
			return
		player2.discard_card(discard_card)
	update_ui()

func _choose_thor_end_turn_discard() -> Card:
	var discard_choice: Card = null
	for card in player2.hand_zone.cards:
		if discard_choice == null or _is_lower_priority_hand_card(card, discard_choice):
			discard_choice = card
	return discard_choice

func _is_lower_priority_hand_card(candidate: Card, current_choice: Card) -> bool:
	if current_choice == null:
		return true
	var candidate_value := _get_thor_hand_value(candidate)
	var current_value := _get_thor_hand_value(current_choice)
	if candidate_value != current_value:
		return candidate_value < current_value
	return _get_card_order_index(candidate) < _get_card_order_index(current_choice)

func _get_thor_hand_value(card: Card) -> int:
	if card is EnkiLordOfEridu:
		return 100
	if card is MeadOfPoetry:
		return 90
	if card is DivineLightning:
		return 80
	if card is Askelladen:
		return 75
	if card is FallOfTheMighty:
		return 70
	if card is VoidShield:
		return 60
	if card is HariiWarrior:
		return 50
	if card is BrownBear:
		return 40
	return 0

func _submit_prepare_card(card: Card, zone: Zone) -> bool:
	if card == null or zone == null or game_manager == null:
		return false
	if not game_manager.can_prepare_card(player2, card, zone):
		return false
	return game_input.submit_action({
		type = "prepare_card",
		card_uid = card.uid,
		player_index = game_manager.players.find(zone.zone_owner),
		zone_type = zone.zone_type,
		zone_index = zone.zone_index,
	})

func _submit_attack(attacker: Card, target) -> bool:
	if attacker == null or target == null:
		return false
	var target_id := ""
	if target is Player:
		target_id = str(game_manager.players.find(target))
	elif target is Card:
		target_id = target.uid
	return game_input.submit_action({
		type = "request_attack",
		attacker_uid = attacker.uid,
		target_id = target_id,
	})

func _submit_change_mode(card: Card, mode: Card.CreatureMode) -> bool:
	if card == null or game_manager == null:
		return false
	return game_input.submit_action({
		type = "change_mode",
		card_uid = card.uid,
		mode = mode,
	})

func _submit_unlock_power(power: PowerCard) -> bool:
	if power == null:
		return false
	return game_input.submit_action({
		type = "unlock_power",
		power_uid = power.uid,
	})

func _submit_activate_power(power: PowerCard, target: Card) -> bool:
	if power == null or target == null:
		return false
	return game_input.submit_action({
		type = "activate_power",
		power_uid = power.uid,
		target_uid = target.uid,
	})

func _get_best_affordable_thor_hand_creature(extra_mana: int, preferred_zone: Zone = null) -> Card:
	if player2 == null or game_manager == null:
		return null
	var zone := preferred_zone if preferred_zone != null else _get_first_open_summon_zone(player2)
	if zone == null:
		return null
	var best_creature: Card = null
	var available_mana := player2.mana + extra_mana
	for card in player2.hand_zone.cards:
		if not _can_thor_evaluate_creature_play(card, zone, available_mana):
			continue
		if _is_projected_creature_better(card, best_creature):
			best_creature = card
	return best_creature

func _can_thor_evaluate_creature_play(card: Card, zone: Zone, available_mana: int) -> bool:
	if card == null or zone == null or player2 == null:
		return false
	if card.card_type != Card.CardType.CREATURE or card.current_zone != player2.hand_zone:
		return false
	if zone.zone_owner != player2 or not zone.cards.is_empty():
		return false
	var mana_cost := _get_play_cost(card, false)
	if available_mana < mana_cost:
		return false
	return card.can_pay_costs_with_mana_cost(player2, mana_cost)

func _pick_best_board_creature(cards: Array[Card]) -> Card:
	var best_card: Card = null
	for card in cards:
		if card == null:
			continue
		if best_card == null or _is_board_creature_better(card, best_card):
			best_card = card
	return best_card

func _is_projected_creature_better(candidate: Card, current_best: Card) -> bool:
	if current_best == null:
		return true
	var candidate_strength := _get_projected_strength(candidate)
	var current_strength := _get_projected_strength(current_best)
	if candidate_strength != current_strength:
		return candidate_strength > current_strength
	var candidate_resilience := _get_projected_resilience(candidate)
	var current_resilience := _get_projected_resilience(current_best)
	if candidate_resilience != current_resilience:
		return candidate_resilience > current_resilience
	var candidate_speed := candidate.get_effective_speed()
	var current_speed := current_best.get_effective_speed()
	if candidate_speed != current_speed:
		return candidate_speed > current_speed
	return _get_card_order_index(candidate) < _get_card_order_index(current_best)

func _is_board_creature_better(candidate: Card, current_best: Card) -> bool:
	if current_best == null:
		return true
	var candidate_strength := candidate.get_effective_strength()
	var current_strength := current_best.get_effective_strength()
	if candidate_strength != current_strength:
		return candidate_strength > current_strength
	var candidate_resilience := candidate.get_effective_resilience()
	var current_resilience := current_best.get_effective_resilience()
	if candidate_resilience != current_resilience:
		return candidate_resilience > current_resilience
	var candidate_speed := candidate.get_effective_speed()
	var current_speed := current_best.get_effective_speed()
	if candidate_speed != current_speed:
		return candidate_speed > current_speed
	return _get_card_order_index(candidate) < _get_card_order_index(current_best)

func _get_projected_strength(card: Card) -> int:
	if card == null:
		return 0
	var total := card.strength
	if _would_receive_thor_buff(card):
		total += 3
	return total

func _get_projected_resilience(card: Card) -> int:
	if card == null:
		return 0
	var total := card.resilience
	if _would_receive_thor_buff(card):
		total += 3
	return total

func _would_receive_thor_buff(card: Card) -> bool:
	return card != null and card.has_type("Human") and card.has_type("Warrior")

func _get_best_thor_askelladen_attack(attackers: Array[Card], opposing_creatures: Array[Card]) -> Dictionary:
	var best_attack := {}
	for attacker in attackers:
		if not (attacker is Askelladen):
			continue
		var target := _get_best_askelladen_target_for(attacker as Askelladen, opposing_creatures)
		if target == null:
			continue
		if best_attack.is_empty():
			best_attack = {"attacker": attacker, "target": target}
			continue
		var current_attacker: Card = best_attack.get("attacker", null)
		var current_target: Card = best_attack.get("target", null)
		if _is_board_creature_better(attacker, current_attacker):
			best_attack = {"attacker": attacker, "target": target}
			continue
		if attacker == current_attacker and _is_board_creature_better(target, current_target):
			best_attack = {"attacker": attacker, "target": target}
	return best_attack

func _get_best_askelladen_target_for(askelladen: Askelladen, opposing_creatures: Array[Card]) -> Card:
	var best_target: Card = null
	for creature in opposing_creatures:
		if not _should_thor_use_askelladen_retreat(askelladen, creature):
			continue
		if best_target == null or _is_board_creature_better(creature, best_target):
			best_target = creature
	return best_target

func _get_best_thor_mode_switch_candidate() -> Card:
	if player2 == null or game_manager == null:
		return null
	var opposing_creatures := _get_board_creatures(player1)
	var best_creature: Card = null
	var best_score := -1
	for zone in player2.frontline_zones:
		for creature in zone.cards:
			var score := _get_thor_mode_switch_score(creature, opposing_creatures)
			if score > best_score:
				best_score = score
				best_creature = creature
	return best_creature

func _get_thor_mode_switch_score(creature: Card, opposing_creatures: Array[Card]) -> int:
	if creature == null or creature.card_type != Card.CardType.CREATURE:
		return -1
	if creature.creature_mode != Card.CreatureMode.DEFENSIVE:
		return -1
	if not creature.can_take_minor_creature_action():
		return -1
	var score := creature.get_effective_strength() * 100 + creature.get_effective_resilience() * 10 + creature.get_effective_speed()
	if creature is Askelladen and _get_best_askelladen_target_for(creature as Askelladen, opposing_creatures) != null:
		score += 1000000
	elif opposing_creatures.is_empty():
		score += 500000
	elif creature.get_effective_strength() > _get_highest_opposing_strength_or_resilience(opposing_creatures):
		score += 400000
	return score

func _find_hand_enki() -> EnkiLordOfEridu:
	for card in player2.hand_zone.cards:
		if card is EnkiLordOfEridu:
			return card as EnkiLordOfEridu
	return null

func _find_hand_askelladen() -> Askelladen:
	for card in player2.hand_zone.cards:
		if card is Askelladen:
			return card as Askelladen
	return null

func _find_hand_divine_lightning() -> DivineLightning:
	for card in player2.hand_zone.cards:
		if card is DivineLightning:
			return card as DivineLightning
	return null

func _find_hand_fall_of_the_mighty() -> FallOfTheMighty:
	for card in player2.hand_zone.cards:
		if card is FallOfTheMighty:
			return card as FallOfTheMighty
	return null

func _find_hand_void_shield() -> VoidShield:
	for card in player2.hand_zone.cards:
		if card is VoidShield:
			return card as VoidShield
	return null

func _find_hand_unprepared_mead() -> MeadOfPoetry:
	for card in player2.hand_zone.cards:
		if card is MeadOfPoetry:
			return card as MeadOfPoetry
	return null

func _find_ready_prepared_mead() -> MeadOfPoetry:
	for zone in player2.frontline_zones + player2.reserve_zones:
		for card in zone.cards:
			if card is MeadOfPoetry and game_manager.is_prepared_charm_ready(card as MeadOfPoetry):
				return card as MeadOfPoetry
	return null

func _find_thor_call_of_the_valkyrie() -> CallOfTheValkyrie:
	if player2 == null:
		return null
	for zone in player2.power_zones:
		for card in zone.cards:
			if card is CallOfTheValkyrie:
				return card as CallOfTheValkyrie
	return null

func _pick_divine_lightning_target(opponent: Player) -> Card:
	if opponent == null:
		return null
	var best_target: Card = null
	for zone in opponent.frontline_zones + opponent.reserve_zones:
		for card in zone.cards:
			if card == null or not card.is_magical_card():
				continue
			if best_target == null or _is_divine_lightning_target_better(card, best_target):
				best_target = card
	return best_target

func _is_divine_lightning_target_better(candidate: Card, current_best: Card) -> bool:
	if current_best == null:
		return true
	if candidate.is_prepared != current_best.is_prepared:
		return candidate.is_prepared
	var candidate_speed := candidate.get_effective_speed()
	var current_speed := current_best.get_effective_speed()
	if candidate_speed != current_speed:
		return candidate_speed > current_speed
	return _get_card_order_index(candidate) < _get_card_order_index(current_best)

func _opponent_controls_strictly_strongest_creature() -> bool:
	var thor_max_strength := 0
	for creature in _get_board_creatures(player2):
		thor_max_strength = maxi(thor_max_strength, creature.get_effective_strength())
	var opponent_max_strength := 0
	for creature in _get_board_creatures(player1):
		opponent_max_strength = maxi(opponent_max_strength, creature.get_effective_strength())
	return opponent_max_strength > thor_max_strength

func _get_highest_opposing_strength_or_resilience(cards: Array[Card]) -> int:
	var threshold := 0
	for card in cards:
		threshold = maxi(threshold, maxi(card.get_effective_strength(), card.get_effective_resilience()))
	return threshold

func _get_thor_askelladen_problem_creature() -> Card:
	var best_target: Card = null
	var sample_askelladen := Askelladen.new()
	sample_askelladen.card_owner = player2
	for creature in _get_board_creatures(player1):
		if creature == null or not _can_askelladen_retreat(sample_askelladen, creature):
			continue
		if _thor_can_clear_creature_without_askelladen(creature):
			continue
		if best_target == null or _is_board_creature_better(creature, best_target):
			best_target = creature
	return best_target

func _thor_can_clear_creature_without_askelladen(target: Card) -> bool:
	if target == null or target.card_type != Card.CardType.CREATURE:
		return true
	var threshold := maxi(target.get_effective_strength(), target.get_effective_resilience())
	for creature in _get_board_creatures(player2):
		if creature == null or creature is Askelladen:
			continue
		if creature.current_zone not in player2.frontline_zones:
			continue
		if creature.is_sleeping or not creature.can_take_major_creature_action():
			continue
		if creature.creature_mode != Card.CreatureMode.AGGRESSIVE and not creature.can_take_minor_creature_action():
			continue
		if creature.get_effective_strength() > threshold:
			return true
	var summon_zone := _get_first_open_summon_zone(player2)
	if summon_zone != null:
		for card in player2.hand_zone.cards:
			if card == null or card is Askelladen:
				continue
			if not _can_thor_evaluate_creature_play(card, summon_zone, player2.mana):
				continue
			if _get_projected_strength(card) > threshold:
				return true
	var divine_lightning := _find_hand_divine_lightning()
	if divine_lightning != null and target.is_magical_card() and divine_lightning.can_activate_from_hand(game_manager):
		return true
	var fall := _find_hand_fall_of_the_mighty()
	var highest_strength := 0
	for creature in _get_board_creatures(player1) + _get_board_creatures(player2):
		highest_strength = maxi(highest_strength, creature.get_effective_strength())
	if fall != null \
		and _opponent_controls_strictly_strongest_creature() \
		and target.get_effective_strength() == highest_strength \
		and _can_afford_hand_card(fall, false):
		return true
	return false

func _should_thor_use_call_of_the_valkyrie() -> bool:
	if player2 == null:
		return false
	if _needs_thor_askelladen_support():
		return true
	return player2.hand_zone.cards.is_empty() and _choose_thor_call_of_the_valkyrie_target(_find_thor_call_of_the_valkyrie()) != null

func _needs_thor_askelladen_support() -> bool:
	if _get_thor_askelladen_problem_creature() == null:
		return false
	if _find_hand_askelladen() != null:
		return false
	for creature in _get_board_creatures(player2):
		if creature is Askelladen:
			return false
	return _find_thor_graveyard_askelladen() != null

func _choose_thor_call_of_the_valkyrie_target(call: CallOfTheValkyrie) -> Card:
	if call == null:
		return null
	var valid_targets := call.get_valid_targets(game_manager)
	if valid_targets.is_empty():
		return null
	if _needs_thor_askelladen_support():
		for target in valid_targets:
			if target is Askelladen:
				return target
	var best_target: Card = null
	for target in valid_targets:
		if best_target == null or _is_projected_creature_better(target, best_target):
			best_target = target
	return best_target

func _find_thor_graveyard_askelladen() -> Askelladen:
	if player2 == null:
		return null
	for card in player2.graveyard_zone.cards:
		if card is Askelladen:
			return card as Askelladen
	return null

func _should_thor_use_askelladen_retreat(ask_card: Askelladen, other_card: Card) -> bool:
	if ask_card == null or other_card == null:
		return false
	if other_card.get_controller() == player2:
		return false
	if not _can_askelladen_retreat(ask_card, other_card):
		return false
	return not _thor_can_clear_creature_without_askelladen(other_card)

func _get_attack_ready_thor_creatures() -> Array[Card]:
	var ready_creatures: Array[Card] = []
	if player2 == null or game_manager == null:
		return ready_creatures
	if game_manager.attack_restrictions.has(player2):
		return ready_creatures
	for zone in player2.frontline_zones:
		for card in zone.cards:
			if card == null or card.card_type != Card.CardType.CREATURE:
				continue
			if card.creature_mode != Card.CreatureMode.AGGRESSIVE:
				continue
			if card.is_sleeping or not card.get_status_effect("cannot_attack").is_empty():
				continue
			if not card.can_take_major_creature_action():
				continue
			ready_creatures.append(card)
	return ready_creatures

func _get_board_creatures(player: Player) -> Array[Card]:
	var creatures: Array[Card] = []
	if player == null:
		return creatures
	for zone in player.frontline_zones + player.reserve_zones:
		for card in zone.cards:
			if card != null and card.card_type == Card.CardType.CREATURE:
				creatures.append(card)
	return creatures

func _get_first_open_summon_zone(player: Player) -> Zone:
	if player == null:
		return null
	for zone in player.frontline_zones:
		if zone.cards.is_empty():
			return zone
	for zone in player.reserve_zones:
		if zone.cards.is_empty():
			return zone
	return null

func _get_first_open_reserve_zone(player: Player) -> Zone:
	if player == null:
		return null
	for zone in player.reserve_zones:
		if zone.cards.is_empty():
			return zone
	return null

func _get_card_order_index(card: Card) -> int:
	if card == null or card.current_zone == null:
		return 9999
	var zone := card.current_zone
	var local_index := maxi(0, zone.cards.find(card))
	match zone.zone_type:
		Zone.ZoneType.HAND:
			return local_index
		Zone.ZoneType.FRONTLINE:
			return zone.zone_index * 10 + local_index
		Zone.ZoneType.RESERVE:
			return 100 + zone.zone_index * 10 + local_index
		Zone.ZoneType.DECK:
			return 200 + local_index
		_:
			return 500 + local_index

func _get_play_cost(card: Card, prepared: bool) -> int:
	return game_manager.get_card_play_mana_cost(player2, card, prepared)

func _can_afford_hand_card(card: Card, prepared: bool) -> bool:
	var mana_cost := _get_play_cost(card, prepared)
	return card != null and card.can_pay_costs_with_mana_cost(player2, mana_cost)

func _is_thor_player(player: Player) -> bool:
	return player != null and player == player2
