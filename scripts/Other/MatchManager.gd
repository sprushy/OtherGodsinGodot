# MatchManager.gd
extends RefCounted
class_name MatchManager

# This class manages high-level match flow and targeting state,
# decoupling game rules from the UI.

const TiamatScript = preload("res://scripts/cards/Gods/TiamatThePrimordial.gd")

signal targeting_started(source: Card, target_type: String)
signal targeting_ended()
signal move_validated(move: Dictionary)
signal move_failed(reason: String)

var game_manager: GameManager
var game_state: GameState
var network_manager: Node = null # Set this if in multiplayer mode
var authoritative_match_flow_enabled: bool = false

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

# Spell-specific targeting states
var pending_blot_sacrifice_target: Card = null
var pending_blot_selected_creatures: Array[Card] = []
var pending_blot_costs_paid: bool = false

var pending_divine_caprice_power: Card = null
var pending_divine_caprice_selected_zone: Zone = null

var pending_retreat_action: CardAction = null
var pending_retreat_target: Card = null
var pending_retreat_prompt_uids: Array[String] = []
var pending_retreat_guardian_blocked_uids: Array[String] = []
var pending_humbaba_action: CardAction = null
var pending_humbaba_target = null
var pending_humbaba_prompt_uids: Array[String] = []
var pending_tezcatlipoca_titlacauan_action: CardAction = null
var _pending_end_turn_after_resurrection: bool = false
var _active_command_sender_info: Dictionary = {}
var _active_command_type: String = ""
var _pending_ui_interactions: Array[Dictionary] = []
var _next_ui_interaction_id: int = 1

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
	pending_blot_sacrifice_target = null
	pending_blot_selected_creatures.clear()
	pending_blot_costs_paid = false
	pending_divine_caprice_power = null
	pending_divine_caprice_selected_zone = null
	pending_retreat_action = null
	pending_retreat_target = null
	pending_retreat_prompt_uids.clear()
	pending_retreat_guardian_blocked_uids.clear()
	pending_humbaba_action = null
	pending_humbaba_target = null
	pending_humbaba_prompt_uids.clear()
	pending_tezcatlipoca_titlacauan_action = null
	_pending_end_turn_after_resurrection = false
	_active_command_sender_info.clear()
	_active_command_type = ""
	_pending_ui_interactions.clear()
	_next_ui_interaction_id = 1
	last_resolution_text = ""
	last_move_failed_reason = ""
	_authoritative_stack_resolution_pending = false

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

func confirm_click_selection(target) -> void:
	if not pending_click_selection_validator.call(target):
		move_failed.emit("Invalid target for " + pending_click_selection_name)
		return
		
	var confirm_callback = pending_click_selection_confirm
	_clear_targeting_state()
	if confirm_callback.is_valid():
		confirm_callback.call(target)

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

signal action_resolved(action: CardAction)
signal request_ui_interaction(player_index: int, type: String, data: Dictionary)
signal ui_refresh_requested()

const AUTHORITATIVE_STACK_ACTION_LINGER_SECONDS := 0.66

var last_resolution_text: String = ""
var last_move_failed_reason: String = ""
var _authoritative_stack_resolution_pending: bool = false

func _on_game_manager_decision_requested(player: Player, type: String, data: Dictionary) -> void:
	if game_manager == null or player == null:
		return
	var interaction_data := data.duplicate(true)
	if bool(interaction_data.get("queue_with_priority", false)):
		interaction_data.erase("queue_with_priority")
		var source_card := game_manager.get_card_by_uid(str(interaction_data.get("source_uid", "")))
		var event_name := str(interaction_data.get("event_name", type)).strip_edges()
		interaction_data.erase("event_name")
		_queue_decision_priority_event(player, source_card, event_name if event_name != "" else type, type, interaction_data)
		return
	_emit_ui_interaction_for_player(player, type, interaction_data)

func _emit_ui_interaction_for_player(player: Player, type: String, data: Dictionary) -> void:
	if game_manager == null or player == null:
		return
	var player_idx := game_manager.players.find(player)
	if player_idx < 0:
		return
	_record_pending_ui_interaction(player, type, data)
	request_ui_interaction.emit(player_idx, type, data)

func emit_ui_interaction_for_player(player: Player, type: String, data: Dictionary) -> void:
	_emit_ui_interaction_for_player(player, type, data)

func _record_pending_ui_interaction(player: Player, type: String, data: Dictionary) -> void:
	if player == null or type.strip_edges() == "":
		return
	var entry := {
		"player": player,
		"type": type,
		"turn_number": game_manager.turn_number if game_manager != null else -1,
		"prompt_id": _next_ui_interaction_id,
		"data": data.duplicate(true),
	}
	_next_ui_interaction_id += 1
	_prune_matching_pending_ui_interactions(entry)
	_pending_ui_interactions.append(entry)
	while _pending_ui_interactions.size() > 64:
		_pending_ui_interactions.remove_at(0)

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

func _validate_pending_ui_interaction_for_command(command: Dictionary) -> Dictionary:
	var result := {
		"error": "",
		"prompt_id": -1,
	}
	var command_type := str(command.get("type", ""))
	var expected_type := _get_ui_interaction_type_for_command(command_type)
	if expected_type == "":
		return result
	if not (authoritative_match_flow_enabled or network_manager != null):
		return result
	var prompt_idx := _find_pending_ui_interaction_index(command, expected_type)
	if prompt_idx < 0:
		result["error"] = "%s: no matching server prompt is pending" % command_type
		return result
	result["prompt_id"] = int(_pending_ui_interactions[prompt_idx].get("prompt_id", -1))
	return result

func _consume_pending_ui_interaction_by_id(prompt_id: int) -> void:
	if prompt_id < 0:
		return
	for idx in range(_pending_ui_interactions.size() - 1, -1, -1):
		if int(_pending_ui_interactions[idx].get("prompt_id", -1)) == prompt_id:
			_pending_ui_interactions.remove_at(idx)
			return

