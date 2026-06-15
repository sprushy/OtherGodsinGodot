extends CreatureCard
class_name TheWhiteSerpent

const ART_PATH := "res://images/card_art/creatures/TheWhiteSerpentEdit.png"
const ALT_ART_PATH := "res://images/card_art/creatures/the_white_serpent_alt.jpg"
const MEDICINE_SPEED := 2

var in_serpent_form: bool = false

func _init() -> void:
	super._init()
	card_name = "The White Serpent"
	card_types = _get_human_form_types()
	targets = true
	level = 4
	mana_cost = 2
	sacrifice_cost = 0
	speed = 2
	resilience = 26
	strength = 26
	ability_text = "[b]Shift[/b] ([b]Activate[/b], [b]Minor Action[/b], once per turn): Switch between Human, Mage, Shapeshifter and Animal, Anguine, Shapeshifter.\nMedicine ([b]Activate[/b], [b]Spd[/b] 2): Negate enemy effects targeting your cards until end of turn."
	flavor_text = ""
	culture = "Tian"
	artist = "Ricardo Zoppello"
	art_path = ART_PATH
	art_variants = [ART_PATH, ALT_ART_PATH]

func get_activation_label() -> String:
	return "Shift"

func can_activate(game_manager: GameManager) -> bool:
	return can_activate_shift(game_manager)

func can_activate_shift(game_manager: GameManager) -> bool:
	return _can_use_base_creature_action(game_manager) \
		and not is_shapeshift_locked() \
		and can_take_minor_creature_action() \
		and can_use_shift_ability_this_turn() \
		and get_controller() == game_manager.current_player

func can_activate_medicine(game_manager: GameManager) -> bool:
	return _can_use_base_creature_action(game_manager) \
		and get_controller() == game_manager.current_player

func get_activation_failure_reason(game_manager: GameManager) -> String:
	if game_manager == null:
		return card_name + " cannot activate right now."
	if not _can_use_base_creature_action(game_manager):
		return card_name + " cannot use its abilities right now."
	if get_controller() != game_manager.current_player:
		return "It is not " + card_name + "'s turn to act."
	return card_name + " cannot activate right now."

func get_priority_response_speed() -> int:
	return MEDICINE_SPEED

func requires_priority_target_selection() -> bool:
	return true

func can_respond_to_priority_action(action: CardAction, game_manager: GameManager) -> bool:
	if not _can_use_base_creature_action(game_manager):
		return false
	if game_manager == null or action == null:
		return false
	if get_controller() != game_manager.priority_player:
		return false
	return not get_priority_targets(game_manager, action).is_empty()

func get_priority_targets(game_manager: GameManager, action: CardAction = null) -> Array[Card]:
	var valid_targets: Array[Card] = []
	if game_manager == null or action == null:
		return valid_targets
	if not _is_enemy_action(action):
		return valid_targets

	var controller := get_controller()
	if controller == null:
		return valid_targets
	_append_friendly_targets_from_value(action.target, controller, game_manager, valid_targets)
	_append_friendly_targets_from_target_fields(action.event_data, controller, game_manager, valid_targets)
	return valid_targets

func activate(game_manager: GameManager, activation_data = null) -> void:
	if game_manager == null:
		return

	var requested_ability := _resolve_requested_ability(activation_data)
	var medicine_target := activation_data as Card if activation_data is Card else null
	if medicine_target != null:
		_activate_medicine(game_manager, medicine_target)
		return
	match requested_ability:
		"medicine":
			_activate_medicine(game_manager, _resolve_target_from_activation_data(activation_data, game_manager))
			return
		"shift":
			_activate_shift(game_manager)
			return

	if not game_manager.action_stack.is_empty():
		var top_action := game_manager.action_stack.back() as CardAction
		if can_respond_to_priority_action(top_action, game_manager):
			_activate_medicine(game_manager)
			return

	if can_activate_shift(game_manager):
		_activate_shift(game_manager)
		return
	if can_activate_medicine(game_manager):
		_activate_medicine(game_manager)
		return

	game_manager.note_player_feedback(get_activation_failure_reason(game_manager))

func get_hover_detail_lines(_viewer: Player = null) -> Array[String]:
	var active_form := _get_serpent_form_types() if in_serpent_form else _get_human_form_types()
	var inactive_form := _get_human_form_types() if in_serpent_form else _get_serpent_form_types()
	return [
		BaseCard.format_shapeshifter_form_summary(active_form, inactive_form),
	]

func get_tonal_extraction_spirit_profile() -> Dictionary:
	return {
		"card_name": card_name + " Spirit",
		"level": level,
		"speed": speed,
		"resilience": resilience,
		"strength": strength,
		"card_types": _get_human_form_types() if in_serpent_form else _get_serpent_form_types(),
		"culture": culture,
		"artist": artist,
		"art_path": art_path,
	}

func shift_forms() -> void:
	in_serpent_form = not in_serpent_form
	card_types = _get_serpent_form_types() if in_serpent_form else _get_human_form_types()

func _activate_shift(game_manager: GameManager) -> void:
	if not can_activate_shift(game_manager):
		game_manager.note_player_feedback(get_activation_failure_reason(game_manager))
		return

	shift_forms()
	spend_minor_creature_action()
	spend_shift_ability_use()
	game_manager.notify_creature_shapeshifted(self, self)
	game_manager.note_player_feedback(
		"%s shifts into %s form." % [card_name, "Serpent" if in_serpent_form else "Human"]
	)

