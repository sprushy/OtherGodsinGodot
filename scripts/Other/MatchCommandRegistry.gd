extends RefCounted
class_name MatchCommandRegistry

# Central command policy table for network authority, prompt matching, and
# action-window guards. Command execution still lives in MatchManager.
const KNOWN_COMMAND_TYPES := [
	"select_attacker",
	"request_attack",
	"cancel_targeting",
	"confirm_click_selection",
	"play_card",
	"prepare_card",
	"play_creature",
	"creature_move",
	"equip_action",
	"change_mode",
	"end_turn",
	"upkeep_choice",
	"tiamat_upkeep_choice",
	"forfeit",
	"forfeit_match",
	"submit_reinforcements",
	"cast_spell",
	"blot_sacrifice_choice",
	"activate_prepared_hex",
	"god_ability",
	"activate_power",
	"tonal_extraction_choice",
	"unlock_power",
	"activate_divine_caprice",
	"cast_charm",
	"play_hex_response",
	"play_charm_response",
	"play_priority_ability",
	"priority_pass",
	"set_priority_preferences",
	"intercept_decision",
	"combat_retreat_decision",
	"resurrection_choice",
	"skoll_upkeep_summon",
	"hati_moon_hunt",
	"wheel_of_fire_turn_start_choice",
	"activate_card_ability",
	"mopsus_reveal_hand_card",
	"en_hedu_anna_exaltation",
	"aphrodite_enslave_choice",
	"blessed_knights_choice",
	"wolf_adolescent_maturation_choice",
	"tezcatlipoca_active_titlacauan_choice",
	"nusku_active_core_flame_choice",
	"mummu_entropy_choice",
	"first_sage_adapa_choice",
	"third_sage_enmedugga_choice",
	"fourth_sage_enmegalamma_choice",
	"sixth_sage_an_enlilda_choice",
	"seventh_sage_utuabzu_choice",
	"lailoken_reveal_choice",
	"masmassu_priest_reveal_choice",
	"rally_the_troops_choice",
	"terror_impact_choice",
	"huginn_perish_prime_choice",
	"muninn_perish_prime_choice",
	"fenrir_devour_choice",
	"harii_jarl_impact_choice",
	"durinn_secondborn_choice",
	"kur_jara_tree_of_life_choice",
	"hunting_tactics_choice",
	"foolish_optimism_choice",
	"gugalanna_celestial_charge_choice",
	"freyja_active_open_sessrumnir_choice",
	"tiamat_active_summon_choice",
	"giant_master_architect_choice",
	"pai_long_autumn_king_choice",
	"nergal_lion_choice",
	"gala_tura_destroyed_choice",
	"gawain_healing_hands_choice",
	"tatzelwurm_dragon_heart_choice",
	"byggvir_reveal_choice",
	"apollyons_demiurge_choice",
	"habrok_breakout_choice",
	"humbaba_augury_choice",
	"nusku_well_of_fire_choice",
	"ragnarok_discard_choice",
	"return_to_hand_choice",
	"doorway_choice",
	"wolf_master_summon",
	"apply_advanced_building_techniques",
]

static func is_known_command_type(command_type: String) -> bool:
	return command_type in KNOWN_COMMAND_TYPES

static func get_known_command_types() -> Array[String]:
	var command_types: Array[String] = []
	for command_type in KNOWN_COMMAND_TYPES:
		command_types.append(str(command_type))
	return command_types

