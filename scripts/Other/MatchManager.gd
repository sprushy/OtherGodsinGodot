# MatchManager.gd
extends RefCounted
class_name MatchManager

# This class manages high-level match flow and targeting state,
# decoupling game rules from the UI.

const TiamatScript = preload("res://scripts/cards/Gods/TiamatThePrimordial.gd")
const MatchCommandRegistryScript = preload("res://scripts/Other/MatchCommandRegistry.gd")
const AUTHORITATIVE_FLOW_LOG_PREFIX := "[OG server flow]"
const AUTHORITATIVE_FLOW_CHECK_DELAY_SECONDS := 1.0
const AUTHORITATIVE_SETTLED_REFRESH_DELAY_SECONDS := 0.05
const PRIORITY_STOP_KEYS := ["start", "main", "combat", "end"]
const PRIORITY_AUTO_MODE_NONE := "none"
const PRIORITY_AUTO_MODE_PLAY := "play"
const PRIORITY_AUTO_MODE_FAST_FORWARD := "fast_forward"

signal targeting_started(source: Card, target_type: String)
signal targeting_ended()
signal move_validated(move: Dictionary)
signal move_failed(reason: String)

var game_manager: GameManager
var game_state: GameState
var network_manager: Node = null # Set this if in multiplayer mode
var authoritative_match_flow_enabled: bool = false
var allow_immediate_local_authoritative_stack_resolution: bool = false
var remote_authoritative_stack_window_locked: bool = false
var remote_authoritative_visual_linger_pending: bool = false

# Targeting State (moved from CombatMockGame)
var pending_click_selection_name: String = ""
var pending_click_selection_source: Card = null
var pending_click_selection_validator: Callable = Callable()
var pending_click_selection_confirm: Callable = Callable()
var pending_click_selection_cancel: Callable = Callable()

# Hand card play state
var pending_paid_hand_card: Card = null
var pending_paid_hand_display_zone: Zone = null
var pending_paid_hand_display_zone_auto: bool = false
var pending_spell_display_zone: Zone = null

# Spell/Ability waiting state
var awaiting_spell_target: bool = false
var spell_waiting_for_target: Card = null
var spell_waiting_for_action: CardAction = null
var spell_waiting_for_display_zone: Zone = null

# Other specific targeting states
var awaiting_god_ability_target: bool = false
var god_ability_source: Card = null

var awaiting_stupefy_target: bool = false
var stupefy_source: Card = null

var awaiting_pyre_target: bool = false
var pyre_source: Card = null # AncientPyre

var awaiting_anointing_target: bool = false
var anointing_source: Card = null # AnointingStatue

# Attack state
var selected_attacker: Card = null
var pending_attack_target = null # Card or Player
var selected_interceptor: Card = null
var _pending_hunting_tactics_attack_declaration: bool = false
var _pending_hunting_tactics_attack_attacker: Card = null
var _pending_hunting_tactics_attack_target = null # Card or Player

# Spell-specific targeting states
var pending_blot_spell: BlotSacrifice = null
var pending_blot_sacrifice_target: Card = null
var pending_blot_selected_creatures: Array[Card] = []
var pending_blot_costs_paid: bool = false
var pending_blot_display_zone: Zone = null
var pending_blot_cast_command: Dictionary = {}

var pending_divine_caprice_power: Card = null
var pending_divine_caprice_selected_zone: Zone = null

var pending_retreat_action: CardAction = null
var pending_retreat_target: Card = null
var pending_retreat_prompt_uids: Array[String] = []
var pending_retreat_guardian_blocked_uids: Array[String] = []
var pending_humbaba_action: CardAction = null
var pending_humbaba_target = null
var pending_humbaba_prompt_uids: Array[String] = []
var pending_combat_reveal_linger_action: CardAction = null
var _combat_reveal_wait_generation: int = 0
var _board_leaving_activation_linger_pending: bool = false
var _pending_end_turn_after_resurrection: bool = false
var _active_command_sender_info: Dictionary = {}
var _active_command_type: String = ""
var _active_command_pending_prompt_id: int = -1
var _resolving_priority_choice_command: bool = false
var _pending_ui_interactions: Array[Dictionary] = []
var _queued_ui_interactions: Array[Dictionary] = []
var _next_ui_interaction_id: int = 1
var _priority_preferences_by_player: Dictionary = {}
var _pending_turn_action_after_opponent_priority_command: Dictionary = {}
var _pending_turn_action_after_opponent_priority_sender_info: Dictionary = {}
var _replaying_turn_action_after_opponent_priority: bool = false
var _active_turn_start_sequence_turn: int = -1
var _turn_start_sequence_feedback: String = ""
var _turn_start_priority_queued_turn: int = -1

func _init(p_game_manager: GameManager) -> void:
	game_manager = p_game_manager
	move_failed.connect(_on_move_failed)
	if game_manager != null and not game_manager.decision_requested.is_connected(_on_game_manager_decision_requested):
		game_manager.decision_requested.connect(_on_game_manager_decision_requested)
	if game_manager != null and not game_manager.card_summoned.is_connected(_on_game_manager_card_summoned):
		game_manager.card_summoned.connect(_on_game_manager_card_summoned)

func reset_runtime_state() -> void:
	_clear_targeting_state()
	pending_paid_hand_card = null
	pending_paid_hand_display_zone = null
	pending_paid_hand_display_zone_auto = false
	pending_spell_display_zone = null
	awaiting_spell_target = false
	spell_waiting_for_target = null
	spell_waiting_for_action = null
	spell_waiting_for_display_zone = null
	awaiting_god_ability_target = false
	god_ability_source = null
	awaiting_stupefy_target = false
	stupefy_source = null
	awaiting_pyre_target = false
	pyre_source = null
	awaiting_anointing_target = false
	anointing_source = null
	selected_attacker = null
	pending_attack_target = null
	selected_interceptor = null
	pending_blot_spell = null
	pending_blot_sacrifice_target = null
	pending_blot_selected_creatures.clear()
	pending_blot_costs_paid = false
	pending_blot_display_zone = null
	pending_blot_cast_command.clear()
	pending_divine_caprice_power = null
	pending_divine_caprice_selected_zone = null
	pending_retreat_action = null
	pending_retreat_target = null
	pending_retreat_prompt_uids.clear()
	pending_retreat_guardian_blocked_uids.clear()
	pending_humbaba_action = null
	pending_humbaba_target = null
	pending_humbaba_prompt_uids.clear()
	pending_combat_reveal_linger_action = null
	_combat_reveal_wait_generation = 0
	_board_leaving_activation_linger_pending = false
	_pending_end_turn_after_resurrection = false
	_active_command_sender_info.clear()
	_active_command_type = ""
	_active_command_pending_prompt_id = -1
	_resolving_priority_choice_command = false
	_pending_ui_interactions.clear()
	_queued_ui_interactions.clear()
	_next_ui_interaction_id = 1
	_pending_turn_action_after_opponent_priority_command.clear()
	_pending_turn_action_after_opponent_priority_sender_info.clear()
	_replaying_turn_action_after_opponent_priority = false
	_clear_pending_hunting_tactics_attack_declaration()
	_active_turn_start_sequence_turn = -1
	_turn_start_sequence_feedback = ""
	_turn_start_priority_queued_turn = -1
	last_resolution_text = ""
	last_move_failed_reason = ""
	_authoritative_stack_resolution_pending = false
	allow_immediate_local_authoritative_stack_resolution = false
	remote_authoritative_stack_window_locked = false
	remote_authoritative_visual_linger_pending = false

# --- Targeting Control ---

func start_click_selection(
	selection_name: String,
	source: Card,
	validator: Callable,
	confirm: Callable,
	cancel: Callable
) -> void:
	pending_click_selection_name = selection_name
	pending_click_selection_source = source
	pending_click_selection_validator = validator
	pending_click_selection_confirm = confirm
	pending_click_selection_cancel = cancel
	targeting_started.emit(source, selection_name)

func _clear_targeting_state() -> void:
	pending_click_selection_name = ""
	pending_click_selection_source = null
	pending_click_selection_validator = Callable()
	pending_click_selection_confirm = Callable()
	pending_click_selection_cancel = Callable()
	targeting_ended.emit()

func cancel_targeting() -> void:
	var click_cancel_callback := pending_click_selection_cancel
	_clear_targeting_state()
	
	awaiting_spell_target = false
	spell_waiting_for_target = null
	spell_waiting_for_action = null
	spell_waiting_for_display_zone = null
	
	awaiting_god_ability_target = false
	god_ability_source = null
	
	awaiting_stupefy_target = false
	stupefy_source = null
	
	awaiting_pyre_target = false
	pyre_source = null
	
	awaiting_anointing_target = false
	anointing_source = null
	
	if click_cancel_callback.is_valid():
		click_cancel_callback.call()

func _resolve_live_click_selection_target(target):
	if game_manager == null or not (target is Card):
		return target
	var target_card := target as Card
	var target_uid := str(target_card.uid).strip_edges()
	if target_uid == "":
		return target
	var live_target := game_manager.get_card_by_uid(target_uid)
	return live_target if live_target != null else target

func _is_card_in_targets_by_uid(candidate: Card, valid_targets: Array) -> bool:
	if candidate == null:
		return false
	var candidate_uid := str(candidate.uid).strip_edges()
	for valid_target in valid_targets:
		if valid_target == candidate:
			return true
		if valid_target is Card and candidate_uid != "" and str(valid_target.uid).strip_edges() == candidate_uid:
			return true
	return false

func confirm_click_selection(target) -> void:
	var resolved_target = _resolve_live_click_selection_target(target)
	if not pending_click_selection_validator.call(resolved_target):
		move_failed.emit("Invalid target for " + pending_click_selection_name)
		return
		
	var confirm_callback = pending_click_selection_confirm
	_clear_targeting_state()
	if confirm_callback.is_valid():
		confirm_callback.call(resolved_target)

func get_targeting_name() -> String:
	if pending_click_selection_confirm.is_valid():
		return pending_click_selection_name
	if awaiting_pyre_target and pyre_source != null:
		return pyre_source.card_name + ": Ritual Flame"
	if awaiting_anointing_target and anointing_source != null:
		return anointing_source.card_name
	if awaiting_god_ability_target and god_ability_source != null:
		return god_ability_source.card_name
	if awaiting_stupefy_target and stupefy_source != null:
		return stupefy_source.card_name + ": Stupefy"
	if awaiting_spell_target and spell_waiting_for_target != null:
		return spell_waiting_for_target.card_name
	return "Target selection"

func _execute_activate_card_ability_command(
	source_uid: String,
	target_uid: String,
	option: Dictionary,
	has_option: bool,
	has_return_to_hand: bool,
	return_to_hand: bool
) -> void:
	if game_manager == null or source_uid.strip_edges() == "":
		return
	var source_card := game_manager.get_card_by_uid(source_uid)
	if source_card == null or not source_card.has_method("activate"):
		return
	if source_card.card_type == Card.CardType.CREATURE \
			and not game_manager.pay_creature_action_mana_cost(source_card, "activate"):
		return
	if has_return_to_hand:
		source_card.activate(game_manager, {"return_to_hand": return_to_hand})
		return
	var target_card: Card = null
	if target_uid.strip_edges() != "":
		target_card = game_manager.get_card_by_uid(target_uid)
	_activate_card_with_optional_payload(source_card, target_card, option if has_option else {})

func _activate_card_with_optional_payload(source_card: Card, target: Card = null, option: Dictionary = {}) -> void:
	if source_card == null or not source_card.has_method("activate"):
		return
	if option.is_empty():
		if target != null:
			source_card.activate(game_manager, target)
		else:
			source_card.activate(game_manager)
		return
	if _activation_accepts_dictionary_payload(source_card):
		source_card.activate(game_manager, option)
		return
	if target != null:
		source_card.activate(game_manager, target)
	else:
		source_card.activate(game_manager)

func _activation_accepts_dictionary_payload(source_card: Card) -> bool:
	if source_card == null:
		return false
	for method_info in source_card.get_method_list():
		if str(method_info.get("name", "")) != "activate":
			continue
		var args: Array = method_info.get("args", [])
		if args.size() < 2:
			return false
		var payload_arg: Dictionary = args[1]
		var payload_type := int(payload_arg.get("type", TYPE_NIL))
		return payload_type == TYPE_NIL or payload_type == TYPE_DICTIONARY
	return false

signal action_resolved(action: CardAction)
signal request_ui_interaction(player_index: int, type: String, data: Dictionary)
signal ui_refresh_requested()

const AUTHORITATIVE_STACK_ACTION_LINGER_SECONDS := 1.2

var last_resolution_text: String = ""
var last_move_failed_reason: String = ""
var _authoritative_stack_resolution_pending: bool = false

const SIMPLE_DEFERRED_PROMPT_COMPLETION_COMMANDS := [
	"blessed_knights_choice",
	"fourth_sage_enmegalamma_choice",
	"rally_the_troops_choice",
	"harii_jarl_impact_choice",
	"tiamat_active_summon_choice",
	"giant_master_architect_choice",
	"pai_long_autumn_king_choice",
]

const HANDLER_COMPLETES_DEFERRED_PRIORITY_CHOICE_COMMANDS := [
	"fenrir_devour_choice",
	"gugalanna_celestial_charge_choice",
]

func _on_game_manager_decision_requested(player: Player, type: String, data: Dictionary) -> void:
	if game_manager == null or player == null:
		return
	var interaction_data := data.duplicate(true)
	if bool(interaction_data.get("queue_with_priority", false)):
		interaction_data.erase("queue_with_priority")
		var source_card := game_manager.get_card_by_uid(str(interaction_data.get("source_uid", "")))
		var event_name := str(interaction_data.get("event_name", type)).strip_edges()
		var completion_command_type := str(interaction_data.get("completion_command_type", "")).strip_edges()
		interaction_data.erase("event_name")
		interaction_data.erase("completion_command_type")
		if completion_command_type.is_empty() and not interaction_data.has("resolve_method"):
			completion_command_type = _get_default_completion_command_for_interaction(type)
		if interaction_data.has("resolve_method"):
			_queue_method_priority_event(
				player,
				source_card,
				event_name if event_name != "" else type,
				interaction_data
			)
			return
		if _should_collect_choice_before_priority(
			type,
			completion_command_type,
			source_card,
			interaction_data
		):
			interaction_data["_queue_priority_after_choice"] = true
			interaction_data["_priority_event_name"] = event_name if event_name != "" else type
			interaction_data["_priority_completion_command_type"] = completion_command_type
			_present_pre_priority_choice_interaction(player, type, interaction_data)
			return
		_queue_decision_priority_event(
			player,
			source_card,
			event_name if event_name != "" else type,
			type,
			interaction_data,
			completion_command_type
		)
		return
	_emit_ui_interaction_for_player(player, type, interaction_data)

func _present_pre_priority_choice_interaction(player: Player, type: String, data: Dictionary) -> void:
	var parent_action := _get_current_resolving_action()
	if parent_action != null:
		_queue_ui_interaction(player, type, data, parent_action)
		return
	if not _active_command_type.is_empty():
		_queue_ui_interaction(player, type, data)
		return
	_emit_ui_interaction_for_player(player, type, data)

func _get_current_resolving_action() -> CardAction:
	if game_manager == null or game_manager.resolving_stack_actions.is_empty():
		return null
	return game_manager.resolving_stack_actions.back() as CardAction

func _emit_ui_interaction_for_player(player: Player, type: String, data: Dictionary) -> void:
	if game_manager == null or player == null:
		return
	if not _pending_ui_interactions.is_empty() or not _queued_ui_interactions.is_empty():
		_queue_ui_interaction(player, type, data)
		return
	_emit_ui_interaction_now(player, type, data)

func _emit_ui_interaction_now(player: Player, type: String, data: Dictionary) -> void:
	if game_manager == null or player == null:
		return
	var player_idx := game_manager.players.find(player)
	if player_idx < 0:
		return
	if type == "intercept" and _has_duplicate_pending_ui_interaction(player, type, data):
		return
	var prompt_id := _record_pending_ui_interaction(player, type, data)
	var emitted_data := data.duplicate(true)
	emitted_data["_prompt_id"] = prompt_id
	request_ui_interaction.emit(player_idx, type, emitted_data)

func _queue_ui_interaction(
	player: Player,
	type: String,
	data: Dictionary,
	release_after_action: CardAction = null
) -> void:
	if player == null or type.strip_edges() == "":
		return
	for queued in _queued_ui_interactions:
		if queued.get("player", null) == player \
				and str(queued.get("type", "")) == type \
				and queued.get("data", {}) == data \
				and queued.get("release_after_action", null) == release_after_action:
			return
	_queued_ui_interactions.append({
		"player": player,
		"type": type,
		"data": data.duplicate(true),
		"release_after_action": release_after_action,
		"turn_number": game_manager.turn_number if game_manager != null else -1,
	})

func _release_next_queued_ui_interaction() -> void:
	_prune_stale_ui_interactions_for_current_turn()
	if not _pending_ui_interactions.is_empty():
		return
	while not _queued_ui_interactions.is_empty():
		var queued: Dictionary = _queued_ui_interactions[0]
		var release_after_action := queued.get("release_after_action", null) as CardAction
		if release_after_action != null \
				and game_manager != null \
				and release_after_action in game_manager.resolving_stack_actions:
			return
		_queued_ui_interactions.pop_front()
		if not _is_queued_ui_interaction_still_valid(queued):
			continue
		var player := queued.get("player", null) as Player
		var type := str(queued.get("type", ""))
		var data: Dictionary = queued.get("data", {})
		if player == null or game_manager == null or game_manager.players.find(player) < 0:
			continue
		_emit_ui_interaction_now(player, type, data)
		return
	if pending_blot_spell != null:
		_try_queue_pending_authoritative_blot_action()
		return
	if _continue_active_authoritative_turn_start_sequence():
		return
	if game_manager != null and game_manager.action_stack.is_empty():
		_try_process_pending_turn_action_after_opponent_priority()
		return
	_advance_authoritative_priority()

func _is_queued_ui_interaction_still_valid(queued: Dictionary) -> bool:
	if game_manager == null:
		return false
	if int(queued.get("turn_number", game_manager.turn_number)) != game_manager.turn_number:
		return false
	var player := queued.get("player", null) as Player
	if player == null or game_manager.players.find(player) < 0:
		return false
	var type := str(queued.get("type", ""))
	var data: Dictionary = queued.get("data", {})
	var source_uid := str(data.get("source_uid", "")).strip_edges()
	match type:
		"priority":
			return not _is_stale_priority_ui_interaction(queued)
		"wheel_of_fire_turn_start":
			var wheel := game_manager.get_card_by_uid(source_uid) as WheelOfFire
			return wheel != null \
				and wheel.card_owner == player \
				and wheel.can_offer_turn_start_advance(game_manager)
		"breidablik_turn_start":
			var breidablik := game_manager.get_card_by_uid(source_uid) as Breidablik
			if breidablik == null \
					or breidablik.card_owner != player \
					or not breidablik.can_return_priest(game_manager):
				return false
			var stored_priest_uids: Array[String] = []
			for priest in breidablik.get_stored_priests():
				if priest != null:
					stored_priest_uids.append(priest.uid)
			data["target_uids"] = stored_priest_uids
			queued["data"] = data
			return not stored_priest_uids.is_empty()
		"wolf_adolescent_maturation":
			var wolf := game_manager.get_card_by_uid(source_uid)
			if wolf == null \
					or not (wolf is WolfAdolescent or wolf is WolfCub) \
					or wolf.get_controller() != player \
					or not wolf.can_offer_maturation(game_manager):
				return false
			var target_uids: Array[String] = []
			for target in wolf.get_valid_maturation_targets():
				if target != null:
					target_uids.append(target.uid)
			data["target_uids"] = target_uids
			queued["data"] = data
			return not target_uids.is_empty()
	return true

func emit_ui_interaction_for_player(player: Player, type: String, data: Dictionary) -> void:
	_emit_ui_interaction_for_player(player, type, data)

func _record_pending_ui_interaction(player: Player, type: String, data: Dictionary) -> int:
	if player == null or type.strip_edges() == "":
		return -1
	var prompt_id := _next_ui_interaction_id
	var entry := {
		"player": player,
		"type": type,
		"turn_number": game_manager.turn_number if game_manager != null else -1,
		"prompt_id": prompt_id,
		"data": data.duplicate(true),
	}
	_next_ui_interaction_id += 1
	_prune_matching_pending_ui_interactions(entry)
	_pending_ui_interactions.append(entry)
	while _pending_ui_interactions.size() > 64:
		_pending_ui_interactions.remove_at(0)
	return prompt_id

func _prune_stale_ui_interactions_for_current_turn() -> void:
	if game_manager == null:
		return
	var current_turn := game_manager.turn_number
	for idx in range(_pending_ui_interactions.size() - 1, -1, -1):
		var entry: Dictionary = _pending_ui_interactions[idx]
		if _is_stale_ui_interaction_for_current_turn(entry, current_turn):
			_pending_ui_interactions.remove_at(idx)
	for idx in range(_queued_ui_interactions.size() - 1, -1, -1):
		var queued: Dictionary = _queued_ui_interactions[idx]
		if _is_stale_ui_interaction_for_current_turn(queued, current_turn):
			_queued_ui_interactions.remove_at(idx)

func _is_stale_ui_interaction_for_current_turn(entry: Dictionary, current_turn: int) -> bool:
	if int(entry.get("turn_number", current_turn)) != current_turn:
		return true
	if str(entry.get("type", "")) == "priority":
		return _is_stale_priority_ui_interaction(entry)
	return false

func _is_stale_priority_ui_interaction(entry: Dictionary) -> bool:
	if game_manager == null:
		return false
	if game_manager.action_stack.is_empty():
		return true
	var player := entry.get("player", null) as Player
	if player == null:
		return true
	return game_manager.priority_player != player

func _has_duplicate_pending_ui_interaction(player: Player, type: String, data: Dictionary) -> bool:
	for existing in _pending_ui_interactions:
		if existing.get("player", null) != player:
			continue
		if str(existing.get("type", "")) != type:
			continue
		if game_manager != null and int(existing.get("turn_number", -1)) != game_manager.turn_number:
			continue
		var existing_data: Dictionary = existing.get("data", {})
		if existing_data == data:
			return true
	return false

func _prune_matching_pending_ui_interactions(entry: Dictionary) -> void:
	for idx in range(_pending_ui_interactions.size() - 1, -1, -1):
		var existing := _pending_ui_interactions[idx]
		if str(existing.get("type", "")) != str(entry.get("type", "")):
			continue
		if _pending_ui_interaction_has_same_identity(existing, entry):
			_pending_ui_interactions.remove_at(idx)

func _pending_ui_interaction_has_same_identity(first: Dictionary, second: Dictionary) -> bool:
	var first_data: Dictionary = first.get("data", {})
	var second_data: Dictionary = second.get("data", {})
	var identity_keys := [
		"source_uid",
		"card_uid",
		"victim_uid",
		"attacker_uid",
		"target_uid",
		"target_player_index",
		"demon_uid",
		"summoned_uid",
		"power_uid",
		"structure_uid",
	]
	var compared_key := false
	for key in identity_keys:
		if not second_data.has(key):
			continue
		compared_key = true
		if str(first_data.get(key, "")) != str(second_data.get(key, "")):
			return false
	return compared_key or first.get("player", null) == second.get("player", null)

func _command_can_bypass_pending_ui_interaction(command_type: String) -> bool:
	match command_type:
		"forfeit", "forfeit_match", "set_priority_preferences":
			return true
		"upkeep_choice", "tiamat_upkeep_choice", "skoll_upkeep_summon":
			return true
	return false

func _validate_pending_ui_interaction_for_command(command: Dictionary) -> Dictionary:
	_prune_stale_ui_interactions_for_current_turn()
	var result := {
		"error": "",
		"prompt_id": -1,
	}
	var command_type := str(command.get("type", ""))
	var expected_type := _get_ui_interaction_type_for_command(command_type)
	if expected_type == "":
		var blocking_interaction: Dictionary = {}
		if not _pending_ui_interactions.is_empty():
			blocking_interaction = _pending_ui_interactions[0]
		elif not _queued_ui_interactions.is_empty():
			blocking_interaction = _queued_ui_interactions[0]
		if not blocking_interaction.is_empty() \
				and not _command_can_bypass_pending_ui_interaction(command_type):
			result["error"] = "Resolve the pending %s choice before continuing." % str(blocking_interaction.get("type", "card"))
		return result
	if not (authoritative_match_flow_enabled or network_manager != null):
		return result
	var prompt_idx := _find_pending_ui_interaction_index(command, expected_type)
	if prompt_idx < 0:
		result["error"] = "%s: no matching server prompt is pending" % command_type
		return result
	result["prompt_id"] = int(_pending_ui_interactions[prompt_idx].get("prompt_id", -1))
	return result

func _consume_pending_ui_interaction_by_id(prompt_id: int) -> bool:
	if prompt_id < 0:
		return false
	for idx in range(_pending_ui_interactions.size() - 1, -1, -1):
		if int(_pending_ui_interactions[idx].get("prompt_id", -1)) == prompt_id:
			_pending_ui_interactions.remove_at(idx)
			call_deferred("_release_next_queued_ui_interaction")
			return true
	return false

func _consume_active_command_prompt_for_completion(command_type: String) -> bool:
	if _active_command_pending_prompt_id < 0:
		return false
	var expected_type := command_type.strip_edges()
	if expected_type != "" and _active_command_type != expected_type:
		return false
	var prompt_id := _active_command_pending_prompt_id
	_active_command_pending_prompt_id = -1
	return _consume_pending_ui_interaction_by_id(prompt_id)

func _consume_matching_pending_ui_interaction_for_command(command: Dictionary) -> bool:
	var expected_type := _get_ui_interaction_type_for_command(str(command.get("type", "")))
	if expected_type == "":
		return false
	var prompt_idx := _find_pending_ui_interaction_index(command, expected_type)
	if prompt_idx < 0:
		return false
	var prompt_id := int(_pending_ui_interactions[prompt_idx].get("prompt_id", -1))
	return _consume_pending_ui_interaction_by_id(prompt_id)

func _reemit_pending_ui_interaction(entry: Dictionary) -> bool:
	if game_manager == null or entry.is_empty():
		return false
	var player := entry.get("player", null) as Player
	var interaction_type := str(entry.get("type", "")).strip_edges()
	if player == null or interaction_type == "":
		return false
	var player_idx := game_manager.players.find(player)
	if player_idx < 0:
		return false
	var interaction_data: Dictionary = entry.get("data", {})
	var emitted_data := interaction_data.duplicate(true)
	emitted_data["_prompt_id"] = int(entry.get("prompt_id", -1))
	request_ui_interaction.emit(player_idx, interaction_type, emitted_data)
	return true

func _reemit_active_pending_ui_interaction() -> bool:
	if _pending_ui_interactions.is_empty():
		return false
	return _reemit_pending_ui_interaction(_pending_ui_interactions[0])

func _consume_pending_ui_interaction_for_player(player: Player, interaction_type: String) -> bool:
	if player == null or interaction_type.strip_edges() == "":
		return false
	for idx in range(_pending_ui_interactions.size() - 1, -1, -1):
		var entry: Dictionary = _pending_ui_interactions[idx]
		if entry.get("player", null) != player \
				or str(entry.get("type", "")) != interaction_type:
			continue
		return _consume_pending_ui_interaction_by_id(int(entry.get("prompt_id", -1)))
	return false

func _resume_authoritative_flow_after_prompt_command() -> void:
	_prune_stale_ui_interactions_for_current_turn()
	if not _pending_ui_interactions.is_empty():
		# The authoritative prompt queue is strictly serial. If the active
		# selector was missed or replaced by a state refresh, reissue that same
		# prompt instead of leaving the match locked behind invisible state.
		_reemit_active_pending_ui_interaction()
		return
	if not _queued_ui_interactions.is_empty():
		return
	if pending_blot_spell != null:
		_try_queue_pending_authoritative_blot_action()
		return
	if not _uses_authoritative_headless_priority_flow() or game_manager == null:
		return
	if _continue_active_authoritative_turn_start_sequence():
		return
	if game_manager.action_stack.is_empty():
		_try_process_pending_turn_action_after_opponent_priority()
		return
	_advance_authoritative_priority()

func _get_ui_interaction_type_for_command(command_type: String) -> String:
	return MatchCommandRegistryScript.get_ui_interaction_type(command_type)

func _get_default_completion_command_for_interaction(interaction_type: String) -> String:
	match interaction_type:
		"blessed_knights_ward":
			return "blessed_knights_choice"
		"first_sage_adapa_impact":
			return "first_sage_adapa_choice"
		"third_sage_enmedugga_impact":
			return "third_sage_enmedugga_choice"
		"fourth_sage_enmegalamma_impact":
			return "fourth_sage_enmegalamma_choice"
		"sixth_sage_an_enlilda_impact":
			return "sixth_sage_an_enlilda_choice"
		"seventh_sage_utuabzu_impact":
			return "seventh_sage_utuabzu_choice"
		"rally_the_troops":
			return "rally_the_troops_choice"
		"terror_impact":
			return "terror_impact_choice"
		"fenrir_devour_impact":
			return "fenrir_devour_choice"
		"harii_jarl_impact":
			return "harii_jarl_impact_choice"
		"durinn_secondborn_impact":
			return "durinn_secondborn_choice"
		"gugalanna_celestial_charge":
			return "gugalanna_celestial_charge_choice"
		"freyja_active_open_sessrumnir":
			return "freyja_active_open_sessrumnir_choice"
		"tiamat_active_summon":
			return "tiamat_active_summon_choice"
		"giant_master_architect_impact":
			return "giant_master_architect_choice"
		"pai_long_autumn_king_impact":
			return "pai_long_autumn_king_choice"
		"nergal_lion_impact":
			return "nergal_lion_choice"
		"nusku_active_core_flame":
			return "nusku_active_core_flame_choice"
	return ""

func _find_pending_ui_interaction_index(command: Dictionary, expected_type: String) -> int:
	for idx in range(_pending_ui_interactions.size() - 1, -1, -1):
		var entry := _pending_ui_interactions[idx]
		if _pending_ui_interaction_matches_command(entry, command, expected_type):
			return idx
	return -1

func _pending_ui_interaction_matches_command(entry: Dictionary, command: Dictionary, expected_type: String) -> bool:
	if str(entry.get("type", "")) != expected_type:
		return false
	if game_manager != null and int(entry.get("turn_number", -1)) != game_manager.turn_number:
		return false
	var required_player := _get_required_player_for_command(command)
	if required_player != null and entry.get("player", null) != required_player:
		return false
	if expected_type == "intercept":
		return _pending_intercept_prompt_matches_command(entry, command)
	var data: Dictionary = entry.get("data", {})
	for key in ["source_uid", "card_uid", "attacker_uid", "demon_uid", "summoned_uid", "power_uid", "structure_uid"]:
		if not data.has(key):
			continue
		var command_uid := _get_command_uid_for_prompt_key(command, key)
		if command_uid == "" or command_uid != str(data.get(key, "")):
			return false
	if data.has("victim_uid"):
		var victim_uid := _get_command_choice_uid(command)
		if victim_uid == "" or victim_uid != str(data.get("victim_uid", "")):
			return false
	if data.has("target_uid"):
		var target_uid := _get_command_choice_uid(command)
		if target_uid == "" or target_uid != str(data.get("target_uid", "")):
			return false
	if data.has("target_uids") and not _command_choices_are_in_prompt(command, data.get("target_uids", [])):
		return false
	if data.has("attacker_uids") and not _command_uid_is_in_prompt_list(command, "attacker_uid", data.get("attacker_uids", [])):
		return false
	if data.has("defender_uids") and not _command_uid_is_in_prompt_list(command, "defender_uid", data.get("defender_uids", [])):
		return false
	return true

func _pending_intercept_prompt_matches_command(entry: Dictionary, command: Dictionary) -> bool:
	if selected_attacker == null or pending_attack_target == null:
		return false
	var data: Dictionary = entry.get("data", {})
	var expected_attacker_uid := str(data.get("attacker_uid", "")).strip_edges()
	if expected_attacker_uid != "" and expected_attacker_uid != selected_attacker.uid:
		return false
	if pending_attack_target is Card:
		var pending_target := pending_attack_target as Card
		var expected_target_uid := str(data.get("target_uid", "")).strip_edges()
		if expected_target_uid != "" and expected_target_uid != pending_target.uid:
			return false
		if data.has("target_player_index"):
			var target_player_idx := game_manager.players.find(pending_target.get_controller()) if game_manager != null else -1
			if int(data.get("target_player_index", -1)) != target_player_idx:
				return false
	elif pending_attack_target is Player:
		var pending_target_player := pending_attack_target as Player
		var pending_target_player_idx := game_manager.players.find(pending_target_player) if game_manager != null else -1
		if data.has("target_player_index") and int(data.get("target_player_index", -1)) != pending_target_player_idx:
			return false
		var expected_target_uid := str(data.get("target_uid", "")).strip_edges()
		if expected_target_uid != "" and expected_target_uid != str(pending_target_player_idx):
			return false
	var interceptor_uid := str(command.get("interceptor_uid", "")).strip_edges()
	if interceptor_uid != "" and data.has("interceptor_uids"):
		if interceptor_uid not in _string_uid_list(data.get("interceptor_uids", [])):
			return false
	return true

func _get_command_uid_for_prompt_key(command: Dictionary, key: String) -> String:
	match key:
		"card_uid":
			return str(command.get("card_uid", "")).strip_edges()
		"source_uid":
			return str(command.get("source_uid", "")).strip_edges()
		"attacker_uid":
			return str(command.get("attacker_uid", "")).strip_edges()
		"demon_uid":
			return str(command.get("demon_uid", "")).strip_edges()
		"summoned_uid":
			return str(command.get("summoned_uid", "")).strip_edges()
	return str(command.get(key, "")).strip_edges()

func _get_command_choice_uid(command: Dictionary) -> String:
	for key in ["target_uid", "chosen_uid", "victim_uid"]:
		var uid := str(command.get(key, "")).strip_edges()
		if uid != "":
			return uid
	return ""

func _command_choices_are_in_prompt(command: Dictionary, prompt_values: Array) -> bool:
	var allowed_uids := _string_uid_list(prompt_values)
	var chosen_uids: Array[String] = []
	for top_array_key in ["target_uids", "chosen_uids"]:
		if command.has(top_array_key):
			for raw_uid in command.get(top_array_key, []):
				var top_array_uid := str(raw_uid).strip_edges()
				if top_array_uid != "":
					chosen_uids.append(top_array_uid)
	var option_data = command.get("option", {})
	if option_data is Dictionary:
		var option := option_data as Dictionary
		for option_array_key in ["target_uids", "chosen_uids"]:
			if option.has(option_array_key):
				for raw_uid in option.get(option_array_key, []):
					var option_array_uid := str(raw_uid).strip_edges()
					if option_array_uid != "":
						chosen_uids.append(option_array_uid)
		for single_key in ["target_uid", "chosen_uid", "victim_uid"]:
			var option_single_uid := str(option.get(single_key, "")).strip_edges()
			if option_single_uid != "":
				chosen_uids.append(option_single_uid)
	var single_choice := _get_command_choice_uid(command)
	if single_choice != "":
		chosen_uids.append(single_choice)
	for uid in chosen_uids:
		if uid not in allowed_uids:
			return false
	return true

func _command_uid_is_in_prompt_list(command: Dictionary, command_key: String, prompt_values: Array) -> bool:
	var command_uid := str(command.get(command_key, "")).strip_edges()
	if command_uid == "":
		return true
	return command_uid in _string_uid_list(prompt_values)

func _string_uid_list(values: Array) -> Array[String]:
	var uids: Array[String] = []
	for value in values:
		var uid := str(value).strip_edges()
		if uid != "":
			uids.append(uid)
	return uids