func _activate_medicine(game_manager: GameManager, protected_target: Card = null) -> void:
	var can_use := can_activate_medicine(game_manager)
	if not can_use:
		can_use = _is_resolving_medicine_response(game_manager, protected_target)
	if not can_use and not game_manager.action_stack.is_empty():
		var top_action := game_manager.action_stack.back() as CardAction
		can_use = can_respond_to_priority_action(top_action, game_manager)
	if not can_use:
		game_manager.note_player_feedback(get_activation_failure_reason(game_manager))
		return

	var controller := get_controller()
	if controller == null:
		game_manager.note_player_feedback(card_name + " has no controller for Medicine.")
		return
	if protected_target != null and not _is_friendly_card_target(protected_target, controller):
		game_manager.note_player_feedback(card_name + " cannot protect that target.")
		return

	game_manager.grant_turn_opponent_targeting_immunity(controller, self, game_manager.turn_number)
	var target_text := ""
	if protected_target != null:
		target_text = " to protect " + protected_target.get_target_log_display_name(game_manager.get_feedback_viewer())
	game_manager.note_player_feedback(
		"%s uses Medicine%s. Opponent cards targeting %s's cards are negated until end of turn." % [
			card_name,
			target_text,
			controller.player_name
		]
	)

func _can_use_base_creature_action(game_manager: GameManager) -> bool:
	return game_manager != null \
		and current_zone != null \
		and current_zone.is_board_zone() \
		and not is_face_down \
		and not is_stealth \
		and not is_prepared \
		and not is_sleeping \
		and not abilities_suppressed() \
		and not is_activation_locked(game_manager)

func get_serialized_state() -> Dictionary:
	return {
		"in_serpent_form": in_serpent_form,
	}

func apply_serialized_state(state: Dictionary) -> void:
	if state.is_empty():
		in_serpent_form = card_types.has("Anguine")
	else:
		in_serpent_form = bool(state.get("in_serpent_form", false))
	card_types = _get_serpent_form_types() if in_serpent_form else _get_human_form_types()

func _resolve_requested_ability(activation_data) -> String:
	if activation_data is Dictionary:
		return str((activation_data as Dictionary).get("ability", "")).to_lower()
	return ""

func _resolve_target_from_activation_data(activation_data, game_manager: GameManager) -> Card:
	if not (activation_data is Dictionary) or game_manager == null:
		return null
	var activation_dict := activation_data as Dictionary
	var direct_target = activation_dict.get("target", null)
	if direct_target is Card:
		return direct_target as Card
	var target_uid := str(activation_dict.get("target_uid", "")).strip_edges()
	if target_uid == "":
		return null
	return game_manager.get_card_by_uid(target_uid)

func _is_enemy_action(action: CardAction) -> bool:
	if action == null or action.card == null:
		return false
	var controller := get_controller()
	if controller == null:
		return false
	var source_controller := action.card.get_controller()
	if source_controller == null:
		source_controller = action.card.card_owner
	return source_controller != null and source_controller != controller

func _is_friendly_card_target(target: Card, controller: Player) -> bool:
	if target == null or controller == null:
		return false
	var target_controller := target.get_controller()
	if target_controller == null:
		target_controller = target.card_owner
	return target_controller == controller

func _append_unique_friendly_target(target: Card, controller: Player, targets_list: Array[Card]) -> void:
	if _is_friendly_card_target(target, controller) and target not in targets_list:
		targets_list.append(target)

func _append_friendly_targets_from_value(value, controller: Player, game_manager: GameManager, targets_list: Array[Card]) -> void:
	if value is Card:
		_append_unique_friendly_target(value as Card, controller, targets_list)
	elif value is String and game_manager != null:
		_append_unique_friendly_target(game_manager.get_card_by_uid(str(value)), controller, targets_list)
	elif value is Array:
		for entry in value:
			_append_friendly_targets_from_value(entry, controller, game_manager, targets_list)

func _append_friendly_targets_from_target_fields(value, controller: Player, game_manager: GameManager, targets_list: Array[Card]) -> void:
	if value is Dictionary:
		for key in (value as Dictionary).keys():
			var key_text := str(key)
			var entry = (value as Dictionary).get(key)
			if key_text.find("target") != -1:
				_append_friendly_targets_from_value(entry, controller, game_manager, targets_list)
			elif entry is Dictionary:
				_append_friendly_targets_from_target_fields(entry, controller, game_manager, targets_list)
	elif value is Array:
		for entry in value:
			_append_friendly_targets_from_target_fields(entry, controller, game_manager, targets_list)

func _is_resolving_medicine_response(game_manager: GameManager, protected_target: Card = null) -> bool:
	if game_manager == null:
		return false
	var controller := get_controller()
	if protected_target != null and not _is_friendly_card_target(protected_target, controller):
		return false
	for action in game_manager.resolving_stack_actions:
		if action is CardAction \
				and (action as CardAction).card == self \
				and (action as CardAction).type == CardAction.Type.ABILITY \
				and (action as CardAction).response_to != null:
			return true
	return false

func _get_human_form_types() -> Array[String]:
	return [
		"Human",
		"Mage",
		"Shapeshifter",
		"Tian Creature",
	]

func _get_serpent_form_types() -> Array[String]:
	return [
		"Animal",
		"Anguine",
		"Shapeshifter",
		"Tian Creature",
	]
