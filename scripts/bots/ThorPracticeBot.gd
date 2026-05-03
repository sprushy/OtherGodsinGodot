extends RefCounted
class_name ThorPracticeBot

var game_manager: GameManager = null
var match_manager: MatchManager = null
var game_input: GameInput = null
var player_index: int = -1
var bot_player: Player = null
var opponent: Player = null

const RETRY_POLL_DELAY_SECONDS := 0.15

var _active: bool = false
var _step_queued: bool = false
var _retry_poll_queued: bool = false

func attach(
	p_game_manager: GameManager,
	p_match_manager: MatchManager,
	p_game_input: GameInput,
	p_player_index: int
) -> void:
	detach()
	game_manager = p_game_manager
	match_manager = p_match_manager
	game_input = p_game_input
	player_index = p_player_index
	if game_manager != null and player_index >= 0 and player_index < game_manager.players.size():
		bot_player = game_manager.players[player_index]
		opponent = game_manager.get_opponent(bot_player)
	_active = bot_player != null
	_connect_signals()
	poll()

func detach() -> void:
	_disconnect_signals()
	game_manager = null
	match_manager = null
	game_input = null
	player_index = -1
	bot_player = null
	opponent = null
	_active = false
	_step_queued = false
	_retry_poll_queued = false

func poll() -> void:
	_queue_step()

func _connect_signals() -> void:
	if game_manager != null:
		_connect_if_needed(game_manager.turn_upkeep_started, _on_turn_upkeep_started)
		_connect_if_needed(game_manager.turn_started, _on_turn_started)
		_connect_if_needed(game_manager.game_ended, _on_game_ended)
	if match_manager != null:
		_connect_if_needed(match_manager.move_validated, _on_match_progressed)
		_connect_if_needed(match_manager.action_resolved, _on_match_action_resolved)
		_connect_if_needed(match_manager.ui_refresh_requested, _on_match_ui_refresh_requested)
		_connect_if_needed(match_manager.request_ui_interaction, _on_match_ui_interaction)

func _disconnect_signals() -> void:
	if game_manager != null:
		_disconnect_if_needed(game_manager.turn_upkeep_started, _on_turn_upkeep_started)
		_disconnect_if_needed(game_manager.turn_started, _on_turn_started)
		_disconnect_if_needed(game_manager.game_ended, _on_game_ended)
	if match_manager != null:
		_disconnect_if_needed(match_manager.move_validated, _on_match_progressed)
		_disconnect_if_needed(match_manager.action_resolved, _on_match_action_resolved)
		_disconnect_if_needed(match_manager.ui_refresh_requested, _on_match_ui_refresh_requested)
		_disconnect_if_needed(match_manager.request_ui_interaction, _on_match_ui_interaction)

func _connect_if_needed(signal_ref: Signal, method: Callable) -> void:
	if not signal_ref.is_connected(method):
		signal_ref.connect(method)

func _disconnect_if_needed(signal_ref: Signal, method: Callable) -> void:
	if signal_ref.is_connected(method):
		signal_ref.disconnect(method)

func _on_turn_upkeep_started(_turn_number: int, player: Player) -> void:
	if player == bot_player:
		_queue_step()

func _on_turn_started(_turn_number: int, player: Player) -> void:
	if player == bot_player:
		_queue_step()

func _on_game_ended(_winner: Player, _loser: Player) -> void:
	_active = false
	_step_queued = false

func _on_match_progressed(_move: Dictionary) -> void:
	_queue_step()

func _on_match_action_resolved(_action: CardAction) -> void:
	_queue_step()

func _on_match_ui_refresh_requested() -> void:
	_queue_step()

func _on_match_ui_interaction(prompt_player_index: int, type: String, data: Dictionary) -> void:
	if prompt_player_index != player_index:
		return
	match type:
		"priority":
			_queue_step()
		"intercept":
			_submit_intercept_decision("")
		"combat_retreat":
			_handle_combat_retreat_prompt(data)
		"nusku_well_of_fire":
			_handle_nusku_well_of_fire_prompt(data)
		"resurrection":
			_submit_resurrection_choice(data, false)
		"ragnarok_discard":
			_submit_ragnarok_discard(data)
		_:
			_queue_step()