func _validate_end_turn_discards(player: Player, discard_uids: Array) -> Dictionary:
	var result := {
		"ok": false,
		"reason": "end_turn: invalid discard selection",
		"cards": [],
	}
	_log_authoritative_flow_state("end_turn_discard:validate_start player=%s discard_uids=%s" % [
		_get_player_debug_label(player),
		str(discard_uids),
	])
	if player == null or player.hand_zone == null:
		result["reason"] = "end_turn: player hand not found"
		_log_authoritative_flow_state("end_turn_discard:validate_fail reason=%s" % str(result["reason"]))
		return result
	var required_count := maxi(0, player.hand_zone.get_card_count() - Player.MAX_HAND_SIZE)
	_log_authoritative_flow_state("end_turn_discard:required hand=%d max=%d required=%d selected=%d" % [
		player.hand_zone.get_card_count(),
		Player.MAX_HAND_SIZE,
		required_count,
		discard_uids.size(),
	])
	var selected_cards: Array[Card] = []
	var seen_uids: Array[String] = []
	for raw_uid in discard_uids:
		var discard_uid := str(raw_uid).strip_edges()
		if discard_uid == "" or discard_uid in seen_uids:
			result["reason"] = "end_turn: discard choices must be unique hand cards"
			_log_authoritative_flow_state("end_turn_discard:validate_fail reason=%s uid=%s" % [
				str(result["reason"]),
				discard_uid,
			])
			return result
		seen_uids.append(discard_uid)
		var discard_card := game_manager.get_card_by_uid(discard_uid)
		if discard_card == null or discard_card.current_zone != player.hand_zone:
			result["reason"] = "end_turn: discard choices must be cards in your hand"
			_log_authoritative_flow_state("end_turn_discard:validate_fail reason=%s uid=%s card=%s" % [
				str(result["reason"]),
				discard_uid,
				_get_card_debug_label(discard_card),
			])
			return result
		selected_cards.append(discard_card)
	if selected_cards.size() != required_count:
		result["reason"] = "end_turn: discard exactly %d card(s) to reach the hand limit" % required_count
		_log_authoritative_flow_state("end_turn_discard:validate_fail reason=%s" % str(result["reason"]))
		return result
	result["ok"] = true
	result["reason"] = ""
	result["cards"] = selected_cards
	_log_authoritative_flow_state("end_turn_discard:validate_ok selected=%d" % selected_cards.size())
	return result

func _queue_decision_priority_event(
	player: Player,
	source_card: Card,
	event_name: String,
	interaction_type: String,
	interaction_data: Dictionary,
	completion_command_type: String = ""
) -> void:
	if game_manager == null or player == null:
		return
	var action := CardAction.new()
	action.type = CardAction.Type.EVENT
	action.source_player = source_card.card_owner if source_card != null and source_card.card_owner != null else player
	action.initial_priority_player = game_manager.get_opponent(action.source_player) if action.source_player != null else null
	action.card = source_card
	action.event_name = event_name
	action.event_speed = source_card.get_effective_speed() if source_card != null else 0
	action.event_data = interaction_data.duplicate(true)
	action.resolve_callback = func() -> void:
		_emit_ui_interaction_for_player(player, interaction_type, interaction_data)
	if not completion_command_type.is_empty():
		_mark_deferred_authoritative_action(action, completion_command_type)
	var remains_on_stack: bool = queue_or_resolve_priority_event(action)
	if not remains_on_stack:
		return

func _emit_local_priority_prompt_if_needed() -> void:
	if game_manager == null or game_manager.priority_player == null:
		return
	if not _pending_ui_interactions.is_empty() or not _queued_ui_interactions.is_empty():
		return
	if _uses_authoritative_headless_priority_flow():
		return
	var priority_idx := game_manager.players.find(game_manager.priority_player)
	if priority_idx < 0:
		return
	request_ui_interaction.emit(
		priority_idx,
		"priority",
		build_priority_prompt_data(game_manager.priority_player)
	)

func _queue_method_priority_event(
	player: Player,
	source_card: Card,
	event_name: String,
	interaction_data: Dictionary
) -> void:
	if game_manager == null or player == null or source_card == null:
		return
	var method_name := str(interaction_data.get("resolve_method", "")).strip_edges()
	if method_name == "" or not source_card.has_method(method_name):
		return
	var action := CardAction.new()
	action.type = CardAction.Type.EVENT
	action.source_player = source_card.card_owner if source_card.card_owner != null else player
	action.initial_priority_player = game_manager.get_opponent(action.source_player) if action.source_player != null else null
	action.card = source_card
	action.event_name = event_name
	action.event_speed = source_card.get_effective_speed()
	if not game_manager.action_stack.is_empty():
		action.response_to = game_manager.action_stack.back()
	action.event_data = interaction_data.duplicate(true)
	action.resolve_callback = func() -> void:
		var result = source_card.call(method_name, game_manager)
		if result is String and str(result).strip_edges() != "":
			game_manager.note_player_feedback(str(result))
	var remains_on_stack := queue_or_resolve_priority_event(action)
	if remains_on_stack:
		_emit_local_priority_prompt_if_needed()

func _should_collect_choice_before_priority(
	interaction_type: String,
	completion_command_type: String,
	source_card: Card = null,
	interaction_data: Dictionary = {}
) -> bool:
	if completion_command_type.strip_edges().is_empty():
		return false
	return _is_reveal_interaction_type(interaction_type) \
		or _is_targeting_choice_prompt(source_card, interaction_data)

func _is_targeting_choice_prompt(source_card: Card, interaction_data: Dictionary) -> bool:
	if source_card == null or not source_card.has_type("Targeting"):
		return false
	return interaction_data.has("target_uids") or interaction_data.has("target_uid")

func _get_priority_after_choice_prompt_data(command: Dictionary) -> Dictionary:
	if _resolving_priority_choice_command:
		return {}
	var command_type := str(command.get("type", "")).strip_edges()
	var expected_type := _get_ui_interaction_type_for_command(command_type)
	if expected_type == "":
		return {}
	var prompt_idx := _find_pending_ui_interaction_index(command, expected_type)
	if prompt_idx < 0:
		return {}
	var entry: Dictionary = _pending_ui_interactions[prompt_idx]
	var data: Dictionary = entry.get("data", {})
	if not bool(data.get("_queue_priority_after_choice", false)):
		return {}
	return data.duplicate(true)

func _queue_choice_command_as_priority_event(command: Dictionary, source_card: Card) -> bool:
	if game_manager == null or source_card == null:
		return false
	var prompt_data := _get_priority_after_choice_prompt_data(command)
	if prompt_data.is_empty():
		return false
	var event_name := str(prompt_data.get("_priority_event_name", "")).strip_edges()
	if event_name == "":
		event_name = _get_ui_interaction_type_for_command(str(command.get("type", "")))
	var completion_command_type := str(prompt_data.get("_priority_completion_command_type", "")).strip_edges()
	if completion_command_type == "":
		return false
	var queued_command := command.duplicate(true)
	var action := CardAction.new()
	action.type = CardAction.Type.EVENT
	action.source_player = source_card.card_owner if source_card.card_owner != null else game_manager.current_player
	action.initial_priority_player = game_manager.get_opponent(action.source_player) if action.source_player != null else null
	action.card = source_card
	action.event_name = event_name
	action.event_speed = source_card.get_effective_speed()
	if not game_manager.action_stack.is_empty():
		action.response_to = game_manager.action_stack.back()
	action.event_data = prompt_data.duplicate(true)
	action.event_data["queued_choice_command"] = queued_command
	var target_uid := _get_command_choice_uid(command)
	if target_uid != "":
		action.target = game_manager.get_card_by_uid(target_uid)
	action.resolve_callback = func() -> void:
		_execute_queued_priority_choice_command(queued_command, action, completion_command_type)
	_mark_deferred_authoritative_action(action, completion_command_type)
	var remains_on_stack := queue_or_resolve_priority_event(
		action,
		_uses_authoritative_headless_priority_flow()
	)
	if not remains_on_stack:
		command["_suppress_full_state_broadcast"] = true
	return true

func _execute_queued_priority_choice_command(command: Dictionary, action: CardAction, completion_command_type: String) -> void:
	var previous_resolving := _resolving_priority_choice_command
	var previous_command_type := _active_command_type
	var previous_pending_prompt_id := _active_command_pending_prompt_id
	var resolution_command := command.duplicate(true)
	resolution_command["_suppress_full_state_broadcast"] = true
	_resolving_priority_choice_command = true
	_active_command_type = str(resolution_command.get("type", "")).strip_edges()
	_active_command_pending_prompt_id = -1
	var resolved := _process_command_impl(resolution_command)
	if not resolved:
		var feedback := last_move_failed_reason.strip_edges()
		if feedback == "":
			feedback = "%s could not resolve." % _active_command_type
		game_manager.note_player_feedback(feedback)
		if action != null:
			action.resolution_text = feedback
			_clear_deferred_authoritative_action_metadata(action)
	elif action != null and _has_deferred_authoritative_action_metadata(action):
		if completion_command_type in HANDLER_COMPLETES_DEFERRED_PRIORITY_CHOICE_COMMANDS:
			pass
		else:
			var pending_graveyard_prompt := _get_pending_authoritative_graveyard_prompt_command_type()
			if pending_graveyard_prompt.is_empty():
				_complete_deferred_authoritative_action(action, completion_command_type)
	_resolving_priority_choice_command = previous_resolving
	_active_command_type = previous_command_type
	_active_command_pending_prompt_id = previous_pending_prompt_id

func _on_game_manager_card_summoned(
	player: Player,
	card: Card,
	_from_zone: Zone,
	to_zone: Zone,
	summon_source: Card,
	face_down: bool,
	stealth: bool
) -> void:
	if game_manager == null or not _uses_authoritative_headless_priority_flow():
		return
	_log_authoritative_flow_state("card_summoned:received player=%s card=%s source=%s face_down=%s stealth=%s" % [
		_get_player_debug_label(player),
		_get_card_debug_label(card),
		_get_card_debug_label(summon_source),
		str(face_down),
		str(stealth),
	])
	if player == null or card == null or to_zone == null:
		return
	if card.card_type not in [Card.CardType.CREATURE, Card.CardType.STRUCTURE]:
		return
	if face_down or stealth or card.is_face_down or card.is_prepared or card.is_stealth:
		return
	if card.current_zone != to_zone or not to_zone.is_board_zone():
		return
	_prune_invalidated_frontline_entry_event(card)
	if card.card_type == Card.CardType.STRUCTURE:
		_maybe_emit_advanced_building_techniques_prompt(player, card)
	if _is_tezcatlipoca_necoc_yaotl_summon(card, summon_source):
		return
	if _has_pending_impact_priority_action(card):
		return
	if _has_pending_event_priority_action(card, "summon"):
		return
	var summon_priority_action := CardAction.new()
	summon_priority_action.type = CardAction.Type.EVENT
	summon_priority_action.source_player = player
	summon_priority_action.initial_priority_player = game_manager.get_opponent(player)
	summon_priority_action.card = card
	summon_priority_action.event_name = "summon"
	summon_priority_action.event_speed = card.get_effective_speed()
	game_manager.push_to_stack(summon_priority_action)
	_log_authoritative_flow_state("card_summoned:pushed_event action=%s active_command=%s" % [
		_get_action_debug_summary(summon_priority_action),
		_active_command_type,
	])
	if _active_command_advances_summon_priority():
		_log_authoritative_flow_state("card_summoned:active_command_will_advance command=%s" % _active_command_type)
		return
	_advance_authoritative_priority_for_pending_card_events(card)

func _prune_invalidated_frontline_entry_event(card: Card) -> void:
	if game_manager == null or card == null:
		return
	for idx in range(game_manager.action_stack.size() - 1, -1, -1):
		var action := game_manager.action_stack[idx] as CardAction
		if action == null \
				or action.type != CardAction.Type.EVENT \
				or action.event_name != "frontline_entry" \
				or action.card != card:
			continue
		# Frontline-entry responses are discovered when the card first moves.
		# Its Impact can then invalidate those responses before card_summoned
		# fires (for example, Dellingr revealing and locking a prepared Sap).
		if game_manager._has_priority_responses_for_action(action) \
				or _action_requires_explicit_priority_window(action):
			return
		game_manager.action_stack.remove_at(idx)
		return

func _maybe_emit_advanced_building_techniques_prompt(player: Player, structure: Card) -> void:
	if game_manager == null or player == null or structure == null:
		return
	if structure.card_type != Card.CardType.STRUCTURE:
		return
	var building_power := _get_active_advanced_building_techniques(player)
	if building_power == null or not building_power.can_offer_structure_bonus(structure, game_manager):
		return
	_emit_ui_interaction_for_player(player, "advanced_building_techniques", {
		"power_uid": building_power.uid,
		"structure_uid": structure.uid,
	})

func _get_active_advanced_building_techniques(player: Player) -> AdvancedBuildingTechniques:
	if player == null:
		return null
	for zone in player.power_zones:
		if zone.cards.is_empty():
			continue
		var power := zone.cards[0] as AdvancedBuildingTechniques
		if power != null and not power.is_face_down:
			return power
	return null

func _is_tezcatlipoca_necoc_yaotl_summon(card: Card, summon_source: Card) -> bool:
	return card != null \
		and summon_source != null \
		and summon_source.card_name == "Tezcatlipoca, the Smoking Mirror" \
		and card.card_name == "Tezcatlipoca, Active God" \
		and card.has_method("get_valid_titlacauan_targets")

func resolve_action(action: CardAction) -> void:
	last_resolution_text = ""
	var pushed_effect_source := false
	var action_completed := true
	var deferred_completion_command_type := ""
	var destroyed_count_before := game_manager.destroyed_this_turn.size() if game_manager != null else 0
	if action != null and not action.event_data.has("destroyed_count_before"):
		action.event_data["destroyed_count_before"] = destroyed_count_before
	if game_manager != null and action != null and action.card != null:
		game_manager.push_effect_source_card(action.card)
		pushed_effect_source = true
	if game_manager != null and action != null:
		game_manager.begin_stack_action_resolution(action)
	match action.type:
		CardAction.Type.ABILITY:
			_resolve_ability(action)
		CardAction.Type.SPELL:
			_resolve_spell(action)
			if _has_deferred_authoritative_action_metadata(action):
				action_completed = false
				deferred_completion_command_type = str(action.event_data.get("deferred_authoritative_completion_command", ""))
		CardAction.Type.CHARM:
			_resolve_spell(action)
			if _has_deferred_authoritative_action_metadata(action):
				action_completed = false
				deferred_completion_command_type = str(action.event_data.get("deferred_authoritative_completion_command", ""))
		CardAction.Type.EVENT:
			_resolve_event(action)
			if _has_deferred_authoritative_action_metadata(action):
				action_completed = false
				deferred_completion_command_type = str(action.event_data.get("deferred_authoritative_completion_command", ""))
		CardAction.Type.ATTACK:
			_resolve_attack(action)
			action_completed = pending_retreat_action != action \
				and pending_humbaba_action != action \
				and pending_combat_reveal_linger_action != action
			if not action_completed:
				if pending_retreat_action == action:
					deferred_completion_command_type = "combat_retreat_decision"
				elif pending_humbaba_action == action:
					deferred_completion_command_type = "humbaba_augury_choice"
				elif pending_combat_reveal_linger_action == action:
					deferred_completion_command_type = "combat_reveal_linger"
	var action_finalized_during_resolution := false
	if game_manager != null and action != null:
		action_finalized_during_resolution = not game_manager.action_stack.has(action) \
			and not game_manager.resolving_stack_actions.has(action)
	if action_completed and game_manager != null:
		deferred_completion_command_type = _get_pending_authoritative_graveyard_prompt_command_type()
		if not deferred_completion_command_type.is_empty():
			action_completed = false
	if game_manager != null and pushed_effect_source:
		game_manager.pop_effect_source_card()
	if action_finalized_during_resolution:
		return
	if not action_completed:
		if not deferred_completion_command_type.is_empty():
			_mark_deferred_authoritative_action(action, deferred_completion_command_type)
		if _uses_authoritative_headless_priority_flow() and not _has_deferred_authoritative_action_metadata(action):
			printerr("MatchManager: paused authoritative action is missing deferred completion metadata: %s" % _get_action_debug_label(action))
		return
	_queue_destroyed_response_events(destroyed_count_before, action)
	_finalize_resolved_action(action)

func _queue_destroyed_response_events(start_index: int, resolved_action: CardAction) -> void:
	if game_manager == null:
		return
	for i in range(maxi(0, start_index), game_manager.destroyed_this_turn.size()):
		var destroyed_card := game_manager.destroyed_this_turn[i]
		if destroyed_card == null or destroyed_card.card_type != Card.CardType.CREATURE:
			continue
		if _has_pending_event_priority_action(destroyed_card, "destroyed"):
			continue
		var destroyed_action := CardAction.new()
		destroyed_action.type = CardAction.Type.EVENT
		destroyed_action.source_player = destroyed_card.card_owner if destroyed_card.card_owner != null else (resolved_action.source_player if resolved_action != null else game_manager.current_player)
		destroyed_action.initial_priority_player = destroyed_card.card_owner
		destroyed_action.card = destroyed_card
		destroyed_action.event_name = "destroyed"
		destroyed_action.event_speed = 0
		destroyed_action.resolution_text = "%s was destroyed." % destroyed_card.card_name
		if game_manager._has_priority_responses_for_action(destroyed_action):
			game_manager.push_to_stack(destroyed_action)

func _finalize_resolved_action(action: CardAction) -> void:
	if game_manager != null and action != null and action.type == CardAction.Type.ATTACK:
		game_manager.note_attack_resolved()
	_remove_resolved_action(action)
	if game_manager != null and action != null:
		game_manager.end_stack_action_resolution(action)
	if game_manager != null:
		game_manager.prune_stale_stack_actions()
	action_resolved.emit(action)
	if _pending_ui_interactions.is_empty() and not _queued_ui_interactions.is_empty():
		_release_next_queued_ui_interaction()
	_continue_authoritative_stack_after_resolution()

func _continue_authoritative_stack_after_resolution() -> void:
	# Keep continuation centralized so direct and deferred resolution paths both drain the stack.
	if not _uses_authoritative_headless_priority_flow():
		return
	if game_manager == null:
		return
	if _has_blocking_stack_resolution_for_continuation():
		return
	_authoritative_stack_resolution_pending = false
	game_manager.prune_stale_stack_actions()
	if game_manager.action_stack.is_empty():
		_clear_priority_window_state()
		if _continue_active_authoritative_turn_start_sequence():
			return
		_try_process_pending_turn_action_after_opponent_priority()
		if game_manager.action_stack.is_empty() \
				and _pending_ui_interactions.is_empty() \
				and _queued_ui_interactions.is_empty():
			call_deferred("_request_ui_refresh")
		return
	if pending_combat_reveal_linger_action != null \
			and game_manager.action_stack.back() == pending_combat_reveal_linger_action:
		_clear_priority_window_state()
		return
	_clear_priority_window_state()
	_advance_authoritative_priority()

func _has_blocking_stack_resolution_for_continuation() -> bool:
	if game_manager == null or game_manager.resolving_stack_actions.is_empty():
		return false
	if pending_combat_reveal_linger_action == null:
		return true
	for resolving_action in game_manager.resolving_stack_actions:
		if resolving_action != pending_combat_reveal_linger_action:
			return true
	if game_manager.action_stack.is_empty():
		return true
	return game_manager.action_stack.back() == pending_combat_reveal_linger_action

func _mark_deferred_authoritative_action(action: CardAction, completion_command_type: String) -> void:
	if action == null:
		return
	action.event_data["deferred_authoritative_completion_command"] = completion_command_type

func _has_deferred_authoritative_action_metadata(action: CardAction) -> bool:
	return action != null and action.event_data.has("deferred_authoritative_completion_command")

func _clear_deferred_authoritative_action_metadata(action: CardAction) -> void:
	if action == null:
		return
	action.event_data.erase("deferred_authoritative_completion_command")

func _get_action_debug_label(action: CardAction) -> String:
	if action == null:
		return "<null action>"
	if action.card != null:
		return "%s uid=%s type=%s" % [action.card.card_name, str(action.card.uid), str(action.type)]
	if action.event_name != "":
		return "%s type=%s" % [action.event_name, str(action.type)]
	return "type=%s" % str(action.type)

func _get_player_debug_label(player: Player) -> String:
	if player == null:
		return "<none>"
	var player_idx := game_manager.players.find(player) if game_manager != null else -1
	return "%s[%d]" % [player.player_name, player_idx]

func _get_card_debug_label(card: Card) -> String:
	if card == null:
		return "<none>"
	var zone_label := "no-zone"
	if card.current_zone != null:
		zone_label = "%s:%d" % [str(card.current_zone.zone_type), int(card.current_zone.zone_index)]
	return "%s(uid=%s owner=%s zone=%s)" % [
		card.card_name,
		str(card.uid),
		_get_player_debug_label(card.get_controller()),
		zone_label,
	]

func _get_target_debug_label(target) -> String:
	if target is Card:
		return _get_card_debug_label(target as Card)
	if target is Player:
		return _get_player_debug_label(target as Player)
	if target == null:
		return "<none>"
	return str(target)

func _get_action_debug_summary(action: CardAction) -> String:
	if action == null:
		return "<null>"
	var type_names := CardAction.Type.keys()
	var type_label := str(action.type)
	if int(action.type) >= 0 and int(action.type) < type_names.size():
		type_label = str(type_names[int(action.type)])
	var parts: Array[String] = []
	parts.append("type=%s" % type_label)
	if action.event_name != "":
		parts.append("event=%s" % action.event_name)
	if action.card != null:
		parts.append("card=%s" % _get_card_debug_label(action.card))
	if action.attacker != null:
		parts.append("attacker=%s" % _get_card_debug_label(action.attacker))
	if action.united_front_partner != null:
		parts.append("partner=%s" % _get_card_debug_label(action.united_front_partner))
	if action.interceptor != null:
		parts.append("interceptor=%s" % _get_card_debug_label(action.interceptor))
	if action.target != null:
		parts.append("target=%s" % _get_target_debug_label(action.target))
	parts.append("source=%s" % _get_player_debug_label(action.source_player))
	parts.append("initial_priority=%s" % _get_player_debug_label(action.initial_priority_player))
	if action.event_data.has("deferred_authoritative_completion_command"):
		parts.append("deferred=%s" % str(action.event_data.get("deferred_authoritative_completion_command", "")))
	return " ".join(parts)

func _get_pending_ui_debug_summary(limit: int = 5) -> String:
	if _pending_ui_interactions.is_empty():
		return "<none>"
	var items: Array[String] = []
	var start_idx := maxi(0, _pending_ui_interactions.size() - limit)
	for idx in range(start_idx, _pending_ui_interactions.size()):
		var entry: Dictionary = _pending_ui_interactions[idx]
		var data: Dictionary = entry.get("data", {})
		var prompt_player := entry.get("player", null) as Player
		items.append("#%d %s player=%s source=%s target=%s target_uids=%s" % [
			int(entry.get("prompt_id", -1)),
			str(entry.get("type", "")),
			_get_player_debug_label(prompt_player),
			str(data.get("source_uid", "")),
			str(data.get("target_uid", "")),
			str(data.get("target_uids", [])),
		])
	return "; ".join(items)

func _has_pending_reveal_target_ui_interaction() -> bool:
	for entry in _pending_ui_interactions:
		var interaction_type := str(entry.get("type", ""))
		if _is_reveal_interaction_type(interaction_type):
			return true
	return false

func get_pending_reveal_target_ui_interactions() -> Array[Dictionary]:
	var interactions: Array[Dictionary] = []
	for entry in _pending_ui_interactions:
		var interaction_type := str(entry.get("type", ""))
		if not _is_reveal_interaction_type(interaction_type):
			continue
		interactions.append(entry.duplicate(true))
	return interactions

func get_pending_state_refresh_ui_interactions() -> Array[Dictionary]:
	var interactions: Array[Dictionary] = []
	for entry in _pending_ui_interactions:
		var interaction_type := str(entry.get("type", ""))
		var interaction_data: Dictionary = entry.get("data", {})
		if not _is_state_refresh_ui_interaction(interaction_type, interaction_data):
			continue
		var serialized_entry := entry.duplicate(true)
		var serialized_data := interaction_data.duplicate(true)
		serialized_data["_prompt_id"] = int(entry.get("prompt_id", -1))
		serialized_entry["data"] = serialized_data
		interactions.append(serialized_entry)
	return interactions

func get_pending_priority_prompt_data(player: Player) -> Dictionary:
	if player == null:
		return {}
	for entry in _pending_ui_interactions:
		if entry.get("player", null) != player or str(entry.get("type", "")) != "priority":
			continue
		var prompt_data: Dictionary = entry.get("data", {})
		var serialized_prompt_data := prompt_data.duplicate(true)
		serialized_prompt_data["_prompt_id"] = int(entry.get("prompt_id", -1))
		return serialized_prompt_data
	return {}

func _is_reveal_interaction_type(interaction_type: String) -> bool:
	return interaction_type.strip_edges().to_lower().contains("reveal")

func _is_state_refresh_ui_interaction(interaction_type: String, interaction_data: Dictionary = {}) -> bool:
	return _is_reveal_interaction_type(interaction_type) \
		or interaction_type.strip_edges() == "priority" \
		or interaction_type.strip_edges() == "huginn_perish_prime" \
		or interaction_type.strip_edges() == "muninn_perish_prime" \
		or interaction_type.strip_edges() == "nusku_well_of_fire" \
		or bool(interaction_data.get("_queue_priority_after_choice", false))

func _log_authoritative_flow_state(context: String) -> void:
	if game_manager == null or not _uses_authoritative_headless_priority_flow():
		return
	print("%s %s turn=%d current=%s priority=%s passes=%d stack=%d resolving=%d pending_resolution=%s pending_ui=%d" % [
		AUTHORITATIVE_FLOW_LOG_PREFIX,
		context,
		game_manager.turn_number,
		_get_player_debug_label(game_manager.current_player),
		_get_player_debug_label(game_manager.priority_player),
		game_manager.consecutive_passes,
		game_manager.action_stack.size(),
		game_manager.resolving_stack_actions.size(),
		str(_authoritative_stack_resolution_pending),
		_pending_ui_interactions.size(),
	])
	for idx in range(game_manager.action_stack.size()):
		print("%s   stack[%d] %s" % [
			AUTHORITATIVE_FLOW_LOG_PREFIX,
			idx,
			_get_action_debug_summary(game_manager.action_stack[idx]),
		])
	for idx in range(game_manager.resolving_stack_actions.size()):
		print("%s   resolving[%d] %s" % [
			AUTHORITATIVE_FLOW_LOG_PREFIX,
			idx,
			_get_action_debug_summary(game_manager.resolving_stack_actions[idx]),
		])
	if pending_humbaba_action != null:
		print("%s   pending_humbaba action=%s target=%s prompts=%s" % [
			AUTHORITATIVE_FLOW_LOG_PREFIX,
			_get_action_debug_summary(pending_humbaba_action),
			_get_target_debug_label(pending_humbaba_target),
			str(pending_humbaba_prompt_uids),
		])
	if pending_retreat_action != null:
		print("%s   pending_retreat action=%s target=%s prompts=%s" % [
			AUTHORITATIVE_FLOW_LOG_PREFIX,
			_get_action_debug_summary(pending_retreat_action),
			_get_target_debug_label(pending_retreat_target),
			str(pending_retreat_prompt_uids),
		])
	print("%s   pending_ui %s" % [
		AUTHORITATIVE_FLOW_LOG_PREFIX,
		_get_pending_ui_debug_summary(),
	])

func _log_authoritative_flow_checkpoint(context: String, action: CardAction = null, target = null) -> void:
	if game_manager == null or not _uses_authoritative_headless_priority_flow():
		return
	print("%s checkpoint=%s action=%s target=%s stack=%d resolving=%d pending_resolution=%s pending_humbaba=%s priority=%s pending_ui=%d" % [
		AUTHORITATIVE_FLOW_LOG_PREFIX,
		context,
		_get_action_debug_label(action),
		_get_target_debug_label(target),
		game_manager.action_stack.size(),
		game_manager.resolving_stack_actions.size(),
		str(_authoritative_stack_resolution_pending),
		str(pending_humbaba_action != null),
		_get_player_debug_label(game_manager.priority_player),
		_pending_ui_interactions.size(),
	])

func _schedule_authoritative_deferred_action_check(context: String, action: CardAction, target = null) -> void:
	if game_manager == null or not _uses_authoritative_headless_priority_flow():
		return
	var tree = _get_authoritative_resolution_tree()
	if tree == null:
		_check_authoritative_deferred_action_cleared(context, action, target)
		return
	tree.create_timer(AUTHORITATIVE_FLOW_CHECK_DELAY_SECONDS).timeout.connect(
		func() -> void:
			_check_authoritative_deferred_action_cleared(context, action, target),
		CONNECT_ONE_SHOT
	)

func _check_authoritative_deferred_action_cleared(context: String, action: CardAction, target = null) -> void:
	if game_manager == null or not _uses_authoritative_headless_priority_flow():
		return
	var action_still_present := action != null \
		and (game_manager.action_stack.has(action) or action in game_manager.resolving_stack_actions)
	var still_waiting_on_prompt := action != null \
		and (
			pending_humbaba_action == action
			or pending_retreat_action == action
			or pending_combat_reveal_linger_action == action
		)
	var follower_attack_left_stack_locked := target is Player and not game_manager.action_stack.is_empty()
	if action_still_present or still_waiting_on_prompt or follower_attack_left_stack_locked:
		_log_authoritative_flow_state("%s unresolved after %.1fs" % [
			context,
			AUTHORITATIVE_FLOW_CHECK_DELAY_SECONDS,
		])
		return
	_log_authoritative_flow_checkpoint("%s clear after %.1fs" % [
		context,
		AUTHORITATIVE_FLOW_CHECK_DELAY_SECONDS,
	], action, target)

func _complete_deferred_authoritative_action(action: CardAction, completion_command_type: String) -> void:
	if action == null:
		return
	_log_authoritative_flow_state("deferred_complete:start command=%s action=%s" % [
		completion_command_type,
		_get_action_debug_summary(action),
	])
	var expected_command_type := str(action.event_data.get("deferred_authoritative_completion_command", "")).strip_edges()
	if expected_command_type.is_empty():
		printerr("MatchManager: deferred authoritative action completed without stored metadata: %s" % _get_action_debug_label(action))
	elif not completion_command_type.is_empty() and completion_command_type != expected_command_type:
		printerr("MatchManager: deferred authoritative action completed via %s but expected %s for %s" % [
			completion_command_type,
			expected_command_type,
			_get_action_debug_label(action),
		])
	var completed_command_type := completion_command_type.strip_edges()
	if completed_command_type.is_empty():
		completed_command_type = expected_command_type
	action.event_data["defer_resolved_state_broadcast_until_settled"] = true
	var consumed_prompt := _consume_active_command_prompt_for_completion(completed_command_type)
	_log_authoritative_flow_state("deferred_complete:prompt command=%s consumed=%s expected=%s" % [
		completed_command_type,
		str(consumed_prompt),
		expected_command_type,
	])
	_clear_deferred_authoritative_action_metadata(action)
	var destroyed_start_index := int(action.event_data.get("destroyed_count_before", game_manager.destroyed_this_turn.size() if game_manager != null else 0))
	_queue_destroyed_response_events(destroyed_start_index, action)
	_finalize_resolved_action(action)
	var drained := _try_drain_authoritative_event_stack_without_prompt()
	_log_authoritative_flow_state("deferred_complete:after_drain command=%s drained=%s" % [
		completed_command_type,
		str(drained),
	])
	_schedule_authoritative_settled_state_refresh()

func _schedule_authoritative_settled_state_refresh() -> void:
	if not _uses_authoritative_headless_priority_flow():
		return
	_log_authoritative_flow_state("settled_refresh:schedule")
	var tree = _get_authoritative_resolution_tree()
	if tree == null:
		call_deferred("_request_authoritative_settled_state_refresh")
		return
	tree.create_timer(AUTHORITATIVE_SETTLED_REFRESH_DELAY_SECONDS).timeout.connect(
		func() -> void:
			_request_authoritative_settled_state_refresh(),
		CONNECT_ONE_SHOT
	)

func _request_authoritative_settled_state_refresh() -> void:
	if game_manager == null or not _uses_authoritative_headless_priority_flow():
		return
	_log_authoritative_flow_state("settled_refresh:run_before_resume")
	_resume_authoritative_flow_after_prompt_command()
	var drained := _try_drain_authoritative_event_stack_without_prompt()
	_log_authoritative_flow_state("settled_refresh:run_after_drain drained=%s" % str(drained))
	call_deferred("_request_ui_refresh")

func _try_drain_authoritative_event_stack_without_prompt(max_steps: int = 16) -> bool:
	if game_manager == null or not _uses_authoritative_headless_priority_flow():
		return false
	_log_authoritative_flow_state("event_drain:start max_steps=%d" % max_steps)
	var drained := false
	for _step in range(max_steps):
		_prune_stale_ui_interactions_for_current_turn()
		if _authoritative_stack_resolution_pending \
				or not _pending_ui_interactions.is_empty() \
				or not _queued_ui_interactions.is_empty() \
				or not game_manager.resolving_stack_actions.is_empty():
			_log_authoritative_flow_state("event_drain:blocked step=%d drained=%s" % [
				_step,
				str(drained),
			])
			return drained
		game_manager.prune_stale_stack_actions()
		if game_manager.action_stack.is_empty():
			_clear_priority_window_state()
			_log_authoritative_flow_state("event_drain:empty step=%d drained=%s" % [
				_step,
				str(drained),
			])
			return drained
		var top_action := game_manager.action_stack.back() as CardAction
		if top_action == null or top_action.type != CardAction.Type.EVENT:
			_log_authoritative_flow_state("event_drain:non_event step=%d top=%s drained=%s" % [
				_step,
				_get_action_debug_summary(top_action),
				str(drained),
			])
			return drained
		if not _can_resolve_top_stack_action_now():
			_log_authoritative_flow_state("event_drain:needs_priority step=%d top=%s" % [
				_step,
				_get_action_debug_summary(top_action),
			])
			_advance_authoritative_priority()
			return drained
		_clear_priority_window_state()
		_log_authoritative_flow_state("event_drain:resolve step=%d top=%s" % [
			_step,
			_get_action_debug_summary(top_action),
		])
		resolve_action(top_action)
		drained = true
	_log_authoritative_flow_state("event_drain:max_steps_exhausted drained=%s" % str(drained))
	return drained

func _get_pending_authoritative_graveyard_prompt_command_type() -> String:
	if game_manager == null:
		return ""
	if game_manager.has_pending_doorway_choice():
		return "doorway_choice"
	if game_manager.has_pending_return_to_hand_choice():
		return "return_to_hand_choice"
	return ""

func _find_pending_deferred_authoritative_action(command_types: Array[String]) -> CardAction:
	if game_manager == null:
		return null
	for i in range(game_manager.action_stack.size() - 1, -1, -1):
		var action := game_manager.action_stack[i]
		if action == null:
			continue
		var expected_command_type := str(action.event_data.get("deferred_authoritative_completion_command", "")).strip_edges()
		if expected_command_type in command_types:
			return action
	return null

func _find_pending_deferred_action_for_source(command_type: String, source_card: Card) -> CardAction:
	if game_manager == null or source_card == null:
		return null
	for i in range(game_manager.action_stack.size() - 1, -1, -1):
		var action := game_manager.action_stack[i]
		if action == null or action.card != source_card:
			continue
		if str(action.event_data.get("deferred_authoritative_completion_command", "")).strip_edges() == command_type:
			return action
	for i in range(game_manager.resolving_stack_actions.size() - 1, -1, -1):
		var action := game_manager.resolving_stack_actions[i]
		if action == null or action.card != source_card:
			continue
		if str(action.event_data.get("deferred_authoritative_completion_command", "")).strip_edges() == command_type:
			return action
	return null

