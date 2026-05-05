extends CreatureCard
class_name ErlqueensNightingale

var in_bird_form: bool = false

func _init() -> void:
	super._init()
	card_name = "Erlqueen's Nightingale"
	card_types = _get_human_form_types()
	level = 1
	mana_cost = 0
	speed = 3
	resilience = 10
	strength = 13
	sacrifice_cost = 0
	ability_text = "[b]Shift[/b] ([b]Activate[/b], [b]Minor Action[/b], once per turn): Switch this card between Human, Servant, Mage, Witch and Animal, Avian, Aerial. When this card shifts, you may return it to your hand."
	flavor_text = ""
	culture = "Norse"
	artist = "Jessica Kings Via Tcg-Maker"
	art_path = "res://images/card_art/creatures/ErlQueenNightengaleAIEdit.png"

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
		"card_types": _get_human_form_types() if in_bird_form else _get_bird_form_types(),
		"culture": culture,
		"artist": artist,
		"art_path": art_path,
	}

func activate(game_manager: GameManager, target = null) -> void:
	var return_to_hand_after_shift := false
	if target is Dictionary:
		return_to_hand_after_shift = (target as Dictionary).get("return_to_hand", false) == true
	if not can_activate(game_manager):
		return
	shift_forms()
	spend_minor_creature_action()
	spend_shift_ability_use()
	if return_to_hand_after_shift and card_owner != null:
		card_owner.move_card(self, card_owner.hand_zone)
	if game_manager != null:
		game_manager.notify_creature_shapeshifted(self, self)
		var form_label := "Animal, Avian, Aerial" if in_bird_form else "Human, Servant, Mage, Witch"
		var feedback := "%s shifts into %s." % [card_name, form_label]
		if return_to_hand_after_shift:
			feedback += " It returns to hand."
		game_manager.note_player_feedback(feedback)

func shift_forms() -> void:
	in_bird_form = not in_bird_form
	card_types = _get_bird_form_types() if in_bird_form else _get_human_form_types()

func get_serialized_state() -> Dictionary:
	return {
		"in_bird_form": in_bird_form,
	}

func apply_serialized_state(state: Dictionary) -> void:
	if state.is_empty():
		in_bird_form = card_types.has("Avian")
	else:
		in_bird_form = bool(state.get("in_bird_form", false))
	card_types = _get_bird_form_types() if in_bird_form else _get_human_form_types()

func get_hover_detail_lines(_viewer: Player = null) -> Array[String]:
	return [
		"[b]Shift Forms[/b]",
		_current_form_hover_text(),
		_inactive_form_hover_text(),
	]

func _current_form_hover_text() -> String:
	return "Current: " + ("Animal, Avian, Aerial" if in_bird_form else "Human, Servant, Mage, Witch")

func _inactive_form_hover_text() -> String:
	var inactive_form := "Human, Servant, Mage, Witch" if in_bird_form else "Animal, Avian, Aerial"
	return "[color=#8a8a8a]Can shift to: %s[/color]" % inactive_form

func can_return_to_hand_after_shift() -> bool:
	return card_owner != null and current_zone != null and current_zone.is_board_zone()

func _get_human_form_types() -> Array[String]:
	var types: Array[String] = []
	types.append("Human")
	types.append("Servant")
	types.append("Mage")
	types.append("Witch")
	types.append("Shapeshifter")
	types.append("Norse Creature")
	return types

func _get_bird_form_types() -> Array[String]:
	var types: Array[String] = []
	types.append("Animal")
	types.append("Avian")
	types.append("Aerial")
	types.append("Shapeshifter")
	types.append("Norse Creature")
	return types
