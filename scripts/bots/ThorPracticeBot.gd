extends RefCounted
class_name ThorPracticeBot

const CardPromptPolicy = preload("res://scripts/bots/BotCardPromptPolicy.gd")
const CardStrategy = preload("res://scripts/bots/BotCardStrategy.gd")

var game_manager: GameManager = null
var match_manager: MatchManager = null
var game_input: GameInput = null
var player_index: int = -1
var bot_player: Player = null
var opponent: Player = null
# An optional selector responder for manual sandboxes; empty means full play.
var prompt_types_only: Array[String] = []
var get_step_delay: Callable

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
var _answered_prompt_ids: Dictionary = {}
var _current_card_prompt_id: int = -1
var _last_submitted_prompt_id: int = -1
var _strategy_activation_turns: Dictionary = {}
var _pending_power_activation_uid := ""

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
	_answered_prompt_ids.clear()
	_strategy_activation_turns.clear()
	_pending_power_activation_uid = ""
	_current_card_prompt_id = -1
	_last_submitted_prompt_id = -1

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
		_pending_power_activation_uid = ""
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
	if not prompt_types_only.is_empty() and type not in prompt_types_only:
		return
	if type == "priority":
		_queue_step()
		return
	if not _mark_prompt_answered(data):
		return
	var previous_prompt_id := _current_card_prompt_id
	_current_card_prompt_id = int(data.get("_prompt_id", -1))
	_answer_card_prompt(type, data)
	_current_card_prompt_id = previous_prompt_id

func _answer_card_prompt(type: String, data: Dictionary) -> void:
	var command := CardPromptPolicy.build_command(self, type, data)
	if not command.is_empty():
		_submit_action(command)
		return
	match type:
		"intercept":
			_submit_intercept_decision(_choose_interceptor(data))
		"harii_jarl_impact":
			_handle_harii_jarl_impact_prompt(data)
		"combat_retreat":
			_handle_combat_retreat_prompt(data)
		"nusku_well_of_fire":
			_handle_nusku_well_of_fire_prompt(data)
		"ragnarok_discard":
			_submit_ragnarok_discard(data)
		_:
			_answered_prompt_ids.erase(str(_current_card_prompt_id))
			push_warning("Bot has no valid answer for card prompt: %s" % type)

func _mark_prompt_answered(data: Dictionary) -> bool:
	var prompt_id := int(data.get("_prompt_id", -1))
	if prompt_id < 0:
		return true
	var key := str(prompt_id)
	if _answered_prompt_ids.has(key):
		return false
	_answered_prompt_ids[key] = true
	return true

func _forget_rejected_prompt() -> void:
	if _last_submitted_prompt_id >= 0:
		_answered_prompt_ids.erase(str(_last_submitted_prompt_id))
	_last_submitted_prompt_id = -1

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
	var delay := float(get_step_delay.call()) if get_step_delay.is_valid() else STEP_DELAY_SECONDS
	tree.create_timer(delay).timeout.connect(_run_step, CONNECT_ONE_SHOT)

func _should_retry_poll_later() -> bool:
	if not prompt_types_only.is_empty():
		return false
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
	if not prompt_types_only.is_empty():
		return false
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
	var zone := _get_first_open_summon_zone(bot_player)
	if zone != null:
		for card in bot_player.hand_zone.cards:
			if card is Skoll and card.can_use_upkeep_summon(game_manager):
				var normal := _get_best_affordable_hand_creature(game_manager.get_effective_upkeep_mana_gain(game_manager.get_base_upkeep_mana_gain(), bot_player))
				if normal == null or _score_projected_card(card) >= _score_projected_card(normal):
					var mode := _choose_creature_summon_mode(card)
					var stealth := _should_summon_creature_stealthily(card, zone, mode)
					var mode_name := "stealth" if stealth else "aggressive" if mode == Card.CreatureMode.AGGRESSIVE else "defensive"
					_submit_action({"type": "skoll_upkeep_summon", "skoll_uid": card.uid, "player_index": player_index, "zone_type": zone.zone_type, "zone_index": zone.zone_index, "mode": mode_name})
					return
	var choice := _choose_upkeep_option()
	var brood_card := _choose_brood_card(zone, choice)
	if brood_card != null and _submit_action({"type": "tiamat_upkeep_choice", "card_uid": brood_card.uid}):
		return
	_submit_action({
		"type": "upkeep_choice",
		"choice": choice,
	})

func _choose_brood_card(zone: Zone, upkeep_choice: String) -> Card:
	if not TiamatThePrimordial.can_offer_matriarch_rule(game_manager):
		return null
	var brood_cards := TiamatThePrimordial.get_available_matriarch_rule_cards(bot_player)
	var best_card: Card = null
	var best_score := 0
	var extra_mana := 0
	if upkeep_choice == "mana":
		extra_mana = game_manager.get_effective_upkeep_mana_gain(game_manager.get_base_upkeep_mana_gain(), bot_player)
	var hand_card := _get_best_affordable_hand_creature(extra_mana, zone)
	if hand_card != null:
		best_score = _score_creature_play(hand_card, zone, bot_player.mana + extra_mana)
	if upkeep_choice == "mana":
		if hand_card == null:
			return null
		best_score += 900
	for card in brood_cards:
		var score := _score_creature_play_in_zone(card, zone, bot_player.mana)
		if not _opponent_board_is_empty() and _choose_creature_summon_mode(card) == Card.CreatureMode.DEFENSIVE:
			var block_value := _estimate_defensive_summon_value(card, zone)
			if block_value <= 0:
				continue
			score += int(block_value * 0.5)
		if score > best_score:
			best_card = card
			best_score = score
	if best_card == null and upkeep_choice == "draw" and bot_player.deck_zone.cards.is_empty():
		return _pick_best_board_creature(brood_cards)
	return best_card

func _choose_upkeep_option() -> String:
	var draw_mana_gain := GameManager.UPKEEP_DRAW_MANA_GAIN
	var mana_gain := GameManager.UPKEEP_MANA_GAIN
	if game_manager != null:
		draw_mana_gain = game_manager.get_base_upkeep_draw_mana_gain()
		mana_gain = game_manager.get_base_upkeep_mana_gain()
		draw_mana_gain = game_manager.get_effective_upkeep_mana_gain(draw_mana_gain, bot_player)
		mana_gain = game_manager.get_effective_upkeep_mana_gain(mana_gain, bot_player)
	var best_now := _get_best_affordable_hand_creature(draw_mana_gain)
	var best_with_bonus := _get_best_affordable_hand_creature(mana_gain)
	if best_now == null and best_with_bonus != null:
		return "mana"
	var zone := _get_first_open_summon_zone(bot_player)
	var draw_score := 0 if best_now == null else _score_creature_play(best_now, zone, bot_player.mana + draw_mana_gain)
	var mana_score := 0 if best_with_bonus == null else _score_creature_play(best_with_bonus, zone, bot_player.mana + mana_gain)
	if best_now != null:
		draw_score += _estimate_summon_attack_value(best_now, zone, bot_player.mana + draw_mana_gain)
	if best_with_bonus != null:
		mana_score += _estimate_summon_attack_value(best_with_bonus, zone, bot_player.mana + mana_gain)
	if mana_score - draw_score > (900 if bot_player.hand_zone.cards.size() >= 4 else 1800):
		return "mana"
	if _upkeep_mana_enables_manifestation(mana_gain):
		return "mana"
	if bot_player.hand_zone.cards.size() >= 3:
		for card in bot_player.hand_zone.cards:
			if CardStrategy.supported(card) and card is SpellCard and card.sacrifice_cost == 0:
				var cost := _get_play_cost(card, false)
				if cost > bot_player.mana + draw_mana_gain and cost <= bot_player.mana + mana_gain:
					var target := CardStrategy.best_target(self, card, CardStrategy.targets(self, card))
					if (not card.targets or target != null) and CardStrategy.effect_score(self, card, target) > ECON_CARD_VALUE:
						return "mana"
	return "draw"

func _upkeep_mana_enables_manifestation(mana_gain: int) -> bool:
	if mana_gain <= 0 or _get_first_open_summon_zone(bot_player) == null:
		return false
	var god := _find_player_god()
	if god == null or not game_manager.can_player_use_powers(bot_player):
		return false
	if not god.is_muted and god.has_champions_call():
		var manifestation := god.get_champions_call_candidate(true)
		if manifestation != null:
			var cost := game_manager.get_creature_summon_mana_cost(bot_player, manifestation, god)
			if cost > bot_player.mana and cost <= bot_player.mana + mana_gain:
				return true
	for power in _get_player_powers():
		if power is TakeTheField and power.is_face_down and not power.is_muted and not power.is_activation_locked(game_manager):
			var cost: int = power.get_unlock_display_mana_cost(game_manager)
			if cost > bot_player.mana and cost <= bot_player.mana + mana_gain:
				return true
	return false

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
		var danger := _forecast_incoming_follower_loss() if game_manager.current_player == bot_player else -1
		for response_card in responses:
			if response_card is MeadOfPoetry and _target_includes_card(top_action.target, response_card):
				return response_card
		var best_wheel := _find_best_priority_wheel_response(responses, top_action)
		var best_card: Card = best_wheel.get("card", null)
		var best_score := int(best_wheel.get("score", 0))
		for response_card in responses:
			if not CardStrategy.supported(response_card) and not response_card is E2Abzu:
				continue
			var response := _score_priority_card(response_card, top_action, danger)
			var score := int(response["score"])
			if score > best_score:
				best_card = response_card
				best_score = score
		if best_card != null:
			return best_card
	if _should_activate_prepared_mead_for_enki():
		for response_card in responses:
			if response_card is MeadOfPoetry:
				return response_card
	return null

func _score_priority_card(card: Card, action: CardAction, danger: int) -> Dictionary:
	var targets := CardStrategy.targets(self, card, action)
	if targets.is_empty():
		targets = [null]
	var best := {"score": CardStrategy.BAD, "target": null}
	for target: Card in targets:
		var score := CardStrategy.effect_score(self, card, target, action)
		var removed := CardStrategy.removal_targets(self, card, target, action)
		if score <= CardStrategy.BAD and removed.is_empty():
			continue
		if not removed.is_empty():
			if score <= CardStrategy.BAD:
				score = -CardStrategy.mana_penalty(self, CardStrategy.activation_cost(self, card))
				for victim: Card in removed:
					score += CardStrategy.value(self, victim) if victim.get_controller() == opponent else -CardStrategy.value(self, victim)
			if card is E2Abzu:
				score -= E2Abzu.VOID_AND_RETURN_COST * ECON_MANA_VALUE
			if action.type == CardAction.Type.ATTACK and CardStrategy.combat_visible(self, action):
				var both_attackers_removed := action.attacker in removed and (action.united_front_partner == null or action.united_front_partner in removed)
				if both_attackers_removed or _get_attack_defender_card(action) in removed:
					var combat_score := _score_attack_economy(_estimate_attack_economy(action, null, 0, 0))
					score = maxi(score, -combat_score - ECON_CARD_VALUE)
			score += _follower_safety_gain(danger, {"removed": removed})
		elif (card is Dromi or card is Gleipnir) and target != null and score > CardStrategy.BAD:
			score += _follower_safety_gain(danger, {"disable_attacker": target})
		if score > int(best["score"]):
			best = {"score": score, "target": target}
	return best

func _target_includes_card(target_value, card: Card) -> bool:
	if target_value is Card:
		return target_value == card
	if target_value is Array:
		for entry in target_value:
			if _target_includes_card(entry, card):
				return true
	elif target_value is Dictionary:
		for entry in target_value.values():
			if _target_includes_card(entry, card):
				return true
	return false

func _submit_priority_response(card: Card) -> bool:
	if card == null or game_manager.action_stack.is_empty():
		return false
	var top_action: CardAction = game_manager.action_stack.back()
	var danger := _forecast_incoming_follower_loss() if game_manager.current_player == bot_player else -1
	if card is HexCard:
		var targets := game_manager.get_priority_hex_targets(card as HexCard, top_action)
		var target_uid := ""
		if card is WheelOfFire:
			var chosen_target := _choose_best_wheel_of_fire_target(card as WheelOfFire, targets, top_action)
			target_uid = chosen_target.uid if chosen_target != null else ""
		elif CardStrategy.supported(card):
			var chosen_target := _score_priority_card(card, top_action, danger)["target"] as Card
			target_uid = chosen_target.uid if chosen_target != null else ""
		else:
			target_uid = _choose_target_uid_for_source(card, targets)
		var needs_target := bool(card.get("targets"))
		if card.has_method("requires_priority_target_selection"):
			needs_target = card.requires_priority_target_selection()
		if needs_target and target_uid.is_empty():
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
		if CardStrategy.supported(card):
			var target := _score_priority_card(card, top_action, danger)["target"] as Card
			target_uid = target.uid if target != null else ""
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
		if CardStrategy.supported(card) or card is E2Abzu:
			var target := _score_priority_card(card, top_action, danger)["target"] as Card
			target_uid = target.uid if target != null else ""
		if bool(card.get("targets")) and target_uid.is_empty():
			return false
		return _submit_action({
			"type": "play_priority_ability",
			"source_uid": card.uid,
			"target_uid": target_uid,
		})
	return false

func _take_main_phase_action() -> bool:
	var attacks := _get_combat_candidates()
	var combat := _plan_combat(attacks)
	var attack := combat
	if int(combat.get("score", 0)) >= ECON_CARD_VALUE * 20:
		return _submit_attack(attack["attacker"], attack["target"])
	if game_manager.turn_number > 1:
		var supported := _get_best_supported_attack(_get_attack_ready_creatures(), _get_board_creatures(opponent))
		if int(supported.get("score", 0)) > int(attack.get("score", 0)):
			attack = supported
	if _try_activate_mead_for_enki():
		return true
	var danger := _forecast_incoming_follower_loss()
	var summon := _plan_creature_summon(danger, attacks, combat)
	var play := _get_best_strategy_action(attacks, combat, danger, summon)
	var manifestation := _plan_god_manifestation(attack, danger)
	var unlock := _plan_power_unlock(danger)
	var defenses := [
		play, manifestation, unlock, _plan_defensive_stance(danger), _plan_removal_god_ability(danger),
		summon, _plan_power_activation(null, danger), _plan_strategy_support(danger), _plan_hermes_speed(attacks, attack),
	]
	if danger >= bot_player.followers:
		defenses.append(_plan_defensive_attack(attacks, danger))
	defenses.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return int(a.get("score", 0)) > int(b.get("score", 0)))
	for defense in defenses:
		if int(defense.get("score", 0)) >= ECON_CARD_VALUE * 20 and _submit_strategy_plan(defense):
			return true
	if not _pending_power_activation_uid.is_empty():
		var power := game_manager.get_card_by_uid(_pending_power_activation_uid) as PowerCard
		_pending_power_activation_uid = ""
		if power != null and _submit_strategy_plan(_plan_power_activation(power)):
			return true
	if _try_activate_best_god_ability():
		return true
	if _try_summon_askelladen_answer():
		return true
	var united_front := _plan_united_front(attacks, attack)
	var plans := [united_front]
	plans.append_array(defenses)
	plans.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return int(a.get("score", 0)) > int(b.get("score", 0)))
	var attack_score := int(attack.get("score", 0))
	var delayed: Array[Dictionary] = []
	for plan in plans:
		# A setup that improves the combat line can take priority even if its
		# standalone value is smaller than the attack already available.
		if not attack.is_empty() and int(plan.get("score", 0)) < attack_score / 2 \
				and int(plan.get("combat_score", 0)) <= attack_score:
			delayed.append(plan)
		elif _submit_strategy_plan(plan):
			return true
	if not delayed.is_empty() and not attack.is_empty() and _submit_attack(attack["attacker"], attack["target"]):
		return true
	for plan in delayed:
		if _submit_strategy_plan(plan):
			return true
	if _try_prepare_wheel_of_fire():
		return true
	if _try_prepare_vision_of_odin():
		return true
	if _try_prepare_strategy_card():
		return true
	if _try_prepare_mead_of_poetry():
		return true
	if _try_advance_from_reserve():
		return true
	if _try_switch_to_aggressive_mode(danger):
		return true
	if not attack.is_empty() and _submit_attack(attack["attacker"], attack["target"]):
		return true
	if _try_attack():
		return true
	if _try_switch_to_defensive_mode():
		return true
	return false

func _submit_strategy_plan(plan: Dictionary) -> bool:
	if plan.is_empty():
		return false
	var command: Dictionary = plan["command"]
	var submitted := _submit_action(command)
	if submitted and plan.has("once_per_turn_uid"):
		_strategy_activation_turns[plan["once_per_turn_uid"]] = game_manager.turn_number
	if submitted and plan.has("activate_after_unlock_uid"):
		_pending_power_activation_uid = plan["activate_after_unlock_uid"]
	return submitted

func _try_activate_mead_for_enki() -> bool:
	var mead := _find_ready_prepared_mead()
	if mead == null or not _should_activate_prepared_mead_for_enki():
		return false
	return _submit_cast_charm(mead, null, true)