func _complete_deferred_prompt_action(
	command_type: String,
	source_card: Card,
	feedback_text: String = "",
	consume_pending_feedback: bool = true
) -> bool:
	if game_manager == null or source_card == null or command_type.strip_edges() == "":
		return false
	var pending_action := _find_pending_deferred_action_for_source(command_type, source_card)
	if pending_action == null:
		return false
	var resolved_feedback := feedback_text.strip_edges()
	if resolved_feedback == "" and consume_pending_feedback:
		resolved_feedback = game_manager.consume_player_feedback().strip_edges()
	if resolved_feedback != "":
		pending_action.resolution_text = resolved_feedback
		last_resolution_text = resolved_feedback
	_complete_deferred_authoritative_action(pending_action, command_type)
	return true

func _complete_simple_deferred_prompt_action_for_command(command: Dictionary) -> bool:
	var command_type := str(command.get("type", "")).strip_edges()
	if command_type not in SIMPLE_DEFERRED_PROMPT_COMPLETION_COMMANDS:
		return false
	var source_uid := str(command.get("source_uid", "")).strip_edges()
	if source_uid == "" or game_manager == null:
		return false
	var source_card := game_manager.get_card_by_uid(source_uid)
	return _complete_deferred_prompt_action(command_type, source_card)

func _complete_deferred_prompt_action_or_note(command_type: String, source_card: Card, feedback_text: String) -> void:
	if not _complete_deferred_prompt_action(command_type, source_card, feedback_text, false) \
			and game_manager != null \
			and feedback_text.strip_edges() != "":
		game_manager.note_player_feedback(feedback_text)

func _continue_pending_authoritative_graveyard_prompt_action() -> void:
	var action := _find_pending_deferred_authoritative_action(["doorway_choice", "return_to_hand_choice"])
	if action == null:
		return
	var pending_command_type := _get_pending_authoritative_graveyard_prompt_command_type()
	if not pending_command_type.is_empty():
		_mark_deferred_authoritative_action(action, pending_command_type)
		return
	var completion_command_type := str(action.event_data.get("deferred_authoritative_completion_command", "")).strip_edges()
	_complete_deferred_authoritative_action(action, completion_command_type)

func _remove_resolved_action(action: CardAction) -> void:
	if action == null or game_manager == null:
		return
	game_manager.action_stack.erase(action)

func _resolve_ability(action: CardAction) -> void:
	if action.card is HexCard:
		var hex := action.card as HexCard
		if hex.has_method("on_activate_action"):
			hex.on_activate_action(game_manager, action)
			last_resolution_text = action.resolution_text if action.resolution_text != "" else hex.card_name + " resolved!"
		else:
			var def_card: Card = action.interceptor if action.interceptor != null else (action.target if action.target is Card else null)
			game_manager.activate_hex(hex, action.attacker, def_card)
			if game_manager.last_hex_resolution_text != "":
				last_resolution_text = game_manager.last_hex_resolution_text
			else:
				last_resolution_text = hex.card_name + " triggered!"
	elif action.resolve_callback.is_valid():
		action.resolve_callback.call()
		var feedback := game_manager.consume_player_feedback() if game_manager != null else ""
		if feedback.strip_edges() != "" and action.card != null:
			feedback = action.card.format_named_ability_log_message(
				feedback,
				str(action.event_data.get("ability_trigger_hint", "activated"))
			)
		last_resolution_text = feedback if feedback.strip_edges() != "" else (action.resolution_text if action.resolution_text != "" else action.card.card_name + " resolved!")

func _resolve_spell(action: CardAction) -> void:
	if action.resolve_callback.is_valid():
		action.resolve_callback.call()
		var feedback := game_manager.consume_player_feedback() if game_manager != null else ""
		last_resolution_text = feedback if feedback.strip_edges() != "" else (action.resolution_text if action.resolution_text != "" else action.card.card_name + " resolved!")

func _resolve_event(action: CardAction) -> void:
	if action.resolve_callback.is_valid():
		action.resolve_callback.call()
	var feedback := game_manager.consume_player_feedback() if game_manager != null else ""
	if feedback.strip_edges() != "":
		if action.card != null and action.event_name == "summon":
			feedback = action.card.format_named_ability_log_message(feedback, "impact")
		last_resolution_text = feedback
		return
	if action.resolution_text != "":
		last_resolution_text = action.resolution_text
		return
	if _has_deferred_authoritative_action_metadata(action):
		last_resolution_text = ""
		return
	if action.event_name == "summon" and action.card != null:
		last_resolution_text = "%s was summoned." % action.card.card_name
		return
	last_resolution_text = action.event_name.replace("_", " ").capitalize() + " passed."

func _resolve_attack(action: CardAction) -> void:
	if action.attacker == null:
		return

	game_manager.current_phase = GameManager.GamePhase.COMBAT
	var actual_target = action.interceptor if action.interceptor != null else action.target
	var attacker_can_continue := _can_continue_declared_attack(action.attacker)
	var partner_can_continue := _can_continue_declared_attack(action.united_front_partner)

	if not attacker_can_continue and not partner_can_continue:
		if actual_target is Card:
			game_manager._clear_combat_engagement_state(actual_target)
		last_resolution_text = action.attacker.card_name + "'s attack fizzles — attacker is no longer on the frontline."
		return

	if actual_target is Card and actual_target.current_zone != null and actual_target.current_zone.is_board_zone():
		if attacker_can_continue:
			game_manager._begin_declared_combat(action.attacker, actual_target)
		if partner_can_continue:
			game_manager._begin_declared_combat(action.united_front_partner, actual_target)

	if attacker_can_continue:
		action.attacker.mark_attacked_this_turn()

	if actual_target is Card:
		# If the target left the board before the attack resolved (e.g. Gungnir destroyed it),
		# the attack fizzles — attacker still spends their action.
		if actual_target.current_zone == null or not actual_target.current_zone.is_board_zone():
			action.attacker.spend_attack_creature_action()
			game_manager._clear_combat_engagement_state(actual_target)
			last_resolution_text = action.attacker.card_name + "'s attack fizzles — target is no longer on the board."
			return
		# Check for Askelladen Tactical Retreat prompts.
		# If any combatant can retreat, delegate to the UI for the interactive prompt.
		# Otherwise, resolve headlessly so the server can handle networked combat.
		var retreat_prompts := _get_retreat_candidates(action.attacker, actual_target, action.source_player)
		if not retreat_prompts.is_empty():
			pending_retreat_action = action
			pending_retreat_target = actual_target
			pending_retreat_prompt_uids.clear()
			for prompt in retreat_prompts:
				if prompt != null:
					pending_retreat_prompt_uids.append(str(prompt.uid))
			pending_retreat_guardian_blocked_uids = _get_guardian_blocked_retreat_candidate_uids(action.attacker, actual_target)
			_mark_deferred_authoritative_action(
				action,
				"combat_retreat_decision"
			)
			var target_player: Player = _get_card_controller(retreat_prompts[0])
			_emit_ui_interaction_for_player(target_player, "combat_retreat", {
				"action": action,
				"target": actual_target,
				"askelladen_uid": str(retreat_prompts[0].uid),
			})
			return
		pending_humbaba_action = action
		pending_humbaba_target = actual_target
		pending_humbaba_prompt_uids = _get_humbaba_prompt_uids_for_attack(action, actual_target)
		_mark_deferred_authoritative_action(
			action,
			"humbaba_augury_choice"
		)
		if _emit_next_pending_humbaba_prompt():
			return
		_clear_pending_humbaba_state()
		# No retreat possible - resolve directly.
		_finish_creature_combat(action, actual_target)
		return
	elif actual_target is Player:
		pending_humbaba_action = action
		pending_humbaba_target = actual_target
		pending_humbaba_prompt_uids = _get_humbaba_prompt_uids_for_attack(action, actual_target)
		_mark_deferred_authoritative_action(
			action,
			"humbaba_augury_choice"
		)
		if _emit_next_pending_humbaba_prompt():
			return
		_clear_pending_humbaba_state()
		_finish_followers_attack(action, actual_target)

func _finish_followers_attack(action: CardAction, defending_player: Player) -> void:
	if action == null or defending_player == null:
		return
	var active_attackers := _get_active_attackers(action)
	if active_attackers.is_empty():
		return
	for combatant in active_attackers:
		combatant.spend_attack_creature_action()
		combatant.mark_attacked_this_turn()
	game_manager.set_temporary_combat_follower_damage_halved(action.halve_follower_damage)
	var follower_damage := game_manager.resolve_followers_attack(active_attackers, defending_player)
	game_manager.set_temporary_combat_follower_damage_halved(false)
	last_resolution_text = "%s attacks %s's followers for %d!" % [
		action.attacker.card_name,
		defending_player.player_name,
		follower_damage
	]

## Headless combat resolution (no retreat dialog needed).
## Called by _resolve_attack when no Askelladen can retreat.
func _finish_creature_combat(action: CardAction, target: Card) -> void:
	if _begin_combat_reveal_linger(action, target):
		return
	_resolve_creature_combat_now(action, target)

func _begin_combat_reveal_linger(action: CardAction, target: Card) -> bool:
	if action == null or target == null or pending_combat_reveal_linger_action != null:
		return false

	var reveal_cards: Array[Card] = []
	for combatant in [action.attacker, action.united_front_partner, target]:
		if combatant != null and combatant.is_stealth:
			reveal_cards.append(combatant)

	if reveal_cards.is_empty():
		return false

	var tree = _get_authoritative_resolution_tree()
	if tree == null:
		return false

	pending_combat_reveal_linger_action = action
	_mark_deferred_authoritative_action(action, "combat_reveal_linger")

	for combatant in reveal_cards:
		combatant.reveal_from_stealth(game_manager)

	if action.united_front_partner == null:
		game_manager.capture_committed_combat_snapshot(action.attacker, target)

	last_resolution_text = "%s revealed before combat." % _format_card_name_list(reveal_cards)
	_request_ui_refresh()

	_combat_reveal_wait_generation += 1
	_wait_for_combat_reveal_interactions_then_resume(action, target, _combat_reveal_wait_generation)

	return true

func _wait_for_combat_reveal_interactions_then_resume(action: CardAction, target: Card, wait_generation: int) -> void:
	var tree = _get_authoritative_resolution_tree()

	if pending_combat_reveal_linger_action != action or wait_generation != _combat_reveal_wait_generation:
		return

	if tree == null:
		if not _has_pending_combat_reveal_interaction(action):
			_resume_pending_combat_reveal(action, target)
		return

	tree.create_timer(AUTHORITATIVE_STACK_ACTION_LINGER_SECONDS).timeout.connect(
		func() -> void:
			if pending_combat_reveal_linger_action != action or wait_generation != _combat_reveal_wait_generation:
				return

			if _has_pending_combat_reveal_interaction(action):
				_wait_for_combat_reveal_interactions_then_resume(action, target, wait_generation)
				return

			_resume_pending_combat_reveal(action, target),
		CONNECT_ONE_SHOT
	)

func _has_pending_combat_reveal_interaction(action: CardAction) -> bool:
	if action == null or game_manager == null:
		return false
	for stack_action in game_manager.action_stack:
		if stack_action != null and stack_action != action:
			return true
	var combatant_uids: Array[String] = []
	for combatant in [action.attacker, action.united_front_partner, action.target, action.interceptor]:
		if combatant is Card and combatant.uid not in combatant_uids:
			combatant_uids.append(combatant.uid)
	for stack_action in game_manager.action_stack:
		if stack_action == null or not (stack_action is CardAction):
			continue
		var typed_action := stack_action as CardAction
		if typed_action.type != CardAction.Type.EVENT:
			continue
		if not _is_reveal_event_name(typed_action.event_name):
			continue
		if typed_action.card != null and typed_action.card.uid in combatant_uids:
			return true
	for entry in _pending_ui_interactions:
		var interaction_type := str(entry.get("type", ""))
		if not _is_reveal_interaction_type(interaction_type):
			continue
		var data: Dictionary = entry.get("data", {})
		if str(data.get("source_uid", "")) in combatant_uids:
			return true
	return false

func _is_reveal_event_name(event_name: String) -> bool:
	return event_name.strip_edges().to_lower().contains("reveal")

func _resume_pending_combat_reveal(action: CardAction, target: Card) -> void:
	if action == null or target == null or pending_combat_reveal_linger_action != action:
		return
	pending_combat_reveal_linger_action = null
	_combat_reveal_wait_generation += 1
	_resolve_creature_combat_now(
		action,
		target,
		func() -> void:
			_complete_deferred_authoritative_action(action, "combat_reveal_linger")
	)

func _resume_combat_reveal_after_source_choice(source_card: Card) -> void:
	var action := pending_combat_reveal_linger_action
	if action == null or source_card == null:
		return
	var target: Card = action.interceptor if action.interceptor != null else action.target as Card
	if not (target is Card):
		return
	if source_card not in [action.attacker, action.united_front_partner, target]:
		return
	_resume_pending_combat_reveal(action, target)

func _format_card_name_list(cards: Array[Card]) -> String:
	var names: Array[String] = []
	for card in cards:
		if card != null:
			names.append(card.card_name)
	if names.size() <= 1:
		return names[0] if not names.is_empty() else "A card"
	if names.size() == 2:
		return "%s and %s" % [names[0], names[1]]
	return "%s, and %s" % [", ".join(names.slice(0, names.size() - 1)), names.back()]

func _resolve_creature_combat_now(
	action: CardAction,
	target: Card,
	completion_callback: Callable = Callable()
) -> void:
	var attacker := action.attacker
	var partner := action.united_front_partner
	var has_committed_snapshot := partner == null \
		and game_manager.has_committed_combat_snapshot(attacker, target)

	var finish := func() -> void:
		var active: Array[Card] = []
		if partner != null:
			active = game_manager._get_active_united_front_attackers(attacker, partner)
		elif attacker.current_zone != null and attacker.current_zone.is_board_zone():
			active = [attacker]
		for combatant in active:
			combatant.spend_attack_creature_action()
			combatant.mark_attacked_this_turn()
		var combat_text := ""
		if active.size() >= 2:
			combat_text = active[0].card_name + " and " + active[1].card_name + " fought " + target.card_name + "!"
		elif not active.is_empty():
			combat_text = active[0].card_name + " fought " + target.card_name + "!"
		if action.interceptor != null and not combat_text.is_empty():
			last_resolution_text = "%s intercepted %s. %s" % [
				target.card_name,
				_format_card_name_list(active),
				combat_text,
			]
		else:
			last_resolution_text = combat_text
		if completion_callback.is_valid():
			completion_callback.call()

	if not has_committed_snapshot and (target.current_zone == null or not target.current_zone.is_board_zone()):
		last_resolution_text = attacker.card_name + "'s attack fizzles - target is no longer on the board."
		if completion_callback.is_valid():
			completion_callback.call()
		return
	var attacker_on_board := attacker != null \
		and _can_continue_declared_attack(attacker)
	var partner_on_board := partner != null \
		and _can_continue_declared_attack(partner)
	if not has_committed_snapshot and not attacker_on_board and not partner_on_board:
		last_resolution_text = "The attack fizzles - no attacker remains on the frontline."
		if completion_callback.is_valid():
			completion_callback.call()
		return
		
	if partner != null:
		game_manager.set_temporary_combat_follower_damage_halved(action.halve_follower_damage)
		game_manager.resolve_united_front_combat(attacker, partner, target)
		game_manager.set_temporary_combat_follower_damage_halved(false)
		finish.call()
	else:
		game_manager.set_temporary_combat_follower_damage_halved(action.halve_follower_damage)
		var wrapped_finish := func() -> void:
			game_manager.set_temporary_combat_follower_damage_halved(false)
			finish.call()
		if action.interceptor != null:
			game_manager.record_interception(action.interceptor)
		game_manager.resolve_combat_with_continuation(attacker, target, wrapped_finish, action.interceptor != null)

func _is_attacker_still_on_frontline(attacker: Card) -> bool:
	return attacker != null \
		and attacker.current_zone != null \
		and attacker.current_zone.zone_type == Zone.ZoneType.FRONTLINE

func _can_continue_declared_attack(attacker: Card) -> bool:
	return _is_attacker_still_on_frontline(attacker) \
		and attacker.creature_mode == Card.CreatureMode.AGGRESSIVE

## Returns any Askelladen cards in the combat that qualify for Tactical Retreat.
func _get_retreat_candidates(attacker: Card, defender: Card, _turn_player: Player) -> Array:
	var candidates: Array = []
	for card in [attacker, defender]:
		if not (card is Askelladen):
			continue
		var other: Card = defender if card == attacker else attacker
		var ask := card as Askelladen
		if ask.is_face_down or ask.abilities_suppressed():
			continue
		if game_manager.is_immune_to_source(other, ask):
			continue
		if other.get_effective_speed() > ask.get_effective_speed():
			continue
		if not game_manager.is_guardian_protected(other, ask):
			candidates.append(ask)
	return candidates

func _get_guardian_blocked_retreat_candidate_uids(attacker: Card, defender: Card) -> Array[String]:
	var blocked: Array[String] = []
	for card in [attacker, defender]:
		if not (card is Askelladen):
			continue
		var other: Card = defender if card == attacker else attacker
		var ask := card as Askelladen
		if ask.is_face_down or ask.abilities_suppressed():
			continue
		if game_manager.is_immune_to_source(other, ask):
			continue
		if other.get_effective_speed() > ask.get_effective_speed():
			continue
		if game_manager.is_guardian_protected(other, ask):
			blocked.append(str(ask.uid))
	return blocked

func _get_humbaba_prompt_uids_for_attack(action: CardAction, actual_target) -> Array[String]:
	var prompt_uids: Array[String] = []
	if action == null:
		return prompt_uids
	for combatant in _get_active_attackers(action):
		var humbaba := combatant as HumbabaTheTerrible
		if humbaba == null:
			continue
		var humbaba_uid := str(humbaba.uid)
		if humbaba_uid != "" and humbaba_uid not in prompt_uids:
			prompt_uids.append(humbaba_uid)
	if actual_target is Card:
		var defending_humbaba := actual_target as HumbabaTheTerrible
		if defending_humbaba != null:
			var defending_uid := str(defending_humbaba.uid)
			if defending_uid != "" and defending_uid not in prompt_uids:
				prompt_uids.append(defending_uid)
	return prompt_uids

func _get_pending_humbaba_prompt() -> HumbabaTheTerrible:
	if pending_humbaba_prompt_uids.is_empty():
		return null
	return game_manager.get_card_by_uid(str(pending_humbaba_prompt_uids[0])) as HumbabaTheTerrible

func _emit_next_pending_humbaba_prompt() -> bool:
	if game_manager == null:
		return false
	while not pending_humbaba_prompt_uids.is_empty():
		var humbaba := _get_pending_humbaba_prompt()
		if humbaba == null:
			pending_humbaba_prompt_uids.remove_at(0)
			continue
		if humbaba.abilities_suppressed_by_effects():
			pending_humbaba_prompt_uids.remove_at(0)
			continue
		humbaba.queue_augury_trigger_suppression()
		var prompt_targets := humbaba.get_augury_cards(game_manager)
		if prompt_targets.is_empty():
			_pause_pending_humbaba_after_auto_resolution("%s found no cards to read." % humbaba.card_name)
			pending_humbaba_prompt_uids.remove_at(0)
			return true
		var prompt_player := game_manager.get_opponent(humbaba.get_controller())
		if prompt_player == null:
			_pause_pending_humbaba_after_auto_resolution(humbaba.resolve_augury_reading(game_manager, prompt_targets[0]))
			pending_humbaba_prompt_uids.remove_at(0)
			return true
		var player_idx := game_manager.players.find(prompt_player)
		if player_idx < 0:
			_pause_pending_humbaba_after_auto_resolution(humbaba.resolve_augury_reading(game_manager, prompt_targets[0]))
			pending_humbaba_prompt_uids.remove_at(0)
			return true
		var target_uids: Array[String] = []
		for target in prompt_targets:
			if target != null:
				target_uids.append(target.uid)
		_emit_ui_interaction_for_player(prompt_player, "humbaba_augury", {
			"source_uid": humbaba.uid,
			"target_uids": target_uids,
		})
		return true
	return false

func _pause_pending_humbaba_after_auto_resolution(feedback: String) -> void:
	if game_manager == null:
		return
	var resolved_feedback := feedback.strip_edges()
	if resolved_feedback != "":
		game_manager.note_player_feedback(resolved_feedback)
		last_resolution_text = resolved_feedback
		_request_ui_refresh()
	_schedule_pending_humbaba_auto_resume()

func _schedule_pending_humbaba_auto_resume() -> void:
	var action := pending_humbaba_action
	var target = pending_humbaba_target
	var tree = _get_authoritative_resolution_tree()
	if tree == null:
		call_deferred("_resume_pending_humbaba_after_auto_resolution", action, target)
		return
	tree.create_timer(AUTHORITATIVE_STACK_ACTION_LINGER_SECONDS).timeout.connect(
		func() -> void:
			_resume_pending_humbaba_after_auto_resolution(action, target),
		CONNECT_ONE_SHOT
	)

func _resume_pending_humbaba_after_auto_resolution(action: CardAction, actual_target) -> void:
	if action == null or pending_humbaba_action != action:
		return
	if _emit_next_pending_humbaba_prompt():
		return
	_clear_pending_humbaba_state()
	_continue_pending_humbaba_attack_resolution(action, actual_target)
	if pending_retreat_action == action:
		_mark_deferred_authoritative_action(action, "combat_retreat_decision")
		return
	if pending_combat_reveal_linger_action == action:
		_mark_deferred_authoritative_action(action, "combat_reveal_linger")
		return
	_complete_deferred_authoritative_action(action, "humbaba_augury_choice")

func _continue_pending_humbaba_attack_resolution(action: CardAction, actual_target) -> void:
	if action == null:
		return
	if actual_target is Card:
		var target_card := actual_target as Card
		if target_card.current_zone == null or not target_card.current_zone.is_board_zone():
			action.attacker.spend_attack_creature_action()
			game_manager._clear_combat_engagement_state(target_card)
			last_resolution_text = action.attacker.card_name + "'s attack fizzles â€” target is no longer on the board."
			return
		_finish_creature_combat(action, target_card)
	elif actual_target is Player:
		_finish_followers_attack(action, actual_target)

func _clear_pending_humbaba_state() -> void:
	pending_humbaba_action = null
	pending_humbaba_target = null
	pending_humbaba_prompt_uids.clear()

func is_targeting_active() -> bool:
	return pending_click_selection_confirm.is_valid() or \
		awaiting_spell_target or \
		awaiting_god_ability_target or \
		awaiting_stupefy_target or \
		awaiting_pyre_target or \
		awaiting_anointing_target

func _get_active_attackers(action: CardAction) -> Array[Card]:
	var active: Array[Card] = []
	for c in [action.attacker, action.united_front_partner]:
		if _can_continue_declared_attack(c):
			active.append(c)
	return active

func _uses_authoritative_headless_attack_flow() -> bool:
	return authoritative_match_flow_enabled

func uses_authoritative_priority_flow() -> bool:
	return _uses_authoritative_headless_attack_flow()

func _uses_authoritative_headless_priority_flow() -> bool:
	return uses_authoritative_priority_flow()

func _clear_priority_window_state() -> void:
	if game_manager == null:
		return
	game_manager.priority_player = null
	game_manager.consecutive_passes = 0

func _can_resolve_top_stack_action_now() -> bool:
	if game_manager == null or game_manager.action_stack.is_empty():
		return true
	if game_manager.both_passed():
		return true
	var top_action: CardAction = game_manager.action_stack.back()
	if top_action == null:
		return true
	if _action_requires_explicit_priority_window(top_action):
		return false
	var first_player := game_manager.priority_player
	if first_player == null:
		first_player = top_action.initial_priority_player if top_action.initial_priority_player != null else game_manager.get_opponent(top_action.source_player)
	var second_player := game_manager.get_opponent(first_player) if first_player != null else null
	return not _player_has_priority_prompt_responses(first_player) and not _player_has_priority_prompt_responses(second_player)

func set_priority_preferences(
	player: Player,
	stops: Dictionary,
	full_control: bool,
	auto_mode: String = PRIORITY_AUTO_MODE_NONE,
	god_specific: Dictionary = {},
	card_offer_priority: Dictionary = {}
) -> void:
	if game_manager == null or player == null:
		return
	var player_idx := game_manager.players.find(player)
	if player_idx < 0:
		return
	var normalized_stops := {}
	for stop_key in PRIORITY_STOP_KEYS:
		normalized_stops[stop_key] = bool(stops.get(stop_key, false))
	if auto_mode not in [PRIORITY_AUTO_MODE_NONE, PRIORITY_AUTO_MODE_PLAY, PRIORITY_AUTO_MODE_FAST_FORWARD]:
		auto_mode = PRIORITY_AUTO_MODE_NONE
	var raw_hermes_settings = god_specific.get("hermes", {})
	var hermes_settings: Dictionary = {}
	if raw_hermes_settings is Dictionary:
		hermes_settings = raw_hermes_settings as Dictionary
	var card_offer_by_uid: Dictionary = {}
	var raw_card_offer_by_uid = card_offer_priority.get("by_uid", {})
	if raw_card_offer_by_uid is Dictionary:
		card_offer_by_uid = (raw_card_offer_by_uid as Dictionary).duplicate(true)
	_priority_preferences_by_player[player_idx] = {
		"stops": normalized_stops,
		"full_control": full_control,
		"auto_mode": auto_mode,
		"card_offer_priority": {
			"enabled": bool(card_offer_priority.get("enabled", false)),
			"by_uid": card_offer_by_uid,
		},
		"god_specific": {
			"hermes": {
				"offer_priority": bool(hermes_settings.get("offer_priority", true)),
				"auto_pass_end_priority": bool(hermes_settings.get("auto_pass_end_priority", true)),
				"auto_pass_upkeep_priority": bool(hermes_settings.get("auto_pass_upkeep_priority", true)),
			},
		},
	}

func _priority_response_offers_prompt(card: Card, action: CardAction, player: Player) -> bool:
	if card == null or action == null or player == null or game_manager == null:
		return false
	var player_idx := game_manager.players.find(player)
	var preferences: Dictionary = _priority_preferences_by_player.get(player_idx, {})
	var card_offer_priority: Dictionary = preferences.get("card_offer_priority", {})
	if bool(card_offer_priority.get("enabled", false)):
		var raw_offer_by_uid = card_offer_priority.get("by_uid", {})
		var offer_by_uid: Dictionary = {}
		if raw_offer_by_uid is Dictionary:
			offer_by_uid = raw_offer_by_uid as Dictionary
		if not bool(offer_by_uid.get(card.uid, true)):
			return false
	if card.card_name != "Hermes":
		return true
	var god_specific: Dictionary = preferences.get("god_specific", {})
	var hermes_settings: Dictionary = god_specific.get("hermes", {})
	if not bool(hermes_settings.get("offer_priority", true)):
		return false
	var priority_stop_key := get_priority_stop_key(action)
	if priority_stop_key == "end" and bool(hermes_settings.get("auto_pass_end_priority", true)):
		return false
	if priority_stop_key == "start" and bool(hermes_settings.get("auto_pass_upkeep_priority", true)):
		return false
	return true

func get_priority_prompt_offering_responses(player: Player) -> Array:
	var offering_responses: Array = []
	if game_manager == null or player == null or game_manager.action_stack.is_empty():
		return offering_responses
	var top_action: CardAction = game_manager.action_stack.back()
	for card in game_manager.get_priority_responses(player):
		if _priority_response_offers_prompt(card as Card, top_action, player):
			offering_responses.append(card)
	return offering_responses

func get_priority_stop_key(action: CardAction) -> String:
	if action == null:
		return "main"
	var root_action := action
	var response_depth := 0
	while root_action.response_to != null and root_action.response_to != root_action and response_depth < 32:
		root_action = root_action.response_to
		response_depth += 1
	if root_action.type == CardAction.Type.ATTACK:
		return "combat"
	if root_action.type == CardAction.Type.EVENT:
		if root_action.event_name == "start_turn":
			return "start"
		if root_action.event_name == "end_turn":
			return "end"
	return "main"

func _priority_window_was_offered_to_player(action: CardAction, player: Player) -> bool:
	if action == null or player == null or game_manager == null:
		return false
	var player_idx := game_manager.players.find(player)
	if player_idx < 0:
		return false
	var offered_indexes: Array = action.event_data.get("priority_window_offered_player_indexes", [])
	return player_idx in offered_indexes

func mark_priority_window_offered(action: CardAction, player: Player) -> void:
	if action == null or player == null or game_manager == null:
		return
	var player_idx := game_manager.players.find(player)
	if player_idx < 0:
		return
	var offered_indexes: Array = action.event_data.get("priority_window_offered_player_indexes", [])
	if player_idx not in offered_indexes:
		offered_indexes.append(player_idx)
	action.event_data["priority_window_offered_player_indexes"] = offered_indexes
	if bool(action.event_data.get("force_priority_window", false)):
		action.event_data["priority_window_offered"] = true

func _get_action_target_card(action: CardAction) -> Card:
	if action == null or not (action.target is Card):
		return null
	return action.target as Card

func _action_targets_card_for_destruction(action: CardAction) -> bool:
	if action == null or _get_action_target_card(action) == null:
		return false
	if action.event_data.has("destruction"):
		return bool(action.event_data.get("destruction", false))
	if action.event_data.has("destroy"):
		return bool(action.event_data.get("destroy", false))
	if action.card != null:
		if action.card.has_type("Destruction") or action.card.has_type("Magic Destruction"):
			return true
		for type_name in action.card.card_types:
			if str(type_name).findn("destruction") >= 0:
				return true
		if str(action.card.ability_text).findn("destroy") >= 0:
			return true
	if action.event_name.findn("destroy") >= 0:
		return true
	return false

func _play_mode_requires_priority_window(action: CardAction, player: Player) -> bool:
	if action == null or player == null or game_manager == null:
		return false
	if get_priority_stop_key(action) == "combat":
		return _player_has_priority_prompt_responses(player)
	if not _action_targets_card_for_destruction(action):
		return false
	var target_card := _get_action_target_card(action)
	return target_card != null \
		and target_card.card_owner == player \
		and game_manager.can_card_respond_to_priority(target_card, player)

func player_requires_priority_window(action: CardAction, player: Player) -> bool:
	if action == null or player == null or game_manager == null:
		return false
	if bool(action.event_data.get("force_priority_window", false)) \
			and not bool(action.event_data.get("priority_window_offered", false)):
		return true
	if _priority_window_was_offered_to_player(action, player):
		return false
	var player_idx := game_manager.players.find(player)
	var preferences: Dictionary = _priority_preferences_by_player.get(player_idx, {})
	if bool(preferences.get("full_control", false)):
		return true
	var auto_mode := str(preferences.get("auto_mode", PRIORITY_AUTO_MODE_NONE))
	if auto_mode == PRIORITY_AUTO_MODE_FAST_FORWARD:
		return false
	if auto_mode == PRIORITY_AUTO_MODE_PLAY:
		return _play_mode_requires_priority_window(action, player)
	var stops: Dictionary = preferences.get("stops", {})
	return bool(stops.get(get_priority_stop_key(action), false))

func _action_requires_explicit_priority_window(action: CardAction) -> bool:
	if action == null:
		return false
	if bool(action.event_data.get("force_priority_window", false)) \
			and not bool(action.event_data.get("priority_window_offered", false)):
		return true
	for player in game_manager.players:
		if player_requires_priority_window(action, player):
			return true
	return false

func _resolve_authoritative_stack_top_after_priority() -> void:
	if game_manager == null or game_manager.action_stack.is_empty():
		return
	if not _can_resolve_top_stack_action_now():
		_advance_authoritative_priority()
		return
	var resolved_action: CardAction = game_manager.action_stack.back()
	_clear_priority_window_state()
	resolve_action(resolved_action)

func _get_authoritative_resolution_tree():
	if network_manager != null and network_manager is Node:
		return network_manager.get_tree()
	return null

func _has_remote_authoritative_recipients() -> bool:
	if network_manager == null:
		return false
	if network_manager.has_method("_has_remote_broadcast_recipients"):
		return bool(network_manager.call("_has_remote_broadcast_recipients"))
	var player_peer_map = network_manager.get("player_peer_ids")
	if player_peer_map is Dictionary:
		for peer_id in (player_peer_map as Dictionary).values():
			if int(peer_id) > 1:
				return true
	var spectator_ids = network_manager.get("spectator_peer_ids")
	return spectator_ids is Array and not (spectator_ids as Array).is_empty()

func _stack_action_should_linger_for_visibility(action: CardAction) -> bool:
	if action == null:
		return false
	if bool(action.event_data.get("linger_for_visibility", false)):
		return true
	if action.type == CardAction.Type.ATTACK:
		return true
	if action.type not in [CardAction.Type.SPELL, CardAction.Type.ABILITY, CardAction.Type.CHARM]:
		return false
	if action.target != null:
		return true
	return action.card != null and action.card.has_method("is_magical_card") and action.card.is_magical_card()

func _should_linger_authoritative_stack_resolution(action: CardAction = null) -> bool:
	if _stack_action_should_linger_for_visibility(action):
		return true
	# Events such as "summon" have no resolving card visual. Lingering them on
	# the server creates an invisible interval where clients appear unlocked.
	if action != null and action.type == CardAction.Type.EVENT:
		return false
	if allow_immediate_local_authoritative_stack_resolution and not _has_remote_authoritative_recipients():
		return false
	if network_manager == null:
		return false
	return true

func _schedule_authoritative_stack_top_after_priority() -> void:
	if _authoritative_stack_resolution_pending:
		return
	if game_manager == null or game_manager.action_stack.is_empty():
		_clear_priority_window_state()
		return
	_authoritative_stack_resolution_pending = true
	var resolved_action: CardAction = game_manager.action_stack.back()
	var resolve_after_passes := game_manager.both_passed()
	_clear_priority_window_state()
	if not _should_linger_authoritative_stack_resolution(resolved_action):
		_finish_authoritative_stack_resolution(resolved_action, resolve_after_passes)
		return
	var tree = _get_authoritative_resolution_tree()
	if tree == null:
		_finish_authoritative_stack_resolution(resolved_action, resolve_after_passes)
		return
	tree.create_timer(AUTHORITATIVE_STACK_ACTION_LINGER_SECONDS).timeout.connect(
		func() -> void:
			_finish_authoritative_stack_resolution(resolved_action, resolve_after_passes),
		CONNECT_ONE_SHOT
	)

func _finish_authoritative_stack_resolution(action: CardAction, force_resolve: bool = false) -> void:
	_authoritative_stack_resolution_pending = false
	if game_manager == null or action == null:
		return
	if not game_manager.action_stack.has(action):
		if not game_manager.action_stack.is_empty():
			_advance_authoritative_priority()
		else:
			_try_process_pending_turn_action_after_opponent_priority()
		return
	if not force_resolve and not _can_resolve_top_stack_action_now():
		_advance_authoritative_priority()
		return
	_clear_priority_window_state()
	resolve_action(action)
	if action in game_manager.resolving_stack_actions:
		return
	_try_process_pending_turn_action_after_opponent_priority()

func _get_action_label(card: Card, viewer: Player = null) -> String:
	return card.get_log_display_name(viewer) if card != null else "Card"

func _get_action_target_label(target, viewer: Player = null) -> String:
	if target is Card:
		return (target as Card).get_target_log_display_name(viewer)
	if target is Player:
		return (target as Player).player_name + "'s followers"
	return "target"

