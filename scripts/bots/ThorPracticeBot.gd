extends RefCounted
class_name ThorPracticeBot

var game_manager: GameManager = null
var match_manager: MatchManager = null
var game_input: GameInput = null
var player_index: int = -1
var bot_player: Player = null
var opponent: Player = null

const STEP_DELAY_SECONDS := 0.35
const RETRY_POLL_DELAY_SECONDS := 0.15
const CALL_VALKYRIE_DESPERATION_TARGET_SCORE := 3000
const CALL_VALKYRIE_DEFAULT_TARGET_SCORE := 3600
const CALL_VALKYRIE_PREMIUM_TARGET_SCORE := 3900
const CALL_VALKYRIE_LOW_HAND_LIMIT := 2
const CALL_VALKYRIE_SMALL_UPGRADE_MARGIN := 200
const CALL_VALKYRIE_LARGE_UPGRADE_MARGIN := 500
const ECON_CARD_VALUE := 5000
const ECON_MANA_VALUE := 1000
const ECON_FOLLOWERS_PER_CARD := 25
const ASKELLADEN_BOUNCE_TARGET_SCORE := 1800
const ASKELLADEN_RETREAT_SCORE_MARGIN := 400

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
		"harii_jarl_impact":
			_handle_harii_jarl_impact_prompt(data)
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
	var tree := _get_retry_tree()
	if tree == null:
		call_deferred("_run_step")
		return
	tree.create_timer(STEP_DELAY_SECONDS).timeout.connect(_run_step, CONNECT_ONE_SHOT)

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
	return Engine.get_main_loop() as SceneTree

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
		_queue_retry_poll()
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

func _find_player_god() -> GodCard:
	if bot_player == null or bot_player.god_zone == null or bot_player.god_zone.cards.is_empty():
		return null
	return bot_player.god_zone.cards[0] as GodCard

func _choose_priority_response() -> Card:
	var responses := game_manager.get_priority_responses(bot_player)
	var top_action: CardAction = game_manager.action_stack.back() if not game_manager.action_stack.is_empty() else null
	if top_action != null:
		for response_card in responses:
			if response_card is MeadOfPoetry and top_action.target == response_card:
				return response_card
		var best_vision := _find_best_priority_vision_response(responses, top_action)
		if not best_vision.is_empty():
			return best_vision.get("card", null)
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
		var target_uid := ""
		if card is VisionOfOdin:
			var chosen_target := _choose_best_priority_vision_target(card as VisionOfOdin, top_action, targets)
			target_uid = chosen_target.uid if chosen_target != null else ""
		else:
			target_uid = _choose_target_uid_for_source(card, targets)
		if bool(card.get("targets")) and target_uid.is_empty():
			return false
		return _submit_action({
			"type": "play_hex_response",
			"hex_uid": card.uid,
			"target_uid": target_uid,
		})
	if card is CharmCard:
		var charm := card as CharmCard
		var targets: Array[Card] = []
		if charm.targets:
			targets = charm.get_priority_targets(game_manager, top_action)
		var target_uid := _choose_target_uid_for_source(card, targets)
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
		var target_uid := _choose_target_uid_for_source(card, targets)
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
	if _try_activate_best_god_ability():
		return true
	if _try_summon_askelladen_answer():
		return true
	if _try_unlock_best_power():
		return true
	if _try_activate_best_power():
		return true
	if _try_summon_best_creature():
		return true
	if _try_cast_divine_lightning():
		return true
	if _try_cast_fall_of_the_mighty():
		return true
	if _try_prepare_vision_of_odin():
		return true
	if _try_prepare_void_shield():
		return true
	if _try_prepare_mead_of_poetry():
		return true
	if _try_switch_to_aggressive_mode():
		return true
	if _try_attack():
		return true
	if _try_switch_to_defensive_mode():
		return true
	return false

func _try_activate_mead_for_enki() -> bool:
	var mead := _find_ready_prepared_mead()
	if mead == null or not _should_activate_prepared_mead_for_enki():
		return false
	return _submit_cast_charm(mead, null, true)

func _try_activate_best_god_ability() -> bool:
	var god := _find_player_god()
	if god == null or not god.has_method("can_activate") or not god.can_activate(game_manager):
		return false

	if god is GuanYu:
		var guan_yu := god as GuanYu
		if guan_yu.has_method("_can_use_tactical_break") and bool(guan_yu.call("_can_use_tactical_break", game_manager)):
			var tactical_target := _choose_best_enemy_target_for_source(guan_yu, guan_yu.get_valid_targets(game_manager))
			if tactical_target != null:
				return _submit_action({
					"type": "god_ability",
					"god_uid": guan_yu.uid,
					"target_uid": tactical_target.uid,
				})
	if god is Freyja:
		var freyja := god as Freyja
		var revived_target := _choose_best_friendly_graveyard_target_for_source(freyja, freyja.get_valid_targets(game_manager))
		if revived_target != null:
			return _submit_action({
				"type": "god_ability",
				"god_uid": freyja.uid,
				"target_uid": revived_target.uid,
			})
	if god is Hermes:
		var hermes := god as Hermes
		var speed_target := _choose_best_friendly_board_target_for_source(hermes, hermes.get_valid_targets(game_manager))
		if speed_target != null and _score_friendly_target(speed_target) >= 2400:
			return _submit_action({
				"type": "god_ability",
				"god_uid": hermes.uid,
				"target_uid": speed_target.uid,
			})
	if god is DellingrTheDayspring:
		var dellingr := god as DellingrTheDayspring
		var reveal_target := _choose_best_enemy_target_for_source(dellingr, dellingr.get_valid_targets(game_manager))
		if reveal_target != null:
			return _submit_action({
				"type": "god_ability",
				"god_uid": dellingr.uid,
				"target_uid": reveal_target.uid,
			})
	if god is AphroditeAreia:
		var aphrodite := god as AphroditeAreia
		var enthrall_target := _choose_best_enemy_target_for_source(aphrodite, aphrodite.get_valid_targets(game_manager))
		if enthrall_target != null:
			return _submit_action({
				"type": "god_ability",
				"god_uid": aphrodite.uid,
				"target_uid": enthrall_target.uid,
			})

	var champions_call_score := _score_champions_call_activation(god)
	if champions_call_score >= 2200:
		var summon_zone := _get_first_open_summon_zone(bot_player)
		var manifestation := god.get_champions_call_candidate(true)
		var summon_mode := _choose_creature_summon_mode(manifestation)
		return _submit_action({
			"type": "god_ability",
			"god_uid": god.uid,
			"zone_type": summon_zone.zone_type if summon_zone != null else -1,
			"zone_index": summon_zone.zone_index if summon_zone != null else -1,
			"mode": "aggressive" if summon_mode == Card.CreatureMode.AGGRESSIVE else "defensive",
			"shelve_uids": [],
		})
	return false

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
	return _submit_play_creature(creature, zone, _choose_creature_summon_mode(creature))

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

func _try_prepare_vision_of_odin() -> bool:
	var vision := _find_hand_unprepared_vision_of_odin()
	if vision == null:
		return false
	var zone := _get_first_open_reserve_zone(bot_player)
	if zone == null:
		return false
	return _submit_prepare_card(vision, zone)

func _try_prepare_mead_of_poetry() -> bool:
	var mead := _find_hand_unprepared_mead()
	if mead == null:
		return false
	var zone := _get_first_open_reserve_zone(bot_player)
	if zone == null:
		return false
	return _submit_prepare_card(mead, zone)

func _try_unlock_best_power() -> bool:
	var best_power: PowerCard = null
	var best_score := -1000000
	for power in _get_player_powers():
		if power == null or not power.is_face_down or not power.can_unlock(game_manager):
			continue
		if not _can_use_generic_power_command(power):
			continue
		var score := _score_power_unlock(power)
		if score > best_score:
			best_score = score
			best_power = power
	if best_power == null or best_score < 900:
		return false
	return _submit_action({
		"type": "unlock_power",
		"power_uid": best_power.uid,
	})