func _get_ui_interaction_type_for_command(command_type: String) -> String:
	match command_type:
		"intercept_decision":
			return "intercept"
		"aphrodite_enslave_choice":
			return "aphrodite_enslave"
		"blessed_knights_choice":
			return "blessed_knights_ward"
		"wheel_of_fire_turn_start_choice":
			return "wheel_of_fire_turn_start"
		"tezcatlipoca_active_titlacauan_choice":
			return "tezcatlipoca_active_titlacauan"
		"nusku_active_core_flame_choice":
			return "nusku_active_core_flame"
		"mummu_entropy_choice":
			return "mummu_entropy"
		"first_sage_adapa_choice":
			return "first_sage_adapa_impact"
		"third_sage_enmedugga_choice":
			return "third_sage_enmedugga_impact"
		"fourth_sage_enmegalamma_choice":
			return "fourth_sage_enmegalamma_impact"
		"sixth_sage_an_enlilda_choice":
			return "sixth_sage_an_enlilda_impact"
		"lailoken_reveal_choice":
			return "lailoken_reveal"
		"masmassu_priest_reveal_choice":
			return "masmassu_priest_reveal"
		"rally_the_troops_choice":
			return "rally_the_troops"
		"terror_impact_choice":
			return "terror_impact"
		"huginn_perish_prime_choice":
			return "huginn_perish_prime"
		"muninn_perish_prime_choice":
			return "muninn_perish_prime"
		"fenrir_devour_choice":
			return "fenrir_devour_impact"
		"harii_jarl_impact_choice":
			return "harii_jarl_impact"
		"durinn_secondborn_choice":
			return "durinn_secondborn_impact"
		"kur_jara_tree_of_life_choice":
			return "kur_jara_tree_of_life"
		"hunting_tactics_choice":
			return "hunting_tactics"
		"foolish_optimism_choice":
			return "foolish_optimism"
		"gugalanna_celestial_charge_choice":
			return "gugalanna_celestial_charge"
		"freyja_active_open_sessrumnir_choice":
			return "freyja_active_open_sessrumnir"
		"giant_master_architect_choice":
			return "giant_master_architect_impact"
		"pai_long_autumn_king_choice":
			return "pai_long_autumn_king_impact"
		"nergal_lion_choice":
			return "nergal_lion_impact"
		"gala_tura_destroyed_choice":
			return "gala_tura_destroyed"
		"gawain_healing_hands_choice":
			return "gawain_healing_hands"
		"tatzelwurm_dragon_heart_choice":
			return "tatzelwurm_dragon_heart"
		"byggvir_reveal_choice":
			return "byggvir_reveal"
		"humbaba_augury_choice":
			return "humbaba_augury"
		"ragnarok_discard_choice":
			return "ragnarok_discard"
		"return_to_hand_choice":
			return "return_to_hand_choice"
		"resurrection_choice":
			return "resurrection"
		"nusku_well_of_fire_choice":
			return "nusku_well_of_fire"
		"apollyons_demiurge_choice":
			return "apollyons_demiurge"
		"wolf_adolescent_maturation_choice":
			return "wolf_adolescent_maturation"
		"apply_advanced_building_techniques":
			return "advanced_building_techniques"
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
	if player == null or player.hand_zone == null:
		result["reason"] = "end_turn: player hand not found"
		return result
	var required_count := maxi(0, player.hand_zone.get_card_count() - Player.MAX_HAND_SIZE)
	var selected_cards: Array[Card] = []
	var seen_uids: Array[String] = []
	for raw_uid in discard_uids:
		var discard_uid := str(raw_uid).strip_edges()
		if discard_uid == "" or discard_uid in seen_uids:
			result["reason"] = "end_turn: discard choices must be unique hand cards"
			return result
		seen_uids.append(discard_uid)
		var discard_card := game_manager.get_card_by_uid(discard_uid)
		if discard_card == null or discard_card.current_zone != player.hand_zone:
			result["reason"] = "end_turn: discard choices must be cards in your hand"
			return result
		selected_cards.append(discard_card)
	if selected_cards.size() != required_count:
		result["reason"] = "end_turn: discard exactly %d card(s) to reach the hand limit" % required_count
		return result
	result["ok"] = true
	result["reason"] = ""
	result["cards"] = selected_cards
	return result

func _queue_decision_priority_event(
	player: Player,
	source_card: Card,
	event_name: String,
	interaction_type: String,
	interaction_data: Dictionary
) -> void:
	if game_manager == null or player == null:
		return
	var action := CardAction.new()
	action.type = CardAction.Type.EVENT
	action.source_player = source_card.card_owner if source_card != null and source_card.card_owner != null else player
	action.initial_priority_player = game_manager.get_opponent(action.source_player) if action.source_player != null else null
	action.card = source_card
	action.event_name = event_name
	action.event_speed = 0
	action.resolve_callback = func() -> void:
		_emit_ui_interaction_for_player(player, interaction_type, interaction_data)
	var remains_on_stack := queue_or_resolve_priority_event(action)
	if not remains_on_stack:
		return

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
	if player == null or card == null or to_zone == null:
		return
	if card.card_type not in [Card.CardType.CREATURE, Card.CardType.STRUCTURE]:
		return
	if face_down or stealth or card.is_face_down or card.is_prepared or card.is_stealth:
		return
	if card.current_zone != to_zone or not to_zone.is_board_zone():
		return
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
	if _active_command_advances_summon_priority():
		return
	_advance_authoritative_priority_for_pending_card_events(card)

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
	var destroyed_count_before := game_manager.destroyed_this_turn.size() if game_manager != null else 0
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
		CardAction.Type.EVENT:
			_resolve_event(action)
			action_completed = pending_tezcatlipoca_titlacauan_action != action
		CardAction.Type.ATTACK:
			_resolve_attack(action)
			action_completed = pending_retreat_action != action and pending_humbaba_action != action
	if game_manager != null and pushed_effect_source:
		game_manager.pop_effect_source_card()
	if not action_completed:
		return
	_queue_destroyed_priority_events(destroyed_count_before, action)
	_finalize_resolved_action(action)

func _queue_destroyed_priority_events(start_index: int, resolved_action: CardAction) -> void:
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
		if destroyed_card.current_zone != null and destroyed_card.current_zone.is_board_zone():
			destroyed_action.resolution_text = "%s survived combat." % destroyed_card.card_name
		else:
			destroyed_action.resolution_text = "%s was destroyed." % destroyed_card.card_name
		game_manager.push_to_stack(destroyed_action)

func _finalize_resolved_action(action: CardAction) -> void:
	_remove_resolved_action(action)
	if game_manager != null and action != null:
		game_manager.end_stack_action_resolution(action)
	if game_manager != null:
		game_manager.prune_stale_stack_actions()
	action_resolved.emit(action)

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
		last_resolution_text = feedback if feedback.strip_edges() != "" else (action.resolution_text if action.resolution_text != "" else action.card.card_name + " resolved!")

func _resolve_spell(action: CardAction) -> void:
	if action.resolve_callback.is_valid():
		action.resolve_callback.call()
		last_resolution_text = action.resolution_text if action.resolution_text != "" else action.card.card_name + " resolved!"

func _resolve_event(action: CardAction) -> void:
	if action.resolve_callback.is_valid():
		if action.event_name == "tezcatlipoca_active_titlacauan":
			pending_tezcatlipoca_titlacauan_action = action
			action.resolve_callback.call()
			last_resolution_text = action.resolution_text
			return
		action.resolve_callback.call()
	var feedback := game_manager.consume_player_feedback() if game_manager != null else ""
	if feedback.strip_edges() != "":
		last_resolution_text = feedback
		return
	if action.resolution_text != "":
		last_resolution_text = action.resolution_text
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
	var attacker_on_board := action.attacker.current_zone != null and action.attacker.current_zone.is_board_zone()
	var partner_on_board := action.united_front_partner != null \
		and action.united_front_partner.current_zone != null \
		and action.united_front_partner.current_zone.is_board_zone()

	if not attacker_on_board and not partner_on_board:
		if actual_target is Card:
			game_manager._clear_combat_engagement_state(actual_target)
		last_resolution_text = action.attacker.card_name + "'s attack fizzles — attacker is no longer on the board."
		return

	if actual_target is Card and actual_target.current_zone != null and actual_target.current_zone.is_board_zone():
		if attacker_on_board:
			game_manager._begin_declared_combat(action.attacker, actual_target)
		if partner_on_board:
			game_manager._begin_declared_combat(action.united_front_partner, actual_target)

	if attacker_on_board:
		action.attacker.mark_attacked_this_turn()

	if actual_target is Card:
		# If the target left the board before the attack resolved (e.g. Gungnir destroyed it),
		# the attack fizzles — attacker still spends their action.
		if actual_target.current_zone == null or not actual_target.current_zone.is_board_zone():
			action.attacker.spend_major_creature_action()
			game_manager._clear_combat_engagement_state(actual_target)
			last_resolution_text = action.attacker.card_name + "'s attack fizzles — target is no longer on the board."
			return
		# Check for Askelladen Tactful Retreat prompts.
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
			var target_player: Player = _get_card_controller(retreat_prompts[0])
			var player_idx := game_manager.players.find(target_player)
			request_ui_interaction.emit(player_idx, "combat_retreat", {
				"action": action,
				"target": actual_target,
				"askelladen_uid": str(retreat_prompts[0].uid),
			})
			return
		pending_humbaba_action = action
		pending_humbaba_target = actual_target
		pending_humbaba_prompt_uids = _get_humbaba_prompt_uids_for_attack(action, actual_target)
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
		combatant.spend_major_creature_action()
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
	var attacker := action.attacker
	var partner := action.united_front_partner

	var finish := func() -> void:
		var active: Array[Card] = []
		if partner != null:
			active = game_manager._get_active_united_front_attackers(attacker, partner)
		elif attacker.current_zone != null and attacker.current_zone.is_board_zone():
			active = [attacker]
		for combatant in active:
			combatant.spend_major_creature_action()
			combatant.mark_attacked_this_turn()
		if active.size() >= 2:
			last_resolution_text = active[0].card_name + " and " + active[1].card_name + " fought " + target.card_name + "!"
		elif not active.is_empty():
			last_resolution_text = active[0].card_name + " fought " + target.card_name + "!"
		
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