func _build_authoritative_resolution_text(action_type: int, source_card: Card, target = null, viewer: Player = null) -> String:
	var source_name := _get_action_label(source_card, viewer)
	if target != null:
		if action_type == CardAction.Type.ABILITY and source_card != null:
			var target_ability_name := source_card.get_named_ability_name("activated")
			if target_ability_name != "":
				return "%s uses %s targeting %s." % [source_name, target_ability_name, _get_action_target_label(target, viewer)]
		return "%s is targeting %s." % [source_name, _get_action_target_label(target, viewer)]
	if action_type == CardAction.Type.SPELL:
		return "Cast " + source_name + "!"
	if action_type == CardAction.Type.ABILITY and source_card != null:
		var ability_name := source_card.get_named_ability_name("activated")
		if ability_name != "":
			return "%s uses %s." % [source_name, ability_name]
	return source_name + " activated!"

func _find_available_stack_display_zone(player: Player) -> Zone:
	if player == null:
		return null
	for zone in player.reserve_zones + player.frontline_zones:
		if zone.cards.size() > 0:
			continue
		var already_reserved := false
		for action in game_manager.action_stack:
			if action != null and action.display_zone == zone:
				already_reserved = true
				break
		if not already_reserved:
			return zone
	return null

func _can_use_stack_display_zone(zone: Zone, player: Player) -> bool:
	if zone == null or player == null:
		return false
	if not zone.is_board_zone():
		return false
	if zone.zone_owner != player:
		return false
	if not zone.cards.is_empty():
		return false
	for action in game_manager.action_stack:
		if action != null and action.display_zone == zone:
			return false
	return true

func _can_use_requested_stack_display_zone(zone: Zone, player: Player, card: Card) -> bool:
	if zone == null or player == null or card == null:
		return false
	if not zone.is_board_zone():
		return false
	if card.current_zone == zone:
		return true
	if zone.zone_owner != player or not zone.cards.is_empty():
		return false
	for action in game_manager.action_stack:
		if action != null and action.display_zone == zone:
			return false
	return true

func _assign_stack_display_zone(action: CardAction, preferred_zone: Zone = null) -> void:
	if action == null or action.card == null or action.source_player == null:
		return
	if preferred_zone != null and _can_use_requested_stack_display_zone(preferred_zone, action.source_player, action.card):
		action.display_zone = preferred_zone
		return
	if not action.card.goes_to_graveyard_after_use():
		return
	if action.card.current_zone != null and action.card.current_zone.is_board_zone():
		action.display_zone = action.card.current_zone
		return
	action.display_zone = _find_available_stack_display_zone(action.source_player)

func _place_persistent_charm_on_board(charm: CharmCard, display_zone: Zone = null) -> void:
	if charm == null or charm.card_owner == null:
		return
	if charm.goes_to_graveyard_after_use():
		return
	if charm.current_zone != charm.card_owner.hand_zone:
		return
	var target_zone := display_zone
	if target_zone == null \
			or not target_zone.is_board_zone() \
			or target_zone.zone_owner != charm.card_owner \
			or not target_zone.cards.is_empty():
		target_zone = _find_available_stack_display_zone(charm.card_owner)
	if target_zone == null \
			or not target_zone.is_board_zone() \
			or target_zone.zone_owner != charm.card_owner \
			or not target_zone.cards.is_empty():
		return
	charm.card_owner.move_card(charm, target_zone)

func _queue_authoritative_magical_action(
	action_type: int,
	source_card: Card,
	target,
	resolve_callback: Callable,
	resolution_text: String = "",
	preferred_display_zone: Zone = null,
	response_to: CardAction = null
) -> void:
	if game_manager == null or source_card == null:
		return
	var action := CardAction.new()
	action.type = action_type as CardAction.Type
	action.source_player = source_card.card_owner if source_card.card_owner != null else game_manager.current_player
	action.card = source_card
	action.target = target
	action.response_to = response_to
	action.resolve_callback = resolve_callback
	action.resolution_text = resolution_text if resolution_text != "" else _build_authoritative_resolution_text(action_type, source_card, target)
	if action_type == CardAction.Type.ABILITY:
		action.event_data["ability_trigger_hint"] = "activated"
	action.event_data["linger_for_visibility"] = true
	_assign_stack_display_zone(action, preferred_display_zone)
	game_manager.push_to_stack(action)

func _get_intercept_target_row_depth(protected_target) -> int:
	if protected_target is Player:
		return 2
	if not (protected_target is Card):
		return -1
	var target_card := protected_target as Card
	if target_card.card_type == Card.CardType.EQUIPMENT and target_card.equipped_on != null:
		return _get_intercept_target_row_depth(target_card.equipped_on)
	if target_card.current_zone == null:
		return -1
	match target_card.current_zone.zone_type:
		Zone.ZoneType.FRONTLINE:
			return 0
		Zone.ZoneType.RESERVE:
			return 1
		Zone.ZoneType.GOD_SLOT:
			return 2
		_:
			return -1

func _get_interceptor_row_depth(defender: Card) -> int:
	if defender == null or defender.current_zone == null:
		return -1
	match defender.current_zone.zone_type:
		Zone.ZoneType.FRONTLINE:
			return 0
		Zone.ZoneType.RESERVE:
			return 1
		_:
			return -1

func _get_intercept_row_distance(defender: Card, protected_target) -> int:
	var defender_depth := _get_interceptor_row_depth(defender)
	var target_depth := _get_intercept_target_row_depth(protected_target)
	if defender_depth < 0 or target_depth < 0 or target_depth < defender_depth:
		return -1
	return target_depth - defender_depth

func _get_minimum_intercept_row_distance(defender: Card, attacker: Card, protected_target) -> int:
	var minimum_depth := 1
	if defender.creature_mode == Card.CreatureMode.AGGRESSIVE:
		minimum_depth = 2
	minimum_depth = max(0, minimum_depth - defender.get_intercept_reach_bonus(game_manager, attacker, protected_target))
	return minimum_depth

func _get_declared_attack_partner(attacker: Card) -> Card:
	if attacker == null or not attacker.has_method("get_united_front_partner_for_attack"):
		return null
	return attacker.get_united_front_partner_for_attack(game_manager)

func _get_declared_attack_speed(attacker: Card) -> int:
	if attacker == null:
		return 0
	if attacker.has_method("get_united_front_attack_speed"):
		return attacker.get_united_front_attack_speed(game_manager)
	return attacker.get_effective_speed()

func _can_intercept(defender: Card, attacker: Card, protected_target) -> bool:
	if attacker == null or protected_target == null:
		return false
	if protected_target is Card and defender == protected_target:
		return false
	if defender == null or defender.card_type != Card.CardType.CREATURE:
		return false
	if defender.is_sleeping:
		return false
	if defender.can_special_intercept(game_manager, attacker, protected_target):
		return game_manager.can_interceptor_engage_attacker(defender, attacker)
	var interceptor_speed := game_manager.get_interceptor_speed_against_attacker(defender, attacker, protected_target)
	if interceptor_speed < _get_declared_attack_speed(attacker):
		return false
	if not game_manager.can_interceptor_engage_attacker(defender, attacker):
		return false
	if defender.creature_mode == Card.CreatureMode.AGGRESSIVE:
		return _get_intercept_row_distance(defender, protected_target) >= _get_minimum_intercept_row_distance(defender, attacker, protected_target)
	if defender.creature_mode == Card.CreatureMode.DEFENSIVE:
		return _get_intercept_row_distance(defender, protected_target) >= _get_minimum_intercept_row_distance(defender, attacker, protected_target)
	return false

func _get_possible_interceptors(attacker: Card, protected_target) -> Array[Card]:
	var possible_interceptors: Array[Card] = []
	var defender: Player = protected_target if protected_target is Player else (protected_target as Card).get_controller()
	if defender == null:
		return possible_interceptors
	for zone in defender.frontline_zones + defender.reserve_zones:
		for card in zone.cards:
			if _can_intercept(card, attacker, protected_target):
				possible_interceptors.append(card)
	return possible_interceptors

func _build_pending_attack_action() -> CardAction:
	if selected_attacker == null or pending_attack_target == null:
		return null
	var action := CardAction.new()
	action.type = CardAction.Type.ATTACK
	action.source_player = game_manager.current_player
	action.attacker = selected_attacker
	action.united_front_partner = _get_declared_attack_partner(selected_attacker)
	action.attack_speed_override = _get_declared_attack_speed(selected_attacker)
	action.interceptor = selected_interceptor
	action.target = pending_attack_target
	action.halve_follower_damage = selected_attacker != null and selected_attacker.halves_follower_damage_inflicted()
	return action

func _get_priority_response_targets(card: Card, top: CardAction) -> Array:
	var targets: Array = []
	if card == null or top == null or game_manager == null:
		return targets
	if card is HexCard:
		targets = game_manager.get_priority_hex_targets(card as HexCard, top)
	elif card.has_method("get_priority_targets"):
		targets = card.get_priority_targets(game_manager, top)
	elif card is CharmCard:
		targets = (card as CharmCard).get_valid_targets(game_manager)
	elif card.has_method("get_priority_field_targets"):
		targets = card.get_priority_field_targets(game_manager, top)
	elif card.has_method("get_valid_targets"):
		targets = card.get_valid_targets(game_manager)
	return targets

func _get_priority_response_target_uids(card: Card, top: CardAction) -> Array:
	var target_uids: Array = []
	if not _priority_response_requires_target_choice(card):
		return target_uids
	var targets := _get_priority_response_targets(card, top)
	for target in targets:
		if target is Card:
			target_uids.append((target as Card).uid)
	return target_uids

func _priority_response_requires_target_choice(card: Card) -> bool:
	if card == null:
		return false
	if card.has_method("requires_priority_target_selection"):
		return bool(card.call("requires_priority_target_selection"))
	if game_manager != null and game_manager.is_targeting_source(card):
		return true
	return false

func _validate_priority_response_target(card: Card, top: CardAction, target: Card, target_uid: String, context: String) -> String:
	var requested_uid := str(target_uid).strip_edges()
	var requires_target := _priority_response_requires_target_choice(card)
	var valid_targets := _get_priority_response_targets(card, top)
	if not requested_uid.is_empty():
		if not requires_target:
			return ""
		if target == null:
			return context + ": target not found"
		if not _is_card_in_targets_by_uid(target, valid_targets):
			return context + ": invalid priority target"
		return ""
	if requires_target:
		if valid_targets.is_empty():
			return context + ": no valid targets"
		return context + ": target required"
	return ""

func _build_priority_response_options(responses: Array) -> Array:
	var response_options: Array = []
	if game_manager.action_stack.is_empty():
		return response_options
	var top: CardAction = game_manager.action_stack.back()
	for card in responses:
		if card is HexCard:
			var hex := card as HexCard
			var hex_target_uids := _get_priority_response_target_uids(hex, top)
			if _priority_response_requires_target_choice(hex) and hex_target_uids.is_empty():
				continue
			var target_is_attacker := not hex.has_method("get_priority_targets") and top.type == CardAction.Type.ATTACK
			response_options.append({
				response_type = "hex",
				card_uid = hex.uid,
				target_uids = hex_target_uids,
				target_is_attacker = target_is_attacker,
			})
		elif card is CharmCard:
			var charm := card as CharmCard
			var charm_target_uids := _get_priority_response_target_uids(charm, top)
			if _priority_response_requires_target_choice(charm) and charm_target_uids.is_empty():
				continue
			var from_hand := charm.current_zone == charm.card_owner.hand_zone
			response_options.append({
				response_type = "charm",
				card_uid = charm.uid,
				target_uids = charm_target_uids,
				from_hand = from_hand,
			})
		elif card is SpellCard:
			var spell := card as SpellCard
			var spell_target_uids := _get_priority_response_target_uids(spell, top)
			if _priority_response_requires_target_choice(spell) and spell_target_uids.is_empty():
				continue
			response_options.append({
				response_type = "spell",
				card_uid = spell.uid,
				target_uids = spell_target_uids,
			})
		elif card != null and card.is_god and card.has_method("get_valid_targets"):
			var god_target_uids := _get_priority_response_target_uids(card, top)
			if _priority_response_requires_target_choice(card) and god_target_uids.is_empty():
				continue
			response_options.append({
				response_type = "god",
				card_uid = card.uid,
				target_uids = god_target_uids,
			})
		elif card != null and card.has_method("can_respond_to_priority_action") and card.has_method("activate"):
			var ability_target_uids := _get_priority_response_target_uids(card, top)
			if _priority_response_requires_target_choice(card) and ability_target_uids.is_empty():
				continue
			response_options.append({
				response_type = "ability",
				card_uid = card.uid,
				target_uids = ability_target_uids,
			})
	return response_options

func build_priority_prompt_data(player: Player) -> Dictionary:
	if game_manager != null:
		game_manager.prune_stale_stack_actions()
	if game_manager == null or player == null or game_manager.action_stack.is_empty():
		return {
			player_index = game_manager.players.find(player) if game_manager != null and player != null else -1,
			responses = [],
			action_message = "",
		}
	var responses := get_priority_prompt_offering_responses(player)
	if game_manager.action_stack.is_empty():
		return {
			player_index = game_manager.players.find(player),
			responses = [],
			action_message = "",
		}
	return {
		player_index = game_manager.players.find(player),
		responses = _build_priority_response_options(responses),
		action_message = _get_priority_action_message(game_manager.action_stack.back(), player),
	}

func _player_has_priority_prompt_responses(player: Player) -> bool:
	if player == null:
		return false
	return not get_priority_prompt_offering_responses(player).is_empty()

func _get_priority_action_message(top: CardAction, viewer: Player = null) -> String:
	if top == null:
		return ""
	match top.type:
		CardAction.Type.ATTACK:
			if top.attacker != null:
				return _get_action_label(top.attacker, viewer) + " is attacking - you may respond!"
		CardAction.Type.SPELL:
			if top.card != null:
				return _get_action_label(top.card, viewer) + " is waiting to resolve - you may respond!"
		CardAction.Type.ABILITY:
			if top.card != null:
				return _get_action_label(top.card, viewer) + " ability is waiting to resolve - you may respond!"
		CardAction.Type.CHARM:
			if top.card != null:
				return _get_action_label(top.card, viewer) + " is waiting to resolve - you may respond!"
		CardAction.Type.EVENT:
			if top.event_name == "start_turn":
				return "Start-of-turn priority window."
			if top.event_name == "end_turn":
				return "End-of-turn priority window."
			if top.event_name == "destroyed" and top.card != null:
				return _get_action_label(top.card, viewer) + " was destroyed - you may respond!"
			if top.event_name == "summon" and top.card != null:
				return _get_action_label(top.card, viewer) + " was summoned - you may respond!"
			if top.event_name == "hand_play" and top.card != null:
				return _get_action_label(top.card, viewer) + " was played - you may respond!"
			if top.card != null:
				return _get_action_label(top.card, viewer) + " effect waits on priority."
	return ""

func _broadcast_priority_offered(player: Player, responses: Array) -> void:
	if network_manager == null or game_manager.action_stack.is_empty() or player == null:
		return
	var event_data := {
		player_index = game_manager.players.find(player),
		responses = _build_priority_response_options(responses),
		action_message = _get_priority_action_message(game_manager.action_stack.back(), player),
	}
	var player_idx := game_manager.players.find(player)
	var peer_id: int = network_manager.player_peer_ids.get(player_idx, -1)
	if peer_id == 1:
		network_manager.game_event_received.emit("priority_offered", event_data)
	elif peer_id > 0:
		network_manager.broadcast_event_to_peer(peer_id, "priority_offered", event_data)

func advance_priority() -> void:
	_advance_authoritative_priority()

func _advance_authoritative_priority() -> void:
	if not _uses_authoritative_headless_priority_flow():
		return
	_log_authoritative_flow_state("priority_advance:start")
	_prune_stale_ui_interactions_for_current_turn()
	if _authoritative_stack_resolution_pending \
			or not _pending_ui_interactions.is_empty() \
			or not _queued_ui_interactions.is_empty():
		_log_authoritative_flow_state("priority_advance:blocked")
		return
	game_manager.prune_stale_stack_actions()
	if game_manager.action_stack.is_empty():
		_log_authoritative_flow_state("priority_advance:no_stack")
		return
	var player := game_manager.priority_player
	if player == null:
		var top_action: CardAction = game_manager.action_stack.back()
		player = top_action.initial_priority_player if top_action.initial_priority_player != null else game_manager.get_opponent(top_action.source_player)
		game_manager.priority_player = player
	if player == null:
		_log_authoritative_flow_state("priority_advance:no_player")
		return
	if _try_pass_pending_turn_action_actor_priority():
		_log_authoritative_flow_state("priority_advance:passed_pending_actor")
		return
	var prompt_data := build_priority_prompt_data(player)
	var prompt_offering_responses := get_priority_prompt_offering_responses(player)
	var top_action: CardAction = game_manager.action_stack.back()
	var force_priority_window := player_requires_priority_window(top_action, player)
	_log_authoritative_flow_state("priority_advance:evaluate player=%s responses=%d force=%s top=%s" % [
		_get_player_debug_label(player),
		prompt_offering_responses.size(),
		str(force_priority_window),
		_get_action_debug_summary(top_action),
	])
	if prompt_offering_responses.is_empty() and not force_priority_window:
		game_manager.pass_priority()
		_log_authoritative_flow_state("priority_advance:auto_pass player=%s" % _get_player_debug_label(player))
		if game_manager.both_passed():
			if game_manager.action_stack.is_empty():
				_clear_priority_window_state()
				_log_authoritative_flow_state("priority_advance:both_passed_empty")
				return
			_schedule_authoritative_stack_top_after_priority()
		else:
			call_deferred("_advance_authoritative_priority")
		return
	var player_idx := game_manager.players.find(player)
	if player_idx < 0:
		return
	if top_action != null:
		top_action.event_data["priority_prompt_offered_player_index"] = player_idx
		if force_priority_window:
			mark_priority_window_offered(top_action, player)
	_log_authoritative_flow_state("priority_advance:emit_prompt player=%s responses=%d force=%s" % [
		_get_player_debug_label(player),
		prompt_offering_responses.size(),
		str(force_priority_window),
	])
	_emit_ui_interaction_for_player(player, "priority", prompt_data)

func queue_or_resolve_priority_event(action: CardAction, defer_authoritative_priority: bool = false) -> bool:
	if action == null:
		return false
	game_manager.push_to_stack(action)
	var first_player: Player = game_manager.priority_player
	if first_player == null:
		first_player = action.initial_priority_player if action.initial_priority_player != null else game_manager.get_opponent(action.source_player)
	var second_player: Player = game_manager.get_opponent(first_player) if first_player != null else null
	var first_has_responses: bool = _player_has_priority_prompt_responses(first_player)
	var second_has_responses: bool = _player_has_priority_prompt_responses(second_player)
	if first_has_responses or second_has_responses or _action_requires_explicit_priority_window(action):
		if game_manager.priority_player == null:
			game_manager.priority_player = first_player
		if _uses_authoritative_headless_priority_flow() and not defer_authoritative_priority:
			_advance_authoritative_priority()
		return true
	_clear_priority_window_state()
	resolve_action(action)
	return false

func _queue_or_resolve_authoritative_priority_event(action: CardAction) -> void:
	queue_or_resolve_priority_event(action)

func _queue_authoritative_priority_event(
	event_name: String,
	resolve_callback: Callable = Callable(),
	initial_priority_player: Player = null,
	source_player_override: Player = null,
	resolution_text: String = "",
	source_card: Card = null,
	event_speed: int = 0,
	suppress_public_resolution_log: bool = false
) -> void:
	var action := CardAction.new()
	action.type = CardAction.Type.EVENT
	action.source_player = source_player_override if source_player_override != null else game_manager.current_player
	action.initial_priority_player = initial_priority_player
	action.card = source_card
	action.event_name = event_name
	action.event_speed = event_speed
	action.resolve_callback = resolve_callback
	action.resolution_text = resolution_text
	action.event_data["suppress_public_resolution_log"] = suppress_public_resolution_log
	_queue_or_resolve_authoritative_priority_event(action)

func _build_upkeep_resolution_feedback(default_feedback: String) -> String:
	if game_manager == null:
		return default_feedback
	var resolved_feedback := game_manager.consume_player_feedback()
	if resolved_feedback.strip_edges() == "":
		return default_feedback
	if default_feedback.strip_edges() == "" or resolved_feedback == default_feedback:
		return resolved_feedback
	return "%s %s" % [default_feedback, resolved_feedback]

func _get_pending_wheel_of_fire_turn_start_choices() -> Array[WheelOfFire]:
	var pending: Array[WheelOfFire] = []
	if game_manager == null:
		return pending
	for player in game_manager.players:
		if player == null:
			continue
		for zone in player.frontline_zones + player.reserve_zones:
			for card in zone.cards:
				var wheel := card as WheelOfFire
				if wheel != null and wheel.can_offer_turn_start_advance(game_manager):
					pending.append(wheel)
	return pending

func _has_pending_wheel_of_fire_turn_start_choice() -> bool:
	return not _get_pending_wheel_of_fire_turn_start_choices().is_empty()

func _emit_next_wheel_of_fire_turn_start_choice() -> bool:
	var pending := _get_pending_wheel_of_fire_turn_start_choices()
	if pending.is_empty():
		return false
	var wheel := pending[0]
	_emit_ui_interaction_for_player(wheel.card_owner, "wheel_of_fire_turn_start", {
		"source_uid": wheel.uid,
	})
	return true

func _get_pending_breidablik_turn_start_choices() -> Array[Breidablik]:
	var pending: Array[Breidablik] = []
	if game_manager == null or game_manager.current_player == null:
		return pending
	for zone in game_manager.current_player.power_zones:
		for card in zone.cards:
			var breidablik := card as Breidablik
			if breidablik != null and breidablik.can_return_priest(game_manager):
				pending.append(breidablik)
	return pending

func _emit_next_breidablik_turn_start_choice() -> bool:
	var pending := _get_pending_breidablik_turn_start_choices()
	if pending.is_empty():
		return false
	var breidablik := pending[0]
	var stored_priest_uids: Array[String] = []
	for priest in breidablik.get_stored_priests():
		if priest != null:
			stored_priest_uids.append(priest.uid)
	_emit_ui_interaction_for_player(breidablik.card_owner, "breidablik_turn_start", {
		"source_uid": breidablik.uid,
		"target_uids": stored_priest_uids,
	})
	return true

func _close_breidablik_turn_start_windows() -> void:
	if game_manager == null:
		return
	for player in game_manager.players:
		if player == null:
			continue
		for zone in player.power_zones:
			for card in zone.cards:
				if card is Breidablik:
					(card as Breidablik).close_turn_start_window()

func _begin_or_continue_authoritative_turn_start_sequence(feedback: String = "") -> void:
	if game_manager == null:
		return
	if _active_turn_start_sequence_turn != game_manager.turn_number:
		_active_turn_start_sequence_turn = game_manager.turn_number
		_turn_start_sequence_feedback = ""
	if not feedback.strip_edges().is_empty():
		_append_turn_start_sequence_feedback(feedback)
	_continue_active_authoritative_turn_start_sequence()

func _append_turn_start_sequence_feedback(feedback: String) -> void:
	var cleaned_feedback := feedback.strip_edges()
	if cleaned_feedback == "":
		return
	if _turn_start_sequence_feedback.strip_edges() == "":
		_turn_start_sequence_feedback = cleaned_feedback
	elif _turn_start_sequence_feedback != cleaned_feedback:
		_turn_start_sequence_feedback = "%s %s" % [_turn_start_sequence_feedback, cleaned_feedback]

func _continue_active_authoritative_turn_start_sequence() -> bool:
	if game_manager == null \
			or _active_turn_start_sequence_turn != game_manager.turn_number \
			or _turn_start_priority_queued_turn == game_manager.turn_number:
		return false
	_prune_stale_ui_interactions_for_current_turn()
	if not _pending_ui_interactions.is_empty() or not _queued_ui_interactions.is_empty():
		return true
	if _emit_next_wheel_of_fire_turn_start_choice():
		return true
	if _emit_next_breidablik_turn_start_choice():
		return true
	_close_breidablik_turn_start_windows()
	game_manager.prune_stale_stack_actions()
	if not game_manager.action_stack.is_empty() or not game_manager.resolving_stack_actions.is_empty():
		_advance_authoritative_priority()
		return true
	_turn_start_priority_queued_turn = game_manager.turn_number
	_active_turn_start_sequence_turn = -1
	_queue_authoritative_priority_event(
		"start_turn",
		Callable(),
		game_manager.current_player,
		game_manager.current_player,
		_turn_start_sequence_feedback,
		null,
		0,
		true
	)
	_turn_start_sequence_feedback = ""
	return true

func _has_pending_impact_priority_action(card: Card) -> bool:
	if game_manager == null or card == null:
		return false
	for action in game_manager.action_stack:
		if action == null or not (action is CardAction):
			continue
		var typed_action := action as CardAction
		if typed_action.type != CardAction.Type.EVENT or typed_action.card != card:
			continue
		if str(typed_action.event_name).contains("impact"):
			return true
	return false

func _has_pending_event_priority_action(card: Card, event_name: String) -> bool:
	if game_manager == null or card == null:
		return false
	for action in game_manager.action_stack:
		if action == null or not (action is CardAction):
			continue
		var typed_action := action as CardAction
		if typed_action.type != CardAction.Type.EVENT or typed_action.card != card:
			continue
		if typed_action.event_name == event_name:
			return true
	return false

func _advance_authoritative_priority_for_pending_card_events(card: Card) -> void:
	if not _uses_authoritative_headless_priority_flow() or game_manager == null or card == null:
		return
	if _authoritative_stack_resolution_pending or not game_manager.resolving_stack_actions.is_empty():
		return
	if not _has_pending_event_priority_action(card, "summon") \
			and not _has_pending_event_priority_action(card, "frontline_entry") \
			and not _has_pending_impact_priority_action(card):
		return
	_advance_authoritative_priority()

func _active_command_advances_summon_priority() -> bool:
	return _active_command_type in [
		"play_creature",
		"skoll_upkeep_summon",
		"hati_moon_hunt",
		"wolf_master_summon",
		"resurrection_choice",
	]

func _clear_pending_attack_state() -> void:
	selected_attacker = null
	selected_interceptor = null
	pending_attack_target = null
	_clear_pending_hunting_tactics_attack_declaration()

func _clear_pending_hunting_tactics_attack_declaration() -> void:
	_pending_hunting_tactics_attack_declaration = false
	_pending_hunting_tactics_attack_attacker = null
	_pending_hunting_tactics_attack_target = null

func _has_unresolved_stack_action_window() -> bool:
	if game_manager == null:
		return false
	game_manager.prune_stale_stack_actions()
	return remote_authoritative_stack_window_locked \
		or _board_leaving_activation_linger_pending \
		or _authoritative_stack_resolution_pending \
		or pending_blot_spell != null \
		or pending_combat_reveal_linger_action != null \
		or pending_humbaba_action != null \
		or pending_retreat_action != null \
		or not game_manager.action_stack.is_empty() \
		or not game_manager.resolving_stack_actions.is_empty()

func _defer_board_leaving_activation(
	source_card: Card,
	action_text: String,
	resolve_callback: Callable
) -> bool:
	if source_card == null \
			or source_card.current_zone == null \
			or not source_card.current_zone.is_board_zone() \
			or not resolve_callback.is_valid():
		return false
	var tree = _get_authoritative_resolution_tree()
	if tree == null:
		return false
	_board_leaving_activation_linger_pending = true
	last_resolution_text = action_text
	_request_ui_refresh()
	tree.create_timer(AUTHORITATIVE_STACK_ACTION_LINGER_SECONDS).timeout.connect(
		func() -> void:
			resolve_callback.call()
			_board_leaving_activation_linger_pending = false
			var feedback := game_manager.consume_player_feedback() if game_manager != null else ""
			if not feedback.strip_edges().is_empty():
				last_resolution_text = feedback
			_request_ui_refresh(),
		CONNECT_ONE_SHOT
	)
	return true

func has_unresolved_stack_action_window() -> bool:
	return _has_unresolved_stack_action_window()

func set_remote_authoritative_stack_window_locked(locked: bool) -> void:
	remote_authoritative_stack_window_locked = locked

func set_remote_authoritative_visual_linger_pending(pending: bool) -> void:
	remote_authoritative_visual_linger_pending = pending

func is_visual_linger_pending() -> bool:
	return remote_authoritative_visual_linger_pending \
		or _board_leaving_activation_linger_pending \
		or pending_combat_reveal_linger_action != null \
		or _authoritative_stack_resolution_pending

func is_authoritative_stack_resolution_pending() -> bool:
	return _authoritative_stack_resolution_pending

func _request_ui_refresh() -> void:
	ui_refresh_requested.emit()

func _resolve_authoritative_headless_attack() -> void:
	var attack_action := _build_pending_attack_action()
	if attack_action == null:
		print("[HT-DEBUG] _resolve: build returned null, selected=%s target=%s" % [
			selected_attacker.card_name if selected_attacker != null else "null",
			str(pending_attack_target),
		])
		move_failed.emit("The pending attack could not be resolved.")
		_clear_pending_attack_state()
		return
	_clear_pending_attack_state()
	game_manager.push_to_stack(attack_action)
	_request_ui_refresh()
	print("[HT-DEBUG] _resolve: pushed to stack, advancing priority (stack_size=%d pending_ui=%d queued_ui=%d)" % [
		game_manager.action_stack.size(),
		_pending_ui_interactions.size(),
		_queued_ui_interactions.size(),
	])
	_advance_authoritative_priority()

func _get_hunting_tactics_powers_for_attack(attacker: Card) -> Array[HuntingTactics]:
	var powers: Array[HuntingTactics] = []
	if attacker == null:
		return powers
	var controller := attacker.get_controller()
	if controller == null:
		return powers
	for zone in controller.power_zones:
		for card in zone.cards:
			var power := card as HuntingTactics
			if power != null and power.can_check_attack_support_trigger(attacker):
				powers.append(power)
	return powers

func _get_hunting_tactics_prompt_power_for_attack(attacker: Card) -> HuntingTactics:
	for power in _get_hunting_tactics_powers_for_attack(attacker):
		if power.can_offer_attack_support(attacker):
			return power
	return null

func _mark_hunting_tactics_attack_declaration_checked(attacker: Card) -> void:
	if game_manager == null or attacker == null:
		return
	for power in _get_hunting_tactics_powers_for_attack(attacker):
		power.note_attack_declaration_choice(game_manager, attacker)

func _offer_hunting_tactics_attack_declaration_prompt() -> bool:
	if selected_attacker == null or pending_attack_target == null:
		return false
	var power := _get_hunting_tactics_prompt_power_for_attack(selected_attacker)
	if power == null:
		_mark_hunting_tactics_attack_declaration_checked(selected_attacker)
		print("[HT-DEBUG] _offer: no prompt power found for %s" % (selected_attacker.card_name if selected_attacker != null else "null"))
		return false
	_pending_hunting_tactics_attack_declaration = true
	_pending_hunting_tactics_attack_attacker = selected_attacker
	_pending_hunting_tactics_attack_target = pending_attack_target
	print("[HT-DEBUG] _offer: offering prompt power_owner=%s attacker=%s supporters=%d" % [
		power.card_owner.player_name if power.card_owner != null else "null",
		selected_attacker.card_name,
		power.get_support_choices(selected_attacker).size(),
	])
	_emit_ui_interaction_for_player(power.card_owner, "hunting_tactics", power.build_attack_support_prompt_data(selected_attacker))
	return true

func _continue_pending_attack_after_hunting_tactics_choice(attacker: Card, fallback_attack_target = null) -> void:
	print("[HT-DEBUG] _continue_pending_attack_after_hunting_tactics_choice flag=%s attacker=%s selected=%s target=%s" % [
		str(_pending_hunting_tactics_attack_declaration),
		attacker.card_name if attacker != null else "null",
		selected_attacker.card_name if selected_attacker != null else "null",
		str(pending_attack_target),
	])
	if not _pending_hunting_tactics_attack_declaration \
			and _pending_hunting_tactics_attack_attacker == null \
			and _pending_hunting_tactics_attack_target == null:
		return
	if attacker == null and _pending_hunting_tactics_attack_attacker != null:
		attacker = _pending_hunting_tactics_attack_attacker
	if selected_attacker == null and attacker != null:
		selected_attacker = attacker
	if selected_attacker == null and _pending_hunting_tactics_attack_attacker != null:
		selected_attacker = _pending_hunting_tactics_attack_attacker
	if pending_attack_target == null:
		pending_attack_target = fallback_attack_target if fallback_attack_target != null else _pending_hunting_tactics_attack_target
	if attacker != null and selected_attacker != null and attacker != selected_attacker:
		return
	_pending_hunting_tactics_attack_declaration = false
	if selected_attacker == null or pending_attack_target == null:
		return
	if _uses_authoritative_headless_attack_flow():
		_start_authoritative_headless_attack()

func _start_authoritative_headless_attack() -> void:
	if selected_attacker == null or pending_attack_target == null:
		print("[HT-DEBUG] _start_authoritative_headless_attack: missing attacker/target attacker=%s target=%s" % [
			selected_attacker.card_name if selected_attacker != null else "null",
			str(pending_attack_target),
		])
		move_failed.emit("The pending attack is missing an attacker or target.")
		_clear_pending_attack_state()
		return
	selected_interceptor = null
	var possible_interceptors := _get_possible_interceptors(selected_attacker, pending_attack_target)
	print("[HT-DEBUG] _start_authoritative_headless_attack: attacker=%s interceptors=%d pending_ui=%d queued_ui=%d" % [
		selected_attacker.card_name,
		possible_interceptors.size(),
		_pending_ui_interactions.size(),
		_queued_ui_interactions.size(),
	])
	if possible_interceptors.is_empty():
		_resolve_authoritative_headless_attack()
		return
	var defender: Player = pending_attack_target if pending_attack_target is Player else (pending_attack_target as Card).get_controller()
	var defender_idx := game_manager.players.find(defender)
	if defender_idx < 0:
		move_failed.emit("Could not determine which player may intercept.")
		_clear_pending_attack_state()
		return
	var interceptor_uids: Array[String] = []
	for interceptor in possible_interceptors:
		interceptor_uids.append(interceptor.uid)
	var attacker_name := _get_action_label(selected_attacker, defender) if selected_attacker != null else "A creature"
	var prompt_data := {
		"interceptor_uids": interceptor_uids,
		"attacker_uid": selected_attacker.uid if selected_attacker != null else "",
		"target_uid": "",
		"target_player_index": -1,
		"action_message": attacker_name + " is attacking - intercept or allow?"
	}
	if pending_attack_target is Card:
		var target_card := pending_attack_target as Card
		prompt_data["target_uid"] = target_card.uid
		prompt_data["target_player_index"] = game_manager.players.find(target_card.get_controller()) if game_manager != null else -1
	elif pending_attack_target is Player:
		var target_player_idx := game_manager.players.find(pending_attack_target) if game_manager != null else -1
		prompt_data["target_player_index"] = target_player_idx
		prompt_data["target_uid"] = str(target_player_idx)
	_emit_ui_interaction_for_player(defender, "intercept", prompt_data)

# --- Attack Management ---

func can_attack(card: Card) -> bool:
	if card == null or game_manager == null:
		return false
	if is_targeting_active() or _has_pending_reveal_target_ui_interaction():
		return false
	if _has_unresolved_stack_action_window():
		return false
		
	return (
		card.card_type == Card.CardType.CREATURE
		and card.get_controller() == game_manager.current_player
		and not card.summoned_after_first_attack_this_turn
		and card.can_take_major_creature_action()
		and not card.is_sleeping
		and not card.has_status_effect("cannot_attack")
		and game_manager.turn_number > 1
		and card.creature_mode == Card.CreatureMode.AGGRESSIVE
		and card.current_zone != null
		and card.current_zone.zone_type == Zone.ZoneType.FRONTLINE
		and not game_manager.attack_restrictions.has(card.get_controller())
	)

