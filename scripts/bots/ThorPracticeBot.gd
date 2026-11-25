extends RefCounted
class_name ThorPracticeBot

const CardPromptPolicy = preload("res://scripts/bots/BotCardPromptPolicy.gd")
const CardStrategy = preload("res://scripts/bots/BotCardStrategy.gd")
const StrategyPosture = preload("res://scripts/bots/BotStrategyPosture.gd")

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
const VEIL_CONCEALMENT_VALUE := 1200
const SINGLE_TARGET_REMOVAL_HOLD_VALUE := 1000
const COMBAT_ATTACK_SEARCH_WIDTH := 16
const COMBAT_REMOVAL_SEARCH_WIDTH := 32
const COMBAT_RESPONSE_SEARCH_WIDTH := 24
const ECON_MANA_VALUE := 1000
# Stats dictionaries can carry projected combat guards as well as stat deltas.
# The key is internal to bot forecasting and never reaches the engine.
const PROJECTED_DESTRUCTION_GUARDS_KEY := "_projected_destruction_guards"
# Wipes the bot casts in its own main phase, so Mummu can shelve every own
# doomed card worth more banked than destroyed before the sweep resolves
# (Bane of the Svartalfar petrifies instead of destroying and is excluded).
const MUMMU_SHELVE_WIPE_KEYS := [
	"TheInferno", "TheDeluge", "Earthquake", "FiresOfJudgment", "Famine",
	"OccultSingularity", "FalloftheMighty",
]
# Celestial Light converts one follower per grave card once Nusku, Active God
# perishes, so declining Core Flame only enters consideration past this grave.
const NUSKU_CELESTIAL_LIGHT_MIN_GRAVE := 12
# God Death makes the enemy board's defensive value a countdown: blocking never
# stops the 7/turn bleed, so combat that a removal unlocks from a locked board
# is priced at double worth while the bot is the one bleeding.
const GOD_DEATH_UNLOCK_URGENCY := 2
# Rough mid-catalog strength per mana used to guess how large a creature the
# opponent could deploy next turn when their hand is not revealed.
const ECON_FORECAST_SUMMON_STR_PER_MANA := 8
# Per point of STR charged against reserve-line placement while the frontline
# still has room. A reserve creature forgoes the near-term attack option a
# frontline creature keeps (one minor action from flipping to aggression),
# so hiding a semi-decent attacker on the reserve line should require real
# danger or a weak attacker, not just a defensive mood.
const RESERVE_PLACEMENT_STR_VALUE := 200
const ASKELLADEN_BOUNCE_TARGET_SCORE := 1800
const ASKELLADEN_RETREAT_SCORE_MARGIN := 400
# Creature fighting presence is worth roughly a quarter of its board value per
# missed own turn; a Tree of Life cycle keeps Kur-Jara off the board for 2-4
# of those turns before it resurrects.
const KUR_JARA_PRESENCE_TURNS := 4.0
# Flat bonus while the grave still holds another Divine/Priest after the
# current Tree of Life cycle, because the ability re-arms once it resolves.
const KUR_JARA_ENGINE_CONTINUATION := 800
# Opponent board creatures whose ACTIVATED abilities destroy a target on the
# controller's own turn, so a fresh summon they can legally reach is a free
# meal: a face-up Lindwyrm devours anything two levels weaker (Devour's
# target check has no hidden-state filter, so stealth does not dodge it) and
# grows on the kill, and Clay-Eaters' Geophagia eats structures and Stone
# bodies at end of turn. Impact/Reveal devourers (Fenrir, Grindylow, Masmassu
# Priest, Gugalanna) fire only when they enter the field themselves, so they
# are not standing next-turn threats here.
const OPPONENT_ACTIVATED_REMOVAL_KEYS := ["Lindwyrm", "ClayEaters"]

var _active: bool = false
var _step_queued: bool = false
var _retry_poll_queued: bool = false
# A prompt handler can re-emit another prompt synchronously (the authoritative
# MatchManager emits over a signal). Answering that nested prompt inline grows
# one stack frame per prompt until Godot overflows. Defer nested prompts until
# the current handler returns so the answer chain runs on later frames.
var _ui_interaction_in_progress: bool = false
var _deferred_ui_interactions: Array[Dictionary] = []
var _deferred_ui_flush_scheduled: bool = false
var _answered_prompt_ids: Dictionary = {}
var _current_card_prompt_id: int = -1
var _last_submitted_prompt_id: int = -1
var _strategy_activation_turns: Dictionary = {}
var _pending_power_activation_uid := ""
var _dellingr_revealed_target_uids: Dictionary = {}
var _posture_cache := {"turn": -1, "value": {}}
var _posture_evaluating := false
var _locked_board_evaluating := false
var _scoring_byggvir_brewing := false
# Opt-in decision tracing for summon planning. Set OTHERGODS_BOT_DECISION_LOG=1
# on the bot's process (practice window or headless server) to print every
# evaluated summon plan with its score components, so a chosen chump blocker
# can be diffed against the rejected alternative on the same turn.
var _decision_log_env := OS.get_environment("OTHERGODS_BOT_DECISION_LOG").strip_edges().to_lower()
var _decision_log_enabled: bool = not _decision_log_env.is_empty() \
		and _decision_log_env != "0" and _decision_log_env != "false"

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
	_ui_interaction_in_progress = false
	_deferred_ui_interactions.clear()
	_deferred_ui_flush_scheduled = false
	_answered_prompt_ids.clear()
	_strategy_activation_turns.clear()
	_dellingr_revealed_target_uids.clear()
	_pending_power_activation_uid = ""
	_current_card_prompt_id = -1
	_last_submitted_prompt_id = -1
	_posture_cache = {"turn": -1, "value": {}}
	_posture_evaluating = false

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

# Temporary [CRUMB] breadcrumbs for localizing mid-match freezes: every line
# lands in user://logs/godot.log, so the last crumb before a silence names the
# phase that hung. Grep for "[CRUMB]" and remove these once the hang is found.
func _crumb(label: String) -> void:
	var turn := -1
	if game_manager != null:
		turn = game_manager.turn_number
	print("[CRUMB] pid=", OS.get_process_id(), " p", player_index,
			" turn=", turn, " ms=", Time.get_ticks_msec(), " ", label)

func _on_match_ui_interaction(prompt_player_index: int, type: String, data: Dictionary) -> void:
	if not _begin_ui_interaction(prompt_player_index, type, data):
		return
	_handle_ui_interaction(prompt_player_index, type, data)
	_ui_interaction_in_progress = false

func _begin_ui_interaction(prompt_player_index: int, type: String, data: Dictionary) -> bool:
	if not _ui_interaction_in_progress:
		_ui_interaction_in_progress = true
		return true
	# Nested prompt: queue it instead of answering inline. A prompt may be
	# re-emitted by the command that answers the previous one, and that cycle
	# would otherwise recurse until Godot's stack overflows.
	if _deferred_ui_interactions.size() >= 64:
		_deferred_ui_interactions.pop_front()
	_deferred_ui_interactions.append({
		"prompt_player_index": prompt_player_index,
		"type": type,
		"data": data.duplicate(true),
	})
	if not _deferred_ui_flush_scheduled:
		_deferred_ui_flush_scheduled = true
		call_deferred("_flush_deferred_ui_interactions")
	return false

func _is_deferred_prompt_stale(entry: Dictionary) -> bool:
	if match_manager == null or not match_manager.has_method("get_pending_ui_interaction_entries"):
		return false
	var data: Dictionary = entry.get("data", {})
	var prompt_id := int(data.get("_prompt_id", -1))
	if prompt_id < 0:
		return false
	for pending_entry in match_manager.get_pending_ui_interaction_entries():
		if int(pending_entry.get("prompt_id", -1)) == prompt_id:
			return false
	# The prompt was consumed while this answer waited in the re-entrancy queue.
	return true

func _flush_deferred_ui_interactions() -> void:
	_deferred_ui_flush_scheduled = false
	if not _active or _deferred_ui_interactions.is_empty():
		return
	if _ui_interaction_in_progress:
		call_deferred("_flush_deferred_ui_interactions")
		return
	var pending := _deferred_ui_interactions.duplicate(true)
	_deferred_ui_interactions.clear()
	for entry in pending:
		if not _active:
			break
		if _is_deferred_prompt_stale(entry):
			continue
		_on_match_ui_interaction(
			int(entry.get("prompt_player_index", -1)),
			str(entry.get("type", "")),
			entry.get("data", {})
		)

func _handle_ui_interaction(prompt_player_index: int, type: String, data: Dictionary) -> void:
	if prompt_player_index != player_index:
		return
	if not prompt_types_only.is_empty() and type not in prompt_types_only:
		return
	if type != "priority":
		_crumb("prompt:" + type)
	_mana_econ_cache = {}
	_tonal_setup_cache = {}
	_altar_line_cache = {}
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

# True when the active targeting selection was raised by this bot's own card
# in a game this bot resolves authoritatively. Networked client mirrors must
# not confirm locally; the authoritative side answers there.
func _owns_pending_click_selection() -> bool:
	if match_manager == null or not match_manager.pending_click_selection_confirm.is_valid():
		return false
	if match_manager.network_manager != null \
			and not bool(match_manager.network_manager.get("is_server")):
		return false
	var source: Card = match_manager.pending_click_selection_source
	return source != null and source.get_controller() == bot_player

# Mandatory self-raised selections resolve with the first valid target
# (matching the engine's mandatory-selection policy); optional ones cancel
# when no target remains, and mandatory ones with none fizzle safely via the
# empty-target resolution path.
func _resolve_own_click_selection() -> void:
	var targets: Array = match_manager.pending_click_selection_valid_targets
	var target = targets[0] if not targets.is_empty() else null
	if target != null:
		match_manager.confirm_click_selection(target)
	elif match_manager.pending_click_selection_allows_cancel:
		match_manager.cancel_targeting()
	else:
		match_manager.resolve_mandatory_selection_without_target()
	_queue_retry_poll()

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
	# A click selection raised by this bot's own card must be answered by the
	# bot: nobody else will in headless games, and the human answers their own.
	# Check this before the pending-attack guard: a reveal or combat trigger can
	# leave the attack bookkeeping set while raising a mandatory selection, and
	# waiting for the attack to clear would stall the game forever.
	if match_manager.is_targeting_active():
		return _owns_pending_click_selection()
	if match_manager.selected_attacker != null or match_manager.pending_attack_target != null:
		return false
	# A priority window can be offered while another action is still recorded as
	# resolving (for example Masmassu Priest's deferred reveal). Answering that
	# window is legal and necessary: waiting for resolving_stack_actions to
	# empty stalls the bot with a live priority prompt and no other way forward.
	if not game_manager.action_stack.is_empty():
		return game_manager.priority_player == bot_player
	if not game_manager.resolving_stack_actions.is_empty():
		return false
	return game_manager.current_player == bot_player

func _run_step() -> void:
	_step_queued = false
	_mana_econ_cache = {}
	_tonal_setup_cache = {}
	_altar_line_cache = {}
	if not _should_queue_step():
		return
	if _owns_pending_click_selection():
		_crumb("click_selection:start")
		_resolve_own_click_selection()
		_crumb("click_selection:end")
		return
	if not game_manager.action_stack.is_empty():
		_crumb("priority:start")
		_handle_priority()
		_crumb("priority:end")
		return
	if game_manager.current_player != bot_player:
		return
	if not game_manager.has_resolved_turn_upkeep():
		_crumb("upkeep:start")
		_handle_upkeep()
		_crumb("upkeep:end")
		return
	_crumb("main:start")
	if _take_main_phase_action():
		_crumb("main:acted")
		_queue_retry_poll()
		return
	_crumb("finish_turn")
	_finish_turn()

func _handle_upkeep() -> void:
	var zone := _get_first_open_summon_zone(bot_player)
	var upkeep := _choose_upkeep_option(zone)
	if zone != null and not upkeep.get("prioritize_mana", false):
		for card in bot_player.hand_zone.cards:
			if card is Skoll and card.can_use_upkeep_summon(game_manager):
				var normal := _get_best_affordable_hand_creature(game_manager.get_effective_upkeep_mana_gain(game_manager.get_base_upkeep_mana_gain(), bot_player))
				if normal == null or _score_projected_card(card) >= _score_projected_card(normal):
					var mode := _choose_creature_summon_mode(card)
					var stealth := _should_summon_creature_stealthily(card, zone, mode)
					var mode_name := "stealth" if stealth else "aggressive" if mode == Card.CreatureMode.AGGRESSIVE else "defensive"
					_submit_action({"type": "skoll_upkeep_summon", "skoll_uid": card.uid, "player_index": player_index, "zone_type": zone.zone_type, "zone_index": zone.zone_index, "mode": mode_name})
					return
	if str(upkeep.get("choice", "draw")) == "brood":
		var brood_card: Card = upkeep.get("brood_card")
		if brood_card != null and _submit_action({"type": "tiamat_upkeep_choice", "card_uid": brood_card.uid}):
			return
		_submit_action({"type": "upkeep_choice", "choice": "draw"})
		return
	_submit_action({
		"type": "upkeep_choice",
		"choice": str(upkeep.get("choice", "draw")),
	})

# The Matriarch Rule is Tiamat's third upkeep choice alongside draw and mana:
# it adds one known brood card to hand and grants no draw and no mana, so it
# can never stack with the other options. The brood slot is a warehouse, not a
# deck — a slotted card keeps just as well, so a take is only worth the upkeep
# choice when it does something now: a this-turn play line (summon it and
# attack — Gallu over a 21-str body), or a real option increase (a starved
# hand, or no deck left to draw from). A brood card whose copy the hand
# already holds fails both tests — the hand copy already covers the play, the
# bank, and any Altar continuation — so duplicate takes are skipped entirely;
# the slot copy stays as a real option for a later upkeep. Values share
# _choose_upkeep_option's scale; bank_plan_base is the draw option's summon so
# the bank plan prices the same turn with the known card instead of a random
# one.
func _choose_brood_option(zone: Zone, bank_plan_base: int, draw_need: float) -> Dictionary:
	if not TiamatThePrimordial.can_offer_matriarch_rule(game_manager):
		return {}
	var banking_pays := draw_need >= 1.2 or bot_player.deck_zone.cards.is_empty()
	var best_card: Card = null
	var best_value := 0
	for card in TiamatThePrimordial.get_available_matriarch_rule_cards(bot_player):
		var card_key := CardCatalog.to_lookup_key(card.card_name)
		var duplicate_in_hand := false
		for hand_card in bot_player.hand_zone.cards:
			if CardCatalog.to_lookup_key(hand_card.card_name) == card_key:
				duplicate_in_hand = true
				break
		if duplicate_in_hand:
			continue
		var summon_score := _score_creature_play_in_zone(card, zone, bot_player.mana)
		if summon_score > -1000000:
			summon_score += _estimate_summon_attack_value(card, zone, bot_player.mana)
			if not _opponent_board_is_empty() and _choose_creature_summon_mode(card) == Card.CreatureMode.DEFENSIVE:
				summon_score += int(maxi(0, _estimate_defensive_summon_value(card, zone)) * 0.5)
		var bank_score := 0
		if banking_pays:
			bank_score = bank_plan_base + int(float(_deck_card_hand_value(card, bot_player.mana)) * draw_need)
		var value := maxi(summon_score, bank_score)
		# A Demon or Spirit coster starts the Altar of Dreams line: the take
		# banks the chain's continuation when the sleepers it will Void are
		# still reachable, beyond the generic warehouse value above.
		value += CardStrategy.brood_take_line_gain(self, card)
		if value > best_value:
			best_card = card
			best_value = value
	if best_card == null:
		return {}
	return {"card": best_card, "value": best_value}

func _choose_upkeep_option(zone: Zone) -> Dictionary:
	var draw_mana_gain := GameManager.UPKEEP_DRAW_MANA_GAIN
	var mana_gain := GameManager.UPKEEP_MANA_GAIN
	if game_manager != null:
		draw_mana_gain = game_manager.get_base_upkeep_draw_mana_gain()
		mana_gain = game_manager.get_base_upkeep_mana_gain()
		draw_mana_gain = game_manager.get_effective_upkeep_mana_gain(draw_mana_gain, bot_player)
		mana_gain = game_manager.get_effective_upkeep_mana_gain(mana_gain, bot_player)
	if _upkeep_mana_enables_hermes_lethal():
		return {"choice": "mana", "prioritize_mana": true}
	# A ready Mead brew is available under either upkeep choice, so both
	# budgets carry it: the mana option then has to unlock something the
	# brew alone cannot fund to be worth its card.
	var brew := _ready_brew_mana_gain()
	var draw_budget := bot_player.mana + draw_mana_gain + brew
	var mana_budget := bot_player.mana + mana_gain + brew
	if _upkeep_mana_enables_manifestation_removal(draw_budget, mana_budget):
		return {"choice": "mana", "prioritize_mana": true}
	var best_now := _get_best_affordable_hand_creature(draw_mana_gain + brew, zone)
	var best_with_bonus := _get_best_affordable_hand_creature(mana_gain + brew, zone)
	var draw_score := 0 if best_now == null else _score_creature_play(best_now, zone, draw_budget)
	var mana_score := 0 if best_with_bonus == null else _score_creature_play(best_with_bonus, zone, mana_budget)
	if best_now != null:
		draw_score += _estimate_summon_attack_value(best_now, zone, draw_budget)
	if best_with_bonus != null:
		mana_score += _estimate_summon_attack_value(best_with_bonus, zone, mana_budget)
	# Deck-aware upkeep comparison. The mana option is worth what the extra
	# income still buys (its value decays once the stock passes everything the
	# remaining deck and board can pay for); the draw option is worth the
	# expected hand value of the card it takes from the bot's own deck.
	var draw_need := _upkeep_draw_need()
	var draw_card_value := _expected_deck_draw_value(draw_budget)
	# The upkeep draw is playable this turn, so digging credits the deck's
	# remaining answers priced against the current board — not just average
	# card quality.
	var dig_gain := _expected_deck_dig_gain(draw_budget, _forecast_incoming_follower_loss())
	var mana_option := mana_score + CardStrategy.mana_gain_value(self, mana_gain)
	var draw_option := draw_score + int(float(draw_card_value) * draw_need) + dig_gain
	# The Matriarch take is a third, mutually exclusive choice: it grants no
	# draw and no mana. Mana income decaying does not make it good — the random
	# deck card stays the real rival — so it only wins by outscoring both.
	var brood := _choose_brood_option(zone, draw_score, draw_need)
	var brood_option := int(brood.get("value", 0))
	if not brood.is_empty() and brood_option > mana_option and brood_option > draw_option:
		return {"choice": "brood", "brood_card": brood.get("card")}
	if best_now == null and best_with_bonus != null:
		# The bonus mana unlocks the only hand summon; a random draw cannot
		# fund it, so the income wins without a card comparison.
		return {"choice": "mana"}
	# Aphrodite's upkeep income only matters for the Violent Delights line: when
	# the enslave line already fits the draw budget, keep drawing; when a real
	# line needs the bonus mana, weigh it against the draw option; when no line
	# exists, her unusable activation must not inflate the mana preference.
	var aphrodite_overrides_economy := false
	if _find_player_god() is AphroditeAreia and mana_budget > draw_budget:
		var attacks := _get_combat_candidates(mana_budget)
		var mana_line := _plan_combat(attacks, [], null, 0, null, mana_budget)
		if bool(mana_line.get("violent_delights", false)):
			var draw_line := _plan_combat(attacks, [], null, 0, null, draw_budget)
			if bool(draw_line.get("violent_delights", false)):
				return {"choice": "draw"}
			if int(mana_line["score"]) > draw_option:
				return {"choice": "mana"}
		else:
			aphrodite_overrides_economy = true
	if mana_option > draw_option and not aphrodite_overrides_economy:
		return {"choice": "mana"}
	if _upkeep_mana_enables_manifestation(mana_gain):
		return {"choice": "mana"}
	if _upkeep_mana_enables_tonal_extraction(mana_gain):
		return {"choice": "mana"}
	if _upkeep_mana_enables_altar_line(mana_gain):
		return {"choice": "mana"}
	if bot_player.hand_zone.cards.size() >= 3:
		for card in bot_player.hand_zone.cards:
			if CardStrategy.supported(card) and card is SpellCard and card.sacrifice_cost == 0:
				var cost := _get_play_cost(card, false)
				if cost > draw_budget and cost <= mana_budget:
					var target := CardStrategy.best_target(self, card, CardStrategy.targets(self, card))
					if (not card.targets or target != null) and CardStrategy.effect_score(self, card, target) > ECON_CARD_VALUE:
						return {"choice": "mana"}
	return {"choice": "draw"}

# How urgently the bot needs another card at upkeep: an empty hand pays a
# premium for any card, a stocked hand discounts the random draw.
func _upkeep_draw_need() -> float:
	var hand_size := bot_player.hand_zone.cards.size()
	return 1.5 if hand_size <= 1 else 1.2 if hand_size <= 2 else 0.8 if hand_size >= 4 else 1.0

func _upkeep_mana_enables_manifestation_removal(draw_budget: int, mana_budget: int) -> bool:
	if mana_budget <= draw_budget:
		return false
	# Use the same removal evaluation that prices retaliation after Champion's Call.
	var mana_enables_removal := false
	for target in _get_board_creatures(opponent):
		if not CardStrategy.visible(self, target) or not target is ActiveGodCard \
				or target.is_face_down or target.is_stealth:
			continue
		if _manifestation_removal_value(target, draw_budget) > 0:
			return false
		if not mana_enables_removal and _manifestation_removal_value(target, mana_budget) > 0:
			mana_enables_removal = true
	return mana_enables_removal

func _upkeep_mana_enables_hermes_lethal() -> bool:
	var hermes := _find_player_god() as Hermes
	if hermes == null:
		return false
	var draw_gain := game_manager.get_effective_upkeep_mana_gain(game_manager.get_base_upkeep_draw_mana_gain(), bot_player)
	var mana_gain := game_manager.get_effective_upkeep_mana_gain(game_manager.get_base_upkeep_mana_gain(), bot_player)
	# The brew is available under either choice, so it lifts both budgets:
	# the mana income only wins when the lethal line still needs it beyond
	# what the Mead already funds.
	var brew := _ready_brew_mana_gain()
	var draw_budget := bot_player.mana + draw_gain + brew
	var mana_budget := bot_player.mana + mana_gain + brew
	if mana_budget <= draw_budget or not hermes.can_plan_activation_after_upkeep(game_manager, mana_budget):
		return false
	var attacks := _get_combat_candidates(mana_budget)
	var draw_line := _plan_combat(attacks, [], null, 0, null, draw_budget)
	if bool(draw_line.get("lethal", false)) or bool(_plan_hermes_speed(attacks, draw_line, draw_budget).get("lethal", false)):
		return false
	var mana_line := _plan_combat(attacks, [], null, 0, null, mana_budget)
	return bool(mana_line.get("lethal", false)) or bool(_plan_hermes_speed(attacks, mana_line, mana_budget).get("lethal", false))

func _upkeep_mana_enables_manifestation(mana_gain: int) -> bool:
	if mana_gain <= 0 or _get_first_open_summon_zone(bot_player) == null:
		return false
	var god := _find_player_god()
	if god == null or not game_manager.can_player_use_powers(bot_player):
		return false
	# The brew is available under either upkeep choice, so the mana income
	# only counts when it unlocks a line beyond the brew's own reach.
	var base := bot_player.mana + _ready_brew_mana_gain()
	if not god.is_muted and god.has_champions_call():
		var manifestation := god.get_champions_call_candidate(true)
		if manifestation != null:
			var cost := game_manager.get_creature_summon_mana_cost(bot_player, manifestation, god)
			if cost > base and cost <= base + mana_gain:
				return true
	for power in _get_player_powers():
		if power is TakeTheField and power.is_face_down and not power.is_muted and not power.is_activation_locked(game_manager):
			var cost: int = power.get_unlock_display_mana_cost(game_manager)
			if cost > base and cost <= base + mana_gain:
				return true
	return false

func _handle_priority() -> void:
	if game_manager.priority_player != bot_player:
		return
	_crumb("priority:choose")
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
		if top_action.type == CardAction.Type.ATTACK:
			for response_card in responses:
				if response_card is JiangZiyaFisherOfKings \
						and (top_action.target == response_card or top_action.interceptor == response_card):
					return response_card
			for response_card in responses:
				# Sighting is a free summon while one of our Warriors or
				# Lupines attacks; always take the extra body.
				if response_card is RavenStorm:
					return response_card
		for response_card in responses:
			if response_card is E2Abzu and int(_score_priority_card(response_card, top_action, danger)["score"]) > 0:
				return response_card
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
	if card is RavenStorm:
		# Sighting summons this card from hand for free; the body is pure gain.
		return {"score": 2000, "target": null}
	if card is E2Abzu:
		var dodge_best := {"score": CardStrategy.BAD, "target": null}
		for target: Card in card.get_priority_field_targets(game_manager, action):
			var score := _score_e2_abzu_dodge(card, target, action)
			if score > int(dodge_best["score"]):
				dodge_best = {"score": score, "target": target}
		return dodge_best
	var targets := CardStrategy.targets(self, card, action)
	if card is ObsidianReflection:
		if targets.is_empty():
			return {"score": CardStrategy.BAD, "target": null}
		# MatchManager uses the only legal target, or the lead attacker when
		# the response has multiple automatic candidates.
		var reflected_attacker: Card = targets[0] if targets.size() == 1 else action.attacker
		return {"score": _score_obsidian_reflection(card, action, reflected_attacker), "target": reflected_attacker}
	if targets.is_empty():
		targets = [null]
	var followups: Array = game_manager.get_priority_responses(bot_player) if action in game_manager.action_stack else []
	var best := {"score": CardStrategy.BAD, "target": null}
	for target: Card in targets:
		var score := CardStrategy.effect_score(self, card, target, action)
		# Priority responses still count as spell or hex plays, so an active
		# Immortal Techniques with a friendly Mage refunds one mana here too.
		var refund_gain := _immortal_techniques_refund_gain(card)
		if refund_gain > 0:
			score += CardStrategy.mana_gain_value(self, refund_gain)
		if not followups.is_empty() and target != null:
			score = maxi(score, _score_combat_buff_sequence(card, target, action, followups))
		var removed := CardStrategy.removal_targets(self, card, target, action)
		if score <= CardStrategy.BAD and removed.is_empty():
			continue
		if not removed.is_empty():
			if score <= CardStrategy.BAD:
				score = -CardStrategy.mana_penalty(self, CardStrategy.activation_cost(self, card))
				for victim: Card in removed:
					score += CardStrategy.value(self, victim) if _get_card_loss_owner(victim) == opponent else -CardStrategy.value(self, victim)
			if card is E2Abzu:
				score -= E2Abzu.VOID_AND_RETURN_COST * _mana_rate()
			if action.type == CardAction.Type.ATTACK and CardStrategy.combat_visible(self, action):
				var both_attackers_removed := action.attacker in removed and (action.united_front_partner == null or action.united_front_partner in removed)
				if both_attackers_removed or _get_attack_defender_card(action) in removed:
					var combat_score := _score_attack_economy(_estimate_attack_economy(action, null, 0, 0))
					var cancel_score := -combat_score - ECON_CARD_VALUE \
						- CardStrategy.mana_penalty(self, CardStrategy.activation_cost(self, card))
					var removed_combatant: Card = action.attacker if both_attackers_removed else _get_attack_defender_card(action)
					if removed_combatant != null and _get_card_loss_owner(removed_combatant) == bot_player:
						# Cancelling a compelled attack (a Foolish Optimism-style
						# forced combat) by destroying our own combatant still
						# costs that creature: the casualty is paid either way,
						# so only the rest of the combat is avoided. Compare
						# complete lines instead of crediting the full combat.
						cancel_score -= CardStrategy.value(self, removed_combatant)
					score = maxi(score, cancel_score)
			score += _follower_safety_gain(danger, {"removed": removed}, bot_player.mana - CardStrategy.activation_cost(self, card) + refund_gain)
			if action.type == CardAction.Type.EVENT:
				score -= _single_creature_removal_discount(card, removed)
				if game_manager.current_player == opponent:
					score += _current_turn_removal_safety(removed)
		elif (card is Dromi or card is Gleipnir) and target != null and score > CardStrategy.BAD \
				and CardStrategy.adds_attack_lock_next_turn(self, target):
			score += _follower_safety_gain(danger, {"disable_attacker": target}, bot_player.mana - CardStrategy.activation_cost(self, card) + refund_gain)
		score -= maxi(CardStrategy.sweeper_hold_value(card), _inferno_hold_charge(card, action))
		# Attack-punishing replies are worth the most against the biggest
		# prospective attacker still to come this turn; charge the
		# hold-for-bigger-fish trade into the fire-now decision.
		if action != null and action.type == CardAction.Type.ATTACK \
				and CardStrategy.combat_visible(self, action) \
				and (card is Smite or card is VoidShield \
					or (card is DivineLightning and target == action.attacker)):
			score -= _attack_punish_hold_charge(card, action)
		if score > int(best["score"]):
			best = {"score": score, "target": target}
	return best

func _score_obsidian_reflection(card: ObsidianReflection, action: CardAction, target: Card) -> int:
	if action.type != CardAction.Type.ATTACK or not CardStrategy.combat_visible(self, action) \
			or game_manager._temporary_combat_follower_damage_reversed or game_manager._is_hex_immune(target, card):
		return CardStrategy.BAD
	var partner := action.united_front_partner
	if partner != null and not CardStrategy.visible(self, partner):
		return CardStrategy.BAD
	var normal := _estimate_projected_attack_economy(action, {})
	var reversed := _estimate_projected_attack_economy(action, {}, true, -1, false, true)
	@warning_ignore("integer_division")
	var hold_value := ECON_CARD_VALUE / 2
	return _score_attack_economy(reversed) - _score_attack_economy(normal) - hold_value \
		- CardStrategy.mana_penalty(self, CardStrategy.activation_cost(self, card))

func _score_e2_abzu_dodge(source: E2Abzu, target: Card, action: CardAction) -> int:
	if source == null or target == null or action == null or action.source_player != opponent:
		return CardStrategy.BAD
	if target not in source.get_priority_field_targets(game_manager, action):
		return CardStrategy.BAD
	if action.type == CardAction.Type.ATTACK:
		if action.target != target:
			return CardStrategy.BAD
		var combat := _estimate_attack_economy(action, null, 0, 0)
		if target not in combat.get("casualties", []):
			return CardStrategy.BAD
	else:
		if not _target_includes_card(action.target, target) and not _target_includes_card(action.event_data, target):
			return CardStrategy.BAD
		if action.card != null and game_manager.is_immune_to_source(target, action.card):
			return CardStrategy.BAD
	return maxi(0, _get_card_economic_value(target) - E2Abzu.VOID_AND_RETURN_COST * _mana_rate())

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
			var priority_target = _score_priority_card(card, top_action, danger).get("target", null)
			var chosen_target: Card = priority_target if priority_target is Card else null
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
	if card is CompelledByTheSecretName:
		# The declaration needs public information to be worth a card; never
		# respond with a blank command.
		var secret_declaration := CardStrategy.best_compelled_secret_declaration(self)
		if secret_declaration.is_empty():
			return false
		return _submit_action({
			"type": "play_charm_response",
			"charm_uid": card.uid,
			"from_hand": card.current_zone == bot_player.hand_zone,
			"target_uid": "",
			"named_card_name": str(secret_declaration["card_name"]),
		})
	if card is CharmCard:
		var charm := card as CharmCard
		var targets: Array[Card] = []
		if charm.targets:
			targets = charm.get_priority_targets(game_manager, top_action)
		var target_uid := _choose_target_uid_for_source(card, targets)
		if CardStrategy.supported(card):
			var priority_target = _score_priority_card(card, top_action, danger).get("target", null)
			var target: Card = priority_target if priority_target is Card else null
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
			var priority_target = _score_priority_card(card, top_action, danger).get("target", null)
			var target: Card = priority_target if priority_target is Card else null
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
	# A ready Mead brew is on this turn's table, so combat lines price
	# against the brewable stock; the lethal submit below brews first when
	# the line's action taxes run past the current stock.
	var mana_budget := bot_player.mana + _ready_brew_mana_gain()
	var attacks := _get_combat_candidates(mana_budget)
	var combat := _plan_combat(attacks, [], null, 0, null, mana_budget)
	var attack := combat
	if bool(combat.get("lethal", false)):
		return _submit_attack_line(combat, true, mana_budget)
	var hermes_plan := _plan_hermes_speed(attacks, combat, mana_budget)
	if bool(hermes_plan.get("lethal", false)):
		# The speed line's activation plus attack taxes may need the brew.
		if _brew_enables_spend(int(hermes_plan.get("mana_required", 0))):
			hermes_plan["brew_setup"] = true
		if _submit_strategy_plan(hermes_plan):
			return true
	var danger := _forecast_incoming_follower_loss()
	var aspect_shift := _plan_aspect_shift(attacks, combat, danger, hermes_plan, mana_budget)
	if bool(aspect_shift.get("lethal", false)) and _submit_strategy_plan(aspect_shift):
		return true
	var shift := _plan_shift(attacks, combat, danger)
	if bool(shift.get("lethal", false)) and _submit_strategy_plan(shift):
		return true
	if game_manager.turn_number > 1:
		var supported := _get_best_supported_attack(_get_attack_ready_creatures(), _get_board_creatures(opponent))
		if int(supported.get("score", 0)) > int(attack.get("score", 0)):
			attack = supported
		var scavenge_attack := _plan_scavenge_against_unknown_stealth()
		if int(scavenge_attack.get("score", 0)) > int(attack.get("score", 0)):
			attack = scavenge_attack
	var manifestation := _plan_god_manifestation(attack, danger)
	if bool(manifestation.get("lethal", false)) and _submit_strategy_plan(manifestation):
		return true
	if _try_activate_mead_for_enki():
		return true
	var summon := _plan_creature_summon(danger, attacks, combat)
	var attack_setup: Dictionary = summon.get("attack_setup", {})
	var removals: Array[Dictionary] = []
	var play := _get_best_strategy_action(attacks, combat, danger, removals)
	var recruit_removal := _plan_summoned_removal_ability(attacks, combat, danger)
	var god_removal := _plan_removal_god_ability(danger, attacks, combat, removals)
	var power_activation := _plan_power_activation(null, danger, combat, attacks, removals)
	var paired_removal := _plan_paired_removals(removals, attacks, combat, danger)
	var deck_ability := _plan_deck_god_ability(danger, attacks, combat, mana_budget)
	var combat_score := int(combat.get("score", 0))
	var setups := [play, god_removal, power_activation, attack_setup, recruit_removal, paired_removal, aspect_shift, deck_ability]
	setups.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return _is_better_strategy_plan(a, b))
	for setup in setups:
		var gain := int(setup.get("score", 0))
		var improves_combat = int(setup.get("combat_score", 0)) > combat_score or setup.get("combined_setup", false)
		var improves_economy := gain > 0 and gain + combat_score >= int(attack.get("score", 0))
		if (setup.get("lethal", false) or (improves_combat and improves_economy and danger < bot_player.followers)) \
				and _submit_strategy_plan(setup):
			return true
	var unlock := _plan_power_unlock(danger, attacks, combat)
	var support := _plan_strategy_support(danger)
	var defenses := [
		play, manifestation, unlock, _plan_defensive_stance(danger), god_removal,
		summon, recruit_removal, paired_removal, deck_ability, power_activation, support, hermes_plan,
		_plan_equipment_pickup(), shift, aspect_shift,
	]
	if danger >= bot_player.followers:
		defenses.append(_plan_defensive_attack(attacks, danger))
		if not attack_setup.is_empty() and attack_setup["command"] != summon["command"]:
			defenses.append(attack_setup)
	defenses.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return int(a.get("score", 0)) > int(b.get("score", 0)))
	for defense in defenses:
		if int(defense.get("score", 0)) >= ECON_CARD_VALUE * 20 and _submit_strategy_plan(defense):
			return true
	if _submit_abt_unlock_before_structure_build(unlock, support, power_activation):
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
	plans.append(_plan_self_deluge(danger))
	plans.append_array(defenses)
	plans.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return int(a.get("score", 0)) > int(b.get("score", 0)))
	var attack_score := int(attack.get("score", 0))
	@warning_ignore("integer_division")
	var setup_threshold := attack_score if attack.get("violent_delights", false) else attack_score / 2
	var delayed: Array[Dictionary] = []
	for plan in plans:
		# A setup that improves the combat line can take priority even if its
		# standalone value is smaller than the attack already available.
		if not attack.is_empty() and int(plan.get("score", 0)) < setup_threshold \
				and int(plan.get("combat_score", 0)) <= attack_score:
			delayed.append(plan)
		elif _submit_strategy_plan(plan):
			return true
	if not delayed.is_empty() and _submit_attack_line(attack, attack == combat, mana_budget):
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
	if _try_improve_creature_position():
		return true
	if _submit_attack_line(attack, attack == combat, mana_budget):
		return true
	if _try_attack():
		return true
	if _try_switch_to_defensive_mode():
		return true
	if danger >= bot_player.followers:
		return _submit_strategy_plan(_plan_odin_draw(danger, true))
	return false

func _is_better_strategy_plan(candidate: Dictionary, current: Dictionary) -> bool:
	var lethal := bool(candidate.get("lethal", false))
	if lethal != bool(current.get("lethal", false)):
		return lethal
	return int(candidate.get("score", 0)) > int(current.get("score", 0))

func _submit_strategy_plan(plan: Dictionary) -> bool:
	if plan.is_empty():
		return false
	if bool(plan.get("brew_setup", false)):
		# The plan's mana only exists after the Mead brew, so submit the brew
		# in its place: the next planning pass replays the same line on the
		# grown stock, and an opponent response that invalidates it cancels
		# the line naturally. Once-per-turn and unlock follow-throughs must
		# not fire on the brew step itself.
		var brew := _brew_setup_plan(plan)
		return not brew.is_empty() and _submit_action(brew["command"])
	if plan.has("mummu_shelve_setup"):
		# A wipe line that destroys own cards worth more shelved than dead
		# runs Entropic Force first: submit the next profitable shelf in the
		# plan's place; the next pass replays the line on the thinned board
		# (the shelved card already left its doom list and its credit).
		var shelf := _next_mummu_wipe_shelve_command(str(plan["mummu_shelve_setup"]))
		if not shelf.is_empty():
			return _submit_action(shelf)
		plan = plan.duplicate()
		plan.erase("mummu_shelve_setup")
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
	if god == null or not god.has_method("can_activate"):
		return false
	# A ready Mead can fund the god's price past the current stock, so the
	# lend check below only relaxes the mana gate inside can_activate.
	var god_check := func() -> bool: return god.can_activate(game_manager)
	if not god_check.call() and not _passes_after_brew(god_check):
		return false

	if god is Freyja:
		var freyja := god as Freyja
		var revived_target := _choose_freyja_resurrection(freyja)
		if revived_target != null:
			return _submit_god_ability_with_brew(freyja, revived_target.uid)
	if god is DellingrTheDayspring:
		var dellingr := god as DellingrTheDayspring
		var reveal_target := _choose_dellingr_reveal_target(dellingr, dellingr.get_valid_targets(game_manager))
		if reveal_target != null:
			var submitted := _submit_god_ability_with_brew(dellingr, reveal_target.uid)
			if submitted:
				_dellingr_revealed_target_uids[reveal_target.uid] = true
			return submitted
	if god is ManannanMacLir:
		# Mists hides every Triskelion creature in stealth. That sets up their
		# Reveal triggers as ambushes and dodges a turn of targeted answers.
		var manannan := god as ManannanMacLir
		var mist_value := 0
		for target in manannan.get_valid_targets(game_manager):
			@warning_ignore("integer_division")
			mist_value += _estimate_reveal_trigger_value(target) / 2
			if target.creature_mode == Card.CreatureMode.AGGRESSIVE and _can_attack_followers_safely(target):
				# Hiding would forfeit this attack.
				@warning_ignore("integer_division")
				mist_value -= _score_follower_loss(opponent, _get_direct_follower_damage(target)) / 2
		var hidden_enemy_answers := 0
		for hand_card in opponent.hand_zone.cards:
			if not CardStrategy.visible(self, hand_card):
				hidden_enemy_answers += 1
		mist_value += mini(hidden_enemy_answers, 4) * 300
		if mist_value - ManannanMacLir.ACTIVATION_COST * _mana_rate() > 800:
			return _submit_god_ability_with_brew(manannan)
	return false

func _choose_freyja_resurrection(freyja: Freyja) -> Card:
	var cost := freyja.get_activation_mana_cost(game_manager)
	var danger := _forecast_incoming_follower_loss()
	var baseline := _plan_combat(_get_combat_candidates())
	var best_target: Card = null
	var best_score := 0
	for target in freyja.get_valid_targets(game_manager):
		var zone := freyja._get_best_summon_zone(target)
		if zone == null:
			continue
		# The creature returns to the graveyard at our next upkeep. Its printed
		# card value is not a permanent gain from this activation.
		var score := _follower_safety_gain(danger, {"summon": target, "zone": zone, "stance": target}, bot_player.mana - cost)
		score += _estimate_temporary_summon_attack_gain(target, zone, cost, int(baseline.get("score", 0)))
		score += _score_effect_summon_sacrifice_followup([target], cost)
		score -= cost * _mana_rate()
		if score > best_score:
			best_target = target
			best_score = score
	return best_target

func _estimate_tablet_attack_gain(tablet: TabletOfLife, target: Card, zone: Zone, setup_cost: int) -> int:
	if game_manager.current_player != bot_player or zone not in bot_player.frontline_zones \
			or game_manager.attack_restrictions.has(bot_player):
		return 0
	var preview := _preview_board_creature(target, zone)
	preview.active_statuses = target.active_statuses.duplicate()
	preview.creature_mode = Card.CreatureMode.AGGRESSIVE
	preview.is_face_down = false
	preview.is_stealth = false
	preview.wake_up()
	tablet._apply_tablet_of_life(preview, game_manager)
	if preview.is_paralyzed() or preview.has_status_effect("cannot_attack"):
		return 0
	return _estimate_temporary_summon_attack_gain(preview, zone, setup_cost, 0)

func _estimate_temporary_summon_attack_gain(target: Card, zone: Zone, activation_cost: int, baseline_score: int) -> int:
	if zone not in bot_player.frontline_zones or game_manager.turn_number <= 1 \
			or game_manager.has_resolved_attack_this_turn or game_manager.attack_restrictions.has(bot_player) \
			or game_manager._any_active_structure_forces_defensive_summon() \
			or game_manager.is_first_turn_attack_blocked_by_weather(target, true):
		return 0
	var attack_cost := game_manager.get_creature_action_mana_cost(target, "attack")
	if activation_cost + attack_cost > bot_player.mana:
		return 0
	var best_score := 0
	for candidate in _get_attack_candidates(target, null, true):
		if _attack_has_remaining_barrier(candidate, []):
			continue
		var outcomes: Array = [candidate["base"]]
		outcomes.append_array(candidate["replies"].values())
		var worst_score := ECON_CARD_VALUE * 20
		for outcome: Dictionary in outcomes:
			if outcome.is_empty():
				worst_score = -ECON_CARD_VALUE * 20
				break
			var score := _score_attack_economy(_account_for_projected_scavenge_lane(outcome, zone))
			if target in outcome.get("casualties", []):
				# A temporary return is already in the graveyard; losing it does
				# not spend another card.
				score += _get_card_economic_value(target)
			worst_score = mini(worst_score, score)
		best_score = maxi(best_score, worst_score - attack_cost * _mana_rate())
	return maxi(0, best_score - baseline_score)

func _choose_dellingr_reveal_target(_source: DellingrTheDayspring, targets: Array) -> Card:
	var best_target: Card = null
	var best_score := -1000000
	for raw_target in targets:
		var target := raw_target as Card
		if target == null or target.get_controller() != opponent:
			continue
		var score := _score_enemy_target(target)
		if _dellingr_revealed_target_uids.has(target.uid):
			# A second reveal only matters when this prepared magical card can
			# answer a strong attack or summon line this turn.
			if not _dellingr_can_interrupt_strong_line(target):
				continue
			score += ECON_CARD_VALUE
		if best_target == null or score > best_score:
			best_target = target
			best_score = score
	return best_target

func _dellingr_can_interrupt_strong_line(target: Card) -> bool:
	if target == null or not target.is_prepared or not target.is_magical_card() \
			or target.is_muted or target.is_activation_locked(game_manager):
		return false
	var activation_cost := game_manager.get_prepared_card_activation_mana_cost(opponent, target)
	if opponent.mana < activation_cost:
		return false
	var attacks := _get_combat_candidates()
	var attack := _plan_combat(attacks)
	if int(attack.get("score", 0)) >= ECON_CARD_VALUE:
		var action := CardAction.new()
		action.type = CardAction.Type.ATTACK
		action.attacker = attack.get("attacker") as Card
		action.target = attack.get("target")
		if _dellingr_card_can_answer_action(target, action):
			return true
	var summon := _plan_creature_summon(_forecast_incoming_follower_loss(), attacks, attack)
	if int(summon.get("score", 0)) < ECON_CARD_VALUE:
		return false
	var command: Dictionary = summon.get("command", {})
	var creature := game_manager.get_card_by_uid(str(command.get("card_uid", command.get("lupine_uid", ""))))
	if creature == null:
		return false
	for event_name in ["summon", "frontline_entry"]:
		var action := CardAction.new()
		action.type = CardAction.Type.EVENT
		action.source_player = bot_player
		action.card = creature
		action.event_name = event_name
		if _dellingr_card_can_answer_action(target, action):
			return true
	return false

func _dellingr_card_can_answer_action(card: Card, action: CardAction) -> bool:
	if card == null or action == null:
		return false
	if card.has_method("can_respond_to_action") and bool(card.call("can_respond_to_action", action)):
		return true
	return action.event_name == "frontline_entry" \
		and card.has_method("can_respond_to_frontline_entry") \
		and bool(card.call("can_respond_to_frontline_entry", action))

func _plan_hermes_speed(attacks: Array[Dictionary], baseline: Dictionary, projected_mana: int = -1) -> Dictionary:
	if attacks.is_empty() or bool(baseline.get("lethal", false)):
		return {}
	var god := _find_player_god()
	var mana_budget := bot_player.mana if projected_mana < 0 else projected_mana
	if god is HermesPsychopompus:
		return _plan_wings_of_the_departed(god, attacks, baseline, mana_budget) if god.can_use_god_power(game_manager) else {}
	var hermes := god as Hermes
	if hermes == null:
		return {}
	var can_activate := hermes.can_activate(game_manager) if projected_mana < 0 \
		else hermes.can_plan_activation_after_upkeep(game_manager, projected_mana)
	return _plan_deceptive_speed(hermes, attacks, baseline, mana_budget) if can_activate else {}

func _plan_deceptive_speed(hermes: Hermes, attacks: Array[Dictionary], baseline: Dictionary, mana_budget: int, setup_cost: int = 0) -> Dictionary:
	var best := {}
	var cost := setup_cost + Hermes.ACTIVATION_COST
	if cost > mana_budget or hermes._was_used_this_turn(game_manager):
		return best
	var penalty := CardStrategy.mana_penalty(self, cost, mana_budget)
	var baseline_score := int(baseline.get("score", 0))
	for target in hermes.get_valid_targets(game_manager):
		if target.get_controller() != bot_player or target.negates_external_effects() \
				or target.get_effective_speed(Hermes.SPEED_BONUS) == target.get_effective_speed() \
				or game_manager.is_immune_to_source(target, hermes) or game_manager.is_guardian_protected(target, hermes):
			continue
		var projected := _project_speed_boost_attacks(attacks, target, Hermes.SPEED_BONUS)
		if projected.is_empty():
			continue
		var line := _plan_combat(projected, [], null, cost, null, mana_budget)
		var combat_score := int(line.get("score", 0))
		var score := combat_score - baseline_score - penalty
		var lethal := bool(line.get("lethal", false))
		var mana_left := int(line.get("mana", mana_budget - cost))
		var plan := {"score": score, "combat_score": combat_score, "lethal": lethal,
			"mana": mana_left, "mana_required": int(line.get("mana_required", cost)),
			"brew_setup": _brew_enables_spend(int(line.get("mana_required", cost))), "command": {
				"type": "god_ability", "god_uid": hermes.uid, "target_uid": target.uid,
			}}
		if _is_better_strategy_plan(plan, best):
			best = plan
	return best

func _project_speed_boost_attacks(attacks: Array[Dictionary], target: Card, speed_bonus: int) -> Array[Dictionary]:
	var projected: Array[Dictionary] = []
	var updated: Array[Card] = []
	for attack in attacks:
		var attacker: Card = attack["attacker"]
		var partner: Card = attack["partner"]
		if target != attacker and target != partner:
			projected.append(attack)
		elif attacker not in updated:
			updated.append(attacker)
			projected.append_array(_get_attack_candidates(attacker, partner, false, target, speed_bonus))
	if updated.is_empty():
		projected.clear()
	return projected

func _plan_wings_of_the_departed(god: HermesPsychopompus, attacks: Array[Dictionary], baseline: Dictionary, mana_budget: int, setup_cost: int = 0) -> Dictionary:
	var best := {}
	if attacks.is_empty() or mana_budget <= setup_cost:
		return best
	var max_payment := god.get_max_speed_payment(mana_budget - setup_cost)
	if max_payment <= 0:
		return best
	var baseline_score := int(baseline.get("score", 0))
	for target in god.get_speed_targets(game_manager):
		if target.get_controller() != bot_player or target.negates_external_effects() \
				or game_manager.is_guardian_protected(target, god) \
				or not attacks.any(func(attack: Dictionary) -> bool: return target in [attack["attacker"], attack["partner"]]):
			continue
		var previous_speed := target.get_effective_speed()
		for payment in range(1, max_payment + 1):
			var speed_with_bonus := target.get_effective_speed(payment)
			if speed_with_bonus == previous_speed:
				continue
			previous_speed = speed_with_bonus
			var projected := _project_speed_boost_attacks(attacks, target, payment)
			var cost := setup_cost + payment
			var line := _plan_combat(projected, [], null, cost, null, mana_budget)
			var combat_score := int(line.get("score", 0))
			var score := combat_score - baseline_score - CardStrategy.mana_penalty(self, cost, mana_budget)
			var mana_left := int(line.get("mana", mana_budget - cost))
			var plan := {
				"score": score, "combat_score": combat_score, "lethal": bool(line.get("lethal", false)),
				"mana": mana_left, "mana_required": int(line.get("mana_required", cost)),
				"brew_setup": _brew_enables_spend(int(line.get("mana_required", cost))),
				"command": {"type": "god_ability", "god_uid": god.uid, "target_uid": target.uid,
					"ability": HermesPsychopompus.WINGS_OF_THE_DEPARTED, "mana_amount": payment},
			}
			if _is_better_strategy_plan(plan, best):
				best = plan
	return best

func _plan_aspect_shift(attacks: Array[Dictionary], combat: Dictionary, danger: int, current_speed_plan: Dictionary, mana_budget: int) -> Dictionary:
	var best := {}
	var god := _find_player_god()
	if god == null or not god.can_use_god_power(game_manager) or bool(combat.get("lethal", false)):
		return best
	for card in _get_player_powers():
		var power := card as AspectShift
		if power == null:
			continue
		var unlocking := power.is_face_down
		var can_shift := func() -> bool:
			return power.can_unlock(game_manager) if unlocking else power.can_activate(game_manager)
		if not can_shift.call() and not _passes_after_brew(can_shift):
			continue
		var shift_cost := power.get_unlock_mana_cost(game_manager) if unlocking \
			else power.get_activation_mana_cost(AspectShift.SHIFT_COST, game_manager)
		if shift_cost > mana_budget:
			continue
		if god is AphroditeAreia or god is AphroditeSkotia:
			var aphrodite_plan := _plan_aphrodite_aspect_shift(power, god, combat, danger, mana_budget, shift_cost)
			if _is_better_strategy_plan(aphrodite_plan, best):
				best = aphrodite_plan
			continue
		var current_plan := current_speed_plan
		var alternate_plan: Dictionary
		if unlocking:
			var hades_aspect := power.make_hades_aspect() as HermesPsychopompus
			if hades_aspect == null:
				continue
			alternate_plan = _plan_call_of_the_crossing(hades_aspect, danger, attacks, combat, mana_budget, shift_cost)
			var wings := _plan_wings_of_the_departed(hades_aspect, attacks, combat, mana_budget, shift_cost)
			if _is_better_strategy_plan(wings, alternate_plan):
				alternate_plan = wings
		else:
			var normal_aspect := power.get_normal_aspect() as Hermes
			if normal_aspect == null:
				continue
			alternate_plan = _plan_deceptive_speed(normal_aspect, attacks, combat, mana_budget, shift_cost)
			if alternate_plan.is_empty():
				continue
			var summon := _plan_call_of_the_crossing(god as HermesPsychopompus, danger, attacks, combat, mana_budget)
			if _is_better_strategy_plan(summon, current_plan):
				current_plan = summon
		if alternate_plan.is_empty() or bool(current_plan.get("lethal", false)) \
				or not _is_better_strategy_plan(alternate_plan, current_plan):
			continue
		# Submit only the shift. After it resolves, replan from the new board.
		alternate_plan["command"] = {
			"type": "unlock_power" if unlocking else "activate_power", "power_uid": power.uid,
		}
		if _is_better_strategy_plan(alternate_plan, best):
			best = alternate_plan
	return best

func _plan_aphrodite_aspect_shift(power: AspectShift, god: GodCard, combat: Dictionary, danger: int, mana_budget: int, shift_cost: int) -> Dictionary:
	var unlocking := power.is_face_down
	if unlocking and not _get_board_creatures(bot_player).any(func(card: Card) -> bool: return card.is_stealth):
		return {}
	var alternate := power.make_hades_aspect() if unlocking else power.get_normal_aspect()
	if alternate == null:
		return {}
	var mana_left := mana_budget - shift_cost
	var current_capture := _available_violent_delights_value(god as AphroditeAreia, mana_budget, danger)
	var god_zone := bot_player.god_zone
	# Forecast both forms through the live combat rules without emitting a move.
	var previous_zone := alternate.current_zone
	var previous_owner := alternate.card_owner
	alternate.card_owner = bot_player
	alternate.current_zone = god_zone
	god_zone.cards[0] = alternate
	var projected_attacks := _get_combat_candidates(mana_left)
	var projected_combat := _plan_combat(projected_attacks, [], null, shift_cost, null, mana_budget)
	var safety := _follower_safety_gain(danger, {}, mana_left)
	var projected_capture := _available_violent_delights_value(alternate as AphroditeAreia, mana_left, danger, safety)
	god_zone.cards[0] = god
	alternate.current_zone = previous_zone
	alternate.card_owner = previous_owner
	var combat_score := int(projected_combat.get("score", 0))
	var score := combat_score - int(combat.get("score", 0)) + safety + projected_capture - current_capture \
		- CardStrategy.mana_penalty(self, shift_cost, mana_budget)
	return {
		"score": score, "combat_score": combat_score, "lethal": projected_combat.get("lethal", false),
		"brew_setup": _brew_enables_spend(shift_cost + (AphroditeAreia.ACTIVATION_COST if projected_capture > 0 else 0)) \
			or (projected_combat.get("lethal", false) and mana_budget > bot_player.mana),
		"combined_setup": projected_capture > current_capture,
		"command": {"type": "unlock_power" if unlocking else "activate_power", "power_uid": power.uid},
	}

func _available_violent_delights_value(god: AphroditeAreia, mana_budget: int, danger: int, safety_without_capture: int = 0) -> int:
	if god == null or mana_budget < AphroditeAreia.ACTIVATION_COST \
			or not game_manager.player_destroyed_creature_by_combat_this_turn(bot_player):
		return 0
	var best := 0
	for target in god.get_valid_enslave_targets(game_manager):
		if not CardStrategy.visible(self, target) \
				or not game_manager.get_turn_destruction_ward_activation_block_reason(god, target).is_empty():
			continue
		var removed := CardStrategy.removal_targets(self, god, target)
		if removed.is_empty():
			continue
		# A captured threat is gone by the opponent's turn, even if the shift exposed us to it.
		var capture_safety := _follower_safety_gain(danger, {"removed": removed}, mana_budget - AphroditeAreia.ACTIVATION_COST)
		best = maxi(best, _violent_delights_target_value(target) + capture_safety - safety_without_capture \
			- CardStrategy.mana_penalty(self, AphroditeAreia.ACTIVATION_COST, mana_budget))
	return best

func _plan_shift(attacks: Array[Dictionary], baseline: Dictionary, danger: int) -> Dictionary:
	var best := {}
	var baseline_score := int(baseline.get("score", 0))
	var mana_gain := _tonal_mastery_mana(bot_player)
	var mastery_value := _tonal_mastery_shift_value(bot_player, mana_gain) \
		- _tonal_mastery_shift_value(opponent, _tonal_mastery_mana(opponent))
	for card in _get_board_creatures(bot_player):
		if not card.has_method("shift_forms") or not card.can_activate(game_manager) \
				or card.is_activation_locked(game_manager) \
				or not game_manager.get_creature_ability_activation_block_reason(card).is_empty():
			continue
		var tax := game_manager.get_creature_action_mana_cost(card, "activate")
		if tax > bot_player.mana:
			continue
		var form := _preview_shifted_form(card)
		var stats := _shift_stat_changes(card, form)
		var spends_major := not card is ErlqueensNightingale and card.can_take_minor_creature_action_spending_major()
		var budget := bot_player.mana - tax + mana_gain
		var projected: Array[Dictionary] = []
		var rebuilt: Array[Card] = []
		var candidates := attacks if mana_gain <= tax else _get_combat_candidates(budget)
		for candidate in candidates:
			var attacker: Card = candidate["attacker"]
			var partner: Card = candidate["partner"]
			if card not in [attacker, partner]:
				projected.append(candidate)
			elif not spends_major and attacker not in rebuilt:
				rebuilt.append(attacker)
				projected.append_array(_get_attack_candidates(attacker, partner, false, card, 0, form))
		var combat := _plan_combat(projected, [], null, 0, null, budget)
		var combat_score := int(combat.get("score", 0))
		var lethal := bool(combat.get("lethal", false))
		var safety := _follower_safety_gain(danger, {"shifting": card, "shifted_form": form}, budget)
		var creature_safety := _estimate_targeted_casualty_cost(card, card, {}) \
			- _estimate_targeted_casualty_cost(card, form, {card: stats})
		# Favor stronger aggressive forms and sturdier defensive forms when
		# neither side has an immediate combat line that distinguishes them.
		var defensive := card.creature_mode == Card.CreatureMode.DEFENSIVE
		var form_value := stats.x * (20 if defensive else 55) + stats.y * (55 if defensive else 15) + stats.z * 250
		var score := combat_score - baseline_score + safety + creature_safety + form_value + mastery_value \
			- CardStrategy.mana_penalty(self, tax)
		# Leave the minor action available to advance a reserve attacker this turn.
		if not card is ErlqueensNightingale and card.current_zone in bot_player.reserve_zones \
				and card.creature_mode == Card.CreatureMode.AGGRESSIVE and card.can_take_major_creature_action() \
				and not card.has_status_effect("cannot_move") and not card.has_status_effect("cannot_attack") \
				and game_manager.turn_number > 1 and not card.summoned_after_first_attack_this_turn \
				and not game_manager.attack_restrictions.has(bot_player) \
				and bot_player.get_adjacent_zones(card.current_zone).any(func(zone: Zone) -> bool:
					return zone in bot_player.frontline_zones and zone.cards.is_empty()):
			score -= _mana_rate()
		if (lethal and not bool(best.get("lethal", false))) \
				or (lethal == bool(best.get("lethal", false)) and score > int(best.get("score", 0))):
			var command := {"type": "activate_card_ability", "source_uid": card.uid}
			if card is TheWhiteSerpent:
				command["option"] = {"ability": "shift"}
			best = {"command": command, "score": score, "combat_score": combat_score, "lethal": lethal}
	return best

func _preview_shifted_form(card: Card) -> Card:
	# Shift a detached copy so forecasting can use the card's own form rules.
	var form := _preview_board_creature(card, card.current_zone)
	form.shift_forms()
	return form

func _preview_board_creature(card: Card, zone: Zone) -> Card:
	var form := card.duplicate() as Card
	form.apply_serialized_state(card.get_serialized_state())
	form.card_owner = card.card_owner
	form.current_zone = zone
	form.creature_mode = card.creature_mode
	form.equipment = card.equipment
	form.active_buffs = card.active_buffs
	form.active_statuses = card.active_statuses
	form.is_stealth = card.is_stealth
	form.is_face_down = card.is_face_down
	form.incorporeal = card.incorporeal
	return form

func _preview_summoned_creature(card: Card, zone: Zone, stealth: bool) -> Card:
	var form := _preview_board_creature(card, zone)
	form.is_stealth = stealth
	form.is_face_down = stealth
	return form

func _shift_stat_changes(card: Card, form: Card) -> Vector3i:
	return Vector3i(form.get_effective_strength() - card.get_effective_strength(),
		form.get_effective_resilience() - card.get_effective_resilience(),
		form.get_effective_speed() - card.get_effective_speed())

func _estimate_targeted_casualty_cost(card: Card, form: Card, stats: Dictionary, projected_mode: int = -1) -> int:
	var worst_loss := 0
	for attacker in _get_creature_attackers_next_turn(form, []):
		var action := CardAction.new()
		action.type = CardAction.Type.ATTACK
		action.source_player = opponent
		action.attacker = attacker
		action.target = card
		var result := _estimate_raw_attack_economy(action, stats, projected_mode)
		if card not in result["casualties"]:
			continue
		var loss := int(result["bot_cards_lost"]) - int(result["opponent_cards_lost"])
		for interceptor in match_manager._get_possible_interceptors(attacker, form):
			if interceptor == card or _status_persists_to_next_turn(interceptor, "cannot_intercept"):
				continue
			action.interceptor = interceptor
			var reply := _estimate_raw_attack_economy(action, stats)
			loss = mini(loss, int(reply["bot_cards_lost"]) - int(reply["opponent_cards_lost"]))
		worst_loss = maxi(worst_loss, loss)
	var target := form
	if projected_mode >= 0 and projected_mode != int(form.creature_mode):
		target = _preview_board_creature(form, form.current_zone)
		target.creature_mode = projected_mode as Card.CreatureMode
	if target != card:
		target.uid = card.uid
	var target_stats := stats.duplicate()
	# The shifted form already contains its new stats.
	target_stats.erase(card)
	return maxi(worst_loss, _estimate_champions_call_loss(target, [], target_stats))

func _stance_casualty_savings(creature: Card, mode: Card.CreatureMode) -> int:
	return _estimate_targeted_casualty_cost(creature, creature, {}) \
		- _estimate_targeted_casualty_cost(creature, creature, {}, mode)

# Mirror of the casualty skip in _add_combat_casualty: true when this
# attacker's combat destruction cannot actually take the creature off the
# board (Stone Skin's self replacement, a combat ward, or a destruction
# guard).
func _survives_combat_destruction_by(attacker: Card, creature: Card) -> bool:
	if CardStrategy.destruction_guard(creature) or game_manager.is_warded_from_combat_destruction(creature, attacker):
		return true
	if attacker.can_destroy_combat_protected_creatures(creature):
		return false
	var replacement: Zone = creature.get_self_graveyard_replacement_zone(game_manager, true, true, false) if creature is BaseCard else null
	return replacement != null and replacement == creature.current_zone

# A creature the visible enemy cannot remove from combat but can beat in an
# aggressive fight is a repeatable follower farm while it stays aggressive:
# every winning attack transfers followers before the kill, and a body that
# cannot be Slain survives to be farmed again next turn (Stone Skin is the
# canonical case). Defensive stance closes the leak outright - a defensive
# body whose destruction is prevented transfers no followers - and still
# collects failed-attack conversions, so sitting in attack mode is pure
# donation.
func _is_combat_farm_bait(creature: Card, attackers: Array[Card]) -> bool:
	if attackers.is_empty():
		return false
	var beaten := false
	for attacker in attackers:
		if not _survives_combat_destruction_by(attacker, creature):
			return false
		if _get_vision_adjusted_strength(attacker, 0, creature) > _get_vision_adjusted_strength(creature, 0, attacker):
			beaten = true
	return beaten

# Follower-safety value of flipping a farm bait to defensive. The farm
# recurs every turn the unkillable body stays aggressive, so one forecast
# turn alone underprices the leak; count it twice against the one-time
# stance tempo tax.
func _combat_farm_bait_savings(creature: Card) -> int:
	var gain := _follower_safety_gain(_forecast_incoming_follower_loss(), {"stance": creature, "defensive": true},
		bot_player.mana - game_manager.get_creature_action_mana_cost(creature, "change stance"))
	return gain * 2 if gain > 0 else 0

# Estimated casualty risk of a defensive -> aggressive stance switch from
# enemy creatures that are not on the board yet: a summon or reserve advance
# next turn whose STR would clear this creature in aggressive stance (STR vs
# STR) but bounce off its defensive RES (STR vs RES). Switching a high-RES
# defender to aggressive to poke followers silently accepts that answer, so
# the exposure has to be priced into the switch, not only the risk from
# attackers already visible on the board.
func _forecast_aggressive_exposure_risk(creature: Card) -> int:
	if creature == null or opponent == null or game_manager == null \
			or not CardStrategy.visible(self, creature) \
			or game_manager.attack_restrictions.has(opponent):
		return 0
	var strength := creature.get_effective_strength()
	var resilience := creature.get_effective_resilience()
	# The (STR, RES] window below assumes stronger attackers clear the body
	# in either stance. A body no visible attacker can remove from combat
	# breaks that assumption: while it stays aggressive, every stronger
	# visible enemy attacks it turn after turn and keeps the STR surplus as
	# followers (Stone Skin is the canonical case). The stance choice is
	# exactly what keeps that farm open, so charge it directly.
	var farm_exposure := 0
	for attacker in _get_creature_attackers_next_turn(creature, []):
		if not _survives_combat_destruction_by(attacker, creature):
			continue
		farm_exposure = maxi(farm_exposure, _get_vision_adjusted_strength(attacker, 0, creature) - strength)
	if farm_exposure > 0:
		return _score_follower_loss(bot_player, farm_exposure)
	# Only attackers inside the (STR, RES] window are exposure added by the
	# switch: stronger ones clear the creature even in defensive stance, so
	# the stance choice is not what costs it.
	if strength >= resilience or CardStrategy.open_spaces(opponent) <= 0:
		return 0
	var budget := opponent.mana + game_manager.get_automatic_upkeep_mana_gain(opponent, game_manager.turn_number + 1) \
		+ game_manager.get_effective_upkeep_mana_gain(game_manager.get_base_upkeep_mana_gain(), opponent)
	if budget <= 0:
		return 0
	var threat_strength := mini(resilience, budget * ECON_FORECAST_SUMMON_STR_PER_MANA)
	for card in opponent.hand_zone.cards:
		if not CardStrategy.visible(self, card) or not card is CreatureCard or card is ActiveGodCard:
			continue
		if game_manager.get_creature_summon_mana_cost(opponent, card) > budget:
			continue
		threat_strength = maxi(threat_strength, mini(resilience, card.get_effective_strength()))
	if threat_strength <= strength:
		return 0
	var loss := _get_card_economic_value(creature)
	if not creature.is_token:
		@warning_ignore("integer_division")
		loss += (maxi(0, creature.mana_cost) + 2 * creature.sacrifice_cost) * _mana_rate() / 2
	loss += _score_follower_loss(bot_player, threat_strength - strength)
	# The opponent still has to hold the answer, pay for it, and choose this
	# line, so the exposure is charged at half weight. Each ready protective
	# reply (Smite / Void Shield) halves it again: when a clear attempt eats
	# a banked answer the body survives and the reply trades for their
	# attacker, so the loss stops being one-sided. Two or more replies cover
	# an extra clear attempt each.
	@warning_ignore("integer_division")
	return ((loss + 1) / 2) >> mini(_get_own_protective_responses().size(), 3)

# Mirror of _get_known_attack_response_cards for this side's own protection:
# banked face-down responses in owned zones plus affordable hand copies (the
# hand is private to this bot and persists unspent mana into the reply
# window). Only the two replies that remove the ATTACKER count here - The
# Inferno would hit this side's own board too, so it protects nobody.
func _get_own_protective_responses() -> Array[Card]:
	var responses: Array[Card] = []
	if bot_player == null or game_manager == null:
		return responses
	for zone in bot_player.frontline_zones + bot_player.reserve_zones:
		for card in zone.cards:
			if card is Smite or card is VoidShield:
				responses.append(card)
	for card in bot_player.hand_zone.cards:
		if (card is Smite or card is VoidShield) \
				and bot_player.mana >= game_manager.get_card_play_mana_cost(bot_player, card, false):
			responses.append(card)
	return responses

# Attack-punishing replies (Smite / Void Shield / Divine Lightning) pay the
# most against the largest prospective attacker, not the first one to
# declare. While more ready enemies can still attack this turn, passing keeps
# the reply banked for the bigger attack at the price of letting this one
# resolve, so the fire-now score carries that trade: a small attacker can no
# longer bait the reply out of the bot. A second copy of the same reply makes
# holding free — fire one now, keep the other for the bigger fish.
func _attack_punish_hold_charge(card: Card, action: CardAction) -> int:
	if action == null or action.type != CardAction.Type.ATTACK or action.attacker == null \
			or game_manager == null or opponent == null or bot_player == null \
			or game_manager.current_player != opponent or not CardStrategy.combat_visible(self, action):
		return 0
	var bullets := 0
	for zone in bot_player.frontline_zones + bot_player.reserve_zones:
		for held in zone.cards:
			if held.get_script() == card.get_script():
				bullets += 1
	for held in bot_player.hand_zone.cards:
		if held.get_script() == card.get_script() \
				and bot_player.mana >= game_manager.get_card_play_mana_cost(bot_player, held, false):
			bullets += 1
	if bullets > 1:
		return 0
	# Economy of letting this attack resolve: the price the hold option pays.
	var combat := _score_attack_economy(_estimate_attack_economy(action, null, 0, 0))
	var remaining := opponent.mana - game_manager.get_creature_action_mana_cost(action.attacker, "attack")
	var destroys := not (card is VoidShield)
	var best_future := 0
	for attacker in _get_board_creatures(opponent):
		if _has_committed_attack(attacker) or not _can_attack_after_priority(attacker) \
				or attacker.current_zone not in opponent.frontline_zones \
				or not CardStrategy.visible(self, attacker) \
				or attacker.creature_mode != Card.CreatureMode.AGGRESSIVE \
				or game_manager.get_creature_action_mana_cost(attacker, "attack") > remaining \
				or not CardStrategy.can_remove_from_board(self, card, attacker, destroys):
			continue
		# The opponent picks the target, so price the reply against their best
		# (worst-for-us) engagement among our reachable defenders.
		var worst := 1 << 30
		for defender in _get_board_creatures(bot_player):
			if not game_manager.can_cards_engage_each_other(attacker, defender):
				continue
			var probe := CardAction.new()
			probe.type = CardAction.Type.ATTACK
			probe.source_player = opponent
			probe.attacker = attacker
			probe.target = defender
			if not game_manager.can_card_respond_to_action(card, probe, bot_player):
				continue
			worst = mini(worst, _score_attack_economy(_estimate_attack_economy(probe, null, 0, 0)))
		if worst >= (1 << 30):
			continue
		best_future = maxi(best_future, CardStrategy.value(self, attacker) - worst)
	if best_future <= 0:
		return 0
	# The bigger attack is still the opponent's choice, and a declined attack
	# leaves the reply banked anyway, so discount the future payoff by half.
	@warning_ignore("integer_division")
	return maxi(combat + best_future / 2, 0)

# The Inferno re-fires on every future enemy attack, and its payoff grows
# with the attacker's frontline, so a lone mediocre attacker must not bait it
# out while the follower pool is healthy: the follower damage the kill
# cancels is cheap at high totals, and the enemy frontline can only grow over
# the coming turns. The charge gives back the health-blind share of the
# avoided-follower-damage credit the generic response score paid (the same
# urgency clamp _current_turn_removal_safety uses), then prices the prospect
# of a later, bigger trigger: visible reserve bodies at half value (advancing
# costs a turn), hidden bodies at the generic card price, and one expected
# future deployment while the opponent can still field creatures. Both terms
# scale down as the pool empties, so a threatened board still fires the wipe
# to survive; a loaded frontline fires anyway, because the fire-now gain is
# the whole frontline at once.
func _inferno_hold_charge(card: Card, action: CardAction) -> int:
	if not (card is TheInferno) or action == null or action.type != CardAction.Type.ATTACK \
			or game_manager == null or opponent == null or bot_player == null \
			or game_manager.current_player != opponent or not CardStrategy.combat_visible(self, action):
		return 0
	var before := _forecast_incoming_follower_loss({}, true)
	var urgency := clampf(1.0 - float(bot_player.followers - before) / 100.0, 0.25, 1.0)
	var hold_weight := clampf(1.0 - urgency, 0.0, 1.0)
	if hold_weight <= 0.0:
		return 0
	# The follower-loss share of the avoided combat, isolated so a saved
	# defender keeps full credit while the cheap-at-full-pool damage share is
	# priced at what the health clamp says it is worth.
	var attack_economy := _estimate_attack_economy(action, null, 0, 0)
	var bot_after := maxi(0, bot_player.followers - (int(attack_economy.get("bot_followers_lost", 0)) - int(attack_economy.get("bot_followers_gained", 0))))
	var follower_credit := maxi(0, -CardStrategy.follower_change_value(bot_player.followers, bot_after))
	var charge := roundi(float(follower_credit) * hold_weight)
	# Prospect of a later, bigger trigger. The opponent still chooses whether
	# to load the frontline, so the prospect is taken at half.
	var prospect := 0
	for creature in _get_board_creatures(opponent):
		if creature.current_zone == null or creature.current_zone not in opponent.reserve_zones:
			continue
		if CardStrategy.visible(self, creature):
			prospect += int(float(CardStrategy.value(self, creature)) * 0.5)
		else:
			prospect += CardStrategy.CARD_VALUE / 4
	if not opponent.deck_zone.cards.is_empty() or not opponent.hand_zone.cards.is_empty():
		prospect += CardStrategy.CARD_VALUE / 2
	charge += int(float(prospect) * hold_weight * 0.5)
	return charge

func _get_tonal_mastery_god(player: Player) -> TezcatlipocaTheSmokingMirror:
	if player == null or player.god_zone.cards.is_empty() \
			or not game_manager.can_player_use_powers(player) or not game_manager.can_player_gain_mana_now(player):
		return null
	var god := player.god_zone.cards[0] as TezcatlipocaTheSmokingMirror
	return god if god != null and not god.is_muted else null

func _tonal_mastery_mana(player: Player) -> int:
	var god := _get_tonal_mastery_god(player)
	if god != null and god.get_tonal_mastery_token_count() + 1 >= TezcatlipocaTheSmokingMirror.TONAL_MASTERY_TOKEN_THRESHOLD:
		return TezcatlipocaTheSmokingMirror.TONAL_MASTERY_MANA_GAIN
	return 0

func _tonal_mastery_shift_value(player: Player, immediate_mana: int) -> int:
	if immediate_mana > 0:
		return CardStrategy.mana_gain_value(self, immediate_mana)
	return 750 if _get_tonal_mastery_god(player) != null else 0

# ── Tonal Extraction planning ────────────────────────────────────────────────
# Extraction is a two-stage line: keep a Shapeshifter alive, bank mana, then
# unlock the power and copy its alternate form into a Spirit. These helpers
# credit the setup stage so the bot does not spend the target slot or the mana
# on plays that never follow through.

var _tonal_setup_cache := {}

func _find_face_down_tonal_extraction() -> TonalExtraction:
	if _tonal_setup_cache.has("power"):
		return _tonal_setup_cache["power"] as TonalExtraction
	var found: TonalExtraction = null
	for power in _get_player_powers():
		if power is TonalExtraction and power.is_face_down and not power.is_muted:
			found = power
			break
	_tonal_setup_cache["power"] = found
	return found

# Mirrors TonalExtraction target legality for cards not yet on the field.
func _is_tonal_extraction_target(creature: Card) -> bool:
	return creature != null and not creature.is_god \
		and creature.has_type("Shapeshifter") and not creature.is_shapeshift_locked() \
		and creature.has_method("get_tonal_extraction_spirit_profile")

func _tonal_spirit_preview(creature: Card) -> TonalExtractionSpiritToken:
	if creature == null or not creature.has_method("get_tonal_extraction_spirit_profile"):
		return null
	var profile: Dictionary = creature.get_tonal_extraction_spirit_profile()
	if profile.is_empty():
		return null
	var spirit := TonalExtractionSpiritToken.new()
	spirit.configure_from_profile(profile)
	spirit.card_owner = bot_player
	return spirit

func _get_tonal_board_target_count() -> int:
	if _tonal_setup_cache.has("board_targets"):
		return int(_tonal_setup_cache["board_targets"])
	var count := 0
	for card in game_manager.get_field_cards(bot_player):
		if _is_tonal_extraction_target(card):
			count += 1
	_tonal_setup_cache["board_targets"] = count
	return count

# Future option value of deploying this creature as an extraction setup: a
# face-down power can unlock later, lock this Shapeshifter, and summon a
# Spirit with its alternate form's stats. Crediting part of that line at
# summon time makes a similar-stat Shapeshifter beat an unrelated body while
# the power is still face-down, instead of spending the target slot on a
# strong play the bot never follows up on.
func _estimate_tonal_extraction_setup_bonus(creature: Card) -> int:
	var power := _find_face_down_tonal_extraction()
	if power == null or not _is_tonal_extraction_target(creature):
		return 0
	var spirit := _tonal_spirit_preview(creature)
	if spirit == null:
		return 0
	var gain := CardStrategy.value(self, spirit) + (spirit.get_effective_speed() - 1) * 400
	var cost := power.get_unlock_mana_cost(game_manager) \
		+ game_manager.get_creature_summon_mana_cost(bot_player, spirit, power, true)
	# The unlock is a later-turn spend, so charge banked mana at half rate.
	@warning_ignore("integer_division")
	gain -= cost * _mana_rate() / 2
	# Extraction locks this creature's shift ability, and a Tonal Mastery line
	# loses more when the shift options are gone.
	gain -= 1500 if _get_tonal_mastery_god(bot_player) != null else 500
	if gain <= 0:
		return 0
	# Discount the whole future line: mana still has to be saved and paid.
	@warning_ignore("integer_division")
	gain = gain * 55 / 100
	# The power summons one Spirit at a time; an eligible body already on the
	# field makes this deployment a redundant target.
	if _get_tonal_board_target_count() > 0:
		gain /= 2
	return mini(2000, gain)

# Taking upkeep mana can flip a Tonal Extraction line from unaffordable to
# playable this same turn: unlocking against a Shapeshifter already on the
# field, or summoning one from hand first and extracting it before combat.
func _upkeep_mana_enables_tonal_extraction(mana_gain: int) -> bool:
	if mana_gain <= 0 or game_manager == null:
		return false
	var power := _find_face_down_tonal_extraction()
	if power == null or power.is_activation_locked(game_manager) \
			or not game_manager.can_player_use_powers(bot_player):
		return false
	# The brew is available under either upkeep choice, so the mana income
	# only counts when the line needs more than the brew already funds.
	var brew := _ready_brew_mana_gain()
	var reach := bot_player.mana + mana_gain + brew
	for target in power.get_valid_targets(game_manager):
		var spirit := _tonal_spirit_preview(target)
		if spirit == null:
			continue
		var cost := power.get_unlock_mana_cost(game_manager) \
			+ game_manager.get_creature_summon_mana_cost(bot_player, spirit, power, true)
		if cost > bot_player.mana + brew and cost <= reach:
			return true
	if bot_player.has_summoned_this_turn or _get_first_open_summon_zone(bot_player) == null \
			or power.get_open_summon_zone() == null:
		return false
	for card in bot_player.hand_zone.cards:
		if not _is_tonal_extraction_target(card):
			continue
		var spirit := _tonal_spirit_preview(card)
		if spirit == null:
			continue
		var line_cost := _get_play_cost(card, false) + power.get_unlock_mana_cost(game_manager) \
			+ game_manager.get_creature_summon_mana_cost(bot_player, spirit, power, true)
		if line_cost > bot_player.mana + brew and line_cost <= reach:
			return true
	return false

# The held Altar of Dreams line keeps a funding level the bot wants on hand
# (its remaining unlock plus the coster's summon price plus the sleep
# activation tax) so its sleep source's next opportunity can be taken the
# turn it appears; the mana option wins when its income is what still closes
# that gap.
func _upkeep_mana_enables_altar_line(mana_gain: int) -> bool:
	if mana_gain <= 0 or game_manager == null:
		return false
	var line := CardStrategy.held_altar_line(self)
	if not bool(line.get("live", false)):
		return false
	var gross := int(line.get("gross", 0))
	if gross <= 0:
		return false
	# The brew is available under either upkeep choice, so the income only
	# counts when the line needs more than the brew already funds.
	var brew := _ready_brew_mana_gain()
	if bot_player.mana + brew >= gross:
		return false
	return bot_player.mana + brew + mana_gain >= gross

func _plan_god_manifestation(attack: Dictionary = {}, danger: int = -1) -> Dictionary:
	var god := _find_player_god()
	if god is TezcatlipocaTheSmokingMirror:
		return _plan_necoc_yaotl(god, attack, danger)
	if god == null or not god.can_use_champions_call(game_manager):
		return {}
	var manifestation := god.get_champions_call_candidate(true)
	var zone := _get_first_open_summon_zone(bot_player)
	var mode := _choose_creature_summon_mode(manifestation)
	var projects_combat := manifestation is ThorActive or manifestation is GuanYuActive
	if projects_combat:
		mode = Card.CreatureMode.AGGRESSIVE
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
	var preview := _preview_board_creature(manifestation, zone) as ActiveGodCard
	preview.summoned_by_champions_call = true
	var score: int
	var lethal := false
	if projects_combat:
		# Champion's Call pays a different price from a normal summon. Price the
		# attack it actually gives us, including the defender's possible replies.
		if zone.zone_type != Zone.ZoneType.FRONTLINE \
				or game_manager.turn_number <= 1 or game_manager.has_resolved_attack_this_turn \
				or game_manager.attack_restrictions.has(bot_player) \
				or game_manager._any_active_structure_forces_defensive_summon() \
				or game_manager.is_first_turn_attack_blocked_by_weather(preview, true):
			return {}
		var candidates := _get_attack_candidates(preview, null, true)
		for candidate in candidates:
			for result: Dictionary in [candidate["base"]] + candidate["replies"].values():
				if preview in result.get("casualties", []):
					result["bot_cards_lost"] += _combat_god_death_cost(
						bot_player, result["casualties"], int(result["bot_followers_lost"]), true
					)
		var line := _plan_combat(candidates, [], null, mana_paid, zone)
		if line.is_empty() or preview in line.get("cleared", []):
			return {}
		lethal = bool(line.get("lethal", false))
		var cleared: Array = line.get("cleared", [])
		var mana_left := bot_player.mana - mana_paid - game_manager.get_creature_action_mana_cost(preview, "attack")
		score = _manifestation_deployment_value(manifestation, mana_paid, mode) + int(line["score"])
		if not lethal:
			score -= _estimate_projected_summon_casualty_cost(
				manifestation, zone, false, cleared, {}, false, mana_left, choices.slice(0, shelve_count), true
			)
	else:
		score = _score_god_manifestation(preview, mana_paid, mode)
	score -= shelve_penalty
	# Champion's Call removes the base god from the game as it lands the
	# manifestation, so a known entry answer (a Sap revealed by Light of
	# Morning's Doors or Dellingr) destroys the team's last god on arrival,
	# after the shelved cards are already spent, and the god-death follower
	# loss follows. Charge the full price so the call waits until that answer
	# is spent instead of walking the god into it.
	var entry_penalty := _known_entry_response_penalty(manifestation, zone, false)
	if entry_penalty > 0:
		if projects_combat:
			return {}
		score -= entry_penalty + _score_follower_loss(bot_player, GameManager.GOD_DEATH_FOLLOWER_LOSS)
	if not lethal and score < 2200:
		return {}
	return {"score": score, "lethal": lethal, "command": {
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
		payoff = CardStrategy.value(self, manifestation) - 2000 - mana_cost * _mana_rate()
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
		# Necoc Yaotl is a banking engine: it should spend low-value bodies,
		# and above all bodies it holds only temporarily — a Titlacauan
		# enslavement or a borrowed creature returns to the opponent when the
		# effect ends, so storing one forfeits nothing the bot keeps while
		# permanently removing an opposing body. Those are priced at zero.
		var score := payoff
		if card.card_owner == bot_player:
			# Owned bodies pay the board-presence toll plus their forfeited
			# value. The toll is a third of a card for the early stores —
			# cheap fodder is worth banking whenever the payoff's
			# spare-creature term shows a board surplus — and a full card for
			# the final store, which cashes the whole chain. Two lone bodies
			# still never cover the toll.
			@warning_ignore("integer_division")
			var body_cost := ECON_CARD_VALUE if final_sacrifice else ECON_CARD_VALUE / 3
			if card.is_token:
				body_cost /= 2
			var forfeit := maxi(0, _score_summon_sacrifice_candidate(card))
			# In a locked board a mid body's combat future is dead: its value
			# drops sharply, so banking it clears the toll.
			if _locked_board_state():
				forfeit = int(float(forfeit) * 0.5)
			score -= body_cost + forfeit
		@warning_ignore("integer_division")
		score -= card.equipment.size() * (ECON_CARD_VALUE / 2)
		if card == attacker or card == partner:
			@warning_ignore("integer_division")
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
			# The final sacrifice lands the team's last god (the normal god is
			# stored away while the Active form is out), so a known entry answer
			# destroys it on arrival and the god-death follower loss follows.
			# Price that against the theft instead of cashing it blindly.
			var entry_penalty := _known_entry_response_penalty(manifestation, zone, false)
			if entry_penalty > 0:
				score -= entry_penalty + _score_follower_loss(bot_player, GameManager.GOD_DEATH_FOLLOWER_LOSS)
		var safety_gain := _follower_safety_gain(danger, change, bot_player.mana)
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

func _berserker_rage_extra_cost(creature: Card) -> int:
	return Berserker.RAGE_ACTIVATION_COST + game_manager.get_creature_action_mana_cost(creature, "activate")

func _can_project_berserker_rage(creature: Card, summon_zone: Zone, mana_after_summon: int) -> bool:
	if not (creature is Berserker) or summon_zone == null or summon_zone not in bot_player.frontline_zones:
		return false
	if game_manager == null or game_manager.current_player != bot_player or creature.card_owner != bot_player:
		return false
	if creature.is_sleeping or creature.is_used or creature.abilities_suppressed_by_effects():
		return false
	if not game_manager.get_creature_ability_activation_block_reason(creature).is_empty():
		return false
	return mana_after_summon >= _berserker_rage_extra_cost(creature)

func _berserker_rage_stats(creature: Card) -> Dictionary:
	return {
		creature: Vector3i(Berserker.RAGE_STR_BONUS, 0, 0),
		PROJECTED_DESTRUCTION_GUARDS_KEY: [creature],
	}

func _plan_creature_summon(danger: int = -1, attacks: Array[Dictionary] = [], baseline: Dictionary = {}, removed_by_setup: Array = [], setup_cost: int = 0, setup: Dictionary = {}) -> Dictionary:
	if game_manager == null or opponent == null:
		return {}
	var plan_log: Array[Dictionary] = []
	var log_enabled := _decision_log_enabled
	var zones := _get_open_summon_lane_candidates(bot_player)
	if zones.is_empty():
		return {}
	var frontline_open := false
	for lane in zones:
		if lane in bot_player.frontline_zones:
			frontline_open = true
			break
	var best := {}
	var best_score := 0
	var best_attack_setup := {}
	# The Mead brew is on this turn's line, so summon planning prices against
	# the brewable stock. A summon the current stock cannot pay is tagged, and
	# the brew is submitted first (_submit_strategy_plan); the next pass
	# replays the same summon on the grown stock.
	var brew := _ready_brew_mana_gain()
	var available_mana := bot_player.mana + brew - setup_cost
	var baseline_score := int(baseline.get("score", 0))
	var summon_first := bool(setup.get("summon_first", false))
	var removed_before_summon := [] if summon_first else removed_by_setup
	var committed := setup.get("committed") as Card
	var reserved_cards: Array = setup.get("reserved_cards", [])
	var candidates: Array[Card] = bot_player.hand_zone.cards.duplicate()
	var wolf_master_source: Fenrir = null
	if not summon_first and not bot_player.has_summoned_this_turn and game_manager.current_player == bot_player:
		for card in bot_player.hand_zone.cards:
			if card is Fenrir and card.card_owner == bot_player and card not in reserved_cards:
				wolf_master_source = card
				# Payment is checked below against the mana available for this plan.
				var lupines := wolf_master_source.get_valid_wolf_master_summons()
				lupines.sort_custom(func(a: Card, b: Card) -> bool: return a.uid < b.uid)
				candidates.append_array(lupines)
				break
	var enemies := _get_board_creatures(opponent).filter(func(enemy: Card) -> bool: return enemy not in removed_before_summon)
	for summon_zone in zones:
		for creature in candidates:
			if creature in reserved_cards or (summon_first and not creature is Fenrir):
				continue
			# Future payment choices must still be legal after the first action.
			if not removed_by_setup.is_empty() and (creature.sacrifice_cost > 0 or creature.discard_cost > 0):
				continue
			var summon_source := wolf_master_source if creature.current_zone == bot_player.deck_zone else null
			var summon_cost := _get_play_cost(creature, false, summon_source)
			if summon_source != null and summon_cost > available_mana:
				continue
			var rage_ready := _can_project_berserker_rage(creature, summon_zone, available_mana - summon_cost)
			var rage_stats: Dictionary = _berserker_rage_stats(creature) if rage_ready else {}
			var rage_cost := _berserker_rage_extra_cost(creature) if rage_ready else 0
			var score := _score_creature_play_in_zone(
				creature, summon_zone, available_mana, false, summon_source, removed_before_summon
			)
			if score <= -1000000:
				continue
			# Lateral lane alignment: friendly gear that only this lane brings
			# into pickup reach. Attacks and interception reach are independent
			# of the column in this engine, so row-level value is scored below
			# and only the pickup-reach difference separates sibling lanes.
			score += _score_move_toward_equipment(creature, summon_zone)
			if summon_zone in bot_player.reserve_zones and frontline_open \
					and danger < bot_player.followers and not _is_dangerously_low_on_followers():
				# The frontline slot is open, so hiding this creature on the
				# reserve line is a real choice. Charge the lost attack
				# optionality: a frontline creature is one minor action away
				# from flipping to aggression and attacking, while a reserve
				# creature also has to spend a move and mana, and the advance
				# can be blocked. The toll scales with the creature's attack
				# value, but leave a positive deployment value when the reserve
				# is safe and the frontline is threatened.
				var placement_cost := creature.get_effective_strength() * RESERVE_PLACEMENT_STR_VALUE
				@warning_ignore("integer_division")
				score -= mini(placement_cost, maxi(0, score / 2))
			var payment_forecast := danger if creature.sacrifice_cost > 0 else -1
			var prior_payment_penalty := 0
			if payment_forecast >= 0:
				prior_payment_penalty = int(_build_creature_summon_payment_plan(creature, -1, {}, summon_source).get("penalty", 0))
			var fenrir: Fenrir = null
			if creature is Fenrir and game_manager._should_trigger_summon_impact(creature, creature.current_zone, summon_source):
				fenrir = creature
			var needs_attack := creature is RedCap
			var prefer_stealth := _prefers_stealth_summon(creature)
			@warning_ignore("integer_division")
			var face_up_block_value := 0 if fenrir != null else _estimate_defensive_summon_value(creature, summon_zone) / 2
			var reveal_value := _estimate_reveal_trigger_value(creature)
			# A reveal-removal body with no (or only junk) targets on the board
			# still banks its trigger: it can reveal later by attacking or by
			# being attacked, so the hold option is worth a discounted card.
			var banked_reveal_value := _banked_reveal_removal_value(creature)
			var hold_reveal_value := maxi(reveal_value, banked_reveal_value)
			var search_value := _estimate_summon_search_value(creature, available_mana - summon_cost, danger)
			if prefer_stealth and creature is HariiJarl:
				var warband_value := _estimate_harii_jarl_warband_value(creature)
				score -= warband_value
				search_value += warband_value
			var reveal_defender := hold_reveal_value > 0
			var stealth_block_value := 0
			if reveal_defender or prefer_stealth:
				@warning_ignore("integer_division")
				stealth_block_value = _estimate_defensive_summon_value(creature, summon_zone, true) / 2
			var block_value := maxi(face_up_block_value, stealth_block_value)
			var rage_attacks: Array[Dictionary] = []
			if rage_ready and fenrir == null:
				rage_attacks = _get_summon_attack_candidates(
					creature, summon_zone, available_mana - rage_cost, rage_stats,
					removed_before_summon, removed_by_setup, summon_source
				)
			var rage_opens_attack := false
			for rage_attack in rage_attacks:
				var rage_base: Dictionary = rage_attack.get("base", {})
				if rage_attack.get("target") is Card and int(rage_base.get("opponent_cards_lost", 0)) > 0:
					rage_opens_attack = true
					break
			var mode := _choose_creature_summon_mode(creature, enemies)
			if rage_ready and rage_opens_attack:
				mode = Card.CreatureMode.AGGRESSIVE
			elif (block_value > 0 or reveal_defender) and removed_by_setup.is_empty():
				mode = Card.CreatureMode.DEFENSIVE
			var modes := [mode]
			var summon_attacks: Array[Dictionary] = []
			if fenrir == null:
				if rage_ready:
					summon_attacks = rage_attacks
				else:
					summon_attacks = _get_summon_attack_candidates(creature, summon_zone, available_mana, {}, removed_before_summon, removed_by_setup, summon_source)
			if prefer_stealth or danger > 0 or not summon_attacks.is_empty() or fenrir != null:
				modes.append(Card.CreatureMode.DEFENSIVE if mode == Card.CreatureMode.AGGRESSIVE else Card.CreatureMode.AGGRESSIVE)
			var mana_spent := setup_cost + summon_cost
			var needs_brew := bool(setup.get("brew_setup", false)) or mana_spent > bot_player.mana \
				or (rage_ready and rage_opens_attack and bot_player.mana - summon_cost < rage_cost)
			var summon_budget := available_mana if needs_brew else bot_player.mana - setup_cost
			var mana_after_summon := summon_budget - summon_cost
			if rage_ready:
				# Rage is part of this line, so keep the post-summon safety
				# budget honest about the mana the buff will spend.
				mana_after_summon -= rage_cost
			var aggressive_attacks := attacks + summon_attacks
			for summon_mode in modes:
				var defensive: bool = summon_mode == Card.CreatureMode.DEFENSIVE
				var projected_defensive := defensive or game_manager._any_active_structure_forces_defensive_summon(removed_before_summon)
				if needs_attack and (projected_defensive or summon_attacks.is_empty()):
					continue
				var command := _build_creature_play_command(creature, summon_zone, summon_mode, payment_forecast, projected_defensive, summon_budget, summon_source)
				if command.is_empty():
					continue
				var default_stealth := bool(command["stealth"]) and face_up_block_value <= 0 and danger <= 0
				var stealth_options := [default_stealth]
				if defensive and prefer_stealth:
					stealth_options = [true, false]
				elif defensive and reveal_defender:
					stealth_options = [default_stealth, not default_stealth]
				var removed := removed_before_summon + _summon_payment_cards(command)
				if summon_source != null and reserved_cards.any(func(card: Card) -> bool: return card in removed):
					continue
				var removed_on_entry := removed
				var change := {
					"removed": removed, "summon": creature, "zone": summon_zone, "stance": creature,
					"defensive": projected_defensive, "mana_left": mana_after_summon,
				}
				var devour := {}
				var charge := {}
				var stats := {}
				var block_after_impact := face_up_block_value
				var projected := attacks if projected_defensive else aggressive_attacks
				if fenrir != null:
					devour = _forecast_fenrir_devour(fenrir, danger, change)
					if devour.is_empty():
						continue
					removed = devour["removed"]
					if summon_first:
						# The second action must still have its declared target after Devour.
						if removed_by_setup.any(func(victim: Card) -> bool: return victim in removed):
							continue
						removed = removed + removed_by_setup
					stats = devour["combat_stats"]
					change["removed"] = removed
					change["combat_stats"] = stats
					if projected_defensive:
						@warning_ignore("integer_division")
						block_after_impact = _estimate_defensive_summon_value(creature, summon_zone, false, stats, removed) / 2
					else:
						projected = attacks + _get_summon_attack_candidates(creature, summon_zone, available_mana, stats, removed_before_summon, removed_by_setup)
				elif creature is GugalannaBullOfHeaven and not default_stealth \
						and game_manager._should_trigger_summon_impact(creature, creature.current_zone, summon_source) \
						and not CardStrategy.summon_impact_silenced_by_storm(self, creature, removed):
					var targets: Array[Card] = creature.get_valid_impact_targets(game_manager).filter(
						func(target: Card) -> bool: return CardStrategy.visible(self, target)
					)
					charge = _forecast_celestial_charge(creature, targets, danger, change)
					if not charge.is_empty():
						change = charge["change"]
						removed = change["removed"]
				var returns_to_hand := bool(charge.get("returns_to_hand", false))
				var recruit := null if returns_to_hand else creature
				var occupied_zone := null if returns_to_hand else summon_zone
				if returns_to_hand:
					projected = attacks
					block_after_impact = 0
				var line := _plan_combat(projected, removed, committed, mana_spent, occupied_zone, bot_player.mana + brew, [], recruit)
				var combat_score := int(line.get("score", 0))
				var attack_value := combat_score - baseline_score
				if prefer_stealth and not returns_to_hand and not projected_defensive and not summon_attacks.is_empty():
					var boosted := _plan_hermes_summon_attack(creature, summon_zone, attacks, removed, mana_spent, available_mana, committed, removed_before_summon, summon_source)
					var boosted_score := int(boosted.get("score", 0))
					if boosted_score - Hermes.ACTIVATION_COST * _mana_rate() > combat_score:
						line = boosted
						combat_score = boosted_score
						attack_value = combat_score - baseline_score - Hermes.ACTIVATION_COST * _mana_rate()
				var cleared: Array = line.get("cleared", [])
				for stealth: bool in stealth_options:
					var lethal := bool(line.get("lethal", false))
					var uses_recruit: bool = creature in line.get("attackers", [])
					var candidate_combat := combat_score
					var defensive_value := stealth_block_value if stealth and (reveal_defender or prefer_stealth) else block_after_impact
					var candidate := score + (defensive_value if projected_defensive and removed_by_setup.is_empty() else 0) + attack_value
					candidate += int(devour.get("value", 0)) + int(charge.get("value", 0))
					if rage_ready and not projected_defensive and not summon_attacks.is_empty():
						# The summon line assumes Rage is paid before the attack.
						candidate -= CardStrategy.mana_penalty(self, rage_cost) + 1500
					if returns_to_hand:
						candidate -= _score_projected_card(creature)
					if defensive and stealth and reveal_defender:
						# The hold keeps the trigger banked: price the option
						# (banked floor included), not just the best current target.
						candidate += hold_reveal_value
					elif stealth and not projected_defensive and uses_recruit:
						# A hidden body that swings reveals in combat and spends
						# the trigger on the best current target. The attack
						# projection prices the attacker as the revealed form and
						# drops that value, so credit the realized spend here.
						candidate += reveal_value
					if not stealth:
						candidate += search_value
						if prefer_stealth and not returns_to_hand:
							candidate += _estimate_face_up_summon_value(creature, summon_zone, projected_defensive, mana_after_summon, removed)
					candidate += prior_payment_penalty - int(command.get("payment_penalty", 0))
					change["stealth"] = stealth
					# The combat score already credits ordinary damage prevention. Only
					# fold the clears into safety when survival is at stake.
					var impact_opens_combat := not charge.is_empty() and combat_score > baseline_score
					var uses_combat_for_safety := (uses_recruit or impact_opens_combat) and danger >= bot_player.followers
					var safety_mana := mana_after_summon
					var brew_for_combat := false
					if uses_combat_for_safety:
						var combat_spend := bot_player.mana + brew - mana_spent - int(line["mana"])
						brew_for_combat = int(line["mana_required"]) > bot_player.mana
						safety_mana = int(line["mana"]) if brew_for_combat else mana_after_summon - combat_spend
					change["removed"] = removed + cleared if uses_combat_for_safety else removed
					change["mana_left"] = safety_mana
					var safety := _follower_safety_gain(danger, change, safety_mana) if devour.is_empty() or summon_first or uses_combat_for_safety else int(devour["safety"])
					if not stealth and danger > 0 and fenrir == null:
						safety = _score_summon_terror(creature, danger, change, safety)
					candidate += safety
					var casualty_cost := 0
					if not lethal and not returns_to_hand:
						casualty_cost = _estimate_projected_summon_casualty_cost(
							creature, summon_zone, projected_defensive, removed + cleared, stats, stealth,
							mana_after_summon, reserved_cards
						)
						candidate -= casualty_cost
						candidate += _champions_call_cover_gain(
							creature, summon_zone, projected_defensive, stealth, removed + cleared,
							mana_after_summon, stats
						)
					# Compare the unopposed line with each known answer. A recruit
					# lost on entry cannot supply the attack, block, or follow-up.
					var unanswered_score := candidate
					for reply in _get_known_entry_responses(creature, summon_zone, stealth, removed_on_entry):
						var victims: Array = reply["victims"]
						var recruit_survives := creature not in victims
						var after_entry: Array = removed_on_entry + victims + [reply["hex"]]
						var remaining_attacks := attacks
						if recruit_survives and fenrir == null and not projected_defensive:
							remaining_attacks = aggressive_attacks
						var occupied := summon_zone if recruit_survives else null
						var surviving_recruit := creature if recruit_survives else null
						var reply_line := _plan_combat(remaining_attacks, after_entry, committed, mana_spent, occupied, bot_player.mana + brew, [], surviving_recruit)
						var reply_combat := int(reply_line.get("score", 0))
						var mana_left := mana_after_summon
						var reply_score := _score_known_entry_trade(reply, mana_left, removed_on_entry + [creature] + reserved_cards)
						reply_score += reply_combat - baseline_score - int(command.get("payment_penalty", 0))
						var reply_change := {"removed": after_entry}
						if recruit_survives:
							reply_score += score + prior_payment_penalty
							reply_change.merge({"summon": creature, "zone": summon_zone, "stance": creature,
								"defensive": projected_defensive, "stealth": stealth})
						else:
							reply_score -= CardStrategy.mana_penalty(self, summon_cost, available_mana)
						var reply_lethal := bool(reply_line.get("lethal", false))
						if not reply_lethal:
							reply_score += _follower_safety_gain(danger, reply_change, mana_left)
						if (lethal and not reply_lethal) or (lethal == reply_lethal and reply_score < candidate):
							candidate = reply_score
							candidate_combat = reply_combat
							lethal = reply_lethal
						uses_recruit = uses_recruit and creature in reply_line.get("attackers", [])
					# Fresh Blood destroys Red Cap at end of turn if its attack never resolves.
					if needs_attack and not uses_recruit:
						continue
					var entry_penalty := unanswered_score - candidate
					if log_enabled:
						plan_log.append({
							"key": "%s|%d|%d|%d|%s" % [creature.uid, summon_zone.zone_type, summon_zone.zone_index, summon_mode, str(stealth)],
							"name": creature.card_name if summon_source == null else "Wolf Master: " + creature.card_name,
							"zone_type": summon_zone.zone_type,
							"zone_index": summon_zone.zone_index,
							"mode": summon_mode,
							"stealth": stealth,
							"base": score,
							"block": defensive_value if projected_defensive and removed_by_setup.is_empty() else 0,
							"attack": attack_value,
							"devour": int(devour.get("value", 0)),
							"charge": int(charge.get("value", 0)),
							"safety": safety,
							"casualty": casualty_cost,
							"entry": entry_penalty,
							"pay": prior_payment_penalty - int(command.get("payment_penalty", 0)),
							"reveal": hold_reveal_value if defensive and stealth and reveal_defender
									else reveal_value if stealth and not projected_defensive and uses_recruit else 0,
							"search": search_value if not stealth else 0,
							"lethal": lethal,
							"candidate": candidate,
						})
					var best_command: Dictionary = best.get("command", {})
					var best_uid: String = best_command.get("card_uid", best_command.get("lupine_uid", ""))
					var best_is_stealth := bool(best_command.get("stealth", false)) or str(best_command.get("mode", "")) == "stealth"
					var prefers_hidden_tie: bool = candidate > 0 and candidate == best_score and prefer_stealth and stealth \
						and best_uid == creature.uid and not best_is_stealth
					var improves_combat := (uses_recruit or impact_opens_combat) and (lethal or (candidate > 0 and candidate_combat > baseline_score))
					var best_setup_wins := bool(best_attack_setup.get("lethal", false))
					var preferred_setup := improves_combat and (
						(lethal and not best_setup_wins)
						or (lethal == best_setup_wins and candidate > int(best_attack_setup.get("score", 0)))
					)
					if candidate > best_score or prefers_hidden_tie or preferred_setup:
						var plan := {"command": command.duplicate(), "score": candidate, "combat_score": candidate_combat, "lethal": lethal}
						plan["command"]["stealth"] = stealth
						plan["command"].erase("payment_penalty")
						if summon_source != null:
							plan["command"] = {
								"type": "wolf_master_summon",
								"fenrir_uid": summon_source.uid,
								"lupine_uid": creature.uid,
								"player_index": command["player_index"],
								"zone_type": command["zone_type"],
								"zone_index": command["zone_index"],
								"mode": "stealth" if stealth else ("defensive" if defensive else "aggressive"),
								"sacrifice_uids": command["sacrifice_uids"],
							}
						if needs_brew or brew_for_combat:
							# Bank the mana before a summon that relies on it for setup or survival.
							plan["brew_setup"] = true
						if preferred_setup:
							best_attack_setup = plan
						if candidate <= best_score and not prefers_hidden_tie:
							continue
						best = plan
						best_score = candidate
	if not best_attack_setup.is_empty():
		if best.is_empty():
			best = best_attack_setup
		best = best.duplicate()
		best["attack_setup"] = best_attack_setup
	if log_enabled:
		_log_summon_plans(danger, plan_log, best, removed_by_setup.size(), setup_cost)
	return best

# Prints the evaluated summon candidates from one _plan_creature_summon call,
# best first, with the score terms that built each candidate. The chosen plan
# is marked so a losing alternative can be diffed term by term.
func _log_summon_plans(danger: int, plan_log: Array[Dictionary], best: Dictionary, setup_removed: int, setup_cost: int) -> void:
	if plan_log.is_empty():
		return
	plan_log.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return int(a["candidate"]) > int(b["candidate"]))
	var best_key := ""
	if not best.is_empty():
		var command: Dictionary = best["command"]
		var mode: int = Card.CreatureMode.DEFENSIVE
		var stealth := false
		var uid: String = command.get("card_uid", command.get("lupine_uid", ""))
		if command["type"] == "wolf_master_summon":
			mode = Card.CreatureMode.AGGRESSIVE if command["mode"] == "aggressive" else Card.CreatureMode.DEFENSIVE
			stealth = command["mode"] == "stealth"
		else:
			mode = int(command["mode"])
			stealth = bool(command["stealth"])
		best_key = "%s|%d|%d|%d|%s" % [uid, command["zone_type"], command["zone_index"], mode, str(stealth)]
	print("BOT_SUMMON turn=%d danger=%d followers=%d mana=%d setup_removed=%d setup_cost=%d" % [
		game_manager.turn_number if game_manager else -1,
		danger, bot_player.followers, bot_player.mana, setup_removed, setup_cost,
	])
	for i in mini(10, plan_log.size()):
		var entry: Dictionary = plan_log[i]
		var zone_label := "F" if int(entry["zone_type"]) == Zone.ZoneType.FRONTLINE \
				else ("R" if int(entry["zone_type"]) == Zone.ZoneType.RESERVE else "?")
		var mode_label := "AGG" if int(entry["mode"]) == Card.CreatureMode.AGGRESSIVE else "DEF"
		var marker := " <== chosen" if str(entry["key"]) == best_key else ""
		print("  %d) %s z=%s%d mode=%s stealth=%s | base=%d blk=%d atk=%d dev=%d charge=%d saf=%d cas=%d entry=%d pay=%d rev=%d srch=%d lethal=%s => %d%s" % [
			i + 1, entry["name"], zone_label, entry["zone_index"], mode_label, str(entry["stealth"]),
			entry["base"], entry["block"], entry["attack"], entry["devour"], entry["charge"], entry["safety"],
			entry["casualty"], entry["entry"], entry["pay"], entry["reveal"], entry["search"],
			str(entry["lethal"]), entry["candidate"], marker,
		])

func _estimate_summon_search_value(creature: Card, mana: int, danger: int) -> int:
	if not (CardStrategy.key(creature) == "FourthSageEnmegalamma" \
			or creature is GiantMasterArchitect or creature is PaiLongAutumnKing):
		return 0
	if not game_manager.can_player_add_to_hand_now(bot_player) or creature.abilities_suppressed_by_effects():
		return 0
	var value := 0
	for target: Card in creature.get_valid_targets(game_manager):
		var pick := _deck_pick_value(target, mana, danger)
		if CardStrategy.key(creature) == "FourthSageEnmegalamma":
			# Search Sage acquires its target by paying half its level, so
			# the mana leaves the same turn the summon does.
			pick -= CardStrategy.mana_penalty(self, creature.get_acquisition_cost(target))
		value = maxi(value, pick)
	return mini(ECON_CARD_VALUE * 2, value)

func _estimate_face_up_summon_value(creature: Card, zone: Zone, defensive: bool, mana: int, removed: Array) -> int:
	var value := 0
	if not creature.abilities_suppressed_by_effects():
		if creature is JiangZiyaFisherOfKings and game_manager.can_player_add_to_hand_now(bot_player) \
				and not creature.get_valid_targets(game_manager).is_empty():
			value += ECON_MANA_VALUE
		elif creature is DurinnSecondborn and mana >= DurinnSecondborn.REFORGE_COST \
				and game_manager.can_player_add_to_hand_now(bot_player) and not creature.get_valid_targets(game_manager).is_empty():
			value += ECON_MANA_VALUE
		elif creature is FirstSageAdapa or creature is ThirdSageEnmedugga:
			if creature.get_valid_targets(game_manager).any(func(target: Card) -> bool: return target not in removed):
				value += ECON_MANA_VALUE
		elif creature is HelBlarDraug:
			for enemy in _get_board_creatures(opponent):
				if enemy not in removed and CardStrategy.visible(self, enemy) and enemy.has_type("Aerial") \
						and not game_manager.is_immune_to_source(enemy, creature):
					value += ECON_MANA_VALUE
	return value + _estimate_face_up_summon_forced_combat(creature, zone, defensive, mana, removed)

func _estimate_face_up_summon_forced_combat(creature: Card, zone: Zone, defensive: bool, mana: int, removed: Array) -> int:
	var best_gain := 0
	for card: Card in bot_player.hand_zone.cards + game_manager.get_field_cards(bot_player):
		var spell := card as FoolishOptimism
		if spell == null or spell in removed:
			continue
		var cost := CardStrategy.activation_cost(self, spell)
		if cost > mana:
			continue
		if spell.is_prepared:
			if not spell.can_activate_prepared(game_manager, bot_player):
				continue
		elif spell.current_zone != bot_player.hand_zone or not game_manager.can_play_card(bot_player, spell, null):
			continue
		var attackers := spell.get_lowest_level_attacker_choices(game_manager).filter(func(candidate: Card) -> bool: return candidate not in removed)
		if attackers.is_empty():
			continue
		var existing := spell.get_highest_level_defender_choices(game_manager).filter(func(candidate: Card) -> bool: return candidate not in removed)
		var level := creature.get_effective_level()
		if not existing.is_empty() and existing[0].get_effective_level() > level:
			continue
		var defender := _preview_board_creature(creature, zone)
		defender.creature_mode = Card.CreatureMode.DEFENSIVE if defensive else Card.CreatureMode.AGGRESSIVE
		var earlier := CardStrategy.forced_combat_choice(self, spell, attackers, existing)
		var after := CardStrategy.forced_combat_choice(self, spell, attackers, [defender])
		var gain := int(after["score"]) - cost * _mana_rate()
		var existing_gain := maxi(0, int(earlier["score"]) - cost * _mana_rate())
		best_gain = maxi(best_gain, gain - existing_gain)
	return best_gain

func _plan_hermes_summon_attack(creature: Card, zone: Zone, attacks: Array[Dictionary], removed: Array, mana_spent: int, available_mana: int, committed: Card = null, removed_before_summon: Array = [], summon_source: Fenrir = null) -> Dictionary:
	var hermes := _find_player_god() as Hermes
	# The brew may fund the speed activation plus the summon line's taxes.
	var brew := _ready_brew_mana_gain()
	if hermes == null or not hermes.can_plan_activation_after_upkeep(game_manager, bot_player.mana + brew - mana_spent) \
			or creature.negates_external_effects() or game_manager.is_immune_to_source(creature, hermes):
		return {}
	var stats := {creature: Vector3i(0, 0, Hermes.SPEED_BONUS)}
	var boosted := _get_summon_attack_candidates(creature, zone, available_mana - Hermes.ACTIVATION_COST, stats, removed_before_summon, removed, summon_source)
	if boosted.is_empty():
		return {}
	return _plan_combat(attacks + boosted, removed, committed, mana_spent + Hermes.ACTIVATION_COST, zone, bot_player.mana + brew, [], creature)

func _estimate_projected_summon_casualty_cost(
	creature: Card,
	zone: Zone,
	defensive: bool,
	removed: Array,
	stats: Dictionary = {},
	stealth: bool = false,
	mana_left: int = -1,
	unavailable: Array = [],
	replaces_god: bool = false
) -> int:
	if creature == null or zone == null or not zone.is_board_zone():
		return 0
	var target := _preview_summoned_creature(creature, zone, stealth)
	target.uid = creature.uid
	target.creature_mode = Card.CreatureMode.DEFENSIVE if defensive else Card.CreatureMode.AGGRESSIVE
	var greatest_loss := 0
	for attacker in _get_creature_attackers_next_turn(target, removed):
		var action := CardAction.new()
		action.type = CardAction.Type.ATTACK
		action.attacker = attacker
		action.target = creature
		var result := _estimate_raw_attack_economy(action, stats, target.creature_mode)
		if creature not in result.get("casualties", []):
			continue
		var loss := _score_projected_summon_attack_loss(result)
		# A hidden reveal body answers the attack that kills it: combat reveals
		# it, and its Reveal removal (Drown Below / Dalkhu Break) destroys a
		# creature before damage resolves, so the casualty is never a naked
		# loss. Credit the chosen victim against the projected loss. An
		# interceptor takes the hit instead and the body stays hidden, so that
		# path below correctly gets no credit.
		if stealth and (creature is Grindylow or creature is MasmassuPriest) \
				and not creature.abilities_suppressed_by_effects():
			var reveal_target := _choose_combat_reveal_removal(
				creature, _get_reveal_removal_targets(creature), action, result["casualties"]
			)
			if reveal_target != null:
				loss -= _get_card_economic_value(reveal_target)
		if replaces_god:
			loss += _combat_god_death_cost(bot_player, removed + result["casualties"], int(result["bot_followers_lost"]), true)
		for interceptor in match_manager._get_possible_interceptors(attacker, target):
			if interceptor == creature or interceptor in removed or _status_persists_to_next_turn(interceptor, "cannot_intercept", removed):
				continue
			action.interceptor = interceptor
			loss = mini(loss, _score_projected_summon_attack_loss(_estimate_raw_attack_economy(action, stats)))
		greatest_loss = maxi(greatest_loss, loss)
	# Devour-class activated removal ignores stance and stealth alike (its
	# target check has no hidden-state filter), so the same worst-case max
	# covers every projected form the caller asks about.
	greatest_loss = maxi(greatest_loss, _projected_opponent_removal_loss(target, removed))
	var projected_stats := stats.duplicate()
	var target_delta: Vector3i = projected_stats.get(creature, Vector3i.ZERO)
	if not creature.counts_as_on_field() and not replaces_god:
		target_delta.x += _get_projected_strength(creature) - creature.get_effective_strength()
		target_delta.y += _get_projected_resilience(creature) - creature.get_effective_resilience()
	projected_stats[target] = target_delta
	return maxi(greatest_loss, _estimate_champions_call_loss(
		target, removed, projected_stats, mana_left, unavailable, replaces_god
	))

func _projected_champions_call(removed: Array) -> Dictionary:
	if opponent == null or opponent.god_zone.cards.is_empty():
		return {}
	var god := opponent.god_zone.cards[0] as GodCard
	if not (god is Thor or god is GuanYu) or god in removed or not CardStrategy.visible(self, god) \
			or god.is_muted or _status_persists_to_next_turn(god, "activation_locked", removed):
		return {}
	var restriction: Dictionary = game_manager.attack_restrictions.get(opponent, {})
	if not restriction.is_empty() and restriction.get("source") not in removed:
		return {}
	var zone: Zone = null
	for lane in opponent.frontline_zones:
		if lane.cards.all(func(card: Card) -> bool: return card in removed):
			zone = lane
			break
	if zone == null:
		return {}
	# The base god publicly guarantees its linked form. Use that profile and
	# the public hand size, since shelving doesn't depend on card identities.
	var attacker: ActiveGodCard = ThorActive.new() if god is Thor else GuanYuActive.new()
	for creature in _get_board_creatures(opponent):
		if creature not in removed and CardStrategy.visible(self, creature) and creature is ActiveGodCard \
				and creature.get_linked_god_name() == attacker.get_linked_god_name():
			return {}
	attacker.card_owner = opponent
	if game_manager.is_first_turn_attack_blocked_by_weather(attacker, true, removed):
		return {}
	var cost := game_manager.get_creature_summon_mana_cost(opponent, attacker, god)
	var upkeep_mana := opponent.mana + game_manager.get_automatic_upkeep_mana_gain(opponent, game_manager.turn_number + 1)
	var shelve_value := opponent.hand_zone.cards.size() * GodCard.CHAMPIONS_CALL_SHELVE_MANA_VALUE
	var with_mana := upkeep_mana + game_manager.get_effective_upkeep_mana_gain(game_manager.get_base_upkeep_mana_gain(), opponent)
	var with_draw := upkeep_mana + game_manager.get_effective_upkeep_mana_gain(game_manager.get_base_upkeep_draw_mana_gain(), opponent)
	var cash_with_mana := maxi(0, cost - shelve_value)
	var cash_with_draw := cash_with_mana
	if not opponent.deck_zone.cards.is_empty() and game_manager.can_player_add_to_hand_now(opponent):
		cash_with_draw = maxi(0, cash_with_draw - GodCard.CHAMPIONS_CALL_SHELVE_MANA_VALUE)
	var mana_left := maxi(with_mana - cash_with_mana, with_draw - cash_with_draw)
	if mana_left < 0:
		return {}
	# A defensive-only summon can switch stance with its fresh minor action.
	attacker.current_zone = zone
	attacker.creature_mode = Card.CreatureMode.AGGRESSIVE
	attacker.summoned_by_champions_call = true
	return {"attacker": attacker, "cost": with_mana - mana_left}

func _estimate_champions_call_loss(
	target: Card, removed: Array, stats: Dictionary = {}, mana_left: int = -1,
	unavailable: Array = [], replaces_god: bool = false, recruit: Card = null
) -> int:
	var attacker := _projected_champions_call(removed).get("attacker") as Card
	if attacker == null or not game_manager.can_cards_engage_each_other(attacker, target):
		return 0
	for structure in game_manager._get_active_structures():
		if structure not in removed and structure.blocks_attack_on_target(game_manager, attacker, target):
			return 0
	var action := CardAction.new()
	action.type = CardAction.Type.ATTACK
	action.source_player = opponent
	action.attacker = attacker
	action.target = target
	var combat := _estimate_projected_attack_economy(action, stats, false)
	if target not in combat["casualties"]:
		return 0
	var budget := bot_player.mana if mana_left < 0 else mana_left
	if _has_prepared_answer_to_champions_call(attacker, target, budget, removed):
		return 0
	var loss := _score_champions_call_trade(attacker, combat, removed, budget, unavailable, replaces_god)
	var interceptors := match_manager._get_possible_interceptors(attacker, target, attacker.get_effective_speed())
	if recruit != null and match_manager._can_intercept(recruit, attacker, target, null, 0, attacker.get_effective_speed()):
		interceptors.append(recruit)
	for interceptor in interceptors:
		if interceptor.uid == target.uid or interceptor in removed or _status_persists_to_next_turn(interceptor, "cannot_intercept", removed):
			continue
		action.interceptor = interceptor
		combat = _estimate_projected_attack_economy(action, stats, false)
		loss = mini(loss, _score_champions_call_trade(attacker, combat, removed, budget, unavailable, false))
	return maxi(0, loss)

func _champions_call_cover_gain(
	creature: Card, zone: Zone, defensive: bool, stealth: bool, removed: Array, mana_left: int, stats: Dictionary
) -> int:
	if zone.zone_type != Zone.ZoneType.FRONTLINE and not creature is ThorActive:
		return 0
	var gain := 0
	if creature in removed:
		return gain
	for god in _get_board_creatures(bot_player):
		if not god is ActiveGodCard or god in removed:
			continue
		var before := _estimate_champions_call_loss(god, removed, {}, mana_left)
		if before <= 0:
			continue
		var recruit := _preview_board_creature(creature, zone)
		recruit.is_face_down = stealth
		recruit.is_stealth = stealth
		recruit.is_sleeping = false
		recruit.creature_mode = Card.CreatureMode.DEFENSIVE if defensive else Card.CreatureMode.AGGRESSIVE
		var recruit_stats: Vector3i = stats.get(creature, Vector3i.ZERO)
		recruit_stats.x += _get_projected_strength(creature) - creature.get_effective_strength()
		recruit_stats.y += _get_projected_resilience(creature) - creature.get_effective_resilience()
		var after := _estimate_champions_call_loss(god, removed, {recruit: recruit_stats}, mana_left, [], false, recruit)
		gain = maxi(gain, before - after)
	return gain

func _has_prepared_answer_to_champions_call(attacker: Card, target: Card, mana: int, removed: Array) -> bool:
	for hex: Card in game_manager.prepared_hexes:
		if hex.get_controller() != bot_player or hex in removed or not hex.is_prepared \
				or hex.is_muted or _status_persists_to_next_turn(hex, "activation_locked", removed) \
				or hex.get_effective_speed() < maxi(2, attacker.get_effective_speed()) \
				or game_manager.get_prepared_card_activation_mana_cost(bot_player, hex) > mana:
			continue
		var answers := false
		if hex is Sap:
			answers = hex.is_valid_target(game_manager, attacker)
		elif hex is Smite or hex is VoidShield:
			answers = hex.can_activate(attacker, target)
		if answers and CardStrategy.can_remove_from_board(self, hex, attacker, not hex is VoidShield):
			return true
	return false

func _score_champions_call_trade(
	attacker: Card, result: Dictionary, removed: Array, mana: int, unavailable: Array, replaces_god: bool
) -> int:
	var loss := int(result["bot_cards_lost"]) - int(result["opponent_cards_lost"]) \
		+ _score_follower_loss(bot_player, int(result["bot_followers_lost"])) \
		- _score_follower_loss(opponent, int(result["opponent_followers_lost"]))
	var casualties: Array = result["casualties"]
	var bot_death_cost := _combat_god_death_cost(bot_player, removed + casualties, int(result["bot_followers_lost"]), replaces_god)
	loss += bot_death_cost
	if attacker in casualties:
		loss -= _combat_god_death_cost(opponent, removed + casualties, int(result["opponent_followers_lost"]), true)
	# A surviving god can still be a good trade for a body if it walks into
	# removal. Discount that credit because the opponent has another turn's
	# priority windows and can decide whether to commit the god at all.
	if loss > 0 and not bool(result["opponent_wins"]) and attacker not in casualties \
			and (bot_death_cost <= 0 or bot_player.followers - int(result["bot_followers_lost"]) > GameManager.GOD_DEATH_FOLLOWER_LOSS):
		@warning_ignore("integer_division")
		loss -= _champions_call_follow_up_value(attacker, removed + casualties, mana, unavailable, bot_death_cost > 0) / 2
	return loss

func _combat_god_death_cost(player: Player, casualties: Array, damage: int, replaces_god: bool = false, starting_followers: int = -1) -> int:
	# Mummu, Active God reactivates the stored normal god when it leaves the
	# field (MummuActive.on_removed), so its death never starts God Death:
	# price it as the card alone instead of charging phantom follower bleed.
	var god_deaths := casualties.filter(func(card: Card) -> bool:
		return card is ActiveGodCard and not (card is MummuActive) and card.get_controller() == player)
	if not god_deaths.is_empty() and _loses_last_god(player, god_deaths, replaces_god):
		var before := player.followers if starting_followers < 0 else starting_followers
		return ECON_CARD_VALUE + _score_follower_loss(player, GameManager.GOD_DEATH_FOLLOWER_LOSS, maxi(0, before - damage))
	return 0

func _loses_last_god(player: Player, removed: Array, replaces_god: bool) -> bool:
	if not replaces_god and game_manager.player_has_normal_god(player):
		return false
	for creature in _get_board_creatures(player):
		if not creature.is_face_down and not creature.is_stealth and not creature.is_sleeping \
				and creature is ActiveGodCard and not removed.any(func(card: Card) -> bool: return card != null and card.uid == creature.uid):
			return false
	return true

func _champions_call_follow_up_value(
	attacker: Card, removed: Array, mana: int, unavailable: Array, under_god_death: bool
) -> int:
	var budget := mana + game_manager.get_effective_upkeep_mana_gain(game_manager.get_base_upkeep_mana_gain(), bot_player)
	if not under_god_death:
		budget += game_manager.get_automatic_upkeep_mana_gain(bot_player, game_manager.turn_number + 2)
	return _manifestation_removal_value(attacker, budget, removed, unavailable, 2)

func _manifestation_removal_value(
	target: Card, budget: int, removed: Array = [], unavailable: Array = [], turn_offset: int = 0
) -> int:
	var projected := turn_offset > 0
	var value := _get_card_economic_value(target) + _combat_god_death_cost(opponent, removed + [target], 0, projected)
	var best := 0
	for source in _get_board_creatures(bot_player):
		if not source is Nimue or source in removed or source.is_face_down or source.is_stealth or source.is_prepared \
				or source.abilities_suppressed() or _status_persists_to_next_turn(source, "activation_locked", removed, turn_offset):
			continue
		if projected and _status_persists_to_next_turn(source, "sleep", removed, turn_offset) \
				or not projected and (source.is_sleeping or not source.can_take_major_creature_action()):
			continue
		var cost := target.get_effective_level() + game_manager.get_creature_action_mana_cost(source, "activate")
		if budget >= cost and CardStrategy.can_remove_from_board(self, source, target, false):
			best = maxi(best, value - CardStrategy.mana_penalty(self, cost))
	for spell in bot_player.hand_zone.cards + game_manager.get_field_cards(bot_player):
		if not (spell is FallOfTheMighty or spell is FiresOfJudgment) or spell in removed or spell in unavailable \
				or (not spell.is_prepared and (spell.current_zone != bot_player.hand_zone or game_manager.spells_must_be_prepared())) \
				or _status_persists_to_next_turn(spell, "activation_locked", removed, turn_offset):
			continue
		var cost := CardStrategy.activation_cost(self, spell)
		if budget < cost or not CardStrategy.can_remove_from_board(self, spell, target, true, false):
			continue
		var spell_cost := ECON_CARD_VALUE + CardStrategy.mana_penalty(self, cost)
		if spell is FiresOfJudgment:
			best = maxi(best, value - spell_cost)
			continue
		var strength := target.get_effective_strength()
		var collateral := 0
		var strongest := true
		for creature in FallOfTheMighty.get_creatures_for_strength_check(game_manager):
			if creature in removed:
				continue
			if not CardStrategy.visible(self, creature):
				strongest = false
				break
			var projected_strength := creature.get_effective_strength()
			if projected and target is ThorActive and creature.get_controller() == opponent and creature.has_type("Warrior"):
				projected_strength += 5
				if creature.has_type("Human"):
					projected_strength -= 3
			if projected_strength > strength:
				strongest = false
				break
			if projected_strength == strength and creature.get_controller() == bot_player:
				collateral += _get_card_economic_value(creature)
		if strongest:
			best = maxi(best, value - spell_cost - collateral)
	return best

# What a projected body stands to lose to an opponent's activated board ability
# on the controller's next turn: a visible Lindwyrm (or Clay-Eaters) that can
# legally reach the preview and afford its activation spends one major action
# deleting the body outright, so summoning it is feeding, not presence.
# Destruction safety (immunity, Guardian, wards, replacement) comes from the
# curated model via CardStrategy.removal_targets; sources this plan already
# removes this turn are safe.
func _projected_opponent_removal_loss(target: Card, removed: Array = []) -> int:
	if target == null or opponent == null or game_manager == null:
		return 0
	if (target is TheChainedGhostOfAthens and target.is_activation_lock_active()) \
			or CardStrategy.has_active_clanking_chains(game_manager, bot_player, removed):
		return 0
	var budget := opponent.mana + game_manager.get_automatic_upkeep_mana_gain(opponent, game_manager.turn_number + 1) \
			+ game_manager.get_effective_upkeep_mana_gain(game_manager.get_base_upkeep_mana_gain(), opponent)
	var worst := 0
	for source in _get_board_creatures(opponent):
		if source == null or source == target or source in removed:
			continue
		if not CardStrategy.visible(self, source) \
				or CardStrategy.key(source) not in OPPONENT_ACTIVATED_REMOVAL_KEYS:
			continue
		if source.is_petrified() or source.is_face_down or source.is_stealth or source.is_prepared \
				or source.abilities_suppressed() or source.is_activation_locked(game_manager) \
				or _status_persists_to_next_turn(source, "sleep", removed):
			continue
		var activation_cost := game_manager.get_creature_action_mana_cost(source, "activate")
		if source is ClayEaters:
			activation_cost = maxi(activation_cost, ClayEaters.GEOPHAGIA_COST)
		if activation_cost > budget:
			continue
		if not _activated_removal_reaches(source, target) \
				or target not in CardStrategy.removal_targets(self, source, target):
			continue
		var loss := _get_card_economic_value(target)
		if source is Lindwyrm:
			# Devour is free growth: feeding it costs the body AND upgrades the threat.
			loss += _lindwyrm_devour_growth_value()
		worst = maxi(worst, loss)
	return worst

# Legal reach for the standing removal keys. The engine's own zone-scoped
# get_valid_targets cannot see a projected body (a preview is not a member
# of any zone's card list yet), so each key's target rule is restated here
# and must stay in sync with the card script.
func _activated_removal_reaches(source: Card, target: Card) -> bool:
	if source == null or target == null or target == source:
		return false
	if target.current_zone == null or not target.current_zone.is_board_zone():
		return false
	match CardStrategy.key(source):
		"Lindwyrm":
			return target.card_type == Card.CardType.CREATURE \
					and target.get_effective_level() <= source.get_effective_level() - 2
		"ClayEaters":
			return target.card_type == Card.CardType.STRUCTURE \
					or (target.card_type == Card.CardType.CREATURE and target.has_type("Stone"))
	return false

func _score_projected_summon_attack_loss(result: Dictionary) -> int:
	var loss := _score_follower_loss(bot_player, int(result["bot_followers_lost"])) \
		- _score_follower_loss(opponent, int(result["opponent_followers_lost"]))
	for casualty: Card in result["casualties"]:
		loss += _get_card_economic_value(casualty) * (1 if casualty.get_controller() == bot_player else -1)
	return loss

func _get_creature_attackers_next_turn(target: Card, removed: Array) -> Array[Card]:
	var attackers: Array[Card] = []
	var restriction: Dictionary = game_manager.attack_restrictions.get(opponent, {})
	if not restriction.is_empty() and restriction.get("source") not in removed:
		return attackers
	var budget := opponent.mana + game_manager.get_automatic_upkeep_mana_gain(opponent, game_manager.turn_number + 1) \
		+ game_manager.get_effective_upkeep_mana_gain(game_manager.get_base_upkeep_mana_gain(), opponent)
	var candidates := _get_board_creatures(opponent)
	# A temporarily controlled body (Siren's Song) fights for its owner again
	# the moment the borrow returns, so an aggressive frontline loan counts
	# among next turn's attackers. Its current zone is the borrower's copy of
	# the row it will return to, so the zone type carries over.
	for card in _get_board_creatures(bot_player):
		if game_manager.is_temporarily_controlled(card) and card.current_zone != null \
				and card.current_zone.zone_type == Zone.ZoneType.FRONTLINE:
			candidates.append(card)
	for attacker in candidates:
		if attacker == target or attacker in removed or (attacker.get_controller() != opponent and not game_manager.is_temporarily_controlled(attacker)) \
				or not CardStrategy.visible(self, attacker) \
				or attacker.is_petrified() or _status_persists_to_next_turn(attacker, "sleep", removed) \
				or _status_persists_to_next_turn(attacker, "cannot_attack", removed) \
				or game_manager.get_creature_action_mana_cost(attacker, "attack") > budget \
				or (target != null and not game_manager.can_cards_engage_each_other(attacker, target)):
			continue
		if attacker.current_zone in opponent.frontline_zones or game_manager.is_temporarily_controlled(attacker):
			if attacker.creature_mode != Card.CreatureMode.AGGRESSIVE and not attacker.is_stealth:
				# A defensive frontline body flips stance as a minor action and
				# still keeps its major action for the swing, so it is a real
				# next-turn attacker whenever the flip fits the budget.
				var flip_cost := game_manager.get_creature_action_mana_cost(attacker, "change stance")
				if attacker.get_max_minor_creature_actions_per_turn() < 1 \
						or game_manager.get_creature_action_mana_cost(attacker, "attack") + flip_cost > budget:
					continue
		elif not _can_advance_from_reserve_next_turn(attacker, budget, removed):
			continue
		attackers.append(attacker)
	return attackers

func _can_advance_from_reserve_next_turn(attacker: Card, mana: int, removed: Array) -> bool:
	if attacker.current_zone not in opponent.reserve_zones or _status_persists_to_next_turn(attacker, "cannot_move", removed):
		return false
	# Both action pools reset next turn. Moving (and changing stance if needed)
	# must fit in the minor actions so the attacker retains its major action.
	var moves := attacker.get_max_minor_creature_actions_per_turn()
	var available_mana := mana - game_manager.get_creature_action_mana_cost(attacker, "attack")
	if attacker.creature_mode != Card.CreatureMode.AGGRESSIVE:
		moves -= 1
		available_mana -= game_manager.get_creature_action_mana_cost(attacker, "change stance")
	var move_cost := game_manager.get_creature_action_mana_cost(attacker, "move")
	var reachable: Array[Zone] = [attacker.current_zone]
	var visited := {attacker.current_zone: true}
	for _step in range(moves):
		if available_mana < move_cost or reachable.is_empty():
			break
		available_mana -= move_cost
		var next_zones: Array[Zone] = []
		for zone in reachable:
			for destination in opponent.get_adjacent_zones(zone):
				if destination in visited or not destination.cards.all(func(card: Card) -> bool: return card in removed):
					continue
				if destination in opponent.frontline_zones:
					return true
				visited[destination] = true
				next_zones.append(destination)
		reachable = next_zones
	return false

func _score_summon_terror(creature: Card, danger: int, change: Dictionary, baseline: int) -> int:
	if not creature.has_type("Demon") or creature.abilities_suppressed_by_effects():
		return baseline
	var best := baseline
	for power in _get_player_powers():
		if not power is Terror or not power.is_effectively_active():
			continue
		for target: Card in power.get_valid_terror_targets(game_manager, creature):
			if target in change["removed"] or CardStrategy.removal_targets(self, power, target).is_empty() \
					or not game_manager.can_player_add_to_hand_now(target.card_owner) \
					or (CardStrategy.visible(self, target) and game_manager.is_immune_to_source(target, creature)):
				continue
			var projected := change.duplicate()
			projected["removed"] = change["removed"] + [target]
			var score := _follower_safety_gain(danger, projected, int(change["mana_left"]))
			best = maxi(best, score)
	return best

func _get_summon_attack_candidates(card: Card, zone: Zone, available_mana: int, stats: Dictionary = {}, removed_before_summon: Array = [], removed_before_attack: Array = [], summon_source: Fenrir = null) -> Array[Dictionary]:
	if zone.zone_type != Zone.ZoneType.FRONTLINE or game_manager.turn_number <= 1 \
			or game_manager.has_resolved_attack_this_turn or game_manager.attack_restrictions.has(bot_player) \
			or game_manager._any_active_structure_forces_defensive_summon(removed_before_summon) \
			or game_manager.is_first_turn_attack_blocked_by_weather(card, true, removed_before_attack):
		return []
	var attack_cost := game_manager.get_creature_action_mana_cost(card, "attack")
	if _get_play_cost(card, false, summon_source) + attack_cost > available_mana:
		return []
	return _get_attack_candidates(card, null, true, null, 0, null, stats, zone)

func _estimate_summon_attack_value(card: Card, zone: Zone, available_mana: int) -> int:
	var attack_cost := game_manager.get_creature_action_mana_cost(card, "attack")
	var enslave_mana := available_mana - _get_play_cost(card, false) - attack_cost
	var enslave_targets := _get_projected_violent_delights_targets(enslave_mana)
	var best_value := 0
	var removed: Array = []
	var stats := {}
	if card is Fenrir:
		var payment := _build_creature_summon_payment_plan(card, available_mana)
		var devour := _forecast_fenrir_devour(card, -1, {"removed": _summon_payment_cards(payment)})
		removed = devour.get("removed", [])
		stats = devour.get("combat_stats", {})
	elif not enslave_targets.is_empty() and card.sacrifice_cost > 0:
		removed = _summon_payment_cards(_build_creature_summon_payment_plan(card, available_mana))
	for candidate in _get_summon_attack_candidates(card, zone, available_mana, stats):
		if _is_removed_combat_card(candidate["target"], removed):
			continue
		var result := _project_attack(candidate, removed, zone)
		if result.is_empty():
			continue
		var score := _score_attack_economy(result) - attack_cost * _mana_rate()
		if not enslave_targets.is_empty():
			score += _score_violent_delights_attack(candidate, enslave_targets, removed, zone)
		best_value = maxi(best_value, score)
	# A summon can give the opponent a response window before the attack.
	return int(best_value * 0.75)

func _opponent_board_is_empty() -> bool:
	return _get_board_creatures(opponent).is_empty()


func _estimate_defensive_summon_value(card: Card, zone: Zone, stealth: bool = false, stats: Dictionary = {}, removed: Array = []) -> int:
	if card == null or zone == null or zone not in bot_player.frontline_zones + bot_player.reserve_zones:
		return 0
	if _status_persists_to_next_turn(card, "cannot_intercept"):
		return 0
	var interceptor := card
	if card.current_zone == null or not card.current_zone.is_board_zone():
		interceptor = _preview_summoned_creature(card, zone, stealth)
	var targets: Array = [bot_player]
	# Any friendly body is a candidate protected target: a face-up Defensive
	# summon can step in front of any attack for an in-range ally, and a hidden
	# or Aggressive one may still catch slower attacks. The per-attacker
	# _can_intercept gate below decides row, stance, Speed, and reach.
	for target in _get_board_creatures(bot_player):
		if target == card or target in removed:
			continue
		targets.append(target)
	var speed_delta: int = stats.get(card, Vector3i.ZERO).z
	var best_gain := 0
	for attacker in _get_board_creatures(opponent):
		if attacker in removed or not CardStrategy.visible(self, attacker) or attacker.current_zone.zone_type != Zone.ZoneType.FRONTLINE \
				or attacker.creature_mode != Card.CreatureMode.AGGRESSIVE \
				or attacker.has_status_effect("cannot_attack") \
				or not game_manager.can_cards_engage_each_other(card, attacker) \
				or not game_manager.can_interceptor_engage_attacker(card, attacker):
			continue
		var projected_speed := attacker.get_effective_speed() + _opponent_hermes_speed_gain(attacker)
		var partner := match_manager._get_declared_attack_partner(attacker)
		if partner in removed:
			partner = null
		if partner != null:
			if not CardStrategy.visible(self, partner):
				continue
			projected_speed = mini(projected_speed, partner.get_effective_speed() + _opponent_hermes_speed_gain(partner))
		var action := CardAction.new()
		action.type = CardAction.Type.ATTACK
		action.attacker = attacker
		action.united_front_partner = partner
		var allies := [partner] if partner != null else []
		for target in targets:
			if not match_manager._can_intercept(interceptor, attacker, target, interceptor, speed_delta, projected_speed, zone, Card.CreatureMode.DEFENSIVE):
				continue
			if target is Player:
				if game_manager.is_followers_attack_blocked_by_active_structure(attacker, bot_player, allies):
					continue
			elif not game_manager.can_cards_engage_each_other(attacker, target, false) \
					or game_manager.is_attack_blocked_by_active_structure(attacker, target, allies):
				continue
			action.target = target
			action.interceptor = null
			var best_existing_score := _score_attack_economy(_estimate_projected_attack_economy(action, stats))
			for existing in match_manager._get_possible_interceptors(attacker, target, projected_speed):
				if existing == card or existing in removed:
					continue
				action.interceptor = existing
				best_existing_score = maxi(best_existing_score, _score_attack_economy(_estimate_projected_attack_economy(action, stats)))
			action.interceptor = card
			var result := _estimate_projected_attack_economy(action, stats, true, Card.CreatureMode.DEFENSIVE, stealth)
			best_gain = maxi(best_gain, _score_attack_economy(result) - best_existing_score)
	return best_gain

func _is_enemy_creature_answer(card: Card, target: Card, score: int) -> bool:
	if card == null or target == null or score <= 0 or target.get_controller() != opponent:
		return false
	if target.card_type != Card.CardType.CREATURE:
		return false
	return CardStrategy.key(card) in [
		"DivineLightning", "RunicSpellbreaker", "BitMeseri", "ClayEaters", "Alu", "Nimue",
		"Dromi", "Gleipnir", "Snowball", "SapStrength", "VisionOfTartarus", "Absence",
		"Sap", "SepLemutti", "Lindwyrm", "GungnirTheSpearOfOdin", "FairyBlast",
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
	# A known entry answer (a revealed Sap) destroys Askelladen as it enters,
	# so the problem creature stays unanswered and the body is wasted.
	if _known_entry_response_penalty(askelladen, zone, false) > 0:
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

func _get_best_strategy_action(attacks: Array[Dictionary], attack: Dictionary, danger: int = -1, removals: Array[Dictionary] = []) -> Dictionary:
	var best_plan: Dictionary = {}
	var ward_plan := _plan_namburbi_ward(attacks, attack)
	if _is_better_strategy_plan(ward_plan, best_plan):
		best_plan = ward_plan
	var cards: Array = bot_player.hand_zone.cards.duplicate()
	cards.append_array(game_manager.get_field_cards(bot_player))
	for card in cards:
		if not game_manager.get_creature_ability_activation_block_reason(card).is_empty():
			continue
		if card is NamburbiApotropaeon:
			# Planned above; effect_score with no stack action intentionally
			# does not value a self-only ward.
			continue
		if card is HildskjalfThroneOfOdin or card is AnointingStatue or card is Gambanteinn \
				or card is ShroudOfTheAncients or card is ApollyonsDemiurge:
			var reading := _plan_special_card(card, attacks, attack, danger)
			if _is_better_strategy_plan(reading, best_plan):
				best_plan = reading
			continue
		if card is E2Abzu:
			var abzu_plan := _plan_e2_abzu_return(card as E2Abzu)
			if _is_better_strategy_plan(abzu_plan, best_plan):
				best_plan = abzu_plan
			continue
		if card is BlotSacrifice or card is KeyOfSolomon:
			var paid_plan := _plan_sacrifice_spell(card, danger)
			if _is_better_strategy_plan(paid_plan, best_plan):
				best_plan = paid_plan
			continue
		if card is DeucalionsInfants:
			var infants_plan := _plan_deucalions_infants(card, danger)
			if _is_better_strategy_plan(infants_plan, best_plan):
				best_plan = infants_plan
			continue
		if CardStrategy.key(card) == "TheChangelingExchange":
			var changeling_plan := _plan_changeling_exchange(card, danger)
			if _is_better_strategy_plan(changeling_plan, best_plan):
				best_plan = changeling_plan
			continue
		if card is CompelledByTheSecretName:
			var secret_name_plan := _plan_compelled_secret_name(card as CompelledByTheSecretName)
			if _is_better_strategy_plan(secret_name_plan, best_plan):
				best_plan = secret_name_plan
			continue
		if card is KurJara:
			# Tree of Life is planned on its own: a proactive resurrection
			# cycle, plus a withdrawal dodge that still returns its value.
			var kur_jara_plan := _plan_kur_jara_tree_of_life(card as KurJara, danger)
			if _is_better_strategy_plan(kur_jara_plan, best_plan):
				best_plan = kur_jara_plan
			continue
		if card is ErlqueensNightingale or card is TezcatlipocaBlasphemer:
			var withdrawal := _plan_board_withdrawal(card, danger)
			if _is_better_strategy_plan(withdrawal, best_plan):
				best_plan = withdrawal
			continue
		if CardStrategy.supported(card) and (card is SpellCard or card is CharmCard):
			if card.discard_cost > 0 or card.sacrifice_cost > 0:
				continue
			# A ready Mead funds casts the current stock cannot pay yet: the
			# lend check below only relaxes the mana gate, and short-funded
			# plans are wrapped so the brew is submitted first.
			var cast_cost := CardStrategy.activation_cost(self, card)
			var brew_short := bot_player.mana < cast_cost
			var cast_budget := bot_player.mana + (_ready_brew_mana_gain() if brew_short else 0)
			var cast_check: Callable
			if card is SpellCard:
				if card.is_prepared:
					cast_check = func() -> bool: return card.can_activate_prepared(game_manager, bot_player)
				else:
					cast_check = func() -> bool: return game_manager.can_play_card(bot_player, card, null)
			elif card.is_prepared:
				cast_check = func() -> bool: return card.can_activate_prepared(game_manager)
			else:
				cast_check = func() -> bool: return card.can_activate_from_hand(game_manager)
			if not cast_check.call() and not (brew_short and _passes_after_brew(cast_check)):
				continue
			if card is ConjureEidolon:
				var eidolon_plan := _plan_conjure_eidolon(card, attacks, attack, danger)
				if _is_better_strategy_plan(eidolon_plan, best_plan):
					best_plan = eidolon_plan
				continue
			var targets := CardStrategy.targets(self, card)
			if targets.is_empty() and not card.targets:
				targets = [null]
			var reserve := _get_first_open_reserve_zone(bot_player)
			if card is WildMagic and reserve == null:
				reserve = _get_first_open_summon_zone(bot_player)
			if not card.goes_to_graveyard_after_use() and not card.is_prepared and reserve == null:
				continue
			for target: Card in targets:
				if not game_manager.get_turn_destruction_ward_activation_block_reason(card, target).is_empty():
					continue
				var score := CardStrategy.effect_score(self, card, target)
				# Immortal Techniques refunds the cast while a friendly Mage
				# is fielded: the effective cost drops by one, and the +1 is
				# already banked for follow-ups planned later this turn.
				var refund_gain := _immortal_techniques_refund_gain(card)
				if refund_gain > 0:
					score += CardStrategy.mana_gain_value(self, refund_gain)
				if score <= CardStrategy.BAD:
					continue
				var removed := CardStrategy.removal_targets(self, card, target)
				var command := {"type": "cast_spell" if card is SpellCard else "cast_charm", "target_uid": target.uid if target != null else "", "prepared": card.is_prepared}
				command["spell_uid" if card is SpellCard else "charm_uid"] = card.uid
				if (not card.goes_to_graveyard_after_use() or card is WildMagic) and not card.is_prepared and reserve != null:
					command["display_zone"] = {"player_index": player_index, "zone_type": reserve.zone_type, "zone_index": reserve.zone_index}
				var plan := {"command": command, "score": score, "mana_refund": refund_gain}
				if CardStrategy.key(card) in MUMMU_SHELVE_WIPE_KEYS:
					# The sweep kills own cards too: tag the wipe so the shelf
					# setup submits before the cast (see _submit_strategy_plan).
					for victim: Card in removed:
						if victim.get_controller() == bot_player and _mummu_wipe_shelve_credit(victim) > 0:
							plan["mummu_shelve_setup"] = card.uid
							break
				if brew_short:
					# The stock cannot pay this cast yet: tag it so the
					# brew is submitted first and the next pass replays the
					# cast on the grown stock.
					plan["brew_setup"] = true
				if removed.is_empty():
					if _is_enemy_creature_answer(card, target, score):
						@warning_ignore("integer_division")
						plan["score"] += 6500 + _score_follower_loss(opponent, target.get_effective_strength()) / 4
					plan["score"] += _effect_follower_safety_gain(card, target, danger, cast_budget - cast_cost + refund_gain)
				else:
					# Persistent cards can occupy the lane needed by the projected summon.
					var cost := CardStrategy.activation_cost(self, card)
					plan["score"] -= _single_creature_removal_discount(card, removed)
					if card.goes_to_graveyard_after_use():
						_record_targeted_removal(removals, plan, card, target, removed, cost)
					plan = _plan_removal_setup(plan, attacks, attack, danger, removed, cost, null, card.goes_to_graveyard_after_use())
				if _is_better_strategy_plan(plan, best_plan):
					best_plan = plan
		elif CardStrategy.key(card) in CardStrategy.BOARD_ABILITIES and card.current_zone != bot_player.hand_zone:
			if card.is_face_down or card.is_prepared or card.abilities_suppressed() or card.is_activation_locked(game_manager) \
					or (not card.can_activate(game_manager) and not _can_activate_after_brew(card)):
				continue
			var id := CardStrategy.key(card)
			var action_tax := game_manager.get_creature_action_mana_cost(card, "activate") if card is CreatureCard else 0
			if card is Berserker:
				# Rage is a combat buff with a sleep cost; only flip a fight
				# with it (the attack planner sees the live buff afterwards).
				var rage_gain := CardStrategy.combat_gain(self, card, Berserker.RAGE_STR_BONUS, 0, null, 0, 0)
				var rage_score := rage_gain - 1500
				rage_score -= CardStrategy.mana_penalty(self, Berserker.RAGE_ACTIVATION_COST) + action_tax * _mana_rate()
				if rage_score > 0:
					var rage_plan := {
						"command": {"type": "activate_card_ability", "source_uid": card.uid},
						"score": rage_score,
						"combat_score": int(attack.get("score", 0)) + rage_gain,
						"combined_setup": true,
					}
					if _is_better_strategy_plan(rage_plan, best_plan):
						best_plan = rage_plan
				continue
			if card is EnHeduAnna:
				# Exaltation is available only when the god's power activated
				# while she was face-up (can_activate gates that); it buys a
				# stat boost plus a round of immunity from combat and targeting.
				var exalt_option: Dictionary = card.get_exaltation_options()[0]
				if card.creature_mode == Card.CreatureMode.AGGRESSIVE:
					exalt_option = card.get_exaltation_options()[1]
				@warning_ignore("integer_division")
				var exalt_score := 1200 + _estimate_targeted_casualty_cost(card, card, {}) / 2
				exalt_score -= action_tax * _mana_rate()
				if exalt_score > 0:
					var exalt_plan := {"command": {"type": "activate_card_ability", "source_uid": card.uid, "option": exalt_option}, "score": exalt_score}
					if _is_better_strategy_plan(exalt_plan, best_plan):
						best_plan = exalt_plan
				continue
			if card is Mopsus:
				# Seer reveals feed the known-response model for the rest of
				# the game; modest flat value per hidden enemy hand card.
				var hidden_hand_cards: Array[Card] = []
				for hand_card in card.get_valid_targets(game_manager):
					if not CardStrategy.visible(self, hand_card):
						hidden_hand_cards.append(hand_card)
				# Seer demands exactly get_required_seer_target_count picks or
				# it fizzles, so size the selection from that count.
				var required_reveals: int = card.get_required_seer_target_count(game_manager)
				if required_reveals > 0 and required_reveals <= hidden_hand_cards.size():
					var reveal_uids: Array[String] = []
					for hand_card in hidden_hand_cards.slice(0, required_reveals):
						reveal_uids.append(hand_card.uid)
					var seer_score := 400 * reveal_uids.size() - action_tax * _mana_rate()
					if seer_score > 0:
						var seer_plan := {"command": {"type": "activate_card_ability", "source_uid": card.uid, "option": {"target_uids": reveal_uids}}, "score": seer_score}
						if _is_better_strategy_plan(seer_plan, best_plan):
							best_plan = seer_plan
				continue
			if card is WingedLion:
				var flank := _plan_winged_lion_flank(card, action_tax)
				if _is_better_strategy_plan(flank, best_plan):
					best_plan = flank
				continue
			var targets := [null] if id == "Beyla" else CardStrategy.targets(self, card)
			# The brew budget: a ready Mead funds activations the current
			# stock cannot pay yet, and the wrap below submits the brew first
			# so the paid action lands on the next pass.
			var brew_budget := bot_player.mana + _ready_brew_mana_gain()
			for target: Card in targets:
				var score := CardStrategy.wake_gain(self, card) if id == "Beyla" else CardStrategy.target_score(self, card, target)
				if score <= CardStrategy.BAD:
					continue
				var cost := 1 if id == "ClayEaters" else 2 if id in ["AncientPyre", "Gawain", "Beyla", "SeventhSageUtuabzu"] else 0
				if id == "Nimue" and target != null and target.card_type == Card.CardType.CREATURE:
					cost = target.get_effective_level()
				if brew_budget < cost + action_tax:
					continue
				score -= CardStrategy.mana_penalty(self, cost) + action_tax * _mana_rate()
				# Geophagia resolves at end of turn, after the attacks it could clear.
				var removed := [] if card is ClayEaters else CardStrategy.removal_targets(self, card, target)
				var plan := {
					"command": {"type": "activate_card_ability", "source_uid": card.uid, "target_uid": target.uid if target != null else ""},
					"score": score,
				}
				if bot_player.mana < cost + action_tax:
					# The brew funds this activation: tag it so the Mead is
					# submitted first and the next pass takes the paid action.
					plan["brew_setup"] = true
				if not removed.is_empty():
					var committed := card as Card if card is Lindwyrm or card is Nimue else null
					if card is Lindwyrm:
						plan["score"] += _lindwyrm_devour_growth_value()
					_record_targeted_removal(removals, plan, card, target, removed, cost + action_tax, committed)
					plan = _plan_removal_setup(plan, attacks, attack, danger, removed, cost + action_tax, committed)
				else:
					if id in ["Alu", "Lindwyrm", "Nimue"]:
						plan["score"] -= _score_follower_loss(opponent, card.get_effective_strength())
					var activation_budget := brew_budget if plan.get("brew_setup", false) else bot_player.mana
					plan["score"] += _effect_follower_safety_gain(card, target, danger, activation_budget - cost - action_tax)
				if card is HariiShaman and target != null and target.has_type("Warrior") and not target.has_type("Animal"):
					# Transforming a Warrior into an Animal needs the chosen
					# subtype; Lupine is the support type Hunting Tactics reads.
					plan["command"]["option"] = {"target_uid": target.uid, "animal_subtype": "Lupine"}
				if _is_better_strategy_plan(plan, best_plan):
					best_plan = plan
			if id == "AncientPyre" and game_manager.can_player_lose_followers_now(opponent):
				var conversion := {"command": {"type": "activate_card_ability", "source_uid": card.uid, "option": {"mode": "convert"}}, "score": _ancient_pyre_conversion_score()}
				if AncientPyre.EFFECT_AMOUNT >= opponent.followers:
					# The conversion empties the opponent's follower stock:
					# carry the lethal flag so the line outranks every other
					# plan instead of losing the close score race.
					conversion["lethal"] = true
				if bot_player.mana < AncientPyre.ACTIVATION_COST + action_tax:
					# Short stock: the brew funds the clock. Tag it so the
					# Mead is submitted first and the next pass converts on
					# the grown stock.
					conversion["brew_setup"] = true
				if _is_better_strategy_plan(conversion, best_plan):
					best_plan = conversion
	return best_plan

func _ancient_pyre_conversion_score() -> int:
	var score := _score_follower_loss(opponent, AncientPyre.EFFECT_AMOUNT) \
			+ CardStrategy.follower_gain(bot_player, AncientPyre.EFFECT_AMOUNT) \
			- CardStrategy.mana_penalty(self, AncientPyre.ACTIVATION_COST)
	if _locked_board_state():
		# Convert provides a win condition when neither side can push attacks through.
		@warning_ignore("integer_division")
		score += ECON_CARD_VALUE * 20 * AncientPyre.EFFECT_AMOUNT / maxi(1, opponent.followers)
	return score

func _record_targeted_removal(options: Array[Dictionary], plan: Dictionary, source: Card, target: Card, removed: Array, cost: int, committed: Card = null, reserved: Array = []) -> void:
	# Only compose immediate, fixed-target effects. A sweep or delayed
	# destruction has to be evaluated on the board where it actually resolves.
	if target == null or target.get_controller() != opponent or not CardStrategy.visible(self, target) \
			or removed.size() != 1 or removed[0] != target \
			or not game_manager.get_turn_destruction_ward_activation_block_reason(source, target).is_empty():
		return
	options.append({
		"source": source, "target": target, "cost": cost, "committed": committed, "reserved": reserved,
		"plan": plan,
	})

func _plan_paired_removals(options: Array[Dictionary], attacks: Array[Dictionary], baseline: Dictionary, danger: int) -> Dictionary:
	if options.size() < 2 or attacks.is_empty():
		return {}
	var follower_attacks := attacks.filter(func(attack: Dictionary) -> bool: return attack["target"] is Player)
	var brew := _ready_brew_mana_gain()
	var projections := {}
	for i in range(options.size()):
		var first := options[i]
		for j in range(i + 1, options.size()):
			var second := options[j]
			if first["target"] == second["target"]:
				continue
			var first_plan: Dictionary = first["plan"]
			var second_plan: Dictionary = second["plan"]
			var first_cost := int(first["cost"])
			var second_cost := int(second["cost"])
			var first_refund := int(first_plan.get("mana_refund", 0))
			var second_refund := int(second_plan.get("mana_refund", 0))
			var first_required := maxi(first_cost, first_cost - first_refund + second_cost)
			var second_required := maxi(second_cost, second_cost - second_refund + first_cost)
			var starts_with_second := second_required < first_required \
				or (second_required == first_required and _is_better_strategy_plan(second_plan, first_plan))
			var required := second_required if starts_with_second else first_required
			if required > bot_player.mana + brew:
				continue
			var mana := first_cost + second_cost - first_refund - second_refund
			var uses_brew := required > bot_player.mana
			var projected_mana := bot_player.mana + (brew if uses_brew else 0)
			var source := first["source"] as Card
			if source == second["source"] and not (source is AncientPyre and source.uses_this_turn + 2 <= AncientPyre.USES_PER_TURN):
				continue
			var first_payment: Array = first["reserved"]
			var second_payment: Array = second["reserved"]
			if source in second_payment or second["source"] in first_payment \
					or first_payment.any(func(card: Card) -> bool: return card in second_payment):
				continue
			var removed: Array[Card] = [first["target"], second["target"]]
			var committed: Array[Card] = []
			for option in [first, second]:
				if option["committed"] != null:
					committed.append(option["committed"])
			var score := int(first["plan"]["score"]) + int(second["plan"]["score"])
			var victims := removed.map(func(card: Card) -> int: return card.get_instance_id())
			victims.sort()
			var spent := committed.map(func(card: Card) -> int: return card.get_instance_id())
			spent.sort()
			var key := str([victims, spent, projected_mana - mana, uses_brew])
			if projections.has(key) and score <= int(projections[key]["score"]):
				continue
			var opening_plan := second_plan if starts_with_second else first_plan
			projections[key] = {
				"plan": opening_plan.merged({"brew_setup": uses_brew}, true), "score": score, "removed": removed, "committed": committed, "mana": mana,
				"projected_mana": projected_mana,
			}
	var pairs := projections.values()
	if pairs.size() > COMBAT_REMOVAL_SEARCH_WIDTH:
		# Rank by possible direct damage as well as removal value before
		# spending the full combat search on the most promising combinations.
		for pair in pairs:
			var damage := 0
			for attack in follower_attacks:
				if attack["attacker"] in pair["committed"] or attack["partner"] in pair["committed"] \
						or int(attack["mana_cost"]) + int(pair["mana"]) > int(pair["projected_mana"]) \
						or _attack_has_remaining_barrier(attack, pair["removed"]) \
						or _has_projected_attack_reply(attack, pair["removed"]):
					continue
				damage += int(attack["base"].get("opponent_damage_before_guard", 0))
			pair["rank"] = int(pair["score"]) + _score_follower_loss(opponent, maxi(0, damage - opponent.guard))
		pairs.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return int(a["rank"]) > int(b["rank"]))
		pairs.resize(COMBAT_REMOVAL_SEARCH_WIDTH)
	var best := {}
	for pair in pairs:
		var opened := _plan_combat(attacks, pair["removed"], null, pair["mana"], null, int(pair["projected_mana"]), pair["committed"])
		var combat_score := int(opened.get("score", 0))
		var gain := int(pair["score"]) + combat_score - int(baseline.get("score", 0)) \
			+ _follower_safety_gain(danger, {"removed": pair["removed"]}, int(pair["projected_mana"]) - int(pair["mana"]))
		var plan: Dictionary = pair["plan"].merged({
			"score": gain, "combat_score": combat_score, "lethal": bool(opened.get("lethal", false)),
			"combined_setup": true,
		}, true)
		if _is_better_strategy_plan(plan, best):
			best = plan
	return best

func _plan_removal_setup(plan: Dictionary, attacks: Array[Dictionary], baseline: Dictionary, danger: int, removed: Array, cost: int, committed: Card = null, can_pair: bool = true, reserved_cards: Array = []) -> Dictionary:
	# A brew-funded removal submits the brew first, so the combat it opens is
	# priced against the grown stock the paid follow-up actually spends from.
	var projected_mana := bot_player.mana + (_ready_brew_mana_gain() if bool(plan.get("brew_setup", false)) else 0)
	var net_cost := cost - int(plan.get("mana_refund", 0))
	var opened := _plan_combat(attacks, removed, committed, net_cost, null, projected_mana)
	var combat_score := int(opened.get("score", 0))
	var unlock_value := combat_score - int(baseline.get("score", 0))
	if unlock_value > 0 and game_manager.is_player_under_god_death(bot_player) \
			and removed.any(func(victim: Card) -> bool: return victim != null and victim.get_controller() == opponent):
		# Under the god-death clock no amount of blocking stops the bleed, so
		# the enemy body's defensive presence buys the opponent nothing real.
		# Unlocking the push is the only plan that changes the clock; price
		# the unlocked combat above its raw one-turn worth instead of letting
		# it sit behind marginal lines while 7 followers burn every upkeep.
		unlock_value *= GOD_DEATH_UNLOCK_URGENCY
	var best := plan.merged({
		"score": int(plan["score"]) + unlock_value + _follower_safety_gain(danger, {"removed": removed}, projected_mana - net_cost),
		"combat_score": combat_score, "lethal": bool(opened.get("lethal", false)),
	}, true)
	if not can_pair or best["lethal"] or game_manager.has_resolved_attack_this_turn \
			or not removed.any(func(victim: Card) -> bool: return victim.get_controller() == opponent):
		return best
	# Most fixed-target actions commute with an ordinary summon. When the
	# recruit has an order-dependent Devour, forecast both states. Sweeps
	# are evaluated first because the extra body could change their targets.
	var orders := [false]
	if removed.size() == 1 and not str(plan["command"].get("target_uid", "")).is_empty() \
			and int(plan.get("mana_refund", 0)) == 0 \
			and bot_player.hand_zone.cards.any(func(card: Card) -> bool: return card is Fenrir):
		orders.append(true)
	for summon_first in orders:
		var summon := _plan_creature_summon(danger, attacks, baseline, removed, net_cost, {
			"committed": committed, "reserved_cards": reserved_cards, "summon_first": summon_first,
			"brew_setup": plan.get("brew_setup", false),
		})
		var attack_setup: Dictionary = summon.get("attack_setup", {})
		if _is_better_strategy_plan(attack_setup, summon):
			summon = attack_setup
		if summon.is_empty():
			continue
		var combined := plan.merged({
			"command": summon["command"] if summon_first else plan["command"],
			"brew_setup": plan.get("brew_setup", false) or summon.get("brew_setup", false),
			"score": int(plan["score"]) + int(summon["score"]), "combat_score": int(summon["combat_score"]),
			"lethal": bool(summon.get("lethal", false)), "combined_setup": true,
		}, true)
		if summon_first:
			combined.erase("once_per_turn_uid")
		if _is_better_strategy_plan(combined, best):
			best = combined
	return best

func _lindwyrm_devour_growth_value() -> int:
	return Lindwyrm.DEVOUR_STRENGTH_BONUS * 100 + Lindwyrm.DEVOUR_RESILIENCE_BONUS * 50

func _plan_summoned_removal_ability(attacks: Array[Dictionary], baseline: Dictionary, danger: int) -> Dictionary:
	var best := {}
	var zones: Array[Zone] = []
	var front := _get_central_open_zone(bot_player.frontline_zones)
	var reserve := _get_first_open_reserve_zone(bot_player)
	if front != null:
		zones.append(front)
	if reserve != null:
		zones.append(reserve)
	for creature in bot_player.hand_zone.cards:
		if not (creature is Lindwyrm or creature is Nimue):
			continue
		if not game_manager.get_creature_ability_activation_block_reason(creature).is_empty():
			continue
		var summon_cost := _get_play_cost(creature, false)
		var activation_tax := game_manager.get_creature_action_mana_cost(creature, "activate")
		for zone in zones:
			var body_value := _score_creature_play_in_zone(creature, zone, bot_player.mana, false)
			if body_value <= CardStrategy.BAD:
				continue
			var source := _preview_board_creature(creature, zone)
			source.creature_mode = Card.CreatureMode.DEFENSIVE
			source.is_face_down = false
			source.is_stealth = false
			if not source.can_activate(game_manager):
				continue
			for target in CardStrategy.targets(self, source):
				if target.get_controller() != opponent or not CardStrategy.visible(self, target):
					continue
				var removed := CardStrategy.removal_targets(self, source, target)
				var activation_cost: int = target.get_effective_level() if source is Nimue else 0
				var total_cost := summon_cost + activation_cost + activation_tax
				if removed.is_empty() or total_cost > bot_player.mana:
					continue
				var mana_after_ability := bot_player.mana - activation_cost - activation_tax
				var command := _build_creature_play_command(creature, zone, Card.CreatureMode.DEFENSIVE, danger, true, mana_after_ability)
				if command.is_empty():
					continue
				command["stealth"] = false
				command.erase("payment_penalty")
				var sacrifices := _summon_payment_cards(command)
				if _get_known_entry_responses(creature, zone, false, sacrifices).any(
					func(reply: Dictionary) -> bool: return creature in reply["victims"]
				):
					continue
				var removal_score := CardStrategy.target_score(self, source, target)
				if removal_score <= CardStrategy.BAD:
					continue
				if source is Lindwyrm:
					removal_score += _lindwyrm_devour_growth_value()
				removed += sacrifices
				# The recruit spends its major action on removal, leaving the
				# creatures already on board to take the attacks.
				var opened := _plan_combat(attacks, removed, null, total_cost, zone, -1, [], creature)
				var lethal := bool(opened.get("lethal", false))
				var combat_score := int(opened.get("score", 0))
				var score := body_value + removal_score - CardStrategy.mana_penalty(self, activation_cost + activation_tax) \
					+ combat_score - int(baseline.get("score", 0))
				var mana_left := bot_player.mana - total_cost
				score += _follower_safety_gain(danger, {
					"removed": removed, "summon": creature, "zone": zone, "stance": creature, "defensive": true,
				}, mana_left)
				if not lethal:
					score -= _estimate_projected_summon_casualty_cost(creature, zone, true, removed + opened.get("cleared", []), {}, false, mana_left)
				var plan := {
					"command": command, "score": score, "combat_score": combat_score,
					"lethal": lethal, "combined_setup": true,
				}
				if _is_better_strategy_plan(plan, best):
					best = plan
	return best

func _score_e2_abzu_build(abzu: E2Abzu, excluded: Array) -> int:
	var zone := _get_first_open_reserve_zone(bot_player)
	if zone == null or abzu.abilities_suppressed_by_effects() or abzu.is_activation_locked(game_manager):
		return 0
	for card in game_manager.get_field_cards(bot_player, false):
		if card is E2Abzu and card.current_zone.is_board_zone() and card not in excluded \
				and card.card_owner == bot_player and not card.abilities_suppressed() \
				and not card.is_activation_locked(game_manager):
			return 0
	var mana := bot_player.mana - _get_play_cost(abzu, false)
	return _score_e2_abzu_use(abzu, mana, _get_first_open_summon_zone(bot_player, zone), excluded)

func _score_e2_abzu_use(abzu: E2Abzu, mana: int, summon_zone: Zone, excluded: Array = []) -> int:
	var best := 0
	if game_manager.can_player_add_to_hand_now(bot_player):
		var mana_after_return := mana - E2Abzu.RETURN_TO_HAND_COST
		for mage in abzu.get_valid_void_targets(game_manager):
			if mage not in excluded and mage.get_effective_level() < mana_after_return:
				best = maxi(best, _score_e2_abzu_return(mage, mana_after_return, summon_zone))
	if best > 0 or mana - _incoming_mana_drain() < E2Abzu.VOID_AND_RETURN_COST:
		return best
	# Walk of the Sage can put its target in the Void before we build.
	# Build for protection only when a Mer Mage faces an attack Abzu can dodge.
	for mage in abzu.get_valid_field_targets(game_manager):
		if mage in excluded or mage.get_controller() != bot_player:
			continue
		for attacker in _get_creature_attackers_next_turn(mage, excluded):
			if attacker.get_effective_speed() > E2Abzu.VOID_RESPONSE_SPEED:
				continue
			var attack := CardAction.new()
			attack.type = CardAction.Type.ATTACK
			attack.attacker = attacker
			attack.target = mage
			attack.source_player = opponent
			var dodge := _score_e2_abzu_dodge(abzu, mage, attack)
			best = maxi(best, int(dodge * CardStrategy.LINE_CONTINUATION_SHARE))
	return best

func _plan_e2_abzu_return(abzu: E2Abzu) -> Dictionary:
	if abzu == null or abzu.current_zone == null or not abzu.current_zone.is_board_zone() \
			or not abzu.can_activate(game_manager) or not game_manager.can_player_add_to_hand_now(bot_player):
		return {}
	var best_plan: Dictionary = {}
	var best_score := 0
	var mana_after_return := bot_player.mana - E2Abzu.RETURN_TO_HAND_COST
	var summon_zone := _get_first_open_summon_zone(bot_player)
	for mage: Card in abzu.get_valid_void_targets(game_manager):
		var score := _score_e2_abzu_return(mage, mana_after_return, summon_zone)
		if score <= best_score:
			continue
		best_score = score
		best_plan = {
			"score": score,
			"command": {
				"type": "activate_card_ability",
				"source_uid": abzu.uid,
				"target_uid": mage.uid,
			},
		}
	return best_plan

func _score_e2_abzu_return(mage: Card, mana_after_return: int, summon_zone: Zone) -> int:
	var summon_live := summon_zone != null \
			and _score_creature_play_in_zone(mage, summon_zone, mana_after_return) > 0
	var score := _get_hand_value(mage) * 100 - E2Abzu.RETURN_TO_HAND_COST * _mana_rate()
	return score + (2500 if summon_live else 0) + _sage_retrieval_impact_gain(mage, summon_live)

# A retrieved Sage is bought for its impact, not its body: the summon fires
# Silence, Good Fortune, Search, or a channeled replay, so the E2-abzu return
# line is priced through the same impact table the Seventh Sage's Channel Ally
# uses. Conjure Home stays out on purpose — the Sixth Sage only pays while it
# stands on the field, and the live summon score already carries that trade
# through its own trigger bonus.
func _sage_retrieval_impact_gain(mage: Card, summon_live: bool) -> int:
	if mage == null or not mage.has_type("Sage") or str(mage.culture).strip_edges() != "Ancient" \
			or not mage.declares_impact_trigger() or mage.abilities_suppressed_by_effects():
		return 0
	if mage is FirstSageAdapa or mage is ThirdSageEnmedugga:
		# Silence and Good Fortune both fizzle without a legal target, so a
		# retrieval planned around them needs the target pool right now.
		if mage.get_valid_targets(game_manager).is_empty():
			return 0
	if mage is SeventhSageUtuabzu and mage.get_channel_ally_targets(game_manager).is_empty():
		# The channel replay needs another allied Sage to exist at all.
		return 0
	var gain := CardStrategy.seventh_sage_channel_gain(self, mage)
	if gain <= 0:
		return 0
	if summon_live:
		return gain
	# The summon cannot go this turn (the summon is spent, no lane is open, or
	# the retrieval leaves the stock short), so the impact waits a turn and the
	# continuation line is priced at the standard discounted share.
	return int(float(gain) * CardStrategy.LINE_CONTINUATION_SHARE)

func _effect_follower_safety_gain(card: Card, target: Card, danger: int, mana_left: int) -> int:
	if danger < 0:
		return 0
	var removed := CardStrategy.removal_targets(self, card, target)
	if not removed.is_empty():
		return _follower_safety_gain(danger, {"removed": removed}, mana_left)
	match CardStrategy.key(card):
		"Alu":
			if target != null and CardStrategy.adds_attack_lock_next_turn(self, target):
				return _follower_safety_gain(danger, {"disable_attacker": target}, mana_left)
		"BookOfLife":
			var change := {"followers": bot_player.followers + BookOfLife.FOLLOWERS_GAINED}
			var zone := _get_first_open_summon_zone(bot_player)
			if target != null and zone != null:
				change.merge({"summon": target, "zone": zone, "stance": target, "defensive": false})
			return _follower_safety_gain(danger, change, mana_left, false)
		"TabletOfLife":
			if target != null and target.get_effective_level() < 3:
				var zone := (card as TabletOfLife)._get_best_summon_zone(target)
				if zone != null:
					return _follower_safety_gain(danger, {"summon": target, "zone": zone, "stance": target, "defensive": false}, mana_left)
	return 0

func _plan_conjure_eidolon(spell: ConjureEidolon, attacks: Array[Dictionary], baseline: Dictionary, danger: int) -> Dictionary:
	var best := {}
	var zone := spell.get_open_summon_zone()
	if zone == null:
		return best
	var cast_cost := CardStrategy.activation_cost(self, spell)
	var mana_budget := bot_player.mana + _ready_brew_mana_gain()
	var defensive := game_manager._any_active_structure_forces_defensive_summon()
	var can_attack_now := not defensive and zone in bot_player.frontline_zones and game_manager.turn_number > 1 \
		and not game_manager.has_resolved_attack_this_turn and not game_manager.attack_restrictions.has(bot_player)
	var baseline_score := int(baseline.get("score", 0))
	var refund := _immortal_techniques_refund_gain(spell)
	for target in spell.get_valid_targets(game_manager):
		var eidolon := spell.create_eidolon(target)
		var summon_cost := game_manager.get_creature_summon_mana_cost(bot_player, eidolon, spell, true)
		var cost := cast_cost + summon_cost
		if cost > mana_budget:
			continue
		var brew_first := _brew_enables_spend(cost)
		var funded_mana := mana_budget if brew_first else mini(mana_budget, bot_player.mana)
		var body_gain := CardStrategy.value(self, eidolon) + _follower_safety_gain(danger, {
			"summon": eidolon, "zone": zone, "defensive_summons": defensive,
		}, funded_mana - cost + refund)
		var combat := {}
		if can_attack_now and not game_manager.is_first_turn_attack_blocked_by_weather(eidolon, true):
			var eidolon_attacks := _get_attack_candidates(eidolon, null, true, null, 0, null, {}, zone)
			combat = _plan_combat(attacks + eidolon_attacks, [], null, cost - refund, zone, funded_mana, [], eidolon)
		var combat_score := int(combat.get("score", 0))
		# Attacking spends the token. Keeping it for defense and using it now are alternative payoffs.
		var score := maxi(body_gain, combat_score - baseline_score) - ECON_CARD_VALUE \
			- CardStrategy.mana_penalty(self, cost, mana_budget) + CardStrategy.mana_gain_value(self, refund)
		var plan := {
			"score": score, "combat_score": combat_score, "lethal": bool(combat.get("lethal", false)),
			"brew_setup": brew_first,
			"command": {"type": "cast_spell", "spell_uid": spell.uid, "target_uid": target.uid, "prepared": spell.is_prepared},
		}
		if _is_better_strategy_plan(plan, best):
			best = plan
	return best

func _plan_compelled_secret_name(charm: CompelledByTheSecretName) -> Dictionary:
	# The declaration rides on public information only (see
	# CardStrategy.best_compelled_secret_declaration): with nothing revealed,
	# the cast is a plain card loss and the charm is held.
	if charm == null or charm.card_owner != bot_player or charm.is_muted:
		return {}
	var cast_check: Callable
	if charm.is_prepared:
		if charm.current_zone == null or not charm.current_zone.is_board_zone():
			return {}
		cast_check = func() -> bool: return charm.can_activate_prepared(game_manager)
	else:
		if charm.current_zone != bot_player.hand_zone:
			return {}
		cast_check = func() -> bool: return charm.can_activate_from_hand(game_manager)
	if not cast_check.call():
		return {}
	var declaration := CardStrategy.best_compelled_secret_declaration(self)
	if declaration.is_empty():
		return {}
	var cast_cost := CardStrategy.activation_cost(self, charm)
	var score := int(declaration["gain"]) - ECON_CARD_VALUE - CardStrategy.mana_penalty(self, cast_cost)
	if score <= 0:
		return {}
	return {
		"score": score,
		"command": {
			"type": "cast_charm",
			"charm_uid": charm.uid,
			"target_uid": "",
			"prepared": charm.is_prepared,
			"named_card_name": str(declaration["card_name"]),
		},
	}

func _plan_special_card(card: Card, attacks: Array[Dictionary], attack: Dictionary, danger: int) -> Dictionary:
	if card is ApollyonsDemiurge:
		return _plan_demiurge(card, danger)
	if card.current_zone == null or not card.current_zone.is_board_zone():
		return {}
	if card is ShroudOfTheAncients:
		if not card.can_activate_prepared(game_manager, bot_player):
			return {}
		var score := CardStrategy.effect_score(self, card)
		return {"score": score, "command": {"type": "activate_prepared_hex", "hex_uid": card.uid}} if score > 0 else {}
	if card.is_face_down or card.abilities_suppressed() or card.is_activation_locked(game_manager) \
			or int(_strategy_activation_turns.get(card.uid, -1)) == game_manager.turn_number:
		return {}
	if card is HildskjalfThroneOfOdin:
		if not card.can_activate(game_manager):
			return {}
		var owner := bot_player
		var own_top: Card = bot_player.deck_zone.known_top_card
		if bot_player.deck_zone.cards.is_empty():
			owner = opponent
		if owner.deck_zone.cards.size() == 1 and (owner == opponent or own_top != null):
			return {}
		var choices: Array[Card] = card.get_top_cards_for_deck_owner(game_manager, owner)
		var best_target: Card = null
		var best_value := -1000000
		for target in choices:
			var value := _deck_pick_value(target, bot_player.mana, danger) if owner == bot_player else -_get_hand_value(target)
			if value > best_value:
				best_value = value
				best_target = target
		if best_target == null:
			return {}
		var score := 1400
		if owner == bot_player and _can_odin_draw_primed_card():
			var baseline := _deck_pick_value(own_top, bot_player.mana, danger) if own_top != null else 0
			score = maxi(score, best_value - baseline)
		return {"score": score, "once_per_turn_uid": card.uid, "command": {
			"type": "activate_card_ability", "source_uid": card.uid, "target_uid": best_target.uid}}

	var targets: Array[Card] = []
	if card is AnointingStatue:
		targets = game_manager.get_field_cards(null, false)
	elif card.can_activate(game_manager):
		targets = card.get_valid_targets(game_manager)
	var best := {}
	for target in targets:
		var score := 0
		var combat_score := 0
		if card is AnointingStatue:
			if not card.can_activate(game_manager, target):
				continue
			score = CardStrategy.cleanse_score(self, card, target)
		elif target.get_controller() == opponent and CardStrategy.visible(self, target) \
				and not game_manager.is_guardian_protected(target, card) and not game_manager.is_immune_to_source(target, card):
			var mode: String = card._resolve_mode_for_target(card.equipped_on, target)
			if mode == Gambanteinn.MODE_SLEEP and CardStrategy.adds_intercept_lock_this_turn(self, target):
				# Sleeping defenders cannot intercept during the rest of this turn.
				var direct_attacks := attacks.filter(func(candidate: Dictionary) -> bool: return candidate.get("target") != target)
				combat_score = int(_plan_combat(direct_attacks, [target], null, Gambanteinn.ACTIVATION_COST).get("score", 0))
				score = combat_score - int(attack.get("score", 0))
			elif mode == Gambanteinn.MODE_FORCE_AGGRESSIVE and not target.is_sleeping and not target.is_stealth:
				for candidate in attacks:
					if candidate.get("target") != target:
						continue
					var projected := CardAction.new()
					projected.type = CardAction.Type.ATTACK
					projected.attacker = candidate["attacker"]
					projected.target = target
					var result := _estimate_attack_economy(projected, null, 0, 0, 0, true, Card.CreatureMode.AGGRESSIVE)
					combat_score = maxi(combat_score, _score_attack_economy(result))
				score = combat_score - int(attack.get("score", 0))
			# The sleep mode opens the held Altar line's Void window, so its
			# activation is the line's own step and carries no hold charge;
			# the aggressive flip stays a normally priced spend.
			score -= CardStrategy.mana_penalty(self, Gambanteinn.ACTIVATION_COST, -1, mode == Gambanteinn.MODE_SLEEP)
		if score > int(best.get("score", 0)):
			best = {"score": score, "combat_score": combat_score, "command": {
				"type": "activate_card_ability", "source_uid": card.uid, "target_uid": target.uid}}
			if card is Gambanteinn:
				best["once_per_turn_uid"] = card.uid
	return best

func _plan_demiurge(spell: ApollyonsDemiurge, danger: int, preparing: bool = false) -> Dictionary:
	var zone := spell._find_summon_zone()
	if zone == null:
		return {}
	if not preparing:
		if spell.is_prepared:
			if not spell.can_activate_prepared(game_manager, bot_player):
				return {}
		elif not game_manager.can_play_card(bot_player, spell, null):
			return {}
	var cost := CardStrategy.activation_cost(self, spell)
	var deck := bot_player.deck_zone
	var cards := deck.get_unordered_deck_cards()
	var response_costs := {}
	for hex: Card in game_manager.prepared_hexes:
		if hex.get_controller() == bot_player:
			response_costs[game_manager.get_prepared_card_activation_mana_cost(bot_player, hex)] = true
	var known_values: Dictionary[Card, int] = {}
	var values: Array[int] = []
	var defensive := game_manager._any_active_structure_forces_defensive_summon()
	var best := {}
	# Compute the expected best Demon from the unordered population, leaving a draw in the deck.
	var draws := 0
	var peeked_cards: Array[Card] = []
	var refund := _immortal_techniques_refund_gain(spell)
	for x in range(1, mini(bot_player.mana - cost, deck.cards.size() - 1) + 1):
		var mana_left := bot_player.mana - cost - x + refund
		# The safety forecast uses mana to check prepared response affordability.
		if x == 1 or response_costs.has(mana_left + 1):
			known_values.clear()
			values.clear()
			for card in cards:
				var value := 0
				if spell._is_demon(card):
					value = _get_card_economic_value(card) + _get_play_cost(card, false) * _mana_rate()
					value += _follower_safety_gain(danger, {
						"summon": card, "zone": zone, "defensive_summons": defensive,
					}, mana_left)
				if deck.get_deck_placement(card) != Zone.DeckPlacement.UNKNOWN:
					known_values[card] = value
				else:
					values.append(value)
			values.sort()
			values.reverse()
		var known := deck.get_known_deck_card(x - 1)
		if known == null:
			draws += 1
		else:
			peeked_cards.append(known)
		var known_value := 0
		for card in peeked_cards:
			known_value = maxi(known_value, known_values[card])
		var expected := float(known_value)
		var miss := 1.0
		for i in range(values.size() - draws + 1):
			if draws <= 0 or i >= values.size() or values[i] <= known_value:
				break
			var hit := float(draws) / (values.size() - i)
			expected += miss * hit * (values[i] - known_value)
			miss *= 1.0 - hit
		var score := int(expected) - ECON_CARD_VALUE - CardStrategy.mana_penalty(self, cost + x) - x * 250
		if score > int(best.get("score", 0)):
			best = {"score": score, "command": {"type": "cast_spell", "spell_uid": spell.uid, "x_value": x}}
	return best

func _choose_demiurge_summon(uids: Array) -> String:
	var uid := "" if uids.is_empty() else str(uids[0])
	var best := 0
	var zone := _get_first_open_summon_zone(bot_player)
	var danger := _forecast_incoming_follower_loss()
	for offered_uid in uids:
		var card := game_manager.get_card_by_uid(str(offered_uid))
		if card == null:
			continue
		var score := _get_card_economic_value(card) + _get_play_cost(card, false) * _mana_rate()
		if zone != null:
			score += _follower_safety_gain(danger, {"summon": card, "zone": zone,
				"defensive_summons": game_manager._any_active_structure_forces_defensive_summon()}, bot_player.mana)
		if score > best:
			best = score
			uid = str(offered_uid)
	return uid

func _choose_breidablik_return(source: Card, uids: Array) -> String:
	if not source is Breidablik:
		return "" if uids.is_empty() else str(uids[0])
	var best := 0
	var uid := ""
	var danger := _forecast_incoming_follower_loss()
	for offered_uid in uids:
		var priest: Card = source.get_stored_priest_by_uid_or_index(str(offered_uid))
		if priest == null:
			continue
		var zone: Zone = source._get_best_return_zone(priest)
		if zone == null:
			continue
		var followers := priest.get_effective_level() * Breidablik.FOLLOWERS_PER_LEVEL
		var cost: int = source.get_activation_mana_cost(Breidablik.RETURN_MANA_COST, game_manager)
		var score := _get_card_economic_value(priest) - CardStrategy.follower_gain(bot_player, followers * 2)
		score -= CardStrategy.mana_penalty(self, cost)
		score += _follower_safety_gain(danger, {"summon": priest, "zone": zone, "defensive_summons": true}, bot_player.mana - cost)
		if score > best:
			best = score
			uid = str(offered_uid)
	return uid

func _choose_structure_ward_mana(power: AdvancedBuildingTechniques, structure: Card) -> int:
	var budget := power.get_max_structure_bonus_mana(structure, game_manager)
	if budget <= 0 or structure == null:
		return 0
	return int(_structure_ward_plan(structure, budget, false).get("payment", 0))

# Shared Advanced Building Techniques math for the live ward prompt and for
# pre-build projections. `projected` marks a structure that is not on the board
# yet (unlock or activation planning); every visible, awake enemy frontline
# attacker then counts, matching the on-board threat model. Returns the best
# ward payment plus its net score so callers price the combo by what the bot
# would actually pay, never by the power's mere presence.
func _structure_ward_plan(structure: Card, budget: int, projected: bool, projected_zone: Zone = null) -> Dictionary:
	if structure == null or budget <= 0:
		return {"payment": 0, "score": 0}
	if opponent != null and game_manager != null and game_manager.attack_restrictions.has(opponent):
		# The opponent cannot attack at all right now (e.g. pinned by this
		# bot's Warding Stone), so no ward payment has a payoff.
		return {"payment": 0, "score": 0}
	var resilience := structure.get_effective_resilience()
	var threats: Array[int] = []
	var max_enemy_strength := 0
	for attacker in _get_board_creatures(opponent):
		if attacker.current_zone not in opponent.frontline_zones or not CardStrategy.visible(self, attacker) \
				or _status_persists_to_next_turn(attacker, "sleep") or _status_persists_to_next_turn(attacker, "cannot_attack"):
			continue
		if projected:
			if not game_manager.can_cards_engage_each_other(attacker, structure, false):
				continue
			if _projected_structure_is_shielded(attacker, projected_zone):
				continue
		elif not _can_attack_creature(attacker, structure):
			continue
		var strength := _get_combat_strength(attacker, structure)
		if strength > resilience:
			threats.append(strength)
		if strength > max_enemy_strength:
			max_enemy_strength = strength
	# Palisade is a wall: spending ABT mana to move its RES out of range of
	# most attackers makes it survive the hits that would otherwise break the
	# line. Treat a typical mid-strength attacker as a virtual threat even when
	# no current attacker strictly exceeds the base 25 RES. With nothing able
	# to attack the barrier at all there is no payoff, so no payment.
	if structure is PalisadeBarrier:
		var wall_threshold := maxi(max_enemy_strength, 30)
		if wall_threshold > resilience and wall_threshold not in threats:
			threats.append(wall_threshold)
	var best_payment := 0
	var best_score := 0
	for strength in threats:
		var payment := ceili(float(strength - resilience) / AdvancedBuildingTechniques.RESILIENCE_PER_MANA)
		if payment <= 0 or payment > budget:
			continue
		var mana_left := (budget if projected else bot_player.mana) - payment
		# Reinforce only with mana left over from the structure's planned use.
		if (structure is E2Abzu and _score_e2_abzu_use(structure, mana_left, _get_first_open_summon_zone(bot_player, projected_zone)) <= 0) \
				or (structure is AncientPyre and mana_left < AncientPyre.ACTIVATION_COST):
			continue
		var protected_resilience := resilience + payment * AdvancedBuildingTechniques.RESILIENCE_PER_MANA
		var stopped := threats.filter(func(threat: int) -> bool: return threat <= protected_resilience).size()
		@warning_ignore("integer_division")
		var score := _get_card_economic_value(structure) * stopped / threats.size() - CardStrategy.mana_penalty(self, payment)
		if score > best_score:
			best_score = score
			best_payment = payment
	return {"payment": best_payment, "score": best_score}

# A structure the bot has not built yet gets the same barrier protection its
# destination zone has on the board: cards behind an active own frontline
# Palisade cannot be attacked except by Aerial creatures. The barrier's own
# method needs the defender on the board, so mirror its depth rule instead.
func _projected_structure_is_shielded(attacker: Card, projected_zone: Zone) -> bool:
	if attacker == null or projected_zone == null or projected_zone.zone_type != Zone.ZoneType.RESERVE:
		return false
	if attacker.has_type("Aerial"):
		return false
	if game_manager == null:
		return false
	for structure in game_manager._get_active_structures():
		if structure is PalisadeBarrier and structure.get_controller() == bot_player \
				and structure.current_zone != null and structure.current_zone.zone_type == Zone.ZoneType.FRONTLINE:
			return true
	return false

# Payoff of unlocking Advanced Building Techniques right now, priced entirely
# by the ward payments the bot would actually make: structures in hand it can
# play this turn, and the Palisade line of summoning the barrier and then
# reinforcing it. A build line the bot cannot fund this turn, or a structure
# nothing would attack, contributes nothing, so the power is never unlocked
# without a concrete plan to use its effect.
func _project_advanced_building_unlock_gain(unlock_cost: int) -> int:
	if bot_player == null or opponent == null or game_manager == null:
		return 0
	var gain := 0
	for card in bot_player.hand_zone.cards:
		if card == null or card.card_type != Card.CardType.STRUCTURE:
			continue
		if CardStrategy.structure_score(self, card) <= 0:
			continue
		var zone := _get_first_open_reserve_zone(bot_player)
		if zone == null or not game_manager.can_play_card(bot_player, card, zone):
			continue
		var ward_budget := bot_player.mana - unlock_cost - _get_play_cost(card, false)
		if ward_budget <= 0:
			continue
		var plan := _structure_ward_plan(card, ward_budget, true, zone)
		if int(plan.get("payment", 0)) > 0 and int(plan.get("score", 0)) > 0:
			gain += int(plan.get("score", 0))
	for power in _get_player_powers():
		if not (power is PalisadePower):
			continue
		# Count the barrier only when the bot would actually summon it and can
		# fund the whole line (ABT unlock, Palisade unlock and activation, ward
		# mana) from this turn's stock.
		if CardStrategy.palisade_gain(self) <= CardStrategy.BAD:
			break
		var barrier_power := power as PalisadePower
		var line_cost := unlock_cost + CardStrategy.activation_cost(self, power)
		if power.is_face_down:
			line_cost += power.get_unlock_mana_cost(game_manager)
		var ward_budget := bot_player.mana - line_cost
		if ward_budget <= 0:
			break
		var preview := PalisadeBarrier.new()
		preview.card_owner = bot_player
		var plan := _structure_ward_plan(preview, ward_budget, true, barrier_power._find_open_summon_zone())
		if int(plan.get("payment", 0)) > 0 and int(plan.get("score", 0)) > 0:
			# The barrier still needs its own activation step before the ward
			# fires, so bank only part of the line's value here.
			gain += int(float(plan.get("score", 0)) * (0.75 if not power.is_face_down else 0.5))
		break
	return mini(gain, ECON_CARD_VALUE * 2)

# The ABT ward prompt fires the moment a structure is summoned, so the power
# has to already be unlocked when the bot builds. When this turn's plans
# include a structure play (from hand or a Palisade activation) whose ward
# payoff is priced in, take the ABT unlock step first; the build follows on
# the next main-phase action and its ward prompt then has a live power.
func _submit_abt_unlock_before_structure_build(unlock: Dictionary, support: Dictionary, power_activation: Dictionary) -> bool:
	if unlock.is_empty() or bot_player == null or game_manager == null:
		return false
	var power := game_manager.get_card_by_uid(str(unlock.get("command", {}).get("power_uid", ""))) as PowerCard
	if not (power is AdvancedBuildingTechniques):
		return false
	var unlock_cost := power.get_unlock_mana_cost(game_manager)
	if not support.is_empty() and str(support.get("command", {}).get("type", "")) == "play_card":
		var structure := game_manager.get_card_by_uid(str(support.get("command", {}).get("card_uid", "")))
		if structure != null and structure.card_type == Card.CardType.STRUCTURE:
			var ward_budget := bot_player.mana - unlock_cost - _get_play_cost(structure, false)
			if ward_budget > 0:
				var plan := _structure_ward_plan(structure, ward_budget, true, _get_first_open_reserve_zone(bot_player))
				if int(plan.get("payment", 0)) > 0 and int(plan.get("score", 0)) > 0:
					return _submit_strategy_plan(unlock)
	if not power_activation.is_empty() and str(power_activation.get("command", {}).get("type", "")) == "activate_power":
		var palisade := game_manager.get_card_by_uid(str(power_activation.get("command", {}).get("power_uid", ""))) as PowerCard
		if palisade is PalisadePower:
			var barrier_power := palisade as PalisadePower
			var ward_budget := bot_player.mana - unlock_cost - CardStrategy.activation_cost(self, palisade)
			if ward_budget > 0:
				var preview := PalisadeBarrier.new()
				preview.card_owner = bot_player
				var plan := _structure_ward_plan(preview, ward_budget, true, barrier_power._find_open_summon_zone())
				if int(plan.get("payment", 0)) > 0 and int(plan.get("score", 0)) > 0:
					return _submit_strategy_plan(unlock)
	return false

func _plan_deucalions_infants(spell: DeucalionsInfants, danger: int, preparing: bool = false) -> Dictionary:
	if spell.is_prepared:
		if not spell.can_activate_prepared(game_manager, bot_player):
			return {}
	elif not preparing and not game_manager.can_play_card(bot_player, spell, null):
		return {}
	var enemies: Array = spell.get_destroyable_enemy_cards(game_manager)
	if enemies.is_empty():
		enemies = [null]
	var friendly := spell.get_destroyable_friendly_cards(game_manager)
	friendly = friendly.filter(func(card: Card) -> bool: return CardStrategy.can_remove_from_board(self, spell, card, true))
	friendly.sort_custom(func(a: Card, b: Card) -> bool: return _get_card_economic_value(a) < _get_card_economic_value(b))
	var cost := CardStrategy.activation_cost(self, spell)
	var best := {}
	# Compare the enemy loss with each number of low-value friendly sacrifices.
	for enemy: Card in enemies:
		for count in range(friendly.size() + 1):
			var removed: Array[Card] = []
			var choices: Array[String] = []
			var score := -ECON_CARD_VALUE - CardStrategy.mana_penalty(self, cost)
			if CardStrategy.can_remove_from_board(self, spell, enemy, true):
				removed.append(enemy)
				score += CardStrategy.value(self, enemy)
			for i in range(count):
				var victim: Card = friendly[i]
				choices.append(victim.uid)
				removed.append(victim)
				score -= _get_card_economic_value(victim)
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
				@warning_ignore("integer_division")
				score += _get_card_economic_value(token) * 3 / 4
				token_count -= 1
			score += _score_effect_summon_sacrifice_followup(summons.keys(), cost, removed)
			score += _follower_safety_gain(danger, {"removed": removed, "summons": summons}, bot_player.mana - cost + _immortal_techniques_refund_gain(spell))
			if score > int(best.get("score", 0)):
				best = {"score": score, "command": {
					"type": "cast_spell", "spell_uid": spell.uid, "prepared": spell.is_prepared,
					"choices": choices,
					"enemy_target_uid": enemy.uid if enemy != null else "",
				}}
	return best

func _plan_changeling_exchange(spell: Card, danger: int, preparing: bool = false) -> Dictionary:
	if spell == null:
		return {}
	if spell.is_prepared:
		if not spell.can_activate_prepared(game_manager, bot_player):
			return {}
	elif not preparing and not game_manager.can_play_card(bot_player, spell, null):
		return {}
	var friendly: Array = spell.get_friendly_targets(game_manager)
	var enemy: Array = spell.get_enemy_targets(game_manager)
	if friendly.is_empty() or enemy.is_empty():
		return {}
	friendly.sort_custom(func(a: Card, b: Card) -> bool: return _get_card_economic_value(a) < _get_card_economic_value(b))
	enemy.sort_custom(func(a: Card, b: Card) -> bool: return _get_card_economic_value(a) > _get_card_economic_value(b))
	var give: Card = friendly[0] as Card
	var take: Card = enemy[0] as Card
	var score := CardStrategy.value(self, take) - _get_card_economic_value(give)
	score -= CardStrategy.mana_penalty(self, CardStrategy.activation_cost(self, spell))
	if score <= 0:
		return {}
	var command := {"type": "cast_spell", "spell_uid": spell.uid, "prepared": spell.is_prepared,
		"friendly_target_uid": give.uid, "enemy_target_uid": take.uid, "target_uid": take.uid}
	return {"command": command, "score": score}

func _plan_board_withdrawal(source: Card, danger: int) -> Dictionary:
	if danger <= 0 or not source.can_activate(game_manager) or source.is_activation_locked(game_manager) \
			or not game_manager.can_pay_creature_action_mana_cost(source, "activate"):
		return {}
	var best := {}
	var cost := game_manager.get_creature_action_mana_cost(source, "activate")
	var tax := cost * _mana_rate()
	if source is TezcatlipocaBlasphemer:
		for target: Card in source.get_valid_targets(game_manager):
			if not CardStrategy.can_remove_from_board(self, source, target, true):
				continue
			for victim: Card in source.get_valid_blood_magic_sacrifices():
				if not CardStrategy.can_remove_from_board(self, source, victim, true, false):
					continue
				var gain := _follower_safety_gain(danger, {"removed": [victim, target]}, bot_player.mana - cost)
				var target_value := CardStrategy.value(self, target)
				var blood_score := gain - tax - _get_card_economic_value(victim) + (target_value if target.get_controller() == opponent else -target_value)
				if gain > 0 and blood_score > int(best.get("score", 0)):
					best = {"score": blood_score, "command": {"type": "activate_card_ability", "source_uid": source.uid,
						"option": {"target_uid": target.uid, "sacrifice_uid": victim.uid}}}
		return best
	var command := {"type": "activate_card_ability", "source_uid": source.uid}
	if source is ErlqueensNightingale:
		if not game_manager.can_player_add_to_hand_now(bot_player):
			return {}
		command["return_to_hand"] = true
	else:
		return {}
	var score := _follower_safety_gain(danger, {"removed": [source]}, bot_player.mana - cost) - _get_card_economic_value(source) - tax
	return {"score": score, "command": command} if score > 0 else {}

# Tree of Life is a repeatable value engine: Kur-Jara withdraws into the grave
# together with a chosen Divine/Priest, both resurrect two own turns later, and
# the ability re-arms when the cycle resolves. A proactive cycle pays for
# itself when the resurrect target outweighs Kur-Jara's missed fighting turns
# plus the level-difference friendly destructions. With incoming losses the
# same activation doubles as a withdrawal dodge that still returns its value
# later, so it no longer counts as losing the card.
func _plan_kur_jara_tree_of_life(kur_jara: KurJara, danger: int) -> Dictionary:
	if kur_jara == null or kur_jara.is_face_down \
			or kur_jara.abilities_suppressed() or kur_jara.is_activation_locked(game_manager) \
			or not kur_jara.can_activate(game_manager) \
			or not game_manager.can_pay_creature_action_mana_cost(kur_jara, "activate"):
		return {}
	var cost := game_manager.get_creature_action_mana_cost(kur_jara, "activate")
	var tax := cost * _mana_rate()
	# The level cost is paid at resolution with the cheapest-to-lose friendly
	# creatures (the destroy prompt ranks the same pool by ascending value).
	var payables: Array = kur_jara.get_tree_of_life_destroy_candidates(game_manager)
	payables = payables.filter(func(card: Card) -> bool: return card != kur_jara)
	payables.sort_custom(func(a: Card, b: Card) -> bool: return _get_card_economic_value(a) < _get_card_economic_value(b))
	# Resolution resurrects into the first open reserve lane and only falls
	# back to the frontline, so forecast where each returned body lands.
	var reserve_spaces := 0
	var frontline_spaces := 0
	for zone in bot_player.frontline_zones + bot_player.reserve_zones:
		if not zone.cards.is_empty():
			continue
		if zone in bot_player.reserve_zones:
			reserve_spaces += 1
		else:
			frontline_spaces += 1
	var self_reserved := reserve_spaces > 0
	var has_self_space := self_reserved or frontline_spaces > 0
	if not has_self_space and danger <= 0:
		# Nothing can resurrect and the ability would burn itself out in
		# the grave; only a defensive dodge could justify that.
		return {}
	var remaining_reserve := reserve_spaces - (1 if self_reserved else 0)
	var remaining_frontline := frontline_spaces - (0 if self_reserved else 1)
	var chosen_reserved := remaining_reserve > 0
	var has_chosen_space := chosen_reserved or remaining_frontline > 0
	var dodge := _follower_safety_gain(danger, {"removed": [kur_jara]}, bot_player.mana - cost)
	var best := {}
	for target in kur_jara.get_valid_targets(game_manager):
		var destroy_count := maxi(0, target.get_effective_level() - kur_jara.get_effective_level())
		var payment_cost := 0
		for index in range(mini(destroy_count, payables.size())):
			payment_cost += _get_card_economic_value(payables[index])
		var target_gain := 0
		if has_chosen_space:
			target_gain = CardStrategy.value(self, target)
			if chosen_reserved:
				# A reserve landing must spend an advance turn before it can
				# attack; that withheld near-term attack option is the same
				# cost reserve placement pays elsewhere.
				target_gain = maxi(0, target_gain - target.get_effective_strength() * RESERVE_PLACEMENT_STR_VALUE)
		var score := 0
		if not has_self_space:
			score = dodge - _get_card_economic_value(kur_jara) - tax
		else:
			score = dodge + target_gain + _tree_of_life_continuation_bonus(kur_jara, target) \
				- _tree_of_life_absence_cost(kur_jara, self_reserved) - payment_cost - tax
		if score > int(best.get("score", 0)):
			best = {
				"command": {"type": "activate_card_ability", "source_uid": kur_jara.uid, "target_uid": target.uid},
				"score": score,
			}
	return best

func _tree_of_life_absence_cost(kur_jara: KurJara, resurrects_to_reserve: bool) -> int:
	# The countdown skips the activation turn and ticks at the end of the next
	# two own turns, so Kur-Jara loses this turn's action (when the window is
	# still unused) plus two more before it rises; a reserve landing needs one
	# more advance turn before it can attack again.
	var missed_turns := 3 if kur_jara.can_take_major_creature_action() else 2
	if resurrects_to_reserve:
		missed_turns += 1
	# Price the fighting presence alone: the engine premium is about the
	# resurrection value, not what each missed combat turn forfeits.
	var presence := CardStrategy.value(self, kur_jara) - CardStrategy.kur_jara_engine_premium(kur_jara)
	return missed_turns * int(round(float(presence) / KUR_JARA_PRESENCE_TURNS))

func _tree_of_life_continuation_bonus(_kur_jara: KurJara, target: Card) -> int:
	if target == null:
		return 0
	for engine_card in bot_player.graveyard_zone.cards:
		if engine_card == null or engine_card == target \
				or engine_card.card_type != Card.CardType.CREATURE:
			continue
		if engine_card.has_type("Divine") or engine_card.has_type("Priest"):
			return KUR_JARA_ENGINE_CONTINUATION
	return 0

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
			var gain := _follower_safety_gain(danger, {
				"removed": [victim], "summon": hati, "zone": zone, "stance": hati, "defensive": true,
			}, bot_player.mana - mana_cost)
			var score := gain + _get_card_economic_value(hati) - _get_card_economic_value(victim) - mana_cost * _mana_rate()
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
	var mana_cost := CardStrategy.activation_cost(self, spell)
	var cost := ECON_CARD_VALUE + CardStrategy.mana_penalty(self, mana_cost)
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
		var candidate := score - cost - body_cost + _follower_safety_gain(danger, change, bot_player.mana - mana_cost + _immortal_techniques_refund_gain(spell))
		if spell is BlotSacrifice:
			candidate += _score_effect_summon_sacrifice_followup(change.get("summons", {}).keys(), mana_cost, [victim])
		if candidate > int(best.get("score", 0)):
			best = {"score": candidate, "command": {"type": "cast_spell", "spell_uid": spell.uid, "sacrifice_uid": victim.uid, "choices": choices}}
	return best

func _try_prepare_strategy_card() -> bool:
	var zone := _get_prepare_zone()
	if zone == null:
		return false
	var prepared_types: Array[String] = []
	for card in game_manager.get_field_cards(bot_player):
		if card.is_prepared:
			prepared_types.append(CardStrategy.key(card))
	var best_card: Card = null
	var best_score := 0
	var spells_need_preparation := game_manager.spells_must_be_prepared()
	for card in bot_player.hand_zone.cards:
		if not CardStrategy.supported(card) or CardStrategy.key(card) in prepared_types \
				or not (card is HexCard or card is CharmCard or (card is SpellCard and spells_need_preparation)):
			continue
		if not game_manager.can_prepare_card(bot_player, card, zone):
			continue
		var score: int
		if card is ApollyonsDemiurge or card is DeucalionsInfants:
			var danger := _forecast_incoming_follower_loss()
			var plan := _plan_demiurge(card, danger, true) if card is ApollyonsDemiurge else _plan_deucalions_infants(card, danger, true)
			score = int(plan.get("score", 0))
		else:
			if card is SpellCard:
				var target := CardStrategy.best_target(self, card, CardStrategy.targets(self, card))
				score = CardStrategy.effect_score(self, card, target)
			else:
				score = CardStrategy.preparation_score(self, card)
			var activation_cost := _get_play_cost(card, true)
			if card is HexCard:
				# Setting a Hex is free. If it needs another upkeep to be
				# usable, favor a trap that can answer the very next turn.
				if activation_cost > bot_player.mana:
					if activation_cost > CardStrategy.projected_upkeep_mana(self, 1):
						continue
					@warning_ignore("integer_division")
					score /= 2
			else:
				score -= CardStrategy.mana_penalty(self, activation_cost)
		if score <= best_score:
			continue
		score -= CardStrategy.preparation_removal_penalty(self, card)
		if score > best_score:
			best_card = card
			best_score = score
	return _submit_prepare_card(best_card, zone, true) if best_card != null else false

func _plan_strategy_support(danger: int = -1) -> Dictionary:
	var best_card: Card = null
	var best_zone: Zone = null
	var discard: Card = null
	var best_score := 0
	for card in bot_player.hand_zone.cards:
		if (card.discard_cost > 0 and not (card is EriduCityOfSages or card is SleepOfTheDuat)) or card.sacrifice_cost > 0:
			continue
		if card is EquipmentCard:
			for bearer in _get_board_creatures(bot_player):
				if not card.can_equip_to(bearer) or not game_manager.can_play_card(bot_player, card, bearer.current_zone):
					continue
				var score := CardStrategy.equipment_score(self, card, bearer)
				if score > best_score:
					best_card = card
					best_zone = bearer.current_zone
					discard = null
					best_score = score
		elif card is StructureCard:
			var zone := _get_first_open_reserve_zone(bot_player)
			if zone == null or not game_manager.can_play_card(bot_player, card, zone):
				continue
			var score := CardStrategy.structure_score(self, card)
			if score <= CardStrategy.BAD:
				continue
			var payment: Card = null
			if card is EriduCityOfSages or card is SleepOfTheDuat:
				payment = _choose_lowest_priority_card(card.get_valid_play_discards(bot_player), [])
				if payment == null:
					continue
				score -= _deck_card_hand_value(payment, bot_player.mana)
			if card is WardingStone:
				score += _warding_stone_safety_gain(danger, bot_player.followers)
			if score > best_score:
				best_card = card
				best_zone = zone
				discard = payment
				best_score = score
	if best_card == null:
		return {}
	var command := {"type": "play_card", "card_uid": best_card.uid, "player_index": player_index,
		"zone_type": best_zone.zone_type, "zone_index": best_zone.zone_index}
	if discard != null:
		command["discard_uids"] = [discard.uid]
	return {"score": best_score, "command": command}

func _plan_equipment_pickup() -> Dictionary:
	var best: Dictionary = {}
	for bearer in _get_board_creatures(bot_player):
		if bearer.current_zone == null or not bearer.can_receive_equipment():
			continue
		var reachable := game_manager.get_reachable_board_zones(bearer)
		for player in game_manager.players:
			if player == null:
				continue
			for zone in player.frontline_zones + player.reserve_zones:
				for card in zone.cards:
					var steed := card as Pegasus
					if steed != null and not steed.is_mounted_as_steed() \
							and zone.zone_owner == bot_player \
							and steed.can_be_used_as_steed_by(bearer, game_manager) \
							and bearer.can_take_minor_creature_action() \
							and game_manager.can_pay_creature_action_mana_cost(bearer, "mount"):
						# Mounting trades the Pegasus body for Spd 5 plus Aerial
						# and Evasive on the bearer, and frees its lane.
						var speed_gain := maxi(0, Pegasus.STEED_SPEED - bearer.get_effective_speed())
						var mount_score := 1800 + speed_gain * 400 - 700 \
							- game_manager.get_creature_action_mana_cost(bearer, "mount") * _mana_rate()
						if mount_score > int(best.get("score", 0)):
							best = {
								"score": mount_score,
								"command": {"type": "equip_action", "card_uid": bearer.uid, "equipment_uid": steed.uid, "action": "pick_up"},
							}
					var equipment := card as EquipmentCard
					if equipment == null or equipment.equipped_on != null or not equipment.can_equip_to(bearer):
						continue
					var is_enemy := zone.zone_owner != bot_player
					var in_range := zone in reachable
					if is_enemy and not in_range and bearer.current_zone.zone_type != Zone.ZoneType.FRONTLINE:
						continue
					if bearer.has_method("can_pick_up_equipment_action") \
							and not bearer.can_pick_up_equipment_action(game_manager, is_enemy):
						continue
					var action_cost_kind := game_manager.get_equipment_pickup_action_cost_kind(bearer, equipment, is_enemy)
					if action_cost_kind == Card.ACTION_COST_MINOR and not bearer.can_take_minor_creature_action():
						continue
					if action_cost_kind == Card.ACTION_COST_MAJOR and not bearer.can_take_major_creature_action():
						continue
					var mana_cost := game_manager.get_creature_action_mana_cost(bearer, "pick up equipment")
					if bot_player.mana < mana_cost:
						continue
					var action := "steal" if is_enemy else "pick_up"
					if is_enemy and not match_manager._get_possible_interceptors(bearer, equipment).is_empty():
						continue
					var score := CardStrategy.equipment_pickup_score(self, equipment, bearer)
					if action_cost_kind == Card.ACTION_COST_MINOR:
						score -= 700
					elif action_cost_kind == Card.ACTION_COST_MAJOR:
						score -= 1400
					score -= mana_cost * _mana_rate()
					if score <= int(best.get("score", 0)):
						continue
					best = {
						"score": score,
						"command": {"type": "equip_action", "card_uid": bearer.uid, "equipment_uid": equipment.uid, "action": action},
					}
	return best

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
	var zone := _get_prepare_zone()
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
	var zone := _get_prepare_zone()
	if zone == null:
		return false
	return _submit_prepare_card(vision, zone)

func _try_prepare_mead_of_poetry() -> bool:
	var mead := _find_hand_unprepared_mead()
	if mead == null:
		return false
	var zone := _get_prepare_zone()
	if zone == null:
		return false
	return _submit_prepare_card(mead, zone)

func _plan_power_unlock(danger: int = -1, attacks: Array[Dictionary] = [], baseline: Dictionary = {}) -> Dictionary:
	var best_power: PowerCard = null
	var best_score := -1000000
	var extraction := {}
	for power in _get_player_powers():
		if power == null or power is AspectShift or not power.is_face_down:
			continue
		# A ready Mead can fund an unlock the stock cannot pay yet, so the
		# lend check below only relaxes the mana gate; every other unlock
		# condition still gates verbatim inside can_unlock.
		var unlock_check := func() -> bool: return power.can_unlock(game_manager)
		if not unlock_check.call() and not _passes_after_brew(unlock_check):
			continue
		# Unlock commands currently cannot carry a selected discard payment.
		# Do not surrender an arbitrary hand card for a generic unlock.
		if power.discard_cost > 0 or power.sacrifice_cost > 0:
			continue
		if power is TonalExtraction:
			extraction = _plan_tonal_extraction(power, power.get_valid_targets(game_manager), danger, attacks, baseline)
			continue
		var score := _score_power_unlock(power)
		if CardStrategy.key(power) in CardStrategy.PLANNED_POWERS:
			var setup := _plan_special_power(power, danger, baseline, power.get_unlock_mana_cost(game_manager))
			score = int(setup.get("score", CardStrategy.BAD))
		if (power is OraclesSight or power is CallOfTheValkyrie) and _can_odin_draw_primed_card():
			var unlock_cost := power.get_unlock_mana_cost(game_manager)
			var setup_cost := unlock_cost + CardStrategy.activation_cost(self, power)
			if setup_cost <= bot_player.mana:
				var prime := _plan_odin_prime(power, power.get_valid_targets(game_manager), danger, unlock_cost)
				score = maxi(score, int(prime.get("score", 0)))
		if power is AllfathersSacrifice:
			var prime := _plan_allfathers_sacrifice(power, danger, power.get_unlock_mana_cost(game_manager))
			score = int(prime.get("score", 0))
		if power is Ragnarok:
			var removed := CardStrategy.removal_targets(self, power)
			var cost := power.get_unlock_mana_cost(game_manager)
			var budget := bot_player.mana + (_ready_brew_mana_gain() if cost > bot_player.mana else 0)
			var gain := _follower_safety_gain(danger, {"removed": removed}, budget - cost)
			if gain > 0:
				score = gain - CardStrategy.mana_penalty(self, cost)
				for victim: Card in removed:
					score += CardStrategy.value(self, victim) if victim.get_controller() == opponent else -CardStrategy.value(self, victim)
			else:
				score += gain
		if score > best_score:
			best_score = score
			best_power = power
	var extraction_score := int(extraction.get("score", CardStrategy.BAD))
	if extraction_score >= 900 and extraction_score > best_score:
		return extraction
	if best_power == null or best_score < 900:
		return {}
	var plan := {"score": best_score, "command": {
		"type": "unlock_power",
		"power_uid": best_power.uid,
	}}
	if best_power.get_unlock_mana_cost(game_manager) > bot_player.mana:
		# Only the brew can pay this unlock: tag it so the Mead is submitted
		# first and the unlock replays on the next pass.
		plan["brew_setup"] = true
	if _can_use_generic_power_command(best_power) and not best_power is AllfathersSacrifice \
			and not ((best_power is OraclesSight or best_power is CallOfTheValkyrie) and _can_odin_draw_primed_card()):
		plan["activate_after_unlock_uid"] = best_power.uid
	return plan

func _plan_tonal_extraction(power: TonalExtraction, targets: Array[Card], danger: int, attacks: Array[Dictionary] = [], baseline: Dictionary = {}) -> Dictionary:
	var best := {}
	var zone := power.get_open_summon_zone()
	if zone == null:
		return best
	var unlock_cost := power.get_unlock_mana_cost(game_manager) if power.is_face_down else 0
	var defensive := game_manager._any_active_structure_forces_defensive_summon()
	var has_mastery := _get_tonal_mastery_god(bot_player) != null
	var baseline_score := int(baseline.get("score", 0))
	for target in targets:
		var profile := target.get_tonal_extraction_spirit_profile()
		if profile.is_empty():
			continue
		var spirit := TonalExtractionSpiritToken.new()
		spirit.configure_from_profile(profile)
		spirit.card_owner = bot_player
		var cost := unlock_cost + game_manager.get_creature_summon_mana_cost(bot_player, spirit, power, true)
		if cost > bot_player.mana:
			continue
		var score := CardStrategy.value(self, spirit) + (spirit.get_effective_speed() - 1) * 400 \
			- CardStrategy.mana_penalty(self, cost)
		if zone in bot_player.reserve_zones or defensive:
			@warning_ignore("integer_division")
			score -= _mana_rate() / 2
		if zone in bot_player.frontline_zones and _opponent_has_known_board_wipe(spirit, zone):
			score -= _get_card_economic_value(spirit)
		if target.has_method("shift_forms"):
			score -= 1500 if has_mastery else 500
			if target.can_activate(game_manager) and game_manager.can_pay_creature_action_mana_cost(target, "activate"):
				# Locking this creature also forfeits its available Tonal Mastery trigger.
				score -= _tonal_mastery_shift_value(bot_player, _tonal_mastery_mana(bot_player))
		score += _follower_safety_gain(danger, {"summon": spirit, "zone": zone, "defensive_summons": defensive}, bot_player.mana - cost)
		var combat_score := baseline_score
		if not defensive and zone in bot_player.frontline_zones and game_manager.turn_number > 1 \
				and not game_manager.has_resolved_attack_this_turn and not game_manager.attack_restrictions.has(bot_player) \
				and not game_manager.is_first_turn_attack_blocked_by_weather(spirit, true):
			var spirit_attacks := _get_attack_candidates(spirit, null, true, null, 0, null, {}, zone)
			var combat := _plan_combat(attacks + spirit_attacks, [], null, cost, zone, -1, [], spirit)
			combat_score = int(combat.get("score", 0))
			score += combat_score - baseline_score
		if score > int(best.get("score", CardStrategy.BAD)):
			best = {"score": score, "combat_score": combat_score, "command": {
				"type": "unlock_power", "power_uid": power.uid, "target_uid": target.uid,
			}}
	return best

func _plan_power_activation(required_power: PowerCard = null, danger: int = -1, combat: Dictionary = {}, attacks: Array[Dictionary] = [], removals: Array[Dictionary] = []) -> Dictionary:
	var prime := {}
	var best_power: PowerCard = null
	var best_target: Card = null
	var best_guard_mana := 0
	var best_score := -1000000
	var powers := _get_player_powers()
	if required_power != null:
		powers.assign([required_power])
	for power in powers:
		if power == null or power is AspectShift or power.is_face_down:
			continue
		# A ready Mead can fund an activation the stock cannot pay yet, so
		# the lend check below only relaxes the mana gate inside can_activate.
		var activate_check := func() -> bool: return power.can_activate(game_manager)
		if not activate_check.call() and not _passes_after_brew(activate_check):
			continue
		if not game_manager.can_player_use_powers(bot_player):
			continue
		if int(_strategy_activation_turns.get(power.uid, -1)) == game_manager.turn_number:
			continue
		if CardStrategy.key(power) in CardStrategy.PLANNED_POWERS:
			var line := _plan_special_power(power, danger, combat, 0, attacks, removals)
			if _is_better_strategy_plan(line, prime):
				prime = line
			continue
		if not _can_use_generic_power_command(power):
			continue
		if power is AllfathersSacrifice or ((power is OraclesSight or power is CallOfTheValkyrie) and _can_odin_draw_primed_card()):
			var line := _plan_allfathers_sacrifice(power, danger) if power is AllfathersSacrifice \
				else _plan_odin_prime(power, power.get_valid_targets(game_manager), danger)
			if _is_better_strategy_plan(line, prime):
				prime = line
			if power is AllfathersSacrifice or not line.is_empty():
				continue
		var chosen_target: Card = null
		if power is CallOfTheValkyrie:
			chosen_target = _choose_call_of_the_valkyrie_target(power)
		elif power.targets and power.has_method("get_valid_targets"):
			chosen_target = CardStrategy.best_target(self, power, power.get_valid_targets(game_manager))
		if power.targets and chosen_target == null:
			continue
		var score: int
		var guard_mana := 0
		if power is ManaGuard:
			var guard_plan := CardStrategy.mana_guard_plan(self, bot_player.mana, 0, danger)
			guard_mana = int(guard_plan.get("mana_amount", 0))
			score = int(guard_plan.get("score", CardStrategy.BAD))
		else:
			score = _score_power_activation(power, chosen_target)
		if score > best_score:
			best_score = score
			best_power = power
			best_target = chosen_target
			best_guard_mana = guard_mana
	if best_power == null or best_score < CardStrategy.MIN_POWER_ACTIVATION_SCORE or _is_better_strategy_plan(prime, {"score": best_score}):
		return prime
	var command := {
		"type": "activate_power",
		"power_uid": best_power.uid,
	}
	if best_target != null:
		command["target_uid"] = best_target.uid
	if CardStrategy.key(best_power) == "ManaGuard":
		command["mana_amount"] = best_guard_mana
	var plan := {"command": command, "score": best_score}
	var activation_price: int = best_guard_mana if CardStrategy.key(best_power) == "ManaGuard" \
		else CardStrategy.activation_cost(self, best_power)
	if activation_price > bot_player.mana:
		# The activation's price only fits after the brew: tag it so the Mead
		# is submitted first and this activation replays on the next pass.
		plan["brew_setup"] = true
	if CardStrategy.key(best_power) in ["OraclesSight", "ManaGuard", "CallOfTheValkyrie"]:
		plan["once_per_turn_uid"] = best_power.uid
	return plan

func _plan_special_power(power: PowerCard, danger: int, combat: Dictionary, unlock_cost: int = 0, attacks: Array[Dictionary] = [], removals: Array[Dictionary] = []) -> Dictionary:
	var cost := CardStrategy.activation_cost(self, power) + unlock_cost
	if power is Breidablik:
		cost = power.get_activation_mana_cost(Breidablik.HARBOR_MANA_COST, game_manager) + unlock_cost
	# A ready Mead can fund the line the stock cannot pay yet; a brew-funded
	# line is tagged so the Mead is submitted first.
	var brew := _ready_brew_mana_gain()
	if cost > bot_player.mana + brew:
		return {}
	if power is DivineCaprice:
		var caprice := _plan_caprice(power, cost, combat)
		if not caprice.is_empty() and cost > bot_player.mana:
			caprice["brew_setup"] = true
		return caprice
	var targets: Array[Card] = []
	var discard: Card = null
	if power is AnankesBinding:
		if not power.stored_cards.is_empty() or bot_player.deck_zone.cards.size() <= AnankesBinding.RETURN_DELAY_TURNS + 1 \
				or danger >= bot_player.followers:
			return {}
		targets = bot_player.deck_zone.get_unordered_deck_cards()
	elif power is Breidablik:
		targets = power.get_valid_field_priests(game_manager)
	elif power is WalkOfTheSage:
		if bot_player.deck_zone.cards.size() < 2:
			return {}
		targets = power.get_valid_targets(game_manager)
	elif power is FireAndGold:
		discard = _choose_lowest_priority_card(power.get_valid_activation_discards(), [])
		if discard == null:
			return {}
		targets = power.get_valid_targets(game_manager)
	var best := {}
	for target in targets:
		var gain := 0
		if power is AnankesBinding:
			# The card is delayed for two turns and still uses a future draw.
			gain = _deck_card_hand_value(target, bot_player.mana - cost + 4) - 1100
		elif power is Breidablik:
			var followers := target.get_effective_level() * Breidablik.FOLLOWERS_PER_LEVEL
			@warning_ignore("integer_division")
			gain = CardStrategy.follower_gain(bot_player, followers * 2) - _get_card_economic_value(target) / 3
			var mana_budget := bot_player.mana + (brew if cost > bot_player.mana else 0)
			gain += _follower_safety_gain(danger, {"removed": [target], "followers": bot_player.followers + followers}, mana_budget - cost, false)
			if target in _get_attack_ready_creatures():
				@warning_ignore("integer_division")
				gain -= _score_follower_loss(opponent, _get_direct_follower_damage(target)) / 2
		elif power is WalkOfTheSage:
			gain = _walk_of_the_sage_gain(target, cost)
		elif power is FireAndGold:
			if target.get_controller() != opponent or not CardStrategy.visible(self, target) \
					or not CardStrategy.can_remove_from_board(self, power, target, true):
				continue
			gain = CardStrategy.removal_score(self, power, target) - _deck_card_hand_value(discard, bot_player.mana - cost)
		var score := gain - CardStrategy.mana_penalty(self, cost)
		var command := {"type": "activate_power", "power_uid": power.uid, "target_uid": target.uid}
		if discard != null:
			command["discard_uids"] = [discard.uid]
		var plan := {"score": score, "command": command, "once_per_turn_uid": power.uid}
		if cost > bot_player.mana:
			# The line's price only fits after the brew: tag it so the Mead
			# is submitted first and the activation replays on the next pass.
			plan["brew_setup"] = true
		if power is FireAndGold:
			if unlock_cost == 0:
				_record_targeted_removal(removals, plan, power, target, [target], cost, null, [discard])
			plan = _plan_removal_setup(plan, attacks, combat, danger, [target], cost, null, unlock_cost == 0, [discard])
		if _is_better_strategy_plan(plan, best):
			best = plan
	return best

func _walk_of_the_sage_gain(target: Card, cost: int) -> int:
	var gain := 0
	for card in bot_player.hand_zone.cards + game_manager.get_field_cards(bot_player, false):
		if card is SeventhSageUtuabzu and card.current_zone == bot_player.hand_zone \
				and target.has_type("Sage") and target.culture == "Ancient":
			gain = maxi(gain, 4800)
		elif card is VisionOfTartarus and _board_creature_count(opponent) > 0:
			gain = maxi(gain, 3400 if card.is_prepared else 2600)
	# E2-abzu turns the Void into a tutor: with the Walk and the structure
	# both available, every Mer Mage still in the deck is gettable on demand,
	# so the target is priced with its full line value once the structure's
	# level-under-mana retrieval rule is satisfied.
	if CardStrategy.walk_tutor_can_reach(self, target) \
			and game_manager.can_player_add_to_hand_now(bot_player):
		var danger := _forecast_incoming_follower_loss()
		var tutor_gain := _deck_pick_value(target, bot_player.mana - cost + 2, danger) \
			- CardStrategy.mana_penalty(self, E2Abzu.RETURN_TO_HAND_COST) - 1200
		gain = maxi(gain, tutor_gain)
	if game_manager._get_active_powers().any(func(power: PowerCard) -> bool: return power is ACostToWalkTheWorlds):
		gain -= _score_follower_loss(bot_player, ACostToWalkTheWorlds.LOSS_AMOUNT)
	return gain

func _plan_caprice(power: DivineCaprice, cost: int, combat: Dictionary) -> Dictionary:
	if game_manager.turn_number <= 1 or game_manager.attack_restrictions.has(bot_player):
		return {}
	var best := {}
	var baseline := int(combat.get("score", 0))
	for source in bot_player.reserve_zones:
		var attacker := source.get_creature()
		if attacker == null or attacker.get_controller() != bot_player or attacker.creature_mode != Card.CreatureMode.AGGRESSIVE \
				or attacker.is_face_down or attacker.is_sleeping or attacker.has_status_effect("cannot_attack") \
				or attacker.summoned_after_first_attack_this_turn or not attacker.can_take_major_creature_action() \
				or game_manager.is_first_turn_attack_blocked_by_weather(attacker):
			continue
		var attack_cost := game_manager.get_creature_action_mana_cost(attacker, "attack")
		# The brew may fund the reposition plus attack taxes past the stock.
		if attack_cost + cost > bot_player.mana + _ready_brew_mana_gain():
			continue
		for destination in bot_player.frontline_zones:
			var displaced := destination.get_creature()
			if displaced in _get_attack_ready_creatures() or not power.can_reposition_between(source, destination):
				continue
			var lines := _get_attack_candidates(attacker, null, true, null, 0, null, {}, destination)
			var attack_score := 0
			for line in lines:
				attack_score = maxi(attack_score, _score_attack_economy(_project_attack(line, [], destination)))
			var score := attack_score - baseline - CardStrategy.mana_penalty(self, cost) \
				- attack_cost * _mana_rate()
			if score <= int(best.get("score", 0)):
				continue
			best = {"score": score, "combat_score": attack_score, "once_per_turn_uid": power.uid, "command": {
				"type": "activate_divine_caprice", "power_uid": power.uid, "plan": [{
					"source_zone": {"player_index": player_index, "zone_type": source.zone_type, "zone_index": source.zone_index},
					"target_zone": {"player_index": player_index, "zone_type": destination.zone_type, "zone_index": destination.zone_index},
				}]}}
	return best

func _plan_odin_prime(source: Card, visible_cards: Array[Card], danger: int, setup_cost: int = 0) -> Dictionary:
	var cost := CardStrategy.activation_cost(self, source) + setup_cost
	var mana := bot_player.mana - cost
	var known := bot_player.deck_zone.known_top_card
	var baseline := _deck_pick_value(known, bot_player.mana, danger) if known != null else 0
	var best := {}
	for card in visible_cards:
		var score := _deck_pick_value(card, mana, danger) - baseline - CardStrategy.mana_penalty(self, cost)
		if score <= maxi(CardStrategy.MIN_POWER_ACTIVATION_SCORE, int(best.get("score", 0))):
			continue
		var command := {"target_uid": card.uid}
		if source is PowerCard:
			command.merge({"type": "activate_power", "power_uid": source.uid})
		else:
			command.merge({"type": "activate_card_ability", "source_uid": source.uid})
		best = {"score": score, "command": command, "once_per_turn_uid": source.uid}
	return best

func _plan_allfathers_sacrifice(power: AllfathersSacrifice, danger: int, unlock_cost: int = 0) -> Dictionary:
	var fast := _can_odin_draw_primed_card()
	var known := bot_player.deck_zone.known_top_card
	var follower_cost := AllfathersSacrifice.FOLLOWER_COST if bot_player.followers_enabled and game_manager.can_player_lose_followers_now(bot_player) else 0
	if power.is_muted or bot_player.followers < AllfathersSacrifice.FOLLOWER_COST or bot_player.followers <= follower_cost:
		return {}
	var mana := bot_player.mana - unlock_cost
	if not fast and _forecast_incoming_follower_loss({"followers": bot_player.followers - follower_cost, "mana_left": mana}) >= bot_player.followers - follower_cost:
		return {}
	var cost := _score_follower_loss(bot_player, follower_cost) + CardStrategy.mana_penalty(self, unlock_cost)
	var puts_bot_in_lethal_range := fast and follower_cost > 0 \
		and _follower_safety_gain(danger, {"followers": bot_player.followers - follower_cost}, mana) <= -ECON_CARD_VALUE * 20
	if not fast:
		mana += game_manager.get_automatic_upkeep_mana_gain(bot_player, game_manager.turn_number + 2) \
			+ game_manager.get_effective_upkeep_mana_gain(game_manager.get_base_upkeep_mana_gain(), bot_player)
		# Each upcoming enemy Pazuzu turn start eats into the stock this line
		# plans to spend turns from now, so forecast the drained remainder.
		mana -= _incoming_mana_drain()
	var deck := bot_player.deck_zone.get_unordered_deck_cards()
	var known_value := 0
	if not fast and known == null:
		# The planned draw replaces a normal draw the bot would receive anyway.
		for card in deck:
			known_value += _deck_card_hand_value(card, mana)
		if not deck.is_empty():
			@warning_ignore("integer_division")
			known_value = known_value / deck.size() / 3
	if known != null:
		known_value = _deck_pick_value(known, mana, danger) if fast else _deck_card_hand_value(known, mana)
	var best := {}
	for card in deck:
		if not card is SpellCard or card == known:
			continue
		var value := _deck_card_hand_value(card, mana)
		var tactical := _deck_card_tactical_gain(card, mana, danger, [], follower_cost)
		if fast:
			value += tactical
		else:
			@warning_ignore("integer_division")
			value = value * 2 / 3 + mini(ECON_CARD_VALUE, tactical / 2)
		var score := value - cost - known_value
		if puts_bot_in_lethal_range and tactical < ECON_CARD_VALUE * 20:
			continue
		if score > maxi(CardStrategy.MIN_POWER_ACTIVATION_SCORE, int(best.get("score", 0))):
			best = {"score": score, "once_per_turn_uid": power.uid, "command": {
				"type": "activate_power", "power_uid": power.uid, "target_uid": card.uid,
			}}
	return best

func _try_switch_to_aggressive_mode(danger: int = -1) -> bool:
	var creature := _get_best_mode_switch_candidate()
	if creature == null:
		return false
	var cost := game_manager.get_creature_action_mana_cost(creature, "change stance")
	if danger >= 0 and _forecast_incoming_follower_loss({
		"stance": creature, "defensive": false, "mana_left": bot_player.mana - cost,
	}) >= bot_player.followers:
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
				or game_manager.is_temporarily_controlled(creature) \
				or not creature.can_take_minor_creature_action() or not game_manager.can_pay_creature_action_mana_cost(creature, "change stance"):
			continue
		var cost := game_manager.get_creature_action_mana_cost(creature, "change stance")
		var gain := _follower_safety_gain(danger, {"stance": creature, "defensive": true}, bot_player.mana - cost)
		if gain <= 0:
			continue
		# Lethal-prevention stance switches are always allowed; milder
		# preservation gains are only worth the tempo loss when the follower
		# pool is actually scarce.
		if gain < ECON_CARD_VALUE * 30 and not _is_dangerously_low_on_followers():
			continue
		var score := gain + _stance_casualty_savings(creature, Card.CreatureMode.DEFENSIVE) \
			- (1 + cost) * _mana_rate()
		if score > int(best.get("score", 0)):
			best = {"score": score, "command": {"type": "change_mode", "card_uid": creature.uid, "mode": Card.CreatureMode.DEFENSIVE}}
	return best

func _plan_call_of_the_crossing(god: HermesPsychopompus, danger: int, attacks: Array[Dictionary], baseline: Dictionary, mana_budget: int, setup_cost: int = 0) -> Dictionary:
	var best := {}
	var ghosts := god.get_summonable_ghosts()
	if ghosts.is_empty():
		return best
	var lanes := _get_open_summon_lane_candidates(bot_player, 1)
	var defensive := game_manager._any_active_structure_forces_defensive_summon()
	var baseline_score := int(baseline.get("score", 0))
	var can_attack_after_summon := not defensive and game_manager.turn_number > 1 \
		and not game_manager.has_resolved_attack_this_turn and not game_manager.attack_restrictions.has(bot_player)
	for ghost in ghosts:
		var discard_cost := god.get_ghost_discard_cost(ghost)
		var discard_uids := _get_ghost_summon_discard_uids(discard_cost)
		if discard_uids.size() != discard_cost:
			continue
		var cost := setup_cost
		var mana_after_summon := mana_budget - cost
		var grave_fill := _crossing_grave_fill_value(god, discard_uids)
		var value := _ghost_body_presence_value(ghost) \
			- _get_hand_discard_value(discard_uids, mana_after_summon) \
			- CardStrategy.mana_penalty(self, cost, mana_budget)
		for lane in lanes:
			var line := {}
			if can_attack_after_summon and lane.zone_type == Zone.ZoneType.FRONTLINE \
					and not ghost is GidimEnsi and not ghost.has_status_effect("cannot_attack") \
					and not game_manager.is_first_turn_attack_blocked_by_weather(ghost, true):
				var new_attacks := _get_attack_candidates(ghost, null, true, null, 0, null, {}, lane)
				line = _plan_combat(attacks + new_attacks, [], null, cost, lane, mana_budget, [], ghost)
			var combat_score := int(line.get("score", 0))
			var brew_first := _brew_enables_spend(int(line.get("mana_required", cost)))
			var safety_mana := mana_after_summon if brew_first else mini(mana_budget, bot_player.mana) - cost
			var safety := _follower_safety_gain(danger, {"summon": ghost, "zone": lane, "defensive_summons": defensive}, safety_mana)
			var score := value + safety + maxi(0, combat_score - baseline_score) + grave_fill
			var plan := {"score": score, "combat_score": combat_score, "lethal": bool(line.get("lethal", false)),
				"brew_setup": brew_first, "command": {
				"type": "god_ability", "god_uid": god.uid, "ability": HermesPsychopompus.CALL_OF_THE_CROSSING,
				"ghost_uid": ghost.uid, "zone_type": lane.zone_type, "zone_index": lane.zone_index,
				"discard_uids": discard_uids,
			}}
			if _is_better_strategy_plan(plan, best):
				best = plan
	return best

func _get_ghost_summon_discard_uids(cost: int) -> Array[String]:
	var discard_uids: Array[String] = []
	var virtual_hand := bot_player.hand_zone.cards.duplicate()
	for _index in range(cost):
		var discard_card := _choose_lowest_priority_card(virtual_hand, discard_uids)
		if discard_card == null:
			discard_uids.clear()
			return discard_uids
		discard_uids.append(discard_card.uid)
	return discard_uids

func _get_hand_discard_value(discard_uids: Array[String], mana_left: int) -> int:
	# Price the discard holistically as its opportunity cost: what the card could
	# have been worth this turn. A body that could still be summoned loses its
	# full board value (the same scale the summoned Ghost is priced on), so
	# tossing an average body for a weaker one is a real trade, not a free one.
	# A card that cannot be played loses only its discounted hand value.
	var value := 0
	for uid in discard_uids:
		var card := game_manager.get_card_by_uid(uid)
		if card == null:
			continue
		if card is CreatureCard and _get_play_cost(card, false) <= mana_left:
			value += CardStrategy.value(self, card)
		else:
			value += _deck_card_hand_value(card, mana_left)
	return value

func _ghost_body_presence_value(ghost: Card) -> int:
	# The Ghost's standing board value. An Incorporeal body with no Spirit or
	# Mage to engage cannot use its strength offensively, so it is worth its
	# presence and defence rather than its reach; the marginal combat term still
	# credits any follower damage it can actually deal this turn.
	var body := CardStrategy.value(self, ghost)
	if ghost.incorporeal and not _incorporeal_has_matchup():
		body -= CardStrategy._strength_reach_points(ghost.get_effective_strength())
	return body

func _incorporeal_has_matchup() -> bool:
	for enemy in _get_board_creatures(opponent):
		if CardStrategy.visible(self, enemy) and (enemy.has_type("Spirit") or enemy.has_type("Mage")):
			return true
	return false

func _crossing_grave_fill_value(god: HermesPsychopompus, discard_uids: Array[String]) -> int:
	# Discarding a Ghost fuels Wings of the Departed. Credit that grave fill only
	# when the Hades aspect has a creature that could actually spend the speed.
	if god.get_speed_targets(game_manager).is_empty():
		return 0
	var value := 0
	for uid in discard_uids:
		var card := game_manager.get_card_by_uid(uid)
		if card != null and card.has_type("Ghost"):
			@warning_ignore("integer_division")
			value += CardStrategy.MANA_VALUE / 2
	return value

func _plan_deck_god_ability(danger: int, attacks: Array[Dictionary] = [], combat: Dictionary = {}, projected_mana: int = -1) -> Dictionary:
	var god := _find_player_god()
	if god is Odin:
		return _plan_odin_draw(danger)
	if god is HermesPsychopompus:
		var mana_budget := bot_player.mana if projected_mana < 0 else projected_mana
		return _plan_call_of_the_crossing(god, danger, attacks, combat, mana_budget) if god.can_use_god_power(game_manager) else {}
	if not god is NuskuFirebearer or not game_manager.can_player_add_to_hand_now(bot_player):
		return {}
	# A ready Mead can fund the Well of Fire price past the stock.
	var god_check := func() -> bool: return god.can_activate(game_manager)
	if not god_check.call() and not _passes_after_brew(god_check):
		return {}
	var deck := bot_player.deck_zone
	var population := deck.get_unordered_deck_cards()
	var draw_count := mini(NuskuFirebearer.MILL_COUNT, population.size())
	var mana := bot_player.mana + _ready_brew_mana_gain() - NuskuFirebearer.ACTIVATION_COST
	var worst_known := 0
	var known_milled: Array[Card] = []
	for index in draw_count:
		var known := deck.get_known_deck_card(index)
		if known != null:
			known_milled.append(known)
	var values: Array[int] = []
	for card in population:
		var value := _deck_pick_value(card, mana, danger) if god.matches_well_of_fire(card) else 0
		if card in known_milled and value > 0:
			worst_known = mini(worst_known, value) if worst_known > 0 else value
		elif deck.get_deck_placement(card) == Zone.DeckPlacement.UNKNOWN:
			values.append(value)
	draw_count -= known_milled.size()
	# Well of Fire awards the least useful eligible card if the opponent
	# picks optimally. Its expectation is the sum of the probabilities of
	# reaching each value threshold, including samples that miss entirely.
	values.sort()
	var expected := 0.0
	var previous := 0
	var lower_eligible := 0
	var ineligible := values.count(0)
	for value in values:
		if value <= 0:
			continue
		if value > previous and (worst_known == 0 or value <= worst_known):
			var no_worse := _sample_avoids(values.size(), lower_eligible, draw_count)
			var misses := _sample_avoids(values.size(), values.size() - ineligible, draw_count) if worst_known == 0 else 0.0
			expected += float(value - previous) * (no_worse - misses)
			previous = value
		lower_eligible += 1
	if worst_known > previous:
		expected += float(worst_known - previous) * _sample_avoids(values.size(), lower_eligible, draw_count)
	var score := int(expected) - CardStrategy.mana_penalty(self, NuskuFirebearer.ACTIVATION_COST)
	# Milling uses up future draws, particularly when the deck is already short.
	score -= NuskuFirebearer.MILL_COUNT * (250 if population.size() <= 14 else 75)
	# The milled cards also land in the grave, where several of our cards feed.
	score += _well_of_fire_grave_fill_value(population, known_milled, values.size(), draw_count)
	if score <= 0:
		return {}
	var plan := {"score": score, "command": {"type": "god_ability", "god_uid": god.uid}}
	if NuskuFirebearer.ACTIVATION_COST > bot_player.mana:
		# The brew funds the mill's price: tag it so the Mead is submitted
		# first and the ability replays on the next pass.
		plan["brew_setup"] = true
	return plan

func _sample_avoids(population: int, excluded: int, count: int) -> float:
	if population - excluded < count:
		return 0.0
	var probability := 1.0
	for index in range(count):
		probability *= float(population - excluded - index) / float(population - index)
	return probability

func _well_of_fire_grave_fill_value(population: Array[Card], known_milled: Array[Card], unknown_population: int, milled_slots: int) -> int:
	# The mill half of Well of Fire is not pure deck damage: the milled cards
	# land in the grave where several of our cards feed. Like
	# _crossing_grave_fill_value, every credit requires the spender to be
	# actually ours right now, so this never becomes a blanket mill bonus.
	var value := 0

	# Tablet of Life needs an Ancient creature in the grave; one milled target
	# is what unblocks a tablet stranded in hand.
	var tablet: TabletOfLife = null
	for hand_card in bot_player.hand_zone.cards:
		if hand_card is TabletOfLife:
			tablet = hand_card as TabletOfLife
			break
	if tablet != null and tablet.get_valid_targets(game_manager).is_empty():
		var target_fuel := func(card: Card) -> bool:
			return card != null and card.card_type == Card.CardType.CREATURE \
				and not card.is_god and str(card.culture).strip_edges() == "Ancient"
		value += int(_grave_fuel_hit_chance(target_fuel, population, known_milled, unknown_population, milled_slots) * ECON_CARD_VALUE / 2)

	# Pictish Beast's Mana Boon counts grave beasts on every later reveal, so
	# a milled beast still pays through a beast we hold or draw later. Half
	# rate: the milled body is also a summon we will never get to make.
	var beast_fuel := func(card: Card) -> bool: return card is PictishBeast
	if _hand_has_fuel_card(beast_fuel) or _deck_has_fuel_card(beast_fuel, population):
		var expected_beasts := minf(2.0, _expected_grave_fuel_count(beast_fuel, population, known_milled, unknown_population, milled_slots))
		value += int(expected_beasts * PictishBeast.MANA_PER_BEAST * CardStrategy.MANA_VALUE / 2)

	# Nergal Lion's Immolate prepares a Destruction card from the grave at
	# 0 cost; a milled one is a free cast waiting on its Impact.
	var lion := _find_nergal_lion()
	if lion != null and lion.get_valid_immolate_targets(game_manager).is_empty():
		var immolate_fuel := func(card: Card) -> bool:
			return card != null \
				and card.card_type in [Card.CardType.SPELL, Card.CardType.HEX, Card.CardType.CHARM] \
				and lion._is_destruction_card(card) and lion._can_destroy_physical_card(card)
		value += int(_grave_fuel_hit_chance(immolate_fuel, population, known_milled, unknown_population, milled_slots) * CardStrategy.MANA_VALUE)

	# Celestial Light converts followers equal to the grave size when Nusku,
	# Active God perishes after declining Core Flame, so grave growth also
	# feeds that later play. Only buried cards count: the opponent's Well of
	# Fire pick leaves for the hand. The flat half rate prices how far away
	# the summon-decline-perish chain still is.
	if opponent != null and opponent.followers_enabled and bot_player.followers_enabled \
			and _owns_nusku_active(population):
		var grave_growth := float(maxi(0, known_milled.size() + milled_slots - 1))
		value += int(grave_growth * CardStrategy.FOLLOWER_VALUE / 2)
	return value

func _hand_has_fuel_card(fuel_check: Callable) -> bool:
	for card in bot_player.hand_zone.cards:
		if fuel_check.call(card):
			return true
	return false

func _deck_has_fuel_card(fuel_check: Callable, population: Array[Card]) -> bool:
	for card in population:
		if fuel_check.call(card):
			return true
	return false

func _find_nergal_lion() -> NergalLion:
	for card in bot_player.hand_zone.cards:
		if card is NergalLion:
			return card as NergalLion
	for zone in bot_player.frontline_zones + bot_player.reserve_zones:
		for card in zone.cards:
			if card is NergalLion and not card.is_face_down:
				return card as NergalLion
	return null

func _owns_nusku_active(population: Array[Card]) -> bool:
	for card in bot_player.hand_zone.cards:
		if card is NuskuActive:
			return true
	for zone in bot_player.frontline_zones + bot_player.reserve_zones:
		for card in zone.cards:
			if card is NuskuActive:
				return true
	for card in population:
		if card is NuskuActive:
			return true
	return false

func _grave_fuel_hit_chance(fuel_check: Callable, population: Array[Card], known_milled: Array[Card], unknown_population: int, milled_slots: int) -> float:
	# Chance at least one fuel card is milled: the known top slice is
	# certain, the unknown remainder samples hypergeometrically.
	for card in known_milled:
		if fuel_check.call(card):
			return 1.0
	if unknown_population <= 0 or milled_slots <= 0:
		return 0.0
	var eligible := 0
	for card in population:
		if fuel_check.call(card) \
				and bot_player.deck_zone.get_deck_placement(card) == Zone.DeckPlacement.UNKNOWN:
			eligible += 1
	if eligible <= 0:
		return 0.0
	return 1.0 - _sample_avoids(unknown_population, eligible, milled_slots)

func _expected_grave_fuel_count(fuel_check: Callable, population: Array[Card], known_milled: Array[Card], unknown_population: int, milled_slots: int) -> float:
	var count := 0.0
	for card in known_milled:
		if fuel_check.call(card):
			count += 1.0
	if unknown_population > 0 and milled_slots > 0:
		var eligible := 0
		for card in population:
			if fuel_check.call(card) \
					and bot_player.deck_zone.get_deck_placement(card) == Zone.DeckPlacement.UNKNOWN:
				eligible += 1
		count += float(eligible) * float(milled_slots) / float(unknown_population)
	return count

func _should_decline_nusku_core_flame(nusku: NuskuActive) -> bool:
	# Declining Core Flame banks Celestial Light: when Nusku, Active God
	# perishes, it converts followers equal to the grave size. Trade away the
	# milled magical card only when that conversion is worth clearly more
	# than a card in hand.
	if nusku == null or opponent == null or bot_player == null:
		return false
	if nusku.card_owner != bot_player:
		return false
	if not opponent.followers_enabled or not bot_player.followers_enabled:
		return false
	if bot_player.graveyard_zone == null:
		return false
	var grave_size := bot_player.graveyard_zone.cards.size()
	if grave_size < NUSKU_CELESTIAL_LIGHT_MIN_GRAVE:
		return false
	var conversion := _score_follower_loss(opponent, grave_size) \
		+ CardStrategy.follower_gain(bot_player, grave_size)
	# The payout still waits on the active god perishing, so weight it down.
	@warning_ignore("integer_division")
	return conversion * 3 / 5 > CardStrategy.CARD_VALUE * 2

func _plan_odin_draw(danger: int, desperation: bool = false) -> Dictionary:
	var god := _find_player_god() as Odin
	if god == null:
		return {}
	# A ready Mead can fund the Runic Knowledge price past the stock.
	var god_check := func() -> bool: return god.can_activate(game_manager)
	if not god_check.call() and not _passes_after_brew(god_check):
		return {}
	var deck := bot_player.deck_zone
	var known := deck.known_top_card
	var counts := {}
	var representatives: Array[Card] = []
	var unknown_count := 0
	if known != null:
		representatives.append(known)
	else:
		for card in deck.get_unordered_deck_cards():
			if deck.get_deck_placement(card) != Zone.DeckPlacement.UNKNOWN:
				continue
			var key := CardCatalog.to_lookup_key(card.card_name)
			if not counts.has(key):
				representatives.append(card)
			counts[key] = int(counts.get(key, 0)) + 1
			unknown_count += 1
	var penalty := Odin.FOLLOWER_PENALTY if bot_player.followers_enabled and game_manager.can_player_lose_followers_now(bot_player) else 0
	var miss_cost := _score_follower_loss(bot_player, penalty)
	var can_draw := game_manager.can_player_add_to_hand_now(bot_player)
	var best := {}
	var followups := {}
	for offering in god.get_valid_runic_knowledge_offerings():
		var removed := [offering] if offering.current_zone.is_board_zone() else []
		var price := _odin_offering_cost(offering)
		var hit := {"removed": removed}
		var miss := {"removed": removed, "followers": bot_player.followers - penalty}
		var hit_safety := _follower_safety_gain(danger, hit, bot_player.mana) if not removed.is_empty() else 0
		var miss_safety := _follower_safety_gain(danger, miss, bot_player.mana, false) if not removed.is_empty() or penalty > 0 else 0
		for card in representatives:
			var probability := 1.0 if known != null else float(counts[CardCatalog.to_lookup_key(card.card_name)]) / unknown_count
			var out := 0
			if can_draw:
				if removed.is_empty():
					if not followups.has(card):
						followups[card] = _deck_card_tactical_gain(card, bot_player.mana, danger)
					out = followups[card]
				else:
					out = _deck_card_tactical_gain(card, bot_player.mana, danger, removed)
			var draw_value := _deck_card_hand_value(card, bot_player.mana) if can_draw else 0
			var score := 0
			if desperation:
				if probability >= 1.0 or maxi(hit_safety, out) < ECON_CARD_VALUE * 20:
					continue
				# The existing line loses. Maximize the chance of reaching a
				# survivable line, even when a miss immediately ends the game.
				@warning_ignore("integer_division")
				score = maxi(1, int(probability * ECON_CARD_VALUE * 30) - price / 10)
			else:
				if probability < 1.0 and (bot_player.followers <= penalty or (danger >= bot_player.followers and miss_safety < ECON_CARD_VALUE * 20)):
					continue
				score = int(probability * (draw_value + maxi(hit_safety, out)) + (1.0 - probability) * (miss_safety - miss_cost)) - price
			if score > int(best.get("score", 0)):
				best = {"score": score, "command": {"type": "activate_card_ability", "source_uid": god.uid,
					"option": {"offering_uid": offering.uid, "named_card_name": card.card_name}}}
				if god.has_method("get_activation_mana_cost") and god.get_activation_mana_cost(game_manager) > bot_player.mana:
					# The brew funds the draw's price: tag it so the Mead is
					# submitted first and the draw replays on the next pass.
					best["brew_setup"] = true
	return best

func _odin_offering_cost(card: Card) -> int:
	if card.current_zone == bot_player.graveyard_zone:
		return _get_hand_value(card) * 8
	if card is WardingStone and card.get_attack_restriction_turns_remaining(game_manager) <= 0:
		@warning_ignore("integer_division")
		return ECON_CARD_VALUE / 5
	return _get_card_economic_value(card)

func _can_odin_draw_primed_card() -> bool:
	var god := _find_player_god() as Odin
	return god != null and god.can_activate(game_manager) and game_manager.can_player_add_to_hand_now(bot_player)

func _deck_card_hand_value(card: Card, mana: int) -> int:
	var value := 2600 + _get_hand_value(card) * 48
	if _get_play_cost(card, false) > mana:
		@warning_ignore("integer_division")
		value = value * 2 / 3
	elif card is SpellCard or card is CharmCard:
		value += 900
	elif bot_player.hand_zone.cards.is_empty():
		@warning_ignore("integer_division")
		value += ECON_CARD_VALUE / 3
	return value

func _deck_pick_value(card: Card, mana: int, danger: int, excluded: Array = []) -> int:
	return _deck_card_hand_value(card, mana) + _deck_card_tactical_gain(card, mana, danger) \
		+ CardStrategy.deck_pick_line_gain(self, card, excluded)

func _deck_card_tactical_gain(card: Card, mana: int, danger: int, removed: Array = [], follower_cost: int = 0) -> int:
	var cost := _get_play_cost(card, false)
	if mana < cost or card.sacrifice_cost > 0 or card.discard_cost > 0 \
			or card.shelve_cost > 0 or card.banish_cost > 0:
		return 0
	var best := 0
	var followers := bot_player.followers - follower_cost
	if card is CreatureCard and not card is ActiveGodCard and not bot_player.has_summoned_this_turn:
		var zone := _get_first_open_summon_zone(bot_player)
		if zone != null:
			best = _follower_safety_gain(danger, {"removed": removed, "followers": followers,
				"summon": card, "zone": zone, "stance": card, "defensive": true}, mana - cost, false)
			for candidate in _get_summon_attack_candidates(card, zone, mana):
				var outcome := _project_attack(candidate, removed)
				if bool(outcome.get("bot_wins", false)):
					best = maxi(best, ECON_CARD_VALUE * 30)
	elif CardStrategy.supported(card) and (card is CharmCard or (card is SpellCard and not game_manager.spells_must_be_prepared())):
		if not card.goes_to_graveyard_after_use() and _get_first_open_reserve_zone(bot_player) == null:
			return 0
		var targets := CardStrategy.targets(self, card)
		if targets.is_empty() and not card.targets:
			targets = [null]
		for target: Card in targets:
			if target in removed or not game_manager.get_turn_destruction_ward_activation_block_reason(card, target).is_empty():
				continue
			var score := CardStrategy.effect_score(self, card, target)
			if score <= CardStrategy.BAD:
				continue
			var casualties := removed + CardStrategy.removal_targets(self, card, target)
			var adjusted_followers := followers + (BookOfLife.FOLLOWERS_GAINED if card is BookOfLife else 0)
			var change := {"removed": casualties, "followers": adjusted_followers}
			if card is BookOfLife and target != null:
				var zone := _get_first_open_summon_zone(bot_player)
				if zone != null:
					change.merge({"summon": target, "zone": zone, "stance": target})
			var safety := _follower_safety_gain(danger, change, mana - cost + _immortal_techniques_refund_gain(card), false)
			best = maxi(best, score + safety)
	elif card is WardingStone and _get_first_open_reserve_zone(bot_player) != null:
		best = _warding_stone_safety_gain(danger, followers, removed)
	return best

func _plan_removal_god_ability(danger: int, attacks: Array[Dictionary] = [], combat: Dictionary = {}, removals: Array[Dictionary] = []) -> Dictionary:
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
	for target in targets:
		var removed := CardStrategy.removal_targets(self, god, target)
		if removed.is_empty() \
				or not game_manager.get_turn_destruction_ward_activation_block_reason(god, target).is_empty():
			continue
		var cost := AphroditeAreia.ACTIVATION_COST if god is AphroditeAreia else 0
		var gain := _effect_follower_safety_gain(god, target, danger, bot_player.mana - cost)
		var own := target.get_controller() == bot_player
		var mummu := god as Mummu
		if own and mummu != null:
			# Entropic Force returns the card to the deck instead of
			# destroying it, so it is scored as a ramp play as well as a
			# survival removal: see _plan_mummu_entropic_force.
			if _is_destroyed_at_this_turns_end(target) or game_manager.is_temporarily_controlled(target):
				# Doomed and borrowed bodies leave at this turn's end either
				# way, so shelving them is follower-safety neutral.
				gain = 0
			var entropic := _plan_mummu_entropic_force(mummu, target, gain)
			if _is_better_strategy_plan(entropic, best):
				best = entropic
			continue
		if own and gain <= 0:
			continue
		var score := gain + (CardStrategy.value(self, target) if not own else -_get_card_economic_value(target))
		if god is Mummu and game_manager.can_player_gain_mana_now(bot_player):
			score += CardStrategy.mana_gain_value(self, maxi(0, target.get_effective_level() - 1))
		elif god is AphroditeAreia:
			score = gain + _violent_delights_target_value(target) - CardStrategy.mana_penalty(self, AphroditeAreia.ACTIVATION_COST)
		var plan := {
			"score": score, "command": {"type": "god_ability", "god_uid": god.uid, "target_uid": target.uid},
		}
		if not own:
			plan["score"] -= gain
			# Enslavement can occupy the summon lane.
			if god is GuanYu:
				_record_targeted_removal(removals, plan, god, target, removed, cost)
			plan = _plan_removal_setup(plan, attacks, combat, danger, removed, cost, null, not god is AphroditeAreia)
		if _is_better_strategy_plan(plan, best):
			best = plan
	return best

# Entropic Force shelves a face-up card you control into your deck and pays
# its level minus one in mana. The card is not destroyed — it returns through
# the draw cycle — so the price is only the target's residual board value,
# never its pristine card value. That makes Mummu's devalued fuel read as the
# ramp play it is: expired Warding Stones, debuffed bodies, summons that are
# destroyed at this turn's end (Tablet of Life's resurrection), and borrowed
# bodies about to return to the opponent. Healthy cards only shelve when the
# mana still matters, which marginal mana pricing plus the summon-funding
# bonus below cover.
func _plan_mummu_entropic_force(god: Mummu, target: Card, safety_gain: int) -> Dictionary:
	if match_manager.can_attack(target) and _can_attack_followers_safely(target) \
			and game_manager.get_creature_action_mana_cost(target, "attack") <= bot_player.mana:
		# The target still holds a safe direct attack, and recoil cannot
		# take the banked card away faster than its own turn-end expiry:
		# spend that attack first and shelve on the next planning pass.
		return {}
	var mana := maxi(0, target.get_effective_level() - 1)
	var score := safety_gain
	if game_manager.can_player_gain_mana_now(bot_player):
		score += CardStrategy.mana_gain_value(self, mana)
		if _mummu_shelve_funds_summon(mana):
			# The shelved card's mana completes this turn's summon.
			@warning_ignore("integer_division")
			score += ECON_CARD_VALUE / 2
	if _is_destroyed_at_this_turns_end(target):
		# The body leaves for the graveyard at this turn's end regardless;
		# shelving banks it back into the deck instead of losing it.
		@warning_ignore("integer_division")
		score += ECON_CARD_VALUE / 2
	elif game_manager.is_temporarily_controlled(target):
		# The borrowed body returns to the opponent at this turn's end;
		# Entropic Force ends the control early, burying the card in their
		# deck bottom while pocketing the mana.
		@warning_ignore("integer_division")
		score += _get_card_economic_value(target) * 3 / 4
	else:
		# The card shelves into the deck bottom, not the hand: with 35+ card
		# decks and one draw per turn, a shelved card is out of this match
		# long before the draw cycle reaches it. Price the FULL economic
		# value of the deployed body — the card is a real loss, and so is
		# the board presence (tempo, and the follower exposure the safety
		# gain already charges). Healthy bodies therefore only shelve when
		# the mana is genuinely critical; devalued fuel (expired stones,
		# debuffed bodies) already reads as cheap here because its economic
		# value is what collapsed, not the shelve price.
		score -= _get_card_economic_value(target)
	if score <= 0:
		return {}
	return {"score": score, "command": {"type": "god_ability", "god_uid": god.uid, "target_uid": target.uid}}

# True when Entropic Force's mana converts a currently unaffordable hand
# creature into this turn's summon.
func _mummu_shelve_funds_summon(mana: int) -> bool:
	if mana <= 0 or bot_player.hand_zone.cards.is_empty():
		return false
	if _get_best_affordable_hand_creature(0) != null:
		return false
	return _get_best_affordable_hand_creature(mana) != null

# What shelving this own card through Entropic Force gains over letting a
# planned wipe destroy it: the card banks into the deck instead of the
# graveyard and Mummu pockets its level minus one in mana. Zero when Mummu
# cannot act, the card is not a legal Entropic Force target, or a destruction
# replacement already recovers the card somewhere better than the deck bottom.
func _mummu_wipe_shelve_credit(target: Card) -> int:
	if target == null or target.get_controller() != bot_player \
			or target.is_face_down or target.current_zone == null \
			or not target.current_zone.is_board_zone():
		return 0
	if target.has_method("get_self_graveyard_replacement_zone"):
		var replacement: Zone = target.get_self_graveyard_replacement_zone(game_manager, false, true, false)
		if replacement != null and not replacement.is_board_zone():
			# A hand recovery (Draug Revenant and friends) beats a deck-bottom
			# shelf; let the wipe take the card and keep Mummu's activation.
			return 0
	var god := _find_player_god()
	if god == null or not (god is Mummu) or not god.can_activate(game_manager) \
			or game_manager.is_immune_to_source(target, god):
		return 0
	@warning_ignore("integer_division")
	var credit := ECON_CARD_VALUE / 2
	if game_manager.can_player_gain_mana_now(bot_player):
		credit += CardStrategy.mana_gain_value(self, maxi(0, target.get_effective_level() - 1))
	return credit

# Own board cards the planned wipe would destroy that Mummu should shelve
# first, derived from the same doomed list the wipe scoring charges.
func _mummu_wipe_shelve_targets(wipe: Card) -> Array[Card]:
	var targets: Array[Card] = []
	if wipe == null:
		return targets
	for doomed: Card in CardStrategy.removal_targets(self, wipe, null):
		if doomed.get_controller() == bot_player and _mummu_wipe_shelve_credit(doomed) > 0:
			targets.append(doomed)
	return targets

# The wipe line's own doomed cards leave through Entropic Force before the
# sweep resolves: submit the next profitable shelf, or {} when none remain.
func _next_mummu_wipe_shelve_command(wipe_uid: String) -> Dictionary:
	var god := _find_player_god()
	if god == null or not (god is Mummu):
		return {}
	var wipe := game_manager.get_card_by_uid(wipe_uid)
	if wipe == null:
		return {}
	for target in _mummu_wipe_shelve_targets(wipe):
		return {"type": "god_ability", "god_uid": god.uid, "target_uid": target.uid}
	return {}

# A prepared The Deluge only resolves off a summon event, so on a board where
# the sweep nets more than the cheapest legal trigger, Mummu plays a throwaway
# body and answers his own summon. Own cards the sweep would destroy but which
# are worth more shelved leave through Entropic Force first: mummu_shelve_setup
# submits those god abilities ahead of the summon, and the priority response
# fires the prepared Deluge on the thinned board.
func _plan_self_deluge(danger: int) -> Dictionary:
	var deluge := _get_own_prepared_deluge()
	if deluge == null or bot_player.has_summoned_this_turn:
		return {}
	var shelves := _mummu_wipe_shelve_targets(deluge)
	var shelf_mana := 0
	for target in shelves:
		shelf_mana += maxi(0, target.get_effective_level() - 1)
	var budget := bot_player.mana + shelf_mana
	var activation := CardStrategy.activation_cost(self, deluge)
	if activation > budget:
		# The Deluge must stay payable after the trigger resolves; the shelf
		# mana is already banked into the budget above.
		return {}
	# The wipe branch charges own doomed cards at full value and credits the
	# Entropic Force alternative (main phase, action == null), so this base is
	# the sweep's net on the pre-shelve board including every planned shelf.
	var base := CardStrategy.effect_score(self, deluge, null, null)
	if base <= 0:
		return {}
	var doomed_removed: Array = []
	for doomed: Card in CardStrategy.removal_targets(self, deluge, null):
		doomed_removed.append(doomed)
	var best_trigger := {}
	for zone in _get_open_summon_lane_candidates(bot_player):
		for creature: Card in bot_player.hand_zone.cards:
			if creature.sacrifice_cost > 0 or creature.discard_cost > 0 \
					or creature.banish_cost > 0 or creature.shelve_cost > 0 \
					or not (creature is CreatureCard) \
					or not creature.can_be_played(game_manager, bot_player):
				continue
			var cost := _get_play_cost(creature, false)
			if cost > budget - activation:
				# The Deluge must stay payable after the trigger resolves.
				continue
			var command := _build_creature_play_command(creature, zone, Card.CreatureMode.DEFENSIVE, -1, false, budget)
			if command.is_empty():
				continue
			# The summon event must fire, so the trigger stays face-up.
			command["stealth"] = false
			var trigger_loss := CardStrategy.value(self, creature) \
				+ CardStrategy.mana_penalty(self, cost, budget)
			if not best_trigger.is_empty() and trigger_loss >= int(best_trigger["loss"]):
				continue
			best_trigger = {"command": command, "loss": trigger_loss, "cost": cost}
	if best_trigger.is_empty():
		return {}
	var line := base - int(best_trigger["loss"])
	# The priority response will add the same follower-safety term over the
	# whole doomed set (_score_priority_card), so the plan prices the wipe the
	# way the prompt will.
	if danger > 0 and not doomed_removed.is_empty():
		line += _follower_safety_gain(danger, {"removed": doomed_removed},
			budget - int(best_trigger["cost"]) - activation)
	if line <= 0:
		return {}
	var plan := {"command": best_trigger["command"], "score": line}
	if not shelves.is_empty():
		plan["mummu_shelve_setup"] = deluge.uid
	return plan

func _get_own_prepared_deluge() -> TheDeluge:
	if game_manager == null or bot_player == null:
		return null
	for hex: Card in game_manager.prepared_hexes:
		if not (hex is TheDeluge) or hex.get_controller() != bot_player:
			continue
		if hex.is_muted or hex.is_activation_locked(game_manager) \
				or _status_persists_to_next_turn(hex, "activation_locked"):
			continue
		# A hex prepared this turn cannot respond until the next upkeep.
		if int(game_manager.prepared_hexes.get(hex, game_manager.turn_number)) >= game_manager.turn_number:
			continue
		# Special payment costs would fight the shelf sequence (the shelved
		# bodies leave before the sweep resolves), so this line stays clean.
		if hex.sacrifice_cost > 0 or hex.discard_cost > 0 \
				or hex.shelve_cost > 0 or hex.banish_cost > 0:
			continue
		return hex as TheDeluge
	return null

# With Mummu leading, a temporary control effect is more than a one-turn
# borrow: Entropic Force can end the control early by shelving the borrowed
# card into its owner's deck, banking the level mana and denying the redeploy.
func _mummu_temporary_control_bonus(target: Card) -> int:
	if target == null or game_manager == null or bot_player == null:
		return 0
	var god := _find_player_god()
	if god == null or not (god is Mummu) or not god.can_use_god_power(game_manager):
		return 0
	if game_manager.is_immune_to_source(target, god) or not game_manager.can_player_gain_mana_now(bot_player):
		return 0
	# The stolen body itself becomes face-up board presence the bot controls,
	# so Entropic Force's precondition holds once the steal resolves.
	@warning_ignore("integer_division")
	return _get_card_economic_value(target) * 3 / 4 \
		+ CardStrategy.mana_gain_value(self, maxi(0, target.get_effective_level() - 1))

# True when the card is destroyed at this turn's end (Tablet of Life's
# resurrection is the known source).
func _is_destroyed_at_this_turns_end(card: Card) -> bool:
	if card == null or not card.has_status_effect(TabletOfLife.DESTROY_AT_TURN_END_STATUS):
		return false
	return int(card.get_status_effect(TabletOfLife.DESTROY_AT_TURN_END_STATUS).get("expires_turn", -1)) <= game_manager.turn_number

# --- Mummu, Active God Entropy ----------------------------------------------
# Entropy lets the Mummu controller Prime or Shelve any card Mummu destroys.
# The alternative to shelve is prime, never the graveyard, so the two
# placements are compared directly. Prime is the default: the victim rides
# its owner's next draw, burning a fresh topdeck (worst for a thin hand
# desperate for answers), and a body that cannot answer Mummu only comes
# back to be destroyed and re-primed. The lock still matters against a fat
# hand, fading to a floor instead of zero. Shelve wins only when the
# victim's return would threaten Mummu itself.

# Prime's advantage over shelve: the draw-lock value minus the threat of
# handing the card back on top of its owner's deck.
func _mummu_prime_placement_delta(mummu: Card, victim: Card, owner: Player) -> int:
	if victim == null or owner == null:
		return 0
	return _mummu_prime_lock_value(owner) - _mummu_prime_return_cost(mummu, victim)

# The locked draw hurts most when the owner is topdecking for answers, but
# it is never worthless: hands play out, the primed non-answer keeps
# squatting on the topdeck, and the known card stays free information. The
# denial fades with hand size down to a floor instead of reaching zero.
func _mummu_prime_lock_value(owner: Player) -> int:
	if owner == null or owner.hand_zone == null:
		return 0
	var hand := owner.hand_zone.cards.size()
	@warning_ignore("integer_division")
	var base := ECON_CARD_VALUE / 2
	@warning_ignore("integer_division")
	return maxi(base / 5, base * clampi(6 - hand, 1, 6) / 6)

# What the victim is worth when it returns: only a genuine combat answer to
# Mummu makes priming expensive. Bodies that cannot punch through Mummu
# redeploy just to be destroyed and re-primed, so they price as pure lock.
func _mummu_prime_return_cost(mummu: Card, victim: Card) -> int:
	if mummu == null or victim == null or not CardStrategy.visible(self, victim):
		return 0
	if _would_destroy_target_in_battle(victim, mummu):
		@warning_ignore("integer_division")
		return _get_card_economic_value(victim) * 3 / 4
	return 0

# Entropy prompt from our Mummu Active: prime a stolen body back onto our
# own deck, prime non-answers for the draw lock, shelve what answers Mummu.
func _choose_mummu_entropy_placement(mummu: Card, victim: Card) -> String:
	if victim == null:
		return MummuActive.ENTROPY_PRIME
	if victim.card_owner == bot_player:
		return MummuActive.ENTROPY_PRIME
	if _mummu_prime_placement_delta(mummu, victim, victim.card_owner) > 0:
		return MummuActive.ENTROPY_PRIME
	return MummuActive.ENTROPY_SHELVE

# Entropy replaces the plain graveyard death for cards a Mummu Active
# destroys in a projected combat — declared targets, interceptors, and
# recoil-killed attackers all qualify. Tag the economy with the Mummu side's
# best placement so attack, interception, and reply projections price the
# lock (and the answer-denial shelve) from the right perspective.
func _add_mummu_entropy_combat_value(action: CardAction, defender: Card, result: Dictionary) -> void:
	if action == null or action.attacker == null:
		return
	var mummu: Card = null
	var victims: Array[Card] = []
	if action.attacker is MummuActive and not action.attacker.abilities_suppressed():
		# Entropy fires for the declared target and for an interceptor that
		# dies to the attack.
		var defender_card := _get_attack_defender_card(action)
		if defender_card != null and defender_card in result["casualties"] \
				and defender_card.get_controller() != action.attacker.get_controller():
			mummu = action.attacker
			victims.append(defender_card)
	if defender is MummuActive and not defender.abilities_suppressed() \
			and action.attacker in result["casualties"] \
			and action.attacker.get_controller() != defender.get_controller():
		# Recoil kill: Mummu destroyed the attacking creature while defending.
		mummu = defender
		victims.append(action.attacker)
	if mummu == null or victims.is_empty():
		return
	var mummu_side := mummu.get_controller()
	var delta := 0
	for victim: Card in victims:
		if victim.card_owner == mummu_side:
			# A stolen body returns to its true owner's deck top: recovery.
			@warning_ignore("integer_division")
			delta += ECON_CARD_VALUE / 4
		else:
			delta += _mummu_prime_placement_delta(mummu, victim, victim.card_owner)
	if delta == 0:
		return
	result["mummu_entropy_value"] = int(result.get("mummu_entropy_value", 0)) \
		+ (delta if mummu_side == bot_player else -delta)

func _plan_defensive_attack(attacks: Array[Dictionary], danger: int) -> Dictionary:
	var best := {}
	for attack in attacks:
		if _attack_has_remaining_barrier(attack, []) or int(attack["mana_cost"]) > bot_player.mana:
			continue
		var results: Array = [attack["base"]]
		results.append_array(attack["replies"].values())
		var score := 1000000
		for result: Dictionary in results:
			if result.is_empty() or result["opponent_wins"]:
				score = 0
				break
			# Treat enemy returns as potential threats on their next turn.
			var removed: Array = result["casualties"].duplicate()
			for card: Card in result.get("returning_casualties", []):
				if card.get_controller() == opponent:
					removed.erase(card)
			var gain := _follower_safety_gain(danger, {
				"removed": removed,
				"summons": result.get("scavenge_summons", {}),
				"defensive_summons": game_manager._any_active_structure_forces_defensive_summon(),
				"committed_attackers": [attack["attacker"], attack["partner"]],
				"followers": bot_player.followers - int(result["bot_followers_lost"]) + int(result.get("bot_followers_gained", 0)),
				"guard": bot_player.guard - int(result.get("bot_guard_spent", 0)),
			}, bot_player.mana - int(attack["mana_cost"]) + _combat_mana_gain(result, []))
			@warning_ignore("integer_division")
			score = mini(score, gain + _score_attack_economy(result) / 4)
		if score > int(best.get("score", 0)):
			var target = attack["target"]
			best = {"score": score, "command": {"type": "request_attack", "attacker_uid": attack["attacker"].uid, "target_id": str(game_manager.players.find(target)) if target is Player else target.uid}}
	return best

# Scored lines supply the mana left to answer the opponent after the projected play.
func _follower_safety_gain(danger: int, change: Dictionary, mana_left: int, include_immediate_change: bool = true) -> int:
	if danger < 0:
		return 0
	var followers := int(change.get("followers", bot_player.followers))
	var after := followers - _forecast_incoming_follower_loss(change.merged({"mana_left": mana_left}, true))
	# A play or combat can already score the immediate change. Its safety
	# still depends on the total left after the opponent's projected turn.
	var immediate_change := 0 if include_immediate_change else CardStrategy.follower_change_value(bot_player.followers, followers)
	return _score_follower_safety(bot_player.followers - danger, after, immediate_change)

func _score_follower_safety(before: int, after: int, scored_immediate_change: int = 0) -> int:
	if before <= 0:
		return ECON_CARD_VALUE * 30 + CardStrategy.follower_change_value(0, after) if after > 0 else 0
	if after <= 0:
		return -ECON_CARD_VALUE * 30
	var gain := CardStrategy.follower_change_value(before, after) - scored_immediate_change
	return roundi(gain * _posture_safety_multiplier())

# Preservation-only defensive stance switches trade attack tempo for card
# safety. That trade is only worth it when the follower pool is actually
# scarce (or close to defeat), not as a routine play while followers are
# healthy. Followers start at 100 and follower-economy scoring already
# treats 50 as pressure and 25 as scarcity.
func _is_dangerously_low_on_followers() -> bool:
	if opponent == null:
		return bot_player.followers <= 25
	return bot_player.followers <= 25 or bot_player.followers * 2 <= opponent.followers

func _single_creature_removal_discount(source: Card, removed: Array) -> int:
	if removed.size() != 1 or not source.goes_to_graveyard_after_use():
		return 0
	var target := removed[0] as Card
	if target.get_controller() != opponent or not CardStrategy.visible(self, target) \
			or target.card_type != Card.CardType.CREATURE:
		return 0
	var hold_value := SINGLE_TARGET_REMOVAL_HOLD_VALUE
	if target.card_owner == bot_player and not target.is_enslaved():
		return hold_value
	var this_turn := game_manager.current_player == bot_player
	if game_manager.attack_restrictions.has(bot_player) or (this_turn and game_manager.turn_number <= 1):
		return hold_value
	var mana := bot_player.mana
	if not this_turn:
		mana += game_manager.get_automatic_upkeep_mana_gain(bot_player, game_manager.turn_number + 1) \
			+ game_manager.get_effective_upkeep_mana_gain(game_manager.get_base_upkeep_draw_mana_gain(), bot_player)
	# A combat kill spends an attack and can be disrupted before it resolves.
	@warning_ignore("integer_division")
	var combat_credit := CardStrategy.value(self, target) / 2
	var mana_rate := _mana_rate()
	var best := 0
	for attacker in _get_board_creatures(bot_player):
		if attacker.get_controller() != bot_player or attacker.current_zone not in bot_player.frontline_zones or attacker.is_petrified() \
				or (attacker.creature_mode != Card.CreatureMode.AGGRESSIVE and not attacker.is_stealth) \
				or (attacker.is_face_down and not attacker.is_stealth):
			continue
		if this_turn and not _can_attack_after_priority(attacker):
			continue
		if not this_turn and (attacker.is_paralyzed() or _status_persists_to_next_turn(attacker, "sleep") \
				or _status_persists_to_next_turn(attacker, "cannot_attack")):
			continue
		var cost := game_manager.get_creature_action_mana_cost(attacker, "attack")
		var credit := combat_credit - cost * mana_rate
		if cost <= mana and credit > best and _has_clean_removal_attack(attacker, target):
			best = credit
	var zone := _get_central_open_zone(bot_player.frontline_zones)
	if zone == null or (this_turn and game_manager.has_resolved_attack_this_turn) \
			or game_manager._any_active_structure_forces_defensive_summon():
		return hold_value + best
	for recruit in bot_player.hand_zone.cards:
		if recruit.card_type != Card.CardType.CREATURE or recruit.sacrifice_cost > 0 or recruit.discard_cost > 0 \
				or (recruit is ActiveGodCard and not recruit.can_be_played(game_manager, bot_player)) \
				or game_manager.is_first_turn_attack_blocked_by_weather(recruit, true):
			continue
		if this_turn and bot_player.has_summoned_this_turn and not game_manager._can_use_extra_normal_summon(bot_player, recruit, zone):
			continue
		var summon_cost := _get_play_cost(recruit, false)
		var attack_cost := game_manager.get_creature_action_mana_cost(recruit, "attack")
		# The summon still develops a body, so allocate part of its cost to the kill.
		@warning_ignore("integer_division")
		var credit := combat_credit - attack_cost * mana_rate - summon_cost * mana_rate / 2
		if summon_cost + attack_cost > mana or credit <= best or not _can_evaluate_creature_play(recruit, zone, mana) \
				or _known_entry_response_penalty(recruit, zone, false) > 0:
			continue
		if _has_clean_removal_attack(recruit, target, zone):
			best = credit
	return hold_value + best

func _has_clean_removal_attack(attacker: Card, target: Card, summon_zone: Zone = null) -> bool:
	var partner := match_manager._get_declared_attack_partner(attacker) if summon_zone == null else null
	for attack in _get_attack_candidates(attacker, partner, summon_zone != null, null, 0, null, {}, summon_zone, target):
		if _attack_has_remaining_barrier(attack, []):
			continue
		var outcomes: Array = [attack["base"]]
		outcomes.append_array(attack["replies"].values())
		return outcomes.all(func(outcome: Dictionary) -> bool:
			return target in outcome.get("casualties", []) and target not in outcome.get("returning_casualties", []) \
				and attacker not in outcome["casualties"] and int(outcome.get("bot_cards_lost", 0)) == 0 \
				and not bool(outcome.get("opponent_wins", false))
		)
	return false

func _can_attack_after_priority(attacker: Card) -> bool:
	# MatchManager.can_attack also checks whether priority is still resolving.
	return game_manager.turn_number > 1 and attacker.can_take_major_creature_action() \
		and not attacker.summoned_after_first_attack_this_turn and not game_manager.is_first_turn_attack_blocked_by_weather(attacker) \
		and not attacker.is_sleeping and not attacker.is_paralyzed() and not attacker.has_status_effect("cannot_attack") \
		and (not attacker.is_face_down or attacker.is_stealth)

func _current_turn_removal_safety(removed: Array) -> int:
	var before := _forecast_incoming_follower_loss({}, true)
	if before <= 0:
		return 0
	var after := _forecast_incoming_follower_loss({"removed": removed}, true)
	var gain := _score_follower_safety(bot_player.followers - before, bot_player.followers - after)
	if before >= bot_player.followers or after >= bot_player.followers:
		return gain
	# A healthy follower pool can absorb some damage while the bot saves its answer.
	var urgency := clampf(1.0 - float(bot_player.followers - before) / 100.0, 0.25, 1.0)
	return roundi(gain * urgency)

func _estimate_saving_grace_turn_loss(action: CardAction, outcome: Dictionary) -> int:
	var loss := int(outcome["bot_followers_lost"])
	if game_manager.current_player != opponent or loss >= bot_player.followers:
		return loss
	# Count follow-up damage the ward would also stop, with the guard and
	# followers left after this attack. The committed attackers can't go again.
	var committed: Array[Card] = [action.attacker]
	if action.united_front_partner != null:
		committed.append(action.united_front_partner)
	return loss + _forecast_incoming_follower_loss({
		"removed": committed,
		"guard": maxi(0, bot_player.guard - int(outcome.get("bot_guard_spent", 0))),
		"followers": bot_player.followers - loss,
	}, true)

func _ward_would_flip_on_followup(outcome: Dictionary, total_loss: int, ward_cost: int) -> bool:
	# Replays the ward's own response test for the next attack this turn,
	# priced after this attack's damage and guard are already spent. A flip
	# that is committed at the follow-up window is strictly better landed
	# now: the mana price is unchanged and this attack's damage comes back.
	if game_manager.current_player != opponent:
		return false
	var loss := int(outcome["bot_followers_lost"])
	var followup := total_loss - loss
	if followup <= 0:
		return false
	var followers := bot_player.followers - loss
	if followers <= 0:
		return false
	var next_score := _score_follower_loss(bot_player, followup, followers) \
		- CardStrategy.mana_penalty(self, ward_cost)
	if next_score <= 0 or followup >= followers:
		return next_score > 0
	var loss_share := float(followup) / float(followers)
	var hold_value := CardStrategy.CARD_VALUE * (1.0 - loss_share * loss_share)
	if _expects_saving_grace_board_blocker(ward_cost):
		hold_value *= 0.5
	return next_score - roundi(hold_value) > 0

func _expects_saving_grace_board_blocker(ward_cost: int) -> bool:
	var mana := bot_player.mana - ward_cost
	var next_turn := game_manager.current_player != bot_player
	if next_turn:
		mana += game_manager.get_automatic_upkeep_mana_gain(bot_player, game_manager.turn_number + 1)
		mana += game_manager.get_effective_upkeep_mana_gain(game_manager.get_base_upkeep_draw_mana_gain(), bot_player)
	var summon_zone := _get_first_open_summon_zone(bot_player)
	if summon_zone != null and (next_turn or not bot_player.has_summoned_this_turn):
		for card: Card in bot_player.hand_zone.cards:
			# Red Cap normally leaves the field on its own when it attacks.
			if not (card is RedCap or card is ActiveGodCard) and _can_evaluate_creature_play(card, summon_zone, mana) \
					and _score_projected_card(card) > 0:
				return true
	var reserve := _get_first_open_reserve_zone(bot_player)
	if reserve == null:
		return false
	for card: Card in bot_player.hand_zone.cards:
		if not card.is_magical_card() or not CardStrategy.supported(card) \
				or (card is SpellCard and not game_manager.spells_must_be_prepared()) \
				or not game_manager.get_prepare_card_failure_reason(bot_player, card, reserve, true).is_empty():
			continue
		var cost := _get_play_cost(card, true)
		if cost > mana:
			continue
		var score := CardStrategy.preparation_score(self, card)
		if card is SpellCard:
			var target := CardStrategy.best_target(self, card, CardStrategy.targets(self, card))
			score = CardStrategy.effect_score(self, card, target)
		if score > 0 and score > CardStrategy.mana_penalty(self, cost, mana) + CardStrategy.preparation_removal_penalty(self, card):
			return true
	return false

func _warding_stone_safety_gain(danger: int, followers: int, removed: Array = []) -> int:
	if not bot_player.followers_enabled or game_manager.attack_restrictions.has(opponent):
		return 0
	var safe_followers := followers - _forecast_incoming_follower_loss({
		"removed": removed, "followers": followers, "block_attacks": true,
	})
	var immediate := CardStrategy.follower_change_value(bot_player.followers, followers)
	var recruits := _projected_warding_stone_recruits()
	var known_danger := danger if danger >= 0 else _forecast_incoming_follower_loss()
	var known: Dictionary = recruits["known"]
	if not known.is_empty():
		known_danger = maxi(known_danger, _forecast_incoming_follower_loss({}, false, known))
	var gain := _score_follower_safety(bot_player.followers - known_danger, safe_followers, immediate)
	var possible: Dictionary = recruits["possible"]
	if possible.is_empty() or safe_followers <= 0 or known_danger >= bot_player.followers:
		return gain
	var possible_danger := _forecast_incoming_follower_loss({}, false, possible)
	if possible_danger > known_danger:
		var possible_gain := _score_follower_safety(bot_player.followers - possible_danger, safe_followers, immediate)
		# A plausible unknown summon matters near defeat, but cannot get the
		# full priority of a lethal attack we can see.
		@warning_ignore("integer_division")
		gain += mini(possible_gain - gain, ECON_CARD_VALUE * 4) / 2
	return gain

func _projected_warding_stone_recruits() -> Dictionary:
	var known := {}
	var possible := {}
	var result := {"known": known, "possible": possible}
	var zone := _get_central_open_zone(opponent.frontline_zones)
	if zone == null:
		return result
	var base_mana := opponent.mana + game_manager.get_automatic_upkeep_mana_gain(opponent, game_manager.turn_number + 1)
	var mana_budget := base_mana + game_manager.get_effective_upkeep_mana_gain(game_manager.get_base_upkeep_mana_gain(), opponent)
	var draw_budget := base_mana + game_manager.get_effective_upkeep_mana_gain(game_manager.get_base_upkeep_draw_mana_gain(), opponent)
	var unknown_budget := -1
	var cards: Array[Card] = opponent.hand_zone.cards.duplicate()
	var top := opponent.deck_zone.known_top_card
	if not opponent.deck_zone.cards.is_empty():
		if CardStrategy.visible(self, top):
			cards.append(top)
		else:
			unknown_budget = draw_budget
	for card in cards:
		if not CardStrategy.visible(self, card):
			unknown_budget = mana_budget
			continue
		if not card is CreatureCard or card.is_god or card.sacrifice_cost > 0 or card.discard_cost > 0 \
				or card.shelve_cost > 0 or card.banish_cost > 0 \
				or game_manager.is_first_turn_attack_blocked_by_weather(card, true):
			continue
		var cost := game_manager.get_creature_summon_mana_cost(opponent, card)
		if card == top:
			cost += mana_budget - draw_budget
		if cost + game_manager.get_creature_action_mana_cost(card, "attack") > mana_budget:
			continue
		var recruit := _preview_board_creature(card, zone)
		recruit.is_face_down = false
		recruit.is_stealth = false
		recruit.creature_mode = Card.CreatureMode.AGGRESSIVE
		known[recruit] = cost
	if unknown_budget > 0:
		# Use only public mana and card counts to model a typical incoming body.
		var recruit := CreatureCard.new()
		recruit.card_owner = opponent
		recruit.current_zone = zone
		recruit.creature_mode = Card.CreatureMode.AGGRESSIVE
		recruit.strength = mini(24, unknown_budget * ECON_FORECAST_SUMMON_STR_PER_MANA)
		recruit.speed = 2
		if not game_manager.is_first_turn_attack_blocked_by_weather(recruit, true):
			possible[recruit] = mana_budget - unknown_budget + ceili(float(recruit.strength) / ECON_FORECAST_SUMMON_STR_PER_MANA)
	return result

func _forecast_incoming_follower_loss(change: Dictionary = {}, this_turn: bool = false, recruits: Dictionary = {}) -> int:
	if not bot_player.followers_enabled or opponent == null:
		return 0
	var removed: Array = change.get("removed", []).duplicate()
	var followers := int(change.get("followers", bot_player.followers))
	var upkeep_loss := 0 if this_turn else _projected_upkeep_follower_loss(removed, followers)
	var followers_after_upkeep := maxi(0, followers - upkeep_loss)
	if bool(change.get("block_attacks", false)) or followers_after_upkeep <= 0:
		return mini(followers, upkeep_loss)
	if game_manager.current_player == bot_player:
		for creature in _get_board_creatures(bot_player):
			if creature is RedCap and not creature.abilities_suppressed() and not creature._resolved_attack_this_turn \
					and creature not in change.get("committed_attackers", []) \
					and CardStrategy.can_remove_from_board(self, creature, creature, true, false):
				removed.append(creature)
	var restriction: Dictionary = game_manager.attack_restrictions.get(opponent, {})
	if not restriction.is_empty() and restriction.get("source") not in removed:
		return mini(followers, upkeep_loss)
	var prevention: Dictionary = game_manager.turn_follower_loss_preventions.get(bot_player, {})
	if int(prevention.get("expires_turn", -1)) >= game_manager.turn_number + (0 if this_turn else 1) \
			and prevention.get("source_card") not in removed:
		return mini(followers, upkeep_loss)

	var targets: Array = [bot_player]
	var defenders := _get_board_creatures(bot_player)
	# A temporarily controlled body (Siren's Song) returns to its owner at
	# this turn's end, before the forecasted attack window opens: it neither
	# guards the bot's followers nor intercepts for them, and an aggressive
	# frontline borrow comes back as one of the opponent's attackers instead.
	var returning_attackers: Array[Card] = []
	var standing_defenders: Array[Card] = []
	for card in defenders:
		if game_manager.is_temporarily_controlled(card):
			returning_attackers.append(card)
		else:
			standing_defenders.append(card)
	if not returning_attackers.is_empty():
		defenders = standing_defenders
	var summon := change.get("summon") as Card
	var stance := change.get("stance") as Card
	var defensive := bool(change.get("defensive", false))
	var summon_zone := change.get("zone") as Zone
	var summon_stealth := bool(change.get("stealth", false))
	var summons: Dictionary = change.get("summons", {}).duplicate()
	var defensive_summons := bool(change.get("defensive_summons", false))
	var moved := change.get("moved") as Card
	var destination := change.get("destination") as Zone
	var shifting := change.get("shifting") as Card
	var shifted_form := change.get("shifted_form") as Card
	var stats: Dictionary = change.get("combat_stats", {})
	if shifted_form != null:
		stats = stats.duplicate()
		stats[shifting] = _shift_stat_changes(shifting, shifted_form)
	if summon != null:
		summons[summon] = summon_zone
	var summoned_forms := {}
	for recruit: Card in summons:
		defenders.append(recruit)
		summoned_forms[recruit] = _preview_summoned_creature(recruit, summons[recruit], summon_stealth and recruit == summon)
	var structures := game_manager._get_active_structures()
	for card in defenders:
		if card not in removed:
			targets.append(card)
	for structure in structures:
		if structure.get_controller() == bot_player and structure not in removed:
			targets.append(structure)

	var attack_lines: Array[Dictionary] = []
	var budget := opponent.mana
	if not this_turn:
		budget += game_manager.get_automatic_upkeep_mana_gain(opponent, game_manager.turn_number + 1) \
			+ game_manager.get_effective_upkeep_mana_gain(game_manager.get_base_upkeep_mana_gain(), opponent)
	var attackers := _get_board_creatures(opponent)
	attackers.append_array(returning_attackers)
	var champions_call := {} if this_turn else _projected_champions_call(removed)
	var manifestation := champions_call.get("attacker") as Card
	if manifestation != null:
		attackers.append(manifestation)
	attackers.append_array(recruits.keys())
	var mana_left := maxi(0, int(change.get("mana_left", bot_player.mana)))
	for attacker in attackers:
		var attack_zone := destination if attacker == moved else attacker.current_zone
		var attacker_aggressive := attacker.creature_mode == Card.CreatureMode.AGGRESSIVE or attacker.is_stealth
		# A defensive frontline creature flips stance as a minor action and
		# keeps its major action for the attack, so it can still threaten the
		# followers next turn. The flip's mana is charged into the attack cost
		# below, and the affordability check there gates the assumption.
		var assumes_stance_flip := false
		if not attacker_aggressive and not this_turn and attack_zone != null \
				and attack_zone.zone_type == Zone.ZoneType.FRONTLINE \
				and attacker.get_max_minor_creature_actions_per_turn() >= 1:
			attacker_aggressive = true
			assumes_stance_flip = true
		if attacker == stance:
			attacker_aggressive = not defensive
		if attacker in removed or attacker == change.get("disable_attacker") or not CardStrategy.visible(self, attacker) \
				or (attacker.get_controller() != opponent and not game_manager.is_temporarily_controlled(attacker)) \
				or attack_zone == null or attack_zone.zone_type != Zone.ZoneType.FRONTLINE \
				or not attacker_aggressive \
				or attacker.is_petrified() or _status_persists_to_next_turn(attacker, "sleep", removed) \
				or _status_persists_to_next_turn(attacker, "cannot_attack", removed):
			continue
		if this_turn and not _can_attack_after_priority(attacker):
			continue
		var cost := game_manager.get_creature_action_mana_cost(attacker, "attack") + int(recruits.get(attacker, 0))
		if assumes_stance_flip:
			cost += game_manager.get_creature_action_mana_cost(attacker, "change stance")
		if attacker == manifestation:
			cost += int(champions_call["cost"])
		if cost > budget:
			continue
		var speed := attacker.get_effective_speed()
		for target in targets:
			var target_form: Variant = shifted_form if target == shifting else target
			if attacker == manifestation and _has_prepared_answer_to_champions_call(
				attacker, target_form as Card, mana_left, removed
			):
				continue
			if target is Card and not attacker.can_ignore_attack_targeting_restrictions(target) \
					and (not attacker.can_engage(target_form) or not target_form.can_be_engaged_by(attacker)):
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
			action.source_player = opponent
			action.attacker = attacker
			action.target = target
			var target_stance := target as Card if target in summons else stance
			var replies := {target: _forecast_incoming_combat(action, target_stance, (defensive and target == stance) or (defensive_summons and target in summons), summon_stealth and target == summon, removed, stats)}
			for interceptor in defenders:
				if interceptor == target or interceptor in removed or _status_persists_to_next_turn(interceptor, "cannot_intercept", removed):
					continue
				var projected_zone := destination if interceptor == moved else summons.get(interceptor) as Zone
				var mode := -1
				if interceptor == stance:
					mode = Card.CreatureMode.DEFENSIVE if defensive else Card.CreatureMode.AGGRESSIVE
				elif interceptor in summons:
					mode = Card.CreatureMode.DEFENSIVE if defensive_summons else Card.CreatureMode.AGGRESSIVE
				var target_zone := destination if target == moved else summons.get(target) as Zone
				var projected_stealth := summon_stealth and interceptor == summon
				var intercept_form: Card = summoned_forms.get(interceptor, shifted_form if interceptor == shifting else interceptor)
				var legal := match_manager._can_intercept(intercept_form, attacker, target_form, null, 0, speed, projected_zone, mode, target_zone)
				if not legal:
					continue
				action.interceptor = interceptor
				var interceptor_stance := interceptor if interceptor in summons else stance
				replies[interceptor] = _forecast_incoming_combat(action, interceptor_stance, (defensive and interceptor == stance) or (defensive_summons and interceptor in summons), projected_stealth, removed, stats)
			attack_lines.append({"attacker": attacker, "target": target, "replies": replies, "barriers": barriers, "cost": cost})
	var exposure := 0 if this_turn else _aphrodite_exposure_pulse()
	if attack_lines.is_empty():
		return mini(followers, upkeep_loss + exposure)
	var guard := int(change.get("guard", bot_player.guard))
	var most_damage := 0
	# The opponent chooses the attack and the bot chooses whether to intercept.
	# Recheck a second attack after each reply, with spent Guard and casualties carried forward.
	for line in attack_lines:
		if not line["barriers"].is_empty():
			continue
		var least_damage := followers_after_upkeep
		for first: Dictionary in line["replies"].values():
			var first_loss := _forecast_follower_damage(first, guard, followers_after_upkeep)
			if first_loss >= least_damage:
				continue
			var remaining_guard := maxi(0, guard - int(first["damage"]))
			var remaining_followers := followers_after_upkeep - first_loss
			var casualties: Array = first["casualties"]
			var followup := 0
			for second in attack_lines:
				if second["attacker"] == line["attacker"] or second["attacker"] in casualties or second["target"] in casualties \
						or int(line["cost"]) + int(second["cost"]) > budget:
					continue
				if recruits.has(line["attacker"]) and (recruits.has(second["attacker"]) or second["attacker"] == manifestation) \
						or line["attacker"] == manifestation and recruits.has(second["attacker"]):
					continue
				if second["barriers"].any(func(barrier: Card) -> bool: return barrier not in casualties):
					continue
				var second_loss := _forecast_follower_damage(second["replies"][second["target"]], remaining_guard, remaining_followers)
				for interceptor in second["replies"]:
					if interceptor not in casualties:
						second_loss = mini(second_loss, _forecast_follower_damage(second["replies"][interceptor], remaining_guard, remaining_followers))
				followup = maxi(followup, second_loss)
				if first_loss + followup >= least_damage:
					break
			least_damage = mini(least_damage, first_loss + followup)
		most_damage = maxi(most_damage, least_damage)
		if upkeep_loss + most_damage >= followers:
			break
	return mini(followers, upkeep_loss + most_damage + exposure)

func _projected_upkeep_follower_loss(removed: Array, projected_followers: int) -> int:
	if game_manager == null or opponent == null:
		return 0
	var prevention: Dictionary = game_manager.turn_follower_loss_preventions.get(bot_player, {})
	if int(prevention.get("expires_turn", -1)) > game_manager.turn_number \
			and prevention.get("source_card") not in removed:
		return 0
	var total := 0
	for source in game_manager.get_field_cards(opponent):
		if source == null or source in removed or not CardStrategy.visible(self, source) \
				or not source.has_method("get_projected_upkeep_follower_loss"):
			continue
		total += int(source.call(
			"get_projected_upkeep_follower_loss", game_manager, opponent, bot_player, removed
		))
	return mini(maxi(0, projected_followers), total)

func _status_persists_to_next_turn(card: Card, status_name: String, removed: Array = [], turn_offset: int = 1) -> bool:
	for status in card._get_effective_statuses():
		if status.get("name") == status_name and CardStrategy.status_duration(game_manager, card, status) > turn_offset:
			var source := status.get("source_card") as Card
			if source in removed and (source is Alu or source is Dromi or source is Gleipnir or source is HeavySnow):
				continue
			return true
	return false

func _forecast_incoming_combat(action: CardAction, stance: Card, defensive: bool, projected_stealth: bool, removed: Array, stats: Dictionary = {}) -> Dictionary:
	var defender := _get_attack_defender_card(action)
	var mode := -1
	if defender != null and defender == stance:
		mode = Card.CreatureMode.DEFENSIVE if defensive else Card.CreatureMode.AGGRESSIVE
	var result := _estimate_raw_attack_economy(action, stats, mode)
	if defender is Askelladen and _can_askelladen_retreat(defender, action.attacker, stats):
		return {"damage": 0, "casualties": [defender, action.attacker]}
	var damage_from_defender: bool = defender != null and (result.get("bot_loss_source") == defender \
		or result.get("defensive_conversion_defender") == defender)
	var halvings := int(action.halve_follower_damage) + GameManager.combat_follower_damage_halvings(
		action.attacker, defender, action.united_front_partner, damage_from_defender
	)
	var damage := GameManager.apply_follower_damage_halvings(int(result["bot_followers_lost"]), halvings)
	if (defender is MasmassuPriest or defender is Grindylow) and (projected_stealth or defender.is_stealth) \
			and not defender.has_veil_of_night():
		var targets := _get_reveal_removal_targets(defender)
		var target := _choose_combat_reveal_removal(defender, targets, action, result["casualties"] + removed)
		if target != null:
			result["casualties"].append(target)
	_add_expiring_combat_tokens(action, defender, result)
	# Her attack kills a bot creature, unlocking Violent Delights on HER turn;
	# the follow-up enslaved value must flow to the defense forecast.
	return {"damage": damage, "source": result.get("bot_loss_source"), "casualties": result["casualties"],
		"enslavement_risk": int(result.get("enslavement_risk", 0))}

func _forecast_follower_damage(result: Dictionary, guard: int, remaining_followers: int) -> int:
	var damage := maxi(0, int(result["damage"]) - guard)
	var source := result.get("source") as Card
	if game_manager._source_converts_combat_follower_damage(source):
		return game_manager._get_combat_follower_conversion_amount(source, damage, remaining_followers)
	return damage

func _get_combat_candidates(projected_mana: int = -1) -> Array[Dictionary]:
	var candidates: Array[Dictionary] = []
	for attacker in _get_attack_ready_creatures(projected_mana):
		if match_manager.can_attack(attacker):
			candidates.append_array(_get_attack_candidates(attacker, match_manager._get_declared_attack_partner(attacker)))
	return candidates

func _get_attack_candidates(attacker: Card, partner: Card, projected_summon: bool = false, modified_card: Card = null, speed_delta: int = 0, shifted_form: Card = null, summon_stats: Dictionary = {}, projected_zone: Zone = null, only_target: Card = null) -> Array[Dictionary]:
	var candidates: Array[Dictionary] = []
	var targets: Array = [only_target] if only_target != null else [opponent]
	if only_target == null:
		for card in game_manager.get_field_cards(opponent):
			if CardStrategy.visible(self, card) and card.card_type in [Card.CardType.CREATURE, Card.CardType.STRUCTURE]:
				targets.append(card)
	var attacker_form := shifted_form if shifted_form != null and attacker == modified_card else attacker
	if projected_zone != null:
		attacker_form = _preview_board_creature(attacker_form, projected_zone)
		attacker_form.creature_mode = Card.CreatureMode.AGGRESSIVE
	var impact_stats: Vector3i = summon_stats.get(attacker, Vector3i.ZERO) if projected_summon else Vector3i.ZERO
	var declared_form := attacker_form
	if attacker_form.will_reveal_in_combat():
		# The lead attacker normally reveals before the interception window.
		declared_form = _preview_board_creature(attacker_form, attacker_form.current_zone)
		declared_form.is_stealth = false
		declared_form.is_face_down = false
	var attack_speed := declared_form.get_effective_speed(impact_stats.z + (speed_delta if attacker == modified_card else 0))
	var partner_form := partner
	if partner != null:
		partner_form = shifted_form if shifted_form != null and partner == modified_card else partner
		attack_speed = mini(attack_speed, partner_form.get_effective_speed(speed_delta if partner == modified_card else 0))
	var allied_attackers := [partner_form] if partner_form != null else []
	var projected_strength_delta := _get_projected_strength(attacker) - attacker.get_effective_strength() if projected_summon else 0
	var stats := {}
	if projected_summon:
		stats[attacker] = impact_stats + Vector3i(projected_strength_delta, 0, 0)
	elif shifted_form != null:
		stats[modified_card] = _shift_stat_changes(modified_card, shifted_form)
	elif modified_card != null:
		stats[modified_card] = Vector3i(0, 0, speed_delta)
	var structures := game_manager._get_active_structures()
	for target in targets:
		if target is Card:
			if not projected_summon and (attacker_form.current_zone == null or not attacker_form.current_zone.is_board_zone() \
					or target.current_zone == null or not target.current_zone.is_board_zone()):
				continue
			if not game_manager.can_cards_engage_each_other(attacker_form, target, false):
				continue
		var barriers: Array[Card] = []
		for structure in structures:
			var blocks := structure.blocks_attack_on_followers(game_manager, attacker_form, opponent, allied_attackers) \
				if target is Player else structure.blocks_attack_on_target(game_manager, attacker_form, target, allied_attackers)
			if blocks:
				barriers.append(structure)
		var action := CardAction.new()
		action.type = CardAction.Type.ATTACK
		action.source_player = bot_player
		action.attacker = attacker
		action.united_front_partner = partner
		action.attack_speed_override = attack_speed
		action.target = target
		var base := _estimate_projected_attack_economy(action, stats)
		var replies := {}
		var interceptors := match_manager._get_possible_interceptors(attacker_form, target, attack_speed)
		for interceptor in interceptors:
			if CardStrategy.visible(self, interceptor):
				action.interceptor = interceptor
				replies[interceptor] = _estimate_projected_attack_economy(action, stats)
			else:
				replies[interceptor] = {}
		# A prepared response can fire against the original target or the chosen interceptor.
		action.attacker = attacker_form
		for defender: Card in [null] + interceptors:
			if defender != null and not CardStrategy.visible(self, defender):
				continue
			action.interceptor = defender
			for response in _get_known_attack_response_cards(action):
				if response in replies:
					continue
				var result := _estimate_known_attack_response(response, action, attacker)
				if not result.is_empty():
					replies[response] = result
		if not attacker_form.prevents_interception():
			for hidden in _get_board_creatures(opponent):
				if not CardStrategy.visible(self, hidden) and not hidden.has_status_effect("cannot_intercept") and not hidden.is_sleeping:
					replies[hidden] = {}
		candidates.append({
			"attacker": attacker, "partner": partner, "target": target, "base": base, "replies": replies,
			"barriers": barriers,
			"mana_cost": game_manager.get_creature_action_mana_cost(attacker, "attack"),
		})
	return candidates

func _get_known_attack_response_cards(action: CardAction) -> Array[Card]:
	var responses: Array[Card] = []
	if action == null or opponent == null:
		return responses
	for zone in opponent.frontline_zones + opponent.reserve_zones:
		for card in zone.cards:
			if not (card is TheInferno or card is VoidShield or card is Smite or card is DivineLightning or card is ObsidianReflection) or not CardStrategy.visible(self, card):
				continue
			if game_manager.can_card_respond_to_action(card, action, opponent):
				responses.append(card)
	# Revealed hand responses (Seer, Dellingr, effects that expose the hand)
	# are modeled exactly like their prepared counterparts, priced by mana.
	for card in opponent.hand_zone.cards:
		if not (card is TheInferno or card is VoidShield or card is Smite or card is DivineLightning) or not CardStrategy.visible(self, card):
			continue
		if opponent.mana < game_manager.get_card_play_mana_cost(opponent, card, false):
			continue
		if game_manager.can_card_respond_to_action(card, action, opponent):
			responses.append(card)
	return responses

func _estimate_known_attack_response(response: Card, action: CardAction, original_attacker: Card = null) -> Dictionary:
	var attacker := action.attacker if original_attacker == null else original_attacker
	var result := {
		"casualties": [],
		"bot_cards_lost": 0,
		"opponent_cards_lost": 0,
		"bot_followers_lost": 0,
		"opponent_followers_lost": 0,
		"bot_wins": false,
		"opponent_wins": false,
		"spent_hex": response,
	}
	if response is ObsidianReflection:
		var reversed_damage := _get_direct_follower_damage(action.attacker) if game_manager.can_player_lose_followers_now(bot_player) else 0
		result["bot_followers_lost"] = reversed_damage
		result["opponent_followers_lost"] = 0
	elif response is VoidShield or response is Smite:
		var destroys := response is Smite
		if not CardStrategy.can_remove_from_board(self, response, action.attacker, destroys):
			return {}
		_add_destroyed_card_to_economy(result, attacker)
	elif response is DivineLightning:
		# Single magical target, not a frontline wipe. Namburbi can save this
		# attacker, but pricing it as an area answer would overstate the threat.
		if action.attacker == null or action.attacker.current_zone not in bot_player.frontline_zones \
				or not response.is_valid_target(action.attacker) \
				or not CardStrategy.can_remove_from_board(self, response, action.attacker, true, false):
			return {}
		_add_destroyed_card_to_economy(result, attacker)
	else:
		if action.attacker.current_zone in bot_player.frontline_zones \
				and CardStrategy.can_remove_from_board(self, response, action.attacker, true, false):
			_add_destroyed_card_to_economy(result, attacker)
		for zone in bot_player.frontline_zones:
			for card in zone.cards:
				if card != attacker and CardStrategy.can_remove_from_board(self, response, card, true, false):
					_add_destroyed_card_to_economy(result, card)
		if result["casualties"].is_empty():
			return {}
	var mana_left := bot_player.mana - game_manager.get_creature_action_mana_cost(attacker, "attack")
	if attacker.current_zone == bot_player.hand_zone:
		mana_left -= _get_play_cost(attacker, false)
	result["hex_trade_credit"] = _known_hex_trade_credit(response, result["casualties"], mana_left, [attacker])
	return result

func _find_namburbi_ward_card(triggering_attack: CardAction = null) -> NamburbiApotropaeon:
	if game_manager == null or bot_player == null:
		return null
	if game_manager.has_turn_destruction_ward(bot_player) and game_manager.has_turn_follower_loss_prevention(bot_player):
		return null
	for card in game_manager.get_field_cards(bot_player):
		if card is NamburbiApotropaeon and card.can_activate_prepared(game_manager, triggering_attack):
			return card
	if triggering_attack != null:
		# This lookup is used while deciding whether to intercept on the enemy turn.
		return null
	for card in bot_player.hand_zone.cards:
		if card is NamburbiApotropaeon and card.can_activate_from_hand(game_manager) \
				and game_manager.can_play_card(bot_player, card, null):
			return card
	return null

func _forecast_with_namburbi_ward(ward: NamburbiApotropaeon, forecast: Callable) -> Dictionary:
	# Run the same synchronous forecast used after the cast, then restore both effects.
	var previous_ward: Variant = game_manager.turn_destruction_wards.get(bot_player)
	var previous_prevention: Variant = game_manager.turn_follower_loss_preventions.get(bot_player)
	game_manager.grant_turn_destruction_ward(bot_player, ward)
	game_manager.grant_turn_follower_loss_prevention(bot_player, ward)
	var result: Dictionary = forecast.call()
	if previous_ward == null:
		game_manager.turn_destruction_wards.erase(bot_player)
	else:
		game_manager.turn_destruction_wards[bot_player] = previous_ward
	if previous_prevention == null:
		game_manager.turn_follower_loss_preventions.erase(bot_player)
	else:
		game_manager.turn_follower_loss_preventions[bot_player] = previous_prevention
	return result

func _forecast_namburbi_combat(ward: NamburbiApotropaeon, action: CardAction) -> Dictionary:
	return _forecast_with_namburbi_ward(ward, func() -> Dictionary:
		return _estimate_attack_economy(action, null, 0, 0)
	)

func _forecast_namburbi_combat_threat(ward: NamburbiApotropaeon, enemy_mana: int, already_counted: Array[Card]) -> int:
	var best := 0
	var defenders := _get_board_creatures(bot_player)
	var action := CardAction.new()
	action.type = CardAction.Type.ATTACK
	for attacker in _get_board_creatures(opponent):
		if attacker.current_zone not in opponent.frontline_zones or not CardStrategy.visible(self, attacker) \
				or attacker.creature_mode != Card.CreatureMode.AGGRESSIVE \
				or _status_persists_to_next_turn(attacker, "sleep") or _status_persists_to_next_turn(attacker, "cannot_attack") \
				or game_manager.get_creature_action_mana_cost(attacker, "attack") > enemy_mana:
			continue
		action.attacker = attacker
		if not ward.can_respond_to_action(action, game_manager):
			continue
		for defender in defenders:
			if defender in already_counted or attacker.can_destroy_combat_protected_creatures(defender) \
					or not game_manager.can_cards_engage_each_other(attacker, defender):
				continue
			action.target = defender
			if defender in _estimate_raw_attack_economy(action, {})["casualties"]:
				best = maxi(best, CardStrategy.namburbi_saved_creature_value(self, defender))
	return best

func _plan_namburbi_ward(attacks: Array[Dictionary], baseline: Dictionary) -> Dictionary:
	if attacks.is_empty():
		return {}
	var ward := _find_namburbi_ward_card()
	if ward == null:
		return {}
	var cost := CardStrategy.activation_cost(self, ward)
	var attack_mana := bot_player.mana - cost
	var warded_line := _forecast_with_namburbi_ward(ward, func() -> Dictionary:
		return _plan_combat(_get_combat_candidates(attack_mana), [], null, 0, null, attack_mana)
	)
	var lethal := bool(warded_line.get("lethal", false)) and not bool(baseline.get("lethal", false))
	var combat_score := int(warded_line.get("score", 0))
	var score := combat_score - int(baseline.get("score", 0)) - CardStrategy.CARD_VALUE - CardStrategy.mana_penalty(self, cost)
	if not lethal and score <= 0:
		return {}
	return {
		"score": score, "combat_score": combat_score, "lethal": lethal,
		"command": {"type": "cast_charm", "charm_uid": ward.uid, "target_uid": "", "prepared": ward.is_prepared},
	}

func _plan_united_front(attacks: Array[Dictionary], baseline: Dictionary) -> Dictionary:
	var best := {}
	var best_score := 0
	if game_manager.turn_number <= 1:
		return best
	for card in _get_attack_ready_creatures():
		if not (card is RoboticFootsoldier) or card.is_activation_locked(game_manager) or not match_manager.can_attack(card) or not card.can_activate(game_manager):
			continue
		if not game_manager.get_creature_ability_activation_block_reason(card).is_empty():
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
			var score := int(line["score"]) - int(baseline.get("score", 0)) - cost * _mana_rate()
			if score > best_score:
				best_score = score
				best = {
					"score": score,
					"once_per_turn_uid": card.uid,
					"command": {"type": "activate_card_ability", "source_uid": card.uid, "target_uid": partner.uid},
				}
	return best

func _attack_has_remaining_barrier(candidate: Dictionary, removed: Array) -> bool:
	return candidate["barriers"].any(func(card: Card) -> bool: return card not in removed)

func _project_attack(candidate: Dictionary, removed: Array = [], occupied_zone: Zone = null, recruit: Card = null, mana_left: int = -1, line: Dictionary = {}) -> Dictionary:
	if _attack_has_remaining_barrier(candidate, removed):
		return {}
	var result := _account_for_projected_scavenge_lane(candidate["base"], occupied_zone)
	if not line.is_empty():
		result = _combat_outcome_with_remaining_guard(result, line)
	var score := _score_attack_economy(result, line)
	var unavailable: Array = removed + line.get("blocked", [])
	var guaranteed_mana := _combat_mana_gain(result, unavailable) if not line.is_empty() else 0
	for interceptor in candidate["replies"]:
		if interceptor in removed:
			continue
		var reply := _account_for_projected_scavenge_lane(candidate["replies"][interceptor], occupied_zone)
		if reply.is_empty():
			return {}
		if interceptor is TheInferno:
			reply = _account_for_projected_inferno(reply, removed, occupied_zone, recruit, mana_left)
			if reply.is_empty():
				continue
		if not line.is_empty():
			reply = _combat_outcome_with_remaining_guard(reply, line)
		if not line.is_empty() and guaranteed_mana > 0:
			guaranteed_mana = mini(guaranteed_mana, _combat_mana_gain(reply, unavailable))
		var reply_score := _score_attack_economy(reply, line)
		var reply_outcome := -1 if reply["opponent_wins"] else int(reply["bot_wins"])
		var outcome := -1 if result["opponent_wins"] else int(result["bot_wins"])
		if reply_outcome < outcome or (reply_outcome == outcome and reply_score < score):
			result = reply
			score = reply_score
	if not line.is_empty():
		result["guaranteed_mana_gain"] = guaranteed_mana
	return result

func _combat_mana_gain(outcome: Dictionary, unavailable: Array) -> int:
	var gain := _asakku_offering_mana(outcome, unavailable)
	for beast: PictishBeast in outcome.get("mana_boon_sources", []):
		if beast not in unavailable:
			gain += _pictish_beast_mana(beast, unavailable)
	return gain

func _asakku_offering_mana(outcome: Dictionary, unavailable: Array) -> int:
	var kills := 0
	for victim: Card in outcome.get("offering_victims", []):
		if victim not in unavailable:
			kills += 1
	if kills == 0 or not game_manager.can_player_gain_mana_now(bot_player):
		return 0
	var sources := 0
	for ally in _get_board_creatures(bot_player):
		if ally is Asakku and ally.card_owner == bot_player and not ally.is_face_down \
				and not ally.abilities_suppressed() and ally not in unavailable and ally not in outcome["casualties"]:
			sources += 1
	return 2 * kills * sources

func _pictish_beast_mana(beast: PictishBeast, unavailable: Array) -> int:
	if not game_manager.can_player_gain_mana_now(bot_player):
		return 0
	var count := 1 # The source is face-up when Mana Boon resolves.
	for ally in _get_board_creatures(bot_player):
		if ally != beast and ally not in unavailable and beast._is_face_up_pictish_beast(ally):
			count += 1
	for card: Card in bot_player.graveyard_zone.cards:
		if card != beast and beast._is_pictish_beast(card):
			count += 1
	return count * PictishBeast.MANA_PER_BEAST

func _account_for_projected_inferno(reply: Dictionary, removed: Array, zone: Zone, recruit: Card, mana_left: int) -> Dictionary:
	var hex := reply["spent_hex"] as Card
	var casualties: Array = reply["casualties"].filter(func(card: Card) -> bool: return card not in removed)
	if recruit != null and zone in bot_player.frontline_zones and recruit not in casualties and recruit not in removed:
		var preview := _preview_board_creature(recruit, zone)
		if CardStrategy.can_remove_from_board(self, hex, preview, true, false):
			casualties.append(recruit)
	if casualties.is_empty():
		return {}
	if casualties == reply["casualties"]:
		return reply
	var revised := reply.duplicate()
	revised["casualties"] = []
	revised["bot_cards_lost"] = 0
	revised["opponent_cards_lost"] = 0
	for card: Card in casualties:
		_add_destroyed_card_to_economy(revised, card)
	var budget := bot_player.mana if mana_left < 0 else mana_left
	revised["hex_trade_credit"] = _known_hex_trade_credit(hex, casualties, budget, removed)
	return revised

func _account_for_projected_scavenge_lane(outcome: Dictionary, occupied_zone: Zone) -> Dictionary:
	var recruits: Dictionary = outcome.get("scavenge_recruits", {})
	if occupied_zone == null or not recruits.values().has(occupied_zone):
		return outcome
	var slayer := outcome.get("bot_slayer") as Card
	# A hand Hyena already reserves a lane when forecasting its own attack.
	if slayer == null or slayer.current_zone == bot_player.hand_zone:
		return outcome
	var zones: Array[Zone] = slayer.get_available_scavenge_zones()
	if zones.size() > recruits.size():
		return outcome
	var revised := outcome.duplicate()
	var dropped := recruits.find_key(occupied_zone) as Card
	revised["scavenge_value"] = int(revised["scavenge_value"]) - _get_card_economic_value(dropped)
	revised["scavenge_count"] = recruits.size() - 1
	return revised

func _guaranteed_attack_casualties(candidate: Dictionary, removed: Array, outcome: Dictionary) -> Array:
	var casualties: Array = outcome.get("casualties", [])
	if casualties.is_empty():
		return []
	var possible_outcomes: Array = [candidate["base"]]
	for reply in candidate["replies"]:
		if reply not in removed:
			possible_outcomes.append(candidate["replies"][reply])
	return casualties.filter(func(card: Card) -> bool:
		return possible_outcomes.all(func(result: Dictionary) -> bool:
			return card in result.get("casualties", []) and card not in result.get("returning_casualties", [])
		)
	)

func _plan_combat(candidates: Array[Dictionary], removed: Array = [], committed: Card = null, mana_spent: int = 0, occupied_zone: Zone = null, projected_mana: int = -1, additional_committed: Array = [], recruit: Card = null) -> Dictionary:
	var best := {}
	var best_score := 0
	var best_is_lethal := false
	var available_mana := (bot_player.mana if projected_mana < 0 else projected_mana) - mana_spent
	var enslave_targets := _get_projected_violent_delights_targets(available_mana)
	var frontier: Array[Dictionary] = [{
		"score": 0, "mana": available_mana, "min_mana": available_mana, "attackers": [], "removed": removed,
		"spent_hexes": [],
		"blocked": removed + additional_committed if committed == null else removed + additional_committed + [committed],
		"opponent_followers": opponent.followers, "opponent_guard": opponent.guard,
		"bot_followers": bot_player.followers, "bot_guard": bot_player.guard,
		"uncontested": true, "scavenged": false,
	}]
	var depth := 0
	while not frontier.is_empty():
		var next := {}
		var weight := pow(0.75, depth)
		for line in frontier:
			for attack in candidates:
				var extended := _extend_combat_line(line, attack, occupied_zone, weight, recruit)
				if extended.is_empty():
					continue
				var lethal := bool(extended["lethal"])
				var score := int(extended["score"])
				var capture := 0
				if depth == 0 and not extended["terminal"] and not enslave_targets.is_empty() \
						and int(extended["mana"]) >= AphroditeAreia.ACTIVATION_COST:
					capture = _score_violent_delights_attack(attack, enslave_targets, removed, occupied_zone)
				# Compare the capture with continuing combat from this same attack.
				if (lethal and not best_is_lethal) or (lethal == best_is_lethal and score + capture > best_score):
					best_score = score + capture
					best_is_lethal = lethal
					best = {
						"attacker": extended["attacker"], "target": extended["target"], "score": best_score,
						"lethal": lethal, "violent_delights": capture > 0, "attackers": extended["attackers"],
						"cleared": extended["removed"].slice(removed.size()), "mana": extended["mana"],
						"mana_required": available_mana - int(extended["min_mana"]) + mana_spent,
					}
				if extended["terminal"]:
					continue
				var key := _combat_line_key(extended)
				if not next.has(key) or score > int(next[key]["score"]):
					next[key] = extended
		# Equivalent board and resource states share one continuation. Limit
		# breadth without limiting how many ready creatures can attack.
		frontier.assign(next.values())
		frontier.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return int(a["score"]) > int(b["score"]))
		if frontier.size() > COMBAT_ATTACK_SEARCH_WIDTH:
			frontier.resize(COMBAT_ATTACK_SEARCH_WIDTH)
		depth += 1
	return best

func _extend_combat_line(line: Dictionary, attack: Dictionary, occupied_zone: Zone, weight: float, recruit: Card) -> Dictionary:
	var mana := int(line["mana"]) - int(attack["mana_cost"])
	var attacker: Card = attack["attacker"]
	var partner: Card = attack["partner"]
	var target = attack["target"]
	var blocked: Array = line["blocked"]
	var spent_attackers: Array = line["attackers"]
	if mana < 0 or attacker in blocked or attacker in spent_attackers \
			or (partner != null and (partner in blocked or partner in spent_attackers)) \
			or (target is Card and target in blocked):
		return {}
	var removed: Array = line["removed"]
	var spent_hexes: Array = line["spent_hexes"]
	var unavailable_responses := removed + spent_hexes
	var result := _project_attack(attack, unavailable_responses, occupied_zone, recruit, mana, line)
	if result.is_empty() or result["opponent_wins"]:
		return {}
	var cleared := _guaranteed_attack_casualties(attack, unavailable_responses, result)
	var uncontested := bool(line["uncontested"]) and not _has_projected_attack_reply(attack, unavailable_responses)
	var spent_hex := result.get("spent_hex") as Card
	if spent_hex != null:
		spent_hexes = spent_hexes + [spent_hex]
	var opponent_followers := int(line["opponent_followers"]) - int(result["opponent_followers_lost"]) \
		+ int(result.get("opponent_followers_gained", 0))
	var bot_followers := int(line["bot_followers"]) - int(result["bot_followers_lost"]) \
		+ int(result.get("bot_followers_gained", 0))
	var lethal := opponent_followers <= 0 and bot_followers > 0 and (uncontested or spent_attackers.is_empty())
	result["bot_wins"] = lethal
	if line["scavenged"]:
		result["scavenge_value"] = 0
	var score := _score_attack_economy(result, line) - int(attack["mana_cost"]) * _mana_rate()
	# Discount later trades, while keeping confirmed lethal decisive.
	var lethal_bonus := ECON_CARD_VALUE * 20 if lethal else 0
	score = int(line["score"]) + int((score - lethal_bonus) * weight) + lethal_bonus
	# Optional interceptions can leave the declared target alive. Avoid
	# crediting a second kill on that target, or relying on an uncertain survivor.
	var next_blocked: Array = blocked + result.get("casualties", [])
	if target is Card and target not in next_blocked:
		next_blocked.append(target)
	return {
		"attacker": line.get("attacker", attacker), "target": line.get("target", target),
		"attackers": spent_attackers + ([attacker] if partner == null else [attacker, partner]),
		"blocked": next_blocked, "removed": removed + cleared,
		"mana": mana + int(result.get("guaranteed_mana_gain", 0)), "min_mana": mini(int(line.get("min_mana", line["mana"])), mana),
		"score": score,
		"spent_hexes": spent_hexes,
		"heroic_stand_reward": maxi(int(line.get("heroic_stand_reward", 0)), int(result.get("heroic_stand_reward", 0))),
		"opponent_followers": opponent_followers, "bot_followers": bot_followers,
		"opponent_guard": int(line["opponent_guard"]) - int(result.get("opponent_guard_spent", 0)),
		"bot_guard": int(line["bot_guard"]) - int(result.get("bot_guard_spent", 0)),
		"uncontested": uncontested, "scavenged": line["scavenged"] or int(result.get("scavenge_count", 0)) > 0,
		"terminal": opponent_followers <= 0 or bot_followers <= 0, "lethal": lethal,
	}

func _combat_outcome_with_remaining_guard(outcome: Dictionary, line: Dictionary) -> Dictionary:
	var result := outcome.duplicate()
	if result.has("pierce_owners"):
		# Pierce will be recapped after combat damage at this point in the line.
		result.erase("bot_followers_gained")
		result.erase("opponent_followers_gained")
	for side in ["opponent", "bot"]:
		var remaining := int(line[side + "_followers"])
		var loss_key: String = side + "_followers_lost"
		var raw_damage = outcome.get(side + "_damage_before_guard")
		if raw_damage == null:
			result[loss_key] = mini(int(outcome[loss_key]), remaining)
			continue
		var absorbed := mini(int(raw_damage), int(line[side + "_guard"]))
		result[side + "_guard_spent"] = absorbed
		var damage := int(raw_damage) - absorbed
		var source := outcome.get(side + "_loss_source") as Card
		var recipient := opponent if side == "opponent" else bot_player
		if source != null and source.get_controller() != recipient and CardStrategy.visible(self, source) \
				and game_manager._source_converts_combat_follower_damage(source):
			damage = game_manager._get_combat_follower_conversion_amount(source, damage, remaining)
			result["bot_followers_gained" if side == "opponent" else "opponent_followers_gained"] = damage
		result[loss_key] = mini(remaining, damage)
	var conversion_defender := result.get("defensive_conversion_defender") as Card
	if conversion_defender != null:
		# This line may have spent guard on the converted loss after the
		# candidate's outcome was priced with the full guard, so redo the
		# transfer with the recomputed loss instead of the stale gain.
		var winner := conversion_defender.get_controller() as Player
		if result.get("reverse_follower_damage", false):
			winner = game_manager.get_opponent(winner)
		if winner != null and winner.followers_enabled:
			var loser_loss_key := "opponent_followers_lost" if winner == bot_player else "bot_followers_lost"
			result["bot_followers_gained" if winner == bot_player else "opponent_followers_gained"] = int(result[loser_loss_key])
	_apply_pierce_conversions(result, int(line["bot_followers"]), int(line["opponent_followers"]))
	result["bot_wins"] = int(result["opponent_followers_lost"]) - int(result.get("opponent_followers_gained", 0)) >= int(line["opponent_followers"])
	result["opponent_wins"] = int(result["bot_followers_lost"]) - int(result.get("bot_followers_gained", 0)) >= int(line["bot_followers"])
	return result

func _apply_pierce_conversions(result: Dictionary, bot_followers: int, opponent_followers: int) -> void:
	if not result.has("pierce_owners"):
		return
	var remaining := {
		bot_player: bot_followers - int(result["bot_followers_lost"]) + int(result.get("bot_followers_gained", 0)),
		opponent: opponent_followers - int(result["opponent_followers_lost"]) + int(result.get("opponent_followers_gained", 0)),
	}
	# Apply each Slay in combat order. Pierce bypasses guard and can trigger for
	# both casualties of a United Front attack.
	for owner: Player in result["pierce_owners"]:
		var payer := game_manager.get_opponent(owner)
		if payer == null or not payer.followers_enabled or not game_manager.can_player_lose_followers_now(payer):
			continue
		var converted := mini(int(remaining[payer]), Aurboda.PIERCE_FOLLOWERS)
		if converted <= 0:
			continue
		var loss_key := "bot_followers_lost" if payer == bot_player else "opponent_followers_lost"
		remaining[payer] -= converted
		result[loss_key] += converted
		if owner.followers_enabled and int(remaining[owner]) > 0:
			var gain_key := "bot_followers_gained" if owner == bot_player else "opponent_followers_gained"
			remaining[owner] += converted
			result[gain_key] = int(result.get(gain_key, 0)) + converted

func _combat_line_key(line: Dictionary) -> String:
	var key := [line["mana"], line.get("min_mana", line["mana"]), line["opponent_followers"], line["bot_followers"],
		line["opponent_guard"], line["bot_guard"], line["uncontested"], line["scavenged"], line.get("heroic_stand_reward", 0)]
	for field in ["attackers", "blocked", "removed", "spent_hexes"]:
		var cards: Array = line[field]
		var ids := cards.map(func(card: Card) -> int: return card.get_instance_id() if card != null else 0)
		ids.sort()
		key.append(ids)
	return str(key)

func _get_projected_violent_delights_targets(mana: int) -> Dictionary:
	var targets := {}
	if mana < AphroditeAreia.ACTIVATION_COST:
		return targets
	var god := _find_player_god() as AphroditeAreia
	if god == null or god.is_muted or god.card_owner != game_manager.current_player \
			or god.current_zone != bot_player.god_zone or not game_manager.can_player_use_powers(bot_player) \
			or game_manager.player_destroyed_creature_by_combat_this_turn(bot_player):
		return targets
	for target in _get_board_creatures(opponent):
		if CardStrategy.visible(self, target) and god.is_valid_activation_target(target) \
				and not game_manager._is_protected_from_enslavement(target) \
				and not CardStrategy.removal_targets(self, god, target).is_empty() \
				and game_manager.get_turn_destruction_ward_activation_block_reason(god, target).is_empty():
			targets[target] = _violent_delights_target_value(target)
	return targets

func _violent_delights_target_value(target: Card) -> int:
	# The captured body gains a controller and loses access to its abilities.
	@warning_ignore("integer_division")
	return CardStrategy.value(self, target) + _get_card_economic_value(target) / 2

func _score_violent_delights_attack(attack: Dictionary, targets: Dictionary, removed: Array, occupied_zone: Zone) -> int:
	var value := _score_violent_delights_outcome(attack["base"], targets, removed, occupied_zone)
	for reply in attack["replies"]:
		if value <= 0:
			break
		if reply not in removed:
			value = mini(value, _score_violent_delights_outcome(attack["replies"][reply], targets, removed, occupied_zone))
	return value

func _score_violent_delights_outcome(result: Dictionary, targets: Dictionary, removed: Array, occupied_zone: Zone) -> int:
	if not result.get("enemy_creature_destroyed", false) or result["bot_wins"] or result["opponent_wins"]:
		return 0
	var casualties: Array = result["casualties"]
	var returning: Array = result.get("returning_casualties", [])
	var recruits: Dictionary = result.get("scavenge_summons", {})
	# An allied casualty can open a destination for the captured creature.
	var has_space := (bot_player.frontline_zones + bot_player.reserve_zones).any(func(zone: Zone) -> bool:
		return zone != occupied_zone and not recruits.values().has(zone) \
			and zone.cards.all(func(card: Card) -> bool: return card in removed or (card in casualties and card not in returning)))
	if not has_space:
		return 0
	var best := 0
	for target in targets:
		if target not in removed and target not in casualties:
			best = maxi(best, int(targets[target]) - AphroditeAreia.ACTIVATION_COST * _mana_rate())
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
	action.source_player = opponent
	action.attacker = attacker
	action.target = target if target != null else (bot_player as Variant)
	action.united_front_partner = match_manager._get_declared_attack_partner(attacker)
	action.attack_speed_override = match_manager._get_declared_attack_speed(attacker)
	if action.united_front_partner != null and not CardStrategy.visible(self, action.united_front_partner):
		return ""
	var ward := _find_namburbi_ward_card(action)
	var ward_cost := CardStrategy.CARD_VALUE + CardStrategy.mana_penalty(self, CardStrategy.activation_cost(self, ward)) if ward != null else 0
	var best := ""
	var unblocked := _score_interception(action, ward, ward_cost)
	var best_survives := bool(unblocked["survives"])
	var best_score := int(unblocked["score"]) + 200
	for uid in data.get("interceptor_uids", []):
		action.interceptor = game_manager.get_card_by_uid(str(uid))
		if action.interceptor == null:
			continue
		var blocked := _score_interception(action, ward, ward_cost)
		var survives := bool(blocked["survives"])
		var score := int(blocked["score"])
		if (survives and not best_survives) or (survives == best_survives and score > best_score):
			best_survives = survives
			best_score = score
			best = str(uid)
	return best

func _score_interception(action: CardAction, ward: NamburbiApotropaeon, ward_cost: int) -> Dictionary:
	var outcome := _estimate_attack_economy(action, null, 0, 0)
	var score := _score_attack_economy(outcome)
	var survives := not bool(outcome["opponent_wins"])
	if ward != null:
		var warded := _forecast_namburbi_combat(ward, action)
		var warded_score := _score_attack_economy(warded) - ward_cost
		var warded_survives := not bool(warded["opponent_wins"])
		if (warded_survives and not survives) or (warded_survives == survives and warded_score > score):
			return {"survives": warded_survives, "score": warded_score}
	return {"survives": survives, "score": score}

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
		var score := _score_projected_card(card) - game_manager.get_creature_action_mana_cost(card, "move") * _mana_rate()
		if score <= best_score or not _can_attack_followers_safely(card):
			continue
		for zone in bot_player.get_adjacent_zones(card.current_zone):
			if zone in bot_player.frontline_zones and zone.cards.is_empty() \
					and _get_known_entry_responses(card, zone, card.is_stealth, [], false).is_empty():
				best_card = card
				best_zone = zone
				best_score = score
				break
	return best_card != null and _submit_action({"type": "creature_move", "card_uid": best_card.uid, "player_index": player_index, "zone_type": best_zone.zone_type, "zone_index": best_zone.zone_index})

# General movement planning. A move is worth its mana when it enables an
# attack the creature could not make from its current lane, brings friendly
# equipment into pickup reach, shelters a creature that would otherwise be
# destroyed in combat, frees a frontline lane for an aggressive reserve
# creature to advance and attack, or improves interception coverage.
func _try_improve_creature_position() -> bool:
	if game_manager == null or match_manager == null or bot_player == null:
		return false
	if game_manager.turn_number <= 1 or game_manager.attack_restrictions.has(bot_player):
		return false
	var best := {}
	for card in _get_board_creatures(bot_player):
		if card.is_sleeping or card.has_status_effect("cannot_move") \
				or not card.can_take_minor_creature_action() \
				or not game_manager.can_pay_creature_action_mana_cost(card, "move"):
			continue
		var move_cost := game_manager.get_creature_action_mana_cost(card, "move") * _mana_rate()
		for zone in bot_player.get_adjacent_zones(card.current_zone):
			if zone == null or not zone.is_board_zone() or not zone.cards.is_empty():
				continue
			var score := _score_creature_move(card, zone) - move_cost
			if score > int(best.get("score", 0)):
				best = {"score": score, "command": {"type": "creature_move", "card_uid": card.uid,
					"player_index": player_index, "zone_type": zone.zone_type, "zone_index": zone.zone_index}}
	return not best.is_empty() and _submit_action(best["command"])

func _score_creature_move(card: Card, zone: Zone) -> int:
	var from_frontline: bool = card.current_zone != null and card.current_zone in bot_player.frontline_zones
	var to_frontline := zone in bot_player.frontline_zones
	var score := 0
	# Attack option the move adds or removes. Reserve creatures cannot attack,
	# so advancing an aggressive creature gains its full attack value; leaving
	# the frontline gives that option up and also forgoes next turn's
	# one-minor-action flip back to aggression, which only a real safety gain
	# below can pay for.
	var attack_eligible := card.can_take_major_creature_action() and game_manager.turn_number > 1 \
		and not card.summoned_after_first_attack_this_turn and not card.has_status_effect("cannot_attack")
	# Immediate attacks only work from an aggressive stance: the move spends
	# the creature's minor action, so a defensive creature cannot flip into
	# combat this turn.
	if attack_eligible and to_frontline and card.creature_mode == Card.CreatureMode.AGGRESSIVE:
		score += _score_attack_value_from_zone(card, zone)
	if attack_eligible and from_frontline and card.creature_mode == Card.CreatureMode.AGGRESSIVE:
		score -= _score_attack_value_from_zone(card, card.current_zone)
	if from_frontline and not to_frontline:
		score -= card.get_effective_strength() * RESERVE_PLACEMENT_STR_VALUE
	if to_frontline and not from_frontline and card.creature_mode == Card.CreatureMode.DEFENSIVE:
		# A defensive creature on the frontline is one minor action from
		# aggression next turn; on the reserve line that option is gone.
		# Kept below the leaving toll so a creature cannot be shuffled back
		# and forth for net gain.
		@warning_ignore("integer_division")
		score += card.get_effective_strength() * RESERVE_PLACEMENT_STR_VALUE / 4
	# Compare coverage against other interceptors from both rows.
	if card.creature_mode == Card.CreatureMode.DEFENSIVE and from_frontline != to_frontline:
		@warning_ignore("integer_division")
		score += (_estimate_defensive_summon_value(card, zone) - _estimate_defensive_summon_value(card, card.current_zone)) / 2
	# Shelter value: projected combat loss the move avoids. A reserve lane
	# protected by a frontline palisade intercepts for the moved creature.
	if not to_frontline:
		var current_loss := _estimate_projected_summon_casualty_cost(card, card.current_zone, card.creature_mode == Card.CreatureMode.DEFENSIVE, [])
		var sheltered_loss := _estimate_projected_summon_casualty_cost(card, zone, card.creature_mode == Card.CreatureMode.DEFENSIVE, [])
		score += current_loss - sheltered_loss
	# Friendly equipment that comes into pickup reach after the move.
	score += _score_move_toward_equipment(card, zone)
	# Freeing a frontline lane so an aggressive reserve creature can advance
	# and attack this turn in a crowded board.
	if from_frontline and not to_frontline:
		score += _score_freed_frontline_lane(card, card.current_zone)
	# Advancing from a safe reserve lane can offer the same trade as a summon.
	for reply in _get_known_entry_responses(card, zone, card.is_stealth, [], false):
		var mana_left := bot_player.mana - game_manager.get_creature_action_mana_cost(card, "move")
		var trade := _score_known_entry_trade(reply, mana_left, [])
		trade += _follower_safety_gain(_forecast_incoming_follower_loss(), {"removed": reply["victims"]}, mana_left)
		score = mini(score, trade)
	return score

# Best attack value the creature could get acting this turn from `zone`.
func _score_attack_value_from_zone(card: Card, zone: Zone) -> int:
	if card == null or zone == null or opponent == null or match_manager == null:
		return 0
	var preview := _preview_board_creature(card, zone)
	preview.creature_mode = Card.CreatureMode.AGGRESSIVE
	preview.is_stealth = false
	preview.is_face_down = false
	var best := 0
	for target in _get_board_creatures(opponent):
		best = maxi(best, _score_standard_attack_plan(preview, target))
	if _can_attack_followers_safely(preview) \
			and not _known_prepared_response_punishes_attack(preview, opponent):
		best = maxi(best, _score_followers_attack(preview))
	return maxi(best, 0)

func _score_move_toward_equipment(card: Card, zone: Zone) -> int:
	if card == null or zone == null or not card.can_receive_equipment():
		return 0
	var current_reach := game_manager.get_reachable_board_zones(card)
	var moved_reach := _get_reach_from_zone(zone)
	var best := 0
	for player in game_manager.players:
		if player == null:
			continue
		for equip_zone in player.frontline_zones + player.reserve_zones:
			if equip_zone == null or equip_zone == card.current_zone or equip_zone == zone:
				continue
			# Walk toward friendly equipment only; enemy steals have their own
			# interception risks and stay with the direct pickup planner.
			if equip_zone.zone_owner != bot_player:
				continue
			for equip in equip_zone.cards:
				var equipment := equip as EquipmentCard
				if equipment == null or equipment.equipped_on != null or not equipment.can_equip_to(card):
					continue
				# Already in reach: the direct pickup plan handles it.
				if equip_zone in current_reach:
					continue
				if equip_zone not in moved_reach:
					continue
				# The move spends this turn's minor action, so the pickup is
				# discounted for happening a turn later, and low-impact gear
				# is not worth walking for.
				@warning_ignore("integer_division")
				best = maxi(best, maxi(0, CardStrategy.equipment_pickup_score(self, equipment, card) - 2000) / 2)
	return best

func _get_reach_from_zone(zone: Zone) -> Array[Zone]:
	if zone == null:
		return []
	var reachable: Array[Zone] = bot_player.get_adjacent_zones(zone)
	# Cross-board reach: frontline zones can reach the opposing frontline at
	# +/- 1 column, mirroring game_manager.get_reachable_board_zones.
	if zone.zone_type == Zone.ZoneType.FRONTLINE and opponent != null:
		for offset in [-1, 0, 1]:
			var target_index: int = zone.zone_index + offset
			if target_index >= 0 and target_index < opponent.frontline_zones.size():
				reachable.append(opponent.frontline_zones[target_index])
	return reachable

# Value gained by vacating this frontline lane: an aggressive reserve
# creature adjacent to the lane can advance and attack this turn.
func _score_freed_frontline_lane(mover: Card, vacated_zone: Zone) -> int:
	if vacated_zone == null:
		return 0
	var best := 0
	for advancer in _get_board_creatures(bot_player):
		if advancer == mover or advancer.current_zone == null \
				or advancer.current_zone not in bot_player.reserve_zones:
			continue
		if advancer.creature_mode != Card.CreatureMode.AGGRESSIVE or advancer.is_sleeping \
				or advancer.has_status_effect("cannot_move") or advancer.has_status_effect("cannot_attack") \
				or not advancer.can_take_minor_creature_action() or not advancer.can_take_major_creature_action() \
				or advancer.summoned_after_first_attack_this_turn \
				or not game_manager.can_pay_creature_action_mana_cost(advancer, "move"):
			continue
		if vacated_zone not in bot_player.get_adjacent_zones(advancer.current_zone):
			continue
		var gain := _score_attack_value_from_zone(advancer, vacated_zone)
		gain -= game_manager.get_creature_action_mana_cost(advancer, "move") * _mana_rate()
		best = maxi(best, gain)
	return best

# Flank: Winged Lion repositions itself and one partner to any friendly slots
# in a single activation. Score it as the best pair of move deltas it can
# create, using the same move scoring as normal movement.
func _plan_winged_lion_flank(lion: WingedLion, action_tax: int) -> Dictionary:
	var best := {}
	for partner in lion.get_valid_targets(game_manager):
		for self_zone in lion.get_valid_self_zones(game_manager, partner):
			for partner_zone in lion.get_valid_partner_zones(game_manager, partner, self_zone):
				if self_zone == lion.current_zone and partner_zone == partner.current_zone:
					continue
				var score := _score_creature_move(lion, self_zone) + _score_creature_move(partner, partner_zone)
				score -= action_tax * _mana_rate() + 300
				if score > int(best.get("score", 0)):
					best = {
						"score": score,
						"command": {
							"type": "activate_card_ability",
							"source_uid": lion.uid,
							"option": {
								"target_uid": partner.uid,
								"self_zone": _zone_option(self_zone),
								"partner_zone": _zone_option(partner_zone),
							},
						},
					}
	return best

func _zone_option(zone: Zone) -> Dictionary:
	return {
		"player_index": game_manager.players.find(zone.zone_owner),
		"zone_type": zone.zone_type,
		"zone_index": zone.zone_index,
	}

# True when a visible prepared enemy response would fire against declaring
# this attack (The Inferno / Void Shield / Smite, prepared or revealed in
# hand). The replies-aware combat planner prices these answers; the simple
# fallback attack paths consult this guard so execution can never contradict
# the planner's refusal while the board is unchanged.
func _known_prepared_response_punishes_attack(attacker: Card, target) -> bool:
	if attacker == null or opponent == null or game_manager == null:
		return false
	var action := CardAction.new()
	action.type = CardAction.Type.ATTACK
	action.source_player = bot_player
	action.attacker = attacker
	action.target = target
	action.interceptor = target if target is Card else null
	for response in _get_known_attack_response_cards(action):
		if not _estimate_known_attack_response(response, action).is_empty():
			return true
	return false

# Setup paths that need the recruit to survive use the gross loss as a guard.
func _known_entry_response_penalty(entrant: Card, zone: Zone, stealth: bool) -> int:
	for reply in _get_known_entry_responses(entrant, zone, stealth):
		if entrant in reply["victims"]:
			return _get_card_economic_value(entrant)
	return 0

func _get_known_entry_responses(entrant: Card, zone: Zone, stealth: bool, removed: Array = [], summoning: bool = true) -> Array[Dictionary]:
	var replies: Array[Dictionary] = []
	if entrant == null or zone == null or opponent == null or game_manager == null \
			or not zone.is_board_zone():
		return replies
	var event_names: Array[String] = []
	if zone.zone_type == Zone.ZoneType.FRONTLINE:
		event_names.append("frontline_entry")
	if summoning and not stealth:
		event_names.append("summon")
	if event_names.is_empty() or game_manager.prepared_hexes.is_empty():
		return replies
	var preview := _preview_board_creature(entrant, zone)
	preview.is_stealth = stealth
	preview.is_face_down = stealth
	for event_name in event_names:
		var action := CardAction.new()
		action.type = CardAction.Type.EVENT
		action.source_player = bot_player
		action.card = preview
		action.event_name = event_name
		for response: Card in game_manager.prepared_hexes:
			if response.card_owner != opponent or response in removed or not CardStrategy.visible(self, response):
				continue
			if not game_manager.can_card_respond_to_action(response, action, opponent):
				continue
			var victims := CardStrategy.removal_targets(self, response, preview, action)
			var hits_entrant := preview in victims or (response is TheDeluge and preview.is_physical_card() \
					and CardStrategy.can_remove_from_board(self, response, preview, true, false))
			victims = victims.filter(func(card: Card) -> bool: return card != preview and card != entrant and card != response and card not in removed)
			if hits_entrant:
				victims.append(entrant)
			if not victims.is_empty():
				replies.append({"hex": response, "victims": victims})
	return replies

func _score_known_entry_trade(reply: Dictionary, mana_left: int, unavailable: Array) -> int:
	var victims: Array = reply["victims"]
	var result := {"casualties": []}
	for victim: Card in victims:
		_add_destroyed_card_to_economy(result, victim)
	return int(result.get("opponent_cards_lost", 0)) - int(result.get("bot_cards_lost", 0)) \
		+ _known_hex_trade_credit(reply["hex"], victims, mana_left, unavailable) \
		+ _combat_god_death_cost(opponent, victims, 0) - _combat_god_death_cost(bot_player, victims, 0)

# A spent hex is a card and mana the opponent cannot use later. The sweepers
# also threaten a wider board, so drawing one out early is worth a premium.
func _known_hex_trade_credit(response: Card, victims: Array, mana_left: int, unavailable: Array = []) -> int:
	var cost := game_manager.get_prepared_card_activation_mana_cost(opponent, response) if response.is_prepared \
		else game_manager.get_card_play_mana_cost(opponent, response, false)
	var credit := ECON_CARD_VALUE + int(cost * ECON_MANA_VALUE * 0.5) + CardStrategy.sweeper_hold_value(response)
	var bodies := 0
	for victim: Card in victims:
		if victim is CreatureCard and not victim is ActiveGodCard and not victim.is_token and _get_card_loss_owner(victim) == bot_player:
			bodies += _get_card_economic_value(victim)
	if bodies > 0:
		var supply := _hex_replacement_supply(mana_left, victims + unavailable)
		credit += int(bodies * lerpf(-0.22, 0.20, clampf(supply / 2.0, 0.0, 1.0)))
	return credit

func _hex_replacement_supply(mana_left: int, unavailable: Array) -> float:
	var upkeep := game_manager.get_automatic_upkeep_mana_gain(bot_player, game_manager.turn_number + 2)
	var draw_budget := mana_left + upkeep + game_manager.get_effective_upkeep_mana_gain(game_manager.get_base_upkeep_draw_mana_gain(), bot_player)
	var hand_budget := mana_left + upkeep + game_manager.get_effective_upkeep_mana_gain(game_manager.get_base_upkeep_mana_gain(), bot_player)
	var fodder := _get_valid_summon_sacrifice_candidates().filter(func(card: Card) -> bool: return card not in unavailable).size()
	var ready := func(card: Card, budget: int) -> bool:
		return card is CreatureCard and not card is ActiveGodCard and card not in unavailable \
			and card.sacrifice_cost <= fodder and _get_play_cost(card, false) <= budget
	var in_hand := bot_player.hand_zone.cards.filter(func(card: Card) -> bool: return ready.call(card, hand_budget)).size()
	var deck := bot_player.deck_zone
	if in_hand >= 2 or deck.cards.is_empty():
		return float(in_hand)
	var primed := deck.get_primed_top_card()
	if primed != null:
		return float(in_hand) + float(ready.call(primed, draw_budget))
	var draws := deck.cards.filter(func(card: Card) -> bool: return ready.call(card, draw_budget)).size()
	return float(in_hand) + float(draws) / float(deck.cards.size())

func _try_attack() -> bool:
	_crumb("try_attack")
	var attackers := _get_attack_ready_creatures()
	if attackers.is_empty():
		return false
	var opposing_creatures := _get_board_creatures(opponent)
	var safe_followers_attack := _get_best_safe_followers_attack(attackers)
	# If the opponent has a face-up Gidim Ensi, attacking their followers sleeps
	# the attacker. When another ready attacker can cleanly remove that Gidim
	# Ensi first, do that before any follower attack so the follower attacker
	# does not fall asleep.
	if not safe_followers_attack.is_empty() and (_can_kill_with_all_attackers(attackers) or opposing_creatures.is_empty()) and not _has_gidim_ensi_removal_before_followers(attackers):
		return _submit_attack(safe_followers_attack.get("attacker", null), opponent)
	var askelladen_attack := _get_best_askelladen_attack(attackers, opposing_creatures)
	if not askelladen_attack.is_empty():
		return _submit_attack(askelladen_attack.get("attacker", null), askelladen_attack.get("target", null))
	var supported_attack := _get_best_supported_attack(attackers, opposing_creatures)
	if not supported_attack.is_empty():
		return _submit_attack(supported_attack.get("attacker", null), supported_attack.get("target", null))
	# Stealth kills outrank standard attacks: a stealth body pokes
	# un-interceptable every turn it lives, so removing it is the best
	# recurring-income denial available, and the plan is filtered to clean
	# kills with the cheapest sufficient attacker.
	var stealth_attack := _get_best_stealth_attack(attackers, opposing_creatures)
	if not stealth_attack.is_empty():
		return _submit_attack(stealth_attack.get("attacker", null), stealth_attack.get("target", null))
	var standard_attack := _get_best_standard_attack(attackers, opposing_creatures)
	if not standard_attack.is_empty():
		return _submit_attack(standard_attack.get("attacker", null), standard_attack.get("target", null))
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
		# Walls matter: resilience counts at half strength here (was /3) so
		# defensive bodies are not the default discard.
		@warning_ignore("integer_division")
		return 35 + mini(40, maxi(0, card.strength) + maxi(0, card.resilience) / 2)
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
	var chosen_card: Card = null
	var best_value := 1000000
	for choice in choices:
		@warning_ignore("integer_division")
		var value := _get_card_economic_value(choice) - choice.mana_cost * 350 * _mana_rate() / 1000
		if value < best_value:
			chosen_card = choice
			best_value = value
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

func _submit_prepare_card(card: Card, zone: Zone, removal_risk_scored: bool = false) -> bool:
	if card == null or zone == null or game_manager == null:
		return false
	if not game_manager.can_prepare_card(bot_player, card, zone):
		return false
	if not removal_risk_scored and CardStrategy.preparation_removal_penalty(self, card) > 0:
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

func _build_creature_play_command(card: Card, zone: Zone, mode: Card.CreatureMode, danger: int = -1, projected_defensive: bool = false, available_mana: int = -1, summon_source: Fenrir = null) -> Dictionary:
	var from_zone := bot_player.hand_zone if summon_source == null else bot_player.deck_zone
	if card == null or zone == null or card.current_zone != from_zone:
		return {}
	var forecast := {}
	if danger >= 0:
		forecast = {"danger": danger, "summon": card, "zone": zone, "stance": card, "defensive": projected_defensive}
	# Planning may price a summon against a projected stock (the Mead brew or
	# upkeep income); direct submissions keep validating at the real stock.
	var payment_plan := _build_creature_summon_payment_plan(card, available_mana, forecast, summon_source)
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

# Whether hiding this card would forfeit real value. Stealth switches off every
# creature ability while hidden (stealth sets Card._abilities_disabled_by_hidden_state),
# and an Impact never comes back: it only resolves on a face-up hand summon, so
# any card printing an Impact trigger must stay face-up while that trigger has
# something to resolve. A target-gated Impact with no legal targets left —
# nothing left to Conjure, Silence, or Acquire — is moot, and hiding that body
# is free. BOARD_ABILITIES keep their activated-ability value protected
# regardless, and STEALTH_SUPPRESSED_KEYS still covers the kill/death/passive
# bodies with no printed Impact.
func _stealth_would_forfeit_value(card: Card) -> bool:
	if card == null:
		return false
	if card.has_veil_of_night() and not card.abilities_suppressed_by_effects() \
			and "[b]Reveal[/b]" in card.ability_text:
		return true
	var card_key := CardStrategy.key(card)
	if card_key in CardStrategy.BOARD_ABILITIES:
		return true
	if card.declares_impact_trigger() and not card.abilities_suppressed_by_effects():
		if not card.has_method("get_valid_targets") or not card.get_valid_targets(game_manager).is_empty():
			return true
		return false
	return card_key in CardStrategy.STEALTH_SUPPRESSED_KEYS

func _prefers_stealth_summon(card: Card) -> bool:
	# The summon planner treats any speed-1 body as a stealth candidate, so the
	# suppression check must gate this too: never hide a card whose face-up
	# hooks stealth would switch off.
	return not _stealth_would_forfeit_value(card) and (card.get_effective_speed() == 1 or card.has_veil_of_night())

func _should_summon_creature_stealthily(card: Card, zone: Zone, mode: Card.CreatureMode) -> bool:
	if card == null or zone == null or mode != Card.CreatureMode.DEFENSIVE:
		return false
	if _stealth_would_forfeit_value(card):
		return false
	if card.has_veil_of_night():
		return true
	if zone not in bot_player.frontline_zones:
		return _prefers_stealth_summon(card)
	# Stealth is face-down, so a hidden body loses the face-up Defensive intercept
	# and has to match an attack's Speed. Stay face-up when a currently plausible
	# enemy attack outruns this frontline body.
	var speed := card.get_effective_speed()
	if opponent == null:
		return true
	for enemy in _get_board_creatures(opponent):
		if enemy == null or not CardStrategy.visible(self, enemy) or enemy.is_sleeping \
				or enemy.has_status_effect("cannot_attack") or enemy.prevents_interception():
			continue
		var enemy_speed := enemy.get_effective_speed() + _opponent_hermes_speed_gain(enemy)
		if enemy_speed <= speed:
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
	var command_type := str(command.get("type", "?"))
	if command_type != "priority_pass":
		_crumb("submit:" + command_type + " ok=" + str(submitted))
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
	if _would_receive_gawain_sun_blessing(card):
		total += card.strength * 2
	if _would_receive_thor_buff(card):
		total += 3
	if _would_sulak_surprise_on_reveal(card):
		total += card.strength
	return total

# Sulak's Surprise! doubles his strength on the turn he is revealed, so a
# hand or brood-slot Sulak attacks (and prices) at double strength even
# though the buff does not exist yet. On-board copies are handled above by
# the effective-strength early return.
func _would_sulak_surprise_on_reveal(card: Card) -> bool:
	return card is SulakTheUnclean and card.card_owner == bot_player \
		and not card.abilities_suppressed_by_effects()

func _would_receive_gawain_sun_blessing(card: Card) -> bool:
	return card is Gawain and card.card_owner == bot_player \
		and game_manager.current_player == bot_player and not card.abilities_suppressed_by_effects()

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
		if _known_prepared_response_punishes_attack(askelladen, creature):
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

# Look ahead through legal responses, using the same effect scores as priority play.
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
			if CardStrategy.counterstroke_can_answer(self, defender, attacker, null, true):
				continue
			if not match_manager._get_possible_interceptors(attacker, defender).is_empty():
				continue
			if _known_prepared_response_punishes_attack(attacker, defender):
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
					gain = maxi(gain, _score_combat_buff_sequence(support, target, action, support_cards))
					var score := before + gain
					if gain > 0 and score > maxi(0, before) and score > best_score:
						best_score = score
						best_attack = {"attacker": attacker, "target": defender, "score": score}
	return best_attack

func _score_combat_buff_sequence(first: Card, target: Card, action: CardAction, choices: Array) -> int:
	var first_stats := CardStrategy.additive_combat_stats(self, first, target)
	if first_stats == Vector3i.ZERO or not (first is CharmCard or first is HexCard) \
			or first.discard_cost > 0 or first.sacrifice_cost > 0 or choices.size() < 2:
		return CardStrategy.BAD
	var projection := CardStrategy.combat_projection(self, action)
	var attack := projection["attack"] as CardAction
	if attack == null or not CardStrategy.combat_visible(self, attack) \
			or (attack.united_front_partner != null and not CardStrategy.visible(self, attack.united_front_partner)):
		return CardStrategy.BAD
	var combatants: Array[Card] = [attack.attacker, attack.united_front_partner, _get_attack_defender_card(attack)]
	if target not in combatants or CardStrategy.target_score(self, first, target, action) <= CardStrategy.BAD:
		return CardStrategy.BAD
	var effects: Array[Dictionary] = []
	for card: Card in choices:
		if card == first or not (card is CharmCard or card is HexCard) or card.discard_cost > 0 or card.sacrifice_cost > 0:
			continue
		for recipient: Card in CardStrategy.targets(self, card, action):
			if recipient == null or recipient not in combatants:
				continue
			var stats := CardStrategy.additive_combat_stats(self, card, recipient)
			if stats != Vector3i.ZERO and CardStrategy.target_score(self, card, recipient, action) > CardStrategy.BAD:
				effects.append({"card": card, "target": recipient, "stats": stats, "cost": CardStrategy.activation_cost(self, card)})
	if effects.is_empty():
		return CardStrategy.BAD
	var pending: Dictionary = projection["stats"]
	var baseline := _score_attack_economy(_estimate_projected_attack_economy(attack, pending))
	var initial_stats := pending.duplicate()
	initial_stats[target] = initial_stats.get(target, Vector3i.ZERO) + first_stats
	var first_cost := CardStrategy.activation_cost(self, first)
	var attack_cost := 0 if attack in game_manager.action_stack else game_manager.get_creature_action_mana_cost(attack.attacker, "attack")
	var frontier: Array[Dictionary] = [{"last": first, "target": target, "stats": initial_stats, "mana": first_cost, "used": [first.get_instance_id()]}]
	var best := CardStrategy.BAD
	# Keep the best forecasts at each depth. Every extension spends a distinct card.
	while not frontier.is_empty():
		var next: Array[Dictionary] = []
		var seen := {}
		for line in frontier:
			var response := CardAction.new()
			response.type = CardAction.Type.CHARM if line["last"] is CharmCard else CardAction.Type.ABILITY
			response.card = line["last"]
			response.source_player = bot_player
			response.target = line["target"]
			for effect in effects:
				var card: Card = effect["card"]
				var id := card.get_instance_id()
				var mana := int(line["mana"]) + int(effect["cost"])
				if id in line["used"] or bot_player.mana < attack_cost + mana \
						or not game_manager.can_card_respond_to_action(card, response, bot_player):
					continue
				var recipient: Card = effect["target"]
				var stats: Dictionary = line["stats"].duplicate()
				stats[recipient] = stats.get(recipient, Vector3i.ZERO) + effect["stats"]
				var used: Array = line["used"] + [id]
				used.sort()
				var key := str([used, card.get_effective_speed(), stats.get(combatants[0]), stats.get(combatants[1]), stats.get(combatants[2])])
				if seen.has(key):
					continue
				seen[key] = true
				var gain := _score_attack_economy(_estimate_projected_attack_economy(attack, stats)) - baseline
				var score := gain - used.size() * ECON_CARD_VALUE - CardStrategy.mana_penalty(self, mana)
				best = maxi(best, score)
				next.append({"last": card, "target": recipient, "stats": stats, "mana": mana, "used": used, "score": score})
		next.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return int(a["score"]) > int(b["score"]))
		if next.size() > COMBAT_RESPONSE_SEARCH_WIDTH:
			next.resize(COMBAT_RESPONSE_SEARCH_WIDTH)
		frontier = next
	return best

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
	if card is CreatureCard and CardStrategy.visible(self, card) and not (card.is_stealth and card.has_veil_of_night()):
		return card.get_combat_strength_against(opposing_card, str_delta)
	return card.get_effective_strength(str_delta)

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
	if game_manager.is_warded_from_combat_destruction(target, attacker):
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
	if game_manager.is_warded_from_combat_destruction(attacker, target):
		return true
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
		# An interceptor the attacker cannot destroy absorbs the attack for
		# free: the declared target is never fought, the major action and
		# its mana are spent, and the defender will always choose that
		# trade. A wall that intercepts everything it can reach makes the
		# attack pointless even when the attacker survives it.
		if not _would_destroy_target_in_battle(attacker, interceptor):
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
	if CardStrategy.counterstroke_can_answer(self, target, attacker, null, true):
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
	if match_manager == null or not _can_attack_creature(attacker, target):
		return -1000000
	var partner := match_manager._get_declared_attack_partner(attacker)
	var attack_cost := game_manager.get_creature_action_mana_cost(attacker, "attack") * _mana_rate()
	# Score the combat the defender can actually choose: interceptions plus
	# known prepared responses (The Inferno / Void Shield / Smite) for every
	# attack, not only intercepted ones. The replies-aware combat planner
	# refuses attacks a prepared answer punishes; this fallback scorer must
	# agree with that verdict instead of valuing the declared target as if
	# the attack must resolve.
	var has_interceptors := not match_manager._get_possible_interceptors(attacker, target).is_empty()
	var projected_score := -1000000
	for candidate in _get_attack_candidates(attacker, partner):
		if candidate.get("target", null) != target:
			continue
		var projected_result := _project_attack(candidate)
		if projected_result.is_empty() or projected_result["opponent_wins"]:
			return -1000000
		projected_score = _score_attack_economy(projected_result) - attack_cost
		break
	if projected_score <= 0:
		return -1000000
	if not has_interceptors:
		# With nothing able to answer, the fallback still wants a clean kill.
		if _is_attack_target_tactically_bad(attacker, target):
			return -1000000
		if not _would_destroy_target_in_battle(attacker, target):
			return -1000000
	return projected_score + attacker.get_effective_speed() * 30

func _can_kill_with_all_attackers(attackers: Array[Card]) -> bool:
	if opponent == null or game_manager == null or game_manager.has_turn_follower_loss_prevention(opponent):
		return false
	var total_damage := 0
	for attacker in attackers:
		if _can_attack_followers_safely(attacker):
			total_damage += _get_direct_follower_damage(attacker)
	return total_damage >= opponent.followers + opponent.guard

func _get_direct_follower_damage(attacker: Card) -> int:
	return GameManager.apply_follower_damage_halvings(
		_get_combat_strength(attacker), GameManager.combat_follower_damage_halvings(attacker)
	)

func _plan_scavenge_against_unknown_stealth() -> Dictionary:
	var best := {}
	var best_score := 0
	var targets := _get_board_creatures(opponent).filter(func(card: Card) -> bool:
		return card.is_stealth and not card.is_petrified() and not CardStrategy.visible(self, card)
	)
	if targets.is_empty():
		return best
	for attacker in _get_attack_ready_creatures():
		if not (attacker is HyenaPack) or attacker.abilities_suppressed() or not match_manager.can_attack(attacker):
			continue
		var recruits := _get_scavenge_recruits(attacker)
		if recruits.is_empty():
			continue
		var strength := _get_attack_strength_against_defense(attacker)
		var kill_chance := CardStrategy.estimate_defensive_kill_chance(strength)
		# Resilience 24 is near the upper quartile of the reach curve. Use it
		# to price the follower damage from a strong Stealth defender.
		var damage_on_miss := maxi(0, 24 - strength - bot_player.guard)
		var miss_cost := _score_follower_loss(bot_player, damage_on_miss) if game_manager.can_player_lose_followers_now(bot_player) else 0
		if game_manager._has_ferocious_defence(opponent):
			miss_cost += _get_card_economic_value(attacker)
		var score := roundi(kill_chance * (ECON_CARD_VALUE + _get_scavenge_value(recruits)) - (1.0 - kill_chance) * miss_cost)
		score -= game_manager.get_creature_action_mana_cost(attacker, "attack") * _mana_rate()
		if score <= best_score:
			continue
		for target in targets:
			if not _can_attack_creature(attacker, target) or game_manager.is_warded_from_combat_destruction(target, attacker) \
					or _known_prepared_response_punishes_attack(attacker, target) or not _is_attack_safe_from_interceptors(attacker, target):
				continue
			best = {"attacker": attacker, "target": target, "score": score}
			best_score = score
			break
	return best

func _get_best_stealth_attack(attackers: Array[Card], opposing_creatures: Array[Card]) -> Dictionary:
	var best_attacker: Card = null
	var best_target: Card = null
	var best_target_value := -1
	var best_attacker_value := 0
	for target in opposing_creatures:
		if target == null or not (target.is_stealth or target.is_face_down):
			continue
		var target_value := _get_card_economic_value(target) if CardStrategy.visible(self, target) else CardStrategy.CARD_VALUE
		var cheapest_attacker: Card = null
		var cheapest_attacker_value := 0
		for attacker in attackers:
			if not _can_attack_creature(attacker, target):
				continue
			if _known_prepared_response_punishes_attack(attacker, target):
				continue
			if not _is_attack_safe_from_interceptors(attacker, target):
				continue
			if not _would_destroy_target_in_battle(attacker, target):
				continue
			if not _would_attacker_survive_battle(attacker, target):
				continue
			var attacker_value := _get_card_economic_value(attacker)
			if cheapest_attacker == null or attacker_value < cheapest_attacker_value:
				cheapest_attacker = attacker
				cheapest_attacker_value = attacker_value
		if cheapest_attacker == null:
			continue
		if best_attacker == null or target_value > best_target_value or (target_value == best_target_value and cheapest_attacker_value < best_attacker_value):
			best_attacker = cheapest_attacker
			best_target = target
			best_target_value = target_value
			best_attacker_value = cheapest_attacker_value
	if best_attacker == null:
		return {}
	return {"attacker": best_attacker, "target": best_target}

func _get_best_safe_followers_attack(attackers: Array[Card]) -> Dictionary:
	if opponent == null or game_manager == null or match_manager == null:
		return {}
	if not game_manager.can_player_lose_followers_now(opponent):
		return {}
	var best_attacker: Card = null
	var best_score := -1000000
	for attacker in attackers:
		if attacker == null or not _can_attack_followers_safely(attacker):
			continue
		if _known_prepared_response_punishes_attack(attacker, opponent):
			continue
		var score := _score_followers_attack(attacker)
		if best_attacker == null or score > best_score:
			best_attacker = attacker
			best_score = score
	if best_attacker == null:
		return {}
	return {"attacker": best_attacker}

func _has_gidim_ensi_removal_before_followers(attackers: Array[Card]) -> bool:
	# Returns true when a distinct ready attacker can cleanly kill a face-up
	# opponent Gidim Ensi before another attacker safely attacks followers.
	# Attacking followers while a face-up Gidim Ensi is on the field sleeps the
	# attacker, so removing it first avoids that lock.
	var safe_followers: Array[Card] = []
	for attacker in attackers:
		if attacker != null and _can_attack_followers_safely(attacker):
			safe_followers.append(attacker)
	if safe_followers.is_empty():
		return false
	for card in _get_board_creatures(opponent):
		if not (card is GidimEnsi):
			continue
		if card.is_face_down or card.is_stealth:
			continue
		if not CardStrategy.visible(self, card):
			continue
		for remover in attackers:
			if remover == null or not match_manager.can_attack(remover):
				continue
			if not _can_attack_creature(remover, card):
				continue
			if not _is_clean_creature_kill(remover, card):
				continue
			for safe_attacker in safe_followers:
				if safe_attacker != remover:
					return true
	return false

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

func _forecast_expired_combat_stats(turn_offset: int) -> Dictionary:
	var stats := {}
	for card in game_manager.get_field_cards():
		if not CardStrategy.visible(self, card):
			continue
		var expiry_delta := Vector3i.ZERO
		for buff in card._get_effective_buffs():
			var expires_turn = buff.get("expires_turn")
			# These rage buffs are cleared by card hooks at combat or turn end.
			var source := buff.get("source_card") as Card
			var rage_ends: bool = source is BerserkerMead or (source is Berserker and buff.get("effect_type") == "rage_buff")
			if rage_ends or (expires_turn != null and int(expires_turn) < game_manager.turn_number + turn_offset):
				expiry_delta -= Vector3i(buff.get("str", 0), buff.get("res", 0), buff.get("spd", 0))
		if expiry_delta != Vector3i.ZERO:
			stats[card] = expiry_delta
	return stats

func _forecast_stat_combat_gain(recipient: Card, before: Dictionary, after: Dictionary, turn_offset: int) -> int:
	var attacking_player := opponent if turn_offset == 1 else bot_player
	var defending_player := bot_player if attacking_player == opponent else opponent
	var restriction: Dictionary = game_manager.attack_restrictions.get(attacking_player, {})
	var turns_ended := 1 if turn_offset == 2 else 0
	if int(restriction.get("turns", 0)) > turns_ended:
		return 0
	var attackers := _get_attack_ready_creatures() if turn_offset == 0 else _get_board_creatures(attacking_player)
	var interceptors := _get_board_creatures(defending_player)
	var targets: Array = [defending_player]
	for defender in game_manager.get_field_cards(defending_player):
		if CardStrategy.visible(self, defender) and defender.card_type in [Card.CardType.CREATURE, Card.CardType.STRUCTURE]:
			targets.append(defender)
	var budget := attacking_player.mana
	if turn_offset > 0:
		budget += game_manager.get_automatic_upkeep_mana_gain(attacking_player, game_manager.turn_number + turn_offset) \
			+ game_manager.get_effective_upkeep_mana_gain(game_manager.get_base_upkeep_mana_gain(), attacking_player)
	var best_gain := 0
	var worst_before := 0
	var worst_after := 0
	for attacker in attackers:
		if attacker.current_zone not in attacking_player.frontline_zones or not CardStrategy.visible(self, attacker):
			continue
		if turn_offset == 0 and _has_committed_attack(attacker):
			continue
		if turn_offset > 0 and ((attacker.creature_mode != Card.CreatureMode.AGGRESSIVE and not attacker.is_stealth) \
				or _status_persists_to_next_turn(attacker, "sleep", [], turn_offset) \
				or _status_persists_to_next_turn(attacker, "cannot_attack", [], turn_offset)):
			continue
		if game_manager.get_creature_action_mana_cost(attacker, "attack") > budget:
			continue
		var action := CardAction.new()
		action.type = CardAction.Type.ATTACK
		action.attacker = attacker
		action.source_player = attacking_player
		# A declared partner depends on actions already spent this turn.
		if turn_offset == 0:
			action.united_front_partner = match_manager._get_declared_attack_partner(attacker)
		if attacking_player == bot_player and recipient.get_controller() == bot_player \
				and recipient != attacker and recipient != action.united_front_partner:
			continue
		var best_before := 0
		var best_after := 0
		var allies := [action.united_front_partner] if action.united_front_partner != null else []
		for target in targets:
			action.target = target
			if target is Card and not _can_attack_creature(attacker, target):
				continue
			if target is Player and game_manager.is_followers_attack_blocked_by_active_structure(attacker, target, allies):
				continue
			if target is Card and not allies.is_empty() and game_manager.is_attack_blocked_by_active_structure(attacker, target, allies):
				continue
			var old_score := _score_stat_attack_line(action, before, interceptors, turn_offset)
			var new_score := old_score
			if recipient in [attacker, action.united_front_partner, target] or recipient in interceptors:
				new_score = _score_stat_attack_line(action, after, interceptors, turn_offset)
			best_before = maxi(best_before, old_score)
			best_after = maxi(best_after, new_score)
		best_gain = maxi(best_gain, best_after - best_before)
		worst_before = maxi(worst_before, best_before)
		worst_after = maxi(worst_after, best_after)
	if attacking_player == opponent:
		return maxi(0, worst_before - worst_after)
	return best_gain

func _score_stat_attack_line(action: CardAction, stats: Dictionary, interceptors: Array[Card], turn_offset: int) -> int:
	var perspective := 1 if action.source_player == bot_player else -1
	var score := perspective * _score_attack_economy(_estimate_projected_attack_economy(action, stats))
	var attacker := action.attacker
	if attacker.prevents_interception():
		return score
	var attack_speed := attacker.get_effective_speed(stats.get(attacker, Vector3i.ZERO).z)
	var partner := action.united_front_partner
	if partner != null:
		attack_speed = mini(attack_speed, partner.get_effective_speed(stats.get(partner, Vector3i.ZERO).z))
	for interceptor in interceptors:
		if interceptor == action.target \
				or _status_persists_to_next_turn(interceptor, "sleep", [], turn_offset) \
				or _status_persists_to_next_turn(interceptor, "cannot_intercept", [], turn_offset):
			continue
		if not CardStrategy.visible(self, interceptor):
			score = mini(score, 0)
			continue
		var speed_delta: int = stats.get(interceptor, Vector3i.ZERO).z
		if not match_manager._can_intercept(interceptor, attacker, action.target, interceptor, speed_delta, attack_speed, null, -1, null, turn_offset > 0):
			continue
		action.interceptor = interceptor
		score = mini(score, perspective * _score_attack_economy(_estimate_projected_attack_economy(action, stats)))
	action.interceptor = null
	return score

func _can_attack_followers_after_modifiers(attacker: Card, stats: Dictionary) -> bool:
	if game_manager.is_followers_attack_blocked_by_active_structure(attacker, opponent, []):
		return false
	if attacker.prevents_interception():
		return true
	var attack_speed := attacker.get_effective_speed(stats.get(attacker, Vector3i.ZERO).z)
	var partner := match_manager._get_declared_attack_partner(attacker)
	if partner != null:
		attack_speed = mini(attack_speed, partner.get_effective_speed(stats.get(partner, Vector3i.ZERO).z))
	# Unknown defenders may have special intercept hooks. Do not use their hidden
	# identities or assume a speed change can evade them.
	for interceptor in _get_board_creatures(opponent):
		if not CardStrategy.visible(self, interceptor):
			return false
		if match_manager._can_intercept(interceptor, attacker, opponent, interceptor, stats.get(interceptor, Vector3i.ZERO).z, attack_speed):
			return false
	return true

func _can_win_followers_after_modifiers(stats: Dictionary) -> bool:
	if game_manager.has_turn_follower_loss_prevention(opponent):
		return false
	var total_damage := 0
	for attacker in _get_attack_ready_creatures():
		if _has_committed_attack(attacker) or not _can_attack_followers_after_modifiers(attacker, stats):
			continue
		var damage := _get_combat_strength(attacker, null, stats.get(attacker, Vector3i.ZERO).x)
		total_damage += GameManager.apply_follower_damage_halvings(damage, GameManager.combat_follower_damage_halvings(attacker))
	return total_damage >= opponent.followers + opponent.guard

func _score_followers_attack(attacker: Card) -> int:
	if attacker == null or opponent == null or match_manager == null:
		return -1000000
	var action := CardAction.new()
	action.type = CardAction.Type.ATTACK
	action.attacker = attacker
	action.united_front_partner = match_manager._get_declared_attack_partner(attacker)
	action.target = opponent
	var score := _score_attack_economy(_estimate_attack_economy(action, null, 0, 0))
	score += attacker.get_effective_speed() * 25
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
	var borrowed := game_manager.is_temporarily_controlled(creature)
	var added_casualty_cost := -_stance_casualty_savings(creature, Card.CreatureMode.AGGRESSIVE)
	# Going aggressive also exposes the creature to a plausible enemy summon
	# or reserve advance next turn that would clear it in aggressive stance
	# but bounce off its defensive RES. Charge that risk here so a valuable
	# defender is only spent on a switch the attack actually pays for.
	# A borrowed body is exempt from both charges: it leaves at this turn's
	# end, and its combat death is the owner's loss, never the bot's.
	if not borrowed:
		added_casualty_cost += _forecast_aggressive_exposure_risk(creature)
	if added_casualty_cost > 0:
		if not creature.can_take_major_creature_action():
			return -1
		var stance_cost := game_manager.get_creature_action_mana_cost(creature, "change stance")
		var partner := match_manager._get_declared_attack_partner(creature)
		var combat := _plan_combat(_get_attack_candidates(creature, partner), [], null, stance_cost)
		var score := int(combat.get("score", 0)) - stance_cost * _mana_rate() - added_casualty_cost
		if bool(combat.get("lethal", false)):
			return 2000000 + score
		return 300000 + score if score > 0 else -1
	if creature is Askelladen and _get_best_askelladen_target_for(creature as Askelladen, opposing_creatures) != null:
		return 1000000 + creature.get_effective_strength() * 100
	if opposing_creatures.is_empty():
		return 500000 + _score_followers_attack(creature)
	var best_attack_score := -1000000
	for target in opposing_creatures:
		best_attack_score = maxi(best_attack_score, _score_standard_attack_plan(creature, target))
	if best_attack_score <= -1000000:
		# No profitable creature target, but a followers poke nobody can
		# intercept is still an attack plan worth flipping aggressive for.
		if _can_attack_followers_safely(creature):
			return 500000 + _score_followers_attack(creature)
		# Str-tilted body with no plan at all: flip anyway. Aggressive stance
		# defends at STR, which for a str>res body is strictly harder to kill
		# than its defensive RES (Humbaba 27/20 defends at 27 aggressive vs 20
		# defensive), and the exposure forecast charges nothing for str>=res
		# bodies. This rescues strong attackers stuck defensive with no legal
		# plan this turn; the defensive flip scorer refuses str-tilted savings
		# (negative), so the two scorers cannot oscillate.
		# A borrowed body always qualifies for that fallback: it cannot defend
		# for the bot after this turn anyway, and handing it back aggressive
		# makes the owner pay their own stance change or defend at STR.
		if _get_projected_strength(creature) > _get_projected_resilience(creature) or borrowed:
			return 1000 + _get_projected_strength(creature) * 10
		return -1
	return 300000 + best_attack_score

func _get_defensive_mode_switch_score(creature: Card, opposing_creatures: Array[Card]) -> int:
	if creature == null or creature.card_type != Card.CardType.CREATURE:
		return -1
	if creature.creature_mode != Card.CreatureMode.AGGRESSIVE:
		return -1
	# A borrowed body (Siren's Song) returns to its owner at this turn's end,
	# so defensive stance guards nothing for the bot — it only hands the
	# opponent their body back pre-defended. Never flip a borrow defensive.
	if game_manager.is_temporarily_controlled(creature):
		return -1
	if not creature.can_take_minor_creature_action():
		return -1
	if creature.is_sleeping or not game_manager.can_pay_creature_action_mana_cost(creature, "change stance"):
		return -1
	var farm_bait := _is_combat_farm_bait(creature, _get_creature_attackers_next_turn(creature, []))
	if creature.can_take_major_creature_action():
		var has_attack_plan := false
		for target in opposing_creatures:
			if _score_standard_attack_plan(creature, target) > -1000000:
				has_attack_plan = true
				break
		# Only a farm bait with no attack plan while followers are healthy
		# skips the preservation block: staying aggressive would just feed
		# the enemy farm, so flip now.
		if not farm_bait or has_attack_plan or _is_dangerously_low_on_followers():
			# Preserve the attack option while followers are plentiful.
			if not _is_dangerously_low_on_followers():
				return -1
			if has_attack_plan:
				return -1
			if opposing_creatures.is_empty() and _can_attack_followers_safely(creature):
				return -1
	# Once the attack is spent, preserving the creature can justify a stance
	# change even when follower pressure is low. An intercept-free followers
	# lane is not a standing poke once the forecast shows the body destroyed
	# in aggressive stance before its next attack: with no future poke income,
	# the casualty savings outrank the per-turn stance tax of flipping back.
	# A farm bait prices the follower leak itself: its casualty savings are
	# zero because no stance can save it from combat, but defensive stance
	# stops the enemy from draining followers off its body every turn.
	var savings := _stance_casualty_savings(creature, Card.CreatureMode.DEFENSIVE) \
		+ (_combat_farm_bait_savings(creature) if farm_bait else 0) \
		- game_manager.get_creature_action_mana_cost(creature, "change stance") * _mana_rate()
	return savings if savings > 0 else -1

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

# ── Activatable mana sources ────────────────────────────────────────────────
# The bot plans against more than the printed stock: a ready prepared Mead of
# Poetry brews as a zero-mana main-phase action, Immortal Techniques refunds
# each spell or Ancient hex while a friendly Mage is fielded, a hidden Pictish
# Beast banks its Mana Boon the moment it reveals in combat, and Pazuzu's
# Locust Plague taxes the stock carried past this turn. Sources the bot
# triggers on purpose are submitted as a setup step first; the next planning
# pass sees the real grown stock and takes the paid follow-up on its own.

func _ready_brew_mana_gain() -> int:
	# Mana a ready prepared Mead can bank right now. The brew costs no mana,
	# so any planned spend it covers is reachable by brewing first.
	if game_manager == null or bot_player == null:
		return 0
	if _find_ready_prepared_mead() == null:
		return 0
	if not game_manager.can_player_gain_mana_now(bot_player):
		return 0
	return MeadOfPoetry.MANA_GAIN

func _incoming_mana_drain() -> int:
	# Pazuzu's Locust Plague drains at each of its controller's turn starts,
	# so every enemy copy the bot can see taxes the stock it carries into
	# its next turn. Hidden copies stay unknown; only visible bodies price in.
	if opponent == null or game_manager == null:
		return 0
	var drain := 0
	for enemy in _get_board_creatures(opponent):
		if enemy is Pazuzu and CardStrategy.visible(self, enemy) \
				and not enemy.abilities_suppressed():
			drain += Pazuzu.MANA_DRAIN
	return drain

func _immortal_techniques_refund_gain(card: Card) -> int:
	# The +1 lands right after the triggering spell or Ancient hex resolves,
	# so the refund is priced into the cast itself and follow-ups planned
	# later in the turn see the real stock.
	if card == null or bot_player == null or game_manager == null:
		return 0
	if not game_manager.can_player_gain_mana_now(bot_player):
		return 0
	var triggers_refund := card.card_type == Card.CardType.SPELL \
		or (card.card_type == Card.CardType.HEX and str(card.culture) == "Ancient")
	if not triggers_refund:
		return 0
	var refund := 0
	for power in _get_player_powers():
		if power is ImmortalTechniques and power.is_effectively_active() \
				and power._has_friendly_mage_on_field(game_manager):
			refund += 1
	return refund

func _can_activate_after_brew(card: Card) -> bool:
	# can_activate prices paid board abilities against the current stock only.
	# Lending the brew to the stock for the check (the same temporary-mutation
	# pattern the summon payment validation uses) keeps an ability live
	# whenever the brew could fund it; every non-mana condition — targets,
	# per-turn uses, stance, action economy — still gates verbatim inside
	# can_activate itself.
	if card == null or game_manager == null or bot_player == null:
		return false
	return _passes_after_brew(func() -> bool: return card.can_activate(game_manager))

func _passes_after_brew(check: Callable) -> bool:
	# Generic brew lend for affordability gates the engine prices against the
	# current stock (board activations, hand casts, prepared activations).
	# Only the mana gate relaxes: every other condition inside the check
	# still gates verbatim, and the stock is restored before returning.
	if bot_player == null or not check.is_valid():
		return false
	var brew := _ready_brew_mana_gain()
	if brew <= 0:
		return false
	if check.call():
		return true
	var original_mana := bot_player.mana
	bot_player.mana += brew
	var passed: bool = check.call()
	bot_player.mana = original_mana
	return passed

func _brew_setup_plan(plan: Dictionary) -> Dictionary:
	# The brew command that stands in for a brew-tagged plan, carrying the
	# line's score and lethal flag so it competes as the full line it funds.
	# (The brew plan itself is never tagged: it is submitted directly.)
	var mead := _find_ready_prepared_mead()
	if mead == null:
		return {}
	var brew := {
		"command": {
			"type": "cast_charm",
			"charm_uid": mead.uid,
			"target_uid": "",
			"prepared": true,
		},
		"score": int(plan.get("score", 0)),
	}
	if bool(plan.get("lethal", false)):
		brew["lethal"] = true
	return brew

# True when a line that spends `spend` mana is payable only after the brew.
func _brew_enables_spend(spend: int) -> bool:
	var brew := _ready_brew_mana_gain()
	return brew > 0 and spend > bot_player.mana and spend <= bot_player.mana + brew

# Submit a planned attack line, brewing the Mead first when its action taxes
# run past the current stock (usually the lethal line).
func _submit_attack_line(line: Dictionary, budgeted: bool, mana_budget: int) -> bool:
	if line.is_empty():
		return false
	if budgeted and _brew_enables_spend(int(line.get("mana_required", mana_budget - int(line.get("mana", mana_budget))))):
		var brew := _brew_setup_plan(line)
		return not brew.is_empty() and _submit_action(brew["command"])
	return _submit_attack(line["attacker"], line["target"])

# Submit a god ability, brewing the Mead first when its price runs past the
# current stock; the next pass replays the same ability on the grown stock.
func _submit_god_ability_with_brew(god: GodCard, target_uid: String = "") -> bool:
	if god == null:
		return false
	var price: int = god.get_activation_mana_cost(game_manager) if god.has_method("get_activation_mana_cost") else 0
	if _brew_enables_spend(price):
		var brew := _brew_setup_plan({})
		return not brew.is_empty() and _submit_action(brew["command"])
	var command := {"type": "god_ability", "god_uid": god.uid}
	if not target_uid.is_empty():
		command["target_uid"] = target_uid
	return _submit_action(command)

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
	# A visible enemy Pazuzu drains the stock before the drawn creature can be
	# played next turn, so the projection spends what actually remains.
	projected_mana -= _incoming_mana_drain()
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
			retreat_score += _follower_safety_gain(danger, {"removed": [ask_card, other_card]}, bot_player.mana)
			fight_score += _follower_safety_gain(danger, {
				"removed": fight["casualties"],
				"followers": bot_player.followers - int(fight["bot_followers_lost"]) + int(fight.get("bot_followers_gained", 0)),
				"guard": bot_player.guard - int(fight.get("bot_guard_spent", 0)),
			}, bot_player.mana, false)
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

func _can_askelladen_retreat(ask_card: Askelladen, other_card: Card, stats: Dictionary = {}) -> bool:
	if ask_card == null or other_card == null:
		return false
	if ask_card.is_face_down or ask_card.abilities_suppressed():
		return false
	if game_manager == null:
		return false
	if game_manager.is_immune_to_source(other_card, ask_card):
		return false
	if other_card.get_effective_speed(stats.get(other_card, Vector3i.ZERO).z) > ask_card.get_effective_speed(stats.get(ask_card, Vector3i.ZERO).z):
		return false
	if game_manager.is_guardian_protected(other_card, ask_card):
		return false
	return true

func _get_attack_ready_creatures(projected_mana: int = -1) -> Array[Card]:
	var ready_creatures: Array[Card] = []
	if bot_player == null or game_manager == null:
		return ready_creatures
	if game_manager.attack_restrictions.has(bot_player):
		return ready_creatures
	var mana := bot_player.mana if projected_mana < 0 else projected_mana
	for zone in bot_player.frontline_zones:
		for card in zone.cards:
			if card == null or card.card_type != Card.CardType.CREATURE or card.get_controller() != bot_player:
				continue
			if card.creature_mode != Card.CreatureMode.AGGRESSIVE and not card.is_stealth:
				continue
			if card.is_sleeping or not card.get_status_effect("cannot_attack").is_empty():
				continue
			if card.summoned_after_first_attack_this_turn:
				continue
			if game_manager.is_first_turn_attack_blocked_by_weather(card):
				continue
			if game_manager.get_creature_action_mana_cost(card, "attack") > mana:
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

func _get_first_open_summon_zone(player: Player, occupied_zone: Zone = null) -> Zone:
	if player == null:
		return null
	var frontline_zone := _get_central_open_zone(player.frontline_zones, occupied_zone)
	if frontline_zone != null:
		return frontline_zone
	return _get_central_open_zone(player.reserve_zones, occupied_zone)

# Summon lane candidates for the placement pass: the most central open
# frontline lanes first, then reserve lanes. Column choice only changes
# equipment pickup reach in this engine (attacks and interception reach are
# lane-independent), so a bounded center-out sample covers the meaningful
# placements while keeping the central bias as the tiebreaker.
func _get_open_summon_lane_candidates(player: Player, max_per_row: int = 3) -> Array[Zone]:
	var candidates: Array[Zone] = []
	if player == null:
		return candidates
	for rows in [player.frontline_zones, player.reserve_zones]:
		var taken := 0
		for zone in _get_center_out_open_zones(rows):
			candidates.append(zone)
			taken += 1
			if taken >= max_per_row:
				break
	return candidates

func _get_center_out_open_zones(zones: Array[Zone]) -> Array[Zone]:
	var center := float(zones.size() - 1) / 2.0
	var open_indexes: Array[int] = []
	for index in range(zones.size()):
		var zone := zones[index]
		if zone != null and zone.cards.is_empty():
			open_indexes.append(index)
	open_indexes.sort_custom(func(a: int, b: int) -> bool:
		var distance_a := absf(float(a) - center)
		var distance_b := absf(float(b) - center)
		if distance_a != distance_b:
			return distance_a < distance_b
		return a < b
	)
	var ordered: Array[Zone] = []
	for index in open_indexes:
		ordered.append(zones[index])
	return ordered

func _get_first_open_reserve_zone(player: Player) -> Zone:
	if player == null:
		return null
	return _get_central_open_zone(player.reserve_zones)

func _get_prepare_zone() -> Zone:
	var reserve := _get_first_open_reserve_zone(bot_player)
	if reserve != null:
		return reserve
	# Keep at least one frontline slot available for a creature.
	var frontline := _get_center_out_open_zones(bot_player.frontline_zones)
	return frontline[0] if frontline.size() > 1 else null

func _get_central_open_zone(zones: Array[Zone], occupied_zone: Zone = null) -> Zone:
	# Prefer the middle lane, then work outward; equal distances keep row order.
	var center := float(zones.size() - 1) / 2.0
	var best_zone: Zone = null
	var best_distance := INF
	for index in range(zones.size()):
		var zone := zones[index]
		if zone == null or zone == occupied_zone or not zone.cards.is_empty():
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
	return power is CallOfTheValkyrie or power is AllfathersSacrifice or CardStrategy.key(power) in CardStrategy.ACTIVE_POWERS

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
	return _manifestation_deployment_value(manifestation, mana_paid, mode)

func _manifestation_deployment_value(manifestation: Card, mana_paid: int, mode: Card.CreatureMode) -> int:
	var opposing_creatures := _get_board_creatures(opponent)
	@warning_ignore("integer_division")
	var score := ECON_CARD_VALUE + _score_projected_card(manifestation) - mana_paid * 350 * _mana_rate() / 1000
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
		var damage := GameManager.apply_follower_damage_halvings(
			manifestation.get_effective_strength(), GameManager.combat_follower_damage_halvings(manifestation)
		)
		return damage > 0
	return false

func _choose_creature_summon_mode(card: Card, opposing_creatures = null) -> Card.CreatureMode:
	if card == null or card.card_type != Card.CardType.CREATURE:
		return Card.CreatureMode.DEFENSIVE
	var resolved_opposing: Array[Card] = _get_board_creatures(opponent) if opposing_creatures == null else opposing_creatures
	var has_clean_kills := _count_clean_attack_targets_for(card, resolved_opposing) > 0
	var ready_protection := _get_own_protective_responses().size() > 0
	# Real work check, usable by any statline: a target the creature destroys
	# and survives the fight against is a reasonably profitable attack even
	# when it is not fully "clean" (interceptor risk keeps the strict verdict
	# rare, and strong attackers like Asag 33/21 kept falling through to the
	# defensive default because of it). Clean kills, board dominance, and the
	# res-tilted exemption below all reuse this.
	var has_profitable_attacks := has_clean_kills \
			or _is_projected_creature_strongest_on_board(card, resolved_opposing)
	if not has_profitable_attacks:
		for enemy in resolved_opposing:
			if enemy == null or not CardStrategy.visible(self, enemy):
				continue
			if _would_destroy_target_in_battle(card, enemy) and _would_attacker_survive_battle(card, enemy):
				has_profitable_attacks = true
				break
	# Aggressive stance defends at STR vs STR while defensive stance defends at
	# STR vs RES, so a res-dominant body summoned aggressive throws away its
	# better defense stat to poke with its worse one. Only true walls pay
	# that price: any body with profitable work on the board is an attacker
	# first (and can switch to defensive once the work dries up).
	# Exception: with a banked protective reply and an empty board the poke
	# is cheap, so the exposure forecast charges almost nothing for it.
	if _get_projected_resilience(card) > _get_projected_strength(card) and not has_profitable_attacks \
			and not (ready_protection and resolved_opposing.is_empty()):
		return Card.CreatureMode.DEFENSIVE
	if resolved_opposing.is_empty():
		return Card.CreatureMode.AGGRESSIVE
	if has_profitable_attacks:
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
		@warning_ignore("integer_division")
		score += maxi(0, _get_wheel_of_fire_target_value(target) / 3 - WheelOfFire.ADVANCE_COST * _mana_rate())
	if game_manager.current_player == bot_player:
		score += _wheel_follower_safety_gain(wheel, target, bot_player.mana - CardStrategy.activation_cost(self, wheel))
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
	return score - ECON_CARD_VALUE - mana_cost * _mana_rate() - _get_wheel_of_fire_mana_opportunity_cost(mana_cost)

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
			@warning_ignore("integer_division")
			return value / 3
		Zone.ZoneType.FRONTLINE:
			@warning_ignore("integer_division")
			var score := value * 3 / 5 + WheelOfFire.ACTION_TAX_AMOUNT * _mana_rate()
			if not target.is_face_down and not target.is_stealth:
				if target.creature_mode == Card.CreatureMode.AGGRESSIVE and not target.is_sleeping:
					@warning_ignore("integer_division")
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
			var damage := GameManager.apply_follower_damage_halvings(
				attacker.get_effective_strength(), GameManager.combat_follower_damage_halvings(attacker)
			)
			@warning_ignore("integer_division")
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
	score += _wheel_follower_safety_gain(wheel, wheel.attached_target, bot_player.mana - WheelOfFire.ADVANCE_COST)
	score -= WheelOfFire.ADVANCE_COST * _mana_rate()
	score -= _get_wheel_of_fire_mana_opportunity_cost(WheelOfFire.ADVANCE_COST)
	return score > 0

func _wheel_follower_safety_gain(wheel: WheelOfFire, target: Card, mana_left: int) -> int:
	if target == null or target.current_zone == null or not target.current_zone.is_board_zone():
		return 0
	var destination := wheel._get_next_zone_for_target(target)
	if destination == null:
		return 0
	var danger := _forecast_incoming_follower_loss()
	if destination.is_board_zone():
		return _follower_safety_gain(danger, {"moved": target, "destination": destination}, mana_left)
	if CardStrategy.can_remove_from_board(self, wheel, target, false):
		return _follower_safety_gain(danger, {"removed": [target]}, mana_left)
	return 0

func _estimate_attack_economy(action: CardAction, modified_card: Card, str_delta: int, speed_delta: int, res_delta: int = 0, include_retreat: bool = true, projected_defender_mode: int = -1, projected_defender_stealth: bool = false) -> Dictionary:
	var stats := {} if modified_card == null else {modified_card: Vector3i(str_delta, res_delta, speed_delta)}
	return _estimate_projected_attack_economy(action, stats, include_retreat, projected_defender_mode, projected_defender_stealth)

func _estimate_projected_attack_economy(action: CardAction, stats: Dictionary, include_retreat: bool = true, projected_defender_mode: int = -1, projected_defender_stealth: bool = false, reverse_follower_damage: bool = false) -> Dictionary:
	var result := _estimate_raw_attack_economy(action, stats, projected_defender_mode)
	var attack_halvings := 0
	var defense_halvings := 0
	var defender := _get_attack_defender_card(action)
	if action != null:
		# Only forecast passives on cards the bot can identify.
		var known_attacker: Card = action.attacker if CardStrategy.visible(self, action.attacker) else null
		var known_defender: Card = defender if CardStrategy.visible(self, defender) else null
		var known_partner: Card = action.united_front_partner if CardStrategy.visible(self, action.united_front_partner) else null
		var extra_halving := int(action.halve_follower_damage)
		attack_halvings = extra_halving + GameManager.combat_follower_damage_halvings(known_attacker, known_defender, known_partner)
		defense_halvings = extra_halving + GameManager.combat_follower_damage_halvings(known_attacker, known_defender, known_partner, true)
	for player in [bot_player, opponent]:
		if player == null:
			continue
		var loss_key := "bot_followers_lost" if player == bot_player else "opponent_followers_lost"
		var source_key := "bot_loss_source" if player == bot_player else "opponent_loss_source"
		var damage_from_defender: bool = defender != null and (result.get(source_key) == defender \
			or (result.get("defensive_conversion_defender") == defender and player == action.attacker.get_controller()))
		var halvings := defense_halvings if damage_from_defender else attack_halvings
		var amount := GameManager.apply_follower_damage_halvings(int(result[loss_key]), halvings)
		var recipient: Player = game_manager.get_opponent(player) if reverse_follower_damage else player
		if not recipient.followers_enabled or game_manager.has_turn_follower_loss_prevention(recipient):
			amount = 0
		result["bot_damage_before_guard" if recipient == bot_player else "opponent_damage_before_guard"] = amount
	if reverse_follower_damage:
		var bot_loss_source: Card = result.get("bot_loss_source")
		result["bot_loss_source"] = result.get("opponent_loss_source")
		result["opponent_loss_source"] = bot_loss_source
		result["reverse_follower_damage"] = true
	result = _combat_outcome_with_remaining_guard(result, {
		"bot_followers": bot_player.followers, "opponent_followers": opponent.followers,
		"bot_guard": bot_player.guard, "opponent_guard": opponent.guard,
	})
	if include_retreat:
		result = _estimate_retreat_economy(action, result, stats)
	if action != null and action.type == CardAction.Type.ATTACK:
		_add_deck_combat_rewards(action, result)
		for combatant: Card in [action.attacker, action.united_front_partner, defender]:
			if combatant == null or combatant.get_controller() != bot_player \
					or not (combatant.is_stealth or (combatant == defender and projected_defender_stealth)):
				continue
			if combatant.has_veil_of_night():
				if combatant != defender and combatant not in result["casualties"] \
						and not combatant.is_publicly_identified(game_manager):
					result["concealment_value"] = int(result.get("concealment_value", 0)) + VEIL_CONCEALMENT_VALUE
				continue
			if combatant.abilities_suppressed_by_effects():
				continue
			if combatant == defender and (combatant is MasmassuPriest or combatant is Grindylow):
				var targets := _get_reveal_removal_targets(combatant)
				var target := _choose_combat_reveal_removal(combatant, targets, action, result["casualties"])
				if target != null:
					_add_destroyed_card_to_economy(result, target)
					result["reveal_bonus"] = int(result.get("reveal_bonus", 0)) + _reveal_removal_mana_value(combatant, target)
			else:
				if combatant is PictishBeast:
					var beasts: Array = result.get_or_add("mana_boon_sources", [])
					beasts.append(combatant)
				result["reveal_bonus"] = int(result.get("reveal_bonus", 0)) + _estimate_reveal_trigger_value(combatant)
				# Swinging with a hidden reveal-removal body spends the banked
				# trigger even when no target exists yet. Charge the forgone
				# bank so a followers poke cannot cash a Dalkhu Break trap for
				# nothing; an attacking reveal with a real target still nets
				# its value minus the discounted banked floor.
				result["reveal_bonus"] = int(result.get("reveal_bonus", 0)) - _banked_reveal_removal_value(combatant)
		_add_expiring_combat_tokens(action, defender, result)
		_add_mummu_entropy_combat_value(action, defender, result)
		var stand_reward := _heroic_stand_combat_reward(action, defender, result)
		if stand_reward > 0:
			result["heroic_stand_reward"] = stand_reward
	return result

func _heroic_stand_combat_reward(action: CardAction, defender: Card, result: Dictionary) -> int:
	if result["bot_wins"] or result["opponent_wins"] or action.attacker == null \
			or not action.attacker.is_creature_card() or not CardStrategy.visible(self, defender) \
			or not defender.is_creature_card() or defender.is_god or defender.is_petrified():
		return 0
	var combats := 0
	for creature: Card in [action.attacker, action.united_front_partner, defender]:
		if creature != null and creature.get_controller() == bot_player and creature.is_creature_card() \
				and creature not in result["casualties"]:
			combats = maxi(combats, creature.combats_this_game)
	if combats < HeroicStand.COMBAT_THRESHOLD - 2 or combats >= HeroicStand.COMBAT_THRESHOLD \
			or not game_manager.can_player_gain_mana_now(bot_player):
		return 0
	var best := 0
	for card: Card in bot_player.hand_zone.cards + game_manager.prepared_charms.keys():
		if card.card_owner != bot_player or not card is HeroicStand or card.is_activation_locked(game_manager) \
				or game_manager._has_pending_stack_action_for_card(card):
			continue
		if card.is_prepared and (card.is_muted or card.current_zone == null or not card.current_zone.is_board_zone()):
			continue
		if not card.get_qualified_creatures(game_manager).is_empty():
			return 0
		var value := CardStrategy.mana_gain_value(self, HeroicStand.MANA_GAIN) - ECON_CARD_VALUE \
			- CardStrategy.mana_penalty(self, CardStrategy.activation_cost(self, card))
		# A hand copy waits for our turn; a freshly prepared copy also has to wait.
		if (not card.is_prepared and game_manager.current_player != bot_player) \
				or (card.is_prepared and not game_manager.is_prepared_charm_ready(card)):
			@warning_ignore("integer_division")
			value /= 2
		best = maxi(best, value)
	# The second combat still leaves another fight to find and survive.
	@warning_ignore("integer_division")
	return best if combats == HeroicStand.COMBAT_THRESHOLD - 1 else best / 4

func _add_expiring_combat_tokens(action: CardAction, defender: Card, result: Dictionary) -> void:
	var casualties: Array = result["casualties"]
	for combatant: Card in [action.attacker, action.united_front_partner, defender]:
		if not CardStrategy.visible(self, combatant) or not CardStrategy.expires_after_combat(combatant) \
				or combatant in casualties or CardStrategy.destruction_guard(combatant):
			continue
		var status := combatant.get_status_effect(Card.DESTROY_AFTER_COMBAT_STATUS)
		var source := status.get("source_card") as Card
		if source != null and source.get_controller() != combatant.get_controller() \
				and game_manager.has_turn_destruction_ward(combatant.get_controller()):
			continue
		_add_destroyed_card_to_economy(result, combatant)

func _get_scavenge_recruits(slayer: HyenaPack) -> Dictionary:
	var zones := slayer.get_available_scavenge_zones()
	# A projected summon from hand already occupies its own lane.
	var lane_count := zones.size() - int(slayer.current_zone == bot_player.hand_zone)
	var recruits := {}
	for card: Card in bot_player.deck_zone.get_unordered_deck_cards():
		if recruits.size() >= lane_count:
			break
		if card is HyenaPack and game_manager.can_pay_creature_summon_cost(bot_player, card, null, false):
			recruits[card] = zones[recruits.size()]
	return recruits

func _get_scavenge_value(recruits: Dictionary) -> int:
	var value := 0
	for card: Card in recruits:
		value += _get_card_economic_value(card)
	return value

func _add_deck_combat_rewards(action: CardAction, result: Dictionary) -> void:
	var casualties: Array = result.get("casualties", [])
	if casualties.is_empty() or bool(result.get("bot_wins", false)) or bool(result.get("opponent_wins", false)):
		return
	# Only some slayer branches seed this key, but the additions below always
	# accumulate onto it. Normalize so a missing seed cannot error out.
	result["deck_reward"] = int(result.get("deck_reward", 0))
	var slayer := result.get("bot_slayer") as Card
	if slayer is HyenaPack:
		var recruits := _get_scavenge_recruits(slayer)
		result["scavenge_count"] = recruits.size()
		result["scavenge_value"] = _get_scavenge_value(recruits)
		result["scavenge_recruits"] = recruits
		result["scavenge_summons"] = recruits
	elif slayer is Tatzelwurm and game_manager.can_player_add_to_hand_now(bot_player):
		var value := 0
		for target: Card in slayer.get_valid_targets(game_manager):
			value = maxi(value, _deck_card_hand_value(target, bot_player.mana))
		result["deck_reward"] = value
	elif slayer is AnkouServantToTheReaper and game_manager.can_player_add_to_hand_now(bot_player):
		# Reap draws a card on Slay.
		result["deck_reward"] += _expected_deck_draw_value(bot_player.mana)
	var offering_mana := _asakku_offering_mana(result, [])
	if offering_mana > 0:
		result["deck_reward"] += CardStrategy.mana_gain_value(self, offering_mana)
	if not _can_odin_draw_primed_card():
		return
	for card: Card in casualties:
		if card.get_controller() != bot_player or not (card is Huginn or card is Muninn):
			continue
		if card.abilities_suppressed_by_effects() or card.is_token:
			continue
		var killer := action.attacker if card == _get_attack_defender_card(action) else _get_attack_defender_card(action)
		if game_manager._should_class_rend(killer, card):
			continue
		var targets: Array[Card] = card.get_valid_hex_targets() if card is Huginn else card.get_valid_charm_targets()
		var known := bot_player.deck_zone.known_top_card
		var known_value := _deck_card_hand_value(known, bot_player.mana) if known != null else 0
		for target in targets:
			var gain := _deck_card_hand_value(target, bot_player.mana) - known_value
			@warning_ignore("integer_division")
			result["deck_reward"] = maxi(int(result.get("deck_reward", 0)), gain * 2 / 3)

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
			excluded = _estimate_raw_attack_economy(action, {})["casualties"]
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
	if source is Fenrir:
		if target_uids.is_empty():
			return ""
		var devour := _forecast_fenrir_devour(source, danger, {}, target_uids)
		var prey := devour.get("target") as Card
		return prey.uid if prey != null else ""
	if source is GugalannaBullOfHeaven:
		var targets := target_uids.map(func(uid) -> Card: return game_manager.get_card_by_uid(str(uid)))
		var charge := _forecast_celestial_charge(source, targets, danger, {})
		var victim := charge.get("target") as Card
		return victim.uid if victim != null else ""
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
		var own := target.get_controller() == bot_player
		var value := CardStrategy.value(self, target)
		var score := (-value if own else value) + _reveal_removal_mana_value(source, target)
		score += _follower_safety_gain(danger, {"removed": removed}, bot_player.mana)
		if score > best_score:
			best_score = score
			best_uid = str(uid)
	return best_uid

func _forecast_celestial_charge(source: GugalannaBullOfHeaven, targets: Array, danger: int, change: Dictionary) -> Dictionary:
	if targets.is_empty() or source.abilities_suppressed_by_effects():
		return {}
	var removed: Array = change.get("removed", [])
	var returns_to_hand := game_manager.can_player_add_to_hand_now(source.card_owner)
	var best := {}
	var mana_left := int(change.get("mana_left", bot_player.mana))
	var best_score := _follower_safety_gain(danger, change, mana_left) if not change.is_empty() else 0
	var projected := change.duplicate()
	var exposed_body_loss := 0
	if returns_to_hand:
		projected.erase("summon")
		projected.erase("stance")
		# Keeping Gugalanna is worth less if the opponent can immediately kill it.
		if danger >= 0:
			var zone := change.get("zone", source.current_zone) as Zone
			var defensive := bool(change.get("defensive", source.creature_mode == Card.CreatureMode.DEFENSIVE))
			exposed_body_loss = _estimate_projected_summon_casualty_cost(
				source, zone, defensive, removed, {}, false, mana_left
			)
			exposed_body_loss = mini(exposed_body_loss, _get_card_economic_value(source))
	for target: Card in targets:
		if target in removed or CardStrategy.removal_targets(self, source, target).is_empty():
			continue
		projected["removed"] = removed + [target, source] if returns_to_hand else removed + [target]
		var value := CardStrategy.value(self, target)
		if target.get_controller() == bot_player:
			value = -value
		var score := value + _follower_safety_gain(danger, projected, mana_left)
		if returns_to_hand and target.get_controller() == opponent:
			score += exposed_body_loss
		if score > best_score:
			best_score = score
			best = {"target": target, "value": value, "change": projected.duplicate(), "returns_to_hand": returns_to_hand}
	return best

func _reveal_removal_mana_value(source: Card, target: Card) -> int:
	if source is MasmassuPriest and CardStrategy.visible(self, target) \
			and (target.has_type("Demon") or target.has_type("Spirit")) and game_manager.can_player_gain_mana_now(bot_player):
		return CardStrategy.mana_gain_value(self, MasmassuPriest.DEMON_SPIRIT_MANA_GAIN)
	return 0

# A reveal-removal body (Dalkhu Break / Drown Below) whose trigger has no
# worthwhile target yet is a banked removal, not a dead trigger: the body can
# reveal later by attacking or by being attacked, and the controller picks
# that timing. Price the held option at a discounted card so hiding and
# holding competes with spending the body on an early poke. Callers must
# still max this against the spend-now value from _estimate_reveal_trigger_value;
# a target worth a full card makes holding worth exactly that card.
func _banked_reveal_removal_value(card: Card) -> int:
	if card == null or card.abilities_suppressed_by_effects() \
			or card.has_veil_of_night() \
			or not (card is MasmassuPriest or card is Grindylow):
		return 0
	@warning_ignore("integer_division")
	return ECON_CARD_VALUE * 3 / 4

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
		@warning_ignore("integer_division")
		return targets * ECON_CARD_VALUE / 3
	if card is PictishBeast:
		return CardStrategy.mana_gain_value(self, _pictish_beast_mana(card, []))
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
		# Mead scoring can forecast combat again with the same unrevealed board.
		if _scoring_byggvir_brewing:
			return 0
		_scoring_byggvir_brewing = true
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
		_scoring_byggvir_brewing = false
		return best_option_score
	return 0

func _estimate_retreat_economy(action: CardAction, fight: Dictionary, stats: Dictionary) -> Dictionary:
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
		if not _can_askelladen_retreat(card, other, stats):
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

func _estimate_raw_attack_economy(action: CardAction, stats: Dictionary, projected_defender_mode: int = -1) -> Dictionary:
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
	# Recoil and on-kill triggers charge the player who declared the attack.
	# Forecast actions state that side directly through source_player; the
	# controller fallback keeps submitted actions and older call sites on
	# their previous attribution. A temporarily controlled body (Siren's
	# Song) fights for its owner once the borrow returns, so a forecast of
	# that next-turn attack must not bill the bot for its recoil.
	var acting_player: Player = action.source_player if action.source_player != null else attacker.get_controller()
	# Aphrodite can only activate Violent Delights on her own turn, so the
	# risk of her follow-up Enslave counts only when HER attack is the one
	# making the bot-side creature die in combat.
	var her_attack := acting_player == opponent
	var projected_guards: Array = stats.get(PROJECTED_DESTRUCTION_GUARDS_KEY, [])
	var attacker_stats: Vector3i = stats.get(attacker, Vector3i.ZERO)
	var partner_stats: Vector3i = stats.get(partner, Vector3i.ZERO)
	var defender_stats: Vector3i = stats.get(defender, Vector3i.ZERO)
	var attacker_strength := _get_vision_adjusted_strength(attacker, attacker_stats.x, defender)
	var support_strength := _get_vision_adjusted_strength(partner, partner_stats.x, defender)
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
		if attacker_strength > defender.get_effective_resilience(defender_stats.y):
			_add_combat_casualty(result, attacker, defender, her_attack, projected_guards)
		return result
	if defender.card_type != Card.CardType.CREATURE:
		return result
	var defender_mode := int(defender.creature_mode) if projected_defender_mode < 0 else projected_defender_mode
	var attackers: Array[Card] = [attacker, partner]
	var opposing_cards: Array[Card] = [defender]
	if defender_mode == Card.CreatureMode.AGGRESSIVE:
		var defender_strength := _get_vision_adjusted_strength(defender, defender_stats.x, attacker)
		if attacker_strength > defender_strength:
			_add_combat_casualty(result, attacker, defender, her_attack, projected_guards)
			var defender_damage_strength := game_manager._get_giants_disdain_damage_stat(defender, attackers, defender_strength)
			_add_follower_loss_to_economy(result, defender.get_controller(), attacker_strength - defender_damage_strength, damage_source)
		elif defender_strength > attacker_strength:
			_add_combat_casualty(result, defender, attacker, her_attack, projected_guards)
			_add_combat_casualty(result, defender, partner, her_attack, projected_guards)
			var attacker_damage_strength := game_manager._get_giants_disdain_damage_stat(attacker, opposing_cards, attacker_strength - support_strength)
			attacker_damage_strength += game_manager._get_giants_disdain_damage_stat(partner, opposing_cards, support_strength)
			_add_follower_loss_to_economy(result, acting_player, defender_strength - attacker_damage_strength, defender)
		else:
			_add_combat_casualty(result, defender, attacker, her_attack, projected_guards)
			_add_combat_casualty(result, defender, partner, her_attack, projected_guards)
			_add_combat_casualty(result, attacker, defender, her_attack, projected_guards)
		return result

	var attack_strength_vs_defense := _get_vision_adjusted_strength_vs_defense(attacker, attacker_stats.x, defender)
	attack_strength_vs_defense += _get_vision_adjusted_strength_vs_defense(partner, partner_stats.x, defender)
	var defender_resilience := defender.get_effective_resilience(defender_stats.y)
	if attack_strength_vs_defense > defender_resilience:
		_add_combat_casualty(result, attacker, defender, her_attack, projected_guards)
	else:
		if attack_strength_vs_defense < defender_resilience:
			_add_follower_loss_to_economy(result, acting_player, defender_resilience - attack_strength_vs_defense)
			if defender.get_controller() != acting_player:
				result["defensive_conversion_defender"] = defender
		if game_manager._has_ferocious_defence(defender.get_controller()):
			_add_combat_casualty(result, defender, attacker, her_attack, projected_guards)
			_add_combat_casualty(result, defender, partner, her_attack, projected_guards)
	return result

func _add_combat_casualty(
	result: Dictionary,
	killer: Card,
	victim: Card,
	her_attack: bool = false,
	projected_guards: Array = []
) -> void:
	if victim == null or victim in projected_guards or CardStrategy.destruction_guard(victim) \
			or game_manager.is_warded_from_combat_destruction(victim, killer):
		return
	if not killer.can_destroy_combat_protected_creatures(victim):
		var replacement: Zone = victim.get_self_graveyard_replacement_zone(game_manager, true, true, false) if victim is BaseCard else null
		if replacement != null and replacement == victim.current_zone:
			return
	if killer.get_controller() == bot_player and victim.get_controller() == opponent \
			and victim.card_type == Card.CardType.CREATURE and not victim.is_petrified():
		result["enemy_creature_destroyed"] = true
		var slain_enemies: Array = result.get_or_add("offering_victims", [])
		if victim not in slain_enemies:
			slain_enemies.append(victim)
	if not CardStrategy.visible(self, victim):
		_add_destroyed_card_to_economy(result, victim)
		return
	var value := _get_card_economic_value(victim)
	if victim.is_token and not CardStrategy.expires_after_combat(victim):
		@warning_ignore("integer_division")
		value = maxi(0, value - ECON_CARD_VALUE / 2)
	elif not victim.is_token and victim.card_type == Card.CardType.CREATURE:
		# A lasting loss also wastes the mana and creatures invested in deploying it.
		@warning_ignore("integer_division")
		value += (maxi(0, victim.mana_cost) + 2 * victim.sacrifice_cost) * _mana_rate() / 2
	if victim is AgainWalker:
		var return_cost := _forecast_again_walker_return_cost(victim, killer)
		if return_cost > 0:
			var returning: Array = result.get_or_add("returning_casualties", [])
			returning.append(victim)
			var loses_frontline := victim.get_controller() == victim.card_owner \
					and victim.current_zone in victim.card_owner.frontline_zones
			@warning_ignore("integer_division")
			value = mini(value, return_cost * _mana_rate() + (_mana_rate() / 2 if loses_frontline else 0))
	if victim.get_controller() == opponent and victim.card_type == Card.CardType.CREATURE \
			and victim not in result.get("returning_casualties", []):
		value -= _opponent_freyja_reanimate_discount(victim)
	_add_destroyed_card_to_economy(result, victim, value)
	if victim.get_controller() == bot_player and killer.get_controller() == opponent \
			and her_attack and victim.card_type == Card.CardType.CREATURE:
		# Aphrodite can only activate Violent Delights on her own turn, so the
		# risk charges only for a combat kill her attack makes; when the BOT's
		# attack kills her, the unlock doesn't follow (her turn starts with
		# empty combat events). Charge part of the expected enslaved target.
		var enslave_risk := _opponent_aphrodite_enslavement_risk(victim)
		if enslave_risk > 0:
			result["enslavement_risk"] = int(result.get("enslavement_risk", 0)) + enslave_risk
		# Losing a frontline body can also hand Guan Yu's Tactical Break clock
		# the frontline lead it feeds on.
		var counter_risk := _opponent_guanyu_counter_risk(victim)
		if counter_risk > 0:
			result["guanyu_counter_risk"] = int(result.get("guanyu_counter_risk", 0)) + counter_risk
	if victim is CreatureCard and not victim.is_petrified() and not killer.abilities_suppressed() \
			and (killer.get_controller() == bot_player or killer is Aurboda) and not game_manager._should_class_rend(killer, victim):
		var replacement: Zone = victim.get_self_graveyard_replacement_zone(game_manager, true, true, false) if victim is BaseCard else null
		if replacement == null or replacement == victim.card_owner.graveyard_zone:
			if killer.get_controller() == bot_player:
				result["bot_slayer"] = killer
			if killer is Aurboda and killer.card_owner != null and CardStrategy.visible(self, killer):
				var owners: Array = result.get_or_add("pierce_owners", [])
				owners.append(killer.card_owner)
	if killer.get_controller() == bot_player and victim.get_controller() == opponent \
			and victim.card_type == Card.CardType.CREATURE and not victim.is_petrified():
		# A kill that evens the frontline count denies their next Tactical
		# Break counter for a full upkeep.
		var counter_break := _opponent_guanyu_counter_break_bonus(victim)
		if counter_break > 0:
			result["guanyu_counter_break"] = int(result.get("guanyu_counter_break", 0)) + counter_break

func _forecast_again_walker_return_cost(walker: AgainWalker, killer: Card) -> int:
	var owner := walker.card_owner
	if owner == null or walker.is_token or walker.is_enslaved() or walker.is_petrified():
		return 0
	var cost := AgainWalker.RESURRECTION_COST + game_manager.get_creature_summon_mana_cost(owner, walker, null, true)
	if owner.mana < cost or game_manager._should_class_rend(killer, walker):
		return 0
	for source in game_manager._get_graveyard_replacement_sources(walker):
		if source.get_controller() != owner and CardStrategy.visible(self, source):
			return 0
	# A Walker slain in reserve can use the slot it just vacated.
	for zone in owner.reserve_zones:
		if zone.cards.is_empty() or (zone == walker.current_zone and zone.cards.size() == 1):
			return cost
	return 0

func _find_opponent_god() -> GodCard:
	if opponent == null or opponent.god_zone == null or opponent.god_zone.cards.is_empty():
		return null
	return opponent.god_zone.cards[0] as GodCard

# Receiver of the Slain returns a slain Norse Warrior for one turn as a Spirit,
# so the kill still lands eventually. Charge only the borrowed turn: the body
# can block or attack once more before it is destroyed for good.
func _opponent_freyja_reanimate_discount(victim: Card) -> int:
	if victim == null or not victim.has_type("Warrior") or str(victim.culture).strip_edges() != "Norse":
		return 0
	var god := _find_opponent_god()
	if not (god is Freyja) or god.is_muted or not CardStrategy.visible(self, god):
		return 0
	if opponent.mana + 4 < god.get_activation_mana_cost(game_manager):
		return 0
	@warning_ignore("integer_division")
	return _get_card_economic_value(victim) / 3

# Killing one of our creatures in combat unlocks Violent Delights on Aphrodite's
# OWN turn (the guard's combat events clear every turn start). If her Aphrodite
# could pay and a target remains, the forecast should expect to lose part of
# that creature's value.
func _opponent_aphrodite_enslavement_risk(dying_victim: Card) -> int:
	if opponent == null or game_manager == null:
		return 0
	var god := _find_opponent_god()
	if not (god is AphroditeAreia) or god.is_muted or not CardStrategy.visible(self, god):
		return 0
	if opponent.mana + 4 < AphroditeAreia.ACTIVATION_COST:
		return 0
	var best := 0
	for creature in _get_board_creatures(bot_player):
		if creature == dying_victim or not CardStrategy.visible(self, creature) or creature.is_face_down:
			continue
		if not god.is_valid_activation_target(creature):
			continue
		if game_manager._is_protected_from_enslavement(creature):
			continue
		best = maxi(best, _get_card_economic_value(creature))
	if best <= 0:
		return 0
	# She still has to reach her turn, pay, and find the window open.
	@warning_ignore("integer_division")
	return best / 4

# Stack strength that kills a creature: aggressive targets die to STR > STR,
# defensive ones to STR > RES (e.g. a 7/3 body falls to an 8-strength attacker).
func _creature_kill_barrier(creature: Card) -> int:
	if creature == null:
		return 0
	if creature.creature_mode == Card.CreatureMode.DEFENSIVE:
		return creature.get_effective_resilience()
	return creature.get_effective_strength()

# Whether her visible stack can kill this creature next turn: a board attacker
# that can strike it, or a visible hand pull whose summon + attack tax fits the
# budget and clears the barrier.
func _visible_stack_can_kill(creature: Card, budget: int) -> bool:
	for attacker in _get_creature_attackers_next_turn(creature, []):
		if attacker != null and attacker.get_effective_strength() > _creature_kill_barrier(creature):
			return true
	for card in opponent.hand_zone.cards:
		if not CardStrategy.visible(self, card) or not (card is CreatureCard) \
				or (card is ActiveGodCard) or card.is_face_down:
			continue
		if game_manager.get_creature_summon_mana_cost(opponent, card) \
				+ game_manager.get_creature_action_mana_cost(card, "attack") > budget:
			continue
		if card.get_effective_strength() > _creature_kill_barrier(creature):
			return true
	return false

# Half-weight danger pulse for the incoming-forecast danger number: her combo
# needs a combat kill on one of my bodies plus 5 mana for Violent Delights;
# the freed creature is the real loss. (_forecast_incoming_follower_loss
# reports physical followers.)
func _aphrodite_exposure_pulse() -> int:
	var exposure := _opponent_aphrodite_enslave_exposure()
	if exposure <= 0:
		return 0
	@warning_ignore("integer_division")
	return int(exposure / 50)

# Whole-board exposure estimate for the user-facing scenario where the combo
# lives behind a creature in hand: her hand is invisible, so when no visible
# stack kills any of my bodies the budget-bounded worst case counts — the
# standard summon-strength bound may well still produce the killer.
func _opponent_aphrodite_enslave_exposure() -> int:
	if opponent == null or game_manager == null:
		return 0
	var aphrodite := _find_opponent_god() as AphroditeAreia
	if aphrodite == null or aphrodite.is_muted or not CardStrategy.visible(self, aphrodite):
		return 0
	if opponent.mana + 4 < AphroditeAreia.ACTIVATION_COST:
		return 0
	var budget := opponent.mana + game_manager.get_automatic_upkeep_mana_gain(opponent, game_manager.turn_number + 1) \
		+ game_manager.get_effective_upkeep_mana_gain(game_manager.get_base_upkeep_mana_gain(), opponent)
	if budget <= 0:
		return 0
	var exposure := 0
	for creature in _get_board_creatures(bot_player):
		if creature == null or creature.is_face_down or not CardStrategy.visible(self, creature):
			continue
		if not aphrodite.is_valid_activation_target(creature):
			continue
		if game_manager._is_protected_from_enslavement(creature):
			continue
		var barrier := _creature_kill_barrier(creature)
		if barrier <= 0:
			continue
		if _visible_stack_can_kill(creature, budget) \
				or budget * ECON_FORECAST_SUMMON_STR_PER_MANA > barrier:
			exposure = maxi(exposure, _opponent_aphrodite_enslavement_risk(creature))
	return exposure

# Tactical Break value of a single tactic counter: every TACTIC_COUNTER_COST
# counters destroy one board card, so one counter is a quarter of the best
# removal target the enemy god could name.
func _opponent_guanyu_counter_value() -> int:
	var god := _find_opponent_god()
	if not (god is GuanYu) or god.is_muted or not CardStrategy.visible(self, god):
		return 0
	var best := 0
	for creature in _get_board_creatures(bot_player):
		if CardStrategy.visible(self, creature) and not creature.is_face_down:
			best = maxi(best, _get_card_economic_value(creature))
	if best <= 0:
		return 0
	@warning_ignore("integer_division")
	return best / GuanYu.TACTIC_COUNTER_COST

func _guanyu_frontline_count(player: Player) -> int:
	if player == null:
		return 0
	var count := 0
	for zone in player.frontline_zones:
		for card in zone.cards:
			if card != null and card.card_type == Card.CardType.CREATURE:
				count += 1
	return count

# Killing an enemy creature can deny their next Tactical Break counter when
# the kill evens the frontline count: the clock stops for a full upkeep.
func _opponent_guanyu_counter_break_bonus(victim: Card) -> int:
	var counter_value := _opponent_guanyu_counter_value()
	if counter_value <= 0 or victim == null:
		return 0
	var their_count := _guanyu_frontline_count(opponent)
	if victim.current_zone != null and victim.current_zone.zone_type == Zone.ZoneType.FRONTLINE:
		their_count -= 1
	if their_count > _guanyu_frontline_count(bot_player):
		return 0
	@warning_ignore("integer_division")
	return counter_value / 2

# Losing one of our frontline creatures to combat can hand them the frontline
# lead that feeds the Tactical Break clock. Charge part of the next counter.
func _opponent_guanyu_counter_risk(dying_victim: Card) -> int:
	var counter_value := _opponent_guanyu_counter_value()
	if counter_value <= 0 or dying_victim == null \
			or dying_victim.current_zone == null \
			or dying_victim.current_zone.zone_type != Zone.ZoneType.FRONTLINE:
		return 0
	var our_count := _guanyu_frontline_count(bot_player) - 1
	if _guanyu_frontline_count(opponent) <= our_count:
		return 0
	@warning_ignore("integer_division")
	return counter_value / 3

# Deceptive Speed potential: their Hermes can still give this face-up
# creature +3 speed this turn (once per turn, 2 mana). Forecasts that
# compare speeds treat enemy bodies as potentially faster while the god is
# live, so intercept projections stop running on best-case assumptions.
func _opponent_hermes_speed_gain(creature: Card) -> int:
	if creature == null or opponent == null or game_manager == null:
		return 0
	if creature.get_controller() != opponent or not creature.is_creature_card() \
			or creature.is_face_down or creature.is_stealth:
		return 0
	var god := _find_opponent_god()
	if not (god is Hermes) or god.is_muted or not CardStrategy.visible(self, god):
		return 0
	if god._last_used_turn == game_manager.turn_number or opponent.mana < Hermes.ACTIVATION_COST:
		return 0
	for buff in creature.active_buffs:
		if buff.get("effect_type") == Hermes.BUFF_EFFECT_TYPE:
			return 0
	return Hermes.SPEED_BONUS

func _score_attack_economy(result: Dictionary, line: Dictionary = {}) -> int:
	var score := int(result.get("opponent_cards_lost", 0)) - int(result.get("bot_cards_lost", 0))
	score += int(result.get("hex_trade_credit", 0))
	score += int(result.get("scavenge_value", 0)) + int(result.get("deck_reward", 0))
	# Several attacks can qualify different creatures for the same charm.
	score += maxi(0, int(result.get("heroic_stand_reward", 0)) - int(line.get("heroic_stand_reward", 0)))
	score -= int(result.get("enslavement_risk", 0))
	score -= int(result.get("guanyu_counter_risk", 0))
	score += int(result.get("guanyu_counter_break", 0))
	score += int(result.get("reveal_bonus", 0))
	score += int(result.get("concealment_value", 0))
	# Mummu, Active God's Entropy replaces a plain graveyard death with a
	# prime draw-lock or a shelve denial, priced from the bot's perspective.
	score += int(result.get("mummu_entropy_value", 0))
	var bot_followers := int(line.get("bot_followers", bot_player.followers))
	var opponent_followers := int(line.get("opponent_followers", opponent.followers))
	var bot_loss := int(result.get("bot_followers_lost", 0)) - int(result.get("bot_followers_gained", 0))
	var opponent_loss := int(result.get("opponent_followers_lost", 0)) - int(result.get("opponent_followers_gained", 0))
	var bot_after := maxi(0, bot_followers - bot_loss)
	var opponent_after := maxi(0, opponent_followers - opponent_loss)
	var opponent_change := CardStrategy.follower_change_value(opponent_followers, opponent_after)
	if opponent_change < 0:
		opponent_change = roundi(opponent_change * _posture_damage_multiplier())
	score += CardStrategy.follower_change_value(bot_followers, bot_after) - opponent_change
	var casualties: Array = result.get("casualties", [])
	if not casualties.is_empty():
		score += _combat_god_death_cost(opponent, casualties, opponent_loss, false, opponent_followers)
		score -= _combat_god_death_cost(bot_player, casualties, bot_loss, false, bot_followers)
	# A lasting kill can prevent the creature's next attack even if stronger enemies remain.
	var returning: Array = result.get("returning_casualties", [])
	for casualty: Card in casualties:
		if casualty not in returning and casualty.get_controller() == opponent \
				and CardStrategy.visible(self, casualty) and casualty.current_zone != null \
				and casualty.current_zone.zone_type == Zone.ZoneType.FRONTLINE \
				and casualty.card_type == Card.CardType.CREATURE \
				and casualty.creature_mode == Card.CreatureMode.AGGRESSIVE \
				and not casualty.has_status_effect("cannot_attack") \
				and not game_manager.is_followers_attack_blocked_by_active_structure(casualty, bot_player):
			score += mini(_get_direct_follower_damage(casualty), bot_after) * CardStrategy.FOLLOWER_VALUE
	if bool(result.get("bot_wins", false)):
		score += ECON_CARD_VALUE * 20
	if bool(result.get("opponent_wins", false)):
		score -= ECON_CARD_VALUE * 20
	if not _posture_evaluating:
		var posture := str(_strategy_posture().get("posture", "balanced"))
		if posture == "locked_behind" and int(result.get("opponent_cards_lost", 0)) > 0:
			# The fatigue clock favors the opponent, so removing enemy bodies
			# to break the lock is progress even at card parity.
			@warning_ignore("integer_division")
			score += ECON_CARD_VALUE / 2
		elif posture == "locked_ahead" and int(result.get("bot_cards_lost", 0)) > 0:
			# Ahead on the locked clock: protect the board and let fatigue win.
			@warning_ignore("integer_division")
			score -= ECON_CARD_VALUE / 2
	return score

# The current marginal per-mana rate. Card plays should prefer
# CardStrategy.mana_penalty (it integrates across the spent range); action
# taxes of one or two mana can price at this single rate.
func _mana_rate() -> int:
	return CardStrategy.marginal_mana_value(self)

# Strategic posture for this turn (race/defend/locked clocks). Cached per
# turn; the evaluation itself runs scoring passes, so nested reads during
# evaluation or the board lock forecast get neutral weights.
func _strategy_posture() -> Dictionary:
	if game_manager == null or bot_player == null or opponent == null:
		return StrategyPosture.neutral()
	if _posture_evaluating or _locked_board_evaluating:
		return StrategyPosture.neutral()
	if int(_posture_cache["turn"]) == game_manager.turn_number and not (_posture_cache["value"] as Dictionary).is_empty():
		return _posture_cache["value"]
	_posture_evaluating = true
	var posture := StrategyPosture.evaluate(self)
	_posture_evaluating = false
	_posture_cache = {"turn": game_manager.turn_number, "value": posture}
	return posture

func _posture_damage_multiplier() -> float:
	if _posture_evaluating:
		return 1.0
	return float(_strategy_posture().get("damage_multiplier", 1.0))

func _posture_safety_multiplier() -> float:
	if _posture_evaluating:
		return 1.0
	return float(_strategy_posture().get("safety_multiplier", 1.0))

# Locked board state: neither side can push follower damage through. Ancient
# Pyre's conversion then becomes the primary win condition, so surplus mana
# should be pumped into it instead of idling (convert bypasses Guard).
var _locked_board_cache := {"turn": -1, "value": false}
var _mana_econ_cache := {}
# Held Altar of Dreams line snapshot, recomputed per decision step: its
# inputs (powers, hand, board, stock) only move between steps. Mirrors the
# mana econ cache's clear points.
var _altar_line_cache := {}

func _locked_board_state() -> bool:
	if game_manager == null:
		return false
	if int(_locked_board_cache["turn"]) != game_manager.turn_number:
		# Projecting attacks reads posture, which itself depends on the board lock.
		_locked_board_evaluating = true
		var locked := _compute_locked_board_state()
		_locked_board_evaluating = false
		_locked_board_cache = {"turn": game_manager.turn_number, "value": locked}
	return bool(_locked_board_cache["value"])

func _compute_locked_board_state() -> bool:
	var own_push := 0
	for candidate in _get_combat_candidates():
		var outcome := _project_attack(candidate)
		if outcome.is_empty():
			continue
		own_push = maxi(own_push, int(outcome.get("opponent_followers_lost", 0)))
	if own_push > 0:
		return false
	if _forecast_incoming_follower_loss() > 0:
		return false
	return true

# Expected hand value of the upkeep draw, from the bot's actual remaining
# deck: the primed card when known, otherwise the average over the deck.
func _expected_deck_draw_value(mana: int) -> int:
	var deck := bot_player.deck_zone.cards
	if deck.is_empty():
		return 0
	var primed := bot_player.deck_zone.get_primed_top_card()
	if primed != null:
		return _deck_card_hand_value(primed, mana)
	var total := 0
	for card in deck:
		total += _deck_card_hand_value(card, mana)
	@warning_ignore("integer_division")
	return total / deck.size()

# Expected answer-hunting value of the upkeep draw. A card drawn at upkeep is
# playable this turn, so the deck's remaining spells and charms are priced on
# their real lines against the current board (Inferno, Fall of the Mighty,
# Divine Lightning when its targets are actually there) and averaged over the
# whole deck: one live answer among forty cards barely moves the draw option,
# a deck full of them makes digging real. Creatures are excluded — their
# summon lines are separate tempo, and the clean-kill flag inside
# _deck_card_tactical_gain is a relative-pick heuristic rather than an
# absolute value. Preparation rules, affordability, and open reserve zones
# are already enforced inside _deck_card_tactical_gain, so answers that could
# not actually be played this turn price as zero.
func _expected_deck_dig_gain(mana: int, danger: int) -> int:
	var deck := bot_player.deck_zone.cards
	if deck.is_empty():
		return 0
	var primed := bot_player.deck_zone.get_primed_top_card()
	if primed != null:
		if primed is SpellCard or primed is CharmCard:
			return _deck_card_tactical_gain(primed, mana, danger)
		return 0
	var total := 0
	var best := 0
	var answers := 0
	for card in deck:
		if card is SpellCard or card is CharmCard:
			var gain := _deck_card_tactical_gain(card, mana, danger)
			total += gain
			best = maxi(best, gain)
			answers += 1
	if answers == 0:
		return 0
	@warning_ignore("integer_division")
	var expectation := total / deck.size()
	# Play to the outs: when the normal lines are losing — the opponent's kill
	# clock is faster, or a locked board outlives the bot on fatigue — the
	# drawn answer is not average value, it is the one line that flips the
	# game. Weight its hit chance by how far behind the bot is instead of
	# letting deck-size dilution bury it. Ahead or even, no tail: expectation
	# only.
	var posture := _strategy_posture()
	var out_weight := 0.0
	if str(posture.get("posture", "balanced")) == "locked_behind":
		out_weight = 2.0
	else:
		var clock_deficit := int(posture.get("bot_clock", StrategyPosture.NO_CLOCK)) \
			- int(posture.get("opponent_clock", StrategyPosture.NO_CLOCK))
		if clock_deficit > 0:
			out_weight = 1.0 + minf(4.0, float(clock_deficit))
	if out_weight <= 0.0:
		return expectation
	var tail := float(best) * (float(answers) / float(deck.size())) * out_weight
	return maxi(expectation, int(tail))

func _add_destroyed_card_to_economy(result: Dictionary, card: Card, value_override: int = -1) -> void:
	if card == null:
		return
	if result.has("casualties"):
		result["casualties"].append(card)
	var value := value_override
	if value < 0:
		value = _get_card_economic_value(card) if CardStrategy.visible(self, card) else ECON_CARD_VALUE
	var loss_owner := _get_card_loss_owner(card)
	if loss_owner == bot_player:
		result["bot_cards_lost"] = int(result.get("bot_cards_lost", 0)) + value
	elif loss_owner == opponent:
		result["opponent_cards_lost"] = int(result.get("opponent_cards_lost", 0)) + value

# The player that really loses when this card leaves play. Control effects
# (Siren's Song steals, enslavement) move the body between boards, but
# destruction still empties the owner's board for good, so a temporarily
# borrowed creature dying is the owner's loss, never the borrower's.
func _get_card_loss_owner(card: Card) -> Player:
	if card == null:
		return null
	if card.get_controller() != card.card_owner:
		return card.card_owner
	return card.get_controller()

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

func _get_vision_adjusted_strength(card: Card, str_delta: int, opposing_card: Card = null) -> int:
	var strength := _get_combat_strength(card, opposing_card, str_delta)
	if card is SulakTheUnclean and card.will_reveal_in_combat() and CardStrategy.visible(self, card) and not card.abilities_suppressed_by_effects():
		strength += card.strength
	return strength

func _get_vision_adjusted_strength_vs_defense(card: Card, str_delta: int, opposing_card: Card = null) -> int:
	var strength := _get_attack_strength_against_defense(card, opposing_card, str_delta)
	if card is SulakTheUnclean and card.will_reveal_in_combat() and CardStrategy.visible(self, card) and not card.abilities_suppressed_by_effects():
		strength += card.strength
	return maxi(0, strength)

func _get_card_economic_value(card: Card) -> int:
	if card == null:
		return 0
	if card is WardingStone and card.get_attack_restriction_turns_remaining(game_manager) <= 0:
		return _get_inactive_warding_stone_value(card)
	var score := ECON_CARD_VALUE + maxi(0, int(float(_score_projected_card(card)) / 2.0))
	if CardStrategy.expires_after_combat(card):
		# A projected token's cast pays for the attack; a live token still has one combat of board value.
		return roundi(score * 0.55) if card.current_zone != null else 0
	if card.card_type == Card.CardType.CREATURE and card.current_zone != null and card.current_zone.is_board_zone():
		var full_value := CardStrategy.value(self, card)
		if full_value > 0:
			var discount := CardStrategy._debilitation_discount(self, card)
			score = int(score * (1.0 - clampf(float(discount) / float(full_value), 0.0, 0.85)))
	# The Tree of Life engine premium applies on board: protect it in removal
	# responses, keep it out of sacrifice payments, and charge its loss more.
	score += CardStrategy.kur_jara_engine_premium(card)
	score += CardStrategy.clanking_chains_gain(self, card)
	return score

func _get_inactive_warding_stone_value(stone: WardingStone) -> int:
	var controller := stone.get_controller()
	if controller != null and stone.current_zone != null and stone.current_zone.is_board_zone() \
			and not stone.is_face_down and game_manager.can_player_use_powers(controller):
		for god in controller.god_zone.cards:
			if god is Odin and not god.is_muted and god.is_valid_runic_knowledge_offering(stone):
				# Destroying a stone leaves its offering in the graveyard.
				@warning_ignore("integer_division")
				return ECON_CARD_VALUE / 2
	@warning_ignore("integer_division")
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

func _score_follower_loss(player: Player, amount: int, starting_followers: int = -1) -> int:
	if player == null or not player.followers_enabled or amount <= 0:
		return 0
	var followers := player.followers if starting_followers < 0 else starting_followers
	if followers <= 0:
		return 0
	if amount >= followers:
		return ECON_CARD_VALUE * 20
	var score := -CardStrategy.follower_change_value(followers, followers - amount)
	if player == opponent:
		# A racing bot values each point of opponent follower damage above its
		# neutral rate: the clock, not the card economy, wins the game.
		score = int(round(float(score) * _posture_damage_multiplier()))
	return score

func _get_attack_defender_card(action: CardAction) -> Card:
	if action == null:
		return null
	if action.interceptor != null:
		return action.interceptor
	return action.target if action.target is Card else null

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
	var local_index := maxi(0, zone.cards.find(card)) if zone.zone_type != Zone.ZoneType.DECK else 0
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

func _get_play_cost(card: Card, prepared: bool, summon_source: Fenrir = null) -> int:
	if summon_source != null:
		return game_manager.get_creature_summon_mana_cost(bot_player, card, summon_source)
	return game_manager.get_card_play_mana_cost(bot_player, card, prepared)

func _can_afford_hand_card(card: Card, prepared: bool) -> bool:
	var mana_cost := _get_play_cost(card, prepared)
	return card != null and card.can_pay_costs_with_mana_cost(bot_player, mana_cost)

func _score_creature_play(card: Card, zone: Zone, available_mana: int) -> int:
	if card == null or bot_player == null or card.current_zone != bot_player.hand_zone:
		return -1000000
	return _score_creature_play_in_zone(card, zone, available_mana)

func _score_creature_play_in_zone(
	card: Card,
	zone: Zone,
	available_mana: int,
	include_devour: bool = true,
	summon_source: Fenrir = null,
	removed: Array = []
) -> int:
	if card.card_type != Card.CardType.CREATURE or zone == null:
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
	var mana_cost := _get_play_cost(card, false, summon_source)
	var payment_plan := _build_creature_summon_payment_plan(card, available_mana, {}, summon_source)
	if not bool(payment_plan.get("ok", false)):
		return -1000000
	var score := _score_projected_card(card)
	if include_devour and card is Fenrir and game_manager._should_trigger_summon_impact(card, card.current_zone, summon_source):
		var devour := _forecast_fenrir_devour(card, -1, {"removed": _summon_payment_cards(payment_plan)})
		if devour.is_empty():
			return -1000000
		score += int(devour["value"])
	@warning_ignore("integer_division")
	score -= mana_cost * 120 * _mana_rate() / 1000
	score -= int(payment_plan.get("penalty", 0))
	# A summon that dips the stock below the held Altar line's funding strands
	# its removal window until later upkeep income rebuilds the dip, so the
	# strand share prices the optionality the body spends away. The line's own
	# summon — a Demon or Spirit coster the Altar pays for, or one held for
	# exactly that Void window whose direct payment already carries the burn
	# charge — never pays for holding itself open.
	if payment_plan.get("altar_void_uids", []).is_empty() \
			and not (CardStrategy._is_demon_or_spirit_coster(card) and CardStrategy.find_altar_of_dreams(self) != null):
		score += CardStrategy.altar_line_hold_charge(self, available_mana, mana_cost)
	score += _estimate_tonal_extraction_setup_bonus(card)
	score += _summon_trigger_setup_bonus(card, zone)
	score += CardStrategy.clanking_chains_gain(self, card, removed)
	if zone in bot_player.frontline_zones and _opponent_has_known_board_wipe(card, zone):
		score -= _get_card_economic_value(card)
	if card is Askelladen and _get_askelladen_problem_creature() != null:
		score += 1600
	if card is HariiFransiscan:
		score += 500
	if card is HariiJarl:
		score += _estimate_harii_jarl_warband_value(card as HariiJarl)
	if card is Beyla:
		@warning_ignore("integer_division")
		score += CardStrategy.wake_gain(self, card, true) / 2
	if card is RedCap:
		if game_manager.turn_number <= 1 or game_manager.has_resolved_attack_this_turn or zone not in bot_player.frontline_zones or game_manager.attack_restrictions.has(bot_player):
			return -1000000
		for field_card in game_manager.get_field_cards():
			if field_card is HeavySnow and not field_card.is_face_down and not field_card.abilities_suppressed():
				return -1000000
	return score

# Deployment-time credit for creature triggers the engine resolves but the
# generic body score never sees. Each entry prices what playing the card
# profitably actually earns so these bodies compete with stronger vanilla
# stats exactly when their triggers are live.
func _summon_trigger_setup_bonus(card: Card, zone: Zone) -> int:
	if card == null or zone == null or card.abilities_suppressed_by_effects():
		return 0
	var bonus := 0
	if card.has_type("Divine Manifestation"):
		# A Divine Manifestation on either side wakes every sleeper the Duat
		# put down on both boards and keeps the structure from sleeping anyone
		# new while it lives. The wake adjustment prices that trade against
		# both boards, so the bot frees a locked enemy board only when its own
		# sleepers and the body are worth more.
		bonus += CardStrategy.divine_manifestation_wake_adjustment(self, card)
	if card is SixthSageAnEnlilda:
		# Conjure Home voids this body to Acquire an Ancient Dwelling, so the
		# summon doubles as a tutor whenever the best Dwelling the deck still
		# holds beats the body it costs — the same trade the impact's decline
		# check prices when the prompt arrives.
		var sage_danger := _forecast_incoming_follower_loss()
		var best_dwelling := 0
		for target: Card in card.get_valid_targets(game_manager):
			best_dwelling = maxi(best_dwelling, _deck_pick_value(target, bot_player.mana, sage_danger, [card]))
		var body_loss := _get_card_economic_value(card)
		if best_dwelling > body_loss:
			bonus += mini(best_dwelling - body_loss, ECON_CARD_VALUE)
	if card is Pazuzu:
		# Locust Swarm drains 2 mana on entry and Locust Plague repeats the
		# drain at every own upkeep while the body survives.
		bonus += 900
		if zone in bot_player.frontline_zones and opponent != null and opponent.mana >= 4:
			bonus += 700
	if card is Rabisu:
		# Life Drain (Impact) leeches 3 Str/Res from every sleeping creature on
		# both boards — enemy sleepers are weakened, own sleepers are leeched
		# too — and grants Rabisu +3/+3 per drained body. Price the real swing:
		# victim losses use the body-value curves at the drained statline, and
		# Rabisu's permanent gain is credited on its own statline, so draining
		# tiny sleepers or weakening own sleepers no longer counts as free value.
		var drained_count := 0
		var victim_swing := 0
		for board_player in [opponent, bot_player]:
			if board_player == null:
				continue
			for sleeper in _get_board_creatures(board_player):
				if not CardStrategy.visible(self, sleeper) or not sleeper.is_sleeping:
					continue
				if game_manager.is_immune_to_source(sleeper, card):
					continue
				var str_loss := mini(Rabisu.DRAIN_PER_SLEEPING_CREATURE, sleeper.get_effective_strength())
				var res_loss := mini(Rabisu.DRAIN_PER_SLEEPING_CREATURE, sleeper.get_effective_resilience())
				if str_loss <= 0 and res_loss <= 0:
					continue
				drained_count += 1
				var loss: int = CardStrategy._strength_reach_points(sleeper.get_effective_strength() - str_loss) \
					- CardStrategy._strength_reach_points(sleeper.get_effective_strength()) \
					+ CardStrategy._resilience_survival_points(sleeper.get_effective_resilience() - res_loss) \
					- CardStrategy._resilience_survival_points(sleeper.get_effective_resilience())
				victim_swing += -loss if board_player == opponent else loss
		if drained_count > 0:
			var rabisu_gain: int = CardStrategy._strength_reach_points(card.get_effective_strength() + Rabisu.DRAIN_PER_SLEEPING_CREATURE * drained_count) \
				- CardStrategy._strength_reach_points(card.get_effective_strength()) \
				+ CardStrategy._resilience_survival_points(card.get_effective_resilience() + Rabisu.DRAIN_PER_SLEEPING_CREATURE * drained_count) \
				- CardStrategy._resilience_survival_points(card.get_effective_resilience())
			bonus += maxi(0, victim_swing + rabisu_gain)
	if card is Caleuche:
		var spirits := 0
		for ally in _get_board_creatures(bot_player):
			if ally != card and CardStrategy.visible(self, ally) and ally.has_type("Spirit"):
				spirits += 1
		bonus += mini(spirits, 4) * 1300
	if card is GidimEnsi and zone in bot_player.frontline_zones:
		# Its Guardian trigger sleeps anything that attacks the bot's followers,
		# so the wall also deters the incoming push.
		var gidim_danger := _forecast_incoming_follower_loss()
		if gidim_danger > 0:
			@warning_ignore("integer_division")
			bonus += gidim_danger / 3
	if card is HabrokParagonOfHawks:
		# Breakout only needs this to be the lone body at the opponent's turn
		# end; the recursion (bounce plus removal) starts from an empty board.
		if _board_creature_count(bot_player) == 0:
			bonus += 1500
	if card is WolfCub or card is WolfAdolescent:
		bonus += _wolf_maturation_setup_bonus(card)
	if card is Isimud:
		# Forerunner discounts Divine Manifestation summons by 6 while this
		# body is on the field, and Revelation can deploy one directly. With
		# the Walk + E2-abzu tutor live, a Mer Mage manifestation still in
		# the deck (Enki is the flagship) is one combo from Revelation.
		var revelation_payoff := 0
		for hand_card in bot_player.hand_zone.cards:
			if hand_card != card and hand_card.has_type("Divine Manifestation"):
				revelation_payoff += 1800
				break
		if revelation_payoff == 0:
			for deck_card in bot_player.deck_zone.get_unordered_deck_cards():
				if deck_card == card or not deck_card.has_type("Divine Manifestation"):
					continue
				var continuation := CardStrategy.isimud_revelation_continuation(self, deck_card)
				if continuation > 0:
					revelation_payoff += continuation
					break
		bonus += revelation_payoff
	if card is EnHeduAnna:
		if _en_hedu_anna_exaltation_setup_available():
			bonus += 1200
	return bonus

func _wolf_maturation_setup_bonus(card: Card) -> int:
	# Maturation upgrades the wolf into an in-deck Lupine at upkeep; credit
	# half the best upgrade margin while the option stays live.
	var level_cap := 4 if card is WolfCub else 5
	var best := 0
	for deck_card in bot_player.deck_zone.get_unordered_deck_cards():
		if deck_card == card or not deck_card.has_type("Lupine") or deck_card.get_effective_level() > level_cap:
			continue
		best = maxi(best, _score_projected_card(deck_card))
	if best <= 0:
		return 0
	@warning_ignore("integer_division")
	return mini(2000, maxi(0, best - _score_projected_card(card)) / 2)

func _en_hedu_anna_exaltation_setup_available() -> bool:
	# Exaltation needs the god's own power to activate this turn while she is
	# face-up on the field, so she pairs with an affordable god ability.
	var god := _find_player_god()
	if god == null or not god.has_method("can_activate") or not god.can_activate(game_manager):
		return false
	if god.has_method("get_activation_mana_cost") and god.get_activation_mana_cost(game_manager) > bot_player.mana:
		return false
	return true

func _forecast_fenrir_devour(fenrir: Fenrir, danger: int, change: Dictionary, offered_uids: Array = []) -> Dictionary:
	if fenrir.abilities_suppressed_by_effects():
		return {}
	if (fenrir.current_zone == null or not fenrir.current_zone.is_board_zone()) \
			and CardStrategy.summon_impact_silenced_by_storm(self, fenrir, change.get("removed", [])):
		# Devour is an impact payoff: a live Storm silences it the moment the
		# creature enters the field, so the sacrifice cost would buy a body
		# without the planned value. Skip the whole plan until the Storm is
		# gone instead of paying two creatures for a dead trigger.
		return {}
	var removed: Array = change.get("removed", [])
	var best := {}
	var best_score := 0
	for target in fenrir.get_valid_devour_targets(game_manager):
		var visible := CardStrategy.visible(self, target)
		if target in removed or (offered_uids.is_empty() and not visible) \
				or (not offered_uids.is_empty() and target.uid not in offered_uids):
			continue
		var own := target.get_controller() == bot_player
		if visible and (game_manager.is_immune_to_source(target, fenrir) \
				or game_manager.is_guardian_protected(target, fenrir) \
				or CardStrategy.destruction_guard(target) \
				or (not own and game_manager.has_turn_destruction_ward(target.get_controller()))):
			continue
		var gain := Vector3i.ZERO
		# Trollskap can remove the target from combat without awarding Devour stats.
		var returns_to_hand := visible and target is DraugRevenant and not target.abilities_suppressed() \
			and not game_manager._is_watchbeast_active()
		if visible and not returns_to_hand:
			gain = Vector3i(target.get_effective_strength(), target.get_effective_resilience(), 0)
		var value := CardStrategy.value(self, target)
		if own:
			value = -value
		value += gain.x * 30 + gain.y * 15
		var projected := change.duplicate()
		projected["removed"] = removed + [target]
		projected["combat_stats"] = {fenrir: gain}
		var safety := _follower_safety_gain(danger, projected, int(change.get("mana_left", bot_player.mana)))
		if value + safety > best_score:
			best_score = value + safety
			best = {"target": target, "removed": projected["removed"], "combat_stats": projected["combat_stats"], "value": value, "safety": safety}
	return best

func _summon_payment_cards(payment: Dictionary) -> Array[Card]:
	var cards: Array[Card] = []
	for uid in payment.get("sacrifice_uids", []) + payment.get("altar_void_uids", []):
		cards.append(game_manager.get_card_by_uid(uid))
	return cards

func _opponent_has_known_board_wipe(projected_card: Card = null, projected_zone: Zone = null) -> bool:
	if opponent == null or opponent.hand_zone == null:
		return false
	for zone in opponent.frontline_zones + opponent.reserve_zones:
		for card in zone.cards:
			if not CardStrategy.visible(self, card) or not card.is_prepared or CardStrategy.key(card) not in [
				"FiresOfJudgment", "Earthquake", "Famine",
				"OccultSingularity", "FalloftheMighty", "BaneOfTheSvartalfar",
			]:
				continue
			if opponent.mana >= game_manager.get_prepared_card_activation_mana_cost(opponent, card):
				for target in CardStrategy.wipe_cards(self, card):
					if target.get_controller() == bot_player and not game_manager.is_immune_to_source(target, card):
						return true
				if _known_wipe_hits_projected_card(card, projected_card, projected_zone):
					return true
	for card in opponent.hand_zone.cards:
		if not CardStrategy.visible(self, card) or CardStrategy.key(card) not in [
			"FiresOfJudgment", "Earthquake", "Famine", "OccultSingularity",
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
	return false

func _build_creature_summon_payment_plan(card: Card, available_mana: int = -1, forecast: Dictionary = {}, summon_source: Fenrir = null) -> Dictionary:
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
	var mana_cost := _get_play_cost(card, false, summon_source)
	var available := bot_player.mana if available_mana < 0 else available_mana
	if available < mana_cost:
		return result
	# Mana was checked against the forecast above. Validate the other costs against the current state.
	var validation_mana_cost := mini(mana_cost, bot_player.mana)
	if card.sacrifice_cost <= 0:
		if _validate_creature_summon_payment_plan(card, validation_mana_cost, [], []):
			result["ok"] = true
		return result

	var payment_forecast := forecast
	if not forecast.is_empty():
		payment_forecast = forecast.merged({"mana_left": available - mana_cost}, true)
	var direct_plan := _choose_direct_summon_sacrifice_plan(card.sacrifice_cost, payment_forecast)
	var altar_plan := _choose_altar_of_dreams_plan(card, payment_forecast) if summon_source == null else {}
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
	# A Demon or Spirit coster paid with the bot's own bodies burns the Void
	# window this summon could have used: while the bot's sleep source can
	# still turn an enemy creature into the same payment, the direct plan
	# carries the line's continuation so waiting for that removal can win.
	# An altar plan that already lost the selection has priced its own Void.
	if not sacrifice_cards.is_empty() and altar_plan.is_empty():
		result["penalty"] += CardStrategy.held_altar_void_burn_charge(self, card)
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

# A projected body the effect itself destroys at this turn's end (Tablet of
# Life's level 3+ resurrection) has no future to forfeit: converting it into a
# summon's sacrifice payment costs only its residual per-turn use, the same
# share the debilitation model leaves a doomed body standing on the board.
const DOOMED_EFFECT_BODY_PAYMENT_SHARE := 0.15
# A stranded followup line worth at least this much blocks the cast that would
# burn it: the plan tail will happily submit a merely downscored play, so a
# meaningful line has to remove the cast from consideration entirely.
const BURNED_EFFECT_LINE_GATE := 1000

func _score_effect_summon_sacrifice_followup(summoned: Array, setup_mana: int, removed: Array = [], doomed_bodies: Array = [], occupied_zone: Zone = null) -> int:
	# Value the extra normal summon made possible by creatures an effect puts on
	# the board. The actual action is chosen again after the effect resolves.
	# `doomed_bodies` marks projected bodies the effect destroys at this turn's
	# end: they can only pay for a summon in the turn the effect resolves, so a
	# cast after that turn's summon is already spent strands the hand creature
	# the body would have fed, and the cast is charged the burned line.
	if summoned.is_empty() or bot_player == null or game_manager == null \
			or game_manager.current_player != bot_player:
		return 0
	var produced: Array[Card] = []
	for entry in summoned:
		var body := entry as Card
		if body != null and body.card_type == Card.CardType.CREATURE and not body.is_god \
				and not body is ActiveGodCard and body.can_be_used_for_creature_sacrifice:
			produced.append(body)
	if produced.is_empty():
		return 0
	var existing: Array[Card] = []
	for candidate in _get_valid_summon_sacrifice_candidates():
		if candidate not in removed:
			existing.append(candidate)
	var projected := existing + produced
	var mana_left := bot_player.mana - setup_mana
	var best_gain := 0
	var burned_line_gain := 0
	for creature in bot_player.hand_zone.cards:
		if creature in produced or creature.card_type != Card.CardType.CREATURE or creature.sacrifice_cost <= 0 \
				or creature.discard_cost > 0 or creature.banish_cost > 0 or creature.shelve_cost > 0 \
				or creature is ActiveGodCard or _get_play_cost(creature, false) > mana_left:
			continue
		if projected.size() < creature.sacrifice_cost:
			continue
		var payment := _choose_lowest_scored_cards(projected, creature.sacrifice_cost, "sacrifice")
		if payment.size() != creature.sacrifice_cost or not payment.any(func(body: Card) -> bool: return body in produced):
			continue
		var zone := _get_first_open_summon_zone(bot_player, occupied_zone)
		if zone == null:
			continue
		var payment_penalty := 0
		for body in payment:
			payment_penalty += _effect_body_sacrifice_penalty(body, doomed_bodies)
		@warning_ignore("integer_division")
		var followup_value := _score_projected_card(creature) - payment_penalty \
			- _get_play_cost(creature, false) * 120 * _mana_rate() / 1000
		var standalone_value := 0
		if existing.size() >= creature.sacrifice_cost:
			var current_payment := _choose_lowest_scored_cards(existing, creature.sacrifice_cost, "sacrifice")
			@warning_ignore("integer_division")
			standalone_value = _score_projected_card(creature) - _get_play_cost(creature, false) * 120 * _mana_rate() / 1000
			for body in current_payment:
				standalone_value -= _score_summon_sacrifice_candidate(body)
		# The first effect already earns its own body value. Only credit the
		# improvement from converting that body into the followup creature.
		var produced_value := 0
		for body in payment:
			if body in produced:
				produced_value += _effect_body_sacrifice_penalty(body, doomed_bodies)
		var line_gain := followup_value - maxi(standalone_value, produced_value)
		var uses_doomed_body := payment.any(func(body: Card) -> bool: return body in doomed_bodies)
		if existing.size() < creature.sacrifice_cost and uses_doomed_body:
			# The temporary body has no lasting value of its own. If it unlocks
			# a summon, credit the card that can actually stay on the board.
			line_gain += ECON_CARD_VALUE
		if bot_player.has_summoned_this_turn and not game_manager._can_use_extra_normal_summon(bot_player, creature, zone):
			# The turn's normal summon is spent, so the projected body cannot
			# pay for this creature this turn. A body that survives the turn
			# only delays the line, but a doomed body makes this cast burn the
			# effect that was the creature's only fresh payment generator:
			# hold the spell for a turn whose summon window is still open.
			if uses_doomed_body:
				burned_line_gain = maxi(burned_line_gain, line_gain)
			continue
		best_gain = maxi(best_gain, line_gain)
	if burned_line_gain > 0:
		if burned_line_gain >= BURNED_EFFECT_LINE_GATE:
			return CardStrategy.BAD
		return maxi(0, best_gain) - burned_line_gain
	return maxi(0, best_gain)

func _effect_body_sacrifice_penalty(body: Card, doomed_bodies: Array) -> int:
	var penalty := _score_summon_sacrifice_candidate(body)
	if body in doomed_bodies:
		penalty = int(float(penalty) * DOOMED_EFFECT_BODY_PAYMENT_SHARE)
	return penalty

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
	return _follower_safety_gain(int(forecast["danger"]), projected, int(forecast["mana_left"]))

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
	if card.creature_mode == Card.CreatureMode.DEFENSIVE:
		score += 250
	if not card.can_take_major_creature_action():
		score -= 300
	if card.current_zone != null and card.current_zone.zone_type == Zone.ZoneType.RESERVE:
		score -= 150
	if card is Askelladen:
		score += 2500
	if card is EnkiLordOfEridu:
		score += 2200
	if card is Capricorn:
		# Sacrificing Capricorn refunds 2 mana and returns it to hand, so it
		# is the premium sacrifice payment rather than a body to protect.
		score -= 2400
	if card.has_type("Guardian"):
		score += 500
	# A live attacker's follower damage is forfeited when it becomes sacrifice
	# payment, so the body costs more than its printed stats. This keeps the bot
	# from trading a productive board threat for a marginal summon.
	if opponent != null and game_manager != null \
			and card.current_zone != null and card.current_zone.zone_type == Zone.ZoneType.FRONTLINE \
			and card.creature_mode == Card.CreatureMode.AGGRESSIVE \
			and card.can_take_major_creature_action():
		@warning_ignore("integer_division")
		score += _score_follower_loss(opponent, card.get_effective_strength()) / 2
	# A premium body's engine value survives only while the body does, so a
	# summon paid with it forfeits that premium on top of the stats: charge
	# the named engine premium (Tree of Life's cycle). The charge must not
	# reach for the generic removal-econ base — _get_card_economic_value
	# floors at a full card (5000) for essentially every real creature, and
	# charging that base priced every sacrifice summon out of the bot's
	# plans, Necoc Yaotl's stored sacrifices included. Self-replacement
	# passives are already priced by the graveyard-replacement block above,
	# and combat-only protection (Stone Skin) never stopped a voluntary
	# sacrifice anyway.
	if card.current_zone != null and card.current_zone.is_board_zone():
		score += CardStrategy.kur_jara_engine_premium(card) + CardStrategy.clanking_chains_gain(self, card)
	if opponent != null and game_manager != null and card is BaseCard \
			and card.current_zone != null and card.current_zone.is_board_zone() \
			and not card.abilities_suppressed() \
			and card.get_self_graveyard_replacement_zone(game_manager, true, true, false) == card.current_zone:
		var attackers := 0
		for enemy in _get_board_creatures(opponent):
			if enemy.current_zone in opponent.frontline_zones \
					and enemy.creature_mode == Card.CreatureMode.AGGRESSIVE \
					and CardStrategy.visible(self, enemy):
				attackers += 1
		if attackers > 0:
			score += 3000 + mini(3, attackers) * 1000
	return _discount_sacrifice_candidate_for_debilitation(card, score)

func _discount_sacrifice_candidate_for_debilitation(card: Card, score: int) -> int:
	if card == null or card.current_zone == null or not card.current_zone.is_board_zone():
		return score
	var full_value := CardStrategy.value(self, card)
	if full_value <= 0:
		return score
	var discount := CardStrategy._debilitation_discount(self, card)
	var remaining_fraction := 1.0 - clampf(float(discount) / float(full_value), 0.0, 0.85)
	return int(round(float(score) * remaining_fraction))

func _score_altar_void_target(card: Card) -> int:
	if card == null or card.is_god or card is ActiveGodCard:
		return 1000000
	if card.card_owner == opponent:
		return -1500 - _score_enemy_target(card)
	var score := _score_friendly_target(card)
	score += CardStrategy.clanking_chains_gain(self, card)
	if card.current_zone != null and card.current_zone.zone_type == Zone.ZoneType.RESERVE:
		score -= 150
	if card is Askelladen:
		score += 2500
	if card is EnkiLordOfEridu:
		score += 2200
	return _discount_sacrifice_candidate_for_debilitation(card, score)