## Returns any Askelladen cards in the combat that qualify for Tactful Retreat.
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
		humbaba.queue_augury_trigger_suppression()
		var prompt_targets := humbaba.get_augury_cards(game_manager)
		if prompt_targets.is_empty():
			game_manager.note_player_feedback("%s found no cards to read." % humbaba.card_name)
			pending_humbaba_prompt_uids.remove_at(0)
			continue
		var prompt_player := game_manager.get_opponent(humbaba.get_controller())
		if prompt_targets.size() == 1 or prompt_player == null:
			game_manager.note_player_feedback(humbaba.resolve_augury_reading(game_manager, prompt_targets[0]))
			pending_humbaba_prompt_uids.remove_at(0)
			continue
		var player_idx := game_manager.players.find(prompt_player)
		if player_idx < 0:
			game_manager.note_player_feedback(humbaba.resolve_augury_reading(game_manager, prompt_targets[0]))
			pending_humbaba_prompt_uids.remove_at(0)
			continue
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

func _continue_pending_humbaba_attack_resolution(action: CardAction, actual_target) -> void:
	if action == null:
		return
	if actual_target is Card:
		var target_card := actual_target as Card
		if target_card.current_zone == null or not target_card.current_zone.is_board_zone():
			action.attacker.spend_major_creature_action()
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
		if c != null and c.current_zone != null and c.current_zone.is_board_zone():
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
	var first_player := game_manager.priority_player
	if first_player == null:
		first_player = top_action.initial_priority_player if top_action.initial_priority_player != null else game_manager.get_opponent(top_action.source_player)
	var second_player := game_manager.get_opponent(first_player) if first_player != null else null
	return not _player_has_priority_prompt_responses(first_player) and not _player_has_priority_prompt_responses(second_player)

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
		return
	if not force_resolve and not _can_resolve_top_stack_action_now():
		_advance_authoritative_priority()
		return
	_clear_priority_window_state()
	resolve_action(action)
	if not game_manager.action_stack.is_empty():
		_advance_authoritative_priority()

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
		return "%s is targeting %s." % [source_name, _get_action_target_label(target, viewer)]
	if action_type == CardAction.Type.SPELL:
		return "Cast " + source_name + "!"
	return source_name + " activated!"

func _find_available_stack_display_zone(player: Player) -> Zone:
	if player == null:
		return null
	for zone in player.frontline_zones + player.reserve_zones:
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

func _assign_stack_display_zone(action: CardAction, preferred_zone: Zone = null) -> void:
	if action == null or action.card == null or action.source_player == null:
		return
	if preferred_zone != null and _can_use_stack_display_zone(preferred_zone, action.source_player):
		action.display_zone = preferred_zone
		if not action.card.goes_to_graveyard_after_use():
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
	action.type = action_type
	action.source_player = source_card.card_owner if source_card.card_owner != null else game_manager.current_player
	action.card = source_card
	action.target = target
	action.response_to = response_to
	action.resolve_callback = resolve_callback
	action.resolution_text = resolution_text if resolution_text != "" else _build_authoritative_resolution_text(action_type, source_card, target)
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
	var targets := _get_priority_response_targets(card, top)
	for target in targets:
		if target is Card:
			target_uids.append((target as Card).uid)
	return target_uids

func _validate_priority_response_target(card: Card, top: CardAction, target: Card, target_uid: String, context: String) -> String:
	var requested_uid := str(target_uid).strip_edges()
	var valid_targets := _get_priority_response_targets(card, top)
	if not requested_uid.is_empty():
		if target == null:
			return context + ": target not found"
		if target not in valid_targets:
			return context + ": invalid priority target"
		return ""
	if card != null and card.targets:
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
			if hex.targets and hex_target_uids.is_empty():
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
			if charm.targets and charm_target_uids.is_empty():
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
			if spell.targets and spell_target_uids.is_empty():
				continue
			response_options.append({
				response_type = "spell",
				card_uid = spell.uid,
				target_uids = spell_target_uids,
			})
		elif card != null and card.is_god and card.has_method("get_valid_targets"):
			var god_target_uids := _get_priority_response_target_uids(card, top)
			if card.targets and god_target_uids.is_empty():
				continue
			response_options.append({
				response_type = "god",
				card_uid = card.uid,
				target_uids = god_target_uids,
			})
		elif card != null and card.has_method("can_respond_to_priority_action") and card.has_method("activate"):
			var ability_target_uids := _get_priority_response_target_uids(card, top)
			if card.targets and ability_target_uids.is_empty():
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
			responses = [],
			action_message = "",
		}
	var responses := game_manager.get_priority_responses(player)
	if game_manager.action_stack.is_empty():
		return {
			responses = [],
			action_message = "",
		}
	return {
		responses = _build_priority_response_options(responses),
		action_message = _get_priority_action_message(game_manager.action_stack.back(), player),
	}

func _player_has_priority_prompt_responses(player: Player) -> bool:
	if player == null:
		return false
	var prompt_data := build_priority_prompt_data(player)
	if prompt_data.is_empty():
		return false
	var responses: Array = prompt_data.get("responses", [])
	return not responses.is_empty()

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
	if _authoritative_stack_resolution_pending:
		return
	game_manager.prune_stale_stack_actions()
	if game_manager.action_stack.is_empty():
		return
	var player := game_manager.priority_player
	if player == null:
		var top_action: CardAction = game_manager.action_stack.back()
		player = top_action.initial_priority_player if top_action.initial_priority_player != null else game_manager.get_opponent(top_action.source_player)
		game_manager.priority_player = player
	if player == null:
		return
	var prompt_data := build_priority_prompt_data(player)
	var prompt_responses: Array = prompt_data.get("responses", [])
	if prompt_responses.is_empty():
		game_manager.pass_priority()
		if game_manager.both_passed():
			if game_manager.action_stack.is_empty():
				_clear_priority_window_state()
				return
			_schedule_authoritative_stack_top_after_priority()
		else:
			_advance_authoritative_priority()
		return
	var player_idx := game_manager.players.find(player)
	request_ui_interaction.emit(player_idx, "priority", prompt_data)