func _queue_step() -> void:
	if _step_queued:
		return
	if not _should_queue_step():
		if _should_retry_poll_later():
			_queue_retry_poll()
		return
	_step_queued = true
	call_deferred("_run_step")

func _should_retry_poll_later() -> bool:
	if not _active or game_manager == null or match_manager == null or game_input == null:
		return false
	if bot_player == null or game_manager.is_game_over:
		return false
	if game_manager.current_player == bot_player:
		return true
	return not game_manager.action_stack.is_empty() and game_manager.priority_player == bot_player

func _queue_retry_poll() -> void:
	if _retry_poll_queued:
		return
	_retry_poll_queued = true
	var tree := _get_retry_tree()
	if tree == null:
		call_deferred("_run_retry_poll")
		return
	tree.create_timer(RETRY_POLL_DELAY_SECONDS).timeout.connect(_run_retry_poll, CONNECT_ONE_SHOT)

func _run_retry_poll() -> void:
	_retry_poll_queued = false
	_queue_step()

func _get_retry_tree() -> SceneTree:
	if match_manager != null and match_manager.network_manager != null:
		return match_manager.network_manager.get_tree()
	return null

func _should_queue_step() -> bool:
	if not _active or game_manager == null or match_manager == null or game_input == null:
		return false
	if bot_player == null or opponent == null or game_manager.is_game_over:
		return false
	if match_manager.has_method("is_authoritative_stack_resolution_pending") and match_manager.is_authoritative_stack_resolution_pending():
		return false
	if match_manager.is_targeting_active():
		return false
	if match_manager.selected_attacker != null or match_manager.pending_attack_target != null:
		return false
	if not game_manager.resolving_stack_actions.is_empty():
		return false
	if not game_manager.action_stack.is_empty():
		return game_manager.priority_player == bot_player
	return game_manager.current_player == bot_player

func _run_step() -> void:
	_step_queued = false
	if not _should_queue_step():
		return
	if not game_manager.action_stack.is_empty():
		_handle_priority()
		return
	if game_manager.current_player != bot_player:
		return
	if not game_manager.has_resolved_turn_upkeep():
		_handle_upkeep()
		return
	if _take_main_phase_action():
		return
	_finish_turn()

func _handle_upkeep() -> void:
	_submit_action({
		"type": "upkeep_choice",
		"choice": _choose_upkeep_option(),
	})

func _choose_upkeep_option() -> String:
	var draw_mana_gain := GameManager.UPKEEP_DRAW_MANA_GAIN
	var mana_gain := GameManager.UPKEEP_MANA_GAIN
	if game_manager != null:
		draw_mana_gain = game_manager.get_base_upkeep_draw_mana_gain()
		mana_gain = game_manager.get_base_upkeep_mana_gain()
	var best_now := _get_best_affordable_hand_creature(draw_mana_gain)
	var best_with_bonus := _get_best_affordable_hand_creature(mana_gain)
	if best_with_bonus != null and _is_projected_creature_better(best_with_bonus, best_now):
		return "mana"
	if best_now == null and best_with_bonus != null:
		return "mana"
	return "draw"

func _handle_priority() -> void:
	if game_manager.priority_player != bot_player:
		return
	var chosen_response := _choose_priority_response()
	if chosen_response != null and _submit_priority_response(chosen_response):
		return
	_submit_action({"type": "priority_pass"})

func _choose_priority_response() -> Card:
	var responses := game_manager.get_priority_responses(bot_player)
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