static func get_required_player(command: Dictionary, game_manager: GameManager, match_context = null) -> Player:
	if game_manager == null:
		return null
	match str(command.get("type", "")):
		"select_attacker":
			return _controller_from_uid(command, game_manager, "card_uid")
		"request_attack":
			return _controller_from_uid(command, game_manager, "attacker_uid")
		"cancel_targeting", "confirm_click_selection":
			return _get_current_targeting_player(match_context)
		"play_card", "prepare_card", "play_creature", "creature_move", "change_mode", "equip_action":
			return _controller_from_uid(command, game_manager, "card_uid")
		"cast_spell":
			return _controller_from_uid(command, game_manager, "spell_uid")
		"blot_sacrifice_choice":
			return _controller_from_uid(command, game_manager, "source_uid")
		"activate_prepared_hex":
			return _controller_from_uid(command, game_manager, "hex_uid")
		"god_ability":
			return _controller_from_uid(command, game_manager, "god_uid")
		"play_priority_ability":
			return _controller_from_uid(command, game_manager, "source_uid")
		"activate_power", "unlock_power", "activate_divine_caprice", "apply_advanced_building_techniques":
			return _controller_from_uid(command, game_manager, "power_uid")
		"tonal_extraction_choice":
			return _controller_from_uid(command, game_manager, "source_uid")
		"cast_charm", "play_charm_response":
			return _controller_from_uid(command, game_manager, "charm_uid")
		"play_hex_response":
			return _controller_from_uid(command, game_manager, "hex_uid")
		"hati_moon_hunt":
			return _controller_from_uid(command, game_manager, "hati_uid")
		"skoll_upkeep_summon":
			return _controller_from_uid(command, game_manager, "skoll_uid")
		"activate_card_ability", "mopsus_reveal_hand_card", "en_hedu_anna_exaltation", "aphrodite_enslave_choice", "blessed_knights_choice", "wolf_adolescent_maturation_choice", "wheel_of_fire_turn_start_choice", "tezcatlipoca_active_titlacauan_choice", "nusku_active_core_flame_choice", "mummu_entropy_choice", "first_sage_adapa_choice", "third_sage_enmedugga_choice", "fourth_sage_enmegalamma_choice", "sixth_sage_an_enlilda_choice", "seventh_sage_utuabzu_choice", "lailoken_reveal_choice", "masmassu_priest_reveal_choice", "rally_the_troops_choice", "terror_impact_choice", "huginn_perish_prime_choice", "muninn_perish_prime_choice", "fenrir_devour_choice", "harii_jarl_impact_choice", "durinn_secondborn_choice", "kur_jara_tree_of_life_choice", "hunting_tactics_choice", "foolish_optimism_choice", "gugalanna_celestial_charge_choice", "freyja_active_open_sessrumnir_choice", "tiamat_active_summon_choice", "giant_master_architect_choice", "pai_long_autumn_king_choice", "nergal_lion_choice", "gala_tura_destroyed_choice", "gawain_healing_hands_choice", "tatzelwurm_dragon_heart_choice", "byggvir_reveal_choice", "apollyons_demiurge_choice", "habrok_breakout_choice":
			return _controller_from_uid(command, game_manager, "source_uid")
		"humbaba_augury_choice":
			var humbaba := _card_from_uid(command, game_manager, "source_uid") as HumbabaTheTerrible
			return game_manager.get_opponent(humbaba.get_controller()) if humbaba != null else null
		"nusku_well_of_fire_choice":
			var nusku := _card_from_uid(command, game_manager, "source_uid") as NuskuFirebearer
			return game_manager.get_opponent(nusku.get_controller()) if nusku != null else null
		"ragnarok_discard_choice":
			var power := _card_from_uid(command, game_manager, "source_uid") as Ragnarok
			return power.get_pending_discard_player(game_manager) if power != null else null
		"return_to_hand_choice":
			return _controller_from_uid(command, game_manager, "card_uid")
		"doorway_choice":
			var pending_structure = game_manager.call("get_pending_doorway_structure") if game_manager.has_method("get_pending_doorway_structure") else null
			if pending_structure != null:
				return _card_controller(pending_structure)
			return _controller_from_uid(command, game_manager, "structure_uid")
		"wolf_master_summon":
			return _controller_from_uid(command, game_manager, "fenrir_uid")
		"intercept_decision":
			var interceptor_uid := str(command.get("interceptor_uid", ""))
			if not interceptor_uid.is_empty():
				return _card_controller(game_manager.get_card_by_uid(interceptor_uid))
			var pending_attack_target = _context_value(match_context, "pending_attack_target", null)
			if pending_attack_target is Card:
				return _card_controller(pending_attack_target as Card)
			if pending_attack_target is Player:
				return pending_attack_target as Player
			return game_manager.other_player
		"combat_retreat_decision":
			var askelladen_uid := str(command.get("askelladen_uid", "")).strip_edges()
			if not askelladen_uid.is_empty():
				return _card_controller(game_manager.get_card_by_uid(askelladen_uid))
			return _get_pending_retreat_prompt_player(match_context, game_manager)
		"resurrection_choice":
			var resurrect_card := _card_from_uid(command, game_manager, "card_uid")
			return resurrect_card.card_owner if resurrect_card != null else null
		"priority_pass":
			return game_manager.priority_player if game_manager.priority_player != null else game_manager.current_player
		"set_priority_preferences":
			var priority_player_index := int(command.get("player_index", -1))
			if priority_player_index >= 0 and priority_player_index < game_manager.players.size():
				return game_manager.players[priority_player_index]
			return null
		"forfeit", "forfeit_match":
			var forfeiting_index := int(command.get("player_index", -1))
			if forfeiting_index >= 0 and forfeiting_index < game_manager.players.size():
				return game_manager.players[forfeiting_index]
			return null
		"submit_reinforcements":
			var reinforcement_player_index := int(command.get("player_index", -1))
			if reinforcement_player_index >= 0 and reinforcement_player_index < game_manager.players.size():
				return game_manager.players[reinforcement_player_index]
			return null
		"upkeep_choice", "tiamat_upkeep_choice", "end_turn":
			return game_manager.current_player
	return null