func get_attack_invalid_reason(card: Card) -> String:
	if card == null:
		return "No card selected."
	if card.card_type != Card.CardType.CREATURE:
		return "Only creatures can attack."
	if is_targeting_active() or _has_pending_reveal_target_ui_interaction():
		return "Choose a target for %s before attacking." % get_targeting_name()
	if _has_unresolved_stack_action_window():
		return "Resolve the pending stack action before attacking."
	if card.summoned_after_first_attack_this_turn:
		return card.card_name + " cannot attack because it was summoned after the first attack resolved this turn."
	if not card.can_take_major_creature_action():
		if card.creature_major_action_used:
			return card.card_name + " has already used its major action this turn."
		return card.card_name + " has already used all of its minor actions this turn."
	if card.is_sleeping:
		return card.card_name + " is Sleeping and cannot act."
	if card.has_status_effect("cannot_attack"):
		var status = card.get_status_effect("cannot_attack")
		var source = status.get("source", "an effect")
		return card.card_name + " cannot attack because of " + source + "."
	if card.get_controller() != game_manager.current_player:
		return "It is not " + card.card_name + "'s controller's turn."
	if game_manager.turn_number <= 1:
		return "Cannot attack on the first turn!"
	if card.creature_mode != Card.CreatureMode.AGGRESSIVE:
		return card.card_name + " is in defensive stance and cannot attack."
	if card.current_zone == null or card.current_zone.zone_type != Zone.ZoneType.FRONTLINE:
		return card.card_name + " cannot attack from the back row."
	if game_manager.attack_restrictions.has(card.get_controller()):
		var turns = game_manager.attack_restrictions[card.get_controller()]
		return "Attacks restricted for " + str(turns) + " more turns."
	
	return ""

func _emit_attack_invalid_feedback(reason: String) -> void:
	var trimmed_reason := reason.strip_edges()
	if trimmed_reason == "":
		return
	if trimmed_reason.contains("cannot attack because it was summoned after the first attack resolved this turn"):
		game_manager.note_player_feedback(trimmed_reason)
	move_failed.emit(trimmed_reason)

func select_attacker(card: Card) -> void:
	if card == null:
		selected_attacker = null
		return
		
	if can_attack(card):
		if selected_attacker == card:
			selected_attacker = null
		else:
			selected_attacker = card
			pending_attack_target = null
	else:
		_emit_attack_invalid_feedback(get_attack_invalid_reason(card))

func request_attack(attacker, target) -> bool:
	var attacker_card: Card = attacker if attacker is Card else game_manager.get_card_by_uid(str(attacker))
	var target_obj = target
	if pending_attack_target != null:
		move_failed.emit("Resolve the pending attack before declaring another attack.")
		return false
	
	if target is String:
		target_obj = null
		# Check if target is a card
		target_obj = game_manager.get_card_by_uid(target)
		if target_obj == null:
			var target_index := int(target)
			if str(target_index) == target and target_index >= 0 and target_index < game_manager.players.size():
				target_obj = game_manager.players[target_index]
		if target_obj == null:
			# Check if target is a player (by index or name)
			for p in game_manager.players:
				if p.player_name == target:
					target_obj = p
					break
	
	if attacker_card == null or target_obj == null:
		move_failed.emit("Invalid attack request: missing attacker or target.")
		return false
		
	if not can_attack(attacker_card):
		_emit_attack_invalid_feedback(get_attack_invalid_reason(attacker_card))
		return false
		
	# Check if target is valid for engagement
	if target_obj is Card:
		if not game_manager.can_cards_engage_each_other(attacker_card, target_obj):
			move_failed.emit(attacker_card.card_name + " cannot engage " + target_obj.card_name + ".")
			return false
	elif target_obj is Player:
		var allied_attackers := []
		var united_front_partner := _get_declared_attack_partner(attacker_card)
		if united_front_partner != null:
			allied_attackers.append(united_front_partner)
		if game_manager.is_followers_attack_blocked_by_active_structure(attacker_card, target_obj, allied_attackers):
			move_failed.emit(attacker_card.card_name + " cannot attack " + target_obj.player_name + "'s followers.")
			return false

	selected_attacker = attacker_card
	pending_attack_target = target_obj
	selected_interceptor = null
	
	# In a real game, this might trigger an "intercept" phase
	move_validated.emit({"type": "attack", "attacker": attacker_card, "target": target_obj})
	if _uses_authoritative_headless_attack_flow():
		if _offer_hunting_tactics_attack_declaration_prompt():
			return true
		_start_authoritative_headless_attack()
	return true

func broadcast_event(event_type: String, data: Dictionary) -> void:
	if network_manager != null and network_manager.is_server:
		network_manager.rpc("broadcast_event", event_type, data)

# --- Zone Serialization Helpers ---

## Convert a Zone to a serializable dict for use in commands.
static func zone_to_dict(zone: Zone, gm: GameManager) -> Dictionary:
	if zone == null or zone.zone_owner == null:
		return {}
	return {
		"player_index": gm.players.find(zone.zone_owner),
		"zone_type": zone.zone_type,
		"zone_index": zone.zone_index,
	}

## Resolve a zone dict back to a Zone object.
func resolve_zone(zone_dict: Dictionary) -> Zone:
	var player_idx: int = zone_dict.get("player_index", -1)
	if player_idx < 0 or player_idx >= game_manager.players.size():
		return null
	var player := game_manager.players[player_idx]
	var zone_idx: int = zone_dict.get("zone_index", 0)
	match zone_dict.get("zone_type", -1):
		Zone.ZoneType.HAND:     return player.hand_zone
		Zone.ZoneType.DECK:     return player.deck_zone
		Zone.ZoneType.GRAVEYARD: return player.graveyard_zone
		Zone.ZoneType.ABYSS:    return player.abyss_zone
		Zone.ZoneType.GOD_SLOT: return player.god_zone
		Zone.ZoneType.POWER_SLOT:
			if zone_idx >= 0 and zone_idx < player.power_zones.size():
				return player.power_zones[zone_idx]
		Zone.ZoneType.FRONTLINE:
			if zone_idx >= 0 and zone_idx < player.frontline_zones.size():
				return player.frontline_zones[zone_idx]
		Zone.ZoneType.RESERVE:
			if zone_idx >= 0 and zone_idx < player.reserve_zones.size():
				return player.reserve_zones[zone_idx]
	return null

func _resolve_command_display_zone(command: Dictionary, _source_player: Player) -> Zone:
	var zone_dict = command.get("display_zone", {})
	if not (zone_dict is Dictionary):
		return null
	var zone := resolve_zone(zone_dict as Dictionary)
	return zone if zone != null and zone.is_board_zone() else null

func _resolve_sender_player(sender_info: Dictionary) -> Player:
	if sender_info.is_empty():
		return null
	var player_idx := int(sender_info.get("player_index", -1))
	if player_idx < 0 or player_idx >= game_manager.players.size():
		return null
	return game_manager.players[player_idx]

func _get_card_controller(card: Card) -> Player:
	if card == null:
		return null
	return card.get_controller() if card.has_method("get_controller") else card.card_owner

func _get_current_targeting_player() -> Player:
	if pending_click_selection_source != null:
		return _get_card_controller(pending_click_selection_source)
	if awaiting_spell_target and spell_waiting_for_target != null:
		return _get_card_controller(spell_waiting_for_target)
	if awaiting_god_ability_target and god_ability_source != null:
		return _get_card_controller(god_ability_source)
	if awaiting_stupefy_target and stupefy_source != null:
		return _get_card_controller(stupefy_source)
	if awaiting_pyre_target and pyre_source != null:
		return _get_card_controller(pyre_source)
	if awaiting_anointing_target and anointing_source != null:
		return _get_card_controller(anointing_source)
	return null

func _resolve_cards_by_uids(raw_uids: Array) -> Array[Card]:
	var cards: Array[Card] = []
	for raw_uid in raw_uids:
		var uid := str(raw_uid).strip_edges()
		if uid == "":
			continue
		var card := game_manager.get_card_by_uid(uid)
		if card != null:
			cards.append(card)
	return cards

func _cards_have_unique_uids(cards: Array[Card]) -> bool:
	var seen := {}
	for card in cards:
		if card == null:
			return false
		if seen.has(card.uid):
			return false
		seen[card.uid] = true
	return true

func _can_use_creature_for_summon_sacrifice(card: Card, player: Player) -> bool:
	return card != null \
		and player != null \
		and card.card_type == Card.CardType.CREATURE \
		and not card.is_god \
		and card.can_be_used_for_creature_sacrifice \
		and card.get_controller() == player \
		and card.current_zone != null \
		and card.current_zone.is_board_zone()

func _get_active_altar_of_dreams(player: Player) -> AltarOfDreams:
	if player == null:
		return null
	for zone in player.power_zones:
		if zone == null or zone.cards.is_empty():
			continue
		var altar := zone.cards[0] as AltarOfDreams
		if altar != null and not altar.is_face_down:
			return altar
	return null

func _resolve_authoritative_creature_summon_sacrifices(
	sacrifices: Array[Card],
	summoned_card: Card,
	on_complete: Callable,
	index: int = 0
) -> void:
	if index >= sacrifices.size():
		if on_complete.is_valid():
			on_complete.call()
		return
	var sacrificed := sacrifices[index]
	if not _can_use_creature_for_summon_sacrifice(sacrificed, sacrificed.get_controller() if sacrificed != null else null):
		move_failed.emit("Selected summon sacrifice is no longer valid.")
		return
	var finish := func() -> void:
		var paid := not is_instance_valid(sacrificed) \
			or sacrificed.current_zone == null \
			or not sacrificed.current_zone.is_board_zone()
		if not paid:
			move_failed.emit("%s could not be sacrificed for %s." % [
				sacrificed.card_name if sacrificed != null else "Selected creature",
				summoned_card.card_name if summoned_card != null else "that summon"
			])
			return
		if sacrificed != null and sacrificed.has_method("on_sacrificed_for_summon") and not sacrificed.abilities_suppressed():
			sacrificed.on_sacrificed_for_summon(game_manager, summoned_card)
		_resolve_authoritative_creature_summon_sacrifices(sacrifices, summoned_card, on_complete, index + 1)
	game_manager.request_send_to_graveyard(sacrificed, finish, false, false)

func _clear_pending_authoritative_blot_cast() -> void:
	pending_blot_spell = null
	pending_blot_sacrifice_target = null
	pending_blot_selected_creatures.clear()
	pending_blot_costs_paid = false
	pending_blot_display_zone = null
	pending_blot_cast_command.clear()

func _begin_authoritative_blot_cast(
	spell: BlotSacrifice,
	player: Player,
	sacrifice_target: Card,
	prepared_spell: bool,
	command: Dictionary
) -> bool:
	if spell == null or player == null:
		move_failed.emit("Blot Sacrifice could not identify its caster.")
		return false
	if pending_blot_spell != null:
		move_failed.emit("Another Blot Sacrifice payment is still resolving.")
		return false
	if not _can_use_creature_for_summon_sacrifice(sacrifice_target, player):
		move_failed.emit("Blot Sacrifice requires a valid friendly creature sacrifice.")
		return false
	var original_sacrifice_cost := spell.sacrifice_cost
	spell.sacrifice_cost = 0
	var paid := false
	if prepared_spell:
		if not spell.can_activate_prepared(game_manager, player):
			spell.sacrifice_cost = original_sacrifice_cost
			move_failed.emit(_get_move_activation_failure_reason(spell, true, player))
			return false
		paid = game_manager.activate_prepared_card(spell, player)
	else:
		var play_failure_reason := game_manager.get_play_card_failure_reason(player, spell, null)
		if not play_failure_reason.is_empty():
			spell.sacrifice_cost = original_sacrifice_cost
			move_failed.emit(play_failure_reason)
			return false
		var mana_required := game_manager.get_card_play_mana_cost(player, spell, false)
		paid = spell.pay_costs_with_mana_cost(player, mana_required, game_manager)
		if paid and mana_required < spell.mana_cost:
			game_manager.claim_cost_adjustments(
				spell,
				spell.mana_cost,
				Card.COST_KIND_HAND_PLAY,
				{"player": player, "prepared": false}
			)
	spell.sacrifice_cost = original_sacrifice_cost
	spell.clear_pending_chosen_sacrifices()
	if not paid:
		move_failed.emit(_get_move_cost_payment_failure_reason(spell, prepared_spell, player))
		return false
	pending_blot_spell = spell
	pending_blot_sacrifice_target = sacrifice_target
	pending_blot_costs_paid = true
	pending_blot_display_zone = spell.current_zone if prepared_spell else _resolve_command_display_zone(command, player)
	pending_blot_cast_command = command.duplicate(true)
	var finish_sacrifice := func() -> void:
		var sacrifice_paid := not is_instance_valid(sacrifice_target) \
			or sacrifice_target.current_zone == null \
			or not sacrifice_target.current_zone.is_board_zone()
		if not sacrifice_paid:
			_clear_pending_authoritative_blot_cast()
			move_failed.emit("%s could not be sacrificed for Blot Sacrifice." % sacrifice_target.card_name)
			return
		# Perish hooks schedule their selectors when the card reaches the
		# graveyard. Queue Blot on the following frame so that selector becomes
		# the active authoritative prompt first.
		move_validated.emit(pending_blot_cast_command)
		call_deferred("_try_queue_pending_authoritative_blot_action")
	game_manager.request_send_to_graveyard(sacrifice_target, finish_sacrifice, false, false)
	return true

func _try_queue_pending_authoritative_blot_action() -> void:
	if pending_blot_spell == null \
			or not _pending_ui_interactions.is_empty() \
			or not _queued_ui_interactions.is_empty():
		return
	_queue_pending_authoritative_blot_action()

func _queue_pending_authoritative_blot_action() -> void:
	var spell := pending_blot_spell
	var sacrifice_target := pending_blot_sacrifice_target
	var display_zone := pending_blot_display_zone
	_clear_pending_authoritative_blot_cast()
	if spell == null or game_manager == null or game_manager.is_game_over:
		return
	var action := CardAction.new()
	action.type = CardAction.Type.SPELL
	action.source_player = spell.card_owner
	action.card = spell
	action.display_zone = display_zone
	action.resolution_text = "Blot Sacrifice resolves."
	action.event_data["linger_for_visibility"] = true
	action.resolve_callback = func() -> void:
		game_manager.notify_spell_played(spell.card_owner, spell)
		if spell.get_available_summon_zones().is_empty():
			if spell.should_go_to_graveyard() and spell.current_zone != spell.card_owner.graveyard_zone:
				spell.card_owner.move_card(spell, spell.card_owner.graveyard_zone)
			game_manager.note_player_feedback("Blot Sacrifice resolved, but no open zone was available.")
			return
		if spell.get_valid_hand_creatures(BlotSacrifice.MAX_SUMMON_LEVELS, []).is_empty():
			if spell.should_go_to_graveyard() and spell.current_zone != spell.card_owner.graveyard_zone:
				spell.card_owner.move_card(spell, spell.card_owner.graveyard_zone)
			game_manager.note_player_feedback("Blot Sacrifice resolved, but there were no valid creatures in hand to summon.")
			return
		_mark_deferred_authoritative_action(action, "blot_sacrifice_choice")
		_emit_ui_interaction_for_player(spell.card_owner, "blot_sacrifice", {
			"source_uid": spell.uid,
			"sacrifice_target_uid": sacrifice_target.uid if sacrifice_target != null else "",
		})
	_assign_stack_display_zone(action, display_zone)
	game_manager.push_to_stack(action)
	move_validated.emit({
		"type": "blot_sacrifice_queued",
		"source_uid": spell.uid,
	})
	_advance_authoritative_priority()

func _get_valid_authoritative_blot_choices(spell: BlotSacrifice, raw_uids: Array) -> Dictionary:
	var result := {
		"ok": false,
		"reason": "Blot Sacrifice received an invalid creature selection.",
		"cards": [],
	}
	if spell == null:
		return result
	var selected: Array[Card] = []
	var seen_uids := {}
	var remaining_levels := BlotSacrifice.MAX_SUMMON_LEVELS
	var available_slots := spell.get_available_summon_zones().size()
	for raw_uid in raw_uids:
		var uid := str(raw_uid).strip_edges()
		if uid == "" or seen_uids.has(uid):
			result["reason"] = "Blot Sacrifice choices must be unique creatures."
			return result
		if selected.size() >= available_slots:
			result["reason"] = "Blot Sacrifice selected more creatures than there are open zones."
			return result
		var creature := game_manager.get_card_by_uid(uid)
		if creature == null or creature not in spell.get_valid_hand_creatures(remaining_levels, selected):
			result["reason"] = "Blot Sacrifice selected a creature that is no longer summonable."
			return result
		seen_uids[uid] = true
		selected.append(creature)
		remaining_levels -= creature.get_effective_level()
	result["ok"] = true
	result["reason"] = ""
	result["cards"] = selected
	return result

func _get_required_player_for_command(command: Dictionary) -> Player:
	return MatchCommandRegistryScript.get_required_player(command, game_manager, self)

func _send_rejection_to_sender(sender_info: Dictionary, reason: String) -> void:
	if sender_info.is_empty() or network_manager == null or not network_manager.is_server:
		return
	var peer_id := int(sender_info.get("peer_id", -1))
	if peer_id <= 1:
		return
	network_manager.broadcast_event_to_peer(peer_id, "command_rejected", {"reason": reason})

func _validate_sender_authority(command: Dictionary, sender_info: Dictionary) -> String:
	if sender_info.is_empty():
		return ""
	var sender_player := _resolve_sender_player(sender_info)
	if sender_player == null:
		return "Unauthorized command: unknown player."
	var required_player := _get_required_player_for_command(command)
	if required_player == null:
		return ""
	if sender_player != required_player:
		if str(command.get("type", "")) == "combat_retreat_decision":
			return "Waiting for %s to decide Tactical Retreat." % required_player.player_name
		return "Unauthorized command: that action belongs to %s." % required_player.player_name
	return ""

func _get_command_actor(sender_info: Dictionary) -> Player:
	var sender_player := _resolve_sender_player(sender_info)
	return sender_player if sender_player != null else game_manager.current_player

func _requires_resolved_upkeep(command: Dictionary) -> bool:
	return MatchCommandRegistryScript.requires_resolved_upkeep(command)

func _requires_clear_stack_window(command_type: String) -> bool:
	return MatchCommandRegistryScript.requires_clear_stack_window(command_type)

func _validate_turn_action_window(command: Dictionary, sender_info: Dictionary) -> String:
	var command_type := str(command.get("type", ""))
	if _requires_clear_stack_window(command_type):
		if is_targeting_active() or _has_pending_reveal_target_ui_interaction():
			return "Choose a target for %s before continuing." % get_targeting_name()
		if _uses_authoritative_headless_priority_flow():
			_try_drain_authoritative_event_stack_without_prompt()
		if _has_unresolved_stack_action_window():
			if _uses_authoritative_headless_priority_flow():
				call_deferred("_resume_authoritative_flow_after_prompt_command")
			return "Resolve the pending stack action before continuing."
	var actor := _get_command_actor(sender_info)
	if actor == null:
		return ""
	if _requires_resolved_upkeep(command) and actor == game_manager.current_player and not game_manager.has_resolved_turn_upkeep():
		return "Resolve upkeep before taking other actions."
	return ""

func _should_turn_action_decline_priority(command: Dictionary, sender_info: Dictionary) -> bool:
	if game_manager == null or not _uses_authoritative_headless_priority_flow():
		return false
	var command_type := str(command.get("type", ""))
	if not _requires_clear_stack_window(command_type):
		return false
	if is_targeting_active() or _has_pending_reveal_target_ui_interaction():
		return false
	if game_manager.action_stack.is_empty():
		return false
	if _authoritative_stack_resolution_pending or not game_manager.resolving_stack_actions.is_empty():
		return false
	var actor := _get_command_actor(sender_info)
	return actor != null \
		and actor == game_manager.current_player \
		and actor == game_manager.priority_player

func _complete_turn_action_priority_decline(actor: Player) -> void:
	if game_manager == null or game_manager.action_stack.is_empty():
		_clear_priority_window_state()
		return
	if game_manager.both_passed():
		_resolve_authoritative_stack_top_after_priority()
		return
	var waiting_player := game_manager.priority_player
	var top_action: CardAction = game_manager.action_stack.back()
	if waiting_player != null \
			and waiting_player != actor \
			and not player_requires_priority_window(top_action, waiting_player) \
			and not _player_has_priority_prompt_responses(waiting_player):
		game_manager.pass_priority()
		_resolve_authoritative_stack_top_after_priority()
		return
	_advance_authoritative_priority()

func _decline_priority_for_turn_action(command: Dictionary, sender_info: Dictionary) -> bool:
	if not _should_turn_action_decline_priority(command, sender_info):
		return false
	var actor := _get_command_actor(sender_info)
	_remember_turn_action_after_priority(command, sender_info)
	_consume_pending_ui_interaction_for_player(actor, "priority")
	game_manager.pass_priority()
	move_validated.emit({type = "priority_pass"})
	_complete_turn_action_priority_decline(actor)
	_request_ui_refresh()
	return true

func _validate_upkeep_choice_window(actor: Player) -> String:
	if game_manager == null or actor == null:
		return ""
	if actor != game_manager.current_player:
		return "It is not your turn."
	if not game_manager.is_player_in_upkeep_window(actor):
		return "Upkeep has already been resolved."
	return ""

func _clear_pending_turn_action_after_opponent_priority() -> void:
	_pending_turn_action_after_opponent_priority_command.clear()
	_pending_turn_action_after_opponent_priority_sender_info.clear()

func _remember_turn_action_after_priority(command: Dictionary, sender_info: Dictionary) -> void:
	if _replaying_turn_action_after_opponent_priority:
		return
	_pending_turn_action_after_opponent_priority_command = command.duplicate(true)
	_pending_turn_action_after_opponent_priority_sender_info = sender_info.duplicate(true)

func _has_pending_turn_action_after_opponent_priority() -> bool:
	return not _pending_turn_action_after_opponent_priority_command.is_empty()

func _clear_pending_turn_action_after_priority_response(responding_player: Player) -> void:
	if not _has_pending_turn_action_after_opponent_priority():
		return
	var pending_actor := _get_pending_turn_action_after_opponent_priority_actor()
	if pending_actor == null or responding_player == null or pending_actor != responding_player:
		_clear_pending_turn_action_after_opponent_priority()

func _should_defer_turn_action_until_opponent_priority_declines(command: Dictionary, sender_info: Dictionary) -> bool:
	if _replaying_turn_action_after_opponent_priority:
		return false
	if game_manager == null or not _uses_authoritative_headless_priority_flow():
		return false
	var command_type := str(command.get("type", ""))
	if not _requires_clear_stack_window(command_type):
		return false
	if is_targeting_active() or _has_pending_reveal_target_ui_interaction():
		return false
	if game_manager.action_stack.is_empty():
		return false
	if _authoritative_stack_resolution_pending or not game_manager.resolving_stack_actions.is_empty():
		return false
	var actor := _get_command_actor(sender_info)
	return actor != null \
		and actor == game_manager.current_player \
		and game_manager.priority_player != null \
		and game_manager.priority_player != actor

func _defer_turn_action_until_opponent_priority_declines(command: Dictionary, sender_info: Dictionary) -> bool:
	if not _should_defer_turn_action_until_opponent_priority_declines(command, sender_info):
		return false
	_remember_turn_action_after_priority(command, sender_info)
	call_deferred("_advance_authoritative_priority")
	_request_ui_refresh()
	return true

func _get_pending_turn_action_after_opponent_priority_actor() -> Player:
	if not _has_pending_turn_action_after_opponent_priority():
		return null
	var sender_player := _resolve_sender_player(_pending_turn_action_after_opponent_priority_sender_info)
	return sender_player if sender_player != null else game_manager.current_player

func _try_pass_pending_turn_action_actor_priority() -> bool:
	if game_manager == null or not _has_pending_turn_action_after_opponent_priority():
		return false
	if game_manager.action_stack.is_empty() or _authoritative_stack_resolution_pending:
		return false
	var actor := _get_pending_turn_action_after_opponent_priority_actor()
	if actor == null or actor != game_manager.current_player or actor != game_manager.priority_player:
		return false
	game_manager.pass_priority()
	move_validated.emit({type = "priority_pass"})
	if game_manager.both_passed():
		if not game_manager.action_stack.is_empty():
			_schedule_authoritative_stack_top_after_priority()
		else:
			_clear_priority_window_state()
	else:
		_advance_authoritative_priority()
	_request_ui_refresh()
	return true

func _try_process_pending_turn_action_after_opponent_priority() -> void:
	if _replaying_turn_action_after_opponent_priority or not _has_pending_turn_action_after_opponent_priority():
		return
	if game_manager == null:
		_clear_pending_turn_action_after_opponent_priority()
		return
	if _has_unresolved_stack_action_window():
		return
	var command := _pending_turn_action_after_opponent_priority_command.duplicate(true)
	var sender_info := _pending_turn_action_after_opponent_priority_sender_info.duplicate(true)
	_clear_pending_turn_action_after_opponent_priority()
	_replaying_turn_action_after_opponent_priority = true
	process_command(command, sender_info)
	_replaying_turn_action_after_opponent_priority = false

func _on_move_failed(reason: String) -> void:
	last_move_failed_reason = reason
	_log_authoritative_flow_state("command:failed type=%s reason=%s" % [
		_active_command_type,
		reason,
	])
	_send_rejection_to_sender(_active_command_sender_info, reason)

func _get_move_play_failure_reason(card: Card, player: Player, target_zone: Zone = null) -> String:
	if card != null and game_manager != null:
		var reason := game_manager.get_play_card_failure_reason(player, card, target_zone)
		if reason.strip_edges() != "":
			return reason
	return ("%s play was rejected without a rules reason." % card.card_name) if card != null else "This play was rejected without a rules reason."

func _get_move_activation_failure_reason(card: Card, prepared: bool = false, player: Player = null) -> String:
	if card == null:
		return "Activation was rejected without a rules reason."
	var acting_player := player
	if acting_player == null:
		acting_player = card.card_owner
	if game_manager != null and game_manager._has_pending_stack_action_for_card(card):
		return card.card_name + " is already waiting to resolve."
	if game_manager != null and game_manager.has_insufficient_activation_mana(card, prepared, acting_player):
		return game_manager.get_activation_mana_unavailable_text(card)
	if prepared and game_manager != null:
		var play_reason := game_manager.get_play_card_failure_reason(acting_player, card, null)
		if play_reason.strip_edges() != "":
			return play_reason
	if card.has_method("get_activation_failure_reason"):
		var activation_reason := str(card.call("get_activation_failure_reason", game_manager))
		if activation_reason.strip_edges() != "":
			return activation_reason
	return "%s activation was rejected without a rules reason." % card.card_name

func _get_move_cost_payment_failure_reason(card: Card, prepared: bool = false, player: Player = null) -> String:
	if card == null:
		return "Cost payment failed."
	var acting_player := player
	if acting_player == null:
		acting_player = card.card_owner
	if game_manager != null and game_manager.has_insufficient_activation_mana(card, prepared, acting_player):
		return game_manager.get_activation_mana_unavailable_text(card)
	return "%s cost payment failed." % card.card_name

# --- Network Command Support ---

## Entry point for commands from the network.
## Commands are Dictionaries containing "type" and relevant IDs.
## Returns true on success, false on failure (failure also emits move_failed).
func process_command(command: Dictionary, sender_info: Dictionary = {}) -> bool:
	_active_command_sender_info = sender_info.duplicate(true)
	_active_command_type = str(command.get("type", ""))
	_active_command_pending_prompt_id = -1
	if _uses_authoritative_headless_priority_flow():
		_log_authoritative_flow_state("command:start type=%s peer=%s player_index=%s keys=%s" % [
			_active_command_type,
			str(sender_info.get("peer_id", "")),
			str(sender_info.get("player_index", "")),
			str(command.keys()),
		])
	if not MatchCommandRegistryScript.is_known_command_type(_active_command_type):
		move_failed.emit("Unknown command type: " + str(command.get("type")))
		_active_command_sender_info.clear()
		_active_command_type = ""
		_active_command_pending_prompt_id = -1
		return false
	if _accept_redundant_priority_pass(command, sender_info):
		_active_command_sender_info.clear()
		_active_command_type = ""
		_active_command_pending_prompt_id = -1
		return true
	var authority_error := _validate_sender_authority(command, sender_info)
	if not authority_error.is_empty():
		move_failed.emit(authority_error)
		_active_command_sender_info.clear()
		_active_command_type = ""
		_active_command_pending_prompt_id = -1
		return false
	if _defer_turn_action_until_opponent_priority_declines(command, sender_info):
		_log_authoritative_flow_state("command:deferred_until_opponent_priority type=%s" % _active_command_type)
		_active_command_sender_info.clear()
		_active_command_type = ""
		_active_command_pending_prompt_id = -1
		return true
	if _decline_priority_for_turn_action(command, sender_info):
		_log_authoritative_flow_state("command:declined_priority type=%s" % _active_command_type)
		_active_command_sender_info.clear()
		_active_command_type = ""
		_active_command_pending_prompt_id = -1
		return true
	var turn_window_error := _validate_turn_action_window(command, sender_info)
	if not turn_window_error.is_empty():
		if _uses_authoritative_headless_priority_flow() and _requires_clear_stack_window(_active_command_type):
			_log_authoritative_flow_state("command_rejected %s: %s" % [
				_active_command_type,
				turn_window_error,
			])
		move_failed.emit(turn_window_error)
		_active_command_sender_info.clear()
		_active_command_type = ""
		_active_command_pending_prompt_id = -1
		return false
	var pending_prompt_validation := _validate_pending_ui_interaction_for_command(command)
	var pending_prompt_error := str(pending_prompt_validation.get("error", ""))
	if not pending_prompt_error.is_empty():
		move_failed.emit(pending_prompt_error)
		_active_command_sender_info.clear()
		_active_command_type = ""
		_active_command_pending_prompt_id = -1
		return false
	var pending_prompt_id := int(pending_prompt_validation.get("prompt_id", -1))
	_active_command_pending_prompt_id = pending_prompt_id
	var result := _process_command_impl(command)
	if _uses_authoritative_headless_priority_flow():
		_log_authoritative_flow_state("command:processed type=%s result=%s prompt_id=%d" % [
			_active_command_type,
			str(result),
			_active_command_pending_prompt_id,
		])
	if result:
		_complete_simple_deferred_prompt_action_for_command(command)
		if not _consume_active_command_prompt_for_completion(_active_command_type):
			_consume_matching_pending_ui_interaction_for_command(command)
	_active_command_sender_info.clear()
	_active_command_type = ""
	_active_command_pending_prompt_id = -1
	if result and _pending_ui_interactions.is_empty() and not _queued_ui_interactions.is_empty():
		_release_next_queued_ui_interaction()
	elif result:
		call_deferred("_resume_authoritative_flow_after_prompt_command")
	return result

func _accept_redundant_priority_pass(command: Dictionary, sender_info: Dictionary) -> bool:
	if str(command.get("type", "")) != "priority_pass":
		return false
	if game_manager == null or not _uses_authoritative_headless_priority_flow():
		return false
	var priority_cleared := game_manager.priority_player == null or game_manager.action_stack.is_empty()
	if not priority_cleared and not _authoritative_stack_resolution_pending:
		return false
	var sender_player := _resolve_sender_player(sender_info)
	if not sender_info.is_empty() and sender_player == null:
		return false
	if sender_player != null:
		_consume_pending_ui_interaction_for_player(sender_player, "priority")
	_log_authoritative_flow_state("command:redundant_priority_pass_accepted")
	_request_ui_refresh()
	return true