func _submit_priority_response(card: Card) -> bool:
	if card == null or game_manager.action_stack.is_empty():
		return false
	var top_action: CardAction = game_manager.action_stack.back()
	if card is HexCard:
		var targets := game_manager.get_priority_hex_targets(card as HexCard, top_action)
		var target_uid := _first_target_uid(targets)
		if bool(card.get("targets")) and target_uid.is_empty():
			return false
		return _submit_action({
			"type": "play_hex_response",
			"hex_uid": card.uid,
			"target_uid": target_uid,
		})
	if card is CharmCard:
		var charm := card as CharmCard
		var targets := charm.get_priority_targets(game_manager, top_action) if charm.targets else []
		var target_uid := _first_target_uid(targets)
		if charm.targets and target_uid.is_empty():
			return false
		return _submit_action({
			"type": "play_charm_response",
			"charm_uid": charm.uid,
			"from_hand": charm.current_zone == bot_player.hand_zone,
			"target_uid": target_uid,
		})
	if card.has_method("can_respond_to_priority_action") and card.has_method("activate"):
		var targets: Array = []
		if card.has_method("get_priority_field_targets"):
			targets = card.get_priority_field_targets(game_manager, top_action)
		elif card.has_method("get_valid_targets"):
			targets = card.get_valid_targets(game_manager)
		var target_uid := _first_target_uid(targets)
		if bool(card.get("targets")) and target_uid.is_empty():
			return false
		return _submit_action({
			"type": "play_priority_ability",
			"source_uid": card.uid,
			"target_uid": target_uid,
		})
	return false

func _take_main_phase_action() -> bool:
	if _try_activate_mead_for_enki():
		return true
	if _try_summon_askelladen_answer():
		return true
	if _try_summon_best_creature():
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
	if _try_switch_to_aggressive_mode():
		return true
	if _try_attack():
		return true
	return false

func _try_activate_mead_for_enki() -> bool:
	var mead := _find_ready_prepared_mead()
	if mead == null or not _should_activate_prepared_mead_for_enki():
		return false
	return _submit_cast_charm(mead, null, true)

func _should_activate_prepared_mead_for_enki() -> bool:
	if game_manager == null or game_manager.current_player != bot_player:
		return false
	if bot_player.has_summoned_this_turn:
		return false
	var enki := _find_hand_enki()
	var mead := _find_ready_prepared_mead()
	if enki == null or mead == null:
		return false
	var mana_cost := _get_play_cost(enki, false)
	if not enki.can_pay_costs_with_mana_cost(bot_player, mana_cost):
		return false
	return bot_player.mana < mana_cost and bot_player.mana + MeadOfPoetry.MANA_GAIN >= mana_cost

func _try_summon_best_creature() -> bool:
	if game_manager == null or bot_player.has_summoned_this_turn:
		return false
	var zone := _get_first_open_summon_zone(bot_player)
	if zone == null:
		return false
	var creature := _get_best_affordable_hand_creature(0, zone)
	if creature == null:
		return false
	return _submit_play_creature(creature, zone, Card.CreatureMode.AGGRESSIVE)

func _try_summon_askelladen_answer() -> bool:
	if game_manager == null or bot_player.has_summoned_this_turn:
		return false
	var askelladen := _find_hand_askelladen()
	if askelladen == null:
		return false
	var zone := _get_first_open_summon_zone(bot_player)
	if zone == null:
		return false
	var target := _get_askelladen_problem_creature()
	if target == null:
		return false
	if not _can_evaluate_creature_play(askelladen, zone, bot_player.mana):
		return false
	return _submit_play_creature(askelladen, zone, Card.CreatureMode.AGGRESSIVE)

func _try_cast_divine_lightning() -> bool:
	var divine_lightning := _find_hand_divine_lightning()
	if divine_lightning == null:
		return false
	var target := _pick_divine_lightning_target(opponent)
	if target == null:
		return false
	if not divine_lightning.can_activate_from_hand(game_manager):
		return false
	return _submit_cast_charm(divine_lightning, target, false)

func _try_cast_fall_of_the_mighty() -> bool:
	var fall := _find_hand_fall_of_the_mighty()
	if fall == null or not _opponent_controls_strictly_strongest_creature():
		return false
	if not _can_afford_hand_card(fall, false):
		return false
	return _submit_action({
		"type": "cast_spell",
		"spell_uid": fall.uid,
		"target_uid": "",
	})

func _try_prepare_void_shield() -> bool:
	var void_shield := _find_hand_void_shield()
	if void_shield == null:
		return false
	var zone := _get_first_open_reserve_zone(bot_player)
	if zone == null:
		return false
	return _submit_prepare_card(void_shield, zone)

