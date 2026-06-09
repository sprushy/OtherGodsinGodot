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

func can_respond_to_priority_action(action: CardAction, game_manager: GameManager) -> bool:
	if not _can_use_base_creature_action(game_manager):
		return false
	if game_manager == null or action == null:
		return false
	if get_controller() != game_manager.priority_player:
		return false
	return _action_targets_friendly_card(action, game_manager)

func activate(game_manager: GameManager, activation_data = null) -> void:
	if game_manager == null:
		return

	var requested_ability := _resolve_requested_ability(activation_data)
	match requested_ability:
		"medicine":
			_activate_medicine(game_manager)
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
	return [
		"[b]Current Form[/b]: %s" % ("Serpent" if in_serpent_form else "Human"),
		"[b]Human[/b]: Human, Mage, Shapeshifter.",
		"[b]Serpent[/b]: Animal, Anguine, Shapeshifter.",
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

func _activate_medicine(game_manager: GameManager) -> void:
	var can_use := can_activate_medicine(game_manager)
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

	game_manager.grant_turn_opponent_targeting_immunity(controller, self, game_manager.turn_number)
	game_manager.note_player_feedback(
		"%s uses Medicine. Opponent cards targeting %s's cards are negated until end of turn." % [
			card_name,
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

func _action_targets_friendly_card(action: CardAction, game_manager: GameManager) -> bool:
	if action == null or action.card == null:
		return false
	var controller := get_controller()
	if controller == null:
		return false
	var source_controller := action.card.get_controller()
	if source_controller == null:
		source_controller = action.card.card_owner
	if source_controller == null or source_controller == controller:
		return false
	if _target_value_contains_friendly_card(action.target, controller, game_manager):
		return true
	return _target_value_contains_friendly_card(action.event_data, controller, game_manager)

func _is_friendly_card_target(target: Card, controller: Player) -> bool:
	if target == null or controller == null:
		return false
	var target_controller := target.get_controller()
	if target_controller == null:
		target_controller = target.card_owner
	return target_controller == controller

func _target_value_contains_friendly_card(value, controller: Player, game_manager: GameManager) -> bool:
	if value is Card:
		return _is_friendly_card_target(value as Card, controller)
	if value is String and game_manager != null:
		var target_card := game_manager.get_card_by_uid(str(value))
		return _is_friendly_card_target(target_card, controller)
	if value is Array:
		for entry in value:
			if _target_value_contains_friendly_card(entry, controller, game_manager):
				return true
	elif value is Dictionary:
		for entry in (value as Dictionary).values():
			if _target_value_contains_friendly_card(entry, controller, game_manager):
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
