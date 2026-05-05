extends CreatureCard
class_name Jiaolong

var in_human_form: bool = false

func _init() -> void:
	super._init()
	card_name = "Jiaolong"
	card_types = _get_dragon_form_types()
	level = 3
	mana_cost = 0
	speed = 1
	resilience = 16
	strength = 22
	sacrifice_cost = 0
	ability_text = "[b]Shift[/b] ([b]Activate[/b], [b]Minor Action[/b], once per turn): Switch this card between Dragon, Animal, Piscine, Aqueous and Human, Aqueous, Shapeshifter."
	flavor_text = ""
	culture = "Tian"
	artist = "Riccardo Zoppello"
	art_path = "res://images/card_art/creatures/Jiaolong.jpg"

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

func get_tonal_extraction_spirit_profile() -> Dictionary:
	return {
		"card_name": card_name + " Spirit",
		"level": level,
		"speed": speed,
		"resilience": resilience,
		"strength": strength,
		"card_types": _get_dragon_form_types() if in_human_form else _get_human_form_types(),
		"culture": culture,
		"artist": artist,
		"art_path": art_path,
	}

func activate(game_manager: GameManager, _target: Card = null) -> void:
	if not can_activate(game_manager):
		return
	shift_forms()
	spend_minor_creature_action()
	spend_shift_ability_use()
	if game_manager != null:
		game_manager.notify_creature_shapeshifted(self, self)
		var form_label := "Human, Aqueous, Shapeshifter" if in_human_form else "Dragon, Animal, Piscine, Aqueous"
		game_manager.note_player_feedback("%s shifts into %s." % [card_name, form_label])

func shift_forms() -> void:
	in_human_form = not in_human_form
	card_types = _get_human_form_types() if in_human_form else _get_dragon_form_types()

func get_serialized_state() -> Dictionary:
	return {
		"in_human_form": in_human_form,
	}

func apply_serialized_state(state: Dictionary) -> void:
	if state.is_empty():
		in_human_form = card_types.has("Human")
	else:
		in_human_form = bool(state.get("in_human_form", false))
	card_types = _get_human_form_types() if in_human_form else _get_dragon_form_types()

func get_hover_detail_lines(_viewer: Player = null) -> Array[String]:
	return [
		"[b]Shift Forms[/b]",
		_current_form_hover_text(),
		_inactive_form_hover_text(),
	]

func _current_form_hover_text() -> String:
	return "Current: " + ("Human, Aqueous, Shapeshifter" if in_human_form else "Dragon, Animal, Piscine, Aqueous")

func _inactive_form_hover_text() -> String:
	var inactive_form := "Dragon, Animal, Piscine, Aqueous" if in_human_form else "Human, Aqueous, Shapeshifter"
	return "[color=#8a8a8a]Can shift to: %s[/color]" % inactive_form

func _get_dragon_form_types() -> Array[String]:
	var types: Array[String] = []
	types.append("Dragon")
	types.append("Animal")
	types.append("Piscine")
	types.append("Aqueous")
	types.append("Shapeshifter")
	types.append("Tian Creature")
	return types

func _get_human_form_types() -> Array[String]:
	var types: Array[String] = []
	types.append("Human")
	types.append("Aqueous")
	types.append("Shapeshifter")
	types.append("Tian Creature")
	return types
