extends CreatureCard
class_name Nagual

const FELINE_STR_BONUS := 4
const FELINE_SPD_BONUS := 1
const HUMAN_RES_BONUS := 5
const ART_PATH := "res://images/card_art/creatures/NagualEdit.png"

var in_feline_form: bool = false

func _init() -> void:
	super._init()
	card_name = "Nagual"
	card_types = _get_human_form_types()
	level = 2
	mana_cost = 0
	sacrifice_cost = 0
	speed = 1
	resilience = 17
	strength = 17
	ability_text = "[b]Shift[/b] ([b]Activate[/b], [b]Minor Action[/b], once per turn): Switch between Human, Mage, Shaman, Shapeshifter and Animal, Feline, Mage, Shaman, Shapeshifter.\nTonal Strengths ([b]Passive[/b]): Feline form gets +4 STR and +1 SPD. Human form gets +5 RES."
	flavor_text = ""
	culture = "Nahuatl"
	artist = "Ricardo Zoppello"
	art_path = ART_PATH

func get_activation_label() -> String:
	return "Shift"

func can_activate(game_manager: GameManager) -> bool:
	if game_manager == null:
		return false
	if get_controller() != game_manager.current_player:
		return false
	if current_zone == null or not current_zone.is_board_zone():
		return false
	if abilities_suppressed():
		return false
	if is_shapeshift_locked():
		return false
	if is_sleeping:
		return false
	return can_take_minor_creature_action() and can_use_shift_ability_this_turn()

func get_activation_failure_reason(game_manager: GameManager) -> String:
	if game_manager == null:
		return card_name + " cannot shift right now."
	var controller := get_controller()
	if controller == null:
		return card_name + " has no controller."
	if not game_manager.action_stack.is_empty() or not game_manager.resolving_stack_actions.is_empty():
		return "Resolve the pending stack action before shifting " + card_name + "."
	if controller != game_manager.current_player:
		return "It is not " + card_name + "'s turn to act."
	if current_zone == null or not current_zone.is_board_zone():
		return card_name + " must be on the field to shift."
	if abilities_suppressed():
		return card_name + " is suppressed."
	if is_shapeshift_locked():
		return card_name + " cannot shift right now."
	if is_sleeping:
		return card_name + " is asleep."
	if not can_take_minor_creature_action():
		return card_name + " has no minor actions left."
	if not can_use_shift_ability_this_turn():
		return card_name + " has already shifted this turn."
	return ""

func get_tonal_extraction_spirit_profile() -> Dictionary:
	return {
		"card_name": card_name + " Spirit",
		"level": level,
		"speed": 1,
		"resilience": HUMAN_RES_BONUS + resilience if in_feline_form else resilience,
		"strength": strength if in_feline_form else strength + FELINE_STR_BONUS,
		"card_types": _get_human_form_types() if in_feline_form else _get_feline_form_types(),
		"culture": culture,
		"artist": artist,
		"art_path": art_path,
	}

func activate(game_manager: GameManager, _target: Card = null) -> void:
	if not can_activate(game_manager):
		if game_manager != null:
			game_manager.note_player_feedback(get_activation_failure_reason(game_manager))
		return
	shift_forms()
	spend_minor_creature_action()
	spend_shift_ability_use()
	if game_manager != null:
		game_manager.notify_creature_shapeshifted(self, self)
		game_manager.note_player_feedback(
			"%s shifts into %s form." % [card_name, "Feline" if in_feline_form else "Human"]
		)

func shift_forms() -> void:
	in_feline_form = not in_feline_form
	card_types = _get_feline_form_types() if in_feline_form else _get_human_form_types()

func get_serialized_state() -> Dictionary:
	return {
		"in_feline_form": in_feline_form,
	}

func apply_serialized_state(state: Dictionary) -> void:
	if state.is_empty():
		in_feline_form = card_types.has("Feline")
	else:
		in_feline_form = bool(state.get("in_feline_form", false))
	card_types = _get_feline_form_types() if in_feline_form else _get_human_form_types()

func get_effective_speed() -> int:
	var total := super.get_effective_speed()
	if in_feline_form:
		total += FELINE_SPD_BONUS
	return clampi(total, 1, 7)

func get_effective_strength() -> int:
	var total := super.get_effective_strength()
	if in_feline_form:
		total += FELINE_STR_BONUS
	return max(0, total)

func get_effective_resilience() -> int:
	var total := super.get_effective_resilience()
	if not in_feline_form:
		total += HUMAN_RES_BONUS
	return max(0, total)

func get_hover_detail_lines(_viewer: Player = null) -> Array[String]:
	var active_form := _get_feline_form_types() if in_feline_form else _get_human_form_types()
	var inactive_form := _get_human_form_types() if in_feline_form else _get_feline_form_types()
	return [
		BaseCard.format_shapeshifter_form_summary(active_form, inactive_form),
		"[b]Feline[/b]: +4 STR and +1 SPD. [b]Human[/b]: +5 RES.",
	]

func _get_human_form_types() -> Array[String]:
	return [
		"Human",
		"Mage",
		"Shaman",
		"Shapeshifter",
		"Nahuatl Creature",
	]

func _get_feline_form_types() -> Array[String]:
	return [
		"Animal",
		"Feline",
		"Mage",
		"Shaman",
		"Shapeshifter",
		"Nahuatl Creature",
	]
