extends EquipmentCard
class_name Gambanteinn

const ACTIVATION_COST := 2
const MODE_SLEEP := "sleep"
const MODE_FORCE_AGGRESSIVE := "force_aggressive"

var _pending_end_turn_effects: Array[Dictionary] = []
var _listening_game_manager: GameManager = null

func _init() -> void:
	super._init()
	card_name = "Gambanteinn"
	culture = "Norse"
	card_types = ["Staff", "Wand", "Targeting"]
	mana_cost = 0
	speed = 1
	level = 1
	targets = true
	ability_text = "Pay 2 mana. If equipped to a Mage, put a creature to Sleep until end of turn. If equipped to a Shaman, it may instead switch a defensive creature to aggressive stance until end of turn. Only Mages and Shamans can equip this card."
	flavor_text = ""
	artist = "Lorinda Tomko"
	art_path = "res://images/card_art/equipment/gambanteinn_ai_edit.png"

func can_equip_to(creature: Card) -> bool:
	return super.can_equip_to(creature) and _is_valid_bearer(creature)

func get_activation_label() -> String:
	return "Use Gambanteinn"

func can_activate(game_manager: GameManager) -> bool:
	if game_manager == null:
		return false
	if abilities_suppressed() or is_activation_locked(game_manager):
		return false
	var bearer := _get_active_bearer()
	if bearer == null or bearer.is_sleeping:
		return false
	var controller := bearer.get_controller()
	if controller == null or controller != game_manager.current_player:
		return false
	if controller.mana < ACTIVATION_COST:
		return false
	return not get_valid_targets(game_manager).is_empty()

func get_valid_targets(game_manager: GameManager) -> Array[Card]:
	var valid_targets: Array[Card] = []
	if game_manager == null:
		return valid_targets
	var bearer := _get_active_bearer()
	if bearer == null:
		return valid_targets

	var can_sleep := bearer.has_type("Mage")
	var can_force_aggressive := bearer.has_type("Shaman")
	for player in game_manager.players:
		for zone in player.frontline_zones + player.reserve_zones:
			for card in zone.cards:
				if card == null or card.card_type != Card.CardType.CREATURE:
					continue
				if can_sleep:
					valid_targets.append(card)
					continue
				if can_force_aggressive and card.creature_mode != Card.CreatureMode.AGGRESSIVE:
					valid_targets.append(card)
	return valid_targets

func activate(game_manager: GameManager, target: Card = null) -> void:
	if not can_activate(game_manager):
		if game_manager != null:
			game_manager.note_player_feedback("%s cannot activate right now." % card_name)
		return
	if target == null or target not in get_valid_targets(game_manager):
		game_manager.note_player_feedback("%s fizzles: choose a valid creature." % card_name)
		return
	if game_manager.is_guardian_protected(target, self):
		game_manager.note_player_feedback(target.get_target_log_display_name(game_manager.get_feedback_viewer()) + " is protected by Guardian!")
		return
	if game_manager.is_immune_to_source(target, self):
		game_manager.note_player_feedback(target.get_target_log_display_name(game_manager.get_feedback_viewer()) + " is immune to " + card_name + ".")
		return

	var bearer := _get_active_bearer()
	if bearer == null:
		game_manager.note_player_feedback("%s has no bearer." % card_name)
		return
	var controller := bearer.get_controller()
	if controller == null or not controller.spend_mana(ACTIVATION_COST):
		game_manager.note_player_feedback("%s needs %d mana." % [card_name, ACTIVATION_COST])
		return

	var chosen_mode := _resolve_mode_for_target(bearer, target)
	if chosen_mode == "":
		game_manager.note_player_feedback("%s fizzles: no valid mode for %s." % [card_name, target.card_name])
		return

	_track_pending_effect(game_manager, target, chosen_mode)
	if chosen_mode == MODE_FORCE_AGGRESSIVE:
		target.creature_mode = Card.CreatureMode.AGGRESSIVE
		game_manager.note_player_feedback("%s forces %s into aggressive stance until end of turn." % [card_name, target.get_target_log_display_name(game_manager.get_feedback_viewer())])
	else:
		target.apply_sleep(self)
		game_manager.note_player_feedback("%s puts %s to sleep until end of turn." % [card_name, target.get_target_log_display_name(game_manager.get_feedback_viewer())])