func _try_prepare_mead_of_poetry() -> bool:
	var mead := _find_hand_unprepared_mead()
	if mead == null:
		return false
	var zone := _get_first_open_reserve_zone(bot_player)
	if zone == null:
		return false
	return _submit_prepare_card(mead, zone)

func _try_unlock_call_of_the_valkyrie() -> bool:
	var call := _find_call_of_the_valkyrie()
	if call == null or not call.is_face_down:
		return false
	if not _should_use_call_of_the_valkyrie():
		return false
	return _submit_action({
		"type": "unlock_power",
		"power_uid": call.uid,
	})

func _try_activate_call_of_the_valkyrie() -> bool:
	var call := _find_call_of_the_valkyrie()
	if call == null or call.is_face_down:
		return false
	if not _should_use_call_of_the_valkyrie():
		return false
	var target := _choose_call_of_the_valkyrie_target(call)
	if target == null or not call.can_activate(game_manager):
		return false
	return _submit_action({
		"type": "activate_power",
		"power_uid": call.uid,
		"target_uid": target.uid,
	})

func _try_switch_to_aggressive_mode() -> bool:
	var creature := _get_best_mode_switch_candidate()
	if creature == null:
		return false
	return _submit_action({
		"type": "change_mode",
		"card_uid": creature.uid,
		"mode": Card.CreatureMode.AGGRESSIVE,
	})

func _try_attack() -> bool:
	var attackers := _get_attack_ready_creatures()
	if attackers.is_empty():
		return false
	var opposing_creatures := _get_board_creatures(opponent)
	if _can_kill_with_all_attackers(attackers):
		var direct_attacker := _pick_best_board_creature(attackers)
		return _submit_attack(direct_attacker, opponent)
	if opposing_creatures.is_empty():
		var direct_attacker := _pick_best_board_creature(attackers)
		return _submit_attack(direct_attacker, opponent)
	var askelladen_attack := _get_best_askelladen_attack(attackers, opposing_creatures)
	if not askelladen_attack.is_empty():
		return _submit_attack(askelladen_attack.get("attacker", null), askelladen_attack.get("target", null))
	var standard_attack := _get_best_standard_attack(attackers, opposing_creatures)
	if not standard_attack.is_empty():
		return _submit_attack(standard_attack.get("attacker", null), standard_attack.get("target", null))
	var stealth_attack := _get_best_stealth_attack(attackers, opposing_creatures)
	if not stealth_attack.is_empty():
		return _submit_attack(stealth_attack.get("attacker", null), stealth_attack.get("target", null))
	return false

func _finish_turn() -> void:
	var discard_uids := _get_end_turn_discard_uids()
	_submit_action({
		"type": "end_turn",
		"discard_uids": discard_uids,
	})

func _get_end_turn_discard_uids() -> Array[String]:
	var discard_uids: Array[String] = []
	var virtual_hand := bot_player.hand_zone.cards.duplicate()
	while virtual_hand.size() - discard_uids.size() > Player.MAX_HAND_SIZE:
		var discard_card := _choose_lowest_priority_card(virtual_hand, discard_uids)
		if discard_card == null:
			break
		discard_uids.append(discard_card.uid)
	return discard_uids

func _choose_lowest_priority_card(cards: Array, already_chosen_uids: Array[String]) -> Card:
	var discard_choice: Card = null
	for card in cards:
		if card == null or card.uid in already_chosen_uids:
			continue
		if discard_choice == null or _is_lower_priority_hand_card(card, discard_choice):
			discard_choice = card
	return discard_choice

func _is_lower_priority_hand_card(candidate: Card, current_choice: Card) -> bool:
	if current_choice == null:
		return true
	var candidate_value := _get_hand_value(candidate)
	var current_value := _get_hand_value(current_choice)
	if candidate_value != current_value:
		return candidate_value < current_value
	return _get_card_order_index(candidate) < _get_card_order_index(current_choice)

func _get_hand_value(card: Card) -> int:
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