func _process_command_impl(command: Dictionary) -> bool:
	var acting_player := _get_command_actor(_active_command_sender_info)
	match command.get("type", ""):
		"set_priority_preferences":
			var preference_player := acting_player
			var preference_player_idx := int(command.get("player_index", -1))
			if preference_player_idx >= 0 and preference_player_idx < game_manager.players.size():
				preference_player = game_manager.players[preference_player_idx]
			if preference_player == null:
				move_failed.emit("set_priority_preferences: player not found")
				return false
			var priority_stops = command.get("stops", {})
			if not (priority_stops is Dictionary):
				move_failed.emit("set_priority_preferences: invalid stops")
				return false
			var god_specific = command.get("god_specific", {})
			if not (god_specific is Dictionary):
				move_failed.emit("set_priority_preferences: invalid god settings")
				return false
			var card_offer_priority = command.get("card_offer_priority", {})
			if not (card_offer_priority is Dictionary):
				move_failed.emit("set_priority_preferences: invalid card priority settings")
				return false
			set_priority_preferences(
				preference_player,
				priority_stops as Dictionary,
				bool(command.get("full_control", false)),
				str(command.get("auto_mode", PRIORITY_AUTO_MODE_NONE)),
				god_specific as Dictionary,
				card_offer_priority as Dictionary
			)
			return true
		"select_attacker":
			var uid = command.get("card_uid", "")
			var card = game_manager.get_card_by_uid(uid)
			select_attacker(card)
			return true
		"request_attack":
			var attacker_uid = command.get("attacker_uid", "")
			var target_id = command.get("target_id", "") # Can be card UID or player name/index
			return request_attack(attacker_uid, target_id)
		"cancel_targeting":
			cancel_targeting()
			return true
		"confirm_click_selection":
			var target_uid = command.get("target_uid", "")
			var target = game_manager.get_card_by_uid(target_uid)
			# Fallback to player search if not a card
			if target == null:
				var player_idx = command.get("player_index", -1)
				if player_idx >= 0 and player_idx < game_manager.players.size():
					target = game_manager.players[player_idx]
			confirm_click_selection(target)
			return true
		"play_card":
			var card := game_manager.get_card_by_uid(command.get("card_uid", ""))
			var zone := resolve_zone(command)
			if card == null:
				move_failed.emit("play_card: card not found")
				return false
			var play_failure_reason := game_manager.get_play_card_failure_reason(acting_player, card, zone)
			if not play_failure_reason.is_empty():
				move_failed.emit(play_failure_reason)
				return false
			game_manager.play_card(acting_player, card, zone)
			move_validated.emit(command)
			return true
		"apply_advanced_building_techniques":
			var power_uid := str(command.get("power_uid", "")).strip_edges()
			var structure_uid := str(command.get("structure_uid", "")).strip_edges()
			var mana_to_spend := int(command.get("mana_to_spend", 0))
			var power := game_manager.get_card_by_uid(power_uid) as AdvancedBuildingTechniques
			var structure := game_manager.get_card_by_uid(structure_uid)
			if power == null or structure == null:
				move_failed.emit("Advanced Building Techniques: card not found")
				return false
			if acting_player != null and power.card_owner != acting_player:
				move_failed.emit("Advanced Building Techniques: wrong controller")
				return false
			if not power.can_offer_structure_bonus(structure, game_manager):
				move_failed.emit("Advanced Building Techniques bonus is no longer available.")
				return false
			power.apply_structure_bonus(structure, mana_to_spend, game_manager)
			move_validated.emit(command)
			return true
		"prepare_card":
			var card := game_manager.get_card_by_uid(command.get("card_uid", ""))
			var zone := resolve_zone(command)
			if card == null:
				move_failed.emit("prepare_card: card not found")
				return false
			var prepare_failure_reason := game_manager.get_prepare_card_failure_reason(acting_player, card, zone)
			if not prepare_failure_reason.is_empty():
				move_failed.emit(prepare_failure_reason)
				return false
			game_manager.prepare_card(acting_player, card, zone)
			move_validated.emit(command)
			return true
		"creature_move":
			var card := game_manager.get_card_by_uid(command.get("card_uid", ""))
			var zone := resolve_zone(command)
			if card == null or zone == null:
				move_failed.emit("creature_move: invalid card or zone")
				return false
			if not game_manager.creature_move(card, zone):
				move_failed.emit("Invalid move - must be an adjacent empty zone.")
				return false
			move_validated.emit(command)
			return true
		"equip_action":
			var card := game_manager.get_card_by_uid(command.get("card_uid", ""))
			var equipment := game_manager.get_card_by_uid(command.get("equipment_uid", ""))
			var action: String = command.get("action", "pick_up")
			if card == null or equipment == null:
				move_failed.emit("equip_action: invalid card or equipment")
				return false
			if not game_manager.resolve_creature_equipment_action(card, equipment, action):
				move_failed.emit("equip_action failed")
				return false
			move_validated.emit(command)
			return true
		"change_mode":
			var card := game_manager.get_card_by_uid(command.get("card_uid", ""))
			if card == null:
				move_failed.emit("change_mode: card not found")
				return false
			var mode = command.get("mode", -1)
			if not game_manager.creature_change_mode(card, mode):
				move_failed.emit("Cannot change mode for " + card.card_name)
				return false
			move_validated.emit(command)
			return true
		"end_turn":
			if acting_player != game_manager.current_player:
				move_failed.emit("It is not your turn.")
				return false
			var et_discard_uids: Array = command.get("discard_uids", [])
			var et_discard_validation := _validate_end_turn_discards(acting_player, et_discard_uids)
			if not bool(et_discard_validation.get("ok", false)):
				move_failed.emit(str(et_discard_validation.get("reason", "end_turn: invalid discard selection")))
				return false
			for et_card in et_discard_validation.get("cards", []):
				acting_player.discard_card(et_card)
			move_validated.emit(command)
			if _check_for_next_resurrection():
				_pending_end_turn_after_resurrection = true
				return true
			_finalize_pending_end_turn(acting_player)
			return true
		"upkeep_choice":
			var upkeep_window_error := _validate_upkeep_choice_window(acting_player)
			if not upkeep_window_error.is_empty():
				move_failed.emit(upkeep_window_error)
				return false
			match command.get("choice", ""):
				"draw":
					game_manager.player_chooses_draw()
				"mana":
					game_manager.player_chooses_mana()
				"skip":
					game_manager.player_chooses_upkeep_only()
				_:
					move_failed.emit("upkeep_choice: unknown choice '" + str(command.get("choice")) + "'")
					return false
			var choice_feedback := ""
			if _uses_authoritative_headless_priority_flow():
				choice_feedback = _build_upkeep_resolution_feedback(
					game_manager.get_upkeep_choice_feedback(str(command.get("choice", "")))
				)
				if not choice_feedback.strip_edges().is_empty():
					choice_feedback = "%s upkeep: %s" % [acting_player.player_name, choice_feedback]
					command["public_log_message"] = choice_feedback
			move_validated.emit(command)
			if _uses_authoritative_headless_priority_flow():
				_begin_or_continue_authoritative_turn_start_sequence(choice_feedback)
			return true
		"tiamat_upkeep_choice":
			var tiamat_upkeep_error := _validate_upkeep_choice_window(acting_player)
			if not tiamat_upkeep_error.is_empty():
				move_failed.emit(tiamat_upkeep_error)
				return false
			var tiamat_card_uid := str(command.get("card_uid", "")).strip_edges()
			var tiamat_card := game_manager.get_card_by_uid(tiamat_card_uid)
			if tiamat_card == null:
				move_failed.emit("Matriarch Rule: card not found.")
				return false
			if not TiamatScript.resolve_matriarch_rule(game_manager, tiamat_card):
				move_failed.emit("Matriarch Rule is not available for that card.")
				return false
			command["public_log_message"] = "Matriarch Rule added %s to %s's hand." % [
				tiamat_card.card_name,
				game_manager.current_player.player_name
			]
			game_manager.player_chooses_upkeep_only()
			move_validated.emit(command)
			if _uses_authoritative_headless_priority_flow():
				var tiamat_feedback := _build_upkeep_resolution_feedback(
					"Matriarch Rule returned %s to hand." % tiamat_card.card_name
				)
				_begin_or_continue_authoritative_turn_start_sequence(tiamat_feedback)
			return true
		"forfeit":
			if game_manager.is_game_over:
				move_failed.emit("The game is already over.")
				return false
			var forfeiting_player: Player = acting_player
			var forfeiting_index := int(command.get("player_index", -1))
			if forfeiting_index >= 0 and forfeiting_index < game_manager.players.size():
				forfeiting_player = game_manager.players[forfeiting_index]
			if forfeiting_player == null:
				move_failed.emit("forfeit: player not found")
				return false
			game_manager.forfeit_game(forfeiting_player)
			move_validated.emit(command)
			return true
		"forfeit_match":
			if game_manager.is_game_over:
				move_failed.emit("The game is already over.")
				return false
			var match_forfeiting_player: Player = acting_player
			var match_forfeiting_index := int(command.get("player_index", -1))
			if match_forfeiting_index >= 0 and match_forfeiting_index < game_manager.players.size():
				match_forfeiting_player = game_manager.players[match_forfeiting_index]
			if match_forfeiting_player == null:
				move_failed.emit("forfeit_match: player not found")
				return false
			game_manager.forfeit_match(match_forfeiting_player)
			move_validated.emit(command)
			return true
		"submit_reinforcements":
			move_failed.emit("Reinforcement changes are only available between games in a series.")
			return false
		"play_creature":
			var card := game_manager.get_card_by_uid(command.get("card_uid", ""))
			var zone := resolve_zone(command)
			var mode: Card.CreatureMode = int(command.get("mode", Card.CreatureMode.DEFENSIVE)) as Card.CreatureMode
			var stealth: bool = command.get("stealth", false)
			var sacrifice_cards := _resolve_cards_by_uids(command.get("sacrifice_uids", []))
			var altar_void_cards := _resolve_cards_by_uids(command.get("altar_void_uids", []))
			if card == null or zone == null:
				move_failed.emit("play_creature: invalid card or zone")
				return false
			var original_sacrifice_cost := card.sacrifice_cost
			var using_altar_void := not altar_void_cards.is_empty()
			if using_altar_void and not sacrifice_cards.is_empty():
				move_failed.emit("Choose either sacrifices or Altar of Dreams targets, not both.")
				return false
			if original_sacrifice_cost > 0:
				if using_altar_void:
					if altar_void_cards.size() != original_sacrifice_cost or not _cards_have_unique_uids(altar_void_cards):
						move_failed.emit("%s requires exactly %d unique Altar of Dreams target(s)." % [card.card_name, original_sacrifice_cost])
						return false
					var altar := _get_active_altar_of_dreams(acting_player)
					if altar == null or not altar.can_replace_sacrifice_cost(card, game_manager):
						move_failed.emit("Altar of Dreams cannot pay %s's summon cost right now." % card.card_name)
						return false
					for altar_target in altar_void_cards:
						if altar_target == null or altar_target.card_type != Card.CardType.CREATURE or not altar_target.is_sleeping:
							move_failed.emit("Altar of Dreams requires sleeping creature targets.")
							return false
				else:
					if sacrifice_cards.size() != original_sacrifice_cost or not _cards_have_unique_uids(sacrifice_cards):
						move_failed.emit("%s requires exactly %d unique summon sacrifice(s)." % [card.card_name, original_sacrifice_cost])
						return false
					for sacrifice_card in sacrifice_cards:
						if not _can_use_creature_for_summon_sacrifice(sacrifice_card, acting_player):
							move_failed.emit("Selected summon sacrifice is invalid for " + card.card_name + ".")
							return false
			if original_sacrifice_cost > 0 and (using_altar_void or not sacrifice_cards.is_empty()):
				card.sacrifice_cost = 0
			var play_failure_reason := game_manager.get_play_card_failure_reason(acting_player, card, zone)
			if not play_failure_reason.is_empty():
				card.sacrifice_cost = original_sacrifice_cost
				move_failed.emit(play_failure_reason)
				return false
			card.sacrifice_cost = original_sacrifice_cost
			var finish_creature_play := func() -> void:
				var summon_original_sacrifice_cost := card.sacrifice_cost
				if summon_original_sacrifice_cost > 0:
					card.sacrifice_cost = 0
				var success := game_manager.summon_creature_by_effect(
					acting_player, card, zone,
					mode, stealth, stealth,
					null, true, true, true
				)
				card.sacrifice_cost = summon_original_sacrifice_cost
				if not success:
					move_failed.emit("Summon failed for " + card.card_name)
					return
				move_validated.emit(command)
				_advance_authoritative_priority_for_pending_card_events(card)
			if original_sacrifice_cost <= 0:
				finish_creature_play.call()
				return true
			if using_altar_void:
				var active_altar := _get_active_altar_of_dreams(acting_player)
				if active_altar == null or not active_altar.pay_replacement_cost(card, altar_void_cards, game_manager):
					move_failed.emit("Altar of Dreams payment failed for " + card.card_name + ".")
					return false
				finish_creature_play.call()
				return true
			_resolve_authoritative_creature_summon_sacrifices(sacrifice_cards, card, finish_creature_play)
			return true
		"cast_spell":
			var spell_uid: String = command.get("spell_uid", "")
			var spell := game_manager.get_card_by_uid(spell_uid)
			if spell == null or not (spell is SpellCard):
				move_failed.emit("cast_spell: spell not found or not a SpellCard")
				return false
			var spell_target_uid: String = command.get("target_uid", "")
			var spell_target: Card = game_manager.get_card_by_uid(spell_target_uid) if spell_target_uid != "" else null
			var spell_ward_block_reason := game_manager.get_turn_destruction_ward_activation_block_reason(spell, spell_target)
			if spell_ward_block_reason != "":
				move_failed.emit(spell_ward_block_reason)
				return false
			var player := acting_player
			var prepared_spell := spell.is_prepared and spell.current_zone != null and spell.current_zone.is_board_zone()
			if _uses_authoritative_headless_priority_flow() and spell is BlotSacrifice:
				var blot_sacrifice_uid := str(command.get("sacrifice_uid", "")).strip_edges()
				var blot_sacrifice_target := game_manager.get_card_by_uid(blot_sacrifice_uid) if blot_sacrifice_uid != "" else null
				return _begin_authoritative_blot_cast(
					spell as BlotSacrifice,
					player,
					blot_sacrifice_target,
					prepared_spell,
					command
				)
			
			# Set chosen discards
			var discard_uids: Array = command.get("discard_uids", [])
			if discard_uids.size() > 0:
				var discard_cards: Array[Card] = []
				for discard_uid in discard_uids:
					var c := game_manager.get_card_by_uid(discard_uid as String)
					if c != null:
						discard_cards.append(c)
				spell.set_pending_chosen_discards(discard_cards)
			
			# Set chosen sacrifices
			var sacrifice_uid: String = command.get("sacrifice_uid", "")
			if spell.sacrifice_cost > 0:
				if sacrifice_uid == "":
					spell.clear_pending_chosen_sacrifices()
					move_failed.emit("%s requires a chosen sacrifice." % spell.card_name)
					return false
				var sac_card := game_manager.get_card_by_uid(sacrifice_uid)
				if sac_card == null:
					spell.clear_pending_chosen_sacrifices()
					move_failed.emit("%s sacrifice target was not found." % spell.card_name)
					return false
				spell.set_pending_chosen_sacrifices([sac_card])
			elif sacrifice_uid != "":
				var sac_card := game_manager.get_card_by_uid(sacrifice_uid)
				if sac_card != null:
					spell.set_pending_chosen_sacrifices([sac_card])
			else:
				spell.clear_pending_chosen_sacrifices()

			if prepared_spell:
				if not (spell as SpellCard).can_activate_prepared(game_manager, player):
					spell.clear_pending_chosen_sacrifices()
					move_failed.emit(_get_move_activation_failure_reason(spell, true, player))
					return false
				if not game_manager.activate_prepared_card(spell, player):
					spell.clear_pending_chosen_sacrifices()
					move_failed.emit(_get_move_cost_payment_failure_reason(spell, true, player))
					return false
			else:
				var play_failure_reason := game_manager.get_play_card_failure_reason(player, spell, null)
				if not play_failure_reason.is_empty():
					spell.clear_pending_chosen_sacrifices()
					move_failed.emit(play_failure_reason)
					return false
				var mana_required := game_manager.get_card_play_mana_cost(player, spell, false)
				if not spell.pay_costs_with_mana_cost(player, mana_required, game_manager):
					spell.clear_pending_chosen_sacrifices()
					move_failed.emit(_get_move_cost_payment_failure_reason(spell, false, player))
					return false
				if mana_required < spell.mana_cost:
					game_manager.claim_cost_adjustments(
						spell,
						spell.mana_cost,
						Card.COST_KIND_HAND_PLAY,
						{"player": player, "prepared": false}
					)
			if _uses_authoritative_headless_priority_flow():
				var spell_command_display_zone := _resolve_command_display_zone(command, player)
				var preferred_display_zone: Zone = spell.current_zone if prepared_spell else spell_command_display_zone
				var spell_resolve := func() -> void:
					game_manager.notify_spell_played(player, spell)
					(spell as SpellCard).resolve_from_command(game_manager, command)
					if (spell as SpellCard).should_go_to_graveyard() and spell.current_zone != player.graveyard_zone:
						player.move_card(spell, player.graveyard_zone)
				_queue_authoritative_magical_action(
					CardAction.Type.SPELL,
					spell,
					spell_target,
					spell_resolve,
					"",
					preferred_display_zone
				)
				_advance_authoritative_priority()
				move_validated.emit(command)
				return true
			game_manager.notify_spell_played(player, spell)
			game_manager.run_with_effect_source(
				spell,
				func() -> void:
					(spell as SpellCard).resolve_from_command(game_manager, command)
			)
			if (spell as SpellCard).should_go_to_graveyard() and spell.current_zone != player.graveyard_zone:
				player.move_card(spell, player.graveyard_zone)
			move_validated.emit(command)
			return true
		"blot_sacrifice_choice":
			var source_uid := str(command.get("source_uid", "")).strip_edges()
			var blot := game_manager.get_card_by_uid(source_uid) as BlotSacrifice
			_log_authoritative_flow_state("blot_choice:start source=%s choices=%s" % [
				source_uid,
				str(command.get("choices", [])),
			])
			if blot == null:
				move_failed.emit("blot_sacrifice_choice: spell not found")
				return false
			var pending_blot_action := _find_pending_deferred_action_for_source("blot_sacrifice_choice", blot)
			if pending_blot_action == null:
				move_failed.emit("blot_sacrifice_choice: no Blot Sacrifice choice is pending")
				return false
			var choice_result := _get_valid_authoritative_blot_choices(blot, command.get("choices", []))
			if not bool(choice_result.get("ok", false)):
				move_failed.emit(str(choice_result.get("reason", "Blot Sacrifice choices were invalid.")))
				return false
			var chosen_creatures: Array[Card] = []
			for chosen in choice_result.get("cards", []):
				if chosen is Card:
					chosen_creatures.append(chosen as Card)
			_log_authoritative_flow_state("blot_choice:before_summon chosen=%d pending_action=%s" % [
				chosen_creatures.size(),
				_get_action_debug_summary(pending_blot_action),
			])
			var summoned_creatures := blot.summon_selected_creatures(game_manager, chosen_creatures)
			_log_authoritative_flow_state("blot_choice:after_summon summoned=%d" % summoned_creatures.size())
			if blot.should_go_to_graveyard() and blot.current_zone != blot.card_owner.graveyard_zone:
				blot.card_owner.move_card(blot, blot.card_owner.graveyard_zone)
			var feedback := "Blot Sacrifice fizzled: no creatures chosen to summon."
			if not chosen_creatures.is_empty():
				feedback = "Blot Sacrifice summoned %d creature(s)." % summoned_creatures.size()
			command["public_log_message"] = feedback
			_log_authoritative_flow_state("blot_choice:before_complete feedback=%s" % feedback)
			_complete_deferred_prompt_action("blot_sacrifice_choice", blot, feedback, false)
			_log_authoritative_flow_state("blot_choice:after_complete")
			command["_suppress_full_state_broadcast"] = true
			move_validated.emit(command)
			return true
		"activate_prepared_hex":
			var hex_uid: String = command.get("hex_uid", "")
			var hex_card := game_manager.get_card_by_uid(hex_uid)
			if hex_card == null or not (hex_card is HexCard):
				move_failed.emit("activate_prepared_hex: hex not found")
				return false
			var hex := hex_card as HexCard
			if not hex.can_activate_prepared(game_manager, acting_player):
				move_failed.emit(_get_move_activation_failure_reason(hex, true, acting_player))
				return false
			if not game_manager.activate_prepared_card(hex, acting_player):
				move_failed.emit(_get_move_cost_payment_failure_reason(hex, true, acting_player))
				return false
			var hex_action := CardAction.new()
			hex_action.type = CardAction.Type.ABILITY
			hex_action.source_player = hex.card_owner
			hex_action.card = hex
			hex_action.resolution_text = hex.card_name + " resolved."
			game_manager.push_to_stack(hex_action)
			if _uses_authoritative_headless_priority_flow():
				_advance_authoritative_priority()
			move_validated.emit(command)
			return true
		"god_ability":
			var god_uid: String = command.get("god_uid", "")
			var god_card := game_manager.get_card_by_uid(god_uid)
			if god_card == null or not god_card.is_god:
				move_failed.emit("god_ability: god card not found")
				return false
			if not god_card.has_method("can_activate") or not god_card.can_activate(game_manager):
				var god_failure_reason: String = str(god_card.get_activation_failure_reason(game_manager)) if god_card.has_method("get_activation_failure_reason") else ""
				move_failed.emit(god_failure_reason if god_failure_reason != "" else god_card.card_name + " activation was rejected without a rules reason.")
				return false
			var target: Card = null
			var target_uid: String = command.get("target_uid", "")
			if target_uid != "":
				target = game_manager.get_card_by_uid(target_uid)
			var is_champions_call_command: bool = god_card.has_method("is_champions_call_command") and god_card.is_champions_call_command(command)
			if god_card.targets and target == null and not is_champions_call_command:
				move_failed.emit("god_ability: target card not found")
				return false
			if target != null and god_card.has_method("is_valid_activation_target") and not god_card.is_valid_activation_target(target):
				move_failed.emit("god_ability: invalid target")
				return false
			var god_ward_block_reason := game_manager.get_turn_destruction_ward_activation_block_reason(god_card, target)
			if god_ward_block_reason != "":
				move_failed.emit(god_ward_block_reason)
				return false
			if _uses_authoritative_headless_priority_flow():
				_queue_authoritative_magical_action(
					CardAction.Type.ABILITY,
					god_card,
					target,
					func() -> void:
						if god_card.has_method("activate_from_command"):
							god_card.activate_from_command(game_manager, command)
						else:
							god_card.activate(game_manager, target)
				)
				_advance_authoritative_priority()
				move_validated.emit(command)
				return true
			if god_card.has_method("activate"):
				game_manager.run_with_effect_source(
					god_card,
					func() -> void:
						if god_card.has_method("activate_from_command"):
							god_card.activate_from_command(game_manager, command)
						else:
							god_card.activate(game_manager, target)
				)
			move_validated.emit(command)
			return true
		"activate_power":
			var power_uid: String = command.get("power_uid", "")
			var power_card := game_manager.get_card_by_uid(power_uid)
			if power_card == null or not (power_card is PowerCard):
				move_failed.emit("activate_power: power card not found")
				return false
			var act_target: Card = null
			var act_target_uid: String = command.get("target_uid", "")
			if act_target_uid != "":
				act_target = game_manager.get_card_by_uid(act_target_uid)
			var power_ward_block_reason := game_manager.get_turn_destruction_ward_activation_block_reason(power_card, act_target)
			if power_ward_block_reason != "":
				move_failed.emit(power_ward_block_reason)
				return false
			var act_mode: String = command.get("mode", "")
			if act_mode == "return_priest":
				if not (power_card is Breidablik):
					move_failed.emit("activate_power: return_priest requires Breidablik")
					return false
				var breidablik := power_card as Breidablik
				if not breidablik.can_return_priest(game_manager):
					move_failed.emit(power_card.card_name + " cannot return a priest right now.")
					return false
				if act_target == null:
					act_target = breidablik.get_stored_priest_by_uid_or_index(
						act_target_uid,
						int(command.get("stored_priest_index", -1))
					)
				game_manager.push_effect_source_card(power_card)
				var returned := breidablik.return_priest(game_manager, act_target)
				game_manager.pop_effect_source_card()
				if not returned:
					move_failed.emit(power_card.card_name + " could not return that priest.")
					return false
				command["public_log_message"] = "%s returned %s." % [
					power_card.card_name,
					act_target.card_name if act_target != null else "that Priest"
				]
			else:
				if not power_card.can_activate(game_manager):
					move_failed.emit(_get_move_activation_failure_reason(power_card, false, power_card.card_owner))
					return false
				var activation_command := command.duplicate(true)
				if power_card is Breidablik:
					var breidablik := power_card as Breidablik
					act_target = breidablik.resolve_harbor_target(act_target)
					if act_target == null and command.get("target_zone", {}) is Dictionary:
						var target_zone := resolve_zone(command.get("target_zone", {}) as Dictionary)
						var target_zone_card_index := int(command.get("target_zone_card_index", -1))
						if target_zone != null and target_zone_card_index >= 0 and target_zone_card_index < target_zone.cards.size():
							act_target = breidablik.resolve_harbor_target(target_zone.cards[target_zone_card_index])
					if act_target == null:
						move_failed.emit(power_card.card_name + " needs a friendly Priest that has not attacked this turn.")
						return false
				if _uses_authoritative_headless_priority_flow():
					if power_card is Breidablik:
						var queued_breidablik := power_card as Breidablik
						var queued_priest := act_target
						var breidablik_uid: String = str(power_card.uid)
						var priest_uid: String = str(act_target.uid)
						var priest_name: String = str(act_target.card_name)
						var priest_zone := act_target.current_zone
						var priest_zone_card_index := priest_zone.cards.find(act_target) if priest_zone != null else -1
						_queue_authoritative_magical_action(
							CardAction.Type.ABILITY,
							power_card,
							act_target,
							func() -> void:
								var live_breidablik := queued_breidablik
								if live_breidablik == null \
										or live_breidablik.current_zone == null \
										or live_breidablik.current_zone.zone_type != Zone.ZoneType.POWER_SLOT:
									live_breidablik = game_manager.get_card_by_uid(breidablik_uid) as Breidablik
								var live_priest := live_breidablik.resolve_harbor_target(queued_priest) \
									if live_breidablik != null else null
								if live_priest == null \
										and live_breidablik != null \
										and priest_zone != null \
										and priest_zone_card_index >= 0 \
										and priest_zone_card_index < priest_zone.cards.size():
									live_priest = live_breidablik.resolve_harbor_target(
										priest_zone.cards[priest_zone_card_index]
									)
								if live_priest == null and live_breidablik != null:
									live_priest = live_breidablik.get_valid_field_priest_by_uid(priest_uid)
								if live_breidablik == null \
										or live_priest == null \
										or not live_breidablik.harbor_priest(game_manager, live_priest):
									game_manager.note_player_feedback(
										"Breidablik could not harbor %s." % priest_name
									)
						)
						_advance_authoritative_priority()
						move_validated.emit(command)
						return true
					_queue_authoritative_magical_action(
						CardAction.Type.ABILITY,
						power_card,
						act_target,
						func() -> void:
							if power_card.has_method("activate_from_command"):
								power_card.call("activate_from_command", game_manager, activation_command)
							else:
								power_card.activate(game_manager, act_target)
					)
					_advance_authoritative_priority()
					move_validated.emit(command)
					return true
				game_manager.run_with_effect_source(
					power_card,
					func() -> void:
						if power_card.has_method("activate_from_command"):
							power_card.call("activate_from_command", game_manager, activation_command)
						else:
							power_card.activate(game_manager, act_target)
				)
			move_validated.emit(command)
			return true
		"tonal_extraction_choice":
			var delegated_command := command.duplicate(true)
			delegated_command["type"] = "activate_power"
			delegated_command["power_uid"] = str(command.get("source_uid", ""))
			return _process_command_impl(delegated_command)
		"cast_charm":
			var charm_uid: String = command.get("charm_uid", "")
			var charm := game_manager.get_card_by_uid(charm_uid)
			if charm == null or not (charm is CharmCard):
				move_failed.emit("cast_charm: charm not found")
				return false
			var charm_card := charm as CharmCard
			var charm_target: Card = null
			var charm_target_uid: String = command.get("target_uid", "")
			if charm_target_uid != "":
				charm_target = game_manager.get_card_by_uid(charm_target_uid)
			var charm_ward_block_reason := game_manager.get_turn_destruction_ward_activation_block_reason(charm_card, charm_target)
			if charm_ward_block_reason != "":
				move_failed.emit(charm_ward_block_reason)
				return false
			var charm_prepared: bool = command.get("prepared", false) or charm_card.is_prepared
			var charm_source_action: CardAction = game_manager.action_stack.back() if not game_manager.action_stack.is_empty() else null
			if charm_prepared:
				if not charm_card.can_activate_prepared(game_manager, charm_source_action):
					move_failed.emit(_get_move_activation_failure_reason(charm_card, true, charm_card.card_owner))
					return false
				if not game_manager.activate_prepared_card(charm_card, charm_card.card_owner):
					move_failed.emit(_get_move_cost_payment_failure_reason(charm_card, true, charm_card.card_owner))
					return false
			else:
				if not charm_card.can_activate_from_hand(game_manager, charm_source_action):
					move_failed.emit(_get_move_play_failure_reason(charm_card, charm_card.card_owner, null))
					return false
				if not charm_card.pay_costs(charm_card.card_owner, game_manager):
					move_failed.emit(_get_move_cost_payment_failure_reason(charm_card, false, charm_card.card_owner))
					return false
			if _uses_authoritative_headless_priority_flow():
				var charm_command_display_zone := _resolve_command_display_zone(command, charm_card.card_owner)
				var preferred_display_zone: Zone = charm_card.current_zone if charm_prepared else charm_command_display_zone
				var charm_resolve := func() -> void:
					_place_persistent_charm_on_board(charm_card, preferred_display_zone)
					charm_card.resolve(game_manager, charm_target)
					if charm_card.goes_to_graveyard_after_use() \
							and charm_card.current_zone != null \
							and charm_card.current_zone != charm_card.card_owner.graveyard_zone:
						charm_card.card_owner.move_card(charm_card, charm_card.card_owner.graveyard_zone)
				_queue_authoritative_magical_action(
					CardAction.Type.SPELL,
					charm_card,
					charm_target,
					charm_resolve,
					"",
					preferred_display_zone,
					charm_source_action
				)
				_advance_authoritative_priority()
				move_validated.emit(command)
				return true
			game_manager.run_with_effect_source(
				charm_card,
				func() -> void:
					var charm_immediate_display_zone := _resolve_command_display_zone(command, charm_card.card_owner)
					_place_persistent_charm_on_board(charm_card, charm_immediate_display_zone)
					charm_card.resolve(game_manager, charm_target)
			)
			if charm_card.goes_to_graveyard_after_use() \
					and charm_card.current_zone != null \
					and charm_card.current_zone != charm_card.card_owner.graveyard_zone:
				charm_card.card_owner.move_card(charm_card, charm_card.card_owner.graveyard_zone)
			move_validated.emit(command)
			return true
		"skoll_upkeep_summon":
			var skoll_upkeep_error := _validate_upkeep_choice_window(acting_player)
			if not skoll_upkeep_error.is_empty():
				move_failed.emit(skoll_upkeep_error)
				return false
			var skoll_uid: String = command.get("skoll_uid", "")
			var skoll_card := game_manager.get_card_by_uid(skoll_uid)
			if skoll_card == null or not (skoll_card is Skoll):
				move_failed.emit("skoll_upkeep_summon: Skoll card not found")
				return false
			var skoll := skoll_card as Skoll
			if not skoll.can_use_upkeep_summon(game_manager):
				move_failed.emit("Skoll cannot use upkeep summon right now.")
				return false
			var skoll_zone := resolve_zone(command)
			if skoll_zone == null or skoll_zone.zone_owner != game_manager.current_player \
					or skoll_zone.zone_type not in [Zone.ZoneType.FRONTLINE, Zone.ZoneType.RESERVE] \
					or not skoll_zone.cards.is_empty():
				move_failed.emit("Skoll upkeep summon: invalid zone.")
				return false
			var skoll_mode_str: String = command.get("mode", "aggressive")
			var skoll_mode: Card.CreatureMode = Card.CreatureMode.DEFENSIVE
			if skoll_mode_str == "aggressive":
				skoll_mode = Card.CreatureMode.AGGRESSIVE
			var skoll_stealth := skoll_mode_str == "stealth"
			game_manager.player_chooses_upkeep_only()
			if not game_manager.summon_creature_by_effect(
				game_manager.current_player, skoll, skoll_zone,
				skoll_mode, skoll_stealth, skoll_stealth,
				skoll, false, false
			):
				move_failed.emit("Skoll could not be summoned.")
				return false
			skoll.apply_upkeep_summon_tax(game_manager)
			move_validated.emit(command)
			if _uses_authoritative_headless_priority_flow():
				_begin_or_continue_authoritative_turn_start_sequence("Skoll summoned via Sun Hunt.")
			else:
				_advance_authoritative_priority_for_pending_card_events(skoll)
			return true
		"hati_moon_hunt":
			var hati_uid: String = command.get("hati_uid", "")
			var hati_card := game_manager.get_card_by_uid(hati_uid)
			if hati_card == null or not (hati_card is Hati):
				move_failed.emit("hati_moon_hunt: Hati card not found")
				return false
			var hati := hati_card as Hati
			if not hati.can_use_moon_hunt_summon(game_manager):
				move_failed.emit("Hati cannot use Moon Hunt right now.")
				return false
			var sacrifice_uid: String = command.get("sacrifice_uid", "")
			var sacrifice_target := game_manager.get_card_by_uid(sacrifice_uid)
			if sacrifice_target == null or not hati.is_valid_moon_hunt_sacrifice(sacrifice_target):
				move_failed.emit("Moon Hunt requires a valid friendly creature sacrifice.")
				return false
			var hati_zone := resolve_zone(command)
			if not hati.is_valid_moon_hunt_destination(hati_zone, sacrifice_target):
				move_failed.emit("Moon Hunt: invalid zone.")
				return false
			var hati_mode_str: String = command.get("mode", "defensive")
			var hati_mode: Card.CreatureMode = Card.CreatureMode.DEFENSIVE
			if hati_mode_str == "aggressive":
				hati_mode = Card.CreatureMode.AGGRESSIVE
			var hati_stealth := hati_mode_str == "stealth"
			if not hati.resolve_moon_hunt_summon(game_manager, hati_zone, sacrifice_target, hati_mode, hati_stealth):
				move_failed.emit("Moon Hunt fizzled.")
				return false
			move_validated.emit(command)
			_advance_authoritative_priority_for_pending_card_events(hati)
			return true
		"wheel_of_fire_turn_start_choice":
			var source_uid: String = str(command.get("source_uid", "")).strip_edges()
			var wheel := game_manager.get_card_by_uid(source_uid) as WheelOfFire
			if wheel == null:
				move_failed.emit("wheel_of_fire_turn_start_choice: Wheel of Fire not found")
				return false
			if not wheel.can_offer_turn_start_advance(game_manager):
				move_failed.emit("Wheel of Fire cannot advance its target right now.")
				return false
			var feedback := wheel.resolve_turn_start_advance_choice(game_manager, bool(command.get("pay_cost", false)))
			if feedback.strip_edges() != "":
				game_manager.note_player_feedback(feedback)
			move_validated.emit(command)
			if _uses_authoritative_headless_priority_flow():
				_begin_or_continue_authoritative_turn_start_sequence(
					_build_upkeep_resolution_feedback(feedback)
				)
			return true
		"breidablik_turn_start_choice":
			var source_uid := str(command.get("source_uid", "")).strip_edges()
			var breidablik := game_manager.get_card_by_uid(source_uid) as Breidablik
			if breidablik == null:
				move_failed.emit("breidablik_turn_start_choice: Breidablik not found")
				return false
			if not breidablik.can_return_priest(game_manager):
				move_failed.emit("Breidablik cannot return a Priest right now.")
				return false
			var feedback := "Declined Breidablik."
			if bool(command.get("return_priest", false)):
				var priest := breidablik.get_stored_priest_by_uid_or_index(
					str(command.get("target_uid", "")),
					int(command.get("stored_priest_index", -1))
				)
				if priest == null:
					move_failed.emit("Breidablik could not find that harbored Priest.")
					return false
				game_manager.push_effect_source_card(breidablik)
				var returned := breidablik.return_priest(game_manager, priest)
				game_manager.pop_effect_source_card()
				if not returned:
					move_failed.emit("Breidablik could not return that Priest.")
					return false
				feedback = "%s returned %s." % [breidablik.card_name, priest.card_name]
			else:
				breidablik.close_turn_start_window()
			command["public_log_message"] = feedback
			move_validated.emit(command)
			if _uses_authoritative_headless_priority_flow():
				_begin_or_continue_authoritative_turn_start_sequence(feedback)
			return true
		"unlock_power":
			var up_uid: String = command.get("power_uid", "")
			var up_card := game_manager.get_card_by_uid(up_uid)
			if up_card == null or not (up_card is PowerCard):
				move_failed.emit("unlock_power: power card not found")
				return false
			if not up_card.can_unlock(game_manager):
				move_failed.emit(up_card.card_name + " cannot be unlocked right now.")
				return false
			var unlock_target_uid := str(command.get("target_uid", "")).strip_edges()
			if up_card is TonalExtraction and not unlock_target_uid.is_empty():
				var tonal_card := up_card as TonalExtraction
				var unlock_target := game_manager.get_card_by_uid(unlock_target_uid)
				if unlock_target == null or unlock_target not in tonal_card.get_valid_targets(game_manager):
					move_failed.emit("unlock_power: invalid Tonal Extraction target")
					return false
				tonal_card.set_pending_unlock_target_uid(unlock_target_uid)
			up_card.unlock(game_manager)
			move_validated.emit(command)
			return true
		"activate_card_ability":
			var aca_source_uid: String = command.get("source_uid", "")
			var aca_source := game_manager.get_card_by_uid(aca_source_uid)
			if aca_source == null:
				move_failed.emit("activate_card_ability: source card not found")
				return false
			if not aca_source.has_method("activate"):
				move_failed.emit("activate_card_ability: card has no activate method")
				return false
			var aca_target: Card = null
			var aca_target_uid: String = command.get("target_uid", "")
			if aca_target_uid != "":
				aca_target = game_manager.get_card_by_uid(aca_target_uid)
			var aca_option_value = command.get("option", {})
			var aca_option: Dictionary = aca_option_value if aca_option_value is Dictionary else {}
			var aca_has_option := command.has("option") and not aca_option.is_empty()
			if aca_target == null and not aca_option.is_empty():
				var nested_target_uid := str(aca_option.get("target_uid", aca_option.get("chosen_uid", ""))).strip_edges()
				if nested_target_uid != "":
					aca_target = game_manager.get_card_by_uid(nested_target_uid)
			var aca_resolve_target_uid = aca_target.uid if aca_target != null else ""
			var aca_has_return_to_hand := command.has("return_to_hand")
			var aca_return_to_hand := bool(command.get("return_to_hand", false))
			var ability_ward_block_reason := game_manager.get_turn_destruction_ward_activation_block_reason(aca_source, aca_target)
			if ability_ward_block_reason != "":
				move_failed.emit(ability_ward_block_reason)
				return false
			if aca_source is AncientPyre:
				var aca_pyre := aca_source as AncientPyre
				var pyre_mode := str(aca_option.get("mode", "")).strip_edges()
				if not aca_pyre.can_activate(game_manager):
					move_failed.emit(aca_pyre.get_activation_failure_reason(game_manager))
					return false
				if pyre_mode == "convert":
					var pyre_opponent := game_manager.get_opponent(aca_pyre.card_owner)
					if pyre_opponent == null or pyre_opponent.followers <= 0:
						move_failed.emit("activate_card_ability: Ancient Pyre cannot convert right now")
						return false
				elif aca_pyre.is_frontline():
					if aca_target == null or not aca_pyre.is_valid_card_selection_target(aca_target, game_manager):
						move_failed.emit("activate_card_ability: invalid Ancient Pyre target")
						return false
				elif aca_target != null:
					move_failed.emit("activate_card_ability: Ancient Pyre does not use a card target from reserve")
					return false
			if aca_source.card_type == Card.CardType.CREATURE \
					and not game_manager.can_pay_creature_action_mana_cost(aca_source, "activate"):
				move_failed.emit(aca_source.card_name + " needs 1 mana to activate while Wheel of Fire is attached.")
				return false
			if _uses_authoritative_headless_priority_flow():
				_queue_authoritative_magical_action(
					CardAction.Type.ABILITY,
					aca_source,
					aca_target,
					Callable(self, "_execute_activate_card_ability_command").bind(
						aca_source_uid,
						aca_resolve_target_uid,
						aca_option,
						aca_has_option,
						aca_has_return_to_hand,
						aca_return_to_hand
					)
				)
				move_validated.emit(command)
				_advance_authoritative_priority()
				return true
			game_manager.run_with_effect_source(
				aca_source,
				Callable(self, "_execute_activate_card_ability_command").bind(
					aca_source_uid,
					aca_resolve_target_uid,
					aca_option,
					aca_has_option,
					aca_has_return_to_hand,
					aca_return_to_hand
				)
			)
			move_validated.emit(command)
			return true
		"mopsus_reveal_hand_card":
			var mopsus := game_manager.get_card_by_uid(str(command.get("source_uid", ""))) as Mopsus
			var hand_card := game_manager.get_card_by_uid(str(command.get("target_uid", "")))
			if mopsus == null or hand_card == null:
				move_failed.emit("Mopsus Seer: card not found")
				return false
			if not mopsus.can_activate(game_manager) or not mopsus.reveal_hand_card(game_manager, hand_card):
				move_failed.emit("Mopsus Seer: invalid opponent hand card")
				return false
			_request_ui_refresh()
			return true
		"en_hedu_anna_exaltation":
			var eha_uid: String = command.get("source_uid", "")
			var eha_card := game_manager.get_card_by_uid(eha_uid)
			if eha_card == null or not (eha_card is EnHeduAnna):
				move_failed.emit("en_hedu_anna_exaltation: card not found")
				return false
			var eha_option: Dictionary = command.get("option", {})
			var eha := eha_card as EnHeduAnna
			if not eha.is_valid_exaltation_option(eha_option):
				move_failed.emit("en_hedu_anna_exaltation: invalid Exaltation bonus")
				return false
			if not eha.can_activate(game_manager):
				move_failed.emit(eha.get_activation_failure_reason(game_manager))
				return false
			var eha_feedback := eha.resolve_exaltation_choice(game_manager, eha_option)
			if eha_feedback.strip_edges() != "":
				game_manager.note_player_feedback(eha_feedback)
			move_validated.emit(command)
			return true
		"aphrodite_enslave_choice":
			var source_uid: String = command.get("source_uid", "")
			var god := game_manager.get_card_by_uid(source_uid) as AphroditeAreia
			if god == null:
				move_failed.emit("aphrodite_enslave_choice: god not found")
				return false
			var confirmed: bool = command.get("confirm", false)
			if not confirmed:
				move_validated.emit(command)
				return true
			# "Choose Target" part is handled by a subsequent god_ability command from the client
			move_validated.emit(command)
			return true
		"first_sage_adapa_choice":
			var source_uid: String = command.get("source_uid", "")
			var sage := game_manager.get_card_by_uid(source_uid) as FirstSageAdapa
			if sage == null:
				move_failed.emit("first_sage_adapa_choice: card not found")
				return false
			var valid_targets := sage.get_valid_targets(game_manager)
			var target_uid: String = command.get("target_uid", "")
			if target_uid == "":
				var feedback := "%s found no opposing powers or God abilities to silence." % sage.card_name if valid_targets.is_empty() else sage.card_name + " impact fizzles."
				game_manager.note_player_feedback(feedback)
				move_validated.emit(command)
				return true
			var target := sage.get_silence_target_by_uid(game_manager, target_uid)
			if target == null:
				if _resolving_priority_choice_command:
					game_manager.note_player_feedback(sage.card_name + " impact fizzles because its target is no longer valid.")
					move_validated.emit(command)
					return true
				move_failed.emit("first_sage_adapa_choice: invalid silence target")
				return false
			if _queue_choice_command_as_priority_event(command, sage):
				move_validated.emit(command)
				return true
			game_manager.note_player_feedback(sage.resolve_silence_divine_impact(game_manager, target))
			move_validated.emit(command)
			return true
		"third_sage_enmedugga_choice":
			var source_uid: String = command.get("source_uid", "")
			var sage := game_manager.get_card_by_uid(source_uid) as ThirdSageEnmedugga
			if sage == null:
				move_failed.emit("third_sage_enmedugga_choice: card not found")
				return false
			var valid_targets := sage.get_valid_targets(game_manager)
			var target_uid: String = command.get("target_uid", "")
			if target_uid == "":
				var feedback := "%s found no Mer Sage to bless." % sage.card_name if valid_targets.is_empty() else sage.card_name + " impact fizzles."
				game_manager.note_player_feedback(feedback)
				move_validated.emit(command)
				return true
			var target := game_manager.get_card_by_uid(target_uid)
			if not _is_card_in_targets_by_uid(target, valid_targets):
				if _resolving_priority_choice_command:
					game_manager.note_player_feedback(sage.card_name + " impact fizzles because its target is no longer valid.")
					move_validated.emit(command)
					return true
				move_failed.emit("third_sage_enmedugga_choice: invalid Mer Sage target")
				return false
			if _queue_choice_command_as_priority_event(command, sage):
				move_validated.emit(command)
				return true
			game_manager.note_player_feedback(sage.resolve_good_fortune_impact(game_manager, target))
			move_validated.emit(command)
			return true
		"fourth_sage_enmegalamma_choice":
			var source_uid: String = command.get("source_uid", "")
			var sage := game_manager.get_card_by_uid(source_uid)
			if sage == null or not sage.has_method("get_valid_targets") or not sage.has_method("resolve_search_sage_impact") or not sage.has_method("resolve_search_sage_decline"):
				move_failed.emit("fourth_sage_enmegalamma_choice: card not found")
				return false
			var valid_targets: Array[Card] = []
			for entry in sage.call("get_valid_targets", game_manager):
				var target_card := entry as Card
				if target_card != null:
					valid_targets.append(target_card)
			var target_uid: String = command.get("target_uid", "")
			if target_uid == "":
				var feedback := ""
				if valid_targets.is_empty() and sage.has_method("resolve_no_search_targets"):
					feedback = str(sage.call("resolve_no_search_targets"))
				else:
					feedback = str(sage.call("resolve_search_sage_decline", game_manager))
				game_manager.note_player_feedback(feedback)
				move_validated.emit(command)
				return true
			var target := game_manager.get_card_by_uid(target_uid)
			if target == null or target not in valid_targets:
				move_failed.emit("fourth_sage_enmegalamma_choice: invalid Mer Sage target")
				return false
			game_manager.note_player_feedback(str(sage.call("resolve_search_sage_impact", game_manager, target)))
			move_validated.emit(command)
			return true
		"sixth_sage_an_enlilda_choice":
			var source_uid: String = command.get("source_uid", "")
			var sage := game_manager.get_card_by_uid(source_uid) as SixthSageAnEnlilda
			if sage == null:
				move_failed.emit("sixth_sage_an_enlilda_choice: card not found")
				return false
			var valid_targets := sage.get_valid_targets(game_manager)
			var target_uid: String = command.get("target_uid", "")
			if target_uid == "":
				var feedback := sage.resolve_no_conjure_home_targets() if valid_targets.is_empty() else sage.resolve_conjure_home_decline(game_manager)
				_complete_deferred_prompt_action_or_note("sixth_sage_an_enlilda_choice", sage, feedback)
				move_validated.emit(command)
				return true
			var target := game_manager.get_card_by_uid(target_uid)
			if target == null or target not in valid_targets:
				move_failed.emit("sixth_sage_an_enlilda_choice: invalid Ancient Dwelling target")
				return false
			if _defer_board_leaving_activation(
				sage,
				"%s activates Conjure Home." % sage.card_name,
				func() -> void:
					var feedback := sage.resolve_conjure_home_impact(game_manager, target)
					_complete_deferred_prompt_action_or_note("sixth_sage_an_enlilda_choice", sage, feedback)
			):
				move_validated.emit(command)
				return true
			_complete_deferred_prompt_action_or_note(
				"sixth_sage_an_enlilda_choice",
				sage,
				sage.resolve_conjure_home_impact(game_manager, target)
			)
			move_validated.emit(command)
			return true
		"seventh_sage_utuabzu_choice":
			var source_uid: String = command.get("source_uid", "")
			var sage := game_manager.get_card_by_uid(source_uid) as SeventhSageUtuabzu
			if sage == null:
				move_failed.emit("seventh_sage_utuabzu_choice: card not found")
				return false
			var valid_targets := sage.get_channel_ally_targets(game_manager)
			var target_uid: String = command.get("target_uid", "")
			if target_uid == "":
				game_manager.note_player_feedback("%s found no valid allied Ancient Sage to channel." % sage.card_name)
				move_validated.emit(command)
				return true
			var target := game_manager.get_card_by_uid(target_uid)
			if not _is_card_in_targets_by_uid(target, valid_targets):
				if _resolving_priority_choice_command:
					game_manager.note_player_feedback(sage.card_name + " impact fizzles because its target is no longer valid.")
					move_validated.emit(command)
					return true
				move_failed.emit("seventh_sage_utuabzu_choice: invalid Ancient Sage target")
				return false
			if _queue_choice_command_as_priority_event(command, sage):
				move_validated.emit(command)
				return true
			game_manager.note_player_feedback(sage.resolve_channel_ally_impact(game_manager, target))
			move_validated.emit(command)
			return true
		"lailoken_reveal_choice":
			var source_uid: String = command.get("source_uid", "")
			var lailoken := game_manager.get_card_by_uid(source_uid) as Lailoken
			if lailoken == null:
				move_failed.emit("lailoken_reveal_choice: card not found")
				return false
			var pending_action := _find_pending_deferred_action_for_source("lailoken_reveal_choice", lailoken)
			var valid_targets := lailoken.get_valid_targets(game_manager)
			var target_uid: String = command.get("target_uid", "")
			if target_uid == "":
				var feedback := "%s found no prepared magical cards to drain." % lailoken.card_name if valid_targets.is_empty() else lailoken.card_name + " reveal fizzles."
				game_manager.note_player_feedback(feedback)
				if pending_action != null:
					pending_action.resolution_text = feedback
					last_resolution_text = feedback
					_complete_deferred_authoritative_action(pending_action, "lailoken_reveal_choice")
				_resume_combat_reveal_after_source_choice(lailoken)
				move_validated.emit(command)
				return true
			var target := game_manager.get_card_by_uid(target_uid)
			if not _is_card_in_targets_by_uid(target, valid_targets):
				if _resolving_priority_choice_command:
					var feedback := lailoken.card_name + " reveal fizzles because its target is no longer valid."
					game_manager.note_player_feedback(feedback)
					if pending_action != null:
						pending_action.resolution_text = feedback
						last_resolution_text = feedback
						_complete_deferred_authoritative_action(pending_action, "lailoken_reveal_choice")
					_resume_combat_reveal_after_source_choice(lailoken)
					move_validated.emit(command)
					return true
				move_failed.emit("lailoken_reveal_choice: invalid magical target")
				return false
			if _queue_choice_command_as_priority_event(command, lailoken):
				move_validated.emit(command)
				return true
			lailoken.begin_magic_drain_reveal(
				game_manager,
				target,
				func(result_text: String) -> void:
					if result_text.strip_edges() != "":
						game_manager.note_player_feedback(result_text)
						if pending_action != null:
							pending_action.resolution_text = result_text
							last_resolution_text = result_text
					if pending_action != null:
						_complete_deferred_authoritative_action(pending_action, "lailoken_reveal_choice")
					_resume_combat_reveal_after_source_choice(lailoken)
			)
			move_validated.emit(command)
			return true
		"masmassu_priest_reveal_choice":
			var source_uid: String = command.get("source_uid", "")
			var priest = game_manager.get_card_by_uid(source_uid)
			if not (priest is MasmassuPriest) and not (priest is Grindylow):
				move_failed.emit("masmassu_priest_reveal_choice: card not found")
				return false
			var pending_action := _find_pending_deferred_action_for_source("masmassu_priest_reveal_choice", priest)
			var valid_targets: Array = priest.get_valid_targets(game_manager)
			var target_uid: String = command.get("target_uid", "")
			if target_uid == "":
				var no_target_feedback: String = "%s found no creatures to drown." % priest.card_name if priest is Grindylow else "%s found no creatures to break." % priest.card_name
				var feedback: String = no_target_feedback if valid_targets.is_empty() else priest.card_name + " reveal fizzles."
				game_manager.note_player_feedback(feedback)
				if pending_action != null:
					pending_action.resolution_text = feedback
					last_resolution_text = feedback
					_complete_deferred_authoritative_action(pending_action, "masmassu_priest_reveal_choice")
				_resume_combat_reveal_after_source_choice(priest)
				move_validated.emit(command)
				return true
			var target := game_manager.get_card_by_uid(target_uid)
			if not _is_card_in_targets_by_uid(target, valid_targets):
				if _resolving_priority_choice_command:
					var feedback: String = priest.card_name + " reveal fizzles because its target is no longer valid."
					game_manager.note_player_feedback(feedback)
					if pending_action != null:
						pending_action.resolution_text = feedback
						last_resolution_text = feedback
						_complete_deferred_authoritative_action(pending_action, "masmassu_priest_reveal_choice")
					_resume_combat_reveal_after_source_choice(priest)
					move_validated.emit(command)
					return true
				move_failed.emit("masmassu_priest_reveal_choice: invalid creature target")
				return false
			if _queue_choice_command_as_priority_event(command, priest):
				move_validated.emit(command)
				return true
			priest.begin_dalkhu_break_reveal(
				game_manager,
				target,
				func(result_text: String) -> void:
					if result_text.strip_edges() != "":
						game_manager.note_player_feedback(result_text)
						if pending_action != null:
							pending_action.resolution_text = result_text
							last_resolution_text = result_text
					if pending_action != null:
						_complete_deferred_authoritative_action(pending_action, "masmassu_priest_reveal_choice")
					_resume_combat_reveal_after_source_choice(priest)
			)
			move_validated.emit(command)
			return true
		"rally_the_troops_choice":
			var source_uid: String = command.get("source_uid", "")
			var rally := game_manager.get_card_by_uid(source_uid) as RallyTheTroops
			if rally == null:
				move_failed.emit("rally_the_troops_choice: power not found")
				return false
			var target_uid: String = command.get("target_uid", "")
			var target := game_manager.get_card_by_uid(target_uid) if target_uid != "" else null
			var valid_targets := rally.get_valid_rally_targets(game_manager)
			if target != null and target not in valid_targets:
				move_failed.emit("rally_the_troops_choice: invalid Warrior target")
				return false
			var summoned_uid := str(command.get("summoned_uid", ""))
			var summoned_card := game_manager.get_card_by_uid(summoned_uid) if summoned_uid != "" else null
			game_manager.note_player_feedback(rally.resolve_rally_choice(game_manager, target, summoned_card))
			move_validated.emit(command)
			return true
		"terror_impact_choice":
			var source_uid: String = command.get("source_uid", "")
			var terror := game_manager.get_card_by_uid(source_uid) as Terror
			if terror == null:
				move_failed.emit("terror_impact_choice: power not found")
				return false
			var demon_uid := str(command.get("demon_uid", ""))
			var demon := game_manager.get_card_by_uid(demon_uid)
			if demon == null:
				move_failed.emit("terror_impact_choice: demon not found")
				return false
			var valid_targets := terror.get_valid_terror_targets(game_manager, demon)
			var target_uid: String = command.get("target_uid", "")
			var target := game_manager.get_card_by_uid(target_uid) if target_uid != "" else null
			if not _is_card_in_targets_by_uid(target, valid_targets):
				if _resolving_priority_choice_command:
					game_manager.note_player_feedback(terror.card_name + " impact fizzles because its target is no longer valid.")
					move_validated.emit(command)
					return true
				move_failed.emit("terror_impact_choice: invalid creature target")
				return false
			if _queue_choice_command_as_priority_event(command, terror):
				move_validated.emit(command)
				return true
			game_manager.note_player_feedback(terror.resolve_terror_impact(game_manager, demon, target))
			move_validated.emit(command)
			return true
		"huginn_perish_prime_choice":
			var source_uid: String = command.get("source_uid", "")
			var huginn := game_manager.get_card_by_uid(source_uid) as Huginn
			if huginn == null:
				move_failed.emit("huginn_perish_prime_choice: card not found")
				return false
			var valid_targets := huginn.get_valid_hex_targets()
			var target_uid: String = command.get("target_uid", "")
			var target := game_manager.get_card_by_uid(target_uid) if target_uid != "" else null
			if target == null or target not in valid_targets:
				move_failed.emit("huginn_perish_prime_choice: invalid Hex target")
				return false
			game_manager.note_player_feedback(huginn.resolve_perish_prime_choice(game_manager, target))
			move_validated.emit(command)
			return true
		"muninn_perish_prime_choice":
			var source_uid: String = command.get("source_uid", "")
			var muninn := game_manager.get_card_by_uid(source_uid) as Muninn
			if muninn == null:
				move_failed.emit("muninn_perish_prime_choice: card not found")
				return false
			var valid_targets := muninn.get_valid_charm_targets()
			var target_uid: String = command.get("target_uid", "")
			var target := game_manager.get_card_by_uid(target_uid) if target_uid != "" else null
			if target == null or target not in valid_targets:
				move_failed.emit("muninn_perish_prime_choice: invalid Charm target")
				return false
			game_manager.note_player_feedback(muninn.resolve_perish_prime_choice(game_manager, target))
			move_validated.emit(command)
			return true
		"fenrir_devour_choice":
			var source_uid: String = command.get("source_uid", "")
			var fenrir := game_manager.get_card_by_uid(source_uid) as Fenrir
			if fenrir == null:
				move_failed.emit("fenrir_devour_choice: card not found")
				return false
			var valid_targets := fenrir.get_valid_devour_targets(game_manager)
			var target_uid: String = command.get("target_uid", "")
			if target_uid == "":
				_complete_deferred_prompt_action_or_note("fenrir_devour_choice", fenrir, fenrir.card_name + " impact fizzles.")
				move_validated.emit(command)
				return true
			var target := game_manager.get_card_by_uid(target_uid)
			if not _is_card_in_targets_by_uid(target, valid_targets):
				if _resolving_priority_choice_command:
					_complete_deferred_prompt_action_or_note(
						"fenrir_devour_choice",
						fenrir,
						fenrir.card_name + " impact fizzles because its target is no longer valid."
					)
					move_validated.emit(command)
					return true
				move_failed.emit("fenrir_devour_choice: invalid creature target")
				return false
			if _queue_choice_command_as_priority_event(command, fenrir):
				move_validated.emit(command)
				return true
			fenrir.resolve_devour_impact(
				game_manager,
				target,
				func(feedback: String) -> void:
					_complete_deferred_prompt_action_or_note("fenrir_devour_choice", fenrir, feedback)
			)
			move_validated.emit(command)
			return true
		"harii_jarl_impact_choice":
			var source_uid: String = command.get("source_uid", "")
			var jarl := game_manager.get_card_by_uid(source_uid) as HariiJarl
			if jarl == null:
				move_failed.emit("harii_jarl_impact_choice: card not found")
				return false
			var valid_targets := jarl.get_valid_warband_targets(game_manager)
			var chosen_cards: Array[Card] = []
			for chosen_uid in command.get("chosen_uids", []):
				var chosen_card := game_manager.get_card_by_uid(str(chosen_uid))
				if chosen_card == null or chosen_card not in valid_targets or chosen_card in chosen_cards:
					move_failed.emit("harii_jarl_impact_choice: invalid Harii target")
					return false
				chosen_cards.append(chosen_card)
				if chosen_cards.size() > HariiJarl.MAX_WARBAND_SUMMONS:
					move_failed.emit("harii_jarl_impact_choice: too many Harii selected")
					return false
			if chosen_cards.is_empty() and valid_targets.is_empty():
				move_validated.emit(command)
				return true
			game_manager.note_player_feedback(jarl.resolve_warband_impact(game_manager, chosen_cards))
			move_validated.emit(command)
			return true
		"durinn_secondborn_choice":
			var source_uid: String = command.get("source_uid", "")
			var durinn := game_manager.get_card_by_uid(source_uid) as DurinnSecondborn
			if durinn == null:
				move_failed.emit("durinn_secondborn_choice: card not found")
				return false
			var valid_targets := durinn.get_valid_targets(game_manager)
			var target_uid: String = command.get("target_uid", "")
			if target_uid == "":
				var feedback := "%s found no weapons to reforge." % durinn.card_name if valid_targets.is_empty() else durinn.card_name + " impact fizzles."
				game_manager.note_player_feedback(feedback)
				move_validated.emit(command)
				return true
			var target := game_manager.get_card_by_uid(target_uid)
			if not _is_card_in_targets_by_uid(target, valid_targets):
				if _resolving_priority_choice_command:
					game_manager.note_player_feedback(durinn.card_name + " impact fizzles because its target is no longer valid.")
					move_validated.emit(command)
					return true
				move_failed.emit("durinn_secondborn_choice: invalid weapon target")
				return false
			if _queue_choice_command_as_priority_event(command, durinn):
				move_validated.emit(command)
				return true
			game_manager.note_player_feedback(durinn.resolve_reforge_impact(game_manager, target))
			move_validated.emit(command)
			return true
		"kur_jara_tree_of_life_choice":
			var source_uid: String = command.get("source_uid", "")
			var kur_jara := game_manager.get_card_by_uid(source_uid) as KurJara
			if kur_jara == null:
				move_failed.emit("kur_jara_tree_of_life_choice: card not found")
				return false
			var valid_targets := kur_jara.get_tree_of_life_destroy_candidates(game_manager)
			var required_count := kur_jara.get_tree_of_life_pending_destroy_count()
			var chosen_cards: Array[Card] = []
			for chosen_uid in command.get("chosen_uids", []):
				var chosen_card := game_manager.get_card_by_uid(str(chosen_uid))
				if chosen_card == null or chosen_card not in valid_targets or chosen_card in chosen_cards:
					move_failed.emit("kur_jara_tree_of_life_choice: invalid creature target")
					return false
				chosen_cards.append(chosen_card)
				if chosen_cards.size() > required_count:
					move_failed.emit("kur_jara_tree_of_life_choice: too many creatures selected")
					return false
			kur_jara.resolve_tree_of_life_destroy_selection(game_manager, chosen_cards)
			move_validated.emit(command)
			return true
		"hunting_tactics_choice":
			var source_uid: String = command.get("source_uid", "")
			var power := game_manager.get_card_by_uid(source_uid) as HuntingTactics
			if power == null:
				move_failed.emit("hunting_tactics_choice: power not found")
				return false
			var attacker_uid: String = command.get("attacker_uid", "")
			var attacker := game_manager.get_card_by_uid(attacker_uid)
			if attacker == null:
				move_failed.emit("hunting_tactics_choice: attacker not found")
				return false
			var valid_targets := power.get_support_choices(attacker)
			var chosen_cards: Array[Card] = []
			for chosen_uid in command.get("chosen_uids", []):
				var chosen_card := game_manager.get_card_by_uid(str(chosen_uid))
				if chosen_card == null or chosen_card not in valid_targets or chosen_card in chosen_cards:
					move_failed.emit("hunting_tactics_choice: invalid supporter")
					return false
				chosen_cards.append(chosen_card)
			var attack_target_before_choice = pending_attack_target if pending_attack_target != null else _pending_hunting_tactics_attack_target
			var has_pending_hunting_tactics_attack := _pending_hunting_tactics_attack_declaration \
				or (_pending_hunting_tactics_attack_attacker != null and _pending_hunting_tactics_attack_target != null)
			var continue_pending_attack := has_pending_hunting_tactics_attack \
				and (
					attacker == selected_attacker \
					or selected_attacker == null \
					or attacker == _pending_hunting_tactics_attack_attacker
				) \
				and attack_target_before_choice != null
			print("[HT-DEBUG] choice: flag=%s attacker_matches=%s selected=%s target=%s chosen=%d" % [
				str(_pending_hunting_tactics_attack_declaration),
				str(attacker == selected_attacker),
				selected_attacker.card_name if selected_attacker != null else "null",
				str(pending_attack_target),
				chosen_cards.size(),
			])
			game_manager.note_player_feedback(power.resolve_combat_support_choice(game_manager, attacker, chosen_cards))
			move_validated.emit(command)
			if continue_pending_attack:
				# Consume the hunting_tactics prompt before resuming the attack so
				# _advance_authoritative_priority() doesn't bail out on the still-
				# pending interaction (which would leave the attack stuck on the
				# stack in the no-interceptor case) and the intercept prompt emits
				# immediately rather than being queued behind this entry.
				var consumed := _consume_active_command_prompt_for_completion("hunting_tactics_choice")
				if not consumed:
					consumed = _consume_matching_pending_ui_interaction_for_command(command)
				print("[HT-DEBUG] choice: consumed_prompt=%s pending_ui_after=%d" % [str(consumed), _pending_ui_interactions.size()])
				_continue_pending_attack_after_hunting_tactics_choice(attacker, attack_target_before_choice)
			return true
		"gugalanna_celestial_charge_choice":
			var source_uid: String = command.get("source_uid", "")
			var card := game_manager.get_card_by_uid(source_uid) as GugalannaBullOfHeaven
			if card == null:
				move_failed.emit("gugalanna_celestial_charge_choice: card not found")
				return false
			var valid_targets := card.get_valid_impact_targets(game_manager)
			var target_uid: String = command.get("target_uid", "")
			var target := game_manager.get_card_by_uid(target_uid) if target_uid != "" else null
			if target != null and not _is_card_in_targets_by_uid(target, valid_targets):
				if _resolving_priority_choice_command:
					var feedback := card.card_name + " impact fizzles because its target is no longer valid."
					game_manager.note_player_feedback(feedback)
					_complete_deferred_prompt_action(
						"gugalanna_celestial_charge_choice",
						card,
						feedback,
						false
					)
					move_validated.emit(command)
					return true
				move_failed.emit("gugalanna_celestial_charge_choice: invalid target")
				return false
			if target != null and _queue_choice_command_as_priority_event(command, card):
				move_validated.emit(command)
				return true
			if target != null and _defer_board_leaving_activation(
				card,
				"%s activates Celestial Charge." % card.card_name,
				func() -> void:
					card.apply_celestial_charge(game_manager, target)
					_complete_deferred_prompt_action("gugalanna_celestial_charge_choice", card)
			):
				move_validated.emit(command)
				return true
			card.apply_celestial_charge(game_manager, target)
			_complete_deferred_prompt_action("gugalanna_celestial_charge_choice", card)
			move_validated.emit(command)
			return true
		"freyja_active_open_sessrumnir_choice":
			var source_uid: String = command.get("source_uid", "")
			var active_god := game_manager.get_card_by_uid(source_uid) as FreyjaActive
			if active_god == null:
				move_failed.emit("freyja_active_open_sessrumnir_choice: active god not found")
				return false
			var option: Dictionary = command.get("option", {})
			var skip_choice := bool(option.get("skip", command.get("skip", false)))
			var selection_data = option if not option.is_empty() else command
			var chosen_targets := active_god.get_selected_open_sessrumnir_targets(game_manager, selection_data)
			var raw_choices: Array = []
			if selection_data is Dictionary:
				raw_choices = selection_data.get("target_uids", [])
			elif selection_data is Array:
				raw_choices = selection_data
			if raw_choices.is_empty() and not skip_choice:
				command["skip"] = true
				skip_choice = true
			if chosen_targets.size() != raw_choices.size():
				if _resolving_priority_choice_command:
					game_manager.note_player_feedback(active_god.card_name + " impact fizzles because its selection is no longer valid.")
					move_validated.emit(command)
					return true
				move_failed.emit("freyja_active_open_sessrumnir_choice: invalid target")
				return false
			if not skip_choice and not active_god.is_valid_open_sessrumnir_selection(game_manager, chosen_targets):
				if _resolving_priority_choice_command:
					game_manager.note_player_feedback(active_god.card_name + " impact fizzles because its selection is no longer valid.")
					move_validated.emit(command)
					return true
				move_failed.emit("freyja_active_open_sessrumnir_choice: invalid selection")
				return false
			if _queue_choice_command_as_priority_event(command, active_god):
				move_validated.emit(command)
				return true
			active_god.resolve_from_command(game_manager, command)
			move_validated.emit(command)
			return true
		"tiamat_active_summon_choice":
			var source_uid: String = command.get("source_uid", "")
			var active_god := game_manager.get_card_by_uid(source_uid) as TiamatActive
			if active_god == null:
				move_failed.emit("tiamat_active_summon_choice: active god not found")
				return false
			var label := str(command.get("label", "Birth"))
			if label not in ["Birth", "Death"]:
				move_failed.emit("tiamat_active_summon_choice: invalid summon label")
				return false
			var target_uid: String = command.get("target_uid", "")
			var target := game_manager.get_card_by_uid(target_uid) if target_uid != "" else null
			var valid_targets := active_god.get_valid_summon_targets(game_manager, label)
			if target == null and not valid_targets.is_empty():
				move_failed.emit("tiamat_active_summon_choice: target is required")
				return false
			if target != null and target not in valid_targets:
				move_failed.emit("tiamat_active_summon_choice: invalid Demon or Dragon target")
				return false
			game_manager.note_player_feedback(active_god.resolve_summon_choice(game_manager, label, target))
			move_validated.emit(command)
			return true
		"giant_master_architect_choice":
			var source_uid: String = command.get("source_uid", "")
			var card := game_manager.get_card_by_uid(source_uid) as GiantMasterArchitect
			if card == null:
				move_failed.emit("giant_master_architect_choice: card not found")
				return false
			var valid_targets := card.get_valid_targets(game_manager)
			var target_uid: String = command.get("target_uid", "")
			if target_uid == "":
				game_manager.note_player_feedback(card.resolve_master_plan_cancel(game_manager))
				move_validated.emit(command)
				return true
			var target := game_manager.get_card_by_uid(target_uid)
			if target == null or target not in valid_targets:
				move_failed.emit("giant_master_architect_choice: invalid structure target")
				return false
			game_manager.note_player_feedback(card.resolve_master_plan_impact(game_manager, target))
			move_validated.emit(command)
			return true
		"pai_long_autumn_king_choice":
			var source_uid: String = command.get("source_uid", "")
			var card := game_manager.get_card_by_uid(source_uid) as PaiLongAutumnKing
			if card == null:
				move_failed.emit("pai_long_autumn_king_choice: card not found")
				return false
			var valid_targets := card.get_valid_targets(game_manager)
			var target_uid: String = command.get("target_uid", "")
			if target_uid == "":
				if valid_targets.is_empty():
					game_manager.note_player_feedback(card.resolve_no_weather_targets())
				else:
					game_manager.note_player_feedback(card.resolve_stormcloud_cancel(game_manager))
				move_validated.emit(command)
				return true
			var target := game_manager.get_card_by_uid(target_uid)
			if target == null or target not in valid_targets:
				move_failed.emit("pai_long_autumn_king_choice: invalid Weather charm target")
				return false
			game_manager.note_player_feedback(card.resolve_stormcloud_impact(game_manager, target))
			move_validated.emit(command)
			return true
		"nergal_lion_choice":
			var source_uid: String = command.get("source_uid", "")
			var card := game_manager.get_card_by_uid(source_uid) as NergalLion
			if card == null:
				move_failed.emit("nergal_lion_choice: card not found")
				return false
			var valid_targets := card.get_valid_immolate_targets(game_manager)
			var valid_zones := card.get_valid_immolate_zones()
			if valid_zones.is_empty():
				move_failed.emit("nergal_lion_choice: no valid field zone")
				return false
			var target_uid: String = command.get("target_uid", "")
			var target := game_manager.get_card_by_uid(target_uid) if target_uid != "" else null
			if target == null or target not in valid_targets:
				if _resolving_priority_choice_command:
					game_manager.note_player_feedback(card.card_name + " impact fizzles because its target is no longer valid.")
					move_validated.emit(command)
					return true
				move_failed.emit("nergal_lion_choice: invalid destruction target")
				return false
			if _queue_choice_command_as_priority_event(command, card):
				move_validated.emit(command)
				return true
			game_manager.note_player_feedback(card.resolve_immolate_impact(game_manager, target, valid_zones[0]))
			move_validated.emit(command)
			return true
		"gala_tura_destroyed_choice":
			var source_uid: String = command.get("source_uid", "")
			var card := game_manager.get_card_by_uid(source_uid) as GalaTura
			if card == null:
				move_failed.emit("gala_tura_destroyed_choice: card not found")
				return false
			var valid_targets := card.get_destroyed_trigger_targets(game_manager)
			var chosen_cards: Array[Card] = []
			for chosen_uid in command.get("chosen_uids", []):
				var chosen_card := game_manager.get_card_by_uid(str(chosen_uid))
				if chosen_card == null or chosen_card not in valid_targets or chosen_card in chosen_cards:
					move_failed.emit("gala_tura_destroyed_choice: invalid creature target")
					return false
				chosen_cards.append(chosen_card)
				if chosen_cards.size() > GalaTura.MAX_RETURN_COUNT:
					move_failed.emit("gala_tura_destroyed_choice: too many creatures selected")
					return false
			game_manager.note_player_feedback(card.resolve_destroyed_trigger(game_manager, chosen_cards))
			move_validated.emit(command)
			return true
		"gawain_healing_hands_choice":
			var source_uid: String = command.get("source_uid", "")
			var card := game_manager.get_card_by_uid(source_uid) as Gawain
			if card == null:
				move_failed.emit("gawain_healing_hands_choice: card not found")
				return false
			var target_uid: String = command.get("target_uid", "")
			var target := game_manager.get_card_by_uid(target_uid)
			var valid_targets := card.get_valid_targets(game_manager)
			if target == null or target not in valid_targets:
				move_failed.emit("gawain_healing_hands_choice: invalid creature target")
				return false
			var status_index := int(command.get("status_index", -1))
			var removable := card.get_removable_statuses(target)
			if status_index < 0 or status_index >= removable.size():
				move_failed.emit("gawain_healing_hands_choice: invalid status choice")
				return false
			game_manager.note_player_feedback(card.resolve_healing_hands_by_index(game_manager, target, status_index))
			move_validated.emit(command)
			return true
		"tatzelwurm_dragon_heart_choice":
			var source_uid: String = command.get("source_uid", "")
			var card := game_manager.get_card_by_uid(source_uid) as Tatzelwurm
			if card == null:
				move_failed.emit("tatzelwurm_dragon_heart_choice: card not found")
				return false
			var valid_targets := card.get_valid_targets(game_manager)
			var target_uid: String = command.get("target_uid", "")
			if target_uid == "":
				game_manager.note_player_feedback(card.resolve_dragon_heart_decline(game_manager))
				move_validated.emit(command)
				return true
			var target := game_manager.get_card_by_uid(target_uid)
			if target == null or target not in valid_targets:
				move_failed.emit("tatzelwurm_dragon_heart_choice: invalid Dragon target")
				return false
			game_manager.note_player_feedback(card.resolve_dragon_heart(game_manager, target))
			move_validated.emit(command)
			return true
		"byggvir_reveal_choice":
			var source_uid: String = command.get("source_uid", "")
			var card := game_manager.get_card_by_uid(source_uid) as Byggvir
			if card == null:
				move_failed.emit("byggvir_reveal_choice: card not found")
				return false
			var choice_data: Dictionary = command.get("choice", {})
			var matched := card.find_matching_brewing_option(game_manager, choice_data)
			if matched.is_empty():
				move_failed.emit("byggvir_reveal_choice: invalid Brewing option")
				return false
			if _queue_choice_command_as_priority_event(command, card):
				move_validated.emit(command)
				return true
			game_manager.note_player_feedback(card.resolve_brewing_option(game_manager, matched))
			move_validated.emit(command)
			return true
		"nusku_well_of_fire_choice":
			var source_uid: String = command.get("source_uid", "")
			var nusku := game_manager.get_card_by_uid(source_uid) as NuskuFirebearer
			if nusku == null:
				move_failed.emit("nusku_well_of_fire_choice: card not found")
				return false
			var target_uid: String = command.get("target_uid", "")
			var target := game_manager.get_card_by_uid(target_uid) if target_uid != "" else null
			var pending_choice_uids: Array = nusku.get_meta(NuskuFirebearer.PENDING_CHOICE_UIDS_META, [])
			if target == null or target.uid not in pending_choice_uids or not nusku.is_valid_pending_well_of_fire_choice(target):
				move_failed.emit("nusku_well_of_fire_choice: invalid Well of Fire choice")
				return false
			nusku._complete_well_of_fire(game_manager, target, int(nusku.get_meta(NuskuFirebearer.PENDING_MILL_COUNT_META, int(command.get("mill_count", NuskuFirebearer.MILL_COUNT)))))
			move_validated.emit(command)
			return true
		"ragnarok_discard_choice":
			var source_uid: String = command.get("source_uid", "")
			var power := game_manager.get_card_by_uid(source_uid) as Ragnarok
			if power == null:
				move_failed.emit("ragnarok_discard_choice: power not found")
				return false
			var discard_player := power.get_pending_discard_player(game_manager)
			if discard_player == null or discard_player.hand_zone == null:
				move_failed.emit("ragnarok_discard_choice: no discard prompt is pending")
				return false
			var target_uid: String = str(command.get("target_uid", "")).strip_edges()
			var chosen_card := game_manager.get_card_by_uid(target_uid)
			if chosen_card == null or chosen_card.current_zone != discard_player.hand_zone or not discard_player.hand_zone.cards.has(chosen_card):
				move_failed.emit("ragnarok_discard_choice: invalid discard choice")
				return false
			power.resolve_discard_choice(game_manager, chosen_card)
			move_validated.emit(command)
			return true
		"foolish_optimism_choice":
			var source_uid: String = command.get("source_uid", "")
			var spell := game_manager.get_card_by_uid(source_uid) as FoolishOptimism
			if spell == null:
				move_failed.emit("foolish_optimism_choice: spell not found")
				return false
			var attacker_uid: String = command.get("attacker_uid", "")
			var defender_uid: String = command.get("defender_uid", "")
			if attacker_uid == "" or defender_uid == "":
				spell.send_to_graveyard_if_needed()
				game_manager.note_player_feedback(spell.card_name + " fizzles.")
				move_validated.emit(command)
				return true
			var attacker := game_manager.get_card_by_uid(attacker_uid)
			var defender := game_manager.get_card_by_uid(defender_uid)
			if attacker == null or defender == null:
				move_failed.emit("foolish_optimism_choice: attacker or defender not found")
				return false
			var valid_attackers := spell.get_lowest_level_attacker_choices(game_manager)
			var valid_defenders := spell.get_highest_level_defender_choices(game_manager)
			if attacker not in valid_attackers or defender not in valid_defenders:
				move_failed.emit("foolish_optimism_choice: invalid tied creature choice")
				return false
			game_manager.note_player_feedback(spell.finish_prompt_resolution(game_manager, attacker, defender))
			move_validated.emit(command)
			return true
		"blessed_knights_choice":
			var source_uid: String = command.get("source_uid", "")
			var ward_kind: String = command.get("ward_kind", "")
			var card := game_manager.get_card_by_uid(source_uid) as BlessedKnights
			if card == null:
				move_failed.emit("blessed_knights_choice: card not found")
				return false
			if ward_kind not in card.get_blessed_ward_options():
				move_failed.emit("blessed_knights_choice: invalid ward choice")
				return false
			card.apply_blessed_ward(game_manager, ward_kind)
			game_manager.note_player_feedback(
				"%s grants Blessed Ward against %s this turn." % [
					card.card_name,
					card.get_blessed_ward_label(ward_kind),
				]
			)
			move_validated.emit(command)
			return true
		"tezcatlipoca_active_titlacauan_choice":
			var source_uid: String = command.get("source_uid", "")
			var active_god := game_manager.get_card_by_uid(source_uid) as TezcatlipocaActive
			if active_god == null:
				move_failed.emit("tezcatlipoca_active_titlacauan_choice: active god not found")
				return false
			var option: Dictionary = command.get("option", {})
			var skip_choice := bool(option.get("skip", command.get("skip", false)))
			var selection_data = option if not option.is_empty() else command
			var chosen_targets := active_god.get_selected_titlacauan_targets(game_manager, selection_data)
			var raw_choices: Array = []
			if selection_data is Dictionary:
				raw_choices = selection_data.get("target_uids", [])
			elif selection_data is Array:
				raw_choices = selection_data
			if raw_choices.is_empty() and not skip_choice:
				command["skip"] = true
				skip_choice = true
			if chosen_targets.size() != raw_choices.size():
				if _resolving_priority_choice_command:
					game_manager.note_player_feedback(active_god.card_name + " impact fizzles because its selection is no longer valid.")
					move_validated.emit(command)
					return true
				move_failed.emit("tezcatlipoca_active_titlacauan_choice: invalid target")
				return false
			if not skip_choice and not active_god.is_valid_titlacauan_selection(game_manager, chosen_targets):
				if _resolving_priority_choice_command:
					game_manager.note_player_feedback(active_god.card_name + " impact fizzles because its selection is no longer valid.")
					move_validated.emit(command)
					return true
				move_failed.emit("tezcatlipoca_active_titlacauan_choice: invalid selection")
				return false
			if _queue_choice_command_as_priority_event(command, active_god):
				move_validated.emit(command)
				return true
			active_god.resolve_from_command(game_manager, command)
			var feedback := game_manager.consume_player_feedback()
			if feedback.strip_edges() != "":
				game_manager.note_player_feedback(feedback)
				last_resolution_text = feedback
			move_validated.emit(command)
			return true
		"nusku_active_core_flame_choice":
			var source_uid: String = command.get("source_uid", "")
			var active_god := game_manager.get_card_by_uid(source_uid) as NuskuActive
			if active_god == null:
				move_failed.emit("nusku_active_core_flame_choice: active god not found")
				return false
			var chosen_uid: String = str(command.get("chosen_uid", command.get("target_uid", ""))).strip_edges()
			if chosen_uid != "":
				if not active_god.is_pending_core_flame_choice_uid(chosen_uid):
					move_failed.emit("nusku_active_core_flame_choice: invalid Core Flame choice")
					return false
			active_god.resolve_from_command(game_manager, command)
			if not active_god.has_pending_core_flame_choice():
				_complete_deferred_prompt_action("nusku_active_core_flame_choice", active_god)
			move_validated.emit(command)
			return true
		"apollyons_demiurge_choice":
			var source_uid: String = command.get("source_uid", "")
			var spell := game_manager.get_card_by_uid(source_uid) as ApollyonsDemiurge
			if spell == null:
				move_failed.emit("apollyons_demiurge_choice: spell not found")
				return false
			var chosen_uid: String = str(command.get("target_uid", command.get("chosen_uid", ""))).strip_edges()
			if chosen_uid == "" or not spell.is_pending_demiurge_choice_uid(chosen_uid):
				move_failed.emit("apollyons_demiurge_choice: invalid Demon choice")
				return false
			var feedback := spell.resolve_demiurge_choice(game_manager, chosen_uid)
			game_manager.note_player_feedback(feedback)
			move_validated.emit(command)
			return true
		"habrok_breakout_choice":
			var source_uid: String = str(command.get("source_uid", "")).strip_edges()
			var habrok := game_manager.get_card_by_uid(source_uid) as HabrokParagonOfHawks
			if habrok == null:
				move_failed.emit("habrok_breakout_choice: card not found")
				return false
			if not habrok.can_trigger_breakout(game_manager, game_manager.current_player):
				move_failed.emit("habrok_breakout_choice: Breakout is no longer available")
				return false
			var do_breakout := bool(command.get("do_breakout", false))
			if do_breakout and _defer_board_leaving_activation(
				habrok,
				"%s activates Breakout." % habrok.card_name,
				func() -> void:
					habrok.resolve_breakout_choice(game_manager, true)
			):
				move_validated.emit(command)
				return true
			habrok.resolve_breakout_choice(game_manager, do_breakout)
			move_validated.emit(command)
			return true
		"wolf_adolescent_maturation_choice":
			var source_uid: String = command.get("source_uid", "")
			var wolf := game_manager.get_card_by_uid(source_uid)
			if wolf == null or not (wolf is WolfAdolescent or wolf is WolfCub):
				move_failed.emit("wolf_adolescent_maturation_choice: card not found")
				return false
			if not wolf.can_offer_maturation(game_manager):
				move_failed.emit("wolf_adolescent_maturation_choice: Maturation is not available")
				return false
			var target_uid: String = command.get("target_uid", "")
			var target: Card = game_manager.get_card_by_uid(target_uid) if target_uid != "" else null
			var valid_targets: Array[Card] = []
			valid_targets.assign(wolf.get_valid_maturation_targets())
			if target != null and target not in valid_targets:
				move_failed.emit("wolf_adolescent_maturation_choice: invalid Lupine target")
				return false
			var feedback: String = wolf.resolve_maturation_choice(game_manager, target)
			if feedback.strip_edges() != "":
				game_manager.note_player_feedback(feedback)
			move_validated.emit(command)
			return true
		"humbaba_augury_choice":
			var source_uid: String = command.get("source_uid", "")
			var humbaba := game_manager.get_card_by_uid(source_uid) as HumbabaTheTerrible
			if humbaba == null:
				move_failed.emit("humbaba_augury_choice: card not found")
				return false
			if pending_humbaba_action != null:
				var current_prompt := _get_pending_humbaba_prompt()
				if current_prompt == null:
					move_failed.emit("humbaba_augury_choice: no augury prompt is waiting for a response")
					_clear_pending_humbaba_state()
					return false
				if source_uid != "" and source_uid != str(current_prompt.uid):
					move_failed.emit("humbaba_augury_choice: that augury prompt is no longer active")
					return false
			var valid_targets := humbaba.get_augury_cards(game_manager)
			if valid_targets.is_empty():
				move_failed.emit("humbaba_augury_choice: no cards available to prime")
				return false
			var target_uid: String = command.get("target_uid", "")
			var target: Card = game_manager.get_card_by_uid(target_uid) if target_uid != "" else null
			if target != null and target not in valid_targets:
				move_failed.emit("humbaba_augury_choice: invalid card choice")
				return false
			var feedback := humbaba.resolve_augury_reading(game_manager, target)
			if feedback.strip_edges() != "":
				game_manager.note_player_feedback(feedback)
			if pending_humbaba_action != null:
				var action := pending_humbaba_action
				var pending_target = pending_humbaba_target
				if not pending_humbaba_prompt_uids.is_empty():
					pending_humbaba_prompt_uids.remove_at(0)
				if _emit_next_pending_humbaba_prompt():
					move_validated.emit(command)
					return true
				_clear_pending_humbaba_state()
				_continue_pending_humbaba_attack_resolution(action, pending_target)
				if pending_retreat_action == action:
					_mark_deferred_authoritative_action(
						action,
						"combat_retreat_decision"
					)
					move_validated.emit(command)
					return true
				if pending_combat_reveal_linger_action == action:
					_mark_deferred_authoritative_action(
						action,
						"combat_reveal_linger"
					)
					move_validated.emit(command)
					return true
				_complete_deferred_authoritative_action(action, "humbaba_augury_choice")
				if pending_target is Player:
					_schedule_authoritative_deferred_action_check(
						"humbaba_followers_after_augury",
						action,
						pending_target
					)
				move_validated.emit(command)
				return true
			move_validated.emit(command)
			return true
		"mummu_entropy_choice":
			var source_uid: String = command.get("source_uid", "")
			var active_god := game_manager.get_card_by_uid(source_uid)
			if active_god == null or not active_god.has_method("resolve_from_command"):
				move_failed.emit("mummu_entropy_choice: active god not found")
				return false
			active_god.resolve_from_command(game_manager, command)
			move_validated.emit(command)
			return true
		"wolf_master_summon":
			var wm_fenrir_uid: String = command.get("fenrir_uid", "")
			var wm_fenrir_card := game_manager.get_card_by_uid(wm_fenrir_uid)
			if wm_fenrir_card == null or not (wm_fenrir_card is Fenrir):
				move_failed.emit("wolf_master_summon: Fenrir not found")
				return false
			var wm_fenrir := wm_fenrir_card as Fenrir
			if not wm_fenrir.can_use_hand_ability(game_manager):
				move_failed.emit("Wolf Master cannot be used right now.")
				return false
			if not wm_fenrir.perform_wolf_master_shuffle():
				move_failed.emit("Wolf Master shuffle failed.")
				return false
			var wm_lupine_uid: String = command.get("lupine_uid", "")
			var wm_lupine := game_manager.get_card_by_uid(wm_lupine_uid)
			if wm_lupine == null:
				move_failed.emit("wolf_master_summon: lupine not found")
				return false
			var wm_zone := resolve_zone(command)
			if wm_zone == null or wm_zone.zone_owner != game_manager.current_player \
					or wm_zone.zone_type not in [Zone.ZoneType.FRONTLINE, Zone.ZoneType.RESERVE] \
					or not wm_zone.cards.is_empty():
				move_failed.emit("wolf_master_summon: invalid zone")
				return false
			var wm_mode_str: String = command.get("mode", "aggressive")
			var wm_mode: Card.CreatureMode = Card.CreatureMode.DEFENSIVE
			if wm_mode_str == "aggressive":
				wm_mode = Card.CreatureMode.AGGRESSIVE
			var wm_stealth := wm_mode_str == "stealth"
			if not game_manager.summon_creature_by_effect(
				game_manager.current_player, wm_lupine, wm_zone,
				wm_mode, wm_stealth, wm_stealth,
				wm_fenrir_card, true, true
			):
				move_failed.emit("Wolf Master: summon failed for " + wm_lupine.card_name)
				return false
			move_validated.emit(command)
			_advance_authoritative_priority_for_pending_card_events(wm_lupine)
			return true
		"activate_divine_caprice":
			var dc_uid: String = command.get("power_uid", "")
			var dc_card := game_manager.get_card_by_uid(dc_uid)
			if dc_card == null or not (dc_card is DivineCaprice):
				move_failed.emit("activate_divine_caprice: DivineCaprice not found")
				return false
			var dc := dc_card as DivineCaprice
			if not dc.can_activate(game_manager):
				move_failed.emit(_get_move_activation_failure_reason(dc, false, dc.card_owner))
				return false
			var raw_plan: Array = command.get("plan", [])
			var dc_plan: Array = []
			for step in raw_plan:
				var src_zone := resolve_zone(step.get("source_zone", {}))
				var tgt_zone := resolve_zone(step.get("target_zone", {}))
				if src_zone != null and tgt_zone != null:
					dc_plan.append({"source_zone": src_zone, "target_zone": tgt_zone})
			if dc_plan.is_empty():
				move_failed.emit("activate_divine_caprice: plan is empty or all zones invalid")
				return false
			if _uses_authoritative_headless_priority_flow():
				_queue_authoritative_magical_action(
					CardAction.Type.ABILITY,
					dc,
					dc_plan,
					func() -> void:
						dc.activate(game_manager, dc_plan)
				)
				_advance_authoritative_priority()
				move_validated.emit(command)
				return true
			game_manager.run_with_effect_source(
				dc,
				func() -> void:
					dc.activate(game_manager, dc_plan)
			)
			move_validated.emit(command)
			return true
		"intercept_decision":
			if selected_attacker == null or pending_attack_target == null:
				move_failed.emit("intercept_decision: no attack is waiting for interception")
				return false
			var int_uid: String = str(command.get("interceptor_uid", "")).strip_edges()
			if int_uid.is_empty():
				selected_interceptor = null
			else:
				var interceptor: Card = game_manager.get_card_by_uid(int_uid)
				if interceptor == null:
					move_failed.emit("intercept_decision: interceptor not found")
					return false
				if interceptor not in _get_possible_interceptors(selected_attacker, pending_attack_target):
					move_failed.emit("intercept_decision: invalid interceptor")
					return false
				selected_interceptor = interceptor
			if _uses_authoritative_headless_attack_flow():
				_resolve_authoritative_headless_attack()
			move_validated.emit(command)
			return true
		"combat_retreat_decision":
			return _process_combat_retreat_decision(command)
		"play_charm_response":
			var pcr_charm_uid: String = command.get("charm_uid", "")
			var pcr_charm := game_manager.get_card_by_uid(pcr_charm_uid)
			if pcr_charm == null or not (pcr_charm is CharmCard):
				move_failed.emit("play_charm_response: charm card not found")
				return false
			if game_manager.action_stack.is_empty():
				move_failed.emit("play_charm_response: no action on stack")
				return false
			var pcr_source: CardAction = game_manager.action_stack.back()
			var requested_from_hand := bool(command.get("from_hand", false))
			var pcr_from_hand := pcr_charm.current_zone == pcr_charm.card_owner.hand_zone
			if requested_from_hand != pcr_from_hand:
				move_failed.emit("play_charm_response: charm location changed")
				return false
			if not game_manager.can_card_respond_to_priority(pcr_charm, pcr_charm.card_owner):
				move_failed.emit(_get_move_activation_failure_reason(pcr_charm, not pcr_from_hand, pcr_charm.card_owner))
				return false
			var pcr_charm_card := pcr_charm as CharmCard
			var pcr_target_uid: String = command.get("target_uid", "")
			var pcr_target: Card = game_manager.get_card_by_uid(pcr_target_uid) if pcr_target_uid != "" else null
			var pcr_target_error := _validate_priority_response_target(pcr_charm_card, pcr_source, pcr_target, pcr_target_uid, "play_charm_response")
			if not pcr_target_error.is_empty():
				move_failed.emit(pcr_target_error)
				return false
			if pcr_from_hand:
				if not pcr_charm_card.pay_costs(pcr_charm_card.card_owner, game_manager):
					move_failed.emit(_get_move_cost_payment_failure_reason(pcr_charm_card, false, pcr_charm_card.card_owner))
					return false
			else:
				if not game_manager.activate_prepared_card(pcr_charm, pcr_charm.card_owner):
					move_failed.emit(_get_move_cost_payment_failure_reason(pcr_charm_card, true, pcr_charm_card.card_owner))
					return false
			var pcr_action := CardAction.new()
			pcr_action.type = CardAction.Type.CHARM
			pcr_action.source_player = pcr_charm_card.card_owner
			pcr_action.card = pcr_charm
			pcr_action.target = pcr_target
			pcr_action.response_to = pcr_source
			pcr_action.resolve_callback = func() -> void:
				_place_persistent_charm_on_board(pcr_charm_card, pcr_action.display_zone)
				pcr_charm_card.resolve(game_manager, pcr_target)
				if pcr_charm_card.goes_to_graveyard_after_use() \
						and pcr_charm_card.current_zone != null \
						and pcr_charm_card.current_zone != pcr_charm_card.card_owner.graveyard_zone:
					pcr_charm_card.card_owner.move_card(pcr_charm_card, pcr_charm_card.card_owner.graveyard_zone)
			_assign_stack_display_zone(
				pcr_action,
				pcr_target.current_zone if pcr_target != null and pcr_target.current_zone != null and pcr_target.current_zone.is_board_zone() else null
			)
			game_manager.push_to_stack(pcr_action)
			_clear_pending_turn_action_after_priority_response(pcr_charm_card.card_owner)
			move_validated.emit(command)
			if _uses_authoritative_headless_priority_flow():
				_advance_authoritative_priority()
			return true
		"play_priority_ability":
			var pra_source_uid: String = command.get("source_uid", "")
			var pra_source := game_manager.get_card_by_uid(pra_source_uid)
			if pra_source == null:
				move_failed.emit("play_priority_ability: source card not found")
				return false
			if game_manager.action_stack.is_empty():
				move_failed.emit("play_priority_ability: no action on stack")
				return false
			var pra_source_action: CardAction = game_manager.action_stack.back()
			if not pra_source.has_method("activate"):
				move_failed.emit("play_priority_ability: source card has no activatable ability")
				return false
			if not game_manager.can_card_respond_to_priority(pra_source, pra_source.card_owner):
				move_failed.emit("play_priority_ability: source cannot respond right now")
				return false
			var pra_target: Card = null
			var pra_target_uid: String = command.get("target_uid", "")
			if pra_target_uid != "":
				pra_target = game_manager.get_card_by_uid(pra_target_uid)
			var pra_target_error := _validate_priority_response_target(pra_source, pra_source_action, pra_target, pra_target_uid, "play_priority_ability")
			if not pra_target_error.is_empty():
				move_failed.emit(pra_target_error)
				return false
			var pra_zone: Zone = null
			if command.has("zone_type"):
				pra_zone = resolve_zone(command)
				if pra_zone == null:
					move_failed.emit("play_priority_ability: invalid zone")
					return false
			var pra_action := CardAction.new()
			pra_action.type = CardAction.Type.ABILITY
			pra_action.source_player = pra_source.card_owner
			pra_action.card = pra_source
			pra_action.target = pra_target
			pra_action.response_to = pra_source_action
			if pra_zone != null:
				pra_action.event_data["summon_zone"] = CardAction._zone_to_dict(pra_zone, game_manager)
			if command.has("mode"):
				pra_action.event_data["summon_mode"] = int(command.get("mode", Card.CreatureMode.DEFENSIVE))
			pra_action.resolve_callback = func() -> void:
				var uses_activation_context := pra_action.event_data.has("summon_zone") or pra_action.event_data.has("summon_mode")
				if uses_activation_context:
					var activation_context: Dictionary = {}
					if pra_target != null:
						activation_context["triggering_attacker"] = pra_target
					var summon_zone_dict = pra_action.event_data.get("summon_zone", {})
					if summon_zone_dict is Dictionary and not (summon_zone_dict as Dictionary).is_empty():
						var resolved_zone := CardAction._dict_to_zone(summon_zone_dict as Dictionary, game_manager)
						if resolved_zone != null:
							activation_context["summon_zone"] = resolved_zone
					if pra_action.event_data.has("summon_mode"):
						activation_context["summon_mode"] = int(pra_action.event_data.get("summon_mode", Card.CreatureMode.DEFENSIVE))
					if not activation_context.is_empty():
						pra_source.activate(game_manager, activation_context)
					elif pra_target != null:
						pra_source.activate(game_manager, pra_target)
					else:
						pra_source.activate(game_manager)
				elif pra_target != null:
					pra_source.activate(game_manager, pra_target)
				else:
					pra_source.activate(game_manager)
			game_manager.push_to_stack(pra_action)
			_clear_pending_turn_action_after_priority_response(pra_source.card_owner)
			move_validated.emit(command)
			if _uses_authoritative_headless_priority_flow():
				_advance_authoritative_priority()
			return true
		"priority_pass":
			if _uses_authoritative_headless_priority_flow():
				# The pass can resolve the stack and run a deferred turn action before
				# submit_command's normal prompt cleanup gets another chance.
				if not _consume_active_command_prompt_for_completion("priority_pass") and acting_player != null:
					_consume_pending_ui_interaction_for_player(acting_player, "priority")
				game_manager.pass_priority()
				if game_manager.both_passed():
					if not game_manager.action_stack.is_empty():
						_schedule_authoritative_stack_top_after_priority()
					else:
						_clear_priority_window_state()
						_try_process_pending_turn_action_after_opponent_priority()
				else:
					_advance_authoritative_priority()
				_request_ui_refresh()
				move_validated.emit(command)
				return true
			move_validated.emit(command)
			return true
		"resurrection_choice":
			var card_uid: String = command.get("card_uid", "")
			var confirmed: bool = command.get("confirm", false)
			var card := game_manager.get_card_by_uid(card_uid)
			if card == null:
				move_failed.emit("resurrection_choice: card not found")
				return false
			if card not in game_manager.pending_resurrections:
				move_failed.emit("resurrection_choice: no matching resurrection prompt is pending")
				return false
			
			if confirmed:
				var player := card.card_owner
				if player == null or player.graveyard_zone == null or card.current_zone != player.graveyard_zone:
					game_manager.pending_resurrections.erase(card)
					move_failed.emit("resurrection_choice: card is no longer in its graveyard")
					return false
				if player.mana < AgainWalker.RESURRECTION_COST:
					move_failed.emit("resurrection_choice: not enough mana")
					return false
				var resurrection_zone := _get_resurrection_zone_for_card(card)
				if resurrection_zone == null:
					game_manager.note_player_feedback("%s cannot resurrect: no empty reserve zone." % card.card_name)
					game_manager.pending_resurrections.erase(card)
					move_validated.emit(command)
					if _pending_end_turn_after_resurrection:
						if _check_for_next_resurrection():
							return true
						_pending_end_turn_after_resurrection = false
						_finalize_pending_end_turn(player)
					return true

				player.spend_mana(AgainWalker.RESURRECTION_COST)
				var placed := game_manager.summon_creature_by_effect(
					player,
					card,
					resurrection_zone,
					Card.CreatureMode.AGGRESSIVE,
					false,
					false,
					null,
					false,
					false,
					false
				)
				if not placed:
					player.gain_mana(AgainWalker.RESURRECTION_COST)
					game_manager.note_player_feedback("%s could not resurrect." % card.card_name)
					game_manager.pending_resurrections.erase(card)
					move_validated.emit(command)
					if _pending_end_turn_after_resurrection:
						if _check_for_next_resurrection():
							return true
						_pending_end_turn_after_resurrection = false
						_finalize_pending_end_turn(player)
					return true
			
			# Remove from pending list regardless of choice (or if failed)
			game_manager.pending_resurrections.erase(card)
			move_validated.emit(command)
			_advance_authoritative_priority_for_pending_card_events(card)
			if _pending_end_turn_after_resurrection:
				if _check_for_next_resurrection():
					return true
				_pending_end_turn_after_resurrection = false
				_finalize_pending_end_turn(card.card_owner if card != null else null)
			return true
		"return_to_hand_choice":
			var card_uid := str(command.get("card_uid", "")).strip_edges()
			var pending_card := game_manager.get_pending_return_to_hand_card()
			if pending_card == null:
				move_failed.emit("return_to_hand_choice: no pending choice")
				return false
			if pending_card.uid != card_uid:
				move_failed.emit("return_to_hand_choice: pending choice does not match card")
				return false
			if not game_manager.resolve_pending_return_to_hand_choice(bool(command.get("pay_cost", false))):
				move_failed.emit("return_to_hand_choice: failed to resolve")
				return false
			move_validated.emit(command)
			if _uses_authoritative_headless_priority_flow():
				_continue_pending_authoritative_graveyard_prompt_action()
			return true
		"doorway_choice":
			var structure_uid := str(command.get("structure_uid", "")).strip_edges()
			var card_uid := str(command.get("card_uid", "")).strip_edges()
			var pending_structure := game_manager.get_pending_doorway_structure()
			var pending_card := game_manager.get_pending_doorway_card()
			if pending_structure == null or pending_card == null:
				move_failed.emit("doorway_choice: no pending choice")
				return false
			if pending_structure.uid != structure_uid:
				move_failed.emit("doorway_choice: pending structure does not match")
				return false
			if pending_card.uid != card_uid:
				move_failed.emit("doorway_choice: pending card does not match")
				return false
			if not game_manager.resolve_pending_doorway_choice(bool(command.get("send_to_abyss", false))):
				move_failed.emit("doorway_choice: failed to resolve")
				return false
			move_validated.emit(command)
			if _uses_authoritative_headless_priority_flow():
				_continue_pending_authoritative_graveyard_prompt_action()
			return true
		"play_hex_response":
			var phr_hex_uid: String = command.get("hex_uid", "")
			var phr_hex_card := game_manager.get_card_by_uid(phr_hex_uid)
			if phr_hex_card == null or not (phr_hex_card is HexCard):
				move_failed.emit("play_hex_response: hex card not found")
				return false
			if game_manager.action_stack.is_empty():
				move_failed.emit("play_hex_response: no action on stack")
				return false
			var phr_source: CardAction = game_manager.action_stack.back()
			if not game_manager.can_card_respond_to_priority(phr_hex_card, phr_hex_card.card_owner):
				move_failed.emit(_get_move_activation_failure_reason(phr_hex_card, true, phr_hex_card.card_owner))
				return false
			var phr_target_uid: String = command.get("target_uid", "")
			var phr_target: Card = game_manager.get_card_by_uid(phr_target_uid) if phr_target_uid != "" else null
			var phr_hex := phr_hex_card as HexCard
			var phr_target_error := _validate_priority_response_target(phr_hex, phr_source, phr_target, phr_target_uid, "play_hex_response")
			if not phr_target_error.is_empty():
				move_failed.emit(phr_target_error)
				return false
			if not _priority_response_requires_target_choice(phr_hex):
				var automatic_targets := _get_priority_response_targets(phr_hex, phr_source)
				phr_target = automatic_targets[0] as Card if automatic_targets.size() == 1 else null
				phr_target_uid = phr_target.uid if phr_target != null else ""
			var phr_target_is_attacker := not phr_hex.has_method("get_priority_targets") and phr_source.type == CardAction.Type.ATTACK
			var phr_ability := CardAction.new()
			phr_ability.type = CardAction.Type.ABILITY
			phr_ability.source_player = phr_hex.card_owner
			phr_ability.card = phr_hex
			phr_ability.response_to = phr_source
			phr_ability.attacker = phr_target if phr_target_is_attacker and phr_target != null else phr_source.attacker
			phr_ability.interceptor = phr_source.interceptor
			phr_ability.target = phr_target if not phr_target_is_attacker and phr_target != null else phr_source.target
			if not game_manager.activate_prepared_card(phr_hex_card, phr_hex_card.card_owner):
				move_failed.emit(_get_move_cost_payment_failure_reason(phr_hex, true, phr_hex.card_owner))
				return false
			game_manager.push_to_stack(phr_ability)
			_clear_pending_turn_action_after_priority_response(phr_hex.card_owner)
			move_validated.emit(command)
			if _uses_authoritative_headless_priority_flow():
				_advance_authoritative_priority()
			return true
	move_failed.emit("Unknown command type: " + str(command.get("type")))
	return false