func on_removed(_game_manager: GameManager) -> void:
	if _pending_end_turn_effects.is_empty():
		_disconnect_turn_end_listener()

func get_effect_summary_lines() -> Array[String]:
	var lines := super.get_effect_summary_lines()
	var bearer := _get_active_bearer()
	if bearer == null:
		return lines
	if bearer.has_type("Mage"):
		lines.append("Mage bearer: pay %d to sleep a creature until end of turn" % ACTIVATION_COST)
	if bearer.has_type("Shaman"):
		lines.append("Shaman bearer: may switch a creature to aggressive until end of turn")
	return lines

func _get_active_bearer() -> Card:
	if equipped_on == null:
		return null
	if current_zone == null or equipped_on.current_zone != current_zone:
		return null
	if not equipped_on.can_receive_equipment():
		return null
	return equipped_on

func _is_valid_bearer(creature: Card) -> bool:
	return creature != null and (creature.has_type("Mage") or creature.has_type("Shaman"))

func _resolve_mode_for_target(bearer: Card, target: Card) -> String:
	if bearer == null or target == null:
		return ""
	var can_sleep := bearer.has_type("Mage")
	var can_force_aggressive := bearer.has_type("Shaman") and target.creature_mode != Card.CreatureMode.AGGRESSIVE
	if can_force_aggressive and not can_sleep:
		return MODE_FORCE_AGGRESSIVE
	if can_sleep and not can_force_aggressive:
		return MODE_SLEEP
	if can_sleep and can_force_aggressive:
		return MODE_FORCE_AGGRESSIVE if target.creature_mode == Card.CreatureMode.DEFENSIVE else MODE_SLEEP
	return ""

func _track_pending_effect(game_manager: GameManager, target: Card, mode: String) -> void:
	_pending_end_turn_effects = _pending_end_turn_effects.filter(func(entry: Dictionary) -> bool:
		return entry.get("target") != target
	)
	_pending_end_turn_effects.append({
		"target": target,
		"mode": mode,
		"previous_mode": target.creature_mode,
		"return_turn_number": game_manager.turn_number if game_manager != null else -1,
		"ending_player": game_manager.current_player if game_manager != null else null,
	})
	_ensure_turn_end_listener(game_manager)

func _ensure_turn_end_listener(game_manager: GameManager) -> void:
	if game_manager == null:
		return
	if _listening_game_manager == game_manager and game_manager.global_turn_ended.is_connected(_on_global_turn_end):
		return
	_disconnect_turn_end_listener()
	_listening_game_manager = game_manager
	game_manager.global_turn_ended.connect(_on_global_turn_end)

func _disconnect_turn_end_listener() -> void:
	if _listening_game_manager != null and _listening_game_manager.global_turn_ended.is_connected(_on_global_turn_end):
		_listening_game_manager.global_turn_ended.disconnect(_on_global_turn_end)
	_listening_game_manager = null

func _on_global_turn_end(ending_turn_number: int, ending_player: Player) -> void:
	var remaining_effects: Array[Dictionary] = []
	for entry in _pending_end_turn_effects:
		if int(entry.get("return_turn_number", -1)) != ending_turn_number:
			remaining_effects.append(entry)
			continue
		if entry.get("ending_player") != ending_player:
			remaining_effects.append(entry)
			continue
		_resolve_pending_effect(entry)
	_pending_end_turn_effects = remaining_effects
	if _pending_end_turn_effects.is_empty():
		_disconnect_turn_end_listener()

func _resolve_pending_effect(entry: Dictionary) -> void:
	var target := entry.get("target") as Card
	if target == null or not is_instance_valid(target):
		return
	var mode := str(entry.get("mode", ""))
	if mode == MODE_FORCE_AGGRESSIVE:
		target.creature_mode = int(entry.get("previous_mode", Card.CreatureMode.DEFENSIVE)) as Card.CreatureMode
		return
	target.remove_status_effects_from_source_card(self, "sleep")