func _handle_combat_retreat_prompt(data: Dictionary) -> void:
	var askelladen := game_manager.get_card_by_uid(str(data.get("askelladen_uid", ""))) as Askelladen
	var action := data.get("action", null) as CardAction
	var target = data.get("target", null)
	var other_card: Card = null
	if askelladen != null and action != null and target != null:
		other_card = action.attacker if action.attacker != askelladen else (target as Card)
	var use_retreat := _should_use_askelladen_retreat(askelladen, other_card)
	_submit_action({
		"type": "combat_retreat_decision",
		"askelladen_uid": askelladen.uid if askelladen != null else "",
		"retreat": use_retreat,
	})

func _handle_nusku_well_of_fire_prompt(data: Dictionary) -> void:
	var nusku := game_manager.get_card_by_uid(str(data.get("source_uid", ""))) as NuskuFirebearer
	if nusku == null:
		return
	var choices: Array[Card] = []
	for target_uid in data.get("target_uids", []):
		var choice := game_manager.get_card_by_uid(str(target_uid))
		if choice != null:
			choices.append(choice)
	var chosen_card := nusku.choose_opponent_pick(choices)
	_submit_action({
		"type": "nusku_well_of_fire_choice",
		"source_uid": nusku.uid,
		"target_uid": chosen_card.uid if chosen_card != null else "",
		"mill_count": int(data.get("mill_count", NuskuFirebearer.MILL_COUNT)),
	})

func _submit_resurrection_choice(data: Dictionary, confirm: bool) -> void:
	var card_uid := str(data.get("card_uid", "")).strip_edges()
	if card_uid.is_empty():
		return
	_submit_action({
		"type": "resurrection_choice",
		"card_uid": card_uid,
		"confirm": confirm,
	})

func _submit_ragnarok_discard(data: Dictionary) -> void:
	var target_uids: Array = data.get("target_uids", [])
	if target_uids.is_empty():
		return
	var chosen_uid := str(target_uids[0])
	var chosen_card := game_manager.get_card_by_uid(chosen_uid)
	for raw_uid in target_uids:
		var candidate := game_manager.get_card_by_uid(str(raw_uid))
		if candidate != null and _is_lower_priority_hand_card(candidate, chosen_card):
			chosen_card = candidate
	if chosen_card == null:
		return
	_submit_action({
		"type": "ragnarok_discard_choice",
		"source_uid": str(data.get("source_uid", "")),
		"target_uid": chosen_card.uid,
	})

func _submit_intercept_decision(interceptor_uid: String) -> bool:
	return _submit_action({
		"type": "intercept_decision",
		"interceptor_uid": interceptor_uid,
	})

func _submit_prepare_card(card: Card, zone: Zone) -> bool:
	if card == null or zone == null or game_manager == null:
		return false
	if not game_manager.can_prepare_card(bot_player, card, zone):
		return false
	return _submit_action({
		"type": "prepare_card",
		"card_uid": card.uid,
		"player_index": game_manager.players.find(zone.zone_owner),
		"zone_type": zone.zone_type,
		"zone_index": zone.zone_index,
	})

func _submit_play_creature(card: Card, zone: Zone, mode: Card.CreatureMode) -> bool:
	if card == null or zone == null:
		return false
	return _submit_action({
		"type": "play_creature",
		"card_uid": card.uid,
		"player_index": game_manager.players.find(zone.zone_owner),
		"zone_type": zone.zone_type,
		"zone_index": zone.zone_index,
		"mode": mode,
		"stealth": false,
		"sacrifice_uids": [],
		"altar_void_uids": [],
	})

func _submit_cast_charm(charm: CharmCard, target: Card = null, prepared: bool = false) -> bool:
	if charm == null:
		return false
	return _submit_action({
		"type": "cast_charm",
		"charm_uid": charm.uid,
		"target_uid": target.uid if target != null else "",
		"prepared": prepared,
	})

func _submit_attack(attacker: Card, target) -> bool:
	if attacker == null or target == null:
		return false
	var target_id := ""
	if target is Player:
		target_id = str(game_manager.players.find(target))
	elif target is Card:
		target_id = target.uid
	return _submit_action({
		"type": "request_attack",
		"attacker_uid": attacker.uid,
		"target_id": target_id,
	})

