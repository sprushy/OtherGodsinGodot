extends CreatureCard
class_name Thiazi

const ART_PATH := "res://images/card_art/creatures/ThiaziEdit.png"
const ANIMAL_FORM_SPEED_BONUS := 2
const ANIMAL_FORM_RESILIENCE_DELTA := -11
const ANIMAL_FORM_STRENGTH_BONUS := 3

var in_animal_form: bool = false

func _init() -> void:
	super._init()
	card_name = "Thiazi"
	card_types = _get_giant_form_types()
	level = 4
	mana_cost = 4
	sacrifice_cost = 0
	speed = 1
	resilience = 26
	strength = 24
	ability_text = "[b]Shift[/b] ([b]Activate[/b]): Switch this card between Giant, Mage, Shapeshifter and Animal, Mage, Avian, Aerial.\n[b]Animal Form[/b] ([b]Passive[/b]): While in Animal form, this card's stats become SPD 3 / RES 15 / STR 27."
	flavor_text = ""
	culture = "Norse"
	artist = "Lorinda Tomko"
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
	return can_take_major_creature_action()

func get_tonal_extraction_spirit_profile() -> Dictionary:
	return {
		"card_name": card_name + " Spirit",
		"level": level,
		"speed": speed if in_animal_form else speed + ANIMAL_FORM_SPEED_BONUS,
		"resilience": resilience if in_animal_form else resilience + ANIMAL_FORM_RESILIENCE_DELTA,
		"strength": strength if in_animal_form else strength + ANIMAL_FORM_STRENGTH_BONUS,
		"card_types": _get_giant_form_types() if in_animal_form else _get_animal_form_types(),
		"culture": culture,
		"artist": artist,
		"art_path": art_path,
	}

func activate(game_manager: GameManager, _target: Card = null) -> void:
	if not can_activate(game_manager):
		return
	shift_forms()
	spend_major_creature_action()
	if game_manager != null:
		game_manager.notify_creature_shapeshifted(self, self)
		game_manager.note_player_feedback("%s shifts into %s." % [card_name, _get_current_form_label()])

func shift_forms() -> void:
	in_animal_form = not in_animal_form
	card_types = _get_animal_form_types() if in_animal_form else _get_giant_form_types()

func get_effective_speed() -> int:
	var total := super.get_effective_speed()
	if in_animal_form:
		total += ANIMAL_FORM_SPEED_BONUS
	return clampi(total, 1, 7)

func get_effective_resilience() -> int:
	var total := super.get_effective_resilience()
	if in_animal_form:
		total += ANIMAL_FORM_RESILIENCE_DELTA
	return max(0, total)

func get_effective_strength() -> int:
	var total := super.get_effective_strength()
	if in_animal_form:
		total += ANIMAL_FORM_STRENGTH_BONUS
	return max(0, total)

func get_hover_detail_lines(_viewer: Player = null) -> Array[String]:
	return [
		"[b]Current Form[/b]: %s" % _get_current_form_label(),
		"[b]Giant Form[/b]: Giant, Mage, Shapeshifter; SPD 1 / RES 26 / STR 24.",
		"[b]Animal Form[/b]: Animal, Mage, Avian, Aerial; SPD 3 / RES 15 / STR 27.",
	]

func _get_current_form_label() -> String:
	return "Animal, Mage, Avian, Aerial" if in_animal_form else "Giant, Mage, Shapeshifter"

func _get_giant_form_types() -> Array[String]:
	return [
		"Giant",
		"Mage",
		"Shapeshifter",
		"Norse Creature",
	]

func _get_animal_form_types() -> Array[String]:
	return [
		"Animal",
		"Mage",
		"Avian",
		"Aerial",
		"Shapeshifter",
		"Norse Creature",
	]