func queue_or_resolve_priority_event(action: CardAction) -> bool:
	if action == null:
		return false
	game_manager.push_to_stack(action)
	var first_player: Player = game_manager.priority_player
	if first_player == null:
		first_player = action.initial_priority_player if action.initial_priority_player != null else game_manager.get_opponent(action.source_player)
	var second_player: Player = game_manager.get_opponent(first_player) if first_player != null else null
	var first_has_responses: bool = _player_has_priority_prompt_responses(first_player)
	var second_has_responses: bool = _player_has_priority_prompt_responses(second_player)
	if first_has_responses or second_has_responses:
		if game_manager.priority_player == null:
			game_manager.priority_player = first_player
		if _uses_authoritative_headless_priority_flow():
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
	event_speed: int = 0
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

func _has_unresolved_stack_action_window() -> bool:
	if game_manager == null:
		return false
	game_manager.prune_stale_stack_actions()
	return _authoritative_stack_resolution_pending \
		or not game_manager.action_stack.is_empty() \
		or not game_manager.resolving_stack_actions.is_empty()

func has_unresolved_stack_action_window() -> bool:
	return _has_unresolved_stack_action_window()

func is_authoritative_stack_resolution_pending() -> bool:
	return _authoritative_stack_resolution_pending

func _request_ui_refresh() -> void:
	ui_refresh_requested.emit()

func _resolve_authoritative_headless_attack() -> void:
	var attack_action := _build_pending_attack_action()
	if attack_action == null:
		move_failed.emit("The pending attack could not be resolved.")
		_clear_pending_attack_state()
		return
	_clear_pending_attack_state()
	game_manager.push_to_stack(attack_action)
	_request_ui_refresh()
	_advance_authoritative_priority()

func _start_authoritative_headless_attack() -> void:
	if selected_attacker == null or pending_attack_target == null:
		move_failed.emit("The pending attack is missing an attacker or target.")
		_clear_pending_attack_state()
		return
	selected_interceptor = null
	var possible_interceptors := _get_possible_interceptors(selected_attacker, pending_attack_target)
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
	_emit_ui_interaction_for_player(defender, "intercept", {
		"interceptor_uids": interceptor_uids,
		"attacker": selected_attacker,
		"target": pending_attack_target,
		"action_message": attacker_name + " is attacking - intercept or allow?"
	})

# --- Attack Management ---