func _submit_action(command: Dictionary) -> bool:
	if game_input == null:
		return false
	return game_input.submit_action(command)

func _first_target_uid(targets: Array) -> String:
	for target in targets:
		if target is Card:
			return (target as Card).uid
	return ""

func _get_best_affordable_hand_creature(extra_mana: int, preferred_zone: Zone = null) -> Card:
	if bot_player == null or game_manager == null:
		return null
	var zone := preferred_zone if preferred_zone != null else _get_first_open_summon_zone(bot_player)
	if zone == null:
		return null
	var best_creature: Card = null
	var available_mana := bot_player.mana + extra_mana
	for card in bot_player.hand_zone.cards:
		if not _can_evaluate_creature_play(card, zone, available_mana):
			continue
		if _is_projected_creature_better(card, best_creature):
			best_creature = card
	return best_creature

func _can_evaluate_creature_play(card: Card, zone: Zone, available_mana: int) -> bool:
	if card == null or zone == null or bot_player == null:
		return false
	if card.card_type != Card.CardType.CREATURE or card.current_zone != bot_player.hand_zone:
		return false
	if zone.zone_owner != bot_player or not zone.cards.is_empty():
		return false
	var mana_cost := _get_play_cost(card, false)
	if available_mana < mana_cost:
		return false
	return card.can_pay_costs_with_mana_cost(bot_player, mana_cost)

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

func _get_best_askelladen_attack(attackers: Array[Card], opposing_creatures: Array[Card]) -> Dictionary:
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
		if not _can_attack_creature(askelladen, creature):
			continue
		if not _should_use_askelladen_retreat(askelladen, creature):
			continue
		if best_target == null or _is_board_creature_better(creature, best_target):
			best_target = creature
	return best_target

func _get_best_standard_attack(attackers: Array[Card], opposing_creatures: Array[Card]) -> Dictionary:
	var best_attack := {}
	for attacker in attackers:
		for target in opposing_creatures:
			if not _can_attack_creature(attacker, target):
				continue
			var target_threshold := maxi(target.get_effective_strength(), target.get_effective_resilience())
			if attacker.get_effective_strength() <= target_threshold:
				continue
			if best_attack.is_empty():
				best_attack = {"attacker": attacker, "target": target}
				continue
			var current_attacker: Card = best_attack.get("attacker", null)
			var current_target: Card = best_attack.get("target", null)
			if _is_attack_plan_better(attacker, target, current_attacker, current_target):
				best_attack = {"attacker": attacker, "target": target}
	return best_attack

func _is_attack_plan_better(candidate_attacker: Card, candidate_target: Card, current_attacker: Card, current_target: Card) -> bool:
	if current_target == null:
		return true
	if _is_board_creature_better(candidate_target, current_target):
		return true
	if _is_board_creature_better(current_target, candidate_target):
		return false
	return _is_board_creature_better(candidate_attacker, current_attacker)

func _can_attack_creature(attacker: Card, target: Card) -> bool:
	return attacker != null \
		and target != null \
		and game_manager != null \
		and attacker.current_zone != null \
		and attacker.current_zone.is_board_zone() \
		and target.current_zone != null \
		and target.current_zone.is_board_zone() \
		and game_manager.can_cards_engage_each_other(attacker, target)

func _can_kill_with_all_attackers(attackers: Array[Card]) -> bool:
	if opponent == null:
		return false
	var total_str := 0
	for attacker in attackers:
		total_str += attacker.get_effective_strength()
	return total_str >= opponent.followers

func _get_best_stealth_attack(attackers: Array[Card], opposing_creatures: Array[Card]) -> Dictionary:
	var best_attacker: Card = null
	var best_target: Card = null
	for target in opposing_creatures:
		if target == null or not (target.is_stealth or target.is_face_down):
			continue
		for attacker in attackers:
			if not _can_attack_creature(attacker, target):
				continue
			if best_attacker == null or _is_board_creature_better(attacker, best_attacker):
				best_attacker = attacker
				best_target = target
	if best_attacker == null:
		return {}
	return {"attacker": best_attacker, "target": best_target}