func _try_activate_best_god_ability() -> bool:
	var god := _find_player_god()
	if god == null or not god.has_method("can_activate") or not god.can_activate(game_manager):
		return false

	if god is Freyja:
		var freyja := god as Freyja
		var revived_target := _choose_best_friendly_graveyard_target_for_source(freyja, freyja.get_valid_targets(game_manager))
		if revived_target != null:
			return _submit_action({
				"type": "god_ability",
				"god_uid": freyja.uid,
				"target_uid": revived_target.uid,
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
	return false

func _plan_hermes_speed(attacks: Array[Dictionary], baseline: Dictionary) -> Dictionary:
	var hermes := _find_player_god() as Hermes
	var best := {}
	if hermes == null or attacks.is_empty() or not hermes.can_activate(game_manager):
		return best
	var cost := Hermes.ACTIVATION_COST
	var penalty := CardStrategy.mana_penalty(self, cost)
	var baseline_score := int(baseline.get("score", 0))
	for target in hermes.get_valid_targets(game_manager):
		if target.get_controller() != bot_player or target.get_effective_speed(Hermes.SPEED_BONUS) == target.get_effective_speed() \
				or game_manager.is_immune_to_source(target, hermes) or game_manager.is_guardian_protected(target, hermes):
			continue
		var projected: Array[Dictionary] = []
		var updated: Array[Card] = []
		for attack in attacks:
			var attacker: Card = attack["attacker"]
			var partner: Card = attack["partner"]
			if target != attacker and target != partner:
				projected.append(attack)
			elif attacker not in updated:
				updated.append(attacker)
				projected.append_array(_get_attack_candidates(attacker, partner, false, target, Hermes.SPEED_BONUS))
		if updated.is_empty():
			continue
		var line := _plan_combat(projected, [], null, cost)
		var combat_score := int(line.get("score", 0))
		var score := combat_score - baseline_score - penalty
		if score > int(best.get("score", 0)):
			best = {"score": score, "combat_score": combat_score, "command": {
				"type": "god_ability", "god_uid": hermes.uid, "target_uid": target.uid,
			}}
	return best

func _plan_god_manifestation(attack: Dictionary = {}, danger: int = -1) -> Dictionary:
	var god := _find_player_god()
	if god is TezcatlipocaTheSmokingMirror:
		return _plan_necoc_yaotl(god, attack, danger)
	if god == null or not god.can_use_champions_call(game_manager):
		return {}
	var manifestation := god.get_champions_call_candidate(true)
	var zone := _get_first_open_summon_zone(bot_player)
	var mode := _choose_creature_summon_mode(manifestation)
	var shelve_count := god.get_champions_call_required_shelve_count(game_manager)
	var choices := god.get_champions_call_shelvable_hand_cards(manifestation)
	choices.sort_custom(_is_lower_priority_hand_card)
	var shelve_uids: Array[String] = []
	var shelve_penalty := 0
	for card in choices.slice(0, shelve_count):
		shelve_uids.append(card.uid)
		shelve_penalty += 900 + _get_hand_value(card) * 14
	var cost := game_manager.get_creature_summon_mana_cost(bot_player, manifestation, god)
	var mana_paid := maxi(0, cost - shelve_count * GodCard.CHAMPIONS_CALL_SHELVE_MANA_VALUE)
	var score := _score_god_manifestation(manifestation, mana_paid, mode) - shelve_penalty
	if score < 2200:
		return {}
	return {"score": score, "command": {
		"type": "god_ability",
		"god_uid": god.uid,
		"zone_type": zone.zone_type,
		"zone_index": zone.zone_index,
		"mode": "aggressive" if mode == Card.CreatureMode.AGGRESSIVE else "defensive",
		"shelve_uids": shelve_uids,
	}}

func _plan_necoc_yaotl(god: TezcatlipocaTheSmokingMirror, attack: Dictionary, danger: int) -> Dictionary:
	if not god.can_use_god_power(game_manager):
		return {}
	var command := {"type": "god_ability", "god_uid": god.uid}
	if god.can_resolve_necoc_yaotl_summon(game_manager):
		return {"score": 16000, "command": command}
	var sacrifices := god.get_valid_targets(game_manager)
	if sacrifices.is_empty():
		return {}
	var stored_count := god.get_necoc_yaotl_sacrifices().size()
	var final_sacrifice := stored_count == TezcatlipocaTheSmokingMirror.REQUIRED_NECOC_YAOTL_SACRIFICES - 1
	var board_count := _board_creature_count(bot_player)
	# Early offerings buy progress, so favor bodies the board can spare afterward.
	var spare_creatures := clampi(board_count - 1 - maxi(1, _board_creature_count(opponent)), 0, 3)
	var payoff := 2200 + spare_creatures * 850 + stored_count * 450
	var level_budget := god.get_necoc_yaotl_total_level()
	var steal_uids: Array[String] = []
	var manifestation: TezcatlipocaActive = null
	var open_summon_zones: Array[Zone] = []
	var defensive_summon := false
	# The sacrifice frees one space and the manifestation takes one.
	var steal_limit := mini(TezcatlipocaActive.MAX_TITLACAUAN_TARGETS, CardStrategy.open_spaces(bot_player))
	if final_sacrifice:
		var forms := god.get_hover_summoned_active_gods()
		if forms.is_empty() or not forms[0] is TezcatlipocaActive:
			return {}
		manifestation = forms[0] as TezcatlipocaActive
		open_summon_zones = god.get_champions_call_open_zones()
		defensive_summon = game_manager._any_active_structure_forces_defensive_summon()
		if not game_manager.can_pay_creature_summon_cost(bot_player, manifestation, god, false):
			return {}
		var mana_cost := game_manager.get_creature_summon_mana_cost(bot_player, manifestation, god, true)
		# The Active God replaces the normal god's Tonal Mastery engine.
		payoff = CardStrategy.value(self, manifestation) - 2000 - mana_cost * ECON_MANA_VALUE
		if steal_limit > 0:
			for target in manifestation.get_valid_titlacauan_targets(game_manager):
				if CardStrategy.visible(self, target):
					steal_uids.append(target.uid)
	if danger < 0:
		danger = _forecast_incoming_follower_loss()
	var attacker := attack.get("attacker") as Card
	var partner := match_manager._get_declared_attack_partner(attacker)
	var best_score := 0
	var best_sacrifice: Card = null
	for card in sacrifices:
		var body_cost := ECON_CARD_VALUE if final_sacrifice else ECON_CARD_VALUE / 2
		if card.is_token:
			body_cost /= 2
		var score := payoff - body_cost - maxi(0, _score_summon_sacrifice_candidate(card))
		score -= card.equipment.size() * (ECON_CARD_VALUE / 2)
		if card == attacker or card == partner:
			score -= int(attack.get("score", 0)) / 2
		var removed: Array[Card] = [card]
		if not steal_uids.is_empty():
			var stolen := CardStrategy.budget_choices(self, steal_uids, level_budget + card.get_effective_level(), steal_limit, true)
			for uid in stolen:
				var target := game_manager.get_card_by_uid(uid)
				score += CardStrategy.value(self, target)
				removed.append(target)
		var change := {"removed": removed}
		if manifestation != null:
			# Frontline has priority. The exact lane within a row does not affect interception.
			var zone := card.current_zone
			if not open_summon_zones.is_empty() and (zone in bot_player.reserve_zones or open_summon_zones[0] in bot_player.frontline_zones):
				zone = open_summon_zones[0]
			change.merge({"summon": manifestation, "zone": zone, "stance": manifestation, "defensive": defensive_summon})
		var safety_gain := _follower_safety_gain(danger, change)
		var prevents_lethal := safety_gain >= ECON_CARD_VALUE * 30
		if not final_sacrifice and (board_count <= 1 or danger >= bot_player.followers) and not prevents_lethal:
			continue
		score += safety_gain
		if score > best_score:
			best_score = score
			best_sacrifice = card
	if best_sacrifice == null:
		return {}
	command["target_uid"] = best_sacrifice.uid
	return {"score": best_score, "command": command}

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

func _plan_creature_summon(danger: int = -1, attacks: Array[Dictionary] = [], baseline: Dictionary = {}, removed_by_setup: Array = [], setup_cost: int = 0) -> Dictionary:
	if game_manager == null or opponent == null:
		return {}
	var zone := _get_first_open_summon_zone(bot_player)
	if zone == null:
		return {}
	var zones: Array[Zone] = [zone]
	var reserve := _get_first_open_reserve_zone(bot_player)
	if reserve != null and reserve != zone:
		zones.append(reserve)
	var best := {}
	var best_score := 0
	var available_mana := bot_player.mana - setup_cost
	var baseline_score := int(baseline.get("score", 0))
	var enemies := _get_board_creatures(opponent).filter(func(enemy: Card) -> bool: return enemy not in removed_by_setup)
	for summon_zone in zones:
		for creature in bot_player.hand_zone.cards:
			# Future payment choices must still be legal after the first action.
			if not removed_by_setup.is_empty() and (creature.sacrifice_cost > 0 or creature.discard_cost > 0):
				continue
			var score := _score_creature_play(creature, summon_zone, available_mana)
			if score <= -1000000:
				continue
			var payment_forecast := danger if creature.sacrifice_cost > 0 and (danger >= bot_player.followers or bot_player.followers <= 25) else -1
			var prior_payment_penalty := 0
			if payment_forecast >= 0:
				prior_payment_penalty = int(_build_creature_summon_payment_plan(creature).get("penalty", 0))
			var face_up_block_value := _estimate_defensive_summon_value(creature, summon_zone) / 2
			var reveal_defender := _estimate_reveal_trigger_value(creature) > 0
			var stealth_block_value := 0
			if reveal_defender:
				stealth_block_value = _estimate_defensive_summon_value(creature, summon_zone, true) / 2
			var block_value := maxi(face_up_block_value, stealth_block_value)
			var mode := _choose_creature_summon_mode(creature, enemies)
			if block_value > 0 and removed_by_setup.is_empty():
				mode = Card.CreatureMode.DEFENSIVE
			var modes := [mode]
			var summon_attacks := _get_summon_attack_candidates(creature, summon_zone, available_mana)
			if danger > 0 or not summon_attacks.is_empty():
				modes.append(Card.CreatureMode.DEFENSIVE if mode == Card.CreatureMode.AGGRESSIVE else Card.CreatureMode.AGGRESSIVE)
			var mana_spent := setup_cost + _get_play_cost(creature, false)
			var aggressive_attacks := attacks + summon_attacks
			for summon_mode in modes:
				var defensive: bool = summon_mode == Card.CreatureMode.DEFENSIVE
				var projected_defensive := defensive or game_manager._any_active_structure_forces_defensive_summon()
				var command := _build_creature_play_command(creature, summon_zone, summon_mode, payment_forecast, projected_defensive)
				if command.is_empty():
					continue
				var default_stealth := bool(command["stealth"]) and face_up_block_value <= 0 and danger <= 0
				var stealth_options := [default_stealth]
				if defensive and reveal_defender:
					stealth_options = [default_stealth, not default_stealth]
				var removed := removed_by_setup.duplicate()
				for uid in command["sacrifice_uids"] + command["altar_void_uids"]:
					removed.append(game_manager.get_card_by_uid(uid))
				var projected := attacks if projected_defensive else aggressive_attacks
				var line := _plan_combat(projected, removed, null, mana_spent)
				var combat_score := int(line.get("score", 0))
				var attack_value := combat_score - baseline_score
				for stealth: bool in stealth_options:
					var defensive_value := stealth_block_value if stealth and reveal_defender else face_up_block_value
					var candidate := score + (defensive_value if projected_defensive and removed_by_setup.is_empty() else 0) + attack_value
					candidate += prior_payment_penalty - int(command.get("payment_penalty", 0))
					var change := {
						"removed": removed, "summon": creature, "zone": summon_zone, "stance": creature,
						"defensive": projected_defensive, "stealth": stealth,
					}
					var safety := _follower_safety_gain(danger, change)
					if not stealth and danger > 0:
						safety = _score_summon_removal(creature, danger, change, safety)
					candidate += safety
					if candidate > best_score:
						best = {"command": command.duplicate(), "score": candidate, "combat_score": combat_score}
						best["command"]["stealth"] = stealth
						best["command"].erase("payment_penalty")
						best_score = candidate
	return best

func _score_summon_removal(creature: Card, danger: int, change: Dictionary, baseline: int) -> int:
	var options: Array[Dictionary] = []
	if creature is Fenrir:
		options.append({"source": creature, "targets": creature.get_valid_devour_targets(game_manager)})
	elif creature is GugalannaBullOfHeaven:
		options.append({"source": creature, "targets": creature.get_valid_impact_targets(game_manager)})
	if creature.has_type("Demon") and not creature.abilities_suppressed_by_effects():
		for power in _get_player_powers():
			if power is Terror and power.is_effectively_active():
				options.append({"source": power, "targets": power.get_valid_terror_targets(game_manager, creature)})
	if options.is_empty():
		return baseline
	var best := baseline
	for option in options:
		var source := option["source"] as Card
		for target: Card in option["targets"]:
			if target in change["removed"] or CardStrategy.removal_targets(self, source, target).is_empty():
				continue
			if source is Terror and (not game_manager.can_player_add_to_hand_now(target.card_owner) \
					or (CardStrategy.visible(self, target) and game_manager.is_immune_to_source(target, creature))):
				continue
			var projected := change.duplicate()
			projected["removed"] = change["removed"] + [target]
			if source is GugalannaBullOfHeaven and game_manager.can_player_add_to_hand_now(bot_player):
				projected.erase("summon")
			var score := _follower_safety_gain(danger, projected)
			best = maxi(best, score)
	return best

func _get_summon_attack_candidates(card: Card, zone: Zone, available_mana: int) -> Array[Dictionary]:
	if zone.zone_type != Zone.ZoneType.FRONTLINE or game_manager.turn_number <= 1 \
			or game_manager.has_resolved_attack_this_turn or game_manager.attack_restrictions.has(bot_player) \
			or game_manager._any_active_structure_forces_defensive_summon() \
			or game_manager.is_first_turn_attack_blocked_by_weather(card, true):
		return []
	var attack_cost := game_manager.get_creature_action_mana_cost(card, "attack")
	if _get_play_cost(card, false) + attack_cost > available_mana:
		return []
	return _get_attack_candidates(card, null, true)

func _estimate_summon_attack_value(card: Card, zone: Zone, available_mana: int) -> int:
	var attack_cost := game_manager.get_creature_action_mana_cost(card, "attack")
	var best_value := 0
	for candidate in _get_summon_attack_candidates(card, zone, available_mana):
		var result := _project_attack(candidate)
		if result.is_empty():
			continue
		var score := _score_attack_economy(result) - attack_cost * ECON_MANA_VALUE
		best_value = maxi(best_value, score)
	# A summon can give the opponent a response window before the attack.
	return int(best_value * 0.75)

func _opponent_board_is_empty() -> bool:
	return _get_board_creatures(opponent).is_empty()


func _estimate_defensive_summon_value(card: Card, zone: Zone, stealth: bool = false) -> int:
	if card == null or zone == null or zone not in bot_player.frontline_zones + bot_player.reserve_zones:
		return 0
	if _status_persists_to_next_turn(card, "cannot_intercept"):
		return 0
	var best_gain := 0
	for attacker in _get_board_creatures(opponent):
		if not CardStrategy.visible(self, attacker) or attacker.current_zone.zone_type != Zone.ZoneType.FRONTLINE \
				or attacker.creature_mode != Card.CreatureMode.AGGRESSIVE \
				or attacker.has_status_effect("cannot_attack") \
				or not game_manager.can_cards_engage_each_other(card, attacker) \
				or not game_manager.can_interceptor_engage_attacker(card, attacker):
			continue
		if game_manager.is_followers_attack_blocked_by_active_structure(attacker, bot_player, []):
			continue
		var projected_speed := attacker.get_effective_speed()
		var partner := match_manager._get_declared_attack_partner(attacker)
		if partner != null:
			if not CardStrategy.visible(self, partner):
				continue
			projected_speed = mini(projected_speed, partner.get_effective_speed())
		var speed_delta := -1 if stealth and not card.is_stealth else 0
		if not match_manager._can_intercept(card, attacker, bot_player, card, speed_delta, projected_speed, zone, Card.CreatureMode.DEFENSIVE):
			continue
		var action := CardAction.new()
		action.type = CardAction.Type.ATTACK
		action.attacker = attacker
		action.united_front_partner = partner
		action.target = bot_player
		var best_existing_score := _score_attack_economy(_estimate_attack_economy(action, null, 0, 0))
		for existing in match_manager._get_possible_interceptors(attacker, bot_player):
			action.interceptor = existing
			best_existing_score = maxi(best_existing_score, _score_attack_economy(_estimate_attack_economy(action, null, 0, 0)))
		action.interceptor = card
		var result := _estimate_attack_economy(action, null, 0, 0, 0, true, Card.CreatureMode.DEFENSIVE, stealth)
		var candidate_score := _score_attack_economy(result)
		best_gain = maxi(best_gain, candidate_score - best_existing_score)
	return best_gain

func _is_enemy_creature_answer(card: Card, target: Card, score: int) -> bool:
	if card == null or target == null or score <= 0 or target.get_controller() != opponent:
		return false
	if target.card_type != Card.CardType.CREATURE:
		return false
	return CardStrategy.key(card) in [
		"DivineLightning", "RunicSpellbreaker", "BitMeseri", "ClayEaters", "Alu", "Nimue",
		"Dromi", "Gleipnir", "Snowball", "SapStrength", "VisionOfTartarus", "Absence",
		"Sap", "SepLemutti", "Lindwyrm", "GungnirTheSpearOfOdin",
	]

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

func _get_best_strategy_action(attacks: Array[Dictionary], attack: Dictionary, danger: int = -1, summon: Dictionary = {}) -> Dictionary:
	var best_plan: Dictionary = {}
	var best_score := 0
	var cards: Array = bot_player.hand_zone.cards.duplicate()
	cards.append_array(game_manager.get_field_cards(bot_player))
	for card in cards:
		if card is BlotSacrifice or card is KeyOfSolomon:
			var paid_plan := _plan_sacrifice_spell(card, danger)
			if int(paid_plan.get("score", 0)) > best_score:
				best_score = paid_plan["score"]
				best_plan = paid_plan
			continue
		if card is DeucalionsInfants:
			var infants_plan := _plan_deucalions_infants(card, danger)
			if int(infants_plan.get("score", 0)) > best_score:
				best_score = infants_plan["score"]
				best_plan = infants_plan
			continue
		if card is ErlqueensNightingale or card is KurJara or card is TezcatlipocaBlasphemer:
			var withdrawal := _plan_board_withdrawal(card, danger)
			if int(withdrawal.get("score", 0)) > best_score:
				best_score = withdrawal["score"]
				best_plan = withdrawal
			continue
		if CardStrategy.supported(card) and (card is SpellCard or card is CharmCard):
			if card.discard_cost > 0 or card.sacrifice_cost > 0:
				continue
			if card is SpellCard:
				if card.is_prepared:
					if not card.can_activate_prepared(game_manager, bot_player):
						continue
				elif not game_manager.can_play_card(bot_player, card, null):
					continue
			else:
				if card.is_prepared:
					if not card.can_activate_prepared(game_manager):
						continue
				elif not card.can_activate_from_hand(game_manager):
					continue
			var targets := CardStrategy.targets(self, card)
			if targets.is_empty() and not card.targets:
				targets = [null]
			var reserve := _get_first_open_reserve_zone(bot_player)
			if not card.goes_to_graveyard_after_use() and not card.is_prepared and reserve == null:
				continue
			for target: Card in targets:
				if not game_manager.get_turn_destruction_ward_activation_block_reason(card, target).is_empty():
					continue
				var score := CardStrategy.effect_score(self, card, target)
				if score <= CardStrategy.BAD:
					continue
				if _is_enemy_creature_answer(card, target, score):
					score += 6500 + _score_follower_loss(opponent, target.get_effective_strength()) / 4
				var removed := CardStrategy.removal_targets(self, card, target)
				var combat_score := int(attack.get("score", 0))
				if removed.is_empty():
					score += _effect_follower_safety_gain(card, target, danger)
				else:
					var cost := CardStrategy.activation_cost(self, card)
					var opened := _plan_combat(attacks, removed, null, cost)
					combat_score = int(opened.get("score", 0))
					var after_removal := score + combat_score - int(attack.get("score", 0)) \
						+ _follower_safety_gain(danger, {"removed": removed})
					# Compare removal followed by an aggressive summon with summoning into the current board.
					# Persistent cards may occupy the projected summon lane, so only project one-shot effects here.
					if card.goes_to_graveyard_after_use() and not game_manager.has_resolved_attack_this_turn \
							and removed.any(func(victim: Card) -> bool: return victim.get_controller() == opponent):
						var followup := _plan_creature_summon(danger, attacks, attack, removed, cost)
						var followup_score := int(followup.get("combat_score", 0))
						if not followup.is_empty() and followup["command"]["mode"] == Card.CreatureMode.AGGRESSIVE \
								and followup_score > maxi(combat_score, int(summon.get("combat_score", 0))) \
								and score + int(followup.get("score", 0)) > after_removal:
							after_removal = score + int(followup["score"])
							combat_score = followup_score
					score = after_removal
				if score <= best_score:
					continue
				best_score = score
				var command := {"type": "cast_spell" if card is SpellCard else "cast_charm", "target_uid": target.uid if target != null else "", "prepared": card.is_prepared}
				command["spell_uid" if card is SpellCard else "charm_uid"] = card.uid
				if not card.goes_to_graveyard_after_use() and not card.is_prepared and reserve != null:
					command["display_zone"] = {"player_index": player_index, "zone_type": reserve.zone_type, "zone_index": reserve.zone_index}
				best_plan = {"command": command, "score": score, "combat_score": combat_score}
		elif CardStrategy.key(card) in CardStrategy.BOARD_ABILITIES and card.current_zone != bot_player.hand_zone:
			if card.is_face_down or card.is_prepared or card.abilities_suppressed() or card.is_activation_locked(game_manager) or not card.can_activate(game_manager):
				continue
			var id := CardStrategy.key(card)
			var action_tax := game_manager.get_creature_action_mana_cost(card, "activate") if card is CreatureCard else 0
			var targets := [null] if id == "Beyla" else CardStrategy.targets(self, card)
			for target: Card in targets:
				var score := CardStrategy.wake_gain(self, card) if id == "Beyla" else CardStrategy.target_score(self, card, target)
				if score <= CardStrategy.BAD:
					continue
				var cost := 1 if id == "ClayEaters" else 2 if id in ["AncientPyre", "Gawain", "Beyla"] else 0
				if id == "Nimue" and target != null and target.card_type == Card.CardType.CREATURE:
					cost = target.get_effective_level()
					if target.get_controller() == opponent:
						var opened := _plan_combat(attacks, CardStrategy.removal_targets(self, card, target), card, cost + action_tax)
						score += maxi(0, int(opened.get("score", 0)) - int(attack.get("score", 0)))
				if bot_player.mana < cost + action_tax:
					continue
				score -= CardStrategy.mana_penalty(self, cost) + action_tax * ECON_MANA_VALUE
				if id in ["Alu", "Lindwyrm", "Nimue"]:
					score -= _score_follower_loss(opponent, card.get_effective_strength())
				score += _effect_follower_safety_gain(card, target, danger)
				if score > best_score:
					best_score = score
					best_plan = {"command": {"type": "activate_card_ability", "source_uid": card.uid, "target_uid": target.uid if target != null else ""}, "score": score}
			if id == "AncientPyre" and game_manager.can_player_lose_followers_now(opponent):
				var conversion_score := _score_follower_loss(opponent, 5) + CardStrategy.follower_gain(bot_player, 5) - CardStrategy.mana_penalty(self, 2)
				if conversion_score > best_score:
					best_score = conversion_score
					best_plan = {"command": {"type": "activate_card_ability", "source_uid": card.uid, "option": {"mode": "convert"}}, "score": conversion_score}
	return best_plan

func _effect_follower_safety_gain(card: Card, target: Card, danger: int) -> int:
	if danger < 0:
		return 0
	var removed := CardStrategy.removal_targets(self, card, target)
	if not removed.is_empty():
		return _follower_safety_gain(danger, {"removed": removed})
	match CardStrategy.key(card):
		"Alu":
			if target != null:
				return _follower_safety_gain(danger, {"disable_attacker": target})
		"BookOfLife":
			var change := {"followers": bot_player.followers + BookOfLife.FOLLOWERS_GAINED}
			var zone := _get_first_open_summon_zone(bot_player)
			if target != null and zone != null:
				change.merge({"summon": target, "zone": zone, "stance": target, "defensive": false})
			return _follower_safety_gain(danger, change)
	return 0

func _plan_deucalions_infants(spell: DeucalionsInfants, danger: int) -> Dictionary:
	if danger <= 0:
		return {}
	if spell.is_prepared:
		if not spell.can_activate_prepared(game_manager, bot_player):
			return {}
	elif not game_manager.can_play_card(bot_player, spell, null):
		return {}
	var enemies: Array = spell.get_destroyable_enemy_cards(game_manager)
	if enemies.is_empty():
		enemies = [null]
	var friendly := spell.get_destroyable_friendly_cards(game_manager)
	var best := {}
	# Compare the forced enemy loss with the optional destruction of a friendly card.
	for enemy: Card in enemies:
		for victim: Card in [null] + friendly:
			var removed: Array[Card] = []
			var score := -ECON_CARD_VALUE - CardStrategy.mana_penalty(self, CardStrategy.activation_cost(self, spell))
			if CardStrategy.can_remove_from_board(self, spell, enemy, true):
				removed.append(enemy)
				score += CardStrategy.value(self, enemy)
			if CardStrategy.can_remove_from_board(self, spell, victim, true):
				removed.append(victim)
				score -= CardStrategy.value(self, victim)
			if removed.is_empty():
				continue
			var summons := {}
			var token_count := spell.get_destroyed_structure_or_golem_count_this_turn(game_manager) + removed.size()
			for zone in bot_player.frontline_zones + bot_player.reserve_zones:
				if token_count <= 0:
					break
				if zone.cards.any(func(card: Card) -> bool: return card not in removed):
					continue
				var token := StoneInfant.new()
				token.card_owner = bot_player
				summons[token] = zone
				token_count -= 1
			score += _follower_safety_gain(danger, {"removed": removed, "summons": summons})
			if score > int(best.get("score", 0)):
				best = {"score": score, "command": {
					"type": "cast_spell", "spell_uid": spell.uid, "prepared": spell.is_prepared,
					"choices": [victim.uid] if victim != null else [],
					"enemy_target_uid": enemy.uid if enemy != null else "",
				}}
	return best

func _plan_board_withdrawal(source: Card, danger: int) -> Dictionary:
	if danger <= 0 or not source.can_activate(game_manager) or source.is_activation_locked(game_manager) \
			or not game_manager.can_pay_creature_action_mana_cost(source, "activate"):
		return {}
	var best := {}
	var tax := game_manager.get_creature_action_mana_cost(source, "activate") * ECON_MANA_VALUE
	if source is TezcatlipocaBlasphemer:
		for target: Card in source.get_valid_targets(game_manager):
			if not CardStrategy.can_remove_from_board(self, source, target, true):
				continue
			for victim: Card in source.get_valid_blood_magic_sacrifices():
				if not CardStrategy.can_remove_from_board(self, source, victim, true, false):
					continue
				var gain := _follower_safety_gain(danger, {"removed": [victim, target]})
				var target_value := CardStrategy.value(self, target)
				var score := gain - tax - _get_card_economic_value(victim) + (target_value if target.get_controller() == opponent else -target_value)
				if gain > 0 and score > int(best.get("score", 0)):
					best = {"score": score, "command": {"type": "activate_card_ability", "source_uid": source.uid,
						"option": {"target_uid": target.uid, "sacrifice_uid": victim.uid}}}
		return best
	var command := {"type": "activate_card_ability", "source_uid": source.uid}
	if source is ErlqueensNightingale:
		if not game_manager.can_player_add_to_hand_now(bot_player):
			return {}
		command["return_to_hand"] = true
	else:
		var targets: Array[Card] = source.get_valid_targets(game_manager)
		var target := _choose_best_friendly_graveyard_target_for_source(source, targets)
		if target == null:
			return {}
		command["target_uid"] = target.uid
	var score := _follower_safety_gain(danger, {"removed": [source]}) - _get_card_economic_value(source) - tax
	return {"score": score, "command": command} if score > 0 else {}

func _plan_moon_hunt(hati: Hati) -> Dictionary:
	var command := {"type": "hati_moon_hunt", "decline": true}
	if hati == null or not hati.can_use_moon_hunt_summon(game_manager):
		return command
	var danger := _forecast_incoming_follower_loss()
	if danger <= 0:
		return command
	var best_score := 0
	var mana_cost := hati.get_total_moon_hunt_mana_cost(game_manager)
	for victim in hati.get_valid_moon_hunt_sacrifices():
		if not CardStrategy.can_remove_from_board(self, hati, victim, true, false):
			continue
		for zone in bot_player.frontline_zones + bot_player.reserve_zones:
			if not hati.is_valid_moon_hunt_destination(zone, victim):
				continue
			var gain := _follower_safety_gain(danger, {"removed": [victim], "summon": hati, "zone": zone, "stance": hati, "defensive": true})
			var score := gain + _get_card_economic_value(hati) - _get_card_economic_value(victim) - mana_cost * ECON_MANA_VALUE
			if gain > 0 and score > best_score:
				best_score = score
				command = {"type": "hati_moon_hunt", "sacrifice_uid": victim.uid, "player_index": player_index,
					"zone_type": zone.zone_type, "zone_index": zone.zone_index, "mode": "defensive"}
	return command

func _plan_sacrifice_spell(spell: SpellCard, danger: int = -1) -> Dictionary:
	if spell.is_prepared:
		if not spell.can_activate_prepared(game_manager, bot_player):
			return {}
	elif not game_manager.can_play_card(bot_player, spell, null):
		return {}
	var sacrifices := _get_valid_summon_sacrifice_candidates() if spell is BlotSacrifice else (spell as KeyOfSolomon).get_valid_sacrifices()
	if sacrifices.is_empty():
		return {}
	var score := 0
	var choices: Array[String] = []
	if spell is BlotSacrifice:
		var blot := spell as BlotSacrifice
		var uids: Array[String] = []
		for recruit in blot.get_valid_hand_creatures():
			uids.append(recruit.uid)
		choices = CardStrategy.budget_choices(self, uids, BlotSacrifice.MAX_SUMMON_LEVELS, blot.get_available_summon_zones().size() + 1, false, true)
		for uid in choices:
			var recruit := game_manager.get_card_by_uid(uid)
			score += CardStrategy.blot_summon_gain(self, recruit)
	else:
		if not game_manager.can_player_add_to_hand_now(bot_player):
			return {}
		var demons := (spell as KeyOfSolomon).get_valid_demon_targets()
		demons.sort_custom(func(a: Card, b: Card) -> bool: return _get_card_economic_value(a) > _get_card_economic_value(b))
		for demon in demons.slice(0, KeyOfSolomon.MAX_DEMONS_TO_RETURN):
			choices.append(demon.uid)
			score += _get_card_economic_value(demon)
	if choices.is_empty():
		return {}
	var best := {}
	var cost := ECON_CARD_VALUE + CardStrategy.mana_penalty(self, CardStrategy.activation_cost(self, spell))
	for victim in sacrifices:
		if not CardStrategy.can_remove_from_board(self, spell, victim, not spell is BlotSacrifice, false):
			continue
		var body_cost := _get_card_economic_value(victim)
		if victim.is_sleeping:
			body_cost /= 2
		var change := {"removed": [victim]}
		if spell is BlotSacrifice:
			var zones: Array[Zone] = []
			for zone in bot_player.frontline_zones + bot_player.reserve_zones:
				if zone.cards.is_empty() or (zone == victim.current_zone and zone.get_creature() == victim):
					zones.append(zone)
			var summons: Dictionary = {}
			for index in range(mini(zones.size(), choices.size())):
				summons[game_manager.get_card_by_uid(choices[index])] = zones[index]
			change["summons"] = summons
		var candidate := score - cost - body_cost + _follower_safety_gain(danger, change)
		if candidate > int(best.get("score", 0)):
			best = {"score": candidate, "command": {"type": "cast_spell", "spell_uid": spell.uid, "sacrifice_uid": victim.uid, "choices": choices}}
	return best

func _try_prepare_strategy_card() -> bool:
	var zone := _get_first_open_reserve_zone(bot_player)
	if zone == null:
		return false
	var prepared_types: Array[String] = []
	for card in game_manager.get_field_cards(bot_player):
		if card.is_prepared:
			prepared_types.append(CardStrategy.key(card))
	var best_card: Card = null
	var best_score := 0
	for card in bot_player.hand_zone.cards:
		if not CardStrategy.supported(card) or not (card is HexCard or card is CharmCard or (card is SpellCard and game_manager.spells_must_be_prepared())) or CardStrategy.key(card) in prepared_types:
			continue
		if not game_manager.can_prepare_card(bot_player, card, zone):
			continue
		var score := CardStrategy.preparation_score(self, card) - CardStrategy.mana_penalty(self, _get_play_cost(card, true))
		if card is SpellCard:
			var target := CardStrategy.best_target(self, card, CardStrategy.targets(self, card))
			score = CardStrategy.effect_score(self, card, target) - CardStrategy.mana_penalty(self, _get_play_cost(card, true))
		if score > best_score:
			best_card = card
			best_score = score
	return _submit_prepare_card(best_card, zone) if best_card != null else false

func _plan_strategy_support(danger: int = -1) -> Dictionary:
	var best_card: Card = null
	var best_zone: Zone = null
	var best_score := 0
	for card in bot_player.hand_zone.cards:
		if card.discard_cost > 0 or card.sacrifice_cost > 0:
			continue
		if card is EquipmentCard:
			for bearer in _get_board_creatures(bot_player):
				if not card.can_equip_to(bearer) or not game_manager.can_play_card(bot_player, card, bearer.current_zone):
					continue
				var score := CardStrategy.equipment_score(self, card, bearer)
				if score > best_score:
					best_card = card
					best_zone = bearer.current_zone
					best_score = score
		elif card is StructureCard:
			var zone := _get_first_open_reserve_zone(bot_player)
			if zone == null or not game_manager.can_play_card(bot_player, card, zone):
				continue
			var score := CardStrategy.structure_score(self, card)
			if card is WardingStone:
				score += _follower_safety_gain(danger, {"block_attacks": true})
			if score > best_score:
				best_card = card
				best_zone = zone
				best_score = score
	if best_card == null:
		return {}
	return {"score": best_score, "command": {"type": "play_card", "card_uid": best_card.uid, "player_index": player_index, "zone_type": best_zone.zone_type, "zone_index": best_zone.zone_index}}

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

func _try_prepare_wheel_of_fire() -> bool:
	var zone := _get_first_open_reserve_zone(bot_player)
	if zone == null:
		return false
	# One unbound Wheel is enough until it finds a target. Keep reserve space
	# available for creatures and other prepared responses.
	for board_zone in bot_player.frontline_zones + bot_player.reserve_zones:
		for card in board_zone.cards:
			if card is WheelOfFire and card.is_prepared:
				return false
	for card in bot_player.hand_zone.cards:
		var wheel := card as WheelOfFire
		if wheel == null:
			continue
		# The hand card cannot attach yet, so inspect potential enemy targets;
		# the actual response uses the authority's legal target list later.
		if _choose_best_wheel_of_fire_target(wheel, _get_board_creatures(opponent)) != null:
			return _submit_prepare_card(wheel, zone)
	return false

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

func _plan_power_unlock(danger: int = -1) -> Dictionary:
	var best_power: PowerCard = null
	var best_score := -1000000
	for power in _get_player_powers():
		if power == null or not power.is_face_down or not power.can_unlock(game_manager):
			continue
		# Unlock commands currently cannot carry a selected discard payment.
		# Do not surrender an arbitrary hand card for a generic unlock.
		if power.discard_cost > 0 or power.sacrifice_cost > 0:
			continue
		if power is Breidablik or power is DivineCaprice:
			continue
		var score := _score_power_unlock(power)
		if power is Ragnarok and danger > 0:
			var removed := CardStrategy.removal_targets(self, power)
			var gain := _follower_safety_gain(danger, {"removed": removed})
			if gain > 0:
				score = gain - CardStrategy.mana_penalty(self, power.get_unlock_mana_cost(game_manager))
				for victim: Card in removed:
					score += CardStrategy.value(self, victim) if victim.get_controller() == opponent else -CardStrategy.value(self, victim)
		if score > best_score:
			best_score = score
			best_power = power
	if best_power == null or best_score < 900:
		return {}
	var plan := {"score": best_score, "command": {
		"type": "unlock_power",
		"power_uid": best_power.uid,
	}}
	if _can_use_generic_power_command(best_power):
		plan["activate_after_unlock_uid"] = best_power.uid
	return plan

func _plan_power_activation(required_power: PowerCard = null, danger: int = -1) -> Dictionary:
	var best_power: PowerCard = null
	var best_target: Card = null
	var best_guard_mana := 0
	var best_score := -1000000
	var powers := _get_player_powers()
	if required_power != null:
		powers.assign([required_power])
	for power in powers:
		if power == null or power.is_face_down or not power.can_activate(game_manager):
			continue
		if not game_manager.can_player_use_powers(bot_player) or not _can_use_generic_power_command(power):
			continue
		if int(_strategy_activation_turns.get(power.uid, -1)) == game_manager.turn_number:
			continue
		var chosen_target: Card = null
		if power is CallOfTheValkyrie:
			chosen_target = _choose_call_of_the_valkyrie_target(power)
		elif power.targets and power.has_method("get_valid_targets"):
			chosen_target = CardStrategy.best_target(self, power, power.get_valid_targets(game_manager))
		if power.targets and chosen_target == null:
			continue
		var score := _score_power_activation(power, chosen_target)
		var guard_mana := 0
		if power is ManaGuard:
			guard_mana = CardStrategy.guard_mana(self)
			if danger >= bot_player.followers and guard_mana > 0:
				# Find the smallest payment that leaves followers after the projected line.
				for mana in range(1, guard_mana + 1):
					var gain := _follower_safety_gain(danger, {"guard": bot_player.guard + mana * ManaGuard.GUARD_PER_MANA})
					if gain >= ECON_CARD_VALUE * 20:
						guard_mana = mana
						score = _score_follower_loss(bot_player, mana * ManaGuard.GUARD_PER_MANA) - CardStrategy.mana_penalty(self, mana) + gain
						break
		if score > best_score:
			best_score = score
			best_power = power
			best_target = chosen_target
			best_guard_mana = guard_mana
	if best_power == null or best_score < CardStrategy.MIN_POWER_ACTIVATION_SCORE:
		return {}
	var command := {
		"type": "activate_power",
		"power_uid": best_power.uid,
	}
	if best_target != null:
		command["target_uid"] = best_target.uid
	if CardStrategy.key(best_power) == "ManaGuard":
		command["mana_amount"] = best_guard_mana
	var plan := {"command": command, "score": best_score}
	if CardStrategy.key(best_power) in ["OraclesSight", "ManaGuard"]:
		plan["once_per_turn_uid"] = best_power.uid
	return plan

func _try_switch_to_aggressive_mode(danger: int = -1) -> bool:
	var creature := _get_best_mode_switch_candidate()
	if creature == null:
		return false
	if danger >= 0 and _forecast_incoming_follower_loss({"stance": creature, "defensive": false}) >= bot_player.followers:
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

func _plan_defensive_stance(danger: int) -> Dictionary:
	var best := {}
	if danger <= 0:
		return best
	for creature in _get_board_creatures(bot_player):
		if creature.creature_mode != Card.CreatureMode.AGGRESSIVE or creature.is_sleeping \
				or not creature.can_take_minor_creature_action() or not game_manager.can_pay_creature_action_mana_cost(creature, "change stance"):
			continue
		var gain := _follower_safety_gain(danger, {"stance": creature, "defensive": true})
		if gain <= 0:
			continue
		var score := gain - (1 + game_manager.get_creature_action_mana_cost(creature, "change stance")) * ECON_MANA_VALUE
		if score > int(best.get("score", 0)):
			best = {"score": score, "command": {"type": "change_mode", "card_uid": creature.uid, "mode": Card.CreatureMode.DEFENSIVE}}
	return best

func _plan_removal_god_ability(danger: int) -> Dictionary:
	var god := _find_player_god()
	var best := {}
	if god == null or not god.has_method("can_activate") or not god.can_activate(game_manager):
		return best
	var targets: Array[Card] = []
	if god is Mummu:
		targets.assign(game_manager.get_field_cards(bot_player, false).filter(god.is_valid_activation_target))
	elif god is GuanYu and god._can_use_tactical_break(game_manager):
		targets = god.get_valid_targets(game_manager)
	elif god is AphroditeAreia:
		targets = god.get_valid_enslave_targets(game_manager)
	elif god is Odin and danger > 0:
		var top: Card = god._get_top_deck_card()
		var known := top != null and top.is_publicly_identified(game_manager)
		var penalty := 0 if known or game_manager.has_turn_follower_loss_prevention(bot_player) else Odin.FOLLOWER_PENALTY
		if bot_player.followers <= penalty:
			return best
		for offering in god.get_valid_runic_knowledge_offerings():
			if offering.current_zone == null or not offering.current_zone.is_board_zone():
				continue
			var score := _follower_safety_gain(danger, {"removed": [offering], "followers": bot_player.followers - penalty})
			score -= _get_card_economic_value(offering)
			if score > int(best.get("score", 0)):
				best = {"score": score, "command": {"type": "activate_card_ability", "source_uid": god.uid,
					"option": {"offering_uid": offering.uid, "named_card_name": top.card_name if known else offering.card_name}}}
		return best
	for target in targets:
		if CardStrategy.removal_targets(self, god, target).is_empty() \
				or not game_manager.get_turn_destruction_ward_activation_block_reason(god, target).is_empty():
			continue
		var gain := _effect_follower_safety_gain(god, target, danger)
		var own := target.get_controller() == bot_player
		if own and gain <= 0:
			continue
		var score := gain + (CardStrategy.value(self, target) if not own else -_get_card_economic_value(target))
		if god is Mummu and game_manager.can_player_gain_mana_now(bot_player):
			score += maxi(0, target.get_effective_level() - 1) * ECON_MANA_VALUE
		elif god is AphroditeAreia:
			score -= CardStrategy.mana_penalty(self, AphroditeAreia.ACTIVATION_COST)
		if score > int(best.get("score", 0)):
			best = {"score": score, "command": {"type": "god_ability", "god_uid": god.uid, "target_uid": target.uid}}
	return best

func _plan_defensive_attack(attacks: Array[Dictionary], danger: int) -> Dictionary:
	var best := {}
	for attack in attacks:
		if attack["barrier"] != null or int(attack["mana_cost"]) > bot_player.mana:
			continue
		var results: Array = [attack["base"]]
		results.append_array(attack["replies"].values())
		var score := 1000000
		for result: Dictionary in results:
			if result.is_empty() or result["opponent_wins"]:
				score = 0
				break
			var gain := _follower_safety_gain(danger, {
				"removed": result.get("casualties", []),
				"committed_attackers": [attack["attacker"], attack["partner"]],
				"followers": bot_player.followers - int(result["bot_followers_lost"]) + int(result.get("bot_followers_gained", 0)),
				"guard": bot_player.guard - int(result.get("bot_guard_spent", 0)),
			})
			score = mini(score, gain + _score_attack_economy(result) / 4)
		if score > int(best.get("score", 0)):
			var target = attack["target"]
			best = {"score": score, "command": {"type": "request_attack", "attacker_uid": attack["attacker"].uid, "target_id": str(game_manager.players.find(target)) if target is Player else target.uid}}
	return best

func _follower_safety_gain(danger: int, change: Dictionary) -> int:
	if danger < 0:
		return 0
	var after := _forecast_incoming_follower_loss(change)
	var followers := int(change.get("followers", bot_player.followers))
	var difference := (followers - after) - (bot_player.followers - danger)
	if danger >= bot_player.followers and after < followers:
		return ECON_CARD_VALUE * 30 + difference * 100
	if danger < bot_player.followers and after >= followers:
		return -ECON_CARD_VALUE * 30
	return difference * (600 if bot_player.followers < 25 else 200)

func _forecast_incoming_follower_loss(change: Dictionary = {}) -> int:
	if not bot_player.followers_enabled or opponent == null or bool(change.get("block_attacks", false)):
		return 0
	var removed: Array = change.get("removed", []).duplicate()
	if game_manager.current_player == bot_player:
		for creature in _get_board_creatures(bot_player):
			if creature is RedCap and not creature.abilities_suppressed() and not creature._resolved_attack_this_turn \
					and creature not in change.get("committed_attackers", []) \
					and CardStrategy.can_remove_from_board(self, creature, creature, true, false):
				removed.append(creature)
	var restriction: Dictionary = game_manager.attack_restrictions.get(opponent, {})
	if not restriction.is_empty() and restriction.get("source") not in removed:
		return 0
	var prevention: Dictionary = game_manager.turn_follower_loss_preventions.get(bot_player, {})
	if int(prevention.get("expires_turn", -1)) > game_manager.turn_number and prevention.get("source_card") not in removed:
		return 0

	var targets: Array = [bot_player]
	var defenders := _get_board_creatures(bot_player)
	var summon := change.get("summon") as Card
	var stance := change.get("stance") as Card
	var defensive := bool(change.get("defensive", false))
	var summon_zone := change.get("zone") as Zone
	var summon_stealth := bool(change.get("stealth", false))
	var summons: Dictionary = change.get("summons", {}).duplicate()
	var moved := change.get("moved") as Card
	var destination := change.get("destination") as Zone
	if summon != null:
		summons[summon] = summon_zone
	for recruit: Card in summons:
		defenders.append(recruit)
	var structures := game_manager._get_active_structures()
	for card in defenders:
		if card not in removed:
			targets.append(card)
	for structure in structures:
		if structure.get_controller() == bot_player and structure not in removed:
			targets.append(structure)

	var attack_lines: Array[Dictionary] = []
	var budget := opponent.mana + game_manager.get_automatic_upkeep_mana_gain(opponent, game_manager.turn_number + 1) \
		+ game_manager.get_effective_upkeep_mana_gain(game_manager.get_base_upkeep_mana_gain(), opponent)
	for attacker in _get_board_creatures(opponent):
		var attack_zone := destination if attacker == moved else attacker.current_zone
		if attacker in removed or attacker == change.get("disable_attacker") or not CardStrategy.visible(self, attacker) \
				or attacker.get_controller() != opponent or attack_zone == null or attack_zone.zone_type != Zone.ZoneType.FRONTLINE \
				or (attacker.creature_mode != Card.CreatureMode.AGGRESSIVE and not attacker.is_stealth) \
				or attacker.is_petrified() or _status_persists_to_next_turn(attacker, "sleep", removed) \
				or _status_persists_to_next_turn(attacker, "cannot_attack", removed):
			continue
		var cost := game_manager.get_creature_action_mana_cost(attacker, "attack")
		if cost > budget:
			continue
		var speed := attacker.get_effective_speed()
		for target in targets:
			if target is Card and not attacker.can_ignore_attack_targeting_restrictions(target) \
					and (not attacker.can_engage(target) or not target.can_be_engaged_by(attacker)):
				continue
			var barriers: Array[Card] = []
			for structure in structures:
				if structure in removed or not CardStrategy.visible(self, structure):
					continue
				var blocked := structure.blocks_attack_on_followers(game_manager, attacker, bot_player) if target is Player \
					else structure.blocks_attack_on_target(game_manager, attacker, target)
				if blocked:
					barriers.append(structure)
			var action := CardAction.new()
			action.type = CardAction.Type.ATTACK
			action.attacker = attacker
			action.target = target
			var target_stance := target as Card if target in summons else stance
			var replies := {target: _forecast_incoming_combat(action, target_stance, defensive and target == stance, summon_stealth and target == summon, removed)}
			for interceptor in defenders:
				if interceptor in removed or _status_persists_to_next_turn(interceptor, "cannot_intercept", removed):
					continue
				var projected_zone := destination if interceptor == moved else summons.get(interceptor) as Zone
				var mode := -1
				if interceptor == stance:
					mode = Card.CreatureMode.DEFENSIVE if defensive else Card.CreatureMode.AGGRESSIVE
				elif interceptor in summons:
					mode = Card.CreatureMode.AGGRESSIVE
				var target_zone := destination if target == moved else summons.get(target) as Zone
				var projected_stealth := summon_stealth and interceptor == summon
				var speed_delta := -1 if projected_stealth and not interceptor.is_stealth else 0
				var legal := match_manager._can_intercept(interceptor, attacker, target, interceptor, speed_delta, speed, projected_zone, mode, target_zone)
				if not legal:
					continue
				action.interceptor = interceptor
				var interceptor_stance := interceptor if interceptor in summons else stance
				replies[interceptor] = _forecast_incoming_combat(action, interceptor_stance, defensive and interceptor == stance, projected_stealth, removed)
			attack_lines.append({"attacker": attacker, "target": target, "replies": replies, "barriers": barriers, "cost": cost})
	if attack_lines.is_empty():
		return 0
	var guard := int(change.get("guard", bot_player.guard))
	var followers := int(change.get("followers", bot_player.followers))
	var most_damage := 0
	# The opponent chooses the attack and the bot chooses whether to intercept.
	# Recheck a second attack after each reply, with spent Guard and casualties carried forward.
	for line in attack_lines:
		if not line["barriers"].is_empty():
			continue
		var least_damage := followers
		for first: Dictionary in line["replies"].values():
			var first_loss := _forecast_follower_damage(first, guard)
			if first_loss >= least_damage:
				continue
			var remaining_guard := maxi(0, guard - int(first["damage"]))
			var casualties: Array = first["casualties"]
			var followup := 0
			for second in attack_lines:
				if second["attacker"] == line["attacker"] or second["attacker"] in casualties or second["target"] in casualties \
						or int(line["cost"]) + int(second["cost"]) > budget:
					continue
				if second["barriers"].any(func(barrier: Card) -> bool: return barrier not in casualties):
					continue
				var second_loss := _forecast_follower_damage(second["replies"][second["target"]], remaining_guard)
				for interceptor in second["replies"]:
					if interceptor not in casualties:
						second_loss = mini(second_loss, _forecast_follower_damage(second["replies"][interceptor], remaining_guard))
				followup = maxi(followup, second_loss)
				if first_loss + followup >= least_damage:
					break
			least_damage = mini(least_damage, first_loss + followup)
		most_damage = maxi(most_damage, least_damage)
		if most_damage >= followers:
			break
	return most_damage

func _status_persists_to_next_turn(card: Card, status_name: String, removed: Array = []) -> bool:
	for status in card._get_effective_statuses():
		if status.get("name") == status_name and int(status.get("expires_turn", game_manager.turn_number + 1)) > game_manager.turn_number:
			var source := status.get("source_card") as Card
			if source in removed and (source is Alu or source is Dromi or source is Gleipnir):
				continue
			return true
	return false

func _forecast_incoming_combat(action: CardAction, stance: Card, defensive: bool, projected_stealth: bool, removed: Array) -> Dictionary:
	var defender := _get_attack_defender_card(action)
	var mode := -1
	if defender != null and defender == stance:
		mode = Card.CreatureMode.DEFENSIVE if defensive else Card.CreatureMode.AGGRESSIVE
	var result := _estimate_raw_attack_economy(action, null, 0, 0, mode)
	if defender is Askelladen and _can_askelladen_retreat(defender, action.attacker):
		return {"damage": 0, "casualties": [defender, action.attacker]}
	var damage := int(result["bot_followers_lost"])
	if GameManager.combat_halves_follower_damage(action.attacker, defender):
		damage = GameManager.round_down_divide(damage, 2)
	if (defender is MasmassuPriest or defender is Grindylow) and (projected_stealth or defender.is_stealth):
		var targets := _get_reveal_removal_targets(defender)
		var target := _choose_combat_reveal_removal(defender, targets, action, result["casualties"] + removed)
		if target != null:
			result["casualties"].append(target)
	return {"damage": damage, "source": result.get("bot_loss_source"), "casualties": result["casualties"]}

func _forecast_follower_damage(result: Dictionary, guard: int) -> int:
	var damage := maxi(0, int(result["damage"]) - guard)
	var source := result.get("source") as Card
	if game_manager._source_converts_combat_follower_damage(source):
		return game_manager._get_combat_follower_conversion_amount(source, damage)
	return damage

func _get_combat_candidates() -> Array[Dictionary]:
	var candidates: Array[Dictionary] = []
	for attacker in _get_attack_ready_creatures():
		if match_manager.can_attack(attacker) and game_manager.can_pay_creature_action_mana_cost(attacker, "attack"):
			candidates.append_array(_get_attack_candidates(attacker, match_manager._get_declared_attack_partner(attacker)))
	return candidates

func _get_attack_candidates(attacker: Card, partner: Card, projected_summon: bool = false, speed_target: Card = null, speed_delta: int = 0) -> Array[Dictionary]:
	var candidates: Array[Dictionary] = []
	var targets: Array = [opponent]
	for card in game_manager.get_field_cards(opponent):
		if CardStrategy.visible(self, card) and card.card_type in [Card.CardType.CREATURE, Card.CardType.STRUCTURE]:
			targets.append(card)
	var attack_speed := attacker.get_effective_speed(speed_delta if attacker == speed_target else 0)
	if partner != null:
		attack_speed = mini(attack_speed, partner.get_effective_speed(speed_delta if partner == speed_target else 0))
	var allied_attackers := [partner] if partner != null else []
	var projected_strength_delta := _get_projected_strength(attacker) - attacker.get_effective_strength() if projected_summon else 0
	for target in targets:
		if target is Card:
			if projected_summon and not game_manager.can_cards_engage_each_other(attacker, target):
				continue
			if not projected_summon and not _can_attack_creature(attacker, target):
				continue
		if target is Card and partner != null and game_manager.is_attack_blocked_by_active_structure(attacker, target, allied_attackers):
			continue
		var barriers: Array[Card] = []
		if target is Player:
			for structure in game_manager._get_active_structures():
				if structure.blocks_attack_on_followers(game_manager, attacker, opponent, allied_attackers):
					barriers.append(structure)
			if barriers.size() > 1:
				continue
		var action := CardAction.new()
		action.type = CardAction.Type.ATTACK
		action.source_player = bot_player
		action.attacker = attacker
		action.united_front_partner = partner
		action.attack_speed_override = attack_speed
		action.target = target
		var modified_card := attacker if projected_summon else speed_target
		var base := _estimate_attack_economy(action, modified_card, projected_strength_delta, speed_delta)
		var replies := {}
		var interceptors := match_manager._get_possible_interceptors(attacker, target, attack_speed)
		for interceptor in interceptors:
			if CardStrategy.visible(self, interceptor):
				action.interceptor = interceptor
				replies[interceptor] = _estimate_attack_economy(action, modified_card, projected_strength_delta, speed_delta)
			else:
				replies[interceptor] = {}
		# A prepared response can fire against the original target or the chosen interceptor.
		for defender: Card in [null] + interceptors:
			if defender != null and not CardStrategy.visible(self, defender):
				continue
			action.interceptor = defender
			for response in _get_known_attack_response_cards(action):
				if response in replies:
					continue
				var result := _estimate_known_attack_response(response, action, projected_summon)
				if not result.is_empty():
					replies[response] = result
		for hidden in _get_board_creatures(opponent):
			if not CardStrategy.visible(self, hidden) and not hidden.has_status_effect("cannot_intercept") and not hidden.is_sleeping:
				replies[hidden] = {}
		candidates.append({
			"attacker": attacker, "partner": partner, "target": target, "base": base, "replies": replies,
			"barrier": barriers[0] if not barriers.is_empty() else null,
			"mana_cost": game_manager.get_creature_action_mana_cost(attacker, "attack"),
		})
	return candidates

func _get_known_attack_response_cards(action: CardAction) -> Array[Card]:
	var responses: Array[Card] = []
	if action == null or opponent == null:
		return responses
	for zone in opponent.frontline_zones + opponent.reserve_zones:
		for card in zone.cards:
			if not (card is TheInferno or card is VoidShield or card is Smite) or not CardStrategy.visible(self, card):
				continue
			if game_manager.can_card_respond_to_action(card, action, opponent):
				responses.append(card)
	return responses

func _estimate_known_attack_response(response: Card, action: CardAction, projected_summon: bool = false) -> Dictionary:
	var result := {
		"casualties": [],
		"bot_cards_lost": 0,
		"opponent_cards_lost": 0,
		"bot_followers_lost": 0,
		"opponent_followers_lost": 0,
		"bot_wins": false,
		"opponent_wins": false,
	}
	if response is VoidShield or response is Smite:
		var victim := action.attacker
		var destroys := response is Smite
		var removable := CardStrategy.can_remove_from_board(self, response, victim, destroys)
		if projected_summon:
			removable = not game_manager.is_immune_to_source(victim, response) and not game_manager.is_guardian_protected(victim, response) \
					and (not destroys or (not CardStrategy.destruction_guard(victim) and not game_manager.has_turn_destruction_ward(bot_player)))
		if not removable:
			return {}
		_add_destroyed_card_to_economy(result, victim)
		return result
	if projected_summon and not game_manager.is_immune_to_source(action.attacker, response) \
			and not CardStrategy.destruction_guard(action.attacker) \
			and not game_manager.has_turn_destruction_ward(bot_player):
		_add_destroyed_card_to_economy(result, action.attacker)
	for zone in bot_player.frontline_zones:
		for card in zone.cards:
			if card == null or game_manager.is_immune_to_source(card, response) or CardStrategy.destruction_guard(card):
				continue
			if card.card_type == Card.CardType.CREATURE and game_manager.has_turn_destruction_ward(bot_player):
				continue
			_add_destroyed_card_to_economy(result, card)
	return result

func _plan_united_front(attacks: Array[Dictionary], baseline: Dictionary) -> Dictionary:
	var best := {}
	var best_score := 0
	if game_manager.turn_number <= 1:
		return best
	for card in _get_attack_ready_creatures():
		if not (card is RoboticFootsoldier) or card.is_activation_locked(game_manager) or not match_manager.can_attack(card) or not card.can_activate(game_manager):
			continue
		if int(_strategy_activation_turns.get(card.uid, -1)) == game_manager.turn_number:
			continue
		if match_manager._get_declared_attack_partner(card) != null:
			continue
		var cost := game_manager.get_creature_action_mana_cost(card, "activate")
		if bot_player.mana < cost + game_manager.get_creature_action_mana_cost(card, "attack"):
			continue
		var other_attacks := attacks.filter(func(candidate: Dictionary) -> bool: return candidate["attacker"] != card)
		for partner in card.get_valid_targets(game_manager):
			var projected := _get_attack_candidates(card, partner)
			projected.append_array(other_attacks)
			var line := _plan_combat(projected, [], null, cost)
			if line.get("attacker") != card:
				continue
			var score := int(line["score"]) - int(baseline.get("score", 0)) - cost * ECON_MANA_VALUE
			if score > best_score:
				best_score = score
				best = {
					"score": score,
					"once_per_turn_uid": card.uid,
					"command": {"type": "activate_card_ability", "source_uid": card.uid, "target_uid": partner.uid},
				}
	return best

func _project_attack(candidate: Dictionary, removed: Array = []) -> Dictionary:
	if candidate["barrier"] != null and candidate["barrier"] not in removed:
		return {}
	var result: Dictionary = candidate["base"]
	var score := _score_attack_economy(result)
	for interceptor in candidate["replies"]:
		if interceptor in removed:
			continue
		var reply: Dictionary = candidate["replies"][interceptor]
		if reply.is_empty():
			return {}
		var reply_score := _score_attack_economy(reply)
		if reply_score < score:
			result = reply
			score = reply_score
	return result

func _plan_combat(candidates: Array[Dictionary], removed: Array = [], committed: Card = null, mana_spent: int = 0) -> Dictionary:
	var best := {}
	var best_score := 0
	var available_mana := bot_player.mana - mana_spent
	for first in candidates:
		if int(first["mana_cost"]) > available_mana:
			continue
		if _is_removed_combat_card(first["target"], removed) or first["attacker"] in removed or first["partner"] in removed \
				or first["attacker"] == committed or (committed != null and first["partner"] == committed):
			continue
		var first_result := _project_attack(first, removed)
		if first_result.is_empty():
			continue
		var score := _score_attack_economy(first_result) - int(first["mana_cost"]) * ECON_MANA_VALUE
		var casualties: Array = first_result.get("casualties", [])
		# Only count a target as cleared if the attack has no remaining replies.
		var uncontested := not _has_projected_attack_reply(first, removed)
		var first_removed := removed + casualties if uncontested else removed
		var best_followup := 0
		if not first_result["bot_wins"] and not first_result["opponent_wins"]:
			for second in candidates:
				if int(first["mana_cost"]) + int(second["mana_cost"]) > available_mana:
					continue
				if _is_removed_combat_card(second["target"], first_removed) or second["target"] in casualties:
					continue
				if second["attacker"] in [first["attacker"], first["partner"], committed] or second["attacker"] in casualties or second["attacker"] in removed:
					continue
				if second["partner"] != null and (second["partner"] in [first["attacker"], first["partner"], committed] or second["partner"] in casualties or second["partner"] in removed):
					continue
				# An optional interception could leave the original target alive.
				# Avoid crediting a second kill on the same target in either case.
				if second["target"] == first["target"] and second["target"] is Card:
					continue
				var second_result := _project_attack(second, first_removed)
				if second_result.is_empty():
					continue
				var followup := int((_score_attack_economy(second_result) - int(second["mana_cost"]) * ECON_MANA_VALUE) * 0.75)
				var second_loss := int(second_result["opponent_followers_lost"])
				if second_result.has("opponent_damage_before_guard"):
					# Guard spent on the first hit is unavailable for the second.
					var remaining_guard := maxi(0, opponent.guard - int(first_result.get("opponent_guard_spent", 0)))
					var remainder := maxi(0, int(second_result.get("opponent_damage_before_guard", 0)) - remaining_guard)
					var damage_source := second_result.get("opponent_loss_source") as Card
					second_loss = game_manager._get_combat_follower_conversion_amount(damage_source, remainder) if game_manager._source_converts_combat_follower_damage(damage_source) else remainder
					second_loss = mini(opponent.followers, second_loss)
					followup += int((_score_follower_loss(opponent, second_loss) - _score_follower_loss(opponent, int(second_result["opponent_followers_lost"]))) * 0.75)
				var total_loss := int(first_result["opponent_followers_lost"]) + second_loss - int(first_result.get("opponent_followers_gained", 0))
				if uncontested and not _has_projected_attack_reply(second, first_removed) and total_loss >= opponent.followers:
					followup = ECON_CARD_VALUE * 20
				best_followup = maxi(best_followup, followup)
		score += best_followup
		if score > best_score:
			best_score = score
			best = {"attacker": first["attacker"], "target": first["target"], "score": score}
	return best

func _is_removed_combat_card(value, removed: Array) -> bool:
	if not (value is Card):
		return false
	for card: Card in removed:
		if card == value:
			return true
	return false

func _has_projected_attack_reply(candidate: Dictionary, removed: Array) -> bool:
	return candidate["replies"].keys().any(func(card: Card) -> bool: return card not in removed)

func _choose_interceptor(data: Dictionary) -> String:
	var attacker := game_manager.get_card_by_uid(str(data.get("attacker_uid", "")))
	if not CardStrategy.visible(self, attacker):
		return ""
	var target_uid := str(data.get("target_uid", ""))
	var target := game_manager.get_card_by_uid(target_uid)
	if target == null and target_uid != str(player_index):
		return ""
	var action := CardAction.new()
	action.type = CardAction.Type.ATTACK
	action.attacker = attacker
	action.target = target if target != null else bot_player
	action.united_front_partner = match_manager._get_declared_attack_partner(attacker)
	if action.united_front_partner != null and not CardStrategy.visible(self, action.united_front_partner):
		return ""
	var best := ""
	var unblocked := _estimate_attack_economy(action, null, 0, 0)
	var best_survives := not bool(unblocked["opponent_wins"])
	var best_score := _score_attack_economy(unblocked) + 200
	for uid in data.get("interceptor_uids", []):
		action.interceptor = game_manager.get_card_by_uid(str(uid))
		if action.interceptor == null:
			continue
		var blocked := _estimate_attack_economy(action, null, 0, 0)
		var survives := not bool(blocked["opponent_wins"])
		var score := _score_attack_economy(blocked)
		if (survives and not best_survives) or (survives == best_survives and score > best_score):
			best_survives = survives
			best_score = score
			best = str(uid)
	return best

func _try_advance_from_reserve() -> bool:
	if game_manager.turn_number <= 1 or game_manager.attack_restrictions.has(bot_player):
		return false
	var best_card: Card = null
	var best_zone: Zone = null
	var best_score := 0
	for card in _get_board_creatures(bot_player):
		if card.current_zone not in bot_player.reserve_zones or card.creature_mode != Card.CreatureMode.AGGRESSIVE:
			continue
		if card.is_sleeping or card.has_status_effect("cannot_move") or card.has_status_effect("cannot_attack") or not card.can_take_minor_creature_action_spending_minor() or not card.can_take_major_creature_action():
			continue
		if card.summoned_after_first_attack_this_turn or game_manager.is_first_turn_attack_blocked_by_weather(card) or not game_manager.can_pay_creature_action_mana_cost(card, "move"):
			continue
		var score := _score_projected_card(card) - game_manager.get_creature_action_mana_cost(card, "move") * ECON_MANA_VALUE
		if score <= best_score or not _can_attack_followers_safely(card):
			continue
		for zone in bot_player.get_adjacent_zones(card.current_zone):
			if zone in bot_player.frontline_zones and zone.cards.is_empty():
				best_card = card
				best_zone = zone
				best_score = score
				break
	return best_card != null and _submit_action({"type": "creature_move", "card_uid": best_card.uid, "player_index": player_index, "zone_type": best_zone.zone_type, "zone_index": best_zone.zone_index})

func _try_attack() -> bool:
	var attackers := _get_attack_ready_creatures()
	if attackers.is_empty():
		return false
	var opposing_creatures := _get_board_creatures(opponent)
	var safe_followers_attack := _get_best_safe_followers_attack(attackers)
	if not safe_followers_attack.is_empty() and (_can_kill_with_all_attackers(attackers) or opposing_creatures.is_empty()):
		return _submit_attack(safe_followers_attack.get("attacker", null), opponent)
	var askelladen_attack := _get_best_askelladen_attack(attackers, opposing_creatures)
	if not askelladen_attack.is_empty():
		return _submit_attack(askelladen_attack.get("attacker", null), askelladen_attack.get("target", null))
	var supported_attack := _get_best_supported_attack(attackers, opposing_creatures)
	if not supported_attack.is_empty():
		return _submit_attack(supported_attack.get("attacker", null), supported_attack.get("target", null))
	var standard_attack := _get_best_standard_attack(attackers, opposing_creatures)
	if not standard_attack.is_empty():
		return _submit_attack(standard_attack.get("attacker", null), standard_attack.get("target", null))
	var stealth_attack := _get_best_stealth_attack(attackers, opposing_creatures)
	if not stealth_attack.is_empty():
		return _submit_attack(stealth_attack.get("attacker", null), stealth_attack.get("target", null))
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
	if card is WheelOfFire:
		return 82
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
	if card is CreatureCard:
		return 35 + mini(40, maxi(0, card.strength) + maxi(0, card.resilience) / 3)
	return 65 if CardStrategy.supported(card) else 30

func _handle_combat_retreat_prompt(data: Dictionary) -> void:
	var askelladen := game_manager.get_card_by_uid(str(data.get("askelladen_uid", ""))) as Askelladen
	var action: CardAction = null
	var action_data = data.get("action", null)
	if action_data is CardAction:
		action = action_data
	elif action_data is Dictionary:
		action = CardAction.from_dict(action_data, game_manager)
	var target: Card = null
	var target_data = data.get("target", null)
	if target_data is Card:
		target = target_data
	else:
		target = game_manager.get_card_by_uid(str(data.get("target_uid", "")))
	if target == null and action != null:
		target = _get_attack_defender_card(action)
	var other_card: Card = null
	if askelladen != null and action != null and target != null:
		other_card = action.attacker if action.attacker != askelladen else target
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
	var command := _build_creature_play_command(card, zone, mode)
	return not command.is_empty() and _submit_action(command)

func _build_creature_play_command(card: Card, zone: Zone, mode: Card.CreatureMode, danger: int = -1, projected_defensive: bool = false) -> Dictionary:
	if card == null or zone == null or card.current_zone != bot_player.hand_zone:
		return {}
	var forecast := {}
	if danger >= 0:
		forecast = {"danger": danger, "summon": card, "zone": zone, "stance": card, "defensive": projected_defensive}
	var payment_plan := _build_creature_summon_payment_plan(card, bot_player.mana, forecast)
	if not bool(payment_plan.get("ok", false)):
		return {}
	var command := {
		"type": "play_creature",
		"card_uid": card.uid,
		"player_index": game_manager.players.find(zone.zone_owner),
		"zone_type": zone.zone_type,
		"zone_index": zone.zone_index,
		"mode": mode,
		"stealth": _should_summon_creature_stealthily(card, zone, mode),
		"sacrifice_uids": payment_plan.get("sacrifice_uids", []),
		"altar_void_uids": payment_plan.get("altar_void_uids", []),
	}
	if not forecast.is_empty():
		command["payment_penalty"] = payment_plan["penalty"]
	return command

func _should_summon_creature_stealthily(card: Card, zone: Zone, mode: Card.CreatureMode) -> bool:
	if card == null or zone == null or mode != Card.CreatureMode.DEFENSIVE:
		return false
	var card_key := CardStrategy.key(card)
	var ability_text := card.ability_text.to_lower().replace("[b]", "").replace("[/b]", "")
	# Stealth suppresses ordinary face-up passives and impact abilities, so keep
	# those bodies visible when they can provide value immediately.
	if card_key in CardStrategy.BOARD_ABILITIES \
			or "passive" in ability_text \
			or "impact" in ability_text \
			or "on summon" in ability_text:
		return false
	if zone not in bot_player.frontline_zones:
		return false
	# Stealth costs one speed. Preserve face-up speed when that difference could
	# let this frontline body intercept a currently plausible enemy attack.
	var face_up_speed := card.get_effective_speed()
	var stealth_speed := maxi(0, face_up_speed - 1)
	if opponent == null:
		return true
	for enemy in _get_board_creatures(opponent):
		if enemy == null or not CardStrategy.visible(self, enemy) or enemy.is_sleeping \
				or enemy.has_status_effect("cannot_attack"):
			continue
		var enemy_speed := enemy.get_effective_speed()
		if enemy_speed <= stealth_speed or enemy_speed > face_up_speed:
			continue
		if _can_attack_followers_safely(enemy) or _has_attackable_friendly_target(enemy):
			return false
	return true

func _has_attackable_friendly_target(attacker: Card) -> bool:
	if attacker == null or bot_player == null:
		return false
	for target in _get_board_creatures(bot_player):
		if target != null and _can_attack_creature(attacker, target):
			return true
	return false

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
	if _current_card_prompt_id >= 0:
		command["_prompt_id"] = _current_card_prompt_id
		_last_submitted_prompt_id = _current_card_prompt_id
	var submitted := game_input.submit_action(command)
	if not submitted:
		_forget_rejected_prompt()
	return submitted

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
		if play_score > -1000000:
			play_score += _estimate_summon_attack_value(card, zone, available_mana)
		# Compare this play with passing; having a legal summon is not itself value.
		if play_score <= 0:
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
	if card.current_zone != null and card.current_zone.is_board_zone():
		return card.get_effective_strength()
	var total := card.strength
	if _would_receive_thor_buff(card):
		total += 3
	return total

func _get_projected_resilience(card: Card) -> int:
	if card == null:
		return 0
	if card.current_zone != null and card.current_zone.is_board_zone():
		return card.get_effective_resilience()
	var total := card.resilience
	if _would_receive_thor_buff(card):
		total += 3
	return total

func _would_receive_thor_buff(card: Card) -> bool:
	var god := _find_player_god()
	return god is Thor and not god.is_muted and card != null and card.card_owner == bot_player and card.has_type("Human") and card.has_type("Warrior")

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
		if not _can_askelladen_retreat(askelladen, creature):
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

# Look one legal response ahead, using the same effect scores as priority play.
# This covers strength/resilience tricks as well as speed-enabled abilities.
func _get_best_supported_attack(attackers: Array[Card], opposing_creatures: Array[Card]) -> Dictionary:
	var best_attack := {}
	var best_score := 0
	var support_cards: Array = game_manager.get_field_cards(bot_player)
	support_cards.append_array(bot_player.hand_zone.cards)
	for attacker in attackers:
		if not match_manager.can_attack(attacker):
			continue
		if match_manager._get_declared_attack_partner(attacker) != null:
			continue
		for defender in opposing_creatures:
			if not CardStrategy.visible(self, defender) or not _can_attack_creature(attacker, defender):
				continue
			if not match_manager._get_possible_interceptors(attacker, defender).is_empty():
				continue
			var action := CardAction.new()
			action.type = CardAction.Type.ATTACK
			action.source_player = bot_player
			action.attacker = attacker
			action.target = defender
			var before := _score_attack_economy(_estimate_attack_economy(action, null, 0, 0))
			for support in support_cards:
				if not CardStrategy.supported(support) or not game_manager.can_card_respond_to_action(support, action, bot_player):
					continue
				var attack_cost := game_manager.get_creature_action_mana_cost(attacker, "attack")
				if bot_player.mana < attack_cost + CardStrategy.activation_cost(self, support):
					continue
				for target in CardStrategy.targets(self, support, action):
					if target not in [attacker, defender] or CardStrategy.stat_changes(self, support, target).is_empty():
						continue
					var gain := CardStrategy.effect_score(self, support, target, action)
					var score := before + gain
					if gain > 0 and score > maxi(0, before) and score > best_score:
						best_score = score
						best_attack = {"attacker": attacker, "target": defender, "score": score}
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

func _get_combat_strength(card: Card, opposing_card: Card = null, str_delta: int = 0) -> int:
	if card == null:
		return 0
	if card is CreatureCard and CardStrategy.visible(self, card):
		return card.get_combat_strength_against(opposing_card, str_delta)
	return maxi(0, card.get_effective_strength() + str_delta)

func _get_attack_strength_against_defense(attacker: Card, defender: Card = null, str_delta: int = 0) -> int:
	if attacker == null:
		return 0
	var total := _get_combat_strength(attacker, defender, str_delta)
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
		return _get_combat_strength(attacker, target) > target.get_effective_resilience()
	if target.creature_mode == Card.CreatureMode.AGGRESSIVE:
		return _get_combat_strength(attacker, target) >= _get_combat_strength(target, attacker)
	return _get_attack_strength_against_defense(attacker, target) > target.get_effective_resilience()

func _would_attacker_survive_battle(attacker: Card, target: Card) -> bool:
	if attacker == null or target == null:
		return false
	if target.is_petrified() or target.card_type == Card.CardType.STRUCTURE:
		return true
	if target.creature_mode == Card.CreatureMode.AGGRESSIVE:
		return _get_combat_strength(attacker, target) > _get_combat_strength(target, attacker)
	return not _defender_has_ferocious_defence(target, _get_attack_strength_against_defense(attacker, target))

func _is_attack_safe_from_interceptors(attacker: Card, target: Card) -> bool:
	if match_manager == null:
		return false
	for interceptor in match_manager._get_possible_interceptors(attacker, target):
		if not CardStrategy.visible(self, interceptor):
			continue
		if _is_attack_target_tactically_bad(attacker, interceptor) or not _would_attacker_survive_battle(attacker, interceptor):
			return false
	return true

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
	if not _is_attack_safe_from_interceptors(attacker, target):
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
	if not _is_attack_safe_from_interceptors(attacker, target):
		return -1000000
	if _is_attack_target_tactically_bad(attacker, target):
		return -1000000
	if not _would_destroy_target_in_battle(attacker, target):
		return -1000000
	var target_reward_multiplier := 1 if target is WardingStone \
			and target.get_attack_restriction_turns_remaining(game_manager) <= 0 else 12
	var score := _score_enemy_target(target) * target_reward_multiplier
	if _is_askelladen(target):
		score -= attacker.get_effective_strength() * 40
		score -= int(float(_score_projected_card(attacker)) / 4.0)
		if attacker.get_effective_speed() > target.get_effective_speed():
			score += 1400
		else:
			score += 500
	elif _would_attacker_survive_battle(attacker, target):
		if not (target is WardingStone and target.get_attack_restriction_turns_remaining(game_manager) <= 0):
			score += 2400
	else:
		score -= 1800
	score += attacker.get_effective_speed() * 30
	return score

func _can_kill_with_all_attackers(attackers: Array[Card]) -> bool:
	if opponent == null or game_manager == null or game_manager.has_turn_follower_loss_prevention(opponent):
		return false
	var total_damage := 0
	for attacker in attackers:
		if _can_attack_followers_safely(attacker):
			total_damage += _get_direct_follower_damage(attacker)
	return total_damage >= opponent.followers + opponent.guard

func _get_direct_follower_damage(attacker: Card) -> int:
	var damage := _get_combat_strength(attacker)
	if GameManager.combat_halves_follower_damage(attacker):
		damage = GameManager.round_down_divide(damage, 2)
	return damage

func _get_best_stealth_attack(attackers: Array[Card], opposing_creatures: Array[Card]) -> Dictionary:
	var best_attacker: Card = null
	var best_target: Card = null
	for target in opposing_creatures:
		if target == null or not (target.is_stealth or target.is_face_down):
			continue
		for attacker in attackers:
			if not _can_attack_creature(attacker, target):
				continue
			if not _is_attack_safe_from_interceptors(attacker, target):
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

func _has_committed_attack(creature: Card) -> bool:
	for action in game_manager.action_stack:
		if action.type == CardAction.Type.ATTACK and creature in [action.attacker, action.united_front_partner]:
			return true
	return false

func _can_attack_followers_after_modifier(attacker: Card, modified_card: Card, speed_delta: int) -> bool:
	if game_manager.is_followers_attack_blocked_by_active_structure(attacker, opponent, []):
		return false
	# Unknown defenders may have special intercept hooks. Do not use their hidden
	# identities or assume a speed change can evade them.
	for interceptor in _get_board_creatures(opponent):
		if not CardStrategy.visible(self, interceptor):
			return false
		if match_manager._can_intercept(interceptor, attacker, opponent, modified_card, speed_delta):
			return false
	return true

func _can_win_followers_after_modifier(modified_card: Card, str_delta: int, speed_delta: int) -> bool:
	if game_manager.has_turn_follower_loss_prevention(opponent):
		return false
	var total_damage := 0
	for attacker in _get_attack_ready_creatures():
		if _has_committed_attack(attacker) or not _can_attack_followers_after_modifier(attacker, modified_card, speed_delta):
			continue
		var damage := _get_combat_strength(attacker, null, str_delta if attacker == modified_card else 0)
		if GameManager.combat_halves_follower_damage(attacker):
			damage = GameManager.round_down_divide(damage, 2)
		total_damage += damage
	return total_damage >= opponent.followers + opponent.guard

func _score_followers_attack(attacker: Card) -> int:
	if attacker == null or opponent == null:
		return -1000000
	var damage := _get_direct_follower_damage(attacker)
	var score := damage * 140 + attacker.get_effective_speed() * 25
	if damage >= opponent.followers + opponent.guard:
		score += 3000
	if opponent.followers + opponent.guard <= damage * 2:
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
	if creature.is_sleeping or creature.has_status_effect("cannot_attack") or not creature.can_take_minor_creature_action_spending_minor():
		return -1
	if game_manager.turn_number <= 1 or game_manager.attack_restrictions.has(bot_player) or creature.summoned_after_first_attack_this_turn or game_manager.is_first_turn_attack_blocked_by_weather(creature):
		return -1
	if not game_manager.can_pay_creature_action_mana_cost(creature, "change stance"):
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
	if creature.is_sleeping or not game_manager.can_pay_creature_action_mana_cost(creature, "change stance"):
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
		if _get_combat_strength(enemy, creature) < creature.get_effective_resilience():
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
	projected_mana += game_manager.get_automatic_upkeep_mana_gain(bot_player, game_manager.turn_number + 1)
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
		if game_manager.current_player == bot_player and CardStrategy.combat_visible(self, action):
			var danger := _forecast_incoming_follower_loss()
			var fight := _estimate_attack_economy(action, null, 0, 0, 0, false)
			retreat_score += _follower_safety_gain(danger, {"removed": [ask_card, other_card]})
			fight_score += _follower_safety_gain(danger, {
				"removed": fight["casualties"],
				"followers": bot_player.followers - int(fight["bot_followers_lost"]) + int(fight.get("bot_followers_gained", 0)),
				"guard": bot_player.guard - int(fight.get("bot_guard_spent", 0)),
			})
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
	return _score_attack_economy(_estimate_attack_economy(action, null, 0, 0, 0, false))

func _score_askelladen_retreat_result(ask_card: Askelladen, other_card: Card) -> int:
	if ask_card == null or other_card == null:
		return -1000000
	return _get_card_economic_value(other_card) - _get_card_economic_value(ask_card)

func _can_askelladen_retreat(ask_card: Askelladen, other_card: Card, modified_card: Card = null, speed_delta: int = 0) -> bool:
	if ask_card == null or other_card == null:
		return false
	if ask_card.is_face_down or ask_card.abilities_suppressed():
		return false
	if game_manager == null:
		return false
	if game_manager.is_immune_to_source(other_card, ask_card):
		return false
	if other_card.get_effective_speed(speed_delta if other_card == modified_card else 0) > ask_card.get_effective_speed(speed_delta if ask_card == modified_card else 0):
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
			if game_manager.is_first_turn_attack_blocked_by_weather(card) or not game_manager.can_pay_creature_action_mana_cost(card, "attack"):
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
	var frontline_zone := _get_central_open_zone(player.frontline_zones)
	if frontline_zone != null:
		return frontline_zone
	return _get_central_open_zone(player.reserve_zones)

func _get_first_open_reserve_zone(player: Player) -> Zone:
	if player == null:
		return null
	return _get_central_open_zone(player.reserve_zones)

func _get_central_open_zone(zones: Array[Zone]) -> Zone:
	# Prefer the middle lane, then work outward; equal distances keep row order.
	var center := float(zones.size() - 1) / 2.0
	var best_zone: Zone = null
	var best_distance := INF
	for index in range(zones.size()):
		var zone := zones[index]
		if zone == null or not zone.cards.is_empty():
			continue
		var distance := absf(float(index) - center)
		if distance < best_distance:
			best_zone = zone
			best_distance = distance
	return best_zone

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
	return power is CallOfTheValkyrie or CardStrategy.key(power) in CardStrategy.ACTIVE_POWERS

func _score_power_unlock(power: PowerCard) -> int:
	if power == null:
		return -1000000
	if power is TakeTheField:
		var forms: Array[Card] = power.get_hover_summoned_active_gods()
		if forms.is_empty() or forms[0].sacrifice_cost > 0:
			return CardStrategy.BAD
		var score := _score_god_manifestation(forms[0], power.get_unlock_display_mana_cost(game_manager), Card.CreatureMode.AGGRESSIVE)
		if TiamatThePrimordial.is_tiamat_god(_find_player_god()):
			score -= TiamatThePrimordial.get_available_matriarch_rule_cards(bot_player).size() * 800
		return score
	if power is CallOfTheValkyrie:
		var target := _choose_call_of_the_valkyrie_target(power as CallOfTheValkyrie)
		var unlock_cost := power.get_unlock_mana_cost(game_manager)
		if unlock_cost + CardStrategy.activation_cost(self, power) > bot_player.mana or target == null or not _should_use_call_of_the_valkyrie():
			return -1000000
		return 1800 + _score_call_of_the_valkyrie_target(target) - unlock_cost * 140
	return CardStrategy.unlock_score(self, power)

func _score_power_activation(power: PowerCard, target: Card = null) -> int:
	if power == null:
		return -1000000
	if power is CallOfTheValkyrie:
		if target == null or not _should_use_call_of_the_valkyrie():
			return -1000000
		return 2200 + _score_call_of_the_valkyrie_target(target)
	return CardStrategy.power_score(self, power, target)

func _should_activate_untargeted_power(power: PowerCard) -> bool:
	if power == null:
		return false
	if _get_best_affordable_hand_creature(0) == null:
		return true
	return bot_player != null and bot_player.hand_zone != null and bot_player.hand_zone.cards.size() <= 1

func _score_god_manifestation(manifestation: Card, mana_paid: int, mode: Card.CreatureMode) -> int:
	if game_manager == null or not _has_good_manifestation_attack(manifestation, mode):
		return -1000000
	var opposing_creatures := _get_board_creatures(opponent)
	var score := ECON_CARD_VALUE + _score_projected_card(manifestation) - mana_paid * 350
	if opposing_creatures.is_empty():
		score += 1800
	elif _is_projected_creature_strongest_on_board(manifestation, opposing_creatures):
		score += 900
	else:
		score -= 2200
	if mode == Card.CreatureMode.DEFENSIVE:
		score -= 1700
	if _board_creature_count(bot_player) == 0 and opposing_creatures.is_empty():
		score += 600
	if _board_creature_count(bot_player) < _board_creature_count(opponent):
		score += 800
	if manifestation is ThorActive:
		score += _count_other_friendly_warriors() * 250
	var best_hand := _get_best_affordable_hand_creature(0)
	if best_hand != null and _get_play_cost(best_hand, false) > bot_player.mana - mana_paid:
		score -= int(_score_projected_card(best_hand) * 0.7)
	return score

func _has_good_manifestation_attack(manifestation: Card, mode: Card.CreatureMode) -> bool:
	if manifestation == null or game_manager == null or match_manager == null \
			or game_manager.current_player != bot_player \
			or game_manager.turn_number <= 1 \
			or game_manager.has_resolved_attack_this_turn \
			or game_manager.attack_restrictions.has(bot_player) \
			or (mode != Card.CreatureMode.AGGRESSIVE and not manifestation.is_stealth) \
			or game_manager.is_first_turn_attack_blocked_by_weather(manifestation):
		return false
	for target in game_manager.get_field_cards(opponent):
		if target == null or target.card_type not in [Card.CardType.CREATURE, Card.CardType.STRUCTURE] \
				or not CardStrategy.visible(self, target) \
				or not game_manager.can_cards_engage_each_other(manifestation, target):
			continue
		if not _would_destroy_target_in_battle(manifestation, target) \
				or not _would_attacker_survive_battle(manifestation, target):
			continue
		if match_manager._get_possible_interceptors(manifestation, target).is_empty():
			return true
	if not game_manager.is_followers_attack_blocked_by_active_structure(manifestation, opponent, []) \
			and match_manager._get_possible_interceptors(manifestation, opponent).is_empty():
		var damage := manifestation.get_effective_strength()
		if manifestation.halves_follower_damage_inflicted():
			damage = GameManager.round_down_divide(damage, 2)
		return damage > 0
	return false

func _choose_creature_summon_mode(card: Card, opposing_creatures = null) -> Card.CreatureMode:
	if card == null or card.card_type != Card.CardType.CREATURE:
		return Card.CreatureMode.DEFENSIVE
	var resolved_opposing: Array[Card] = _get_board_creatures(opponent) if opposing_creatures == null else opposing_creatures
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
	var projected_resilience := _get_projected_resilience(card)
	var projected_speed := card.get_effective_speed()
	var strongest_seen := false
	for enemy in opposing_creatures:
		if enemy == null:
			continue
		strongest_seen = true
		var projected_strength := _get_combat_strength(card, enemy) + _get_projected_strength(card) - card.get_effective_strength()
		var enemy_strength := _get_combat_strength(enemy, card)
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

func _find_best_priority_wheel_response(responses: Array, top_action: CardAction) -> Dictionary:
	var best: Dictionary = {}
	for response_card in responses:
		var wheel := response_card as WheelOfFire
		if wheel == null:
			continue
		var targets := game_manager.get_priority_hex_targets(wheel, top_action)
		var target := _choose_best_wheel_of_fire_target(wheel, targets, top_action)
		if target == null:
			continue
		var score := _score_wheel_of_fire_target(wheel, target, top_action)
		if score > int(best.get("score", 0)):
			best = {"card": wheel, "target": target, "score": score}
	return best

func _choose_best_wheel_of_fire_target(wheel: WheelOfFire, targets: Array, action: CardAction = null) -> Card:
	var best_target: Card = null
	var best_score := 0
	for raw_target in targets:
		var target := raw_target as Card
		var score := _score_wheel_of_fire_target(wheel, target, action)
		if score > best_score:
			best_target = target
			best_score = score
	return best_target

func _score_wheel_of_fire_target(wheel: WheelOfFire, target: Card, action: CardAction = null) -> int:
	if wheel == null or target == null or target.get_controller() != opponent:
		return -1000000
	if not wheel.can_attach_to_target(game_manager, target) or not target.current_zone.is_board_zone():
		return -1000000
	if game_manager.is_guardian_protected(target, wheel) or game_manager._is_hex_immune(target, wheel):
		return -1000000
	if not target.current_zone.get_equipment().is_empty():
		return -1000000
	for player in game_manager.players:
		for zone in player.frontline_zones + player.reserve_zones:
			for card in zone.cards:
				if card is WheelOfFire and card.attached_target == target and card._is_active():
					return -1000000
	var score := _score_wheel_of_fire_movement(wheel, target)
	if score <= 0:
		return -1000000
	if target.current_zone.zone_type == Zone.ZoneType.FRONTLINE:
		# Discount future removal by a turn and its upkeep payment. The creature
		# may move forward again, so this is worth less than removal now.
		score += maxi(0, _get_wheel_of_fire_target_value(target) / 3 - WheelOfFire.ADVANCE_COST * ECON_MANA_VALUE)
	if game_manager.current_player == bot_player:
		score += _wheel_follower_safety_gain(wheel, target)
	var defender := _get_attack_defender_card(action)
	var combatants_visible := action != null and action.attacker != null \
		and not action.attacker.is_face_down and not action.attacker.is_stealth \
		and (defender == null or (not defender.is_face_down and not defender.is_stealth))
	if combatants_visible and action.type == CardAction.Type.ATTACK and action.united_front_partner == null:
		var before := _estimate_attack_economy(action, null, 0, 0)
		var combat_score := _score_attack_economy(before)
		if target == action.attacker:
			# Moving the sole attacker off frontline cancels its declared attack.
			# Let an attack that already benefits us resolve instead.
			if combat_score > 0:
				return -1000000
			score += maxi(0, -combat_score)
		elif target == _get_attack_defender_card(action):
			if combat_score > 0 and int(before.get("opponent_cards_lost", 0)) > 0:
				return -1000000
			# Only removing a reserve defender cancels combat; a frontline
			# defender pushed to reserve can still be attacked.
			if target.current_zone.zone_type == Zone.ZoneType.RESERVE:
				score += maxi(0, -combat_score)
	var mana_cost := game_manager.get_prepared_card_activation_mana_cost(bot_player, wheel)
	return score - ECON_CARD_VALUE - mana_cost * ECON_MANA_VALUE - _get_wheel_of_fire_mana_opportunity_cost(mana_cost)

func _get_wheel_of_fire_target_value(target: Card) -> int:
	# Hidden enemy creatures have no known stats or identity. Do not use the
	# authoritative in-process state to give the bot information it cannot see.
	if target.is_face_down or target.is_stealth:
		return ECON_CARD_VALUE
	return _get_card_economic_value(target)

func _score_wheel_of_fire_movement(wheel: WheelOfFire, target: Card) -> int:
	if target == null or target.get_controller() != opponent or target.current_zone == null:
		return -1000000
	# Reuse the card's exact destination rules, including a full reserve line.
	if wheel._get_next_zone_for_target(target) == null:
		return -1000000
	var value := _get_wheel_of_fire_target_value(target)
	match target.current_zone.zone_type:
		Zone.ZoneType.RESERVE:
			return value + _score_wheel_of_fire_interceptor_removal(target)
		Zone.ZoneType.GRAVEYARD:
			# Void denies reuse, but removing a live threat is worth more.
			return value / 3
		Zone.ZoneType.FRONTLINE:
			var score := value * 3 / 5 + WheelOfFire.ACTION_TAX_AMOUNT * ECON_MANA_VALUE
			if not target.is_face_down and not target.is_stealth:
				if target.creature_mode == Card.CreatureMode.AGGRESSIVE and not target.is_sleeping:
					score += _score_follower_loss(bot_player, target.get_effective_strength()) / 2
				if target.has_type("Guardian"):
					score += ECON_MANA_VALUE
			return score
	return -1000000

func _score_wheel_of_fire_interceptor_removal(target: Card) -> int:
	if match_manager == null or target.is_face_down or target.is_stealth:
		return 0
	var best_score := 0
	for attacker in _get_attack_ready_creatures():
		if game_manager.is_followers_attack_blocked_by_active_structure(attacker, opponent, []):
			continue
		var interceptors := match_manager._get_possible_interceptors(attacker, opponent)
		if target in interceptors:
			# Clearing the last interceptor can open a winning follower attack.
			# Several remaining blockers make this a less immediate benefit.
			var damage := attacker.get_effective_strength()
			if attacker.halves_follower_damage_inflicted():
				damage /= 2
			best_score = maxi(best_score, _score_follower_loss(opponent, damage) / interceptors.size())
	return best_score

func _get_wheel_of_fire_mana_opportunity_cost(mana_cost: int) -> int:
	if mana_cost <= 0 or bot_player.has_summoned_this_turn:
		return 0
	var best_now := _get_best_affordable_hand_creature(0)
	if best_now == null:
		return 0
	var best_after := _get_best_affordable_hand_creature(-mana_cost)
	return maxi(0, _get_card_economic_value(best_now) - _get_card_economic_value(best_after))

func _should_pay_wheel_of_fire_upkeep(wheel: WheelOfFire) -> bool:
	if wheel == null or not wheel.can_offer_turn_start_advance(game_manager):
		return false
	var score := _score_wheel_of_fire_movement(wheel, wheel.attached_target)
	score += _wheel_follower_safety_gain(wheel, wheel.attached_target)
	score -= WheelOfFire.ADVANCE_COST * ECON_MANA_VALUE
	score -= _get_wheel_of_fire_mana_opportunity_cost(WheelOfFire.ADVANCE_COST)
	return score > 0

func _wheel_follower_safety_gain(wheel: WheelOfFire, target: Card) -> int:
	if target == null or target.current_zone == null or not target.current_zone.is_board_zone():
		return 0
	var destination := wheel._get_next_zone_for_target(target)
	if destination == null:
		return 0
	var danger := _forecast_incoming_follower_loss()
	if destination.is_board_zone():
		return _follower_safety_gain(danger, {"moved": target, "destination": destination})
	if CardStrategy.can_remove_from_board(self, wheel, target, false):
		return _follower_safety_gain(danger, {"removed": [target]})
	return 0

func _estimate_attack_economy(action: CardAction, modified_card: Card, str_delta: int, speed_delta: int, res_delta: int = 0, include_retreat: bool = true, projected_defender_mode: int = -1, projected_defender_stealth: bool = false) -> Dictionary:
	var result := _estimate_raw_attack_economy(action, modified_card, str_delta, res_delta, projected_defender_mode)
	var halve_follower_damage := false
	if action != null:
		var defender := _get_attack_defender_card(action)
		# Only forecast passives on cards the bot can identify.
		var known_attacker: Card = action.attacker if CardStrategy.visible(self, action.attacker) else null
		var known_defender: Card = defender if CardStrategy.visible(self, defender) else null
		var known_partner: Card = action.united_front_partner if CardStrategy.visible(self, action.united_front_partner) else null
		halve_follower_damage = action.halve_follower_damage or GameManager.combat_halves_follower_damage(known_attacker, known_defender, known_partner)
	for player in [bot_player, opponent]:
		if player == null:
			continue
		var loss_key := "bot_followers_lost" if player == bot_player else "opponent_followers_lost"
		var amount := int(result[loss_key])
		if halve_follower_damage:
			amount = GameManager.round_down_divide(amount, 2)
		if game_manager.has_turn_follower_loss_prevention(player):
			amount = 0
		if player == opponent:
			result["opponent_damage_before_guard"] = amount
			result["opponent_guard_spent"] = mini(amount, player.guard)
		else:
			result["bot_guard_spent"] = mini(amount, player.guard)
		amount = maxi(0, amount - player.guard)
		var source_key := "bot_loss_source" if player == bot_player else "opponent_loss_source"
		var source := result.get(source_key) as Card
		if source != null and CardStrategy.visible(self, source) and game_manager._source_converts_combat_follower_damage(source):
			amount = game_manager._get_combat_follower_conversion_amount(source, amount)
			result["bot_followers_gained" if player == opponent else "opponent_followers_gained"] = mini(player.followers, amount)
		amount = mini(player.followers, amount)
		result[loss_key] = amount
		result["opponent_wins" if player == bot_player else "bot_wins"] = amount >= player.followers and amount > 0
	if include_retreat:
		result = _estimate_retreat_economy(action, result, modified_card, speed_delta)
	if action != null and action.type == CardAction.Type.ATTACK:
		var defender := _get_attack_defender_card(action)
		for combatant: Card in [action.attacker, action.united_front_partner, defender]:
			if combatant == null or combatant.get_controller() != bot_player or combatant.abilities_suppressed_by_effects() \
					or not (combatant.is_stealth or (combatant == defender and projected_defender_stealth)):
				continue
			if combatant == defender and (combatant is MasmassuPriest or combatant is Grindylow):
				var targets := _get_reveal_removal_targets(combatant)
				var target := _choose_combat_reveal_removal(combatant, targets, action, result["casualties"])
				if target != null:
					_add_destroyed_card_to_economy(result, target)
					result["reveal_bonus"] = int(result.get("reveal_bonus", 0)) + _reveal_removal_mana_value(combatant, target)
			else:
				result["reveal_bonus"] = int(result.get("reveal_bonus", 0)) + _estimate_reveal_trigger_value(combatant)
	return result

func _get_reveal_removal_targets(source: Card) -> Array[Card]:
	if source is MasmassuPriest:
		return (source as MasmassuPriest).get_valid_targets(game_manager)
	return (source as Grindylow).get_valid_targets(game_manager)

func _choose_combat_reveal_removal(source: Card, targets: Array[Card], action: CardAction = null, excluded: Array = []) -> Card:
	if source.abilities_suppressed_by_effects():
		return null
	var best: Card = null
	var best_score := 0
	for target in targets:
		if target == null or target.get_controller() != opponent or target in excluded \
				or game_manager.is_immune_to_source(target, source) or game_manager.is_guardian_protected(target, source) \
				or CardStrategy.destruction_guard(target) or game_manager.has_turn_destruction_ward(opponent):
			continue
		var score := CardStrategy.value(self, target) + _reveal_removal_mana_value(source, target)
		# Solo combat is already committed. Removing its attacker still allows that
		# fight to resolve, so value the next attack the reveal can prevent.
		if action != null and target != action.attacker and target != action.united_front_partner \
				and CardStrategy.visible(self, target) and target.current_zone in opponent.frontline_zones \
				and (target.creature_mode == Card.CreatureMode.AGGRESSIVE or target.is_stealth) \
				and not target.is_sleeping and not target.has_status_effect("cannot_attack") \
				and not game_manager.is_followers_attack_blocked_by_active_structure(target, bot_player, []):
			score += _score_follower_loss(bot_player, maxi(0, _get_direct_follower_damage(target) - bot_player.guard))
		if score > best_score:
			best = target
			best_score = score
	return best

func _choose_removal_reveal_target_uid(source: Card, target_uids: Array) -> String:
	var targets := _get_reveal_removal_targets(source)
	for i in range(targets.size() - 1, -1, -1):
		if targets[i].uid not in target_uids:
			targets.remove_at(i)
	var action := match_manager.pending_combat_reveal_linger_action
	if action == null:
		# Networked bots receive the combat in their stack snapshot.
		for stack_action: CardAction in game_manager.action_stack:
			if stack_action.type == CardAction.Type.ATTACK and _get_attack_defender_card(stack_action) == source:
				action = stack_action
				break
	var excluded: Array = []
	if action != null:
		if _get_attack_defender_card(action) == source and CardStrategy.visible(self, action.attacker) \
				and (action.united_front_partner == null or CardStrategy.visible(self, action.united_front_partner)):
			excluded = _estimate_raw_attack_economy(action, null, 0, 0)["casualties"]
		else:
			action = null
	if action == null and game_manager.current_player == bot_player:
		return _choose_impact_removal_target(source, target_uids)
	var target := _choose_combat_reveal_removal(source, targets, action, excluded)
	return target.uid if target != null else ""

func _choose_impact_removal_target(source: Card, target_uids: Array, demon: Card = null) -> String:
	if source == null:
		return ""
	var danger := _forecast_incoming_follower_loss() if game_manager.current_player == bot_player else -1
	var best_uid := ""
	var best_score := 0
	for uid in target_uids:
		var target := game_manager.get_card_by_uid(str(uid))
		var removed := CardStrategy.removal_targets(self, source, target)
		if removed.is_empty():
			continue
		if source is Terror and (demon == null or not game_manager.can_player_add_to_hand_now(target.card_owner) \
				or (CardStrategy.visible(self, target) and game_manager.is_immune_to_source(target, demon))):
			continue
		if source is GugalannaBullOfHeaven and game_manager.can_player_add_to_hand_now(bot_player):
			removed.append(source)
		var own := target.get_controller() == bot_player
		var value := CardStrategy.value(self, target)
		var score := (-value if own else value) + _reveal_removal_mana_value(source, target)
		score += _follower_safety_gain(danger, {"removed": removed})
		if score > best_score:
			best_score = score
			best_uid = str(uid)
	return best_uid

func _reveal_removal_mana_value(source: Card, target: Card) -> int:
	if source is MasmassuPriest and CardStrategy.visible(self, target) \
			and (target.has_type("Demon") or target.has_type("Spirit")) and game_manager.can_player_gain_mana_now(bot_player):
		return MasmassuPriest.DEMON_SPIRIT_MANA_GAIN * ECON_MANA_VALUE
	return 0

func _estimate_reveal_trigger_value(card: Card) -> int:
	if card.abilities_suppressed_by_effects():
		return 0
	if card is SulakTheUnclean:
		return 0 # Its strength increase is already included in the combat forecast.
	if card is Afanc:
		var targets := 0
		for enemy in _get_board_creatures(opponent):
			if card._can_poison_target(enemy, game_manager):
				targets += 1
		return targets * ECON_CARD_VALUE / 3
	if card is PictishBeast:
		var count := 0
		for own in bot_player.frontline_zones + bot_player.reserve_zones:
			for field_card in own.cards:
				if field_card is PictishBeast and not field_card.is_stealth and not field_card.is_face_down and not field_card.is_prepared:
					count += 1
		for grave_card in bot_player.graveyard_zone.cards:
			if grave_card is PictishBeast:
				count += 1
		count += 1 # The revealed source becomes face-up before Mana Boon resolves.
		if not game_manager.can_player_gain_mana_now(bot_player):
			return 0
		return count * PictishBeast.MANA_PER_BEAST * ECON_MANA_VALUE
	if card is Lailoken:
		var lailoken_best_value := 0
		for lailoken_target in card.get_valid_targets(game_manager):
			if lailoken_target.get_controller() == opponent and not game_manager.is_immune_to_source(lailoken_target, card) \
					and not game_manager.is_guardian_protected(lailoken_target, card) and not CardStrategy.destruction_guard(lailoken_target):
				lailoken_best_value = maxi(lailoken_best_value, CardStrategy.value(self, lailoken_target))
		return lailoken_best_value
	if card is MasmassuPriest or card is Grindylow:
		var target := _choose_combat_reveal_removal(card, _get_reveal_removal_targets(card))
		if target != null:
			return CardStrategy.value(self, target) + _reveal_removal_mana_value(card, target)
	if card is Byggvir:
		var best_option_score := 0
		for option in card.get_brewing_options(game_manager):
			var power := option.get("power", null) as PowerCard
			var target := option.get("target", null) as Card
			var returned := option.get("card", null) as Card
			var option_score := 0
			match str(option.get("kind", "")):
				"return": option_score = _get_card_economic_value(returned)
				"flip": option_score = CardStrategy.unlock_score(self, power, 0) if power != null else 0
				"activate", "activate_targeted": option_score = CardStrategy.power_score(self, power, target) if power != null else 0
			best_option_score = maxi(best_option_score, option_score)
		return best_option_score
	return 0

func _estimate_retreat_economy(action: CardAction, fight: Dictionary, modified_card: Card, speed_delta: int) -> Dictionary:
	if action == null or action.type != CardAction.Type.ATTACK or action.united_front_partner != null:
		return fight
	var defender := _get_attack_defender_card(action)
	if not CardStrategy.visible(self, action.attacker) or not CardStrategy.visible(self, defender):
		return fight
	var result := fight
	for card in [action.attacker, defender]:
		if not card is Askelladen:
			continue
		var other: Card = defender if card == action.attacker else action.attacker
		if not _can_askelladen_retreat(card, other, modified_card, speed_delta):
			continue
		# Shelving removes both bodies and prevents all battle follower damage.
		var retreat := {
			"casualties": [],
			"bot_cards_lost": 0, "opponent_cards_lost": 0,
			"bot_followers_lost": 0, "opponent_followers_lost": 0,
			"bot_wins": false, "opponent_wins": false,
		}
		_add_destroyed_card_to_economy(retreat, action.attacker)
		_add_destroyed_card_to_economy(retreat, defender)
		var improvement := _score_attack_economy(retreat) - _score_attack_economy(result)
		if card.get_controller() == bot_player and improvement > ASKELLADEN_RETREAT_SCORE_MARGIN:
			result = retreat
		elif card.get_controller() == opponent and improvement < -ASKELLADEN_RETREAT_SCORE_MARGIN:
			result = retreat
	return result

func _estimate_raw_attack_economy(action: CardAction, modified_card: Card, str_delta: int, res_delta: int, projected_defender_mode: int = -1) -> Dictionary:
	var result := {
		"casualties": [],
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
	var partner := action.united_front_partner
	var defender := _get_attack_defender_card(action)
	var attacker_strength := _get_vision_adjusted_strength(attacker, modified_card, str_delta, defender)
	var support_strength := _get_vision_adjusted_strength(partner, modified_card, str_delta, defender)
	attacker_strength += support_strength
	var damage_source := attacker
	if partner != null and not game_manager._source_converts_combat_follower_damage(attacker) and game_manager._source_converts_combat_follower_damage(partner):
		damage_source = partner
	if defender == null:
		_add_follower_loss_to_economy(result, _get_attack_defending_player(action, defender), attacker_strength, damage_source)
		return result
	if defender.is_god:
		_add_follower_loss_to_economy(result, defender.get_controller(), attacker_strength, damage_source)
		return result
	if defender.is_petrified() or defender.card_type == Card.CardType.STRUCTURE:
		if attacker_strength > defender.get_effective_resilience() + (res_delta if defender == modified_card else 0):
			_add_combat_casualty(result, attacker, defender)
		return result
	if defender.card_type != Card.CardType.CREATURE:
		return result
	var defender_mode := int(defender.creature_mode) if projected_defender_mode < 0 else projected_defender_mode
	var attackers: Array[Card] = [attacker, partner]
	var opposing_cards: Array[Card] = [defender]
	if defender_mode == Card.CreatureMode.AGGRESSIVE:
		var defender_strength := _get_vision_adjusted_strength(defender, modified_card, str_delta, attacker)
		if attacker_strength > defender_strength:
			_add_combat_casualty(result, attacker, defender)
			var defender_damage_strength := game_manager._get_giants_disdain_damage_stat(defender, attackers, defender_strength)
			_add_follower_loss_to_economy(result, defender.get_controller(), attacker_strength - defender_damage_strength, damage_source)
		elif defender_strength > attacker_strength:
			_add_combat_casualty(result, defender, attacker)
			_add_combat_casualty(result, defender, partner)
			var attacker_damage_strength := game_manager._get_giants_disdain_damage_stat(attacker, opposing_cards, attacker_strength - support_strength)
			attacker_damage_strength += game_manager._get_giants_disdain_damage_stat(partner, opposing_cards, support_strength)
			_add_follower_loss_to_economy(result, attacker.get_controller(), defender_strength - attacker_damage_strength, defender)
		else:
			_add_combat_casualty(result, defender, attacker)
			_add_combat_casualty(result, defender, partner)
			_add_combat_casualty(result, attacker, defender)
		return result

	var attack_strength_vs_defense := _get_vision_adjusted_strength_vs_defense(attacker, modified_card, str_delta, defender)
	attack_strength_vs_defense += _get_vision_adjusted_strength_vs_defense(partner, modified_card, str_delta, defender)
	var defender_resilience := maxi(0, defender.get_effective_resilience() + (res_delta if defender == modified_card else 0))
	if attack_strength_vs_defense > defender_resilience:
		_add_combat_casualty(result, attacker, defender)
	else:
		if attack_strength_vs_defense < defender_resilience:
			_add_follower_loss_to_economy(result, attacker.get_controller(), defender_resilience - attack_strength_vs_defense)
		if game_manager._has_ferocious_defence(defender.get_controller()):
			_add_combat_casualty(result, defender, attacker)
			_add_combat_casualty(result, defender, partner)
	return result

func _add_combat_casualty(result: Dictionary, killer: Card, victim: Card) -> void:
	if victim == null or CardStrategy.destruction_guard(victim):
		return
	if not killer.can_destroy_combat_protected_creatures(victim):
		var replacement: Zone = victim.get_self_graveyard_replacement_zone(game_manager, true, true, false) if victim is BaseCard else null
		if replacement != null and replacement == victim.current_zone:
			return
	_add_destroyed_card_to_economy(result, victim)

func _score_attack_economy(result: Dictionary) -> int:
	var score := int(result.get("opponent_cards_lost", 0)) - int(result.get("bot_cards_lost", 0))
	score += int(result.get("reveal_bonus", 0))
	score += _score_follower_loss(opponent, int(result.get("opponent_followers_lost", 0)))
	score -= _score_follower_loss(bot_player, int(result.get("bot_followers_lost", 0)))
	score += CardStrategy.follower_gain(bot_player, int(result.get("bot_followers_gained", 0)))
	score -= CardStrategy.follower_gain(opponent, int(result.get("opponent_followers_gained", 0)))
	# A creature kill can prevent its next attack even if stronger enemies remain.
	for casualty: Card in result.get("casualties", []):
		if casualty.get_controller() == opponent and CardStrategy.visible(self, casualty) and casualty.current_zone != null \
				and casualty.current_zone.zone_type == Zone.ZoneType.FRONTLINE \
				and casualty.card_type == Card.CardType.CREATURE \
				and casualty.creature_mode == Card.CreatureMode.AGGRESSIVE \
				and not casualty.has_status_effect("cannot_attack") \
				and not game_manager.is_followers_attack_blocked_by_active_structure(casualty, bot_player):
			score += mini(_get_direct_follower_damage(casualty), bot_player.followers) * (ECON_CARD_VALUE / ECON_FOLLOWERS_PER_CARD)
	if bool(result.get("bot_wins", false)):
		score += ECON_CARD_VALUE * 20
	if bool(result.get("opponent_wins", false)):
		score -= ECON_CARD_VALUE * 20
	return score

func _add_destroyed_card_to_economy(result: Dictionary, card: Card) -> void:
	if card == null:
		return
	if result.has("casualties"):
		result["casualties"].append(card)
	var value := _get_card_economic_value(card) if CardStrategy.visible(self, card) else ECON_CARD_VALUE
	if card.get_controller() == bot_player:
		result["bot_cards_lost"] = int(result.get("bot_cards_lost", 0)) + value
	elif card.get_controller() == opponent:
		result["opponent_cards_lost"] = int(result.get("opponent_cards_lost", 0)) + value

func _add_follower_loss_to_economy(result: Dictionary, player: Player, amount: int, source: Card = null) -> void:
	if player == null or amount <= 0:
		return
	var actual_loss := amount
	if player == bot_player:
		result["bot_loss_source"] = source
		result["bot_followers_lost"] = int(result.get("bot_followers_lost", 0)) + actual_loss
		if actual_loss >= player.followers:
			result["opponent_wins"] = true
	elif player == opponent:
		result["opponent_loss_source"] = source
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

func _get_vision_adjusted_strength(card: Card, modified_card: Card, str_delta: int, opposing_card: Card = null) -> int:
	var strength := _get_combat_strength(card, opposing_card, str_delta if card == modified_card else 0)
	if card is SulakTheUnclean and card.is_stealth and CardStrategy.visible(self, card) and not card.abilities_suppressed_by_effects():
		strength += card.strength
	return strength

func _get_vision_adjusted_strength_vs_defense(card: Card, modified_card: Card, str_delta: int, opposing_card: Card = null) -> int:
	var strength := _get_attack_strength_against_defense(card, opposing_card, str_delta if card == modified_card else 0)
	if card is SulakTheUnclean and card.is_stealth and CardStrategy.visible(self, card) and not card.abilities_suppressed_by_effects():
		strength += card.strength
	return maxi(0, strength)

func _get_card_economic_value(card: Card) -> int:
	if card == null:
		return 0
	if card is WardingStone and card.get_attack_restriction_turns_remaining(game_manager) <= 0:
		return _get_inactive_warding_stone_value(card)
	return ECON_CARD_VALUE + maxi(0, int(float(_score_projected_card(card)) / 2.0))

func _get_inactive_warding_stone_value(stone: WardingStone) -> int:
	return ECON_MANA_VALUE if _opponent_can_use_mummu_on_warding_stone(stone) else ECON_CARD_VALUE / 5 - 1

func _opponent_can_use_mummu_on_warding_stone(stone: WardingStone) -> bool:
	var mummu := _get_opponent_mummu()
	if stone == null or opponent == null or game_manager == null or mummu == null \
			or stone.get_controller() != opponent \
			or stone.is_face_down \
			or stone.current_zone == null \
			or not stone.current_zone.is_board_zone() \
			or not game_manager.can_player_use_powers(opponent) \
			or mummu.is_muted \
			or mummu.current_zone != opponent.god_zone \
			or game_manager.is_immune_to_source(stone, mummu):
		return false
	return true

func _get_opponent_mummu() -> Mummu:
	if opponent == null or opponent.god_zone == null:
		return null
	for card in opponent.god_zone.cards:
		if card is Mummu:
			return card as Mummu
	return null

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
	if CardStrategy.supported(source) or CardStrategy.key(source) in CardStrategy.ACTIVE_POWERS or CardStrategy.key(source) in CardStrategy.BOARD_ABILITIES:
		return CardStrategy.target_score(self, source, target)
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
	if target is WardingStone and target.get_attack_restriction_turns_remaining(game_manager) <= 0:
		return _get_inactive_warding_stone_value(target)
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
	if card == null or bot_player == null or card.current_zone != bot_player.hand_zone:
		return -1000000
	return _score_creature_play_in_zone(card, zone, available_mana)

func _score_creature_play_in_zone(card: Card, zone: Zone, available_mana: int) -> int:
	if card.card_type != Card.CardType.CREATURE or zone == null:
		return -1000000
	var fenrir_devour_value := 0
	if card is Fenrir:
		fenrir_devour_value = _get_fenrir_devour_target_value(card as Fenrir)
		if fenrir_devour_value <= 0:
			return -1000000
	if card is ActiveGodCard:
		if zone not in bot_player.frontline_zones or not _has_good_manifestation_attack(card, Card.CreatureMode.AGGRESSIVE):
			return -1000000
		var god := _find_player_god()
		if god == null or god.get_active_god_deck_role(card) != GodCard.ACTIVE_GOD_DECK_ROLE_ALLOWED:
			return -1000000
	if zone.zone_owner != bot_player or not zone.cards.is_empty():
		return -1000000
	if bot_player.has_summoned_this_turn and not game_manager._can_use_extra_normal_summon(bot_player, card, zone):
		return -1000000
	var mana_cost := _get_play_cost(card, false)
	var payment_plan := _build_creature_summon_payment_plan(card, available_mana)
	if not bool(payment_plan.get("ok", false)):
		return -1000000
	var score := _score_projected_card(card)
	score -= mana_cost * 120
	score -= int(payment_plan.get("penalty", 0))
	if zone in bot_player.frontline_zones and _opponent_has_known_board_wipe(card, zone):
		score -= _get_card_economic_value(card)
	if card is Askelladen and _get_askelladen_problem_creature() != null:
		score += 1600
	if card is HariiFransiscan:
		score += 500
	if card is HariiJarl:
		score += _estimate_harii_jarl_warband_value(card as HariiJarl)
	score += fenrir_devour_value
	if card is Beyla:
		score += CardStrategy.wake_gain(self, card, true) / 2
	if card is RedCap:
		if game_manager.turn_number <= 1 or game_manager.has_resolved_attack_this_turn or zone not in bot_player.frontline_zones or game_manager.attack_restrictions.has(bot_player):
			return -1000000
		for field_card in game_manager.get_field_cards():
			if field_card is HeavySnow and not field_card.is_face_down and not field_card.abilities_suppressed():
				return -1000000
	return score

func _get_fenrir_devour_target_value(fenrir: Fenrir) -> int:
	if fenrir == null or game_manager == null or opponent == null:
		return 0
	var best_value := 0
	for target in fenrir.get_valid_devour_targets(game_manager):
		if target == null or target.get_controller() != opponent \
				or not CardStrategy.visible(self, target) \
				or game_manager.is_immune_to_source(target, fenrir) \
				or game_manager.is_guardian_protected(target, fenrir) \
				or game_manager.has_turn_destruction_ward(opponent):
			continue
		var target_value := _get_card_economic_value(target)
		target_value += target.get_effective_strength() * 30 + target.get_effective_resilience() * 15
		best_value = maxi(best_value, target_value)
	return best_value

func _opponent_has_known_board_wipe(projected_card: Card = null, projected_zone: Zone = null) -> bool:
	if opponent == null or opponent.hand_zone == null:
		return false
	for zone in opponent.frontline_zones + opponent.reserve_zones:
		for card in zone.cards:
			if not CardStrategy.visible(self, card) or not card.is_prepared or CardStrategy.key(card) not in [
				"TheInferno", "FiresOfJudgment", "TheDeluge", "Earthquake", "Famine",
				"OccultSingularity", "FalloftheMighty", "BaneOfTheSvartalfar",
			]:
				continue
			if opponent.mana >= game_manager.get_prepared_card_activation_mana_cost(opponent, card):
				if card is TheInferno:
					if projected_zone in bot_player.frontline_zones:
						return true
					for bot_frontline in bot_player.frontline_zones:
						if not bot_frontline.cards.is_empty():
							return true
				else:
					for target in CardStrategy.wipe_cards(self, card):
						if target.get_controller() == bot_player and not game_manager.is_immune_to_source(target, card):
							return true
					if _known_wipe_hits_projected_card(card, projected_card, projected_zone):
						return true
	for card in opponent.hand_zone.cards:
		if not CardStrategy.visible(self, card) or CardStrategy.key(card) not in [
			"FiresOfJudgment", "TheDeluge", "Earthquake", "Famine", "OccultSingularity",
			"FalloftheMighty", "BaneOfTheSvartalfar",
		]:
			continue
		if opponent.mana < game_manager.get_card_play_mana_cost(opponent, card, false):
			continue
		for target in CardStrategy.wipe_cards(self, card):
			if target.get_controller() == bot_player and not game_manager.is_immune_to_source(target, card):
				return true
		if _known_wipe_hits_projected_card(card, projected_card, projected_zone):
			return true
	return false

func _known_wipe_hits_projected_card(wipe: Card, projected_card: Card, projected_zone: Zone) -> bool:
	if wipe == null or projected_card == null or projected_zone == null or projected_zone not in bot_player.frontline_zones:
		return false
	if game_manager.is_immune_to_source(projected_card, wipe):
		return false
	match CardStrategy.key(wipe):
		"FiresOfJudgment":
			return projected_card.card_type in [Card.CardType.CREATURE, Card.CardType.STRUCTURE, Card.CardType.EQUIPMENT]
		"TheDeluge":
			return projected_card.is_physical_card()
	return false

func _build_creature_summon_payment_plan(card: Card, available_mana: int = -1, forecast: Dictionary = {}) -> Dictionary:
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
	if card.card_type != Card.CardType.CREATURE:
		return result
	var mana_cost := _get_play_cost(card, false)
	var available := bot_player.mana if available_mana < 0 else available_mana
	if available < mana_cost:
		return result
	# Mana was checked against the forecast above. Validate the other costs against the current state.
	var validation_mana_cost := mini(mana_cost, bot_player.mana)
	if card.sacrifice_cost <= 0:
		if _validate_creature_summon_payment_plan(card, validation_mana_cost, [], []):
			result["ok"] = true
		return result

	var direct_plan := _choose_direct_summon_sacrifice_plan(card.sacrifice_cost, forecast)
	var altar_plan := _choose_altar_of_dreams_plan(card, forecast)
	var chosen_plan := {}
	if not altar_plan.is_empty() and not direct_plan.is_empty():
		chosen_plan = altar_plan if int(altar_plan["selection_cost"]) <= int(direct_plan["selection_cost"]) else direct_plan
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
	if not _validate_creature_summon_payment_plan(card, validation_mana_cost, sacrifice_cards, altar_void_cards):
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

func _choose_direct_summon_sacrifice_plan(required: int, forecast: Dictionary = {}) -> Dictionary:
	if required <= 0:
		return {"sacrifice_cards": [], "altar_void_cards": [], "penalty": 0}
	var candidates := _get_valid_summon_sacrifice_candidates()
	if candidates.size() < required:
		return {}
	var chosen := _choose_lowest_scored_cards(candidates, required, "sacrifice", forecast)
	if chosen.size() != required:
		return {}
	var penalty := 0
	for card in chosen:
		penalty += _score_summon_sacrifice_candidate(card)
	return {
		"sacrifice_cards": chosen,
		"altar_void_cards": [],
		"penalty": penalty,
		"selection_cost": penalty - _summon_payment_safety_gain(forecast, chosen),
	}

func _choose_altar_of_dreams_plan(card: Card, forecast: Dictionary = {}) -> Dictionary:
	var altar := _get_active_altar_of_dreams_for_bot()
	if altar == null or card == null or not altar.can_replace_sacrifice_cost(card, game_manager):
		return {}
	var required := card.sacrifice_cost
	var valid_targets: Array[Card] = []
	for target in altar.get_valid_void_targets(game_manager):
		if not (target is ActiveGodCard):
			valid_targets.append(target)
	if valid_targets.size() < required:
		return {}
	var chosen := _choose_lowest_scored_cards(valid_targets, required, "altar", forecast)
	if chosen.size() != required:
		return {}
	var penalty := 0
	for target in chosen:
		penalty += _score_altar_void_target(target)
	return {
		"sacrifice_cards": [],
		"altar_void_cards": chosen,
		"penalty": penalty,
		"selection_cost": penalty - _summon_payment_safety_gain(forecast, chosen),
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
				and not (card is ActiveGodCard) \
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

func _choose_lowest_scored_cards(candidates: Array[Card], required: int, score_mode: String, forecast: Dictionary = {}) -> Array[Card]:
	if not forecast.is_empty() and required == 2:
		var pair: Array[Card] = []
		var lowest := 1000000000
		for first in range(candidates.size()):
			for second in range(first + 1, candidates.size()):
				var payment: Array[Card] = [candidates[first], candidates[second]]
				var cost := _score_lowest_selection_candidate(payment[0], score_mode) + _score_lowest_selection_candidate(payment[1], score_mode)
				cost -= _summon_payment_safety_gain(forecast, payment)
				if cost < lowest:
					lowest = cost
					pair = payment
		return pair
	var chosen: Array[Card] = []
	var used_uids := {}
	for _i in range(required):
		var best_card: Card = null
		var best_score := 1000000000
		for candidate in candidates:
			if candidate == null or used_uids.has(candidate.uid):
				continue
			var candidate_score := _score_lowest_selection_candidate(candidate, score_mode)
			candidate_score -= _summon_payment_safety_gain(forecast, chosen + [candidate])
			if best_card == null or candidate_score < best_score or (candidate_score == best_score and _get_card_order_index(candidate) < _get_card_order_index(best_card)):
				best_card = candidate
				best_score = candidate_score
		if best_card == null:
			return []
		chosen.append(best_card)
		used_uids[best_card.uid] = true
	return chosen

func _summon_payment_safety_gain(forecast: Dictionary, payment: Array) -> int:
	if forecast.is_empty():
		return 0
	var projected := forecast.duplicate()
	projected["removed"] = payment
	return _follower_safety_gain(int(forecast["danger"]), projected)

func _score_lowest_selection_candidate(card: Card, score_mode: String) -> int:
	match score_mode:
		"altar":
			return _score_altar_void_target(card)
		_:
			return _score_summon_sacrifice_candidate(card)

func _score_summon_sacrifice_candidate(card: Card) -> int:
	if card == null or card.is_god or card is ActiveGodCard:
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
	if card == null or card.is_god or card is ActiveGodCard:
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