func can_attack(card: Card) -> bool:
	if card == null or game_manager == null:
		return false
	if _has_unresolved_stack_action_window():
		return false
		
	return (
		card.card_type == Card.CardType.CREATURE
		and card.get_controller() == game_manager.current_player
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
	if _has_unresolved_stack_action_window():
		return "Resolve the pending stack action before attacking."
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
		move_failed.emit(get_attack_invalid_reason(card))

func request_attack(attacker, target) -> void:
	var attacker_card: Card = attacker if attacker is Card else game_manager.get_card_by_uid(str(attacker))
	var target_obj = target
	
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
		return
		
	if not can_attack(attacker_card):
		move_failed.emit(get_attack_invalid_reason(attacker_card))
		return
		
	# Check if target is valid for engagement
	if target_obj is Card:
		if not game_manager.can_cards_engage_each_other(attacker_card, target_obj):
			move_failed.emit(attacker_card.card_name + " cannot engage " + target_obj.card_name + ".")
			return
	elif target_obj is Player:
		var allied_attackers := []
		var united_front_partner := _get_declared_attack_partner(attacker_card)
		if united_front_partner != null:
			allied_attackers.append(united_front_partner)
		if game_manager.is_followers_attack_blocked_by_active_structure(attacker_card, target_obj, allied_attackers):
			move_failed.emit(attacker_card.card_name + " cannot attack " + target_obj.player_name + "'s followers.")
			return

	selected_attacker = attacker_card
	pending_attack_target = target_obj
	selected_interceptor = null
	
	# In a real game, this might trigger an "intercept" phase
	move_validated.emit({"type": "attack", "attacker": attacker_card, "target": target_obj})
	if _uses_authoritative_headless_attack_flow():
		_start_authoritative_headless_attack()

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

func _get_required_player_for_command(command: Dictionary) -> Player:
	match str(command.get("type", "")):
		"select_attacker":
			return _get_card_controller(game_manager.get_card_by_uid(str(command.get("card_uid", ""))))
		"request_attack":
			return _get_card_controller(game_manager.get_card_by_uid(str(command.get("attacker_uid", ""))))
		"cancel_targeting", "confirm_click_selection":
			return _get_current_targeting_player()
		"play_card", "prepare_card", "play_creature", "creature_move", "change_mode", "equip_action":
			return _get_card_controller(game_manager.get_card_by_uid(str(command.get("card_uid", ""))))
		"cast_spell":
			return _get_card_controller(game_manager.get_card_by_uid(str(command.get("spell_uid", ""))))
		"activate_prepared_hex":
			return _get_card_controller(game_manager.get_card_by_uid(str(command.get("hex_uid", ""))))
		"god_ability":
			return _get_card_controller(game_manager.get_card_by_uid(str(command.get("god_uid", ""))))
		"play_priority_ability":
			return _get_card_controller(game_manager.get_card_by_uid(str(command.get("source_uid", ""))))
		"activate_power", "unlock_power", "activate_divine_caprice", "apply_advanced_building_techniques":
			return _get_card_controller(game_manager.get_card_by_uid(str(command.get("power_uid", ""))))
		"cast_charm", "play_charm_response":
			return _get_card_controller(game_manager.get_card_by_uid(str(command.get("charm_uid", ""))))
		"play_hex_response":
			return _get_card_controller(game_manager.get_card_by_uid(str(command.get("hex_uid", ""))))
		"hati_moon_hunt":
			return _get_card_controller(game_manager.get_card_by_uid(str(command.get("hati_uid", ""))))
		"skoll_upkeep_summon":
			return _get_card_controller(game_manager.get_card_by_uid(str(command.get("skoll_uid", ""))))
		"activate_card_ability", "en_hedu_anna_exaltation", "aphrodite_enslave_choice", "blessed_knights_choice", "wolf_adolescent_maturation_choice", "wheel_of_fire_turn_start_choice", "tezcatlipoca_active_titlacauan_choice", "nusku_active_core_flame_choice", "mummu_entropy_choice", "first_sage_adapa_choice", "third_sage_enmedugga_choice", "fourth_sage_enmegalamma_choice", "sixth_sage_an_enlilda_choice", "lailoken_reveal_choice", "masmassu_priest_reveal_choice", "rally_the_troops_choice", "terror_impact_choice", "huginn_perish_prime_choice", "muninn_perish_prime_choice", "fenrir_devour_choice", "harii_jarl_impact_choice", "durinn_secondborn_choice", "kur_jara_tree_of_life_choice", "hunting_tactics_choice", "foolish_optimism_choice", "gugalanna_celestial_charge_choice", "freyja_active_open_sessrumnir_choice", "giant_master_architect_choice", "pai_long_autumn_king_choice", "nergal_lion_choice", "gala_tura_destroyed_choice", "gawain_healing_hands_choice", "tatzelwurm_dragon_heart_choice", "byggvir_reveal_choice", "apollyons_demiurge_choice":
			return _get_card_controller(game_manager.get_card_by_uid(str(command.get("source_uid", ""))))
		"humbaba_augury_choice":
			var humbaba := game_manager.get_card_by_uid(str(command.get("source_uid", ""))) as HumbabaTheTerrible
			return game_manager.get_opponent(humbaba.get_controller()) if humbaba != null else null
		"nusku_well_of_fire_choice":
			var nusku := game_manager.get_card_by_uid(str(command.get("source_uid", ""))) as NuskuFirebearer
			return game_manager.get_opponent(nusku.get_controller()) if nusku != null else null
		"ragnarok_discard_choice":
			var power := game_manager.get_card_by_uid(str(command.get("source_uid", ""))) as Ragnarok
			return power.get_pending_discard_player(game_manager) if power != null else null
		"return_to_hand_choice":
			return _get_card_controller(game_manager.get_card_by_uid(str(command.get("card_uid", ""))))
		"doorway_choice":
			var pending_structure := game_manager.get_pending_doorway_structure()
			if pending_structure != null:
				return _get_card_controller(pending_structure)
			return _get_card_controller(game_manager.get_card_by_uid(str(command.get("structure_uid", ""))))
		"wolf_master_summon":
			return _get_card_controller(game_manager.get_card_by_uid(str(command.get("fenrir_uid", ""))))
		"intercept_decision":
			var interceptor_uid := str(command.get("interceptor_uid", ""))
			if not interceptor_uid.is_empty():
				return _get_card_controller(game_manager.get_card_by_uid(interceptor_uid))
			if pending_attack_target is Card:
				return _get_card_controller(pending_attack_target)
			if pending_attack_target is Player:
				return pending_attack_target
			return game_manager.other_player
		"combat_retreat_decision":
			var askelladen_uid := str(command.get("askelladen_uid", "")).strip_edges()
			if not askelladen_uid.is_empty():
				return _get_card_controller(game_manager.get_card_by_uid(askelladen_uid))
			return _get_pending_retreat_prompt_player()
		"resurrection_choice":
			var resurrect_card := game_manager.get_card_by_uid(str(command.get("card_uid", "")))
			return resurrect_card.card_owner if resurrect_card != null else null
		"priority_pass":
			return game_manager.priority_player if game_manager.priority_player != null else game_manager.current_player
		"forfeit":
			var forfeiting_index := int(command.get("player_index", -1))
			if forfeiting_index >= 0 and forfeiting_index < game_manager.players.size():
				return game_manager.players[forfeiting_index]
			return null
		"upkeep_choice", "tiamat_upkeep_choice", "end_turn":
			return game_manager.current_player
	return null

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
			return "Waiting for %s to decide Tactful Retreat." % required_player.player_name
		return "Unauthorized command: that action belongs to %s." % required_player.player_name
	return ""

func _get_command_actor(sender_info: Dictionary) -> Player:
	var sender_player := _resolve_sender_player(sender_info)
	return sender_player if sender_player != null else game_manager.current_player

func _requires_resolved_upkeep(command: Dictionary) -> bool:
	var command_type := str(command.get("type", ""))
	if command_type == "activate_power" and str(command.get("mode", "")) == "return_priest":
		return false
	match command_type:
		# These commands are valid while the current player is still inside a
		# turn-start prompt/upkeep window and should not be blocked by the
		# generic "resolve upkeep first" guard.
		"upkeep_choice", "tiamat_upkeep_choice", "skoll_upkeep_summon", "priority_pass", "intercept_decision", "combat_retreat_decision", "play_hex_response", "play_charm_response", "play_priority_ability", "forfeit", "humbaba_augury_choice", "return_to_hand_choice", "doorway_choice":
			return false
	return true

func _requires_clear_stack_window(command_type: String) -> bool:
	match command_type:
		"select_attacker", "request_attack", "play_card", "prepare_card", "play_creature", "creature_move", "equip_action", "change_mode", "end_turn":
			return true
		"cast_spell", "activate_prepared_hex", "god_ability", "activate_power", "unlock_power", "activate_divine_caprice", "cast_charm", "activate_card_ability", "en_hedu_anna_exaltation":
			return true
	return false

func _validate_turn_action_window(command: Dictionary, sender_info: Dictionary) -> String:
	var command_type := str(command.get("type", ""))
	if _requires_clear_stack_window(command_type) and _has_unresolved_stack_action_window():
		return "Resolve the pending stack action before continuing."
	var actor := _get_command_actor(sender_info)
	if actor == null:
		return ""
	if _requires_resolved_upkeep(command) and actor == game_manager.current_player and not game_manager.has_resolved_turn_upkeep():
		return "Resolve upkeep before taking other actions."
	return ""

func _validate_upkeep_choice_window(actor: Player) -> String:
	if game_manager == null or actor == null:
		return ""
	if actor != game_manager.current_player:
		return "It is not your turn."
	if not game_manager.is_player_in_upkeep_window(actor):
		return "Upkeep has already been resolved."
	return ""

func _on_move_failed(reason: String) -> void:
	last_move_failed_reason = reason
	_send_rejection_to_sender(_active_command_sender_info, reason)

# --- Network Command Support ---

## Entry point for commands from the network.
## Commands are Dictionaries containing "type" and relevant IDs.
## Returns true on success, false on failure (failure also emits move_failed).
func process_command(command: Dictionary, sender_info: Dictionary = {}) -> bool:
	_active_command_sender_info = sender_info.duplicate(true)
	_active_command_type = str(command.get("type", ""))
	var authority_error := _validate_sender_authority(command, sender_info)
	if not authority_error.is_empty():
		move_failed.emit(authority_error)
		_active_command_sender_info.clear()
		_active_command_type = ""
		return false
	var turn_window_error := _validate_turn_action_window(command, sender_info)
	if not turn_window_error.is_empty():
		move_failed.emit(turn_window_error)
		_active_command_sender_info.clear()
		_active_command_type = ""
		return false
	var pending_prompt_validation := _validate_pending_ui_interaction_for_command(command)
	var pending_prompt_error := str(pending_prompt_validation.get("error", ""))
	if not pending_prompt_error.is_empty():
		move_failed.emit(pending_prompt_error)
		_active_command_sender_info.clear()
		_active_command_type = ""
		return false
	var result := _process_command_impl(command)
	if result:
		_consume_pending_ui_interaction_by_id(int(pending_prompt_validation.get("prompt_id", -1)))
	_active_command_sender_info.clear()
	_active_command_type = ""
	return result

func _process_command_impl(command: Dictionary) -> bool:
	var acting_player := _get_command_actor(_active_command_sender_info)
	match command.get("type", ""):
		"select_attacker":
			var uid = command.get("card_uid", "")
			var card = game_manager.get_card_by_uid(uid)
			select_attacker(card)
			return true
		"request_attack":
			var attacker_uid = command.get("attacker_uid", "")
			var target_id = command.get("target_id", "") # Can be card UID or player name/index
			request_attack(attacker_uid, target_id)
			return true
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
			var mode: Card.CreatureMode = int(command.get("mode", -1)) as Card.CreatureMode
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
				_:
					move_failed.emit("upkeep_choice: unknown choice '" + str(command.get("choice")) + "'")
					return false
			move_validated.emit(command)
			if _uses_authoritative_headless_priority_flow():
				var choice_feedback := _build_upkeep_resolution_feedback(
					game_manager.get_upkeep_choice_feedback(str(command.get("choice", "")))
				)
				if _has_pending_wheel_of_fire_turn_start_choice():
					_emit_next_wheel_of_fire_turn_start_choice()
					return true
				_queue_authoritative_priority_event(
					"start_turn",
					Callable(),
					game_manager.current_player,
					game_manager.current_player,
					choice_feedback
				)
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
				if _has_pending_wheel_of_fire_turn_start_choice():
					_emit_next_wheel_of_fire_turn_start_choice()
					return true
				_queue_authoritative_priority_event(
					"start_turn",
					Callable(),
					game_manager.current_player,
					game_manager.current_player,
					tiamat_feedback
				)
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
					move_failed.emit(
						game_manager.get_activation_mana_unavailable_text(spell)
						if game_manager.has_insufficient_activation_mana(spell, true, player)
						else spell.card_name + " cannot activate right now."
					)
					return false
				if not game_manager.activate_prepared_card(spell, player):
					spell.clear_pending_chosen_sacrifices()
					move_failed.emit(
						game_manager.get_activation_mana_unavailable_text(spell)
						if game_manager.has_insufficient_activation_mana(spell, true, player)
						else "Cannot afford " + spell.card_name + "!"
					)
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
					move_failed.emit("Cannot afford " + spell.card_name + "!")
					return false
				if mana_required < spell.mana_cost:
					game_manager.claim_cost_adjustments(
						spell,
						spell.mana_cost,
						Card.COST_KIND_HAND_PLAY,
						{"player": player, "prepared": false}
					)
			if _uses_authoritative_headless_priority_flow():
				var preferred_display_zone: Zone = spell.current_zone if prepared_spell else (
					spell_target.current_zone if spell_target != null and spell_target.current_zone != null and spell_target.current_zone.is_board_zone() else null
				)
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
				move_validated.emit(command)
				_advance_authoritative_priority()
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
		"activate_prepared_hex":
			var hex_uid: String = command.get("hex_uid", "")
			var hex_card := game_manager.get_card_by_uid(hex_uid)
			if hex_card == null or not (hex_card is HexCard):
				move_failed.emit("activate_prepared_hex: hex not found")
				return false
			var hex := hex_card as HexCard
			if not hex.can_activate_prepared(game_manager, acting_player):
				move_failed.emit(
					game_manager.get_activation_mana_unavailable_text(hex)
					if game_manager.has_insufficient_activation_mana(hex, true, acting_player)
					else hex.card_name + " cannot activate right now."
				)
				return false
			if not game_manager.activate_prepared_card(hex, acting_player):
				move_failed.emit(
					game_manager.get_activation_mana_unavailable_text(hex)
					if game_manager.has_insufficient_activation_mana(hex, true, acting_player)
					else "Cannot afford " + hex.card_name + "!"
				)
				return false
			var hex_action := CardAction.new()
			hex_action.type = CardAction.Type.ABILITY
			hex_action.source_player = hex.card_owner
			hex_action.card = hex
			hex_action.resolution_text = hex.card_name + " resolved."
			game_manager.push_to_stack(hex_action)
			move_validated.emit(command)
			if _uses_authoritative_headless_priority_flow():
				_advance_authoritative_priority()
			return true
		"god_ability":
			var god_uid: String = command.get("god_uid", "")
			var god_card := game_manager.get_card_by_uid(god_uid)
			if god_card == null or not god_card.is_god:
				move_failed.emit("god_ability: god card not found")
				return false
			if not god_card.has_method("can_activate") or not god_card.can_activate(game_manager):
				var god_failure_reason: String = str(god_card.get_activation_failure_reason(game_manager)) if god_card.has_method("get_activation_failure_reason") else ""
				move_failed.emit(god_failure_reason if god_failure_reason != "" else god_card.card_name + "'s ability cannot be activated right now.")
				return false
			var target: Card = null
			var target_uid: String = command.get("target_uid", "")
			if target_uid != "":
				target = game_manager.get_card_by_uid(target_uid)
			if god_card.targets and target == null:
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
				move_validated.emit(command)
				_advance_authoritative_priority()
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
					move_failed.emit(power_card.card_name + " cannot activate right now.")
					return false
				if _uses_authoritative_headless_priority_flow():
					_queue_authoritative_magical_action(
						CardAction.Type.ABILITY,
						power_card,
						act_target,
						func() -> void:
							power_card.activate(game_manager, act_target)
					)
					move_validated.emit(command)
					_advance_authoritative_priority()
					return true
				game_manager.run_with_effect_source(
					power_card,
					func() -> void:
						power_card.activate(game_manager, act_target)
				)
			move_validated.emit(command)
			return true
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
					move_failed.emit(game_manager.get_activation_mana_unavailable_text(charm_card) if game_manager.has_insufficient_activation_mana(charm_card, true, charm_card.card_owner) else charm_card.card_name + " cannot activate right now.")
					return false
				if not game_manager.activate_prepared_card(charm_card, charm_card.card_owner):
					move_failed.emit(game_manager.get_activation_mana_unavailable_text(charm_card) if game_manager.has_insufficient_activation_mana(charm_card, true, charm_card.card_owner) else "Cannot afford " + charm_card.card_name + "!")
					return false
			else:
				if not charm_card.can_activate_from_hand(game_manager, charm_source_action):
					move_failed.emit(charm_card.card_name + " cannot be played right now.")
					return false
				if not charm_card.pay_costs(charm_card.card_owner, game_manager):
					move_failed.emit(game_manager.get_activation_mana_unavailable_text(charm_card) if game_manager.has_insufficient_activation_mana(charm_card, false, charm_card.card_owner) else "Cannot afford " + charm_card.card_name + "!")
					return false
			if _uses_authoritative_headless_priority_flow():
				var preferred_display_zone: Zone = charm_card.current_zone if charm_prepared else (charm_target.current_zone if charm_target != null and charm_target.current_zone != null and charm_target.current_zone.is_board_zone() else null)
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
				move_validated.emit(command)
				_advance_authoritative_priority()
				return true
			game_manager.run_with_effect_source(
				charm_card,
				func() -> void:
					_place_persistent_charm_on_board(charm_card, charm_target.current_zone if charm_target != null else null)
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
			if hati_zone == null or hati_zone.zone_owner != game_manager.current_player \
					or hati_zone.zone_type not in [Zone.ZoneType.FRONTLINE, Zone.ZoneType.RESERVE] \
					or not hati_zone.cards.is_empty():
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
				if _emit_next_wheel_of_fire_turn_start_choice():
					return true
				_queue_authoritative_priority_event(
					"start_turn",
					Callable(),
					game_manager.current_player,
					game_manager.current_player,
					_build_upkeep_resolution_feedback(feedback)
				)
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
			if aca_target == null and not aca_option.is_empty():
				var nested_target_uid := str(aca_option.get("target_uid", aca_option.get("chosen_uid", ""))).strip_edges()
				if nested_target_uid != "":
					aca_target = game_manager.get_card_by_uid(nested_target_uid)
			var ability_ward_block_reason := game_manager.get_turn_destruction_ward_activation_block_reason(aca_source, aca_target)
			if ability_ward_block_reason != "":
				move_failed.emit(ability_ward_block_reason)
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
					func() -> void:
						if aca_source.card_type == Card.CardType.CREATURE \
								and not game_manager.pay_creature_action_mana_cost(aca_source, "activate"):
							return
						if command.has("return_to_hand"):
							aca_source.activate(game_manager, {"return_to_hand": bool(command.get("return_to_hand", false))})
						elif command.has("option"):
							aca_source.activate(game_manager, aca_option)
						elif aca_target != null:
							aca_source.activate(game_manager, aca_target)
						else:
							aca_source.activate(game_manager)
				)
				move_validated.emit(command)
				_advance_authoritative_priority()
				return true
			if command.has("return_to_hand"):
				game_manager.run_with_effect_source(
					aca_source,
					func() -> void:
						if aca_source.card_type == Card.CardType.CREATURE \
								and not game_manager.pay_creature_action_mana_cost(aca_source, "activate"):
							return
						aca_source.activate(game_manager, {"return_to_hand": bool(command.get("return_to_hand", false))})
				)
			elif command.has("option"):
				game_manager.run_with_effect_source(
					aca_source,
					func() -> void:
						if aca_source.card_type == Card.CardType.CREATURE \
								and not game_manager.pay_creature_action_mana_cost(aca_source, "activate"):
							return
						aca_source.activate(game_manager, aca_option)
				)
			elif aca_target != null:
				game_manager.run_with_effect_source(
					aca_source,
					func() -> void:
						if aca_source.card_type == Card.CardType.CREATURE \
								and not game_manager.pay_creature_action_mana_cost(aca_source, "activate"):
							return
						aca_source.activate(game_manager, aca_target)
				)
			else:
				game_manager.run_with_effect_source(
					aca_source,
					func() -> void:
						if aca_source.card_type == Card.CardType.CREATURE \
								and not game_manager.pay_creature_action_mana_cost(aca_source, "activate"):
							return
						aca_source.activate(game_manager)
				)
			move_validated.emit(command)
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
			var target := game_manager.get_card_by_uid(target_uid)
			if target == null or target not in valid_targets:
				move_failed.emit("first_sage_adapa_choice: invalid silence target")
				return false
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
				if valid_targets.size() == 1 and valid_targets[0] == sage:
					game_manager.note_player_feedback(sage.resolve_good_fortune_impact(game_manager, sage))
					move_validated.emit(command)
					return true
				var feedback := "%s found no Mer Sage to bless." % sage.card_name if valid_targets.is_empty() else sage.card_name + " impact fizzles."
				game_manager.note_player_feedback(feedback)
				move_validated.emit(command)
				return true
			var target := game_manager.get_card_by_uid(target_uid)
			if target == null or target not in valid_targets:
				move_failed.emit("third_sage_enmedugga_choice: invalid Mer Sage target")
				return false
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
				game_manager.note_player_feedback(feedback)
				move_validated.emit(command)
				return true
			var target := game_manager.get_card_by_uid(target_uid)
			if target == null or target not in valid_targets:
				move_failed.emit("sixth_sage_an_enlilda_choice: invalid Ancient Dwelling target")
				return false
			game_manager.note_player_feedback(sage.resolve_conjure_home_impact(game_manager, target))
			move_validated.emit(command)
			return true
		"lailoken_reveal_choice":
			var source_uid: String = command.get("source_uid", "")
			var lailoken := game_manager.get_card_by_uid(source_uid) as Lailoken
			if lailoken == null:
				move_failed.emit("lailoken_reveal_choice: card not found")
				return false
			var valid_targets := lailoken.get_valid_targets(game_manager)
			var target_uid: String = command.get("target_uid", "")
			if target_uid == "":
				var feedback := "%s found no prepared magical cards to drain." % lailoken.card_name if valid_targets.is_empty() else lailoken.card_name + " reveal fizzles."
				game_manager.note_player_feedback(feedback)
				move_validated.emit(command)
				return true
			var target := game_manager.get_card_by_uid(target_uid)
			if target == null or target not in valid_targets:
				move_failed.emit("lailoken_reveal_choice: invalid magical target")
				return false
			lailoken.begin_magic_drain_reveal(
				game_manager,
				target,
				func(result_text: String) -> void:
					if result_text.strip_edges() != "":
						game_manager.note_player_feedback(result_text)
			)
			move_validated.emit(command)
			return true
		"masmassu_priest_reveal_choice":
			var source_uid: String = command.get("source_uid", "")
			var priest := game_manager.get_card_by_uid(source_uid) as MasmassuPriest
			if priest == null:
				move_failed.emit("masmassu_priest_reveal_choice: card not found")
				return false
			var valid_targets := priest.get_valid_targets(game_manager)
			var target_uid: String = command.get("target_uid", "")
			if target_uid == "":
				var feedback := "%s found no non-Human creatures to break." % priest.card_name if valid_targets.is_empty() else priest.card_name + " reveal fizzles."
				game_manager.note_player_feedback(feedback)
				move_validated.emit(command)
				return true
			var target := game_manager.get_card_by_uid(target_uid)
			if target == null or target not in valid_targets:
				move_failed.emit("masmassu_priest_reveal_choice: invalid creature target")
				return false
			priest.begin_dalkhu_break_reveal(
				game_manager,
				target,
				func(result_text: String) -> void:
					if result_text.strip_edges() != "":
						game_manager.note_player_feedback(result_text)
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
			if target == null or target not in valid_targets:
				move_failed.emit("terror_impact_choice: invalid creature target")
				return false
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
				game_manager.note_player_feedback(fenrir.card_name + " impact fizzles.")
				move_validated.emit(command)
				return true
			var target := game_manager.get_card_by_uid(target_uid)
			if target == null or target not in valid_targets:
				move_failed.emit("fenrir_devour_choice: invalid creature target")
				return false
			fenrir.resolve_devour_impact(
				game_manager,
				target,
				func(feedback: String) -> void:
					if feedback.strip_edges() != "":
						game_manager.note_player_feedback(feedback)
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
			if target == null or target not in valid_targets:
				move_failed.emit("durinn_secondborn_choice: invalid weapon target")
				return false
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
			game_manager.note_player_feedback(power.resolve_combat_support_choice(game_manager, attacker, chosen_cards))
			move_validated.emit(command)
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
			if target != null and target not in valid_targets:
				move_failed.emit("gugalanna_celestial_charge_choice: invalid target")
				return false
			card.apply_celestial_charge(game_manager, target)
			move_validated.emit(command)
			return true
		"freyja_active_open_sessrumnir_choice":
			var source_uid: String = command.get("source_uid", "")
			var active_god := game_manager.get_card_by_uid(source_uid) as FreyjaActive
			if active_god == null:
				move_failed.emit("freyja_active_open_sessrumnir_choice: active god not found")
				return false
			var option: Dictionary = command.get("option", {})
			var selection_data = option if not option.is_empty() else command
			var chosen_targets := active_god.get_selected_open_sessrumnir_targets(game_manager, selection_data)
			var raw_choices: Array = []
			if selection_data is Dictionary:
				raw_choices = selection_data.get("target_uids", [])
			elif selection_data is Array:
				raw_choices = selection_data
			if chosen_targets.size() != raw_choices.size():
				move_failed.emit("freyja_active_open_sessrumnir_choice: invalid target")
				return false
			var skip_choice := bool(option.get("skip", command.get("skip", false)))
			if not skip_choice and not active_god.is_valid_open_sessrumnir_selection(game_manager, chosen_targets):
				move_failed.emit("freyja_active_open_sessrumnir_choice: invalid selection")
				return false
			active_god.resolve_from_command(game_manager, command)
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
				move_failed.emit("nergal_lion_choice: invalid destruction target")
				return false
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
			var pending_choice_uids: Array = nusku.get_meta("well_of_fire_pending_choice_uids", [])
			if target == null or target.uid not in pending_choice_uids:
				move_failed.emit("nusku_well_of_fire_choice: invalid Well of Fire choice")
				return false
			nusku._complete_well_of_fire(game_manager, target, int(nusku.get_meta("well_of_fire_pending_mill_count", int(command.get("mill_count", NuskuFirebearer.MILL_COUNT)))))
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
			move_validated.emit(command)
			return true
		"tezcatlipoca_active_titlacauan_choice":
			var source_uid: String = command.get("source_uid", "")
			var active_god := game_manager.get_card_by_uid(source_uid)
			if active_god == null or not active_god.has_method("resolve_from_command"):
				move_failed.emit("tezcatlipoca_active_titlacauan_choice: active god not found")
				return false
			active_god.resolve_from_command(game_manager, command)
			var feedback := game_manager.consume_player_feedback()
			if feedback.strip_edges() != "":
				game_manager.note_player_feedback(feedback)
				last_resolution_text = feedback
			move_validated.emit(command)
			if pending_tezcatlipoca_titlacauan_action != null:
				var action := pending_tezcatlipoca_titlacauan_action
				pending_tezcatlipoca_titlacauan_action = null
				_finalize_resolved_action(action)
			return true
		"nusku_active_core_flame_choice":
			var source_uid: String = command.get("source_uid", "")
			var active_god := game_manager.get_card_by_uid(source_uid)
			if active_god == null or not active_god.has_method("resolve_from_command"):
				move_failed.emit("nusku_active_core_flame_choice: active god not found")
				return false
			var chosen_uid: String = str(command.get("chosen_uid", command.get("target_uid", ""))).strip_edges()
			if chosen_uid != "":
				var nusku_active := active_god as NuskuActive
				if nusku_active == null or not nusku_active.is_pending_core_flame_choice_uid(chosen_uid):
					move_failed.emit("nusku_active_core_flame_choice: invalid Core Flame choice")
					return false
			active_god.resolve_from_command(game_manager, command)
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
		"wolf_adolescent_maturation_choice":
			var source_uid: String = command.get("source_uid", "")
			var wolf := game_manager.get_card_by_uid(source_uid) as WolfAdolescent
			if wolf == null:
				move_failed.emit("wolf_adolescent_maturation_choice: card not found")
				return false
			if not wolf.can_offer_maturation(game_manager):
				move_failed.emit("wolf_adolescent_maturation_choice: Maturation is not available")
				return false
			var target_uid: String = command.get("target_uid", "")
			var target: Card = game_manager.get_card_by_uid(target_uid) if target_uid != "" else null
			var valid_targets := wolf.get_valid_maturation_targets()
			if target != null and target not in valid_targets:
				move_failed.emit("wolf_adolescent_maturation_choice: invalid Lupine target")
				return false
			var feedback := wolf.resolve_maturation_choice(game_manager, target)
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
			move_validated.emit(command)
			if pending_humbaba_action != null:
				var action := pending_humbaba_action
				var pending_target = pending_humbaba_target
				if not pending_humbaba_prompt_uids.is_empty():
					pending_humbaba_prompt_uids.remove_at(0)
				if _emit_next_pending_humbaba_prompt():
					return true
				_clear_pending_humbaba_state()
				_continue_pending_humbaba_attack_resolution(action, pending_target)
				_finalize_resolved_action(action)
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
				move_failed.emit(dc.card_name + " cannot activate right now.")
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
				move_validated.emit(command)
				_advance_authoritative_priority()
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
				move_failed.emit(game_manager.get_activation_mana_unavailable_text(pcr_charm) if game_manager.has_insufficient_activation_mana(pcr_charm, not pcr_from_hand, pcr_charm.card_owner) else "play_charm_response: charm cannot respond right now")
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
					move_failed.emit(game_manager.get_activation_mana_unavailable_text(pcr_charm_card) if game_manager.has_insufficient_activation_mana(pcr_charm_card, false, pcr_charm_card.card_owner) else "Cannot afford " + pcr_charm_card.card_name + "!")
					return false
			else:
				if not game_manager.activate_prepared_card(pcr_charm, pcr_charm.card_owner):
					move_failed.emit(game_manager.get_activation_mana_unavailable_text(pcr_charm_card) if game_manager.has_insufficient_activation_mana(pcr_charm_card, true, pcr_charm_card.card_owner) else "Cannot afford " + pcr_charm_card.card_name + "!")
					return false
			var pcr_action := CardAction.new()
			pcr_action.type = CardAction.Type.SPELL
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
				if not pra_action.event_data.is_empty():
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
					pra_source.activate(game_manager, activation_context)
				elif pra_target != null:
					pra_source.activate(game_manager, pra_target)
				else:
					pra_source.activate(game_manager)
			game_manager.push_to_stack(pra_action)
			move_validated.emit(command)
			if _uses_authoritative_headless_priority_flow():
				_advance_authoritative_priority()
			return true
		"priority_pass":
			if _uses_authoritative_headless_priority_flow():
				game_manager.pass_priority()
				move_validated.emit(command)
				if game_manager.both_passed():
					if not game_manager.action_stack.is_empty():
						_schedule_authoritative_stack_top_after_priority()
					else:
						_clear_priority_window_state()
				else:
					_advance_authoritative_priority()
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
				if player.mana < 1:
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

				player.spend_mana(1)
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
					player.gain_mana(1)
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
				move_failed.emit(game_manager.get_activation_mana_unavailable_text(phr_hex_card) if game_manager.has_insufficient_activation_mana(phr_hex_card, true, phr_hex_card.card_owner) else "play_hex_response: hex cannot respond right now")
				return false
			var phr_target_uid: String = command.get("target_uid", "")
			var phr_target: Card = game_manager.get_card_by_uid(phr_target_uid) if phr_target_uid != "" else null
			var phr_hex := phr_hex_card as HexCard
			var phr_target_error := _validate_priority_response_target(phr_hex, phr_source, phr_target, phr_target_uid, "play_hex_response")
			if not phr_target_error.is_empty():
				move_failed.emit(phr_target_error)
				return false
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
				move_failed.emit(game_manager.get_activation_mana_unavailable_text(phr_hex) if game_manager.has_insufficient_activation_mana(phr_hex, true, phr_hex.card_owner) else "Cannot afford " + phr_hex.card_name + "!")
				return false
			game_manager.push_to_stack(phr_ability)
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
		last_resolution_text = "Tactful Retreat! Both creatures returned to the bottom of their decks."
		_clear_pending_retreat_state()
		_finalize_resolved_action(action)
		return true
	if not pending_retreat_prompt_uids.is_empty():
		var next_prompt := _get_pending_retreat_prompt()
		if next_prompt == null:
			_clear_pending_retreat_state()
			move_failed.emit("combat_retreat_decision: next retreat prompt was unavailable")
			return false
		var player_idx := game_manager.players.find(_get_card_controller(next_prompt))
		request_ui_interaction.emit(player_idx, "combat_retreat", {
			"action": action,
			"target": target,
			"askelladen_uid": str(next_prompt.uid),
		})
		return true
	_clear_pending_retreat_state()
	_finish_creature_combat(action, target)
	if blocked_ask != null:
		last_resolution_text = "Asaruludu's Guardian prevented %s's Tactful Retreat!" % blocked_ask.card_name
	_finalize_resolved_action(action)
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
		if card.card_owner.mana >= 1 \
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