func _process_combat_retreat_decision(command: Dictionary) -> bool:
	var current_prompt := _get_pending_retreat_prompt()
	if pending_retreat_action == null or pending_retreat_target == null or current_prompt == null:
		move_failed.emit("combat_retreat_decision: no retreat prompt is waiting for a response")
		_clear_pending_retreat_state()
		return false
	var requested_uid := str(command.get("askelladen_uid", "")).strip_edges()
	if not requested_uid.is_empty() and requested_uid != str(current_prompt.uid):
		move_failed.emit("combat_retreat_decision: that retreat prompt is no longer active")
		return false
	var action := pending_retreat_action
	var target := pending_retreat_target
	var blocked_ask := _get_first_guardian_blocked_retreat_prompt()
	if not pending_retreat_prompt_uids.is_empty():
		pending_retreat_prompt_uids.remove_at(0)
	if bool(command.get("retreat", false)):
		game_manager.send_to_deck_bottom_with_hook(action.attacker)
		game_manager.send_to_deck_bottom_with_hook(target)
		last_resolution_text = "Tactical Retreat! Both creatures returned to the bottom of their decks."
		_clear_pending_retreat_state()
		_complete_deferred_authoritative_action(action, "combat_retreat_decision")
		return true
	if not pending_retreat_prompt_uids.is_empty():
		var next_prompt := _get_pending_retreat_prompt()
		if next_prompt == null:
			_clear_pending_retreat_state()
			move_failed.emit("combat_retreat_decision: next retreat prompt was unavailable")
			return false
		_emit_ui_interaction_for_player(_get_card_controller(next_prompt), "combat_retreat", {
			"action": action,
			"target": target,
			"askelladen_uid": str(next_prompt.uid),
		})
		return true
	_clear_pending_retreat_state()
	_finish_creature_combat(action, target)
	if blocked_ask != null:
		last_resolution_text = "Asaruludu's Guardian prevented %s's Tactical Retreat!" % blocked_ask.card_name
	_complete_deferred_authoritative_action(action, "combat_retreat_decision")
	return true