static func get_ui_interaction_type(command_type: String) -> String:
	match command_type:
		"intercept_decision":
			return "intercept"
		"combat_retreat_decision":
			return "combat_retreat"
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
		"seventh_sage_utuabzu_choice":
			return "seventh_sage_utuabzu_impact"
		"lailoken_reveal_choice":
			return "lailoken_reveal"
		"masmassu_priest_reveal_choice":
			return "masmassu_priest_reveal"
		"rally_the_troops_choice":
			return "rally_the_troops"
		"terror_impact_choice":
			return "terror_impact"
		"tonal_extraction_choice":
			return "tonal_extraction"
		"blot_sacrifice_choice":
			return "blot_sacrifice"
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
		"tiamat_active_summon_choice":
			return "tiamat_active_summon"
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

static func requires_resolved_upkeep(command: Dictionary) -> bool:
	var command_type := str(command.get("type", ""))
	if command_type == "activate_power" and str(command.get("mode", "")) == "return_priest":
		return false
	match command_type:
		"upkeep_choice", "tiamat_upkeep_choice", "skoll_upkeep_summon", "priority_pass", "set_priority_preferences", "intercept_decision", "combat_retreat_decision", "play_hex_response", "play_charm_response", "play_priority_ability", "forfeit", "forfeit_match", "humbaba_augury_choice", "return_to_hand_choice", "doorway_choice":
			return false
	return true

static func requires_clear_stack_window(command_type: String) -> bool:
	match command_type:
		"select_attacker", "request_attack", "play_card", "prepare_card", "play_creature", "creature_move", "equip_action", "change_mode", "end_turn":
			return true
		"cast_spell", "activate_prepared_hex", "god_ability", "activate_power", "unlock_power", "activate_divine_caprice", "cast_charm", "activate_card_ability", "mopsus_reveal_hand_card", "en_hedu_anna_exaltation", "apply_advanced_building_techniques":
			return true
	return false

static func _controller_from_uid(command: Dictionary, game_manager: GameManager, key: String) -> Player:
	return _card_controller(_card_from_uid(command, game_manager, key))

static func _card_from_uid(command: Dictionary, game_manager: GameManager, key: String) -> Card:
	if game_manager == null:
		return null
	return game_manager.get_card_by_uid(str(command.get(key, "")))

static func _card_controller(card) -> Player:
	var resolved_card := card as Card
	if resolved_card == null:
		return null
	return resolved_card.get_controller() if resolved_card.has_method("get_controller") else resolved_card.card_owner

static func _get_current_targeting_player(match_context) -> Player:
	if match_context == null:
		return null
	var click_source := _context_value(match_context, "pending_click_selection_source", null) as Card
	if click_source != null:
		return _card_controller(click_source)
	if bool(_context_value(match_context, "awaiting_spell_target", false)):
		var spell_source := _context_value(match_context, "spell_waiting_for_target", null) as Card
		if spell_source != null:
			return _card_controller(spell_source)
	if bool(_context_value(match_context, "awaiting_god_ability_target", false)):
		var god_source := _context_value(match_context, "god_ability_source", null) as Card
		if god_source != null:
			return _card_controller(god_source)
	if bool(_context_value(match_context, "awaiting_stupefy_target", false)):
		var stupefy_source := _context_value(match_context, "stupefy_source", null) as Card
		if stupefy_source != null:
			return _card_controller(stupefy_source)
	if bool(_context_value(match_context, "awaiting_pyre_target", false)):
		var pyre_source := _context_value(match_context, "pyre_source", null) as Card
		if pyre_source != null:
			return _card_controller(pyre_source)
	if bool(_context_value(match_context, "awaiting_anointing_target", false)):
		var anointing_source := _context_value(match_context, "anointing_source", null) as Card
		if anointing_source != null:
			return _card_controller(anointing_source)
	return null

static func _get_pending_retreat_prompt_player(match_context, game_manager: GameManager) -> Player:
	if match_context == null or game_manager == null:
		return null
	var prompt_uids = _context_value(match_context, "pending_retreat_prompt_uids", [])
	if not (prompt_uids is Array) or (prompt_uids as Array).is_empty():
		return null
	var prompt := game_manager.get_card_by_uid(str((prompt_uids as Array)[0]))
	return _card_controller(prompt)

static func _context_value(match_context, property_name: String, fallback = null):
	if match_context == null:
		return fallback
	var value = match_context.get(property_name)
	return fallback if value == null else value