func _get_best_mode_switch_candidate() -> Card:
	if bot_player == null or game_manager == null:
		return null
	var opposing_creatures := _get_board_creatures(opponent)
	var best_creature: Card = null
	var best_score := -1
	for zone in bot_player.frontline_zones:
		for creature in zone.cards:
			var score := _get_mode_switch_score(creature, opposing_creatures)
			if score > best_score:
				best_score = score
				best_creature = creature
	return best_creature

func _get_mode_switch_score(creature: Card, opposing_creatures: Array[Card]) -> int:
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
	for card in bot_player.hand_zone.cards:
		if card is EnkiLordOfEridu:
			return card as EnkiLordOfEridu
	return null

func _find_hand_askelladen() -> Askelladen:
	for card in bot_player.hand_zone.cards:
		if card is Askelladen:
			return card as Askelladen
	return null

func _find_hand_divine_lightning() -> DivineLightning:
	for card in bot_player.hand_zone.cards:
		if card is DivineLightning:
			return card as DivineLightning
	return null

func _find_hand_fall_of_the_mighty() -> FallOfTheMighty:
	for card in bot_player.hand_zone.cards:
		if card is FallOfTheMighty:
			return card as FallOfTheMighty
	return null

func _find_hand_void_shield() -> VoidShield:
	for card in bot_player.hand_zone.cards:
		if card is VoidShield:
			return card as VoidShield
	return null

func _find_hand_unprepared_mead() -> MeadOfPoetry:
	for card in bot_player.hand_zone.cards:
		if card is MeadOfPoetry:
			return card as MeadOfPoetry
	return null

func _find_ready_prepared_mead() -> MeadOfPoetry:
	for zone in bot_player.frontline_zones + bot_player.reserve_zones:
		for card in zone.cards:
			if card is MeadOfPoetry and game_manager.is_prepared_charm_ready(card as MeadOfPoetry):
				return card as MeadOfPoetry
	return null

func _find_call_of_the_valkyrie() -> CallOfTheValkyrie:
	if bot_player == null:
		return null
	for zone in bot_player.power_zones:
		for card in zone.cards:
			if card is CallOfTheValkyrie:
				return card as CallOfTheValkyrie
	return null

func _pick_divine_lightning_target(target_player: Player) -> Card:
	if target_player == null:
		return null
	var best_target: Card = null
	for zone in target_player.frontline_zones + target_player.reserve_zones:
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
	var bot_max_strength := -1
	for creature in _get_board_creatures(bot_player):
		if not FallOfTheMighty.counts_for_strength_check(creature):
			continue
		bot_max_strength = maxi(bot_max_strength, creature.get_effective_strength())
	var opponent_max_strength := -1
	for creature in _get_board_creatures(opponent):
		if not FallOfTheMighty.counts_for_strength_check(creature):
			continue
		opponent_max_strength = maxi(opponent_max_strength, creature.get_effective_strength())
	return opponent_max_strength >= 0 and opponent_max_strength > bot_max_strength

func _get_highest_opposing_strength_or_resilience(cards: Array[Card]) -> int:
	var threshold := 0
	for card in cards:
		threshold = maxi(threshold, maxi(card.get_effective_strength(), card.get_effective_resilience()))
	return threshold

func _get_askelladen_problem_creature() -> Card:
	var best_target: Card = null
	var sample_askelladen := Askelladen.new()
	sample_askelladen.card_owner = bot_player
	for creature in _get_board_creatures(opponent):
		if creature == null or not _can_askelladen_retreat(sample_askelladen, creature):
			continue
		if _can_clear_creature_without_askelladen(creature):
			continue
		if best_target == null or _is_board_creature_better(creature, best_target):
			best_target = creature
	return best_target