func _try_activate_best_power() -> bool:
	var best_power: PowerCard = null
	var best_target: Card = null
	var best_score := -1000000
	for power in _get_player_powers():
		if power == null or power.is_face_down or not power.can_activate(game_manager):
			continue
		if not _can_use_generic_power_command(power):
			continue
		var chosen_target: Card = null
		if power.has_method("get_valid_targets"):
			chosen_target = _choose_best_target_for_source(power, power.get_valid_targets(game_manager))
		var score := _score_power_activation(power, chosen_target)
		if score > best_score:
			best_score = score
			best_power = power
			best_target = chosen_target
	if best_power == null or best_score < 1200:
		return false
	var command := {
		"type": "activate_power",
		"power_uid": best_power.uid,
	}
	if best_target != null:
		command["target_uid"] = best_target.uid
	return _submit_action(command)

func _try_switch_to_aggressive_mode() -> bool:
	var creature := _get_best_mode_switch_candidate()
	if creature == null:
		return false
	return _submit_action({
		"type": "change_mode",
		"card_uid": creature.uid,
		"mode": Card.CreatureMode.AGGRESSIVE,
	})

func _try_switch_to_defensive_mode() -> bool:
	var creature := _get_best_defensive_mode_switch_candidate()
	if creature == null:
		return false
	return _submit_action({
		"type": "change_mode",
		"card_uid": creature.uid,
		"mode": Card.CreatureMode.DEFENSIVE,
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
	var safe_followers_attack := _get_best_safe_followers_attack(attackers)
	if not safe_followers_attack.is_empty():
		return _submit_attack(safe_followers_attack.get("attacker", null), opponent)
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
	if card is VisionOfOdin:
		return 85
	if card is DivineLightning:
		return 80
	if card is Askelladen:
		return 78
	if card is HariiJarl:
		return 72
	if card is FallOfTheMighty:
		return 70
	if card is VoidShield:
		return 60
	if card is HariiFransiscan:
		return 58
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
	var use_retreat := _should_use_askelladen_retreat(askelladen, other_card, action)
	_submit_action({
		"type": "combat_retreat_decision",
		"askelladen_uid": askelladen.uid if askelladen != null else "",
		"retreat": use_retreat,
	})

func _handle_harii_jarl_impact_prompt(data: Dictionary) -> void:
	var jarl := game_manager.get_card_by_uid(str(data.get("source_uid", ""))) as HariiJarl
	if jarl == null:
		return
	var prompt_targets: Array[Card] = []
	for target_uid in data.get("target_uids", []):
		var target := game_manager.get_card_by_uid(str(target_uid))
		if target != null:
			prompt_targets.append(target)
	var chosen_cards := _choose_harii_jarl_warband_targets(jarl, prompt_targets)
	var chosen_uids: Array[String] = []
	for chosen_card in chosen_cards:
		if chosen_card != null:
			chosen_uids.append(chosen_card.uid)
	_submit_action({
		"type": "harii_jarl_impact_choice",
		"source_uid": jarl.uid,
		"chosen_uids": chosen_uids,
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
	var payment_plan := _build_creature_summon_payment_plan(card, bot_player.mana)
	if not bool(payment_plan.get("ok", false)):
		return false
	return _submit_action({
		"type": "play_creature",
		"card_uid": card.uid,
		"player_index": game_manager.players.find(zone.zone_owner),
		"zone_type": zone.zone_type,
		"zone_index": zone.zone_index,
		"mode": mode,
		"stealth": false,
		"sacrifice_uids": payment_plan.get("sacrifice_uids", []),
		"altar_void_uids": payment_plan.get("altar_void_uids", []),
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
	var best_score := -1000000
	var available_mana := bot_player.mana + extra_mana
	for card in bot_player.hand_zone.cards:
		var play_score := _score_creature_play(card, zone, available_mana)
		if play_score <= -1000000:
			continue
		if best_creature == null or play_score > best_score or (play_score == best_score and _is_projected_creature_better(card, best_creature)):
			best_creature = card
			best_score = play_score
	return best_creature

func _can_evaluate_creature_play(card: Card, zone: Zone, available_mana: int) -> bool:
	if card == null or zone == null or bot_player == null:
		return false
	if card.card_type != Card.CardType.CREATURE or card.current_zone != bot_player.hand_zone:
		return false
	if zone.zone_owner != bot_player or not zone.cards.is_empty():
		return false
	return bool(_build_creature_summon_payment_plan(card, available_mana).get("ok", false))

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
	var best_score := ASKELLADEN_BOUNCE_TARGET_SCORE
	for creature in opposing_creatures:
		if not _can_attack_creature(askelladen, creature):
			continue
		var score := _score_askelladen_bounce_target(creature)
		if _can_clear_creature_without_askelladen(creature):
			score -= 1800
		if score < best_score:
			continue
		if best_target == null or score > best_score or (score == best_score and _is_board_creature_better(creature, best_target)):
			best_target = creature
			best_score = score
	return best_target

func _get_best_standard_attack(attackers: Array[Card], opposing_creatures: Array[Card]) -> Dictionary:
	var best_attack := {}
	for attacker in attackers:
		for target in opposing_creatures:
			var attack_score := _score_standard_attack_plan(attacker, target)
			if attack_score <= -1000000:
				continue
			if best_attack.is_empty():
				best_attack = {"attacker": attacker, "target": target, "score": attack_score}
				continue
			var current_attacker: Card = best_attack.get("attacker", null)
			var current_target: Card = best_attack.get("target", null)
			var current_score := int(best_attack.get("score", -1000000))
			if attack_score > current_score or (attack_score == current_score and _is_attack_plan_better(attacker, target, current_attacker, current_target)):
				best_attack = {"attacker": attacker, "target": target, "score": attack_score}
	if not best_attack.is_empty():
		best_attack.erase("score")
	return best_attack

func _is_attack_plan_better(candidate_attacker: Card, candidate_target: Card, current_attacker: Card, current_target: Card) -> bool:
	if current_target == null:
		return true
	if _is_board_creature_better(candidate_target, current_target):
		return true
	if _is_board_creature_better(current_target, candidate_target):
		return false
	var candidate_attacker_score := _score_projected_card(candidate_attacker)
	var current_attacker_score := _score_projected_card(current_attacker)
	if candidate_attacker_score != current_attacker_score:
		return candidate_attacker_score < current_attacker_score
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

func _get_attack_strength_against_defense(attacker: Card) -> int:
	if attacker == null:
		return 0
	var total := attacker.get_effective_strength()
	for equip in attacker.equipment:
		if equip is EquipmentCard:
			total += equip.get_bonus_strength_vs_defense(attacker)
	return total

func _defender_has_ferocious_defence(target: Card, opposing_strength: int) -> bool:
	if target == null or game_manager == null:
		return false
	if target.card_type != Card.CardType.CREATURE:
		return false
	if target.creature_mode != Card.CreatureMode.DEFENSIVE:
		return false
	if not game_manager.has_method("_has_ferocious_defence"):
		return false
	return game_manager._has_ferocious_defence(target.get_controller()) \
		and target.get_effective_resilience() >= opposing_strength

func _would_destroy_target_in_battle(attacker: Card, target: Card) -> bool:
	if attacker == null or target == null:
		return false
	if _is_stone_monkey(target) and not attacker.can_destroy_combat_protected_creatures(target):
		return false
	if target.is_petrified() or target.card_type == Card.CardType.STRUCTURE:
		return attacker.get_effective_strength() > target.get_effective_resilience()
	if target.creature_mode == Card.CreatureMode.AGGRESSIVE:
		return attacker.get_effective_strength() >= target.get_effective_strength()
	return _get_attack_strength_against_defense(attacker) > target.get_effective_resilience()

func _would_attacker_survive_battle(attacker: Card, target: Card) -> bool:
	if attacker == null or target == null:
		return false
	if target.is_petrified() or target.card_type == Card.CardType.STRUCTURE:
		return true
	if target.creature_mode == Card.CreatureMode.AGGRESSIVE:
		return attacker.get_effective_strength() > target.get_effective_strength()
	return not _defender_has_ferocious_defence(target, _get_attack_strength_against_defense(attacker))

func _is_askelladen(card: Card) -> bool:
	return card is Askelladen

func _is_stone_monkey(card: Card) -> bool:
	return card is StoneMonkey

func _is_reasonable_askelladen_trade(attacker: Card, target: Card) -> bool:
	if attacker == null or target == null:
		return false
	if attacker is ActiveGodCard:
		return false
	if not _would_destroy_target_in_battle(attacker, target):
		return false
	return _score_projected_card(attacker) <= _score_projected_card(target) + 800

func _is_attack_target_tactically_bad(attacker: Card, target: Card) -> bool:
	if attacker == null or target == null:
		return true
	if _is_stone_monkey(target) and not attacker.can_destroy_combat_protected_creatures(target):
		return true
	if not _is_askelladen(target):
		return false
	if attacker.get_effective_speed() > target.get_effective_speed():
		return false
	return not _is_reasonable_askelladen_trade(attacker, target)

func _is_clean_creature_kill(attacker: Card, target: Card) -> bool:
	if not _can_attack_creature(attacker, target):
		return false
	if _is_attack_target_tactically_bad(attacker, target):
		return false
	if not _would_destroy_target_in_battle(attacker, target):
		return false
	if _is_askelladen(target) and attacker.get_effective_speed() <= target.get_effective_speed():
		return _is_reasonable_askelladen_trade(attacker, target)
	return _would_attacker_survive_battle(attacker, target)

func _score_standard_attack_plan(attacker: Card, target: Card) -> int:
	if not _can_attack_creature(attacker, target):
		return -1000000
	if _is_attack_target_tactically_bad(attacker, target):
		return -1000000
	if not _would_destroy_target_in_battle(attacker, target):
		return -1000000
	var score := _score_enemy_target(target) * 12
	if _is_askelladen(target):
		score -= attacker.get_effective_strength() * 40
		score -= int(float(_score_projected_card(attacker)) / 4.0)
		if attacker.get_effective_speed() > target.get_effective_speed():
			score += 1400
		else:
			score += 500
	elif _would_attacker_survive_battle(attacker, target):
		score += 2400
	else:
		score -= 1800
	score += attacker.get_effective_speed() * 30
	return score

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

func _get_best_safe_followers_attack(attackers: Array[Card]) -> Dictionary:
	if opponent == null or game_manager == null or match_manager == null:
		return {}
	var best_attacker: Card = null
	var best_score := -1000000
	for attacker in attackers:
		if attacker == null or not _can_attack_followers_safely(attacker):
			continue
		var score := _score_followers_attack(attacker)
		if best_attacker == null or score > best_score:
			best_attacker = attacker
			best_score = score
	if best_attacker == null:
		return {}
	return {"attacker": best_attacker}

func _can_attack_followers_safely(attacker: Card) -> bool:
	if attacker == null or opponent == null or game_manager == null or match_manager == null:
		return false
	if game_manager.is_followers_attack_blocked_by_active_structure(attacker, opponent, []):
		return false
	return match_manager._get_possible_interceptors(attacker, opponent).is_empty()

func _score_followers_attack(attacker: Card) -> int:
	if attacker == null or opponent == null:
		return -1000000
	var score := attacker.get_effective_strength() * 140 + attacker.get_effective_speed() * 25
	if attacker.get_effective_strength() >= opponent.followers:
		score += 3000
	if opponent.followers <= attacker.get_effective_strength() * 2:
		score += 1200
	if attacker.is_stealth:
		score += 400
	return score

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

func _get_best_defensive_mode_switch_candidate() -> Card:
	if bot_player == null or game_manager == null:
		return null
	var opposing_creatures := _get_board_creatures(opponent)
	var best_creature: Card = null
	var best_score := -1
	for zone in bot_player.frontline_zones:
		for creature in zone.cards:
			var score := _get_defensive_mode_switch_score(creature, opposing_creatures)
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
	if creature is Askelladen and _get_best_askelladen_target_for(creature as Askelladen, opposing_creatures) != null:
		return 1000000 + creature.get_effective_strength() * 100
	if opposing_creatures.is_empty():
		return 500000 + _score_followers_attack(creature)
	var best_attack_score := -1000000
	for target in opposing_creatures:
		best_attack_score = maxi(best_attack_score, _score_standard_attack_plan(creature, target))
	if best_attack_score <= -1000000:
		return -1
	return 300000 + best_attack_score

func _get_defensive_mode_switch_score(creature: Card, opposing_creatures: Array[Card]) -> int:
	if creature == null or creature.card_type != Card.CardType.CREATURE:
		return -1
	if creature.creature_mode != Card.CreatureMode.AGGRESSIVE:
		return -1
	if not creature.can_take_minor_creature_action():
		return -1
	if creature.can_take_major_creature_action():
		for target in opposing_creatures:
			if _score_standard_attack_plan(creature, target) > -1000000:
				return -1
		if opposing_creatures.is_empty() and _can_attack_followers_safely(creature):
			return -1
	var best_threat := 0
	for enemy in opposing_creatures:
		if not _can_attack_creature(enemy, creature):
			continue
		if enemy.get_effective_strength() < creature.get_effective_resilience():
			continue
		best_threat = maxi(best_threat, _score_projected_card(enemy))
	if best_threat <= 0:
		return -1
	return best_threat + creature.get_effective_resilience() * 25

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

func _find_hand_unprepared_vision_of_odin() -> VisionOfOdin:
	for card in bot_player.hand_zone.cards:
		if card is VisionOfOdin:
			return card as VisionOfOdin
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
	var best_score := ASKELLADEN_BOUNCE_TARGET_SCORE
	var sample_askelladen := Askelladen.new()
	sample_askelladen.card_owner = bot_player
	for creature in _get_board_creatures(opponent):
		if creature == null or not _can_askelladen_retreat(sample_askelladen, creature):
			continue
		var score := _score_askelladen_bounce_target(creature)
		if _can_clear_creature_without_askelladen(creature):
			score -= 1800
		if score < best_score:
			continue
		if best_target == null or score > best_score or (score == best_score and _is_board_creature_better(creature, best_target)):
			best_target = creature
			best_score = score
	return best_target

func _can_clear_creature_without_askelladen(target: Card) -> bool:
	if target == null or target.card_type != Card.CardType.CREATURE:
		return true
	for creature in _get_board_creatures(bot_player):
		if creature == null or creature is Askelladen:
			continue
		if creature.current_zone not in bot_player.frontline_zones:
			continue
		if creature.is_sleeping or not creature.can_take_major_creature_action():
			continue
		if creature.creature_mode != Card.CreatureMode.AGGRESSIVE and not creature.can_take_minor_creature_action():
			continue
		if _is_clean_creature_kill(creature, target):
			return true
	var summon_zone := _get_first_open_summon_zone(bot_player)
	if summon_zone != null:
		for card in bot_player.hand_zone.cards:
			if card == null or card is Askelladen:
				continue
			if not _can_evaluate_creature_play(card, summon_zone, bot_player.mana):
				continue
			if _card_can_answer_target_after_summon(card, target):
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
	var valkyrie_call := _find_call_of_the_valkyrie()
	if bot_player == null or valkyrie_call == null:
		return false
	var target := _choose_call_of_the_valkyrie_target(valkyrie_call)
	if target == null:
		return false
	if _needs_askelladen_support():
		return target is Askelladen
	return _is_call_of_the_valkyrie_target_worth_priming(valkyrie_call, target)

func _needs_askelladen_support() -> bool:
	if _get_askelladen_problem_creature() == null:
		return false
	if _find_hand_askelladen() != null:
		return false
	for creature in _get_board_creatures(bot_player):
		if creature is Askelladen:
			return false
	return _find_graveyard_askelladen() != null

func _choose_call_of_the_valkyrie_target(valkyrie_call: CallOfTheValkyrie) -> Card:
	if valkyrie_call == null:
		return null
	var valid_targets := valkyrie_call.get_valid_targets(game_manager)
	if valid_targets.is_empty():
		return null
	if _needs_askelladen_support():
		for target in valid_targets:
			if target is Askelladen:
				return target
	var useful_target := _choose_best_call_of_the_valkyrie_target(valkyrie_call, valid_targets, true)
	if useful_target != null:
		return useful_target
	return _choose_best_call_of_the_valkyrie_target(valkyrie_call, valid_targets, false)

func _choose_best_call_of_the_valkyrie_target(valkyrie_call: CallOfTheValkyrie, valid_targets: Array[Card], require_useful: bool) -> Card:
	var best_target: Card = null
	var best_score := -1000000
	for target in valid_targets:
		if target == null:
			continue
		if require_useful and not _is_call_of_the_valkyrie_target_worth_priming(valkyrie_call, target):
			continue
		var score := _score_call_of_the_valkyrie_target(target)
		if _call_of_the_valkyrie_target_answers_board(target):
			score += 500
		if _can_play_call_of_the_valkyrie_target_after_next_draw(valkyrie_call, target):
			score += 300
		if best_target == null or score > best_score or (score == best_score and _get_card_order_index(target) < _get_card_order_index(best_target)):
			best_target = target
			best_score = score
	return best_target

func _is_call_of_the_valkyrie_target_worth_priming(valkyrie_call: CallOfTheValkyrie, target: Card) -> bool:
	if bot_player == null or game_manager == null or target == null:
		return false
	if target is Askelladen and _needs_askelladen_support():
		return true
	if not _can_play_call_of_the_valkyrie_target_after_next_draw(valkyrie_call, target):
		return false

	var target_score := _score_call_of_the_valkyrie_target(target)
	var best_hand := _get_best_affordable_hand_creature(0)
	if best_hand == null:
		return target_score >= CALL_VALKYRIE_DESPERATION_TARGET_SCORE
	if _call_of_the_valkyrie_activation_would_block_hand_play(valkyrie_call, best_hand):
		return false

	var target_play_score := _score_projected_card(target)
	var best_hand_score := _score_projected_card(best_hand)
	var target_is_clear_upgrade := target_play_score >= best_hand_score + CALL_VALKYRIE_SMALL_UPGRADE_MARGIN
	if _call_of_the_valkyrie_target_answers_board(target):
		return target_score >= CALL_VALKYRIE_DESPERATION_TARGET_SCORE and target_is_clear_upgrade
	if _board_creature_count(bot_player) < _board_creature_count(opponent):
		return target_score >= CALL_VALKYRIE_DEFAULT_TARGET_SCORE and target_is_clear_upgrade
	var hand_size := bot_player.hand_zone.cards.size() if bot_player.hand_zone != null else 0
	if hand_size <= CALL_VALKYRIE_LOW_HAND_LIMIT:
		return target_score >= CALL_VALKYRIE_PREMIUM_TARGET_SCORE \
			and target_play_score >= best_hand_score + CALL_VALKYRIE_LARGE_UPGRADE_MARGIN
	return false

func _can_play_call_of_the_valkyrie_target_after_next_draw(valkyrie_call: CallOfTheValkyrie, target: Card) -> bool:
	if bot_player == null or game_manager == null or valkyrie_call == null or target == null:
		return false
	if target.card_type != Card.CardType.CREATURE:
		return false
	if _get_first_open_summon_zone(bot_player) == null:
		return false
	var projected_mana := _get_call_of_the_valkyrie_projected_draw_mana(valkyrie_call)
	if projected_mana < _get_play_cost(target, false):
		return false
	return _can_pay_projected_additional_costs(target)

func _get_call_of_the_valkyrie_projected_draw_mana(valkyrie_call: CallOfTheValkyrie) -> int:
	if bot_player == null or game_manager == null or valkyrie_call == null:
		return 0
	var projected_mana := bot_player.mana
	if valkyrie_call.is_face_down:
		projected_mana -= valkyrie_call.get_unlock_mana_cost(game_manager)
	projected_mana -= valkyrie_call.get_activation_mana_cost(CallOfTheValkyrie.ACTIVATION_COST, game_manager)
	projected_mana += game_manager.get_effective_upkeep_mana_gain(game_manager.get_base_upkeep_draw_mana_gain(), bot_player)
	return projected_mana

func _can_pay_projected_additional_costs(card: Card) -> bool:
	if card == null or bot_player == null:
		return false
	if card.discard_cost > 0 and bot_player.hand_zone.cards.size() < card.discard_cost:
		return false
	if card.shelve_cost > 0 and bot_player.hand_zone.cards.size() < card.shelve_cost:
		return false
	if card.sacrifice_cost > 0 and _get_valid_summon_sacrifice_candidates().size() < card.sacrifice_cost:
		return false
	if card.banish_cost > 0 and _get_projected_banishable_card_count() < card.banish_cost:
		return false
	return true

func _get_projected_banishable_card_count() -> int:
	if bot_player == null:
		return 0
	var count := bot_player.hand_zone.cards.size()
	for zone in bot_player.frontline_zones + bot_player.reserve_zones:
		count += zone.cards.size()
	return count

func _call_of_the_valkyrie_activation_would_block_hand_play(valkyrie_call: CallOfTheValkyrie, best_hand: Card) -> bool:
	if valkyrie_call == null or best_hand == null or bot_player == null:
		return false
	var committed_mana := valkyrie_call.get_activation_mana_cost(CallOfTheValkyrie.ACTIVATION_COST, game_manager)
	if valkyrie_call.is_face_down:
		committed_mana += valkyrie_call.get_unlock_mana_cost(game_manager)
	if committed_mana <= 0:
		return false
	var zone := _get_first_open_summon_zone(bot_player)
	if zone == null:
		return false
	return _score_creature_play(best_hand, zone, bot_player.mana) > -1000000 \
		and _score_creature_play(best_hand, zone, bot_player.mana - committed_mana) <= -1000000

func _call_of_the_valkyrie_target_answers_board(target: Card) -> bool:
	if target == null:
		return false
	if target is Askelladen and _get_askelladen_problem_creature() != null:
		return true
	var opposing_creatures := _get_board_creatures(opponent)
	return not opposing_creatures.is_empty() and _count_clean_attack_targets_for(target, opposing_creatures) > 0

func _find_graveyard_askelladen() -> Askelladen:
	if bot_player == null:
		return null
	for card in bot_player.graveyard_zone.cards:
		if card is Askelladen:
			return card as Askelladen
	return null

func _should_use_askelladen_retreat(ask_card: Askelladen, other_card: Card, action: CardAction = null) -> bool:
	if ask_card == null or other_card == null:
		return false
	if ask_card.get_controller() != bot_player:
		return false
	if other_card.get_controller() == bot_player:
		return false
	if not _can_askelladen_retreat(ask_card, other_card):
		return false
	var fight_score := _score_askelladen_fight_result(action, ask_card, other_card)
	if fight_score > -1000000:
		var retreat_score := _score_askelladen_retreat_result(ask_card, other_card)
		return retreat_score > fight_score + ASKELLADEN_RETREAT_SCORE_MARGIN
	var score := _score_askelladen_bounce_target(other_card)
	if _can_clear_creature_without_askelladen(other_card):
		score -= 1800
	return score >= ASKELLADEN_BOUNCE_TARGET_SCORE

func _score_askelladen_fight_result(action: CardAction, ask_card: Askelladen, other_card: Card) -> int:
	if action == null or action.type != CardAction.Type.ATTACK:
		return -1000000
	if action.attacker == null:
		return -1000000
	var defender := _get_attack_defender_card(action)
	if defender == null:
		return -1000000
	if action.attacker != ask_card and action.attacker != other_card:
		return -1000000
	if defender != ask_card and defender != other_card:
		return -1000000
	return _score_attack_economy(_estimate_attack_economy(action, null, 0, 0))

func _score_askelladen_retreat_result(ask_card: Askelladen, other_card: Card) -> int:
	if ask_card == null or other_card == null:
		return -1000000
	return _get_card_economic_value(other_card) - _get_card_economic_value(ask_card)

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
			if card.summoned_after_first_attack_this_turn:
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

func _get_player_powers() -> Array[PowerCard]:
	var powers: Array[PowerCard] = []
	if bot_player == null:
		return powers
	for zone in bot_player.power_zones:
		for card in zone.cards:
			var power := card as PowerCard
			if power != null:
				powers.append(power)
	return powers

func _can_use_generic_power_command(power: PowerCard) -> bool:
	return power != null and not (power is Breidablik) and not (power is DivineCaprice)

func _score_power_unlock(power: PowerCard) -> int:
	if power == null:
		return -1000000
	if power is CallOfTheValkyrie:
		var target := _choose_call_of_the_valkyrie_target(power as CallOfTheValkyrie)
		if target == null or not _should_use_call_of_the_valkyrie():
			return -1000000
		return 1800 + _score_call_of_the_valkyrie_target(target) - power.get_unlock_mana_cost(game_manager) * 140
	var score := -power.get_unlock_mana_cost(game_manager) * 140
	var best_target: Card = null
	if power.has_method("get_valid_targets"):
		best_target = _choose_best_target_for_source(power, power.get_valid_targets(game_manager))
	if best_target != null:
		score += 1200 + int(float(_score_activation_target(power, best_target)) / 10.0)
	if _get_best_affordable_hand_creature(0) == null:
		score += 500
	if bot_player != null and bot_player.hand_zone != null and bot_player.hand_zone.cards.size() <= 2:
		score += 250
	return score

func _score_power_activation(power: PowerCard, target: Card = null) -> int:
	if power == null:
		return -1000000
	if power is CallOfTheValkyrie:
		if target == null or not _should_use_call_of_the_valkyrie():
			return -1000000
		return 2200 + _score_call_of_the_valkyrie_target(target)
	if power.targets:
		if target == null:
			return -1000000
		return 1000 + _score_activation_target(power, target)
	if _should_activate_untargeted_power(power):
		return 1400
	return -1000000

func _should_activate_untargeted_power(power: PowerCard) -> bool:
	if power == null:
		return false
	if _get_best_affordable_hand_creature(0) == null:
		return true
	return bot_player != null and bot_player.hand_zone != null and bot_player.hand_zone.cards.size() <= 1

func _score_champions_call_activation(god: GodCard) -> int:
	if god == null or not god.has_method("can_use_champions_call") or not god.can_use_champions_call(game_manager):
		return -1000000
	var manifestation := god.get_champions_call_candidate(true)
	if manifestation == null:
		return -1000000
	var opposing_creatures := _get_board_creatures(opponent)
	var summon_mode := _choose_creature_summon_mode(manifestation, opposing_creatures)
	var clean_kill_count := _count_clean_attack_targets_for(manifestation, opposing_creatures)
	var score := _score_projected_card(manifestation)
	var shelve_count := god.get_champions_call_required_shelve_count(game_manager)
	score -= shelve_count * 2000
	if opposing_creatures.is_empty():
		score += 1800
	elif clean_kill_count > 0:
		score += 900 + clean_kill_count * 550
	else:
		score -= 2200
	if summon_mode == Card.CreatureMode.DEFENSIVE:
		score -= 1700
	if game_manager != null and game_manager.turn_number <= 2 and summon_mode == Card.CreatureMode.DEFENSIVE and clean_kill_count == 0:
		score -= 1200
	if _board_creature_count(bot_player) == 0 and opposing_creatures.is_empty():
		score += 600
	if _board_creature_count(bot_player) < _board_creature_count(opponent):
		score += 800
	score += _count_other_friendly_warriors() * 250
	var best_hand := _get_best_affordable_hand_creature(0)
	if best_hand == null:
		score += 600
	else:
		score -= int(_score_projected_card(best_hand) * 0.9)
	return score

func _choose_creature_summon_mode(card: Card, opposing_creatures: Array[Card] = []) -> Card.CreatureMode:
	if card == null or card.card_type != Card.CardType.CREATURE:
		return Card.CreatureMode.DEFENSIVE
	var resolved_opposing := opposing_creatures
	if resolved_opposing.is_empty() and opponent != null:
		resolved_opposing = _get_board_creatures(opponent)
	if resolved_opposing.is_empty():
		return Card.CreatureMode.AGGRESSIVE
	if _count_clean_attack_targets_for(card, resolved_opposing) > 0:
		return Card.CreatureMode.AGGRESSIVE
	if _is_projected_creature_strongest_on_board(card, resolved_opposing):
		return Card.CreatureMode.AGGRESSIVE
	if _should_summon_as_aggressive_into_defensive_wall(card, resolved_opposing):
		return Card.CreatureMode.AGGRESSIVE
	return Card.CreatureMode.DEFENSIVE

func _should_summon_as_aggressive_into_defensive_wall(card: Card, opposing_creatures: Array[Card]) -> bool:
	if card == null or opposing_creatures.is_empty():
		return false
	var has_defensive_wall := false
	for enemy in opposing_creatures:
		if enemy == null:
			continue
		if enemy.creature_mode == Card.CreatureMode.DEFENSIVE and not _would_destroy_target_in_battle(card, enemy):
			has_defensive_wall = true
			break
	if not has_defensive_wall:
		return false
	var projected_strength := _get_projected_strength(card)
	var projected_resilience := _get_projected_resilience(card)
	if projected_resilience > projected_strength:
		return false
	for enemy in opposing_creatures:
		if enemy == null or not _can_attack_creature(enemy, card):
			continue
		if enemy.get_effective_strength() >= projected_resilience and enemy.get_effective_strength() < projected_strength:
			return true
	return projected_resilience <= maxi(1, int(float(projected_strength) / 2.0))

func _count_clean_attack_targets_for(attacker: Card, opposing_creatures: Array[Card]) -> int:
	var count := 0
	for target in opposing_creatures:
		if _is_clean_creature_kill(attacker, target):
			count += 1
	return count

func _is_projected_creature_strongest_on_board(card: Card, opposing_creatures: Array[Card]) -> bool:
	if card == null:
		return false
	var projected_strength := _get_projected_strength(card)
	var projected_resilience := _get_projected_resilience(card)
	var projected_speed := card.get_effective_speed()
	var strongest_seen := false
	for enemy in opposing_creatures:
		if enemy == null:
			continue
		strongest_seen = true
		var enemy_strength := enemy.get_effective_strength()
		var enemy_resilience := enemy.get_effective_resilience()
		var enemy_speed := enemy.get_effective_speed()
		if projected_strength < enemy_strength:
			return false
		if projected_strength == enemy_strength and projected_resilience < enemy_resilience:
			return false
		if projected_strength == enemy_strength and projected_resilience == enemy_resilience and projected_speed < enemy_speed:
			return false
	return strongest_seen

func _count_other_friendly_warriors() -> int:
	var count := 0
	for creature in _get_board_creatures(bot_player):
		if creature != null and creature.has_type("Warrior"):
			count += 1
	return count

func _find_best_priority_vision_response(responses: Array, top_action: CardAction) -> Dictionary:
	if top_action == null or top_action.type != CardAction.Type.ATTACK:
		return {}
	var best_card: VisionOfOdin = null
	var best_target: Card = null
	var best_score := 0
	for response_card in responses:
		var vision := response_card as VisionOfOdin
		if vision == null:
			continue
		var targets := game_manager.get_priority_hex_targets(vision, top_action)
		var target := _choose_best_priority_vision_target(vision, top_action, targets)
		if target == null:
			continue
		var score := _score_vision_of_odin_priority_target(vision, top_action, target)
		if best_card == null or score > best_score:
			best_card = vision
			best_target = target
			best_score = score
	if best_card == null:
		return {}
	return {"card": best_card, "target": best_target, "score": best_score}

func _choose_best_priority_vision_target(vision: VisionOfOdin, top_action: CardAction, targets: Array) -> Card:
	var best_target: Card = null
	var best_score := -1000000
	for raw_target in targets:
		var target := raw_target as Card
		if target == null:
			continue
		var score := _score_vision_of_odin_priority_target(vision, top_action, target)
		if score <= -1000000:
			continue
		if best_target == null or score > best_score:
			best_target = target
			best_score = score
	return best_target

func _score_vision_of_odin_priority_target(_vision: VisionOfOdin, top_action: CardAction, target: Card) -> int:
	if top_action == null or top_action.type != CardAction.Type.ATTACK or target == null:
		return -1000000
	var attacker := top_action.attacker
	var defender := _get_attack_defender_card(top_action)
	var target_is_friendly_norse := target.card_owner == bot_player and _is_norse_creature(target)
	var target_is_enemy_non_norse := target.card_owner == opponent and not _is_norse_creature(target)
	if not target_is_friendly_norse and not target_is_enemy_non_norse:
		return -1000000
	if target != attacker and target != defender:
		return -1000000
	var score := _score_vision_economic_swing(_vision, top_action, target, target_is_friendly_norse)
	if defender == null:
		if target == attacker and target_is_enemy_non_norse and attacker.get_controller() == opponent:
			score += 800 + VisionOfOdin.STR_SWING * 140
			if bot_player != null and bot_player.followers <= attacker.get_effective_strength() and bot_player.followers > attacker.get_effective_strength() - VisionOfOdin.STR_SWING:
				score += 3200
		elif target == attacker and target_is_friendly_norse and attacker.get_controller() == bot_player:
			score += 500 + VisionOfOdin.STR_SWING * 120
			if opponent != null and opponent.followers > attacker.get_effective_strength() and opponent.followers <= attacker.get_effective_strength() + VisionOfOdin.STR_SWING:
				score += 2600
		return score if score > 0 else -1000000
	if target == attacker:
		if attacker.get_controller() == bot_player and target_is_friendly_norse:
			if attacker.get_effective_strength() < defender.get_effective_resilience() and attacker.get_effective_strength() + VisionOfOdin.STR_SWING >= defender.get_effective_resilience():
				score += 3600
			if defender is Askelladen and attacker.get_effective_speed() <= defender.get_effective_speed() and attacker.get_effective_speed() + VisionOfOdin.SPEED_SWING > defender.get_effective_speed():
				score += 2600
		elif attacker.get_controller() == opponent and target_is_enemy_non_norse:
			if attacker.get_effective_strength() >= defender.get_effective_resilience() and attacker.get_effective_strength() - VisionOfOdin.STR_SWING < defender.get_effective_resilience():
				score += 3600
			if attacker is Askelladen and defender.get_effective_speed() <= attacker.get_effective_speed() and defender.get_effective_speed() > attacker.get_effective_speed() - VisionOfOdin.SPEED_SWING:
				score += 2600
	if target == defender:
		if defender.get_controller() == bot_player and target_is_friendly_norse:
			if defender.get_effective_strength() < attacker.get_effective_resilience() and defender.get_effective_strength() + VisionOfOdin.STR_SWING >= attacker.get_effective_resilience():
				score += 3600
			if defender is Askelladen and attacker.get_effective_speed() > defender.get_effective_speed() and attacker.get_effective_speed() <= defender.get_effective_speed() + VisionOfOdin.SPEED_SWING:
				score += 2600
		elif defender.get_controller() == opponent and target_is_enemy_non_norse:
			if defender.get_effective_strength() >= attacker.get_effective_resilience() and defender.get_effective_strength() - VisionOfOdin.STR_SWING < attacker.get_effective_resilience():
				score += 3600
			if defender is Askelladen and attacker.get_effective_speed() <= defender.get_effective_speed() and attacker.get_effective_speed() > defender.get_effective_speed() - VisionOfOdin.SPEED_SWING:
				score += 2600
	return score if score > 0 else -1000000

func _score_vision_economic_swing(vision: VisionOfOdin, action: CardAction, target: Card, target_is_buffed: bool) -> int:
	if action == null or target == null:
		return -1000000
	var str_delta := VisionOfOdin.STR_SWING if target_is_buffed else -VisionOfOdin.STR_SWING
	var speed_delta := VisionOfOdin.SPEED_SWING if target_is_buffed else -VisionOfOdin.SPEED_SWING
	var before := _estimate_attack_economy(action, null, 0, 0)
	var after := _estimate_attack_economy(action, target, str_delta, speed_delta)
	var score := _score_attack_economy(after) - _score_attack_economy(before)
	score -= ECON_CARD_VALUE
	if vision != null and game_manager != null and bot_player != null:
		score -= game_manager.get_prepared_card_activation_mana_cost(bot_player, vision) * ECON_MANA_VALUE
	return score

func _estimate_attack_economy(action: CardAction, modified_card: Card, str_delta: int, _speed_delta: int) -> Dictionary:
	var result := {
		"bot_cards_lost": 0,
		"opponent_cards_lost": 0,
		"bot_followers_lost": 0,
		"opponent_followers_lost": 0,
		"bot_wins": false,
		"opponent_wins": false,
	}
	if action == null or action.attacker == null:
		return result
	var attacker := action.attacker
	var defender := _get_attack_defender_card(action)
	var attacker_strength := _get_vision_adjusted_strength(attacker, modified_card, str_delta)
	if defender == null:
		_add_follower_loss_to_economy(result, _get_attack_defending_player(action, defender), attacker_strength)
		return result
	if defender.is_god:
		_add_follower_loss_to_economy(result, defender.get_controller(), attacker_strength)
		return result
	if defender.is_petrified() or defender.card_type == Card.CardType.STRUCTURE:
		if _get_vision_adjusted_strength_vs_defense(attacker, modified_card, str_delta) > defender.get_effective_resilience():
			_add_destroyed_card_to_economy(result, defender)
		return result
	if defender.card_type != Card.CardType.CREATURE:
		return result
	if defender.creature_mode == Card.CreatureMode.AGGRESSIVE:
		var defender_strength := _get_vision_adjusted_strength(defender, modified_card, str_delta)
		if attacker_strength > defender_strength:
			_add_destroyed_card_to_economy(result, defender)
			_add_follower_loss_to_economy(result, defender.get_controller(), attacker_strength - defender_strength)
		elif defender_strength > attacker_strength:
			_add_destroyed_card_to_economy(result, attacker)
			_add_follower_loss_to_economy(result, attacker.get_controller(), defender_strength - attacker_strength)
		else:
			_add_destroyed_card_to_economy(result, attacker)
			_add_destroyed_card_to_economy(result, defender)
		return result

	var attack_strength_vs_defense := _get_vision_adjusted_strength_vs_defense(attacker, modified_card, str_delta)
	var defender_resilience := defender.get_effective_resilience()
	if attack_strength_vs_defense > defender_resilience:
		_add_destroyed_card_to_economy(result, defender)
	elif attack_strength_vs_defense < defender_resilience:
		_add_follower_loss_to_economy(result, attacker.get_controller(), defender_resilience - attack_strength_vs_defense)
		if _defender_has_ferocious_defence(defender, attack_strength_vs_defense):
			_add_destroyed_card_to_economy(result, attacker)
	elif _defender_has_ferocious_defence(defender, attack_strength_vs_defense):
		_add_destroyed_card_to_economy(result, attacker)
	return result

func _score_attack_economy(result: Dictionary) -> int:
	var score := int(result.get("opponent_cards_lost", 0)) - int(result.get("bot_cards_lost", 0))
	score += _score_follower_loss(opponent, int(result.get("opponent_followers_lost", 0)))
	score -= _score_follower_loss(bot_player, int(result.get("bot_followers_lost", 0)))
	if bool(result.get("bot_wins", false)):
		score += ECON_CARD_VALUE * 20
	if bool(result.get("opponent_wins", false)):
		score -= ECON_CARD_VALUE * 20
	return score

func _add_destroyed_card_to_economy(result: Dictionary, card: Card) -> void:
	if card == null:
		return
	var value := _get_card_economic_value(card)
	if card.get_controller() == bot_player:
		result["bot_cards_lost"] = int(result.get("bot_cards_lost", 0)) + value
	elif card.get_controller() == opponent:
		result["opponent_cards_lost"] = int(result.get("opponent_cards_lost", 0)) + value

func _add_follower_loss_to_economy(result: Dictionary, player: Player, amount: int) -> void:
	if player == null or amount <= 0:
		return
	var actual_loss := mini(amount, player.followers)
	if player == bot_player:
		result["bot_followers_lost"] = int(result.get("bot_followers_lost", 0)) + actual_loss
		if actual_loss >= player.followers:
			result["opponent_wins"] = true
	elif player == opponent:
		result["opponent_followers_lost"] = int(result.get("opponent_followers_lost", 0)) + actual_loss
		if actual_loss >= player.followers:
			result["bot_wins"] = true

func _get_attack_defending_player(action: CardAction, defender: Card) -> Player:
	if defender != null:
		return defender.get_controller()
	if action != null and action.target is Player:
		return action.target as Player
	if action != null and action.attacker != null:
		return game_manager.get_opponent(action.attacker.get_controller()) if game_manager != null else null
	return null

func _get_vision_adjusted_strength(card: Card, modified_card: Card, str_delta: int) -> int:
	if card == null:
		return 0
	var strength := card.get_effective_strength()
	if card == modified_card:
		strength += str_delta
	return maxi(0, strength)

func _get_vision_adjusted_strength_vs_defense(card: Card, modified_card: Card, str_delta: int) -> int:
	if card == null:
		return 0
	var strength := _get_attack_strength_against_defense(card)
	if card == modified_card:
		strength += str_delta
	return maxi(0, strength)

func _get_card_economic_value(card: Card) -> int:
	if card == null:
		return 0
	return ECON_CARD_VALUE + maxi(0, int(float(_score_projected_card(card)) / 2.0))

func _score_follower_loss(player: Player, amount: int) -> int:
	if player == null or amount <= 0:
		return 0
	if amount >= player.followers:
		return ECON_CARD_VALUE * 20
	var base_per_follower := int(float(ECON_CARD_VALUE) / float(ECON_FOLLOWERS_PER_CARD))
	var score := 0
	for index in range(amount):
		var followers_after_loss := maxi(0, player.followers - index - 1)
		var pressure := 1.0
		if followers_after_loss < 50:
			var danger := float(50 - followers_after_loss) / 50.0
			pressure += pow(danger, 2.0) * 3.0
		score += int(round(float(base_per_follower) * pressure))
	return score

func _get_attack_defender_card(action: CardAction) -> Card:
	if action == null:
		return null
	if action.interceptor != null:
		return action.interceptor
	return action.target as Card

func _is_norse_creature(card: Card) -> bool:
	return card != null and card.card_type == Card.CardType.CREATURE and str(card.culture).strip_edges() == "Norse"

func _choose_harii_jarl_warband_targets(jarl: HariiJarl, prompt_targets: Array[Card]) -> Array[Card]:
	var targets := prompt_targets if not prompt_targets.is_empty() else jarl.get_valid_warband_targets(game_manager)
	var ranked_targets: Array[Dictionary] = []
	for target in targets:
		if target == null:
			continue
		ranked_targets.append({
			"card": target,
			"score": _score_harii_jarl_warband_target(target),
		})
	ranked_targets.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		var score_a := int(a.get("score", -1000000))
		var score_b := int(b.get("score", -1000000))
		if score_a != score_b:
			return score_a > score_b
		return _get_card_order_index(a.get("card", null)) < _get_card_order_index(b.get("card", null))
	)
	var chosen: Array[Card] = []
	for entry in ranked_targets:
		var card := entry.get("card", null) as Card
		if card == null:
			continue
		chosen.append(card)
		if chosen.size() >= HariiJarl.MAX_WARBAND_SUMMONS:
			break
	return chosen

func _score_harii_jarl_warband_target(card: Card) -> int:
	var score := _score_projected_card(card)
	score += _count_clean_attack_targets_for(card, _get_board_creatures(opponent)) * 1400
	if card is HariiFransiscan:
		score += 600
	return score

func _estimate_harii_jarl_warband_value(jarl: HariiJarl) -> int:
	if jarl == null or bot_player == null:
		return 0
	var open_zones_after_jarl := maxi(0, _get_board_open_zone_count(bot_player) - 1)
	if open_zones_after_jarl <= 0:
		return 0
	var valid_targets := jarl.get_valid_warband_targets(game_manager)
	if valid_targets.is_empty():
		return 0
	var scored_targets: Array[int] = []
	for target in valid_targets:
		scored_targets.append(_score_harii_jarl_warband_target(target))
	scored_targets.sort()
	scored_targets.reverse()
	var score := 0
	var summon_count := mini(mini(open_zones_after_jarl, HariiJarl.MAX_WARBAND_SUMMONS), scored_targets.size())
	for index in range(summon_count):
		score += int(float(int(scored_targets[index])) / 2.0)
	return score

func _get_board_open_zone_count(player: Player) -> int:
	var count := 0
	if player == null:
		return count
	for zone in player.frontline_zones + player.reserve_zones:
		if zone != null and zone.cards.is_empty():
			count += 1
	return count

func _score_askelladen_bounce_target(target: Card) -> int:
	if target == null:
		return -1000000
	var score := _score_enemy_target(target)
	if target is ActiveGodCard:
		score += 2200
	if _is_stone_monkey(target):
		score += 2600
	if target.get_effective_strength() >= 20 or target.get_effective_resilience() >= 20:
		score += 900
	if target.has_type("Guardian"):
		score += 500
	return score

func _card_can_answer_target_after_summon(card: Card, target: Card) -> bool:
	if card == null or target == null or card.card_type != Card.CardType.CREATURE:
		return false
	if _is_stone_monkey(target) and not card.can_destroy_combat_protected_creatures(target):
		return false
	if _is_askelladen(target) and card.get_effective_speed() <= target.get_effective_speed():
		return card.get_effective_strength() >= target.get_effective_resilience() and not (card is ActiveGodCard)
	return card.get_effective_strength() >= target.get_effective_resilience() and card.get_effective_resilience() > target.get_effective_strength()

func _choose_best_target_for_source(source: Card, targets: Array) -> Card:
	var best_target: Card = null
	var best_score := -1000000
	for raw_target in targets:
		var target := raw_target as Card
		if target == null:
			continue
		var score := _score_activation_target(source, target)
		if best_target == null or score > best_score:
			best_target = target
			best_score = score
	return best_target

func _choose_best_enemy_target_for_source(_source: Card, targets: Array) -> Card:
	var best_target: Card = null
	var best_score := -1000000
	for raw_target in targets:
		var target := raw_target as Card
		if target == null or target.card_owner != opponent:
			continue
		var score := _score_enemy_target(target)
		if best_target == null or score > best_score:
			best_target = target
			best_score = score
	return best_target

func _choose_best_friendly_board_target_for_source(_source: Card, targets: Array) -> Card:
	var best_target: Card = null
	var best_score := -1000000
	for raw_target in targets:
		var target := raw_target as Card
		if target == null or target.card_owner != bot_player:
			continue
		if target.current_zone == null or not target.current_zone.is_board_zone():
			continue
		var score := _score_friendly_target(target)
		if best_target == null or score > best_score:
			best_target = target
			best_score = score
	return best_target

func _choose_best_friendly_graveyard_target_for_source(_source: Card, targets: Array) -> Card:
	var best_target: Card = null
	var best_score := -1000000
	for raw_target in targets:
		var target := raw_target as Card
		if target == null or target.card_owner != bot_player:
			continue
		if target.current_zone != bot_player.graveyard_zone:
			continue
		var score := _score_graveyard_target(target)
		if best_target == null or score > best_score:
			best_target = target
			best_score = score
	return best_target

func _choose_target_uid_for_source(source: Card, targets: Array) -> String:
	var best_target := _choose_best_target_for_source(source, targets)
	return best_target.uid if best_target != null else ""

func _score_activation_target(source: Card, target: Card) -> int:
	if target == null:
		return -1000000
	if target.card_owner == bot_player and target.current_zone == bot_player.graveyard_zone:
		return 45000 + _score_graveyard_target(target)
	if target.card_owner == opponent:
		return 50000 + _score_enemy_target(target)
	if target.card_owner == bot_player:
		return 20000 + _score_friendly_target(target)
	if source is CallOfTheValkyrie:
		return _score_call_of_the_valkyrie_target(target)
	return _score_projected_card(target)

func _score_call_of_the_valkyrie_target(target: Card) -> int:
	return _score_graveyard_target(target) + 400

func _score_graveyard_target(target: Card) -> int:
	var score := _score_projected_card(target)
	if target is Askelladen and _get_askelladen_problem_creature() != null:
		score += 3000
	if target != null and target.has_type("Warrior"):
		score += 500
	return score

func _score_enemy_target(target: Card) -> int:
	var score := _score_projected_card(target)
	if target.is_magical_card():
		score += 1200
	if target.is_prepared:
		score += 800
	if target.has_type("Guardian"):
		score += 500
	if target.has_type("Stealth"):
		score += 350
	return score

func _score_friendly_target(target: Card) -> int:
	var score := _score_projected_card(target)
	if target.card_type == Card.CardType.CREATURE and not target.is_sleeping and target.can_take_major_creature_action():
		score += 500
	return score

func _score_projected_card(card: Card) -> int:
	if card == null:
		return -1000000
	if card.card_type == Card.CardType.CREATURE:
		var score := _get_projected_strength(card) * 100 + _get_projected_resilience(card) * 10 + card.get_effective_speed()
		if card.has_type("Warrior"):
			score += 150
		if card is HariiFransiscan:
			score += 250
		return score
	return _get_hand_value(card) * 100

func _board_creature_count(player: Player) -> int:
	return _get_board_creatures(player).size()

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

func _score_creature_play(card: Card, zone: Zone, available_mana: int) -> int:
	if card == null or zone == null or bot_player == null:
		return -1000000
	if card.card_type != Card.CardType.CREATURE or card.current_zone != bot_player.hand_zone:
		return -1000000
	if zone.zone_owner != bot_player or not zone.cards.is_empty():
		return -1000000
	var mana_cost := _get_play_cost(card, false)
	var payment_plan := _build_creature_summon_payment_plan(card, available_mana)
	if not bool(payment_plan.get("ok", false)):
		return -1000000
	var score := _score_projected_card(card)
	score -= mana_cost * 120
	score -= int(payment_plan.get("penalty", 0))
	if card is Askelladen and _get_askelladen_problem_creature() != null:
		score += 1600
	if card is HariiFransiscan:
		score += 500
	if card is HariiJarl:
		score += _estimate_harii_jarl_warband_value(card as HariiJarl)
	return score

func _build_creature_summon_payment_plan(card: Card, available_mana: int = -1) -> Dictionary:
	var result := {
		"ok": false,
		"sacrifice_cards": [],
		"sacrifice_uids": [],
		"altar_void_cards": [],
		"altar_void_uids": [],
		"penalty": 0,
	}
	if card == null or bot_player == null or game_manager == null:
		return result
	if card.card_type != Card.CardType.CREATURE or card.current_zone != bot_player.hand_zone:
		return result
	var mana_cost := _get_play_cost(card, false)
	var available := bot_player.mana if available_mana < 0 else available_mana
	if available < mana_cost:
		return result
	if card.sacrifice_cost <= 0:
		if _validate_creature_summon_payment_plan(card, mana_cost, [], []):
			result["ok"] = true
		return result

	var direct_plan := _choose_direct_summon_sacrifice_plan(card.sacrifice_cost)
	var altar_plan := _choose_altar_of_dreams_plan(card)
	var chosen_plan := {}
	if not altar_plan.is_empty() and not direct_plan.is_empty():
		chosen_plan = altar_plan if int(altar_plan.get("penalty", 1000000)) <= int(direct_plan.get("penalty", 1000000)) else direct_plan
	elif not altar_plan.is_empty():
		chosen_plan = altar_plan
	else:
		chosen_plan = direct_plan
	if chosen_plan.is_empty():
		return result

	var sacrifice_cards: Array[Card] = []
	for raw_sacrifice in chosen_plan.get("sacrifice_cards", []):
		var sacrifice := raw_sacrifice as Card
		if sacrifice != null:
			sacrifice_cards.append(sacrifice)
	var altar_void_cards: Array[Card] = []
	for raw_target in chosen_plan.get("altar_void_cards", []):
		var altar_target := raw_target as Card
		if altar_target != null:
			altar_void_cards.append(altar_target)
	if not _validate_creature_summon_payment_plan(card, mana_cost, sacrifice_cards, altar_void_cards):
		return result
	result["ok"] = true
	result["sacrifice_cards"] = sacrifice_cards
	result["altar_void_cards"] = altar_void_cards
	result["penalty"] = int(chosen_plan.get("penalty", 0))
	var sacrifice_uids: Array[String] = []
	for sacrifice in sacrifice_cards:
		if sacrifice != null:
			sacrifice_uids.append(sacrifice.uid)
	result["sacrifice_uids"] = sacrifice_uids
	var altar_void_uids: Array[String] = []
	for target in altar_void_cards:
		if target != null:
			altar_void_uids.append(target.uid)
	result["altar_void_uids"] = altar_void_uids
	return result

func _validate_creature_summon_payment_plan(card: Card, mana_cost: int, sacrifice_cards: Array[Card], altar_void_cards: Array[Card]) -> bool:
	if card == null or bot_player == null:
		return false
	var original_sacrifice_cost := card.sacrifice_cost
	card.clear_pending_chosen_sacrifices()
	if not altar_void_cards.is_empty():
		card.sacrifice_cost = 0
	else:
		card.set_pending_chosen_sacrifices(sacrifice_cards)
	var ok := card.can_pay_costs_with_mana_cost(bot_player, mana_cost)
	card.sacrifice_cost = original_sacrifice_cost
	card.clear_pending_chosen_sacrifices()
	return ok

func _choose_direct_summon_sacrifice_plan(required: int) -> Dictionary:
	if required <= 0:
		return {"sacrifice_cards": [], "altar_void_cards": [], "penalty": 0}
	var candidates := _get_valid_summon_sacrifice_candidates()
	if candidates.size() < required:
		return {}
	var chosen := _choose_lowest_summon_sacrifice_cards(candidates, required)
	if chosen.size() != required:
		return {}
	var penalty := 0
	for card in chosen:
		penalty += _score_summon_sacrifice_candidate(card)
	return {
		"sacrifice_cards": chosen,
		"altar_void_cards": [],
		"penalty": penalty,
	}

func _choose_altar_of_dreams_plan(card: Card) -> Dictionary:
	var altar := _get_active_altar_of_dreams_for_bot()
	if altar == null or card == null or not altar.can_replace_sacrifice_cost(card, game_manager):
		return {}
	var required := card.sacrifice_cost
	var valid_targets := altar.get_valid_void_targets(game_manager)
	if valid_targets.size() < required:
		return {}
	var chosen := _choose_lowest_altar_void_cards(valid_targets, required)
	if chosen.size() != required:
		return {}
	var penalty := 0
	for target in chosen:
		penalty += _score_altar_void_target(target)
	return {
		"sacrifice_cards": [],
		"altar_void_cards": chosen,
		"penalty": penalty,
	}

func _get_valid_summon_sacrifice_candidates() -> Array[Card]:
	var candidates: Array[Card] = []
	if bot_player == null:
		return candidates
	for zone in bot_player.frontline_zones + bot_player.reserve_zones:
		for card in zone.cards:
			if card != null \
				and card.card_type == Card.CardType.CREATURE \
				and not card.is_god \
				and card.can_be_used_for_creature_sacrifice \
				and card.get_controller() == bot_player \
				and card.current_zone != null \
				and card.current_zone.is_board_zone():
				candidates.append(card)
	return candidates

func _get_active_altar_of_dreams_for_bot() -> AltarOfDreams:
	for power in _get_player_powers():
		var altar := power as AltarOfDreams
		if altar != null and not altar.is_face_down:
			return altar
	return null

func _choose_lowest_summon_sacrifice_cards(candidates: Array[Card], required: int) -> Array[Card]:
	return _choose_lowest_scored_cards(candidates, required, "sacrifice")

func _choose_lowest_altar_void_cards(candidates: Array[Card], required: int) -> Array[Card]:
	return _choose_lowest_scored_cards(candidates, required, "altar")

func _choose_lowest_scored_cards(candidates: Array[Card], required: int, score_mode: String) -> Array[Card]:
	var chosen: Array[Card] = []
	var used_uids := {}
	for _i in range(required):
		var best_card: Card = null
		var best_score := 1000000000
		for candidate in candidates:
			if candidate == null or used_uids.has(candidate.uid):
				continue
			var candidate_score := _score_lowest_selection_candidate(candidate, score_mode)
			if best_card == null or candidate_score < best_score or (candidate_score == best_score and _get_card_order_index(candidate) < _get_card_order_index(best_card)):
				best_card = candidate
				best_score = candidate_score
		if best_card == null:
			return []
		chosen.append(best_card)
		used_uids[best_card.uid] = true
	return chosen

func _score_lowest_selection_candidate(card: Card, score_mode: String) -> int:
	match score_mode:
		"altar":
			return _score_altar_void_target(card)
		_:
			return _score_summon_sacrifice_candidate(card)

func _score_summon_sacrifice_candidate(card: Card) -> int:
	if card == null:
		return 1000000
	var score := _score_projected_card(card)
	if card.is_sleeping:
		score -= 900
	if card.creature_mode == Card.CreatureMode.DEFENSIVE:
		score -= 250
	if not card.can_take_major_creature_action():
		score -= 300
	if card.current_zone != null and card.current_zone.zone_type == Zone.ZoneType.RESERVE:
		score -= 150
	if card is Askelladen:
		score += 2500
	if card is EnkiLordOfEridu:
		score += 2200
	if card.has_type("Guardian"):
		score += 500
	return score

func _score_altar_void_target(card: Card) -> int:
	if card == null:
		return 1000000
	if card.card_owner == opponent:
		return -1500 - _score_enemy_target(card)
	var score := _score_friendly_target(card)
	if card.is_sleeping:
		score -= 900
	if card.current_zone != null and card.current_zone.zone_type == Zone.ZoneType.RESERVE:
		score -= 150
	if card is Askelladen:
		score += 2500
	if card is EnkiLordOfEridu:
		score += 2200
	return score