func _get_pending_retreat_prompt() -> Askelladen:
	if pending_retreat_prompt_uids.is_empty():
		return null
	return game_manager.get_card_by_uid(str(pending_retreat_prompt_uids[0])) as Askelladen

func _get_pending_retreat_prompt_player() -> Player:
	var prompt := _get_pending_retreat_prompt()
	return _get_card_controller(prompt)

func _get_first_guardian_blocked_retreat_prompt() -> Askelladen:
	if pending_retreat_guardian_blocked_uids.is_empty():
		return null
	return game_manager.get_card_by_uid(str(pending_retreat_guardian_blocked_uids[0])) as Askelladen

func _clear_pending_retreat_state() -> void:
	pending_retreat_action = null
	pending_retreat_target = null
	pending_retreat_prompt_uids.clear()
	pending_retreat_guardian_blocked_uids.clear()

func _finalize_pending_end_turn(acting_player: Player) -> void:
	var end_turn_player := acting_player if acting_player != null else game_manager.current_player
	if end_turn_player == null:
		return
	if _uses_authoritative_headless_priority_flow():
		_queue_authoritative_priority_event(
			"end_turn",
			func() -> void:
				game_manager.end_turn(),
			end_turn_player,
			end_turn_player,
			"End-turn window closed."
		)
		return
	game_manager.end_turn()

func _check_for_next_resurrection() -> bool:
	# Only relevant if we have pending resurrections
	if game_manager.pending_resurrections.is_empty():
		return false
		
	var candidates: Array[Card] = []
	for card in game_manager.pending_resurrections:
		if card.card_owner.mana >= AgainWalker.RESURRECTION_COST \
				and card.current_zone == card.card_owner.graveyard_zone \
				and _get_resurrection_zone_for_card(card) != null:
			candidates.append(card)
			
	if not candidates.is_empty():
		var next_card := candidates[0]
		_emit_ui_interaction_for_player(next_card.card_owner, "resurrection", {"card_uid": next_card.uid})
		return true
	return false

func _get_resurrection_zone_for_card(card: Card) -> Zone:
	if card == null or card.card_owner == null:
		return null
	var player := card.card_owner
	var preferred_idx: int = card.last_board_zone_index
	if preferred_idx >= 0 and preferred_idx < player.reserve_zones.size():
		var preferred_zone := player.reserve_zones[preferred_idx]
		if preferred_zone != null and preferred_zone.cards.is_empty():
			return preferred_zone
	for zone in player.reserve_zones:
		if zone != null and zone.cards.is_empty():
			return zone
	return null