func _can_clear_creature_without_askelladen(target: Card) -> bool:
	if target == null or target.card_type != Card.CardType.CREATURE:
		return true
	var threshold := maxi(target.get_effective_strength(), target.get_effective_resilience())
	for creature in _get_board_creatures(bot_player):
		if creature == null or creature is Askelladen:
			continue
		if creature.current_zone not in bot_player.frontline_zones:
			continue
		if creature.is_sleeping or not creature.can_take_major_creature_action():
			continue
		if creature.creature_mode != Card.CreatureMode.AGGRESSIVE and not creature.can_take_minor_creature_action():
			continue
		if creature.get_effective_strength() > threshold:
			return true
	var summon_zone := _get_first_open_summon_zone(bot_player)
	if summon_zone != null:
		for card in bot_player.hand_zone.cards:
			if card == null or card is Askelladen:
				continue
			if not _can_evaluate_creature_play(card, summon_zone, bot_player.mana):
				continue
			if _get_projected_strength(card) > threshold:
				return true
	var divine_lightning := _find_hand_divine_lightning()
	if divine_lightning != null and target.is_magical_card() and divine_lightning.can_activate_from_hand(game_manager):
		return true
	var fall := _find_hand_fall_of_the_mighty()
	var strongest_creatures := FallOfTheMighty.get_strongest_creatures(game_manager)
	if fall != null \
		and FallOfTheMighty.counts_for_strength_check(target) \
		and _opponent_controls_strictly_strongest_creature() \
		and strongest_creatures.has(target) \
		and _can_afford_hand_card(fall, false):
		return true
	return false

func _should_use_call_of_the_valkyrie() -> bool:
	if bot_player == null:
		return false
	if _needs_askelladen_support():
		return true
	return bot_player.hand_zone.cards.is_empty() and _choose_call_of_the_valkyrie_target(_find_call_of_the_valkyrie()) != null

func _needs_askelladen_support() -> bool:
	if _get_askelladen_problem_creature() == null:
		return false
	if _find_hand_askelladen() != null:
		return false
	for creature in _get_board_creatures(bot_player):
		if creature is Askelladen:
			return false
	return _find_graveyard_askelladen() != null

func _choose_call_of_the_valkyrie_target(call: CallOfTheValkyrie) -> Card:
	if call == null:
		return null
	var valid_targets := call.get_valid_targets(game_manager)
	if valid_targets.is_empty():
		return null
	if _needs_askelladen_support():
		for target in valid_targets:
			if target is Askelladen:
				return target
	var best_target: Card = null
	for target in valid_targets:
		if best_target == null or _is_projected_creature_better(target, best_target):
			best_target = target
	return best_target

func _find_graveyard_askelladen() -> Askelladen:
	if bot_player == null:
		return null
	for card in bot_player.graveyard_zone.cards:
		if card is Askelladen:
			return card as Askelladen
	return null

func _should_use_askelladen_retreat(ask_card: Askelladen, other_card: Card) -> bool:
	if ask_card == null or other_card == null:
		return false
	if other_card.get_controller() == bot_player:
		return false
	if not _can_askelladen_retreat(ask_card, other_card):
		return false
	return not _can_clear_creature_without_askelladen(other_card)

func _can_askelladen_retreat(ask_card: Askelladen, other_card: Card) -> bool:
	if ask_card == null or other_card == null:
		return false
	if ask_card.is_face_down or ask_card.abilities_suppressed():
		return false
	if game_manager == null:
		return false
	if game_manager.is_immune_to_source(other_card, ask_card):
		return false
	if other_card.get_effective_speed() > ask_card.get_effective_speed():
		return false
	if game_manager.is_guardian_protected(other_card, ask_card):
		return false
	return true

func _get_attack_ready_creatures() -> Array[Card]:
	var ready_creatures: Array[Card] = []
	if bot_player == null or game_manager == null:
		return ready_creatures
	if game_manager.attack_restrictions.has(bot_player):
		return ready_creatures
	for zone in bot_player.frontline_zones:
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
	return game_manager.get_card_play_mana_cost(bot_player, card, prepared)

func _can_afford_hand_card(card: Card, prepared: bool) -> bool:
	var mana_cost := _get_play_cost(card, prepared)
	return card != null and card.can_pay_costs_with_mana_cost(bot_player, mana_cost)
